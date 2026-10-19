#pragma TextEncoding = "UTF-8"
#pragma rtGlobals = 3
#pragma IgorVersion = 7.00

// =====================================================================================
//  HEKA_Tree_V2.ipf   --  STEP 1 + STEP 2, now reading PatchMaster NEXT as well
//  Andre Dagostin / Vollum Institute
//
//  !! REMOVE HEKA_Tree.ipf and HEKA_Load.ipf from the experiment before adding the _V2
//  !! files -- the function names are unchanged, so keeping both gives duplicate-name
//  !! compile errors.  HEKA_Browser.ipf needs no change and can stay as it is.
//
//  WHAT'S NEW IN THIS VERSION
//  --------------------------
//  PatchMaster NEXT (version string like "1.7.0 [Build 1072]") changed two things.
//
//  1. THE BUNDLE HEADER GREW.  BundleItem went from 16 to 24 bytes because oStart and
//     oLength became INT64, so BundleHeaderSize went 256 -> 352.  Any reader that
//     computes item i at 64+16*i lands mid-record and gets nonsense -- that is why the
//     old code "found" .pul with a garbage start and a length of zero.
//
//     Detection: byte 56 of the bundle header is an INT32 format code.  The v9/v1000
//     docs leave it inside "oReserved", but PatchMaster fills it in:
//           1000 = classic  (16-byte items, 256-byte header)
//           2000 = PM NEXT  (24-byte items, 352-byte header)
//     We read it, then VERIFY by parsing and scoring the item table, and fall back to
//     the other layout if the primary guess yields nothing plausible.
//
//  2. THE TRACE RECORD GREW.  TrData and TrDataPoints became INT64, so every field
//     from TrInternalSolution onward shifts by +8 and TraceRecSize goes 512 -> 528.
//     See HK_Def_pul_4().
//
//  What did NOT change: the tree format itself (magic, level count, level sizes, the
//  inline child counts), and the Root / Group / Series / Sweep records.  The .amp tree
//  is identical to v9.  In .pgf only the root record grew (584 -> 1144).
//
//  Note: the FileFormat_v1000 documents do NOT describe this -- they match the classic
//  format exactly (TrData INT32 @40, BundleItem 16 bytes).  v1000 IS the old format.
//
//  CHECK IT ON BOTH FILES
//      HK_Scan("")          // prints the detected format code and item size
//      HK_CheckBlockEnd()   // tree walk must land exactly on the block end
//      HK_Verify()          // inline child counts vs the redundant metadata fields
//      HK_VerifyData()      // NEW: proves TrData/TrDataPoints tile the .dat block
//      HK_SelfTest()        // decoder vs GBLoadWave
//
//  STEP 1: generic single-pass tree scanner.
//  STEP 2: table-driven metadata reader.
//
//  ------------------------------------------------------------------------------
//  STEP 2 IN ONE SENTENCE
//  Every field of every record is described once, in a table, by (name, offset,
//  type).  One generic reader then pulls ANY field of ANY record by name, straight
//  out of the copy of the tree block that is already sitting in memory.  No file
//  access, no GBLoadWave, no per-field hand-written code.
//
//  QUICK TEST
//      HK_Scan("")                          // as before
//      HK_Dump( HK_Node4(0,0,0,0) )         // every field of group 1 / series 1 / sweep 1 / trace 1
//      HK_Dump( HK_Node4(0,0,-1,-1) )       // every field of that series, incl. amplifier state
//      Print HK_Num( HK_Node4(0,0,0,0), "TrDataScaler" )
//      Print HK_GetS( HK_Node4(0,0,-1,-1), "SeComment" )
//      Print HK_GetS( HK_Node4(0,0,-1,-1), "SeTime" )        // date/time, readable
//      HK_Collect(2, "Am_CSlow", "CSlow_all")                // CSlow of every series -> one wave
//      HK_Collect(4, "TrDataPoints", "npnts_all")
//      HK_SelfTest()                        // decoder check against GBLoadWave
//
//  MAIN ENTRY POINTS
//      HK_Num(node, field)          numeric value  (NaN if the field is absent)
//      HK_NumI(node, field, i)      element i of an array field
//      HK_GetS(node, field)         value as text (strings, dates, enums, numbers)
//      HK_Dump(node)               print every field of that record
//      HK_FieldList([which, level]) ";"-list of field names available at a level
//      HK_Collect(level, field, destName)   one field for EVERY node at a level
//      HK_CollectT(level, field, destName)  same, into a text wave
//
//  ADDING A FIELD
//      Find the right HK_Def_* function below, add one line:
//          HK_F(s, "TrWhatever", 123, "R8")
//      Types: I32 U32 I16 U16 S16 I8 C8 R8 R4 TIM   (TIM = PatchMaster date/time)
//      Arrays / strings use HK_FN(s, name, offset, type, count); "STR" count = length.
//      Fields that do not exist in your file version are detected automatically
//      (offset beyond the level size stored in the file) and return NaN / "".
// =====================================================================================


static StrConstant kHK_DF   = "root:Packages:HEKA"
static Constant    kHK_Grow = 4096          // initial / growth chunk for the node table

// PatchMaster stores time as seconds since 01-Jan-1990, on a 1904 base, modulo 2^32.
// Igor's own date/time origin is 01-Jan-1904, so the conversion is a subtraction.
static Constant kHK_JanFirst1990 = 1580970496
static Constant kHK_HighDWord    = 4294967296


// #####################################################################################
// #####                            STEP 1  -  THE SCANNER                         #####
// #####################################################################################

// -------------------------------------------------------------------------------------
// Package data folder
// -------------------------------------------------------------------------------------
static Function/DF HK_Home()
	if( !DataFolderExists("root:Packages") )
		NewDataFolder root:Packages
	endif
	if( !DataFolderExists(kHK_DF) )
		NewDataFolder $kHK_DF
	endif
	DFREF dfr = $kHK_DF
	return dfr
End


// -------------------------------------------------------------------------------------
// Byte-level accessors on the in-memory copy of the tree block.
// swap = 0 -> little-endian file (Windows / Intel Mac);  swap = 1 -> big-endian (PPC Mac)
// -------------------------------------------------------------------------------------
static Function HK_U32(bb, off, swap)			// unsigned INT32
	Wave/B/U bb
	Variable off, swap

	if( swap )
		return bb[off]*16777216 + bb[off+1]*65536 + bb[off+2]*256 + bb[off+3]
	endif
	return bb[off] + bb[off+1]*256 + bb[off+2]*65536 + bb[off+3]*16777216
End

static Function HK_I32(bb, off, swap)			// signed INT32
	Wave/B/U bb
	Variable off, swap

	Variable v = HK_U32(bb, off, swap)
	if( v >= 2147483648 )
		v -= 4294967296
	endif
	return v
End

// Signed INT64.  Igor variables are doubles, so values are exact up to 2^53 -- ample
// for file offsets (9 PB) and sample counts.  Introduced because PatchMaster NEXT
// widened TrData and TrDataPoints to 64 bits.
static Function HK_I64(bb, off, swap)
	Wave/B/U bb
	Variable off, swap

	Variable lo, hi
	if( swap )
		hi = HK_U32(bb, off,   swap)
		lo = HK_U32(bb, off+4, swap)
	else
		lo = HK_U32(bb, off,   swap)
		hi = HK_U32(bb, off+4, swap)
	endif
	if( hi >= 2147483648 )						// negative
		return -( (4294967296 - hi - 1) * 4294967296 + (4294967296 - lo) )
	endif
	return hi * 4294967296 + lo
End

static Function HK_U16(bb, off, swap)			// unsigned INT16 / CARD16 / SET16
	Wave/B/U bb
	Variable off, swap

	if( swap )
		return bb[off]*256 + bb[off+1]
	endif
	return bb[off] + bb[off+1]*256
End

static Function HK_I16(bb, off, swap)			// signed INT16
	Wave/B/U bb
	Variable off, swap

	Variable v = HK_U16(bb, off, swap)
	if( v >= 32768 )
		v -= 65536
	endif
	return v
End

// IEEE-754 double, decoded from raw bytes.  Verified against 40000 test values.
static Function HK_R8(bb, off, swap)
	Wave/B/U bb
	Variable off, swap

	Variable b0, b1, b2, b3, b4, b5, b6, b7
	if( swap )
		b7 = bb[off]
		b6 = bb[off+1]
		b5 = bb[off+2]
		b4 = bb[off+3]
		b3 = bb[off+4]
		b2 = bb[off+5]
		b1 = bb[off+6]
		b0 = bb[off+7]
	else
		b0 = bb[off]
		b1 = bb[off+1]
		b2 = bb[off+2]
		b3 = bb[off+3]
		b4 = bb[off+4]
		b5 = bb[off+5]
		b6 = bb[off+6]
		b7 = bb[off+7]
	endif

	Variable sgn  = (b7 & 0x80) ? -1 : 1
	Variable expo = (b7 & 0x7F) * 16 + trunc(b6 / 16)
	Variable mant = (b6 & 0x0F) * 281474976710656 + b5 * 1099511627776 + b4 * 4294967296	\
	              + b3 * 16777216 + b2 * 65536 + b1 * 256 + b0

	if( expo == 0 )
		return (mant == 0) ? sgn*0 : sgn * mant * 2^-1074
	endif
	if( expo == 2047 )
		return (mant == 0) ? sgn * Inf : NaN
	endif
	return sgn * (1 + mant / 4503599627370496) * 2^(expo - 1023)
End

// IEEE-754 single precision
static Function HK_R4(bb, off, swap)
	Wave/B/U bb
	Variable off, swap

	Variable b0, b1, b2, b3
	if( swap )
		b3 = bb[off]
		b2 = bb[off+1]
		b1 = bb[off+2]
		b0 = bb[off+3]
	else
		b0 = bb[off]
		b1 = bb[off+1]
		b2 = bb[off+2]
		b3 = bb[off+3]
	endif

	Variable sgn  = (b3 & 0x80) ? -1 : 1
	Variable expo = (b3 & 0x7F) * 2 + trunc(b2 / 128)
	Variable mant = (b2 & 0x7F) * 65536 + b1 * 256 + b0

	if( expo == 0 )
		return (mant == 0) ? sgn*0 : sgn * mant * 2^-149
	endif
	if( expo == 255 )
		return (mant == 0) ? sgn * Inf : NaN
	endif
	return sgn * (1 + mant / 8388608) * 2^(expo - 127)
