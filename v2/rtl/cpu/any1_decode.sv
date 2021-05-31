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

// Rename these signals for convenience
Address dip;
Instruction dir;

always @*
begin
//	dc_rid = a2d_out.rid;
	dip <= a2d_out.ip;
	dir <= a2d_out.ir;
end

always @*
	begin
//		decbuf.rid <= dc_rid;
		decbuf.ui <= TRUE;
		decbuf.ir <= dir;
		decbuf.ip <= dip;
		decbuf.pip <= predicted_ip;
		decbuf.predict_taken <= a2d_out.predict_taken;
		decbuf.Stream <= a2d_out.Stream;
		decbuf.Stream_inc <= 1'b0;
		decbuf.rfwr <= FALSE;
		decbuf.vrfwr <= FALSE;
		decbuf.Ra <= dir.r2.Ra;
		decbuf.Rb <= dir.r2.Rb;
		decbuf.Rc <= 6'd0;
		decbuf.Rt <= 6'd0;
		decbuf.Ravec <= FALSE;
		decbuf.Rbvec <= FALSE;
		decbuf.Rtvec <= FALSE;
		decbuf.RaStep <= ven;
		decbuf.RbStep <= ven;
		decbuf.step <= ven;
		decbuf.is_vec <= dir.r2.opcode[7];
		decbuf.branch <= dir.r2.opcode[7:3]=={4'h4,1'b1};
		decbuf.vex <= FALSE;
		decbuf.is_mod <= dir.r2.opcode[7:4]==4'h5;
		decbuf.needRc <= FALSE;
		decbuf.imm.val <= 64'd0;
