#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//List of procedures here:
//
// 1 - Segregate: egregates the different smiluation protocols in 100, 200 and 500 Hz
// 2 - AVG: averages all the PM* traces in the datafolder

Function Segregate() //segregates the different smiluation protocols in 100, 200 and 500 Hz folders



String Name=getdatafolder(1)


String Dest
String List=wavelist("*", ";","")
Variable i
Variable Min_Peak=-1e-9

Variable Point_1, Point_2
Variable Delta
For (i=0;i<itemsinlist(list);i+=1)
	findpeak /i /n /q  /M=(Min_Peak) $Stringfromlist(i,list)
	Point_1=v_PeakLoc
	findpeak /i /n /q  /M=(Min_Peak) /r=(Point_1+0.002,+inf) $Stringfromlist(i,list)
	Point_2=v_Peakloc
	Delta=Point_2-Point_1
	If (Delta>0.009 && Delta<0.011)
		Dest=Name+"F_100:"
		If (DataFolderExists("F_100")==0)
			Newdatafolder F_100
		Endif
		Movewave $Stringfromlist(i,list), $Dest
	Endif
	If (Delta>0.09 && Delta<0.11)
		Dest=Name+"F_10:"
		If (DataFolderExists("F_10")==0)
			Newdatafolder F_10
		Endif
	Movewave $Stringfromlist(i,list), $Dest
	Endif
	If (Delta>0.045 && Delta<0.055)
		Dest=Name+"F_20:"
		If (DataFolderExists("F_20")==0)
			Newdatafolder F_20
		Endif
		Movewave $Stringfromlist(i,list), $Dest
	Endif
	If (Delta>0.019 && Delta<0.022)
		Dest=Name+"F_50:"
		If (DataFolderExists("F_50")==0)
			Newdatafolder F_50
		Endif
		Movewave $Stringfromlist(i,list), $Dest
	Endif
//	If (Delta>0.0019 && Delta<0.003)
//		Dest=Name+"F_500:"
//		If (DataFolderExists("F_500")==0)
//			Newdatafolder F_500
//		Endif
//		Movewave $Stringfromlist(i,list), $Dest
//	Endif
//	If (Delta>0.004 && Delta<0.006)
//		Dest=Name+"F_200:"
//		If (DataFolderExists("F_200")==0)
//			Newdatafolder F_200
//		Endif
//		Movewave $Stringfromlist(i,list), $Dest
//	Endif
//	If (Delta<0.0011)
	//	Dest=Name+"F_1K:"
		//Movewave $Stringfromlist(i,list), $Dest
//	Endif

endfor

end



Function AVG_sims(Name)
String Name 
String list=wavelist("*"+Name+"*",";","")
Variable i
if (strlen(list)==0)
	Print "******************* No such waves in this DF *******************"
	abort
endif
duplicate /o $Stringfromlist(0,list), temp
for (i=1;i<itemsinlist(list);i+=1)
	wave temp2=$Stringfromlist(i,list)
	temp+=temp2
endfor
temp/=i
print i
duplicate/o temp, $Name+"_AVG"
killwaves /z temp, MAxes, Division_indexes
end

Function DFs()//creates Datafolders with different names to make my life easier

Variable i,Num_DFs=2 //amount of different datafolders to be created minus the control
String DFs_Names="F_100;F_200;F_500;"
for (i=0;i<num_dfs+1;i+=1)
	If (datafolderExists(Dfs_names[i])==0)
		NewDatafolder $Stringfromlist(i,Dfs_names)
	endif
endfor
end



Function Look_DFs() //go and  into each datafolder (one evel only) and perform the action in the "for" loop
String Comm="s"
String DF_List=Stringbykey("Folders",datafolderdir(1),":",";")
Variable i,j
String This_DF=getdatafolder(1)
DFREF This_DataF = GetDataFolderDFR()
String GO_To_DF
String list=wavelist("*",";","")
for (i=0;i<itemsinlist(list);i+=1)
	if (stringmatch(stringfromlist(i,list),"*pulse*")!=1 && stringmatch(stringfromlist(i,list),"P_*")!=1)
