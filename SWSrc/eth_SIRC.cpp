// Title: ETH_SIRC class definition
// 
// Description: Read and write to input/output buffers and parameter register file.  Also, 
// start execution, wait until execution is completed and reconfigure the
// device via SystemACE.
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

//PUBLIC FUNCTIONS
//Constructor for the class
//FPGA_ID: 6 byte array containing the MAC adddress of the destination FPGA
//Return with an error code if anything goes wrong.
ETH_SIRC::ETH_SIRC(uint8_t *FPGA_ID){
	lastError = 0;
	//Make connection to NIC driver
	if(!OpenPacketDriver()){
		return;
	}

	if(FPGA_ID == NULL){
#ifdef DEBUG
		printf("Invalid destination MAC address given!\n");
#endif
		lastError = INVALIDFPGAMACADDRESS;
		return;
	}

	FPGA_MACAddress = (uint8_t *) malloc(sizeof(uint8_t) * 6);
	if(!FPGA_MACAddress){
		lastError = FAILMEMALLOC;
		return;
	}

	memcpy(FPGA_MACAddress, FPGA_ID, 6);

	outstandingTransmits = 0;

#ifdef DEBUG
	writeResends = 0;
	readResends = 0;
	paramWriteResends = 0;
	paramReadResends = 0;
	resetResends = 0;

#ifdef SYSACECONFIG
	sysACEConfigResends = 0;
#endif
#ifdef SYSACERW
	sysACEReadResends = 0;
	sysACEWriteResends = 0;
#endif
	writeAndRunResends = 0;
#endif

	//Queue up a bunch of receives
	//We want to keep this full, so every time we read
	// one out we should add one back.
	for(int i = 0; i < DEFAULT_RECEIVE_SIZE; i++){
		if(!addReceive()){
			return;
		}
	}
	
#ifdef IMPACTCONFIG
	ifstream fin;
	string tempString;

#ifndef PATHTOIMPACT
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef PATHTOIMPACTTEMPLATEBATCHFILE
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef PATHTOIMPACTPROGRAMMINGBATCHFILE
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef PATHTOIMPACTPROGRAMMINGOUTPUTFILE
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef IMPACTSUCCESSPHRASE
	lastError = FAILIMPACTCONSTANTDEFINE;
	return;
#endif

	//Check to see that the iMPACT binary exists
	tempString = PATHTOIMPACT;
	fin.open(tempString.c_str(), ifstream::in);
	if(fin.fail()){
		fin.close();
		lastError = FAILPATHTOIMPACT;
		return;
	}
	fin.close();

	//Check to see that the template configuration batch file exists
	tempString = PATHTOIMPACTTEMPLATEBATCHFILE;
	fin.open(tempString.c_str(), ifstream::in);
	if(fin.fail()){
		fin.close();
		lastError = FAILPATHTOIMPACTTEMPLATEBATCHFILE;
		return;
	}
	fin.close();

#endif
	//Send a soft reset to make sure that the user circuit is not running.
	if(!sendReset()){
		lastError = FAILINITIALCONTACT;
	}

	return;
}

ETH_SIRC::~ETH_SIRC(){
#ifdef DEBUG
	printf("Write Resends = %d\n", writeResends);
	printf("Read Resends = %d\n", readResends);
	printf("Param Reg Write Resends = %d\n", paramWriteResends);
	printf("Param Reg Read Resends = %d\n", paramReadResends);
	printf("Param Reg Write Resends = %d\n", paramWriteResends);
	printf("Param Reg Read Resends = %d\n", paramReadResends);
#ifdef SYSACECONFIG
	printf("SysACE Config Resends = %d\n", sysACEConfigResends);
#endif
#ifdef SYSACERW
	printf("SysACE Read Resends = %d\n", sysACEReadResends);
	printf("SysACE Write Resends = %d\n", sysACEWriteResends);
#endif
	printf("Write and Run Resends = %d\n", writeAndRunResends);
#endif

	ClosePacketDriver();

	if(FPGA_MACAddress){
		free(FPGA_MACAddress);
	}
}

//Send a block of data to an input buffer on the FPGA
// startAddress: local address on FPGA input buffer to begin writing at
// length: # of bytes to write
// buffer: data to be sent to FPGA
//Return true if write is successful.
//If write fails for any reason, return false w/error code
BOOL ETH_SIRC::sendWrite(uint32_t  startAddress, uint32_t length, uint8_t *buffer){
	//Developer Note: When this function returns, it is possible that
	//	there are one or more transmission packets still waiting on the completion port.
	//	They will be acked, but not completed yet.  Thus, the packets will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.

	//This function breaks the write request into packet-appropriate write commands.
	//These write commands are sent in blocks of NUMOUTSTANDINGWRITES.
	//Each write command is acknowledged when it has been received by the FPGA.
	//After sending out NUMOUTSTANDINGWRITES write commands, we check to see which,
	// if any commands have been acknowledged.  If they are not acknowledged in a 
	// timely manner, we resend the write command.
	//If any command is not acknowledged after MAXRETRIES attempts, we will
	// return false.
	uint32_t currLength;
	int numRetries;
	
	lastError = 0;

	if(!buffer){
		lastError = INVALIDBUFFER;
		return false;
	}

	if(startAddress > MAXINPUTDATABYTEADDRESS){
		lastError = INVALIDADDRESS;
		return false;
	}

	if(length == 0 || startAddress + length > MAXINPUTDATABYTEADDRESS){
		lastError = INVALIDLENGTH;
		return false;
	}

	while(length > 0){
		//Break this write into MAXWRITESIZE sized chunks or smaller
		if(length > MAXWRITESIZE)
			currLength = MAXWRITESIZE;
		else
			currLength = length;

		if(!createWriteRequestBackAndTransmit(startAddress, currLength, buffer)){
			//If the send errored out, something is very wrong.
			emptyOutstandingPackets();
			return false;
		}

		//Update all of the markers
		buffer += currLength;
		startAddress += currLength;
		length -= currLength;

		//See if we have too many outstanding messages (or if we are done transmitting).
		//If so, we should scoreboard and check off any write acks we got back
		//A better way to do this would have an independent thread take care of the
		// scoreboarding, but synchronization might be very difficult
		if(outstandingTransmits >= NUMOUTSTANDINGWRITES || length == 0){
			//Try to check writes off the scoreboard & resend outstanding packets up to N times
			numRetries = 0;
			while(1){
				//Try to receive acks for the outstanding writes
				if(!receiveWriteAcks()){
					//Verify that receiveWriteAcks did not return false due to some error
					// rather then just not getting back all of the acks we expected.
					if(lastError != 0){
						emptyOutstandingPackets();
						return false;
					}

					//Not all of the writes' acks came back, so re-send any outstanding writes that are still left outstanding
					//However, don't resend anything if that was the last time around.
					numRetries++;
					if(numRetries >= MAXRETRIES){
						//We have resent too many times
#ifdef DEBUG					
						printf("Write resent too many times without acknowledgement!\n");
#endif
						lastError = FAILWRITEACK;
						emptyOutstandingPackets();
						return false;
					}
					else{
						for(packetIter = outstandingPackets.begin(); packetIter != outstandingPackets.end(); packetIter++){
							//Since these packets are being re-sent, make sure the initial send has been completed, then reset it.
							assert((*packetIter)->completed);
							(*packetIter)->completed = false;

							//Also, double-check to see that none have been acked
							assert(!(*packetIter)->acked);

#ifdef DEBUG					
							writeResends++;
#endif

							if(!addTransmit(*packetIter)){
#ifdef DEBUG					
								printf("Write not sent!\n");
#endif
								lastError = INVALIDWRITETRANSMIT;
								emptyOutstandingPackets();
								return false;
							}
						}
					}
				}
				else{
					//We got all of the acks back, so break out of the while(1) and go to the next block of writes
					break;
				}
			}
		}
	}

	//Make sure that there are no outstanding packets
	lastError = 0;
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);
	return TRUE;
}

//Read a block of data from the output buffer of the FPGA
// startAddress: local address on FPGA output buffer to begin reading from
// length: # of bytes to read
// buffer: destination for data received from FPGA
//Return true if read is successful.
//If read fails for any reason, return false w/ error code
BOOL ETH_SIRC::sendRead(uint32_t startAddress, uint32_t length, uint8_t *buffer){
	//Developer Note: When this function returns, it is possible that
	//	there are one or more transmission packets still waiting on the completion port.
	//	They will be acked, but not completed yet.  Thus, the packets will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.

	//This function sends this read request to the FPGA.
	//The FPGA responds by breaking up the read request into packet-appropriate responses.
	//If we receive all of the parts back from the read request, we directly return true.
	//If not, we keep track of the parts we missed and re-send requests for those parts.
	//If we need to resend any part of the initial read request more than MAXRETRIES times,
	// we will return false.
	int numRetries;

	lastError = 0;

	if(!buffer){
		lastError = INVALIDBUFFER;
		return false;
	}

	if(startAddress > MAXOUTPUTDATABYTEADDRESS){
		lastError = INVALIDADDRESS;
		return false;
	}

	if(length == 0 || startAddress + length > MAXOUTPUTDATABYTEADDRESS){
		lastError = INVALIDLENGTH;
		return false;
	}

	//Send the read request
	if(!createReadRequestBackAndTransmit(startAddress, length)){
		return false;
	}

	//Now that we've sent out the read request, try to get back some responses.
	numRetries = 0;
	while(1){
		//Try to get back all of the read responses associated with the current outstanding
		// read requests.  The first time through we will only have 1 request on the queue.
		// However, for subsequent retries, this may be larger than 1.
		//If we don't get back all of the reads we want, we will have all of the necessary resends
		// sitting in the outstanding packet queue.
		if(!receiveReadResponses(startAddress, buffer)){
			//Verify that receiveReadData did not return false due to some error
			// rather then just not getting back all of the read responses we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//Not all of the read replies came back, so we should send all of the packets on the outstanding list
			// unless that was the last chance we had
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG
				printf("Read resent too many times without response!\n");
#endif
				lastError = FAILREADACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				//Transmit/re-transmit the packets in the outstanding list.
				for(packetIter = outstandingPackets.begin(); packetIter != outstandingPackets.end(); packetIter++){
#ifdef DEBUG					
					readResends++;
#endif
					//Some of these packets are re-transmissions, so mark them incomplete before sending
					(*packetIter)->completed = false;
#ifdef BIGDEBUG
					printf("Num Retries = %d, Resending packet:\n", numRetries);
					printPacket(*packetIter);
#endif

					if(!addTransmit(*packetIter)){
#ifdef DEBUG
						printf("Read not sent!\n");
#endif
						lastError = INVALIDREADTRANSMIT;
						emptyOutstandingPackets();
						return false;
					}
				}
			}
			numRetries++;
		}
		else{
			//All of the reads came back, so we are done
			break;
		}
	}

	lastError = 0;
	assert(outstandingPackets.empty());
	assert(outstandingReadStartAddresses.empty());
	assert(outstandingReadLengths.empty());
	assert(outstandingTransmits == 0);
	return true;
}

//Send a 32-bit value from the PC to the parameter register file on the FPGA
// regNumber: register to which value should be sent (between 0 and 254)
// value: value to be written
//Returns true if write is successful.
//If write fails for any reason, returns false.
// Check error code with getLastError()
BOOL ETH_SIRC::sendParamRegisterWrite(uint8_t regNumber, uint32_t value){
	//Developer Note: When this function returns, it is possible that
	//	there is one transmission packet still waiting on the completion port.
	//	It will be acked, but not completed yet.  Thus, the packet will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.

	PACKET *packet;
	int numRetries;
	
	lastError = 0;

	if(!(regNumber < 255)){
		lastError = INVALIDADDRESS;
		return false;
	}

	if(!createParamWriteRequestBackAndTransmit(regNumber, value)){
		//If the send errored out, something is very wrong.
		emptyOutstandingPackets();
		return false;
	}

	//Try to check the write off.  Resend up to N times
	numRetries = 0;
	while(1){
		//Try to receive param write acks for the outstanding param write
		if(!receiveParamWriteAck()){
			//Verify that receiveParamWriteAcks did not return false due to some error
			// rather then just not getting back the ack we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//The param write ack didn't come back, so re-send the outstanding packet
			//However, don't resend anything if that was the last time around.
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG					
				printf("Param reg write resent too many times without acknowledgement!\n");
#endif
				lastError = FAILWRITEACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				packet = outstandingPackets.front();
				//Since this packet is being re-sent, make sure the initial send has been completed, then reset it.
				assert(packet->completed);
				packet->completed = false;

				//Also, double-check to see that none have been acked
				assert(!packet->acked);

#ifdef DEBUG					
				paramWriteResends++;
#endif

				if(!addTransmit(packet)){
#ifdef DEBUG					
					printf("Param write not sent!\n");
#endif
					lastError = INVALIDPARAMWRITETRANSMIT;
					emptyOutstandingPackets();
					return false;
				}
			}
		}
		else{
			//We got the ack back, so break out of the while(1)
			break;
		}
	}

	lastError = 0;
	//Make sure that there are no outstanding packets
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);
	return TRUE;
}

