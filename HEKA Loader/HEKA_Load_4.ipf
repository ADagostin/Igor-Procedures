#pragma TextEncoding = "UTF-8"
#pragma rtGlobals = 3
#pragma IgorVersion = 7.00

// =====================================================================================
//  HEKA_Load_4.ipf   --  trace loading + stimulus reconstruction
//  Andre Dagostin / Vollum Institute
//
//  Requires HEKA_Tree_V2.ipf.  Uses only its public API, so the two
//  files stay independent -- you can recompile either one without touching the other.
//
//  WHAT THIS FIXES vs. Load_HEKA 2.3
//  ---------------------------------
//  1. NUMBER FORMAT.  v2.3 switches on TrDataKind (offset 64) with "case 5 / case 17".
//     TrDataKind is a SET16 of FLAGS -- LittleEndian, IsLeak, IsVirtual, IsImon,
//     IsVmon, Clip -- it says nothing about the number format.  The format is
//     TrDataFormat at offset 70:  0=int16, 1=int32, 2=real32, 3=real64.
//     "case 5" worked only because those flag combinations happened to co-occur with
//     float data on your rig.  A leak trace or a clipped trace would break it.
//
//  2. INTERLEAVING.  v2.3 builds Inter0, Inter1, ... then concatenates them with
//     WaveList("inter*"), which sorts ALPHABETICALLY -- so Inter10 lands before
//     Inter2 and any recording with more than 10 blocks is silently scrambled.
//     It also computes the block length as TrInterleaveSize/Num_Traces, but
//     TrInterleaveSize is already in BYTES and already refers to this trace alone
//     (DataFile_v9.txt 3.2).  And the "delete point 0" / "trim extra points" fixups
//     become unnecessary once the block arithmetic is right.
//
//  3. AXIS SCALING.  v2.3 ends with SetScale/i y,... on a 1D wave.  For a 1D wave the
//     y dimension does not exist; the data scaling is dimension "d".
//
//  QUICK TEST
//      HK_Scan("")
//      HK_TraceInfo( HK_Node4(0,0,0,0) )            // what the record actually says
//      Wave w = HK_LoadTrace( HK_Node4(0,0,0,0) )   // load it
//      HK_Plot( HK_Node4(0,0,0,0) )                 // load + display
//      HK_LoadSweep( HK_Node4(0,0,0,-1) )           // every trace of one sweep
//      HK_LoadSeries2D( HK_Node4(0,0,-1,-1), 0, "Se1_Tr1" )   // series -> 2D wave
//      HK_CompareOld( HK_Node4(0,0,0,0) )           // new loader vs. your v2.3 path
//
//  MAIN ENTRY POINTS
//      HK_LoadTrace(node [, destName, zeroSub])   -> wave reference
//      HK_LoadSweep(sweepNode [, zeroSub])        -> loads every trace of that sweep
//      HK_LoadSeries2D(seriesNode, traceIdx, destName [, zeroSub])
//      HK_TraceInfo(node)                         -> prints the decoded record
//      HK_Plot(node)                              -> load and display
// =====================================================================================


static StrConstant kHKL_DF  = "root:Packages:HEKA"
static StrConstant kHKL_TMP = "root:Packages:HEKA:tmp"

// TrDataKind bit numbers (PulsedFile_v9.txt)
static Constant kHKL_LittleEndianBit = 0
static Constant kHKL_IsLeak          = 1
static Constant kHKL_IsVirtual       = 2
static Constant kHKL_IsImon          = 3
static Constant kHKL_IsVmon          = 4
static Constant kHKL_Clip            = 5


// -------------------------------------------------------------------------------------
//  Format helpers
// -------------------------------------------------------------------------------------

// TrDataFormat -> bytes per sample
static Function HKL_BytesPerSample(fmt)
	Variable fmt

	switch( fmt )
		case 0:
			return 2			// int16
		case 1:
			return 4			// int32
		case 2:
			return 4			// real32
		case 3:
			return 8			// real64
	endswitch
	return NaN
End

// TrDataFormat -> GBLoadWave file numeric type code
static Function HKL_GBType(fmt)
	Variable fmt

	switch( fmt )
		case 0:
			return 16			// 16-bit signed integer
		case 1:
			return 32			// 32-bit signed integer
		case 2:
			return 2			// 32-bit float
		case 3:
			return 4			// 64-bit float
	endswitch
	return NaN
End

Function/S HK_DataFormatName(fmt)
	Variable fmt

	String lst = "int16;int32;real32;real64"
	if( fmt < 0 || fmt >= ItemsInList(lst) )
		return "unknown(" + num2str(fmt) + ")"
	endif
	return StringFromList(fmt, lst)
End

// Decoded TrDataKind flags as readable text
Function/S HK_DataKindFlags(kind)
	Variable kind

	String s = ""
	if( kind & 2^kHKL_LittleEndianBit )
		s += "LittleEndian,"
	else
		s += "BigEndian,"
	endif
	if( kind & 2^kHKL_IsLeak )
		s += "IsLeak,"
	endif
	if( kind & 2^kHKL_IsVirtual )
		s += "IsVirtual,"
	endif
	if( kind & 2^kHKL_IsImon )
		s += "IsImon,"
	endif
	if( kind & 2^kHKL_IsVmon )
		s += "IsVmon,"
	endif
	if( kind & 2^kHKL_Clip )
		s += "Clip,"
	endif
	return RemoveEnding(s, ",")
End

Function HK_IsLeakTrace(node)
	Variable node
	return ( HK_Num(node, "TrDataKind") & 2^kHKL_IsLeak ) != 0
End

Function HK_IsVirtualTrace(node)
	Variable node
	return ( HK_Num(node, "TrDataKind") & 2^kHKL_IsVirtual ) != 0
End


// -------------------------------------------------------------------------------------
//  Where a node sits in the hierarchy: 0-based index among its siblings
// -------------------------------------------------------------------------------------
Function HK_SiblingIndex(node)
	Variable node

	DFREF dfr = $kHKL_DF
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) || node <= 0 || node >= DimSize(nd,0) )
		return -1
	endif
	Variable parent = nd[node][2]
	if( parent < 0 )
		return 0
	endif
	Variable c = nd[parent][4]
	Variable k = 0
	do
		if( c == node )
			return k
		endif
		c = nd[c][5]
		k += 1
	while( c >= 0 )
	return -1
End

// "1_2_3_1" style path for a trace node (1-based, the way PatchMaster displays it)
Function/S HK_PathString(node)
	Variable node

	DFREF dfr = $kHKL_DF
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) || node < 0 )
		return ""
	endif
	String s = ""
	Variable n = node
	do
		if( nd[n][0] == 0 )
			break
		endif
		s = num2istr( HK_SiblingIndex(n) + 1 ) + SelectString(strlen(s), "", "_") + s
		n = nd[n][2]
	while( n > 0 )
	return s
End


// -------------------------------------------------------------------------------------
//  Scratch data folder for GBLoadWave (it always builds into the current folder)
// -------------------------------------------------------------------------------------
static Function/DF HKL_Tmp()
	DFREF nulldf = $""
	if( !DataFolderExists(kHKL_DF) )
		Print "HEKA_Load: run HK_Scan() first."
		return nulldf
	endif
	if( !DataFolderExists(kHKL_TMP) )
		NewDataFolder $kHKL_TMP
	endif
	DFREF dfr = $kHKL_TMP
	return dfr
End


// =====================================================================================
//  HK_TraceInfo -- print exactly what the record says, before loading anything.
//  This is the quickest way to see that TrDataFormat and TrDataKind are different
//  things, and what your files actually contain.
// =====================================================================================
Function HK_TraceInfo(node)
	Variable node

	if( HK_Level(node) != 4 )
		Print "HK_TraceInfo: that node is not a trace (level 4)."
		return -1
	endif

	Variable fmt   = HK_Num(node, "TrDataFormat")
	Variable kind  = HK_Num(node, "TrDataKind")
	Variable npnts = HK_Num(node, "TrDataPoints")
	Variable bps   = HKL_BytesPerSample(fmt)
	Variable isize = HK_Num(node, "TrInterleaveSize")
	Variable iskip = HK_Num(node, "TrInterleaveSkip")

	Printf "---- trace %s  (node %d)  \"%s\" ----\r", HK_PathString(node), node, HK_Label(node)
	Printf "  TrDataFormat   = %g  -> %s  (%g bytes/sample)\r", fmt, HK_DataFormatName(fmt), bps
	Printf "  TrDataKind     = %g  -> %s\r", kind, HK_DataKindFlags(kind)
	Printf "  TrData         = %g   (byte offset in the .dat file)\r", HK_Num(node, "TrData")
	Printf "  TrDataPoints   = %g   -> %g bytes of raw data\r", npnts, npnts*bps
	Printf "  TrDataScaler   = %.10g      TrZeroData = %.10g\r", HK_Num(node, "TrDataScaler"), HK_Num(node, "TrZeroData")
	Printf "  TrXStart       = %.10g      TrXInterval = %.10g  [%s]\r", HK_Num(node, "TrXStart"), HK_Num(node, "TrXInterval"), HK_GetS(node, "TrXUnit")
	Printf "  TrYUnit        = %s          TrUseXStart = %g\r", HK_GetS(node, "TrYUnit"), HK_Num(node, "TrUseXStart")
	Printf "  TrRecordingMode= %s\r", HK_GetS(node, "TrRecordingMode")
	if( isize > 0 )
		Printf "  INTERLEAVED    : TrInterleaveSize = %g bytes (%g points/block), TrInterleaveSkip = %g bytes\r", isize, isize/bps, iskip
		Printf "                   -> %g blocks\r", ceil( npnts / (isize/bps) )
	else
		Printf "  contiguous     : TrInterleaveSize = 0\r"
	endif
	return 0
End


