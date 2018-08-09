#Oregon Commercial Vehicle 3-Step Model
#Yegor Malinovskiy, malinovskiyy@pbworld.com
#Ben Stabler, stabler@pbworld.com 9/23/2013
#Ben Stabler, ben.stabler@rsginc.com, 06/30/15
#
#Modified:
# Binny M Paul       binny.mathewpaul@rsginc.com 07-15 - 2018 - read TOD calibration factors from CSV input and apply for each TOD

###############################################
#################USER MANAGED##################
###############################################

library(omxr) #OMX matrices

###################INPUTS######################

##Maximum # of iterations in trip balancing
balance_iter <- 5

##File names
#TAZ data (employment)
tazFileName <- "inputs/maz_data_export.csv"

#Productions
nonWorkProductionFileName <- "config/cvm/nonWorkProd_IntraTrips.csv"
workProductionFileName <- "config/cvm/workProd_IntraTrips.csv"

#Attractions
nonWorkAttractionFileName <- "config/cvm/nonWorkAttr.csv"
workAttractionFileName <- "config/cvm/workAttr.csv"

#Friction factor
nonWorkFrictionFileName <- "config/cvm/nonWorkFriction.csv"
workFrictionFileName <- "config/cvm/workFriction.csv"

#In vehicle time skim
skimFileName <- "outputs/skims/taz_skim_sov_pm.omx"
timeSkimNum <- 2

#Time of day filenames
carTODFileName <- "config/cvm/TOD_Car.csv"
suTODFileName <- "config/cvm/TOD_SUTruck.csv"
muTODFileName <- "config/cvm/TOD_MUTruck.csv"

TOD_periodsFileName  <- "config/cvm/TOD_Periods.csv"

TOD_calFacFileName  <- "config/cvm/TOD_CalibrationFactors.csv"

###################OUTPUTS######################

##Outputs Directory
#Matrix output filename prefixes (suffixes by TOD period added later)
carOut <- "outputs/other/CAR"
suOut <- "outputs/other/SU"
muOut <- "outputs/other/MU"

omxFileName = "outputs/trips/cvmTrips.omx"

###############################################
##################MAIN SCRIPT##################
###############################################


####################SETUP#######################
#TAZ inputs (employment by type)
#convert CT-RAMP employment categories to CVM/JEMnR employment categories
mazData <- read.csv(tazFileName, header = TRUE)
tazData = data.frame(TAZ=as.vector(tapply(mazData$TAZ,mazData$TAZ,unique)))
tazData$AFREMP = as.vector(tapply(mazData$EMP_AGR,mazData$TAZ,sum))
tazData$CONEMP = as.vector(tapply(mazData$EMP_CONSTR,mazData$TAZ,sum))
tazData$FINEMP = as.vector(tapply(mazData$EMP_FINANC + mazData$EMP_REALES + mazData$EMP_MGMT,mazData$TAZ,sum))
tazData$GVTEMP = as.vector(tapply(mazData$EMP_PUBADM,mazData$TAZ,sum))
tazData$MFGEMP = as.vector(tapply(mazData$EMP_FOOD + mazData$EMP_WOOD + mazData$EMP_METAL,mazData$TAZ,sum))
tazData$MINEMP = as.vector(tapply(mazData$EMP_MIN,mazData$TAZ,sum))
tazData$RETEMP = as.vector(tapply(mazData$EMP_RETAIL + mazData$EMP_SPORT ,mazData$TAZ,sum))
tazData$SVCEMP = as.vector(tapply(mazData$EMP_ACCFD + mazData$EMP_INFO + mazData$EMP_PROF + 
  mazData$EMP_ADMIN + mazData$EMP_EDUC + mazData$EMP_HEALTH + mazData$EMP_ARTS + 
  mazData$EMP_OTHER,mazData$TAZ,sum))
tazData$TCPEMP = as.vector(tapply(mazData$EMP_UTIL + mazData$EMP_POSTAL,mazData$TAZ,sum))
tazData$WSTEMP = as.vector(tapply(mazData$EMP_WHOLE,mazData$TAZ,sum))
tazData = tazData[order(tazData$TAZ),]

