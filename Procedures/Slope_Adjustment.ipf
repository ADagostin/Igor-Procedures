#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Menu "Macros"
	Submenu "HvG Lab Analysis"
		"Adjust_slope"
	End
End

Function Adjust_slope()


String/g Name=""
DoWindow/k Adjustment
NewPanel /N=Adjustment /W=(100,100,370, 250) /K=1 
PopUpMenu NomeGrafico pos = {190,10}, BodyWidth=150
PopUpMenu NomeGrafico Title = "Choose Graph"
if (strlen(WinList("*",";","win:1"))==0)
	PopUpMenu NomeGrafico Value ="No Graphs Available"
	else
	PopUpMenu NomeGrafico Value = sortlist(WinList("*",";","win:1"),";",16)
endif
CheckBox 		Kill_ori 		Win=Adjustment, Value=0, Title="Kill original waves", Side=0, pos={20,95}//, Proc=All_Waves
CheckBox 		Selected_Waves Win=Adjustment, Value=0, Title="Analyse waves containing:", Side=0, pos={20,50}, Proc=Selected_Waves_Str
SetVariable 		Sel_Waves 		Win=Adjustment, disable=2, bodywidth=190, noproc, pos={45,70}, size={200,10},Title="", value=Name
Button 			Go 				Win=Adjustment, pos={20,120}, Size = {90,20}, Title="Go!", proc=List_Adjustment
Button 			Cancel 			Win=Adjustment, pos={150,120}, Size = {90,20}, Title="Cancel", Proc=Cancel_Adjustment

end

Function List_Adjustment (ctrlname)//:ButtonControl
String Ctrlname
String List
Variable i
Svar Name
Controlinfo /W=Adjustment Selected_Waves
Variable Selected_Waves=V_Value
Controlinfo /W=Adjustment NomeGrafico
String Graph = S_Value //Selected Graph Name
if (Selected_Waves==1)
	List=Wavelist("*"+Name+"*",";","")
	for (i=0;i<itemsinlist(list);i+=1)
		Adjust_slope_effector(stringfromlist(i,list))
	endfor
endif
if (StringMatch(Graph,"!No Graphs Availabe")==1&&Strlen(Graph)>0)
	List=Wavelist("*",";","Win:"+Graph)
	for (i=0;i<itemsinlist(list);i+=1)
		Adjust_slope_effector(stringfromlist(i,list))
	endfor
endif
end


//222222222222222222222222222222222222222222222222222222222222222222222222222
Function Selected_Waves_Str (Ctrlname,Checked) : CheckBoxControl
String Ctrlname
Variable Checked
if (Checked==1)
	PopUpMenu NomeGrafico Win=Adjustment, Value ="No Graphs Availabe", Disable=2
	//CheckBox All_Waves Win=Artifact_Handling, Value=0
	SetVariable Sel_Waves activate, disable=0, frame=0
	else
	PopUpMenu NomeGrafico Win=Adjustment, Value = sortlist(WinList("*",";","win:1"),";",16), Disable=0
	SetVariable Sel_Waves activate, disable=2
endif
end
//333333333333333333333333333333333333333333333333333333333333333333333333333
Function Cancel_Adjustment(Ctrlname) : Buttoncontrol
String Ctrlname
DoWindow/k Adjustment
end




Function Adjust_slope_effector(Onda)
String Onda//="root:Capacitance_cut"

//String Name=RemoveEnding(Onda)+"ap_Ori"
Duplicate/o $Onda, Temp
wavestats /q  Temp
variable i
for (i=0;i<1000;i+=1)
	if (numtype (Temp[i])!=2)
		print "Nan! = ",i
		break
	endif
endfor

Variable m= (Temp[V_npnts+V_numNaNs-1]-Temp[i])/((V_npnts+V_numNaNs-1)*dimdelta(Temp,0))
make/o/n=(V_npnts+V_numNaNs) Adjust = m*(x*dimdelta(Temp,0)-Temp[i])
setscale /p x,0,dimdelta(Temp,0),"s",Adjust
ControlInfo /W=Adjustment Kill_Ori
temp-=Adjust
if (V_value==0)

Duplicate/o temp, $Onda+"_ADJ"
else
Duplicate/o temp, $Onda
endif
//execute Onda+"= temp-Adjust"
Killwaves Temp
end