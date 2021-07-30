// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// FLINK - Linker
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
#pragma once

class clsAny1elfSection : public clsElf64Section {
public:
  void AddInsn(int64_t insn) {
    int nn;

    if ((insn & 0x70) == 0x70) {
      for (nn = 0; nn < 5; nn++) {
        AddNybble(insn);
        insn >>= 4;
      }
    }
    else {
      for (nn = 0; nn < 9; nn++) {
        AddNybble(insn);
        insn >>= 4;
      }
    }
  };
};

class clsAny1elfFile : public clsElf64File
{
public:
    clsAny1elfSection *sections[256];
    void AddSection(clsAny1elfSection* sect) {
      sections[hdr.e_shnum] = sect;
      hdr.e_shnum++;
    };

};
