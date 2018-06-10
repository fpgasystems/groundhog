// Title: ETH_SIRC class definition
// 
// Description: Read and write to input/output buffers and parameter register file.  Also, 
// start execution, wait until execution is completed and (maybe) reconfigure the
// device via SystemACE or iMPACT.
//
// Based on ENIC code from MSR Giano
//
// Copyright: Microsoft 2009
//
// Author: Ken Eguro
//
// Created: 10/23/09 
//
// Version: 1.00
// 
// 
// Changelog: 
//
//----------------------------------------------------------------------------

#include "include.h"

//If you would like to configure using iMPACT and an external programmer, fill in these constants
//If not, comment out these constants.
//#define IMPACTCONFIG
//Where is the iMPACT executable?
#define PATHTOIMPACT "C:\\Xilinx\\10.1\\ISE\\bin\\nt64\\impact.exe"
//Where is the file with the template batch commands for iMPACT?
#define PATHTOIMPACTTEMPLATEBATCHFILE "impactBatchTemplate.cmd"
//Where would the user like to store the programming batch file for iMPACT?
#define PATHTOIMPACTPROGRAMMINGBATCHFILE "impactBatch.cmd"
//We would like to redirect the stdout when iMPACT runs.  Where would the user like to put it?
#define PATHTOIMPACTPROGRAMMINGOUTPUTFILE "impact.out"
//What phrase should we look for to determine if iMPACT successfully programmed the chip?
#define IMPACTSUCCESSPHRASE "\'5\': Programmed successfully."

//If you would like to configure from the CompactFlash card attach to the SystemACE, define this
// constant
//#define SYSACECONFIG

//#define DEBUG
//#define BIGDEBUG

//******Constants we should change based upon the setup of the hardware-side API
//How many bytes are in the input data buffer?
//The default value is 128KB
//#define MAXINPUTDATABYTEADDRESS (1024 * 128)
#define MAXINPUTDATABYTEADDRESS (8192 * 32)

//How many bytes are in the output data buffer?
//The default value is 8KB
//#define MAXOUTPUTDATABYTEADDRESS (1024 * 16)
#define MAXOUTPUTDATABYTEADDRESS (32768 * 32)

//******These error codes we expect to be returned from the ETH_SIRC functions from time to time.
//		These occur if the user presents invalid data, if the user's machine is not configured correctly,
//			if there is something wrong with the connection between the PC and the FPGA, or if there is 
//			something wrong with the FPGA itself.
//Conditions that might occur when the constructor is called
//Check to see if the Virtual Machine Network Services driver is installed
#define FAILVMNSDRIVERPRESENT -1
//Check to see if the Virtual Machine Network Services driver is active on any adapter
#define FAILVMNSDRIVERACTIVE -2
//The Virtual Machine Network Services driver can't seem to be set to the correct MAC filtering
#define FAILVMNSDRIVERFILTER -3
//The Virtual Machine Network Services driver can't seem to get a MAC address
#define FAILVMNSDRIVERMACADD -4
//The Virtual Machine Network Services driver can't seem to get a completion port
#define FAILVMNSDRIVERCOMPLETION -5
//The ETH_SIRC constructor was fed an invalid FPGA target MAC address
#define INVALIDFPGAMACADDRESS -6
//The ETH_SIRC constructor could not contact the target FPGA - check the network cable and target MAC address
#define FAILINITIALCONTACT -7

//Conditions that might occur any time a communication function is called
//We have run out of free memory and an allocation failed
#define FAILMEMALLOC -8
//The last command was called with an invalid buffer
//For sendWriteAndRun it could refer to either inData or outData
#define INVALIDBUFFER -9
//The last command was called with an invalid start/register/SystemACE address
#define INVALIDADDRESS -10
//The last command was called with an invalid length
//For sendWriteAndRun it could refer to either inLength or maxOutLength
#define INVALIDLENGTH -11

//Valid for sendWrite, sendParamRegisterWrite, and sendWriteAndRun
//We didn't seem to get a timely acknowledgment from the write command we sent, even after retries
//If this is returned after the sendWriteAndRun command, the user should 
// re-evaulate the expected runtime of their circuit and possibly increase the timeout.
//If that does not work, there is likely a physical problem.  Make sure that the sendWrite
// function works.
#define FAILWRITEACK -12

