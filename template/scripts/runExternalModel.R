########################################################################################
# Shell script to run the SWIM external model
#
# This script does the following:-
# 1. Sources all the required functions from the SWIM stanalone script
# 2. Reads in and processes the input data required for external model
# 3. Calls the appropriate functions
#
# Author: binny.mathewpaul@rsginc.com Dec 2018
########################################################################################

cat("Running External Model....\n\n")

### Prep data and functions for the run
if(!("fun" %in% ls())) {
  
  cat("Run for SOABM\n\n")
  
  fun = list()
  runModel = TRUE
  
  library(omxr) #OMX matrices
  
  ## source SWIM functions
  source("scripts/externalModel_SWIM_ODOT_Standalone.R")
  
  inputLoc = "inputs/"
  storeLoc = "outputs/other/"
  storeLocTrips = "outputs/trips/"
  omxScriptName = "scripts/omx.r"
  
  # read in SWIM settings file
  settings <- read.csv("config/swim_ext/SWIM_External_Properties.csv", header = TRUE)
  
  SWIM_SL_Filename_Pattern            <- trimws(paste(settings$value[settings$key=="SWIM_SL_Filename_Pattern"]))	
  externalDisaggregateMethodNumber    <- as.numeric(trimws(paste(settings$value[settings$key=="externalDisaggregateMethodNumber"])))
  year                                <- as.numeric(trimws(paste(settings$value[settings$key=="year"])))
  Crosswalk_File                      <- trimws(paste(settings$value[settings$key=="Crosswalk"]))	
  
  #SWIM_SL_Filename_Pattern <- "_outputs"
  #externalDisaggregateMethodNumber <- 4
  #year <- 2010
  
  Crosswalk <- read.csv(paste(inputLoc, Crosswalk_File, sep=""))
  
  TOD_periods <- read.csv("config/cvm/TOD_Periods.csv", header=T, as.is=T)      
  if(sum("daily" %in% TOD_periods$Period) == 0) {
    TOD_periods <- rbind(TOD_periods, list("daily", 0, 2359, "all times of the day", "24"))
  }
  
  externals <- read.csv(paste(inputLoc, "selectLinks.csv", sep=""))
  pCols <- unlist(sapply(TOD_periods$Period, function(x) grep(paste("^",x,sep=""), colnames(externals))))
  colnames(externals)[pCols] <- names(pCols)
  externals <- externals[,c("STATIONNUMBER", "DIRECTION", "AutoAWDT", "TruckAWDT", "AWDT_YEAR", names(pCols), "GrowthRate")]
  externals <- externals[order(externals$STATIONNUMBER,externals$DIRECTION),]
  rm(pCols)
  colnames(externals)[1] <- "station"
  
  maz <- read.csv(paste(inputLoc, "maz_data_export.csv", sep=""))
  taz <- tapply(maz$TAZ,maz$TAZ,min)
  tazpopbase <- tapply(maz$POP,maz$TAZ,sum)
  tazempbase <- tapply(maz$EMP_TOTAL,maz$TAZ,sum)
  taz <- as.data.frame(cbind(TAZ=taz,POPBASE=tazpopbase,EMPBASE=tazempbase))
  taz <- taz[order(taz$TAZ),]
  rm(maz,tazpopbase,tazempbase)
  
  externalZones <- as.character(sort(unique(externals$station)))
  
}



### Run model
if(runModel) { 
  attach(fun)
  extModelSWIM()
} 

### Copy OMX trip table to trips output folder
source_file <- paste(storeLoc, "externalOD.omx", sep = "")
if(file.exists(source_file)){
  file.copy(source_file, storeLocTrips, overwrite = T, copy.date = T)
}else{
  cat(paste(source_file, "does not exist in", storeLoc))
  quit(status = 1)
}



#Finish