//		killwaves/z $Stringfromlist(i,list)
	endif
endfor
List ="Amplitudes;"//Raster_Wave;HW;:APs:ACT_Pot_0;"
//List ="Act_avg;"//Raster_Wave;HW;Amplitudes;Amplitudes_Raw;Threshold_wv;Mean_ap"

String Sublist
For (i=0;i<itemsinlist(List);i+=1)
	Sublist=wavelist(Stringfromlist(i,list)+"!P*",";","")
	for (j=0;j<itemsinlist(sublist);j+=1)
//		killwaves /z $Stringfromlist(j,sublist)
	endfor
endfor
For (i=0;i<itemsinlist(DF_List,",");i+=1)
GO_To_DF=This_DF+stringfromlist(i,DF_List,",")+":"

	Setdatafolder GO_To_DF
	Retrieve_from_DF(This_DataF,i,list)
	Setdatafolder This_DataF

endfor
//list=wavelist("Mid_AP_AVG_500_ctrl*",";","")
//align_aps(list,0)

for (i=0;i<itemsinlist(list);i+=1)
sublist=wavelist(stringfromlist(i,list)+"*",";","")
for (j=0;j<itemsInList(sublist);j+=1)
Averages(stringfromlist(i,list))
endfor
endfor
end






Function Retrieve_From_DF(Prev_DataF,index,list) //retrieves the waves designated in the LIST string to the main datafolder with numbers as suffixes
DFREF Prev_DataF
Variable index
String List 
//List =wavelist("P_2_9*",";","")//"Final_AVG;Initial_AVG;" //the waves you need right here!

Wave Amplitudes,Amplitudes_Norm,Threshold_Wv_eq,Delay
Variable i
String Name, Name2

//list=wavelist("Act_*",";","")

//Duplicate/o $Stringfromlist(0,list), Temp

For (i=0;i<itemsinlist(list);i+=1)
//if (stringmatch(comm,"kill")==1)
//	setdatafolder Prev_DataF
//	if (stringmatch(stringfromlist(i,list),"P*")==1)
//		killdatafolder Stringfromlist(i,list)
//	endif
//else
//wave temp2=$Stringfromlist(i,list)	
	Name=Stringfromlist(i,list)+"_"+num2str(index)
	if (stringmatch(Name,"*:*"))

		Name2=stringfromlist(2,name,":")
	//	rename $name, $Name2
		name=name2
		
	endif
	Duplicate/o $Stringfromlist(i,list), $name
//	temp+=temp2
	
	
//endif

//temp/=5

//Name="Mid_AP_AVG_500_ctrl"+num2str(index)

movewave $Name, Prev_DataF
//killwaves temp
endfor
end

Function P_Time()
string List=sortlist(wavelist("P_*",";",""),";",16)
String expr="([[:alpha:]]+):([[:digit:]]+):([[:digit:]]+):([[:digit:]]+)"
String Title, Hour, Minute, Second
String Path//=Getdatafolder(1)
Variable i, Sweep_Index
String DF_Name

for (i=0;i<itemsinlist(list);i+=1)
	Splitstring/E=(expr) stringfromlist(4,note($Stringfromlist(i,list))), Title, Hour, Minute, Second
	if (i==0)
		make/o/n=1 Timer_Sweeps=str2num(Minute)
	else
		insertpoints i,1,Timer_Sweeps
		Timer_Sweeps[i]=str2num(Minute)
	endif
endfor
DF_Name="S_"+num2str(Sweep_index)
Path=Getdatafolder(1)+DF_Name+":"
if (datafolderexists(DF_Name)==0)
		Newdatafolder $DF_Name
	endif
