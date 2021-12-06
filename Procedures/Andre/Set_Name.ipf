#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function Set()
  PPTDoRenameMultipleWaves ("imon-", "Imon_", "", "")
//  PPTDoRenameMultipleWaves ("imon-2", "Imon_2", "", "")
  PPTDoRenameMultipleWaves ("adc-0", "No_Filter", "", "")
  PPTDoRenameMultipleWaves ("vmon-", "Vmon_", "", "")
  //PPTDoKillMultipleWaves ("adc", 1)
  //PPTDoKillMultipleWaves ("vmon", 1)
end
  