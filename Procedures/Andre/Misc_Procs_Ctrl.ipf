#pragma rtGlobals=1		// Use modern global access method.

Menu "Andre"
	"Remove Evoked Artifacts", Artifact_Panel()
	"Load Igor Experiment", Load()
	"Correct wavename", Set()
	"Miscellaneous Analysis", Analysis_Win()
	"AP Analysis", AP_Handling()
end

Function Analysis_Win()
dowindow Meu_Teste
if (V_flag)
	Killwindow Meu_Teste
endif
Variable/G Indice_Global, Matador_de_Janela,Controle_Grafico_Corrente=0, Controle_Grafico_Atualizado=0,BoxSize=1
Matador_de_janela=0
String/G Nome_Janela_Top
String /G root:Wild_Card
Svar /SDFR=root: Wild_Card
	Variable popNum
	String popStr	
NewPanel /K=1 /W=(100,0,520, 500) /N=Meu_Teste
Nome_Janela_Top="Meu_Teste"
Execute "ModifyPanel cbRGB = (61166, 61166, 61166)"		// grey background

Checkbox Mode_1 win=Meu_teste, pos={5,13}, title="", value=1, proc=CHeckbox_Mode
PopUpMenu NomeGrafico pos = {20,10},size={50,10}, Title = "Select a Graph"
Checkbox Mode_2 win=Meu_teste, pos={173,13}, title="", proc=CHeckbox_Mode

Setvariable Wild_C title= "or use a "+num2char(34)+"Wild Card"+num2char(34)+":", bodywidth=80, value=Wild_Card, Pos={330,10}

if (strlen(WinList("*",";","win:1"))==0)
	PopUpMenu NomeGrafico Value ="No Graph Available"
	else
	PopUpMenu NomeGrafico Value = sortlist(WinList("*",";","win:1"),";",16)
endif
PopUpMenu NomeGrafico proc=StrTxt
StrTxt2()

//Button Media pos= {5,50}, size = {90,20}, title = "Average Waves", proc = Set_Graph_Datafolder
checkbox Media pos= {5,50}, size = {90,20}, title = " Average Waves", proc = CHeckbox_Handling
//Button Plot pos={110,50}, size={90,20}, title="Plotting PM", proc=plota

//Button IV pos= {5,70}, size = {90,20}, title = "IV / VI", proc = Set_Graph_Datafolder//IV_VI
checkbox IV pos= {5,70}, size = {90,20}, title = " IV / VI", proc=CHeckbox_Handling


//Button Cut pos={110,110}, size = {90,20}, Title="Cut Wave"
//Button Cut proc = Set_Graph_Datafolder
checkbox Cut 							win=MEu_Teste, pos={5,90}, size = {90,20}, Title="Cut Wave", proc=CHeckbox_Handling
//Button Zero_Baseline pos={110,130}, size={90,20}, Title="Offset", proc=Set_Graph_Datafolder
Checkbox Zero_Baseline 				win=MEu_Teste, pos={5,110}, size={90,20}, Title="Offset", proc=CHeckbox_Handling
Checkbox Minimum 						win=MEu_Teste, pos={5,130}, size={90,20}, Title="Min Val", proc=CHeckbox_Handling
Checkbox Maximum 						win=MEu_Teste, pos={5,150}, size={90,20}, Title="Max Val", proc=CHeckbox_Handling
checkbox Retrieve_waves 				win=MEu_Teste, pos= {110,50}, size = {90,20}, title = "Retrieve Waves", disable=2, proc = CHeckbox_Handling
checkbox Evoked_artifact_Removal 	win=MEu_Teste, pos= {110,53}, size = {90,20}, title = " \rRemove Stim\rArtifact", proc = CHeckbox_Handling
Checkbox V_Hold 						win=MEu_Teste, pos={110,90}, size={90,20}, Title="Print Baseline", proc=CHeckbox_Handling

