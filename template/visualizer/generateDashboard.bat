:: ############################################################################
:: # Batch file to generate CTRAMP HTML Visualizer
:: # binny.mathewpaul@rsginc.com, June 2017
:: # 1. User should specify the path to base and build summaries the specified 
:: #    directory should have all the files listed in 
:: #    /templates/summaryFilesNames.csv
:: # 2. User should also specify the name of the base and build scenario if the 
:: #    base/build scenario is specified as "OHAS", scenario names are replaced 
:: #    with appropriate Census sources names wherever applicable
:: ############################################################################
@ECHO off

:: User Inputs
:: ###########
SET PROJECT_DIR=%1
SET WORKING_DIR=%PROJECT_DIR%\visualizer

SET BASE_SUMMARY_DIR=%2
SET BUILD_SUMMARY_DIR=%3
SET BASE_SCENARIO_NAME=%4
SET BUILD_SCENARIO_NAME=%5
:: for survey base legend names are different [Yes/No]
:: assignment summaries are for all links
SET IS_BASE_SURVEY=%6
SET BASE_SAMPLE_RATE=%7
SET BUILD_SAMPLE_RATE=%8
SET MAX_ITER=%9

SET OUTPUT_HTML_NAME=SOABM_Dashboard

SET SHP_FILE_NAME=zones_zone.shp

:: Set up dependencies
:: ###################
SET R_SCRIPT=%PROJECT_DIR%..\dependencies\R-3.4.1\bin\Rscript
ECHO R_SCRIPT: %R_SCRIPT%

SET R_LIBRARY=%PROJECT_DIR%..\dependencies\R-3.4.1\library
ECHO R_LIBRARY: %R_SCRIPT%

SET RSTUDIO_PANDOC=%PROJECT_DIR%..\dependencies\Pandoc
ECHO RSTUDIO_PANDOC: %R_SCRIPT%

:: Parameters file
SET PARAMETERS_FILE=%WORKING_DIR%\runtime\parameters.csv

ECHO Key,Value > %PARAMETERS_FILE%
ECHO PROJECT_DIR,%PROJECT_DIR% >> %PARAMETERS_FILE%
ECHO WORKING_DIR,%WORKING_DIR% >> %PARAMETERS_FILE%
ECHO BASE_SUMMARY_DIR,%BASE_SUMMARY_DIR% >> %PARAMETERS_FILE%
ECHO BUILD_SUMMARY_DIR,%BUILD_SUMMARY_DIR% >> %PARAMETERS_FILE%
ECHO BASE_SCENARIO_NAME,%BASE_SCENARIO_NAME% >> %PARAMETERS_FILE%
ECHO BUILD_SCENARIO_NAME,%BUILD_SCENARIO_NAME% >> %PARAMETERS_FILE%
ECHO BASE_SAMPLE_RATE,%BASE_SAMPLE_RATE% >> %PARAMETERS_FILE%
ECHO BUILD_SAMPLE_RATE,%BUILD_SAMPLE_RATE% >> %PARAMETERS_FILE%
ECHO R_LIBRARY,%R_LIBRARY% >> %PARAMETERS_FILE%
ECHO OUTPUT_HTML_NAME,%OUTPUT_HTML_NAME% >> %PARAMETERS_FILE%
ECHO SHP_FILE_NAME,%SHP_FILE_NAME% >> %PARAMETERS_FILE%
ECHO IS_BASE_SURVEY,%IS_BASE_SURVEY% >> %PARAMETERS_FILE%
ECHO MAX_ITER,%MAX_ITER% >> %PARAMETERS_FILE%

:: Call the R Script to process ABM output
:: #######################################
ECHO %startTime%%Time%: Running R script to process ABM output...
%R_SCRIPT% %WORKING_DIR%\scripts\workersByMAZ.R %PARAMETERS_FILE%
%R_SCRIPT% %WORKING_DIR%\scripts\SummarizeABM.R %PARAMETERS_FILE%

:: Call the master R script
:: ########################
ECHO %startTime%%Time%: Running R script to generate visualizer...
%R_SCRIPT% %WORKING_DIR%\scripts\Master.R %PARAMETERS_FILE%
IF %ERRORLEVEL% EQU 11 (
   ECHO File missing error. Check error file in outputs.
   EXIT /b %errorlevel%
)
ECHO %startTime%%Time%: Dashboard creation complete...

