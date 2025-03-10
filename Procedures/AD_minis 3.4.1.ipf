#pragma rtGlobals=1		// Use modern global access method.
#include <WaveSelectorWidget>
#include <PopupWaveSelector>


//The EPSC template used for EPSC detection is based on the article:
//Journal of Physiology (1993), 472, pp. 615-663 615 
//QUANTAL COMPONENTS OF UNITARY EPSCs AT THE MOSSY FIBRE SYNAPSE ON CA3 PYRAMIDAL CELLS OF RAT HIPPOCAMPUS BY P. JONAS, G. MAJOR* AND B. SAKMANN

//Deconvolution module follows Alejandro Javier Pernía-Andrade, Sarit Pati Goswami, Yvonne Stickler, Ulrich Fröbe, Alois Schlögl, Peter Jonas. Biophysical Journal, VOLUME 103, ISSUE 7, P1429-1439, OCTOBER 03, 2012 - DOI:https://doi.org/10.1016/j.bpj.2012.08.039

// ------------to do list----------------
// when returnong to an existing experiment, retrieve all the analysis performed in it. Also put all the graphs in place, including the deconveolution module.
//

Menu "Macros"

	Submenu "HvG Lab Analysis"
		"AD minis", Init_Analysis()
	End
	
End

//1 ******************************************************************************************************

Function Init_Analysis() // First dialogue to get info on wether a new or existing ananlysis is going to be performed

	String /g root:Info="       Start new or retrieve existing analysis?       "
	newpanel /k=1 /n=What_to_do /w=(300,200,800,350) as "Choose Wisely"
	Titlebox  TB1, Fsize=16, Frame=0, Anchor=LT, Pos={60,20}, Size={1,1}, Variable= Root:Info
	Button New, 		Win=What_to_do, Fsize=18, pos={30,85}, Size = {120,40}, Title="New", proc=Instructions_Handling
	Button Existing, 	Win=What_to_do, Fsize=18, pos={190,85}, Size = {120,40}, Title="Existing", proc=Instructions_Handling
	Button Cancel_Select, 		Win=What_to_do, Fsize=18, pos={350,85}, Size = {120,40}, Title="Close", proc=Instructions_Handling

End
//2 ******************************************************************************************************
//Checks for the Minis datafolder, creates it if it doesn't exists or asks for the user to properly set it
Function DFR()

	KillWindow What_to_do
	if (datafolderexists("minis")==0 && stringmatch(getdatafolder(1),"*:Minis*")!=1)
		Newdatafolder/s Minis
		DS_initialize("void")
	else
		If (Stringmatch(Getdatafolder(0),"Minis")==1)
			DS_initialize("void")
		else
			String /g root:Info="        Set the "+num2char(34)+"Minis"+num2char(34)+" datafolder and restart the Function!      "
			newpanel /k=1 /n=Instructions /w=(300,200,800,350)
			Titlebox  TB1, Fsize=16, Frame=0, Anchor=LT, Pos={20,20}, Size={1,1}, Variable= Root:Info
			Button ok, Win=Instructions, Fsize=18, pos={150,85}, Size = {200,40}, Title="Got it!", proc=Instructions_Handling
		EndIf
	endif

end

//3 ******************************************************************************************************

Function New_Analysis() //Starts a brand new analysis instance (from the main window button "New Analysis")

	//String CtrlName
	SVar /sdfr=root:Analysis_Parameters Host_Datafolder
	Variable i
	String DF_Name="Minis"
	String An_Params_Wave_Loc
	if (stringmatch(Host_Datafolder[strlen(Host_Datafolder)-1],":"))//for some reason the string "Host_Datafolder" sometimes coms with semicolon and,
		An_Params_Wave_Loc=Host_Datafolder+"An_Params"						//sometimes, without. This "if" statement prevents errors when looking for the wave
	else																				//An_Params 
		An_Params_Wave_Loc=Host_Datafolder+":An_Params"
	endif
	Host_Datafolder=getdatafolder(1)
	String Ending = stringfromlist(itemsinlist(Host_Datafolder,":")-1,Host_Datafolder,":")+":"
	setdatafolder $RemoveEnding(Host_Datafolder, Ending)
	do
		if (datafolderExists(DF_Name)==1)
			DF_Name="Minis"+num2str(i)
			i+=1
		Else
			Break
		Endif
	while (1)
	Host_Datafolder=RemoveEnding(Host_Datafolder, Ending)+DF_Name
	NewDataFolder /s $Host_Datafolder
	
	DS_initialize(An_Params_Wave_Loc)

End

//4 ******************************************************************************************************
// Initial values for the analysis parameters - sored in the Root:
Function DS_initialize(An_Params_Wave_Loc)

	String An_Params_Wave_Loc	
	String This_DF=getdatafolder(1)
	Setdatafolder Root:
	If (datafolderexists("Analysis_Parameters"))
		Setdatafolder Analysis_Parameters
	else
		Newdatafolder /S Analysis_Parameters
	endif		
	variable /G 	G_mininumber			=	0
	variable /G 	G_sweeps				=	1
	variable /G 	G_threshold			=	-14e-12
	variable /G 	G_signalwindow		=	10
	variable /G 	G_noisewindow		=	25
	variable /G 	G_stepsize			=	3
	variable /G 	G_showtime			=	0
	variable /G 	G_jump					=	170
	variable /G 	G_pointnumber		=	0
	variable /G 	G_Rise_Tau			=	0.6
	variable /G 	G_Decay_Tau			=	0.00017
	variable /G 	G_Mini_Size			=	150
	variable /G 	G_Decay_time			=	50 
	variable /G 	G_Baseline			=	50
	variable /G 	G_Bin_Size_Freq		=	0.001
	variable /G 	G_Num_BIn_Freq		=	30
	variable /G 	G_Bin_Size_Amp		=	-5e-12
	variable /G 	G_Num_BIn_Amp		=	50
	variable /G 	G_Bin_Size_Char		=	1e-12
	variable /G 	G_Num_BIn_Char		=	50
	variable /G 	G_Bin_Size_Rise		=	10e-6
	variable /G 	G_Num_BIn_Rise		=	50
	variable /G 	G_Bin_Size_Decay	=	10e-6
	variable /G 	G_Num_BIn_Decay		=	50
	Variable /G G_Tolerance			=	0.6
	Variable /G F1_Low					=	100
	Variable /G F1_High				=	500
	Variable /G F2_Low					=	200
	Variable /G F2_High				=	1000
	Variable /G Threshold_dec 		=	1.2e-12
	Variable /G Jump_dec 				=	5
	Variable /G Noise_dec 			=	20
	Variable /G Step_dec 				=	5
	Variable /G Amplitude_PSC_fit
	Variable /G x_offset_fit
	Variable /G y_offset_fit
	String/g Host_Datafolder 		=	This_DF
	
	Dowindow /K Minicontroller
	Setdatafolder Host_Datafolder
	Strswitch (An_Params_Wave_Loc)
		Case "void":
			Update_An_Params_Wave_or_Vals(0)
			Break
		Default:
			If (Waveexists (An_Params)==0)
				Make/n=(22,2) /t An_Params
				execute "An_Params="+An_Params_Wave_Loc
			EndIf
			Update_An_Params_Wave_or_Vals(2)
			Break
	EndSwitch
	
	Minicontroller("New_Exp")
	
Endmacro

//5 ******************************************************************************************************
// Well, kill all results, right?
Function DS_killallresults()

	string currentwana
	variable i
	SVar /sdfr=root:Analysis_Parameters Host_Datafolder	
	String List=Tracenamelist("Analysis_Minis#Mini_Wave",",",1)
	Execute "Removefromgraph/z /W=Analysis_Minis#Mini_Wave  "+removeending(List)	
	List=Tracenamelist("Analysis_Minis#Data_Display",",",1)
	Execute "Removefromgraph/z /W=Analysis_Minis#Data_Display "+removeending(List)	
	Setdatafolder $Host_datafolder
	list=Wavelist("*",";","")
	Controlinfo /W=Analysis_minis Use_Template
	if (V_Value)
		list=removefromlist("epsc_Template_ori",list)
	endif 
	ControlInfo /W=Analysis_Minis Which_Wave
	For (i=0;i<itemsinlist(list);i+=1)
		If (Stringmatch(Stringfromlist(i,list),S_value)!=1)
			killwaves /z $Stringfromlist(i,list)
		endif
	Endfor

Endmacro

//6******************************************************************************************************
// kills the progression window in case it is opened (due to an error or something)
Function Kill_Child_Win()
	
	String List=childwindowlist("Analysis_minis")
	Variable i
	For (i=0;i<itemsinlist(list);i+=1)
		If (Stringmatch(Stringfromlist(i,list),"Mini_Detection")==1)
			Killwindow Analysis_Minis#Mini_Detection
		EndIf
	Endfor
	
End

//7******************************************************************************************************
// Mini detection starts here
Function DS_isolateminis()

	silent 1
	Kill_Child_Win()
	SVar /sdfr=root:Analysis_Parameters Host_Datafolder
	variable avg_noise, noise_SD, avg_signal, wavenumpoints, i, events, wavenumber, timestamp, threshold, Percent_One
	string   currentwana, Progress
	nvar /sdfr=root:Analysis_Parameters G_noisewindow, G_signalwindow, G_stepsize, G_sweeps, G_threshold, G_jump, G_Mini_Size, G_Decay_Time, G_Baseline//, G_Curr_Amp, G_Curr_Decay, G_mininumber	 
	Setdatafolder $Host_Datafolder
	print "**********---------Start Isolation---------**********"
	make /N=0 /O a_Timestamp
	Dowindow /W=Analysis_minis Data_Display
	Wave /z Minis
	if (V_Flag==1)
		Execute "removefromgraph /W=Analysis_minis#Data_Display "+removeEnding(RemoveFromlist("a_Timestamp",wavelist("*",",","Win:Analysis_minis#Data_Display"),","))
	Endif
	ControlInfo /W=Analysis_Minis Which_Wave
	currentwana = S_Value
	print currentwana
	if (waveexists($currentwana)==0)
		Print "Wave not found. Please select a wave for analysis" 
		Abort
	endif
	wavestats /Q /M=1 $currentwana
	wavenumpoints =  V_npnts+V_numNans+V_numINFs
	dowindow /W=Analysis_minis Mini_detection
	If (V_Flag==1 && i>0)
		Execute "Killwindow Analysis_minis#Mini_detection"
	endif	
	Progress=Num2str(Floor(i/Numpnts($CurrentWana)*100))+" %"
	If (i==0)
		NewPanel /K=1 /N=Mini_Detection /Host=Analysis_Minis /Ext=0 /W=(10,0,250,290)
		Titlebox Percentage Frame=0, Pos={100,240}, Size={20,10}, Fsize=24, Title=Progress, Win=Analysis_Minis#Mini_Detection
		Make/O /N=2 Progression_Minis={Floor(i/Numpnts($CurrentWana)*100),100-Floor(i/Numpnts($CurrentWana)*100)}
		Make/O /T /N=2 Progression_Txt={"Whole","Percent"}
		SimplePieChart(125,125,100,Progression_Minis,Progression_Txt)
	EndIf
	i = G_noisewindow
	ControlINfo /W=Analysis_minis Positive
	Variable Absolute=V_Value
	do //inside the actual sweep
		wavestats /M=1 /Q /R=[i-G_noisewindow, i] $currentwana
		avg_noise = V_avg
		wavestats /Q /M=1 /R=[i+20, i +20+ G_signalwindow] $currentwana //I am trying the average of a small cluster of points a little ahead of the serch loop
		avg_signal = V_avg
		threshold=avg_signal-avg_noise
		//mini detected?
		Switch (Absolute)
			Case 0:
				if (threshold<=G_threshold)
					wave sourcewave = $currentwana
					wavestats/q /r=[i-G_Baseline,i+(G_Mini_Size-G_Baseline)/2] $currentwana
					events += 1
					if (Detect_Mini(Events, Sourcewave, mEPSC, G_Mini_size, V_Minloc,0)==1)				
						//Timestamp of mini
						Wavestats/q /M=1 /r=[i-G_Baseline, i+G_Mini_Size] $currentwana
						timestamp = v_minloc
						InsertPoints (events-1),1, a_Timestamp
						a_Timestamp[(events-1)]=timestamp					
					Else
						events -= 1	
					endif
				i += G_jump
				endif
				Break
			Case 1:
				if (threshold>=ABS(G_threshold))
					wave sourcewave = $currentwana
					wavestats/q /r=[i-G_Baseline,i+(G_Mini_Size-G_Baseline)/2] $currentwana
					events += 1
					if (Detect_Mini(Events, Sourcewave, mEPSC, G_Mini_size, V_Maxloc,0)==1)				
						//Timestamp of mini
						Wavestats/q /M=1 /r=[i-G_Baseline, i+G_Mini_Size] $currentwana
						timestamp = v_maxloc
						InsertPoints (events-1),1, a_Timestamp
						a_Timestamp[(events-1)]=timestamp		
					Else
						events -= 1	
					endif
				i += G_jump
				endif
				Break
		EndSwitch
//******		
		If(Floor(i/Numpnts($CurrentWana)*100)>(Percent_One+1))
			Progression_Minis[1]=	100-Floor(i/Numpnts($CurrentWana)*100)
			Progression_Minis[0]=	Floor(i/Numpnts($CurrentWana)*100)
			SimplePieChart(125,125,100,Progression_Minis,Progression_Txt)	
			Percent_One=Floor(i/Numpnts($CurrentWana)*100)
			Progress=Num2str(Percent_One)+" %"
			Titlebox Percentage Title=Progress
			DoUpdate
			pauseupdate
		EndIf	
//******
//move analysis windows
		i += G_stepsize		
	while (i < wavenumpoints)
	print num2str(events) + " mEPSCs detected"	
	wavenumber += 1		
	Killwindow /z Analysis_minis#Mini_Detection
	//create parameter waves
	make /N=(events) /O a_Amplitude, a_Risetime, a_Decaytime, a_Charge, a_Baseline, a_RiseTime_loc
	make /N=((events),2) /O Risetime_Xs
	print "**********---------End Isolation---------**********"
	DS_analyseminis()
	Killwindow /z Analysis_minis#Mini_Detection
	if (strlen (wavelist("*",";","Win:Analysis_minis#Data_Display"))>0)
		Execute "removefromgraph /W=Analysis_minis#Data_Display "+Removeending(wavelist("*",",","Win:Analysis_minis#Data_Display"),",a_Timestamp,")
	endif	
	DIsplay_mini_Graph()
	Display_and_Modify()
	Wave Minis, All_Baseline_Vals
	Setscale/p x,0,(deltax($CurrentWana)),"s",Minis,All_Baseline_Vals
	Killwaves/Z Progression_Minis,Progression_txt, Degrees, res, w_coef,W_sigma, C_Wana//, AVGs
	Filter_by_Decay()
	Make_AVG_PSC("Final")
	String Final= Update_Output_Text()
	TitleBox  Results Win=Analysis_Minis, Pos={20, 480}, Title=Final, Fsize=14, Frame=0

End

// 8 ******************************************************************************************************
// Updates the info on the detected minis displyes in the "Detection" tab

Function /S Update_Output_Text()
	
	Wave a_amplitude, a_timestamp
	
	Variable AVG_Wave=Mean(a_Amplitude)
	String SAmp_Final =num2Str(Avg_Wave)	
	SAmp_Final =RemoveEnding (SAmp_Final, "e-"+stringfromlist(( itemsinlist(SAmp_Final,"-")-1),SAmp_Final,"-"))
	AVG_Wave=Str2Num(SAmp_Final)*Str2Num(StringFromlist(1,Unity(a_Amplitude,1,0)))
	SAmp_Final=Num2Str(AVG_Wave)	
	String Final="# of PSCs : "+num2str(numpnts(a_amplitude))+"\rAvg amplitude: "+SAmp_Final+StringFromlist(0,Unity(a_Amplitude,1,0))+"A\rAvg frequency: "+Num2Str(   NumPnts(a_Amplitude)/(a_Timestamp[Numpnts(a_Timestamp)-1]-a_Timestamp[0]))+" Hz"
	if (waveexists(Results))
		Wave/t /z Results
		Results[1][1]=num2str(numpnts(a_amplitude))
		Results[2][1]=SAmp_Final+StringFromlist(0,Unity(a_Amplitude,1,0))
		Results[3][1]=Num2Str(   NumPnts(a_Amplitude)/(a_Timestamp[Numpnts(a_Timestamp)-1]-a_Timestamp[0]))+" Hz"
	endif
	Return Final
	
End

// 9 ******************************************************************************************************
//Averages and displays the average PSCs

Function Make_AVG_PSC(ControlName)//:ButtonControl

	String ControlName
	Wave EPSC_Template, AVG_d
	Variable scale
	if (StringMatch(ControlName,"Force"))
		Align_by_dAdt(1)
	else
	//	Align_by_dAdt(0)
	endif
	If (StringMatch(Controlname,"AVG_PSC")==1) //Shows the Average in a new window
		Dowindow/K Average
		Display/k=1 /N=Average AVG_d		
	EndIF
	Setscale /p x,0,deltax(AVG_d),"s",EPSC_Template
	ControlINfo /W=Analysis_minis Positive
	Variable zero=EPSC_Template[0]
	EPSC_Template-=zero
	Variable max_PNT
	if (V_value==0)
		scale=(wavemin(AVG_d)-AVG_d[0])/wavemin(EPSC_template)
	else
		scale=(wavemax(AVG_d)-AVG_d[0])/wavemax(EPSC_template)
	endif
	EPSC_Template*=scale
	EPSC_Template+=AVG_d[0]
	
end
// 10 ******************************************************************************************************
//Manages the comparison between the sliding average and the trace itself and reports a positive or negative match

