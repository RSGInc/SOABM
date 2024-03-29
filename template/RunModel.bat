
::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
:: Run the complete Master_Runner travel model
:: Ben Stabler, ben.stabler@rsginc.com, 081215
:: Revised 05/22/17 ben.stabler@rsginc.com, 09/30/20 bmp, br
::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:: setup iteration sample rate
SET MAX_ITER=5
SET SAMPLERATE_ITERATION1=0.10
SET SAMPLERATE_ITERATION2=0.20
SET SAMPLERATE_ITERATION3=0.40
SET SAMPLERATE_ITERATION4=0.70
SET SAMPLERATE_ITERATION5=1.0

:: -------------------------------------------------------------------------------------------------
:: Setup folders, IP addresses, file references, etc.
:: -------------------------------------------------------------------------------------------------

@ECHO OFF

:: get ip address of machine
SET PATH=C:\Windows\System32
FOR /f "delims=[] tokens=2" %%a IN ('ping -4 -n 1 %ComputerName% ^| findstr [') DO SET HOST_IP_ADDRESS=%%a
ECHO HOST_IP_ADDRESS: %HOST_IP_ADDRESS%

:: setup dependencies, which are one folder up so they can be shared across scenarios
SET JAVA_PATH=%~dp0..\dependencies\jdk1.8.0_111
ECHO JAVA_PATH: %JAVA_PATH%

SET PYTHON=%~dp0..\dependencies\Python37\python.exe
ECHO PYTHON: %PYTHON%

SET R_SCRIPT=%~dp0..\dependencies\R-3.4.1\bin\Rscript
ECHO R_SCRIPT: %R_SCRIPT%

SET R_LIBRARY=%~dp0..\dependencies\R-3.4.1\library
ECHO R_LIBRARY: %R_SCRIPT%

SET RSTUDIO_PANDOC=%~dp0..\dependencies\Pandoc
ECHO RSTUDIO_PANDOC: %R_SCRIPT%

:: setup folders
SET PROJECT_DRIVE=%~d0
ECHO PROJECT_DRIVE: %PROJECT_DRIVE%

SET PROJECT_DIRECTORY=%~dp0
ECHO PROJECT_DIRECTORY: %PROJECT_DIRECTORY%

SET PROJECT_DIRECTORY_FORWARD=%PROJECT_DIRECTORY:\=/%
ECHO PROJECT_DIRECTORY_FORWARD: %PROJECT_DIRECTORY_FORWARD%

:: Copy the ODOT VDF DLLs to the local VISUM DLL folder
SET VDF_BMP=%~dp0\application
ECHO VDF_BMP: %VDF_BMP%

SET VDF_DLL=%~dp0\application
ECHO VDF_DLL: %VDF_DLL%

COPY %VDF_BMP%\VisumVDF_ODOTVDFx64.bmp "%AppData%\PTV Vision\PTV Visum 2023\UserVDF-DLLs"
COPY %VDF_DLL%\VisumVDF_ODOTVDFx64.dll "%AppData%\PTV Vision\PTV Visum 2023\UserVDF-DLLs"

:: empty outputs folder
ECHO empty outputs folder
DEL outputs\*.* /S /Q

:: -------------------------------------------------------------------------------------------------
:: Run Input Checker
:: -------------------------------------------------------------------------------------------------

CALL %PROJECT_DIRECTORY%\inputChecker\RunInputChecker %PROJECT_DIRECTORY%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

:: -------------------------------------------------------------------------------------------------
:: Run VISUM MAZ, TAZ, and TAP skimming procedures
:: -------------------------------------------------------------------------------------------------

rem # build taz-based skimming setup
%PYTHON% scripts\Master_Runner.py taz_initial
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

rem # build maz-based skimming setup
%PYTHON% scripts\Master_Runner.py maz_initial
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

rem # build tap-based skimming setup
%PYTHON% scripts\Master_Runner.py tap_initial
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

rem # generate taz skims using tomtom speeds
%PYTHON% scripts\Master_Runner.py taz_skim_speed
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

rem # generate maz skims
%PYTHON% scripts\Master_Runner.py maz_skim
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

rem # generate tap skims using tomtom speeds
:RETRY
%PYTHON% scripts\Master_Runner.py tap_skim_speed
IF %ERRORLEVEL% NEQ 0 GOTO RETRY

:: -------------------------------------------------------------------------------------------------
:: Run Commercial Vehicle Model and External Model
:: -------------------------------------------------------------------------------------------------

rem # run cvm
%R_SCRIPT% scripts\cvm.R
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

rem # run external model
%R_SCRIPT% scripts\runExternalModel.R
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

:: -------------------------------------------------------------------------------------------------
:: Loop
:: -------------------------------------------------------------------------------------------------
SET /A ITERATION=0
:ITER_START
SET /A ITERATION+=1
ECHO MODEL ITERATION %ITERATION%

