`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2015-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
//`define RED_SCREEN	1'b1
`define CROSS0

module mpmc7(
rst_i, clk40MHz, clk100MHz,
clk0, cyc0, stb0, ack0, we0, sel0, adr0, dati0, dato0,
cs1, cyc1, stb1, ack1, we1, sel1, adr1, dati1, dato1, sr1, cr1, rb1,
cyc2, stb2, ack2, we2, sel2, adr2, dati2, dato2,
cyc3, stb3, ack3, we3, sel3, adr3, dati3, dato3,
cyc4, stb4, ack4, we4, sel4, adr4, dati4, dato4,
cyc5, stb5, ack5, sel5, adr5, dato5, spriteno,
cyc6, stb6, ack6, we6, sel6, adr6, dati6, dato6,
cs7, cyc7, stb7, ack7, we7, sel7, adr7, dati7, dato7, sr7, cr7, rb7,
mem_ui_rst, mem_ui_clk, calib_complete,
rstn, mem_addr, mem_cmd, mem_en, mem_wdf_data, mem_wdf_end, mem_wdf_mask, mem_wdf_wren,
mem_rd_data, mem_rd_data_valid, mem_rd_data_end, mem_rdy, mem_wdf_rdy,
ch, state
);
parameter NAR = 2;
parameter AMSB = 28;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
parameter CMD_READ = 3'b001;
parameter CMD_WRITE = 3'b000;
// State machine states
parameter IDLE = 4'd0;
parameter PRESET = 4'd1;
parameter SEND_DATA = 4'd2;
parameter SET_CMD_RD = 4'd3;
parameter SET_CMD_WR = 4'd4;
parameter WAIT_NACK = 4'd5;
parameter WAIT_RD = 4'd6;

input rst_i;
input clk40MHz;
input clk100MHz;

// Channel 0 is reserved for bitmapped graphics display.
//
parameter C0W = 128;	// Channel zero width
input clk0;
input cyc0;
input stb0;
output ack0;
input [C0W/8-1:0] sel0;
input we0;
input [31:0] adr0;
input [C0W-1:0] dati0;
output reg [C0W-1:0] dato0;
reg [C0W-1:0] dato0n;

// Channel 1 is reserved for cpu1
parameter C1W = 128;
input cs1;
input cyc1;
input stb1;
output ack1;
input we1;
input [C1W/8-1:0] sel1;
input [31:0] adr1;
input [C1W-1:0] dati1;
output reg [C1W-1:0] dato1;
input sr1;
input cr1;
output reg rb1;

// Channel 2 is reserved for the ethernet controller
parameter C2W = 32;
input cyc2;
input stb2;
output ack2;
input we2;
input [C2W/8-1:0] sel2;
input [31:0] adr2;
input [C2W-1:0] dati2;
output reg [C2W-1:0] dato2;

// Channel 3 is reserved for the audio controller
input cyc3;
input stb3;
output ack3;
input we3;
input [1:0] sel3;
input [31:0] adr3;
input [15:0] dati3;
output reg [15:0] dato3;

// Channel 4 is reserved for the graphics controller
parameter C4W = 128;
input cyc4;
input stb4;
output ack4;
input we4;
input [C4W/8-1:0] sel4;
input [31:0] adr4;
input [C4W-1:0] dati4;
output reg [C4W-1:0] dato4;

// Channel 5 is reserved for sprite DMA, which is read-only
parameter C5W = 64;
input cyc5;
input stb5;
output ack5;
input [C5W/8-1:0] sel5;
input [5:0] spriteno;
input [31:0] adr5;
output reg [C5W-1:0] dato5;

// Channel 6 is reserved for the SD/MMC controller
parameter C6W = 128;
input cyc6;
input stb6;
output ack6;
input we6;
input [C6W/8-1:0] sel6;
input [31:0] adr6;
input [C6W-1:0] dati6;
output reg [C6W-1:0] dato6;

// Channel 7 is reserved for the cpu
parameter C7W = 128;
input cs7;
input cyc7;
input stb7;
output ack7;
input we7;
input [C7W/8-1:0] sel7;
input [31:0] adr7;
input [C7W-1:0] dati7;
output reg [C7W-1:0] dato7;
input sr7;
input cr7;
output reg rb7;

// MIG interface signals
input mem_ui_rst;
input mem_ui_clk;
input calib_complete;
output rstn;
output [AMSB:0] mem_addr;
output [2:0] mem_cmd;
output mem_en;
output reg [127:0] mem_wdf_data;
output reg [15:0] mem_wdf_mask;
output mem_wdf_end;
output mem_wdf_wren;
input [127:0] mem_rd_data;
input mem_rd_data_valid;
input mem_rd_data_end;
input mem_rdy;
input mem_wdf_rdy;

// Debugging
output reg [3:0] ch;
output reg [3:0] state;

integer n;

reg [7:0] sel;
reg [31:0] adr;
reg [63:0] dato;
reg [63:0] dati;
reg [127:0] dat128;
reg [15:0] wmask;

reg [3:0] nch;
reg do_wr;
reg [1:0] sreg;
reg rstn;
reg fast_read0, fast_read1, fast_read2, fast_read3;
reg fast_read4, fast_read5, fast_read6, fast_read7;
reg read0,read1,read2,read3;
reg read4,read5,read6,read7;
reg elevate = 1'b0;
reg [5:0] elevate_cnt = 6'h00;
reg [5:0] nack_to = 6'd0;
reg [5:0] spriteno_r;

wire cs0 = cyc0 && stb0 && adr0[31:29]==3'h0;
wire ics1 = cyc1 & stb1 & cs1;
wire cs2 = cyc2 && stb2 && adr2[31:29]==3'h0;
wire cs3 = cyc3 && stb3 && adr3[31:29]==3'h0;
wire cs4 = cyc4 && stb4 && adr4[31:29]==3'h0;
wire cs5 = cyc5 && stb5 && adr5[31:29]==3'h0;
wire cs6 = cyc6 && stb6 && adr6[31:29]==3'h0;
wire ics7 = cyc7 & stb7 & cs7;

reg acki0,acki1,acki2,acki3,acki4,acki5,acki6,acki7;

// Record of the last read address for each channel.
// Cache address tag
reg [31:0] ch0_addr;
reg [31:0] ch1_addr;
reg [31:0] ch2_addr;
reg [31:0] ch3_addr;
reg [31:0] ch4_addr;
reg [31:0] ch5_addr [0:63];	// separate address for each sprite
reg [31:0] ch6_addr;
reg [31:0] ch7_addr;
reg ch5_flag;

// Read data caches
(* ram_style="distributed" *)
reg [127:0] ch0_rd_data [0:7];
(* ram_style="distributed" *)
reg [127:0] ch1_rd_data [0:1];
reg [127:0] ch2_rd_data;
reg [127:0] ch3_rd_data;
reg [127:0] ch4_rd_data;
(* ram_style="distributed" *)
reg [127:0] ch5_rd_data [0:255];
reg [127:0] ch6_rd_data;
(* ram_style="distributed" *)
reg [127:0] ch7_rd_data [0:1];

reg [2:0] num_strips;
reg [2:0] strip_cnt;
reg [2:0] strip_cnt2;
reg [AMSB:0] mem_addr;
reg [AMSB:0] mem_addr0;
reg [AMSB:0] mem_addr1;
reg [AMSB:0] mem_addr2;
reg [AMSB:0] mem_addr3;
reg [AMSB:0] mem_addr4;
reg [AMSB:0] mem_addr5;
reg [AMSB:0] mem_addr6;
reg [AMSB:0] mem_addr7;

reg [15:0] refcnt;
reg refreq;
wire refack;
reg [15:0] tocnt;					// memory access timeout counter

reg [3:0] resv_ch [0:NAR-1];
reg [31:0] resv_adr [0:NAR-1];

reg [7:0] match;
always @(posedge mem_ui_clk)
if (rst_i)
	match <= 8'h00;
else begin
	if (match >= NAR)
		match <= 8'h00;
	else
		match <= match + 8'd1;
end

reg cs0xx;
reg we0xx;
reg [C0W/8-1:0] sel0xx;
reg [31:0] adr0xx;
reg [C0W-1:0] dati0xx;

reg cs1xx;
reg we1xx;
reg [15:0] sel1xx;
reg [31:0] adr1xx;
reg [127:0] dati1xx;
reg sr1xx;
reg cr1xx;

reg cs7xx;
reg we7xx;
reg [C7W/8-1:0] sel7xx;
reg [31:0] adr7xx;
reg [C7W-1:0] dati7xx;
reg sr7xx;
reg cr7xx;

reg [63:0] mem_rd_data1;
reg [7:0] to_cnt;

// Terminate the ack signal as soon as the circuit select goes away.
assign ack0 = acki0 & cs0;
assign ack1 = acki1 & ics1;
assign ack2 = acki2 & cs2;
assign ack3 = acki3 & cs3;
assign ack4 = acki4 & cs4;
assign ack5 = acki5 & cs5;
assign ack6 = acki6 & cs6;
assign ack7 = acki7 & ics7;

// Used to transition state to IDLE at end of access
wire ne_acki0;
wire ne_acki1;
wire ne_acki2;
wire ne_acki3;
wire ne_acki4;
wire ne_acki5;
wire ne_acki6;
wire ne_acki7;
edge_det ed_acki0 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki0), .pe(), .ne(ne_acki0), .ee());
edge_det ed_acki1 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki1), .pe(), .ne(ne_acki1), .ee());
edge_det ed_acki2 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki2), .pe(), .ne(ne_acki2), .ee());
edge_det ed_acki3 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki3), .pe(), .ne(ne_acki3), .ee());
edge_det ed_acki4 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki4), .pe(), .ne(ne_acki4), .ee());
edge_det ed_acki5 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki5), .pe(), .ne(ne_acki5), .ee());
edge_det ed_acki6 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki6), .pe(), .ne(ne_acki6), .ee());
edge_det ed_acki7 (.rst(rst_i), .clk(mem_ui_clk), .ce(1'b1), .i(acki7), .pe(), .ne(ne_acki7), .ee());

// Register signals onto mem_ui_clk domain
// The following channels don't need to be registered as they are operating
// under the mem_ui_clk domain already.
// Channel 0 (bmp controller) 
// Channel 5 (sprite controller)
always @(posedge clk40MHz)
begin
	cs1xx <= ics1;
	we1xx <= we1;
	sel1xx <= sel1;
	adr1xx <= adr1;
	dati1xx <= dati1;
	sr1xx <= sr1;
	cr1xx <= cr1;

	cs7xx <= ics7;
	we7xx <= we7;
	sel7xx <= sel7;
	adr7xx <= adr7;
	dati7xx <= dati7;
	sr7xx <= sr7;
	cr7xx <= cr7;
end
`ifdef CROSS0
always @(posedge clk0)
`else
always @*
`endif
begin
	cs0xx <= cs0;
	we0xx <= we0;
	sel0xx <= sel0;
	adr0xx <= adr0;
	dati0xx <= dati0;
