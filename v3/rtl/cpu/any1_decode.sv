// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_decode.sv
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

module any1_decode(ir, decbuf, predicted_ip, ven, lsm_mask);
input Instruction ir;
output sDecode decbuf;
input Address predicted_ip;
input [5:0] ven;
input [35:0] lsm_mask;

integer m,n;
reg [5:0] Rm;
/*
always_comb
	casez({ir[13],ir[35:20],ir[12:8]})
	22'b0????????????????????1:	Rm = 6'd30;
	22'b0???????????????????10:	Rm = 6'd29;
	22'b0??????????????????100:	Rm = 6'd28;
	22'b0?????????????????1000:	Rm = 6'd27;
	22'b0????????????????10000:	Rm = 6'd26;
	22'b0???????????????100000:	Rm = 6'd10;
	22'b0??????????????1000000:	Rm = 6'd11;
	22'b0?????????????10000000:	Rm = 6'd12;
	22'b0????????????100000000:	Rm = 6'd13;
	22'b0???????????1000000000:	Rm = 6'd14;
	22'b0??????????10000000000:	Rm = 6'd15;
	22'b0?????????100000000000:	Rm = 6'd16;
	22'b0????????1000000000000:	Rm = 6'd17;
	22'b0???????10000000000000:	Rm = 6'd18;
	22'b0??????100000000000000:	Rm = 6'd19;
	22'b0?????1000000000000000:	Rm = 6'd1;
	22'b0????10000000000000000:	Rm = 6'd2;
	22'b0???100000000000000000:	Rm = 6'd3;
	22'b0??1000000000000000000:	Rm = 6'd4;
	22'b0?10000000000000000000:	Rm = 6'd24;
	22'b0100000000000000000000:	Rm = 6'd25;
	22'b1????????????????????1:	Rm = 6'd3;
	22'b1???????????????????10:	Rm = 6'd4;
	22'b1??????????????????100:	Rm = 6'd5;
	22'b1?????????????????1000:	Rm = 6'd6;
	22'b1????????????????10000:	Rm = 6'd7;
	22'b1???????????????100000:	Rm = 6'd8;
	22'b1??????????????1000000:	Rm = 6'd9;
	22'b1?????????????10000000:	Rm = 6'd20;
	22'b1????????????100000000:	Rm = 6'd21;
	22'b1???????????1000000000:	Rm = 6'd22;
	22'b1??????????10000000000:	Rm = 6'd23;
	22'b1?????????100000000000:	Rm = 6'd24;
	22'b1????????1000000000000:	Rm = 6'd25;
	22'b1???????10000000000000:	Rm = 6'd26;
	22'b1??????100000000000000:	Rm = 6'd27;
	22'b1?????1000000000000000:	Rm = 6'd1;
	22'b1????10000000000000000:	Rm = 6'd2;
	22'b1???100000000000000000:	Rm = 6'd3;
	22'b1??1000000000000000000:	Rm = 6'd28;
	22'b1?10000000000000000000:	Rm = 6'd0;
	22'b1100000000000000000000:	Rm = 6'd0;
	default:	Rm = 6'd0;
	endcase
*/
// Select callee or caller save registers
function [5:0] fnPickRn;
input [11:0] sel;
begin
	casez(sel)
	12'b??????????10:	fnPickRn = 6'd29;
	12'b?????????100:	fnPickRn = 6'd28;
	12'b????????1000:	fnPickRn = 6'd10;
	12'b???????10000:	fnPickRn = 6'd11;
	12'b??????100000:	fnPickRn = 6'd12;
	12'b?????1000000:	fnPickRn = 6'd13;
	12'b????10000000:	fnPickRn = 6'd14;
	12'b???100000000:	fnPickRn = 6'd1;
	12'b??1000000000:	fnPickRn = 6'd2;
	12'b?10000000000:	fnPickRn = 6'd3;
	12'b100000000000:	fnPickRn = 6'd24;
	12'b??????????11:	fnPickRn = 6'd1;
	12'b?????????101:	fnPickRn = 6'd2;
	12'b????????1001:	fnPickRn = 6'd3;
	12'b???????10001:	fnPickRn = 6'd4;
	12'b??????100001:	fnPickRn = 6'd5;
	12'b?????1000001:	fnPickRn = 6'd6;
	12'b????10000001:	fnPickRn = 6'd20;
	12'b???100000001:	fnPickRn = 6'd21;
	12'b??1000000001:	fnPickRn = 6'd22;
	12'b?10000000001:	fnPickRn = 6'd23;
	12'b100000000001:	fnPickRn = 6'd28;
	default:	fnPickRn = 6'd0;
	endcase
