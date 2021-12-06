#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Menu "Macros"
	Submenu "HvG Lab Analysis"
		"AP Analysis", AP_Handling()
	
	End
End

//****************************************Creates the panel which will control the handling functions****************************************

Function AP_Handling()

	Variable/g Threshold=100
	Variable/g Baseline_Final_X=100
	VAriable/g AP_Num=5
	Variable/g AP_min=0
	DoWindow/k Action_Potential_Handling
	NewPanel /N=Action_Potential_Handling /W=(100,100,390, 530) /K=1 
	PopUpMenu NomeGrafico pos = {190,60}, BodyWidth=150
	PopUpMenu NomeGrafico Title = "Choose Graph"
	if (strlen(WinList("*",";","win:1"))==0)
		PopUpMenu NomeGrafico Value ="No Graphs Available"
		else
		PopUpMenu NomeGrafico Value = sortlist(WinList("*",";","win:1"),";",16)
	endif
	CheckBox 		Killl_Waves 			Win=Action_Potential_Handling, Value=1, Title="Kill all previous AP waves", 	Side=0, pos={14,100}
	Checkbox 		Multiple_Waves 		win=Action_Potential_Handling, Value=0, Title="Analize multiple waves", 		Side=0, pos={14,83}
	CheckBox 		Phase_Plane 			Win=Action_Potential_Handling, Value=0, Title="Plot Phase Plane", 				Side=0, pos={14,145}
	CheckBox 		Choose_Amp 				Win=Action_Potential_Handling, Value=0, Title="Amplitude from Threshold", 		Side=0, pos={120,145}
	Checkbox 		Plot_Data 				Win=Action_Potential_Handling, Value=0, Title="Plot results", 					Side=0, pos={11,305}
	Button 			Set_Cursors 			Win=Action_Potential_Handling, pos={45,120},	 size = {200,20},Title="Set Cursors",	proc=Set_Cursors
	Button 			Go 						Win=Action_Potential_Handling, pos={5,350},	 Size = {130,50}, fsize=24, Title="Go!", 			proc=AP_Analysis
	Button 			Cancel 					Win=Action_Potential_Handling, pos={153,350},	 Size = {130,50}, fsize=24, Title="Cancel", 		Proc=OK
	SetVariable 	Threshold_Detection 	Win=Action_Potential_Handling, pos={207,170},	 Size = {10,10}, BodyWidth=60, 	Value=AP_min, Title="AP minimum amplitude (mV):", noproc
	CheckBox 		Threshold_detect		Win=Action_Potential_Handling, Value=0, Title="Use threshold equation", Side=0, pos={13,198}, proc=Checkboxes
	SetVariable 	Threshold 				Win=Action_Potential_Handling, pos={179,220}, Size={10,10}, BodyWidth=40, Value=Threshold, Title="dV/dt value for threshold", noproc
	SetVariable		AVG_AP 					Win=Action_Potential_Handling, pos={250,280}, Size={10,10}, BodyWidth=40, Value=AP_Num, Title="# of APs to average (Beginning & End)", noproc
	SetVariable 	Final 					Win=Action_Potential_Handling, pos={157,250}, Size={10,10}, BodyWidth=60, Value=Baseline_Final_X, Title="AP baseline (µs): ", noproc
	TabControl AP_Detect 		win=Action_Potential_Handling,fSize=16, pos={5,5}, size={280,325}, value=1, tablabel(0)="AP detection"// proc=AP_Tab_Mngt
//	TabControl AP_Detect 		value=0, tablabel(0)="AP detection"

end

//****************************************Calculates the Individual AP Baseline ***************************************

Function BAse_Start(New_Name)

	String New_Name
	Variable Baseline
	Controlinfo /W=Action_Potential_Handling Final
	Baseline=mean($New_Name,0,v_value/1000000)
	wave temp=$New_name
	return temp[0]
	//return Baseline

end

//****************************************Controls the behavior of checkboxes ***************************************


Function Checkboxes(Box):checkboxcontrol

	STRUCT WMCheckboxAction &Box
	Strswitch (Box.CtrlName)
	Case "Threshold_detect":
		If (Box.Checked)
			SetVariable 	Threshold 	Win=Action_Potential_Handling, disable=2
			else
			SetVariable 	Threshold 	Win=Action_Potential_Handling, disable=0
		endif
	break
	endswitch
	return 0
end

//****************************************Define Action Potential boundaries*****************************************************

Function Set_Cursors(CtrlName):ButtonControl

	String CtrlName
	Controlinfo /W=Action_Potential_Handling NomeGrafico
	String Graph = S_Value //Selected Graph Name
	string List=wavelist("*",";","win:"+Graph)
	Dowindow/F $Graph
	ShowInfo

end

//********************************Cuts the APs and calls the averaging and analysis functions*****************************************

