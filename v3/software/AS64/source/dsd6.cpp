// ============================================================================
//        __
//   \\__/ o\    (C) 2016  Robert Finch, Stratford
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
#include "stdafx.h"

static void emitAlignedCode(int cd);
static void process_shifti(int oc, int funct3, int funct7);
static void ProcessEOL(int opt);

extern int first_rodata;
extern int first_data;
extern int first_bss;
extern int htable[100000];
extern int htblcnt[100000];
extern int htblmax;
extern int pass;

static int64_t ca;

extern int use_gp;

#define OPT64     0
#define OPTX32    1
#define OPTLUI0   0

// ----------------------------------------------------------------------------
// Return the register number or -1 if not a register.
// Parses pretty register names like SP or BP in addition to r1,r2,etc.
// ----------------------------------------------------------------------------

static int getRegisterX()
{
    int reg;

    while(isspace(*inptr)) inptr++;
    switch(*inptr) {
    case 'x': case 'X':
         if (isdigit(inptr[1])) {
             reg = inptr[1]-'0';
             if (isdigit(inptr[2])) {
                 reg = 10 * reg + (inptr[2]-'0');
                 if (isdigit(inptr[3])) {
                     reg = 10 * reg + (inptr[3]-'0');
                     if (isIdentChar(inptr[4]))
                         return -1;
                     inptr += 4;
                     NextToken();
                     return reg;
                 }
                 else if (isIdentChar(inptr[3]))
                     return -1;
                 else {
                     inptr += 3;
                     NextToken();
                     return reg;
                 }
             }
             else if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 NextToken();
                 return reg;
             }
         }
         else return -1;
    case 'a': case 'A':
         if (isdigit(inptr[1])) {
             reg = inptr[1]-'0' + 18;
             if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 NextToken();
                 return reg;
             }
         }
         else return -1;
    case 'f': case 'F':
        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 2;
        }
        break;
    case 'g': case 'G':
        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 26;
        }
        break;
    case 's': case 'S':
        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 14;
        }
        break;
    case 't': case 'T':
         if (isdigit(inptr[1])) {
             reg = inptr[1]-'0' + 26;
             if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 NextToken();
                 return reg;
             }
         }
        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 15;
        }
        /*
        if ((inptr[1]=='R' || inptr[1]=='r') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 24;
        }
        */
        break;
    case 'p': case 'P':
        if ((inptr[1]=='c' || inptr[1]=='C') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 29;
        }
        break;
    case 'l': case 'L':
        if ((inptr[1]=='R' || inptr[1]=='r') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 31;
        }
        break;
    case 'r': case 'R':
        if ((inptr[1]=='a' || inptr[1]=='A') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 1;
        }
        break;
    case 'v': case 'V':
         if (inptr[1]=='0' || inptr[1]=='1') {
             reg = inptr[1]-'0' + 16;
             if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 NextToken();
                 return reg;
             }
         }
    default:
        return -1;
    }
    return -1;
}

