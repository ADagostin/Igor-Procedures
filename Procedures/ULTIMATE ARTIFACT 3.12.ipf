#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//This function was designed to remove artifacts from evoked events by selecting, with cursors A and B, the first stimulation artifact of a train of stimulus.
//It demands a graph as reference to get the cursor positioning from
//V. 3.12: removed "Amplitude calculated by exp extrapolation" option. IT wasn't woth the effort. 
Function Artifact_Panel()
string Ctrlname
Variable /G  root:Tolerance=0.9
String/g Name=""
DoWindow/k Artifact_Handling
NewPanel /N=Artifact_Handling /W=(100,100,400, 450) /K=1 
PopUpMenu NomeGrafico pos = {190,10}, BodyWidth=150
PopUpMenu NomeGrafico Title = "Choose Graph"
if (strlen(WinList("*",";","win:1"))==0)
	PopUpMenu NomeGrafico Value ="No Graphs Available"
	else
	PopUpMenu NomeGrafico Value = sortlist(WinList("*",";","win:1"),";",16)
endif
Nvar /sdfr=root: Tolerance
Variable V_Offset=60

//This Checkbox allows to analize all waves in the datafolder.  It'll use the same cursor positions as the displayed graph, though!
CheckBox All_Waves Win=Artifact_Handling, Value=0, Title="Analyze all Waves", Side=0, pos={20,95}, Proc=All_Waves
//Calculates the amplitude of the PSC realtive to the last point before the artifact
CheckBox Baseline Win=Artifact_Handling, Value=0, Title="1st Amp pnt after artifact", Side=0, pos={20,35}//, disable=2
CheckBox Baseline Win=Artifact_Handling, help={"When checked, PSC amplitude is calculated\r using the PSC 1st point as reference.\rIf not, it uses the last pnt from previous current."}
//Only analyzes waves in the Datafolder which contains the specified string in the "Name" field
CheckBox Selected_Waves Win=Artifact_Handling, Value=0, Title="Analyze waves containing:", Side=0, pos={20,73}, Proc=Selected_Waves
//Analizes peaks in or outwads
CheckBox Peak_Direction Win=Artifact_Handling, Value=0, TItle="Analyze positive peaks", Side=0, Pos={125,95}

Checkbox Manual_Freq_Input 	Win=Artifact_Handling, Value=0, TItle="Manual Freq Input", SIde=0, Pos={20,115}, proc=Manual_Frequency_Input
Setvariable Offset 				Win=Artifact_Handling, Value=_NUM:0.05,		Title="1st event (s)", 	bodywidth=60, pos={217,115}, disable=2
Setvariable Manual_Freq			Win=Artifact_Handling, Value=_NUM:0,			Title="Frequency (Hz)", 	bodywidth=60, pos={217,135}, disable=2
Setvariable NUm_Stims			Win=Artifact_Handling, Value=_NUM:50,			Title="Num Stims",		bodywidth=60, pos={217,155}, disable=2
SetVariable Sel_Waves disable=2, bodywidth=90, noproc, pos={70,70}, size={200,10},Title=" ", value=Name
Setvariable Tolerance Bodywidth=40, noproc, pos={85,50}, size={30,10}, TItle="Tolerance", Value=Tolerance, Limits={0.1,1,0.05}

Button Go Win=Artifact_Handling, pos={20,120+V_Offset}, Size = {90,20}, Title="Go!", proc=List1
Button Cancel_Art_Hand Win=Artifact_Handling, pos={150,120+V_Offset}, Size = {90,20}, Title="Cancel", Proc=Cancel_Wins

DrawText /W=Artifact_handling 20,255+V_Offset, "Fit Exponential Function to Decay"
CheckBox Fitting_S Win=Artifact_Handling, Value=1, TItle="Single", Side=0, Pos={40,260+V_Offset}, Proc=Fit_Type
CheckBox Fitting_D Win=Artifact_Handling, Value=0, TItle="Double", Side=0, Pos={120,260+V_Offset}, Proc=Fit_Type 
CheckBox Output_Graph Win=Artifact_Handling, Value=1, TItle="Display Amplitudes", Side=0, Pos={20,200+V_Offset}
CheckBox Output_Table Win=Artifact_Handling, Value=1, TItle="Make Result Table", Side=0, Pos={20,180+V_Offset}
Checkbox Output_Waves Win=Artifact_Handling, Value=0, Disable=2, Title="Calculate & make table of Avg. Amps", Side=0, Pos={20, 220+V_Offset}
DrawText /W=Artifact_handling 90,167+V_Offset, "Output Options"
Drawline /W=Artifact_handling 20,160+V_Offset,85,160+V_Offset
Drawline /W=Artifact_handling 177,160+V_Offset,250,160+V_Offset
End

Function Manual_Frequency_Input(CtrlName, Checked):CheckBoxCOntrol
String CtrlName
Variable Checked
Switch (Checked)
	Case 0:
		Setvariable Offset 				Win=Artifact_Handling, disable=2
		Setvariable Manual_Freq			Win=Artifact_Handling, disable=2
		Setvariable NUm_Stims			Win=Artifact_Handling, disable=2
	Break
	Case 1:
		Setvariable Offset 				Win=Artifact_Handling, disable=0
		Setvariable Manual_Freq			Win=Artifact_Handling, disable=0
		Setvariable NUm_Stims			Win=Artifact_Handling, disable=0
	Break

endswitch	
end

Function Display_amps(Num_Displays)
Variable Num_Displays
Variable i
String Wave_Name
controlinfo /W=artifact_Handling Output_Graph
if (v_value==1)
for (i=0;i<Num_Displays;i+=1)
	Execute "Display/k=1 Amplitudes_"+num2str(i)+" vs Amplitudes_Time_"+num2str(i)
	Execute "Appendtograph fit_Amplitudes_"+Num2str(i)
	Wave_Name="Amplitudes_"+Num2Str(i)
	Execute "ModifyGraph mode("+Wave_Name+")=3,marker("+Wave_Name+")=8,msize("+Wave_Name+")=3, rgb("+Wave_Name+")=(0,0,0)"
