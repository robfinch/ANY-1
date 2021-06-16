// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2018  Robert Finch, Waterloo
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
#include "stdafx.h"

static void process_shifti(int oc, int funct3, int funct7);
static void ProcessEOL(int opt);
extern void process_message();
static void mem_operand(int64_t *disp, int *regA, int *regB, int *Sc);
extern void emitNybble(int64_t);
extern char *pif1;
extern int first_rodata;
extern int first_data;
extern int first_bss;
extern int htable[100000];
extern int htblcnt[100000];
extern int htblmax;
extern int pass;

static double ca;

extern int use_gp;

#define OPT64     0
#define OPTX32    1
#define OPTLUI0   0
#define LB16	-31653LL

static int regSP = 63;
static int regFP = 62;
static int regLR = 61;
static int regXL = 60;
static int regGP = 59;
static int regTP = 58;
static int regCnst;

// ----------------------------------------------------------------------------
// Return the register number or -1 if not a register.
// Parses pretty register names like SP or BP in addition to r1,r2,etc.
// ----------------------------------------------------------------------------

static int getRegisterX()
{
    int reg;

    while(isspace(*inptr)) inptr++;
	if (*inptr == '$')
		inptr++;
    switch(*inptr) {
    case 'r': case 'R':
        if ((inptr[1]=='a' || inptr[1]=='A') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return regLR;
        }
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
             reg = inptr[1]-'0' + 35;
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
            return regFP;
        }
        break;
    case 'g': case 'G':
        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return regGP;
        }
        break;
    case 'p': case 'P':
        if ((inptr[1]=='C' || inptr[1]=='c') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 31;
        }
        break;
    case 's': case 'S':
        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return (regSP);
        }
        break;
    case 't': case 'T':
         if (isdigit(inptr[1])) {
             reg = inptr[1]-'0' + 5;
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
             if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 NextToken();
                 return (reg);
             }
         }
        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return (regTP);
        }
        /*
        if ((inptr[1]=='R' || inptr[1]=='r') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return 24;
        }
        */
        break;
	// lr
    case 'l': case 'L':
        if ((inptr[1]=='R' || inptr[1]=='r') && !isIdentChar(inptr[2])) {
            inptr += 2;
            NextToken();
            return (regLR);
        }
        break;
	// xlr
    case 'x': case 'X':
        if ((inptr[1]=='L' || inptr[1]=='l') && (inptr[2]=='R' || inptr[2]=='r') && 
			!isIdentChar(inptr[3])) {
            inptr += 3;
            NextToken();
            return (regXL);
        }
        break;
	case 'v': case 'V':
         if (isdigit(inptr[1])) {
             reg = inptr[1]-'0' + 1;
             if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 NextToken();
                 return (reg);
             }
         }
		 break;
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

int GetConstantReg()
{
	static int which = 51;
	which++;
	if (which > 55)
		which = 52;
	regCnst = which;
	return (which);
}

// ----------------------------------------------------------------------------
// Return the register number or -1 if not a register.
// Parses pretty register names like SP or BP in addition to r1,r2,etc.
// ----------------------------------------------------------------------------

static int getVecRegister()
{
    int reg;

    while(isspace(*inptr)) inptr++;
    switch(*inptr) {
    case 'v': case 'V':
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
		 else if (inptr[1]=='l' || inptr[1]=='L') {
			 if (!isIdentChar(inptr[2])) {
				 inptr += 2;
				 NextToken();
				 return 0x28;
			 }
		 }
         else if (inptr[1]=='m' || inptr[1]=='M') {
			 if (isdigit(inptr[2])) {
				 if (inptr[2] >= '0' && inptr[2] <= '7') {
					 if (!isIdentChar(inptr[3])) {
						 return 0x20 | (inptr[2]-'0');
					 }
				 }
			 }
		 }
		 return -1;
	}
    return -1;
}

// ----------------------------------------------------------------------------
// Get the friendly name of a special purpose register.
// ----------------------------------------------------------------------------

static int DSD7_getSprRegister()
{
    int reg = -1;
    int pr;

    while(isspace(*inptr)) inptr++;
//    reg = getCodeareg();
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
         return (int)ival.low & 0xFFF;

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
// Process the size specifier for a FP instruction.
// ---------------------------------------------------------------------------
static int GetFPSize()
{
	int sz;

    sz = 'q';
    if (*inptr=='.') {
        inptr++;
        if (strchr("sdtqSDTQ",*inptr)) {
            sz = tolower(*inptr);
            inptr++;
        }
        else
            printf("Illegal float size.\r\n");
    }
	switch(sz) {
	case 's':	sz = 0; break;
	case 'd':	sz = 1; break;
	case 't':	sz = 2; break;
	case 'q':	sz = 3; break;
	default:	sz = 3; break;
	}
	return (sz);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void emit_prefix(int64_t val)
{
	// Fit in 42 bits ?
	if (val < -0x20000000000LL || val > 0x1FFFFFFFFFFLL) {
		emitCode((((val >> 16) & 3) << 6) | 0x1A);
		emitCode((val >> 18) & 255);
		emitCode((val >> 26) & 255);
		emitCode((val >> 34) & 255);
		emitCode((((val >> 42) & 3) << 6) | 0x1B);
		emitCode((val >> 44) & 255);
		emitCode((val >> 52) & 255);
		emitCode((val >> 60) & 255);
	}
	// Fit in 16 bits ?
	else if (val < -32768 || val > 32768) {
		emitCode((((val >> 16) & 3) << 6) | 0x1A);
		emitCode((val >> 18) & 255);
		emitCode((val >> 26) & 255);
		emitCode((val >> 34) & 255);
	}
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void emit_insn(int64_t oc, int can_compress, int sz)
{
    int ndx;

    if (pass==3 && can_compress && gCanCompress) {
       for (ndx = 0; ndx < htblmax; ndx++) {
         if ((int)oc == hTable[ndx].opcode) {
           hTable[ndx].count++;
           return;
         }
       }
       if (htblmax < 100000) {
          hTable[htblmax].opcode = (int)oc;
          hTable[htblmax].count = 1;
          htblmax++;
          return;  
       }
       printf("Too many instructions.\r\n");
       return;
    }
    if (pass > 3) {
     if (can_compress && gCanCompress) {
       for (ndx = 0; ndx < htblmax; ndx++) {
         if ((int)oc == hTable[ndx].opcode) {
           emitCode((ndx << 6)|0x1F);
		   num_bytes += 2;
		   num_insns += 1;
           return;
         }
       }
     }
	 emitNybble(oc & 15);
	 emitNybble((oc >> 4) & 15);
	 emitNybble((oc >> 8) & 15);
	 emitNybble((oc >> 12) & 15);
	 emitNybble((oc >> 16) & 15);
	 emitNybble((oc >> 20) & 15);
	 emitNybble((oc >> 24) & 15);
	 emitNybble((oc >> 28) & 15);
	 emitNybble((oc >> 32) & 15);
     num_bytes += 4.5;
	if ((code_address & 31)==31)
		 emitNybble(0);

	//if (sz==3) {
	//	emitCode((int)(oc >> 16));
 //	    num_bytes += 2;
	//	emitCode(oc >> 32);
 //	    num_bytes += 2;
	//}
    num_insns += 1;
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
    */
    }
}
 
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
static void getSz(int *sz)
{
	if (*inptr=='.')
		inptr++;
    *sz = inptr[0];
    switch(*sz) {
    case 'b': case 'B': *sz = 0; break;
    case 'c': case 'C': *sz = 1; break;
    case 'h': case 'H': *sz = 2; break;
    case 'w': case 'W': *sz = 3; break;
	case 'd': case 'D': *sz = 0x83; break;
	case 'i': case 'I': *sz = 0x43; break;
    default: 
             printf("%d bad size.\r\n", lineno);
             *sz = 3;
    }
    inptr += 1;
}

// ---------------------------------------------------------------------------
// addi r1,r2,#1234
//
// A value that is too large has to be loaded into a register then the
// instruction converted to a registered form.
// So
//		addi	r1,r2,#$12345678
// Becomes:
//		ori		r23,r0,#$5678
//		oriq1	r23,#$1234
//		addi	r1,r2,r23
// ---------------------------------------------------------------------------

static void process_riop(int64_t opcode6)
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
	if (opcode6==0x05)	{ // subi
		val = -val;
		opcode6 = 0x04;	// change to addi
	}
	if (val < -131072 || val > 131072) {
		GetConstantReg();
		emit_insn(
			(val << 18) |
			(regCnst << 12) |
			(0 << 6) |
			0x09,!expand_flag,4);	// ORI
		val >>= 16;
		emit_insn(
			(val << 18) |
			(regCnst << 12) |
			(0 << 6) |
			(1 << 6) |
			0x1A,!expand_flag,4);	// ORQ1
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 18) |
				(regCnst << 12) |
				(0 << 6) |
				(2 << 6) |
				0x1A,!expand_flag,4);	// ORQ2
		}
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 18) |
				(regCnst << 12) |
				(0 << 6) |
				(3 << 6) |
				0x1A,!expand_flag,4);	// ORQ3
		}
		emit_insn(
			(opcode6 << 30) |
			(3 << 24) |		// set size to word size op
			(Rt << 18) |
			(regCnst << 12) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		return;
	}
	emit_insn(((val & 0x3FFFF) << 18)|(Rt << 12)|(Ra << 6)|opcode6,!expand_flag,4);
}

