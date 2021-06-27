// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_select.sv
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

module any1_select(ir, sel);
input Instruction ir;
output reg [31:0] sel;

always @*
case(ir.r2.opcode)
LDx,STx,LDxX,STxX,LDSx,STSx,LDxVX,CVLDSx,STxVX,CVSTSx:
	case(ir.ld.func)
	4'd0:	sel <= 32'h00000003;
	4'd1:	sel <= 32'h0000000F;
	4'd2:	sel <= 32'h000000FF;
	4'd3:	sel <= 32'h0000FFFF;
	4'd4:	sel <= 32'hFFFFFFFF;
	4'd6:	sel <= 32'h0000FFFF;
	4'd7:	sel <= 32'h0000FFFF;
	4'd8:	sel <= 32'h00000003;
	4'd9:	sel <= 32'h0000000F;
	4'd10:	sel <= 32'h000000FF;
	4'd11:	sel <= 32'h0000FFFF;
	4'd12:	sel <= 32'hFFFFFFFF;
	4'd14:	sel <= 32'h0000FFFF;
	4'd15:	sel <= 32'h0000FFFF;
	default:	sel <= 32'h00000000;
	endcase
CALL,RTS:
	sel <= 32'h0000FFFF;
default:	sel <= 32'h00000000;
endcase
endmodule
