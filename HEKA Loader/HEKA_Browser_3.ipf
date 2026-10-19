#pragma TextEncoding = "UTF-8"
#pragma rtGlobals = 3
#pragma IgorVersion = 7.00

// =====================================================================================
//  HEKA_Browser_3.ipf   --  five-column cascading browser, multi-select
//  Andre Dagostin / Vollum Institute
//
//  Requires HEKA_Tree_V2.ipf and HEKA_Load_4.ipf.
//  !! Remove the old HEKA_Browser.ipf from the experiment first -- the function names
//  !! are unchanged, so keeping both gives duplicate-name compile errors.
//
//  RUN IT
//      HK_Browser()
//
//  LAYOUT
//  Five listboxes side by side: Group | Series | Sweep | Trace | Series name.  In the
//  first four, clicking an item fills the listbox to its right and empties everything
//  further right.  The fifth stands apart -- see below.
//
//  SELECTION
//  ONE listbox owns the selection at a time, but it may hold MANY rows (ctrl-click /
//  shift-click, ListBox mode 10).  Clicking in a different listbox clears the others.
//  The last row clicked is the cascade ANCHOR -- it is what fills the column to the
//  right -- while everything selected in that column is what Load acts on.  So the
//  highlight now answers two questions at once: where you are (anchor) and what you
//  asked for (the whole selection).  The Load button title always states the count.
//
//  THE FIFTH LISTBOX -- "Series name"
//  Unique series labels within the current group, deduplicated, with how many series
//  carry each name.  Selecting a name means "every series in this group called that",
//  which is the quick way to pull all repeats of one protocol.  It is not part of the
//  cascade: choosing a name tints the matching rows in the Series column so you can
//  see what you asked for, and empties Sweep/Trace because there is no single anchor.
//
//  BASE NAME
//  The "Base name" field replaces the leading "P" of every generated wave name.  It
//  writes root:Packages:HEKA:HK_BaseName, which HEKA_Load_4's HK_BaseName() reads, so
//  traces AND stimulus waves follow it, and command-line loads honour it too.
//
//  The highlight and the browsing position are therefore different things, and both
//  are shown.  The single selection gets Igor's normal highlight; every upstream item
//  you navigated through keeps a pale blue TINT, so the trail Group > Series > Sweep
//  stays visible without any of them looking selected.  The "Path" line under the
//  listboxes spells the same thing out in words.
//
//  AUTO-ADVANCE
//  A sweep holding a single trace offers no choice, so clicking that sweep drops
//  straight into its trace: selected, described and plotted in one click.  See
//  HKB_AutoAdvance() to extend this to other levels.
//
//  LOADING
//  The Load button acts on EVERY selected row of the focused listbox.  Selecting
//  traces loads those traces; selecting sweeps, series or groups loads every trace
//  beneath each of them; selecting series names loads every series so called.  The
//  button title always states how many items and how many traces that is, so it is
//  never a guess.
// =====================================================================================
Menu "Andre"
	"Load Patchmaster", HK_Browser()	
end

static StrConstant kHKB_DF    = "root:Packages:HEKA:GUI"
static StrConstant kHKB_PANEL = "HekaBrowser"

static Constant kHKB_LeafLevel = 4			// traces, in the .pul tree
// listbox index 0..3  <->  .pul node level 1..4
static Constant kHKB_NumCols   = 2			// label column + count column

// Five listboxes: 0..3 are the Group/Series/Sweep/Trace cascade, 4 is the unique
// series-name list.  Only 0..3 have node waves; list 4's rows are names, not nodes.
static Constant kHKB_NLists    = 5
static Constant kHKB_NameList  = 4

// ListBox mode 10 = multiple, non-contiguous row selection.  This is the value
// WaveMetrics' own WaveSelectorWidget passes for that mode, so it is proven rather
// than inferred.  Igor owns bit 0 of the selWave for whichever list has the focus;
// HKB_Repaint() therefore leaves that list's plane 0 alone and only clears the others.
static Constant kHKB_ModeMulti = 10

// CELL COLOURING.  The colour index is NOT carried in the bits of the selWave value --
// it lives in a third DIMENSION of the selWave:
//     selWave must be 3D, N x cols x 2
//       plane 0  = the usual selection bits (bit 0 = selected)
//       plane 1  = an index into the ListBox colorWave, 0-based by row
//     and plane 1 must be labelled:   SetDimLabel 2, 1, backColors, selWave
//       (use "foreColors" instead to tint the text rather than the background)
//     colorWave is N x 3 -- one row per colour, columns are R, G, B (0..65535).
// A 2D selWave simply has no plane 1, which is why nothing was tinted before.
//
// HKB_Colors row 0 is white (the normal cell background, used by every untinted cell,
// since index 0 is a real colour and not a "no colour" sentinel) and row 1 is the tint.
static Constant kHKB_Selected  = 0x01
static Constant kHKB_TintIndex = 1			// row of HKB_Colors used for the upstream trail
static Constant kHKB_PlaneSel  = 0			// selWave plane holding the selection bits
static Constant kHKB_PlaneCol  = 1			// selWave plane holding the colour index

// Auto-advance: when a sweep holds exactly one trace, clicking the sweep selects and
// displays that trace straight away.  To extend the same courtesy to other levels
// (e.g. a series with a single sweep), add the level to HKB_AutoAdvance().
static Constant kHKB_AutoLevel = 2			// listbox 2 = Sweep


