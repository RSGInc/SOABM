set PROJECT_DRIVE=%1
set PROJECT_DIRECTORY=%2
set HOST_IP_ADDRESS=%3
set JAVA_PATH=%4

set HOST_PORT=1117

%PROJECT_DRIVE%
cd %PROJECT_DIRECTORY%


:: get the ipaddress of this machine
FOR /F "TOKENS=1* DELIMS= " %%A IN ('IPCONFIG') DO (
  IF "%%A"=="IPv4" SET IP=%%B
)
FOR %%A IN (%IP%) DO SET IPADDRESS=%%A
set HOST_IP_ADDRESS=%IPADDRESS%

rem ### Name the project directory.  This directory will hava data and runtime subdirectories
set CONFIG=%PROJECT_DIRECTORY%\config
set JAR_LOCATION=%PROJECT_DIRECTORY%\application
set LIB_JAR_PATH=%JAR_LOCATION%/odottm2.jar

rem ### Define the CLASSPATH environment variable for the classpath needed in this model run.
set OLDCLASSPATH=%CLASSPATH%

rem ### Define the CLASSPATH environment variable for the classpath needed in this model run.
set CLASSPATH=%CONFIG%;%PROJECT_DIRECTORY%;%LIB_JAR_PATH%;%JAR_LOCATION%\*

rem ### Save the name of the PATH environment variable, so it can be restored at the end of the model run.
set OLDPATH=%PATH%

rem ### Change the PATH environment variable so that JAVA_HOME is listed first in the PATH.
rem ### Doing this ensures that the JAVA_HOME path we defined above is the on that gets used in case other java paths are in PATH.
set PATH=%JAVA_PATH%\bin;%OLDPATH%

rem ### Change current directory to RUNTIME, and issue the java command to run the model.
ECHO ***calling: java -server -Xmx35000m -cp "%CLASSPATH%" -Dlog4j.configuration=log4j_hh.xml com.pb.mtctm2.abm.application.SandagHouseholdDataManager2 -hostname %HOST_IP_ADDRESS% -port %HOST_PORT%
START %JAVA_PATH%\bin\java -server -Xmx10000m -cp "%CLASSPATH%" -Dlog4j.configuration=log4j_hh.xml com.pb.mtctm2.abm.application.SandagHouseholdDataManager2 -hostname %HOST_IP_ADDRESS% -port %HOST_PORT%
rem java -Xdebug -Xrunjdwp:transport=dt_socket,address=1044,server=y,suspend=y -server -Xms40000m -Xmx40000m -cp "%CLASSPATH%" -Dlog4j.configuration=log4j_hh.xml com.pb.mtctm2.abm.application.SandagHouseholdDataManager2 -hostname %HOST_IP_ADDRESS% -port %HOST_PORT%
ECHO %ERRORLEVEL%
IF %ERRORLEVEL% NEQ 0 GOTO MODEL_ERROR
 
rem ### restore saved environment variable values, and change back to original current directory
set PATH=%OLDPATH%
set CLASSPATH=%OLDCLASSPATH%

ECHO HhMgr COMPLETE
GOTO END

:MODEL_ERROR
ECHO Model Failed
PAUSE
EXIT 1

:END

