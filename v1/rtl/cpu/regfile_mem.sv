module regfile_mem(clk, wr, wa, ra, i, o);
input clk;
input wr;
input [11:0] wa;
input [11:0] ra;
input [63:0] i;
output [63:0] o;

reg [11:0] rra;
reg [63:0] mem [0:4095];

always @(posedge clk)
	if (wr)
		mem[wa] <= i;

always @(posedge clk)
	rra <= ra;
always @(posedge clk)
	o <= mem[ra];

endmodule
