#pragma rtGlobals=3		// Use modern global access method and strict wave access.
function Rec_all()
String list=sortlist(wavelist("Amplitudes_*",";",""),";",16)
Variable i,n,t
for (i=0;i<itemsinlist(list);i+=1)
if (StringMatch(stringfromlist(i,list), "*time*")==0 && StringMatch(stringfromlist(i,list), "*norm*")==0 )
if (n==0)
		duplicate/o $stringfromlist(i,list),test
		make/o/n=1 Pts_Rec=test[numpnts(test)-1]
		n+=1
	else
		duplicate/o $stringfromlist(i,list),temp
		InsertPoints numpnts(Pts_Rec), 1, Pts_Rec
		Pts_Rec[n]=temp[numpnts(temp)-1]
		test+=temp
		n+=1
	endif
endif
EndFor
test/=n
DeletePoints numpnts(test)-1,1, test
Concatenate /NP /O {test, Pts_Rec}, Recovery_
n=0
for (i=0;i<itemsinlist(list);i+=1)
if ( StringMatch(stringfromlist(i,list), "*norm_*")==1 )
	if (n==0)
		duplicate/o $stringfromlist(i,list),test
		make/o/n=1 Pts_Rec=test[numpnts(test)-1]
		n+=1
	else
		duplicate/o $stringfromlist(i,list),temp
		InsertPoints numpnts(Pts_Rec), 1, Pts_Rec
		Pts_Rec[n]=temp[numpnts(temp)-1]
		test+=temp
		n+=1
	endif
endif
if (StringMatch(stringfromlist(i,list), "*time_*")==1)
	if (t==0)
		duplicate/o $stringfromlist(i,list),test_time
		make/o/n=1 Pts_Rec_time=test_time[numpnts(test_time)-1]
		t+=1
	else
		duplicate/o $stringfromlist(i,list),temp_time
		InsertPoints numpnts(Pts_Rec_time), 1, Pts_Rec_time
		Pts_Rec_time[n]=temp_time[numpnts(temp_time)-1]
		test_time+=temp_time
		t+=1
	endif
endif
endfor
test/=n
test_time/=t
killwaves temp, temp_time
DeletePoints numpnts(test)-1,1, test
DeletePoints numpnts(test_time)-1,1, test_time
Concatenate /NP /O {Test_Time, Pts_Rec_Time}, Recovery_Tm_
Concatenate /NP /O {test, Pts_Rec}, Recovery_Norm
end