//Read a 32-bit value from the parameter register file on the FPGA back to the PC
// regNumber: register to which value should be read (between 0 and 254)
// value: value received from FPGA
//Returns true if read is successful.
//If read fails for any reason, returns false.
// Check error code with getLastError().
BOOL ETH_SIRC::sendParamRegisterRead(uint8_t regNumber, uint32_t *value){
	//Developer Note: When this function returns, it is possible that
	//	there is one transmission packet still waiting on the completion port.
	//	It will be acked, but not completed yet.  Thus, the packet will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.

	PACKET *packet;
	int numRetries;
	
	lastError = 0;

	if(!(regNumber < 255)){
		lastError = INVALIDADDRESS;
		return false;
	}

	if(!createParamReadRequestBackAndTransmit(regNumber)){
		//If the send errored out, something is very wrong.
		emptyOutstandingPackets();
		return false;
	}

	//Try to check the read off.  Resend up to N times
	numRetries = 0;
	while(1){
		//Try to receive param read response for the outstanding param read
		if(!receiveParamReadResponse(value, 0)){
			//Verify that receiveParamReadResponse did not return false due to some error
			// rather then just not getting back the ack we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//The param read response didn't come back, so re-send the outstanding packet
			//However, don't resend anything if that was the last time around.
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG					
				printf("Param reg read resent too many times without acknowledgement!\n");
#endif
				lastError = FAILREADACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				packet = outstandingPackets.front();
				//Since this packet is being re-sent, make sure the initial send has been completed, then reset it.
				assert(packet->completed);
				packet->completed = false;

				//Also, double-check to see that none have been acked
				assert(!packet->acked);

#ifdef DEBUG					
				paramReadResends++;
#endif

				if(!addTransmit(packet)){
#ifdef DEBUG					
					printf("Param read not sent!\n");
#endif
					lastError = INVALIDPARAMREADTRANSMIT;
					emptyOutstandingPackets();
					return false;
				}
			}
		}
		else{
			//We got the ack back, so break out of the while(1)
			break;
		}
	}

	lastError = 0;
	//Make sure that there are no outstanding packets
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);
	return TRUE;
}

//Raise execution signal on FPGA
//Returns true if signal is raised.
//If signal is not raised for any reason, returns false.
// Check error code with getLastError()
BOOL ETH_SIRC::sendRun(){
	//Developer Note: When this function returns, it is possible that
	//	there is one transmission packet still waiting on the completion port.
	//	It will be acked, but not completed yet.  Thus, the packet will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.

	PACKET *packet;
	int numRetries;
	
	lastError = 0;

	if(!createParamWriteRequestBackAndTransmit(255, 1)){
		//If the send errored out, something is very wrong.
		emptyOutstandingPackets();
		return false;
	}

	//Try to check the write off.  Resend up to N times
	numRetries = 0;
	while(1){
		//Try to receive param write acks for the outstanding param write
		if(!receiveParamWriteAck()){
			//Verify that receiveParamWriteAcks did not return false due to some error
			// rather then just not getting back the ack we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//The param write ack didn't come back, so re-send the outstanding packet
			//However, don't resend anything if that was the last time around.
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG					
				printf("Run signal resent too many times without acknowledgement!\n");
#endif
				lastError = FAILWRITEACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				packet = outstandingPackets.front();
				//Since this packet is being re-sent, make sure the initial send has been completed, then reset it.
				assert(packet->completed);
				packet->completed = false;

				//Also, double-check to see that none have been acked
				assert(!packet->acked);

#ifdef DEBUG					
				paramWriteResends++;
#endif

				if(!addTransmit(packet)){
#ifdef DEBUG					
					printf("Param write not sent!\n");
#endif
					lastError = INVALIDPARAMWRITETRANSMIT;
					emptyOutstandingPackets();
					return false;
				}
			}
		}
		else{
			//We got the ack back, so break out of the while(1)
			break;
		}
	}

	lastError = 0;
	//Make sure that there are no outstanding packets
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);
	return TRUE;
}

//Wait until execution signal on FPGA is lowered
// maxWaitTime: # of seconds to wait until timeout.
//Returns true if signal is lowered.
//If function fails for any reason, returns false.
// Check error code with getLastError().
BOOL ETH_SIRC::waitDone(uint8_t maxWaitTime){
	//Developer Note: When this function returns, it is possible that
	//	there are one or more transmission packets still waiting on the completion port.
	//	They will be acked, but not completed yet.  Thus, the packets will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.
	uint32_t value;

	lastError = 0;

	time_t currTime = time(NULL);
	time_t endTime = currTime + maxWaitTime;

	while(endTime > currTime){
		//Send out the read
		if(!createParamReadRequestBackAndTransmit(255)){
			//If the send errored out, something is very wrong.
			emptyOutstandingPackets();
			return false;
		}

		//Try to get the read back
		if(!receiveParamReadResponse(&value, maxWaitTime)){
			//If receiveParamReadResponse timed out, replace the
			// error code with FAILWAITACK
			if(lastError == FAILREADACK){
			//The param read response didn't come back in time, so error out
#ifdef DEBUG					
				printf("Wait done response didn't come back in time!\n");
#endif
				lastError = FAILWAITACK;
			}

			emptyOutstandingPackets();
			return false;
		}
		else{
			//We got the ack back
			//See if the done register is 0
			if(value == 0){
				lastError = 0;

				//Make sure that there are no outstanding packets
				assert(outstandingPackets.empty());
				assert(outstandingTransmits == 0);
				return TRUE;
			}
		}
		currTime = time(NULL);
	}

	lastError = FAILDONE;
	return false;
}

//Send a soft reset to the user circuit (useful when debugging new applications
//	and the circuit refuses to give back control to the host PC)
//Returns true if the soft reset is accepted
//If the reset command is refused for any reason, returns false.
// Check error code with getLastError()
BOOL ETH_SIRC::sendReset(){
	//Developer Note: When this function returns, it is possible that
	//	there is one transmission packet still waiting on the completion port.
	//	It will be acked, but not completed yet.  Thus, the packet will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.
	PACKET *packet;
	int numRetries;
	
	lastError = 0;

	if(!createResetRequestAndTransmit()){
		//If the send errored out, something is very wrong.
		emptyOutstandingPackets();
		return false;
	}

	//Try to check the reset off.  Resend up to N times
	numRetries = 0;
	while(1){
		//Try to receive reset acknowledge
		if(!receiveResetAck()){
			//Verify that receiveResetAck did not return false due to some error
			// rather then just not getting back the ack we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//The reset response didn't come back, so re-send the outstanding packet
			//However, don't resend anything if that was the last time around.
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG					
				printf("Reset resent too many times without acknowledgement!\n");
#endif
				lastError = FAILRESETACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				packet = outstandingPackets.front();
				//Since this packet is being re-sent, make sure the initial send has been completed, then reset it.
				assert(packet->completed);
				packet->completed = false;

				//Also, double-check to see that it has not been acked
				assert(!packet->acked);

#ifdef DEBUG					
				resetResends++;
#endif

				if(!addTransmit(packet)){
#ifdef DEBUG					
					printf("Reset request not sent!\n");
#endif
					lastError = INVALIDRESETTRANSMIT;
					emptyOutstandingPackets();
					return false;
				}
			}
		}
		else{
			//We got the ack back, so break out of the while(1)
			break;
		}
	}

	lastError = 0;
	//Make sure that there are no outstanding packets
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);
	return TRUE;
}


//Send a block of data to the FPGA, raise the execution signal, wait for the execution
// signal to be lowered, then read back up to values of results
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
//  error == FAILCAPACITY: The output was larger than provided buffer.  Rather than the number of
//			bytes actually returned, the outputLength variable will contain the TOTAL number bytes the
//			function wanted to return (the number of bytes actually returned will be maxOutLength).
//			If this occurs, user should read back bytes {maxOutLength, outputLength - 1} manually
//			with a subsequent sendRead command.
//  error == FAILREADACK: The write and execution phases completed correctly, but we retried
//			the readback phase too many times.  In this case, like the FAILCAPICITY error, outputLength
//			will contain the TOTAL number bytes the	function wanted to return.  The state of outData is unknown,
//			but some data has been partially written.  The user could try calling sendRead
//			from {0, outputLength-1} manually if re-calling sendWriteAndRun is not easy
//			(for example, if inData and outData overlapped).
//  error == anything else: see normal error list
BOOL ETH_SIRC::sendWriteAndRun(uint32_t startAddress, uint32_t inLength, uint8_t *inData, 
							  uint8_t maxWaitTime, uint8_t *outData, uint32_t maxOutLength, 
							  uint32_t *outputLength){
	uint32_t numPackets;
	uint32_t currLength;
	int numRetries = 0;
	
	lastError = 0;

	//Check the input parameters
	if(!inData){
		lastError = INVALIDBUFFER;
		return false;
	}
	if(startAddress > MAXINPUTDATABYTEADDRESS){
		lastError = INVALIDADDRESS;
		return false;
	}
	if(inLength == 0 || startAddress + inLength > MAXINPUTDATABYTEADDRESS){
		lastError = INVALIDLENGTH;
		return false;
	}

	//Check the output parameters
	if(!outData){
		lastError = INVALIDBUFFER;
		return false;
	}
	if(maxOutLength == 0 || maxOutLength > MAXOUTPUTDATABYTEADDRESS){
		lastError = INVALIDLENGTH;
		return false;
	}

	//Try to send the data to the FPGA
	//First break the write request into packet-appropriate write commands.
	//The first N are sent using the normal write command, the last one is sent using the
	// write and execute command.
	//Determine how many packets are we going to need to send.
	//This division will round down to the next integer
	numPackets = inLength / MAXWRITESIZE;
	if(inLength % MAXWRITESIZE == 0){
		//If the length of the input buffer fits exactly into N packets, let's send 1 less
		numPackets--;
	}
	currLength = numPackets * MAXWRITESIZE;

	//There are 3 phases to this function: write initial data to FPGA, send last write & run packet,
	// wait for data to come back.
	//Aside from the normal, unrecoverable problems that can occur (invalid parameters,
	// memory allocation fail, etc), there are four types of "recoverable" errors that can happen.
	while(numRetries < MAXRETRIES){
		//Write the initial part of the data to the FPGA
		//We want all of the initial writes to be send and acknowledged before we send the write & run command.
		//This is in the while() loop because we don't know if the execution is destructive.
		//In the current system the input and output buffers are independent, but in the future they may not be.
		//Thus, if anything goes wrong we will have to re-send all of the input data before re-execution.
		if(numPackets > 0){
			if(!sendWrite(startAddress, currLength, inData)){
				//Error #1: The write of the first N packets using regular send write commands error out.
				//		The sendWrite function already takes care of resend attempts, so if this fails the 
				//		whole function should fail.
				return false;	
			}
		}

		//Now we want to send the last packet out via a write & run command.
		if(!createWriteAndRunRequestBackAndTransmit(startAddress + currLength, inLength - currLength, inData + currLength)){
			//If the send errored out, something is very wrong.
			return false;
		}

		//Try to receive the responses from the FPGA.
		//If we return true, we got back all of the responses without any trouble.
		//If we return false, this may be due to any number of causes.
		if(receiveWriteAndRunAcks(maxWaitTime, maxOutLength, outData, outputLength)){
			//We got back all of the write & run responses and they fit within the
			// output buffer without trouble.
			lastError = 0;
			return true;
		}
		else{
			if(lastError == FAILWRITEACK){
				//Error #2: We got no response at all. In this case, we don't know if the
				//		initial packet was lost or if all of the responses (could be a small number)
				//		were lost.  Because of this, we have to retry the entire sequence again, 
				//		beginning at the very first write (execution might have overwritten some of the
				//		input data).
				sendReset();
				numRetries++;
#ifdef DEBUG					
				writeAndRunResends++;
#endif
				continue;
			}
			else if(lastError == FAILWRITEANDRUNCAPACITY){
				//Error #3: We got all of the expected responses back, but they don't fit in the output buffer
				//		The receiveWriteAndRunAcks function has already set lastError to FAILWRITEANDRUNCAPACITY, 
				//		and set outputLength to the total length of the response
				return false;
			}
			else if(lastError == FAILWRITEANDRUNREADACK){
				//Error #4: We missed some response.
				//		The receiveWriteAndRunAcks function has already set outputLength to the total length of the response and
				//		filled in requests for the missing part into outstandingPackets, outstandingReadStartAddresses and 
				//		outstandingReadLengths.  Thus, all we have to do is just resend them, if we have not retried too many times
				//		Once we get into this state, don't reenter the outer while loop.  At this point
				//		we can only return true, false with FAILWRITEANDRUNCAPACITY/FAILREADACK, or false with some fatal error.
				//		Stated another way, we don't want to try resending the entire write and run command again.
				lastError = 0;
				
				while(numRetries < MAXRETRIES){
					//Transmit/re-transmit the packets in the outstanding list.
#ifdef DEBUG					
					writeAndRunResends++;
#endif
					for(packetIter = outstandingPackets.begin(); packetIter != outstandingPackets.end(); packetIter++){
						//Some of these packets could be re-transmissions, so mark them incomplete before sending
						(*packetIter)->completed = false;
#ifdef BIGDEBUG
						printf("Num Retries = %d, Resending packet:\n", numRetries);
						printPacket(*packetIter);
#endif

						if(!addTransmit(*packetIter)){
#ifdef DEBUG
							printf("Read not sent!\n");
#endif
							lastError = INVALIDREADTRANSMIT;
							emptyOutstandingPackets();
							return false;
						}
					}
					numRetries++;

					//Try to get the reads back
					if(receiveReadResponses(0, outData)){
						//We got back all of the outstanding reads
						if(okCapacity){
							lastError = 0;
							return true;
						}
						else{
							lastError = FAILWRITEANDRUNCAPACITY;
							return false;
						}	
					}
					else{
						//Verify that receiveReadData did not return false due to some error
						// rather then just not getting back all of the read responses we expected.
						if(lastError != 0){
							emptyOutstandingPackets();
							return false;
						}

						//Not all of the read replies came back, so we should send all of the packets on the outstanding list
						// unless that was the last chance we had
						if(numRetries >= MAXRETRIES){
							break;
						}
					}
				}

				//We have resent too many times
#ifdef DEBUG
				printf("Write and run resent too many times without response!\n");
#endif
				emptyOutstandingPackets();
				lastError = FAILWRITEANDRUNREADACK;
				return false;
			}
			else{
				//Some other, unrecoverable problem might have occured.  In that case, we enter the normal
				// unrecoverable exit routine.
				emptyOutstandingPackets();
				return false;
			}
		}
	}
	//If we get this far, we tried resending the write & run command too many times because of FAILWRITEACK errors
#ifdef DEBUG
	printf("Write and run resent too many times without response!\n");
#endif
	lastError = FAILWRITEACK;
	emptyOutstandingPackets();
	return false;
}