//		dcRedirectIp <= dip + {{25{dir[63]}},dir[63:28],3'h0};
		case(dir.r2.opcode)
		BRK:	decbuf.ui <= FALSE;
		NOP:	decbuf.ui <= FALSE;
		R1:
			case(dir.r2.func)
			ABS:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			NOT:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			V2BITS:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		R2:
			case(dir.r2.func)
			ADD,SUB,AND,OR,XOR:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			DIF:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			MULF:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			MUL,MULU,MULSU,MULH,MULUH,MULSUH:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			DIV,DIVU,DIVSU:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			SEQ,SNE,SLT,SGE,SLTU,SGEU,CMP:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			default:	;
			endcase
		R3:
			case(dir.r2.func)
			PTRDIF:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			SLL:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			CHK:
				begin
					decbuf.Rc <= dir[13:8];
					decbuf.ui <= FALSE;
					decbuf.needRc <= TRUE;
				end
			default:	;
			endcase
		ADDI,SUBFI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; decbuf.ui <= FALSE; end
		ANDI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{1'b1}},dir[31:20]}; decbuf.ui <= FALSE; end
		MULI,DIVI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; end
		MULUI,MULSUI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {52'd0,dir[31:20]}; end
		DIVUI,DIVSUI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {52'd0,dir[31:20]}; end
		ORI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {32'd0,dir[31:20]}; decbuf.ui <= FALSE; end
		XORI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {32'd0,dir[31:20]}; decbuf.ui <= FALSE; end
		BTFLD:		begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		SEQI,SNEI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; decbuf.ui <= FALSE; end
		SLTI,SGTI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; decbuf.ui <= FALSE; end
		SLTUI,SGTUI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {52'd0,dir[31:20]}; decbuf.ui <= FALSE; end
		BYTNDX:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {56'd0,dir[27:20]}; end
		U21NDX:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {56'd0,dir[27:20]}; end
		PERM:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{56{1'b0}},dir[27:20]}; decbuf.ui <= FALSE; end
		CHKI:
			begin
				decbuf.ui <= FALSE;
				decbuf.imm.val <= decbuf.imm.val <= {{52{dir[31]}},dir[31:20]};
			end
		JAL,BAL:
			begin
				decbuf.ui <= FALSE;
				decbuf.Rt <= {6'h0,dir[9:8]};
				decbuf.imm.val <= {{40{dir[31]}},dir[31:10],2'h0};
				decbuf.rfwr <= TRUE;
				decbuf.Stream_inc <= 1'b1;
			end
		JALR:
			begin
				decbuf.ui <= FALSE;
				decbuf.Rt <= {6'h0,dir[9:8]};
				decbuf.imm.val <= {{50{dir[31]}},dir[31:20],2'h0};
				decbuf.rfwr <= TRUE;
			end
		BEQ,BNE,BLT,BGE,BLTU,BGEU,BBS:	begin	decbuf.ui <= FALSE; decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{50{dir[31]}},dir[31:26],dir[13:8],2'd0}; decbuf.branch <= TRUE; end
		LEA:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{56{dir.ld.disp[7]}},dir.ld.disp}; decbuf.ui <= FALSE; end
		LDx:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{56{dir.ld.disp[7]}},dir.ld.disp}; decbuf.ui <= FALSE; end
		LDxX: begin decbuf.Rt <= dir.ld.Rt; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		LDSx: begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{56{dir.ld.disp[7]}},dir.ld.disp}; decbuf.ui <= FALSE; decbuf.Rtvec <= TRUE; end
		LDxVX:	begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.imm.val <= {{56{dir.ld.disp[7]}},dir.ld.disp}; decbuf.ui <= FALSE; decbuf.Rtvec <= TRUE; end
		STx:	begin decbuf.Rt <= 6'd0; decbuf.Rc <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{56{dir.st.disphi[1]}},dir.st.disphi,dir.st.displo}; decbuf.ui <= FALSE; decbuf.needRc <= TRUE; end
		STxX: begin decbuf.Rt <= 6'd0; decbuf.ui <= FALSE; end
		STSx: begin decbuf.Rt <= 6'd0; decbuf.imm.val <= {{56{dir.st.disphi[1]}},dir.st.disphi,dir.st.displo}; decbuf.ui <= FALSE; end
		STxVX:	begin decbuf.Rt <= 6'd0; decbuf.imm.val <= {{56{dir.st.disphi[1]}},dir.st.disphi,dir.st.displo}; decbuf.ui <= FALSE; end
		SYS:
			begin
				case(dir.r2.func)
				PFI:		decbuf.ui <= FALSE;
				TLBRW:	begin decbuf.ui <= FALSE; decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; end
				default:	;
				endcase
			end
		CSR:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.imm.val <= {52'd0,dir[31:20]}; end
		EXI0,EXI1,EXI2,IMOD,BRMOD,STRIDE:	decbuf.ui <= FALSE;
`ifdef SUPPORT_VECTOR
		VR1:
			case(dir.r2.func)
			ABS:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
			NOT:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
			V2BITS:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= FALSE; end
			BITS2V:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= FALSE; decbuf.Rtvec <= TRUE; end
			VCMPRSS:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
			VCIDX:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= FALSE; decbuf.Rtvec <= TRUE; end
			default:	;
			endcase			
		VR2:
			case(dir.r2.func)
			ADD,SUB,AND,OR,XOR:	begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			DIF:	begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			MULF:	begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			MUL,MULU,MULSU,MULH,MULUH,MULSUH:	begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			DIV,DIVU,DIVSU:	begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			SEQ,SNE,SLT,SGE,SLTU,SGEU,CMP:	begin decbuf.Rt <= dir[13:8]; decbuf.vrfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			VEX:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.rfwr <= TRUE; decbuf.vex <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= FALSE; end
			VEINS:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.veins <= TRUE; decbuf.Rbvec <= FALSE; decbuf.Rtvec <= TRUE; end
			VSLLV:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
			VSLRV:	begin decbuf.Rt <= dir[15:8]; decbuf.ui <= FALSE; decbuf.vrfwr <= TRUE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
			default:	;
			endcase
		VR3:
			case(dir.r2.func)
			PTRDIF:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			SLL:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rbvec <= TRUE; decbuf.Rtvec <= TRUE; end
			CHK:
				begin
					decbuf.Ravec <= TRUE;
					decbuf.Rbvec <= TRUE; 
					decbuf.Rc <= dir[13:8];
					decbuf.ui <= FALSE;
					decbuf.needRc <= TRUE;
				end
			default:	;
			endcase
		VADDI,VSUBFI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VANDI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{1'b1}},dir[31:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VMULI,VDIVI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VMULUI,VMULSUI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {52'd0,dir[31:20]}; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VDIVUI,VDIVSUI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {52'd0,dir[31:20]}; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VORI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {32'd0,dir[31:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VXORI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {32'd0,dir[31:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VBTFLD:		begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		VSEQI,VSNEI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VSLTI,VSGTI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{52{dir[31]}},dir[31:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VSLTUI,VSGTUI:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {52'd0,dir[31:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VBYTNDX:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {56'd0,dir[27:20]}; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VU21NDX:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {56'd0,dir[27:20]}; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VPERM:	begin decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{56{1'b0}},dir[27:20]}; decbuf.ui <= FALSE; decbuf.Ravec <= TRUE; decbuf.Rtvec <= TRUE; end
		VCHKI:
			begin
				decbuf.ui <= FALSE;
				decbuf.Ravec <= TRUE; 
				decbuf.imm.val <= decbuf.imm.val <= {{52{dir[31]}},dir[31:20]};
			end
`endif			
		default:	;
		endcase
	end

endmodule
