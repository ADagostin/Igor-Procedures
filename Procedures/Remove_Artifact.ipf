#pragma rtGlobals=3		// Use modern global access method and strict wave access.
// Removes the artifacts
// Place the cursosr A and B delimiting the artifact
// Prompt will ask for the graph name to be processed and also the stimulation frequency 
// Outputs as Wave_Artif
function Tira()
String Graph,List_fit,fit_Item,Base_Name
Make/o/n=10/T Data_Title={"PPR","TAU 1","TAU 2","TAU 3","TAU 4","TAU 5", "Decay% ","RRP","TAU Decay","X?"}
Make/o/n=10 Data
variable i, Delta,Freq,Add,peak,Start, i_fit
variable/g index_fit
prompt Graph, "Graph"
Prompt Base_Name, "Wave Base Name"
freq=300
prompt Freq, "Stimulus Frequency"
doprompt "Graph and Frequency",Graph,Freq,Base_Name
String / G Base_Name_Global = Base_Name
String Wv = stringfromlist(0,wavelist ("*",";","Win:"+Graph))
String Out = Wv+"_Artif"
Svar  fit_Name_list
duplicate/o $Wv, Temp
index_fit=0
string Cursor_Info = CsrInfo(A,Graph)
if (strlen (stringfromlist(1,Cursor_Info))<4)
	Print "No cursor A in ",Graph
	abort
endif
variable Size =abs( Pcsr(a)-Pcsr(b))
Delta=Deltax(Temp)
Start=Pcsr(a)
Add=ceil(1/freq/delta)
if (freq==300)
	Add=343
endif
wavestats/q /r=[start,start+Size] Temp
peak=V_Max-V_min
Make/o/n=1 Amplitudes=0
Make/o/n=1 Time_Peaks=0

Bsln(Graph,Freq)

Wave Time_tofit
Wave fit_To_fit
setscale /p x,Time_tofit[0],1e-5,"s",fit_To_fit //This command is related to the "Bsln" Procedure, it is here to  prevente an error back in the code
Make/o/n=1 Amp_Adj=0
do
	wavestats/q /r=[start,start+Size] Temp
	if (V_max-V_min<peak-(peak/2))
		break
	endif
	Amp(Start,Add,Size)
	Data[0]=Amplitudes[1]/Amplitudes[0]
	for (i=0;i<=Size;i+=1)		
		Temp[Start+i]=NaN	
	endfor
	Start=Start+Add
	IF (start>numpnts(temp))
		break
	endif
while(1)
duplicate/o Temp, $Out
Display/n=Decay /k=1 $Out
duplicate/o Amplitudes, Amp_Ori
//Wave Amp_Adj
//Amplitudes=Amp_Adj
for (i=0;i<itemsinlist(fit_Name_list);i+=1)
	Appendtograph $stringfromlist(i,fit_Name_list)
endfor
List_fit=wavelist("fit*",";","Win:")
do
	fit_item=stringfromlist(i_fit,List_fit)
	if (strlen(fit_item)==0)
		break
	endif
	execute "ModifyGraph rgb("+fit_Item+")=(0,0,0)"
	i_fit+=1
while(1)
if (Freq==300)
	RRP()
endif

edit/k=1 /n=Table_Res Data_Title, Data
variable Normalizer=Amplitudes[0]
Make/n=(numpnts(Amplitudes)) Amp_Norm=Amplitudes/Normalizer
display/n=Normalized /k=1 Amp_Norm vs Time_Peaks
ModifyGraph mode=3,marker=8,msize=3,rgb=(0,0,0)
RenKill()

end
//*******************************************************************************************88
//Returns waves containig current amplitudes (Amplitudes) and its peak in time (Time_Peaks)
//these are totally related to function "Tira"
Function Amp(Start,Add,Size)
Variable Start,Add,Size //Start: the initial point before the artifact; Size: the "length" of the artifact; Add: the gap between two artifacts
Variable Amp10_90_UP,Amp10_90_DOWN
Wave Amplitudes
Wave Temp
Wave fit_temp
Wave Time_Peaks
Wave W_Coef
Wave fit_To_fit //used to adjust the baseline
Wave Amp_adj
Wave fit_To_fit
Nvar Index_fit
String Fit_Name
String/g fit_Name_list
Variable Difference_Adjustment
Start=Start+Size
wavestats/q /r=[Start,Start+add-Size] Temp
Amp10_90_UP=temp[V_minrowloc]-(temp[V_minrowloc]-temp[Start+add-Size])/10
Amp10_90_DOWN=temp[Start+add-Size]+(temp[V_minrowloc]-temp[Start+add-Size])/10
if (Amplitudes[0]==0)
	Amplitudes[0]=V_min
	Time_Peaks[0]=V_minloc
	Difference_Adjustment=fit_To_fit(V_minloc)-Temp[Start]
	fit_To_fit=fit_To_fit-Difference_Adjustment
	Amp_adj[0]=Amplitudes[0]-fit_To_fit[0]
	 // The difference fit_To_fit(V_minloc)-Temp[Start] should give the artifact amplitude