//Reconfigure the FPGA using the SystemACE by pulling a bitstream from the CompactFlash card
//This function sends a command over the ethernet connection.
// configNumber: bitstream # (between 0 and 7)
//Returns true if configuration command received successfully.
//If command not received for any reason, returns false.
// Check error code with getLastError().
#ifdef SYSACECONFIG
BOOL ETH_SIRC::sendConfiguration(uint8_t configNumber){
	//Developer Note: When this function returns, it is possible that
	//	there are one or more transmission packets still waiting on the completion port.
	//	They will be acked, but not completed yet.  Thus, the packets will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.
	PACKET *packet;
	int numRetries;
	uint32_t temp;
	
	lastError = 0;

	if(!(configNumber < 8)){
		lastError = INVALIDADDRESS;
		return false;
	}

	if(!createSysACEConfigureRequestBackAndTransmit(configNumber)){
		//If the send errored out, something is very wrong.
		emptyOutstandingPackets();
		return false;
	}

	//Try to check the configuration command off.  Resend up to N times
	numRetries = 0;
	while(1){
		//Try to receive the ack for the outstanding configuration command
		if(!receiveSysACEConfigureAck()){
			//Verify that receiveSysACEConfigureAck did not return false due to some error
			// rather then just not getting back the ack we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//The configuration ack didn't come back, so re-send the outstanding packet
			//However, don't resend anything if that was the last time around.
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG					
				printf("SystemACE configuration resent too many times without acknowledgement!\n");
#endif
				lastError = FAILCONFIGURATIONACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				packet = outstandingPackets.front();
				//Since this packet is being re-sent, make sure the initial send has been completed, then reset it.
				assert(packet->completed);
				packet->completed = false;

				//Also, double-check to see that none have been acked
				assert(!packet->acked);

#ifdef DEBUG					
				sysACEConfigResends++;
#endif

				if(!addTransmit(packet)){
#ifdef DEBUG					
					printf("SystemACE configuration not sent!\n");
#endif
					lastError = INVALIDSYSACECONFIGTRANSMIT;
					emptyOutstandingPackets();
					return false;
				}
			}
		}
		else{
			//We got the ack back, so break out of the while(1)
			break;
		}
	}

	//Make sure that there are no outstanding packets
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);

	//Pause the whole system for 1.5 seconds to make sure that the reconfiguration is complete.
	Sleep(1500);

	//Try to do a register read to see if the system came back
	if(!sendParamRegisterRead(0, &temp)){
		lastError = FAILCONFIGURATIONRETURN;
		return false;
	}

	lastError = 0;
	return TRUE;
}
#endif

//Reconfigure FPGA with bitstream from file - configure with iMPACT with external programmer
//Returns true if configuration completes successfully.
//Otherwise, returns false.
// Check error code with getLastError().
#ifdef IMPACTCONFIG
BOOL ETH_SIRC::sendConfiguration(char *path){
	ifstream fin;
	ofstream fout;
	FILE *output;
	string tempString;
	string keyString;
	BOOL found;
	size_t location;
	errno_t err;
	uint32_t temp;

#ifndef PATHTOIMPACT
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef PATHTOIMPACTTEMPLATEBATCHFILE
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef PATHTOIMPACTPROGRAMMINGBATCHFILE
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef PATHTOIMPACTPROGRAMMINGOUTPUTFILE
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return false;
#endif
#ifndef IMPACTSUCCESSPHRASE
	//This check shouldn't be necessary since the code will not compile without this definition
	lastError = FAILIMPACTCONSTANTDEFINE;
	return;
#endif

	//Check to see that the bitstream file exists
	tempString = path;
	fin.open(tempString.c_str(), ifstream::in);
	if(fin.fail()){
		fin.close();
		lastError = FAILCONFIGURATIONBITSTREAM;
		return false;
	}
	fin.close();

	//Open the template configuration batch file
	tempString = PATHTOIMPACTTEMPLATEBATCHFILE;
	fin.open(tempString.c_str(), ifstream::in);
	if(fin.fail()){
		fin.close();
		lastError = FAILPATHTOIMPACTTEMPLATEBATCHFILE;
		return false;
	}

	//Open the configuration programming batch file
	tempString = PATHTOIMPACTPROGRAMMINGBATCHFILE;
	fout.open(tempString.c_str(), ifstream::out);
	if(fout.fail()){
		fout.close();
		lastError = FAILPATHTOIMPACTPROGRAMMINGBATCHFILE;
		return false;
	}

	//Go through the template batch file and replace the BITSTREAMFILENAME variable with the provided bitstream path name.
	//Output to the programming batch file
	found = false;
	keyString = "BITSTREAMFILENAME";
	while(getline(fin, tempString)){
		location = tempString.find(keyString);
		if(location != string::npos){
			//We found more than 1 instance of BITSTREAMFILENAME
			if(found){
				lastError = FAILIMPACTTEMPLATEBATCHFILE;
				fin.close();
				fout.close();
				return false;
			}
			tempString.replace(location, keyString.length(), path);
			found = true;
		}
		fout << tempString << endl;
	}
	if(!found){
		//We did not fine an instance of BITSTREAMFILENAME
		lastError = FAILIMPACTTEMPLATEBATCHFILE;
		fin.close();
		fout.close();
		return false;
	}

	fin.close();
	fout.close();

	//Redirect stdout to a file
	err = freopen_s(&output, PATHTOIMPACTPROGRAMMINGOUTPUTFILE, "w", stdout);
	if(err != 0){
		//Return stdout back to the console
		err = freopen_s(&output, "CON", "w", stdout);
		lastError = FAILPATHTOIMPACTPROGRAMMINGSOUTPUTFILE;
		return false;
	}	

	//Execute iMPACT with the batch file.
	tempString = PATHTOIMPACT;
	tempString += " -batch ";
	tempString += PATHTOIMPACTPROGRAMMINGBATCHFILE;
	//Redirect stderr to stdout (stdout is already redirected to a file)
	tempString += " 2>&1";

	system(tempString.c_str());

	//Return stdout back to the console
	fclose(output);
	err = freopen_s(&output, "CON", "w", stdout);

	//Open the output file to see if the programming succeeded
	tempString = PATHTOIMPACTPROGRAMMINGOUTPUTFILE;
	fin.clear();
	fin.open(tempString.c_str(), ifstream::in);
	if(fin.fail()){
		fin.close();
		lastError = FAILPATHTOIMPACTPROGRAMMINGSOUTPUTFILE;
		return false;
	}
	keyString = IMPACTSUCCESSPHRASE;
	while(getline(fin, tempString)){
		location = tempString.find(keyString);
		if(location != string::npos){
			//We found the success phrase, so try and do a register read to see if the system came back
			fin.close();
			if(!sendParamRegisterRead(0, &temp)){
				lastError = FAILCONFIGURATIONRETURN;
				return false;
			}
			lastError = 0;
			return true;
		}
	}
	fin.close();
	//We did not find the success phrase, so return an error
	lastError = FAILCONFIGURATIONIMPACT;
	return false;
}
#endif


