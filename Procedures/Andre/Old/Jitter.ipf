#pragma rtGlobals=1		// Use modern global access method.
#include <FilterDialog> menus=0

Function Jitter()

string  Nome
variable bloco
prompt Nome, "Nome do Gráfico"
prompt bloco, "tamanho do bloco"
doprompt "Gráfico", Nome,bloco
String /g NomeGraf=Nome
Variable /g Block=Bloco
Latency()
wavestats/q Jit1
appendtograph/w=$nome /c=(0,0,0) Media_F
drawtext/w=$nome 0.7,0.11, "Jitter = "+num2str(V_sdev)
end

//**********************************************************************

function Latency()

Svar Nomegraf
Nvar Block
Variable Index,h2,h
Variable /g Pico

if (block>0)
	block=block-1
endif

string List=tracenamelist(NomeGraf, ";",1) 					//Lista das Waves que serão usadas
string Janela, Tracename
do
	Tracename=StringFromList(Index,List)  	
	if(strlen(Tracename)==0)
		break
	endif
	findpeak/q/p /m=100 $Tracename
	Pico= round (V_peakloc)
	wavestats/q /r=(Pico-200,Pico-10) $Tracename
	duplicate/o $Tracename, onda
	H=0
	h2=20
	findpeak/n/q/p/r=((Pico+20),(Pico+500)) $Tracename
	variable m1,m2,m3,m4,m5,m6,ms1,ms2,ms3,ms4,ms5,ms6
		
		do
			Duplicate/O onda, onda_smth
			smooth 5, onda_smth
			m1= mean(onda,(Pico+h+h2),(Pico+h+h2+block))
			m2= mean(onda,(Pico+h+h2+block+1),(Pico+h+h2+2*block+1))
			m3= mean(onda,(Pico+h+h2+2*block+2),(Pico+h+h2+3*block+2))
			m4= mean(onda,(Pico+h+h2+3*block+3),(Pico+h+h2+4*block+3))
			m5= mean(onda,(Pico+h+h2+4*block+4),(Pico+h+h2+5*block+4))
			m6= mean(onda,(Pico+h+h2+5*block+5),(Pico+h+h2+6*block+5))
			
			ms1= mean(onda_smth,(Pico+h+h2),(Pico+h+h2+block))
			ms2= mean(onda_smth,(Pico+h+h2+block+1),(Pico+h+h2+2*block+1))
			ms3= mean(onda_smth,(Pico+h+h2+2*block+2),(Pico+h+h2+3*block+2))
			ms4= mean(onda_smth,(Pico+h+h2+3*block+3),(Pico+h+h2+4*block+3))		
			ms5= mean(onda_smth,(Pico+h+h2+4*block+4),(Pico+h+h2+5*block+4))
			ms6= mean(onda_smth,(Pico+h+h2+5*block+5),(Pico+h+h2+6*block+5))
			
			killwaves onda_smth
			if ((m1>m2) & (m2>m3) & (m3>m4) & (m4>m5)& (m5>m6))
			 if ( (ms1>ms2) & (ms2>ms3) & (ms3>ms4) & (ms4>ms5)& (ms5>ms6))
				duplicate/o/r=[(pico+h+h2),(pico+h+h2+10)] onda, Inicio_Evento
				findvalue /V=(wavemax(Inicio_Evento)) /t=0.15 /s=(Pico+H+H2) onda
				variable Medida_2 = V_value
				break
			endif
			endif
			h+=1
		While (onda[v_value+h]<v_peakloc)
	variable D=0
	do
		d+=1
	while ((onda[Pico-(D)+1]-onda[Pico-D])>0.5)
	
	if (onda[pico-D]>(abs(5*V_sdev)))
		do
			d+=1
		while ((onda[Pico-(D)+1]-onda[Pico-D])>0.5)
	endif
	
	Variable Medida_1= (Pico-D+1)
	wave Time__s_
	variable Jitter= (Medida_2-Medida_1)*(Time__s_[1])
	
	if (index==0)
		wavestats/q $tracename
		variable Pontos=V_npnts
		make/O/d/n=1 Jit1=Jitter
		make/o/d/n=(V_npnts) Media=onda
	else
		make/o/d/n=(Pontos) Media=Media+onda
		make/O/d/n=1 Jit2=Jitter
		concatenate/NP/O {Jit1,Jit2}, Jit1
	endif
	index+=1
	janela= "J_"+num2str(index)
	display/k=1 /n=f $tracename
	setaxis/w=f bottom (Medida_1-100),(Medida_2+250)
	setaxis/w=f left (onda[Medida_1]-80),(onda[Medida_1]+40)
	renamewindow f, $janela
	cursor/h=0/s=2/w=$janela /a=1 A, $Tracename, Medida_2
	cursor/h=0/s=2/w=$janela /a=1 B, $Tracename, Medida_1
while(1)

make/o/d/n=(Pontos) Media_F=Media/(index)

end

//****************************************************************
Function Parametros()
wave Onda
variable m1,m2,m3,m4,m5,m6,ms1,ms2,ms3,ms4,ms5,ms6
Nvar Pico, Block
Variable H,H2
H2=20

Duplicate/O onda, onda_smth
			smooth 5, onda_smth
			do
			m1= mean(onda,(Pico+h+h2),(Pico+h+h2+block))
			m2= mean(onda,(Pico+h+h2+block+1),(Pico+h+h2+2*block+1))
			m3= mean(onda,(Pico+h+h2+2*block+2),(Pico+h+h2+3*block+2))
			m4= mean(onda,(Pico+h+h2+3*block+3),(Pico+h+h2+4*block+3))
			m5= mean(onda,(Pico+h+h2+4*block+4),(Pico+h+h2+5*block+4))
			m6= mean(onda,(Pico+h+h2+5*block+5),(Pico+h+h2+6*block+5))
			
			ms1= mean(onda_smth,(Pico+h+h2),(Pico+h+h2+block))
			ms2= mean(onda_smth,(Pico+h+h2+block+1),(Pico+h+h2+2*block+1))
			ms3= mean(onda_smth,(Pico+h+h2+2*block+2),(Pico+h+h2+3*block+2))
			ms4= mean(onda_smth,(Pico+h+h2+3*block+3),(Pico+h+h2+4*block+3))		
			ms5= mean(onda_smth,(Pico+h+h2+4*block+4),(Pico+h+h2+5*block+4))
			ms6= mean(onda_smth,(Pico+h+h2+5*block+5),(Pico+h+h2+6*block+5))
			

			if ((m1>m2) & (m2>m3) & (m3>m4) & (m4>m5)& (m5>m6))
			 if ( (ms1>ms2) & (ms2>ms3) & (ms3>ms4) & (ms4>ms5)& (ms5>ms6))
				duplicate/o/r=[(pico+h+h2),(pico+h+h2+10)] onda, Inicio_Evento
				findvalue /V=(wavemax(Inicio_Evento)) /t=0.15 /s=(Pico+H+H2) onda
				variable Medida_2 = V_value
				break
			endif
			endif
			h+=1
			While(1)
killwaves onda_smth
end