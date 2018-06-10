//Microsoft Research License Agreement
//Non-Commercial Use Only
// SATA core
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
 * Author        : Louis Woods <louis.woods@inf.ethz.ch>
 * Module        : TestSATA
 * Created       : May 18 2011
 * Last Update   : November 20 2013
 * ---------------------------------------------------------------------------
 * Description   : Module for benchmarking the SATA core using Ken Eguro's SIRC.
 *                 -> http://research.microsoft.com/apps/pubs/default.aspx?id=121293
 *                 CMD_IDENTIFY_DEVICE           (0)  -> identify device command returns 512 bytes
 *                 CMD_READ_DMA_EXTENDED         (1), -> read single LBA
 *                 CMD_WRITE_DMA_EXTENDED        (2), -> write single LBA
 *                 CMD_FIRST_PARTY_DMA_READ_NCQ  (3), -> read single LBA with NCQ command
 *                 CMD_FIRST_PARTY_DMA_WRITE_NCQ (4), -> write single LBA with NCQ command
 *                 CMD_BENCHMARK_READ_DMA        (6), -> read a set of LBAs
 *                 CMD_BENCHMARK_WRITE_DMA       (7), -> write a set of LBAs
 *                 CMD_BENCHMARK_READ_NCQ        (8), -> read a set of LBAs with NCQ
 *                 CMD_BENCHMARK_WRITE_NCQ       (9); -> write a set of LBAs with NCQ         
 * ---------------------------------------------------------------------------
 * Changelog     : Added reg_cmd_done
 *                 Because we increased the receive buffer it is actually 
 *                 possible that a SATA command completes while we are
 *                 waiting in state READ_HOLD (which tests the hold
 *                 logic of Groundhog). Therefore we need to remember that
 *                 the command completed while we were deliberately not reading
 *                 out the receive buffer for n cycles.
 * ------------------------------------------------------------------------- */