end

always @(posedge clk100MHz)
begin
	sreg <= {sreg[0],rst_i};
	rstn <= ~sreg[1];
end

reg toggle;	// CPU1 / CPU0 priority toggle
reg toggle_sr;
reg [19:0] resv_to_cnt;
reg sr1x,sr7x;
reg [127:0] dati128;

wire ch1_read = ics1 && !we1xx && cs1xx && (adr1xx[31:5]==ch1_addr[31:5]);
wire ch7_read = cs7xx && !we7xx && (adr7xx[31:5]==ch7_addr[31:5]);

always @*
begin
	fast_read0 = (cs0xx && !we0xx && adr0xx[31:7]==ch0_addr[31:7]);
end
always @*
begin
	fast_read1 = ch1_read;
end
always @*
begin
	fast_read2 = (!we2 && cs2 && adr2[31:4]==ch2_addr[31:4]);
end
always @*
begin
	fast_read3 = (!we3 && cs3 && adr3[31:4]==ch3_addr[31:4]);
end
always @*
begin
	fast_read4 = (!we4 && cs4 && adr4[31:4]==ch4_addr[31:4]);
end
// For the sprite channel, reading the 64-bits of a strip not beginning at
// a 64-byte aligned paragraph only checks for the 64 bit address adr[5:3].
// It's assumed that a 4x128-bit strips were read the by the previous access.
// It's also assumed that the strip address won't match because there's more
// than one sprite and sprite accesses are essentially random.
always @*
begin
	fast_read5 = (cs5 && adr5[31:6] == ch5_addr[spriteno][31:6]);