#add externals
tazsWithExternals = read_lookup(skimFileName, "NO")$Lookup
externalTazs = tazsWithExternals[!(tazsWithExternals %in% tazData$TAZ)] 
externalsData = as.data.frame(matrix(0, length(externalTazs), ncol(tazData)))
colnames(externalsData) = colnames(tazData)
externalsData$TAZ = externalTazs
tazData = rbind(externalsData, tazData)
rm(tazsWithExternals, externalTazs, externalsData)

#Productions inputs
nwkProd <- read.csv(nonWorkProductionFileName, header = TRUE, row.names=1)
wkProd <- read.csv(workProductionFileName, header = TRUE, row.names=1)

#Attractions inputs
nwkAttr <- read.csv(nonWorkAttractionFileName, header = TRUE, row.names=1)
wkAttr <- read.csv(workAttractionFileName , header = TRUE, row.names=1)

#Friction factor inputs
nwkFriction <- read.csv(nonWorkFrictionFileName, header = TRUE, row.names=1)
wkFriction <- read.csv(workFrictionFileName, header = TRUE, row.names=1)

#Travel time skim inputs
ivTimepeakdriveAlone = read_omx(skimFileName, timeSkimNum)
rownames(ivTimepeakdriveAlone) = read_lookup(skimFileName, "NO")$Lookup
colnames(ivTimepeakdriveAlone) = read_lookup(skimFileName, "NO")$Lookup

#Time of day 
carTOD <- read.csv(carTODFileName, header = TRUE)
suTOD <- read.csv(suTODFileName, header = TRUE)
muTOD <- read.csv(muTODFileName, header = TRUE)

TOD_periods  <- read.csv(TOD_periodsFileName, header=T, as.is=T)
TOD_calFacs  <- read.csv(TOD_calFacFileName, header=T, as.is=T)

##TAZ limits (internal TAZs only)
allTAZs <- as.integer(unlist(dimnames(ivTimepeakdriveAlone)[1]))
minTAZ <- which(allTAZs == max( min(allTAZs), min(tazData$TAZ) ))
maxTAZ <- which(allTAZs == min( max(allTAZs), max(tazData$TAZ) ))



###############TRIP GENERATION##################

##FUNCTION TO CROSS MULTIPLY PRODUCTIONS OR ATTRACTIONS BY EMPLOYMENT
crossMult <- function(workMat, mode) {
	return(		tazData$AFREMP*(workMat["Agriculture, Forestry",mode]) +
				tazData$MINEMP*(workMat["Mining",mode]) +
				tazData$CONEMP*(workMat["Construction",mode]) +
				tazData$MFGEMP*(workMat["Manufacturing",mode]) + 
				tazData$TCPEMP*(workMat["Transportation, Communications, Public Utilities",mode]) +
				tazData$WSTEMP*(workMat["Wholesale",mode])+
				tazData$RETEMP*(workMat["Retail",mode])+
				tazData$FINEMP*(workMat["Financial",mode])+
				tazData$SVCEMP*(workMat["Service",mode])+
				tazData$GVTEMP*(workMat["Government",mode]))
}


##CAR MODE PRODUCTIONS/ATTRACTIONS
mode <- "Car"
tazData$ProdCar_Wk <- crossMult(wkProd, mode)
tazData$AttrCar_Wk <- crossMult(wkAttr, mode)

tazData$ProdCar_NWk <- crossMult(nwkProd, mode)
tazData$AttrCar_NWk <- crossMult(nwkAttr, mode)


##SINGLE UNIT TRUCK MODE PRODUCTIONS/ATTRACTIONS
mode <- "SU.Truck"
tazData$ProdSU_Wk <- crossMult(wkProd, mode)
tazData$AttrSU_Wk <- crossMult(wkAttr, mode)

tazData$ProdSU_NWk <- crossMult(nwkProd, mode)
tazData$AttrSU_NWk <- crossMult(nwkAttr, mode)


##MULTI UNIT TRUCK MODE PRODUCTIONS/ATTRACTIONS
mode <- "MU.Truck"
tazData$ProdMU_Wk <- crossMult(wkProd, mode)
tazData$AttrMU_Wk <- crossMult(wkAttr, mode)

