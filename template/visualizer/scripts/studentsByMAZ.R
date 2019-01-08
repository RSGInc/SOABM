##################################################################
### Script to summarize students by MAZ and Grade level attending
###
### MAZ level enrollment is read from the MAZ data file
### NUmber of students by MAZ are summarized from the school location choice model output
##################################################################

### Read Command Line Arguments
args                <- commandArgs(trailingOnly = TRUE)
Parameters_File     <- args[1]
#Parameters_File     <- "E:/projects/clients/odot/SouthernOregonABM/Contingency/SOABM/template/visualizer/runtime/parameters.csv"

SYSTEM_REPORT_PKGS <- c("reshape", "dplyr", "ggplot2", "plotly")
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
OutputDir     <- file.path(WORKING_DIR, "data/JPEG")
OutputCSVDir  <- file.path(PROJECT_DIR, "outputs/other/ABM_Summaries")


# read data
per     <- read.csv(paste(ABMOutputDir, paste("personData_",MAX_ITER, ".csv", sep = ""), sep = "/"), as.is = T)
wsLoc   <- read.csv(paste(ABMOutputDir, paste("wsLocResults_",MAX_ITER, ".csv", sep = ""), sep = "/"), as.is = T)
mazData <- read.csv(paste(ABMInputDir, "maz_data_export.csv", sep = "/"), as.is = T)

student_types <- c("Grade_K_8", "Grade_9_12", "University", "Total")


### Functions
lm_eqn <- function(df){
  m <- lm(y ~ x, df)
  eq <- paste("Y = ", format(coef(m)[2], digits = 3), " * X + ", format(coef(m)[1], digits = 3), ",  ", "r2=", format(summary(m)$r.squared, digits = 3), sep = "")
  return(eq)
}

createScatter <- function(df, stud){
  df <- df[df$studCat==stud,]
  colnames(df) <- c("CountLocation", "STUD_TYPE", "y", "x")
  
  #remove rows where both x and y are zeros
  df <- df[!(df$x==0 & df$y==0),]
  
  x_pos <- round(max(df$x)*0.25)
  x_pos1 <- round(max(df$x)*0.75)
  y_pos <- round(max(df$y)*0.80)
  
  p2 <- ggplot(df, aes(x=x, y=y)) + 
    geom_point(shape=1, color = "#0072B2") + 
    geom_smooth(method=lm, formula = y ~ x, se=FALSE, color = "#0072B2") + 
    geom_abline(intercept = 0, slope = 1, linetype = 2) + 
    geom_text(x = x_pos, y = y_pos,label = as.character(lm_eqn(df)) ,  parse = FALSE, color = "#0072B2", size = 6) + 
    geom_text(x = x_pos1, y = 0,label = "- - - - : 45 Deg Line",  parse = FALSE, color = "black") + 
    labs(x=paste("Enrollments", stud, sep = "-"), y=paste("Students", stud, sep = "-"))
  
  ggsave(file=paste(OutputDir, paste("Students_Enrollments_", stud, ".PNG", sep = ""), sep = "/"), width=12,height=10, device = "png", dpi = 200)
}

# students by grade [K-8, 9-12, Univ], preschoolers not included
# remove non-students and home-schooled
studentsByMAZ <- wsLoc[wsLoc$StudentCategory != 3 & !(wsLoc$SchoolSegment %in% c(88888)) & wsLoc$PersonType != 8, ] 

studentsByMAZ <- studentsByMAZ %>%
  mutate(weight = 1/BUILD_SAMPLE_RATE) %>%
  mutate(studCat = ifelse((StudentCategory==1) & (SchoolSegment<=8), 1, 0)) %>%                              # K-8
  mutate(studCat = ifelse((StudentCategory==1) & (SchoolSegment>8) & (SchoolSegment<=16), 2, studCat)) %>%   # 9-12
  mutate(studCat = ifelse((StudentCategory==2), 3, studCat)) %>%                                             # Univ
  group_by(SchoolLocation, studCat) %>%
  mutate(num_students = sum(weight)) %>%
  select(SchoolLocation, studCat, num_students) %>%
  ungroup()

ABM_Summary <- cast(studentsByMAZ, SchoolLocation~studCat, value = "num_students", fun.aggregate = max)
ABM_Summary$`1`[is.infinite(ABM_Summary$`1`)] <- 0
ABM_Summary$`2`[is.infinite(ABM_Summary$`2`)] <- 0
ABM_Summary$`3`[is.infinite(ABM_Summary$`3`)] <- 0  

colnames(ABM_Summary) <- c("MAZ", "Grade_K_8", "Grade_9_12", "University")


# compute enrollments by student categories
mazData <- mazData %>%
  mutate(ENROLLUNIV = ENROLLCOLL + ENROLLCOOT + ENROLLADSC)

### Prepare final DF in right format
df1 <- mazData[,c("MAZ", "NO")] %>%
  left_join(ABM_Summary, by = c("MAZ"="MAZ")) %>%
  select(-NO)

df1[is.na(df1)] <- 0
df1$Total <- rowSums(df1[,!colnames(df1) %in% c("MAZ")])
df1[is.na(df1)] <- 0
df1 <- melt(df1, id = c("MAZ"))
colnames(df1) <- c("MAZ", "studCat", "value")

df2 <- mazData[,c("MAZ","ENROLLK_8", "ENROLL9_12", "ENROLLUNIV")]
df2 <- df2 %>%
  rename(Grade_K_8 = ENROLLK_8) %>%
  rename(Grade_9_12 = ENROLL9_12) %>%
  rename(University = ENROLLUNIV)

df2[is.na(df2)] <- 0
df2$Total <- rowSums(df2[,!colnames(df2) %in% c("MAZ")])
df2[is.na(df2)] <- 0
df2 <- melt(df2, id = c("MAZ"))
colnames(df2) <- c("MAZ", "studCat", "value")

df <- cbind(df1, df2$value)
colnames(df) <- c("MAZ", "studCat", "Students", "Enrollments")

### Create scatter plots
for(stud in student_types){
  cat(stud, "\n")
  createScatter(df, stud)
}

#### Write outputs
write.csv(df, paste(OutputCSVDir, "enrollment_students_Summary.csv", sep = "/"), row.names = F)












# finish