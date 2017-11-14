##########################################################
### Script to summarize workers by MAZ and Occupation Type

### Read Command Line Arguments
args                <- commandArgs(trailingOnly = TRUE)
Parameters_File     <- args[1]

SYSTEM_REPORT_PKGS <- c("reshape", "dplyr")
lib_sink <- suppressWarnings(suppressMessages(lapply(SYSTEM_REPORT_PKGS, library, character.only = TRUE))) 

### Read parameters from Parameters_File
parameters          <- read.csv(Parameters_File, header = TRUE)
PROJECT_DIR         <- trimws(paste(parameters$Value[parameters$Key=="PROJECT_DIR"]))	
WORKING_DIR         <- trimws(paste(parameters$Value[parameters$Key=="WORKING_DIR"]))
MAX_ITER            <- trimws(paste(parameters$Value[parameters$Key=="MAX_ITER"]))
BUILD_SAMPLE_RATE   <- as.numeric(trimws(paste(parameters$Value[parameters$Key=="BUILD_SAMPLE_RATE"])))

ABMOutputDir  <- file.path(PROJECT_DIR, "outputs/other")
ABMInputDir   <- file.path(PROJECT_DIR, "inputs")
factorDir     <- file.path(WORKING_DIR, "data")
OutputDir     <- file.path(ABMOutputDir, "ABM_Summaries")

# read data
per     <- read.csv(paste(ABMOutputDir, paste("personData_",MAX_ITER, ".csv", sep = ""), sep = "/"), as.is = T)
wsLoc   <- read.csv(paste(ABMOutputDir, paste("wsLocResults_",MAX_ITER, ".csv", sep = ""), sep = "/"), as.is = T)
mazData <- read.csv(paste(ABMInputDir, "maz_data_export.csv", sep = "/"), as.is = T)
occFac  <- read.csv(paste(factorDir, "occFactors.csv", sep = "/"), as.is = T)

# workers by occupation type
workersbyMAZ <- wsLoc[wsLoc$PersonType<=3 & wsLoc$WorkLocation>0 & wsLoc$WorkSegment %in% c(0,1,2,3,4,5),] %>%
  mutate(weight = 1/BUILD_SAMPLE_RATE) %>%
  group_by(WorkLocation, WorkSegment) %>%
  mutate(num_workers = sum(weight)) %>%
  select(WorkLocation, WorkSegment, num_workers)

ABM_Summary <- cast(workersbyMAZ, WorkLocation~WorkSegment, value = "num_workers", fun.aggregate = max)
ABM_Summary$`0`[is.infinite(ABM_Summary$`0`)] <- 0
ABM_Summary$`1`[is.infinite(ABM_Summary$`1`)] <- 0
ABM_Summary$`2`[is.infinite(ABM_Summary$`2`)] <- 0
ABM_Summary$`3`[is.infinite(ABM_Summary$`3`)] <- 0
ABM_Summary$`4`[is.infinite(ABM_Summary$`4`)] <- 0
ABM_Summary$`5`[is.infinite(ABM_Summary$`5`)] <- 0

colnames(ABM_Summary) <- c("MAZ", "occ1", "occ2", "occ3", "occ4", "occ5", "occ6")


# compute jobs by occupation type
empCat <- colnames(occFac)[colnames(occFac)!="emp_code"]

mazData$occ1 <- 0
mazData$occ2 <- 0
mazData$occ3 <- 0
mazData$occ4 <- 0
mazData$occ5 <- 0
mazData$occ6 <- 0

for(cat in empCat){
  mazData$occ1 <- mazData$occ1 + mazData[,c(cat)]*occFac[1,c(cat)]
  mazData$occ2 <- mazData$occ2 + mazData[,c(cat)]*occFac[2,c(cat)]
  mazData$occ3 <- mazData$occ3 + mazData[,c(cat)]*occFac[3,c(cat)]
  mazData$occ4 <- mazData$occ4 + mazData[,c(cat)]*occFac[4,c(cat)]
  mazData$occ5 <- mazData$occ5 + mazData[,c(cat)]*occFac[5,c(cat)]
  mazData$occ6 <- mazData$occ6 + mazData[,c(cat)]*occFac[6,c(cat)]
}

### get df in right format before outputting
df1 <- mazData[,c("MAZ", "NO")] %>%
  left_join(ABM_Summary, by = c("MAZ"="MAZ")) %>%
  select(-NO)

df1[is.na(df1)] <- 0
df1$Total <- rowSums(df1[,!colnames(df1) %in% c("MAZ")])
df1[is.na(df1)] <- 0
df1 <- melt(df1, id = c("MAZ"))
colnames(df1) <- c("MAZ", "occp", "value")

df2 <- mazData[,c("MAZ","occ1", "occ2", "occ3", "occ4", "occ5", "occ6")]
df2[is.na(df2)] <- 0
df2$Total <- rowSums(df2[,!colnames(df2) %in% c("MAZ")])
df2[is.na(df2)] <- 0
df2 <- melt(df2, id = c("MAZ"))
colnames(df2) <- c("MAZ", "occp", "value")

df <- cbind(df1, df2$value)
colnames(df) <- c("MAZ", "occp", "jobs", "workers")


### Write outputs
write.csv(df, paste(OutputDir, "job_worker_summary.csv", sep = "/"), row.names = F)












# finish