//Valid for sendRead, sendParamRegisterRead
//We didn't seem to get a timely acknowledgment from the read command we sent, even after retries
#define FAILREADACK -13

//Valid for sendWriteAndRun
//The output buffer was too small for the amount of results data the circuit
//		produced.
//If this occurs, the returned outputLength will not be the number of bytes returned, but rather the 
//		total number of bytes the execution phase wanted to return (the number of bytes actually returned 
//		will be maxOutLength).  The user can then simply read the “overflow” bytes from addresses 
//		{maxOutLength, outputLength-1} manually with a subsequent sendRead command.
#define FAILWRITEANDRUNCAPACITY 14

//Valid for sendWriteAndRun
//The write and execute phases occured correctly, but we had to retry the readback phase too many times.
//		The returned outputLength will not be the number of bytes returned, but rather the 
//		total number of bytes the execution phase wanted to return.  The state of outData is unknown,
//		but some data has been partially written.
//		In theory, the user could use this information to try a subsequent call to sendRead from {0, outputLength-1}.
//		This option may be attractive if calling sendWriteAndRun is not easy.  For example, 
//		if inData and outData point to an overlapping region, it may be simpler to try and 
//		re-read outData rather than recreating inData so that execution can be attempted again.
#define FAILWRITEANDRUNREADACK 15

//Valid for waitDone
//The waitDone request was not acknowledged.  This is different than merely timing out,
// we asked the FPGA about the done signal and got no response.
#define FAILWAITACK -16

//Valid for waitDone
//The waitDone request was acknowledged, but it did not lower within the allotted time.
//Either something is wrong with the circuit on the FPGA or the user should
// re-evaulate the expected runtime of their circuit and possibly increase the timeout.
//If a subseqent call to waitDone doesn't return true, sendReset is always an option.
#define FAILDONE 17

//Valid for sendReset
//The sendReset command was not acknowledged, even after retries
#define FAILRESETACK -18

//Valid for sendConfiguration
//The sendConfiguration command was not acknowledged, even after retries
#define FAILCONFIGURATIONACK -19

//Valid for sendConfiguration
//After sending the sendConfiguration command we cannot re-contact the FPGA
#define FAILCONFIGURATIONRETURN -20

//Valid for sendConfiguration using iMPACT
//The function for programming via iMPACT was called, but one of the constants was not defined
//Check to make sure that IMPACT, PATHTOIMPACT, PATHTOIMPACTTEMPLATEBATCHFILE, PATHTOIMPACTPROGRAMMINGBATCHFILE, 
//		PATHTOIMPACTPROGRAMMINGOUTPUTFILE, and IMPACTSUCCESSPHRASE are defined below.
#ifdef IMPACTCONFIG
#define FAILIMPACTCONSTANTDEFINE -21

//Valid for sendConfiguration using iMPACT
//Could not find iMPACT executable
#define FAILPATHTOIMPACT -22

//Valid for sendConfiguration using iMPACT
//Could not find iMPACT batch template command file
#define FAILPATHTOIMPACTTEMPLATEBATCHFILE -23

//Valid for sendConfiguration using iMPACT
//There is not exactly 1 instance of BITSTREAMFILENAME in the batch template command file
#define FAILIMPACTTEMPLATEBATCHFILE -24

//Valid for sendConfiguration using iMPACT
//Could not open iMPACT batch programming command file for writing
#define FAILPATHTOIMPACTPROGRAMMINGBATCHFILE -25

//Valid for sendConfiguration using iMPACT
//Could not open iMPACT output file either for reading or writing
#define FAILPATHTOIMPACTPROGRAMMINGSOUTPUTFILE -26

//Valid for sendConfiguration using iMPACT
//Function was not passed a valid bitstream path
#define FAILCONFIGURATIONBITSTREAM 27

//Valid for sendConfiguration using iMPACT
//iMPACT did not program the FPGA successfully
//Check the impact output file for details.
#define FAILCONFIGURATIONIMPACT -28
#endif

//Valid for sendSystemACERegisterRead - currently unused
//The sendSystemACERegisterRead was not acknowledged
#ifdef SYSACERW
#define FAILSYSACEREADACK -29

//Valid for sendSystemACERegisterWrite - currently unused
//The sendSystemACERegisterWrite was not acknowledged
#define FAILSYSACEWRITEACK -30
#endif

