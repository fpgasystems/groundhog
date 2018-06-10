// Title:  Implementation of various CPU utilties 
//
// Copyright: Microsoft 2009
//
// Author: Rene Mueller
//
// Created: 8/10/09 
//
// Version: 1.00
// 
// 
// Description: Contains functions for reading the current clock speed of
// of the CPU, setting the affinity of a process to a specified core and 
// reading out the time-based counter register.
//
// Changelog: 
//
//----------------------------------------------------------------------------

#include "include.h"

extern "C" {
#include <powrprof.h>
}

// missing Windows processor power information struct
typedef struct _PROCESSOR_POWER_INFORMATION {
	ULONG  Number;
    ULONG  MaxMhz;
    ULONG  CurrentMhz;
    ULONG  MhzLimit;
    ULONG  MaxIdleState;
    ULONG  CurrentIdleState;
} PROCESSOR_POWER_INFORMATION , *PPROCESSOR_POWER_INFORMATION;


typedef std::vector<PROCESSOR_POWER_INFORMATION> PPIVector;

//
// set process affinity to a specified core
// @param  core number (0: first core CPU0, 1: second core CPU1, etc.)
// @return 0 upon success, 1 in case of an error
//
//int set_affinity_core(int core)
//{
//	DWORD_PTR mask, processMask, systemMask; 
//	if ((core<0) || (core>63))
//		return 1;
//	mask = 1LL << core;
//	
//	// fixating process to CPU<core>
//	if (!SetProcessAffinityMask(GetCurrentProcess(), mask)) 
//		return 1;
//	SwitchToThread(); // trying to yield process such that it moves (does this work?)
//
//	// make sure we run only on CPU<core>	
//	GetProcessAffinityMask(GetCurrentProcess(), (PDWORD_PTR)&processMask, (PDWORD_PTR)&systemMask);
//
//	return ((processMask & mask) == mask)?0:1;
//}
//
////
//// set process affinity to the second core (CPU1)
//// @return 0 upon success, 1 in case of an error
////
//int set_affinity_secondcore()
//{
//	UINT64 processMask, systemMask; 
//
//	// fixating process to CPU1
//	SetProcessAffinityMask(GetCurrentProcess(), 2);
//	SwitchToThread(); // trying to yield process such that it moves (does this work?)
//
//	// make sure we run only on CPU1	
//	GetProcessAffinityMask(GetCurrentProcess(), (PDWORD_PTR)&processMask, (PDWORD_PTR)&systemMask);
//
//	return ((processMask & 0xf) == 0x1)?0:1;
//}


//
// return the current clock speed of CPU0
// @return clock frequency in MHz
int get_clockspeed_mhz()
{
    SYSTEM_INFO sys_info;
    PPIVector ppis;
	int speed = -1;

    // find out how many processors we have in the system
    GetSystemInfo(&sys_info);
    ppis.resize(sys_info.dwNumberOfProcessors);

    // get CPU stats
    if (CallNtPowerInformation(ProcessorInformation, NULL, 0, &ppis[0],
        (ULONG)(sizeof(PROCESSOR_POWER_INFORMATION) * ppis.size())) != ERROR_SUCCESS)
    {
        perror("main: ");
        return -1;
    }

    // print out CPU stats
    for (PPIVector::iterator it = ppis.begin(); it != ppis.end(); ++it)
    {
		if (it->Number == 0) {
			speed = it->CurrentMhz;
		}
	}
	return speed;
}


