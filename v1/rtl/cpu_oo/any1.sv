// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1.sv
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//`define SIM   1'b1

`include "../inc/any1-defines.sv"
`include "../inc/any1-config.sv"

`ifdef CPU_B128
`define SELH    31:16
`define DATH    255:128
`endif
`ifdef CPU_B64
`define SELH    15:8
`define DATH    127:64
`endif
`ifdef CPU_B32
`define SELH    7:4
`define DATH    63:32
`endif

`include "../fpu/fpConfig.sv"

module any1(hartid_i, rst_i, clk_i, wc_clk_i, nmi_i, irq_i, cause_i, vpa_o, cyc_o, stb_o, ack_i, sel_o, we_o, adr_o, dat_i, dat_o, sr_o, cr_o, rb_i);
parameter WID = 64;
parameter AWID = 32;
parameter FPWID = `FPWID;
parameter RSTPC = 64'hFFFFFFFFFFFC0100;
parameter pL1CacheLines = 128;
localparam pL1msb = $clog2(pL1CacheLines-1)-1+5;
input [7:0] hartid_i;
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
`ifdef CPU_B128
input [127:0] dat_i;
output reg [127:0] dat_o;
`endif
`ifdef CPU_B64
input [63:0] dat_i;
output reg [63:0] dat_o;
`endif
`ifdef CPU_B32
input [31:0] dat_i;
output reg [31:0] dat_o;
`endif
output reg sr_o;
output reg cr_o;
input rb_i;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
parameter LOW = 1'b0;
parameter HIGH = 1'b1;

integer n;
reg [5:0] state;
parameter IFETCH1 = 6'd1;
parameter IFETCH2 = 6'd2;
parameter IFETCH3 = 6'd3;
parameter IFETCH4 = 6'd4;
parameter DECODE = 6'd5;
parameter REGFETCH1 = 6'd6;
parameter REGFETCH2 = 6'd7;
parameter EXECUTE = 6'd8;
parameter WRITEBACK = 6'd9;
parameter MEMORY1 = 6'd11;
parameter MEMORY2 = 6'd12;
parameter MEMORY3 = 6'd13;
parameter MEMORY4 = 6'd14;
parameter MEMORY5 = 6'd15;
parameter MEMORY6 = 6'd16;
parameter MEMORY7 = 6'd17;
parameter MEMORY8 = 6'd18;
parameter MEMORY9 = 6'd19;
parameter MEMORY10 = 6'd20;
parameter MEMORY11 = 6'd21;
parameter MEMORY12 = 6'd22;
parameter MEMORY13 = 6'd23;
parameter MEMORY14 = 6'd24;
parameter MEMORY15 = 6'd25;
parameter MUL1 = 6'd26;
parameter MUL2 = 6'd27;
parameter PAM	 = 6'd28;
parameter TMO = 6'd29;
parameter PAGEMAPA = 6'd30;
parameter CSR1 = 6'd31;
parameter CSR2 = 6'd32;
parameter DATA_ALIGN = 6'd33;
parameter MEMORY_KEYCHK1 = 6'd34;
parameter MEMORY_KEYCHK2 = 6'd35;
parameter MEMORY_KEYCHK3 = 6'd36;
parameter FLOAT = 6'd37;
parameter INSTRUCTION_ALIGN = 6'd38;
parameter IFETCH5 = 6'd39;
parameter MEMORY1a = 6'd40;
parameter MEMORY6a = 6'd41;
parameter MEMORY11a = 6'd42;
parameter IFETCH2a = 6'd43;
parameter REGFETCH3 = 6'd44;
parameter EXPAND_CI = 6'd45;
parameter IFETCH3a = 6'd46;