Function Detect_Mini(Evt_Num, Sourcewave, mEPSC, Mini_size, Peak_Pnt,Force_EPSC_detection)

	Variable Evt_Num
	Wave /z Sourcewave, mEPSC
	Variable Mini_Size, Peak_Pnt, Force_EPSC_detection
	NVar /sdfr=root:Analysis_Parameters G_Mini_Size, G_Baseline, G_Decay_Tau, G_Rise_Tau
	ControlINfo /W=Analysis_minis Positive
	Variable Absolute=V_Value
	Controlinfo /W=Analysis_Minis Use_Template
	if (V_Value)
		if (waveexists (epsc_Template_ori)==1)
		Duplicate/o epsc_Template_ori, EPSC_Template
		else
		Controlinfo /w=Analysis_Minis Which_wave
		If (Absolute==0)
			make/o/n=(G_Mini_Size) epsc_Template= -1*  (1-exp(-(x*deltax($S_Value))/G_Rise_Tau))*  (exp(-(x*deltax($S_Value))/G_Decay_Tau))
		Else
			make/o/n=(G_Mini_Size) epsc_Template=  (1-exp(-(x*deltax($S_Value))/G_Rise_Tau))*  (exp(-(x*deltax($S_Value))/G_Decay_Tau))
		EndIF
		endif
	else
		If (Absolute==0)
			make/o/n=(G_Mini_Size) epsc_Template= -1*  (1-exp(-(x*deltax(Sourcewave))/G_Rise_Tau))*  (exp(-(x*deltax(Sourcewave))/G_Decay_Tau))
		Else
			make/o/n=(G_Mini_Size) epsc_Template=  (1-exp(-(x*deltax(Sourcewave))/G_Rise_Tau))*  (exp(-(x*deltax(Sourcewave))/G_Decay_Tau))
		EndIF
	endif
	variable ok=Sliding_Avg(x2pnt(sourcewave,Peak_Pnt),Sourcewave)
	if (ok>0)
		If (Evt_Num==1 || waveexists(Minis)==0)
			Make/o/n=(G_Mini_Size) Minis
			Make/o/t/n=(7,3) Results
			
			Results[0][1]="Template Search"
			Results[0][2]="Deconvolution"
			Results[1][0]="# of Evts"
			Results[2][0]="Amplitude"
			Results[3][0]="Frequency"
			Results[4][0]="Rise TAU"
				Results[4][2]="N/A"
			Results[5][0]="Decay TAU"
				Results[5][2]="N/A"
			Results[6][0]="Charge"
				Results[6][2]="N/A"
			Make/o/n=(10) All_Baseline_Vals
		else
			insertpoints /m=1 Evt_Num,1,Minis
			insertpoints /m=1 Evt_Num,1,All_Baseline_Vals
		endif
			if (Force_EPSC_detection)
			Minis[][Evt_num]= sourcewave[x+(x2pnt(sourcewave,Peak_Pnt)-G_Baseline)]	
			All_Baseline_Vals[][Evt_num]=Mean(sourcewave,(Peak_Pnt-G_Baseline*deltax(sourcewave)), (Peak_Pnt-(G_Baseline-10)*deltax(sourcewave)))
			else
			Minis[][Evt_num-1]= sourcewave[x+(x2pnt(sourcewave,Peak_Pnt)-G_Baseline)]	
			All_Baseline_Vals[][Evt_num-1]=Mean(sourcewave,(Peak_Pnt-G_Baseline*deltax(sourcewave)), (Peak_Pnt-(G_Baseline-10)*deltax(sourcewave)))
			endif
		Return 1
	Else
		Return 0
	endif

end
// 11 ******************************************************************************************************
//Compares the sliding template to the trace to find (or not) the event

Function Sliding_Avg(Start_Pnt,Sourcewave)

	Variable Start_Pnt
	Wave SourceWave
	variable i,k, Begin_Match, Finish_Match, Percent_Mini_Size,offset, scale,minim
	NVar /sdfr=root:Analysis_Parameters G_Mini_Size, G_Tolerance,G_noisewindow
	Make/o/n=1 res
	Make/o/n=1 crit
	Percent_Mini_Size=floor(G_Mini_Size/5)
	Begin_Match=Start_Pnt-Percent_Mini_Size
	Finish_Match=Start_Pnt+G_Mini_Size-percent_mini_size	
	Controlinfo/W=Analysis_minis Positive
	wavestats/q /r=[start_pnt, start_pnt+G_mini_size] SourceWave
	wave epsc_template
	Make/o/n=3 W_Coef
	offset=mean(sourcewave, pnt2x(sourcewave,Start_Pnt), pnt2x(sourcewave,Start_Pnt+G_noisewindow))
	If (V_Value==0)
		minim=wavemin(EPSC_Template)
		scale=abs(v_min-offset)
		epsc_template/=(minim*-1)
	Else
		minim=wavemax(EPSC_Template)
		scale=abs(v_max-offset)
		epsc_template/=minim
	EndIf
	epsc_template*=scale
	epsc_template+=offset
		if (Begin_Match<(numpnts(SourceWave)-(g_mini_size*2-2)))
			for (i=(Begin_Match);i<(Finish_Match);i+=1)
				Duplicate/o/r=[i,i+G_Mini_Size-1] SourceWave, Temp
				res[k]=   statscorrelation(Temp,epsc_template)
				insertpoints i+1,1,res
				insertpoints i+1,1,crit
				k+=1
			endfor
			deletepoints k,1,res
			wavestats/q res
			if (V_max>G_Tolerance)
				return V_Maxloc
			else
				return 0
			endif	
		endif
	return 0
	
End

// 12 ******************************************************************************************************
//Extracts all the parameters from the detected event 

Function DS_analyseminis()

	silent 1
	variable peak, baseline, twentypercent, eightypercent, amplitude, risetime, decaytime,Absolute
	variable peakpn, twentypn, wavenumber, xposition, endofminipn, Percent_One, Mini_Wave_Size, Start_Fit_Pt
	string fitwindowname,Progress
	wave /z a_Amplitude, a_Risetime, a_Decaytime, a_Charge, mininumbers,a_Baseline,Minis, C_Wana, Risetime_Xs
	wave /t Results
	nvar /sdfr=root:Analysis_Parameters G_Mini_Size, G_Baseline, G_Decay_time//, DeltaX_Main_Wave
	SVar /sdfr=root:Analysis_Parameters Host_Datafolder
	print "**********---------Start Analysis---------**********"
	wavestats/q a_risetime
	Results[4][1]=num2str(V_sum/V_npnts) //This strategy avoids the NaN resulting from the "mean" function
	wavestats/q a_decaytime
	Results[5][1]=num2str(V_sum/V_npnts)
	Results[6][1]=num2str(mean(a_Charge))
	Dowindow /K Monitor 
	SetDatafolder $Host_Datafolder
	Make/o/n=(G_Mini_Size) C_Wana
	Mini_Wave_Size=DimSize (Minis,1)	
	Wavenumber=0
	make /O /N=3 W_coef
	make/o/n=1 W_Fitconstants
	Make/o/n=1 Start_Fit
	Make/o /n=(ceil(G_Mini_size/3)) All_Decay_time
	ControlINfo /W=Analysis_minis Positive
	Absolute=V_Value
	do //for all "mEPSC*" waves
		C_Wana=Minis[p][wavenumber]
		Controlinfo /W=Analysis_Minis Which_Wave
		setscale /p x,0,Deltax($S_Value),"s",c_Wana	
		wavestats /Q /M=1 /R=[0,10] C_Wana 
		baseline = V_avg
		wavestats /Q /M=1 C_Wana 
		If (Absolute==0)
		peak = V_min; peakpn =V_MinRowLoc
		amplitude = peak - baseline
		Else
		peak = V_max; peakpn =V_MaxRowLoc
		amplitude = baseline-Peak
		EndIf
		a_Amplitude[xposition]= amplitude
		a_Baseline[xposition]=baseline
		//Risetime
		If (Absolute==0)
			twentypercent = amplitude * 0.2 + baseline
			eightypercent = amplitude * 0.8 + baseline
		Else
			twentypercent = baseline-amplitude * 0.2 
			eightypercent = baseline-amplitude * 0.8 
		EndIF
		findlevel /Q  /R=[0,peakpn] C_Wana, twentypercent 
		twentypn=V_LevelX
		findlevel /Q /R=[0, peakpn] C_Wana, eightypercent 
		a_Risetime[xposition]= (V_LevelX - twentypn)
		Risetime_Xs[xposition][q]={{twentypn},{V_LevelX}}
		//Charge
		a_Charge[xposition]= charge(xposition,C_Wana)
		//Decaytime		
		If (Absolute==0)
			eightypercent = amplitude * 0.8 + baseline //it's actually seventy, i just did not want another variable
		Else
			eightypercent = baseline-amplitude * 0.8
		EndIf
		findlevel /Q /P /R=[peakpn, G_Mini_Size] C_Wana, eightypercent 
		Start_Fit_Pt= round(V_Levelx)
		If(Wavenumber>0)
		insertpoints/M=1 Wavenumber, 1, All_Decay_time
		Insertpoints Wavenumber, 1,Start_Fit
		Endif
		Variable V_FitError=0
		CurveFit/Q /NTHR=0 /N /W=2 exp_XOffset  C_Wana[Start_Fit_Pt, numpnts(C_Wana)-1] /D /NWOK
		a_Decaytime[xposition]= W_coef(2)
		All_Decay_time[][Wavenumber]=W_coef[0]+W_coef[1]*exp(-(((x+Start_Fit_Pt)*Deltax(C_Wana))-W_fitConstants[0])/W_coef[2])
		Start_Fit[wavenumber]=Start_Fit_Pt
		//clean up and proceed	
		Progress=Num2str(Floor(wavenumber/Mini_Wave_Size*100))+" %"
		If (wavenumber==0)
			NewPanel /K=1 /N=Mini_Detection /Host=Analysis_Minis /Ext=0 /W=(10,0,250,290)
			Titlebox Percentage Frame=0, Pos={100,240}, Size={20,10}, Fsize=24, Title=Progress, Win=Analysis_Minis#Mini_Detection
			Make/O /N=2 Progression_Minis={Floor(wavenumber/Dimsize(Minis,1)*100),100-Floor(wavenumber/Mini_Wave_Size*100)}			
			Make/O /T /N=2 Progression_Txt={"Whole","Percent"}
			SimplePieChart(125,125,100,Progression_Minis,Progression_Txt)
		EndIf
		//******		
		If(Floor(wavenumber/Mini_Wave_Size*100)>(Percent_One+5))
			Progression_Minis[1]=	100-Floor(wavenumber/Mini_Wave_Size*100)
			Progression_Minis[0]=	Floor(wavenumber/Mini_Wave_Size*100)
			SimplePieChart(125,125,100,Progression_Minis,Progression_Txt)	
			Percent_One=Floor(wavenumber/Mini_Wave_Size*100)
			Progress=Num2str(Percent_One)+" %"
			Titlebox Percentage Title=Progress
			DoUpdate
			pauseupdate
		EndIf	
		//******
		wavenumber += 1
		xposition += 1
	while (Wavenumber<Mini_Wave_Size)
	
	print "**********---------End of Analysis---------**********"
	wavestats /Q /M=1 a_amplitude	
End

// 13 ******************************************************************************************************

function charge(EPSC_num, Wv_ana)

	variable EPSC_num
	Wave Wv_ana
	
	duplicate/o Wv_ana, temp_ch
	Variable charge, Absolute, ref_point, offset
	offset=mean(Wv_ana,pnt2x(Wv_ana,numpnts(Wv_ana)-6), pnt2x(Wv_ana,numpnts(Wv_ana)-1))
	temp_ch-=offset
	ControlINfo /W=Analysis_minis Positive
	Absolute=V_Value  
	wavestats /M=1 /q temp_ch
	switch (Absolute)
		Case 1:
			ref_point=V_maxrowloc
			break
		Case 0:
			ref_point=V_minrowloc
			break
	endswitch
	findvalue /s=(ref_point) /V=0 /t=(1e-12) temp_ch
	switch (V_Value)
		case -1:
			charge=area(temp_ch,pnt2x(Wv_ana,ref_point-10),inf)
		break
		default:
			charge=area(temp_ch,pnt2x(Wv_ana,ref_point-10),pnt2x(Wv_ana,V_Value))
		break
	endswitch
	if (Absolute==0)
		charge*=-1
	endif
	return charge
	killwaves /z temp_ch

end


// 14 ******************************************************************************************************
// Plots the histograms based on the user input

Function DS_plothistograms(Action)
String Action
	String Unit
	variable i
	wave a_Timestamp,a_Interminitime,a_Risetime,a_Amplitude,a_Decaytime,a_Charge
	NVar /sdfr=root:Analysis_Parameters G_Bin_Size_Freq, G_Num_BIn_Freq, G_Bin_Size_Amp, G_Num_BIn_Amp, G_Bin_Size_Char, G_Num_BIn_Char,G_Bin_Size_Rise,G_Num_Bin_Rise,G_Bin_Size_Decay,G_Num_Bin_Decay
	if (numpnts(a_Timestamp)==0)
		Error_Dialog("Analysis")
		return 0
	endif
	If(Stringmatch(Action,"Plot")==1)
		DoWindow /k All_Histograms 
		Newpanel/k=1 /n=all_histograms /w=(100,100,1080,590) as "Histograms"
		ModifYPanel /W=All_Histograms cbRGB=(65535.,65535.,65535)
		//Amplitude
		Make/N=130/D/O a_Amplitude_Hist
		Histogram/B={0,G_Bin_Size_Amp,G_Num_BIn_Amp} a_Amplitude,a_Amplitude_Hist
		Display /K=1 /Host=All_Histograms /W=(20,20,320,230) /N=Amplitudehistogram a_Amplitude_Hist as "Amplitude"
		ModifyGraph margin(right)=43
		ModifyGraph mode=5
		ModifyGraph rgb=(0,0,0)
		Label left "number ov events"
		Unit= "\\u#2Amplitude ("+replacestring (" ",stringfromlist(0,Unity(a_Amplitude,1,0)),"")+"A)"
		Label bottom Unit
		SetAxis/A/R bottom
		TextBox/N=text0/F=0/A=MT/X=0.00/Y=0.00/E "\\f01\\Z18Amplitude"
		//Risetime
		Make/N=50/D/O a_Risetime_Hist
		Histogram/B={0,G_Bin_Size_Rise,G_Num_Bin_Rise} a_Risetime,a_Risetime_Hist
		Display /K=1 /Host=All_Histograms /W=(20,260,320,470) /N=Risetimehistogram a_Risetime_Hist as "Rise time"
		ModifyGraph margin(right)=43
		ModifyGraph mode=5
		ModifyGraph rgb=(0,0,0)
		Label left "number ov events"
		Unit="\\u#2Risetime ("+replacestring (" ",stringfromlist(0,Unity(a_Risetime,1,0)),"")+"s)"
		Label bottom Unit
		SetAxis/A bottom
		TextBox/N=text0/F=0/A=MT/X=0.00/Y=0.00/E "\\f01\\Z18Risetime"
		//Decaytime
		Make/N=60/D/O a_Decaytime_Hist
		Histogram/B={0,G_Bin_Size_Decay,G_Num_Bin_Decay} a_Decaytime,a_Decaytime_Hist
		Display /K=1 /Host=All_Histograms /W=(340,20,640,230)/N=Decaytimehistogram a_Decaytime_Hist as "Decay"
		ModifyGraph margin(right)=43
		ModifyGraph mode=5
		ModifyGraph rgb=(0,0,0)
		Label left "number ov events"
		Unit="\\u#2Tau ("+replacestring (" ",stringfromlist(0,Unity(a_Decaytime,1,0)),"")+"s)"
		Label bottom Unit
		SetAxis/A bottom
		TextBox/N=text0/F=0/A=MT/X=0.00/Y=0.00/E "\\f01\\Z18Decaytime"
		//Charge
		Make/N=600/D/O a_Charge_Hist
		Histogram/B={0,G_Bin_Size_Char,G_Num_BIn_Char} a_Charge,a_Charge_Hist
		Display /K=1 /Host=All_Histograms /W=(340,260,640,470) /N=Chargehistogram a_Charge_Hist as "Charge"
		ModifyGraph margin(right)=43
		ModifyGraph mode=5
		ModifyGraph rgb=(0,0,0)
		Label left "number ov events"
		Unit="\\u#2Charge ("+replacestring (" ",stringfromlist(0,Unity(a_Charge,1,0)),"")+"C)"
		Label bottom Unit
		SetAxis/A bottom
		TextBox/N=text0/F=0/A=MT/X=0.00/Y=0.00/E "\\f01\\Z18Charge"
		//Frequency
		wavestats /Q /M=1 a_Timestamp
		i=0
		do
			Make /O /N=(V_npnts-1) a_Interminitime
			a_Interminitime[i]= a_Timestamp[(i+1)]-a_Timestamp[i]
			i+=1
		while (i<=V_npnts)
		Make/N=60/D/O a_Interminitime_Hist
		Histogram/B={0,G_Bin_Size_Freq,G_Num_BIn_Freq} a_Interminitime,a_Interminitime_Hist
		Display /K=1 /Host=All_Histograms /W=(660,20,960,230) /N=Interminitimehistogram a_Interminitime_Hist as "Inter-Event"
		ModifyGraph margin(right)=43
		ModifyGraph mode=5
		ModifyGraph rgb=(0,0,0)
		Label left "number ov events"
		Unit="\\u#2delta(Time) ("+replacestring (" ",stringfromlist(0,Unity(a_Interminitime,1,0)),"")+"s)"
		Label bottom Unit
		SetAxis/A bottom
		TextBox/N=text0/F=0/A=MT/X=0.00/Y=0.00/E "\\f01\\Z18Interminitime"
		Histogram_Panel_Vars()
	Else
		Histogram/B={0,G_Bin_Size_Amp,G_Num_BIn_Amp} a_Amplitude,a_Amplitude_Hist
		Histogram/B={0,G_Bin_Size_Rise,G_Num_Bin_Rise} a_Risetime,a_Risetime_Hist
		Histogram/B={0,G_Bin_Size_Decay,G_Num_Bin_Decay} a_Decaytime,a_Decaytime_Hist
		Histogram/B={0,G_Bin_Size_Char,G_Num_BIn_Char} a_Charge,a_Charge_Hist
		Histogram/B={0,G_Bin_Size_Freq,G_Num_BIn_Freq} a_Interminitime,a_Interminitime_Hist
	EndIF

End

// 15 ******************************************************************************************************

Function Histogram_Panel_Vars()

	NVar /sdfr=root:Analysis_Parameters G_Bin_Size_Freq, G_Num_BIn_Freq, G_Bin_Size_Amp, G_Num_BIn_Amp, G_Bin_Size_Char, G_Num_BIn_Char,G_Bin_Size_Rise,G_Num_Bin_Rise,G_Bin_Size_Decay,G_Num_Bin_Decay
	
	print G_Bin_Size_Freq, G_Num_BIn_Freq
	Titlebox Bin_Size_Pan, 				Win=All_Histograms, Fsize=14, Frame=0, Pos={735, 260}, Title="Bin size", Disable=0
	Titlebox Num_Bins_Pan, 				Win=All_Histograms, FSize=14, Frame=0, Pos={817,260}, Title="Num Bins", Disable=0
	Setvariable Hist_Bin_Freq_Pan, 	Win=All_Histograms, 	Pos={760,280}, Size={50,20}, Title="Frequency ",fsize=12, bodywidth=80, Disable=0, Value=G_Bin_Size_Freq
	Setvariable Num_Bins_Freq_Pan, 	Win=All_Histograms,	Pos={842,280}, Size={50,20}, Title=" ",fsize=12, bodywidth=80, Disable=0,Value=G_Num_BIn_Freq
	Setvariable Hist_Bin_Amp_Pan, 		Win=All_Histograms,	Pos={760,305}, Size={50,285}, Title="Amplitude",fsize=12, bodywidth=80, Disable=0, Value=G_Bin_Size_Amp
	Setvariable Num_Bins_Amp_Pan, 		Win=All_Histograms, 	Pos={842,305}, Size={50,20}, Title=" ",fsize=12, bodywidth=80, Disable=0, Value=G_Num_BIn_Amp
	Setvariable Hist_Bin_Charge_Pan, 	Win=All_Histograms, 	Pos={760,330}, Size={50,20}, Title="Charge (C) ",fsize=12, bodywidth=80, Disable=0, Value=G_Bin_Size_Char
	Setvariable Num_Bins_Charge_Pan, 	Win=All_Histograms,	Pos={842,330}, Size={50,20}, Title=" ",fsize=12, bodywidth=80, Disable=0, Value=G_Num_BIn_Char
	Setvariable Hist_Bin_Rise_Pan, 	Win=All_Histograms,	Pos={760,355}, Size={50,20}, Title="Rise (s)   ",fsize=12, bodywidth=80, Disable=0, Value=G_Bin_Size_Rise
	Setvariable Num_Bins_Rise_Pan, 	Win=All_Histograms,	Pos={842,355}, Size={50,20}, Title=" ",fsize=12, bodywidth=80, Disable=0, Value=G_Num_BIn_Rise
	Setvariable Hist_Bin_Decay_Pan, 	Win=All_Histograms,	Pos={760,380}, Size={50,20}, Title="Decay (s)  ",fsize=12, bodywidth=80, Disable=0, Value=G_Bin_Size_Decay
	Setvariable Num_Bins_Decay_Pan, 	Win=All_Histograms,	Pos={842,380}, Size={50,20}, Title=" ",fsize=12, bodywidth=80, Disable=0, Value=G_Num_BIn_Decay
	Button Update, 							Win=All_Histograms, 	pos={680,420}, size={120,40},proc=Instructions_Handling, FSize=16, title="Update results"
	Button Cancel_Pan, 					Win=All_Histograms, 	pos={820,420}, size={120,40},proc=Instructions_Handling, FSize=16, title="Close"

