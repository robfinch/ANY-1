// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_mem_ctrl.sv
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

module any1_mem_ctrl(rst,clk,UserMode,MUserMode,ASID,sregfile,ip,ihit,ifStall,ic_line,
	fifoToCtrl_i,fifoToCtrl_full,fifoFromCtrl_o,fifoFromCtrl_rd,
	bok_i, bte_o, cti_o, vpa_o, vda_o, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o,
	dat_i, dat_o, sr_o, cr_o, rb_i, dce);
parameter AWID=32;
input rst;
input clk;
input UserMode;
input MUserMode;
input [7:0] ASID;
input [63:0] sregfile [0:15];
input Address ip;
output ihit;
input ifStall;
output [511:0] ic_line;
// Fifo controls
input MemoryRequest fifoToCtrl_i;
output fifoToCtrl_full;
output MemoryResponse fifoFromCtrl_o;
input fifoFromCtrl_rd;
// Bus controls
input bok_i;
output reg [1:0] bte_o;
output reg [2:0] cti_o;
output reg vpa_o;
output reg vda_o;
output reg cyc_o;
output reg stb_o;
input ack_i;
output reg we_o;
output reg [15:0] sel_o;
output Address adr_o;
input [127:0] dat_i;
output reg [127:0] dat_o;
output reg sr_o;
output reg cr_o;
input rb_i;
output reg dce;							// data cache enable

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
parameter HIGH = 1'b1;
parameter LOW = 1'b0;

parameter LOAD = 3'd0;
parameter STORE = 3'd1;
parameter CACHE = 3'd3;

parameter MEMORY1 = 6'd1;
parameter MEMORY2 = 6'd2;
parameter MEMORY3 = 6'd3;
parameter MEMORY4 = 6'd4;
parameter MEMORY5 = 6'd5;
parameter MEMORY6 = 6'd6;
parameter MEMORY7 = 6'd7;
parameter MEMORY8 = 6'd8;
parameter MEMORY9 = 6'd9;
parameter MEMORY10 = 6'd10;
parameter MEMORY11 = 6'd11;
parameter MEMORY12 = 6'd12;
parameter MEMORY13 = 6'd13;
parameter DATA_ALIGN = 6'd14;
parameter MEMORY_KEYCHK1 = 6'd15;
parameter MEMORY_KEYCHK2 = 6'd16;
parameter KEYCHK_ERR = 6'd17;
parameter TLB1 = 6'd21;
parameter TLB2 = 6'd22;
parameter TLB3 = 6'd23;
parameter IFETCH1 = 6'd31;
parameter IFETCH2 = 6'd32;
parameter IFETCH3 = 6'd33;
parameter IFETCH4 = 6'd34;
parameter IFETCH5 = 6'd35;
parameter IFETCH6 = 6'd36;
parameter DFETCH2 = 6'd42;
parameter DFETCH3 = 6'd43;
parameter DFETCH4 = 6'd44;
parameter DFETCH5 = 6'd45;
parameter DFETCH6 = 6'd46;
parameter DFETCH7 = 6'd47;
parameter KYLD = 6'd51;
parameter KYLD2 = 6'd52;
parameter KYLD3 = 6'd53;
parameter KYLD4 = 6'd54;
parameter KYLD5 = 6'd55;
parameter KYLD6 = 6'd56;
parameter KYLD7 = 6'd57;

integer n;
genvar g;

reg [5:0] shr_ma;

reg [5:0] state;
// States for hardware routine stack, three deep.
reg [5:0] stk_state1, stk_state2, stk_state3;
reg [1:0] waycnt;
reg iaccess;
reg daccess;
reg [3:0] icnt;
reg [3:0] dcnt;

MemoryRequest memreq;
reg memreq_rd;
MemoryResponse memresp;
reg zero_data;

Address ea = {memreq.adr[AWID-1:AWID-4],memreq.adr[AWID-5:0] >> shr_ma};	// Keep same segment
reg [7:0] ealow;
wire [3:0] segsel = ea[AWID-1:AWID-4];
wire [3:0] ea_acr = sregfile[segsel][3:0];
wire [3:0] pc_acr = sregfile[ip[AWID-1:AWID-4]][3:0];

`ifdef CPU_B128
reg [31:0] sel;
reg [255:0] dat, dati;
wire [63:0] datis = dati >> {ealow[3:0],3'b0};
`endif
`ifdef CPU_B64
reg [15:0] sel;
reg [127:0] dat, dati;
wire [63:0] datis = dati >> {ealow[2:0],3'b0};
`endif
`ifdef CPU_B32
reg [7:0] sel;
reg [63:0] dat, dati;
wire [63:0] datis = dati >> {ealow[1:0],3'b0};
`endif

