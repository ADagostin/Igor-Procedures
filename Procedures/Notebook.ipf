#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function /t Get_Images()
String Image_List
Image_list=sortlist(winlist("*",";","Win:1"),";",16)
return Image_list
end

Function MK_NT()
dowindow Panel_load
if (V_flag==0)
	Newpanel /n=Panel_Load /w=(100,100,700,500) /k=1 as "Build Notebook"
endif
Svar /z File_folder
Svar /z Save_NB
Svar /z Image_Folder
if (!SVar_Exists (File_Folder)) 															//Was the global string created already?
	String /G File_Folder//="VIBA269:Users:dagostia:Box Sync:Recs 2021:June:060321.dat" 	// SET THE BLOODY FILE PATH HERE!! 
	String /G Image_Folder
	If (Stringmatch(Stringbykey("OS",IgorInfo(3)),"*Mac*")) 							//is the function running in a MAc or in a PC?
		String /G Save_NB="VIBA269:Users:dagostia:Desktop"
	EndIf
	IF (Stringmatch(Stringbykey("OS",IgorInfo(3)),"*Windows*")) 
		String /G Save_NB="C:\\Users\\dagostia\\desktop"
	endif
endif
Setvariable File_Name 	bodyWidth=470, title="Path to file" , FSize=12, value=File_Folder
Setvariable Save_NB 	bodyWidth=430, title="Path to save Notebook" , FSize=12, value=Save_NB
Setvariable Img_Folder 	bodyWidth=230, title=" ", FSize=12, value=Image_Folder
doupdate
Setvariable File_Name 	pos={15, 15}
Setvariable Save_NB 	pos={15, 90}
SetDrawEnv /W=Panel_Load fSize=20, xcoord=abs, ycoord=abs
Drawtext /W=Panel_Load 15,255,"Image Folder"
Setvariable Img_Folder 	pos={15,260}
Button refresho 				pos={15,40},Title="Load & Refresh",size={120,30},fsize=14,proc=grab
Button New_Folder_Data 	pos={150,40},Title="Set Folder",size={120,30},fsize=14, proc=Set_Folder
Button Save_Notbook		pos={15,115},Title="Save Notebook",size={120,30},fsize=14, proc=SaveNote
Button New_Folder_Save 	pos={150,115},Title="Set Folder",size={120,30},fsize=14, proc=Set_Folder
Button New_Folder_Image 	pos={15,285},Title="Set Folder",size={120,30},fsize=14, proc=Set_Folder
Button New_File_Image 		pos={150,285},Title="Load Image File",size={120,30},fsize=14, proc=Get_image
Button Insert_Image	 		pos={15,315},Title="Append Image to Notebook",size={255,30},fsize=14, proc=Set_Folder
SetDrawEnv /W=Panel_Load fSize=20, xcoord=abs, ycoord=abs
Drawtext /W=Panel_Load 15,190,"Select from loaded images"
SetDrawEnv /W=Panel_Load fSize=20, xcoord=abs, ycoord=abs
Popupmenu Images Win=Panel_Load, fSize=16, title="", bodywidth=120, pos={80,200}, Value=Get_Images(),proc=Mini_Image
end

Function Set_Folder(Fdr_Struct) : Buttoncontrol
	Struct WMButtonAction &Fdr_Struct
	Svar Save_NB
	Svar File_Folder
	Svar Image_Folder
	If (Fdr_Struct.Eventcode==2)
		StrSwitch (Fdr_Struct.CtrlName)
			Case "New_Folder_Save":
				getfilefolderinfo /Q /D
				Save_NB = S_Path
				break
			Case "New_Folder_Data":
				GetFileFOlderInfo /Q
				File_Folder=S_Path
				Break
			Case "New_Folder_Image":
				GetFileFOlderInfo /Q /D
				Image_Folder=S_Path
				//Get_image()
				break
			Case "Insert_Image":
				Controlinfo /W=Panel_Load Images
				Notebook nov picture={$S_Value,-5,0}
				break
		endswitch
	endif
end