end
endfunction

// Select a choice set of registers
function [5:0] fnRn3;
input [2:0] Rn;
begin
	case(Rn)
	3'd0:	fnRn3 <= 6'd1;		// Return address
	3'd1:	fnRn3 <= 6'd4;		// temp
	3'd2:	fnRn3 <= 6'd5;		// temp
	3'd3:	fnRn3 <= 6'd10;		// saved
	3'd4:	fnRn3 <= 6'd11;		// saved
	3'd5:	fnRn3 <= 6'd20;		// arg
	3'd6:	fnRn3 <= 6'd21;		// arg
	3'd7:	fnRn3 <= 6'd22;
	endcase
end
endfunction

reg done;
always @*
begin
	decbuf.Rm = 6'd0;
	m = 1;
	done = FALSE;
	for (n = 0; n < 36; n = n + 1) begin
		if (lsm_mask[n] && !done && (n > 7 || n < 2)) begin
			decbuf.Rm = m;
			done = TRUE;
		end
		if (n > 7 || n < 2)
			m = m + 1;
	end
end


always_comb // @*//(a2d_out, predicted_ip, ven)
	begin
//		decbuf.rid <= dc_rid;
//		decbuf.v <= a2d_out.v;
		decbuf.ui <= TRUE;
		decbuf.ir <= ir;
//		decbuf.ip <= a2d_out.ip;
		decbuf.pip <= predicted_ip;
//		decbuf.predict_taken <= a2d_out.predict_taken;
		decbuf.rfwr <= FALSE;
		decbuf.vrfwr <= FALSE;
		decbuf.vmrfwr <= FALSE;
		decbuf.Ra <= {ir.r2.Ta,ir.r2.Ra};
		decbuf.Rb <= {ir.r2.Tb,ir.r2.Rb};
		decbuf.Vm <= 3'd0;
		decbuf.z <= 1'b0;
		decbuf.Rc <= 7'd0;
		decbuf.Rt <= 6'd0;
		decbuf.Ravec <= ir.r2.Ta==1'b1;
		decbuf.Rbvec <= ir.r2.Tb==2'b01;
		decbuf.Rcvec <= FALSE;
		decbuf.Rtvec <= ir.r2.Tt==1'b1;
		decbuf.Rbseg <= FALSE;
		decbuf.Rtseg <= FALSE;
		decbuf.Ramask <= FALSE;
		decbuf.Rbmask <= FALSE;
		decbuf.RaStep <= ven;
		decbuf.RbStep <= ven;
		decbuf.step <= ven;
		decbuf.is_signed <= TRUE;
		decbuf.is_vec <= ir.r2.opcode[7];
		decbuf.branch <= ir.r2.opcode[7:3]=={4'h4,1'b1};
		decbuf.call <= FALSE;
		decbuf.exec <= FALSE;
		decbuf.lsm <= FALSE;
		decbuf.vex <= FALSE;
		decbuf.veins <= FALSE;
		decbuf.vsrlv <= FALSE;
		decbuf.is_mod <= ir.r2.opcode[7:4]==4'h5;
		decbuf.needRa <= TRUE;
		decbuf.needRb <= FALSE;
		decbuf.needRc <= FALSE;
		decbuf.imm.val <= 64'd0;
		decbuf.mem_op <= ir.r2.opcode[6:4]==3'd6;
		decbuf.mc <= FALSE;
//		dcRedirectIp <= a2d_out.ip + {{25{ir[63]}},ir[63:28],3'h0};
		casez(ir.r2.opcode)
		8'h7?:	tDecode20();
		BRK:	decbuf.ui <= FALSE;
		NOP:	decbuf.ui <= FALSE;
		R1:
			case(ir.r2.func)
			ABS:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			NABS:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			NOT:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			CTLZ:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			CTPOP:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
