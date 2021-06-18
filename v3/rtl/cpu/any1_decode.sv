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

module any1_decode(a2d_out, decbuf, predicted_ip, ven);
input sInstAlignOut a2d_out;
output sDecode decbuf;
input Address predicted_ip;
input [5:0] ven;

always @*//(a2d_out, predicted_ip, ven)
	begin
//		decbuf.rid <= dc_rid;
		decbuf.v <= a2d_out.v;
		decbuf.ui <= TRUE;
		decbuf.ir <= a2d_out.ir;
		decbuf.ip <= a2d_out.ip;
		decbuf.pip <= predicted_ip;
		decbuf.predict_taken <= a2d_out.predict_taken;
		decbuf.rfwr <= FALSE;
		decbuf.vrfwr <= FALSE;
		decbuf.Ra <= a2d_out.ir.r2.Ra;
		decbuf.Rb <= a2d_out.ir.r2.Rb;
		decbuf.Vm <= 3'd0;
		decbuf.z <= 1'b0;
		decbuf.Rc <= 6'd0;
		decbuf.Rt <= 6'd0;
		decbuf.Ravec <= a2d_out.ir.r2.Ta==2'b01;
		decbuf.Rbvec <= a2d_out.ir.r2.Tb==2'b01;
		decbuf.Rcvec <= FALSE;
		decbuf.Rtvec <= a2d_out.ir.r2.Tt==2'b01;
		decbuf.Ramask <= FALSE;
		decbuf.Rbmask <= FALSE;
		decbuf.RaStep <= ven;
		decbuf.RbStep <= ven;
		decbuf.step <= ven;
		decbuf.is_vec <= a2d_out.ir.r2.opcode[7];
		decbuf.branch <= a2d_out.ir.r2.opcode[7:3]=={4'h4,1'b1};
		decbuf.vex <= FALSE;
		decbuf.veins <= FALSE;
		decbuf.vsrlv <= FALSE;
		decbuf.is_mod <= a2d_out.ir.r2.opcode[7:4]==4'h5;
		decbuf.needRc <= FALSE;
		decbuf.imm.val <= 64'd0;
		decbuf.mem_op <= a2d_out.ir.r2.opcode[6:5]==2'd3;