Function Mini_Image(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	Controlinfo /W=Panel_load Images
	String Wv=wavelist("*",";","Win:"+S_Value)
	if (wintype("panel_load#frame")!=0)
		killwindow panel_load#Frame
	endif
	Display /Host=Panel_load /w=(270,200,580,380) /N=Frame
	appendimage /W=Panel_load#Frame $Stringfromlist(0,Wv)
	modifygraph /W=Panel_load#Frame wbRGB=(61166,61166,61166), frameInset=2,framestyle=2
	SetAxis/A/R left

end


function Make_Notebook()
String Exp_Date
Dowindow Data
if (V_Flag==1)
Killwindow Data
endif
Newnotebook /f=1 /k=1 /n=Data
Notebook data, tabs={1*36, 3*72}
String Group
String Series
String List
Variable i,j,k
String Base_Name, Stim_Name
String expr="([[:alpha:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:alpha:]]+)-([[:digit:]]+)"
String Base, Gr, Se, Sw, Tr, Name, Namen=""
splitstring/E=(expr) Stringfromlist(0,sortlist(wavelist("*",";",""),";",16)),Base, Gr, Se, Sw, Tr, Name, Namen

if (strlen (Base)<1)
	    expr="([[:alpha:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:alpha:]]+)"//_([[:digit:]]+)"
	    splitstring/E=(expr) Stringfromlist(0,sortlist(wavelist("*",";",""),";",16)),Base, Gr, Se, Sw, Tr, Name, Namen	
	    Print "P_",Base ,Name   
endif
if (strlen (Base)<1)
	    expr="([[:alpha:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:alpha:]]+)([[:digit:]]+)"
	    splitstring/E=(expr) Stringfromlist(0,sortlist(wavelist("*",";",""),";",16)),Base, Gr, Se, Sw, Tr, Name, Namen	    
	    Print "None"
endif

String Initial_series, Final_Series, Initial_Group, Final_Group
Variable Version=round(IgorVersion())
String FirstChar, Write_timer
Initial_Series=""
i=str2num(Gr)
do
	if (Version<8)
	Base_Name="PMPulse_"+num2str(i)
	else
	Base_Name="P_"+num2str(i)
	endif
	List=sortlist(wavelist(Base_Name+"*",";",""),";",16)
	If(Strlen(list)==0)
	//print "List is null"
		break
	endif
	Notebook Data, fSize=18, fStyle=4,text="\r\r"+"Cell #"+num2str(i)+"\r\r"
	Notebook Data, fSize=12, fStyle=0
	do		
		splitstring/E=(expr) Stringfromlist(j,list),Base, Gr, Se, Sw, Tr, Name, Namen
	
		Final_Series=Se
		Final_Group=Gr
		if (stringmatch(Final_series,Initial_Series)==0 || Stringmatch(Initial_Group,Final_Group)==0 && Strlen(Se)!=0)
			if (Version<8)
				Write_timer=stringbykey("\rTimer",note($Stringfromlist(j,list)),":")[3,inf]
				Stim_name=stringbykey("\rStimulation",note($Stringfromlist(j,list)),":")[2,inf]
				
			else
				Stim_name=stringbykey("PMStimulationName",note($Stringfromlist(j,list)),":")
				Write_Timer=stringbykey("Timer",note($Stringfromlist(j,list)),":")
				if (Strlen(stim_name)==0)
					Write_timer=stringbykey("\rTimer",note($Stringfromlist(j,list)),":")[1,inf]
					Stim_name=stringbykey("\rStimulation",note($Stringfromlist(j,list)),":")[1,inf]
				endif 
			Endif
			notebook data, text="Series "+Se+": "
			notebook data, fStyle=1, text=Stim_Name//+"\r"
			notebook data, fStyle=0
			notebook data, text="\t\tTimer: "+Write_Timer+"\r"
		endif
		Initial_Series=Se
		Initial_Group=Gr
		j+=1
	while(j<itemsinlist(list)-1)
	j=0
	i+=1
while (1)
//Grab()
end

function grab(Ctrlname):Buttoncontrol
String Ctrlname
Svar File_Folder
if (strlen (File_Folder)==0)
	GetFileFolderInfo /q
	If (V_Flag==-1)
		abort
	endif
	File_Folder=S_Path
endif
Variable Version=round(IgorVersion())
String Load 
if (Version<8)
	Load =   "LoadPM/Q "+"\""+File_Folder+"\"" 
	else
	Load= "bpc_LoadPM/R=1/N="+"\""+"P"+"\""+"/O/Q/W "+"\""+replacestring ("C\\",replacestring (":",File_Folder,"\\\\"),"c:\\")+"\""
endif
Execute Load

dowindow Data
if (V_flag==0)
Make_Notebook()
endif
Dowindow Nov
if (V_flag==0)
renamewindow Data, Nov
make_notebook()
endif

Variable Cell_Start_Paragraph, Cell_start_Pos
Variable Series_Start_Paragraph, Series_start_Pos

notebook nov Selection={EndOfFile, EndOFFile}, findtext={"Cell", 16}
getselection notebook, nov, 1
Cell_Start_Paragraph=V_startParagraph
Cell_start_Pos=V_startPos
notebook nov selection={(Cell_Start_Paragraph,0),(Cell_Start_Paragraph+1,0)}
getselection notebook, nov, 2
String Sel_Cell=S_Selection[6,inf]
String Current_Cell="Cell #"+Sel_Cell
notebook nov Selection={EndOfFile, EndOFFile}, findtext={"Series", 16}
getselection notebook, nov, 1
Series_Start_Paragraph=V_startParagraph
Series_start_Pos=V_startPos
notebook nov selection={(Series_Start_Paragraph,0),(Series_Start_Paragraph,12)}
getselection notebook, nov, 2
String Sel_Val = S_Selection
if (stringmatch(S_Selection,"Series*"))
String expr="([[:alpha:]]+) ([[:digit:]]+): ([[:alpha:]]+)"
String Base, Num, wtvr
splitstring/E=(expr) Sel_Val,Base, Num, wtvr
endif
String Current_Series="Series "+Num

notebook nov selection={(Series_Start_Paragraph-1,0),(Series_Start_Paragraph,0)},Findtext={"Timer",1}
getselection notebook, nov, 1
notebook nov selection={(Series_Start_Paragraph,V_Startpos),(Series_Start_Paragraph+1,0)}
getselection notebook, nov, 2
String Latest_Sel=S_Selection[0,18]
print Latest_Sel

Variable Start_Format//=Series_Start_Paragraph+1
getselection notebook, nov, 2

notebook Data Selection={StartOfFile, StartOfFile}, Findtext={Latest_Sel,1}
//print s_selection
//abort
getselection notebook, Data, 1
//print V_startParagraph

notebook Data Selection={(V_startParagraph+1,0),EndOfFIle}
getselection notebook, Data, 2
String New_Tetx=S_Selection
Notebook Nov selection={endOfFile,endOfFile}, findText={"",1}
notebook Nov, text=S_Selection
Start_Format=Series_Start_Paragraph
Variable Start_Format_point,End_Format_point, flag
do
Notebook nov selection={(Start_Format,0),(Start_Format+1,0)}
Notebook nov Findtext={":",1}
flag=V_flag
if (flag)
	GetSelection Notebook, Nov, 1

 	Start_Format_point=V_StartPos+1

	Notebook nov selection={(Start_Format-1,0),(Start_Format,0)}
	Notebook nov Findtext={"Timer:",1}

	GetSelection Notebook, Nov, 1
 	End_Format_point=V_StartPos-1
	Notebook Nov Selection={(Start_Format,Start_Format_point),(Start_Format,End_Format_point)}
	Notebook Nov  fStyle=1
//	print Start_Format, Start_Format_point, End_Format_point
	else
		Notebook nov selection={(Start_Format-1,0),(Start_Format,0)}, FindText={":",1}
		if (V_Flag)
			GetSelection Notebook, Nov, 1
 			Start_Format_point=V_StartPos+1
			Notebook nov selection={(Start_Format-1,0),(Start_Format,0)}
			Notebook nov Findtext={"Timer:",1}
			GetSelection Notebook, Nov, 1
 			End_Format_point=V_StartPos-1
			Notebook Nov Selection={(Start_Format,Start_Format_point),(Start_Format,End_Format_point)}
			Notebook Nov  fStyle=1
		endif
endif
Start_Format+=1

while (Flag)
dowindow Data
if (V_flag==1)
killwindow Data
endif
end

Function SaveNote_Ori(CtrlName):ButtonControl //Obsolete
String CtrlNAme
Svar /z Save_NB
Pathinfo Save_Notebook
string Igor_Data= Stringbykey("OS",IgorInfo(3))
if (V_Flag==0)
	If (Stringmatch(Igor_Data,"*Mac*"))
		Newpath Save_Notebook, Save_NB
		print "Saving at: "+Save_NB
	else
		Newpath Save_Notebook, "C:\\Users\\dagostia\\desktop"
		print "Saving at: \\Users\\dagostia\\desktop"
	endif
endif
SaveNotebook /O /P=Save_Notebook /S=4 nov as "Data.rtf"
end

Function SaveNote(CtrlName):ButtonControl
	String CtrlNAme
	Svar /z Save_NB
	Pathinfo Save_Notebook
	if (V_Flag==0)	
		Newpath Save_Notebook, Save_NB	
	endif
	print "Saving at: "+Save_NB	
	SaveNotebook /O /P=Save_Notebook /S=4 nov as "Data.rtf"
end

function Get_image(Image_Struct) : Buttoncontrol
	Struct WmButtonAction &Image_Struct
pathinfo vid
Svar Image_Folder
variable i
if (V_flag==0)
	newpath vid Image_Folder
endif
if (Image_Struct.Eventcode!=2)
	abort
endif
playMovie /p=vid //as "C1.MP4"
playmovieaction frame=0
make/o/n=(640,480,3)  M_MovieFrame
make/o/n=(640,480) M_RGB2Gray
Make/o/n=(dimsize(M_RGB2Gray,0),dimsize(M_RGB2Gray,1),10) Temp_3D
for (i=0;i<10;i+=1)
	playmovieaction frame=i
	playmovieaction extract
	imagetransform rgb2gray m_movieframe
	Temp_3D[][][i]=M_RGB2Gray[p][q]
endfor
imagetransform averageImage Temp_3D
playmovieaction kill
wave M_StdvImage
Killwaves Temp_3D,M_MovieFrame,M_RGB2Gray,M_StdvImage
String List = wavelist ("Snap*",";","")
String Name="Snap_"+num2str(itemsinlist(list))
rename M_AveImage, $Name
end
