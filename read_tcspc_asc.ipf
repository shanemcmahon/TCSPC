#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function UserContinue(ctrlName) : ButtonControl
	String ctrlName
	DoWindow/K PauseForUser0
End
macro DoReadTCSPC()
ReadTCSPC("")
endmacro

macro ReadMultiTCSPC()
variable FileRefNum,k_rm,nFilesSelected
string filelist
open /r /d /t=".asc" /mult=1 FileRefNum
filelist = s_filename
nFilesSelected = ItemsInList(filelist, "\r")
k_rm = -1
do
k_rm = k_rm + 1
s_filename = StringFromList(k_rm,filelist,"\r")
print s_filename
ReadTCSPC(s_filename)
while(k_rm <  nFilesSelected-1)
endmacro

function ReadTCSPC(FileNameIn)
	string FileNameIn
	variable v1,v2,FileRefNum,j,i
	string s_filename, filelist,filepath,line,OutWaveName,outwavename1,outwavename2
	//bring window named OutputWaveNames to the front
	//if it does not exists, create a table editing WaveNames
	dowindow /f OutputWaveNames
	if(!v_flag)
		make /o /t /n=6 WaveNames = {"Decay1x","FCS1x","MCS","FCCS","Decay2x","FCS2X"}
		edit /n=OutputWaveNames WaveNames
		NewPanel/K=2 /n=PauseForUser0 as "Pause for user"; AutoPositionWindow/M=1/R=OutputWaveNames
		DrawText 21,20,"Edit Output wave names in table";
		Button button0,pos={80,58},size={92,20},title="Continue"; Button button0,proc=UserContinue
		PauseForUser PauseForUser0, Parameters
	endif


	open /r /t=".asc" FileRefNum as FileNameIn

	if(strlen(s_filename) == 0)
		return(0)
	endif
	j=-1
	if(!WaveExists($"UID"))
		make /t /n=1 UID
		UID[0] = s_filename
	else
		insertPoints 0,1,UID
		UID[0] = s_filename
	endif

	// if(!FileRefNum)
	// 	abort "2"
	// endif

	do//1
		j = j + 1
		do//2
			freadline filerefnum, line
			if(strlen(line)==0)
				return(0)
			endif
		while(!stringmatch(line,"*BLOCK*"))//2
		OutWaveName = cleanupname(replacestring(" ",line,""),0)
		OutWaveName=replacestring("_",OutWaveName,"")
		OutWaveName=replacestring("XBLOCK",OutWaveName,"x")
		//		OutWaveName1 = uniquename(OutWaveName,1,0)
		//		make /o $OutWaveName1
		//		OutWaveName2 = uniquename(OutWaveName,1,0)
		//		make /o $OutWaveName2
		outwavename1 = outwavename + "1"
		outwavename2 = outwavename + "2"
		make /o $(OutWaveName1)
		make /o $(OutWaveName2)
		wave OutWave1 = $OutWaveName1
		wave OutWave2 = $OutWaveName2
		do//3
			freadline filerefnum, line
			if(strlen(line)==0)
				return(0)
			endif

			sscanf line, "%f %f",v1,v2
		while (v1==0 && v2 ==0)	//3
		OutWave1[0] = v1
		OutWave2[0] = v2
		i = 1
		do//4
			freadline filerefnum, line
			if(strlen(line)==0)
				return(0)
			endif

			sscanf line, "%f %f",v1,v2
			OutWave1[i] = v1
			OutWave2[i] = v2
			i++
			if (i >= (numpnts(OutWave1)-1))
				insertpoints (numpnts(OutWave1)-1),(numpnts(OutWave1)),OutWave1,OutWave2
			endif
		while (!stringmatch(line,"*END*"))	// as long as expression is TRUE//4

		deletepoints (i-1),Inf,OutWave1,OutWave2
		if(!WaveExists($(WaveNames[j])))
			duplicate /o OutWave2, $(WaveNames[j])
			setscale /p x,OutWave1[0],OutWave1[0],$(WaveNames[j])
			redimension /n=(-1,1) $(WaveNames[j])
		else
			wave WaveNameRef = $(WaveNames[j])
			InsertPoints/M=1 0,1, WaveNameRef

			WaveNameRef[][0] = OutWave2[min(numpnts(OutWave2)-1,p)]
		endif
		note $(WaveNames[j]),s_filename

	while(1)//1
	close FileRefNum