//		dcRedirectIp <= a2d_out.ip + {{25{a2d_out.ir[63]}},a2d_out.ir[63:28],3'h0};
		case(a2d_out.ir.r2.opcode)
		BRK:	decbuf.ui <= FALSE;
		NOP:	decbuf.ui <= FALSE;
		R1:
			case(a2d_out.ir.r2.func)
			ABS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			NABS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			NOT:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			CTLZ:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			CTPOP:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			TRANSFORM:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		R2:
			case(a2d_out.ir.r2.func)
			ADD,SUB,AND,OR,XOR:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			DIF:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			MULF:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			MUL,MULU,MULSU,MULH,MULUH,MULSUH:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			DIV,DIVU,DIVSU:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			SLL,SRL:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			SLLI,SRLI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm <= {57'd0,a2d_out.ir.r2.Rb}; end
			SEQ,SNE,SLT,SGE,SLTU,SGEU,CMP:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		R3:
			case(a2d_out.ir.r2.func)
			PTRDIF:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			SLLP:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			CHK:
				begin
					decbuf.Rc <= a2d_out.ir[14:8];
					decbuf.ui <= FALSE;
					decbuf.needRc <= TRUE;
				end
			default:	;
			endcase
`ifdef SUPPORT_FLOAT
		F1:
			case(a2d_out.ir.r2.func)
			FABS:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FNABS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FNEG:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FSQRT:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			I2F:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			F2I:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FRM:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		F2:
			case(a2d_out.ir.r2.func)
			CPYSGN,SGNINV:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FADD,FSUB,FMUL,FDIV:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FMIN,FMAX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FCMP,FCMPB:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			FSEQ,FSNE,FSLT,FSLE:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			//FSETM:	begin decbuf.Rt <= {3'd0,a2d_out.ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		F3:
			case(a2d_out.ir.r2.func)
			MADD,MSUB,NMADD,NMSUB:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
`endif			
		ADDI,SUBFI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		ANDI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{1'b1}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		MULI,DIVI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; end
		MULUI,MULSUI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; end
		DIVUI,DIVSUI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; end
		ORI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		XORI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		BTFLD:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		SEQI,SNEI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		SLTI,SGTI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		SLTUI,SGTUI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		BYTNDX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {56'd0,a2d_out.ir[29:22]}; end
		U21NDX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; end
		PERM:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{1'b0}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		CHKI:
			begin
				decbuf.ui <= FALSE;
				decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]};
			end
		JAL,BAL:
			begin
				decbuf.ui <= FALSE;
				decbuf.Rt <= {5'h0,a2d_out.ir[9:8]};
				decbuf.imm.val <= {{38{a2d_out.ir[35]}},a2d_out.ir[35:10]};
				decbuf.rfwr <= TRUE;
			end
		JALR:
			begin
				decbuf.ui <= FALSE;
				decbuf.Rt <= {5'h0,a2d_out.ir[9:8]};
				decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]};
				decbuf.rfwr <= TRUE;
			end
		BEQ,BNE,BLT,BGE,BLTU,BGEU,BBS:	begin	decbuf.ui <= FALSE; decbuf.imm.val <= {{52{a2d_out.ir[35]}},a2d_out.ir[35:29],a2d_out.ir[12:8]}; decbuf.branch <= TRUE; end
		LEA:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{54{a2d_out.ir.ld.disp[9]}},a2d_out.ir.ld.disp}; decbuf.ui <= FALSE; end
		LDx:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{54{a2d_out.ir.ld.disp[9]}},a2d_out.ir.ld.disp}; decbuf.ui <= FALSE; end
		LDxX: begin decbuf.Rt <= a2d_out.ir.ld.Rt; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		LDSx: begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{54{a2d_out.ir.ld.disp[4]}},a2d_out.ir.ld.disp}; decbuf.ui <= FALSE; decbuf.Rtvec <= TRUE; end
		LDxVX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{54{a2d_out.ir.ld.disp[4]}},a2d_out.ir.ld.disp}; decbuf.ui <= FALSE; decbuf.Rtvec <= TRUE; end
		STx:	begin decbuf.Rt <= 6'd0; decbuf.rfwr <= FALSE; decbuf.imm.val <= {{54{a2d_out.ir.st.disphi[2]}},a2d_out.ir.st.disphi,a2d_out.ir.st.displo}; decbuf.ui <= FALSE; end
		STxX: begin decbuf.Rt <= 6'd0; decbuf.ui <= FALSE; end
		STSx: begin decbuf.Rt <= 6'd0; decbuf.imm.val <= {{52{a2d_out.ir.st.disphi}},a2d_out.ir.st.disphi,a2d_out.ir.st.displo}; decbuf.ui <= FALSE; end
		STxVX:	begin decbuf.Rt <= 6'd0; decbuf.imm.val <= {{52{a2d_out.ir.st.disphi}},a2d_out.ir.st.disphi,a2d_out.ir.st.displo}; decbuf.ui <= FALSE; end
		SYS:
			begin
				case(a2d_out.ir.r2.func)
				POPQ:		begin decbuf.ui <= FALSE; decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; end
				PEEKQ:	begin decbuf.ui <= FALSE; decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; end
				POPQI:	begin decbuf.ui <= FALSE; decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; end
				PEEKQI:	begin decbuf.ui <= FALSE; decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; end
				PFI:		decbuf.ui <= FALSE;
				TLBRW:	begin decbuf.ui <= FALSE; decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; end
				default:	;
				endcase
			end
		CSR:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; end
		EXI0,EXI1,EXI2,BRMOD,BTFLDX,IMOD,STRIDE:	decbuf.ui <= FALSE;
		VIMOD,VSTRIDE:	begin decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.ui <= FALSE; end
