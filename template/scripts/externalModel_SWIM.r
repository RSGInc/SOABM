# Create External Trip Tables for JEMnR from SWIM subarea
# Converts SDT, LDT, CT and ET trip lists into JEMnr trip tables by
#   class type, time-of-day, tour purpose, trip purpose, Ext type (II,IE,EI,EE).
#
# Inputs: 
# 1. SL outputs from SWIM (SDT,LDT,CT and ET)
#       Trip list  ex: Trips_LDTPerson_select_link.csv
#       Zonal data ex: Employment.csv
# 2. SWIM to Local Zone Crosswalk (SWIM_JEMnR_TAZ_CW.csv)
# 3. Local zonal data (TAZ.csv)
# 4. SWIM select link file wiht count data (SelectLinks.csv)
#
# Outputs:
# 1. Trip tables by class type, trip purpose
#  1.1 Output PA format csv tables by trip purpose (8), total auto (1) and total truck (1)
#  1.2 If there are multiple sets then the outputs are written to the same location as the inputs
#  1.3: If there are multiple data sets, then all the outputs are averaged to another set "AVG_Output"
#  1.4:Outputs externalod_auto, externalod_truck, and externalod (total trips) matrices
#
# Author:
# Amar Sarvepalli    Sarvepalli@pbworld.com  06-01-2012
# Ben Stabler        stabler@pbworld.com     06-16-2012
#
# Modified:
# Alex Bettinardi    alexander.o.bettinardi 08-01-2012
# Ben Stabler        stabler@pbworld.com    12-04-2012
# Alex Bettinardi    alexander.o.bettinardi 05-08-2013 - to work with both OSUM and JEMnR 
# Ben Stabler        ben.stabler@rsginc.com 07-17-2015 - SOABM integration
# Alex Bettinardi    alexander.o.bettinardi 07-24-2015 - updates to work with SWIM 25 revisions - mainly, alpha2 beta now is provided in the select link zip file
# Alex Bettinardi    alexander.o.bettinardi 07-29-2015 - getting the code back up to the latest 2013 changes (Dec-27-13), and cleaning up a couple small issues.
# Alex Bettinardi    alexander.o.bettinardi 08-04-2015 - updating halo adjustment treatment to be more generic and work with the revised SWIM control tables.

cat("External model based on SWIM subarea process\n\n")

if(!("fun" %in% ls())) {
  
  cat("Run for SOABM\n\n")
  
  fun = list()
  runModel = TRUE
  
  omxScriptName = "scripts/omx.R"
  
  inputLoc = "inputs/"
  storeLoc = "outputs/"
  
  SWIM_SL_Filename_Pattern <- "_outputs"
  externalDisaggregateMethodNumber <- 1
  year <- 2010
  
  Crosswalk <- read.csv("inputs/SWIM_JEMnR_TAZ_CW.csv")
  
  TOD_periods <- read.csv("config/cvm/TOD_Periods.csv", header=T, as.is=T)      
  if(sum("daily" %in% TOD_periods$Period) == 0) {
    TOD_periods <- rbind(TOD_periods, list("daily", 0, 2359, "all times of the day", "24"))
  }
    
  externals <- read.csv("inputs/selectLinks.csv")
  pCols <- unlist(sapply(TOD_periods$Period, function(x) grep(paste("^",x,sep=""), colnames(externals))))
  colnames(externals)[pCols] <- names(pCols)
  externals <- externals[,c("STATIONNUMBER", "DIRECTION", "AutoAADT", "TruckAADT", "AADT_YEAR", names(pCols), "GrowthRate")]
  externals <- externals[order(externals$STATIONNUMBER,externals$DIRECTION),]
  rm(pCols)
  colnames(externals)[1] <- "station"
  
  maz <- read.csv("inputs/maz_data_export.csv")
  taz <- tapply(maz$TAZ,maz$TAZ,min)
  tazpopbase <- tapply(maz$POP,maz$TAZ,sum)
  tazempbase <- tapply(maz$EMP_TOTAL,maz$TAZ,sum)
  taz <- as.data.frame(cbind(TAZ=taz,POPBASE=tazpopbase,EMPBASE=tazempbase))
  taz <- taz[order(taz$TAZ),]
  rm(maz,tazpopbase,tazempbase)
  
  externalZones <- as.character(sort(unique(externals$station)))

}

fun$externalModelSWIM <- function(IPF=TRUE) {

	#process SWIM select link datasets to create RData files
	  processSLDataSets(SWIM_SL_Filename_Pattern, inputLoc)
	
	# Create external array
	# Choose a disaggregation  method (select between 1 to 4)
    disaggregateMethod <- c("SWIMPCT","LOCALPOPSHARE", "LOCALEMPSHARE", "LOCALPOP2EMPSHARE")
	  disaggregateMethod <- disaggregateMethod[externalDisaggregateMethodNumber]
	  print(paste("create external demand array using", disaggregateMethod))
	  out <- createExternalMatrices(disaggregateMethod, inputLoc, storeLoc)
	
	# IPF external matrix to counts   
    ipfExternalMatricesToCounts(IPF,storeLoc) #set to FALSE to skip IPF and just collapse on purpose
    
    # return ee, ie, ei trips to the R workspace
    out
}

#================================================================================================= 
# Function Definitions 
#================================================================================================= 

