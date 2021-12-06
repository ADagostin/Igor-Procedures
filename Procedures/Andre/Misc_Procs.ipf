#pragma rtGlobals=1		// Use modern global access method.




//********************************************

//FUNÇÃO TAU
//Calcula, ajustando uma exponencial simples entre os cursores A e B do gráfico, 
//a constante de tempo de um conjunto de Waves inseridas em um gráfico, resultando 
//numa Wave contendo o valor de cada constante de tempo.

function TAU()													//Calcula o TAU1 de um determinado grupo de Waves em um  mesmo intervalo de dados em um ou mais gráficos
	variable analise
	variable NumGraf 												//Número de gráficos a serem usados na análise
	prompt Numgraf, "Quantos Gráficos serão analisados?"
	string Graph 													//O nome do gráfico em que se encontram os cursores
	prompt Graph, "Gráfico Contendo os Cursores"
	doprompt "Gráficos", Graph, NumGraf
	String TraceName 											//O nome do traçado da lista a ser analisado
	Variable Index=0 												//Variável de controle de qual o traçado está sendo selecionado na lista
	variable PtoA=pcsr(A,Graph) 									//Posição do cursor A no gráfico determinado
	variable PtoB=pcsr(B,Graph) 									//Posição do cursor B no gráfico determinado
	String NomeGraf												//Nome do gráfico a ser analisado no momento
	prompt NomeGraf, "Qual o gráfico a ser usado nas análises?"
	String NomeWave 											//Nome da Wave que será criada com os dados de TAU 1
	prompt NomeWave, "Nome da Wave a ser criada como resultado"
	variable MedIndex=NumGraf
	killwaves /a/z
	do
		if(Index==0) 
			doprompt "Dados de Entrada", NomeGraf, NomeWave 
		endif			
		string List=tracenamelist(NomeGraf, ";",1) 					//Lista das Waves que serão usadas
		Tracename=StringFromList(Index,List)  						//Momento no qual é designado um traçado específico à String 'Tracename'
		if(strlen(tracename)==0) 									//Momento no qual não existem mais traçados (Wave "zero")
			NumGraf-=1
			duplicate/o/d TauList, $NomeWave						//A Wave final é criada
		else
				CurveFit/Q exp_XOffset $tracename[PtoA,PtoB] 		//Ajuste da curva
				make/d/o/n=1 Data=(k2)
			if(index==0)
				make/d/o/n=1 Taulist=Data						//na primeira volta do loop, a Wave 'Taulist' é criada
			else
				duplicate/o Taulist, Base
				concatenate/o/np {Base,Data}, Taulist  			//Os valores unitários são adicionados à Wave 'TauList' a partir da segunda volta
			endif
		endif
		Index+=1
		if(strlen(tracename)==0)
			wavestats/q TauList
			make/d/o/n=(V_npnts) Med=(Med+TauList)				//Somatório de todos os valores
			make/d/o/n=(V_npnts) Med1=(Med/(MedIndex))			//Cálculo da média
			Index=0
		endif
		if(NumGraf==0)
			break
		endif
	while(NumGraf>0)
	display $NomeWave
end

//*********************************************************************************************************

//*********************************************************************************************************

Function Print_Hold()
ControlInfo /w=Meu_teste Nomegrafico
	String NomeGraf=S_value
	print NomeGraf
	String XC_a, XC_b
	XC_a=csrInfo(A,NomeGraf)
	XC_b=csrInfo(B,NomeGraf)
//	abort
	If (Strlen(XC_a)==0 || Strlen(XC_b)==0)
		Print "Place both cursors in the target graph"
		abort
	Endif
	dowindow /f $Nomegraf
	String list=wavelist("*",";","Win:"+NomeGraf)
	Variable i, baseline
	for (i=0;i<itemsinlist(list);i+=1)
		Wave Temp=$Stringfromlist(i,list)
		Baseline+=mean(temp, xcsr(a),xcsr(b))
	endfor
	Baseline/=itemsinlist(list)
	Print "Baseline: ",Baseline
end