`include "../fpu/fpSize.sv"
reg [1:0] u2_a, u2_b, u2_c, u2_d;

reg rfwr_a, rfwr_b, rfwr_c, rfwr_d;
reg [9:0] Rs1_a, Rs1_b, Rs1_c, Rs1_d;
reg [9:0] Rs2_a, Rs2_b, Rs2_c, Rs2_d;
reg [9:0] Rs3_a, Rs3_b, Rs3_c, Rs3_d;
reg [9:0] Rs4_a, Rs4_b, Rs4_c, Rs4_d;
reg [9:0] Rd_a, Rd_b, Rd_c, Rd_d;
reg [80:0] res_a, res_b, res_c, res_d;
wire [79:0] rfoRs1_a, rfoRs1_b, rfoRs1_c, rfoRs1_d;
wire [79:0] rfoRs2_a, rfoRs2_b, rfoRs2_c, rfoRs2_d;
wire [79:0] rfoRs3_a, rfoRs3_b, rfoRs3_c, rfoRs3_d;
wire [79:0] rfoRs4_a, rfoRs4_b, rfoRs4_c, rfoRs4_d;

any1_regfile u1_a
(
	.clk(clk_g),
	.wr(rfwr_a),
	.wa(Rd_a),
	.i(res_a[63:0]),
	.ra0(Rs1_a),
	.ra1(Rs2_a),
	.ra2(Rs3_a),
	.ra3(Rs4_a),
	.o0(rfoRs1_a),
	.o1(rfoRs2_a),
	.o2(rfoRs3_a),
	.o3(rfoRs4_a)
);

any1_regfile u1_b
(
	.clk(clk_g),
	.wr(rfwr_b),
	.wa(Rd_a),
	.i(res_b[63:0]),
	.ra0(Rs1_b),
	.ra1(Rs2_b),
	.ra2(Rs3_b),
	.ra3(Rs4_b),
	.o0(rfoRs1_b),
	.o1(rfoRs2_b),
	.o2(rfoRs3_b),
	.o3(rfoRs4_b)
);

any1_regfile u1_c
(
	.clk(clk_g),
	.wr(rfwr_c),
	.wa(Rd_c),
	.i(res_c[63:0]),
	.ra0(Rs1_c),
	.ra1(Rs2_c),
	.ra2(Rs3_c),
	.ra3(Rs4_c),
	.o0(rfoRs1_c),
	.o1(rfoRs2_c),
	.o2(rfoRs3_c),
	.o3(rfoRs4_c)
);

any1_regfile u1_d
(
	.clk(clk_g),
	.wr(rfwr_d),
	.wa(Rd_d),
	.i(res_d[63:0]),
	.ra0(Rs1_d),
	.ra1(Rs2_d),
	.ra2(Rs3_d),
	.ra3(Rs4_d),
	.o0(rfoRs1_d),
	.o1(rfoRs2_d),
	.o2(rfoRs3_d),
	.o3(rfoRs4_d)
);

reg [7:0] vl;

// CSRs
reg [7:0] cause [0:7];
reg [AWID-1:0] tvec [0:7];
reg [AWID-1:0] badaddr [0:7];

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

// Rd,Rs1,Rs2 or Rs3 is q vector register
wire is_vector_inst = dir[15:14]==2'b01 || dir[23:22]==2'b01 || dir[31:30]==2'b01 || dir[39:38]==2'b01;
wire is_immediate_op_a;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Evaluate branch condition
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
wire takb;
reg [63:0] brdat;
any1_eval_branch ueb1
(
  .inst(xir),
  .a(ia_a),
  .b(ib_b),
  .takb(takb_a)
);

always @(posedge clk_g)
if (rst_i) begin
	state <= IFETCH1;

case (state)
// It takes two clocks to read the pagemap ram, this is after the linear
// address is set, which also takes a clock cycle.
IFETCH1:
  begin
`ifdef SIM
    $display("Fetched: %d", instfetch);
    $display("Ticks: %d", tick);