// Build an insert mask for data cache store operations.
wire [567:0] stmask;
reg [127:0] stmask1;
generate begin : gStMask
`ifdef CPU_B128
	for (g = 0; g < 16; g = g + 1)
		always_comb
			stmask1[g*4+3:g*4] = sel_o[g] ? 8'h00 : 8'hFF;
assign stmask = stmask1 << {adr_o[5:4],7'd0};
`endif
`ifdef CPU_B64
	for (g = 0; g < 8; g = g + 1)
		always_comb
			stmask1[g*4+3:g*4] = sel_o[g] ? 8'h00 : 8'hFF;
assign stmask = stmask1 << {adr_o[5:3],6'd0};
`endif
`ifdef CPU_B32
	for (g = 0; g < 4; g = g + 1)
		always_comb
			stmask1[g*4+3:g*4] = sel_o[g] ? 8'h00 : 8'hFF;
assign stmask = stmask1 << {adr_o[5:2],5'd0};
`endif
end
endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// PMA Checker
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [AWID-4:0] PMA_LB [0:7];
reg [AWID-4:0] PMA_UB [0:7];
reg [15:0] PMA_AT [0:7];

initial begin
  PMA_LB[7] = 28'hFFFC000;
  PMA_UB[7] = 28'hFFFFFFF;
  PMA_AT[7] = 16'h000D;       // rom, byte addressable, cache-read-execute
  PMA_LB[6] = 28'hFFD0000;
  PMA_UB[6] = 28'hFFD1FFF;
  PMA_AT[6] = 16'h0206;       // io, (screen) byte addressable, read-write
  PMA_LB[5] = 28'hFFD2000;
  PMA_UB[5] = 28'hFFDFFFF;
  PMA_AT[5] = 16'h0206;       // io, byte addressable, read-write
  PMA_LB[4] = 28'hFFFFFFF;
  PMA_UB[4] = 28'hFFFFFFF;
  PMA_AT[4] = 16'hFF00;       // vacant
  PMA_LB[3] = 28'hFFFFFFF;
  PMA_UB[3] = 28'hFFFFFFF;
  PMA_AT[3] = 16'hFF00;       // vacant
  PMA_LB[2] = 28'hFFFFFFF;
  PMA_UB[2] = 28'hFFFFFFF;
  PMA_AT[2] = 16'hFF00;       // vacant
  PMA_LB[1] = 28'h1000000;
  PMA_UB[1] = 28'hFFCFFFF;
  PMA_AT[1] = 16'hFF00;       // vacant
  PMA_LB[0] = 28'h0000000;
  PMA_UB[0] = 28'h0FFFFFF;
  PMA_AT[0] = 16'h010F;       // ram, byte addressable, cache-read-write-execute
end


wire [3:0] ififo_cnt;

wire [16:0] lfsr_o;

lfsr ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);


bc_fifo16X #(.WID($bits(MemoryRequest))) uififo1
(
	.clk(clk),
	.reset(rst),
	.wr(fifoToCtrl.fifo_wr),
	.rd(memreq_rd),
	.di(fifoToCtrl),
	.dout(memreq),
	.ctr(ififo_cnt)
);

assign fifoToCtrl_full = ififo_cnt==4'd15;
wire fifoToCtrl_empty = ififo_cnt==4'd0;

bc_fifo16X #(.WID($bits(MemoryResponse))) uififo2
(
	.clk(clk),
	.reset(rst),
	.wr(memresp.fifo_wr),
	.rd(fifoFromCtrl_rd),
	.di(memresp),
	.dout(fifoFromCtrl_o),
	.ctr(ofifo_cnt)
);

assign fifoFromCtrl_o.fifo_empty = ofifo_cnt==4'd0;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg ic_update;
reg [1:0] ic_rway,ic_wway;
wire icache_wr;
assign icache_wr = state==IFETCH3;
reg ic_invline,ic_invall;
reg [1:0] prev_ic_rway = 0;

reg iaccess;
reg [3:0] icnt;
reg [511:0] ici;
reg [AWID-7:0] ic_tag;
reg [AWID-7:0] prev_ic_tag = 0;