End

static Function/S HK_CStr(bb, off, maxLen)		// zero-terminated ASCII string
	Wave/B/U bb
	Variable off, maxLen

	String s = ""
	Variable i, c
	for( i = 0; i < maxLen; i += 1 )
		c = bb[off+i]
		if( c == 0 )
			break
		endif
		s += num2char(c)
	endfor
	return s
End

// PatchMaster stored time -> Igor date/time seconds (origin 01-Jan-1904)
Function HK_PMTime2Igor(storedTime)
	Variable storedTime

	Variable t = storedTime - kHK_JanFirst1990
	if( t < 0 )
		t += kHK_HighDWord
	endif
	return t
End


// =====================================================================================
//  BUNDLE HEADER
// =====================================================================================
Function HK_ReadBundleHeader(pathStr)
	String pathStr

	DFREF dfr = HK_Home()

	Variable refNum
	Open/R/Z=1 refNum as pathStr
	if( V_flag != 0 )
		Print "HK_ReadBundleHeader: cannot open file."
		return -1
	endif

	Make/O/B/U/N=512 dfr:HK_Hdr/WAVE=hh		// 512 covers both the 256- and 352-byte headers
	FSetPos refNum, 0
	FBinRead refNum, hh
	FStatus refNum
	Variable fileSize = V_logEOF
	Close refNum

	String sig = HK_CStr(hh, 0, 8)
	if( CmpStr(sig[0,2], "DAT") != 0 )
		Printf "HK_ReadBundleHeader: signature is \"%s\", not a bundled PatchMaster file.\r", sig
		return -2
	endif

	Variable hswap  = (hh[52] == 0)			// oIsLittleEndian: TRUE (1) = little-endian
	Variable nItems = HK_I32(hh, 48, hswap)

	// ---------------------------------------------------------------------------------
	//  FORMAT CODE.  Byte 56 of the bundle header is an INT32 that the v9/v1000 docs
	//  leave inside "oReserved", but PatchMaster fills it in:
	//        1000 = classic     BundleItem 16 bytes (INT32 start/length), header 256
	//        2000 = PM NEXT     BundleItem 24 bytes (INT64 start/length), header 352
	//  We trust it, but we verify: the item table is parsed and scored, and if the
	//  primary guess yields nothing plausible we fall back to the other layout.
	// ---------------------------------------------------------------------------------
	Variable fmtCode  = HK_I32(hh, 56, hswap)
	Variable itemSize = 16
	if( fmtCode >= 2000 )
		itemSize = 24
	endif

	Variable score = HK_ParseItems(hh, itemSize, hswap, nItems, fileSize)
	if( score < 1 )
		Variable alt = 40 - itemSize					// 16 <-> 24
		Variable score2 = HK_ParseItems(hh, alt, hswap, nItems, fileSize)
		if( score2 > score )
			Printf "HK_ReadBundleHeader: format code %d suggested %d-byte items, but %d-byte items parse correctly. Using %d.\r", fmtCode, itemSize, alt, alt
			itemSize = alt
			score    = score2
		else
			HK_ParseItems(hh, itemSize, hswap, nItems, fileSize)		// restore
		endif
	endif
	if( score < 1 )
		Print "HK_ReadBundleHeader: could not make sense of the bundle item table with either layout."
		return -3
	endif

	String/G dfr:HK_Path        = pathStr
	String/G dfr:HK_Signature   = sig
	String/G dfr:HK_PMVersion   = HK_CStr(hh, 8, 32)
	Variable/G dfr:HK_nItems    = nItems
	Variable/G dfr:HK_FormatCode = fmtCode
	Variable/G dfr:HK_ItemSize   = itemSize
	Variable/G dfr:HK_HeaderSize = 64 + 12*itemSize
	Variable/G dfr:HK_FileSize   = fileSize

	return 0
End


// Fill HK_ItemStart / HK_ItemLength / HK_ItemExt assuming the given BundleItem size.
// Returns how many entries look plausible (extension ".xxx", range inside the file).
static Function HK_ParseItems(hh, itemSize, hswap, nItems, fileSize)
	Wave/B/U hh
	Variable itemSize, hswap, nItems, fileSize

	DFREF dfr = HK_Home()
	Make/O/D/N=(nItems) dfr:HK_ItemStart/WAVE=iStart
	Make/O/D/N=(nItems) dfr:HK_ItemLength/WAVE=iLen
	Make/O/T/N=(nItems) dfr:HK_ItemExt/WAVE=iExt

	Variable headerSize = 64 + 12*itemSize
	Variable i, o, good = 0
	String e
	for( i = 0; i < nItems; i += 1 )
		o = 64 + itemSize*i
		if( itemSize == 24 )
			iStart[i] = HK_I64(hh, o,   hswap)
			iLen[i]   = HK_I64(hh, o+8, hswap)
			iExt[i]   = HK_CStr(hh, o+16, 8)
		else
			iStart[i] = HK_I32(hh, o,   hswap)
			iLen[i]   = HK_I32(hh, o+4, hswap)
			iExt[i]   = HK_CStr(hh, o+8, 8)
		endif

		e = iExt[i]
		if( strlen(e) == 0 )
			continue									// unused slot: neither good nor bad
		endif
		if( CmpStr(e[0], ".") != 0 )
			continue
		endif
		if( iStart[i] < headerSize || iLen[i] < 0 )
			continue
		endif
		if( fileSize > 0 && iStart[i] + iLen[i] > fileSize )
			continue
		endif
		good += 1
	endfor
	return good
End


static Function HK_ItemIndex(ext)
	String ext

	DFREF dfr = HK_Home()
	Wave/T/Z/SDFR=dfr iExt = HK_ItemExt
	if( !WaveExists(iExt) )
		return -1
	endif
	Variable i
	for( i = 0; i < numpnts(iExt); i += 1 )
		if( CmpStr(iExt[i], ext) == 0 )
			return i
		endif
	endfor
	return -1
End


// =====================================================================================
//  THE SCANNER
//      HK_Scan(pathStr [, which])     which = "pul" (default), "pgf", "amp", "sol", ...
// =====================================================================================
Function HK_Scan(pathStr, [which])
	String pathStr
	String which

	if( ParamIsDefault(which) )
		which = "pul"
	endif

	if( strlen(pathStr) == 0 )
		GetFileFolderInfo/Q
		pathStr = S_Path
		if( strlen(pathStr) == 0 )
			return -1
		endif
	endif

	Variable t0 = StopMSTimer(-2)

	if( HK_ReadBundleHeader(pathStr) != 0 )
		return -2
	endif

	DFREF dfr = HK_Home()
	Wave/SDFR=dfr iStart = HK_ItemStart
	Wave/SDFR=dfr iLen   = HK_ItemLength

	Variable idx = HK_ItemIndex("." + which)
	if( idx < 0 )
		Printf "HK_Scan: this bundle contains no \".%s\" block.\r", which
		return -3
	endif

	Variable blockStart = iStart[idx]
	Variable blockLen   = iLen[idx]
	if( blockLen <= 0 )
		Printf "HK_Scan: \".%s\" block is empty.\r", which
		return -4
	endif

	// ---- ONE disk read: the whole tree block into memory --------------------------
	Variable refNum
	Open/R/Z=1 refNum as pathStr
	if( V_flag != 0 )
		return -5
	endif
	Make/O/B/U/N=(blockLen) dfr:HK_Bytes/WAVE=bb
	FSetPos refNum, blockStart
	FBinRead refNum, bb
	Close refNum

	// ---- tree header --------------------------------------------------------------
	Variable magic = HK_U32(bb, 0, 0)
	Variable swap
	if( magic == 0x54726565 )			// bytes on disk read "eerT"  -> little-endian file
		swap = 0
	elseif( magic == 0x65657254 )		// bytes on disk read "Tree"  -> big-endian file
		swap = 1
	else
		Printf "HK_Scan: bad tree magic 0x%08X at file offset %d.\r", magic, blockStart
		return -6
	endif

	Variable nLevels = HK_I32(bb, 4, swap)
	if( nLevels <= 0 || nLevels > 16 )
		Printf "HK_Scan: implausible level count %d.\r", nLevels
		return -7
	endif

	Make/O/D/N=(nLevels) dfr:HK_LevelSize/WAVE=lsz
	Variable i
	for( i = 0; i < nLevels; i += 1 )
		lsz[i] = HK_I32(bb, 8 + 4*i, swap)
	endfor

	Variable pos = 8 + 4*nLevels			// offset of the root record, inside the block

	// ---- walk ---------------------------------------------------------------------
	Make/O/D/N=(kHK_Grow, 6) dfr:HK_Node/WAVE=nd
	nd = NaN
	Variable nNodes = 0
	HK_Walk(bb, lsz, nd, swap, pos, 0, -1, nNodes)
	Redimension/N=(nNodes, 6) nd

	SetDimLabel 1, 0, level,       nd
	SetDimLabel 1, 1, recOffset,   nd
	SetDimLabel 1, 2, parent,      nd
	SetDimLabel 1, 3, nChildren,   nd
	SetDimLabel 1, 4, firstChild,  nd
	SetDimLabel 1, 5, nextSibling, nd

	Variable/G dfr:HK_BlockStart = blockStart
	Variable/G dfr:HK_BlockLen   = blockLen
	Variable/G dfr:HK_Swap       = swap
	Variable/G dfr:HK_nLevels    = nLevels
	Variable/G dfr:HK_nNodes     = nNodes
	String/G   dfr:HK_Which      = which

	HK_KillDefs()							// field tables belong to the previous tree

	Make/O/D/N=(nLevels) dfr:HK_LevelCount/WAVE=lc
	lc = 0
	for( i = 0; i < nNodes; i += 1 )
		lc[ nd[i][0] ] += 1
	endfor

	Variable dt = (StopMSTimer(-2) - t0) * 1e-6
	SVAR ver = dfr:HK_PMVersion
	Printf "-------------------------------------------------------------\r"
	NVAR fcode = dfr:HK_FormatCode
	NVAR isize = dfr:HK_ItemSize
	Printf "HEKA bundle : %s\r", pathStr
	Printf "PatchMaster : %s   (block .%s, %d bytes, %s-endian)\r", ver, which, blockLen, SelectString(swap, "little", "big")
	Printf "format code : %d  ->  %s   (BundleItem %d bytes, header %d)\r", fcode, SelectString(fcode >= 2000, "classic / v1000", "PatchMaster NEXT"), isize, 64 + 12*isize
	Printf "levels      : %d   sizes = ", nLevels
	for( i = 0; i < nLevels; i += 1 )
		Printf "%d%s", lsz[i], SelectString(i < nLevels-1, "", ", ")
	endfor
	Printf "\r"
	Printf "nodes/level : "
	for( i = 0; i < nLevels; i += 1 )
		Printf "L%d=%d%s", i, lc[i], SelectString(i < nLevels-1, "", "  ")
	endfor
	Printf "\r"
	Printf "total nodes : %d   scanned in %.3f s\r", nNodes, dt
	Printf "-------------------------------------------------------------\r"

	return nNodes
