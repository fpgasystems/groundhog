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

// 
// inline function read the 64 bit cycle count register on x86 CPU
//
inline UINT64
get_cyclecount(void)
{
	// t-remuel: read out cycle counter register
	volatile UINT32 lo, hi;
	volatile UINT64 cycles;
	__asm 
		{
			rdtsc			; TSC register -> edx:eax
			mov		lo, eax	; store lower 32 bits
			mov		hi, edx	; store upper 32 bits
		}
	cycles = hi;
	cycles <<= 32;
	cycles |= lo;	
	return cycles;
}


//
// set process affinity to a specified core
// @param  core number (0: first core CPU0, 1: second core CPU1, etc.)
// @return 0 upon success, 1 in case of an error
//
int set_affinity_core(int core);



//
// return the current clock speed of CPU0
// @return clock frequency in MHz (-1 in case of an error)
int get_clockspeed_mhz();
