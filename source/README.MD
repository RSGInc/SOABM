
How to Build the ODOT ABM Java program
======================================

  - Download Eclipse
  - Import odottm2 as an Eclipse project
  - Build with Ant
    - Right click on build.xml and select Run As and then Ant Build. This should fail, but will setup a default Ant Build configuration
    - Right click on build.xml and select Run As and then External tools configurations
    - Go to the Targets tab and check "release"
    - Click Run to build
    - odottm2.jar in the release folder is the release version
 - Copy odottm2.jar to template\application folder before running the model
