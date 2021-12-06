#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function Pulo()
string list=wavelist("*cm",";","")
String List_Rs=wavelist("*GS",";","")
string data,data_exp
data_exp="([[:digit:]]+):([[:digit:]]+):([[:digit:]]+)"
variable i,j, First_Hr, First_min, First_Sec, Relative_Time,NaN1
string m,s,h
make/o/n=(itemsinlist(list)) Ini, Fin, Delt,Tm,R_Series
j=50
for (i=0;i<itemsinlist(list);i+=1)
data=stringbykey("\rtimer",note($stringfromlist(i,list)),":",";")
if (i==0)
duplicate/o $stringfromlist(i,list),test
do
	j+=10
while ((numtype(test[j])!=2)) //Finds the 1st NaN
NaN1=pnt2x(test,j)
do
	j+=1
while (numtype(test[j])==2) // Finds the 1st real number after the NaNs
killwaves test
endif

splitstring /E=(Data_Exp) stringbykey("\rSweep Time",note($stringfromlist(i,list)),":",";"),h,m,s
if (i==0)
	First_Hr=str2num(h)
	First_min=str2num(m)
	First_sec=str2num(s)
endif
Relative_Time=((str2num(m)*60)+str2num(s))-First_min*60

if(str2num(h)==First_hr)
	Relative_Time=((str2num(m)*60)+str2num(s))-First_min*60
	else
	Relative_time=((str2num(m)*60)+str2num(s))+(60-First_min)*60
endif
	Tm[i]=Relative_time
	delt[i]=mean($stringfromlist(i,list),pnt2x($stringfromlist(i,list),j),pnt2x($stringfromlist(i,list),j)+0.1)- mean($stringfromlist(i,list),NaN1-.11,NaN1-0.01)
	R_Series[i]=1/mean($stringfromlist(i,List_Rs),pnt2x($stringfromlist(i,List_Rs),j),inf)
endfor
setscale /i y,wavemin(Delt),wavemax(Delt),"F",Delt
setscale /i y,wavemin(R_Series),wavemax(R_Series),"MOhm",R_Series
Setscale /i x,wavemin(Tm),Wavemax(Tm),"s",Tm
Display/k=1 Delt vs Tm; AppendToGraph/R R_Series vs Tm
ModifyGraph mode=4,marker=19,msize=2,lstyle(Delt)=2,lstyle(R_Series)=3
ModifyGraph rgb(R_Series)=(0,0,0)
Legend/C/N=text0/F=0/A=MC
Legend/C/N=text0/J/B=1/A=RT/X=32.61/Y=36.18
end