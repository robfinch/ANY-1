// ============================================================================
//        __
//   \\__/ o\    (C) 2014  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// A64 - Assembler
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
#ifndef NAMETABLE_HPP
#define NAMETABLE_HPP

#include <string.h>
extern char nametext[1000000];

class NameTable {
public:
    int length;

public:    
    NameTable() {
        nametext[0] = 0;
        nametext[1] = 0;
        length = 1;
    };
    void Clear() {
        nametext[0] = 0;
        nametext[1] = 0;
        length = 1;
    };
    char *GetName(int ndx) {
         return &nametext[ndx];
    };
    
    int FindName(char *nm) {
        int nn, mm;
        
        for (nn = 1; nn < length; nn++) {
            if (nametext[nn] == nm[0]) {
                for(mm = 1; nm[mm] == nametext[nn+mm] && nm[mm]; mm++);
                if (nm[mm]=='\0' && nametext[nn+mm]=='\0')
                   return nn;
                while (nametext[nn] != 0 && nn < length) nn++;
                nn++;
            }
            else {
                while(nametext[nn]!=0 && nn < length) nn++;
                nn++;
            }
        }
        return -1;
    };

    int AddName(char *nm) {
        int ret;
        int olen;
        
        if ((ret = FindName(nm)) > 0)
           return ret;
        olen = length;
        strcpy_s(&nametext[length], sizeof(nametext)-length, nm);
        if ((sizeof(nametext) - length) <= 0)
          exit(0);
        length += strlen(nm) + 1;
        return olen;
    };
    
    void write(FILE *fp) {
         fwrite((void *)nametext, 1, length, fp);
    };
};

#endif