//******These error codes should not be returned.  If they do, something is wrong in the API code.
//		Please send me mail with details regarding the conditions under which this occurred.
#define FAILVMNSCOMPLETION -100
#define INVALIDWRITETRANSMIT -101
#define INVALIDREADTRANSMIT -102
#define INVALIDPARAMWRITETRANSMIT -103
#define INVALIDPARAMREADTRANSMIT -104
#define FAILREADMISSING -105
#define INVALIDRESETTRANSMIT -106
#ifdef SYSACECONFIG
#define INVALIDSYSACECONFIGTRANSMIT -107
#endif
#ifdef SYSACERW
#define INVALIDSYSACEREADTRANSMIT -108
#define INVALIDSYSACEWRITETRANSMIT -109
#endif
#define INVALIDWRITEANDRUNTRANSMIT -110
#define INVALIDWRITEANDRUNRECIEVE -111

//******These are constants that should only be changed if the network protocol changes
//			(ie we want to support jumbo frames and have updated the hardware-side API controller
//			to accomodate that.
//This is the maximum packet size (entire packet including header)
#define MAXPACKETSIZE 1500

//This is the maximum packet payload size (entire packet minus header)
//Should be between 10 and 1486 for normal packets
#define MAXPACKETDATASIZE 1486

//This should be the maximum packet data size minus 9 for the write command, start address and length
#define MAXWRITESIZE (MAXPACKETDATASIZE - 9)
//This should be the maximum packet data size minus 5 for the read command and start address
#define MAXREADSIZE (MAXPACKETDATASIZE - 5)

//******These are constants that can be used to tune the performance of the API
//This is the number of packets we queue up on the completion port.
//Raising this number can reduce dropped packets and improve receive bandwidth, at the expense of a 
// somwhat larger memory footprint for the API.
//Raising it might be a good idea if we expect the CPU load of the system to 
// be high when we are transmitting and receiving with the FPGA, or if the
// speed of the CPU itself is somewhat marginal.
#define DEFAULT_RECEIVE_SIZE 400

//This is the number of writes we might send out before checking to see if any were acknowledged
//Raising this number somewhat can improve transmission bandwidth, at the expense of a somewhat
//	larger memory footprint for the API.
//This number should be smaller than DEFAULT_RECEIVE_SIZE
#define NUMOUTSTANDINGWRITES 250

//Maximum number of times we will try to re-send a given request or command before giving up.
//If the other factors are set correctly and there is no hardware problem in the system
// we should not need to increase this.
//Applies to sendWrite, sendRead, sendParamRegisterWrite, sendParamRegisterRead, sendRun
// and sendWriteAndRun.
//Does not apply to waitDone (has own explicit timeout).
#define MAXRETRIES 3

//Number of milliseconds we will wait between valid write acks before declaring 
// that an outstanding write packet has not been successful.
//Notice, the entire write does not have to be completed in this time, but we should
// not have to wait more than N milliseconds before we see the first ack, nor more than
// N milliseconds between acks.
//This number should not be reduced below 1000.
//Applies to sendWrite and sendParamRegisterWrite
//Also applies during write phase of sendWriteAndRun
//#define WRITETIMEOUT 2000
#define WRITETIMEOUT 2000

//Number of milliseconds we will wait between valid read responses before declaring 
// that an outstanding read request has not been successful.
//Notice, the entire read does not have to be completed in this time, but we should
// not have to wait more than N milliseconds before we see the first response, nor more than
// N milliseconds between responses.
//This number should not be reduced below 1000.
//Applies to sendRead and sendParamRegisterRead
//Also applies during readback phase of sendWriteAndRun
//#define READTIMEOUT 2000
#define READTIMEOUT 2000

class ETH_SIRC{
public:
	//Constructor for the class
	//FPGA_ID: 6 byte array containing the MAC adddress of the destination FPGA
	//	This should be arranged big-endian (MSB of MAC address is array[0]).
	//	It has been done this way since most people like to read left to right {MSB, .. , LSB}
	//Check error code with getLastError() to make certain constructor
	// succeeded fully.
	ETH_SIRC(uint8_t *FPGA_ID);
	//Destructor for the class
	~ETH_SIRC();