# create SWIM select link RData sets
fun$processSLDataSets <- function(SWIM_SL_Filename_Pattern, inputLoc) {

  # Get list of datasets by name of the folders (prefixed with "_SL")
	  datasets <- dir(path = inputLoc, pattern = paste(SWIM_SL_Filename_Pattern,".zip",sep=""), all.files = FALSE, 
	  	full.names = FALSE, recursive = FALSE, ignore.case = FALSE)
	  
	# Loop by dataset
  for(d in 1:length(datasets)) {
  
   # Get the folder name
     folderName <- paste(inputLoc, unlist(strsplit(datasets[d],".zip")), sep="")
   
   # Get output file name
     outFileName = paste(inputLoc,gsub(".zip", ".RData", datasets[d]), sep="")
   
   # If output file doesn't exist, create it
   if(!file.exists(outFileName)) {
			
			 print(paste("process SWIM select link datasets to create RData files\n", outFileName))
		 # Read year of SWIM run from file name   
       parsedName = strsplit(strsplit(datasets[d],SWIM_SL_Filename_Pattern)[[1]][1],"_")[[1]]
       swimyr = as.integer(parsedName[length(parsedName)])
   
	   # Read CSV files 
	     unzip(paste(inputLoc, datasets[d], sep=""), files = NULL, list = FALSE, overwrite = TRUE, junkpaths = TRUE, exdir = folderName)
	   
	     ct.. <- read.csv(paste(folderName, "/Trips_CTTruck_select_link.csv", sep=""), as.is=T)
	     et.. <- read.csv(paste(folderName, "/Trips_ETTruck_select_link.csv", sep=""), as.is=T)
	     ldt.. <- read.csv(paste(folderName, "/Trips_LDTPerson_select_link.csv", sep=""), as.is=T)
	     sdt.. <- read.csv(paste(folderName, "/Trips_SDTPerson_select_link.csv", sep=""), as.is=T)
	     emp.AzIn <- read.csv(paste(folderName, "/Employment.csv", sep=""), as.is=T)
	     rownames(emp.AzIn) <- emp.AzIn$Azone
	     sph.AzIp <- read.csv(paste(folderName, "/SynPop_Taz_Summary.csv", sep=""), as.is=T)
	     rownames(sph.AzIp) <- sph.AzIp$TAZ
	     
	     # additional code for swim25 to read in alpha2beta if it exits 7-24-15 AB
	     a2bCheck <- file.exists(paste(folderName, "/alpha2beta.csv", sep=""))
	     if(a2bCheck){
         a <- read.csv(paste(folderName, "/alpha2beta.csv", sep=""), as.is=T)
          rownames(a) <- a$Azone
          # one clean step that may not be needed for much longer, but won't hurt anything
          a$COUNTY <- gsub("Hood River", "HoodRiver",a$COUNTY) 
	     }
	     
	     # clean-up files
	     sapply(list.files(path=folderName, full.names=T), file.remove)
	     writeLines(paste("RD", gsub("/","\\\\",folderName)), "temp.bat")
	     system("temp.bat")
	     file.remove("temp.bat")
	     
	   # save to RData file
	     # additional if logic for swim25 to read in alpha2beta if it exits 7-24-15 AB
	     if(a2bCheck){
          save(list=c("a","ct..","et..","ldt..","sdt..","emp.AzIn","sph.AzIp","swimyr"), file=outFileName)
       } else {
          save(list=c("ct..","et..","ldt..","sdt..","emp.AzIn","sph.AzIp","swimyr"), file=outFileName)
	     }
	  }
	} 
}

