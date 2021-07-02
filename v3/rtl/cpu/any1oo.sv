// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1oo.sv
// ANY1 processor implementation.
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
import fp::*;

module any1oo(hartid_i, rst_i, clk_i, wc_clk_i, nmi_i, irq_i, cause_i,
	vpa_o, vda_o, bte_o, cti_o, bok_i, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o,
	dat_i, dat_o, sr_o, cr_o, rb_i);
input [63:0] hartid_i;
input rst_i;
input clk_i;
input wc_clk_i;
input nmi_i;
input [3:0] irq_i;
input [7:0] cause_i;
output vpa_o;
output vda_o;
output [1:0] bte_o;
output [2:0] cti_o;
input bok_i;
output cyc_o;
output stb_o;
input ack_i;
output we_o;
output [15:0] sel_o;
output [AWID-1:0] adr_o;
input [127:0] dat_i;
output [127:0] dat_o;
output sr_o;		// set memory reservation
output cr_o;		// clear memory reservation
input rb_i;					// input memory still reserved bit

integer j,k,n,m;
genvar g;
wire clk_g;
wire acki = ack_i;


wire [2:0] omode;
wire [2:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode, DebugMode;
wire MUserMode;

Instruction ir;
sFuncUnit [5:0] funcUnit;
sInstAlignIn f2a_in;
sInstAlignOut a2d_in,a2d_out,a3d;
sDecode decbuf;
sExecute exbufi, exbufo;
sMemoryIO membufi,membufi1;
sReorderEntry [ROB_ENTRIES-1:0] rob;
sALUrec mulreci,mulreco, divreci, divreco, fpreci,fpreco;
sGraphicsOp graphi,grapho;
sFuncUnit memfu;
reg [2:0] mod_cnt;
sInstAlignOut [7:0] mod_list;
wire ihit;

reg x2mul_wr,x2mul_rd;
wire x2mul_full,x2mul_empty;
reg x2fp_wr,x2fp_rd;
wire x2fp_full,x2fp_empty;
reg mul_sign;
Value mul_a;
Value mul_b;
reg [VALUE_SIZE*2-1:0] mul_p;
reg [5:0] rob_que, prev_rob_que, prev_rob_dec, prev_rob_dec2;
reg [5:0] rob_deq;
reg [5:0] rob_exec, rob_pexec, safe_rob_exec, rob_dec;
always_comb
	safe_rob_exec = rob_exec==6'd63 ? rob_pexec : rob_exec;
reg [5:0] mstate, mstk_state;			// memory state
reg [2:0] mul_state;	// multipler state
reg [2:0] div_state;
reg [2:0] fp_state;
reg [2:0] gr_state;
reg [63:0] csrro;
reg [47:0] rob_q, rob_d;
wire [47:0] rob_x;
wire [pL1ICacheLineSize-1:0] ic_line;

function [7:0] fnBackupCnt;
input [5:0] qp;
integer n,m,k;
begin
	m = rob_que;
	k = 0;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (m==rob_exec)
			fnBackupCnt = k;
		else begin
			m = m - 1;
			if (m <= 0)
				m = ROB_ENTRIES - 1;
			k = k + 1;
		end
	end
end
endfunction
/*
function [63:0] fnBranchInvalidateMask;
input [5:0] xp;
input [5:0] dqp;
integer n,m,done;
begin
	m = xp;
	done = FALSE;
	fnBranchInvalidateMask = 64'h0;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (m==dqp)
			done = TRUE;
		if (!done)
			fnBranchInvalidateMask[n] = 1'b1;
		m = m + 1;
		if (m >= ROB_ENTRIES)
			m = 0;
	end
end
endfunction

wire [63:0] branchInvalidateMask = fnBranchInvalidateMask(rob_exec);
wire [63:0] wbBranchInvalidateMask = fnBranchInvalidateMask(wb_redirecto.xrid);
wire [63:0] exBranchInvalidateMask = fnBranchInvalidateMask(ex_redirecto.xrid);
wire [63:0] dcBranchInvalidateMask = fnBranchInvalidateMask(dc_redirecto.xrid);
*/

function Address fnIPInc;
input Address pc;
begin
	fnIPInc = {pc[AWID-1:24],pc[23:-1] + 4'd9};
end
endfunction

function [ROB_ENTRIES-1:0] fnOlderInst;
input [5:0] ridi;
input [5:0] qp;		// que position
integer n,m,done;
begin
	m = ridi;
	fnOlderInst = {ROB_ENTRIES{1'b0}};
	done = FALSE;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (!done)
			fnOlderInst[m] = TRUE;
		if (m==qp)
			done = TRUE;
		m = m - 1;
		if (m < 0)
			m = ROB_ENTRIES-1;
	end
end
endfunction

function [5:0] fnQp1;
input [5:0] q;
begin
	fnQp1 = q >= ROB_ENTRIES-1 ? 6'd0 : q + 2'd1;
end
endfunction

function [ROB_ENTRIES-1:0] fnNewerInst;
input [5:0] ridi;
integer n;
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		fnNewerInst[n] = rob[n].rob_q > rob[ridi].rob_q;
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
Value div_a;
Value div_b;

wire [VALUE_SIZE*2-1:0] div_q;
wire [VALUE_SIZE*2-1:0] ndiv_q = -div_q;
Value div_r = div_a - (div_b * div_q[VALUE_SIZE*2-1:VALUE_SIZE]);
Value ndiv_r = -div_r;
fpdivr16 #(VALUE_SIZE) u16 (
	.clk(clk_g),
	.ld(div_state==DIV3),
	.a(div_a),
	.b(div_b),
	.q(div_q),
	.r(),
	.done(div_done)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Graphics
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


Address ip;											// Instruction pointer

Value regfile [0:31];
Rid regfilesrc [0:31];					// bit 7 = 0 = regfile, 1 = reorder buffer
Rid regfilesrc_hist [0:15][0:31];
reg [WID-1:0] sregfile [0:15];
wire restore_rfsrc;
Rid vregfilesrc [0:63];					// bit 7 = 0 = regfile, 1 = reorder buffer
Rid vregfilesrc_hist [0:15][0:63];
Rid vm_regfilesrc [0:7];
Rid vm_regfilesrc_hist[0:15][0:7];

reg vrf_update;
reg [11:0] vrf_wa;
reg [63:0] vrf_din;
wire [63:0] vrfoA, vrfoB;
wire [11:0] vrf_raA = {decbuf.RaStep,decbuf.Ra[4:0]};
wire [11:0] vrf_raB = {decbuf.RbStep,decbuf.Rb[4:0]};

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

reg [63:0] vm_regfile [0:7];

reg [3:0] active_branch;
reg dc2if_redirect_rd;
Address dc_redirect_ip;
sRedirect dc_redirecti,ex_redirecti,mem_redirecti,wb_redirecti;
sRedirect dc_redirecto,ex_redirecto,wb_redirecto;
reg ex2if_redirect_rd,wb2if_redirect_rd;
reg dc2if_redirect_rd2,ex2if_redirect_rd2,wb2if_redirect_rd2;
reg dc2if_redirect_rd3,ex2if_redirect_rd3,wb2if_redirect_rd3;
wire dc2if_redirect_empty,ex2if_redirect_empty,wb2if_redirect_empty;

reg x2m_rd,x2g_rd;
wire f2a_empty;
wire a2d_empty;
wire d2x_empty;
wire x2m_empty;
wire x2g_empty;
reg dc2if_wr,ex2if_wr,wb2if_wr;
reg exfifo_rd;
reg memfifo_wr;

//CSRs
Value scratch [0:7];
reg [63:0] tcbptr;							// task control block pointer
reg [63:0] cr0;
wire bpe = cr0[32];
wire btben = cr0[33];
wire dce;
wire sple = cr0[35];
wire tag_mode = cr0[36];
reg [63:0] tick;
Address tvec [0:7];
reg [7:0] cause [0:7];
Address badaddr [0:7];
Address eip;
reg [5:0] estep;
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
reg [63:0] keys2 [0:3];
reg [19:0] keys [0:7];
always_comb
begin
	keys[0] = keys2[0][19:0];
	keys[1] = keys2[0][39:20];
	keys[2] = keys2[0][59:40];
	keys[3] = keys2[1][19:0];
	keys[4] = keys2[1][39:20];
	keys[5] = keys2[1][59:40];
	keys[6] = keys2[2][19:0];
	keys[7] = keys2[2][39:20];
end
reg [7:0] vl;
reg [47:0] ifStalls;
reg [47:0] insnCommitted;
Rect gr_target;
Rect gr_clip;
reg [63:0] gr_ctrl;
wire clip_en = gr_ctrl[5];

reg fdz,fnv,fof,fuf,fnx;
reg [63:0] fpscr;
wire [2:0] rm = fpscr[46:44];
wire [31:0] fscsr = {rm,fnv,fdz,fof,fuf,fnx};

sMemoryIO membufo;
wire d_cache = membufo.ir.r2.opcode==CACHE;
wire d_st = membufo.ir.r2.opcode==STx||membufo.ir.r2.opcode==STxX;
wire d_ld = membufo.ir.r2.opcode==LDx||membufo.ir.r2.opcode==LDxX;

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
wire [15:0] selx;
any1_select ua1sel
(
	.ir(rob[memreq.tid[5:0]].ir),
	.sel(selx)
);

Address ea;


// Detect if data overflows a cache line, meaning two lines need to be read.
wire
data_overflow = (selx==8'hFF && ea[5:0] > 6'd56) ||
								(selx==8'h0F && ea[5:0] > 6'd60) ||
								(selx==8'h03 && ea[5:0] > 6'd62)
								;

function [5:0] fnIncNdx;
input [5:0] ndx;
begin
	if (ndx>=6'd15)
		ndx <= 6'd0;
	else
		ndx <= ndx + 2'd1;
end
endfunction

wire memresp_empty;
wire memresp_v;
always_comb
if (memresp_v) begin
	memfu.rid <= memresp.tid[5:0];
	memfu.cmt <= memresp.cmt;
	memfu.ele <= memresp.step;
	if (memresp.ret)
		memfu.res <= rob[memresp.tid[5:0]].res;
	else
		memfu.res <= memresp.res;
	memfu.res2 <= rob[memresp.tid[5:0]].ib;
	memfu.cause <= memresp.cause;
	memfu.badAddr <= memresp.badAddr;
end
else begin
	memfu.rid <= 6'd63;
	memfu.cmt <= FALSE;
	memfu.ele <= 6'd0;
	memfu.res <= 128'd0;
	memfu.res2 <= 64'd0;
	memfu.cause <= 16'h0000;
	memfu.badAddr <= 33'd0;
end

always_comb
	funcUnit[FU_MEM] <= memfu;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire ex_takb;
any1_eval_branch ubev1
(
	.inst(rob[safe_rob_exec].ir),
	.a(rob[safe_rob_exec].ia),
	.b(rob[safe_rob_exec].ib),
	.takb(ex_takb)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

any1_agen uagen
(
	.rst(rst_i),
	.clk(clk_g),
	.ir(membufi.ir),
	.ia(membufi.ia),
	.ib(membufi.ib),
	.ic(membufi.ic),
	.imm(membufi.imm),
	.step(membufi.step),
	.ea(ea)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Trace
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg wr_trace;
wire rd_trace;
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
// Branch target buffer.
//
// Access to the branch target buffer must be within one clock cycle, so it
// is composed of LUT ram.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Address btb_predicted_ip;
BTBEntry btb [0:511];
initial begin
	for (n = 0; n < 512; n = n + 1) begin
		btb[n].addr <= 33'd0;
		btb[n].tag <= 1'd0;
		btb[n].v <= INV;
	end
end
always_comb
	if (btb[ip[11:3]].tag==ip[AWID-1:12] && btb[ip[11:3]].v)
		btb_predicted_ip <= btb[ip[11:3]].addr;
	else
		btb_predicted_ip <= fnIPInc(ip);

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
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

wire ifStall;
reg ifStall1,ifStall2,ifStall3;
wire f2a_full, f2a_v;
wire a2d_full, a2d_v;
wire d2r_full, d2r_v;
wire d2x_full, d2x_v;
wire x2m_full, x2m_v;
wire x2g_full, x2g_v;
wire d2x_underflow;
reg d2x_full1,d2x_full2;
reg [5:0] decven;
reg push_vec;
//wire ifStall = f2a_full || !ihit;
assign a2d_full = 1'b0;
assign a2d_v = 1'b1;
assign ifStall = !ihit || d2x_full;	// || push_vec;
reg dcStall,dcStall1,vecStall;
wire f2a_rst,a2d_rst,d2x_rst;
reg wb_f2a_rst,wb_a2d_rst,wb_d2x_rst;

reg pop_f2ad,pop_a2dd,pop_d2xd;
wire push_f2a = !ifStall && !f2a_full;// && rob_que+2'd1 != rob_deq;
wire pop_f2a = !a2d_full && !f2a_empty;

function [5:0] fnNext;
input [5:0] q;
begin
	if (q + 2'd1 > ROB_ENTRIES - 1)
		fnNext = 6'd0;
	else
		fnNext = q + 2'd1;
end
endfunction

wire [5:0] que_nxt1 = fnNext(rob_que);
wire [5:0] que_nxt2 = fnNext(que_nxt1);
assign d2x_full = que_nxt1==rob_deq || que_nxt2==rob_deq;
wire push_a2d = !d2x_full && !a2d_full && !ifStall2;// && (!ifStall3 || ifStall4); //pop_f2ad;
wire pop_a2d = !d2x_full && !vecStall && !ifStall3;
//wire push_d2x = (a2d_v || push_vec) && (!ifStall || push_vec) && !d2x_full;
wire push_d2x = !ifStall && !d2x_full;
wire pop_d2x = !x2m_full && !x2mul_full && !x2div_full && !d2x_empty;

always_comb	
	push_vec <= decbuf.is_vec && !decbuf.vex && !decbuf.veins && decven < vl && mod_cnt==3'd0;
always_comb
	vecStall <= decbuf.is_vec && !decbuf.vex && !decbuf.veins && decven < vl && mod_cnt==3'd0;

reg push_vec2;
always @(posedge clk_g)
if (rst_i)
	push_vec2 <= 1'b0;
else
	push_vec2 <= push_vec;
always @(posedge clk_g)
if (rst_i)
	d2x_full1 <= 1'b0;
else
	d2x_full1 <= d2x_full;
always @(posedge clk_g)
if (rst_i)
	d2x_full2 <= 1'b0;
else
	d2x_full2 <= d2x_full1;

always @(posedge clk_g)
if (rst_i)
	ifStalls <= 48'd0;
else
	ifStalls <= ifStalls + ifStall;

always @(posedge clk_g)
if (rst_i)
	ifStall1 <= 1'b0;
else
	ifStall1 <= ifStall;
always @(posedge clk_g)
if (rst_i)
	ifStall2 <= 1'b0;
else
	ifStall2 <= ifStall1;
always @(posedge clk_g)
if (rst_i)
	ifStall3 <= 1'b0;
else
	ifStall3 <= ifStall2;

always @(posedge clk_g)
	dcStall1 <= dcStall;
always @(posedge clk_g)
	pop_f2ad <= pop_f2a;
always @(posedge clk_g)
	pop_a2dd <= pop_a2d || (dcStall1 && !dcStall);
always @(posedge clk_g)
	pop_d2xd <= pop_d2x;

Address ip1;
Address btb_predicted_ip1;
reg predict_taken1;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

// The following two decodes must be extremely fast as there is only 1/2 clock 
// available.

reg [127:0] is_vector;
generate begin : gIsVec
begin
	for (g = 0; g < 512; g = g + 4) begin
	always_comb
		is_vector[g>>2] <= ic_line[g+7];
	end
end
end
endgenerate

reg [127:0] is_modifier;
generate begin : gIsMod
begin
	for (g = 0; g < 512; g = g + 4) begin
	always_comb
		is_modifier[g>>2] <= ic_line[g+6:g+4]==3'd5;
	end
end
end
endgenerate

wire [ROB_ENTRIES-1:0] newer_than_robo = fnNewerInst(robo.rid);
wire [ROB_ENTRIES-1:0] newer_than_wb = fnNewerInst(wb_redirecto.xrid);
wire [ROB_ENTRIES-1:0] newer_than_mem = fnNewerInst(mem_redirecti.xrid);
wire [ROB_ENTRIES-1:0] newer_than_ex = fnNewerInst(ex_redirecti.xrid);

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
*/
// Instruction align combo logic
any1_ialign uia1
(
	.i(f2a_in),
	.o(a2d_in)
);

/*
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
*/
reg decra;
wire [5:0] Rmo, Rmi;
any1_decode udec1
(
	.ir(rob[rob_dec].ir),
	.decbuf(decbuf),
	.predicted_ip(btb_predicted_ip),
	.ven(decven)
);


// Detect if there are only committed instructions in the queue before this
// one.
function fnCmtsAhead;
input [5:0] ridi;
integer n, m, pos, done;
begin
	pos = -1;
	done = 0;
	m = ridi;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (m==rob_que)
			done = 1;
		if (!(rob[m].cmt && rob[m].cause==16'h0 || !rob[m].v) && !done && m != ridi)
			pos = m;
		m = m - 1;
		if (m < 0)
			m = ROB_ENTRIES-1;
	end
	fnCmtsAhead = pos==-1;
end
endfunction

function [5:0] fnNextDec;
input [5:0] cdec;
integer n,m, done;
begin
	fnNextDec = 6'd63;
	done = FALSE;
	m = cdec + 1;
	if (m >= ROB_ENTRIES)
		m = 0;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (!rob[m].dec && !done) begin
			fnNextDec = m;
			done = TRUE;
		end
		m = m + 1;
		if (m >= ROB_ENTRIES)
			m = 0;
	end
end
endfunction

// Store operations use Rc.
function regValid;
input [6:0] rg;
begin
	regValid = 	rg[6] ||
							rg[4:0]==5'd0 ||
							rg[4:0]==5'd31 ||
							regfilesrc[rg[4:0]].rf == 1'd0 ||
							rob[regfilesrc[rg[4:0]].rid].cmt
							;
end
endfunction

function [63:0] fnWidenAddress;
input Address rAddr;
begin
	fnWidenAddress = {{32{rAddr[31]}},rAddr};
end
endfunction

always_comb
	if (decbuf.Ra[4:0]==5'd0)
		exbufi.ia.val <= {VALUE_SIZE{1'd0}};
	else if (decbuf.Ravec)
		exbufi.ia.val <= vregfilesrc[decbuf.Ra[4:0]].rf==1'b0 ? vrfoA : {VALUE_SIZE/16{16'hDEAD}};
	else if (decbuf.Ramask)
		exbufi.ia.val <= vregfilesrc[decbuf.Ra[2:0]].rf==1'b0 ? vm_regfile[decbuf.Ra[2:0]] : {VALUE_SIZE/16{16'hDEAD}};
	else if (decbuf.Ra[4:0]==5'd31)
		exbufi.ia.val <= decbuf.ip;
	else if (regfilesrc[decbuf.Ra[4:0]].rf)
		exbufi.ia.val <= rob[regfilesrc[decbuf.Ra[4:0]].rid].res.val;
	else
		exbufi.ia.val <= regfile[decbuf.Ra[4:0]].val;

always_comb
	if (decbuf.Rc[6])
		exbufi.ic.val <= decbuf.is_signed ? {{58{decbuf.Rc[5]}},decbuf.Rc[5:0]} : decbuf.Rc[5:0];
	else if (decbuf.Rc[4:0]==5'd0)
		exbufi.ic.val <= {VALUE_SIZE{1'd0}};
	else if (!decbuf.needRc)
		exbufi.ic.val <= {VALUE_SIZE{1'd0}};
	else if (decbuf.Rc[4:0]==5'd31)
		exbufi.ic.val <= decbuf.ip;
	else if (regfilesrc[decbuf.Rc[4:0]].rf)
		exbufi.ic.val <= rob[regfilesrc[decbuf.Rc[4:0]].rid].res.val; 
	else
		exbufi.ic.val <= regfile[decbuf.Rc[4:0]].val;

always_comb
	if (decbuf.Rb[6])
		exbufi.ib.val <= decbuf.is_signed ? {{58{decbuf.Rb[5]}},decbuf.Rb[5:0]} : decbuf.Rb[5:0];
	else if (decbuf.Rb[4:0]==5'd0)
		exbufi.ib.val <= {VALUE_SIZE{1'd0}};
	else if (decbuf.Rbvec)
		exbufi.ib.val <= vregfilesrc[decbuf.Rb[4:0]].rf==1'b0 ? vrfoB : {VALUE_SIZE/16{16'hDEAD}};
	else if (decbuf.Rbmask)
		exbufi.ib.val <= vregfilesrc[decbuf.Rb[2:0]].rf==1'b0 ? vm_regfile[decbuf.Rb[2:0]] : {VALUE_SIZE/16{16'hDEAD}};
	else
		exbufi.ib.val <= decbuf.Rb[4:0]==5'd31 ? decbuf.ip : regfilesrc[decbuf.Rb[4:0]].rf ? rob[regfilesrc[decbuf.Rb[4:0]].rid].res.val : regfile[decbuf.Rb[4:0]].val;

always_comb
begin
	exbufi.v <= a2d_out.v;
	exbufi.ip <= decbuf.ip;
	exbufi.pip <= decbuf.pip;
	exbufi.predict_taken <= decbuf.predict_taken;
	exbufi.branch <= decbuf.branch;
	exbufi.ir <= decbuf.ir;
	exbufi.rfwr <= decbuf.rfwr;
	exbufi.iav <= (!decbuf.needRa || (decbuf.Ravec ? (vregfilesrc[decbuf.Ra[4:0]].rf==1'b0) : decbuf.Ramask ? vm_regfilesrc[decbuf.Ra[2:0]].rf==1'b0 : regValid({1'b0,decbuf.Ra}))) && !decbuf.exec;
	exbufi.ibv <= (decbuf.Rb[6] || !decbuf.needRb || (decbuf.Rbvec ? (vregfilesrc[decbuf.Rb[4:0]].rf==1'b0) : decbuf.Rbmask ? vm_regfilesrc[decbuf.Rb[2:0]].rf==1'b0 : regValid(decbuf.Rb))) && !decbuf.exec;
	exbufi.icv <= (regValid(decbuf.Rc) || !decbuf.needRc) && !decbuf.exec;
	// To detect WAW hazard for vector instructions
	exbufi.itv <= (decbuf.Rtvec ? (vregfilesrc[decbuf.Rt[4:0]].rf==1'b0) : !decbuf.is_vec) && !decbuf.exec;
	exbufi.imm <= decbuf.imm;
	exbufi.vmask <= vm_regfile[decbuf.Vm];
	exbufi.vmv <= (vm_regfilesrc[decbuf.Vm].rf==1'b0 || rob[vm_regfilesrc[decbuf.Vm]].cmt) && !decbuf.exec;

//	dcStall <=  !(exbufi.iav & exbufi.ibv & exbufi.icv & exbufi.idv & exbufi.itv);
	dcStall <= 1'b0;//!exbufi.itv & decbuf.is_vec;
//	dcStall <= 1'b0;
end
/*
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
*/
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

x2m_fifo ux2g
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(graphi),      // input wire [134 : 0] din
  .wr_en(!x2g_full && graphi.wr),	// input wire wr_en
  .rd_en(x2g_rd),  // input wire rd_en
  .dout(grapho),    // output wire [134 : 0] dout
  .full(x2g_full),    // output wire full
  .empty(x2g_empty),  		// output wire empty
  .valid(x2g_v)  // output wire valid
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

ALU_fifo ux2fp
(
  .clk(clk_g),      // input wire clk
  .srst(rst_i),    // input wire srst
  .din(fpreci),      // input wire [134 : 0] din
  .wr_en(!x2fp_full && fpreci.wr),	// input wire wr_en
  .rd_en(x2fp_rd),  // input wire rd_en
  .dout(fpreco),    // output wire [134 : 0] dout
  .full(x2fp_full),    // output wire full
  .empty(x2fp_empty)  		// output wire empty
);

wire ex2if_redirect_v, wb2if_redirect_v, mem_redirect_v;
wire pe_ex2if_redirect_v, pe_wb2if_redirect_v, pe_mem2if_redirect_v;
wire ne_ex2if_redirect_v, ne_wb2if_redirect_v, ne_mem2if_redirect_v;
edge_det uedwb2if (.rst(rst_i), .clk(clk_g), .i(wb2if_redirect_v), .pe(pe_wb2if_redirect_v), .ne(ne_wb2if_redirect_v), .ee());
edge_det uedex2if (.rst(rst_i), .clk(clk_g), .i(ex2if_redirect_v), .pe(pe_ex2if_redirect_v), .ne(ne_ex2if_redirect_v), .ee());
edge_det uedmem2if (.rst(rst_i), .clk(clk_g), .i(mem2if_redirect_v), .pe(pe_mem2if_redirect_v), .ne(ne_mem2if_redirect_v), .ee());

sReorderEntry robo;
wire brAddrMispredict = exbufi.pip != ex_redirecti.redirect_ip;//exRedirectIp;

reg do_ex_branch, do_mem_branch, do_wb_branch;
reg [ROB_ENTRIES-1:0] ex_stomp, mem_stomp;

always @*
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		ex_stomp[n] = 1'b0;
		if (newer_than_ex[n]) begin
			ex_stomp[n] = do_ex_branch;
		end
	end
end
`ifdef SUPPORT_CALL_RET
always @*
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		mem_stomp[n] = 1'b0;
		if (newer_than_mem[n]) begin
			mem_stomp[n] = do_mem_branch;
		end
	end
end
`else
always_comb
	mem_stomp <= {ROB_ENTRIES{1'b0}};
`endif

reg [NUM_AIREGS-1:1] rob_livetarget [0:ROB_ENTRIES-1];
wire [31:1] reg_out [0:ROB_ENTRIES-1];

generate begin : gRegout
for (g = 0; g < ROB_ENTRIES; g = g + 1) begin
decoder5 udc1 (rob[g].Rt[4:0], reg_out[g][31:1]);
end
end
endgenerate

always @*
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		rob_livetarget[n] = (rob[n].v && rob[n].dec && !(ex_stomp[n]|mem_stomp[n])) ? reg_out[n] : {NUM_AIREGS{1'b0}};
end

function RegBitList fnLivetarget;
begin
	for (j = 1; j < NUM_AIREGS; j = j + 1) begin
		fnLivetarget[j] = 1'b0;
		for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
			fnLivetarget[j] = fnLivetarget[j] | rob_livetarget[n][j];
		end
	end
end
endfunction

function RegBitList [ROB_ENTRIES-1:0] fnCumulative;
input [5:0] missid;
integer n;
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		fnCumulative[n] = 31'b0;
		for (j = n; j < n + ROB_ENTRIES; j = j + 1) begin
			if (missid==(j % ROB_ENTRIES))
				for (k = n; k <= j; k = k + 1)
					fnCumulative[n] = fnCumulative[n] | rob_livetarget[k % ROB_ENTRIES];// & {NUM_AIREGS{vv[n]}});
		end
	end
end
endfunction

function RegBitList [ROB_ENTRIES-1:0] fnLatestID;
input [5:0] missid;
integer n;
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
    fnLatestID[n] = (missid == n || ((rob_livetarget[n] & fnCumulative((n+1)%ROB_ENTRIES)) == {NUM_AIREGS{1'b0}}))
				    ? rob_livetarget[n]
				    : {NUM_AIREGS{1'b0}};
end
endfunction

RegBitList [ROB_ENTRIES-1:0] ex_latestID, dec_latestID;
RegBitList [ROB_ENTRIES-1:0] mem_latestID;
RegBitList [ROB_ENTRIES-1:0] cumu;
always @*
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		cumu[n] = 31'b0;
		for (j = n; j < n + ROB_ENTRIES; j = j + 1) begin
			if (mem_redirecti.xrid==(j % ROB_ENTRIES))
				for (k = n; k <= j; k = k + 1)
					cumu[n] = cumu[n] | rob_livetarget[k % ROB_ENTRIES];// & {NUM_AIREGS{vv[n]}});
		end
	end
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
    mem_latestID[n] = (mem_redirecti.xrid == n || ((rob_livetarget[n] & cumu[(n+1)%ROB_ENTRIES]) == {NUM_AIREGS{1'b0}}))
				    ? rob_livetarget[n]
				    : {NUM_AIREGS{1'b0}};
end

always_comb
	do_ex_branch = ex_redirecti.wr && rob[ex_redirecti.xrid].v==VAL && rob[ex_redirecti.xrid].cmt==FALSE;
always_comb
	do_mem_branch = mem_redirecti.wr && rob[mem_redirecti.xrid].v==VAL && rob[mem_redirecti.xrid].cmt==FALSE;
always_comb
	do_wb_branch = wb_redirecti.wr && rob[wb_redirecti.xrid].v==VAL && rob[wb_redirecti.xrid].cmt==FALSE;

reg [31:0] regIsValid, vregIsValid, vm_regIsValid;
RegBitList livetarget;
always_comb
	livetarget = fnLivetarget();

reg [ROB_ENTRIES-1:0] ex_source;
always @*
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
	  ex_source[n] = | ex_latestID[n];
reg [ROB_ENTRIES-1:0] mem_source;
always @*
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
	  mem_source[n] = | mem_latestID[n];


reg [4:0] commit_tgt;
always_comb
	commit_tgt = rob[rob_deq].Rt[4:0];

always @*
begin
	for (n = 0; n < NUM_AIREGS; n = n + 1)
	begin
		regIsValid[n] = ~regfilesrc[n].rf;
		vregIsValid[n] = ~vregfilesrc[n].rf;
		if (do_ex_branch|do_mem_branch|do_wb_branch) begin
       if (~(livetarget[n])) begin
     			regIsValid[n] = 1'b1;
     			vregIsValid[n] = 1'b1;
     	 end
    end
	end
	for (n = 0; n < 8; n = n + 1)
	begin
		vm_regIsValid[n] = ~vm_regfilesrc[n].rf;
		if (do_ex_branch|do_mem_branch|do_wb_branch) begin
       if (~(livetarget[n])) begin
     			vm_regIsValid[n] = 1'b1;
     	 end
    end
	end
	if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].rfwr && regfilesrc[commit_tgt].rf)
		regIsValid[commit_tgt] = regfilesrc[commit_tgt].rid == rob_deq;
	if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].vrfwr && vregfilesrc[commit_tgt].rf)
		vregIsValid[commit_tgt] = vregfilesrc[commit_tgt].rid == rob_deq;
	if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].vmrfwr && vm_regfilesrc[commit_tgt].rf)
		vm_regIsValid[commit_tgt] = vm_regfilesrc[commit_tgt].rid == rob_deq;
	if (do_mem_branch) begin
		if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].rfwr && regfilesrc[commit_tgt].rf)
			regIsValid[commit_tgt] = regIsValid[commit_tgt] || mem_source[rob_deq];
		if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].vrfwr && vregfilesrc[commit_tgt].rf)
			vregIsValid[commit_tgt] = vregIsValid[commit_tgt] || mem_source[rob_deq];
		if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].vmrfwr && vm_regfilesrc[commit_tgt].rf)
			vm_regIsValid[commit_tgt] = vm_regIsValid[commit_tgt] || mem_source[rob_deq];
	end
	else if (do_ex_branch) begin
		if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].rfwr && regfilesrc[commit_tgt].rf)
			regIsValid[commit_tgt] = regIsValid[commit_tgt] || ex_source[rob_deq];
		if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].vrfwr && vregfilesrc[commit_tgt].rf)
			vregIsValid[commit_tgt] = vregIsValid[commit_tgt] || ex_source[rob_deq];
		if (rob[rob_deq].v==VAL && rob[rob_deq].cmt==TRUE && rob[rob_deq].vmrfwr && vm_regfilesrc[commit_tgt].rf)
			vm_regIsValid[commit_tgt] = vm_regIsValid[commit_tgt] || ex_source[rob_deq];
	end
	regIsValid[0] = 1'b1;
	vregIsValid[0] = 1'b1;
end

integer nn;
always_ff @(posedge clk_g)
if (rst_i) begin
	for (nn = 1; nn < NUM_AIREGS; nn = nn + 1) begin
		regfilesrc[nn].rf <= 1'b0;	
		vregfilesrc[nn].rf <= 1'b0;	
	end
	for (nn = 0; nn < 8; nn = nn + 1) begin
		vm_regfilesrc[nn].rf <= 1'b0;	
	end
end
else begin
	for (nn = 1; nn < NUM_AIREGS; nn = nn + 1) begin
		regfilesrc[nn].rf <= ~regIsValid[nn];	
		vregfilesrc[nn].rf <= ~vregIsValid[nn];	
	end
	for (nn = 0; nn < 8; nn = nn + 1) begin
		vm_regfilesrc[nn].rf <= ~vm_regIsValid[nn];	
	end
	if (!(do_ex_branch|do_mem_branch|do_wb_branch)) begin
		if (rob[rob_dec].v==VAL && rob_dec != 6'd63 && !rob[rob_dec].dec) begin
			if (decbuf.rfwr)
				regfilesrc[decbuf.Rt[4:0]].rf <= 1'b1;
			if (decbuf.vrfwr)
				vregfilesrc[decbuf.Rt[4:0]].rf <= 1'b1;
			if (decbuf.vmrfwr)
				vm_regfilesrc[decbuf.Rt[2:0]].rf <= 1'b1;
		end
	end
end


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Floating point logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [7:0] fp_cnt;
reg [2:0] rm3;
reg d_fltcmp;
wire [5:0] fltfunct5 = fpreco.ir.r2.func;
reg [FPWID-1:0] fcmp_res, ftoi_res, itof_res, fres;
wire [2:0] rmq = rm3==3'b111 ? rm : rm3;

Value fcmp_o;
wire [EX:0] fas_o, fmul_o, fdiv_o, fsqrt_o;
wire [EX:0] fma_o;
wire fma_uf;
wire mul_of, div_of;
wire mul_uf, div_uf;
wire norm_nx;
wire sqrt_done;
wire cmpnan, cmpsnan;
reg [EX:0] fnorm_i;
wire [MSB+3:0] fnorm_o;
reg ld;
reg ld1;
wire sqrneg, sqrinf;
wire fa_inf, fa_xz, fa_vz;
wire fa_qnan, fa_snan, fa_nan;
wire fb_qnan, fb_snan, fb_nan;
wire finf, fdn;
always @(posedge clk_g)
	ld1 <= ld;
`ifdef SUPPORT_FLOAT
fpDecomp u12 (.i(fpreco.a.val), .sgn(), .exp(), .man(), .fract(), .xz(fa_xz), .mz(), .vz(fa_vz), .inf(fa_inf), .xinf(), .qnan(fa_qnan), .snan(fa_snan), .nan(fa_nan));
fpDecomp u13 (.i(fpreco.b.val), .sgn(), .exp(), .man(), .fract(), .xz(), .mz(), .vz(), .inf(), .xinf(), .qnan(fb_qnan), .snan(fb_snan), .nan(fb_nan));

assign fcmp_res = fcmp_o[1] ? {FPWID{1'd1}} : fcmp_o[0] ? 1'd0 : 1'd1;
i2f u2 (.clk(clk_g), .ce(1'b1), .op(~fpreco.ir.r2.Rb[0]), .rm(rmq), .i(fpreco.a.val), .o(itof_res));
f2i u3 (.clk(clk_g), .ce(1'b1), .op(~fpreco.ir.r2.Rb[0]), .i(fpreco.a.val), .o(ftoi_res), .overflow());
fpAddsub u4 (.clk(clk_g), .ce(1'b1), .rm(rmq), .op(fltfunct5==FSUB), .a(fpreco.a.val), .b(fpreco.b.val), .o(fas_o));
fpMultiply u5 (.clk(clk_g), .ce(1'b1), .a(fpreco.a.val), .b(fpreco.b.val), .o(fmul_o), .sign_exe(), .inf(), .overflow(mul_of), .underflow(mul_uf));
fpDivide u6 (.rst(rst_i), .clk(clk_g), .clk4x(1'b0), .ce(1'b1), .ld(ld), .op(1'b0),
	.a(fpreco.a.val), .b(fpreco.b.val), .o(fdiv_o), .done(), .sign_exe(), .overflow(div_of), .underflow(div_uf));
fpSqrt u7 (.rst(rst_i), .clk(clk_g), .ce(1'b1), .ld(ld),
	.a(fpreco.a.val), .o(fsqrt_o), .done(sqrt_done), .sqrinf(sqrinf), .sqrneg(sqrneg));
fpFMA u14
(
	.clk(clk_g),
	.ce(1'b1),
	.op(fpreco.ir.r2.opcode==MSUB||fpreco.ir.r2.opcode==NMSUB),
	.rm(rmq),
	.a(fpreco.ir.r2.opcode==NMADD||fpreco.ir.r2.opcode==NMSUB ? {~fpreco.a.val[FPWID-1],fpreco.a.val[FPWID-2:0]} : fpreco.a.val),
	.b(fpreco.b.val),
	.c(fpreco.c.val),
	.o(fma_o),
	.under(fma_uf),
	.over(),
	.inf(),
	.zero()
);

always @(posedge clk_g)
case(fpreco.ir.r2.opcode)
F1,VF1:
	case(fpreco.ir.r2.func)
	FSQRT:	fnorm_i <= fsqrt_o;
	default:	fnorm_i <= 1'd0;
	endcase
F2,VF2:
	case(fpreco.ir.r2.func)
	FADD:	fnorm_i <= fas_o;
	FSUB:	fnorm_i <= fas_o;
	FMUL:	fnorm_i <= fmul_o;
	FDIV:	fnorm_i <= fdiv_o;
	default:	fnorm_i <= 1'd0;
	endcase
F3,VF3:
	case(fpreco.ir.r2.func)
	MADD,MSUB,NMADD,NMSUB:
		fnorm_i <= fma_o;
	default:	fnorm_i <= 1'd0;
	endcase
default:	fnorm_i <= 1'd0;
endcase
reg fnorm_uf;
wire norm_uf;
always @(posedge clk_g)
case(fpreco.ir.r2.opcode)
F2,VF2:
	case(fpreco.ir.r2.func)
	FMUL:	fnorm_uf <= mul_uf;
	FDIV:	fnorm_uf <= div_uf;
	default:	fnorm_uf <= 1'b0;
	endcase
F3,VF3:
	case(fpreco.ir.r2.func)
	MADD,MSUB,NMADD,NMSUB:
		fnorm_uf <= fma_uf;
	default:	fnorm_uf <= 1'b0;
	endcase
default:	fnorm_uf <= 1'b0;
endcase
fpNormalize u8 (.clk(clk_g), .ce(1'b1), .i(fnorm_i), .o(fnorm_o), .under_i(fnorm_uf), .under_o(norm_uf), .inexact_o(norm_nx));
fpRound u9 (.clk(clk_g), .ce(1'b1), .rm(rmq), .i(fnorm_o), .o(fres));
fpDecompReg u10 (.clk(clk_g), .ce(1'b1), .i(fres), .sgn(), .exp(), .fract(), .xz(fdn), .vz(), .inf(finf), .nan() );
`endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Graphics logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg wr_coeff;
Value pt_o;
Value coeff_o;

any1_point_transform uptt1
(
	.clk_i(clk_g),
	.wr_i(wr_coeff),
	.adr_i(grapho.ia.val[5:0]),
	.dat_i(grapho.ib.val),
	.dat_o(coeff_o),
	.pt_i(grapho.ia.val),
	.pt_o(pt_o)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [35:0] ldm_mask;
reg ld_vtmp;
reg [63:0] new_vtmp;
wire [63:0] vtmp;
reg [5:0] tid;
sReorderEntry robi;
always_comb robi = rob[safe_rob_exec];

any1_execute uex1(
	.rst(rst_i),
	.clk(clk_g),
	.robi(robi),
	.robo(robo),
	.mulreci(mulreci),
	.divreci(divreci),
	.membufi(membufi),
	.rob_exec(rob_exec),
	.ex_redirect(ex_redirecti),
	.f2a_rst(f2a_rst),
	.a2d_rst(a2d_rst),
	.d2x_rst(d2x_rst),
	.ex_takb(ex_takb),
	.csrro(csrro),
	.irq_i(|irq_i),		// For PFI instruction
	.cause_i(cause_i),
	.brAddrMispredict(brAddrMispredict),
	.restore_rfsrc(restore_rfsrc),
	.vregfilesrc(vregfilesrc),
	.vl(vl),
	.rob_x(rob_x),
	.rob_q(rob_q),
	.ld_vtmp(ld_vtmp),
	.new_vtmp(new_vtmp),
	.vtmp(vtmp),
	.out(robo.out),
	.tid(tid),
	.rd_trace(rd_trace),
	.trace_dout(trace_dout),
	.gr_target(gr_target),
	.gr_clip(gr_clip),
	.clip_en(clip_en),
	.lsm_mask(ldm_mask)
);

reg zero_data;
MemoryRequest memreq;
MemoryResponse memresp;
wire memreq_full;
reg memresp_rd;
reg membufi_wr,membufi_wr1;

always_ff @(posedge clk_g)
	membufi1 <= membufi;
always_ff @(posedge clk_g)
	membufi_wr1 <= membufi.wr;
always_ff @(posedge clk_g)
	membufi_wr <= membufi_wr1;

always_comb
if (rst_i) begin
	memreq.fifo_wr = FALSE;
	memreq.tid <= 8'h7F;
	memreq.step <= 6'd0;
	memreq.adr <= 33'd0;
	memreq.dat <= 64'd0;
	memreq.sel <= 32'h0;
	memreq.func2 <= 4'd0;
	memreq.func = 3'd0;
end
else begin
	memreq.tid = membufi1.rid;
	memreq.step = membufi1.step;
	memreq.adr = ea;
	memreq.dat = membufi1.ib;
	memreq.sel = selx;
	memreq.func2 = membufi1.ir.ld.func;
	case (membufi1.ir.ld.opcode)
	LDx,LDxX,LDSx,LDxVX,CVLDSx:
		memreq.func = LOAD;
	LDxZ,LDxXZ:
		memreq.func = LOADZ;
	STx,STxX,STSx,STxVX,CVSTSx:
		memreq.func = STORE;
	CACHE:
		memreq.func = CACHE2;
`ifdef SUPPORT_CALL_RET		
	RTS:
		memreq.func = RTS2;
	CALL:
		memreq.func = M_CALL;
`endif		
	default:	memreq.func = LOAD;
	endcase
	memreq.fifo_wr = membufi_wr;
end

wire [5:0] tidx = memresp.tid[5:0];
always_comb memresp_rd <= !memresp_empty;
edge_det uedmemresp1 (.rst(rst_i), .clk(clk_g), .i(memresp_v), .pe(pe_memresp_v), .ne(), .ee());

always_comb
	prev_rob_dec <= rob_dec==6'd0 ? ROB_ENTRIES - 1 : rob_dec - 2'd1;

wire xx;
any1_mem_ctrl umc1
(
	.rst(rst_i),
	.clk(clk_g),
	.UserMode(UserMode),
	.MUserMode(MUserMode),
	.omode(omode),
	.ASID(ASID),
	.sregfile(sregfile),
	.ip(ip),
	.ihit(ihit),
	.ifStall(ifStall),
	.ic_line(ic_line),
	.fifoToCtrl_i(memreq),
	.fifoToCtrl_full(memreq_full),
	.fifoFromCtrl_o(memresp),
	.fifoFromCtrl_empty(memresp_empty),
	.fifoFromCtrl_rd(memresp_rd),
	.fifoFromCtrl_v(memresp_v),
	.bok_i(bok_i),
	.bte_o(bte_o),
	.cti_o(cti_o),
	.vpa_o(vpa_o),
	.vda_o(),
	.cyc_o(cyc_o),
	.stb_o(stb_o),
	.ack_i(ack_i),
	.we_o(we_o),
	.sel_o(sel_o),
	.adr_o({adr_o,xx}),
	.dat_i(dat_i),
	.dat_o(dat_o),
	.sr_o(sr_o),
	.cr_o(cr_o),
	.rb_i(rb_i),
	.dce(dce),
	.keys(keys)
);


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
	if (|irq_i|pe_nmi)
		wfi <= 1'b0;
	else if (set_wfi)
		wfi <= 1'b1;
end

BUFGCE u11 (.CE(!wfi), .I(clk_i), .O(clk_g));
//assign clk_g = clk_i;

reg [127:0] exi;
reg exilo, eximid, exihi, has_exi, exi3, exi4;
Address exi_ip;
reg imod,brmod,stride,btmod;
Address imod_ip;
Value regc, regd, regm, regz;
Instruction imod_inst;
reg regcv,regdv,regmv;
reg [5:0] RegspecC, RegspecD;
reg [5:0] regcsrc,regdsrc,regmsrc;
reg Rdvec,Rcvec;
reg [5:0] br_Rt;
reg [7:0] ip_cnt;
reg [63:0] a2d_buf [0:127];
reg [6:0] a2di;
reg [5:0] decven2;

wire is_modif = is_modifier[ip[5:-1]];
wire cmts_ahead = fnCmtsAhead(membufo.rid);
assign ex_latestID = fnLatestID(ex_redirecti.xrid);
assign dec_latestID = fnLatestID(rob_dec);
//assign mem_latestID = fnLatestID(mem_redirecti.xrid);
wire RegBitList [ROB_ENTRIES-1:0] wb_latestID = fnLatestID(wb_redirecto.xrid);

always_comb
	tReadCSR(csrro,rob[safe_rob_exec].imm[15:0]);

reg [47:0] exec_misses;

// Wakeup list, one bit for each instruction.
wire [ROB_ENTRIES-1:0] wakeup_list;
wire [6:0] next_exec;

any1_scheduler usched1
(
	.clk(clk_g),
	.rob(rob),
	.rob_que(rob_que),
	.robo(robo),
	.wakeup_list(wakeup_list),
	.selection(next_exec)
);

function [35:0] fnLDMmask;
integer done;
begin
	done = FALSE;
	fnLDMmask = ldm_mask;
	for (n = 0; n < 36; n = n + 1)
		if (ldm_mask[n] & !done) begin
			fnLDMmask[n] = 1'b0;
			done = TRUE;
		end
end
endfunction

// Core watchdog timer
reg [9:0] wd_timer;
reg [5:0] pp_rob_exec;
reg wd_timeout;
always_ff @(posedge clk_g)
if (rst_i) begin
	pp_rob_exec <= 6'd63;
	wd_timer <= 10'd0;
	wd_timeout <= FALSE;
end
else begin
	wd_timeout <= FALSE;
	pp_rob_exec <= rob_pexec;
	if (pp_rob_exec==rob_pexec)
		wd_timer <= wd_timer + 2'd1;
	else
		wd_timer <= 10'd0;
	if (wd_timer[9]) begin
		wd_timeout <= TRUE;
		wd_timer <= 10'd0;
	end
end

reg ifetch_v;
reg [5:0] last_rid;
reg cycle_after;
reg [5:0] rob_que_m1;
reg branch_invalidating;
always_comb rob_que_m1 = rob_que==6'd0 ? ROB_ENTRIES -1 : rob_que - 2'd1;
always_comb branch_invalidating = ihit && (wb_redirecti.wr || mem_redirecti.wr || ex_redirecti.wr);
Address mod_ip;
Instruction tir;
 
always @(posedge clk_g)
if (rst_i) begin
	ip <= RSTIP;
	mod_ip <= RSTIP;
	tvec[4'd4] <= BRKIP;
	decven <= 6'd0;
	mod_cnt <= 3'd0;
	tid <= 6'd0;
	nmif <= 1'b0;
	wb_f2a_rst <= TRUE;
	wb_a2d_rst <= TRUE;
	wb_d2x_rst <= TRUE;
	pmStack <= 12'b001001001000;
	rob_deq <= 6'd0;
	rob_que <= 6'd0;
	rob_d <= 48'd0;
	rob_q <= 48'd0;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		rob[n].rid = n[5:0];
		rob[n].v <= FALSE;
		rob[n].cmt <= FALSE;
		rob[n].cmt2 <= FALSE;
		rob[n].out <= FALSE;
		rob[n].dec <= FALSE;
		rob[n].rfwr <= FALSE;
		rob[n].ui <= FALSE;	// ***
		rob[n].ip <= RSTIP;
		rob[n].ir <= NOP_INSN;
		rob[n].jump <= FALSE;
		rob[n].branch <= FALSE;
		rob[n].call <= FALSE;
		rob[n].exec <= FALSE;
		rob[n].myst <= FALSE;
		rob[n].btag <= 4'd0;
		rob[n].predict_taken <= FALSE;
		rob[n].cause <= FLT_NONE;
		rob[n].ia.val <= 64'd0;
		rob[n].ib.val <= 64'd0;
		rob[n].ic.val <= 64'd0;
		rob[n].id.val <= 64'd0;
		rob[n].vmask <= 64'hFFFFFFFFFFFFFFFF;
		rob[n].imm <= 64'd0;
		rob[n].iav <= TRUE;
		rob[n].ibv <= TRUE;
		rob[n].icv <= TRUE;
		rob[n].idv <= TRUE;
		rob[n].itv <= TRUE;
		rob[n].vmv <= TRUE;
		rob[n].ias <= 1'b0;
		rob[n].ibs <= 1'b0;
		rob[n].ics <= 1'b0;
		rob[n].ids <= 1'b0;
		rob[n].its <= 1'b0;
		rob[n].vms <= 1'b0;
		rob[n].ia_ele <= 6'd0;
		rob[n].ib_ele <= 6'd0;
		rob[n].ic_ele <= 6'd0;
		rob[n].id_ele <= 6'd0;
		rob[n].it_ele <= 6'd0;
		rob[n].res.val <= 64'd0;
		rob[n].Rt <= 6'h00;
	end
	mstate <= MEMORY1;
	mstk_state <= MEMORY1;
	mul_state <= MUL1;
	div_state <= DIV1;
	ld_time <= FALSE;
	status[4] <= 64'h0;
	status[3] <= 64'd0;
	status[2] <= 64'd0;
	status[1] <= 64'd0;
	status[0] <= 64'd0;
	for (n = 0; n < NUM_AIREGS; n = n + 1)
		regfile[n] <= 64'd0;
	for (n = 0; n < 16; n = n + 1)
		sregfile[n] <= 64'd0;
	for (n = 0; n < 8; n = n + 1)
		vm_regfile[n] <= 64'hFFFFFFFFFFFFFFFF;
	active_branch <= 2'd0;
	dc_redirecti.redirect_ip <= 32'd0;
	dc_redirecti.current_ip <= 32'd0;
	dc_redirecti.wr <= FALSE;
	mem_redirecti.xrid <= 6'd0;
	mem_redirecti.redirect_ip <= 32'd0;
	mem_redirecti.current_ip <= 32'd0;
	mem_redirecti.step <= 6'd0;
	wb_redirecti.redirect_ip <= 32'd0;
	wb_redirecti.current_ip <= 32'd0;
	wb_redirecti.wr <= FALSE;
	cr0 <= 64'h940000000;		// enable branch predictor, data cache
	keytbl <= 32'h00020000;
	for (n = 0; n < 4; n = n + 1)
		keys2[n] <= 64'd0;
	vl <= 8'd4;
	exihi <= FALSE;
	eximid <= FALSE;
	exilo <= FALSE;
	exi3 <= FALSE;
	exi4 <= FALSE;
	imod <= FALSE;
	btmod <= FALSE;
	brmod <= FALSE;
	stride <= FALSE;
	has_exi <= FALSE;
	imod_inst <= NOP_INSN;
	regc <= 64'd0;
	regd <= 64'd0;
	regcv <= INV;
	regdv <= INV;
	for (n = 0; n < 32; n = n + 1)
		regfilesrc[n] <= 7'd0;
	for (n = 0; n < 32; n = n + 1)
		vregfilesrc[n] <= 7'd0;
	for (n = 0; n < 8; n = n + 1)
		vm_regfilesrc[n] <= 7'd0;
	vrf_update <= FALSE;
	ip_cnt <= 8'h00;
	a2di <= 7'd0;
	ld_vtmp <= FALSE;
	new_vtmp <= 64'd0;
	decven2 <= 6'd0;
	rob_exec <= 6'd63;
	rob_dec <= 6'd63;
	insnCommitted <= 48'd0;
	exec_misses <= 48'd0;

	ifetch_v <= INV;
	ip1 <= RSTIP;
	btb_predicted_ip1 <= RSTIP;
	predict_taken1 <= FALSE;

	f2a_in.v <= INV;
	f2a_in.ip <= RSTIP;
	f2a_in.pip <= RSTIP;
	f2a_in.predict_taken <= FALSE;
	f2a_in.cacheline <= {16{NOP_INSN}};

	a2d_out.v <= INV;
	a2d_out.ip <= RSTIP;
	a2d_out.pip <= RSTIP;
	a2d_out.ir <= NOP_INSN;
	a2d_out.predict_taken <= FALSE;
	
	last_rid <= 6'd63;
	prev_rob_dec2 <= 6'd63;
	ldm_mask <= 36'hFFFFFFF03;
end
else begin
	mem_redirecti.wr <= FALSE;
	wb_redirecti.wr <= FALSE;
	exfifo_rd <= FALSE;
	memfifo_wr <= FALSE;
	wb_f2a_rst <= FALSE;
	wb_a2d_rst <= FALSE;
	wb_d2x_rst <= FALSE;
	x2m_rd <= FALSE;
	x2g_rd <= FALSE;
	x2mul_rd <= FALSE;
	x2mul_wr <= FALSE;
	x2div_rd <= FALSE;
	x2div_wr <= FALSE;
	x2fp_rd <= FALSE;
	x2fp_wr <= FALSE;
	ld_vtmp <= FALSE;
	cycle_after <= FALSE;
	if (ld_time==TRUE && wc_time_dat==wc_time)
		ld_time <= FALSE;
	if (pe_nmi)
		nmif <= 1'b1;
/*
	if (!ifStall)
		decven <= 6'd0;
	else if (push_vec)
		decven <= decven + 6'd1;
*/
	vrf_update <= FALSE;
/*
	if (!ifStall) begin
		ip1 <= ip;
		btb_predicted_ip1 <= btb_predicted_ip;
		predict_taken1 <= predict_taken;
		ifetch_v <= VAL;
	end
*/
	if (!ifStall) begin
		f2a_in.ip <= ip;
		f2a_in.pip <= btb_predicted_ip;
		f2a_in.predict_taken <= predict_taken;
	 	f2a_in.cacheline <= ic_line;
	 	f2a_in.v <= VAL;//ifetch_v;
	end

	if (!ifStall) begin
		a2d_out.v <= a2d_in.v;
		a2d_out.predict_taken <= a2d_in.predict_taken;
		a2d_out.ir <= a2d_in.ir;	// ic_inst
		a2d_out.ip <= a2d_in.ip;
		a2d_out.pip <= a2d_in.pip;
	end

//	waycnt <= waycnt + 2'd1;

	// Instruction fetch
	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("Instruction fetch");
	$display("ip: %h", f2a_in.ip[AWID-1:0]);

//	if (push_f2a) begin
	if (!ifStall) begin

		if (predict_taken & btben)
			ip <= btb_predicted_ip;
		else begin
			if (is_modifier[ip[5:-1]]) begin
				if (mod_cnt==2'd0)
					mod_ip <= ip;
				mod_cnt <= mod_cnt + 2'd1;
				ip <= fnIPInc(ip);
			end
			else begin
				mod_cnt <= 3'd0;
				if (decven2 < vl) begin
					if (is_vector[ip[5:-1]]) begin
						ip <= mod_ip;
						decven2 <= decven2 + 2'd1;
					end
					else begin
						decven2 <= 6'd0;
						ip <= fnIPInc(ip);
					end
				end
				else begin
					decven2 <= 6'd0;
					ip <= fnIPInc(ip);
				end
			end
		end
		if (a2d_in.ir[6:2]==5'b10111) begin
			a2d_out.ir <= a2d_in.ir & (ldm_mask | 36'h0000000FC);
			ldm_mask <= fnLDMmask();
		end
		else if ((a2d_in.ir[6:4]==3'd6||a2d_in.ir[6:4]==3'd7) && a2d_in.ir[35:32]==LSM && (ldm_mask!=36'd0)) begin
			ip <= |mod_cnt ? mod_ip : a2d_in.ip - 4'd9;	// There should always be a modifier 5c to 5F
//			a2d_out.ir <= a2d_in.ir & (ldm_mask | 36'h00007C000);
			f2a_in.v <= INV;
//			ldm_mask <= fnLDMmask();
		end
		else if (a2d_in.ir[6:4]!=3'b101) begin
			ldm_mask <= 36'hFFFFFFF03;
		end
	end

	/*
	$display("Push d2x");
	if (push_d2x) begin
		a2d_buf[a2di] <= {a2d_out.ip,a2d_out.ir};
		a2di <= a2di + 2'd1;
		for (n = 0; n < 128; n = n + 1)
			$display("pa2d: %h", a2d_buf[n]);
	end
	*/

	$display("Instruction Fetch");
	$display("Line: %h", ic_line);
	$display("ip: %h.%h", ip[AWID-1:0],{3'b0,ip[0:-1]}<<3);

	// Instruction Align
	// All work done with combo logic above.
	$display("Instruction Align");
	$display("in:  ip: %h  ir:%h", a2d_in.ip[AWID-1:0], a2d_in.ir);
	$display("out: ip: %h  ir:%h", a2d_out.ip[AWID-1:0], a2d_out.ir);
//	if (pop_f2ad)
//		rob[a2d_in.rid].ir <= a2d_in.ir;
//	if (pop_a2d)
//		rob[a2d_out.rid].ir <= a2d_out.ir;

	// Decode
	// Mostly done by combo logic above.
	$display("Decode");
  $display ("--------------------------------------------------------------------- Regfile ---------------------------------------------------------------------");
	for (n=0; n < NUM_AIREGS; n=n+4) begin
	    $display("%d: %h %h   %d: %h %h   %d: %h %h   %d: %h %h#",
	       n[5:0]+0, regfile[{n[5:2],2'b00}], regfilesrc[n+0],
	       n[5:0]+1, regfile[{n[5:2],2'b01}], regfilesrc[n+1],
	       n[5:0]+2, regfile[{n[5:2],2'b10}], regfilesrc[n+2],
	       n[5:0]+3, regfile[{n[5:2],2'b11}], regfilesrc[n+3]
	       );
	end

	// Need to set this a cycle sooner
//	if (rob_exec < ROB_ENTRIES)
//		rob[rob_exec].out <= TRUE;

	
	// Execute
	// Lots to do here.
	// Simple single cycle instructions are executed directly and the reorder buffer updated.
	// Multi-cycle instructions are placed in instruction queues.

	// Search for ready-to execute instructions and move execute pointer there.
//	if (next_exec[5:0] != 6'd63)
		rob_exec <= next_exec[5:0];
	if (rob_exec != 6'd63)
		rob_pexec <= rob_exec;
	if (next_exec[6])
		exec_misses <= exec_misses + 2'd1;

	$display("Execute");
	$display("ip: %h  ir: %h  a:%h  b:%h  c:%h  d:%h  i:%h", exbufi.ip[AWID-1:0], exbufi.ir,exbufi.ia.val,exbufi.ib.val,exbufi.ic.val,exbufi.id.val,exbufi.imm.val);

	/*
	if (last_rid!=robo.rid) 
	begin
			if (robo.update_rob) begin
				rob[robo.rid].wr_fu <= robo.wr_fu;
				rob[robo.rid].takb <= robo.takb;
				rob[robo.rid].cause <= robo.cause;
				rob[robo.rid].res <= robo.res;
				rob[robo.rid].cmt <= robo.cmt;
				rob[robo.rid].cmt2 <= robo.cmt2;
				rob[robo.rid].vcmt <= robo.vcmt;
				rob[robo.rid].out <= TRUE;
				last_rid <= robo.rid;
		end
		if (restore_rfsrc) begin
//			tRestoreRegfileSrc(rob[robo.rid].btag);
			//rob_que <= rob_exec;
			//rob_q <= rob_q - fnBackupCnt(rob_exec);
//			for (n = 0; n < ROB_ENTRIES; n = n + 1)
//				if (newer_than_robo[n])
//					rob[n].v <= 1'b0;
		end
	end
	*/

	if (memresp_v && !rob[tidx].cmt && rob[tidx].v) begin
		rob[tidx].cause <= memresp.cause;
		rob[tidx].badAddr <= memresp.badAddr;
		if (memresp.cmt && !memresp.ret && rob[tidx].out)
			rob[tidx].cmt <= TRUE;
		if (memresp.cmt && !memresp.ret && rob[tidx].out)
			rob[tidx].cmt2 <= TRUE;
		if (memresp.ret) begin
			mem_redirecti.wr <= TRUE;
			mem_redirecti.xrid <= memresp.tid[5:0];
			mem_redirecti.step <= 6'd0;
			mem_redirecti.redirect_ip <= memresp.res;
			mem_redirecti.current_ip <= rob[tidx].ip;
		end
		else if (!memresp.call)
			rob[tidx].res <= memresp.res;
	end

	// We do not always want to write to the EXEC FU. It may have been a multi-cycle or memory op.
	if (robo.wr_fu) begin
		funcUnit[FU_EXEC].cmt <= robo.cmt;
		funcUnit[FU_EXEC].ele <= robo.step;
		funcUnit[FU_EXEC].rid <= robo.rid;
		funcUnit[FU_EXEC].res <= robo.res;
		funcUnit[FU_EXEC].res2 <= robo.ia;
		funcUnit[FU_EXEC].cause <= robo.cause;
		funcUnit[FU_EXEC].badAddr <= robo.ip;
	end
	else begin
		funcUnit[FU_EXEC].cmt <= FALSE;
		funcUnit[FU_EXEC].rid <= 6'd63;
	end

	if (robo.update_rob==TRUE && !rob[robo.rid].cmt && rob[robo.rid].v==VAL) begin// && robo.rid != prev_rob_dec2) begin
		rob[robo.rid].wr_fu <= robo.wr_fu;
		rob[robo.rid].takb <= robo.takb;
		rob[robo.rid].cause <= robo.cause;
		rob[robo.rid].res <= robo.res;
//		if (robo.cmt)
		if (robo.out)
			rob[robo.rid].cmt <= robo.cmt;
//		if (robo.cmt2)
		if (robo.out)
			rob[robo.rid].cmt2 <= robo.cmt2;
		rob[robo.rid].vcmt <= robo.vcmt;
		rob[robo.rid].out <= TRUE;
`ifdef SUPPORT_MYST		
		if (robo.myst|robo.exec) begin
			rob[robo.rid].ir <= robo.res.val[35:0];
			rob[robo.rid].dec <= FALSE;
			rob[robo.rid].out <= FALSE;
			rob[robo.rid].cmt <= FALSE;
			rob[robo.rid].cmt2 <= FALSE;
			rob[robo.rid].vcmt <= FALSE;
		end
`endif		
	end
	if (robo.out2) begin
		rob[robo.rid].out <= TRUE;
		rob[robo.rid].res <= robo.res;
	end

  $display ("----------------------------------------------------------------- Reorder Buffer -----------------------------------------------------------------");
  $display ("head: %d  tail: %d", rob_deq, rob_que);
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		$display("%c%c%c%d: %c%c%c%c%c ip=%h.%h.%d ir=%h Rt=%d res=%h imm=%h a=%h%c b=%h%c c=%h%c q:%d",
			n[5:0]==rob_deq ? "D" : " ", n==rob_que ? "Q" : " ", n==rob_exec ? "X" : " ",
			n[5:0],rob[n].cmt ? "C" : " ",rob[n].v ? "V" : " ",
			rob[n].rfwr ? "W" : " ",
			rob[n].dec ? "D" : " ",
			rob[n].out ? "O" : " ",
			rob[n].ip[AWID-1:0],{3'b0,rob[n].ip[-1:-1]}<<3,rob[n].step,rob[n].ir,
			rob[n].Rt,rob[n].res.val,
			rob[n].imm,rob[n].ia.val,rob[n].iav?"v":" ",
			rob[n].ib.val,rob[n].ibv?"v":" ",
			rob[n].ic.val,rob[n].icv?"v":" ",
			rob[n].rob_q[15:0]);
	end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Writeback
	//
	// Writeback looks only at the reorder buffer to determine which register
	// to update. The reorder buffer acts like a fifo between the other stages
	// and the writeback stage.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	$display("Writeback");
	$display("ticks: %d  committed:%d  ifStalls:%d  ex miss:%d", tick[15:0], insnCommitted, ifStalls[15:0], exec_misses[15:0]);
	if (TRUE) begin
		if (rob[rob_deq].cmt==TRUE && rob[rob_deq].v==VAL) begin
			insnCommitted <= insnCommitted + 2'd1;
			begin
				$display("ip:%h  ir:%h", rob[rob_deq].ip[AWID-1:0], rob[rob_deq].ir);
				$display("Rt:%d  res:%h", rob[rob_deq].Rt, rob[rob_deq].res);
				if (rob[rob_deq].ui==TRUE) begin
					status[4][4] <= 1'b0;	// disable further interrupts
					eip <= rob[rob_deq].ip;
					estep <= rob[rob_deq].step;
					pmStack <= {pmStack[27:0],3'b100,1'b0};
					cause[3'd4] <= FLT_UNIMP;
					wb_f2a_rst <= TRUE;
					wb_a2d_rst <= TRUE;
					wb_d2x_rst <= TRUE;
					wb_redirecti.redirect_ip <= tvec[3'd4] + {omode,6'h00};
					wb_redirecti.current_ip <= rob[rob_deq].ip;
					wb_redirecti.xrid <= rob_deq;
					wb2if_wr <= TRUE;
				end
				else if (rob[rob_deq].cause!=16'h00) begin
					status[4][4] <= 1'b0;	// disable further interrupts
					eip <= rob[rob_deq].ip;
					estep <= rob[rob_deq].step;
					pmStack <= {pmStack[27:0],3'b100,1'b0};
					cause[3'd4] <= rob[rob_deq].cause;
					badaddr[3'd4] <= rob[rob_deq].badAddr;
					wb_f2a_rst <= TRUE;
					wb_a2d_rst <= TRUE;
					wb_d2x_rst <= TRUE;
					wb_redirecti.redirect_ip <= tvec[3'd4] + {omode,5'h00};
					wb_redirecti.current_ip <= rob[rob_deq].ip;
					wb_redirecti.xrid <= rob_deq;
					wb2if_wr <= TRUE;
				end
				else begin
					case(rob[rob_deq].ir.r2.opcode)
					CSR:
						case({rob[rob_deq].ir.r2.Ta,rob[rob_deq].ir.r2.Tt})
						CSRW:	tWriteCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						CSRS:	tSetbitCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						CSRC:	tClrbitCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						//CSRRW:	tWriteCSR(rob[rob_deq].ia,rob[rob_deq].imm[15:0]);
						default:	;
						endcase
					SYS:
						case(rob[rob_deq].ir.r2.func)
						RTE:	
							begin
								sema[0] <= 1'b0;
								wb_redirecti.redirect_ip <= eip + rob[rob_deq].ia;
								wb_redirecti.current_ip <= rob[rob_deq].ip;
								wb_redirecti.step <= estep;
								wb_redirecti.xrid <= rob_deq;
								wb_redirecti.wr <= TRUE;
								wb2if_wr <= TRUE;
								wb_f2a_rst <= TRUE;
								wb_a2d_rst <= TRUE;
								wb_d2x_rst <= TRUE;
								pmStack <= {8'h9,pmStack[31:4]};
								status[4][pmStack[3:1]] <= pmStack[0];
								status[3][pmStack[3:1]] <= pmStack[0];
								status[2][pmStack[3:1]] <= pmStack[0];
								status[1][pmStack[3:1]] <= pmStack[0];
								status[0][pmStack[3:1]] <= pmStack[0];
							end
						TLBRW:	;
						default:	;
						endcase
`ifdef SUPPORT_FLOAT						
					F1:
						case(rob[rob_deq].ir.r2.opcode)
						FSQRT:	
							begin
								if (rob[rob_deq].fp_flags.fuf) fpscr[50] <= 1'b1;
								if (rob[rob_deq].fp_flags.fof) fpscr[49] <= 1'b1;
								if (rob[rob_deq].fp_flags.fdz) fpscr[51] <= 1'b1;
								if (rob[rob_deq].fp_flags.fnv) fpscr[48] <= 1'b1;
								if (rob[rob_deq].fp_flags.fnx) fpscr[52] <= 1'b1;
								fpscr[29] <= rob[rob_deq].fp_flags.lt;
								fpscr[28] <= rob[rob_deq].fp_flags.gt;
								fpscr[27] <= rob[rob_deq].fp_flags.eq;
								fpscr[26] <= rob[rob_deq].fp_flags.inf;
							end
						FRM:	fpscr[46:44] <= rob[rob_deq].res[2:0];
						default:	;
						endcase
					F2:
						begin
							case(rob[rob_deq].ir.r2.opcode)
							ADD,SUB,MUL:
								begin
									if (rob[rob_deq].fp_flags.fuf) fpscr[50] <= 1'b1;
									if (rob[rob_deq].fp_flags.fof) fpscr[49] <= 1'b1;
									if (rob[rob_deq].fp_flags.fnx) fpscr[52] <= 1'b1;
								end
							DIV:
								begin
									if (rob[rob_deq].fp_flags.fuf) fpscr[50] <= 1'b1;
									if (rob[rob_deq].fp_flags.fof) fpscr[49] <= 1'b1;
									if (rob[rob_deq].fp_flags.fdz) fpscr[51] <= 1'b1;
									if (rob[rob_deq].fp_flags.fnx) fpscr[52] <= 1'b1;
								end
							default:	;
							endcase			
							fpscr[29] <= rob[rob_deq].fp_flags.lt;
							fpscr[28] <= rob[rob_deq].fp_flags.gt;
							fpscr[27] <= rob[rob_deq].fp_flags.eq;
							fpscr[26] <= rob[rob_deq].fp_flags.inf;
						end
					F3:		
						begin
							case(rob[rob_deq].ir.r2.opcode)
							MADD,MSUB,NMADD,NMSUB:
								begin
									if (rob[rob_deq].fp_flags.fuf) fpscr[50] <= 1'b1;
									if (rob[rob_deq].fp_flags.fof) fpscr[49] <= 1'b1;
									if (rob[rob_deq].fp_flags.fnx) fpscr[52] <= 1'b1;
								end
							default:	;
							endcase
							fpscr[29] <= rob[rob_deq].fp_flags.lt;
							fpscr[28] <= rob[rob_deq].fp_flags.gt;
							fpscr[27] <= rob[rob_deq].fp_flags.eq;
							fpscr[26] <= rob[rob_deq].fp_flags.inf;
						end
`endif						
					VM:
						begin
							case(rob[rob_deq].ir.r2.opcode)
							MTVL:	vl <= rob[rob_deq].res.val;
							default:	;
							endcase
						end
					default:	;
					endcase
					if (rob[rob_deq].rfwr==TRUE) begin
						regfile[rob[rob_deq].Rt[4:0]] <= rob[rob_deq].res;
//						regfilesrc[rob[rob_deq].Rt[4:0]].rf <= 1'b0;
						for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
							if (rob[n].ias.rid==rob_deq)
								rob[n].ias.rf <= 1'b0;
							if (rob[n].ibs.rid==rob_deq)
								rob[n].ibs.rf <= 1'b0;
						end
					end
`ifdef SUPPORT_VECTOR					
					if (rob[rob_deq].vrfwr) begin
						vrf_update <= TRUE;
						vrf_din <= rob[rob_deq].res;
						vrf_wa <= {rob[rob_deq].res_ele,rob[rob_deq].Rt[5:0]};
//						vregfilesrc[rob[rob_deq].Rt[4:0]].rf <= 1'b0;
					end
					if (rob[rob_deq].vmrfwr) begin
						vm_regfile[rob[rob_deq].Rt[2:0]] <= rob[rob_deq].res.val;
//						vm_regfilesrc[rob[rob_deq].Rt[4:0]].rf <= 1'b0;
					end
`endif					
				end
				tDeque1();
			end
		end
		else if (rob[rob_deq].v==INV) begin
			tDeque1();
		end
	end
	else begin
		tDeque1();
	end
	
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Argument capture
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		for (m = 0; m < 6; m = m + 1) begin
			if (!rob[n].iav && rob[n].ias.rid==funcUnit[m].rid && rob[n].ia_ele==funcUnit[m].ele && funcUnit[m].cmt) begin
				rob[n].iav <= TRUE;
				rob[n].ia <= funcUnit[m].res;
				if (rob[n].veins)
					rob[n].step <= funcUnit[m].res[5:0];
			end
			if (!rob[n].ibv && rob[n].ibs.rid==funcUnit[m].rid && rob[n].ib_ele==funcUnit[m].ele && funcUnit[m].cmt) begin
				rob[n].ibv <= TRUE;
				rob[n].ib <= funcUnit[m].res;
			end
			if (!rob[n].icv && rob[n].ics.rid==funcUnit[m].rid && rob[n].ic_ele==funcUnit[m].ele && funcUnit[m].cmt) begin
				rob[n].icv <= TRUE;
				rob[n].ic <= funcUnit[m].res;
			end
			if (!rob[n].idv && rob[n].idib==FALSE && rob[n].ids.rid==funcUnit[m].rid && rob[n].id_ele==funcUnit[m].ele && funcUnit[m].cmt) begin
				rob[n].idv <= TRUE;
				rob[n].id <= funcUnit[m].res;
			end
			if (!rob[n].idv && rob[n].idib==TRUE && rob[n].ids.rid==funcUnit[m].rid && rob[n].id_ele==funcUnit[m].ele && funcUnit[m].cmt) begin
				rob[n].idv <= TRUE;
				rob[n].id <= funcUnit[m].res2;
			end
`ifdef SUPPORT_VECTOR
			if (!rob[n].vmv && rob[n].vms.rid==funcUnit[m].rid && rob[n].ic_ele==funcUnit[m].ele && funcUnit[m].cmt) begin
				rob[n].vmv <= TRUE;
				rob[n].vmask <= funcUnit[m].res;
			end
`endif			
			if (!rob[n].itv && !rob[n].exec && rob[n].its.rid==funcUnit[m].rid && rob[n].it_ele==funcUnit[m].ele && funcUnit[m].cmt) begin
				rob[n].itv <= TRUE;
			end
		end
	end
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		for (m = 0; m < ROB_ENTRIES; m = m + 1) begin
			if (!rob[n].iav && rob[n].ias.rid==m && rob[n].ia_ele==rob[m].step && rob[m].cmt) begin
				rob[n].iav <= TRUE;
				rob[n].ia <= rob[m].res;
				if (rob[n].veins)
					rob[n].step <= rob[m].res[5:0];
			end
			if (!rob[n].ibv && rob[n].ibs.rid==m && rob[n].ib_ele==rob[m].step && rob[m].cmt) begin
				rob[n].ibv <= TRUE;
				rob[n].ib <= rob[m].res;
			end
			if (!rob[n].icv && rob[n].ics.rid==m && rob[n].ic_ele==rob[m].step && rob[m].cmt) begin
				rob[n].icv <= TRUE;
				rob[n].ic <= rob[m].res;
			end
			if (!rob[n].idv && rob[n].idib==FALSE && rob[n].ids.rid==m && rob[n].id_ele==rob[m].step && rob[m].cmt) begin
				rob[n].idv <= TRUE;
				rob[n].id <= rob[m].res;
			end
			if (!rob[n].idv && rob[n].idib==TRUE && rob[n].ids.rid==m && rob[n].id_ele==rob[m].step && rob[m].cmt) begin
				rob[n].idv <= TRUE;
				rob[n].id <= rob[m].ib;
			end
`ifdef SUPPORT_VECTOR			
			if (!rob[n].vmv && rob[n].vms.rid==m && rob[n].id_ele==rob[m].step && rob[m].cmt) begin
				rob[n].vmv <= TRUE;
				rob[n].vmask <= rob[m].res;
			end
`endif
			if (!rob[n].itv && !rob[n].exec && rob[n].its.rid==m && rob[n].it_ele==rob[m].step && rob[m].cmt) begin
				rob[n].itv <= TRUE;
			end
		end
	end
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Decode
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Assign reorder buffer and initialize buffer.
	if (push_d2x)
		tQueue();

	rob_dec <= fnNextDec(rob_dec);
	if (rob_dec != 6'd63 && !rob[rob_dec].dec) begin
		prev_rob_dec2 <= rob_dec;
		tDecode();
	end


	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Instruction Fetch
	// The order of these LOC is important, they must be after the queue
	// so that branch invalidation takes precedence when setting the valid
	// bit.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

	if (wb_redirecti.wr) begin
		if (rob[wb_redirecti.xrid].v && !rob[wb_redirecti.xrid].cmt)
			tBranch(wb_redirecti,newer_than_wb,wb_latestID);
		else if (!ifStall)
			ip <= fnIPInc(ip);
	end
`ifdef SUPPORT_CALL_RET	
	else if (mem_redirecti.wr) begin
		if (rob[mem_redirecti.xrid].v && !rob[mem_redirecti.xrid].cmt)
			tBranch(mem_redirecti,newer_than_mem,mem_latestID);
		else if (!ifStall)
			ip <= fnIPInc(ip);
	end
`endif	
	else if (ex_redirecti.wr) begin
		if (rob[ex_redirecti.xrid].v && !rob[ex_redirecti.xrid].cmt)
			tBranch(ex_redirecti,newer_than_ex,ex_latestID);
		else if (!ifStall)
			ip <= fnIPInc(ip);
	end


	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Watchdog timeout pipeline advance logic.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	if (wd_timeout) begin
		rob[safe_rob_exec].ir <= NOP_INSN;
		rob[safe_rob_exec].cause <= FLT_WD;
		rob[safe_rob_exec].v <= TRUE;
		rob[safe_rob_exec].cmt <= TRUE;
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
		R3,VR3:
			begin
				case(mulreco.ir.r2.func)
				MUL,MULH:
					if (rob[mulreco.rid].iav && rob[mulreco.rid].ibv) begin
						mul_sign <= rob[mulreco.rid].ia[VALUE_SIZE-1] ^ rob[mulreco.rid].ib[VALUE_SIZE-1];
						mul_a <= rob[mulreco.rid].ia[VALUE_SIZE-1] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
						mul_b <= rob[mulreco.rid].ib[VALUE_SIZE-1] ? - rob[mulreco.rid].ib : rob[mulreco.rid].ib;
						mul_state <= MUL3;
					end
				MULSU,MULSUH:
					if (rob[mulreco.rid].iav && rob[mulreco.rid].ibv) begin
						mul_sign <= rob[mulreco.rid].ia[VALUE_SIZE-1];
						mul_a <= rob[mulreco.rid].ia[VALUE_SIZE-1] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
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
		MULI,VMULI:
			if (rob[mulreco.rid].iav) begin
				mul_sign <= rob[mulreco.rid].ia[VALUE_SIZE-1] ^ mulreco.imm[VALUE_SIZE-1];
				mul_a <= rob[mulreco.rid].ia[VALUE_SIZE-1] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
				mul_b <= mulreco.imm[VALUE_SIZE-1] ? - mulreco.imm : mulreco.imm;
				mul_state <= MUL3;
			end
		MULSUI,VMULSUI:
			if (rob[mulreco.rid].iav) begin
				mul_sign <= rob[mulreco.rid].ia[VALUE_SIZE-1];
				mul_a <= rob[mulreco.rid].ia[VALUE_SIZE-1] ? - rob[mulreco.rid].ia : rob[mulreco.rid].ia;
				mul_b <= mulreco.imm;
				mul_state <= MUL3;
			end
		MULUI,VMULUI:
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
		rob[mulreco.rid].res <= mul_sign ? -mul_p[VALUE_SIZE-1:0] : mul_p;
		rob[mulreco.rid].cmt <= TRUE;
		rob[mulreco.rid].cmt2 <= TRUE;
		if (rob[mulreco.rid].is_vec && rob[mulreco.rid].step >= vl)
			rob[mulreco.rid].vcmt <= TRUE;
		funcUnit[FU_MUL].res <= mul_sign ? -mul_p[VALUE_SIZE-1:0] : mul_p;
		funcUnit[FU_MUL].res2 <= rob[mulreco.rid].ib;
		funcUnit[FU_MUL].rid <= mulreco.rid;
		funcUnit[FU_MUL].ele <= rob[mulreco.rid].step;
		case(mulreco.ir[7:0])
		R3,VR3:
			begin
				case(mulreco.ir.r2.func)
				MULH:		begin funcUnit[FU_MUL].res <= mul_sign ? -mul_p[VALUE_SIZE*2-1:VALUE_SIZE] : mul_p[VALUE_SIZE*2-1:VALUE_SIZE]; funcUnit[FU_MUL].rid <= mulreco.rid; rob[mulreco.rid].res <= mul_sign ? -mul_p[VALUE_SIZE*2-1:VALUE_SIZE] : mul_p[VALUE_SIZE*2-1:VALUE_SIZE]; end
				MULSUH:	begin funcUnit[FU_MUL].res <= mul_sign ? -mul_p[VALUE_SIZE*2-1:VALUE_SIZE] : mul_p[VALUE_SIZE*2-1:VALUE_SIZE]; funcUnit[FU_MUL].rid <= mulreco.rid; rob[mulreco.rid].res <= mul_sign ? -mul_p[VALUE_SIZE*2-1:VALUE_SIZE] : mul_p[VALUE_SIZE*2-1:VALUE_SIZE]; end
				MULUH:	begin funcUnit[FU_MUL].res <= mul_p[VALUE_SIZE*2-1:VALUE_SIZE]; funcUnit[FU_MUL].rid <= mulreco.rid; rob[mulreco.rid].res <= mul_p[VALUE_SIZE*2-1:VALUE_SIZE]; end
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
		R3,VR3:
			if (rob[divreco.rid].iav && rob[divreco.rid].ibv)
			begin
				case(divreco.ir.r2.func)
				DIV:
					begin
						div_sign <= rob[divreco.rid].ia[VALUE_SIZE-1] ^ rob[divreco.rid].ib[VALUE_SIZE-1];
						div_a <= rob[divreco.rid].ia[VALUE_SIZE-1] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
						div_b <= rob[divreco.rid].ib[VALUE_SIZE-1] ? - rob[divreco.rid].ib : rob[divreco.rid].ib;
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
						div_sign <= rob[divreco.rid].ia[VALUE_SIZE-1];
						div_a <= rob[divreco.rid].ia[VALUE_SIZE-1] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
						div_b <= rob[divreco.rid].ib;
						div_state <= DIV3;
					end
				default:	;			
				endcase
			end
		DIVI,VDIVI:
			if (rob[divreco.rid].iav) begin
				div_sign <= rob[divreco.rid].ia[VALUE_SIZE-1] ^ divreco.imm[VALUE_SIZE-1];
				div_a <= rob[divreco.rid].ia[VALUE_SIZE-1] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
				div_b <= divreco.imm[VALUE_SIZE-1] ? - divreco.imm : divreco.imm;
				div_state <= DIV3;
			end
		DIVUI,VDIVUI:
			if (rob[divreco.rid].iav) begin
				div_sign <= 1'b0;
				div_a <= rob[divreco.rid].ia;
				div_b <= divreco.imm;
				div_state <= DIV3;
			end
		DIVSUI,VDIVSUI:
			if (rob[divreco.rid].iav) begin
				div_sign <= rob[divreco.rid].ia[VALUE_SIZE-1];
				div_a <= rob[divreco.rid].ia[VALUE_SIZE-1] ? - rob[divreco.rid].ia : rob[divreco.rid].ia;
				div_b <= divreco.imm;
				div_state <= DIV3;
			end
		default:	;			
		endcase
DIV3:
	div_state <= DIV4;
DIV4:
	if (div_done) begin
		rob[divreco.rid].res <= div_sign ? -div_q[VALUE_SIZE-1:0] : div_q;
		rob[divreco.rid].cmt <= TRUE;
		rob[divreco.rid].cmt2 <= TRUE;
		if (rob[divreco.rid].is_vec && rob[divreco.rid].step >= vl)
			rob[divreco.rid].vcmt <= TRUE;
		funcUnit[FU_DIV].res <= div_sign ? -div_q[VALUE_SIZE-1:0] : div_q;
		funcUnit[FU_DIV].res2 <= rob[divreco.rid].ib;
		funcUnit[FU_DIV].rid <= divreco.rid;
		funcUnit[FU_MUL].ele <= rob[divreco.rid].step;
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

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
// Handle float type operations.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
`ifdef SUPPORT_FLOAT
	case (fp_state)
ST_FP1:
	if (!x2fp_empty) begin
		x2fp_rd <= TRUE;
		fp_state <= ST_FP2;
	end
ST_FP2:
	begin
		case(fpreco.ir.r2.opcode)
		F1,VF1:
			case(fpreco.ir.r2.func)
			I2F:	
				if (rob[fpreco.rid].iav) begin
					fp_state <= ST_FP3;
					fp_cnt <= 8'd2;
				end
			F2I:	
				if (rob[fpreco.rid].iav) begin
					fp_state <= ST_FP3;
					fp_cnt <= 8'd2;
				end
			FSQRT:	
				if (rob[fpreco.rid].iav) begin
					fp_state <= ST_FP3;
					fp_cnt <= 8'd127;
				end
			default:	;
			endcase		
		F2,VF2:
			begin
				case(fpreco.ir.r2.func)
				FADD,FSUB:
					if (rob[fpreco.rid].iav && rob[fpreco.rid].ibv) begin
						fp_state <= ST_FP3;
						fp_cnt <= 8'd25;
					end
				FMUL:
					if (rob[fpreco.rid].iav && rob[fpreco.rid].ibv) begin
						fp_state <= ST_FP3;
						fp_cnt <= 8'd23;
					end
				FDIV:
					if (rob[fpreco.rid].iav && rob[fpreco.rid].ibv) begin
						fp_state <= ST_FP3;
						fp_cnt <= 8'd127;
					end
				default:	;
				endcase
			end
		F3,VF3:
			case(fpreco.ir.r2.func)
			MADD,MSUB,NMADD,NMSUB:
				if (rob[fpreco.rid].iav && rob[fpreco.rid].ibv && rob[fpreco.rid].icv) begin
					fp_state <= ST_FP3;
					fp_cnt <= 8'd35;
				end
			default:	;
			endcase
		default:	;
		endcase
	end
ST_FP3:
	begin
		fp_cnt <= fp_cnt - 2'd1;
		if (fp_cnt[7]) begin
			rob[fpreco.rid].fp_flags <= {fdn,finf,norm_uf,norm_nx};
			rob[fpreco.rid].res <= fres;
			rob[fpreco.rid].fp_flags <= 9'd0;
			rob[fpreco.rid].fp_flags.inf <= finf;
			rob[fpreco.rid].fp_flags.lt <= !finf &&  fres[63];
			rob[fpreco.rid].fp_flags.gt <= !finf && !fres[63];
			rob[fpreco.rid].fp_flags.eq <= !finf && fres[62:0]==63'd0;
			rob[fpreco.rid].cmt <= TRUE;
			rob[fpreco.rid].cmt2 <= TRUE;
			if (rob[fpreco.rid].is_vec && rob[fpreco.rid].step >= vl)
				rob[fpreco.rid].vcmt <= TRUE;
			case(fpreco.ir.r2.opcode)
			F1,VF1:
				case(fpreco.ir.r2.func)
				I2F:	funcUnit[FU_FP].res <= itof_res;
				F2I:	funcUnit[FU_FP].res <= ftoi_res;
				FSQRT:
					begin
				  	if (fdn) rob[fpreco.rid].fp_flags.fuf <= 1'b1;
  					if (finf) rob[fpreco.rid].fp_flags.fof <= 1'b1;
  					if (fpreco.a[FPWID-2:0]==63'd0)
  						rob[fpreco.rid].fp_flags.fdz <= 1'b1;
  					if (sqrinf|sqrneg)
  						rob[fpreco.rid].fp_flags.fnv <= 1'b1;
  					if (norm_nx) rob[fpreco.rid].fp_flags.fnx <= 1'b1;
					end
				default:
					begin 
						funcUnit[FU_FP].res <= fres;
					end
				endcase
			F2,VF2:
				case(fpreco.ir.r2.func)
				FADD,FSUB,FMUL:
					begin
						if (fdn) rob[fpreco.rid].fp_flags.fuf <= 1'b1;
						if (finf) rob[fpreco.rid].fp_flags.fof <= 1'b1;
						if (norm_nx) rob[fpreco.rid].fp_flags.fnx <= 1'b1;
					end
				FDIV:
					begin
						if (fdn) rob[fpreco.rid].fp_flags.fuf <= 1'b1;
						if (finf) rob[fpreco.rid].fp_flags.fof <= 1'b1;
						if (fpreco.b[FPWID-2:0]==1'd0)
							rob[fpreco.rid].fp_flags.fdz <= 1'b1;
						if (norm_nx) rob[fpreco.rid].fp_flags.fnx <= 1'b1;
					end
				default:	;
				endcase
			F3,VF3:
				case(fpreco.ir.r2.func)
				MADD,MSUB,NMADD,NMSUB:
					begin
						if (fdn) rob[fpreco.rid].fp_flags.fuf <= 1'b1;
						if (finf) rob[fpreco.rid].fp_flags.fof <= 1'b1;
						if (norm_nx) rob[fpreco.rid].fp_flags.fnx <= 1'b1;
					end
				default:	;
				endcase
			default:	funcUnit[FU_FP].res <= fres;
			endcase
			funcUnit[FU_FP].res2 <= rob[fpreco.rid].ib;
			funcUnit[FU_FP].rid <= fpreco.rid;
			funcUnit[FU_FP].ele <= rob[fpreco.rid].step;
			fp_state <= ST_FP1;
		end
	end
default:
	fp_state <= ST_FP1;
	endcase
`endif

	case(gr_state)
ST_GR1:
	if (!x2g_empty) begin
		x2g_rd <= TRUE;
		gr_state <= ST_GR2;
	end
ST_GR2:
		case(grapho.ir.r2.opcode)
		R1:
			case(fpreco.ir.r2.func)
			TRANSFORM:	gr_state <= ST_GR3;
			default:	;
			endcase
		R2:
			case(fpreco.ir.r2.func)
			RW_COEFF:		begin gr_state <= ST_GR3; wr_coeff <= TRUE; end
			default:	;
			endcase
		default:	;
		endcase
ST_GR3:
	begin
		gr_state <= ST_GR1;
		rob[grapho.rid].cmt <= TRUE;
		rob[grapho.rid].cmt2 <= TRUE;
		funcUnit[FU_GR].res2 <= rob[grapho.rid].ia;
		funcUnit[FU_GR].rid <= grapho.rid;
		funcUnit[FU_GR].ele <= rob[grapho.rid].step;
		case(grapho.ir.r2.opcode)
		R1:
			case(fpreco.ir.r2.func)
			TRANSFORM: begin funcUnit[FU_GR].res <= pt_o; rob[grapho.rid].res <= pt_o; end
			RW_COEFF:	 begin funcUnit[FU_GR].res <= coeff_o; rob[grapho.rid].res <= coeff_o; end
			default:	;
			endcase
		default:	;
		endcase
	end
default:
		gr_state <= ST_GR1;
	endcase

end	// clock domain

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

task tQueue;
begin
	prev_rob_que <= rob_que;
	rob[rob_que].rob_q <= rob_q;
	rob[rob_que].v <= a2d_out.v && !branch_invalidating;
	rob[rob_que].dec <= FALSE;
	rob[rob_que].out <= FALSE;
	rob[rob_que].update_rob <= FALSE;
	rob[rob_que].predict_taken <= a2d_out.predict_taken;
	rob[rob_que].ir <= a2d_out.ir;
	rob[rob_que].ip <= a2d_out.ip;
	rob[rob_que].irmod <= {$bits(Instruction){1'b0}};
	rob[rob_que].exi <= FALSE;
	rob[rob_que].imod <= FALSE;
	rob[rob_que].brmod <= FALSE;
	rob[rob_que].stride <= FALSE;
	rob[rob_que].exec <= FALSE;
	rob[rob_que].myst <= FALSE;
	rob[rob_que].mod_cnt <= mod_cnt;
	rob[rob_que].ia_ele <= decven;
	rob[rob_que].ib_ele <= decven;
	rob[rob_que].it_ele <= decven;
	rob[rob_que].id <= 64'd0;
	rob[rob_que].ics <= {1'b0,6'd0};
	rob[rob_que].ids <= {1'b0,6'd0};
	rob[rob_que].idib <= FALSE;
	rob[rob_que].its <= {1'b0,6'd0};//regfilesrc[decbuf.Rt[5:0]];
	rob[rob_que].step <= decven;
	if (nmif) begin
		nmif <= 1'b0;
		rob[rob_que].cause <= 16'h8000|FLT_NMI;
	end
	else if (|irq_i && die && decbuf.ir[6:4]!=4'h5)	// not prefix inst.
		rob[rob_que].cause <= 16'h8000|cause_i;
	else
		rob[rob_que].cause <= FLT_NONE;

	rob_q <= rob_q + 2'd1;
	if (rob_que >= ROB_ENTRIES-1)
		rob_que <= 6'd0;
	else
		rob_que <= rob_que + 2'd1;
end
endtask

task tDecode;
begin
`ifdef SUPPORT_EXEC
	if (rob[rob_dec].exec)
		tResetSrcs(dec_latestID);
`endif			
	rob[rob_dec].ui <= decbuf.ui;
	rob[rob_dec].is_vec <= decbuf.is_vec;
	rob[rob_dec].Ra <= decbuf.Ra;
	rob[rob_dec].Rb <= decbuf.Rb;
	rob[rob_dec].Rc <= 7'h00;
	rob[rob_dec].Rd <= 7'd0;
	rob[rob_dec].Rm <= decbuf.Rm;
	rob[rob_dec].Ravec <= decbuf.Ravec;
	rob[rob_dec].Rbvec <= decbuf.Rbvec;
	rob[rob_dec].Rcvec <= FALSE;
	rob[rob_dec].Rdvec <= FALSE;
	rob[rob_dec].Rt <= decbuf.Rt;
	rob[rob_dec].ia <= exbufi.ia;
	rob[rob_dec].ib <= exbufi.ib;
	if (decbuf.vsrlv) begin
		rob[rob_dec].ia_ele <= vl - decven;
		rob[rob_dec].ib_ele <= vl - decven;
		rob[rob_dec].it_ele <= vl - decven;
	end
	if (decbuf.branch)
		rob[rob_dec].ic <= rob[rob_dec].ip;
	else
		rob[rob_dec].ic <= 64'd0;
	rob[rob_dec].imm <= {{64{decbuf.imm.val[VALUE_SIZE-1]}},decbuf.imm.val};
	rob[rob_dec].vmask <= exbufi.vmask;
		rob[rob_dec].iav <= exbufi.iav;
		rob[rob_dec].ibv <= exbufi.ibv;
		rob[rob_dec].icv <= TRUE;
		rob[rob_dec].idv <= TRUE;
		rob[rob_dec].itv <= exbufi.itv;
		rob[rob_dec].vmv <= exbufi.vmv;
`ifdef SUPPORT_VECTOR
	if (decbuf.Ravec)
		rob[rob_dec].ias <= vregfilesrc[decbuf.Ra[4:0]];
	else
`endif
	if (rob[rob_dec].v==VAL && rob[rob_dec].cmt==TRUE && rob[rob_dec].Rt[4:0]==decbuf.Ra[4:0] && rob[rob_dec].rfwr)
		rob[rob_dec].ias <= {1'b0,6'b0};
	else
		rob[rob_dec].ias <= regfilesrc[decbuf.Ra[4:0]];
	rob[rob_dec].step_v <= TRUE;
`ifdef SUPPORT_VECTOR
	if (decbuf.vex) begin
		rob[rob_dec].ibs <= vregfilesrc[decbuf.Rb[4:0]];
		rob[rob_dec].step_v <= FALSE;
	end
	else if (decbuf.Rbvec)
		rob[rob_dec].ibs <= vregfilesrc[decbuf.Rb[4:0]];
	else
`endif
	begin
		if (rob[rob_dec].v==VAL && rob[rob_dec].cmt==TRUE && rob[rob_dec].Rt[4:0]==decbuf.Rb[4:0] && rob[rob_dec].rfwr)
			rob[rob_dec].ibs <= {1'b0,6'b0};
		else
			rob[rob_dec].ibs <= regfilesrc[decbuf.Rb[4:0]];
	end
	rob[rob_dec].vms <= vm_regfilesrc[decbuf.Vm];
	rob[rob_dec].rfwr <= decbuf.rfwr;
	rob[rob_dec].vrfwr <= decbuf.vrfwr;
	rob[rob_dec].branch <= decbuf.branch;
	rob[rob_dec].call <= decbuf.call;
	rob[rob_dec].jump <= decbuf.jump;
	rob[rob_dec].mem_op <= decbuf.mem_op;
	rob[rob_dec].mc <= decbuf.mc;
	rob[rob_dec].dec <= TRUE;
	rob[rob_dec].cmt <= FALSE;
	rob[rob_dec].cmt2 <= FALSE;
	rob[rob_dec].out <= FALSE;
	rob[rob_dec].res <= {VALUE_SIZE/16{16'hDEAD}};
	rob[rob_dec].veins <= decbuf.veins;
	if (decbuf.veins) begin
		rob[rob_dec].step_v <= FALSE;
		rob[rob_dec].step <= exbufi.ia.val[5:0];
	end

	case(decbuf.ir.r2.opcode)
	BEQ,BNE,BLT,BGE,BLTU,BGEU,BBS:
		begin
			active_branch <= active_branch + 2'd1;
			rob[rob_dec].btag <= active_branch;
			rob[rob_dec].branch <= TRUE;
		end
	JAL,BAL,JALR:
		begin
			active_branch <= active_branch + 2'd1;
			rob[rob_dec].btag <= active_branch;
			rob[rob_dec].branch <= TRUE;
		end
	default:	;
	endcase
	case(decbuf.ir.r2.opcode)
	EXI0:
		begin
			rob[rob_dec].cmt <= TRUE;
			rob[rob_dec].cmt2 <= TRUE;
			rob[rob_dec].out <= TRUE;
			rob[rob_dec].exi <= TRUE;
			rob[rob_dec].imm <= {{128-39{exbufi.ir[35]}},exbufi.ir[35:8],11'd0};
		end
	EXI1:
		begin
			rob[rob_dec].cmt <= TRUE;
			rob[rob_dec].cmt2 <= TRUE;
			rob[rob_dec].out <= TRUE;
			rob[rob_dec].exi <= TRUE;
			rob[rob_dec].imm <= rob[prev_rob_dec].imm;
			rob[rob_dec].imm[127:39] <= {{128-67{exbufi[35]}},exbufi.ir[35:8]};
		end
	EXI2:
		begin
			rob[rob_dec].cmt <= TRUE;
			rob[rob_dec].cmt2 <= TRUE;
			rob[rob_dec].out <= TRUE;
			rob[rob_dec].exi <= TRUE;
			rob[rob_dec].imm <= rob[prev_rob_dec].imm;
			rob[rob_dec].imm[127:67] <= {{128-95{exbufi[35]}},exbufi.ir[35:8]};
		end
	EXI3:
		begin
			rob[rob_dec].cmt <= TRUE;
			rob[rob_dec].cmt2 <= TRUE;
			rob[rob_dec].out <= TRUE;
			rob[rob_dec].exi <= TRUE;
			rob[rob_dec].imm[127:95] <= {{128-123{exbufi[35]}},exbufi.ir[35:8]};
		end
	EXI4:
		begin
			rob[rob_dec].cmt <= TRUE;
			rob[rob_dec].cmt2 <= TRUE;
			rob[rob_dec].out <= TRUE;
			rob[rob_dec].exi <= TRUE;
			rob[rob_dec].imm[127:123] <= exbufi.ir[12:8];
		end
	IMOD:
		begin
			rob[rob_dec].imod <= TRUE;
			rob[rob_dec].vmask <= exbufi.vmask;
			rob[rob_dec].z <= exbufi.z;
		end
	VIMOD:
		begin
			rob[rob_dec].imod <= TRUE;
			rob[rob_dec].vmask <= exbufi.vmask;
			rob[rob_dec].z <= exbufi.z;
		end
	BRMOD:
		begin
			rob[rob_dec].brmod <= TRUE;
			rob[rob_dec].exi <= TRUE;
			rob[rob_dec].imm <= {{128-35{exbufi.ir[35]}},exbufi.ir[35:21],exbufi.ir[13:10],16'h0};
		end
	STRIDE:
		begin
			rob[rob_dec].stride <= TRUE;
			rob[rob_dec].out <= TRUE;
		end
	VSTRIDE:
		begin
			rob[rob_dec].stride <= TRUE;
			rob[rob_dec].out <= TRUE;
		end
	RGLST0,RGLST1,RGLST2,RGLST3:
		begin
			rob[rob_dec].cmt <= TRUE;
			rob[rob_dec].cmt2 <= TRUE;
			rob[rob_dec].out <= TRUE;
		end
	default:	
		begin
			if (decbuf.is_vec) begin
				if (decven < vl)
					decven <= decven + 2'd1;
				else begin
					decven <= 6'd0;
				end
			end
		end
	endcase
	// Check make sure the modifier applies the next instruction in program
	// order. It's possible for a modifier to fall under the branch shadow
	// and the instruction fetched from the target is likely not the next
	// one in program order.
	if (fnIPInc(rob[prev_rob_dec].ip)==rob[rob_dec].ip) begin
		if (rob[prev_rob_dec].exi) begin
			rob[rob_dec].imm[127:11] <= rob[prev_rob_dec].imm[127:11];
			rob[rob_dec].Rm <= rob[prev_rob_dec].Rm;
			if (rob[rob_dec].mem_op && rob[rob_dec].ir[35:32]==LSM) begin
				if (rob[rob_dec].ir[6:4]==3'd6)
				 	rob[rob_dec].Rt <= rob[prev_rob_dec].Rm;
				else begin
				 	rob[rob_dec].Rb <= rob[prev_rob_dec].Rm;
				 	rob[rob_dec].ibv <= FALSE;
					rob[rob_dec].ibs <= regfilesrc[rob[prev_rob_dec].Rm[4:0]];
				end
			end
		end
		if (rob[prev_rob_dec].imod) begin
			rob[rob_dec].Rc <= rob[prev_rob_dec].Ra;
			rob[rob_dec].Rd <= rob[prev_rob_dec].Rb;
			rob[rob_dec].ic <= rob[prev_rob_dec].ia;
			rob[rob_dec].id <= rob[prev_rob_dec].ib;
			rob[rob_dec].icv <= rob[prev_rob_dec].iav;
			rob[rob_dec].idv <= rob[prev_rob_dec].ibv;
			rob[rob_dec].ics <= {1'b1,prev_rob_dec};
			rob[rob_dec].ids <= {1'b1,prev_rob_dec};
			rob[rob_dec].idib <= TRUE;
			rob[rob_dec].Rcvec <= rob[prev_rob_dec].Ravec;
			rob[rob_dec].Rdvec <= rob[prev_rob_dec].Rbvec;
			if (rob[prev_rob_dec].ir[12]) begin
//					rob[rob_dec].vms <= rob[prev_rob_dec].msrc;
				rob[rob_dec].vmask <= rob[prev_rob_dec].vmask;
//					rob[rob_dec].vmv <= rob[prev_rob_dec].vmv;
			rob[rob_dec].Rm <= rob[prev_rob_dec].Rm;
			if (rob[rob_dec].mem_op && rob[rob_dec].ir[35:32]==LSM) begin
				if (rob[rob_dec].ir[6:4]==3'd6)
				 	rob[rob_dec].Rt <= rob[prev_rob_dec].Rm;
				else begin
				 	rob[rob_dec].Rb <= rob[prev_rob_dec].Rm;
				 	rob[rob_dec].ibv <= FALSE;
					rob[rob_dec].ibs <= regfilesrc[rob[prev_rob_dec].Rm[4:0]];
				end
			end
			end
		end
		if (rob[prev_rob_dec].brmod) begin
			rob[rob_dec].Rc <= rob[prev_rob_dec].Ra;
			rob[rob_dec].Rd <= rob[prev_rob_dec].Rb;
			rob[rob_dec].ic <= rob[prev_rob_dec].ia;
			rob[rob_dec].id <= rob[prev_rob_dec].ib;
			rob[rob_dec].icv <= rob[prev_rob_dec].iav;
			rob[rob_dec].idv <= rob[prev_rob_dec].ibv;
			rob[rob_dec].ics <= {1'b1,prev_rob_dec};
			rob[rob_dec].ids <= {1'b1,prev_rob_dec};
			rob[rob_dec].Rcvec <= rob[prev_rob_dec].Ravec;
			rob[rob_dec].Rdvec <= rob[prev_rob_dec].Rbvec;
			rob[rob_dec].imm[127:16] <= rob[prev_rob_dec].imm[127:16];
			rob[rob_dec].Rt <= rob[prev_rob_dec].Rt;
			if (rob[prev_rob_dec].Rt[4:0] != 5'd0) begin
//				tAllocReg(imod_inst.r2.Rt,rob[rob_dec].pRt);
				rob[rob_dec].rfwr <= TRUE;
//					regfilesrc[rob[prev_rob_dec].Rt[4:0]].rf <= 1'b1;
				regfilesrc[rob[prev_rob_dec].Rt[4:0]].rid <= rob_dec;
			end
		end
		if (rob[prev_rob_dec].stride) begin
			rob[rob_dec].Rc <= rob[prev_rob_dec].Ra;
			rob[rob_dec].Rd <= rob[prev_rob_dec].Rb;
			rob[rob_dec].ic <= rob[prev_rob_dec].ia;
			rob[rob_dec].id <= rob[prev_rob_dec].ib;
			rob[rob_dec].icv <= rob[prev_rob_dec].iav;
			rob[rob_dec].idv <= rob[prev_rob_dec].ibv;
			rob[rob_dec].ics <= {1'b1,prev_rob_dec};
			rob[rob_dec].ids <= {1'b1,prev_rob_dec};
			rob[rob_dec].Rcvec <= rob[prev_rob_dec].Ravec;
			rob[rob_dec].Rdvec <= rob[prev_rob_dec].Rbvec;
			rob[rob_dec].Rm <= rob[prev_rob_dec].Rm;
			if (rob[rob_dec].mem_op && rob[rob_dec].ir[35:32]==LSM) begin
				if (rob[rob_dec].ir[6:4]==3'd6)
				 	rob[rob_dec].Rt <= rob[prev_rob_dec].Rm;
				else begin
				 	rob[rob_dec].Rb <= rob[prev_rob_dec].Rm;
				 	rob[rob_dec].ibv <= FALSE;
					rob[rob_dec].ibs <= regfilesrc[rob[prev_rob_dec].Rm[4:0]];
				end
			end
		end
		if (rob[prev_rob_dec].ir[6:2]==5'b10111) begin
			rob[rob_dec].Rm <= rob[prev_rob_dec].Rm;
		end
	end
	if (rob[rob_dec].v==VAL & ~branch_invalidating) begin
		if (decbuf.rfwr)
			regfilesrc[decbuf.Rt[4:0]].rid <= decbuf.exec ? 6'd63 : rob_dec;
		if (decbuf.vrfwr)
			vregfilesrc[decbuf.Rt[4:0]].rid <= decbuf.exec ? 6'd63 : rob_dec;
		if (decbuf.vmrfwr)
			vm_regfilesrc[decbuf.Rt[4:0]].rid <= decbuf.exec ? 6'd63 : rob_dec;
		if (decbuf.rfwr && rob[rob_dec].mem_op && rob[rob_dec].ir[35:32]==LSM) begin
			if (rob[rob_dec].ir[6:4]==3'd6)
				regfilesrc[decbuf.Rm[4:0]].rid <= rob_dec;
		end
	end
end
endtask
	
task tDeque1;
begin
	rob[rob_deq].v <= INV;
	rob[rob_deq].ui <= INV;
	rob[rob_deq].cause <= FLT_NONE;
	rob[rob_deq].cmt <= FALSE;
	rob[rob_deq].rfwr <= FALSE;
	rob[rob_deq].vrfwr <= FALSE;
	rob[rob_deq].vmrfwr <= FALSE;
	rob[rob_deq].jump <= FALSE;
	rob[rob_deq].branch <= FALSE;
	// Test if queue would be empty
	if (fnQp1(rob_deq) != rob_que) begin
		rob_d <= rob_d + 2'd1;
		rob_deq <= fnQp1(rob_deq);
		insnCommitted <= insnCommitted + 2'd1;
	end
end
endtask

task tBranch;
input sRedirect redi;
input [ROB_ENTRIES-1:0] newer_than;
input RegBitList [ROB_ENTRIES-1:0] latestID;
begin
	begin
		if (rob[redi.xrid].v) begin
			rob[redi.xrid].cmt <= TRUE;
			rob[redi.xrid].cmt2 <= TRUE;
			//rob[redi.xrid].v <= FALSE;
			ip <= redi.redirect_ip;
			decven <= redi.step;
			ifetch_v <= INV;
			f2a_in.v <= INV;
			a2d_out.v <= INV;
			for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
				if (newer_than[n] && n!=redi.xrid) begin
					rob[n].v <= INV;
					rob[n].out <= FALSE;
				end
			end
			tResetSrcs(latestID);
		end
	end
end
endtask

task tResetSrcs;
input RegBitList [ROB_ENTRIES-1:0] latestID;
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
  	if (|latestID[n]) begin// && (~newer_than[n] || n[5:0]==redi.xrid)) begin
  		if (rob[n].v==VAL) begin
	  		if (rob[n].Rt[5]) begin
		  		vregfilesrc[rob[n].Rt[4:0]].rid <= n[5:0];
	  		end
	  		else if (rob[n].vmrfwr) begin
		  		vm_regfilesrc[rob[n].Rt[2:0]].rid <= n[5:0];
	  		end
	  		else begin
	  			regfilesrc[rob[n].Rt[4:0]].rid <= n[5:0];
	  		end
	  	end
  	end
  end
end
endtask

task arg_vs;
begin
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		rob[n].ias <= rob[n].Ravec ? vregfilesrc[rob[n].Ra[4:0]] : regfilesrc[rob[n].Ra[4:0]];
		rob[n].ibs <= rob[n].Rbvec ? vregfilesrc[rob[n].Rb[4:0]] : regfilesrc[rob[n].Rb[4:0]];
		rob[n].ics <= rob[n].Rcvec ? vregfilesrc[rob[n].Rc[4:0]] : regfilesrc[rob[n].Rc[4:0]];
		rob[n].ids <= rob[n].Rdvec ? vregfilesrc[rob[n].Rd[4:0]] : regfilesrc[rob[n].Rd[4:0]];
	end
end
endtask

task SetSource;
input [4:0] rg;
input [5:0] rid;
begin
	for (m = 0; m < ROB_ENTRIES; m = m + 1) begin
		if (rob[m].Ra[4:0]==rg) rob[m].ias.rid <= rid;
		if (rob[m].Rb[4:0]==rg) rob[m].ibs.rid <= rid;
		if (rob[m].Rc[4:0]==rg) rob[m].ics.rid <= rid;
		if (rob[m].Rd[4:0]==rg) rob[m].ids.rid <= rid;
	end
end
endtask

task tReadCSR;
output Value res;
input [15:0] regno;
begin
	if (regno[14:12] <= omode) begin
		casez(regno[15:0])
		CSR_SCRATCH:	res.val <= scratch[regno[14:12]];
		CSR_DCR0:	res.val <= cr0|(dce << 5'd30);
		CSR_DHARTID: res.val <= hartid_i;
		CSR_MHARTID: res.val <= hartid_i;
		CSR_MCR0:	res.val <= cr0|(dce << 5'd30);
		CSR_KEYTBL:	res.val <= keytbl;
		CSR_KEYS:	res.val <= keys2[regno[1:0]];
		CSR_SEMA: res.val <= sema;
		CSR_FSTAT:	res.val <= fpscr;
		CSR_ASID:	res.val <= ASID;
		CSR_MBADADDR:	res.val <= badaddr[regno[14:12]];
		CSR_TICK:	res.val <= tick;
		CSR_CAUSE:	res.val <= cause[regno[14:12]];
		CSR_MTVEC,CSR_DTVEC:
			res.val <= tvec[regno[2:0]];
		CSR_DPMSTACK:	res.val <= pmStack;
		CSR_MPMSTACK:	res.val <= pmStack;
		CSR_MVSTEP:	res.val <= estep;
		CSR_DVSTEP:	res.val <= estep;
		CSR_DVTMP:	res.val <= vtmp;
		CSR_MVTMP:	res.val <= vtmp;
		CSR_DEIP: res.val <= eip;
		CSR_MEIP: res.val <= eip;
		CSR_TIME:	res.val <= wc_time;
		CSR_MSTATUS:	res.val <= status[4];
		CSR_DSTATUS:	res.val <= status[4];
		CSR_DTCBPTR:	res.val <= tcbptr;
		default:	res.val <= 64'd0;
		endcase
	end
	else
		res <= 64'd0;
end
endtask

task tWriteCSR;
input Value val;
input [15:0] regno;
begin
	if (regno[14:12] <= omode) begin
		casez(regno[15:0])
		CSR_SCRATCH:	scratch[regno[14:12]] <= val.val;
		CSR_DCR0:		cr0 <= val.val;
		CSR_MCR0:		cr0 <= val.val;
		CSR_SEMA:		sema <= val.val;
		CSR_KEYTBL:	keytbl <= val.val;
		CSR_KEYS:		keys2[regno[1:0]] <= val.val;
		CSR_FSTAT:	fpscr <= val.val;
		CSR_ASID: 	ASID <= val.val;
		CSR_MBADADDR:	badaddr[regno[14:12]] <= val.val;
		CSR_CAUSE:	cause[regno[14:12]] <= val.val;
		CSR_MTVEC,CSR_DTVEC:
			tvec[regno[2:0]] <= val.val;
		CSR_DPMSTACK:	pmStack <= val.val;
		CSR_MPMSTACK:	pmStack <= val.val;
		CSR_DVSTEP:	estep <= val.val;
		CSR_MVSTEP:	estep <= val.val;
		CSR_DVTMP:	begin new_vtmp <= val.val; ld_vtmp <= TRUE; end
		CSR_MVTMP:	begin new_vtmp <= val.val; ld_vtmp <= TRUE; end
		CSR_DEIP:	eip <= val.val;
		CSR_MEIP:	eip <= val.val;
		CSR_DTIME:	begin wc_time_dat <= val.val; ld_time <= TRUE; end
		CSR_MTIME:	begin wc_time_dat <= val.val; ld_time <= TRUE; end
		CSR_DSTATUS:	status[4] <= val.val;
		CSR_MSTATUS:	status[4] <= val.val;
		CSR_DTCBPTR:	tcbptr <= val.val;
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

endmodule

module decoder5 (num, out);
input [4:0] num;
output [31:1] out;

wire [31:0] out1;

assign out1 = 32'd1 << num;
assign out = out1[31:1];

endmodule

