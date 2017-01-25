@ECHO OFF
::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
:: Run the entire SOABM travel model
:: Ben Stabler, ben.stabler@rsginc.com, 081215
::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:: -------------------------------------------------------------------------------------------------
:: Set properties
:: -------------------------------------------------------------------------------------------------

:: user specified for now; once model is stable, automatically calculate many of these
SET HOST_IP_ADDRESS=172.28.0.100
SET JAVA_PATH=C:\\Progra~1\\Java\\jdk1.8.0_45
SET PROJECT_DRIVE=E:
SET PROJECT_DIRECTORY_FORWARD=E:/projects/Clients/ODOT/SouthernOregonABM/BaseYear2010_Template
SET PROJECT_DIRECTORY=E:\projects\Clients\ODOT\SouthernOregonABM\BaseYear2010_Template
SET PYTHON="C:\Program Files\Python27\python.exe"
SET R_SCRIPT="C:\Program Files\R\R-3.2.1\bin\Rscript"
SET MAX_ITER=3
SET SAMPLERATE_ITERATION1=0.5
SET SAMPLERATE_ITERATION2=0.75
SET SAMPLERATE_ITERATION3=1.0
SET SAMPLERATE_ITERATION4=1.0
SET SAMPLERATE_ITERATION5=1.0

:: -------------------------------------------------------------------------------------------------
:: Run VISUM MAZ, TAZ, and TAP skimming procedures
:: -------------------------------------------------------------------------------------------------

rem # build taz-based skimming setup
%PYTHON% scripts\SOABM.py taz_initial

rem # build maz-based skimming setup
%PYTHON% scripts\SOABM.py maz_initial

rem # build tap-based skimming setup
%PYTHON% scripts\SOABM.py tap_initial

rem # generate taz skims using tomtom speeds
%PYTHON% scripts\SOABM.py taz_skim_speed

rem # generate maz skims
%PYTHON% scripts\SOABM.py maz_skim

rem # generate tap skims using tomtom speeds
%PYTHON% scripts\SOABM.py tap_skim_speed

:: -------------------------------------------------------------------------------------------------
:: Run Commercial Vehicle Model and External Model
:: -------------------------------------------------------------------------------------------------

rem # run cvm
%R_SCRIPT% scripts\cvm.R

rem # run external model
%R_SCRIPT% scripts\externalModel_SWIM.R

:: -------------------------------------------------------------------------------------------------
:: Loop
:: -------------------------------------------------------------------------------------------------
SET /A ITERATION=0
:ITER_START
SET /A ITERATION+=1
ECHO ****MODEL ITERATION %ITERATION%

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

rem # run OR RAMP model
CALL application\runORRAMP %PROJECT_DRIVE% %PROJECT_DIRECTORY_FORWARD% %SAMPLERATE% %ITERATION% %JAVA_PATH%

rem # shutdown matrix manager and hh manager
CALL application\killjava 

:: -------------------------------------------------------------------------------------------------
:: Build, load, and assign trip matrices into VISUM
:: -------------------------------------------------------------------------------------------------

%PYTHON% scripts\SOABM.py build_trip_matrices %SAMPLERATE% %ITERATION%

%PYTHON% scripts\SOABM.py taz_skim

%PYTHON% scripts\SOABM.py tap_skim

:: -------------------------------------------------------------------------------------------------
:: Loop again if needed
:: -------------------------------------------------------------------------------------------------

IF %ITERATION% LSS %MAX_ITER% GOTO ITER_START

:: -------------------------------------------------------------------------------------------------
:: All done
:: -------------------------------------------------------------------------------------------------

ECHO MODEL RUN COMPLETE