Sweep_index+=1
for (i=0;i<numpnts(Timer_Sweeps);i+=1)
	If (i>0 && Timer_Sweeps[i]<Timer_Sweeps[i-1])
		DF_Name="S_"+num2str(Sweep_index)
		if (datafolderexists(DF_Name)==0)
			Newdatafolder $DF_Name
		endif
		Path=Getdatafolder(1)+DF_Name+":"
		Sweep_index+=1	
	endif
	movewave $Stringfromlist(i,list),$Path	
endfor
end

Function Seg_SOM()
Variable i
String list=sortlist(wavelist("*",";",""),";",16)
if (datafolderexists("GF")==0)
	Newdatafolder GF
endif
if (datafolderExists("HFS")==0)
	Newdatafolder HFS
Endif
String Path
for (i=0;i<itemsinlist(list);i+=1)
	if (numpnts($Stringfromlist(i,list))>70000)
		Path=getdatafolder(1)+"Gf:"
		else
		Path=getdatafolder(1)+"HFS:"
	endif
		movewave $Stringfromlist(i,list),$Path
Endfor
end

Function Multiple_Display(Name)
String Name
String List=wavelist("*"+Name+"*",";","")
Variable i
display /k=1 $Stringfromlist(0,list)
for (i=1;i<itemsinlist(list);i+=1)
	Appendtograph $Stringfromlist(i,list)
Endfor
End

Function Loads()
//  /J=objectNamesStr	Loads only the objects named in the semicolon-separated list of object names.
loaddata /I /L=1 /R /T /j="Mid_AP_AVG;"//"Mid_AP_AVG_Stry_500;Mid_AP_AVG_Ctrl_500;Mid_AP_AVG_100_stry;Mid_AP_AVG_100_Ctrl;Mid_AP_AVG_500_Stry;Mid_AP_AVG_500_Ctrl;Mid_AP_AVG_stry_100;Mid_AP_AVG_Ctrl_100;"
end

•look_dfs()
•avgs("Threshold")
•avgs("Amplitudes")
•Avgs("Delay")
•avgs("Final")
•avgs("Initial")
avgs("HW")
•edit /k=1 Threshold_wv_eq_avg,Amplitudes_avg,Delay_avg, HW_Avg


Function/t align_APs(select)//(list, option)
variable select
string list=wavelist("*",";","win:")
variable option
variable i, P1,p2
P1=pcsr(a)
p2=pcsr(b)
String Name
duplicate /o $Stringfromlist(0,list), TEMP_Dif
duplicate /o $Stringfromlist(0,list), TEMP_Dif_dif

Make/o/n=(itemsinlist(list)) Maxes
for (i=0; i<itemsinlist(list);i+=1)
//Name="Temp_"+num2str(i)
//duplicate/o $Stringfromlist(i,list), $Name
wave temp=$Stringfromlist(i,list)
if (strlen(csrinfo(A))==0 || strlen(csrinfo(B))==0)
wavestats/q temp
else

wavestats/q /r=[pcsr(a),pcsr(b)] temp
endif
If (select)
Maxes[i]=V_Maxrowloc
else
Maxes[i]=V_Minrowloc//V_Maxrowloc
endif
switch (Select)
	Case 1:
	Maxes[i]=V_Maxrowloc
	break
	Case -1:
	Maxes[i]=V_Minrowloc
	break
	Case 0:
	Differentiate TEMP /D=Temp_DIF
	Differentiate TEMP_Dif /D=Temp_DIF_DIF
	//findlevel /P /Q Temp_Dif_DIF, -3e-6 
	//Maxes[i]=round(V_Levelx)
	wavestats /q Temp_DIF_DIF
		Maxes[i]=V_Maxrowloc//V_Minrowloc

	break
	Case 2:
		Differentiate TEMP /D=Temp_DIF
		findlevel /P  /r=[P1,P2] /Q Temp_DIF, -4e-7 
		Maxes[i]=round(V_Levelx)
	break
	Default:
		Print "Choose 1 for positive peak alignement, -1 for negative or 0 for dV/dt"
	abort
