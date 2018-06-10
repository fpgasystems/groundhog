// Copyright: Microsoft 2009
// Project       : Groundhog : A Serial ATA Host Bus Adapter (HBA) for FPGAs
// Version       : v0.2
// Author        : Louis Woods
//                 includes code written by Ken Eguro 
//                 and 2009 MSR intern Rene Mueller.
//
// Created: 10/23/09 
//
// Changelog: 
// (1) identify: show contents of words 60-61: max. number of sectors of SSD
// (2) identify: check word 84, whether 48-bit addressing is enabled (code will not work otherwise)
//
// Description:
// Program based on the SIRC communication framework to test Groundhog.
// Supported commands:
//   - reset
//   desc: resets the circuit and SSD
//	 - identify
//   desc: issues command "identify device", and extracts info about the SSD/hard disk
//	 - read			LBA					?SECTORCNT(default:1)
//   desc: reads a block at the logical block address 'LBA', the size of the read can be specified
//         as multiple of 512-byte sectors, default is 1=512 bytes
//	 - write		LBA					?SECTORCNT(default:1)	?2BYTEPATTERN(default:repeat0-(2^16-1))
//   desc: wirtes a block starting at the logical block address 'LBA', the size of the read can be specified
//         as multiple of 512-byte sectors, default is 1=512 bytes, a 2-byte pattern can also be specified
//         which is repeated, if no pattern is spceified the block will contain an ascending sequence from 
//         0-2^16-1
//	 - writeseq		?numblocks(default:1)		?blocksize(default:1)	?NCQ(default:0)
//   desc: write a sequential sequence of blocks, parameters are number of blocks
//         block size as multiple of 512-byte sectors and if NCQ should be used (0|1)
//   - writernd		?numblocks(default:1)		?blocksize(default:1)	?NCQ(default:0)
//   desc: write a random sequence of blocks, parameters are number of blocks
//         block size as multiple of 512-byte sectors and if NCQ should be used (0|1)
//   - readback		?blocksize	?NCQ
//   desc: when writeseq/writernd are used the sequence of writes is stored in a file,
//         readback reads that sequence back, parameters are block size and if NCQ should be used
//   - benchmark	?testsdd(default:1)
//   desc: tests sequential read/write speed, random read/write speed and NCQ
//		   setting the paramter testssd=0 will supress the NCQ related tests
//----------------------------------------------------------------------------
//

#include "include.h"

using namespace std;

//How many bytes do we want to send for each bandwidth test?
//Default value = 8KB
#define BANDWIDTHTESTSIZE 8*1024

//How many times would we like to send this message?
#define BANDWIDTHTESTITER 1000

//Packets (FISes) received will be displayed in hex
//#define DEBUGINFO 1
//#define TRANSACTIONINFO 1

// Parametes sent to user application
#define REG_NO_BUFFERCNT 10
#define REG_NO_LINKUP 11
#define REG_NO_CMD_FAILED 12
#define REG_NO_LINKGEN 13
#define REG_CLKTICKCNT_L 14
#define REG_CLKTICKCNT_U 15
#define REG_SATA_ERRORS 16
#define REG_DATA_ERRORS 17

// Constants
#define CMD_IDENTIFY_DEVICE 0
#define	CMD_READ_DMA_EXTENDED 1
#define	CMD_WRITE_DMA_EXTENDED 2
#define	CMD_FIRST_PARTY_DMA_READ_NCQ 3
#define	CMD_FIRST_PARTY_DMA_WRITE_NCQ 4
#define CMD_RESET 5
#define CMD_BENCHMARK_READ_DMA 6
#define CMD_BENCHMARK_WRITE_DMA 7
#define CMD_BENCHMARK_READ_NCQ 8
#define CMD_BENCHMARK_WRITE_NCQ 9

#define	NUMBLOCKS 1
#define BLOCKSIZE 1

#define WAITDONE 60

void error(string inErr){
	cerr << "Error:" << endl;
	cerr << "\t" << inErr << endl;
	exit(-1);
}

string getFISType(const uint8_t byte) {
	switch(byte) {
		case 0x27	:	return "Register FIS (HBA to Device)";			break;
		case 0x34	:	return "Register FIS (Device to HBA)";			break;
		case 0xA1	:	return "Set Device Bits (Device to HBA)";		break;
		case 0x5F	:	return "PIO Setup (Device to HBA)";				break;
		case 0x39	:	return "DMA Activate (Device to HBA)";			break;
		case 0x41	:	return "First Party DMA Setup (Bidirectional)";	break;
		case 0x46	:	return "DATA (Bidirectional)";					break;
		case 0x58	:	return "BIST Activate (Bidirectional)";			break;
		default		:	return "Unknown FIS type";						break;
	}
}

void printDeviceSignature(const uint8_t sectorcount, const uint8_t sectornumber, const uint8_t cylinderlow, const uint8_t cylinderhigh) {
	printf("- Device Signature : ");
	if(sectorcount == 0x01 && sectornumber == 0x01 && cylinderlow == 0x00 && cylinderhigh == 0x00) {
		printf("ATA Device (Sector Count = 0x%02x, Sector Number = 0x%02x, Cylinder Low = 0x%02x, Cylinder High = 0x%02x)", sectorcount, sectornumber, cylinderlow, cylinderhigh);
	} else if(sectorcount == 0x01 && sectornumber == 0x01 && cylinderlow == 0x14 && cylinderhigh == 0xEB) {
		printf("ATAPI Device (Sector Count = 0x%02x, Sector Number = 0x%02x, Cylinder Low = 0x%02x, Cylinder High = 0x%02x)", sectorcount, sectornumber, cylinderlow, cylinderhigh);
	} else {
		printf("Unknown Device (Sector Count = 0x%02x, Sector Number = 0x%02x, Cylinder Low = 0x%02x, Cylinder High = 0x%02x)", sectorcount, sectornumber, cylinderlow, cylinderhigh);
	}
	printf("\n");
}

void printFISStatus(const uint8_t byte) {
	printf("- Status : BSY=%x, DRDY=%x, DF/SE=%x, #=%x, DRQ=%x, obsolete=%x, obsolete=%x, ERR/CHK=%x\n", (byte >> 7) & 0x1, (byte >> 6) & 0x1, (byte >> 5) & 0x1, (byte >> 4) & 0x1, (byte >> 3) & 0x1, (byte >> 2) & 0x1, (byte >> 1) & 0x1, byte & 0x1); 
}

