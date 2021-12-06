#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <FilterDialog> menus=0
Menu "Macros"
	Submenu "HvG Lab Analysis"
		"Capacitance AVG", Cap_Panel()
	End
End

Function Cap_Panel()

DoWindow/k Cap_Ctrl
NewPanel /N=Cap_Ctrl /W=(100,100,370, 250) /K=1 
String/g Name="Cm"
Variable/g Fit_End=6500
Button 			Jump			Win=Cap_Ctrl, pos = {60,10}, Size={150,20}, Title="Gimme da jump!", Proc=Jump_Vals
Button 			Clean			Win=Cap_Ctrl, pos = {60,30}, Size={150,20}, Title="Clean Tau Waves", Proc=Clean_Taus
CheckBox 		Make_Fit 		Win=Cap_Ctrl, Value=0, Title="Fit DblExp to traces", Side=0, pos={20,95}, Proc=Fit_Params
TitleBox 		Selected_Waves Win=Cap_Ctrl, Title="Analyse waves finishing with:",  pos={20,50}, frame=0
SetVariable 		Sel_Waves 		Win=Cap_Ctrl, disable=0, bodywidth=190, noproc, pos={45,70}, size={200,10},Title="", value=Name
SetVariable 		Fit_Limit		Win=Cap_Ctrl, Disable=2, Bodywidth=80, Pos={200,95},Value=Fit_End, Title="Endpnt:"
Button 			Go 				Win=Cap_Ctrl, pos={20,120}, Size = {90,20}, Title="Go!", proc=Cap
Button 			Cancel 			Win=Cap_Ctrl, pos={150,120}, Size = {90,20}, Title="Cancel", Proc=Cancel_Cap
end

Function Cancel_Cap(Ctrl):buttoncontrol
String Ctrl
Dowindow/k Cap_Ctrl
end

Function Jump_Vals(CtrlInfo):Buttoncontrol
String CtrlInfo
Pulo()
end

Function Clean_Taus(Ctrl):ButtonControl
String Ctrl
Clean_Wave()
end

Function Fit_Params (CtrlInfo,check):CheckboxControl
String CtrlInfo
Variable Check
SVar Name
NVar Fit_End
String List=wavelist("*"+name,";","")

if (Check==1)
	Fit_End=numpnts($Stringfromlist(0,list))-1
	SetVariable 		Fit_Limit		Win=Cap_Ctrl, Disable=0, value=Fit_End
	else
	SetVariable 		Fit_Limit		Win=Cap_Ctrl, Disable=2
endif
end
controlinfo
Function cap(CtrlInfo):ButtonControl

String CtrlInfo
String DF_Name = Getdatafolder(1)
Setdatafolder DF_Name
SVar Name
String List_Name="*_"+Name
string List_CM=Wavelist(List_Name,";","")//
//List_CM=Wavelist("*cap",";","")
string List_GS=Seg_By_Name("*_GS",List_CM)//Wavelist("*_GS",";","")//
//list_gs=Wavelist("*_rs",";","")
string List_GM=Seg_By_Name("*_GM",List_CM)//Wavelist("*_GM",";","")//
//list_gm=Wavelist("*_rm",";","")

variable i,Offset, Avg_Cap
Avg_Cap=testw(List_CM)

for (i=0;i<itemsinlist(list_CM);i+=1)

	Duplicate/o $stringfromlist(i,List_CM), Temp_CM
	Duplicate/o $stringfromlist(i,List_GS), Temp_GS
	Duplicate/o $stringfromlist(i,List_GM), Temp_GM
	offset=mean(Temp_CM ,0.05,0.350)
	Temp_CM=Temp_CM-offset
	
	execute stringfromlist(i,List_CM)+"="+ stringfromlist(i,List_CM)+"-"+num2str(offset)
	
	if (i==0)
			make/o/n=(numpnts(Temp_CM)) Capacitance=Temp_CM
			make/o/n=(numpnts(Temp_GS)) Rseries=Temp_GS
			make/o/n=(numpnts(Temp_GM)) Rmemb=Temp_GM	
	else

		Capacitance=Capacitance+Temp_CM
		Rseries=Rseries+Temp_GS
		Rmemb=Rmemb+Temp_GM
	endif
	
endfor

Capacitance=Capacitance/itemsinlist(List_CM)
Smooth 10, Capacitance
Rseries=1/(Rseries/itemsinlist(List_GS))
Rmemb=1/(Rmemb/itemsinlist(List_GM))
killwaves Temp_CM,Temp_GM,Temp_GS
display/k=1 Capacitance
pauseupdate
appendtograph /L=Rs Rseries
appendtograph /L=Rm Rmemb
ModifyGraph axisEnab(Rm)={0,0.20}
ModifyGraph axisEnab(Rs)={0.22,0.42}
ModifyGraph axisEnab(left)={0.45,0.85}

