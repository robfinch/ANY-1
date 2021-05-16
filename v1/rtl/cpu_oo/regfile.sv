module regfile (clk,clk4x,wr0,wr1,wa0,wa1,i0,i1,o00,o01,o02,o03,o10,o11,o12,o13);
input clk;
input wr0;
input wr1;
input [11:0] wa0;
input [11:0] wa1;
input [63:0] i0;
input [63:0] i1;
output [63:0] o00;
output [63:0] o01;
output [63:0] o02;
output [63:0] o03;
output [63:0] o10;
output [63:0] o11;
output [63:0] o12;
output [63:0] o13;

regfile_mem u00(clk, wr, wa, ra00, i, o00);
regfile_mem u01(clk, wr, wa, ra01, i, o01);
regfile_mem u02(clk, wr, wa, ra02, i, o02);
regfile_mem u03(clk, wr, wa, ra03, i, o03);

regfile_mem u10(clk, wr, wa, ra10, i, o10);
regfile_mem u11(clk, wr, wa, ra11, i, o11);
regfile_mem u12(clk, wr, wa, ra12, i, o12);
regfile_mem u13(clk, wr, wa, ra13, i, o13);

endmodule