static int isdelim(char ch)
{
    return ch==',' || ch=='[' || ch=='(' || ch==']' || ch==')' || ch=='.';
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static int getCodeareg()
{
    int pr;

    SkipSpaces();
    if (inptr[0]=='c' || inptr[0]=='C') {
         if (isdigit(inptr[1]) && (inptr[2]==',' || isdelim(inptr[2]) || isspace(inptr[2]))) {
              pr = (inptr[1]-'0');
              inptr += 2;
         }
         else if (isdigit(inptr[1]) && isdigit(inptr[2]) && (inptr[3]==',' || isdelim(inptr[3]) || isspace(inptr[3]))) {
              pr = ((inptr[1]-'0') * 10) + (inptr[2]-'0');
              inptr += 3;
         }
         else
             return -1;
    }
    else
        return -1;
     NextToken();
     return pr;
}


// ----------------------------------------------------------------------------
// Get the friendly name of a special purpose register.
// ----------------------------------------------------------------------------

static int DSD6_getSprRegister()
{
    int reg;
    int pr;

    while(isspace(*inptr)) inptr++;
    reg = getCodeareg();
    if (reg >= 0) {
       reg |= 0x10;
       return reg;
    }
    if (inptr[0]=='p' || inptr[0]=='P') {
         if (isdigit(inptr[1]) && isdigit(inptr[2])) {
              pr = ((inptr[1]-'0' * 10) + (inptr[2]-'0'));
              if (!isIdentChar(inptr[3])) {
                  inptr += 3;
                  NextToken();
                  return pr | 0x40;
              }
         }
         else if (isdigit(inptr[1])) {
              pr = (inptr[1]-'0');
              if (!isIdentChar(inptr[2])) {
                  inptr += 2;
                  NextToken();
                  return pr | 0x40;
              }
         }
     }

    while(isspace(*inptr)) inptr++;
    switch(*inptr) {

    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
         NextToken();
         NextToken();
         return ival.low;

    // arg1
    case 'a': case 'A':
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='g' || inptr[2]=='G') &&
             (inptr[3]=='1' || inptr[3]=='1') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             NextToken();
             return 58;
         }
         break;
    // bear
    case 'b': case 'B':
         if ((inptr[1]=='e' || inptr[1]=='E') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='r' || inptr[3]=='R') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             NextToken();
             return 11;
         }
         break;
    // cas clk cr0 cr3 cs CPL
    case 'c': case 'C':
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             (inptr[2]=='s' || inptr[2]=='S') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 44;
         }
         if ((inptr[1]=='l' || inptr[1]=='L') &&
             (inptr[2]=='k' || inptr[2]=='K') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 0x06;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='0') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 0x00;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='3') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 0x03;
         }
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') &&
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x2F;
               }
            }
            inptr += 2;
            NextToken();
            return 0x27;
        }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='l' || inptr[2]=='L') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 42;
         }
         break;

    // dbad0 dbad1 dbctrl dpc dsp ds
    case 'd': case 'D':
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             (inptr[4]=='0' || inptr[4]=='0') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             NextToken();
             return 50;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             (inptr[4]=='1' || inptr[4]=='1') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             NextToken();
             return 51;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             (inptr[4]=='2' || inptr[4]=='2') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             NextToken();
             return 52;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             (inptr[4]=='3' || inptr[4]=='3') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             NextToken();
             return 53;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             (inptr[3]=='t' || inptr[3]=='T') &&
             (inptr[4]=='r' || inptr[4]=='R') &&
             (inptr[5]=='l' || inptr[5]=='L') &&
             !isIdentChar(inptr[6])) {
             inptr += 6;
             NextToken();
             return 54;
         }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 7;
         }
         if (
             (inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             (inptr[3]=='c' || inptr[3]=='C') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             NextToken();
             return 7;
         }
         if ((inptr[1]=='s' || inptr[1]=='S') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 16;
         }
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') &&         
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x29;
               }
            }
            inptr += 2;
            NextToken();
            return 0x21;
        }
         break;

    // ea epc esp es
    case 'e': case 'E':
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             !isIdentChar(inptr[2])) {
             inptr += 2;
             NextToken();
             return 40;
         }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 9;
         }
         if ((inptr[1]=='s' || inptr[1]=='S') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 17;
         }
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') &&  
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x2A;
               }
            }
            inptr += 2;
            NextToken();
            return 0x22;
        }
         break;

    // fault_pc fs
    case 'f': case 'F':
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             (inptr[2]=='u' || inptr[2]=='U') &&
             (inptr[3]=='l' || inptr[3]=='L') &&
             (inptr[4]=='t' || inptr[4]=='T') &&
             (inptr[5]=='_' || inptr[5]=='_') &&
             (inptr[6]=='p' || inptr[6]=='P') &&
             (inptr[7]=='c' || inptr[7]=='C') &&
             !isIdentChar(inptr[8])) {
             inptr += 8;
             NextToken();
             return 0x08;
         }
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') &&
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x2B;
               }
            }
            inptr += 2;
            NextToken();
            return 0x23;
        }
         break;

    // gs GDT
    case 'g': case 'G':
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') && 
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x2C;
               }
            }
            inptr += 2;
            NextToken();
            return 0x24;
        }
        if ((inptr[1]=='d' || inptr[1]=='D') &&
           (inptr[2]=='t' || inptr[2]=='T') &&
            !isIdentChar(inptr[3])) {
            inptr += 3;
            NextToken();
            return 41;
        }
        break;

    // history
    case 'h': case 'H':
         if ((inptr[1]=='i' || inptr[1]=='I') &&
             (inptr[2]=='s' || inptr[2]=='S') &&
             (inptr[3]=='t' || inptr[3]=='T') &&
             (inptr[4]=='o' || inptr[4]=='O') &&
             (inptr[5]=='r' || inptr[5]=='R') &&
             (inptr[6]=='y' || inptr[6]=='Y') &&
             !isIdentChar(inptr[7])) {
             inptr += 7;
             NextToken();
             return 0x0D;
         }
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') &&
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x2D;
               }
            }
            inptr += 2;
            NextToken();
            return 0x25;
        }
         break;

    // ipc isp ivno
    case 'i': case 'I':
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 8;
         }
         if ((inptr[1]=='s' || inptr[1]=='S') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 15;
         }
         if ((inptr[1]=='v' || inptr[1]=='V') &&
             (inptr[2]=='n' || inptr[2]=='N') &&
             (inptr[3]=='o' || inptr[3]=='O') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             NextToken();
             return 0x0C;
         }
         break;


    // LC LDT
    case 'l': case 'L':
         if ((inptr[1]=='c' || inptr[1]=='C') &&
             !isIdentChar(inptr[2])) {
             inptr += 2;
             NextToken();
             return 0x33;
         }
         if ((inptr[1]=='d' || inptr[1]=='D') &&
            (inptr[2]=='t' || inptr[2]=='T') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 40;
         }
         break;

    // pregs
    case 'p': case 'P':
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='e' || inptr[2]=='E') &&
             (inptr[3]=='g' || inptr[3]=='G') &&
             (inptr[4]=='s' || inptr[4]=='S') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             NextToken();
             return 52;
         }
         break;

    // rand
    case 'r': case 'R':
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             (inptr[2]=='n' || inptr[2]=='N') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             NextToken();
             return 0x12;
         }
         break;
    // ss_ll srand1 srand2 ss segsw segbase seglmt segacr
    case 's': case 'S':
         if ((inptr[1]=='s' || inptr[1]=='S') &&
             (inptr[2]=='_' || inptr[2]=='_') &&
             (inptr[3]=='l' || inptr[3]=='L') &&
             (inptr[4]=='l' || inptr[4]=='L') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             NextToken();
             return 0x1A;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='n' || inptr[3]=='N') &&
             (inptr[4]=='d' || inptr[4]=='D') &&
             (inptr[5]=='1') &&
             !isIdentChar(inptr[6])) {
             inptr += 6;
             NextToken();
             return 0x10;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='n' || inptr[3]=='N') &&
             (inptr[4]=='d' || inptr[4]=='D') &&
             (inptr[5]=='2') &&
             !isIdentChar(inptr[6])) {
             inptr += 6;
             NextToken();
             return 0x11;
         }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='r' || inptr[2]=='R') &&
             isdigit(inptr[3]) && isdigit(inptr[4]) &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             NextToken();
             return (inptr[3]-'0')*10 + (inptr[4]-'0');
         }
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') &&
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x2E;
               }
            }
            inptr += 2;
            NextToken();
            return 0x26;
         }
         // segxxx
         if ((inptr[1]=='e' || inptr[1]=='E') &&
             (inptr[2]=='g' || inptr[2]=='G')) {
             // segsw
             if ((inptr[3]=='s' || inptr[3]=='S') &&
                  (inptr[4]=='w' || inptr[4]=='W') &&
                  !isIdentChar(inptr[5])) {
               inptr += 5;
               NextToken();
               return 43;
             }
             // segbase
             if ((inptr[3]=='b' || inptr[3]=='B') &&
                  (inptr[4]=='a' || inptr[4]=='A') &&
                  (inptr[5]=='s' || inptr[5]=='S') &&
                  (inptr[6]=='e' || inptr[6]=='E') &&
                  !isIdentChar(inptr[7])) {
               inptr += 7;
               NextToken();
               return 44;
             }
             // seglmt
             if ((inptr[3]=='l' || inptr[3]=='L') &&
                  (inptr[4]=='m' || inptr[4]=='M') &&
                  (inptr[5]=='t' || inptr[5]=='T') &&
                  !isIdentChar(inptr[6])) {
               inptr += 6;
               NextToken();
               return 45;
             }
             // segacr
             if ((inptr[3]=='a' || inptr[3]=='A') &&
                  (inptr[4]=='c' || inptr[4]=='C') &&
                  (inptr[5]=='r' || inptr[5]=='R') &&
                  !isIdentChar(inptr[6])) {
               inptr += 6;
               NextToken();
               return 47;
             }
         }
         break;

    // tag tick 
    case 't': case 'T':
         if ((inptr[1]=='i' || inptr[1]=='I') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             (inptr[3]=='k' || inptr[3]=='K') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             NextToken();
             return 0x32;
         }
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             (inptr[2]=='g' || inptr[2]=='G') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 41;
         }
         break;

    // vbr
    case 'v': case 'V':
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='r' || inptr[2]=='R') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             NextToken();
             return 10;
         }
         break;
    case 'z': case 'Z':
        if ((inptr[1]=='s' || inptr[1]=='S') &&
            !isIdentChar(inptr[2])) {
            if (inptr[2]=='.') {
               if ((inptr[3]=='l' || inptr[3]=='L') &&
                   (inptr[4]=='m' || inptr[4]=='M') &&
                   (inptr[5]=='t' || inptr[5]=='T') &&
                   !isIdentChar(inptr[6])) {
                       inptr += 6;
                       NextToken();
                       return 0x28;
               }
            }
            inptr += 2;
            NextToken();
            return 0x20;
        }
        break;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void emit_insn(int oc, int can_compress)
{
    int ndx;

    if (pass==3 && can_compress) {
       for (ndx = 0; ndx < htblmax; ndx++) {
         if (oc == hTable[ndx].opcode) {
           hTable[ndx].count++;
           return;
         }
       }
       if (htblmax < 100000) {
          hTable[htblmax].opcode = oc;
          hTable[htblmax].count = 1;
          htblmax++;
          return;  
       }
       printf("Too many instructions.\r\n");
       return;
    }
    if (pass > 3) {
     if (can_compress) {
       for (ndx = 0; ndx < htblmax; ndx++) {
         if (oc == hTable[ndx].opcode) {
           emitAlignedCode(((ndx & 8) << 4)|0x50|(ndx & 0x7));
           emitCode(ndx >> 4);
           return;
         }
       }
     }
     emitAlignedCode(oc & 255);
     emitCode((oc >> 8) & 255);
     emitCode((oc >> 16) & 255);
     emitCode((oc >> 24) & 255);
    }
    /*
    if (processOpt==2) {
       for (ndx = 0; ndx < htblmax; ndx++) {
         if (oc == hTable[ndx].opcode) {
           printf("found opcode\n");
           emitAlignedCode(((ndx & 8) << 4)|0x50|(ndx & 0x7));
           emitCode(ndx >> 4);
           return;
         }
       }
     emitAlignedCode(oc & 255);
     emitCode((oc >> 8) & 255);
     emitCode((oc >> 16) & 255);
     emitCode((oc >> 24) & 255);
    }
    else {
     emitAlignedCode(oc & 255);
     emitCode((oc >> 8) & 255);
     emitCode((oc >> 16) & 255);
     emitCode((oc >> 24) & 255);
    }
    */
}
 
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void emit_insn2(int64_t oc)
{
     emitCode(oc & 255);
     emitCode((oc >> 8) & 255);
     emitCode((oc >> 16) & 255);
     emitCode((oc >> 24) & 255);
}
 