//PRIVATE FUNCTIONS
//Try to set the handle and completion port for the virtual network service.
//Return true if everything succeeded.
//Return false w/error code if anything fails.
BOOL ETH_SIRC::OpenPacketDriver(){
    BOOL        bResult;
    HRESULT     Result;
    wchar_t      SymbolicName[MAX_LINK_NAME_LENGTH];

	//
    //  Start from scratch.
    //
    memset(&PacketDriver, 0, sizeof(PACKET_DRIVER_STATE));

    //
    //  Make sure we have an interface, lest we crash and burn later
    //
    bResult = VirtualpcDriverGetSymbolicName(SymbolicName);

    if (bResult == FALSE){
#ifdef DEBUG
        printf("OpenPacketDriver: no NIC.  Check installation of Virtual Machine Network Services Driver.\n");
#endif
		lastError = FAILVMNSDRIVERPRESENT;
		return false;
    }

    //
    //  Open the NDIS packet driver so we can send and receive.
    //
    PacketDriver.hFile = VirtualpcDriverOpenAdapter(SymbolicName, &(PacketDriver.AuxHandle));

    if (PacketDriver.hFile == INVALID_HANDLE_VALUE){
#ifdef DEBUG
        printf("OpenPacketDriver: no suitable NIC.  Check activation of Virtual Machine Network Services.\n");
#endif
		lastError = FAILVMNSDRIVERACTIVE;
        return false;
    }

    //
    //  Initialize our descriptor
    //
    //
    //  Set up the capture filter.
    //	Only recieve packets intended for the MAC address we got when we opened the adapter

    Result = VirtualpcDriverSetFilter(
                    PacketDriver.hFile,
                    //NDIS_PACKET_TYPE_BROADCAST | 
                    //NDIS_PACKET_TYPE_MULTICAST |
                    //NDIS_PACKET_TYPE_ALL_MULTICAST |
					NDIS_PACKET_TYPE_DIRECTED
					);
	
	if (Result != S_OK){
#ifdef DEBUG
		printf("OpenPacketDriver: Filter setting failed!\n");
#endif
		lastError = FAILVMNSDRIVERFILTER;
        CloseHandle(PacketDriver.hFile);
        if (PacketDriver.AuxHandle != INVALID_HANDLE_VALUE)
            CloseHandle(PacketDriver.AuxHandle);
        return false;
	}

    //
    //  Get the ethernet address for this adapter.
    //
    Result = VirtualpcDriverGetAddress(
                    PacketDriver.hFile, 
                    PacketDriver.EthernetAddress
                    );
    if (Result != S_OK){
#ifdef DEBUG
        printf("OpenPacketDriver: NIC has no MAC?? (hr=%x)\n.", Result);
#endif
		lastError = FAILVMNSDRIVERMACADD;
        CloseHandle(PacketDriver.hFile);
        if (PacketDriver.AuxHandle != INVALID_HANDLE_VALUE)
            CloseHandle(PacketDriver.AuxHandle);
        return false;
    }

   printf("Host MAC is %02x:%02x:%02x:%02x:%02x:%02x\n", 
	   PacketDriver.EthernetAddress[0],
	   PacketDriver.EthernetAddress[1], 
	   PacketDriver.EthernetAddress[2],
	   PacketDriver.EthernetAddress[3], 
	   PacketDriver.EthernetAddress[4],
	   PacketDriver.EthernetAddress[5]);

    //
    //  Create the I/O completion ports for send and
    //  receive operations to and from the packet driver.
    //
    PacketDriver.IoCompletionPort = CreateIoCompletionPort(
                                        PacketDriver.hFile,
                                        NULL,
                                        (ULONG) &PacketDriver, 
                                        0
                                        );

    assert(PacketDriver.IoCompletionPort != NULL);
	if(!PacketDriver.IoCompletionPort){
#ifdef DEBUG
        printf("OpenPacketDriver: Completion port creation failed\n.");
#endif
		lastError = FAILVMNSDRIVERCOMPLETION;
		return false;
	}

    PacketDriver.bInitialized = TRUE;

    return TRUE;
}

//Clear out any packets pending on the completion port,
// free any allocated packets, and close out the handle and 
// completion port for the virtual network service.
void ETH_SIRC::ClosePacketDriver(){
    /* Stop listening to network port, reclaim pending packets and free memory
     */
    FlushPacketDriver(&PacketDriver);

    /* Close handles
     */
    if (PacketDriver.hFile != INVALID_HANDLE_VALUE)
        CloseHandle(PacketDriver.hFile);
    PacketDriver.hFile = INVALID_HANDLE_VALUE;

    if (PacketDriver.AuxHandle != INVALID_HANDLE_VALUE)
        CloseHandle(PacketDriver.AuxHandle);
    PacketDriver.AuxHandle = INVALID_HANDLE_VALUE;

    /* Close the completion port 
     */
    CloseHandle(PacketDriver.IoCompletionPort);
    PacketDriver.IoCompletionPort = INVALID_HANDLE_VALUE;

    /* Done
     */
    PacketDriver.bInitialized = FALSE;
}

//This function queues a receive on the network port
//Return true on success, return false w/error code on failure
BOOL ETH_SIRC::addReceive(){
    PACKET *Packet;

	PacketAllocate(&PacketDriver, &Packet);
	if(!Packet){
		lastError = FAILMEMALLOC;
		return false;
	}

#ifdef BIGDEBUG
	printf("***********Adding receive packet @ %x\n", Packet);
#endif

    PacketReadFile(PacketDriver.hFile, Packet);

    return TRUE;
}

//Fill in the source, destination and length fields for the packet, along with the
// nBytesAvail field.
void ETH_SIRC::fillPacketHeader(PACKET* Packet, uint32_t length){
	assert(Packet != NULL);
	assert(length <= MAXPACKETDATASIZE);

	//The length of the frame will be the length of the payload plus 6 + 6 + 2 (dest MAC,
	//  source MAC, and payload length)
	Packet->nBytesAvail = length + 14;

	//Set the destination and source addresses of the packet (0-5 and 6-11)
	memcpy(Packet->Buffer, FPGA_MACAddress, 6);
	memcpy(Packet->Buffer + 6, PacketDriver.EthernetAddress, 6);

	//The payload length field (bytes 12 and 13) does not include the length of the header
	Packet->Buffer[13] = (length) % 256;
	Packet->Buffer[12] = (length) >> 8;
}

//This function adds a transmit to the output queue and sends the message
//Return true if the send goes OK, return false if not.
//Don't bother with an error code, the function that calls this will take care of that.
BOOL ETH_SIRC::addTransmit(PACKET* Packet){
	HRESULT Result;

#ifdef BIGDEBUG
	printf("***********Transmitting packet @ %x\n", Packet);
#endif

	Result = PacketWriteFile(PacketDriver.hFile, Packet);

	if(Result != S_OK && Result != ERROR_IO_PENDING){
#ifdef DEBUG
		printf("Bad transmission packet!\n");
#endif
		return FALSE;
	}
	return TRUE;
}

//The ack on the outstanding packets isn't coming, so put them into the free list
//To avoid all problems, we should clear the completion ports first.
//This will ensure that no uncompleted requests are outstanding that will complete
// later, after the packet has been freed.
void ETH_SIRC::emptyOutstandingPackets(){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif

	//Keep polling the completion port until it comes up empty
	while(1){
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						READTIMEOUT);
		//We may time out and fail (or fail for some other reason)
		if (!bResult)
			break;
		
		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving ){
				//Received packets get freed outright
				PacketFree(&PacketDriver, Packet);
			}
			else{
				//Transmitted packets are assumed to be in the outstanding list,
				// so we don't have to do anything with them right now.
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
			}
		}
	}

	//Now put the outstanding transmits into the free list
	//Some of them might have been completed, but none should be acked.
	for(packetIter = outstandingPackets.begin(); packetIter != outstandingPackets.end(); packetIter++){
		assert(!(*packetIter)->acked);
		PacketFree(&PacketDriver, *packetIter);
	}

	//Empty the read starting address and length lists
	outstandingReadStartAddresses.clear();
	outstandingReadLengths.clear();
}

//Create a write request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
BOOL ETH_SIRC::createWriteRequestBackAndTransmit(uint32_t startAddress, uint32_t length, uint8_t *buffer){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	uint32_t tempLength;
	uint32_t tempAddress;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be N + 9 bytes long (N + 1 byte command + 4 bytes address + 4 bytes length)
	fillPacketHeader(currentPacket, length + 9);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'w'
	currBuffer[0] = 'w';

	tempLength = length;
	tempAddress = startAddress;

	//Set the start address and write length fields (1-4 and 5-8)
	for(int i = 3; i >=0; i--){
		currBuffer[i + 1] = tempAddress % 256;
		currBuffer[i + 5] = tempLength % 256;
		tempAddress = tempAddress >> 8;
		tempLength = tempLength >> 8;
	}

	//Copy the write data over
	memcpy(currBuffer + 9, buffer, length);

	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("Write not sent!\n");
#endif
		lastError = INVALIDWRITETRANSMIT;
		return false;
	}
	return true;
}