// -------------------------------------------------------------------------------------
//  Package folder + globals
// -------------------------------------------------------------------------------------
static Function/DF HKB_Home()

	DFREF nulldf = $""
	if( !DataFolderExists("root:Packages") )
		NewDataFolder root:Packages
	endif
	if( !DataFolderExists("root:Packages:HEKA") )
		NewDataFolder root:Packages:HEKA
	endif
	if( !DataFolderExists(kHKB_DF) )
		NewDataFolder $kHKB_DF
	endif
	DFREF dfr = $kHKB_DF

	SVAR/Z st = dfr:HKB_Status
	if( !SVAR_Exists(st) )
		String/G dfr:HKB_Status = "no file loaded"
	endif
	SVAR/Z dd = dfr:HKB_DestDF
	if( !SVAR_Exists(dd) )
		String/G dfr:HKB_DestDF = "root:HEKA_Data"
	endif
	SVAR/Z fs = dfr:HKB_FileStr
	if( !SVAR_Exists(fs) )
		String/G dfr:HKB_FileStr = "-- no file --"
	endif
	SVAR/Z pp = dfr:HKB_PathStr
	if( !SVAR_Exists(pp) )
		String/G dfr:HKB_PathStr = ""
	endif
	SVAR/Z inf = dfr:HKB_InfoStr
	if( !SVAR_Exists(inf) )
		String/G dfr:HKB_InfoStr = ""
	endif
	NVAR/Z zs = dfr:HKB_ZeroSub
	if( !NVAR_Exists(zs) )
		Variable/G dfr:HKB_ZeroSub = 0
	endif
	NVAR/Z pv = dfr:HKB_DoPreview
	if( !NVAR_Exists(pv) )
		Variable/G dfr:HKB_DoPreview = 1
	endif
	NVAR/Z ls = dfr:HKB_LoadStim
	if( !NVAR_Exists(ls) )
		Variable/G dfr:HKB_LoadStim = 0			// "also load stimulus" checkbox
	endif
	NVAR/Z sl = dfr:HKB_SelLevel
	if( !NVAR_Exists(sl) )
		Variable/G dfr:HKB_SelLevel = -1			// which listbox holds the selection
	endif

	Wave/Z/SDFR=dfr cur = HKB_Cur
	if( !WaveExists(cur) )
		Make/O/D/N=4 dfr:HKB_Cur/WAVE=cur2			// cascade anchor node at each level
		cur2 = -1
	endif

	// The base-name prefix lives in the LOADER's folder, not the GUI's, so that
	// HK_BaseName() finds it even with no panel open.
	if( !DataFolderExists("root:Packages:HEKA") )
		NewDataFolder root:Packages:HEKA
	endif
	DFREF hk = root:Packages:HEKA
	SVAR/Z bn = hk:HK_BaseName
	if( !SVAR_Exists(bn) )
		String/G hk:HK_BaseName = "P"
	endif

	Variable i
	for( i = 0; i < kHKB_NLists; i += 1 )
		Wave/Z/T/SDFR=dfr lw = $("HKB_L"+num2istr(i))
		if( !WaveExists(lw) )
			Make/O/T/N=(0, kHKB_NumCols)    dfr:$("HKB_L"+num2istr(i))
			Make/O/D/N=(0, kHKB_NumCols, 2) dfr:$("HKB_S"+num2istr(i))/WAVE=sw0
			Make/O/D/N=0                    dfr:$("HKB_N"+num2istr(i))
			HKB_LabelSelWave(sw0)
		endif
		// an experiment saved with the earlier 2D selWaves has no colour plane: add it
		Wave/Z/SDFR=dfr sw1 = $("HKB_S"+num2istr(i))
		if( WaveExists(sw1) )
			if( DimSize(sw1, 2) < 2 )
				Redimension/N=(DimSize(sw1,0), kHKB_NumCols, 2) sw1
			endif
			HKB_LabelSelWave(sw1)
		endif
	endfor

	// ListBox colour table: one row per colour, columns are R, G, B.
	// Row 0 is the ordinary white cell background -- index 0 is a real colour here,
	// not a "leave it alone" sentinel, so every untinted cell points at it.
	Wave/Z/SDFR=dfr cw = HKB_Colors
	if( !WaveExists(cw) )
		Make/O/W/U/N=(2,3) dfr:HKB_Colors/WAVE=cw2
		cw2[0][0] = 65535
		cw2[0][1] = 65535
		cw2[0][2] = 65535						// row 0: normal background
		cw2[1][0] = 52000
		cw2[1][1] = 57000
		cw2[1][2] = 65535						// row 1: pale blue, the upstream trail
	endif

	return dfr
End


// Tell Igor that plane 1 of a selWave carries background-colour indices.
// Change "backColors" to "foreColors" here to tint the text instead of the cell.
static Function HKB_LabelSelWave(sw)
	Wave sw

	if( !WaveExists(sw) )
		return -1
	endif
	if( DimSize(sw, 2) < 2 )
		return -1
	endif
	SetDimLabel 2, kHKB_PlaneCol, backColors, sw
	return 0
End


static Function HKB_HaveTree()
	if( !DataFolderExists("root:Packages:HEKA") )
		return 0
	endif
	DFREF dfr = root:Packages:HEKA
	Wave/Z/SDFR=dfr nd = HK_Node
	return WaveExists(nd)
End

static Function/WAVE HKB_ListW(L)
	Variable L
	DFREF gui = $kHKB_DF
	Wave/T/Z/SDFR=gui w = $("HKB_L"+num2istr(L))
	return w
End

static Function/WAVE HKB_SelW(L)
	Variable L
	DFREF gui = $kHKB_DF
	Wave/Z/SDFR=gui w = $("HKB_S"+num2istr(L))
	return w
End

static Function/WAVE HKB_NodeW(L)
	Variable L
	DFREF gui = $kHKB_DF
	Wave/Z/SDFR=gui w = $("HKB_N"+num2istr(L))
	return w
End


// =====================================================================================
//  MODEL
//  Only one derived quantity is needed: the extent of each node's subtree.  HK_Scan
//  stores the tree in DFS preorder, so a subtree is the contiguous block
//  [n, subEnd(n)) -- which makes "count / enumerate the traces under this node" a
//  plain range loop at any level.
// =====================================================================================
Function HKB_BuildModel()

	if( !HKB_HaveTree() )
		Print "HK_Browser: run HK_Scan() first."
		return -1
	endif
	DFREF gui = HKB_Home()
	DFREF dfr = root:Packages:HEKA
	Wave/SDFR=dfr nd = HK_Node

	Variable n = DimSize(nd, 0)
	Make/O/D/N=(n) gui:HKB_SubEnd/WAVE=subEnd

	Make/FREE/D/N=(n) stacks
	Variable sp = 0
	Variable i
	for( i = 0; i < n; i += 1 )
		do
			if( sp == 0 )
				break
			endif
			if( nd[ stacks[sp-1] ][0] < nd[i][0] )
				break
			endif
			sp -= 1
			subEnd[ stacks[sp] ] = i
		while( 1 )
		stacks[sp] = i
		sp += 1
	endfor
	do
		if( sp == 0 )
			break
		endif
		sp -= 1
		subEnd[ stacks[sp] ] = n
	while( 1 )

	Wave/SDFR=gui cur = HKB_Cur
	cur = -1
	NVAR sel = gui:HKB_SelLevel
	sel = -1
	return 0