endfor
endif
end

Function Fit_Type(CtrlName,Checked):CheckBoxControl
String CtrlName
Variable Checked
StrSwitch (CtrlName)
	Case "Fitting_S":
		CheckBox Fitting_S, Value=1
		CheckBox Fitting_D, Value=0
		Break
	Case "Fitting_D":
		CheckBox Fitting_S, Value=0
		CheckBox Fitting_D, Value=1
		Break
EndSwitch
End

//0000000000000000000000000000000000000000000000000000000000 The code for choosing which waves will be analyzed
Function List1 (Ctrlname):ButtonControl

String Ctrlname
String List
Variable Check,i
Svar Name
Controlinfo /W=Artifact_Handling NomeGrafico
String Graph = S_Value //Selected Graph Name
Make/o/n=(1,3) /t W_Wavelist
Getwindow $graph, wavelist
string WV_Name=W_Wavelist[0][1] //- Original
//String WV_Name=removeending(List)
killwaves W_Wavelist
setdatafolder GetWavesDataFolder($WV_Name,1)
Controlinfo /W=Artifact_Handling Selected_Waves
Variable Selected_Waves=V_Value
Controlinfo /W=Artifact_Handling All_Waves
Variable All_Waves=V_Value
if (Selected_Waves==1)
	List=Wavelist("*"+Name+"*",";","")
	do
		if (stringmatch(stringfromlist(i,List),"*Artif")==1)
			List=removefromlist(stringfromlist(i,List),List)
			i=0
		endif
		i+=1
	while (i<itemsinlist(List))	
	Check=0
endif
if (All_Waves==1)
	List=Wavelist("!*Artif",";","")
	Check=1
endif
if (StringMatch(Graph,"!No Graphs Availabe")==1&&Strlen(Graph)>0&&Check!=1)
	List=Wavelist("!*Artif",";","Win:"+Graph)
	Check=2
endif
if (Check==1)
	String /g Info="        Remember: ALL waves are going to be processed!\rMake sure you have only those you want in the datafolder."
	newpanel /k=1 /n=Instructions /w=(300,200,800,350)
	Titlebox  TB1, Fsize=16, Frame=0, Anchor=LT, Pos={20,20}, Size={1,1}, Variable= Info
	Button ok, Win=Instructions, Fsize=18, pos={30,85}, Size = {200,40}, Title="Go!", proc=Multiple_Waves_Proc
	Button Cancel_Instructions, Win=Instructions, Fsize=18, pos={275,85}, Size = {200,40}, Title="Cancel", proc=Cancel_Wins
	
else
	Art_Ult(List,Graph,Check)
endif

End


Function Multi_Final()
String List,List_Output, List_Amps
Variable Check,i
ControlInfo /W=Artifact_Handling Output_Table
If (V_Value==1)
	Wave Output_Data_Title
	List_output=Wavelist("Output_Data_*",";","")
	Edit /K=1
	for (i=0;i<itemsinlist(List_Output);i+=1)
		Appendtotable $Stringfromlist(i,List_Output)
	EndFor
	Execute "Output_Data=("+removeending(RemoveFromList("Output_Data_Title",(wavelist("output_data_*","+","")),"+"))+")/"+num2str(itemsinlist(List_output))
	Execute "Appendtotable Output_Data"
EndIf
ControlInfo /W=Artifact_Handling Output_Waves
If (V_Value==1)
	List_Amps=Wavelist("Amplitudes_*",";","")
	Make/o/n=(numpnts($Stringfromlist(0,list_Amps))) Amps_AVG, Amps_Norm_AVG
	If (itemsinlist(List_Amps)>3)
		Killwaves /z Amplitudes, Amplitudes_Norm, Amplitudes_time
		For (i=0;i<itemsinlist(List_Amps);i+=1)
			If (Stringmatch(Stringfromlist(i,List_Amps),"*Time*")==0)
				If (Stringmatch(Stringfromlist(i,List_Amps),"*_Norm*")==0)
					Execute "Amps_AVG+="+Stringfromlist(i,List_Amps)
//				Else
//					If (Stringmatch(Stringfromlist(i,List_Amps),"Amplitudes_Norm")==0)
//						Execute "Amps_Norm_AVG+="+Stringfromlist(i,List_Amps)
//					EndIf
				EndIF
			EndIF
		EndFor
	EndIf
	Amps_AVG/=6
	Amps_Norm_AVG=Amps_AVG/Amps_AVG[0]
	Deletepoints 99,(Numpnts(Amps_AVG)-100),Amps_AVG
	Deletepoints 99,(Numpnts(Amps_Norm_AVG)-100),Amps_Norm_AVG
	Edit /K=1
	Appendtotable Amps_AVG, Amps_Norm_AVG
EndIf
end
//00000000000000000000000000000000000000000000000000000000000000000000000000 This will analyze all the waves in the datafolder.
Function Multiple_Waves_Proc(CtrlName):Buttoncontrol
String Ctrlname



Dowindow /k Instructions
if (waveexists($stringfromlist(0,wavelist("*Artif",";","")))==1)
	Execute "Killwaves /z "+ removeending(wavelist("*Artif",",",""))
endif
if (waveexists($stringfromlist(0,wavelist("Amplitudes*",";","")))==1)
	Execute "Killwaves /z "+ removeending(wavelist("Amplitudes*",",",""))
endif
if (waveexists($stringfromlist(0,removefromlist("Output_Data_Title",wavelist("Output_Data*",";",""))))==1)
	Execute "Killwaves /z "+ RemoveEnding(removefromlist("Output_Data_Title",wavelist("Output_Data*",",",""),","))
