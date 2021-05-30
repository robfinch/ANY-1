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

module any1_execute(rst,clk,robi,robo,mulreci,divreci,membufi,rob_exec,Stream_inc,ex_redirect,
	f2a_rst,a2d_rst,d2x_rst,ex_takb,csrro,irq_i,cause_i,brAddrMispredict,ifStream,rst_exStream,exStream,
	restore_rfsrc,set_wfi,vregfilesrc,vl);
input rst;
input clk;
input sReorderEntry robi;
output sReorderEntry robo;
output sALUrec mulreci;
output sALUrec divreci;
output sMemoryIO membufi;
output reg [5:0] rob_exec;
input Stream_inc;
output sRedirect ex_redirect;
output reg f2a_rst;
output reg a2d_rst;
output reg d2x_rst;
input ex_takb;
input [63:0] csrro;
input irq_i;
input [7:0] cause_i;
input brAddrMispredict;
input Rid vregfilesrc [0:63];

input [5:0] ifStream;
input rst_exStream;
output reg [5:0] exStream;
output reg restore_rfsrc;
output reg set_wfi= 1'b0;
input [7:0] vl;

integer n;

wire [127:0] sll_out = {robi.ib.val,robi.ia.val} << robi.ic.val[5:0];
wire brMispredict = ex_takb != robi.predict_taken;//exbufi.predict_taken;
reg [63:0] prev_res;
reg [63:0] vscan_sum;
reg [5:0] vec_y;

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

	// Execute
	// Lots to do here.
	// Simple single cycle instructions are executed directly and the reorder buffer updated.
	// Multi-cycle instructions are placed in instruction queues.
always @(posedge clk)
if (rst) begin
	rob_exec <= 6'd0;
	robo <= 1'd0;
	exStream <= 6'd0;
	f2a_rst <= TRUE;
	a2d_rst <= TRUE;
	d2x_rst <= TRUE;
	mulreci.wr <= FALSE;
	divreci.wr <= FALSE;
	membufi.wr <= FALSE;
	ex_redirect.wr <= FALSE;
	ex_redirect.redirect_ip <= RSTIP;
	ex_redirect.current_ip <= RSTIP;
	restore_rfsrc <= FALSE;
	set_wfi <= FALSE;
