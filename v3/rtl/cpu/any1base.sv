// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1base.sv
// ANY1 processor base implementation.
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
import fp::*;

module any1(hartid_i, rst_i, clk_i, clk2x_i, wc_clk_i, nmi_i, irq_i, cause_i,
	vpa_o, vda_o, bte_o, cti_o, bok_i, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o,
	dat_i, dat_o, sr_o, cr_o, rb_i);
input [63:0] hartid_i;
input rst_i;
input clk_i;
input clk2x_i;
input wc_clk_i;
input nmi_i;
input [2:0] irq_i;
input [7:0] cause_i;
output reg vpa_o;
output reg vda_o;
output reg [1:0] bte_o;
output reg [2:0] cti_o;
input bok_i;
output cyc_o;
output reg stb_o;
input ack_i;
output reg we_o;
output reg [7:0] sel_o;
output reg [AWID-1:0] adr_o;
input [63:0] dat_i;
output reg [63:0] dat_o;
output reg sr_o;		// set memory reservation
output reg cr_o;		// clear memory reservation
input rb_i;					// input memory still reserved bit

wire clk_g;
integer j,k,n,m,n1;
genvar g;
wire clk_g;
wire acki = ack_i;


wire [2:0] omode;
wire [2:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode, DebugMode;
wire MUserMode;

Instruction ir, micro_ir;
sFuncUnit [5:0] funcUnit;
sDecode decbuf;
sALUrec mulreci,mulreco, divreci, divreco, fpreci,fpreco;
sGraphicsOp graphi,grapho;
sFuncUnit memfu;
reg [2:0] mod_cnt;

reg x2mul_wr,x2mul_rd;
wire x2mul_full,x2mul_empty;
reg x2fp_wr,x2fp_rd;
wire x2fp_full,x2fp_empty;
reg mul_sign;
Value mul_a;
Value mul_b;
reg [VALUE_SIZE*2-1:0] mul_p;

reg [2:0] mul_state;	// multipler state
reg [2:0] div_state;
reg [2:0] fp_state;
reg [2:0] gr_state;
reg [63:0] csrro;

reg [5:0] micro_ip;
reg [AWID-1:0] ip;
reg [AWID-1:0] cs_base;
reg [63:0] irL, irH;
reg illegal_insn;

Value imm;
Value ia,ib,ic,id;

Selector cs;
SegDesc cs_desc;								// code segment descriptor
Value regfile [0:31];
reg wr_sgram;
reg [9:0] sgram_adr;
reg [19:0] sgram_dat;
wire [19:0] sgram_bo, sgram_ao;
wire [9:0] ea_seg;

sregfile_blkram usgr1 (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(wr_sgram),      // input wire [0 : 0] wea
  .addra(sgram_adr),  // input wire [10 : 0] addra
  .dina(sgram_dat),    // input wire [63 : 0] dina
  .douta(),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(1'b0),      // input wire enb
  .web(1'b1),      // input wire [0 : 0] web
  .addrb(ea_seg),  // input wire [10 : 0] addrb
  .dinb(20'd0),    // input wire [63 : 0] dinb
  .doutb(sgram_ao)  // output wire [63 : 0] doutb
);
sregfile_blkram usgr2 (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(wr_sgram),      // input wire [0 : 0] wea
  .addra(sgram_adr),  // input wire [10 : 0] addra
  .dina(sgram_dat),    // input wire [63 : 0] dina
  .douta(),  // output wire [63 : 0] douta
  .clkb(~clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .web(1'b0),      // input wire [0 : 0] web
  .addrb(ib[9:0]),  // input wire [10 : 0] addrb
  .dinb(20'd0),    // input wire [63 : 0] dinb
  .doutb(sgram_bo)  // output wire [63 : 0] doutb
);


function Address fnIPInc;
input Address pc;
begin
//	fnIPInc = {pc[AWID-1:24],pc[23:-1] + (is_20bit[pc[3:-1]] ? 4'd5 : 4'd9)};
	fnIPInc = {pc[AWID-1:24],pc[23:-1] + 4'd9};
end
endfunction

//CSRs
Value scratch [0:7];
Value stuff0, stuff1;				// return value registers
Address tcbptr;							// task control block pointer
reg [63:0] cr0;
wire bpe = cr0[32];
wire btben = cr0[33];
wire dce;
wire sple = cr0[35];
wire tag_mode = cr0[36];
wire [2:0] arange = cr0[42:40];
reg [63:0] tick;
Address tvec [0:7];
Value svec [0:7];
reg [7:0] cause [0:7];
Address badaddr [0:7];
Address eip;
Value ecs;
Value ecsbnd;
SegDesc pcs;
Value dsp;
reg [5:0] estep;
reg [63:0] pmStack;
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
reg [63:0] gdt, ldt;
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
	.ir(ir),
	.sel(selx)
);

Address ea;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire ex_takb;
any1_eval_branch ubev1
(
	.inst(ir),
	.a(ia),
	.b(ib),
	.takb(ex_takb)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

any1_agen uagen
(
	.rst(rst_i),
	.clk(clk_g),
	.ir(ir),
	.ia(ia),
	.ib(ib),
	.ic(ic),
	.imm(imm),
	.step(6'd0),
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

reg decra;
reg [35:0] ldm_mask, lsm_mask;
wire [5:0] Rmo, Rmi;

any1_decode udec1
(
	.ir(ir),
	.decbuf(decbuf),
	.predicted_ip(1'd0),
	.ven(decven),
	.lsm_mask(lsm_mask)
);

always_comb
	tReadCSR(csrro,imm[15:0]);

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

always_ff @(posedge clk_i)
if (rst_i) begin
	ip <= RSTIP;
	illegal_insn <= TRUE;
end
else begin
	case(state)
	IFETCH0:
		if (micro_ip != 6'd0) begin
			ip <= ip;
			case(micro_ip)
			// ENTER
			6'd1: begin micro_ip <= 6'd2; ir <= {16'hFFA0,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; end						// ADD $SP,$SP,#-96
			6'd2:	begin micro_ip <= 6'd3; ir <= {4'd3,5'h00,2'd0,5'd29,1'b0,micro_ir[12:8],6'h00,STx}; end							// STO $FP,[$SP]
			6'd3:	begin micro_ip <= 6'd4; ir <= {4'd3,5'h00,2'd0,micro_ir[18:14],1'b0,micro_ir[12:8],6'h10,STx}; end		// STO $RA,16[$SP]
			6'd4:	begin micro_ip <= 6'd5; ir <= {4'd3,5'h00,2'd0,5'd0,1'b0,micro_ir[12:8],6'h20,STx}; end								// STO $X0,32[$SP]
			6'd5: begin micro_ip <= 6'd6; ir <= {16'h0000,1'b0,micro_ir[12:8],1'b0,5'd29,ADDI}; end	// ADD $FP,$SP,#0
			6'd6: begin micro_ip <= 6'd0; ir <= {micro_ir[35:23],3'b0,1'b0,micro_ir[12:8],1'b0,micro_ir[12: 8],ADDI}; ip <= fnIPInc(ip); end // SUB $SP,$SP,#Amt
			// UNLINK
			6'd8:	begin micro_ip <= 6'd9; ir <= {OR,2'd0,7'd0,1'b0,micro_ir[18:14],1'b0,micro_ir[12:8],R2};	end		// MOV $SP,$FP
			// POP Ra
			6'd9:	begin micro_ip <= 6'd10; ir <= {4'd3,12'd0,1'b0,micro_ir[12:8],1'b0,micro_ir[18:14],LDx}; end		// LDO $FP,[$SP]
			6'd10:	begin micro_ip <= 6'd0; ir <= {16'h0008,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; ip <= fnIPInc(ip); end			// ADD $SP,$SP,#8
			// LDM / STM
			6'd12:
				begin
					lsm_mask <= fnLDMmask(lsm_mask);
					ldm_mask <= lsm_mask;
					ir <= micro_ir;
					//ip <= |mod_cnt ? mod_ip + 4'd9 : ip;
					if (ldm_mask==36'd0) begin
						micro_ip <= 6'd0;
						ip <= fnIPInc(ip); 
						// Reset mask or the next time in will quit too soon.
						ldm_mask <= 36'hFFFFFFF03;
					end
				end
			// PUSH Ra
			6'd13:	begin micro_ip <= 6'd14; ir <= {16'hFFF8,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI};	end			// SUB $SP,$SP,#8
			6'd14:	begin micro_ip <= 6'd0;  ir <= {4'd3,5'd0,2'd0,micro_ir[18:14],1'b0,micro_ir[12:8],6'd0,STx}; ip <= fnIPInc(ip); end		// STO $FP,[$SP]
			// PUSH Ra,Rb
			6'd15:	begin micro_ip <= 6'd16; ir <= {16'hFFF0,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI};	end			// SUB $SP,$SP,#16
			6'd16:	begin micro_ip <= 6'd17; ir <= {4'd3,5'd0,2'd0,micro_ir[18:14],1'b0,micro_ir[12:8],6'd0,STx}; end		// STO $FP,[$SP]
			6'd17:	begin micro_ip <= 6'd0;  ir <= {4'd3,5'd0,2'd0,micro_ir[24:20],1'b0,micro_ir[12:8],6'd0,STx}; ip <= fnIPInc(ip); end		// STO $FP,[$SP]
			// POP Ra,Rb
			6'd18:	begin micro_ip <= 6'd19; ir <= {4'd3,12'd0,1'b0,micro_ir[12:8],1'b0,micro_ir[24:20],LDx}; end		// LDO $Rb,[$SP]
			6'd19:	begin micro_ip <= 6'd20; ir <= {4'd3,12'h008,1'b0,micro_ir[12:8],1'b0,micro_ir[18:14],LDx}; end		// LDO $Ra,8[$SP]
			6'd20:	begin micro_ip <= 6'd0;  ir <= {16'h0010,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; ip <= fnIPInc(ip); end			// ADD $SP,$SP,#16
			// LEAVE Ra,#Adj
			6'd21:	begin micro_ip <= 6'd22; ir <= {OR,2'd0,7'd0,1'b0,5'd29,1'b0,micro_ir[12:8],R2};	end		// MOV $SP,$FP
			6'd22:	begin micro_ip <= 6'd23; ir <= {4'd3,12'h000,1'b0,micro_ir[12:8],1'b0,5'd29,LDx}; end		// LDO $FP,[$SP]
			6'd23:	begin micro_ip <= 6'd24; ir <= {4'd3,12'h010,1'b0,micro_ir[12:8],1'b0,micro_ir[18:14],LDx}; end		// LDO $RA,16[$SP]
 			6'd24:	begin micro_ip <= 6'd25; ir <= {16'h0060,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; end			// ADD $SP,$SP,#96
 			6'd25:	begin micro_ip <= 6'd26; ir <= {1'b0,micro_ir[31:20],3'b000,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; end			// ADD $SP,$SP,#Amt
			6'd26:	begin micro_ip <= 6'd0;  ir <= {16'h0000,1'b0,micro_ir[18:14],1'b0,5'd0,JALR}; ip <= fnIPInc(ip); end		// JALR $X0,[$Ra]
			// BSR	Label
			6'd27:	begin micro_ip <= 6'd28; ir <= {micro_ir[35:10],2'd1,BAL}; end		// BAL $X1,Address
			6'd28:	begin micro_ip <= 6'd29; ir <= {16'hFFF8,1'b0,5'd30,1'b0,5'd30,ADDI};	end			// SUB $SP,$SP,#8
			6'd29:	begin micro_ip <= 6'd0;  ir <= {4'd3,5'd0,2'd0,5'd1,1'b0,5'd30,6'd0,STx}; ip <= fnIPInc(ip); end		// STO $X1,[$SP]
			// ENTER FAR
			6'd32: 	begin micro_ip <= 6'd33; ir <= {16'hFFA0,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; end						// ADD $SP,$SP,#-96
			6'd33:	begin micro_ip <= 6'd34; ir <= {4'd3,5'h00,2'd0,5'd29,1'b0,micro_ir[12:8],6'h00,STx}; end							// STO $FP,[$SP]
			6'd34:	begin micro_ip <= 6'd35; ir <= {4'd3,5'h00,2'd0,micro_ir[18:14],1'b0,micro_ir[12:8],6'h10,STx}; end		// STO $RA,16[$SP]
			6'd35:	begin micro_ip <= 6'd36; ir <= {4'hB,5'h00,2'b00,5'd14,1'b0,micro_ir[12:8],6'h18,STx}; end						// STO $B14,24[$SP]
			6'd36:	begin micro_ip <= 6'd37; ir <= {4'd3,5'h00,2'd0,5'd0,1'b0,micro_ir[12:8],6'h20,STx}; end							// STO $X0,32[$SP]
			6'd37:	begin micro_ip <= 6'd38; ir <= {4'd3,5'h00,2'd0,5'd0,1'b0,micro_ir[12:8],6'h28,STx}; end							// STO $X0,40[$SP]
			6'd38: 	begin micro_ip <= 6'd39; ir <= {16'h0000,1'b0,micro_ir[12:8],1'b0,5'd29,ADDI}; end	// ADD $FP,$SP,#0
			6'd39: 	begin micro_ip <= 6'd00; ir <= {micro_ir[35:23],3'b0,1'b0,micro_ir[12:8],1'b0,micro_ir[12: 8],ADDI}; ip <= fnIPInc(ip); end // SUB $SP,$SP,#Amt
			// LEAVE FAR Ra,#Adj
			6'd42:	begin micro_ip <= 6'd43; ir <= {OR,2'd0,7'd0,1'b0,5'd29,1'b0,micro_ir[12:8],R2};	end							// MOV $SP,$FP
			6'd43:	begin micro_ip <= 6'd44; ir <= {4'd3,12'h000,1'b0,micro_ir[12:8],1'b0,5'd29,LDx}; end							// LDO $FP,[$SP]
			6'd44:	begin micro_ip <= 6'd45; ir <= {4'd3,12'h010,1'b0,micro_ir[12:8],1'b0,micro_ir[18:14],LDx}; end		// LDO $RA,16[$SP]
			6'd45:	begin micro_ip <= 6'd46; ir <= {4'hB,12'h010,1'b0,micro_ir[12:8],1'b0,5'd15,LDx}; end							// LDO $B15,16[$SP]
 			6'd46:	begin micro_ip <= 6'd47; ir <= {16'h0060,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; end			// ADD $SP,$SP,#96
			6'd47:	begin micro_ip <= 6'd48; ir <= {1'b0,micro_ir[31:20],3'b000,1'b0,micro_ir[12:8],1'b0,micro_ir[12:8],ADDI}; end			// ADD $SP,$SP,#Amt
			6'd48:	begin micro_ip <= 6'd0;  ir <= {16'h0000,1'b0,micro_ir[18:14],1'b0,5'd0,JALR}; ip <= fnIPInc(ip); end		// JALR $X0,[$Ra]
			// DEFCAT
			6'd50:	begin micro_ip <= 6'd51; ir <= {4'd3,12'h000,1'b0,5'd29,1'b0,micro_ir[18:14],LDx}; end							// LDO $Tn,[$FP]
			6'd51:	begin micro_ip <= 6'd52; ir <= {4'd3,12'h020,1'b0,micro_ir[18:14],1'b0,micro_ir[24:20],LDx}; end		// LDO $Tn+1,32[$Tn]
			6'd52:	begin micro_ip <= 6'd53; ir <= {4'd3,5'h00,2'd0,micro_ir[24:20],1'b0,5'd29,6'h10,STx}; end					// STO $Tn+1,16[$FP]
			6'd53:	begin micro_ip <= 6'd54; ir <= {4'd3,12'h028,1'b0,micro_ir[18:14],1'b0,micro_ir[24:20],LDx}; end		// LDO $Tn+1,40[$Tn]
			6'd54:	begin micro_ip <= 6'd0;  ir <= {4'd3,5'h00,2'd0,micro_ir[24:20],1'b0,5'd29,6'h18,STx}; ip <= fnIPInc(ip); end					// STO $Tn+1,24[$FP]
			default:	micro_ip <= 6'd0; 
			endcase
			goto (DECODE);
		end
		else
			goto (IFETCH1);

	IFETCH1:
		if (~ack_i) begin
			illegal_insn <= TRUE;
			iip <= ip;
			vpa_o <= HIGH;
			lcyc <= HIGH;
			stb_o <= HIGH;
			sel_o <= 8'hFF;
			tPC();
			state <= IFETCH2;
			if (nmif) begin
				nmif <= 1'b0;
				lcyc <= LOW;
				tException(32'h800000FE,ip,6'd62,imStack[3:0]);
				pc <= mtvec + 8'hFC;
			end
	 		else if (irq_i > im_level && ie && !mloco && cid==5'd0) begin
				lcyc <= LOW;
				tException(32'h80000000|cause_i,ip,6'd52+irq_i,{1'b0,irq_i});
			end
			else
				ip <= fnIPInc(ip);
		end
	IFETCH2:
		if (ack_i) begin
			lcyc <= LOW;
			irL <= dat_i;
			state <= (ip[2:-1] > 4'd7) ? IFETCH3 : IFETCH5;
		end
	IFETCH3:
		if (~ack_i) begin
			lcyc <= HIGH;
			ladr <= {ladr[AWID-1:3]+2'd1,3'd0};
			state <= IFETCH4;
		end
	IFETCH4:
		if (ack_i) begin
			irH <= dat_i;
		end
	IFETCH5:
		begin
			ir <= {irH,irL} >> {ip[3:-1],2'b00};
			state <= DECODE;
		end

	DECODE:
		casez(ir[7:0])
		ENTER: 
			begin
				micro_ir <= ir;
				micro_ip <= ir[19] ? 6'd32 : 6'd1;
				goto (IFETCH0);
			end
		PUSH:
			begin
				micro_ir <= ir;
				micro_ip <= ir[35:32]==4'd1 ? 6'd13 : 6'd15;
				goto (IFETCH0);
			end
		POP:
			begin
				micro_ir <= ir;
				case(ir[35:32])
				4'd1:	micro_ip <= 6'd9;
				4'd2:	micro_ip <= 6'd18;
				4'd4:	micro_ip <= 6'd8;		// UNLINK
				4'd5: micro_ip <= 6'd21;	// LEAVE
				4'd6:	micro_ip <= 6'd42;	// LEAVE FAR
				4'd8:	micro_ip <= 6'd50;	// DEFCAT
				default:	micro_ip <= 6'd0;
				endcase
				goto (IFETCH0);
			end
		BSR:
			begin
				micro_ir <= ir;
				micro_ip <= 6'd27;
				goto (IFETCH0);
			end
		SYS:
			begin
				if ((ir[35:29]==CSAVE || ir[35:29]==CRESTORE) && ir[13:8] != 6'd47) begin
					ir <= {ir[35:14],ir[13:8]+2'd1,ir[7:0]};
					goto (REGFETCH0);
				end
			end
		8'b?10111??:
			 begin
				lsm_mask <= ir & 36'hFFFFFFF03;
				mod_cnt <= mod_cnt - 2'd1;
				goto (REGFETCH0);
			end
		8'b?110????:
			if (ir[35:32]==LSM) begin
				micro_ir <= ir;
				micro_ip <= 6'd12;
				goto (IFETCH0);
			//ip <= |mod_cnt ? mod_ip : a2d_in.ip - 4'd9;	// There should always be a modifier 5c to 5F
	//			a2d_out.ir <= a2d_in.ir & (ldm_mask | 36'h00007C000);
				//f2a_in.v <= INV;
	//			ldm_mask <= fnLDMmask();
			end
		// For compressed instructions, perform a branch to the next instruction.
		// The IP was already incremented by 9 and it should have been by 4.
		// This is the kludgy way to fix up the address for the next instruction.
		// Its great benefit is that it is a resource efficient and timing fast
		// solution. But it adds a clock cycle to the execution time of every
		// compressed instruction.
		8'b0111????:
			begin
				ip <= iip + 4'd5;
				goto (REGFETCH0);
			end
		default:
				goto (REGFETCH0);
		endcase
	default:	;
	endcase
end

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
		CSR_MSVEC,CSR_DSVEC:
			res.val <= svec[regno[2:0]];
		CSR_DPMSTACK:	res.val <= pmStack;
		CSR_MPMSTACK:	res.val <= pmStack;
		CSR_MVSTEP:	res.val <= estep;
		CSR_DVSTEP:	res.val <= estep;
		CSR_DVTMP:	res.val <= vtmp;
		CSR_MVTMP:	res.val <= vtmp;
		CSR_DEIP: res.val <= eip;
		CSR_MEIP: res.val <= eip;
		CSR_DECS: res.val <= ecs;
		CSR_MECS: res.val <= ecs;
		CSR_DPCS: res.val <= pcs;
		CSR_MPCS: res.val <= pcs;
		CSR_DSP:	res.val <= dsp;
		CSR_TIME:	res.val <= wc_time;
		CSR_MSTATUS:	res.val <= status[4];
		CSR_DSTATUS:	res.val <= status[4];
		CSR_DTCBPTR:	res.val <= tcbptr;
		CSR_DSTUFF0:	res.val <= stuff0;
		CSR_DSTUFF1:	res.val <= stuff1;
		CSR_DGDT:	res.val <= gdt;
		CSR_DLDT:	res.val <= ldt;
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
		CSR_MSVEC,CSR_DSVEC:
			svec[regno[2:0]] <= val.val;
		CSR_DPMSTACK:	pmStack <= val.val;
		CSR_MPMSTACK:	pmStack <= val.val;
		CSR_DVSTEP:	estep <= val.val;
		CSR_MVSTEP:	estep <= val.val;
		CSR_DVTMP:	begin new_vtmp <= val.val; ld_vtmp <= TRUE; end
		CSR_MVTMP:	begin new_vtmp <= val.val; ld_vtmp <= TRUE; end
		CSR_DEIP:	eip <= val.val;
		CSR_MEIP:	eip <= val.val;
		CSR_DECS:	ecs <= val.val;
		CSR_MECS:	ecs <= val.val;
		CSR_DPCS:	pcs <= val.val;
		CSR_MPCS:	pcs <= val.val;
		CSR_DSP:	dsp <= val.val;
		CSR_DTIME:	begin wc_time_dat <= val.val; ld_time <= TRUE; end
		CSR_MTIME:	begin wc_time_dat <= val.val; ld_time <= TRUE; end
		CSR_DSTATUS:	status[4] <= val.val;
		CSR_MSTATUS:	status[4] <= val.val;
		CSR_DTCBPTR:	tcbptr <= val.val;
		CSR_DSTUFF0:	stuff0 <= val.val;
		CSR_DSTUFF1:	stuff1 <= val.val;
		CSR_DGDT:	gdt <= val.val;
		CSR_DLDT:	ldt <= val.val;
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

task tEA;
begin
	if (ea[AWID-1:24]=={AWID-24{1'b1}})
		ladr <= ea;
	else
		ladr <= ea[AWID-11:0] + {sregfile[segsel][AWID-1:4],14'd0};
end
endtask

task tPC;
begin
	if (ip[AWID-1:24]=={AWID-24{1'b1}})
		ladr <= {ip[AWID-1:3],3'h0};
	else
		ladr <= {ip[AWID-1:3],3'h0} + {cs_base[AWID-1:4],14'd0};
end
endtask

task wb_nack;
begin
	vpa_o <= LOW;
	vda_o <= LOW;
	lcyc <= LOW;
	stb_o <= LOW;
	we_o <= LOW;
	sel_o <= 8'h00;
	dat_o <= 64'h0;
end
endtask

task tException;
input [31:0] cse;
input [31:0] tpc;
input [5:0] rs;
input [3:0] ml;
begin
	pc <= mtvec + {pmStack[2:1],6'h00};
	mepc[rs] <= tpc;
	pmStack <= {pmStack[28:0],2'b11,1'b0};
	mstatus[11:0] <= {mstatus[8:0],2'b11,1'b0};
	imStack <= {imStack[27:0],ml};
	mcause <= cse;
	illegal_insn <= 1'b0;
	instret <= instret + 2'd1;
  rprv <= 5'h0;
  Rdx1 <= rs;
  Rs1x1 <= rs;
  Rs2x1 <= rs;
  Rs3x1 <= rs;
  rsStack <= {rsStack[41:0],rs};
	goto (IFETCH);
end
endtask

task goto;
input [5:0] nst;
begin
  state <= nst;
end
endtask

endmodule