endif
if (waveexists($stringfromlist(0,wavelist("Areas*",";","")))==1)
	Execute "Killwaves /z "+ removeending(wavelist("Areas*",",",""))
endif


//String List=Wavelist("PMPulse*",";","")
String List=Wavelist("P_*",";","")
ControlInfo /W=Artifact_Handling All_Waves
variable check = V_Value
variable i
Wave  Amplitudes_Time, Areas, Output_Data, Amplitudes_Norm

	for (i=0;i<itemsinlist(list);i+=1)
		Art_Ult(Stringfromlist(i,list),"Graph1",Check)	
//		Fits(i)
		Ren(Stringfromlist(i,list),0,i)
		
	endfor
Multi_Final()
doupdate
Display_amps(i)
print i, " Waves Processed"
Execute "Killwaves/z Areas,Amplitudes_Time, Amplitudes,Output_Data, Amplitudes_Norm,Baseline"
ControlInfo /W=Artifact_Handling All_Waves
If (V_value==1)
Execute "make/o/n=5 Output_Data=(Output_Data_0+Output_Data_1+Output_Data_2+Output_Data_3+Output_Data_4+Output_Data_5)/6"
Endif
end
//11111111111111111111111111111111111111111111111111111111111111111111111111Closes the "Artifact_Handling" window
Function Cancel_Wins(Ctrlname) : Buttoncontrol
String Ctrlname
//DoWindow/k Artifact_Handling
StrSwitch (CtrlName)
	Case "Cancel_Art_Hand":
		DoWindow/k Artifact_Handling
		break	
	Case "Cancel_Instructions":
		Dowindow /k Instructions
		break

EndSwitch
end
//222222222222222222222222222222222222222222222222222222222222222222222222222 Activates the Checkbox Control for the "Analyze Waves Containing"
Function Selected_Waves (Ctrlname,Checked) : CheckBoxControl
String Ctrlname
Variable Checked
if (Checked==1)
	PopUpMenu NomeGrafico Win=Artifact_Handling, Value ="No Graphs Availabe", Disable=2
	CheckBox All_Waves Win=Artifact_Handling, Value=0
	SetVariable Sel_Waves activate, disable=0
	CheckBox Output_Waves Disable=0, Value=1
	else
	PopUpMenu NomeGrafico Win=Artifact_Handling, Value = sortlist(WinList("*",";","win:1"),";",16), Disable=0
	SetVariable Sel_Waves activate, disable=2
	CheckBox Output_Waves Disable=2, Value=0
endif
end
//333333333333333333333333333333333333333333333333333333333333333333333333333 Activates the Function to analyze all waves
Function All_Waves (Ctrlname,Checked) : CheckBoxControl
String Ctrlname
Variable Checked
if (Checked==1)
	PopUpMenu NomeGrafico Win=Artifact_Handling, Title ="Csrs from Graph"
	CheckBox Selected_Waves Win=Artifact_Handling, Value=0
	SetVariable Sel_Waves activate, disable=2
	CheckBox Output_Waves Value=1, Disable=0
	else
	PopUpMenu NomeGrafico Win=Artifact_Handling, Value = sortlist(WinList("*",";","win:1"),";",16), Disable=0, Title="Choose Graph"
	CheckBox Output_Waves Value=0, Disable=2
endif
end
//444444444444444444444444444444444444444444444444444444444444444444444444444 This guy is the Maestro, it makes everything happen!
function Art_Ult(List,Graph,Check)
String List,Graph
Variable Check

ControlInfo /W=Artifact_Handling NomeGrafico
Dowindow/F $S_Value
doupdate
//execute "dowindow/f "+Graph
//if (StringMatch(Graph,"!No Graphs Availabe")==1&&Strlen(Graph)>0)
//	dowindow/f $Graph
//endif
if (Check==20)
	dowindow/f Set_Cursor
	if (V_Flag==0)
		display/N=Set_Cursor /k=1 $stringfromlist(0,List)
	endif
	if (strlen (CsrInfo(B))==0)
		Dowindow/k Set_Cursor
		Dowindow/k Cursor_Error
		display/N=Set_Cursor /k=1 $stringfromlist(0,List)
		Cursor /P A, $stringfromlist(0,List), 1000
		Showinfo
		NewPanel /N=Cursor_Error /W=(450,250,700,320) /K=1 
		TitleBox Error win=Cursor_Error, Frame=3, pos={10,10}, Size={500,10},Title="         Limit the artifact with cursors A and B        "
		Button Set_Csr Win=Cursor_Error, pos={75,45}, Size = {110,20}, Title="Ok, Got it!", Proc=OK_Csr
		abort
	endif
endif
if (strlen (CsrInfo(A))==0&&Check==2)
	Dowindow/k Error
	NewPanel /N=Error /W=(450,250,700,320) /K=1 
	TitleBox Error win=Error, Frame=3, pos={10,10},Title="Catastrophic error!!!! No cursors on the Graph!!" 
	Button Go Win=Error, pos={70,40}, Size = {110,20}, Title="Ok, Got it!", proc=OK_Csr2
	abort
endif
Variable Peak_to_Start, Peak_to_End, Artifact_Size,Start,The_End,i,k,h,Decay,Total_Area,Start1
String Wave_Name
//**********************************
//this is to avoid problems with (1) different sampling rates and (2) different stimulation frequencies when looking for EPSC's amplitudes
//Variable Frequency = 50
//Frequency=Frequency*1000
Variable Variation_DeltaX
//**********************************
Controlinfo /W=Artifact_Handling Peak_Direction
 
Variable Absolute=-1
//print V_Value
if (V_Value==1)
	Absolute=1
endif
Variable Artifact_Found,j
String Name

