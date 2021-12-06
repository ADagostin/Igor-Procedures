#pragma rtGlobals=1		// Use modern global access method.


Function Conc()

String Lista, NomeWave, NomeGraf
Variable Index
Prompt Nomegraf, "Grafico"
Doprompt "Nome do Grafico", Nomegraf
Lista=tracenamelist(Nomegraf,";",1)

do
	Nomewave=stringfromlist(Index,Lista)
	if (strlen(NomeWave)==0)
		break
	endif
	Duplicate/o $Nomewave, Onda
	wavestats/q onda
	if (Index==0)
		make/n=(v_npnts)/o W1=Onda
	else
		make/n=(V_npnts)/o W2=Onda
		concatenate/o/np {W1,W2}, W_Final
		duplicate/o W_Final,W1
	endif
	index+=1
while(1)



killwaves Onda,W1,W2
end