`ifdef SUPPORT_GRAPHICS			
			TRANSFORM:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			CLIP:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
`endif
			default:	;
			endcase
		R2:
			begin
				decbuf.needRb <= TRUE;
				case(ir.r2.func)
				ADD,SUB:	begin decbuf.Rt <= {ir.r2.Tt,ir.r2.Rt}; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				AND,OR,XOR,NAND,NOR,XNOR:	begin decbuf.Rt <= {ir.r2.Tt,ir.r2.Rt}; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
`ifdef SUPPORT_MYST		
				MYST:	begin decbuf.Rt <= {ir.r2.Tt,ir.r2.Rt}; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
`endif				
				DIF:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				MULF:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
				MUL,MULU,MULSU,MULH,MULUH,MULSUH:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				DIV,DIVU,DIVSU:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				BMMOR,BMMXOR,BMMTOR,BMMTXOR:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				SLL,SRL,SRA,ROL,ROR:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				SLLI,SRLI,SRAI,ROLI,RORI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm <= {57'd0,ir.r2.Tb,ir.r2.Rb}; end
				SEQ,SNE,SLT,SGE,CMP:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				SLTU,SGEU:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
				default:	;
				endcase
			end
		R3:
			begin
				decbuf.needRb <= TRUE;
				decbuf.needRc <= TRUE;
				case(ir.r2.func)
				PTRDIF:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
				SLLP:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				CHK:
					begin
						decbuf.Rc <= ir[13:8];
						decbuf.ui <= FALSE;
						decbuf.needRc <= TRUE;
					end
				MUX:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				CMOVNZ:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				default:	;
				endcase
			end
`ifdef SUPPORT_FLOAT
		F1:
			case(ir.r2.func)
			FABS:		begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FNABS:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FNEG:		begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FSQRT:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
			I2F:		begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
			F2I:		begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
			FRM:		begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		F2:
			begin
				decbuf.needRb <= TRUE;
				case(ir.r2.func)
				CPYSGN,SGNINV:		begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				FADD,FSUB,FMUL,FDIV:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				FMIN,FMAX:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				FCMP,FCMPB:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				FSEQ,FSNE,FSLT,FSLE:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				//FSETM:	begin decbuf.Rt <= {3'd0,ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; end
				default:	;
				endcase
			end
		F3:
			begin
				decbuf.needRb <= TRUE;
				case(ir.r2.func)
				MADD,MSUB,NMADD,NMSUB:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				default:	;
				endcase
			end
`endif			
		ADDI,SUBFI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.ui <= FALSE; end
		ANDI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd1}},ir[35:20]}; decbuf.ui <= FALSE; end
		MULFI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.is_signed <= FALSE; end
		MULI,DIVI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.mc <= TRUE; end
		MULUI,MULSUI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.mc <= TRUE; decbuf.is_signed <= FALSE; end
		DIVUI,DIVSUI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.mc <= TRUE; decbuf.is_signed <= FALSE; end
		ORI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
		XORI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
`ifdef SUPPORT_MYST		
		MYSTI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
`endif		
		BTFLD:		begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		SEQI,SNEI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.ui <= FALSE; end
		SLTI,SGTI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.ui <= FALSE; end
		SLTUI,SGTUI:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
		BYTNDX:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-10{1'd0}},ir[29:20]}; end
		U21NDX:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; end
		PERM:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
		CHKI:
			begin
				decbuf.ui <= FALSE;
				decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]};
			end
		JAL,BAL:
			begin
				decbuf.needRa <= FALSE;
				decbuf.ui <= FALSE;
				decbuf.Rt <= {4'h0,ir[9:8]};
				decbuf.Ravec <= FALSE;
				decbuf.Rtvec <= FALSE;
				decbuf.imm.val <= {{VALUE_SIZE-26{ir[35]}},ir[35:10]};
				decbuf.rfwr <= TRUE;
				decbuf.mc <= TRUE;
			end
		JALR:
			begin
				decbuf.ui <= FALSE;
				decbuf.Rt <= {4'h0,ir[9:8]};
				decbuf.Rtvec <= FALSE;
				decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]};
				decbuf.rfwr <= TRUE;
				decbuf.mc <= TRUE; 
			end
