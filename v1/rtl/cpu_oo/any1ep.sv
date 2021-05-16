// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1ep.sv
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

module any1ep(rst, clk, cyc_o, stb_o, ack_i, sel_o, adr_o, dat_i, dat_o);
input rst;
input clk;
output reg cyc_o;
output reg stb_o;
input ack_i;
output [15:0] sel_o;
output [AWID-1:0] adr_o;
input [127:0] dat_i;
output reg [127:0] dat_o;

wire clk_g = clk;

reg [3:0] omode;
reg [63:0] ir;
sDecode decbuf, regbuf;
sExecuteIn exbufi;
sExecuteOut exbufo;
sReorderEntry [15:0] rob;
reg [3:0] rob_tail;
reg [3:0] rob_head;
reg [3:0] if_rid, ia_rid, a2d_rid, dc_rid;
reg [5:0] mstate;

reg [AWID-1:0] ip, aip;
reg [AWID-1:0] f2a_ip;

reg [WID-1:0] regfile [0:63];
reg [5:0] regfilestat [0:63];

reg [5:0] fEpoch,dEpoch,eEpoch;
reg [5:0] ifEpoch,dcEpoch,rfEpoch,exEpoch;	// epoch associated with instructions
reg [5:0] next_dcEpoch;
reg decRedirect_rd;
wire [AWID-1:0] decRedirect_ip;
wire decRedirect_v;
reg execRedirect_rd;
wire [AWID-1:0] execRedirect_ip;
wire execRedirect_v;

reg dc2if_wr;
reg exfifo_rd;
reg memfifo_wr;
wire [AWID-1:0] dip;
wire [63:0] dir;
wire r2x_full,x2m_full;

//CSRs
reg [7:0] cause [0:7];
reg [AWID-1:0] badaddr [0:7];
reg [AWID-1:0] eip;
reg [31:0] pmStack;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