Variable Previous_Start, Previous_Variation, Current_Variation, User_Frequency_Input, Index
controlinfo /W=Artifact_Handling Manual_Freq_Input
If (V_Value==1)
	User_Frequency_Input=1
	Controlinfo /W=Artifact_Handling NUm_Stims
	Make/o/n=(V_Value) Stim_Timepoints
	Controlinfo /W=Artifact_Handling Manual_Freq
	Stim_Timepoints=x*1/V_Value
	Controlinfo /W=Artifact_Handling Offset
	Stim_Timepoints+=V_Value 				
endif
for (h=0;h<itemsinlist(List);h+=1)
	Make/o/n=1 Amplitudes, Amplitudes_Time,Areas,Baseline =0
	Amplitudes=0
	Amplitudes_Time=0
	Areas=0
	Baseline =0
	Duplicate/o $Stringfromlist(h,List), Test
//	Variation_DeltaX= Frequency*DeltaX(Test)*343 // sets the corret "range" to search for the minimum/maximum value
	Duplicate/o/r=[pcsr(A),pcsr(B)] Test, Artifact
	Wavestats/q Artifact
	Peak_to_Start=abs(x2pnt(test,V_maxloc)-pcsr(A))
	Peak_to_End=abs(x2pnt(test,V_maxloc)-pcsr(B))
	Artifact_Size=abs(pcsr(B)-pcsr(A))
	Start=pcsr(A)
	The_End=pcsr(B)	
	duplicate /o/r=[pcsr(a),pcsr(b)] Test, Template
	duplicate /o/r=[pcsr(a),pcsr(b)] Test, Template_Ori
	Duplicate/o Template, Prev_Template
	
	do
//code to avoid very simple artifact waveform not to be positively correlaterd to baseline noise.!!!!!! ex: cell#2 012519
		If (User_Frequency_Input==0)
			Artifact_Found=Slid_Avg(Start,Test)
		Else
			if (index>=numpnts(Stim_Timepoints))
				break
			endif
			Artifact_Found=Stim_Timepoints[index]
			index+=1
			
		Endif
 		If (Artifact_Found>0)

//			if (Absolute==1)
				Duplicate/o Template, Prev_Template


				duplicate /o/r=[Artifact_Found,Artifact_Found+Artifact_Size] Test, Template

				if (k==99 && stringmatch(Stringfromlist(h,list),"pmpulse1")!=1 && stringmatch(Stringfromlist(h,list),"pmpulse4")!=1)
				//Template=Template_Ori
				endif
			
				for (i=0;i<Artifact_Size;i+=1)
			
					test[i+Artifact_Found]=NaN			
				endfor		
				Variation_DeltaX=Artifact_Found-Previous_Start-Artifact_Size
				
				if (k>0)
					if (User_Frequency_Input!=0)
						Area_EPSC(x2pnt(Test,Stim_Timepoints[index-2]), x2pnt(Test,Stim_Timepoints[index-1]),k)
						
						
					else			
					
					If  ((Start-Previous_Start)>Current_Variation*1.2)
						Area_EPSC(Previous_Start,Previous_Start+Current_Variation,K)
						
					else	
						
						Area_EPSC(Start,Previous_Start,k)
					
					Endif
					endif
				endif
				Current_Variation=Start-Previous_Start
			//	Previous_Start=Artifact_Found
				The_End=Artifact_Found+Artifact_Size //end of artifact
						
				if (K>0)
					if (k==1)
					
						AMP_Decay(0,PCsr(b,Graph),Variation_DeltaX,Absolute,0)

					endif
					if (Variation_DeltaX>Previous_Variation*1.2 && Previous_Variation!=0)
//						print The_End,Previous_Variation,k
						AMP_Decay(k,The_End,Previous_Variation,Absolute,index-1)
					
					Else			
						//AMP_Decay(k,The_End-Artifact_Size,Variation_DeltaX,Absolute) //calculates the amplitude of the EPSCs
					AMP_Decay(k,The_End,Variation_DeltaX,Absolute,index-1)
					EndIf
			
				endif
				
				Previous_Start=Artifact_Found
				Previous_Variation=Variation_DeltaX
				Start+=Artifact_Size	
				k+=1
			endif
		
//		EndIf		
		Start+=10
	While (Start<Numpnts(test))//-(The_End-Start)))
	Template=Template_Ori
	Area_EPSC(Previous_Start,Previous_Start+Current_Variation,k-1)
	if ( numpnts(Amplitudes)>5)
	Decay=((Amplitudes[numpnts(Amplitudes)-1]+Amplitudes[numpnts(Amplitudes)-2]+Amplitudes[numpnts(Amplitudes)-3]+Amplitudes[numpnts(Amplitudes)-4]+Amplitudes[numpnts(Amplitudes)-5])/5)/Amplitudes[0]
	endif
	Store("Decay",Decay,0)
	Total_Area=sum(Areas)
	Store("Area",Total_Area,0)
	Store("PPR",(Amplitudes[1]/Amplitudes[0]),0)
	Wave_Name=Stringfromlist(h,List)+"_Artif"
	Duplicate/o Test, $Wave_Name
	if ((itemsinlist(list)>1)&&(waveexists(Amplitudes)==1))
	make/o/n=(numpnts(Amplitudes)) Amplitudes_Norm=Amplitudes/Amplitudes[0]
		Name = "_"+num2str(h)
		ren(Name,1,1)
	endif
	
endfor
if (check!=1)
	Print h, "Waves Processed in graph "+Graph+" - "+num2str(numpnts(Amplitudes))+" events detected"
endif
killwaves/z test,artifact
Dowindow/k Set_Cursor

make/o/n=(numpnts(Amplitudes)) Amplitudes_Norm=Amplitudes/Amplitudes[0]

Fits(h)