// =====================================================================================
//  HK_LoadTrace -- the real thing.
//      node      : a level-4 (trace) node index
//      destName  : optional output wave name; default is built from the hierarchy
//      zeroSub   : optional; 1 = also subtract TrZeroData (see note below)
//  Returns a wave reference (null on failure).
//
//  NOTE on TrZeroData.  FileFormat.txt: trace data are stored LEAK SUBTRACTED but NOT
//  ZERO SUBTRACTED, and you subtract ZeroCurrent from the scaled trace to obtain the
//  zero-subtracted trace.  That is what zeroSub=1 does.  The default is 0, which
//  reproduces what PatchMaster shows and what your v2.3 code produced -- so your
//  existing analyses do not change unless you ask for it.
// =====================================================================================
Function/WAVE HK_LoadTrace(node, [destName, zeroSub])
	Variable node
	String destName
	Variable zeroSub

	if( ParamIsDefault(zeroSub) )
		zeroSub = 0
	endif

	if( HK_Level(node) != 4 )
		Print "HK_LoadTrace: that node is not a trace (level 4)."
		return $""
	endif

	DFREF dfr = $kHKL_DF
	SVAR/Z/SDFR=dfr scanned = HK_Path
	if( !SVAR_Exists(scanned) )
		Print "HK_LoadTrace: run HK_Scan() first."
		return $""
	endif
	// The samples live in the bundle itself, or in the companion .dat of an unbundled
	// set.  TrData is an absolute offset into that file in both cases.
	String path = HK_DataFile()
	if( strlen(path) == 0 )
		Print "HK_LoadTrace: this recording has no .dat raw-data file."
		return $""
	endif

	// ---- record fields -------------------------------------------------------------
	Variable dataOff = HK_Num(node, "TrData")
	Variable npnts   = HK_Num(node, "TrDataPoints")
	Variable fmt     = HK_Num(node, "TrDataFormat")
	Variable scaler  = HK_Num(node, "TrDataScaler")
	Variable zeroDat = HK_Num(node, "TrZeroData")
	Variable xStart  = HK_Num(node, "TrXStart")
	Variable xDelta  = HK_Num(node, "TrXInterval")
	Variable isize   = HK_Num(node, "TrInterleaveSize")
	Variable iskip   = HK_Num(node, "TrInterleaveSkip")
	String   xUnit   = HK_GetS(node, "TrXUnit")
	String   yUnit   = HK_GetS(node, "TrYUnit")

	Variable bps    = HKL_BytesPerSample(fmt)
	Variable gbType = HKL_GBType(fmt)
	if( numtype(bps) != 0 )
		Printf "HK_LoadTrace: unknown TrDataFormat = %g.\r", fmt
		return $""
	endif
	if( npnts <= 0 )
		Printf "HK_LoadTrace: TrDataPoints = %g, nothing to load.\r", npnts
		return $""
	endif

	// The GBLoadWave flag set below is the one HK_SelfTest validated byte-for-byte
	// against the in-memory decoder on a little-endian (Windows / Intel Mac) file.
	// Old big-endian PowerPC Mac files are flagged here rather than silently mis-read.
	NVAR/Z/SDFR=dfr swap = HK_Swap
	if( NVAR_Exists(swap) )
		if( swap != 0 )
			Print "HK_LoadTrace: WARNING -- this is a big-endian (PowerPC Mac) file. Raw-data byte order is untested; check the trace before trusting it."
		endif
	endif

	// PatchMaster NEXT widened TrData to INT64, which is the whole reason files may now
	// exceed 2 GB.  GBLoadWave's /S skip parameter is the limit we would hit first, so
	// say so plainly rather than returning a wrong trace.
	if( dataOff + npnts*HKL_BytesPerSample(fmt) > 2147483647 )
		Printf "HK_LoadTrace: trace %s starts at byte %.0f, beyond the 2 GB that GBLoadWave can skip to.\r", HK_PathString(node), dataOff
		Print  "              This file is larger than 2 GB; loading past that point needs a different reader."
		return $""
	endif

	// ---- output wave name ----------------------------------------------------------
	if( ParamIsDefault(destName) || strlen(destName) == 0 )
		String lbl = HK_Label(node)
		lbl = ReplaceString("mon-", lbl, "")
		lbl = ReplaceString("-", lbl, "_")
		lbl = ReplaceString(" ", lbl, "_")
		destName = CleanupName(HK_BaseName() + "_" + HK_PathString(node) + "_" + lbl, 0)
	endif

	Make/O/D/N=(npnts) $destName/WAVE=dest
	dest = NaN

	DFREF tmpDF  = HKL_Tmp()
	DFREF saveDF = GetDataFolderDFR()

	Variable ok   = 1
	Variable ppb  = npnts					// points per block; whole trace if contiguous
	Variable step = 0						// byte step between blocks; 0 if contiguous
	if( isize > 0 )
		// TrInterleaveSize : bytes in ONE block of THIS trace
		// TrInterleaveSkip : bytes from the start of one block to the start of the next
		ppb  = floor(isize / bps)
		step = iskip
		if( ppb < 1 )
			Printf "HK_LoadTrace: TrInterleaveSize=%g is smaller than one sample (%g bytes).\r", isize, bps
			KillWaves/Z dest
			return $""
		endif
		if( iskip < isize )
			Printf "HK_LoadTrace: warning -- TrInterleaveSkip (%g) < TrInterleaveSize (%g); blocks would overlap.\r", iskip, isize
		endif
	endif

	// ---- read the raw samples, block by block, into explicit index ranges -----------
	Variable done = 0
	Variable blk  = 0
	Variable cnt, vf
	do
		cnt = min(ppb, npnts - done)
		SetDataFolder tmpDF
		GBLoadWave/B/Q/T={gbType, 4}/W=1/U=(cnt)/S=(dataOff + blk*step)/N=HKLtmp/O path
		vf = V_flag
		SetDataFolder saveDF
		if( vf < 1 )
			Printf "HK_LoadTrace: GBLoadWave failed on block %g (offset %g).\r", blk, dataOff + blk*step
			ok = 0
			break
		endif
		Wave/SDFR=tmpDF blkRef = HKLtmp0
		dest[done, done+cnt-1] = blkRef[p - done]		// explicit index -- no WaveList sorting
		done += cnt
		blk  += 1
	while( done < npnts )

	Wave/Z/SDFR=tmpDF junk = HKLtmp0
	KillWaves/Z junk

	if( !ok )
		Print "HK_LoadTrace: read failed -- check that the file is still at " + path
		KillWaves/Z dest
		return $""
	endif

	// ---- scale ---------------------------------------------------------------------
	dest *= scaler
	if( zeroSub )
		dest -= zeroDat
	endif

	SetScale/P x, xStart, xDelta, xUnit, dest
	SetScale d, 0, 0, yUnit, dest						// "d" = data scaling; 1D waves have no y dim

	Note/K dest, "HEKA;\rnode=" + num2istr(node) + ";\rpath=" + HK_PathString(node)		\
		+ ";\rlabel=" + HK_Label(node) + ";\rformat=" + HK_DataFormatName(fmt)			\
		+ ";\rkind=" + HK_DataKindFlags(HK_Num(node, "TrDataKind"))					\
		+ ";\rscaler=" + num2str(scaler) + ";\rzeroData=" + num2str(zeroDat)			\
		+ ";\rzeroSubtracted=" + num2istr(zeroSub) + ";\r" + HK_TraceMetaNote(node)

	return dest
End


// =====================================================================================
//  Load every trace of one sweep.  Returns the number of traces loaded.
// =====================================================================================
Function HK_LoadSweep(sweepNode, [zeroSub])
	Variable sweepNode
	Variable zeroSub

	if( ParamIsDefault(zeroSub) )
		zeroSub = 0
	endif
	if( HK_Level(sweepNode) != 3 )
		Print "HK_LoadSweep: that node is not a sweep (level 3)."
		return -1
	endif

	Variable n = HK_NumChildren(sweepNode)
	Variable i, got = 0
	for( i = 0; i < n; i += 1 )
		Wave/Z w = HK_LoadTrace( HK_Child(sweepNode, i), zeroSub=zeroSub )
		if( WaveExists(w) )
			got += 1
		endif
	endfor
	Printf "HK_LoadSweep: %d of %d traces loaded.\r", got, n
	return got
End


// =====================================================================================
//  Load one trace index across every sweep of a series, into a 2D wave [point][sweep].
//  This is the shape most analyses want.  Sweeps of differing length are padded
//  with NaN and a warning is printed.
// =====================================================================================
Function/WAVE HK_LoadSeries2D(seriesNode, traceIdx, destName, [zeroSub])
	Variable seriesNode, traceIdx
	String destName
	Variable zeroSub

	if( ParamIsDefault(zeroSub) )
		zeroSub = 0
	endif
	if( HK_Level(seriesNode) != 2 )
		Print "HK_LoadSeries2D: that node is not a series (level 2)."
		return $""
	endif

	Variable nSw = HK_NumChildren(seriesNode)
	if( nSw <= 0 )
		Print "HK_LoadSeries2D: series has no sweeps."
		return $""
	endif

	// first pass: longest sweep, and check the trace index exists everywhere
	// NOTE: never name a local variable "p" here -- it would shadow the point index
	// used in the wave assignment further down.
	Variable i, sw, tr, npt, maxPnts = 0, missing = 0, ragged = 0, firstPnts = -1
	for( i = 0; i < nSw; i += 1 )
		sw = HK_Child(seriesNode, i)
		tr = HK_Child(sw, traceIdx)
		if( tr < 0 )
			missing += 1
			continue
		endif
		npt = HK_Num(tr, "TrDataPoints")
		if( firstPnts < 0 )
			firstPnts = npt
		elseif( npt != firstPnts )
			ragged = 1
		endif
		maxPnts = max(maxPnts, npt)
	endfor
	if( maxPnts <= 0 )
		Printf "HK_LoadSeries2D: no trace %d found in any sweep of this series.\r", traceIdx+1
		return $""
	endif
	if( missing )
		Printf "HK_LoadSeries2D: warning -- %d of %d sweeps have no trace %d.\r", missing, nSw, traceIdx+1
	endif
	if( ragged )
		Print "HK_LoadSeries2D: warning -- sweeps differ in length; short ones are NaN-padded."
	endif

	Make/O/D/N=(maxPnts, nSw) $destName/WAVE=dest
	dest = NaN

	DFREF tmpDF = HKL_Tmp()
	String tmpName = "HKL_one"
	DFREF saveDF = GetDataFolderDFR()

	Variable got = 0
	for( i = 0; i < nSw; i += 1 )
		sw = HK_Child(seriesNode, i)
		tr = HK_Child(sw, traceIdx)
		if( tr < 0 )
			continue
		endif
		SetDataFolder tmpDF
		Wave/Z one = HK_LoadTrace(tr, destName=tmpName, zeroSub=zeroSub)
		SetDataFolder saveDF
		if( !WaveExists(one) )
			continue
		endif
		dest[0, numpnts(one)-1][i] = one[p]
		if( got == 0 )
			SetScale/P x, DimOffset(one,0), DimDelta(one,0), WaveUnits(one,0), dest
			SetScale d, 0, 0, WaveUnits(one,-1), dest
		endif
		got += 1
	endfor
	KillWaves/Z tmpDF:$tmpName

	SetScale/P y, 1, 1, "sweep", dest
	Printf "HK_LoadSeries2D: %s = [%d points x %d sweeps], trace %d.\r", destName, maxPnts, got, traceIdx+1
	return dest
End


// =====================================================================================
//  Load and display
// =====================================================================================
Function HK_Plot(node)
	Variable node

	Wave/Z w = HK_LoadTrace(node)
	if( !WaveExists(w) )
		return -1
	endif
	Display/K=1 w
	ModifyGraph rgb=(0,0,0)
	Label bottom "\\u#2" + WaveUnits(w, 0)
	Label left   "\\u#2" + WaveUnits(w, -1)
	TextBox/C/N=info/A=LT/F=0 HK_PathString(node) + "  \"" + HK_Label(node) + "\""
	return 0
End


// =====================================================================================
//  HK_CompareOld -- loads one trace the new way and the v2.3 way side by side.
//  v2.3's format decision (switch on TrDataKind) is reproduced verbatim so you can
//  see whether it happens to agree on this file, and where it would not.
// =====================================================================================
Function HK_CompareOld(node)
	Variable node

	if( HK_Level(node) != 4 )
		Print "HK_CompareOld: that node is not a trace."
		return -1
	endif

	Variable kind = HK_Num(node, "TrDataKind")
	Variable fmt  = HK_Num(node, "TrDataFormat")

	// --- what v2.3 would have chosen ------------------------------------------------
	Variable oldType
	switch( kind )
		case 5:
			oldType = 2
			break
		case 17:
			oldType = 2
			break
		default:
			oldType = 16
	endswitch
	Variable newType = HKL_GBType(fmt)

	Printf "trace %s : TrDataKind=%g (%s), TrDataFormat=%g (%s)\r", HK_PathString(node), kind, HK_DataKindFlags(kind), fmt, HK_DataFormatName(fmt)
	Printf "   v2.3 would read as GBLoadWave type %g;  correct type is %g   ->  %s\r", oldType, newType, SelectString(oldType == newType, "WOULD HAVE BEEN WRONG", "same")

	// --- interleave arithmetic -------------------------------------------------------
	Variable isize = HK_Num(node, "TrInterleaveSize")
	if( isize > 0 )
		Variable bps    = HKL_BytesPerSample(fmt)
		Variable npnts  = HK_Num(node, "TrDataPoints")
		Variable nTrace = HK_NumChildren( HKL_Parent(node) )
		Printf "   interleaved: v2.3 block length = TrInterleaveSize/nTraces = %g/%g = %g points\r", isize, nTrace, isize/nTrace
		Printf "                correct block length = TrInterleaveSize/bytesPerSample = %g/%g = %g points\r", isize, bps, floor(isize/bps)
		Printf "                blocks = %g   (v2.3 concatenates by WaveList, which mis-orders past 10)\r", ceil(npnts/floor(isize/bps))
	endif
	return 0
End