`ifdef SUPPORT_CALL_RET			
		CALL:
			begin
				decbuf.ui <= FALSE;
				decbuf.call <= TRUE;
				decbuf.rfwr <= TRUE;
				decbuf.Rt <= 6'd30;	// SP
				decbuf.Ra <= 6'd30;
				decbuf.Rtvec <= FALSE;
				decbuf.Ravec <= FALSE;
				decbuf.imm.val <= {{VALUE_SIZE-26{ir[35]}},ir[35:10]};
				decbuf.mc <= TRUE; 
			end
		RTS:
			begin
				decbuf.ui <= FALSE;
				decbuf.rfwr <= TRUE;
				decbuf.Rt <= 6'd30;	// SP
				decbuf.Ra <= 6'd30;
				decbuf.Rtvec <= FALSE;
				decbuf.Ravec <= FALSE;
				decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]};
				decbuf.mc <= TRUE; 
			end
`endif			
		BEQ,BNE,BLT,BGE:	begin	decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:27],ir[19],ir[13:8]}; decbuf.branch <= TRUE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; decbuf.Ravec <= FALSE; decbuf.Ra[5] <= 1'b0; end
		BLTU,BGEU,BBS:	begin	decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:27],ir[19],ir[13:8]}; decbuf.branch <= TRUE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; decbuf.is_signed <= FALSE; decbuf.Ravec <= FALSE; decbuf.Ra[5] <= 1'b0; end
		LEA:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-12{ir.ld.disp[11]}},ir.ld.disp}; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
		LDx:	begin decbuf.Rt <= ir.ld.func==LSM ? decbuf.Rm : ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-12{ir.ld.disp[11]}},ir.ld.disp}; decbuf.ui <= FALSE; decbuf.mc <= TRUE; decbuf.lsm <= ir.ld.func==LSM; end
		LDxX: begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; decbuf.lsm <= ir.nld.func==LSM; end
		LDxZ:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-12{ir.ld.disp[11]}},ir.ld.disp}; decbuf.ui <= FALSE; decbuf.mc <= TRUE; decbuf.lsm <= ir.ld.func==LSM; end
		LDxXZ:begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; decbuf.lsm <= ir.nld.func==LSM; end
		LDSx: begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-12{ir.ld.disp[11]}},ir.ld.disp}; decbuf.ui <= FALSE; decbuf.Rtvec <= TRUE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; end
		LDxVX:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-12{ir.ld.disp[11]}},ir.ld.disp}; decbuf.ui <= FALSE; decbuf.Rtvec <= TRUE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; end
//		LDM: 	begin decbuf.ui <= FALSE; decbuf.mc <= TRUE; decbuf.Rt <= Rm; decbuf.lsm <= TRUE; decbuf.rfwr <= TRUE; end
		STx:	begin decbuf.Rt <= 6'd0; decbuf.Rb <= ir.ld.func==LSM ? {1'b0,decbuf.Rm} : {ir.r2.Tb,ir.r2.Rb}; decbuf.imm.val <= {{VALUE_SIZE-13{ir.st.disphi[4]}},ir.st.disphi,ir.st.displo}; decbuf.ui <= FALSE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; decbuf.lsm <= ir.st.func==LSM; end
		STxX: begin decbuf.Rt <= 6'd0; decbuf.ui <= FALSE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; decbuf.lsm <= ir.nst.func==LSM; end
		STSx: begin decbuf.Rt <= 6'd0; decbuf.imm.val <= {{VALUE_SIZE-13{ir.st.disphi[4]}},ir.st.disphi,ir.st.displo}; decbuf.ui <= FALSE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; end
		STxVX:	begin decbuf.Rt <= 6'd0; decbuf.imm.val <= {{VALUE_SIZE-13{ir.st.disphi[4]}},ir.st.disphi,ir.st.displo}; decbuf.ui <= FALSE; decbuf.needRb <= TRUE; decbuf.mc <= TRUE; end
//		STM: 	begin decbuf.Rt <= 6'd0; decbuf.ui <= FALSE; decbuf.mc <= TRUE; decbuf.Rb <= {1'b0,Rm}; decbuf.needRb <= TRUE; decbuf.lsm <= TRUE; end
		SYS:
			begin
				case(ir.r2.func)
				POPQ:		begin decbuf.ui <= FALSE; decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; end
				PEEKQ:	begin decbuf.ui <= FALSE; decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; end
				POPQI:	begin decbuf.ui <= FALSE; decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; end
				PEEKQI:	begin decbuf.ui <= FALSE; decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; end
				PFI:		begin decbuf.ui <= FALSE; decbuf.needRa <= FALSE; end
				TLBRW:	begin decbuf.ui <= FALSE; decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.mc <= TRUE; end
