// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// AS64 - Assembler
//  - 64 bit CPU
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
#ifndef SYMBOL_H
#define SYMBOL_H

#include "Int128.h"

typedef struct {
  int ord;        // ordinal
  int name;       // name table index
  int gfnName;    // name in global func table
  int parent;
  int referenceCount;
  Int128 value;
  int64_t size;
  int64_t alignment;
  Macro* macro;
  int libcallno;
  unsigned int segment : 6;   // or section
  unsigned int pad2a : 1;
  unsigned int isConst : 1;   // An equate
  unsigned int isLibcall : 1;
  unsigned int isDefined : 1;
  unsigned int isExtern : 1;
  unsigned int isGlobal : 1;
	unsigned int isMacro : 1;
  unsigned int isFunc : 1;  // 1=func, 0=data
  unsigned int hasPhaseErr : 1;
  unsigned int pad2b : 1;
  unsigned int addressBits : 8; // number of bits needed to represent address
} SYM;

SYM *find_symbol(char *name);
SYM *new_symbol(char *name);
void DumpSymbols();
extern int numsym;

#endif