bool isError(const uint8_t byte) {
	if(byte & 0x1)
		return true;
	else
		return false;
}

void printFISError(const uint8_t byte) {
	printf("- Error : ICRC=%x, UNC=%x, MC=%x, IDNF=%x, MCR=%x, ABRT=%x, NM=%x, obsolete=%x\n", (byte >> 7) & 0x1, (byte >> 6) & 0x1, (byte >> 5) & 0x1, (byte >> 4) & 0x1, (byte >> 3) & 0x1, (byte >> 2) & 0x1, (byte >> 1) & 0x1, byte & 0x1); 
}

void identifySerialNumber(uint8_t *outputValues) {
	
	int i;
	uint32_t identifyOffset = 10;
	uint32_t identifyLength = 10;

	cout <<"- [Words 10-19]\tSerial Number = ";
	for(i=0; i<identifyLength*2; i+=2) {
		printf("%c%c",outputValues[(identifyOffset*2)+i+1],outputValues[(identifyOffset*2)+i]);
	}
	cout << endl;

}

void identifyModelNumber(uint8_t *outputValues) {
			
	int i;
	uint32_t identifyOffset = 27;
	uint32_t identifyLength = 20;

	cout <<"- [Words 27-46]\tModel Number = ";
	for(i=0; i<identifyLength*2; i+=2) {
		printf("%c%c",outputValues[(identifyOffset*2)+i+1],outputValues[(identifyOffset*2)+i]);
	}
	cout << endl;

}

void identifyTrimSupport(uint8_t *outputValues) {
			
	int i;
	uint32_t identifyOffset = 169;
	uint32_t identifyLength = 1;

	cout <<"- [Word 169]\tData Set Management Support = ";
	for(i=0; i<identifyLength*2; i+=2) {
		printf("0x%02x%02x -> TRIM Support = %s",outputValues[(identifyOffset*2)+i+1],outputValues[(identifyOffset*2)+i], (outputValues[(identifyOffset*2)+i] & 0x1) ? "yes" : "no");
	}
	cout << endl;

}

void identifyMaxNum512LBARanges(uint8_t *outputValues) {
			
	int i;
	uint32_t identifyOffset = 105;
	uint32_t identifyLength = 1;

	cout <<"- [Word 105]\tMax. number of 512-byte blocks of LBA range entries = ";
	for(i=0; i<identifyLength*2; i+=2) {
		printf("0x%02x%02x",outputValues[(identifyOffset*2)+i+1],outputValues[(identifyOffset*2)+i]);
	}
	cout << endl;

}

void identifySATACapabilities(uint8_t *outputValues) {
			
	int i;
	uint32_t identifyOffset = 76;
	uint32_t identifyLength = 1;

	cout <<"- [Word 76]\tSATA capabilities = ";
	for(i=0; i<identifyLength*2; i+=2) {
		printf("0x%02x%02x\n",outputValues[(identifyOffset*2)+i+1],outputValues[(identifyOffset*2)+i]);
		printf("\t\t-> SATA Gen1 = %s\n",(outputValues[(identifyOffset*2)+i] & 0x2) ? "yes" : "no");
		printf("\t\t-> SATA Gen2 = %s\n",(outputValues[(identifyOffset*2)+i] & 0x4) ? "yes" : "no");
		printf("\t\t-> Native Command Queuing (NCQ) = %s ",(outputValues[(identifyOffset*2)+i+1] & 0x1) ? "yes" : "no");
		if(outputValues[(identifyOffset*2)+i+1] & 0x1) printf(" (queue depth = %d)", (outputValues[(75*2)] & 0x1f)+1);
	}
	cout << endl;

}

void identify48BitSupport(uint8_t *outputValues) {

	uint64_t num_sectors;
	num_sectors = outputValues[60*2+3];
	num_sectors <<= 8;
	num_sectors |= outputValues[60*2+2];
	num_sectors <<= 8;
	num_sectors |= outputValues[60*2+1];
	num_sectors <<= 8;
	num_sectors |= outputValues[60*2+0];

	if(num_sectors = 0x0FFFFFFF) {
		num_sectors = outputValues[100*2+7];
		num_sectors <<= 8;
		num_sectors |= outputValues[100*2+6];
		num_sectors <<= 8;
		num_sectors |= outputValues[100*2+5];
		num_sectors <<= 8;
		num_sectors |= outputValues[100*2+4];
		num_sectors <<= 8;
		num_sectors |= outputValues[100*2+3];
		num_sectors <<= 8;
		num_sectors |= outputValues[100*2+2];
		num_sectors <<= 8;
		num_sectors |= outputValues[100*2+1];
		num_sectors <<= 8;
		num_sectors |= outputValues[100*2+0];
	}
	
	cout <<"- [Words 60-61]\t";
	printf("Max. number of sectors = %I64u -> SSD capacity = %I64u GB\n", num_sectors, num_sectors*512/1000/1000/1000);
	cout <<"- [Word 84]\t";
	printf("48-bit addressing supported = %s\n", (outputValues[84*2+1] & 0x1) ? "yes" : "no");

}

bool getNCQSupport(uint8_t *outputValues) {
	return outputValues[(76*2)+0+1] & 0x1;
}

bool get48BitSupport(uint8_t *outputValues) {
	return outputValues[84*2+1] & 0x1;
}

uint32_t getQueueDepth(uint8_t *outputValues) {
	return (outputValues[(75*2)] & 0x1f)+1;
}

void sleep(unsigned int msec) {
	clock_t goal = msec + clock();
	while(goal > clock());
}

// Returns 100[ns] intervals
UINT64 getTime() {
	SYSTEMTIME st;
	GetSystemTime(&st);

	FILETIME ft;
	SystemTimeToFileTime(&st, &ft); // converts to filetime format
	ULARGE_INTEGER ui;
	ui.LowPart = ft.dwLowDateTime;
	ui.HighPart = ft.dwHighDateTime;

	return ui.QuadPart;
}