any1_agen uagen
(
	.clk(clk_g),
	.ir(membufo.ir),
	.ia(membufo.ia),
	.ib(membufo.ib),
	.ea(ea)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [3:0] icnt;
reg [511:0] ici;
reg [511:0] iri, airi;
(* ram_style="distributed" *)
reg [511:0] icache0 [0:pL1CacheLines-1];
reg [511:0] icache1 [0:pL1CacheLines-1];
reg [511:0] icache2 [0:pL1CacheLines-1];
reg [511:0] icache3 [0:pL1CacheLines-1];
(* ram_style="distributed" *)
reg [AWID-1:6] ictag0 [0:pL1CacheLines-1];
reg [AWID-1:6] ictag1 [0:pL1CacheLines-1];
reg [AWID-1:6] ictag2 [0:pL1CacheLines-1];
reg [AWID-1:6] ictag3 [0:pL1CacheLines-1];
(* ram_style="distributed" *)
reg [pL1CacheLines-1:0] icvalid0;
reg [pL1CacheLines-1:0] icvalid1;
reg [pL1CacheLines-1:0] icvalid2;
reg [pL1CacheLines-1:0] icvalid3;
reg ic_invline;
reg ihit1a;
reg ihit1b;
reg ihit1c;
reg ihit1d;
always @*	//(posedge clk_g)
  ihit1a <= ictag0[ip[pL1msb:6]]==ip[AWID-1:6] && icvalid0[ip[pL1msb:6]];
always @*	//(posedge clk_g)
  ihit1b <= ictag1[ip[pL1msb:6]]==ip[AWID-1:6] && icvalid1[ip[pL1msb:6]];
always @*	//(posedge clk_g)
  ihit1c <= ictag2[ip[pL1msb:6]]==ip[AWID-1:6] && icvalid2[ip[pL1msb:6]];
always @*	//(posedge clk_g)
  ihit1d <= ictag3[ip[pL1msb:6]]==ip[AWID-1:6] && icvalid3[ip[pL1msb:6]];
wire ihit = ihit1a|ihit1b|ihit1c|ihit1d;
initial begin
  icvalid0 = {pL1CacheLines{1'd0}};
  icvalid1 = {pL1CacheLines{1'd0}};
  icvalid2 = {pL1CacheLines{1'd0}};
  icvalid3 = {pL1CacheLines{1'd0}};
  for (n = 0; n < pL1CacheLines; n = n + 1) begin
  	icache0[n] <= {12{NOP_INSN}};
  	icache1[n] <= {12{NOP_INSN}};
  	icache2[n] <= {12{NOP_INSN}};
  	icache3[n] <= {12{NOP_INSN}};
    ictag0[n] = 32'd1;
    ictag1[n] = 32'd1;
    ictag2[n] = 32'd1;
    ictag3[n] = 32'd1;
  end
end

wire f2a_full, f2a_v;
wire a2d_full, a2d_v;
wire d2r_full, d2r_v;
wire r2x_full, r2x_v;

f2a_fifo uf2a
(
  .clk(clk_g),      // input wire clk
  .srst(srst),    // input wire srst
  .din({if_rid,ip,iri}),      // input wire [511 : 0] din
  .wr_en(!f2a_full && ihit),  // input wire wr_en
  .rd_en(!a2d_full),  // input wire rd_en
  .dout({ia_rid,aip,airi}),    // output wire [511 : 0] dout
  .full(f2a_full),    // output wire full
  .empty(),  		// output wire empty
  .valid(f2a_v)  // output wire valid
);

// Instruction align
always @*
 	if (f2a_v) begin
	  case(aip[5:0])
	  6'h00:	a2d_ir <= airi[63:0];
	  6'h08:	a2d_ir <= airi[127:64];
	  6'h10:	a2d_ir <= airi[191:128];
	  6'h18:	a2d_ir <= airi[255:192];
	  6'h20:	a2d_ir <= airi[319:256];
	  6'h28:	a2d_ir <= airi[383:320];
	  6'h30:	a2d_ir <= airi[447:384];
	  6'h38:	a2d_ir <= airi[511:448];
	  default:	a2d_ir <= NOP_INSN;		// instruction alignment fault
		endcase
		a2d_ip <= aip;
		a2d_rid <= ai_rid;
	end
	else begin
		a2d_ip <= RSTIP;
		a2d_ir <= NOP_INSN;
		a2d_rid <= ai_rid;
	end
	

a2d_fifo ua2d
(
  .clk(clk_g),      // input wire clk
  .srst(srst),    // input wire srst
  .din({a2d_rid,a2d_ip,a2d_ir}),      // input wire [95 : 0] din
  .wr_en(!a2d_full),	// input wire wr_en
  .rd_en(!d2r_full),  // input wire rd_en
  .dout({dc_rid,dip,dir}),    // output wire [95 : 0] dout
  .full(a2d_full),    // output wire full
  .empty(),  		// output wire empty
  .valid(a2d_v)  // output wire valid
);

// Decode
always @*
	begin
		decbuf.rid <= dc_rid;
		decbuf.ii <= TRUE;
		case(dir[7:0])
		R3:
			case(dir[57:50])
			SLL:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.ii <= FALSE; end
			default:	;
			endcase
		ADDI,SUBFI:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{dir[19]}},dir[19:0]}; decbuf.ii <= FALSE; end
		ANDI:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{1'b1}},dir[19:0]}; decbuf.ii <= FALSE; end
		ORI:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{1'b0}},dir[19:0]}; decbuf.ii <= FALSE; end
		XORI:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{1'b0}},dir[19:0]}; decbuf.ii <= FALSE; end
		EXT,EXTU:		begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.ii <= FALSE; end
		SEQI,SNEI:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{dir[19]}},dir[19:0]}; decbuf.ii <= FALSE; end
		SLTI,SGTI:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{dir[19]}},dir[19:0]}; decbuf.ii <= FALSE; end
		SLTUI,SGTUI:	begin decbuf.Rt <= dir[31:26]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{1'b0}},dir[19:0]}; decbuf.ii <= FALSE; end
		JAL:
			begin
				decbuf.ii <= FALSE;
				decbuf.Rt <= dir[13:8];
				case(dir[21:16])
				6'd0:		dcRedirectIp <= {{24{dir[63]}},dir[63:28]};
				6'd63:	dcRedirectIp <= dip + {{24{dir[63]}},dir[63:28]};
				default:	;
				endcase
			end
		BEQ,BNE,BLT,BGE,BLTU,BGEU:	begin	decbuf.ii <= FALSE; decbuf.Rt <= dir[13:8]; decbuf.rfwr <= TRUE; debuf.imm <= {{43{dir[63]}},dir[63:50],dir[43:40],3'd0}; end
		LDB,LDW,LDT,LDO:	begin decbuf.Rt <= dir[29:24]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{dir[19]}},dir[19:0]}; decbuf.ii <= FALSE; end
		STB,STW,STT,STO:	begin decbuf.Rt <= 6'd0; decbuf.Rc <= dir[29:24]; decbuf.rfwr <= TRUE; decbuf.imm <= {{44{dir[19]}},dir[19:0]}; decbuf.ii <= FALSE; end
		default:
			begin
				decbuf.ii <= TRUE;
				decbuf.rfwr <= FALSE;
				decbuf.ir <= dir;
				decbuf.Rt <= 6'd0;
				decbuf.Ra <= dir[25:20];
				decbuf.Rb <= dir[19:14];
				decbuf.Rc <= dir[13:8];
				decbuf.Rd <= dir[7:2];
				decbuf.imm <= 64'd0;
			end
		endcase
	end

// Execute
always @*
	begin
		case(exbufi.ir[7:0])
		JAL:
			begin
				case(dir[21:16])
				6'd0:		;	// already done
				6'd63:	; // already done
				default:
					begin
						exRedirectIp <= 
					end
				endcase
			end
		endcase
	end

reg stallrf;

d2r_fifo ud2r
(
  .clk(clk_g),      // input wire clk
  .srst(srst),    // input wire srst
  .din(decbuf),      // input wire [134 : 0] din
  .wr_en(!d2r_full && a2d_v),	// input wire wr_en
  .rd_en(!r2x_full && !stallrf),  // input wire rd_en
  .dout(regbuf),    // output wire [134 : 0] dout
  .full(d2r_full),    // output wire full
  .empty(),  		// output wire empty
  .valid(d2r_v)  // output wire valid
);

// Register Fetch
always @*
begin
	exbufi.rid <= regbuf.rid;
	exbufi.ir <= regbuf.ir;
	exbufi.ia <= regbuf.Ra[7] ? {{57{regbuf.Ra[6]}},regbuf.Ra[6:0]} : regbuf.Ra[5:0]==6'd0 ? 64'd0 : regfile[regbuf.Ra];
	exbufi.ib <= regbuf.Rb[7] ? {{57{regbuf.Rb[6]}},regbuf.Rb[6:0]} : regbuf.Rb[5:0]==6'd0 ? 64'd0 : regfile[regbuf.Rb];
	exbufi.ic <= regbuf.Rc[7] ? {{57{regbuf.Rc[6]}},regbuf.Rc[6:0]} : regbuf.Rc[5:0]==6'd0 ? 64'd0 : regfile[regbuf.Rc];
	exbufi.id <= regbuf.Rd[7] ? {{57{regbuf.Rd[6]}},regbuf.Rd[6:0]} : regbuf.Rd[5:0]==6'd0 ? 64'd0 : regfile[regbuf.Rd];
	stallrf <= 	regfilestat[regbuf.Ra[5:0]] != 6'd0 ||
							regfilestat[regbuf.Rb[5:0]] != 6'd0 ||
							regfilestat[regbuf.Rc[5:0]] != 6'd0 ||
							regfilestat[regbuf.Rd[5:0]] != 6'd0
							;
end

r2x_fifo ur2x
(
  .clk(clk_g),      // input wire clk
  .srst(srst),    // input wire srst
  .din(exbufi),      // input wire [134 : 0] din
  .wr_en(!r2x_full && d2r_v),	// input wire wr_en
  .rd_en(!x2m_full),  // input wire rd_en
  .dout(exbufo),    // output wire [134 : 0] dout
  .full(r2x_full),    // output wire full
  .empty(),  		// output wire empty
  .valid(r2x_v)  // output wire valid
);

x2m_fifo ux2m
(
  .clk(clk_g),      // input wire clk
  .srst(srst),    // input wire srst
  .din(membufi),      // input wire [134 : 0] din
  .wr_en(!x2m_full && memfifo_wr),	// input wire wr_en
  .rd_en(mstate==MEMORY1),  // input wire rd_en
  .dout(membufo),    // output wire [134 : 0] dout
  .full(x2m_full),    // output wire full
  .empty(),  		// output wire empty
  .valid(x2m_v)  // output wire valid
);

dc2if_redirect_fifo udc2if
(
  .clk(clk_g),      // input wire clk
  .srst(srst),    // input wire srst
  .din(dcRedirectIp),      // input wire [31 : 0] din
  .wr_en(dc2if_wr),	// input wire wr_en
  .rd_en(dc2if_redirect_rd),  // input wire rd_en
  .dout(dc_redirect_ip),    // output wire [31 : 0] dout
  .full(),    	// output wire full
  .empty(),  		// output wire empty
  .valid(dc2if_redirect_v)  // output wire valid
);

ex2if_redirect_fifo uex2if
(
  .clk(clk_g),      // input wire clk
  .srst(srst),    // input wire srst
  .din(exRedirectIp),      // input wire [31 : 0] din
  .wr_en(ex2if_wr),	// input wire wr_en
  .rd_en(ex2if_redirect_rd),  // input wire rd_en
  .dout(ex_redirect_ip),    // output wire [31 : 0] dout
  .full(),    	// output wire full
  .empty(),  		// output wire empty
  .valid(ex2if_redirect_v)  // output wire valid
);


always @(posedge clk_g)
if (rst) begin
	omode <= 3'd4;
	fEpoch <= 6'd0;
end
else begin
	ex2if_redirect_rd <= FALSE;
	dc2if_redirect_rd <= FALSE;
	dc2if_wr <= FALSE;
	ex2if_wr <= FALSE;
	exfifo_rd <= FALSE;
	memfifo_wr <= FALSE;

	// Instruction fetch
	ifEpoch <= fEpoch;
  case(1'b1)
  ihit1a: iri <= icache0[ip[pL1msb:5]];
  ihit1b: iri <= icache1[ip[pL1msb:5]];
  ihit1c: iri <= icache2[ip[pL1msb:5]];
  ihit1d: iri <= icache3[ip[pL1msb:5]];
  default:  iri <= {12{NOP_INSN}};
  endcase
  if (ex2if_redirect_v) begin
  	fEpoch <= fEpoch + 2'd1;
		ip <= ex_redirect_ip;
		ex2if_redirect_rd <= TRUE;
	end
	else if (dc2if_redirect_v) begin
  	fEpoch <= fEpoch + 2'd1;
		ip <= dc_redirect_ip;
		dc2if_redirect_rd <= TRUE;
	end
	else if (!f2a_full && ihit && rob[rob_tail].v == INV) begin
		// Increment ip
		ip <= ip + 4'd8;
	end
	if (rob[rob_tail].v == INV) begin
		if_rid <= rob_tail;
		rob[rob_tail].v <= VAL;
		rob_tail <= rob_tail + 2'd1;
	end

	// Decode
	case(dir[7:0])
	JAL:
		begin
			case(dir[21:16])
			6'd0:		begin dcEpoch <= dcEpoch + 2'd1; dc2if_wr <= TRUE; end
			6'd63:	begin dcEpoch <= dcEpoch + 2'd1; dc2if_wr <= TRUE; end
			default:	;
			endcase
		end
	endcase

	// Register Fetch
	if (regbuf.Rt != 6'd0 && !((regbuf.Rt == rob[rob_head].Rt) && rob[rob_head].v))
		regfilestat[regbuf.Rt] <= regfilestat[regbuf.Rt] + 2'd1;

	// Execute
	if (exbufi.epoch==eEpoch) begin
		case(exbufi.ir[7:0])
		ADDI:	begin rob[exbufi.rid].res <= exbufi.ia + exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		SUBFI:begin rob[exbufi.rid].res <= exbufi.imm - exbufi.ia; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		ANDI:	begin rob[exbufi.rid].res <= exbufi.ia & exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		ORI:	begin rob[exbufi.rid].res <= exbufi.ia | exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		XORI:	begin rob[exbufi.rid].res <= exbufi.ia ^ exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		SEQI:	begin rob[exbufi.rid].res <= exbufi.ia == exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		SNEI:	begin rob[exbufi.rid].res <= exbufi.ia != exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		SLTI:	begin rob[exbufi.rid].res <= $signed(exbufi.ia) < $signed(exbufi.imm); rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		SGTI:	begin rob[exbufi.rid].res <= $signed(exbufi.ia) > $signed(exbufi.imm); rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		SLTUI:	begin rob[exbufi.rid].res <= exbufi.ia < exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		SGTUI:	begin rob[exbufi.rid].res <= exbufi.ia > exbufi.imm; rob[exbufi.rid].cmt <= TRUE; exfifo_rd <= TRUE; end
		JAL:
			begin
				rob[exbufi.rid].res <= exbufi.ip + {exbufi.ir[27:24],3'd0} + 4'd8;
				case(dir[21:16])
				6'd0:		;	// already done
				6'd63:	; // already done
				default:	begin eEpoch <= eEpoch + 2'd1; ex2if_wr <= TRUE; end
				endcase
			end
		LDB,LDW,LDT,LDO,
		STB,STW,STT,STO:
			begin
				membufi.rid <= exbufi.rid;
				membufi.ir <= exbufi.ir;
				membufi.ia <= exbufi.ia;
				membufi.ib <= exbufi.ib;
				membufi.imm <= exbufi.imm;
				memfifo_wr <= TRUE;
				exfifo_rd <= TRUE;
			end
		default:	
		endcase
	end

	// Memory
	case(mstate)
MEMORY1:
	if (ihit) begin
		if (x2m_v)
			mgoto (MEMORY1c);
	end
	else begin
    icnt <= 4'd0;
`ifdef RTF64_TLB
    mgoto (IFETCH2a);
`else
    mgoto (IFETCH3);
`endif
  end
IFETCH2a:
  begin
  	iaccess <= FALSE;
    mgoto(IFETCH3);
  end
IFETCH3:
  begin
 		xlaten <= FALSE;
	  begin
  		mgoto (IFETCH3a);
`ifdef RTF64_TLB  		
  		if (tlbmiss) begin
			  tException(32'h80000004,ip);
			  badaddr[3'd4] <= ip;
			  vpa_o <= FALSE;
			end
			else
`endif			
			begin
			  // First time in, set to miss address, after that increment
			  icaccess <= TRUE;
`ifdef CPU_B128
        if (!icaccess)
          iadr <= {adr_o[AWID-1:5],5'h0};
        else
          iadr <= {iadr[AWID-1:4],4'h0} + 5'h10;
`endif
`ifdef CPU_B64
        if (!icaccess)
          iadr <= {adr_o[AWID-1:5],5'h0}
        else
          iadr <= {iadr[AWID-1:3],3'h0} + 4'h8;
`endif
`ifdef CPU_B32
        if (!icaccess)
          iadr <= {adr_o[AWID-1:5],5'h0};
        else
          iadr <= {iadr[AWID-1:2],2'h0} + 3'h4;
`endif			
      end
	  end
  end
IFETCH3a:
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
		tPMAPC(); // must have adr_o valid for PMA
  end
IFETCH5:
  begin
`ifdef CPU_B128
    if (icnt[3:2]==2'd3)
      ictag[iadr[pL1msb:6]] <= iadr[AWID-1:0] & ~64'h10;
`endif
`ifdef CPU_B64
    if (icnt[3:1]==3'd7)
      ictag[iadr[pL1msb:6]] <= iadr[AWID-1:0] & ~64'h10;
`endif
`ifdef CPU_B32
    if (icnt[3:0]==4'd15)
      ictag[iadr[pL1msb:6]] <= iadr[AWID-1:0] & ~64'h10;
`endif
    icvalid[iadr[pL1msb:6]] <= 1'b1;
    icache[iadr[pL1msb:6]] <= ici;
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
    if (icnt[3:2]==2'd3)
`endif
`ifdef CPU_B64
    if (icnt[3:1]==3'd7)
`endif
`ifdef CPU_B32
    if (icnt[3:0]==4'd15)
`endif
			mgoto (MEMORY1);
		else
      mgoto (IFETCH3);
    end
  end

MEMORY1c:
  begin
    if (membufo.ir[7:0]==LINK) begin
    	rob[membufo.rid].Rt <= 6'd62;
    	rob[membufo.rid].res <= membufo.ia + membufo.imm;
    end
`ifdef RTF64_TLB
    mgoto (MEMORY1a);
`else
    mgoto (MEMORY2);
`endif
    if (opcode==LEA) begin
      rob[membufi.rid].res <= ea;
      rob[membufi.rid].cmt <= TRUE;
      mgoto (MEMORY1);
    end
    else begin
      tEA();
      xlaten <= TRUE;
`ifdef CPU_B128
      sel <= selx << ea[3:0];
      dat <= membufo.dato << {ea[3:0],3'b0};
`endif
`ifdef CPU_B64
      sel <= selx << ea[2:0];
      dat <= membufo.dato << {ea[2:0],3'b0};
`endif
`ifdef CPU_B32
      sel <= selx << ea[1:0];
      dat <= membufo.dato << {ea[1:0],3'b0};
`endif
      ealow <= ea[7:0];
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
    mgoto (MEMORY3);
    if (d_cache)
      tPMAEA();
  end
MEMORY3:
  begin
    xlaten <= FALSE;
    mgoto (MEMORY4);
`ifdef RTF64_TLB
		if (tlbmiss) begin
		  tException(32'h80000004,ipc);
  	  badaddr[3'd5] <= ea;
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
      case(opcode)
      STB,STW,STT,STO,STOC,STPTR,//`FSTO,`PSTO,
        we_o <= HIGH;
      default:  ;
      endcase
    end
  end
MEMORY4:
  begin
    if (d_cache) begin
      icvalid[adr_o[pL1msb:6]] <= 1'b0;
      mgoto (MEMORY1);
    end
    else if (acki) begin
      mgoto (MEMORY5);
      stb_o <= LOW;
      dati <= dat_i;
      if (sel[`SELH]==1'h0) begin
        cyc_o <= LOW;
        we_o <= LOW;
        sel_o <= 1'h0;
      end
    end
  end
MEMORY5:
  if (~acki) begin
    if (|sel[`SELH])
      mgoto (MEMORY6);
    else begin
      case(opcode)
      STB,STW,STT,STO,STOC:,//`FSTO,`PSTO,
      	begin
		    	rob[membufo.rid].cmt <= TRUE;
        	mgoto (MEMORY1);
        end
      STPTR:
      	if (ea==32'd0) begin
		    	rob[membufo.rid].cmt <= TRUE;
      		mgoto (MEMORY1);
      	end
      	else begin
      		shr_ma <= TRUE;
      		membufo.dato <= 64'd0;
      		mgoto (MEMORY1c);
      	end
      default:
        mgoto (DATA_ALIGN);
      endcase
    end
  end
MEMORY6:
  begin
`ifdef RTF64_TLB
    mgoto (MEMORY6a);
`else
    mgoto (MEMORY7);
`endif
    xlaten <= TRUE;
    tEA();
  end
MEMORY6a:
  mgoto (MEMORY7);
MEMORY7:
  mgoto (MEMORY_KEYCHK2);
MEMORY_KEYCHK2:
  begin
    mgoto (MEMORY8);
    tPMAEA();
  end
MEMORY8:
  begin
    xlaten <= FALSE;
    mgoto (MEMORY9);
`ifdef RTF64_TLB    
		if (tlbmiss) begin
		  tException(32'h80000004,ipc);
  	  badaddr[3'd4] <= ea;
		  cyc_o <= LOW;
		  stb_o <= LOW;
		  we_o <= 1'b0;
		  sel_o <= 1'd0;
	  end
		else
`endif
		begin
      stb_o <= HIGH;
      sel_o <= sel[`SELH];
      dat_o <= dat[`DATH];
    end
  end
MEMORY9:
  if (acki) begin
    mgoto (MEMORY10);
    stb_o <= LOW;
    dati[`DATH] <= dat_i;
`ifdef CPU_B128
    cyc_o <= LOW;
    we_o <= LOW;
    sel_o <= 1'h0;
`endif
`ifdef CPU_B64
    cyc_o <= LOW;
    we_o <= LOW;
    sel_o <= 1'h0;
`endif
`ifdef CPU_B32
    if (sel[11:8]==4'h0) begin
      cyc_o <= LOW;
      we_o <= LOW;
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
      case(opcode)
      STB,STW,STT,STO,STOC://,`FSTO,`PSTO,
      	begin
		    	rob[membufo.rid].cmt <= TRUE;
        	mgoto (MEMORY1);
        end
      STPTR:
      	if (ea==32'd0) begin
		    	rob[membufo.rid].cmt <= TRUE;
      		goto (MEMORY1);
      	end
      	else begin
      		shr_ma <= TRUE;
      		membufo.dato <= 64'd0;
      		mgoto (MEMORY1c);
      	end
      default:
        mgoto (DATA_ALIGN);
      endcase
    end
  end
MEMORY11:
  begin
`ifdef RTF64_TLB
    mgoto (MEMORY11a);
`else
    mgoto (MEMORY12);
`endif
    xlaten <= TRUE;
    tEA();
  end
MEMORY11a:
  mgoto (MEMORY12);
MEMORY12:
  mgoto (MEMORY_KEYCHK3);
MEMORY_KEYCHK3:
  begin
    mgoto (MEMORY13);
    tPMAEA();
  end
MEMORY13:
  begin
    xlaten <= FALSE;
    mgoto (MEMORY14);
`ifdef RTF64_TLB    
		if (tlbmiss) begin
		  tException(32'h80000004,ipc);
  	  badaddr[3'd4] <= ea;
		  cyc_o <= LOW;
		  stb_o <= LOW;
		  we_o <= 1'b0;
		  sel_o <= 1'd0;
	  end
		else
`endif		
		begin
      stb_o <= HIGH;
      sel_o <= sel[11:8];
      dat_o <= dat[95:64];
    end
  end
MEMORY14:
  if (acki) begin
    mgoto (MEMORY15);
    cyc_o <= LOW;
    stb_o <= LOW;
    we_o <= LOW;
    sel_o <= 4'h0;
    dati[95:64] <= dat_i;
  end
MEMORY15:
  if (~acki) begin
    case(opcode)
    STB,STW,STT,STO,STOC://,`FSTO,`PSTO,
    	begin
	    	rob[membufo.rid].cmt <= TRUE;
      	mgoto (MEMORY1);
    	end
    STPTR:
    	if (ea==32'd0) begin
    	 	rob[membufo.rid].cmt <= TRUE;
    		goto (MEMORY1);
    	end
    	else begin
    		shr_ma <= TRUE;
    		membufo.dato <= 64'd0;
    		goto (MEMORY1c);
    	end
    default:
      mgoto (DATA_ALIGN);
    endcase
  end
DATA_ALIGN:
  begin
    mgoto (MEMORY1);
    rob[membufo.rid].cmt <= TRUE;
    case(membufo.ir[7:0])
    `LDB:   rob[membufo.rid].res <= {{56{datis[7]}},datis[7:0]};
    `LDBU: 	rob[membufo.rid].res <= {{56{1'b0}},datis[7:0]};
    `LDW:   rob[membufo.rid].res <= {{48{datis[15]}},datis[15:0]};
    `LDWU: 	rob[membufo.rid].res <= {{48{1'b0}},datis[15:0]};
    `LDT:   rob[membufo.rid].res <= {{32{datis[31]}},datis[31:0]};
    `LDTU:  rob[membufo.rid].res <= {{32{1'b0}},datis[31:0]};
    `LDO:   rob[membufo.rid].res <= datis[63:0];
	  //LDOR: res <= datis[63:0];
    //`FLDO,`PLDO:  res <= datis[63:0];
    //`RTS:    pc <= datis[63:0] + {ir[12:9],2'b00};
    //`RTX:    pc <= datis[63:0];
    //`UNLINK:  begin res <= datis[63:0]; Rd <= 5'd30; end
    //`POP:   begin crres <= datis[31:0]; rares <= datis[AWID-1:0]; res <= datis[63:0]; end
    default:  ;
    endcase
  end
	endcase

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Writeback
	//
	// Writeback looks only at the reorder buffer to determine which register
	// to update. The reorder buffer acts like a fifo between the other stages
	// and the writeback stage.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	// Update register scorebaord
	if (rob[rob_head].Rt != 6'd0 && !(regbuf.Rt == rob[rob_head].Rt) && rob[rob_head].v && rob[rob_head].cmt)
		regfilestate[rob[rob_head].Rt] <= regfilestate[rob[rob_head].Rt] - 6'd1;
	if (rob[rob_head].v & rob[rob_head].cmt) begin
		rob[rob_head].v <= INV;
		rob[rob_head].cmt <= FALSE;
		rob_head <= rob_head + 2'd1;
		if (rob[rob_head].rfwr)
			regfile[rob[rob_head].Rt] <= rob[rob_head].res;
	end

end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

task tException;
input [31:0] cse;
input [AWID-1:0] tpc;
begin
	ip <= tvec[3'd4] + {omode,6'h00};
	eip <= tpc;
	pmStack <= {pmStack[27:0],3'b100,1'b0};
	cause[3'd4] <= cse;
//	instret <= instret + 2'd1;
//  rprv <= 5'h0;
  $display("**********************");
  $display("** Exception: %d    **", cse);
  $display("**********************");
end
endtask

task mgoto;
input [5:0] nst;
begin
	mstate <= nst;
end
endtask

endmodule
