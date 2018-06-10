//Microsoft Research License Agreement
//Non-Commercial Use Only
//_____________________________________________________________________
//
//This Microsoft Research License Agreement, including all exhibits ("MSR-LA") is a legal agreement between you and Microsoft Corporation (?Microsoft? or ?we?) for the software or data identified above, which may include source code, and any associated materials, text or speech files, associated media and "online" or electronic documentation and any updates we provide in our discretion (together, the "Software"). 
//
//By installing, copying, or otherwise using this Software, found at http://research.microsoft.com/downloads, you agree to be bound by the terms of this MSR-LA.  If you do not agree, do not install copy or use the Software. The Software is protected by copyright and other intellectual property laws and is licensed, not sold.    
//
//SCOPE OF RIGHTS:
//You may use, copy, reproduce, and distribute this Software for any non-commercial purpose, subject to the restrictions in this MSR-LA. Some purposes which can be non-commercial are teaching, academic research, public demonstrations and personal experimentation. You may also distribute this Software with books or other teaching materials, or publish the Software on websites, that are intended to teach the use of the Software for academic or other non-commercial purposes.
//You may not use or distribute this Software or any derivative works in any form for commercial purposes. Examples of commercial purposes would be running business operations, licensing, leasing, or selling the Software, distributing the Software for use with commercial products, using the Software in the creation or use of commercial products or any other activity which purpose is to procure a commercial gain to you or others.
//If the Software includes source code or data, you may create derivative works of such portions of the Software and distribute the modified Software for non-commercial purposes, as provided herein.  
//If you distribute the Software or any derivative works of the Software, you will distribute them under the same terms and conditions as in this license, and you will not grant other rights to the Software or derivative works that are different from those provided by this MSR-LA. 
//If you have created derivative works of the Software, and distribute such derivative works, you will cause the modified files to carry prominent notices so that recipients know that they are not receiving the original Software. Such notices must state: (i) that you have changed the Software; and (ii) the date of any changes.
//
//In return, we simply require that you agree: 
//1. That you will not remove any copyright or other notices from the Software.
//2. That if any of the Software is in binary format, you will not attempt to modify such portions of the Software, or to reverse engineer or decompile them, except and only to the extent authorized by applicable law. 
//3. That Microsoft is granted back, without any restrictions or limitations, a non-exclusive, perpetual, irrevocable, royalty-free, assignable and sub-licensable license, to reproduce, publicly perform or display, install, use, modify, post, distribute, make and have made, sell and transfer your modifications to and/or derivative works of the Software source code or data, for any purpose.  
//4. That any feedback about the Software provided by you to us is voluntarily given, and Microsoft shall be free to use the feedback as it sees fit without obligation or restriction of any kind, even if the feedback is designated by you as confidential. 
//5.  THAT THE SOFTWARE COMES "AS IS", WITH NO WARRANTIES. THIS MEANS NO EXPRESS, IMPLIED OR STATUTORY WARRANTY, INCLUDING WITHOUT LIMITATION, WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, ANY WARRANTY AGAINST INTERFERENCE WITH YOUR ENJOYMENT OF THE SOFTWARE OR ANY WARRANTY OF TITLE OR NON-INFRINGEMENT. THERE IS NO WARRANTY THAT THIS SOFTWARE WILL FULFILL ANY OF YOUR PARTICULAR PURPOSES OR NEEDS. ALSO, YOU MUST PASS THIS DISCLAIMER ON WHENEVER YOU DISTRIBUTE THE SOFTWARE OR DERIVATIVE WORKS.
//6.  THAT NEITHER MICROSOFT NOR ANY CONTRIBUTOR TO THE SOFTWARE WILL BE LIABLE FOR ANY DAMAGES RELATED TO THE SOFTWARE OR THIS MSR-LA, INCLUDING DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL OR INCIDENTAL DAMAGES, TO THE MAXIMUM EXTENT THE LAW PERMITS, NO MATTER WHAT LEGAL THEORY IT IS BASED ON. ALSO, YOU MUST PASS THIS LIMITATION OF LIABILITY ON WHENEVER YOU DISTRIBUTE THE SOFTWARE OR DERIVATIVE WORKS.
//7.  That we have no duty of reasonable care or lack of negligence, and we are not obligated to (and will not) provide technical support for the Software.
//8.  That if you breach this MSR-LA or if you sue anyone over patents that you think may apply to or read on the Software or anyone's use of the Software, this MSR-LA (and your license and rights obtained herein) terminate automatically.  Upon any such termination, you shall destroy all of your copies of the Software immediately.  Sections 3, 4, 5, 6, 7, 8, 11 and 12 of this MSR-LA shall survive any termination of this MSR-LA.
//9.  That the patent rights, if any, granted to you in this MSR-LA only apply to the Software, not to any derivative works you make.
//10. That the Software may be subject to U.S. export jurisdiction at the time it is licensed to you, and it may be subject to additional export or import laws in other places.  You agree to comply with all such laws and regulations that may apply to the Software after delivery of the software to you.
//11. That all rights not expressly granted to you in this MSR-LA are reserved.
//12. That this MSR-LA shall be construed and controlled by the laws of the State of Washington, USA, without regard to conflicts of law.  If any provision of this MSR-LA shall be deemed unenforceable or contrary to law, the rest of this MSR-LA shall remain in full effect and interpreted in an enforceable manner that most nearly captures the intent of the original language. 
//----------------------------------------------------------------------------

/* ---------------------------------------------------------------------------
 * Project       : Groundhog : A Serial ATA Host Bus Adapter (HBA) for FPGAs
 * Version       : v0.2
 * Author        : Ken Eguro <eguro@microsoft.com>
 * Module        : ethernetController
 * Created       : April 18 2012
 * Last Update   : November 20 2013
 * ---------------------------------------------------------------------------
 * Description   : This is the ethernet controller block.
 *                 It is a modified version of the ethernetController.v file in the SIRC v1.0 codebase.  
 *                 For more details regarding SIRC please go to 
 *                 http://research.microsoft.com/en-us/downloads/d335458e-c241-4845-b0ef-c587c8d29796/
 * ---------------------------------------------------------------------------
 * Changelog     : none
 * ------------------------------------------------------------------------- */