`ifdef SUPPORT_EXEC				
				EXEC:		begin decbuf.ui <= FALSE; decbuf.exec <= TRUE; end
`endif				
				CSAVE:		begin decbuf.ui <= FALSE; decbuf.Ra <= 6'd0; decbuf.Rb <= {2'b00,ir[12:8]}; decbuf.Rbseg <= ir[13]; decbuf.needRb <= TRUE; decbuf.needRa <= FALSE; decbuf.mc <= TRUE; end
				CRESTORE:	begin decbuf.ui <= FALSE; decbuf.Ra <= 6'd0; decbuf.Rt <= {1'b0,ir[12:8]}; decbuf.Rtseg <= ir[13]; decbuf.mc <= TRUE; decbuf.needRa <= FALSE; decbuf.rfwr <= TRUE; end
				default:	;
				endcase
			end
		CSR:	begin decbuf.Rt <= {1'b0,ir[12:8]}; decbuf.Rtvec <= FALSE; decbuf.Ra <= {1'b0,ir.r2.Ra}; decbuf.Ravec <= FALSE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; end
		RGLST0,RGLST1,RGLST2,RGLST3:	begin decbuf.ui <= FALSE; decbuf.needRa <= FALSE; decbuf.Ravec <= FALSE; decbuf.Rbvec <= FALSE; decbuf.Rtvec <= FALSE; end
		EXI0,EXI1,EXI2:	begin decbuf.ui <= FALSE; decbuf.needRa <= FALSE; decbuf.Ravec <= FALSE; decbuf.Rbvec <= FALSE; decbuf.Rtvec <= FALSE; end
		BRMOD:	begin decbuf.ui <= FALSE; decbuf.Rt <= {4'b0,ir.r2.Rt[1:0]}; decbuf.Rc <= {1'b0,ir.im.Tc1,ir.im.Rc}; decbuf.Rtvec <= FALSE; end
		IMOD,STRIDE:	begin decbuf.ui <= FALSE; decbuf.Rc <= {ir.im.Tc2,ir.im.Tc1,ir.im.Rc}; end
		VIMOD,VSTRIDE:	begin decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.ui <= FALSE; decbuf.Rc <= {ir.im.Tc2,ir.im.Tc1,ir.im.Rc}; end
`ifdef SUPPORT_VECTOR
		VR1:
			case(ir.r2.func)
			ABS:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			NABS:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			NOT:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			CTLZ:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			CTPOP:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			V2BITS:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.rfwr <= TRUE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			BITS2V:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			VCMPRSS:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			VCIDX:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
`ifdef SUPPORT_GRAPHICS			
			TRANSFORM:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
			CLIP:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Vm <= ir[23:21]; decbuf.z <= ir[20]; end
`endif
			default:	;
			endcase			
		VR2:
			begin
				decbuf.needRb <= TRUE; 
				case(ir.r2.func)
				ADD,SUB,AND,OR,XOR:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
`ifdef SUPPORT_MYST		
				MYST:	begin decbuf.Rt <= {ir.r2.Tt,ir.r2.Rt}; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