//*********************************************************************************************************
//Calcula a IV ou a VI (depende do tipo de traçado que está sendo analisado),
function IV_VI()// : ButtonControl
	
	string TraceName											//O nome do traçado da lista a ser analisado
	string /G root:NomeGraf
	String /G root:Nova="IVVI"							//Nome do gráfico a ser analisado no momento
	Svar /SDFR=root: Nova
	SVar /SDFR=root: Nomegraf
	variable Index=0 												//Variável de controle de qual o traçado está sendo selecionado na lista
	variable Data1

	ControlInfo /w=Meu_teste Nomegrafico
	NomeGraf=S_value
	dowindow/f $Nomegraf
//	 List=wavelist("!*stim",";","WIN:"+Nomegraf)
	
//	Dados_Wave_Pulso()
NewPanel/host=$nomegraf /k=1 /N=Input /W=(0,100,270,10) /ext=0
modifypanel/w=$NomeGraf Framestyle=0
execute  "ModifyPanel cbRGB = (61166, 61166, 61166)"
popupmenu  Tipo_IV, title="Type", value="Mean;Positive;Negative;Absolute",pos={5,70}
Setvariable Nome_Wave_IVVI title= "Wave name", bodywidth=180, value=Nova, Pos={180,40}
controlinfo /w=Meu_Teste Nome_Wave_IVVI 
button BotaoOK win=$NomeGraf#Input, disable=0, title="Continue", proc = Continua_IVVI, pos={215,70}
button Cancel_IV_Input win=$NomeGraf#Input, disable=0, title="Cancel", pos={140,70}, proc=Kill_Window
drawtext /w=$nomegraf#input 5,20, "Set Cursors A and B and name upcoming wave"
end

Function Continua_IVVI(IV_Ctrl) : ButtonControl
	Struct WMButtonAction&IV_Ctrl
	if (IV_Ctrl.eventcode!=2)
		return 0
	endif
	Svar /SDFR=root: Nova
	Svar /SDFR=root: NomeGraf
	string TraceName											//O nome do traçado da lista a ser analisado
	string List	 						//Nome do gráfico a ser analisado no momento
	List=wavelist("!*stim",";","WIN:"+Nomegraf)
	variable Index=0 												//Variável de controle de qual o traçado está sendo selecionado na lista
	variable Data1
	variable X_Inicial,X_Final
	wave ondin=$stringfromlist(0,List)
	X_Inicial=(pnt2x(ondin,numpnts(ondin)))
	X_Final=(pnt2x(ondin,numpnts(ondin)))

	cursor/A=1/W=$NomeGraf B $stringfromlist(0,List), (X_Final/3)
	cursor/A=1/W=$NomeGraf A $stringfromlist(0,List), (X_Final/5)
	
	Controlinfo/w=$nomegraf#Input Tipo_IV						//Esse controliinfo deve ser posto aqui, senão a jnaela Input é eliminada e não dá pra achar o S_value do popup
	killwindow $nomegraf#Input
	textbox /k/n=Data
	button BotaoOK, disable=1
	variable PtoA=xcsr(A,NomeGraf) 
	variable Pa=pcsr(A,NomeGraf) 								//Posição do cursor A no gráfico determinado
	variable PtoB=xcsr(B,NomeGraf) 									//Posição do cursor B no gráfico determinado
	index=0
	make/d/o/n=(itemsinlist(list)) Output
	For (index=0;index<itemsinlist(list);index+=1)
		
					//Lista das Waves que serão usadas
		Tracename=StringFromList(Index,List)  						//Momento no qual é designado um traçado específico à String 'Tracename'
		
	
			wavestats/q /r=(PtoA,PtoB) $tracename
			if (V_value==1)
			Data1=Mean($tracename,PtoA,PtoB) 					//Média do traçado na posição dos cursores
			endif
			if (V_value==2)
			Data1= V_max
			endif
			if (V_value==3)
			Data1=V_min
			endif
			if (V_value==4)
				If (abs(V_min)>abs(V_max))
					Data1=V_min
					else
					Data1=V_max
				endif
			endif
			Output[index]=Data1
		
	endfor
	nova=Check_Wavename(Nova)
	duplicate/o Output,$nova
	killwaves Output