Function AP_Analysis(CtrlName):ButtonControl

	String CtrlName
	VAriable i
	String /G Err_Str="\JCCatastrophic error!!!! Multiple waves in the graph!!\r Plese select multiple analysis or remove\r unused waves."
	Controlinfo /W=Action_Potential_Handling NomeGrafico
	String Graph = S_Value //Selected Graph Name
	Controlinfo /W=Action_Potential_Handling Multiple_Waves
	string List=wavelist("*",";","win:"+Graph)
	if (itemsinlist(list)>1&&V_Value==0)
		Dowindow/k Error
		NewPanel /N=Error /W=(450,250,900,420) /K=1 
		TitleBox Error win=Error, Frame=0, pos={10,10},size={300,70},fsize=18,Variable=Err_Str 
		Button Go Win=Error, pos={165,110}, Size = {120,40}, fsize=18, Title="Ok, Got it!", proc=OK
		abort
	endif
	if (strlen(CsrInfo(A,Graph))==0)
		Dowindow/k Error
		NewPanel /N=Error /W=(450,250,700,320) /K=1 
		TitleBox Error win=Error, Frame=0, pos={30,20}, Title="Catastrophic error!!!! No cursors limiting AP!!" 
		Button Go Win=Error, pos={70,40}, Size = {110,20}, Title="Ok, Got it!", proc=OK
		abort
	endif
	String Path
	make/o/n=(3,3) /t W_wavelist
	getwindow $graph, wavelist
	Path=W_wavelist[0][1]
	if (Stringmatch(Path,"*:*")==1)
		setdatafolder removeending (Path,W_wavelist[0][0])
	endif
	List=sortlist(wavelist("*",";","win:"+Graph),";",16)
//	print list
Print "**********************************************"
	String New_Name, Home_Datafolder
	Controlinfo /W=Action_Potential_Handling Multiple_Waves
	if (itemsinlist(list)>1&&V_Value==1)
		Home_Datafolder=GetWavesDataFolder($Stringfromlist(i,list),1)	 
		for (i=0;i<itemsinlist(list);i+=1)
			if (stringmatch(Stringfromlist(i,list),"*-*")==1)
				New_Name=replacestring("-",Stringfromlist(i,list),"_")
				rename $Stringfromlist(i,list),$New_Name
				New_AP(Graph,New_Name)
			else
				print Stringfromlist(i,list)
				New_AP(Graph,Stringfromlist(i,list)) 
			endif
			SetDataFolder $Home_Datafolder
		endfor	
		SetDataFolder $Home_Datafolder
	else
		Home_Datafolder=GetWavesDataFolder($Stringfromlist(0,list),1)
		if (stringmatch(Stringfromlist(0,list),"*-*")==1)
			New_Name=replacestring("-",Stringfromlist(0,list),"_")
			rename $Stringfromlist(0,list),$New_Name
			New_AP(Graph,New_Name)
		else
			New_AP(Graph,Stringfromlist(0,list))
		Endif
		SetDataFolder $Home_Datafolder
	endif

//-------------------------------Kills all Action Potential Waves ---------------------------------{
	ControlInfo /W=Action_Potential_Handling Kill_Waves
	List=wavelist("Act_Pot*",";","")
	if ((V_Value==1)&&(Waveexists($Stringfromlist(0,List))==1))
		Killwaves $stringfromlist(i,List)
	endif

end

//****************************************Cuts the Source Wave into individual AP Waves*******************************************************

