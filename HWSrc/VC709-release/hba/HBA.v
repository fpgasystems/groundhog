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
 * Author        : Louis Woods <louis.woods@inf.ethz.ch>, ported to VC709 by Lisa Liu
 * Module        : HBA
 * Created       : April 18 2012
 * Last Update   : December 03 2013
 * ---------------------------------------------------------------------------
 * Description   : This module provides the interface of the SATA core to 
 *                 any FPGA application. It instantiates the speed control 
 *                 module, the DCM, the link module and the transport module.
 * ---------------------------------------------------------------------------
 * Notice        : instantiate this HBA in your own project, you cannot
 *                 instantiate it within the test-framework that we provdie
 *                 for the XUPV5-based HBA
 * ------------------------------------------------------------------------- */

module HBA 
  #(
    // Simulation attributes
    parameter SIM_GTPRESET_SPEEDUP = 1,      // Set to 1 to speed up sim reset
    parameter SIM_PLL_PERDIV2      = 9'h14d, // Set to the VCO Unit Interval time

    // Refclk attributes
    parameter CLKINDC_B = "TRUE", 

    // Channel bonding attributes
    parameter CHAN_BOND_MODE_0  = "OFF", // "MASTER", "SLAVE", or "OFF"
    parameter CHAN_BOND_LEVEL_0 = 0,     // 0 to 7. See UG for details
    parameter CHAN_BOND_MODE_1  = "OFF", // "MASTER", "SLAVE", or "OFF"
    parameter CHAN_BOND_LEVEL_1 = 0      // 0 to 7. See UG for details
    )
   (
    // clock and reset
    input         hard_reset, // Active high, reset button pushed on board
    input         soft_reset, // Active high, reset button or soft reset
    input         cpll_ref_clk, //60MHz clock generated via PLL in the top module, also drp clk
    output        gth_refclk, //150MHz SATA3 clock used for reset link and gth
    output        sata_sys_clock, // 75/150 MHZ system clock
   
    // ports that connect to I/O pins of the FPGA
    input         TILE0_REFCLK_PAD_P_IN, // GTP reference clock input
    input         TILE0_REFCLK_PAD_N_IN, // GTP reference clock input
    input         RXP0_IN, // Receiver input
    input         RXN0_IN, // Receiver input
    output        TXP0_OUT, // Transceiver output
    output        TXN0_OUT, // Transceiver output

    // HBA main interface: input ports
    input [2:0]   cmd,
    input         cmd_en,
    input [47:0]  lba,
    input [15:0]  sectorcnt,
    input [15:0]  wdata,
    input         wdata_en,
    input         rdata_next, 

    // HBA main interface: output ports
    output        wdata_full,
    output [15:0] rdata,
    output        rdata_empty,
    output        cmd_failed,
    output        cmd_success,

    // HBA additional reporting signals
    output        link_initialized,
    output [1:0]  link_gen,

    // HBA NCQ extension
    input [4:0]   ncq_wtag,
    output [4:0]  ncq_rtag,
    output        ncq_idle,
    output        ncq_relinquish,
    output        ncq_ready_for_wdata,
    output [31:0] ncq_SActive,
    output        ncq_SActive_valid
    );

   wire           drp_clk;
   // Link module connections
   wire           from_link_comreset;
   wire           from_link_initialized;
   wire           from_link_idle;
   wire           from_link_ready_to_transmit;
   wire           from_link_next;
   wire [31:0]    from_link_data;
   wire           from_link_data_en;
   wire           from_link_done;
   wire           from_link_err;

   wire           to_link_FIS_rdy;
   wire [31:0]    to_link_data;
   wire           to_link_done;
   wire           to_link_receive_overflow;
   wire           to_link_send_empty;
   wire           to_link_send_underrun;

   // RX GTH tile <-> Link Module
   //wire [2:0]     RXSTATUS0;
   wire           RXELECIDLE0;
   wire [1:0]     RXCHARISK0;
   wire [15:0]    RXDATA;
   wire           RXBYTEISALIGNED0;
   wire           RXRESET;

   // TX GTH tile <-> Link Module
   wire           TXCOMSTART0;
   wire           TXCOMTYPE0;
   wire           TXELECIDLE;
   wire [15:0]    TXDATA;
   wire           TXCHARISK;
   
   // Other GTH tile RX signals
   wire           RXUSRCLK1;
   wire           RXUSRCLK2;
   wire           RXENELECIDLERESETB;
   wire           RXELECIDLERESET0;
   
   // Other GTH tile TX signals
   wire           TXUSRCLK1;
   wire           TXUSRCLK2;

   // Other GTH tile general signals
   wire           PLLLKDET;
   wire           RESETDONE0;
   wire           REFCLKOUT;
   
   wire           rx_reset_done, tx_reset_done;
   wire           rx_comwake_det, rx_cominit_det;
   wire           tx_cominit, tx_comfinish, tx_comwake;

   wire           logic_clk;

   // Speed Negotiation Control
   //   wire [15:0]    snc_do;        // DRP data out
   //   wire           snc_drdy;      // DRP ready
   //   wire           snc_reset;     // Clock Freq. Change -> reset
   //   wire [6:0]     snc_daddr;     // DRP Address
   //   wire           snc_den;       // DRP enable
   //   wire [15:0]    snc_di;        // DRP data in
   //   wire           snc_dwe;       // DRP write enable  
   //   wire [1:0]     snc_gen_value; // SATA I/II (III -> future release)
   wire           link_reset;
   wire           gth_reset;
   wire           gth_refclk_156;
   wire           clk150_locked;
   wire           clkdv;

   // signal assignments
   assign link_initialized   = from_link_initialized;

   // GTP clock assignments
   assign TXUSRCLK1 = logic_clk;//usrclk;
   assign TXUSRCLK2 = logic_clk;
   assign RXUSRCLK1 = logic_clk;//usrclk;
   assign RXUSRCLK2 = logic_clk;
   
   assign gth_reset          =  soft_reset | hard_reset;    // | ~clk150_locked; //soft_reset || snc_reset;
   assign link_reset     =  soft_reset | hard_reset;
   //assign dcm_reset          = (!PLLLKDET) || snc_reset;
   assign RXELECIDLERESET0   = (RXELECIDLE0 && RESETDONE0);
   assign RXENELECIDLERESETB = !RXELECIDLERESET0; 
   
   // GTH clock buffers

   gth_sata_GT_USRCLK_SOURCE gt_usrclk_source
     (
      .Q8_CLK0_GTREFCLK_PAD_N_IN  (TILE0_REFCLK_PAD_N_IN),
      .Q8_CLK0_GTREFCLK_PAD_P_IN  (TILE0_REFCLK_PAD_P_IN),
      .Q8_CLK0_GTREFCLK_OUT       (gth_refclk_156),
      
      .GT0_TXUSRCLK_OUT    (logic_clk),
      .GT0_TXUSRCLK2_OUT   (), //TXUSRCLK2 is same as TXUSRCLK
      .GT0_TXOUTCLK_IN     (REFCLKOUT),
      .GT0_RXUSRCLK_OUT    (),
      .GT0_RXUSRCLK2_OUT   (),
      
      .DRPCLK_IN (cpll_ref_clk),
      .DRPCLK_OUT(drp_clk)
      );
   
   Clk150 genClk150x
     (// Clock in ports
      .CLK_IN1(gth_refclk_156),      // IN
      // Clock out ports
      .CLK_OUT1(gth_refclk),     // OUT
      // Status and control signals
      .RESET(1'b0),//(hard_reset),// IN
      .LOCKED(clk150_locked));


   BUFG sata_sys_clock_bufg 
     (
      .I (logic_clk), 
      .O (sata_sys_clock)
      );
   
   Link Link0
     (
      .clk                         (logic_clk),
      .reset                       (link_reset),//(gth_reset),
      // .gen_value                   (1'b1),//(snc_gen_value==2'b10),
      
      .rx_locked                   (PLLLKDET),
      //.rx_status                   (RXSTATUS0),
      .rx_cominit_det      (rx_cominit_det),
      .rx_comwake_det      (rx_comwake_det),
      .rx_elecidle                 (RXELECIDLE0),
      .rx_charisk                  (RXCHARISK0),
      .rx_datain                   (RXDATA),
      .rx_byteisaligned            (RXBYTEISALIGNED0),
      .rx_reset                    (RXRESET),
      
      //.tx_comstart                 (TXCOMSTART0),
      //.tx_comtype                  (TXCOMTYPE0),
      .tx_cominit        (tx_cominit),
      //.tx_comfinish       (tx_comfinish),
      .tx_comwake        (tx_comwake),
      .tx_elecidle                 (TXELECIDEL),
      .tx_data                     (TXDATA),
      .tx_charisk                  (TXCHARISK),

      .from_link_comreset          (from_link_comreset),
      .from_link_initialized       (from_link_initialized),
      .from_link_idle              (from_link_idle),
      .from_link_ready_to_transmit (from_link_ready_to_transmit),
      .from_link_next              (from_link_next),
      .from_link_data              (from_link_data),
      .from_link_data_en           (from_link_data_en),
      .from_link_done              (from_link_done),
      .from_link_err               (from_link_err),

      .to_link_FIS_rdy             (to_link_FIS_rdy),
      .to_link_data                (to_link_data),
      .to_link_done                (to_link_done),
      .to_link_receive_empty       (rdata_empty),
      .to_link_receive_overflow    (to_link_receive_overflow),
      .to_link_send_empty          (to_link_send_empty),
      .to_link_send_underrun       (to_link_send_underrun)
      );

   Transport Transport0
     (
      .clk                         (logic_clk),
      .reset                       (from_link_comreset),

      // HBA main interface: input ports
      .cmd                         (cmd),
      .cmd_en                      (cmd_en),
      .lba                         (lba),
      .sectorcnt                   (sectorcnt),
      .wdata                       (wdata),
      .wdata_en                    (wdata_en),
      .rdata_next                  (rdata_next), 

      // HBA main interface: output ports
      .wdata_full                  (wdata_full),
      .rdata                       (rdata),
      .rdata_empty                 (rdata_empty),
      .cmd_failed                  (cmd_failed),
      .cmd_success                 (cmd_success),

      // HBA NCQ extension
      .ncq_wtag                    (ncq_wtag),
      .ncq_rtag                    (ncq_rtag),
      .ncq_idle                    (ncq_idle),
      .ncq_relinquish              (ncq_relinquish),
      .ncq_ready_for_wdata         (ncq_ready_for_wdata),
      .ncq_SActive                 (ncq_SActive),
      .ncq_SActive_valid           (ncq_SActive_valid),
      
      // Link module
      .from_link_idle              (from_link_idle),
      .from_link_ready_to_transmit (from_link_ready_to_transmit),
      .from_link_next              (from_link_next),
      .from_link_data              (from_link_data),
      .from_link_data_en           (from_link_data_en),
      .from_link_done              (from_link_done),
      .from_link_err               (from_link_err),

      .to_link_FIS_rdy             (to_link_FIS_rdy),
      .to_link_data                (to_link_data),
      .to_link_done                (to_link_done),
      .to_link_receive_overflow    (to_link_receive_overflow),
      .to_link_send_empty          (to_link_send_empty),
      .to_link_send_underrun       (to_link_send_underrun)
      );

   
   assign link_gen = 2; //snc_gen_value;
   assign RESETDONE0 = rx_reset_done & tx_reset_done;
   //instantiate one GTH at location X1Y38 to connect SATA1 on FMC XM104
   gth_sata #
     (
      .EXAMPLE_SIMULATION             (0),
      .WRAPPER_SIM_GTRESET_SPEEDUP    ("TRUE")
      )
   gth_sata_i
     (
      //.GT0_DRP_BUSY_OUT               (),
      
      //_____________________________________________________________________
      //_____________________________________________________________________
      //GT0  (X1Y38) //connect to the SATA1 port on xm104

      //------------------------------- CPLL Ports -------------------------------
      .GT0_CPLLFBCLKLOST_OUT          (),
      .GT0_CPLLLOCK_OUT               (PLLLKDET),
      .GT0_CPLLLOCKDETCLK_IN          (cpll_ref_clk),
      .GT0_CPLLREFCLKLOST_OUT         (),
      .GT0_CPLLRESET_IN               (gth_reset),
      //------------------------ Channel - Clocking Ports ------------------------
      .GT0_GTREFCLK0_IN               (gth_refclk),
      //-------------------------- Channel - DRP Ports  --------------------------
      .GT0_DRPADDR_IN                 (0),
      .GT0_DRPCLK_IN                  (drp_clk),
      .GT0_DRPDI_IN                   (0),//(snc_di),
      .GT0_DRPDO_OUT                  (),//(snc_do),
      .GT0_DRPEN_IN                   (1'b0), //(snc_den),
      .GT0_DRPRDY_OUT                 (), //(snc_drdy),
      .GT0_DRPWE_IN                   (1'b0), //(snc_dwe),
      //------------------- RX Initialization and Reset Ports --------------------
      .GT0_RXUSERRDY_IN               (~gth_reset & PLLLKDET & ~RXRESET), //asserted when usr_clk is stable and uer interface is ready to receive from GTH transceiver
      //------------------------ RX Margin Analysis Ports ------------------------
      .GT0_EYESCANDATAERROR_OUT       (),
      //----------------------- Receive Ports - CDR Ports ------------------------
      .GT0_RXCDRLOCK_OUT              (),
      //---------------- Receive Ports - FPGA RX Interface Ports -----------------
      .GT0_RXUSRCLK_IN                (logic_clk),
      .GT0_RXUSRCLK2_IN               (logic_clk),
      //---------------- Receive Ports - FPGA RX interface Ports -----------------
      .GT0_RXDATA_OUT                 (RXDATA),
      //---------------------- Receive Ports - RX AFE Ports ----------------------
      .GT0_GTHRXN_IN                  (RXN0_IN),
      //---------------------- Receive Ports -RX AFE Ports -----------------------
      .GT0_GTHRXP_IN                  (RXP0_IN),
      //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
      .GT0_RXSTATUS_OUT               (),
      //------------ Receive Ports - RX Byte and Word Alignment Ports ------------
      .GT0_RXBYTEISALIGNED_OUT        (RXBYTEISALIGNED0),
      //------------------- Receive Ports - RX Equalizer Ports -------------------
      .GT0_RXDFEAGCHOLD_IN            (1'b0),
      .GT0_RXDFELFHOLD_IN             (1'b0),
      //------------- Receive Ports - RX Fabric Output Control Ports -------------
      .GT0_RXOUTCLK_OUT               (),
      //----------- Receive Ports - RX Initialization and Reset Ports ------------
      .GT0_GTRXRESET_IN               (RXRESET | gth_reset | ~PLLLKDET), //(RXRESET), ,
      //----------------- Receive Ports - RX OOB Signaling ports -----------------
      .GT0_RXCOMSASDET_OUT            (),
      .GT0_RXCOMWAKEDET_OUT           (rx_comwake_det),
      //---------------- Receive Ports - RX OOB Signaling ports  -----------------
      .GT0_RXCOMINITDET_OUT           (rx_cominit_det),
      //---------------- Receive Ports - RX OOB signalling Ports -----------------
      .GT0_RXELECIDLE_OUT             (RXELECIDLE0),
      //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
      .GT0_RXCHARISK_OUT              (RXCHARISK0), // RX control value : rx_charisk[0] = 1 -> rx_datain[7:0] is K (control value) (e.g., 8'hBC = K28.5), rx_charisk[1] = 1 -> rx_datain[15:8] is K 
      //------------ Receive Ports -RX Initialization and Reset Ports ------------
      .GT0_RXRESETDONE_OUT            (rx_reset_done),
      //------------------- TX Initialization and Reset Ports --------------------
      .GT0_GTTXRESET_IN               (gth_reset | ~PLLLKDET),
      .GT0_TXUSERRDY_IN               (~gth_reset & PLLLKDET),
      //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
      .GT0_TXUSRCLK_IN                (logic_clk),
      .GT0_TXUSRCLK2_IN               (logic_clk),
      //------------------- Transmit Ports - PCI Express Ports -------------------
      .GT0_TXELECIDLE_IN              (TXELECIDEL),
      //---------------- Transmit Ports - TX Data Path interface -----------------
      .GT0_TXDATA_IN                  (TXDATA),
      //-------------- Transmit Ports - TX Driver and OOB signaling --------------
      .GT0_GTHTXN_OUT                 (TXN0_OUT),
      .GT0_GTHTXP_OUT                 (TXP0_OUT),
      //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
      .GT0_TXOUTCLK_OUT              (REFCLKOUT),
      .GT0_TXOUTCLKFABRIC_OUT         (),
      .GT0_TXOUTCLKPCS_OUT            (),
      //----------- Transmit Ports - TX Initialization and Reset Ports -----------
      .GT0_TXRESETDONE_OUT            (tx_reset_done),
      //---------------- Transmit Ports - TX OOB signalling Ports ----------------
      .GT0_TXCOMFINISH_OUT            (tx_comfinish),
      .GT0_TXCOMINIT_IN               (tx_cominit),
      .GT0_TXCOMSAS_IN                (1'b0),
      .GT0_TXCOMWAKE_IN               (tx_comwake),
      //--------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
      .GT0_TXCHARISK_IN               ({3'b0, TXCHARISK}),




      //____________________________COMMON PORTS________________________________
      //-------------------- Common Block  - Ref Clock Ports ---------------------
      .GT0_GTREFCLK0_COMMON_IN        (gth_refclk),
      //----------------------- Common Block - QPLL Ports ------------------------
      .GT0_QPLLLOCK_OUT               (),
      .GT0_QPLLLOCKDETCLK_IN          (cpll_ref_clk),
      .GT0_QPLLREFCLKLOST_OUT         (),
      .GT0_QPLLRESET_IN               (gth_reset)

      );

endmodule