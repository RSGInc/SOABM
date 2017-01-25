rem # run VISUM network LOS procedures
rem # Ben Stabler, ben.stabler@rsginc.com, 060915

SET PYTHON="C:\Program Files\Python27\python.exe"

rem # build taz-based skimming setup
%PYTHON% scripts\SOABM.py taz_initial

rem # build maz-based skimming setup
%PYTHON% scripts\SOABM.py maz_initial

rem # build tap-based skimming setup
%PYTHON% scripts\SOABM.py tap_initial

rem # generate taz skims using free flow speeds
rem # %PYTHON% scripts\SOABM.py taz_skim

rem # generate taz skims using tomtom speeds
%PYTHON% scripts\SOABM.py taz_skim_speed

rem # generate maz skims
%PYTHON% scripts\SOABM.py maz_skim

rem # generate tap skims using free flow speeds
rem # %PYTHON% scripts\SOABM.py tap_skim

rem # generate tap skims using tomtom speeds
%PYTHON% scripts\SOABM.py tap_skim_speed