Function New_AP(Graph,Test_Wave)

	String Graph,Test_Wave
	String PA_Wave, Amp_Raw_List //= S_Value //Selected Graph Name
	Data_Folder_Handling(Test_wave)
	Duplicate/o $Test_Wave,Test
	Dowindow/F $Graph
	Variable AP_Max
	Make/o/n=1 AP_Peaks_Time=0//,Amplitudes,Amplitudes_Raw
	Make/o/n=1 Amplitudes=0
	Make/o/n=1 Baseline=0
	Make/o/n=1 AHP=0
	Make/o/n=1 Amplitudes_Raw=0
	Make/o/n=1 HW=0	
	Make/o/n=1 Rise=0
	Make/o/n=1 Fall=0
	Make/o/n=1 Threshold_Wv=0
	Make/o/n=1 Threshold_Time=0
	Make/o/n=1 Threshold_Wv_Eq=0	
	Make/o/n=1 Threshold_Time_Eq=0
	Controlinfo /W=Action_Potential_Handling Threshold_detect
	if (V_Value==1)
		Run_AP($Test_Wave)
	endif
		variable i,Start_P,End_P,Start_Range,End_Range, AP_min
	Set_Freq(abs(xcsr(b)-xcsr(a)))
	duplicate/o/r=[pcsr(a),pcsr(b)] test, Act_Pot_0
	ControlInfo /W=Action_Potential_Handling Threshold_Detection
	if (Wavemax(Act_Pot_0)>V_Value)
		Individual_Data("Act_Pot_0",Test_Wave,Pcsr(A),0)
	else
		i-=1
	endif
	wavestats/q Act_Pot_0
	Start_Range=X2Pnt(Test,V_maxLoc)-Pcsr(a)
	End_Range=Pcsr(b)-X2Pnt(Test,V_maxLoc)
	End_P=Pcsr(b)
	Make/o/n=5 /t Parameters = {"# APs","Threshold","Amplitude","HW","Baseline"}
	Make/o/n=5 Parameters_Data
	setscale /p x,0,deltax(Test),"s",Act_Pot_0
	ControlInfo /W=Action_Potential_Handling Threshold_Detection
	AP_min=V_Value/1000

	do
		findpeak/q/m=(AP_min) /P /R=[End_P,numpnts(test)] Test
		PA_Wave="Act_Pot_"+num2str(i+1)
		if (V_flag==0&&V_PeakVal>AP_min)
		//	wavestats/q /r=(v_peakloc-0.0002,v_peakloc+0.0002) Test
	//		AP_Max=wavemax (Test,v_peakloc-0.0002,v_peakloc+0.0002)
			duplicate/o /r=[floor(V_peakloc)-Start_Range,floor(V_Peakloc)+End_Range] Test, $PA_Wave
			//duplicate/o /r=[AP_Max-Start_Range,AP_Max+End_Range] Test, $PA_Wave

		else
			i+=1
			break	
		endif
		i+=1
		if (V_Flag==0)
			Individual_Data(PA_Wave,Test_Wave,floor(V_peakloc)-Start_Range,i)
			V_Flag=0
			execute "wavestats/q " + PA_Wave
			setscale /p x,0,deltax(Test),"s",$PA_Wave
		endif
		Start_P=V_PeakLoc-Start_Range
		End_P=floor(V_Peakloc)+End_Range
		if (V_FLag==0)
			setscale /p x,0,deltax(Test),"s",$PA_Wave
		endif
		doupdate
		if (getkeystate(0) & 32)
			abort
		endif
	while(V_Flag==0)
	doupdate
	Parameters_Data[0]=i
	Controlinfo /W=Action_Potential_Handling Plot_Data
	If (V_Value==1)
		Controlinfo /W=Action_Potential_Handling Multiple_Waves
		If (V_Value==0)
			Appendtograph/w=$Graph Amplitudes_Raw vs AP_Peaks_Time
			ModifyGraph/w=$Graph mode(Amplitudes_Raw)=3,msize(Amplitudes_Raw)=2;DelayUpdate
			ModifyGraph/w=$Graph rgb(Amplitudes_Raw)=(0,0,65535)
		else
			Display/k=1 $Test_Wave
			Appendtograph Amplitudes_Raw vs AP_PEaks_Time
			ModifyGraph mode(Amplitudes_Raw)=3,msize(Amplitudes_Raw)=2;DelayUpdate
			ModifyGraph rgb(Amplitudes_Raw)=(0,0,65535)
		endif
	endif
	i=0
	make/o/n=(numpnts(AP_Peaks_Time)-1) Interspike_Interval
	for (i=0;i<numpnts(AP_Peaks_Time)-1;i+=1)
		Interspike_Interval[i]=AP_Peaks_Time[i+1]-AP_Peaks_Time[i]
	endfor
	Duplicate/o AP_Peaks_Time, AP_Peaks_Time_Norm	
	AP_Peaks_Time_Norm[p]-=AP_Peaks_Time[0]
	setscale /i y,wavemin(Interspike_Interval),wavemax(Interspike_Interval),"s",Interspike_Interval
	setscale /i x, wavemin(AP_Peaks_Time),wavemax(AP_Peaks_Time),"s",AP_Peaks_Time
	setscale /i x, wavemin(AP_Peaks_Time_Norm),wavemax(AP_Peaks_Time_Norm),"s",AP_Peaks_Time_Norm
	AVG_APs()
	AP_Mean(test_wave) // Averages the APs
	string AP_list=wavelist("Act_Pot*",";","")
	if (datafolderexists("APs")==0)
		Newdatafolder APs
		else
		killdataFolder APs
		Newdatafolder APs
	endif
	setdatafolder APs
	//killwaves /a /z
	Setdatafolder ::
	For (i=0;i<itemsinlist(AP_List);i+=1)
		Movewave $Stringfromlist(i,AP_List), :APs:
	endfor
	Params(Test_Wave) //Calculates the amplitude and HW of the APs
	fill_fail()
	Continuation()
	Raster(Test_Wave)
	Kill_Frenzy()
	AHP-=Baseline //calculates the AHP relative to the baseline
end

//********************************************* Kills waves already used ************************************
Function Kill_Frenzy()

	wave Betas, Cond, Differential, D2, Erev, Fall, Mean_AP_Dif, NaNs, Temp, Test, Wave_AP_0, Wv_h_AP_0,Wv_m_AP_0,Wv_n_0, X_Zeros, X0
	killwaves /z Betas, Cond, Differential, D2, Erev, Fall, Mean_AP_Dif, NaNs, Temp, Test, Wave_AP_0, Wv_h_AP_0,Wv_m_AP_0,Wv_n_0, X_Zeros, X0
	wave Alpha, Threshold_eq, Threshold_time_eq,Th_wv
	Killwaves /z Alpha, Threshold_eq, Threshold_Time_eq, Th_wv

end

//********************************************* Averages, Differentiates and get the Parameters from the APs*******************************************

Function Continuation()

	Wave AP_Peaks_Time_Norm,Amplitudes,HW,Rise,Fall, Threshold_wv, Threshold_wv_eq
	wave ap_peaks_time
	make /o /n=(numpnts(AP_Peaks_Time)) Ap_peaks_corr=x*0.002+0.05
	Ap_peaks_corr=ap_peaks_time-ap_peaks_corr
	Controlinfo /W=Action_Potential_Handling Plot_Data
	If (V_Value==1)
		Controlinfo /W=Action_Potential_Handling Threshold_detect
		if (V_Value==1)
			Appendtotable Threshold_wv_eq,Amplitudes,HW,Ap_peaks_corr,Rise,Fall
		else
			Appendtotable Threshold_wv,Amplitudes,HW,Ap_peaks_corr,Rise,Fall
		endif
	Endif
