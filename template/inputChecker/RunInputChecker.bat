:: ############################################################################
:: # Batch file to run SO-ABM Input Checker
:: # binny.mathewpaul@rsginc.com, April 2019
:: #
:: ############################################################################
@ECHO off

:: User Inputs
:: ###########
SET PROJECT_DIR=%1
::SET PROJECT_DIR=E:\projects\clients\odot\SouthernOregonABM\Contingency\Task3\SOABM\template
SET WORKING_DIR=%PROJECT_DIR%\inputChecker


:: Set up dependencies
:: ###################
SET PYTHON=%PROJECT_DIR%..\dependencies\Python27\python.exe
ECHO PYTHON: %PYTHON%


:: Call Input Checker script
:: #########################
%PYTHON% %WORKING_DIR%\scripts\inputChecker.py %WORKING_DIR%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR


:: Error handling and return code
:: ##############################
ECHO Input Checker Ran Successfully. Please check log file in "inputChecker\logs" directory
GOTO END

:MODEL_ERROR
:: Error in inputs
IF %ERRORLEVEL% NEQ 1 (
	ECHO Input checker found fatal error(s) in inputs. Aborting Model Run. 
	ECHO Please check log file in "inputChecker\logs" directory for more details
	PAUSE
	exit 2
)
:: Error in input checker
ECHO Input Checker did not run successfully
PAUSE
exit 1

:END