#create external PA matrices (for multiple SWIM select link output scenarios)
# 0: Create zonal equivalency and disaggregation shares between SWIM and Local zones
# 0.1: Reads user specified input files
# 0.2: Identifies the select link output files from SWIM model by matching pattern specified in the "SWIM_SL_Filename_Pattern" and unzips files to a new folder with the same name.
# 0.3: Creates a zonal equivalency file and computes "SWIMPCT", "LOCALPOPSHARE", "LOCALEMPSHARE" and "LOCALPOP2EMPSHARE" 
# 1: Processes trips
# 1.1: Reads trip lists, filters out non-auto trips and applies vehicle occupancy factors and determines if trip is made by a local household or truck tour produced locally
# 1.2: Checks link percent on all records (although multiple paths exists for an od pair, the sum of link percents should equal to 100%)
# 1.3: Computes time period and flags PA and AP formats
# 1.5: Codes JEMnR trip purposes based on "tripPurpose" and "FROM_TRIP_TYPE" and "tourPurpose"
# 2: Creates trip matrices by vehicle class and trip purpose
# 2.1: Reshapes matrix to a square matrix and then converts into local zone matrix 
# 2.2: Truck trips are computed in similar way as total auto trips
fun$createExternalMatrices <- function( disaggregateMethod, inputLoc, storeLoc) {

  # Get list of datasets by name of the folders in RData format
	datasets <- dir(path=inputLoc,pattern=paste(SWIM_SL_Filename_Pattern,".RData",sep=""))

  # Reads SWIM pop, emp, passenger and truck trip data
  for(d in 1:length(datasets)) {
  
     load(paste(inputLoc, datasets[d], sep=""))
     
   # load the county controls developed for SWIM for areas outside of the "local" urban boundary
     load(paste(inputLoc, "swimControls.RData", sep=""))
     
   # Assign Counties to pop and emp tables
     sph.AzIp$County <- a[rownames(sph.AzIp), "COUNTY"]
     emp.AzIn$County <- a[rownames(emp.AzIn), "COUNTY"]
        
   #=================================================================================================
   # Build land use controls with SWIM distributions where needed (needed for zones outside JEMnR area).
   #=================================================================================================

   # sum SWIM population by county
      Pop.. <- as.data.frame(tapply(sph.AzIp$TotalPersons, sph.AzIp$County, sum))
      names(Pop..) <- "SWIMPOP"
      Pop..$POP <- 0
      # Create interpolate function
      interpolate <- function(year, Data..) {
         dif <- year - as.numeric(colnames(Data..))
         yrs <- colnames(Data..)[abs(dif) %in% sort(abs(dif))[1:2]]
         ifelse(rep(min(abs(dif))==0, nrow(Data..)), Data..[,dif==0], Data..[,yrs[1]]+(apply(Data..[,yrs],1,diff)/diff(as.numeric(yrs))*(year-as.numeric(yrs[1]))))
      }
      # interpolate to get correct year for population
      if(!as.character(year) %in% colnames(Pop.CoYr)){
         Pop.CoYr <- cbind(Pop.CoYr, interpolate(year, Pop.CoYr))
         colnames(Pop.CoYr)[ncol(Pop.CoYr)] <- year
      }
      Pop..[rownames(Pop.CoYr),"POP"] <- Pop.CoYr[,as.character(year)]
      # adjustment for Halo
      haloPop <- (sum(Pop..$SWIMPOP) * (1+((year-swimyr)*(sum(Pop.CoYr[,ncol(Pop.CoYr)]) - sum(Pop.CoYr[,1]))/diff(as.numeric(colnames(Pop.CoYr)[c(1,ncol(Pop.CoYr))])))/sum(Pop..$POP))) - sum(Pop..$POP) 
      Pop..[Pop..$POP == 0, "POP"] <- Pop..[Pop..$POP == 0, "SWIMPOP"] * (haloPop / sum(Pop..[Pop..$POP == 0, "SWIMPOP"]))   
      # Create a county adjustment factor
      Pop..$Adj <- Pop..$POP/Pop..$SWIMPOP
        
      # Create new population field at the TAZ level with adjusted population
      sph.AzIp$AdjustPop <- as.vector(sph.AzIp$TotalPersons * Pop..[sph.AzIp$County, "Adj"])
      # if 2010, overwrite with known census totals
      # logic for SWIM 25 - this is no longer needed 7-24-15 AB
      if(exists("pop10.Az")){
         if(year == 2010) sph.AzIp[names(pop10.Az),"AdjustPop"] <- pop10.Az 
         rm(pop10.Az)
      }         
      #clean up work space
      rm(haloPop, Pop..) 
      
      # Create an employment land use control
      # sum SWIM employment by county
      Emp.. <- as.data.frame(tapply(emp.AzIn$Total, emp.AzIn$County, sum))
      names(Emp..) <- "SWIMEMP"
      Emp..$Emp <- 0
      # interpolate to get correct year for employment
      if(!as.character(year) %in% colnames(Emp.CoYr)){
         Emp.CoYr <- cbind(Emp.CoYr, interpolate(year, Emp.CoYr))
         colnames(Emp.CoYr)[ncol(Emp.CoYr)] <- year
      }
      Emp..[rownames(Emp.CoYr),"Emp"] <- Emp.CoYr[,as.character(year)]
      # adjustment for Halo
      haloEmp <- (sum(Emp..$SWIMEMP) * (1+((year-swimyr)*(sum(Emp.CoYr[,ncol(Emp.CoYr)]) - sum(Emp.CoYr[,1]))/diff(as.numeric(colnames(Emp.CoYr)[c(1,ncol(Emp.CoYr))])))/sum(Emp..$Emp))) - sum(Emp..$Emp) 
      Emp..[Emp..$Emp == 0, "Emp"] <- Emp..[Emp..$Emp == 0, "SWIMEMP"] * (haloEmp / sum(Emp..[Emp..$Emp == 0, "SWIMEMP"]))   
      # Create a county adjustment factor
      Emp..$Adj <- Emp..$Emp/Emp..$SWIMEMP
     
      # Create new emp field at the TAZ level with adjusted employment
      emp.AzIn$AdjustEmp <- as.vector(emp.AzIn$Total * Emp..[emp.AzIn$County, "Adj"])
      # ensure that emp.AzIn is ordered that same as the sph file
      emp.AzIn <- emp.AzIn[rownames(sph.AzIp),]
      sph.AzIp$AdjustEmp <- emp.AzIn$AdjustEmp 
      # if 2010, overwrite with known employment distributions
      # logic for SWIM 25 - this is no longer needed 7-24-15 AB
      if(exists("emp10.Az")){
         if(year == 2010) sph.AzIp[names(emp10.Az),"AdjustEmp"] <- emp10.Az         
         rm(emp10.Az)
      }
      #clean up work space
      rm(haloEmp, Emp..)

   #=================================================================================================
   # Create zonal equivalency and disaggregation shares between SWIM and Local zones
   #=================================================================================================

    # Append to LOCAL pop and employment data to Zonal crosswalk file      
       Crosswalk$LOCALPOP <- taz$POPBASE[match(Crosswalk$LOCALZONE,taz$TAZ)] * (Crosswalk$LOCALPCT/100)
       Crosswalk$LOCALEMP <- taz$EMPBASE[match(Crosswalk$LOCALZONE,taz$TAZ)] * (Crosswalk$LOCALPCT/100)
       Crosswalk$County <- a[as.character(Crosswalk$SWIMZONE), "COUNTY"]
       
    # Compute Local population and employment totals by alpha zone 
       Pop.Az <- tapply(Crosswalk$LOCALPOP, Crosswalk$SWIMZONE,sum)
       Emp.Az <- tapply(Crosswalk$LOCALEMP, Crosswalk$SWIMZONE,sum)

       # add employment fields
       sph.AzIp$TotalEmp <- emp.AzIn$Total
       rm(emp.AzIn)

    # Overwrite alpha control totals with specific local area zone controls
       sph.AzIp[names(Pop.Az), "AdjustPop"] <- Pop.Az
       sph.AzIp[names(Emp.Az), "AdjustEmp"] <- Emp.Az
       
    # Update County controls   
       Pop.Co <- tapply(Crosswalk$LOCALPOP, Crosswalk$County,sum)
       popFac.Co <- (Pop.CoYr[names(Pop.Co),as.character(year)] - Pop.Co) /
                     tapply(sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)), "AdjustPop"], sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)), "County"], sum)[names(Pop.Co)]
       sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)) & (sph.AzIp$County %in% names(Pop.Co)), "AdjustPop"] <- sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)) & (sph.AzIp$County %in% names(Pop.Co)), "AdjustPop"] *
                                                                                                                 popFac.Co[sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)) & (sph.AzIp$County %in% names(Pop.Co)), "County"]]
       Emp.Co <- tapply(Crosswalk$LOCALEMP, Crosswalk$County,sum)
       empFac.Co <- (Emp.CoYr[names(Emp.Co),as.character(year)] - Emp.Co) /
                     tapply(sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)), "AdjustEmp"], sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)), "County"], sum)[names(Emp.Co)]
       sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)) & (sph.AzIp$County %in% names(Emp.Co)), "AdjustEmp"] <- sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)) & (sph.AzIp$County %in% names(Emp.Co)), "AdjustEmp"] *
                                                                                                                 empFac.Co[sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)) & (sph.AzIp$County %in% names(Emp.Co)), "County"]]
       
       rm(Pop.Co, Emp.Co, Pop.CoYr, Emp.CoYr, popFac.Co)      
    
    # Create desitination zonal adjustment factor opitions
       #subset sph.AzIp to only needed fields
       sph.AzIp <- sph.AzIp[,c("TAZ", "County", "TotalPersons", "AdjustPop", "TotalEmp", "AdjustEmp")]
       colnames(sph.AzIp) <- c("TAZ", "County", "SWIMPOP", "AdjustPop", "SWIMEMP", "AdjustEmp")       
       
       # create attraction level control using the user defined disaggregation method        
       if (disaggregateMethod == "SWIMPCT") {
           sph.AzIp$Atr <- (sph.AzIp$AdjustEmp * 2 + sph.AzIp$AdjustPop) 
           sph.AzIp$AtrFac <- sph.AzIp$Atr / (sph.AzIp$SWIMEMP * 2 + sph.AzIp$SWIMPOP)
           Crosswalk$AtrFac <- Crosswalk$SWIMPCT / 100
       }
       if (disaggregateMethod == "LOCALPOPSHARE") {
           sph.AzIp$Atr <- sph.AzIp$AdjustPop 
           sph.AzIp$AtrFac <- sph.AzIp$AdjustPop / sph.AzIp$SWIMPOP 
           Crosswalk$AtrFac <- Crosswalk$LOCALPOP / as.vector(tapply(Crosswalk$LOCALPOP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)])
       }
       if (disaggregateMethod == "LOCALEMPSHARE") {
           sph.AzIp$Atr <- sph.AzIp$AdjustEmp 
           sph.AzIp$AtrFac <- sph.AzIp$AdjustEmp / sph.AzIp$SWIMEMP 
           Crosswalk$AtrFac <- Crosswalk$LOCALEMP / as.vector(tapply(Crosswalk$LOCALEMP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)])
       }
       if (disaggregateMethod == "LOCALPOP2EMPSHARE") {
           sph.AzIp$Atr <- (sph.AzIp$AdjustEmp * 2 + sph.AzIp$AdjustPop) 
           sph.AzIp$AtrFac <- sph.AzIp$Atr / (sph.AzIp$SWIMEMP * 2 + sph.AzIp$SWIMPOP) 
           Crosswalk$AtrFac <- (Crosswalk$LOCALEMP * 2 + Crosswalk$LOCALPOP) / 
                               as.vector(tapply(Crosswalk$LOCALEMP * 2 + Crosswalk$LOCALPOP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)]) 
       }
       
       # Correct any nan's in the attraction factor
       sph.AzIp[is.nan(sph.AzIp$AtrFac),"AtrFac"] <- ifelse(sph.AzIp[is.nan(sph.AzIp$AtrFac),"Atr"] == 0, 0, 1)
       Crosswalk$AtrFac[is.nan(Crosswalk$AtrFac)] <- 0
        
       # create the production factor which is always a population factor
       sph.AzIp$ProFac <- sph.AzIp$AdjustPop / sph.AzIp$SWIMPOP       
       sph.AzIp[is.nan(sph.AzIp$ProFac),"ProFac"] <- ifelse(sph.AzIp[is.nan(sph.AzIp$ProFac),"AdjustPop"] == 0, 0, 1)
       Crosswalk$ProFac <- Crosswalk$LOCALPOP / as.vector(tapply(Crosswalk$LOCALPOP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)]) 
       Crosswalk$ProFac[is.nan(Crosswalk$ProFac)] <- 0
               
       #clean up work space 
       rm(Pop.Az, Emp.Az)    

       # write out the crosswalk for run analysis
       write.csv(Crosswalk, paste(storeLoc, "SWIM_TAZ_CW_Report.csv", sep=""), row.names=F)    
       write.csv(sph.AzIp, paste(storeLoc, "SWIM_TAZ_LUadj_Report.csv", sep=""), row.names=F)


     #=================================================================================================
     # Prep, Add Weights, and Combine SWIM trip tables to be used with JEMnR
     #=================================================================================================
       
       # Add trip lists by auto classes, remove non-auto modes, factor by veh occupancy
         auto_modes_veh_occ = c("DA"=1,"SR2"=2,"SR3P"=3.3)
         ldt.. <- ldt..[,c("origin","destination","tripMode","tripStartTime","tourPurpose","FROM_TRIP_TYPE","tripPurpose","HOME_ZONE",
           "EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT")]
         sdt..<- sdt..[,c("origin","destination","tripMode","tripStartTime","tourPurpose","FROM_TRIP_TYPE","tripPurpose","HOME_ZONE",
           "EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT")]
         auto <- rbind(sdt..,ldt..)
         auto <- auto[auto$tripMode %in% names(auto_modes_veh_occ),]
         auto$Volume <- 1 / auto_modes_veh_occ[as.character(auto$tripMode)]
         rm(auto_modes_veh_occ)
         
         #=================================================================================================
         # Compute JEMnR trip purpose (based on From / To trip purposes) 
         # Add missing FROM_TRIP_TYPE based on tourPurpose
         auto$FROM_TRIP_TYPE[auto$FROM_TRIP_TYPE == ""] <- auto$tourPurpose[auto$FROM_TRIP_TYPE == ""] 
         
         # Check if the trip is home-based (either FROM_TRIP_TYPE or tripPurpose purpose in home)
         auto$homebased <- 0
         auto$homebased[auto$FROM_TRIP_TYPE == "HOME" | auto$tripPurpose == "HOME"] <- 1
         
         # Code trip purpose
         auto$purpose <- ""
         auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="COLLEGE"     | auto$tripPurpose=="COLLEGE")]     <- "hbcoll"  # home-based college
         auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="RECREATE"    | auto$tripPurpose=="RECREATE")]    <- "hbr"  # home-based recreational
         auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="SHOP"        | auto$tripPurpose=="SHOP")]        <- "hbs"  # home-based shop  
         auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="GRADESCHOOL" | auto$tripPurpose=="GRADESCHOOL")] <- "hbsch" # home-based school 
         auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="OTHER"       | auto$tripPurpose=="OTHER")]       <- "hbo"  # home-based other
     
         auto$purpose[auto$homebased==1 & (auto$tripPurpose=="WORK" | auto$tripPurpose=="WORK_BASED" | auto$tripPurpose=="WORKRELATED" |
                                           auto$FROM_TRIP_TYPE=="WORK" | auto$FROM_TRIP_TYPE=="WORK_BASED" | auto$FROM_TRIP_TYPE=="WORKRELATED") ]  <- "hbw"  # home-based work
         
         auto$purpose[auto$homebased==0]  <- "nhbnw"                                                                                                             # nonhome-based other
         auto$purpose[auto$homebased==0 & (auto$tripPurpose=="WORK" | auto$tripPurpose=="WORK_BASED" | auto$tripPurpose=="WORKRELATED" |
                                           auto$FROM_TRIP_TYPE=="WORK" | auto$FROM_TRIP_TYPE=="WORK_BASED" | auto$FROM_TRIP_TYPE=="WORKRELATED")]   <- "nhbw"  # nonhome-based work

         # special code to crosswalk purposes to OSUM (if OSUM)
         if(exists("osumFun")){
            purpCW <-        c("hbw",   "hbro","hbshp","hbsch","hbro","hbw","nhb",  "nhb", "")
            names(purpCW) <- c("hbcoll","hbr", "hbs",  "hbsch","hbo", "hbw","nhbnw","nhbw", "") 
            auto$purpose <- purpCW[auto$purpose]         
         }

         #Weight trip table by population of the home zone for personal auto trips
         # this creates production level control
         
         auto$Pweight <- auto$Volume * sph.AzIp[as.character(auto$HOME_ZONE), "ProFac"] 
         #Save production level control totals
         ProdCont <- tapply(auto$Pweight, auto$HOME_ZONE, sum)

         #Weight on attraction end
         auto$Aweight <- sph.AzIp[as.character(auto$destination), "AtrFac"]
         #auto$Aweight[auto$HOME_ZONE == auto$destination] <- 1
         auto[is.na(auto$Aweight),"Aweight"] <- 1
         #data$Aweight <- data$Aweight*sum(data$Pweight)/sum(data$Aweight)
         
         # re-adjust productions
         auto$Weight <- auto$Pweight * auto$Aweight
         ProdCont <- ProdCont / tapply(auto$Weight, auto$HOME_ZONE, sum) 
         ProdCont[is.nan(ProdCont)] <- 0
         auto$Weight <- as.vector(auto$Weight * ProdCont[as.character(auto$HOME_ZONE)])
         rm(ProdCont)

               
       # Add trip lists by truck classes
         ct.. <- ct..[,c("origin","destination","tripStartTime","HOME_ZONE","EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT")]
         ct..$Volume = 1
         et.. <- et..[,c("origin","destination","tripStartTime","HOME_ZONE","EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT","truckVolume")]
         colnames(et..)[colnames(et..) == "truckVolume"] <- "Volume"
         truck <- rbind(ct..,et..)         
         # add purpose to truck table
         truck$purpose <- "truck"
         # Remove trucks's home zone before combining with auto - trucks adjustment will always be based on attraction
         truck$HOME_ZONE <- 0
         
         # add truck weights
         truck$Weight <- sph.AzIp[as.character(truck$destination), "AtrFac"]
         truck[is.na(truck$Weight),"Weight"] <- 1
         
       # combine both auto and truck into complete "data" set
         data <- rbind(auto[,names(truck)], truck)
         #data$Weight[is.na(data$Weight)] = 1 # this code was introduced by RSG, but it was really just masking another error in the steps above AB 7-24-15
         
         # creat time of day  
         data$TOD <- sapply(data$tripStartTime,function(x) paste(TOD_periods[x >= TOD_periods[,"StartTime"] & x < TOD_periods[,"EndTime"], "Period"], collapse="-"))   
         
         # create external tags
         data$ext <- "II"
         data[(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_ORIGIN"])) & !(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_DESTINATION"])),"ext"] <- "EI"
         data[!(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_ORIGIN"])) & (1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_DESTINATION"])),"ext"]  <- "IE"
         data[(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_ORIGIN"])) & (1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_DESTINATION"])),"ext"]  <- "EE"
         # remove auto table and truck
         rm(auto, truck, sdt.., ldt.., ct.., et..)
         
         # For the first dataset
         # create a blank matrix with all zone-to-zone, time-of-day, and mode (auto / truck) information
         
         if(d==1){
            # create purpose list
            extPurposes <- sort(unique(data$purpose))                       
         
            # Create the "zoneNames" object
            if(exists("osumFun")){
               zoneNames <- sort(c(as.numeric(row.names(ext.traffic)), taz.data$taz))
               internalZones <- sort(as.character(taz.data$taz))
            } else {   
               zoneNames <- sort(c(unique(externals$station),taz$TAZ)) #add externals
               internalZones <- sort(as.character(taz$TAZ))
            }
            # Creating a blank matrices with all zone-to-zone, time-of-day, and mode (auto / truck) information
            ext.ZnZnTdMd <- array(0, dim=c(length(zoneNames), length(zoneNames), nrow(TOD_periods), length(extPurposes)), 
                            dimnames=list(zoneNames, zoneNames, TOD_periods$Period, extPurposes)) 
         }
       
          #=================================================================================================
          # Check for LINK PERCENTS
          # Add link percent check (if there are multiple paths to OD, they all must sum to 100%)
          
            data$od <- paste(data$origin,data$destination,sep="-")
       
             # Get records whose link pcts != 100% 
             temp <- data[data$SELECT_LINK_PERCENT!=1,]
             if(dim(temp)[1] > 1) {
               uniqueLinkPct <- unique(temp$SELECT_LINK_PERCENT)
               # loop thru each link percent value and compute mean and count
               for (u in 1:length(uniqueLinkPct)) {
                 value        <- tapply(temp$SELECT_LINK_PERCENT[temp$SELECT_LINK_PERCENT==uniqueLinkPct[u]],temp$od[temp$SELECT_LINK_PERCENT==uniqueLinkPct[u]],mean)
                 count        <- tapply(temp$SELECT_LINK_PERCENT[temp$SELECT_LINK_PERCENT==uniqueLinkPct[u]],temp$od[temp$SELECT_LINK_PERCENT==uniqueLinkPct[u]],length)
                 
                 # Compute modulus of count and mean
                 r <- round((1 / value))
                 mod <-  count %% r
                 
                 # Report list of o-d pairs for which modulus is not zero (meaning the od link percents doesn't add up to 100%) 
                 if(mod > 0) {
                   checkLinkPct <- cbind(count,value, mod)
                   ifelse(exists("all_checkLinkPct"), all_checkLinkPct <- rbind(all_checkLinkPct,checkLinkPct), all_checkLinkPct <- checkLinkPct)
                 }
               }    
             }
             rm(temp)
             
            # Write od pairs to a csv file
            if(exists("all_checkLinkPct")){
              write.csv(all_checkLinkPct,"errors_in_trip_list_data.csv",row.names=T)
              rm(all_checkLinkPct,checkLinkPct)
            }
            
     #=================================================================================================
     # Fill JEMnR external array with disaggrated SWIM trip information
     #=================================================================================================
       
       # create a list of SWIM zones in the local area model
         LocalZones <- unique(Crosswalk$SWIMZONE)
         Vol <- tapply(data$Weight, paste(data$EXTERNAL_ZONE_ORIGIN, data$EXTERNAL_ZONE_DESTINATION, data$HOME_ZONE, data$purpose, data$TOD, data$ext), sum)
         rm(data)
          
       # Work through each record to disaggrate to JEMnR zones
         for(i in 1:length(Vol)){
            # Pull information from Volume vector
            # PA adjusted vehicle volume
            v <- Vol[i]
            # Origin zone
            oz <- unlist(strsplit(names(Vol)[i], " "))[1]
            # Destination Zone
            dz <- unlist(strsplit(names(Vol)[i], " "))[2]                
            # Is Local Zone check for proper Factor - either attraction or production
            f <- ifelse(unlist(strsplit(names(Vol)[i], " "))[3] %in% LocalZones, "ProFac", "AtrFac")
            # purpose
            p <- unlist(strsplit(names(Vol)[i], " "))[4]
            # time-of-day periods
            tods <- unlist(strsplit(unlist(strsplit(names(Vol)[i], " "))[5], "-"))
            # external tag
            xx <- unlist(strsplit(names(Vol)[i], " "))[6]
            # Create vectors of local zones
            oZns <- as.character(Crosswalk[as.character(Crosswalk$SWIMZONE) == oz,"LOCALZONE"])
            dZns <- as.character(Crosswalk[as.character(Crosswalk$SWIMZONE) == dz,"LOCALZONE"])

            # Case for EE flows
            if(xx == "EE") ext.ZnZnTdMd[gsub("_", "", oz), gsub("_", "", dz),tods,p] <- v + ext.ZnZnTdMd[gsub("_", "", oz), gsub("_", "", dz),tods,p]

            # Case for EI flows
            if(xx == "EI") ext.ZnZnTdMd[gsub("_", "", oz),dZns,tods,p] <- (v * Crosswalk[Crosswalk$SWIMZONE == as.numeric(dz),f]) + ext.ZnZnTdMd[gsub("_", "", oz),dZns,tods,p]

            # Case for IE flows
            if(xx == "IE") ext.ZnZnTdMd[oZns, gsub("_", "", dz),tods,p] <- (v * Crosswalk[Crosswalk$SWIMZONE == as.numeric(oz),f]) + ext.ZnZnTdMd[oZns,gsub("_", "", dz),tods,p]
  
            # Case for II flows
            if(xx == "II"){
               ext.ZnZnTdMd[oZns,dZns,tods,p] <- 
                  # I needed to vectorize in order to allow the matrix to fill the array
                  as.vector(v * outer(Crosswalk[Crosswalk$SWIMZONE == as.numeric(oz),f], Crosswalk[Crosswalk$SWIMZONE == as.numeric(dz),f])) + ext.ZnZnTdMd[oZns,dZns,tods,p]
            }
         
         } # end of the for loop
         # clean up after loop
         rm(v, oz, dz, f, p, tods, xx, oZns, dZns)   

  } # End multiple datasets

  # Averages multiple external PA matrices and writes output
  ext.ZnZnTdMd <- ext.ZnZnTdMd/length(datasets)
  save(ext.ZnZnTdMd, file=paste(storeLoc, "externalOD_ZnZnTdMd.RData", sep=""))
  
  #####################
  # This step needs to occur in this step to accomodate OSUM
  ######################
  # First pull SWIM auto and truck volumes for comparison
  SWIMauto <- apply(ext.ZnZnTdMd[,,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],1,sum) + apply(ext.ZnZnTdMd[,,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],2,sum)
  externals$SWIMauto <- round(SWIMauto[as.character(externals[,"station"])]/2)
  SWIMtruck <- apply(ext.ZnZnTdMd[,,"daily","truck"],1,sum) + apply(ext.ZnZnTdMd[,,"daily","truck"],2,sum)
  externals$SWIMtruck <- round(SWIMtruck[as.character(externals[,"station"])]/2) 
  # create SWIM truck percentage
  externals$SWIMtrkPct <- externals$SWIMtruck/(externals$SWIMtruck+externals$SWIMauto)   
        
  # For external stations without volume information (coded with NA), use SWIM truck percentages  
  if(any(is.na(externals$TruckAADT))) externals[is.na(externals$TruckAADT),c("AutoAADT", "TruckAADT")] <- cbind(externals[is.na(externals$TruckAADT),"AutoAADT"] * (1-externals$SWIMtrkPct[is.na(externals$TruckAADT)]), externals[is.na(externals$TruckAADT),"AutoAADT"] * externals$SWIMtrkPct[is.na(externals$TruckAADT)])
  externals <<- externals 
  
  #MODIFY CODE FOR JEMNR
  # kickout summary results to the R-workspace, for OSUM, but also of interest to JEMnR
  out <- list()
  out$total <- cbind(apply(ext.ZnZnTdMd[externalZones,externalZones,"daily",],1,sum) + apply(ext.ZnZnTdMd[externalZones,externalZones,"daily",],2,sum),
         apply(ext.ZnZnTdMd[internalZones,externalZones,"daily",],2,sum), apply(ext.ZnZnTdMd[externalZones,internalZones,"daily",],1,sum))
  
  out$auto <- cbind(apply(ext.ZnZnTdMd[externalZones,externalZones,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],1,sum) + apply(ext.ZnZnTdMd[externalZones,externalZones,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],2,sum),
         apply(ext.ZnZnTdMd[internalZones,externalZones,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],2,sum), apply(ext.ZnZnTdMd[externalZones,internalZones,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],1,sum))
  
  out$truck <- cbind(apply(ext.ZnZnTdMd[externalZones,externalZones,"daily","truck"],1,sum) + apply(ext.ZnZnTdMd[externalZones,externalZones,"daily","truck"],2,sum),
         apply(ext.ZnZnTdMd[internalZones,externalZones,"daily","truck"],2,sum), apply(ext.ZnZnTdMd[externalZones,internalZones,"daily","truck"],1,sum))
  colnames(out$total) <- colnames(out$auto) <- colnames(out$truck) <- c("ee", "ie", "ei")
     
  out
}