`timescale 1ns / 1ps
`default_nettype none

  module TestSATA 
    #(
      //************ Input and output block memory parameters
      //The user's circuit communicates with the input and output memories as N-byte chunks
      //This should be some power of 2 >= 1.
      parameter INMEM_BYTE_WIDTH = 1,
      parameter OUTMEM_BYTE_WIDTH = 1,
    
      //How many N-byte words does the user's circuit use?
      parameter INMEM_ADDRESS_WIDTH = 17,
      parameter OUTMEM_ADDRESS_WIDTH = 13
      )
   (
    input                                     clk,
    input                                     reset,
    
    // A user application can only check the status of the run register and reset it to zero
    
    input                                     userRunValue, // Read run register value
    output reg                                userRunClear, // Reset run register
   
    //Parameter register file connections
    output reg                                register32CmdReq, // Parameter register handshaking request signal - assert to perform read or write
    input                                     register32CmdAck, // Parameter register handshaking acknowledgment signal - when the req and ack ar both true fore 1 clock cycle, the request has been accepted
    output reg [31:0]                         register32WriteData, // Parameter register write data
    output reg [7:0]                          register32Address, // Parameter register address
    output reg                                register32WriteEn, // When we put in a request command, are we doing a read or write?
    input                                     register32ReadDataValid, // After a read request is accepted, this line indicates that the read has returned and that the data is ready
    input [31:0]                              register32ReadData, // Parameter register read data

    //Input memory connections
    output reg                                inputMemoryReadReq, // Input memory handshaking request signal - assert to begin a read request
    input                                     inputMemoryReadAck, // Input memory handshaking acknowledgement signal - when the req and ack are both true for 1 clock cycle, the request has been accepted
    output reg [(INMEM_ADDRESS_WIDTH - 1):0]  inputMemoryReadAdd, // Input memory read address - can be set the same cycle that the req line is asserted
    input                                     inputMemoryReadDataValid, // After a read request is accepted, this line indicates that the read has returned and that the data is ready
    input [((INMEM_BYTE_WIDTH * 8) - 1):0]    inputMemoryReadData, // Input memory read data
   
    //Output memory connections
    output                                    outputMemoryWriteReq, // Output memory handshaking request signal - assert to begin a write request
    input                                     outputMemoryWriteAck, // Output memory handshaking acknowledgement signal - when the req and ack are both true for 1 clock cycle, the request has been accepted
    output reg [(OUTMEM_ADDRESS_WIDTH - 1):0] outputMemoryWriteAdd, // Output memory write address - can be set the same cycle that the req line is asserted
    output [((OUTMEM_BYTE_WIDTH * 8) - 1):0]  outputMemoryWriteData, // Output memory write data
    output [(OUTMEM_BYTE_WIDTH - 1):0]        outputMemoryWriteByteMask, // Allows byte-wise writes when multibyte words are used - each of the OUTMEM_USER_BYTE_WIDTH line can be 0 (do not write byte) or 1 (write byte)

    //8 optional LEDs for visual feedback & debugging
    output reg [7:0]                          LED,
    output [1:0]                              ERROR_LED,

    // HBA main interface: input ports
    output reg [2:0]                          cmd,
    output reg                                cmd_en,
    output reg [47:0]                         lba,
    output reg [15:0]                         sectorcnt,
    output [15:0]                             wdata,
    output                                    wdata_en,
    output reg                                rdata_next,

    // HBA main interface: output ports
    input                                     wdata_full,
    input [15:0]                              rdata,
    input                                     rdata_empty,
    input                                     cmd_failed,
    input                                     cmd_success,

    // HBA additional reporting signals
    input                                     link_initialized,
    input [1:0]                               link_gen,
    
    // HBA NCQ extension
    output reg [4:0]                          ncq_wtag,
    input [4:0]                               ncq_rtag,
    input                                     ncq_idle,
    input                                     ncq_relinquish,
    input                                     ncq_ready_for_wdata,
    input [31:0]                              ncq_SActive,
    input                                     ncq_SActive_valid
    );

   // Commands implemented in the transport module
   localparam
     CMD_IDENTIFY_DEVICE           = 0,
     CMD_READ_DMA_EXTENDED         = 1,
     CMD_WRITE_DMA_EXTENDED        = 2,
     CMD_FIRST_PARTY_DMA_READ_NCQ  = 3,
     CMD_FIRST_PARTY_DMA_WRITE_NCQ = 4,
     CMD_RESET                     = 5,
     CMD_BENCHMARK_READ_DMA        = 6,
     CMD_BENCHMARK_WRITE_DMA       = 7,
     CMD_BENCHMARK_READ_NCQ        = 8,
     CMD_BENCHMARK_WRITE_NCQ       = 9;
   
   // FSM states
   localparam 
     WAIT_LINKUP              = 0,
     
     READ_DEVICE_SIGNATURE_0  = 1,
     READ_DEVICE_SIGNATURE_1  = 2,
     
     WRITE_REGISTERS_0        = 3,
     WRITE_REGISTERS_1        = 4,
     WRITE_REGISTERS_2        = 5,
     WRITE_REGISTERS_3        = 6,
     WRITE_REGISTERS_4        = 7,
     WRITE_REGISTERS_5        = 8,
     WRITE_REGISTERS_6        = 9,
     WRITE_REGISTERS_7        = 10,
     
     IDLE                     = 11,
     
     READ_REGISTERS           = 12,
     EXECUTE_CMD              = 13,
     
     IDENTIFY_0               = 14,
     IDENTIFY_1               = 15,
     IDENTIFY_2               = 16,
     
     READ_0                   = 17,
     READ_1                   = 18,
     READ_2                   = 19,
     READ_HOLD                = 20,
     
     WRITE_0                  = 21,
     WRITE_1                  = 22,
     WRITE_2                  = 23,
     WRITE_3                  = 24,
     WRITE_HOLD               = 25,

     READ_NCQ_0               = 26,
     READ_NCQ_1               = 27,
     READ_NCQ_2               = 28,
     READ_NCQ_3               = 29,
     
     WRITE_NCQ_0              = 30,
     WRITE_NCQ_1              = 31,
     WRITE_NCQ_2              = 32,
     WRITE_NCQ_3              = 33,

     BENCHMARK_READ_DMA_0     = 34,
     BENCHMARK_READ_DMA_1     = 35,
     BENCHMARK_READ_DMA_2     = 36,
     BENCHMARK_READ_DMA_3     = 37,

     BENCHMARK_WRITE_DMA_0    = 38,
     BENCHMARK_WRITE_DMA_1    = 39,
     BENCHMARK_WRITE_DMA_2    = 40,
     BENCHMARK_WRITE_DMA_3    = 41,
     BENCHMARK_WRITE_DMA_4    = 42,

     BENCHMARK_READ_NCQ_0     = 43,
     BENCHMARK_READ_NCQ_1     = 44,
     BENCHMARK_READ_NCQ_2     = 45,
     BENCHMARK_READ_NCQ_3     = 46,
     BENCHMARK_READ_NCQ_4     = 47,
     BENCHMARK_READ_NCQ_5     = 48,
     BENCHMARK_READ_NCQ_6     = 49,
     BENCHMARK_READ_NCQ_7     = 50,
     BENCHMARK_READ_NCQ_8     = 51,

     BENCHMARK_WRITE_NCQ_0    = 52,
     BENCHMARK_WRITE_NCQ_1    = 53,
     BENCHMARK_WRITE_NCQ_2    = 54,
     BENCHMARK_WRITE_NCQ_3    = 55,
     BENCHMARK_WRITE_NCQ_4    = 56,
     BENCHMARK_WRITE_NCQ_5    = 57,
     BENCHMARK_WRITE_NCQ_6    = 58,
     BENCHMARK_WRITE_NCQ_7    = 59,
     BENCHMARK_WRITE_NCQ_8    = 60;
   
   // State registers
   reg [5:0]                                  currState;
   reg [31:0]                                 clock_count;
   
   // Parameters from user (registers 0 to 9)
   reg [31:0]                                    CMD;
   reg [31:0]                                    LBA_L;
   reg [31:0]                                    LBA_U;
   reg [31:0]                                    SECTORCNT;
   reg [31:0]                                    NUMWORDS;
   
   // Parameters to user (registers 10 to 19)
   localparam 
     REG_NO_BUFFERCNT  = 10,
     REG_NO_LINKUP     = 11,
     REG_NO_CMD_FAILED = 12,
     REG_NO_LINKGEN    = 13,
     REG_CLKTICKCNT_L  = 14,
     REG_CLKTICKCNT_U  = 15,
     REG_SATA_ERRORS   = 16,
     REG_DATA_ERRORS   = 17;

   // FIFO for data from input buffer
   wire                                          input_BRAM_empty;
   wire                                          input_BRAM_full;

   // Counting words and sectors
   // -> avoid inserting too much into FIFO
   reg                                           word_count_reset;
   reg [7:0]                                     word_count;
   reg                                           input_data_processed;
   reg [15:0]                                    sector_count;
   reg                                           sector_count_reset;

   reg [31:0]                                    reg_buffercnt;
   reg [31:0]                                    reg_cmd_failed;
   reg                                           reg_cmd_done;

   reg                                           inputMemReq;
   reg                                           inputMemValid;
   reg [31:0]                                    regSATAErrorCount;
   reg [31:0]                                    regDataErrorCount;

   reg [63:0]                                    clktickcnt;
   reg                                           clktickcnt_en;
   reg                                           clktickcnt_clear;
                                           
   reg                                           benchmark;
   reg                                           benchmark_ncq;
   reg                                           benchmark_write_en;  

   reg                                           rng_reset;
   wire                                          rng_en;
   wire [15:0]                                   rng_data;
   reg                                           rng_latency;
   reg [15:0]                                    rng_rdata_r;
   reg                                           rng_setseed;
   wire [15:0]                                   rng_seed;
   
   wire                                          data_error;
   reg                                           data_error_reg;
   reg                                           data_error_reset;

   reg [31:0]                                    dataFIS_end;
   integer                                       i;

   // NCQ related bookkeeping
   
   localparam NCQ_QUEUE_LOG_SIZE = 5;
   localparam NCQ_QUEUE_SIZE     = 2**NCQ_QUEUE_LOG_SIZE;
   localparam NCQ_QUEUE_FULL     = NCQ_QUEUE_SIZE-1;
   
   reg [NCQ_QUEUE_SIZE:0]                        ncq_queue;
   reg [4:0]                                     ncq_next_tag;
   wire                                          ncq_next_tag_valid;
   wire                                          ncq_is_full;
   reg                                           ncq_lba_loaded;

   // BRAM to store LBA associated with command
   reg                                           BRAMen;
   reg  [3:0]                                    BRAMwe;
   wire [4:0]                                    BRAMAddr;
   wire [31:0]                                   BRAMDataOut;
   
   assign outputMemoryWriteByteMask = {OUTMEM_BYTE_WIDTH{1'b1}};
   
   assign ERROR_LED[0] = ~link_initialized;
   assign ERROR_LED[1] = 0;

   assign outputMemoryWriteReq  = rdata_next && (!rdata_empty);
   assign outputMemoryWriteData = rdata;

   assign wdata_en   = (!wdata_full) && (!input_BRAM_empty);
   assign rng_en     = benchmark_write_en || (rdata_next && rng_latency);
   assign data_error = rng_en && (rng_data != rng_rdata_r);

   assign rng_seed = benchmark_ncq ? (BRAMDataOut[31:16] ^ BRAMDataOut[15:0]) : (LBA_L[31:16] ^ LBA_L[15:0]);
   
   initial begin
      currState = WAIT_LINKUP;
      
      // user parameters
      CMD       = 0;
      LBA_L     = 0;
      LBA_U     = 0;
      SECTORCNT = 0;
      NUMWORDS  = 0;
      
      userRunClear = 0;
      
      // set linkup register to 0
      register32Address   = REG_NO_LINKUP;
      register32CmdReq    = 1;
      register32WriteData = 0;
      register32WriteEn   = 1;
      
      inputMemoryReadReq = 0;
      inputMemoryReadAdd = 0;
      
      outputMemoryWriteAdd = 0;

      inputMemReq   = 0;
      inputMemValid = 0;
      
      reg_buffercnt  = 0;
      reg_cmd_failed = 0;
      reg_cmd_done   = 0;

      // HBA signals
      cmd        = 0;
      cmd_en     = 0;
      lba        = 0;
      sectorcnt  = 0;
      rdata_next = 0;
      
      clktickcnt_en    = 0;
      clktickcnt_clear = 1;

      benchmark          = 0;
      benchmark_ncq      = 0;
      benchmark_write_en = 0; 

      rng_reset   = 1;
      rng_setseed = 0;

      ncq_queue      = 0;
      ncq_lba_loaded = 0;

      BRAMen = 0;
      BRAMwe = 4'b0000;
      
   end

   always @(posedge clk) begin
      LED = 8'b00000000;
      
      if(reset) begin
         currState <= WAIT_LINKUP;
         
         // user parameters
         CMD       <= 0;
         LBA_L     <= 0;
         LBA_U     <= 0;
         SECTORCNT <= 0;
         NUMWORDS  <= 0;
         
         userRunClear <= 0;
         
         // set linkup register to 0
         register32Address   <= REG_NO_LINKUP;
         register32CmdReq    <= 1;
         register32WriteData <= 0;
         register32WriteEn   <= 1;
         
         inputMemoryReadReq <= 0;
         inputMemoryReadAdd <= 0;
         
         outputMemoryWriteAdd <= 0;

         inputMemReq   <= 0;
         inputMemValid <= 0;
         
         reg_buffercnt  <= 0;
         reg_cmd_failed <= 0;
         reg_cmd_done   <= 0;

         // HBA signals
         cmd        <= 0;
         cmd_en     <= 0;
         lba        <= 0;
         sectorcnt  <= 0;
         rdata_next <= 0;
         
         clktickcnt_en    <= 0;
         clktickcnt_clear <= 1;

         benchmark          <= 0;
         benchmark_ncq      <= 0;
         benchmark_write_en <= 0; 

         rng_reset   <= 1;
         rng_setseed <= 0;

         // reset queue to all positions free
         ncq_queue      <= 0;
         ncq_lba_loaded <= 0;

         BRAMen <= 0;
         BRAMwe <= 4'b0000;
      end
      else begin

         BRAMen <= 0;
         BRAMwe <= 4'b0000;
                 
         if(outputMemoryWriteReq) begin
            reg_buffercnt        <= reg_buffercnt + 1;
            outputMemoryWriteAdd <= outputMemoryWriteAdd + 1;
         end
         
         case(currState)

           /* ------------------------------------------------------------ */
           /* Reset                                                        */
           /* ------------------------------------------------------------ */
           
           WAIT_LINKUP: begin
              if(register32CmdAck == 1 && register32CmdReq == 1) begin
                 register32CmdReq  <= 0;
                 register32WriteEn <= 0;
              end 
              if(link_initialized) begin
                 // set linkup register to 1
                 register32Address   <= REG_NO_LINKUP;
                 register32CmdReq    <= 1;
                 register32WriteData <= 1;
                 register32WriteEn   <= 1; 
                 currState           <= READ_DEVICE_SIGNATURE_0;
              end
           end

           READ_DEVICE_SIGNATURE_0: begin
              if(register32CmdAck == 1 && register32CmdReq == 1) begin
                 register32CmdReq  <= 0;
                 register32WriteEn <= 0;
              end
              if(!rdata_empty) begin
                 rdata_next <= 1;
                 if(rdata_next) begin
                    currState <= READ_DEVICE_SIGNATURE_1;
                 end
              end
              else begin
                 rdata_next <= 0;
              end
           end

           READ_DEVICE_SIGNATURE_1: begin
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
                 currState  <= WRITE_REGISTERS_0;
              end
           end
           
           WRITE_REGISTERS_0: begin
              register32CmdReq    <= 1;
              register32WriteEn   <= 1;
              register32Address   <= REG_NO_BUFFERCNT;
              register32WriteData <= reg_buffercnt;
              currState           <= WRITE_REGISTERS_1;
           end

           WRITE_REGISTERS_1: begin
              register32Address   <= REG_NO_CMD_FAILED;
              register32WriteData <= reg_cmd_failed;
              currState           <= WRITE_REGISTERS_2;
           end

           WRITE_REGISTERS_2: begin
              register32Address   <= REG_NO_LINKGEN;
              register32WriteData <= link_gen;
              currState           <= WRITE_REGISTERS_3;
           end

           WRITE_REGISTERS_3: begin
              register32Address   <= REG_CLKTICKCNT_L;
              register32WriteData <= clktickcnt[31:0];
              currState           <= WRITE_REGISTERS_4;
           end
           
           WRITE_REGISTERS_4: begin
              register32Address   <= REG_CLKTICKCNT_U;
              register32WriteData <= clktickcnt[63:32];
              currState           <= WRITE_REGISTERS_5;
           end

           WRITE_REGISTERS_5: begin
              register32Address   <= REG_SATA_ERRORS;
              register32WriteData <= regSATAErrorCount;
              currState           <= WRITE_REGISTERS_6;
           end

           WRITE_REGISTERS_6: begin
              register32Address   <= REG_DATA_ERRORS;
              register32WriteData <= regDataErrorCount;
              currState           <= WRITE_REGISTERS_7;
           end
           
           WRITE_REGISTERS_7: begin
              if(register32CmdAck == 1 && register32CmdReq == 1) begin
                 register32CmdReq  <= 0;
                 register32WriteEn <= 0;
                 userRunClear      <= 1;
                 currState         <= IDLE;
              end
           end
           
           /* ------------------------------------------------------------ */
           /* Idle : waiting for command from user application             */
           /* ------------------------------------------------------------ */
           
           IDLE: begin
              clock_count  <= 0;
              userRunClear <= 0;
              
              // reset input memory
              inputMemoryReadReq <= 0;
              inputMemoryReadAdd <= 0;
              
              // reset output memory
              outputMemoryWriteAdd  <= 0;
              reg_buffercnt         <= 0;
              reg_cmd_failed        <= 0;
              reg_cmd_done          <= 0;

              sector_count_reset <= 1;
              clktickcnt_clear   <= 1;
              clktickcnt_en      <= 0;

              // reset benchmark registers
              inputMemReq        <= 0;
              inputMemValid      <= 0;
              regSATAErrorCount  <= 0;
              regDataErrorCount  <= 0;

              // benchmark mode
              benchmark          <= 0;
              benchmark_ncq      <= 0;
              benchmark_write_en <= 0;
              rng_reset          <= 1;

              if((userRunValue == 1) && (userRunClear != 1)) begin
                 rng_reset         <= 0;
                 register32Address <= 0;
                 register32WriteEn <= 0;
                 register32CmdReq  <= 1;
                 currState         <= READ_REGISTERS;
              end
           end
           
           /* ------------------------------------------------------------ */
           /* Read registers                                               */
           /* ------------------------------------------------------------ */
           
           // reg 0 = CMD
           // reg 1 = LBA_L
           // reg 2 = LBA_U
           // reg 3 = SECTORCNT
           
           READ_REGISTERS: begin

              sector_count_reset <= 0;
              
              // if we just accepted a read, stop requesting reads
              if(register32CmdAck == 1 && register32CmdReq == 1) begin
                 register32CmdReq <= 0;
              end
              // if a read came back, shift in the value from the register file
              if(register32ReadDataValid) begin
                 if(register32Address < 4) begin
                    register32Address <= register32Address+1;
                    register32CmdReq  <= 1;
                 end
                 else begin
                    register32CmdReq <= 0;
                 end
                 
                 CMD       <= LBA_L;              // reg 0
                 LBA_L     <= LBA_U;              // reg 1
                 LBA_U     <= SECTORCNT;          // reg 2
                 SECTORCNT <= NUMWORDS;           // reg 3
                 NUMWORDS  <= register32ReadData; // reg 4
                 
                 if(register32Address == 4) begin
                    currState        <= EXECUTE_CMD;
                    register32CmdReq <= 0;
                 end
              end
           end

           EXECUTE_CMD: begin
              case(CMD)
                // identify device
                CMD_IDENTIFY_DEVICE: begin
                   currState <= IDENTIFY_0;
                end
                
                // single read dma command
                CMD_READ_DMA_EXTENDED: begin
                   currState <= READ_0;
                end
                
                // single write dma command
                CMD_WRITE_DMA_EXTENDED: begin
                   currState <= WRITE_0;
                end
                
                // single read ncq command
                CMD_FIRST_PARTY_DMA_READ_NCQ: begin
                   currState <= READ_NCQ_0;
                end
                
                // single write ncq command
                CMD_FIRST_PARTY_DMA_WRITE_NCQ: begin
                   currState <= WRITE_NCQ_0;
                end

                // benchmark : DMA read
                CMD_BENCHMARK_READ_DMA: begin
                   data_error_reset   <= 1;
                   benchmark          <= 1;
                   inputMemoryReadReq <= 1;
                   clktickcnt_clear   <= 0;
                   clktickcnt_en      <= 1;
                   currState          <= BENCHMARK_READ_DMA_0;
                end

                // benchmark : DMA write
                CMD_BENCHMARK_WRITE_DMA: begin
                   benchmark          <= 1;
                   inputMemoryReadReq <= 1;
                   clktickcnt_clear   <= 0;
                   clktickcnt_en      <= 1;
                   currState          <= BENCHMARK_WRITE_DMA_0;
                end

                // benchmark : NCQ read
                CMD_BENCHMARK_READ_NCQ: begin
                   data_error_reset   <= 1;
                   benchmark          <= 1;
                   benchmark_ncq      <= 1;
                   inputMemoryReadReq <= 1;
                   clktickcnt_clear   <= 0;
                   clktickcnt_en      <= 1;
                   currState          <= BENCHMARK_READ_NCQ_0;
                end

                // benchmark : NCQ read
                CMD_BENCHMARK_WRITE_NCQ: begin
                   benchmark          <= 1;
                   benchmark_ncq      <= 1;
                   inputMemoryReadReq <= 1;
                   clktickcnt_clear   <= 0;
                   clktickcnt_en      <= 1;
                   currState          <= BENCHMARK_WRITE_NCQ_0;
                end
                
                default: begin
                   userRunClear <= 1;
                   currState    <= IDLE;
                end
              endcase
           end

           
           /* ------------------------------------------------------------ */
           /* Identify Device (0xEC) states                                */
           /* ------------------------------------------------------------ */

           IDENTIFY_0: begin
              cmd_en    <= 1;
              cmd       <= CMD_IDENTIFY_DEVICE;
              currState <= IDENTIFY_1;
           end

           IDENTIFY_1: begin
              cmd_en <= 0;
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(cmd_failed || cmd_success) begin
                 reg_cmd_failed <= cmd_failed;
                 currState      <= IDENTIFY_2;
              end
           end

           IDENTIFY_2: begin
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(!rdata_next) begin
                 rdata_next <= 0;
                 currState  <= WRITE_REGISTERS_0;
              end
           end
           
           /* ------------------------------------------------------------ */
           /* Read DMA Extended (0x25) states                              */
           /* ------------------------------------------------------------ */
           
           READ_0: begin
              cmd_en    <= 1;
              cmd       <= CMD_READ_DMA_EXTENDED;
              lba       <= {LBA_U[23:0],LBA_L[23:0]};
              sectorcnt <= SECTORCNT[15:0];
              currState <= READ_1;
           end
           
           READ_1: begin
              cmd_en <= 0;
              if(!rdata_empty) begin
                 rdata_next  <= 1;
                 clock_count <= clock_count+1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(cmd_failed || cmd_success) begin
                 reg_cmd_failed <= cmd_failed;
                 currState      <= READ_2;
              end

              // test flow control mechanism : stop sending data to buffer during FIS transmission
              if(clock_count == 57) begin
                 rdata_next  <= 0;
                 clock_count <= 0;
                 currState   <= READ_HOLD;
              end
           end

           READ_2: begin
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(!rdata_next) begin
                 rdata_next <= 0;
                 currState  <= WRITE_REGISTERS_0;
              end
           end

           // wait 10000 clock cycles before resuming transmission
           READ_HOLD: begin
              if(cmd_failed || cmd_success) begin
                 reg_cmd_failed <= cmd_failed;
                 reg_cmd_done   <= 1;
              end
              
              clock_count <= clock_count+1;
              if(clock_count == 10000) begin
                 if(reg_cmd_done || cmd_failed || cmd_success) begin
                    if(!rdata_empty) begin
                       rdata_next <= 1;
                    end
                    currState <= READ_2;
                 end
                 else begin
                    currState <= READ_1;
                 end
              end
           end
           
           /* ------------------------------------------------------------ */
           /* Write DMA Extended (0x35) states                             */
           /* ------------------------------------------------------------ */

           WRITE_0: begin
              cmd_en    <= 1;
              cmd       <= CMD_WRITE_DMA_EXTENDED;
              lba       <= {LBA_U[23:0],LBA_L[23:0]};
              sectorcnt <= SECTORCNT[15:0];
              currState <= WRITE_1;
           end

           WRITE_1: begin
              cmd_en <= 0;
              if(!wdata_full) begin
                 inputMemoryReadReq <= 1;
                 currState          <= WRITE_2;
              end
           end

           WRITE_2: begin
              if((!wdata_full) && (!input_data_processed)) begin
                 inputMemoryReadReq <= 1;
                 inputMemoryReadAdd <= inputMemoryReadAdd+1;
                 clock_count        <= clock_count+1;
              end
              else begin
                inputMemoryReadReq <= 0;
              end
              if(input_data_processed) begin
                 currState <= WRITE_3;
              end

              // test flow control mechanism : stop sending data to buffer during FIS transmission
              if(clock_count == 66) begin
                 inputMemoryReadReq <= 0;
                 clock_count        <= 0;
                 currState          <= WRITE_HOLD;
              end
           end

           WRITE_3: begin
              if(cmd_failed || cmd_success) begin
                 inputMemoryReadReq <= 0;
                 reg_cmd_failed     <= cmd_failed;
                 currState          <= WRITE_REGISTERS_0;
              end
           end

           // wait 10000 clock cycles before resuming transmission
           WRITE_HOLD: begin
              clock_count <= clock_count+1;
              if(clock_count == 10000) begin
                 inputMemoryReadReq <= 1;
                 currState          <= WRITE_2;
              end
           end

           /* ------------------------------------------------------------ */
           /* First Party DMA Read (0x60) states                           */
           /* ------------------------------------------------------------ */

           // --- Desc : NCQ read is used synchronously for testing purposes,
           // ---        e.g., we issue a single read and wait for the response
           // --         without issuing more commands in between.

           // Issue command (0x60), (tag = 0x3) 
           READ_NCQ_0: begin
              cmd_en    <= 1;
              cmd       <= CMD_FIRST_PARTY_DMA_READ_NCQ;
              lba       <= {LBA_U[23:0],LBA_L[23:0]};
              sectorcnt <= SECTORCNT[15:0];
              ncq_wtag  <= 5'h03;
              currState <= READ_NCQ_1;
           end

           // Wait for command to complete
           READ_NCQ_1: begin
              cmd_en <= 0;
              if(cmd_failed || cmd_success) begin
                 // Something went wrong -> abort
                 if(cmd_failed) begin
                    reg_cmd_failed <= cmd_failed;
                    currState      <= READ_NCQ_3;
                 end
                 // Now wait for data
                 else begin
                    currState <= READ_NCQ_2;
                 end
              end
           end

           // Read data coming back from drive
           READ_NCQ_2: begin
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(cmd_failed || cmd_success) begin
                 reg_cmd_failed <= cmd_failed;
                 currState      <= READ_NCQ_3;
              end
           end

           // Finish -> write out results
           READ_NCQ_3: begin
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(!rdata_next) begin
                 rdata_next <= 0;
                 currState  <= WRITE_REGISTERS_0;
              end
           end

           /* ------------------------------------------------------------ */
           /* First Party DMA Write (0x60) states                          */
           /* ------------------------------------------------------------ */

           // --- Desc : NCQ write is used synchronously for testing purposes,
           // ---        e.g., we issue a single write and wait for the response
           // --         without issuing more commands in between.

           // Issue command (0x61), (tag = 0x3)            
           WRITE_NCQ_0: begin
              cmd_en    <= 1;
              cmd       <= CMD_FIRST_PARTY_DMA_WRITE_NCQ;
              lba       <= {LBA_U[23:0],LBA_L[23:0]};
              sectorcnt <= SECTORCNT[15:0];
              ncq_wtag  <= 5'h03;
              currState <= WRITE_NCQ_1;
           end

           // Wait for command to complete 
           WRITE_NCQ_1: begin
              cmd_en <= 0;
              if(cmd_failed || cmd_success) begin
                 // Something went wrong -> abort
                 if(cmd_failed) begin
                    reg_cmd_failed <= cmd_failed;
                    currState      <= WRITE_NCQ_3;
                 end
                 // Now wait for data
                 else begin
                    currState <= WRITE_NCQ_2;
                 end
              end
           end

           // Write data to HBA buffer 
           WRITE_NCQ_2: begin
              if((!wdata_full) && (!input_data_processed)) begin
                 inputMemoryReadReq <= 1;
                 inputMemoryReadAdd <= inputMemoryReadAdd+1;
              end
              else begin
                inputMemoryReadReq <= 0;
              end
              if(input_data_processed) begin
                 currState <= WRITE_NCQ_3;
              end
           end
           
           // Finish -> write out results
           WRITE_NCQ_3: begin
              if(cmd_failed || cmd_success) begin
                 inputMemoryReadReq <= 0;
                 reg_cmd_failed     <= cmd_failed;
                 currState          <= WRITE_REGISTERS_0;
              end
           end

           /* ------------------------------------------------------------ */
           /* Benchmark: Perform sequence of reads using DMA cmds          */
           /* ------------------------------------------------------------ */
           
           BENCHMARK_READ_DMA_0: begin
              data_error_reset <= 0;
              if(inputMemoryReadDataValid == 1) begin
                if(inputMemValid) begin
                   LBA_L[31:16]  <= inputMemoryReadData;
                   inputMemReq   <= 0;
                   inputMemValid <= 0;
                   currState     <= BENCHMARK_READ_DMA_1;
                end
                else begin
                   LBA_L[15:0]   <= inputMemoryReadData;
                   inputMemValid <= 1;
                end
              end
              
              if((inputMemoryReadReq == 1) && (inputMemoryReadAck == 1)) begin
                 inputMemoryReadAdd <= inputMemoryReadAdd+1;
                 if(inputMemReq) begin
                    inputMemoryReadReq <= 0;
                 end
                 else begin
                    inputMemReq <= 1;
                 end
              end
           end

           BENCHMARK_READ_DMA_1: begin
              cmd_en      <= 1;
              rng_setseed <= 1;
              cmd         <= CMD_READ_DMA_EXTENDED;
              lba         <= {16'h0000,LBA_L[31:0]};
              sectorcnt   <= SECTORCNT[15:0];
              currState   <= BENCHMARK_READ_DMA_2;
           end
           
           BENCHMARK_READ_DMA_2: begin
              cmd_en      <= 0;
              rng_setseed <= 0;
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(cmd_failed || cmd_success) begin
                 if(cmd_failed) begin
                    regSATAErrorCount <= regSATAErrorCount+1;
                 end
                 if(data_error_reg) begin
                    regDataErrorCount <= regDataErrorCount+1;
                 end
                 currState <= BENCHMARK_READ_DMA_3;
              end
           end

           BENCHMARK_READ_DMA_3: begin
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              if(!rdata_next) begin
                 if(inputMemoryReadAdd == NUMWORDS) begin
                    clktickcnt_en <= 0;
                    currState     <= WRITE_REGISTERS_0;
                 end
                 else begin
                    data_error_reset   <= 1;
                    inputMemoryReadReq <= 1;
                    currState          <= BENCHMARK_READ_DMA_0;
                 end
              end
           end
           
           /* ------------------------------------------------------------ */
           /* Benchmark: Perform sequence of writes using DMA cmds         */
           /* ------------------------------------------------------------ */

           BENCHMARK_WRITE_DMA_0: begin
              if(inputMemoryReadDataValid == 1) begin
                 if(inputMemValid) begin
                    LBA_L[31:16]  <= inputMemoryReadData;
                    inputMemReq   <= 0;
                    inputMemValid <= 0;
                    currState     <= BENCHMARK_WRITE_DMA_1;
                 end
                 else begin
                    LBA_L[15:0]   <= inputMemoryReadData;
                    inputMemValid <= 1;
                 end
              end
              
              if((inputMemoryReadReq == 1) && (inputMemoryReadAck == 1)) begin
                 inputMemoryReadAdd <= inputMemoryReadAdd+1;
                 if(inputMemReq) begin
                    inputMemoryReadReq <= 0;
                 end
                 else begin
                    inputMemReq <= 1;
                 end
              end
           end

           BENCHMARK_WRITE_DMA_1: begin
              cmd_en      <= 1;
              rng_setseed <= 1;
              cmd         <= CMD_WRITE_DMA_EXTENDED;
              lba         <= {16'h0000,LBA_L[31:0]};
              sectorcnt   <= SECTORCNT[15:0];
              currState   <= BENCHMARK_WRITE_DMA_2;
           end

           BENCHMARK_WRITE_DMA_2: begin
              cmd_en      <= 0;
              rng_setseed <= 0;
              if(!wdata_full) begin
                 benchmark_write_en <= 1;
                 currState          <= BENCHMARK_WRITE_DMA_3;
              end
           end

           BENCHMARK_WRITE_DMA_3: begin
              if((!wdata_full) && (!input_data_processed)) begin
                 benchmark_write_en <= 1;
              end
              else begin
                 benchmark_write_en <= 0;
              end
              if(input_data_processed) begin
                 currState <= BENCHMARK_WRITE_DMA_4;
              end
           end

           BENCHMARK_WRITE_DMA_4: begin
              // command done
              if(cmd_failed || cmd_success) begin
                 // if there was an error, count it
                 if(cmd_failed) begin
                    regSATAErrorCount <= regSATAErrorCount+1;
                 end
                 // we processed all LBAs from input memory
                 if(inputMemoryReadAdd == NUMWORDS) begin
                    clktickcnt_en <= 0;
                    currState     <= WRITE_REGISTERS_0;
                 end
                 // there are still LBAs in the input memory to process
                 else begin
                    inputMemoryReadReq <= 1;
                    currState          <= BENCHMARK_WRITE_DMA_0;
                 end
              end
           end

           /* ------------------------------------------------------------ */
           /* Benchmark: Perform sequence of reads using NCQ cmds          */
           /* ------------------------------------------------------------ */

           // Load next LBA
           BENCHMARK_READ_NCQ_0: begin
              data_error_reset <= 0;
              
              // We don't have a valid LBA from previous attempt
              // -> load new LBA from input memory
              if(!ncq_lba_loaded) begin
                 if(inputMemoryReadDataValid == 1) begin
                    if(inputMemValid) begin
                       ncq_lba_loaded <= 1;
                       LBA_L[31:16]   <= inputMemoryReadData;
                       inputMemReq    <= 0;
                       inputMemValid  <= 0;
                       currState      <= BENCHMARK_READ_NCQ_1;
                    end
                    else begin
                       LBA_L[15:0]   <= inputMemoryReadData;
                       inputMemValid <= 1;
                    end
                 end
                 if((inputMemoryReadReq == 1) && (inputMemoryReadAck == 1)) begin
                    inputMemoryReadAdd <= inputMemoryReadAdd+1;
                    if(inputMemReq) begin
                       inputMemoryReadReq <= 0;
                    end
                    else begin
                       inputMemReq <= 1;
                    end
                 end
              end
              // LBA is already loaded from a previous attempt
              // -> skip this step
              else begin
                 currState <= BENCHMARK_READ_NCQ_1;
              end
           end

           // Attempt to issue next command
           BENCHMARK_READ_NCQ_1: begin
              // HBA is idle 
              // -> it's safe to issue command
              if(ncq_idle) begin
                 cmd_en    <= 1;
                 cmd       <= CMD_FIRST_PARTY_DMA_READ_NCQ;
                 lba       <= {16'h0000,LBA_L[31:0]};
                 sectorcnt <= SECTORCNT[15:0];
                 ncq_wtag  <= ncq_next_tag;
                 currState <= BENCHMARK_READ_NCQ_2;
              end
              // HBA is busy (data is received)
              // -> need to wait until HBA is ready
              else begin
                 currState <= BENCHMARK_READ_NCQ_3;
              end
           end

           // Wait for command to complete
           BENCHMARK_READ_NCQ_2: begin
              cmd_en <= 0;
              // Command was aborted by HBA because disk wants to transmit
              // -> need to wait until HBA is ready
              if(ncq_relinquish) begin
                 currState <= BENCHMARK_READ_NCQ_3;
              end
              // OK: command went through
              else if(cmd_failed || cmd_success) begin
                 // Count error and will retry
                 if(cmd_failed) begin
                    regSATAErrorCount <= regSATAErrorCount+1;
                 end
                 // Command succeded -> add to queue
                 else if(cmd_success) begin
                    ncq_lba_loaded          <= 0;
                    ncq_queue[ncq_next_tag] <= 1'b1;

                    // write LBA to tag location
                    BRAMen <= 1;
                    BRAMwe <= 4'b1111;
                 end
                 currState <= BENCHMARK_READ_NCQ_7;
              end
           end

           // Wait for Data or SActive
           BENCHMARK_READ_NCQ_3: begin
              // One or multiple commands completed 
              // -> clear completed queue slots
              if(ncq_SActive_valid) begin
                 ncq_queue <= ncq_queue ^ ncq_SActive;
                 currState <= BENCHMARK_READ_NCQ_7;
              end
              // Data was received
              // -> need to process data (empty buffers)
              else if(!rdata_empty) begin 
                 BRAMen    <= 1;            
                 currState <= BENCHMARK_READ_NCQ_4;
              end
           end

           // Set Seed
           BENCHMARK_READ_NCQ_4: begin
              BRAMen      <= 0;
              rng_setseed <= 1;
              currState   <= BENCHMARK_READ_NCQ_5;
           end

           BENCHMARK_READ_NCQ_5: begin
              rng_setseed <= 0;
              rdata_next  <= 1;
              currState   <= BENCHMARK_READ_NCQ_6;
           end

           // Wait for Data transfer to complete
           BENCHMARK_READ_NCQ_6: begin
              // Read data
              if(!rdata_empty) begin
                 rdata_next <= 1;
              end
              else begin
                 rdata_next <= 0;
              end
              // Data transfer is complete
              if((cmd_failed || cmd_success) && (rdata_next == 0)) begin
                 // Count error and will retry
                 if(cmd_failed) begin
                    regSATAErrorCount <= regSATAErrorCount+1;
                 end
                 if(data_error_reg) begin
                    regDataErrorCount <= regDataErrorCount+1;
                 end
                 currState <= BENCHMARK_READ_NCQ_7;
              end
           end  

           // Check if all LBAs have been processed
           // -> else continue
           BENCHMARK_READ_NCQ_7: begin
              // We processed all LBAs
              if((inputMemoryReadAdd == NUMWORDS) && (!ncq_lba_loaded)) begin
                 currState <= BENCHMARK_READ_NCQ_8;
              end
              // HBA is idle -> issue next command
              else if(ncq_idle) begin
                 // We have a valid next tag -> issue next command
                 if(ncq_next_tag_valid) begin
                    if(!ncq_lba_loaded) begin
                       data_error_reset   <= 1;
                       inputMemoryReadReq <= 1;
                    end
                    currState <= BENCHMARK_READ_NCQ_0;
                 end
              end
              // HBA is busy -> need to wait until HBA is ready
              else begin
                 currState <= BENCHMARK_READ_NCQ_3;
              end
           end      

           // All LBAs have been processed
           // -> wait until queueu is empty, then finish
           BENCHMARK_READ_NCQ_8: begin
              // HBA is idle
              if(ncq_idle) begin
                 // We are done if
                 //   - no more data in input buffer
                 //   - all queued commmands have been completed
                 //   - HBA is idle (should be idle anyway when all queued commands are completed)
                 if(rdata_empty && (ncq_queue == 0)) begin
                    clktickcnt_en <= 0;
                    currState     <= WRITE_REGISTERS_0;
                 end
              end
              // HBA is busy -> more data is being received
              else begin
                 currState <= BENCHMARK_READ_NCQ_3;
              end
           end
           
           /* ------------------------------------------------------------ */
           /* Benchmark: Perform sequence of writes using NCQ cmds         */
           /* ------------------------------------------------------------ */

           // Load next LBA
           BENCHMARK_WRITE_NCQ_0: begin
              // We don't have a valid LBA from previous attempt
              // -> load new LBA from input memory
              if(!ncq_lba_loaded) begin
                 if(inputMemoryReadDataValid == 1) begin
                    if(inputMemValid) begin
                       ncq_lba_loaded <= 1;
                       LBA_L[31:16]   <= inputMemoryReadData;
                       inputMemReq    <= 0;
                       inputMemValid  <= 0;
                       currState      <= BENCHMARK_WRITE_NCQ_1;
                    end
                    else begin
                       LBA_L[15:0]   <= inputMemoryReadData;
                       inputMemValid <= 1;
                    end
                 end
                 if((inputMemoryReadReq == 1) && (inputMemoryReadAck == 1)) begin
                    inputMemoryReadAdd <= inputMemoryReadAdd+1;
                    if(inputMemReq) begin
                       inputMemoryReadReq <= 0;
                    end
                    else begin
                       inputMemReq <= 1;
                    end
                 end
              end
              
              // LBA is already loaded from a previous attempt
              // -> skip this step
              else begin
                 currState <= BENCHMARK_WRITE_NCQ_1;
              end
           end

           // Attempt to issue next command
           BENCHMARK_WRITE_NCQ_1: begin
              // HBA is idle 
              // -> it's safe to issue command
              if(ncq_idle) begin
                 cmd_en    <= 1;
                 cmd       <= CMD_FIRST_PARTY_DMA_WRITE_NCQ;
                 lba       <= {16'h0000,LBA_L[31:0]};
                 sectorcnt <= SECTORCNT[15:0];
                 ncq_wtag  <= ncq_next_tag;
                 currState <= BENCHMARK_WRITE_NCQ_2;
              end
              
              // HBA is busy (data is received)
              // -> need to wait until HBA is ready
              else begin
                 currState <= BENCHMARK_WRITE_NCQ_3;
              end
           end

           // Wait for command to complete
           BENCHMARK_WRITE_NCQ_2: begin
              cmd_en <= 0;
              
              // Command was aborted by HBA because disk wants to transmit
              // -> need to wait until HBA is ready
              if(ncq_relinquish) begin
                 currState <= BENCHMARK_WRITE_NCQ_3;
              end

              // OK: command went through
              else if(cmd_failed || cmd_success) begin
                 // Count error and will retry
                 if(cmd_failed) begin
                    regSATAErrorCount <= regSATAErrorCount+1;
                 end
                 // Command succeded -> add to queue
                 else if(cmd_success) begin
                    ncq_lba_loaded          <= 0;
                    ncq_queue[ncq_next_tag] <= 1'b1;

                    // write LBA to tag location
                    BRAMen <= 1;
                    BRAMwe <= 4'b1111;
                 end
                 currState <= BENCHMARK_WRITE_NCQ_7;
              end
           end
          
           // Wait for SActive or request to transmit data
           BENCHMARK_WRITE_NCQ_3: begin
              // One or multiple commands completed 
              // -> clear completed queue slots
              if(ncq_SActive_valid) begin
                 ncq_queue <= ncq_queue ^ ncq_SActive;
                 currState <= BENCHMARK_WRITE_NCQ_7;
              end
              else if(ncq_ready_for_wdata) begin
                 // read LBA from tag location
                 BRAMen    <= 1;
                 currState <= BENCHMARK_WRITE_NCQ_4;
              end
           end

           // Set seed for RNG
           BENCHMARK_WRITE_NCQ_4: begin
              BRAMen      <= 0;
              rng_setseed <= 1;
              currState   <= BENCHMARK_WRITE_NCQ_5;
           end
           
           // Transmit write data
           BENCHMARK_WRITE_NCQ_5: begin
              rng_setseed <= 0;
              if((!wdata_full) && (!input_data_processed)) begin
                 benchmark_write_en <= 1;
              end
              else begin
                 benchmark_write_en <= 0;
              end
              if(input_data_processed) begin
                 currState <= BENCHMARK_WRITE_NCQ_6;
              end
           end

           // Wait for data transfer to complete
           BENCHMARK_WRITE_NCQ_6: begin
              // command done
              if(cmd_failed || cmd_success) begin
                 // if there was an error, count it
                 if(cmd_failed) begin
                    regSATAErrorCount <= regSATAErrorCount+1;
                 end
                 currState <= BENCHMARK_WRITE_NCQ_7;
              end
           end

           // Check if all LBAs have been processed
           // -> else continue
           BENCHMARK_WRITE_NCQ_7: begin
              // We processed all LBAs
              if((inputMemoryReadAdd == NUMWORDS) && (!ncq_lba_loaded)) begin
                 currState <= BENCHMARK_WRITE_NCQ_8;
              end
              
              // HBA is idle -> issue next command
              else if(ncq_idle) begin
                 // We have a valid next tag -> issue next command
                 if(ncq_next_tag_valid) begin
                    if(!ncq_lba_loaded) begin
                       inputMemoryReadReq <= 1;
                    end
                    currState <= BENCHMARK_WRITE_NCQ_0;
                 end
              end
              
              // HBA is busy -> need to wait until HBA is ready
              else begin
                 currState <= BENCHMARK_WRITE_NCQ_3;
              end
           end

           // All LBAs have been processed
           // -> wait until queueu is empty, then finish
           BENCHMARK_WRITE_NCQ_8: begin
              // HBA is idle
              if(ncq_idle) begin
                 // We are done if
                 //   - no more data in input buffer
                 //   - all queued commmands have been completed
                 //   - HBA is idle (should be idle anyway when all queued commands are completed)
                 if(input_BRAM_empty && (ncq_queue == 0)) begin
                    clktickcnt_en <= 0;
                    currState     <= WRITE_REGISTERS_0;
                 end
              end
              // HBA is busy -> more data is being received
              else begin
                 currState <= BENCHMARK_WRITE_NCQ_3;
              end
           end
           
         endcase
      end
   end
   
   // Time it takes to read/write a block
   always @(posedge clk) begin
      if(reset) begin
         clktickcnt <= 0;
      end
      else begin
         if(clktickcnt_clear) begin
            clktickcnt <= 0;
         end 
         else if(clktickcnt_en) begin
            clktickcnt <= clktickcnt+1;
         end
      end
   end
   
   // Count number of 16-bit words within a sector
   always @(posedge clk) begin
      if(word_count_reset) begin
         word_count <= 0;
      end 
      else if(benchmark ? benchmark_write_en : inputMemoryReadReq) begin
         word_count <= word_count+1;
      end
   end

   // Count number of sectors within a Data FIS
   always @(posedge clk) begin
      if(sector_count_reset) begin
         word_count_reset <= 1;
         sector_count     <= 0;
      end 
      else begin
         input_data_processed <= 0;
         word_count_reset     <= 0;
         // if word_count = 255 another sector has been processed
         if((benchmark ? benchmark_write_en : inputMemoryReadReq) && (word_count==8'hFE)) begin
            word_count_reset <= 1;
            if (sector_count == (SECTORCNT-1)) begin
               input_data_processed <= 1;
               sector_count         <= 0;
           end
            else begin
               sector_count <= sector_count+1;
            end
         end
      end
   end

   // Check for data errors
   always @(posedge clk) begin
      if(data_error_reset) begin
         data_error_reg <= 0;
      end 
      else begin
        if(data_error) begin
           data_error_reg <= 1;
        end
      end
   end

   // If we stop reading from buffer (rdata) we need to add
   // one clock cycle latency before we start producing new
   // random numbers
   
   always @(posedge clk) begin
      if(rdata_next) begin
         rng_latency <= 1;
      end
      else begin
         rng_latency <= 0;
      end
      rng_rdata_r <= rdata;
   end
   
   // buffer data from input BRAM
   FIFO 
     #(
       .WIDTH       (16),
       .DEPTH       (8),
       .ADDR_BITS   (3)
       )
   InputDataBuffer0
     (
      .clk         (clk),
      .reset       (reset),
      .dataIn      (benchmark ? rng_data           : inputMemoryReadData),
      .dataInWrite (benchmark ? benchmark_write_en : inputMemoryReadDataValid),
      .dataOut     (wdata),
      .dataOutRead (wdata_en),
      .empty       (input_BRAM_empty),
      .full        (input_BRAM_full),
      .underrun    (),
      .overflow    ()
      );
   
   
   // using scrambler for rng
   RNG RNG0 
     (
      .clk          (clk),
      .reset        (rng_reset),
      .enable       (rng_en),
      .setseed      (rng_setseed),
      .seed         (rng_seed),
      .scramblemask (rng_data)
      );


   // Get next valid tag
   // Loop trough queue until we find and empty spot
   always @(posedge clk) begin
      if(reset) begin
         ncq_next_tag <= 0;
      end
      else begin
         // loop until we find an empty spot in the queue
         if(ncq_queue[ncq_next_tag] == 1'b1) begin
            ncq_next_tag <= ncq_next_tag+1;
         end 
      end
   end
   
   assign ncq_next_tag_valid = (ncq_queue[ncq_next_tag] == 1'b1) ? 0 : 1;
   assign ncq_is_full        = (ncq_queue == NCQ_QUEUE_FULL)     ? 1 : 0;

   SinglePortBRAM_VHDL LBAStorage0
     (
      .clk         (clk),
      .reset       (reset),
      .BRAMAddr    ({4'b0000,BRAMAddr}),
      .BRAMDataIn  (LBA_L),
      .BRAMen      (BRAMen),
      .BRAMwe      (BRAMwe),
      .BRAMDataOut (BRAMDataOut)
      );
   
   assign BRAMAddr = (BRAMwe != 4'b0000) ? ncq_next_tag : ncq_rtag;
   
endmodule