`endif				
				DIF:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				MULF:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
				MUL,MULU,MULSU,MULH,MULUH,MULSUH:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				DIV,DIVU,DIVSU:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				BMMOR,BMMXOR,BMMTOR,BMMTXOR:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				SLL,SRL:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				SLLI,SRLI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm <= {57'd0,ir.r2.Tb,ir.r2.Rb}; end
				SEQ,SNE,SLT,SGE,CMP:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				SLTU,SGEU:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
				VEX:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.rfwr <= TRUE; decbuf.vex <= TRUE; end
				VEINS:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.veins <= TRUE; end
				VSLLV:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; end
				VSRLV:	begin decbuf.Rt <= ir[13:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.vsrlv <= TRUE; end
				default:	;
				endcase
			end
		VR3:
			begin
				decbuf.needRb <= TRUE; 
				case(ir.r2.func)
				PTRDIF:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
				SLLP:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				CHK:
					begin
						decbuf.Rc <= ir[13:8];
						decbuf.Rcvec <= ir[14:13]==2'b01;
						decbuf.ui <= FALSE;
						decbuf.needRc <= TRUE;
					end
				default:	;
				endcase
			end
		VM:
			case(ir.r2.func)
			MTM:	begin decbuf.Rt <= {4'd0,ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; end
			MFM:	begin decbuf.Rt <= ir[13:8]; decbuf.Vm <= ir[16:14]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			MTVL:	begin decbuf.ui <= FALSE; end
			VMADD,MAND,MOR,MXOR:	begin decbuf.Rt <= {4'd0,ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; decbuf.Rbmask <= TRUE; end
			MFILL:	begin decbuf.Rt <= {4'd0,ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; end
			MFIRST,MLAST,MPOP:	begin decbuf.Rt <= ir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; end
			MSLL,MSRL:	begin decbuf.Rt <= {4'd0,ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; end
			default:	;
			endcase
`ifdef SUPPORT_FLOAT			
		VF1:
			case(ir.r2.func)
			FABS:		begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FNABS:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FNEG:		begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FSQRT:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
			I2F:		begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
			F2I:		begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
			default:	;
			endcase
		VF2:
			begin
				decbuf.needRb <= TRUE; 
				case(ir.r2.func)
				CPYSGN,SGNINV:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				FADD,FSUB,FMUL,FDIV:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				FMIN,FMAX:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				FCMP,FCMPB:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				FSEQ,FSNE,FSLT,FSLE:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
				default:	;
				endcase
			end
		VF3:
			begin
				decbuf.needRb <= TRUE; 
				case(ir.r2.func)
				MADD,MSUB,NMADD,NMSUB:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.mc <= TRUE; end
				default:	;
				endcase
			end
`endif			
		VADDI,VSUBFI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.ui <= FALSE; end
		VANDI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'b1}},ir[35:20]}; decbuf.ui <= FALSE; end
		VMULFI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.is_signed <= FALSE; end
		VMULI,VDIVI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.mc <= TRUE; end
		VMULUI,VMULSUI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.mc <= TRUE; end
		VDIVUI,VDIVSUI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.mc <= TRUE; end
		VORI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
		VXORI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
`ifdef SUPPORT_MYST		
		VMYSTI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
`endif		
		VBTFLD:		begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
		VSEQI,VSNEI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.ui <= FALSE; end
		VSLTI,VSGTI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]}; decbuf.ui <= FALSE; end
		VSLTUI,VSGTUI:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; decbuf.is_signed <= FALSE; end
		VBYTNDX:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= ir[30]; decbuf.vrfwr <= ~ir[30]; decbuf.ui <= FALSE; decbuf.imm.val <= {54'd0,ir[29:20]}; end
		VU21NDX:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= ir[30]; decbuf.vrfwr <= ~ir[30]; decbuf.ui <= FALSE; decbuf.imm.val <= {54'd0,ir[29:20]}; end
		VPERM:	begin decbuf.Rt <= ir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{VALUE_SIZE-16{1'd0}},ir[35:20]}; decbuf.ui <= FALSE; end
		VCHKI:
			begin
				decbuf.ui <= FALSE;
				decbuf.imm.val <= {{VALUE_SIZE-16{ir[35]}},ir[35:20]};
			end
		VSYS:
			begin
				case(ir.r2.func)
`ifdef SUPPORT_EXEC				
				EXEC:		begin decbuf.ui <= FALSE; end
`endif				
				default:	;
				endcase
			end
`endif			
		default:	;
		endcase
	end

