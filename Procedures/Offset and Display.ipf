#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Macros"
	Submenu "HvG Lab Analysis"
		"Offset_and_Display"
	End
End

Function Offset_and_Display()

String/g Name=""
DoWindow/k Offset
NewPanel /N=Offset /W=(100,100,370, 250) /K=1 
PopUpMenu NomeGrafico pos = {190,10}, BodyWidth=150
PopUpMenu NomeGrafico Title = "Choose Graph"
if (strlen(WinList("*",";","win:1"))==0)
	PopUpMenu NomeGrafico Value ="No Graphs Available"
	else
	PopUpMenu NomeGrafico Value = sortlist(WinList("*",";","win:1"),";",16)
endif
//CheckBox 		Kill_ori 		Win=Offset, Value=0, Title="Kill original waves", Side=0, pos={20,95}//, Proc=All_Waves
TitleBox 		Selected_Waves Win=Offset, Title="Analyse waves containing:",  pos={20,50}, frame=0
SetVariable 		Sel_Waves 		Win=Offset, disable=0, bodywidth=190, noproc, pos={45,70}, size={200,10},Title="", value=Name
Button 			Go 				Win=Offset, pos={20,120}, Size = {90,20}, Title="Go!", proc=Offset_and_Display_Exec
Button 			Cancel 			Win=Offset, pos={150,120}, Size = {90,20}, Title="Cancel", Proc=Cancel_Offset
end

Function Cancel_Offset(Ctrl):buttoncontrol
String Ctrl
Dowindow/k Offset
end



function Offset_and_Display_Exec(Ctrl):Buttoncontrol
String Ctrl 
Svar Name
String Item="*"+name
String List=wavelist(Item,";","")
Variable i,ini,final,offset,Range, Max1,Max2
wave tm
String Suffix, Units

if (stringmatch(item,"*cm*")==0)
Units="A"
ini=500000
final=515000
I_avg(List)
else
Units="F"
ini=0//3000
final=11000//8000
endif
String Notes
wavestats /q $stringfromlist(0,list)
make/o/n=(final-ini,itemsinlist(list)) Waterfall =0
for (i=0;i<itemsinlist(list);i+=1)

if (stringmatch("!*Cut",stringfromlist(i,list))==0)
	duplicate/o/r=[ini,final-1] $stringfromlist(i,list), Temp
	offset=mean(temp,pnt2x(Temp,100),pnt2x(temp,200))
	temp-=offset
	Waterfall[][i]=Temp[p]
	Smooth 10, Temp
	Suffix=Stringfromlist(i,list)+"_Cut"
	duplicate/o temp, $Suffix

	if (i==0)
		display/k=1 $Suffix
	else
		Appendtograph $Suffix
		if (ini>8000)
			Notes = removeEnding( Stringbykey ("\rV1", note($suffix),":",";")," mV")
			if (str2num(notes)>-50)
				ModifyGraph rgb($Suffix)=(65280,54528,48896)
			endif
		endif
	endif
	wavestats/q Temp
	Max1+=V_max
//	print v_max
	If (Max1>Max2)
		Max2=Max1
		
		
	endif
endif
endfor
//Max1/=(i+1)

i=0
doupdate
GetAxis Left
pauseupdate
Range=V_max-V_min
list=wavelist("*_Cut",";","win:")
for (i=0;i<itemsinlist(list);i+=1)

	Modifygraph offset($Stringfromlist(i,list))={0,(-i*Range)}
endfor
i=0
do
i+=1
while (abs(Max2*10^i)<1)
Max1=Max2
Max1*=10^i
Max1=round(Max1)
Variable Power
String Pref
switch (mod(i,3))
	Case 0:
	break
	Case 1:
	Max1*=10
	break
	Case 2:
	Max1*=100
	break
endswitch
Switch ((i-mod(i,3))/3)
	Case 1:
		Pref="m"
		break
	Case 2:
		Pref="µ"
		break
	Case 3:
		Pref="n"
		break
	Case 4:
		Pref="p"
		break
	Case 5:
		Pref="f"
		break
endSwitch
print i, mod(i,3), max1, max2
doupdate
GetAxis/q Left
Range=V_max-V_min


execute "PPTDrawScaleBars ("+num2char(34)+"bottom"+num2char(34)+","+num2char(34)+"left"+num2char(34)+", 1, 1, pnt2x("+Suffix+",0),"+num2str(V_min)+", 0,"+num2str(Range/10)+","+num2char(34)+num2char(34)+","+num2char(34)+Pref+Units+num2char(34)+")"
ModifyGraph axRGB(left)=(65535,65535,65535),tlblRGB(left)=(65535,65535,65535);DelayUpdate
ModifyGraph alblRGB(left)=(65535,65535,65535);DelayUpdate
SetAxis/A
doupdate
setdrawenv rotate=90
drawtext pnt2x($Suffix,0),V_min,num2str(round(   range     )/10)+Pref+Units
print pnt2x($Suffix,0), V_min
//duplicate /o Waterfall, Waterfall_Smth
//Smooth 10, Waterfall_smth
//newwaterfall Waterfall_Smth vs {*,tm}

end

Function I_avg(List)
String List
Variable i
Duplicate/o $stringfromlist(0,list), I_Temp
for (i=1;i<itemsinlist(list);i+=1)
Execute "I_temp+="+Stringfromlist(i,list)
endfor
i_temp/=itemsinlist(list)
end