// ---------------------------------------------------------------------------
// slti r1,r2,#1234
//
// A value that is too large has to be loaded into a register then the
// instruction converted to a registered form.
// ---------------------------------------------------------------------------

static void process_setiop(int opcode6, int cond4)
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
	if (val < -1024 || val > 1023) {
		GetConstantReg();
		emit_insn(
			(val << 16) |
			(regCnst << 11) |
			(0 << 6) |
			0x09,!expand_flag,4);	// ORI
		val >>= 16;
		emit_insn(
			(val << 16) |
			(regCnst << 11) |
			(0 << 6) |
			(1 << 6) |
			0x1A,!expand_flag,4);	// ORQ1
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 16) |
				(regCnst << 11) |
				(0 << 6) |
				(2 << 6) |
				0x1A,!expand_flag,4);	// ORQ2
		}
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 16) |
				(regCnst << 11) |
				(0 << 6) |
				(3 << 6) |
				0x1A,!expand_flag,4);	// ORQ3
		}
		emit_insn(
			(((cond4 >= 12 && cond4 <= 15) ? 7 : 6) << 26) |
			((cond4 & 7) << 23) |
			(3 << 21) |		// set size to word size op
			(Rt << 16) |
			(regCnst << 11) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		return;
	}
	emit_insn(
		(cond4<<28)|
		((val & 0xFFF) << 16)|
		(Rt << 11)|(Ra << 6)|
		opcode6,!expand_flag,4);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_rrop(int64_t funct6)
{
    int Ra,Rb,Rt;
    char *p;
	int sz = 3;

    p = inptr;
	if (*p=='.')
		getSz(&sz);
    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
    need(',');
    NextToken();
    if (token=='#') {
        inptr = p;
        process_riop(funct6);
        return;
    }
    prevToken();
    Rb = getRegisterX();
    //prevToken();
	if (funct6==0x2ELL || funct6==0x2CLL || funct6==0x2DLL) {
		funct6 += 0x10LL;	// change to divmod
	    emit_insn((funct6<<30)||(Rt<<24)|(Rb<<12)|(Ra<<6)|0x02,!expand_flag,4);
		return;
	}
	// No size is emitted for divides
	else if (funct6==0x3CLL || funct6==0x3DLL || funct6==0x3ELL) {
	    emit_insn((funct6<<30)||(Rt<<18)|(Rb<<12)|(Ra<<6)|0x02,!expand_flag,4);
		return;
	}
	if (funct6==0x07) {	// CMPU
	    emit_insn((0x06LL<<30)|(0x01 << 26)|(sz << 24)|(Rt<<18)|(Rb<<12)|(Ra<<6)|0x02,!expand_flag,4);
		return;
	}
    emit_insn((funct6<<30)|(sz << 24)|(Rt<<18)|(Rb<<12)|(Ra<<6)|0x02,!expand_flag,4);
}
       
// ---------------------------------------------------------------------------
// jmp main
// jal [r19]
// ---------------------------------------------------------------------------

static void process_jal(int oc)
{
    int64_t addr, val;
    int Ra;
    int Rt;
	bool noRt;

	noRt = false;
	Ra = 0;
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
            emit_insn((Ra << 6)|(Rt<<11)|0x18,0,4);
            return;
       }
    }
    prevToken();
    Rt = getRegisterX();
    if (Rt >= 0) {
        need(',');
        NextToken();
        // jal Rt,[Ra]
        if (token=='(' || token=='[')
           goto j1;
    }
    else {
        Rt = 0;
		noRt = true;
	}
	addr = expr();
    // d(Rn)? 
    //NextToken();
    if (token=='(' || token=='[') {
        Ra = getRegisterX();
        if (Ra==-1) {
            printf("Illegal jump address mode.\r\n");
            Ra = 0;
        }
		if (Ra==31)	// program counter relative ?
			addr -= code_address;
	}
	val = addr;
	if (noRt && val > 0xfffffffff8000000LL && val < 0x7ffffffLL) {
		emit_insn(
			(((val & 0xfffffff) >> 2) << 6) |
			0x19,0,4
		);
		return;
	}
	if (val < -131072 || val > 131071) {
		GetConstantReg();
		emit_insn(
			(val << 16) |
			(regCnst << 11) |
			(0 << 6) |
			0x09,!expand_flag,4);	// ORI
		val >>= 16;
		emit_insn(
			(val << 16) |
			(regCnst << 11) |
			(0 << 6) |
			(1 << 6) |
			0x1A,!expand_flag,4);	// ORQ1
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 16) |
				(regCnst << 11) |
				(0 << 6) |
				(2 << 6) |
				0x1A,!expand_flag,4);	// ORQ2
		}
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 16) |
				(regCnst << 11) |
				(0 << 6) |
				(3 << 6) |
				0x1A,!expand_flag,4);	// ORQ3
		}
		if (Ra != 0) {
			// add r23,r23,Ra
			emit_insn(
				(0x04 << 26) |
				(regCnst << 16) |
				(regCnst << 11) |
				(Ra << 6) |
				0x02,0,4
				);
			// jal Rt,r23
			emit_insn(
				(0 << 16) |
				(Rt << 11) |
				(regCnst << 6) | 0x18,!expand_flag,4);
			return;
		}
		emit_insn(
			(0 << 16) |
			(Rt << 11) |
			(regCnst << 6) | 0x18,!expand_flag,4);
		return;
	}
	emit_insn((addr << 16) | (Rt << 11) | (Ra << 6) | 0x18,!expand_flag,4);
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
    int fmt;
    int rm;

    rm = 0;
    fmt = GetFPSize();
    p = inptr;
    if (oc==0x01)        // fcmp
        Rt = getRegisterX();
    else
        Rt = getFPRegister();
    need(',');
    Ra = getFPRegister();
    if (token==',')
       rm = getFPRoundMode();
    prevToken();
    emit_insn(
			(fmt << 27)|
			(rm << 24)|
			(Rt << 18)|
			(oc << 12)|
			(Ra << 6) |
			0x36,!expand_flag,2
			);
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
    int fmt;
    int rm;

    rm = 0;
    fmt = GetFPSize();
    p = inptr;
    if (oc==0x01)        // fcmp
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
    emit_insn(
			(oc << 29)|
			(fmt << 27)|
			(rm << 24)|
			(Rt << 18)|
			(Rb << 12)|
			(Ra << 6) |
			0x36,!expand_flag,4
			);
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
	emit_insn(
		((bits & 0x3F) << 18) |
		(oc << 12) |
		(Ra << 6) |
		0x36,!expand_flag,2
		);
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
	emit_insn(
		(1 << 26) |
		(oc << 21) |
		(Rt << 16) |
		(Ra << 6) |
		0x02,!expand_flag,4
		);
	prevToken();
}

