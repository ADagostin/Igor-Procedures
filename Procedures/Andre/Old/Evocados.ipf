#pragma rtGlobals=1		// Use modern global access method.


function Field_Evocado(CtrlName):ButtonControl  //Separa todos os sweeps evocados das waves do PCLAMP 10 (eles vêm concatenados)
string CtrlName
string Nomegraf, Lista, Nome_Onda
variable Delay, Pico1,Pico2, Duracao, Ponto1,Ponto2, index,i
Controlinfo /w=meu_teste NomeGrafico
Nomegraf=S_Value
Lista=wavelist("!Fit*",";","win:"+Nomegraf)
Wave Wv=$stringfromlist(0,lista)
findpeak/q /m=60 Wv
Pico1=round(V_Peakloc)
findpeak/q/r=[(Pico1+100),numpnts(Wv)] /m=60 Wv
Pico2=round(V_Peakloc)
Duracao=Pico2-Pico1
Ponto1=0
make/o/n=(duracao) Wv_Media
do
	Ponto2=Ponto1+duracao
	Nome_Onda= "Stim_"+stringfromlist(0,lista)+"_"+num2str(index)
	duplicate/o/r=[Ponto1,Ponto2] Wv, TEMP
	setscale /p x 0,0.0001,"s",TEMP
	variable baseline=mean(TEMP,0,100)
	wavestats/q TEMP
	for (i=v_maxloc-10;i<v_maxloc+10;i+=1)
		TEMP[i]=mean(TEMP, v_maxloc-20+i,  V_Maxloc-10+i)
	endfor
	Ponto1=Ponto1+Duracao
	index+=1
	duplicate/o TEMP, $Nome_onda
	Wv_Media=Wv_Media+TEMP
while(ponto1<numpnts(Wv))
Wv_Media=Wv_Media/index
Killwaves TEMP
Nome_Onda= "Stim_"+stringfromlist(0,lista)+"_Media"
dUPLICATE/O Wv_Media, $Nome_Onda
killwaves Wv_Media
setscale /p x 0,0.0001,"s",$Nome_Onda
end
//**********************************************************88

function alinha()
variable Pto_Alinhamento, i
String Nomegraf, Lista
Controlinfo /w=meu_teste NomeGrafico
Nomegraf=S_Value
Lista=wavelist("!Fit*",";","win:"+Nomegraf)
print lista
wavestats/q $stringfromlist(0,Lista)
Pto_Alinhamento=v_maxloc
for (i=1;i<itemsinlist(lista);i+=1)
	wavestats/q $stringfromlist(i,Lista)
	if (v_maxloc<Pto_alinhamento)
		Pto_alinhamento=v_maxloc
	endif
endfor
for (i=0;i<itemsinlist(lista);i+=1)
	wavestats/q $stringfromlist(i,Lista)
	if (V_maxloc>Pto_alinhamento)
		deletepoints 0, x2pnt($stringfromlist(i,Lista),(v_maxloc-pto_alinhamento)), $stringfromlist(i,Lista)
	endif
endfor
end
//%%%%%%%%%%%%%%%%%%%%%%%
//Manages all the "Cancel" buttons and window killing
Function Kill_Info_Window(Ctrlname):Buttoncontrol
String CtrlName
StrSwitch (CtrlName)
	Case "Cancela":
		Killwindow Evocados
	break
	Case "Ok_Artifact":
		Killwindow Instructions
	Break