end
always @*
begin
	fast_read6 =  (!we6 && cs6 && adr6[31:4]==ch6_addr[31:4]);
end
always @*
begin
  fast_read7 = ch7_read;
end

always @*
begin
	sr1x = FALSE;
    if (ch1_read)
        sr1x = sr1xx;
end
always @*
begin
	sr7x = FALSE;
    if (ch7_read)
        sr7x = sr7xx;
end

// Select the channel
// This prioritizes the channel during the IDLE state.
// During an elevate cycle the channel priorities are reversed.
always @(posedge mem_ui_clk)
begin
	if (elevate) begin
		if (cs7xx)
			nch <= 3'd7;
		else if (cs6)
			nch <= 3'd6;
		else if (cs5)
			nch <= 3'd5;
		else if (cs4)
			nch <= 3'd4;
		else if (cs3)
			nch <= 3'd3;
		else if (cs2)
			nch <= 3'd2;
		else if (cs1xx)
			nch <= 3'd1;
		else if (cs0xx)
			nch <= 3'd0;
		else
			nch <= 4'hF;
	end
	// Channel 0 read or write takes precedence
	else if (cs0xx & we0xx)
		nch <= 3'd0;
	else if (cs0xx & ~fast_read0)
		nch <= 3'd0;
	else if (cs1xx & we1xx)
		nch <= 3'd1;
	else if (cs2 & we2)
		nch <= 3'd2;
	else if (cs3 & we3)
		nch <= 3'd3;
	else if (cs4 & we4)
		nch <= 3'd4;
	else if (cs6 & we6)
		nch <= 3'd6;
	else if (cs7xx & we7xx)
		nch <= 3'd7;
	// Reads, writes detected above
	else if (cs1xx & ~fast_read1)
		nch <= 3'd1;
	else if (cs2 & ~fast_read2)
		nch <= 3'd2;
	else if (cs3 & ~fast_read3)
		nch <= 3'd3;
	else if (cs4 & ~fast_read4)
		nch <= 3'd4;
	else if (cs5 & ~fast_read5)
		nch <= 3'd5;
	else if (cs6 & ~fast_read6)
		nch <= 3'd6;
	else if (cs7xx & ~fast_read7)
		nch <= 3'd7;
	// Nothing selected
	else
		nch <= 4'hF;
end

// This counter used to periodically reverse channel priorities to help ensure
// that a particular channel isn't permanently blocked by other higher priority
// ones.
always @(posedge mem_ui_clk)
	if (state==PRESET) begin
		elevate_cnt <= elevate_cnt + 6'd1;
		elevate = elevate_cnt == 6'd63;
	end

always @(posedge mem_ui_clk)
	if (state==IDLE)
		ch <= nch;

