
# Setting Up a New Scenario

Unzip the template setup SOABM_<date>.zip file that includes the following folders and files.
  - RunModel.bat – overall model run script
  - application – DOS batch files, Java ORRAMP jar file, HDF5 DLLs for OMX
  - config – ORRAMP properties file, ORRAMP JPPF config files
  - cvm – CVM model parameters; R library installers
  - visum – skimming procedure files
    - TAZ assignment using warm start path-based assignment
    - TAP assignment using headway-based optimal strategies search
  - inputs – Popsyn input files, VISUM scenario version file, external model input files
  - logs – ORRAMP output log files
  - outputs – all model outputs – skims, trip lists, matrices, etc.
  - scripts – VISUM skimming, OMX reader/writer, external model, CVM
  - uec – ORRAMP utility expression calculator (UEC) model parameter files

The steps to setup a new model run are below.
  - Unzip the SOABM_<date>.zip template setup to a project folder such as C:/SOABM.
  - Set the IP address of the matrix server and household server in the config/orramp.properties file to the IP address of the computer:
    - RunModel.MatrixServerAddress=172.28.0.100
    - RunModel.HouseholdServerAddress=172.28.0.100
  - Set the properties at the top of the RunModel.bat file:
    - HOST_IP_ADDRESS=172.28.0.100 #machine IP address
    - JAVA_PATH=C:\\Progra~1\\Java\\jdk1.8.0_45
    - PROJECT_DRIVE=C:
    - PROJECT_DIRECTORY_FORWARD=C:/SOABM
    - PROJECT_DIRECTORY=C:\SOABM
    - PYTHON="C:\Program Files\Python27\python.exe"
    - R_SCRIPT="C:\Program Files\R\R-3.2.1\bin\Rscript"
    - MAX_ITER=3               #max number of overall model iterations
    - SAMPLERATE_ITERATION1-5=0.5	#HH sample rate 0.5=50%

If the amount of RAM or the number of processing threads for CT-RAMP needs to be updated (because the population increased or the run machine changed) then the following settings should be reviewed:
  - application\runHhMgr.cmd, the -Xmx10000m setting specifies how much RAM is allocated to the household data manager
  - application\runMtxMgr.cmd, the -Xmx10g setting specifies how much RAM is allocated to the matrix data manager
  - application\runORRAMP.cmd, the –Xmx40g setting specifies how much RAM is allocated to the main process
  - config\jppf-clientLocal.properties, the jppf.local.execution.threads = 10 setting specifies how many threads are allocated to CT-RAMP

To run the model, open a DOS command window in the scenario root folder, such as C:/SOABM, and then run RunModel.bat.  