endswitch

endfor
if (option==1)
list= wavelist("Temp_*",";","")
endif

wavestats /q Maxes
variable Base_Deltax=deltax($Stringfromlist(V_MaxRowLoc,list))
Wave Base_Wv=$Stringfromlist(V_MaxRowLoc,list)
Variable This_Deltax
variable Max_Val=Wavemax(Maxes)
for (i=0; i<itemsinlist(list);i+=1)
This_Deltax=Deltax($Stringfromlist(i,list))
	if ((Base_Deltax/This_Deltax)!=1)


		resample /same=Base_Wv $Stringfromlist(i,list)

	endif
	if (strlen(csrinfo(A))==0 || strlen(csrinfo(B))==0)
	wavestats/q $Stringfromlist(i,list)
	else
	wavestats/q /r=[pcsr(a),pcsr(b)] $Stringfromlist(i,list)
	endif
	switch (select)
	Case 1:
	if (V_Maxrowloc<Max_Val)
			//deletepoints 0,V_Maxrowloc-Min_val,$Stringfromlist(i,list)
			
			insertpoints 0,abs(V_Maxrowloc-Max_val),$Stringfromlist(i,list)
			wave temp=$Stringfromlist(i,list)
			temp[0,abs(V_Maxrowloc-Max_val)]=nan
		//	print i, V_Maxrowloc-Max_val
		endif
	
	Break
	Case -1:
	

		if (V_minrowloc<Max_Val)
			//deletepoints 0,V_Maxrowloc-Min_val,$Stringfromlist(i,list)
			
			insertpoints 0,abs(V_minrowloc-Max_val),$Stringfromlist(i,list)
			wave temp=$Stringfromlist(i,list)
			temp[0,abs(V_minrowloc-Max_val)]=nan
		//	print i, V_Maxrowloc-Max_val
		endif
	Break
	Case 0:
	Differentiate $Stringfromlist(i,list) /D=Temp_DIF
		Differentiate TEMP_Dif /D=Temp_DIF_DIF
//	print i, V_Maxrowloc,Max_val
	wavestats /q temp_dif_DIf
	if (V_Maxrowloc<Max_Val)
			//deletepoints 0,V_Maxrowloc-Min_val,$Stringfromlist(i,list)
			
			insertpoints 0,abs(V_Maxrowloc-Max_val),$Stringfromlist(i,list)
			wave temp=$Stringfromlist(i,list)
			temp[0,abs(V_Maxrowloc-Max_val)]=nan
			print i, V_Maxrowloc-Max_val
		endif
	break
	Case 2:
		Differentiate $Stringfromlist(i,list) /D=Temp_DIF
		findlevel /P /r=[p1,p2]  /Q Temp_DIF, -4e-7 
		if (round(V_Levelx)<Max_Val)
			insertpoints 0,abs(round(V_Levelx)-Max_val),$Stringfromlist(i,list)
			wave temp=$Stringfromlist(i,list)
			temp[0,abs(round(V_Levelx)-Max_val)]=nan
		endif
	break
		if (V_minrowloc<Max_Val)
			insertpoints 0,abs(V_minrowloc-Max_val),$Stringfromlist(i,list)
			wave temp=$Stringfromlist(i,list)
			temp[0,abs(V_minrowloc-Max_val)]=nan
		endif
	break
	endswitch	
endfor
killwaves /z temp_dif
killwaves /z temp_dif_dif
if (option==1)
return list
endif
end

function move(num)
Variable num
String Base
String Name="P_"+num2str(num)
string list=wavelist("*"+Name+"*",";","")
if (strlen (list)==0)
	abort
endif
Variable i, index
Name="C"+Num2str(num)
if (datafolderexists(Name)==0)
	Newdatafolder $Name
endif
do
	if (Stringmatch(stringfromlist(i,note($Stringfromlist(0,list))),"PMStimulation*")==1)
		index=i
		break
	endif
	i+=1