// ---------------------------------------------------------------------------
// beqi r2,#123,label
// ---------------------------------------------------------------------------

static void process_beqi(int opcode6, int opcode3)
{
    int Ra;
    int64_t val, imm;
    int64_t disp;

    Ra = getRegisterX();
    need(',');
    NextToken();
    imm = expr();
	need(',');
	NextToken();
	val = expr();
	disp = val - (code_address + 4);
	if (imm < -256 || imm > 255) {
		printf("Branch immediate too large: %d %d", lineno, imm);
	}
	emit_insn((((disp >> 3) & 0x3FF) << 22) |
		(opcode3 << 17) |
		((imm & 0x1FF) << 11) |
		(Ra << 6) |
		((disp>>2) & 1) |
		opcode6,0,4
	);
    return;
}


// ---------------------------------------------------------------------------
// beq r1,r2,label
// bne r2,r3,r4
//
// When opcode4 is negative it indicates to swap the a and b registers. This
// allows source code to use alternate forms of branch conditions.
// ---------------------------------------------------------------------------

static void process_bcc(int64_t opcode6, int64_t opcode4)
{
    int Ra, Rb, Rc, pred;
    int64_t val;
    int64_t disp;
	char *p, *p1;

	pred = 0;
	p1 = inptr;
    Ra = getRegisterX();
    need(',');
    Rb = getRegisterX();
    need(',');
	p = inptr;
	Rc = getRegisterX();
	if (Rc==-1) {
		inptr = p;
	    NextToken();
		if (token=='#' && opcode4==0) {
			inptr = p1;
			process_beqi(0x32,0);
			return;
		}
		val = expr();
		disp = val - (code_address + 4);
		if (token==',') {
			NextToken();
			pred = (int)expr();
		}
		if (opcode4 < 0) {
			opcode4 = -opcode4;
			emit_insn(((disp >> 3) & 0x3FF) << 24 |
				((pred & 3) << 22) |
				(opcode4 << 18) |
				(Ra << 12) |
				(Rb << 6) |
				((disp >> 2) & 1) |
				opcode6,0,4
			);
			return;
		}
	    emit_insn(((disp >> 3) & 0x3FF) << 24 |
			((pred & 3) << 22) |
			(opcode4 << 18) |
			(Rb << 12) |
			(Ra << 6) |
			((disp >> 2) & 1) |
			opcode6,0,4
		);
		return;
	}
	if (token==',') {
		NextToken();
		pred = (int)expr();
	}
	if (opcode4 < 0) {
		opcode4 = -opcode4;
		emit_insn(
			((pred & 3) << 28) |
			(opcode4 << 24) |
			(Rc << 18) |
			(Ra << 12) |
			(Rb << 6) |
			0x03,0,4
		);
	}
	emit_insn(
		((pred & 3) << 28) |
		(opcode4 << 24) |
		(Rc << 18) |
		(Rb << 12) |
		(Ra << 6) |
		0x03,0,4
	);
}

// ---------------------------------------------------------------------------
// bfextu r1,r2,#1,#63
// ---------------------------------------------------------------------------

static void process_bitfield(int oc)
{
    int Ra;
    int Rt;
    int64_t mb;
    int64_t me;

    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
    need(',');
    NextToken();
    mb = expr();
    need(',');
    NextToken();
    me = expr();
	emit_insn(
		(oc << 28) |
		(me << 22) |
		(mb << 16) |
		(Rt << 11) |
		(Ra << 6) |
		0x22,0,4
	);
}


// ---------------------------------------------------------------------------
// bra label
// ---------------------------------------------------------------------------

static void process_bra(int oc)
{
    int Ra = 0, Rb = 0;
    int64_t val;
    int64_t disp;

    NextToken();
    val = expr();
    disp = val - (code_address + 4);
    emit_insn((((disp >> 3) & 0xFFF) << 24) |
		(3 << 22) |	// static predict taken
		(0 << 18) |
        (0 << 12) |
        (0 << 6) |
		((disp>>2) & 1) |
        0x30,0,4
    );
}

// ----------------------------------------------------------------------------
// chk r1,r2,r3,label
// ----------------------------------------------------------------------------

static void process_chk(int opcode6)
{
	int Ra;
	int Rb;
	int Rc;
	int64_t val, disp; 
     
	Ra = getRegisterX();
	need(',');
	Rb = getRegisterX();
	need(',');
	Rc = getRegisterX();
	need(',');
	NextToken();
	val = expr();
    disp = val - code_address;
	emit_insn(((disp >> 3) & 0x3FF) << 22 |
		(Rc << 16) |
		(Rb << 11) |
		(Ra << 6) |
		((disp >> 2) & 1) |
		opcode6,!expand_flag,4
	);
}


static void process_chki(int opcode6)
{
	int Ra;
	int Rb;
	int64_t val, disp; 
     
	Ra = getRegisterX();
	need(',');
	Rb = getRegisterX();
	need(',');
	NextToken();
	val = expr();
    disp = val - code_address;
	if (val < LB16 || val > 32767LL) {
		emit_insn((0x8000 << 16)|(Rb << 11)|(Ra << 6)|opcode6,0,2);
		emit_insn(val,0,2);
		return;
	}
	emit_insn(((val & 0xFFFF) << 16)|(Rb << 11)|(Ra << 6)|opcode6,!expand_flag,2);
}


// ---------------------------------------------------------------------------
// fbeq.q fp1,fp0,label
// ---------------------------------------------------------------------------

