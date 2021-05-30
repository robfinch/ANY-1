// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1oo.sv
// ANY1 processor implementation with elastic pipeline.
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
`define SIM   1'b1
import any1_pkg::*;

module any1oo(rst_i, clk_i, wc_clk_i, nmi_i, irq_i, cause_i,
	vpa_o, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o, dat_i, dat_o, sr_o, cr_o, rb_i);
input rst_i;
input clk_i;
input wc_clk_i;
input nmi_i;
input irq_i;
input [7:0] cause_i;
output reg vpa_o;
output reg cyc_o;
output reg stb_o;
input ack_i;
output reg we_o;
output reg [15:0] sel_o;
output reg [AWID-1:0] adr_o;
input [127:0] dat_i;
output reg [127:0] dat_o;
output reg sr_o;		// set memory reservation
output reg cr_o;		// clear memory reservation
input rb_i;					// input memory still reserved bit

integer n,m;
genvar g;
wire clk_g;
wire acki = ack_i;


wire [2:0] omode;
wire [2:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode, DebugMode;
wire MUserMode;

Instruction ir;
sFuncUnit [3:0] funcUnit;
sInstAlignIn f2a_in, f2a_out;
sInstAlignOut a2d_in,a2d_out;
sDecode decbuf;
sExecute exbufi, exbufo;
sMemoryIO membufi;
sReorderEntry [ROB_ENTRIES-1:0] rob;
sALUrec mulreci,mulreco, divreci, divreco;
sFuncUnit memfu;
reg x2mul_wr,x2mul_rd;
wire x2mul_full,x2mul_empty;
reg mul_sign;
reg [63:0] mul_a;
reg [63:0] mul_b;
reg [127:0] mul_p;
reg [5:0] rob_que;
reg [5:0] rob_deq;
wire [5:0] rob_exec;
reg [5:0] mstate, mstk_state;			// memory state
reg [2:0] mul_state;	// multipler state
reg [2:0] div_state;
reg [63:0] csrro;

reg [63:0] regalloc;
reg [63:0] regalloc_hist[0:15];
reg [6:0] regmap [0:63];
reg [6:0] regmap_hist[0:15][0:63];

function [6:0] fnNextAllocReg;
input [5:0] Rt;
begin
	fnNextAllocReg = 7'd0;
	for (n = 0; n < 64; n = n + 1) begin
		if (regalloc[n]==1'b0) begin
			fnNextAllocReg = {1'b1,n[5:0]};
		end
	end
end
endfunction


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Multiply / Divide support logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg x2div_wr,x2div_rd;
wire x2div_full,x2div_empty;
wire div_done;
reg div_sign;
reg [63:0] div_a;
reg [63:0] div_b;

wire [128-1:0] div_q;
wire [128-1:0] ndiv_q = -div_q;
wire [63:0] div_r = div_a - (div_b * div_q[128-1:64]);
wire [63:0] ndiv_r = -div_r;
fpdivr16 #(64) u16 (
	.clk(clk_g),
	.ld(div_state==DIV3),
	.a(div_a),
	.b(div_b),
	.q(div_q),
	.r(),
	.done(div_done)
);


Address ip;											// Instruction pointer

Value regfile [0:127];
Rid regfilesrc [0:127];					// bit 7 = 0 = regfile, 1 = reorder buffer
Rid regfilesrc_hist [0:15][0:127];
reg [WID-1:0] sregfile [0:15];
wire restore_rfsrc;
Rid vregfilesrc [0:63];					// bit 7 = 0 = regfile, 1 = reorder buffer
Rid vregfilesrc_hist [0:15][0:63];

reg vrf_update;
reg [11:0] vrf_wa;
reg [63:0] vrf_din;
wire [63:0] vrfoA, vrfoB;
wire [11:0] vrf_raA = {decbuf.RaStep,decbuf.Ra[5:0]};
wire [11:0] vrf_raB = {decbuf.RbStep,decbuf.Rb[5:0]};

vec_regfile_blkmem uvrfA (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(vrf_update),      // input wire [0 : 0] wea
  .addra(vrf_wa),  // input wire [11 : 0] addra
  .dina(vrf_din),    // input wire [63 : 0] dina
  .douta(),  			// output wire [63 : 0] douta
  .clkb(~clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .web(1'b0),      // input wire [0 : 0] web
  .addrb(vrf_raA),  // input wire [11 : 0] addrb
  .dinb(64'd0),    // input wire [63 : 0] dinb
  .doutb(vrfoA)  // output wire [63 : 0] doutb
);

vec_regfile_blkmem uvrfB (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(vrf_update),      // input wire [0 : 0] wea
  .addra(vrf_wa),  // input wire [11 : 0] addra
  .dina(vrf_din),    // input wire [63 : 0] dina
  .douta(),  			// output wire [63 : 0] douta
  .clkb(~clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .web(1'b0),      // input wire [0 : 0] web
  .addrb(vrf_raB),  // input wire [11 : 0] addrb
  .dinb(64'd0),    // input wire [63 : 0] dinb
  .doutb(vrfoB)  // output wire [63 : 0] doutb
);

reg [5:0] ifStream,dcStream,rfStream,wbStream;	// Stream associated with instructions
wire [5:0] exStream;
reg [3:0] active_branch;
reg dc2if_redirect_rd;
Address dc_redirect_ip;
sRedirect dc_redirecti,ex_redirecti,wb_redirecti;
sRedirect dc_redirecto,ex_redirecto,wb_redirecto;
reg ex2if_redirect_rd,wb2if_redirect_rd;
reg dc2if_redirect_rd2,ex2if_redirect_rd2,wb2if_redirect_rd2;
reg dc2if_redirect_rd3,ex2if_redirect_rd3,wb2if_redirect_rd3;
wire dc2if_redirect_empty,ex2if_redirect_empty,wb2if_redirect_empty;

reg x2m_rd;
wire f2a_empty;
wire a2d_empty;
wire d2x_empty;
wire x2m_empty;
reg dc2if_wr,ex2if_wr,wb2if_wr;
reg exfifo_rd;
reg memfifo_wr;

//CSRs
reg [63:0] cr0;
wire bpe = cr0[32];
wire btben = cr0[33];
wire dce = cr0[30];
wire sple = cr0[35];
wire tag_mode = cr0[36];
reg [63:0] tick;
Address tvec [0:7];
reg [7:0] cause [0:7];
Address badaddr [0:7];
Address eip;
reg [31:0] pmStack;
Address dbad [0:3];
reg [63:0] dbcr;
reg [31:0] mtimecmp;
reg [31:0] status [0:7];
wire mprv = status[4][17];
wire uie = status[4][0];
wire sie = status[4][1];
wire hie = status[4][2];
wire mie = status[4][3];
wire die = status[4][4];
reg [7:0] ASID;
reg [63:0] sema;
Address keytbl;
reg [19:0] keys [0:7];
reg [7:0] vl;

sMemoryIO membufo;
wire d_cache = membufo.ir.r2.opcode==CACHE;
wire d_st = membufo.ir.r2.opcode==STx;
wire d_ld = membufo.ir.r2.opcode==LDx;

assign omode = pmStack[3:1];
assign DebugMode = omode==3'b100;
assign MachineMode = omode==3'b011;
assign HypervisorMode = omode==3'b010;
assign SupervisorMode = omode==3'b001;
assign UserMode = omode==3'b000;
assign memmode = mprv ? pmStack[7:5] : omode;
wire MMachineMode = memmode==3'b011;
assign MUserMode = memmode==3'b000;

reg shr_ma;
wire [7:0] selx;
any1_select ua1sel
(
	.ir(rob[membufo.rid].ir),
	.sel(selx)
);

wire [AWID-1:0] ea;
reg [7:0] ealow;
wire [3:0] segsel = ea[AWID-1:AWID-4];

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

function [5:0] fnIncNdx;
input [5:0] ndx;
begin
	if (ndx>=6'd15)
		ndx <= 6'd0;
	else
		ndx <= ndx + 2'd1;
end
endfunction

always @*
	funcUnit[FU_MEM] <= memfu;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire ex_takb;
any1_eval_branch ubev1
(
	.inst(rob[rob_exec].ir),
	.a(rob[rob_exec].ia),
	.b(rob[rob_exec].ib),
	.takb(ex_takb)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

any1_agen uagen
(
	.rst(rst_i),
	.clk(clk_g),
	.ir(rob[membufo.rid].ir),
	.ia(rob[membufo.rid].ia),
	.ib(rob[membufo.rid].ib),
	.ic(rob[membufo.rid].ic),
	.imm(rob[membufo.rid].imm),
	.ea(ea)
);

// Build an insert mask for data cache store operations.
wire [511:0] stmask;
reg [127:0] stmask1;
generate begin : gStMask
`ifdef CPU_B128
	for (g = 0; g < 16; g = g + 1)
		always @*
			stmask1[g*4+3:g*4] = sel_o[g] ? 8'h00 : 8'hFF;