while(1)
For (i=0;i<itemsinlist(list);i+=1)
	Base= replacestring(" ",Stringbykey("PMStimulationName",Stringfromlist(index,note($Stringfromlist(i,list)))),"_")+"_"
	base=replacestring ("-",base,"_")
	Name=":C"+Num2str(num)+":"+Stringfromlist(i,list)
	movewave $Stringfromlist(i,list), $replacestring("P_",Name,Base)
endfor
end

function main()
variable i=1
do
	move(i)
	i+=1
while(1)
end

Function VM()
getwindow kwTopWin	Wavelist
wave /t W_WaveList
String Name
variable i,j
for (j=0;j<dimsize(W_Wavelist,0);j+=1)
	wave temp=$W_Wavelist[j][1]
	do
		if (stringmatch(stringfromlist(i,note(temp)),"*V1*")==1)
			break
		endif
		i+=1
	while(1)
	Name=stringfromlist(i,note(temp))
	print "Holding potential for rec "+W_Wavelist[j][0]+": "+stringbykey("V1",Name)+" V"
	i=0
endfor
end


function New_IV(Type)
Variable type
Variable P1=0.345
Variable P2=0.35
if (strlen(csrInfo(A))==0 || Strlen(Csrinfo(B))==0)
		print "No cursors in the top Graph!!"
		abort
endif
IF (Type<1 || Type>2)
	Print "Choose 1 or 2 points and rerun."
	abort
	
endif
Make/n=1 IVVI
Switch (Type)
	Case 1:
		Exec_IV(xcsr(a),xcsr(b))
		Print "**************************"
		Print "X1: ",xcsr(a),"; X2: ",xcsr(b)
		Print "**************************"
	break
	Case 2:
		Exec_IV(xcsr(a),xcsr(b))
		Duplicate/o IVVI, VI_Ini
		Print "**************************"
		Print "X1: ",xcsr(a),"; X2: ",xcsr(b)
		Exec_IV(P1,P2)
		Duplicate /o IVVI, VI_Final
		Print "X1: ",P1,"; X2: ",P2
		Print "**************************"
		killwaves/z ivvi
	break
endswitch

end

function Exec_IV(P1, P2)
Variable P1, P2
String List=wavelist("*",";","Win:")
Variable i
make/o/n=(Itemsinlist(list)) IVVI
for (i=0;i<itemsinlist(list);i+=1)
	IVVI[i]=mean($StringfromList(i,list),P1,P2)
	//IVVI[i]=mean($StringfromList(i,list),xcsr(a),xcsr(b))
endfor
end

Function Jitters()
String Amp_List=wavelist("Amplitude*",";","")
String Delay_List=wavelist("Delay*",";","")
variable i
make /o/n=(50,itemsinlist(Amp_List)) Amp_Matrix, Del_Matrix
Make/o/n=50 Amp_Jitt, Del_Jitt
For (i=0;i<itemsinlist(Amp_List);i+=1)
	Wave Temp_Amp=$Stringfromlist(i,Amp_List)
	Amp_Matrix[][i]=temp_amp[p]
	
	
	Wave Temp_Delay=$Stringfromlist(i,Delay_List)
	Del_Matrix[][i]=Temp_Delay[p]
endfor
For (i=0;i<50;i+=1)
	matrixop /o Temp_Amp=row(Amp_Matrix,i)
	wavestats /q Temp_Amp
	Amp_Jitt[i]=V_Sdev
	matrixop /o Temp_Delay=row(Del_Matrix,i)
	wavestats /q Temp_Delay
	Del_Jitt[i]=V_Sdev
endfor
killwaves Temp_Amp,Temp_Delay,Amp_Matrix,Del_Matrix
end

function raster_offset()
string list=wavelist("*",";","Win:")
variable i,j
j=0.1
for (i=0;i<itemsinlist(list);i+=1)
	ModifyGraph offset($Stringfromlist(i,list))={0,j}
	j+=0.1