icache_blkmem uicm (
  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(icache_wr),      // input wire [0 : 0] wea
  .addra({waycnt,adr_o[12:6]}),  // input wire [8 : 0] addra
  .dina(ici),    // input wire [511 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(!ifStall),      // input wire enb
  .addrb({ic_rway,ip[12:6]}),  // input wire [8 : 0] addrb
  .doutb(ic_line)  // output wire [511 : 0] doutb
);

reg [AWID-7:0] ictag [0:3] [0:512/4-1];
reg [512/4-1:0] icvalid [0:3];
reg ihit;
reg ihit1a;
reg ihit1b;
reg ihit1c;
reg ihit1d;
always_comb
begin
  ihit1a = ictag[0][ip[12:6]]==ip[AWID-1:6] && icvalid[0][ip[12:6]]==TRUE;
  ihit1b = ictag[1][ip[12:6]]==ip[AWID-1:6] && icvalid[1][ip[12:6]]==TRUE;
  ihit1c = ictag[2][ip[12:6]]==ip[AWID-1:6] && icvalid[2][ip[12:6]]==TRUE;
  ihit1d = ictag[3][ip[12:6]]==ip[AWID-1:6] && icvalid[3][ip[12:6]]==TRUE;
	ihit = ihit1a|ihit1b|ihit1c|ihit1d;
end

initial begin
	for (n = 0; n < 512; n = n + 1) begin
		icvalid[0][n] = 1'b1;
		icvalid[1][n] = 1'b1;
		icvalid[2][n] = 1'b1;
		icvalid[3][n] = 1'b1;
	end
  for (n = 0; n < 512; n = n + 1) begin
    ictag[0][n] = 32'd1;
    ictag[1][n] = 32'd1;
    ictag[2][n] = 32'd1;
    ictag[3][n] = 32'd1;
  end
end