Button Run pos={5,170}, size = {90,40}, fsize=24, Title="GO", proc=Set_Graph_Datafolder
Button Cancela pos = {110, 170}, size = {90, 40}, fsize=20, title = "Close", proc = Kill_Window

end 

//***************************************************
function Lista()

Wave/t Wave_Geral
listbox Ondas size={200,150}, mode=2, pos={200,10}, win=Meu_Teste, listwave=Wave_Geral
listbox Ondas proc=Dribla_Bug
insight()
end


//***************************************************

Function Changewavecolor()

	String/g Wave_Selecionada,Ondas
	Wave/t Wave_Geral
	if (Strlen(Wave_Geral[0])==0)
		return 0
	Endif
	ControlInfo Ondas
	Wave_Selecionada= stringfromlist(itemsinlist(Wave_Geral[V_value],":")-1,Wave_Geral[V_value],":")
	removefromgraph /W=Meu_Teste#Mini_Graph $Wave_Selecionada
	Modifygraph/w=Meu_Teste#Mini_Graph rgb=(47872,47872,47872)
	Appendtograph /w=Meu_Teste#Mini_Graph $Wave_Geral[V_value]
	Modifygraph/w=Meu_Teste#Mini_Graph rgb($Wave_Selecionada)=(0,0,0)
end
	
//***************************************************
Function Kill_Window(Kill_Action) : Buttoncontrol
	Struct WMButtonAction & Kill_Action
	if (Kill_Action.eventcode==2)
		StrSwitch (Kill_Action.CtrlName)
			Case "Meu_Teste":
				Killwindow Meu_Teste
				Break
			Case "Cancela":
				Killwindow Meu_Teste//Cutting_Window
				Break
			Case "Cancel_IV_Input":
				SVar /SDFR=Root: Nomegraf
				Killwindow $Nomegraf+"#input"
				Break
			Case "Cancel_Art_Hand":
				Killwindow Artifact_Removal
				Break
			Case "Set_Csr":
				Killwindow Cursor_Error
				//Killwindow Artifact_Removal
				Break
			Case "Cut_Cancela":
				Getwindow kwTopWin, activesw
				killwindow $S_Value
				Break
		Endswitch
	endif
End
//***************************************************

Function Set_Graph_Datafolder(Button_Struct) : Buttoncontrol
	Struct WMButtonAction & Button_Struct
	dowindow Meu_Teste
	if (V_Flag==0)
		abort
	endif
	Controlinfo /W=Meu_teste NomeGrafico
	
	String Graph = S_Value 
	dowindow $Graph
	if (V_Flag==0)
		abort
	endif
	Make/o/n=(1,3) /t W_Wavelist
	Getwindow $graph, wavelist
	string WV_Name=W_Wavelist[0][1]
	killwaves /z W_Wavelist
	setdatafolder GetWavesDataFolder($WV_Name,1)
	Svar /SDFR=root: Selected_Chk
	String test=StrVarOrDefault("root:Selected_Chk", " " )
	if (strlen(test)==1)
	//print "ok"
	abort
	endif
	
	if (Button_Struct.eventcode==2)
		StrSwitch (Selected_Chk)
			Case "IV":
				IV_VI()
				break
			Case "Cut":
				Cut()
				Break
			Case "Media":
				//Media_Waves_Graph()
				ControlInfo /W=Meu_Teste Mode_1
				Svar /SDFR=root: Wild_Card
				If (V_Value)
				Averages("Use_Graph")
				else
				Averages(Wild_Card)
				endif
				Break
			Case "Zero_Baseline":
				Zera()
				Break
			Case "Minimum":
				Imin()
				Break
			Case "Maximum":
				Imax()
				Break 
			Case "Evoked_artifact_Removal":
				Artifact_Panel_AO()
				Break
			Case "V_Hold":
				Print_Hold()
				Break
		Endswitch
	endif
end



