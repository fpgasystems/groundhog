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
 * Module        : SpeedNegotiation
 * Created       : April 20 2011
 * Last Update   : November 20 2013
 * ---------------------------------------------------------------------------
 * Description   : Speed Negotiation
 *                 The FSM first tries SATA II (3 Gbit/s). If initialization fails
 *                 SATA I (1.5 Gbit/s) is tried. The GTP tile has a dynamic reconfiguration
 *                 port (DRP) that allows us to change the divider settings of the internal
 *                 phase-locked loop (PLL) of the GTP tile at runtime (FPGA reconfiguration
 *                 is not needed).
 * 
 *                 DRP and setting for SATA I:
 * 
 *                 Attribute             | DRP Address | Value
 * 
 *                 PLL_RXDIVSEL_OUT_0[0] | 0x46[2]     | 1
 *                 PLL_RXDIVSEL_OUT_1[0] | 0x0A[0]     | 1
 *                 PLL_TXDIVSEL_OUT_0[0] | 0x45[15]    | 1
 *                 PLL_TXDIVSEL_OUT_1[0] | 0x05[4]     | 1
 *
 *                 DRP and setting for SATA II:
 * 
 *                 Attribute             | DRP Address | Value
 * 
 *                 PLL_RXDIVSEL_OUT_0[0] | 0x46[2]     | 0
 *                 PLL_RXDIVSEL_OUT_1[0] | 0x0A[0]     | 0
 *                 PLL_TXDIVSEL_OUT_0[0] | 0x45[15]    | 0
 *                 PLL_TXDIVSEL_OUT_1[0] | 0x05[4]     | 0
 * ---------------------------------------------------------------------------
 * Changelog     : none
 * ------------------------------------------------------------------------- */