end

macro DoCalcAnisotropy(ParWaveName, PerpWaveName,BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth)
string ParWaveName="Decay1x", PerpWaveName="Decay2x"
variable BgPar = 0
variable BgPerp = 0
variable TACmax = 12.5
variable FitMinT = 3.8
variable FitMaxT = 9
variable g = 1.09
variable nSmooth=17
Prompt BgPar,"Dark count, parallel"
Prompt BgPerp,"Dark count, perpendicular"
prompt TACmax,"TAC max (ns)"
prompt FitMinT,"minimum time for curve fitting window"
prompt FitMaxT,"max time for curve fitting window"
Prompt ParWaveName, "Parallel fluorescence polariztion wave name", popup,WaveList("*",";","" )
Prompt PerpWaveName, "Perpendicular fluorescence polariztion wave name", popup,WaveList("*",";","" )
prompt g,"correction factor g"
prompt nSmooth,"Smoothing factor"
CalculateAnisotropy($ParWaveName, $PerpWaveName,BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth)
endmacro

function CalculateAnisotropy2D(ParWave, PerpWave,BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth)
wave ParWave, PerpWave
variable BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth
variable i,nColAnisotropy
wave Anisotropy
variable nColPar = DimSize(ParWave,1)
variable nColPerp = DimSize(PerpWave,1)
print nColPar,nColPerp
if(nColPar != nColPerp)
abort "2D waves must have same dimensions"
endif
make /o Anisotropy
for(i = 0;i < nColPar;i = i + 1)	// Initialize variables;continue test
	// duplicate /o /r=(FitMinT,FitMaxT)[i] ParWave,ParWave1D
	duplicate /o /r=(*)[i] ParWave,ParWave1D
	Redimension /n=(numpnts(ParWave1D)) ParWave1D
	// duplicate /o /r=(FitMinT,FitMaxT)[i] PerpWave,PerpWave1D
	duplicate /o /r=(*)[i] PerpWave,PerpWave1D
	Redimension /n=(numpnts(PerpWave1D)) PerpWave1D
	CalculateAnisotropy(ParWave1D, PerpWave1D,BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth)
	if(!WaveExists($"Anisotropy2D"))
	duplicate Anisotropy, Anisotropy2D
	Redimension /n=(-1,1) Anisotropy2D
	else
	nColAnisotropy = dimsize(Anisotropy2D,1)
	InsertPoints /m=1 (nColAnisotropy),1,Anisotropy2D
	Anisotropy2D[][nColAnisotropy] = Anisotropy[p]
	endif
endfor						// Execute body code until continue test is FALSE
end

function CalculateAnisotropy(ParWave, PerpWave,BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth)
	wave ParWave, PerpWave
	variable BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth
	if(dimsize(ParWave,1) > 0)
		CalculateAnisotropy2D(ParWave, PerpWave,BgPar,BgPerp,TACmax,FitMinT,FitMaxT,g,nSmooth)
		return(0)
	endif
	// duplicate /o /r=(FitMinT,FitMaxT) ParWave, IparPD
	// duplicate /o /r=(FitMinT,FitMaxT), PerpWave, IperpPD
  make /o /n=2 wIndicator = {1,NaN}
	duplicate /o ParWave, IparPD
	duplicate /o PerpWave, IperpPD
	duplicate /o IparPD,wTemp
	wTemp = ((IparPD == 0) & (IperpPD == 0))
	//IparPD = IParPD*wIndicator[wTemp[p]]
	//IperpPD = IPerpPD*wIndicator[wTemp[p]]

	killwaves /z wSmoothCoefs
	make /o /n=(2*(nSmooth)+1) wSmoothCoefs
	setscale /p x,(-nSmooth),1,wSmoothCoefs
	wSmoothCoefs = exp(-(x)^2)
	wavestats wSmoothCoefs
	wSmoothCoefs = wSmoothCoefs/v_sum

	Loess/V=2/N=(nSmooth)/ORD=2 srcWave= IparPD
	// FilterFIR/E=2/COEF=wSmoothCoefs IparPD
	Loess/V=2/N=(nSmooth)/ORD=2 srcWave= IperpPD
	// FilterFIR/E=2/COEF=wSmoothCoefs IperpPD

	IparPD = (IparPD - BgPar)
	IperpPD = (IperpPD - BgPerp)

	duplicate /o IparPD Anisotropy
	Anisotropy = (IparPD - g*IperpPD)/(IparPD + 2*g*IperpPD)