end

// 16 ******************************************************************************************************
// Adds the units to each of the values (A, s, V,) and their suffixe (mini, micro, nano, pico, etc...)
Function/S Unity(TestWave, Choice, Pnt_Num)

	Wave TestWave
	Variable Choice, Pnt_Num
	String Unit, SAmp_Final
	If (Choice==0) //One point Only to get the data from
		SAmp_Final=Num2Str(TestWave[Pnt_Num])
	Else
		SAmp_Final=Num2Str(Mean(TestWave))
	EndIF
	Variable Pwr_Amp=Str2Num(stringfromlist(( itemsinlist(SAmp_final,"-")-1),SAmp_Final,"-"))
	Variable Final_multiplier
	Variable Pwr_Amp_Final=Ceil (Pwr_Amp/3)
	VAriable Current_Amp_Unit= Str2Num(stringfromlist(( itemsinlist(SAmp_final,"-")-1),SAmp_Final,"-"))
	Variable Adjust_Dec=Str2Num(stringfromlist(( itemsinlist(SAmp_final,"-")-1),SAmp_Final,"-"))
	Switch (Pwr_Amp_Final)
		Case 1:
			Unit=" m"
			Final_multiplier=10^(3-Current_Amp_Unit)
			Break	
		Case 2:
			Unit=" u"
		Final_multiplier=10^(6-Current_Amp_Unit)
			Break
		Case 3:
			Unit=" n"
			Final_multiplier=10^(9-Current_Amp_Unit)
			Break	
		Case 4:
			Unit=" p"
			Final_multiplier=10^(12-Current_Amp_Unit)
			Break
	EndSwitch	
	Unit+=";"+Num2Str(Final_multiplier)+";"
	If(Strlen(Unit)>0)
		return unit
	Else
		Return ""
	Endif
	
End

// 17 ******************************************************************************************************
//manages adding or deleting a current from the detection results
Function pressdelete(Ctrl_name)

	String Ctrl_name
	nvar /sdfr=root:Analysis_Parameters G_mininumber
	variable pointnumber=G_mininumber
	wave /z a_Amplitude, a_Risetime, a_Decaytime, a_Charge, a_Timestamp, a_Baseline,Amps, Minis,Start_Fit, All_Decay_time, Risetime_Xs
	if (numpnts(Minis)==0)
		Error_Dialog("Analysis")
		return 0
	endif
	Svar /sdfr=root:Analysis_Parameters Host_Datafolder
	Setdatafolder $Host_Datafolder	
	Adjust_Points(pointnumber) //deletes or add points in the arrays	
//	SetVariable G_mininumber, Limits={0,(Numpnts(a_Amplitude)-1),1}
	SetVariable G_mininum, Limits={0,(Numpnts(a_Amplitude)-1),1}

	String Final= Update_Output_Text()
	TitleBox  Results Win=Analysis_Minis, Title=Final
	Pauseupdate
	Strswitch (Ctrl_name)
		Case "Delete":
			pressnext("Pressprevious")
			Break
		Case "":
			pressnext("Pressprevious")
			Break
	endswitch
	
End

// 18 ******************************************************************************************************
//Displays next event in the Analysis tab
Function pressnext(ctrlName)

	String ctrlName
	Variable Limits=0
	nvar /sdfr=root:Analysis_Parameters G_mininumber 
	Variable G_Curr_Amp, G_Curr_Decay
	if (G_mininumber<0)
		G_mininumber=0
	endif
	Wave Minis,a_amplitude, Start_Fit, All_Decay_time,a_Decaytime
	if (numpnts(Minis)==0)
		Error_Dialog("Analysis")
		return 0
	endif	
	SetVariable G_mininum, Limits={0,(dimsize(minis,1)-1),1}	
	if (G_Mininumber>=(dimsize(minis,1)-1))
		If (G_Mininumber>=(dimsize(minis,1)-1) || Stringmatch(CtrlName,"pressNext")==1)
			G_Mininumber=dimsize(minis,1)-1
			Limits=1
		Endif
	endif	
	if (G_Mininumber==0)
		If (G_mininumber<0 || Stringmatch(CtrlName,"pressprevious")==1)
			G_Mininumber=0
			Limits=1
		Endif
	Endif	
	If (limits==0)
		StrSwitch (CtrlName)
		Case "pressNext":
			G_mininumber += 1
			Modify_Point(G_mininumber,0)
			Break
		Case "pressprevious":
			G_mininumber -= 1
			Modify_Point(G_mininumber,0)
			Break
		EndSwitch
	Endif	
	make /o /n=(1,3) /T W_WaveList
	getwindow 	Analysis_Minis#Mini_Wave wavelist
	String list= removeending(tracenamelist("Analysis_Minis#Mini_Wave",",",1))
	execute "Removefromgraph /z /W=Analysis_Minis#Mini_Wave "+ list
	if (numtype(G_MiniNumber)==2)
		G_MiniNumber=0
	endif
	MatrixOP /FREE Wv_Mini=col(minis,G_MiniNumber)
	ControlInfo /W=Analysis_Minis Positive

	Variable Absolute = V_Value
	
	If (Absolute==0)
		wavestats/m=1/q Wv_Mini
		Make/n=1/o Pt_time_Amp=V_Minloc*Deltax($S_value)
	Else
		wavestats/m=1/q Wv_Mini
		Make/n=1/o Pt_time_Amp=V_Maxloc*Deltax($S_value)
	EndIF
	Setscale/p x,Start_Fit[G_MiniNumber]*deltax($S_value),Deltax($S_value),"s",All_Decay_time
	Appendtograph /W=Analysis_Minis#Mini_Wave Minis[][G_MiniNumber],All_Baseline_Vals[][G_Mininumber],All_Decay_time[][G_Mininumber]
	Appendtograph /W=Analysis_Minis#Mini_Wave Amps[G_Mininumber,G_Mininumber] vs Pt_time_Amp
	ModifyGraph /W=Analysis_Minis#Mini_Wave mode(Amps)=3, marker=19, msize(Amps)=3,rgb(Amps)=(1,4,52428)
	ModifyGraph /W=Analysis_Minis#Mini_Wave rgb(Minis)=(0,0,0)
	ModifyGraph /W=Analysis_Minis#Mini_Wave lsize(All_Baseline_Vals)=3, lsize(All_Decay_time)=2
	Killwaves/z Wv_Mini	
	String Thsi_Unit=Unity(a_Amplitude,0,G_mininumber)
	String SAmp_Final =num2Str(a_Amplitude[G_mininumber])
	SAmp_Final =RemoveEnding (SAmp_Final, "e-"+stringfromlist(( itemsinlist(SAmp_Final,"-")-1),SAmp_Final,"-"))
	VAriable Corrected_AVG=round(Str2Num(SAmp_Final)*Str2Num(StringFromlist(1,Thsi_Unit)))
	SAmp_Final=Num2Str(Corrected_AVG)
	Align_by_dAdt(1)
	String Title_Valdisplay
	[G_Curr_Amp,Title_Valdisplay]=SuperRound(a_Amplitude[G_Mininumber])//trunc(a_Amplitude[G_Mininumber]*1e12)
	ValDisplay Curr_amp,   Value= _Num:G_Curr_Amp, Title="Amplitude ("+Title_Valdisplay+"A):"//a_amplitude[G_mininumber]
	
	[G_Curr_Decay,Title_Valdisplay]=SuperRound(a_decaytime[G_Mininumber])
	ValDisplay Curr_Decay,   Value= _Num:G_Curr_Decay, Title="Decay ("+Title_Valdisplay+"s):"
	
End

// 19 ******************************************************************************************************
//Returns time unit
Function /S Unity_Time(Pnt_num)

	Variable Pnt_Num
	Wave a_Decaytime
	Variable Pnt=a_Decaytime[Pnt_Num]
	String Unit
	If (Pnt<1 && Pnt>=0.001)
		Unit=Num2Str(Pnt*1000)+" ms"
	Endif
	If (Pnt<0.001 && Pnt>=0.000001)
		Unit=Num2Str(Pnt*1000000)+" us"
	Endif
	IF (Strlen(Unit)>0)
		Return Unit
	Else
		Return "??"
	Endif
End

// 20******************************************************************************************************

///--------------------------- This part of the Function is intended to highlight the markers in the miniature graph-----------
//-------------------------------------whenever you click them at the "Amplitudes" tab in the ----------------------------
// ---------------------------------------------------"Analysis_minis" window----------------------------------------

//Hook functin is used to tell the mouse position and its location when clicked.
Function Hook(s)

	STRUCT WMWinHookStruct &s
	String Wave_Name
	ControlInfo /W=Analysis_Minis Which_Wave
	Wave_Name="Only:"+S_Value
	String Wv_Name=S_Value
	Variable State= getkeystate(0) //Is Shift pressed?
	getwindow Analysis_Minis#Data_Display activesw
	if (StringMatch(S_Value, "*Deconv"))
			return 0
	endif
	switch(s.eventCode)
	case 5: // Mouseclick	
		Getmouse /w=Analysis_Minis#Data_Display
		if (V_left<530 && V_Top<400 && V_left>0 && V_Top>0)
			If (State==4) //yes, shift's pressed
				 Force_EPSC(Wv_Name, Str2Num( stringbykey( "HITPOINT",tracefrompixel (V_left+340, V_Top+36, Wave_name))))
			endif			
			if (strlen(tracefrompixel (V_left+340, V_Top+36,"Window:Analysis_Minis#Data_Display;Only:Amps"))>0)
				Modify_Point(STR2NUM( stringbykey( "HITPOINT",tracefrompixel (V_left+340, V_Top+36, "only:Amps"))),1)		
			endif
		endif
	break
	endswitch

End

// 21 ******************************************************************************************************
// Modifies the color of the marker to highligh a specific one in the graph display
Function Modify_Point(Point_x,Set_Mod)

	Variable Point_x, Set_Mod
	Svar /sdfr=root:Analysis_Parameters Host_Datafolder
	Variable Different_DF
	if (stringmatch(Host_Datafolder,Getdatafolder(1))!=1) //if user is in a different datafolder than that of the analysis
		DFREF This_DF = GetDataFolderDFR() //get the current DF address
		execute "Setdatafolder "+Host_Datafolder //sets analysis DF
		Different_DF=1 
	endif	
	make/o/n=(1,3) /t W_WaveList=""
	getwindow Analysis_Minis#Data_Display wavelist
	if (strlen(W_WaveList[0][1])==0 || numtype(strlen(W_WaveList[0][1]))==2)
		return 0
	endif
	wave Amps, Minis, All_Baseline_Vals, All_Decay_time, Start_Fit
	Variable Selected_Point=Point_x
	NVar /sdfr=root:Analysis_Parameters Highlighted_Point, G_miniNumber
	Setactivesubwindow Analysis_Minis#Data_Display
	Wave Amps
	ModifyGraph /W=Analysis_Minis#Data_Display rgb(Amps[Highlighted_Point])=(0,0,52224)
	ModifyGraph  /W=Analysis_Minis#Data_Display rgb(Amps[Selected_Point])=(65280,0,0)
	Highlighted_Point=Selected_Point
	G_Mininumber=Selected_Point
	Slide_Graph(Selected_Point)	
	If (Set_Mod==1)	
		PressNext("Modify_Point")
	EndIf
	if (Different_DF)
		Setdatafolder This_DF //back to previous DF
	endif
	doupdate
end

// 22 ******************************************************************************************************

Function Slide_Graph(Selected_Point)

	Variable Selected_Point
	Variable Start, Finish, Delta
	Wave a_Timestamp
	String Axis_Data= axisinfo ("Analysis_Minis#Data_Display", "Bottom")
	String Axis_Range, Comm2, Axis_Name, Pt1, Pt2, Pt1a, Pt2a	
	Axis_Range= stringbykey("SETAXISCMD",Axis_Data,":",";")
	String expr="([[:alpha:]]+) ([[:alpha:]]+) ([[:digit:]]+).([[:digit:]]+),([[:digit:]]+).([[:digit:]]+)"
	SplitString/E=(expr) Axis_Range, Comm2, Axis_Name, Pt1, Pt1a, Pt2,Pt2a
	Pt1+="."+Pt1a
	Pt2+="."+Pt2a	
	Start=Str2num(Pt1)
	Finish=Str2Num(Pt2)
	Delta=(Finish-Start)/10
	If (a_Timestamp[Selected_Point]>Finish || a_Timestamp[Selected_Point]<Start)
		SetAxis  /W=Analysis_Minis#Data_Display bottom (a_Timestamp[Selected_Point]-Delta),(a_Timestamp[Selected_Point]+Finish-Start-Delta)
	Endif

End

// 23 ******************************************************************************************************
//I forgot what it does....
function Display_and_Modify()

	Variable /g ROOT:Analysis_Parameters:Highlighted_Point
	Setwindow Analysis_Minis, hook(WMWinHookStruct)=hook, hookevents=0
	Setactivesubwindow Analysis_Minis#Data_Display

end

// 24 ******************************************************************************************************
// Adds the manually-chosen EPSC to the array 
Function Force_EPSC(Wave_name, EPSC_Ref_Pnt)

	String Wave_Name
	Variable EPSC_Ref_Pnt
	Variable i, EPSC_Num,eightypercent, twentypercent, amplitude, decaytime,twentypn, peakpn, baseline, peak, PeaKVal, PeakLocation,PeakLocation_Row
	Wave a_timestamp, Minis, A_amplitude, Amps,a_Baseline,All_Baseline_Vals,a_Risetime,a_Charge,a_Decaytime, Start_Fit, All_Decay_time, RiseTime_Xs
	NVar /sdfr=root:Analysis_Parameters G_Baseline, G_Mini_Size,G_Decay_Time//, G_mini_Number	
	Wave temp=$Wave_Name
	findlevel /q a_timestamp, pnt2x(temp, EPSC_Ref_Pnt)
	if (numtype(V_Levelx)!=2 && V_Levelx>0)
		EPSC_Num=ceil(V_Levelx) //defines where the new PSC will be added
	else
		EPSC_Num=0
	endif
	Wavestats /q /r=[EPSC_Ref_Pnt-G_Baseline, EPSC_Ref_Pnt+G_Mini_Size] temp //stats on the wave portion containing the putative EPSC
	ControlInfo /W=Analysis_Minis Positive
	If (V_value==0)
		PeakVal=V_min
		PeakLocation=V_minloc
		PeakLocation_Row=V_minrowloc
		if (Detect_Mini(EPSC_Num, temp, mEPSC, G_Mini_Size, V_Minloc,1)==0) //checks if it is within the PSC specs
			return 0
		endif
	Else
		PeakVal=V_max
		PeakLocation=V_maxloc
		PeakLocation_Row=V_maxrowloc
		if (Detect_Mini(EPSC_Num, temp, mEPSC, G_Mini_Size, V_maxloc,1)==0) //checks if it is within the PSC specs
			return 0
		endif
	EndIF	
	
	if (waveexists(Start_Fit)==0)
		Make /n=1 Start_Fit
	endif
	if (waveexists(Minis)==0)
		Make/o /n=(G_Mini_Size) Minis
	endif
	if (waveexists(All_Baseline_Vals)==0)
		Make/o /n=10 All_Baseline_Vals
	endif
	if (waveexists(All_Decay_time)==0)
		Make/o /n=(ceil(G_Mini_size/3)) All_Decay_time
	endif
	if (waveexists(a_timestamp)==0)
		Make /n=1 a_timestamp
	endif
	if (waveexists(Amps)==0)
		Make /n=1 Amps
	endif
	if (waveexists(a_Baseline)==0)
		Make /n=1 a_Baseline
	endif
	if (waveexists(A_amplitude)==0)
		Make /n=1 A_amplitude
	endif
	if (waveexists(a_Charge)==0)
		Make /n=1 a_Risetime
	endif

	//Event found, add it to all the other waves:
	Insertpoints EPSC_Num,1, a_timestamp,Amps,a_Baseline,A_amplitude,a_Risetime,a_Charge,a_Decaytime, Start_Fit
	Insertpoints /M=1 EPSC_Num,1, All_Decay_time	
	
	a_timestamp[EPSC_Num]=PeakLocation
	//a_Threshold[EPSC_num]=0//figure out what to do to calculate threshold here!
	Amps[EPSC_Num]=PeakVal
	a_Baseline[EPSC_Num]=Mean(Temp,(PeakLocation-G_Baseline*deltax(Temp)), (PeakLocation-(G_Baseline-10)*deltax(Temp)))
	A_amplitude[EPSC_Num]=Amps[EPSC_Num]-a_Baseline[EPSC_Num]
	Minis[][EPSC_Num]=Temp[p+(PeakLocation_Row-G_Baseline)]
	
	All_Baseline_Vals[][EPSC_Num]=Mean(Temp,(PeakLocation-G_Baseline*deltax(Temp)), (PeakLocation-(G_Baseline-10)*deltax(Temp)))
	Variable Ref_Decay=PeakLocation_Row-G_Baseline
	//Charge
	Duplicate /O /R=[PeakLocation_Row-G_Baseline, PeakLocation_Row-G_Baseline+G_Mini_Size] Temp C_Wana
	a_Charge[EPSC_Num]= charge(EPSC_Num,C_Wana)
	//Risetime
	Amplitude=PeakVal- a_Baseline[EPSC_Num]
	peakpn=PeakLocation_Row
	twentypercent = amplitude * 0.2 + a_Baseline[EPSC_Num]
	eightypercent = amplitude * 0.8 + a_Baseline[EPSC_Num]
	findlevel   /Q /R=[PeakLocation_Row-G_Baseline,peakpn] Temp, twentypercent 
	twentypn=V_LevelX
	findlevel /Q /R=[PeakLocation_Row-G_Baseline, peakpn] Temp, eightypercent 
	a_Risetime[EPSC_Num]= (V_LevelX - twentypn)	
	Risetime_Xs[EPSC_Num][q]={{x2pnt(Temp,twentypn)},{x2pnt(Temp,V_LevelX)}}
	//Decaytime
	make /O /N=3 W_coef
	Make /O /N=1 W_fitConstants
	twentypercent = peakval - (amplitude * 0.2)
	eightypercent = peakval - amplitude * 0.8
	findlevel /q /R=[peakpn, peakpn+G_Mini_Size*2] Temp, twentypercent
	twentypn=V_Levelx
	findlevel /q /R=[peakpn, peakpn+G_Mini_Size*2] Temp, eightypercent 
	
	CurveFit/Q /NTHR=0 /N /W=2 exp_XOffset  Temp[X2Pnt(Temp,twentypn), X2Pnt(Temp,V_LevelX)] /D /NWOK		
	
	All_Decay_time[][EPSC_Num]=W_coef[0]+W_coef[1]*exp(-(((p+X2Pnt(Temp,twentypn))*Deltax(Temp))-W_fitConstants[0])/W_coef[2])
	Start_Fit[EPSC_Num]=X2Pnt(Temp,twentypn)-Ref_Decay
	a_Decaytime[EPSC_Num]= W_coef(2)
	Wave_name="Fit_"+Wave_name
	removefromgraph /Z /W=Analysis_Minis#Data_Display $Wave_name	
	
	Make_AVG_PSC("Force") //Averages and displays the average PSCs		
	String Final= Update_Output_Text()
	TitleBox  Results Win=Analysis_Minis, Title=Final
	PressNext("Force") //Displays the detected event in the Analysis tab