// Select the address input
always @(posedge mem_ui_clk)
	if (state==IDLE) begin
		case(nch)
		3'd0:	if (we0xx)
					adr <= {adr0xx[AMSB:4],4'h0};
				else
					adr <= {adr0xx[AMSB:6],6'h0};
		3'd1:	if (we1xx)
					adr <= {adr1xx[AMSB:4],4'h0};
				else
					adr <= {adr1xx[AMSB:5],5'h0};
		3'd2:	adr <= {adr2[AMSB:4],4'h0};
		3'd3:	adr <= {adr3[AMSB:4],4'h0};
		3'd4:	adr <= {adr4[AMSB:4],4'h0};
		3'd5:	adr <= {adr5[AMSB:6],6'h0};
		3'd6:	adr <= {adr6[AMSB:4],4'h0};
		3'd7:	if (we7xx)
					adr <= {adr7xx[AMSB:4],4'h0};
				else
					adr <= {adr7xx[AMSB:5],5'h0};
		default:	adr <= 29'h1FFFFFFF;
		endcase
	end

// Setting the write mask
reg [15:0] wmask0;
reg [15:0] wmask1;
reg [15:0] wmask2;
reg [15:0] wmask3;
reg [15:0] wmask4;
reg [15:0] wmask5;
reg [15:0] wmask6;
reg [15:0] wmask7;

always @(posedge mem_ui_clk)
	if (state==IDLE)
	begin
		if (we0xx) begin
			if (C0W==128)
				wmask0 <= ~sel0xx;
			else if (C0W==64)
				case(adr0xx[3])
				1'd0:	wmask0 <= {8'hFF,~sel0xx};
				1'd1: wmask0 <= {~sel0xx,8'hFF};
				endcase
			else
				case(adr0xx[3:2])
				2'd0:	wmask0 <= {12'hFFF,~sel0xx};
				2'd1:	wmask0 <= {8'hFF,~sel0xx,4'hF};
				2'd2:	wmask0 <= {4'hF,~sel0xx,8'hFF};
				2'd3: wmask0 <= {~sel0xx,12'hFFF};
				endcase
		end
		else
			wmask0 <= 16'h0000;
		if (we1xx) begin
			if (C1W==128)
				wmask1 <= ~sel1xx;
			else if (C1W==64)
				case(adr1xx[3])
				1'd0:	wmask1 <= {8'hFF,~sel1xx};
				1'd1: wmask1 <= {~sel1xx,8'hFF};
				endcase
			else
				case(adr1xx[3:2])
				2'd0:	wmask1 <= {12'hFFF,~sel1xx};
				2'd1:	wmask1 <= {8'hFF,~sel1xx,4'hF};
				2'd2:	wmask1 <= {4'hF,~sel1xx,8'hFF};
				2'd3: wmask1 <= {~sel1xx,12'hFFF};
				endcase
		end
		else
			wmask1 <= 16'h0000;
		if (we2) begin
			if (C2W==128)
				wmask2 <= ~sel2;
			else if (C2W==64)
				case(adr2[3])
				1'd0:	wmask2 <= {8'hFF,~sel2};
				1'd1: wmask2 <= {~sel2,8'hFF};
				endcase
			else
				case(adr2[3:2])
				2'd0:	wmask2 <= {12'hFFF,~sel2};
				2'd1:	wmask2 <= {8'hFF,~sel2,4'hF};
				2'd2:	wmask2 <= {4'hF,~sel2,8'hFF};
				2'd3: wmask2 <= {~sel2,12'hFFF};
				endcase
		end
		else
			wmask2 <= 16'h0000;
		if (we3)
			wmask3 <= ~(sel3 << {adr3[3:1],1'b0});
		else
			wmask3 <= 16'h0000;
		if (we4) wmask4 <= ~sel4; else wmask4 <= 16'h0000;
		wmask5 <= 16'h0000;
		if (we6) begin
			if (C6W==128)
				wmask6 <= ~sel6;
			else if (C6W==64)
				case(adr6[3])
				1'd0:	wmask6 <= {8'hFF,~sel6};
				1'd1: wmask6 <= {~sel6,8'hFF};
				endcase
			else
	      case(adr6[3:2])
	      2'd0:  wmask6 <= {12'hFFF,~sel6[3:0]};
	      2'd1:  wmask6 <= {8'hFF,~sel6[3:0],4'hF};
	      2'd2:  wmask6 <= {4'hF,~sel6[3:0],8'hFF};
	      2'd3:  wmask6 <= {~sel6[3:0],12'hFFF};
	      endcase
	  end
    else
    	wmask6 <= 16'h0000;
		if (we7xx) begin
			if (C7W==128)
				wmask7 <= ~sel7xx;
			else
				case(adr7xx[3])
				1'd0:	wmask7 <= {8'hFF,~sel7xx};
				1'd1:	wmask7 <= {~sel7xx,8'hFF};
				endcase
		end
		else
			wmask7 <= 16'h0000;
	end

// Setting the write data
always @(posedge mem_ui_clk)
	if (state==IDLE) begin
		case(nch)
		3'd0:	dat128 <= C0W==128 ? dati0xx : C0W==64 ? {2{dati0xx}} : {4{dati0xx}};
		3'd1:	dat128 <= C1W==128 ? dati1xx : C0W==64 ? {2{dati1xx}} : {4{dati1xx}};
		3'd2:	dat128 <= C2W==128 ? dati2 : C2W==64 ? {2{dati2}} : {4{dati2}};
		3'd3:	dat128 <= {8{dati3}};
		3'd4:	dat128 <= C4W==128 ? dati4 : {2{dati4}};
		3'd5:	;
		3'd6:	dat128 <= C6W==128 ? dati6 : C6W==64 ? {2{dati6}} : {4{dati6}};
		3'd7:	dat128 <= C7W==128 ? dati7xx : {2{dati7xx}};
		default:	dat128 <= {2{dati7xx}};
		endcase
	end

// Managing read cache addresses
reg ld_addr;
always @(posedge mem_ui_clk)
	ld_addr <= (state==WAIT_RD||state==SET_CMD_RD) && mem_rd_data_valid
							&& strip_cnt2==num_strips;
reg cc0,cc1,cc2,cc3,cc4,cc5,cc6,cc7;
always @(posedge mem_ui_clk) cc0 <= state==IDLE && cs0xx && we0xx;
always @(posedge mem_ui_clk) cc1 <= state==IDLE && cs1xx && we1xx;
always @(posedge mem_ui_clk) cc2 <= state==IDLE && cs2 && we2;
always @(posedge mem_ui_clk) cc3 <= state==IDLE && cs3 && we3;
always @(posedge mem_ui_clk) cc4 <= state==IDLE && cs4 && we4;
always @(posedge mem_ui_clk) cc6 <= state==IDLE && cs6 && we6;
always @(posedge mem_ui_clk) cc7 <= state==IDLE && cs7xx && we7xx;

always @(posedge mem_ui_clk)
if (mem_ui_rst) begin
	ch0_addr <= 32'hFFFFFFFF;
	ch1_addr <= 32'hFFFFFFFF;
	ch2_addr <= 32'hFFFFFFFF;
	ch3_addr <= 32'hFFFFFFFF;
	ch4_addr <= 32'hFFFFFFFF;
	for (n = 0; n < 64; n = n + 1)
		ch5_addr[n] <= 32'hFFFFFFFF;
	ch6_addr <= 32'hFFFFFFFF;
	ch7_addr <= 32'hFFFFFFFF;