//-------------------------------------------Printing the Phase Plot
	ControlInfo /W=Action_Potential_Handling Phase_Plane
	if (V_Value==1)
		Wave Mean_AP_DIF, Mean_AP
		display/k=1 Mean_AP_DIF vs Mean_AP
	endif

end


//*********************************************Makes the total AP average**************************************************
Function AP_Mean(Test_wave)
String Test_Wave
Wave Act_Pot_1
	String List = Wavelist("Act_Pot*",";","")//"Win:APs")
	Variable N=itemsinlist(List),i
	List=RemoveEnding(List)
	if (itemsinlist(list)>1)
		Make/o/n=(numpnts(Act_Pot_1)) Mean_AP
		for (i=0;i<=N-1;i+=1)
			duplicate/o $stringfromlist(i,List),Temp
			Mean_AP=Mean_AP+Temp
		endfor
		Mean_AP=Mean_AP/N
		SetScale/p x,0,deltax(Act_Pot_1),"s", Mean_AP
	else
		wave Act_Pot_0
		make/o/n=(numpnts(Act_Pot_0)) Mean_AP=Act_Pot_0
		SetScale/p x,0,deltax(Act_Pot_0),"s", Mean_AP
	endif

//-------------------------------------------Calculates and displays the derivative (DvDt)

	wave Mean_AP_DIF, Final_AVG, Initial_AVG
	ControlInfo /W=Action_Potential_Handling Threshold
	Variable Threshold=V_Value //Value in Volts/Sec
	Variable/g Threshold_real
	String Win_Name="AVG_"+Test_Wave
	String AP_List=Wavelist("Act_Pot*",";","")
	differentiate Mean_AP/D=Mean_AP_DIF
	Dowindow Avgs
	if (V_Flag>0)
		killwindow Avgs
	endif
	Controlinfo /W=Action_Potential_Handling Plot_Data
	If (V_Value==1)
		display/N=$Win_Name /K=1 /W=(100,100,600,500) Mean_AP
		Dowindow/F $Win_Name
		Appendtograph/R=DvDt Mean_AP_DIF
		if (Waveexists(Final_AVG)==1&&Waveexists(Initial_AVG)==1)
			Appendtograph/L=L2 Final_AVG, Initial_AVG
		endif
		pauseupdate
		for (i=0;i<itemsinlist(AP_list);i+=1)
			Appendtograph /L=Act_Pot $Stringfromlist(i,AP_list)
		endfor
		ModifyGraph freePos(DvDt)={0,kwFraction}
		ModifyGraph rgb(Mean_AP_DIF)=(0,0,0)
		ModifyGraph freePos(Act_Pot)={0,bottom}
		ModifyGraph lblPos(Act_Pot)=50
		Setscale /I y,Wavemin(Mean_AP),WaveMax(Mean_AP),"V",Mean_AP
		Setscale /I y,Wavemin(Mean_AP_DIF),WaveMax(Mean_AP_DIF),"V/s",Mean_AP_DIF
		ModifyGraph lblPos(DvDt)=50
		if (Waveexists(Final_AVG)==1&&Waveexists(Initial_AVG)==1)
			ModifyGraph freePos(L2)={0,bottom}
			ModifyGraph lblPos(L2)=50	
			ModifyGraph axisEnab(left)={0.63,1},axisEnab(DvDt)={0.63,1},axisEnab(Act_Pot)={0,0.3},Axisenab(L2)={0.33,0.6};DelayUpdate
			ModifyGraph rgb(Initial_AVG)=(0,0,0)
			Legend/C/N=text0/J/F=0 "\\s(Final_AVG) Final_AVG\r\\s(Initial_AVG) Initial_AVG"
			Legend/C/N=text0/J/X=5.00/Y=50.00
			Legend/C/N=text0/J/B=1
		else
			ModifyGraph axisEnab(left)={0.52,1},axisEnab(DvDt)={0.52,1},axisEnab(Act_Pot)={0,0.48};DelayUpdate
		endif
		Legend/C/N=text1/J/F=0 "\\s(Mean_AP) Mean_AP\r\\s(Mean_AP_DIF) Mean_AP_DIF\r"
		Legend/C/N=text1/J/B=1
		TextBox/C/N=text2/F=0/B=1 "Individual APs"
		TextBox/C/N=text2/X=5.00/Y=80.00
	Endif
	findlevel/q/EDGE=1/P Mean_AP_DIF, Threshold
	if (numtype(V_Levelx)==2)
		Threshold_real=NaN
	else
		Threshold_real=Mean_AP[round(V_Levelx)]
	Endif
	Controlinfo /W=Action_Potential_Handling Threshold_detect
	if (V_Value==1)
		wave Threshold_wv_eq
		Threshold_real=mean(Threshold_Wv_eq)
	endif
	Doupdate

end


//******************************************Calculates the AP parameters and saves is to the Parameters_Data wave*****************************************************