`timescale 1 ns / 1 ps 

module SpeedNegotiation 
  (
   input wire        clk,
   input wire        reset,
  
   //--- input ports ----------------------------------------------------

   input wire        from_link_initialized, // SATA link established
   input wire [15:0] do, // DRP data out
   input wire        drdy, // DRP ready
   input wire        gtp_lock, // GTP locked

   //--- output ports ---------------------------------------------------
  
   output reg        mgt_reset, // GTP reset request     
   output reg [6:0]  daddr, // DRP address
   output reg        den, // DRP enable
   output reg [15:0] di, // DRP data in
   output reg        dwe, // DRP write enable
   output reg [1:0]  gen_value             // Indicates negotiated SATA version : 1 = SATA 1, 2 = SATA II, (3 = SATA III -> not yet supported)
  
   );

   localparam [4:0]
     IDLE            = 0,
     
     // SATA II states
     GEN2_READ_0     = 1,
     GEN2_WRITE_0    = 2,
     GEN2_COMPLETE_0 = 3,
     GEN2_PAUSE      = 4,
     GEN2_READ_1     = 5,
     GEN2_WRITE_1    = 6,
     GEN2_COMPLETE_1 = 7,
     GEN2_RESET      = 8,
     GEN2_WAIT       = 9,
     
     // SATA I states
     GEN1_READ_0     = 10,
     GEN1_WRITE_0    = 11,
     GEN1_COMPLETE_0 = 12,
     GEN1_PAUSE      = 13,
     GEN1_READ_1     = 14,
     GEN1_WRITE_1    = 15,
     GEN1_COMPLETE_1 = 16,
     GEN1_RESET      = 17,
     GEN1_WAIT       = 18,
     
     LINKUP          = 19;

   localparam
     GEN1 = 2'b01,
     GEN2 = 2'b10,
     GEN3 = 2'b11;
   
   reg [4:0]         state;
   reg [31:0]        linkup_cnt;
   reg [15:0]        drp_reg;
   reg [15:0]        reset_cnt;
   reg [3:0]         pause_cnt;
   
   always @ (posedge clk) begin
      
      if(reset) begin
         
         state      <= IDLE;
         daddr      <= 7'b0;
         di         <= 8'b0;
         den        <= 1'b0;
         dwe        <= 1'b0;
         drp_reg    <= 16'b0;
         linkup_cnt <= 32'h0;
         gen_value  <= GEN2;
         reset_cnt  <= 16'b0000000000000000;
         mgt_reset  <= 1'b0;
         pause_cnt  <= 4'b0000;
         
      end
      else begin
         
         case(state)

           IDLE: begin
              if(gtp_lock) begin
                 daddr <= 7'h46;
                 den   <= 1'b1;
                 state <= GEN2_READ_0;        
              end
              else begin
                 state <= IDLE;
              end
           end
           
           /* ------------------------------------------------------------ */
           /* SATA II                                                      */
           /* ------------------------------------------------------------ */           
           
           GEN2_READ_0: begin
              gen_value <= GEN2;
              if(drdy) begin
                 drp_reg <= do;
                 den     <= 1'b0;
                 state   <= GEN2_WRITE_0;
              end
              else begin
                 state <= GEN2_READ_0;
              end
           end
           
           GEN2_WRITE_0: begin
              di    <= drp_reg;
              di[2] <= 1'b0;
              den   <= 1'b1;
              dwe   <= 1'b1;
              state <= GEN2_COMPLETE_0;
           end
           
           GEN2_COMPLETE_0: begin
              if(drdy) begin
                 dwe   <= 1'b0;
                 den   <= 1'b0;
                 state <= GEN2_PAUSE;
              end
              else begin
                 state <= GEN2_COMPLETE_0;
              end
           end
           
           GEN2_PAUSE: begin
              if(pause_cnt == 4'b1111) begin
                 dwe       <= 1'b0;
                 den       <= 1'b1;
                 daddr     <= 7'h45;
                 pause_cnt <= 4'b0000;
                 state     <= GEN2_READ_1;
              end
              else begin
                 pause_cnt <= pause_cnt + 1'b1;
                 state     <= GEN2_PAUSE;
              end
           end
      
           GEN2_READ_1: begin
              if(drdy) begin
                 drp_reg <= do;
                 den     <= 1'b0;
                 state   <= GEN2_WRITE_1;
              end
              else begin
                 state <= GEN2_READ_1;
              end
           end
           
           GEN2_WRITE_1: begin
              di     <= drp_reg;  
              di[15] <= 1'b0;
              den    <= 1'b1;
              dwe    <= 1'b1;
              state  <= GEN2_COMPLETE_1;
           end
           
           GEN2_COMPLETE_1: begin
              if(drdy) begin
                 dwe   <= 1'b0;
                 den   <= 1'b0;
                 state <= GEN2_RESET;
              end
              else begin
                 state <= GEN2_COMPLETE_1;
              end
           end
           
           GEN2_RESET: begin
              if(reset_cnt == 16'b00001111) begin
                 reset_cnt <= reset_cnt + 1'b1;
                 state     <= GEN2_RESET;
                 mgt_reset <= 1'b1;
              end
              else if(reset_cnt == 16'b0000000000011111) begin
                 reset_cnt <= 16'b00000000;
                 mgt_reset <= 1'b0;
                 state     <= GEN2_WAIT;
              end
              else begin
                 reset_cnt <= reset_cnt + 1'b1;
                 state     <= GEN2_RESET;
              end
           end
           
           GEN2_WAIT:  begin
              if(from_link_initialized) begin
                 linkup_cnt <= 32'h0;
                 state      <= LINKUP;
              end
              else begin
                 if(gtp_lock) begin
                    if(linkup_cnt == 32'h00080EB4) begin // Duration allows 4 linkup tries
                       linkup_cnt <= 32'h0;
                       daddr      <= 7'h46;
                       den        <= 1'b1;
                       state      <= GEN1_READ_0;
                    end
                    else begin
                       linkup_cnt <= linkup_cnt + 1'b1;
                       state      <= GEN2_WAIT;
                    end
                 end
                 else begin
                    state <= GEN2_WAIT;
                 end
              end
           end

           /* ------------------------------------------------------------ */
           /* SATA I                                                       */
           /* ------------------------------------------------------------ */   
           
           GEN1_READ_0: begin
              gen_value <= GEN1;
              if(drdy) begin
                 drp_reg <= do;
                 den     <= 1'b0;
                 state   <= GEN1_WRITE_0;
              end
              else begin
                 state <= GEN1_READ_0;
              end
           end

           GEN1_WRITE_0: begin
              di    <= drp_reg;  
              di[2] <= 1'b1;
              den   <= 1'b1;
              dwe   <= 1'b1;
              state <= GEN1_COMPLETE_0;
           end
   
           GEN1_COMPLETE_0: begin
              if(drdy) begin
                 dwe   <= 1'b0;
                 den   <= 1'b0;
                 state <= GEN1_PAUSE;
              end
              else begin
                 state <= GEN1_COMPLETE_0;
              end
           end 

           GEN1_PAUSE: begin
              if(pause_cnt == 4'b1111) begin
                 dwe       <= 1'b0;
                 den       <= 1'b1;
                 daddr     <= 7'h45;
                 pause_cnt <= 4'b0000;
                 state     <= GEN1_READ_1;
              end
              else begin
                 pause_cnt <= pause_cnt + 1'b1;
                 state     <= GEN1_PAUSE;
              end
           end
           
           GEN1_READ_1: begin 
              if(drdy) begin
                 drp_reg <= do;
                 den     <= 1'b0;
                 state   <= GEN1_WRITE_1;
              end
              else begin
                 state <= GEN1_READ_1;
              end
           end
           
           GEN1_WRITE_1: begin
              di     <= drp_reg;
              di[15] <= 1'b1;
              den    <= 1'b1;
              dwe    <= 1'b1;
              state  <= GEN1_COMPLETE_1;
           end
           
           GEN1_COMPLETE_1: begin
              if(drdy) begin
                 dwe   <= 1'b0;
                 den   <= 1'b0;
                 state <= GEN1_RESET;
              end
              else begin
                 state <= GEN1_COMPLETE_1;
              end
           end

           GEN1_RESET: begin
              if(reset_cnt == 16'b00001111) begin
                 reset_cnt <= reset_cnt + 1'b1;
                 state     <= GEN1_RESET;
                 mgt_reset <= 1'b1;
              end
              else if(reset_cnt == 16'h001F) begin
                 reset_cnt <= 16'b00000000;
                 mgt_reset <= 1'b0;
                 state     <= GEN1_WAIT;
              end
              else begin
                 reset_cnt <= reset_cnt + 1'b1;
                 state     <= GEN1_RESET;
              end
           end
           
           GEN1_WAIT: begin
              if(from_link_initialized) begin
                 linkup_cnt <= 32'h0;
                 state      <= LINKUP;
              end
              else begin
                 if(gtp_lock) begin
                    if(linkup_cnt == 32'h00080EB4) begin // Duration allows 4 linkup tries
                       linkup_cnt <= 32'h0;
                       daddr      <= 7'h46;
                       den        <= 1'b1;
                       state      <= GEN2_READ_0;
                    end
                    else begin
                       linkup_cnt <= linkup_cnt + 1'b1;
                       state      <= GEN1_WAIT;
                    end
                 end
                 else begin
                    state <= GEN1_WAIT;
                 end
              end
           end

           /* ------------------------------------------------------------ */
           /* Link Initialization succeeded                                */
           /* ------------------------------------------------------------ */  
           
           LINKUP: begin
              if (!from_link_initialized) begin
                 linkup_cnt <= 32'h0;
                 daddr      <= 7'h46;
                 den        <= 1'b1;
                 state      <= GEN2_READ_0;
              end                 
           end
           

           default: begin
              state      <= IDLE;
              daddr      <= 7'b0;
              di         <= 8'b0;
              den        <= 1'b0;
              dwe        <= 1'b0;
              drp_reg    <= 16'b0;
              linkup_cnt <= 32'h0;
              reset_cnt  <= 8'b00000000;
              mgt_reset  <= 1'b0;
              pause_cnt  <= 4'b0000;
              gen_value  <= GEN2;
           end
           
         endcase
         
      end
   end

endmodule