//Try and grab as many write acks that we can up till:
// 1) we get all of the outstanding writes acked, return true
// 2) we haven't gotten a new ack for N seconds (N should never be less than 1), return false
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveWriteAcks(){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif

	time_t currTime = time(NULL);
	time_t lastTime = currTime;

	while(currTime <  lastTime + (WRITETIMEOUT / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						WRITETIMEOUT);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//This return false is not an error per se, we just timed out
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving ){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is a good write ack
				if(checkWriteAck(Packet)){
					//This is a good ack
					//Free the receive packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//See if we have gotten all of the write acks back
					//If we have gotten all the writes acked, we are done for now
					if(outstandingTransmits == 0){
						return true;
					}
					lastTime = currTime;
					continue;
				}
	
				//This isn't an ack of something we sent, but we should free the packet anyways.
				PacketFree(&PacketDriver, Packet);

				//When we complete a packet recieve, we might have to do something.
				// For example, add another receive to the queue.
				if(!addReceive()){
					return false;
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				if(Packet->acked){
					//If so, free it
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("recieveWriteAcks bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}
	//This return false is not an error per se, we just timed out
	return false;
}

//See if this write ack matches one that is outstanding
//If the packet matches one in the outstandingPacket list, return true.
//If not, return false.
BOOL ETH_SIRC::checkWriteAck(PACKET* packet){
	uint8_t *message;
	uint8_t *testMessage;

	message = packet->Buffer;

	//See if the packet is from the expected source
	for(int i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//See if the packet is the correct length
	//This should be exactly 9 bytes long (command byte + start address + length)
	if(message[12] != 0 || message[13] != 9)
		return false;

	//Check the command byte
	if(message[14] != 'w')
		return false;

	//So far, so good - let's try to match this against one of the outstanding writes
	//We add the newest packets sent to the end of the list, so the oldest (and likely first to be acked)
	// packets should be near the front.
	for(packetIter = outstandingPackets.begin(); packetIter != outstandingPackets.end(); packetIter++){
		testMessage = (*packetIter)->Buffer;

		//Check if we recognize start address & length
		if(message[15] == testMessage[15] && message[16] == testMessage[16] && message[17] == testMessage[17] && message[18] == testMessage[18] &&
			message[19] == testMessage[19] && message[20] == testMessage[20] && message[21] == testMessage[21] && message[22] == testMessage[22]){
#ifdef BIGDEBUG
				printf("Matched in scoreboard packet @ %x!\n", *(packetIter));
#endif
				//We matched a transmission, so see if that command was completed already.
				//If it was completed, put it in the free list
				if((*packetIter)->completed){
#ifdef BIGDEBUG
					printf("*******Command already completed, so freeing\n");
					//printPacket(*packetIter);
#endif
					PacketFree(&PacketDriver, *packetIter);
				}
				else{
					//Otherwise, just mark it acked and free it when it completes
					(*packetIter)->acked = true;
#ifdef BIGDEBUG
					printf("*******Command not completed, so waiting to free\n");
					//printPacket(*packetIter);
#endif
				}

				//remove this from the outstanding packets
				outstandingPackets.erase(packetIter);

				//Decrement the outstanding packet counter
				outstandingTransmits --;
				return true;
		}
	}

	return false;
}

//Create a read request, add it to the back of the outstanding queue and transmit it.
//Return true if transmission goes smoothly.
//Return false with error code if anything goes wrong.
BOOL ETH_SIRC::createReadRequestBackAndTransmit(uint32_t startAddress, uint32_t length){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	uint32_t tempLength;
	uint32_t tempAddress;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}
	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 9 bytes long (1 byte command + 4 bytes address + 4 bytes length)
	fillPacketHeader(currentPacket, 9);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'r'
	currBuffer[0] = 'r';

	tempLength = length;
	tempAddress = startAddress;

	//Set the start address and write length fields (1-4 and 5-8)
	for(int i = 3; i >=0; i--){
		currBuffer[i + 1] = tempAddress % 256;
		currBuffer[i + 5] = tempLength % 256;
		tempAddress = tempAddress >> 8;
		tempLength = tempLength >> 8;
	}

	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingReadStartAddresses.push_back(startAddress);
	outstandingReadLengths.push_back(length);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG
		printf("Read not sent!\n");
#endif
		lastError = INVALIDREADTRANSMIT;
		emptyOutstandingPackets();
		return false;
	}
	return true;
}


//Create a read request just before the location currently pointed to by the various iterators
// in the outstandingPacket lists.
//When we are done, the iterators will point to the location just beyond the read request we just made
//Return true if the addition went smoothly.
//Return false w/error code if not.
BOOL ETH_SIRC::createReadRequestCurrentIterLocation(uint32_t startAddress, uint32_t length){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	uint32_t tempLength;
	uint32_t tempAddress;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}
	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 9 bytes long (1 byte command + 4 bytes address + 4 bytes length)
	fillPacketHeader(currentPacket, 9);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'r'
	currBuffer[0] = 'r';

	tempLength = length;
	tempAddress = startAddress;

	//Set the start address and write length fields (1-4 and 5-8)
	for(int i = 3; i >=0; i--){
		currBuffer[i + 1] = tempAddress % 256;
		currBuffer[i + 5] = tempLength % 256;
		tempAddress = tempAddress >> 8;
		tempLength = tempLength >> 8;
	}

	//Keep track of this message
	packetIter = outstandingPackets.insert(packetIter, currentPacket);
	startAddressIter = outstandingReadStartAddresses.insert(startAddressIter, startAddress);
	lengthIter = outstandingReadLengths.insert(lengthIter, length);

	incrementCurrIterLocation();
	outstandingTransmits++;
	return true;
}

// We have sent out one or more read requests (in strictly increasing addresses).
// The transmitted request packets are in outstandingPackets and the corresponding starting address
//	and length of the requests are in outstandingReadStartAddresses and outstandingReadLengths.
// We pass this function the initial start address of the entire read so that we know what the
//  offset should be within the buffer for subsequent read request replies.
// Try any grab as many read responses as we can till:
//	1) we get all of the reads back that we asked for, return true
//	2) we haven't gotten a new ack for N seconds (N should never be less than 1), return false
//		and outstandingPacket/ReadStartAddress/ReadLength will be loaded with the resends
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveReadResponses(uint32_t initialStartAddress, uint8_t *buffer){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	//Let's keep track of where we are in the list of outstanding packets.
	//These iterators will always point to the lowest-address request still outstanding
	// (that is, we have not seen a response to it, nor anything with a higher requested address than it).
	//Since this is a sorted list, any packet earlier in the list will only have requests
	// from lower addresses.
	packetIter = outstandingPackets.begin();
	startAddressIter = outstandingReadStartAddresses.begin();
	lengthIter = outstandingReadLengths.begin();

	//This is the starting address we are expecting
	uint32_t currAddress = 0;
	uint32_t currLength = 0;

	noResends = true;

	//This is the current time
	time_t currTime = time(NULL);
	//This is the time we last saw a valid read response
	time_t lastTime = currTime;

	while(currTime <  lastTime + (READTIMEOUT / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						READTIMEOUT);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//If we fail, any outstanding requests still in the outstanding list should be
			// re-sent.  This will be taken care of when we return from this function.
			//However, we have to add a re-send request for any remaining part of the current request, if any.
			//We have a current request if currLength is not zero.
			if(currLength != 0){
				//Add a new request before the current location.
				if(!createReadRequestCurrentIterLocation(currAddress, currLength)){
					return false;
				}
			}
			//This return false is not an error per se, we just timed out and we'll have to resend
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is any read response packet we are expecting.
				//If it is, copy the data to the buffer, update the currAddress/currLength,
				// and update the outstanding packet list (removing or adding as necessary).
				if(checkReadData(Packet, &currAddress, &currLength, buffer, initialStartAddress)){
					//This is a good read response, so update the timer
					lastTime = currTime;

					//Free the packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//We know we are done if there are no more transmits outstanding and the
					// currLength == 0
					if(outstandingTransmits == 0 && currLength == 0){
						return true;
					}
					//We know we are done for now if we are at the end of the outstanding queue and we have
					// currLength == 0).  No sense in waiting to time out, we know that we had some problems
					// and we want to resend.
					else if(packetIter == outstandingPackets.end() && currLength == 0){
						break;
					}
				}
				else{
					//This was not a good read response, so just free the packet and go back around
					//Free the packet
					PacketFree(&PacketDriver, Packet);
					
					if(lastError != 0){
						//checkReadData has some sort of problem, so return
						return false;
					}

					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				//If so, free it
				if(Packet->acked){
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("recieveWriteAcks bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}

	//We timed out. Any outstanding requests still in the outstanding list should be
	// re-sent.  This will be taken care of when we return from this function.
	//However, we have to add a re-send request for any remaining part of the current request, if any.
	//We have a current request if currLength is not zero.
	if(currLength != 0){
		//Add a new request before the current location.
		if(!createReadRequestCurrentIterLocation(currAddress, currLength)){
			return false;
		}
	}
	return false;
}

//This function looks at the packet we have been sent and determines if the packet
//	is a response to any of the outstanding read requests we have.
//If it it not a response to a read request, we will return false.
//If it is a response, we copy the data to the buffer in the correct location, update 
// currAddress & currLength, and add or remove any necessary read requests from the
// outstanding list.  If this goes OK, we will return true.  If anything goes wrong
// we will return false with an error code.
BOOL ETH_SIRC::checkReadData(PACKET* packet, uint32_t* currAddress, uint32_t* currLength, 
							 uint8_t* buffer, uint32_t initialStartAddress){
	uint8_t *message = packet->Buffer;

	uint32_t dataLength;
	uint32_t startAddress;
	int i;

	//When we enter this function, packetIter will always be pointing at a request for which 
	// we have not seen any responses.  This is because as soon as we see any 
	// response from a given request, we remove it from the list.
	//First, see if this is a valid read response
	//See if the packet is from the expected source
	for(i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//Get the length of the packet
	dataLength = message[12];
	dataLength = (dataLength << 8) + message[13];
	//This packet must be at least 6 bytes long (1 byte command + 4 bytes address + 1 data byte)
	if(dataLength < 6){
		return false;
	}

	//Check the command byte
	if(message[14] != 'r')
		return false;

	//Get the start address
	startAddress = 0;
	for(i = 0; i < 4; i++){
		startAddress = startAddress << 8;
		startAddress += message[15 + i];
	}

	//This is probably a valid read response, let's try to match it up
	while(1){
		if(*currLength == 0){
			//If currLength == 0, the request at packetIter is a new one and we are hoping to get
			//		responses for it.  currAddress does not have any meaningful value in it yet.
			//	If this is the case, we should update currAddress and currLength with the
			//		values from the request at packetIter.
			//See if we are all out of requests.
			if(lengthIter == outstandingReadLengths.end()){
				//This only happens when we get responses beyond of the range of the requests we have queued up
				//If this happens, something is wrong, so just toss out the packet
				return false;
			}

			*currLength = *lengthIter;
			*currAddress = *startAddressIter;
			
			//	Now, there are a few things that can happen:
			//	1) we get a response for the beginning of the request at packetIter
			if(startAddress == *currAddress){
				//	a) mark the packet acked
				markPacketAcked(*packetIter);
				//	b) remove the packet at from the outstanding list
				removeReadRequestCurrentIterLocation();
				//	b) copy over the received data to the buffer
				memcpy(buffer+(startAddress - initialStartAddress), message + 19, dataLength - 5);
				//	c) update currLength & currAddress
				*currLength -= dataLength - 5;
				*currAddress += dataLength - 5;
				return true;
			}
			//	2) we get a response for the middle of the request at packetIter (we missed some
			//		data for the beginning of the request)
			else if(startAddress > *currAddress && startAddress < *currAddress + *currLength){
				noResends = false;
				//	a) mark the packet acked
				markPacketAcked(*packetIter);
				//	b) remove the packet at from the outstanding list
				removeReadRequestCurrentIterLocation();				
				//	c) create and insert a new read request for the missing piece
				if(!createReadRequestCurrentIterLocation(*currAddress, startAddress - *currAddress)){
					return false;
				}
				//	d) copy over the data
				memcpy(buffer+(startAddress - initialStartAddress), message + 19, dataLength - 5);
				//	e) update currLength & currAddress
				*currLength -= (startAddress - *currAddress) + dataLength - 5;
				*currAddress = startAddress + dataLength - 5;
				return true;
			}
			//	3) we get a response for an interval beyond the end of the request at packetIter
			//		(we missed responses for the entire request)
			else if(startAddress >= *currAddress + *currLength){
				noResends = false;
				//	a) increment packetIter (leave the old request in the list)
				incrementCurrIterLocation();
				//	b) set currLength = 0 (indicate we are trying to consider a new request)
				*currLength = 0;
				//	c) go back to the start of the function
				continue;
			}
			// 4) we get a response for an interval before the request at packetIter.
			//		In this case, something has gone wrong (perhaps a delay in the network?)
			//		Either way, just toss out the packet
			else{
				return false;
			}
		}
		//If currLength != 0, we are hoping to get a response at currAddress, a part of a request
		//		already started.
		else{
			//	There are a few things that can happen here:
			//	1) we get a response for right at currAddress
			if(startAddress == *currAddress){
				//	a) copy over the received data to the buffer
				memcpy(buffer+(startAddress - initialStartAddress), message + 19, dataLength - 5);
				//	b) update currLength & currAddress
				*currLength -= dataLength - 5;
				*currAddress += dataLength - 5;
				return true;
			}
			//	2) we get a response for the middle between currAddress and currLength (we missed some data
			//		for the beginning of the request)
			else if(startAddress > *currAddress && startAddress < *currAddress + *currLength){
				noResends = false;
				//	a) create and insert a new read request for the missing piece
				if(!createReadRequestCurrentIterLocation(*currAddress, startAddress - *currAddress)){
					return false;
				}
				//	b) copy over the data
				memcpy(buffer+(startAddress - initialStartAddress), message + 19, dataLength - 5);
				//	c) update currLength & currAddress
				*currLength -= (startAddress - *currAddress) + dataLength - 5;
				*currAddress = startAddress + dataLength - 5;
				return true;
			}
			// 3) we get a response for an interval beyond the end of the current request
			//		(we missed the response for the remainder of the current request)
			else if(startAddress >= *currAddress + *currLength){
				noResends = false;
				//	a) create and insert a new read request for the missing piece of the current request
				if(!createReadRequestCurrentIterLocation(*currAddress, *currLength)){
					return false;
				}
				//	b) set currLength to zero to indicate we are done with the current request
				*currLength = 0;
				//	c) go back to the start of the function
				continue;
			}
			// 4) we get a response for an interval before the current request
			//		In this case, something has gone wrong (perhaps a delay in the network?)
			//		Either way, we have probably created a new read request for this packet already,
			//			
			//		Either way, just toss out the packet
			else{
				return false;
			}
		}
	}
}

//Create a register write request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
BOOL ETH_SIRC::createParamWriteRequestBackAndTransmit(uint8_t regNumber, uint32_t value){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 6 bytes long (1 byte command + 1 byte address + 4 bytes length)
	fillPacketHeader(currentPacket, 6);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'k'
	currBuffer[0] = 'k';

	//Copy the register address over
	currBuffer[1] = regNumber;
	
	//Copy the value over
	for(int i = 3; i >= 0; i--){
		currBuffer[i + 2] = value % 256;
		value = value >> 8;
	}
	//memcpy(currBuffer + 2, &value, 4);

	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("Param write not sent!\n");
#endif
		lastError = INVALIDPARAMWRITETRANSMIT;
		return false;
	}

	return true;
}

//Try and grab a param write ack up till:
// 1) we get the outstanding write acked, return true
// 2) we don't get the ack for N seconds (N should never be less than 1), return false
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveParamWriteAck(){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	time_t currTime = time(NULL);
	time_t lastTime = currTime;

	while(currTime <  lastTime + (WRITETIMEOUT / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						WRITETIMEOUT);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//This return false is not an error per se, we just timed out
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is a good param write ack
				if(checkParamWriteAck(Packet)){
					//This is a good ack
					//Free the receive packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//We have gotten the parm write acked, so we are done
					return true;
				}
	
				//This isn't an ack of something we sent, but we should free the packet anyways.
				PacketFree(&PacketDriver, Packet);

				//When we complete a packet recieve, we might have to do something.
				// For example, add another receive to the queue.
				if(!addReceive()){
					return false;
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				if(Packet->acked){
					//If so, free it
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("recieveParamWriteAcks bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}
	//This return false is not an error per se, we just timed out
	return false;
}

//See if this param write ack matches the one that is outstanding
//If the packet matches the one in the outstandingPacket list, return true.
//If not, return false.
BOOL ETH_SIRC::checkParamWriteAck(PACKET* packet){
	uint8_t *message;
	uint8_t *testMessage;

	PACKET *testPacket;

	message = packet->Buffer;

	//See if the packet is from the expected source
	for(int i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//See if the packet is the correct length
	//This should be exactly 6 bytes long (command byte + reg address + value)
	if(message[12] != 0 || message[13] != 6)
		return false;

	//Check the command byte
	if(message[14] != 'k')
		return false;

	//So far, so good - let's try to match this against the one outstanding write
	testPacket = outstandingPackets.front();
	testMessage = testPacket->Buffer;

	//Check if we recognize reg address & value
	if(message[15] == testMessage[15] && message[16] == testMessage[16] && message[17] == testMessage[17] && 
		message[18] == testMessage[18] && message[19] == testMessage[19]){
#ifdef BIGDEBUG
		printf("Matched in scoreboard packet @ %x!\n", testPacket);
#endif
		//We matched a transmission, so see if that command was completed already.
		//If it was completed, put it in the free list
		if(testPacket->completed){
#ifdef BIGDEBUG
			printf("*******Command already completed, so freeing\n");
			//printPacket(testPacket);
#endif
			PacketFree(&PacketDriver, testPacket);
		}
		else{
			//Otherwise, just mark it acked and free it when it completes
			testPacket->acked = true;
#ifdef BIGDEBUG
			printf("*******Command not completed, so waiting to free\n");
			//printPacket(testPacket);
#endif
		}

		//remove this from the outstanding packets
		outstandingPackets.pop_front();

		//Decrement the outstanding packet counter
		outstandingTransmits --;
		return true;
	}

	return false;
}

//Create a register read request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
BOOL ETH_SIRC::createParamReadRequestBackAndTransmit(uint8_t regNumber){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 2 bytes long (1 byte command + 1 byte address)
	fillPacketHeader(currentPacket, 2);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'y'
	currBuffer[0] = 'y';

	//Copy the register address over
	currBuffer[1] = regNumber;

	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("Param read not sent!\n");
#endif
		lastError = INVALIDPARAMREADTRANSMIT;
		return false;
	}

	return true;
}

//Try and grab a param read response up till:
// 1) we get the outstanding read reponse, return true
// 2) we don't get the response for N seconds (N should never be less than 1), return false
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveParamReadResponse(uint32_t *value, uint32_t maxWaitTime){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	if(maxWaitTime == 0){
		maxWaitTime = READTIMEOUT;
	}
	else{
		maxWaitTime = maxWaitTime * 1000;
	}

	time_t currTime = time(NULL);
	time_t lastTime = currTime;

	while(currTime <  lastTime + (maxWaitTime / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						maxWaitTime);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//This return false is not an error per se, we just timed out
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is a good param read response
				if(checkParamReadData(Packet, value)){
					//This is a good response
					//Free the receive packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//We have gotten the parm read response, so we are done
					return true;
				}
	
				//This isn't a response to something we sent, but we should free the packet anyways.
				PacketFree(&PacketDriver, Packet);

				//When we complete a packet recieve, we might have to do something.
				// For example, add another receive to the queue.
				if(!addReceive()){
					return false;
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				if(Packet->acked){
					//If so, free it
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("receiveParamReadResponse bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}
	//This return false is not an error per se, we just timed out
	return false;

}

//See if this param write ack matches the one that is outstanding
//If the packet matches the one in the outstandingPacket list, return true.
//If not, return false.
BOOL ETH_SIRC::checkParamReadData(PACKET* packet, uint32_t *value){
	uint8_t *message;
	uint8_t *testMessage;

	PACKET *testPacket;

	message = packet->Buffer;

	//See if the packet is from the expected source
	for(int i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//See if the packet is the correct length
	//This should be exactly 6 bytes long (command byte + reg address + value)
	if(message[12] != 0 || message[13] != 6)
		return false;

	//Check the command byte
	if(message[14] != 'y')
		return false;

	//So far, so good - let's try to match this against the one outstanding write
	testPacket = outstandingPackets.front();
	testMessage = testPacket->Buffer;

	//Check if we recognize reg address
	if(message[15] == testMessage[15]){
#ifdef BIGDEBUG
		printf("Matched in scoreboard packet @ %x!\n", testPacket);
#endif
		//Copy the value over
		*value = 0;
		for(int i = 0; i < 4; i++){
			*value += message[i + 16] << (3 - i) * 8;
		}
		//memcpy(value, message + 16, 4);

		//We matched a transmission, so see if that command was completed already.
		//If it was completed, put it in the free list
		if(testPacket->completed){
#ifdef BIGDEBUG
			printf("*******Command already completed, so freeing\n");
			//printPacket(testPacket);
#endif
			PacketFree(&PacketDriver, testPacket);
		}
		else{
			//Otherwise, just mark it acked and free it when it completes
			testPacket->acked = true;
#ifdef BIGDEBUG
			printf("*******Command not completed, so waiting to free\n");
			//printPacket(testPacket);
#endif
		}

		//remove this from the outstanding packets
		outstandingPackets.pop_front();

		//Decrement the outstanding packet counter
		outstandingTransmits --;
		return true;
	}

	return false;
}

//Create a write and run request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
BOOL ETH_SIRC::createWriteAndRunRequestBackAndTransmit(uint32_t startAddress, uint32_t length, uint8_t *buffer){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	uint32_t tempLength;
	uint32_t tempAddress;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be N + 9 bytes long (N + 1 byte command + 4 bytes address + 4 bytes length)
	fillPacketHeader(currentPacket, length + 9);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'g'
	currBuffer[0] = 'g';

	tempLength = length;
	tempAddress = startAddress;

	//Set the start address and write length fields (1-4 and 5-8)
	for(int i = 3; i >=0; i--){
		currBuffer[i + 1] = tempAddress % 256;
		currBuffer[i + 5] = tempLength % 256;
		tempAddress = tempAddress >> 8;
		tempLength = tempLength >> 8;
	}

	//Copy the write data over
	memcpy(currBuffer + 9, buffer, length);

	//Don't keep track of this message
	//If we need to resend it, we will recreate it.
	//outstandingPackets.push_back(currentPacket);
	//outstandingTransmits++;
	//To make sure that the packet gets deleted when it is transmitted,
	// mark it as acked right now.
	currentPacket->acked = true;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("Write and run not sent!\n");
#endif
		lastError = INVALIDWRITEANDRUNTRANSMIT;
		return false;
	}
	return true;
}

// We have sent out a write and run command.
// There are 5 possible situation that can occur
// 1) We get all of the expected responses back and they fit in output buffer
//		Set outputLength to the number of bytes we are returning and return true
// 2) We get no response at all
//		Set lastError to FAILWRITEACK and return false.
// 3) We get all of the expected responses back, but they don't fit in the output buffer
//		Set lastError to FAILWRITEANDRUNCAPACITY, set outputLength to the total length of the response and return false
// 4) We miss some reponse, regardless of whether or not it would fit in the output buffer
//		Set lastError to FAILREADACK, set outputLength to the total length of the response, put the requests for the
//		missing parts (except those that wouldn't fit in the output buffer) into outstandingPackets, 
//		outstandingReadStartAddresses and outstandingReadLengths, and return false
// 5) We have some other technical problem like the other receiveXXX functions.
//		Set lastError appropriately and return false.
BOOL ETH_SIRC::receiveWriteAndRunAcks(uint8_t maxWaitTime, uint32_t maxOutLength, uint8_t *buffer, uint32_t *outputLength){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	//Let's keep track of where we are in the list of outstanding packets.
	//Since the write & run command does not have explicit read requests,
	//	when we come through this function we will not have any outstanding requests initially.
	//We will add requests, though, as we miss packets.
	packetIter = outstandingPackets.begin();
	startAddressIter = outstandingReadStartAddresses.begin();
	lengthIter = outstandingReadLengths.begin();

	//This is the starting address we are expecting
	uint32_t currAddress = 0;
	//This is the remaining number of bytes we are expecting
	uint32_t currLength = 0;

	noResponse = true;

	//This is the current time
	time_t currTime = time(NULL);
	//This is the time we last saw a valid read response
	time_t lastTime = currTime;

	while(currTime <  lastTime + maxWaitTime){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						maxWaitTime * 1000);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			break;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is any read response packet we are expecting.
				//If it is, copy the data to the buffer, update the currAddress/currLength/outputLength,
				// and add missed reads if necessary.
				if(checkWriteAndRunData(Packet, &currAddress, &currLength, buffer, outputLength, maxOutLength)){
					//This is a good read response, so update the timer
					lastTime = currTime;

					//Free the packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//Are we expecting any more packets?
					//We are not if the currLength is zero.  If we got here we have seen at least 1 good packet,
					//	so we can only be exiting with the case that: 
					//	1) we saw all of the packets we wanted to and the output fit 
					//		(lastError == 0 and we return true)
					//	2) we saw all of the packets we wanted to, but and the output did not fit
					//		(lastError == FAILWRITEANDRUNCAPACITY and we return false)
					//	3) we missed at least one packet somewhere down the line, regardless if the output could fit
					//		or not (lastError == FAILREADACK and we return false)
					if(currLength == 0){
						return(lastError == 0);
					}
				}
				else{
					//This was not a good read response, so just free the packet and go back around
					//Free the packet
					PacketFree(&PacketDriver, Packet);
					
					if(lastError != 0 && lastError != FAILWRITEANDRUNREADACK && lastError != FAILWRITEANDRUNCAPACITY){
						//checkWriteAndRunData had some sort of serious problem, so return
						return false;
					}

					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				//If so, free it
				if(Packet->acked){
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("receiveWriteAndRunAcks bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}

	//We timed out.
	//Have we seen any response yet?  If not, let's return a FAILWRITEACK error
	if(noResponse){
		lastError = FAILWRITEACK;
		return false;
	}
	
	//We have seen a response, but we were anticipating more packets.
	//Let's add a read request for the remaining part
	if(!createReadRequestCurrentIterLocation(currAddress, currLength)){
		return false;
	}
	//This return false is not an error per se, we just missed some packets and we'll have to send new read requests
	lastError = FAILWRITEANDRUNREADACK;
	return false;
}

//This function looks at the packet we have been sent and determines if the packet
//	is write and run command response.
//If it it not a write and run command response, we will return false.
//If it is a response, we:
//		1) check to see if this is the first response we have seen
//				(If so, setup outputLength and currLength, maybe set 
//				lastError = FAILWRITEANDRUNCAPACITY.  If not, double-check outputLength 
//				against current message parameters.  Either way, set okCapacity.)
//		2) determine if we missed any packets
//				(if so, add any necessary read requests to the outstanding packet list 
//				and set lastError = FAILREADACK)
//		3) copy the data to the buffer in the correct location and update 
//				currAddress & currLength.  
//In all but some fatal error case, we will return true.  We might set an error code, but
//		the function will still return true.
BOOL ETH_SIRC::checkWriteAndRunData(PACKET* packet, uint32_t* currAddress, uint32_t* currLength,  
									uint8_t* buffer, uint32_t *outputLength, uint32_t maxOutLength){
	uint8_t *message = packet->Buffer;

	uint32_t dataLength;
	uint32_t startAddress;
	uint32_t remainingLength;
	int i;

	//First, see if this is a valid read response
	//See if the packet is from the expected source
	for(i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//Get the length of the packet
	dataLength = message[12];
	dataLength = (dataLength << 8) + message[13];
	//This packet must be at least 10 bytes long (1 byte command + 4 bytes address + 4 bytes remaining # bytes + 1 data byte)
	if(dataLength < 10){
		return false;
	}

	//Check the command byte
	if(message[14] != 'g')
		return false;

	//Get the start address
	startAddress = 0;
	for(i = 0; i < 4; i++){
		startAddress = startAddress << 8;
		startAddress += message[15 + i];
	}

	//Get the remaining length
	remainingLength = 0;
	for(i = 0; i < 4; i++){
		remainingLength = remainingLength << 8;
		remainingLength += message[19 + i];
	}

	//This is some sort of valid read response, so:
	//		1) check to see if this is the first response we have seen
	//				(If so, setup outputLength and currLength, maybe set 
	//				lastError = FAILWRITEANDRUNCAPACITY.  If not, double-check outputLength 
	//				against current message parameters.  Either way, set okCapacity.
	if(noResponse){
		noResponse = false;
		*outputLength = startAddress + remainingLength;

		if(*outputLength > maxOutLength){
			*currLength = maxOutLength;
			lastError = FAILWRITEANDRUNCAPACITY;
			okCapacity = false;
		}
		else{
			*currLength = *outputLength;
			okCapacity = true;
		}
	}
	else if(*outputLength != startAddress + remainingLength){
		lastError = INVALIDWRITEANDRUNRECIEVE;
		return false;
	}

	//		2) determine if we missed any packets
	//				(if so, add any necessary read requests to the outstanding packet list 
	//				and set lastError = FAILREADACK)
	if(startAddress > *currAddress){
		//We missed some packets, so add a read request for the missing ones
		//Notice, we might have already had the FAILWRITEANDRUNCAPACITY error, but we are
		//		now switching to the FAILREADACK error.
		//If everything comes back normally after the re-send, we will reinstate the 
		//		FAILWRITEANDRUNCAPACITY if necessary
		lastError = FAILWRITEANDRUNREADACK;
		if(!createReadRequestCurrentIterLocation(*currAddress, startAddress - *currAddress)){
			return false;
		}
		*currLength -= startAddress - *currAddress;
	}
	else if(startAddress < *currAddress){
		//This is data we were expecting earlier.  We have already put in another
		//	request for it, so just ignore this packet.
		return false;
	}

	//		3) copy the data to the buffer in the correct location and update 
	//				currAddress & currLength.
	memcpy(buffer + startAddress, message + 23, min(*currLength, dataLength - 9));
	*currAddress = startAddress + dataLength - 9;
	*currLength -= min(*currLength, dataLength - 9);

	return true;
}


//Create a reset request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
BOOL ETH_SIRC::createResetRequestAndTransmit(){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 1 bytes long (1 byte command)
	fillPacketHeader(currentPacket, 1);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'm'
	currBuffer[0] = 'm';

	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("Reset not sent!\n");
#endif
		lastError = INVALIDRESETTRANSMIT;
		return false;
	}
	return true;
}

//Try and grab a reset ack up till:
// 1) we get the outstanding reset acked, return true
// 2) we don't get the ack for N seconds (N should never be less than 1), return false
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveResetAck(){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	time_t currTime = time(NULL);
	time_t lastTime = currTime;

	while(currTime <  lastTime + (WRITETIMEOUT / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						WRITETIMEOUT);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//This return false is not an error per se, we just timed out
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is a good reset ack
				if(checkResetAck(Packet)){
					//This is a good ack
					//Free the receive packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//We have gotten the parm write acked, so we are done
					return true;
				}
	
				//This isn't an ack of something we sent, but we should free the packet anyways.
				PacketFree(&PacketDriver, Packet);

				//When we complete a packet recieve, we might have to do something.
				// For example, add another receive to the queue.
				if(!addReceive()){
					return false;
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				if(Packet->acked){
					//If so, free it
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("recieveResetAcks bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}
	//This return false is not an error per se, we just timed out
	return false;
}

//See if this reset ack matches the one that is outstanding
//If the packet matches the one in the outstandingPacket list, return true.
//If not, return false.
BOOL ETH_SIRC::checkResetAck(PACKET* packet){
	uint8_t *message;
	PACKET *testPacket;

	message = packet->Buffer;

	//See if the packet is from the expected source
	for(int i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//See if the packet is the correct length
	//This should be exactly 1 bytes long (command byte)
	if(message[12] != 0 || message[13] != 1)
		return false;

	//Check the command byte
	if(message[14] != 'm')
		return false;

	//We have a match, so let's get rid of the outstanding reset packet
	testPacket = outstandingPackets.front();

	//See if that command was completed already.
	//If it was completed, put it in the free list
	if(testPacket->completed){
#ifdef BIGDEBUG
		printf("*******Command already completed, so freeing\n");
		//printPacket(testPacket);
#endif
		PacketFree(&PacketDriver, testPacket);
	}
	else{
		//Otherwise, just mark it acked and free it when it completes
		testPacket->acked = true;
#ifdef BIGDEBUG
		printf("*******Command not completed, so waiting to free\n");
		//printPacket(testPacket);
#endif
	}

	//remove this from the outstanding packets
	outstandingPackets.pop_front();

	//Decrement the outstanding packet counter
	outstandingTransmits --;
	return true;
}

//Create a SystemACE configure request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
#ifdef SYSACECONFIG
BOOL ETH_SIRC::createSysACEConfigureRequestBackAndTransmit(uint8_t configNumber){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 2 bytes long (1 byte command + 1 byte address)
	fillPacketHeader(currentPacket, 2);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'c'
	currBuffer[0] = 'c';

	//Copy the configure address over
	currBuffer[1] = configNumber;
	
	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("SystemACE configuration not sent!\n");
#endif
		lastError = INVALIDSYSACECONFIGTRANSMIT;
		return false;
	}

	return true;
}

//Try and grab a SysACE configuration ack up till:
// 1) we get the outstanding configuration command acked, return true
// 2) we don't get the ack for N seconds (N should never be less than 1), return false
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveSysACEConfigureAck(){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	time_t currTime = time(NULL);
	time_t lastTime = currTime;

	while(currTime <  lastTime + (WRITETIMEOUT / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						WRITETIMEOUT);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//This return false is not an error per se, we just timed out
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is a good SysACE config ack
				if(checkSysACEConfigureAck(Packet)){
					//This is a good ack
					//Free the receive packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//We have gotten the parm write acked, so we are done
					return true;
				}
	
				//This isn't an ack of something we sent, but we should free the packet anyways.
				PacketFree(&PacketDriver, Packet);

				//When we complete a packet recieve, we might have to do something.
				// For example, add another receive to the queue.
				if(!addReceive()){
					return false;
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				if(Packet->acked){
					//If so, free it
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("receiveSysACEConfigureAck bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}
	//This return false is not an error per se, we just timed out
	return false;

}

//See if this message matches the SysACE configuration ack that is outstanding
//If the packet matches the one in the outstandingPacket list, return true.
//If not, return false.
BOOL ETH_SIRC::checkSysACEConfigureAck(PACKET* packet){
	uint8_t *message;
	uint8_t *testMessage;

	PACKET *testPacket;

	message = packet->Buffer;

	//See if the packet is from the expected source
	for(int i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//See if the packet is the correct length
	//This should be exactly 2 bytes long (command byte + reg address)
	if(message[12] != 0 || message[13] != 2)
		return false;

	//Check the command byte
	if(message[14] != 'c')
		return false;

	//So far, so good - let's try to match this against the one outstanding write
	testPacket = outstandingPackets.front();
	testMessage = testPacket->Buffer;

	//Check if we recognize reg address & value
	if(message[15] == testMessage[15]){
#ifdef BIGDEBUG
		printf("Matched in scoreboard packet @ %x!\n", testPacket);
#endif
		//We matched a transmission, so see if that command was completed already.
		//If it was completed, put it in the free list
		if(testPacket->completed){
#ifdef BIGDEBUG
			printf("*******Command already completed, so freeing\n");
			//printPacket(testPacket);
#endif
			PacketFree(&PacketDriver, testPacket);
		}
		else{
			//Otherwise, just mark it acked and free it when it completes
			testPacket->acked = true;
#ifdef BIGDEBUG
			printf("*******Command not completed, so waiting to free\n");
			//printPacket(testPacket);
#endif
		}

		//remove this from the outstanding packets
		outstandingPackets.pop_front();

		//Decrement the outstanding packet counter
		outstandingTransmits --;
		return true;
	}

	return false;
}
#endif

void ETH_SIRC::incrementCurrIterLocation(){
	assert(packetIter != outstandingPackets.end());
	packetIter++;
	assert(startAddressIter != outstandingReadStartAddresses.end());
	startAddressIter++;
	assert(lengthIter != outstandingReadLengths.end());
	lengthIter++;
}

void ETH_SIRC::removeReadRequestCurrentIterLocation(){
	packetIter = outstandingPackets.erase(packetIter);
	startAddressIter = outstandingReadStartAddresses.erase(startAddressIter);
	lengthIter = outstandingReadLengths.erase(lengthIter);
	outstandingTransmits--;
}

//Mark this packet acked and free it if the transmission has been completed.
void ETH_SIRC::markPacketAcked(PACKET* packet){
	assert(!packet->acked);
	//See if the initial read request has been completed
	if(packet->completed){
		//If it has been completed, free the transmission packet.
		PacketFree(&PacketDriver, packet);
	}
	else{
		//We have seen a response from the read request, but we haven't seen the
		// transmit completion yet.  Thus, just mark it acked.  We'll free it when
		// it completes.
		packet->acked = true;
	}
}

//Currently unused functions
//Send a 32-bit value from the PC to the SystemACE on the FPGA
// regNumber: register to which value should be sent (between 0 and 47)
// value: value to be written
//Returns true if write is successful.
//If write fails for any reason, returns false.
// Check error code with getLastError()
#ifdef SYSACERW
BOOL ETH_SIRC::sendSystemACERegisterWrite(uint8_t regNumber, uint32_t value){
	//Developer Note: When this function returns, it is possible that
	//	there is one transmission packet still waiting on the completion port.
	//	It will be acked, but not completed yet.  Thus, the packet will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.

	PACKET *packet;
	int numRetries;
	
	lastError = 0;

	if(!(regNumber < 48)){
		lastError = INVALIDADDRESS;
		return false;
	}

	if(!createSystemACERegisterWriteRequestBackAndTransmit(regNumber, value)){
		//If the send errored out, something is very wrong.
		emptyOutstandingPackets();
		return false;
	}

	//Try to check the write off.  Resend up to N times
	numRetries = 0;
	while(1){
		//Try to receive param write acks for the outstanding param write
		if(!receiveSystemACERegisterWriteAck()){
			//Verify that receiveParamWriteAcks did not return false due to some error
			// rather then just not getting back the ack we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//The param write ack didn't come back, so re-send the outstanding packet
			//However, don't resend anything if that was the last time around.
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG					
				printf("Param reg write resent too many times without acknowledgement!\n");
#endif
				lastError = FAILSYSACEWRITEACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				packet = outstandingPackets.front();
				//Since this packet is being re-sent, make sure the initial send has been completed, then reset it.
				assert(packet->completed);
				packet->completed = false;

				//Also, double-check to see that none have been acked
				assert(!packet->acked);

#ifdef DEBUG					
				sysACEWriteResends++;
#endif

				if(!addTransmit(packet)){
#ifdef DEBUG					
					printf("Param write not sent!\n");
#endif
					lastError = INVALIDSYSACEWRITETRANSMIT;
					emptyOutstandingPackets();
					return false;
				}
			}
		}
		else{
			//We got the ack back, so break out of the while(1)
			break;
		}
	}

	//Make sure that there are no outstanding packets
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);
	return TRUE;
}

//Create a register write request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
BOOL ETH_SIRC::createSystemACERegisterWriteRequestBackAndTransmit(uint8_t regNumber, uint32_t value){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 6 bytes long (1 byte command + 1 byte address + 4 bytes length)
	fillPacketHeader(currentPacket, 6);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 's'
	currBuffer[0] = 's';

	//Copy the register address over
	currBuffer[1] = regNumber;
	
	//Copy the value over
	for(int i = 3; i >= 0; i--){
		currBuffer[i + 2] = value % 256;
		value = value >> 8;
	}

	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("SysACE register write not sent!\n");
#endif
		lastError = INVALIDSYSACEWRITETRANSMIT;
		return false;
	}

	return true;
}

//Try and grab a param write ack up till:
// 1) we get the outstanding write acked, return true
// 2) we don't get the ack for N seconds (N should never be less than 1), return false
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveSystemACERegisterWriteAck(){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	time_t currTime = time(NULL);
	time_t lastTime = currTime;

	while(currTime <  lastTime + (WRITETIMEOUT / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						WRITETIMEOUT);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//This return false is not an error per se, we just timed out
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is a good param write ack
				if(checkSystemACERegisterWriteAck(Packet)){
					//This is a good ack
					//Free the receive packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//We have gotten the parm write acked, so we are done
					return true;
				}
	
				//This isn't an ack of something we sent, but we should free the packet anyways.
				PacketFree(&PacketDriver, Packet);

				//When we complete a packet recieve, we might have to do something.
				// For example, add another receive to the queue.
				if(!addReceive()){
					return false;
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				if(Packet->acked){
					//If so, free it
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("receiveSystemACERegisterWriteAck bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}
	//This return false is not an error per se, we just timed out
	return false;
}

//See if this message matches a SystemACE register write ack that is outstanding
//If the packet matches the one in the outstandingPacket list, return true.
//If not, return false.
BOOL ETH_SIRC::checkSystemACERegisterWriteAck(PACKET* packet){
	uint8_t *message;
	uint8_t *testMessage;

	PACKET *testPacket;

	message = packet->Buffer;

	//See if the packet is from the expected source
	for(int i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//See if the packet is the correct length
	//This should be exactly 6 bytes long (command byte + reg address + value)
	if(message[12] != 0 || message[13] != 6)
		return false;

	//Check the command byte
	if(message[14] != 's')
		return false;

	//So far, so good - let's try to match this against the one outstanding write
	testPacket = outstandingPackets.front();
	testMessage = testPacket->Buffer;

	//Check if we recognize reg address & value
	if(message[15] == testMessage[15] && message[16] == testMessage[16] && message[17] == testMessage[17] && 
		message[18] == testMessage[18] && message[19] == testMessage[19]){
#ifdef BIGDEBUG
		printf("Matched in scoreboard packet @ %x!\n", testPacket);
#endif
		//We matched a transmission, so see if that command was completed already.
		//If it was completed, put it in the free list
		if(testPacket->completed){
#ifdef BIGDEBUG
			printf("*******Command already completed, so freeing\n");
			//printPacket(testPacket);
#endif
			PacketFree(&PacketDriver, testPacket);
		}
		else{
			//Otherwise, just mark it acked and free it when it completes
			testPacket->acked = true;
#ifdef BIGDEBUG
			printf("*******Command not completed, so waiting to free\n");
			//printPacket(testPacket);
#endif
		}

		//remove this from the outstanding packets
		outstandingPackets.pop_front();

		//Decrement the outstanding packet counter
		outstandingTransmits --;
		return true;
	}

	return false;
}


//Read a 32-bit value from the SysACE back to the PC
// regNumber: register to which value should be read (between 0 and 47)
// value: value received from FPGA
//Returns true if read is successful.
//If read fails for any reason, returns false.
// Check error code with getLastError().
BOOL ETH_SIRC::sendSystemACERegisterRead(uint8_t regNumber, uint32_t *value){
	//Developer Note: When this function returns, it is possible that
	//	there is one transmission packet still waiting on the completion port.
	//	It will be acked, but not completed yet.  Thus, the packet will not be in the FreePacket list.
	//	However, as long as all subsequent functions free acked transmissions of all types we will be OK.

	PACKET *packet;
	int numRetries;
	
	lastError = 0;

	if(!(regNumber < 48)){
		lastError = INVALIDADDRESS;
		return false;
	}

	if(!createSystemACERegisterReadRequestBackAndTransmit(regNumber)){
		//If the send errored out, something is very wrong.
		emptyOutstandingPackets();
		return false;
	}

	//Try to check the read off.  Resend up to N times
	numRetries = 0;
	while(1){
		//Try to receive param read response for the outstanding param read
		if(!receiveSystemACERegisterReadResponse(value, 0)){
			//Verify that receiveParamReadResponse did not return false due to some error
			// rather then just not getting back the ack we expected.
			if(lastError != 0){
				emptyOutstandingPackets();
				return false;
			}

			//The param read response didn't come back, so re-send the outstanding packet
			//However, don't resend anything if that was the last time around.
			numRetries++;
			if(numRetries >= MAXRETRIES){
				//We have resent too many times
#ifdef DEBUG					
				printf("SysACE reg read resent too many times without acknowledgement!\n");
#endif
				lastError = FAILSYSACEREADACK;
				emptyOutstandingPackets();
				return false;
			}
			else{
				packet = outstandingPackets.front();
				//Since this packet is being re-sent, make sure the initial send has been completed, then reset it.
				assert(packet->completed);
				packet->completed = false;

				//Also, double-check to see that none have been acked
				assert(!packet->acked);

#ifdef DEBUG					
				sysACEReadResends++;
#endif

				if(!addTransmit(packet)){
#ifdef DEBUG					
					printf("Param read not sent!\n");
#endif
					lastError = INVALIDSYSACEREADTRANSMIT;
					emptyOutstandingPackets();
					return false;
				}
			}
		}
		else{
			//We got the ack back, so break out of the while(1)
			break;
		}
	}

	//Make sure that there are no outstanding packets
	assert(outstandingPackets.empty());
	assert(outstandingTransmits == 0);
	return TRUE;
}

//Create a SysACE register read request, add it to the back of the outstanding queue and transmit it.
//Return true if the addition & transmission goes OK.
//Return false w/error code if not.
BOOL ETH_SIRC::createSystemACERegisterReadRequestBackAndTransmit(uint8_t regNumber){
    PACKET *currentPacket;
	uint8_t *currBuffer;

	//Get a packet to put this message in.
	PacketAllocate(&PacketDriver, &currentPacket);
	if(!currentPacket){
		lastError = FAILMEMALLOC;
		return false;
	}

	currentPacket->Mode = PacketModeTransmitting;

	//The packet will be 2 bytes long (1 byte command + 1 byte address)
	fillPacketHeader(currentPacket, 2);

	//Get the beginning of the packet payload (header is 14 bytes)
	currBuffer = &(currentPacket->Buffer[14]);

	//Set the command byte to 'a'
	currBuffer[0] = 'a';

	//Copy the register address over
	currBuffer[1] = regNumber;

	//Keep track of this message
	outstandingPackets.push_back(currentPacket);
	outstandingTransmits++;

	if(!addTransmit(currentPacket)){
#ifdef DEBUG					
		printf("SysACE register read not sent!\n");
#endif
		lastError = INVALIDSYSACECONFIGTRANSMIT;
		return false;
	}

	return true;
}

//Try and grab a SysACE register read response up till:
// 1) we get the outstanding read reponse, return true
// 2) we don't get the response for N seconds (N should never be less than 1), return false
// 3) we have some problem on the completion port or addReceive, return false w/ error code
BOOL ETH_SIRC::receiveSystemACERegisterReadResponse(uint32_t *value, uint32_t maxWaitTime){
	DWORD           Transferred;
	PACKET *        Packet;
	BOOL            bResult;
	OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
	ULONG_PTR       Key;
#else
	UINT_PTR        Key;
#endif
	if(maxWaitTime == 0){
		maxWaitTime = READTIMEOUT;
	}
	else{
		maxWaitTime = maxWaitTime * 1000;
	}

	time_t currTime = time(NULL);
	time_t lastTime = currTime;

	while(currTime <  lastTime + (maxWaitTime / 1000)){
		Packet = NULL;
		Overlapped = NULL;

		//Look through completed packets.
		//This might be a completion on a transmit (that we basically ignore)
		// or a completion on a recieve that we try to match up
		bResult = GetQueuedCompletionStatus(
						PacketDriver.IoCompletionPort,
						&Transferred,
						&Key,
						&Overlapped,
						maxWaitTime);

		//GetQueuedCompletionStatus may time out and fail
		if (!bResult){
			//This return false is not an error per se, we just timed out
			return false;
		}

		currTime = time(NULL);

		//Some packet completed
        Packet = (PACKET *) Overlapped;

#ifdef BIGDEBUG	
		printf("***********Completion on packet @ %x\n", Packet);
#endif

        if(Packet != NULL ){
			assert(Packet->Mode != PacketModeInvalid);

			if (Packet->Mode == PacketModeReceiving){
				//We got a packet from someone, so finish filling in the packet info
				Packet->nBytesAvail = Transferred;
				Packet->Result = S_OK;

#ifdef BIGDEBUG	
				printf("***********Packet receive completed on packet @ %x\n", Packet);
				//printPacket(Packet);
#endif

				//Check if this is a good SysACE register read response
				if(checkSystemACERegisterReadData(Packet, value)){
					//This is a good response
					//Free the receive packet
					PacketFree(&PacketDriver, Packet);
					//When we complete a packet recieve, we might have to do something.
					// For example, add another receive to the queue.
					if(!addReceive()){
						return false;
					}

					//We have gotten the parm read response, so we are done
					return true;
				}
	
				//This isn't a response to something we sent, but we should free the packet anyways.
				PacketFree(&PacketDriver, Packet);

				//When we complete a packet recieve, we might have to do something.
				// For example, add another receive to the queue.
				if(!addReceive()){
					return false;
				}
			}
			else{
				assert((Packet->Mode == PacketModeTransmitting) ||
					   (Packet->Mode == PacketModeTransmittingBuffer));
				//This was a transmit that completed.  See if it has been acked
				if(Packet->acked){
					//If so, free it
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, resetting since acked!\n", Packet);
					//printPacket(Packet);
#endif
					PacketFree(&PacketDriver, Packet);
				}
				else{
					//Otherwise, just mark it completed and free it when it is acked
					Packet->completed = true;
#ifdef BIGDEBUG
					printf("*******Packet transmit completed on packet @ %x, NOT resetting yet!\n", Packet);
					//printPacket(Packet);
#endif
				}
			}
		}
		else{
			/* Some sort of error */
			Key = GetLastError();
			printf("receiveSystemACERegisterReadResponse bad completion (x%x)\n", Key);
			lastError = FAILVMNSCOMPLETION;
			return false;
		}
	}
	//This return false is not an error per se, we just timed out
	return false;
}

//See if this packet matches the SysACE register read that is outstanding
//If the packet matches the one in the outstandingPacket list, return true.
//If not, return false.
BOOL ETH_SIRC::checkSystemACERegisterReadData(PACKET* packet, uint32_t *value){
	uint8_t *message;
	uint8_t *testMessage;

	PACKET *testPacket;

	message = packet->Buffer;

	//See if the packet is from the expected source
	for(int i = 0; i < 6; i++){
		if(message[i + 6] != FPGA_MACAddress[i])
			return false;
	}

	//See if the packet is the correct length
	//This should be exactly 6 bytes long (command byte + reg address + value)
	if(message[12] != 0 || message[13] != 6)
		return false;

	//Check the command byte
	if(message[14] != 'a')
		return false;

	//So far, so good - let's try to match this against the one outstanding write
	testPacket = outstandingPackets.front();
	testMessage = testPacket->Buffer;

	//Check if we recognize reg address
	if(message[15] == testMessage[15]){
#ifdef BIGDEBUG
		printf("Matched in scoreboard packet @ %x!\n", testPacket);
#endif
		//Copy the value over
		*value = 0;
		for(int i = 0; i < 4; i++){
			*value += message[i + 16] << (3 - i) * 8;
		}
		//memcpy(value, message + 16, 4);

		//We matched a transmission, so see if that command was completed already.
		//If it was completed, put it in the free list
		if(testPacket->completed){
#ifdef BIGDEBUG
			printf("*******Command already completed, so freeing\n");
			//printPacket(testPacket);
#endif
			PacketFree(&PacketDriver, testPacket);
		}
		else{
			//Otherwise, just mark it acked and free it when it completes
			testPacket->acked = true;
#ifdef BIGDEBUG
			printf("*******Command not completed, so waiting to free\n");
			//printPacket(testPacket);
#endif
		}

		//remove this from the outstanding packets
		outstandingPackets.pop_front();

		//Decrement the outstanding packet counter
		outstandingTransmits --;
		return true;
	}

	return false;
}
#endif

void ETH_SIRC::printPacket(PACKET* packet){
	unsigned int i;
	
	printf("Packet contents:\n");
	printf("\t%18s%18s%6s[Data]\n\t", "[Dest Address]", "[Src Address]","[Len]");
	for(i = 0; i < packet->nBytesAvail; i++){
		printf("%02x ", packet->Buffer[i]);	
	}
	printf("\n");
}