setscale /i y,wavemin($Wave_Name),wavemax($Wave_Name),"A",$Wave_Name
setscale /i y,wavemin(amplitudes),wavemax(amplitudes),"A", Amplitudes
Wave Template, res, temp, W_Coef, W_Sigma, W_Fitconstants
Killwaves /z res, temp, W_Coef, W_Sigma, W_Fitconstants
end
//55555555555555555555555555555555555555555555555555555555
Function OK_Csr(Ctrlname):Buttoncontrol
String CtrlName
Killwindow Cursor_Error 
TextBox/k /N=Csr_Alert
end
//66666666666666666666666666666666666666666666666666666666
Function OK_Csr2(Ctrlname):Buttoncontrol
String CtrlName
Killwindow Error
end
//777777777777777777777777777777777777777777777777777777777
Function AMP_Decay(k,The_End,Variation_DeltaX,Absolute,index) //absolute==-1 means inward current!

	Variable k,The_End,Variation_DeltaX,Absolute,index
	variable i, Absolute_Baseline
	Variable /g Pnt_Prev_Amp
	ControlInfo /W=Artifact_Handling Baseline
//	Absolute_Baseline=V_Value
	Wave Test, Amplitudes,Amplitudes_Time,Baseline,Stim_Timepoints
	Wavestats/q/r=[The_End,The_End+Variation_DeltaX] Test
	
	if (Absolute==-1)
		i=x2pnt(test,V_minloc)
		controlinfo /W=Artifact_Handling Manual_Freq_Input
		If (V_Value==0)
			do // here the functions searches backwards untill the first NaN and uses this point as baseline to measure the EPSC amplitude
				i-=1
			while((numtype(test[i])!=2)==1)
			i+=1
			Controlinfo /W=Artifact_Handling Baseline
			if (V_Value==0)
				do//Keeps searching until it finds a non-NaN value, which is defined as the baseline
					i-=1
				while (numtype(Test[i])==2)
			Endif
//			print i, Test[i]
		else
			i=x2pnt(test,Stim_Timepoints[index])
			Wavestats/r=(Stim_Timepoints[index]+abs(xcsr(a)-xcsr(b)),Stim_Timepoints[index]+(Stim_Timepoints[1]-Stim_Timepoints[0])) test//[The_End,The_End+Variation_DeltaX] Test
		//print Stim_Timepoints[index]+abs(xcsr(a)-xcsr(b)),Stim_Timepoints[index]+(Stim_Timepoints[1]-Stim_Timepoints[0])
		//abort
		endif			
		if (k==0)
//			If (Absolute_Baseline==1)		
	//			Amplitudes[k]=V_min-Test[i]
		//	Else
				Amplitudes[k]=V_min

			controlinfo /W=Artifact_Handling Manual_Freq_Input
			If (V_Value==0)
				Amplitudes[k]=V_min-Test[i]
			EndIf
			Amplitudes_Time[k]=V_minloc
			Store("1st EPSC",v_min,1)
			Baseline[k]=Test[i]			
		else
			Insertpoints k,1,Amplitudes
			Insertpoints k,1,Baseline
			Insertpoints k,1,Amplitudes_Time
//			If (Absolute_Baseline==0)
		Amplitudes[k]=V_min

			controlinfo /W=Artifact_Handling Manual_Freq_Input
			If (V_Value==0)
				Amplitudes[k]=V_min-Test[i]
			Endif
//			Else
//				if (K==0)
//					Amplitudes[k]=V_min-Test[i]
//				else
//					Amplitudes[k]=v_min-Extrapolation(Amplitudes[k-1],(Pnt_Prev_Amp),k) //relies on the amplitude of the previous PSC
//				endif
//			EndIf
			Amplitudes_Time[k]=V_minloc
//			Baseline[k]=Extrapolation(Amplitudes[k-1],(Pnt_Prev_Amp),k)//Test[i]
			Baseline[k]=Test[i]
		endif
	else
	
		i=x2pnt(test,V_maxloc)
		do // here the functions searches backwards untill the first NaN and uses this point as baseline to measure the EPSC amplitude
			i-=1
		while((numtype(test[i])!=2))//==1)
		Wavestats/q/r=[i,V_Maxrowloc] Test
		Variable i_NaN=i
		Controlinfo /W=Artifact_Handling Baseline
		if (V_Value==0)
			do
				i-=1
			while (numtype(Test[i])==2)
		else
		i+=1
		EndIf
		if (k==0)
			Amplitudes[k]=V_max-Test[i]
			Amplitudes_Time[k]=V_maxloc
			Store("1st EPSC",v_max,1)
			Baseline[k]=Test[i]			
		else
			Insertpoints k,1,Amplitudes
			Insertpoints k,1,Baseline
			Insertpoints k,1,Amplitudes_Time
			Amplitudes[k]=V_max-Test[i]	
			Amplitudes_Time[k]=V_maxloc
			Baseline[k]=Test[i]
		endif
		
	endif
Pnt_Prev_Amp=V_minrowloc
//print "ok",Test[i],Amplitudes[k],i
//	abort
//print amplitudes[k]
end
//888888888888888888888888888888888888888888888888888888888
Function Extrapolation(PSC_Apex,Pnt_Prev_Amp,k)
Variable PSC_Apex,Pnt_Prev_Amp,k
wave template, test
Variable Delta_x		=deltax(test)
Variable Tau				=0.0005
Variable Num_Pnts_Exp =round(x2pnt(test,pnt2x(template,numpnts(template)-1)))-Pnt_Prev_Amp
return PSC_Apex*exp(-(Num_Pnts_Exp*Delta_x)/Tau)
end

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function Area_EPSC(Start1,Start,k)
Variable Start1,Start,k
Wave Test,Areas
Variable Offset,i