static void process_fbcc(int opcode3)
{
    int Ra, Rb;
    int64_t val;
    int64_t disp;
	int sz;

    sz = GetFPSize();
    Ra = getFPRegister();
    need(',');
    Rb = getFPRegister();
    need(',');
    NextToken();

    val = expr();
    disp = val - code_address;
	if (disp < -255 || disp > 255) {
		// Flip the test
		switch(opcode3) {
		case 0:	opcode3 = 1; break;
		case 1:	opcode3 = 0; break;
		case 2:	opcode3 = 3; break;
		case 3:	opcode3 = 2; break;
		case 4:	opcode3 = 5; break;
		case 5: opcode3 = 4; break;
		case 6:	opcode3 = 7; break;
		case 7:	opcode3 = 6; break;
		}
		emit_insn(
			(sz << 27) |
			(4 << 21) |
			(opcode3 << 18) |
			(Rb << 12) |
			(Ra << 6) |
			0x01,0,2
		);
		emit_insn((disp & 0x1FFF) << 19 |
			0x12,0,2
		);
		return;
	}
    emit_insn(
		(((disp & 0x1FF) >> 6) << 29) |
		(sz << 27) |
		((disp & 0x3F) << 21) |
		(opcode3 << 18) |
        (Rb << 12) |
        (Ra << 6) |
        0x01,0,2
    );
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_call(int64_t opcode)
{
	int64_t val;
	int Ra = 0;

    NextToken();
	val = expr();
	if (token=='[') {
		Ra = getRegisterX();
		need(']');
		if (Ra==31) {
			val -= code_address;
		}
	}
	if (val==0) {
		if (opcode==0x28)	// JMP [Ra]
			// jal r0,[Ra]
			emit_insn(
				(Ra << 6) |
				0x18,0,4
			);
		else
			// jal lr,[Ra]	- call [Ra]
			emit_insn(
				(regLR << 12) |
				(Ra << 6) |
				0x18,0,4
			);
		return;
	}
	if (code_bits > 27 && (val < 0xFFFFFFFFF8000000LL || val > 0x7FFFFFFLL)) {
		emit_insn(
			(val << 18) |
			(23 << 12) |
			(0 << 6) |
			0x09,!expand_flag,4);	// ORI
		val >>= 16;
		emit_insn(
			(val << 18) |
			(23 << 12) |
			(0 << 6) |
			(1 << 6) |
			0x1A,!expand_flag,4);	// ORQ1
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 18) |
				(23 << 12) |
				(0 << 6) |
				(2 << 6) |
				0x1A,!expand_flag,4);	// ORQ2
		}
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 18) |
				(23 << 12) |
				(0 << 6) |
				(3 << 6) |
				0x1A,!expand_flag,4);	// ORQ3
		}
		if (Ra!=0) {
			// add r23,r23,Ra
			emit_insn(
				(0x04 << 30) |
				(23 << 18) |
				(23 << 11) |
				(Ra << 6) |
				0x02,0,4
				);
		}
		if (opcode==0x28)	// JMP
			// jal r0,[r23]
			emit_insn(
				(23 << 6) |
				0x18,0,4
				);
		else
			// jal lr,[r23]	- call [r23]
			emit_insn(
				(regLR << 12) |
				(23 << 6) |
				0x18,0,4
				);
		return;
	}
	emit_insn(
		(((val & 0xFFFFFFFF) >> 2) << 6) |
		0x19,0,4
		);
}

static void process_iret(int op)
{
	int64_t val = 0;

    NextToken();
	if (token=='#') {
		val = expr();
	}
	emit_insn(
		((val & 0x3F) << 16) |
		(0 << 11) |
		(0 << 6) |
		op,0,4
	);
}

static void process_ret()
{
	int64_t val = 0;

    NextToken();
	if (token=='#') {
		val = expr();
	}
	emit_prefix(val);
	emit_insn(
		(((val==0?8:val) & 0xFFFF) << 16) |
		(31 << 11) |
		(31 << 6) |
		0x29,0,4
	);
}

// ----------------------------------------------------------------------------
// inc -8[bp],#1
// ----------------------------------------------------------------------------

