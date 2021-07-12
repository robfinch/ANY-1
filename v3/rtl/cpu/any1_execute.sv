// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_execute.sv
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

module any1_execute(rst,clk,robi,execo,mulreci,divreci,membufi,fpreci,rob_exec,ex_redirect,
	a2d_rst,d2x_rst,ex_takb,csrro,irq_i,cause_i,brAddrMispredict,out,tid,
	restore_rfsrc,set_wfi,vregfilesrc,vl,rob_x,rob_q,
	ld_vtmp, vtmp, new_vtmp, graphi, rd_trace, trace_dout,
	gr_target, gr_clip, clip_en, lsm_mask, exvec, tcbptr,
	);
input rst;
input clk;
input sReorderEntry robi;
output sExecuteOut execo;
output sALUrec mulreci;
output sALUrec divreci;
output sALUrec fpreci;
output sMemoryIO membufi;
output sGraphicsOp graphi;
input [5:0] rob_exec;
output reg [47:0] rob_x;
input [47:0] rob_q;
output sRedirect ex_redirect;
output reg a2d_rst;
output reg d2x_rst;
input ex_takb;
input [63:0] csrro;
input irq_i;
input [7:0] cause_i;
input brAddrMispredict;
input Rid vregfilesrc [0:63];

output reg restore_rfsrc;
output reg set_wfi= 1'b0;
input [7:0] vl;
input ld_vtmp;
output reg [63:0] vtmp;			// temporary register for vector operations
input [63:0] new_vtmp;
input out;
input [5:0] tid;
output reg rd_trace;
input [63:0] trace_dout;

input Rect gr_target;
input Rect gr_clip;
input clip_en;
input [35:0] lsm_mask;
output reg [3:0] exvec;
input Address tcbptr;

integer m,n;