end
else begin
	if (cc0) clear_cache(adr0xx);
	if (cc1) clear_cache(adr1xx);
	if (cc2) clear_cache(adr2);
	if (cc3) clear_cache(adr3);
	if (cc4) clear_cache(adr4);
	if (cc6) clear_cache(adr6);
	if (cc7) clear_cache(adr7xx);
	ch5_flag <= FALSE;
	if (ld_addr) begin
		case(ch)
		3'd0:	ch0_addr <= {adr0xx[31:6],6'h0};
		3'd1: ch1_addr <= {adr1xx[31:5],5'h00};
		3'd2: ch2_addr <= adr2;
		3'd3: ch3_addr <= adr3;
		3'd4: ch4_addr <= adr4;
		3'd5: ch5_addr[spriteno] <= adr5;
		3'd6: ch6_addr <= adr6;
		3'd7: ch7_addr <= {adr7xx[31:5],5'h0};
		default:	;
		endcase
	end
end

always @(posedge mem_ui_clk)
	if (state==IDLE)
		spriteno_r <= spriteno;

// Setting burst length
always @(posedge mem_ui_clk)
	if (state==IDLE) begin
  		num_strips <= 3'd0;
		case(nch)
		3'd0:	if (!we0xx) num_strips <= 3'd7;
		3'd1:	if (!we1xx)	num_strips <= 3'd1;
		3'd2:	;
		3'd3:	;
		3'd4:	;
		3'd5:	num_strips <= 3'd3;
		3'd6:	;
		3'd7:	if (!we7xx)	num_strips <= 3'd1;
		default:	;
		endcase
	end

// Auto-increment the request address during a read burst until the desired
// number of strips are requested.
always @(posedge mem_ui_clk)
if (state==PRESET)
	mem_addr <= adr;
else if (state==SET_CMD_RD)
  if (mem_rdy == TRUE) begin
    if (strip_cnt!=num_strips) begin
      mem_addr <= mem_addr + 10'd16;
    end
  end
always @(posedge mem_ui_clk)
if (mem_ui_rst)
  mem_wdf_mask <= 16'h0000;
else begin
if (state==PRESET)
	case(ch)
	3'd0:	mem_wdf_mask <= wmask0;
	3'd1:	mem_wdf_mask <= wmask1;
	3'd2:	mem_wdf_mask <= wmask2;
	3'd3:	mem_wdf_mask <= wmask3;
	3'd4:	mem_wdf_mask <= wmask4;
	3'd5:	mem_wdf_mask <= wmask5;
	3'd6:	mem_wdf_mask <= wmask6;
	3'd7:	mem_wdf_mask <= wmask7;
	default:	mem_wdf_mask <= 16'h0000;
	endcase
end
always @(posedge mem_ui_clk)
if (mem_ui_rst)
  mem_wdf_data <= 128'd0;
else begin
if (state==PRESET)
	mem_wdf_data <= dat128;
end

// Setting output data
always @(posedge clk40MHz)
`ifdef RED_SCREEN
	if (C0W==128)
		dato0 <= 128'h7C007C007C007C007C007C007C007C00;
	else if (C0W==64)
		dato0 <= 64'h7C007C007C007C00;
	else
		dato0 <= 32'h7C007C00;
`else
	if (C0W==128)
		dato0 <= ch0_rd_data[adr0xx[5:4]];
	else if (C0W==64)
		case(adr0xx[3])
		1'd0:	dato0 <= ch0_rd_data[adr0xx[5:4]][63:0];
		1'd1:	dato0 <= ch0_rd_data[adr0xx[5:4]][127:64];
		endcase
	else
		case(adr0xx[3:2])
		2'd0:	dato0 <= ch0_rd_data[adr0xx[5:4]][31:0];
		2'd1:	dato0 <= ch0_rd_data[adr0xx[5:4]][63:32];
		2'd2:	dato0 <= ch0_rd_data[adr0xx[5:4]][95:64];
		2'd3:	dato0 <= ch0_rd_data[adr0xx[5:4]][127:96];
		endcase