# Custom IPF function for external Matrices
fun$extIPF <- function(rowcontrol, colcontrol, fullMat, extSta, period, maxiter=100, closure=0.0001){
           # input data checks: sum of marginal totals equal and no zeros in marginal totals
           #if(sum(rowcontrol) != sum(colcontrol)) stop("sum of rowcontrol must equal sum of colcontrol")
           if(any(rowcontrol==0)){
              numzero <- sum(rowcontrol==0)
              rowcontrol[rowcontrol==0] <- 0.001
              warning(paste(numzero, "zeros in rowcontrol argument replaced with 0.001 for period =", period, sep=" "))
           }
           if(any(colcontrol==0)){
              numzero <- sum(colcontrol==0)
              colcontrol[colcontrol==0] <- 0.001
              warning(paste(numzero, "zeros in colcontrol argument replaced with 0.001 for period =", period, sep=" "))
           }
         
           # set initial values
           result <- fullMat
           ee <- fullMat[extSta, extSta]
           ei <- fullMat[extSta, !(colnames(fullMat) %in% extSta)]
           ie <- fullMat[!(colnames(fullMat) %in% extSta), extSta]
           rowcheck <- 1
           colcheck <- 1
           iter <- 0
           
           # successively proportion rows and columns until closure or iteration criteria are met
           while(((rowcheck > closure) | (colcheck > closure)) & (iter < maxiter)){
	            # Row adjustment
              rowtotal <- rowSums(cbind(ee,ei))
	            rowfactor <- rowcontrol/rowtotal
	            rowfactor[is.infinite(rowfactor)] <- 1
	            ee <- sweep(ee, 1, rowfactor, "*")
	            ei <- sweep(ei, 1, rowfactor, "*")
	            
	            # Col Adjustments
	            coltotal <- colSums(rbind(ee,ie))
	            colfactor <- colcontrol/coltotal
	            colfactor[is.infinite(colfactor)] <- 1
	            ee <- sweep(ee, 2, colfactor, "*")
	            ie <- sweep(ie, 2, colfactor, "*")
	            
              rowcheck <- sum(abs(1-rowfactor))
	            colcheck <- sum(abs(1-colfactor))
	            iter <- iter + 1
	            #print(paste(iter, round(rowcheck,5), round(colcheck,5))) #useful in checking ipf's that don't close
           }
           if(iter == maxiter) print(paste( "The maximum (", iter, ") number of iterations was reached the externalModel ipf did NOT close for period=", period, sep=""))

           # Repack the EE, EI, and IE into the full matrix
           result[extSta, extSta] <- ee
           result[extSta, !(colnames(result) %in% extSta)] <- ei
           result[!(colnames(result) %in% extSta), extSta] <- ie
           result
}

