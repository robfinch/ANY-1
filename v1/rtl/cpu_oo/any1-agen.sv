// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
`include "any1-defines.sv"

module any1_agen(inst, ele, a, b, base, offset, ma, idle);
parameter AMSB = 63;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
input [63:0] inst;
input [5:0] ele;
input [AMSB:0] a;
input [AMSB:0] b;
input [AMSB:0] base;
input [63:0] offset;
output reg [AMSB:0] ma;
output idle;

assign idle = 1'b1;
reg [AMSB+1:0] bx;
reg [63:0] cst;

always @*
case(inst[`SZ4])
3'd0:	bx <= b;
3'd1:	bx <= b << 1;
3'd2:	bx <= b << 2;
3'd3:	bx <= b << 3;
3'd4:	bx <= b << 4;
//3'd7:	bx <= (b << 2) + b;					// * 5
default:	bx = b;
endcase

always @*
casez(inst[`OPCODE])
`CEAX:	ma <=        a + bx + {{42{inst[63]}},inst[63:60],inst[39:32]};
`CEAS:	ma <=        a + b *ele + {{42{inst[63]}},inst[63:60],inst[39:32]};
`CEAVI:	ma <=        a + b + {{42{inst[63]}},inst[63:60],inst[39:32]};
`LDX:		ma <= base + a + bx + {{42{inst[63]}},inst[63:60],inst[39:32]};
`LDS:		ma <= base + a + b * ele + {{42{inst[63]}},inst[63:60],inst[39:32]};
`LDVI:	ma <= base + a + b + {{42{inst[63]}},inst[63:60],inst[39:32]};
`STX:		ma <= base + a + bx + {{42{inst[63]}},inst[63:60],inst[39:32]};
`STS:		ma <= base + a + b * ele + {{42{inst[63]}},inst[63:60],inst[39:32]};
`STVI:	ma <= base + a + b + {{42{inst[63]}},inst[63:60],inst[39:32]};
`LOAD:	// Loads
	casez(inst[`OPCODE])
	`AMO:		ma <= a;
	default:	
		case(inst[`AM])
		1'd0:	ma <= base + a + {{AMSB{inst[36]}},inst[36:18]} + offset;
		1'd1:	ma <= base + a + bx + {inst[36:33],inst[22:18]};
		endcase
	endcase
`STORE:	// stores
	casez(inst[`OPCODE])
	`LEA:
		case(inst[`AM])
		1'd0:		ma <= base + a + {{AMSB{inst[36]}},inst[36:23],inst[12:8]};
		1'd1:		ma <= base + a + cx + {inst[36:33],inst[12:8]};
		endcase
	`PUSHC:
		ma <= base + a - 8'd16;
	`PUSH:
		case(inst[35:34])
		2'd0:	ma <= base + a - 8'd0;
		2'd1:	ma <= base + a - 8'd16;
		2'd2:	ma <= base + a - 8'd32;
		2'd3:	ma <= base + a - 8'd48;
		endcase
	default:	
		case(inst[`AM])
		1'd0:	ma <= base + a + {{AMSB{inst[36]}},inst[36:23],inst[12:8]} + offset;
		1'd1:	ma <= base + a + cx + {inst[36:33],inst[12:8]};
		endcase
	endcase
default:	ma <= base + a + {{AMSB{inst[36]}},inst[36:18]} + offset;
endcase


endmodule