end
// /////////// ------------End of the "Highlight Point" part --------------// ///////////

// ///////////-------------Panel interface management--------------////////////////
// 25 - Builds the GUI
Function Minicontroller(Type_of_Experiment) : Panel

	String Type_of_Experiment
	PauseUpdate; Silent 1		// building window...
	Dowindow /K Analysis_Minis
	NewPanel/K=1 /W=(500,576,1400,1176) /N=Analysis_Minis
	vars(Type_of_Experiment) //Initializes the variables to their default values
	SetDrawLayer /w=Analysis_Minis UserBack
	DrawRect /W=Analysis_Minis 10,36,310,350
	DrawRect /W=Analysis_Minis 10,360,310,420
	DIsplay /Host=Analysis_minis /W=(10,36,170,240) /n=Mini_Wave /Hide=1
	Modifygraph /W=Analysis_Minis#Mini_Wave Frameinset=1, Framestyle=4	
	Display /Host = Analysis_Minis /Hide=0 /N=Data_Display /W=(340,36,880,470)
	Display /Host = Analysis_Minis /N=EPSC_Temp /W=(20,46,250,200) /Hide=1
	if (waveexists(EPSC_Template)!=1)
		make/o/n=1 EPSC_Template=0 //needs this mock wave to run everything
	endif
	Appendtograph EPSC_Template
	ModifyGraph nticks=0,noLabel=2
	ModifyGraph axOffset(left)=-5,axOffset(bottom)=-2
	Modifygraph /W=Analysis_Minis#EPSC_Temp Frameinset=1, Framestyle=4	
	Modifygraph /W=Analysis_Minis#Data_Display Frameinset=1, Framestyle=4
	display /host=Analysis_Minis /N=Deconv /W=(300,46,870,500) /hide=1
	Tab_Display(0,1,1) //hides or shows elements in each tab
	Tabcontrol Main, Size={880,550},pos={5,0}
	Tabcontrol Main, tablabel(1) ="Analyze", proc=Tab_Mngt
	Tabcontrol Main, tablabel(0) ="Detect", proc=Tab_Mngt
	Tabcontrol Main, tablabel(2) ="Deconvolution", proc=Tab_Mngt
	Update_An_Params_Wave_or_Vals(2)
//	Set_Ana_PArams(0) //Loads the analysis parameters

end

// 26 ******************************************************************************************************
//Deals with the graphic aspect of the tabs - rectangles and drawing environments
Function Tab_Mngt(tab):Tabcontrol

	Struct WMTabControlAction &tab
 	SetDrawLayer /K UserBack
 	NVar /sdfr=root:Analysis_Parameters G_Mininumber
	Switch (tab.tab)
		Case 0:
			SetDrawLayer/w=Analysis_Minis /K Overlay
			SetDrawLayer/w=Analysis_Minis /K UserBack
			SetDrawLayer /w=Analysis_Minis UserBack
			DrawRect /W=Analysis_Minis 10,36,310,350
			DrawRect /W=Analysis_Minis 10,360,310,420
			Tab_Display(0,1,1)
		break
		Case 1:
			SetDrawLayer/w=Analysis_Minis /K Overlay
			SetDrawLayer/w=Analysis_Minis /K UserBack
			SetDrawLayer /w=Analysis_Minis UserBack
			DrawRect /W=Analysis_Minis 10,36,310,240
			Tab_Display(1,0,1)
			Modify_point(G_mininumber,1)
		break
		Case 2:
			SetDrawLayer/w=Analysis_Minis /K Overlay
			SetDrawLayer/w=Analysis_Minis /K UserBack
			SetDrawLayer /w=Analysis_Minis UserBack
			Drawline /W=Analysis_Minis 20,265,280,265
			Drawline /W=Analysis_Minis 20,400,280,400
			Tab_Display(1,1,0)
			SetVariable 		setdecaylow, 	Disable=0, pos={22,215}//
			SetVariable 		setdecayhigh,	Disable=0, pos={22,240}
			Checkbox 			Use_Template, 	Disable=0, pos={170,215}
		break
	endswitch

end

// 27 ******************************************************************************************************
//Deals with the tabs and their elements - hide and show
Function Tab_Display(Hide_Display, Hide_Analyse, Hide_Deconv)	//1=hide

	Variable Hide_Display
	Variable Hide_Analyse
	Variable Hide_Deconv
	Svar /sdfr=root:Analysis_Parameters Host_Datafolder
	Wave /t /z Results
 	Button 			isolate, 						Disable=Hide_Display
	Button 			Select_Waves, 				Disable=Hide_Display
	SetVariable 		setvar1, 						Disable=Hide_Display
	SetVariable 		signalwindow, 				Disable=Hide_Display
	SetVariable 		noisewindow, 				Disable=Hide_Display
	SetVariable 		stepsize, 					Disable=Hide_Display
	SetVariable 		jump, 							Disable=Hide_Display
	SetVariable 		Size, 							Disable=Hide_Display
	SetVariable 		Decay, 						Disable=Hide_Display
	SetVariable 		Baseline, 					Disable=Hide_Display
	SetVariable 		Tolerance,					Disable=Hide_Display
	Button 			killallresults, 			Disable=Hide_Display
	If (Hide_Display!=1)
		SetVariable 		Which_Wave, 				Disable=2//Hide_Controls
	Else
		SetVariable 		Which_Wave, 				Disable=Hide_Display
	Endif
	titlebox 			Select_Wave, 				Disable=Hide_Display
	TitleBox  		Results, 						Disable=Hide_Display
	Button 			Create_EPSC_Template, 	Disable=Hide_Display
	Button 			Display_Wave, 				Disable=Hide_Display
	SetVariable 		setdecaylow, 				Disable=Hide_Display, pos={22,365}
	SetVariable 		setdecayhigh, 				Disable=Hide_Display, pos={22,390}
	titlebox 			Create_EPSC, 				Disable=Hide_Display
	CheckBox 			Positive, 					Disable=Hide_Display
	Checkbox 			Use_Template, 				Disable=Hide_Display, pos= {23,320}
	Popupmenu 		An_Params_Handling,		Disable=Hide_Display
	If (numtype(Strlen(Results[0][0]))!=2 && Stringmatch(Results[0][0], "No Waves Selected")!=1)
		ValDisplay 	signalwindow_Val, 			Disable=Hide_Display
		ValDisplay 	noisewindow_Val, 			Disable=Hide_Display
		ValDisplay 	stepsize_Val, 				Disable=Hide_Display
		ValDisplay 	jump_Val, 					Disable=Hide_Display
		ValDisplay 	setvar1_Val, 				Disable=Hide_Display
		ValDisplay 	Size_Val, 					Disable=Hide_Display
		Valdisplay 	Baseline_Val, 				Disable=Hide_Display
		ValDisplay 	Decay_Val, 					Disable=Hide_Display
	endif
	Variable enable=Hide_Deconv==0?1:0
	if (enable==0)
		Setactivesubwindow Analysis_Minis#Data_Display
	endif
	Setwindow Analysis_Minis#Data_Display 	hide=Enable
	Button FWD_x, 									Disable=Enable
	Button BACK_x, 									Disable=Enable
	Button Grow_x, 									Disable=Enable
	Button Shrink_x, 								Disable=Enable
	Button Reset_x, 								Disable=Enable
	Button FWD_y, 									Disable=Enable
	Button BACK_y,  								Disable=Enable
	Button Grow_y, 									Disable=Enable
	Button Shrink_y, 								Disable=Enable
	Button Reset_y,									Disable=Enable
	Button Reset_ALL, 								Disable=Enable
	Setwindow 	Analysis_Minis#Mini_Wave 	hide=Hide_Analyse
	Button 		pressnext,						Disable=Hide_Analyse
	Button 		pressprevious, 					Disable=Hide_Analyse
	Button 		plot, 								Disable=Hide_Analyse
	Button 		AVG_PSC, 							Disable=Hide_Analyse
	Button 		Delete, 							Disable=Hide_Analyse
	Titlebox 		Bin_Size, 						Disable=Hide_Analyse
	Titlebox 		Num_Bins, 						Disable=Hide_Analyse
	SetVariable G_mininum,				Value=root:Analysis_Parameters:G_mininumber,			Disable=Hide_Analyse
	ValDisplay Curr_amp,							Disable=Hide_Analyse
	ValDisplay Curr_Decay,						Disable=Hide_Analyse
	Setvariable Hist_Bin_Freq, 			Value=root:Analysis_Parameters:G_Bin_Size_Freq,		Disable=Hide_Analyse
	Setvariable Num_Bins_Freq, 			Value=root:Analysis_Parameters:G_Num_BIn_Freq,		Disable=Hide_Analyse
	Setvariable Hist_Bin_Amp, 			Value=root:Analysis_Parameters:G_Bin_Size_Amp,		Disable=Hide_Analyse
	Setvariable Num_Bins_Amp, 			Value=root:Analysis_Parameters:G_Num_BIn_Amp,			Disable=Hide_Analyse	
	Setvariable Hist_Bin_Charge, 		Value=root:Analysis_Parameters:G_Bin_Size_Char,		Disable=Hide_Analyse
	Setvariable Num_Bins_Charge, 		Value=root:Analysis_Parameters:G_Num_BIn_Char,		Disable=Hide_Analyse
	Setvariable Hist_Bin_Rise,			Value=root:Analysis_Parameters:G_Bin_Size_Rise,		Disable=Hide_Analyse
	Setvariable Num_Bins_Rise,			Value=root:Analysis_Parameters:G_Num_BIn_Rise,		Disable=Hide_Analyse	
	Setvariable Hist_Bin_Decay,			Value=root:Analysis_Parameters:G_Bin_Size_Decay,		Disable=Hide_Analyse
	Setvariable Num_Bins_Decay,			Value=root:Analysis_Parameters:G_Num_BIn_Decay,		Disable=Hide_Analyse
	if (Hide_Deconv==0)
		Setactivesubwindow Analysis_Minis#Deconv
	endif
	Setwindow Analysis_Minis#EPSC_Temp 			hide=Hide_Deconv
	Setwindow Analysis_Minis#Deconv	 			hide=Hide_Deconv
	Titlebox Filter1, 								Disable=Hide_Deconv
	Titlebox Filter2, 								Disable=Hide_Deconv
	SetVariable Filter1_Low, 					Disable=Hide_Deconv
	SetVariable Filter1_High,					Disable=Hide_Deconv
	SetVariable Filter2_Low, 					Disable=Hide_Deconv
	SetVariable Filter2_High, 					Disable=Hide_Deconv
	Button Run_Deconv, 							Disable=Hide_Deconv
	if (waveexists(Deconvolved) || Hide_Deconv==1)
		Button Rerun_Peak_Dec,					Disable=Hide_Deconv
		else
		Button Rerun_Peak_Dec,					Disable=2
	endif
	Button Filter_by_Deconv,						Disable=Hide_Deconv
	Checkbox F1, 									Disable=Hide_Deconv
	Checkbox F2, 									Disable=Hide_Deconv
	SetVariable Threshold_dec, 					Disable=Hide_Deconv
	SetVariable Jump_dec,							Disable=Hide_Deconv
	SetVariable Noise_dec, 						Disable=Hide_Deconv
	SetVariable Step_dec, 						Disable=Hide_Deconv
	TitleBox  /Z Dec_Num_evts, 					Disable=Hide_Deconv
	Popupmenu Deconvolution_Action,			Disable=Hide_Deconv
	
end

// 28******************************************************************************************************
// Displays trace and individual markers in the graph
Function DIsplay_mini_Graph()

	Wave a_Baseline,a_amplitude
	Wave Amps_Time=a_timestamp
	pauseupdate	
	wave /t /z Results
	if (waveexists(Results)) //retrieves the analyzed wave name and stores it in the "which_wave" variable display in the main window
		Execute "SetVariable Which_Wave, Value=_Str:"+num2char(34)+Results[0][0]+num2char(34)
	endif
	ControlInfo /W=Analysis_Minis Which_Wave
	Wave /z Test=$S_Value
	if (Strlen(S_Value)==0 || Stringmatch(S_Value, "No Waves Selected")==1)
		beep
		Print "********************************* No Waves seleced for analysis. Choose wisely. *********************************"
		abort
	endif
	String cmd
	removefromgraph /z /W=Analysis_Minis#Data_Display Test
	Execute "AppendToGraph /W=Analysis_Minis#Data_Display "+S_Value  // This command needs "execute" or it'll return an error when running
	Execute "ModifyGraph /W=Analysis_Minis#Data_Display rgb("+S_Value+")=(0,0,0)" // This command needs "execute" or it'll return an error when running
	if (waveexists(a_amplitude) && waveexists(Amps_Time))
		Duplicate/o a_Amplitude, Amps
		ControlINfo /W=Analysis_minis Positive
		If (V_Value==0)
			Amps+=a_Baseline
		Else
			Amps=a_Baseline-a_Amplitude
		EndIf
		removefromgraph /z /W=Analysis_Minis#Data_Display Amps
		AppendToGraph/W=Analysis_Minis#Data_Display Amps vs Amps_Time
		ModifyGraph /W=Analysis_Minis#Data_Display mode(Amps)=3,rgb(Amps)=(0,0,52224),marker(Amps)=19
	endif
	doupdate
	
end

// 29 ******************************************************************************************************
//Creates an outside box to enable wave selection - see MakeListIntoWaveSelector
Function WaveSelectorPanel(CtrlName)

	String CtrlName
	Dowindow/K What_to_do
	Variable showWhat=1
	String panelName = "WaveSelector"
	Variable Button_Offset
	if (WinType(panelName) == 7)
		DoWindow/F $panelName
	else
		NewPanel/K=1/N=$panelName/W=(180,180,450,540) as "Selector"
		ListBox WaveSelectorList,pos={10,13},size={250,220}
		// This function (MakeListIntoWaveSelector) does all the work of making the listbox control into a Wave Selector widget. It calls an Igor Pro Built in ipf file
		Button Cancel_Load,pos={150,330-Button_Offset},size={110,20},title="Cancel", Proc=Instructions_Handling//Cancel_select	
		Strswitch (Ctrlname)
			Case "Existing":
		//If (Stringmatch(CtrlName, "Existing")==1)	
				MakeListIntoWaveSelector(panelName, "WaveSelectorList", content = WMWS_DataFolders)//showWhat)
				PopupMenu sortKind, pos={155,240}, Size={20,35}, title="Sort By"
				MakePopupIntoWaveSelectorSort(panelName, "WaveSelectorList", "sortKind")	
				Button Existing_Exp,pos={9,330-Button_Offset},size={110,20},title="Done", Proc=Instructions_Handling
				Break
		//else		
			Case "Select_Waves":
				MakeListIntoWaveSelector(panelName, "WaveSelectorList", content = showWhat)
				PopupMenu sortKind, pos={155,240}, Size={20,35}, title="Sort Waves By"
				MakePopupIntoWaveSelectorSort(panelName, "WaveSelectorList", "sortKind")	
				Button Done,pos={9,330-Button_Offset},size={110,20},title="Done", Proc=Instructions_Handling
				SetVariable Output_wave_name,  Disable=2, pos={210,290}, Bodywidth=250,  FSize=16, Title=" ", Value=_Str:"Conc_Pulse"
				CheckBox Enable_output_Name_Change, Pos={10,270}, Title="Custom output wave name: ", Value=0, Fsize=12, proc=Enable_Input_WaveName
				Break
			Case "Copy":
				MakeListIntoWaveSelector(panelName, "WaveSelectorList", content = WMWS_DataFolders)//showWhat)
				PopupMenu sortKind, pos={155,240}, Size={20,35}, title="Sort By"
				MakePopupIntoWaveSelectorSort(panelName, "WaveSelectorList", "sortKind")	
				Button Copy_Params,pos={9,330-Button_Offset},size={110,20},title="Done", Proc=Instructions_Handling
				Break
		//Endif
		EndSwitch	
	endif
	
End

// 30******************************************************************************************************
// Deals witht the Checkbos in the wave selector window
Function Enable_Input_WaveName(CtrlName, Check):CheckBoxControl

	String CtrlName
	Variable  Check
	If (Check==1)
		SetVariable Output_wave_name Win=WaveSelector, Disable=0
	Else
		SetVariable Output_wave_name Win=WaveSelector, Disable=2, Value=_Str:"Conc_Pulse"
	EndIf

end

