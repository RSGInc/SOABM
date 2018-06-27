#ifndef __USERDEFINEDVDF_H
#define __USERDEFINEDVDF_H

#include "wctype.h" // for wchar_t

/*
 *   Description	This function is called by VISUM once immediately after start-up and before the first use of any of the other functions. 
 *                Use this function to initialize your data structures or perform any other preparatory functions, if necessary.
 *   Parameters	  none
 *   Return value	true – initialization successful
 *                false – initialization failed, DLL should not be called
 */
extern "C" __declspec (dllexport) char Init();

/*
 *   Description	This function is called by VISUM once immediately before shut-down and after the last use of any of the other functions. 
                  Use this function to perform any clean-up, if necessary, e.g. free up dynamically allocated memory
 *   Parameters	  none
 *   Return value	none
 */
extern "C" __declspec (dllexport) void Destroy();

/*
 */
extern "C" __declspec (dllexport) char IsThreadSafe();

/*
 */
extern "C" __declspec (dllexport) char DependsOnTSys();

/*
 *   Description	Should return a readable name for the functional form which is used as the combobox entry in the volume-delay function dialog
 *   Parameters	  langid: a language code which can be used to optionally translate the name to other languages. Ignore if this is not needed. 
 *                        If you use the language code, always include the case of an unknown code, because languages may be added in the future 
 *                        without a formal interface change. Possible values as of now:
 *                        ‘ENG’ – English
 *                        ‘DEU’ – German
 *                        ‘FRA’ – French
 *                        ‘ITA’ – Italian
 *                        ‘POL’ – Polish
 *                        ‘SPA’ – Spanish
 *                        ‘LAS’ – Latin-American Spanish
 *                        ‘CHI’ – Chinese
 *                        ‘JAP’ - Japanese
 *   Return value	The readable name of the functional form as a 16-bit UTF-16 character string. The value must be returned as UTF-16 
 *                to accommodate special characters in some languages, notably the Asiatic ones.
 */
extern "C" __declspec (dllexport) const wchar_t* GetName(const char *langid);

/*
 *   Description	Should return a string to be used as a unique ID for the functional form. This ID is stored internally in the version file 
 *                to record the user allocation to link types, and as the ID of the functional form in the XML format for procedure parameters.
 *   Parameters	  none
 *   Return value	the ID string as an ASCII string. The string must contain only the characters 0..9, a..z, A..Z.
 */
extern "C" __declspec (dllexport) const char* GetID();

/*
 *   Description	The DLL interface definition is versioned, so that function declarations can be changed or extended in the future. 
 *                Return the version number of the header file against which you program your functions. VISUM compares the returned number 
 *                to the version numbers it knows about, calls the DLL functions accordingly or gives an error message, if the version number 
 *                is not supported.
 *   Parameters	  none
 *   Return value	the version number
 */
extern "C" __declspec (dllexport) int GetInterfaceVersion();

/*
 *   Description	VISUM calls this function once at the beginning of each assignment. It passes as parameters the number of transport systems and 
 *                an array of the codes for each transport system. For efficiency reasons, the other functions will receive the transport system 
 *                as a number, the zero-based index into array tsysids.  To avoid string comparisons in these frequently called functions, 
 *                you should in SetTsysInfo evaluate once and store the numerical index  of those transport systems 
 *                which need special treatment in the volume-delay function.
 *   Parameters	  numtsys – the number of transport systems (= length of array tsysids)
 *                tsysids – array of 16-bit UTF-16 character strings, each of which is the value of the attribute CODE for one transport system 
 *                          used in the assignment.
 *   Return value	none
 */
extern "C" __declspec (dllexport) void SetTsysInfo (int numtsys, const wchar_t * tsysids[]);

/*
 *   Description	The implementation of the volume-delay function itself. VISUM calls this function in order to calculate the current link travel 
 *                time t_curr for one link / turn / connector / node and one transport system. Care should be taken to code the function 
 *                in a computationally efficient form, because it will be called very frequently.
 *   Parameters	  see manual
 *   Return value	t_curr in [s]
 */
extern "C" __declspec (dllexport) double Calc (int tsysind, char tsysisopen,
                                    int typ, int numlanes, double length, double cap, double v0, double t0, double gradient, 
                                    double pcuvol, double basevol, double vehvolsys[], 
                                    int uval1, int uval2, int uval3, int uvaltsys, 
                                    double para_a, double para_b, double para_c, double para_d, double para_f, double para_a2, double para_b2, double para_d2, double para_f2, double satcrit);

/*
 *   Description	VISUM calls this function in order to calculate the derivative of the current link travel time t_curr with respect to the volume 
 *                of the given tsys for one link / turn / connector / node and one transport system. This function is only called 
 *                within the bicriterial toll assignment methods Tribut and Tribut_Lohse. Care should be taken to code the function 
 *                in a computationally efficient form, because it will be called very frequently.
 *                If the function is not implemented by the DLL, VISUM will compute the derivative numerically. This will be slower than supplying 
 *                CalcDerivative() in the DLL.
 *   Parameters	  same as for Calc()
 *   Return value	derivative of t_curr in [s]
 */
extern "C" __declspec (dllexport) double CalcDerivative (int tsysind, char tsysisopen,
                                              int typ, int numlanes, double length, double cap, double v0, double t0, double gradient, 
                                              double pcuvol, double basevol, double vehvolsys[], 
                                              int uval1, int uval2, int uval3, int uvaltsys, 
                                              double para_a, double para_b, double para_c, double para_d, double para_f, double para_a2, double para_b2, double para_d2, double para_f2, double satcrit);

/*
 *   Description	VISUM calls this function in order to calculate the integral of the current link travel time t_curr 
 *                for one link / turn / connector / node and one transport system. This function is needed in the computation of the Relavtive Gap 
 *                according to the formulation due to David Boyce. Care should be taken to code the function in a computationally efficient form, 
 *                because it will be called very frequently.
 *                If the function is not implemented by the DLL, VISUM will compute the integral numerically. This will be slower than supplying 
 *                CalcIntegral() in the DLL.
 *   Parameters	  same as for Calc()
 *   Return value	integral from 0 to VolPCU of the volume-delay function in [s].
 */
extern "C" __declspec (dllexport) double CalcIntegral (int tsysind, char tsysisopen,
                                            int typ, int numlanes, double length, double cap, double v0, double t0, double gradient, 
                                            double pcuvol, double basevol, double vehvolsys[], 
                                            int uval1, int uval2, int uval3, int uvaltsys, 
                                            double para_a, double para_b, double para_c, double para_d, double para_f, double para_a2, double para_b2, double para_d2, double para_f2, double satcrit);


#endif // __USERDEFINEDVDF_H