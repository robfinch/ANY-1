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

module any1_agen(rst,clk,ir,ia,ib,ic,imm,step,ea);
input rst;
input clk;
input Instruction ir;
input Value ia;
input Value ib;
input Value ic;
input Value imm;
input [5:0] step;
output Address ea;

reg [2:0] Sc;
always_comb
	Sc = ir.nld.Sc;

always @(posedge clk)
if (rst)
	ea <= 32'd0;
else begin
	case(ir.ld.opcode)
	LDx:	ea[AWID-1:0] <= imm + ia.val;
	LDxX:	ea[AWID-1:0] <= imm + ia.val + (ib.val << ir.nld.Sc);
	STx:	ea[AWID-1:0] <= imm + ia.val;
	STxX:	ea[AWID-1:0] <= imm + ia.val + (ic.val << Sc);
	LDSx:	ea[AWID-1:0] <= imm + ia.val + ic.val * step;
	STSx:	ea[AWID-1:0] <= imm + ia.val + ic.val * step;
	LDxVX:	ea[AWID-1:0] <= imm + ia.val + ic.val;
	STxVX:	ea[AWID-1:0] <= imm + ia.val + ic.val;
	CVLDSx:	ea[AWID-1:0] <= imm + ia.val + ic.val * step;
	CVSTSx:	ea[AWID-1:0] <= imm + ia.val + ic.val * step;
	CALL:	  ea[AWID-1:0] <= ia.val;
	RTS:		ea[AWID-1:0] <= ia.val;
	default:	ea <= 33'd0;
	endcase
	ea[-1:-1] <= 1'b0;
end

endmodule
