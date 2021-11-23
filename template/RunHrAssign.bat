
::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
:: Run a specific period assignment
:: Alex Bettinardi, alexander.o.bettinardi@odot.state.or.us, 02-20-20
::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Jin Ren updated to run from Python27\python.exe to Python37\python.exe on 11/10/2021

:: setup iteration, sample rate, period
SET ITERATION=0
SET SAMPLERATE=1.0
SET PERIODNAME=PKHR
SET TPSTART=25
SET TPEND=27



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
# SET PYTHON=%~dp0..\dependencies\Python27\python.exe
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



:: -------------------------------------------------------------------------------------------------
:: Build, load, and assign trip matrices into VISUM
:: -------------------------------------------------------------------------------------------------

%PYTHON% scripts\Master_Runner.py build_trip_matrices %SAMPLERATE% %ITERATION% %PERIODNAME% %TPSTART% %TPEND%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

%PYTHON% scripts\Master_Runner.py taz_skim_pkhr %PERIODNAME%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR

ECHO MODEL RUN COMPLETE
GOTO END

:MODEL_ERROR
ECHO Model Failed

:END
