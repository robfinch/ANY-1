// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
// 4993
`include "any1-config.sv"
`define VAL		1'b1
`define INV		1'b0

module regfileSource(rst, clk, clk5x, ph, branchmiss, heads, slotvd, slot_rfw,
	queuedOn,	rqueuedOn, iq_state, iq_rfw, iq_Rd, Rd, rob_tails,
	iq_latestID, iq_tgt, iq_rid, rf_source, ack_o);
parameter AREGS = 4096;
parameter QENTRIES = `QENTRIES;
parameter RENTRIES = `RENTRIES;
parameter QSLOTS = `QSLOTS;
parameter RBIT = 11;
input rst;
input clk;
input clk5x;
input [2:0] ph;
input branchmiss;
input [`QBITS] heads [0:QENTRIES-1];
input [QSLOTS-1:0] slotvd;
input [QSLOTS-1:0] slot_rfw;
input [QSLOTS-1:0] queuedOn;
input [QENTRIES-1:0] rqueuedOn;
input [2:0] iq_state [0:QENTRIES-1];
input [QENTRIES-1:0] iq_rfw;
input [RBIT:0] iq_Rd [0:QENTRIES-1];
input [RBIT:0] Rd [0:QSLOTS-1];
input [`RBITS] rob_tails [0:QSLOTS-1];
input [RBIT:0] iq_latestID [0:QENTRIES-1];
input [RBIT:0] iq_tgt [0:QENTRIES-1];
input [`RBITS] iq_rid [0:QENTRIES-1];
output reg [`QBITSP1] rf_source [0:AREGS-1];
output reg ack_o;