End


static Function HK_Walk(bb, lsz, nd, swap, pos, level, parent, nNodes)
	Wave/B/U bb
	Wave/D lsz, nd
	Variable swap
	Variable &pos
	Variable level, parent
	Variable &nNodes

	Variable me = nNodes
	nNodes += 1
	if( me >= DimSize(nd, 0) )
		Redimension/N=(DimSize(nd,0) + kHK_Grow, 6) nd
	endif

	nd[me][0] = level
	nd[me][1] = pos
	nd[me][2] = parent
	nd[me][4] = -1
	nd[me][5] = -1

	pos += lsz[level]						// skip the record body
	Variable nkids = HK_I32(bb, pos, swap)	// <-- the child count, stored inline
	pos += 4
	nd[me][3] = nkids

	if( level + 1 >= numpnts(lsz) || nkids <= 0 )
		return me
	endif

	nd[me][4] = me + 1						// preorder: first child is the next node
	Variable k, kid, prev = -1
	for( k = 0; k < nkids; k += 1 )
		kid = HK_Walk(bb, lsz, nd, swap, pos, level+1, me, nNodes)
		if( prev >= 0 )
			nd[prev][5] = kid
		endif
		prev = kid
	endfor
	return me
End


// =====================================================================================
//  NAVIGATION HELPERS
// =====================================================================================
Function HK_Child(n, k)
	Variable n, k

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) || n < 0 || n >= DimSize(nd,0) || k < 0 || k >= nd[n][3] )
		return -1
	endif
	Variable c = nd[n][4]
	do
		if( k == 0 )
			return c
		endif
		c = nd[c][5]
		k -= 1
	while( c >= 0 )
	return -1
End

Function HK_Node4(gr, se, sw, tr)
	Variable gr, se, sw, tr

	Variable n = 0								// root
	if( gr < 0 )
		return n
	endif
	n = HK_Child(n, gr)
	if( n < 0 || se < 0 )
		return n
	endif
	n = HK_Child(n, se)
	if( n < 0 || sw < 0 )
		return n
	endif
	n = HK_Child(n, sw)
	if( n < 0 || tr < 0 )
		return n
	endif
	return HK_Child(n, tr)
End

Function HK_Offset(n)
	Variable n

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	NVAR/Z/SDFR=dfr bs = HK_BlockStart
	if( !WaveExists(nd) || !NVAR_Exists(bs) || n < 0 || n >= DimSize(nd,0) )
		return NaN
	endif
	return bs + nd[n][1]
End

Function HK_NumChildren(n)
	Variable n

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) || n < 0 || n >= DimSize(nd,0) )
		return NaN
	endif
	return nd[n][3]
End

Function HK_Level(n)
	Variable n

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) || n < 0 || n >= DimSize(nd,0) )
		return NaN
	endif
	return nd[n][0]
End

Function/S HK_Label(n)
	Variable n

	DFREF dfr = HK_Home()
	Wave/Z/B/U/SDFR=dfr bb = HK_Bytes
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(bb) || !WaveExists(nd) || n < 0 || n >= DimSize(nd,0) )
		return ""
	endif
	if( nd[n][0] == 0 )
		return HK_CStr(bb, nd[n][1] + 8, 32)		// RoVersionName
	endif
	return HK_CStr(bb, nd[n][1] + 4, 32)			// Gr/Se/Sw/TrLabel
End


// =====================================================================================
//  REPORTING / VERIFICATION  (step 1)
// =====================================================================================
Function HK_Report([maxLevel])
	Variable maxLevel

	if( ParamIsDefault(maxLevel) )
		maxLevel = 2
	endif

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) )
		Print "HK_Report: run HK_Scan() first."
		return -1
	endif

	String names = "Root;Group;Series;Sweep;Trace;L5;L6;L7"
	Variable i, lev, j
	String indent
	for( i = 0; i < DimSize(nd,0); i += 1 )
		lev = nd[i][0]
		if( lev > maxLevel )
			continue
		endif
		indent = ""
		for( j = 0; j < lev; j += 1 )
			indent += "    "
		endfor
		Printf "%s%s[%d]  \"%s\"   children=%d   offset=%d\r", indent, StringFromList(lev, names), i, HK_Label(i), nd[i][3], HK_Offset(i)
	endfor
	return 0
End


Function HK_Verify()

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	Wave/Z/B/U/SDFR=dfr bb = HK_Bytes
	NVAR/Z/SDFR=dfr swap = HK_Swap
	SVAR/Z/SDFR=dfr which = HK_Which
	if( !WaveExists(nd) || CmpStr(which, "pul") != 0 )
		Print "HK_Verify: run HK_Scan(\"\") on the .pul block first."
		return -1
	endif

	Variable i, lev, off, bad = 0, nSe = 0, nSw = 0, nTr = 0
	Variable stated, actual, expectID, c, k

	for( i = 0; i < DimSize(nd,0); i += 1 )
		lev    = nd[i][0]
		off    = nd[i][1]
		actual = nd[i][3]

		if( lev == 2 )
			nSe += 1
			stated = HK_I32(bb, off + 120, swap)		// SeNumberSweeps
			if( stated != actual )
				Printf "  series node %d (\"%s\"): SeNumberSweeps=%d  but inline count=%d\r", i, HK_Label(i), stated, actual
				bad += 1
			endif
		elseif( lev == 3 )
			nSw += 1
			expectID = 1
			c = nd[i][4]
			do
				if( c < 0 )
					break
				endif
				k = HK_I32(bb, nd[c][1] + 36, swap)		// TrTraceID
				if( k != expectID )
					Printf "  sweep node %d: child %d has TrTraceID=%d, expected %d\r", i, expectID-1, k, expectID
					bad += 1
				endif
				expectID += 1
				c = nd[c][5]
			while( 1 )
		elseif( lev == 4 )
			nTr += 1
		endif
	endfor

	Printf "HK_Verify: %d series, %d sweeps, %d traces checked -- %s\r", nSe, nSw, nTr, SelectString(bad == 0, num2str(bad) + " MISMATCHES", "all consistent")
	return bad
End


Function HK_CheckBlockEnd()

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd  = HK_Node
	Wave/Z/SDFR=dfr lsz = HK_LevelSize
	NVAR/Z/SDFR=dfr blen = HK_BlockLen
	if( !WaveExists(nd) )
		return -1
	endif

	Variable last = DimSize(nd,0) - 1
	Variable endPos = nd[last][1] + lsz[ nd[last][0] ] + 4
	Printf "HK_CheckBlockEnd: walk ended at %d, block is %d bytes  ->  %s\r", endPos, blen, SelectString(endPos == blen, "MISMATCH", "exact")
	return endPos - blen
End



// #####################################################################################
// #####                    STEP 2  -  TABLE-DRIVEN METADATA READER                #####
// #####################################################################################

// -------------------------------------------------------------------------------------
//  Descriptor builders.  One line per field:  name, offset, type [, count]
//  Types: I32 U32 I16 U16 S16 I8 C8 R8 R4 TIM STR
// -------------------------------------------------------------------------------------
static Function HK_F(s, name, off, type)
	String &s
	String name
	Variable off
	String type
	s += name + "," + num2istr(off) + "," + type + ",1;"
End

static Function HK_FN(s, name, off, type, n)
	String &s
	String name
	Variable off
	String type
	Variable n
	s += name + "," + num2istr(off) + "," + type + "," + num2istr(n) + ";"
End

static Function HK_TypeSize(type)
	String type
	strswitch( type )
		case "I32":
		case "U32":
		case "R4":
			return 4
		case "I64":
			return 8
		case "I16":
		case "U16":
		case "S16":
			return 2
		case "I8":
		case "C8":
			return 1
		case "R8":
		case "TIM":
			return 8
	endswitch
	return 1									// STR: size is the count
End


// ------------------------------ .pul  level 0 : Root ---------------------------------
static Function/S HK_Def_pul_0()
	String s = ""
	HK_F (s, "RoVersion",      0, "I32")
	HK_F (s, "RoMark",         4, "I32")
	HK_FN(s, "RoVersionName",  8, "STR", 32)
	HK_FN(s, "RoAuxFileName", 40, "STR", 80)
	HK_FN(s, "RoRootText",    120, "STR", 400)
	HK_F (s, "RoStartTime",   520, "TIM")
	HK_F (s, "RoMaxSamples",  528, "I32")
	HK_F (s, "RoCRC",         532, "U32")
	HK_F (s, "RoFeatures",    536, "S16")
	HK_FN(s, "RoTcEnumerator",544, "I16", 32)
	HK_FN(s, "RoTcKind",      608, "I8",  32)
	return s
