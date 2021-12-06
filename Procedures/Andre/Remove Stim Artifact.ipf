#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//This function was designed to remove artifacts from evoked events by selecting, with cursors A and B, the first stimulation artifact of a train of stimulus.
//It demands a graph as reference to get the cursor positioning from

Function Artifact_Panel_AO()
string Ctrlname
Variable /G  root:Tolerance=0.9
String/g Name=""
DoWindow/k Artifact_Removal
NewPanel /N=Artifact_Removal /W=(100,100,370, 220) /K=1 as "Remove Evoked Artifact"

Nvar /sdfr=root: Tolerance
//CheckBox All_Waves Win=Artifact_Removal, Value=0, Title="Analyze all Waves", Side=0, pos={20,95}, Proc=All_Waves_AO
Setvariable Tolerance Bodywidth=50, noproc, pos={220,10}, size={30,20}, fsize=16, TItle="Please set the tolerance \r(Default = 0.9)", Value=Tolerance, Limits={0.1,1,0.05}
Button Go Win=Artifact_Removal, pos={20,70}, fsize=16, Size = {90,30}, Title="Go!", proc=List_AO
Button Cancel_Art_Hand Win=Artifact_Removal, fsize=16, pos={150,70}, Size = {90,30}, Title="Cancel", Proc=Kill_Window

End


//0000000000000000000000000000000000000000000000000000000000 The code for choosing which waves will be analyzed
Function List_AO (Ctrlname):ButtonControl
String Ctrlname
String List
Variable i
Svar Name
killwindow Artifact_Removal
Controlinfo /W=Meu_Teste NomeGrafico
String Graph = S_Value //Selected Graph Name
dowindow /f $S_Value
Make/o/n=(1,3) /t W_Wavelist
Getwindow $graph, wavelist
string WV_Name=W_Wavelist[0][1]
killwaves W_Wavelist
setdatafolder GetWavesDataFolder($WV_Name,1)
Controlinfo /w=Meu_Teste Nomegrafico
List=Wavelist("!*Artif",";","Win:"+S_value)
Art_Ult_AO(List,Graph)
End

//00000000000000000000000000000000000000000000000000000000000000000000000000 This will analyze all the waves in the datafolder.
Function Multiple_Waves_Proc_AO(CtrlName):Buttoncontrol
String Ctrlname


if (waveexists($stringfromlist(0,wavelist("*Artif",";","")))==1)
	Execute "Killwaves /z "+ removeending(wavelist("*Artif",",",""))
endif
Controlinfo /W=Meu_Teste Nomegrafico
String List=Wavelist("*",";","Win:"+S_Value)

variable i
	for (i=0;i<itemsinlist(list);i+=1)
		Art_Ult_AO(Stringfromlist(i,list),S_Value)	
	endfor
doupdate

end

//444444444444444444444444444444444444444444444444444444444444444444444444444 This guy is the Maestro, it makes everything happen!
function Art_Ult_AO(List,Graph)
String List,Graph

ControlInfo /W=Meu_teste NomeGrafico
Dowindow/F $S_Value
doupdate

	
	if (strlen (CsrInfo(B))==0 || strlen (CsrInfo(A))==0)
		
		Showinfo
		dowindow Artifact_Removal
		if (V_Value)
		//killwindow Artifact_Removal
		endif
		NewPanel /N=Cursor_Error /W=(450,250,820,380) /K=1 
		TitleBox Error win=Cursor_Error, Frame=3, pos={10,12}, Size={400,10},fsize=18,Title="\JCLimit the artifact with cursors A and B and \rrerun the function"
		Button Set_Csr Win=Cursor_Error, pos={120,80}, fsize=24, Size = {130,40}, Title="Ok, Got it!", Proc=Kill_Window
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
Controlinfo /W=Artifact_Removal Peak_Direction
 
Variable Absolute=-1
//print V_Value
if (V_Value==1)
	Absolute=1
endif
Variable Artifact_Found,j
String Name

Variable Previous_Start, Previous_Variation, Current_Variation
for (h=0;h<itemsinlist(List);h+=1)
//	Make/o/n=1 Amplitudes, Amplitudes_Time,Areas,Baseline =0
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
			Artifact_Found=Slid_Avg_AO(Start,Test)
 		If (Artifact_Found>0)
				Duplicate/o Template, Prev_Template
				duplicate /o/r=[Artifact_Found,Artifact_Found+Artifact_Size] Test, Template
				for (i=0;i<Artifact_Size;i+=1)
					test[i+Artifact_Found]=NaN			
				endfor		
				Variation_DeltaX=Artifact_Found-Previous_Start-Artifact_Size
				Current_Variation=Start-Previous_Start
				The_End=Artifact_Found+Artifact_Size //end of artifact
				Previous_Start=Artifact_Found
				Previous_Variation=Variation_DeltaX
				Start+=Artifact_Size	
				k+=1
			endif	
		Start+=10
	While (Start<Numpnts(test))
	Template=Template_Ori
	Wave_Name=Stringfromlist(h,List)+"_Artif"
	Duplicate/o Test, $Wave_Name

endfor

fill_blank(wave_name)
killwaves/z test,artifact
Dowindow/k Set_Cursor
Wave Template, res, temp, review
Killwaves /z res, temp, template, Template_ori, review, prev_template

end

function fill_blank(wave_name)
String wave_name
wave temp=$wave_name
variable i
for (i=0;i<numpnts(temp);i+=1)
	if (numtype(temp[i])==2)
		//temp[i]=temp[i-1]
	endif
endfor
end

Function Slid_Avg_AO(Start_Pnt,SourceWave)

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
		Wavestats /q Template
		Template_Amp=V_Max-V_Min
		Wavestats/q Prev_template
		Prev_Template_Amp=V_Max-V_Min
		wavestats /q res
		if (V_Max>Tolerance)// && Prev_Template_Amp>=Template_Amp/10)
		Return Look_Forward_AO(Start_Pnt, SourceWave, Template,Template_Size, V_Max)+V_Maxrowloc
		
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

Function Look_Forward_AO(Start, Sourcewave, template, Template_Size, Tolerance)
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