tazData$ProdMU_NWk <- crossMult(nwkProd, mode)
tazData$AttrMU_NWk <- crossMult(nwkAttr, mode)


cat("Sum of Productions Work: ", sum(tazData$ProdMU_Wk + tazData$ProdSU_Wk + tazData$ProdCar_Wk))
cat("Sum of Productions Non-Work: ", sum(tazData$ProdMU_NWk + tazData$ProdSU_NWk + tazData$ProdCar_NWk))

###############TRIP DISTRIBUTION################

##FRICTION FACTORS
##FUNCTION TO GET FRICTION FACTOR MATRIX
getFrictionMat <- function(friMat, skim, mode) {
	r <- friMat["r",mode]
	s <- friMat["s",mode]
	b <- friMat["b",mode]
	q <- friMat["q",mode]
	return(exp((b*skim)+((r + s*skim)/(1+q*skim^2))))
}

##TRIP TABLES
##FUNCTION TO GET TRIP TABLE
getTripTable <- function(friMat, attr, prod, mode) {
	n <- length(attr)
	tempMat <- matrix(rep(NA, n^2), nrow=n, ncol=n)
	skim <- ivTimepeakdriveAlone[minTAZ:maxTAZ,minTAZ:maxTAZ]
	f <- getFrictionMat(friMat, skim, mode)
	norm <- colSums(t(f)*attr)
	tripMat <- prod*(t(attr*t(f))/norm)
	tripMat[is.nan(tripMat)] = 0 #Prevent NaNs
	return (tripMat)
}

##ROOT MEAN SQUARE ERROR
rmse<-function(v1,v2) {
	e <- v1-v2;
	sqrt(sum(e^2)/(length(e)))
}

##FUNCTION TO BALANCE TRIP TABLE ON ATTRACTIONS
balanceTrips <- function(trip_mat, friMat, attr, prod, mode, max_rmse=1e-5, max_iter=balance_iter) {
	new_rmse<-rmse(attr,colSums(trip_mat))
	iter=0
	while( new_rmse>max_rmse && iter<max_iter ) {
		adj_Attr <- attr/(colSums(trip_mat))
		adj_Attr[is.nan(adj_Attr)] = 0 #Prevent NaNs
		adj_Attr[is.infinite(adj_Attr)] = 0 #Prevent InFs
		if(iter == 0){next_iter_attr <- attr} else {next_iter_attr <- next_iter_attr*adj_Attr}
		trip_mat <- getTripTable(friMat, next_iter_attr, prod, mode)
		trip_mat[is.nan(trip_mat)] = 0 #Prevent NaNs
		new_rmse<-rmse(attr,colSums(trip_mat)) 
		iter<-iter+1
		cat("Iteration",iter,"RMSE:",new_rmse,"\n")
	}
	return(trip_mat)
}


mode <- "Car"
WORK_CAR_TRIPS <- balanceTrips(getTripTable(wkFriction, tazData$AttrCar_Wk, tazData$ProdCar_Wk, mode), wkFriction, tazData$AttrCar_Wk, tazData$ProdCar_Wk, mode)
NWORK_CAR_TRIPS <- balanceTrips(getTripTable(nwkFriction, tazData$AttrCar_NWk, tazData$ProdCar_NWk, mode), nwkFriction, tazData$AttrCar_NWk, tazData$ProdCar_NWk, mode)

mode <- "SU.Truck"
WORK_SU_TRIPS <- balanceTrips(getTripTable(wkFriction, tazData$AttrSU_Wk, tazData$ProdSU_Wk, mode), wkFriction, tazData$AttrSU_Wk, tazData$ProdSU_Wk, mode)
NWORK_SU_TRIPS <- balanceTrips(getTripTable(nwkFriction, tazData$AttrSU_NWk, tazData$ProdSU_NWk, mode), nwkFriction, tazData$AttrSU_NWk, tazData$ProdSU_NWk, mode)