// ---------------------------------------------------------------------------
// Emit code aligned to a code address.
// ---------------------------------------------------------------------------

static void emitAlignedCode(int cd)
{
     int64_t ad;

     ad = code_address & 15;
//     while (ad != 0 && ad != 4 && ad != 8 && ad != 12) {
       while (ad & 1) {
         emitByte(0x00);
         ad = code_address & 15;
     }
     emitByte(cd);
}


// ---------------------------------------------------------------------------
// Emit constant extension for memory operands.
// ---------------------------------------------------------------------------

static void emitImm0(int64_t v, int force)
{
     if (v != 0 || force) {
          emitAlignedCode(0xfd);
          emitCode(v & 255);
          emitCode((v >> 8) & 255);
          emitCode((v >> 16) & 255);
          emitCode((v >> 24) & 255);
     }
     if (((v < 0) && ((v >> 32) != -1L)) || ((v > 0) && ((v >> 32) != 0L)) || (force && data_bits > 32)) {
          emitAlignedCode(0xfe);
          emitCode((v >> 32) & 255);
          emitCode((v >> 40) & 255);
          emitCode((v >> 48) & 255);
          emitCode((v >> 56) & 255);
     }
}

// ---------------------------------------------------------------------------
// Emit constant extension for memory operands.
// ---------------------------------------------------------------------------

static void emitImm2(int64_t v, int force)
{
     if (v < 0L || v > 3L || force) {
          emitAlignedCode(0xfd);
          emitCode((v >> 2) & 255);
          emitCode((v >> 10) & 255);
          emitCode((v >> 18) & 255);
          emitCode((v >> 26) & 255);
     }
     if (((v < 0) && ((v >> 34) != -1L)) || ((v > 0) && ((v >> 34) != 0L)) || (force && data_bits > 34)) {
          emitAlignedCode(0xfe);
          emitCode((v >> 34) & 255);
          emitCode((v >> 42) & 255);
          emitCode((v >> 50) & 255);
          emitCode((v >> 58) & 255);
     }
}
 
// ---------------------------------------------------------------------------
// Emit constant extension for memory operands.
// ---------------------------------------------------------------------------