static Function HKL_Parent(node)
	Variable node

	DFREF dfr = $kHKL_DF
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) || node < 0 || node >= DimSize(nd,0) )
		return -1
	endif
	return nd[node][2]
End


// =====================================================================================
//  HK_ScanDataFormats -- one line telling you every (TrDataFormat, TrDataKind,
//  interleave) combination present in the whole file.  Run it on a few of your
//  datasets: it shows immediately whether v2.3 has ever mis-read anything.
// =====================================================================================
Function HK_ScanDataFormats()

	DFREF dfr = $kHKL_DF
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) )
		Print "HK_ScanDataFormats: run HK_Scan() first."
		return -1
	endif

	Variable i, fmt, kind, isize, idx, n = 0
	String key, seen = ""
	Make/FREE/D/N=64 tally = 0

	for( i = 0; i < DimSize(nd,0); i += 1 )
		if( nd[i][0] != 4 )
			continue
		endif
		n += 1
		fmt   = HK_Num(i, "TrDataFormat")
		kind  = HK_Num(i, "TrDataKind")
		isize = HK_Num(i, "TrInterleaveSize")
		key = "fmt=" + num2istr(fmt) + " (" + HK_DataFormatName(fmt) + ")   kind=" + num2istr(kind) + " (" + HK_DataKindFlags(kind) + ")   interleaved=" + SelectString(isize > 0, "no", "yes")
		idx = WhichListItem(key, seen, "|")
		if( idx < 0 )
			idx = ItemsInList(seen, "|")
			if( idx >= numpnts(tally) )
				Redimension/N=(numpnts(tally)*2) tally
			endif
			seen += key + "|"
		endif
		tally[idx] += 1
	endfor

	Printf "HK_ScanDataFormats: %d traces, %d distinct combinations\r", n, ItemsInList(seen, "|")
	for( i = 0; i < ItemsInList(seen, "|"); i += 1 )
		Printf "   %7d x   %s\r", tally[i], StringFromList(i, seen, "|")
	endfor
	return 0
End



// #####################################################################################
// #####            STIMULUS RECONSTRUCTION  (rewritten in HEKA_Load_4)            #####
// #####################################################################################
//
//  WHERE STIMULUS NAMES COME FROM
//  ------------------------------
//  Trace (AD input) names ARE stored in the file -- TrLabel: "Imon-1", "Adc-1".
//  Stimulus (DA output) names are NOT.  The .pgf ChannelRecord has no name field at
//  all, only chDacChannel (INT16) and chDacMode (BYTE).  PatchMaster derives the
//  displayed name at run time from the channel index plus the amplifier hardware
//  layout, so a reader has to reconstruct it.
//
//  The manuals give the rule.  PATCHMASTER 23.5: "AD channels are always linked to a
//  DA output channel. Therefore 'Imon-1' is linked to the corresponding Stim-1 DA
//  output."  PATCHMASTER 7.1.3: amplifier 1 uses DA-3 as Stim-1, amplifier 2 uses
//  DA-2 as Stim-2, amplifier 3 uses DA-1, amplifier 4 uses DA-0.  EPC 10 USB 3.3: the
//  LIH 8+8 provides DA-0..DA-3 and AD-0..AD-7, of which a Double leaves DA-0/DA-1 and
//  AD-0..AD-2 free for the user.
//
//  And the mapping is in the file, in the .amp tree that this module now reads:
//  each AmplifierState carries sIMonAdc, sVMonAdc, sStimDac and sE9Boards per board.
//  Both reference files give board 0 = (IMon 6, VMon 5, StimDac 3) and board 1 =
//  (IMon 4, VMon 3, StimDac 2), with sE9Boards = 2 -- an EPC 10 USB Double.  So:
//      trace Imon-1 -> TrAdcChannel 6 -> board 0 -> sStimDac 3 -> chDacChannel 3 -> Stim1
//      trace Imon-2 -> TrAdcChannel 4 -> board 1 -> sStimDac 2 -> chDacChannel 2 -> Stim2
//      trace Adc-1  -> TrAdcChannel 1 -> free input       -> chDacChannel 0 -> DA0
//
//  NAMING RULE (HK_StimChannelName)
//      chDacChannel matches a board's sStimDac AND chDacUnit is set
//                                     -> "Stim1", "Stim2", ...  ("Stim" if one board)
//      chDacUnit set (an analog output)               -> "DA0", "DA1", "DA2"
//      chDacUnit empty (a digital line)               -> "D0", "D1", ...
//  chDacMode is undocumented in the v9 and v1000 specs, so the rule deliberately does
//  NOT depend on it -- it keys off the .amp cross-check and the unit string, both
//  verifiable.  chDacMode is only reported by HK_StimInfo, for diagnosis.  With no
//  .amp block the rule degrades to "DA<n>" rather than inventing an amplifier number.
//
//  WHICH CHANNELS PRODUCE A WAVE
//      amplifier stimulus channels (Stim*)  : always -- the clamp command matters even
//                                             when it is a flat holding potential
//      auxiliary channels (DA*, D*)         : only when the waveform actually varies.
//                                             An idle line (e.g. DA-0 sitting at 0 V
//                                             while Adc-1 passively records) is not a
//                                             stimulus and is skipped silently.
//
//  CHANNELS WITH NO RECORDED TRACE
//  A DA channel need not have an AD input.  In "PM example.dat" the 100 Hz protocol
//  drives a digital line with 101 segments and records nothing on it; matching on
//  chAdcChannel alone made it invisible.  HK_LoadUnmatchedStimuli() picks those up per
//  sweep, named without a trace index: P_<gr>_<se>_<sw>_D0.
//
//  SHORT CHANNELS ARE NORMAL
//  That same digital train is 0.6 s long (50 pulses at 100 Hz) inside a 5.25 s sweep.
//  PatchMaster holds a channel at its last level once its segments run out, so a
//  stored duration SHORTER than the sweep is expected and is padded quietly (the wave
//  note records where padding began).  Only a stored duration LONGER than the sweep is
//  a real problem, and that still warns.


static StrConstant kHKS_DF = "root:Packages:HEKA:PGF"
static StrConstant kHKA_DF = "root:Packages:HEKA:AMP"

// StimSegment seClass
static Constant kHKS_Constant   = 0
static Constant kHKS_Ramp       = 1
static Constant kHKS_Continuous = 2
static Constant kHKS_ConstSine  = 3
static Constant kHKS_Square     = 4
static Constant kHKS_Chirp      = 5

// chStimToDacID bits
static Constant kHKS_UseRelative = 0x02		// stimulus is relative to the holding value

// AmplifierState field offsets, relative to AmAmplifierState (= AmplState record + 112)
static Constant kHKA_StateBase   = 112
static Constant kHKA_oE9Boards   = 208		// INT16
static Constant kHKA_oIMonAdc    = 212		// INT16
static Constant kHKA_oVMonAdc    = 214		// INT16
static Constant kHKA_oStimDac    = 220		// INT16
static Constant kHKA_oActiveE9   = 236		// BYTE


// -------------------------------------------------------------------------------------
//  Byte decoders for the cached .pgf / .amp blocks
// -------------------------------------------------------------------------------------
static Function HKS_U32(bb, off, swap)
	Wave/B/U bb
	Variable off, swap
	if( swap )
		return bb[off]*16777216 + bb[off+1]*65536 + bb[off+2]*256 + bb[off+3]
	endif
	return bb[off] + bb[off+1]*256 + bb[off+2]*65536 + bb[off+3]*16777216
End

static Function HKS_I32(bb, off, swap)
	Wave/B/U bb
	Variable off, swap
	Variable v = HKS_U32(bb, off, swap)
	if( v >= 2147483648 )
		v -= 4294967296
	endif
	return v
End

static Function HKS_I16(bb, off, swap)
	Wave/B/U bb
	Variable off, swap
	Variable v
	if( swap )
		v = bb[off]*256 + bb[off+1]
	else
		v = bb[off] + bb[off+1]*256
	endif
	if( v >= 32768 )
		v -= 65536
	endif
	return v
End

static Function HKS_R8(bb, off, swap)
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
	Variable sgn = 1
	if( b7 & 0x80 )
		sgn = -1
	endif
	Variable expo = (b7 & 0x7F) * 16 + trunc(b6 / 16)
	Variable mant = (b6 & 0x0F) * 281474976710656 + b5 * 1099511627776 + b4 * 4294967296	\
	              + b3 * 16777216 + b2 * 65536 + b1 * 256 + b0
	if( expo == 0 )
		if( mant == 0 )
			return sgn * 0
		endif
		return sgn * mant * 2^-1074
	endif
	if( expo == 2047 )
		if( mant == 0 )
			return sgn * Inf
		endif
		return NaN
	endif
	return sgn * (1 + mant / 4503599627370496) * 2^(expo - 1023)
End

static Function/S HKS_CStr(bb, off, maxLen)
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


// -------------------------------------------------------------------------------------
//  Generic tree walker, shared by the .pgf and .amp caches
// -------------------------------------------------------------------------------------
static Function HKS_Walk(bb, lsz, nd, swap, pos, level, parent, nNodes)
	Wave/B/U bb
	Wave/D lsz, nd
	Variable swap
	Variable &pos
	Variable level, parent
	Variable &nNodes

	Variable me = nNodes
	nNodes += 1
	if( me >= DimSize(nd, 0) )
		Redimension/N=(DimSize(nd,0) + 2048, 6) nd
	endif
	nd[me][0] = level
	nd[me][1] = pos
	nd[me][2] = parent
	nd[me][4] = -1
	nd[me][5] = -1

	pos += lsz[level]
	Variable nkids = HKS_I32(bb, pos, swap)
	pos += 4
	nd[me][3] = nkids

	if( level + 1 >= numpnts(lsz) || nkids <= 0 )
		return me
	endif
	nd[me][4] = me + 1
	Variable k, kid, prev = -1
	for( k = 0; k < nkids; k += 1 )
		kid = HKS_Walk(bb, lsz, nd, swap, pos, level+1, me, nNodes)
		if( prev >= 0 )
			nd[prev][5] = kid
		endif
		prev = kid
	endfor
	return me
End


// Read one bundled tree block into <dfName> as <prefix>Bytes / <prefix>Node /
// <prefix>LevelSize / <prefix>Swap, cached against the file path.  Returns 0 on success.
static Function HKS_LoadBlock(ext, dfName, prefix)
	String ext, dfName, prefix

	if( !DataFolderExists("root:Packages:HEKA") )
		Print "HK_LoadStimulus: run HK_Scan() first."
		return -1
	endif
	DFREF hk = root:Packages:HEKA
	SVAR/Z path = hk:HK_Path
	if( !SVAR_Exists(path) )
		Print "HK_LoadStimulus: run HK_Scan() first."
		return -1
	endif

	if( !DataFolderExists(dfName) )
		NewDataFolder $dfName
	endif
	DFREF dfr = $dfName

	SVAR/Z cached = dfr:$(prefix+"Path")
	Wave/Z/SDFR=dfr nodes = $(prefix+"Node")
	if( SVAR_Exists(cached) && WaveExists(nodes) )
		if( CmpStr(cached, path) == 0 )
			return 0
		endif
	endif

	Wave/Z/T/SDFR=hk iExt   = HK_ItemExt
	Wave/Z/SDFR=hk   iStart = HK_ItemStart
	Wave/Z/SDFR=hk   iLen   = HK_ItemLength
	if( !WaveExists(iExt) )
		Print "HK_LoadStimulus: no item table -- run HK_Scan() first."
		return -1
	endif

	Variable i, idx = -1
	for( i = 0; i < numpnts(iExt); i += 1 )
		if( CmpStr(iExt[i], ext) == 0 )
			idx = i
			break
		endif
	endfor
	if( idx < 0 )
		return -2							// caller decides whether that is fatal
	endif
	Variable blockStart = iStart[idx]
	Variable blockLen   = iLen[idx]
	if( blockLen <= 0 )
		return -2
	endif

	// In a bundle this is the bundle; in an unbundled set it is the companion file.
	String blockFile = HK_ItemFileFor(ext)
	if( strlen(blockFile) == 0 )
		blockFile = path
	endif

	Variable refNum
	Open/R/Z=1 refNum as blockFile
	if( V_flag != 0 )
		Print "HK_LoadStimulus: cannot open " + blockFile
		return -3
	endif
	Make/O/B/U/N=(blockLen) dfr:$(prefix+"Bytes")/WAVE=bb
	FSetPos refNum, blockStart
	FBinRead refNum, bb
	Close refNum

	Variable magic = HKS_U32(bb, 0, 0)
	Variable swap
	if( magic == 0x54726565 )
		swap = 0
	elseif( magic == 0x65657254 )
		swap = 1
	else
		Printf "HK_LoadStimulus: bad tree magic 0x%08X in the %s block.\r", magic, ext
		return -4
	endif

	Variable nLevels = HKS_I32(bb, 4, swap)
	if( nLevels <= 0 || nLevels > 16 )
		Printf "HK_LoadStimulus: implausible %s level count %d.\r", ext, nLevels
		return -4
	endif
	Make/O/D/N=(nLevels) dfr:$(prefix+"LevelSize")/WAVE=lsz
	for( i = 0; i < nLevels; i += 1 )
		lsz[i] = HKS_I32(bb, 8 + 4*i, swap)
	endfor

	Variable pos = 8 + 4*nLevels
	Make/O/D/N=(2048, 6) dfr:$(prefix+"Node")/WAVE=nd
	nd = NaN
	Variable nNodes = 0
	HKS_Walk(bb, lsz, nd, swap, pos, 0, -1, nNodes)
	Redimension/N=(nNodes, 6) nd

	Variable/G dfr:$(prefix+"Swap")   = swap
	Variable/G dfr:$(prefix+"nNodes") = nNodes
	String/G   dfr:$(prefix+"Path")   = path

	if( pos != blockLen )
		Printf "HK_LoadStimulus: warning -- the %s walk ended at %d but the block is %d bytes.\r", ext, pos, blockLen
	endif
	return 0
