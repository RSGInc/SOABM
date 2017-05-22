Oregon Department of Transportation (ODOT) Southern Oregon Activity Based Model (SOABM)

The SOABM is a collection of travel modeling components.  The core components of the system are:
  - OR-RAMP – ODOT’s version of the CT-RAMP family of ABMs for modeling resident travel.
  - VISUM + Python – Zone and network data management, as well as network skimming and assignment procedures.
  - Commercial vehicle model – ODOT’s trip-based commercial vehicle model implemented in R.
  - External model – ODOT’s external travel model based on select link analysis flows from SWIM at each SOABM external station location.
  - RunModel – A DOS batch program for running the overall model system.

## Contents

  - source: Java source code and dependencies for building the AB demand model program
  - template: Template full model setup (except for inputs) for the Southern Oregon ABM
  - dependencies.zip: Complete Java, Python, and R installs for running the model
  
## Installation
Check out the repository. This repository uses [`git-lfs`](https://git-lfs.github.com), which the user will need to install separately.

```sh
# with git-lfs installed
git clone https://username@github.com/rsginc/SOABM
```

If you clone the repository before installing `git-lfs`, you can download the large file resources with

```sh
git lfs fetch
```

On initial checkout, the user will need to:

  1. Expand dependencies.zip: included versions of Java, Python, and R.
  2. Ensure [Visum 16](http://vision-traffic.ptvgroup.com/en-us/products/ptv-visum/) is installed.  The user will need to install a licensed version of this software prior to running the model.

The current version of the model requires a computer with a 64-bit Windows operating system. The computer should have 40 GB+ RAM, and at least 100 GB of free space on the model hard drive.

## File Structure
The installed model has a general file structure as shown below (all paths relative to the installation location):

```
root/dependencies/
  jdk1.8.0_111/ – Java install
  Python27/ – Python install
  R-3.3.1/ – R install
root/scenario_name/
  RunModel.bat – overall model run script
  application/ – DOS batch files, Java ORRAMP jar file, HDF5 DLLs for OMX
  config/ – ORRAMP properties file, ORRAMP JPPF config files
    cvm/ – CVM model parameters
    visum/ – skimming procedure files
  inputs/ – Popsyn input files, VISUM scenario version file, external model input files
  logs/ – ORRAMP output log files
  outputs/ – all model outputs – skims, trip lists, matrices, etc.
  scripts/ – VISUM skimming, OMX reader/writer, external model, CVM
  uec/ – ORRAMP utility expression calculator (UEC) model parameter files
```

Every scenario is contained within its own folder, with a unique name. The folder 
name is the same as the scenario name.  

## Running the Model

Open a DOS command window in the scenario root folder and run RunModel.bat