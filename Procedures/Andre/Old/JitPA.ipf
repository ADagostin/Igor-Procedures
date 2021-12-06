#pragma rtGlobals=1		// Use modern global access method.


Function Varii()

String Lista, NomeWave, NomeGraf
Variable Index, Index_pico
Prompt Nomegraf, "Grafico"
Doprompt "Nome do Grafico", Nomegraf
Lista=tracenamelist(Nomegraf,";",1)
do
	Nomewave=stringfromlist(Index,Lista)
	
	if (strlen(NomeWave)==0)
		break
	endif
	findpeak/q/m=0/b=2 $NomeWave
	Index_Pico+=1
	
	if (index==0)
		make/o/n=1 Ind_Latencia=V_peakloc
		make/o/n=1 Amp_Pico=V_peakval
		else
		insertpoints (Index),1,Ind_Latencia
		insertpoints (Index),1,Amp_Pico
	endif

	if (V_flag==0) //verifica a existência de um pico maior do que zero
		Ind_Latencia[(Index)]=V_peakloc
		Amp_Pico[(Index)]=V_peakval
		if (WaveExists(Pico)==0)
			make/o/n=1 Pico=V_peakloc
		else
			make/o/n=1 Pico2=V_peakloc
			concatenate/o/np {Pico,Pico2}, Pico_Final
			duplicate/o Pico_Final,Pico
		endif
		else
		Ind_Latencia[(Index)]=0
		Amp_Pico[(Index)]=0
	endif
	index+=1
while(1)
wavestats/q Pico_Final
textbox /k/n=Data
textbox /F=0 /A=RT/W=$NomeGraf /n=Data "Jitter (ms) = "+num2str(V_sdev*1000)+"\r# de PAs = "+num2str(V_npnts)+"\r# de Falhas = "+num2str(index-V_npnts)+"\rLatência (ms) = "+num2str(mean(Pico_Final)*1E3)
if (waveexists(Dados_PAs)==1)
	wave Dados_PAs
	wave/t Cells
	else
	make/o/n=(1,8) Dados_PAs
	make/o/n=1/t Cells
endif
variable/G i=numpnts(Dados_PAs)
//wavestats/q Dados_PAs
if (Dados_PAs[(i/7)-1][0]>0)
	insertpoints (i/7),1,Dados_PAs
	insertpoints (i/7),1,Cells
	i=(i/7)
	else
	i=(i/7)-1
endif
	Dados_PAs[i][0]=V_sdev*1000
	Dados_PAs[i][1]=V_npnts
	Dados_PAs[i][2]=index-V_npnts
	Dados_PAs[i][3]=mean(Pico_Final)*1E3
//string tst="C1_040809_1_5_4"
string cell, dash, nova
variable v1

Nomewave=stringfromlist(Index-1,Lista)
if (stringmatch(Nomewave,"C1*")==1)
	sscanf Nomewave,"%[C1_]%d%[_]", cell, v1,dash
endif
if (stringmatch(Nomewave,"C2*")==1)
	sscanf Nomewave,"%[C2_]%d%[_]", cell, v1,dash
endif
if (stringmatch(Nomewave,"C3*")==1)
	sscanf Nomewave,"%[C3_]%d%[_]", cell, v1,dash
endif
if (stringmatch(Nomewave,"C4*")==1)
	sscanf Nomewave,"%[C4_]%d%[_]", cell, v1,dash
endif
if (strlen(num2str(v1))<6|strlen(num2str(v1))<4)
	nova=cell+"0"+num2str(v1)
	else
	nova=cell+num2str(v1)
endif
index=0
if (pnt2x($Nomewave,numpnts($nomewave))>0.16)
	nova=nova+"_5Hz"
	index=1
endif
if (pnt2x($Nomewave,numpnts($nomewave))<0.16&&pnt2x($Nomewave,numpnts($nomewave))>0.1)
	nova=nova+"_10Hz"
	index=1
endif
if (pnt2x($Nomewave,numpnts($nomewave))<0.07&&pnt2x($Nomewave,numpnts($nomewave))>0.03)
	nova=nova+"_50Hz"
	index=1
endif
if (index==0)
	nova=nova+"_100Hz"
endif
	Cells[i]=nova
	
killwaves Pico_final,Pico,Pico2	
//potencial_de_acao()
end