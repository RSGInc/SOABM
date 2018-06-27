#include "UserDefinedVDF.h"

#include "tchar.h"
#include <math.h>

wchar_t VDFName[] = _T("ODOTVDF");
char  VDFID[] = "ODOTVDF";
int INTERFACE_VERSION = 1;

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

char Init()
{
  return TRUE;
}

void Destroy()
{
}

char IsThreadSafe()
{
  return TRUE;
}

char DependsOnTSys()
{
  return FALSE;
}

const wchar_t* GetName(const char *langid)
{
  return VDFName;
}

const char* GetID()
{
  return VDFID;
}

int GetInterfaceVersion()
{
  return INTERFACE_VERSION;
}

void SetTsysInfo (int numtsys, const wchar_t * tsysids[])
{
}

double CalcDerivative(int tsysind, char tsysisopen,
	int typ, int numlanes, double length, double cap, double v0, double t0, double gradient,
	double pcuvol, double basevol, double vehvolsys[],
	int uval1, int uval2, int uval3, int uvaltsys,
	double para_a, double para_b, double para_c, double para_d, double para_f, double para_a2, double para_b2, double para_d2, double para_f2, double satcrit)
{
	return 0.0;
}

double CalcIntegral(int tsysind, char tsysisopen,
	int typ, int numlanes, double length, double cap, double v0, double t0, double gradient,
	double pcuvol, double basevol, double vehvolsys[],
	int uval1, int uval2, int uval3, int uvaltsys,
	double para_a, double para_b, double para_c, double para_d, double para_f, double para_a2, double para_b2, double para_d2, double para_f2, double satcrit)
{
	return 0.0;
}

double Calc (int tsysind, char tsysisopen,
             int typ, int numlanes, double length, double cap, double v0, double t0, double gradient, 
             double pcuvol, double basevol, double vehvolsys[], 
             int uval1, int uval2, int uval3, int uvaltsys, 
             double para_a, double para_b, double para_c, double para_d, double para_f, double para_a2, double para_b2, double para_d2, double para_f2, double satcrit)
{
	//mid link capacity
	double mid_link_cap = uval1 * 1.0;
	if (mid_link_cap <= 0.0) {
		return 10E10;
	}
	double mid_link_bpr = t0 * (1.0 + para_a * pow( (pcuvol / mid_link_cap), para_b ));
	
	//uncongested signal delay scaled by 100 since AddVal2 must be an integer
	double unc_sig_delay = uval2 / 100.0;

	//intersection congestion adjustment
	double int_cap = uval3 * 1.0;
	double int_cong_adj = 1.0;
	if (int_cap > 0.0 ) {
        int_cong_adj = 1.0 + para_a2 * pow((pcuvol / int_cap), para_b2);
	}
	
    //return the complete vdf
    return mid_link_bpr + unc_sig_delay * int_cong_adj;
}