duplicate/o /r=[start1,start] Test, EPSC_Area

do
i+=1
if (numpnts(EPSC_Area)==i)
break
endif
while(numtype(EPSC_Area[i])==2)

//deletepoints 0,i,epsc_area  WTF DOES IT DO?!?!?!?!?!?!?!?

offset=EPSC_Area[numpnts(EPSC_Area)-1]

EPSC_Area=EPSC_Area-offset

if (k>0)
	insertpoints k-1,1,Areas
endif
Areas[k-1]= area (EPSC_Area)


Killwaves EPSC_Area
end
//999999999999999999999999999999999999999999999999999999999
Function Fits(h)
Variable h
Wave Amplitudes,Amplitudes_Time
String Name, List
Variable V_FitError=0
ControlInfo /W=artifact_handling Fitting_S
If (V_Value==1)
//	print "ok"
	ControlInfo /W=artifact_handling Peak_Direction
	If (V_Value==0)
		Wavestats/q /R=[0,20] Amplitudes
		CurveFit/q/NTHR=0 exp_XOffset  Amplitudes[V_Minloc,95] /X=Amplitudes_Time /D 
	Else
	
		Wavestats/q /R=[0,20] Amplitudes
		CurveFit/q /NTHR=0 exp_XOffset  Amplitudes[V_Maxloc,95] /X=Amplitudes_Time /D 
	EndIf
Else
	ControlInfo /W=artifact_handling Peak_Direction
	If (V_Value==0)
		Wavestats/q /R=[0,20] Amplitudes
		CurveFit/q/NTHR=0 dblexp_XOffset  Amplitudes[V_Minloc,95] /X=Amplitudes_Time /D 
	Else
		Wavestats/q /R=[0,20] Amplitudes
		CurveFit/q/NTHR=0 dblexp_XOffset  Amplitudes[V_Maxloc,95] /X=Amplitudes_Time /D 
	EndIf
EndIf


Store ("Tau",0,0)
List=wavelist("Areas*",";","")
end
//10-10-10-10-10-10-10-10-10-10-10-10-10-10-10-10-10-10-10
Function Store(Name,data,a)
String Name
Variable data
Variable a
if (a==1)
	Make /n=1/o/t Output_Data_Title
	Make/n=1/o Output_Data
	else
	insertpoints numpnts(Output_Data),1,Output_Data
	insertpoints numpnts(Output_Data_Title),1,Output_Data_Title
endif
StrSwitch(Name)
	case "1st EPSC":
		Output_Data[numpnts(Output_Data)-1]=Data
		Output_Data_Title[numpnts(Output_Data)-1]=Name+"(A)"
		break

	case "Tau":
		Wave w_coef
		Output_Data[numpnts(Output_Data)-1]=w_coef[2]*1000
		Output_Data_Title[numpnts(Output_Data)-1]=Name+" 1 (ms)"
		ControlInfo /W=Artifact_Handling Fitting_S
		If (V_Value==0)
			If (numpnts(Output_Data_Title)<6)
				Insertpoints (numpnts(Output_Data_Title)),1,Output_Data_Title,Output_Data
			EndIf
			Output_Data_Title[numpnts(Output_Data)-1]=Name+" 2 (ms)"
			Output_Data[numpnts(Output_Data)-1]=w_coef[4]*1000
		EndIf
		break

	Case "Decay":
		Output_Data[numpnts(Output_Data)-1]=Data*100
		Output_Data_Title[numpnts(Output_Data)-1]=Name+"(%)"
		break
	
	Case "Area":
		Output_Data[numpnts(Output_Data)-1]=Data*-1
		Output_Data_Title[numpnts(Output_Data)-1]=Name+"(C)"
		break
	
	Case "PPR":
		Output_Data[numpnts(Output_Data)-1]=Data
		Output_Data_Title[numpnts(Output_Data)-1]=Name
		break
	
	endswitch
end

Function Ren(Name,Multiple_Waves,Item_Num)
String Name

variable Multiple_Waves
Variable Item_num

String Wvs= "Amplitudes;Amplitudes_Time;Areas;Output_Data;Amplitudes_Norm;Baseline;fit_Amplitudes"
variable i
String New_Name
Wave Baseline

for (i=0;i<itemsinlist(Wvs);i+=1)
	if (multiple_waves==1)
		New_Name = stringfromlist(i,Wvs)+Name
		Duplicate/o $stringfromlist(i,Wvs), $New_Name
		
	else
		New_Name = stringfromlist(i,Wvs)+"_"+num2str(Item_num)
		Duplicate/o $stringfromlist(i,Wvs),$New_Name
//		 print "ren", new_name
	endif

endfor

end

//Fills the NaN gaps between EPSCs
function artef()
string list=stringfromlist(0,wavelist("*",";","win:"))
variable i
duplicate/o $list, test
for (i=1;i<numpnts(test);i+=1)
if (numtype(test[i])==2)
test[i]=test[i-1]
endif
endfor	
//print area(test,10,10.5)
END



//11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-11-
Function Shitty_Artifact()
String List=Wavelist("*_Artif",";","")
Variable i
For (i=0;i<itemsinlist(list);i+=1)
	Diff_Artef_Wave(Stringfromlist(i,list))
	Execute "Duplicate/o Alternative_Amplitudes, Alternative_Amplitudes_"+num2str(i+1)
	Execute "Duplicate/o Alternative_Amplitudes_Time, Alternative_Amplitudes_Time_"+num2str(i+1)
endfor
Execute "Killwaves Alternative_Amplitudes,Alternative_Amplitudes_Time"
Show_Traces()
end