EndSwitch
End
//??????????????????????????????????????????
//Replaces the values Between cursor A and B in a specific graph by NaN
// It is intended to remove the stimulation artifact from a Wave to improve its visualization
//Cursos A and B MUST be present and limiting the so called artifact
function Corta_Artefato(CtrlName):ButtonControl  
string CtrlName
string nomegraf, Lista, Onda
variable i,j,Max1,Max2
ControlInfo/W=Meu_Teste Nomegrafico
NomeGraf=S_value
Lista=wavelist("!Fit*",";","win:"+Nomegraf)
String/g Info="Place cursors A and B on window "+Num2char(34)+Nomegraf+Num2char(34)+"!"
if (Strlen(Csrinfo(A,NomeGraf))<1 || Strlen(Csrinfo(B,NomeGraf))<1)
	newpanel /k=1 /n=Instructions /w=(300,200,700,350)
	Titlebox  TB1, Fsize=16, Frame=0, Anchor=LT, Pos={20,20}, Size={1,1}, Variable= Info
	Button Ok_Artifact, Win=Instructions, Fsize=18, pos={90,85}, Size = {200,40}, Title="Got it!", proc=Kill_Info_Window
	Abort
Endif
ControlInfo/W=Evocados Keep_Original
for (i=0;i<itemsinlist(Lista);i+=1)
	If (V_Value==0)
		Duplicate/o Wv, $stringfromlist(i,lista)+"_Artif"
		Else
		Wave Wv =$stringfromlist(i,lista)
	EndIf
	for (j=Pcsr(A,NomeGraf);j<Pcsr(B,NomeGraf);j+=1)
			Wv[j]=NaN // Replaces the wave point by a "Not a number" value. 
	endfor
	
endfor
end

//**********************************************************88888
function slope(Ctrlname):ButtonControl // Calcula o Slope do potencial (usuário quem define o ponto de mensuração)
string Ctrlname
Slope_Amplitude(0)

end
//**********************************************************88888
function Slope_Amplitude(Controle) //Plota uma wave (wave 0) e disponibiliza os cursores para marcação da wave a ser analisada
Variable Controle
variable/g Ctrl
ctrl=Controle
Dowindow/F Evocados
//TextBox /G= /B=1 /F=0 /N=Setting /A=Lb /X=20 /Y=10 



String/g Lista=wavelist("!Fit*",";","Win:Evocados#Mini_Graph_Evocados")
wave Wv=$stringfromlist(0,Lista) 

killwindow Evocados#Mini_Graph_Evocados

display/n=Mini_Graph_Evocados_Single_Wave  /host=Evocados /w= (15, 70, 402, 270) Wv
Cursor /A=1 /w=Evocados#Mini_Graph_Evocados_Single_Wave A  $stringfromlist(0,Lista) ,pnt2x($stringfromlist(0,Lista) ,numpnts($stringfromlist(0,Lista))/2)
Cursor /A=1 /w=Evocados#Mini_Graph_Evocados_Single_Wave B  $stringfromlist(0,Lista) ,pnt2x($stringfromlist(0,Lista) ,numpnts($stringfromlist(0,Lista))/2)
button BotaoOK, Win=Evocados, disable=0, title="Continue", size= {60,20}, pos={180,300}, proc = OK_evoc
SetDrawEnv/W=Evocados TextRGB=(65280,0,0)
Drawtext /W=Evocados 10,290, "  ********************Position the Cursosrs and hit OK********************"
//pauseforuser Evocados#Mini_Graph_Evocados_single_Wave
//ControlInfo /W=Meu_Teste NomeGrafico

//if (Ctrl==1)
//	Amplitude_Evocado(S_Value)
//endif
//if (ctrl==0)
//	Inclina(S_value)
//endif
//dowindow /k Evocados
end
//**********************************************************88888
function OK_evoc(CtrlName):ButtonControl // Faz o serviço de medidas de Slope/Amplitude  e cria as waves finais
string ctrlname
NVar Ctrl
Variable i
Svar Lista
wave W_Coef
variable/g Pa, Pb
pauseupdate
Pa=pcsr(a, "Evocados#Mini_Graph_Evocados_Single_Wave")
Pb=pcsr(b, "Evocados#Mini_Graph_Evocados_Single_Wave")
killwindow Evocados#Mini_Graph_Evocados_Single_Wave
Insight_Evocado()
doupdate
ControlInfo /W=Meu_Teste NomeGrafico


if (Ctrl==1)
//	Amplitude_Evocado(S_Value)
endif
if (ctrl==0)
	Inclina(S_value)
