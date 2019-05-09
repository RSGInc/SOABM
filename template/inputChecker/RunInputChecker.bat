:: ############################################################################
:: # Batch file to run SO-ABM Input Checker
:: # binny.mathewpaul@rsginc.com, April 2019
:: #
:: ############################################################################
@ECHO off

:: Set up dependencies
:: ###################
SET WORKING_DIR=%~dp0
ECHO WORKING_DIR: %WORKING_DIR%

SET PYTHON=%WORKING_DIR%..\..\dependencies\Python27\python.exe
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
	ECHO Input checker found fatal error in inputs. Aborting Model Run. 
	ECHO Please check log file in "inputChecker\logs" directory for more details
	PAUSE
	exit 2
)
:: Error in input checker
ECHO Input Checker did not run successfully. Debug Input Checker for errors.
PAUSE
exit 1

:END