	//Send a block of data to an input buffer on the FPGA
	// startAddress: local address on FPGA input buffer to begin writing at
	// length: # of bytes to write
	// buffer: data to be sent to FPGA
	//Returns true if write is successful.
	//If write fails for any reason, returns false.
	// Check error code with getLastError().
	BOOL sendWrite(uint32_t  startAddress, uint32_t  length, uint8_t *buffer);
	//Read a block of data from the output buffer of the FPGA
	// startAddress: local address on FPGA output buffer to begin reading from
	// length: # of bytes to read
	// buffer: data received from FPGA  
	//Returns true if read is successful.
	//If read fails for any reason, returns false.
	// Check error code with getLastError().
	BOOL sendRead(uint32_t startAddress, uint32_t length, uint8_t *buffer);

	//Send a 32-bit value from the PC to the parameter register file on the FPGA
	// regNumber: register to which value should be sent (between 0 and 254)
	// value: value to be written
	//Returns true if write is successful.
	//If write fails for any reason, returns false.
	// Check error code with getLastError()
	BOOL sendParamRegisterWrite(uint8_t regNumber, uint32_t value);
	//Read a 32-bit value from the parameter register file on the FPGA back to the PC
	// regNumber: register to which value should be read (between 0 and 254)
	// value: value received from FPGA
	//Returns true if read is successful.
	//If read fails for any reason, returns false.
	// Check error code with getLastError().
	BOOL sendParamRegisterRead(uint8_t regNumber, uint32_t *value);

	//Raise execution signal on FPGA
	//Returns true if signal is raised.
	//If signal is not raised for any reason, returns false.
	// Check error code with getLastError()
	BOOL sendRun();
	//Wait until execution signal on FPGA is lowered
	// maxWaitTime: # of seconds to wait until timeout (from 1 to 4M sec).
	//Returns true if signal is lowered.
	//If function fails for any reason, returns false.
	// Check error code with getLastError().
	BOOL waitDone(uint8_t maxWaitTime);
	//Send a soft reset to the user circuit (useful when debugging new applications
	//	and the circuit refuses to give back control to the host PC)
	//Returns true if the soft reset is accepted
	//If the reset command is refused for any reason, returns false.
	// Check error code with getLastError()
	BOOL sendReset();

	//Send a block of data to the FPGA, raise the execution signal, wait for the execution
	// signal to be lowered, then read back up to N values of results
	// startAddress: local address on FPGA input buffer to begin writing at
	// length: # of bytes to write
	// inData: data to be sent to FPGA
	// maxWaitTime: # of seconds to wait until execution timeout
	// outData: readback data buffer (if function returns successfully)
	// maxOutLength: maximum length of outData buffer provided
	// outputLength: number of bytes actually returned (if function returns successfully)
	// Returns true if entire process is successful.
	// If function fails for any reason, returns false.
	//  Check error code with getLastError().
	//  error != FAILCAPACITY: see normal error list
	//  error == FAILCAPACITY: Output was larger than provided buffer.  Rather than the number of
	//			bytes actually returned, the outputLength variable will contain the TOTAL number bytes the
	//			function wanted to return (he number of bytes actually returned will be maxOutLength).
	//			If this occurs, user should read back bytes {maxOutLength, outputLength - 1} manually
	//			with a subsequent sendRead command.
	BOOL sendWriteAndRun(uint32_t startAddress, uint32_t inLength, uint8_t *inData, 
		uint8_t maxWaitTime, uint8_t *outData, uint32_t maxOutLength, 
		uint32_t *outputLength);

	//Reconfigure the FPGA using the SystemACE by pulling a bitstream from the CompactFlash card
	//This function sends a command over the ethernet connection.
	// configNumber: bitstream # (between 0 and 7)
	//Returns true if configuration command received successfully.
	//If command not received for any reason, returns false.
	// Check error code with getLastError().
#ifdef SYSACECONFIG
	BOOL sendConfiguration(uint8_t configNumber);
#endif

	//Reconfigure FPGA with bitstream from file - configure with iMPACT with external programmer
	//Returns true if configuration completes successfully.
	//Otherwise, returns false.
	// Check error code with getLastError().
#ifdef IMPACTCONFIG
	BOOL sendConfiguration(char *path);
#endif

	//Retrieve the last error code.  Any value < 0 indicates a problem.
	//A value === 0 indicates no error.
	//See function prototype description above for further explaination.
	int8_t getLastError(){
		return(lastError);
	}
private:
	PACKET_DRIVER_STATE PacketDriver;
	uint8_t *FPGA_MACAddress;
	
	int8_t lastError;