Function Diff_Artef_Wave(Processed_Wave)
String Processed_Wave
Variable i,t, index
Wave Amplitudes, Amplitudes_Time
Duplicate/o Amplitudes, Alternative_Amplitudes
Duplicate/o Amplitudes_Time, Alternative_amplitudes_time
Execute "Differentiate "+Processed_Wave+"/D="+Processed_Wave+"_DIF"
wave test=$Processed_Wave+"_DIF"
Wave Wv=$Processed_Wave
do
	If (numtype(test[i])==2)
		for (t=i;t<(i+1000);t+=1)
			if (numtype(Test[t])!=2)
				Alternative_Amplitudes[index]=Wv[x2pnt(Wv,Alternative_Ampltude(test,t,index))]
				index+=1
				i=t
				break
			endif
		endfor
	endif
	i+=1
while (i<numpnts(test))
Killwaves test
end

Function Alternative_Ampltude(Processed_Wave,t,index)
wave Processed_Wave
Variable t,index

ControlInfo /W=Artifact_Handling Peak_Direction
Variable Peak_Direction=V_Value







wave Alternative_amplitudes_time
Wave Test2= Processed_Wave
Wavestats /q /R=[t,t+200] Test2
do
	if (test2[t]!=0) //When the artifact clips, Di/Dt=0 and messes up the deection with the first differential, so the 1st value must be different from 0
		break
	endif
	t+=1
while (test2[t]==0)
Variable Amplitude
if (Peak_Direction==1)
	Findlevel /EDGE=2 /r=[t,t+200] /Q Test2,0
	else
	Findlevel /EDGE=1 /r=[t,t+200] /Q Test2,0
endif
if (V_Flag==1)
		Findlevel /EDGE=0 /r=[t+20,t+200] /Q Test2,0
		if (V_Flag==1)
			Findpeak /q /R=[t+3,t+200] Test2
			If (V_flag==1)
				Alternative_amplitudes_time[index]=V_Peakloc
				Return V_PeakVal
			else
				pulsestats /q /b=3 /f=0.9 /r=[t,t+200] Test2
			//print "pulsestats", index, V_PulseLoc1
				Alternative_amplitudes_time[index]=V_PulseLoc1
				Return V_PulseLoc1	
			endif
		else
			Alternative_amplitudes_time[index]=V_Levelx
			Return V_Levelx
		endif
Else
		Alternative_amplitudes_time[index]=V_Levelx
		Return V_Levelx
endif
end

//DIsplays all the averaged traces (PMPulse1, PMPulse2, etc) and the  amplitudes calculated with the "Shitty_Artifact" routine
Function Show_Traces() 
String List=SortList(Wavelist("*_Artif",";",""),";",16)
String Axis
variable i, Start, Finish=1/Itemsinlist(List)-0.02
PauseUpdate
for (i=0;i<Itemsinlist(List);i+=1)
	Axis="L"+Num2Str(i+1)
	If (i==0)
		Display/L=$Axis /k=1 $Stringfromlist(i,list)
		Execute "Edit/k=1 Alternative_Amplitudes_"+Num2Str(i+1)
	Else
		Appendtograph/L=$Axis $Stringfromlist(i,List)
		Execute "Appendtotable Alternative_Amplitudes_"+Num2Str(i+1)
	EndIf
	ModifyGraph freePos($Axis)={0,bottom}, lblPosMode($Axis)=1, axisEnab($Axis)={Start, Finish}
	Execute "AppendToGraph/L="+Axis+" Alternative_Amplitudes_"+Num2Str(i+1)+" vs Alternative_Amplitudes_Time_"+Num2Str(i+1)
	Execute "ModifyGraph mode(Alternative_Amplitudes_"+Num2Str(i+1)+")=4,marker(Alternative_Amplitudes_"+Num2Str(i+1)+")=8, msize(Alternative_Amplitudes_"+Num2Str(i+1)+")=3, rgb(Alternative_Amplitudes_"+Num2Str(i+1)+")=(0,65535,0),lstyle(Alternative_Amplitudes_"+Num2Str(i+1)+")=3"
//	Execute "ModifyGraph mode(Alternative_Amplitudes_"+Num2Str(i+1)+")=4,lstyle(Alternative_Amplitudes_"+Num2Str(i+1)+")=3"
	Start=Finish+0.02
	Finish+=1/Itemsinlist(List)
endfor
SetAxis bottom 0,0.36
DoUpdate
end
//Copies the values of Cursor A to Cursor B in the graph created by the "Show_Traces"procedure
Function Correct()
Variable P_Wave, Amplitude_Value
Variable P_Amplitude
String Data_Wave_Name,Amplitude_Wave_Name
String Cursor_A=CsrInfo(A)
P_Wave=Str2Num(StringByKey("Point",Cursor_A,":"))
Data_Wave_Name=StringByKey("TNAME",Cursor_A,":")
Wave Test=$Data_Wave_Name
 Amplitude_Value=Test[P_Wave]
String Cursor_B=CsrInfo(B)
Amplitude_Wave_Name=StringByKey("TNAME",Cursor_B,":")
P_Amplitude=Str2Num(StringByKey("Point",Cursor_B,":"))
Execute Amplitude_Wave_Name+"["+Num2Str(P_Amplitude)+"]"+"="+Num2Str(Amplitude_Value)
String Num = replacestring("Alternative_Amplitudes_",Amplitude_Wave_Name,"")
Execute "Alternative_Amplitudes_Time_"+Num+"["+Num2Str(P_Amplitude)+"]="+Num2Str(Xcsr(A))
end
//********************
function fail()
String List_TM=Wavelist("Amplitudes_Time_*",";","")