// 31******************************************************************************************************
// Specifies all the elements in the tabs in the main window
Function vars(Type_of_Experiment)

	String Type_of_Experiment
	String Current_Folder
	Wave/z /t Results
	if (waveexists(Results)==0)
		Make/o/t/n=(7,3) Results
		Results[0][0]="No Waves Selected"
	elseif (strlen(Results[0][0])<=2)
		Results[0][0]="No Waves Selected"
	endif
	Current_Folder = getdatafolder(1)
	Nvar /sdfr=root:Analysis_Parameters G_mininumber
	Variable H_Pos_An_panel, V_Pos_An_Panel
	wave /z a_amplitude, a_DecayTime
	titlebox Version_num, pos={820,5},frame=0,title= "Version 3.4.1", Fsize=12
	CheckBox Positive,			Pos={20,260},Title="Detect Positive Peaks", VAlue=0,proc=I_template
	Checkbox Use_Template, 	pos= {23,320}, Title="Use data template", value=0, proc=I_template
	Button Select_Waves,pos={20,285},size={120,25}, fColor=(16385,49025,65535), fStyle=1, FSize=16,proc= Instructions_Handling,title="Select Waves"//, Fsize=18
	SetVariable Which_Wave,pos={60,440}, Bodywidth=300, Frame=0,  Size={250,40}, FSize=16, Title=" ",BarBackColor=0, Disable=2
	Execute "SetVariable Which_Wave, Value=_Str:"+num2char(34)+Results[0][0]+num2char(34)
	Button isolate,pos={176,285},size={120,20},title="Isolate minis",proc=Instructions_Handling//pressisolate
	Button isolate,help={"starts isolation function according to set parameters"}, Disable=1
	Button killallresults,pos={176,315},size={120,20},title="Kill all results",fColor=(65535,16385,16385), Disable=1,proc=Instructions_Handling//presskillall
	Button killallresults,help={"!!!Kills all results in the \"mini\" folder!!!"}
	H_Pos_An_panel=10	
	SetVariable setvar1,pos={H_Pos_An_panel+50,76},size={120,15},title="Threshold (Amps)", Bodywidth=70, labelBack=(65535,65535,65535),limits={-inf,inf,-1e-12},value= root:Analysis_Parameters:G_threshold,  proc=Set_Value, Disable=1
		ValDisplay setvar1_Val,pos={210,76},Title="= (pA)",  Bodywidth=40, Frame=0, Disable=1
	SetVariable signalwindow,pos={H_Pos_An_panel+50,99},size={120,15},title="Signal win  (pts)  ", proc=Set_Value, BodyWidth=70, value= root:Analysis_Parameters:G_signalwindow,  labelBack=(65535,65535,65535), Disable=1
		ValDisplay signalwindow_Val,pos={210,99},Title="= (ms)",  Bodywidth=40, Frame=0, Disable=1
	SetVariable noisewindow,pos={H_Pos_An_panel+50,122},size={120,15},title="Noise win  (pts)   ",value= root:Analysis_Parameters:G_noisewindow,  labelBack=(65535,65535,65535), proc=Set_Value, BodyWidth=70, Disable=1
		ValDisplay noisewindow_Val,pos={210,122},Title="= (ms)",  Bodywidth=40, Frame=0, Disable=1
	SetVariable stepsize,pos={H_Pos_An_panel+50,145},size={120,15},title="Step size (pts)    ",value= root:Analysis_Parameters:G_stepsize, labelBack=(65535,65535,65535), proc=Set_Value, BodyWidth=70, Disable=1
		ValDisplay stepsize_Val,pos={210,145},Title="= (ms)",  Bodywidth=40, Frame=0, Disable=1
	SetVariable jump,pos={H_Pos_An_panel+50,168},size={120,15},title="Jump (pts)          ",value= root:Analysis_Parameters:G_jump, labelBack=(65535,65535,65535), proc=Set_Value, BodyWidth=70, Disable=1
		ValDisplay jump_Val,pos={210,168},Title="= (ms)",  Bodywidth=40, Frame=0, Disable=1
	SetVariable Size,pos={H_Pos_An_panel+50,191},size={120,15},title="EPSC size (pts)    ",value=root:Analysis_Parameters:G_Mini_Size, labelBack=(65535,65535,65535), proc=Set_Value, BodyWidth=70, Disable=1
		ValDisplay Size_Val,pos={210,191},Title="= (ms)",  Bodywidth=40, Frame=0, Disable=1
	SetVariable Decay,pos={H_Pos_An_panel+50,237},size={120,15},title="Decay time(pts)  ",value= root:Analysis_Parameters:G_Decay_time, labelBack=(65535,65535,65535), proc=Set_Value, BodyWidth=70, Disable=1
		ValDisplay Decay_Val,pos={210,237},Title="= (ms)",  Bodywidth=40, Frame=0, Disable=1
	SetVariable Baseline,pos={H_Pos_An_panel+50,214},size={120,15},title="Baseline (pts)      ",value= root:Analysis_Parameters:G_Baseline, labelBack=(65535,65535,65535), proc=Set_Value, BodyWidth=70, Disable=1
		ValDisplay Baseline_Val,pos={210,214},Title="= (ms)",  Bodywidth=40, Frame=0, Disable=1		
	SetVariable Tolerance, pos={176,260},size={120,20},title="Tolerance",value=root:Analysis_Parameters:G_Tolerance, labelBack=(65535,65535,65535), proc=Set_Value, BodyWidth=70, limits={0.1,1,0.05}, Disable=1
	
	Button pressnext,		pos={245,40},size={60,25},Fsize=16, title="Next",help={"shows next mini"}, Disable=1, 			proc=Instructions_Handling
	Button pressprevious,	pos={175,40},size={60,25},FSize=16, title="Prev",help={"shows previous mini"}, Disable=1, 	proc=Instructions_Handling
	Button delete,pos={175,67},size={130,25},FSize=16, title="Delete mini",help={"deletes mEPSC number set in the left panel"}, Disable=1,proc=Instructions_Handling//pressdelete
	SetVariable G_mininum,pos={175,94},size={130,25},title="PSC #",fSize=16,value=G_Curr_Amp, Disable=1, Proc=EPSC_Num, Limits={0,10000,1}
		ValDisplay Curr_amp,   pos={253, 160}, Title="Amplitude (pA): ", Bodywidth=40, Frame=0, Disable=1
		ValDisplay Curr_Decay, pos={227, 180}, Title="Decay (ms): ",     Bodywidth=40, Frame=0, Disable=1
	titlebox Create_EPSC, pos={170,370},frame=0,title= "Display EPSC Template", Fsize=12, Disable=1
	Button Create_EPSC_Template,pos={196,387},size={80,30},title="GO", Fsize=16, Proc=Instructions_Handling//Display_EPSC_Template
	Button Create_EPSC_Template,help={"rejects mEPSC, which do not pass filter criteria, and deletes parameters from all waves"}, Disable=1
	Button Display_Wave pos={155,430},size={150,30},title="Display Data Trace", Fsize=16, proc=Instructions_Handling

	SetVariable setdecaylow,pos={22,365},size={140,16},title="Rise Tau [s]   ",fSize=12,limits={-inf,inf,0.00001},value=root:Analysis_Parameters:G_Rise_Tau, Disable=1, proc=Set_Value
	SetVariable setdecayhigh,pos={22,390},size={140,16},title="Decay Tau [s]",fSize=12,limits={-inf,inf,0.00001},value= root:Analysis_Parameters:G_Decay_Tau, Disable=1, proc=Set_Value
	Popupmenu An_Params_Handling, mode=0, Size={120,40}, pos={20,42}, Title="Parameters", Fsize=16, Value="Load From File;Save to File;Copy from previous analysis;", DIsable=1, Proc=An_Params_Load_or_Save
	Button AVG_PSC,pos={175,125},size={130,30},proc=Instructions_Handling,title="Display PSC Average", Disable=1
	Button plot,pos={215,270},size={97,50},title="Plot \rhistograms",proc=Instructions_Handling
	Button plot,help={"plots all results in histograms"}, Disable=1
	H_Pos_An_panel=108
	V_Pos_An_Panel=270
	Titlebox Bin_Size, Fsize=14, Frame=0, Pos={90, V_Pos_An_Panel-20}, Title="Bin size", Disable=1
	Titlebox Num_Bins, FSize=14, Frame=0, Pos={165,V_Pos_An_Panel-20}, Title="# Bins", Disable=1
	Setvariable Hist_Bin_Freq, Pos={H_Pos_An_panel,V_Pos_An_Panel}, Size={50,20}, Title="Frequency ",fsize=12, bodywidth=80, Disable=1, Value=G_Bin_Size_Freq, proc=Set_Value
	Setvariable Num_Bins_Freq, Pos={H_Pos_An_panel+82,V_Pos_An_Panel}, Size={20,20}, Title=" ",fsize=12, bodywidth=50, Disable=1,Value=root:G_Num_BIn_Freq, proc=Set_Value
	Setvariable Hist_Bin_Amp, Pos={H_Pos_An_panel,V_Pos_An_Panel+25}, Size={50,20}, Title="Amplitude",fsize=12, bodywidth=80, Disable=1, Value=G_Bin_Size_Amp, proc=Set_Value
	Setvariable Num_Bins_Amp, Pos={H_Pos_An_panel+82,V_Pos_An_Panel+25}, Size={20,20}, Title=" ",fsize=12, bodywidth=50, Disable=1, Value=root:G_Num_BIn_Amp, proc=Set_Value
	Setvariable Hist_Bin_Charge, Pos={H_Pos_An_panel,V_Pos_An_Panel+25*2}, Size={50,20}, Title="Charge (C) ",fsize=12, bodywidth=80, Disable=1, Value=G_Bin_Size_Char, proc=Set_Value
	Setvariable Num_Bins_Charge, Pos={H_Pos_An_panel+82,V_Pos_An_Panel+25*2}, Size={20,20}, Title=" ",fsize=12, bodywidth=50, Disable=1, Value=root:G_Num_BIn_Char, proc=Set_Value
	Setvariable Hist_Bin_Rise, Pos={H_Pos_An_panel,V_Pos_An_Panel+25*3}, Size={50,20}, Title="Rise (s)   ",fsize=12, bodywidth=80, Disable=1, Value=G_Bin_Size_Rise, proc=Set_Value
	Setvariable Num_Bins_Rise, Pos={H_Pos_An_panel+82,V_Pos_An_Panel+25*3}, Size={20,20}, Title=" ",fsize=12, bodywidth=50, Disable=1, Value=root:G_Num_BIn_Rise, proc=Set_Value
	Setvariable Hist_Bin_Decay, Pos={H_Pos_An_panel,V_Pos_An_Panel+25*4}, Size={50,20}, Title="Decay (s)  ",fsize=12, bodywidth=80, Disable=1, Value=G_Bin_Size_Decay, proc=Set_Value
	Setvariable Num_Bins_Decay, Pos={H_Pos_An_panel+82,V_Pos_An_Panel+25*4}, Size={20,20}, Title=" ",fsize=12, bodywidth=50, Disable=1, Value=root:G_Num_BIn_Decay, proc=Set_Value
	Button FWD_x, Win=Analysis_Minis, pos={485,470},size={40,25},Title="\W549", proc=Axis_Range, Disable=0
	Button BACK_x, Win=Analysis_Minis, pos={445,470},size={40,25},Title="\W546", proc=Axis_Range, Disable=0
	Button Grow_x, Win=Analysis_Minis, pos={380,470},size={40,25},Title="\Z18+", proc=Axis_Range	, Disable=0
	Button Shrink_x, Win=Analysis_Minis, pos={340,470},size={40,25},Title="\Z18-", proc=Axis_Range, Disable=0
	Button Reset_x,Win=Analysis_Minis, pos={420,470},size={25,25},fColor=(65280,21760,0),Title="\Z16\f01®", proc=Axis_Range, Disable=0
	Button FWD_y, Win=Analysis_Minis, pos={315,285},size={25,40},Title="\W517", proc=Axis_Range, Disable=0
	Button BACK_y, Win=Analysis_Minis, pos={315,325},size={25,40},Title="\W523", proc=Axis_Range, Disable=0
	Button Grow_y, Win=Analysis_Minis, pos={315,390},size={25,40},Title="\Z18+", proc=Axis_Range, Disable=0
	Button Shrink_y, Win=Analysis_Minis, pos={315,430},size={25,40},Title="\Z18-", proc=Axis_Range, Disable=0
	Button Reset_y,Win=Analysis_Minis, pos={315,365},size={25,25},fColor=(65280,21760,0),Title="\Z16\f01®", proc=Axis_Range, Disable=0	
	Button Reset_ALL,Win=Analysis_Minis, pos={315,470},size={25,25},fColor=(52224,0,0),Title="\Z16\f01®", proc=Axis_Range, Disable=0
	Button New_Analysis, Win=Analysis_Minis, pos={5, 560}, Size={140,30}, FSize=18, Title="New analysis", proc=Instructions_Handling
	Button Existing, Win=Analysis_Minis, pos={175, 560}, Size={220,30}, FSize=18, Title="Go to existing analysis", proc=WaveSelectorPanel
	Button Cancel_it, Win=Analysis_Minis, pos={795, 560}, Size={90,30}, FSize=18, Title="Close", proc=Instructions_Handling
	//Deconvolution panel	
	Titlebox EPSC_template, FSize=16, Frame=0, Pos={20,30}, Title="EPSC template", Disable=1
	Titlebox Filter1, FSize=16, Frame=0, Pos={20,405}, Title="Signal filter", Disable=1
	CheckBox F1,			Pos={110,410}, VAlue=0, title=""
	Checkbox F1, help={"Sets the low pass filter for the data trace"}
	SetVariable Filter1_Low,pos={20,430},size={150,16},title="End pass band",fSize=12,limits={-inf,inf,0.00001},value=root:Analysis_Parameters:F1_Low, Disable=1, proc=Set_Value
	SetVariable Filter1_High,pos={20,460},size={150,16},title="Reject Band",fSize=12,limits={-inf,inf,0.00001},value= root:Analysis_Parameters:F1_High, proc=Set_Value	
	Titlebox Filter2, FSize=16, Frame=0, Pos={170,405}, Title="Deconv filter", Disable=1
	CheckBox F2			Pos={265,410}, VAlue=0, title=""	
	Checkbox F2, help={"Sets the low pass filter for the deconvolved trace"}
	SetVariable Filter2_Low,pos={200,430},size={80,16},title=" ",fSize=12,limits={-inf,inf,0.00001},value=root:Analysis_Parameters:F2_Low, Disable=1, proc=Set_Value
	SetVariable Filter2_High,pos={200,460},size={80,16},title=" ",fSize=12,limits={-inf,inf,0.00001},value= root:Analysis_Parameters:F2_High, proc=Set_Value
	Button Run_Deconv, pos={20,500}, Size={180,30}, Title="Run Deconvolution", fSize=16, disable=1, proc=Instructions_Handling
	Button Filter_by_Deconv, pos={350,500}, Size={100,30}, Title="Do it", fSize=16, disable=1, proc=Instructions_Handling//FIlter result by decovolutionDeconvolve
	PopUpMenu Deconvolution_Action pos = {220,493},size={180,130}, fSize=16, Value="--;Intersec;Combine;",Title = "Select\rAction"
	Nvar /SDFR=root:Analysis_Parameters Threshold_dec, Jump_dec, Noise_dec, Step_dec
	SetVariable Threshold_dec ,pos={20,275},size={150,16},title="Threshold",fSize=14, value=Threshold_dec, Disable=1
		Button Rerun_Peak_Dec, pos={180,275}, Size={100,50}, Title="Find Peaks\rOnly", fSize=16, disable=2, proc=Instructions_Handling
	SetVariable Jump_dec ,pos={20,305},size={150,16},title="Jump",fSize=14, value=Jump_dec, Disable=1, proc=Set_Value
	SetVariable Noise_dec ,pos={20,335},size={150,16},title="Noise",fSize=14, value=Noise_dec, Disable=1, proc=Set_Value
	SetVariable Step_dec ,pos={20,365},size={150,16},title="Step",fSize=14, value=Step_dec, Disable=1, proc=Set_Value
	StrSwitch (Type_of_Experiment) //if it is a new analysis, the lobal variables will be stored in the An_Params wave. If it is an existing one, 
											//the values of An_Params will be written to the Global vals
		Case "New_Exp":
			Update_An_Params_Wave_or_Vals(1)
			break
		Case "Existing_Exp":
			Update_An_Params_Wave_or_Vals(2)
			break
	Endswitch
end	


// 32 ******************************************************************************************************
// Makes a template out of the average PSCs already detected - not the best approach... needs work
Function I_template(CB_Struct) : CheckBoxControl //do not add  "Static" to this function!
	STRUCT WMCheckboxAction &CB_Struct
	if (CB_Struct.eventcode!=2 && strlen(CB_Struct.ctrlname)>0)
		return 0
	endif
	
	if (CB_Struct.checked==0)
		Display_EPSC_Template("void")
		return 0
	elseif(waveexists(AVG_d))
		if (waveexists(epsc_template))
			replacewave /w=Analysis_Minis#EPSC_Temp trace=epsc_template, avg_d
		else
			replacewave /w=Analysis_Minis#EPSC_Temp trace=avg_d, avg_d //this is a weird one. I did this because of a bug.
		endif
		return 0
	endif
	Variable Minimum, Maximum
	wave /z EPSC_Template, AVG_d
	if (waveexists(AVG_d)==0)
		If (stringmatch(CB_Struct.Ctrlname, "*Use_Template*"))
			print "*************************  No events selected for template  *************************"
		Endif
		Checkbox Use_Template win=Analysis_minis, value=0
		abort
	endif
	Duplicate/o AVG_d, EPSC_Template_ori
	Variable First_pnt=EPSC_Template_ori[0]
	EPSC_Template_Ori-=First_pnt
	Controlinfo /w=Analysis_minis Positive
	Minimum=Wavemin(EPSC_Template_Ori)
	Maximum=Wavemax(EPSC_Template_Ori)
	if (V_Value)
		EPSC_Template_Ori/=Maximum
	else
		EPSC_Template_Ori/=-Minimum
	endif
	Duplicate/o EPSC_Template_Ori,EPSC_Template
	killwaves /z EPSC_Template_Ori
end

// 33******************************************************************************************************
// Builds and displays the PSC template according to the values inserted in the main window
Function Display_EPSC_Template(CtrlName)//:Buttoncontrol
	
	String CtrlName
	NVar /sdfr=root:Analysis_Parameters G_Mini_Size, G_Rise_Tau, G_Decay_Tau
	Variable Minim, Absolute, scale
	Wave /Z EPSC_Template_ori, AVG_minis, AVG_d
	ControlINfo /W=Analysis_minis Positive
	Absolute=V_Value
	Controlinfo /w=Analysis_Minis Which_wave
	IF (Strlen(S_Value)==0)
		Print "**************** U MUST SELECT A WAVE FIRST! DO IT!****************"
		abort
	ENDIF
	Controlinfo /W=Analysis_Minis Use_Template
	if (V_Value)
		if (waveexists(AVG_d)==0 && waveexists(EPSC_Template_ori)==0)
			print "*****************   Template doesn't exist.   *****************" 
			return 0
		else
			if (waveexists(AVG_d))
				Duplicate/o AVG_d, EPSC_Template

			elseif(waveexists(EPSC_Template_ori))
				Duplicate/o EPSC_Template_ori, EPSC_Template
			endif
		endif
	else
		Controlinfo /w=Analysis_Minis Which_wave
		If (Absolute==0)
			make/o/n=(G_Mini_Size) epsc_Template= -1*  (1-exp(-(x*deltax($S_Value))/G_Rise_Tau))*  (exp(-(x*deltax($S_Value))/G_Decay_Tau))
		Else
			make/o/n=(G_Mini_Size) epsc_Template=  (1-exp(-(x*deltax($S_Value))/G_Rise_Tau))*  (exp(-(x*deltax($S_Value))/G_Decay_Tau))
		EndIF
	endif
	Controlinfo /w=Analysis_Minis Which_wave
	setscale /p x,0,deltax($S_Value),"s",EPSC_Template
	dowindow/k Template_and_AVG
	StrSwitch(CtrlName)
		Case"Create_EPSC_Template":
			Display_n_fit_AVG_PSC(absolute)
			break
		Case "void":
			if (waveexists(AVG_d) && Waveexists(EPSC_Template))
				replacewave /w=Analysis_Minis#EPSC_Temp trace=avg_d, EPSC_template
			endif
			break
			 
	endswitch
end

