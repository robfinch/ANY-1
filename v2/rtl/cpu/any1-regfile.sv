module any1_regfile (clk,wr,wa,i,ra0, ra1, ra2, ra3,o0,o1,o2,o3);
input clk;
input wr;
input [9:0] wa;
input [79:0] i;
input [9:0] ra0;
input [9:0] ra1;
input [9:0] ra2;
input [9:0] ra3;
output reg [79:0] o0;
output reg [79:0] o1;
output reg [79:0] o2;
output reg [79:0] o3;

wire [79:0] rd0, rd1, rd2, rd3;

any1_regfile_mem u00(clk, wr, wa, ra0, i, rd0);
any1_regfile_mem u01(clk, wr, wa, ra1, i, rd1);
any1_regfile_mem u02(clk, wr, wa, ra2, i, rd2);
any1_regfile_mem u03(clk, wr, wa, ra3, i, rd3);

always @*
begin
	o0 = ra0[5:0]==6'd0 ? 80'd0 : ra0==wa ? i : rd0;
	o1 = ra1[5:0]==6'd0 ? 80'd0 : ra1==wa ? i : rd1;
	o2 = ra2[5:0]==6'd0 ? 80'd0 : ra2==wa ? i : rd2;
	o3 = ra3[5:0]==6'd0 ? 80'd0 : ra3==wa ? i : rd3;
end

endmodule