//	print difference_adjustment
	
	else
	insertpoints (numpnts(Amplitudes)),1,Amplitudes
	insertpoints (numpnts(Time_Peaks)),1,Time_Peaks
	insertpoints (numpnts(Amp_Adj)),1,Amp_Adj
	Amplitudes[numpnts(Amplitudes)-1]=V_min
	Time_Peaks[numpnts(Time_Peaks)-1]=V_minloc	
	Amp_adj[numpnts(Amp_Adj)-1]=Amplitudes[numpnts(Amp_Adj)-1]-fit_To_fit(V_minloc) //insert correction here!!!!!! THIS IS WRONG!!!
endif
if (index_fit < 5)
		
		findlevel/q /EDGE=1 /P /R=[V_minrowloc,Start+add-Size] Temp, AMP10_90_UP
		Amp10_90_UP=V_levelx
		findlevel/q /EDGE=1 /P /R=[V_minrowloc,Start+add-Size] Temp, AMP10_90_DOWN
		Amp10_90_DOWN=V_levelx
		CurveFit/q/NTHR=0 exp_XOffset  Temp[Amp10_90_UP,Amp10_90_DOWN] /D 
		if (index_fit==0)
			Make/o/n=1 TAUs=W_Coef[2]
		else
			insertpoints index_fit,1,TAUs
			TAUs[index_fit]=W_Coef[2]
		endif
		
		fit_Name= "fit_"+num2str(index_fit)
		if (waveexists($fit_name)==1)
			duplicate/o fit_Temp, $fit_Name
		else
			wtf(fit_Name) //Used only to prevent an error from the Rename function hosted at the WTF function
		endif
		if (index_fit == 0)
			fit_Name_list = fit_name
		else
			fit_Name_list= fit_Name_list+";"+fit_name
		endif
		index_fit+=1
	endif

end
//***********************************************************************************************
 //Used only to prevent an error from the Rename function hosted at the WTF function
function WTF(fit_Name)
String fit_Name
Wave fit_Temp
rename fit_Temp, $fit_Name
end

//***********************************************************************************************
Function RRP()
Wave Amplitudes
Wave Time_Peaks
Wave fit_Amplitudes
Wave fit_exp_Amplitudes
Wave Temp
Wave W_Coef
Wave Data
Duplicate/o Time_Peaks, Time_Peaks_Zero
Variable Offset=Time_Peaks_Zero[0]
wavestats/q Amplitudes
Appendtograph Amplitudes vs Time_Peaks
CurveFit/NTHR=0 exp_XOffset Amplitudes[V_minRowLoc,numpnts(amplitudes)-1] /x=Time_Peaks /D
execute "duplicate/o fit_amplitudes, fit_exp_Amplitudes"
execute "Appendtograph fit_exp_Amplitudes"
execute "removefromgraph/z fit_Amplitudes"
Data[8]=W_Coef[2]
execute "Killwaves/z fit_Amplitudes"
ModifyGraph lstyle(fit_exp_Amplitudes)=3,rgb(fit_exp_Amplitudes)=(0,0,0)
ModifyGraph mode(Amplitudes)=3, marker(Amplitudes)=8,msize(Amplitudes)=2,rgb(Amplitudes)=(0,0,65280)
variable i
make/o/n=1 Result=Amplitudes[0]
for (i=0;i<numpnts(Amplitudes);i+=1)
	if (i>0)
		insertpoints i,1,Result
		result[i]=result[i-1]+Amplitudes[i]
	endif
endfor
Result=result*(-1)
Display/n=R_R_P /k=1 Result
CurveFit/X=1/NTHR=0 line  Result[numpnts (result)-50,+inf] /D 
ModifyGraph lstyle(fit_Result)=2,rgb(fit_Result)=(0,0,0)

Data[7]=W_Coef[0]
end
//******************************************************************
function Bsln(Graph,Freq)
String Graph
Variable Freq
String List_fit,fit_Item
variable i, Delta,Add,peak,Start, i_fit
String Wv = stringfromlist(0,wavelist ("*",";","Win:"+Graph))
String Out = Wv+"_Artif"
duplicate/o $Wv, Temp
string Cursor_Info = CsrInfo(A,Graph)
if (strlen (stringfromlist(1,Cursor_Info))<4)
	Print "No cursor A in ",Graph
	abort
endif
variable Size =abs( Pcsr(a)-Pcsr(b))
Delta=Deltax(Temp)
Start=Pcsr(a)
Add=ceil(1/freq/delta)
if (freq==300)
	Add=340
endif
wavestats/q /r=[start,start+Size] Temp
peak=V_Max-V_min
Make/o/n=1 To_fit=0
Make/o/n=1 Time_tofit=0
do
	wavestats/q /r=[start,start+Size] Temp
	if (V_max-V_min<peak-(peak/2))
		break
	endif
	if (To_fit[0]==0)
		To_fit[0]=Temp[Start+Size]//V_max
		Time_tofit[0]=pnt2x (Temp, Start+size)//V_maxloc
		else
		insertpoints (numpnts(To_fit)),1,To_fit
		insertpoints (numpnts(Time_tofit)),1,Time_tofit
		To_fit[numpnts(To_fit)-1]=V_max
		Time_tofit[numpnts(Time_tofit)-1]=V_maxloc
	endif
	Start=Start+Add
	IF (start>numpnts(temp))
		break
	endif
