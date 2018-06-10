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
 * Author        : Louis Woods <louis.woods@inf.ethz.ch>
 * Module        : CRC32
 * Created       : May 17 2011
 * Last Update   : March 15 2012
 * ---------------------------------------------------------------------------
 * Description   : CRC32 Generation Module: G(x)
 *                 G(x) = x^32+x^26+x^23+x^22+x^16+x^12+x^11+x^10+x^8+x^7+x^5+x^4+x^2+x+1
 *                 Init: current_crc <= 32'h52325032;
 * ------------------------------------------------------------------------- */

`timescale 1ns / 1ps

module CRC_32
  (
   input         clk,
   input         reset,
   input         enable,
   input         tx,
   input [15:0]  data,
   output [15:0] crc
   );

   reg [15:0]         data_r1;
   reg [15:0]         data_r2;
   reg [15:0]         data_r3;
   
   reg                odd;
   wire [15:0]        current_data;
   reg  [31:0]        current_crc;
   
   reg                enable_r1;
   reg                enable_r2;
   
   reg [31:0]         tmp_crc;
   reg                x32;
   integer            i;

   assign current_data = (tx) ? ((odd) ? data : data_r2)                         : ((odd) ? data_r3 : data_r1);
   assign crc          = (tx) ? ((odd) ? current_crc[15:0] : current_crc[31:16]) : ((odd) ? current_crc[31:16] : current_crc[15:0]);

   initial begin
      odd         = 0;
      current_crc = 32'h52325032;
      enable_r1   = 0;
      enable_r2   = 0;
   end
   
   always @(posedge clk) begin
      
      if(reset) begin
         odd         <= 0;
         current_crc <= 32'h52325032;
         enable_r1   <= 0;
         enable_r2   <= 0;
      end
      else begin

         tmp_crc = current_crc;
         
         if (enable || enable_r1) begin
            odd <= !odd;
         end

         if (enable) begin

            data_r1 <= data;
            data_r2 <= data_r1;
            data_r3 <= data_r2;
            
            enable_r1 <= 1;
            enable_r2 <= enable_r1;

            if ((tx && enable_r1) || enable_r2) begin

               // shift 16 times          
               for(i=15; i>=0; i=i-1) begin

                  // get output of LFSR
                  x32 = tmp_crc[31] ^ current_data[i];
                  
                  tmp_crc[31] = tmp_crc[30];
                  tmp_crc[30] = tmp_crc[29];
                  tmp_crc[29] = tmp_crc[28];
                  tmp_crc[28] = tmp_crc[27];
                  tmp_crc[27] = tmp_crc[26];
                  tmp_crc[26] = tmp_crc[25] ^ x32; // x^25 xor x^32
                  tmp_crc[25] = tmp_crc[24];
                  tmp_crc[24] = tmp_crc[23];

                  tmp_crc[23] = tmp_crc[22] ^ x32; // x^22 xor x^32
                  tmp_crc[22] = tmp_crc[21] ^ x32; // x^21 xor x^32
                  tmp_crc[21] = tmp_crc[20];
                  tmp_crc[20] = tmp_crc[19];
                  tmp_crc[19] = tmp_crc[18];
                  tmp_crc[18] = tmp_crc[17];
                  tmp_crc[17] = tmp_crc[16];
                  tmp_crc[16] = tmp_crc[15] ^ x32; // x^15 xor x^32

                  tmp_crc[15] = tmp_crc[14];
                  tmp_crc[14] = tmp_crc[13];
                  tmp_crc[13] = tmp_crc[12];
                  tmp_crc[12] = tmp_crc[11] ^ x32; // x^11 xor x^32
                  tmp_crc[11] = tmp_crc[10] ^ x32; // x^10 xor x^32
                  tmp_crc[10] = tmp_crc[9]  ^ x32; // x^9  xor x^32
                  tmp_crc[9]  = tmp_crc[8];
                  tmp_crc[8]  = tmp_crc[7]  ^ x32; // x^7  xor x^32

                  tmp_crc[7] = tmp_crc[6]   ^ x32; // x^6  xor x^32
                  tmp_crc[6] = tmp_crc[5];
                  tmp_crc[5] = tmp_crc[4]   ^ x32; // x^4  xor x^32
                  tmp_crc[4] = tmp_crc[3]   ^ x32; // x^3  xor x^32
                  tmp_crc[3] = tmp_crc[2];
                  tmp_crc[2] = tmp_crc[1]   ^ x32; // x^1  xor x^32
                  tmp_crc[1] = tmp_crc[0]   ^ x32; // x^0  xor x^32
                  tmp_crc[0] = x32;
  
               end
            end
         end
         current_crc <= tmp_crc;
      end
   end

endmodule