End


// Rebuild the subtree table if it does not match the currently scanned tree -- e.g.
// the user ran HK_Scan() from the command line while this panel was open.
static Function HKB_EnsureModel()

	if( !HKB_HaveTree() )
		return -1
	endif
	DFREF gui = $kHKB_DF
	DFREF dfr = root:Packages:HEKA
	Wave/SDFR=dfr nd = HK_Node
	Wave/Z/SDFR=gui subEnd = HKB_SubEnd
	if( !WaveExists(subEnd) )
		return HKB_BuildModel()
	endif
	if( numpnts(subEnd) != DimSize(nd, 0) )
		return HKB_BuildModel()
	endif
	return 0
End


// Number of trace records inside a node's subtree.
static Function HKB_NumTraces(node)
	Variable node

	if( node < 0 )
		return 0
	endif
	if( HKB_EnsureModel() != 0 )
		return 0
	endif
	DFREF gui = $kHKB_DF
	DFREF dfr = root:Packages:HEKA
	Wave/SDFR=dfr nd     = HK_Node
	Wave/SDFR=gui subEnd = HKB_SubEnd

	Variable i, c = 0
	Variable b = subEnd[node]
	for( i = node; i < b; i += 1 )
		if( nd[i][0] == kHKB_LeafLevel )
			c += 1
		endif
	endfor
	return c
End


// =====================================================================================
//  LIST FILLING
// =====================================================================================

static Function/S HKB_Eng(v, unit)
	Variable v
	String unit

	if( numtype(v) != 0 )
		return "-"
	endif
	if( v == 0 )
		return "0 " + unit
	endif
	Variable e = floor( log(abs(v)) / 3 )
	e = min(max(e, -5), 3)
	String pfx = StringFromList(e + 5, "f;p;n;u;m;;k;M;G")
	String out
	sprintf out, "%.4g %s%s", v / (10^(3*e)), pfx, unit
	return out
End


static Function/S HKB_LeafName(pth)
	String pth

	Variable a = strsearch(pth, ":", inf, 1)
	Variable b = strsearch(pth, "\\", inf, 1)
	Variable k = max(a, b)
	if( k < 0 )
		return pth
	endif
	return pth[k+1, inf]
End


// Fill listbox L from the children of its parent node, and blank every listbox to the
// right of it.  L = 0..3 maps to .pul levels 1..4.
static Function HKB_FillLevel(L)
	Variable L

	DFREF gui = HKB_Home()
	DFREF dfr = root:Packages:HEKA
	Wave/SDFR=gui cur = HKB_Cur

	Variable parent
	if( L == 0 )
		parent = 0										// the root node
	else
		parent = cur[L-1]
	endif

	Wave/T lw = HKB_ListW(L)
	Wave   sw = HKB_SelW(L)
	Wave   nw = HKB_NodeW(L)

	Variable n = 0
	if( HKB_HaveTree() )
		if( parent >= 0 )
			n = HK_NumChildren(parent)
		endif
	endif
	if( numtype(n) != 0 )
		n = 0
	endif

	// drop the control's row selection BEFORE resizing, so it can never point past the
	// end of the new list
	DoWindow $kHKB_PANEL
	if( V_flag )
		ListBox $("lb"+num2istr(L)), win=$kHKB_PANEL, selRow=-1
	endif

	Redimension/N=(n, kHKB_NumCols)    lw
	Redimension/N=(n, kHKB_NumCols, 2) sw
	Redimension/N=(n) nw
	HKB_LabelSelWave(sw)
	lw = ""
	sw = 0

	Variable i, node
	String s
	for( i = 0; i < n; i += 1 )
		node  = HK_Child(parent, i)
		nw[i] = node
		sprintf s, "%d  %s", i+1, HK_Label(node)
		lw[i][0] = s
		switch( L )
			case 0:
				lw[i][1] = num2istr( HK_NumChildren(node) ) + " se"
				break
			case 1:
				lw[i][1] = num2istr( HK_NumChildren(node) ) + " sw"
				break
			case 2:
				lw[i][1] = num2istr( HK_NumChildren(node) ) + " tr"
				break
			case 3:
				lw[i][1] = num2istr( HK_Num(node, "TrDataPoints") )
				break
		endswitch
	endfor

	// everything further right is now meaningless
	if( L < 3 )
		cur[L+1, 3] = -1
		Variable k
		for( k = L+1; k < 4; k += 1 )
			Wave/T lw2 = HKB_ListW(k)
			Wave   sw2 = HKB_SelW(k)
			Wave   nw2 = HKB_NodeW(k)
			DoWindow $kHKB_PANEL
			if( V_flag )
				ListBox $("lb"+num2istr(k)), win=$kHKB_PANEL, selRow=-1
			endif
			Redimension/N=(0, kHKB_NumCols)    lw2
			Redimension/N=(0, kHKB_NumCols, 2) sw2
			Redimension/N=0 nw2
			HKB_LabelSelWave(sw2)
		endfor
	endif
	return n
End