assign stmask = stmask1 << {adr_o[5:4],7'd0};
`endif
`ifdef CPU_B64
	for (g = 0; g < 8; g = g + 1)
		always @*
			stmask1[g*4+3:g*4] = sel_o[g] ? 8'h00 : 8'hFF;
assign stmask = stmask1 << {adr_o[5:3],6'd0};
`endif
`ifdef CPU_B32
	for (g = 0; g < 4; g = g + 1)
		always @*
			stmask1[g*4+3:g*4] = sel_o[g] ? 8'h00 : 8'hFF;
assign stmask = stmask1 << {adr_o[5:2],5'd0};
`endif
end
endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Trace
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg wr_trace, rd_trace;
reg wr_whole_address;
reg [5:0] br_hcnt;
reg [5:0] br_rcnt;
reg [63:0] br_history;
wire [63:0] trace_dout;
wire trace_full;
wire trace_empty;
wire trace_valid;
reg tron;
wire [3:0] trace_match;
assign trace_match[0] = (dbad[0]==ip && dbcr[19:16]==4'b1000 && dbcr[32]);
assign trace_match[1] = (dbad[1]==ip && dbcr[23:20]==4'b1000 && dbcr[33]);
assign trace_match[2] = (dbad[2]==ip && dbcr[27:24]==4'b1000 && dbcr[34]);
assign trace_match[3] = (dbad[3]==ip && dbcr[31:28]==4'b1000 && dbcr[35]);
wire trace_on = 
  trace_match[0] ||
  trace_match[1] ||
  trace_match[2] ||
  trace_match[3]
  ;
wire trace_off = trace_full;
wire trace_compress = dbcr[36];

always @(posedge clk_g)
if (rst_i) begin
  wr_trace <= 1'b0;
  wr_whole_address <= TRUE;
  br_hcnt <= 6'd8;
  br_rcnt <= 6'd0;
  tron <= FALSE;
end
else begin
  if (trace_off)
    tron <= FALSE;
  else if (trace_on)
    tron <= TRUE;
  wr_trace <= 1'b0;
  if (tron) begin
    if (!trace_compress)
      wr_whole_address <= TRUE;
		if (rob[rob_deq].v & rob[rob_deq].cmt) begin
	    if (trace_compress) begin
	      if (rob[rob_deq].branch) begin
	        if (br_hcnt < 6'h3E) begin
	          br_history[br_hcnt] <= rob[rob_deq].takb;
	          br_hcnt <= br_hcnt + 2'd1;
	        end
	        else begin
	          br_rcnt <= br_rcnt + 2'd1;
	          br_history[7:0] <= {br_hcnt-4'd8,2'b01};
	          if (br_rcnt==6'd3) begin
	            br_rcnt <= 6'd0;
	            wr_whole_address <= 1'b1;
	          end
	          wr_trace <= 1'b1;
	          br_hcnt <= 6'd8;
	        end
	      end
	      else if (rob[rob_deq].jump) begin
	        br_history[7:0] <= {br_hcnt-4'd8,2'b01};
	        br_rcnt <= 6'd0;
	        wr_whole_address <= 1'b1;
	        wr_trace <= 1'b1;
	        br_hcnt <= 6'd8;
	      end
	    end
	    else begin
	      if (wr_whole_address) begin
	        wr_whole_address <= 1'b0;
	        br_history[63:0] <= {rob[rob_deq].ip[AWID-1:2],2'b00};//jump_tgt[AWID-1:3],3'b00};
	        wr_trace <= 1'b1;
	      end
	    end
	  end
  end
end

TraceFifo utf1 (
  .clk(clk_g),                // input wire clk
  .srst(rst_i),              // input wire srst
  .din(br_history),                // input wire [63 : 0] din
  .wr_en(wr_trace),            // input wire wr_en
  .rd_en(rd_trace),            // input wire rd_en
  .dout(trace_dout),              // output wire [63 : 0] dout
  .full(trace_full),              // output wire full
  .empty(trace_empty),            // output wire empty
  .valid(trace_valid),            // output wire valid
  .data_count()  // output wire [9 : 0] data_count
);

reg [AWID-1:0] iadr;
reg keyViolation = 1'b0;

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

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Branch target buffer.
//
// Access to the branch target buffer must be within one clock cycle, so it
// is composed of LUT ram.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [AWID-1:0] btb_predicted_ip;
BTBEntry btb [0:511];
initial begin
	for (n = 0; n < 512; n = n + 1) begin
		btb[n].addr <= 32'd0;
		btb[n].tag <= 1'd0;
	end
end
always @*
	if (btb[ip[11:3]].tag==ip[AWID-1:12] && btb[ip[11:3]].v)
		btb_predicted_ip <= btb[ip[11:3]].addr;
	else
		btb_predicted_ip <= ip + 4'd4;

always @(posedge clk_g)
if (rst_i) begin
	for (n = 0; n < 512; n = n + 1)
		btb[n].v <= INV;
end
else begin
	if (wb2if_redirect_rd2) begin
		btb[wb_redirecto.current_ip[11:3]].addr <= wb_redirecto.redirect_ip;
		btb[wb_redirecto.current_ip[11:3]].tag <= wb_redirecto.current_ip[AWID-1:12];
		btb[wb_redirecto.current_ip[11:3]].v <= VAL;
	end
	else if (ex2if_redirect_rd2) begin
		btb[ex_redirecto.current_ip[11:3]].addr <= ex_redirecto.redirect_ip;
		btb[ex_redirecto.current_ip[11:3]].tag <= ex_redirecto.current_ip[AWID-1:12];
		btb[ex_redirecto.current_ip[11:3]].v <= VAL;
	end
	else if (dc2if_redirect_rd2) begin
		btb[dc_redirecto.current_ip[11:3]].addr <= dc_redirecto.redirect_ip;
		btb[dc_redirecto.current_ip[11:3]].tag <= dc_redirecto.current_ip[AWID-1:12];
		btb[dc_redirecto.current_ip[11:3]].v <= VAL;
	end
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Branch Predictor
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire predict_taken;
gselectPredictor ubprd1
(
	.rst(rst_i),
	.clk(clk_g),
	.en(bpe),
	.xisBranch(rob[rob_deq].branch & rob[rob_deq].cmt & rob[rob_deq].v),
	.xip(rob[rob_deq].ip),
	.takb(rob[rob_deq].takb),
	.ip(ip),
	.predict_taken(predict_taken)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Data Cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg [1:0] waycnt;
reg daccess;
reg [2:0] dwait;		// wait state counter for dcache
reg [3:0] dcnt;
Address dadr;
reg [pL1LineSize-1:0] dci;
wire [pL1LineSize-1:0] dc_line;
reg [pL1LineSize-1:0] datil;
reg dcachable;
reg [1:0] dc_rway,dc_wway;
reg dcache_wr;
reg dc_invline,dc_invall;

dcache_blkmem your_instance_name (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(dcache_wr),      // input wire [0 : 0] wea
  .addra({dc_wway,dadr[11:6]}),  // input wire [8 : 0] addra
  .dina(dci),    // input wire [511 : 0] dina
  .clkb(clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({dc_rway,adr_o[11:6]}),  // input wire [8 : 0] addrb
  .doutb(dc_line)  // output wire [511 : 0] doutb
);
/*
dcache_mem udcm1 (
  .a({dc_wway,dadr[pL1msb:6]}),        // input wire [5 : 0] a
  .d(dci),        // input wire [511 : 0] d
  .dpra({dc_rway,adr_o[pL1msb:6]}),  // input wire [5 : 0] dpra
  .clk(clk),    // input wire clk
  .we(dcache_wr),      // input wire we
  .dpo(dc_line)    // output wire [511 : 0] dpo
);
*/
reg [AWID-7:0] dctag0 [0:63];
reg [AWID-7:0] dctag1 [0:63];
reg [AWID-7:0] dctag2 [0:63];
reg [AWID-7:0] dctag3 [0:63];
reg [pL1CacheLines-1:0] dcvalid0;
reg [pL1CacheLines-1:0] dcvalid1;
reg [pL1CacheLines-1:0] dcvalid2;
reg [pL1CacheLines-1:0] dcvalid3;
reg dc_invline;
reg dhit1a;
reg dhit1b;
reg dhit1c;
reg dhit1d;
always @*	//(posedge clk_g)
  dhit1a <= dctag0[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid0[adr_o[pL1msb:6]];
always @*	//(posedge clk_g)
  dhit1b <= dctag1[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid1[adr_o[pL1msb:6]];
always @*	//(posedge clk_g)
  dhit1c <= dctag2[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid2[adr_o[pL1msb:6]];
always @*	//(posedge clk_g)
  dhit1d <= dctag3[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid3[adr_o[pL1msb:6]];
wire dhit = dhit1a|dhit1b|dhit1c|dhit1d;
initial begin
  dcvalid0 = {pL1CacheLines{1'd0}};
  dcvalid1 = {pL1CacheLines{1'd0}};
  dcvalid2 = {pL1CacheLines{1'd0}};
  dcvalid3 = {pL1CacheLines{1'd0}};
  for (n = 0; n < pL1CacheLines; n = n + 1) begin
    dctag0[n] = 32'd1;
    dctag1[n] = 32'd1;
    dctag2[n] = 32'd1;
    dctag3[n] = 32'd1;
  end
end

always @*
begin
  case(1'b1)
  dhit1a: dc_rway <= 2'b00;
  dhit1b: dc_rway <= 2'b01;
  dhit1c: dc_rway <= 2'b10;
  dhit1d: dc_rway <= 2'b11;
  default:  dc_rway <= 2'b00;
  endcase
end

// ToDo:
// Add data cache invalidate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire ifStall;
reg ic_update;
wire [16:0] lfsr_o;
reg [1:0] ic_rway,ic_wway;
wire icache_wr;
reg ic_invline,ic_invall;

lfsr ulfsr1
(
	.rst(rst_i),
	.clk(clk_g),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

reg iaccess;
reg [3:0] icnt;
reg [pL1LineSize-1:0] ici;
reg [pL1LineSize-1:0] iri;
wire [pL1LineSize-1:0] ic_line;
wire [31:0] ic_inst;
reg [AWID-7:0] ic_tag;
//reg [pL1LineSize-1:0] icache [0:3] [0:pL1CacheLines-1];
/*
icache_mem uicm1 (
  .a({waycnt,iadr[pL1msb:6]}),        // input wire [5 : 0] a
  .d(ici),        // input wire [511 : 0] d
  .dpra({ic_rway,ip[pL1msb:6]}),  // input wire [5 : 0] dpra
  .clk(clk_g),    // input wire clk
  .we(icache_wr),      // input wire we
  .dpo(ic_line)    // output wire [511 : 0] dpo
);
*/
icache_blkmemA uicmA (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(icache_wr),      // input wire [0 : 0] wea
  .addra({waycnt,iadr[12:6]}),  // input wire [8 : 0] addra
  .dina(ici),    // input wire [511 : 0] dina
  .clkb(clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({ic_rway,ip[12:6]}),  // input wire [8 : 0] addrb
  .doutb(ic_line)  // output wire [511 : 0] doutb
);
icache_blkmemB uicmB (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(icache_wr),      // input wire [0 : 0] wea
  .addra({waycnt,iadr[12:6]}),  // input wire [8 : 0] addra
  .dina(ici),    // input wire [511 : 0] dina
  .clkb(clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({ic_rway,ip[12:2]}),  // input wire [12 : 0] addrb
  .doutb(ic_inst)  // output wire [31 : 0] doutb
);

reg [AWID-7:0] ictag [0:3] [0:pL1ICacheLines-1];
reg [pL1ICacheLines-1:0] icvalid [0:3];
reg ihit = 1'b0;
reg ihit1a;
reg ihit1b;
reg ihit1c;
reg ihit1d;
always @(posedge clk_g)
begin
  ihit1a = ictag[0][ip[12:6]]==ip[AWID-1:6] && icvalid[0][ip[12:6]]==TRUE;
  ihit1b = ictag[1][ip[12:6]]==ip[AWID-1:6] && icvalid[1][ip[12:6]]==TRUE;
  ihit1c = ictag[2][ip[12:6]]==ip[AWID-1:6] && icvalid[2][ip[12:6]]==TRUE;
  ihit1d = ictag[3][ip[12:6]]==ip[AWID-1:6] && icvalid[3][ip[12:6]]==TRUE;
	ihit = ihit1a|ihit1b|ihit1c|ihit1d;
end

initial begin
	for (n = 0; n < pL1ICacheLines; n = n + 1) begin
		icvalid[0][n] = 1'b1;
		icvalid[1][n] = 1'b1;
		icvalid[2][n] = 1'b1;
		icvalid[3][n] = 1'b1;
	end
  for (n = 0; n < pL1ICacheLines; n = n + 1) begin
    ictag[0][n] = 32'd1;
    ictag[1][n] = 32'd1;
    ictag[2][n] = 32'd1;
    ictag[3][n] = 32'd1;
  end
end

always @*
begin
  case(1'b1)
  ihit1a: ic_rway <= 2'b00;
  ihit1b: ic_rway <= 2'b01;
  ihit1c: ic_rway <= 2'b10;
  ihit1d: ic_rway <= 2'b11;
  default:  ic_rway <= 2'b00;
  endcase
end

// For victim cache update
always @*
begin
  case(1'b1)
  ihit1a: ic_tag <= ictag[0][ip[12:6]];
  ihit1b: ic_tag <= ictag[1][ip[12:6]];
  ihit1c: ic_tag <= ictag[2][ip[12:6]];
  ihit1d: ic_tag <= ictag[3][ip[12:6]];
  default:  ic_tag <= 32'd1;
  endcase
end

always @(posedge clk_g)
if (rst_i) begin

	for (n = 0; n < pL1ICacheLines; n = n + 1) begin
		icvalid[0][n] <= 1'b0;
		icvalid[1][n] <= 1'b0;
		icvalid[2][n] <= 1'b0;
		icvalid[3][n] <= 1'b0;
	end

end
else begin
	if (icache_wr)
		icvalid[waycnt][iadr[12:6]] <= 1'b1;
	// Cache line invalidate
	// Use physical address
	// ToDo: Check for tag match
	else if (mstate==MEMORY4) begin
		if (ic_invline) begin
			icvalid[0][adr_o[12:6]] <= 1'b0;
			icvalid[1][adr_o[12:6]] <= 1'b0;
			icvalid[2][adr_o[12:6]] <= 1'b0;
			icvalid[3][adr_o[12:6]] <= 1'b0;
		end
		else if (ic_invall) begin
			for (n = 0; n < pL1ICacheLines; n = n + 1) begin
				icvalid[0][n] <= 1'b0;
				icvalid[1][n] <= 1'b0;
				icvalid[2][n] <= 1'b0;
				icvalid[3][n] <= 1'b0;
			end
		end
	end
end

//always @(posedge clk_g)
//	if (ic_update)
		//tLICache(lfsr_o[1:0],iadr[AWID-1:6],ici,1'b1);


reg [2:0] ivcnt;
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
always @*
	kyhit <= kytag[adr_o[23:18]]==adr_o[AWID-1:18] && kyv[adr_o[23:18]];
initial begin
	kyv = 64'd0;
	for (n = 0; n < 64; n = n + 1) begin
		kyline[n] <= 512'd0;
		kytag[n] <= 32'd1;
	end
end
wire [19:0] kyut = kyline[adr_o[23:18]] >> {adr_o[17:14],5'd0};
`endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// TLB
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg xlaten;
reg tlben, tlbwr;
wire tlbmiss;
wire [3:0] tlbacr;
wire [63:0] tlbdato;
reg [63:0] tlb_ia, tlb_ib;

any1_TLB utlb (
  .rst_i(rst_i),
  .clk_i(clk_g),
  .asid_i(ASID),
  .umode_i(vpa_o ? UserMode : MUserMode),
  .xlaten_i(xlaten),
  .we_i(we_o),
  .ladr_i(dadr),
  .iacc_i(iaccess),
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
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg ifStall1,ifStall2;
reg [5:0] decven;
wire f2a_full, f2a_v;
wire a2d_full, a2d_v;
wire d2r_full, d2r_v;
wire d2x_full, d2x_v;
wire x2m_full, x2m_v;
wire d2x_underflow;
//wire ifStall = f2a_full || !ihit;
assign ifStall = a2d_full || !ihit;
reg dcStall,dcStall1,vecStall;
reg push_vec;
wire f2a_rst,a2d_rst,d2x_rst;
reg wb_f2a_rst,wb_a2d_rst,wb_d2x_rst;

reg pop_f2ad,pop_a2dd,pop_d2xd;
wire push_f2a = !ifStall && !f2a_full;// && rob_que+2'd1 != rob_deq;
wire pop_f2a = !a2d_full && !f2a_empty;

wire push_a2d = !a2d_full && !ifStall2; //pop_f2ad;
wire pop_a2d = !d2x_full && !a2d_empty && !dcStall && !vecStall;
wire push_d2x = (!d2x_full && pop_a2dd && !dcStall && rob[rob_que].v!=VAL) || (dcStall1 && !dcStall) || push_vec;
wire pop_d2x = !x2m_full && !x2mul_full && !x2div_full && !d2x_empty;

always @*
	push_vec <= decbuf.is_vec && !decbuf.vex && decven < vl && !d2x_full;
always @*
	vecStall <= decbuf.is_vec && !decbuf.vex && decven < vl && !d2x_full;

always @(posedge clk_g)
	ifStall1 <= ifStall;
always @(posedge clk_g)
	ifStall2 <= ifStall1;

always @(posedge clk_g)
	dcStall1 <= dcStall;
always @(posedge clk_g)
	pop_f2ad <= pop_f2a;
always @(posedge clk_g)
	pop_a2dd <= pop_a2d || (dcStall1 && !dcStall);
always @(posedge clk_g)
	pop_d2xd <= pop_d2x;

// Instruction fetch
always @(posedge clk_g)
begin
	f2a_in.Stream <= ifStream;
	f2a_in.ip <= ip;
	f2a_in.pip <= btb_predicted_ip;
	f2a_in.predict_taken <= predict_taken;
//  if (ihit)
//  	f2a_in.cacheline <= ic_line;
// 	else
// 		f2a_in.cacheline <= {16{NOP_INSN}};
end

always @(posedge clk_g)
begin
	a2d_in.Stream <= f2a_in.Stream;
	a2d_in.predict_taken <= f2a_in.predict_taken;
	if (|f2a_in.ip[1:0])
  	a2d_in.ir <= {8'h0,FLT_IADR,16'h0};		// instruction alignment fault
  else
		a2d_in.ir <= ic_inst;
	a2d_in.ip <= f2a_in.ip;
	a2d_in.pip <= f2a_in.pip;
end

/*
f2a_fifo uf2a
(
  .clk(clk_g),      // input wire clk
  .srst(f2a_rst|wb_f2a_rst),    // input wire srst
  .din(f2a_in),//{if_rid,ip,iri}),      // input wire [511 : 0] din
  .wr_en(push_f2a),  // input wire wr_en
  .rd_en(pop_f2a),  // input wire rd_en
  .dout(f2a_out),    // output wire [511 : 0] dout
  .full(f2a_full),    // output wire full
  .empty(f2a_empty),  		// output wire empty
  .valid(f2a_v)  // output wire valid
);

// Instruction align combo logic
any1_ialign uia1
(
	.i(f2a_out),
	.o(a2d_in)
);
*/

a2d_fifo ua2d
(
  .clk(clk_g),      // input wire clk
  .srst(a2d_rst|wb_a2d_rst),    // input wire srst
  .din(a2d_in),      // input wire [95 : 0] din
  .wr_en(push_a2d),	// input wire wr_en
  .rd_en(pop_a2d),  // input wire rd_en
  .dout(a2d_out),    // output wire [95 : 0] dout
  .full(a2d_full),    // output wire full
  .empty(a2d_empty),  		// output wire empty
  .valid(a2d_v)  // output wire valid
);

any1_decode udec1
(
	.a2d_out(a2d_out),
	.decbuf(decbuf),
	.predicted_ip(btb_predicted_ip)
);


// Store operations use Rc.
function regValid;
input [7:0] rg;
begin
	regValid = 	rg[5:0]==6'd0 ||
							rg[5:0]==6'd63 ||
							regfilesrc[regmap[rg[5:0]]].rf == 1'd0 ||
							rob[regfilesrc[regmap[rg[5:0]]].rid].cmt
							;
end
endfunction

always @*
begin
	exbufi.iav <= decbuf.Ravec ? (decbuf.Ra[5:0]==6'd0 || vregfilesrc[decbuf.Ra[5:0]].rf==1'b0) : regValid(decbuf.Ra);
	exbufi.ibv <= decbuf.Rbvec ? (decbuf.Rb[5:0]==6'd0 || vregfilesrc[decbuf.Ra[5:0]].rf==1'b0) : regValid(decbuf.Rb);
	exbufi.icv <= regValid(decbuf.Rc) || !decbuf.needRc;
	// To detect WAW hazard
	exbufi.itv <= 1'b1;//regValid(decbuf.Rt);
end

function [63:0] fnWidenAddress;
input Address rAddr;
begin
	fnWidenAddress = {{32{rAddr[31]}},rAddr};
end
endfunction

always @*
begin
	exbufi.Stream <= decbuf.Stream;
	exbufi.Stream_inc <= decbuf.Stream_inc;
	exbufi.ip <= decbuf.ip;
	exbufi.pip <= decbuf.pip;
	exbufi.predict_taken <= decbuf.predict_taken;
	exbufi.branch <= decbuf.branch;
	exbufi.ir <= decbuf.ir;
	exbufi.rfwr <= decbuf.rfwr;
	if (decbuf.Ravec)
		exbufi.ia.val <= decbuf.Ra[5:0]==6'd0 ? 64'd0 : vregfilesrc[decbuf.Ra[5:0]].rf==1'b0 ? vrfoA : 64'hDEADEADDEADDEAD;
	else
		exbufi.ia.val <= decbuf.Ra[5:0]==6'd0 ? 64'd0 : decbuf.Ra[5:0]==6'd63 ? decbuf.ip : regfilesrc[regmap[decbuf.Ra[5:0]]].rf ? rob[regfilesrc[regmap[decbuf.Ra[5:0]]].rid].res.val : regfile[regmap[decbuf.Ra]].val;
	if (decbuf.Rbvec)
		exbufi.ib.val <= decbuf.Rb[5:0]==6'd0 ? 64'd0 : vregfilesrc[decbuf.Rb[5:0]].rf==1'b0 ? vrfoB : 64'hDEADEADDEADDEAD;
	else
		exbufi.ib.val <= decbuf.Rb[5:0]==6'd0 ? 64'd0 : decbuf.Rb[5:0]==6'd63 ? decbuf.ip : regfilesrc[regmap[decbuf.Rb[5:0]]].rf ? rob[regfilesrc[regmap[decbuf.Rb[5:0]]].rid].res.val : regfile[regmap[decbuf.Rb]].val;
	if (decbuf.needRc)
		exbufi.ic.val <= decbuf.Rc[5:0]==6'd0 ? 64'd0 : decbuf.Rc[5:0]==6'd63 ? decbuf.ip : regfilesrc[regmap[decbuf.Rc[5:0]]].rf ? rob[regfilesrc[regmap[decbuf.Rc[5:0]]].rid].res.val : regfile[regmap[decbuf.Rc]].val;
	else
		exbufi.ic.val <= 64'd0;
	exbufi.imm <= decbuf.imm;
//	dcStall <=  !(exbufi.iav & exbufi.ibv & exbufi.icv & exbufi.idv & exbufi.itv);
	dcStall <= !exbufi.itv;
//	dcStall <= 1'b0;
end

d2x_fifo ud2x
(
  .clk(clk_g),      // input wire clk
  .srst(d2x_rst|wb_d2x_rst),    // input wire srst
  .din(exbufi),      // input wire [134 : 0] din
  .wr_en(push_d2x),	// input wire wr_en
  .rd_en(pop_d2x),  // input wire rd_en
  .dout(exbufo),    // output wire [134 : 0] dout
  .full(d2x_full),    // output wire full
  .empty(d2x_empty),  		// output wire empty
  .underflow(d2x_underflow),
  .valid(d2x_v)  // output wire valid
);

x2m_fifo ux2m
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(membufi),      // input wire [134 : 0] din
  .wr_en(!x2m_full && membufi.wr),	// input wire wr_en
  .rd_en(x2m_rd),  // input wire rd_en
  .dout(membufo),    // output wire [134 : 0] dout
  .full(x2m_full),    // output wire full
  .empty(x2m_empty),  		// output wire empty
  .valid(x2m_v)  // output wire valid
);

ALU_fifo ux2mul
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(mulreci),      // input wire [134 : 0] din
  .wr_en(!x2mul_full && mulreci.wr),	// input wire wr_en
  .rd_en(x2mul_rd),  // input wire rd_en
  .dout(mulreco),    // output wire [134 : 0] dout
  .full(x2mul_full),    // output wire full
  .empty(x2mul_empty)  		// output wire empty
);

ALU_fifo ux2div
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(divreci),      // input wire [134 : 0] din
  .wr_en(!x2div_full && divreci.wr),	// input wire wr_en
  .rd_en(x2div_rd),  // input wire rd_en
  .dout(divreco),    // output wire [134 : 0] dout
  .full(x2div_full),    // output wire full
  .empty(x2div_empty)  		// output wire empty
);

if_redirect_fifo udc2if
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(dc_redirecti),      // input wire [31 : 0] din
  .wr_en(dc2if_wr),	// input wire wr_en
  .rd_en(dc2if_redirect_rd),  // input wire rd_en
  .dout(dc_redirecto),    // output wire [31 : 0] dout
  .full(),    	// output wire full
  .empty(dc2if_redirect_empty),  		// output wire empty
  .valid()  // output wire valid
);

