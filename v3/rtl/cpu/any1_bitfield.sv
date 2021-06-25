`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2016-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
//
// ============================================================================
//
import any1_pkg::*;

`ifndef BFSET
`define BFSET     3'd0
`define BFCLR     3'd1
`define BFCHG     3'd2 
`define BFINS     3'd3
`define BFEXT     3'd4
`define BFEXTU    3'd5
`define BFFFO	  3'd6
`endif

module any1_bitfield(inst, a, b, c, d, o, masko);
parameter DWIDTH=64;
input Instruction inst;
input Value a;
input Value b;
input Value c;
input Value d;
output Value o;
output [DWIDTH-1:0] masko;

reg [DWIDTH*2-1:0] o1;
reg [DWIDTH*2-1:0] o2;
wire [6:0] ffoo;

// generate mask
reg [DWIDTH-1:0] mask;
assign masko = mask;
wire [2:0] op = inst.r2.func[2:0];
wire [5:0] mb = c.val[5:0];
wire [5:0] mw = d.val[5:0];
reg [5:0] me;
always_comb me <= mb + mw;
wire [5:0] ml = mw;		// mask length-1

integer nn,n;
always @*
	for (nn = 0; nn < DWIDTH; nn = nn + 1)
		mask[nn] <= (nn >= mb) ^ (nn <= me) ^ (me >= mb);

ffo96 u1 ({32'h0,a.val},ffoo);

always @*
begin
o1 = 128'd0;	// prevent inferred latch
o2 = 128'd0;
o.val = {DWIDTH{1'b0}};
case (op)
`BFINS: 
	begin
		o2 = {64'd0,b.val} << mb;
		for (n = 0; n < DWIDTH; n = n + 1) o[n] = (mask[n] ? o2[n] : a.val[n]);
	end
`BFSET: 	begin for (n = 0; n < DWIDTH; n = n + 1) o[n] = mask[n] ? 1'b1 : a.val[n]; end
`BFCLR: 	begin for (n = 0; n < DWIDTH; n = n + 1) o[n] = mask[n] ? 1'b0 : a.val[n]; end
`BFCHG: 	begin for (n = 0; n < DWIDTH; n = n + 1) o[n] = mask[n] ? ~a.val[n] : a.val[n]; end
`BFEXTU:	// Also does SRL
	begin
		o1 = {b.val,a.val} >> mb;
		for (n = 0; n < DWIDTH; n = n + 1)
			o[n] = n <= me ? o1[n] : 1'b0;
	end
`BFEXT:	// Also does SRA
	begin
		o1 = {b.val,a.val} >> mb;
		for (n = 0; n < DWIDTH; n = n + 1)
			o[n] = n <= me ? o1[n] : o1[me];
	end
`BFFFO:
	begin
		for (n = 0; n < DWIDTH; n = n + 1)
			o1[n] = mask[n] ? a.val[n] : 1'b0;
		o.val = (ffoo==7'd127) ? -64'd1 : ffoo - mb;	// ffoo returns 127 if no one was found
	end
default:	o.val = {DWIDTH{1'b0}};
endcase
end

endmodule

