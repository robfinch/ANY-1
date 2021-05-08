// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_icache.v
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
`define TRUE    1'b1
`define FALSE   1'b0

// -----------------------------------------------------------------------------
// Small, 64 line cache memory (5kiB) made from distributed RAM. Access is
// within a single clock cycle.
// -----------------------------------------------------------------------------

module L1_icache_mem(clk, wr, lineno, i, o, fi, fo);
parameter pLines = 64;
parameter pLineWidth = 512;
localparam pLNMSB = pLines==128 ? 6 : 5;
input clk;
input wr;
input [pLNMSB:0] lineno;
input [pLineWidth-1:0] i;
output [pLineWidth-1:0] o;
input [2:0] fi;		// fault in
output [2:0] fo;	// fault out
integer n;

(* ram_style="distributed" *)
reg [pLineWidth-1:0] mem [0:pLines-1];
reg [2:0] fmem[0:pLines-1];

initial begin
	for (n = 0; n < pLines; n = n + 1) begin
		mem[n] <= {pLineWidth{1'b0}};
		fmem[n] <= 3'd0;
	end
end

always  @(posedge clk)
	if (wr)
		mem[lineno] <= i;
always  @(posedge clk)
	if (wr)
		fmem[lineno] <= fi;

assign o = mem[lineno];
assign fo = fmem[lineno];

endmodule

// -----------------------------------------------------------------------------
// Four way set associative tag memory for L1 cache.
// -----------------------------------------------------------------------------

module L1_icache_cmptag4way(rst, clk, nxt, wr, invline, invall, adr, lineno, hit, missadr);
parameter pLines = 64;
parameter AMSB = 63;
localparam pLNMSB = pLines==128 ? 6 : 5;
localparam pMSB = pLines==128 ? 8 : 7;
input rst;
input clk;
input nxt;
input wr;
input invline;
input invall;
input [AMSB:0] adr;
output reg [pLNMSB:0] lineno;
output reg hit;
output reg [AMSB:0] missadr;

// Tag memory
(* ram_style="distributed" *)
reg [AMSB-5:0] mem0 [0:pLines-1];
reg [AMSB-5:0] mem1 [0:pLines-1];
reg [AMSB-5:0] mem2 [0:pLines-1];
reg [AMSB-5:0] mem3 [0:pLines-1];
reg [AMSB:0] rradr;
reg [pLines-1:0] mem0v;
reg [pLines-1:0] mem1v;
reg [pLines-1:0] mem2v;
reg [pLines-1:0] mem3v;
integer n;
initial begin
  for (n = 0; n < pLines; n = n + 1)
  begin
    mem0[n] = 0;
    mem1[n] = 0;
    mem2[n] = 0;
    mem3[n] = 0;
    mem0v[n] = 0;
    mem1v[n] = 0;
    mem2v[n] = 0;
    mem3v[n] = 0;
  end
end

wire [21:0] lfsro;
lfsr #(22,22'h0ACE3) u1 (rst, clk, nxt, 1'b0, lfsro);
reg [pLNMSB:0] wlineno;
always @(posedge clk)
if (rst)
	wlineno <= 6'h00;
else begin
	if (wr) begin
		case(lfsro[1:0])
		2'b00:	begin  mem0[adr[11:6]] <= adr[AMSB:6];  wlineno <= {2'b00,adr[11:6]}; end
		2'b01:	begin  mem1[adr[11:6]] <= adr[AMSB:6];  wlineno <= {2'b01,adr[11:6]}; end
		2'b10:	begin  mem2[adr[11:6]] <= adr[AMSB:6];  wlineno <= {2'b10,adr[11:6]}; end
		2'b11:	begin  mem3[adr[11:6]] <= adr[AMSB:6];  wlineno <= {2'b11,adr[11:6]}; end
		endcase
	end
end

always @(posedge clk)
if (rst) begin
	mem0v <= 1'd0;
	mem1v <= 1'd0;
	mem2v <= 1'd0;
	mem3v <= 1'd0;
