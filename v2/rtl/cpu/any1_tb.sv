import any1_pkg::*;

`define ADD1_INSN	{12'h001,6'h04,6'h04,ADDI}
`define ADD2_INSN	{32'h002,6'h07,6'h06,ADDI}
`define ADD3_INSN	{32'h002,6'h47,6'h46,ADDI}
`define STO_INSN	{4'h1,12'h000,4'h3,3'h0,1'b0,8'h00,8'h00,8'h00,8'h8F,8'h70}
`define BNE_INSN {6'h3F,6'h07,6'h04,6'h00,BNE}

module any1_tb();
reg clk;
reg rst;

wire vpa_o;
wire cyc_o;
wire stb_o;
reg ack_i;
wire we_o;
wire [15:0] sel_o;
wire [31:0] adr_o;
reg [127:0] dat_i;
wire [127:0] dat_o;

reg [63:0] mem [0:1023];

initial begin
	clk = 1'b0;
	#20 rst = 1'b1;
	#200 rst = 1'b0;
end

always #5 clk <= ~clk;

always @(posedge clk)
if (we_o && adr_o[31:13]==20'd0)
	mem[adr_o[12:3]] <= dat_o;

any1oo ua1
(
	.rst_i(rst),
	.clk_i(clk),
	.wc_clk_i(clk),
	.nmi_i(1'b0),
	.irq_i(1'b0),
	.cause_i(8'h00),
	.vpa_o(vpa_o),
	.cyc_o(cyc_o),
	.stb_o(stb_o),
	.ack_i(ack_i),
	.we_o(we_o),
	.sel_o(sel_o),
	.adr_o(adr_o),
	.dat_i(dat_i),
	.dat_o(dat_o)
);

always @(posedge clk)
begin
	ack_i <= cyc_o;
	if (adr_o[31:24]==8'hFF)
		case(adr_o[5:2])
		3'd0:	dat_i <= {`ADD1_INSN,{3{NOP_INSN}}};
		3'd1:	dat_i <= {4{`ADD2_INSN}};
		3'd2: dat_i <= {4{`STO_INSN}};
		3'd3:	dat_i <= {4{`ADD3_INSN}};
		3'd4:	dat_i <= {{3{NOP_INSN}},`BNE_INSN};
		default:	dat_i <= {4{NOP_INSN}};
		endcase
	else
		dat_i <= 128'd0;
end

endmodule