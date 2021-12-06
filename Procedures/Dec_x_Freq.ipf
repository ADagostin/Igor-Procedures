#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function Freqs()
String List=wavelist("Amp_*",";","")
Variable i
Make/o /n=6 All_Amps
for (i=0;i<itemsinlist(list);i+=1)
	if (stringmatch(Stringfromlist(i,list),"*1Hz*")==1)
	Attribute(0,$Stringfromlist(i,list))
	endif
	if (stringmatch(Stringfromlist(i,list),"*10*")==1)
	Attribute(1,$Stringfromlist(i,list))
	endif
	if (stringmatch(Stringfromlist(i,list),"*20*")==1)
	Attribute(2,$Stringfromlist(i,list))
	endif
	if (stringmatch(Stringfromlist(i,list),"*50*")==1)
	Attribute(3,$Stringfromlist(i,list))
	endif
	if (stringmatch(Stringfromlist(i,list),"*Mult*")==1)
	wave Nova=$Stringfromlist(i,list)
	All_Amps[4]=mean($Stringfromlist(i,list),45,49)/Nova[0]
	All_Amps[5]=mean($Stringfromlist(i,list),75,79)/Nova[0]
	endif

endfor


end

Function Attribute(Num,Wv)
Variable Num
Wave Wv
Wave All_Amps
All_Amps[Num]=mean(Wv,numpnts(Wv)-6,numpnts(Wv)-1)/Wv[0]
end
Function Dep_x_Freq(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = 1/(1+B*x)+(A*x)/(1+B*x)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 2
	//CurveFitDialog/ w[0] = B
	//CurveFitDialog/ w[1] = A

	return 1/(1+w[0]*x)+(w[1]*x)/(1+w[0]*x)
End