ModifyGraph freePos(Rs)={0,bottom},freePos(Rm)={0,bottom}
ModifyGraph lblPos(Rs)=90
ModifyGraph lblPos(Rm)=90
ModifyGraph axisEnab(bottom)={0,0.8}

doupdate
pauseupdate
setscale /p y,wavemin(Capacitance),wavemax(Capacitance),"F",Capacitance
setscale /p y,wavemin(Rseries), wavemax(Rseries),"Ohm",Rseries
wavestats /q Rseries
SetAxis Rs V_min-V_min/5,V_max+V_max/5

setscale /p y,wavemin(Rmemb),wavemax(Rmemb),"Ohm",Rmemb

Setscale /p x,0,deltax($Stringfromlist(0,List_CM)),"s",Capacitance, Rseries,Rmemb
wavestats/q Rmemb
SetAxis Rm V_min-V_min/5,V_max+V_max/5
for (i=0;i<itemsinlist(List_CM);i+=1)
	AppendtoGraph $Stringfromlist(i,List_CM)
	ModifyGraph rgb($Stringfromlist(i,List_CM))=(65535,32768,32768)
endfor

//Scale_Down_Cap(Capacitance, Rseries,Rmemb)
RemoveFromGraph Capacitance //this is how I figure out to bring the wave to the front...
Appendtograph Capacitance

SetAxis left wavemin(Capacitance)-abs(wavemin(Capacitance))/20,wavemax(Capacitance)+abs(wavemax(Capacitance))/20
ModifyGraph rgb(Capacitance)=(0,0,0),rgb(Rseries)=(2,39321,1)
//TextBox/C/N=text2/F=0/A=LB/X=2/Y=67 "C\Bm\M:"+num2str(Avg_Cap)+"pF"
i=50 //Will start search for NaN in the "do" loop at point 50
do
	i+=10
while ((numtype(Capacitance[i])!=2)) //Finds the 1st NaN
do
	i+=1
while (numtype(Capacitance[i])==2) // Finds the 1st real number after the NaNs
Make/o/n=(itemsinlist(List_CM)) Tau_F,Tau_S,A_F,A_S
Variable K
//*******************Individual Cm curve fitting*******************
Pauseupdate
ControlInfo /W=Cap_Ctrl Make_Fit
If (V_Value==1)
NVar Fit_End

for (K=0;K<itemsinlist(List_CM);K+=1)
//	Adjust_Exp_Individual(Stringfromlist(K,List_CM), i,Fit_End,K)
endfor
CurveFit/q/NTHR=0 dblexp_XOffset  Capacitance[i,Fit_End] /D 
else

//*********************************************************

CurveFit/q/NTHR=0 exp_XOffset  Capacitance[i,inf] /D 
endif
Doupdate
wave W_Coef

String TAU1=num2str(round(W_Coef[2]*1000))



Note Capacitance,"\rCslow:		"+num2str(Avg_Cap)+" pF"
Note Capacitance, "TAU_f:		"+TAU1+" ms"
If (numpnts(W_Coef)==5)
	String A1=num2str(round(W_Coef[1]/(w_Coef[1]+w_coef[3])*100))
	String TAU2=num2str(round(W_Coef[4]*1000))
	Note Capacitance, "TAU_s:		"+TAU2+" ms"
	TextBox/C/N=text1/F=0/A=MC "Double Exp Fit\r\\F'Symbol't\\F'Arial'\\Bf\\M = "+TAU1+" ms ("+A1+"%)\r\\F'Symbol't\\F'Arial'\\Bs\\M = "+TAU2+" s"
	Else
	TextBox/C/N=text1/F=0/A=MC "Exp Fit\r\\F'Symbol't\\F'Arial'\\Bf\\M = "+TAU1+" ms "//("+A1+"%)"//\r\\F'Symbol't\\F'Arial'\\Bs\\M = "+TAU2+" s"
EndIf
doupdate
Legend/A=LT /x=15 /y=5 /C/N=text0/F=0/A=MC "\\s(Rseries) R\Bs\M            \\s(Rmemb) R\Bm\M          \\s(Capacitance) C\Bm\M (baseline:"+num2str(Avg_Cap)+"pF)"
Dowindow/f Cap_Ctrl
end

//*******************************************************

function Leak()
string list = wavelist ("Leak*",";","")
String Name
variable i
for (i=0;i<itemsinlist(list);i+=6)
	duplicate/o $stringfromlist(0,list),test
	make/o/n=(numpnts(test)) Add
	execute "Add=("+Stringfromlist(i,List)+"+"+Stringfromlist((i+1),List)+"+"+Stringfromlist(i+2,List)+"+"+Stringfromlist(i+3,List)+"+"+Stringfromlist(i+4,List)+"+"+Stringfromlist(i+5,List)+")*(-1)"
	setscale /p x,0,deltax(test),"s",Add
	Name="Lk_"+num2str(i/6)
	duplicate /o Add, $Name