Function /t Check_Wavename(Wave_Name)
	String Wave_Name
	String Name_Check=Wave_Name
	Variable i=-1
	if (waveexists($wave_name))
		do
			i+=1
			Name_Check=Wave_Name+Num2str(i)
		while(waveexists($Name_Check))
	endif
	return Name_Check
End

Function CHeckbox_Handling(Chk_Struct) : Checkboxcontrol
	Struct WMCheckBoxAction & Chk_Struct
	String /G root:Selected_Chk
	Checkbox Media 							win=Meu_teste,  value=0
	Checkbox Cut 							win=Meu_teste, value=0
	Checkbox IV 								win=Meu_teste, value=0
	Checkbox Zero_Baseline 				win=Meu_teste, value=0
	Checkbox Minimum 						win=Meu_teste, value=0
	Checkbox Maximum 						win=Meu_teste, value=0
	Checkbox Retrieve_waves 				win=Meu_teste, value=0
	Checkbox Evoked_artifact_Removal 	win=MEu_Teste, value=0
	CheckBox V_Hold							win=MEu_Teste, value=0
	Svar /sdfr=root: Selected_Chk
	Selected_Chk=Chk_Struct.ctrlname
	Checkbox $Chk_Struct.ctrlname 		win=Meu_teste, value=1
end

Function CHeckbox_Mode(Chk_Struct) : Checkboxcontrol
	Struct WMCheckBoxAction & Chk_Struct
	Variable M1, M2
	StrSwitch (Chk_Struct.CtrlName)
		Case "Mode_1":
			M1=0
			M2=2
			Checkbox Mode_1 win=Meu_Teste, Value=1
			Checkbox Mode_2 win=Meu_Teste, Value=0
			listbox Ondas win=Meu_Teste, disable=0//, Listwave=Wave_Geral
		Break
		Case "Mode_2":
			M1=2
			M2=0
			Checkbox Mode_1 win=Meu_Teste, Value=0
			Checkbox Mode_2 win=Meu_Teste, Value=1
			listbox Ondas win=Meu_Teste, disable=2
		Break
	EndSwitch
//	Checkbox Media win=Meu_teste,  disable=0
	Checkbox Cut 							win=Meu_teste, disable=M1
	Checkbox IV 								win=Meu_teste, disable=M1
	Checkbox Zero_Baseline 				win=Meu_teste, disable=M1
	Checkbox Minimum 						win=Meu_teste, disable=M1
	Checkbox Maximum 						win=Meu_teste, disable=M1
	CheckBox Evoked_artifact_Removal 	win=MEu_Teste, disable=M1

//	Popupmenu NomeGrafico win=Meu_Teste, disable=M1
	
	Checkbox Retrieve_waves win=Meu_teste, disable=M2
//	Setvariable Wild_C win=Meu_Teste, disable=M2
end
//***************************************************

