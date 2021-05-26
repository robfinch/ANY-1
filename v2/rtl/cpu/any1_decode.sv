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

module any1_decode(a2d_out, decbuf, predicted_ip);
input sInstAlignOut a2d_out;
output sDecode decbuf;
input Address predicted_ip;

reg [5:0] dc_rid;
Address dip;
Instruction dir;

always @*
begin
	dc_rid = a2d_out.rid;
	dip = a2d_out.ip;
	dir = a2d_out.ir;
end

always @*
	begin
		decbuf.rid <= dc_rid;
		decbuf.ui <= TRUE;
		decbuf.ir <= dir;
		decbuf.ip <= dip;
		decbuf.pip <= predicted_ip;
		decbuf.predict_taken <= a2d_out.predict_taken;
		decbuf.Stream <= a2d_out.Stream;
		decbuf.Stream_inc <= 1'b0;
		decbuf.rfwr <= FALSE;
		decbuf.Ra <= dir.Ra;
		decbuf.Rb <= dir.Rb;
		decbuf.Rc <= dir.Rc;
		decbuf.Rd <= dir.func;		/// same field as Rd
		decbuf.Rt <= 8'd0;
		decbuf.is_vec <= dir.Ra[7:6]==2'b01 || dir.Rb[7:6]==2'b01 || dir.Rc[7:6]==2'b01 || dir.Rt[7:6]==2'b01;
		decbuf.imm.val <= 64'd0;
//		dcRedirectIp <= dip + {{25{dir[63]}},dir[63:28],3'h0};
		case(dir.opcode)
		NOP:	decbuf.ui <= FALSE;
		R3:
			case(dir.func)
			ADD,SUB,AND,OR,XOR:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			SLL:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
			R2:
				case(dir[39:32])
				DIF:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				MULF:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				MUL,MULU,MULSU,MULH,MULUH,MULSUH:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				DIV,DIVU,DIVSU:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				SEQ,SNE,SLT,SGE,SLTU,SGEU:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
				R1:
					case(dir.Rb)
					ABS:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
					NOT:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
					V2BITS:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
					default:	;
					endcase
				default:	;
				endcase
			CHK:
				begin
					decbuf.Rc <= dir[15:8];
					decbuf.ui <= FALSE;
				end
			default:	;
			endcase
		ADDI,SUBFI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{32{dir[59]}},dir[59:28]}; decbuf.ui <= FALSE; end
		ANDI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{32{1'b1}},dir[59:28]}; decbuf.ui <= FALSE; end
		MULI,DIVI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {{32{dir[59]}},dir[59:28]}; end
		MULUI,MULSUI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {32'd0,dir[59:28]}; end
		DIVUI,DIVSUI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {32'd0,dir[59:28]}; end
		ORI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {32'd0,dir[59:28]}; decbuf.ui <= FALSE; end
		XORI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {32'd0,dir[59:28]}; decbuf.ui <= FALSE; end
		EXT,EXTU:		begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; end
		SEQI,SNEI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{32{dir[59]}},dir[59:28]}; decbuf.ui <= FALSE; end
		SLTI,SGTI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{32{dir[59]}},dir[59:28]}; decbuf.ui <= FALSE; end
		SLTUI,SGTUI:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {32'd0,dir[59:28]}; decbuf.ui <= FALSE; end
		BYTNDX:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= dir[31:24]; end
		U21NDX:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.ui <= FALSE; decbuf.imm.val <= {dir[52:48],dir[39:24]}; end
		PERM:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{36{1'b0}},dir[55:48],dir[39:24]}; decbuf.ui <= FALSE; end
		CHKI:
			begin
				decbuf.ui <= FALSE;
				decbuf.imm.val <= decbuf.imm.val <= {{32{dir[59]}},dir[59:28]};
			end
		JAL:
			begin
				decbuf.ui <= FALSE;
				decbuf.Rt <= {6'h0,dir[9:8]};
				decbuf.imm.val <= {{25{dir[59]}},dir[59:24],3'h0};
				decbuf.rfwr <= TRUE;
				case(dir[21:16])
				6'd0:		decbuf.Stream_inc <= 1'b1;
				6'd63:	decbuf.Stream_inc <= 1'b1;
				default:	;
				endcase
			end
		BEQ,BNE,BLT,BGE,BLTU,BGEU:	begin	decbuf.ui <= FALSE; decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{45{dir[59]}},dir[59:48],dir[43:40],3'd0}; end
		LEA:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{44{dir[59]}},dir[59:48],dir[39:32]}; decbuf.ui <= FALSE; end
		LDx:	begin decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{44{dir[59]}},dir[59:48],dir[39:32]}; decbuf.ui <= FALSE; end
		STx:	begin decbuf.Rt <= 6'd0; decbuf.Rc <= dir[15:8]; decbuf.rfwr <= TRUE; decbuf.imm.val <= {{44{dir[59]}},dir[59:48],dir[39:32]}; decbuf.ui <= FALSE; end
		SYS:
			begin
				case(dir.func)
				CSR:		decbuf.ui <= FALSE;
				PFI:		decbuf.ui <= FALSE;
				TLBRW:	begin decbuf.ui <= FALSE; decbuf.Rt <= dir[15:8]; decbuf.rfwr <= TRUE; end
				default:	;
				endcase
			end
		default:	;
		endcase
	end

endmodule