endfor
end

//*******************************************************

function testw(List_CM)
String List_CM
String Cap_note, Single_Cap,Cap
Cap="\rCslow"
Variable i, Capacitance
for (i=0;i<itemsinlist(list_CM);i+=1)
	Cap_Note=note($stringfromlist(i,List_cm))
	Single_Cap=stringbykey(Cap,Cap_Note,":",";")
	Single_Cap=RemoveEnding(Single_Cap,"pF") 
	capacitance=Capacitance+str2num(Single_Cap)
endfor
Capacitance= Capacitance/itemsinlist(list_cm)
return capacitance
end

//*******************************************************

Function Scale_Down_Cap(Capacitance, Rseries,Rmemb)
Wave Capacitance, Rseries,Rmemb 
Variable i
Duplicate /o Capacitance, Cap_Scaled_Down
Duplicate /o Rseries, Rs_Scaled_Down
Duplicate /o Rmemb, Rm_Scaled_Down
Resample /Down=50 Cap_Scaled_Down
Resample /Down=50 Rs_Scaled_Down
Resample /Down=50 Rm_Scaled_Down
Cap_Scaled_Down /= 1e-15
Rs_Scaled_Down /=1e6
Rm_Scaled_Down /=1e9
Duplicate /o Cap_Scaled_Down, Cap_Scaled_Down_Norm
wavestats/q Cap_Scaled_Down_Norm
Cap_Scaled_Down_Norm/=V_max
end
//*******************************************************
static Function Adjust_Exp_Individual(Wave_Name, Initial,Final,K)
String Wave_Name
Variable Initial,Final,K

Wave W_Coef, Tau_F,Tau_S,A_F,A_S
CurveFit/q/NTHR=0 dblexp_XOffset  $Wave_Name[Initial,Final] /D 
Tau_F[K]=	W_Coef[2]
Tau_S[K]=	W_Coef[4]
A_F[K]=	W_Coef[1]
A_S[K]=	W_Coef[3]
String Fit_Name="Fit_"+Wave_Name
String Fit_Name_Output="Fit_"+Num2str(K)
Duplicate/o $Fit_Name, $Fit_Name_Output

removefromgraph/Z $Fit_Name
Killwaves /Z $Fit_Name
end

//*******************************************************
 Function Clean_Wave()
Wave Tau_F,Tau_S,Tm,Tm_Taus
If (Waveexists(TM)==0)
	Pulo()
endif
execute "duplicate/o Tm, Tm_Taus"

wavestats/q Tau_S
Variable Num_Pnts=V_Npnts+V_numNaNs+V_NumInfs
Variable i,k
For (i=Num_Pnts-1;i>=0;i-=1)
	if (Numtype(Tau_F[i])!=0 || Numtype(Tau_S[i])!=0)
		Deletepoints i,1,Tau_F,Tau_S,Tm_Taus
	endif
endfor
k=2
do
wavestats/ q Tau_S
For (i=V_Npnts-1;i>=0;i-=1)
	if (Tau_S[i]>V_Avg+k*V_Sdev || Tau_S[i]<V_Avg-k*V_Sdev)
		Deletepoints i,1,Tau_F,Tau_S,Tm_Taus
	endif
endfor
wavestats/ q Tau_F
For (i=V_Npnts-1;i>=0;i-=1)
	if (Tau_F[i]>V_Avg+k*V_Sdev || Tau_F[i]<V_Avg-k*V_Sdev)
		Deletepoints i,1,Tau_F,Tau_S,Tm_Taus
	endif
endfor
k+=1
while (k<4)
Display/k=1 Tau_F vs Tm_Taus; AppendToGraph/R Tau_S vs Tm_Taus
end
//*******************************************************
Function /S Seg_By_Name(Suffix,List_CM)
String Suffix
String list_CM//=wavelist("*_CM",";","")
String List, Output_List, This_Name
Variable i,k
List=wavelist(Suffix,";","")
String expr="([[:alpha:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:digit:]]+)_([[:alpha:]]+)"
String PMP, Group, Series, Sweep, Trace, rest
Output_list=""
for (i=0;i<itemsinlist(List_CM);i+=1)
	SplitString/E=(expr) Stringfromlist(i,List_CM), PMP, Group, Series, Sweep, Trace, rest
	This_Name="*"+Group+"_"+Series+"_"+Sweep+"*"	
	do
		If (Stringmatch(Stringfromlist(i+k,List),This_Name)==1 && Stringmatch(Stringfromlist(i+k,List),Suffix)==1)
			If (strlen(Output_List)==0)
				Output_List=Stringfromlist(i+k,list)+";"
			else
				Output_List+=Stringfromlist(i+k,list)+";"
			
			Endif
			break
		Endif
		k+=1
	while (k<=itemsinlist(list))
endfor	
Return Output_List
end