#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function AM2()
String list=wavelist("*",";","")
String Temp_s
Variable PM, temp_len
Variable i,j,k,l, index
	If (stringmatch(stringfromlist(0,list),"PMPulse*"))
		PM=1
	
		For (index=0;index<itemsinlist(list);index+=1)
			Temp_s=stringfromlist(index,list)
			temp_len=strlen(Temp_s)
			Temp_s=Temp_s[0,temp_len-10]
			wave temp = $stringfromlist(index,list)
			if (stringmatch(stringfromlist(index,list),"*Vmon*"))
				rename temp, $Temp_s
			endif
		endfor
	else
		PM=0
	endif
	index=0

String Name="Averaged_"
String Num_sw
//index+=1
for (i=0;i<=9;i+=1)
	for (j=0;j<=9;j+=1)
		for (k=0;k<=9;k+=1)
		if (PM==0)
			if (k>0 || j>0 || i>0)
				index+=1	
				Num_sw=num2str(i)+num2str(j)+num2str(k)		
				list=wavelist("*"+Num_sw+"*",";","")		
				if (strlen(list)==0)
					print index, "averages processed"//, "wut"
					abort
				endif
				for(l=0;l<itemsInList(list);l+=1)
					if (l==0)
						if (itemsinlist(list)>1)
						Duplicate /o $Stringfromlist(0,list), temp
						endif
					else
						wave temp1=$Stringfromlist(l,list)
						Temp+=temp1
					endif
				endfor
				temp/=itemsinlist(list)
				duplicate /o temp, $Name+num2str(index)				
			endif	
		else
	//		if (k>0 || j>0 || i>0)
		if (i==0 && j==0 && k==0)
			k+=1
		endif
				
				if (j==0)
					Num_sw="_"+num2str(k)
				else
					if (i==0)
						Num_sw="_"+num2str(j)+num2str(k)
					else
						Num_sw="_"+num2str(i)+num2str(j)+num2str(k)
					endif
				endif
				index+=1	
				list=wavelist("*"+Num_sw,";","")
				if (strlen(list)==0)
					print index-1, "averages processed"
					abort
				endif
				for(l=0;l<itemsInList(list);l+=1)
					if (l==0)
						if (itemsinlist(list)>1)
						Duplicate /o $Stringfromlist(0,list), temp
						endif
					else
						wave temp1=$Stringfromlist(l,list)
						Temp+=temp1
					endif
				endfor
				temp/=itemsinlist(list)
				duplicate /o temp, $Name+num2str(index)				
	//		endif	
		endif
		endfor
	endfor
endfor
			

end

Function All_Mean()
Variable Extra
String name//="*ch1"
String Wave_Name,List= sortlist(wavelist("*P*",";",""),";",16)


variable Nth =15





Variable i,k,total_Runs, Run_number//,Extra
Total_Runs=floor(itemsinlist(List)/Nth)

//Are there extra traces from an incomplete round? If there are, add to "Extra": - I don't remember what this does...
//1 for 10ms
//2 for 25 ms
//3 for 50 ms
//4 for 100 ms
// 5 for 300 ms
// 6 for 500 ms
// 7 for 1 s
// 8 for 2s
// 9 for 3s
// 10 for 4s
// 11 for 5s
// 12 for 10s
// Extra = 0


if (mod(itemsinlist(list),Nth)-Extra!=0)
Print "*******************  # of waves is not multiple of ", Nth,"*******************"
abort
endif
if (Extra>0)
	Total_Runs=Total_runs+1 // tells the routine there is one more incomplete round to go for
endif

for (i=1;I<=Nth;i+=1)
	make/o/n=(Numpnts($Stringfromlist(i-1,List))) Temp	
	
	for (k=0;k<Total_Runs;K+=1)
		Wave Temp2=$Stringfromlist(i-1+k*Nth,List)
		
		Temp=Temp+Temp2
		setscale /p x,0,deltax($Stringfromlist(i-1+k*Nth,List)),"s",temp
	endfor
	temp=temp/Total_Runs
	if (i==Extra)
		Total_Runs=Total_runs-1 // When the incomplete routine reaches its end (i.e., Nth=#Of the last sweep), the procedure gets back to the original #Sweeps
	endif
	Wave_Name = "PMPulse"+num2str(i-1)
	Duplicate/o Temp, $Wave_Name
	killwaves/z temp
	
endfor

end

function adj()

string list="control_avg"//="test092"//wavelist("C20929*",";","")//wave test
print list
wave control_avg
variable i, start, Add,k,h

add=349
start=pcsr(a)
for (k=0;k<itemsinlist(list);k+=1)
	duplicate/o $list, teste
//	InsertPoints 0,910, $stringfromlist(k,test)
	
	do	
		insertpoints start,3,teste
		for (h=0;h<=8;h+=1)
		teste[start+h]=NaN
		endfor
		start=start+add

	i+=1
	while (i<99)
	start=start+add
	i=0

	// duplicate/o test, $list


//	execute "rename test, Test"+num2str(k)


endfor
end

function Align(list, nth)
string list
variable nth
variable i,Num_loops
num_loops=itemsinlist(list)/nth

if (strlen(csrinfo(A))<1)
	print "No Cursor"
	abort
endif

wavestats/q /r=[pcsr(a),pcsr(a)+1000] $stringfromlist(0,list)
variable Delta, Align_pt=x2pnt($stringfromlist(0,list),V_minloc)

for (i=1;i<itemsinlist(list);i+=1)
print stringfromlist(i,list)
	wavestats/q /r=[pcsr(a),pcsr(a)+200] $stringfromlist(i,list)
	Delta= x2pnt($stringfromlist(i,list),V_minloc)-Align_pt
	if (delta<0)
		
		insertpoints 0,(delta*-1),$stringfromlist(i,list)
	//	deletepoints numpnts($stringfromlist(i,list))-abs(delta),abs(delta),$stringfromlist(i,list)
		else
	//	deletepoints 0,delta,$stringfromlist(i,list)
		insertpoints numpnts($stringfromlist(i,list))-1,delta*-1,$stringfromlist(i,list)
	endif

endfor

abort
end



Function Equalize()
string Name,list=wavelist("*",";","win:dyn_32")
variable i,maxpnt=-5.79e-9
for (i=0;i<itemsinlist(list);i+=1)
Name="Dyn_Ht_Norm_"+num2str(i)//stringfromlist(i,list)+"_Norm"
execute "Duplicate/o '"+stringfromlist(i,list)+"'"+Name
execute Name+"/="+num2str(maxpnt)
execute Name+"*=(-1)"

endfor

end