task tDecode20;
begin
	decbuf.ui <= FALSE;
	decbuf.Rtvec <= FALSE;
	decbuf.Ravec <= FALSE;
	decbuf.Rbvec <= FALSE;
	case(ir.r2.opcode[3:0])
	4'd0:
		case(ir[12:8])
		5'd0:
			case(ir[19:13])
			7'd120:	; // RTI
			7'd121:	;	// PFI
  		7'd123:	;	// WFI
			default:	;	// BRK
			endcase
		default:	// LDO FP
			begin
				decbuf.rfwr <= TRUE;
				decbuf.Rt <= {1'b0,ir[12:8]};
				decbuf.Ra <= {1'b0,5'd29};
				decbuf.imm <= {{VALUE_SIZE-10{ir[19]}},ir[19:13],3'b0};
			end
		endcase
	4'd1:	// LDO SP
		begin
			decbuf.rfwr <= TRUE;
			decbuf.Rt <= {1'b0,ir[12:8]};
			decbuf.Ra <= {1'b0,5'd30};
			decbuf.imm <= {{VALUE_SIZE-10{ir[19]}},ir[19:13],3'b0};
		end
	4'd2:	// STO FP
		begin
			decbuf.Rb <= {2'b00,ir[12:8]};
			decbuf.Ra <= {1'b0,5'd29};
			decbuf.imm <= {{VALUE_SIZE-10{ir[19]}},ir[19:13],3'b0};
		end
	4'd3:	// STO SP
		begin
			decbuf.Rb <= {2'b00,ir[12:8]};
			decbuf.Ra <= {1'b0,5'd30};
			decbuf.imm <= {{VALUE_SIZE-10{ir[19]}},ir[19:13],3'b0};
		end
	4'd4:
		case(ir[19:18])
		2'd0:	begin decbuf.Rt <= {4'd0,ir[9:8]}; decbuf.Ra <= {1'b0,ir[17:13]}; decbuf.imm <= {VALUE_SIZE{1'd0}}; decbuf.mc <= TRUE; decbuf.rfwr <= TRUE; end
		default: begin decbuf.Rt <= {4'd0,ir[9:8]}; decbuf.Ra <= {1'b0,ir[17:13]}; decbuf.rfwr <= TRUE; end
		endcase
	4'd5,4'd6,4'd7:	begin decbuf.Rt <= {1'b0,ir[12:8]}; decbuf.Ra <= {1'b0,ir[12:8]}; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE;
		decbuf.imm <= ir[12:8]==5'd30 ? {{VALUE_SIZE-10{ir[19]}},ir[19:13],3'b0} : {{VALUE_SIZE-7{ir[19]}},ir[19:13]}; end
	4'd8,4'd9: begin decbuf.Ra <= {1'b0,ir[12:8]}; decbuf.Ravec <= 1'b0; decbuf.imm <= {{VALUE_SIZE-7{ir[19]}},ir[19:13]}; decbuf.mc <= TRUE; end	// BEQZ / BNEZ
	4'd10:	begin decbuf.Rt <= {4'd0,ir[9:8]}; decbuf.needRa <= FALSE; decbuf.imm <= {{VALUE_SIZE-10{ir[19]}},ir[19:10]}; decbuf.mc <= TRUE; decbuf.rfwr <= TRUE; end	// BAL / BRA
	4'd11:  begin decbuf.Rt <= {1'd0,ir[12:8]}; decbuf.needRa <= FALSE; decbuf.imm <= {{VALUE_SIZE-7{ir[19]}},ir[19:13]}; decbuf.rfwr <= TRUE; end	// LDI
	4'd12:
			case(ir[19:18])
			2'b11:		begin decbuf.Rt <= fnRn3(ir[10:8]); decbuf.Ra <= fnRn3(ir[10:8]); decbuf.Rb <= fnRn3(ir[15:13]); decbuf.needRb <= TRUE; decbuf.rfwr <= TRUE; end
			default:	begin decbuf.Rt <= {1'd0,ir[12:8]}; decbuf.Ra <= {1'd0,ir[12:8]}; decbuf.imm <= {{VALUE_SIZE-5{ir[19]}},ir[17:13]}; decbuf.rfwr <= TRUE; end
			endcase
	4'd13:	decbuf.ui <= TRUE;
	4'd14:	begin decbuf.Rt <= fnPickRn(ir[19:8]); decbuf.Ra <= {1'b0,5'd30}; decbuf.mc <= TRUE; decbuf.lsm <= TRUE; end
	4'd15:	begin decbuf.Ra <= {1'b0,5'd30}; decbuf.Rb <= fnPickRn(ir[19:8]); decbuf.mc <= TRUE; decbuf.lsm <= TRUE; end
	default:	;
	endcase
end
endtask

endmodule