mode <- "MU.Truck"
WORK_MU_TRIPS <- balanceTrips(getTripTable(wkFriction, tazData$AttrMU_Wk, tazData$ProdMU_Wk, mode), wkFriction, tazData$AttrMU_Wk, tazData$ProdMU_Wk, mode)
NWORK_MU_TRIPS <- balanceTrips(getTripTable(nwkFriction, tazData$AttrMU_NWk, tazData$ProdMU_NWk, mode), nwkFriction, tazData$AttrMU_NWk, tazData$ProdMU_NWk, mode)


cat("Sum of Matrix Work: ", sum(WORK_CAR_TRIPS + WORK_SU_TRIPS + WORK_MU_TRIPS))
cat("Sum of Matrix Non-Work: ", sum(NWORK_CAR_TRIPS + NWORK_SU_TRIPS + NWORK_MU_TRIPS))

##############TIME OF DAY CHOICE################

#Generate OD Matrix by multiplying by appropriate TOD factors
generateODMatrix <- function(tod, period, w_trips, nw_trips) {
	startTime <- as.integer(TOD_periods[TOD_periods["Period"] == period][2])
	endTime <- as.integer(TOD_periods[TOD_periods["Period"] == period][3])
 	return(	sum( tod$From.Work.to.Visit	[ tod$Time[!is.na(tod$Time)] >= startTime & tod$Time[!is.na(tod$Time)] < endTime ])*(w_trips) +
			sum( tod$From.Visit.to.Work	[ tod$Time[!is.na(tod$Time)] >= startTime & tod$Time[!is.na(tod$Time)] < endTime ])*t(w_trips) +
			sum( tod$Visit.to.Visit		[ tod$Time[!is.na(tod$Time)] >= startTime & tod$Time[!is.na(tod$Time)] < endTime ])*(nw_trips)+
			sum( tod$Visit.to.Visit		[ tod$Time[!is.na(tod$Time)] >= startTime & tod$Time[!is.na(tod$Time)] < endTime ])*t(nw_trips) )
}

#Periods used in TOD csv files
periods <- TOD_periods["Period"][,1]

#Write tables to folder
n <- sqrt(length(WORK_CAR_TRIPS))
dailycommercialvehicle <- matrix(rep(0, n^2), nrow=n, ncol=n)

create_omx(omxFileName, n, n)
write_lookup(omxFileName, rownames(WORK_CAR_TRIPS), "NO")

for(i in 1:length(periods))
{
	todCalFac <- TOD_calFacs$calfac[TOD_calFacs$Period==periods[i]]
	
  car <- generateODMatrix(carTOD, periods[i], WORK_CAR_TRIPS, NWORK_CAR_TRIPS)
	print(paste("Car trips ", periods[i], ": ", sum(car)))
	car <- car * todCalFac
	print(paste("Car trips with calibration factor ", periods[i], ": ", sum(car)))
	su <- generateODMatrix(suTOD, periods[i], WORK_SU_TRIPS, NWORK_SU_TRIPS)
	print(paste("Single-unit truck trips ", periods[i], ": ", sum(su)))
	su <- su * todCalFac
	print(paste("Car trips with calibration factor ", periods[i], ": ", sum(su)))
	mu <- generateODMatrix(muTOD, periods[i], WORK_MU_TRIPS, NWORK_MU_TRIPS)
	print(paste("Multi-unit truck trips ", periods[i], ": ", sum(mu)))
	mu <- mu * todCalFac
	print(paste("Car trips with calibration factor ", periods[i], ": ", sum(mu)))
	
	write.table(car, paste(carOut,"_",periods[i],".csv",sep = ""), sep=",", row.names=TRUE, col.names=NA)
	write.table(su, paste(suOut,"_",periods[i],".csv",sep = ""), sep=",", row.names=TRUE, col.names=NA)
	write.table(mu, paste(muOut,"_",periods[i],".csv",sep = ""), sep=",", row.names=TRUE, col.names=NA)
	
	write_omx(omxFileName, car, paste("car_",periods[i],sep = ""))
	write_omx(omxFileName, su, paste("su_",periods[i],sep = ""))
	write_omx(omxFileName, mu, paste("mu_",periods[i],sep = ""))
	
	dailycommercialvehicle <- dailycommercialvehicle + car + su + mu
}




