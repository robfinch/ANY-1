`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	DFPSqrt128_tb.v
//		- decimal floating point square root test bench
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

module DFPSqrt128_tb();
parameter N=34;
reg rst;
reg clk;
reg clk4x;
reg [12:0] adr;
DFP128 a, a1;
DFP128 mem [0:8191];
reg [255:0] memo [0:9000];
DFP128 o;
reg ld;
wire done;
reg [3:0] state;
reg [7:0] count;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	clk4x = 0;
	adr = 0;
//	$readmemh("d:/cores2020/rtf64/v2/rtl/verilog/cpu/fpu/test_bench/fpSqrt128_tv.txt", mem);
	#20 rst = 1;
	#50 rst = 0;
end

always #8
	clk = ~clk;

genvar g;
generate begin : gRand
	for (g = 0; g < 128; g = g + 4) begin
		always @(posedge clk) begin
			a1[g+3:g] <= $urandom() % 16;
		end
	end
end
endgenerate

always @(posedge clk)
if (rst) begin
	adr = 0;
	state <= 1;
	count <= 0;
end
else
begin
	ld <= 1'b0;
case(state)
4'd1:
	begin
		count <= 8'd0;
		a <= a1;
		ld <= 1'b1;
		state <= 2;
	end
4'd2:
	begin
		count <= count + 2'd1;
		if (count==8'd160) begin
			memo[adr] <= {o,a};
			adr <= adr + 1;
			if (adr==8191) begin
				$writememh("d:/cores2020/rtf64/v2/rtl/verilog/cpu/fpu/test_bench/DFPSqrt128_tvo.txt", memo);
				$finish;
			end
			state <= 3;
		end
	end
4'd3:	state <= 4;
4'd4:	state <= 5;
4'd5:	state <= 1;
endcase
end

DFPSqrt128nr #(.N(N)) u1 (rst, clk, 1'b1, ld, a, o, 3'b000);//, sign_exe, inf, overflow, underflow);

endmodule
