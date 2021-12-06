#pragma rtGlobals=1		// Use modern global access method.

function Progressao()
make/o/n=1 Tamanho_Wave
make/o/n=1 Cem=100
make/o/n=1 Zero=0
make/o/t/n=1 Andamento="%"
ControlInfo Ondas
variable valor
display/k=1/w=(20,20,120,150) /n=Porcentagem_Concluida Cem vs Andamento
pauseupdate
appendtograph/b=x2 zero vs andamento
SetAxis left 0,100
ModifyGraph hbFill(Zero)=2
ModifyGraph axRGB(x2)=(65535,65535,65535),tlblRGB(x2)=(65535,65535,65535);DelayUpdate
ModifyGraph alblRGB(x2)=(65535,65535,65535)
ModifyGraph axisEnab(left)={0,0.8}
doupdate
end