// Repaint all four selWaves from the model.  One row per column can be marked, and it
// is marked one of two ways:
//     the column that holds the selection  -> Igor's normal highlight (bit 0)
//     a column further upstream            -> background tint via the colorWave index
// Painting everything from state on every change means a stray click can never leave
// two columns looking selected, which is the failure mode this design invites.
static Function HKB_Repaint()

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	NVAR sel = gui:HKB_SelLevel

	Variable L, r
	for( L = 0; L < kHKB_NLists; L += 1 )
		Wave sw = HKB_SelW(L)
		if( !WaveExists(sw) )
			continue
		endif
		if( DimSize(sw, 0) == 0 )
			continue
		endif

		// Plane 1 (the tint) is entirely ours, so clear it every time.
		sw[][][kHKB_PlaneCol] = 0

		// Plane 0 (the selection bits) belongs to Igor for whichever list has the
		// focus -- clearing it there would destroy a multi-row selection the moment
		// anything repaints.  Clear it only on the lists that no longer own the focus.
		if( L != sel )
			sw[][][kHKB_PlaneSel] = 0
			DoWindow $kHKB_PANEL
			if( V_flag )
				ListBox $("lb"+num2istr(L)), win=$kHKB_PANEL, selRow=-1
			endif
		endif
	endfor

	// Tint the cascade trail: one row per column upstream of the focused one.
	for( L = 0; L < 4; L += 1 )
		if( L >= sel || cur[L] < 0 )
			continue
		endif
		r = HKB_RowForNode(L, cur[L])
		if( r < 0 )
			continue
		endif
		Wave sw2 = HKB_SelW(L)
		sw2[r][][kHKB_PlaneCol] = kHKB_TintIndex
	endfor

	// When a series NAME owns the selection, tint every Series row it matches, so the
	// panel shows which series "all the ones called X" actually resolves to.
	if( sel == kHKB_NameList )
		Wave/T nlw = HKB_ListW(kHKB_NameList)
		Wave   nsw = HKB_SelW(kHKB_NameList)
		Wave   ssw = HKB_SelW(1)
		Variable nSe = 0
		if( cur[0] >= 0 )
			nSe = HK_NumChildren(cur[0])
		endif
		Variable k, se
		for( r = 0; r < DimSize(nsw, 0); r += 1 )
			if( !HKB_RowSelected(nsw, r) )
				continue
			endif
			for( k = 0; k < nSe; k += 1 )
				se = HK_Child(cur[0], k)
				if( CmpStr( HKB_SeriesLabel(se), nlw[r][0] ) == 0 )
					if( k < DimSize(ssw, 0) )
						ssw[k][][kHKB_PlaneCol] = kHKB_TintIndex
					endif
				endif
			endfor
		endfor
		// the group is still the trail
		if( cur[0] >= 0 )
			r = HKB_RowForNode(0, cur[0])
			if( r >= 0 )
				Wave gsw = HKB_SelW(0)
				gsw[r][][kHKB_PlaneCol] = kHKB_TintIndex
			endif
		endif
	endif
	return 0
End


// Row of listbox L showing node, or -1.
static Function HKB_RowForNode(L, node)
	Variable L, node

	Wave/Z nw = HKB_NodeW(L)
	if( !WaveExists(nw) || node < 0 )
		return -1
	endif
	Variable r
	for( r = 0; r < numpnts(nw); r += 1 )
		if( nw[r] == node )
			return r
		endif
	endfor
	return -1
End


// Is any cell of this row selected?  Igor may mark bit 0 in one column or all of
// them depending on mode, so test the whole row rather than assuming.
static Function HKB_RowSelected(sw, r)
	Wave sw
	Variable r

	if( !WaveExists(sw) || r < 0 || r >= DimSize(sw,0) )
		return 0
	endif
	Variable c
	for( c = 0; c < DimSize(sw,1); c += 1 )
		if( sw[r][c][kHKB_PlaneSel] & kHKB_Selected )
			return 1
		endif
	endfor
	return 0
End

static Function HKB_CountSelected(L)
	Variable L

	Wave/Z sw = HKB_SelW(L)
	if( !WaveExists(sw) )
		return 0
	endif
	Variable r, n = 0
	for( r = 0; r < DimSize(sw,0); r += 1 )
		if( HKB_RowSelected(sw, r) )
			n += 1
		endif
	endfor
	return n
End


// A series label, with empty labels given a visible stand-in.  Both the name list and
// the name -> series matching go through this, so they cannot disagree.
static Function/S HKB_SeriesLabel(seriesNode)
	Variable seriesNode

	String s = HK_Label(seriesNode)
	if( strlen(s) == 0 )
		return "(unnamed)"
	endif
	return s
End


// Unique series labels of the current group, with how many series carry each.
static Function HKB_FillNameList()

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	Wave/T lw = HKB_ListW(kHKB_NameList)
	Wave   sw = HKB_SelW(kHKB_NameList)
	Wave   nw = HKB_NodeW(kHKB_NameList)

	DoWindow $kHKB_PANEL
	if( V_flag )
		ListBox $("lb"+num2istr(kHKB_NameList)), win=$kHKB_PANEL, selRow=-1
	endif
	Redimension/N=(0, kHKB_NumCols)    lw
	Redimension/N=(0, kHKB_NumCols, 2) sw
	Redimension/N=0 nw
	HKB_LabelSelWave(sw)

	if( !HKB_HaveTree() || cur[0] < 0 )
		return 0
	endif
	Variable nSe = HK_NumChildren(cur[0])
	if( nSe <= 0 )
		return 0
	endif

	// TAB-separated so a series label containing ";" cannot split an entry
	String uniq = "", lbl
	Variable i
	for( i = 0; i < nSe; i += 1 )
		lbl = HKB_SeriesLabel( HK_Child(cur[0], i) )
		if( WhichListItem(lbl, uniq, "\t") < 0 )
			uniq += lbl + "\t"
		endif
	endfor

	Variable m = ItemsInList(uniq, "\t")
	Redimension/N=(m, kHKB_NumCols)    lw
	Redimension/N=(m, kHKB_NumCols, 2) sw
	Redimension/N=(m) nw
	HKB_LabelSelWave(sw)
	lw = ""
	sw = 0
	nw = -1

	Variable j, cnt
	for( i = 0; i < m; i += 1 )
		lbl = StringFromList(i, uniq, "\t")
		cnt = 0
		for( j = 0; j < nSe; j += 1 )
			if( CmpStr( HKB_SeriesLabel( HK_Child(cur[0], j) ), lbl ) == 0 )
				cnt += 1
			endif
		endfor
		lw[i][0] = lbl
		lw[i][1] = num2istr(cnt) + " se"
	endfor
	return m
End


// TAB-separated list of the series names selected in the name list.  TAB rather than
// ";" because a PatchMaster series label may well contain a semicolon.
static Function/S HKB_SelectedNames()

	Wave/Z/T lw = HKB_ListW(kHKB_NameList)
	Wave/Z   sw = HKB_SelW(kHKB_NameList)
	String out = ""
	if( !WaveExists(lw) || !WaveExists(sw) )
		return out
	endif
	Variable r
	for( r = 0; r < DimSize(lw, 0); r += 1 )
		if( HKB_RowSelected(sw, r) )
			out += lw[r][0] + "\t"
		endif
	endfor
	return out
End


