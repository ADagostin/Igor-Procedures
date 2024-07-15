#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//List of procedures here:
//
// 1 - Segregate: egregates the different smiluation protocols in 100, 200 and 500 Hz
// 2 - AVG: averages all the PM* traces in the datafolder

 //segregates the different smiluation protocols in 100, 200 and 500 Hz folders
//OBS: it's very unlikelly it'll work with someone else's recordings though. use at your own risk 
function segregate()
String Name=getdatafolder(1)
String list=wavelist("*",";","")
variable i, Pos, Freq
String Temp_S,Dest, check	
for (i=0;i<itemsinlist(list);i+=1)
	Wave temp=$Stringfromlist(i,list)
	
	check = note(temp)
	if (stringmatch(Check[0,7],"Filename")==0) // used without "pretty print"
		Freq=Delta(check)
	else
		Pos=strsearch(note(temp),"Channel",0) // used with "pretty print"
		Temp_S=note(temp)[Pos+10,inf]
		Pos=Strsearch(Temp_S,"Channel",0)
		Temp_S=Temp_S[Pos,Pos+500]
		Freq=Delta(Temp_S)	
	endif
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

static function delta(Temp_S)
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
if (strsearch (Temp_S,"0.0099",0)!=-1)
	return 100
endif
if (strsearch (Temp_S,"0.0049",0)!=-1)
	return 200
endif
if (strsearch (Temp_S,"0.0019",0)!=-1)
	return 500
endif


end


//performs a simple averaging of a wavelist containig the wildcard string with the function
Function AVG_sims(Name)
String Name 
String list=wavelist("*"+Name+"*",";","")
if (strlen(list)==0)
	Print "******************* No such waves in this DF *******************"
	abort
endif
variable i, pnts
pnts=numpnts($StringfromList(0,list))
for (i=1;i<itemsInList(list);i+=1)
	if (pnts!=numpnts($StringfromList(i,list)))
		print "****** Number of points for the waves are different - aborting ******"
		abort
	endif
endfor
concatenate /o /np=1 list, Matrix
matrixop /o temp=sumrows(Matrix)
temp/=itemsinlist(list)
setscale /p x,0,deltax($Stringfromlist(0,list)),"s",temp
duplicate/o temp, $Name+"_AVG"
killwaves /z temp, Matrix
end

//adds Nan to the end of a group of waves to make them the same size
//note: i'd rather add points than to subtract them to avoid losing any significant datapoint
Function Same_num_pnts(name)
String Name 
String list=wavelist("*"+Name+"*",";","")
if (strlen(list)==0)
	Print "******************* No such waves in this DF *******************"
	abort
endif
variable i, total
make/n=(itemsInList(list)) Wave_Num_Pnts
for (i=0;i<itemsInList(list);i+=1)
	Wave_Num_Pnts[i]=numpnts($Stringfromlist(i,list))
endfor
for (i=0;i<itemsInList(list);i+=1)
	wave temp=$Stringfromlist(i,list)
	if (numpnts(temp)!=wavemax(Wave_Num_Pnts))
		insertpoints /v=(nan) numpnts(temp), wavemax(Wave_Num_Pnts)-numpnts(temp), temp
		total+=1
	endif
	
endfor
print "****** ",total,"waves modified ******"
killwaves /z Wave_Num_Pnts
end


//change active datafolder (one evel only) and retrieves listed waves into the original datafolder
//while averaging them 
Function Look_DFs() 
String Comm="s"
String DF_List=Stringbykey("Folders",datafolderdir(1),":",";")
Variable i,j
String This_DF=getdatafolder(1)
string This_DataF = GetDataFolder(1)
String GO_To_DF, Sublist
String list=wavelist("*",";","")

List ="raster_wave;mean_ap;"//:APs:ACT_Pot_0;" //your waves here!

For (i=0;i<itemsinlist(DF_List,",");i+=1)
	GO_To_DF=This_DF+stringfromlist(i,DF_List,",")+":"
	Setdatafolder GO_To_DF
	doupdate
	Retrieve_from_DF(This_DataF,i,list)
	Setdatafolder This_DataF
endfor

for (i=0;i<itemsinlist(list);i+=1)
	sublist=wavelist(stringfromlist(i,list)+"*",";","")
	for (j=0;j<itemsInList(sublist);j+=1)
		Averages(stringfromlist(i,list))
	endfor
endfor
return 0
end