integer n;
reg [11:0] wa;
reg [`RBITS] wd;
reg ack;

initial begin
for (n = 0; n < AREGS; n = n + 1)
	rf_source[n] = 1'b0;
end

always @*
if (rst) begin
	wa <= wa + 12'd1;
	wd <= {`QBIT{1'b1}};
	ack <= 1'b1;	// for now, should reset all register sources
end
else begin
	wa <= 12'd0;
	wd <= {`QBIT{1'b1}};
	ack <= 1'b1;
	if (branchmiss) begin
		for (n = 0; n < QENTRIES; n = n + 1) begin
    	if (|iq_latestID[n]) begin
    		wa <= iq_tgt[n];
    		wd <= {{`QBIT{1'b0}},iq_rid[n[`QBITS]]};
    	end
    end
	end
	else begin
		// Setting the rf valid and source
		case(slotvd)

		4'b0000:	;
		4'b0001:
			if (ph==3'd0 && queuedOn[0]) begin
				if (slot_rfw[0]) begin
					wa <= Rd[0];
					wd <= {{`QBIT{1'b0}},rob_tails[0]};
				end
			end

		4'b0010:
			if (ph==3'd0 && queuedOn[1]) begin
				if (slot_rfw[1]) begin
					wa <= Rd[1];
					wd <= {{`QBIT{1'b0}},rob_tails[0]};
				end
			end

		4'b0011:
			case (ph)
			3'd0:
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						wa <= Rd[0];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[1]) begin
						if (slot_rfw[1])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[0]) begin
					if (queuedOn[1]) begin
						if (slot_rfw[1]) begin
							ack <= 1'b1;
							wa <= Rd[1];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
						end
					end
				end
			default:	;
			endcase

		4'b0100:
			if (ph==3'd0) begin
				if (queuedOn[2]) begin
					if (slot_rfw[2]) begin
						wa <= Rd[2];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
				end
			end

		4'b0101:
			case(ph)
			3'd0:
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						wa <= Rd[0];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[2]) begin
						if (slot_rfw[2])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[0]) begin
					if (queuedOn[2]) begin
						if (slot_rfw[2]) begin
							wa <= Rd[2];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
							ack <= 1'b1;
						end
					end
				end
			default:	;
			endcase

		4'b0110:
			case(ph)
			3'd0:
				if (queuedOn[1]) begin
					if (slot_rfw[1]) begin
						wa <= Rd[1];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[2])
						ack <= 1'b0;
				end
			3'd1:
				if (queuedOn[1]) begin
					if (queuedOn[2]) begin
						if (slot_rfw[2]) begin
							wa <= Rd[2];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
							ack <= 1'b1;
						end
					end
				end
			default:	;
			endcase

		4'b0111:
			case(ph)
			3'd0:
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						wa <= Rd[0];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[1]) begin
						if (slot_rfw[1])
							ack <= 1'b0;
					end
				end
			3'd1:
				begin
					ack <= 1'b1;
					if (queuedOn[0]) begin
						if (queuedOn[1]) begin
							if (slot_rfw[1]) begin
								wa <= Rd[1];
								wd <= {{`QBIT{1'b0}},rob_tails[1]};
							end
							if (queuedOn[2]) begin
								if (slot_rfw[2])
									ack <= 1'b0;
							end
						end
					end
				end
			3'd2:
				begin
					ack <= 1'b1;
					if (queuedOn[0]) begin
						if (queuedOn[1]) begin
							if (queuedOn[2]) begin
								if (slot_rfw[2]) begin
									wa <= Rd[2];
									wd <= {{`QBIT{1'b0}},rob_tails[2]};
								end
							end
						end
					end
				end
			default:	;
			endcase
	
		4'b1000:
			if (queuedOn[3]) begin
				if (slot_rfw[3]) begin
					wa <= Rd[3];
					wd <= {{`QBIT{1'b0}},rob_tails[0]};
				end
			end

		4'b1001:
			case(ph)
			3'd0:
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						wa <= Rd[0];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[3]) begin
						if (slot_rfw[3])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[0]) begin
					if (queuedOn[3]) begin
						if (slot_rfw[3]) begin
							wa <= Rd[3];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
							ack <= 1'b1;
						end
					end
				end
			default:	;
			endcase

		4'b1010:
			case(ph)
			3'd0:
				if (queuedOn[1]) begin
					if (slot_rfw[1]) begin
						wa <= Rd[1];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[3]) begin
						if (slot_rfw[3])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[1]) begin
					if (queuedOn[3]) begin
						if (slot_rfw[3]) begin
							wa <= Rd[3];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
							ack <= 1'b1;
						end
					end
				end
			default:	;
			endcase

		4'b1011:
			case(ph)
			3'd0:
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						wa <= Rd[0];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[1]) begin
						if (slot_rfw[1])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[0]) begin
					if (queuedOn[1]) begin
						if (slot_rfw[1]) begin
							wa <= Rd[1];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
						end
						if (queuedOn[3]) begin
							if (slot_rfw[3])
								ack <= 1'b0;
						end
					end
				end
			3'd2:
				if (queuedOn[0]) begin
					if (queuedOn[1]) begin
						if (queuedOn[3]) begin
							if (slot_rfw[3]) begin
								wa <= Rd[3];
								wd <= {{`QBIT{1'b0}},rob_tails[2]};
								ack <= 1'b1;
							end
						end
					end
				end
			default:	;
			endcase

		4'b1100:
			case(ph)
			3'd0:
				if (queuedOn[2]) begin
					if (slot_rfw[2]) begin
						wa <= Rd[2];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[3]) begin
						if (slot_rfw[3])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[2]) begin
					if (queuedOn[3]) begin
						if (slot_rfw[3]) begin
							wa <= Rd[3];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
							ack <= 1'b1;
						end
					end
				end
			default:	;
			endcase

		4'b1101:
			case(ph)
			3'd0:
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						wa <= Rd[0];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[2]) begin
						if (slot_rfw[2])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[0]) begin
					if (queuedOn[2]) begin
						if (slot_rfw[2]) begin
							wa <= Rd[2];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
						end
						if (queuedOn[3]) begin
							if (slot_rfw[3])
								ack <= 1'b0;
						end
					end
				end
			3'd2:
				if (queuedOn[0]) begin
					if (queuedOn[2]) begin
						if (queuedOn[3]) begin
							if (slot_rfw[3]) begin
								wa <= Rd[3];
								wd <= {{`QBIT{1'b0}},rob_tails[2]};
								ack <= 1'b1;
							end
						end
					end
				end
			default:	;
			endcase

		4'b1110:
			case(ph)
			3'd0:
				if (queuedOn[1]) begin
					if (slot_rfw[1]) begin
						wa <= Rd[1];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[2]) begin
						if (slot_rfw[2])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[1]) begin
					if (queuedOn[2]) begin
						if (slot_rfw[2]) begin
							wa <= Rd[2];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
						end
						if (queuedOn[3]) begin
							if (slot_rfw[3])
								ack <= 1'b0;
						end
					end
				end
			3'd2:
				if (queuedOn[1]) begin
					if (queuedOn[2]) begin
						if (queuedOn[3]) begin
							if (slot_rfw[3]) begin
								wa <= Rd[3];
								wd <= {{`QBIT{1'b0}},rob_tails[2]};
								ack <= 1'b1;
							end
						end
					end
				end
			default:	;
			endcase

		4'b1111:
			case(ph)
			3'd0:
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						wa <= Rd[0];
						wd <= {{`QBIT{1'b0}},rob_tails[0]};
					end
					if (queuedOn[1]) begin
						if (slot_rfw[1])
							ack <= 1'b0;
					end
				end
			3'd1:
				if (queuedOn[0]) begin
					if (queuedOn[1]) begin
						if (slot_rfw[1]) begin
							wa <= Rd[1];
							wd <= {{`QBIT{1'b0}},rob_tails[1]};
						end
						if (queuedOn[2]) begin
							if (slot_rfw[2])
								ack <= 1'b0;
						end
					end
				end
			3'd2:
				if (queuedOn[0]) begin
					if (queuedOn[1]) begin
						if (queuedOn[2]) begin
							if (slot_rfw[2]) begin
								wa <= Rd[2];
								wd <= {{`QBIT{1'b0}},rob_tails[2]};
							end
							if (queuedOn[3]) begin
								if (slot_rfw[3])
									ack <= 1'b0;
							end
						end
					end
				end
			3'd3:
				if (queuedOn[0]) begin
					if (queuedOn[1]) begin
						if (queuedOn[2]) begin
							if (queuedOn[3]) begin
								if (slot_rfw[3]) begin
									wa <= Rd[3];
									wd <= {{`QBIT{1'b0}},rob_tails[3]};
									ack <= 1'b1;
								end
							end
						end
					end
				end
			default:	;
			endcase
		endcase
	end
end

always @(posedge clk)
if (rst) begin
	ack_o <= 1'b1;
	rf_source[wa] <= wd;
end
else begin
	if (ack)
		ack_o <= ack;
	if (ph==3'd4)
		ack_o <= 1'b0;
	rf_source[wa] <= wd;
	rf_source[0] <= {`QBIT{1'b1}};
end

endmodule