Function Params(Test_Wave)

	String Test_Wave
	wave Mean_AP
	Wave Parameters_Data,Parameters
	wavestats/q Mean_AP
	Nvar Threshold_real
	Variable base
	base=BAse_Start(Test_Wave)
	Variable Amplitude
	Controlinfo /W=Action_Potential_Handling Choose_Amp
	If(V_Value==0)
		Amplitude= V_Max-Base
		Print "Amplitude calculated from BASELINE = ", BAse
	else
		Amplitude= V_Max-Threshold_real
		Print "Amplitude calculated from THRESHOLD = ", Threshold_real
	endif
	Print "**********************************************"
	Variable HW,HW_ini,HW_end
	FindLevel/q /EDGE=1 Mean_AP, (Threshold_real+Amplitude/2)
	HW_ini=V_levelx
	FindLevel/q /EDGE=2 /R=(V_MaxLoc,+inf) Mean_AP, (V_max-Amplitude/2)
	HW_end=V_Levelx
	HW=HW_end-HW_ini
	Parameters_Data[1]=Threshold_real
	Parameters_Data[2]=Amplitude
	Parameters_Data[3]=HW
	Parameters_Data[4]=Base
	Controlinfo /W=Action_Potential_Handling Plot_Data
	If (V_Value==1)
		edit/n=$Test_Wave /k=1 Parameters, Parameters_Data
	Endif

end


//****************************************Kills the dialog windows when button is pressed***************************************************

Function OK(Ctrlname):Buttoncontrol

String CtrlName
Dowindow Error
if (V_Flag==1)
	Killwindow Error
	V_Flag=0
	abort
Endif
Dowindow APs
if (V_Flag==1)
	killwindow APs
	V_Flag=0
	abort
endif
Dowindow Action_Potential_Handling
if (V_Flag==1)
	killwindow Action_Potential_Handling
	V_Flag=0
endif
end


//****************************************Calculates indiviual points for amplitude (Peak-threshold) and peak time*******************************

Function Individual_Data(Wv,Test_Wave,P_Start,PA_Index)

	String Wv,Test_Wave
	Variable P_Start, PA_Index
	Wave Threshold_wv_eq, THreshold_Time_eq
	Variable Threshold, Individual_threshold_time, Individual_Threshold
	Controlinfo /W=Action_Potential_Handling Threshold_detect
	if (V_Value==0)
		ControlInfo /W=Action_Potential_Handling Threshold
		Threshold=V_Value  //Value in Volts/Sec
	endif
	Wave Differential,AP_Peaks_Time,Amplitudes,Amplitudes_Raw,HW,Rise,Fall,Threshold_Wv, Threshold_Time, AHP, Baseline
	Differentiate $Wv /D=Differential 												
	findlevel/q/EDGE=1/P Differential, Threshold								
	duplicate /o $wv, inst
	Controlinfo /W=Action_Potential_Handling Threshold_detect
	If (V_Value)
	th($Test_Wave,P_Start,numpnts(inst))
	endif
	Variable Base =BAse_Start(Wv)//Baseline
		
	Controlinfo /W=Action_Potential_Handling Threshold_detect
	if (V_Value==1)
		Individual_Threshold=threshold_wv_eq[PA_Index]
		Individual_Threshold_Time=threshold_Time_eq[PA_Index]
	else
		if (numtype(V_levelx)==2)														
			Individual_Threshold=nan														
		else																
			Individual_Threshold=inst[round(V_levelx)]		
		endif																
		Individual_Threshold_Time=(P_Start+V_levelx)*deltax(inst)
	endif
	
	Variable HW_ini,HW_end,Rise_10,Rise_90,Fall_10,Fall_90
	killwaves inst 
	Wavestats/q $Wv
	Controlinfo /W=Action_Potential_Handling Choose_Amp
	if (numpnts(AP_Peaks_Time)==1&&AP_Peaks_Time[0]==0)
		AP_Peaks_Time[0]= V_maxloc	
		if (V_Value==0)
			Amplitudes[0]=V_max-Base
		else
			Amplitudes[0]=V_max-Individual_Threshold
		endif
		Baseline[0]=Base
		Threshold_Wv[0]=Individual_Threshold
		Threshold_Time[0]=Individual_Threshold_Time
		Amplitudes_Raw[0]=V_Max
		FindLevel/q /EDGE=1 $Wv, (Individual_Threshold+Amplitudes[numpnts(Amplitudes)-1]/2)
		HW_ini=V_Levelx
		FindLevel/q /EDGE=2 /R=(V_MaxLoc,+inf) $Wv, (V_max-Amplitudes[numpnts(Amplitudes)-1]/2)
		HW_end=V_Levelx
		HW[0]= HW_end-HW_ini	
		FindLevel/q /EDGE=1 $Wv, (Individual_Threshold+(V_max-Individual_Threshold)/10)
		Rise_10=V_Levelx
		FindLevel/q /EDGE=1 $Wv, (Individual_Threshold+(9*(V_max-Individual_Threshold)/10))
		Rise_90=V_Levelx
		Rise[0]=Rise_90-Rise_10
		FindLevel/q /EDGE=2 /R=(V_MaxLoc,+inf) $Wv, (V_max-(V_max-Individual_Threshold)/10)
		Fall_10=V_Levelx
		FindLevel/q /EDGE=2 /R=(V_MaxLoc,+inf) $Wv, (V_max-(V_max-(9*Individual_Threshold)/10))
		Fall_90=V_Levelx
		Fall[0]=Fall_90-Fall_10	
		wavestats /q $WV
		Wavestats /q /r=[v_maxrowloc,numpnts($WV)-1] $Wv
		AHP[0]=V_min
	else
		insertpoints numpnts(AP_Peaks_Time),	1, AP_Peaks_Time
		insertpoints numpnts(Amplitudes),		1,Amplitudes
		insertpoints numpnts(Amplitudes_Raw),	1,Amplitudes_Raw
		insertpoints numpnts(HW),					1,HW
		insertpoints numpnts(Rise),				1,Rise
		insertpoints numpnts(Fall),				1,Fall
		insertpoints numpnts(Threshold_Wv),		1,Threshold_Wv
		insertpoints numpnts(Threshold_Time),	1,Threshold_Time
		insertpoints numpnts(AHP),					1,AHP
		insertpoints numpnts(Baseline),			1,Baseline
		AP_Peaks_Time[numpnts(AP_Peaks_Time)-1]=V_Maxloc
		If(V_Value==0)
			Amplitudes[numpnts(Amplitudes)-1]=V_max-Base
		else
			Amplitudes[numpnts(Amplitudes)-1]=V_max-Individual_Threshold
		endif
		Amplitudes_Raw[numpnts(Amplitudes_Raw)-1]=V_max
		Threshold_Wv[numpnts(Threshold_Wv)-1]=Individual_Threshold
		Threshold_Time[numpnts(Threshold_Time)-1]=Individual_Threshold_Time
		Baseline[numpnts(baseline)-1]=Base
		FindLevel /q /EDGE=1 $Wv, (Individual_Threshold+Amplitudes[numpnts(Amplitudes)-1]/2)
		HW_ini=V_Levelx
		FindLevel /q /EDGE=2 /R=(V_MaxLoc,+inf) $Wv, (V_max-Amplitudes[numpnts(Amplitudes)-1]/2)	
		HW_end=V_Levelx
		HW[numpnts(HW)-1]= HW_end-HW_ini
		FindLevel/q /EDGE=1 $Wv, (Individual_Threshold+(V_max-Individual_Threshold)/10)
		Rise_10=V_Levelx
		FindLevel/q /EDGE=1 $Wv, (Individual_Threshold+(9*(V_max-Individual_Threshold)/10))
		Rise_90=V_Levelx	
		Rise[Numpnts(Rise)-1]=Rise_90-Rise_10	
		FindLevel/q /EDGE=2 /R=(V_MaxLoc,+inf) $Wv, (V_max-(V_max-Individual_Threshold)/10)
		Fall_10=V_Levelx
		FindLevel/q /EDGE=2 /R=(V_MaxLoc,+inf) $Wv, (V_max-(V_max-(9*Individual_Threshold)/10))
		Fall_90=V_Levelx
		Fall[NumPnts(Fall)-1]=Fall_90-Fall_10	
		wavestats /q $WV
		Wavestats /q /r=[v_maxrowloc,numpnts($WV)-1] $Wv
		AHP[numpnts(AHP)-1]=V_min
	endif