End


Function HKS_Ensure()
	return HKS_LoadBlock(".pgf", kHKS_DF, "HKS_")
End


// -------------------------------------------------------------------------------------
//  Node helpers, parameterised by which cached tree
// -------------------------------------------------------------------------------------
static Function HKX_Child(dfName, prefix, n, k)
	String dfName, prefix
	Variable n, k
	DFREF dfr = $dfName
	Wave/Z/SDFR=dfr nd = $(prefix+"Node")
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

static Function HKX_Off(dfName, prefix, n)
	String dfName, prefix
	Variable n
	DFREF dfr = $dfName
	Wave/Z/SDFR=dfr nd = $(prefix+"Node")
	if( !WaveExists(nd) || n < 0 || n >= DimSize(nd,0) )
		return NaN
	endif
	return nd[n][1]
End

static Function HKX_NKids(dfName, prefix, n)
	String dfName, prefix
	Variable n
	DFREF dfr = $dfName
	Wave/Z/SDFR=dfr nd = $(prefix+"Node")
	if( !WaveExists(nd) || n < 0 || n >= DimSize(nd,0) )
		return 0
	endif
	return nd[n][3]
End

static Function HKX_Parent(dfName, prefix, n)
	String dfName, prefix
	Variable n
	DFREF dfr = $dfName
	Wave/Z/SDFR=dfr nd = $(prefix+"Node")
	if( !WaveExists(nd) || n < 0 || n >= DimSize(nd,0) )
		return -1
	endif
	return nd[n][2]
End

// .pgf shorthands.  Every .pgf lookup goes through one of these; nothing in this module
// indexes HK_Node (the .pul table) with a .pgf node number.
static Function HKS_Child(n, k)
	Variable n, k
	return HKX_Child(kHKS_DF, "HKS_", n, k)
End
static Function HKS_Off(n)
	Variable n
	return HKX_Off(kHKS_DF, "HKS_", n)
End
static Function HKS_NKids(n)
	Variable n
	return HKX_NKids(kHKS_DF, "HKS_", n)
End
static Function HKS_Parent(n)
	Variable n
	return HKX_Parent(kHKS_DF, "HKS_", n)
End


// =====================================================================================
//  THE AMPLIFIER BOARD TABLE  (.amp)
//  One row per amplifier board: sIMonAdc, sVMonAdc, sStimDac.  This is what turns a
//  DA channel index into the name PatchMaster shows.
// =====================================================================================
Function HKA_Ensure()

	Variable err = HKS_LoadBlock(".amp", kHKA_DF, "HKA_")
	if( err != 0 )
		return err
	endif
	DFREF dfr = $kHKA_DF
	Wave/Z/SDFR=dfr board = HKA_Board
	if( WaveExists(board) )
		return 0										// table already built for this file
	endif

	Wave/SDFR=dfr bb = HKA_Bytes
	NVAR/SDFR=dfr swap = HKA_Swap

	// root -> Series records -> AmplState records.  The ADC/DAC assignment is hardware,
	// so it is read from the first Series; later Series are checked for disagreement.
	Make/O/D/N=(8, 3) dfr:HKA_Board/WAVE=bd			// [board][iMon, vMon, stimDac]
	bd = NaN
	Variable/G dfr:HKA_nBoards = 0
	NVAR nBoards = dfr:HKA_nBoards

	Variable nSeries = HKX_NKids(kHKA_DF, "HKA_", 0)
	if( nSeries <= 0 )
		return -2
	endif

	Variable si, k, st, ao, b, conflicts = 0
	for( si = 0; si < nSeries; si += 1 )
		Variable se = HKX_Child(kHKA_DF, "HKA_", 0, si)
		for( k = 0; k < HKX_NKids(kHKA_DF, "HKA_", se); k += 1 )
			st = HKX_Child(kHKA_DF, "HKA_", se, k)
			ao = HKX_Off(kHKA_DF, "HKA_", st) + kHKA_StateBase
			b  = bb[ao + kHKA_oActiveE9]
			if( b < 0 || b >= 8 )
				continue
			endif
			nBoards = max(nBoards, HKS_I16(bb, ao + kHKA_oE9Boards, swap))
			if( numtype(bd[b][0]) == 0 )
				if( bd[b][2] != HKS_I16(bb, ao + kHKA_oStimDac, swap) )
					conflicts += 1
				endif
				continue
			endif
			bd[b][0] = HKS_I16(bb, ao + kHKA_oIMonAdc, swap)
			bd[b][1] = HKS_I16(bb, ao + kHKA_oVMonAdc, swap)
			bd[b][2] = HKS_I16(bb, ao + kHKA_oStimDac, swap)
		endfor
	endfor

	if( conflicts )
		Printf "HKA_Ensure: warning -- %d amplifier states disagree about sStimDac. The first value per board was used.\r", conflicts
	endif
	return 0
End


// Board index whose stimulus DAC is dacChannel, or -1.
static Function HKA_BoardForStimDac(dacChannel)
	Variable dacChannel

	if( HKA_Ensure() != 0 )
		return -1
	endif
	DFREF dfr = $kHKA_DF
	Wave/Z/SDFR=dfr bd = HKA_Board
	if( !WaveExists(bd) )
		return -1
	endif
	Variable b
	for( b = 0; b < DimSize(bd, 0); b += 1 )
		if( numtype(bd[b][2]) != 0 )
			continue
		endif
		if( bd[b][2] == dacChannel )
			return b
		endif
	endfor
	return -1
End

static Function HKA_NumBoards()
	if( HKA_Ensure() != 0 )
		return 0
	endif
	DFREF dfr = $kHKA_DF
	NVAR/Z/SDFR=dfr n = HKA_nBoards
	if( !NVAR_Exists(n) )
		return 0
	endif
	return n
End


// =====================================================================================
//  HK_StimChannelName -- the name PatchMaster would show for a .pgf Channel.
// =====================================================================================
Function/S HK_StimChannelName(ch)
	Variable ch

	if( HKS_Ensure() != 0 )
		return ""
	endif
	DFREF pgf = $kHKS_DF
	Wave/SDFR=pgf bb   = HKS_Bytes
	NVAR/SDFR=pgf swap = HKS_Swap

	Variable co = HKS_Off(ch)
	if( numtype(co) != 0 )
		return ""
	endif
	Variable dch  = HKS_I16(bb, co + 28, swap)			// chDacChannel
	String   unit = HKS_CStr(bb, co + 40, 8)			// chDacUnit

	Variable board = -1
	if( strlen(unit) > 0 )
		board = HKA_BoardForStimDac(dch)
	endif
	if( board >= 0 )
		if( HKA_NumBoards() <= 1 )
			return "Stim"
		endif
		return "Stim" + num2istr(board + 1)
	endif
	if( strlen(unit) > 0 )
		return "DA" + num2istr(dch)
	endif
	return "D" + num2istr(dch)
End

// Is this channel an amplifier stimulus output (rather than an auxiliary DA/digital)?
static Function HKS_IsAmpStim(ch)
	Variable ch
	String nm = HK_StimChannelName(ch)
	if( strlen(nm) < 4 )
		return 0
	endif
	return CmpStr(nm[0,3], "Stim") == 0
End


// -------------------------------------------------------------------------------------
//  Sweep-to-sweep increment.  IncrementModeType:
//     0 ModeInc   1 ModeDec   2 ModeIncInterleaved   3 ModeDecInterleaved
//     4 ModeAlternate   5 ModeLogInc   6 ModeLogDec
//     7 ModeLogIncInterleaved  8 ModeLogDecInterleaved  9 ModeLogAlternate
//  Interleaved variants advance the same way sweep to sweep; interleaving affects
//  acquisition order, not the value sequence.  The two Alternate modes are NOT handled
//  -- the base value is returned and the caller warns.
// -------------------------------------------------------------------------------------
static Function HKS_IncValue(base, inc, factor, mode, j)
	Variable base, inc, factor, mode, j

	if( j <= 0 )
		return base
	endif
	switch( mode )
		case 0:
		case 2:
			return base + j*inc
		case 1:
		case 3:
			return base - j*inc
		case 5:
		case 7:
			if( factor == 0 )
				return base
			endif
			return base * factor^j
		case 6:
		case 8:
			if( factor == 0 )
				return base
			endif
			return base / factor^j
	endswitch
	return base										// Alternate modes: caller warns
End

static Function HKS_IsAlternate(mode)
	Variable mode
	if( mode == 4 || mode == 9 )
		return 1
	endif
	return 0
End


// Resolved voltage of one segment for a given sweep.
//   seVoltage is NOT always the value PatchMaster used.  seVoltageSource says which
//   source the segment is bound to:
//       0  = Constant -> use seVoltage
//       1  = Holding  -> use the CHANNEL's chHolding; seVoltage is a stale leftover
//                        from the stimulus editor and is ignored
//      >=2 = a stimulus parameter (roParams), which this code does not resolve
static Function HKS_SegVoltage(bb, eo, swap, sweepIdx, holding, relative)
	Wave/B/U bb
	Variable eo, swap, sweepIdx, holding, relative

	Variable vSrc  = HKS_I32(bb, eo + 16, swap)
	Variable vBase = HKS_R8(bb, eo + 8, swap)
	if( vSrc == 1 )
		vBase = holding
	endif
	Variable v = HKS_IncValue( vBase, HKS_R8(bb, eo+28, swap), HKS_R8(bb, eo+20, swap), bb[eo+6], sweepIdx )
	if( relative )
		v += holding
	endif
	return v
End

static Function HKS_SegDuration(bb, eo, swap, sweepIdx)
	Wave/B/U bb
	Variable eo, swap, sweepIdx
	return HKS_IncValue( HKS_R8(bb, eo+36, swap), HKS_R8(bb, eo+56, swap), HKS_R8(bb, eo+48, swap), bb[eo+7], sweepIdx )
End


