import sys, pandas as pd
sys.path.append("scripts")
from Properties import Properties

#read properties file
properties = Properties()
properties.loadPropertyFile("config\orramp.properties")
mazFilename = properties['mgra.socec.file']
hhFilename = properties['PopulationSynthesizer.InputToCTRAMP.HouseholdFile']

#read data files
print("read households and maz data file")
mazs = pd.read_csv(mazFilename.strip("/"))
hhs = pd.read_csv(hhFilename.strip("/"))

#for hhs, get mazseq and copy maz to maz_initial
if "maz_initial" not in hhs.columns:
  print("for hhs, get mazseq and copy maz to maz_initial")
  mazs.index = mazs.NO
  hhs["maz_initial"] = hhs.maz
  hhs.maz = mazs.loc[hhs.maz].MAZ.tolist()
else:
  print("maz_initial column already in hhs table so do not renumber mazs")

#check that each hh's maz is in the maz file
result = hhs["maz_initial"].isin(mazs.NO).all()
print("check that each hh's maz is in the maz file: " + str(result))

#write households with sequential maz numbers
print("write households with sequential maz numbers")
hhs.to_csv(hhFilename.strip("/"), index=False)
