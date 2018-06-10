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
 * Module        : sysACEIO
 * Created       : April 18 2012
 * Last Update   : November 20 2013
 * ---------------------------------------------------------------------------
 * Description   : This is a utility block.  It is copied from the SIRC v1.0 codebase.
 *                 For more details regarding SIRC please go to 
 *                 http://research.microsoft.com/en-us/downloads/d335458e-c241-4845-b0ef-c587c8d29796/
 * ---------------------------------------------------------------------------
 * Changelog     : none
 * ------------------------------------------------------------------------- */

`timescale 1ns / 1ps
`default_nettype none

  module iobuf16(IO, I, O, T);
   inout [15:0] IO;
   input [15:0] I;
   output [15:0] O;
   input         T;
   
   IOBUF IOBUF_B0(.IO(IO[0]), .I(I[0]), .O(O[0]), .T(T));
   IOBUF IOBUF_B1(.IO(IO[1]), .I(I[1]), .O(O[1]), .T(T));
   IOBUF IOBUF_B2(.IO(IO[2]), .I(I[2]), .O(O[2]), .T(T));
   IOBUF IOBUF_B3(.IO(IO[3]), .I(I[3]), .O(O[3]), .T(T));
   IOBUF IOBUF_B4(.IO(IO[4]), .I(I[4]), .O(O[4]), .T(T));
   IOBUF IOBUF_B5(.IO(IO[5]), .I(I[5]), .O(O[5]), .T(T));
   IOBUF IOBUF_B6(.IO(IO[6]), .I(I[6]), .O(O[6]), .T(T));
   IOBUF IOBUF_B7(.IO(IO[7]), .I(I[7]), .O(O[7]), .T(T));
   IOBUF IOBUF_B8(.IO(IO[8]), .I(I[8]), .O(O[8]), .T(T));
   IOBUF IOBUF_B9(.IO(IO[9]), .I(I[9]), .O(O[9]), .T(T));
   IOBUF IOBUF_B10(.IO(IO[10]), .I(I[10]), .O(O[10]), .T(T));
   IOBUF IOBUF_B11(.IO(IO[11]), .I(I[11]), .O(O[11]), .T(T));
   IOBUF IOBUF_B12(.IO(IO[12]), .I(I[12]), .O(O[12]), .T(T));
   IOBUF IOBUF_B13(.IO(IO[13]), .I(I[13]), .O(O[13]), .T(T));
   IOBUF IOBUF_B14(.IO(IO[14]), .I(I[14]), .O(O[14]), .T(T));
   IOBUF IOBUF_B15(.IO(IO[15]), .I(I[15]), .O(O[15]), .T(T));

endmodule