`endif
always @(posedge clk40MHz)
	if (C1W==128)
		dato1 <= ch1_rd_data[adr1xx[4]];
	else if (C1W==64)
		case(adr1xx[3])
		1'd0:	dato1 <= ch1_rd_data[adr1xx[4]][63:0];
		1'd1:	dato1 <= ch1_rd_data[adr1xx[4]][127:64];
		endcase
	else
		case(adr1xx[3:2])
		2'd0:	dato1 <= ch1_rd_data[adr1xx[4]][31:0];
		2'd1:	dato1 <= ch1_rd_data[adr1xx[4]][63:32];
		2'd2:	dato1 <= ch1_rd_data[adr1xx[4]][95:64];
		2'd3:	dato1 <= ch1_rd_data[adr1xx[4]][127:96];
		endcase
always @(posedge clk40MHz)
	if (C2W==128)
		dato2 <= ch2_rd_data;
	else if (C2W==64)
		case(adr2[3])
    1'd0:    dato2 <= ch2_rd_data[ 63:0];
    1'd1:    dato2 <= ch2_rd_data[127:64];
    endcase
	else
		case(adr2[3:2])
    2'd0:    dato2 <= ch2_rd_data[31:0];
    2'd1:    dato2 <= ch2_rd_data[63:32];
    2'd2:    dato2 <= ch2_rd_data[95:64];
    2'd3:    dato2 <= ch2_rd_data[127:96];
    endcase
always @(posedge clk40MHz)
	dato3 <= ch3_rd_data >> {adr3[3:1],4'd0};
always @(posedge clk40MHz)
	if (C4W==128)
		dato4 <= ch4_rd_data;
	else
		case(adr4[3])
		1'b0:	dato4 <= ch4_rd_data[63:0];
		1'b1:	dato4 <= ch4_rd_data[127:64];
		endcase
always @(posedge clk40MHz)
	if (C5W==128)
		dato5 <= ch5_rd_data[{spriteno_r,adr5[5:4]}][127: 0];
	else if (C5W==64)
		case(adr5[3])
		1'b0:	dato5 <= ch5_rd_data[{spriteno_r,adr5[5:4]}][ 63: 0];
		1'b1:	dato5 <= ch5_rd_data[{spriteno_r,adr5[5:4]}][127:64];
	  endcase
	else if (C5W==32)
		case(adr5[3:2])
		2'd0:	dato5 <= ch5_rd_data[{spriteno_r,adr5[5:4]}][ 31: 0];
		2'd1:	dato5 <= ch5_rd_data[{spriteno_r,adr5[5:4]}][ 63:32];
		2'd2:	dato5 <= ch5_rd_data[{spriteno_r,adr5[5:4]}][ 95:64];
		2'd3:	dato5 <= ch5_rd_data[{spriteno_r,adr5[5:4]}][127:96];
	  endcase
	
always @(posedge clk40MHz)
	if (C6W==128)
		dato6 <= ch6_rd_data;
	else if (C6W==64)
		case(adr6[3])
    1'd0:    dato6 <= ch6_rd_data[ 63:0];
    1'd1:    dato6 <= ch6_rd_data[127:64];
    endcase
	else
		case(adr6[3:2])
    2'd0:    dato6 <= ch6_rd_data[31:0];
    2'd1:    dato6 <= ch6_rd_data[63:32];
    2'd2:    dato6 <= ch6_rd_data[95:64];
    2'd3:    dato6 <= ch6_rd_data[127:96];
    endcase
always @(posedge clk40MHz)
	case(adr7xx[4:3])
	2'd0:	dato7 <= ch7_rd_data[0][63:0];
	2'd1:	dato7 <= ch7_rd_data[0][127:64];
	2'd2:	dato7 <= ch7_rd_data[1][63:0];
	2'd3:	dato7 <= ch7_rd_data[1][127:64];
	endcase

// Setting ack output
// Ack takes place outside of a state so that reads from different read caches
// may occur at the same time.
always @(posedge mem_ui_clk)
if (rst_i|mem_ui_rst) begin
	acki0 <= FALSE;
	acki1 <= FALSE;
	acki2 <= FALSE;
	acki3 <= FALSE;
	acki4 <= FALSE;
	acki5 <= FALSE;
	acki6 <= FALSE;
	acki7 <= FALSE;
end
else begin
	// Reads: the ack doesn't happen until the data's been cached.
	if (fast_read0)
		acki0 <= TRUE;
	if (ch1_read)
		acki1 <= TRUE;
	if (!we2 && cs2 && adr2[31:4]==ch2_addr[31:4])
		acki2 <= TRUE;
	if (!we3 && cs3 && adr3[31:4]==ch3_addr[31:4])
		acki3 <= TRUE;
	if (!we4 && cs4 && adr4[31:4]==ch4_addr[31:4])
		acki4 <= TRUE;
	if (cs5 && adr5[31:6]==ch5_addr[spriteno][31:6])
    acki5 <= TRUE;
	if (!we6 && cs6 && adr6[31:4]==ch6_addr[31:4])
		acki6 <= TRUE;
  if (fast_read7)
    acki7 <= TRUE;

	if (state==IDLE) begin
    if (cr1xx) begin
      acki1 <= TRUE;
    	for (n = 0; n < NAR; n = n + 1)
      	if ((resv_ch[n]==4'd1) && (resv_adr[n][31:4]==adr1xx[31:4]))
        	acki1 <= FALSE;
    end
//    else
//        acki1 <= FALSE;
    if (cr7xx) begin
      acki7 <= TRUE;
    	for (n = 0; n < NAR; n = n + 1)
	      if ((resv_ch[n]==4'd7) && (resv_adr[n][31:4]==adr7xx[31:4]))
	        acki7 <= FALSE;
    end
//    else
//      acki7 <= FALSE;
	end

	// Write: an ack can be sent back as soon as the write state is reached..
	if (state==SET_CMD_WR && mem_rdy == TRUE)
    case(ch)
    3'd0:   acki0 <= TRUE;
    3'd1:   acki1 <= TRUE;
    3'd2:   acki2 <= TRUE;
    3'd3:   acki3 <= TRUE;
    3'd4:   acki4 <= TRUE;
    3'd5:   acki5 <= TRUE;
    3'd6:   acki6 <= TRUE;
    3'd7:   acki7 <= TRUE;
    default:	;
    endcase

	// Clear the ack when the circuit is de-selected.
	if (!cs0xx) acki0 <= FALSE;
	if (!cs1xx || !ics1) acki1 <= FALSE;
	if (!cs2) acki2 <= FALSE;
	if (!cs3) acki3 <= FALSE;
	if (!cs4) acki4 <= FALSE;
	if (!cs5) acki5 <= FALSE;
	if (!cs6) acki6 <= FALSE;
	if (!cs7xx) acki7 <= FALSE;

end

// State machine
always @(posedge mem_ui_clk)
if (rst_i|mem_ui_rst)
	state <= IDLE;
else
case(state)
IDLE:
  // According to the docs there's no need to wait for calib complete.
  // Calib complete goes high in sim about 111 us.
  // Simulation setting must be set to FAST.
	//if (calib_complete)
	begin
		case(nch)
		3'd0:	state <= PRESET;
		3'd1:
		    if (cr1xx) begin
	        state <= IDLE;
		    	for (n = 0; n < NAR; n = n + 1)
	        	if ((resv_ch[n]==4'd1) && (resv_adr[n][31:4]==adr1xx[31:4]))
            	state <= PRESET;
		    end
		    else
	        state <= PRESET;
		3'd2:	state <= PRESET;
		3'd3:	state <= PRESET;
		3'd4:	state <= PRESET;
		3'd5:	state <= PRESET;
		3'd6:	state <= PRESET;
		3'd7:
		    if (cr7xx) begin
	        state <= IDLE;
		    	for (n = 0; n < NAR; n = n + 1)
		        if ((resv_ch[n]==4'd7) && (resv_adr[n][31:4]==adr7xx[31:4]))
	            state <= PRESET;
		    end
		    else
	        state <= PRESET;
		default:	;	// no channel selected -> stay in IDLE state
		endcase
	end
PRESET:
	if (do_wr)
		state <= SEND_DATA;
	else begin
		tocnt <= 16'd0;
		state <= SET_CMD_RD;
	end
SEND_DATA:
  if (mem_wdf_rdy == TRUE)
    state <= SET_CMD_WR;
SET_CMD_WR:
	begin
		nack_to <= 6'd0;
	  if (mem_rdy == TRUE)
	    state <= WAIT_NACK;
	end
SET_CMD_RD:
	begin
		nack_to <= 6'd0;
		tocnt <= tocnt + 16'd1;
		if (tocnt==16'd120)
			state <= IDLE;
    if (mem_rdy == TRUE) begin
			if (strip_cnt==num_strips) begin
				tocnt <= 16'd0;
				state <= WAIT_RD;
			end
    end
    if (mem_rd_data_valid) begin
			if (strip_cnt2==num_strips)
				state <= WAIT_NACK;
    end
	end
WAIT_RD:
	begin
		nack_to <= 6'd0;
		tocnt <= tocnt + 16'd1;
		if (tocnt==16'd120)
			state <= IDLE;
    if (mem_rd_data_valid) begin
      if (strip_cnt2==num_strips)
        state <= WAIT_NACK;
    end
	end
WAIT_NACK:
	begin
		case(ch)
		3'd0:	if (ne_acki0) state <= IDLE;
		3'd1:	if (ne_acki1) state <= IDLE;
		3'd2:	if (ne_acki2) state <= IDLE;
		3'd3:	if (ne_acki3) state <= IDLE;
		3'd4:	if (ne_acki4) state <= IDLE;
		3'd5:	if (ne_acki5) state <= IDLE;
		3'd6:	if (ne_acki6) state <= IDLE;
		3'd7:	if (ne_acki7) state <= IDLE;
		default:	state <= IDLE;
		endcase
		nack_to <= nack_to + 6'd1;
		if (nack_to==6'd5)
			state <= IDLE;
	end
default:	state <= IDLE;
endcase


// Manage memory strip counters.
always @(posedge mem_ui_clk)
begin
	if (state==IDLE)
		strip_cnt <= 3'd0;
	else if (state==SET_CMD_RD)
    if (mem_rdy == TRUE) begin
      if (strip_cnt != num_strips)
        strip_cnt <= strip_cnt + 3'd1;
    end
end

always @(posedge mem_ui_clk)
begin
	if (state==IDLE)
		strip_cnt2 <= 3'd0;
	else if (state==WAIT_RD || state==SET_CMD_RD)
  	if (mem_rd_data_valid) begin
	    case(ch)
	    3'd0:	strip_cnt2 <= strip_cnt2 + 3'd1;
	    3'd1:	strip_cnt2 <= strip_cnt2 + 3'd1;
	    3'd5:	strip_cnt2 <= strip_cnt2 + 3'd1;
	    3'd7:	strip_cnt2 <= strip_cnt2 + 3'd1;
	    default:	;
	    endcase
  	end
end

// Update data caches with read data.
always @(posedge mem_ui_clk)
begin
	if (state==WAIT_RD || state==SET_CMD_RD)
  	if (mem_rd_data_valid) begin
	    case(ch)
	    3'd0:	ch0_rd_data[strip_cnt2[2:0]] <= mem_rd_data;
	    3'd1:	ch1_rd_data[strip_cnt2[0]] <= mem_rd_data;
	    3'd2:	ch2_rd_data <= mem_rd_data;
	    3'd3:	ch3_rd_data <= mem_rd_data;
	    3'd4:	ch4_rd_data <= mem_rd_data;
	    3'd5:	ch5_rd_data[{spriteno_r,strip_cnt2[1:0]}] <= mem_rd_data;
	    3'd6:	ch6_rd_data <= mem_rd_data;
	    3'd7:	ch7_rd_data[strip_cnt2[0]] <= mem_rd_data;
	    default:	;
	    endcase
		end
end

// Write operation indicator
always @(posedge mem_ui_clk)
begin
	if (state==IDLE) begin
		case(nch)
		3'd0:	do_wr <= we0xx;
		3'd1:
			if (we1xx) begin
			    if (cr1xx) begin
			    	do_wr <= FALSE;
			    	for (n = 0; n < NAR; n = n + 1)
			        if ((resv_ch[n]==4'd1) && (resv_adr[n][31:4]==adr1xx[31:4]))
		            do_wr <= TRUE;
			    end
			    else
		        do_wr <= TRUE;
			end
			else
				do_wr <= FALSE;
		3'd2:	do_wr <= we2;
		3'd3:	do_wr <= we3;
		3'd4:	do_wr <= we4;
		3'd6:	do_wr <= we6;
		3'd7:
			if (we7xx) begin
			    if (cr7xx) begin
			    	do_wr <= FALSE;
			    	for (n = 0; n < NAR; n = n + 1)
			        if ((resv_ch[n]==4'd7) && (resv_adr[n][31:4]==adr7xx[31:4]))
		            do_wr <= TRUE;
			    end
			    else
		        do_wr <= TRUE;
			end
      else
      	do_wr <= FALSE;
	    default:	do_wr <= FALSE;
	    endcase
	end
end

// Reservation status bit
always @(posedge mem_ui_clk)
if (state==IDLE) begin
  if (cs1xx & we1xx & ~acki1) begin
    if (cr1xx) begin
      rb1 <= FALSE;
    	for (n = 0; n < NAR; n = n + 1)
	      if ((resv_ch[n]==4'd1) && (resv_adr[n][31:4]==adr1xx[31:4]))
  	      rb1 <= TRUE;
    end
  end
end

always @(posedge mem_ui_clk)
if (state==IDLE) begin
  if (cs7xx & we7xx & ~acki7) begin
    if (cr7xx) begin
      rb7 <= FALSE;
    	for (n = 0; n < NAR; n = n + 1)
	      if ((resv_ch[n]==4'd7) && (resv_adr[n][31:4]==adr7xx[31:4]))
  	      rb7 <= TRUE;
    end
  end
end

// Managing address reservations
always @(posedge mem_ui_clk)
if (mem_ui_rst) begin
	resv_to_cnt <= 20'd0;
	toggle <= FALSE;
	toggle_sr <= FALSE;
 	for (n = 0; n < NAR; n = n + 1)
		resv_ch[n] <= 4'hF;
end
else begin
	resv_to_cnt <= resv_to_cnt + 20'd1;

	if (sr1x & sr7x) begin
		if (toggle_sr) begin
			reserve_adr(4'h1,adr1xx);
			toggle_sr <= 1'b0;
		end
		else begin
			reserve_adr(4'h7,adr7xx);
			toggle_sr <= 1'b1;
		end
	end
	else begin
		if (sr1x)
			reserve_adr(4'h1,adr1xx);
		if (sr7x)
			reserve_adr(4'h7,adr7xx);
	end

	if (state==IDLE) begin
		if (cs1xx & we1xx & ~acki1) begin
		    toggle <= 1'b1;
		    if (cr1xx) begin
		    	for (n = 0; n < NAR; n = n + 1)
		        if ((resv_ch[n]==4'd1) && (resv_adr[n][31:4]==adr1xx[31:4]))
		            resv_ch[n] <= 4'hF;
		    end
		end
		else if (cs7xx & we7xx & ~acki7) begin
		    toggle <= 1'b1;
		    if (cr7xx) begin
		    	for (n = 0; n < NAR; n = n + 1)
		        if ((resv_ch[n]==4'd7) && (resv_adr[n][31:4]==adr7xx[31:4]))
		            resv_ch[n] <= 4'hF;
		    end
		end
		else if (!we1xx & cs1xx & ~fast_read1 & (cs7xx ? toggle : 1'b1))
			toggle <= 1'b0;
		else if (!we7xx & cs7xx & ~fast_read7)
			toggle <= 1'b1;
	end
end

assign mem_wdf_wren = state==SEND_DATA;
assign mem_wdf_end = state==SEND_DATA;
assign mem_en = state==SET_CMD_RD || state==SET_CMD_WR;
assign mem_cmd = state==SET_CMD_RD ? CMD_READ : CMD_WRITE;

// Clear the read cache where the cache address matches the given address. This is to
// prevent reading stale data from a cache.
task clear_cache;
input [31:0] adr;
begin
	if (ch0_addr[31:6]==adr[31:6])
		ch0_addr <= 32'hFFFFFFFF;
	if (ch1_addr[31:5]==adr[31:5])
		ch1_addr <= 32'hFFFFFFFF;
	if (ch2_addr[31:4]==adr[31:4])
		ch2_addr <= 32'hFFFFFFFF;
	if (ch3_addr[31:4]==adr[31:4])
		ch3_addr <= 32'hFFFFFFFF;
	if (ch4_addr[31:4]==adr[31:4])
		ch4_addr <= 32'hFFFFFFFF;
	// For channel5 we don't care.
	// It's possible that stale data would be read, but it's only for one video
	// frame. It's a lot of extra hardware to clear channel5 so we don't do it.
	if (ch6_addr[31:4]==adr[31:4])
		ch6_addr <= 32'hFFFFFFFF;
	if (ch7_addr[31:5]==adr[31:5])
		ch7_addr <= 32'hFFFFFFFF;
end
endtask

integer empty_resv;
function resv_held;
input [3:0] ch;
input [31:0] adr;
begin
	resv_held = FALSE;
 	for (n = 0; n < NAR; n = n + 1)
 		if (resv_ch[n]==ch && resv_adr[n]==adr)
 			resv_held = TRUE;
end
endfunction

// Find an empty reservation bucket
always @*
begin
	empty_resv <= -1;
 	for (n = 0; n < NAR; n = n + 1)
		if (resv_ch[n]==4'hF)
			empty_resv <= n;
end

// Two reservation buckets are allowed for. There are two (or more) CPU's in the
// system and as long as they are not trying to control the same resource (the
// same semaphore) then they should be able to set a reservation. Ideally there
// could be more reservation buckets available, but it starts to be a lot of
// hardware.
task reserve_adr;
input [3:0] ch;
input [31:0] adr;
begin
	// Ignore an attempt to reserve an address that's already reserved. The LWAR
	// instruction is usually called in a loop and we don't want it to use up
	// all address reservations.
	if (!resv_held(ch,adr)) begin
		if (empty_resv >= 0) begin
			resv_ch[empty_resv] <= ch;
			resv_adr[empty_resv] <= adr;
		end
		// Here there were no free reservation buckets, so toss one of the
		// old reservations out.
		else begin
			resv_ch[match] <= ch;
			resv_adr[match] <= adr;
		end
	end
end
endtask

endmodule