end

//*********************************************************************************************************

//**********************************************************************************************
			
function Media_Waves_Graph()//: ButtonControl
//String ctrlname
String Graphname, Tracename, ListWave
ControlInfo Nomegrafico
if (strlen(S_Value)>0)
	 GraphName  = S_Value							//O nome do traçado da lista a ser analisado
	ListWave=tracenamelist(GraphName, ";",1) 
	else
	Listwave=wavelist("*",";","")
endif
	Variable Index,i,k											//Variável de controle de qual o traçado está sendo selecionado na lista
	 

		for (i=0;i<(itemsinlist(ListWave));i+=1)
				Tracename=stringfromlist(i,ListWave)
				wave Onda=$tracename
				if (i==0)
					make/o/n=(numpnts(onda)) Media=Onda
					else	
					Media=Media+Onda
				endif
		endfor
		Media=Media/(itemsinlist(ListWave))
string partes="([[:alpha:][:digit:]]+)_([[:digit:]]+)" // Dá o nome da média, apenas o sufixo até o "_" (vide POSIX Character Classes para mais info)
string Nome_Final, N1
splitstring /e=Partes stringfromlist(0,ListWave), Nome_Final, N1
Nome_Final=Nome_Final+"_AVG"
i=-1
String Wave_Index
if (waveexists($Nome_Final))
	do
		i+=1
		Wave_Index=Nome_Final+num2str(i)
	while(waveexists($Wave_Index)==1)
endif
duplicate/o Media, $Nome_Final
setscale /p x,0,deltax($stringfromlist(0,Listwave)), "s", $Nome_Final
killwaves media
end

//*********************************************************************


//************************************************************************

Function Imin()
variable /g PtoM=0
Topo()
end


Function Imax()
variable /g PtoM=1
Topo()
end


Function Topo()
nvar PtoM
string Graph
variable Index=0
string trace
ControlInfo /w=meu_teste Nomegrafico
//prompt Graph, "Gráfico"
//doprompt "Gráfico a ser analisado", Graph
graph=S_Value
dowindow /f $Graph
string Lista=sortlist(wavelist("*",";","Win:"+Graph),";",16)
	do
		Trace=StringFromList(Index,Lista)
		if(strlen(Trace)==0)
			break
		endif
		if (strlen (CsrInfo (A,Graph))==0)
		wavestats/q $Trace
		else
		wavestats/q /r=[pcsr(A),pcsr(b)] $Trace
		endif
		if (PtoM==0)
			make/o/n=1 Pico=V_Min
			make/o /n=1 Pico_Time=V_Minloc
			else
			make/o/n=1 Pico=V_Max
			make/o /n=1 Pico_Time=V_Maxloc
		endif		
		if (index==0)
			Make/o/n=1 Onda2=Pico
			Make/o/n=1 Onda2_Time=Pico_Time
			else
			Concatenate/NP/o {Onda2,Pico}, Onda
			Concatenate/NP/o {Onda2_Time,Pico_Time}, Onda_Time
			duplicate/o Onda, Onda2
			duplicate/o Onda_Time, Onda2_Time
		endif
		index+=1
	While(1)
	display onda
end

//************************************************************************

Function Averages(name) //averages all PM* traces in the datafolder
string name
String List=Wavelist("*"+name+"*",";","")
if (Stringmatch(name, "Use_Graph"))
Controlinfo /w=Meu_Teste Nomegrafico
list=wavelist("*",";","Win:"+s_value)
Name="AVG"
else
Name+="_AVG"
endif

Variable i,index, j
for (i=0;i<itemsinlist(list);i+=1)
	if (stringmatch(stringfromList(i,list),"*avg*")==1)
		list=removeFromList(stringfromList(i,list),list)
	endif
endfor

//duplicate /o $Stringfromlist(0,list), AVG_All

Make/o/n=(itemsinlist(list)) Num_Pnts_Wvs
for (i=0;i<itemsinlist(list);i+=1)
	Wave temp=$Stringfromlist(i,list)
	Num_Pnts_Wvs[i]=numpnts(temp)