End

// ------------------------------ .pul  level 1 : Group --------------------------------
static Function/S HK_Def_pul_1()
	String s = ""
	HK_F (s, "GrMark",              0, "I32")
	HK_FN(s, "GrLabel",             4, "STR", 32)
	HK_FN(s, "GrText",             36, "STR", 80)
	HK_F (s, "GrExperimentNumber",116, "I32")
	HK_F (s, "GrGroupCount",      120, "I32")
	HK_F (s, "GrCRC",             124, "U32")
	HK_F (s, "GrMatrixWidth",     128, "R8")
	HK_F (s, "GrMatrixHeight",    136, "R8")
	return s
End

// ------------------------------ .pul  level 2 : Series -------------------------------
// The Series record itself is UNCHANGED in PatchMaster NEXT -- same 1728 bytes and the
// same offsets (verified: SeLabel, SeNumberSweeps, SeTime, SeUsername, the user-param
// descriptors).  BUT the embedded AmplifierState / LockInParams block is left
// UNINITIALISED by PMN: that region is filled with stale process memory (recognisable
// 0x00007ff... pointer values), not amplifier settings.  PMN sets SeAmplStateOffset=0
// and SeAmplStateSeries=n, i.e. the real state lives in the .amp tree.
// So on a PMN file the Am_* / Lo_* fields are deliberately NOT registered -- reporting
// random bytes as CSlow or Rs would be far worse than reporting nothing.
static Function/S HK_Def_pul_2(fmtCode)
	Variable fmtCode
	String s = ""
	HK_F (s, "SeMark",             0, "I32")
	HK_FN(s, "SeLabel",            4, "STR", 32)
	HK_FN(s, "SeComment",         36, "STR", 80)
	HK_F (s, "SeSeriesCount",    116, "I32")
	HK_F (s, "SeNumberSweeps",   120, "I32")
	HK_F (s, "SeAmplStateOffset",124, "I32")
	HK_F (s, "SeAmplStateSeries",128, "I32")
	HK_F (s, "SeMethodTag",      132, "I32")
	HK_F (s, "SeTime",           136, "TIM")
	HK_F (s, "SePageWidth",      144, "R8")
	// SeSwUserParamDescr : 4 x (name 32 + unit 8) starting at 152
	HK_FN(s, "SeSwParamName1",   152, "STR", 32)
	HK_FN(s, "SeSwParamUnit1",   184, "STR", 8)
	HK_FN(s, "SeSwParamName2",   192, "STR", 32)
	HK_FN(s, "SeSwParamUnit2",   224, "STR", 8)
	HK_FN(s, "SeSwParamName3",   232, "STR", 32)
	HK_FN(s, "SeSwParamUnit3",   264, "STR", 8)
	HK_FN(s, "SeSwParamName4",   272, "STR", 32)
	HK_FN(s, "SeSwParamUnit4",   304, "STR", 8)
	HK_FN(s, "SeMethodName",     312, "STR", 32)
	HK_FN(s, "SeSeUserParams1",  344, "R8", 4)
	if( fmtCode < 2000 )
		HK_Def_LockIn(s, 376, "Lo_")			// SeLockInParams
		HK_Def_AmplState(s, 472, "Am_")			// SeAmplifierState
	endif
	HK_FN(s, "SeUsername",       872, "STR", 80)
	HK_FN(s, "SeParamName1",     952, "STR", 32)
	HK_FN(s, "SeParamUnit1",     984, "STR", 8)
	HK_FN(s, "SeParamName2",     992, "STR", 32)
	HK_FN(s, "SeParamUnit2",    1024, "STR", 8)
	HK_FN(s, "SeParamName3",    1032, "STR", 32)
	HK_FN(s, "SeParamUnit3",    1064, "STR", 8)
	HK_FN(s, "SeParamName4",    1072, "STR", 32)
	HK_FN(s, "SeParamUnit4",    1104, "STR", 8)
	HK_F (s, "SeCRC",           1116, "U32")
	HK_FN(s, "SeSeUserParams2", 1120, "R8", 4)
	return s
End

// ------------------------------ .pul  level 3 : Sweep --------------------------------
static Function/S HK_Def_pul_3()
	String s = ""
	HK_F (s, "SwMark",               0, "I32")
	HK_FN(s, "SwLabel",              4, "STR", 32)
	HK_F (s, "SwAuxDataFileOffset", 36, "I32")
	HK_F (s, "SwStimCount",         40, "I32")
	HK_F (s, "SwSweepCount",        44, "I32")
	HK_F (s, "SwTime",              48, "TIM")
	HK_F (s, "SwTimer",             56, "R8")
	HK_FN(s, "SwSwUserParams",      64, "R8", 4)
	HK_F (s, "SwTemperature",       96, "R8")
	HK_F (s, "SwOldIntSol",        104, "I32")
	HK_F (s, "SwOldExtSol",        108, "I32")
	HK_F (s, "SwDigitalIn",        112, "S16")
	HK_F (s, "SwSweepKind",        114, "S16")
	HK_F (s, "SwDigitalOut",       116, "S16")
	HK_FN(s, "SwSwMarkers",        120, "R8", 4)
	HK_F (s, "SwCRC",              156, "U32")
	HK_FN(s, "SwSwHolding",        160, "R8", 16)
	return s
End

// ------------------------------ .pul  level 4 : Trace --------------------------------
// The trace record is the ONE .pul record PatchMaster NEXT changed.
//   TrData       INT32 @40  ->  INT64 @40
//   TrDataPoints INT32 @44  ->  INT64 @48
// so every field from TrInternalSolution onward moves by +8 and TraceRecSize goes
// 512 -> 528.  Verified against a real PMN file: the first trace reads Data=352,
// DataPoints=11250, DataFormat=1 (int32), and the NEXT trace's Data is exactly
// 352 + 11250*4 = 45352.
static Function/S HK_Def_pul_4(fmtCode)
	Variable fmtCode

	Variable isNext = (fmtCode >= 2000)
	Variable sh = 0							// shift applied from TrInternalSolution on
	if( isNext )
		sh = 8
	endif

	String s = ""
	HK_F (s, "TrMark",               0, "I32")
	HK_FN(s, "TrLabel",              4, "STR", 32)
	HK_F (s, "TrTraceID",           36, "I32")
	if( isNext )
		HK_F(s, "TrData",           40, "I64")
		HK_F(s, "TrDataPoints",     48, "I64")
	else
		HK_F(s, "TrData",           40, "I32")
		HK_F(s, "TrDataPoints",     44, "I32")
	endif
	HK_F (s, "TrInternalSolution",  48+sh, "I32")
	HK_F (s, "TrAverageCount",      52+sh, "I32")
	HK_F (s, "TrLeakID",            56+sh, "I32")
	HK_F (s, "TrLeakTraces",        60+sh, "I32")
	HK_F (s, "TrDataKind",          64+sh, "S16")
	HK_F (s, "TrUseXStart",         66+sh, "I8")
	HK_F (s, "TrTcKind",            67+sh, "I8")
	HK_F (s, "TrRecordingMode",     68+sh, "I8")
	HK_F (s, "TrAmplIndex",         69+sh, "C8")
	HK_F (s, "TrDataFormat",        70+sh, "I8")
	HK_F (s, "TrDataAbscissa",      71+sh, "I8")
	HK_F (s, "TrDataScaler",        72+sh, "R8")
	HK_F (s, "TrTimeOffset",        80+sh, "R8")
	HK_F (s, "TrZeroData",          88+sh, "R8")
	HK_FN(s, "TrYUnit",             96+sh, "STR", 8)
	HK_F (s, "TrXInterval",        104+sh, "R8")
	HK_F (s, "TrXStart",           112+sh, "R8")
	HK_FN(s, "TrXUnit",            120+sh, "STR", 8)
	HK_F (s, "TrYRange",           128+sh, "R8")
	HK_F (s, "TrYOffset",          136+sh, "R8")
	HK_F (s, "TrBandwidth",        144+sh, "R8")
	HK_F (s, "TrPipetteResistance",152+sh, "R8")
	HK_F (s, "TrCellPotential",    160+sh, "R8")
	HK_F (s, "TrSealResistance",   168+sh, "R8")
	HK_F (s, "TrCSlow",            176+sh, "R8")
	HK_F (s, "TrGSeries",          184+sh, "R8")
	HK_F (s, "TrRsValue",          192+sh, "R8")
	HK_F (s, "TrGLeak",            200+sh, "R8")
	HK_F (s, "TrMConductance",     208+sh, "R8")
	HK_F (s, "TrLinkDAChannel",    216+sh, "I32")
	HK_F (s, "TrValidYrange",      220+sh, "I8")
	HK_F (s, "TrAdcMode",          221+sh, "I8")
	HK_F (s, "TrAdcChannel",       222+sh, "I16")
	HK_F (s, "TrYmin",             224+sh, "R8")
	HK_F (s, "TrYmax",             232+sh, "R8")
	HK_F (s, "TrSourceChannel",    240+sh, "I32")
	HK_F (s, "TrExternalSolution", 244+sh, "I32")
	HK_F (s, "TrCM",               248+sh, "R8")
	HK_F (s, "TrGM",               256+sh, "R8")
	HK_F (s, "TrPhase",            264+sh, "R8")
	HK_F (s, "TrDataCRC",          272+sh, "U32")
	HK_F (s, "TrCRC",              276+sh, "U32")
	HK_F (s, "TrGS",               280+sh, "R8")
	HK_F (s, "TrSelfChannel",      288+sh, "I32")
	HK_F (s, "TrInterleaveSize",   292+sh, "I32")
	HK_F (s, "TrInterleaveSkip",   296+sh, "I32")
	HK_F (s, "TrImageIndex",       300+sh, "I32")
	HK_FN(s, "TrTrMarkers",        304+sh, "R8", 10)
	HK_F (s, "TrSECM_X",           384+sh, "R8")
	HK_F (s, "TrSECM_Y",           392+sh, "R8")
	HK_F (s, "TrSECM_Z",           400+sh, "R8")
	HK_F (s, "TrTrHolding",        408+sh, "R8")
	HK_F (s, "TrTcEnumerator",     416+sh, "I32")
	HK_F (s, "TrXTrace",           420+sh, "I32")
	HK_F (s, "TrIntSolValue",      424+sh, "R8")
	HK_F (s, "TrExtSolValue",      432+sh, "R8")
	HK_FN(s, "TrIntSolName",       440+sh, "STR", 32)
	HK_FN(s, "TrExtSolName",       472+sh, "STR", 32)
	HK_F (s, "TrDataPedestal",     504+sh, "R8")
	return s
