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
 * Module        : Link
 * Created       : April 08 2011
 * Last Update   : March 15 2012
 * Last Update   : July 29 2013
 * ---------------------------------------------------------------------------
 * Description   : Low-level SATA interface
 *                 - Link initialization on reset (OOB)
 *                 - Send FIS
 *                 - Receive FIS
 *                 - Scrambling/descrambling
 *                 - CRC32 generation/checking
 *                 - ALIGN insertion
 * ---------------------------------------------------------------------------
 * Changelog     : (1) Removed LINK_READY, LINK_READY_R_OK.
 *                 After initialization the device sends the device signature.
 *                 Knowing this the old version of Groundhog started sending
 *                 PRIM_R_RDY immediately after initialization, which
 *                 occasionally caused probems with some SSDs. We now go into
 *                 state IDLE and wait for the device to send PRIM_X_RDY. 
 *                 Groundhog is running much more stable now, so we could
 *                 remove the abort logic in the old version.
 * 
 *                 (2) Fixed bug in the receiving hold logic, i.e., HOLD that
 *                 is invoked by the FPGA (see states RECEIVEFIS_HOLDi). In the
 *                 old version of Groundhog we resumed normal operation as soon
 *                 as the receive buffer became empty. However, this transition 
 *                 can only be taken when no primitives are sent, i.e., the 
 *                 device may be sending (1) HOLDA, (2) HOLDA, (3) CONT. If we 
 *                 take this transition at (1), RECEIVEFIS_HOLD5 would sometimes
 *                 confuse the second HOLDA with the HOLDA that determines the 
 *                 end of scrambled data.
 * ------------------------------------------------------------------------- */