// The nodes the Load button acts on, in tree order.  This one function is the whole
// answer to "what did the user ask for", so the button title, the info line and the
// loader cannot disagree about it.
//     focused list 0..3   -> the node of every selected row
//     focused list 4      -> every series in the current group whose label matches a
//                            selected name
// Returns a free numeric wave; numpnts() == 0 means there is nothing to load.
static Function/WAVE HKB_TargetNodes()

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	NVAR sel = gui:HKB_SelLevel

	Make/FREE/D/N=0 w_out
	if( sel < 0 )
		return w_out
	endif
	if( !HKB_HaveTree() )
		return w_out
	endif

	Variable k, n
	if( sel == kHKB_NameList )
		if( cur[0] < 0 )
			return w_out
		endif
		String names = HKB_SelectedNames()
		Variable nSe = HK_NumChildren(cur[0])
		Variable se
		for( k = 0; k < nSe; k += 1 )
			se = HK_Child(cur[0], k)
			if( WhichListItem( HKB_SeriesLabel(se), names, "\t" ) >= 0 )
				n = numpnts(w_out)
				Redimension/N=(n+1) w_out
				w_out[n] = se
			endif
		endfor
		return w_out
	endif

	Wave/Z nw = HKB_NodeW(sel)
	Wave/Z sw = HKB_SelW(sel)
	if( !WaveExists(nw) || !WaveExists(sw) )
		return w_out
	endif
	for( k = 0; k < numpnts(nw); k += 1 )
		if( HKB_RowSelected(sw, k) )
			n = numpnts(w_out)
			Redimension/N=(n+1) w_out
			w_out[n] = nw[k]
		endif
	endfor
	// Nothing marked: the cascade anchor is still the row we know was clicked.
	if( numpnts(w_out) == 0 )
		if( cur[sel] >= 0 )
			Redimension/N=1 w_out
			w_out[0] = cur[sel]
		endif
	endif
	return w_out
End


// How many traces sit beneath the whole current selection.
static Function HKB_TargetTraces(tgt)
	Wave tgt

	if( !WaveExists(tgt) )
		return 0
	endif
	Variable i, n = 0
	for( i = 0; i < numpnts(tgt); i += 1 )
		n += HKB_NumTraces(tgt[i])
	endfor
	return n
End


// =====================================================================================
//  SELECTION
// =====================================================================================
static Function HKB_Select(L, row)
	Variable L, row

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	NVAR sel = gui:HKB_SelLevel

	// ---- the series-name list is not part of the cascade ----------------------------
	if( L == kHKB_NameList )
		Wave/T nlw = HKB_ListW(kHKB_NameList)
		Wave   nsw = HKB_SelW(kHKB_NameList)
		if( row < 0 || row >= DimSize(nlw, 0) )
			return -1
		endif
		sel = kHKB_NameList
		// Igor normally sets the row's bit before calling us; if it reported nothing,
		// the clicked row is still the one thing we know about, so mark it ourselves.
		if( HKB_CountSelected(kHKB_NameList) == 0 )
			nsw[row][][kHKB_PlaneSel] = kHKB_Selected
		endif
		cur[1, 3] = -1							// no single anchor below the group
		HKB_FillLevel(2)						// empties Sweep and Trace
		HKB_Repaint()
		HKB_UpdatePath()
		HKB_UpdateInfo()
		HKB_UpdateLoadButton()
		return 0
	endif

	Wave nw = HKB_NodeW(L)
	if( row < 0 || row >= numpnts(nw) )
		return -1
	endif

	cur[L] = nw[row]							// the last row clicked is the anchor
	sel    = L

	// Igor marks the clicked row itself, but auto-advance and command-line calls reach
	// here with nothing marked.  Mark the row only when the list is empty of selection,
	// so a real ctrl-click multi-selection is never touched.
	Wave sw = HKB_SelW(L)
	if( HKB_CountSelected(L) == 0 )
		sw[row][][kHKB_PlaneSel] = kHKB_Selected
		DoWindow $kHKB_PANEL
		if( V_flag )
			ListBox $("lb"+num2istr(L)), win=$kHKB_PANEL, selRow=row
		endif
	endif

	// Cascade into the column on the right.  Never re-fill the column that was just
	// clicked -- that would rebuild its list wave and throw away the user's click.
	Variable nKids = 0
	if( L < 3 )
		nKids = HKB_FillLevel(L+1)
	endif
	if( L == 0 )
		HKB_FillNameList()						// the group changed
	endif

	HKB_Repaint()
	HKB_UpdatePath()
	HKB_UpdateInfo()
	HKB_UpdateLoadButton()

	NVAR doPrev = gui:HKB_DoPreview
	if( doPrev )
		if( HK_Level(cur[L]) == kHKB_LeafLevel )
			HKB_Preview(cur[L])
		endif
	endif

	// A sweep with a single trace has nothing to choose: go straight to the trace so
	// it is selected, described and plotted in one click.  Only when the click picked
	// exactly one sweep -- auto-advancing out of a multi-sweep selection would throw
	// that selection away.
	if( HKB_CountSelected(L) <= 1 )
		if( HKB_AutoAdvance(L, nKids) )
			HKB_Select(L+1, 0)
		endif
	endif
	return 0
End


// Should clicking level L, which turned out to have nKids children, drop straight into
// the only one?  Add levels here to extend the behaviour (e.g. `|| L == 1` would make a
// series holding a single sweep advance too).
static Function HKB_AutoAdvance(L, nKids)
	Variable L, nKids

	if( nKids != 1 )
		return 0
	endif
	if( L != kHKB_AutoLevel )
		return 0
	endif
	return 1
End


static Function HKB_UpdatePath()

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	SVAR ps = gui:HKB_PathStr
	NVAR sel = gui:HKB_SelLevel

	String names  = "Group;Series;Sweep;Trace;Series name"
	String plural = "Groups;Series;Sweeps;Traces;Series names"
	String s = "", tail = ""
	Variable k
	for( k = 0; k < 4; k += 1 )
		if( cur[k] < 0 )
			break
		endif
		if( strlen(s) )
			s += "  >  "
		endif
		s += StringFromList(k, names) + " " + num2istr( HK_SiblingIndex(cur[k]) + 1 )
		if( strlen(HK_Label(cur[k])) )
			s += " (" + HK_Label(cur[k]) + ")"
		endif
	endfor
	if( strlen(s) == 0 )
		s = "-- nothing selected --"
	endif

	// The anchor above is where you are; this is what you asked for.  They differ as
	// soon as more than one row is picked, so both get said.
	Variable n = 0
	if( sel >= 0 )
		n = HKB_CountSelected(sel)
	endif
	if( sel == kHKB_NameList )
		String nm = HKB_SelectedNames()
		if( n == 1 )
			tail = "      [selected: series name \"" + StringFromList(0, nm, "\t") + "\"]"
		elseif( n > 1 )
			sprintf tail, "      [selected: %d series names]", n
		endif
	elseif( sel >= 0 )
		if( n > 1 )
			sprintf tail, "      [selected: %d %s]", n, StringFromList(sel, plural)
		else
			tail = "      [selected: " + StringFromList(sel, names) + "]"
		endif
	endif
	ps = "Path:  " + s + tail
	return 0