endfor
end

function sub()
make/o/n=(1,3) /t W_WaveList
getwindow kwTopWin wavelist
string list=""
variable i,j
for (i=0;i<dimsize(W_WaveList,0);i+=1)
	List=List+W_Wavelist[i][1]+";"
endfor
for (i=0;i<itemsinlist(list);i+=1)
	wave temp=$Stringfromlist(i,list)
	for (j=0;j<numpnts(temp);j+=1)
//		if (numtype(temp[j])==2)
	if (temp[j]==0)
			temp[j]=nan
		//	temp[j]=temp[j-1]
		endif
	endfor
Endfor
end

Function Display_All()
String list=wavelist("*",";","")
Variable i
Display /k=1 $Stringfromlist(0,list)
For(i=1;i<itemsinlist(list);i+=1)
	Appendtograph $Stringfromlist(i,list)
endfor
end


Function Trim()
String list=wavelist("*",";","Win:")
if (Strlen(list)==0)
	Abort
endif
String Info=Csrinfo(a)
if (strlen(info)==0)
	Print "No Cursor A in target Graph"
	Abort
endif
Info=Csrinfo(b)
if (strlen(info)==0)
	Print "No Cursor B in target Graph"
	Abort
endif	
variable i
Variable P1=Pcsr(A)
Variable P2=Pcsr(B)
for (i=0;i<itemsinlist(list);i+=1)
Wave temp=$stringfromlist(i,list)
If (P1>P2)
	Deletepoints P1,numpnts(temp)-P1-1,Temp
	Deletepoints 0,P2,temp
	else
	Deletepoints P2,numpnts(temp)-P2-1,Temp
	Deletepoints 0,P1,temp
endif
DeletePoints numpnts(temp)-1,1, temp
endfor
end

Function Kill_COnd()

String List=wavelist("*",";","")//("!Artif*",";","WIN:")
wave Cd_artif
variable i,j
//Make/O/D/N=0 coefs
for (i=0;i<itemsInList(list);i+=1)
	wave temp=$Stringfromlist(i,list)
//temp-=cd_artif
//If (wavemin(temp,xcsr(a),xcsr(b))>-0.5e-9)
if (wavemax(temp)<-20e-3)
//movewave temp, :APs:
//j+=1
killwaves temp
//removefromgraph $Stringfromlist(i,list)
	endif
 	//FilterFIR/DIM=0/LO={0,0.1,101}/COEF coefs, temp
//setscale /p x,0,0.00004096,"s",temp
//resample /up=5 temp
endfor
end

Function Back()
string list=wavelist("*",";","Win:")
variable i,j
for (i=0;i<itemsinlist(list);i+=1)
	wave temp=$Stringfromlist(i,list)
	do
	j+=1
	while(numtype(temp[j])==2)
deletepoints 0,j,temp
j=0
endfor
end

function get_param() // retrieves some parameters based on the wave's note
String list=wavelist("P*",";","")
String parameter="Sweep Time"
//Parameter="PMSweepTime"
variable i
wave temp=$StringfromList(0,list)
//print stringbykey(parameter,note(temp))
String Temp_String=stringbykey(parameter,note(temp),":",";\r")
Variable Str_offset=16+1
Variable This_Hour=str2num(Temp_String[Str_offset,Str_offset+1])
Str_offset+=3
Variable This_Min=str2num(Temp_String[Str_offset,Str_offset+1])
Str_offset+=3
Variable This_Sec=str2num(Temp_String[Str_offset,Str_offset+1])
print This_Hour,strlen(Temp_String), Temp_String
Variable Zero_time_Secs=This_Hour*60*60+This_Min*60+This_Sec
Make/o/n=(itemsInList(list)) Stim_Time
	Str_offset-=6

