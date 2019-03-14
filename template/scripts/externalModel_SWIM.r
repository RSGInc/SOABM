    
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
    # Alex Bettinardi    alexander.o.bettinardi 12-27-2013 - to work with both OSUM and JEMnR 
    # Alex Bettinardi    alexander.o.bettinardi 07-24-2015 - updates to work with SWIM 25 revisions - mainly, alpha2 beta now is provided in the select link zip file
    # Alex Bettinardi    alexander.o.bettinardi 07-29-2015 - getting the code back up to the latest 2013 changes (Dec-27-13), and cleaning up a couple small issues.
    # Alex Bettinardi    alexander.o.bettinardi 08-04-2015 - updating halo adjustment treatment to be more generic and work with the revised SWIM control tables.
    # Alex Bettinardi    alexander.o.bettinardi@odot.state.or.us 8/26/15- Changed to use AWDT fields select_link.csv as opposed to AADT, which was incorrect field naming
    # Martin Mann 01/08/16  In the createExtMats function: Added parallelization using the doParallel library.  
    #                        Used with TOD field creation for the data table and the loop filling the output matrix.  
    #                        Added code to replace the taz table loaded from the taz.csv file in the inputs folder with a 
    #                        taz with the full population (University model run only)   
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 3/2/16- re-unified the ABM, OSUM, and JEMnR code, removed CALM specific code - that process is handled externally to this code.
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 7/20/16- fixed identifed time-of-day coding issue, and corrected issue where county employement projections are assumed to hold true into the future. 
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 3/13/17- Updated the LDT filename that the code points to (the person copy was never a good one to use, and we have found that SWIM is not exporting correctly, additionally fixed a small issue/warning with the error reporting fuctionality that PB added, and which should probably eventually be removed.
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 3/21/17- The code was not properly setup to work with disaggregate Method, "SWIMPCT" (1), updates were made to allow this functionality to work.
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 1/5/18 - Blocked load and library warnings, removed redundent error file print, upped iterations in IPF to 100.
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 9/19/18 - Corrected for the condition that a night OD by purpose could be totally empty - reporting back to the user if controls don't match in general
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 1/23/19 - Corrected a spelling error in the IPF warning message
    # Alex Bettinardi     alexander.o.bettinardi@odot.state.or.us 3/13/19 - Updating some small typos in messages to the screen
          
      ############################ CREATE EXTERNAL OD MATRICES ############################################      
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
      
    # load required libraries
    options(warn=-1)
    suppressMessages(library(doParallel))
    options(warn=0)  

                            
    cat("External model based on SWIM subarea process\n\n")
    
    ##################################### MAIN CALLING FUNCTION ##############################################
    
    fun$extModelSWIM <- function(IPF=TRUE) {
                          
                            #Process SWIM select link datasets to create RData files
                         	  procSLDataSets(SWIM_SL_Filename_Pattern, inputLoc)
                              	
                           	#Create external array
                            disaggregateMethod <- c("SWIMPCT","LOCALPOPSHARE", "LOCALEMPSHARE", "LOCALPOP2EMPSHARE")
                         	  disaggregateMethod <- disaggregateMethod[externalDisaggregateMethodNumber]  #Choose a disaggregation  method (select between 1 to 4)
                         	  print(paste("create external demand array using", disaggregateMethod))
                         	  out <- createExtMats(disaggregateMethod, inputLoc, storeLoc)
                              	
                           	#IPF external matrix to counts   
                            ipfExtMatsToCounts(IPF,storeLoc) #set to FALSE to skip IPF and just collapse on purpose
                                  
                            #Return ee, ie, ei trips to the R workspace
                            out
                          
                        }
    
    #================================================================================================= 
    ######################################### SUB FUNCTIONS ###########################################
    #================================================================================================= 
    
    
    ############################ PROCESS SELECT LINK OUTPUT FROM SWIM ############################################
    
    fun$procSLDataSets <- function(SWIM_SL_Filename_Pattern, inputLoc) {

                              #Get list of datasets by name of the folders (prefixed with "_SL")
                           	  datasets <- dir(path = inputLoc, pattern = paste(SWIM_SL_Filename_Pattern,".zip",sep=""), all.files = FALSE, 
                            	  	              full.names = FALSE, recursive = FALSE, ignore.case = FALSE)
                            	  
                            	#Loop by dataset
                              for(d in 1:length(datasets)) {                  
                                    #Get the folder name
                                    folderName <- paste(inputLoc, unlist(strsplit(datasets[d],".zip")), sep="")
                                   
                                    #Get output file name
                                    outFileName = paste(inputLoc,gsub(".zip", ".RData", datasets[d]), sep="")
                                   
                                    #If output file doesn't exist, create it
                                    if(!file.exists(outFileName)) {
                                          writeLines(paste("process SWIM select link datasets to create RData files\n", outFileName)) # 3-13-19 AB - change from a print to a writeLines so that the \n would work properly
                                    		  #Read year of SWIM run from file name   
                                          parsedName = strsplit(strsplit(datasets[d],SWIM_SL_Filename_Pattern)[[1]][1],"_")[[1]]
                                          swimyr = as.integer(parsedName[length(parsedName)])
                                       
                                    	    #Read CSV files 
                                    	    unzip(paste(inputLoc, datasets[d], sep=""), files = NULL, list = FALSE, overwrite = TRUE, junkpaths = TRUE, exdir = folderName)
                                    	    ct.. <- read.csv(paste(folderName, "/Trips_CTTruck_select_link.csv", sep=""), as.is=T)
                                    	    et.. <- read.csv(paste(folderName, "/Trips_ETTruck_select_link.csv", sep=""), as.is=T)
                                    	    ldt.. <- read.csv(paste(folderName, "/Trips_LDTVehicle_select_link.csv", sep=""), as.is=T) # changed this from Persons to Vehicle - 3-13-17 AB
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
                                           
                                    	    #Clean-up files
                                    	    sapply(list.files(path=folderName, full.names=T), file.remove)
                                    	    writeLines(paste("RD", gsub("/","\\\\",folderName)), "temp.bat")
                                    	    system("temp.bat")
                                    	    file.remove("temp.bat")
                                    	     
                                    	    #Save to RData file
                                    	     # additional if logic for swim25 to read in alpha2beta if it exits 7-24-15 AB
	                                         if(a2bCheck){
                                              save(list=c("a","ct..","et..","ldt..","sdt..","emp.AzIn","sph.AzIp","swimyr"), file=outFileName)
                                           } else {
                                              save(list=c("ct..","et..","ldt..","sdt..","emp.AzIn","sph.AzIp","swimyr"), file=outFileName)
	                                         }
                                        }
                           	  } 
                          }
      

      ############################ CREATE EXTERNAL OD MATRICES ############################################
      
      fun$createExtMats <- function( disaggregateMethod, inputLoc, storeLoc) {
                            
                            if(exists("runUniversityModel")){
                            if(runUniversityModel) {
                                  tempTaz <- taz
                                  taz <- read.csv("inputs/taz_census.csv")
                                  rownames(taz) <- taz$TAZ
                            }}
                                
                            #Get list of datasets by name of the folders in RData format
                          	datasets <- dir(path=inputLoc,pattern=paste(SWIM_SL_Filename_Pattern,".RData",sep=""))
                          
                            ########### START LOOP FOR MULTIPLE DATA SETS ##################################
                            
                            for(d in 1:length(datasets)) {
                                  
                                  #Reads SWIM pop, emp, passenger and truck trip data
                                  load(paste(inputLoc, datasets[d], sep=""))
                               
                                  #Load the county controls developed for SWIM for areas outside of the "local" urban boundary
                                  load(paste(inputLoc, "swimControls.RData", sep=""))
                                   
                                  #Assign Counties to pop and emp tables
                                  sph.AzIp$County <- a[rownames(sph.AzIp), "COUNTY"]
                                  emp.AzIn$County <- a[rownames(emp.AzIn), "COUNTY"]
                                      
                                  #=================================================================================================
                                  # Build land use controls with SWIM distributions where needed (needed for zones outside JEMnR area).
                                  #=================================================================================================
                              
                                  #Sum SWIM population by county
                                  Pop.. <- as.data.frame(tapply(sph.AzIp$TotalPersons, sph.AzIp$County, sum))
                                  names(Pop..) <- "SWIMPOP"
                                  Pop..$POP <- 0
                                  
                                  #Create interpolate function
                                  interpolate <- function(year, Data..) {
                                                   dif <- year - as.numeric(colnames(Data..))
                                                   yrs <- colnames(Data..)[abs(dif) %in% sort(abs(dif))[1:2]]
                                                   ifelse(rep(min(abs(dif))==0, nrow(Data..)), Data..[,dif==0], Data..[,yrs[1]]+(apply(Data..[,yrs],1,diff)/diff(as.numeric(yrs))*(year-as.numeric(yrs[1]))))
                                                  }
                                  #Interpolate to get correct year for population
                                  if(!as.character(year) %in% colnames(Pop.CoYr)){
                                        Pop.CoYr <- cbind(Pop.CoYr, interpolate(year, Pop.CoYr))
                                        colnames(Pop.CoYr)[ncol(Pop.CoYr)] <- year
                                  }
                                  Pop..[rownames(Pop.CoYr),"POP"] <- Pop.CoYr[,as.character(year)]
                                  
                                  #Adjustment for Halo
                                  haloPop <- (sum(Pop..$SWIMPOP) * (1+((year-swimyr)*(sum(Pop.CoYr[,ncol(Pop.CoYr)]) - sum(Pop.CoYr[,1]))/diff(as.numeric(colnames(Pop.CoYr)[c(1,ncol(Pop.CoYr))])))/sum(Pop..$POP))) - sum(Pop..$POP) 
                                  Pop..[Pop..$POP == 0, "POP"] <- Pop..[Pop..$POP == 0, "SWIMPOP"] * (haloPop / sum(Pop..[Pop..$POP == 0, "SWIMPOP"]))        
                                  Pop..$Adj <- Pop..$POP/Pop..$SWIMPOP   #Create a county adjustment factor
                                      
                                  #Create new population field at the TAZ level with adjusted population
                                  sph.AzIp$AdjustPop <- as.vector(sph.AzIp$TotalPersons * Pop..[sph.AzIp$County, "Adj"])
                                  #if 2010, overwrite with known census totals
                                  # logic for SWIM 25 - this is no longer needed 7-24-15 AB
                                  if(exists("pop10.Az")){
                                     if(year == 2010) sph.AzIp[names(pop10.Az),"AdjustPop"] <- pop10.Az 
                                     rm(pop10.Az)
                                  }     
                                  rm(haloPop, Pop..) 
                                    
                                  #Create an employment land use control
                                  Emp.. <- as.data.frame(tapply(emp.AzIn$Total, emp.AzIn$County, sum))  #sum SWIM employment by county
                                  names(Emp..) <- "SWIMEMP"
                                  Emp..$Emp <- 0
                                  
                                  #Interpolate to get correct year for employment
                                  if(!as.character(year) %in% colnames(Emp.CoYr)){
                                        Emp.CoYr <- cbind(Emp.CoYr, interpolate(year, Emp.CoYr))
                                        colnames(Emp.CoYr)[ncol(Emp.CoYr)] <- year
                                  }
                                  Emp..[rownames(Emp.CoYr),"Emp"] <- Emp.CoYr[,as.character(year)]
                                  
                                  #Adjustment for Halo
                                  haloEmp <- (sum(Emp..$SWIMEMP) * (1+((year-swimyr)*(sum(Emp.CoYr[,ncol(Emp.CoYr)]) - sum(Emp.CoYr[,1]))/diff(as.numeric(colnames(Emp.CoYr)[c(1,ncol(Emp.CoYr))])))/sum(Emp..$Emp))) - sum(Emp..$Emp) 
                                  Emp..[Emp..$Emp == 0, "Emp"] <- Emp..[Emp..$Emp == 0, "SWIMEMP"] * (haloEmp / sum(Emp..[Emp..$Emp == 0, "SWIMEMP"]))   
                                  #Create a county adjustment factor
                                  Emp..$Adj <- Emp..$Emp/Emp..$SWIMEMP
                                   
                                  #Create new emp field at the TAZ level with adjusted employment
                                  emp.AzIn$AdjustEmp <- as.vector(emp.AzIn$Total * Emp..[emp.AzIn$County, "Adj"])
                                  emp.AzIn <- emp.AzIn[rownames(sph.AzIp),] #Ensure that emp.AzIn is ordered that same as the sph file
                                  sph.AzIp$AdjustEmp <- emp.AzIn$AdjustEmp 
                                  #If 2010, overwrite with known employment distributions 
                                  # logic for SWIM 25 - this is no longer needed 7-24-15 AB
                                  if(exists("emp10.Az")){
                                     if(year == 2010) sph.AzIp[names(emp10.Az),"AdjustEmp"] <- emp10.Az         
                                     rm(emp10.Az)
                                  }     
                                  rm(haloEmp, Emp..)
                              
                                  #=================================================================================================
                                  # Create zonal equivalency and disaggregation shares between SWIM and Local zones
                                  #=================================================================================================
                              
                                  #Append to LOCAL pop and employment data to Zonal crosswalk file      
                                  Crosswalk$LOCALPOP <- taz$POPBASE[match(Crosswalk$LOCALZONE,taz$TAZ)] * (Crosswalk$LOCALPCT/100)
                                  Crosswalk$LOCALEMP <- taz$EMPBASE[match(Crosswalk$LOCALZONE,taz$TAZ)] * (Crosswalk$LOCALPCT/100)
                                  Crosswalk$County <- a[as.character(Crosswalk$SWIMZONE), "COUNTY"]
                              
                                  #Compute Local population and employment totals by alpha zone 
                                  Pop.Az <- tapply(Crosswalk$LOCALPOP, Crosswalk$SWIMZONE,sum)
                                  Emp.Az <- tapply(Crosswalk$LOCALEMP, Crosswalk$SWIMZONE,sum)
                              
                                  #Add employment fields
                                  sph.AzIp$TotalEmp <- emp.AzIn$Total
                                  rm(emp.AzIn)
                              
                                  #Overwrite alpha control totals with specific local area zone controls
                                  sph.AzIp[names(Pop.Az), "AdjustPop"] <- Pop.Az
                                  sph.AzIp[names(Emp.Az), "AdjustEmp"] <- Emp.Az
                                     
                                  #Update County Poulation controls   
                                  Pop.Co <- tapply(Crosswalk$LOCALPOP, Crosswalk$County,sum)
                                  countyPopTotals <- tapply(sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)), "AdjustPop"], sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)), "County"], sum)[names(Pop.Co)]
                                  popFac.Co <- (Pop.CoYr[names(Pop.Co),as.character(year)] - Pop.Co) / countyPopTotals
                                  # 7-20-16 AB - new hard stop if any of these values are negative
                                  if(any(popFac.Co<0)) stop("Some of the County level population controls went negative.\nThis is a hard stop in the code in the SWIM external model.\nYou need to review your total population by County in your TAZ input and the year you have specfied for this model.\nThis error indicates that those county level population totals are greater than the population totals by year in the swimControl.Rdata input file.\nMeaning that you have more population for your County in your model than has been specified by OEA.\nReivew TAZ, year, and swimControls.RData inputs to determine where the issue is.\nAsk Alex Bettinardi if there are any questions.") 
                                                   
                                  #Adjust Population using County Controls
                                  curAdjPop <- sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)) & (sph.AzIp$County %in% names(Pop.Co)), "AdjustPop"]
                                  popFacByCnty <- popFac.Co[sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)) & (sph.AzIp$County %in% names(Pop.Co)), "County"]]
                                  sph.AzIp[!(rownames(sph.AzIp) %in% names(Pop.Az)) & (sph.AzIp$County %in% names(Pop.Co)), "AdjustPop"] <- curAdjPop * popFacByCnty                    

                                  #Update County Employment controls 
                                  Emp.Co <- tapply(Crosswalk$LOCALEMP, Crosswalk$County,sum)
                                  countyEmpTotals <- tapply(sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)), "AdjustEmp"], sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)), "County"], sum)[names(Emp.Co)]
                                  empFac.Co <- (Emp.CoYr[names(Emp.Co),as.character(year)] - Emp.Co) / countyEmpTotals
                                  
                                  #Adjust Employment using County Controls
                                  curAdjEmp <- sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)) & (sph.AzIp$County %in% names(Emp.Co)), "AdjustEmp"] 
                                  empFacByCnty <-  empFac.Co[sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)) & (sph.AzIp$County %in% names(Emp.Co)), "County"]]                
                                  # removed this adjustment on 7-19-16 (AB) because this step incorrectly assumes that county level employment projections for the state mean something 
                                  # since no one is held to them this step can go negative which is not correct, and there is no information availalbe to improve this step, hence just remove it.
                                  #sph.AzIp[!(rownames(sph.AzIp) %in% names(Emp.Az)) & (sph.AzIp$County %in% names(Emp.Co)), "AdjustEmp"] <- curAdjEmp * empFacByCnty
                                  
                                  rm(Pop.Co, Emp.Co, Pop.CoYr, Emp.CoYr, popFac.Co)      
                                  
                                  #Create destination zonal adjustment factor opitions
                                  sph.AzIp <- sph.AzIp[,c("TAZ", "County", "TotalPersons", "AdjustPop", "TotalEmp", "AdjustEmp")] #subset sph.AzIp to only needed fields
                                  colnames(sph.AzIp) <- c("TAZ", "County", "SWIMPOP", "AdjustPop", "SWIMEMP", "AdjustEmp")
                                                                                 
                                  #Create attraction level control using the user defined disaggregation method
                                  switch(disaggregateMethod,
                                        "SWIMPCT" = {sph.AzIp$Atr <- (sph.AzIp$AdjustEmp * 2 + sph.AzIp$AdjustPop) 
                                                     sph.AzIp$AtrFac <- sph.AzIp$Atr / (sph.AzIp$SWIMEMP * 2 + sph.AzIp$SWIMPOP)
                                                     Crosswalk$AtrFac <- Crosswalk$SWIMPCT / 100 },
                                        
                                        "LOCALPOPSHARE" = {sph.AzIp$Atr <- sph.AzIp$AdjustPop 
                                                           sph.AzIp$AtrFac <- sph.AzIp$AdjustPop / sph.AzIp$SWIMPOP 
                                                           xWlkDenom <- as.vector(tapply(Crosswalk$LOCALPOP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)])
                                                           Crosswalk$AtrFac <- Crosswalk$LOCALPOP / xWlkDenom },
                                       
                                        "LOCALEMPSHARE" = {sph.AzIp$Atr <- sph.AzIp$AdjustEmp 
                                                           sph.AzIp$AtrFac <- sph.AzIp$AdjustEmp / sph.AzIp$SWIMEMP 
                                                           xWlkDenom <- as.vector(tapply(Crosswalk$LOCALEMP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)])
                                                           Crosswalk$AtrFac <- Crosswalk$LOCALEMP / xWlkDenom },                                                                                              
                                        
                                        "LOCALPOP2EMPSHARE" = {sph.AzIp$Atr <- (sph.AzIp$AdjustEmp * 2 + sph.AzIp$AdjustPop) 
                                                               sph.AzIp$AtrFac <- sph.AzIp$Atr / (sph.AzIp$SWIMEMP * 2 + sph.AzIp$SWIMPOP)
                                                               xWlkDenom <- as.vector(tapply(Crosswalk$LOCALEMP * 2 + Crosswalk$LOCALPOP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)])
                                                               Crosswalk$AtrFac <- (Crosswalk$LOCALEMP * 2 + Crosswalk$LOCALPOP) /xWlkDenom }
                                      )                                               

                                  #Correct any nan's in the attraction factor
                                  sph.AzIp[is.nan(sph.AzIp$AtrFac),"AtrFac"] <- ifelse(sph.AzIp[is.nan(sph.AzIp$AtrFac),"Atr"] == 0, 0, 1)
                                  Crosswalk$AtrFac[is.nan(Crosswalk$AtrFac)] <- 0
                                      
                                  #Create the production factor which is always a population factor
                                  sph.AzIp$ProFac <- sph.AzIp$AdjustPop / sph.AzIp$SWIMPOP       
                                  sph.AzIp[is.nan(sph.AzIp$ProFac),"ProFac"] <- ifelse(sph.AzIp[is.nan(sph.AzIp$ProFac),"AdjustPop"] == 0, 0, 1)
                                  Crosswalk$ProFac <- Crosswalk$LOCALPOP / as.vector(tapply(Crosswalk$LOCALPOP, Crosswalk$SWIMZONE, sum)[as.character(Crosswalk$SWIMZONE)]) 
                                  Crosswalk$ProFac[is.nan(Crosswalk$ProFac)] <- 0
                                  rm(Pop.Az, Emp.Az)    
                              
                                  # write out the crosswalk for run analysis
                                  write.csv(Crosswalk, paste(storeLoc, "SWIM_TAZ_CW_Report.csv", sep=""), row.names=F)    
                                  write.csv(sph.AzIp, paste(storeLoc, "SWIM_TAZ_LUadj_Report.csv", sep=""), row.names=F)

                              
                                  #=================================================================================================
                                  # Prep, Add Weights, and Combine SWIM trip tables to be used with JEMnR, Create Auto Table
                                  #=================================================================================================
                                     
                                  #Create AutoAdd trip lists by auto classes, remove non-auto modes, factor by veh occupancy
                                  auto_modes_veh_occ = c("DA"=1,"SR2"=2,"SR3P"=3.3)
                                  ldtColIndx <- c("origin","destination","tripMode","tripStartTime","tourPurpose","FROM_TRIP_TYPE","tripPurpose","HOME_ZONE","EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT")
                                  ldt.. <- ldt..[,ldtColIndx]
                                  sdtColIndx <- c("origin","destination","tripMode","tripStartTime","tourPurpose","FROM_TRIP_TYPE","tripPurpose","HOME_ZONE","EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT")
                                  sdt..<- sdt..[,sdtColIndx]
                                  auto <- rbind(sdt..,ldt..)
                                  auto <- auto[auto$tripMode %in% names(auto_modes_veh_occ),]
                                  auto$Volume <- 1 / auto_modes_veh_occ[as.character(auto$tripMode)]
                                  rm(auto_modes_veh_occ)
                                       
                                  #=================================================================================================
                                  # Compute JEMnR trip purpose (based on From / To trip purposes) 
                                  #=================================================================================================
                                  
                                  #Add missing FROM_TRIP_TYPE based on tourPurpose     
                                  auto$FROM_TRIP_TYPE[auto$FROM_TRIP_TYPE == ""] <- auto$tourPurpose[auto$FROM_TRIP_TYPE == ""]  
                                       
                                  #Check if the trip is home-based (either FROM_TRIP_TYPE or tripPurpose purpose in home)
                                  auto$homebased <- 0
                                  auto$homebased[auto$FROM_TRIP_TYPE == "HOME" | auto$tripPurpose == "HOME"] <- 1
                                       
                                  #Code trip purpose
                                  auto$purpose <- ""
                                  auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="COLLEGE"     | auto$tripPurpose=="COLLEGE")]     <- "hbcoll"                                         #home-based college
                                  auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="RECREATE"    | auto$tripPurpose=="RECREATE")]    <- "hbr"                                            #home-based recreational
                                  auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="SHOP"        | auto$tripPurpose=="SHOP")]        <- "hbs"                                            #home-based shop  
                                  auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="GRADESCHOOL" | auto$tripPurpose=="GRADESCHOOL")] <- "hbsch"                                          #home-based school 
                                  auto$purpose[auto$homebased==1 & (auto$FROM_TRIP_TYPE =="OTHER"       | auto$tripPurpose=="OTHER")]       <- "hbo"                                            #home-based other                                  
                                  auto$purpose[auto$homebased==1 & (auto$tripPurpose=="WORK" | auto$tripPurpose=="WORK_BASED" | auto$tripPurpose=="WORKRELATED" |
                                                                    auto$FROM_TRIP_TYPE=="WORK" | auto$FROM_TRIP_TYPE=="WORK_BASED" | auto$FROM_TRIP_TYPE=="WORKRELATED") ]  <- "hbw"           #home-based work     
                                  auto$purpose[auto$homebased==0]  <- "nhbnw"                                                                                                                   #nonhome-based other
                                  auto$purpose[auto$homebased==0 & (auto$tripPurpose=="WORK" | auto$tripPurpose=="WORK_BASED" | auto$tripPurpose=="WORKRELATED" |
                                                                    auto$FROM_TRIP_TYPE=="WORK" | auto$FROM_TRIP_TYPE=="WORK_BASED" | auto$FROM_TRIP_TYPE=="WORKRELATED")]   <- "nhbw"          #nonhome-based work
                              
                                  #Special code to crosswalk purposes to OSUM (if OSUM)
                                  if(exists("osumFun")){
                                        purpCW <- c("hbw",   "hbro","hbshp","hbsch","hbro","hbw","nhb",  "nhb", "")
                                        names(purpCW) <- c("hbcoll","hbr", "hbs",  "hbsch","hbo", "hbw","nhbnw","nhbw", "") 
                                        auto$purpose <- purpCW[auto$purpose]         
                                  }
                              
                                  #=================================================================================================
                                  # Create production level control 
                                  #=================================================================================================
                                  
                                  #Weight trip table by population of the home zone for personal auto trips
                                  auto$Pweight <- auto$Volume * sph.AzIp[as.character(auto$HOME_ZONE), "ProFac"] 
                                  ProdCont <- tapply(auto$Pweight, auto$HOME_ZONE, sum)
                              
                                  #Weight on attraction end
                                  auto$Aweight <- sph.AzIp[as.character(auto$destination), "AtrFac"]
                                  auto[is.na(auto$Aweight),"Aweight"] <- 1
                                       
                                  #Re-adjust productions
                                  auto$Weight <- auto$Pweight * auto$Aweight
                                  ProdCont <- ProdCont / tapply(auto$Weight, auto$HOME_ZONE, sum) 
                                  ProdCont[is.nan(ProdCont)] <- 0
                                  auto$Weight <- as.vector(auto$Weight * ProdCont[as.character(auto$HOME_ZONE)])
                                  rm(ProdCont)
                              
                                  #=================================================================================================
                                  #  Create data table  
                                  #=================================================================================================                                            
                                  
                                  #Add trip lists by truck classes
                                  ct.. <- ct..[,c("origin","destination","tripStartTime","HOME_ZONE","EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT")]
                                  ct..$Volume = 1
                                  et.. <- et..[,c("origin","destination","tripStartTime","HOME_ZONE","EXTERNAL_ZONE_ORIGIN","EXTERNAL_ZONE_DESTINATION","SELECT_LINK_PERCENT","truckVolume")]
                                  colnames(et..)[colnames(et..) == "truckVolume"] <- "Volume"
                                  truck <- rbind(ct..,et..)         
                                  #Add purpose to truck table
                                  truck$purpose <- "truck"
                                  #Remove trucks's home zone before combining with auto - trucks adjustment will always be based on attraction
                                  truck$HOME_ZONE <- 0
                                       
                                  #Add truck weights
                                  truck$Weight <- sph.AzIp[as.character(truck$destination), "AtrFac"]
                                  truck[is.na(truck$Weight),"Weight"] <- 1
                                       
                                  #Combine both auto and truck into complete "data" set
                                  data <- rbind(auto[,names(truck)], truck)
                                       
                                  #=================================================================================================
                                  #  Add time of day  
                                  #=================================================================================================  
                                  
                                  #Add time of day function  
                                  getTOD <- function(tripStartTime) {
                                              TODLst <- list()
                                              for(x in 1:nrow(TOD_periods)) {
                                                    indx1 <-  tripStartTime >= TOD_periods[x,"StartTime"]
                                                    indx2 <-  tripStartTime <= TOD_periods[x,"EndTime"] # 7-19-16 AB - changed "<" to "<=", which is correct based on the way the input file is defined.
                                                    curTOD  <-  rep("",length(tripStartTime))
                                                    curTOD[indx1&indx2] <-  rep(TOD_periods[x, "Period"],sum(indx1&indx2))
                                                    TODLst[[x]] <- curTOD
                                              }
                                              for(i in 1:(length(TODLst)-1)) TODLst[[i+1]] <- paste(TODLst[[i]],TODLst[[i+1]],sep=" ")             
                                              TODLst[[i+1]] <- gsub("^ +| +$","",TODLst[[i+1]]) 
                                              TOD <-gsub(" +","-",TODLst[[i+1]])  
                                              names(TOD) <- names(tripStartTime)
                                              return(TOD)
                                            }             
                                  
                                  #Cluster processing     
                                  options(warn=-1)
                                  cl <- makeCluster(7)
                                  registerDoParallel(cl)
                                  clusterExport(cl,c("TOD_periods"))
                                  tripStartTime <- data$tripStartTime
                                  names(tripStartTime) <- 1:nrow(data)
                                  splitDF <- split(data$tripStartTime,rep(1:7,each=ceiling(nrow(data)/7))[1:nrow(data)])    
                                  outLst <-  parLapply(cl,splitDF, getTOD) 
                                  names(outLst) <- NULL               
                                  outDF <- unlist(outLst)
                                  data$TOD <-  outDF 
                                  gc()
                                  options(warn=0)
                                
                                  #Create external tags
                                  data$ext <- "II"
                                  data[(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_ORIGIN"])) & !(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_DESTINATION"])),"ext"] <- "EI"
                                  data[!(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_ORIGIN"])) & (1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_DESTINATION"])),"ext"]  <- "IE"
                                  data[(1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_ORIGIN"])) & (1:nrow(data) %in% grep("_", data[,"EXTERNAL_ZONE_DESTINATION"])),"ext"]  <- "EE"
                                  rm(auto, truck, sdt.., ldt.., ct.., et..)
                                  
                                  #=================================================================================================
                                  #  create a blank matrix for OD output (only on first data set) 
                                  #=================================================================================================                                    
                                       
                                  if(d==1){  
                                        extPurposes <- sort(unique(data$purpose))  #Create purpose list                     
                                        #Create the "zoneNames" object
                                        if(exists("osumFun")){
                                              zoneNames <- sort(c(as.numeric(row.names(ext.traffic)), taz.data$taz))
                                              internalZones <- sort(as.character(taz.data$taz))
                                        } else {   
                                              zoneNames <- sort(c(unique(externals$station),taz$TAZ)) #add externals
                                              internalZones <- sort(as.character(taz$TAZ))
                                        }
                                        #Creating a blank matrices with all zone-to-zone, time-of-day, and mode (auto / truck) information
                                        ext.ZnZnTdMd <- array(0, dim=c(length(zoneNames), length(zoneNames), nrow(TOD_periods), length(extPurposes)),dimnames=list(zoneNames, zoneNames, TOD_periods$Period, extPurposes)) 
                                  }
                                     
                                  #=================================================================================================
                                  # Add link percent check (if there are multiple paths to OD, they all must sum to 100%)
                                  #=================================================================================================  
                    
                                  data$od <- paste(data$origin,data$destination,sep="-")
                                     
                                  #=================================================================================================
                                  # Fill JEMnR external array with disaggregated SWIM trip information
                                  #=================================================================================================                                                   
                          
                                  #Create a list of SWIM zones in the local area model
                                  LocalZones <- unique(Crosswalk$SWIMZONE)
                                  Vol <- tapply(data$Weight, paste(data$EXTERNAL_ZONE_ORIGIN, data$EXTERNAL_ZONE_DESTINATION, data$HOME_ZONE, data$purpose, data$TOD, data$ext), sum)
                                  rm(data)

                                  #Function To Fill Array
                                  getVol <- function(curVol) {
                                              curExt.ZnZnTdMd <- ext.ZnZnTdMd
                                              for(i in 1:length(curVol)){
                                                    #Pull Adjusted vehicle volume
                                                    v <- curVol[i] 
                                                    #Origin zone
                                                    oz <- unlist(strsplit(names(curVol)[i], " "))[1]
                                                    #Destination Zone
                                                    dz <- unlist(strsplit(names(curVol)[i], " "))[2]
                                                    #Is Local Zone check for proper Factor - either attraction or production
                                                    f <- ifelse(unlist(strsplit(names(curVol)[i], " "))[3] %in% LocalZones, "ProFac", "AtrFac")
                                                    #Purpose
                                                    p <- unlist(strsplit(names(curVol)[i], " "))[4]
                                                    #Time-of-Day Periods
                                                    tods <- unlist(strsplit(unlist(strsplit(names(curVol)[i], " "))[5], "-"))
                                                    #External tag
                                                    xx <- unlist(strsplit(names(curVol)[i], " "))[6]
                                                    #Create vectors of local zones
                                                    oZns <- as.character(Crosswalk[as.character(Crosswalk$SWIMZONE) == oz,"LOCALZONE"])
                                                    dZns <- as.character(Crosswalk[as.character(Crosswalk$SWIMZONE) == dz,"LOCALZONE"])  
                                                    
                                                    switch(xx,
                                                          #Case for EE flows
                                                          "EE" =  curExt.ZnZnTdMd[gsub("_", "", oz), gsub("_", "", dz),tods,p] <- v + curExt.ZnZnTdMd[gsub("_", "", oz), gsub("_", "", dz),tods,p],   
                                                          #Case for EI flows
                                                          "EI" = curExt.ZnZnTdMd[gsub("_", "", oz),dZns,tods,p] <- (v * Crosswalk[Crosswalk$SWIMZONE == as.numeric(dz),f]) + curExt.ZnZnTdMd[gsub("_", "", oz),dZns,tods,p],
                                                          #Case for IE flows
                                                          "IE" = curExt.ZnZnTdMd[oZns, gsub("_", "", dz),tods,p] <- (v * Crosswalk[Crosswalk$SWIMZONE == as.numeric(oz),f]) + curExt.ZnZnTdMd[oZns,gsub("_", "", dz),tods,p],
                                                          #Case for II flows
                                                          "II" =  curExt.ZnZnTdMd[oZns,dZns,tods,p] <- as.vector(v * outer(Crosswalk[Crosswalk$SWIMZONE == as.numeric(oz),f], Crosswalk[Crosswalk$SWIMZONE == as.numeric(dz),f])) + curExt.ZnZnTdMd[oZns,dZns,tods,p]                                                        
                                                     )
                                                     
                                              }
                                              rm(v, oz, dz, f, p, tods, xx, oZns, dZns)
                                              gc()
                                              return(curExt.ZnZnTdMd)   
                                            }
                          
                                  #Break up loop and send to seven clusters
                                  e1 <- new.env(parent = parent.frame())  # this one has enclosure package:base.
                                  sapply(c("ext.ZnZnTdMd","LocalZones","Crosswalk"),function(x)assign(x, get(x), envir = e1))
                                  clusterExport(cl,c("ext.ZnZnTdMd","LocalZones","Crosswalk"),envir=e1)           
                                  
                                  #Work through each record to disaggrate to JEMnR zones
                                  splitDF <- split(Vol,rep(1:7,length(Vol))[1:length(Vol)])   
                                  matLst <- parLapply(cl,splitDF,getVol)
                                  for(x in 1:(length(matLst)-1)) matLst[[x +1]] <- matLst[[x]] + matLst[[x +1]]
                                  ext.ZnZnTdMd <- matLst[[x +1]] + ext.ZnZnTdMd  
                                      
                            } 
                            
                            ########### END LOOP FOR MULTIPLE DATA SETS ##################################
      
                            stopCluster(cl)
                            rm(cl)
                            gc()  
                              
                            #Averages multiple external PA matrices and writes output
                            ext.ZnZnTdMd <- ext.ZnZnTdMd/length(datasets)
                            save(ext.ZnZnTdMd, file=paste(storeLoc, "externalOD_ZnZnTdMd.RData", sep=""))
                          
                            ########### OSUM REQUIRED STEP ###############################################

                            #First pull SWIM auto and truck volumes for comparison
                            SWIMauto <- apply(ext.ZnZnTdMd[,,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],1,sum) + apply(ext.ZnZnTdMd[,,"daily",!(dimnames(ext.ZnZnTdMd)[[4]] %in% "truck")],2,sum)
                            externals$SWIMauto <- round(SWIMauto[as.character(externals[,"station"])]/2)
                            SWIMtruck <- apply(ext.ZnZnTdMd[,,"daily","truck"],1,sum) + apply(ext.ZnZnTdMd[,,"daily","truck"],2,sum)
                            externals$SWIMtruck <- round(SWIMtruck[as.character(externals[,"station"])]/2) 
                            #Create SWIM truck percentage
                            externals$SWIMtrkPct <- externals$SWIMtruck/(externals$SWIMtruck+externals$SWIMauto)   
                                
                            #For external stations without volume information (coded with NA), use SWIM truck percentages  
                            if(any(is.na(externals$TruckAWDT))) externals[is.na(externals$TruckAWDT),c("AutoAWDT", "TruckAWDT")] <- cbind(externals[is.na(externals$TruckAWDT),"AutoAWDT"] * (1-externals$SWIMtrkPct[is.na(externals$TruckAWDT)]), externals[is.na(externals$TruckAWDT),"AutoAWDT"] * externals$SWIMtrkPct[is.na(externals$TruckAWDT)])
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
  
                            if(exists("runUniversityModel")){
                               if(runUniversityModel) taz  <- tempTaz
                            }
                            return(out)
                          }
    
    ############################ IPF FUNCTION FOR EXTERNAL MATRICES #####################################

    fun$extIPF <- function(rowcontrol, colcontrol, fullMat, extSta, period, maxiter=100, closure=0.0001){
                    #input data checks: sum of marginal totals equal and no zeros in marginal totals
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
                 
                    #Set initial values
                    result <- fullMat
                    ee <- fullMat[extSta, extSta]
                    ei <- fullMat[extSta, !(colnames(fullMat) %in% extSta)]
                    ie <- fullMat[!(colnames(fullMat) %in% extSta), extSta]
                    rowcheck <- 1
                    colcheck <- 1
                    iter <- 0
                   
                    #Successively proportion rows and columns until closure or iteration criteria are met
                    while(((rowcheck > closure) | (colcheck > closure)) & (iter < maxiter)){
        	               
                         #Row Adjustments
                          rowtotal <- rowSums(cbind(ee,ei))
            	            rowfactor <- rowcontrol/rowtotal
            	            rowfactor[is.infinite(rowfactor)] <- 1
            	            ee <- sweep(ee, 1, rowfactor, "*")
            	            ei <- sweep(ei, 1, rowfactor, "*")
            	            
            	            #Column Adjustments
            	            coltotal <- colSums(rbind(ee,ie))
            	            colfactor <- colcontrol/coltotal
            	            colfactor[is.infinite(colfactor)] <- 1
            	            ee <- sweep(ee, 2, colfactor, "*")
            	            ie <- sweep(ie, 2, colfactor, "*")
            	            
                          rowcheck <- sum(abs(1-rowfactor))
            	            colcheck <- sum(abs(1-colfactor))
            	            iter <- iter + 1
                    }
                    if(iter == maxiter) cat(paste( "\nThe maximum (", iter, ") number of iterations was reached the externalModel ipf did NOT close for period=", period,"\nSum of abs of Row Differences to Row Controls = ",rowcheck,"\nSum of abs of Col Differences to Col Controls = ", colcheck, "\nClosure Criteria = ", closure, "\n\n",sep=""))  # AB 1-23-19, corrected Clouser , 3-13-19 - corrected again, had changed it Closuer, third times the charm

                    #Repack the EE, EI, and IE into the full matrix
                    result[extSta, extSta] <- ee
                    result[extSta, !(colnames(result) %in% extSta)] <- ei
                    result[!(colnames(result) %in% extSta), extSta] <- ie
                    return(result)
                  }
    
    #IPF external matrices (auto and truck) to counts
    fun$ipfExtMatsToCounts <- function(IPF,storeLoc) {
                  
                  	             #get OD array 
                                load(paste(storeLoc, "externalOD_ZnZnTdMd.RData", sep=""))
                               
                                #Create the truck and auto AWDTs to be used
                                
                                #Adjust volumes to analysis year
                                # only run from JEMnR, in OSUM this is handeled externally to address special generators
                                if(!exists("osumFun")){
                                   externals$daily_auto <- externals$AutoAWDT * (1 + (externals$GrowthRate*(year  - externals$AWDT_YEAR)))
                                   externals$daily_truck <- externals$TruckAWDT * (1 + (externals$GrowthRate*(year  - externals$AWDT_YEAR)))
                                }
                                 
                                #write out edited externals table for external model diagonistics
                                write.csv(externals, paste(storeLoc, "selectLinks_Report.csv", sep=""), row.names=F)
                                
                                #save externals names to remove temp fields
                                extNames <- names(externals)
                               
                                #create period volume controls
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
                                             #check to ensure that the seed has enough information for the period - if not, use daily
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
                              	
                              	# 9-19-19 AB - adding extra error checking if have nan
                              	# Totals are assumed to match well enough if they make it through the ipf process without error - however NAN is a seperate issue
                             	  emptyHours <- dimnames(ext.ZnZnTdMd)[[3]][is.nan(apply(ext.ZnZnTdMd,3,sum))]                              	                              	
                              	if(length(emptyHours) > 0){
                              	   cat(paste("\nThe following hours have zero SWIM demand to base patterns off of:\n", paste(emptyHours, collapse="\n"),"\n",sep=""))
                              	   cat(paste("\nA total coded demand of,",round(sum((externals$daily_truck+externals$daily_auto)  *t(externals[,emptyHours]))),"vehicles was coded for those hours but is now zero\nsince SWIM has no demand to base trends off of.\n"))
                                   ext.ZnZnTdMd[is.nan(ext.ZnZnTdMd)] <-0
                              	}
                              	
                              	# export the external information being used in the run 
                              	save(ext.ZnZnTdMd, file=paste(storeLoc, "externalOD_ZnZnTdMd.RData", sep=""))
                              	
                              	if(exists("omxScriptName")){
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
	                              }}
                                
                                }
    }
       
############################################################################## END ##############################################################################################################################
