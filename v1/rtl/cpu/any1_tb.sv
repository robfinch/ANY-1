import any1_pkg::*;

`define ADD1_INSN	{4'h1,32'h00000001,4'h00,8'h04,8'h04,ADDI}
`define ADD2_INSN	{4'h1,32'h00000002,4'h00,8'h07,8'h06,ADDI}
`define ADD3_INSN	{4'h1,32'h00000002,4'h00,8'h47,8'h46,ADDI}
`define STO_INSN	{4'h1,12'h000,4'h3,3'h0,1'b0,8'h00,8'h00,8'h00,8'h8F,8'h70}
`define BNE_INSN {4'h1,12'hFFF,4'h0,4'hC,8'd63,8'h88,8'h04,8'h00,BNE}

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
	ack_i <= cyc_o;

always @(posedge clk)
begin
	if (adr_o[31:24]==8'hFF)
		case(adr_o[6:4])
		3'd0:	dat_i <= {`ADD1_INSN,{8{NOP}}};
		3'd1:	dat_i <= {`ADD2_INSN,`ADD2_INSN};
		3'd2: dat_i <= {`STO_INSN,`STO_INSN};
		3'd3:	dat_i <= {`ADD3_INSN,`ADD3_INSN};
		3'd4:	dat_i <= {NOP_INSN,`BNE_INSN};
		default:	dat_i <= {NOP_INSN,NOP_INSN};
		endcase
	else
		dat_i <= 128'd0;
end

endmodule
