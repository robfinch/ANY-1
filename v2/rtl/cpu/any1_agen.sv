// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_agen.sv
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
// ============================================================================

import any1_pkg::*;

module any1_agen(rst,clk,ir,ia,ib,ic,imm,ea);
input rst;
input clk;
input Instruction ir;
input Value ia;
input Value ib;
input Value ic;
input Value imm;
output Address ea;

reg [5:0] Sc;
always @*
if (ir.nld.S==0)
	Sc <= 6'd0;
else
	case(ir.ld.func)
	4'd0:	Sc <= 6'd0;
	4'd1:	Sc <= 6'd1;
	4'd2:	Sc <= 6'd2;
	4'd3:	Sc <= 6'd3;
	4'd7:	Sc <= 6'd3;
	default:	Sc <= 6'd0;
	endcase

always @(posedge clk)
if (rst)
	ea <= 32'd0;
else begin
	case(ir.ld.opcode)
	LDx:	ea <= imm + ia.val;
	LDxX:	ea <= imm + ia.val + (ib.val << Sc);
	STx:	ea <= imm + ia.val;
	STxX:	ea <= imm + ia.val + (ic.val << Sc);
	default:	ea <= 32'd0;
	endcase
end

endmodule
