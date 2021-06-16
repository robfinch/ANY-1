`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	DFPMultiply128_tb.v
//		- decimal floating point multiplier test bench
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
//	Floating Point Multiplier / Divider
//
//	This multiplier/divider handles denormalized numbers.
//	The output format is of an internal expanded representation
//	in preparation to be fed into a normalization unit, then
//	rounding. Basically, it's the same as the regular format
//	except the mantissa is doubled in size, the leading two
//	bits of which are assumed to be whole bits.
//
//
// ============================================================================

import DFPPkg::*;

module DFPMultiply128_tb();
parameter N=34;
reg rst;
reg clk;
reg [15:0] adr;
DFP128 a,b;
DFP128 o;
DFP128 ad,bd;
DFP128 od;
reg [3:0] rm;

integer n;
DFP128 a1, b1;
wire [63:0] doubleA = {a[31], a[30], {3{~a[30]}}, a[29:23], a[22:0], {29{1'b0}}};
wire [63:0] doubleB = {b[31], b[30], {3{~b[30]}}, b[29:23], b[22:0], {29{1'b0}}};
wire done;
reg ld;

integer outfile;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	adr = 0;
	a = $urandom(1);
	#20 rst = 1;
	#50 rst = 0;
	#2000000  $fclose(outfile);
	#10 $finish;
end

always #5
	clk = ~clk;

genvar g;
generate begin : gRand
	for (g = 0; g < 128; g = g + 4) begin
		always @(posedge clk) begin
			a1[g+3:g] <= $urandom() % 16;
			b1[g+3:g] <= $urandom() % 16;
		end
	end
end
endgenerate

reg [9:0] count;
always @(posedge clk)
if (rst) begin
	adr <= 0;
	count <= 0;
end
else
begin
	ld <= 1'b0;
  if (adr==0) begin
    outfile = $fopen("d:/cores2020/rtf64/v2/rtl/verilog/cpu/fpu/test_bench/DFPMultiply128_tvo.txt", "wb");
    $fwrite(outfile, "rm ------ A ------  ------- B ------  - DUT Product -  - SIM Product -\n");
  end
	count <= count + 1;
	if (count > 750)
		count <= 1'd1;
	if (count==2) begin	
		a <= a1;
		b <= b1;
		ld <= 1'b1;
		rm <= adr[15:13];
		//ad <= memd[adr][63: 0];
		//bd <= memd[adr][127:64];
	end
	if (adr==1 && count==2) begin
		a <= 128'h1c001e0000000000000000000000000;	// 7
		b <= 128'h08000e0000000000000000000000000;	// 2
	end
	if (adr==1 && count==2) begin
		a <= 128'h63ff80334cd334cd334cd334cd334ac;	// 1/3?
		b <= 128'h0c000c0000000000000000000000000;	// 3
	end
	if (adr==2 && count==2) begin
		a <= 128'h64001a0000000000000000000000000;
		b <= 128'h08000e0000000000000000000000000;	// 2
	end
	if (adr==3 && count==2) begin
		a <= 128'h63ffc00000000000000000000000000;	//0?
		b <= 128'h63ffc00000000000000000000000000;
	end
	if (adr==4 && count==2) begin
		a <= 128'h04004e0000000000000000000000000;	// 11
		b <= 128'h04004e0000000000000000000000000;
	end
	if (count==750) begin
	  $fwrite(outfile, "%h\t%h\t%h\t%h\n", rm, a, b, o);
		adr <= adr + 1;
	end
end

//fpMulnr #(64) u1 (clk, 1'b1, a, b, o, rm);//, sign_exe, inf, overflow, underflow);
DFPMultiply128nr u6 (clk, 1'b1, ld, a, b, o, rm, done);//, sign_exe, inf, overflow, underflow);

endmodule
