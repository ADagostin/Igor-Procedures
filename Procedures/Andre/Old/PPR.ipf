#pragma rtGlobals=1		// Use modern global access method.
Function PPR()
ControlInfo/w=Meu_Teste Nomegrafico
String Nome_Grafico=S_Value

//Cut (S_Value)


print nome_grafico
end

function Desmarca (Ctrlname,Checked) :CheckboxControl
String Ctrlname
Variable Checked
variable Dois, Quatro, Cursores
String W="Cutting_Window"
ControlInfo/w=Cutting_Window Dois
Dois=V_Value
ControlInfo/w=Cutting_Window Quatro
Quatro=V_Value
if (dois==10)
	checkbox Quatro win=Cutting_Window, value=0
	elseif (quatro==10)
	checkbox Dois win=Cutting_Window, value=0
endif
wave/t Wave_Geral
//variable/g PtoA,PtoB,PtoC,PtoD
ControlInfo/w=$W Dois
Cursores=checked
//controlinfo /w=$W Todas_Ondas
if (Cursores==1 && stringmatch (Ctrlname, "Dois")==1)
Cursor /a=1 /W=Cutting_Window A $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2-400)
Cursor /a=1 /W=Cutting_Window B $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2-200)
Cursor /a=0 /W=Cutting_Window C $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2+200)
Cursor /a=0 /W=Cutting_Window D $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2+400)
Cursor /K /W=Cutting_Window C 
Cursor /K /W=Cutting_Window D 
//PtoA=pcsr(A,W)
//PtoB=pcsr(B,W)
checkbox Quatro win=Cutting_Window, value=0
elseif (Cursores==1 && stringmatch (Ctrlname, "Quatro")==1)
Cursor /a=1 /W=Cutting_Window A $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2-400)
Cursor /a=1 /W=Cutting_Window B $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2-200)
Cursor /a=1 /W=Cutting_Window C $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2+200)
Cursor /a=1 /W=Cutting_Window D $Wave_Geral[0] pnt2x($Wave_Geral[0],(numpnts($Wave_Geral[0]))/2+400)
//PtoA=pcsr(A,W)
//PtoB=pcsr(B,W)
//PtoC=pcsr(C,W)
//PtoD=pcsr(D,W)
checkbox Dois win=Cutting_Window, value=0
endif
end