end

//********Averages 5 first and 5 last APs************************
Function AVG_APs()
String list=wavelist("Act_Pot*",";","")
ControlInfo /W=Action_Potential_Handling  AVG_AP
If (itemsinlist(list)>=V_Value*2&&V_Value!=0)

	Variable i
	for (i=0;i<=4;i+=1)
		if (i==0)
			duplicate/o $stringfromlist(i,list), Initial_AVG
		else
			Execute "Initial_AVG+="+Stringfromlist(i,list)
		endif
	endfor
	Initial_AVG/=5
	for (i=0;i<=4;i+=1)
		if (i==0)
			duplicate/o $stringfromlist(itemsinlist(list)-1,list), Final_AVG
		else
			Execute "Final_AVG+="+Stringfromlist(itemsinlist(list)-1-i,list)
		endif
	endfor
	Final_AVG/=5
	Setscale /P x,0,deltax(Initial_AVG),"s",Initial_AVG,Final_AVG
endif
end

//*******************************Creates the Datafolder which will contain the data***********************************

Function Data_Folder_Handling(Test_wave)

	String Test_wave
	if (datafolderexists(Test_wave)==0)
		NewDataFolder $Test_wave
		else
		setdatafolder $Test_wave
		Killwaves /a /z
		setdatafolder ::
	endif
//	killwaves /a/z
	Execute "Duplicate /o "+Test_Wave+", "+getdatafolder(1)+Test_Wave+":"+Test_Wave
	SetDataFolder $Test_wave

end

Function Set_Freq(Delta)
Variable Delta
Variable /g root:Frequency
NVar /SDFR=root: Frequency
//10 Hz
If(Delta<0.1 && Delta>0.05)
	Frequency=10
endif
//20 Hz
If(Delta<0.05 && Delta>0.02)
	Frequency=20
endif

//50 Hz
If(Delta<0.02 && Delta>0.01)
	Frequency=50
endif
//100 Hz
If(Delta<0.01 && Delta>0.005)
	Frequency=100
endif
//200 Hz
If(Delta<0.005 && Delta>0.002)
	Frequency=200
endif
//500 Hz
If(Delta<0.002 && Delta>0.0008)
	Frequency=500
endif
//1000 Hz
If(Delta<0.0008)
	Frequency=1000