always_comb
begin
  case(1'b1)
  ihit1a: ic_rway <= 2'b00;
  ihit1b: ic_rway <= 2'b01;
  ihit1c: ic_rway <= 2'b10;
  ihit1d: ic_rway <= 2'b11;
  default:  ic_rway <= prev_ic_rway;
  endcase
end

// For victim cache update
always_comb
begin
  case(1'b1)
  ihit1a: ic_tag <= ictag[0][ip[12:6]];
  ihit1b: ic_tag <= ictag[1][ip[12:6]];
  ihit1c: ic_tag <= ictag[2][ip[12:6]];
  ihit1d: ic_tag <= ictag[3][ip[12:6]];
  default:  ic_tag <= prev_ic_tag;
  endcase
end

always_ff @(posedge clk)
	prev_ic_rway <= ic_rway;
always_ff @(posedge clk)
	prev_ic_tag <= ic_tag;

always @(posedge clk)
if (rst) begin
	icvalid[0] <= {512/4{1'b0}};
	icvalid[1] <= {512/4{1'b0}};
	icvalid[2] <= {512/4{1'b0}};
	icvalid[3] <= {512/4{1'b0}};
end
else begin
	if (icache_wr) begin
		icvalid[waycnt][adr_o[12:6]] <= 1'b1;
		ictag[waycnt][adr_o[12:6]] <= adr_o[AWID-1:6];
	end
	// Cache line invalidate
	// Use physical address
	// ToDo: Check for tag match
	else if (state==MEMORY4) begin
		if (ic_invline) begin
			icvalid[0][adr_o[12:6]] <= 1'b0;
			icvalid[1][adr_o[12:6]] <= 1'b0;
			icvalid[2][adr_o[12:6]] <= 1'b0;
			icvalid[3][adr_o[12:6]] <= 1'b0;
		end
		else if (ic_invall) begin
			icvalid[0] <= {512/4{1'b0}};
			icvalid[1] <= {512/4{1'b0}};
			icvalid[2] <= {512/4{1'b0}};
			icvalid[3] <= {512/4{1'b0}};
		end
	end
end


reg [2:0] ivcnt;
reg [2:0] vcn;
reg [511:0] ivcache [0:4];
reg [AWID-1:6] ivtag [0:4];
reg [4:0] ivvalid;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Key Cache
// - the key cache is direct mapped, 64 lines of 512 bits.
// - keys are stored in the low order 20 bits of a 32-bit memory cell
// - 16 keys per 512 bit cache line
// - one cache line is enough to cover 256kB of memory
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

`ifdef SUPPORT_KEYCHK
reg [511:0] kyline [0:63];
reg [AWID-19:0] kytag;
reg [63:0] kyv;
reg kyhit;
always_comb
	kyhit <= kytag[adr_o[23:18]]==adr_o[AWID-1:18] && kyv[adr_o[23:18]];
initial begin
	kyv = 64'd0;
	for (n = 0; n < 64; n = n + 1) begin
		kyline[n] = 512'd0;
		kytag[n] = 32'd1;
	end
end
wire [19:0] kyut = kyline[adr_o[23:18]] >> {adr_o[17:14],5'd0};
`endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Data Cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg [1:0] waycnt;
reg daccess;
reg [2:0] dwait;		// wait state counter for dcache
reg [4:0] dcnt;
Address dadr;
reg [631:0] dci;		// 512 + 120 bit overflow area
wire [631:0] dc_line;
reg [631:0] datil;
reg dcachable;
reg [1:0] dc_rway,dc_wway,prev_dc_rway;
reg dcache_wr;
reg dc_invline,dc_invall;

dcache_blkmem udcb1 (
  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(dcache_wr),      // input wire [0 : 0] wea
  .addra({dc_wway,dadr[12:6]}),  // input wire [8 : 0] addra
  .dina(dci),    // input wire [511 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({dc_rway,adr_o[12:6]}),  // input wire [8 : 0] addrb
  .doutb(dc_line)  // output wire [511 : 0] doutb
);

reg [AWID-7:0] dctag0 [0:127];
reg [AWID-7:0] dctag1 [0:127];
reg [AWID-7:0] dctag2 [0:127];
reg [AWID-7:0] dctag3 [0:127];
reg [127:0] dcvalid0;
reg [127:0] dcvalid1;
reg [127:0] dcvalid2;
reg [127:0] dcvalid3;
reg dhit1a;
reg dhit1b;
reg dhit1c;
reg dhit1d;
always_comb	//(posedge clk_g)
  dhit1a <= dctag0[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid0[adr_o[12:6]];
always_comb	//(posedge clk_g)
  dhit1b <= dctag1[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid1[adr_o[12:6]];
always @*	//(posedge clk_g)
  dhit1c <= dctag2[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid2[adr_o[12:6]];
always_comb	//(posedge clk_g)
  dhit1d <= dctag3[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid3[adr_o[12:6]];
wire dhit = dhit1a|dhit1b|dhit1c|dhit1d;
initial begin
  for (n = 0; n < 128; n = n + 1) begin
    dctag0[n] = 32'd1;
    dctag1[n] = 32'd1;
    dctag2[n] = 32'd1;
    dctag3[n] = 32'd1;
  end
end

always_comb
begin
  case(1'b1)
  dhit1a: dc_rway <= 2'b00;
  dhit1b: dc_rway <= 2'b01;
  dhit1c: dc_rway <= 2'b10;
  dhit1d: dc_rway <= 2'b11;
  default:  dc_rway <= prev_dc_rway;
  endcase
end

always_ff @(posedge clk)
	prev_dc_rway <= dc_rway;

// ToDo:
// Add data cache invalidate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// TLB
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg xlaten;
reg tlben, tlbwr;
wire tlbmiss;
wire [3:0] tlbacr;
wire [63:0] tlbdato;
reg [63:0] tlb_ia, tlb_ib;
reg inext;

any1_TLB utlb (
  .rst_i(rst),
  .clk_i(clk),
  .asid_i(ASID),
  .umode_i(vpa_o ? UserMode : MUserMode),
  .xlaten_i(xlaten),
  .we_i(we_o),
  .ladr_i(dadr),
  .next_i(inext),
  .iacc_i(iaccess),
  .dacc_i(daccess),
  .iadr_i(iadr),
  .padr_o(adr_o), // ToDo: fix this for icache access
  .acr_o(tlbacr),
  .tlben_i(tlben),
  .wrtlb_i(tlbwr),
  .tlbadr_i(tlb_ia[11:0]),
  .tlbdat_i(tlb_ib),
  .tlbdat_o(tlbdato),
  .tlbmiss_o(tlbmiss)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// State Machine
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always @(posedge clk)
if (rst) begin
	dce <= FALSE;
end
else begin
	inext <= FALSE;
	memreq_rd <= FALSE;
	memresp.fifo_wr <= FALSE;
	dcache_wr <= FALSE;

	case(state)
	MEMORY1:
		begin
			iaccess <= FALSE;
			daccess <= FALSE;
		  icnt <= 4'd0;
		  dcnt <= 5'd0;
		  shr_ma <= 6'd0;
			if (ihit) begin
				if (!fifoToCtrl_empty) begin
					memreq_rd <= TRUE;
					gosub (MEMORY2);
				end
			end
			else begin
				// On a miss goto load I$ process unless a hit in the victim cache.
				gosub (IFETCH1);
				for (n = 0; n < 5; n = n + 1) begin
					if (ivtag[n]==ip[AWID-1:6] && ivvalid[n]) begin
						vcn <= n;
			    	gosub (IFETCH4);
		    	end
				end
			end
		end
	MEMORY2:
		begin
			// Detect cache controller commands
  		case(memreq.func)
			TLB:
				begin
		    	tlb_ia <= memreq.adr;
    			tlb_ib <= memreq.dat;
    			tlbwr <= TRUE;
					goto (TLB1);
				end
			LOAD:
				case(memreq.func2)
				CACHE2:
					begin
						ic_invline <= memreq.dat[2:0]==3'd1;
						ic_invall	<= memreq.dat[2:0]==3'd2;
						dc_invline <= memreq.dat[5:3]==3'd3;
						dc_invall	<= memreq.dat[5:3]==3'd4;
						memresp.step <= memreq.step;
						if (memreq.dat[5:3]==3'd1)
							dce <= TRUE;
						if (membufo.Rt[5:3]==3'd2)
							dce <= FALSE;
				    memresp.cmt <= TRUE;
						memresp.tid <= memreq.tid;
						memresp.fifo_wr <= TRUE;
						ret();
					end
				LEA2:
					begin
						memresp.tid <= memreq.tid;
						memresp.step <= memreq.step;
						memresp.res <= memreq.adr;
				    memresp.cmt <= TRUE;
						memresp.fifo_wr <= TRUE;
					end
				default:
					begin
			    	daccess <= TRUE;
	    		  tEA(ea);
	      		xlaten <= TRUE;
	      		// Setup proper select lines
			      sel <= memreq.sel << ea[3:0];
			  		goto (MEMORY3);
					end
				endcase
			STORE:
				begin
		    	daccess <= TRUE;
    		  tEA(ea);
      		xlaten <= TRUE;
      		// Setup proper select lines
		      sel <= zero_data ? 16'h0001 << ea[3:0] : memreq.sel << ea[3:0];
		      // Shift output data into position
    		  dat <= zero_data ? 256'd0 : {128'd0,memreq.dat} << {ea[3:0],3'b0};
		  		goto (MEMORY3);
				end
			default:	ret();	// unknown operation
			endcase
	  end
	// The following two states for TLB translation lookup
	MEMORY3:
		goto (MEMORY4);
`ifdef SUPPORT_KEYCHK
	MEMORY4:
		goto (MEMORY_KEYCHK1);
`else
	MEMORY4:
		goto (MEMORY5);
`endif
`ifdef SUPPORT_KEYCHK
	MEMORY_KEYCHK1:
  	begin
  		if (!kyhit)
  			gosub(KYLD);
			else begin
				goto (KEYCHK_ERR);
				for (n = 0; n < 8; n = n + 1)
					if (kyut == keys[n] || kyut==20'd0)
						goto(MEMORY5);
			end
    	if (memreq.func==CACHE)
      	tPMAEA();
  	end
	KEYCHK_ERR:
		begin
			memresp.step <= memreq.step;
	    memresp.cause <= 16'h8031;	// KEY fault
	    memresp.cmt <= TRUE;
			memresp.tid <= memreq.tid;
		  memresp.badAddr <= ea;
		  memresp.fifo_wr <= TRUE;
		  ret();
		end
`endif

	MEMORY5:
	  begin
	    xlaten <= FALSE;
	    dwait <= 3'd0;
	    goto (MEMORY6);
			if (tlbmiss) 
				tTLBMiss(ea);
	    else if (memreq.func2 != CACHE) begin
	    	vda_o <= HIGH;
	      cyc_o <= HIGH;
	      stb_o <= HIGH;
	      sel_o <= sel[`SELL];
	      dat_o <= dat[`DATL];
	      case(memreq.func)
	      LOAD:
	      	begin
	     			sr_o <= memreq.func2==LDOR;
  	    		if (dhit) begin
    	  			tDeactviateBus();
      				sr_o <= LOW;
	      		end
	      	end
	      STORE:	
	      	begin
      			cr_o <= memreq.func2==STCR;
	      		we_o <= HIGH;
	      	end
	      default:  ;
	      endcase
	    end
	  end

	MEMORY6:
	  begin
	  	case(1'b1)
	    ic_invline:	ret();
	    ic_invall:	ret();
	    dc_invline:	ret();
	    dc_invall:	ret();
	    dce & dhit:
		    begin
		    	datil <= dc_line;
		  		if (memreq.func==STORE) begin
		  			if (ack_i) begin
			  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
			  			dc_wway <= dc_rway;
		  				dcache_wr <= TRUE;
				      goto (MEMORY7);
				      stb_o <= LOW;
				      if (sel[`SELH]==1'h0)
				      	tDeactivateBus();
				    end
		  		end
		    	else begin
		    		dwait <= dwait + 2'd1;
		    		if (dwait==3'd2)
			      	goto (MEMORY7);
			    end
	  		end
	    default:
		    if (ack_i) begin
		      goto (MEMORY7);
		      stb_o <= LOW;
		      dati <= dat_i;
		      if (sel[`SELH]==1'h0) begin
		      	tDeactivateBus();
		      end
		    end
	  	endcase
	  end

	MEMORY7:
		begin
		  if (~ack_i) begin
		    if (|sel[`SELH])
		      goto (MEMORY8);
		    else begin
		      case(memreq.func)
		      LOAD:
		      	begin
		      		if (dce & dhit)
		      			dati <= datil >> {adr_o[5:3],6'b0};
			        goto (DATA_ALIGN);
		      	end
			    STORE:
			    	begin
			    		if (memreq.func2==STPTR) begin	// STPTR
					    	if (~|ea[AWID-5:0]) begin
					  			memresp.step <= memreq.step;
					    	 	memresp.cmt <= TRUE;
		  						memresp.tid <= memreq.tid;
		  						memresp.fifo_wr <= TRUE;
						    	ret();
					    	end
					    	else begin
					    		shr_ma <= shr_ma + 4'd9;
					    		zero_data <= TRUE;
					    		goto (MEMORY2);
					    	end
			    		end
			    		else begin
				  			memresp.step <= memreq.step;
					    	memresp.cmt <= TRUE;
				  			memresp.tid <= memreq.tid;
				  			memresp.fifo_wr <= TRUE;
					    	ret();
				      end
			    	end
		      default:
		        mgoto (DATA_ALIGN);
		      endcase
		    end
		  end
	  end

	MEMORY8:
	  begin
	    goto (MEMORY9);
	    xlaten <= TRUE;
	    tEA({ea[AWID-1:4] + 2'd1,4'd0});
	  end
  
	// Wait a couple of clocks for TLB lookup
	MEMORY9:
		begin
	  	goto (MEMORY10);
		end
`ifdef SUPPORT_KEYCHK
	MEMORY10:
		begin
		  goto (MEMORY_KEYCHK2);
		end
 
	MEMORY_KEYCHK2:
  	begin
  		if (!kyhit)
  			gosub(KYLD);
			else begin
				goto (KEYCHK_ERR);
				for (n = 0; n < 8; n = n + 1)
					if (kyut == keys[n] || kyut==20'd0)
						goto(MEMORY11);
			end
    	if (memreq.func==CACHE)
      	tPMAEA();
  	end
`else
	MEMORY10:
	  goto (MEMORY11);
`endif

	MEMORY11:
	  begin
	    xlaten <= FALSE;
	    dwait <= 3'd0;
	//    dadr <= adr_o;
	    goto (MEMORY12);
			if (tlbmiss)
				tTLBMiss(ea);
			else begin
				if (dhit & memreq.func==LOAD & dce)
		 			tDeactivateBus();
				else begin
	      	stb_o <= HIGH;
	      	sel_o <= sel[`SELH];
	      	dat_o <= dat[`DATH];
	    	end
	    end
	  end

	MEMORY12:
	  if (dhit & dce) begin
	  	datil <= dc_line;
			if (memreq.func==STORE) begin
				if (ack_i) begin
	  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
	  			dc_wway <= dc_rway;
	  			dcache_wr <= TRUE;
		      goto (MEMORY13);
		      stb_o <= LOW;
		      if (sel[`SELH]==1'h0)
				    tDeactivateBus();
		    end
			end
	  	else begin
	    	dwait <= dwait + 2'd1;
	    	if (dwait==3'd2)
	      	mgoto (MEMORY13);
	    end
		end
	  else if (ack_i) begin
	    goto (MEMORY13);
	    dati[`DATH] <= dat_i;
	    tDeactivateBus();
	  end

	MEMORY13:
	  if (~ack_i) begin
	    begin
	      case(memreq.func)
	      LOAD:
	      	begin
	      		if (dhit & dce)
	      			dati <= datil >> {adr_o[5:3],6'b0};
		        goto (DATA_ALIGN);
	      	end
		    STORE:
		    	begin
		    		if (memreq.func2==STPTR) begin	// STPTR
				    	if (~|ea[AWID-5:0]) begin
				  			memresp.step <= memreq.step;
				    	 	memresp.cmt <= TRUE;
				  			memresp.tid <= memreq.tid;
				  			memresp.fifo_wr <= TRUE;
					    	ret();
				    	end
				    	else begin
				    		shr_ma <= TRUE;
				    		zero_data <= TRUE;
				    		mgoto (MEMORY2);
				    	end
		    		end
		    		else begin
			  			memresp.step <= memreq.step;
			    	 	memresp.cmt <= TRUE;
			  			memresp.tid <= memreq.tid;
			  			memresp.fifo_wr <= TRUE;
				    	ret();
			      end
		    	end
	      default:
	        goto (DATA_ALIGN);
	      endcase
	    end
	  end

	DATA_ALIGN:
	  begin
	  	if (memreq.func==LOAD & ~dhit & dcachable & dce)
	  		goto (DFETCH2);
	  	else
	    	ret();
			memresp.step <= memreq.step;
	    memresp.cmt <= TRUE;
			memresp.tid <= memreq.tid;
			memresp.fifo_wr <= TRUE;
			sr_o <= LOW;
	    case(memreq.func)
	    LOAD:
	    	begin
		    	case(memreq.func2)
		    	LDB:	begin memresp.res <= {{56{datis[7]}},datis[7:0]}; end
		    	LDW:	begin memresp.res <= {{48{datis[15]}},datis[15:0]}; end
		    	LDT:	begin memresp.res <= {{32{datis[31]}},datis[31:0]}; end
		    	LDO:	begin memresp.res <= datis[63:0]; end
		    	LDOR:	begin memresp.res <= datis[63:0]; end
		    	LDBU:	begin memresp.res <= {56'd0,datis[7:0]}; end
		    	LDWU:	begin memresp.res <= {48'd0,datis[15:0]}; end
		    	LDTU:	begin memresp.res <= {32'd0,datis[31:0]}; end
		    	default:	;
		    	endcase
	    	end
	    default:  ;
	    endcase
	  end

	// Complete TLB access cycle
	TLB1:
		goto (TLB2);	// Give time for TLB to process
	TLB2:
		goto (TLB3);	// Give time for TLB to process
	TLB3:
		begin
			memresp.step <= memreq.step;
	    memresp.res <= tlbdato;
	    memresp.cmt <= TRUE;
			memresp.tid <= memreq.tid;
			memresp.fifo_wr <= TRUE;
	   	ret();
		end

	// Hardware subroutine to fetch instruction cache line
	IFETCH1:
	  if (!ack_i) begin
	  	// Cache miss, select an entry in the victim cache to
	  	// update.
			ivcnt <= ivcnt + 2'd1;
			if (ivcnt>=3'd4)
				ivcnt <= 3'd0;
			ivcache[ivcnt] <= ic_line;
			ivtag[ivcnt] <= ic_tag;
			ivvalid[ivcnt] <= TRUE;
		  iaccess <= TRUE;
	  	vpa_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;	// constant address burst cycle
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
	    adr_o <= {ip[AWID-1:6],6'h0};
  		goto (IFETCH2);
	  end
	IFETCH2:
	  begin
	  	stb_o <= HIGH;
	    if (ack_i) begin
	      ici <= {dat_i,ici[511:128]};	// shift in the data
	      icnt <= icnt + 4'd4;					// increment word count
	      if (icnt[3:2]==2'd3) begin		// Are we done?
	      	tBusDeactivate();
	      	iaccess <= FALSE;
	      	goto (IFETCH3);
	    	end
	    	if (!bok_i) begin							// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (IFETCH6);
	    	end
	    end
			//tPMAIP(); // must have adr_o valid for PMA
		end
	IFETCH3:
		begin
		  ic_wway <= waycnt;
			waycnt <= waycnt + 2'd1;
			ret();
		end

	IFETCH4:
		goto (IFETCH5);		// delay for block ram read
	IFETCH5:
		begin
			ici <= ivcache[vcn];
			ivcache[vcn] <= ic_line;
			ivtag[vcn] <= ic_tag;
			ivvalid[vcn] <= VAL;
			goto (IFETCH3);
		end

	IFETCH6:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (IFETCH2);
			end
		end

	DFETCH2:
	  begin
	    goto(DFETCH3);
	  end
	DFETCH3:
	  begin
	 		xlaten <= FALSE;
		  begin
	  		goto (DFETCH4);
	  		if (tlbmiss)
	  			tTLBMiss(adr_o);
			  // First time in, set to miss address, after that increment
	      dadr <= {adr_o[AWID-1:6],6'h0};
		  end
	  end

	// Initiate burst access
	DFETCH4:
	  if (!ack_i) begin
	  	vda_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;	// constant address burst cycle
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
	    goto (DFETCH5);
	  end

	// Sustain burst access
	DFETCH5:
	  begin
	  	daccess <= FALSE;
	  	stb_o <= HIGH;
	    if (ack_i) begin
	    	dcnt <= dcnt + 4'd4;
	      dci <= {dat_i,dci[639:128]};
	      if (dcnt[4:2]==3'd4) begin		// Are we done?
	      	tBusDeactivate();
	      	goto (DFETCH7);
	    	end
	    	if (!bok_i) begin							// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (DFETCH6);
	    	end
	    end
	  end
  
  // Increment address and bounce back for another read.
  DFETCH6:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (DFETCH5);
			end
		end

	// Trgger a data cache update. The data cache line is in dci. The only thing
	// left to do is update the tag and valid status.
	DFETCH7:
	  begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[12:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[12:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[12:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[12:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[12:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[12:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[12:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[12:6]] <= 1'b1;
    	endcase
    	ret();
	  end

	// Hardware subroutine to load keys.
`ifdef SUPPORT_KEYCHK
	KYLD:
	  begin
	    tEA(keytbl);
			goto (KYLD2);
	  end
	KYLD2:
		goto (KYLD3);

	KYLD3:
	  begin
	 		xlaten <= FALSE;
		  begin
	  		goto (KYLD4);
	  		if (tlbmiss)
	  			tTLBMiss(adr_o);
				else
				  // First time in, set to miss address, after that increment
				  daccess <= TRUE;
	      dadr <= {adr_o[AWID-1:5],5'h0};
		  end
	  end

	KYLD4:
	  if (!ack_i) begin
	  	vda_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
	    goto (KYLD5);
	  end

	KYLD5:
	  begin
	  	stb_o <= HIGH;
	    if (ack_i) begin
	    	dcnt <= dcnt + 4'd4;
	      dci <= {dat_i,dci[511:128]};
	      if (dcnt[4:2]==3'd3) begin		// Are we done?
	      	tBusDeactivate();
	      	goto (KYLD7);
	    	end
	    	if (!bok_i) begin							// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (KYLD6);
	    	end
	    end
	  end

	KYLD6:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (KYLD5);
			end
		end

	KYLD7:
	  begin
	  	kytag[dadr[11:6]] <= dadr[AWID-1:6];
	  	kyline[dadr[11:6]] <= dci;
	  	kyv[dadr[11:6]] <= 1'b1;
	  	ret();
	  end
`endif

	default:
		goto (MEMORY1);
	endcase
end

task tTLBMiss;
input Address ba;
begin
	memresp.step <= memreq.step;
	memresp.cmt <= TRUE;
  memresp.cause <= 16'h8004;
	memresp.tid <= memreq.tid;
  memresp.badAddr <= ba;
  memresp.fifo_wr <= TRUE;
	goto (MEMORY1);
end
endtask

task tEA;
input Address iea;
begin
  if (MUserMode && memreq.func==STORE && !ea_acr[1])
    memresp.cause <= 16'h8032;
  else if (MUserMode && memreq.func==LOAD && !ea_acr[2])
    memresp.cause <= 16'h8033;
	if (!MUserMode || iea[AWID-1:24]=={AWID-24{1'b1}})
		dadr <= iea;
	else
		dadr <= iea[AWID-5:0] + {sregfile[segsel][AWID-1:4],`SEG_SHIFT};
end
endtask

task tBusDeactivate;
begin
	vpa_o <= LOW;			//
	vda_o <= LOW;
	cti_o <= 3'b000;	// Normal cycles again
	cyc_o <= LOW;
	stb_o <= LOW;
	sel_o <= 16'h0000;
end
endtask

task goto;
input [5:0] nst;
begin
	state <= nst;
end
endtask

task gosub;
input [5:0] nst;
begin
	stk_state1 <= state;
	stk_state2 <= stk_state1;
	stk_state3 <= stk_state2;
	state <= nst;
end
endtask

task ret;
begin
	state <= stk_state1;
	stk_state1 <= stk_state2;
	stk_state2 <= stk_state3;
end
endtask

endmodule
