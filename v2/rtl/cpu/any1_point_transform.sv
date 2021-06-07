// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_point_transform.sv
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
//
// Perform point transformation
// Points are transformed in a single clock cycle using 27 parallel multipliers.
//
import any1_pkg::*;

module any1_point_transform(clk_i,wr_i,adr_i,dat_i,dat_o,pt_i,pt_o);
input clk_i;
input wr_i;
input [5:0] adr_i;
input Value dat_i;
output Value dat_o;
input Point pt_i;
output Point pt_o;
parameter AA = 6'd0;
parameter AB = 6'd1;
parameter AC = 6'd2;
parameter AT = 6'd3;
parameter BA = 6'd4;
parameter BB = 6'd5;
parameter BC = 6'd6;
parameter BT = 6'd7;
parameter CA = 6'd8;
parameter CB = 6'd9;
parameter CC = 6'd10;
parameter CT = 6'd11;
parameter CMD = 6'd31;

reg transform, otransform;
reg [31:0] aa, ab, ac, at;	// Transform matrix coefficients
reg [31:0] ba, bb, bc, bt;
reg [31:0] ca, cb, cc, ct;

reg [31:0] up0x, up0y, up0z;
reg [31:0] up1x, up1y, up1z;
reg [31:0] up2x, up2y, up2z;
reg [31:0] p0x, p0y, p0z;
reg [31:0] p1x, p1y, p1z;
reg [31:0] p2x, p2y, p2z;

always @(posedge clk_i)
begin
	if (wr_i)
		case(adr_i)
		AA:	aa <= dat_i;
		AB:	ab <= dat_i;
		AC:	ac <= dat_i;
		AT:	at <= dat_i;
		BA:	ba <= dat_i;
		BB:	bb <= dat_i;
		BC:	bc <= dat_i;
		BT:	bt <= dat_i;
		CA:	ca <= dat_i;
		CB:	cb <= dat_i;
		CC:	cc <= dat_i;
		CT:	ct <= dat_i;
		CMD: transform <= dat_i[0];
		default:	;
		endcase
	case(adr_i)
	AA:	dat_o <= aa;
	AB:	dat_o <= ab;
	AC:	dat_o <= ac;
	AT:	dat_o <= at;
	BA:	dat_o <= ba;
	BB:	dat_o <= bb;
	BC:	dat_o <= bc;
	BT:	dat_o <= bt;
	CA:	dat_o <= ca;
	CB:	dat_o <= cb;
	CC:	dat_o <= cc;
	CT:	dat_o <= ct;
	CMD:	dat_o <= transform;
	default:	dat_o <= 32'd0;
	endcase
end

// Point Transform
wire signed [63:0] aax0 = aa * up0x;
wire signed [63:0] aby0 = ab * up0y;
wire signed [63:0] acz0 = ac * up0z;
wire signed [63:0] bax0 = ba * up0x;
wire signed [63:0] bby0 = bb * up0y;
wire signed [63:0] bcz0 = bc * up0z;
wire signed [63:0] cax0 = ca * up0x;
wire signed [63:0] cby0 = cb * up0y;
wire signed [63:0] ccz0 = cc * up0z;

wire signed [63:0] x0_prime = aax0 + aby0 + acz0 + {at,16'h0000};
wire signed [63:0] y0_prime = bax0 + bby0 + bcz0 + {bt,16'h0000};
wire signed [63:0] z0_prime = cax0 + cby0 + ccz0 + {ct,16'h0000};

always @(posedge clk_i)
	pt_o.x <= transform ? x0_prime[47:16] : pt_i.x;
always @(posedge clk_i)
	pt_o.y <= transform ? y0_prime[47:16] : pt_i.y;
always @(posedge clk_i)
	pt_o.z <= transform ? z0_prime[47:16] : pt_i.z;

endmodule
