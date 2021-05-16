


rob_Rt[`ROB_HEADQ] <= new_rob_Rt[`ROB_HEADQ];

module preg_avail(rst, clk, rob_state, rob_Rt, rob_rfwr, new_rob_Rt);
input rst;
input clk;
input [3:0] rob_state [1:0];
input [8:0] rob_Rt [1:0];
input [1:0] rob_rfwr;
output [8:0] new_rob_Rt;

wire [7:0] RtAvail [1:0];

integer n;
reg [7:0] preg_avail [0:63];
reg [2:0] rrmap [63:0];

RtRen u1 (RtAvail[0],new_rob_Rt[0][8:6]);
RtRen u2 (RtAvail[1],new_rob_Rt[1][8:6]);
assign new_rob_Rt[0][5:0]==rob_Rt[0][5:0];
assign new_rob_Rt[1][5:0]==rob_Rt[1][5:0];

always @(posedge clk)
if (rst) begin
	for (n = 0; n < 64; n = n + 1)
		preg_avail[n] <= 8'hFF;
end
else begin
	if (rob_state[0]==`ROB_COMMIT && rob_rfwr[0])
		preg_avail[rob_Rt[0][5:0]][rob_Rt[0][8:6]] <= 1'b1;
	if (rob_state[1]==`ROB_COMMIT && rob_rfwr[1])
		preg_avail[rob_Rt[1][5:0]][rob_Rt[1][8:6]] <= 1'b1;
end

assign RtAvail[0] = preg_avail[rob_Rt[0][5:0]];
assign RtAvail[1] = preg_avail[rob_Rt[1][5:0]];

assign RtStall[0] = ~|RtAvail[0][7:1];
assign RtStall[1] = ~|RtAvail[1][7:1];

endmodule

module RtRen(i, o);
input [7:1] avail;
output reg [2:0] o;

casez(avail)
7'b1??????:	o <= 3'd7;
7'b01?????:	o <= 3'd6;
7'b001????:	o <= 3'd5;
7'b0001???:	o <= 3'd4;
7'b00001??:	o <= 3'd3;
7'b000001?:	o <= 3'd2;
7'b0000001:	o <= 3'd1;
default:	o <= 3'd0;
endcase

endmodule

reg [7:0] rrmap[63:0];
reg [255:0] rnameBitmap;

if (rob_rfwr[0] & rob_scalarT[0] & rob_rfwr[1] & rob_scalarT[1]) begin
	rrfifo[rrfifoTail] <= rob_Rt[0][7:0];
	rrfifo[rrfifoTail+1] <= rob_Rt[1][7:0];
	rrfifoTail <= rrfifoTail + 2'd2;
end
else if (rob_rfwr[0] & rob_scalarT[0])
	rrfifo[rrfifoTail] <= rob_Rt[0][7:0];
	rrfifoTail <= rrfifoTail + 2'd1;
end
else if (rob_rfwr[1] & rob_scalarT[1])
	rrfifo[rrfifoTail] <= rob_Rt[1][7:0];
	rrfifoTail <= rrfifoTail + 2'd1;
end


regtag1 = 7'h00;
regtag2 = 7'h00;
for (n = 1; n < 128; n = n + 1)
	if (rob_state[`DISPATCH_HEAD]==`ROB_DISPATCH) begin
		if (rnameBitmap[n]==`AVAIL && regtag1==7'h00)
			regtag1 = n;
		else if (rnameBitmap[n]==`AVAIL && regtag2==7'h00)
			regtag2 = n;
	end

	rnameBitmap[regtag1] <= `USED;
	rnameBitmap[regtag2] <= `USED;

	rmap[regtag1] <= Rt[0];
	rmap[regtag2] <= Rt[1];

always @(posedge clk)
if (rst) begin
	rnameBitmap <= {128{`AVAIL}};
end
else begin
	if (rob_state[`CMT_HEAD]==`ROB_COMMIT && rob_rfwr[`CMT_HEAD] && rob_Rt[`CMT_HEAD][11:10]==2'b00)
		rnameBitmap[rob_Rt[`CMT_HEAD][7:0]] <= `AVAIL;
	if (rob_state[(`CMT_HEAD+1) % 8]==`ROB_COMMIT && rob_rfwr[(`CMT_HEAD+1) % 8] && rob_Rt[(`CMT_HEAD+1) % 8][11:10]==2'b00)
		rnameBitmap[rob_Rt[(`CMT_HEAD+1) % 8][7:0]] <= `AVAIL;
end