for (i=1;i<itemsInList(list);i+=1)
	wave temp=$StringfromList(i,list)
	Temp_String=stringbykey(parameter,note(temp),":",";\r")
	This_Hour=str2num(Temp_String[Str_offset,Str_offset+1])
	Str_offset+=3
	This_Min=str2num(Temp_String[Str_offset,Str_offset+1])
	Str_offset+=3
	This_Sec=str2num(Temp_String[Str_offset,Str_offset+1])
	Str_offset-=6
	Stim_time[i]=This_Hour*60*60+This_Min*60+This_Sec-Zero_time_secs
endfor
end

Function Set_C() // sets cursosrs for HFS analysis
//SetAxis bottom 0.098,0.103
//SetAxis bottom 0.098,0.103


//SetAxis bottom 0.0296,0.034
SetAxis bottom 0.0211,0.0225

String Wv=wavelist("*",";","Win:")
//wave temp=$Stringfromlist(0,Wv)
cursor /A=1 A $Stringfromlist(0,Wv) 0.0218
cursor /A=1 B $Stringfromlist(0,Wv) 0.0223
end

function ar() // retrieves the area under curve for short HFS - used in Geroge's experiments
wave avg_artif
wave temp=avg_artif
variable i
make/o/n=10 areas, Baseline_area
for (i=0;i<10;i+=1)
	areas[i]=area (temp,0.1+0.02*i,0.12+0.02*i)
	Baseline_area[i]=(temp(0.1+0.02*i))*0.02
endfor
areas-=baseline_area
end


function IDF() //"�nvade datafolders" - accesses DFs (one level only)  and execute the desired command(s)
Variable DF_Num=countobjects("",4)
variable i
wave P_avg, PMPulse_avg,a_amplitude0, amp_norm
for (i=0;i<DF_Num;i+=1)

	Setdatafolder getindexedObjName("",4,i)
//		avg_sims("P")
//	execute"resample /up=10 P_avg"

//		showinfo
//execute "Edit /k=1 Amplitudes, Amplitudes_norm"
//	segregate()
//display_all()
//sleep /s 1
//look_dfs()
avg_sims("P")

		execute "display /k=1 P_avg"; showinfo
//look_dfs()
//set(); display_all(); Showinfo


//execute "Duplicate /o a_amplitude0, Amp_norm"
//execute "Amp_norm/=a_amplitude0[0]"
	setdatafolder ::
	
endfor

end

function sggt()
String Name=getdatafolder(1)
String list=wavelist("*",";","")
variable i, Pos, Freq
String Temp_S,Dest
for (i=0;i<itemsinlist(list);i+=1)
	Wave temp=$Stringfromlist(i,list)
	Pos=strsearch(note(temp),"Channel",0)
	Temp_S=note(temp)[Pos+10,inf]
	Pos=Strsearch(Temp_S,"Channel",0)
	Temp_S=Temp_S[Pos,Pos+500]
	//print temp_s
//abort
	Freq=Delta(Temp_S)	
	If (Freq==100)
		Dest=Name+"F_100:"
		If (DataFolderExists("F_100")==0)
			Newdatafolder F_100
		Endif
		Movewave $Stringfromlist(i,list), $Dest
	Endif
	If (Freq==200)
		Dest=Name+"F_200:"
		If (DataFolderExists("F_200")==0)
			Newdatafolder F_200
		Endif
	Movewave $Stringfromlist(i,list), $Dest
	Endif
	If (Freq==500)
		Dest=Name+"F_500:"
		If (DataFolderExists("F_500")==0)
			Newdatafolder F_500
		Endif
	Movewave $Stringfromlist(i,list), $Dest
	Endif

	
endfor
end

function delta(Temp_S)
String Temp_S
if (strsearch (Temp_S,"9.90 ms",0)!=-1)
	return 100
endif
if (strsearch (Temp_S,"4.90 ms",0)!=-1)
	return 200
endif
if (strsearch (Temp_S,"1.90 ms",0)!=-1)
	return 500
endif

end