End

// --------------------- shared sub-records: LockIn + AmplifierState -------------------
static Function HK_Def_LockIn(s, b, p)
	String &s
	Variable b
	String p
	HK_F(s, p+"ExtCalPhase",      b+0,  "R8")
	HK_F(s, p+"ExtCalAtten",      b+8,  "R8")
	HK_F(s, p+"PLPhase",          b+16, "R8")
	HK_F(s, p+"PLPhaseY1",        b+24, "R8")
	HK_F(s, p+"PLPhaseY2",        b+32, "R8")
	HK_F(s, p+"UsedPhaseShift",   b+40, "R8")
	HK_F(s, p+"UsedAttenuation",  b+48, "R8")
	HK_F(s, p+"ExtCalValid",      b+64, "I8")
	HK_F(s, p+"PLPhaseValid",     b+65, "I8")
	HK_F(s, p+"LockInMode",       b+66, "I8")
	HK_F(s, p+"CalMode",          b+67, "I8")
End

static Function HK_Def_AmplState(s, b, p)
	String &s
	Variable b
	String p
	HK_FN(s, p+"StateVersion",   b+0,  "STR", 8)
	HK_F (s, p+"CurrentGain",    b+8,  "R8")
	HK_F (s, p+"F2Bandwidth",    b+16, "R8")
	HK_F (s, p+"F2Frequency",    b+24, "R8")
	HK_F (s, p+"RsValue",        b+32, "R8")
	HK_F (s, p+"RsFraction",     b+40, "R8")
	HK_F (s, p+"GLeak",          b+48, "R8")
	HK_F (s, p+"CFastAmp1",      b+56, "R8")
	HK_F (s, p+"CFastAmp2",      b+64, "R8")
	HK_F (s, p+"CFastTau",       b+72, "R8")
	HK_F (s, p+"CSlow",          b+80, "R8")
	HK_F (s, p+"GSeries",        b+88, "R8")
	HK_F (s, p+"VCStimDacScale", b+96, "R8")
	HK_F (s, p+"CCStimScale",    b+104,"R8")
	HK_F (s, p+"VHold",          b+112,"R8")
	HK_F (s, p+"LastVHold",      b+120,"R8")
	HK_F (s, p+"VpOffset",       b+128,"R8")
	HK_F (s, p+"VLiquidJunction",b+136,"R8")
	HK_F (s, p+"CCIHold",        b+144,"R8")
	HK_F (s, p+"CSlowStimVolts", b+152,"R8")
	HK_F (s, p+"CCTrackVHold",   b+160,"R8")
	HK_F (s, p+"TimeoutCSlow",   b+168,"R8")
	HK_F (s, p+"SearchDelay",    b+176,"R8")
	HK_F (s, p+"MConductance",   b+184,"R8")
	HK_F (s, p+"MCapacitance",   b+192,"R8")
	HK_FN(s, p+"SerialNumber",   b+200,"STR", 8)
	HK_F (s, p+"E9Boards",       b+208,"I16")
	HK_F (s, p+"CSlowCycles",    b+210,"I16")
	HK_F (s, p+"IMonAdc",        b+212,"I16")
	HK_F (s, p+"VMonAdc",        b+214,"I16")
	HK_F (s, p+"MuxAdc",         b+216,"I16")
	HK_F (s, p+"TestDac",        b+218,"I16")
	HK_F (s, p+"StimDac",        b+220,"I16")
	HK_F (s, p+"StimDacOffset",  b+222,"I16")
	HK_F (s, p+"MaxDigitalBit",  b+224,"I16")
	HK_F (s, p+"HasCFastHigh",   b+226,"I8")
	HK_F (s, p+"CFastHigh",      b+227,"I8")
	HK_F (s, p+"HasBathSense",   b+228,"I8")
	HK_F (s, p+"BathSense",      b+229,"I8")
	HK_F (s, p+"HasF2Bypass",    b+230,"I8")
	HK_F (s, p+"F2Mode",         b+231,"I8")
	HK_F (s, p+"AmplKind",       b+232,"I8")
	HK_F (s, p+"IsEpc9N",        b+233,"I8")
	HK_F (s, p+"ADBoard",        b+234,"I8")
	HK_F (s, p+"BoardVersion",   b+235,"I8")
	HK_F (s, p+"ActiveE9Board",  b+236,"I8")
	HK_F (s, p+"Mode",           b+237,"I8")
	HK_F (s, p+"Range",          b+238,"I8")
	HK_F (s, p+"F2Response",     b+239,"I8")
	HK_F (s, p+"RsOn",           b+240,"I8")
	HK_F (s, p+"CSlowRange",     b+241,"I8")
	HK_F (s, p+"CCRange",        b+242,"I8")
	HK_F (s, p+"CCGain",         b+243,"I8")
	HK_F (s, p+"CSlowToTestDac", b+244,"I8")
	HK_F (s, p+"StimPath",       b+245,"I8")
	HK_F (s, p+"CCTrackTau",     b+246,"I8")
	HK_F (s, p+"WasClipping",    b+247,"I8")
	HK_F (s, p+"RepetitiveCSlow",b+248,"I8")
	HK_F (s, p+"LastCSlowRange", b+249,"I8")
	HK_F (s, p+"CanCCFast",      b+251,"I8")
	HK_F (s, p+"CanLowCCRange",  b+252,"I8")
	HK_F (s, p+"CanHighCCRange", b+253,"I8")
	HK_F (s, p+"CanCCTracking",  b+254,"I8")
	HK_F (s, p+"HasVmonPath",    b+255,"I8")
	HK_F (s, p+"HasNewCCMode",   b+256,"I8")
	HK_F (s, p+"Selector",       b+257,"C8")
	HK_F (s, p+"HoldInverted",   b+258,"I8")
	HK_F (s, p+"AutoCFast",      b+259,"I8")
	HK_F (s, p+"AutoCSlow",      b+260,"I8")
	HK_F (s, p+"HasVmonX100",    b+261,"I8")
	HK_F (s, p+"TestDacOn",      b+262,"I8")
	HK_F (s, p+"QMuxAdcOn",      b+263,"I8")
	HK_F (s, p+"Imon1Bandwidth", b+264,"R8")
	HK_F (s, p+"StimScale",      b+272,"R8")
	HK_F (s, p+"Gain",           b+280,"I8")
	HK_F (s, p+"Filter1",        b+281,"I8")
	HK_F (s, p+"StimFilterOn",   b+282,"I8")
	HK_F (s, p+"RsSlow",         b+283,"I8")
	HK_F (s, p+"CCCFastOn",      b+285,"I8")
	HK_F (s, p+"CCFastSpeed",    b+286,"I8")
	HK_F (s, p+"F2Source",       b+287,"I8")
	HK_F (s, p+"TestRange",      b+288,"I8")
	HK_F (s, p+"TestDacPath",    b+289,"I8")
	HK_F (s, p+"MuxChannel",     b+290,"I8")
	HK_F (s, p+"MuxGain64",      b+291,"I8")
	HK_F (s, p+"VmonX100",       b+292,"I8")
	HK_F (s, p+"IsQuadro",       b+293,"I8")
	HK_F (s, p+"F1Mode",         b+294,"I8")
	HK_F (s, p+"StimFilterHz",   b+296,"R8")
	HK_F (s, p+"RsTau",          b+304,"R8")
	HK_F (s, p+"DacToAdcDelay",  b+312,"R8")
	HK_F (s, p+"InputFilterTau", b+320,"R8")
	HK_F (s, p+"OutputFilterTau",b+328,"R8")
	HK_F (s, p+"VmonFactor",     b+336,"R8")
	HK_FN(s, p+"CalibDate",      b+344,"STR", 16)
	HK_F (s, p+"VmonOffset",     b+360,"R8")
	HK_F (s, p+"EEPROMKind",     b+368,"I8")
	HK_F (s, p+"VrefX2",         b+369,"I8")
	HK_F (s, p+"CCStimDacScale", b+376,"R8")
	HK_F (s, p+"VmonFiltBandwidth", b+384,"R8")
	HK_F (s, p+"VmonFiltFrequency", b+392,"R8")
End

// ------------------------------ .pgf  (stimulus tree) --------------------------------
static Function/S HK_Def_pgf_0()
	String s = ""
	HK_F (s, "roVersion",      0, "I32")
	HK_F (s, "roMark",         4, "I32")
	HK_FN(s, "roVersionName",  8, "STR", 32)
	HK_F (s, "roMaxSamples",  40, "I32")
	HK_FN(s, "roParams",      48, "R8", 10)
	HK_FN(s, "roParamText",  128, "STR", 320)
	HK_F (s, "roCRC",        580, "U32")
	return s
End

