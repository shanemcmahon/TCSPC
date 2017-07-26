#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function AutoCorrTCSPC()
string MacroTimeName
Prompt MacroTimeName, "MacroTime wave name",popup,WaveList("*",";","" )
variable MacroClock = 25e-9
prompt MacroClock, "Macro clock"
variable MinCorrTime = 100e-9
Prompt MinCorrTime, "Minimum Correlation time"
variable BgPar, BgPerp
BgPar = 13
Bgperp = 25
Prompt BgPar,"Dark count rate, parallel detector"
prompt BgPerp,"Dark count rate, Perpendicular detector"
DoPrompt "", MacroTimeName, MacroClock,MinCorrTime,BgPar,BgPerp
wave MacroTimes = $MacroTimeName
variable MaxTime = WaveMax(macrotimes)
killwaves /z PhotonTimes, PhotonTimesIndex
make /o /B /n=(MaxTime/MinCorrTime*MacroClock) PhotonTimes
make /o /B /n=(MaxTime/MinCorrTime*MacroClock) PhotonTimesIndex
duplicate /o MacroTimes MacroTimes2
MacroTimes2 = floor((MacroTimes/MinCorrTime)*MacroClock)
variable i=0
variable nPhotons = numpnts(MacroTimes)
for(i=0;i<(nPhotons-1);i++)	// Initialize variables;continue test
    PhotonTimes[MacroTimes2[i]] = 1
endfor						// Execute body code until continue test is FALSE
killwaves /z PhotonCoincidence
make /o /B /n=(numpnts(PhotonTimes)) PhotonCoincidence
variable nBins = (numpnts(PhotonTimes)) -1
for(i=0;i<nBins;i++)
PhotonCoincidence = PhotonTimes[p]*PhotonTimes[i+p]
print sum(photoncoincidence)
deletepoints 0,1,PhotonCoincidence
endfor

end //AutoCorrTCSPC

menu "macros"
  "AutoCorrTCSPC"
end