// Does this channel's stored waveform ever leave a single level?  An auxiliary DA or
// digital line that never does is idle, not a stimulus, and produces no wave.
static Function HKS_ChannelVaries(ch, sweepIdx)
	Variable ch, sweepIdx

	DFREF pgf = $kHKS_DF
	Wave/SDFR=pgf bb   = HKS_Bytes
	NVAR/SDFR=pgf swap = HKS_Swap

	Variable co   = HKS_Off(ch)
	Variable stim = HKS_Parent(ch)
	if( numtype(co) != 0 || stim < 0 )
		return 0
	endif
	Variable so       = HKS_Off(stim)
	Variable holding  = HKS_R8(bb, co + 48, swap)
	Variable relative = (HKS_I16(bb, co + 76, swap) & kHKS_UseRelative) != 0
	Variable startSeg = HKS_I32(bb, so + 100, swap)

	Variable i, seg, eo, v, first = 1
	Variable v0 = 0
	for( i = 0; i < HKS_NKids(ch); i += 1 )
		seg = HKS_Child(ch, i)
		eo  = HKS_Off(seg)
		if( bb[eo+5] == 0 || i < startSeg )
			continue
		endif
		v = HKS_SegVoltage(bb, eo, swap, sweepIdx, holding, relative)
		if( first )
			v0 = v
			first = 0
		elseif( v != v0 )
			return 1
		endif
	endfor
	return 0
End


// =====================================================================================
//  HK_StimChannel -- the .pgf Channel node that drove a given .pul trace, or -1.
// =====================================================================================
Function HK_StimChannel(traceNode)
	Variable traceNode

	if( HK_Level(traceNode) != 4 )
		return -1
	endif
	if( HKS_Ensure() != 0 )
		return -1
	endif

	DFREF hk = root:Packages:HEKA
	Wave/SDFR=hk nd = HK_Node
	DFREF pgf = $kHKS_DF
	Wave/SDFR=pgf bb   = HKS_Bytes
	NVAR/SDFR=pgf swap = HKS_Swap

	Variable sweepNode  = nd[traceNode][2]
	Variable seriesNode = nd[sweepNode][2]
	Variable seriesIdx  = HK_SiblingIndex(seriesNode)

	Variable stim = HKS_Child(0, seriesIdx)			// Stimulation i  <->  Series i
	if( stim < 0 )
		return -1
	endif

	Variable adc = HK_Num(traceNode, "TrAdcChannel")
	Variable k, ch
	for( k = 0; k < HKS_NKids(stim); k += 1 )
		ch = HKS_Child(stim, k)
		if( HKS_I16(bb, HKS_Off(ch) + 20, swap) == adc )		// chAdcChannel
			return ch
		endif
	endfor
	return -1
End


// =====================================================================================
//  HKS_BuildWave -- the shared waveform builder.  Used both for channels attached to a
//  trace and for channels with no recorded trace.
// =====================================================================================
static Function/WAVE HKS_BuildWave(ch, sweepIdx, npnts, dt, xstart, xUnit, destName, tag)
	Variable ch, sweepIdx, npnts, dt, xstart
	String xUnit, destName, tag

	DFREF pgf = $kHKS_DF
	Wave/SDFR=pgf bb   = HKS_Bytes
	NVAR/SDFR=pgf swap = HKS_Swap

	Variable stim = HKS_Parent(ch)
	Variable so   = HKS_Off(stim)
	Variable co   = HKS_Off(ch)
	if( stim < 0 || numtype(so) != 0 || numtype(co) != 0 )
		Printf "HK_LoadStimulus: could not resolve the stimulus record for %s.\r", tag
		return $""
	endif
	if( npnts <= 0 || numtype(dt) != 0 || dt <= 0 )
		Printf "HK_LoadStimulus: %s has no usable sampling (%g pts, dt=%g).\r", tag, npnts, dt
		return $""
	endif

	Variable holding   = HKS_R8(bb, co + 48, swap)
	Variable relative  = (HKS_I16(bb, co + 76, swap) & kHKS_UseRelative) != 0
	String   dacUnit   = HKS_CStr(bb, co + 40, 8)
	Variable sineCycle = HKS_R8(bb, co + 96,  swap)
	Variable sineAmp   = HKS_R8(bb, co + 104, swap)
	Variable sqNegAmp  = HKS_R8(bb, co + 144, swap)
	Variable sqDuty    = HKS_R8(bb, co + 152, swap)
	Variable sqCycle   = HKS_R8(bb, co + 232, swap)
	Variable sqPosAmp  = HKS_R8(bb, co + 240, swap)
	Variable startSeg  = HKS_I32(bb, so + 100, swap)

	if( numtype(sqDuty) != 0 || sqDuty <= 0 || sqDuty >= 1 )
		sqDuty = 0.5
	endif

	Make/O/D/N=(npnts) $destName/WAVE=dest
	dest = NaN

	Variable nSeg = HKS_NKids(ch)
	Variable i, seg, eo, cls, store, vMode, tMode
	Variable durJ, volJ, nsamp, a, b
	Variable prevV = holding
	Variable filled = 0
	Variable altWarned = 0
	Variable srcWarned = 0
	Variable approx = 0
	Variable vSrc, dSrc

	for( i = 0; i < nSeg; i += 1 )
		seg = HKS_Child(ch, i)
		eo  = HKS_Off(seg)
		cls   = bb[eo + 4]
		store = bb[eo + 5]
		vMode = bb[eo + 6]
		tMode = bb[eo + 7]

		vSrc = HKS_I32(bb, eo + 16, swap)
		dSrc = HKS_I32(bb, eo + 44, swap)
		if( vSrc >= 2 )
			if( !srcWarned )
				Printf "HK_LoadStimulus: %s segment %d takes its voltage from stimulus parameter %d, which this code does not resolve. The stored seVoltage was used instead -- verify before trusting it.\r", tag, i+1, vSrc-1
				srcWarned = 1
			endif
		endif
		if( dSrc != 0 )
			if( !srcWarned )
				Printf "HK_LoadStimulus: %s segment %d takes its duration from a source (%d) this code does not resolve. The stored seDuration was used instead.\r", tag, i+1, dSrc
				srcWarned = 1
			endif
		endif

		durJ = HKS_SegDuration(bb, eo, swap, sweepIdx)
		volJ = HKS_SegVoltage(bb, eo, swap, sweepIdx, holding, relative)

		if( HKS_IsAlternate(vMode) || HKS_IsAlternate(tMode) )
			if( !altWarned )
				Printf "HK_LoadStimulus: %s uses an Alternate increment mode, which is not reconstructed; sweep 1 values used.\r", tag
				altWarned = 1
			endif
		endif

		if( store == 0 || i < startSeg )
			prevV = volJ
			continue
		endif

		if( cls == kHKS_Continuous || cls == kHKS_Chirp )
			Printf "HK_LoadStimulus: %s segment %d is %s, which this code does not reconstruct. No stimulus wave written.\r", tag, i+1, SelectString(cls == kHKS_Chirp, "Continuous", "Chirp")
			KillWaves/Z dest
			return $""
		endif

		nsamp = round(durJ / dt)
		if( nsamp < 1 )
			prevV = volJ
			continue
		endif
		a = filled
		b = min(filled + nsamp - 1, npnts - 1)
		if( a > npnts - 1 )
			filled += nsamp
			prevV = volJ
			continue
		endif

		switch( cls )
			case kHKS_Constant:
				dest[a, b] = volJ
				break
			case kHKS_Ramp:
				if( nsamp > 1 )
					dest[a, b] = prevV + (volJ - prevV) * (p - a) / (nsamp - 1)
				else
					dest[a, b] = volJ
				endif
				break
			case kHKS_ConstSine:
				approx = 1
				if( sineCycle > 0 )
					dest[a, b] = volJ + sineAmp * sin( 2*pi * ((p - a)*dt) / sineCycle )
				else
					dest[a, b] = volJ
				endif
				break
			case kHKS_Square:
				approx = 1
				if( sqCycle > 0 )
					dest[a, b] = volJ + ( mod((p - a)*dt, sqCycle) < sqCycle*sqDuty ? sqPosAmp : sqNegAmp )
				else
					dest[a, b] = volJ
				endif
				break
		endswitch

		filled += nsamp
		prevV = volJ
	endfor

	// A channel whose segments run out before the sweep ends is NORMAL -- PatchMaster
	// holds the line at its last level (the 100 Hz digital train is 0.6 s of a 5.25 s
	// sweep).  Pad quietly and record it.  Only an OVER-length channel is a problem.
	String padNote = ""
	if( filled > npnts + 1 )
		Printf "HK_LoadStimulus: %s -- segments total %g samples but the sweep holds only %d; the stimulus was truncated.\r", tag, filled, npnts
	endif
	if( filled < npnts )
		dest[filled, npnts-1] = prevV
		sprintf padNote, "heldFromSample=%d;heldValue=%.10g;", filled, prevV
	endif

	SetScale/P x, xstart, dt, xUnit, dest
	SetScale d, 0, 0, dacUnit, dest

	String nt = "HEKA stimulus;channel=" + HK_StimChannelName(ch) + ";" + tag									\
		+ ";entry=" + HKS_CStr(bb, so + 4, 32) + ";sweepIndex=" + num2istr(sweepIdx+1)						\
		+ ";holding=" + num2str(holding) + ";relative=" + num2istr(relative)								\
		+ ";dacUnit=" + dacUnit + ";" + padNote
	if( approx )
		nt += "UNVERIFIED=sine/square segments reconstructed from the format spec only;"
		Printf "HK_LoadStimulus: %s contains sine or squarewave segments. That reconstruction is from the spec and has never been checked against a real file -- please verify it.\r", tag
	endif
	Note/K dest, nt

	return dest
End


// =====================================================================================
//  HK_LoadStimulus -- the stimulus that drove one trace.
//      Named P_<gr>_<se>_<sw>_<tr>_<DAname>, e.g. P_1_1_1_1_Stim1, P_1_1_1_2_Stim2.
//      An auxiliary channel (DA*/D*) that never leaves one level is idle rather than a
//      stimulus, and returns null without writing anything.
// =====================================================================================
Function/WAVE HK_LoadStimulus(traceNode, [destName])
	Variable traceNode
	String destName

	if( HK_Level(traceNode) != 4 )
		Print "HK_LoadStimulus: that node is not a trace (level 4)."
		return $""
	endif

	Variable ch = HK_StimChannel(traceNode)
	if( ch < 0 )
		return $""										// no matching channel: stay silent
	endif

	DFREF hk = root:Packages:HEKA
	Wave/SDFR=hk nd = HK_Node
	Variable sweepIdx = HK_SiblingIndex(nd[traceNode][2])

	if( !HKS_IsAmpStim(ch) )
		if( !HKS_ChannelVaries(ch, sweepIdx) )
			return $""									// idle auxiliary line, not a stimulus
		endif
	endif

	if( ParamIsDefault(destName) || strlen(destName) == 0 )
		destName = CleanupName(HK_BaseName() + "_" + HK_PathString(traceNode) + "_" + HK_StimChannelName(ch), 0)
	endif

	return HKS_BuildWave(ch, sweepIdx, HK_Num(traceNode, "TrDataPoints"), HK_Num(traceNode, "TrXInterval"),	\
		HK_Num(traceNode, "TrXStart"), HK_GetS(traceNode, "TrXUnit"), destName, "trace " + HK_PathString(traceNode))
End


