#pragma rtGlobals=1		// Use modern global access method.
function Normal()

String Lista, NomeWave, NomeGraf, Nome_Onda
Variable Index, Set_Point
Prompt Nomegraf, "Grafico"
Doprompt "Nome do Grafico", Nomegraf
Lista=tracenamelist(Nomegraf,";",1)
do
	Nomewave=stringfromlist(Index,Lista)
	
	if (strlen(NomeWave)==0)
		break
	endif
	wavestats/q/r=[pcsr(A),PCsr(B)] $Nomewave
	Nome_Onda=NomeWave+"_Norm"
	duplicate/o $NomeWave, Onda
	Make/o/n=(numpnts($Nomewave)) $Nome_Onda=Onda/V_min*-1
	

if (Index==0)
//	display $Nome_Onda
	else
	//appendtograph $Nome_Onda
endif
index+=1
while(1)
Killwaves onda
end