endif
dowindow /k Evocados
end
//****************************************************************************
Function Janela_Evocados(Ctrlname):ButtonControl //Cria a janela de análise dos eventos evocados
string Ctrlname
variable/g Controle
sVar Nome_Janela_Top
Dowindow/K Evocados
NewPanel /K=1 /W=(100,0,520, 350) /N=Evocados
Nvar Matador_de_Janela
String/g Data_Folder_Name=""
Nome_Janela_Top="Evocados"
Execute "ModifyPanel cbRGB = (61166, 61166, 61166)"		// grey background

Button Slope pos= {105,5}, size = {90,20}, title = "Slope", proc = Slope

Button Cancela pos = {305, 5}, size = {90, 20}, title = "Cancela"
Button Cancela proc = Kill_Info_Window
Button Corta_Artefato pos={5,5}, size= {90,20}, title = "Corta Artefato", proc= Corta_Artefato
Checkbox Keep_Original  Pos={5,35}, Size={30,20}, Title="Kill original waves", NoProc
//Button Amplitude pos={105,35}, size= {90,20}, title = "Amplitude", proc= Amplitude
Checkbox Data_Org  Pos={135,35}, Size={30,20}, Title="New DataFolder Name:", fColor=(26112,26112,26112), Proc=Set_DF_Name
Setvariable DF_Name BodyWidth=100, Pos={170,35}, Size={200,20}, Value=Data_Folder_Name, Title=" ", Disable=1
Button Separa_Sweeps pos={205, 5}, size={90,20}, title="Separa Estímulos", proc= Field_Evocado

insight_Evocado()
end
//0000000000
Function Set_DF_Name(CtrlName, Check):CheckboxControl
String CtrlNAme
Variable Check
If (Check==0)
	Setvariable DF_Name Disable=1
	CheckBox Data_Org fColor=(26112,26112,26112)
	Else
	Setvariable DF_Name Disable=0
	CheckBox Data_Org fColor=(0,0,0)
	Organize_Data("Define_DF_Name")
EndIf
end

//****************************************************************************
Function Insight_Evocado () //Cria a miniatura
controlinfo Ondas
variable index,i, Ind_Ondas=V_Value
String Ondas
ControlInfo /W=Meu_Teste NomeGrafico
Make/o/t/n=1 Wave_Geral
String Lista_Geral=Wavelist("!Fit*",";","Win:"+s_value)
for (i=0;i<itemsinlist(Lista_Geral);i+=1)
	if (i==0)
		Wave_Geral[i]=stringfromlist(i,Lista_geral)
	else
		insertpoints (i-1),1,Wave_Geral
		Wave_Geral[i-1]=stringfromlist(i,Lista_geral)
	endif
endfor
sort/a Wave_Geral,Wave_Geral
dowindow/W=Evocados Mini_Graph_Evocados
controlInfo Nomegrafico
Ondas=tracenamelist(S_Value,";",1)
display/n=Mini_Graph_Evocados  /host=Evocados /w= (15, 70, 402, 270)
modifypanel /w=Evocados#Mini_Graph_Evocados frameinset=-2, framestyle=1

Variable Controle_Stim
do
	if (strlen(stringfromlist(index, Ondas))==0)
		break
	endif
	if (stringmatch(stringfromlist(index, Ondas),"*stim")==1)
		appendtograph/L=L2 /W=Evocados#Mini_graph_Evocados $Wave_Geral[index]
		Controle_stim=1
	else
		appendtograph/L=Left /W=Evocados#Mini_graph_Evocados $Wave_Geral[index]
	endif
	index+=1
while(1)
if (Controle_Stim==1)
	ModifyGraph axisEnab(L2)={0.51,1}
	ModifyGraph axisEnab(Left)={0,0.49}
	wave Onda_Eixo_X=$(stringbykey("cwave",(axisinfo ("Evocados#Mini_graph_Evocados","bottom")),":"))
	ModifyGraph freePos(L2)={Onda_Eixo_X[0],bottom}
	ModifyGraph lblPos(L2)=40
