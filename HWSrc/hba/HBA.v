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
 * Module        : HBA
 * Created       : April 18 2012
 * Last Update   : November 20 2013
 * ---------------------------------------------------------------------------
 * Description   : This module provides the interface of the SATA core to 
 *                 any FPGA application. It instantiates the speed control 
 *                 module, the DCM, the link module and the transport module.
 * ---------------------------------------------------------------------------
 * Changelog     : none
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
    input         hard_reset,     // Active high, reset button pushed on board
    input         soft_reset,     // Active high, reset button or soft reset
    output        sata_sys_clock, // 75/150 MHZ system clock (used for soft reset)
   
    // ports that connect to I/O pins of the FPGA
    input         TILE0_REFCLK_PAD_P_IN, // GTP reference clock input
    input         TILE0_REFCLK_PAD_N_IN, // GTP reference clock input
    input         RXP0_IN,               // Receiver input
    input         RXN0_IN,               // Receiver input
    output        TXP0_OUT,              // Transceiver output
    output        TXN0_OUT,              // Transceiver output

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

   // Link module connections
   wire           from_link_comreset;
   wire           from_link_initialized;
   wire           from_link_idle;
   wire           from_link_ready_to_transmit;
   wire           from_link_next;
   wire [15:0]    from_link_data;
   wire           from_link_data_en;
   wire           from_link_done;
   wire           from_link_err;

   wire           to_link_FIS_rdy;
   wire [15:0]    to_link_data;
   wire           to_link_done;
   wire           to_link_receive_overflow;
   wire           to_link_send_empty;
   wire           to_link_send_underrun;

   // RX GTP tile <-> Link Module
   wire [2:0]     RXSTATUS0;
   wire           RXELECIDLE0;
   wire [1:0]     RXCHARISK0;
   wire [15:0]    RXDATA;
   wire           RXBYTEISALIGNED0;
   wire           RXRESET;

   // TX GTP tile <-> Link Module
   wire           TXCOMSTART0;
   wire           TXCOMTYPE0;
   wire           TXELECIDLE;
   wire [15:0]    TXDATA;
   wire           TXCHARISK;
   
   // Other GTP tile RX signals
   wire           RXUSRCLK1;
   wire           RXUSRCLK2;
   wire           RXENELECIDLERESETB;
   wire           RXELECIDLERESET0;
   
   // Other GTP tile TX signals
   wire           TXUSRCLK1;
   wire           TXUSRCLK2;

   // Other GTP tile general signals
   wire           PLLLKDET;
   wire           RESETDONE0;
   wire           REFCLKOUT;

   // DCM signals
   wire           dcm_clk0;
   wire           dcm_clk2x;
   wire           dcm_clkdv;
   wire           dcm_locked;
   wire           dcm_refclkin;   
   wire           dcm_reset;
   
   // DCM output clocks and GTP user clocks
   wire           clk0;
   wire           clk2x;
   wire           usrclk;
   wire           logic_clk;

   // Speed Negotiation Control
   wire [15:0]    snc_do;        // DRP data out
   wire           snc_drdy;      // DRP ready
   wire           snc_reset;     // Clock Freq. Change -> reset
   wire [6:0]     snc_daddr;     // DRP Address
   wire           snc_den;       // DRP enable
   wire [15:0]    snc_di;        // DRP data in
   wire           snc_dwe;       // DRP write enable  
   wire [1:0]     snc_gen_value; // SATA I/II (III -> future release)

   wire           gtp_reset;
   wire           gtp_refclk;
   wire           clkdv;

   // signal assignments
   assign link_initialized   = from_link_initialized;

   // GTP clock assignments
   assign TXUSRCLK1 = usrclk;
   assign TXUSRCLK2 = logic_clk;
   assign RXUSRCLK1 = usrclk;
   assign RXUSRCLK2 = logic_clk;
   
   assign gtp_reset          = soft_reset || snc_reset;
   assign dcm_reset          = (!PLLLKDET) || snc_reset;
   assign RXELECIDLERESET0   = (RXELECIDLE0 && RESETDONE0);
   assign RXENELECIDLERESETB = !RXELECIDLERESET0; 
   
   // GTP clock buffers

   IBUFDS ibufdsa 
     (
      .I  (TILE0_REFCLK_PAD_P_IN), 
      .IB (TILE0_REFCLK_PAD_N_IN), 
      .O  (gtp_refclk)
      );

   BUFG refclkout_bufg 
     (
      .I (REFCLKOUT), 
      .O (dcm_refclkin)
      );

   BUFG dcm_clk0_bufg 
     (
      .I (dcm_clk0), 
      .O (clk0)
      );
   
   BUFG dcm_clkdv_bufg 
     (
      .I (dcm_clkdv), 
      .O (clkdv)
      );   
   
   BUFG dcm_clk2x_bufg 
     (
      .I (dcm_clk2x), 
      .O (clk2x)
      );

   BUFG sata_sys_clock_bufg 
     (
      .I (logic_clk), 
      .O (sata_sys_clock)
      );

   BUFGMUX logic_clk_bufgmux 
     (
      .O  (logic_clk), 
      .I0 (clkdv), 
      .I1 (clk0), 
      .S  (snc_gen_value==2'b10) // GEN1 = 0, GEN2 = 1
      );

   BUFGMUX usrclk_bufgmux 
     (
      .O  (usrclk), 
      .I0 (clk0), 
      .I1 (clk2x), 
      .S  (snc_gen_value==2'b10) // GEN1 = 0, GEN2 = 1
      );
   
   // DCM for GTP clocks   
   DCM_BASE 
     #(
       .CLKDV_DIVIDE          (2.0),
       .CLKIN_PERIOD          (6.666),
       .DLL_FREQUENCY_MODE    ("HIGH"),
       .DUTY_CYCLE_CORRECTION ("TRUE"),
       .FACTORY_JF            (16'hF0F0)
       ) 
   GEN2_DCM
     (
      .CLK0     (dcm_clk0),     // 0 degree DCM CLK ouptput
      .CLK180   (),             // 180 degree DCM CLK output
      .CLK270   (),             // 270 degree DCM CLK output
      .CLK2X    (dcm_clk2x),    // 2X DCM CLK output
      .CLK2X180 (),             // 2X, 180 degree DCM CLK out
      .CLK90    (),             // 90 degree DCM CLK output
      .CLKDV    (dcm_clkdv),    // Divided DCM CLK out (CLKDV_DIVIDE)
      .CLKFX    (),             // DCM CLK synthesis out (M/D)
      .CLKFX180 (),             // 180 degree CLK synthesis out
      .LOCKED   (dcm_locked),   // DCM LOCK status output
      .CLKFB    (clk0),         // DCM clock feedback   
      .CLKIN    (dcm_refclkin), // Clock input (from IBUFG, BUFG or DCM)
      .RST      (dcm_reset)     // DCM asynchronous reset input
      ); 
   
   Link Link0
     (
      .clk                         (logic_clk),
      .reset                       (gtp_reset),
      .gen_value                   (snc_gen_value==2'b10),
      
      .rx_locked                   (PLLLKDET),
      .rx_status                   (RXSTATUS0),
      .rx_elecidle                 (RXELECIDLE0),
      .rx_charisk                  (RXCHARISK0),
      .rx_datain                   (RXDATA),
      .rx_byteisaligned            (RXBYTEISALIGNED0),
      .rx_reset                    (RXRESET),
      
      .tx_comstart                 (TXCOMSTART0),
      .tx_comtype                  (TXCOMTYPE0),
      .tx_elecidle                 (TXELECIDLE),
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

   SpeedNegotiation SpeedNegotiation0
     (
      .clk                   (dcm_refclkin),
      .reset                 (soft_reset),
      
      //--- input ports ----------------------------------------------------
      
      .from_link_initialized (from_link_initialized), // SATA link established
      .do                    (snc_do),                // DRP data out
      .drdy                  (snc_drdy),              // DRP ready
      .gtp_lock              (PLLLKDET),              // GTP locked
      
      //--- output ports ---------------------------------------------------  
      //   
      .mgt_reset             (snc_reset),             // GTP reset request     
      .daddr                 (snc_daddr),             // DRP address                     
      .den                   (snc_den),               // DRP enable
      .di                    (snc_di),                // DRP data in
      .dwe                   (snc_dwe),               // DRP write enable
      .gen_value             (snc_gen_value)          // Indicates negotiated SATA version : 1 = SATA 1, 2 = SATA II, (3 = SATA III -> not yet supported)
      
      );

   assign link_gen = snc_gen_value;

   //instantiate on GTP tile(two transceivers)
   GTP_DUAL 
     #(
       //_______________________ Simulation-Only Attributes __________________
      
       .SIM_GTPRESET_SPEEDUP (SIM_GTPRESET_SPEEDUP),
       .SIM_PLL_PERDIV2      (SIM_PLL_PERDIV2),

       //___________________________ Shared Attributes _______________________

       //---------------------- Tile and PLL Attributes ----------------------

       .CLK25_DIVIDER         (6), 
       .CLKINDC_B             ("TRUE"),   
       .OOB_CLK_DIVIDER       (6),
       .OVERSAMPLE_MODE       ("FALSE"),
       .PLL_DIVSEL_FB         (2),
       .PLL_DIVSEL_REF        (1),
       .PLL_TXDIVSEL_COMM_OUT (1), // GEN1 = 2, GEN2 = 1
       .TX_SYNC_FILTERB       (1),
       
       //______________________ Transmit Interface Attributes ________________

       //----------------- TX Buffering and Phase Alignment ------------------   

       .TX_BUFFER_USE_0            ("TRUE"),
       .TX_XCLK_SEL_0              ("TXOUT"),
       .TXRX_INVERT_0              (5'b00000),
       .TX_BUFFER_USE_1            ("TRUE"),
       .TX_XCLK_SEL_1              ("TXOUT"),
       .TXRX_INVERT_1              (5'b00000),   

       //------------------- TX Serial Line Rate settings --------------------   

       //.PLL_TXDIVSEL_OUT_0         (1), // GEN1 = 2, GEN2 = 1
       //.PLL_TXDIVSEL_OUT_1         (1), // GEN1 = 2, GEN2 = 1

       .PLL_TXDIVSEL_OUT_0         (2), // 1=3Gbit/s 
       .PLL_TXDIVSEL_OUT_1         (2), // 1=3Gbit/s

       //------------------- TX Driver and OOB signalling --------------------  

       .TX_DIFF_BOOST_0           ("TRUE"),
       .TX_DIFF_BOOST_1           ("TRUE"),

       //---------------- TX Pipe Control for PCI Express/SATA ---------------

       .COM_BURST_VAL_0            (4'b0101),
       .COM_BURST_VAL_1            (4'b0101),

       //_______________________ Receive Interface Attributes ________________

       //---------- RX Driver,OOB signalling,Coupling and Eq.,CDR ------------  

       .AC_CAP_DIS_0               ("FALSE"),
       .OOBDETECT_THRESHOLD_0      (3'b111), 
       .PMA_CDR_SCAN_0             (27'h6c08040), 
       .PMA_RX_CFG_0               (25'h0dce111),
       .RCV_TERM_GND_0             ("FALSE"),
       .RCV_TERM_MID_0             ("TRUE"),
       .RCV_TERM_VTTRX_0           ("TRUE"),
       .TERMINATION_IMP_0          (50),

       .AC_CAP_DIS_1               ("FALSE"),
       .OOBDETECT_THRESHOLD_1      (3'b111), 
       .PMA_CDR_SCAN_1             (27'h6c08040), 
       .PMA_RX_CFG_1               (25'h0dce111),  
       .RCV_TERM_GND_1             ("FALSE"),
       .RCV_TERM_MID_1             ("TRUE"),
       .RCV_TERM_VTTRX_1           ("TRUE"),
       .TERMINATION_IMP_1          (50),

       .TERMINATION_CTRL           (5'b10100),
       .TERMINATION_OVRD           ("FALSE"),

       //------------------- RX Serial Line Rate Settings --------------------   

       //.PLL_RXDIVSEL_OUT_0         (1),  // GEN1 = 2, GEN2 = 1
       //.PLL_RXDIVSEL_OUT_1         (1),  // GEN1 = 2, GEN2 = 1

       .PLL_RXDIVSEL_OUT_0         (2),  // 1 = 3 Gbit/s 
       .PLL_RXDIVSEL_OUT_1         (2),  // 1 = 3 Gbit/s
       
       .PLL_SATA_0                 ("FALSE"),
       .PLL_SATA_1                 ("FALSE"),


       //------------------------- PRBS Detection ----------------------------  

       .PRBS_ERR_THRESHOLD_0       (32'h00000008),
       .PRBS_ERR_THRESHOLD_1       (32'h00000008),

       //------------------- Comma Detection and Alignment -------------------  

       .ALIGN_COMMA_WORD_0         (2),
       .COMMA_10B_ENABLE_0         (10'b1111111111),
       .COMMA_DOUBLE_0             ("FALSE"),
       .DEC_MCOMMA_DETECT_0        ("TRUE"),
       .DEC_PCOMMA_DETECT_0        ("TRUE"),
       .DEC_VALID_COMMA_ONLY_0     ("FALSE"),
       .MCOMMA_10B_VALUE_0         (10'b1010000011),
       .MCOMMA_DETECT_0            ("TRUE"),
       .PCOMMA_10B_VALUE_0         (10'b0101111100),
       .PCOMMA_DETECT_0            ("TRUE"),
       .RX_SLIDE_MODE_0            ("PCS"),

       .ALIGN_COMMA_WORD_1         (2),
       .COMMA_10B_ENABLE_1         (10'b1111111111),
       .COMMA_DOUBLE_1             ("FALSE"),
       .DEC_MCOMMA_DETECT_1        ("TRUE"),
       .DEC_PCOMMA_DETECT_1        ("TRUE"),
       .DEC_VALID_COMMA_ONLY_1     ("FALSE"),
       .MCOMMA_10B_VALUE_1         (10'b1010000011),
       .MCOMMA_DETECT_1            ("TRUE"),
       .PCOMMA_10B_VALUE_1         (10'b0101111100),
       .PCOMMA_DETECT_1            ("TRUE"),
       .RX_SLIDE_MODE_1            ("PCS"),


       //------------------- RX Loss-of-sync State Machine -------------------  

       .RX_LOSS_OF_SYNC_FSM_0      ("FALSE"),
       .RX_LOS_INVALID_INCR_0      (8),
       .RX_LOS_THRESHOLD_0         (128),

       .RX_LOSS_OF_SYNC_FSM_1      ("FALSE"),
       .RX_LOS_INVALID_INCR_1      (8),
       .RX_LOS_THRESHOLD_1         (128),

       //------------ RX Elastic Buffer and Phase alignment ports ------------   

       .RX_BUFFER_USE_0            ("TRUE"),
       .RX_XCLK_SEL_0              ("RXREC"),

       .RX_BUFFER_USE_1            ("TRUE"),
       .RX_XCLK_SEL_1              ("RXREC"),

       //--------------------- Clock Correction Attributes -------------------   

       .CLK_CORRECT_USE_0          ("TRUE"),
       .CLK_COR_ADJ_LEN_0          (4),
       .CLK_COR_DET_LEN_0          (4),
       .CLK_COR_INSERT_IDLE_FLAG_0 ("FALSE"),
       .CLK_COR_KEEP_IDLE_0        ("FALSE"),
       .CLK_COR_MAX_LAT_0          (18),
       .CLK_COR_MIN_LAT_0          (16),
       .CLK_COR_PRECEDENCE_0       ("TRUE"),
       .CLK_COR_REPEAT_WAIT_0      (0),
       .CLK_COR_SEQ_1_1_0          (10'b0110111100),
       .CLK_COR_SEQ_1_2_0          (10'b0001001010),
       .CLK_COR_SEQ_1_3_0          (10'b0001001010),
       .CLK_COR_SEQ_1_4_0          (10'b0001111011),
       .CLK_COR_SEQ_1_ENABLE_0     (4'b1111),
       .CLK_COR_SEQ_2_1_0          (10'b0000000000),
       .CLK_COR_SEQ_2_2_0          (10'b0000000000),
       .CLK_COR_SEQ_2_3_0          (10'b0000000000),
       .CLK_COR_SEQ_2_4_0          (10'b0000000000),
       .CLK_COR_SEQ_2_ENABLE_0     (4'b0000),
       .CLK_COR_SEQ_2_USE_0        ("FALSE"),
       .RX_DECODE_SEQ_MATCH_0      ("TRUE"),

       .CLK_CORRECT_USE_1          ("TRUE"),
       .CLK_COR_ADJ_LEN_1          (4),
       .CLK_COR_DET_LEN_1          (4),
       .CLK_COR_INSERT_IDLE_FLAG_1 ("FALSE"),
       .CLK_COR_KEEP_IDLE_1        ("FALSE"),
       .CLK_COR_MAX_LAT_1          (18),
       .CLK_COR_MIN_LAT_1          (16),
       .CLK_COR_PRECEDENCE_1       ("TRUE"),
       .CLK_COR_REPEAT_WAIT_1      (0),
       .CLK_COR_SEQ_1_1_1          (10'b0110111100),
       .CLK_COR_SEQ_1_2_1          (10'b0001001010),
       .CLK_COR_SEQ_1_3_1          (10'b0001001010),
       .CLK_COR_SEQ_1_4_1          (10'b0001111011),
       .CLK_COR_SEQ_1_ENABLE_1     (4'b1111),
       .CLK_COR_SEQ_2_1_1          (10'b0000000000),
       .CLK_COR_SEQ_2_2_1          (10'b0000000000),
       .CLK_COR_SEQ_2_3_1          (10'b0000000000),
       .CLK_COR_SEQ_2_4_1          (10'b0000000000),
       .CLK_COR_SEQ_2_ENABLE_1     (4'b0000),
       .CLK_COR_SEQ_2_USE_1        ("FALSE"),
       .RX_DECODE_SEQ_MATCH_1      ("TRUE"),

       //-------------------- Channel Bonding Attributes ---------------------   

       .CHAN_BOND_1_MAX_SKEW_0     (7),
       .CHAN_BOND_2_MAX_SKEW_0     (7),
       .CHAN_BOND_LEVEL_0          (CHAN_BOND_LEVEL_0),
       .CHAN_BOND_MODE_0           (CHAN_BOND_MODE_0),
       .CHAN_BOND_SEQ_1_1_0        (10'b0000000000),
       .CHAN_BOND_SEQ_1_2_0        (10'b0000000000),
       .CHAN_BOND_SEQ_1_3_0        (10'b0000000000),
       .CHAN_BOND_SEQ_1_4_0        (10'b0000000000),
       .CHAN_BOND_SEQ_1_ENABLE_0   (4'b0000),
       .CHAN_BOND_SEQ_2_1_0        (10'b0000000000),
       .CHAN_BOND_SEQ_2_2_0        (10'b0000000000),
       .CHAN_BOND_SEQ_2_3_0        (10'b0000000000),
       .CHAN_BOND_SEQ_2_4_0        (10'b0000000000),
       .CHAN_BOND_SEQ_2_ENABLE_0   (4'b0000),
       .CHAN_BOND_SEQ_2_USE_0      ("FALSE"),  
       .CHAN_BOND_SEQ_LEN_0        (1),
       .PCI_EXPRESS_MODE_0         ("FALSE"),     

       .CHAN_BOND_1_MAX_SKEW_1     (7),
       .CHAN_BOND_2_MAX_SKEW_1     (7),
       .CHAN_BOND_LEVEL_1          (CHAN_BOND_LEVEL_1),
       .CHAN_BOND_MODE_1           (CHAN_BOND_MODE_1),
       .CHAN_BOND_SEQ_1_1_1        (10'b0000000000),
       .CHAN_BOND_SEQ_1_2_1        (10'b0000000000),
       .CHAN_BOND_SEQ_1_3_1        (10'b0000000000),
       .CHAN_BOND_SEQ_1_4_1        (10'b0000000000),
       .CHAN_BOND_SEQ_1_ENABLE_1   (4'b0000),
       .CHAN_BOND_SEQ_2_1_1        (10'b0000000000),
       .CHAN_BOND_SEQ_2_2_1        (10'b0000000000),
       .CHAN_BOND_SEQ_2_3_1        (10'b0000000000),
       .CHAN_BOND_SEQ_2_4_1        (10'b0000000000),
       .CHAN_BOND_SEQ_2_ENABLE_1   (4'b0000),
       .CHAN_BOND_SEQ_2_USE_1      ("FALSE"),  
       .CHAN_BOND_SEQ_LEN_1        (1),
       .PCI_EXPRESS_MODE_1         ("FALSE"),

       //---------------- RX Attributes for PCI Express/SATA ---------------

       .RX_STATUS_FMT_0            ("SATA"),
       .SATA_BURST_VAL_0           (3'b100),
       .SATA_IDLE_VAL_0            (3'b100),
       .SATA_MAX_BURST_0           (7),
       .SATA_MAX_INIT_0            (22),
       .SATA_MAX_WAKE_0            (7),
       .SATA_MIN_BURST_0           (4),
       .SATA_MIN_INIT_0            (12),
       .SATA_MIN_WAKE_0            (4),
       .TRANS_TIME_FROM_P2_0       (16'h0060),
       .TRANS_TIME_NON_P2_0        (16'h0025),
       .TRANS_TIME_TO_P2_0         (16'h0100),

       .RX_STATUS_FMT_1            ("SATA"),
       .SATA_BURST_VAL_1           (3'b100),
       .SATA_IDLE_VAL_1            (3'b100),
       .SATA_MAX_BURST_1           (7),
       .SATA_MAX_INIT_1            (22),
       .SATA_MAX_WAKE_1            (7),
       .SATA_MIN_BURST_1           (4),
       .SATA_MIN_INIT_1            (12),
       .SATA_MIN_WAKE_1            (4),
       .TRANS_TIME_FROM_P2_1       (16'h0060),
       .TRANS_TIME_NON_P2_1        (16'h0025),
       .TRANS_TIME_TO_P2_1         (16'h0100)         
       ) 
   GTP_DUAL_0 
     (

      //---------------------- Loopback and Powerdown Ports ----------------------
      .LOOPBACK0                      (3'b000),
      .LOOPBACK1                      (3'b000),
      .RXPOWERDOWN0                   (2'b00),
      .RXPOWERDOWN1                   (2'b00),
      .TXPOWERDOWN0                   (2'b00),
      .TXPOWERDOWN1                   (2'b00),
      //--------------------- Receive Ports - 8b10b Decoder ----------------------
      .RXCHARISCOMMA0                 (),
      .RXCHARISCOMMA1                 (),
      .RXCHARISK0                     (RXCHARISK0),
      .RXCHARISK1                     (),
      .RXDEC8B10BUSE0                 (1'b1),
      .RXDEC8B10BUSE1                 (1'b1),
      .RXDISPERR0                     (),
      .RXDISPERR1                     (),
      .RXNOTINTABLE0                  (),
      .RXNOTINTABLE1                  (),
      .RXRUNDISP0                     (),
      .RXRUNDISP1                     (),
      //----------------- Receive Ports - Channel Bonding Ports ------------------
      .RXCHANBONDSEQ0                 (),
      .RXCHANBONDSEQ1                 (),
      .RXCHBONDI0                     (3'b000),
      .RXCHBONDI1                     (3'b000),
      .RXCHBONDO0                     (),
      .RXCHBONDO1                     (),
      .RXENCHANSYNC0                  (1'b1),
      .RXENCHANSYNC1                  (1'b1),
      //----------------- Receive Ports - Clock Correction Ports -----------------
      .RXCLKCORCNT0                   (),
      .RXCLKCORCNT1                   (),
      //------------- Receive Ports - Comma Detection and Alignment --------------
      .RXBYTEISALIGNED0               (RXBYTEISALIGNED0),
      .RXBYTEISALIGNED1               (),
      .RXBYTEREALIGN0                 (),
      .RXBYTEREALIGN1                 (),
      .RXCOMMADET0                    (),
      .RXCOMMADET1                    (),
      .RXCOMMADETUSE0                 (1'b1),
      .RXCOMMADETUSE1                 (1'b1),
      .RXENMCOMMAALIGN0               (1'b1),
      .RXENMCOMMAALIGN1               (1'b1),
      .RXENPCOMMAALIGN0               (1'b1),
      .RXENPCOMMAALIGN1               (1'b1),
      .RXSLIDE0                       (1'b0),
      .RXSLIDE1                       (1'b0),
      //--------------------- Receive Ports - PRBS Detection ---------------------
      .PRBSCNTRESET0                  (1'b0),
      .PRBSCNTRESET1                  (1'b0),
      .RXENPRBSTST0                   (2'b00),
      .RXENPRBSTST1                   (2'b00),
      .RXPRBSERR0                     (),
      .RXPRBSERR1                     (),
      //----------------- Receive Ports - RX Data Path interface -----------------
      .RXDATA0                        (RXDATA),
      .RXDATA1                        (),
      .RXDATAWIDTH0                   (1'b1),
      .RXDATAWIDTH1                   (1'b1),
      .RXRECCLK0                      (),
      .RXRECCLK1                      (),
      .RXRESET0                       (RXRESET),
      .RXRESET1                       (RXRESET),
      .RXUSRCLK0                      (RXUSRCLK1),
      .RXUSRCLK1                      (RXUSRCLK1),
      .RXUSRCLK20                     (RXUSRCLK2),
      .RXUSRCLK21                     (RXUSRCLK2),
      //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
      .RXCDRRESET0                    (gtp_reset),
      .RXCDRRESET1                    (gtp_reset),
      .RXELECIDLE0                    (RXELECIDLE0),
      .RXELECIDLE1                    (),
      .RXELECIDLERESET0               (RXELECIDLERESET0),
      //.RXELECIDLERESET1               (rxelecidlereset1),
      .RXELECIDLERESET1               (),
      .RXENEQB0                       (1'b1),
      .RXENEQB1                       (1'b1),
      .RXEQMIX0                       (2'b00),
      .RXEQMIX1                       (2'b00),
      .RXEQPOLE0                      (4'b0000),
      .RXEQPOLE1                      (4'b0000),
      .RXN0                           (RXN0_IN),
      .RXN1                           (),
      .RXP0                           (RXP0_IN),
      .RXP1                           (),
      //------ Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
      .RXBUFRESET0                    (gtp_reset),
      .RXBUFRESET1                    (gtp_reset),
      .RXBUFSTATUS0                   (),
      .RXBUFSTATUS1                   (),
      .RXCHANISALIGNED0               (),
      .RXCHANISALIGNED1               (),
      .RXCHANREALIGN0                 (),
      .RXCHANREALIGN1                 (),
      .RXPMASETPHASE0                 (1'b0),
      .RXPMASETPHASE1                 (1'b0),
      .RXSTATUS0                      (RXSTATUS0),
      .RXSTATUS1                      (),
      //------------- Receive Ports - RX Loss-of-sync State Machine --------------
      .RXLOSSOFSYNC0                  (),
      .RXLOSSOFSYNC1                  (),
      //-------------------- Receive Ports - RX Oversampling ---------------------
      .RXENSAMPLEALIGN0               (1'b0),
      .RXENSAMPLEALIGN1               (1'b0),
      .RXOVERSAMPLEERR0               (),
      .RXOVERSAMPLEERR1               (),
      //------------ Receive Ports - RX Pipe Control for PCI Express -------------
      .PHYSTATUS0                     (),
      .PHYSTATUS1                     (),
      .RXVALID0                       (),
      .RXVALID1                       (),
      //--------------- Receive Ports - RX Polarity Control Ports ----------------
      .RXPOLARITY0                    (1'b0),
      .RXPOLARITY1                    (1'b0),
      //----------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
      .DADDR                          (snc_daddr),
      .DCLK                           (dcm_refclkin),
      .DEN                            (snc_den),
      .DI                             (snc_di),
      .DO                             (snc_do),
      .DRDY                           (snc_drdy),
      .DWE                            (snc_dwe),
      //------------------- Shared Ports - Tile and PLL Ports --------------------
      .CLKIN                          (gtp_refclk),
      .GTPRESET                       (gtp_reset),
      .GTPTEST                        (4'b0000),
      .INTDATAWIDTH                   (1'b1),
      .PLLLKDET                       (PLLLKDET),
      .PLLLKDETEN                     (1'b1),
      .PLLPOWERDOWN                   (1'b0),
      .REFCLKOUT                      (REFCLKOUT),
      .REFCLKPWRDNB                   (1'b1),
      .RESETDONE0                     (RESETDONE0),
      .RESETDONE1                     (),
      .RXENELECIDLERESETB             (RXENELECIDLERESETB),
      .TXENPMAPHASEALIGN              (1'b0),
      .TXPMASETPHASE                  (1'b0),
      //-------------- Transmit Ports - 8b10b Encoder Control Ports --------------
      .TXBYPASS8B10B0                 ({1'b0,1'b0}),
      .TXBYPASS8B10B1                 ({1'b0,1'b0}),
      .TXCHARDISPMODE0                ({1'b0,1'b0}),
      .TXCHARDISPMODE1                ({1'b0,1'b0}),
      .TXCHARDISPVAL0                 ({1'b0,1'b0}),
      .TXCHARDISPVAL1                 ({1'b0,1'b0}),
      .TXCHARISK0                     ({1'b0,TXCHARISK}),
      .TXCHARISK1                     ({1'b0,TXCHARISK}),
      .TXENC8B10BUSE0                 (1'b1),
      .TXENC8B10BUSE1                 (1'b1),
      .TXKERR0                        (),
      .TXKERR1                        (),
      .TXRUNDISP0                     (),
      .TXRUNDISP1                     (),
      //----------- Transmit Ports - TX Buffering and Phase Alignment ------------
      .TXBUFSTATUS0                   (),
      .TXBUFSTATUS1                   (),
      //---------------- Transmit Ports - TX Data Path interface -----------------
      .TXDATA0                        (TXDATA),
      .TXDATA1                        (TXDATA),
      .TXDATAWIDTH0                   (1'b1),
      .TXDATAWIDTH1                   (1'b1),
      .TXOUTCLK0                      (),
      .TXOUTCLK1                      (),
      .TXRESET0                       (gtp_reset),
      .TXRESET1                       (gtp_reset),
      .TXUSRCLK0                      (TXUSRCLK1),
      .TXUSRCLK1                      (TXUSRCLK1),
      .TXUSRCLK20                     (TXUSRCLK2),
      .TXUSRCLK21                     (TXUSRCLK2),
      //------------- Transmit Ports - TX Driver and OOB signalling --------------
      .TXBUFDIFFCTRL0                 (3'b001),
      .TXBUFDIFFCTRL1                 (3'b001),
      .TXDIFFCTRL0                    (3'b100),
      .TXDIFFCTRL1                    (3'b100),
      .TXINHIBIT0                     (1'b0),
      .TXINHIBIT1                     (1'b0),
      .TXN0                           (TXN0_OUT),
      .TXN1                           (),
      .TXP0                           (TXP0_OUT),
      .TXP1                           (),
      .TXPREEMPHASIS0                 (3'b011),
      .TXPREEMPHASIS1                 (3'b011),
      //------------------- Transmit Ports - TX PRBS Generator -------------------
      .TXENPRBSTST0                   (1'b0),
      .TXENPRBSTST1                   (1'b0),
      //------------------ Transmit Ports - TX Polarity Control ------------------
      .TXPOLARITY0                    (1'b0),
      .TXPOLARITY1                    (1'b0),
      //--------------- Transmit Ports - TX Ports for PCI Express ----------------
      .TXDETECTRX0                    (1'b0),
      .TXDETECTRX1                    (1'b0),
      .TXELECIDLE0                    (TXELECIDLE),
      .TXELECIDLE1                    (TXELECIDLE),
      //------------------- Transmit Ports - TX Ports for SATA -------------------
      .TXCOMSTART0                    (TXCOMSTART0),
      .TXCOMSTART1                    (1'b0),
      .TXCOMTYPE0                     (TXCOMTYPE0), //this is 0 for cominit/comreset/  and 1 for comwake
      .TXCOMTYPE1                     (1'b0)
      );

endmodule