	std::list <PACKET *> outstandingPackets;
	//How many outstanding packets do we have?
	//We could just do outstandingPackets.size(), but that might be slow
	int outstandingTransmits;
	std::list <PACKET *>::iterator packetIter;

	//These are the parameters used when we are doing reads.
	std::list <uint32_t> outstandingReadStartAddresses;
	std::list <uint32_t> outstandingReadLengths;

	std::list <uint32_t>::iterator startAddressIter;
	std::list <uint32_t>::iterator lengthIter;

	//Over the current set of read requests, have we seen the
	// need for any resends?
	BOOL noResends;

	// Have we seen any response from the write & run command?
	BOOL noResponse;

	// Have we had a capacity problem for the response to this write & run command?
	BOOL okCapacity;

#ifdef DEBUG
	int writeResends;
	int readResends;
	int paramWriteResends;
	int paramReadResends;
	int resetResends;
#ifdef SYSACECONFIG
	int sysACEConfigResends;
#endif
#ifdef SYSACERW
	int sysACEReadResends;
	int sysACEWriteResends;
#endif
	int writeAndRunResends;
#endif

	BOOL OpenPacketDriver();
    void ClosePacketDriver();

	BOOL addReceive();

	void fillPacketHeader(PACKET* Packet, uint32_t length);

	BOOL addTransmit(PACKET* Packet);
	void emptyOutstandingPackets();

	BOOL createWriteRequestBackAndTransmit(uint32_t startAddress, uint32_t length, uint8_t *buffer);
	BOOL receiveWriteAcks();
	BOOL checkWriteAck(PACKET* packet);

	BOOL createReadRequestBackAndTransmit(uint32_t startAddress, uint32_t length);
	BOOL createReadRequestCurrentIterLocation(uint32_t startAddress, uint32_t length);
	BOOL receiveReadResponses(uint32_t initialStartAddress, uint8_t *buffer);
	BOOL checkReadData(PACKET* packet, uint32_t* currAddress, uint32_t* currLength,  
		uint8_t* buffer, uint32_t initialStartAddress);

	BOOL createParamWriteRequestBackAndTransmit(uint8_t regNumber, uint32_t value);
	BOOL receiveParamWriteAck();
	BOOL checkParamWriteAck(PACKET* packet);

	BOOL createParamReadRequestBackAndTransmit(uint8_t regNumber);
	BOOL receiveParamReadResponse(uint32_t *value, uint32_t maxWaitTime);
	BOOL checkParamReadData(PACKET* packet, uint32_t *value);

	BOOL createWriteAndRunRequestBackAndTransmit(uint32_t startAddress, uint32_t length, uint8_t *buffer);
	BOOL receiveWriteAndRunAcks(uint8_t maxWaitTime, uint32_t maxOutLength, uint8_t *buffer, uint32_t *outputLength);
	BOOL checkWriteAndRunData(PACKET* packet, uint32_t* currAddress, uint32_t* currLength,  
									uint8_t* buffer, uint32_t *outputLength, uint32_t maxOutLength);

	BOOL createResetRequestAndTransmit();
	BOOL receiveResetAck();
	BOOL checkResetAck(PACKET* packet);

#ifdef SYSACECONFIG
	BOOL createSysACEConfigureRequestBackAndTransmit(uint8_t configNumber);
	BOOL receiveSysACEConfigureAck();
	BOOL checkSysACEConfigureAck(PACKET* packet);
#endif

	void incrementCurrIterLocation();
	void removeReadRequestCurrentIterLocation();
	void markPacketAcked(PACKET* packet);

	void printPacket(PACKET* packet);

	//Currently unused functions
#ifdef SYSACERW
	BOOL sendSystemACERegisterWrite(uint8_t regNumber, uint32_t value);
	BOOL createSystemACERegisterWriteRequestBackAndTransmit(uint8_t regNumber, uint32_t value);
	BOOL receiveSystemACERegisterWriteAck();
	BOOL checkSystemACERegisterWriteAck(PACKET* packet);

	BOOL sendSystemACERegisterRead(uint8_t regNumber, uint32_t *value);
	BOOL createSystemACERegisterReadRequestBackAndTransmit(uint8_t regNumber);
	BOOL receiveSystemACERegisterReadResponse(uint32_t *value, uint32_t maxWaitTime);
	BOOL checkSystemACERegisterReadData(PACKET* packet, uint32_t *value);
#endif
};