//retrieves the waves designated in the LIST string to the main datafolder with numbers as suffixes
Function Retrieve_From_DF(Prev_DataF,index,list) 
string Prev_DataF
Variable index
String List
String Name, Name2, destination
Variable i 
For (i=0;i<itemsinlist(list);i+=1)
	Name=Stringfromlist(i,list)+"_"+num2str(index)
	if (stringmatch(Name,"*:*"))
		Name2=stringfromlist(2,name,":")
		name=name2		
	endif
	Duplicate/o $Stringfromlist(i,list) $name
	destination=Prev_DataF+name
	movewave $Name, $destination
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
			wavestats /q /r=[p1,p2] Temp_DIF_DIF
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
				insertpoints 0,abs(V_minrowloc-Max_val),$Stringfromlist(i,list)
				wave temp=$Stringfromlist(i,list)
				temp[0,abs(V_minrowloc-Max_val)]=nan
			endif
		Break
		Case 0:
			Differentiate $Stringfromlist(i,list) /D=Temp_DIF
			Differentiate TEMP_Dif /D=Temp_DIF_DIF
			wavestats /q /r=[p1,p2] temp_dif_DIf
			if (V_Maxrowloc<Max_Val)
				insertpoints 0,abs(V_Maxrowloc-Max_val),$Stringfromlist(i,list)
				wave temp=$Stringfromlist(i,list)
				temp[0,abs(V_Maxrowloc-Max_val)]=nan
			print i, V_Maxrowloc-Max_val
			endif
		break
	Case 2:
		print i
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
Variable P1=0.245
Variable P2=0.25
if (strlen(csrInfo(A))==0 || Strlen(Csrinfo(B))==0)
		print "No cursors in the top Graph!!"
		abort
endif

IF (Type<1 || Type>2)
	Print "Choose 1 or 2 points and rerun."
	abort
	
endif
Make/n=1 /o IVVI
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
String List=sortlist(wavelist("!fit*",";","Win:"),";",16)
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
//j=0.1
for (i=0;i<itemsinlist(list);i+=1)
	ModifyGraph offset($Stringfromlist(i,list))={0,j}
	j+=400//e-12
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
		if (numtype(temp[j])==2)
	//if (j>pcsr(a) && J<Pcsr(b))
		//	temp[j]=nan
			temp[j]=temp[j-1]
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


function Get_item(item_num) //bpc_Read_HEKA
variable item_num
string list=wavelist("*",";","win:")
variable i
String item, accessory
make/o/n=(itemsinlist(list)) output
switch (item_num)
	Case 0:
		item+="Sweep Time"
	break
	Case 1:
		item="Timer"
		accessory=""
		for (i=0;i<numpnts(output);i+=1)
			wave temp=$Stringfromlist(i,list)
			output[i]= return_secs(temp,i)
		endfor
	break
	Case 2:
		item="Group"
	break
	Case 3:
		item="Series"
	break
	Case 4:
		item="Sweep"
	break
	Case 5:
		item="Trace"
	break
	Case 6:
		item="CSlow"
	break
	Case 7:
		item="RSeries"
		accessory="MOhm"
	break
	Case 8:
		item="RSValue"
	break
	Case 9:
		item="rsFraction"
	break
endswitch
print "Item =", item

end

Function return_secs(temp,i)

	wave temp
	variable i
	string list=wavelist("P_*",";","win:")
	string test
	variable minute, second, output
	test = stringbykey("\rtimer",note(temp))
	test = test[0,strlen(test)-5]
	minute = str2num(test[4,5])
	second=str2num(test[7,8])
	output=minute*60+second
	return output

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


function IDF() //"•nvade datafolders" - accesses DFs (one level only)  and execute the desired command(s)
String prot
Variable DF_Num=countobjects("",4)
variable i
String name, DFs
Dfs=""
setdatafolder root:
wave P_avg, PMPulse_avg,a_amplitude, a_risetime, amp_norm, output
for (i=0;i<DF_Num;i+=1)
//strswitch (prot)
//	Case "look_dfs":
		DFs=getindexedObjName("",4,i)
		print DFs
//	break
//	default:
if (stringmatch(DFs,"A*")!=1 && stringmatch(DFs,"P*")!=1)
	Setdatafolder getindexedObjName("",4,i)
//	zap()
//	look_dfs()
//Setdatafolder Minis

	//segregate()
	//	execute"resample /up=10 P_avg"
	//		showinfo
	//execute "Edit /k=1 Amplitudes, Amplitudes_norm"
	//	segregate()
	//name="amp_"+num2str(i)
//execute "duplicate /o a_amplitude , "+name
//movewave $name, root:
//name="rise_"+num2str(i)

//execute "duplicate /o a_risetime, "+Name
//movewave $name, root:

//	display_all(); showInfo
	//sleep /s 1
	//execute "display /k=1 P_avg"; showinfo
	//set(); display_all(); Showinfo
	//execute "Duplicate /o a_amplitude0, Amp_norm"
	//execute "Amp_norm/=a_amplitude0[0]"
	setdatafolder ::
	setdatafolder ::