/*
    for (n = 0; n < 32; n = n + 4) begin
      $display("%d: %h  %d: %h  %d: %h  %d: %h",
         n[4:0], iregfile[n],
         n[4:0]+2'd1, iregfile[n+1],
         n[4:0]+2'd2, iregfile[n+2],
         n[4:0]+2'd3, iregfile[n+3]
      );
    end
*/
`endif    
	end

DECODE:
  begin
    pc <= pc + 4'd8;
    $display("IP: %h", ipc);
    $display("Fetch: %h", dir);
    goto (REGFETCH1);
    Rd_a <= 10'd0;
    Rd_b <= 10'd0;
    Rd_c <= 10'd0;
    Rd_d <= 10'd0;
    if (is_vector_inst) begin
    	Rs1_a <= {4'd0,dir[21:16]};
    	Rs2_a <= {4'd0,dir[29:24]};
    	Rs3_a <= {4'd0,dir[37:32]};
    	Rs4_a <= {4'd0,dir[55:50]};
    	Rs1_b <= {4'd0,dir[21:16]};
    	Rs2_b <= {4'd0,dir[29:24]};
    	Rs3_b <= {4'd0,dir[37:32]};
    	Rs4_b <= {4'd0,dir[55:50]};
    	Rs1_c <= {4'd0,dir[21:16]};
    	Rs2_c <= {4'd0,dir[29:24]};
    	Rs3_c <= {4'd0,dir[37:32]};
    	Rs4_c <= {4'd0,dir[55:50]};
    	Rs1_d <= {4'd0,dir[21:16]};
    	Rs2_d <= {4'd0,dir[29:24]};
    	Rs3_d <= {4'd0,dir[37:32]};
    	Rs4_d <= {4'd0,dir[55:50]};
    end
    else begin
    	Rs1_a <= {4'd15,dir[21:16]};
    	Rs2_a <= {4'd15,dir[29:24]};
    	Rs3_a <= {4'd15,dir[37:32]};
    	Rs4_a <= {4'd15,dir[55:50]};
    	Rs1_b <= {4'd15,dir[21:16]};
    	Rs2_b <= {4'd15,dir[29:24]};
    	Rs3_b <= {4'd15,dir[37:32]};
    	Rs4_b <= {4'd15,dir[55:50]};
    	Rs1_c <= {4'd15,dir[21:16]};
    	Rs2_c <= {4'd15,dir[29:24]};
    	Rs3_c <= {4'd15,dir[37:32]};
    	Rs4_c <= {4'd15,dir[55:50]};
    	Rs1_d <= {4'd15,dir[21:16]};
    	Rs2_d <= {4'd15,dir[29:24]};
    	Rs3_d <= {4'd15,dir[37:32]};
    	Rs4_d <= {4'd15,dir[55:50]};
  	end
    casez(opcode)
    `OSR2:
		endcase
	end

// Need a state to read Rd from block ram.
REGFETCH1:
  begin
    if (d_jsr)
      id <= ip; // pc is addressing next instruction
    else
      id <= 64'd0;

    if (is_immediate_op_a)
    	u2_a <= rir_a[29:28];
    else
    	u2_a <= rir_a[49:48];

    if (is_immediate_op_b)
    	u2_b <= rir_b[29:28];
    else
    	u2_b <= rir_b[49:48];

    if (is_immediate_op_c)
    	u2_c <= rir_c[29:28];
    else
    	u2_c <= rir_c[49:48];

    if (is_immediate_op_d)
    	u2_d <= rir_d[29:28];
    else
    	u2_d <= rir_d[49:48];

    goto (REGFETCH2);
  end