function Address fnIncIP;
input Address ptr;
begin
	fnIncIP = {ptr[AWID-1:24],ptr[23:-1] + 4'd9};
end
endfunction

function Address fnIncIP5;
input Address ptr;
begin
	fnIncIP5 = {ptr[AWID-1:24],ptr[23:-1] + 4'd5};
end
endfunction

wire [7:0] vs = VALUE_SIZE;
wire d_vsllv = (robi.ir.r2.opcode==VR2) && robi.ir.r2.func==VSLLV;
wire d_vsrlv = (robi.ir.r2.opcode==VR2) && robi.ir.r2.func==VSRLV;

wire [127:0] sll_out = {robi.ib.val,robi.ia.val} << robi.ic.val[5:0];
wire [127:0] sll_out2 = {64'd0,robi.ia.val} << robi.ib.val[5:0];
wire [127:0] srl_out2 = {robi.ia.val,64'd0} >> robi.ib.val[5:0];
wire [127:0] slli_out2 = {64'd0,robi.ia.val} << robi.imm[5:0];
wire [127:0] srli_out2 = {robi.ia.val,64'd0} >> robi.imm[5:0];

wire brMispredict = ex_takb != robi.predict_taken;//exbufi.predict_taken;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Count: leading zeros, leading ones, population.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
wire [6:0] cntlzo, cntloo, cntpopo;

cntlz64 uclz1 (robi.ia.val, cntlzo);
cntlo64 uclo1 (robi.ia.val, cntloo);
cntpop64 ucpop1 (robi.ia.val, cntpopo);

wire [6:0] ffoo, floo, lsm_pc;
ffo96 uffo1 ({32'd0,robi.ia.val}, ffoo);
flo96 uflo1 ({32'h0,robi.ia.val}, floo);

cntpop64 upop2 ({34'd0,robi.ir[35:8],robi.ir[1:0]}, lsm_pc);

reg [4:0] Rm;
reg done;
always @*
begin
	m = 0;
	done = FALSE;
	for (n = 0; n < 36; n = n + 1) begin
		if (lsm_mask[n] && !done && (n > 7 || n < 2)) begin
			Rm = m;
			done = TRUE;
		end
		if (n > 7 || n < 2)
			m = m + 1;
	end
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Bitfield
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Value bf_out;
any1_bitfield ubf1
(
	.inst(robi.ir),
	.a(robi.ia),
	.b(robi.ib),
	.c(robi.ic),
	.d(robi.id),
	.o(bf_out),
	.masko()
);


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Bit Matrix Multiply
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Value bmm_o;
BMM ubmm1
(
	.op(robi.ir[1:0]),
	.a(robi.ia),
	.b(robi.ib),
	.o(bmm_o)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Floating Point
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire fa_inf, fa_xz, fa_vz;
wire fa_qnan, fa_snan, fa_nan;
wire fb_qnan, fb_snan, fb_nan;
wire [63:0] fcmp_o;
wire cmpnan,cmpsnan;

`ifdef SUPPORT_FLOAT
fpDecomp u12 (.i(robi.ia.val), .sgn(), .exp(), .man(), .fract(), .xz(fa_xz), .mz(), .vz(fa_vz), .inf(fa_inf), .xinf(), .qnan(fa_qnan), .snan(fa_snan), .nan(fa_nan));
fpDecomp u13 (.i(robi.ib.val), .sgn(), .exp(), .man(), .fract(), .xz(), .mz(), .vz(), .inf(), .xinf(), .qnan(fb_qnan), .snan(fb_snan), .nan(fb_nan));

fpCompare u1 (
	.a(robi.ia.val),
	.b(robi.ib.val),
	.o(fcmp_o),
	.nan(cmpnan),
	.snan(cmpsnan)
);
`endif

	// Execute
	// Lots to do here.
	// Simple single cycle instructions are executed directly and the reorder buffer updated.
	// Multi-cycle instructions are placed in instruction queues.
	
reg [5:0] last_tid;
reg [5:0] count;			// count for STM
reg membufi_wr1;

always @(posedge clk)
if (rst) begin
	rob_x <= 48'd0;
	//rob_exec <= 6'd0;
	execo <= 1'd0;
	a2d_rst <= TRUE;
	d2x_rst <= TRUE;
	mulreci.wr <= FALSE;
	divreci.wr <= FALSE;
	membufi.wr <= FALSE;
	membufi_wr1 <= FALSE;
	ex_redirect.wr <= FALSE;
	ex_redirect.redirect_ip <= RSTIP;
	ex_redirect.current_ip <= RSTIP;
	restore_rfsrc <= FALSE;
	set_wfi <= FALSE;
	last_tid <= 6'd0;
	vtmp <= 64'h0;
	rd_trace <= FALSE;
	count <= 6'd0;
end
else begin
	a2d_rst <= FALSE;
	d2x_rst <= FALSE;
	mulreci.wr <= FALSE;
	divreci.wr <= FALSE;
	// Create a two cycle wide write pulse.
	membufi_wr1 <= membufi.wr;
//	if (membufi_wr1)
		membufi.wr <= FALSE;
	fpreci.wr <= FALSE;
	ex_redirect.wr <= FALSE;
	restore_rfsrc <= FALSE;
	set_wfi <= FALSE;
	execo.update <= FALSE;
	execo.wr_fu <= FALSE;
	execo.out <= FALSE;
	execo.out2 <= FALSE;
	rd_trace <= FALSE;

	$display("Execute");

	exvec <= 4'd0;
	if (robi.v==VAL && !robi.cmt && rob_exec != 6'd63) begin
		execo.rid <= robi.rid;
		execo.ip <= robi.ip;
		execo.step <= robi.step;
		execo.ia <= robi.ia;
		execo.cause <= robi.cause;
		execo.out <= FALSE;
		execo.takb <= FALSE;
		execo.wr_fu <= FALSE;
		execo.update <= FALSE;
		execo.update_c <= FALSE;
		execo.update_d <= FALSE;
		last_tid <= tid;
		exvec <= 4'd1;
		if (robi.dec) begin
			exvec <= 4'd2;
		$display("rid:%d ip: %h  ir: %h  a:%h%c  b:%h%c  c:%h%c  d:%h%c  i:%h", rob_exec, robi.ip, robi.ir,
			robi.ia.val,robi.iav?"v":" ",robi.ib.val,robi.ibv?"v":" ",
			robi.ic.val,robi.icv?"v":" ",robi.id.val,robi.idv?"v":" ",
			robi.imm);

		// If the instruction is exceptioned, then ignore executing it.
		if (robi.ui || robi.cause != 16'h0000) begin
			exvec <= 4'd4;
			execo.cmt <= TRUE;
			execo.cmt2 <= TRUE;
			execo.out <= TRUE;
		end
		else if (!robi.out) begin
			exvec <= 4'd3;
		execo.out <= TRUE;
		//robi.res.tag <= robi.ir.tag;
		execo.step <= robi.step;
		execo.takb <= FALSE;
		execo.wr_fu <= TRUE;
		execo.update <= !robi.mc;
		execo.cmt <= !robi.mc;
		execo.cmt2 <= !robi.mc;
		execo.res.val <= 64'hDEADDEADEADEAD;
		if (robi.ir[6:4]!=3'b101)	// not a modifier
			if (robi.ir[35:32]!=LSM || !robi.mem_op)
				count <= 6'd0;
		casez(robi.ir.r2.opcode)
		8'h7?:
			case(robi.ir[3:0])
			4'd0:
				case(robi.ir[12:8])
				5'd0:
					case(robi.ir[19:13])
					7'd120:	; // RTI (handled at WRITEBACK)
					7'd121:		// PFI
						begin
			      	if (irq_i != 1'b0)
					    	execo.cause <= 16'h8000|cause_i;
					    tMod();
				  	end
		  		7'd123:		begin set_wfi <= TRUE; tMod(); end	// WFI
					default:	begin execo.cause <= robi.ir[19:13]; tMod(); end	// BRK
					endcase
				default:
					tLoad(2'b00);
				endcase
			4'd1:	tLoad(2'b00);
			4'd2:	tStore(2'b00);
			4'd3:	tStore(2'b00);
			4'd4:
				case(robi.ir[19:18])
				2'd0:	tJalr();
				2'd1:	begin execo.res.val <= robi.ia.val; tMod(); end	// MOV
				2'd2: begin execo.res.val <= robi.ia.val + robi.ib.val; tMod(); end	// ADD
				2'd3: begin execo.res.val <= robi.ia.val & robi.ib.val; tMod(); end	// AND
				endcase
			4'd5:	begin execo.res.val <= robi.ia.val + robi.imm; tMod(); end
			4'd6:	begin execo.res.val <= robi.ia.val & robi.imm; tMod(); end
			4'd7:	begin execo.res.val <= robi.ia.val | robi.imm; tMod(); end
			4'd8:	tBranch();
			4'd9:	tBranch();
			4'd10:	tBal(TRUE);
			4'd11:	begin execo.res.val <= robi.imm; tMod(); end	// LDI
			4'd12:
				case(robi.ir[19:18])
				2'd0:	begin execo.res.val <= robi.ia.val << robi.imm[4:0]; tMod(); end
				2'd1:	begin execo.res.val <= robi.ia.val >> robi.imm[4:0]; tMod(); end
				2'd2:	begin execo.res.val <= robi.ia.val[VALUE_SIZE-1] ? ~({VALUE_SIZE{1'b1}} >> robi.imm[4:0]) | robi.ia.val >> robi.imm[4:0] : robi.ia.val >> robi.imm[4:0]; tMod(); end
				2'd3:
					begin
						case({robi.ir[17:16],robi.ir[12:11]})
						4'd0:	begin execo.res.val <= robi.ia.val - robi.ib.val; tMod(); end
						4'd1: begin execo.res.val <= robi.ia.val | robi.ib.val; tMod(); end
						4'd2: begin execo.res.val <= robi.ia.val ^ robi.ib.val; tMod(); end
						4'd3: begin execo.res.val <= ~(robi.ia.val & robi.ib.val); tMod(); end
						4'd4: begin execo.res.val <= ~(robi.ia.val | robi.ib.val); tMod(); end
						default:	;
						endcase
					end
				endcase
			4'd14:	tLoad(2'b00);
			4'd15:	tStore(2'b00);
			default:	;
			endcase
		BRK:	begin execo.cause <= robi.ir[21:14]; tMod(); end
		NOP:	tMod();
		R3:
			begin
				case(robi.ir.r2.func)
				SLLP:	begin execo.res.val <= sll_out[63:0]; tMod(); end
				PTRDIF:	
					begin
						//robi.res.tag <= TAG_INT;
						execo.res.val <= ((robi.ia.val < robi.ib.val) ? robi.ib.val - robi.ia.val : robi.ia.val - robi.ib.val) >> robi.ic.val[4:0];
						tMod();
					end
				CHK:
					case(robi.ir.r2.func)
					3'd0:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd1:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd2:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd3:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd4:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd5:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd6:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd7:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					default:
						begin
							tMod();
						end
					endcase
				default:	;
				endcase
			end
		R2:
			begin
				case(robi.ir.r2.func)
				ADD:	begin	execo.res.val <= robi.ia.val + robi.ib.val; tMod(); end
				SUB:	begin	execo.res.val <= robi.ia.val - robi.ib.val; tMod(); end
				AND:	begin	execo.res.val <= robi.ia.val & robi.ib.val; tMod(); end
				OR:		begin	execo.res.val <= robi.ia.val | robi.ib.val; tMod(); end
				XOR:	begin	execo.res.val <= robi.ia.val ^ robi.ib.val; tMod(); end
`ifdef SUPPORT_MYST				
				MYST:	begin execo.res.val <= {robi.id.val[35:29],robi.ir[28:8],robi.id.val[7:0]}; execo.myst <= TRUE; tMod(); end
`endif					
				BMMOR,BMMXOR,BMMTOR,BMMTXOR:	begin execo.res.val <= bmm_o; tMod(); end
				SLL:	begin execo.res.val <= sll_out2[VALUE_SIZE-1:0]; tMod(); end
				SLLI:	begin execo.res.val <= slli_out2[VALUE_SIZE-1:0]; tMod(); end
				SRL:	begin execo.res.val <= srl_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				SRLI:	begin execo.res.val <= srli_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				ROL:	begin execo.res.val <= sll_out2[VALUE_SIZE-1:0]|sll_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				ROLI:	begin execo.res.val <= slli_out2[VALUE_SIZE-1:0]|slli_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				ROR:	begin execo.res.val <= srl_out2[VALUE_SIZE-1:0]|srl_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				RORI:	begin execo.res.val <= srli_out2[VALUE_SIZE-1:0]|srli_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				SRA:	begin execo.res.val <= robi.ia.val[VALUE_SIZE-1] ? ~({VALUE_SIZE{1'b1}} >> robi.ib.val[5:0]) | srl_out2[VALUE_SIZE*2-1:VALUE_SIZE] : srl_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				SRAI:	begin execo.res.val <= robi.ia.val[VALUE_SIZE-1] ? ~({VALUE_SIZE{1'b1}} >> robi.imm[5:0]) | srli_out2[VALUE_SIZE*2-1:VALUE_SIZE] : srli_out2[VALUE_SIZE*2-1:VALUE_SIZE]; tMod(); end
				DIF:
					begin
						execo.res <= $signed(robi.ia.val) < $signed(robi.ib.val) ?
							robi.ib.val - robi.ia.val : robi.ia.val - robi.ib.val;
						tMod();
					end
				MUL,MULU,MULSU,MULH,MULUH,MULSUH:
					begin
						mulreci.rid <= rob_exec;
						mulreci.ir <= robi.ir;
						mulreci.a <= robi.ia;
						mulreci.b <= robi.ib;
						mulreci.wr <= TRUE;
						tMod();
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				DIV,DIVU,DIVSU:
					begin
						divreci.rid <= rob_exec;
						divreci.ir <= robi.ir;
						divreci.a <= robi.ia;
						divreci.b <= robi.ib;
						divreci.wr <= TRUE;
						tMod();
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				MULF:	begin execo.res.val <= robi.ia.val[23:0] * robi.ib.val[15:0]; tMod(); end
				CMP:	begin execo.res.val <= $signed(robi.ia.val) < $signed(robi.ib.val) ? -64'd1 : $signed(robi.ia.val) == $signed(robi.ib.val) ? 64'd0 : 64'd1; tMod(); end
				SEQ:	begin execo.res.val <= robi.ia.val == robi.ib.val; tMod(); end
				SNE:	begin execo.res.val <= robi.ia.val != robi.ib.val; tMod(); end
				SLT:	begin execo.res.val <= $signed(robi.ia.val) < $signed(robi.ib.val); tMod(); end
				SGE:	begin execo.res.val <= $signed(robi.ia.val) >= $signed(robi.ib.val); tMod(); end
				SLTU:	begin execo.res.val <= robi.ia.val < robi.ib.val; tMod(); end
				SGEU:	begin execo.res.val <= robi.ia.val >= robi.ib.val; tMod(); end
				default:	;
				endcase
			end
		R1:
			begin
				case(robi.ir.r2.func)
				ABS:	begin execo.res.val <= robi.ia[63] ? -robi.ia : robi.ia; tMod(); end
				NABS:	begin execo.res.val <= robi.ia[63] ? robi.ia : -robi.ia; tMod(); end
				NEG:	begin execo.res.val <= -robi.ia; tMod(); end
				NOT:	begin execo.res.val <= robi.ia==64'd0 ? 64'd1 : 64'd0; tMod(); end
				CTLZ:	begin execo.res.val <= cntlzo; tMod(); end
				CTPOP:	begin execo.res.val <= cntpopo; tMod(); end
				V2BITS:	begin
									if (robi.step==0) begin
										if (robi.vmask[0]) begin
											execo.res.val <= {63'd0,robi.ia.val[0]};
											vtmp <= {63'd0,robi.ia.val[0]};
										end
										else if (robi.irmod.im.z) begin
											execo.res.val <= 64'd0;
											vtmp <= 64'd0;
										end
									end
									else begin
										if (robi.vmask[robi.step]) begin
											execo.res.val <= vtmp | (robi.ia.val[0] << robi.step);
											vtmp <= vtmp | (robi.ia.val[0] << robi.step);
										end
									end
									tMod(); 
								end
`ifdef SUPPORT_GRAPHICS								
				TRANSFORM:
					begin
						graphi.rid <= rob_exec;
						graphi.ir <= robi.ir;
						graphi.ia <= robi.ia;
						graphi.ib <= robi.ib;
						graphi.ic <= robi.ic;
						graphi.wr <= TRUE;
						tMod();
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				CLIP:
					begin
						execo.res.val <=
							((robi.ia.val[31:0] < gr_target.ul.x) ||
							 	(robi.ia.val[63:32] < gr_target.ul.y) ||
							 	(robi.ia.val[31:0] >= gr_target.lr.x) ||
							 	(robi.ia.val[63:32] >= gr_target.lr.y) ||
							 	clip_en && (
									(robi.ia.val[31:0] < gr_clip.ul.x) ||
							 		(robi.ia.val[63:32] < gr_clip.ul.y) ||
							 		(robi.ia.val[31:0] >= gr_clip.lr.x) ||
							 		(robi.ia.val[63:32] >= gr_clip.lr.y) ||	
							 	));
					end
`endif					
				default:	;
				endcase
			end
`ifdef SUPPORT_FLOAT			
		F1,VF1:
			begin
				case(robi.ir.r2.func)
				FABS:	begin execo.res.val <= {1'b0,robi.ia.val[62:0]}; tMod(); end
				FNABS:begin execo.res.val <= {1'b1,robi.ia.val[62:0]}; tMod(); end
				FNEG:	begin execo.res.val <= {~robi.ia.val[63],robi.ia.val[62:0]}; tMod(); end
				I2F,F2I,FSQRT:
					begin
						fpreci.rid <= rob_exec;
						fpreci.a <= robi.ia;
						fpreci.wr <= TRUE;
						tMod(); 
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				FRM:	begin execo.res.val <= robi.ia.val; tMod(); end
				default:	;
				endcase
			end
		F2,VF2:
			begin
				case(robi.ir.r2.func)
				CPYSGN: begin execo.res.val <= { robi.ib.val[63],robi.ia.val[62:0]}; tMod(); end
				SGNINV: begin execo.res.val <= {~robi.ib.val[63],robi.ia.val[62:0]}; tMod(); end
				FADD,FSUB,FMUL,FDIV:
					begin
						fpreci.rid <= rob_exec;
						fpreci.a <= robi.ia;
						fpreci.b <= robi.ib;
						fpreci.wr <= TRUE;
						tMod(); 
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				FMIN:	// FMIN	
					begin
						if ((fa_snan|fb_snan)||(fa_qnan&fb_qnan))
							execo.res.val <= 64'h7FFFFFFFFFFFFFFF;	// canonical NaN
						else if (fa_qnan & !fb_nan)
							execo.res.val <= robi.ib.val;
						else if (!fa_nan & fb_qnan)
							execo.res.val <= robi.ia.val;
						else if (fcmp_o[1])
							execo.res.val <= robi.ia.val;
						else
							execo.res.val <= robi.ib.val;
						tMod();
					end
				FMAX:	// FMAX
					begin
						if ((fa_snan|fb_snan)||(fa_qnan&fb_qnan))
							execo.res.val <= 64'h7FFFFFFFFFFFFFFF;	// canonical NaN
						else if (fa_qnan & !fb_nan)
							execo.res.val <= robi.ib.val;
						else if (!fa_nan & fb_qnan)
							execo.res.val <= robi.ia.val;
						else if (fcmp_o[1])
							execo.res.val <= robi.ib.val;
						else
							execo.res.val <= robi.ia.val;
						tMod();
					end
				FCMP:	begin execo.res.val <=  cmpnan ? 64'h4000000000000000 : fcmp_o[1] ? 64'hBFF0000000000000 : fcmp_o[0] ? 64'd0 : 64'h3FF0000000000000;	tMod(); end	//2,-1,0,1 
				FCMPB:begin	execo.res.val <=  fcmp_o; tMod(); end
				FSEQ:	begin execo.res.val <=  fcmp_o[0] & ~cmpnan; tMod(); end
				FSNE: begin execo.res.val <= ~fcmp_o[0] & ~cmpnan; tMod(); end
				FSLT:	begin execo.res.val <=  fcmp_o[1] & ~cmpnan; tMod(); end
				FSLE:	begin execo.res.val <=  fcmp_o[2] & ~cmpnan; tMod(); end
				FSETM:
					if (robi.step==6'd0) begin
						execo.res.val <= 64'd0;
						vtmp <= 64'd0;
						case(robi.ir[13:11])
						3'd0:	begin execo.res.val[robi.step] <=  fcmp_o[0]; vtmp <=  fcmp_o[0]; end
						3'd1:	begin execo.res.val[robi.step] <= ~fcmp_o[0]; vtmp <= ~fcmp_o[0]; end
						3'd2:	begin execo.res.val[robi.step] <=  fcmp_o[1]; vtmp <=  fcmp_o[1]; end
						3'd3:	begin execo.res.val[robi.step] <=  fcmp_o[2]; vtmp <=  fcmp_o[2]; end
						default:	;
						endcase
						tMod();
					end
					else begin
						execo.res.val <= vtmp;
						case(robi.ir[13:11])
						3'd0:	begin execo.res.val[robi.step] <=  fcmp_o[0]; vtmp[robi.step] <=  fcmp_o[0]; end
						3'd1:	begin execo.res.val[robi.step] <= ~fcmp_o[0]; vtmp[robi.step] <= ~fcmp_o[0]; end
						3'd2:	begin execo.res.val[robi.step] <=  fcmp_o[1]; vtmp[robi.step] <=  fcmp_o[1]; end
						3'd3:	begin execo.res.val[robi.step] <=  fcmp_o[2]; vtmp[robi.step] <=  fcmp_o[2]; end
						default:	;
						endcase
						tMod();
					end
				default:	;
				endcase
			end
		F3,VF3:
			begin
				case(robi.ir.r2.func)
				MADD,MSUB,NMADD,NMSUB:
					begin
						fpreci.rid <= rob_exec;
						fpreci.a <= robi.ia;
						fpreci.b <= robi.ib;
						fpreci.c <= robi.ic;
						fpreci.wr <= TRUE;
						tMod(); 
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				default:	;
				endcase
			end
`endif
		ADDI:	begin execo.res.val <= robi.ia.val + robi.imm; tMod(); end
		SUBFI:begin execo.res.val <= robi.imm - robi.ia.val; tMod(); end
		ANDI:	begin execo.res.val <= robi.ia.val & robi.imm; tMod(); end
		ORI:	begin execo.res.val <= robi.ia.val | robi.imm; tMod(); end
		XORI:	begin execo.res.val <= robi.ia.val ^ robi.imm; tMod(); end
`ifdef SUPPORT_MYST
		MYSTI:	begin execo.res.val <= {robi.id.val[35:20],robi.ir[19:8],robi.id.val[7:0]}; execo.myst <= TRUE; tMod(); end
`endif
		MULI,MULUI,MULSUI:
				begin
					begin
						mulreci.rid <= rob_exec;
						mulreci.a <= robi.ia;
						mulreci.imm <= robi.imm;
						mulreci.wr <= TRUE;
						tMod(); 
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				end
		DIVI,DIVUI,DIVSUI:
				begin
					begin
						divreci.rid <= rob_exec;
						divreci.a <= robi.ia;
						divreci.imm <= robi.imm;
						divreci.wr <= TRUE;
						tMod(); 
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				end
		MULFI:begin execo.res.val <= robi.ia.val[23:0] * robi.imm[15:0]; tMod(); end
		SEQI:	begin execo.res.val <= robi.ia.val == robi.imm; tMod(); end
		SNEI:	begin execo.res.val <= robi.ia != robi.imm; tMod(); end
		SLTI:	begin execo.res.val <= $signed(robi.ia.val) < $signed(robi.imm); tMod(); end
		SGTI:	begin execo.res.val <= $signed(robi.ia.val) > $signed(robi.imm); tMod(); end
		SLTUI:	begin execo.res.val <= robi.ia.val < robi.imm; tMod(); end
		SGTUI:	begin execo.res.val <= robi.ia.val > robi.imm; tMod(); end
		BTFLD:	begin execo.res.val <= bf_out.val; tMod(); execo.cmt <= TRUE; end
    BYTNDX:
	    begin
	    	if (robi.ir.r2.func[6:3]!=4'd0) begin
	        if (robi.ia.val[7:0]==robi.imm[7:0])
	          execo.res.val <= 64'd0;
	        else if (robi.ia.val[15:8]==robi.imm[7:0])
	          execo.res.val <= 64'd1;
	        else if (robi.ia.val[23:16]==robi.imm[7:0])
	          execo.res.val <= 64'd2;
	        else if (robi.ia.val[31:24]==robi.imm[7:0])
	          execo.res.val <= 64'd3;
	        else if (robi.ia.val[39:32]==robi.imm[7:0])
	          execo.res.val <= 64'd4;
	        else if (robi.ia.val[47:40]==robi.imm[7:0])
	          execo.res.val <= 64'd5;
	        else if (robi.ia.val[55:40]==robi.imm[7:0])
	          execo.res.val <= 64'd6;
	        else if (robi.ia.val[63:56]==robi.imm[7:0])
	          execo.res.val <= 64'd7;
	        else
	          execo.res.val <= {64{1'b1}};  // -1
	      end
	      else begin
	        if (robi.ia.val[7:0]==robi.ib.val[7:0])
	          execo.res.val <= 64'd0;
	        else if (robi.ia.val[15:8]==robi.ib.val[7:0])
	          execo.res.val <= 64'd1;
	        else if (robi.ia.val[23:16]==robi.ib.val[7:0])
	          execo.res.val <= 64'd2;
	        else if (robi.ia.val[31:24]==robi.ib.val[7:0])
	          execo.res.val <= 64'd3;
	        else if (robi.ia.val[39:32]==robi.ib.val[7:0])
	          execo.res.val <= 64'd4;
	        else if (robi.ia.val[47:40]==robi.ib.val[7:0])
	          execo.res.val <= 64'd5;
	        else if (robi.ia.val[55:40]==robi.ib.val[7:0])
	          execo.res.val <= 64'd6;
	        else if (robi.ia.val[63:56]==robi.ib.val[7:0])
	          execo.res.val <= 64'd7;
	        else
	          execo.res.val <= {64{1'b1}};  // -1
	      end
	      tMod();
	    end
`ifdef U10NDX
    U10NDX:
    begin
    	if (robi.ir.sz==4'd1) begin
        if (robi.ia.val[9:0]==robi.imm[9:0])
          execo.res.val <= 64'd0;
        else if (robi.ia.val[19:10]==robi.imm[9:0])
          execo.res.val <= 64'd1;
        else if (robi.ia.val[29:20]==robi.imm[9:0])
          execo.res.val <= 64'd2;
        else if (robi.ia.val[39:30]==robi.imm[9:0])
          execo.res.val <= 64'd3;
        else if (robi.ia.val[49:40]==robi.imm[9:0])
          execo.res.val <= 64'd4;
        else if (robi.ia.val[59:50]==robi.imm[9:0])
          execo.res.val <= 64'd5;
        else
          execo.res.val <= {64{1'b1}};  // -1
      end
      else begin
        if (robi.ia.val[9:0]==robi.ib.val[9:0])
          execo.res.val <= 64'd0;
        else if (robi.ia.val[19:10]==robi.ib.val[9:0])
          execo.res.val <= 64'd1;
        else if (robi.ia.val[29:20]==robi.ib.val[9:0])
          execo.res.val <= 64'd2;
        else if (robi.ia.val[39:30]==robi.ib.val[9:0])
          execo.res.val <= 64'd3;
        else if (robi.ia.val[49:40]==robi.ib.val[9:0])
          execo.res.val <= 64'd4;
        else if (robi.ia.val[59:50]==robi.ib.val[9:0])
          execo.res.val <= 64'd5;
        else
          execo.res.val <= {64{1'b1}};  // -1
      end
      tMod();
    end
`endif
    U21NDX:
			begin
	    	if (robi.ir.r2.func[6:3]!=4'd0) begin
	        if (robi.ia.val[20:0]==robi.imm[20:0])
	          execo.res.val <= 64'd0;
	        else if (robi.ia.val[41:21]==robi.imm[20:0])
	          execo.res.val <= 64'd1;
	        else if (robi.ia.val[62:42]==robi.imm[20:0])
	          execo.res.val <= 64'd2;
	        else
	          execo.res.val <= {64{1'b1}};  // -1
	      end
	      else begin
	        if (robi.ia.val[20:0]==robi.ib.val[20:0])
	          execo.res.val <= 64'd0;
	        else if (robi.ia.val[41:21]==robi.ib.val[20:0])
	          execo.res.val <= 64'd1;
	        else if (robi.ia.val[62:42]==robi.ib.val[20:0])
	          execo.res.val <= 64'd2;
	        else
	          execo.res.val <= {64{1'b1}};  // -1
	      end
	      tMod();
	    end
    PERM:
			begin
	    	if (robi.ir.r2.func!=4'd0) begin
	    		execo.res.val[7:0] <= robi.ia.val >> {robi.imm[2:0],3'b0};
	    		execo.res.val[15:8] <= robi.ia.val >> {robi.imm[5:3],3'b0};
	    		execo.res.val[23:16] <= robi.ia.val >> {robi.imm[8:6],3'b0};
	    		execo.res.val[31:24] <= robi.ia.val >> {robi.imm[11:9],3'b0};
	    		execo.res.val[39:32] <= robi.ia.val >> {robi.imm[14:12],3'b0};
	    		execo.res.val[47:40] <= robi.ia.val >> {robi.imm[17:15],3'b0};
	    		execo.res.val[55:48] <= robi.ia.val >> {robi.imm[20:18],3'b0};
	    		execo.res.val[63:56] <= robi.ia.val >> {robi.imm[23:21],3'b0};
					tMod();
				end
				else if (robi.ibv) begin
	    		execo.res.val[7:0] <= robi.ia.val >> {robi.ib.val[2:0],3'b0};
	    		execo.res.val[15:8] <= robi.ia.val >> {robi.ib.val[5:3],3'b0};
	    		execo.res.val[23:16] <= robi.ia.val >> {robi.ib.val[8:6],3'b0};
	    		execo.res.val[31:24] <= robi.ia.val >> {robi.ib.val[11:9],3'b0};
	    		execo.res.val[39:32] <= robi.ia.val >> {robi.ib.val[14:12],3'b0};
	    		execo.res.val[47:40] <= robi.ia.val >> {robi.ib.val[17:15],3'b0};
	    		execo.res.val[55:48] <= robi.ia.val >> {robi.ib.val[20:18],3'b0};
	    		execo.res.val[63:56] <= robi.ia.val >> {robi.ib.val[23:21],3'b0};
					tMod();
				end
			end    	
		CHKI:
			begin
				case(robi.ir.r2.Rt[2:0])
				3'd0:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd1:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd2:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd3:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd4:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd5:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd6:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd7:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				endcase
			end
		BEQ,BNE,BLT,BGE,BLTU,BGEU,BBS:
			tBranch();
		JALR:	tJalr();
		JAL:
			begin
				//execo.jump <= TRUE;
				//execo.jump_tgt <= robi.imm;
				execo.res.val <= fnIncIP(robi.ip);
				a2d_rst <= TRUE;
				d2x_rst <= TRUE;
				ex_redirect.redirect_ip <= robi.imm;
				ex_redirect.current_ip <= robi.ip;
				ex_redirect.xrid <= rob_exec;
				ex_redirect.step <= 6'd0;
				ex_redirect.wr <= TRUE;
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.update <= TRUE;
			end
		BAL:	tBal(FALSE);
`ifdef SUPPORT_CALL_RET			
		CALL:
			begin
				membufi.rid <= rob_exec;
				membufi.step <= robi.step;
				membufi.ir <= robi.ir;
				membufi.ia.val <= robi.ia.val - 4'd8;
				membufi.ib.val <= fnIncIP(robi.ip);
				membufi.ic <= robi.ic;
				membufi.dato <= fnIncIP(robi.ip);
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				tMod();
				a2d_rst <= TRUE;
				d2x_rst <= TRUE;
				ex_redirect.redirect_ip <= robi.ir[8] ? robi.imm : robi.ip + robi.imm;
				ex_redirect.current_ip <= robi.ip;
				ex_redirect.xrid <= rob_exec;
				ex_redirect.step <= 6'd0;
				ex_redirect.wr <= TRUE;
				execo.res.val <= robi.ia.val - 4'd8;	// decrement SP
				execo.update <= TRUE;
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.out2 <= TRUE;
				execo.wr_fu <= TRUE;
			end
		RTS:
			begin
				membufi.rid <= rob_exec;
				membufi.step <= robi.step;
				membufi.ir <= robi.ir;
				membufi.ia <= robi.ia;
				membufi.ib <= robi.ib;
				membufi.ic <= robi.ic;
				membufi.dato <= robi.ib;
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				execo.res.val <= robi.ia.val + {robi.imm[63:3],3'b0};	// increment SP
				execo.update <= TRUE;
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.wr_fu <= TRUE;
			end
`endif			
		LEA,LDx,LDxX,LDxZ,LDxXZ:
			tLoad(2'b01);
		STx,STxX:
			tStore(2'b01);
		LDSx:
			//if (memfifo_wr==FALSE) begin	// prevent back-to-back screwup
			begin
			if (robi.vmask[robi.step]) begin
				membufi.rid <= rob_exec;
				membufi.step <= robi.step;
				membufi.ir <= robi.ir;
				membufi.ia <= robi.ia;
				membufi.ib <= robi.ib;
				membufi.ic <= robi.ic;
				membufi.dato <= robi.ib;
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				tMod();
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.wr_fu <= FALSE;
			end
			else if (robi.irmod.im.z)
				tDoOp(64'd0);
			else begin
				tDoOp(64'd0);
				execo.vrfwr <= FALSE;
			end
			end
		STSx:
			//if (memfifo_wr==FALSE) begin	// prevent back-to-back screwup
			// This does not wait for registers to be valid.
			begin
			if (robi.vmask[robi.step]) begin
				membufi.rid <= rob_exec;
				membufi.step <= robi.step;
				membufi.ir <= robi.ir;
				membufi.ia <= robi.ia;
				membufi.ib <= robi.ib;
				membufi.ic <= robi.ic;
				membufi.dato <= robi.ib;
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				tMod();
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.wr_fu <= FALSE;
				execo.out <= TRUE;
			end
			else if (robi.irmod.im.z) begin
				membufi.rid <= rob_exec;
				membufi.step <= robi.step;
				membufi.ir <= robi.ir;
				membufi.ia <= robi.ia;
				membufi.ib <= robi.ib;
				membufi.ic <= robi.ic;
				membufi.dato <= 64'd0;
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				tMod();
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.wr_fu <= FALSE;
				execo.out <= TRUE;
			end
			else begin
				tDoOp(64'd0);
				execo.vrfwr <= FALSE;
			end
			end
		CVLDSx:
			//if (memfifo_wr==FALSE) begin	// prevent back-to-back screwup
			// This does not wait for registers to be valid.
			begin
			if (robi.vmask[robi.step]) begin
				vtmp[5:0] <= vtmp[5:0] + 2'd1;
				membufi.rid <= rob_exec;
				membufi.step <= vtmp[5:0];
				membufi.ir <= robi.ir;
				membufi.ia <= robi.ia;
				membufi.ib <= robi.ib;
				membufi.ic <= robi.ic;
				membufi.dato <= robi.ib;
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				tMod();
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.wr_fu <= FALSE;
				execo.out <= TRUE;
			end
			else if (robi.irmod.im.z)
				tDoOp(64'd0);
			else begin
				tDoOp(64'd0);
				execo.vrfwr <= FALSE;
			end
			end
		CVSTSx:
			//if (memfifo_wr==FALSE) begin	// prevent back-to-back screwup
			// This does not wait for registers to be valid.
			begin
			if (robi.vmask[robi.step]) begin
				vtmp[5:0] <= vtmp[5:0] + 2'd1;
				membufi.rid <= rob_exec;
				membufi.step <= vtmp[5:0];
				membufi.ir <= robi.ir;
				membufi.ia <= robi.ia;
				membufi.ib <= robi.ib;
				membufi.ic <= robi.ic;
				membufi.dato <= robi.ib;
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				tMod();
				execo.cmt <= FALSE;
				execo.cmt2 <= FALSE;
				execo.wr_fu <= FALSE;
				execo.out <= TRUE;
			end
			else begin
				tDoOp(64'd0);
				execo.vrfwr <= FALSE;
			end
			end
		CSR:
			begin
				execo.ia <= robi.ia;
				case({robi.ir.r2.Ta,robi.ir.r2.Tt})
				CSRR:	execo.res <= csrro;
				CSRW,CSRS,CSRC:	;
//				CSRRW:	execo.res <= csrro;
				default:	;
				endcase
		    tMod();
			end
		SYS:
			case(robi.ir.r2.func)
			POPQ:
				begin
					case(robi.ia[5:0])
					6'd15:	
						begin
							execo.res <= trace_dout;
							rd_trace <= TRUE;
							tMod();
						end
					default:	;
					endcase
				end
			POPQI:
				begin
					case(robi.ir.r2.Ra)
					6'd15:	
						begin
							execo.res <= trace_dout;
							rd_trace <= TRUE;
							tMod();
						end
					default:	;
					endcase
				end
			PEEKQ:
				begin
					case(robi.ia[5:0])
					6'd15:	
						begin
							execo.res <= trace_dout;
							tMod();
						end
					default:	;
					endcase
				end
			PEEKQI:
				begin
					case(robi.ir.r2.Ra)
					6'd15:	
						begin
							execo.res <= trace_dout;
							tMod();
						end
					default:	;
					endcase
				end
			PFI:
				begin
	      	if (irq_i != 1'b0)
			    	execo.cause <= 16'h8000|cause_i;
			    tMod();
		  	end
		  WFI:	begin set_wfi <= TRUE; tMod(); end
			TLBRW:
				begin
					membufi.rid <= rob_exec;
					membufi.step <= robi.step;
					membufi.ir <= robi.ir;
					membufi.ia <= robi.ia;
					membufi.ib <= robi.ib;
					membufi.imm <= robi.imm;
					membufi.wr <= TRUE;
					tMod();
					execo.cmt <= FALSE;
					execo.cmt2 <= FALSE;
					execo.wr_fu <= FALSE;
					execo.out <= TRUE;
				end
`ifdef SUPPORT_EXEC
			EXEC:
				begin
					execo.exec <= TRUE;
					execo.res.val <= robi.ia.val;
					tMod();
				end
`endif				
			CSAVE:		tStore(2'b10);
			CRESTORE:	tLoad(2'b10);
			default:	;
			endcase
		// Some of the modifiers should never execute because they are committed
		// immediately at decode.
		RGLST0,RGLST1,RGLST2,RGLST3:	tMod();
		EXI0,EXI1,EXI2:	tMod();
		IMOD:
			begin
				execo.update_c <= TRUE;
				execo.update_d <= TRUE;
				execo.ia <= robi.ia;
				execo.ib <= robi.ib;
				tMod();
			end
		BRMOD:
			begin
				execo.update_c <= TRUE;
				execo.ia <= robi.ia;
				tMod();
			end
		STRIDE:
			begin
				execo.update_c <= TRUE;
				execo.update_d <= TRUE;
				execo.ia <= robi.ia;
				execo.ib <= robi.ib;
				tMod();
			end
		8'hFF:
			;//rob_exec <= rob_exec;
`ifdef SUPPORT_VECTOR
		VR1:
			begin
				case(robi.ir.r2.func)
				ABS:	begin
								execo.update <= TRUE;
								if (robi.vmask.val[robi.step]) begin
									execo.res.val <= robi.ia[63] ? -robi.ia : robi.ia;
									execo.cmt <= TRUE;
									execo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									execo.res.val <= 64'd0;
						  end
				NABS:	begin
								execo.update <= TRUE;
								if (robi.vmask.val[robi.step]) begin
									execo.res.val <= robi.ia[63] ? robi.ia : -robi.ia;
									execo.cmt <= TRUE;
									execo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									execo.res.val <= 64'd0;
						  end
				NEG:	begin
								execo.update <= TRUE;
								if (robi.vmask.val[robi.step]) begin
									execo.res.val <= -robi.ia;
									execo.cmt <= TRUE;
									execo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									execo.res.val <= 64'd0;
						  end
				NOT:	begin
								execo.update <= TRUE;
								if (robi.vmask.val[robi.step]) begin
									execo.res.val <= robi.ia==64'd0 ? 64'd1 : 64'd0;
									execo.cmt <= TRUE;
									execo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									execo.res.val <= 64'd0;
							end
				CTLZ:	begin
								execo.update <= TRUE;
								if (robi.vmask.val[robi.step]) begin
									execo.res.val <= cntlzo;
									execo.cmt <= TRUE;
									execo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									execo.res.val <= 64'd0;
							end
				CTPOP:begin
								execo.update <= TRUE;
								if (robi.vmask.val[robi.step]) begin
									execo.res.val <= cntpopo;
									execo.cmt <= TRUE;
									execo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									execo.res.val <= 64'd0;
							end
				V2BITS:	
					if (robi.iav) begin
						if (robi.step==0) begin
							if (robi.vmask[0]) begin
								execo.res.val <= {63'd0,robi.ia.val[0]};
								vtmp <= {63'd0,robi.ia.val[0]};
							end
							else if (robi.irmod.im.z) begin
								execo.res.val <= 64'd0;
								vtmp <= 64'd0;
							end
						end
						else begin
							if (robi.vmask[robi.step]) begin
								execo.res.val <= vtmp | (robi.ia.val[0] << robi.step);
								vtmp <= vtmp | (robi.ia.val[0] << robi.step);
							end
						end
						tMod();
						if (robi.step + 2'd1 >= vl)
							execo.vcmt <= TRUE;
					end
				BITS2V:
					if (robi.iav) begin
						tDoOp(robi.ia.val[robi.step]);
					end
				VCMPRSS:
					begin
						if (robi.step==6'd0)
							vtmp[5:0] <= 6'd0;
						execo.res <= robi.ia;
						if (robi.vmask[robi.step]) begin
							execo.res_ele <= |robi.step ? vtmp[5:0] : 6'd0;
							vtmp[5:0] <= vtmp[5:0] + 2'd1;
						end
						tMod();
					end
				VCIDX:
					begin
						if (robi.step==6'd0)
							vtmp[5:0] <= 6'd0;
						execo.res <= robi.ia * robi.step;
						if (robi.vmask[robi.step]) begin
							execo.res_ele <= |robi.step ? vtmp[5:0] : 6'd0;
							vtmp[5:0] <= vtmp[5:0] + 2'd1;
						end
						tMod();
					end
				VSCAN:
					begin
						execo.res.val <= vtmp;
						if (robi.step==6'd0) begin
							vtmp <= 64'd0;
							execo.res.val <= 64'd0;
						end
						else if (robi.vmask[robi.step])
							vtmp <= vtmp + robi.ia.val;
						tMod();
					end
				default:	;
				endcase
			end
		VR2:
			begin
				case(robi.ir.r2.func)
				ADD:	tDoOp(robi.ia.val + robi.ib.val);
				SUB:	tDoOp(robi.ia.val - robi.ib.val);
				AND:	tDoOp(robi.ia.val & robi.ib.val);
				OR:		tDoOp(robi.ia.val | robi.ib.val);
				XOR:	tDoOp(robi.ia.val ^ robi.ib.val);
				SLL:	tDoOp(robi.ia.val << robi.ib.val[5:0]);
				SLLI:	tDoOp(robi.ia.val << {robi.ir.r2.Tb[0],robi.ir.r2.Rb[4:0]});
				SRL:	tDoOp(execo.res.val <= robi.ia.val >> robi.ib.val[5:0]);
				SRLI:	tDoOp(execo.res.val <= robi.ia.val >> {robi.ir.r2.Tb[0],robi.ir.r2.Rb[4:0]});
				DIF:
					begin
						tDoOp($signed(robi.ia.val) < $signed(robi.ib.val) ?
							robi.ib.val - robi.ia.val : robi.ia.val - robi.ib.val);
					end
				MUL,MULU,MULSU,MULH,MULUH,MULSUH:
					begin
						mulreci.rid <= rob_exec;
						mulreci.ir <= robi.ir;
						mulreci.a <= robi.ia;
						mulreci.b <= robi.ib;
						mulreci.wr <= TRUE;
						tMod();
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.vcmt <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				DIV,DIVU,DIVSU:
					begin
						divreci.rid <= rob_exec;
						divreci.ir <= robi.ir;
						divreci.a <= robi.ia;
						divreci.b <= robi.ib;
						divreci.wr <= TRUE;
						tMod();
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.vcmt <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				MULF:	tDoOp(robi.ia.val[23:0] * robi.ib.val[15:0]);
				CMP:	tDoOp($signed(robi.ia.val) < $signed(robi.ib.val) ? -64'd1 : $signed(robi.ia.val) == $signed(robi.ib.val) ? 64'd0 : 64'd1);
				SEQ:	tDoOp(robi.ia.val == robi.ib.val);
				SNE:	tDoOp(robi.ia.val != robi.ib.val);
				SLT:	tDoOp($signed(robi.ia.val) < $signed(robi.ib.val));
				SGE:	tDoOp($signed(robi.ia.val) >= $signed(robi.ib.val));
				SLTU:	tDoOp(robi.ia.val < robi.ib.val);
				SGEU:	tDoOp(robi.ia.val >= robi.ib.val);
				SETM:
					if (robi.step==6'd0) begin
						execo.res.val <= 64'd0;
						vtmp <= 64'd0;
						case(robi.ir[13:11])
						3'd0:	begin execo.res.val[robi.step] <= robi.ia.val==robi.ib.val; vtmp <= robi.ia.val==robi.ib.val; end
						3'd1:	begin execo.res.val[robi.step] <= robi.ia.val!=robi.ib.val; vtmp <= robi.ia.val!=robi.ib.val; end
						3'd2:	begin execo.res.val[robi.step] <= $signed(robi.ia.val)< $signed(robi.ib.val); vtmp <= $signed(robi.ia.val)< $signed(robi.ib.val); end
						3'd3:	begin execo.res.val[robi.step] <= $signed(robi.ia.val)<=$signed(robi.ib.val); vtmp <= $signed(robi.ia.val)<=$signed(robi.ib.val); end
						3'd4:	begin execo.res.val[robi.step] <= robi.ia.val< robi.ib.val; vtmp <= robi.ia.val< robi.ib.val; end
						3'd5:	begin execo.res.val[robi.step] <= robi.ia.val<=robi.ib.val; vtmp <= robi.ia.val<=robi.ib.val; end
						default:	;
						endcase
						tMod();
					end
					else begin
						execo.res.val <= vtmp;
						case(robi.ir[13:11])
						3'd0:	begin execo.res.val[robi.step] <= robi.ia.val==robi.ib.val; vtmp[robi.step] <= robi.ia.val==robi.ib.val; end
						3'd1:	begin execo.res.val[robi.step] <= robi.ia.val!=robi.ib.val; vtmp[robi.step] <= robi.ia.val!=robi.ib.val; end
						3'd2:	begin execo.res.val[robi.step] <= $signed(robi.ia.val)< $signed(robi.ib.val); vtmp[robi.step] <= $signed(robi.ia.val)< $signed(robi.ib.val); end
						3'd3:	begin execo.res.val[robi.step] <= $signed(robi.ia.val)<=$signed(robi.ib.val); vtmp[robi.step] <= $signed(robi.ia.val)<=$signed(robi.ib.val); end
						3'd4:	begin execo.res.val[robi.step] <= robi.ia.val< robi.ib.val; vtmp[robi.step] <= robi.ia.val< robi.ib.val; end
						3'd5:	begin execo.res.val[robi.step] <= robi.ia.val<=robi.ib.val; vtmp[robi.step] <= robi.ia.val<=robi.ib.val; end
						default:	;
						endcase
						tMod();
					end
				VEX:
					if (robi.step_v) begin
						execo.res.val <= robi.ib;
						tMod();
					end
					else begin
						execo.step_v <= TRUE;
						execo.step <= robi.ia[5:0];
					end
				VEINS:
					if (robi.step_v)
						tDoOp(robi.ib);
					else begin
						execo.step_v <= TRUE;
						execo.step <= robi.ia[5:0];
					end
				VSLLV:
					begin
						if ({2'b0,robi.ia_ele} + robi.ib.val[11:6] <= vl) begin
							execo.res_ele <= robi.ia_ele + robi.ib.val[11:6];
							tDoOp(sll_out2[63:0]|vtmp);
							vtmp <= sll_out2[127:64];
						end
						else begin
							execo.res_ele <= robi.ia_ele - vl - 2'd1;
							tDoOp(64'd0);
						end
					end
				VSRLV:
					begin
						if (robi.ia_ele >= robi.ib.val[11:6]) begin
							execo.res_ele <= robi.ia_ele - robi.ib.val[11:6];
							tDoOp(vtmp|srl_out2[127:64]);
							vtmp <= srl_out2[63:0];
						end
						else begin
							execo.res_ele <= robi.ia_ele;
							tDoOp(64'd0);
						end
					end
`ifdef SUPPORT_MYST				
				MYST:	begin execo.res.val <= {robi.id.val[35:29],robi.ir[28:8],robi.id.val[7:0]}; execo.myst <= TRUE; tMod(); end
`endif					
				default:	;
				endcase
			end
		VR3:
			begin
				case(robi.ir.r2.func)
				SLLP:	tDoOp(execo.res.val <= sll_out[63:0]);
				PTRDIF:	tDoOp(((robi.ia.val < robi.ib.val) ? robi.ib.val - robi.ia.val : robi.ia.val - robi.ib.val) >> robi.ic.val[4:0]);
				CHK:
					case(robi.ir.r2.func)
					3'd0:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd1:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd2:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd3:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.ib.val)) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd4:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd5:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd6:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					3'd7:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							execo.cause <= FLT_CHK;
							tMod();
						end
					default:
						begin
							tMod();
						end
					endcase
				default:	;
				endcase
			end
		VADDI:	tDoOp(robi.ia.val + robi.imm);
		VSUBFI:	tDoOp(robi.imm - robi.ia.val);
		VANDI:	tDoOp(robi.ia.val & robi.imm);
		VORI:		tDoOp(robi.ia.val | robi.imm);
		VXORI:	tDoOp(robi.ia.val ^ robi.imm);
		VMULI,VMULUI,VMULSUI:
				begin
					begin
						mulreci.rid <= rob_exec;
						mulreci.a <= robi.ia;
						mulreci.imm <= robi.imm;
						mulreci.wr <= TRUE;
						tMod(); 
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.vcmt <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				end
		VDIVI,VDIVUI,VDIVSUI:
				begin
					begin
						divreci.rid <= rob_exec;
						divreci.a <= robi.ia;
						divreci.imm <= robi.imm;
						divreci.wr <= TRUE;
						tMod(); 
						execo.cmt <= FALSE;
						execo.cmt2 <= FALSE;
						execo.vcmt <= FALSE;
						execo.wr_fu <= FALSE;
						execo.out <= TRUE;
					end
				end
		VMULFI:	tDoOp(robi.ia.val[23:0] * robi.imm[15:0]);
		VSEQI:	tDoOp(robi.ia.val == robi.imm);
		VSNEI:	tDoOp(robi.ia != robi.imm);
		VSLTI:	tDoOp($signed(robi.ia.val) < $signed(robi.imm));
		VSGTI:	tDoOp($signed(robi.ia.val) > $signed(robi.imm));
		VSLTUI:	tDoOp(robi.ia.val < robi.imm);
		VSGTUI:	tDoOp(robi.ia.val > robi.imm);
		VBTFLD:	tDoOp(bf_out.val);
    VBYTNDX:
	    begin
	   		if (vtmp==64'd0 | robi.Rt[6]) begin
		    	if (robi.ir.r2.func[6:3]!=4'd0) begin
		        if (robi.ia.val[7:0]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'b0};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'b0});
		        end
		        else if (robi.ia.val[15:8]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'd1};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd1});
		        end
		        else if (robi.ia.val[23:16]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'd2};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd2});
		        end
		        else if (robi.ia.val[31:24]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'd3};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd3});
		        end
		        else if (robi.ia.val[39:32]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'd4};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd4});
		        end
		        else if (robi.ia.val[47:40]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'd5};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd5});
		        end
		        else if (robi.ia.val[55:40]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'd6};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd6});
		        end
		        else if (robi.ia.val[63:56]==robi.imm[7:0]) begin
		        	vtmp <= {robi.step,3'd7};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd7});
		        end
		        else
		          tDoOp({64{1'b1}});  // -1
	        end
		      else begin
		        if (robi.ia.val[7:0]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'b0};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'b0});
		        end
		        else if (robi.ia.val[15:8]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'd1};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd1});
		        end
		        else if (robi.ia.val[23:16]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'd2};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd2});
		        end
		        else if (robi.ia.val[31:24]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'd3};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd3});
		        end
		        else if (robi.ia.val[39:32]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'd4};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd4});
		        end
		        else if (robi.ia.val[47:40]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'd5};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd5});
		        end
		        else if (robi.ia.val[55:40]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'd6};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd6});
		        end
		        else if (robi.ia.val[63:56]==robi.ib.val[7:0]) begin
		        	vtmp <= {robi.step,3'd7};
		        	vtmp[63] <= 1'b1;
		          tDoOp({robi.step,3'd7});
		        end
		        else
		          tDoOp({64{1'b1}});  // -1
		      end
	      end
        else begin
          tDoOp(vtmp[63] ? {1'b0,vtmp[62:0]} : 64'hFFFFFFFFFFFFFFFF);  // -1
        end
	    end
	  VM:
			case(robi.ir.r2.func)
			MTM:	begin execo.res.val <= robi.ia.val; tMod(); end
			MFM:	if (robi.vmv) begin execo.res.val <= robi.vmask; tMod(); end
			VMADD:begin execo.res.val <= robi.ia.val + robi.ib.val; tMod(); end
			MAND:	begin execo.res.val <= robi.ia.val & robi.ib.val; tMod(); end
			MOR:	begin execo.res.val <= robi.ia.val | robi.ib.val; tMod(); end
			MXOR:	begin execo.res.val <= robi.ia.val ^ robi.ib.val; tMod(); end
			MFILL:	begin 
								for (n = 0; n < 64; n = n + 1)
									execo.res.val[n] <= n[5:0] <= robi.ia.val[5:0];
								tMod();
							end
			MSLL:	begin execo.res.val <= robi.ia.val << robi.ib.val[5:0]; tMod(); end
			MSRL:	begin execo.res.val <= robi.ia.val >> robi.ib.val[5:0]; tMod(); end
			MPOP: begin execo.res.val <= cntpopo; tMod(); end
			MFIRST:	begin execo.res.val <= floo; tMod(); end
			MLAST:	begin execo.res.val <= ffoo; tMod(); end
			default:	;
	  	endcase
`ifdef U10NDX
    VU10NDX:
    begin
    	if (robi.ir.sz==4'd1) begin
        if (robi.ia.val[9:0]==robi.imm[9:0])
          tDoOp( 64'd0);
        else if (robi.ia.val[19:10]==robi.imm[9:0])
          tDoOp( 64'd1);
        else if (robi.ia.val[29:20]==robi.imm[9:0])
          tDoOp( 64'd2);
        else if (robi.ia.val[39:30]==robi.imm[9:0])
          tDoOp( 64'd3);
        else if (robi.ia.val[49:40]==robi.imm[9:0])
          tDoOp( 64'd4);
        else if (robi.ia.val[59:50]==robi.imm[9:0])
          tDoOp( 64'd5);
        else
          tDoOp( {64{1'b1}});  // -1
      end
      else begin
        if (robi.ia.val[9:0]==robi.ib.val[9:0])
          tDoOp( 64'd0);
        else if (robi.ia.val[19:10]==robi.ib.val[9:0])
          tDoOp( 64'd1);
        else if (robi.ia.val[29:20]==robi.ib.val[9:0])
          tDoOp( 64'd2);
        else if (robi.ia.val[39:30]==robi.ib.val[9:0])
          tDoOp( 64'd3)
        else if (robi.ia.val[49:40]==robi.ib.val[9:0])
          tDoOp( 64'd4)
        else if (robi.ia.val[59:50]==robi.ib.val[9:0])
          tDoOp( 64'd5);
        else
          tDoOp( {64{1'b1}});  // -1
      end
    end
`endif
    VU21NDX:
		begin
    	if (robi.ir.r2.func!=4'd0) begin
        if (robi.ia.val[20:0]==robi.imm[20:0])
          tDoOp( 64'd0);
        else if (robi.ia.val[41:21]==robi.imm[20:0])
          tDoOp( 64'd1);
        else if (robi.ia.val[62:42]==robi.imm[20:0])
          tDoOp( 64'd2);
        else
          tDoOp( {64{1'b1}});  // -1
      end
      else begin
        if (robi.ia.val[20:0]==robi.ib.val[20:0])
          tDoOp( 64'd0);
        else if (robi.ia.val[41:21]==robi.ib.val[20:0])
          tDoOp( 64'd1);
        else if (robi.ia.val[62:42]==robi.ib.val[20:0])
          tDoOp( 64'd2);
        else
          tDoOp( {64{1'b1}});  // -1
      end
    end
    PERM:
		begin
    	if (robi.ir.r2.func!=4'd0) begin
    		tDoOp({
    		robi.ia.val >> {robi.imm[23:21],3'b0},
    		robi.ia.val >> {robi.imm[20:18],3'b0},
    		robi.ia.val >> {robi.imm[17:15],3'b0},
    		robi.ia.val >> {robi.imm[14:12],3'b0},
    		robi.ia.val >> {robi.imm[11:9],3'b0},
    		robi.ia.val >> {robi.imm[8:6],3'b0},
    		robi.ia.val >> {robi.imm[5:3],3'b0},
    		robi.ia.val >> {robi.imm[2:0],3'b0}});
			end
			else begin
    		tDoOp({
    		robi.ia.val >> {robi.ib.val[23:21],3'b0},
    		robi.ia.val >> {robi.ib.val[20:18],3'b0},
    		robi.ia.val >> {robi.ib.val[17:15],3'b0},
    		robi.ia.val >> {robi.ib.val[14:12],3'b0},
    		robi.ia.val >> {robi.ib.val[11:9],3'b0},
    		robi.ia.val >> {robi.ib.val[8:6],3'b0},
    		robi.ia.val >> {robi.ib.val[5:3],3'b0},
    		robi.ia.val >> {robi.ib.val[2:0],3'b0}});
			end
		end    	
		VCHKI:
			begin
				case(robi.ir.r2.Rt[2:0])
				3'd0:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd1:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd2:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd3:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.imm)) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd4:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd5:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd6:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				3'd7:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm))) begin
						execo.cause <= FLT_CHK;
						tMod();
					end
				endcase
			end
`ifdef SUPPORT_MYST
		VMYSTI:	begin execo.res.val <= {robi.id.val[35:20],robi.ir[19:8],robi.id.val[7:0]}; execo.myst <= TRUE; tMod(); end
`endif
		VSYS:
			case(robi.ir.r2.func)
`ifdef SUPPORT_EXEC
			EXEC:
				begin
					execo.exec <= TRUE;
					execo.res.val <= robi.ia.val;
					tMod();
				end
`endif				
			default:	;			
			endcase
`endif
		default:	;
		endcase
		end // if (!robi.out)
		end // if (robi.dec)
	end // if (robi.v && !robi.cmt && rob_exec != 6'd63)
	else begin
		/*
		if (robi.v==INV)
			tMod();
		else
		*/
		if (robi.dec && robi.out && rob_exec != 6'd63) begin
			tMod();
		end
	end
end

task tBal;
input opt;
begin
	//execo.jump <= TRUE;
	//execo.jump_tgt <= robi.ip + robi.imm;
	execo.res.val <= opt ? fnIncIP5(robi.ip) : fnIncIP(robi.ip);
	a2d_rst <= TRUE;
	d2x_rst <= TRUE;
	ex_redirect.redirect_ip <= robi.ip + robi.imm;
	ex_redirect.current_ip <= robi.ip;
	ex_redirect.xrid <= rob_exec;
	ex_redirect.step <= 6'd0;
	ex_redirect.wr <= TRUE;
	execo.update <= TRUE;
	execo.cmt <= FALSE;
	execo.cmt2 <= FALSE;
end
endtask

task tBranch;
begin
	execo.takb <= ex_takb;
	execo.res.val <= fnIncIP(robi.ip);
	tMod();
	if (brMispredict) begin
		a2d_rst <= TRUE;
		d2x_rst <= TRUE;
		ex_redirect.redirect_ip <= ex_takb ? robi.ic + robi.imm : fnIncIP(robi.ip);
		//ex_redirect.redirect_ip <= ex_takb ? robi.ic + robi.imm : fnIncIP(robi.ip);
		ex_redirect.current_ip <= robi.ip;
		ex_redirect.step <= 6'd0;
		ex_redirect.xrid <= rob_exec;
		ex_redirect.wr <= TRUE;
		restore_rfsrc <= TRUE;
		execo.cmt <= FALSE;
		execo.cmt2 <= FALSE;
	end
	else if (brAddrMispredict) begin
		a2d_rst <= TRUE;
		d2x_rst <= TRUE;
		ex_redirect.redirect_ip <= ex_takb ? robi.ic + robi.imm : fnIncIP(robi.ip);
		//ex_redirect.redirect_ip <= ex_takb ? robi.ic + robi.imm : fnIncIP(robi.ip);
		ex_redirect.current_ip <= robi.ip;
		ex_redirect.step <= 6'd0;
		ex_redirect.xrid <= rob_exec;
		ex_redirect.wr <= TRUE;
		execo.cmt <= FALSE;
		execo.cmt2 <= FALSE;
		restore_rfsrc <= TRUE;
	end
end
endtask

task tJalr;
begin
	//execo.jump <= TRUE;
	//execo.jump_tgt <= robi.ia.val + robi.imm;
	execo.res <= fnIncIP(robi.ip);
	a2d_rst <= TRUE;
	d2x_rst <= TRUE;
	ex_redirect.redirect_ip <= robi.ia.val + robi.imm;
	ex_redirect.current_ip <= robi.ip;
	ex_redirect.step <= 6'd0;
	ex_redirect.xrid <= rob_exec;
	ex_redirect.wr <= TRUE;
	execo.cmt <= FALSE;
	execo.cmt2 <= FALSE;
	execo.update <= TRUE;
end
endtask


// For a LDM if Rt is zero there is nothing left to load. Do not run a bus
// cycle. The micro-code may pass the load operation for a couple of cycles
// beyond the point where it is finished.

task tLoad;
input [1:0] opt;
begin
	membufi.rid <= rob_exec;
	membufi.step <= robi.step;
	membufi.ir <= robi.ir;
	membufi.ib <= robi.ib;
	membufi.ic <= robi.ic;
	membufi.dato <= robi.ib;
	membufi.imm <= robi.imm;
	tMod();
	execo.cmt <= FALSE;
	execo.cmt2 <= FALSE;
	execo.wr_fu <= FALSE;
	if (opt==2'b10) begin
		membufi.ia <= tcbptr + {robi.Rtseg,robi.Rt[4:0],3'h0};
		membufi.wr <= TRUE;
	end
	else if (robi.ir[35:32]==LSM && opt==2'b01) begin
		membufi.ia <= robi.ia + {count,3'd0};
		count <= count + 2'd1;
		if (robi.Rt != 6'd0)
			membufi.wr <= TRUE;
		else begin
			execo.cmt <= TRUE;
			execo.cmt2 <= TRUE;
		end
	end
	else begin
		membufi.ia <= robi.ia;
		count <= 6'd0;
		membufi.wr <= TRUE;
	end
end
endtask

// For STM if Rb is zero there there is nothing more to do. Do not run a bus
// cycle.

task tStore;
input [1:0] opt;
begin
	exvec <= 4'd5;
	membufi.rid <= rob_exec;
	membufi.step <= robi.step;
	membufi.ir <= robi.ir;
	membufi.ib <= robi.ib;
	membufi.ic <= robi.ic;
	membufi.dato <= robi.ib;
	membufi.imm <= robi.imm;
	tMod();
	execo.cmt <= FALSE;
	execo.cmt2 <= FALSE;
	execo.wr_fu <= FALSE;
	if (opt==2'b10) begin
		membufi.ia <= tcbptr + {robi.Rbseg,robi.Rb[4:0],3'h0};
		membufi.wr <= TRUE;
	end
	else if (robi.ir[35:32]==LSM && opt==2'b01) begin
		membufi.ia <= robi.ia + {count,3'd0};
		count <= count + 2'd1;
		if (robi.Rb != 7'd0)
			membufi.wr <= TRUE;
		else begin
			execo.cmt <= TRUE;
			execo.cmt2 <= TRUE;
		end
	end
	else begin
		membufi.ia <= robi.ia;
		count <= 6'd0;
		membufi.wr <= TRUE;
	end
end
endtask

task tDoOp;
input Value res;
begin
	execo.update <= TRUE;
	execo.out <= TRUE;
	if (robi.vmask.val[robi.step])
		execo.res.val <= res.val;
	else if (robi.irmod.im.z)
		execo.res.val <= {VALUE_SIZE{1'd0}};
	execo.cmt <= TRUE;
	execo.cmt2 <= TRUE;
	if (robi.step >= vl) begin
		vtmp <= 64'h0;
		execo.vcmt <= TRUE;
	end
end
endtask

task tMod;
begin
	execo.cmt <= TRUE;
	execo.cmt2 <= TRUE;
	execo.update <= TRUE;
	execo.vcmt <= robi.step >= vl;
	if (robi.step >= vl) begin
		vtmp <= 64'h0;
		execo.vcmt <= TRUE;
	end
end
endtask

endmodule