endif
Controle_Stim=0
Changewavecolor()
end

//***********************************************************

Function Inclina(graph)
string Graph
string lista
variable Pto1_Amp,Pto2_Amp, Scale1,Scale2, Minimo, ScaleX1,ScaleX2, Amplitude,i
variable Pto_Restricao_1, Pto_Restricao_2,k
Nvar Pa, Pb


lista=wavelist("!Fit*",";","win:"+Graph)
cursor/p /a=1 /w=$graph a $stringfromlist(0,lista), Pa
cursor/p /a=1 /w=$graph b $stringfromlist(0,lista), Pb

DoWindow/F $Graph
for (k=0;k<itemsinlist(lista);k+=1)
	if (stringmatch(stringfromlist(k,lista),"fit*")==0)
		duplicate/o $stringfromlist(k,lista),Davez
		wavestats/q/r=[pcsr(A,Graph),pcsr(B,Graph)] Davez
		Scale2=x2pnt(Davez,V_Minloc)
		Minimo=V_Minloc
		Pto2_Amp=V_min
		wavestats/q/r=(xcsr(A,Graph),minimo) Davez
		Scale1=x2pnt(Davez,V_Maxloc)
		ScaleX1=V_Maxloc
		Pto1_Amp=V_max
		Amplitude = abs(Pto2_Amp-Pto1_Amp)
		Pto_Restricao_1=10
		Pto_Restricao_2=90
		for (i=scale1;i<scale2;i+=1)
			if (davez[i]<(pto1_amp-(Amplitude/Pto_Restricao_1)))
				cursor /a=1 /w=$graph C  $stringfromlist(i,lista) pnt2x(davez,i)
				scale1=i
				break
			endif
		endfor
		for (i=scale2;i>scale1;i-=1)
			if (davez[i]>(pto2_amp+(Amplitude/Pto_Restricao_1)))
				cursor /a=1 /w=$graph D  $stringfromlist(i,lista) pnt2x(davez,i)
				scale2=i
				break
			endif
		endfor
		CurveFit/q/NTHR=0 line $stringfromlist(k,lista)[Scale1,Scale2] /D 
	
		wave W_Coef
		if (k==0)
			Make/o/n=1 Inclinacao
		Else
			insertpoints k,1,Inclinacao
		endif
		Inclinacao[k]=W_Coef[1]
	endif
endfor

Organize_Data(Graph)
mudacor(Graph)
end

//*****************************************************
function mudacor(Graph)
String Graph
Dowindow /F $Graph
string lista
variable k
ControlInfo /W=Meu_Teste NomeGrafico
lista=WaveList("Fit*",";","")
for (k=0;k<itemsinlist(lista);k+=1)
if (stringmatch(stringfromlist(k,lista),"fit*")==1)
	ModifyGraph lsize($stringfromlist(k,lista))=1.3
	Modifygraph rgb($stringfromlist(k,lista))=(0,0,0)
endif
endfor
end
//*****************************************************
Function Organize_Data(Graph)
String Graph
Variable i,k
String New_DF
SVar Data_Folder_Name
Do
	New_DF="Data_"+Num2Str(i)
	If (DatafolderExists(New_DF)!=0 && StringMatch (Data_Folder_Name,New_DF)==0)
		i+=1
	else
		If (Stringmatch(Graph,"Define_DF_Name")!=1)
			Newdatafolder $New_DF
		Endif
		Break
	endif
While(DatafolderExists(New_DF)!=0)
If (Stringmatch(Graph,"Define_DF_Name")!=1)
	String List=Wavelist("*",";","Win:"+Graph)
	New_DF="root:"+New_DF+":"
	For (k=0;k<itemsinlist(List);k+=1)
		MoveWave $StringFromlist(k,List),$New_DF
	EndFor
Else
	If (Strlen(Data_Folder_Name)==0)
		Data_Folder_Name=New_DF
	EndIF
EndIF
End