#IPF external matrices (auto and truck) to counts
fun$ipfExternalMatricesToCounts <- function(IPF,storeLoc) {

	#get OD array 
  load(paste(storeLoc, "externalOD_ZnZnTdMd.RData", sep=""))
 
  # create the truck and auto AADTs to be used
  ############################################
  
  # Adjust volumes to analysis year
  # only run from JEMnR, in OSUM this is handeled externally to address special generators
  if(!exists("osumFun")){
     externals$daily_auto <- externals$AutoAADT * (1 + (externals$GrowthRate*(year  - externals$AADT_YEAR)))
     externals$daily_truck <- externals$TruckAADT * (1 + (externals$GrowthRate*(year  - externals$AADT_YEAR)))
  }
  # write out edited externals table for external model diagonistics
  write.csv(externals, paste(storeLoc, "selectLinks_Report.csv", sep=""), row.names=F)
  
  # save externals names to remove temp fields
  extNames <- names(externals)
 
  # create period volume controls
  for(p in TOD_periods$Period[TOD_periods$Period != "daily"]) {
     externals$temp <- externals$daily_auto * externals[,p]
     names(externals)[length(externals)] <- paste(p, "auto", sep="_")
     externals$temp <- externals$daily_truck * externals[,p]
     names(externals)[length(externals)] <- paste(p, "truck", sep="_")
  }
 
  
  if(IPF){
  print("IPF external matrix to counts")
  # Create all the period external matrices
  for(p in TOD_periods$Period){
     
     # create an auto seed for the period      
     seed <- apply(ext.ZnZnTdMd[,,p,!dimnames(ext.ZnZnTdMd)[[4]] %in% "truck"],1:2,sum)
     # check to ensure that the seed has enough information for the period - if not, use daily
     if(any(rowSums(seed[as.character(externalZones),])==0) | any(colSums(seed[,as.character(externalZones)])==0)){        
        seed <- apply(ext.ZnZnTdMd[,,"daily",!dimnames(ext.ZnZnTdMd)[[4]] %in% "truck"],1:2,sum)
        puSplit <- apply(ext.ZnZnTdMd[,,p,!dimnames(ext.ZnZnTdMd)[[4]] %in% "truck"],3,sum)/sum(ext.ZnZnTdMd[,,p,!dimnames(ext.ZnZnTdMd)[[4]] %in% "truck"])
        ipfResult <-  extIPF(externals[externals$DIRECTION=="IN", paste(p,"auto",sep="_")], externals[externals$DIRECTION=="OUT", paste(p,"auto",sep="_")],seed, as.character(externalZones),p)
	      for(pu in names(puSplit)){ 
           ext.ZnZnTdMd[,,p,pu] <- ipfResult*puSplit[pu]
        }   
     } else {
        # run the ipf for auto
        ipfResult <-  extIPF(externals[externals$DIRECTION=="IN", paste(p,"auto",sep="_")], externals[externals$DIRECTION=="OUT", paste(p,"auto",sep="_")],seed, as.character(externalZones),p)
	      # fill the ipf information back into the array
        sweepStat <- ipfResult/seed
        sweepStat[is.nan(sweepStat)] <- 0 
        ext.ZnZnTdMd[,,p,!dimnames(ext.ZnZnTdMd)[[4]] %in% "truck"] <- sweep(ext.ZnZnTdMd[,,p,!dimnames(ext.ZnZnTdMd)[[4]] %in% "truck"], c(1:2), sweepStat, "*")
	   }
	   
	   # run the ipf for truck and fill the array
	   seed <- ext.ZnZnTdMd[,,p,"truck"]
     # check to ensure that the seed has enough information for the period - if not, use daily
     if(any(rowSums(seed[as.character(externalZones),])==0) | any(colSums(seed[,as.character(externalZones)])==0)){        
        seed <- ext.ZnZnTdMd[,,"daily","truck"]
     }
	   # run the ipf for truck
     ext.ZnZnTdMd[,,p,"truck"] <- extIPF(externals[externals$DIRECTION=="IN", paste(p,"truck",sep="_")], externals[externals$DIRECTION=="OUT", paste(p,"truck",sep="_")],seed, as.character(externalZones),p) 	  
  }
  
  externals <<- externals[,extNames]    
	
	# export the external information being used in the run 
	save(ext.ZnZnTdMd, file=paste(storeLoc, "externalOD_ZnZnTdMd.RData", sep=""))
	
	if(file.exists(omxScriptName)) { 
		
		print("write OMX matrices")
		
		source(omxScriptName)
	 	fName = paste(storeLoc, "externalOD.omx", sep="")
		createFileOMX(fName, nrow(ext.ZnZnTdMd), nrow(ext.ZnZnTdMd))
		writeLookupOMX(fName, dimnames(ext.ZnZnTdMd)[1][[1]], "NO")
	
		timeperiods = dimnames(ext.ZnZnTdMd)[3][[1]]
		purposes = dimnames(ext.ZnZnTdMd)[4][[1]]
	
		for(i in 1:length(timeperiods)) {
			for(j in 1:length(purposes)) {
		
				mat = ext.ZnZnTdMd[,,timeperiods[i],purposes[j]]
				matName = paste(timeperiods[i],purposes[j],sep="_")
				writeMatrixOMX(fName, mat, matName)
			}
		}
	}
	
	ext.ZnZnTdMd
	}
}
   
  
#run model
if(runModel) { 
	attach(fun)
  externalModelSWIM()
} 
 