`timescale 1ns / 1ps
`default_nettype none

  module ethernetController 
    #(
      //************ Input and output block memory parameters
      //The user's circuit communicates with the input and output memories as N-byte chunks
      parameter INMEM_USER_BYTE_WIDTH = 1,
      parameter OUTMEM_USER_BYTE_WIDTH = 1,
    
      //How many of the 32-bit address lines do the input and output buffers actually use?
      parameter INMEM_USER_ADDRESS_WIDTH = 17,
      parameter OUTMEM_USER_ADDRESS_WIDTH = 13,
    
      //Does the user side of the memory have extra registers?
      parameter INMEM_USER_REGISTER = 1,
    
      //What MAC address should the FPGA use?
      parameter MAC_ADDRESS = 48'hAAAAAAAAAAAA
      )
   (
    input                                        controllerSideClock, //This clock runs the LocalLink FIFOs and the controller side of the memory - must be >= 125MHz
    input                                        reset, //Hard reset for the controller

    //Interface to eth<->LocalLink module
    input [7:0]                                  rx_ll_data_in, // Input data 
    input                                        rx_ll_sof_in, // Input start of frame
    input                                        rx_ll_eof_in, // Input end of frame
    input                                        rx_ll_src_rdy_in, // Input source ready (emac module)
    output reg                                   rx_ll_dst_rdy_out, // Input receiver ready (this module)

    output [7:0]                                 tx_ll_data_out, // Output data
    output reg                                   tx_ll_sof_out, // Output start of frame
    output reg                                   tx_ll_eof_out, // Output end of frame
    output reg                                   tx_ll_src_rdy_out, // Output source ready (this module)
    input                                        tx_ll_dst_rdy_in, // Output receiver ready (emac module)
   
    //SystemACE interface
    input                                        sysACE_CLK, //33 MHz clock
    output reg [6:0]                             sysACE_MPADD, //SystemACE Address
    inout [15:0]                                 sysACE_MPDATA, //SystemACE Data
    output                                       sysACE_MPCE, //SystemACE active low chip enable
    output reg                                   sysACE_MPWE, //SystemACE active low write enable
    output reg                                   sysACE_MPOE, //SystemACE active low output enable
    //input       sysACE_MPBRDY,             //SystemACE active high buffer ready signal - currently unused
    //input       sysACE_MPIRQ,             //SystemACE active high interrupt request - currently unused
   
    //Interface to user logic
    input                                        userInterfaceClock, //This is the clock to which the user circuit's register file, memories accesses, and reset are synchronized
    output reg                                   userLogicReset, //Reset for the user-side logic.  Will be asserted when the reset for the controller is asserted
    // or when the controller receives a soft reset command over the ethernet.
    //A user application can only check the status of the run register and reset it to zero
    output                                       userRunValue, //Run register value
    input                                        userRunClear, //Does the user circuit want to reset the run register? (active high)
   
    //User interface to parameter register file
    input                                        register32CmdReq, //Parameter register handshaking request signal
    output                                       register32CmdAck, //Parameter register handshaking acknowledgment signal
    input [31:0]                                 register32WriteData, //Parameter register write data
    input [7:0]                                  register32Address, //Parameter register address
    input                                        register32WriteEn, //Parameter register write enable
    output reg                                   register32ReadDataValid, //Indicates that a read request has returned with data
    output [31:0]                                register32ReadData, //Parameter register read data
   
    //User interface to input memory
    input                                        inputMemoryReadReq, //Input memory handshaking request signal
    output                                       inputMemoryReadAck, //Input memory handshaking acknowledgment signal
    input [(INMEM_USER_ADDRESS_WIDTH - 1):0]     inputMemoryReadAdd, //Input memory read address line
    output                                       inputMemoryReadDataValid, //Indicates that a read request has returned with data
    output [((INMEM_USER_BYTE_WIDTH * 8) - 1):0] inputMemoryReadData, //Input memory read data line
   
    //Output memeory connections
    input                                        outputMemoryWriteReq, //Output memory handshaking request signal
    output                                       outputMemoryWriteAck, //Output memory handshaking acknowledgment signal
    input [(OUTMEM_USER_ADDRESS_WIDTH - 1):0]    outputMemoryWriteAdd, //Output memory write address line
    input [((OUTMEM_USER_BYTE_WIDTH * 8) - 1):0] outputMemoryWriteData, //Output memory write data line
    input [(OUTMEM_USER_BYTE_WIDTH - 1):0]       outputMemoryWriteByteMask //Output memory write byte mask
    );
   
   //These are parameters that are specific to the controller side
   //The controller side always communicates with the input and output memories over single bytes,
   // so we can figure out what the correct sizes should be based on the user's interface.
   //To do this, we need a log base 2 calculation for powers of 2
   function integer logb2;
      input integer                              val;
      begin
         val = val >> 1;
         for(logb2 = 0; val > 0; logb2 = logb2+1) begin
            val = val >> 1;
         end
      end
   endfunction

   localparam OUTMEM_LOG_USER_BYTE_WIDTH = logb2(OUTMEM_USER_BYTE_WIDTH);
   localparam INMEM_CONTROLLER_ADDR_WIDTH = INMEM_USER_ADDRESS_WIDTH + logb2(INMEM_USER_BYTE_WIDTH);
   localparam OUTMEM_CONTROLLER_ADDR_WIDTH = OUTMEM_USER_ADDRESS_WIDTH + logb2(OUTMEM_USER_BYTE_WIDTH);

   
   //**********Ethernet rx/tx controller logic
   //FSM states of the receiver
   localparam IDLE = 0;        // Not servicing any request right now
   localparam RECEIVING_REQ = 1;     // Pulling out the header from a new packet
   localparam PROCESS_REQ = 2;      // Pull in command byte to decide what kind of packet this is
   localparam RECEIVE_OUTPUT_MEM_READ = 3;  // Pulling out the read address and read length of a read request
   localparam PROCESS_OUTPUT_MEM_READ = 4;  // Waiting to issue the read to the TX FSM
   localparam RECEIVE_INPUT_MEM_WRITE = 5;  // Pulling out the write address and write length of a write request
   localparam PROCESS_INPUT_MEM_WRITE = 6;  // Pulling out N bytes of write data from RX FIFO
   localparam SEND_INPUT_MEM_WRITE_ACK = 7; // Waiting to issue a write ack to the TX FSM
   localparam RECEIVE_REG32_READ = 8;   // Pulling 1 byte of register address from RX FIFO
   localparam RECEIVE_REG32_WRITE = 9;   // Pulling 5 bytes of register address and data from RX FIFO
   localparam REG32_TRANSACTION = 10;   // Reading or writing to the register-32 file
   localparam SEND_REG32_ACK = 11;    // Waiting to issue a register-32 transaction ack to the TX FSM
   localparam RECEIVE_CONFIG_CF = 12;   // Pulling 1 byte of configuration address from RX FIFO
   localparam SEND_CONFIG_CF_ACK = 13;   // Waiting to issue a config CF ack to the TX FSM then send the config command to the SystemACE fifo
   localparam SEND_SA_COMMAND = 14;    // Waiting to issue a command to the SystemACE fifo
   localparam RECEIVE_SA_REG_WRITE = 15;  // Pulling 1 byte of register address and 2 bytes of data from RX FIFO
   localparam SEND_SA_REG_WRITE_ACK = 16;  // Waiting to issue a register write ack to the TX FSM then send the write command to the SystemACE fifo
   localparam RECEIVE_SA_REG_READ = 17;   // Pulling 1 byte of register address from RX FIFO
   localparam SEND_SA_REG_READ = 18;    // Waiting to issue a register read command to the SystemACE fifo
   localparam SEND_SA_REG_READ_DATA = 19;  // Waiting to issue an ack to the TX FSM, then send the config command to the SystemACE fifo
   localparam SEND_RESET_ACK = 20;    // Waiting to issue a soft reset ack to the TX FSM
   localparam RECEIVE_ERROR = 21;     // Something went wrong, so end an error message
   localparam RECEIVE_EMPTY_PACKET = 22;  // For whatever the reason, empty the rest of this packet
   
   //Errors of the receiver
   localparam RECEIVE_ERROR_PACKET_LENGTH = 0;    // This error occurs if we get a packet too short to be a complete command
   localparam RECEIVE_ERROR_COMMAND = 1;      // This error occurs if we get an invalid command byte
   localparam RECEIVE_ERROR_READ_LENGTH = 2;     // This error occurs when we get a read command, but it's not the correct length packet
   localparam RECEIVE_ERROR_READ_RUNNING = 3;     // This error occurs when we get a read command, but the user application is still running
   localparam RECEIVE_ERROR_WRITE_LENGTH = 4;     // This error occurs when we get a write command, but it's not the correct length packet
   localparam RECEIVE_ERROR_WRITE_RUNNING = 5;    // This error occurs when we get a write command, but the user application is still running
   localparam RECEIVE_ERROR_WRITE_AND_EXECUTE_RUNNING = 6;// This error occurs when we get a write and execute command, but the user application is still running
   localparam RECEIVE_ERROR_WRITE_AND_EXECUTE_LENGTH = 7; // This error occurs when we get a write and execute command, but it's not the correct length packet
   localparam RECEIVE_ERROR_REG32_READ_LENGTH = 8;   // This error occurs when we get a reg32 read command, but it's not the correct length packet
   localparam RECEIVE_ERROR_REG32_READ_RUNNING = 9;   // This error occurs when we get a reg32 read command, but the user application is still running
   localparam RECEIVE_ERROR_REG32_WRITE_LENGTH = 10;  // This error occurs when we get a reg32 write command, but it's not the correct length packet
   localparam RECEIVE_ERROR_REG32_WRITE_RUNNING = 11;  // This error occurs when we get a reg32 write command, but the user application is still running
   localparam RECEIVE_ERROR_SYSACE_CONFIG_LENGTH = 12;  // This error occurs when we get a SystemACE configure command, but it's not the correct length packet
   localparam RECEIVE_ERROR_SYSACE_CONFIG_RUNNING = 13; // This error occurs when we get a SystemACE configure command, but the user application is still running
   localparam RECEIVE_ERROR_SYSACE_CONFIG_ADDRESS = 14; // This error occurs when we get a SystemACE configure command, but the address is not [0-7]
   localparam RECEIVE_ERROR_SA_REG_WRITE_LENGTH = 15;  // This error occurs when we get a SystemACE reg write command, but it's not the correct length packet
   localparam RECEIVE_ERROR_SA_REG_WRITE_RUNNING = 16;  // This error occurs when we get a SystemACE reg write command, but the user application is still running
   localparam RECEIVE_ERROR_SA_REG_WRITE_ADDRESS = 17;  // This error occurs when we get a SystemACE reg write command, but the address is not [0-47]
   localparam RECEIVE_ERROR_SA_REG_READ_LENGTH = 18;  // This error occurs when we get a SystemACE reg read command, but it's not the correct length packet
   localparam RECEIVE_ERROR_SA_REG_READ_RUNNING = 19;  // This error occurs when we get a SystemACE reg read command, but the user application is still running
   localparam RECEIVE_ERROR_SA_REG_READ_ADDRESS = 20;  // This error occurs when we get a SystemACE reg read command, but the address is not [0-47]
   localparam RECEIVE_ERROR_RESET_LENGTH = 21;    // This error occurs when we get a soft reset command, but it's not the correct length packet

   //FSM states of the transmitter
   localparam PROCESS_READ_SEND_HEADER = 1;  // Pushing out the header of the current read request
   localparam PROCESS_READ_SEND_DATA = 2;   // Servicing a read request
   localparam PROCESS_SEND_TERM_HEADER = 3;  // Pushing out only a header + some small packet (error or ack)
   localparam INIT_WAIT_FOR_DONE = 4;    // Before we are waiting until the user circuit is done execution
   localparam WAIT_FOR_DONE = 5;      // Waiting until the user circuit is done execution


   //SystemACE commands
   localparam CONFIGFROMCF = 0;
   //localparam WRITERAMTOCF = 1;
   localparam WRITE_SA_REG = 2;
   localparam READ_SA_REG = 3;


   //One last constant
   localparam MAX_PACKET_LENGTH = 1486;    // This defines the maximum length output data transfer we support
   // This should be between 6 (minimum read of 1 byte + 5 byte intro) and 1486 bytes
   //  for standard size frames.
   // Notice that the max length really only applies to read responses, since
   //  we assume that the host generating write requests will respect the packet length

   //Ethernet packet formats:
   // I - Commands from host PC:
   //  Read/write memory
   //  Read/write registers
   //  Read/write to SystemACE registers
   // Formats for all commands
   // Dest address - 6 bytes = FPGA MAC address
   // Source address - 6 bytes = source MAC address
   // Packet length - 2 bytes for all ethernet frames
   //
   // Payload for memory reads:
   // Byte [0] - 'r'7
   // Byte [1 - 4] - base address
   // Byte [5 - 8] - length of read
   //
   // Payload for memory writes:
   // Byte [0] - 'w'
   // Byte [1 - 4] - base address
   // Byte [5 - 8] - length of write
   // Byte [9+] data
   //
   // Payload for memory write & run commands:
   // Byte [0] - 'g'
   // Byte [1 - 4] - base address
   // Byte [5 - 8] - length of write
   // Byte [9+] data
   //
   // Payload for read register-32
   // Byte [0] - 'y'
   // Byte [1] - register address
   //
   // Payload for write register-32
   // Byte [0] - 'k'
   // Byte [1] - register address
   // Byte [2 - 5] - register value
   //
   // Dedicated purpose registers
   // #255 - not in reg file, 1-bit run register
   //
   // Payload for configure from SystemACE CF
   // Byte [0] - 'c'
   // Byte [1] - configuration # (0-7)
   //
   // Payload for SystemACE register write
   // Byte [0] - 's'
   // Byte [1] - register number
   // Byte [2, 3] - 16-bit register value
   //
   // Payload for SystemACE register read
   // Byte [0] - 'a'
   // Byte [1] - register number
   //
   // Payload for reset command
   // Byte [0] - 'm'
   //
   // II - Responses from board:
   // Errors, read memory, write memory ack, read register-32, write register-32 ack
   // Dest address - 6 bytes = MAC address of request
   // Source address - 6 bytes = FPGA MAC address
   // Packet length - 2 bytes for errors, 9 bytes for memory write acks, 5 + # of bytes read for memory reads
   //       6 bytes for register-32 read or write acks, 1 byte for start or stop ack
   //
   // Payload for errors:
   // Byte [0] - 'e'
   // Byte [1] - error code
   //
   // Payload for memory reads:
   // Byte [0] - 'r'
   // Byte [1 - 4] - starting address
   // Byte [5+] - data
   //
   // Payload for memory write acks:
   // Byte [0] - 'w'
   // Byte [1-4] - starting address
   // Byte [5-8] - # of bytes
   //
   // Payload for memory write & run acks:
   // Byte [0] - 'g'
   // Byte [1-4] - starting address
   // Byte [5-8] - # of bytes remaining in output readback, including
   //      payload of this packet
   // Byte [9+] - data
   //
   // Payload for read register-32 acks:
   // Byte [0] - 'y'
   // Byte [1] - register address
   // Byte [2-5] - register value
   //
   // Payload for write register-32 acks:
   // Byte [0] - 'k'
   // Byte [1] - register address
   // Byte [2-5] - register value
   //
   // Payload for configure from SystemACE CF ack
   // Byte [0] - 'c'
   // Byte [1] - configuration # (0-7)
   //
   // Payload for SystemACE register write ack
   // Byte [0] - 's'
   // Byte [1] - register number
   // Byte [2, 3] - 16-bit register value
   //
   // Payload for SystemACE register read
   // Byte [0] - 'a'
   // Byte [1] - register number
   // Byte [2, 3] - 16-bit register value
   //
   // Payload for reset command
   // Byte [0] - 'm'
   //
   //This is written under the assumption (this seems correct based on 
   // ug194.pdf) that the LocalLink RX FIFO will only contain whole, good packets.
   //Bad frames and overflows are avoided because the entire frame is received and inspected
   // before getting put into the FIFO.
   //Thus, no error checking is done.

   //Signal declaration for receiver
   //Receiver state registers
   reg [4:0] rx_state;
   reg [3:0] rx_header_counter;
   reg [2:0] rx_command_counter;
   //reg [7:0] rx_error_status;
   reg [6:0] rx_error_status;       //Modified to remove warning, original saved for clarity

   //Header input buffers
   //reg [47:0] rx_header_buffer_dest_add;
   reg [39:0] rx_header_buffer_dest_add;   //Modified to remove warning, original saved for clarity
   reg [47:0] rx_header_buffer_src_add;
   reg [15:0] rx_header_buffer_len;

   //Packet input buffers - memory read/wrtie
   reg [31:0] rx_mem_address;
   reg [31:0] rx_mem_length;

   //Packet input buffers - reg read/write
   reg [7:0]  rx_reg_address;
   reg [31:0] rx_reg_value;

   //Packet input buffers - SystemACE reg read/write
   //reg [7:0] rx_SA_reg_address;      //Removed to remove warning, original saved for clarity
   reg [15:0] rx_SA_reg_value;

   //We might need to save the original starting address
   // and length if we want to ack a write
   reg [31:0] rx_mem_start_address;
   reg [31:0] rx_mem_start_length;
   
   //Signal declarations for transmitter
   //Transmitter state registers
   reg [2:0]  tx_state;
   reg [4:0]  tx_header_counter;
   reg [31:0] tx_curr_mem_address; //current address we are reading from
   reg [31:0] tx_curr_bytes_left;  //number of bytes left in current read
   reg [15:0] tx_read_len;    //number of bytes left in current packet

   //What is the largest address in the output memory the user circuit wrote to?
   reg [(OUTMEM_USER_ADDRESS_WIDTH - 1):0] tx_max_output_address; 
   reg                                     resetMaxOutputAddress;
   

   //Is the transmit logic trying to do a readback following a write & execute command?
   reg                                     tx_readback_after_execute;

   //Header output buffers
   reg [47:0]                              tx_header_buffer_dest_add;
   reg [47:0]                              tx_header_buffer_src_add;
   reg [15:0]                              tx_header_buffer_len;
   reg [71:0]                              tx_packet_payload;

   //These registers are used to keep the header information
   // just in case we need to split the read into more than one packet
   reg [47:0]                              tx_save_dest_add;

   //This register is to deal with the latency in the memory
   reg [(OUTMEM_CONTROLLER_ADDR_WIDTH - 1):0] oldReadAddress;
   
   wire [(OUTMEM_CONTROLLER_ADDR_WIDTH - 1):0] outputMemReadAddressIn;
   wire [7:0]                                  outputMemReadDataOut;
   
   //Should I execute after I receive this write command?
   reg                                         executeAfterReceive;

   //Run register
   //There is one register on the controller side (that will react instantly to
   // the controller-side signals userRunRegisterSet, softReset and
   // in a delayed manner to user-side signal userRunClear) and another register
   // on the user side (that will react instantly to the user side signal
   // userRunClear and in a delayed manner to the controller -side signals 
   // userRunRegisterSet and softReset
   reg                                         userRunRegisterControllerSide;
   reg                                         userRunRegisterUserSide;
   assign userRunValue = userRunRegisterUserSide;
   wire                                        userRunRegisterSet;

   //Soft reset register
   reg                                         softReset;
   
   //Registers to make hard reset synchronous (needed to resolve issue with timing constraints)
   reg                                         resetUserClockDomain;
   reg                                         resetControllerClockDomain;
   
   //Wires for input and output memory
   wire [((INMEM_USER_BYTE_WIDTH * 8) - 1):0]  inputMemoryExternalReadData;
   wire [7:0]                                  outputMemoryInternalReadData;
   
   //Wires for parameter registers
   wire [31:0]                                 register32ExternalReadData;
   reg                                         register32InternalWriteEnable;
   wire [31:0]                                 register32InternalReadData;
   
   //Wires and regs to and from SystemACE fifos
   reg [1:0]                                   ethToFifoCommand;
   reg [6:0]                                   ethToFifoAddress;
   reg [15:0]                                  ethToFifoData;
   reg                                         ethToFifoWrite;
   wire                                        toSysACEFifoFull;
   //wire [1:0] fifoToEthCommand;    //Removed to remove warning, original saved for potential future use
   wire [6:0]                                  fifoToEthAddress;
   wire [15:0]                                 fifoToEthData;
   reg                                         fifoToEthRead;
   wire                                        fromSysACEFifoEmpty;
   
   initial begin
      rx_state = IDLE;
      rx_ll_dst_rdy_out = 0;
      rx_header_counter = 0;
      rx_command_counter = 0;
      rx_error_status = 0;

      tx_state = IDLE;
      tx_ll_sof_out = 1;
      tx_ll_eof_out = 1;
      tx_ll_src_rdy_out = 1;
      register32InternalWriteEnable = 0;
      
      executeAfterReceive = 0;
      tx_readback_after_execute = 0;
      
      ethToFifoWrite = 0;
      fifoToEthRead = 0;
      
      softReset = 0;
      resetMaxOutputAddress = 0;
   end  
   always @(posedge controllerSideClock) begin
      if(resetControllerClockDomain == 1) begin
         rx_state <= IDLE;
         rx_ll_dst_rdy_out <= 0;
         
         tx_state <= IDLE;
         tx_ll_sof_out <= 1;
         tx_ll_eof_out <= 1;
         tx_ll_src_rdy_out <= 1;
         register32InternalWriteEnable <= 0;

         executeAfterReceive <= 0;
         tx_readback_after_execute <= 0;
         
         ethToFifoWrite <= 0;
         fifoToEthRead <= 0;
         
         softReset <= 0;
         resetMaxOutputAddress <= 0;
      end
      else begin
         case(rx_state)
           IDLE: begin
              ethToFifoWrite <= 0;
              fifoToEthRead <= 0;
              softReset <= 0;
              register32InternalWriteEnable <= 0;
              resetMaxOutputAddress <= 0;
              
              //Don't do anything until the start of frame and ready signals go low
              if(rx_ll_src_rdy_in == 0 && rx_ll_sof_in == 0) begin
                 rx_state <= RECEIVING_REQ;
                 rx_header_buffer_len[7:0] <= rx_ll_data_in;
                 rx_header_counter <= 12;
              end
           end
           RECEIVING_REQ: begin
              //If there is valid data, add it to the header buffer
              if(rx_ll_src_rdy_in == 0) begin
                 //Shift data into the header buffer
                 //rx_header_buffer_dest_add <= {rx_header_buffer_dest_add[39:0], rx_header_buffer_src_add[47:40]};  
                 rx_header_buffer_dest_add <= {rx_header_buffer_dest_add[31:0], rx_header_buffer_src_add[47:40]}; //Modified to remove warning, original saved for clarity 
                 rx_header_buffer_src_add <= {rx_header_buffer_src_add[39:0], rx_header_buffer_len[15:8]};
                 rx_header_buffer_len <= {rx_header_buffer_len[7:0], rx_ll_data_in};

                 rx_header_counter <= rx_header_counter - 1;
                 
                 //See if we are done loading the header
                 if(rx_header_counter == 0) begin
                    //See if this packet is for our MAC address
                    if({rx_header_buffer_dest_add[39:0], rx_header_buffer_src_add[47:40]} == MAC_ADDRESS) begin
                       //See if this packet is long enough to be a valid request - at least a command byte
                       //Easy enough to remove this check if need be.
                       if({rx_header_buffer_len[7:0], rx_ll_data_in} >= 1) begin
                          rx_state <= PROCESS_REQ;
                       end
                       else begin
                          //Otherwise, this can't be a valid command packet
                          rx_state <= RECEIVE_ERROR;
                          rx_error_status <= RECEIVE_ERROR_PACKET_LENGTH;
                          rx_ll_dst_rdy_out <= 1;
                       end
                    end
                    else begin
                       //This packet isn't for us, so just remove the packet from the FIFO
                       rx_state <= RECEIVE_EMPTY_PACKET;
                    end
                 end
              end
           end
           PROCESS_REQ: begin
              //Grab the command byte
              //If there is valid data, see what the command is
              if(rx_ll_src_rdy_in == 0) begin
                 //We grab 1 byte of packet data
                 if(rx_ll_data_in == 8'h72) begin //Data == 'r'
                    //We want to do an output memory read, so
                    //1) Make sure that there are exactly 9 bytes in this packet
                    // (command byte and 4 bytes of address and 4 bytes of length)
                    //2) Make sure that the run register is low
                    if(rx_header_buffer_len != 9) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_READ_LENGTH;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else if(userRunRegisterControllerSide == 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_READ_RUNNING;
                       rx_ll_dst_rdy_out <= 1;   
                    end
                    else begin
                       rx_state <= RECEIVE_OUTPUT_MEM_READ;
                       rx_command_counter <= 7;
                    end
                 end
                 else if(rx_ll_data_in == 8'h77) begin //Data == 'w'
                    //This is an input memory write, so make sure that the run register is low
                    if(userRunRegisterControllerSide == 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_WRITE_RUNNING;
                       rx_ll_dst_rdy_out <= 1;   
                    end
                    else begin
                       rx_state <= RECEIVE_INPUT_MEM_WRITE;
                       rx_command_counter <= 7;
                       
                       //This is a regular write
                       executeAfterReceive <= 0;
                    end
                 end
                 else if(rx_ll_data_in == 8'h79) begin //Data == 'y'
                    //This is a register-32 read so
                    //1) Make sure that there are exactly 2 bytes in this packet
                    // (command byte and register address)
                    //2) Make sure that the user circuit isn't running (is this actually true?)
                    // maybe we want to check on the status of the system?
                    if(rx_header_buffer_len != 2) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_REG32_READ_LENGTH;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    //We have to be able to at least do a register read while the system is running or we won't
                    // be able to check the run register.  Thus, even if the userRunRegister is high, we will 
                    // wait to see what register we are asking for before erroring out.
                    else begin
                       rx_state <= RECEIVE_REG32_READ;
                       //rx_error_status <= 8'h79;
                       rx_error_status <= 7'h79;    //Modified to remove warning, original saved for clarity
                    end
                 end
                 else if(rx_ll_data_in == 8'h6B) begin //Data == 'k'
                    //This is a register-32 write so
                    //1) Make sure that there are exactly 6 bytes in this packet
                    // (command byte, register address and 32-bit register value)
                    //2) Make sure that the user program isn't running
                    if(rx_header_buffer_len != 6) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_REG32_WRITE_LENGTH;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else if(userRunRegisterControllerSide == 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_REG32_WRITE_RUNNING;
                       rx_ll_dst_rdy_out <= 1;   
                    end
                    else begin
                       rx_state <= RECEIVE_REG32_WRITE;
                       rx_command_counter <= 4;
                       //rx_error_status <= 8'h6B;
                       rx_error_status <= 7'h6B;    //Modified to remove warning, original saved for clarity 
                    end
                 end
                 else if(rx_ll_data_in == 8'h67) begin //Data == 'g'
                    //This is an input memory write & execute, so make sure that the run register is low
                    if(userRunRegisterControllerSide == 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_WRITE_AND_EXECUTE_RUNNING;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else begin
                       rx_state <= RECEIVE_INPUT_MEM_WRITE;
                       rx_command_counter <= 7;

                       //This is a write & execute
                       executeAfterReceive <= 1;
                    end
                 end
                 else if(rx_ll_data_in == 8'h63) begin //Data == 'c'
                    //This is a configure from SystemACE CF command
                    //1) Make sure that there are exactly 2 bytes in this packet
                    // (command byte and configuration address)
                    //2) Make sure that the user circuit isn't running
                    if(rx_header_buffer_len != 2) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_SYSACE_CONFIG_LENGTH;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else if(userRunRegisterControllerSide == 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_SYSACE_CONFIG_RUNNING;
                       rx_ll_dst_rdy_out <= 1;   
                    end
                    else begin
                       rx_state <= RECEIVE_CONFIG_CF;
                    end
                 end
                 else if(rx_ll_data_in == 8'h73) begin //Data == 's'
                    //This is a SystemACE register write
                    //1) Make sure that there are exactly 4 bytes in this packet
                    // (command byte, register address and 2 bytes of data)
                    //2) Make sure that the user circuit isn't running
                    if(rx_header_buffer_len != 4) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_SA_REG_WRITE_LENGTH;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else if(userRunRegisterControllerSide == 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_SA_REG_WRITE_RUNNING;
                       rx_ll_dst_rdy_out <= 1;   
                    end
                    else begin
                       rx_state <= RECEIVE_SA_REG_WRITE;
                       rx_command_counter <= 2;
                    end
                 end
                 else if(rx_ll_data_in == 8'h61) begin //Data == 'a'
                    //This is a SystemACE register read
                    //1) Make sure that there are exactly 2 bytes in this packet
                    // (command byte, register address)
                    //2) Make sure that the user circuit isn't running
                    if(rx_header_buffer_len != 2) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_SA_REG_READ_LENGTH;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else if(userRunRegisterControllerSide == 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_SA_REG_READ_RUNNING;
                       rx_ll_dst_rdy_out <= 1;   
                    end
                    else begin
                       rx_state <= RECEIVE_SA_REG_READ;
                    end
                 end
                 else if(rx_ll_data_in == 8'h6d) begin //Data == 'm'
                    //This is a soft reset command for the user's circuit
                    //Make sure that there are exactly 1 bytes in this packet
                    // (command byte)
                    if(rx_header_buffer_len != 1) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_RESET_LENGTH;
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else begin
                       //Start asserting the soft reset signal
                       softReset <= 1;
                       
                       //If the TX is not doing anything, let's send the ack directly
                       if(tx_state == IDLE) begin
                          tx_ll_sof_out <= 0;
                          tx_ll_src_rdy_out <= 0;
                          
                          //Send out 14 bytes of header and 1 bytes of payload
                          tx_state <= PROCESS_SEND_TERM_HEADER;
                          tx_header_counter <= 14;
                          tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                          tx_header_buffer_src_add <= MAC_ADDRESS;
                          tx_header_buffer_len <= 1;

                          //Send an 'm'
                          tx_packet_payload[71:64] <= 8'h6d;

                          rx_state <= IDLE; 
                       end
                       else begin
                          //Otherwise, we have to spin until the TX isn't busy
                          //Stop grabbing data from the input
                          rx_ll_dst_rdy_out <= 1;
                          rx_state <= SEND_RESET_ACK;
                       end
                    end
                 end
                 else begin
                    //This isn't a command that we recognize, so send an error message
                    rx_state <= RECEIVE_ERROR;
                    rx_error_status <= RECEIVE_ERROR_COMMAND;
                    rx_ll_dst_rdy_out <= 1;
                 end
              end
           end
           RECEIVE_OUTPUT_MEM_READ: begin 
              //Pull out the 4 byte of read address and 4 bytes of read length
              //If there is valid data, grab the address or length value
              if(rx_ll_src_rdy_in == 0) begin
                 //Decrement the command counter
                 rx_command_counter <= rx_command_counter - 1;

                 //We grab 1 byte of packet data
                 //Shift data into the memory address/length registers
                 rx_mem_address <= {rx_mem_address[23:0], rx_mem_length[31:24]};
                 rx_mem_length <= {rx_mem_length[23:0], rx_ll_data_in}; 
                 
                 if(rx_command_counter == 0) begin
                    //If the TX FSM is not doing anything, we can send the request directly
                    if(tx_state == IDLE) begin
                       tx_ll_sof_out <= 0;
                       tx_ll_src_rdy_out <= 0;
                       
                       tx_curr_mem_address <= {rx_mem_address[23:0], rx_mem_length[31:24]};
                       tx_curr_bytes_left <= {rx_mem_length[23:0], rx_ll_data_in};
                       
                       //Load the tx buffers - 14 bytes of header and 5 bytes of payload intro
                       //Also, load the read counter
                       tx_state <= PROCESS_READ_SEND_HEADER;
                       tx_header_counter <= 18;
                       tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                       tx_header_buffer_src_add <= MAC_ADDRESS;
                       
                       //This will be a regular readback
                       tx_readback_after_execute <= 0;
                       
                       if({rx_mem_length[23:0], rx_ll_data_in} > (MAX_PACKET_LENGTH - 5)) begin
                          //We will need to send this as at least 2 separate packets because
                          // the payload intro plus the read data will be too long.
                          //The packet length will be the maximum allowed and
                          // but the data read length for this packet will be the max - 5 (intro).
                          //Also, save the dest address because we'll need it
                          tx_header_buffer_len <= MAX_PACKET_LENGTH;
                          tx_read_len <= (MAX_PACKET_LENGTH - 5);
                          tx_save_dest_add <= rx_header_buffer_src_add;
                       end
                       else begin
                          //This will only take one packet, so just set up the output buffer and counter
                          //The entire packet will be 5 bytes longer than the actual read because
                          // of the intro
                          tx_header_buffer_len <= {rx_mem_length[7:0], rx_ll_data_in} + 5;
                          tx_read_len <= {rx_mem_length[7:0], rx_ll_data_in};
                       end
                       
                       //'r' followed by the starting address
                       tx_packet_payload[71:64] <= 8'h72;
                       tx_packet_payload[63:32] <= {rx_mem_address[23:0], rx_mem_length[31:24]};
                       
                       rx_state <= IDLE;
                    end
                    else begin
                       //Otherwise, we have to spin until it is done
                       //Don't grab any more data till we stop spinning
                       rx_ll_dst_rdy_out <= 1;
                       rx_state <= PROCESS_OUTPUT_MEM_READ;
                    end
                 end
              end
           end
           PROCESS_OUTPUT_MEM_READ: begin
              //Wait until the TX is done with what it is currently doing
              if(tx_state == IDLE) begin
                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 tx_curr_mem_address <= rx_mem_address;
                 tx_curr_bytes_left <= rx_mem_length;
                 
                 //Send out 14 bytes of header, and 5 bytes of payload intro
                 tx_state <= PROCESS_READ_SEND_HEADER;
                 tx_header_counter <= 18;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 
                 //This will be a regular readback
                 tx_readback_after_execute <= 0;

                 if(rx_mem_length > MAX_PACKET_LENGTH) begin
                    //We will need to send this as at least 2 separate packets because
                    // the payload intro plus the read data will be too long.
                    //The packet length will be the maximum allowed and
                    // but the data read length for this packet will be the max - 5 (intro).
                    //Also, save the dest address because we'll need it
                    tx_header_buffer_len <= MAX_PACKET_LENGTH;
                    tx_read_len <= (MAX_PACKET_LENGTH - 5);
                    tx_save_dest_add <= rx_header_buffer_src_add;
                 end
                 else begin
                    //This will only take one packet, so just set up the output buffer and counter
                    //The entire packet will be 5 bytes longer than the actual read because
                    // of the intro
                    tx_header_buffer_len <= rx_mem_length[15:0] + 5;
                    tx_read_len <= rx_mem_length[15:0];       
                 end
                 //'r' followed by the starting address
                 tx_packet_payload[71:64] <= 8'h72;
                 tx_packet_payload[63:32] <= rx_mem_address;
                 
                 //We've stopped spinning, so we are ready to grab more data
                 rx_state <= IDLE;
                 rx_ll_dst_rdy_out <= 0;
              end
           end
           RECEIVE_INPUT_MEM_WRITE: begin
              //Pull out the 4 bytes of write address and 4 bytes of write length
              //If there is valid data, grab the address or length value
              if(rx_ll_src_rdy_in == 0) begin
                 //Decrement the command counter
                 rx_command_counter <= rx_command_counter - 1;

                 //We grab 1 byte of packet data
                 //Shift data into the memory address/length registers
                 rx_mem_address <= {rx_mem_address[23:0], rx_mem_length[31:24]};
                 rx_mem_length <= {rx_mem_length[23:0], rx_ll_data_in}; 
                 rx_mem_start_address <= {rx_mem_address[23:0], rx_mem_length[31:24]};
                 rx_mem_start_length <= {rx_mem_length[23:0], rx_ll_data_in}; 
                 
                 if(rx_command_counter == 0) begin
                    //Make sure that the write request and the packet length line up
                    //The entire packet should be of length N + 1(command byte) + 8 
                    // (address and length bytes)
                    if({rx_mem_length[7:0], rx_ll_data_in} != rx_header_buffer_len - 9) begin
                       rx_state <= RECEIVE_ERROR;
                       if(executeAfterReceive == 1) begin
                          rx_error_status <= RECEIVE_ERROR_WRITE_AND_EXECUTE_LENGTH;
                       end
                       else begin
                          rx_error_status <= RECEIVE_ERROR_WRITE_LENGTH;
                       end
                       rx_ll_dst_rdy_out <= 1;
                    end
                    else begin
                       rx_state <= PROCESS_INPUT_MEM_WRITE;
                    end
                 end
              end    
           end
           PROCESS_INPUT_MEM_WRITE: begin
              // Pull out N bytes of write data from RX FIFO and put them into memory
              //If there is valid data, grab the data value
              if(rx_ll_src_rdy_in == 0) begin
                 rx_mem_length <= rx_mem_length - 1;
                 rx_mem_address  <= rx_mem_address + 1;

                 if(rx_mem_length == 1) begin
                    //We have gotten all of the write data.  
                    // If this is not a write & execute command, try to send a write ack
                    // If this is a write & execute command, try to start the user circuit and put the TX FSM into a waiting mode
                    //If the TX FSM is not doing anything, we can send the request directly
                    if(tx_state == IDLE) begin
                       if(executeAfterReceive == 0)begin
                          // This is just a write command, so send a write ack
                          tx_ll_sof_out <= 0;
                          tx_ll_src_rdy_out <= 0;
                          
                          //Send out 14 bytes of header and 9 bytes of payload
                          tx_state <= PROCESS_SEND_TERM_HEADER;
                          tx_header_counter <= 22;
                          tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                          tx_header_buffer_src_add <= MAC_ADDRESS;
                          tx_header_buffer_len <= 9;
                          //'w' followed by the address and length
                          tx_packet_payload[71:64] <= 8'h77;
                          tx_packet_payload[63:32] <= rx_mem_start_address;
                          tx_packet_payload[31:0] <= rx_mem_start_length;
                       end
                       else begin
                          // This is a write & execute command, so start the user circuit and put the TX FSM into a waiting mode
                          register32InternalWriteEnable <= 1;
                          rx_reg_address <= 8'hFF;
                          rx_reg_value <= 32'h00000001;
                          tx_state <= INIT_WAIT_FOR_DONE;

                          //Set up values for the subsequent read
                          //We always start at output address 0
                          tx_curr_mem_address <= 0;
                          //We don't know what the length of the read will be.
                          //When the circuit comes back, we'll need to fill in tx_curr_bytes_left (maximum output address + 1)

                          //Before we start execution, we should reset the max output address counter
                          //During execution, we will watch the output addresses and record the maximum output address written
                          resetMaxOutputAddress <= 1;
                          
                          //When the tx comes back from waiting, we will want to send back write and execute ack packets
                          //Load the tx buffers - 14 bytes of header and 9 bytes of payload intro (command byte, start address, and # remaining bytes)
                          //Also, load the read counter
                          tx_header_counter <= 22;
                          tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                          tx_header_buffer_src_add <= MAC_ADDRESS;
                          tx_save_dest_add <= rx_header_buffer_src_add;
                          
                          //When the circuit comes back, we'll also need to fill in tx_header_buffer_len (length of payload = 9 + tx_read_len or MAX_PACKET_LENGTH)
                          //When the circuit comes back, we'll also need to fill in tx_read_len (number of data bytes in packet = maximum output address + 1 or MAX_PACKET_LENGTH - 9)
                          
                          //'g' command packet
                          tx_packet_payload[71:64] <= 8'h67;
                          //We always start back at address 0
                          tx_packet_payload[63:32] <= 0;

                          //When the circuit comes back, we'll also need to fill in tx_packet_payload[31:0] (# of remaining read bytes = maximum output address + 1)
                       end                       
                       rx_state <= IDLE;
                    end
                    else begin
                       //The transmit circuit is busy, so let's spin until it is free
                       rx_ll_dst_rdy_out <= 1;
                       rx_state <= SEND_INPUT_MEM_WRITE_ACK;
                    end
                 end
              end
           end
           SEND_INPUT_MEM_WRITE_ACK: begin
              //Wait until the TX is done with what it is currently doing
              if(tx_state == IDLE) begin
                 if(executeAfterReceive == 0)begin
                    // This is just a write command, so send a write ack
                    tx_ll_sof_out <= 0;
                    tx_ll_src_rdy_out <= 0;
                    
                    //Send out 14 bytes of header and 9 bytes of payload
                    tx_state <= PROCESS_SEND_TERM_HEADER;
                    tx_header_counter <= 22;
                    tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                    tx_header_buffer_src_add <= MAC_ADDRESS;
                    tx_header_buffer_len <= 9;
                    //'w' followed by the address and length
                    tx_packet_payload[71:64] <= 8'h77;
                    tx_packet_payload[63:32] <= rx_mem_start_address;
                    tx_packet_payload[31:0] <= rx_mem_start_length;
                 end
                 else begin
                    // This is a write & execute command, so start the user circuit and put the TX FSM into a waiting mode
                    register32InternalWriteEnable <= 1;
                    rx_reg_address <= 8'hFF;
                    rx_reg_value <= 32'h00000001;
                    tx_state <= INIT_WAIT_FOR_DONE;

                    //Set up values for the subsequent read
                    //We always start at output address 0
                    tx_curr_mem_address <= 0;
                    //We don't know what the length of the read will be.
                    //When the circuit comes back, we'll need to fill in tx_curr_bytes_left (maximum output address + 1)

                    //Before we start execution, we should reset the max output address counter
                    //During execution, we will watch the output addresses and record the maximum output address written
                    resetMaxOutputAddress <= 1;
                    
                    //When the tx comes back from waiting, we will also want to send back write and execute ack packets
                    //Load the tx buffers - 14 bytes of header and 9 bytes of payload intro (command byte, start address, and # remaining bytes)
                    //Also, load the read counter
                    tx_header_counter <= 22;
                    tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                    tx_header_buffer_src_add <= MAC_ADDRESS;
                    tx_save_dest_add <= rx_header_buffer_src_add;
                    
                    //When the circuit comes back, we'll also need to fill in tx_header_buffer_len (length of payload = 9 + tx_read_len or MAX_PACKET_LENGTH)
                    //When the circuit comes back, we'll also need to fill in tx_read_len (number of data bytes in packet = maximum output address + 1 or MAX_PACKET_LENGTH - 9)
                    
                    //'g' command packet
                    tx_packet_payload[71:64] <= 8'h67;
                    //We always start back at address 0
                    tx_packet_payload[63:32] <= 0;

                    //When the circuit comes back, we'll need to fill in tx_packet_payload[31:0] (# of remaining read bytes = maximum output address + 1)
                 end 
                 
                 //The RX side can go back to consuming data now.
                 rx_ll_dst_rdy_out <= 0;      
                 rx_state <= IDLE;
              end
           end
           RECEIVE_REG32_READ: begin
              //Pull out the 1 byte of register address
              //If there is valid data, grab the address value
              if(rx_ll_src_rdy_in == 0) begin      
                 //We grab 1 byte of packet data
                 //We aren't grabbing any more input data for a few cycles, so make sure
                 // that the ready signal is high
                 rx_reg_address <= rx_ll_data_in;
                 
                 //Check to see if the userRunRegister is true and we are asking to read a register
                 // that is not the run register
                 if(userRunRegisterControllerSide == 1 && rx_ll_data_in != 8'hFF) begin
                    rx_state <= RECEIVE_ERROR;
                    rx_error_status <= RECEIVE_ERROR_REG32_READ_RUNNING;
                 end
                 else begin
                    rx_state <= REG32_TRANSACTION;  
                    rx_command_counter <= 1;       
                 end
                 rx_ll_dst_rdy_out <= 1;
              end        
           end
           RECEIVE_REG32_WRITE: begin
              //Pull out the 1 byte of register address or data value
              //If there is valid data, grab the value
              if(rx_ll_src_rdy_in == 0) begin
                 //Decrement the command counter
                 rx_command_counter <= rx_command_counter - 1;

                 //We grab 1 byte of packet data
                 //Shift data into the memory address/length registers
                 rx_reg_address <= rx_reg_value[31:24];
                 rx_reg_value <= {rx_reg_value[23:0], rx_ll_data_in};

                 if(rx_command_counter == 0) begin
                    //The register32 file will be written during the next cycle
                    //We aren't grabbing any more input data for a few cycles, so make sure
                    // that the ready signal is high
                    rx_state <= REG32_TRANSACTION;  
                    register32InternalWriteEnable <= 1;
                    rx_command_counter <= 1;
                    rx_ll_dst_rdy_out <= 1;
                 end
              end
           end
           REG32_TRANSACTION: begin
              //If we want to do a write, this first cycle actually does the write
              //If we want to do a read, this first cycle just gets the address to the registers
              //Either way, the second cycle does a read
              rx_command_counter <= rx_command_counter - 1;
              register32InternalWriteEnable <= 0;
              
              if(rx_command_counter == 0) begin
                 //If the TX is not doing anything, let's send the ack directly
                 if(tx_state == IDLE) begin
                    tx_ll_sof_out <= 0;
                    tx_ll_src_rdy_out <= 0;
                    
                    //Send out 14 bytes of header and 6 bytes of payload
                    tx_state <= PROCESS_SEND_TERM_HEADER;
                    tx_header_counter <= 19;
                    tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                    tx_header_buffer_src_add <= MAC_ADDRESS;
                    tx_header_buffer_len <= 6;

                    //either 'y' or 'k' followed by the register address and value
                    //tx_packet_payload[71:64] <= rx_error_status;
                    tx_packet_payload[71:64] <= {1'b0, rx_error_status};  //Modified to remove warning, original saved for clarity
                    tx_packet_payload[63:56] <= rx_reg_address;
                    if(rx_reg_address == 8'hFF) begin
                       tx_packet_payload[55:24] <= {31'd0, userRunRegisterControllerSide};
                    end
                    else begin
                       tx_packet_payload[55:24] <= register32InternalReadData;
                    end
                    
                    rx_ll_dst_rdy_out <= 0;
                    rx_state <= IDLE; 
                 end
                 else begin
                    rx_state <= SEND_REG32_ACK;
                 end
              end
           end
           SEND_REG32_ACK: begin
              //Wait till the TX is not doing anything, then send the ack
              if(tx_state == IDLE) begin
                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 6 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 19;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 6;

                 //either 'y' or 'k' followed by the register address and value
                 //tx_packet_payload[71:64] <= rx_error_status;
                 tx_packet_payload[71:64] <= {1'b0, rx_error_status};  //Modified to remove warning, original saved for clarity
                 tx_packet_payload[63:56] <= rx_reg_address;      
                 if(rx_reg_address == 8'hFF) begin
                    tx_packet_payload[55:24] <= {31'd0, userRunRegisterControllerSide};
                 end
                 else begin
                    tx_packet_payload[55:24] <= register32InternalReadData;
                 end
                 
                 rx_ll_dst_rdy_out <= 0;
                 rx_state <= IDLE; 
              end    
           end

           RECEIVE_CONFIG_CF: begin
              //Pull out the 1 byte of configuration address
              //If there is valid data, grab the address value
              if(rx_ll_src_rdy_in == 0) begin
                 //Make sure that the configuration # is between 0-7
                 if(rx_ll_data_in > 8'd7)begin
                    rx_state <= RECEIVE_ERROR;
                    rx_error_status <= RECEIVE_ERROR_SYSACE_CONFIG_ADDRESS;
                    rx_ll_dst_rdy_out <= 1;
                 end
                 else begin
                    //We want to forward the configuration command to the SystemACE controller
                    ethToFifoCommand <= CONFIGFROMCF;
                    ethToFifoData <= {8'd0, rx_ll_data_in};
                    
                    //At this point, we want to issue the command to the SystemACE fifo & send the ack
                    if(tx_state == IDLE && toSysACEFifoFull == 0) begin
                       //If the transmitter isn't doing anything and the fifo has space, we can issue both directly
                       ethToFifoWrite <= 1;

                       tx_ll_sof_out <= 0;
                       tx_ll_src_rdy_out <= 0;
                       
                       //Send out 14 bytes of header and 2 bytes of payload
                       tx_state <= PROCESS_SEND_TERM_HEADER;
                       tx_header_counter <= 15;
                       tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                       tx_header_buffer_src_add <= MAC_ADDRESS;
                       tx_header_buffer_len <= 2;

                       //'c' followed by the configuration address
                       tx_packet_payload[71:64] <= 8'h63;
                       tx_packet_payload[63:56] <= rx_ll_data_in;
                       
                       rx_state <= IDLE;
                    end
                    else if(tx_state == IDLE) begin
                       //If only the transmitter isn't doing anything, send the ack then wait on the fifo
                       tx_ll_sof_out <= 0;
                       tx_ll_src_rdy_out <= 0;
                       
                       //Send out 14 bytes of header and 2 bytes of payload
                       tx_state <= PROCESS_SEND_TERM_HEADER;
                       tx_header_counter <= 15;
                       tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                       tx_header_buffer_src_add <= MAC_ADDRESS;
                       tx_header_buffer_len <= 2;

                       //'c' followed by the configuration address
                       tx_packet_payload[71:64] <= 8'h63;
                       tx_packet_payload[63:56] <= rx_ll_data_in;

                       rx_ll_dst_rdy_out <= 1;
                       rx_state <= SEND_SA_COMMAND;
                    end
                    else begin
                       //If both the transmitter is busy and the SystemACE fifo is full, wait on the transmitter
                       //  then issue the command to the fifo
                       rx_ll_dst_rdy_out <= 1;
                       rx_state <= SEND_CONFIG_CF_ACK;      
                    end
                 end
              end        
           end
           SEND_CONFIG_CF_ACK: begin
              //We are waiting for the TX to free up
              if(tx_state == IDLE && toSysACEFifoFull == 0) begin
                 //If the transmitter isn't doing anything and the fifo has space, we can issue both directly
                 ethToFifoWrite <= 1;

                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 2 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 15;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 2;

                 //'c' followed by the configuration address
                 tx_packet_payload[71:64] <= 8'h63;
                 tx_packet_payload[63:56] <= ethToFifoData[7:0];

                 //Restart the RX
                 rx_ll_dst_rdy_out <= 0;      
                 rx_state <= IDLE;
              end
              else if(tx_state == IDLE) begin
                 //If the transmitter is idle but the SystemACE fifo is full, send the ack then wait on the fifo
                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 2 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 15;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 2;

                 //'c' followed by the configuration address
                 tx_packet_payload[71:64] <= 8'h63;
                 tx_packet_payload[63:56] <= ethToFifoData[7:0];

                 rx_state <= SEND_SA_COMMAND;
              end     
           end
           SEND_SA_COMMAND: begin
              //We have already sent whatever ack, so just send the SystemACE command
              //Wait until there is space in the SystemACE fifo, then restart the RX
              if(toSysACEFifoFull == 0) begin
                 ethToFifoWrite <= 1;

                 rx_ll_dst_rdy_out <= 0;
                 rx_state <= IDLE;
              end
           end  

           RECEIVE_SA_REG_WRITE: begin
              //Pull out the 1 byte of register address and 2 bytes of data value
              //If there is valid data, grab the value
              if(rx_ll_src_rdy_in == 0) begin
                 //Decrement the command counter
                 rx_command_counter <= rx_command_counter - 1;

                 //We grab 1 byte of packet data
                 //Shift data into the address/value registers
                 //rx_SA_reg_address <= rx_SA_reg_value[15:8];     //Modified to remove warning, original saved for clarity
                 rx_SA_reg_value <= {rx_SA_reg_value[7:0], rx_ll_data_in};

                 if(rx_command_counter == 0) begin
                    //Make sure that the register address is 0-47
                    if(rx_SA_reg_value[15:8] > 8'd47) begin
                       rx_state <= RECEIVE_ERROR;
                       rx_error_status <= RECEIVE_ERROR_SA_REG_WRITE_ADDRESS;
                       rx_ll_dst_rdy_out <= 1;
                    end  
                    else begin
                       //We want to forward the register write command to the SystemACE controller
                       ethToFifoCommand <= WRITE_SA_REG;
                       ethToFifoAddress <= rx_SA_reg_value[15:8];
                       ethToFifoData <= {rx_SA_reg_value[7:0], rx_ll_data_in};
                       
                       //At this point, we want to issue the command to the SystemACE fifo & send the ack
                       if(tx_state == IDLE && toSysACEFifoFull == 0) begin
                          //If the transmitter isn't doing anything and the fifo has space, we can issue both directly
                          ethToFifoWrite <= 1;

                          tx_ll_sof_out <= 0;
                          tx_ll_src_rdy_out <= 0;
                          
                          //Send out 14 bytes of header and 4 bytes of payload
                          tx_state <= PROCESS_SEND_TERM_HEADER;
                          tx_header_counter <= 17;
                          tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                          tx_header_buffer_src_add <= MAC_ADDRESS;
                          tx_header_buffer_len <= 4;

                          //'s' followed by the register address and value
                          tx_packet_payload[71:64] <= 8'h73;
                          tx_packet_payload[63:40] <= {rx_SA_reg_value, rx_ll_data_in};
                          
                          rx_state <= IDLE;
                       end
                       else if(tx_state == IDLE) begin
                          //If only the transmitter isn't doing anything, send the ack then wait on the fifo
                          tx_ll_sof_out <= 0;
                          tx_ll_src_rdy_out <= 0;
                          
                          //Send out 14 bytes of header and 4 bytes of payload
                          tx_state <= PROCESS_SEND_TERM_HEADER;
                          tx_header_counter <= 17;
                          tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                          tx_header_buffer_src_add <= MAC_ADDRESS;
                          tx_header_buffer_len <= 4;

                          //'s' followed by the register address and value
                          tx_packet_payload[71:64] <= 8'h73;
                          tx_packet_payload[63:40] <= {rx_SA_reg_value, rx_ll_data_in};

                          rx_ll_dst_rdy_out <= 1;
                          rx_state <= SEND_SA_COMMAND;
                       end
                       else begin
                          //If both the transmitter is busy and the SystemACE fifo is full, wait on the transmitter
                          //  then issue the command to the fifo
                          rx_ll_dst_rdy_out <= 1;
                          rx_state <= SEND_SA_REG_WRITE_ACK;      
                       end
                    end
                 end        
              end
           end
           SEND_SA_REG_WRITE_ACK: begin
              //We are waiting for the TX to free up
              if(tx_state == IDLE && toSysACEFifoFull == 0) begin
                 //If the transmitter isn't doing anything and the fifo has space, we can issue both directly
                 ethToFifoWrite <= 1;

                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 4 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 17;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 4;

                 //'s' followed by the register address and value
                 tx_packet_payload[71:64] <= 8'h73;
                 tx_packet_payload[63:40] <= {rx_SA_reg_value, rx_ll_data_in};
                 
                 //Restart the RX
                 rx_ll_dst_rdy_out <= 0;      
                 rx_state <= IDLE;
              end
              else if(tx_state == IDLE) begin
                 //If the transmitter is idle but the SystemACE fifo is full, send the ack then wait on the fifo
                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 4 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 17;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 4;

                 //'s' followed by the register address and value
                 tx_packet_payload[71:64] <= 8'h73;
                 tx_packet_payload[63:40] <= {rx_SA_reg_value, rx_ll_data_in};

                 rx_state <= SEND_SA_COMMAND;
              end     
           end

           RECEIVE_SA_REG_READ: begin
              //Pull out the 1 byte of register address
              //If there is valid data, grab the address value
              if(rx_ll_src_rdy_in == 0) begin
                 //Any way that we go, we will not be accepting new RX data for a while
                 rx_ll_dst_rdy_out <= 1;
                 
                 //Make sure that the register address is between 0-47
                 if(rx_ll_data_in > 8'd47)begin
                    rx_state <= RECEIVE_ERROR;
                    rx_error_status <= RECEIVE_ERROR_SA_REG_READ_ADDRESS;
                 end
                 else begin
                    //We want to forward the configuration command to the SystemACE controller
                    ethToFifoCommand <= READ_SA_REG;
                    ethToFifoAddress <= rx_ll_data_in[6:0];
                    
                    //At this point, we want to issue the command to the SystemACE fifo, then wait for something to come back
                    if(toSysACEFifoFull == 0) begin
                       //If the fifo has space, issue the command, then wait for something to come back from the SystemACE
                       ethToFifoWrite <= 1;
                       rx_state <= SEND_SA_REG_READ_DATA;
                    end
                    else begin
                       //If the SystemACE fifo is full, wait till there is room, then wait on a response
                       rx_state <= SEND_SA_REG_READ;      
                    end
                 end
              end        
           end
           SEND_SA_REG_READ: begin
              //Wait until there is space in the SystemACE fifo, send the command, then wait for a response
              if(toSysACEFifoFull == 0) begin
                 ethToFifoWrite <= 1;
                 rx_state <= SEND_SA_REG_READ_DATA;
              end
           end
           SEND_SA_REG_READ_DATA: begin
              //We sent the command to the SystemACE fifo, now just wait for something to show up in the return fifo
              ethToFifoWrite <= 0;

              //Check to see if we have the read data sitting in the fifo and we can send it to the host
              if(tx_state == IDLE && fromSysACEFifoEmpty == 0) begin
                 fifoToEthRead <= 1;

                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 4 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 17;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 4;

                 //'a' followed by the register address and value
                 tx_packet_payload[71:64] <= 8'h61;
                 tx_packet_payload[63:40] <= {1'b0, fifoToEthAddress, fifoToEthData};
                 
                 //Restart the RX
                 rx_ll_dst_rdy_out <= 0;
                 rx_state <= IDLE;
              end
           end

           SEND_RESET_ACK: begin
              //If the TX is not doing anything, let's send the ack directly
              if(tx_state == IDLE) begin
                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 1 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 14;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 1;

                 //Send an 'm'
                 tx_packet_payload[71:64] <= 8'h6d;

                 //Start grabbing data from the input again
                 rx_ll_dst_rdy_out <= 0;
                 rx_state <= IDLE; 
              end    
           end

           RECEIVE_ERROR: begin
              //Send an error message back to the host, then empty the rest of the packet
              // onto the floor
              if(tx_state == IDLE) begin
                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;
                 
                 //Send out 14 bytes of header and 2 bytes of payload
                 tx_state <= PROCESS_SEND_TERM_HEADER;
                 tx_header_counter <= 15;
                 tx_header_buffer_dest_add <= rx_header_buffer_src_add;
                 tx_header_buffer_src_add <= MAC_ADDRESS;
                 tx_header_buffer_len <= 2;
                 //'e' followed by the error code
                 tx_packet_payload[71:64] <= 8'h65;
                 //tx_packet_payload[63:56] <= rx_error_status;
                 tx_packet_payload[63:56] <= {1'b0, rx_error_status};  //Modified to remove warning, original saved for clarity
                 
                 rx_state <= RECEIVE_EMPTY_PACKET;
                 rx_ll_dst_rdy_out <= 0;
              end
           end
           RECEIVE_EMPTY_PACKET: begin
              // Drop bytes on the floor until we reach the end of the packet
              // We don't know what the length is (the length we got from the 
              //  packet header may not really be the length if it was the type instead)
              // However, we can just wait till the end of frame signal goes high
              if(rx_ll_src_rdy_in == 0) begin
                 if(rx_ll_eof_in == 0) begin
                    rx_state <= IDLE;
                 end
              end
           end
           default: begin
              //Unknown state, so reset the receiver state
              rx_state <= IDLE;
              rx_ll_dst_rdy_out <= 0;
              rx_header_counter <= 12;
           end
         endcase
         case(tx_state)
           IDLE: begin
              //When the transmitter is idle, don't do anything
           end
           PROCESS_READ_SEND_HEADER: begin
              //Sends what is in the input header + payload buffer then goes 
              // to the reading state
              if(tx_ll_dst_rdy_in == 0) begin
                 tx_header_counter <= tx_header_counter - 1;
                 
                 //Shift out the rx header data
                 tx_header_buffer_dest_add <= {tx_header_buffer_dest_add[39:0], tx_header_buffer_src_add[47:40]};
                 tx_header_buffer_src_add <= {tx_header_buffer_src_add[39:0], tx_header_buffer_len[15:8]};
                 tx_header_buffer_len <= {tx_header_buffer_len[7:0], tx_packet_payload[71:64]};
                 tx_packet_payload[71:8] <= tx_packet_payload[63:0];
                 
                 if(tx_ll_sof_out == 0) begin
                    //We are currently sending the first byte, so raise the start of frame line for the next cycle
                    tx_ll_sof_out <= 1;
                 end     
                 
                 if(tx_header_counter == 0) begin
                    //This is the last byte of the header + payload buffer, so go to the reading
                    tx_state <= PROCESS_READ_SEND_DATA;
                    
                    //There is one cycle of delay in the memory,
                    // so update the read address now.
                    //If the dest isn't ready during the
                    // next clock cycle, that's OK, since we can
                    // repeat the old address.
                    tx_curr_mem_address <= tx_curr_mem_address + 1;
                    oldReadAddress <= tx_curr_mem_address[(OUTMEM_CONTROLLER_ADDR_WIDTH - 1):0];
                    
                    //See if we are only going to send one byte, because if so we have to raise the EOF line
                    if(tx_curr_bytes_left == 1) begin
                       tx_ll_eof_out <= 0;
                    end
                 end
              end
           end
           PROCESS_SEND_TERM_HEADER: begin
              //This sends only what is in the input header + payload buffer then goes 
              // back to being idle
              if(tx_ll_dst_rdy_in == 0) begin
                 tx_header_counter <= tx_header_counter - 1;
                 
                 //Shift out the rx header data
                 tx_header_buffer_dest_add <= {tx_header_buffer_dest_add[39:0], tx_header_buffer_src_add[47:40]};
                 tx_header_buffer_src_add <= {tx_header_buffer_src_add[39:0], tx_header_buffer_len[15:8]};
                 tx_header_buffer_len <= {tx_header_buffer_len[7:0], tx_packet_payload[71:64]};
                 tx_packet_payload[71:8] <= tx_packet_payload[63:0];
                 
                 if(tx_ll_sof_out == 0) begin
                    //We are currently sending the first byte, so raise the start of frame line for the next cycle
                    tx_ll_sof_out <= 1;
                 end     
                 
                 else if(tx_header_counter == 1) begin
                    //This is the second to last byte we are going to send,
                    // so raise the end of frame line for the next cycle 
                    tx_ll_eof_out <= 0;
                 end
                 else if(tx_header_counter == 0) begin
                    //This is the last byte we are going to send, so raise the end of frame / source ready lines
                    // for the next cycle and go back to being idle
                    tx_ll_eof_out <= 1;
                    tx_ll_src_rdy_out <= 1;
                    tx_state <= IDLE;
                 end
              end
           end
           
           PROCESS_READ_SEND_DATA: begin
              //Send bytes from the memory
              if(tx_ll_dst_rdy_in == 0) begin
                 //Update number of bytes left in this packet, in this entire read
                 // and the current read address
                 tx_read_len <= tx_read_len - 1;
                 tx_curr_bytes_left <= tx_curr_bytes_left - 1;
                 
                 if(tx_read_len != 1) begin
                    //Unless this is the last cycle, update
                    // the address
                    tx_curr_mem_address <= tx_curr_mem_address + 1;
                    oldReadAddress <= tx_curr_mem_address;
                 end
                 
                 if(tx_read_len == 2) begin
                    //This is the second to last byte we are going to send in this packet,
                    // so lower the end of frame line for the next cycle
                    tx_ll_eof_out <= 0;
                 end
                 else if(tx_read_len == 1) begin
                    //This is the last byte we are going to send, so raise the end of frame line.
                    tx_ll_eof_out <= 1;

                    //Now the question is, are we done with the entire read?
                    if(tx_curr_bytes_left == 1) begin
                       //If we are done, raise the output ready line 
                       // for the next cycle and go back to being idle       
                       tx_ll_src_rdy_out <= 1;
                       tx_state <= IDLE;
                    end
                    else begin
                       //We are not done with this read, so we have to send another packet
                       //See if we should do a regular readback or a readback after execute
                       if(tx_readback_after_execute == 0) begin
                          //This is a regular readback
                          //Send out 14 bytes of header and 5 bytes of payload intro
                          tx_state <= PROCESS_READ_SEND_HEADER;
                          tx_header_counter <= 18;
                          tx_header_buffer_dest_add <= tx_save_dest_add;
                          tx_header_buffer_src_add <= MAC_ADDRESS;
                          
                          if(tx_curr_bytes_left - 1 > (MAX_PACKET_LENGTH - 5)) begin
                             //We will need to send this as at least 2 separate packets because
                             // the payload intro plus the read data will be too long.
                             //The packet length will be the maximum allowed and
                             // but the data read length for this packet will be the max - 5 (intro).
                             tx_header_buffer_len <= MAX_PACKET_LENGTH;
                             tx_read_len <= (MAX_PACKET_LENGTH - 5);
                          end
                          else begin
                             //This will only take one packet, so just set up the output buffer and counter
                             //The entire packet will be 5 bytes longer than the actual read because
                             // of the intro
                             tx_header_buffer_len <= tx_curr_bytes_left + 4;
                             tx_read_len <= tx_curr_bytes_left - 1;
                          end
                          
                          //'r' followed by the starting address
                          tx_packet_payload[71:64] <= 8'h72;
                          tx_packet_payload[63:32] <= tx_curr_mem_address;
                          
                          tx_ll_sof_out <= 0;
                       end
                       else begin
                          //This is a readback after execute
                          //Send out 14 bytes of header and 9 bytes of payload intro
                          tx_state <= PROCESS_READ_SEND_HEADER;
                          tx_header_counter <= 22;
                          tx_header_buffer_dest_add <= tx_save_dest_add;
                          tx_header_buffer_src_add <= MAC_ADDRESS;
                          
                          if(tx_curr_bytes_left - 1 > (MAX_PACKET_LENGTH - 9)) begin
                             //We will need to send this as at least 2 separate packets because
                             // the payload intro plus the read data will be too long.
                             //The packet length will be the maximum allowed and
                             // but the data read length for this packet will be the max - 9 (intro).
                             tx_header_buffer_len <= MAX_PACKET_LENGTH;
                             tx_read_len <= (MAX_PACKET_LENGTH - 9);
                          end
                          else begin
                             //This will only take one packet, so just set up the output buffer and counter
                             //The entire packet will be 5 bytes longer than the actual read because
                             // of the intro
                             tx_header_buffer_len <= tx_curr_bytes_left + 8;
                             tx_read_len <= tx_curr_bytes_left - 1;
                          end
                          
                          //'g' followed by the starting address and the remaining bytes
                          tx_packet_payload[71:64] <= 8'h67;
                          tx_packet_payload[63:32] <= tx_curr_mem_address;
                          tx_packet_payload[31:0] <= tx_curr_bytes_left - 1;
                          
                          tx_ll_sof_out <= 0;
                       end
                    end
                 end
              end
           end
           INIT_WAIT_FOR_DONE: begin
              //The run flag should be getting set this clock cycle, so just move on to WAIT_FOR_DONE
              tx_state <= WAIT_FOR_DONE;
           end
           WAIT_FOR_DONE: begin
              //If the user's circuit is being cancelled by the user, cancel the readback
              if(softReset == 1)begin
                 tx_state <= IDLE;
              end
              //If the user's circuit is done (and wasn't cancelled by the user), start the readback
              if(userRunRegisterControllerSide == 0)begin
                 tx_state <= PROCESS_READ_SEND_HEADER;
                 tx_readback_after_execute <= 1;
                 
                 //Start the output lines
                 tx_ll_sof_out <= 0;
                 tx_ll_src_rdy_out <= 0;

                 //We only have to set 4 values here - all involving the length of the readback.
                 //All of the other values for the readback were set when we got the write & execute command.
                 
                 //Fill in tx_curr_bytes_left (maximum output address, in bytes + 1)
                 //What I really want is to fill in the lower OUTMEM_LOG_USER_BYTE_WIDTH # of bits
                 // with the byte mask ==> priority encoder.  However, the priority encoder needs to be
                 // parameterizable to work with any word width.  Thus, for the moment we will assume that
                 // if any byte in a word are touched, that all of the bytes should be sent to the host.
                 tx_curr_bytes_left <= (tx_max_output_address + 1) << OUTMEM_LOG_USER_BYTE_WIDTH;
                 
                 //Fill in the tx_read_len (number of data bytes in packet = maximum output address, in bytes + 1 or MAX_PACKET_LENGTH - 9)
                 //Fill in tx_header_buffer_len (length of payload = 9 + tx_read_len or MAX_PACKET_LENGTH)
                 //Is this going to take more than 1 packet?
                 if(((tx_max_output_address + 1) << OUTMEM_LOG_USER_BYTE_WIDTH) > (MAX_PACKET_LENGTH - 9)) begin
                    //We will need to send this as at least 2 separate packets because
                    // the payload intro plus the read data will be too long.
                    //The packet length will be the maximum allowed and
                    // but the data read length for this packet will be the max - 9 (intro).
                    tx_header_buffer_len <= MAX_PACKET_LENGTH;
                    tx_read_len <= (MAX_PACKET_LENGTH - 9);
                 end
                 else begin
                    //This will only take one packet, so just set up the output buffer and counter
                    //The entire packet will be 9 bytes longer than the actual read because
                    // of the intro
                    tx_header_buffer_len <= ((tx_max_output_address + 1) << OUTMEM_LOG_USER_BYTE_WIDTH) + 9;
                    tx_read_len <= (tx_max_output_address + 1) << OUTMEM_LOG_USER_BYTE_WIDTH;
                 end  
                 
                 //Fill in tx_packet_payload[31:0] (# of remaining read bytes = maximum output address + 1)
                 tx_packet_payload[31:0] <= (tx_max_output_address + 1) << OUTMEM_LOG_USER_BYTE_WIDTH;
              end
           end
           default: begin
              //Unknown state, so reset the transmitter state
              tx_state <= IDLE;
              tx_ll_sof_out <= 1;
              tx_ll_eof_out <= 1;
              tx_ll_src_rdy_out <= 1;
           end
         endcase
      end
   end
   

   //**********Monitor the max output address
   initial begin
      tx_max_output_address = {OUTMEM_USER_BYTE_WIDTH{1'b0}};
   end
   always @(posedge userInterfaceClock or posedge resetMaxOutputAddress)begin
      //The controller circuit can only reset or read tx_max_output_address.
      //Reading tx_max_output_address from a part of the circuit controlled by the controller clock 
      //  is OK even though this is controlled by userInterface clock.  This is because
      //  this register will not be updated after userRunRegister goes low
      //  and we will only read the register after userRunRegister goes low.
      if(resetMaxOutputAddress == 1) begin
         tx_max_output_address <= {OUTMEM_USER_BYTE_WIDTH{1'b0}};
      end
      else if(outputMemoryWriteReq == 1 && userRunRegisterUserSide == 1 && (outputMemoryWriteAdd > tx_max_output_address))begin
         tx_max_output_address <= outputMemoryWriteAdd;
      end
   end


   //**********Synchronized hard reset
   //We can do this without regard to clock domains because when the hard reset line is asserted, it is asserted for 
   // multiple clock cycles.  I wouldn't normally worry about the timing of such a slow signal, but I'm doing this
   // to eliminate any source of timing constraint problems.
   initial begin
      resetUserClockDomain = 0;
      resetControllerClockDomain = 0;
   end
   always @(posedge userInterfaceClock) begin
      if(reset) begin
         resetUserClockDomain <= 1;
      end
      else begin
         resetUserClockDomain <= 0;
      end
   end
   always @(posedge controllerSideClock) begin
      if(reset) begin
         resetControllerClockDomain <= 1;
      end
      else begin
         resetControllerClockDomain <= 0;
      end
   end

   //**********User Run Register & userLogic reset
   //We have to sync the userRunClear signal to the controller clock domain
   reg userRunClearHistory;
   reg userRunClearToggle;
   reg [1:0] userRunClearToggleControllerSide;
   initial begin
      userRunClearHistory = 0;
      userRunClearToggle = 0;
      userRunClearToggleControllerSide = 2'd0;
      userRunRegisterControllerSide = 0;
   end
   //Detect level change
   always @(posedge userInterfaceClock)begin
      userRunClearHistory <= userRunClear;
      if(userRunClear == 1 && userRunClearHistory == 0)begin
         userRunClearToggle <= ~userRunClearToggle;
      end
   end
   //Sync to controller domain
   always @(posedge controllerSideClock) begin
      //This technique will work as long as userRunClear isn't pulsed twice or more times faster than
      // the controller side clock is running.  This won't happen unless the
      // user pulses userRunClear even though the user-side userRunRegister is not asserted.
      userRunClearToggleControllerSide <= {userRunClearToggleControllerSide[0], userRunClearToggle};
   end
   //Now build the controller side register that will react to
   // the controller-side signals userRunRegisterSet, softReset and
   // synced userRunClear signal
   always @(posedge controllerSideClock) begin
      //Soft or hard reset
      if(softReset == 1 || resetControllerClockDomain == 1) begin
         userRunRegisterControllerSide <= 0;
      end
      //User side run reset
      else if(userRunClearToggleControllerSide[1] ^ userRunClearToggleControllerSide[0]) begin
         userRunRegisterControllerSide <= 0;
      end
      //Internal run set
      else if(userRunRegisterSet == 1) begin
         userRunRegisterControllerSide <= 1;
      end
   end
   assign userRunRegisterSet = (register32InternalWriteEnable == 1 && rx_reg_address == 8'hFF) ? rx_reg_value[0] : 0;
   
   
   //We have to sync the userRunRegisterSet and softReset signal to the user clock domain
   reg userRunRegisterSetHistory;
   reg userRunRegisterSetToggle;
   reg [1:0] userRunRegisterSetToggleUserSide;
   reg       softResetHistory;
   reg       softResetToggle;
   reg [1:0] softResetToggleUserSide;
   initial begin
      userRunRegisterSetHistory = 0;
      userRunRegisterSetToggle = 0;
      userRunRegisterSetToggleUserSide = 2'd0;
      softResetHistory = 0;
      softResetToggle = 0;
      softResetToggleUserSide = 2'd0;
      userLogicReset = 0;
   end
   //Detect level change
   always @(posedge controllerSideClock)begin
      userRunRegisterSetHistory <= userRunRegisterSet;
      if(userRunRegisterSet == 1 && userRunRegisterSetHistory == 0)begin
         userRunRegisterSetToggle <= ~userRunRegisterSetToggle;
      end
      softResetHistory <= softReset;
      if(softReset == 1 && softResetHistory == 0)begin
         softResetToggle <= ~softResetToggle;
      end
   end
   //Sync to user domain
   always @(posedge userInterfaceClock) begin
      //This technique will work as long as userRunRegisterSet isn't pulsed twice or more times faster than
      // the user side clock is running.  This won't happen unless the
      // controller pulses userRunRegisterSet even though the controller side userRunRegister is already asserted.
      userRunRegisterSetToggleUserSide <= {userRunRegisterSetToggleUserSide[0], userRunRegisterSetToggle};
      //This technique will work as long as softReset isn't pulsed twice or more times faster than
      // the user side clock is running.  This won't happen unless the
      // controller pulses softReset even though the controller side userRunRegister is already false.
      softResetToggleUserSide <= {softResetToggleUserSide[0], softResetToggle};
   end
   
   //Now build the user side register that will react to the user-side signal userRunClear 
   // and the synced userRunRegisterSet and softReset signals
   always @(posedge userInterfaceClock) begin
      //All signals synchronous to controller clock
      //Hard or soft reset
      if(resetUserClockDomain == 1 || (softResetToggleUserSide[1] ^ softResetToggleUserSide[0])) begin
         
         // (Louis Woods) Workaround: On reset, I set userRunRegisterUserSide to 1 because I immediatly need to write
         //                           the device signature to the ouput memory. After the signature has been written 
         //                           I set this back to 0 using userRunClear
         
         //userRunRegisterUserSide <= 0;
         userRunRegisterUserSide <= 1;
         userLogicReset          <= 1;
      end
      //User side run reset
      else if(userRunClear) begin
         userRunRegisterUserSide <= 0;
      end
      //Internal run set
      else if(userRunRegisterSetToggleUserSide[1] ^ userRunRegisterSetToggleUserSide[0]) begin
         userRunRegisterUserSide <= 1;
      end
      else begin
         userLogicReset <= 0;
      end
   end 

   //**********Input and Output Memories
   //For the input data, buffer a message up to 256KB in size (default)
   //The ethernet reciever (port A) should only write values when
   // we actually want to do a input memory write, have valid values to write, and 
   // (double check) that the run register is low.
   //I put in a check here, but the write should never start if the run register is high
   //Once I'm sure that this module is working, I can take this check out since it is
   // internal to the system
   //The user application (port B) should only read values when the
   // run register is high, otherwise it will only get zeros
   //Do not remove this check since it is connected to external signals
   blk_mem_gen_inputMem memInputData
     (
      .clka(controllerSideClock),
      .dina(rx_ll_data_in),
      .addra(rx_mem_address[(INMEM_CONTROLLER_ADDR_WIDTH - 1):0]),
      .wea((rx_state == PROCESS_INPUT_MEM_WRITE && rx_ll_src_rdy_in == 0 && userRunRegisterControllerSide == 0) ? 1'b1 : 1'b0),
      .clkb(userInterfaceClock),
      .addrb(inputMemoryReadAdd),
      .doutb(inputMemoryExternalReadData)
      );
   
   assign inputMemoryReadData = (userRunRegisterUserSide == 1 && inputMemoryReadDataValid == 1) ? 
                                inputMemoryExternalReadData : {(INMEM_USER_BYTE_WIDTH * 8){1'b0}};

   //Handle the handshaking protocol
   //Since we are only using block memory, we will always accept read requests on the same cycle
   // they are sent
   assign inputMemoryReadAck = userRunRegisterUserSide;
   //The block memory cannot respond faster than the next clock cycle (no pipelining registers), with increasing
   // latency from there.  Thus, we should have a minimum of 1 delay on the data valid signal.
   reg [INMEM_USER_REGISTER:0] inputMemoryReadDataValidPipeline;
   initial begin
      inputMemoryReadDataValidPipeline = {(INMEM_USER_REGISTER + 1){1'b0}};
   end
   always @(posedge userInterfaceClock) begin
      //I don't like mixing blocking assignments, but this is the only way I could figure out
      // to make this parameterizable.  Should be simple enough that XST will synthesize correctly.
      inputMemoryReadDataValidPipeline = inputMemoryReadDataValidPipeline << 1;
      inputMemoryReadDataValidPipeline[0] = (inputMemoryReadReq == 1) && (userRunRegisterUserSide == 1);
   end
   assign inputMemoryReadDataValid = inputMemoryReadDataValidPipeline[INMEM_USER_REGISTER];
   
   //For the output data, buffer up to 8KB (default)
   //The user application (port A) can only
   // write data to the output memory, and only when the run register is high
   //Do not remove this check since it is connected to external signals
   //The ethernet transmitter (port B) should only start reading values out when
   // the run register is low.
   //I have put in a check here but the read should never start if the run register is high
   //Once I'm sure that this module is working, I can take this check out since it is
   // internal to the system
   blk_mem_gen_outputMem memOutputData
     (
      .clka(userInterfaceClock),
      .dina(outputMemoryWriteData),
      .addra(outputMemoryWriteAdd),
      .wea((userRunRegisterUserSide == 1 && outputMemoryWriteReq == 1) ? outputMemoryWriteByteMask : {OUTMEM_USER_BYTE_WIDTH{1'b0}}),
      .clkb(controllerSideClock),
      .addrb(outputMemReadAddressIn),
      .doutb(outputMemoryInternalReadData)
      );
   
   assign outputMemReadDataOut = (userRunRegisterControllerSide == 0) ? outputMemoryInternalReadData : 8'd0;
   //This selects if the memory will be reading a new location, or because the dest
   // isn't ready, it's a re-read.
   assign outputMemReadAddressIn = (tx_ll_dst_rdy_in == 0) ? tx_curr_mem_address[(OUTMEM_CONTROLLER_ADDR_WIDTH - 1):0] : oldReadAddress;

   //Handle the handshaking protocol
   //Since we are only using block memory, we will always accept write requests on the same cycle
   // they are sent
   assign outputMemoryWriteAck = userRunRegisterUserSide;
   
   //This decides if we are shifting out header/intro information or memory data
   assign tx_ll_data_out = (tx_state == PROCESS_READ_SEND_DATA)? outputMemReadDataOut: tx_header_buffer_dest_add[47:40];

   //**********Parameter 32 Registers
   //The ethernet receiver (port A) should only read or write values when
   // we have valid values to write and when the run register is low.
   //I put in a write check here, but the write should never start if the run register is high
   //Once I'm sure that this module is working, I can take this check out since it is
   // internal to the system.  There is no separate read check.
   //The user application (port B) should only read or write values when the
   // run register is high
   //Do not remove these checks since these ports are connected to external signals
   //Notice that this is a 255 location register file.  Location 256 is the run register.
   blk_mem_gen_paramReg register32File
     (
      .clka(controllerSideClock),
      .dina(rx_reg_value),
      .addra(rx_reg_address),
      .wea((userRunRegisterControllerSide == 0) ? register32InternalWriteEnable : 1'b0),
      .douta(register32InternalReadData),
      .clkb(userInterfaceClock),
      .dinb(register32WriteData),
      .addrb(register32Address),
      .web((userRunRegisterUserSide == 1 && register32CmdReq == 1) ? register32WriteEn : 1'b0),
      .doutb(register32ExternalReadData)
      );
   
   assign register32ReadData = (userRunRegisterUserSide == 1 && register32ReadDataValid ==1) ? register32ExternalReadData : 32'd0;

   //Handle the handshaking protocol
   //Since we are only using block memory, we will always accept read requests on the same cycle
   // they are sent
   assign register32CmdAck = userRunRegisterUserSide;

   //The block memory will respond on next clock cycle if there was a valid read request issued
   initial begin
      register32ReadDataValid = 0;
   end
   always @(posedge userInterfaceClock) begin
      register32ReadDataValid <= (userRunRegisterUserSide == 1) && (register32CmdReq == 1) && (register32WriteEn == 0);
   end

   //**********SystemACE controller
   // Take care of the inout port
   reg [15:0] sysACE_MPDATA_In;
   wire [15:0] sysACE_MPDATA_Out;
   iobuf16 sysACEIO(
                    .IO(sysACE_MPDATA), 
                    .I(sysACE_MPDATA_In), 
                    .O(sysACE_MPDATA_Out),
                    .T(~sysACE_MPOE && ~sysACE_MPCE) //Output is active only when the chip is enabled and chip output is enabled
                    );
   
   // Shift the systemACE clock
   wire        sysACE_clk_o;
   wire        sysACE_delay_clk;
   wire        sysACEPllFB;
   wire        sysACEPllLock;
   wire        sysACEreset;
   PLL_BASE 
     #(
       .COMPENSATION("SYSTEM_SYNCHRONOUS"),  // "SYSTEM_SYNCHRONOUS",
       .BANDWIDTH("OPTIMIZED"),      // "HIGH", "LOW" or "OPTIMIZED"

       .CLKFBOUT_MULT(14),        // Multiplication factor for all output clocks
       .DIVCLK_DIVIDE(1),        // Division factor for all clocks (1 to 52)
       .CLKFBOUT_PHASE(0),        // Phase shift (degrees) of all output clocks
       .REF_JITTER(0.100),        // Input reference jitter (0.000 to 0.999 UI%)
       .CLKIN_PERIOD(30.303),       // Clock period (ns) of input clock on CLKIN

       .CLKOUT0_DIVIDE(14),       // Division factor (1 to 128)
       .CLKOUT0_PHASE(118.929),      // Phase shift (degrees) (0.0 to 360.0)
       .CLKOUT0_DUTY_CYCLE(0.5)      // Duty cycle (0.01 to 0.99)
       ) 
   clkBPLL 
     (
      .CLKOUT0(sysACE_delay_clk),    // 33 MHz phase shifted by 9 ns
      .CLKFBOUT(sysACEPllFB),      // General output feedback signal
      .CLKIN(sysACE_CLK),       // Clock input
      .CLKFBIN(sysACEPllFB),       // Clock feedback input
      .LOCKED(sysACEPllLock),      // Active high PLL lock signal
      .RST(1'b0)
      );
   
   assign sysACEreset = reset | ~sysACEPllLock;
   BUFG bufSysACEClk (.O(sysACE_clk_o), .I(sysACE_delay_clk));

   //Instantiate FIFOs between the ethernet controller and the SystemACE
   //Wires to and from fifos
   wire        toSysACEFifoEmpty;
   wire [1:0]  fifoToSysACECommand;
   wire [6:0]  fifoToSysACEAddress;
   wire [15:0] fifoToSysACEData;
   reg         fifoToSysACERead;
   wire        fromSysACEFifoFull;
   reg         sysACEToFifoWrite;

   fifo36Wrapper EthToSysACEFifo
     (
      .writeClk(controllerSideClock),
      .writeData({ethToFifoCommand, ethToFifoAddress, ethToFifoData}),
      .writeEnable(ethToFifoWrite),
      .full(toSysACEFifoFull),
      .readClk(sysACE_clk_o),
      .readData({fifoToSysACECommand, fifoToSysACEAddress, fifoToSysACEData}),
      .readEnable(fifoToSysACERead),
      .empty(toSysACEFifoEmpty),
      .reset(sysACEreset)
      );
   
   fifo36Wrapper SysACEToEthFifo
     (
      .writeClk(sysACE_clk_o),
      .writeData({sysACE_MPADD ,sysACE_MPDATA_Out}),
      .writeEnable(sysACEToFifoWrite),
      .full(fromSysACEFifoFull),
      .readClk(controllerSideClock),
      .readData({fifoToEthAddress, fifoToEthData}),
      .readEnable(fifoToEthRead),
      .empty(fromSysACEFifoEmpty),
      .reset(sysACEreset)
      );
   
   // SystemACE controller state machine
   localparam PROCESS_CONFIGFROMCF = 1;  // Writing the values to reboot the system from a specific configuration on the CF
   localparam PROCESS_SA_WRITE = 2;   // Writing one value out to the SystemACE registers
   localparam PROCESS_SA_READ = 3;    // Read one value from the SystemACE registers

   //For the ML50X board, the SystemACE seems to come up in 16-bit mode automatically
   //Values used for the control register
   //0) Force MPU lock request - 1 => 0
   //1) Make lock request - 1 => 0
   //2) Override the config address - 1
   //3) Override the config mode pin - 1
   //4) Start the configuration process after reset - 1
   //5) Start the configuration process - 1
   //6) Configure from CF - 0
   //7) Reset the controllers - 1 => 0
   //8) Disable data buffer ready interrupts - 0
   //9) Disable error interrupts - 0
   //10) Disable configuration done interrupts - 0
   //11) Reset the interrupt request line - 0
   //12) not used
   //13-15) configuration address
   localparam FORCECFRESET = 13'b0000010111111;
   localparam FORCECFUNRESET = 13'b0000000111100;
   
   reg [2:0]   sysACE_state;
   reg [2:0]   sysACECounter;
   
   assign sysACE_MPCE = 0;  //Chip is always enabled
   
   initial begin
      sysACE_MPADD = 0;
      sysACE_MPWE = 0;  //Come up writing a 1 to register 0 of the SystemACE
      sysACE_MPDATA_In = 16'd1;
      sysACE_MPOE = 1;
      sysACE_state = IDLE;
      
      fifoToSysACERead = 0;
      sysACEToFifoWrite = 0;
   end
   
   always @(posedge sysACE_clk_o) begin
      if(sysACEreset == 1) begin
         sysACE_MPADD <= 0;
         sysACE_MPWE <= 0;  //Come up writing a 1 to register 0 of the SystemACE to put it into 16-bit mode
         sysACE_MPDATA_In <= 16'd1;
         sysACE_MPOE <= 1;
         sysACE_state <= IDLE;
         
         fifoToSysACERead <= 0;
         sysACEToFifoWrite <= 0;
      end
      else begin
         case(sysACE_state)
           IDLE: begin
              //We might have come out of reset, in which case we just wrote to register 0
              sysACE_MPWE <= 1;
              //We might have just done a last register read, in which case we have to stop the output
              // and stop writing to the SystemACE to eth fifo.
              sysACE_MPOE <= 1;
              sysACEToFifoWrite <= 0;
              
              if(toSysACEFifoEmpty == 0) begin
                 //Don't do anything until something shows up in the fifo, then take 1 item out
                 fifoToSysACERead <= 1;
                 
                 if(fifoToSysACECommand == CONFIGFROMCF) begin
                    //Let's start writing the start reconfiguring value to register 0x18
                    sysACE_MPADD <= 6'h18;
                    sysACE_MPDATA_In <= {fifoToSysACEData[2:0], 13'h00BF};
                    sysACE_MPWE <= 0;
                    sysACECounter <= 2;
                    sysACE_state <= PROCESS_CONFIGFROMCF;
                 end
                 else if(fifoToSysACECommand == WRITE_SA_REG) begin
                    //Let's start writing to the appropriate register
                    sysACE_MPADD <= fifoToSysACEAddress;
                    sysACE_MPDATA_In <= fifoToSysACEData;
                    sysACE_MPWE <= 0;
                    sysACE_state <= PROCESS_SA_WRITE;
                 end
                 else if(fifoToSysACECommand == READ_SA_REG) begin
                    //Let's start reading from the appropriate register
                    sysACE_MPADD <= fifoToSysACEAddress;
                    sysACE_MPOE <= 0;
                    sysACE_state <= PROCESS_SA_READ;
                 end
              end
           end
           PROCESS_CONFIGFROMCF: begin
              //Stop reading from the fifo
              fifoToSysACERead <= 0;
              sysACECounter <= sysACECounter - 1;
              sysACE_MPWE <= ~sysACE_MPWE;

              if(sysACECounter == 2) begin
                 //Write the stop resetting value to register 0x18 during the next cycle
                 sysACE_MPDATA_In <= {fifoToSysACEData[2:0], 13'h003C};
              end

              if(sysACECounter == 0) begin
                 sysACE_state <= IDLE;
              end
           end
           PROCESS_SA_WRITE: begin
              //Stop reading from the fifo
              fifoToSysACERead <= 0;

              //Stop writing to the register
              sysACE_state <= IDLE;
              sysACE_MPWE <= 1;
           end
           PROCESS_SA_READ: begin
              //Stop reading from the fifo
              fifoToSysACERead <= 0;
              
              //If there is space in the outgoing fifo, put the value read from the SystemACE in
              if(fromSysACEFifoFull == 0) begin
                 //Write the value we get back from the SystemACE into the fifo in the next cycle
                 sysACEToFifoWrite <= 1;
                 sysACE_state <= IDLE;
              end
           end
         endcase
      end
   end
endmodule