// 34******************************************************************************************************
// Retrieves and gives a proper name to the selected wave for analysis.
Function Done(CtrlName)

	String CtrlName
	Svar /sdfr=root:Analysis_Parameters Host_Datafolder
	Wave /t /z Results
	String panelName = "WaveSelector"
	String List=WS_SelectedObjectsList("WaveSelector","WaveSelectorList")
	String This_datafolder, DF_Waves
	
	 
	Variable i, Num_Pnts_Max, Wv_Index
	wave /z An_Params
	if (Stringmatch(Ctrlname, "Existing_Exp")==1) //If if i an existing analysis, the analyzed wave is retrieved alongside its results
		This_datafolder=Stringfromlist(0,list)
		Host_Datafolder=This_datafolder
		IF (Exists ("Host_DataFolder")==0)
			SetDatafolder This_datafolder
		Else
			SetdataFolder $Host_Datafolder
		Endif
		
		DF_Waves=sortlist(Wavelist("*",";",""),";",16)
		For (i=0;i<Itemsinlist(DF_Waves);i+=1)
			If(Numpnts($Stringfromlist(i,DF_Waves))>Num_Pnts_Max)
				Num_Pnts_Max=Numpnts($Stringfromlist(i,DF_Waves))
				Wv_Index=i
			Endif
		Endfor
		wave temp=$Stringfromlist(Wv_Index,DF_Waves)
		dowindow Analysis_Minis
		if (V_flag)
			Setvariable Which_Wave Win=Analysis_Minis , Value=_Str:Results[0][0]
		endif
		Minicontroller("Existing_Exp")
		Deconvolve(1) 
	Else //It's a new analysis and it's necessary to launch the waves selector window
		String List_Wv=Stringfromlist(0,list)
		This_datafolder=Removefromlist((Stringfromlist((itemsinlist(List_Wv,":")-1),List_Wv,":")), List_Wv,":")
		String Wv2P, Final_Destination, Dup_Final_Name
		Wave /z temp
		If (ItemsinList(List)==0)
			String /g Info="        Select at Least one wave from the list, my friend!         "
			newpanel /k=1 /n=Instructions /w=(300,200,800,350)
			Titlebox  TB1, Fsize=16, Frame=0, Anchor=LT, Pos={20,20}, Size={1,1}, Variable= Info
			Button My_Bad, Win=Instructions, Fsize=18, pos={140,85}, Size = {200,40}, Title="Oops, my bad!!", proc=Instructions_Handling//Cancel_select	
			Abort
		EndIf
		ControlInfo /W=WaveSelector Output_wave_name // The Wavename will be stored in this SetVariable field
		Results[0][0]=S_Value
		SetDataFolder $This_DataFolder
		If (Itemsinlist(List)>1) //Several waves selected to be concatenated
			For (i=0;I<itemsinlist(list);i+=1)		//concatenating them all...
				If (i==0)
					Wave W1= $Stringfromlist(0,list)
					Wave W2 = $Stringfromlist(1,list)
					Concatenate/NP /O {W1,W2}, Temp
					i+=1			
				Else
					Duplicate/O Temp, W1b	
					Wave W2 = $Stringfromlist(i,list)
					Concatenate/NP /O {W1b, W2}, Temp			
				EndIf	
			EndFor				
		Else
			Duplicate/O $Stringfromlist(0,list), Temp //Single wave selectd
		EndIf
		ControlInfo /W=WaveSelector Enable_Output_Name_CHange //Custom name for the wave?
		If (V_Value==0) //
			If (itemsinlist(list)==1)
				Results[0][0]=StringFromList((Itemsinlist(List,":")-1),Stringfromlist(0,list),":")//Removes the folders and subfolders from the string, leaving only the Wavename
			Else
				ControlInfo /W=WaveSelector Output_wave_name
				Results[0][0]=S_Value
			endif
		Endif	
		ControlInfo /W=WaveSelector Enable_Output_Name_CHange
		If (Waveexists($Results[0][0])==0) //Is there a wave with this name already? If yes, it'll be overwritten.
			Rename Temp, $Results[0][0]
		Else
			Duplicate/o Temp, $Results[0][0]
			Killwaves/z Temp //Do I need to kill it?
		EndIf
	//Wave's ready!	
		if (Stringmatch(This_DataFolder,Host_Datafolder)!=1) //the wave datafolder is different than that of the analysis
			Final_Destination=Host_Datafolder+Results[0][0]
			This_DataFolder+=Results[0][0]
			Dup_Final_Name=Results[0][0]+"2"
			Duplicate/o $Results[0][0], $Dup_Final_Name	
			If (Waveexists($Host_Datafolder+Results[0][0])==1)
				execute "Removefromgraph /Z /W=Analysis_Minis#Data_Display "+Results[0][0]
				execute "Killwaves /z "+Host_Datafolder+Results[0][0]
			Endif
			MoveWave $This_DataFolder, $Final_Destination
			Rename $Dup_Final_Name, $Results[0][0]
		Endif	
		SetdataFolder $Host_Datafolder
	Endif
	NVar /z /sdfr=root:Analysis_Parameters G_signalwindow,G_noisewindow,G_stepsize,G_jump,G_threshold,G_Mini_Size,G_Decay_time, G_Baseline, G_Curr_Amp
	//Update numbers in the main window
	Execute "ValDisplay  setvar1_Val 			Win=Analysis_Minis, Disable=0 , Value = "+Num2str(G_threshold*1e12)
	Execute "ValDisplay  signalwindow_Val 	Win=Analysis_Minis, Disable=0 ,Value = "+Num2str(G_signalwindow*Deltax($Results[0][0])*1000)
	Execute "ValDisplay  noisewindow_Val 		Win=Analysis_Minis, Disable=0, Value = "+Num2str(G_noisewindow*Deltax($Results[0][0])*1000)
	Execute "ValDisplay  stepsize_Val 		Win=Analysis_Minis, Disable=0, Value = "+Num2str(G_stepsize*Deltax($Results[0][0])*1000)
	Execute "ValDisplay  jump_Val 				Win=Analysis_Minis, Disable=0, Value = "+Num2str(G_jump*Deltax($Results[0][0])*1000)
	Execute "ValDisplay  Size_Val 				Win=Analysis_Minis, Disable=0, Value = "+Num2Str(G_Mini_Size*Deltax($Results[0][0])*1000)
	Execute "ValDisplay  Decay_Val 			Win=Analysis_Minis, Disable=0, Value = "+Num2Str(G_Decay_time*Deltax($Results[0][0])*1000)
	Execute "ValDisplay  Baseline_Val 		Win=Analysis_Minis, Disable=0, Value = "+Num2Str(G_Baseline*Deltax($Results[0][0])*1000)	
	Execute "SetVariable Which_Wave 			Win=Analysis_Minis, Value=_Str:"+num2char(34)+Results[0][0]+num2char(34)
	Wave /t Results
	CheckBox Enable_output_Name_Change Win=WaveSelector,  Value=0
	Dowindow /k $PanelName
	Killwaves/z W1b
	If (Waveexists(Minis)==1 && Waveexists(a_amplitude)==1 && Waveexists(a_timestamp)==1 && Waveexists(a_baseline)==1 && Waveexists(a_charge)==1 && Waveexists(a_decaytime)==1 && Waveexists(a_risetime)==1)
		DIsplay_mini_Graph()
		Display_and_Modify()
		String Final= Update_Output_Text()
		TitleBox  Results Win=Analysis_Minis, Pos={20, 480}, Title=Final, Fsize=14, Frame=0, Disable=0
	Endif
	Killdatafolder root:Packages
end

// 35 ******************************************************************************************************
// Adjusts values in the main window (points to time)
Function Set_Value(ctrlName,varNum,varStr,varName) : SetVariableControl

	String ctrlName ; Variable varNum ; String varStr ; String varName
	Nvar /sdfr=root:Analysis_Parameters G_Rise_Tau, G_Decay_Tau
	ControlInfo /W=Analysis_Minis Which_Wave
	StrSwitch(CtrlName)
		Case "signalwindow":
			Execute "ValDisplay  signalwindow_Val Value = "+Num2Str(Varnum*Deltax($S_Value)*1000)
		Break
		Case "NoiseWindow":
			Execute "ValDisplay  NoiseWindow_Val Value = "+Num2Str(Varnum*Deltax($S_Value)*1000)
			Break
		Case "stepsize":
			Execute "ValDisplay  stepsize_Val Value = "+Num2Str(Varnum*Deltax($S_Value)*1000)
			Break
		Case "jump":
			Execute "ValDisplay  jump_Val Value = "+Num2Str(Varnum*Deltax($S_Value)*1000)
			Break
		Case "SetVar1":
			Execute "ValDisplay  SetVar1_Val Value = "+Num2Str(Varnum*1e12)
			Break
		Case "Size":
			Execute "ValDisplay  Size_Val Value = "+Num2Str(Varnum*Deltax($S_Value)*1000)
			Break
		Case "Baseline":
			Execute "ValDisplay  Baseline_Val Value = "+Num2Str(Varnum*Deltax($S_Value)*1000)
			Break
		Case "setdecaylow":
			Display_EPSC_Template("setdecaylow")
			Break
		Case "setdecayhigh":
			Display_EPSC_Template("setdecayhigh")
			Break
		Case "setdecayhigh_2nd":
			Display_EPSC_Template("Deconvolve") //this is a random string to pass to the function
			Break
		Case "setdecaylow_2nd":
			Display_EPSC_Template("Deconvolve") //this is a random string to pass to the function
			Break
	EndSwitch
	Update_An_Params_Wave_or_Vals(1)
	//Set_Ana_PArams(1)

End

// 36 ******************************************************************************************************
// Deals witht the x and y scaling buttons
Function Axis_Range(ControlName):Buttoncontrol

	String ControlName
	ControlInfo /W=Analysis_Minis Which_Wave
	Wave Test=$S_Value
	Variable Begin_Axis_x, End_Axis_x,Begin_Axis_y, End_Axis_y
	getaxis/q/w=Analysis_Minis#Data_Display bottom
	Begin_Axis_x=V_Min
	End_Axis_x=V_Max
	getaxis/q/w=Analysis_Minis#Data_Display left
	Begin_Axis_y=V_Min
	End_Axis_y=V_Max
	StrSwitch (ControlName)
		Case "Reset_ALL":
			Setaxis/A/W=Analysis_Minis#Data_Display
		break
		Case "Reset_x":
			Setaxis /W=Analysis_Minis#Data_Display bottom 0,numpnts(test)*deltax(Test)// Begin_Axis_x,(End_Axis_x-(End_Axis_x/4))
		break
		Case "Grow_x":
			Setaxis /W=Analysis_Minis#Data_Display bottom Begin_Axis_x,(End_Axis_x-(End_Axis_x/4))
		break
		Case "Shrink_x":
			Setaxis /W=Analysis_Minis#Data_Display bottom Begin_Axis_x,(End_Axis_x+(End_Axis_x/4))
		break
		Case "FWD_x":
			Setaxis /W=Analysis_Minis#Data_Display bottom Begin_Axis_x+(End_Axis_x-Begin_Axis_x)/5,End_Axis_x+(End_Axis_x-Begin_Axis_x)/5
		break
		Case "BACK_x":
			Setaxis /W=Analysis_Minis#Data_Display bottom Begin_Axis_x-(End_Axis_x-Begin_Axis_x)/5,End_Axis_x-(End_Axis_x-Begin_Axis_x)/5
		break	
		Case "Reset_y":
			Setaxis /W=Analysis_Minis#Data_Display left Wavemin(test),Wavemax(test)
		break
		Case "Grow_y":
			Setaxis /W=Analysis_Minis#Data_Display left ( Begin_Axis_y-( Begin_Axis_y/4)),End_Axis_y
		break
		Case "Shrink_y":
			Setaxis /W=Analysis_Minis#Data_Display left ( Begin_Axis_y+( Begin_Axis_y/4)),End_Axis_y
		break
		Case "FWD_y":
			Setaxis /W=Analysis_Minis#Data_Display left Begin_Axis_y+(End_Axis_y-Begin_Axis_y)/5,End_Axis_y+(End_Axis_y-Begin_Axis_y)/5
		break
		Case "BACK_y":
			Setaxis /W=Analysis_Minis#Data_Display left Begin_Axis_y-(End_Axis_y-Begin_Axis_y)/5,End_Axis_y-(End_Axis_y-Begin_Axis_y)/5
		break
	EndSwitch

end


//------------------------------End of Panel interface management------------------------------

//37 - _____________________________--Pie Chart for Mini detction--_________________________________
// That cute pie chart telling you the progress of the detection
Function SimplePieChart(CenterX, CenterY, Radius, Values, Labels)

	Variable CenterX, CenterY, Radius
	Wave Values
	Wave /T Labels
	Variable Loop1, NumShades, Color, AltTags=.03, ArcMidPnt //AltTags value is the amount to space out a tag from the pie when it gets too crowded
	Duplicate /O Values, Degrees
	Integrate/P Values /D=Degrees
	Degrees=Degrees*360/sum(Values)
	if (numpnts(Values)<6)
		NumShades=numpnts(Values)
		AltTags=0
	else
		if (mod(numpnts(Values),5)!=1) //what's bad is if there is one left at the end, which would get the starting color
			NumShades=5
		else
			if (mod(numpnts(Values),4)!=1)
				NumShades=4
			else
				NumShades=3
			endif
		endif
	endif
	DrawWedge(CenterX, CenterY, 0, Degrees[0], Radius, 1,16019,65535)//36000, 36000, 36000)
	ArcMidPnt=Degrees[0]/2
	for (Loop1=0;Loop1<numpnts(Values)-1;Loop1+=1)
		Color=16000
		DrawWedge(CenterX, CenterY, Degrees[Loop1], Degrees[Loop1+1], Radius, 52428,1,1)//Color, Color+10000, Color+30000)
		ArcMidPnt=(Degrees[Loop1]+Degrees[Loop1+1])/2
	endfor
End		

// 38 ******************************************************************************************************
// Used by the Pie function above
Function DrawWedge(CenterX, CenterY, StartAngle, EndAngle, Radius, Red, Green, Blue)
	//Draw a wedge with the given center position through the given angles
	//Wedges have black line border and the given color
	//Angles in degrees, Center and radius graph relative
	//End Angle must be > Start Angle
	Variable CenterX, CenterY, StartAngle, EndAngle, Radius, Red, Green, Blue
	if (EndAngle-StartAngle>180)
		SetDrawEnv fillfgc=(Red, Green, Blue), linethick=0
		DrawPoly CenterX, CenterY, 1, 1, {0, 0, Radius*cos((StartAngle+180)*pi/180), Radius*sin((StartAngle+180)*pi/180), Radius*cos(EndAngle*pi/180), Radius*sin(EndAngle*pi/180), 0, 0}
		SetDrawEnv fillfgc=(Red,Green,Blue)
		DrawArc /X/Y CenterX, CenterY, Radius, StartAngle, StartAngle+180
		SetDrawEnv fillfgc=(Red, Green, Blue)
		DrawArc /X/Y CenterX, CenterY, Radius, StartAngle+180, EndAngle
	else
		SetDrawEnv fillfgc=(Red, Green, Blue), linethick=0
		DrawPoly CenterX, CenterY, 1, 1, {0, 0, Radius*cos(StartAngle*pi/180), Radius*sin(StartAngle*pi/180), Radius*cos(EndAngle*pi/180), Radius*sin(EndAngle*pi/180), 0, 0}
		SetDrawEnv fillfgc=(Red, Green, Blue)
		DrawArc /X/Y CenterX, CenterY, Radius, StartAngle, EndAngle
	endif
	DrawLine CenterX, CenterY, CenterX+Radius*cos(StartAngle*pi/180), CenterY+Radius*sin(StartAngle*pi/180)
	DrawLine CenterX, CenterY, CenterX+Radius*cos(EndAngle*pi/180), CenterY+Radius*sin(EndAngle*pi/180)
End

//_____________________________--End of Pie Chart for Mini detction--_________________________________

// 39 ******************************************************************************************************
//removes unrealistic events from the detection. Can be tweaked by used. Shoul I make a panel for this?!
function Filter_by_Decay()
	String ctrlName
	nvar /sdfr=root:Analysis_Parameters G_mininumber, G_Threshold
	variable pointnumber=G_mininumber
	wave a_Amplitude, a_Risetime, a_Decaytime, a_Charge, a_Timestamp, a_Baseline,Amps, Minis, Start_Fit, All_Decay_time, Risetime_Xs
	Svar /sdfr=root:Analysis_Parameters Host_Datafolder
	Wave a_decaytime,All_Baseline_Vals
	variable i
	for (i=0;i<numpnts(a_decaytime);i+=1) //removes calculated decays
		if (abs(a_decaytime[i])>0.010 || numtype(a_decaytime[i])==2 || a_decaytime[i]<0.00005)
			Adjust_Points(i)
			i-=1
		endif
	endfor
	Align_by_dAdt(0)
//	return 0
end

// 40 ******************************************************************************************************
// Deltes unwanted events from array
Function Adjust_Points(i)

		Variable i
		wave a_Amplitude, a_Risetime, a_Decaytime, a_Charge, a_Timestamp, a_Baseline,Amps, Minis, Start_Fit, All_Decay_time, Risetime_Xs, a_decaytime,All_Baseline_Vals
		Deletepoints /M=1 i,1, minis
		Deletepoints /M=1 i,1,All_Baseline_Vals
		Deletepoints /M=1 i,1,All_Decay_time
		Deletepoints i,1,a_Amplitude
		Deletepoints i,1,a_Risetime
		Deletepoints i,1,Risetime_Xs
		Deletepoints i,1,a_Decaytime
		Deletepoints i,1,a_Charge
		Deletepoints i,1,a_Timestamp
		Deletepoints i,1,a_Baseline
		Deletepoints i,1,Amps
		Deletepoints i,1,Start_fit

end

// 41 ******************************************************************************************************
// Aligns the PSCs for averaging
 Function Align_by_dAdt(Continuum)
	Variable Continuum
	wave a_Amplitude, a_Risetime, RiseTime_Xs, a_Decaytime, a_Charge, a_Timestamp, a_Baseline,Amps, Minis, Start_Fit, All_Decay_time
	NVar /sdfr=root:Analysis_Parameters G_Mini_Size, G_Baseline
	if (waveexists(Minis)!=1)
		Error_Dialog("Analysis")
		abort
	endif
	make /o/n=(dimsize(minis,1)) Max_DIFs //stores the extreme dI/dt
	make /o/n=(dimsize(minis,1)) Refs=x
	Make /o/n=(2*dimsize(minis,0)) AVG_d=0
	
	variable i
	ControlINfo /W=Analysis_minis Positive
	Variable Absolute=V_Value
	for (i=0;i<dimsize(minis,1);i+=1)
		matrixop /o temp=col(minis,i)
		differentiate temp /D=Temp_DIF
		wavestats /q temp_DIF
		if (Absolute)
			Max_DIFs[i]=v_maxloc
		else
			Max_DIFs[i]=abs(V_Minloc)
		endif
	endfor 
	i=0
	wavestats /q Max_DIFs
	if (Continuum==0)
		Variable /g dAdt_Bar=v_sdev*0.8 //sets the bar for eliminating events that have an enormous rise time
	//endif
	
	do
		if (max_difs[i]>dAdt_Bar+v_avg || max_difs[i]<-dAdt_Bar+v_avg || max_difs[i]==0)
			deletepoints i,1,max_difs
			deletepoints i,1,Refs		
			Adjust_Points(i)
		else
			i+=1
		endif
		if (i>=numpnts(max_difs))
			break
		endif
	while (1)
	endif
	wavestats /q Max_DIFs
	
	for (i=0;i<numpnts(max_difs);i+=1)
		make /o /n=(dimsize(minis,0)) temp=minis[p][i]
		insertpoints 0,abs(v_max-Max_DIFs[i]),temp
		AVG_d[0,numpnts(temp)-1]+=temp
	endfor
	AVG_d/=numpnts(Max_DIFs)
	Deletepoints 0,abs(V_max-v_min), AVG_d
	Deletepoints dimsize(minis,0)-1-abs(V_max-v_min),numpnts(avg_d)-1, AVG_d
	ControlInfo /W=Analysis_Minis Which_Wave
	setscale /p x,0,deltax($S_Value),"s",AVG_d
	killwaves /z temp_dif, refs,Max_DIFs