endif
//endswitch
endfor
end
//returns the suffix of the patchmaster waves - used to differentiate between PPT and BPC
//loading XOPs
Static Function /t Which_XOP()
	string list=wavelist("*",";","")
	variable i
	for (i=0;i<itemsInList(list);i+=1)
		if (stringmatch(stringfromList(i,list),"*mon*"))
			return "mon"
		else
			return ""
		endif
	endfor
end


//Calculatest the FFT from input (current) and output (voltage)
//after averaging the chirp waves. It calculates the impedance by dividing V_FFT/I_FFT and 
//outputs a wave ("final") which is the whole FFT spectrum of the waves.

Function ZAP()
	
	wave V_AVG, I_AVG
	avg_sims("V"+Which_XOP())
	avg_sims("I"+Which_XOP())
	if (strlen(Which_XOP())==0)
		ZAP_Cont(1)
	else
		ZAP_Cont(0)
	endif
end

Static Function ZAP_cont(Val)
	Variable val
	if (val)
		wave I_AVG, V_AVG
		Duplicate/o I_AVG, Imon_AVG
		Duplicate/o V_AVG, Vmon_AVG
		killwaves /z I_AVG, V_AVG
	endif
	Print "********************   Start calculating ZAP wave, please wait.   ********************"
	variable i
	Variable Freq_ini=1 //defines the final FFT piece to be used
	Variable Freq_final=500 //defines the final FFT piece to be used
	Print "Averages calculated..."
	FFT/OUT=1/DEST=Imon_FFT Imon_AVG
	FFT/OUT=1/DEST=Vmon_FFT vmon_AVG
	Print "FFTs calculated..."
	make/o /n=(numpnts(Imon_FFT)) Imped_real
	make/o /n=(numpnts(Imon_FFT)) Imped_Img
	duplicate/o /c Imon_FFT, Imped
	Imped=Vmon_FFT/Imped
	imped_real=Imped[p]
	imped_img=imag(imped)
	make/o/n=(numpnts(Imped_Real)) Final
	Final = sqrt(Imped_Real^2+Imped_Img^2)
	setscale /p x,0,deltax(Imon_FFT),"Hz",Final
	deletepoints x2pnt(final,Freq_final), numpnts(final)-x2pnt(final,Freq_final), final
	deletepoints 0,x2pnt(final, Freq_ini),final
	setscale /p x,Freq_ini,deltax(Imon_FFT),"Hz",Final
	if (strlen(functioninfo("PPTDoKillMultipleWaves")))
	PPTDoKillMultipleWaves ("_I", 1); Doupdate
	PPTDoKillMultipleWaves ("_V", 1); Doupdate
	endif
	Duplicate/O Final, filtered
	Make/O/D/N=0 coefs
	FilterFIR/DIM=0/LO={0,0.0166611,101}/COEF coefs, filtered
	//make/o/n=300 temp
	resample /down=10 filtered
	//resample /same=temp filtered
	killwaves /z Imped, Imon_FFT, Vmon_FFT, coefs, Imped_real, Imped_img//, temp
	for (i=0;i<3;i+=1)
		Doupdate
		beep
		sleep /s 0.3
	endfor
	Print "***********************Success calculating ZAP wave.***********************"
end
//Seg_Ch: Segregates the ZAP waves with their respecive current command input
function seg_ch()
	newdatafolder /o Amp_100
	newdatafolder /o Amp_50
	string name, Volt, Curr
	variable i, delta
	string list=wavelist("*",";","")
	if (stringmatch(stringfromList(0,list),"*mon*")) 									// checks whether the waves are named after the PPT or BPC loading XOPs
		Volt="Vmon"
		Curr="Imon"
	else
		Volt="V"
		Curr="I"
	endif
		for (i=0;i<itemsinlist(list);i+=1)
		if (stringmatch(stringfromlist(i,list),"*"+Curr+"*")) 						//is it an I_mon wave?
			wavestats /q $stringfromlist(i,list) 										//the amplitude of the chirp wave is calculated
			name =replacestring("2_"+Curr,stringfromlist(i,list),"1_"+Volt) 		//gets the corresponding V_mon wave name
			wave temp=$stringfromlist(whichlistitem(name,list),list)				//defines "temp" as the V_mon wave - just to make my life easier
			delta=v_max-v_min 																	//the amplitude of the chirp wave
			if (delta>105e-12) 																//sets the datafolder that will host the wave pair depending on the stimulus amplitude
				movewave $stringfromlist(i,list), :Amp_100:
				movewave temp, :Amp_100:
				else
				movewave $stringfromlist(i,list), :Amp_50:
				movewave temp, :Amp_50:
			endif
	endif
