// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
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
//
import any1_pkg::*;

module any1_eval_branch(inst, a, b, takb);
parameter WID=64;
input [63:0] inst;
input [WID-1:0] a;
input [WID-1:0] b;
output reg takb;

always @*
case(inst[7:0])
BEQ: takb =  a==b;
BNE: takb =  a!=b;
BLT: takb = 	$signed(a) <  $signed(b);
BGE: takb = 	$signed(a) >= $signed(b);
BLTU:  takb = a <  b;
BGEU:  takb = a >= b;
default:  takb = 1'b0;
endcase

endmodule