// =====================================================================================
//  HK_LoadUnmatchedStimuli -- DA channels of this sweep that drive no recorded trace.
//  These are real stimuli (a digital train to a stimulus isolator, a command to an
//  external device) that matching on chAdcChannel alone would miss entirely.
//  Named without a trace index: P_<gr>_<se>_<sw>_D0.
//  Returns how many waves were written.
// =====================================================================================
Function HK_LoadUnmatchedStimuli(sweepNode)
	Variable sweepNode

	if( HK_Level(sweepNode) != 3 )
		return 0
	endif
	if( HKS_Ensure() != 0 )
		return 0
	endif

	DFREF hk = root:Packages:HEKA
	Wave/SDFR=hk nd = HK_Node
	DFREF pgf = $kHKS_DF
	Wave/SDFR=pgf bb   = HKS_Bytes
	NVAR/SDFR=pgf swap = HKS_Swap

	Variable seriesNode = nd[sweepNode][2]
	Variable seriesIdx  = HK_SiblingIndex(seriesNode)
	Variable sweepIdx   = HK_SiblingIndex(sweepNode)
	Variable stim = HKS_Child(0, seriesIdx)
	if( stim < 0 )
		return 0
	endif

	// A channel with no trace has no sampling of its own; borrow the sweep's first
	// trace so the wave overlays the data point for point.
	Variable nTr = HK_NumChildren(sweepNode)
	if( nTr <= 0 )
		return 0
	endif
	Variable ref    = HK_Child(sweepNode, 0)
	Variable npnts  = HK_Num(ref, "TrDataPoints")
	Variable dt     = HK_Num(ref, "TrXInterval")
	Variable xstart = HK_Num(ref, "TrXStart")
	String   xUnit  = HK_GetS(ref, "TrXUnit")

	// which ADC channels this sweep actually records
	Make/FREE/D/N=(nTr) recAdc
	Variable i
	for( i = 0; i < nTr; i += 1 )
		recAdc[i] = HK_Num( HK_Child(sweepNode, i), "TrAdcChannel" )
	endfor

	String swPath = HK_PathString(sweepNode)
	Variable k, ch, adc, j, matched, got = 0
	String nm, destName
	for( k = 0; k < HKS_NKids(stim); k += 1 )
		ch  = HKS_Child(stim, k)
		adc = HKS_I16(bb, HKS_Off(ch) + 20, swap)
		matched = 0
		for( j = 0; j < nTr; j += 1 )
			if( recAdc[j] == adc )
				matched = 1
				break
			endif
		endfor
		if( matched )
			continue									// handled by HK_LoadStimulus
		endif
		if( !HKS_IsAmpStim(ch) )
			if( !HKS_ChannelVaries(ch, sweepIdx) )
				continue								// idle line
			endif
		endif
		nm = HK_StimChannelName(ch)
		destName = CleanupName(HK_BaseName() + "_" + swPath + "_" + nm, 0)
		Wave/Z w = HKS_BuildWave(ch, sweepIdx, npnts, dt, xstart, xUnit, destName, "sweep " + swPath + " " + nm)
		if( WaveExists(w) )
			got += 1
		endif
	endfor
	return got
End


// Everything for one sweep: each trace's stimulus plus the unattached DA channels.
Function HK_LoadSweepStimuli(sweepNode)
	Variable sweepNode

	if( HK_Level(sweepNode) != 3 )
		return 0
	endif
	Variable i, got = 0
	for( i = 0; i < HK_NumChildren(sweepNode); i += 1 )
		Wave/Z w = HK_LoadStimulus( HK_Child(sweepNode, i) )
		if( WaveExists(w) )
			got += 1
		endif
	endfor
	return got + HK_LoadUnmatchedStimuli(sweepNode)
End


// =====================================================================================
//  HK_StimInfo -- how a trace maps onto the stimulus tree, without building anything.
// =====================================================================================
Function HK_StimInfo(traceNode)
	Variable traceNode

	if( HK_Level(traceNode) != 4 )
		Print "HK_StimInfo: that node is not a trace (level 4)."
		return -1
	endif
	Variable ch = HK_StimChannel(traceNode)
	if( ch < 0 )
		Printf "HK_StimInfo: no stimulus channel matches trace %s (TrAdcChannel = %g).\r", HK_PathString(traceNode), HK_Num(traceNode, "TrAdcChannel")
		return -1
	endif

	DFREF hk = root:Packages:HEKA
	Wave/SDFR=hk nd = HK_Node
	DFREF pgf = $kHKS_DF
	Wave/SDFR=pgf bb   = HKS_Bytes
	NVAR/SDFR=pgf swap = HKS_Swap

	Variable stim = HKS_Parent(ch)
	Variable so = HKS_Off(stim)
	Variable co = HKS_Off(ch)
	Variable sweepIdx = HK_SiblingIndex(nd[traceNode][2])
	if( stim < 0 || numtype(so) != 0 || numtype(co) != 0 )
		Printf "HK_StimInfo: could not resolve the stimulus record for trace %s.\r", HK_PathString(traceNode)
		return -1
	endif

	// amplifier board table
	Printf "---- stimulus for trace %s  \"%s\" ----\r", HK_PathString(traceNode), HK_Label(traceNode)
	if( HKA_Ensure() == 0 )
		DFREF adf = $kHKA_DF
		Wave/SDFR=adf bd = HKA_Board
		Printf "  amplifier   : %d board(s)\r", HKA_NumBoards()
		Variable b
		for( b = 0; b < DimSize(bd,0); b += 1 )
			if( numtype(bd[b][0]) != 0 )
				continue
			endif
			Printf "                board %d -> Stim%d : sIMonAdc=%g  sVMonAdc=%g  sStimDac=%g\r", b, b+1, bd[b][0], bd[b][1], bd[b][2]
		endfor
	else
		Print  "  amplifier   : no .amp block -- DA channels fall back to DA<n> naming"
	endif

	Variable holding = HKS_R8(bb, co+48, swap)
	Printf "  Stimulation : \"%s\"   sampleInterval = %.6g s   nSweeps = %d\r", HKS_CStr(bb, so+4, 32), HKS_R8(bb, so+112, swap), HKS_I32(bb, so+144, swap)
	Printf "  Channel     : %s   chDacChannel=%d chDacMode=%d unit=%s   chAdcChannel=%d (matches TrAdcChannel)\r", HK_StimChannelName(ch), HKS_I16(bb, co+28, swap), bb[co+30], HKS_CStr(bb, co+40, 8), HKS_I16(bb, co+20, swap)
	Printf "  Holding     : %.6g      chStimToDacID = %d%s\r", holding, HKS_I16(bb, co+76, swap), SelectString((HKS_I16(bb, co+76, swap) & kHKS_UseRelative) != 0, "", "  (relative to holding)")
	Printf "  this sweep  : index %d of the series      varies = %d\r", sweepIdx + 1, HKS_ChannelVaries(ch, sweepIdx)

	String classes = "Constant;Ramp;Continuous;ConstSine;Squarewave;Chirp"
	Variable i, seg, eo, cls, vSrc
	Variable total = 0, durJ, volJ
	Variable relative = (HKS_I16(bb, co + 76, swap) & kHKS_UseRelative) != 0
	String srcName
	for( i = 0; i < HKS_NKids(ch); i += 1 )
		seg = HKS_Child(ch, i)
		eo  = HKS_Off(seg)
		cls = bb[eo+4]
		vSrc = HKS_I32(bb, eo+16, swap)
		srcName = "seVoltage"
		if( vSrc == 1 )
			srcName = "Holding"
		elseif( vSrc >= 2 )
			srcName = "param " + num2istr(vSrc-1) + " (UNRESOLVED)"
		endif
		durJ = HKS_SegDuration(bb, eo, swap, sweepIdx)
		volJ = HKS_SegVoltage(bb, eo, swap, sweepIdx, holding, relative)
		Printf "    seg %d: %-10s  V = %-12.6g  dur = %-12.6g  store = %d   source = %s\r", i+1, StringFromList(cls, classes), volJ, durJ, bb[eo+5], srcName
		if( bb[eo+5] != 0 && i >= HKS_I32(bb, so+100, swap) )
			total += durJ
		endif
	endfor
	Variable npnts = HK_Num(traceNode, "TrDataPoints")
	Variable dt    = HK_Num(traceNode, "TrXInterval")
	Printf "  stored segments total %.6g s;  sweep is %d x %.6g = %.6g s   ->  %s\r", total, npnts, dt, npnts*dt,	SelectString(total > npnts*dt + 2*dt, SelectString(abs(total - npnts*dt) < 2*dt, "shorter, held at last level (normal)", "match"), "LONGER THAN THE SWEEP")

	// the unattached channels of this sweep
	Variable sweepNode = nd[traceNode][2]
	Variable nTr = HK_NumChildren(sweepNode)
	Variable k, c2, adc2, j, matched
	String extra = ""
	for( k = 0; k < HKS_NKids(stim); k += 1 )
		c2 = HKS_Child(stim, k)
		adc2 = HKS_I16(bb, HKS_Off(c2) + 20, swap)
		matched = 0
		for( j = 0; j < nTr; j += 1 )
			if( HK_Num( HK_Child(sweepNode, j), "TrAdcChannel" ) == adc2 )
				matched = 1
				break
			endif
		endfor
		if( !matched )
			extra += HK_StimChannelName(c2) + SelectString(HKS_ChannelVaries(c2, sweepIdx), " (idle, skipped)", " (" + num2istr(HKS_NKids(c2)) + " segments)") + ", "
		endif
	endfor
	if( strlen(extra) )
		Printf "  this sweep also drives, with nothing recorded on it: %s\r", RemoveEnding(extra, ", ")
	endif
	return 0
End


// #####################################################################################
// #####          ACQUISITION METADATA -> WAVE NOTE  (added in HEKA_Load_4)        #####
// #####################################################################################
//
//  HK_LoadTrace appends HK_TraceMetaNote() to every trace's wave note.  Read a field
//  back with, e.g.
//        Print StringByKey("CSlow", note(w), "=", ";")          // 1.66684e-10
//        Print StringByKey("CSlow_disp", note(w), "=", ";")     // 166.7 pF
//  Every physical quantity gets two keys: the bare SI value (parse it with str2num)
//  and a "_disp" companion in engineering units.
//
//  WHERE EACH FIELD COMES FROM, AND WHY
//  ------------------------------------
//  The AmplifierState embedded in the .pul SeriesRecord is NOT usable: it is all
//  zeros in v2x91 files and uninitialised process memory in PatchMaster NEXT (visible
//  as 0x00007ff... pointer values).  Every amplifier parameter below is therefore read
//  from the .amp tree, which is fully populated in both reference files.
//
//  Routing, verified against both files:
//      .pul Series -> .amp Series : SeAmplStateSeries, 1-based (1,2,3... for series
//                                   1,2,3...); falls back to the series position.
//      trace -> amplifier board   : the board whose sIMonAdc or sVMonAdc equals
//                                   TrAdcChannel; falls back to TrAmplIndex-1.
//                                   (Imon-1 -> AD 6 -> board 0; Imon-2 -> AD 4 -> board 1.)
//      board -> AmplState record  : the child whose sActiveE9Board matches.
//
//  FIELD NOTES
//    Mode          Two independent things, so both are written.  RecordingMode is the
//                  trace's TrRecordingMode (InOut/OnCell/OutOut/WholeCell/CClamp/
//                  VClamp/NoMode) -- it mixes patch configuration with clamp mode and
//                  so cannot say "whole-cell AND current-clamp".  ClampMode is the
//                  amplifier's sMode (TestMode/VCMode/CCMode/NoMode).
//    Holding       Taken from the linked stimulus channel's chHolding, as DataFile_v9
//                  section 4.2 specifies ("The field 'Holding' of the chLinkedChannel
//                  channel contains now V-membrane/I-membrane of the trace").  The
//                  trace's own TrTrHolding is NOT used: it reads -0.07 correctly in
//                  the v2x91 file but 0 in the PatchMaster NEXT file whose cell was
//                  held at -60 mV.  The unit follows chDacUnit, so a current-clamp
//                  recording reports pA and a voltage-clamp one mV without guessing.
//    RSeries       1/sGSeries -- the measured series resistance.
//    RsValue       sRsValue -- the compensated PORTION, in ohms.
//    RsFraction    sRsFraction, written both as a fraction and as a percentage.
//                  These three are consistent: 5.9015 MOhm x 0.66143 = 3.9034 MOhm,
//                  which is exactly sRsValue.  HK_CheckRsConsistency() re-runs that
//                  identity across a whole file.
//                  (The trace record's TrRsValue equals sRsValue in one reference file
//                  but 1/sGSeries in the other, so it is deliberately not used.)
//    RsOn / RsTau  sRsOn is the on/off flag; sRsTau is the lag -- 1e-5 = 10 us in the
//                  v2x91 file, matching the amplifier's Rs-compensation speed setting.
//    CFastAmp1/2   NOT amplifier 1 and amplifier 2.  These are the two components of
//                  ONE amplifier's C-fast compensation: EPC 10 USB 5.3 calls them "the
//                  unfiltered C-Fast amplitude (C-Fast Amplitude 1)" and "the filtered
//                  C-Fast amplitude (C-Fast Amplitude 2)", sharing sCFastTau.  Each
//                  board carries its own pair.
//    Gain          sGain is an INDEX into the amplifier's gain table (2, 1, 3 in these
//                  files), not a gain.  The physical value is sCurrentGain in V/A
//                  (2e9 V/A = 2 mV/pA); both are written.
//    Filter1       The current-monitor Filter 1: bandwidth in Hz plus the pop-up text
//                  it was selected as (Filter1Setting, e.g. "Bessel 10 kHz").  See the
//                  block above HKM_Filter1Name() for how the index was pinned down.
//    Filter2       The 4-pole filter in series with Filter 1.  Filter2 is the value
//                  dialled in PatchMaster, Filter2Real the bandwidth the hardware
//                  achieved (3 kHz vs 2873.5 Hz in both reference files), Filter2Type
//                  the characteristic from sF2Response.  Both files were recorded with
//                  Bessel, so the Butterworth code is structurally right but, like
//                  Comment, unverified against real content.
//    Comment       SeComment, the per-series comment.  It is empty in both reference
//                  files, so this field is structurally right but unverified against
//                  real content.  GrText (group) and RoRootText (file) also exist.
//    Stimulation   stEntryName of the .pgf Stimulation record for this series.
//
//  Non-monitor traces (an Adc-n input, say) carry TrAmplIndex = 1 and would otherwise
//  inherit amplifier 1's CSlow, Rs and gain, none of which describe them.  They get
//  the file/time/stimulus fields only, plus Monitor=0.