endfor
Make/o/n=(wavemax(Num_Pnts_Wvs)) AVG_All
Make/o/n=(wavemax(Num_Pnts_Wvs)) Division_Indexes=0
do
for (i=0;i<itemsinlist(list);i+=1)
	Wave temp=$Stringfromlist(i,list)
	if (index<Numpnts(Temp) && numtype(temp[index])!=2)
		AVG_All[index]+=Temp[index]
		Division_Indexes[index]+=1
	endif
endfor

index+=1
while(index<wavemax(Num_Pnts_Wvs))
index=i
duplicate/o avg_all, new
new/=i
for (i=0;i<numpnts(AVG_All);i+=1)
AVG_All[i]/=Division_Indexes[i]
endfor
//Name+="_AVG"
setscale /p x,0,deltax($Stringfromlist(0,list)),"s",avg_all
duplicate /o AVG_ALL, $name
killwaves AVG_All,Division_Indexes, new, Num_pnts_wvs
print index, " waves processed"
End

//***************************************************************************************

//**************************************************************************


//*************************************************************************




//***********************************************************************

Function Cut()


wave/t Wave_Geral // Nome da Text wave contendo uma lista das waves que estão no insight
Controlinfo /w=Meu_Teste NomeGrafico
dowindow /f s_Value
execute "ShowInfo"
Cursor /a=1 /W=$s_Value A $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2)
Cursor /a=1 /W=$s_Value B $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2)
String/g  Nome_Onda_Dup="_Cut"
String W_Name=S_Value+"#Cutting_Window"
if (wintype(W_Name)==7)
	killwindow $W_Name
endif
Newpanel /N=Cutting_Window /Ext=0 /Host=$S_Value /K=2 /W=(0,0,200,100) as "Place cursors A and B to continue"
button BotaoOK win=$S_Value#Cutting_Window, disable=0, title="Continue", pos={5,5}, fsize=14, size={70,30}, proc = Mata_Janela_Top
button Cut_Cancela win=$S_Value#Cutting_Window, disable=0, title="Cancel", pos={5,50}, fsize=14, size={70,30}, proc = Kill_Window

end



//********************************************************************************

function Mata_Janela_Top (ctrlName) : ButtonControl
string ctrlname
string W="Cutting_Window"
String Name
wave/t Wave_Geral
variable i
Controlinfo /w=Meu_Teste NomeGrafico
String Graph=S_Value
wave/t W_Wavelist
Getwindow $S_Value wavelist
String List=wavelist("*",";","win:"+Graph)
for (i=0;i<dimsize(W_Wavelist,0);i+=1)
//	List+=W_Wavelist[1][i]+";"
endfor
For (i=0;i<itemsinlist(list);i+=1)
	Name=StringfromList(i,list)+"_Cut"
	Duplicate /o /r=[pcsr(A,Graph),pcsr(B,Graph)] $StringfromList(i,list), $Name
	setscale /p x,0,deltax($Name),"s",$Name
endfor
//print i, "Waves processed"
Killwaves /z W_Wavelist
execute "killwindow "+Graph+"#Cutting_Window"
end

//********************************************************************************


//*************************************************************************************
function Zera()
//ControlInfo Ondas
Wave/t Wave_Geral
variable index, Media, delta
string Onda_S
controlinfo/w=Meu_teste NomeGrafico
dowindow/f S_Value
String LIst=wavelist("*",";","Win:"+S_Value)
do
//	if (stringmatch(Wave_geral[index],"!*stim")==1)
		Wave Onda=$Stringfromlist(index,list)//$Wave_geral[index]
		if (strlen(CsrInfo(A,S_Value))>0 && strlen(CsrInfo(B,S_Value))>0)
			delta=mean (onda,pcsr(A,S_Value),pcsr(B,S_Value))//average between cursrs if they are on graph
		else 
			delta=mean(onda,0,pnt2x(onda, 50)) //average of the first 50 pnts
		endif
		Onda=Onda-delta
//		print delta
//	endif
	index+=1
while(index<itemsinlist(list))//numpnts(wave_geral))
end










