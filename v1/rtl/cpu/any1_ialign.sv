// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_ialign.sv
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//                                                                          
//
// Input a cache line and address and output a single instruction.
// ============================================================================

import any1_pkg::*;

module any1_ialign(i, o);
input sInstAlignIn i;
output sInstAlignOut o;

always @*
begin
	o.Stream <= i.Stream;
	o.predict_taken <= i.predict_taken;
  case(i.ip[5:0])
  6'h00:	o.ir <= i.cacheline[63:0];
  6'h08:	o.ir <= i.cacheline[127:64];
  6'h10:	o.ir <= i.cacheline[191:128];
  6'h18:	o.ir <= i.cacheline[255:192];
  6'h20:	o.ir <= i.cacheline[319:256];
  6'h28:	o.ir <= i.cacheline[383:320];
  6'h30:	o.ir <= i.cacheline[447:384];
  6'h38:	o.ir <= i.cacheline[511:448];
  default:	o.ir <= {40'h0,FLT_IADR,16'h0};		// instruction alignment fault
	endcase
	o.ip <= i.ip;
	o.rid <= i.rid;
	o.pip <= i.pip;
end

endmodule
