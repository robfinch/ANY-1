//=============================================================================
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
//
//=============================================================================
//
import any1_pkg::*;

module gselectPredictor(rst, clk, en, xisBranch, xip, takb, ip, predict_taken);
input rst;
input clk;
input en;
input xisBranch;
input Address xip;
input takb;
input Address ip;
output reg predict_taken;

integer n;

reg wrhist;
reg [2:0] gbl_branch_hist;
reg [1:0] branch_history_table [511:0];
always_comb
	wrhist <= xisBranch;

// For simulation only, initialize the history table to zeros.
// In the real world we don't care.
initial begin
	for (n = 0; n < 512; n = n + 1)
		branch_history_table[n] = 3;
end
wire [8:0] bht_wa = {xip[8:2],gbl_branch_hist[2:1]};		// write address
wire [1:0] bht_xbits = branch_history_table[bht_wa];
reg [8:0] bht_ra;
reg [1:0] bht_ibits;
always_comb
begin
	bht_ra = {ip[8:2],gbl_branch_hist[2:1]};	// read address (IF stage)
	bht_ibits = branch_history_table[bht_ra];
	predict_taken = (bht_ibits==2'd0 || bht_ibits==2'd1) && en;
end

// Two bit saturating counter
// If taking a branch in commit0 then a following branch
// in commit1 is never encountered. So only update for
// commit1 if commit0 is not taken.
reg [1:0] xbits_new;
always_comb
if (wrhist) begin
	if (takb) begin
		if (bht_xbits != 2'd1)
			xbits_new <= bht_xbits + 2'd1;
		else
			xbits_new <= bht_xbits;
	end
	else begin
		if (bht_xbits != 2'd3)
			xbits_new <= bht_xbits - 2'd1;
		else
			xbits_new <= bht_xbits;
	end
end
else
	xbits_new <= bht_xbits;

always_ff @(posedge clk)
if (rst)
	gbl_branch_hist <= 3'b000;
else begin
  if (en) begin
    if (wrhist) begin
      gbl_branch_hist <= {gbl_branch_hist[1:0],takb};
      branch_history_table[bht_wa] <= xbits_new;
    end
	end
end

endmodule