`timescale 1 ns / 1 ps

module Link 
  (
   input         clk,
   input         reset,
   input         gen_value, // SATA Gen I (gen_value = 0) or Gen II (gen_value = 1) 

   // GTH Tile -> RX signals
   input         rx_locked, // GTP PLL is locked
   //input [2:0]   rx_status, // RX OOB type 
   input         rx_cominit_det,
   input         rx_comwake_det,
   input         rx_elecidle, // RX electrical idle
   input [1:0]   rx_charisk, // RX control value : rx_charisk[0] = 1 -> rx_datain[7:0] is K (control value) (e.g., 8'hBC = K28.5), rx_charisk[1] = 1 -> rx_datain[15:8] is K 
   input [15:0]  rx_datain, // RX data
   input         rx_byteisaligned, // RX byte alignment completed
   output reg    rx_reset, // GTP PCS reset

   // GTH Tile -> TX signals
   //output        tx_comstart, // TX OOB enable
   //output        tx_comtype, // TX OOB type select
   output        tx_cominit,
   //output tx_comfinish,
   output        tx_comwake,
   output        tx_elecidle, // TX electircal idel
   output [15:0] tx_data, // TX data outgoing 
   output        tx_charisk, // TX byted is K character

   input         to_link_FIS_rdy,
   input [15:0]  to_link_data,
   input         to_link_done,
   input         to_link_receive_empty,
   input         to_link_receive_overflow,
   input         to_link_send_empty,
   input         to_link_send_underrun,

   output reg    from_link_comreset,
   output reg    from_link_initialized,
   output reg    from_link_idle,
   output reg    from_link_ready_to_transmit,
   output        from_link_next,
   output [15:0] from_link_data,
   output        from_link_data_en,
   output reg    from_link_done,
   output reg    from_link_err
   );

   // --- states link layer FSM ----------------------------------
   
   localparam [5:0]
      
     // reset states
     HOST_COMRESET          = 0,
     WAIT_DEV_COMINIT       = 1,
     HOST_COMWAKE           = 2, 
     WAIT_DEV_COMWAKE       = 3,
     WAIT_AFTER_COMWAKE     = 4,
     WAIT_AFTER_COMWAKE1    = 5,
     HOST_D10_2             = 6,
     HOST_SEND_ALIGN        = 7,
     WAIT_LINK_READY        = 8,
     
     // after reset wait in this state
     IDLE                   = 9,
     
     // send FIS states
     SENDFIS_X_RDY          = 10,
     SENDFIS_WAIT_BUFFER    = 11,   
     SENDFIS_SOF            = 12,
     SENDFIS_PAYLOAD        = 13,
     SENDFIS_CRC            = 14,
     SENDFIS_EOF            = 15,
     SENDFIS_WTRM           = 16,
     SENDFIS_SYNC           = 17,
     SENDFIS_SYNC_ERR       = 18,
     SENDFIS_PAYLOAD_AHOLD1 = 19,
     SENDFIS_PAYLOAD_AHOLD2 = 20,
     SENDFIS_PAYLOAD_AHOLD3 = 21,
     SENDFIS_PAYLOAD_HOLD   = 22,
     
     // receive FIS states
     RECEIVEFIS_R_RDY       = 23,
     RECEIVEFIS_R_IP        = 24,
     RECEIVEFIS_HOLDA       = 25,
     RECEIVEFIS_WAIT_HOLD   = 26,
     RECEIVEFIS_HOLD1       = 27,
     RECEIVEFIS_HOLD2       = 28,
     RECEIVEFIS_HOLD3       = 29,
     RECEIVEFIS_HOLD4       = 30,
     RECEIVEFIS_HOLD5       = 31,
     RECEIVEFIS_HOLD6       = 32,
     RECEIVEFIS_HOLD7       = 33,
     RECEIVEFIS_HOLD8       = 34,
     RECEIVEFIS_R_OK        = 35;
   
   
   reg [5:0]     currState;
   
   // --- Encoding of SATA primitives ----------------------------

   localparam [31:0]
     PRIM_DIALTONE = 32'h4A4A4A4A, 
     PRIM_ALIGN    = 32'h7B4A4ABC,
     PRIM_CONT     = 32'h9999AA7C,
     PRIM_DMAT     = 32'h3636B57C,
     PRIM_EOF      = 32'hD5D5B57C,
     PRIM_HOLD     = 32'hD5D5AA7C,
     PRIM_HOLDA    = 32'h9595AA7C,
     PRIM_PMACK    = 32'h9595957C,
     PRIM_PMNAK    = 32'hF5F5957C,
     PRIM_PMREQ_P  = 32'h1717B57C,
     PRIM_PMREQ_S  = 32'h7575957C,
     PRIM_R_ERR    = 32'h5656B57C,
     PRIM_R_IP     = 32'h5555B57C,
     PRIM_R_OK     = 32'h3535B57C,
     PRIM_R_RDY    = 32'h4A4A957C,
     PRIM_SOF      = 32'h3737B57C,
     PRIM_SYNC     = 32'hB5B5957C,
     PRIM_WTRM     = 32'h5858B57C,
     PRIM_X_RDY    = 32'h5757B57C;

   reg [31:0]    currPrimitive;
   reg [15:0]    currPayload_r; 
   wire [15:0]   currPayload;

   // --- Send FSM states ---------------------------------------- 

   localparam [2:0]
     SEND_DIALTONE  = 1,
     SEND_PRIMITIVE = 2,
     SEND_PAYLOAD   = 3,
     SEND_CRC       = 4;
   
   reg [2:0]     sendState;

   // --- SATA primitive detected --------------------------------

   wire          
                 prim_align_det,
                 prim_cont_det,
                 prim_dmat_det,
                 prim_eof_det,
                 prim_hold_det,
                 prim_holda_det,
                 prim_pmack_det,
                 prim_pmnak_det,
                 prim_pmreq_p_det,
                 prim_pmreq_s_det,
                 prim_r_err_det,
                 prim_r_ip_det,
                 prim_r_ok_det,
                 prim_r_rdy_det,
                 prim_sof_det,
                 prim_sync_det,
                 prim_wtrm_det,
                 prim_x_rdy_det;
   
   reg           
                 prim_align_det_r,
                 prim_cont_det_r,
                 prim_dmat_det_r,
                 prim_eof_det_r,
                 prim_hold_det_r,
                 prim_holda_det_r,
                 prim_pmack_det_r,
                 prim_pmnak_det_r,
                 prim_pmreq_p_det_r,
                 prim_pmreq_s_det_r,
                 prim_r_err_det_r,
                 prim_r_ip_det_r,
                 prim_r_ok_det_r,
                 prim_r_rdy_det_r,
                 prim_sof_det_r,
                 prim_sync_det_r,
                 prim_wtrm_det_r,
                 prim_x_rdy_det_r;

   reg           primitive_det, primitive_det_r1, primitive_det_r2;
   reg           hold;

   // FIS transaction completion signals
   reg           FIS_transaction_done;
   reg           FIS_transaction_err;
   
   reg           to_link_FIS_rdy_r1, to_link_FIS_rdy_r2;

   // moved from port to here

   wire [15:0]   scramble_mask;
   reg [15:0]    tx_scramble_mask_r0;
   reg [15:0]    tx_scramble_mask_r1;

   // transmit scrambler
   
   reg           tx_scramble_reset;
   reg           tx_scramble_enable;
   
   // --- CRC registers & wires ----------------------------------
   
   reg           crc32_reset;
   reg           crc32_tx_enable;
   reg           crc32_mode_tx;
   wire [15:0]   crc32_data;
   wire [15:0]   crc32_code;
   wire          crc32_rx_match;
   reg [1:0]     crc32_rx_state;

   reg [17:0]    count;
   reg           count_en;
   reg           send_align_r;
   
   reg           align_cnt;
   reg [8:0]     align_prim_cnt;
   reg           align_insert;
   reg [2:0]     align_countdown;
   reg           align_process;

   // RX register chain
   reg [15:0]    rx_datain_r1;
   reg [15:0]    rx_datain_r2;
   reg [15:0]    rx_datain_r3;
   reg [15:0]    rx_datain_r4;
   reg [15:0]    rx_datain_r5;
   reg [15:0]    rx_datain_r6;

   wire          rx_datain_r2_valid;
   reg           rx_datain_r3_valid;
   reg           rx_datain_r4_valid;
   reg           rx_datain_r5_valid;
   reg           rx_datain_r6_valid;

   reg [15:0]    tx_data_r0, tx_data_r1, tx_data_r2, tx_data_r3;

   //reg                     tx_comstart_r0, tx_comstart_r1, tx_comstart_r2, tx_comstart_r3;
   //reg                     tx_comtype_r0,  tx_comtype_r1,  tx_comtype_r2,  tx_comtype_r3;
   reg           tx_cominit_r0, tx_cominit_r1, tx_cominit_r2, tx_cominit_r3;
   reg           tx_comwake_r0, tx_comwake_r1, tx_comwake_r2, tx_comwake_r3;
   //reg        tx_comfinish_r0, tx_comfinish_r1, tx_comfinish_r2, tx_comfinish_r3;
   reg           tx_elecidle_r0, tx_elecidle_r1, tx_elecidle_r2, tx_elecidle_r3;
   reg           tx_charisk_r0,  tx_charisk_r1,  tx_charisk_r2,  tx_charisk_r3;
   
   reg           align_cnt_en;

   // registers & parameters to compute rx_datain_r2_valid
   localparam
     WAIT_SOF = 0, // wait for Start Of FIS (SOF)
     WAIT_EOF = 1; // wait for End Of FIS   (EOF)
   
   reg           receiveFIScurrState;
   reg           rx_datain_valid;
   reg           process_send_data;
   
   wire          link_din_valid;
   wire          link_din_done;
   reg           link_din_done_firstclock;  
   reg           link_din_crc;                  
   
   assign link_din_valid = from_link_next && (!to_link_send_empty);
   assign link_din_done  = (!link_din_done_firstclock) && (to_link_send_empty && to_link_done);
   
   always@(posedge clk) begin
      if (reset) begin
         link_din_done_firstclock <= 0;
      end
      else begin
         if(to_link_send_empty && to_link_done) begin
            link_din_done_firstclock <= 1;
         end
         else begin
            link_din_done_firstclock <= 0;
         end
      end
   end

   assign from_link_next    = process_send_data && (!align_process);
   assign from_link_data    = rx_datain_r4;
   assign from_link_data_en = rx_datain_r4_valid;
   assign currPayload       = to_link_data;
   
   always@(posedge clk) begin : SEQ
      
      if (reset) begin
         
         currState                   <= HOST_COMRESET;
         process_send_data           <= 0; 
         from_link_initialized       <= 0;
         from_link_idle              <= 0;
         from_link_ready_to_transmit <= 0;
         
         count_en  <= 0;
         
         //tx_comstart_r0 <= 0;
         //tx_comtype_r0  <= 0;
         tx_cominit_r0 <= 1'b0;
         tx_comwake_r0 <= 1'b0;
         //tx_comfinish_r0 <= 1'b0;
         tx_elecidle_r0 <= 1;

         align_cnt_en <= 0;
         send_align_r <= 0;
         rx_reset     <= 0;

         sendState            <= SEND_PRIMITIVE;
         currPrimitive        <= PRIM_ALIGN;
         FIS_transaction_done <= 0;
         FIS_transaction_err  <= 0;
         hold                 <= 0;

         crc32_reset     <= 0;
         crc32_tx_enable <= 0;
         crc32_mode_tx   <= 0;
         crc32_rx_state  <= 2'b0;

         tx_scramble_reset  <= 0;
         tx_scramble_enable <= 0;
         
         link_din_crc <= 0;
         from_link_comreset <= 0;
         
      end
      else begin

         // delayed payload
         currPayload_r <= currPayload;
         
         // defaults: this signals are only high in exactly one state
         from_link_idle              <= 0;
         from_link_ready_to_transmit <= 0;

         // start defaults - do I need this?
         count_en       <= 0;
         //tx_comstart_r0 <= 0;
         //tx_comtype_r0  <= 0;
         tx_cominit_r0 <= 1'b0;
         //tx_comfinish_r0 <= 1'b0;
         tx_comwake_r0 <= 1'b0;

         send_align_r <= 0;
         rx_reset     <= 0;
         
         sendState            <= SEND_PRIMITIVE;
         currPrimitive        <= PRIM_ALIGN;
         FIS_transaction_done <= 0;
         FIS_transaction_err  <= 0;

         from_link_comreset <= 0;
         
         case (currState)
           
           // --- Link initialization -------------------------------------------------

           HOST_COMRESET: begin
              from_link_comreset    <= 1;
              align_cnt_en          <= 0;
              from_link_initialized <= 0;
              tx_elecidle_r0        <= 1;

              if (rx_locked) begin
                 if (((!gen_value) && count == 18'h000A2) || (gen_value && count == 18'h00144)) begin
                    //tx_comstart_r0 <= 0;
                    //tx_comtype_r0  <= 0;
                    tx_cominit_r0 <= 1'b0;
                    //tx_comfinish_r0 <= 1'b0;
                    tx_comwake_r0 <= 1'b0;
                    currState      <= WAIT_DEV_COMINIT;
                 end
                 else begin
                    //                    tx_comstart_r0 <= 1;
                    //                    tx_comtype_r0  <= 0;
                    tx_cominit_r0 <= 1'b1;
                    //tx_comfinish_r0 <= 1'b0;
                    tx_comwake_r0 <= 1'b0;
                    count_en       <= 1;
                    currState      <= HOST_COMRESET;
                 end
              end
              else begin
                 //                 tx_comstart_r0 <= 0;
                 //                 tx_comtype_r0  <= 0;
                 tx_cominit_r0 <= 1'b0;
                 //tx_comfinish_r0 <= 1'b0;
                 tx_comwake_r0 <= 1'b0;
                 currState     <= HOST_COMRESET;
              end
           end
           
           WAIT_DEV_COMINIT: begin
              //device cominit detected
              if (rx_cominit_det) begin
                 currState <= HOST_COMWAKE;
              end
              else begin
                 //restart comreset after no cominit for at least 880us
                 if(count == 18'h203AD) begin
                    count_en  <= 0;
                    currState <= HOST_COMRESET;
                 end
                 else begin
                    count_en  <= 1;
                    currState <= WAIT_DEV_COMINIT;
                 end
              end
           end

           HOST_COMWAKE: begin
              if (((!gen_value) && count == 18'h0009B) || (gen_value && count == 18'h00136)) begin
                 //                 tx_comstart_r0 <= 0;
                 //                 tx_comtype_r0  <= 0;
                 tx_cominit_r0 <= 1'b0;
                 //tx_comfinish_r0 <= 1'b0;
                 tx_comwake_r0 <= 1'b0;
                 currState     <= WAIT_DEV_COMWAKE;
              end
              else begin
                 //                 tx_comstart_r0 <= 1;
                 //                 tx_comtype_r0  <= 1;
                 tx_cominit_r0 <= 1'b0;
                 //tx_comfinish_r0 <= 1'b0;
                 tx_comwake_r0 <= 1'b1;
                 count_en      <= 1;
                 currState     <= HOST_COMWAKE;
              end
           end
           
           WAIT_DEV_COMWAKE: begin
              //device comwake detected
              if (rx_comwake_det) begin
                 currState <= WAIT_AFTER_COMWAKE;
              end
              else begin
                 //restart comreset after no cominit for 880us
                 if(count == 18'h203AD) begin
                    count_en  <= 0;
                    currState <= HOST_COMRESET;
                 end
                 else begin
                    count_en  <= 1;
                    currState <= WAIT_DEV_COMWAKE;
                 end
              end
           end

           WAIT_AFTER_COMWAKE: begin
              if(count == 6'h3F) begin
                 currState <= WAIT_AFTER_COMWAKE1;
              end
              else begin
                 count_en  <= 1;
                 currState <= WAIT_AFTER_COMWAKE;
              end
           end

           WAIT_AFTER_COMWAKE1: begin
              if(!rx_elecidle) begin
                 rx_reset  <= 1;
                 currState <= HOST_D10_2;
              end
              else begin
                 currState <= WAIT_AFTER_COMWAKE1;
              end
           end
           
           HOST_D10_2: begin
              tx_elecidle_r0 <= 0;
              sendState      <= SEND_DIALTONE;
              
              // if not rx byte is alinged -> something went wrong (will eventually reset)
              // wait until we see first ALIGN primitive, if we can detect an ALIGN primitive
              // this means that we actually understand the bit stream comming from the drive.
              
              if(prim_align_det && rx_byteisaligned) begin
                 align_cnt_en <= 1;
                 currState    <= HOST_SEND_ALIGN;
              end
              else begin
                 // restart comreset after 880us
                 if(count == 18'h203AD) begin
                    count_en  <= 0;
                    currState <= HOST_COMRESET;
                 end
                 else begin
                    count_en  <= 1;
                    currState <= HOST_D10_2;
                 end
              end
           end
           
           HOST_SEND_ALIGN: begin
              send_align_r  <= 1;
              currPrimitive <= PRIM_ALIGN;
              if((prim_sync_det || prim_sync_det_r) && align_cnt) begin
                 send_align_r <= 0;
                 currState    <= WAIT_LINK_READY;
              end
              else begin
                 currState <= HOST_SEND_ALIGN;
              end
           end

           WAIT_LINK_READY: begin
              // we have waited for link to get up for too long -> reset
              if(count == 18'h203AD) begin
                 count_en  <= 0;
                 currState <= HOST_COMRESET;
              end
              // link is now ready
              else if ((!rx_elecidle) && align_cnt) begin
                 count_en <= 0;
                 from_link_initialized <= 1;
                 
                 currState     <= IDLE;
                 currPrimitive <= PRIM_SYNC;
                 
              end
              // link is not ready yet -> rx is still idle
              else begin
                 count_en  <= 1;
                 currState <= WAIT_LINK_READY;
              end
           end

           // --- Idle : after init or completed cmd wait here for next cmd -----------

           IDLE: begin
              from_link_idle    <= 1;
              process_send_data <= 0;
              tx_scramble_reset <= 1;
              
              crc32_reset       <= 1;
              crc32_tx_enable   <= 0;
              crc32_mode_tx     <= 0;
              crc32_rx_state    <= 2'b0;
              
              // host wants to send FIS to drive
              if((to_link_FIS_rdy_r1 || to_link_FIS_rdy_r2) && align_cnt) begin
                 crc32_reset       <= 0;
                 currState         <= SENDFIS_X_RDY;
                 currPrimitive     <= PRIM_X_RDY;
                 tx_scramble_reset <= 0;
                 crc32_mode_tx     <= 1;
              end
              
              // drive wants to send FIS to host
              else if((prim_x_rdy_det || prim_x_rdy_det_r) && align_cnt) begin
                 crc32_reset       <= 0;
                 currState         <= RECEIVEFIS_R_RDY;
                 currPrimitive     <= PRIM_R_RDY;
                 tx_scramble_reset <= 0;
              end
              
              else begin
                 currState     <= IDLE;
                 currPrimitive <= PRIM_SYNC;
              end
           end

           // --- Send Frame Information Structure (FIS) ------------------------------

           SENDFIS_X_RDY: begin
              
              // wait until drive is ready to receive
              if((prim_r_rdy_det || prim_r_rdy_det_r) && align_cnt) begin
                 from_link_ready_to_transmit <= 1;
                 currState                   <= SENDFIS_WAIT_BUFFER;
                 currPrimitive               <= PRIM_X_RDY;
              end
              
              // if drive wants to send, we need to relinquish our bid and accept the FIS from the drive
              // this can happen with asynchronous I/O -> native command queuing (NCQ)
              // abort the current transaction with an error and start receiving the new FIS
              else if((prim_x_rdy_det || prim_x_rdy_det_r) && align_cnt) begin
                 FIS_transaction_done <= 1;
                 FIS_transaction_err  <= 1;
                 crc32_mode_tx        <= 0;
                 currState            <= RECEIVEFIS_R_RDY;
                 currPrimitive        <= PRIM_R_RDY;
              end
              
              else begin
                 currState     <= SENDFIS_X_RDY;
                 currPrimitive <= PRIM_X_RDY;
              end
              
           end

           SENDFIS_WAIT_BUFFER: begin
              from_link_ready_to_transmit <= 1;
              currState                   <= SENDFIS_WAIT_BUFFER;
              currPrimitive               <= PRIM_X_RDY;
              if((!to_link_send_underrun) && align_cnt) begin
                 currState     <= SENDFIS_SOF;
                 currPrimitive <= PRIM_SOF;
              end
           end

           SENDFIS_SOF: begin
              crc32_tx_enable    <= 1;
              tx_scramble_enable <= 1;
              process_send_data  <= 1;
              if(align_cnt) begin
                 currState <= SENDFIS_PAYLOAD;
                 sendState <= SEND_PAYLOAD;
              end
              else begin
                 currState     <= SENDFIS_SOF;
                 currPrimitive <= PRIM_SOF;
              end
           end

           SENDFIS_PAYLOAD: begin
              // data for this FIS is sent
              if(to_link_send_empty && to_link_done) begin
                 link_din_crc      <= 1;
                 crc32_tx_enable   <= 0;
                 process_send_data <= 0;              
                 currState         <= SENDFIS_CRC;
                 sendState         <= SEND_CRC;
              end
              // drive requests hold
              // if all data is in buffers (to_link_done), ignore request
              // and finish FIS transmission
              else if((!to_link_done) && (prim_hold_det || prim_hold_det_r) && align_cnt) begin
                 currState <= SENDFIS_PAYLOAD_AHOLD1;
                 sendState <= SEND_PAYLOAD;
              end
              // buffer underrun -> prepare to send hold
              // at end of FIS we will always have a buffer underrun
              // -> we only send hold if !to_link_done
              else if((!to_link_done) && to_link_send_underrun  && (!align_cnt)) begin
                 process_send_data <= 0;
                 currState         <= SENDFIS_PAYLOAD;
                 sendState         <= SEND_PAYLOAD;
              end
              // buffer underrun -> send hold primitives
              else if((!process_send_data) && align_cnt) begin
                 currState      <= SENDFIS_PAYLOAD_HOLD;
                 currPrimitive  <= PRIM_HOLD;
              end
              // default: keep sending payload data
              else begin
                 currState <= SENDFIS_PAYLOAD;
                 sendState <= SEND_PAYLOAD;
              end
           end

           SENDFIS_PAYLOAD_AHOLD1: begin
              // data for this FIS is sent
              if(to_link_send_empty && to_link_done) begin
                 link_din_crc      <= 1;
                 crc32_tx_enable   <= 0;
                 process_send_data <= 0;              
                 currState         <= SENDFIS_CRC;
                 sendState         <= SEND_CRC;
              end
              // acknowledge hold
              else if((!link_din_valid) && align_cnt) begin
                 currState     <= SENDFIS_PAYLOAD_AHOLD2;
                 currPrimitive <= PRIM_HOLDA;
              end
              // keep sending data until buffer is empty
              else begin
                 process_send_data <= 0; 
                 currState         <= SENDFIS_PAYLOAD_AHOLD1;
                 sendState         <= SEND_PAYLOAD;
              end
           end

           SENDFIS_PAYLOAD_AHOLD2: begin
              currPrimitive <= PRIM_HOLDA;
              if((prim_r_ip_det || prim_r_ip_det_r) && align_cnt) begin
                 currState <= SENDFIS_PAYLOAD_AHOLD3;
              end
              else begin
                 currState <= SENDFIS_PAYLOAD_AHOLD2;
              end
           end

           SENDFIS_PAYLOAD_AHOLD3: begin
              currState         <= SENDFIS_PAYLOAD_AHOLD3;
              currPrimitive     <= PRIM_HOLDA;
              process_send_data <= 1;
              if(link_din_valid && align_cnt) begin
                 currState <= SENDFIS_PAYLOAD;
                 sendState <= SEND_PAYLOAD;
              end
           end

           SENDFIS_PAYLOAD_HOLD: begin
              currState     <= SENDFIS_PAYLOAD_HOLD;
              currPrimitive <= PRIM_HOLD;
              if((!to_link_send_underrun) && (!align_cnt)) begin
                 process_send_data <= 1;
                 currState         <= SENDFIS_PAYLOAD;
              end
           end

           SENDFIS_CRC: begin
              link_din_crc <= 0;
              if(align_cnt) begin
                 currState     <= SENDFIS_EOF;
                 currPrimitive <= PRIM_EOF;
              end
              else begin
                 currState <= SENDFIS_CRC;
                 sendState <= SEND_CRC;
              end
           end

           SENDFIS_EOF: begin
              tx_scramble_enable <= 0;
              if(align_cnt) begin
                 currState     <= SENDFIS_WTRM;
                 currPrimitive <= PRIM_WTRM;
              end
              else begin
                 currState     <= SENDFIS_EOF;
                 currPrimitive <= PRIM_EOF;
              end
           end

           SENDFIS_WTRM: begin
              if((prim_r_ok_det || prim_r_ok_det_r) && align_cnt) begin
                 currState     <= SENDFIS_SYNC;
                 currPrimitive <= PRIM_SYNC;
              end
              else if(((prim_r_err_det || prim_r_err_det_r) || ((prim_sync_det || prim_sync_det_r))) && align_cnt) begin
                 currState     <= SENDFIS_SYNC_ERR;
                 currPrimitive <= PRIM_SYNC;
              end
              else begin
                 currState     <= SENDFIS_WTRM;
                 currPrimitive <= PRIM_WTRM;
              end
           end

           SENDFIS_SYNC: begin
              if((prim_sync_det || prim_sync_det_r) && align_cnt) begin
                 currState            <= IDLE;
                 currPrimitive        <= PRIM_SYNC;
                 FIS_transaction_done <= 1;
              end
              else begin
                 currState     <= SENDFIS_SYNC;
                 currPrimitive <= PRIM_SYNC;
              end
           end

           SENDFIS_SYNC_ERR: begin
              if((prim_sync_det || prim_sync_det_r) && align_cnt) begin
                 currState            <= IDLE;
                 currPrimitive        <= PRIM_SYNC;
                 FIS_transaction_done <= 1;
                 FIS_transaction_err  <= 1;
              end
              else begin
                 currState     <= SENDFIS_SYNC_ERR;
                 currPrimitive <= PRIM_SYNC;
              end
           end

           // --- Receive Frame Information Structure (FIS) ----------------------------

           RECEIVEFIS_R_RDY: begin
              // If trying to send FIS while we are receiving
              // -> abort receive request
              if(to_link_FIS_rdy || to_link_FIS_rdy_r1 || to_link_FIS_rdy_r2) begin
                 FIS_transaction_done <= 1;
                 FIS_transaction_err  <= 1;
                 crc32_mode_tx        <= 0;
              end
              
              if((prim_sof_det || prim_sof_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              else begin
                 currState     <= RECEIVEFIS_R_RDY;
                 currPrimitive <= PRIM_R_RDY;
              end
           end

           RECEIVEFIS_R_IP: begin
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end

              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device requests hold -> acknowledge (HOLDA)
              else if((prim_hold_det || prim_hold_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLDA;
                 currPrimitive <= PRIM_HOLDA;
              end
              // imminent read buffer overflow -> request hold
              else if(to_link_receive_overflow && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLD1;
                 currPrimitive <= PRIM_HOLD;
              end
              // receiving data in progress
              else begin
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
           end           

           RECEIVEFIS_HOLDA: begin
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end
              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device requests hold -> acknowledge (HOLDA)
              else if(prim_hold_det || prim_hold_det_r) begin
                 currState     <= RECEIVEFIS_HOLDA;
                 currPrimitive <= PRIM_HOLDA;
              end
              // primitive suppression : device sent (HOLD, HOLD, CONT) -> go into permanent hold state
              else if(prim_cont_det || prim_cont_det_r) begin
                 if(align_cnt) begin
                    hold          <= 1;
                    currState     <= RECEIVEFIS_WAIT_HOLD;
                 end
                 currPrimitive <= PRIM_HOLDA;
              end
              // receiving data in progress
              else begin
                 currState     <= RECEIVEFIS_HOLDA;
                 currPrimitive <= PRIM_R_IP;
              end
           end

           RECEIVEFIS_WAIT_HOLD: begin
              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 hold          <= 0;
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device requests to terminate permanent hold state -> acknowledge (HOLDA)
              else if((prim_hold_det || prim_hold_det_r) && align_cnt) begin
                 hold          <= 0;
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              // receiving scrambled data (primitive suppression)
              else begin
                 hold          <= 1;
                 currState     <= RECEIVEFIS_WAIT_HOLD;
                 currPrimitive <= PRIM_HOLDA;
              end
           end

           RECEIVEFIS_HOLD1: begin
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end

              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device sends first hold acknowledgement (HOLDA)
              else if((prim_holda_det || prim_holda_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLD2;
                 currPrimitive <= PRIM_HOLD;
              end
              // receive buffer is empty -> go back into normal mode
              else if(to_link_receive_empty && align_cnt) begin
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              else begin
                 currState     <= RECEIVEFIS_HOLD1;
                 currPrimitive <= PRIM_HOLD;
              end
           end

           RECEIVEFIS_HOLD2: begin
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end

              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device sends second hold acknowledgement (HOLDA)
              else if((prim_holda_det || prim_holda_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLD3;
                 currPrimitive <= PRIM_HOLD;
              end
              // receive buffer is empty -> go back into normal mode
              else if(to_link_receive_empty && align_cnt) begin
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              else begin
                 currState     <= RECEIVEFIS_HOLD2;
                 currPrimitive <= PRIM_HOLD;
              end
           end


           RECEIVEFIS_HOLD3: begin
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end

              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // primitive suppression : device sent (HOLDA, HOLDA, CONT) -> go into permanent hold state
              else if((prim_cont_det || prim_cont_det_r) && align_cnt) begin
                 hold          <= 1;
                 currState     <= RECEIVEFIS_HOLD4;
                 currPrimitive <= PRIM_HOLD;
              end
              // receive buffer is empty -> go back into normal mode
              else if(to_link_receive_empty && align_cnt) begin
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              else begin
                 currState     <= RECEIVEFIS_HOLD3;
                 currPrimitive <= PRIM_HOLD;
              end
           end

           // we are waiting for buffer to be emptied by application
           // so that we can continue receiving data
           RECEIVEFIS_HOLD4: begin
              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 hold          <= 0;
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // receive buffer is empty -> go back into normal mode
              // ATTENTION: this transition can only be taken when no primitives are sent
              //            the device may be sending (1) HOLDA, (2) HOLDA, (3) CONT
              //            if we take this transition at 1, RECEIVEFIS_HOLD5 may confuse
              //            the second HOLDA with the HOLDA that determines the end of
              //            scrambled data
              else if(to_link_receive_empty && align_cnt && (!(primitive_det || primitive_det_r1))) begin
                 currState     <= RECEIVEFIS_HOLD5;
                 currPrimitive <= PRIM_R_IP;
              end
              else begin
                 currState     <= RECEIVEFIS_HOLD4;
                 currPrimitive <= PRIM_HOLD;
              end
           end

           // we are waiting for HOLDA from device that signals the end of scrambled data
           // ATTENTION: some device might send HOLDA, HOLDA, CONT
           //            therefore we cannot directly transition to RECEIVEFIS_R_IP
           RECEIVEFIS_HOLD5: begin
              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 hold          <= 0;
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // PRIM_R_IP is acknowledged with HOLDA primitive
              else if((prim_holda_det || prim_holda_det_r) && align_cnt) begin
                 // we cannot directly go to RECEIVEFIS_R_IP
                 // since the device may be sending HOLDA HOLDA CONT scrambled data HOLDA
                 
                 hold          <= 0;
                 currState     <= RECEIVEFIS_HOLD6;
                 currPrimitive <= PRIM_R_IP;
              end
              else begin
                 currState     <= RECEIVEFIS_HOLD5;
                 currPrimitive <= PRIM_R_IP;
              end
           end

           // it is possible that the device sends not a single HOLDA primitive
           // but HOLDA HOLDA CONT scrambled data HOLDA
           RECEIVEFIS_HOLD6: begin
              hold <= 0;
              
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end

              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device requests hold -> acknowledge (HOLDA)
              else if((prim_hold_det || prim_hold_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLDA;
                 currPrimitive <= PRIM_HOLDA;
              end
              // received second HOLDA
              else if((prim_holda_det || prim_holda_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLD7;
                 currPrimitive <= PRIM_R_IP;
              end
              // we did not receive a second primitive
              // and can continue in RECEIVEFIS_R_IP
              else if(align_cnt) begin
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              // receiving data in progress
              else begin
                 currState     <= RECEIVEFIS_HOLD6;
                 currPrimitive <= PRIM_R_IP;
              end
           end

           // if we see a CONT scrambeled data will follow
           // otherwise go into RECEIVEFIS_R_IP
           RECEIVEFIS_HOLD7: begin
              hold <= 0;
              
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end

              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device requests hold -> acknowledge (HOLDA)
              else if((prim_hold_det || prim_hold_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLDA;
                 currPrimitive <= PRIM_HOLDA;
              end
              // received CONT, i.e., HOLDA HOLDA CONT
              else if((prim_cont_det || prim_cont_det_r) && align_cnt) begin
                 hold          <= 1;
                 currState     <= RECEIVEFIS_HOLD8;
                 currPrimitive <= PRIM_R_IP;
              end
              // we did not receive a second primitive
              // and can continue in RECEIVEFIS_R_IP
              else if(align_cnt) begin
                 hold          <= 0;
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              // receiving data in progress
              else begin
                 currState     <= RECEIVEFIS_HOLD7;
                 currPrimitive <= PRIM_R_IP;
              end
           end

           // we are receiving scrambled data until we see
           // another HOLDA
           RECEIVEFIS_HOLD8: begin
              hold <= 1;
              
              // device asks to terminate FIS transaction
              if((prim_wtrm_det || prim_wtrm_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              // device requests hold -> acknowledge (HOLDA)
              else if((prim_hold_det || prim_hold_det_r) && align_cnt) begin
                 currState     <= RECEIVEFIS_HOLDA;
                 currPrimitive <= PRIM_HOLDA;
              end
              // received CONT, i.e., HOLDA HOLDA CONT
              else if((prim_holda_det || prim_holda_det_r) && align_cnt) begin
                 hold          <= 0;
                 currState     <= RECEIVEFIS_R_IP;
                 currPrimitive <= PRIM_R_IP;
              end
              // receiving data in progress
              else begin
                 currState     <= RECEIVEFIS_HOLD8;
                 currPrimitive <= PRIM_R_IP;
              end
           end
           
           RECEIVEFIS_R_OK: begin
              if(rx_datain_r6_valid) begin
                 crc32_rx_state[0] <= crc32_rx_state[1] & crc32_rx_match;
                 crc32_rx_state[1] <= crc32_rx_match;
              end
              
              if((prim_sync_det || prim_sync_det_r) && align_cnt) begin
                 currState             <= IDLE;
                 currPrimitive         <= PRIM_SYNC;
                 FIS_transaction_done  <= 1;
                 FIS_transaction_err   <= (!crc32_rx_state[0]);
              end
              else begin
                 currState     <= RECEIVEFIS_R_OK;
                 currPrimitive <= PRIM_R_OK;
              end
              
           end

           // We should never end up in this state!
           // If we do anyway -> do the equivalent of a reset
           default: begin
              
              currState             <= HOST_COMRESET;
              process_send_data     <= 0; 
              from_link_initialized <= 0;
              from_link_idle        <= 0;
              
              count_en  <= 0;
              
              //tx_comstart_r0 <= 0;
              //tx_comtype_r0  <= 0;
              tx_cominit_r0 <= 1'b0;
              //tx_comfinish_r0 <= 1'b0;
              tx_comwake_r0 <= 1'b0;
              tx_elecidle_r0 <= 1;

              align_cnt_en <= 0;
              send_align_r <= 0;
              rx_reset     <= 0;

              sendState            <= SEND_PRIMITIVE;
              currPrimitive        <= PRIM_ALIGN;
              FIS_transaction_done <= 0;
              FIS_transaction_err  <= 0;
              hold                 <= 0;

              crc32_reset     <= 0;
              crc32_tx_enable <= 0;
              crc32_mode_tx   <= 0;
              crc32_rx_state  <= 2'b0;

              tx_scramble_reset  <= 0;
              tx_scramble_enable <= 0;
              
              link_din_crc <= 0;
              
           end
         endcase
      end

   end

   always @(posedge clk) begin

      if (reset) begin
         align_process <= 0;
      end
      else begin
         tx_scramble_mask_r0 <= 16'h0000;

         if(align_insert) begin
            align_countdown <= 4;
         end
         
         // FSM for tx_data
         case(sendState)
           
           // PRIM_DIALTONE is not really a primitive - D10.2-D10.2 "dial tone"
           SEND_DIALTONE: begin
              align_process <= 0;
              tx_data_r0    <= PRIM_DIALTONE[15:0];
           end

           // Sending 32-bit primitives
           SEND_PRIMITIVE: begin
              align_process <= 0;
              // Full primitive sent -> can insert ALIGN
              if(!align_cnt) begin
                 // Insert align (exception SOF and EOF because not buffered)
                 if(((align_countdown == 4) || (align_countdown == 2)) && (currPrimitive != PRIM_SOF) && (currPrimitive != PRIM_EOF)) begin
                    align_countdown <= align_countdown-1;
                    tx_data_r0      <= PRIM_ALIGN[15:0];
                 end
                 // Send other primitve
                 else begin
                    tx_data_r0 <= currPrimitive[15:0];
                 end
              end

              else begin
                 // Insert align (exception SOF and EOF because not buffered)
                 if(((align_countdown == 3) || (align_countdown == 1)) && (currPrimitive != PRIM_SOF) && (currPrimitive != PRIM_EOF)) begin
                    align_countdown <= align_countdown-1;
                    tx_data_r0      <= PRIM_ALIGN[31:16];
                 end
                 else begin
                    tx_data_r0 <= currPrimitive[31:16];
                 end
              end
           end

           // Sending data (payload data of FISes)
           SEND_PAYLOAD: begin

              if(!align_cnt) begin
                 if((align_countdown == 4) || (align_countdown == 2)) begin
                    if(align_process) begin
                       if(align_countdown == 2) begin
                          align_process <= 0;
                       end
                       align_countdown <= align_countdown-1;
                       tx_data_r0      <= PRIM_ALIGN[15:0];
                    end
                    else begin
                       align_process       <= 1;
                       tx_scramble_mask_r0 <= scramble_mask;
                       tx_data_r0          <= currPayload_r;
                    end
                 end
                 else begin
                    tx_scramble_mask_r0 <= scramble_mask;
                    tx_data_r0          <= currPayload_r;
                 end
              end

              else begin
                 if((align_countdown == 3) || (align_countdown == 1)) begin
                    align_countdown <= align_countdown-1;
                    tx_data_r0      <= PRIM_ALIGN[31:16];
                 end
                 else begin
                    tx_scramble_mask_r0 <= scramble_mask;
                    tx_data_r0          <= currPayload_r;
                 end
              end
              
           end

           // Appending the 32-bit CRC code of a payload
           SEND_CRC: begin
              align_process       <= 0;
              tx_scramble_mask_r0 <= scramble_mask;
              tx_data_r0          <= crc32_code;
           end

           // Appending the 32-bit CRC code of a payload
           default: begin
              align_process <= 0;        
              if(!align_cnt) begin
                 tx_data_r0 <= PRIM_ALIGN[15:0];
              end
              else begin
                 tx_data_r0 <= PRIM_ALIGN[31:16];
              end
           end

         endcase

         // FSM for tx_charisk

         case(sendState)

           SEND_DIALTONE: begin
              tx_charisk_r0 <= 1'b0;
           end
           
           SEND_PAYLOAD: begin
              if((align_countdown != 0) && align_process) begin
                 if(!align_cnt) begin
                    tx_charisk_r0 <= 1'b1;
                 end
                 else begin
                    tx_charisk_r0 <= 1'b0;
                 end
              end
              else begin
                 tx_charisk_r0 <= 1'b0;
              end
           end

           SEND_CRC: begin
              tx_charisk_r0 <= 1'b0;
           end

           default: begin
              if(!align_cnt) begin
                 tx_charisk_r0 <= 1'b1;
              end
              else begin
                 tx_charisk_r0 <= 1'b0;
              end
           end
           
         endcase
      end
   end

   // We always want to send whole primitives (32 bit).
   // Therefore we only change sendState when align_cnt = 1
   always@(posedge clk) begin
      if(reset) begin
         align_cnt = 1;
      end
      else if(align_cnt_en) begin
         align_cnt = align_cnt+1;
      end
      else begin
         align_cnt = 1;
      end
   end

   // This counter is used for the OOB initialization protocol
   always@(posedge clk) begin
      if (reset) begin
         count <= 18'b0;
      end
      else begin
         if(count_en) begin  
            count <= count + 1;
         end
         else begin
            count <= 18'b0;
         end
      end
   end

   // At least every 256 DWords we need to insert two align primitives
   always@(posedge clk) begin
      if (reset) begin
         align_prim_cnt <= 0;
         align_insert   <= 0;
      end
      else begin
         align_prim_cnt <= align_prim_cnt+1;

         align_insert <= 0;
         if(align_prim_cnt == 511) begin
            align_insert <= 1;
         end
      end
   end

   // shift result -> timing constraints
   always@(posedge clk) begin : txdata_shift
      if (reset) begin
         tx_scramble_mask_r1 <= 16'h0000;
         tx_data_r1          <= 16'h0000;
         tx_data_r2          <= 16'h0000;
         tx_data_r3          <= 16'h0000;
         tx_charisk_r1       <= 1'b0;
         tx_charisk_r2       <= 1'b0;
         tx_charisk_r3       <= 1'b0;
         //         tx_comstart_r1      <= 1'b0;
         //         tx_comstart_r2      <= 1'b0;
         //         tx_comstart_r3      <= 1'b0;
         //         tx_comtype_r1       <= 1'b0;
         //         tx_comtype_r2       <= 1'b0;
         //         tx_comtype_r3       <= 1'b0;
         tx_cominit_r1 <= 1'b0;
         //tx_comfinish_r1 <= 1'b0;
         tx_comwake_r1 <= 1'b0;
         tx_cominit_r2 <= 1'b0;
         //tx_comfinish_r2 <= 1'b0;
         tx_comwake_r2 <= 1'b0;
         tx_cominit_r3 <= 1'b0;
         //tx_comfinish_r3 <= 1'b0;
         tx_comwake_r3 <= 1'b0;
         tx_elecidle_r1      <= 1'b1;
         tx_elecidle_r2      <= 1'b1;
         tx_elecidle_r3      <= 1'b1;
      end
      else begin
         tx_scramble_mask_r1 <= tx_scramble_mask_r0;
         
         tx_data_r1 <= tx_data_r0;
         tx_data_r2 <= tx_data_r1 ^ tx_scramble_mask_r1;
         tx_data_r3 <= tx_data_r2;

         tx_charisk_r1 <= tx_charisk_r0;
         tx_charisk_r2 <= tx_charisk_r1;
         tx_charisk_r3 <= tx_charisk_r2;

         //         tx_comstart_r1  <= tx_comstart_r0;
         //         tx_comstart_r2  <= tx_comstart_r1;
         //         tx_comstart_r3  <= tx_comstart_r2;
         //         tx_comtype_r1   <= tx_comtype_r0;
         //         tx_comtype_r2   <= tx_comtype_r1;
         //         tx_comtype_r3   <= tx_comtype_r2;
         tx_cominit_r1 <= tx_cominit_r0;
         tx_cominit_r2 <= tx_cominit_r1;
         tx_cominit_r3 <= tx_cominit_r2;

         //tx_comfinish_r1 <= tx_comfinish_r0;
         //tx_comfinish_r2 <= tx_comfinish_r1;
         //tx_comfinish_r3 <= tx_comfinish_r2;
         
         tx_comwake_r1 <= tx_comwake_r0;
         tx_comwake_r2 <= tx_comwake_r1;
         tx_comwake_r3 <= tx_comwake_r2;
         
         tx_elecidle_r1   <= tx_elecidle_r0;
         tx_elecidle_r2   <= tx_elecidle_r1;
         tx_elecidle_r3   <= tx_elecidle_r2;
      end
   end

   assign tx_data     = tx_data_r3;
   assign tx_charisk  = tx_charisk_r3;
   //   assign tx_comstart = tx_comstart_r3;
   //   assign tx_comtype  = tx_comtype_r3;
   assign tx_cominit = tx_cominit_r3;
   //assign tx_comfinish = tx_comfinish_r3;
   assign tx_comwake = tx_comwake_r3;
   assign tx_elecidle = tx_elecidle_r3;

   // primitive detection

   assign prim_align_det   = (rx_datain_r1 == PRIM_ALIGN[31:16]   && rx_datain_r2 == PRIM_ALIGN[15:0]);
   assign prim_cont_det    = (rx_datain_r1 == PRIM_CONT[31:16]    && rx_datain_r2 == PRIM_CONT[15:0]);
   assign prim_dmat_det    = (rx_datain_r1 == PRIM_DMAT[31:16]    && rx_datain_r2 == PRIM_DMAT[15:0]);
   assign prim_eof_det     = (rx_datain_r1 == PRIM_EOF[31:16]     && rx_datain_r2 == PRIM_EOF[15:0]);
   assign prim_hold_det    = (rx_datain_r1 == PRIM_HOLD[31:16]    && rx_datain_r2 == PRIM_HOLD[15:0]);
   assign prim_holda_det   = (rx_datain_r1 == PRIM_HOLDA[31:16]   && rx_datain_r2 == PRIM_HOLDA[15:0]);
   assign prim_pmack_det   = (rx_datain_r1 == PRIM_PMACK[31:16]   && rx_datain_r2 == PRIM_PMACK[15:0]);
   assign prim_pmnak_det   = (rx_datain_r1 == PRIM_PMNAK[31:16]   && rx_datain_r2 == PRIM_PMNAK[15:0]);
   assign prim_pmreq_p_det = (rx_datain_r1 == PRIM_PMREQ_P[31:16] && rx_datain_r2 == PRIM_PMREQ_P[15:0]);
   assign prim_pmreq_s_det = (rx_datain_r1 == PRIM_PMREQ_S[31:16] && rx_datain_r2 == PRIM_PMREQ_S[15:0]);
   assign prim_r_err_det   = (rx_datain_r1 == PRIM_R_ERR[31:16]   && rx_datain_r2 == PRIM_R_ERR[15:0]);
   assign prim_r_ip_det    = (rx_datain_r1 == PRIM_R_IP[31:16]    && rx_datain_r2 == PRIM_R_IP[15:0]);
   assign prim_r_ok_det    = (rx_datain_r1 == PRIM_R_OK[31:16]    && rx_datain_r2 == PRIM_R_OK[15:0]);
   assign prim_r_rdy_det   = (rx_datain_r1 == PRIM_R_RDY[31:16]   && rx_datain_r2 == PRIM_R_RDY[15:0]);
   assign prim_sof_det     = (rx_datain_r1 == PRIM_SOF[31:16]     && rx_datain_r2 == PRIM_SOF[15:0]);
   assign prim_sync_det    = (rx_datain_r1 == PRIM_SYNC[31:16]    && rx_datain_r2 == PRIM_SYNC[15:0]);
   assign prim_wtrm_det    = (rx_datain_r1 == PRIM_WTRM[31:16]    && rx_datain_r2 == PRIM_WTRM[15:0]);
   assign prim_x_rdy_det   = (rx_datain_r1 == PRIM_X_RDY[31:16]   && rx_datain_r2 == PRIM_X_RDY[15:0]);



   // delayed primitives: used when received primitives are not aligned
   always @(posedge clk) begin
      if (reset) begin
         prim_align_det_r   <= 0;
         prim_cont_det_r    <= 0;
         prim_dmat_det_r    <= 0;
         prim_eof_det_r     <= 0;
         prim_hold_det_r    <= 0;
         prim_holda_det_r   <= 0;
         prim_pmack_det_r   <= 0;
         prim_pmnak_det_r   <= 0;
         prim_pmreq_p_det_r <= 0;
         prim_pmreq_s_det_r <= 0;
         prim_r_err_det_r   <= 0;
         prim_r_ip_det_r    <= 0;
         prim_r_ok_det_r    <= 0;
         prim_r_rdy_det_r   <= 0;
         prim_sof_det_r     <= 0;
         prim_sync_det_r    <= 0;
         prim_wtrm_det_r    <= 0;
         prim_x_rdy_det_r   <= 0;

         from_link_done     <= 0;
         from_link_err      <= 0;
         
         to_link_FIS_rdy_r1 <= 0;
         to_link_FIS_rdy_r2 <= 0;
      end
      else begin
         prim_align_det_r   <= prim_align_det;
         prim_cont_det_r    <= prim_cont_det;
         prim_dmat_det_r    <= prim_dmat_det;
         prim_eof_det_r     <= prim_eof_det;
         prim_hold_det_r    <= prim_hold_det;
         prim_holda_det_r   <= prim_holda_det;
         prim_pmack_det_r   <= prim_pmack_det;
         prim_pmnak_det_r   <= prim_pmnak_det;
         prim_pmreq_p_det_r <= prim_pmreq_p_det;
         prim_pmreq_s_det_r <= prim_pmreq_s_det;
         prim_r_err_det_r   <= prim_r_err_det;
         prim_r_ip_det_r    <= prim_r_ip_det;
         prim_r_ok_det_r    <= prim_r_ok_det;
         prim_r_rdy_det_r   <= prim_r_rdy_det;
         prim_sof_det_r     <= prim_sof_det;
         prim_sync_det_r    <= prim_sync_det;
         prim_wtrm_det_r    <= prim_wtrm_det;
         prim_x_rdy_det_r   <= prim_x_rdy_det;

         from_link_done     <= FIS_transaction_done;
         from_link_err      <= FIS_transaction_err;
         
         to_link_FIS_rdy_r1 <= to_link_FIS_rdy;
         to_link_FIS_rdy_r2 <= to_link_FIS_rdy_r1;
      end
   end
   
   // --- FIFO to store data coming form disk --------------------------------

   always@(posedge clk) begin : rxdata_shift
      if (reset)
        begin
           primitive_det       <= 1'b0;
           primitive_det_r1    <= 1'b0;
           primitive_det_r2    <= 1'b0;

           rx_datain_r1        <= 16'b0;
           rx_datain_r2        <= 16'b0;
           rx_datain_r3        <= 16'b0;
           rx_datain_r4        <= 16'b0;
           rx_datain_r5        <= 16'b0;
           rx_datain_r6        <= 16'b0;

           rx_datain_r3_valid  <= 1'b0;
           rx_datain_r4_valid  <= 1'b0;
           rx_datain_r5_valid  <= 1'b0;
           rx_datain_r6_valid  <= 1'b0;
        end 
      else 
        begin 
           primitive_det       <= rx_charisk[0];
           primitive_det_r1    <= primitive_det;
           primitive_det_r2    <= primitive_det_r1;
           
           rx_datain_r1        <= rx_datain;
           rx_datain_r2        <= rx_datain_r1;
           rx_datain_r3        <= rx_datain_r2;
           rx_datain_r4        <= rx_datain_r3 ^ scramble_mask;
           rx_datain_r5        <= rx_datain_r4;
           rx_datain_r6        <= rx_datain_r5;
           
           rx_datain_r3_valid  <= rx_datain_r2_valid;
           rx_datain_r4_valid  <= rx_datain_r3_valid;
           rx_datain_r5_valid  <= rx_datain_r4_valid;
           rx_datain_r6_valid  <= rx_datain_r5_valid;
        end
   end

   // registers & parameters to compute rx_datain_r2_valid
   
   always @(posedge clk) begin
      if(reset) begin
         receiveFIScurrState <= WAIT_SOF;
         rx_datain_valid     <= 0;
      end
      else begin
         case(receiveFIScurrState)
           WAIT_SOF: begin
              rx_datain_valid <= 0;
              if(prim_sof_det) begin
                 receiveFIScurrState <= WAIT_EOF;
              end
           end
           
           WAIT_EOF: begin
              // when we detect primitives set data valid = 0
              if(primitive_det || primitive_det_r1) begin
                 rx_datain_valid <= 0;
                 if(prim_eof_det) begin
                    receiveFIScurrState <= WAIT_SOF;
                 end
              end
              else begin
                 rx_datain_valid <= 1;
              end
           end
         endcase
      end
   end

   assign rx_datain_r2_valid = rx_datain_valid && (!hold);

   // --- Scramble/Unscramble data ----------------------------------------------------

   // since SATA is not full-duplex we use the same scrambler circuit
   // for incoming and outgoing traffic
   
   Scrambler Scrambler0 
     (
      .clk          (clk),
      .reset        (tx_scramble_reset || prim_eof_det),
      .enable       (tx_scramble_enable || prim_sof_det),
      .nopause      (link_din_valid || link_din_done || link_din_crc || rx_datain_r2_valid),
      .scramblemask (scramble_mask)
      );


   // --- CRC generation & checking ---------------------

   // since SATA is not full-duplex we use the same CRC-32 circuit 
   // for incoming and outgoing traffic
   
   CRC_32 CRC_32_0
     (
      .clk    (clk),
      .reset  (crc32_reset), // reset is triggered before reception or transmission of a FIS
      .enable (rx_datain_r4_valid || (crc32_tx_enable && (link_din_valid | link_din_done))),
      .tx     (crc32_mode_tx),
      .data   (crc32_data),
      .crc    (crc32_code)
      );
   
   assign crc32_data     = crc32_mode_tx ? to_link_data : rx_datain_r4;
   assign crc32_rx_match = rx_datain_r6 == crc32_code;
   
endmodule