// AmplifierState field offsets, relative to AmAmplifierState (= AmplState record + 112)
static Constant kHKA_oCurrentGain = 8
static Constant kHKA_oF2Bandwidth = 16		// achieved F2 -3 dB bandwidth, Hz
static Constant kHKA_oF2Frequency = 24		// F2 as dialled in PatchMaster, Hz
static Constant kHKA_oRsValue     = 32
static Constant kHKA_oRsFraction  = 40
static Constant kHKA_oCFastAmp1   = 56
static Constant kHKA_oCFastAmp2   = 64
static Constant kHKA_oCFastTau    = 72
static Constant kHKA_oCSlow       = 80
static Constant kHKA_oGSeries     = 88
static Constant kHKA_oVHold       = 112
static Constant kHKA_oVpOffset    = 128
static Constant kHKA_oVLiquidJunc = 136
static Constant kHKA_oCCIHold     = 144
static Constant kHKA_oImon1Bw     = 264		// Filter 1 bandwidth, Hz
static Constant kHKA_oMode        = 237
static Constant kHKA_oF2Response  = 239		// BYTE: 0 = Bessel, 1 = Butterworth
static Constant kHKA_oRsOn        = 240
static Constant kHKA_oGainIndex   = 280
static Constant kHKA_oFilter1     = 281		// BYTE: index into the Filter 1 pop-up
static Constant kHKA_oRsTau       = 304


// -------------------------------------------------------------------------------------
//  Analog filter decoding
//
//  FILTER 1 is a 6-pole low-pass in the current-monitor path, chosen from a pop-up.
//  sFilter1 stores the menu INDEX, and both manuals list the menu in this order:
//        0 = Bessel 100 kHz    1 = Bessel 30 kHz    2 = Bessel 10 kHz    3 = HQ 30 kHz
//  Verified rather than assumed: both reference files hold sFilter1 = 2 while the
//  independent sImon1Bandwidth reads 10000 Hz.  That same cross-check rules out
//  sF1Mode (offset 294), which differs between the two files (3 vs 0) while the
//  bandwidth does not -- it tracks sAmplKind (5 vs 2), so it describes the hardware,
//  not the user's setting.
//
//  FILTER 2 is a 4-pole low-pass in series with Filter 1, serving current monitor 2
//  and the voltage monitor.  Its bandwidth is stored twice and the two are NOT the
//  same number:
//        sF2Frequency  = the value dialled in PatchMaster (the control moves in
//                        0.1 kHz steps, and the reference files hold exactly 3000)
//        sF2Bandwidth  = what the hardware actually achieved (2873.479 Hz) -- the
//                        field heka_reader.py names "RealF2Bandwidth"
//  Both are written.  Use the real one for rise-time or noise corrections.  No further
//  combination with Filter 1 is needed: PATCHMASTER 7.1.13 states that the Filter 2
//  setting is already the effective bandwidth of the two filters in series.
// -------------------------------------------------------------------------------------

// Menu text for a Filter 1 index.
static Function/S HKM_Filter1Name(idx)
	Variable idx

	if( numtype(idx) != 0 || idx < 0 || idx > 3 )
		return "index " + num2istr(idx)
	endif
	return StringFromList(idx, "Bessel 100 kHz;Bessel 30 kHz;Bessel 10 kHz;HQ 30 kHz")
End

// Corner frequency implied by a Filter 1 index, in Hz; NaN if the index is unknown.
static Function HKM_Filter1Hz(idx)
	Variable idx

	if( numtype(idx) != 0 || idx < 0 || idx > 3 )
		return NaN
	endif
	return str2num( StringFromList(idx, "100000;30000;10000;30000") )
End

// Filter 2 characteristic, from sF2Response.
static Function/S HKM_F2TypeName(resp)
	Variable resp

	if( resp == 0 )
		return "Bessel"
	endif
	if( resp == 1 )
		return "Butterworth"
	endif
	if( resp == 2 )
		return "Bypass"
	endif
	return "code " + num2istr(resp)
End


// -------------------------------------------------------------------------------------
//  Small formatting helpers
// -------------------------------------------------------------------------------------
static Function/S HKM_Eng(v, unit)
	Variable v
	String unit

	if( numtype(v) != 0 )
		return "n/a"
	endif
	if( v == 0 )
		return "0 " + unit
	endif
	Variable e = floor( log(abs(v)) / 3 )
	e = min(max(e, -5), 3)
	String pfx = StringFromList(e + 5, "f;p;n;u;m;;k;M;G")
	String out
	sprintf out, "%.4g %s%s", v / (10^(3*e)), pfx, unit
	//out+="\r"
	return out
End

static Function HKM_AddS(s, key, val)
	String &s
	String key
	String val
	s += key + "=" + val + ";"
	return 0
End

// SI value plus an engineering-units companion under <key>_disp
static Function HKM_AddN(s, key, v, unit)
	String &s
	String key
	Variable v
	String unit
	String t
	//sprintf t, "%s=%.10g;%s_disp=%s;", key, v, key, HKM_Eng(v, unit)
	sprintf t, "%s=%s;", key, HKM_Eng(v, unit)
	s += t//+"\r"
	return 0
End

// last path component, tolerating ":" and "\" separators
static Function/S HKM_LeafName(pth)
	String pth
	Variable a = strsearch(pth, ":", inf, 1)
	Variable b = strsearch(pth, "\\", inf, 1)
	Variable k = max(a, b)
	//pth+="\r"
	if( k < 0 )
		return pth
	endif
	return pth[k+1, inf]
End


// -------------------------------------------------------------------------------------
//  Amplifier state lookup
// -------------------------------------------------------------------------------------

// Is this trace one of the amplifier monitor inputs (Imon / Vmon / Emon)?
// Decided by channel number rather than by label, so it does not depend on how the
// Trace Assign dialog happens to spell things.
Function HK_IsMonitorTrace(traceNode)
	Variable traceNode

	if( HK_Level(traceNode) != 4 )
		return 0
	endif
	if( HKA_Ensure() != 0 )
		return 0
	endif
	DFREF adf = $kHKA_DF
	Wave/Z/SDFR=adf bd = HKA_Board
	if( !WaveExists(bd) )
		return 0
	endif
	Variable adc = HK_Num(traceNode, "TrAdcChannel")
	Variable b
	for( b = 0; b < DimSize(bd,0); b += 1 )
		if( numtype(bd[b][0]) != 0 )
			continue
		endif
		if( bd[b][0] == adc || bd[b][1] == adc )
			return 1
		endif
	endfor
	return 0
End


// The .amp AmplState node holding this trace's amplifier settings, or -1.
static Function HKA_StateForTrace(traceNode)
	Variable traceNode

	if( HKA_Ensure() != 0 )
		return -1
	endif
	DFREF hk = root:Packages:HEKA
	Wave/SDFR=hk nd = HK_Node
	DFREF adf = $kHKA_DF
	Wave/SDFR=adf ab = HKA_Bytes
	Wave/SDFR=adf bd = HKA_Board

	Variable sweepNode  = nd[traceNode][2]
	Variable seriesNode = nd[sweepNode][2]

	Variable nSe = HKX_NKids(kHKA_DF, "HKA_", 0)
	if( nSe <= 0 )
		return -1
	endif
	Variable si = HK_Num(seriesNode, "SeAmplStateSeries") - 1		// 1-based in the file
	if( numtype(si) != 0 || si < 0 || si >= nSe )
		si = HK_SiblingIndex(seriesNode)
	endif
	if( si < 0 || si >= nSe )
		return -1
	endif
	Variable ase = HKX_Child(kHKA_DF, "HKA_", 0, si)

	Variable adc = HK_Num(traceNode, "TrAdcChannel")
	Variable b, board = -1
	for( b = 0; b < DimSize(bd,0); b += 1 )
		if( numtype(bd[b][0]) != 0 )
			continue
		endif
		if( bd[b][0] == adc || bd[b][1] == adc )
			board = b
			break
		endif
	endfor
	if( board < 0 )
		board = HK_Num(traceNode, "TrAmplIndex") - 1				// 1-based in the file
	endif
	if( board < 0 || numtype(board) != 0 )
		return -1
	endif

	Variable k, st, ao
	for( k = 0; k < HKX_NKids(kHKA_DF, "HKA_", ase); k += 1 )
		st = HKX_Child(kHKA_DF, "HKA_", ase, k)
		ao = HKX_Off(kHKA_DF, "HKA_", st) + kHKA_StateBase
		if( ab[ao + kHKA_oActiveE9] == board )
			return st
		endif
	endfor
	return -1
End


// stEntryName of the .pgf Stimulation record driving this trace's series.
static Function/S HKM_StimEntryName(traceNode)
	Variable traceNode

	if( HKS_Ensure() != 0 )
		return ""
	endif
	DFREF hk = root:Packages:HEKA
	Wave/SDFR=hk nd = HK_Node
	DFREF pgf = $kHKS_DF
	Wave/SDFR=pgf bb = HKS_Bytes

	Variable seriesNode = nd[ nd[traceNode][2] ][2]
	Variable stim = HKS_Child(0, HK_SiblingIndex(seriesNode))
	if( stim < 0 )
		return ""
	endif
	return HKS_CStr(bb, HKS_Off(stim) + 4, 32)
End


// Holding potential/current for a trace, from the linked stimulus channel.
// Returns NaN if it cannot be resolved; unit is returned through unitOut.
static Function HKM_Holding(traceNode, unitOut)
	Variable traceNode
	String &unitOut

	unitOut = ""
	Variable ch = HK_StimChannel(traceNode)
	if( ch >= 0 )
		DFREF pgf = $kHKS_DF
		Wave/SDFR=pgf bb   = HKS_Bytes
		NVAR/SDFR=pgf swap = HKS_Swap
		Variable co = HKS_Off(ch)
		unitOut = HKS_CStr(bb, co + 40, 8)						// chDacUnit: "V" or "A"
		if( strlen(unitOut) == 0 )
			unitOut = "V"
		endif
		return HKS_R8(bb, co + 48, swap)						// chHolding
	endif

	// no stimulus channel: fall back to the amplifier's own hold value
	Variable st = HKA_StateForTrace(traceNode)
	if( st < 0 )
		return NaN
	endif
	DFREF adf = $kHKA_DF
	Wave/SDFR=adf ab = HKA_Bytes
	NVAR/SDFR=adf aswap = HKA_Swap
	Variable ao = HKX_Off(kHKA_DF, "HKA_", st) + kHKA_StateBase
	if( ab[ao + kHKA_oMode] == 2 )								// CCMode
		unitOut = "A"
		return HKS_R8(ab, ao + kHKA_oCCIHold, aswap)
	endif
	unitOut = "V"
	return HKS_R8(ab, ao + kHKA_oVHold, aswap)