end

// 42 ******************************************************************************************************

Function Analysis_Params(Function_RW)
	String Function_RW
	Wave /t An_Params
	Variable Val
	Nvar /sdfr=root:Analysis_Parameters G_threshold, G_signalwindow, G_noisewindow, G_stepsize, G_jump, G_Mini_Size, G_Baseline, G_Decay_time, G_Tolerance, G_Rise_Tau, G_Decay_Tau
	StrSwitch (Function_RW)
		Case "Read":
			LoadWave/O
			If (strlen(S_Wavenames)<=2)
				return 0
			endif
			wave /t An_Params=$RemoveEnding(S_Wavenames)
			Duplicate/o /t An_Params, root:Analysis_Parameters:An_Params	
			Update_An_Params_Wave_or_Vals(2)
			CheckBox Positive, win=Analysis_Minis, VAlue=str2num(An_Params[11][1])
			Killwaves $RemoveEnding(S_Wavenames)
		Break
		Case "Write":
			Make/o/n=12 /t An_Params
			Update_An_Params_Wave_or_Vals(1)
			Save/C An_Params as "An_Params.ibw"
		Break
	EndSwitch
	
End

// 43 ******************************************************************************************************

Function Set_Ana_PArams(Start)
	
	Variable Start
	NVar /sdfr=root:Analysis_Parameters G_threshold, G_signalwindow, G_noisewindow, G_stepsize, G_jump, G_Mini_Size, G_Baseline, G_Decay_time, G_Tolerance, G_Rise_Tau, G_Decay_Tau
	String Current_Folder = getdatafolder(1)
		If (Waveexists (An_Params)==0)
				Make/n=(22,2) /t An_Params
		EndIf
		Update_An_Params_Wave_or_Vals(1) //wave was just created and it ieeds numerical values
		If (Waveexists(root:Analysis_Parameters:An_Params)==1 && Start==0) //Wave exists in Analysis_Parameters Folder and the routine is relaunched
			Duplicate/o /t root:Analysis_Parameters:An_Params, $Current_Folder+"An_Params"	
			If (Waveexists(An_Params)==1) //This line may seem redundant, but seriously, it is not. At least in Igor 6.03
				Update_An_Params_Wave_or_Vals(1)
				//CheckBox Positive, win=Analysis_Minis, VAlue=str2num(An_Params[1][11])
			EndIf
		Else //Wave exists in Analysis_Parameters Folder and Needs to be updated or needs to be created
			If (Waveexists (An_Params)==0)
				Make/n=(22,2) /t An_Params
			EndIf
			Update_An_Params_Wave_or_Vals(2)
			Duplicate/o An_Params, root:Analysis_Parameters:An_Params
		EndIf
	Setdatafolder  $Current_Folder
End



Function Update_An_Params_Wave_or_Vals(option)//0, Gives 1st columns their names, 1 updates wave, 2 updates values 
	Variable option
	NVar /sdfr=root:Analysis_Parameters G_threshold, G_signalwindow, G_noisewindow, G_stepsize, G_jump, G_Mini_Size, G_Baseline, G_Decay_time, G_Tolerance, G_Rise_Tau, G_Decay_Tau
	NVar /sdfr=root:Analysis_Parameters F1_Low, F1_High, F2_Low, F2_High, Threshold_Dec, Jump_Dec, Noise_Dec, Step_Dec
	If (Waveexists (An_Params)==0)			
			Make/o/n=(22,2) /t An_Params
	elseif (wavetype(An_Params,1)==1)
			rename An_Params, An_Params_Numeric
			wave An_Params_Numeric
			Make/o/n=(22,2) /t An_Params
			An_Params[][1]=num2str(An_Params_Numeric) //be aware of the outcome of this line... not sure if the vals are being correctly assigned.
			killwaves /z An_Params_Numeric
			Update_An_Params_Wave_or_Vals(0) //Need to populate the fist column
	EndIf
	Switch (Option)
		Case 0:
			An_Params[0][0]		=	"Threshold"
			An_Params[1][0]		=	"Signal Window"
			An_Params[2][0]		=	"Noise window"
			An_Params[3][0]		=	"Step size"
			An_Params[4][0]		=	"Jump size"
			An_Params[5][0]		=	"Mini Size"
			An_Params[6][0]		=	"Baseline"
			An_Params[7][0]		=	"Decay_time"
			An_Params[8][0]		=	"Tolerance"
			An_Params[9][0]		=	"Rise Tau"
			An_Params[10][0]	=	"Decay Tau"
			An_Params[11][0]	=	"Peak Direction" 					//Boolean
			An_Params[12][0]	= "Threshold Deconvolution"
			An_Params[13][0] 	= "Jump Deconvolution"
			An_Params[14][0]	= "Noise Deconvolution"
			An_Params[15][0]	= "Step Deconvolution"
			An_Params[16][0]	= "Signal Filter" 						//Boolean
			An_Params[17][0]	= "Deconvolution Filter" 			//Boolean
			An_Params[18][0]	= "End Pass Band Signal Filter"
			An_Params[19][0]	= "Reject Band Signal Filter"
			An_Params[20][0]	= "End Pass Band Deconvolution Filter"
			An_Params[21][0]	= "Reject Band Deconvolution Filter"
		break
		Case 1:
			ControlInfo /W=Analysis_Minis Positive
			An_Params[0][1]		=	num2str(G_threshold)
			An_Params[1][1]		=	num2str(G_signalwindow)
			An_Params[2][1]		=	num2str(G_noisewindow)
			An_Params[3][1]		=	num2str(G_stepsize)
			An_Params[4][1]		=	num2str(G_jump)
			An_Params[5][1]		=	num2str(G_Mini_Size)
			An_Params[6][1]		=	num2str(G_Baseline)
			An_Params[7][1]		=	num2str(G_Decay_time)
			An_Params[8][1]		=	num2str(G_Tolerance)
			An_Params[9][1]		=	num2str(G_Rise_Tau)
			An_Params[10][1]	=	num2str(G_Decay_Tau)
			An_Params[11][1]	=	num2str(V_Value)
			An_Params[12][1]	= num2str(Threshold_Dec)
			An_Params[13][1]	= num2str(Jump_Dec)
			An_Params[14][1]	= num2str(Noise_Dec)
			An_Params[15][1]	= num2str(Step_Dec)
			ControlInfo /W=Analysis_Minis F1
			An_Params[16][1]	= num2str(V_Value)
			ControlInfo /W=Analysis_Minis F2
			An_Params[17][1]	= num2str(V_Value)
			An_Params[18][1]	= num2str(F1_Low)
			An_Params[19][1]	= num2str(F1_High)
			An_Params[20][1]	= num2str(F2_Low)
			An_Params[21][1]	= num2str(F2_High)
		break
		Case 2:
			if (strlen (an_params[0][1])<1)
				break
			endif
			G_threshold		=  str2num(An_Params[0][1])
			G_signalwindow	=	str2num(An_Params[1][1])
			G_noisewindow	=	str2num(An_Params[2][1])
			G_stepsize		=	str2num(An_Params[3][1])
			G_jump				=	str2num(An_Params[4][1])
			G_Mini_Size		=	str2num(An_Params[5][1]) 
			G_Baseline		=	str2num(An_Params[6][1])
			G_Decay_time		=	str2num(An_Params[7][1])
			G_Tolerance		=	str2num(An_Params[8][1])
			G_Rise_Tau		=	str2num(An_Params[9][1])
			G_Decay_Tau		=	str2num(An_Params[10][1])
			CheckBox Positive Value=str2num(An_Params[11][1])
			Threshold_Dec	=  str2num(An_Params[12][1])
			Jump_Dec 			=	str2num(An_Params[13][1])
			Noise_Dec 		=	str2num(An_Params[14][1])
			Step_Dec			=	str2num(An_Params[15][1])
			CheckBox F1 		Value=	str2num(An_Params[16][1])
			CheckBox F2		Value=	str2num(An_Params[17][1])
			F1_Low 			=	str2num(An_Params[18][1])
			F1_High 			=	str2num(An_Params[19][1])
			F2_Low 			=	str2num(An_Params[20][1])
			F2_High 			=	str2num(An_Params[21][1])
			break
	endswitch

end

// 44 ******************************************************************************************************
//PSC deconvolution module

function Deconvolve(option)

	Variable option //0 = new deconvolution; 1 = plotting data only
	
	If (Option==0)
		Variable Fori_1, Fori_2, Fdec_1, Fdec_2
		getwindow Analysis_Minis#deconv title
		if (stringmatch(S_Value,"dec"))
				killwindow /z Analysis_Minis#deconv
		endif
		Controlinfo /W=Analysis_Minis Which_Wave
		wave PSC_Wv=$S_Value
		Wave AVG_d
		Wave EPSC_Template
		Controlinfo /w=Analysis_minis Use_Template
	
		if (V_Value==1)
			duplicate/o AVG_d, EPSC_t
		else
			duplicate/o EPSC_Template, EPSC_t
		endif
	
		Controlinfo F1
		if (V_Value)
			Controlinfo /w=Analysis_minis Filter1_Low
			Fori_1 = V_Value
			Controlinfo /w=Analysis_minis Filter1_High
			Fori_2 = V_Value
			wave Filtered_PSC=Filter_Wave(PSC_Wv,Fori_1,Fori_2,"F1")
		else
			wave Filtered_PSC=PSC_Wv
		endif
		variable i, min_epsc, V_0
		pauseupdate
		Differentiate EPSC_t /D=EPSC_t_dif
		V_0=EPSC_t[0]
		EPSC_t-=V_0
		controlinfo Positive
		if (V_Value)// || wavemax(EPSC_t)<EPSC_t[0] )//the second condition covers the possibility of "data template" without checking "Detect Positive PEaks"checkbox
			min_epsc=wavemax(EPSC_t) //this arithmetic may look counterintuitive but for some reason the EPSC template must be the opposite of that 
		else								//you want to detect. 
			min_epsc=wavemin(EPSC_t)
		endif
		EPSC_t/=min_epsc // normalizes the epsc template wave to 1
		killwaves /z EPSC_t_dif
		Controlinfo F2
		wave /z Filtered
		if (V_Value)
			wave Filt1=Deconv_FFT(EPSC_t,Filtered_PSC)
			setscale /p x,0,deltax(PSC_Wv),"s",Filt1
			Controlinfo /w=Analysis_minis Filter2_Low
			Fdec_1 = V_Value
			Controlinfo /w=Analysis_minis Filter2_High
			Fdec_2 = V_Value
			Wave Filtered=Filter_Wave(Filt1,Fdec_1,Fdec_2,"F2")
		else
			wave Temp_d=Deconv_FFT(EPSC_t,Filtered_PSC)
			setscale /p x,0,deltax(PSC_Wv),"s",Temp_d
		endif	
		Controlinfo F2
		if (V_Value)
			Duplicate/o Filtered, Deconvolved
		else
			Duplicate/o Temp_d, Deconvolved
		endif
		deconvolved[numpnts(deconvolved)-30,numpnts(deconvolved)-1]=0
		deconvolved[0,29]=0
		Button Rerun_Peak_Dec, Disable=0	
	Elseif (Option==1) //existing analysis
		Wave /t Results
		Wave PSC_Wv=$Results[0][0]//Final_Name
	Endif
	wave /z deconvolved
	if (waveexists(Deconvolved)==0) //this is for the displaying purposes when returning to an existing analysis
		Abort
	endif
	getwindow Analysis_Minis#deconv title
	if (stringmatch(S_Value,"dec"))
		display /host=Analysis_Minis /N=Deconv /W=(300,46,870,500) as "Dec"
	endif
	make/o/n=(1,3) /t W_WaveList=""
	getwindow Analysis_Minis#deconv wavelist
	findvalue /TEXT="Deconvolved" w_wavelist
	if (V_Value==-1)
		appendtograph /W=Analysis_Minis#Deconv Deconvolved
	endif
	Controlinfo /W=Analysis_Minis Which_Wave
	findvalue /TEXT=S_Value w_wavelist
	if (V_Value==-1)
		appendtograph/l=original /W=Analysis_Minis#Deconv PSC_Wv
		wave Amps, a_Timestamp
		if (waveexists(Amps))
			appendtograph/l=original /W=Analysis_Minis#Deconv Amps vs a_Timestamp
		endif
	endif
	String DecGraph_wv_Name=nameofwave(PSC_Wv) 
	ModifyGraph /W=Analysis_Minis#Deconv rgb(Deconvolved)=(1,16019,65535),rgb($DecGraph_wv_Name)=(0,0,0)
	ModifyGraph /W=Analysis_Minis#Deconv axisEnab(left)={0.48,0.95},axisEnab(original)={0,0.45},freePos(original)={0,bottom}
	ModifyGraph /W=Analysis_Minis#Deconv lblPos(original)=60
	ModifyGraph /W=Analysis_Minis#Deconv mode(Amps)=3,rgb(Amps)=(0,0,52224),marker(Amps)=19
	TextBox/W=Analysis_Minis#Deconv/C/N=Dec_Trace /F=0/A=LT/X=1/Y=0 "\\Z18\K(1,16019,65535)Deconvolved"
	TextBox/W=Analysis_Minis#Deconv/C/N=Ori_Trace /F=0/A=LT/X=1/Y=50 "\\Z18Original"
	doupdate
	Get_Peak(Deconvolved,option)
	
	//Variable Events=Get_Peak(Deconvolved)
	//TitleBox  Dec_Num_evts Win=Analysis_Minis, Pos={700, 500}, Title=num2str(Events)+" events detected", Fsize=18, Frame=0, Disable=0
	killwaves /z DEC, DECFFT, Template_FFT, Trace_FFT
	Update_An_Params_Wave_or_Vals(1)
	
end

// 45 ******************************************************************************************************

static function /wave Deconv_FFT(epsc_T,PSC_Wv)
	
	wave epsc_T,PSC_Wv
	if (mod(numpnts(PSC_Wv),2))
		deletepoints 0,1,PSC_wv
	endif
	print "Deconvolution in progress at ",time()," . Please wait."
	if (mod(numpnts(PSC_wv),100)!=0)
		deletepoints numpnts(PSC_wv)-mod(numpnts(PSC_wv),100),mod(numpnts(PSC_wv),100),PSC_wv
		//This if stetement removes the last points of the PSC_wv_Cut beacuse for some reason the FFT function
		//does not like small broken even numbers and it takes fucking forever to calculate the FFT			
		//I'd rather sacrifice some datapoints than precios minutes of my life.
	endif
	doupdate
	FFT/OUT=1/DEST=Trace_FFT PSC_Wv
	FFT/OUT=1/PAD={NumPnts(PSC_Wv)}/DEST=Template_FFT epsc_T
	Make/o/N=(numpnts(Template_FFT)) /D/C DECFFT
	DECFFT=Trace_FFT/Template_FFT
	IFFT/DEST=DEC DECFFT
	print "Deconvolution complete."
	doupdate
	killwaves /z PSC_Wv_Cut, DEC_partial, temp
	return DEC
	
end

// 46 ******************************************************************************************************

Static Function /wave Filter_Wave(PSC_Wv,low,high,Filter) //filters the source wave

	wave PSC_Wv
	Variable low
	Variable high
	String Filter
	print "Filtering wave"
	low*=deltax(PSC_Wv)
	high*=deltax(PSC_Wv)
	Duplicate/O PSC_Wv, filtered; DelayUpdate
	Make/O/D/N=0 coefs; DelayUpdate
	try
		FilterFIR/DIM=0/LO={low,high,101}/COEF coefs, filtered; AbortOnRTE
	catch
		String errMessage = GetRTErrMessage()+";"
		strswitch (Filter)
			Case "F1":
				Filter="Signal Filter"
			Case "F2":
				Filter="Deconv Filter"
		endswitch 
		abort "While performing "+Stringfromlist(0,errMessage)+", the following error occurred: \r\r_"+ Stringfromlist(1,errMessage)+"\r\rReview the filter parameters for "+Filter
	endtry
	return filtered

end

// 47 ******************************************************************************************************


function Get_Peak(Wv,option)

	wave Wv
	Variable option //0 for new deconvolution, 1 for existing
	Nvar /SDFR=root:Analysis_Parameters Threshold_dec, Jump_dec, Noise_dec, Step_dec
	Wave /t Results
	if (Option==0)
		make/o/n=1 Peak_Timestamp=0
		make/o/n=1 Peak_Val=0
		removefromgraph /z /w=Analysis_minis#Deconv Peak_Val
		variable start,events,i,index
		Variable Threshold_ori=Threshold_dec
		Variable avg_noise, avg_signal
		findpeak /m=(Threshold_dec) /N  /q /R=[start,inf] Wv
		start=V_PeakLoc
		Peak_Timestamp=start
		Peak_Val=V_PeakVal
		AppendToGraph /w=Analysis_minis#Deconv /l=left Peak_Val vs Peak_Timestamp
		ModifyGraph /w=Analysis_minis#Deconv mode(Peak_Val)=3,marker(Peak_Val)=19
		Controlinfo Positive 
		Variable absolute=V_Value
		wavestats/q Wv
		variable wavenumpoints =  V_npnts+V_numNans+V_numINFs
		i=0
		do
			wavestats /q /r=[i-2*Noise_dec,i] Wv
			if (absolute)
				threshold_ori=V_avg+Threshold_dec
					findlevel /b=(1) /Edge=1 /P /q /R=[i,i+Noise_dec] Wv,Threshold_ori
			else
				threshold_ori=V_avg-Threshold_dec
			findlevel /b=(1) /Edge=2 /P /q /R=[i,i+Noise_dec] Wv,Threshold_ori
			endif
			if (V_flag==0 && backwards(V_levelx, Threshold_dec, Noise_dec, Wv))
				i=V_Levelx+Jump_dec
				Switch (Absolute)
					Case 0:
						wavestats/q /r=[V_levelx, V_levelx+Noise_dec] Wv
						if (events>0)
							insertpoints numpnts(Peak_Timestamp),1,Peak_Timestamp
      						insertpoints numpnts(Peak_Val),1,Peak_Val
    	 	    		endif
     					Peak_Timestamp[numpnts(Peak_Timestamp)-1]=V_MinLoc
      					Peak_Val[numpnts(Peak_Val)-1]=V_Min					
					Break
					Case 1:
						wavestats/q /r=[V_levelx, V_levelx+2*Noise_dec] Wv
						if (events>0)
							insertpoints numpnts(Peak_Timestamp),1,Peak_Timestamp
      						insertpoints numpnts(Peak_Val),1,Peak_Val
    				   endif
     				 	Peak_Timestamp[numpnts(Peak_Timestamp)-1]=V_MaxLoc
    	  				PEak_Val[numpnts(Peak_Val)-1]=V_Max
						Break			
				EndSwitch
				events += 1
				if (mod(events,50)==0)
					progress_bar(i, wavenumpoints,"Run Deconvolution")
					doupdate
				endif
				index+=1
			endif
		i += Step_dec		
		while (i<wavenumpoints)
	TitleBox  Dec_Num_evts Win=Analysis_Minis, Pos={700, 500}, Title=num2str(Events)+" events detected", Fsize=18, Frame=0, Disable=0
	Results[1][2]=num2str(Events)//"# of Evts"
	elseif(Option==1 && Waveexists(Peak_Val))
		getwindow Analysis_minis#Deconv wavelist
		if (stringmatch(t1(),"*Peak_Val*")==0)
			AppendToGraph /w=Analysis_minis#Deconv /l=left Peak_Val vs Peak_Timestamp
		endif
		ModifyGraph /w=Analysis_minis#Deconv mode(Peak_Val)=3,marker(Peak_Val)=19
		TitleBox  Dec_Num_evts Win=Analysis_Minis, Pos={700, 500}, Title=Results[1][2]+" events detected", Fsize=18, Frame=0, Disable=1
	endif
	SetDrawLayer/w=Analysis_Minis /K Overlay //erases the progress bar
	Results[2][2]="N/A" //Amplitude
	Results[3][2]=num2str(Events/(deltax(Wv)*Numpnts(Wv)))+"Hz" //"Frequency"