IF %ITERATION% EQU 1 SET SAMPLERATE=%SAMPLERATE_ITERATION1%
IF %ITERATION% EQU 2 SET SAMPLERATE=%SAMPLERATE_ITERATION2%
IF %ITERATION% EQU 3 SET SAMPLERATE=%SAMPLERATE_ITERATION3%
IF %ITERATION% EQU 4 SET SAMPLERATE=%SAMPLERATE_ITERATION4%
IF %ITERATION% EQU 5 SET SAMPLERATE=%SAMPLERATE_ITERATION5%

:: -------------------------------------------------------------------------------------------------
:: Run OR RAMP demand model
:: -------------------------------------------------------------------------------------------------

rem # start matrix manager server
CALL application\runMtxMgr %PROJECT_DRIVE% %PROJECT_DIRECTORY% %HOST_IP_ADDRESS% %JAVA_PATH%

rem # start hh manager server
CALL application\runHhMgr %PROJECT_DRIVE% %PROJECT_DIRECTORY% %HOST_IP_ADDRESS% %JAVA_PATH%

rem # run OR RAMP model, but first set IP_ADDRESS dynamically
ECHO # Properties File with IP Address Set by Model Runner > config\orramp_out.properties
FOR /F "delims=*" %%i IN (config\orramp.properties) DO (
    SET LINE=%%i
    SETLOCAL EnableDelayedExpansion
    SET LINE=!LINE:%%HOST_IP_ADDRESS%%=%HOST_IP_ADDRESS%!
    ECHO !LINE!>>config\orramp_out.properties
    ENDLOCAL
)
CALL application\runORRAMP %PROJECT_DRIVE% %PROJECT_DIRECTORY_FORWARD% %SAMPLERATE% %ITERATION% %JAVA_PATH%

rem # shutdown matrix manager and hh manager
CALL application\killjava

:: -------------------------------------------------------------------------------------------------
:: Build, load, and assign trip matrices into VISUM
:: -------------------------------------------------------------------------------------------------

%PYTHON% scripts\Master_Runner.py build_trip_matrices %SAMPLERATE% %ITERATION%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

%PYTHON% scripts\Master_Runner.py taz_skim %ITERATION%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR
:here
%PYTHON% scripts\Master_Runner.py tap_skim
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

:: -------------------------------------------------------------------------------------------------
:: Loop again if needed
:: -------------------------------------------------------------------------------------------------

IF %ITERATION% LSS %MAX_ITER% GOTO ITER_START

:: -------------------------------------------------------------------------------------------------
:: Assign non-motorized matrices
:: -------------------------------------------------------------------------------------------------

%PYTHON% scripts\Master_Runner.py nm_assignment
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

:: -------------------------------------------------------------------------------------------------
:: Generate assignment summary file and inputs for HTML dashboard
:: -------------------------------------------------------------------------------------------------
%PYTHON% scripts\Master_Runner.py generate_html_inputs
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

%PYTHON% scripts\Master_Runner.py generate_final_summary %PROJECT_DIRECTORY%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

:: -------------------------------------------------------------------------------------------------
:: Process ABM Outputs and generate HTML dashboard
:: -------------------------------------------------------------------------------------------------
ECHO Processing ABM outputs and generating HTML dashboard...
:: Visualizer configuration
SET BASE_SUMMARY_DIR=%PROJECT_DIRECTORY%\inputs\OHAS_Census_Summaries
SET BUILD_SUMMARY_DIR=%PROJECT_DIRECTORY%\outputs\other\ABM_Summaries

SET BASE_SCENARIO_NAME=OHAS
SET BUILD_SCENARIO_NAME=SOABM
:: for survey base legend names are different [Yes/No]
:: assignment summaries are for all links
SET IS_BASE_SURVEY=Yes
SET BASE_SAMPLE_RATE=1.0

IF %MAX_ITER% EQU 1 SET BUILD_SAMPLE_RATE=%SAMPLERATE_ITERATION1%
IF %MAX_ITER% EQU 2 SET BUILD_SAMPLE_RATE=%SAMPLERATE_ITERATION2%
IF %MAX_ITER% EQU 3 SET BUILD_SAMPLE_RATE=%SAMPLERATE_ITERATION3%
IF %MAX_ITER% EQU 4 SET BUILD_SAMPLE_RATE=%SAMPLERATE_ITERATION4%
IF %MAX_ITER% EQU 5 SET BUILD_SAMPLE_RATE=%SAMPLERATE_ITERATION5%

CALL %PROJECT_DIRECTORY%\visualizer\generateDashboard %PROJECT_DIRECTORY% %BASE_SUMMARY_DIR% %BUILD_SUMMARY_DIR% %BASE_SCENARIO_NAME% %BUILD_SCENARIO_NAME% %IS_BASE_SURVEY% %BASE_SAMPLE_RATE% %BUILD_SAMPLE_RATE% %MAX_ITER%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

:: -------------------------------------------------------------------------------------------------
:: All done
:: -------------------------------------------------------------------------------------------------

ECHO MODEL RUN COMPLETE

:: Remind user to check inputChecker LOG
ECHO Please check log file in "inputChecker\logs" directory
TYPE %PROJECT_DIRECTORY:/=\%inputChecker\logs\inputCheckerSummary.txt
PAUSE
GOTO END

:MODEL_ERROR
ECHO Model Failed
PAUSE

:END
