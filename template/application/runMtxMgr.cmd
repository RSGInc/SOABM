
set PROJECT_DRIVE=%1
set PROJECT_DIRECTORY=%2
set HOST_IP_ADDRESS=%3
set JAVA_PATH=%4


%PROJECT_DRIVE%
cd %PROJECT_DIRECTORY%

set HOST_MATRIX_PORT=1191

:: get the ipaddress of this machine
FOR /F "TOKENS=1* DELIMS= " %%A IN ('IPCONFIG') DO (
  IF "%%A"=="IPv4" SET IP=%%B
)
FOR %%A IN (%IP%) DO SET IPADDRESS=%%A
set HOST_IP_ADDRESS=%IPADDRESS%

rem ### Set the directory of the jdk version desired for this model run
rem ### Note that a jdk is required; a jre is not sufficient, as the UEC class generates
rem ### and compiles code during the model run, and uses javac in the jdk to do this.

rem ### Name the project directory.  This directory will hava data and runtime subdirectories
set CONFIG=%PROJECT_DIRECTORY%/config
set JAR_LOCATION=%PROJECT_DIRECTORY%/application
set LIB_JAR_PATH=%JAR_LOCATION%/odottm2.jar

rem ### Define the CLASSPATH environment variable for the classpath needed in this model run.
set OLDCLASSPATH=%CLASSPATH%

rem ### Define the CLASSPATH environment variable for the classpath needed in this model run.
set CLASSPATH=%CONFIG%;%PROJECT_DIRECTORY%;%LIB_JAR_PATH%;%JAR_LOCATION%\*

rem ### Save the name of the PATH environment variable, so it can be restored at the end of the model run.
set OLDPATH=%PATH%

rem ### Change the PATH environment variable so that JAVA_HOME is listed first in the PATH.
rem ### Doing this ensures that the JAVA_HOME path we defined above is the on that gets used in case other java paths are in PATH.
set PATH=%JAVA_PATH%\bin;%JAR_LOCATION%;%OLDPATH%

rem java -Dname=p%HOST_MATRIX_PORT% -Xdebug -Xrunjdwp:transport=dt_socket,address=1049,server=y,suspend=y -server -Xmx10g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j_mtx.xml com.pb.mtctm2.abm.ctramp.MatrixDataServer -hostname %HOST_IP_ADDRESS% -port %HOST_MATRIX_PORT% -label "ORRAMP Matrix Sever"
ECHO ***calling: %JAVA_PATH%\bin\java -Dname=p%HOST_MATRIX_PORT% -Xmx10g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j_mtx.xml com.pb.mtctm2.abm.ctramp.MatrixDataServer -hostname %HOST_IP_ADDRESS% -port %HOST_MATRIX_PORT% -label "ORRAMP Matrix Server"
START %JAVA_PATH%\bin\java -Djava.library.path=%JAR_LOCATION% -Dname=p%HOST_MATRIX_PORT% -Xmx10g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j_mtx.xml com.pb.mtctm2.abm.ctramp.MatrixDataServer -hostname %HOST_IP_ADDRESS% -port %HOST_MATRIX_PORT% -label "ORRAMP Matrix Server"

rem ### restore saved environment variable values, and change back to original current directory
set PATH=%OLDPATH%
set CLASSPATH=%OLDCLASSPATH%