int main(int argc, char* argv[]){
	//Test harness variables
	ETH_SIRC *ETH_SIRC_P;
	uint8_t FPGA_ID[6];

	//Input buffer
	uint8_t *inputValues;
	//Output buffer
	uint8_t *outputValues;

	// Command line arguments
	UINT64 arg1;
    int    arg2;
	int    arg3;

	// SATA demo variables
	uint32_t  readReg = 0;
	uint32_t  numInputBytes = 0;
	uint32_t  numOutputBytes = 0;
	UINT64    LBA;
	uint32_t* LBA_array;
	uint32_t  LBA_L;
	uint32_t  LBA_U;
	uint32_t  SECTORCNT;
	uint32_t  PATTERN;
	uint32_t  numOps;

	// lwoods variables
	UINT64 start, end;
	
	bool isNCQSupported = false;
	bool is48bitAddressingSupported = false;
	bool run_startup = true;
	uint32_t cnt_startup = 0;
	bool run_benchmark = false;
	uint32_t cnt_benchmark = 0;
	bool testssd = true;

	bool blocksizetest_run             = false;
	bool blocksizetest_write           = true;
	bool blocksizetest_seqaccess       = true;
	uint32_t blocksizetest_sectorcnt   = 0;
	uint32_t blocksizetest_numaccesses = 0;

	uint32_t numTimestamps = 0;
	uint32_t numOutputValues = 0;
	uint32_t timestamp = 0;
	uint32_t commandReg = 0;
	uint32_t buffercntReg = 0;
	uint32_t total_clk_cnt_1_Reg = 0;
	uint32_t total_clk_cnt_2_Reg = 0;
	unsigned long long total_clk_cnt = 0;
	uint32_t clockfreq = 0;
	double   period;
	double   total_accesstime;
	double   throughput;
	double   total_data;
	double total_avgaccesstime = 0;
	uint32_t hashReg = 0;
	uint32_t identifyLength = 0;
	uint32_t identifyOffset = 0;
	unsigned char lba[4];
	uint32_t numblocks = NUMBLOCKS;
	uint32_t blocksize = BLOCKSIZE;
	uint32_t blocksize_tmp = 0;
	uint32_t blocksize_shift = 0;
	uint32_t currentLBA = 0;
	uint32_t totalMatches = 0;
	uint32_t totalMisMatches = 0;
	uint32_t totalProbes = 0;
	uint32_t useNCQ;

	char *token = NULL;
	char *next_token = NULL;
	uint32_t i,j;

	//Speed testing variables
	int speed = get_clockspeed_mhz();
	double usPeriod = 1/(double)speed;

	std::ostringstream tempStream;

	//**** Process command line input
	if (argc == 3) {
		//Grab the target MAC address
		token = strtok_s(argv[1], ":", &next_token);
		for (i = 0; i < 6 && (token != NULL); i++) {
			if(!atoh(token, 1, &FPGA_ID[i])){
				error("Invalid MAC address");
			}
			token = strtok_s(NULL, ":", &next_token);
		}
		//Check to see if there were exactly 6 bytes
		if (i!=6) {
			error("Invalid MAC address");
		}

		cout << "destination MAC: " 
				<< hex << setw(2) << setfill('0') 
				<< setw(2) << (int)FPGA_ID[0] << ":" 
				<< setw(2) << (int)FPGA_ID[1] << ":" 
				<< setw(2) << (int)FPGA_ID[2] << ":" 
				<< setw(2) << (int)FPGA_ID[3] << ":" 
				<< setw(2) << (int)FPGA_ID[4] << ":" 
				<< setw(2) << (int)FPGA_ID[5] << dec << endl;

		//Grab # of datapoints
		numOps = (uint32_t) atoi(argv[2]);
		if ((numOps < 2)) {
			tempStream << "Invalid number of operations: " << (int)numOps << ".  Must be > 1";
			error(tempStream.str());
		}
	} 
	else if(argc == 1){
		cout << "****USING DEFAULT MAC ADDRESS - AA:AA:AA:AA:AA:AA" << endl;
		FPGA_ID[0] = 0xAA;
		FPGA_ID[1] = 0xAA;
		FPGA_ID[2] = 0xAA;
		FPGA_ID[3] = 0xAA;
		FPGA_ID[4] = 0xAA;
		FPGA_ID[5] = 0xAA;
		numOps = min((uint32_t)MAXINPUTDATABYTEADDRESS, (uint32_t)MAXOUTPUTDATABYTEADDRESS);
	}
	else{
		error("Usage: " + (string) argv[0] + " FPGA_MAC_addr num_datapoints");
	}

	cout << "Processor clock speed = " << speed << " MHz" << endl;

	//**** Set up communication with FPGA
	//Create communication object
	ETH_SIRC_P = new ETH_SIRC(FPGA_ID);
	//Make sure that the constructor didn't run into trouble
	if((int) ETH_SIRC_P->getLastError() != 0){
		tempStream << "Constructor failed with code " << (int) ETH_SIRC_P->getLastError();
		error(tempStream.str());
	}

	inputValues = (uint8_t *) malloc(sizeof(uint8_t) * numOps);
	assert(inputValues);
	outputValues = (uint8_t *) malloc(sizeof(uint8_t) * numOps);
	assert(outputValues);

	cout << endl;

	string commandline;
	string command;

	while(cin || run_startup || run_benchmark || blocksizetest_run) {

		if(!run_startup && !run_benchmark && !blocksizetest_run) {
			getline(cin, commandline);
			istringstream iss(commandline);
		
			command	= "";
			arg1	= -1;
			arg2	= -1;
			arg3	= -1,

			iss >> command;
			iss >> arg1;
			iss >> arg2;
			iss >> arg3;
		}

		// === Reset Device ===========================================================================

		if(command == "reset" || (run_startup && (cnt_startup == 0))) {

			cnt_startup++;

			if(!ETH_SIRC_P->sendReset()) {
				tempStream << "- Reset failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}

			// write command to command register (reg 2)
			// note that this command does not actually do anything but it ensures that we don't read the buffer count too early
			if(!ETH_SIRC_P->sendParamRegisterWrite(2, CMD_RESET)) {
				tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}

			// execute command on FPGA
			if(!ETH_SIRC_P->sendRun()) {
				tempStream << "- Run command failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}

			if(!ETH_SIRC_P->waitDone(WAITDONE)) {
				tempStream << "- Wait till done failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}

			// read linkup register
			if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_LINKUP, &readReg)) {
				tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}

			if(readReg) {

				// read buffer count register
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_BUFFERCNT, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// the buffer count register contains the number of words in the buffer (1 word = 2 bytes)
				numInputBytes = readReg*2;

				if(numInputBytes > 0) {
				
					// read the data back
					if(!ETH_SIRC_P->sendRead(0, numInputBytes, outputValues)) {
						tempStream << "Read from FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
						error(tempStream.str());
					}

					cout << "- Received " << getFISType(outputValues[0]) << ":" << endl << endl;

					for(i=0; i < numInputBytes; i+=4) {
						printf("\t0x%02x 0x%02x 0x%02x 0x%02x\n",outputValues[i+3], outputValues[i+2], outputValues[i+1], outputValues[i]);
					}

					cout << endl;

					printDeviceSignature(outputValues[12],outputValues[4],outputValues[5],outputValues[6]);
					printFISStatus(outputValues[2]);

					if(isError(outputValues[2])) {
						printFISError(outputValues[3]);
						cout << "- Link initialization: FAILED!" << endl;
						// retry stratup ...
						cnt_startup--;
					} else {

						// read linkgen register
						if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_LINKGEN, &readReg)) {
							tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
							error(tempStream.str());
						}
		                
						cout << "- Established SATA version " << readReg;
						if(readReg==1) {
							clockfreq = 75;
							cout << " (150 MiB/s)" << endl;
						} else if(readReg==2) {
							clockfreq = 150;
							cout << " (300 MiB/s)" << endl;
						} else if(readReg==3) {
							clockfreq = 150;
							cout << " (600 MiB/s)" << endl;
						}
						
						cout << "- Link initialization: SUCCESS!" << endl;
					}
				}

			} else {

				cout << "- The SATA link could not be initialized: unknown error!" << endl;

			}

		// === Identify ===============================================================================

		} else if(command == "identify" || (run_startup && (cnt_startup == 1))) {

			cnt_startup++;

			// write command to command register (reg 0)
			if(!ETH_SIRC_P->sendParamRegisterWrite(0, CMD_IDENTIFY_DEVICE)) {
				tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}

			// execute command on FPGA
			if(!ETH_SIRC_P->sendRun()) {
				tempStream << "- Run command failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}
			if(!ETH_SIRC_P->waitDone(WAITDONE)) {
				tempStream << "- Wait till done failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}

			// read command error regiseter
			if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_CMD_FAILED, &readReg)) {
				tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
				error(tempStream.str());
			}
			if(readReg) {
				cout << "- SATA HBA reported a COMMAND ERROR!" << endl;
			} else {
				// read buffer count register
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_BUFFERCNT, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// the buffer count register contains the number of words in the buffer (1 word = 2 bytes)
				numInputBytes = readReg*2;

				if(numInputBytes > 0) {
					// read the data back
					if(!ETH_SIRC_P->sendRead(0, numInputBytes, outputValues)) {
						tempStream << "Read from FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
						error(tempStream.str());
					}

					cout << "- Identify Device: 512-byte data structure" << endl << endl;

					for(i=0; i < numInputBytes; i+=2){
						printf("\t0x%02x%02x ",outputValues[i+1],outputValues[i]);
						if((i%16) == 14) {
							cout << endl;
						}
					}
					cout << endl;
				}

				identifySerialNumber(outputValues);
				identifyModelNumber(outputValues);
				identifySATACapabilities(outputValues);
				identifyMaxNum512LBARanges(outputValues);
				identifyTrimSupport(outputValues);
				identify48BitSupport(outputValues);

				isNCQSupported = getNCQSupport(outputValues);
				is48bitAddressingSupported = get48BitSupport(outputValues);
			}

		// === read LBA ===============================================================================

		} else if(command == "read") {

			// --- parse arguments --------------------------------------------------------------------

			if(!is48bitAddressingSupported) {
				cout << "- Error: SSD does not support 48-bit addressing!" << endl;
			} else if(arg1 == -1) {
				cout << "- Error: LBA missing!" << endl;
			} else if(arg2 > 0xFFFF) {
				cout << "- Error: Max sector count = 65535" << endl;
			} else {

				LBA       = arg1;
				LBA_L     = LBA & 0x0000000000FFFFFF;
				LBA_U     = (LBA >> 24) & 0x0000000000FFFFFF;
				SECTORCNT = (arg2 > 0) ? arg2 : 1;

				// write command to command register (reg 0)
				if(!ETH_SIRC_P->sendParamRegisterWrite(0, CMD_READ_DMA_EXTENDED)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write lower LBA to LBA_L register (reg 1)
				if(!ETH_SIRC_P->sendParamRegisterWrite(1, LBA_L)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write upper LBA to LBA_U register (reg 2)
				if(!ETH_SIRC_P->sendParamRegisterWrite(2, LBA_U)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write SECTORCNT to sector count register (reg 3)
				if(!ETH_SIRC_P->sendParamRegisterWrite(3, SECTORCNT)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// execute command on FPGA
				if(!ETH_SIRC_P->sendRun()) {
					tempStream << "- Run command failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				if(!ETH_SIRC_P->waitDone(WAITDONE)) {
					tempStream << "- Wait till done failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// read command error regiseter
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_CMD_FAILED, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				if(readReg) {
					cout << "- SATA HBA reported a COMMAND ERROR!" << endl;
				} else {
					if(SECTORCNT <= 8) {
						// read buffer count register
						if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_BUFFERCNT, &readReg)) {
							tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
							error(tempStream.str());
						}

						// the buffer count register contains the number of words in the buffer (1 word = 2 bytes)
						numInputBytes = readReg*2;

						if(numInputBytes > 0) {
							// read the data back
							if(!ETH_SIRC_P->sendRead(0, numInputBytes, outputValues)) {
								tempStream << "Read from FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
								error(tempStream.str());
							}

							printf("\n\t%d sector%s starting at LBA %d:\n\n", SECTORCNT, (SECTORCNT>1)?"s":"", LBA);

							for(i=0; i < numInputBytes; i+=2){
								printf("\t0x%02x%02x ",outputValues[i+1],outputValues[i]);
								if((i%16) == 14) {
									cout << endl;
								}
							}
							cout << endl;
						}
					} else {
						cout << "- read from LBA " << LBA << " (SECTOR COUNT = " << SECTORCNT << ") successful!" << endl;
						cout << "- Cannot display more than 8 sectors!" << endl;
					}
				}
			}

		// === write LBA ==============================================================================

		} else if(command == "write") {

			// --- parse arguments --------------------------------------------------------------------

			if(!is48bitAddressingSupported) {
				cout << "- Error: SSD does not support 48-bit addressing!" << endl;
			} else if(arg1 == -1) {
				cout << "- Error: LBA missing!" << endl;
			} else if(arg2 > 0xFFFF) {
				cout << "- Error: Max sector count = 65535" << endl;
			} else {

				if(arg2 > 16) {
				  cout << "- Warning: buffer size on FPGA = 16 sectors (8 KiB), data will be written repeatedly!" << endl;
				}

				LBA       = arg1;
				LBA_L     = LBA & 0x0000000000FFFFFF;
				LBA_U     = (LBA >> 24) & 0x0000000000FFFFFF;
				SECTORCNT = (arg2 > 0)  ? arg2 : 1;
				PATTERN   = arg3;

				// write command to command register (reg 0)
				if(!ETH_SIRC_P->sendParamRegisterWrite(0, CMD_WRITE_DMA_EXTENDED)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write lower LBA to LBA_L register (reg 1)
				if(!ETH_SIRC_P->sendParamRegisterWrite(1, LBA_L)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write upper LBA to LBA_U register (reg 2)
				if(!ETH_SIRC_P->sendParamRegisterWrite(2, LBA_U)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write SECTORCNT to sector count register (reg 3)
				if(!ETH_SIRC_P->sendParamRegisterWrite(3, SECTORCNT)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

			    // write pattern to 4 KiB input buffer
				numOutputBytes = (SECTORCNT < 8) ? SECTORCNT : 8;
				for(j=0; j<numOutputBytes*256; j++) {
					if(PATTERN==(-1)) {
						inputValues[j*2]   = (uint8_t) (j & 0xFF);
						inputValues[j*2+1] = (uint8_t) ((j>>8) & 0xFF);
					} else {
						inputValues[j*2]   = (uint8_t) (PATTERN & 0xFF);
						inputValues[j*2+1] = (uint8_t) ((PATTERN>>8) & 0xFF);
					}
				}

				// write data to input buffer on FPGA
				if(!ETH_SIRC_P->sendWrite(0, numOutputBytes*512, inputValues)){
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// execute on FPGA
				if(!ETH_SIRC_P->sendRun()){
					tempStream << "- Run command failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				if(!ETH_SIRC_P->waitDone(WAITDONE)){
					tempStream << "- Wait till done failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// read command error regiseter
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_NO_CMD_FAILED, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				if(readReg) {
					cout << "- SATA HBA reported a COMMAND ERROR!" << endl;
				} else {
					cout << "- write to LBA " << LBA << " successful!" << endl;
				}

			}

		// === writeseq ===============================================================================

		} else if(command == "writeseq" || (run_benchmark && cnt_benchmark == 0) || (blocksizetest_run && (blocksizetest_sectorcnt < 65536) && blocksizetest_write && blocksizetest_seqaccess)) {

			if(run_benchmark) {
			  cnt_benchmark++;
			}

			if(!is48bitAddressingSupported) {
				cout << "- Error: SSD does not support 48-bit addressing!" << endl;
			} else if(clockfreq == 0) {
				cout << "- Error: Type 'reset' first to get clock frequency!" << endl;
			} else if((arg1 != -1) && arg1 > (1 << 14)) {
				cout << "- Error: Max number of LBAs = " << (1 << 14) << endl;
			} else if(arg2 > 0xFFFF) {
				cout << "- Error: Max sector count = 65528" << endl;
			} else {

				// --- parse arguments --------------------------------------------------------------------

				if(run_benchmark) {
					if(testssd) {
					  numblocks = 256;
					} else {
					  numblocks = 128;
					}
					blocksize	= 2048;
					useNCQ		= 0;
				} else if(blocksizetest_run) {
					useNCQ              = 0;
					numblocks           = blocksizetest_numaccesses;
					blocksize           = blocksizetest_sectorcnt;
					blocksizetest_write = false;
				} else {
					numblocks	= (arg1 != (-1)) ? arg1	: NUMBLOCKS;
					blocksize	= (arg2 > 0)	 ? arg2	: BLOCKSIZE;
					useNCQ		= (arg3 == 1)	 ? 1    : 0;
				}

				// --- generate LBA.txt file --------------------------------------------------------------

				// open output file
				ofstream outfile ("LBAs.txt", ios::binary);

				// compute shift of block
				blocksize_shift = 0;
				blocksize_tmp   = blocksize;
				if(blocksize_tmp>1) {
					do{blocksize_shift++;} while(!((blocksize_tmp>>=1) & 0x1));
				}

				// compute numblocks LBAs
				for(j=0; j<numblocks; j++) {

					// compute the LBA
					LBA = (j << blocksize_shift);

					lba[0] = LBA >> 0 & 0xFF;
					lba[1] = LBA >> 8 & 0xFF;
					lba[2] = LBA >> 16 & 0xFF;
					lba[3] = LBA >> 24 & 0xFF;

					outfile << lba[0];
					outfile << lba[1];
					outfile << lba[2];
					outfile << lba[3];
				}

				// close output file
				outfile.close();

				// --- do benchmark -----------------------------------------------------------------------

				// write command to command register (reg 0)
				if(!ETH_SIRC_P->sendParamRegisterWrite(0, (useNCQ) ? CMD_BENCHMARK_WRITE_NCQ : CMD_BENCHMARK_WRITE_DMA)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write SECTORCNT to sector count register (reg 3)
				if(!ETH_SIRC_P->sendParamRegisterWrite(3, blocksize)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}


				// write LBAs to input memory
				ifstream infile  ("LBAs.txt", ios::binary); 

				j = 0;
				while(!infile.eof()) {

					char buffer[4];
					infile.read(buffer,4);
					for(i=0; i<4; i++) {
						lba[i] = buffer[i];
					}

					if(!infile.eof()) {

#ifdef DEBUGINFO
						LBA	= lba[0] | (lba[1]<<8) | (lba[2]<<16) | (lba[3]<<24);
						printf("- LBA (SW) = %010lld (0x%016llx)\n", LBA, LBA);
#endif

						inputValues[j*4+0] = lba[0];
						inputValues[j*4+1] = lba[1];
						inputValues[j*4+2] = lba[2];
						inputValues[j*4+3] = lba[3];

						j++;
					}
				}

				//write number of 16-bit words in input memory into reg 4
				if(!ETH_SIRC_P->sendParamRegisterWrite(4,j*2)){
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write data to input buffer on FPGA
				if(!ETH_SIRC_P->sendWrite(0, j*4, inputValues)){
			 		tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
			 		error(tempStream.str());
				}

				start = getTime();

				// execute on FPGA
				if(!ETH_SIRC_P->sendRun()){
					tempStream << "- Run command failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				if(!ETH_SIRC_P->waitDone(WAITDONE)){
					tempStream << "- Wait till done failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				
				end = getTime();

				if(run_benchmark) {
					cout << endl << "- --- Write Seq DMA --------------------------------------------------" << endl << endl;
				}

				// get number of SATA erros
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_SATA_ERRORS, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				cout << "- SATA errors\t= " << readReg << endl;

				// read clock tick coung
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_CLKTICKCNT_U, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				total_clk_cnt = readReg;
				total_clk_cnt = total_clk_cnt << 32;

				if(!ETH_SIRC_P->sendParamRegisterRead(REG_CLKTICKCNT_L, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				total_clk_cnt += readReg;

				period           = (double)1000/(double)clockfreq;
                total_accesstime = period*(double)total_clk_cnt/1000000.0;
				total_data       = ((double)j*blocksize)/2.0;
				throughput       = (double)total_data/(double)total_accesstime; // KiB/ms
				throughput       = throughput*1000.0/1024.0; // MiB/s

				if(blocksizetest_run) {
					printf("- # writes\t= %d\n",                              numblocks);
					printf("- write size\t= %.1f [KiB]\n",                    (double)blocksize/2.0);
					printf("- write speed\t= %.3f [MiB/s]\n",                 throughput);
				} else {
					printf("- # writes\t= %d\n",                              numblocks);
					printf("- write size\t= %.1f [KiB]\n",                    (double)blocksize/2.0);
					printf("- tick count\t= %llu\n",                          total_clk_cnt);
					printf("- clock freq.\t= %d [MHz]\n",                     clockfreq);
					printf("- time\t\t= %.3f [ms] (FPGA), %.3f [ms] (CPU)\n", total_accesstime,(float)(end-start)/10000.0);
					printf("- data\t\t= %.1f [KiB]\n",                        total_data);
					printf("- throughput\t= %.3f [MiB/s]\n",                  throughput);
				}

			}

		// === writernd ===============================================================================

		} else if(command == "writernd" || (run_benchmark && (cnt_benchmark == 2 || (isNCQSupported && cnt_benchmark == 4)))|| (blocksizetest_run && (blocksizetest_sectorcnt < 65536) && blocksizetest_write && !blocksizetest_seqaccess)) {

			if(run_benchmark) {
			  cnt_benchmark++;
			}

			if(!is48bitAddressingSupported) {
				cout << "- Error: SSD does not support 48-bit addressing!" << endl;
			} else if(clockfreq == 0) {
				cout << "- Error: Type 'reset' first to get clock frequency!" << endl;
			} else if((arg1 != -1) && arg1 > (1 << 14)) {
				cout << "- Error: Max number of LBAs = " << (1 << 14) << endl;
			} else if(arg2 > 0xFFFF) {
				cout << "- Error: Max sector count = 65535" << endl;
			} else {

				// --- parse arguments --------------------------------------------------------------------

				if(run_benchmark) {
					if(testssd) {
					  numblocks = 16384;
					} else {
					  numblocks = 256;
					}
					blocksize = 8;
					if(cnt_benchmark==5) {
					  useNCQ = 1;
					} else {
					  useNCQ = 0;
					}
				} else if(blocksizetest_run) {
					useNCQ              = 0;
					numblocks           = blocksizetest_numaccesses;
					blocksize           = blocksizetest_sectorcnt;
					blocksizetest_write = false;
				} else {
					numblocks	= (arg1 != (-1)) ? arg1	: NUMBLOCKS;
					blocksize	= (arg2 > 0)	 ? arg2	: BLOCKSIZE;
					useNCQ		= (arg3 == 1)	 ? 1    : 0;
				}

				// --- generate LBA.txt file --------------------------------------------------------------

				LBA_array = (uint32_t*) calloc(numblocks, sizeof(uint32_t));

				// compute shift of block
				blocksize_shift = 0;
				blocksize_tmp   = blocksize;
				if(blocksize_tmp>1) {
					do{blocksize_shift++;} while(!((blocksize_tmp>>=1) & 0x1));
				}

				// compute numblocks consecutive LBAs
				for(j=0; j<numblocks; j++) {
					// add 1 MiB gap between blocks :  j << 11
					if(cnt_benchmark == 3){
					  LBA_array[j] = (1 << 25) | (j << 10);
					} else if(cnt_benchmark == 5) {
					  LBA_array[j] = (1 << 26) | (j << 10);
					} else {
					  LBA_array[j] = j << 11;
					}
				}

				// Knuth shuffle
				uint32_t posx;
				uint32_t temp;
				for(i=numblocks-1; i>1; i--) {
					posx = rand()%(i+1);
					temp = LBA_array[posx];
					LBA_array[posx] = LBA_array[i];
					LBA_array[i] = temp;
				}

				// open output file
				ofstream outfile ("LBAs.txt", ios::binary);

				for(j=0; j<numblocks; j++) {
					lba[0] = LBA_array[j] >> 0 & 0xFF;
					lba[1] = LBA_array[j] >> 8 & 0xFF;
					lba[2] = LBA_array[j] >> 16 & 0xFF;
					lba[3] = LBA_array[j] >> 24 & 0x0F;

					outfile << lba[0];
					outfile << lba[1];
					outfile << lba[2];
					outfile << lba[3];
				}

				// close output file
				outfile.close();
				free(LBA_array);

				// --- do benchmark -----------------------------------------------------------------------

				// write command to command register (reg 0)
				if(!ETH_SIRC_P->sendParamRegisterWrite(0, (useNCQ) ? CMD_BENCHMARK_WRITE_NCQ : CMD_BENCHMARK_WRITE_DMA)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write SECTORCNT to sector count register (reg 3)
				if(!ETH_SIRC_P->sendParamRegisterWrite(3, blocksize)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}


				// write LBAs to input memory
				ifstream infile  ("LBAs.txt", ios::binary); 

				j = 0;
				while(!infile.eof()) {

					char buffer[4];
					infile.read(buffer,4);
					for(i=0; i<4; i++) {
						lba[i] = buffer[i];
					}

					if(!infile.eof()) {

#ifdef DEBUGINFO
						LBA	= lba[0] | (lba[1]<<8) | (lba[2]<<16) | (lba[3]<<24);
						printf("- LBA (SW) = %010lld (0x%016llx)\n", LBA, LBA);
#endif

						inputValues[j*4+0] = lba[0];
						inputValues[j*4+1] = lba[1];
						inputValues[j*4+2] = lba[2];
						inputValues[j*4+3] = lba[3];

						j++;
					}
				}

				//write number of 16-bit words in input memory into reg 4
				if(!ETH_SIRC_P->sendParamRegisterWrite(4,j*2)){
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write data to input buffer on FPGA
				if(!ETH_SIRC_P->sendWrite(0, j*4, inputValues)){
			 		tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
			 		error(tempStream.str());
				}

				start = getTime();

				// execute on FPGA
				if(!ETH_SIRC_P->sendRun()){
					tempStream << "- Run command failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				if(!ETH_SIRC_P->waitDone(WAITDONE)){
					tempStream << "- Wait till done failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				end = getTime();

				if(run_benchmark && !useNCQ) {
					cout << endl << "- --- Write Rnd DMA --------------------------------------------------" << endl << endl;
				} else if(run_benchmark && useNCQ) {
					cout << endl << "- --- Write Rnd NCQ --------------------------------------------------" << endl << endl;
				}

				// get number of SATA erros
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_SATA_ERRORS, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				cout << "- SATA errors\t= " << readReg << endl;

				// read clock tick coung
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_CLKTICKCNT_U, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				total_clk_cnt = readReg;
				total_clk_cnt = total_clk_cnt << 32;

				if(!ETH_SIRC_P->sendParamRegisterRead(REG_CLKTICKCNT_L, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				total_clk_cnt += readReg;

				period           = (double)1000/(double)clockfreq;
                total_accesstime = period*(double)total_clk_cnt/1000000.0;
				total_data       = ((double)j*blocksize)/2.0;
				throughput       = (double)total_data/(double)total_accesstime; // KiB/ms
				throughput       = throughput*1000.0/1024.0; // MiB/s


				if(blocksizetest_run) {
					printf("- # writes\t= %d\n",                              numblocks);
					printf("- write size\t= %.1f [KiB]\n",                    (double)blocksize/2.0);
					printf("- write speed\t= %.3f [MiB/s]\n",                 throughput);
				} else {
					printf("- # writes\t= %d\n",                              numblocks);
					printf("- write size\t= %.1f [KiB]\n",                    (double)blocksize/2.0);
					printf("- tick count\t= %llu\n",                          total_clk_cnt);
					printf("- clock freq.\t= %d [MHz]\n",                     clockfreq);
					printf("- time\t\t= %.3f [ms] (FPGA), %.3f [ms] (CPU)\n", total_accesstime,(float)(end-start)/10000.0);
					printf("- data\t\t= %.1f [KiB]\n",                        total_data);
					printf("- throughput\t= %.3f [MiB/s]\n",                  throughput);
				}

			}

		// === readback ===============================================================================

		} else if(command == "readback" || (run_benchmark && ((cnt_benchmark == 1) || (cnt_benchmark == 3) || (isNCQSupported && cnt_benchmark == 5))) || (blocksizetest_run && (blocksizetest_sectorcnt < 65536))) {
			
			if(run_benchmark) {
			  cnt_benchmark++;
			}

			if(!is48bitAddressingSupported) {
				cout << "- Error: SSD does not support 48-bit addressing!" << endl;
			} else if(clockfreq == 0) {
				cout << "- Error: Type 'reset' first to get clock frequency!" << endl;
			} else if(arg1 != (-1) && arg1 > 0xFFFF) {
				cout << "- Error: Max sector count = 65535" << endl;
			} else {

				// --- parse arguments --------------------------------------------------------------------

				if(run_benchmark) {
					if(cnt_benchmark == 2) {
						blocksize	= 2048;
						useNCQ		= 0;
					} else if(cnt_benchmark == 4) {
						blocksize	= 8;
						useNCQ		= 0;
					} else if(cnt_benchmark == 6) {
						blocksize	= 8;
						useNCQ		= 1;
					}

				} else if(blocksizetest_run) {

					useNCQ    = 0;
					blocksize = blocksizetest_sectorcnt;

					if(blocksizetest_sectorcnt > 64) blocksizetest_numaccesses /=2;
					blocksizetest_sectorcnt = blocksizetest_sectorcnt+blocksizetest_sectorcnt;
					if(blocksizetest_sectorcnt == 65536) blocksizetest_sectorcnt -= 8;
					blocksizetest_write = true;

				} else {
				  blocksize	= (arg1 != (-1)) ? arg1	: BLOCKSIZE;
				  useNCQ	= (arg2 == 1)	 ? 1    : 0;
				}

				// --- do benchmark -----------------------------------------------------------------------

				// write command to command register (reg 0)
				if(!ETH_SIRC_P->sendParamRegisterWrite(0, (useNCQ) ? CMD_BENCHMARK_READ_NCQ : CMD_BENCHMARK_READ_DMA)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write SECTORCNT to sector count register (reg 3)
				if(!ETH_SIRC_P->sendParamRegisterWrite(3, blocksize)) {
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write LBAs to input memory
				ifstream infile  ("LBAs.txt", ios::binary); 

				j = 0;
				while(!infile.eof()) {

					char buffer[4];
					infile.read(buffer,4);
					for(i=0; i<4; i++) {
						lba[i] = buffer[i];
					}

					if(!infile.eof()) {
#ifdef DEBUGINFO
						LBA	= lba[0] | (lba[1]<<8) | (lba[2]<<16) | (lba[3]<<24);
						printf("- LBA (SW) = %010lld (0x%016llx)\n", LBA, LBA);
#endif

						inputValues[j*4+0] = lba[0];
						inputValues[j*4+1] = lba[1];
						inputValues[j*4+2] = lba[2];
						inputValues[j*4+3] = lba[3];

						j++;
					}
				}

				//write number of 16-bit words in input memory into reg 4
				if(!ETH_SIRC_P->sendParamRegisterWrite(4,j*2)){
					tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				// write data to input buffer on FPGA
				if(!ETH_SIRC_P->sendWrite(0, j*4, inputValues)){
			 		tempStream << "Write to FPGA failed with code " << (int) ETH_SIRC_P->getLastError();
			 		error(tempStream.str());
				}

				start = getTime();

				// execute on FPGA
				if(!ETH_SIRC_P->sendRun()){
					tempStream << "- Run command failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				if(!ETH_SIRC_P->waitDone(WAITDONE)){
					tempStream << "- Wait till done failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				end = getTime();

				if(cnt_benchmark == 2) {
					cout << endl << "- --- Read Seq DMA ---------------------------------------------------" << endl << endl;
				} else if(cnt_benchmark >= 4 && !useNCQ) {
					cout << endl << "- --- Read Rnd DMA ---------------------------------------------------" << endl << endl;
				} else if(cnt_benchmark >= 4 && useNCQ) {
					cout << endl << "- --- Read Rnd NCQ ---------------------------------------------------" << endl << endl;
				}

				// get number of SATA erros
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_SATA_ERRORS, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				cout << "- SATA errors\t= " << readReg << endl;

				// get number of data erros
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_DATA_ERRORS, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}

				cout << "- Data errors\t= " << readReg << endl;

				// read clock tick coung
				if(!ETH_SIRC_P->sendParamRegisterRead(REG_CLKTICKCNT_U, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				total_clk_cnt = readReg;
				total_clk_cnt = total_clk_cnt << 32;

				if(!ETH_SIRC_P->sendParamRegisterRead(REG_CLKTICKCNT_L, &readReg)) {
					tempStream << "- Parameter register write failed with code " << (int) ETH_SIRC_P->getLastError();
					error(tempStream.str());
				}
				total_clk_cnt += readReg;

				period           = (double)1000/(double)clockfreq;
                total_accesstime = period*(double)total_clk_cnt/1000000.0;
				total_data       = ((double)j*blocksize)/2.0;
				throughput       = (double)total_data/(double)total_accesstime; // KiB/ms
				throughput       = throughput*1000.0/1024.0; // MiB/s

				if(blocksizetest_run) {
					printf("- read speed\t= %.3f [MiB/s]\n", throughput);
					cout << endl << "- --------------------------------------------------------------------" << endl << endl;
				} else {
					printf("- # reads\t= %d\n",                              j);
					printf("- read size\t= %.1f [KiB]\n",                    (double)blocksize/2.0);
					printf("- tick count\t= %llu\n",                          total_clk_cnt);
					printf("- clock freq.\t= %d [MHz]\n",                     clockfreq);
					printf("- time\t\t= %.3f [ms] (FPGA), %.3f [ms] (CPU)\n", total_accesstime,(float)(end-start)/10000.0);
					printf("- data\t\t= %.1f [KiB]\n",                        total_data);
					printf("- throughput\t= %.3f [MiB/s]\n",                  throughput);
				}

			}

		} else if(command == "benchmark" || (run_benchmark && cnt_benchmark == 6)) {
			
			if(!is48bitAddressingSupported) {
				cout << "- Error: SSD does not support 48-bit addressing!" << endl;
			} else {
				if(arg1 == 0) {
				  testssd = false;
				} else {
				  testssd = true;
				}

				if(run_benchmark) {
				  run_benchmark = false;
				} else {
				  run_benchmark = true;
				  cnt_benchmark = 0;
				}
			}

		/*
		} else if(command == "seqaccess" || command == "rndaccess" || blocksizetest_run) {
			
			if(!is48bitAddressingSupported) {
				cout << "- Error: SSD does not support 48-bit addressing!" << endl;
			} else {
				if(blocksizetest_run) {
					blocksizetest_run = false;
				} else {
					blocksizetest_run         = true;
					blocksizetest_write       = true;
					blocksizetest_sectorcnt   = 1;
					blocksizetest_numaccesses = 16384;

					blocksizetest_seqaccess = (command == "seqaccess") ? true : false;

					cout << endl << "- --------------------------------------------------------------------" << endl << endl;
				}
			}
		*/

		// === Print possible commands ================================================================

		} else if(command == "help" || run_startup) {
			
			run_startup = false;

			cout << endl;
			cout << "SIRC interface to SATA HBA (Groundhog)" << endl << endl;
			cout << "usage: command [options]" << endl << endl;
			cout << "Commands:" << endl;
			cout << "- reset" << endl;
			cout << "- identify" << endl;
			cout << "- read\t\tLBA\t\t?SECTORCNT(default:1)" << endl;
			cout << "- write\t\tLBA\t\t?SECTORCNT(default:1)\t?2BYTEPATTERN(default:repeat0-(2^16-1))" << endl;
			cout << "- writeseq\t?numblocks\t?blocksize ?NCQ" << endl;
			cout << "- writernd\t?numblocks\t?blocksize ?NCQ" << endl;
			cout << "- readback\t?blocksize\t?NCQ" << endl;
			cout << "- benchmark\t?testsdd(default:1)" << endl;
			//cout << "- seqaccess" << endl;
			//cout << "- rndaccess" << endl;

		// === Quit program ===========================================================================

		} else if(command == "exit") {
			break;

		// === Command unknown ========================================================================
		
		} else {
			cout << "> Sorry, this command does not exist" << endl;
		}

		if(!run_benchmark && !run_startup && !blocksizetest_run){
		  cout << "> ";
		}
	}

	delete ETH_SIRC_P;
	free(inputValues);
	free(outputValues);

	return 0;
}