end
else begin
	f2a_rst <= FALSE;
	a2d_rst <= FALSE;
	d2x_rst <= FALSE;
	mulreci.wr <= FALSE;
	divreci.wr <= FALSE;
	membufi.wr <= FALSE;
	ex_redirect.wr <= FALSE;
	restore_rfsrc <= FALSE;
	set_wfi <= FALSE;

	$display("Execute");
	if (robi.Stream == exStream + Stream_inc) begin
		if (robi.dec) begin
		$display("rid:%d ip: %h  ir: %h  a:%h%c  b:%h%c  c:%h%c  d:%h%c  i:%h", rob_exec, robi.ip, robi.ir,
			robi.ia.val,robi.iav?"v":" ",robi.ib.val,robi.ibv?"v":" ",
			robi.ic.val,robi.icv?"v":" ",robi.id.val,robi.idv?"v":" ",
			robi.imm.val);

		if (rst_exStream)
			exStream <= ifStream + 2'd1;
		else
			exStream <= exStream + robi.Stream_inc;

		// If the instruction is exceptioned, then ignore executing it.

		if (robi.ui || robi.cause != 16'h0000) begin
			robo.cmt <= TRUE;
			rob_exec <= rob_exec + 2'd1;
		end
		else
		//robi.res.tag <= robi.ir.tag;
		robo <= robi;
		robo.btag <= 4'd0;
		robo.takb <= FALSE;
		robo.vmask <= -64'd1;
		robo.jump_tgt <= 32'd0;
		robo.wr_fu <= TRUE;
		robo.update_rob <= FALSE;
		case(robi.ir.r2.opcode)
		BRK:	robo.cause <= robi.ir[21:14];
		NOP:	tMod();
		R3:
			if (robi.iav && robi.ibv && robi.icv) begin
				case(robi.ir.r2.func)
				SLLP:	begin robo.res.val <= sll_out[63:0]; tMod(); end
				PTRDIF:	
					begin
						//robi.res.tag <= TAG_INT;
						robo.res.val <= ((robi.ia.val < robi.ib.val) ? robi.ib.val - robi.ia.val : robi.ia.val - robi.ib.val) >> robi.ic.val[4:0];
						tMod();
					end
				CHK:
					case(robi.ir.r2.func)
					3'd0:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd1:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd2:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd3:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd4:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd5:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd6:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd7:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					default:
						begin
							robo.ui <= TRUE;
							tMod();
						end
					endcase
				default:	;
				endcase
			end
		R2:
			if (robi.iav && robi.ibv) begin
				case(robi.ir.r2.func)
				ADD:	begin	robo.res.val <= robi.ia.val + robi.ib.val; tMod(); end
				SUB:	begin	robo.res.val <= robi.ia.val - robi.ib.val; tMod(); end
				AND:	begin	robo.res.val <= robi.ia.val & robi.ib.val; tMod(); end
				OR:		begin	robo.res.val <= robi.ia.val | robi.ib.val; tMod(); end
				XOR:	begin	robo.res.val <= robi.ia.val ^ robi.ib.val; tMod(); end
				SLL:	begin robo.res.val <= robi.ia.val << robi.ib.val[5:0]; tMod(); end
				SLLI:	begin robo.res.val <= robi.ia.val << robi.ir.r2.Rb; tMod(); end
				DIF:
					begin
						robo.res <= $signed(robi.ia.val) < $signed(robi.ib.val) ?
						robo.ib.val - robi.ia.val : robi.ia.val - robi.ib.val;
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
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.wr_fu <= FALSE;
					end
				DIV,DIVU,DIVSU:
					begin
						divreci.rid <= rob_exec;
						divreci.ir <= robi.ir;
						divreci.a <= robi.ia;
						divreci.b <= robi.ib;
						divreci.wr <= TRUE;
						tMod();
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.wr_fu <= FALSE;
					end
				MULF:	begin robo.res.val <= robi.ia.val[23:0] * robi.ib.val[15:0]; tMod(); end
				CMP:	begin robo.res.val <= $signed(robi.ia.val) < $signed(robi.ib.val) ? -64'd1 : $signed(robi.ia.val) == $signed(robi.ib.val) ? 64'd0 : 64'd1; tMod(); end
				SEQ:	begin robo.res.val <= robi.ia.val == robi.ib.val; tMod(); end
				SNE:	begin robo.res.val <= robi.ia.val != robi.ib.val; tMod(); end
				SLT:	begin robo.res.val <= $signed(robi.ia.val) < $signed(robi.ib.val); tMod(); end
				SGE:	begin robo.res.val <= $signed(robi.ia.val) >= $signed(robi.ib.val); tMod(); end
				SLTU:	begin robo.res.val <= robi.ia.val < robi.ib.val; tMod(); end
				SGEU:	begin robo.res.val <= robi.ia.val >= robi.ib.val; tMod(); end
				default:	;
				endcase
			end
		R1:
			if (robi.iav) begin
				case(robi.ir.r2.func)
				ABS:	begin robo.res.val <= robi.ia[63] ? -robi.ia : robi.ia; tMod(); end
				NOT:	begin robo.res.val <= robi.ia==64'd0 ? 64'd1 : 64'd0; tMod(); end
				V2BITS:	begin
									if (robi.step==0) begin
										if (robi.vmask[0]) begin
											robo.res.val <= {63'd0,robi.ia.val[0]};
											prev_res <= {63'd0,robi.ia.val[0]};
										end
										else if (robi.irmod.im.z) begin
											robo.res.val <= 64'd0;
											prev_res <= 64'd0;
										end
									end
									else begin
										if (robi.vmask[robi.step]) begin
											robo.res.val <= prev_res | (robi.ia.val[0] << robi.step);
											prev_res <= prev_res | (robi.ia.val[0] << robi.step);
										end
									end
									tMod(); 
								end
				default:	;
				endcase
			end
		ADDI:	if (robi.iav) begin robo.res.val <= robi.ia.val + robi.imm.val; tMod(); end
		SUBFI:if (robi.iav) begin robo.res.val <= robi.imm.val - robi.ia.val; tMod(); end
		ANDI:	if (robi.iav) begin robo.res.val <= robi.ia.val & robi.imm.val; tMod(); end
		ORI:	if (robi.iav) begin robo.res.val <= robi.ia.val | robi.imm.val; tMod(); end
		XORI:	if (robi.iav) begin robo.res.val <= robi.ia.val ^ robi.imm.val; tMod(); end
		MULI,MULUI,MULSUI:
				begin
					if (robi.iav) begin
						mulreci.rid <= rob_exec;
						mulreci.a <= robi.ia;
						mulreci.imm <= robi.imm;
						mulreci.wr <= TRUE;
						tMod(); 
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.wr_fu <= FALSE;
					end
				end
		DIVI,DIVUI,DIVSUI:
				begin
					if (robi.iav) begin
						divreci.rid <= rob_exec;
						divreci.a <= robi.ia;
						divreci.imm <= robi.imm;
						divreci.wr <= TRUE;
						tMod(); 
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.wr_fu <= FALSE;
					end
				end
		MULFI:if (robi.iav) begin robo.res.val <= robi.ia.val[23:0] + robi.imm.val[15:0]; tMod(); end
		SEQI:	if (robi.iav) begin robo.res.val <= robi.ia.val == robi.imm.val; tMod(); end
		SNEI:	if (robi.iav) begin robo.res.val <= robi.ia != robi.imm; tMod(); end
		SLTI:	if (robi.iav) begin robo.res.val <= $signed(robi.ia.val) < $signed(robi.imm.val); tMod(); end
		SGTI:	if (robi.iav) begin robo.res.val <= $signed(robi.ia.val) > $signed(robi.imm.val); tMod(); end
		SLTUI:	if (robi.iav) begin robo.res.val <= robi.ia.val < robi.imm.val; tMod(); end
		SGTUI:	if (robi.iav) begin robo.res.val <= robi.ia.val > robi.imm.val; tMod(); end
		BTFLD:	if (robi.iav) begin robo.res.val <= bf_out.val; tMod(); end
    BYTNDX:
	    if (robi.iav) begin
	    	if (robi.ir.r2.func!=4'd0) begin
	        if (robi.ia.val[7:0]==robi.imm.val[7:0])
	          robo.res.val <= 64'd0;
	        else if (robi.ia.val[15:8]==robi.imm.val[7:0])
	          robo.res.val <= 64'd1;
	        else if (robi.ia.val[23:16]==robi.imm.val[7:0])
	          robo.res.val <= 64'd2;
	        else if (robi.ia.val[31:24]==robi.imm.val[7:0])
	          robo.res.val <= 64'd3;
	        else if (robi.ia.val[39:32]==robi.imm.val[7:0])
	          robo.res.val <= 64'd4;
	        else if (robi.ia.val[47:40]==robi.imm.val[7:0])
	          robo.res.val <= 64'd5;
	        else if (robi.ia.val[55:40]==robi.imm.val[7:0])
	          robo.res.val <= 64'd6;
	        else if (robi.ia.val[63:56]==robi.imm.val[7:0])
	          robo.res.val <= 64'd7;
	        else
	          robo.res.val <= {64{1'b1}};  // -1
	      end
	      else begin
	        if (robi.ia.val[7:0]==robi.ib.val[7:0])
	          robo.res.val <= 64'd0;
	        else if (robi.ia.val[15:8]==robi.ib.val[7:0])
	          robo.res.val <= 64'd1;
	        else if (robi.ia.val[23:16]==robi.ib.val[7:0])
	          robo.res.val <= 64'd2;
	        else if (robi.ia.val[31:24]==robi.ib.val[7:0])
	          robo.res.val <= 64'd3;
	        else if (robi.ia.val[39:32]==robi.ib.val[7:0])
	          robo.res.val <= 64'd4;
	        else if (robi.ia.val[47:40]==robi.ib.val[7:0])
	          robo.res.val <= 64'd5;
	        else if (robi.ia.val[55:40]==robi.ib.val[7:0])
	          robo.res.val <= 64'd6;
	        else if (robi.ia.val[63:56]==robi.ib.val[7:0])
	          robo.res.val <= 64'd7;
	        else
	          robo.res.val <= {64{1'b1}};  // -1
	      end
	      tMod();
	    end
`ifdef U10NDX
    U10NDX:
    if (robi.iav) begin
    	if (robi.ir.sz==4'd1) begin
        if (robi.ia.val[9:0]==robi.imm.val[9:0])
          robo.res.val <= 64'd0;
        else if (robi.ia.val[19:10]==robi.imm.val[9:0])
          robo.res.val <= 64'd1;
        else if (robi.ia.val[29:20]==robi.imm.val[9:0])
          robo.res.val <= 64'd2;
        else if (robi.ia.val[39:30]==robi.imm.val[9:0])
          robo.res.val <= 64'd3;
        else if (robi.ia.val[49:40]==robi.imm.val[9:0])
          robo.res.val <= 64'd4;
        else if (robi.ia.val[59:50]==robi.imm.val[9:0])
          robo.res.val <= 64'd5;
        else
          robo.res.val <= {64{1'b1}};  // -1
      end
      else begin
        if (robi.ia.val[9:0]==robi.ib.val[9:0])
          robo.res.val <= 64'd0;
        else if (robi.ia.val[19:10]==robi.ib.val[9:0])
          robo.res.val <= 64'd1;
        else if (robi.ia.val[29:20]==robi.ib.val[9:0])
          robo.res.val <= 64'd2;
        else if (robi.ia.val[39:30]==robi.ib.val[9:0])
          robo.res.val <= 64'd3;
        else if (robi.ia.val[49:40]==robi.ib.val[9:0])
          robo.res.val <= 64'd4;
        else if (robi.ia.val[59:50]==robi.ib.val[9:0])
          robo.res.val <= 64'd5;
        else
          robo.res.val <= {64{1'b1}};  // -1
      end
      tMod();
    end
`endif
    U21NDX:
		if (robi.iav) begin
    	if (robi.ir.r2.func!=4'd0) begin
        if (robi.ia.val[20:0]==robi.imm.val[20:0])
          robo.res.val <= 64'd0;
        else if (robi.ia.val[41:21]==robi.imm.val[20:0])
          robo.res.val <= 64'd1;
        else if (robi.ia.val[62:42]==robi.imm.val[20:0])
          robo.res.val <= 64'd2;
        else
          robo.res.val <= {64{1'b1}};  // -1
      end
      else begin
        if (robi.ia.val[20:0]==robi.ib.val[20:0])
          robo.res.val <= 64'd0;
        else if (robi.ia.val[41:21]==robi.ib.val[20:0])
          robo.res.val <= 64'd1;
        else if (robi.ia.val[62:42]==robi.ib.val[20:0])
          robo.res.val <= 64'd2;
        else
          robo.res.val <= {64{1'b1}};  // -1
      end
      tMod();
    end
    PERM:
		if (robi.iav) begin
    	if (robi.ir.r2.func!=4'd0) begin
    		robo.res.val[7:0] <= robi.ia.val >> {robi.imm.val[2:0],3'b0};
    		robo.res.val[15:8] <= robi.ia.val >> {robi.imm.val[5:3],3'b0};
    		robo.res.val[23:16] <= robi.ia.val >> {robi.imm.val[8:6],3'b0};
    		robo.res.val[31:24] <= robi.ia.val >> {robi.imm.val[11:9],3'b0};
    		robo.res.val[39:32] <= robi.ia.val >> {robi.imm.val[14:12],3'b0};
    		robo.res.val[47:40] <= robi.ia.val >> {robi.imm.val[17:15],3'b0};
    		robo.res.val[55:48] <= robi.ia.val >> {robi.imm.val[20:18],3'b0};
    		robo.res.val[63:56] <= robi.ia.val >> {robi.imm.val[23:21],3'b0};
			end
			else begin
    		robo.res.val[7:0] <= robi.ia.val >> {robi.ib.val[2:0],3'b0};
    		robo.res.val[15:8] <= robi.ia.val >> {robi.ib.val[5:3],3'b0};
    		robo.res.val[23:16] <= robi.ia.val >> {robi.ib.val[8:6],3'b0};
    		robo.res.val[31:24] <= robi.ia.val >> {robi.ib.val[11:9],3'b0};
    		robo.res.val[39:32] <= robi.ia.val >> {robi.ib.val[14:12],3'b0};
    		robo.res.val[47:40] <= robi.ia.val >> {robi.ib.val[17:15],3'b0};
    		robo.res.val[55:48] <= robi.ia.val >> {robi.ib.val[20:18],3'b0};
    		robo.res.val[63:56] <= robi.ia.val >> {robi.ib.val[23:21],3'b0};
			end
			tMod();
		end    	
		CHKI:
			if (robi.iav && robi.icv) begin
				case(robi.ir.r2.Rt[2:0])
				3'd0:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd1:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd2:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd3:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd4:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd5:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd6:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd7:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				endcase
			end
		BEQ,BNE,BLT,BGE,BLTU,BGEU,BBS:
			if (robi.iav && robi.ibv && robi.icv) begin
				robo.branch <= TRUE;
				robo.takb <= ex_takb;
				robo.res.val <= robi.ip + 4'd4;
				tMod();
				if (brMispredict) begin
					robo.Stream_inc <= 1'b1;
					f2a_rst <= TRUE;
					a2d_rst <= TRUE;
					d2x_rst <= TRUE;
					exStream <= exStream + 2'd1;
					ex_redirect.redirect_ip <= ex_takb ? robi.ic + robi.imm.val : robi.ip + 4'd4;
					ex_redirect.current_ip <= robi.ip;
					ex_redirect.wr <= TRUE;
					restore_rfsrc <= TRUE;
				end
				else if (brAddrMispredict) begin
					robo.Stream_inc <= 1'b1;
					f2a_rst <= TRUE;
					a2d_rst <= TRUE;
					d2x_rst <= TRUE;
					exStream <= exStream + 2'd1;
					ex_redirect.redirect_ip <= ex_takb ? robi.ic + robi.imm.val : robi.ip + 4'd4;
					ex_redirect.current_ip <= robi.ip;
					ex_redirect.wr <= TRUE;
					restore_rfsrc <= TRUE;
				end
			end
		JALR:
			if (robi.iav) begin
				robo.jump <= TRUE;
				robo.jump_tgt <= robi.ia.val + robi.imm.val;
				robo.jump_tgt[1:0] <= 3'd0;
				robo.res <= robi.ip + {robi.ir[13:10],2'b0};
				robo.Stream_inc <= 1'b1;
				f2a_rst <= TRUE;
				a2d_rst <= TRUE;
				d2x_rst <= TRUE;
				exStream <= exStream + 2'd1;
				ex_redirect.redirect_ip <= robi.ia.val + robi.imm.val;
				ex_redirect.current_ip <= robi.ip;
				ex_redirect.wr <= TRUE;
				tMod();
			end
		LEA,LDx,LDxX,
		STx,STxX:
			//if (memfifo_wr==FALSE) begin	// prevent back-to-back screwup
			// This does not wait for registers to be valid.
			begin
				membufi.rid <= rob_exec;
				membufi.ir <= robi.ir;
				membufi.ia <= robi.ia;
				membufi.ib <= robi.ib;
				membufi.ic <= robi.ic;
				membufi.dato <= robi.ib;
				membufi.imm <= robi.imm;
				membufi.wr <= TRUE;
				tMod();
				robo.cmt <= FALSE;
				robo.cmt2 <= FALSE;
				robo.wr_fu <= FALSE;
			end
		CSR:
			if (robi.iav) begin
				robo.ia <= robi.ia;
				case(robi.imm[18:16])
				CSRR:	robo.res <= csrro;
				CSRW,CSRS,CSRC:	;
				CSRRW:	robo.res <= csrro;
				default:	;
				endcase
		    tMod();
			end
		SYS:
			case(robi.ir.r2.func)
			PFI:
				begin
	      	if (irq_i != 1'b0)
			    	robo.cause <= 16'h8000|cause_i;
			    tMod();
		  	end
		  WFI:	begin set_wfi <= TRUE; tMod(); end
			TLBRW:
				begin
					membufi.rid <= rob_exec;
					membufi.ir <= robi.ir;
					membufi.ia <= robi.ia;
					membufi.ib <= robi.ib;
					membufi.imm <= robi.imm;
					membufi.wr <= TRUE;
					tMod();
					robo.cmt <= FALSE;
					robo.cmt2 <= FALSE;
					robo.wr_fu <= FALSE;
				end
			default:	;
			endcase
		EXI0,EXI1,EXI2:	tMod();
		IMOD:
			if (robi.icv & robi.idv)
				tMod();
		BRMOD:
			if (robi.icv)
				tMod();
		8'hFF:
			rob_exec <= rob_exec;
`ifdef SUPPORT_VECTOR
		VR1:
			if (robi.iav) begin
				case(robi.ir.r2.func)
				ABS:	begin
								robo.update_rob <= TRUE;
								rob_exec <= rob_exec + 2'd1;
								if (robi.vmask.val[robi.step]) begin
									robo.res.val <= robi.ia[63] ? -robi.ia : robi.ia;
									robo.cmt <= TRUE;
									robo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									robo.res.val <= 64'd0;
						  end
				NOT:	begin
								robo.update_rob <= TRUE;
								rob_exec <= rob_exec + 2'd1;
								if (robi.vmask.val[robi.step]) begin
									robo.res.val <= robi.ia==64'd0 ? 64'd1 : 64'd0;
									robo.cmt <= TRUE;
									robo.cmt2 <= TRUE;
								end
								else if (robi.irmod.im.z)
									robo.res.val <= 64'd0;
							end
				V2BITS:	begin
									if (robi.step==0) begin
										if (robi.vmask[0]) begin
											robo.res.val <= {63'd0,robi.ia.val[0]};
											prev_res <= {63'd0,robi.ia.val[0]};
										end
										else if (robi.irmod.im.z) begin
											robo.res.val <= 64'd0;
											prev_res <= 64'd0;
										end
									end
									else begin
										if (robi.vmask[robi.step]) begin
											robo.res.val <= prev_res | (robi.ia.val[0] << robi.step);
											prev_res <= prev_res | (robi.ia.val[0] << robi.step);
										end
									end
									tMod();
									if (robi.step >= vl)
										robo.vcmt <= TRUE;
								end
				VEX:
					if (robi.ibv && robi.step_v) begin
						robo.res.val <= robi.ib;
						tMod();
					end
					else begin
						robo.step_v <= TRUE;
						robo.step <= robi.ia[5:0];
					end
				default:	;
				endcase
			end
		VR2:
			if (robi.iav && robi.ibv) begin
				case(robi.ir.r2.func)
				ADD:	tDoOp(robi.ia.val + robi.ib.val);
				SUB:	tDoOp(robi.ia.val - robi.ib.val);
				AND:	tDoOp(robi.ia.val & robi.ib.val);
				OR:		tDoOp(robi.ia.val | robi.ib.val);
				XOR		tDoOp(robi.ia.val ^ robi.ib.val);
				SLL:	tDoOp(robi.ia.val << robi.ib.val[5:0]);
				SLLI:	tDoOp(robi.ia.val << robi.ir.r2.Rb);
				DIF:
					begin
						tDoOp($signed(robi.ia.val) < $signed(robi.ib.val) ?
							robo.ib.val - robi.ia.val : robi.ia.val - robi.ib.val);
					end
				MUL,MULU,MULSU,MULH,MULUH,MULSUH:
					begin
						mulreci.rid <= rob_exec;
						mulreci.ir <= robi.ir;
						mulreci.a <= robi.ia;
						mulreci.b <= robi.ib;
						mulreci.wr <= TRUE;
						tMod();
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.vcmt <= FALSE;
						robo.wr_fu <= FALSE;
					end
				DIV,DIVU,DIVSU:
					begin
						divreci.rid <= rob_exec;
						divreci.ir <= robi.ir;
						divreci.a <= robi.ia;
						divreci.b <= robi.ib;
						divreci.wr <= TRUE;
						tMod();
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.vcmt <= FALSE;
						robo.wr_fu <= FALSE;
					end
				MULF:	tDoOp(robi.ia.val[23:0] * robi.ib.val[15:0]);
				CMP:	tDoOp($signed(robi.ia.val) < $signed(robi.ib.val) ? -64'd1 : $signed(robi.ia.val) == $signed(robi.ib.val) ? 64'd0 : 64'd1);
				SEQ:	tDoOp(robi.ia.val == robi.ib.val);
				SNE:	tDoOp(robi.ia.val != robi.ib.val);
				SLT:	tDoOp($signed(robi.ia.val) < $signed(robi.ib.val));
				SGE:	tDoOp($signed(robi.ia.val) >= $signed(robi.ib.val));
				SLTU:	tDoOp(robi.ia.val < robi.ib.val);
				SGEU:	tDoOp(robi.ia.val >= robi.ib.val);
				default:	;
				endcase
			end
		VR3:
			if (robi.iav && robi.ibv && robi.icv) begin
				case(robi.ir.r2.func)
				SLLP:	tDoOp(robo.res.val <= sll_out[63:0]);
				PTRDIF:	tDoOp(((robi.ia.val < robi.ib.val) ? robi.ib.val - robi.ia.val : robi.ia.val - robi.ib.val) >> robi.ic.val[4:0]);
				CHK:
					case(robi.ir.r2.func)
					3'd0:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd1:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd2:
						if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd3:
						if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.ib.val)) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd4:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd5:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd6:
						if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					3'd7:
						if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.ib.val))) begin
							robo.cause <= FLT_CHK;
							tMod();
						end
					default:
						begin
							robo.ui <= TRUE;
							tMod();
						end
					endcase
				default:	;
				endcase
			end
		VADDI:	if (robi.iav) tDoOp(robi.ia.val + robi.imm.val);
		VSUBFI:	if (robi.iav) tDoOp(robi.imm.val - robi.ia.val);
		VANDI:	if (robi.iav) tDoOp(robi.ia.val & robi.imm.val);
		VORI:		if (robi.iav) tDoOp(robi.ia.val | robi.imm.val);
		VXORI:	if (robi.iav) tDoOp(robi.ia.val ^ robi.imm.val);
		VMULI,VMULUI,VMULSUI:
				begin
					if (robi.iav) begin
						mulreci.rid <= rob_exec;
						mulreci.a <= robi.ia;
						mulreci.imm <= robi.imm;
						mulreci.wr <= TRUE;
						tMod(); 
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.vcmt <= FALSE;
						robo.wr_fu <= FALSE;
					end
				end
		VDIVI,VDIVUI,VDIVSUI:
				begin
					if (robi.iav) begin
						divreci.rid <= rob_exec;
						divreci.a <= robi.ia;
						divreci.imm <= robi.imm;
						divreci.wr <= TRUE;
						tMod(); 
						robo.cmt <= FALSE;
						robo.cmt2 <= FALSE;
						robo.vcmt <= FALSE;
						robo.wr_fu <= FALSE;
					end
				end
		VMULFI:	if (robi.iav) tDoOp(robi.ia.val[23:0] + robi.imm.val[15:0]);
		VSEQI:	if (robi.iav) tDoOp(robi.ia.val == robi.imm.val);
		VSNEI:	if (robi.iav) tDoOp(robi.ia != robi.imm);
		VSLTI:	if (robi.iav) tDoOp($signed(robi.ia.val) < $signed(robi.imm.val));
		VSGTI:	if (robi.iav) tDoOp($signed(robi.ia.val) > $signed(robi.imm.val));
		VSLTUI:	if (robi.iav) tDoOp(robi.ia.val < robi.imm.val);
		VSGTUI:	if (robi.iav) tDoOp(robi.ia.val > robi.imm.val);
		VBTFLD:	if (robi.iav) tDoOp(bf_out.val);
    VBYTNDX:
	    if (robi.iav) begin
	    	if (robi.ir.r2.func!=4'd0) begin
	        if (robi.ia.val[7:0]==robi.imm.val[7:0])
	          tDoOp(64'd0);
	        else if (robi.ia.val[15:8]==robi.imm.val[7:0])
	          tDoOp(64'd1);
	        else if (robi.ia.val[23:16]==robi.imm.val[7:0])
	          tDoOp(64'd2);
	        else if (robi.ia.val[31:24]==robi.imm.val[7:0])
	          tDoOp(64'd3);
	        else if (robi.ia.val[39:32]==robi.imm.val[7:0])
	          tDoOp(64'd4);
	        else if (robi.ia.val[47:40]==robi.imm.val[7:0])
	          tDoOp(64'd5);
	        else if (robi.ia.val[55:40]==robi.imm.val[7:0])
	          tDoOp(64'd6);
	        else if (robi.ia.val[63:56]==robi.imm.val[7:0])
	          tDoOp(64'd7);
	        else
	          tDoOp({64{1'b1}});  // -1
	      end
	      else begin
	        if (robi.ia.val[7:0]==robi.ib.val[7:0])
	          tDoOp(64'd0);
	        else if (robi.ia.val[15:8]==robi.ib.val[7:0])
	          tDoOp(64'd1);
	        else if (robi.ia.val[23:16]==robi.ib.val[7:0])
	          tDoOp(64'd2);
	        else if (robi.ia.val[31:24]==robi.ib.val[7:0])
	          tDoOp(64'd3);
	        else if (robi.ia.val[39:32]==robi.ib.val[7:0])
	          tDoOp( 64'd4);
	        else if (robi.ia.val[47:40]==robi.ib.val[7:0])
	          tDoOp( 64'd5);
	        else if (robi.ia.val[55:40]==robi.ib.val[7:0])
	          tDoOp( 64'd6);
	        else if (robi.ia.val[63:56]==robi.ib.val[7:0])
	          tDoOp( 64'd7);
	        else
	          tDoOp({64{1'b1}});  // -1
	      end
	    end
`ifdef U10NDX
    VU10NDX:
    if (robi.iav) begin
    	if (robi.ir.sz==4'd1) begin
        if (robi.ia.val[9:0]==robi.imm.val[9:0])
          tDoOp( 64'd0);
        else if (robi.ia.val[19:10]==robi.imm.val[9:0])
          tDoOp( 64'd1);
        else if (robi.ia.val[29:20]==robi.imm.val[9:0])
          tDoOp( 64'd2);
        else if (robi.ia.val[39:30]==robi.imm.val[9:0])
          tDoOp( 64'd3);
        else if (robi.ia.val[49:40]==robi.imm.val[9:0])
          tDoOp( 64'd4);
        else if (robi.ia.val[59:50]==robi.imm.val[9:0])
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
		if (robi.iav) begin
    	if (robi.ir.r2.func!=4'd0) begin
        if (robi.ia.val[20:0]==robi.imm.val[20:0])
          tDoOp( 64'd0);
        else if (robi.ia.val[41:21]==robi.imm.val[20:0])
          tDoOp( 64'd1);
        else if (robi.ia.val[62:42]==robi.imm.val[20:0])
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
		if (robi.iav) begin
    	if (robi.ir.r2.func!=4'd0) begin
    		tDoOp({
    		robi.ia.val >> {robi.imm.val[23:21],3'b0},
    		robi.ia.val >> {robi.imm.val[20:18],3'b0},
    		robi.ia.val >> {robi.imm.val[17:15],3'b0},
    		robi.ia.val >> {robi.imm.val[14:12],3'b0},
    		robi.ia.val >> {robi.imm.val[11:9],3'b0},
    		robi.ia.val >> {robi.imm.val[8:6],3'b0},
    		robi.ia.val >> {robi.imm.val[5:3],3'b0},
    		robi.ia.val >> {robi.imm.val[2:0],3'b0}});
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
			if (robi.iav && robi.icv) begin
				case(robi.ir.r2.Rt[2:0])
				3'd0:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val <= robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd1:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val <= robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd2:
					if (!(robi.ic.val <= robi.ia.val && robi.ia.val < robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd3:
					if (!(robi.ic.val < robi.ia.val && robi.ia.val < robi.imm.val)) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd4:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd5:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) <= $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd6:
					if (!($signed(robi.ic.val) <= $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				3'd7:
					if (!($signed(robi.ic.val) < $signed(robi.ia.val) && $signed(robi.ia.val) < $signed(robi.imm.val))) begin
						robo.cause <= FLT_CHK;
						tMod();
					end
				endcase
			end
`endif
		default:	;
		endcase
		end
	end
	// Stream mismatch
	else begin
		if (robi.dec) begin
			tMod();
		end
	end
end

task tDoOp;
input [63:0] res;
begin
	robo.update_rob <= TRUE;
	rob_exec <= rob_exec + 2'd1;
	if (robi.vmask.val[robi.step])
		robo.res.val <= res;
	else if (robi.irmod.im.z)
		robo.res.val <= 64'd0;
	robo.cmt <= TRUE;
	robo.cmt2 <= TRUE;
	robo.vcmt = robi.step >= vl;
end
endtask

task tMod;
begin
	robo.cmt <= TRUE;
	robo.cmt2 <= TRUE;
	robo.update_rob <= TRUE;
	if (rob_exec >= ROB_ENTRIES-1)
		rob_exec <= 6'd0;
	else
		rob_exec <= rob_exec + 2'd1; 
	robo.vcmt = robi.step >= vl;
end
endtask


endmodule