String List_Amp=Wavelist("Amplitudes_Norm_*",";","")
String List_Base=WaveList("Baseline*",";","")
Variable i,k,j
Make/o/n=(itemsinlist(List_TM)) Recov_Data
For(i=0;i<itemsinlist(List_TM);i+=1)
	Wave Temp_TM=$Stringfromlist(i,list_TM)
	Wave Temp_Amp=$Stringfromlist(i,List_Amp)
	Wave Temp_Base=$StringFromList(i,List_Base)
	For (j=1;j<numpnts(Temp_Amp);j+=1)
		
		If (Temp_Amp[j]<Mean(Temp_Amp)/3)
			Deletepoints j,1,Temp_TM,Temp_Amp,Temp_Base
			j-=1
		endif
	endfor
	For (k=1;K<numpnts(Temp_TM);k+=1)
		If (Temp_TM[k]-Temp_TM[k-1]>0.02 )
			Recov_Data[i]=Temp_Amp[k]
//			print k, Stringfromlist(i,list_TM)
		endif
	EndFor
EndFor
execute "Display Amplitudes_Norm_0,Amplitudes_Norm_1,Amplitudes_Norm_2,Amplitudes_Norm_3,Amplitudes_Norm_4,Amplitudes_Norm_5"
InsertPoints 0,1, Recov_Data
end

Function NA()
String List=wavelist("Amplitudes_Norm*","+","")
variable i
wave AVG_Norm
execute "Make/o/n=(200) AVG_Norm=("+removeEnding(List)+")/6"
execute "print mean (AVG_Norm, 92,97)"
execute "recov_Data[0] = mean (AVG_Norm, 92,97)"
end

pmpulse0+=2e-9
pmpulse1+=2e-9
pmpulse2+=2e-9
pmpulse3+=2e-9
pmpulse4+=2e-9
pmpulse5+=2e-9

Function Slid_Avg(Start_Pnt,SourceWave)

	Variable Start_Pnt
	Wave SourceWave
	variable minim
	wave template, W_Coef,res2, Prev_Template
	Variable offset, scale,i,k,Reference, Template_Amp, Prev_Template_Amp
	Variable Template_Size=numpnts(Template)
	Nvar /sdfr=root: Tolerance
	wavestats/q /r=[start_pnt, start_pnt+Template_Size] SourceWave
	if ((V_max-V_min)>(wavemax(Prev_Template)-Wavemin(Prev_Template))/3)
	offset=mean(sourcewave, Start_Pnt, (Start_Pnt-5))
	scale=abs(v_min-offset)
	Reference=mean (template,pnt2x(sourcewave,1),pnt2x(sourcewave,3)) // Original
	//Reference=mean (Sourcewave,pnt2x(sourcewave,1),pnt2x(sourcewave,3)) //Looks better!!!
	Template-=Reference
	minim=wavemin(Template)
	if (minim!=0)
		Template/=(minim*-1)
	endif
	if (scale!=0)
		template*=scale
	endif

	Template+=offset
	Make/o/n=10 res=0
	if (Start_Pnt<(numpnts(SourceWave)-(Template_Size*2-2)))
		for (i=(Start_Pnt);i<(Start_Pnt+10);i+=1)
			Duplicate/o/r=[i,i+Template_Size-1]Sourcewave, temp
			res[k]=  statscorrelation(Temp,Template)
		
			k+=1
		endfor
		Wavestats/q Template
	//	If (ABS(V_Min)-ABS(V_Max)<0.1e-9) //What is this for?!!?
	//	return 0
	//	EndIF		
		Wavestats /q Template
		Template_Amp=V_Max-V_Min
		Wavestats/q Prev_template
		Prev_Template_Amp=V_Max-V_Min
		wavestats /q res

		if (V_Max>Tolerance)// && Prev_Template_Amp>=Template_Amp/10)

		//	If (Tolerance<=0.6)
		Return Look_Forward(Start_Pnt, SourceWave, Template,Template_Size, V_Max)+V_Maxrowloc
		
			return Start_pnt+V_Maxrowloc
		else
		
			return 0
		endif	
		
	Else	
	
		Return 0
	endif
else
return 0
endif
End

Function Look_Forward(Start, Sourcewave, template, Template_Size, Tolerance)
Variable Start
Wave Sourcewave, Template
Variable Template_Size, Tolerance
Variable i,k,j
make/o/n=(floor(template_Size/2)) Review
Make/o/n=10 res=0
do
for (i=(Start+j);i<(Start+10+j);i+=1)
			Duplicate/o/r=[i,i+Template_Size-1]Sourcewave, temp
			res[k]=  statscorrelation(Temp,Template)

			k+=1
endfor
k=0
review[j]=Wavemax(res)
j+=1
while (j<floor(Template_size/2))
if (Wavemax(review)>Tolerance)
	Wavestats/q review
//	print 1, V_MaxRowLoc, Tolerance
	Return Start+V_MaxRowLoc
	Else
	Return Start
Endif
end



Function Baseline_from_Prev(Prev_Start_Pnt, Prev_Start, Last_non_NaN, Peak_time, Test)
Variable Prev_Start_Pnt, Prev_Start, Last_non_NaN,Peak_Time
Wave Test


Make/o/n=3 W_Coef
Findvalue /T=5e-12 /S=(x2pnt(Test,Prev_Start)) /V=(Prev_Start_Pnt) Test
//print v_value, Prev_Start_Pnt, x2pnt(Test,Prev_Start)
CurveFit /q/NTHR=0 exp_XOffset  Test[v_value,Last_non_NaN] /D 
Make/o/n=2000 fit_Test= W_coef[0]+W_coef[1]*exp(-(x*deltax(Test))/W_coef[2])
setscale /p x,Pnt2x(Test,v_value),1e-5,"s",fit_test
//execute "setscale /p x,"+num2str(Pnt2x(avg0,v_value))+",1e-5,"+num2char(34)+"s"+Num2char(34)+",fit_test"
//print avg0(Peak_Time),fit_Test(Peak_Time)
//print peak_time
return (Test(Peak_Time)-fit_Test(Peak_Time))

//print Prev_Start_Pnt, Prev_Start

end