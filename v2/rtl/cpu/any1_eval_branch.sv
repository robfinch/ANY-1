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
input Instruction inst;
input Value a;
input Value b;
output reg takb;

always @*
case(inst.br.opcode)
BEQ: takb =  a.val==b.val;
BNE: takb =  a.val!=b.val;
BLT: takb = 	$signed(a.val) <  $signed(b.val);
BGE: takb = 	$signed(a.val) >= $signed(b.val);
BLTU:  takb = a.val <  b.val;
BGEU:  takb = a.val >= b.val;
BBS:	takb = a.val[b.val[5:0]];
default:  takb = 1'b0;
endcase

endmodule