End


static Function HKB_UpdateInfo()

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	SVAR inf = gui:HKB_InfoStr
	NVAR sel = gui:HKB_SelLevel

	inf = ""
	if( sel < 0 )
		return 0
	endif

	Wave/Z tgt = HKB_TargetNodes()
	Variable nItems = 0
	if( WaveExists(tgt) )
		nItems = numpnts(tgt)
	endif
	if( nItems == 0 )
		return 0
	endif

	// A set has no single description worth printing, so describe the set.  A series
	// name is always a set, even when it happens to match exactly one series.
	if( sel == kHKB_NameList || nItems > 1 )
		String u = StringFromList(sel, "groups;series;sweeps;traces;series")
		sprintf inf, "%d %s selected,  %d traces total", nItems, u, HKB_TargetTraces(tgt)
		return 0
	endif

	Variable node = tgt[0]
	Variable npnts, dt
	String s = ""
	switch( sel )
		case 0:
			sprintf s, "%d series,  %d traces total", HK_NumChildren(node), HKB_NumTraces(node)
			break
		case 1:
			sprintf s, "%d sweeps,  %d traces total", HK_NumChildren(node), HKB_NumTraces(node)
			break
		case 2:
			sprintf s, "%d traces", HK_NumChildren(node)
			break
		case 3:
			npnts = HK_Num(node, "TrDataPoints")
			dt    = HK_Num(node, "TrXInterval")
			sprintf s, "%d pts   %s   %s   %s   %s", npnts, HKB_Eng(npnts*dt, HK_GetS(node,"TrXUnit")), HK_GetS(node,"TrYUnit"), HK_DataFormatName(HK_Num(node,"TrDataFormat")), HK_GetS(node,"TrRecordingMode")
			if( HK_IsLeakTrace(node) )
				s += "   (leak)"
			endif
			break
	endswitch
	inf = s
	return 0
End


static Function HKB_UpdateLoadButton()

	DFREF gui = HKB_Home()
	NVAR sel = gui:HKB_SelLevel

	DoWindow $kHKB_PANEL
	if( !V_flag )
		return 0
	endif

	String t = "Load  --  nothing selected"
	Wave/Z tgt = HKB_TargetNodes()
	Variable nItems = 0
	if( WaveExists(tgt) )
		nItems = numpnts(tgt)
	endif
	if( nItems > 0 )
		Variable nTr = HKB_TargetTraces(tgt)
		if( nItems == 1 )
			if( nTr == 1 )
				t = "Load selected trace"
			else
				sprintf t, "Load selected  (%d traces)", nTr
			endif
		else
			sprintf t, "Load %d selected  (%d traces)", nItems, nTr
		endif
	endif
	Button bLoad, win=$kHKB_PANEL, title=t
	return 0
End


// =====================================================================================
//  PANEL
// =====================================================================================
Function HK_Browser()

	DoWindow $kHKB_PANEL
	if( V_flag )
		DoWindow/F $kHKB_PANEL
		return 0
	endif

	DFREF gui = HKB_Home()
	Wave/T l0 = HKB_ListW(0)
	Wave/T l1 = HKB_ListW(1)
	Wave/T l2 = HKB_ListW(2)
	Wave/T l3 = HKB_ListW(3)
	Wave/T l4 = HKB_ListW(4)
	Wave   s0 = HKB_SelW(0)
	Wave   s1 = HKB_SelW(1)
	Wave   s2 = HKB_SelW(2)
	Wave   s3 = HKB_SelW(3)
	Wave   s4 = HKB_SelW(4)
	Wave   cw = gui:HKB_Colors

	NewPanel/K=1/N=$kHKB_PANEL/W=(80, 80, 1020, 540) as "HEKA DAT Browser"

	Button   bOpen,  pos={8,6},   size={80,20},  title="Open .dat...", fsize=11, proc=HKB_ButtonProc
	TitleBox tFile,  pos={94,10}, size={640,16}, frame=0, fsize=10, variable=root:Packages:HEKA:GUI:HKB_FileStr

	TitleBox hGr,    pos={10,30},  size={138,14}, frame=0, fsize=11, title="\\f01Group"
	TitleBox hSe,    pos={156,30}, size={138,14}, frame=0, fsize=11, title="\\f01Series"
	TitleBox hSw,    pos={302,30}, size={138,14}, frame=0, fsize=11, title="\\f01Sweep"
	TitleBox hTr,    pos={448,30}, size={138,14}, frame=0, fsize=11, title="\\f01Trace"
	TitleBox hNm,    pos={594,30}, size={138,14}, frame=0, fsize=11, title="\\f01Series name"

	ListBox  lb0, pos={8,46},   size={140,320}, proc=HKB_ListProc
	ListBox  lb0, listWave=l0, selWave=s0, colorWave=cw, mode=kHKB_ModeMulti, widths={88,40}
	ListBox  lb1, pos={154,46}, size={140,320}, proc=HKB_ListProc
	ListBox  lb1, listWave=l1, selWave=s1, colorWave=cw, mode=kHKB_ModeMulti, widths={88,40}
	ListBox  lb2, pos={300,46}, size={140,320}, proc=HKB_ListProc
	ListBox  lb2, listWave=l2, selWave=s2, colorWave=cw, mode=kHKB_ModeMulti, widths={88,40}
	ListBox  lb3, pos={446,46}, size={140,320}, proc=HKB_ListProc
	ListBox  lb3, listWave=l3, selWave=s3, colorWave=cw, mode=kHKB_ModeMulti, widths={88,40}
	ListBox  lb4, pos={592,46}, size={140,320}, proc=HKB_ListProc
	ListBox  lb4, listWave=l4, selWave=s4, colorWave=cw, mode=kHKB_ModeMulti, widths={88,40}

	TitleBox tPath,   pos={8,374}, size={724,16}, frame=0, fsize=11, variable=root:Packages:HEKA:GUI:HKB_PathStr
	TitleBox tInfo,   pos={8,394}, size={724,16}, frame=0, fsize=11, variable=root:Packages:HEKA:GUI:HKB_InfoStr
	TitleBox tStatus, pos={8,416}, size={724,16}, frame=0, fsize=11, variable=root:Packages:HEKA:GUI:HKB_Status

	Button   bLoad,  pos={742,46},  size={190,26}, title="Load  --  nothing selected", fsize=11, proc=HKB_ButtonProc
	CheckBox cZero,  pos={742,80},  size={190,14}, title="subtract TrZeroData", fsize=11, variable=root:Packages:HEKA:GUI:HKB_ZeroSub
	CheckBox cStim,  pos={742,98},  size={190,14}, title="also load stimulus",  fsize=11, variable=root:Packages:HEKA:GUI:HKB_LoadStim
	CheckBox cPrev,  pos={742,116}, size={190,14}, title="preview on click",    fsize=11, variable=root:Packages:HEKA:GUI:HKB_DoPreview
	SetVariable svBase, pos={742,138}, size={190,16}, title="Base ", fsize=11, value=root:Packages:HEKA:HK_BaseName
	SetVariable svDest, pos={742,160}, size={190,16}, title="Into ", fsize=11, value=root:Packages:HEKA:GUI:HKB_DestDF
	Button   bInfo,  pos={742,184}, size={190,18}, title="Dump metadata", fsize=11, proc=HKB_ButtonProc

	Display/W=(742,212,932,366)/HOST=$kHKB_PANEL/N=Preview
	ModifyGraph/W=$(kHKB_PANEL+"#Preview") margin(left)=38, margin(bottom)=26, margin(top)=8, margin(right)=8
	ModifyGraph/W=$(kHKB_PANEL+"#Preview") fSize=9

	SetWindow $kHKB_PANEL, hook(HKBhook) = HKB_WinHook

	if( HKB_HaveTree() )
		HKB_AfterScan()
	endif
	return 0