end     


static function /t t1() //Helps to Check for the existance of the wave Peak_val needed in the deconvolution panel to avoid error when loading an existing analysis.

	wave /t w_wavelist
	duplicate /o /free /t /r=[][0] w_wavelist, Col_w
	variable i
	String test=""
	for (i=0;i<dimsize(Col_w,0);i+=1)
		test+=Col_w[i]+";"
	endfor
	return test
end


// 48 ******************************************************************************************************

Static Function Filter_by_Deconvolution()
Variable PSC_num
wave peak_timestamp,a_timestamp
Variable i,j,index
Variable Greater_Wave
nvar /sdfr=root:Analysis_Parameters G_mininumber
	
	Greater_Wave=numpnts(a_timestamp)
	Duplicate /o a_timestamp, Intersection_Timestamps
	Intersection_Timestamps=0
	for (i=0;i<Greater_wave;i+=1)
		findvalue /V=(a_timestamp[i]) /t=0.002 peak_timestamp
		if (V_Value!=-1)
			Intersection_Timestamps[i]=a_timestamp[i]
		endif
	endfor
	j=round(numpnts(Intersection_Timestamps)/20)
	for (i=numpnts(Intersection_Timestamps)-1;i>=0;i-=1)
		if (Intersection_Timestamps[i]==0)
			G_mininumber=i
			pressdelete("Intersec")
		endif
		if (numpnts(Intersection_Timestamps)-i>=j)
			progress_bar(index, numpnts(Intersection_Timestamps),"Intersec")
			j+=round(numpnts(Intersection_Timestamps)/20)
		endif
		index+=1
	endfor
	SetDrawLayer/w=Analysis_Minis /K Overlay
	
end

// 49 ******************************************************************************************************

Function progress_bar(progression,wv_num_pnts,button_name)

	Variable progression,wv_num_pnts
	String Button_name
	Variable size
	Strswitch (button_name)
		Case "Run Deconvolution":
			SetDrawLayer/w=Analysis_Minis /K Overlay
			SetDrawLayer /w=Analysis_Minis Overlay
			SetdrawEnv /W=Analysis_Minis fillfgc=(1,65535,33232), linethick=1
			size=round(progression/wv_num_pnts*180)
			DrawRect /W=Analysis_Minis 20,535,20+size,540
		Break
		Case "Intersec":
			SetDrawLayer/w=Analysis_Minis /K Overlay
			SetDrawLayer /w=Analysis_Minis Overlay
			SetdrawEnv /W=Analysis_Minis fillfgc=(1,65535,33232), linethick=1
			size=round(progression/wv_num_pnts*100)
			DrawRect /W=Analysis_Minis 220,535,220+size,540
			doupdate
		Break
	Endswitch

end

// 50 ******************************************************************************************************

Static Function backwards(peak_x, Threshold_dec, Noise_dec, Wv) //double checks if the found threshold is real
	Variable peak_x
	Variable Threshold_dec
	Variable Noise_Dec
	Wave Wv
	Controlinfo Positive 
	Variable absolute=V_Value
	Variable Threshold_ori
	wavestats /q /r=[peak_x+20,peak_x+5*Noise_dec+20] Wv
	if (absolute)
		threshold_ori=V_avg+Threshold_dec
		findlevel /b=(1) /Edge=1 /P /q /R=[peak_x+Noise_dec,peak_x-5] Wv,Threshold_ori
	else
		threshold_ori=V_avg-Threshold_dec
		findlevel /b=(1) /Edge=2 /P /q /R=[peak_x+Noise_dec,peak_x-5] Wv,Threshold_ori
	endif
	If (V_flag==0)
		return 1
	else
		return 0
	endif
end

// 51 ******************************************************************************************************

Function Trim_by_Deconv()
	wave Peak_Timestamp, a_Timestamp
	nvar /sdfr=root:Analysis_Parameters G_mininumber
	variable pointnumber=G_mininumber
	variable i
	duplicate/o a_Timestamp, tmst
	for (i=numpnts(a_Timestamp)-1;i>=0;i-=1)
		findvalue /T=0.05 /V=(a_Timestamp[i]) Peak_Timestamp
		if (V_value==-1)
			G_mininumber=i
			pressdelete("")
			deletepoints i,1,tmst
		endif
	endfor
end

//End of deconvolution module

// 52 ******************************************************************************************************

// Error messages handling
function Error_Dialog(error)

	String error
	killwindow /Z Error_Msg
	Newpanel /W=(200,200,600,350) /FLT=2 /K=1 /N=Error_Msg as "Error"
	StrSwitch (Error)
		Case "Analysis":
			Error="There is no data available.\rPlease perform detection."
		break
	Endswitch
	titlebox /Z Err anchor=MC,Fsize=18,pos={0,30},size={400,20},frame=0,title=Error
	Button Err_Button, pos={170,100},size={60,40},FSize=20,Title="OK", proc=Instructions_Handling//Cancel_select

end

// 53******************************************************************************************************

Function EPSC_Num(A_Struct) : SetVariableControl

	Struct WMSetVariableAction &A_Struct
	if (A_Struct.eventcode==2 || A_Struct.eventcode==6) //enter pressed or arrow 
		Modify_Point(A_Struct.dval,1)
	endif
	
end

// 54******************************************************************************************************

//returns values that were originally in power of ten as "converted" numbers with two decimal algarisms after the point

Function [Variable number_out, String Out_Str] SuperRound(Variable number)                   

    String StrNumber, Number_2, dummy
    Variable Multiplier, i, power , difference , prefix, adding                       // multiplier decides how much the decimal spot is "shifted" 
    StrNumber=num2str(number) 
    if (strsearch ( StrNumber"e",0)!=-1)
    	Multiplier = str2num(StrNumber[strsearch ( StrNumber"e",0)+1,inf])                       
    else //when there is no  "e" to identify decimal numbers
    	if (abs(number)<1)
			for (i=1;i<strlen(StrNumber);i+=1)
				adding=str2num(strnumber[i])
				if (adding>=1)
					i-=1
					break
				endif
			endfor			
    		Multiplier=i*-1
    	endif //what if the number>>1? Gotta work this shit out...
    endif
    difference=mod(multiplier,3)
    if (multiplier>0)
    	//power=Multiplier-difference - original
   		power=Multiplier-3-difference+2 //the "-2" followed by the round command is needed to have only 2 decimal algarisms after the point
    	number_out=round(number/10^(power))/100
    else
    	//power=Multiplier-3-difference
    	power=Multiplier-3-difference-2 //the "-2" followed by the round command is needed to have only 2 decimal algarisms after the point
    	number_out=round(number/10^(power))/100
    endif   
   	StrNumber=num2str(number) 
   	number_2=StrNumber[strsearch(StrNumber".",0)+1,strsearch(StrNumber".",0)+2]
   	StrNumber=StrNumber[0,strsearch ( StrNumber".",0)]+number_2
 	if (multiplier>0)
 		prefix=(abs(Multiplier)-mod(abs(Multiplier),3))
  	else
  		prefix=(abs(Multiplier)+3-mod(abs(Multiplier),3))
  	endif
   prefix=multiplier<0?(prefix*-1):prefix
   switch (prefix)
   	Case -15:
   		Out_str="f"
   		Break
   Case -12:
   		Out_str="p"
   		Break
   Case -9:
   		Out_str="n"
   		Break
   Case -6:
   		Out_str="µ"
   		Break
   	Case -3:
   		Out_str="m"
   		Break
   	Case 0:
   		Out_str=""
   		Break
   	Case 3:
   		Out_str="k"
   		Break
   	Case 6:
   		Out_str="k"
   		Break
	Case 9:
   		Out_str="G"
   		Break
   	Case 12:
   		Out_str="T"
   		Break	
   	endswitch
   	return [number_out, Out_Str]
End

// 55 ******************************************************************************************************

Function copy_Wave() //copies the analysis parameters from another analysis
	String List=WS_SelectedObjectsList("WaveSelector","WaveSelectorList") //retrieves the datafolder selection
	String Params_Origin=Stringfromlist(0,List)+":An_Params"
	Wave /t An_PArams
	execute "An_Params="+Params_Origin
	Update_An_Params_Wave_or_Vals(2) //updates the global variables to the new values
	Killwindow Waveselector
end


// 55 ******************************************************************************************************

Function Combine()
wave Peak_Val, Peak_Timestamp
wave Amps, a_timestamp, fit_wave_10
ControlInfo /W=Analysis_Minis Which_Wave
String Wave_Name=S_Value
variable i, j, Start, Delta
Delta=deltax($Wave_Name)
do 
findvalue /S=(Start) /T=0.0005 /V=(Peak_Timestamp[i]) a_timestamp
if (V_Value==-1)
	Force_EPSC(Wave_Name,round(Peak_Timestamp[i]/delta))
	
else
	Start=Peak_Timestamp[j]
	j+=1
endif

i+=1


while (i<numpnts(Peak_Timestamp))
ControlInfo /W=Analysis_Minis Which_Wave 
execute "Removefromgraph /z /W=Analysis_Minis#Deconv Fit_"+S_Value
execute "Killwaves /z Fit_"+S_Value
end

Function Display_n_fit_AVG_PSC(absolute)
variable absolute
NVar/sdfr=root:Analysis_Parameters G_Rise_Tau, G_Decay_Tau, x_offset_fit, y_offset_fit, Amplitude_PSC_fit

variable scale, p
wave /z EPSC_template, AVG_d

Newpanel/k=1 /n=Template_and_AVG /w=(100,100,500,500) as "EPSC Template"
Display/k=1 /N=EPSCTemplate /HOST=Template_and_AVG /W=(10,10,390,240) EPSC_Template 
Variable zero=EPSC_Template[0]
EPSC_Template-=zero
if (waveexists(AVG_d)==1)
				
	if (absolute==0)
		scale=(wavemin(AVG_d)-AVG_d[0])/wavemin(EPSC_template)
	else
		scale=(wavemax(AVG_d)-AVG_d[0])/wavemax(EPSC_template)
	endif	
	EPSC_Template*=scale
	EPSC_Template+=AVG_d[0]
	appendtograph AVG_d
	ModifyGraph rgb(AVG_d)=(0,0,0)
	Legend/C/N=text0/J/F=0/A=RC "\\s(AVG_d) PSC avg\r\\s(epsc_Template) Template"
endif
if (strlen(csrinfo(A))>=2)
	x_offset_fit=xcsr(a)
endif
y_offset_fit=AVG_d[0]
amplitude_PSC_fit=1e-7//wavemax(AVG_d)-wavemin(AVG_d)
titlebox FIt_Params, pos={10,245},frame=0,title= "PSC Fitting Parameters", Fsize=16

SetVariable setdecaylow_2nd ,pos={10,270},size={140,16},title="Rise Tau [s]   ",fSize=12,limits={-inf,inf,0.00001},value=root:Analysis_Parameters:G_Rise_Tau, proc=Set_Value
SetVariable setdecayhigh_2nd ,pos={10,295},size={140,16},title="Decay Tau [s]",fSize=12,limits={-inf,inf,0.00001},value= root:Analysis_Parameters:G_Decay_Tau, proc=Set_Value
SetVariable Amplitude_fit ,pos={10,320},size={140,16},title="Fit amp",fSize=12,limits={-inf,inf,0.00001},value= root:Analysis_Parameters:amplitude_PSC_fit//, proc=Set_Value
SetVariable fit_x_offset ,pos={10,345},size={100,16},title="x offset",fSize=12,limits={-inf,inf,0.0001},value=root:Analysis_Parameters:x_offset_fit//, proc=Set_Value
SetVariable fit_y_offset ,pos={10,370},size={100,16},title="y offset",fSize=12,limits={-inf,inf,0.0001},value= root:Analysis_Parameters:y_offset_fit//, proc=Set_Value
Button Fit_once,pos={170,270},size={80,20},title="Fit Once",proc=Fit_hand
Button Fit_Def,pos={170,300},size={80,20},title="Fit with Function",proc=Fit_hand
Button Copy_vals ,pos={170,330},size={80,40},title="Copy fit vals\rto template",proc=Fit_hand

If (absolute==0)
	p=-1
	else
	p=1
endif

end

Function Fit_hand(B_Struct):Buttoncontrol
	STRUCT WMButtonAction &B_Struct
	STRUCT WMCheckboxAction CB_Struct
	if (B_Struct.eventcode!=2)
		return 0
	endif
	wave /t W_Wavelist
	wave AVG_d
	Wave /D W_coef
	NVar/sdfr=root:Analysis_Parameters G_Rise_Tau, G_Decay_Tau, x_offset_fit, y_offset_fit, Amplitude_PSC_fit, G_Mini_Size
	Variable Absolute=1
	ControlINfo /W=Analysis_minis Positive
	if (V_Value==0)
		Absolute=-1
	endif
	GEtwindow Template_and_AVG#EPSCTemplate wavelist
	wave temp=$W_Wavelist[0][0]
	StrSwitch (B_Struct.CtrlName)
		Case "Fit_Once":	
			Make/o/n=200 fit_AVG_d=amplitude_PSC_fit*Absolute*(1-exp(-(x*deltax(temp))/G_Rise_Tau))*  (exp(-(x*deltax(temp))/G_Decay_Tau))+AVG_d[0]
			setscale /p x,x_offset_fit,deltax(temp),"s",fit_AVG_d
			deletepoints G_Mini_Size-round(x_offset_fit/deltax(temp)), numpnts(fit_AVG_d)-1-(G_Mini_Size-round(x_offset_fit/deltax(temp))), fit_AVG_d
		break
		Case "Fit_Def":
			
			Make/D/N=6/O W_coef
			W_coef[0] = {G_Decay_Tau,G_Rise_Tau, absolute, amplitude_PSC_fit, y_offset_fit, x_offset_fit}
			FuncFit /Q /H="001000" PSC W_coef AVG_d[x2pnt(AVG_d,x_offset_fit),inf] /D
			//fit_AVG_d-=AVG_d[0]
		break
		Case "Copy_vals":
			G_Decay_Tau=W_coef[0]
			G_Rise_Tau=W_coef[1]
		break
		
	EndSwitch
	findValue /TEXT="fit_AVG_d" W_Wavelist
	if (V_Value==-1)
		appendtograph /W=Template_and_AVG#EPSCTemplate fit_AVG_d
	endif
	ModifyGraph /W=Template_and_AVG#EPSCTemplate lstyle(fit_AVG_d)=7,rgb(fit_AVG_d)=(1,16019,65535)
	killwaves /z W_Wavelist
	
end


// 56 ******************************************************************************************************

//Handles all buttons actions
Function Instructions_Handling(B_Struct):Buttoncontrol
	STRUCT WMButtonAction &B_Struct
	STRUCT WMCheckboxAction CB_Struct
	if (B_Struct.eventcode!=2)
		return 0
	endif
	StrSwitch (B_Struct.ctrlName)
		Case "ok":
			Killwindow Instructions
			Break
		Case "Cancel_It":
			Killwindow Analysis_Minis
			Break
		Case "Cancel_Pan":
			KillWindow All_Histograms
			Break
		Case "Cancel_Seg":
			KillWindow Mini_Seg
			Break
		Case "Cancel_Select":
			KillWindow What_to_do
			Break
		Case "Cancel_Load":
			Dowindow/K WaveSelector
			Break
		Case "My_Bad":
			Dowindow/K Instructions
			Break
		Case "Err_Button":
			Killwindow /Z Error_Msg
			Break
		Case "New":
			DFR()
			Break
		Case "Existing":
			WaveSelectorPanel(B_Struct.ctrlName)
			Break
		Case "Select_Waves":
			WaveSelectorPanel("Select_Waves")
			Break
		Case "Copy_Params":
			copy_Wave()
			Break
		Case "	Create_EPSC_Template":
			Display_EPSC_Template(B_Struct.ctrlName)
			Break
		Case "New_Analysis":
			New_Analysis()
			Break
		Case "AVG_PSC":
			Make_AVG_PSC(B_Struct.ctrlName)
			Break
		case "Display_Wave":
			DIsplay_mini_Graph()
			break
		case "isolate":
			Controlinfo /W=Analysis_Minis Use_Template
			if (V_Value)
				I_template(CB_Struct)
			endif
			DS_isolateminis()
			break
		Case "Plot":
			DS_plothistograms(B_Struct.ctrlName)
			Break
		Case "Update":
			DS_plothistograms(B_Struct.ctrlName)
			Break
		Case "killallresults":
			DS_killallresults()
			Break
		Case "Delete":
			pressdelete("Delete")
			Break
		Case "pressnext":
			pressnext(B_Struct.ctrlName)
			Break
		Case "pressprevious":
			pressnext(B_Struct.ctrlName)
			Break
		Case "Done":
			Done(B_Struct.ctrlName)
			Break
		Case "Existing_Exp":
			Done(B_Struct.ctrlName)
			Break
		Case "Run_Deconv":
			Deconvolve(0)
			Break
		Case "Rerun_Peak_Dec":
			Wave /z Deconvolved
			Get_Peak(Deconvolved,0)
			Break
		Case "Filter_by_Deconv":
			Controlinfo /w=Analysis_minis Deconvolution_Action
			Strswitch (S_Value)
				Case "Intersec":
					Filter_by_Deconvolution()
					Break
				Case "Combine":
					Combine()
					Break
			endswitch	
			Break
		Case "Create_EPSC_Template":
			Display_EPSC_Template(B_Struct.ctrlName)
			Break
	EndSwitch
end


Function An_Params_Load_or_Save(Pop_act) : PopupMenuControl

	Struct WMPopupAction & Pop_act
	if (Pop_act.eventcode!=2)
		return 0
	endif
	StrSwitch (Pop_act.popStr)
		Case "Load From File":
			Analysis_Params("read")
			Break
		Case "Save to File":
			Analysis_Params("Write")
			Break
		Case "Copy from previous analysis": 
			WaveSelectorPanel("Copy") 
			Break	
	endswitch
end

Function PSC(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = a*p*(1-exp(-(x-xoff)/G_Rise_Tau))*  (exp(-(x-xoff)/G_Decay_Tau))+k
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 6
	//CurveFitDialog/ w[0] = G_Decay_Tau
	//CurveFitDialog/ w[1] = G_Rise_Tau
	//CurveFitDialog/ w[2] = p
	//CurveFitDialog/ w[3] = a
	//CurveFitDialog/ w[4] = k
	//CurveFitDialog/ w[5] = xoff

	return w[3]*w[2]*(1-exp(-(x-w[5])/w[1]))*  (exp(-(x-w[5])/w[0]))+w[4]
End