if_redirect_fifo uex2if
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(ex_redirecti),      // input wire [31 : 0] din
  .wr_en(ex_redirecti.wr),	// input wire wr_en
  .rd_en(ex2if_redirect_rd),  // input wire rd_en
  .dout(ex_redirecto),    // output wire [31 : 0] dout
  .full(),    	// output wire full
  .empty(ex2if_redirect_empty),  		// output wire empty
  .valid()  // output wire valid
);

if_redirect_fifo uwb2if
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(wb_redirecti),      // input wire [31 : 0] din
  .wr_en(wb2if_wr),	// input wire wr_en
  .rd_en(wb2if_redirect_rd),  // input wire rd_en
  .dout(wb_redirecto),    // output wire [31 : 0] dout
  .full(),    	// output wire full
  .empty(wb2if_redirect_empty),  		// output wire empty
  .valid()  // output wire valid
);

sReorderEntry robo,robo1;
wire brAddrMispredict = exbufi.pip != ex_redirecti.redirect_ip;//exRedirectIp;
wire rst_exStream = push_f2a ? (wb2if_redirect_rd3|ex2if_redirect_rd3|dc2if_redirect_rd3) : 1'b0;


any1_execute uex1(
	.rst(rst_i),
	.clk(clk_g),
	.robi(rob[rob_exec]),
	.robo(robo),
	.mulreci(mulreci),
	.divreci(divreci),
	.membufi(membufi),
	.rob_exec(rob_exec),
	.Stream_inc(rob[rob_exec].Stream_inc),
	.ex_redirect(ex_redirecti),
	.f2a_rst(f2a_rst),
	.a2d_rst(a2d_rst),
	.d2x_rst(d2x_rst),
	.ex_takb(ex_takb),
	.csrro(csrro),
	.irq_i(irq_i),		// For PFI instruction
	.cause_i(cause_i),
	.brAddrMispredict(brAddrMispredict),
	.ifStream(ifStream),
	.exStream(exStream),
	.rst_exStream(rst_exStream),
	.restore_rfsrc(restore_rfsrc),
	.vregfilesrc(vregfilesrc),
	.vl(vl)
);

reg zero_data;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Timers
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always @(posedge clk_g)
if (rst_i)
	tick <= 64'd0;
else
	tick <= tick + 2'd1;

reg [5:0] ld_time;
reg wc_time_irq;
reg [5:0] wc_time_irq_clr;
reg [63:0] wc_time_dat;
reg [63:0] wc_time;
wire clr_wc_time_irq = wc_time_irq_clr[5];
always @(posedge wc_clk_i)
if (rst_i) begin
	wc_time <= 1'd0;
	wc_time_irq <= 1'b0;
end
else begin
	if (|ld_time)
		wc_time <= wc_time_dat;
	else begin
		wc_time[31:0] <= wc_time[31:0] + 2'd1;
		if (wc_time[31:0]==32'd99999999) begin
			wc_time[31:0] <= 32'd0;
			wc_time[63:32] <= wc_time[63:32] + 2'd1;
		end
	end
	if (mtimecmp==wc_time[31:0])
		wc_time_irq <= 1'b1;
	if (clr_wc_time_irq)
		wc_time_irq <= 1'b0;
end

wire pe_nmi;
reg nmif;
edge_det u17 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(nmi_i), .pe(pe_nmi), .ne(), .ee() );

reg wfi;
reg set_wfi = 1'b0;
always @(posedge wc_clk_i)
if (rst_i)
	wfi <= 1'b0;
else begin
	if (irq_i|pe_nmi)
		wfi <= 1'b0;
	else if (set_wfi)
		wfi <= 1'b1;
end

BUFGCE u11 (.CE(!wfi), .I(clk_i), .O(clk_g));
//assign clk_g = clk_i;

wire [3:0] ea_acr = sregfile[segsel][3:0];
wire [3:0] pc_acr = sregfile[ip[AWID-1:AWID-4]][3:0];

assign icache_wr = mstate==IFETCH5 && icnt[3:2]==2'd3 && ~ack_i;

reg [63:0] exi;
reg exilo, eximid, exihi, has_exi;
Address exi_ip;
reg imod,brmod;
Address imod_ip;
Value regc, regd;
Instruction imod_inst;
reg regcv,regdv;
reg [5:0] regcsrc,regdsrc;
reg [5:0] br_Rt;

always @*
	tReadCSR(csrro,rob[rob_exec].imm[15:0]);