End


// =====================================================================================
//  HK_TraceMetaNote -- the acquisition metadata block, as "key=value;" pairs.
// =====================================================================================
Function/S HK_TraceMetaNote(traceNode)
	Variable traceNode

	String s = ""
	if( HK_Level(traceNode) != 4 )
		return s
	endif

	DFREF hk = root:Packages:HEKA
	Wave/Z/SDFR=hk nd = HK_Node
	if( !WaveExists(nd) )
		return s
	endif
	Variable sweepNode  = nd[traceNode][2]
	Variable seriesNode = nd[sweepNode][2]

	// ---- file / experiment ----------------------------------------------------------
	SVAR/Z pth = hk:HK_Path
	SVAR/Z ver = hk:HK_PMVersion
	if( SVAR_Exists(pth) )
		HKM_AddS(s, "FileName", HKM_LeafName(pth))
	endif
	if( SVAR_Exists(ver) )
		HKM_AddS(s, "PMVersion", ver)
	endif

	// ---- timing ---------------------------------------------------------------------
	HKM_AddS(s, "SweepTime", HK_GetS(sweepNode, "SwTime"))
	HKM_AddN(s, "Timer", HK_Num(sweepNode, "SwTimer"), "s")

	// ---- protocol -------------------------------------------------------------------
	HKM_AddS(s, "Stimulation", HKM_StimEntryName(traceNode))
	HKM_AddS(s, "SeriesLabel", HK_GetS(seriesNode, "SeLabel"))
	HKM_AddS(s, "Comment",     HK_GetS(seriesNode, "SeComment"))

	Variable isMon = HK_IsMonitorTrace(traceNode)
	HKM_AddS(s, "Monitor", num2istr(isMon))
	if( !isMon )
		// An auxiliary input does not belong to an amplifier; writing amplifier 1's
		// CSlow / Rs / gain here would be actively misleading, so it is left out.
		return s
	endif

	// ---- modes ----------------------------------------------------------------------
	HKM_AddS(s, "RecordingMode", HK_GetS(traceNode, "TrRecordingMode"))

	Variable st = HKA_StateForTrace(traceNode)
	if( st < 0 )
		HKM_AddS(s, "AmplifierState", "unavailable")
		return s
	endif

	DFREF adf = $kHKA_DF
	Wave/SDFR=adf ab    = HKA_Bytes
	NVAR/SDFR=adf aswap = HKA_Swap
	Variable ao = HKX_Off(kHKA_DF, "HKA_", st) + kHKA_StateBase

	Variable mode = ab[ao + kHKA_oMode]
	String modeNames = "TestMode;VCMode;CCMode;NoMode"
	HKM_AddS(s, "ClampMode", SelectString(mode < 4, num2istr(mode), StringFromList(mode, modeNames)))
	HKM_AddS(s, "AmplifierBoard", num2istr(ab[ao + kHKA_oActiveE9] + 1))

	// ---- holding --------------------------------------------------------------------
	String hUnit = ""
	Variable hold = HKM_Holding(traceNode, hUnit)
	HKM_AddN(s, "Holding", hold, hUnit)

	// ---- capacitance and access -----------------------------------------------------
	HKM_AddN(s, "CSlow", HKS_R8(ab, ao + kHKA_oCSlow, aswap), "F")

	Variable gser = HKS_R8(ab, ao + kHKA_oGSeries, aswap)
	Variable rser = NaN
	if( gser != 0 && numtype(gser) == 0 )
		rser = 1/gser
	endif
	HKM_AddN(s, "RSeries",  rser, "Ohm")
	HKM_AddN(s, "GSeries",  gser, "S")
	HKM_AddN(s, "RsValue",  HKS_R8(ab, ao + kHKA_oRsValue, aswap), "Ohm")

	Variable frac = HKS_R8(ab, ao + kHKA_oRsFraction, aswap)
	String t
	//sprintf t, "RsFraction=%.10g;RsFraction_disp=%.4g %%;", frac, frac*100
	sprintf t, "RsFraction=%.4g %%;", frac*100
	s += t

	Variable rsOn = ab[ao + kHKA_oRsOn]
	HKM_AddS(s, "RsOn", num2istr(rsOn))
	HKM_AddN(s, "RsTau", HKS_R8(ab, ao + kHKA_oRsTau, aswap), "s")

	// C-fast: two components of ONE amplifier, not two amplifiers
	HKM_AddN(s, "CFastAmp1", HKS_R8(ab, ao + kHKA_oCFastAmp1, aswap), "F")
	HKM_AddN(s, "CFastAmp2", HKS_R8(ab, ao + kHKA_oCFastAmp2, aswap), "F")
	HKM_AddN(s, "CFastTau",  HKS_R8(ab, ao + kHKA_oCFastTau,  aswap), "s")

	// ---- offsets and gain -----------------------------------------------------------
	HKM_AddN(s, "LJ",      HKS_R8(ab, ao + kHKA_oVLiquidJunc, aswap), "V")
	HKM_AddN(s, "VOffset", HKS_R8(ab, ao + kHKA_oVpOffset,    aswap), "V")

	Variable cgain = HKS_R8(ab, ao + kHKA_oCurrentGain, aswap)
	//sprintf t, "Gain=%.10g;Gain_disp=%.4g mV/pA;GainIndex=%d;", cgain, cgain/1e9, ab[ao + kHKA_oGainIndex]
	sprintf t, "Gain=%.4g mV/pA;GainIndex=%d;", cgain/1e9, ab[ao + kHKA_oGainIndex]
	s += t

	// ---- analog filters -------------------------------------------------------------
	// Filter 1: prefer the amplifier's own bandwidth figure, fall back to the value the
	// menu index implies if that field was never written.  When both exist and disagree
	// the index is the one PatchMaster showed the user, so say so rather than silently
	// picking one.
	Variable f1idx = ab[ao + kHKA_oFilter1]
	Variable f1bw  = HKS_R8(ab, ao + kHKA_oImon1Bw, aswap)
	Variable f1nom = HKM_Filter1Hz(f1idx)
	if( numtype(f1bw) != 0 || f1bw <= 0 )
		f1bw = f1nom
	elseif( numtype(f1nom) == 0 && abs(f1bw - f1nom) > 1 )
		Printf "HK_TraceMetaNote: %s -- Filter 1 index %d means %s but sImon1Bandwidth reads %s.\r", HK_PathString(traceNode), f1idx, HKM_Eng(f1nom,"Hz"), HKM_Eng(f1bw,"Hz")
	endif
	HKM_AddN(s, "Filter1", f1bw, "Hz")
	HKM_AddS(s, "Filter1Setting", HKM_Filter1Name(f1idx))

	// Filter 2: the dialled value and the achieved one, plus the characteristic.
	HKM_AddN(s, "Filter2",     HKS_R8(ab, ao + kHKA_oF2Frequency, aswap), "Hz")
	HKM_AddN(s, "Filter2Real", HKS_R8(ab, ao + kHKA_oF2Bandwidth, aswap), "Hz")
	HKM_AddS(s, "Filter2Type", HKM_F2TypeName(ab[ao + kHKA_oF2Response]))

	s=replacestring(";",s,";\r")
	return s
End


// =====================================================================================
//  HK_CheckRsConsistency -- re-runs  RSeries x RsFraction == RsValue  over a whole file.
//  That identity is what establishes which of the three Rs fields means what, so it is
//  worth being able to re-test it on any new recording.
// =====================================================================================
Function HK_CheckRsConsistency()

	if( HKA_Ensure() != 0 )
		Print "HK_CheckRsConsistency: no .amp block in this file."
		return -1
	endif
	DFREF adf = $kHKA_DF
	Wave/SDFR=adf ab    = HKA_Bytes
	NVAR/SDFR=adf aswap = HKA_Swap

	Variable nSe = HKX_NKids(kHKA_DF, "HKA_", 0)
	Variable si, k, st, ao
	Variable checked = 0, ok = 0, off = 0
	Variable g, f, rv, pred
	for( si = 0; si < nSe; si += 1 )
		Variable ase = HKX_Child(kHKA_DF, "HKA_", 0, si)
		for( k = 0; k < HKX_NKids(kHKA_DF, "HKA_", ase); k += 1 )
			st = HKX_Child(kHKA_DF, "HKA_", ase, k)
			ao = HKX_Off(kHKA_DF, "HKA_", st) + kHKA_StateBase
			g  = HKS_R8(ab, ao + kHKA_oGSeries,    aswap)
			f  = HKS_R8(ab, ao + kHKA_oRsFraction, aswap)
			rv = HKS_R8(ab, ao + kHKA_oRsValue,    aswap)
			if( g == 0 || f == 0 )
				continue									// compensation off: nothing to test
			endif
			checked += 1
			pred = (1/g) * f
			if( abs(pred - rv) <= 1e-6 * abs(rv) )
				ok += 1
			else
				off += 1
				if( off <= 3 )
					Printf "  board state %d/%d: RSeries*RsFraction = %.6g but RsValue = %.6g\r", si+1, k+1, pred, rv
				endif
			endif
		endfor
	endfor
	Printf "HK_CheckRsConsistency: %d compensated states checked -- %d consistent, %d off.\r", checked, ok, off
	if( checked == 0 )
		Print "   (Rs compensation is off everywhere in this file, so the identity could not be tested.)"
	endif
	return off
End


// =====================================================================================
//  HK_ShowMeta -- print a loaded trace's metadata note as an aligned table.
// =====================================================================================
Function HK_ShowMeta(w)
	Wave w

	String nt = note(w)
	Variable i, n = ItemsInList(nt, ";")
	String item, key, val
	Printf "---- %s ----\r", NameOfWave(w)
	for( i = 0; i < n; i += 1 )
		item = StringFromList(i, nt, ";")
		if( strlen(item) == 0 )
			continue
		endif
		key = StringFromList(0, item, "=")
		val = item[strlen(key)+1, inf]
		Printf "  %-18s %s\r", key, val
	endfor
	return 0
End


// =====================================================================================
//  HK_BaseName -- the prefix every generated wave name starts with.
//  Historically hard-coded as "P"; the browser's "Base name" field now writes
//  root:Packages:HEKA:HK_BaseName and every naming site reads it through here.  The
//  global lives in the loader's own data folder, not the GUI's, so loading from the
//  command line with no panel open still works and still honours whatever was set.
// =====================================================================================
Function/S HK_BaseName()

	if( !DataFolderExists("root:Packages:HEKA") )
		return "P"
	endif
	DFREF dfr = root:Packages:HEKA
	SVAR/Z b = dfr:HK_BaseName
	if( !SVAR_Exists(b) )
		return "P"
	endif
	String s = CleanupName(b, 0)
	if( strlen(s) == 0 )
		return "P"
	endif
	return s
End

Function HK_SetBaseName(newName)
	String newName

	if( !DataFolderExists("root:Packages") )
		NewDataFolder root:Packages
	endif
	if( !DataFolderExists("root:Packages:HEKA") )
		NewDataFolder root:Packages:HEKA
	endif
	DFREF dfr = root:Packages:HEKA
	SVAR/Z b = dfr:HK_BaseName
	if( !SVAR_Exists(b) )
		String/G dfr:HK_BaseName = "P"
		SVAR b2 = dfr:HK_BaseName
		b2 = newName
		return 0
	endif
	b = newName
	return 0
End