endif

Print "Calculated frequency: ",Frequency," Hz"
//Print "**********************************************"
end

//******** I have no idea what this is

function fill_fail()

wave Ap_peaks_time, threshold_wv, HW, amplitudes, Amplitudes_raw, Threshold_Wv_eq, delay
if (waveexists(Ap_peaks_time)==0)
	print "ok"
	abort
endif
duplicate /o Ap_peaks_time, APT
wave temp=APT
//Variable frequency=200
NVar /SDFR=root: Frequency
Variable Dt=1/frequency
variable i
Make/o/n=(Numpnts(AP_Peaks_Time)) Delay=0//X*dt+0.05
Make/o/n=(Numpnts(AP_Peaks_Time)) NaNs=0
delayupdate

Delay=floor((ap_peaks_time-0.05)/dt)
Delay*=dt
Delay+=0.05
Delay=ap_peaks_time-Delay
doupdate

//Delay=APT-Delay
killwaves apt

duplicate/o ap_peaks_time, D2
for (i=0;i<numpnts(ap_peaks_time)-2;i+=1)
	D2[i]=ap_peaks_time[i+1]-ap_peaks_time[i]

endfor
D2[numpnts(D2)-1]=(0.05+100*dt)-ap_peaks_time[numpnts(D2)-1]
wavestats /q D2

for (i=0;i<numpnts(D2)-1;i+=1)
	if (D2[i]>1.5*v_avg && numtype(D2[i])!=2)
	break
		insertpoints i,1,D2,ap_peaks_time,Amplitudes,Threshold_Wv_eq,Delay
		ap_peaks_time[i]=NaN
		Amplitudes[i]=NaN
	//	Amplitudes_Norm[i]=NaN
		Threshold_Wv_eq[i]=NaN
		Delay[i]=NaN
		D2[i]=NaN
		i+=1
	//	print i
	endif
endfor

end


function ConcAll() // concatenates all waves in a specific graph
string List=wavelist("*",";","Win:")
Concatenate /o /np List, Output
end


//Generates the waves for h,n and m gates following the HH formalism using Euler method - Ued for threshold calculation afterwards

Function Run_AP(Wave_Name)

Wave Wave_Name
Wave Stim_Temp=Wave_Name
String Ctrlname
Variable dt= 0.005						//Time  Step
Variable gnmh	
make/o/n=1 Cond = 10e-9					//Max Conductances in mS/cm^2) {Na,Na_r}
make/o/n=1 Erev = 93					//Battery Voltage in mV {Na,Na_r)
make/o/n=4 Alpha, Betas,Taus,X0, x_zeros =0

Variable i
String Name
Variable Tcorr=1
Variable q10 = 3
Variable V, index
Variable	gamma_ = .1

Variable	kam 	= 76.4					//(/ms)
Variable	eam 	= .03					//(/mV)
Variable	kbm 	= 6.930852			//(/ms)	: personal communication from L. Kaczmarek
Variable	ebm 	= -.043				//(/mV)

Variable	kah 	= .00013				//(/ms)
Variable	eah 	= -.1216				//(/mV)
Variable	kbh 	= 50//1.999			//(/ms)
Variable	ebh 	= .0384				//(/mV)

Variable 	ca 		= 0.12889 			//(1/ms)
Variable 	cva 	= 45 					//(mV)
Variable 	cka 	= -33.90877 			//(mV)
Variable 	cb 		= 0.12889 			//(1/ms)
Variable 	cvb 	= 45 					//(mV)
variable 	ckb 	= 12.42101 			//(mV) 

Variable 	Aalpha_n = -0.01				//(/ms-mV)
Variable	Kalpha_n = -10 				//(mV)
Variable	V0alpha_n = -25 				//(mV)
Variable	Abeta_n = 0.125 				//(/ms)
Variable	Kbeta_n = -80 				//(mV)
Variable	V0beta_n = -35 				//(mV)
//--------------------------------------------------------------------------

	Wave Stim_Temp=Wave_Name
	Name="Wave_AP_"+num2str(i)
	Duplicate /o Stim_Temp, $Name
	wave Tempo=$Name
	Name="Wv_h_AP_"+num2str(i)
	Duplicate/o  Stim_Temp, $Name
	wave tempo2=$Name
	Name="Wv_m_AP_"+num2str(i)
	Duplicate/o  Stim_Temp, $Name
	wave tempo3=$Name
	Name="Wv_n_"+num2str(i)
	Duplicate/o  Stim_Temp, $Name
	wave tempo4=$Name
	tempo=0
	tempo2=0
	tempo3=0
	tempo4=0

	do
		V=Stim_Temp[index]*1000		
		//Alpha Functions
		Alpha[0] = kam*exp(eam*v)
		Alpha[1] = kah*exp(eah*v)
		Alpha[3]=	ca * exp(-(v+cva)/cka) 
		Alpha=Alpha*Tcorr

		//Beta Functions
		Betas[0]= kbm*exp(ebm*v)
		Betas[1]= kbh*exp(ebh*v)
		Betas[3] = cb * exp(-(v+cvb)/ckb)
		Betas=Betas*Tcorr
	
		Taus = 1/(Alpha+Betas) //*1/(q10^(1.3))		//Taux and X0 (x1,x2,x3) are defined with alpha and beta
		Taus[3] = 1/(Alpha[3]+Betas[3])*1/(q10^(1.3))
		X0 = Alpha*Taus
	
		X_zeros = (1-dt/Taus)*X_zeros+dt/Taus*X0 			//Euler

		Tempo4[index]=x_zeros[3]//n
		tempo3[index]=x_zeros[0]//m
		Tempo2[index]=x_zeros[1]
		gnmh=Cond[0]*X_zeros[0]^3*x_zeros[1] 					//Calculate actual conductances g with given gates
	
		Tempo[index]=gnmh*(V-Erev[0])*1  
		index+=1
	while(Index<numpnts(Stim_Temp))
	index=0
	Setscale/p x,0,1e-5, "s",$Name

