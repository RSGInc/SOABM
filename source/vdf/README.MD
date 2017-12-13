
How to Build the ODOT VDF
=========================

  - Download Visual Studio Community 2017
  - Download the Desktop Development with C++ Workload if needed (for building Windows desktop C++ applications)
  - Open the UserDefVDF.sln
  - Set the solution configuration to "Release" and the platform to "x64"
  - Go to Build + Rebuild Solution
  - The output VisumVDF_ODOTVDFx64.dll DLL should be in x64/release folder
  - Copy the DLL to the VISUM project directories user defined DLLs folder, such as:
    ``C:\Users\ben.stabler\AppData\Roaming\PTV Vision\PTV Visum 16\UserVDF-DLLs``
  - Copy the VisumVDF_ODOTVDFx64.bmp function image for the VISUM VDF dialog to the same folder
  - Confirm the DLL in VISUM via Calculate + Procedures + General Procedure Settings + PrT Settings + VDF and click Create.  Select the ODOTVDF (user-defined).