static void emitImm12(int64_t v, int force)
{
     if (v < -2048L || v > 2047L || force) {
          emitAlignedCode(0xfd);
          emitCode((v >> 12) & 255);
          emitCode((v >> 20) & 255);
          emitCode((v >> 28) & 255);
          emitCode((v >> 36) & 255);
     }
     if (((v < 0) && ((v >> 44) != -1L)) || ((v > 0) && ((v >> 44) != 0L)) || (force && data_bits > 44)) {
          emitAlignedCode(0xfe);
          emitCode((v >> 44) & 255);
          emitCode((v >> 52) & 255);
          emitCode((v >> 60) & 255);
          emitCode(0x00);
     }
}
 
// ---------------------------------------------------------------------------
// Emit constant extension for 16-bit operands.
// ---------------------------------------------------------------------------

static void emitImm16(int64_t v, int force)
{
     if (v < -32768L || v > 32767L || force) {
          emitAlignedCode(0xfd);
          emitCode((v >> 16) & 255);
          emitCode((v >> 24) & 255);
          emitCode((v >> 32) & 255);
          emitCode((v >> 40) & 255);
     }
     if (((v < 0) && ((v >> 48) != -1L)) || ((v > 0) && ((v >> 48) != 0L)) || (force && (code_bits > 48 || data_bits > 48))) {
          emitAlignedCode(0xfe);
          emitCode((v >> 48) & 255);
          emitCode((v >> 56) & 255);
          emitCode(0x00);
          emitCode(0x00);
     }
}

// ---------------------------------------------------------------------------
// Emit constant extension for 24-bit operands.
// ---------------------------------------------------------------------------

static void emitImm20(int64_t v, int force)
{
     if (v < -524288L || v > 524287L || force) {
          emitAlignedCode(0xfd);
          emitCode((v >> 20) & 255);
          emitCode((v >> 28) & 255);
          emitCode((v >> 36) & 255);
          emitCode((v >> 44) & 255);
     }
     if (((v < 0) && ((v >> 52) != -1L)) || ((v > 0) && ((v >> 52) != 0L)) || (force && (code_bits > 52 || data_bits > 52))) {
          emitAlignedCode(0xfe);
          emitCode((v >> 52) & 255);
          emitCode((v >> 60) & 255);
          emitCode(0x00);
          emitCode(0x00);
     }
}

// ---------------------------------------------------------------------------
// Emit constant extension for 24-bit operands.
// ---------------------------------------------------------------------------

static void emitImm24(int64_t v, int force)
{
     if (v < -8388608L || v > 8388607L || force) {
          emitAlignedCode(0xfd);
          emitCode((v >> 24) & 255);
          emitCode((v >> 32) & 255);
          emitCode((v >> 40) & 255);
          emitCode((v >> 48) & 255);
     }
     if (((v < 0) && ((v >> 56) != -1L)) || ((v > 0) && ((v >> 56) != 0L)) || (force && (code_bits > 56 || data_bits > 56))) {
          emitAlignedCode(0xfe);
          emitCode((v >> 56) & 255);
          emitCode(0x00);
          emitCode(0x00);
          emitCode(0x00);
     }
}

// ---------------------------------------------------------------------------
// Emit constant extension for 32-bit operands.
// ---------------------------------------------------------------------------

static void emitImm32(int64_t v, int force)
{
     if (v < -2147483648LL || v > 2147483647LL || force) {
          emitAlignedCode(0xfd);
          emitCode((v >> 32) & 255);
          emitCode((v >> 40) & 255);
          emitCode((v >> 48) & 255);
          emitCode((v >> 56) & 255);
     }
}

// ---------------------------------------------------------------------------
// addi r1,r2,#1234
// ---------------------------------------------------------------------------