endfor
//futher segregation in different holding (-80, -70, -60 and -50 mV)
//setdatafolder Amp_100
//seg_chirp(Volt, Curr)
//setdatafolder ::
//setdatafolder Amp_50
//seg_chirp(Volt,Curr)
//setdatafolder ::
end

 function seg_chirp(Volt,Curr)
	String VOlt, Curr
	newdatafolder /o CC_80
	newdatafolder /o CC_70
	newdatafolder /o CC_60
	newdatafolder /o CC_50
	String list=wavelist("*"+Volt+"*",";","")
	String sublist=wavelist("*"+Curr+"*",";","")
	variable i
	String DF_names=":CC_50:;:CC_60:;:CC_70:;:CC_80:;" 		//the datafolder name list that will host the waves
	for (i=0;i<itemsinlist(list);i+=1)
		wave temp=$Stringfromlist(i,list) 						//the current V_mon wave in the lsit
		wave temp_i=$Stringfromlist(i,sublist) 					//the current I_mon wave in the list
		variable avg=round(mean(temp,0,0.01)  *-1e2-5) 		// genius here: avg is the average from 0 to 10 mV of the V_mon wave. It is multiplied by -100, subtracted 5 and roundes, 
																			//	resulting in integers from 0 to 3, which will be used as indexes for the DF_names list.
		movewave temp, $stringfromlist(avg, DF_names)
		movewave temp_i, $stringfromlist(avg, DF_names)
	endfor
end
//--------
//Performs a sliding average with a bin size defined by the user.
//If needed, cursors (A to F) can be placed on a displayed target wave to define specific portions of the 
//wave to be computed independently.
Function Sl_AVG(bin, Original)
Variable bin
Wave Original
variable i,j,k

duplicate/o Original, SLD_AVG
//wave Original=LMAN
String Cursors=""
MAKE/O/N=1 Cursor_Pos=numpnts(Original)-1
if (strlen(CsrInfo(A))>0)
	Cursors+="A;"
	insertpoints /V=(pcsr(A)) 0,1,Cursor_Pos 
endif
if (strlen(CsrInfo(B))>0)
	Cursors+="B;"
	insertpoints /V=(pcsr(B)) 1,1,Cursor_Pos
endif
if (strlen(CsrInfo(C))>0)
	Cursors+="C;"
	insertpoints /V=(pcsr(C)) 2,1,Cursor_Pos
endif
if (strlen(CsrInfo(D))>0)
	Cursors+="D;"
	insertpoints /V=(pcsr(D)) 3,1,Cursor_Pos
endif
if (strlen(CsrInfo(E))>0)
	Cursors+="E;"
	insertpoints /V=(pcsr(E)) 4,1,Cursor_Pos
endif
if (strlen(CsrInfo(F))>0)
	Cursors+="F;"
	insertpoints /V=(pcsr(F)) 5,1,Cursor_Pos
endif
if (strlen(CsrInfo(G))>0)
	Cursors+="G;"
	insertpoints /V=(pcsr(G)) 6,1,Cursor_Pos
endif
if (strlen(CsrInfo(H))>0)
	Cursors+="H;"
	insertpoints /V=(pcsr(H)) 7,1,Cursor_Pos
endif
insertpoints 0,1,Cursor_Pos
if (strlen(Cursors)==0)
	For (i=0;i<numpnts(SLD_AVG);i+=1)
		if (i>=numpnts(SLD_AVG)-1-bin)
			SLD_AVG[i]=mean(original,i,numpnts(SLD_AVG)-1-i)
		else
			SLD_AVG[i]=mean(original,i,i+bin-1)
		endif
	endfor
else
	For (i=0;i<=itemsInList(Cursors);i+=1)	
		For (j=Cursor_Pos[i];j<=Cursor_Pos[i+1];j+=1)
			if (j==Cursor_Pos[i] && j>0)
				j+=1
			endif	
			if (j>Cursor_Pos[i+1]-bin)
				//SLD_AVG[j]=mean(original,j,Cursor_Pos[i+1])
				duplicate /o /r=[j,Cursor_Pos[i+1]] original, temp
				insertpoints bin, bin-1, temp
				temp[bin,2*bin-2]=temp[2*bin-2-p]
				setscale /p x,0,1,"",temp
				for (k=0;k<bin;k+=1)
					SLD_AVG[j+k]=mean(temp,k,k+bin-1)	
				endfor		
		
				break
			else
				SLD_AVG[j]=mean(original,j,j+bin-1)
			endif			
		endfor	
	
	Endfor
endif
note SLD_AVG, "Sliding average bin = "+num2str(bin) 
string test=""
if (strlen(Cursors)>0)
	note SLD_AVG, num2str(itemsinlist(Cursors))+" cursors were positioned: "+removeending(Cursors)
	for(i=1;i<numpnts(Cursor_Pos);i+=1)
		test+=num2str(Cursor_Pos[i])+", "
	endfor
	note SLD_AVG, "Cursors defined points: "+removeending (test,", ")
endif
note SLD_AVG, "Right limits calculated using \"mirroring\" approach."
killwaves /z temp, Cursor_pos
end