always @(posedge clk_g)
if (rst_i) begin
	ip <= RSTIP;
	nmif <= 1'b0;
	wb_f2a_rst <= TRUE;
	wb_a2d_rst <= TRUE;
	wb_d2x_rst <= TRUE;
	pmStack <= 12'b001001001000;
	ifStream <= 6'd0;
	dcStream <= 6'd0;
	rfStream <= 6'd0;
	wbStream <= 6'd0;
	zero_data <= FALSE;
	dcachable <= TRUE;
	ivvalid <= 5'h00;
	ivcnt <= 3'd0;
	for (n = 0; n < 5; n = n + 1) begin
		ivtag[n] <= 32'd1;
		ivcache[n] <= {8{NOP_INSN}};
	end
	rob_deq <= 6'd0;
	rob_que <= 6'd0;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		rob[n].Stream <= 6'd0;
		rob[n].Stream_inc <= FALSE;
		rob[n].v <= INV;
		rob[n].cmt <= FALSE;
		rob[n].cmt2 <= FALSE;
		rob[n].dec <= FALSE;
		rob[n].rfwr <= FALSE;
		rob[n].ui <= FALSE;	// ***
		rob[n].ip <= RSTIP;
		rob[n].ir <= NOP_INSN;
		rob[n].jump <= FALSE;
		rob[n].branch <= FALSE;
		rob[n].predict_taken <= FALSE;
		rob[n].cause <= FLT_NONE;
		rob[n].ia.val <= 64'd0;
		rob[n].ib.val <= 64'd0;
		rob[n].ic.val <= 64'd0;
		rob[n].id.val <= 64'd0;
		rob[n].imm <= 64'd0;
		rob[n].iav <= FALSE;
		rob[n].ibv <= FALSE;
		rob[n].icv <= FALSE;
		rob[n].idv <= FALSE;
		rob[n].itv <= FALSE;
		rob[n].ias <= 1'b0;
		rob[n].ibs <= 1'b0;
		rob[n].ics <= 1'b0;
		rob[n].ids <= 1'b0;
		rob[n].its <= 1'b0;
		rob[n].res.val <= 64'd0;
		rob[n].Rt <= 8'h00;
	end
	mstate <= MEMORY1;
	mstk_state <= MEMORY1;
	mul_state <= MUL1;
	div_state <= DIV1;
	ld_time <= FALSE;
	shr_ma <= FALSE;
	status[4] <= 64'h0;
	status[3] <= 64'd0;
	status[2] <= 64'd0;
	status[1] <= 64'd0;
	status[0] <= 64'd0;
	for (n = 0; n < 64; n = n + 1)
		regfile[n] <= 64'd0;
	for (n = 0; n < 16; n = n + 1)
		sregfile[n] <= 64'd0;
	for (n = 0; n < 16; n = n + 1)
		tZeroRegfileSrc(n);
	active_branch <= 2'd0;
	tlben <= TRUE;
	iadr <= RSTIP;
	dadr <= RSTIP;	// prevents TLB miss at startup
	dc_redirecti.redirect_ip <= 32'd0;
	dc_redirecti.current_ip <= 32'd0;
	dc_redirecti.wr <= FALSE;
	wb_redirecti.redirect_ip <= 32'd0;
	wb_redirecti.current_ip <= 32'd0;
	wb_redirecti.wr <= FALSE;
	dc2if_redirect_rd3 <= FALSE;
	ex2if_redirect_rd3 <= FALSE;
	wb2if_redirect_rd3 <= FALSE;
	cr0 <= 64'h940000000;		// enable branch predictor, data cache
	vpa_o <= LOW;
	cyc_o <= LOW;
	stb_o <= LOW;
	sel_o <= 16'h0;
	we_o <= LOW;
	dat_o <= 128'd0;
	sr_o <= LOW;
	cr_o <= LOW;
	keytbl <= 32'h00020000;
	for (n = 0; n < 8; n = n + 1)
		keys[n] <= 20'd0;
	vl <= 8'd4;
	exihi <= FALSE;
	eximid <= FALSE;
	exilo <= FALSE;
	imod <= FALSE;
	brmod <= FALSE;
	has_exi <= FALSE;
	waycnt <= 2'd0;
	ic_wway <= 2'b00;
	dcache_wr <= FALSE;
	dwait <= 3'd0;
	imod_inst <= NOP_INSN;
	regc <= 64'd0;
	regd <= 64'd0;
	regcv <= INV;
	regdv <= INV;
	for (n = 0; n < 64; n = n + 1)
		regmap[n] <= {1'b0,n[5:0]};
	memfu.cmt <= FALSE;
	vrf_update <= FALSE;
end
else begin
	ic_update <= 1'b0;
	ex2if_redirect_rd <= FALSE;
	dc2if_redirect_rd <= FALSE;
	wb2if_redirect_rd <= FALSE;
	if (dc2if_redirect_rd)
		dc2if_redirect_rd3 <= TRUE;
	if (ex2if_redirect_rd)
		ex2if_redirect_rd3 <= TRUE;
	if (wb2if_redirect_rd)
		wb2if_redirect_rd3 <= TRUE;
	dc2if_redirect_rd2 <= dc2if_redirect_rd;
	ex2if_redirect_rd2 <= ex2if_redirect_rd;
	wb2if_redirect_rd2 <= wb2if_redirect_rd;
	dc2if_wr <= FALSE;
	ex2if_wr <= FALSE;
	wb2if_wr <= FALSE;
	exfifo_rd <= FALSE;
	memfifo_wr <= FALSE;
	wb_f2a_rst <= FALSE;
	wb_a2d_rst <= FALSE;
	wb_d2x_rst <= FALSE;
	x2m_rd <= FALSE;
	x2mul_rd <= FALSE;
	x2mul_wr <= FALSE;
	x2div_rd <= FALSE;
	x2div_wr <= FALSE;
	dcache_wr <= FALSE;
	if (ld_time==TRUE && wc_time_dat==wc_time)
		ld_time <= FALSE;
	if (pe_nmi)
		nmif <= 1'b1;
	tlbwr <= FALSE;

	if (pop_a2d)
		decven <= 6'd0;
	else if (push_vec)
		decven <= decven + 6'd1;
	vrf_update <= FALSE;

	waycnt <= waycnt + 2'd1;

	// Instruction fetch
	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("Instruction fetch");
	$display("ip: %h", f2a_in.ip);
	$display("I$ line: %h", f2a_in.cacheline);

	if (!wb2if_redirect_empty)
		wb2if_redirect_rd <= 1'b1;
	else if (!ex2if_redirect_empty)
		ex2if_redirect_rd <= 1'b1;
	else if (!dc2if_redirect_empty)
		dc2if_redirect_rd <= 1'b1;

//	if (push_f2a) begin
	if (!ifStall) begin
		if (wb2if_redirect_rd3) begin
			wb2if_redirect_rd3 <= FALSE;
			ex2if_redirect_rd3 <= FALSE;
			dc2if_redirect_rd3 <= FALSE;
			ifStream <= ifStream + 2'd1;
			dcStream <= ifStream + 2'd1;
			wbStream <= ifStream + 2'd1;
			ip <= wb_redirecto.redirect_ip;
		end
		else if (ex2if_redirect_rd3) begin
			ex2if_redirect_rd3 <= FALSE;
			dc2if_redirect_rd3 <= FALSE;
			ifStream <= ifStream + 2'd1;
			dcStream <= ifStream + 2'd1;
			wbStream <= ifStream + 2'd1;
			ip <= ex_redirecto.redirect_ip;
		end
		else if (dc2if_redirect_rd3) begin
			dc2if_redirect_rd3 <= FALSE;
			ifStream <= ifStream + 2'd1;
			dcStream <= ifStream + 2'd1;
			wbStream <= ifStream + 2'd1;
			ip <= dc_redirecto.redirect_ip;
		end
		else if (predict_taken & btben)
			ip <= btb_predicted_ip;
		else
			ip <= ip + 4'd4;
	end

	$display("Instruction Fetch");
	$display("out: ip: %h  cacheline=%h", f2a_out.ip, f2a_out.cacheline);

	// Instruction Align
	// All work done with combo logic above.
	$display("Instruction Align");
	$display("in:  ip: %h  ir:%h", a2d_in.ip, a2d_in.ir);
	$display("out: ip: %h  ir:%h", a2d_out.ip, a2d_out.ir);
//	if (pop_f2ad)
//		rob[a2d_in.rid].ir <= a2d_in.ir;
//	if (pop_a2d)
//		rob[a2d_out.rid].ir <= a2d_out.ir;

	// Decode
	// Mostly done by combo logic above.
	// If it's a branch create a history record of the register file sources.
	$display("Decode");
  $display ("--------------------------------------------------------------------- Regfile ---------------------------------------------------------------------");
	for (n=0; n < 64; n=n+4) begin
	    $display("%d: %h %h   %d: %h %h   %d: %h %h   %d: %h %h#",
	       n[5:0]+0, regfile[{n[5:2],2'b00}], regfilesrc[n+0],
	       n[5:0]+1, regfile[{n[5:2],2'b01}], regfilesrc[n+1],
	       n[5:0]+2, regfile[{n[5:2],2'b10}], regfilesrc[n+2],
	       n[5:0]+3, regfile[{n[5:2],2'b11}], regfilesrc[n+3]
	       );
	end

	// Assign reorder buffer and initialize buffer.

	if (push_d2x) begin
		if (decbuf.rfwr)
			tAllocReg(decbuf.Rt,rob[rob_que].pRt);
		rob[rob_que].Stream <= decbuf.Stream;
		rob[rob_que].Stream_inc <= 1'b0;
		rob[rob_que].v <= VAL;
		rob[rob_que].predict_taken <= exbufi.predict_taken;
		rob[rob_que].ui <= decbuf.ui;
		rob[rob_que].ip <= decbuf.ip;
		rob[rob_que].ir <= decbuf.ir;
		rob[rob_que].irmod <= 32'd0;
		rob[rob_que].Rt <= decbuf.Rt;
		rob[rob_que].ia <= exbufi.ia;
		rob[rob_que].ib <= exbufi.ib;
		rob[rob_que].ia_ele <= decven;
		rob[rob_que].ib_ele <= decven;
		if (exbufi.branch)
			rob[rob_que].ic <= exbufi.ip;
		else if (decbuf.needRc)
			rob[rob_que].ic <= exbufi.ic;
		else
			rob[rob_que].ic <= 64'd0;
		rob[rob_que].id <= 64'd0;
		rob[rob_que].imm <= exbufi.imm;
		rob[rob_que].iav <= exbufi.iav;
		rob[rob_que].ibv <= exbufi.ibv;
		rob[rob_que].icv <= TRUE;
		rob[rob_que].idv <= TRUE;
		rob[rob_que].itv <= exbufi.itv;
		if (decbuf.Ravec)
			rob[rob_que].ias <= vregfilesrc[decbuf.Ra[5:0]];
		else
			rob[rob_que].ias <= regfilesrc[regmap[decbuf.Ra[5:0]]];
		rob[rob_que].step_v <= TRUE;
		if (decbuf.vex) begin
			rob[rob_que].ibs <= vregfilesrc[decbuf.Rb[5:0]];
			rob[rob_que].step_v <= FALSE;
		end
		else if (decbuf.Rbvec)
			rob[rob_que].ibs <= vregfilesrc[decbuf.Rb[5:0]];
		else begin
			rob[rob_que].ibs <= regfilesrc[regmap[decbuf.Rb[5:0]]];
		end
		rob[rob_que].ics <= {1'b0,6'd0};
		rob[rob_que].ids <= {1'b0,6'd0};
		rob[rob_que].its <= {1'b0,6'd0};;//regfilesrc[decbuf.Rt[5:0]];
		rob[rob_que].rfwr <= decbuf.rfwr;
		rob[rob_que].vrfwr <= decbuf.vrfwr;
		rob[rob_que].branch <= FALSE;
		rob[rob_que].dec <= TRUE;
		rob[rob_que].cmt2 <= FALSE;
		rob[rob_que].vcmt = rob[rob_que].step >= vl;
		rob[rob_que].step <= decven;
		if (nmif) begin
			nmif <= 1'b0;
			rob[rob_que].cause <= 16'h8000|FLT_NMI;
		end
		else if (irq_i & die)
			rob[rob_que].cause <= 16'h8000|cause_i;
		else
			rob[rob_que].cause <= |decbuf.ip[2:0] ? FLT_IADR : FLT_NONE;

		if (rob_que >= ROB_ENTRIES-1)
			rob_que <= 6'd0;
		else
			rob_que <= rob_que + 2'd1;

		case(a2d_out.ir.r2.opcode)
		BEQ,BNE,BLT,BGE,BLTU,BGEU,BBS:
			begin
				tBackupRegfileSrc(active_branch);
				active_branch <= active_branch + 2'd1;
				rob[rob_que].btag <= active_branch;
				rob[rob_que].branch <= TRUE;
			end
		JAL:
			begin
				dcStream <= dcStream + 2'd1;
				dc_redirecti.redirect_ip <= {{41{a2d_out.ir[31]}},a2d_out.ir[31:10],1'h0};
				dc_redirecti.current_ip <= a2d_out.ip;
				dc2if_wr <= TRUE;
			end
		BAL:
			begin
				dcStream <= dcStream + 2'd1;
				dc_redirecti.redirect_ip <= a2d_out.ip + {{41{a2d_out.ir[31]}},a2d_out.ir[31:10],1'h0};
				dc_redirecti.current_ip <= a2d_out.ip;
				dc2if_wr <= TRUE;
			end
		EXI0:
			begin
				exilo <= TRUE;
				exi <= {{32{exbufi.ir[31]}},exbufi.ir[31:8],8'd0};
				exi_ip <= exbufi.ip;
			end
		EXI1:
			begin
				eximid <= TRUE;
				exi[63:32] <= {{40{exbufi.ir[31]}},exbufi.ir[31:8]};
				exi_ip <= exbufi.ip;
				if (!exilo)
					exi_ip <= exbufi.ip;
			end
		EXI2:
			begin
				exihi <= TRUE;
				exi[63:56] <= exbufi.ir[15:8];
				exi_ip <= exbufi.ip;
				if (!eximid && !exilo)
					exi_ip <= exbufi.ip;
			end
		IMOD:
			if (exbufi.iav && exbufi.ibv) begin
				imod <= TRUE;
				regc <= exbufi.ia;
				regd <= exbufi.ib;
				regcv <= exbufi.iav;
				regdv <= exbufi.idv;
				regcsrc <= regfilesrc[regmap[decbuf.Ra]];
				regdsrc <= regfilesrc[regmap[decbuf.Rb]];
				imod_ip <= exbufi.ip;
				imod_inst <= exbufi.ir;
			end
		BRMOD:
			if (exbufi.iav) begin
				brmod <= TRUE;
				regc <= exbufi.ia;
				regcv <= exbufi.iav;
				regcsrc <= regfilesrc[regmap[decbuf.Ra]];
				exi <= {{41{exbufi[28]}},exbufi.ir[28:20],14'h0};
				exi_ip <= exbufi.ip;
				imod_inst <= exbufi.ir;
			end
		default:	;
		endcase
		if (exihi) begin
			has_exi <= TRUE;
			exihi <= FALSE;
			eximid <= FALSE;
			exilo <= FALSE;
			rob[rob_que].imm.val[63:8] <= exi[63:8];
			rob[rob_que].ip <= exi_ip;
		end
		else if (eximid) begin
			has_exi <= TRUE;
			eximid <= FALSE;
			exilo <= FALSE;
			rob[rob_que].imm.val[63:8] <= exi[63:8];
			rob[rob_que].ip <= exi_ip;
		end
		else if (exilo) begin
			has_exi <= TRUE;
			exilo <= FALSE;
			rob[rob_que].imm.val[63:8] <= exi[63:8];
			rob[rob_que].ip <= exi_ip;
		end
		if (imod) begin
			imod <= FALSE;
			rob[rob_que].ip <= imod_ip;
			rob[rob_que].irmod <= imod_inst;
			rob[rob_que].ic <= regc;
			rob[rob_que].id <= regd;
			rob[rob_que].icv <= regcv;
			rob[rob_que].idv <= regdv;
			rob[rob_que].ics <= regcsrc;
			rob[rob_que].ids <= regdsrc;
			if (has_exi) begin
				has_exi <= FALSE;
				rob[rob_que].imm.val[63:8] <= exi[63:8];
			end
		end
		if (brmod) begin
			brmod <= FALSE;
			rob[rob_que].ip <= exi_ip;
			rob[rob_que].irmod <= imod_inst;
			rob[rob_que].ic <= regc;
			rob[rob_que].icv <= regcv;
			rob[rob_que].ics <= regcsrc;
			rob[rob_que].imm.val[63:14] <= exi[63:14];
			rob[rob_que].Rt <= imod_inst.r2.Rt;
			if (imod_inst.r2.Rt != 6'd0) begin
				tAllocReg(imod_inst.r2.Rt,rob[rob_que].pRt);
				rob[rob_que].rfwr <= TRUE;
			end
		end
		if (!(exihi||eximid||exilo||imod))
			has_exi <= FALSE;
	end


/*
//	if (a2d_out.Stream == dcStream) begin
	if (pop_a2dd && exbufi.ir != 64'd0) begin
*/

	// Execute
	// Lots to do here.
	// Simple single cycle instructions are executed directly and the reorder buffer updated.
	// Multi-cycle instructions are placed in instruction queues.

	$display("Execute");
	$display("ip: %h  ir: %h  a:%h  b:%h  c:%h  d:%h  i:%h", exbufi.ip, exbufi.ir,exbufi.ia.val,exbufi.ib.val,exbufi.ic.val,exbufi.id.val,exbufi.imm.val);
	if (rob[rob_exec].Stream == exStream + exbufo.Stream_inc) begin
		if (rob[rob_exec].dec) begin
		$display("rid:%d ip: %h  ir: %h  a:%h%c  b:%h%c  c:%h%c  d:%h%c  i:%h", rob_exec, rob[rob_exec].ip, rob[rob_exec].ir,
			rob[rob_exec].ia.val,rob[rob_exec].iav?"v":" ",rob[rob_exec].ib.val,rob[rob_exec].ibv?"v":" ",
			rob[rob_exec].ic.val,rob[rob_exec].icv?"v":" ",rob[rob_exec].id.val,rob[rob_exec].idv?"v":" ",
			rob[rob_exec].imm.val);
			// The execute sequential logic will have updated the rob_exec,
			// incrementing it to the next entry. We actually want to update
			// the entry that was processed by exec, so i'ts one less.
			if (robo.update_rob) begin
				rob[rob_exec-2'd1] <= robo;
			// We do not always want to write to the EXEC FU. It may have been a multi-cycle or memory op.
				if (robo.wr_fu) begin
					funcUnit[FU_EXEC].rid <= rob_exec;
					funcUnit[FU_EXEC].res <= robo.res;
				end
			end
		end
	end
	if (restore_rfsrc)
		tRestoreRegfileSrc(rob[rob_exec].btag);

	if (memfu.cmt) begin
		memfu.cmt <= FALSE;
		rob[memfu.rid].res <= memfu.res;
		rob[memfu.rid].cmt <= TRUE;
		rob[memfu.rid].cmt2 <= TRUE;
		rob[memfu.rid].cause <= memfu.cause;
		rob[memfu.rid].badAddr <= memfu.badAddr;
	end

	// Memory
	// Memory loads and stores are always executed in program order.

	case(mstate)
MEMORY1:
	begin
		ic_invline <= FALSE;
		ic_invall <= FALSE;
		dc_invline <= FALSE;
		dc_invall <= FALSE;
	iaccess <= FALSE;
	daccess <= FALSE;
  icnt <= 4'd0;
  dcnt <= 4'd0;
	if (ihit) begin
		
		if (!x2m_empty) begin
			x2m_rd <= TRUE;
			zero_data <= FALSE;
			mgoto (MEMORY1c);
		end
		else
			mgoto (MEMORY1);	// Stay in state
		
	end
	else begin
`ifdef ANY1_TLB
    mgoto (IFETCH2a);
`else
    mgoto (IFETCH3);
`endif
`ifdef SUPPORT_VICTIM_CACHE
		for (n = 0; n < 5; n = n + 1) begin
			if (ivtag[n]==iadr[AWID-1:6] && ivvalid[n]) begin
	    	mgoto (IFETCH6);
    	end
		end
`endif
  end
	end
	//tMemory1();

IFETCH6:
	mgoto(IFETCH7);
IFETCH7:
	begin
		ici <= ivcache[n];
		icnt <= 4'd15;	// trigger update
		ivcache[n] <= ic_line;
		ivtag[n] <= ic_tag;
		mgoto (IFETCH5);
	end

IFETCH2a:
  begin
    mgoto(IFETCH3);
  end
IFETCH3:
  begin
`ifdef SUPPORT_VICTIM_CACHE
  	// Cache miss, select an entry in the victim cache to
  	// update.
		ivcnt <= ivcnt + 2'd1;
		if (ivcnt>=3'd4)
			ivcnt <= 3'd0;
		ivcache[ivcnt] <= ic_line;
		ivtag[ivcnt] <= ic_tag;
		ivvalid[ivcnt] <= TRUE;
`endif
		xlaten <= FALSE;
	  begin
  		mgoto (IFETCH3a);
`ifdef ANY1_TLB  		
  		if (tlbmiss) begin
  			memfu.cmt <= TRUE;
  			memfu.rid <= membufo.rid;
		    memfu.cause <= 16'h8004;
			  memfu.badAddr <= ip;
			  vpa_o <= FALSE;
			  tMemory1();
			end
			else
`endif			
			begin
			  // First time in, set to miss address, after that increment
			  iaccess <= TRUE;
`ifdef CPU_B128
        if (!iaccess)
          iadr <= {ip[AWID-1:5],5'h0};
        else
          iadr <= {iadr[AWID-1:4],4'h0} + 5'h10;
`endif
`ifdef CPU_B64
        if (!iaccess)
          iadr <= {ip[AWID-1:5],5'h0}
        else
          iadr <= {iadr[AWID-1:3],3'h0} + 4'h8;
`endif
`ifdef CPU_B32
        if (!iaccess)
          iadr <= {ip[AWID-1:5],5'h0};
        else
          iadr <= {iadr[AWID-1:2],2'h0} + 3'h4;
`endif			
      end
	  end
  end
IFETCH3a:
  begin
  	vpa_o <= HIGH;
    cyc_o <= HIGH;
		stb_o <= HIGH;
`ifdef CPU_B128
    sel_o <= 16'hFFFF;
`endif
`ifdef CPU_B64
    sel_o <= 8'hFF;
`endif
`ifdef CPU_B32
		sel_o <= 4'hF;
`endif
//		adr_o <= iadr;
    mgoto (IFETCH4);
  end

IFETCH4:
  begin
    if (ack_i) begin
      cyc_o <= LOW;
      stb_o <= LOW;
      vpa_o <= LOW;
      sel_o <= 1'h0;
`ifdef CPU_B128
      case(icnt[3:2])
      2'd0: ici[127:0] <= dat_i;
      2'd1: ici[255:128] <= dat_i;
      2'd2: ici[383:256] <= dat_i;
      2'd3: ici[511:384] <= dat_i;
      endcase
      mgoto (IFETCH5);
`endif
`ifdef CPU_B64
      case(icnt[3:1])
      3'd0: ici[63:0] <= dat_i;
      3'd1: ici[127:64] <= dat_i;
      3'd2: ici[191:128] <= dat_i;
      3'd3; ici[255:192] <= dat_i;
      3'd4:	ici[319:256] <= dat_i;
      3'd5:	ici[383:320] <= dat_i;
      3'd6:	ici[447:384] <= dat_i;
      3'd7:	ici[511:448] <= dat_i;
      endcase
      mgoto (IFETCH5);
`endif
`ifdef CPU_B32
			// ToDo: fill remaining cases
      case(icnt[3:0])
      4'd0: ici[31:0] <= dat_i;
      4'd1: ici[63:32] <= dat_i;
      4'd2: ici[95:64] <= dat_i;
      4'd3: ici[127:96] <= dat_i;
      4'd4: ici[159:128] <= dat_i;
      4'd5: ici[191:160] <= dat_i;
      4'd6; ici[223:192] <= dat_i;
      4'd7: ici[255:224] <= dat_i;
      endcase
      mgoto (IFETCH5);
`endif
    end
		tPMAIP(); // must have adr_o valid for PMA
  end

IFETCH5:
  if (~ack_i) begin
`ifdef CPU_B128
    icnt <= icnt + 4'd4;
`endif
`ifdef CPU_B64
    icnt <= icnt + 4'd2;
`endif
`ifdef CPU_B32
    icnt <= icnt + 2'd1;
`endif
`ifdef CPU_B128
    if (icnt[3:2]==2'd3) begin
    	ic_wway <= waycnt;
			ictag[waycnt][iadr[pL1msb:6]] <= iadr[AWID-1:6];
//			icvalid[waycnt][iadr[pL1msb:6]] <= 1'b1;
			mgoto(MEMORY1);
    end
		else
      mgoto (IFETCH3);
`endif
`ifdef CPU_B64
    if (icnt[3:1]==3'd7) begin
			tLICache(lfsr_o[1:0],iadr[AWID-1:6],ici,1'b1);
    	tMemory1();
    end
		else
      mgoto (IFETCH3);
`endif
`ifdef CPU_B32
    if (icnt[3:0]==4'd15) begin
			tLICache(lfsr_o[1:0],iadr[AWID-1:6],ici,1'b1);
    	tMemory1();
    end
		else
      mgoto (IFETCH3);
`endif
  end


`ifdef ANY1_TLB
TLB1:
	mgoto (TLB2);
TLB2:
	mgoto (TLB3);
TLB3:
	begin
    memfu.res <= tlbdato;
    memfu.cmt <= TRUE;
		memfu.rid <= membufo.rid;
   	tMemory1();
	end
`endif


MEMORY1c:
	begin
		// Detect cache controller commands
		if (membufo.ir.ld.opcode==LDx && membufo.ir.ld.func==CACHE && rob[membufo.rid].iav) begin
			ic_invline <= membufo.Rt[2:0]==3'd1;
			ic_invall	<= membufo.Rt[2:0]==3'd2;
			dc_invline <= membufo.Rt[5:3]==3'd3;
			dc_invall	<= membufo.Rt[5:3]==3'd4;
  		mgoto (MEMORY1d);
			if (membufo.Rt[5:3]==3'd1) begin
				cr0[30] <= TRUE;
		    memfu.cmt <= TRUE;
				memfu.rid <= membufo.rid;
   			tMemory1();
			end
			if (membufo.Rt[5:3]==3'd2) begin
				cr0[30] <= FALSE;
    		memfu.cmt <= TRUE;
				memfu.rid <= membufo.rid;
   			tMemory1();
			end
		end
		else if (rob[membufo.rid].iav && rob[membufo.rid].ibv && rob[membufo.rid].icv && rob[membufo.rid].idv)
  		mgoto (MEMORY1d);
  end
  // Need a cycle for AGEN
MEMORY1d:
	mgoto(MEMORY1e);
MEMORY1e:
	begin
  	/*
    if (membufo.ir[7:0]==LINK) begin
    	rob[membufo.rid].Rt <= 6'd62;
    	rob[membufo.rid].res <= membufo.ia + membufo.imm;
    end
   */
`ifdef ANY1_TLB
    mgoto (MEMORY1a);
`else
    mgoto (MEMORY2);
`endif
    if (membufo.ir.r2.opcode==SYS) begin
    	tlb_ia <= rob[membufo.rid].ia;
    	tlb_ib <= rob[membufo.rid].ib;
    	tlbwr <= TRUE;
`ifdef ANY1_TLB
   		mgoto (TLB1);
`else
			rob[membufo.rid].ui <= TRUE;
      rob[membufo.rid].cmt <= TRUE;
      rob[membufo.rid].cmt2 <= TRUE;
			tMemory1();
`endif   		
    end
    else if (membufo.ir.r2.opcode==LDxX && membufo.ir.nld.A==1'b1) begin
      memfu.res.val <= ea;
      memfu.cmt <= TRUE;
 			memfu.rid <= membufo.rid;
    	tMemory1();
    end
    else begin
    	// If speculated loads are not enabled then they must occur at the
    	// head of the list.
    	if (membufo.ir.r2.opcode==LDx && membufo.rid != rob_deq && !sple)
    		mgoto (MEMORY1e);
    	// Holding pattern until store is at head of list
    	// Prevents the scenario of having an instruction before the store
    	// causing an exception.
    	else if (membufo.ir.r2.opcode==STx && membufo.rid != rob_deq)
    		mgoto (MEMORY1e);
    	else begin
      tEA(ea);
      xlaten <= TRUE;
`ifdef CPU_B128
      sel <= selx << ea[3:0];
      dat <= zero_data ? 1'd0 : membufo.dato << {ea[3:0],3'b0};
`endif
`ifdef CPU_B64
      sel <= selx << ea[2:0];
      dat <= zero_data ? 1'd0 : membufo.dato << {ea[2:0],3'b0};
`endif
`ifdef CPU_B32
      sel <= selx << ea[1:0];
      dat <= zero_data ? 1'd0 : membufo.dato << {ea[1:0],3'b0};
`endif
      ealow <= ea[7:0];
      end
    end
  end
MEMORY1a:
  mgoto (MEMORY2);
// This cycle for pageram access
MEMORY2:
  begin
    mgoto (MEMORY_KEYCHK1);
  end
MEMORY_KEYCHK1:
  begin
 `ifdef SUPPORT_KEYCHK
  	if (!kyhit)
  		mgosub(KYLD);
  	else begin
  		mgoto (MEMORY2b);
  		for (n = 0; n < 8; n = n + 1)
  			if (kyut == keys[n] || kyut==20'd0)
  				mgoto(MEMORY3);
  	end
`else
		mgoto (MEMORY3);
`endif  	
    if (d_cache)
      tPMAEA();
  end
MEMORY2b:
	begin
    memfu.cause <= 16'h8031;	// KEY fault
    memfu.cmt <= TRUE;
		memfu.rid <= membufo.rid;
	  memfu.badAddr <= ea;
	  tMemory1();
	end
MEMORY3:
  begin
    xlaten <= FALSE;
    dwait <= 3'd0;
    mgoto (MEMORY4);
`ifdef ANY1_TLB
		if (tlbmiss) begin
	    memfu.cause <= 16'h8004;
  	  memfu.badAddr <= ea;
	    memfu.cmt <= TRUE;
 			memfu.rid <= membufo.rid;
  	  tMemory1();
  	end
    else
`endif    
    if (~d_cache) begin
      cyc_o <= HIGH;
      stb_o <= HIGH;
`ifdef CPU_B128
      sel_o <= sel[15:0];
      dat_o <= dat[127:0];
`endif
`ifdef CPU_B64
      sel_o <= sel[7:0];
      dat_o <= dat[63:0];
`endif
`ifdef CPU_B32
      sel_o <= sel[3:0];
      dat_o <= dat[31:0];
`endif
      case(membufo.ir[7:0])
      LDx:
      	begin
      		if (membufo.ir.ld.func==4'd6)
      			sr_o <= HIGH;
      		if (dhit) begin
      			cyc_o <= 1'b0;
      			stb_o <= 1'b0;
      			sel_o <= 1'h0;
      			sr_o <= LOW;
      		end
      	end
      STx:	
      	begin
      		if (membufo.ir.st.func==4'd6)
      			cr_o <= HIGH;
      		we_o <= HIGH;
      	end
      default:  ;
      endcase
//      dadr <= adr_o;
    end
  end
MEMORY4:
  begin
  	case(1'b1)
    ic_invline:	tMemory1();
    ic_invall:	tMemory1();
    dc_invline:	tMemory1();
    dc_invall:	tMemory1();
    dce & dhit:
	    begin
    	datil <= dc_line;
  		if (d_st) begin
  			if (acki) begin
`ifdef CPU_B128
	  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
`endif
`ifdef CPU_B64
  				dci <= (dc_line & stmask) | ((dat << {adr_o[5:3],6'b0}) & ~stmask);
`endif
`ifdef CPU_B32
  				dci <= (dc_line & stmask) | ((dat << {adr_o[5:2],5'b0}) & ~stmask);
`endif
	  			dc_wway <= dc_rway;
  				dcache_wr <= TRUE;
		      mgoto (MEMORY5);
		      stb_o <= LOW;
		      if (sel[`SELH]==1'h0) begin
		        cyc_o <= LOW;
		        we_o <= LOW;
		        cr_o <= LOW;
		        sel_o <= 1'h0;
		      end
		    end
  		end
    	else begin
    		dwait <= dwait + 2'd1;
    		if (dwait==3'd2)
	      	mgoto (MEMORY5);
	    end
  		end
    default:
	    if (acki) begin
	      mgoto (MEMORY5);
	      stb_o <= LOW;
	      dati <= dat_i;
	      if (sel[`SELH]==1'h0) begin
	        cyc_o <= LOW;
	        we_o <= LOW;
	        cr_o <= LOW;
	        sel_o <= 1'h0;
	      end
	    end
  	endcase
  end
MEMORY5:
  if (~acki) begin
    if (|sel[`SELH])
      mgoto (MEMORY6);
    else begin
      case(membufo.ir.r2.opcode)
      LDx:
      	begin
      		if (dce & dhit)
      			dati <= datil >> {adr_o[5:3],6'b0};
	        mgoto (DATA_ALIGN);
      	end
	    STx://,`FSTO,`PSTO,
	    	begin
	    		if (membufo.ir.st.func==4'd7) begin	// STPTR
			    	if (ea==32'd0) begin
			    	 	memfu.cmt <= TRUE;
  						memfu.rid <= membufo.rid;
				    	tMemory1();
			    	end
			    	else begin
			    		shr_ma <= TRUE;
			    		zero_data <= TRUE;
			    		mgoto (MEMORY1c);
			    	end
	    		end
	    		else begin
			    	memfu.cmt <= TRUE;
		  			memfu.rid <= membufo.rid;
			    	tMemory1();
		      end
	    	end
      default:
        mgoto (DATA_ALIGN);
      endcase
    end
  end
MEMORY6:
  begin
`ifdef ANY1_TLB
    mgoto (MEMORY6a);
`else
    mgoto (MEMORY7);
`endif
    xlaten <= TRUE;
    tEA(ea);
  end
MEMORY6a:
  mgoto (MEMORY7);
MEMORY7:
  mgoto (MEMORY_KEYCHK2);
MEMORY_KEYCHK2:
  begin
 `ifdef SUPPORT_KEYCHK
  	if (!kyhit)
  		mgosub(KYLD);
  	else begin
  		mgoto (MEMORY2b);
  		for (n = 0; n < 8; n = n + 1)
  			if (kyut == keys[n] || kyut==20'd0)
  				mgoto(MEMORY8);
  	end
`else
		mgoto (MEMORY8);
`endif  	
    tPMAEA();
  end
MEMORY8:
  begin
    xlaten <= FALSE;
    dwait <= 3'd0;
//    dadr <= adr_o;
    mgoto (MEMORY9);
`ifdef ANY1_TLB    
		if (tlbmiss) begin
			memfu.cmt <= TRUE;
	    memfu.cause <= 16'h8004;
  	  memfu.badAddr <= ea;
 			memfu.rid <= membufo.rid;
		  cyc_o <= LOW;
		  stb_o <= LOW;
		  we_o <= 1'b0;
		  sel_o <= 1'd0;
		  tMemory1();
	  end
		else
`endif
		begin
			if (dhit & d_ld & dce) begin
				cyc_o <= LOW;
				stb_o <= LOW;
				sel_o <= 1'b0;
			end
			else begin
      	stb_o <= HIGH;
      	sel_o <= sel[`SELH];
      	dat_o <= dat[`DATH];
    	end
    end
  end
MEMORY9:
  if (dhit & dce) begin
  	datil <= dc_line;
		if (d_st) begin
			if (acki) begin
`ifdef CPU_B128
  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
`endif
`ifdef CPU_B64
 				dci <= (dc_line & stmask) | ((dat << {adr_o[5:3],6'b0}) & ~stmask);
`endif
`ifdef CPU_B32
				dci <= (dc_line & stmask) | ((dat << {adr_o[5:2],5'b0}) & ~stmask);
`endif
  			dc_wway <= dc_rway;
  			dcache_wr <= TRUE;
	      mgoto (MEMORY10);
	      stb_o <= LOW;
	      if (sel[`SELH]==1'h0) begin
	        cyc_o <= LOW;
	        we_o <= LOW;
	        cr_o <= LOW;
	        sel_o <= 1'h0;
	      end
	    end
		end
  	else begin
    	dwait <= dwait + 2'd1;
    	if (dwait==3'd2)
      	mgoto (MEMORY10);
    end
	end
  else if (acki) begin
    mgoto (MEMORY10);
    stb_o <= LOW;
    dati[`DATH] <= dat_i;
`ifdef CPU_B128
    cyc_o <= LOW;
    we_o <= LOW;
    cr_o <= LOW;
    sel_o <= 1'h0;
`endif
`ifdef CPU_B64
    cyc_o <= LOW;
    we_o <= LOW;
    cr_o <= LOW;
    sel_o <= 1'h0;
`endif
`ifdef CPU_B32
    if (sel[11:8]==4'h0) begin
      cyc_o <= LOW;
      we_o <= LOW;
      cr_o <= LOW;
      sel_o <= 4'h0;
    end
`endif
  end
MEMORY10:
  if (~acki) begin
`ifdef CPU_B32
    ea <= {ea[31:2]+2'd1,2'b00};
    if (sel[11:8])
      mgoto (MEMORY11);
    else
`endif
    begin
      case(membufo.ir[7:0])
      LDx:
      	begin
      		if (dhit & dce)
      			dati <= datil >> {adr_o[5:3],6'b0};
	        mgoto (DATA_ALIGN);
      	end
	    STx://,`FSTO,`PSTO,
	    	begin
	    		if (membufo.ir.st.func==4'd7) begin	// STPTR
			    	if (ea==32'd0) begin
			    	 	memfu.cmt <= TRUE;
			  			memfu.rid <= membufo.rid;
				    	tMemory1();
			    	end
			    	else begin
			    		shr_ma <= TRUE;
			    		zero_data <= TRUE;
			    		mgoto (MEMORY1c);
			    	end
	    		end
	    		else begin
			    	memfu.cmt <= TRUE;
		  			memfu.rid <= membufo.rid;
				   	tMemory1();
		      end
	    	end
      default:
        mgoto (DATA_ALIGN);
      endcase
    end
  end
MEMORY11:
  begin
`ifdef ANY1_TLB
    mgoto (MEMORY11a);
`else
    mgoto (MEMORY12);
`endif
    xlaten <= TRUE;
    tEA(ea);
  end
MEMORY11a:
  mgoto (MEMORY12);
MEMORY12:
  mgoto (MEMORY_KEYCHK3);
MEMORY_KEYCHK3:
  begin
`ifdef SUPPORT_KEYCHK
  	if (!kyhit)
  		mgosub(KYLD);
  	else begin
  		mgoto (MEMORY2b);
  		for (n = 0; n < 8; n = n + 1)
  			if (kyut == keys[n] || kyut==20'd0)
  				mgoto(MEMORY13);
  	end
`else
		mgoto(MEMORY13);  	
`endif
    tPMAEA();
  end
MEMORY13:
  begin
    xlaten <= FALSE;
    dwait <= 3'd0;
//    dadr <= adr_o;
    mgoto (MEMORY14);
`ifdef ANY1_TLB    
		if (tlbmiss) begin
			memfu.cmt <= TRUE;
	    memfu.cause <= 16'h8004;
  	  memfu.badAddr <= ea;
 			memfu.rid <= membufo.rid;
		  cyc_o <= LOW;
		  stb_o <= LOW;
		  we_o <= LOW;
      cr_o <= LOW;
		  sel_o <= 1'd0;
		  tMemory1();
	  end
		else
`endif		
		begin
			if (dhit & d_ld) begin
				cyc_o <= LOW;
				stb_o <= LOW;
				sel_o <= 1'b0;
			end
			else begin
      	stb_o <= HIGH;
      	sel_o <= sel[11:8];
      	dat_o <= dat[95:64];
    	end
    end
  end
MEMORY14:
  if (dhit & dce) begin
  	datil <= dc_line;
		if (d_st) begin
			if (acki) begin
`ifdef CPU_B128
  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
`endif
`ifdef CPU_B64
 				dci <= (dc_line & stmask) | ((dat << {adr_o[5:3],6'b0}) & ~stmask);
`endif
`ifdef CPU_B32
				dci <= (dc_line & stmask) | ((dat << {adr_o[5:2],5'b0}) & ~stmask);
`endif
  			dc_wway <= dc_rway;
  			dcache_wr <= TRUE;
	      mgoto (MEMORY15);
	      stb_o <= LOW;
        cyc_o <= LOW;
        we_o <= LOW;
        cr_o <= LOW;
        sel_o <= 1'h0;
	    end
		end
  	else begin
    	dwait <= dwait + 2'd1;
    	if (dwait==3'd2)
      	mgoto (MEMORY15);
    end
	end
  else if (acki) begin
    mgoto (MEMORY15);
    cyc_o <= LOW;
    stb_o <= LOW;
    we_o <= LOW;
    cr_o <= LOW;
    sel_o <= 4'h0;
    dati[95:64] <= dat_i;
  end
MEMORY15:
  if (~acki) begin
    case(membufo.ir[7:0])
    LDx:
    	begin
    		if (dhit & dce)
    			dati <= datil >> {adr_o[5:3],6'b0};
        mgoto (DATA_ALIGN);
    	end
    STx://,`FSTO,`PSTO,
    	begin
    		if (membufo.ir.st.func==4'd7) begin	// STPTR
		    	if (ea==32'd0) begin
		    	 	memfu.cmt <= TRUE;
		  			memfu.rid <= membufo.rid;
			    	tMemory1();
		    	end
		    	else begin
		    		shr_ma <= TRUE;
		    		zero_data <= TRUE;
		    		mgoto (MEMORY1c);
		    	end
    		end
    		else begin
		    	memfu.cmt <= TRUE;
	  			memfu.rid <= membufo.rid;
		    	tMemory1();
	      end
    	end
    default:
      mgoto (DATA_ALIGN);
    endcase
  end
DATA_ALIGN:
  begin
  	if (d_ld & ~dhit & dcachable & dce)
  		mgoto (DFETCH2);
  	else
    	tMemory1();
    memfu.cmt <= TRUE;
		memfu.rid <= membufo.rid;
		sr_o <= LOW;
    case(membufo.ir.r2.opcode)
    LDx:
    	begin
	    	case(membufo.ir.ld.func)
	    	4'd0:	begin memfu.res <= {{56{datis[7]}},datis[7:0]}; end
	    	4'd1:	begin memfu.res <= {{48{datis[15]}},datis[15:0]}; end
	    	4'd2:	begin memfu.res <= {{32{datis[31]}},datis[31:0]}; end
	    	4'd3:	begin memfu.res <= datis[63:0]; end
	    	4'd6:	begin memfu.res <= datis[63:0]; end
	    	4'd7:	begin memfu.res <= datis[63:0]; end
	    	4'd8:	begin memfu.res <= {56'd0,datis[7:0]}; end
	    	4'd9:	begin memfu.res <= {48'd0,datis[15:0]}; end
	    	4'd10:	begin memfu.res <= {32'd0,datis[31:0]}; end
	    	4'd11:	begin memfu.res <= datis[63:0]; end
	    	4'd15:	begin memfu.res <= datis[63:0]; end
	    	default:	;
	    	endcase
    	end
    LDxX:
    	begin
	    	case(membufo.ir.nld.func)
	    	4'd0:	begin memfu.res <= {{56{datis[7]}},datis[7:0]}; end
	    	4'd1:	begin memfu.res <= {{48{datis[15]}},datis[15:0]}; end
	    	4'd2:	begin memfu.res <= {{32{datis[31]}},datis[31:0]}; end
	    	4'd3:	begin memfu.res <= datis[63:0]; end
	    	4'd6:	begin memfu.res <= datis[63:0]; end
	    	4'd7:	begin memfu.res <= datis[63:0]; end
	    	4'd8:	begin memfu.res <= {56'd0,datis[7:0]}; end
	    	4'd9:	begin memfu.res <= {48'd0,datis[15:0]}; end
	    	4'd10:	begin memfu.res <= {32'd0,datis[31:0]}; end
	    	4'd11:	begin memfu.res <= datis[63:0]; end
	    	4'd15:	begin memfu.res <= datis[63:0]; end
	    	default:	;
	    	endcase
    	end
	  //LDOR: res <= datis[63:0];
    //`FLDO,`PLDO:  res <= datis[63:0];
    //`RTS:    pc <= datis[63:0] + {ir[12:9],2'b00};
    //`RTX:    pc <= datis[63:0];
    //`UNLINK:  begin res <= datis[63:0]; Rd <= 5'd30; end
    //`POP:   begin crres <= datis[31:0]; rares <= datis[AWID-1:0]; res <= datis[63:0]; end
    default:  ;
    endcase
  end


DFETCH2:
  begin
    mgoto(DFETCH3);
  end
DFETCH3:
  begin
 		xlaten <= FALSE;
	  begin
  		mgoto (DFETCH3a);
`ifdef ANY1_TLB  		
  		if (tlbmiss) begin
  			memfu.cmt <= TRUE;
		    memfu.cause <= 16'h8004;
  			memfu.rid <= membufo.rid;
			  memfu.badAddr <= adr_o;
			  tMemory1();
			end
			else
`endif			
			begin
			  // First time in, set to miss address, after that increment
			  daccess <= TRUE;
`ifdef CPU_B128
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:4],4'h0} + 5'h10;
        end
`endif
`ifdef CPU_B64
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0}
        else begin
          dadr <= {dadr[AWID-1:3],3'h0} + 4'h8;
        end
`endif
`ifdef CPU_B32
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:2],2'h0} + 3'h4;
        end
`endif			
      end
	  end
  end
DFETCH3a:
  begin
    cyc_o <= HIGH;
		stb_o <= HIGH;
`ifdef CPU_B128
    sel_o <= 16'hFFFF;
`endif
`ifdef CPU_B64
    sel_o <= 8'hFF;
`endif
`ifdef CPU_B32
		sel_o <= 4'hF;
`endif
//		adr_o <= dadr;
    mgoto (DFETCH4);
  end
DFETCH4:
  begin
    if (ack_i) begin
      cyc_o <= LOW;
      stb_o <= LOW;
      vpa_o <= LOW;
      sel_o <= 1'h0;
`ifdef CPU_B128
      case(dcnt[3:2])
      2'd0: dci[127:0] <= dat_i;
      2'd1: dci[255:128] <= dat_i;
      2'd2: dci[383:256] <= dat_i;
      2'd3: dci[511:384] <= dat_i;
      endcase
      mgoto (DFETCH5);
`endif
`ifdef CPU_B64
      case(dcnt[3:1])
      3'd0: dci[63:0] <= dat_i;
      3'd1: dci[127:64] <= dat_i;
      3'd2: dci[191:128] <= dat_i;
      3'd3; dci[255:192] <= dat_i;
      3'd4:	dci[319:256] <= dat_i;
      3'd5:	dci[383:320] <= dat_i;
      3'd6:	dci[447:384] <= dat_i;
      3'd7:	dci[511:448] <= dat_i;
      endcase
      mgoto (DFETCH5);
`endif
`ifdef CPU_B32
      case(dcnt[3:0])
      4'd0: dci[31:0] <= dat_i;
      4'd1: dci[63:32] <= dat_i;
      4'd2: dci[95:64] <= dat_i;
      4'd3: dci[127:96] <= dat_i;
      4'd4: dci[159:128] <= dat_i;
      4'd5: dci[191:160] <= dat_i;
      4'd6; dci[223:192] <= dat_i;
      4'd7: dci[255:224] <= dat_i;
      endcase
      mgoto (DFETCH5);
`endif
    end
  end
DFETCH5:
  begin
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3) begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[pL1msb:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[pL1msb:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[pL1msb:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[pL1msb:6]] <= 1'b1;
    	endcase
		end
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7) begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[pL1msb:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[pL1msb:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[pL1msb:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[pL1msb:6]] <= 1'b1;
    	endcase
		end
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15) begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[pL1msb:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[pL1msb:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[pL1msb:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[pL1msb:6]] <= 1'b1;
    	endcase
		end
`endif
    if (~ack_i) begin
`ifdef CPU_B128
      dcnt <= dcnt + 4'd4;
`endif
`ifdef CPU_B64
      dcnt <= dcnt + 4'd2;
`endif
`ifdef CPU_B32
      dcnt <= dcnt + 2'd1;
`endif
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3)
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7)
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15)
`endif
    	tMemory1();
		else
      mgoto (DFETCH3);
    end
  end

`ifdef SUPPORT_KEYCHK
KYLD:
  begin
    tEA(keytbl);
`ifdef ANY1_TLB
			mgoto (KYLD2);
`else
    	mgoto(KYLD3);
`endif
  end
KYLD2:
	mgoto (KYLD3);
KYLD3:
  begin
 		xlaten <= FALSE;
	  begin
  		mgoto (KYLD3a);
`ifdef ANY1_TLB  		
  		if (tlbmiss) begin
  			memfu.cmt <= TRUE;
		    memfu.cause <= 16'h8004;
			  memfu.badAddr <= adr_o;
  			memfu.rid <= membufo.rid;
  			tMemory1();
			end
			else
`endif			
			begin
			  // First time in, set to miss address, after that increment
			  daccess <= TRUE;
`ifdef CPU_B128
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:4],4'h0} + 5'h10;
        end
`endif
`ifdef CPU_B64
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0}
        else begin
          dadr <= {dadr[AWID-1:3],3'h0} + 4'h8;
        end
`endif
`ifdef CPU_B32
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:2],2'h0} + 3'h4;
        end
`endif			
      end
	  end
  end
KYLD3a:
  begin
    cyc_o <= HIGH;
		stb_o <= HIGH;
`ifdef CPU_B128
    sel_o <= 16'hFFFF;
`endif
`ifdef CPU_B64
    sel_o <= 8'hFF;
`endif
`ifdef CPU_B32
		sel_o <= 4'hF;
`endif
//		adr_o <= dadr;
    mgoto (KYLD4);
  end
KYLD4:
  begin
    if (ack_i) begin
      cyc_o <= LOW;
      stb_o <= LOW;
      vpa_o <= LOW;
      sel_o <= 1'h0;
`ifdef CPU_B128
      case(dcnt[3:2])
      2'd0: dci[127:0] <= dat_i;
      2'd1: dci[255:128] <= dat_i;
      2'd2: dci[383:256] <= dat_i;
      2'd3: dci[511:384] <= dat_i;
      endcase
      mgoto (KYLD5);
`endif
`ifdef CPU_B64
      case(dcnt[3:1])
      3'd0: dci[63:0] <= dat_i;
      3'd1: dci[127:64] <= dat_i;
      3'd2: dci[191:128] <= dat_i;
      3'd3; dci[255:192] <= dat_i;
      3'd4:	dci[319:256] <= dat_i;
      3'd5:	dci[383:320] <= dat_i;
      3'd6:	dci[447:384] <= dat_i;
      3'd7:	dci[511:448] <= dat_i;
      endcase
      mgoto (KYLD5);
`endif
`ifdef CPU_B32
      case(dcnt[3:0])
      4'd0: dci[31:0] <= dat_i;
      4'd1: dci[63:32] <= dat_i;
      4'd2: dci[95:64] <= dat_i;
      4'd3: dci[127:96] <= dat_i;
      4'd4: dci[159:128] <= dat_i;
      4'd5: dci[191:160] <= dat_i;
      4'd6; dci[223:192] <= dat_i;
      4'd7: dci[255:224] <= dat_i;
      endcase
      mgoto (KYLD5);
`endif
    end
  end
KYLD5:
  begin
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3) begin
    	kytag[dadr[11:6]] <= dadr[AWID-1:6];
    	kyline[dadr[11:6]] <= dci;
    	kyv[dadr[11:6]] <= 1'b1;
		end
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7) begin
    	kytag[dadr[11:6]] <= dadr[AWID-1:6];
    	kyline[dadr[11:6]] <= dci;
    	kyv[dadr[11:6]] <= 1'b1;
		end
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15) begin
    	kytag[dadr[11:6]] <= dadr[AWID-1:6];
    	kyline[dadr[11:6]] <= dci;
    	kyv[dadr[11:6]] <= 1'b1;
		end
`endif
    if (~ack_i) begin
`ifdef CPU_B128
      dcnt <= dcnt + 4'd4;
`endif
`ifdef CPU_B64
      dcnt <= dcnt + 4'd2;
`endif
`ifdef CPU_B32
      dcnt <= dcnt + 2'd1;
`endif
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3)
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7)
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15)
`endif
    	mret();
		else
      mgoto (KYLD3);
    end
  end
`endif
default:	;
	endcase

  $display ("----------------------------------------------------------------- Reorder Buffer -----------------------------------------------------------------");
  $display ("head: %d  tail: %d", rob_deq, rob_que);
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		$display("%c%c%c%d: Strm=%d%c %c%c%c%c ip=%h ir=%h Rt=%d res=%h imm=%h",
			n[5:0]==rob_deq ? "D" : " ", n==rob_que ? "Q" : " ", n==rob_exec ? "X" : " ",
			n[5:0],rob[n].Stream,rob[n].Stream_inc?"+":" ",rob[n].cmt ? "C" : " ",rob[n].v ? "V" : " ",
			rob[n].rfwr ? "W" : " ",
			rob[n].dec ? "D" : " ",
			rob[n].ip,rob[n].ir,
			rob[n].Rt,rob[n].res.val,
			rob[n].imm.val);
	end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Writeback
	//
	// Writeback looks only at the reorder buffer to determine which register
	// to update. The reorder buffer acts like a fifo between the other stages
	// and the writeback stage.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	$display("Writeback:%d",wbStream);
	if (rob[rob_deq].Stream == wbStream + rob[rob_deq].Stream_inc) begin
		if (rob[rob_deq].cmt==TRUE) begin
			wbStream <= wbStream + rob[rob_deq].Stream_inc;
			begin
				$display("ip:%h  ir:%h", rob[rob_deq].ip, rob[rob_deq].ir);
				$display("Rt:%d  res:%h", rob[rob_deq].Rt, rob[rob_deq].res);
				if (rob[rob_deq].ui==TRUE) begin
					status[4][4] <= 1'b0;	// disable further interrupts
					eip <= rob[rob_deq].ip;
					pmStack <= {pmStack[27:0],3'b100,1'b0};
					cause[3'd4] <= FLT_UNIMP;
					wb_f2a_rst <= TRUE;
					wb_a2d_rst <= TRUE;
					wb_d2x_rst <= TRUE;
					wbStream <= wbStream + 2'd1;
					wb_redirecti.redirect_ip <= tvec[3'd4] + {omode,6'h00};
					wb_redirecti.current_ip <= rob[rob_deq].ip;
					wb2if_wr <= TRUE;
					//tBackupRegfileSrc(wbStream + rob[rob_deq].Stream_inc);
				end
				else if (rob[rob_deq].cause!=16'h00) begin
					status[4][4] <= 1'b0;	// disable further interrupts
					eip <= rob[rob_deq].ip;
					pmStack <= {pmStack[27:0],3'b100,1'b0};
					cause[3'd4] <= rob[rob_deq].cause;
					badaddr[3'd4] <= rob[rob_deq].badAddr;
					wb_f2a_rst <= TRUE;
					wb_a2d_rst <= TRUE;
					wb_d2x_rst <= TRUE;
					wbStream <= wbStream + 2'd1;
					wb_redirecti.redirect_ip <= tvec[3'd4] + {omode,6'h00};
					wb_redirecti.current_ip <= rob[rob_deq].ip;
					wb2if_wr <= TRUE;
					//tBackupRegfileSrc(wbStream + rob[rob_deq].Stream_inc);
				end
				else begin
					case(rob[rob_deq].ir.r2.opcode)
					CSR:
						case(rob[rob_deq].imm[18:16])
						CSRW:	tWriteCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						CSRS:	tSetbitCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						CSRC:	tClrbitCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						CSRRW:	tWriteCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						default:	;
						endcase
					SYS:
						case(rob[rob_deq].ir.r2.func)
						RTE:	
							begin
								sema[0] <= 1'b0;
								wb_redirecti.redirect_ip <= eip + rob[rob_deq].ia;
								wb_redirecti.current_ip <= rob[rob_deq].ip;
								wb2if_wr <= TRUE;
								wb_f2a_rst <= TRUE;
								wb_a2d_rst <= TRUE;
								wb_d2x_rst <= TRUE;
								wbStream <= wbStream + 2'd1;
								pmStack <= {8'h9,pmStack[31:4]};
								status[4][pmStack[3:1]] <= pmStack[0];
								status[3][pmStack[3:1]] <= pmStack[0];
								status[2][pmStack[3:1]] <= pmStack[0];
								status[1][pmStack[3:1]] <= pmStack[0];
								status[0][pmStack[3:1]] <= pmStack[0];
								//tBackupRegfileSrc(wbStream + rob[rob_deq].Stream_inc);
							end
						TLBRW:	;
						default:	;
						endcase
					default:	;
					endcase
					if (rob[rob_deq].rfwr==TRUE) begin
						regfile[rob[rob_deq].Rt[5:0]] <= rob[rob_deq].res;
						regfilesrc[regmap[rob[rob_deq].Rt[5:0]]].rf <= 1'h0;
						regalloc[rob[rob_deq].pRt[5:0]] <= 1'b0;	// deallocate mapped register
						regmap[rob[rob_deq].Rt[5:0]] <= rob[rob_deq].Rt[5:0];
					end
					if (rob[rob_deq].vrfwr) begin
						vrf_update <= TRUE;
						vrf_din <= rob[rob_deq].res;
						vrf_wa <= {rob[rob_deq].res_ele,rob[rob_deq].Rt[5:0]};
						if (rob[rob_deq].vcmt)
							vregfilesrc[rob[rob_deq].Rt[5:0]].rf <= 1'h0;
					end
				end
				begin
					rob[rob_deq].v <= INV;
					rob[rob_deq].ui <= INV;
					rob[rob_deq].cause <= FLT_NONE;
					rob[rob_deq].cmt <= FALSE;
					rob[rob_deq].rfwr <= FALSE;
					rob[rob_deq].vrfwr <= FALSE;
					rob[rob_deq].jump <= FALSE;
					if (rob_deq >= ROB_ENTRIES-1)
						rob_deq <= 6'd0;
					else
						rob_deq <= rob_deq + 2'd1;
				end
			end
		end
	end
	else begin
		if (rob[rob_deq].cmt) begin
			rob[rob_deq].v <= INV;
			rob[rob_deq].ui <= INV;
			rob[rob_deq].cause <= FLT_NONE;
			rob[rob_deq].cmt <= FALSE;
			rob[rob_deq].rfwr <= FALSE;
			rob[rob_deq].vrfwr <= FALSE;
			rob[rob_deq].jump <= FALSE;
			if (rob_deq != rob_que) begin
				if (rob_deq >= ROB_ENTRIES-1)
					rob_deq <= 6'd0;
				else
					rob_deq <= rob_deq + 2'd1;
			end
		end
	end
/*
	else begin
		rob[rob_deq].v <= INV;
		rob[rob_deq].ui <= INV;
		rob[rob_deq].cause <= FLT_NONE;
		rob[rob_deq].cmt <= FALSE;
		rob[rob_deq].jump <= FALSE;
		rob[rob_deq].branch <= FALSE;
		rob_deq <= rob_deq + 2'd1;
	end
*/
/*
	for (n = 0; n < 64; n = n + 1) begin
		for (m = 0; m < 64; m = m + 1) begin
			if (!rob[n].iav && rob[n].ias.rid==m && rob[m].cmt2) begin
				rob[n].iav <= TRUE;
				rob[n].ia <= rob[m].res;
			end
			if (!rob[n].ibv && rob[n].ibs.rid==m && rob[m].cmt2) begin
				rob[n].ibv <= TRUE;
				rob[n].ib <= rob[m].res;
			end
			if (!rob[n].icv && rob[n].ics.rid==m && rob[m].cmt2) begin
				rob[n].icv <= TRUE;
				rob[n].ic <= rob[m].res;
			end
			if (!rob[n].idv && rob[n].ids.rid==m && rob[m].cmt2) begin
				rob[n].idv <= TRUE;
				rob[n].id <= rob[m].res;
			end
			if (!rob[n].itv && rob[n].its.rid==m && rob[m].cmt2) begin
				rob[n].itv <= TRUE;
			end
		end
	end
*/
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		for (m = 0; m < 4; m = m + 1) begin
			if (!rob[n].iav && rob[n].ias.rid==funcUnit[m].rid && rob[n].ia_ele==funcUnit[m].ele) begin
				rob[n].iav <= TRUE;
				rob[n].ia <= funcUnit[m].res;
			end
			if (!rob[n].ibv && rob[n].ibs.rid==funcUnit[m].rid && rob[n].ib_ele==funcUnit[m].ele) begin
				rob[n].ibv <= TRUE;
				rob[n].ib <= funcUnit[m].res;
			end
			if (!rob[n].icv && rob[n].ics.rid==funcUnit[m].rid && rob[n].ic_ele==funcUnit[m].ele) begin
				rob[n].icv <= TRUE;
				rob[n].ic <= funcUnit[m].res;
			end
			if (!rob[n].idv && rob[n].ids.rid==funcUnit[m].rid && rob[n].id_ele==funcUnit[m].ele) begin
				rob[n].idv <= TRUE;
				rob[n].id <= funcUnit[m].res;
			end
		end
	end
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Decode
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
//	if (a2d_out.Stream == dcStream && pop_a2dd)// && !dcStall)
	if (push_d2x) begin
		if (decbuf.rfwr) begin
			regfilesrc[fnNextAllocReg(decbuf.Rt[5:0])].rf <= 1'b1;
			regfilesrc[fnNextAllocReg(decbuf.Rt[5:0])].rid <= rob_que;
		end
		if (decbuf.vrfwr) begin
			vregfilesrc[decbuf.Rt[5:0]].rf <= 1'b1;
			vregfilesrc[decbuf.Rt[5:0]].rid <= rob_que;
		end
	end


// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
// Handle multipler type operations.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  

	case (mul_state)
MUL1:
	if (!x2mul_empty) begin
		x2mul_rd <= TRUE;
		mul_state <= MUL2;
	end
MUL2:
	begin
		case(mulreco.ir.r2.opcode)
		R3:
			begin
				case(mulreco.ir.r2.func)
				MUL,MULH:
					if (rob[mulreco.rid].iav && rob[mulreco.rid].ibv) begin
						mul_sign <= rob[mulreco.rid].ia[63] ^ rob[mulreco.rid].ib[63];
						mul_a <= rob[mulreco.rid].ia[63] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
						mul_b <= rob[mulreco.rid].ib[63] ? - rob[mulreco.rid].ib : rob[mulreco.rid].ib;
						mul_state <= MUL3;
					end
				MULSU,MULSUH:
					if (rob[mulreco.rid].iav && rob[mulreco.rid].ibv) begin
						mul_sign <= rob[mulreco.rid].ia[63];
						mul_a <= rob[mulreco.rid].ia[63] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
						mul_b <= rob[mulreco.rid].ib;
						mul_state <= MUL3;
					end
				MULU,MULUH:
					if (rob[mulreco.rid].iav && rob[mulreco.rid].ibv) begin
						mul_sign <= 1'b0;
						mul_a <= rob[mulreco.rid].ia;
						mul_b <= rob[mulreco.rid].ib;
						mul_state <= MUL3;
					end
				default:	;
				endcase
			end
		MULI:
			if (rob[mulreco.rid].iav) begin
				mul_sign <= rob[mulreco.rid].ia[63] ^ mulreco.imm[63];
				mul_a <= rob[mulreco.rid].ia[63] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
				mul_b <= mulreco.imm[63] ? - mulreco.imm : mulreco.imm;
				mul_state <= MUL3;
			end
		MULSUI:
			if (rob[mulreco.rid].iav) begin
				mul_sign <= rob[mulreco.rid].ia[63];
				mul_a <= rob[mulreco.rid].ia[63] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
				mul_b <= mulreco.imm;
				mul_state <= MUL3;
			end
		MULUI:
			if (rob[mulreco.rid].iav) begin
				mul_sign <= 1'b0;
				mul_a <= rob[mulreco.rid].ia;
				mul_b <= mulreco.imm;
				mul_state <= MUL3;
			end
		default:	;
		endcase
	end
MUL3:
	begin
		rob[mulreco.rid].res <= mul_sign ? -mul_p[63:0] : mul_p;
		rob[mulreco.rid].cmt <= TRUE;
		rob[mulreco.rid].cmt2 <= TRUE;
		funcUnit[FU_MUL].res <= mul_sign ? -mul_p[63:0] : mul_p;
		funcUnit[FU_MUL].rid <= mulreco.rid;
		case(mulreco.ir[7:0])
		R3:
			begin
				case(mulreco.ir.r2.func)
				MULH:		begin funcUnit[FU_MUL].res <= mul_sign ? -mul_p[127:64] : mul_p[127:64]; funcUnit[FU_MUL].rid <= mulreco.rid; rob[mulreco.rid].res <= mul_sign ? -mul_p[127:64] : mul_p[127:64]; end
				MULSUH:	begin funcUnit[FU_MUL].res <= mul_sign ? -mul_p[127:64] : mul_p[127:64]; funcUnit[FU_MUL].rid <= mulreco.rid; rob[mulreco.rid].res <= mul_sign ? -mul_p[127:64] : mul_p[127:64]; end
				MULUH:	begin funcUnit[FU_MUL].res <= mul_p[127:64]; funcUnit[FU_MUL].rid <= mulreco.rid; rob[mulreco.rid].res <= mul_p[127:64]; end
				default:	;
				endcase
			end
		default:	;
		endcase
		mul_state <= MUL1;
	end
default:
	mul_state <= MUL1;
	endcase

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
// Handle divide type operations.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  

	case (div_state)
DIV1:
	if (!x2div_empty) begin
		x2div_rd <= TRUE;
		div_state <= DIV2;
	end
DIV2:
		case(divreco.ir[7:0])
		R3:
			if (rob[divreco.rid].iav && rob[divreco.rid].ibv)
			begin
				case(divreco.ir.r2.func)
				DIV:
					begin
						div_sign <= rob[divreco.rid].ia[63] ^ rob[divreco.rid].ib[63];
						div_a <= rob[divreco.rid].ia[63] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
						div_b <= rob[divreco.rid].ib[63] ? - rob[divreco.rid].ib : rob[divreco.rid].ib;
						div_state <= DIV3;
					end
				DIVU:
					begin
						div_sign <= 1'b0;
						div_a <= rob[divreco.rid].ia;
						div_b <= rob[divreco.rid].ib;
						div_state <= DIV3;
					end
				DIVSU:
					begin
						div_sign <= rob[divreco.rid].ia[63];
						div_a <= rob[divreco.rid].ia[63] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
						div_b <= rob[divreco.rid].ib;
						div_state <= DIV3;
					end
				default:	;			
				endcase
			end
		DIVI:
			if (rob[divreco.rid].iav) begin
				div_sign <= rob[divreco.rid].ia[63] ^ divreco.imm[63];
				div_a <= rob[divreco.rid].ia[63] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
				div_b <= divreco.imm[63] ? - divreco.imm : divreco.imm;
				div_state <= DIV3;
			end
		DIVUI:
			if (rob[divreco.rid].iav) begin
				div_sign <= 1'b0;
				div_a <= rob[divreco.rid].ia;
				div_b <= divreco.imm;
				div_state <= DIV3;
			end
		DIVSUI:
			if (rob[divreco.rid].iav) begin
				div_sign <= rob[divreco.rid].ia[63];
				div_a <= rob[divreco.rid].ia[63] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
				div_b <= divreco.imm;
				div_state <= DIV3;
			end
		default:	;			
		endcase
DIV3:
	div_state <= DIV4;
DIV4:
	if (div_done) begin
		rob[divreco.rid].res <= div_sign ? -div_q[63:0] : div_q;
		rob[divreco.rid].cmt <= TRUE;
		rob[divreco.rid].cmt2 <= TRUE;
		funcUnit[FU_DIV].res <= div_sign ? -div_q[63:0] : div_q;
		funcUnit[FU_DIV].rid <= divreco.rid;
		case(divreco.ir[7:0])
		R3:
			begin
				case(divreco.ir.r2.func)
				default:	;
				endcase
			end
		default:	;
		endcase
		div_state <= DIV1;
	end
	default:
		div_state <= DIV1;
	endcase

end	// clock domain

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

task tMemory1;
begin
	mgoto (MEMORY1);
/*
	iaccess <= FALSE;
	daccess <= FALSE;
  icnt <= 4'd0;
  dcnt <= 4'd0;
	if (ihit)
	begin
		if (!x2m_empty) begin
			x2m_rd <= TRUE;
			zero_data <= FALSE;
			mgoto (MEMORY1c);
		end
		else
			mgoto (MEMORY1);
	end
	else begin
`ifdef ANY1_TLB
    mgoto (IFETCH2a);
`else
    mgoto (IFETCH3);
`endif
`ifdef VICTIM_CACHE
		for (n = 0; n < 5; n = n + 1) begin
			if (ivtag[n]==iadr[AWID-1:6] && ivvalid[n]) begin
				tLICache(lfsr_o[1:0],ivtag[n],ivcache[n],ivvalid[n]);
	    	mgoto (MEMORY1);
    	end
		end
`endif
  end
*/
end
endtask

task tBackupRegfileSrc;
input [3:0] ndx;
begin
	for (n = 0; n < 128; n = n + 1)
		regfilesrc_hist[ndx][n] <= regfilesrc[n];
	for (n = 0; n < 64; n = n + 1)
		regmap_hist[ndx][n] <= regmap[n];
	regalloc_hist[ndx] <= regalloc;
end
endtask

task tRestoreRegfileSrc;
input [3:0] ndx;
begin
	for (n = 0; n < 128; n = n + 1)
		regfilesrc[n] <= regfilesrc_hist[ndx][n];
	for (n = 0; n < 64; n = n + 1)
		regmap[n] <= regmap_hist[ndx][n];
	regalloc <= regalloc_hist[ndx];
end
endtask

task tCopyRegfileSrc;
input [3:0] dst;
input [3:0] src;
begin
	for (n = 0; n < 64; n = n + 1)
		regfilesrc_hist[dst][n] <= regfilesrc_hist[src][n];
end
endtask

task tZeroRegfileSrc;
input [3:0] dst;
begin
	for (n = 0; n < 128; n = n + 1) begin
		regfilesrc[n].rf <= 1'b0;
		regfilesrc[n].rid <= 6'h0;
		regfilesrc_hist[dst][n].rf <= 1'b0;
		regfilesrc_hist[dst][n].rid <= 6'h0;
	end
end
endtask

task tReadCSR;
output Value res;
input [15:0] regno;
begin
	if (regno[14:12] <= omode) begin
		casez(regno[15:0])
		CSR_DCR0:	res.val <= cr0;
		CSR_MCR0:	res.val <= cr0;
		CSR_SEMA: res.val <= sema;
		CSR_ASID:	res.val <= ASID;
		CSR_MBADADDR:	res.val <= badaddr[regno[14:12]];
		CSR_TICK:	res.val <= tick;
		CSR_CAUSE:	res.val <= cause[regno[14:12]];
		CSR_MTVEC,CSR_DTVEC:
			res.val <= tvec[regno[2:0]];
		CSR_DPMSTACK:	res.val <= pmStack;
		CSR_MPMSTACK:	res.val <= pmStack;
		CSR_DEIP: res.val <= eip;
		CSR_MEIP: res.val <= eip;
		CSR_TIME:	res.val <= wc_time;
		CSR_MSTATUS:	res.val <= status[4];
		CSR_DSTATUS:	res.val <= status[4];
		default:	res.val <= 64'd0;
		endcase
	end
	else
		res <= 60'd0;
end
endtask

task tWriteCSR;
input Value val;
input [15:0] regno;
begin
	if (regno[14:12] <= omode) begin
		casez(regno[15:0])
		CSR_DCR0:		cr0 <= val.val;
		CSR_MCR0:		cr0 <= val.val;
		CSR_SEMA:		sema <= val.val;
		CSR_ASID: 	ASID <= val.val;
		CSR_MBADADDR:	badaddr[regno[14:12]] <= val.val;
		CSR_CAUSE:	cause[regno[14:12]] <= val.val;
		CSR_MTVEC,CSR_DTVEC:
			tvec[regno[2:0]] <= val.val;
		CSR_DPMSTACK:	pmStack <= val.val;
		CSR_MPMSTACK:	pmStack <= val.val;
		CSR_DEIP:	eip <= val.val;
		CSR_MEIP:	eip <= val.val;
		CSR_DTIME:	begin wc_time_dat <= val.val; ld_time <= TRUE; end
		CSR_MTIME:	begin wc_time_dat <= val.val; ld_time <= TRUE; end
		CSR_DSTATUS:	status[4] <= val.val;
		CSR_MSTATUS:	status[4] <= val.val;
		default:	;
		endcase
	end
end
endtask

task tSetbitCSR;
input Value val;
input [15:0] regno;
begin
	if (regno[14:12] <= omode) begin
		casez(regno[15:0])
		CSR_DCR0:			cr0[val.val[5:0]] <= 1'b1;
		CSR_MCR0:			cr0[val.val[5:0]] <= 1'b1;
		CSR_SEMA:			sema[val.val[5:0]] <= 1'b1;
		CSR_DPMSTACK:	pmStack <= pmStack | val.val;
		CSR_MPMSTACK:	pmStack <= pmStack | val.val;
		CSR_DSTATUS:	status[4] <= status[4] | val.val;
		CSR_MSTATUS:	status[4] <= status[4] | val.val;
		default:	;
		endcase
	end
end
endtask

task tClrbitCSR;
input Value val;
input [15:0] regno;
begin
	if (regno[14:12] <= omode) begin
		casez(regno[15:0])
		CSR_DCR0:			cr0[val.val[5:0]] <= 1'b0;
		CSR_MCR0:			cr0[val.val[5:0]] <= 1'b0;
		CSR_SEMA:			sema[val.val[5:0]] <= 1'b0;
		CSR_DPMSTACK:	pmStack <= pmStack & ~val.val;
		CSR_MPMSTACK:	pmStack <= pmStack & ~val.val;
		CSR_DSTATUS:	status[4] <= status[4] & ~val.val;
		CSR_MSTATUS:	status[4] <= status[4] & ~val.val;
		default:	;
		endcase
	end
end
endtask

task tLICache;
input [1:0] way;
input Address tagval;
input [511:0] lineval;
input valval;
begin
`ifdef VICTIM_CACHE
	case(way)
	2'd0:	begin ictag0[iadr[pL1msb:6]] <= tagval; ivtag[ivcnt] <= ictag0[iadr[pL1msb:6]]; end
	2'd1:	begin ictag1[iadr[pL1msb:6]] <= tagval; ivtag[ivcnt] <= ictag1[iadr[pL1msb:6]]; end
	2'd2:	begin ictag2[iadr[pL1msb:6]] <= tagval; ivtag[ivcnt] <= ictag2[iadr[pL1msb:6]]; end
	2'd3:	begin ictag3[iadr[pL1msb:6]] <= tagval; ivtag[ivcnt] <= ictag3[iadr[pL1msb:6]]; end
	endcase
	case(way)
	2'd0:	begin icache0[iadr[pL1msb:6]] <= lineval; ivcache[ivcnt] <= icache0[iadr[pL1msb:6]]; end
	2'd1:	begin icache1[iadr[pL1msb:6]] <= lineval; ivcache[ivcnt] <= icache1[iadr[pL1msb:6]]; end
	2'd2:	begin icache2[iadr[pL1msb:6]] <= lineval; ivcache[ivcnt] <= icache2[iadr[pL1msb:6]]; end
	2'd3:	begin icache3[iadr[pL1msb:6]] <= lineval; ivcache[ivcnt] <= icache3[iadr[pL1msb:6]]; end
	endcase
	case(way)
	2'd0:	begin icvalid0[iadr[pL1msb:6]] <= valval; ivvalid[ivcnt] <= icvalid0[iadr[pL1msb:6]]; end
	2'd1:	begin icvalid1[iadr[pL1msb:6]] <= valval; ivvalid[ivcnt] <= icvalid1[iadr[pL1msb:6]]; end
	2'd2:	begin icvalid2[iadr[pL1msb:6]] <= valval; ivvalid[ivcnt] <= icvalid2[iadr[pL1msb:6]]; end
	2'd3:	begin icvalid3[iadr[pL1msb:6]] <= valval; ivvalid[ivcnt] <= icvalid3[iadr[pL1msb:6]]; end
	endcase
`else

	ictag[way][iadr[pL1msb:6]] <= tagval;
//	icvalid[way][iadr[pL1msb:6]] <= valval;

`endif
end
endtask

task tEA;
input Address iea;
begin
  if (MUserMode && d_st && !ea_acr[1])
    rob[membufo.rid].cause <= 16'h8032;
  else if (MUserMode && d_ld && !ea_acr[2])
    rob[membufo.rid].cause <= 16'h8033;
	if (!MUserMode || iea[AWID-1:24]=={AWID-24{1'b1}})
		dadr <= iea;
	else
		dadr <= iea[AWID-4:0] + {sregfile[segsel][AWID-1:4],`SEG_SHIFT};
end
endtask

/*
task tPC;
begin
  if (UserMode & !pc_acr[0])
    tException(32'h80000002,ip);
	if (!UserMode || ip[AWID-1:24]=={AWID-24{1'b1}})
		ladr <= ip;
	else
		ladr <= ip[AWID-2:0] + {sregfile[ip[AWID-1:AWID-4]][AWID-1:4],`SEG_SHIFT};
end
endtask
*/
task tPMAEA;
begin
  if (keyViolation && omode == 3'd0)
    rob[membufo.rid].cause <= 16'h8031;
  // PMA Check
  for (n = 0; n < 8; n = n + 1)
    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
      if ((d_st && !PMA_AT[n][1]) || (d_ld && !PMA_AT[n][2]))
		    rob[membufo.rid].cause <= 16'h803D;
		  dcachable <= PMA_AT[n][3];
    end
end
endtask

task tPMAIP;
begin
  // PMA Check
  // Abort cycle that has already started.
  for (n = 0; n < 8; n = n + 1)
    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
      if (!PMA_AT[n][0]) begin
        rob[rob_que].cause <= 16'h803D;
        cyc_o <= LOW;
    		stb_o <= LOW;
    		vpa_o <= LOW;
    		sel_o <= 4'h0;
    	end
    end
end
endtask

task mgoto;
input [5:0] nst;
begin
	mstate <= nst;
end
endtask

task mgosub;
input [5:0] nst;
begin
	mstk_state <= mstate;
	mstate <= nst;
end
endtask

task mret();
begin
	mstate <= mstk_state;
end
endtask

task tAllocReg;
input [5:0] Rt;
output reg [6:0] mreg;
begin
	mreg <= 7'd0;
	for (n = 0; n < 64; n = n + 1) begin
		if (regalloc[n]==1'b0) begin
			regalloc[n] <= 1'b1;
			mreg <= {1'b1,n[5:0]};
			regmap[Rt] <= {1'b1,n[5:0]};
		end
	end
end
endtask

endmodule