`ifdef SUPPORT_VECTOR
		VR1:
			case(a2d_out.ir.r2.func)
			ABS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			NABS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			NOT:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			CTLZ:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			CTPOP:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			V2BITS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.rfwr <= TRUE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			BITS2V:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			VCMPRSS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			VCIDX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Vm <= a2d_out.ir[25:23]; decbuf.z <= a2d_out.ir[22]; end
			default:	;
			endcase			
		VR2:
			case(a2d_out.ir.r2.func)
			ADD,SUB,AND,OR,XOR:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			DIF:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			MULF:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			MUL,MULU,MULSU,MULH,MULUH,MULSUH:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			DIV,DIVU,DIVSU:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			SLL,SRL:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			SLLI,SRLI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm <= {57'd0,a2d_out.ir.r2.Rb}; end
			SEQ,SNE,SLT,SGE,SLTU,SGEU,CMP:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			VEX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.rfwr <= TRUE; decbuf.vex <= TRUE; end
			VEINS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.veins <= TRUE; end
			VSLLV:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; end
			VSRLV:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.vsrlv <= TRUE; end
			default:	;
			endcase
		VR3:
			case(a2d_out.ir.r2.func)
			PTRDIF:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			SLLP:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			CHK:
				begin
					decbuf.Rc <= a2d_out.ir[14:8];
					decbuf.Rcvec <= a2d_out.ir[14:13]==2'b01;
					decbuf.ui <= FALSE;
					decbuf.needRc <= TRUE;
				end
			default:	;
			endcase
		VM:
			case(a2d_out.ir.r2.func)
			MTM:	begin decbuf.Rt <= {4'd0,a2d_out.ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; end
			MFM:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.Vm <= a2d_out.ir[17:15]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			MTVL:	begin decbuf.ui <= FALSE; end
			VMADD,MAND,MOR,MXOR:	begin decbuf.Rt <= {4'd0,a2d_out.ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; decbuf.Rbmask <= TRUE; end
			MFILL:	begin decbuf.Rt <= {4'd0,a2d_out.ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; end
			MFIRST,MLAST,MPOP:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; end
			MSLL,MSRL:	begin decbuf.Rt <= {4'd0,a2d_out.ir[10:8]}; decbuf.vmrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ramask <= TRUE; end
			default:	;
			endcase
`ifdef SUPPORT_FLOAT			
		VF1:
			case(a2d_out.ir.r2.func)
			FABS:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FNABS:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FNEG:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FSQRT:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			I2F:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			F2I:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		VF2:
			case(a2d_out.ir.r2.func)
			CPYSGN,SGNINV:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FADD,FSUB,FMUL,FDIV:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FMIN,FMAX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FCMP,FCMPB:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			FSEQ,FSNE,FSLT,FSLE:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		VF3:
			case(a2d_out.ir.r2.func)
			MADD,MSUB,NMADD,NMSUB:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
`endif			
		VADDI,VSUBFI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		VANDI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{1'b1}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		VMULI,VDIVI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; end
		VMULUI,VMULSUI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; end
		VDIVUI,VDIVSUI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; end
		VORI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		VXORI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		VBTFLD:		begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		VSEQI,VSNEI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		VSLTI,VSGTI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		VSLTUI,VSGTUI:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {50'd0,a2d_out.ir[35:22]}; decbuf.ui <= FALSE; end
		VBYTNDX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= a2d_out.ir[30]; decbuf.vrfwr <= ~a2d_out.ir[30]; decbuf.ui <= FALSE; decbuf.imm.val <= {56'd0,a2d_out.ir[29:22]}; end
		VU21NDX:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= a2d_out.ir[30]; decbuf.vrfwr <= ~a2d_out.ir[30]; decbuf.ui <= FALSE; decbuf.imm.val <= {56'd0,a2d_out.ir[29:22]}; end
		VPERM:	begin decbuf.Rt <= a2d_out.ir[14:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{1'b0}},a2d_out.ir[33:22]}; decbuf.ui <= FALSE; end
		VCHKI:
			begin
				decbuf.ui <= FALSE;
				decbuf.imm.val <= {{50{a2d_out.ir[35]}},a2d_out.ir[35:22]};
			end
`endif			
		default:	;
		endcase
	end

endmodule