End


static Function HKB_AfterScan()

	DFREF gui = HKB_Home()
	DFREF dfr = root:Packages:HEKA
	SVAR fs = gui:HKB_FileStr
	SVAR/Z pth = dfr:HK_Path
	SVAR/Z ver = dfr:HK_PMVersion
	if( SVAR_Exists(pth) )
		fs = HKB_LeafName(pth)
		if( SVAR_Exists(ver) )
			fs += "      [" + ver + "]"
		endif
	endif

	HKB_BuildModel()
	HKB_FillLevel(0)					// groups; this also blanks series/sweep/trace
	HKB_FillNameList()					// empties it: no group is chosen yet
	HKB_Repaint()
	HKB_UpdatePath()
	HKB_UpdateInfo()
	HKB_UpdateLoadButton()
	HKB_UpdateStatus()
	return 0
End


static Function HKB_UpdateStatus()

	DFREF gui = HKB_Home()
	DFREF dfr = root:Packages:HEKA
	SVAR st = gui:HKB_Status
	Wave/Z/SDFR=dfr nd = HK_Node
	if( !WaveExists(nd) )
		st = "no file loaded"
		return -1
	endif

	Variable i, nTot = 0
	for( i = 0; i < DimSize(nd,0); i += 1 )
		if( nd[i][0] == kHKB_LeafLevel )
			nTot += 1
		endif
	endfor
	sprintf st, "%d traces in this file", nTot
	return 0
End


// =====================================================================================
//  CONTROLS
// =====================================================================================
Function HKB_ListProc(LB) : ListBoxControl
	STRUCT WMListboxAction &LB

	if( !DataFolderExists(kHKB_DF) )
		return 0
	endif
	// 3 = double click, 4 = cell selection, 5 = cell selection with shift held (Igor
	// sends 5 for a shift-click range, so leaving it out would drop those selections).
	if( LB.eventCode != 3 && LB.eventCode != 4 && LB.eventCode != 5 )
		return 0
	endif
	if( LB.row < 0 )
		return 0
	endif
	String LB_Str=LB.ctrlName
	Variable L = str2num( LB_Str[2] )				// "lb0".."lb4"
	if( numtype(L) != 0 )
		return 0
	endif
	if( L < 0 || L >= kHKB_NLists )
		return 0
	endif
	HKB_Select(L, LB.row)
	return 0
End


Function HKB_ButtonProc(B) : ButtonControl
	STRUCT WMButtonAction &B

	if( B.eventCode != 2 )
		return 0
	endif

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	NVAR sel = gui:HKB_SelLevel
	Variable i

	strswitch( B.ctrlName )
		case "bOpen":
			if( HK_Scan("") > 0 )
				HKB_AfterScan()
			endif
			break

		case "bLoad":
			HK_BrowserLoadSelected()
			break

		case "bInfo":
			// Every selected item, not just the anchor -- and via HKB_TargetNodes() so
			// that a series name dumps the series it stands for.  (cur has only the
			// four cascade levels, so it must not be indexed with the name list.)
			Wave/Z tgt = HKB_TargetNodes()
			if( WaveExists(tgt) )
				for( i = 0; i < numpnts(tgt); i += 1 )
					HK_Dump(tgt[i])
					if( HK_Level(tgt[i]) == kHKB_LeafLevel )
						HK_TraceInfo(tgt[i])
					endif
				endfor
			endif
			break
	endswitch
	return 0
End


static Function HKB_Preview(node)
	Variable node

	DFREF gui = HKB_Home()
	NVAR zs = gui:HKB_ZeroSub

	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder gui
	Wave/Z w = HK_LoadTrace(node, destName="HKB_Prev", zeroSub=zs)
	SetDataFolder saveDF
	if( !WaveExists(w) )
		return -1
	endif

	// No DoWindow test: DoWindow does not accept subwindow syntax, and the Preview
	// subwindow is created with the panel, so it exists whenever we get here.
	String gw = kHKB_PANEL + "#Preview"
	CheckDisplayed/W=$gw w
	if( V_flag == 0 )
		AppendToGraph/W=$gw w
		ModifyGraph/W=$gw rgb=(0,0,0)
	endif
	Label/W=$gw bottom "\\u#2" + WaveUnits(w, 0)
	Label/W=$gw left   "\\u#2" + WaveUnits(w, -1)
	return 0