Function Pop_EixoY(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum	
	String popStr		
PopupMenu EixoY pos = {5,40}
Popupmenu EixoY Title = "The Wave",value= listas()
Popupmenu EixoY proc = Insight
end
//***************************************************
function/s Listas()
controlinfo NomeGrafico
make/o/n=1/t Uno=s_value
string/g Listat=	Wavelist("*",";","Win:"+Uno[0])
return Listat
end

//***************************************************
Function Dribla_Bug(Ondas,row,col,event) : ListboxControl
	String Ondas     // name of this control
	Variable row        // row if click in interior, -1 if click in title
	Variable col        // column number
	Variable event
Nvar Indice_Global
if (Indice_Global==2)
	Indice_Global=0
	insight()
	
	Abort
endif
Indice_Global+=1
end
//***************************************************
Function Insight ()
controlinfo Ondas
Nvar Matador_de_Janela
variable index, Ind_Ondas=V_Value
String Ondas=""
Nvar Controle_Grafico_Corrente, Controle_Grafico_Atualizado
wave/t Wave_Geral
//wavestats/q Wave_geral

dowindow/W=Meu_teste Mini_graph 
controlInfo Nomegrafico
Setdrawlayer /w=meu_teste /k UserFront

Setdrawlayer /w=meu_teste UserFront
drawtext /w=Meu_Teste 220,67, "Waves in "+s_value+":"
wave /t W_Wavelist
getwindow $S_Value, wavelist
for (index=0;index<dimsize(W_Wavelist,0);index+=1)
Ondas+=W_Wavelist[index][1]+";"
endfor
//if (numpnts(Wave_Geral)!=itemsInList(Ondas) && strlen(Wave_Geral[0])==0)
	make /o /n=(itemsinlist(ondas)) /t Wave_Geral
	for (index=0;index<itemsInList(ondas);index+=1)
		Wave_Geral[index]=stringfromList(index,ondas)
	endfor
//endif
index=0
//tracenamelist(S_Value,";",1)
controlInfo /w=Meu_Teste Nomegrafico

Controle_Grafico_Atualizado=V_Value
if (Controle_Grafico_Atualizado==Controle_Grafico_Corrente)
	Changewavecolor()
	abort
else
	if (Matador_de_Janela>0)
		Killwindow Meu_Teste#Mini_Graph
	endif
	Matador_de_Janela+=1
	display/n=Mini_Graph  /host=Meu_Teste /w= (10, 220, 400, 450)
	Controle_Grafico_Corrente=V_Value
	Variable Controle_Stim
	do
		if (strlen(stringfromlist(index, Ondas))==0)
			break
		endif
		if (stringmatch(stringfromlist(index, Ondas),"*stim")==1)
			appendtograph/L=L2 /W=Meu_Teste#Mini_graph $Wave_Geral[index]
			Controle_stim=1
		
		else
			appendtograph/L=Left /W=Meu_Teste#Mini_graph $Wave_Geral[index]
		endif
		index+=1
	
	while(1)
	if (Controle_Stim==1)
		ModifyGraph axisEnab(L2)={0.51,1}
		ModifyGraph axisEnab(Left)={0,0.49}
		wave Onda_Eixo_X=$(stringbykey("cwave",(axisinfo ("Meu_Teste#Mini_graph","bottom")),":"))
		ModifyGraph freePos(L2)={Onda_Eixo_X[0],bottom}
		ModifyGraph lblPos(L2)=40
	endif
	Controle_Stim=0
	Changewavecolor()
endif
end
//***************************************************
function StrTxt(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr	
StrTxt2()
end

Function StrTxt2()
Variable Index

ControlInfo NomeGrafico
if (WaveExists(Wave_Geral)==1)
	Killwaves Wave_Geral
endif

if (v_value<1)

abort
endif

String Lista_Geral=""
if (Stringmatch(S_Value,"No Graph Available"))
	Lista_Geral=""
else
	Wave /t W_Wavelist
	getwindow $S_Value, wavelist 
	for (index=0;index<dimsize(W_Wavelist,0);index+=1)
		Lista_Geral+=W_Wavelist[index][1]+";"
	endfor
	print lista_geral
	
//	Lista_Geral=Wavelist("*",";","Win:"+s_value)
endif
Make/o/t/n=1 Wave_Geral
do
if (strlen(stringfromlist(index,Lista_Geral))==0)
	break
endif
if (index==0)
	Wave_Geral[index]=stringfromlist(index,Lista_geral)
	else
	insertpoints (index-1),1,Wave_Geral
	Wave_Geral[index-1]=stringfromlist(index,Lista_geral)
endif
index+=1
while(1)
sort/a Wave_Geral,Wave_Geral

	Lst()

end

//***************************************************


function Lst()
Wave/t Wave_Geral
listbox Ondas size={180,130}, mode=2, pos={220,70}, win=Meu_Teste, listwave=Wave_Geral
listbox Ondas proc=Dribla_Bug
Insight()
end