end
else begin
	if (invall) begin
		mem0v <= 1'd0;
		mem1v <= 1'd0;
		mem2v <= 1'd0;
		mem3v <= 1'd0;
	end
	else if (invline) begin
		if (hit0) mem0v[adr[11:6]] <= 1'b0;
		if (hit1) mem1v[adr[11:6]] <= 1'b0;
		if (hit2) mem2v[adr[11:6]] <= 1'b0;
		if (hit3) mem3v[adr[11:6]] <= 1'b0;
	end
	else if (wr) begin
		case(lfsro[1:0])
		2'b00:	begin  mem0v[adr[11:6]] <= 1'b1; end
		2'b01:	begin  mem1v[adr[11:6]] <= 1'b1; end
		2'b10:	begin  mem2v[adr[11:6]] <= 1'b1; end
		2'b11:	begin  mem3v[adr[11:6]] <= 1'b1; end
		endcase
	end	
end


wire hit0 = mem0[adr[11:6]]==adr[AMSB:6] & mem0v[adr[11:6]];
wire hit1 = mem1[adr[11:6]]==adr[AMSB:6] & mem1v[adr[11:6]];
wire hit2 = mem2[adr[11:6]]==adr[AMSB:6] & mem2v[adr[11:6]];
wire hit3 = mem3[adr[11:6]]==adr[AMSB:6] & mem3v[adr[11:6]];
always @*
begin
  if (wr) lineno = {lfsro[1:0],adr[11:6]};
  else if (hit0)  lineno = {2'b00,adr[11:6]};
  else if (hit1)  lineno = {2'b01,adr[11:6]};
  else if (hit2)  lineno = {2'b10,adr[11:6]};
  else  lineno = {2'b11,adr[11:6]};
	hit = hit0|hit1|hit2|hit3;
	missadr = adr;
end
endmodule


// -----------------------------------------------------------------------------
// 16kB (256 rows of 64 bytes) 4-way associative
// -----------------------------------------------------------------------------

module L1_icache(rst, clk, nxt, wr, wadr, adr, i, o, fault_i, fault_o, hit, invall, invline, missadr);
parameter pSize = 2;
parameter AMSB = 63;
localparam pLines = pSize==4 ? 128 : 64;
localparam pLNMSB = pSize==4 ? 6 : 5;
input rst;
input clk;
input nxt;
input wr;
input [AMSB:0] adr;
input [AMSB:0] wadr;
input [511:0] i;
output reg [511:0] o;
input [2:0] fault_i;
output reg [2:0] fault_o;
output hit;
input invall;
input invline;
output [AMSB:0] missadr;

wire [511:0] ic;
wire [2:0] fic;
reg [511:0] i1, i2;
reg [2:0] fi1, fi2;
wire [pLNMSB:0] lineno;
wire taghit;
reg wr1,wr2;

wire iclk;
//BUFH ucb1 (.I(clk), .O(iclk));
assign iclk = clk;

// Must update the cache memory on the cycle after a write to the tag memmory.
// Otherwise lineno won't be valid. Tag memory takes two clock cycles to update.
always @(posedge iclk)
	wr1 <= wr;
always @(posedge iclk)
	wr2 <= wr1;
always @(posedge iclk)
	i1 <= i;
always @(posedge iclk)
	i2 <= i1;
always @(posedge iclk)
	fi1 <= fault_i;
always @(posedge iclk)
	fi2 <= fi1;

L1_icache_mem #(.pLines(pLines)) u1
(
  .clk(iclk),
  .wr(wr1),
  .i(i1),
  .lineno(lineno),
  .o(ic),
  .fi(fi1),
  .fo(fic)
);

L1_icache_cmptag4way #(.pLines(pLines)) u2
(
	.rst(rst),
	.clk(iclk),
	.nxt(nxt),
	.wr(wr),
	.invline(invline),
	.invall(invall),
	.adr(adr),
	.lineno(lineno),
	.hit(taghit),
	.missadr(missadr)
);

assign hit = taghit;

//always @(radr or ic0 or ic1)
always @(ic)
	o <= ic;
always @(fic)
	fault_o <= fic;

endmodule