static void process_inc(int oc)
{
    int Ra;
    int Rb;
	int Sc;
    int64_t incamt;
    int64_t disp;
    char *p;
    int fixup = 5;
    int neg = 0;

    NextToken();
    p = inptr;
    mem_operand(&disp, &Ra, &Rb, &Sc);
    incamt = 1;
    if (token==']')
       NextToken();
    if (token==',') {
        NextToken();
        incamt = expr();
        prevToken();
    }
    if (Rb >= 0) {
       if (disp != 0)
           printf("displacement not allowed with indexed addressing.\r\n");
       oc = 0x6F;  // INCX
	   // ToDo: fix this
       emit_insn(
           ((disp & 0xFF) << 24) |
           (Rb << 17) |
           ((incamt & 0x1F) << 12) |
           (Ra << 7) |
           oc,0,2
       );
       return;
    }
    if (oc==0x25) neg = 1;
    oc = 0x24;        // INC
    if (Ra < 0) Ra = 0;
    if (neg) incamt = -incamt;
	if (disp < LB16 || disp > 32767LL) {
		emit_insn(
			(0x8000 << 16) |
			((incamt & 0x1f) << 11) |
			(Ra << 6) |
			oc,0,2);
		emit_insn(disp,0,2);
	}
	else {
		emit_insn(
			(disp << 16) |
			((incamt & 0x1f) << 11) |
			(Ra << 6) |
			oc,!expand_flag,2);
    }
    ScanToEOL();
}
       
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_brk()
{
	int64_t val;
	int inc = 1;

    NextToken();
	val = expr();
	NextToken();
	if (token==',') {
		inc = (int)expr();
	}
	else
		prevToken();
	emit_insn(
		(inc << 15) |
		((val & 0x1FF) << 6) |
		0x00,0,4
	);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void GetIndexScale(int *sc)
{
      int64_t val;

      NextToken();
      val = expr();
      prevToken();
      switch(val) {
      case 0: *sc = 0; break;
      case 1: *sc = 0; break;
      case 2: *sc = 1; break;
      case 4: *sc = 2; break;
      case 8: *sc = 3; break;
      default: printf("Illegal scaling factor.\r\n");
      }
}


// ---------------------------------------------------------------------------
// expr
// expr[Reg]
// [Reg]
// [Reg+Reg]
// ---------------------------------------------------------------------------

static void mem_operand(int64_t *disp, int *regA, int *regB, int *Sc)
{
     int64_t val;

     // chech params
     if (disp == (int64_t *)NULL)
         return;
     if (regA == (int *)NULL)
         return;

     *disp = 0;
     *regA = -1;
	 *regB = -1;
	 *Sc = 0;
     if (token!='[') {;
          val = expr();
          *disp = val;
     }
     if (token=='[') {
         *regA = getRegisterX();
         if (*regA == -1) {
             printf("expecting a register\r\n");
         }
		 if (token=='+') {
			 *regB = getRegisterX();
			 if (*regB == -1) {
				 printf("expecting a register\r\n");
			 }
              if (token=='*') {
                  GetIndexScale(Sc);
              }
		 }
         need(']');
     }
}

static void mem_voperand(int64_t *disp, int *regA, int *regB)
{
     int64_t val;

     // chech params
     if (disp == (int64_t *)NULL)
         return;
     if (regA == (int *)NULL)
         return;

     *disp = 0;
     *regA = -1;
	 *regB = -1;
     if (token!='[') {;
          val = expr();
          *disp = val;
     }
     if (token=='[') {
         *regA = getRegisterX();
         if (*regA == -1) {
             printf("expecting a register\r\n");
         }
		 if (token=='+') {
			 *regB = getVecRegister();
			 if (*regB == -1) {
				 printf("expecting a vector register: %d\r\n", lineno);
			 }
		 }
         need(']');
     }
}

// ---------------------------------------------------------------------------
// If the displacement is too large the instruction is converted to an
// indexed form and the displacement loaded into a second register.
//
// So
//      sw   r2,$12345678[r2]
// Becomes:
//		ori  r23,r0,#$5678
//      orq1 r23,#$1234
//      sw   r2,[r2+r23]
//
// sw disp[r1],r2
// sw [r1+r2],r3
// ----------------------------------------------------------------------------

static void process_store(int64_t opcode6)
{
    int Ra,Rb;
    int Rs;
	int Sc;
    int64_t disp,val;

    Rs = getRegisterX();
    if (Rs < 0) {
        printf("Expecting a source register (%d).\r\n", lineno);
        printf("Line:%.60s\r\n",inptr);
        ScanToEOL();
        return;
    }
    expect(',');
    mem_operand(&disp, &Ra, &Rb, &Sc);
	if (Ra > 0 && Rb > 0) {
		emit_insn(
			(opcode6 << 30) |
			(Sc << 24) |
			(Rs << 18) |
			(Rb << 12) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	if (val < -131072 || val > 131071) {
		GetConstantReg();
		emit_insn(
			(val  << 18) |
			(regCnst << 12) |
			(0 << 6) |
			0x09,!expand_flag,4);
		emit_insn(
			((val >> 16) << 18) |
			(regCnst << 12) |
			(0 << 6) |
			(1 << 6) |
			0x1A,!expand_flag,4);	// ORQ1
		// Change to indexed addressing
		emit_insn(
			(opcode6 << 30) |
			(Rs << 18) |
			(regCnst << 12) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		ScanToEOL();
		return;
	}
	emit_insn(
		(val << 18) |
		(Rs << 12) |
		(Ra << 6) |
		opcode6,!expand_flag,4);
    ScanToEOL();
}

static void process_sv(int opcode6)
{
    int Ra,Vb;
    int Vs;
    int64_t disp,val;

    Vs = getVecRegister();
    if (Vs < 0 || Vs > 31) {
        printf("Expecting a vector source register (%d).\r\n", lineno);
        printf("Line:%.60s\r\n",inptr);
        ScanToEOL();
        return;
    }
    expect(',');
    mem_voperand(&disp, &Ra, &Vb);
	if (Ra > 0 && Vb > 0) {
		emit_insn(
			(opcode6 << 26) |
			(Vs << 16) |
			(Vb << 11) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	//if (val < -32768 || val > 32767)
	//	printf("SV displacement too large: %d\r\n", lineno);
	emit_prefix(val);
	emit_insn(
		(val << 16) |
		(Vs << 11) |
		(Ra << 6) |
		opcode6,!expand_flag,4);
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_ldi()
{
    int Ra = 0;
    int Rt;
    int64_t val;
    int opcode6 = 0x09;  // ORI
	int sz = 3;
	char *p;

    p = inptr;
	if (*p=='.')
		getSz(&sz);
    Rt = getRegisterX();
    expect(',');
    val = expr();
	if (val < -32768 || val > 32767) {
		emit_insn(
			(val << 16) |
			(23 << 11) |
			(0 << 6) |
			0x09,!expand_flag,4);	// ORI
		val >>= 16;
		emit_insn(
			(val << 16) |
			(23 << 11) |
			(0 << 6) |
			(1 << 6) |
			0x1A,!expand_flag,4);	// ORQ1
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 16) |
				(23 << 11) |
				(0 << 6) |
				(2 << 6) |
				0x1A,!expand_flag,4);	// ORQ2
		}
		val >>= 16;
		if (val != 0) {
			emit_insn(
				(val << 16) |
				(23 << 11) |
				(0 << 6) |
				(3 << 6) |
				0x1A,!expand_flag,4);	// ORQ3
		}
		emit_insn(
			(opcode6 << 26) |
			(sz << 21) |
			(Rt << 16) |
			(23 << 11) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		return;
	}
	emit_insn(
		(val << 16) |
		(Rt << 11) |
		opcode6,!expand_flag,4
	);
}

// ----------------------------------------------------------------------------
// link #-40
// ----------------------------------------------------------------------------

static void process_link(int opcode6)
{
    int Ra = 31;
    int Rb = 30;
    char *p;
    int64_t val;
    
    p = inptr;
    Rb = getRegisterX();
	if (Rb==-1)
		Rb = 30;
	else
		expect(',');
    NextToken();
    val = expr();
	emit_prefix(val);
	emit_insn(((val & 0xFFFF) << 16)|(Rb << 11)|(Ra << 6)|opcode6,!expand_flag,4);
}

// ----------------------------------------------------------------------------
// lw r1,disp[r2]
// lw r1,[r2+r3]
// ----------------------------------------------------------------------------

static void process_load(int64_t opcode6)
{
    int Ra,Rb;
    int Rt;
	int Sc;
    char *p;
    int64_t disp;
    int64_t val;
    int fixup = 5;

    p = inptr;
	if (opcode6==0x26LL)
		Rt = getVecRegister();
	else
		Rt = getRegisterX();
    if (Rt < 0) {
        printf("Expecting a target register (%d).\r\n", lineno);
        printf("Line:%.60s\r\n",p);
        ScanToEOL();
        inptr-=2;
        return;
    }
    expect(',');
    mem_operand(&disp, &Ra, &Rb, &Sc);
	if (Ra > 0 && Rb > 0) {
		// Trap LEA, convert to LEAX opcode
		if (opcode6==0x04) // ADD is really LEA
			opcode6 = 0x18;
		emit_insn(
			(opcode6 << 30) |
			(Sc << 24) |
			(Rt << 18) |
			(Rb << 12) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	if (val < -131072 || val > 131071) {
		GetConstantReg();
		emit_insn(
			(val  << 18) |
			(regCnst << 12) |
			(0 << 6) |
			0x09,!expand_flag,4);
		emit_insn(
			((val >> 16) << 18) |
			(regCnst << 12) |
			(0 << 6) |
			(1 << 6) |
			0x1A,!expand_flag,4);	// ORQ1
		// Change to indexed addressing
		emit_insn(
			(opcode6 << 30) |
			(Rt << 18) |
			(regCnst << 12) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		ScanToEOL();
		return;
	}
	emit_insn(
		(val << 18) |
		(Rt << 12) |
		(Ra << 6) |
		opcode6,!expand_flag,4);
    ScanToEOL();
}

static void process_lv(int opcode6)
{
    int Ra,Vb;
    int Vt;
    char *p;
    int64_t disp;
    int64_t val;
    int fixup = 5;

    p = inptr;
	Vt = getVecRegister();
    if (Vt < 0) {
        printf("Expecting a vector target register (%d).\r\n", lineno);
        printf("Line:%.60s\r\n",p);
        ScanToEOL();
        inptr-=2;
        return;
    }
    expect(',');
    mem_voperand(&disp, &Ra, &Vb);
	if (Ra > 0 && Vb > 0) {
		emit_insn(
			(opcode6 << 26) |
			(Vt << 16) |
			(Vb << 11) |
			(Ra << 6) |
			0x02,!expand_flag,4);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	//if (val < -32768 || val > 32767)
	//	printf("LV displacement too large: %d\r\n", lineno);
	emit_prefix(val);
	emit_insn(
		(val << 16) |
		(Vt << 11) |
		(Ra << 6) |
		opcode6,!expand_flag,4);
    ScanToEOL();
}

static void process_lsfloat(int opcode6)
{
    int Ra,Rb;
    int Rt;
	int Sc;
    char *p;
    int64_t disp;
    int64_t val;
    int fixup = 5;

    int  sz;
    int rm;

    rm = 0;
    sz = GetFPSize();
    p = inptr;
    Rt = getFPRegister();
    if (Rt < 0) {
        printf("Expecting a target register (1:%d).\r\n", lineno);
        printf("Line:%.60s\r\n",p);
        ScanToEOL();
        inptr-=2;
        return;
    }
    expect(',');
    mem_operand(&disp, &Ra, &Rb, &Sc);
	if (Ra > 0 && Rb > 0) {
		emit_insn(
			(1L << 29) |
			(sz << 27) |
			(Rt << 18) |
			(Rb << 12) |
			(Ra << 6) |
			opcode6,!expand_flag,2);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	if (val < -15LL || val > 15LL) {
		emit_insn(
			(sz << 27) |
			(Rt << 18) |
			(0x10 << 11) |
			(Ra << 6) |
			opcode6,0,2);
		emit_insn(val,0,2);
	}
	else {
		emit_insn(
			(sz << 27) |
			(Rt << 18) |
			((val & 0x1f) << 11) |
			(Ra << 6) |
			opcode6,!expand_flag,2);
    }
    ScanToEOL();
}

static void process_ld()
{
	int Rt;
	char *p;

	p = inptr;
	Rt = getRegisterX();
	expect(',');
//	NextToken();
	if (token == '#') {
		inptr = p;
		process_ldi();
		return;
	}
	// Else: do a word load
	inptr = p;
	process_load(0x22);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_ltcb(int oc)
{
	int Rn;

	Rn = getRegisterX();
	emit_insn(
		(oc << 11) |
		(Rn << 6) |
		0x19,0,1
		);
	prevToken();
}

// ----------------------------------------------------------------------------
// mov r1,r2 -> translated to or Rt,Ra,#0
// ----------------------------------------------------------------------------

static void process_mov(int oc)
{
     int Ra;
     int Rt;
     char *p;
	 int vec = 0;

	 p = inptr;
     Rt = getRegisterX();
	 if (Rt==-1) {
		 inptr = p;
		 Rt = getVecRegister() & 15;
		 vec = 1;
	 }
     need(',');
	 p = inptr;
     Ra = getRegisterX();
	 if (Ra==-1) {
		 inptr = p;
		 Ra = getVecRegister() & 15;
		 vec = 2;
	 }
	 if (vec==1) {
		 emit_insn(
			 (0x33 << 26) |
			 (0x00 << 21) |
			 (Rt << 11) |
			 (Ra << 6) |
			 0x01,0,4
		 );
		 return;
	 }
	 else if (vec==2) {
		 emit_insn(
			 (0x33 << 26) |
			 (0x01 << 21) |
			 (Rt << 11) |
			 (Ra << 6) |
			 0x01,0,4
		 );
		 return;
	 }
	 emit_insn(
		 (Rt << 11) |
		 (Ra << 6) |
		 oc,0,4
		 );
	prevToken();
}

// ----------------------------------------------------------------------------
// shr r1,r2,#5
// ----------------------------------------------------------------------------

static void process_shifti(int64_t op4)
{
     int Ra;
     int Rt;
	 int sz = 3;
	 int64_t func6 = 3;
     int64_t val;
	 char *p = inptr;

	 if (p[0]=='.')
		 getSz(&sz);
     Rt = getRegisterX();
     need(',');
     Ra = getRegisterX();
     need(',');
     NextToken();
     val = expr();
	switch(sz) {
	case 0:	func6 = 0x1F;
	case 1:	func6 = 0x2F;
	case 2:	func6 = 0x3F;
	default:	func6 = 0x0F;
	}
	emit_insn((func6 << 30) | (op4 << 26) | ((val & 0x3f) << 18) | (Rt << 12) | (Ra << 6) | 0x02,!expand_flag,4);
}

// ----------------------------------------------------------------------------
// SEI R1
// SEI #5
// ----------------------------------------------------------------------------

static void process_sei()
{
	int64_t val = 7;
	int Ra = -1;
    char *p;

	p = inptr;
	NextToken();
	if (token=='#')
		val = expr();
	else {
		inptr = p;
	    Ra = getRegisterX();
	}
	if (Ra==-1) {
		emit_insn(
			0xC0000002 |
			((val & 7) << 11) |
			(0 << 6),
			0,4);
	}
	else {
		emit_insn(
			0xC0000002 |
			(0 << 11) |
			(Ra << 6),
			0,4);
	}
}

// ----------------------------------------------------------------------------
// shl r1,r2,r3
// ----------------------------------------------------------------------------

static void process_shift(int64_t op4)
{
     int Ra, Rb;
     int Rt;
     char *p;
	 int sz = 3;
	 int64_t func6 = 3;

	 p = inptr;
	 if (p[0]=='.')
		 getSz(&sz);
     Rt = getRegisterX();
     need(',');
     Ra = getRegisterX();
     need(',');
     NextToken();
	 if (token=='#') {
		 inptr = p;
		 process_shifti(op4 + 0x8);
	 }
	 else {
		prevToken();
		Rb = getRegisterX();
		switch(sz) {
		case 0:	func6 = 0x1FLL;
		case 1:	func6 = 0x2FLL;
		case 2:	func6 = 0x3FLL;
		default:	func6 = 0x0FLL;
		}
		emit_insn((func6 << 30) | (op4 << 26) | (Rt << 18)| (Rb << 12) | (Ra << 6) | 0x02,!expand_flag,4);
	 }
}

// ----------------------------------------------------------------------------
// gran r1
// ----------------------------------------------------------------------------

static void process_gran(int oc)
{
    int Rt;

    Rt = getRegisterX();
//    emitAlignedCode(0x01);
    emitCode(0x00);
    emitCode(Rt);
    emitCode(0x00);
    emitCode(oc);
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
    //emitAlignedCode(0x01);
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
    //emitAlignedCode(0x01);
    emitCode(0x00);
    emitCode(Rt);
    emitCode(0x00);
    emitCode(oc);
}


// ----------------------------------------------------------------------------
// Four cases, two with extendable immediate constants
//
// csrrw	r2,#21,r3
// csrrw	r4,#34,#1234
// csrrw	r5,r4,#1234
// csrrw	r6,r4,r5
// ----------------------------------------------------------------------------

static void process_csrrw(int op)
{
	int Rd;
	int Rs;
	int Rc;
	int64_t val,val2;
	char *p;
  
	Rd = getRegisterX();
	need(',');
	p = inptr;
	NextToken();
	if (token=='#') {
		val = expr();
		need(',');
		NextToken();
		if (token=='#') {
			printf("Illegal CSR instruction.\r\n");
			return;
			val2 = expr();
			if (val2 < -15LL || val2 > 15LL) {
				emit_insn((val << 18) | (op << 16) | (0x10 << 6) | (Rd << 11) | 0x0F,0,2);
				emit_insn(val2,0,2);
				return;
			}
			emit_insn((val << 18) | (op << 16) | ((val2 & 0x1f) << 6) | (Rd << 11) | 0x0F,!expand_flag,2);
			return;
		}
		prevToken();
		Rs = getRegisterX();
		emit_insn(((val & 0xfff) << 16) | (op << 30) | (Rs << 6) | (Rd << 11) | 0x0E,!expand_flag,4);
		prevToken();
		return;
		}
	printf("Illegal CSR instruction.\r\n");
	return;
	inptr = p;
	Rc = getRegisterX();
	need(',');
	NextToken();
	if (token=='#') {
		val2 = expr();
		if (val2 < -15LL || val2 > 15LL) {
			emit_insn((0x0F << 26) | (op << 21) | (Rd << 16) | (0x10 << 6) | (Rc << 11) | 0x0C,0,2);
			emit_insn(val2,0,2);
			return;
		}
		emit_insn((0x0F << 26) | (op << 21) | (Rd << 16) | ((val2 & 0x1f) << 6) | (Rc << 11) | 0x0C,!expand_flag,2);
		return;
	}
	prevToken();
	Rs = getRegisterX();
	emit_insn((0x3F << 26) | (op << 21) | (Rd << 16) | (Rc << 11) | (Rs << 6) | 0x0C,!expand_flag,2);
	prevToken();
	return;
}

// ---------------------------------------------------------------------------
// com r3,r3
// - alternate mnemonic for xor Rn,Rn,#-1
// ---------------------------------------------------------------------------

static void process_com()
{
    int Ra;
    int Rt;

    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
	emit_insn(
		(0xFFFF << 16) |
		(Rt << 11) |
		(Ra << 6) |
		0x0A,!expand_flag,4
		);
	prevToken();
}

// ---------------------------------------------------------------------------
// com r3,r3
// - alternate mnemonic for xor Rn,Rn,#-1
// ---------------------------------------------------------------------------

static void process_neg()
{
    int Ra;
    int Rt;

    Rt = getRegisterX();
    need(',');
    Ra = getRegisterX();
	emit_insn(
		(0x05 << 26) |
		(Rt << 16) |
		(Ra << 11) |
		(0 << 6) |
		0x02,!expand_flag,4
		);
	prevToken();
}

// ----------------------------------------------------------------------------
// push r1
// push #123
// ----------------------------------------------------------------------------

static void process_push(int func, int amt)
{
    int Ra,Rb;
	int FRa;
	int sz;
    int64_t val;

    Ra = -1;
    Rb = -1;
    sz = GetFPSize();
    NextToken();
    if (token=='#') {  // Filter to PUSH
		//printf("Illegal push/pop instruction: %d.\r\n", lineno);
		//return;
       val = expr();
	    if (val > 32767 || val < -32768) {
			emit_insn(
				(val << 16) |
				(23 << 11) |
				(0 << 6) |
				0x09,!expand_flag,4);	// ORI
			val >>= 16;
			emit_insn(
				(val << 16) |
				(23 << 11) |
				(0 << 6) |
				(1 << 6) |
				0x1A,!expand_flag,4);	// ORQ1
			val >>= 16;
			if (val != 0) {
				emit_insn(
					(val << 16) |
					(23 << 11) |
					(0 << 6) |
					(2 << 6) |
					0x1A,!expand_flag,4);	// ORQ2
			}
			val >>= 16;
			if (val != 0) {
				emit_insn(
					(val << 16) |
					(23 << 11) |
					(0 << 6) |
					(3 << 6) |
					0x1A,!expand_flag,4);	// ORQ3
			}
			Ra = 23;
			goto j1;
		}
		else
			emit_insn(
				((val & 0xFFFFLL) << 16) |
				(0x1F << 11) |
				(0x1F << 6) |
				0x1F,  // PUSHC
				0,4
			);
        return;
    }
    prevToken();
	FRa = getFPRegister();
	if (FRa==-1) {
		prevToken();
		Ra = getRegisterX();
	}
	else {
		emit_insn(
			(func << 14) |
			(sz << 12) |
			(FRa << 6) |
			0x19,0,1
			);
		prevToken();
		return;
	}
    if (Ra == -1) {
		Ra = 0;
        printf("%d: unknown register.\r\n", lineno);
    }
j1:
    emit_insn(
		(func << 26) |
		((amt & 31) << 21) |
		(0x1F << 16) |
		(Ra << 11) |
		(0x1F << 6) |
		0x02,0,4);
    prevToken();
}

static void process_sync(int oc)
{
//    emit_insn(oc,!expand_flag);
}


// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_vrrop(int funct6)
{
    int Va,Vb,Vt,Vm;
    char *p;
	int sz = 0x43;

    p = inptr;
	if (*p=='.')
		getSz(&sz);
	if (sz==0x43)
		sz = 0;
	else if (sz==0x83)
		sz = 1;
    Vt = getVecRegister();
    need(',');
    Va = getVecRegister();
    need(',');
    Vb = getVecRegister();
    need(',');
    Vm = getVecRegister();
	if (Vm < 0x20 || Vm > 0x23)
		printf("Illegal vector mask register: %d\r\n", lineno);
	Vm &= 0x3;
    //prevToken();
    emit_insn((funct6<<26)|(Vm<<23)|(sz << 21)|(Vt<<16)|(Vb<<11)|(Va<<6)|0x01,!expand_flag,4);
}
       
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_vsrrop(int funct6)
{
    int Va,Rb,Vt,Vm;
    char *p;
	int sz = 0x43;

    p = inptr;
	if (*p=='.')
		getSz(&sz);
	if (sz==0x43)
		sz = 0;
	else if (sz==0x83)
		sz = 1;
    Vt = getVecRegister();
    need(',');
    Va = getVecRegister();
    need(',');
    Rb = getRegisterX();
    need(',');
    Vm = getVecRegister();
	if (Vm < 0x20 || Vm > 0x23)
		printf("Illegal vector mask register: %d\r\n", lineno);
	Vm &= 0x3;
    //prevToken();
    emit_insn((funct6<<26)|(Vm<<23)|(sz << 21)|(Vt<<16)|(Rb<<11)|(Va<<6)|0x01,!expand_flag,4);
}
       
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void ProcessEOL(int opt)
{
    int64_t nn,mm,wd;
	float nf;
    int first;
    double cc;
	int evn;
    
     //printf("Line: %d\r", lineno);
     expand_flag = 0;
     compress_flag = 0;
     segprefix = -1;
     if (bGen && (segment==codeseg || segment==dataseg || segment==rodataseg)) {
    nn = binstart;
    cc = 2;
    if (segment==codeseg) {
       cc = 4.5;
/*
        if (sections[segment].bytes[binstart]==0x61) {
            fprintf(ofp, "%06LLX ", (int)ca);
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
	nf = nn;
    while (nn < sections[segment].index) {
        fprintf(ofp, "%06LLX ", (int)ca & 0xFFFFFC);
		evn = 0;
        for (mm = nf; nf < mm + cc && nf < sections[segment].index; nf+=4.5) {
			nn = (int)nf;
			switch((int)ca & 31) {
			case 0:
			case 9:
			case 18:
			case 27:
				wd = ((int64_t)sections[segment].bytes[nn]) |
					((int64_t)sections[segment].bytes[nn+1] << 8) |
					((int64_t)sections[segment].bytes[nn+2] << 16) |
					((int64_t)sections[segment].bytes[nn+3] << 24) |
					(((int64_t)sections[segment].bytes[nn+4] & 15) << 32);
				fprintf(ofp, "%09I64X ", wd);
				break;
			case 4:
			case 13:
			case 22:
			case 31:
				wd = ((int64_t)sections[segment].bytes[nn] >> 4) |
					((int64_t)sections[segment].bytes[nn+1] << 4) |
					((int64_t)sections[segment].bytes[nn+2] << 12) |
					((int64_t)sections[segment].bytes[nn+3] << 20) |
					((int64_t)sections[segment].bytes[nn+4] << 28);
				fprintf(ofp, "%09I64X ", wd);
				break;
			case 5: case 14:
				wd = ((int64_t)sections[segment].bytes[nn]) |
					((int64_t)sections[segment].bytes[nn+1] << 8) |
					((int64_t)sections[segment].bytes[nn+2] << 16) |
					((int64_t)sections[segment].bytes[nn+3] << 24) |
					(((int64_t)sections[segment].bytes[nn+4] & 15) << 32);
				fprintf(ofp, "*** %09I64X ", wd);
				break;
			}
            //fprintf(ofp, "%02X%02X%02X%02X ", sections[segment].bytes[nn+3], sections[segment].bytes[nn+2], sections[segment].bytes[nn+1], sections[segment].bytes[nn]);
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

void FT64x36_processMaster()
{
    int nn;
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
	expandedBlock = 1;
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
          if (expandedBlock)
             expand_flag = 1;
        switch(token) {
        case tk_eol: ProcessEOL(1); break;
//        case tk_add:  process_add(); break;
//		case tk_abs:  process_rop(0x04); break;
        case tk_add:  process_rrop(0x04); break;
        case tk_addi: process_riop(0x04); break;
        case tk_align: process_align(); continue; break;
        case tk_and:  process_rrop(0x08); break;
        case tk_andi:  process_riop(0x08); break;
        case tk_asl: process_shift(0x2); break;
        case tk_asr: process_shift(0x3); break;
        case tk_bbc: process_beqi(0x26,1); break;
        case tk_bbs: process_beqi(0x26,0); break;
        case tk_begin_expand: expandedBlock = 1; break;
        case tk_beq: process_bcc(0x30,0); break;
        case tk_beqi: process_beqi(0x32,0); break;
		case tk_bfchg: process_bitfield(2); break;
		case tk_bfclr: process_bitfield(1); break;
        case tk_bfext: process_bitfield(5); break;
        case tk_bfextu: process_bitfield(6); break;
		case tk_bfset: process_bitfield(0); break;
        case tk_bge: process_bcc(0x30,3); break;
        case tk_bgeu: process_bcc(0x30,5); break;
        case tk_bgt: process_bcc(0x30,-2); break;
        case tk_bgtu: process_bcc(0x30,-4); break;
        case tk_ble: process_bcc(0x30,-3); break;
        case tk_bleu: process_bcc(0x30,-5); break;
        case tk_blt: process_bcc(0x30,2); break;
        case tk_bltu: process_bcc(0x30,4); break;
        case tk_bne: process_bcc(0x30,1); break;
        case tk_bra: process_bra(0x01); break;
		case tk_brk: process_brk(); break;
        //case tk_bsr: process_bra(0x56); break;
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
		case tk_call:  process_call(0x19); break;
        case tk_cli: emit_insn(0xC0000002,0,4); break;
		case tk_chk:  process_chk(0x34); break;
		case tk_cmp:  process_rrop(0x06); break;
		case tk_cmpi:  process_riop(0x06); break;
		case tk_cmpu:  process_rrop(0x07); break;
		case tk_cmpui:  process_riop(0x07); break;
        case tk_code: process_code(); break;
        case tk_com: process_com(); break;
        case tk_csrrc: process_csrrw(0x3); break;
        case tk_csrrs: process_csrrw(0x2); break;
        case tk_csrrw: process_csrrw(0x1); break;
        case tk_csrrd: process_csrrw(0x0); break;
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
        case tk_dh_htbl:  process_dh_htbl(); break;
        case tk_dw:  process_dw(); break;
        case tk_end: goto j1;
        case tk_end_expand: expandedBlock = 0; break;
        case tk_endpublic: break;
        case tk_eor: process_rrop(0x0A); break;
        case tk_eori: process_riop(0x0A); break;
        case tk_extern: process_extern(); break;
        case tk_fill: process_fill(); break;
		case tk_hint:	process_hint(); break;
		case tk_if:		pif1 = inptr-2; doif(); break;
		case tk_iret:	process_iret(0xC8000002); break;
        case tk_jal: process_jal(0x18); break;
		case tk_jmp: process_call(0x28); break;
        case tk_lb:  process_load(0x13); break;
        case tk_lbu:  process_load(0x23); break;
        case tk_lc:  process_load(0x20); break;
        case tk_lcu:  process_load(0x21); break;
		case tk_ld:	process_ld(); break;
        case tk_ldi: process_ldi(); break;
        case tk_lea: process_load(0x04); break;
        case tk_lh:  process_load(0x10); break;
        case tk_lhu: process_load(0x11); break;
		case tk_link:	process_link(0x2A); break;
        case tk_lv:  process_lv(0x36); break;
        case tk_lw:  process_load(0x12); break;
		case tk_memdb: emit_insn(0xD0000002,0,4); break;
		case tk_memsb: emit_insn(0xD4000002,0,4); break;
		case tk_message: process_message(); break;
		case tk_mod: process_riop(0x2E); break;
		case tk_modu: process_riop(0x2C); break;
        case tk_mov: process_mov(0x09); break;
        case tk_neg: process_neg(); break;
        case tk_nop: emit_insn(0x1C,0,4); break;
		case tk_not: process_rop(0x05); break;
//        case tk_not: process_rop(0x07); break;
        case tk_or:  process_rrop(0x09); break;
        case tk_ori: process_riop(0x09); break;
        case tk_org: process_org(); break;
        case tk_plus: expand_flag = 1; break;
		case tk_pop:	process_push(0x1A,8); break;
        case tk_public: process_public(); break;
		case tk_push:	process_push(0x19,-8); break;
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
		case tk_ret: process_ret(); break;
		case tk_rol: process_shift(0x4); break;
		case tk_roli: process_shift(0xC); break;
		case tk_ror: process_shift(0x5); break;
		case tk_rori: process_shift(0xD); break;
		case tk_rti: process_iret(0xC8000002); break;
        case tk_sb:  process_store(0x15); break;
        case tk_sc:  process_store(0x24); break;
        case tk_sei: process_sei(); break;
		case tk_seq:	process_setiop(0x1B,2); break;
		case tk_sge:	process_setiop(0x1B,5); break;
		case tk_sgeu:	process_setiop(0x1B,13); break;
		case tk_sgt:	process_setiop(0x1B,7); break;
		case tk_sgtu:	process_setiop(0x1B,15); break;
        //case tk_slt:  process_rrop(0x33,0x02,0x00); break;
        //case tk_sltu:  process_rrop(0x33,0x03,0x00); break;
        //case tk_slti:  process_riop(0x13,0x02); break;
        //case tk_sltui:  process_riop(0x13,0x03); break;
        case tk_sh:  process_store(0x14); break;
        case tk_shl: process_shift(0x0); break;
        case tk_shli: process_shifti(0x8); break;
		case tk_shr: process_shift(0x1); break;
        case tk_shri: process_shifti(0x9); break;
		case tk_shru: process_shift(0x1); break;
		case tk_shrui: process_shifti(0x9); break;
		case tk_sle:	process_setiop(0x1B,6); break;
		case tk_sleu:	process_setiop(0x1B,14); break;
		case tk_slt:	process_setiop(0x1B,4); break;
		case tk_sltu:	process_setiop(0x1B,12); break;
		case tk_sne:	process_setiop(0x1B,3); break;
        case tk_slli: process_shifti(0x8); break;
        case tk_srai: process_shifti(0xB); break;
        case tk_srli: process_shifti(0x9); break;
        case tk_sub:  process_rrop(0x05); break;
        case tk_subi:  process_riop(0x05); break;
        case tk_sv:  process_sv(0x37); break;
        case tk_sw:  process_store(0x16); break;
        case tk_swap: process_rop(0x03); break;
        case tk_sync: emit_insn(0x88000002,0,4); break;
		case tk_unlink: emit_insn((0x1B << 26) | (0x1F << 16) | (30 << 11) | (0x1F << 6) | 0x02,0,4); break;
		case tk_vadd: process_vrrop(0x04); break;
		case tk_vadds: process_vsrrop(0x14); break;
		case tk_vand: process_vrrop(0x08); break;
		case tk_vands: process_vsrrop(0x18); break;
		case tk_vdiv: process_vrrop(0x3E); break;
		case tk_vdivs: process_vsrrop(0x2E); break;
		case tk_vmul: process_vrrop(0x3A); break;
		case tk_vmuls: process_vsrrop(0x2A); break;
		case tk_vor: process_vrrop(0x09); break;
		case tk_vors: process_vsrrop(0x19); break;
		case tk_vsub: process_vrrop(0x05); break;
		case tk_vsubs: process_vsrrop(0x15); break;
		case tk_vxor: process_vrrop(0x0A); break;
		case tk_vxors: process_vsrrop(0x1A); break;
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

