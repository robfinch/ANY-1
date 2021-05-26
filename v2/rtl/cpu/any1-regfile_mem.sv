module any1_regfile_mem(clk, wr, wa, ra, i, o);
input clk;
input wr;
input [9:0] wa;
input [9:0] ra;
input [79:0] i;
output reg [79:0] o;

reg [9:0] rra;
reg [79:0] mem [0:1023];

always @(posedge clk)
	if (wr)
		mem[wa] <= i;

always @(posedge clk)
	rra <= ra;
always @(posedge clk)
	o <= mem[rra];

endmodule