static void process_riop(int opcode7)
{
    int Ra;
    int Rt;
    char *p;
    int64_t val;
    
    p = inptr;
    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
    need(',');
    NextToken();
    val = expr();
    if (val < -2147483648LL || val > 2147483647LL) {
        emit_insn((0x4080 << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
        emit_insn(val,0);
        emit_insn(val>>32,0);
    }
    else if ((val < -16000LL || val > 16383LL)) {
      {
        emit_insn((0x4000 << 17)|(Rt << 12)|(Ra << 7)|opcode7,1);
        emit_insn(val,0);
      }
    }
    else
      emit_insn(((val & 0x7FFF) << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_rrop(int funct7)
{
    int Ra,Rb,Rt;
    char *p;

    p = inptr;
    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
    need(',');
    NextToken();
    if (token=='#') {
        inptr = p;
        process_riop(funct7);
        return;
    }
    prevToken();
    Rb = getRegisterX();
    //prevToken();
    emit_insn((funct7<<25)|(Rt<<17)|(Rb<<12)|(Ra<<7)|0x02,1);
}
       
// ---------------------------------------------------------------------------
// jmp main
// jsr [r19]
// jmp (tbl,r2)
// jsr [gp+r20]
// ---------------------------------------------------------------------------

static void process_jal()
{
    int64_t addr;
    int Ra, Rb;
    int Rt;
    
    Rt = 0;
    NextToken();
    if (token=='(' || token=='[') {
j1:
       Ra = getRegisterX();
       if (Ra==-1) {
           printf("Expecting a register\r\n");
           return;
       }
       // Simple jmp [Rn]
       else {
            if (token != ')' && token!=']')
                printf("Missing close bracket\r\n");
            emit_insn((Ra << 15)|(Rt<<7)|0x67,1);
            return;
       }
    }
    prevToken();
    Rt = getRegisterX();
    printf("Rt=%d ", Rt);
    if (Rt >= 0) {
        need(',');
        NextToken();
        // jal Rt,[Ra]
        if (token=='(' || token=='[')
           goto j1;
    }
    else
        Rt = 0;
    addr = expr() - code_address;
    printf("Addr=%ld ", addr);
    prevToken();
    // d(Rn)? 
    if (token=='(' || token=='[') {
        printf("a ");
        NextToken();
        Ra = getRegisterX();
        if (Ra==-1) {
            printf("Illegal jump address mode.\r\n");
            Ra = 0;
        }
j2:
        if (addr < -2048 || addr > 2047)
            emit_insn((addr & 0xFFFFF000)|0x37,1);
        emit_insn(((addr & 0xFFF) << 20)|(Ra<<15)|(Rt << 7)|0x67,1);
        return;
    }
    printf("b ");
    if (addr > 524287 || addr < -524288) {
        Ra = 0;
        goto j2;
    }
    printf("emit_insn \r\n");
    emit_insn(
        (((addr & 0x100000)>>20)<< 31) |
        (((addr & 0x7FE)>>1) << 21) |
        (((addr & 0x800)>>11) << 20) |
        (((addr & 0xFF000)>>12) << 12) |
        (Rt << 7) |
        0x6F, 0
    );
}

// ---------------------------------------------------------------------------
// subui r1,r2,#1234
// ---------------------------------------------------------------------------
/*
static void process_riop(int oc)
{
    int Ra;
    int Rt;
    char *p;
    int64_t val;
    
    p = inptr;
    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
    need(',');
    NextToken();
    val = expr();

   if (lastsym != (SYM *)NULL)
       emitImm16(val,!lastsym->defined);
   else
       emitImm16(val,0);

    emitImm16(val,lastsym!=(SYM*)NULL);
    emitAlignedCode(oc);
    if (bGen)
    if (lastsym && !use_gp) {
        if( lastsym->segment < 5)
        sections[segment+7].AddRel(sections[segment].index,((lastsym->ord+1) << 32) | 3 | (lastsym->isExtern ? 128 : 0) |
        (lastsym->segment==codeseg ? code_bits << 8 : data_bits << 8));
    }
    emitCode(Ra);
    emitCode(Rt);
    emitCode(val & 255);
    emitCode((val >> 8) & 255);
}
*/
// ---------------------------------------------------------------------------
// fabs.d fp1,fp2[,rm]
// ---------------------------------------------------------------------------

static void process_fprop(int oc)
{
    int Ra;
    int Rt;
    char *p;
    int  sz;
    int fmt;
    int rm;

    rm = 0;
    sz = 'd';
    if (*inptr=='.') {
        inptr++;
        if (strchr("sdtqSDTQ",*inptr)) {
            sz = tolower(*inptr);
            inptr++;
        }
        else
            printf("Illegal float size.\r\n");
    }
    p = inptr;
    if (oc==0xF6)        // fcmp
        Rt = getRegisterX();
    else
        Rt = getFPRegister();
    need(',');
    Ra = getFPRegister();
    if (token==',')
       rm = getFPRoundMode();
    prevToken();
    emitAlignedCode(0x01);
    emitCode(Ra);
    emitCode(Rt);
    switch(sz) {
    case 's': fmt = 0; break;
    case 'd': fmt = 1; break;
    case 't': fmt = 2; break;
    case 'q': fmt = 3; break;
    }
    emitCode((fmt << 3)|rm);
    emitCode(oc);
}

// ---------------------------------------------------------------------------
// fadd.d fp1,fp2,fp12[,rm]
// fcmp.d r1,fp3,fp10[,rm]
// ---------------------------------------------------------------------------

static void process_fprrop(int oc)
{
    int Ra;
    int Rb;
    int Rt;
    char *p;
    int  sz;
    int fmt;
    int rm;

    rm = 0;
    sz = 'd';
    if (*inptr=='.') {
        inptr++;
        if (strchr("sdtqSDTQ",*inptr)) {
            sz = tolower(*inptr);
            inptr++;
        }
        else
            printf("Illegal float size.\r\n");
    }
    p = inptr;
    if (oc==0xF6)        // fcmp
        Rt = getRegisterX();
    else
        Rt = getFPRegister();
    need(',');
    Ra = getFPRegister();
    need(',');
    Rb = getFPRegister();
    if (token==',')
       rm = getFPRoundMode();
    prevToken();
    emitAlignedCode(oc);
    emitCode(Ra);
    emitCode(Rb);
    emitCode(Rt);
    switch(sz) {
    case 's': fmt = 0; break;
    case 'd': fmt = 1; break;
    case 't': fmt = 2; break;
    case 'q': fmt = 3; break;
    }
    emitCode((fmt << 3)|rm);
}

// ---------------------------------------------------------------------------
// fcx r0,#2
// fdx r1,#0
// ---------------------------------------------------------------------------

static void process_fpstat(int oc)
{
    int Ra;
    int64_t bits;
    char *p;

    p = inptr;
    bits = 0;
    Ra = getRegisterX();
    if (token==',') {
       NextToken();
       bits = expr();
    }
    prevToken();
    emitAlignedCode(0x01);
    emitCode(Ra);
    emitCode(bits & 0xff);
    emitCode(0x00);
    emitCode(oc);
}

// ---------------------------------------------------------------------------
// not r3,r3
// ---------------------------------------------------------------------------

static void process_rop(int oc)
{
    int Ra;
    int Rt;

    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
//    prevToken();
    emitAlignedCode(1);
    emitCode(Ra);
    emitCode(Rt);
    emitCode(0x00);
    emitCode(oc);
}

// ---------------------------------------------------------------------------
// brnz r1,label
// ---------------------------------------------------------------------------

static void process_bcc(int opcode4)
{
    int Ra, Rb;
    int64_t val;
    int64_t disp;

    Ra = getRegisterX();
    need(',');
    Rb = getRegisterX();
    need(',');
    NextToken();
    val = expr();
    disp = val - code_address;
    printf("exmit branch\r\n");
    emit_insn((disp & 0x7FFF) << 17 |
        (Rb << 12) |
        (Ra << 7) |
        0x10 |
        opcode4,0
    );
}

// ---------------------------------------------------------------------------
// bra label
// ---------------------------------------------------------------------------

static void process_bra(int oc)
{
    int64_t val;
    int64_t disp;
    int64_t ad;

    NextToken();
    val = expr();
    ad = code_address + 5;
    if ((ad & 15)==15)
       ad++;
    disp = ((val & 0xFFFFFFFFFFFFF000L) - (ad & 0xFFFFFFFFFFFFF000L)) >> 12; 
    emitAlignedCode(oc);
    emitCode(0x00);
    emitCode(val & 255);
    emitCode(((disp & 15) << 4)|((val >> 8) & 15));
    if (oc==0x56)   // BSR
        emitCode((disp >> 4) & 255);
    else
        emitCode((disp >> 4) & 31);
}

// ---------------------------------------------------------------------------
// expr
// expr[Reg]
// expr[Reg+Reg*sc]
// [Reg]
// [Reg+Reg*sc]
// ---------------------------------------------------------------------------

static void mem_operand(int64_t *disp, int *regA)
{
     int64_t val;

     // chech params
     if (disp == (int64_t *)NULL)
         return;
     if (regA == (int *)NULL)
         return;

     *disp = 0;
     *regA = -1;
     if (token!='[') {;
          val = expr();
          *disp = val;
     }
     if (token=='[') {
         *regA = getRegisterX();
         if (*regA == -1) {
             printf("expecting a register\r\n");
         }
         need(']');
     }
}

// ---------------------------------------------------------------------------
// sw disp[r1],r2
// sw [r1+r2],r3
// ----------------------------------------------------------------------------

static void process_store(int opcode7)
{
    int Ra;
    int Rs;
    int64_t disp,val;

    Rs = getRegisterX();
    if (Rs < 0) {
        printf("Expecting a source register.\r\n");
        ScanToEOL();
        return;
    }
    expect(',');
    mem_operand(&disp, &Ra);
    if (Ra < 0) Ra = 0;
    if ((disp < -2048 || disp > 2047) && OPTLUI0) {
        emit_insn((disp & 0xFFFFF000)|(0 << 7)|0x37,1); // LUI
    }
    val = disp;
    if (val < -2147483648LL || val > 2147483647LL) {
        emit_insn((0x4080 << 17)|(Rs << 12)|(Ra << 7)|opcode7,!expand_flag);
        emit_insn(val,0);
        emit_insn(val>>32,0);
    }
    else if ((val < -16000LL || val > 16383LL)) {
      {
        emit_insn((0x4000 << 17)|(Rs << 12)|(Ra << 7)|opcode7,1);
        emit_insn(val,0);
      }
    }
    else
      emit_insn(((val & 0x7FFF) << 17)|(Rs << 12)|(Ra << 7)|opcode7,!expand_flag);
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_ldi()
{
       int Ra = 0;
    int Rt;
    int64_t val;
    int opcode7 = 0x09;  // ORI

    Rt = getRegisterX();
    expect(',');
    val = expr();
    if (val < -2147483648LL || val > 2147483647LL) {
        emit_insn((0x4080 << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
        emit_insn(val,0);
        emit_insn(val>>32,0);
        printf("64 bit constant");
    }
    else if ((val < -16000LL || val > 16383LL)) {
      {
        emit_insn((0x4000 << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
        emit_insn(val,0);
      }
    }
    else
      emit_insn(((val & 0x7FFF) << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
}

// ----------------------------------------------------------------------------
// lw r1,disp[r2]
// lw r1,[r2+r3]
// ----------------------------------------------------------------------------

static void process_load(int opcode7)
{
    int Ra;
    int Rt;
    char *p;
    int64_t disp;
    int64_t val;
    int fixup = 5;

    p = inptr;
    Rt = getRegisterX();
    if (Rt < 0) {
        printf("Expecting a target register.\r\n");
//        printf("Line:%.60s\r\n",p);
        ScanToEOL();
        inptr-=2;
        return;
    }
    expect(',');
    mem_operand(&disp, &Ra);
    if (Ra < 0) Ra = 0;
    val = disp;
    if (val < -2147483648LL || val > 2147483647LL) {
        emit_insn((0x4080 << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
        emit_insn(val,0);
        emit_insn(val>>32,0);
        printf("64 bit constant");
    }
    else if ((val < -16000LL || val > 16383LL)) {
      {
        emit_insn((0x4000 << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
        emit_insn(val,0);
      }
    }
    else
      emit_insn(((val & 0x7FFF) << 17)|(Rt << 12)|(Ra << 7)|opcode7,!expand_flag);
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// mov r1,r2
// ----------------------------------------------------------------------------

static void process_mov(int oc)
{
     int Ra;
     int Rt;
     
     Rt = getRegisterX();
     need(',');
     Ra = getRegisterX();
     emitAlignedCode(0x01);
     emitCode(Ra);
     emitCode(Rt);
     emitCode(0x00);
     emitCode(oc);
//     prevToken();
}

// ----------------------------------------------------------------------------
// rts
// rts #24
// ----------------------------------------------------------------------------

static void process_rts(int oc)
{
     int64_t val;

     val = 0;
     NextToken();
     if (token=='#') {
        val = expr();
     }
     emitAlignedCode(oc);
     emitCode(0x00);
     emitCode(val & 255);
     emitCode((val >> 8) & 255);
     emitCode(0x00);
}

// ----------------------------------------------------------------------------
// srli r1,r2,#5
// ----------------------------------------------------------------------------

static void process_shifti(int funct7)
{
     int Ra;
     int Rt;
     int64_t val;
     
     Rt = getRegisterX();
     need(',');
     Ra = getRegisterX();
     need(',');
     NextToken();
     val = expr();
     emit_insn((funct7 << 25) | ((val & 0x20) << 22) | (Rt << 17)| ((val & 0x1F) << 12) | (Ra << 7) | 0x02,1);  // ORI
}

// ----------------------------------------------------------------------------
// gran r1
// ----------------------------------------------------------------------------

static void process_gran(int oc)
{
    int Rt;

    Rt = getRegisterX();
    emitAlignedCode(0x01);
    emitCode(0x00);
    emitCode(Rt);
    emitCode(0x00);
    emitCode(oc);
    prevToken();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_mtspr(int oc)
{
    int spr;
    int Ra;
    
    spr = DSD6_getSprRegister();
    need(',');
    Ra = getRegisterX();
    emitAlignedCode(0x01);
    emitCode(Ra);
    emitCode(spr);
    emitCode(0x00);
    emitCode(oc);
    if (Ra >= 0)
    prevToken();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_mtfp(int oc)
{
    int fpr;
    int Ra;
    
    fpr = getFPRegister();
    need(',');
    Ra = getRegisterX();
    emitAlignedCode(0x01);
    emitCode(Ra);
    emitCode(fpr);
    emitCode(0x00);
    emitCode(oc);
    if (Ra >= 0)
    prevToken();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_mfspr(int oc)
{
    int spr;
    int Rt;
    
    Rt = getRegisterX();
    need(',');
    spr = DSD6_getSprRegister();
    emitAlignedCode(0x01);
    emitCode(spr);
    emitCode(Rt);
    emitCode(0x00);
    emitCode(oc);
    if (spr >= 0)
    prevToken();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_mffp(int oc)
{
    int fpr;
    int Rt;
    
    Rt = getRegisterX();
    need(',');
    fpr = getFPRegister();
    emitAlignedCode(0x01);
    emitCode(fpr);
    emitCode(Rt);
    emitCode(0x00);
    emitCode(oc);
    if (fpr >= 0)
    prevToken();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_fprdstat(int oc)
{
    int Rt;
    
    Rt = getRegisterX();
    emitAlignedCode(0x01);
    emitCode(0x00);
    emitCode(Rt);
    emitCode(0x00);
    emitCode(oc);
}

static void process_csrrw()
{
  int Rd;
  int Rs;
  int64_t val;
  
  Rd = getRegisterX();
  need(',');
  NextToken();
  val = expr();
  Rs = getRegisterX();
  need(',');
  emit_insn((val << 20) | (Rs << 15) | (1 << 12) | (Rd << 7) | 0x73,!expand_flag);
}

static void process_sync(int oc)
{
    emit_insn(oc,!expand_flag);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void ProcessEOL(int opt)
{
    int nn,mm;
    int first;
    int cc;
    
     //printf("Line: %d\r", lineno);
     expand_flag = 0;
     compress_flag = 0;
     segprefix = -1;
     if (bGen && (segment==codeseg || segment==dataseg || segment==rodataseg)) {
    nn = binstart;
    cc = 8;
    if (segment==codeseg) {
       cc = 4;
/*
        if (sections[segment].bytes[binstart]==0x61) {
            fprintf(ofp, "%06LLX ", ca);
            for (nn = binstart; nn < binstart + 5 && nn < sections[segment].index; nn++) {
                fprintf(ofp, "%02X ", sections[segment].bytes[nn]);
            }
            fprintf(ofp, "   ; imm\n");
             if (((ca+5) & 15)==15) {
                 ca+=6;
                 binstart+=6;
                 nn++;
             }
             else {
                  ca += 5;
                  binstart += 5;
             }
        }
*/
/*
        if (sections[segment].bytes[binstart]==0xfd) {
            fprintf(ofp, "%06LLX ", ca);
            for (nn = binstart; nn < binstart + 5 && nn < sections[segment].index; nn++) {
                fprintf(ofp, "%02X ", sections[segment].bytes[nn]);
            }
            fprintf(ofp, "   ; imm\n");
             if (((ca+5) & 15)==15) {
                 ca+=6;
                 binstart+=6;
                 nn++;
             }
             else {
                  ca += 5;
                  binstart += 5;
             }
        }
         if (sections[segment].bytes[binstart]==0xfe) {
            fprintf(ofp, "%06LLX ", ca);
            for (nn = binstart; nn < binstart + 5 && nn < sections[segment].index; nn++) {
                fprintf(ofp, "%02X ", sections[segment].bytes[nn]);
            }
            fprintf(ofp, "   ; imm\n");
             if (((ca+5) & 15)==15) {
                 ca+=6;
                 nn++;
             }
             else {
                  ca += 5;
             }
        }
*/
    }

    first = 1;
    while (nn < sections[segment].index) {
        fprintf(ofp, "%06LLX ", ca);
        for (mm = nn; nn < mm + cc && nn < sections[segment].index; nn++) {
            fprintf(ofp, "%02X ", sections[segment].bytes[nn]);
        }
        for (; nn < mm + cc; nn++)
            fprintf(ofp, "   ");
        if (first & opt) {
            fprintf(ofp, "\t%.*s\n", inptr-stptr-1, stptr);
            first = 0;
        }
        else
            fprintf(ofp, opt ? "\n" : "; NOP Ramp\n");
        ca += cc;
    }
    // empty (codeless) line
    if (binstart==sections[segment].index) {
        fprintf(ofp, "%24s\t%.*s", "", inptr-stptr, stptr);
    }
    } // bGen
    if (opt) {
       stptr = inptr;
       lineno++;
    }
    binstart = sections[segment].index;
    ca = sections[segment].address;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void dsd6_processMaster()
{
    int nn,mm;
    int64_t bs1, bs2;

    lineno = 1;
    binndx = 0;
    binstart = 0;
    bs1 = 0;
    bs2 = 0;
    inptr = &masterFile[0];
    stptr = inptr;
    code_address = 0;
    bss_address = 0;
    start_address = 0;
    first_org = 1;
    first_rodata = 1;
    first_data = 1;
    first_bss = 1;
    if (pass<3) {
    htblmax = 0;
    for (nn = 0; nn < 100000; nn++) {
      hTable[nn].count = 0;
      hTable[nn].opcode = 0;
    }
    }
    for (nn = 0; nn < 12; nn++) {
        sections[nn].index = 0;
        if (nn == 0)
        sections[nn].address = 0;
        else
        sections[nn].address = 0;
        sections[nn].start = 0;
        sections[nn].end = 0;
    }
    ca = code_address;
    segment = codeseg;
    memset(current_label,0,sizeof(current_label));
    NextToken();
    while (token != tk_eof) {
//        printf("\t%.*s\n", inptr-stptr-1, stptr);
//        printf("token=%d\r", token);
        switch(token) {
        case tk_eol: ProcessEOL(1); break;
//        case tk_add:  process_add(); break;
        case tk_add:  process_rrop(0x04); break;
        case tk_addi: process_riop(0x04); break;
        case tk_align: process_align(); continue; break;
        case tk_and:  process_rrop(0x08); break;
        case tk_andi:  process_riop(0x08); break;
        case tk_beq: process_bcc(0); break;
        case tk_bge: process_bcc(3); break;
        case tk_bgeu: process_bcc(7); break;
        case tk_bgt: process_bcc(5); break;
        case tk_bgtu: process_bcc(9); break;
        case tk_ble: process_bcc(4); break;
        case tk_bleu: process_bcc(8); break;
        case tk_blt: process_bcc(2); break;
        case tk_bltu: process_bcc(6); break;
        case tk_bne: process_bcc(1); break;
        case tk_bra: process_bra(0x46); break;
        case tk_bsr: process_bra(0x56); break;
        case tk_bss:
            if (first_bss) {
                while(sections[segment].address & 4095)
                    emitByte(0x00);
                sections[3].address = sections[segment].address;
                first_bss = 0;
                binstart = sections[3].index;
                ca = sections[3].address;
            }
            segment = bssseg;
            break;
        case tk_cli: emit_insn(0x3100000001,1); break;
        case tk_code: process_code(); break;
        case tk_com: process_rop(0x06); break;
        case tk_cs:  segprefix = 15; break;
        case tk_csrrw: process_csrrw(); break;
        case tk_data:
            if (first_data) {
                while(sections[segment].address & 4095)
                    emitByte(0x00);
                sections[2].address = sections[segment].address;   // set starting address
                first_data = 0;
                binstart = sections[2].index;
                ca = sections[2].address;
            }
            process_data(dataseg);
            break;
        case tk_db:  process_db(); break;
        case tk_dc:  process_dc(); break;
        case tk_dh:  process_dh(); break;
//        case tk_div: process_rrop(0x08); break;
//        case tk_divu: process_rrop(0x18); break;
        case tk_dw:  process_dw(); break;
        case tk_end: goto j1;
        case tk_endpublic: break;
        case tk_eor: process_rrop(0x0A); break;
        case tk_eori: process_riop(0x0A); break;
        case tk_extern: process_extern(); break;
        case tk_fabs: process_fprop(0x88); break;
        case tk_fadd: process_fprrop(0xF4); break;
        case tk_fcmp: process_fprrop(0xF6); break;
        case tk_fdiv: process_fprrop(0xF8); break;
        case tk_fill: process_fill(); break;
        case tk_fix2flt: process_fprop(0x84); break;
        case tk_flt2fix: process_fprop(0x85); break;
        case tk_fmov: process_fprop(0x87); break;
        case tk_fmul: process_fprrop(0xF7); break;
        case tk_fnabs: process_fprop(0x89); break;
        case tk_fneg: process_fprop(0x8A); break;
        case tk_frm: process_fpstat(0x78); break;
        case tk_fstat: process_fprdstat(0x86); break;
        case tk_fsub: process_fprrop(0xF5); break;
        case tk_ftx: process_fpstat(0x75); break;
        case tk_gran: process_gran(0x14); break;
        case tk_jal: process_jal(); break;
        case tk_jmp: process_jal(); break;
        case tk_lb:  process_load(0x40); break;
        case tk_lbu: process_load(0x41); break;
        case tk_lc:  process_load(0x42); break;
        case tk_lcu: process_load(0x43); break;
        case tk_ldi: process_ldi(); break;
        case tk_lh:  process_load(0x44); break;
        case tk_lhu: process_load(0x45); break;
//        case tk_lui: process_lui(); break;
        case tk_lw:  process_load(0x46); break;
        case tk_lwar:  process_load(0x47); break;
        case tk_mfspr: process_mfspr(0x49); break;
        case tk_mov: process_mov(0x04); break;
        case tk_mtspr: process_mtspr(0x48); break;
        case tk_mul: process_rrop(0x60); break;
        case tk_neg: process_rop(0x05); break;
        case tk_nop: emit_insn(0xEAEAEAEAEA,1); break;
        case tk_not: process_rop(0x07); break;
        case tk_or:  process_rrop(0x09); break;
        case tk_ori: process_riop(0x09); break;
        case tk_org: process_org(); break;
        case tk_php: emit_insn(0x3200000001,1); break;
        case tk_plp: emit_insn(0x3300000001,1); break;
        case tk_plus: expand_flag = 1; break;
        case tk_public: process_public(); break;
        case tk_rodata:
            if (first_rodata) {
                while(sections[segment].address & 4095)
                    emitByte(0x00);
                sections[1].address = sections[segment].address;
                first_rodata = 0;
                binstart = sections[1].index;
                ca = sections[1].address;
            }
            segment = rodataseg;
            break;
        case tk_rti: emit_insn(0x4000000001,1); break;
        case tk_rts: process_rts(0x60); break;
        case tk_sb:  process_store(0x48); break;
        case tk_sc:  process_store(0x49); break;
        case tk_sei: emit_insn(0x3000000001,1); break;
        //case tk_slt:  process_rrop(0x33,0x02,0x00); break;
        //case tk_sltu:  process_rrop(0x33,0x03,0x00); break;
        //case tk_slti:  process_riop(0x13,0x02); break;
        //case tk_sltui:  process_riop(0x13,0x03); break;
        case tk_sh:  process_store(0x4A); break;
        case tk_slli: process_shifti(0x18); break;
        case tk_srai: process_shifti(0x1A); break;
        case tk_srli: process_shifti(0x19); break;
        case tk_sub:  process_rrop(0x07); break;
//        case tk_sub:  process_sub(); break;
        case tk_sxb: process_rop(0x08); break;
        case tk_sxc: process_rop(0x09); break;
        case tk_sxh: process_rop(0x0A); break;
        case tk_sw:  process_store(0x4B); break;
        case tk_swap: process_rop(0x03); break;
        case tk_sync: process_sync(0x77); break;
        case tk_xor: process_rrop(0x0A); break;
        case tk_xori: process_riop(0x0A); break;
        case tk_id:  process_label(); break;
        case '-': compress_flag = 1; break;
        }
        NextToken();
    }
j1:
    ;
}