while(1)
duplicate/o Temp, $Out
Display/n=Base_Correct /k=1 $Out
Wave fit_To_fit
Wave Temp
appendtograph To_fit vs Time_tofit
PauseUpdate
CurveFit/q/X=1/NTHR=0 dblexp_XOffset  To_fit /X=Time_tofit /D 
Execute "resample /SAME=Temp fit_to_fit"
execute "ModifyGraph rgb(fit_To_fit)=(0,0,0)"
end
//**************************************************************************************
Function RenKill()
Svar Base_Name_Global
Wave Data,Amplitudes, Amp_Ori, Amp_Norm, Time_Peaks,To_fit,Time_tofit,fit_To_fit, Amp_Adj, fit_0,TAUs,fit_1,fit_2,fit_3,fit_4,fit_Amplitudes, fit_exp_Amplitudes, Result, fit_Result
Variable Med= mean (Amp_Norm, numpnts(Amp_Norm)-11,numpnts(Amp_Norm)-1)
Wave Data
Data[1]=TAUs[0]
Data[2]=TAUs[1]
Data[3]=TAUs[2]
Data[4]=TAUs[3]
Data[5]=TAUs[4]
Data[6]=Med*100
Rename Amp_Ori, $Base_Name_Global+"_Amp_Ori"
Rename Data, $Base_Name_Global+"_Data"
Rename Amp_Norm, $Base_Name_Global+"_Amp_Norm"
Rename Amplitudes, $Base_Name_Global+"_Amplitudes"
Rename Time_Peaks, $Base_Name_Global+"_Time_Peaks"
Rename Time_Peaks_Zero, $Base_Name_Global+"_Time_Peaks_Zero"
Rename To_fit, $Base_Name_Global+"_To_fit"
Rename Time_tofit, $Base_Name_Global+"_Time_tofit"
Rename Fit_To_fit, $Base_Name_Global+"_Fit_To_fit"
Rename Amp_Adj, $Base_Name_Global+"_Amp_Adj"
Rename fit_0, $Base_Name_Global+"_fit_0"
Rename fit_1, $Base_Name_Global+"_fit_1"
Rename fit_2, $Base_Name_Global+"_fit_2"
Rename fit_3, $Base_Name_Global+"_fit_3"
Rename fit_4, $Base_Name_Global+"_fit_4"
Rename TAUs, $Base_Name_Global+"_TAUs"
Rename fit_Amplitudes, $Base_Name_Global+"_fit_Amplitudes"
Rename fit_exp_Amplitudes, $Base_Name_Global+"_fit_exp_Amplitudes"
Rename Result, $Base_Name_Global+"_Result"
Rename Fit_Result, $Base_Name_Global+"_Fit_Result"
RenameWindow Table_Res, $Base_Name_Global+"_Table_Res"
RenameWindow Decay, $Base_Name_Global+"_Decay" 
RenameWindow R_R_P, $Base_Name_Global+"_R_R_P"
RenameWindow Base_Correct, $Base_Name_Global+"_Base_Correct"
RenameWindow Normalized,$Base_Name_Global+"_Normal"
//String Lay = Base_Name_Global+"_Layout"
//Newlayout /k=1 /n=$Lay
//String G1=Base_Name_Global+"_Decay"
//String G2=Base_Name_Global+"_R_R_P"
//String G3=Base_Name_Global+"_Base_Correct"
//String G4=Base_Name_Global+"_Table_Res"
//String G5=Base_Name_Global+"_Normal"
//AppendLayoutObject/W=Novo /F=0 /r=(75,70,300,300) graph $G1
//AppendLayoutObject/W=Novo /F=0 /r=(315,70,540,300) graph $G2
//AppendLayoutObject/W=Novo /F=0 /r=(75,320,300,580) graph $G3
//AppendLayoutObject/W=Novo /F=0 /r=(315,320,540,580) graph $G5
//AppendLayoutObject/W=Novo /F=0 /r=(75,585,300,715) table $G4
Execute "Killwaves Temp"
end
//***************************************************************************

Function Create_Recov_Norm()
string Recov_Wv=wavelist("Recov*",";","")
String Decay_Wv=wavelist("*Amplitude*",";","")
insertpoints 0,1,$stringfromlist(0,Recov_Wv)
execute stringfromlist(0,Recov_Wv)+"[0]="+stringfromlist(0,Decay_Wv)+"[99]"
make/n=14 Normalize
execute "normalize="+ stringfromlist(0,Recov_Wv)+"/"+stringfromlist(0,Decay_Wv)+"[0]"
String New_Name = stringfromlist(0,Recov_Wv)+"_Norm"
duplicate Normalize, $New_Name
Killwaves /z Normalize
end