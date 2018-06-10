#include <iostream>
#include <sstream>
#include <fstream>
#include <string>
#include <iomanip>
#include <windows.h>
#include <assert.h>
#include <WinIoctl.h>
#include <list>
#include <vector>
#include <time.h>
#include <direct.h>

using namespace std;

#ifndef DEFINETYPESH
#define DEFINETYPESH
#include "types.h"
#endif

#ifndef DEFINEPACKETH
#define DEFINEPACKETH
#include "packet.h"
#endif

#ifndef DEFINEETHSIRCH
#define DEFINEETHSIRCH
//#define BIGDEBUG
#include "eth_SIRC.h"
#endif

#ifndef DEFINEUTILH
#define DEFINEUTILH
#include "util.h"
#endif

#ifndef DEFINECPUTOOLSH
#define DEFINECPUTOOLSH
#include "cputools.h"
#endif