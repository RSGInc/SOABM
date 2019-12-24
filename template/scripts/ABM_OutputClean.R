# Alex Bettinardi
# 6-13-19

# Script to remove interim and duplicative files from the ABM run:

# clean all working version files under "networks"
file.remove(paste("outputs/networks/Highway_Assignment_Results_",c("ea","am","md","pm","ev"),".ver",sep=""))
file.remove(paste("outputs/networks/Transit_Assignment_Results_",apply(expand.grid(c("ea","am","md","pm","ev"),paste0("set",1:3)),1,paste,collapse="_"),".ver",sep=""))  
file.remove(paste("outputs/networks/",c("Bike_MAZ_Skim","Walk_MAZ_Skim","Highway_Skimming_Assignment","Transit_Skimming_Assignment","MAZ_Level_Processing"),"_Setup.ver",sep=""))

# clean and simplify "other" folder
file.remove(paste("outputs/other/",c("externalOD.omx",paste0(apply(expand.grid(c("CAR","SU"),c("AM","EA","EV1","EV2","MD","PM")),1,paste,collapse="_"),".csv")),sep=""))

# find the latest iteration
iters <- list.files(path="outputs/other/", pattern="householdData_")

# if statement protects this script if it is getting run the second time
if(length(iters)>0){
   Final <- max(as.numeric(substring(iters,15,15)))
   # rename and clean-up mid-step files
   for(f in c("indivTourData","indivTripData","jointTourData","jointTripData","wsLocResults")){
      file.copy(paste0("outputs/other/",f,"_",Final,".csv"),paste0("outputs/other/",f,".csv"))
      file.remove(list.files(path="outputs/other/", pattern=paste0(f,"_"),full.names=T))
   } # end file for loop
   
   # conduct cleaning for households
   hh <- read.csv("outputs/other/households.csv",as.is=T) 
   hhData <- read.csv(paste0("outputs/other/householdData_",Final,".csv"),as.is=T, row.names=1)
   hh <- cbind(hh,hhData[as.character(hh$hhid),])
   file.remove(list.files(path="outputs/other/", pattern="householdData_",full.names=T))
   write.csv(hh,"outputs/other/households.csv",row.names=F)
   
   # conduct cleaning for persons
   per <- read.csv("outputs/other/persons.csv",as.is=T) 
   perData <- read.csv(paste0("outputs/other/personData_",Final,".csv"),as.is=T)
   rownames(perData) <- perData$person_id
   per <- cbind(per,perData[as.character(per$PERID),])
   file.remove(list.files(path="outputs/other/", pattern="personData_",full.names=T))
   write.csv(per,"outputs/other/persons.csv",row.names=F)
     
   rm(Final,f,hh,hhData,per,perData)
   
   } # end iters if statement
rm(iters)