End


// =====================================================================================
//  LOADING
// =====================================================================================

static Function/DF HKB_MakeDF(pathStr)
	String pathStr

	if( strlen(pathStr) == 0 )
		pathStr = "root:"
	endif
	if( CmpStr(pathStr[0,4], "root:") != 0 )
		pathStr = "root:" + pathStr
	endif
	if( CmpStr(pathStr[strlen(pathStr)-1], ":") != 0 )
		pathStr += ":"
	endif

	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder root:
	Variable i
	String part
	for( i = 1; i < ItemsInList(pathStr, ":"); i += 1 )		// item 0 is "root"
		part = StringFromList(i, pathStr, ":")
		if( strlen(part) == 0 )
			continue
		endif
		NewDataFolder/O/S $part
	endfor
	DFREF dest = GetDataFolderDFR()
	SetDataFolder saveDF
	return dest
End


// A short description of the selection for the history line: the paths of the selected
// nodes, the names when the name list is driving, or just a count when there are too
// many to be worth reading.
static Function/S HKB_WhatLoaded(tgt)
	Wave tgt

	DFREF gui = HKB_Home()
	Wave/SDFR=gui cur = HKB_Cur
	NVAR sel = gui:HKB_SelLevel

	String s = ""
	if( sel == kHKB_NameList )
		s = ReplaceString("\t", HKB_SelectedNames(), ", ")
		s = "\"" + RemoveEnding(s, ", ") + "\""
		if( cur[0] >= 0 )
			s += "  in  " + HK_PathString(cur[0])
		endif
		return s
	endif
	if( !WaveExists(tgt) )
		return s
	endif
	Variable n = numpnts(tgt)
	if( n > 6 )
		return num2istr(n) + " items"
	endif
	Variable i
	for( i = 0; i < n; i += 1 )
		if( strlen(s) )
			s += ", "
		endif
		s += HK_PathString(tgt[i])
	endfor
	return s
End


// Loads everything selected: the traces themselves, or every trace beneath each
// selected sweep, series or group, or every series carrying a selected name.
Function HK_BrowserLoadSelected()

	if( !HKB_HaveTree() )
		Print "HK_BrowserLoadSelected: nothing scanned."
		return -1
	endif
	HKB_EnsureModel()
	DFREF gui = HKB_Home()
	DFREF dfr = root:Packages:HEKA
	Wave/SDFR=gui cur    = HKB_Cur
	Wave/SDFR=gui subEnd = HKB_SubEnd
	Wave/SDFR=dfr nd     = HK_Node
	NVAR sel  = gui:HKB_SelLevel
	SVAR destStr = gui:HKB_DestDF
	SVAR st      = gui:HKB_Status
	NVAR zs      = gui:HKB_ZeroSub

	if( sel < 0 )
		Print "HK_BrowserLoadSelected: nothing selected."
		return 0
	endif

	Wave/Z tgt = HKB_TargetNodes()
	Variable nT = 0
	if( WaveExists(tgt) )
		nT = numpnts(tgt)
	endif
	if( nT == 0 )
		Print "HK_BrowserLoadSelected: nothing selected."
		return 0
	endif

	Variable nSel = HKB_TargetTraces(tgt)
	if( nSel == 0 )
		Print "HK_BrowserLoadSelected: the selection contains no traces."
		return 0
	endif

	DFREF dest   = HKB_MakeDF(destStr)
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder dest

	NVAR doStim = gui:HKB_LoadStim

	Variable t0 = StopMSTimer(-2)
	Variable i, j, node, b, got = 0, failed = 0, gotStim = 0
	Variable swNode, lastSweep = -1
	for( j = 0; j < nT; j += 1 )
		node = tgt[j]
		b    = subEnd[node]
		for( i = node; i < b; i += 1 )
			if( nd[i][0] != kHKB_LeafLevel )
				continue
			endif
			Wave/Z w = HK_LoadTrace(i, zeroSub=zs)
			if( WaveExists(w) )
				got += 1
				if( doStim )
					Wave/Z sm = HK_LoadStimulus(i)
					if( WaveExists(sm) )
						gotStim += 1
					endif
					// Stimulus channels that drive nothing recorded (a digital train to
					// a stimulus isolator, say) belong to the SWEEP, not to any trace.
					// Traces of a sweep are contiguous in preorder, so one call per new
					// sweep node picks them up exactly once.  Selections never overlap
					// -- they are rows of one listbox -- so no sweep is revisited.
					swNode = nd[i][2]
					if( swNode != lastSweep )
						gotStim += HK_LoadUnmatchedStimuli(swNode)
						lastSweep = swNode
					endif
				endif
			else
				failed += 1
			endif
			//if( mod(got, 25) == 0 )
				sprintf st, "loading...  %d of %d", got, nSel
				DoUpdate
			//endif
		endfor
	endfor

	SetDataFolder saveDF
	Variable dt = (StopMSTimer(-2) - t0) * 1e-6

	String dfName = GetDataFolder(1, dest)
	String extra = ""
	if( doStim )
		sprintf extra, " + %d stimuli", gotStim
	endif
	sprintf st, "%d traces%s loaded into %s   (%.2f s)", got, extra, dfName, dt
	Printf "HK_BrowserLoadSelected: %s %s -> %d traces%s in %s   (%.2f s)\r", StringFromList(sel, "Group;Series;Sweep;Trace;Series name"), HKB_WhatLoaded(tgt), got, extra, dfName, dt
	if( failed )
		Printf "   %d traces failed to load.\r", failed
	endif
	if( doStim )
		if( gotStim < got )
			Printf "   %d trace(s) had no matching stimulus channel and were loaded as data only.\r", got - gotStim
		endif
	endif
	return got
End


// =====================================================================================
Function HKB_WinHook(s)
	STRUCT WMWinHookStruct &s

	switch( s.eventCode )
		case 2:				// window killed
			if( DataFolderExists(kHKB_DF) )
				DFREF gui = $kHKB_DF
				Wave/Z/SDFR=gui pw = HKB_Prev
				KillWaves/Z pw
			endif
			break
	endswitch
	return 0
End
