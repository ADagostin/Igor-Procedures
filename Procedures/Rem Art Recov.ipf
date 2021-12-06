#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function Rec_Art()

string Graph
variable Index=0
string trace
prompt Graph, "Gráfico"
doprompt "Gráfico a ser analisado", Graph
dowindow/f $Graph
string Lista=sortlist(wavelist("*",";","Win:"+Graph),";",2)
print lista
Variable Pico,i
Variable Start,init
init=pcsr(a)
wavestats/q/r=[pcsr(a),pcsr(b)] $StringFromList(0,Lista)
Variable Size=  abs (Pcsr(B)-Pcsr(A))
Variable Start_Ini = abs (Pcsr(a)-x2pnt($StringFromList(0,Lista),v_maxloc))
	do
		Trace=StringFromList(Index,Lista)
		if(strlen(Trace)==0)
			break
		endif
		Duplicate/o $Trace, Temp
		wavestats/q /r=[init,numpnts($Trace)] $Trace
 		Start = x2pnt(Temp, V_maxloc) - Start_Ini
		
	for (i=0;i<=Size;i+=1)		
		Temp[Start+i]=NaN	
	endfor	
	Duplicate/o temp, $Trace
		index+=1
	While(1)
DoWindow/f $Graph
Cursor A,$Stringfromlist(0,Lista),deltax($Stringfromlist(0,Lista))*init
Cursor B,$Stringfromlist(itemsinlist(lista)-1,Lista),pnt2x($Stringfromlist(itemsinlist(lista)-1,Lista),numpnts($Stringfromlist(itemsinlist(lista)-1,Lista)) )
Recov_Amp(Graph)
end

Function Recov_Amp(Graph)
string Graph
variable Index=0
string trace
string Lista=sortlist(wavelist("*",";","Win:"+Graph),";",2)

	do
		Trace=StringFromList(Index,Lista)
		if(strlen(Trace)==0)
			break
		endif
	
		wavestats/q /r=[pcsr(A),pcsr(b)] $Trace


			make/o/n=1 Pico=V_Min
			make/o/n=1 Pico_Time=V_minloc
			
	
		if (index==0)
			Make/o/n=1 Onda2=Pico
			Make/o/n=1 Onda3=Pico_Time
			else
			Concatenate/NP/o {Onda2,Pico}, Onda
			duplicate/o Onda, Onda2
			Concatenate/NP/o {Onda3,Pico_Time}, Onda4
			duplicate/o Onda4, Onda3
		endif
		index+=1
	While(1)
	display onda vs Onda4
	rename Onda, Recov
	rename Onda4, Recov_Time
end

Function  Take_OFF(Graph)
string Graph
variable i
string list=csrinfo(A,Graph)
print Graph, list
if (strlen(list)>0)
string Wv=stringbykey("TNAME",List)
Duplicate/o $Wv,Temp
for (i=pcsr(A);i<=pcsr(b);i+=1)

	Temp[i]=NaN 
	duplicate/o Temp, $Wv
endfor
endif
killwaves temp
end