set PROJECT_DRIVE=%1
set PROJECT_DIRECTORY=%2
SET sampleRate=%3
SET iteration=%4

rem ### Set the directory of the jdk version desired for this model run
rem ### Note that a jdk is required; a jre is not sufficient, as the UEC class generates
rem ### and compiles code during the model run, and uses javac in the jdk to do this.
set JAVA_PATH=%5

%PROJECT_DRIVE%
cd %PROJECT_DIRECTORY%

set sampleSeed=1234642

rem ### Name the project directory.  This directory will hava data and runtime subdirectories
set CONFIG=%PROJECT_DIRECTORY%\config
set JAR_LOCATION=%PROJECT_DIRECTORY%\application
set LIB_JAR_PATH=%JAR_LOCATION%\odottm2.jar

rem ### Define the CLASSPATH environment variable for the classpath needed in this model run.
set OLDCLASSPATH=%CLASSPATH%

rem ### Define the CLASSPATH environment variable for the classpath needed in this model run.
set CLASSPATH=%CONFIG%;%PROJECT_DIRECTORY%;%LIB_JAR_PATH%;%JAR_LOCATION%\*

rem ### Save the name of the PATH environment variable, so it can be restored at the end of the model run.
set OLDPATH=%PATH%

rem ### Change the PATH environment variable so that JAVA_HOME is listed first in the PATH.
rem ### Doing this ensures that the JAVA_HOME path we defined above is the on that gets used in case other java paths are in PATH.
set PATH=%JAVA_PATH%\bin;%JAR_LOCATION%;%OLDPATH%

rem ### Run ABM LOCAL 
java -server -Xmx40g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j.xml -Dproject.folder=%PROJECT_DIRECTORY% -Djppf.config=jppf-clientLocal.properties com.pb.mtctm2.abm.application.MTCTM2TourBasedModel orramp -iteration %iteration% -sampleRate %sampleRate% -sampleSeed %sampleSeed%
::java -server -Xmx40g -cp "%CLASSPATH%"  -Djava.library.path=%JAR_LOCATION% -Dlog4j.configuration=log4j.xml -Dproject.folder=%PROJECT_DIRECTORY% -Djppf.config=jppf-clientLocal.properties com.pb.mtctm2.abm.application.MTCTM2TourBasedModel orramp -iteration %iteration% -sampleRate %sampleRate% -sampleSeed %sampleSeed%

rem java -Xdebug -Xrunjdwp:transport=dt_socket,address=1045,server=y,suspend=y -server -Xmx40g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j.xml -Dproject.folder=%PROJECT_DIRECTORY% -Djppf.config=jppf-clientLocal.properties com.pb.mtctm2.abm.application.MTCTM2TourBasedModel orramp -iteration %iteration% -sampleRate %sampleRate% -sampleSeed %sampleSeed%
rem java -agentlib:jdwp=transport=dt_socket,address=1045,server=y,suspend=y -server Xmx40g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j.xml -Dproject.folder=%PROJECT_DIRECTORY% -Djppf.config=jppf-clientLocal.properties com.pb.mtctm2.abm.application.MTCTM2TourBasedModel orramp -iteration %iteration% -sampleRate %sampleRate% -sampleSeed %sampleSeed%

rem ### Run ABM DISTRIBUTED
rem java -Xdebug -Xrunjdwp:transport=dt_socket,address=1045,server=y,suspend=y -server Xmx40g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j.xml -Dproject.folder=%PROJECT_DIRECTORY% -Djppf.config=jppf-clientDistributed.properties com.pb.mtctm2.abm.application.MTCTM2TourBasedModel orramp -iteration %iteration% -sampleRate %sampleRate% -sampleSeed %sampleSeed%
rem java -server Xmx40g -cp "%CLASSPATH%" -Dlog4j.configuration=log4j.xml -Dproject.folder=%PROJECT_DIRECTORY% -Djppf.config=jppf-clientDistributed.properties com.pb.mtctm2.abm.application.MTCTM2TourBasedModel orramp -iteration %iteration% -sampleRate %sampleRate% -sampleSeed %sampleSeed%

rem TODO
rem ### create demand matrices in Cube matrix format - must restart mtx manager before running?
rem java -Xmx80g -cp "%CLASSPATH%" -Dproject.folder=%PROJECT_DIRECTORY% com.pb.mtctm2.abm.application.MTCTM2TripTables mtctm2 -iteration %iteration% -sampleRate %sampleRate%
::java -Xmx80g -cp "%CLASSPATH%" -Dproject.folder=%PROJECT_DIRECTORY% com.pb.mtctm2.abm.application.MTCTM2TripTables mtctm2 -iteration %iteration% -sampleRate %sampleRate%

rem ### restore saved environment variable values, and change back to original current directory
set PATH=%OLDPATH%
set CLASSPATH=%OLDCLASSPATH%
