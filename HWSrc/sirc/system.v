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
 * Module        : system
 * Created       : April 18 2012
 * Last Update   : November 20 2013
 * ---------------------------------------------------------------------------
 * Description   : This is the top module of the example testbench. 
 *                 It is a modified version of the system.v file in the SIRC v1.0 codebase.  
 *                 For more details regarding SIRC please go to 
 *                 http://research.microsoft.com/en-us/downloads/d335458e-c241-4845-b0ef-c587c8d29796/
 * ---------------------------------------------------------------------------
 * Changelog     : none
 * ------------------------------------------------------------------------- */

`timescale 1ns / 1ps
`default_nettype none

module system #(
 //************ Input and output block memory parameters
 //The user's circuit communicates with the input and output memories as N-byte chunks
 //These should be defined as {1, 2, 4, 8, 16, 32} corresponding to an 8, 16, 32, 64, 128, or 256-bit interface.
 //If this value is changed, reflect the changes in the input/output memory .xco and regenerate the core.
 //Note that if more than 1 byte is used by the user, the organization of the bytes are little endian.  For example if N=4,
 // address 32-bit word 0 = {b3:b2:b1:b0}
 // address 32-bit word 1 = {b7:b6:b5:b4}...
 parameter INMEM_USER_BYTE_WIDTH = 2,
 parameter OUTMEM_USER_BYTE_WIDTH = 2,
 //How many address lines are required by the input and output buffers?
 //Stated another way, the "BYTE_WIDTH" parameter determined the width of the words,
 // the "ADDRESS_WIDTH" parameter determines the 2^M word height of buffer.
 //If this value is changed, reflect the changes in the input/output memory .xco and regenerate the core.
 
 parameter INMEM_USER_ADDRESS_WIDTH = 16,
 parameter OUTMEM_USER_ADDRESS_WIDTH = 11,
 //parameter INMEM_USER_ADDRESS_WIDTH = 8,
 //parameter OUTMEM_USER_ADDRESS_WIDTH = 10,
 
 //Was the input memory generated with the "Register Port B Output of Memory Core" box checked?
 //This should be 0 if not, 1 if so.  If this value is changed, reflect the modification in the
 // input memory .xco and regenerate the core.  Technically, it is also possible to account for selecting the
 // "Register Port B Output of Memory Primitives" option.  Either way, the value of this parameter should be equal 
 //  to the value reported by COREGen in the "Latency Added by Output register(s)", "Port B:" field.
 parameter INMEM_USER_REGISTER = 1,
 //What MAC address should the FPGA use?
 //This value is set within the project and does *not* require regeneration of the ethernet core.
 parameter MAC_ADDRESS = 48'hAAAAAAAAAAAA
)( 
 input     CLK_100,    // Primary 100 MHz clock input
 input     RESET,    // Active low reset from board-level button - resets everything on the board, from the
             //  user's circuit to the API controller to the ethernet PHY & clock generation circuits.
             // Should not normally need to be used.  Try the software command sendReset() instead.
             // However, in the worst-case situation where the board stops responding to all 
             //  ethernet commands, it is available to reset everything including the PHY

 //GMII PHY interface for EMAC0
 output [7:0] GMII_TXD_0,   //GMII TX data output
 output    GMII_TX_EN_0,  //GMII TX enable output
 output    GMII_TX_ER_0,  //GMII TX error output
 output    GMII_GTX_CLK_0, //GMII GTX clock output - notice, this is not the same as the GMII_TX_CLK input!
 input    [7:0] GMII_RXD_0,   //GMII RX data input
 input     GMII_RX_DV_0,  //GMII RX data valid input
 input     GMII_RX_ER_0,  //GMII RX error input
 input     GMII_RX_CLK_0,  //GMII RX clock input
 output    GMII_RESET_B,  //GMII reset (active low)

 //SystemACE interface
 input     sysACE_CLK,   //33 MHz clock
 output [6:0]  sysACE_MPADD,  //SystemACE Address
 inout [15:0]  sysACE_MPDATA,  //SystemACE Data
 output    sysACE_MPCE,  //SystemACE active low chip enable
 output    sysACE_MPWE,  //SystemACE active low write enable
 output    sysACE_MPOE,  //SystemACE active low output enable
 //input     sysACE_MPBRDY, //SystemACE active high buffer ready signal - currently unused
 //input     sysACE_MPIRQ, //SystemACE active high interrupt request - currently unused

 // GTP TILE 0 (SATA HOST 1) interface
 input  TILE0_REFCLK_PAD_P_IN, // MGTCLKA, clocks GTP_X0Y3, GTP reference clock input
 input  TILE0_REFCLK_PAD_N_IN, // MGTCLKA, clocks GTP_X0Y3 GTP reference clock input
 input  RXP0_IN,      // Receiving channel
 input  RXN0_IN,      // Receiving channel
 output TXP0_OUT,     // Transmitting channel
 output TXN0_OUT,     // Transmitting channel

 output [7:0] LED,     //8 optional LEDs for visual feedback & debugging
 output [1:0] ERROR_LED   //2 optional ERROR (red) LEDs
);
 //************Handle global asynchronous reset from physical switch on board
 // Buffer active low reset signal from board.
 wire hard_reset_low;
 //************DISABLE RESET
 //If a physical reset switch is not desired, uncomment the next line and commenting out the IBUF declaration on the following line
 //assign hard_reset_low = 1'b1;
 IBUF reset_ibuf (.I(RESET), .O(hard_reset_low));



 //************Generate a 200 MHz reference clock, a 125MHz ethernet clock and the user circuit clock from the 100 MHz clock provided
 // 200 = 100 * 10 / 5
 // 125 = 100 * 10 / 8
 wire clk_200_i;  //200 MHz clock from PLL
 wire clk_200;   //200 MHz clock after buffering
 wire clk_125_eth_i; //125 MHz clock from PLL
 wire clk_125_eth; //125 MHz clock after buffering
 wire pllFB;   //PLL feedback
 wire pllLock;   //PLL locked signal
 //************USER CLOCK
 //This is the clock for the user's interface to which the input/output buffers, register file and soft reset are synchronized.
 //wire clk_user_interface_i; //User clock directly from PLL
 //wire clk_user_interface;  //Buffered version of user clock
 wire clk_sata_interface;  // GTP tile generates the 150 MHz clock for the user logic
  
 PLL_BASE #(
  .COMPENSATION("SYSTEM_SYNCHRONOUS"),  // "SYSTEM_SYNCHRONOUS",
  .BANDWIDTH("OPTIMIZED"),      // "HIGH", "LOW" or "OPTIMIZED"

  .CLKFBOUT_MULT(10),       // Multiplication factor for all output clocks - 1000 = 100 * 10 / 1
  .DIVCLK_DIVIDE(1),        // Division factor for all clocks (1 to 52)
  .CLKFBOUT_PHASE(0.0),       // Phase shift (degrees) of all output clocks
  .REF_JITTER(0.100),       // Input reference jitter (0.000 to 0.999 UI%)
  .CLKIN_PERIOD(10.0),       // Clock period (ns) of input clock on CLKIN

  .CLKOUT0_DIVIDE(5),       // Division factor - 200 = 1000 / 5
  .CLKOUT0_PHASE(0.0),       // Phase shift (degrees) (0.0 to 360.0)
  .CLKOUT0_DUTY_CYCLE(0.5),     // Duty cycle (0.01 to 0.99)
  .CLKOUT1_DIVIDE(8),       // Division factor - 125 = 1000 / 8
  .CLKOUT1_PHASE(0.0),       // Phase shift (degrees) (0.0 to 360.0)
  .CLKOUT1_DUTY_CYCLE(0.5)     // Duty cycle (0.01 to 0.99)
  //************USER CLOCK
  //If a 167 MHz clock is not appropriate for the interface to the user's circuit, make changes here or
  //  comment out the following 3 lines and create a new PLL
  //Also, don't forget to update system.ucf!
  //.CLKOUT2_DIVIDE(6),       // Division factor - 167 = 1000/6
  //.CLKOUT2_PHASE(0.0),       // Phase shift (degrees) (0.0 to 360.0)
  //.CLKOUT2_DUTY_CYCLE(0.5)      // Duty cycle (0.01 to 0.99)
 ) clkBPLL (
  .CLKOUT0(clk_200_i),      // 200 MHz
  .CLKOUT1(clk_125_eth_i),     // 125 MHz
  //************USER CLOCK
  //If the user's circuit requires a different PLL, comment out the following line
  //.CLKOUT2(clk_user_interface_i),     
  .CLKFBOUT(pllFB),        // Clock feedback output
  .CLKIN(CLK_100),        // Clock input
  .CLKFBIN(pllFB),        // Clock feedback input
  .LOCKED(pllLock),        // Active high PLL lock signal
  .RST(~hard_reset_low)      // The only thing that will reset the PLL is the physical reset button
 );

 //Buffer clock signals coming out of PLL
 BUFG bufCLK_200 (.O(clk_200), .I(clk_200_i));
 BUFG bufCLK_125 (.O(clk_125_eth), .I(clk_125_eth_i));
 //BUFG bufCLK_user (.O(clk_user_interface), .I(clk_user_interface_i)); // GTP tile generates the 150 MHz clock for the user logic

 //************Instantiate ethernet communication controller
 //This is a line that tells that user's circuit to reset.
 //Notice, this is not a reset for the entire system, just the user's circuit
 wire userLogicReset;
 
 //Wires from the user design to the communication controller
 wire userRunValue;                   //Read run register value
 wire userRunClear;                   //Reset run register
 
 //Interface to parameter register file
 wire register32CmdReq;                  //Parameter register handshaking request signal
 wire register32CmdAck;                  //Parameter register handshaking acknowledgment signal
 wire [31:0] register32WriteData;              //Parameter register write data
 wire [7:0] register32Address;               //Parameter register address
 wire register32WriteEn;                 //Parameter register write enable
 wire register32ReadDataValid;               //Indicates that a read request has returned with data
 wire [31:0] register32ReadData;              //Parameter register read data
         
 //Interface to input memory
 wire inputMemoryReadReq;                 //Input memory handshaking request signal
 wire inputMemoryReadAck;                 //Input memory handshaking acknowledgment signal
 wire [(INMEM_USER_ADDRESS_WIDTH - 1):0]   inputMemoryReadAdd;   //Input memory read address line
 wire inputMemoryReadDataValid;               //Indicates that a read request has returned with data
 wire [((INMEM_USER_BYTE_WIDTH * 8) - 1):0]  inputMemoryReadData;   //Input memory read data line

 //Interface to output memory
 wire outputMemoryWriteReq;                //Output memory handshaking request signal
 wire outputMemoryWriteAck;                //Output memory handshaking acknowledgment signal
 wire [(OUTMEM_USER_ADDRESS_WIDTH - 1):0]   outputMemoryWriteAdd;  //Output memory write address line
 wire [((OUTMEM_USER_BYTE_WIDTH * 8) - 1):0] outputMemoryWriteData;  //Output memory write data line
 wire [(OUTMEM_USER_BYTE_WIDTH - 1):0]   outputMemoryWriteByteMask; //Output memory write byte mask

 ethernet2BlockMem #(
  //Forward parameters to controller
  .INMEM_USER_BYTE_WIDTH(INMEM_USER_BYTE_WIDTH),
  .OUTMEM_USER_BYTE_WIDTH(OUTMEM_USER_BYTE_WIDTH),
  .INMEM_USER_ADDRESS_WIDTH(INMEM_USER_ADDRESS_WIDTH),
  .OUTMEM_USER_ADDRESS_WIDTH(OUTMEM_USER_ADDRESS_WIDTH),
  .INMEM_USER_REGISTER(INMEM_USER_REGISTER),
  .MAC_ADDRESS(MAC_ADDRESS)
 ) E2M(
  .refClock(clk_200),             //This should be a 200 Mhz reference clock
  .clockLock(pllLock),            //This line from the clock generator indicates when the clocks are stable
  .hardResetLow(hard_reset_low),         //If this line goes low, the physical button told us to reset everything.
  .ethClock(clk_125_eth),           //This should be a 125 MHz source clock
  
  // GMII Interface - EMAC0
  .GMII_TXD(GMII_TXD_0),            //GMII TX data output
  .GMII_TX_EN(GMII_TX_EN_0),          //GMII TX enable output
  .GMII_TX_ER(GMII_TX_ER_0),          //GMII TX error output
  .GMII_GTX_CLK(GMII_GTX_CLK_0),         //GMII GTX clock output - notice, this is not the same as the GMII_TX_CLK input!
  .GMII_RXD(GMII_RXD_0),            //GMII RX data input
  .GMII_RX_DV(GMII_RX_DV_0),          //GMII RX data valid input
  .GMII_RX_ER(GMII_RX_ER_0),          //GMII RX error input
  .GMII_RX_CLK(GMII_RX_CLK_0),          //GMII RX clock input
  .GMII_RESET_B(GMII_RESET_B),          //GMII reset (active low)

  //SystemACE Interface
  .sysACE_CLK(sysACE_CLK),           //33 MHz clock
  .sysACE_MPADD(sysACE_MPADD),          //SystemACE Address
  .sysACE_MPDATA(sysACE_MPDATA),         //SystemACE Data in/out
  .sysACE_MPCE(sysACE_MPCE),          //SystemACE active low chip enable
  .sysACE_MPWE(sysACE_MPWE),          //SystemACE active low write enable
  .sysACE_MPOE(sysACE_MPOE),          //SystemACE active low output enable
  //.sysACE_MPBRDY(sysACE_MPBRDY),         //SystemACE active high buffer ready signal - currently unused
  //.sysACE_MPIRQ(sysACE_MPIRQ),         //SystemACE active high interrupt request - currently unused

  //************User-side interface
  //.userInterfaceClk(clk_user_interface),      //This is the clock to which the user's interface to the controller is synchronized (register file, i/o buffers & reset)
  .userInterfaceClk(clk_sata_interface),
  .userLogicReset(userLogicReset),        //This signal should be used to reset the user's circuit
                     //This will be asserted at configuration time, when the physical button is pressed or when the
                     //  sendReset command is received over the Ethernet.
  .userRunValue(userRunValue),          //Read run register value
  .userRunClear(userRunClear),          //Reset run register (active high)
  
  //User interface to parameter register file
  .register32CmdReq(register32CmdReq),       //Parameter register handshaking request signal
  .register32CmdAck(register32CmdAck),       //Parameter register handshaking acknowledgment signal
  .register32WriteData(register32WriteData),     //Parameter register write data
  .register32Address(register32Address),      //Parameter register address
  .register32WriteEn(register32WriteEn),      //Parameter register write enable
  .register32ReadDataValid(register32ReadDataValid),  //Indicates that a read request has returned with data
  .register32ReadData(register32ReadData),      //Parameter register read data
  
  //User interface to input memory
  .inputMemoryReadReq(inputMemoryReadReq),      //Input memory handshaking request signal
  .inputMemoryReadAck(inputMemoryReadAck),      //Input memory handshaking acknowledgment signal
  .inputMemoryReadAdd(inputMemoryReadAdd),      //Input memory read address line
  .inputMemoryReadDataValid(inputMemoryReadDataValid),  //Indicates that a read request has returned with data
  .inputMemoryReadData(inputMemoryReadData),     //Input memory read data line
  
  //User interface to output memory
  .outputMemoryWriteReq(outputMemoryWriteReq),    //Output memory handshaking request signal
  .outputMemoryWriteAck(outputMemoryWriteAck),    //Output memory handshaking acknowledgment signal
  .outputMemoryWriteAdd(outputMemoryWriteAdd),    //Output memory write address line
  .outputMemoryWriteData(outputMemoryWriteData),    //Output memory write data line
  .outputMemoryWriteByteMask(outputMemoryWriteByteMask) //Output memory write byte mask
 );

   //************GTP tile initialization

   // HBA main interface: input ports
   wire [2:0]                            cmd;
   wire                                  cmd_en;
   wire [47:0]                           lba;
   wire [15:0]                           sectorcnt;
   wire [15:0]                           wdata;
   wire                                  wdata_en;
   wire                                  rdata_next;

   // HBA main interface: output ports
   wire                                  wdata_full;
   wire [15:0]                           rdata;
   wire                                  rdata_empty;
   wire                                  cmd_failed;
   wire                                  cmd_success;

   // HBA additional reporting signals
   wire                                  link_initialized;
   wire [1:0]                            link_gen;
   
   // HBA NCQ extension
   wire [4:0]                            ncq_rtag;
   wire [4:0]                            ncq_wtag;
   wire                                  ncq_idle;
   wire                                  ncq_relinquish;
   wire                                  ncq_ready_for_wdata;
   wire [31:0]                           ncq_SActive;
   wire                                  ncq_SActive_valid;

   // Notice: this test framework will only work with the XUPV5 version
   //         of Groundhog, do not try to instatiate the VC709 version here
   
   HBA HBA0 
     (
      // clock and reset
      .hard_reset     (~hard_reset_low),    // Active high, reset button pushed on board
      .soft_reset     (userLogicReset),     // Active high, reset button or soft reset
      .sata_sys_clock (clk_sata_interface), // 75/150 MHZ system clock
      
      // ports that connect to I/O pins of the FPGA
      .TILE0_REFCLK_PAD_P_IN (TILE0_REFCLK_PAD_P_IN), // GTP reference clock input
      .TILE0_REFCLK_PAD_N_IN (TILE0_REFCLK_PAD_N_IN), // GTP reference clock input
      .RXP0_IN               (RXP0_IN),               // Receiver input
      .RXN0_IN               (RXN0_IN),               // Receiver input
      .TXP0_OUT              (TXP0_OUT),              // Transceiver output
      .TXN0_OUT              (TXN0_OUT),              // Transceiver output

      // HBA main interface: input ports
      .cmd              (cmd),
      .cmd_en           (cmd_en),
      .lba              (lba),
      .sectorcnt        (sectorcnt),
      .wdata            (wdata),
      .wdata_en         (wdata_en),
      .rdata_next       (rdata_next), 

      // HBA main interface: output ports
      .wdata_full       (wdata_full),
      .rdata            (rdata),
      .rdata_empty      (rdata_empty),
      .cmd_failed       (cmd_failed),
      .cmd_success      (cmd_success),

      // HBA additional reporting signals
      .link_initialized (link_initialized),
      .link_gen         (link_gen),
      
      // HBA NCQ extension
      .ncq_wtag            (ncq_wtag),
      .ncq_rtag            (ncq_rtag),
      .ncq_idle            (ncq_idle),
      .ncq_relinquish      (ncq_relinquish),
      .ncq_ready_for_wdata (ncq_ready_for_wdata),
      .ncq_SActive         (ncq_SActive),
      .ncq_SActive_valid   (ncq_SActive_valid)
      );
   
   //************Instantiate user module
   TestSATA 
     #(
       //Forward parameters to user circuit
       .INMEM_BYTE_WIDTH(INMEM_USER_BYTE_WIDTH),
       .OUTMEM_BYTE_WIDTH(OUTMEM_USER_BYTE_WIDTH),
       .INMEM_ADDRESS_WIDTH(INMEM_USER_ADDRESS_WIDTH),
       .OUTMEM_ADDRESS_WIDTH(OUTMEM_USER_ADDRESS_WIDTH)
       ) 
   TestModule0
     (
      .clk(clk_sata_interface),
      .reset(userLogicReset),           //When this signal is asserted (it is synchronous to userInterfaceClk), the user's circuit should reset
      
      .userRunValue(userRunValue),          //Read run register value - when this is asserted, the user's circuit has control over the i/o buffers & register file
      .userRunClear(userRunClear),          //Reset run register - assert this signal for 1 clock cycle to indicate that the user's circuit has completed computation and
      //  wishes to return control over the i/o buffers and register file back to the controller
      
      //User interface to parameter register file
      .register32CmdReq(register32CmdReq),       //Parameter register handshaking request signal
      .register32CmdAck(register32CmdAck),       //Parameter register handshaking acknowledgment signal
      .register32WriteData(register32WriteData),     //Parameter register write data
      .register32Address(register32Address),      //Parameter register address
      .register32WriteEn(register32WriteEn),      //Parameter register write enable
      .register32ReadDataValid(register32ReadDataValid),  //Indicates that a read request has returned with data
      .register32ReadData(register32ReadData),      //Parameter register read data
      
      //User interface to input memory
      .inputMemoryReadReq(inputMemoryReadReq),      //Input memory handshaking request signal - assert to begin a read request
      .inputMemoryReadAck(inputMemoryReadAck),      //Input memory handshaking acknowledgement signal - when the req and ack are both true for 1 clock cycle, the request has been accepted
      .inputMemoryReadAdd(inputMemoryReadAdd),      //Input memory read address - can be set the same cycle that the req line is asserted
      .inputMemoryReadDataValid(inputMemoryReadDataValid),  //After a read request is accepted, this line indicates that the read has returned and that the data is ready
      .inputMemoryReadData(inputMemoryReadData),     //Input memory read data
      
      //User interface to output memory
      .outputMemoryWriteReq(outputMemoryWriteReq),    //Output memory handshaking request signal - assert to begin a write request
      .outputMemoryWriteAck(outputMemoryWriteAck),    //Output memory handshaking acknowledgement signal - when the req and ack are both true for 1 clock cycle, the request has been accepted
      .outputMemoryWriteAdd(outputMemoryWriteAdd),    //Output memory write address - can be set the same cycle that the req line is asserted
      .outputMemoryWriteData(outputMemoryWriteData),    //Output memory write data
      .outputMemoryWriteByteMask(outputMemoryWriteByteMask), //Allows byte-wise writes when multibyte words are used - each of the OUTMEM_USER_BYTE_WIDTH line can be 0 (do not write byte) or 1 (write byte)
      
      .LED       (LED),
      .ERROR_LED (ERROR_LED),

      // HBA main interface: input ports
      .cmd         (cmd),
      .cmd_en      (cmd_en),
      .lba         (lba),
      .sectorcnt   (sectorcnt),
      .wdata       (wdata),
      .wdata_en    (wdata_en),
      .rdata_next  (rdata_next), 

      // HBA main interface: output ports
      .wdata_full       (wdata_full),
      .rdata            (rdata),
      .rdata_empty      (rdata_empty),
      .cmd_failed       (cmd_failed),
      .cmd_success      (cmd_success),

      // HBA additional reporting signals
      .link_initialized (link_initialized),
      .link_gen         (link_gen),
      
      // HBA NCQ extension
      .ncq_wtag            (ncq_wtag),
      .ncq_rtag            (ncq_rtag),
      .ncq_idle            (ncq_idle),
      .ncq_relinquish      (ncq_relinquish),
      .ncq_ready_for_wdata (ncq_ready_for_wdata),
      .ncq_SActive         (ncq_SActive),
      .ncq_SActive_valid   (ncq_SActive_valid)
      );

endmodule