static Function/S HK_Def_pgf_1()				// Stimulation
	String s = ""
	HK_F (s, "stMark",               0, "I32")
	HK_FN(s, "stEntryName",          4, "STR", 32)
	HK_FN(s, "stFileName",          36, "STR", 32)
	HK_FN(s, "stAnalName",          68, "STR", 32)
	HK_F (s, "stDataStartSegment", 100, "I32")
	HK_F (s, "stDataStartTime",    104, "TIM")
	HK_F (s, "stSampleInterval",   112, "R8")
	HK_F (s, "stSweepInterval",    120, "R8")
	HK_F (s, "stLeakDelay",        128, "R8")
	HK_F (s, "stFilterFactor",     136, "R8")
	HK_F (s, "stNumberSweeps",     144, "I32")
	HK_F (s, "stNumberLeaks",      148, "I32")
	HK_F (s, "stNumberAverages",   152, "I32")
	HK_F (s, "stActualAdcChannels",156, "I32")
	HK_F (s, "stActualDacChannels",160, "I32")
	HK_F (s, "stExtTrigger",       164, "I8")
	HK_F (s, "stNoStartWait",      165, "I8")
	HK_F (s, "stUseScanRates",     166, "I8")
	HK_F (s, "stNoContAq",         167, "I8")
	HK_F (s, "stHasLockIn",        168, "I8")
	HK_F (s, "stAutoRange",        171, "I8")
	HK_F (s, "stBreakNext",        172, "I8")
	HK_F (s, "stIsExpanded",       173, "I8")
	HK_F (s, "stLeakCompMode",     174, "I8")
	HK_F (s, "stHasChirp",         175, "I8")
	HK_F (s, "stIsGapFree",        240, "I8")
	HK_F (s, "stHandledExternally",241, "I8")
	HK_F (s, "stCRC",              244, "U32")
	return s
End

static Function/S HK_Def_pgf_2()				// Channel
	String s = ""
	HK_F (s, "chMark",               0, "I32")
	HK_F (s, "chLinkedChannel",      4, "I32")
	HK_F (s, "chCompressionFactor",  8, "I32")
	HK_FN(s, "chYUnit",             12, "STR", 8)
	HK_F (s, "chAdcChannel",        20, "I16")
	HK_F (s, "chAdcMode",           22, "I8")
	HK_F (s, "chDoWrite",           23, "I8")
	HK_F (s, "chLeakStore",         24, "I8")
	HK_F (s, "chAmplMode",          25, "I8")
	HK_F (s, "chOwnSegTime",        26, "I8")
	HK_F (s, "chSetLastSegVmemb",   27, "I8")
	HK_F (s, "chDacChannel",        28, "I16")
	HK_F (s, "chDacMode",           30, "I8")
	HK_F (s, "chHasLockInSquare",   31, "I8")
	HK_F (s, "chRelevantXSegment",  32, "I32")
	HK_F (s, "chRelevantYSegment",  36, "I32")
	HK_FN(s, "chDacUnit",           40, "STR", 8)
	HK_F (s, "chHolding",           48, "R8")
	HK_F (s, "chLeakHolding",       56, "R8")
	HK_F (s, "chLeakSize",          64, "R8")
	HK_F (s, "chLeakHoldMode",      72, "I8")
	HK_F (s, "chLeakAlternate",     73, "I8")
	HK_F (s, "chAltLeakAveraging",  74, "I8")
	HK_F (s, "chLeakPulseOn",       75, "I8")
	HK_F (s, "chStimToDacID",       76, "S16")
	HK_F (s, "chCompressionMode",   78, "S16")
	HK_F (s, "chCompressionSkip",   80, "I32")
	HK_F (s, "chDacBit",            84, "I16")
	HK_F (s, "chHasLockInSine",     86, "I8")
	HK_F (s, "chBreakMode",         87, "I8")
	HK_F (s, "chZeroSeg",           88, "I32")
	HK_F (s, "chStimSweep",         92, "I32")
	HK_F (s, "chSine_Cycle",        96, "R8")
	HK_F (s, "chSine_Amplitude",   104, "R8")
	HK_F (s, "chLockIn_VReversal", 112, "R8")
	HK_F (s, "chChirp_StartFreq",  120, "R8")
	HK_F (s, "chChirp_EndFreq",    128, "R8")
	HK_F (s, "chChirp_MinPoints",  136, "R8")
	HK_F (s, "chSquare_NegAmpl",   144, "R8")
	HK_F (s, "chSquare_DurFactor", 152, "R8")
	HK_F (s, "chLockIn_Skip",      160, "I32")
	HK_F (s, "chPhoto_MaxCycles",  164, "I32")
	HK_F (s, "chPhoto_SegmentNo",  168, "I32")
	HK_F (s, "chLockIn_AvgCycles", 172, "I32")
	HK_F (s, "chImaging_RoiNo",    176, "I32")
	HK_F (s, "chChirp_Skip",       180, "I32")
	HK_F (s, "chChirp_Amplitude",  184, "R8")
	HK_F (s, "chPhoto_Adapt",      192, "I8")
	HK_F (s, "chSine_Kind",        193, "I8")
	HK_F (s, "chChirp_PreChirp",   194, "I8")
	HK_F (s, "chSine_Source",      195, "I8")
	HK_F (s, "chSquare_NegSource", 196, "I8")
	HK_F (s, "chSquare_PosSource", 197, "I8")
	HK_F (s, "chChirp_Kind",       198, "I8")
	HK_F (s, "chChirp_Source",     199, "I8")
	HK_F (s, "chDacOffset",        200, "R8")
	HK_F (s, "chAdcOffset",        208, "R8")
	HK_F (s, "chTraceMathFormat",  216, "I8")
	HK_F (s, "chHasChirp",         217, "I8")
	HK_F (s, "chSquare_Kind",      218, "I8")
	HK_F (s, "chSquare_BaseIncr",  224, "R8")
	HK_F (s, "chSquare_Cycle",     232, "R8")
	HK_F (s, "chSquare_PosAmpl",   240, "R8")
	HK_F (s, "chCompressionOffset",248, "I32")
	HK_F (s, "chPhotoMode",        252, "I32")
	HK_F (s, "chBreakLevel",       256, "R8")
	HK_FN(s, "chTraceMath",        264, "STR", 128)
	HK_F (s, "chCRC",              396, "U32")
	return s
End

static Function/S HK_Def_pgf_3()				// StimSegment
	String s = ""
	HK_F (s, "seMark",              0, "I32")
	HK_F (s, "seClass",             4, "I8")
	HK_F (s, "seStoreKind",         5, "I8")
	HK_F (s, "seVoltageIncMode",    6, "I8")
	HK_F (s, "seDurationIncMode",   7, "I8")
	HK_F (s, "seVoltage",           8, "R8")
	HK_F (s, "seVoltageSource",    16, "I32")
	HK_F (s, "seDeltaVFactor",     20, "R8")
	HK_F (s, "seDeltaVIncrement",  28, "R8")
	HK_F (s, "seDuration",         36, "R8")
	HK_F (s, "seDurationSource",   44, "I32")
	HK_F (s, "seDeltaTFactor",     48, "R8")
	HK_F (s, "seDeltaTIncrement",  56, "R8")
	HK_F (s, "seCRC",              68, "U32")
	HK_F (s, "seScanRate",         72, "R8")
	return s
End

// ------------------------------ .amp  (amplifier tree) -------------------------------
static Function/S HK_Def_amp_0()
	String s = ""
	HK_F (s, "RoVersion",       0, "I32")
	HK_F (s, "RoMark",          4, "I32")
	HK_FN(s, "RoVersionName",   8, "STR", 32)
	HK_FN(s, "RoAmplifierName",40, "STR", 32)
	HK_F (s, "RoAmplifier",    72, "C8")
	HK_F (s, "RoADBoard",      73, "C8")
	HK_F (s, "RoCreator",      74, "C8")
	HK_F (s, "RoCRC",          76, "U32")
	return s
End

static Function/S HK_Def_amp_1()
	String s = ""
	HK_F (s, "SeMark",        0, "I32")
	HK_F (s, "SeSeriesCount", 4, "I32")
	HK_F (s, "SeCRC",        12, "U32")
	return s
End

static Function/S HK_Def_amp_2()
	String s = ""
	HK_F (s, "AmMark",        0, "I32")
	HK_F (s, "AmStateCount",  4, "I32")
	HK_F (s, "AmStateVersion",8, "C8")
	HK_Def_LockIn(s,   16, "Lo_")
	HK_Def_AmplState(s,112, "Am_")
	HK_F (s, "AmIntSol",    512, "I32")
	HK_F (s, "AmExtSol",    516, "I32")
	HK_F (s, "AmCRC",       556, "U32")
	return s
End


// -------------------------------------------------------------------------------------
//  Definition table cache.  Built on first use, killed by HK_Scan.
//  Wave HK_Def_<which>_<level> : text, N x 4 = {name, offset, type, count}
// -------------------------------------------------------------------------------------
static Function HK_KillDefs()
	DFREF dfr = HK_Home()
	String lst = ""
	Variable i
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder dfr
	lst = WaveList("HK_Def_*", ";", "")
	for( i = 0; i < ItemsInList(lst); i += 1 )
		KillWaves/Z $StringFromList(i, lst)
	endfor
	SetDataFolder saveDF
End

static Function/WAVE HK_GetDef(which, level)
	String which
	Variable level

	DFREF dfr = HK_Home()
	String wName = "HK_Def_" + which + "_" + num2istr(level)
	Wave/T/Z/SDFR=dfr def = $wName
	if( WaveExists(def) )
		return def
	endif

	NVAR/Z fmtCode = dfr:HK_FormatCode
	Variable fc = 1000
	if( NVAR_Exists(fmtCode) )
		fc = fmtCode
	endif

	String s = ""
	strswitch( which + "_" + num2istr(level) )
		case "pul_0":
			s = HK_Def_pul_0()
			break
		case "pul_1":
			s = HK_Def_pul_1()
			break
		case "pul_2":
			s = HK_Def_pul_2(fc)
			break
		case "pul_3":
			s = HK_Def_pul_3()
			break
		case "pul_4":
			s = HK_Def_pul_4(fc)
			break
		case "pgf_0":
			s = HK_Def_pgf_0()
			break
		case "pgf_1":
			s = HK_Def_pgf_1()
			break
		case "pgf_2":
			s = HK_Def_pgf_2()
			break
		case "pgf_3":
			s = HK_Def_pgf_3()
			break
		case "amp_0":
			s = HK_Def_amp_0()
			break
		case "amp_1":
			s = HK_Def_amp_1()
			break
		case "amp_2":
			s = HK_Def_amp_2()
			break
	endswitch

	Variable n = ItemsInList(s)
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder dfr
	Make/O/T/N=(n, 4) $wName/WAVE=def2
	SetDataFolder saveDF

	SetDimLabel 1, 0, name,   def2
	SetDimLabel 1, 1, offset, def2
	SetDimLabel 1, 2, type,   def2
	SetDimLabel 1, 3, count,  def2

	Variable i
	String item
	for( i = 0; i < n; i += 1 )
		item       = StringFromList(i, s)
		def2[i][0] = StringFromList(0, item, ",")
		def2[i][1] = StringFromList(1, item, ",")
		def2[i][2] = StringFromList(2, item, ",")
		def2[i][3] = StringFromList(3, item, ",")
	endfor
	return def2