REGFETCH2:
  begin
    case(opcode_a)
    `JAL:
    	if (Rs1_a=={4'd15,6'd63);
      	ip <= ip + {24{rir_a[63]}},rir_a[63:28],4'd0};
    default:  ;
    endcase
    goto (REGFETCH3);
  end
REGFETCH3:
  begin
    goto (EXECUTE);
    $display("RF: irfoRs1:%h Rs1=%d",rfoRs1_a, Rs1_a);
    case(u2_a)
    2'd0:	ia_a <= rir_a[23]==1'b1 ? {{57{rir_a[22]}},rir_a[22:16]} : rfoRs1_a;
    2'd1:	ia_a <= rir_a[23]==1'b1 ? {{57{rir_a[22]}},rir_a[22:16]} : rfoRs1_a;
    2'd2:	ia_a <= rir_a[23]==1'b1 ? {{57{rir_a[22]}},rir_a[22:16]} : rfoRs1_a;
    2'd3:	ia_a <= rir_a[23]==1'b1 ? {{57{rir_a[22]}},rir_a[22:16]} : rfoRs1_a;
  	endcase
  	case(u2_a)
  	2'd0:	ib_a <= rir_a[31]==1'b1 ? {{57{rir_a[30]}},rir_a[30:24]} : rfoRs2_a;
  	2'd1:	ib_a <= rir_a[31]==1'b1 ? {{57{rir_a[30]}},rir_a[30:24]} : rfoRs2_a;
  	2'd2:	ib_a <= rir_a[31]==1'b1 ? {{57{rir_a[30]}},rir_a[30:24]} : rfoRs2_a;
  	2'd3:	ib_a <= rir_a[31]==1'b1 ? {{57{rir_a[30]}},rir_a[30:24]} : rfoRs2_a;
  	endcase
  	case(u2_a)
  	2'd0:	ic_a <= rir_a[39]==1'b1 ? {{57{rir_a[38]}},rir_a[38:32]} : rfoRs3_a;
  	2'd1:	ic_a <= rir_a[39]==1'b1 ? {{57{rir_a[38]}},rir_a[38:32]} : rfoRs3_a;
  	2'd2:	ic_a <= rir_a[39]==1'b1 ? {{57{rir_a[38]}},rir_a[38:32]} : rfoRs3_a;
  	2'd3:	ic_a <= rir_a[39]==1'b1 ? {{57{rir_a[38]}},rir_a[38:32]} : rfoRs3_a;
  	endcase
  	case(u2_a)
  	2'd0:	id_a <= rir_a[57]==1'b1 ? {{57{rir_a[56]}},rir_a[56:50]} : rfoRs4_a;
  	2'd1:	id_a <= rir_a[57]==1'b1 ? {{57{rir_a[56]}},rir_a[56:50]} : rfoRs4_a;
  	2'd2:	id_a <= rir_a[57]==1'b1 ? {{57{rir_a[56]}},rir_a[56:50]} : rfoRs4_a;
  	2'd3:	id_a <= rir_a[57]==1'b1 ? {{57{rir_a[56]}},rir_a[56:50]} : rfoRs4_a;
  	endcase

    case(u2_b)
    2'd0:	ia_b <= rir_b[23]==1'b1 ? {{57{rir_b[22]}},rir_b[22:16]} : rfoRs1_b;
    2'd1:	ia_b <= rir_b[23]==1'b1 ? {{57{rir_b[22]}},rir_b[22:16]} : rfoRs1_b;
    2'd2:	ia_b <= rir_b[23]==1'b1 ? {{57{rir_b[22]}},rir_b[22:16]} : rfoRs1_b;
    2'd3:	ia_b <= rir_b[23]==1'b1 ? {{57{rir_b[22]}},rir_b[22:16]} : rfoRs1_b;
  	endcase
    ia_b <= rfoRs1_b;
    ia_c <= rfoRs1_c;
    ia_d <= rfoRs1_d;
    ib_a <= rfoRs2_a;
    ib_b <= rfoRs2_b;
    ib_c <= rfoRs2_c;
    ib_d <= rfoRs2_d;
    ic_a <= rfoRs3_a;
    ic_b <= rfoRs3_b;
    ic_c <= rfoRs3_c;
    ic_d <= rfoRs3_d;
    id_a <= rfoRs4_a;
    id_b <= rfoRs4_b;
    id_c <= rfoRs4_c;
    id_d <= rfoRs4_d;
  end

endmodule