end


Function Th(wave_name,Pt_Start, Range)
Wave Wave_Name
Variable Pt_Start, Range
Variable Va=-0.031//0.055		// Forsyhte J Physiol. 2008 Jul 15; 586(Pt 14): 3493–3509.
Variable Ka= 0.0065//0.0063		//
Variable gNa = 300e-9   //if we use 2500 nS/micro2 and the cell has 40 micros in diam, gNa=12.5pS
//Variable GNa_Tot=0.5e-6						//Forsythe uses 0.5e-6
Variable ENa = 0.093	// Calculated with [Na]in=4.6 and [Na]out=153.25 @ 35 Celcius
Variable gL  = 12e-9   //Calculated as the G for cell 122319 they use 59 in the paper (page 7)
Variable gK = 200e-9							//Forsythe uses 2e-9
Variable h ,n 
Variable Threshold
Wave Wv_h_AP_0,wv_m_ap_0,Wv_n_0,Threshold_Time_Eq
Variable i,j
wave AP_100
wave TH_Wv,Threshold_Wv_Eq
if (waveexists(TH_Wv)==0)
	Make /o/n=(numpnts(Wv_h_AP_0)) TH_Wv=0
	for (i=0;i<numpnts(Wv_h_AP_0);i+=1)
		h=Wv_h_AP_0[i]
		n=Wv_n_0[i]^4
		Th_Wv[i]=Va-Ka*ln((gNa*(ENa-Va))/(gL*Ka))-Ka*ln(h)-8.1*ln(1+(gk*n)/gL)
	endfor
	setscale /p x,0,1e-5,"s",Th_Wv
	
Endif

For (i=-10;i<range;i+=1)
	if (wave_name[pt_start+i]>th_wv[pt_start+i] )//&& wave_name[i-1]<th_wv[pt_start+i-1])
		if (Threshold_Wv_Eq[0]!=0)
			insertpoints numpnts(Threshold_Wv_Eq),1,Threshold_Wv_Eq,Threshold_Time_Eq
		endif
		Threshold_Wv_Eq[numpnts(Threshold_Wv_Eq)-1]=wave_name[pt_start+i-1]
		Threshold_Time_Eq[numpnts(Threshold_Wv_Eq)-1]=deltax(wave_name)*(pt_start+i-1)
		return 0
	endif
endfor

end

//n gate model: https://senselab.med.yale.edu/ModelDB/ShowModel?model=80769&file=/AkemannKnopfelPurkinje_cell_model/Kv1.mod#tabs-2


Function Raster(Test_Wave)
String Test_Wave
wave target=$Test_Wave
NVar /SDFR=root: Frequency
Variable freq=Frequency
freq=1000/freq
variable train=100

variable i
//COntrolinfo /W=Action_Potential_Handling NomeGrafico
Variable P0=xcsr(a)
variable prev_peak=p0
Controlinfo /W=Action_Potential_Handling Threshold_Detection
Variable minimum=V_Value*1e-3
//wave P_3_3_001_1_V1
//duplicate/o P_3_3_001_1_V1, target
variable max_x=deltax(target)*(numpnts(target)-1)

make /n=(train) /o Raster_Wave=0
for (i=0;i<train;i+=1)
	findpeak /m=(minimum) /q /r=(prev_peak+0.0005,prev_peak+(freq*1e-3)*1.2) target
//	print prev_peak, freq, minimum, v_peakval, v_peakloc
	if (V_Flag==0)
	
		if (i>0)
			if (v_peakloc<prev_peak+freq/5 || v_peakloc>prev_peak-freq/5)//true
				Raster_Wave[i]=1
			//	print v_peakloc, prev_peak,i
			endif
		else
			if (v_peakloc<p0+freq/2)//true
				Raster_Wave[i]=1
			endif
		endif
	endif
	if (numtype(V_peakloc)==2)
		prev_peak+=freq/1000
	else
		prev_peak=v_peakloc
	endif
endfor


Wave AP_Peaks_Time

Make/n=(Train) /o Delay=P0+X*freq*1e-3
Duplicate/o Delay, Delay_Ori
delay=0

end

Function Make_Raster_Plot()
string list=sortlist (wavelist("*",";","Win:"),";",1+16)
variable i,j
for (i=0;i<itemsinlist(list);i+=1)
//	wave temp=$Stringfromlist(i,list)
	ModifyGraph offset($Stringfromlist(i,list))={0,i*0.1}
	//ModifyGraph mode=3,marker($Stringfromlist(i,list))=19,rgb($Stringfromlist(i,list))=(0,0,0)
endfor
end