End

// Row index of a field in the definition table, or -1
static Function HK_DefRow(def, field)
	Wave/T def
	String field

	Variable i
	for( i = 0; i < DimSize(def,0); i += 1 )
		if( CmpStr(def[i][0], field, 0) == 0 )		// case-insensitive
			return i
		endif
	endfor
	return -1
End


// -------------------------------------------------------------------------------------
//  The generic value getter.  Everything below funnels through here.
// -------------------------------------------------------------------------------------
static Function HK_RawNum(bb, base, off, type, swap)
	Wave/B/U bb
	Variable base, off
	String type
	Variable swap

	Variable o = base + off
	strswitch( type )
		case "I32":
			return HK_I32(bb, o, swap)
		case "U32":
			return HK_U32(bb, o, swap)
		case "I64":
			return HK_I64(bb, o, swap)
		case "I16":
			return HK_I16(bb, o, swap)
		case "U16":
		case "S16":
			return HK_U16(bb, o, swap)
		case "I8":
		case "C8":
			return bb[o]
		case "R8":
			return HK_R8(bb, o, swap)
		case "R4":
			return HK_R4(bb, o, swap)
		case "TIM":
			return HK_PMTime2Igor( HK_R8(bb, o, swap) )
	endswitch
	return NaN
End


// =====================================================================================
//  PUBLIC READERS
// =====================================================================================

// Numeric value of a field.  NaN if the field name is unknown, or if the field lies
// beyond the record size that THIS file actually uses (older PatchMaster version).
Function HK_Num(node, field)
	Variable node
	String field
	return HK_NumI(node, field, 0)
End

// Element idx of an array field (idx = 0 for scalars).
Function HK_NumI(node, field, idx)
	Variable node
	String field
	Variable idx

	DFREF dfr = HK_Home()
	Wave/Z/B/U/SDFR=dfr bb  = HK_Bytes
	Wave/Z/SDFR=dfr     nd  = HK_Node
	Wave/Z/SDFR=dfr     lsz = HK_LevelSize
	NVAR/Z/SDFR=dfr     swap  = HK_Swap
	SVAR/Z/SDFR=dfr     which = HK_Which
	if( !WaveExists(bb) || !WaveExists(nd) || node < 0 || node >= DimSize(nd,0) )
		return NaN
	endif

	Variable level = nd[node][0]
	Wave/T def = HK_GetDef(which, level)
	Variable row = HK_DefRow(def, field)
	if( row < 0 )
		return NaN
	endif

	String type = def[row][2]
	if( CmpStr(type, "STR") == 0 )
		return NaN
	endif
	Variable off  = str2num(def[row][1]) + idx * HK_TypeSize(type)
	if( off + HK_TypeSize(type) > lsz[level] )		// not present in this file version
		return NaN
	endif
	return HK_RawNum(bb, nd[node][1], off, type, swap)
End

// Value as text: strings as strings, TIM as a readable date/time, numbers formatted,
// and a few enums translated to names.
Function/S HK_GetS(node, field)
	Variable node
	String field

	DFREF dfr = HK_Home()
	Wave/Z/B/U/SDFR=dfr bb  = HK_Bytes
	Wave/Z/SDFR=dfr     nd  = HK_Node
	Wave/Z/SDFR=dfr     lsz = HK_LevelSize
	NVAR/Z/SDFR=dfr     swap  = HK_Swap
	SVAR/Z/SDFR=dfr     which = HK_Which
	if( !WaveExists(bb) || !WaveExists(nd) || node < 0 || node >= DimSize(nd,0) )
		return ""
	endif

	Variable level = nd[node][0]
	Wave/T def = HK_GetDef(which, level)
	Variable row = HK_DefRow(def, field)
	if( row < 0 )
		return ""
	endif

	String type = def[row][2]
	Variable off = str2num(def[row][1])
	Variable cnt = str2num(def[row][3])

	if( CmpStr(type, "STR") == 0 )
		if( off + cnt > lsz[level] )
			return ""
		endif
		return HK_CStr(bb, nd[node][1] + off, cnt)
	endif

	if( off + HK_TypeSize(type) > lsz[level] )
		return "<absent>"
	endif

	Variable v = HK_RawNum(bb, nd[node][1], off, type, swap)

	if( CmpStr(type, "TIM") == 0 )
		return Secs2Date(v, 2) + " " + Secs2Time(v, 3)
	endif
	if( CmpStr(type, "C8") == 0 )
		return SelectString(v >= 32 && v < 127, num2istr(v), num2char(v))
	endif

	String en = HK_EnumName(def[row][0], v)
	if( strlen(en) )
		return num2str(v) + " (" + en + ")"
	endif

	if( cnt > 1 )								// show the first few array elements
		String out = ""
		Variable i, nShow = min(cnt, 6)
		for( i = 0; i < nShow; i += 1 )
			out += num2str( HK_NumI(node, field, i) ) + SelectString(i < nShow-1, "", ", ")
		endfor
		return out + SelectString(cnt > nShow, "", ", ...") + "   [" + num2istr(cnt) + " elements]"
	endif
	return num2str(v)
End

// Human-readable names for the enums that matter most.  Returns "" if not an enum.
static Function/S HK_EnumName(field, v)
	String field
	Variable v

	String lst = ""
	strswitch( field )
		case "TrRecordingMode":
			lst = "InOut;OnCell;OutOut;WholeCell;CClamp;VClamp;NoMode"
			break
		case "TrDataFormat":
			lst = "int16;int32;real32;real64"
			break
		case "TrDataAbscissa":
			lst = "Time;Segment"
			break
		case "Am_Mode":
			lst = "TestMode;VCMode;CCMode;NoMode"
			break
		case "Am_AmplKind":
			lst = "Epc7;Epc8;Epc9;Epc10;Epc10Plus"
			break
		case "Am_ADBoard":
			lst = "ITC16;ITC18;LIH1600"
			break
		case "seClass":
			lst = "Constant;Ramp;Continuous;ConstSine;Squarewave;Chirpwave"
			break
		case "seStoreKind":
			lst = "SegNoStore;SegStore;SegStoreStart;SegStoreEnd"
			break
		case "chAdcMode":
			lst = "AdcOff;Analog;Digitals;Digital;AdcVirtual"
			break
		case "chAmplMode":
			lst = "AnyAmplMode;VCAmplMode;CCAmplMode;IDensityMode"
			break
		case "chLeakStore":
			lst = "LNone;LStoreAvg;LStoreEach;LNoStore"
			break
		case "chBreakMode":
			lst = "NoBreak;BreakPos;BreakNeg"
			break
		case "stExtTrigger":
			lst = "TrigNone;TrigSeries;TrigSweep;TrigSweepNoLeak"
			break
		case "stAutoRange":
			lst = "Off;Peak;Mean;RelSeg"
			break
	endswitch
	if( strlen(lst) == 0 || v < 0 || v >= ItemsInList(lst) || v != trunc(v) )
		return ""
	endif
	return StringFromList(v, lst)
End


// ";"-list of every field name defined at a level.  Defaults to the current tree and,
// if level is not given, level 4 (trace) for .pul.
Function/S HK_FieldList([which, level])
	String which
	Variable level

	DFREF dfr = HK_Home()
	SVAR/Z/SDFR=dfr w = HK_Which
	if( ParamIsDefault(which) )
		which = SelectString( SVAR_Exists(w), "pul", w )
	endif
	if( ParamIsDefault(level) )
		level = 4
	endif

	Wave/T def = HK_GetDef(which, level)
	String out = ""
	Variable i
	for( i = 0; i < DimSize(def,0); i += 1 )
		out += def[i][0] + ";"
	endfor
	return out
End


// Print every field of one record, with values.  Fields absent from this file
// version are marked <absent> so you can see immediately what your version stores.
Function HK_Dump(node)
	Variable node

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd  = HK_Node
	Wave/Z/SDFR=dfr lsz = HK_LevelSize
	SVAR/Z/SDFR=dfr which = HK_Which
	if( !WaveExists(nd) || node < 0 || node >= DimSize(nd,0) )
		Print "HK_Dump: no such node."
		return -1
	endif

	Variable level = nd[node][0]
	String names = "Root;Group;Series;Sweep;Trace;L5;L6;L7"
	if( CmpStr(which, "pgf") == 0 )
		names = "Root;Stimulation;Channel;StimSegment"
	elseif( CmpStr(which, "amp") == 0 )
		names = "Root;Series;AmplState"
	endif

	Printf "==== %s  node %d  (level %d)  file offset %d  children %d ====\r", StringFromList(level, names), node, level, HK_Offset(node), nd[node][3]
	Printf "     record size in this file: %d bytes\r", lsz[level]

	Wave/T def = HK_GetDef(which, level)
	Variable i
	for( i = 0; i < DimSize(def,0); i += 1 )
		Printf "  %-24s = %s\r", def[i][0], HK_GetS(node, def[i][0])
	endfor
	return 0
End