end

macro DoCleanUpAnisotropy(AnisotropyName, ParName, PerpName, ParBG, PerpBG)
string AnisotropyName = "Anisotropy2D"
string ParName = "Decay1x"
string PerpName = "Decay2x"
variable ParBG, PerpBG
Prompt AnisotropyName,"Name of anisotropy data wave", popup, WaveList("*",";","" )
Prompt ParName,"Name of parallel fluorescence component data wave", popup, WaveList("*",";","" )
Prompt PerpName,"Name of perpendicular fluorescence component data wave", popup, WaveList("*",";","" )
Prompt ParBG,"Dark count parallel detector"
Prompt PerpBG,"Dark count perpendicular detector"

CleanUpAnisotropy($AnisotropyName, $ParName, $PerpName,ParBG,PerpBG)
endmacro

function CleanUpAnisotropy(wAnisotropy,wParallel,wPerp,vParBG,vPerpBG)
wave wAnisotropy,wParallel,wPerp
variable vParBG,vPerpBG
duplicate /o wAnisotropy, wAnisotropyClean
duplicate /o wAnisotropyClean, wTemp
wTemp = ((wParallel > vParBG + 3*sqrt(wParallel)) & (wPerp > vPerpBG + 3*sqrt(wPerp))) // ((wParallel > vParBG + 3*sqrt(wParallel)) & (wPerp > vPerpBG + 3*sqrt(wPerp)))
duplicate /o wTemp,wTemp2
make /o /n=2 wIndicator = {NaN,1}
wTemp2 = wTemp * wIndicator[wTemp[p][q]]
wAnisotropyClean = wAnisotropy*wTemp2

killwaves /z wSmoothCoefs
make /o /n=5 wSmoothCoefs
setscale /p x,(-(numpnts(wSmoothCoefs)-1)/2),1,wSmoothCoefs
wSmoothCoefs = exp(-(x/0.5)^2)
wavestats wSmoothCoefs
wSmoothCoefs = wSmoothCoefs/v_sum

Duplicate/O wAnisotropyClean,wAnisotropyClean_smth;DelayUpdate
FilterFIR/E=2/COEF=wSmoothCoefs wAnisotropyClean_smth;DelayUpdate

 variable ncols = DimSize(wAnisotropyClean_smth,1 )
 variable nrows = DimSize(wAnisotropyClean_smth,0 )
 variable i
 for(i=0;i<ncols;i=i+1)	// Initialize variables;continue test
  //make /o /n=nrows $("wAnisotropyClean_smth" + num2str(i))
	duplicate /o /r=(*)[i] wAnisotropyClean_smth, $("wAnisotropyClean_smth" + num2str(i))
	// wave AnisoI = $("wAnisotropyClean_smth" + num2str(i))
	// setscale /p x,(DimOffset(wAnisotropyClean_smth, 0 )),(	DimDelta(wAnisotropyClean_smth, 0 )),AnisoI
	Redimension /n=(-1,0) $("wAnisotropyClean_smth" + num2str(i))
  endfor						// Execute body code until continue test is FALSE



//Duplicate/O wAnisotropyAvg,wAnisotropyAvg_smth;DelayUpdate
//FilterFIR/E=2/COEF=wSmoothCoefs wAnisotropyAvg_smth;DelayUpdate
end