// -------------------------------------------------------------------------------------
//  Bulk extraction: one field, every node at a level, into a wave.
//  e.g.  HK_Collect(4, "TrCSlow",  "CSlow")     -> makes wave CSlow  (one point per trace)
//        HK_Collect(2, "Am_CSlow", "CSlow_se")  -> one point per series
//  Also makes <destName>_node, the node index of each row, so you can go back.
// -------------------------------------------------------------------------------------
Function/WAVE HK_Collect(level, field, destName)
	Variable level
	String field, destName

	DFREF dfr = HK_Home()
	Wave/Z/B/U/SDFR=dfr bb  = HK_Bytes
	Wave/Z/SDFR=dfr     nd  = HK_Node
	Wave/Z/SDFR=dfr     lsz = HK_LevelSize
	NVAR/Z/SDFR=dfr     swap  = HK_Swap
	SVAR/Z/SDFR=dfr     which = HK_Which
	if( !WaveExists(nd) )
		Print "HK_Collect: run HK_Scan() first."
		return $""
	endif

	Wave/T def   = HK_GetDef(which, level)
	Variable row = HK_DefRow(def, field)
	if( row < 0 )
		Printf "HK_Collect: no field \"%s\" at level %d.\r", field, level
		return $""
	endif
	String type = def[row][2]
	if( CmpStr(type, "STR") == 0 )
		Print "HK_Collect: that is a text field -- use HK_CollectT."
		return $""
	endif
	Variable off = str2num(def[row][1])
	if( off + HK_TypeSize(type) > lsz[level] )
		Printf "HK_Collect: field \"%s\" is not present in this file version.\r", field
		return $""
	endif

	Variable i, n = 0, tot = DimSize(nd,0)
	Make/O/D/N=(tot) $destName/WAVE=out
	Make/O/D/N=(tot) $(destName+"_node")/WAVE=nodes
	for( i = 0; i < tot; i += 1 )
		if( nd[i][0] != level )
			continue
		endif
		out[n]   = HK_RawNum(bb, nd[i][1], off, type, swap)
		nodes[n] = i
		n += 1
	endfor
	Redimension/N=(n) out, nodes
	Printf "HK_Collect: %s = %s of %d level-%d records.\r", destName, field, n, level
	return out
End

Function/WAVE HK_CollectT(level, field, destName)
	Variable level
	String field, destName

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) )
		Print "HK_CollectT: run HK_Scan() first."
		return $""
	endif

	Variable i, n = 0, tot = DimSize(nd,0)
	Make/O/T/N=(tot) $destName/WAVE=out
	Make/O/D/N=(tot) $(destName+"_node")/WAVE=nodes
	for( i = 0; i < tot; i += 1 )
		if( nd[i][0] != level )
			continue
		endif
		out[n]   = HK_GetS(i, field)
		nodes[n] = i
		n += 1
	endfor
	Redimension/N=(n) out, nodes
	Printf "HK_CollectT: %s = %s of %d level-%d records.\r", destName, field, n, level
	return out
End


// =====================================================================================
//  SELF TEST  --  reads a handful of fields two independent ways and compares:
//     (a) the in-memory IEEE-754 decoder used above
//     (b) GBLoadWave straight from the file, i.e. the method your v2.3 code uses
//  Any mismatch is printed.  Run this once after HK_Scan on a real file.
// =====================================================================================
Function HK_SelfTest()

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	SVAR/Z/SDFR=dfr path  = HK_Path
	SVAR/Z/SDFR=dfr which = HK_Which
	if( !WaveExists(nd) || CmpStr(which, "pul") != 0 )
		Print "HK_SelfTest: run HK_Scan(\"\") on the .pul block first."
		return -1
	endif

	String dblFields = "TrDataScaler;TrXInterval;TrXStart;TrYmin;TrYmax;TrZeroData;TrCSlow;TrGSeries;TrRsValue;TrTrHolding"
	// TrData / TrDataPoints are INT64 on PatchMaster NEXT and GBLoadWave has no 64-bit
	// integer type, so they are checked by HK_VerifyData() instead -- which is a
	// stronger test anyway (it proves the offsets tile the .dat block exactly).
	String i32Fields = "TrTraceID;TrInterleaveSize;TrInterleaveSkip"

	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder dfr

	Variable i, k, node, off, a, b, bad = 0, tested = 0
	String f

	// test 25 traces spread evenly through the file
	Variable nTr = 0
	for( i = 0; i < DimSize(nd,0); i += 1 )
		if( nd[i][0] == 4 )
			nTr += 1
		endif
	endfor
	Variable step = max(1, floor(nTr/25))

	Variable seen = 0, done = 0
	for( i = 0; i < DimSize(nd,0) && done < 25; i += 1 )
		if( nd[i][0] != 4 )
			continue
		endif
		seen += 1
		if( mod(seen, step) != 0 )
			continue
		endif
		done += 1
		node = i
		off  = HK_Offset(node)

		for( k = 0; k < ItemsInList(dblFields); k += 1 )
			f = StringFromList(k, dblFields)
			a = HK_Num(node, f)
			b = HK_GB(path, off + HK_FieldOffset("pul", 4, f), 4)
			tested += 1
			if( !HK_Same(a, b) )
				Printf "  MISMATCH node %d  %s : decoder=%.17g  GBLoadWave=%.17g\r", node, f, a, b
				bad += 1
			endif
		endfor
		for( k = 0; k < ItemsInList(i32Fields); k += 1 )
			f = StringFromList(k, i32Fields)
			a = HK_Num(node, f)
			b = HK_GB(path, off + HK_FieldOffset("pul", 4, f), 32)
			tested += 1
			if( !HK_Same(a, b) )
				Printf "  MISMATCH node %d  %s : decoder=%g  GBLoadWave=%g\r", node, f, a, b
				bad += 1
			endif
		endfor
	endfor

	KillWaves/Z HK_TestTmp0
	SetDataFolder saveDF
	Printf "HK_SelfTest: %d values compared against GBLoadWave -- %s\r", tested, SelectString(bad == 0, num2istr(bad) + " MISMATCHES", "all identical")
	return bad
End


// =====================================================================================
//  HK_VerifyData -- checks TrData / TrDataPoints / TrDataFormat against the .dat block.
//
//  This is the regression test for the PatchMaster NEXT change.  For every trace it
//  works out the byte range the samples occupy and checks that
//     (a) the range lies inside the .dat block, and
//     (b) consecutive non-interleaved traces tile the block without gaps or overlaps.
//  If TrData or TrDataPoints were being read at the wrong offset or the wrong width,
//  (b) fails immediately -- so "tiles exactly" is strong evidence the record layout is
//  right, without needing a 64-bit reader in GBLoadWave.
// =====================================================================================
Function HK_VerifyData()

	DFREF dfr = HK_Home()
	Wave/Z/SDFR=dfr nd = HK_Node
	SVAR/Z which = dfr:HK_Which
	if( !WaveExists(nd) || CmpStr(which, "pul") != 0 )
		Print "HK_VerifyData: run HK_Scan(\"\") on the .pul block first."
		return -1
	endif

	Variable idx = HK_ItemIndex(".dat")
	if( idx < 0 )
		Print "HK_VerifyData: no .dat block in this bundle."
		return -1
	endif
	Wave/SDFR=dfr iStart = HK_ItemStart
	Wave/SDFR=dfr iLen   = HK_ItemLength
	Variable datStart = iStart[idx]
	Variable datEnd   = datStart + iLen[idx]

	Variable i, fmt, bps, dOff, npnts, dEnd
	Variable nTr = 0, outside = 0, gaps = 0, overlaps = 0, interleaved = 0
	Variable prevEnd = -1
	String lst = "2;4;4;8"						// bytes per sample for fmt 0..3

	for( i = 0; i < DimSize(nd,0); i += 1 )
		if( nd[i][0] != 4 )
			continue
		endif
		nTr += 1
		fmt   = HK_Num(i, "TrDataFormat")
		dOff  = HK_Num(i, "TrData")
		npnts = HK_Num(i, "TrDataPoints")
		if( fmt < 0 || fmt > 3 )
			Printf "  node %d: TrDataFormat = %g is not 0..3\r", i, fmt
			outside += 1
			continue
		endif
		bps  = str2num(StringFromList(fmt, lst))
		dEnd = dOff + npnts*bps

		if( dOff < datStart || dEnd > datEnd )
			Printf "  node %d (%s): data %g..%g lies outside the .dat block %g..%g\r", i, HK_Label(i), dOff, dEnd, datStart, datEnd
			outside += 1
			continue
		endif
		if( HK_Num(i, "TrInterleaveSize") > 0 )
			interleaved += 1
			prevEnd = -1						// tiling test does not apply
			continue
		endif
		if( prevEnd >= 0 )
			if( dOff > prevEnd )
				gaps += 1
			elseif( dOff < prevEnd )
				overlaps += 1
			endif
		endif
		prevEnd = dEnd
	endfor

	Printf "HK_VerifyData: %d traces, .dat block %g..%g (%g bytes)\r", nTr, datStart, datEnd, datEnd-datStart
	Printf "   outside block : %d\r", outside
	Printf "   gaps          : %d\r", gaps
	Printf "   overlaps      : %d\r", overlaps
	if( interleaved )
		Printf "   interleaved   : %d  (excluded from the tiling test)\r", interleaved
	endif
	if( outside == 0 && overlaps == 0 )
		Print "   -> TrData / TrDataPoints / TrDataFormat are being read correctly."
	else
		Print "   -> LAYOUT PROBLEM: the trace record is not being decoded correctly."
	endif
	return outside + overlaps
End

static Function HK_Same(a, b)
	Variable a, b
	if( numtype(a) != 0 || numtype(b) != 0 )
		return numtype(a) == numtype(b)
	endif
	if( a == b )
		return 1
	endif
	return abs(a-b) <= 1e-12 * max(abs(a), abs(b))
End

static Function HK_GB(path, offset, gbType)
	String path
	Variable offset, gbType
	GBLoadWave/B/Q/T={gbType, 4}/W=1/U=1/S=(offset)/N=HK_TestTmp/O=1 path
	Wave w = HK_TestTmp0
	return w[0]
End

static Function HK_FieldOffset(which, level, field)
	String which
	Variable level
	String field
	Wave/T def = HK_GetDef(which, level)
	Variable row = HK_DefRow(def, field)
	if( row < 0 )
		return NaN
	endif
	return str2num(def[row][1])
End
