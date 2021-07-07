// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2021  Robert Finch, Waterloo
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
#define I_RR	002
#define I_JRL	0xD3

// Root Level Opcodes
#define I_R1		0x01
#define I_R2		0x02
#define I_R3		0x03
#define I_VM		0x80
#define I_ADDI	0x04
#define I_SUBFI 0x05
#define I_MULI	0x06
#define I_CMP		0x07
#define I_ANDI	0x08
#define I_ORI		0x09
#define I_EORI	0x0A
#define I_XORI	0x0A
#define I_BITI	0x0B
#define I_SHIFT	0x0C
#define I_SET		0x0D
#define I_MULUI	0x0E
#define I_CSR		0x0F
#define I_DIVI	0x10
#define I_DIVUI 0x11
#define I_DIVSUI 0x12
#define I_R2B		0x13
#define I_MULFI		0x15
#define I_MULSUI	0x16
#define I_PERMI	0x17
#define I_REMI	0x18
#define I_REMU	0x19
#define I_BYTNDX	0x1A
#define I_WYDNDX	0x1B
#define I_EXT		0x1C
#define I_DEP		0x1D
#define I_DEPI	0x1E
#define I_FFO		0x1F
#define I_REMSUI	0x20
#define I_DIVRI	0x21
#define I_CHKI	0x22
#define I_SANDI	0x24
#define I_SORI	0x25
#define I_SEQI	0x26
#define I_SNEI	0x27
#define I_SLTI	0x28
#define I_SGEI	0x29
#define I_SLEI  0x2A
#define I_SGTI  0x2B
#define I_SLTUI	0x2C
#define I_SGEUI	0x2D
#define I_SLEUI 0x2E
#define I_SGTUI 0x2F
#define I_ADD5	0x30
#define I_OR5		0x31
#define I_ADD22	0x32
#define I_ADDR2	0x33
#define I_ORR2	0x34
#define I_GCSUB7	0x36
#define I_GCSUBI	0x37
#define I_ADDUI	0x38
#define I_ANDUI	0x3A
#define I_ORUI	0x3C
#define I_AUIIP	0x3E

#define I_RTE		0x45
#define I_BEQ		0x4E
#define I_BNE		0x4F
#define I_BLT		0x48
#define I_BGE		0x49
#define I_BLTU	0x4A
#define I_BGEU	0x4B

#define I_EXI0	0x50
#define I_EXI1	0x51
#define I_EXI2	0x52

#define I_BRA		0x55
#define I_BBS		0x4D
#define I_IMOD	0x58
#define I_BTFLDX	0x59
#define I_BRMOD	0x5A
#define I_JSR18		0x5E
#define I_BT			0x5F

#define I_LDx		0x60
#define I_LDxX	0x61
#define I_LDxZ	0x64
#define I_LDxXZ	0x65
#define I_STx		0x68
#define I_STxX	0x69

#define I_LDOSP20	0x71
#define I_STOSP20	0x73
#define I_JALR20	0x74
#define I_MOV20		0x40074
#define I_ADD20		0x80074
#define I_AND20		0xC0074
#define I_ADDI20	0x75
#define I_ANDI20	0x76
#define I_ORI20		0x77
#define I_BEQZ20	0x78
#define I_BNEZ20	0x79
#define I_BAL20		0x7A
#define I_LDI20		0x7B
#define I_SLLI20	0x7C
#define I_SRLI20	0x4007C
#define I_SUB20		0xC007C
#define I_OR20		0xC027C
#define I_XOR20		0xC047C
#define I_NAND20	0xC067C
#define I_NOR20		0xD007C

#define I_BRK		0x00
#define I_NOP		0x3F
#define I_OSR2	0x07

#define I_JAL		0x40
#define I_BAL		0x41
#define I_JALR	0x42
#define I_RET		0x7B
#define I_CALL	0x7C

#define I_LDBS	0x80
#define I_LDBUS	0x81
#define I_LDWS	0x82
#define I_LDWUS	0x83
#define I_LDTS	0x84
#define I_LDTUS 0x85
#define I_LDOS	0x86
#define I_UNLINK	0x8F

#define I_LEA		0x91
#define I_FLDO	0x92
#define I_PLDO	0x93

#define I_LDB		0x98
#define I_LDBU	0x99
#define I_LDW		0x9A
#define I_LDWU	0x9B
#define I_LDT		0x9C
#define I_LDTU	0x9D
#define I_LDO		0x9E
#define I_LDOR	0x9F

#define I_LDOT	0x88

#define I_LDO24	0x90

#define I_STBS	0xA0
#define I_STWS	0xA1
#define I_STTS	0xA2
#define I_STOS	0xA3
#define I_STOCS	0xA4
#define I_STPTRS	0xA5
#define I_STOTS	0xA6
#define I_STOT	0xA8
#define I_PUSHC	0xA9
#define I_PUSH	0xAA
#define I_FSTO	0xAB
#define I_LINK	0xAD
#define I_STX		0xAF
#define I_STB		0xB8
#define I_STW		0xB9
#define I_STT		0xBA
#define I_STO		0xBB
#define I_STOC	0xBC
#define I_STPTR	0xBD

#define I_FLT2	0xF2
#define I_FMA		0xF4
#define I_FMS		0xF5
#define I_FNMA	0xF6
#define I_FNMS	0xF7

// 1r operations
#define	I_TST		0x0B

// 3r Operations
#define I_MIN		0x0
#define I_MAX		0x1
#define I_MAJ		0x2
#define I_MUX		0x3
#define I_ADD3	0x4
#define I_SUB3	0x5
#define I_CMOVENZ	0x6
#define I_FLIP	0x7
#define I_AND3	0x0
#define I_OR3		0x1
#define I_EOR3	0x2
#define I_DEP3	0x3
#define I_EXT3	0x4
#define I_EXTU3	0x5
#define I_BLEND	0x6
#define I_PTRDIF	0x18

// 2r Operations
#define I_AND2	0x00
#define I_OR2		0x01
#define I_EOR2	0x02
#define I_XOR2	0x02
#define I_BMM		0x03
#define I_ADD2	0x04
#define I_SUB2	0x05
#define I_MUL		0x06
#define I_NAND	0x08
#define I_NOR		0x09
#define I_ENOR	0x0A
#define I_XNOR	0x0A
#define I_BIT		0x0B
#define I_R1		0x0C
#define I_MOV		0x0D
#define I_MULU	0x0E
#define I_MULH	0x0F
#define I_DIV		0x10
#define I_DIVU	0x11
#define I_DIVSU	0x12
#define I_REM		0x13
#define I_REMU	0x14
#define I_REMSU	0x15
#define I_MULSU	0x16
#define I_PERM	0x17
#define I_DIF		0x18
#define I_SLL		0x19
#define I_SLLI	0x1A
//#define I_BYTNDX2	0x1A
#define I_WYDNDX2	0x1B
#define I_MULF		0x1C
#define I_MULSUH	0x1D
#define I_MULUH	0x1E
#define I_SRL		0x21
#define I_SRLI	0x22

#define I_CHK2B		0x00
#define I_CMPR2B	0x14
#define I_CMPUR2B	0x15

// Shift Operations
#define I_SHL		0x0
#define I_SHLI	0x8
#define I_ASL		0x0
#define I_ASLI	0x8
#define I_LSR		0x1
#define I_LSRI  0x9
#define I_SHR		0x1
#define I_SHRI	0x9
#define I_ASR		0x4
#define I_ASRI	0xC
#define I_ROL		0x2
#define I_ROLI	0xA
#define I_ROR		0x3
#define I_RORI	0xB
#define I_ASLX	0x5
#define I_ASLXI	0xD

// 2r Set operations
#define I_SEQ		0x0
#define I_SNE		0x1
#define I_SAND	0x2
#define I_SOR		0x3
#define I_SLT		0x4
#define I_SLTU	0x5
#define I_SGE		0x6
#define I_SGEU	0x7

// osr2
#define I_GCSUB	0x03
#define I_PUSHQ	0x08
#define I_POPQ	0x09
#define I_PEEKQ	0x0A
#define I_SETKEY	0x0C
#define I_GCCLR	0x0D
#define I_REX		0x10
#define I_PFI		0x11
#define I_WAI		0x12
#define I_SETTO 0x18
#define I_GETTO	0x19
#define I_GETZL 0x1A
#define I_MVMAP	0x1C
#define I_MVSEG	0x1D
#define I_MVCI	0x1F

#define I_FCMP	0x10
#define I_FSEQ	0x11
#define I_FSLT	0x12
#define I_FSLE	0x13

#define I_LDM		0x6F
#define I_STM		0x7F

//#define I_SRL		0x400000591400001CLL
#define I_CSRRD		0x000000000FLL
#define I_CSRRW		0x000000200FLL
#define I_CSRRC		0x000008000FLL
#define I_CSRRS		0x000008200FLL

#define CI_TABLE_SIZE		512

static void (*jumptbl[tk_last_token])();
static int64_t parm1[tk_last_token];
static int64_t parm2[tk_last_token];
static int64_t parm3[tk_last_token];

extern InsnStats insnStats;
static void ProcessEOL(int opt);
extern void process_message();
static void mem_operand(int64_t *disp, int *regA, int *regB, int *Sc, int *seg);

extern char *pif1;
extern int first_rodata;
extern int first_data;
extern int first_bss;
extern int htblmax;
extern int pass;
extern int num_cinsns;

static int64_t ca;
static int recflag;

extern int use_gp;

static int regPC = 31;
static int regSP = 30;
static int regFP = 29;
static int regGP = 28;
static int regGP1 = 27;
static int regTP = 26;
static int regArg = 20;
static int regTmp = 4;
static int regReg = 10;
static int regCB = 2;
static int regXL = 1;
static int regCnst;

#define OPT64     0
#define OPTX32    1
#define OPTLUI0   0
#define LB16	-31653LL

#define S_BYTE	0
#define S_WYDE	1
#define S_TETRA	2
#define S_OCTA	3
#define S_HEXI	4

#define RT(x)		(((x) & 0x3fLL) << 8LL)
#define RD(x)		(((x) & 0x3fLL) << 8LL)
#define RA(x)		(((x) & 0x3FLL) << 14LL)
#define RB(x)		(((x) & 0x7fLL) << 20LL)
#define TA(x)		(((x) & 1LL) << 19LL)
#define FUNC4(x)	(((x) & 15LL) << 32LL)
#define FUNC6(x)	(((x) & 0x7FLL) << 29LL)
#define IMM(x)	(((x) & 0xffffLL) << 20LL)
#define SHI7(x)	((((x) & 0x60LL) << 29LL) | RB(((x) & 0x3fLL)))
#define STDISP(x)	((((x) & 0x1fLL) << 8LL) | (((x) & 0x1fE0LL) << 23LL))
#define LDDISP(x)	(((x) & 0x3ffffLL) << 13LL)
#define AM(x)		(((x) & 1LL << 38LL))
#define RETIMM(x)	(((x) & 0x1ffff0LL) << 18LL)
#define P2(x)			(((x) & 3LL) << 11LL)
#define BRDISP(x)	((((x) >> 6LL) & 0xffLL) << 32LL) | (((x)&63LL)<<8LL)
#define BO(x)		(((x) & 0x3fLL) << 14LL)
#define BW(x)		(((x) & 0x3fLL) << 20LL)


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void error(char *msg)
{
	printf("%s. (%d)\n", msg, /*mname.c_str(), */lineno);
	fprintf(ofp, "%s. (%d)\n", msg, /*mname.c_str(), */lineno);
}

// ----------------------------------------------------------------------------
// Return the register number or -1 if not a register.
// Parses pretty register names like SP or BP in addition to r1,r2,etc.
// ----------------------------------------------------------------------------

//static int getRegisterX()
//{
//    int reg;
//
//    while(isspace(*inptr)) inptr++;
//	if (*inptr == '$')
//		inptr++;
//    switch(*inptr) {
//    case 'r': case 'R':
//        if ((inptr[1]=='a' || inptr[1]=='A') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 29;
//        }
//         if (isdigit(inptr[1])) {
//             reg = inptr[1]-'0';
//             if (isdigit(inptr[2])) {
//                 reg = 10 * reg + (inptr[2]-'0');
//                 if (isdigit(inptr[3])) {
//                     reg = 10 * reg + (inptr[3]-'0');
//                     if (isIdentChar(inptr[4]))
//                         return -1;
//                     inptr += 4;
//                     any1_NextToken();
//                     return reg;
//                 }
//                 else if (isIdentChar(inptr[3]))
//                     return -1;
//                 else {
//                     inptr += 3;
//                     any1_NextToken();
//                     return reg;
//                 }
//             }
//             else if (isIdentChar(inptr[2]))
//                 return -1;
//             else {
//                 inptr += 2;
//                 any1_NextToken();
//                 return reg;
//             }
//         }
//         else return -1;
//    case 'a': case 'A':
//         if (isdigit(inptr[1])) {
//             reg = inptr[1]-'0' + 18;
//             if (isIdentChar(inptr[2]))
//                 return -1;
//             else {
//                 inptr += 2;
//                 any1_NextToken();
//                 return reg;
//             }
//         }
//         else return -1;
//    case 'b': case 'B':
//        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 30;
//        }
//        break;
//    case 'f': case 'F':
//        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 2;
//        }
//        break;
//    case 'g': case 'G':
//        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 26;
//        }
//        break;
//    case 'p': case 'P':
//        if ((inptr[1]=='C' || inptr[1]=='c') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 31;
//        }
//        break;
//    case 's': case 'S':
//        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 31;
//        }
//        break;
//    case 't': case 'T':
//         if (isdigit(inptr[1])) {
//             reg = inptr[1]-'0' + 26;
//             if (isIdentChar(inptr[2]))
//                 return -1;
//             else {
//                 inptr += 2;
//                 any1_NextToken();
//                 return reg;
//             }
//         }
//        if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 15;
//        }
//        /*
//        if ((inptr[1]=='R' || inptr[1]=='r') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 24;
//        }
//        */
//        break;
//	// lr
//    case 'l': case 'L':
//        if ((inptr[1]=='R' || inptr[1]=='r') && !isIdentChar(inptr[2])) {
//            inptr += 2;
//            any1_NextToken();
//            return 29;
//        }
//        break;
//	// xlr
//    case 'x': case 'X':
//        if ((inptr[1]=='L' || inptr[1]=='l') && (inptr[2]=='R' || inptr[2]=='r') && 
//			!isIdentChar(inptr[3])) {
//            inptr += 3;
//            any1_NextToken();
//            return 28;
//        }
//        break;
//    default:
//        return -1;
//    }
//    return -1;
//}

static int getRegisterX()
{
  int reg;
	char *p;

  while(isspace(*inptr))
		inptr++;
	if (*inptr == '$')
		inptr++;
	if (*inptr == '#') {
		inptr++;
		any1_NextToken();
		reg = expr();
//		any1_NextToken();
		return (reg|0x40);
	}
  switch(*inptr) {
  case 'r': case 'R':
    if (inptr[1]=='a' || inptr[1]=='A') {
			if (isdigit(inptr[2])) {
				if (inptr[2] != '0' && inptr[2] != '1')
					return (-1);
				if (!isIdentChar(inptr[3])) {
					inptr += 3;
					reg = 96 + inptr[2] - '0';
					any1_NextToken();	// Will modify inptr!
					return (reg);
				}
				return (-1);
			}
			else if (!isIdentChar(inptr[2])) {
				inptr += 2;
				any1_NextToken();
				return (96);
			}
			return (-1);
    }
    if (isdigit(inptr[1])) {
      reg = inptr[1]-'0';
      if (isdigit(inptr[2])) {
        reg = 10 * reg + (inptr[2]-'0');
        if (isdigit(inptr[3])) {
          reg = 10 * reg + (inptr[3]-'0');
					if (isdigit(inptr[4])) {
						reg = 10 * reg + (inptr[4] - '0');
						if (isIdentChar(inptr[5]))
							return (-1);
						else {
							inptr += 5;
							any1_NextToken();
							return (reg);
						}
					}
					else if (isIdentChar(inptr[4]))
						return (-1);
					else {
						inptr += 4;
						any1_NextToken();
						return (reg);
					}
        }
        else if (isIdentChar(inptr[3]))
          return (-1);
        else {
          inptr += 3;
          any1_NextToken();
          return (reg);
        }
      }
      else if (isIdentChar(inptr[2]))
        return (-1);
      else {
        inptr += 2;
        any1_NextToken();
        return (reg);
      }
    }
		return (-1);

  case 'a': case 'A':
    if (isdigit(inptr[1])) {
      reg = inptr[1]-'0' + regArg;
      if (isIdentChar(inptr[2]))
        return (-1);
      inptr += 2;
      any1_NextToken();
      return (reg);
    }
		return (-1);

  case 'f': case 'F':
		if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
			inptr += 2;
			any1_NextToken();
			return (regFP);
		}
		if (isdigit(inptr[1])) {
			reg = 64 + inptr[1] - '0';
			if (isdigit(inptr[2])) {
				reg = reg * 10 + inptr[2] - '0';
				if (!isIdentChar(inptr[3])) {
					inptr += 3;
					any1_NextToken();
					return (reg);
				}
			}
			if (!isIdentChar(inptr[2])) {
				inptr += 2;
				any1_NextToken();
				return (reg);
			}
		}
		break;

  case 'g': case 'G':
    if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
      inptr += 2;
      any1_NextToken();
      return (regGP);
    }
		if ((inptr[1] == 'P' || inptr[1] == 'p') && 
			(inptr[2]=='1') && 
			!isIdentChar(inptr[3])) {
			inptr += 3;
			any1_NextToken();
			return (regGP1);
		}
		break;

  case 's': case 'S':
    if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
      inptr += 2;
      any1_NextToken();
      return (regSP);
    }
		if (isdigit(inptr[1])) {
			if (!isIdentChar(inptr[2])) {
				reg = regReg + inptr[1] - '0';
				inptr += 2;
				any1_NextToken();
				return (reg);
			}
		}
    break;

    case 't': case 'T':
      if (isdigit(inptr[1])) {
        reg = inptr[1]-'0' + regTmp;
        if (isIdentChar(inptr[2]))
          return (-1);
        else {
          inptr += 2;
          any1_NextToken();
          return (reg);
        }
      }
      if ((inptr[1]=='P' || inptr[1]=='p') && !isIdentChar(inptr[2])) {
          inptr += 2;
          any1_NextToken();
          return (regTP);
      }
      break;
	// lk0 to lk7
    case 'l': case 'L':
			if ((inptr[1] == 'R' || inptr[1] == 'r') && !isIdentChar(inptr[2])) {
				reg = 1;
					inptr += 2;
					any1_NextToken();
					return (reg);
				}
        if (inptr[1]=='K' || inptr[1]=='k') {
					if (isdigit(inptr[2]) && !isIdentChar(inptr[3])) {
						reg = inptr[2] - '0' + 1;
						inptr += 3;
						any1_NextToken();
						return (reg);
					}
        }
        break;
	// cr, cr0 to cr3, cn0 to cn1
		case 'c': case 'C':
			if (inptr[1] == 'R' || inptr[1] == 'r') {
				reg = 125;
				if (isdigit(inptr[2]) && !isIdentChar(inptr[3])) {
					reg = inptr[2] - '0' + 112;
					inptr += 3;
				}
				else if (!isIdentChar(inptr[2])) {
					inptr += 2;
				}
				any1_NextToken();
				return (reg);
			}
			else if (inptr[1] == 'N' || inptr[1] == 'n') {
				reg = 114;
				if (isdigit(inptr[2]) && !isIdentChar(inptr[3])) {
					reg = inptr[2] - '0' + 114;
					inptr += 3;
				}
				else if (!isIdentChar(inptr[2])) {
					inptr += 2;
				}
				any1_NextToken();
				return (reg);
			}
			break;
		// xlr
    case 'x': case 'X':
			if (isdigit(inptr[1])) {
				reg = inptr[1] - '0';
				if (isdigit(inptr[2])) {
					reg = reg * 10 + inptr[2] - '0';
					if (!isIdentChar(inptr[3])) {
						inptr += 3;
						any1_NextToken();
						return (reg);
					}
					return (-1);
				}
				if (!isIdentChar(inptr[2])) {
					inptr += 2;
					any1_NextToken();
					return (reg);
				}
				return (-1);
			}
      if ((inptr[1]=='L' || inptr[1]=='l') && (inptr[2]=='R' || inptr[2]=='r') && 
			!isIdentChar(inptr[3])) {
            inptr += 3;
            any1_NextToken();
            return (regXL);
        }
        break;
	case 'v': case 'V':
		// vm0 to vm7
		if ((inptr[1] == 'M' || inptr[1] == 'm') && !isIdentChar(inptr[2])) {
			if (isdigit(inptr[2]) && !isIdentChar(inptr[3])) {
				reg = inptr[1] - '0' + 104;
				inptr += 3;
				any1_NextToken();
				return (reg);
			}
		}
		// v0 to v31
		if (isdigit(inptr[1])) {
             reg = inptr[1]-'0' + 64;
             if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 any1_NextToken();
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

static int IsRn3(int rg)
{
	switch (rg) {
	case 1: return 0;		// RA
	case 4: return 1;		// temp
	case 5: return 2;		// temp
	case 10: return 3;	// Saved
	case 11: return 4;	// saved
	case 20: return 5;	// arg
	case 21: return 6;	// arg
	case 22: return 7;	// arg
	default:	return -1;
	}
}

// ----------------------------------------------------------------------------
// Return the register number or -1 if not a register.
// Parses pretty register names like SP or BP in addition to r1,r2,etc.
// ----------------------------------------------------------------------------

static int getVecRegister()
{
    int reg;

    while(isspace(*inptr)) inptr++;
	if (*inptr=='$')
		inptr++;
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
                     any1_NextToken();
                     return reg;
                 }
                 else if (isIdentChar(inptr[3]))
                     return -1;
                 else {
                     inptr += 3;
                     any1_NextToken();
                     return reg;
                 }
             }
             else if (isIdentChar(inptr[2]))
                 return -1;
             else {
                 inptr += 2;
                 any1_NextToken();
                 return reg;
             }
         }
		 else if (inptr[1]=='l' || inptr[1]=='L') {
			 if (!isIdentChar(inptr[2])) {
				 inptr += 2;
				 any1_NextToken();
				 return 0x2F;
			 }
		 }
         else if (inptr[1]=='m' || inptr[1]=='M') {
			 if (isdigit(inptr[2])) {
				 if (inptr[2] >= '0' && inptr[2] <= '7') {
					 if (!isIdentChar(inptr[3])) {
						 reg = 0x20 | (inptr[2]-'0');
						 inptr += 3;
						 any1_NextToken();
						 return (reg);
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
                  any1_NextToken();
                  return pr | 0x40;
              }
         }
         else if (isdigit(inptr[1])) {
              pr = (inptr[1]-'0');
              if (!isIdentChar(inptr[2])) {
                  inptr += 2;
                  any1_NextToken();
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
         any1_NextToken();
         any1_NextToken();
         return (int)ival.low & 0xFFF;

    // arg1
    case 'a': case 'A':
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='g' || inptr[2]=='G') &&
             (inptr[3]=='1' || inptr[3]=='1') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             any1_NextToken();
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
             any1_NextToken();
             return 11;
         }
         break;
    // cas clk cr0 cr3 cs CPL
    case 'c': case 'C':
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             (inptr[2]=='s' || inptr[2]=='S') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 44;
         }
         if ((inptr[1]=='l' || inptr[1]=='L') &&
             (inptr[2]=='k' || inptr[2]=='K') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 0x06;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='0') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 0x00;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='3') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
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
                       any1_NextToken();
                       return 0x2F;
               }
            }
            inptr += 2;
            any1_NextToken();
            return 0x27;
        }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='l' || inptr[2]=='L') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
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
             any1_NextToken();
             return 50;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             (inptr[4]=='1' || inptr[4]=='1') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             any1_NextToken();
             return 51;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             (inptr[4]=='2' || inptr[4]=='2') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             any1_NextToken();
             return 52;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='d' || inptr[3]=='D') &&
             (inptr[4]=='3' || inptr[4]=='3') &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             any1_NextToken();
             return 53;
         }
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             (inptr[3]=='t' || inptr[3]=='T') &&
             (inptr[4]=='r' || inptr[4]=='R') &&
             (inptr[5]=='l' || inptr[5]=='L') &&
             !isIdentChar(inptr[6])) {
             inptr += 6;
             any1_NextToken();
             return 54;
         }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 7;
         }
         if (
             (inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             (inptr[3]=='c' || inptr[3]=='C') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             any1_NextToken();
             return 7;
         }
         if ((inptr[1]=='s' || inptr[1]=='S') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
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
                       any1_NextToken();
                       return 0x29;
               }
            }
            inptr += 2;
            any1_NextToken();
            return 0x21;
        }
         break;

    // ea epc esp es
    case 'e': case 'E':
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             !isIdentChar(inptr[2])) {
             inptr += 2;
             any1_NextToken();
             return 40;
         }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 9;
         }
         if ((inptr[1]=='s' || inptr[1]=='S') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
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
                       any1_NextToken();
                       return 0x2A;
               }
            }
            inptr += 2;
            any1_NextToken();
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
             any1_NextToken();
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
                       any1_NextToken();
                       return 0x2B;
               }
            }
            inptr += 2;
            any1_NextToken();
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
                       any1_NextToken();
                       return 0x2C;
               }
            }
            inptr += 2;
            any1_NextToken();
            return 0x24;
        }
        if ((inptr[1]=='d' || inptr[1]=='D') &&
           (inptr[2]=='t' || inptr[2]=='T') &&
            !isIdentChar(inptr[3])) {
            inptr += 3;
            any1_NextToken();
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
             any1_NextToken();
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
                       any1_NextToken();
                       return 0x2D;
               }
            }
            inptr += 2;
            any1_NextToken();
            return 0x25;
        }
         break;

    // ipc isp ivno
    case 'i': case 'I':
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='c' || inptr[2]=='C') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 8;
         }
         if ((inptr[1]=='s' || inptr[1]=='S') &&
             (inptr[2]=='p' || inptr[2]=='P') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 15;
         }
         if ((inptr[1]=='v' || inptr[1]=='V') &&
             (inptr[2]=='n' || inptr[2]=='N') &&
             (inptr[3]=='o' || inptr[3]=='O') &&
             !isIdentChar(inptr[4])) {
             inptr += 4;
             any1_NextToken();
             return 0x0C;
         }
         break;


    // LC LDT
    case 'l': case 'L':
         if ((inptr[1]=='c' || inptr[1]=='C') &&
             !isIdentChar(inptr[2])) {
             inptr += 2;
             any1_NextToken();
             return 0x33;
         }
         if ((inptr[1]=='d' || inptr[1]=='D') &&
            (inptr[2]=='t' || inptr[2]=='T') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
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
             any1_NextToken();
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
             any1_NextToken();
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
             any1_NextToken();
             return 0x1A;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='n' || inptr[3]=='N') &&
             (inptr[4]=='d' || inptr[4]=='D') &&
             (inptr[5]=='1') &&
             !isIdentChar(inptr[6])) {
             inptr += 6;
             any1_NextToken();
             return 0x10;
         }
         if ((inptr[1]=='r' || inptr[1]=='R') &&
             (inptr[2]=='a' || inptr[2]=='A') &&
             (inptr[3]=='n' || inptr[3]=='N') &&
             (inptr[4]=='d' || inptr[4]=='D') &&
             (inptr[5]=='2') &&
             !isIdentChar(inptr[6])) {
             inptr += 6;
             any1_NextToken();
             return 0x11;
         }
         if ((inptr[1]=='p' || inptr[1]=='P') &&
             (inptr[2]=='r' || inptr[2]=='R') &&
             isdigit(inptr[3]) && isdigit(inptr[4]) &&
             !isIdentChar(inptr[5])) {
             inptr += 5;
             any1_NextToken();
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
                       any1_NextToken();
                       return 0x2E;
               }
            }
            inptr += 2;
            any1_NextToken();
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
               any1_NextToken();
               return 43;
             }
             // segbase
             if ((inptr[3]=='b' || inptr[3]=='B') &&
                  (inptr[4]=='a' || inptr[4]=='A') &&
                  (inptr[5]=='s' || inptr[5]=='S') &&
                  (inptr[6]=='e' || inptr[6]=='E') &&
                  !isIdentChar(inptr[7])) {
               inptr += 7;
               any1_NextToken();
               return 44;
             }
             // seglmt
             if ((inptr[3]=='l' || inptr[3]=='L') &&
                  (inptr[4]=='m' || inptr[4]=='M') &&
                  (inptr[5]=='t' || inptr[5]=='T') &&
                  !isIdentChar(inptr[6])) {
               inptr += 6;
               any1_NextToken();
               return 45;
             }
             // segacr
             if ((inptr[3]=='a' || inptr[3]=='A') &&
                  (inptr[4]=='c' || inptr[4]=='C') &&
                  (inptr[5]=='r' || inptr[5]=='R') &&
                  !isIdentChar(inptr[6])) {
               inptr += 6;
               any1_NextToken();
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
             any1_NextToken();
             return 0x32;
         }
         if ((inptr[1]=='a' || inptr[1]=='A') &&
             (inptr[2]=='g' || inptr[2]=='G') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
             return 41;
         }
         break;

    // vbr
    case 'v': case 'V':
         if ((inptr[1]=='b' || inptr[1]=='B') &&
             (inptr[2]=='r' || inptr[2]=='R') &&
             !isIdentChar(inptr[3])) {
             inptr += 3;
             any1_NextToken();
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
                       any1_NextToken();
                       return 0x28;
               }
            }
            inptr += 2;
            any1_NextToken();
            return 0x20;
        }
        break;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// Process the size specifier for a FP instruction.
// h: half (16 bit)
// s: single (32 bit)
// d: double (64 bit)
// t: triple (96 bit)
// q: quad (128 bit)
// ---------------------------------------------------------------------------

static int GetFPSize()
{
	int sz;

  sz = 'd';
  if (*inptr=='.') {
    inptr++;
    if (strchr("hsdtqHSDTQ",*inptr)) {
      sz = tolower(*inptr);
      inptr++;
    }
		else {
			inptr--;
			return (-1);
//			error("Illegal float size");
		}
  }
	switch(sz) {
	case 'h':	sz = 0; break;
	case 's':	sz = 1; break;
	case 'd':	sz = 2; break;
	case 't':	sz = 3; break;
	case 'q':	sz = 4; break;
	default:	sz = 3; break;
	}
	return (sz);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static bool iexpand(int64_t oc)
{
	if ((oc >> 7) & 1) {
		switch ((((oc >> 12) & 0x0F) << 1) | ((oc >> 6) & 1)) {
		case 0:
			insnStats.adds++;
			break;
		case 1:
			insnStats.moves++;
			break;
		case 2:
			if ((oc & 0x01f) != 0)
				insnStats.adds++;
			break;
		case 4:
			if ((oc & 0x1f) == 0)
				insnStats.rets++;
			else
				insnStats.ands++;
			break;
		case 5:	insnStats.calls++; break;
		case 6: insnStats.shls++; break;
		case 7:
			if (((oc >> 8) & 0xF) == 0)
				insnStats.pushes++;
			break;
		case 8:
			switch ((oc >> 4) & 3) {
			case 0:
			case 1:
				insnStats.shifts++;
				break;
			case 2:
				insnStats.ors++;
				break;
			case 3:
				switch ((oc >> 10) & 3) {
				case 1:
					insnStats.ands++;
					break;
				case 2:
					insnStats.ors++;
					break;
				case 3:
					insnStats.xors++;
					break;
				}
			}
		case 9:
		case 11:
		case 13:
		case 15:
		case 25:
		case 27:
			insnStats.loads++;
			break;
		case 17:
		case 19:
		case 21:
		case 23:
		case 29:
		case 31:
			insnStats.stores++;
			break;
		case 14:
		case 16:
		case 18:
		case 20:
		case 22:
		case 24:
		case 26:
		case 28:
		case 30:
			insnStats.branches++;
			break;
		}
		return true;
	}
	return false;
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void emit_insn(int64_t oc, int length = 9, bool can_compress = false)
{
	int ndx;
	int opmajor = oc & 0xff;
	int ls;
	int cond;

	if (fEmitCode) {
		switch (opmajor) {
		case I_R1:
			switch ((oc >> 26LL) & 0x3fLL) {
			}
			break;
		case I_R2:
			switch ((oc >> 26LL) & 0x3fLL) {
			case I_MOV:
				insnStats.moves++;
				break;
			case I_ADD2:
				insnStats.adds++;
				break;
			case I_SUB2:
				insnStats.subs++;
				break;
			case I_AND2:
				insnStats.ands++;
				break;
			case I_OR2:
				insnStats.ors++;
				break;
			case I_XOR2:
				insnStats.xors++;
				break;
			case I_CMP:
				if ((oc >> 10LL) & 7LL)
					insnStats.mops++;
				insnStats.compares++;
				break;
			}
			break;
		case I_R3:
			switch ((oc >> 26LL) & 63LL) {
			case I_PTRDIF:
			case I_PTRDIF + 1:
				insnStats.ptrdif++;
				break;
			case I_EXT3:
			case I_EXTU3:
			case I_DEP3:
				insnStats.bitfields++;
				break;
			}
			break;
		case I_SET:
			switch ((oc >> 26LL) & 0x63LL) {
			case I_SLT:
			case I_SLTU:
			case I_SGE:
			case I_SGEU:
			case I_SEQ:
			case I_SNE:
				insnStats.sets++;
				break;
			}
			break;
		case I_ADDI:
			insnStats.adds++;
			break;
		case I_ANDI:
			insnStats.ands++;
			break;
		case I_ORI:
			insnStats.ors++;
			break;
		case I_XORI:
			insnStats.xors++;
			break;
		case I_EXT:
		case I_DEP:
		case I_DEPI:
			insnStats.bitfields++;
			break;
		case I_STBS:
		case I_STWS:
		case I_STTS:
		case I_STOS:
		case I_STOCS:
		case I_STOTS:
			insnStats.stores++;
			break;
		case I_STB:
		case I_STW:
		case I_STT:
		case I_STO:
		case I_STOC:
		case I_STOT:
			if ((oc & 0x4000000LL) == 0)
				insnStats.indexed++;
			insnStats.stores++;
			break;
		case I_LDBS:
		case I_LDBUS:
		case I_LDWS:
		case I_LDWUS:
		case I_LDTS:
		case I_LDTUS:
		case I_LDOS:
			insnStats.loads++;
			break;
		case I_LDB:
		case I_LDBU:
		case I_LDW:
		case I_LDWU:
		case I_LDT:
		case I_LDTU:
		case I_LDO:
		case I_LDOT:
			if ((oc & 0x4000000LL) == 0)
				insnStats.indexed++;
			insnStats.loads++;
			break;
		case I_CALL:
		case I_JAL:
		case I_BAL:
			insnStats.calls++;
			break;
		case I_RET:
			insnStats.rets++;
			break;
		case I_RTE:
			insnStats.rets++;
			break;
		case I_SLTI:
		case I_SLTUI:
		case I_SGTI:
		case I_SGTUI:
		case I_SEQI:
		case I_SNEI:
		case I_SANDI:
		case I_SORI:
			insnStats.sets++;
			break;
		case I_BBS:
			insnStats.bbc++;
		case I_BEQ:
		case I_BNE:
		case I_BLT:
		case I_BGE:
		case I_BRA:
			insnStats.branches++;
			break;
		case I_CSR:
			insnStats.csrs++;
			break;
		case I_PERMI:
			break;
		case I_WYDNDX:
			break;
		case I_CMP:
			insnStats.compares++;
			break;
		case I_FLT2:
			insnStats.floatops++;
			break;
		case I_NOP:
			break;
		}
	}

	if (fEmitCode && length <= 4 && length > 2) {
		switch (length) {
		case 4:	oc = oc & 0xffffffffLL; break;
		case 3: oc = oc & 0xffffffLL; break;
		case 2: oc = oc & 0xffffLL; break;
		default: oc = oc & 0xffffLL; break;
		}
		if (pass == 3 && can_compress && !expand_flag && gCanCompress) {
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
			error("Too many instructions");
			return;
		}
	}
	if (fEmitCode) {
		if (pass > 3) {
			if (can_compress && !expand_flag && gCanCompress && length > 2 && length <= 4) {
				for (ndx = 0; ndx < min(CI_TABLE_SIZE, htblmax); ndx++) {
					if (oc == hTable[ndx].opcode) {
						emitCode(0x60 | (ndx >> 8));
						emitCode(ndx);
						num_bytes += 2;
						num_insns += 1;
						num_cinsns += 1;
						insnStats.total++;
						return;
					}
				}
			}
			emitNybble(oc & 15LL);
			emitNybble(((oc) >> 4LL) & 15LL);
			emitNybble(((oc) >> 8LL) & 15LL);
			emitNybble(((oc) >> 12LL) & 15LL);
			emitNybble(((oc) >> 16LL) & 15LL);
			if (length > 5) {
				emitNybble(((oc) >> 20LL) & 15LL);
				emitNybble(((oc) >> 24LL) & 15LL);
				emitNybble(((oc) >> 28LL) & 15LL);
				emitNybble(((oc) >> 32LL) & 15LL);
				num_bytes += 4.5;
			}
			else {
				num_bytes += 2.5;
				num_cinsns++;
			}
			insnStats.total++;
			num_insns += 1;
		}
	}
}

static void LoadConstant(int64_t val, int rg)
{
	int64_t val1, val2;

	if (IsNBit(val, 7LL)) {
		emit_insn((val << 13LL) | (rg << 8LL) | I_LDI20, 5);
		return;
	}
	if (IsNBit(val, 16LL)) {
		emit_insn(
			((val & 0xffffLL) << 20LL) |
			RA(0) | RT(rg) |
			I_ADDI);	// ADDI (sign extends)
		return;
	}
	if (IsNBit(val, 39LL)) {
		emit_insn(((val >> 11LL) << 8LL) | I_EXI0);
		emit_insn(((val & 0xFFFFLL) << 20LL) | RA(0) | RT(rg) | I_ADDI);
		return;
	}
	if (IsNBit(val, 67LL)) {
		emit_insn(((val >> 11LL) << 8LL) | I_EXI0);
		emit_insn(((val >> 39LL) << 8LL) | I_EXI1);
		emit_insn(((val & 0xFFFFLL) << 20LL) | RA(0) | RT(rg) | I_ADDI);
		return;
	}
	emit_insn(((val >> 11LL) << 8LL) | I_EXI0);
	emit_insn(((val >> 39LL) << 8LL) | I_EXI1);
	emit_insn(((val >> 67LL) << 8LL) | I_EXI2);
	emit_insn(((val & 0xFFFFLL) << 20LL) | RA(0) | RT(rg) | I_ADDI);
	return;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
static void getSz(int *sz)
{
	if (*inptr=='.')
		inptr++;
    *sz = inptr[0];
    switch(*sz) {
    case 'b': case 'B':
		if (inptr[1] == 'p' || inptr[1] == 'P') {
			inptr+=2;
			*sz = 11;
		}
		else {
			inptr++;
			*sz = 3;
		}
		break;
	case 'w': case 'W':
		if (inptr[1] == 'p' || inptr[1] == 'P') {
			inptr+=2;
			*sz = 10;
		}
		else {
			inptr++;
			*sz = 2;
		}
		break;
    case 't': case 'T':
		if (inptr[1] == 'p' || inptr[1] == 'P') {
			inptr+=2;
			*sz = 9;
		}
		else {
			inptr++;
			*sz = 1;
		}
		break;
    case 'o': case 'O':
		if (inptr[1] == 'p' || inptr[1] == 'P') {
			inptr+=2;
			*sz = 8;
		}
		else {
			inptr++;
			*sz = 0;
		}
		break;
	case 'd': case 'D': *sz = 0x83; break;
	case 'i': case 'I': *sz = 0x43; break;
  default: 
//    error("Bad size");
		inptr--;
    *sz = 0;
  }
}

// ---------------------------------------------------------------------------
// Get memory aquire and release bits.
// ---------------------------------------------------------------------------

static void GetArBits(int64_t *aq, int64_t *rl)
{
	*aq = *rl = 0;
	while (*inptr == '.') {
		inptr++;
		if (inptr[0] != 'a' && inptr[0] != 'A' && inptr[0] != 'r' && inptr[0] != 'R') {
			inptr--;
			break;
		}
		if ((inptr[0] == 'a' || inptr[0] == 'A') && (inptr[1] == 'q' || inptr[1] == 'Q')) {
			inptr += 2;
			*aq = 1;
		}
		if ((inptr[0] == 'r' || inptr[0] == 'R') && (inptr[1] == 'l' || inptr[1] == 'L')) {
			inptr += 2;
			*rl = 1;
		}
	}
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_getzl(int oc)
{
	int Rd;

	if (*inptr == '.') {
		inptr++;
		recflag = true;
	}
	Rd = getRegisterX();
	emit_insn(
		FUNC6(oc) |
		RT(Rd) |
		I_OSR2, true
	);
	prevToken();
}

static void process_permi(int64_t opcode6, int64_t func6, int64_t bit23)
{
	int Ra;
	int Rt, Rtp;
	char* p;
	int64_t val;
	int sz = 3;
	bool li = false;
	int left = 0;

	// Check for left/right indicator
	p = inptr;
	if (*p == '.') {
		inptr++;
		if (p[1] == 'l' || p[1] == 'L') {
			inptr++;
			left = 1;
		}
		else if (p[1] == 'r' || p[1] == 'R') {
			inptr++;
			left = 0;
		}
		else {
			inptr--;
		}
	}
	Rt = getRegisterX();
	need(',');
	p = inptr;
	Ra = getRegisterX();
	if (Ra < 0) {
	}
	else {
		need(',');
	}
	any1_NextToken();
	val = expr();

	emit_insn(
		((val >> 12LL) << 20LL) |
		I_BRMOD
	);
	emit_insn(
		IMM(val & 0xffffLL) |
		RT(Rt) |
		RA(Ra) |
		opcode6);
xit:
	ScanToEOL();
}

static void ext11(int64_t val)
{
	if (!IsNBit(val, 11LL)) {
		if (!IsNBit(val, 39LL)) {
			// Fits into 67 bits?
			if (!IsNBit(val, 67LL)) {
				emit_insn(
					((val >> 11LL) << 8LL) |
					I_EXI0, false
				);
				emit_insn(
					((val >> 39LL) << 8LL) |
					I_EXI1, false
				);
				emit_insn(
					((val >> 67LL) << 8LL) |
					I_EXI2, false
				);
			}
			// Fits into 67 bits
			else {
				emit_insn(
					((val >> 11LL) << 8LL) |
					I_EXI0, false
				);
				emit_insn(
					((val >> 39LL) << 8LL) |
					I_EXI1, false
				);
			}
		}
		// Fits into 39 bits
		else {
			emit_insn(
				((val >> 11LL) << 8LL) |
				I_EXI0, false
			);
		}
	}
}

// ---------------------------------------------------------------------------
// addi r1,r2,#1234
//
// A value that is too large has to be loaded into a register then the
// instruction converted to a registered form.
// So
//		addi	r1,r2,#$12345678
// Becomes:
// ---------------------------------------------------------------------------

static void process_riop(int64_t opcode6, int64_t func6, int64_t bit23)
{
	int Ra;
	int Rt, Rtp;
	char *p;
	int64_t val;
	int sz = 3;
	bool li = false;

	p = inptr;
	if (*p == '.')
		getSz(&sz);
	Rt = getRegisterX();
	need(',');
	p = inptr;
	Ra = getRegisterX();
	if (Ra < 0) {
		error("A source register is needed for RI operation");
		Ra = 0;
	}
	else {
		need(',');
	}
	any1_NextToken();
	val = expr();

	if (opcode6==-I_ADDI)	{ // subi
		val = -val;
		opcode6 = I_ADDI;	// change to addi
	}
	if (opcode6 == I_WYDNDX) {
		emit_insn(
			((val >> 13LL) << 32LL) |
			IMM(val) |
			RT(Rt) |
			RA(Ra) |
			opcode6, true);
			goto xit;
	}
	if (opcode6 == I_ADDI && Rt==regSP && Ra==regSP && (val & 7LL) == 0 && IsNBit(val, 10)) {
		emit_insn(((val >> 3LL) << 13) | (Rt << 8) | I_ADDI20, 5);
		goto xit;
	}
	if (opcode6 == I_ANDI && Rt == regSP && Ra == regSP && (val & 7LL) == 0 && IsNBit(val, 10)) {
		emit_insn(((val >> 3LL) << 13LL) | (Rt << 8) | I_ANDI20, 5);
		goto xit;
	}
	if (opcode6 == I_ORI && Rt == regSP && Ra == regSP && (val & 7LL) == 0 && IsNBit(val, 10)) {
		emit_insn(((val >> 3LL) << 13LL) | (Rt << 8) | I_ORI20, 5);
		goto xit;
	}
	if (opcode6 == I_ADDI && IsNBit(val, 7) && Rt==Ra) {
		emit_insn((val << 13) | (Rt << 8) | I_ADDI20, 5);
		goto xit;
	}
	if (opcode6 == I_ANDI && IsNBit(val, 7) && Rt==Ra) {
		emit_insn((val << 13) | (Rt << 8) | I_ANDI20, 5);
		goto xit;
	}
	if (opcode6 == I_ORI && IsNBit(val, 7) && Rt==Ra) {
		emit_insn((val << 13) | (Rt << 8) | I_ORI20, 5);
		goto xit;
	}
	if (!IsNBit(val, 16LL))
		ext11(val);
	emit_insn(
		IMM(val) |
		RT(Rt) |
		RA(Ra) |
		opcode6);
xit:
	ScanToEOL();
}

// ---------------------------------------------------------------------------
// slti cr1,r2,#1234
//
// A value that is too large has to be loaded into a register then the
// instruction converted to a registered form.
// ---------------------------------------------------------------------------

static void process_setiop(int64_t opcode6, int64_t func6, int64_t bit23)
{
	int Ra;
	int Rt;
	char *p;
	int64_t val;
	bool li = false;
	int mop = 0;
	int sz = 0;

	p = inptr;
	if (inptr[0] == '.')
		getSz(&sz);
	p = inptr;
	Rt = getRegisterX();
	if (Rt >= 112 && Rt <= 115) {
		Rt &= 3;
	}
	need(',');
	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	val = expr();
	if (!IsNBit(val, 16LL))
		ext11(val);
	emit_insn(
		IMM(val) |
		RT(Rt) |
		RA(Ra) |
		opcode6
	);
	prevToken();
	ScanToEOL();
}

// ---------------------------------------------------------------------------
// slt $t0,$t1,$r16
// ---------------------------------------------------------------------------

static void process_setop(int64_t funct6, int64_t opcode6, int64_t bit23)
{
	int Ra, Rb, Rt;
	char *p, *q;
	int sz = 3;
	int64_t val;
	int mop = 0;

	p = inptr;
	if (*inptr == '.')
		getSz(&sz);
	sz &= 7;
	q = inptr;
	Rt = getRegisterX();
	if (Rt >= 112 && Rt <= 115) {
		Rt &= 3;
	}
	need(',');
	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	Rb = getRegisterX();
	if (Rb == -1) {
		inptr = p;
		process_setiop(opcode6, funct6, bit23);
		return;
	}
	if (funct6 < 0)
		emit_insn(
			FUNC6(-funct6) |
			RB(Ra) |
			RT(Rt) |
			RA(Rb) |
			I_SET
		);
	else
		emit_insn(
			FUNC6(funct6) |
			RB(Rb) |
			RT(Rt) |
			RA(Ra) |
			I_SET
		);
	prevToken();
	ScanToEOL();
}

static void process_fsetop(int64_t funct6)
{
	int Ra, Rb, Rt;
	char* p, * q;
	int sz = 3;
	int64_t val;
	int mop = 0;
	int rm = 0;
	int fmt;

	p = inptr;
	if (*inptr == '.')
		fmt = GetFPSize();
	sz &= 7;
	p = inptr;
	Rt = getRegisterX();
	if (Rt >= 112 && Rt <= 115) {
		Rt &= 3;
		need(',');
	}
	else {
		Rt = 1;
		inptr = p;
	}
	Ra = getFPRegister();
	need(',');
	any1_NextToken();
	q = inptr;
	Rb = getFPRegister();
	emit_insn(
		FUNC6(funct6) |
		RB(Rb) |
		RT(Rt) |
		RA(Ra) |
		I_FLT2
	);
	prevToken();
	ScanToEOL();
}

// ---------------------------------------------------------------------------
// add r1,r2,r3
// ---------------------------------------------------------------------------

static void process_rrop()
{
  int Ra,Rb,Rt,Rbp,Rtp;
  char *p;
	int sz = 0;
	int64_t instr;
	int64_t funct6 = parm1[token];
	int64_t iop = parm2[token];
	int64_t opcode = parm3[token];

	instr = 0LL;
  p = inptr;
	if (*p=='.')
		getSz(&sz);
  Rt = getRegisterX();
  need(',');
  Ra = getRegisterX();
	if (token == ',') {
		any1_NextToken();
		if (token == '#') {
			if (iop < 0 && iop != -I_ADDI)
				error("Immediate mode not supported");
			//printf("Insn:%d\n", token);
			inptr = p;
			if (iop == I_PERMI)
				process_permi(iop, funct6, opcode);
			else
				process_riop(iop, funct6, opcode);
			return;
		}
		prevToken();
		Rb = getRegisterX();
	}
	else {
		error("R2 operation needs two source operands");
		fprintf(ofp, "R2 operation needs two source operands\r");
		Rb = 0;
	}
	if (Rb >= 112 && Rb <= 115) {
		Rb &= 3;
		opcode = I_R2B;
	}
	if (funct6 == I_PTRDIF) {
		if (token == ',') {
			any1_NextToken();
			sz = expr() & 31;
		}
	}
	//prevToken();
	//if (funct6==0x2E || funct6==0x2C || funct6==0x2D) {
	//	funct6 += 0x10;	// change to divmod
	//    emit_insn((funct6<<26LL)||(1<<23)||(Rb<<18)|(Rt<<13)|(Ra<<8)|0x02,!expand_flag,4);
	//	goto xit;
	//}
	Ra = Ra & 0x1f;
	Rb = Rb & 0x1f;
	Rt = Rt & 0x1f;
	if (Ra == Rt && IsRn3(Ra) >= 0 && IsRn3(Rb) >= 0 && funct6 == I_SUB2) {
		emit_insn((IsRn3(Rb) << 13LL) | (IsRn3(Rt) << 8LL) | I_SUB20, 5);
		goto xit;
	}
	if (Ra == Rt && IsRn3(Ra) >= 0 && IsRn3(Rb) >= 0 && funct6 == I_OR2) {
		emit_insn((IsRn3(Rb) << 13LL) | (IsRn3(Rt) << 8LL) | I_OR20, 5);
		goto xit;
	}
	if (Ra == Rt && IsRn3(Ra) >= 0 && IsRn3(Rb) >= 0 && funct6 == I_XOR2) {
		emit_insn((IsRn3(Rb) << 13LL) | (IsRn3(Rt) << 8LL) | I_XOR20, 5);
		goto xit;
	}
	if (Ra == Rt && funct6 == I_ADD2) {
		emit_insn(((Rb) << 13LL) | ((Rt) << 8LL) | I_ADD20, 5);
		goto xit;
	}
	if (Ra == Rt && funct6 == I_AND2) {
		emit_insn(((Rb) << 13LL) | ((Rt) << 8LL) | I_AND20, 5);
		goto xit;
	}
	emit_insn(FUNC6(funct6) | RB(Rb) | RT(Rt) | RA(Ra) | I_R2);
	xit:
		prevToken();
		ScanToEOL();
}
       
static void process_cmp()
{
	int Cr;
	int Ra, Rb, Rt, Rbp, Rtp;
	char *p;
	int sz = 3;
	int64_t instr;
	int64_t funct6 = parm1[token];
	int64_t iop = parm2[token];
	int64_t bit23 = parm3[token];
	int mop = 0;
	int opcode = I_R2;

	instr = 0LL;
	p = inptr;
	// fxdiv, transform
	// - check for writeback indicator
	if (*inptr == '.')
		getSz(&sz);
	p = inptr;
	Rt = getRegisterX();
	need(',');
	p == inptr;
	Ra = getRegisterX();
	if (Ra < 0) {
		inptr = p;
		if (token == '#') {
			process_riop(iop, funct6, bit23);
			return;
		}
		error("CMP: a source register is required");
		return;
	}
	if (token == ',') {
		any1_NextToken();
		if (token == '#') {
			inptr = p;
			process_riop(iop, funct6, bit23);
			return;
		}
		prevToken();
		Rb = getRegisterX();
	}
	else {
		Rb = Ra;
		Ra = Rt;
		Rt = 0;
	}
	//prevToken();
	//if (funct6==0x2E || funct6==0x2C || funct6==0x2D) {
	//	funct6 += 0x10;	// change to divmod
	//    emit_insn((funct6<<26LL)||(1<<23)||(Rb<<18)|(Rt<<13)|(Ra<<8)|0x02,!expand_flag,4);
	//	goto xit;
	//}
	Ra = Ra & 0x1f;
	Rb = Rb & 0x1f;
	emit_insn(FUNC6(funct6) | RB(Rb) | RT(Rt) | RA(Ra) | I_R2);
xit:
	prevToken();
	ScanToEOL();
}

static void process_ptrdif()
{
	int Ra, Rb, Rt, Rbp, Rtp;
	char *p;
	int sz = 3;
	int sc = 0;
	int64_t instr;
	int64_t funct6 = parm1[token];
	int64_t iop = parm2[token];
	int64_t bit23 = parm3[token];
	int opcode = I_R3;

	instr = 0LL;
	p = inptr;
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	if (token == '#') {
		if (iop < 0 && iop != -4)
			error("Immediate mode not supported");
		//printf("Insn:%d\n", token);
		inptr = p;
		process_riop(iop,funct6,bit23);
		return;
	}
	prevToken();
	Rb = getRegisterX();
	if (Rb >= 112 && Rb <= 115) {
		Rb &= 3;
		opcode = I_R2B;
	}
	need(',');
	any1_NextToken();
	sc = expr();

	//prevToken();
	//if (funct6==0x2E || funct6==0x2C || funct6==0x2D) {
	//	funct6 += 0x10;	// change to divmod
	//    emit_insn((funct6<<26LL)||(1<<23)||(Rb<<18)|(Rt<<13)|(Ra<<8)|0x02,!expand_flag,4);
	//	goto xit;
	//}
	emit_insn((3)<<29LL|RB(0)|RA(sc)|I_IMOD);
	emit_insn(instr | FUNC6(funct6) | RB(Rb) | RT(Rt) | RA(Ra) | opcode);
xit:
	prevToken();
	ScanToEOL();
}

// ---------------------------------------------------------------------------
// or r1,r2,r3,r4
// ---------------------------------------------------------------------------

static void process_rrrop(int64_t funct6)
{
	int Ra, Rb, Rc = 0, Rt;
	char *p;
	int sz = 3;
	int opcode = I_R3;

	p = inptr;
	if (*p == '.')
		getSz(&sz);
	if (*inptr == '.')
		recflag = TRUE;
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	if (token == '#') {
		inptr = p;
		process_riop(funct6,0,0);
		return;
	}
	prevToken();
	Rb = getRegisterX();
	if (token == ',') {
		any1_NextToken();
		Rc = getRegisterX();
	}
	else {
		switch (funct6) {
		case I_AND3:	Rc = Rb; break;	// and
		case I_OR3:	Rc = 0; break;	// or
		case I_EOR3:	Rc = 0; break;	// xor
		}
	}
	emit_insn(RA(Rc)|I_IMOD);
	emit_insn(FUNC6(funct6) | RT(Rt) | RB(Rb) | RA(Ra) | opcode);
}

static void process_cmove(int64_t funct6)
{
	int Ra, Rb, Rc = 0, Rt;
	char *p;
	int sz = 3;
	int64_t val;

	p = inptr;
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	need(',');
	Rb = getRegisterX();
	need(',');
	any1_NextToken();
	if (token == '#') {
		error("Illegal cmove address mode - register only.");
		val = expr();
		if (!IsNBit(val, 16)) {
			LoadConstant(val, 23);
			emit_insn(
				(funct6 << 42LL) |
				(0LL << 39LL) |
				RB(Rb) |
				RT(Rt) |
				RA(Ra) |
				(1 << 6) |
				0x02);
			return;
		}
		emit_insn(
			(funct6 << 42LL) |
			(4LL << 39LL) |
			((val & 0xffffLL) << 23LL) |
			RB(Rb) |
			RT(Rt) |
			RA(Ra) |
			(1 << 6) |
			0x02);
		return;
	}
	prevToken();
	Rc = getRegisterX();
	prevToken();
	ScanToEOL();
}

static void process_cmovf(int64_t funct6)
{
	int Ra, Rb, Rc = 0, Rt;
	char *p;
	int sz = 3;

	p = inptr;
	Rt = getFPRegister();
	need(',');
	Ra = getRegisterX();
	need(',');
	Rb = getFPRegister();
	need(',');
	any1_NextToken();
	Rc = getFPRegister();
}

// ---------------------------------------------------------------------------
// jmp main
// jal [r19]
// ---------------------------------------------------------------------------

static void process_jal(int64_t oc, int opt)
{
	int64_t addr, val;
	int Ra;
	int Rt;
	bool noRt;
	char *p;
	bool rel = false;

	noRt = false;
	Ra = 0;
	Rt = 0;
	p = inptr;
	if (*inptr == '*') {
		inptr++;
		rel = true;
	}
  any1_NextToken();
	if (token == '(' || token == '[') {
	j1:
		Ra = getRegisterX();
		if (Ra == -1) {
			printf("Expecting a register\r\n");
			goto xit;
		}
		// Simple jmp [Rn]
		if (token != ')' && token != ']')
			printf("Missing close bracket %d\n", lineno);
		emit_insn(RA(Ra) | RD(Rt) | I_JAL);
		goto xit;
	}
	else
		inptr = p;
    Rt = getRegisterX();
    if (Rt >= 0) {
        need(',');
        any1_NextToken();
        // jal Rt,[Ra]
        if (token=='(' || token=='[')
           goto j1;
    }
    else {
      Rt = 0;
			noRt = true;
		}
		if (noRt && opt)
			Rt = 1;
		addr = expr();
    // d(Rn)? 
    //any1_NextToken();
    if (token=='(' || token=='[') {
        Ra = getRegisterX();
        if (Ra==-1) {
            printf("Illegal jump address mode.\r\n");
            Ra = 0;
        }
		if (Ra==regPC)	// program counter relative ?
			addr -= code_address;
	}
	val = addr;
	if (Ra == 0) {
		if (IsNBit(val, 26)) {
			emit_insn(((val) << 10LL) | RT(Rt) |	I_JAL);
			goto xit;
		}
		if (IsNBit(val, 39)) {
			emit_insn(((val >> 11LL) << 8LL) | I_EXI0);
			emit_insn(((val) << 10LL) | RT(Rt) | I_JAL);
			goto xit;
		}
		if (IsNBit(val, 67)) {
			emit_insn(((val >> 11LL) << 8LL) | I_EXI0);
			emit_insn(((val >> 39LL) << 8LL) | I_EXI1);
			emit_insn(((val) << 10LL) | RT(Rt) | I_JAL);
			goto xit;
		}
	}
	if (IsNBit(val, 16)) {
		emit_insn(((val) << 20LL) | RA(Ra) | RT(Rt) | I_JAL);
		goto xit;
	}
	if (IsNBit(val, 39)) {
		emit_insn(((val >> 11LL) << 8LL) | I_EXI0);
		emit_insn(((val) << 20LL) | RA(Ra) | RT(Rt) | I_JAL);
		goto xit;
	}
	if (IsNBit(val, 67)) {
		emit_insn(((val >> 11LL) << 8LL) | I_EXI0);
		emit_insn(((val >> 39LL) << 8LL) | I_EXI1);
		emit_insn(((val) << 20LL) | RA(Ra) | RT(Rt) | I_JAL);
		goto xit;
	}
xit:
	ScanToEOL();
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
    any1_NextToken();
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
// fabs.d r1,r2[,rm]
// ---------------------------------------------------------------------------

static void process_fprop(int64_t oc)
{
    int Ra;
    int Rt;
    char *p;
    int fmt;
    int64_t rm;

    rm = 0;
    fmt = GetFPSize();
    p = inptr;
    Rt = getFPRegister();
    need(',');
    Ra = getFPRegister();
    if (token==',')
       rm = getFPRoundMode();
//    prevToken();
	if (fmt != 2) {
		emit_insn(
			(oc << 42LL) |
			((int64_t)fmt << 31LL) |
			(rm << 28) |
			RT(Rt) |
			RB(0) |
			RA(Ra) |
			0x0F
		);
		return;
	}
  emit_insn(
		(oc << 26LL) |
		(rm << 23) |
		RT(Rt)|
		RB(0)|
		RA(Ra) |
		0x0F
	);
}

// ---------------------------------------------------------------------------
// itof.d $fp1,$r2[,rm]
// ---------------------------------------------------------------------------

static void process_itof(int64_t oc)
{
  int Ra;
  int Rt;
  char *p;
  int fmt;
  int64_t rm;

  rm = 0;
  fmt = GetFPSize();
  p = inptr;
  Rt = getFPRegister();
  need(',');
  Ra = getRegisterX();
  if (token==',')
    rm = getFPRoundMode();
//    prevToken();
	if (fmt != 2) {
		emit_insn(
			(oc << 42LL) |
			(fmt << 31LL) |
			(rm << 28LL) |
			RT(Rt) |
			RB(0) |
			RA(Ra) |
			I_FLT2
		);
		return;
	}
  emit_insn(
		(oc << 26LL) |
		(rm << 23LL)|
		RT(Rt)|
		RB(0)|
		RA(Ra) |
		I_FLT2
		);
}

static void process_ftoi(int64_t oc)
{
	int Ra;
	int Rt;
	char *p;
	int fmt;
	int64_t rm;

	rm = 0;
	fmt = GetFPSize();
	p = inptr;
	Rt = getRegisterX();
	need(',');
	Ra = getFPRegister();
	if (token == ',')
		rm = getFPRoundMode();
	//    prevToken();
	if (fmt != 2) {
		emit_insn(
			(oc << 42LL) |
			(fmt << 31LL) |
			(rm << 28LL) |
			RT(Rt) |
			RB(0) |
			RA(Ra) |
			I_FLT2
		);
		return;
	}
	emit_insn(
		(oc << 26LL) |
		(rm << 23LL) |
		RT(Rt) |
		RB(0) |
		RA(Ra) |
		I_FLT2
	);
}

// ---------------------------------------------------------------------------
// fadd.d r1,r2,r12[,rm]
// fcmp.d r1,r3,r10[,rm]
// ---------------------------------------------------------------------------

static void process_fprrop(int64_t oc)
{
    int Ra;
    int Rb;
    int Rt;
    char *p;
    int fmt;
    int64_t rm;

    rm = 0;
    fmt = GetFPSize();
    p = inptr;
		if (*inptr == '.') {
			inptr++;
			recflag = true;
		}
    if (oc==I_FCMP)        // fcmp
        Rt = getRegisterX();
    else
        Rt = getFPRegister();
    need(',');
    Ra = getFPRegister();
    need(',');
    Rb = getFPRegister();
    if (token==',')
       rm = getFPRoundMode();
//    prevToken();
  emit_insn(
		FUNC6(oc)|
		RT(Rt)|
		RB(Rb)|
		RA(Ra) |
		I_FLT2
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
       any1_NextToken();
       bits = expr();
    }
    prevToken();
	emit_insn(
		((bits & 0x3F) << 18) |
		(oc << 12) |	// ToDo Fix this
		RA(Ra) |
		I_FLT2
		);
}

// ---------------------------------------------------------------------------
// not r3,r3
// ---------------------------------------------------------------------------

static void process_rop(int oc)
{
  int Ra;
  int Rt;
	int sz = 3;
	char *p;
	int mop = 0;

	p = inptr;
	if (*inptr == '.')
		getSz(&sz);
	if (*inptr == '.') {
		inptr++;
		recflag = TRUE;
	}
	Rt = getRegisterX();
	if (token == ',') {
		Ra = getRegisterX();
	}
	else {
		Ra = Rt;
		if (oc == I_TST) {
			Rt = 0;
		}
		else {
			any1_NextToken();
			error("Target register is required for R1 op");
			Rt = 0;
		}
	}
	emit_insn(
		FUNC6(oc) |
		RT(Rt) |
		RA(Ra) |
		I_R1
		);
	prevToken();
}

// ---------------------------------------------------------------------------
// popq r3,r3
// ---------------------------------------------------------------------------

static void process_popq(int oc)
{
	int Ra;
	int Rt;
	int sz = 0;
	char *p;

	p = inptr;
	if (*p == '.')
		getSz(&sz);
	Rt = getRegisterX();
	if (token == ',') {
		Ra = getRegisterX();
	}
	else {
		Ra = Rt;
		if (oc == I_TST) {
			Rt = 0;
		}
		else {
			any1_NextToken();
			error("Target register is required for R1 op");
			Rt = 0;
		}
	}
	emit_insn(
		FUNC6(oc) |
		RT(Rt) |
		RA(Ra) |
		I_OSR2
	);
	prevToken();
}

static void process_ptrop(int oc, int func)
{
	int Ra;
	int Rt;
	char *p;

	p = inptr;
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	emit_insn(
		(1LL << 26LL) |
		(func << 23) |
		(oc << 18) |
		RT(Rt) |
		RA(Ra) |
		0x02
	);
	prevToken();
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
static int InvertBranchOpcode(int opcode4)
{
	switch (opcode4) {
	case 0:	return (1);	// BEQ to BNE
	case 1:	return (0);	// BNE to BEQ
	default:	return (opcode4);	// Otherwise operands are swapped.
	}
}

static void findComma()
{
	char* q = inptr;

	while (*inptr != ',' && *inptr != '\r' && *inptr!='\n') inptr--;
	if (*inptr == ',')
		any1_NextToken();	// Get the comma
	else
		inptr = q;
}

// ---------------------------------------------------------------------------
//  beq		cr1,label
//	bne		label2	; assumes cr0
// ---------------------------------------------------------------------------

static void process_bcc()
{
	int Cr = 0;
	int Ra, Rb, Rc;
	int64_t val;
	int64_t disp;
	int encode;
	int ins48 = 0;
	int64_t opcode6 = parm1[token];
	int64_t opcode4 = parm2[token];
	int64_t op4 = parm3[token];
	char *p = inptr;
	char* q, *r;

	Ra = getRegisterX();
	need(',');
	Rb = getRegisterX();
	findComma();
	need(',');
	any1_NextToken();
	q = inptr;
	val = expr();
	disp = val - code_address;
	//disp /= 9;
	// Swap operands?
	if (opcode6 < 0) {
		opcode6 = -opcode6;
		Rc = Ra;
		Ra = Rb;
		Rb = Rc;
	}
	if (Ra & 0x40)
		error("Register value required");
	if ((Rb == 0 || (Rb & 0x7f) == 0x40) && IsNBit(disp, 7)) {
		if (opcode6 == I_BEQ) {
			emit_insn((disp << 13LL) | (Ra << 8) | I_BEQZ20, 5);
			goto xit;
		}
		else if (opcode6 == I_BNE) {
			emit_insn((disp << 13LL) | (Ra << 8) | I_BNEZ20, 5);
			goto xit;
		}
	}
	if (!IsNBit(disp,16))
		emit_insn((((disp) >> 20LL) << 21LL) | RA(31) | (((disp >> 16LL) & 15LL) << 10LL) | RT(0) | I_BRMOD);
	emit_insn((((disp) >> 7LL) << 27LL) | RB(Rb) | TA(disp >> 6) | RA(Ra) | RT(disp) | opcode6);
xit:
	prevToken();
	return;
}

// ---------------------------------------------------------------------------
//
// ---------------------------------------------------------------------------

static void process_bbc(int opcode6, int opcode3)
{
	int Ra, Rc, pred;
	int64_t bitno;
	int64_t val;
	int64_t disp;
	char* p1;
	int sz = 3;
	char* p;
	bool isn48 = false;

	p = inptr;
	if (*p == '.')
		getSz(&sz);

	pred = 3;		// default: statically predict as always taken
	p1 = inptr;
	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	if (token == '#')
		bitno = expr() | 0x40;
	else {
		prevToken();
		bitno = getRegisterX();
	}
	need(',');
	p = inptr;
	Rc = getRegisterX();
	if (Rc == -1) {
		inptr = p;
		any1_NextToken();
		val = expr();
		disp = (val - code_address);
		//disp /= 9;
		if (!IsNBit(disp, 16))
			emit_insn((((disp) >> 20LL) << 21LL) | RA(31) | (((disp >> 16LL) & 15LL) << 10LL) | RT(0) | I_BRMOD);
		emit_insn((((disp) >> 7LL) << 27LL) | RB(bitno) | TA(disp>>6) | RA(Ra) | RT(disp) | opcode6);
		return;
	}
	error("ibne: target must be a label");
}

// ---------------------------------------------------------------------------
// beqi r2,#123,label
// ---------------------------------------------------------------------------

static void process_beqi(int64_t opcode6, int64_t opcode3)
{
	int Ra, pred = 0;
	int64_t val, imm;
	int64_t disp, mask;
	int sz = 3;
	int ins48 = 0;
	char* p;

	p = inptr;
	if (*p == '.')
		getSz(&sz);

	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	imm = expr();
	need(',');
	any1_NextToken();
	val = expr();
	if (!IsNBit(imm, 8LL)) {
		//printf("Branch immediate too large: %d %I64d", lineno, imm);
		LoadConstant(imm, 2LL);
		disp = (val - code_address) >> 2LL;
		if (!IsNBit(disp, 11LL)) {
			ins48 = !gpu;
			if (!IsNBit(disp, 27LL) || gpu) {
				if (pass > 4)
					error("BEQI Branch target too far away");
			}
			return;
		}
		emit_insn(
			((disp & 0x3fffLL) << 10LL) |
			RD(0) |
			I_BEQ, false
		);
		return;
	}
	mask = 0xFFFFFFFFFFFFFFFFLL;
	mask = mask >> (64LL - (int64_t)code_bits);
	disp = ((val & mask) - (code_address & mask));
	//disp /= 9;
	if (!IsNBit(disp, 11LL)) {
		ins48 = !gpu;
		if (!IsNBit(disp, 27LL) || gpu) {
			if (pass > 4)
				error("BEQI Branch target too far away");
		}
		return;
	}
	emit_insn(
		(disp << 21LL) |
		((imm & 0xffLL) << 13LL) |
		RD(Ra) |
		opcode6
	);
	return;
}


// ---------------------------------------------------------------------------
// bfextu r1,r2,#1,#63
// ---------------------------------------------------------------------------

static void process_bitfield(int64_t oc, int64_t fn)
{
	int Ra, Rb, Rc;
	int Rt;
	int64_t mb;
	int64_t me;
	int64_t val;
	int64_t op;
	int sz = 3;
	char *p;
	bool gmb, gme, gval;

	gmb = gme = gval = false;
	p = inptr;
	if (*p == '.')
		getSz(&sz);
	Rt = getRegisterX();
	need(',');
	p = inptr;
	Ra = getRegisterX();
	need(',');
	p = inptr;
	Rb = getRegisterX();
	if (Rb == -1) {
		inptr = p;
		any1_NextToken();
		mb = expr();
		gmb = true;
	}
	need(',');
	p = inptr;
	Rc = getRegisterX();
	if (Rc == -1) {
		inptr = p;
		any1_NextToken();
		me = expr();
		gme = true;
	}
	if (!gme) {
		switch (oc) {
		case I_DEP:
			if (fn)
				fn = I_FLIP;
			else
				fn = I_DEP3;
			break;
		case I_EXT:
			if (fn)
				fn = I_EXTU3;
			else
				fn = I_EXT3;
			break;
		}
	}
	if (gme != gmb)
		error("Bitfield spec must be both register or both constant");
	emit_insn(op);
//	ScanToEOL();
	prevToken();
}


// ---------------------------------------------------------------------------
// bra label
// ---------------------------------------------------------------------------

static void process_bra(int oc, int cond)
{
  int Ra = 0, Rb = 0;
  int64_t val;
	int64_t disp;
	int ins48 = 0;

  any1_NextToken();
  val = expr();
	disp = val - code_address;
	if (IsNBit(disp, 13LL))
		emit_insn((disp << 10LL) | I_BAL20,5);
	else
		emit_insn(((disp) << 10LL) | I_BAL);
}

// ----------------------------------------------------------------------------
// chk r1,r2,r3,label
// ----------------------------------------------------------------------------

static void process_chki(int opcode6)
{
	int Ra;
	int Rb;
	int64_t val, disp; 
	bool recflag = false;

	if (*inptr == '.') {
		recflag = true;
		inptr++;
	}
	Ra = getRegisterX();
	need(',');
	Rb = getRegisterX();
	need(',');
	any1_NextToken();
	val = expr();
	// ToDO: Fix
	if (!IsNBit(val, 13)) {
		LoadConstant(val, 2);
		emit_insn(
			FUNC6(I_CHK2B) |
			RB(2) |
			RA(Rb) |
			RT(Ra) |
			I_R3
		);
		return;
	}
	emit_insn(
		IMM(val) |
		RA(Rb) |
		RT(Ra) |
		opcode6);
}


static void process_chk(int opcode6)
{
	int Ra;
	int Rb;
	int Rc;
	int64_t val, disp;
	char* p;
	bool recflag = false;

	p = inptr;
	if (*inptr == '.') {
		recflag = true;
		inptr++;
	}
	Ra = getRegisterX();
	need(',');
	Rb = getRegisterX();
	need(',');
	if (token == '#') {
		inptr = p;
		process_chki(I_CHKI);
		return;
	}
	Rc = getRegisterX();
	// ToDo: Fix
	emit_insn(
		FUNC6(I_CHK2B) |
		RB(Rc) |
		RA(Rb) |
		RT(Ra) |
		I_R3
	);
}


// ---------------------------------------------------------------------------
// Same as bcc except assumes cr1
// fbeq label
// ---------------------------------------------------------------------------

static void process_fbcc()
{
	int Cr = 0;
	int Ra, Rb, Rc;
	int64_t val;
	int64_t disp;
	int encode;
	int ins48 = 0;
	int64_t opcode6 = parm1[token];
	int64_t opcode4 = parm2[token];
	int64_t op4 = parm3[token];
	char* p = inptr;

	Cr = getRegisterX();
	if (Cr < 0) { // no register
		Cr = 113;
	}
	else if (Cr < 112 || Cr > 115)
		error("Need condition register for branch");
	else {
		need(',');
	}
	any1_NextToken();
	val = expr();
	emit_insn(
		((val >> 2LL) << 10LL) |
		((Cr & 3LL) << 8LL) |
		opcode6
	);
	return;
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_call(int opcode, int opt)
{
	int64_t val, disp, def;
	int Ra = 0;
	int lk = 0;
	char* p;
	bool rel = true;

	SkipSpaces();\
	p = inptr;
	if (inptr[0] == '!') {
		inptr++;
		rel = false;
	}
	if (opcode == I_BAL)
		rel = true;
	if (opcode == I_JAL)
		rel = false;
	if (opcode == I_JAL || opcode == I_BAL) {
		lk = getRegisterX();
		if (lk < 0) {
			lk = opt ? 1 : 0;
		}
		else if (lk < 0 || lk > 3) {
			error("Link register x0 to x3 must be specified.");
			lk = 1;
		}

		any1_NextToken();
		if (token == tk_comma)
			any1_NextToken();
		prevToken();
	}
	any1_NextToken();
	val = expr_def(&def);
	if (token=='[') {
		Ra = getRegisterX();
		need(']');
		any1_NextToken();
	}
	if (val==0) {
			// JMP [Ra]
			// jrl r0,[Ra]
			emit_insn(
				RA(Ra) |
				RT(lk) |
				I_JALR
			);
		return;
	}
	disp = (val - code_address);
	if (Ra == 0 && !rel) {
		if (code_bits < 25) {
			emit_insn(((val) << 10LL) | ((lk) << 8LL) | opcode);
			return;
		}
		if (!IsNBit(val, 26)) {
			ext11(val);
		}
		emit_insn(((val) << 10LL) | ((lk) << 8LL) | opcode);
		return;
	}
	if (Ra == 0 && rel) {
		val = disp;
		if (IsNBit(disp, 13LL)) {
			emit_insn((val << 10LL) | ((lk) << 8LL) | I_BAL, 5);
			return;
		}
		if (code_bits < 25) {
			emit_insn(((val) << 10LL) | ((lk) << 8LL) | opcode);
			return;
		}
		if (!IsNBit(val, 26))
			ext11(val);
		emit_insn(((val) << 10LL) | ((lk) << 8LL) | opcode);
		return;
	}
}

static void process_iret(int64_t op)
{
	int64_t ro, sema;
	int64_t val = 0;
	int Ra;
	char* p;

	p = inptr;
	sema = 0;
	ro = expr();
	if (token == ',') {
		any1_NextToken();
		sema = expr();
	}
	emit_insn(
		((sema & 0x3FLL) << 18LL) |
		RT(ro) |
		op
	);
}

static void process_ret(int64_t opcode)
{
	int64_t val = 0;
	int64_t ro = 4;
	int64_t stkadj = 0;
	bool ins48 = false;
	bool li = false;
	int lk = 0;
	char* p;

	p = inptr;
/*
	lk = getRegisterX();
	if (lk < 0) {
		lk = 1;
		inptr = p;
	}
	else if (lk >= 96 && lk <= 97)
		lk -= 96;
	else
		lk = 0;
*/
	/*
  any1_NextToken();
	if (token == '#') {
		stkadj = expr();
	}
	else
		stkadj = 8;
	*/
	/*
	else {
		ro = expr();
		if ((ro > 60LL) || (ro < 0LL) || (ro & 3LL))
			error ("RTS return offset must be >= 0 and <= 60 and a multiple of four");
		if (token == '[') {
			lk = getRegisterX();
			if (lk < 96 || lk > 97)
				error("RTS must specify return address register (ra0 or ra1)");
			lk -= 96;
			need(']');
		}
		if (token == ',') {
			any1_NextToken();
			stkadj = expr();
		}
	}
	*/
	emit_insn((1 << 13) | I_JALR20,5);
//	emit_insn(IMM(stkadj) | RA(30) | RT(30) | I_RET);
}

// ---------------------------------------------------------------------------
// brk #240
// ---------------------------------------------------------------------------

static void process_brk()
{
	int64_t val;
	int inc = 1;
	int user = 0;
	int Ra = -1;

	any1_NextToken();
	val = expr();
	emit_insn((val & 0xffLL) << 14LL);
	return;
	Ra = getRegisterX();
	if (Ra == -1) {
		any1_NextToken();
		val = expr();
		//any1_NextToken();
		if (token == ',') {
			any1_NextToken();
			inc = (int)expr();
			if (token == ',') {
				any1_NextToken();
				user = (int)expr();
			}
			else
				prevToken();
		}
		else
			prevToken();
		emit_insn(
			(user << 26) |
			((inc & 31) << 21) |
			((val & 0xFFLL) << 8) |
			0x00
		);
		return;
	}
	any1_NextToken();
	if (token == ',') {
		inc = (int)expr();
		any1_NextToken();
		if (token == ',')
			user = (int)expr;
		else
			prevToken();
	}
	else
		prevToken();
	// ToDo: Fix this
	emit_insn(
		(user << 26) |
		((inc & 31) << 21) |
		(1 << 16) |
		RA(Ra & 0x1f) |
		0x00
	);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_push()
{
	int Ra, Rb;
	int64_t val;
	bool li = false;

	SkipSpaces();
	if (*inptr == '#') {
		inptr++;
		any1_NextToken();
		val = expr();
		if (IsNBit(val, 24)) {
			emit_insn(
				(val << 8LL) |
				I_PUSHC
			);
			goto xit;
		}
		else {
			LoadConstant(val, 2);
			emit_insn(
				RD(2) |
				I_PUSH
			);
			goto xit;
		}
	}
	Ra = getRegisterX();
	emit_insn(
		RD(Ra) |
		I_PUSH
	);
xit:
	prevToken();
	ScanToEOL();
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void process_link(int64_t oc)
{
	int64_t amt;

	any1_NextToken();
	amt = expr();
	emit_insn(
		(amt << 8LL)|
		oc,true);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

static void GetIndexScale(int *sc)
{
	int64_t val;

	any1_NextToken();
	val = expr();
	prevToken();
	switch(val) {
	case 0: *sc = 0; break;
	case 1: *sc = 0; break;
	case 2: *sc = 1; break;
	case 4: *sc = 2; break;
	case 8: *sc = 3; break;
	case 16: *sc = 4; break;
	case 32: *sc = 5; break;
	case 64: *sc = 6; break;
	default: printf("Illegal scaling factor.\r\n");
	}
}


// ---------------------------------------------------------------------------
// expr
// expr[Reg]
// [Reg]
// [Reg+Reg]
// ---------------------------------------------------------------------------

static void mem_operand(int64_t *disp, int *regA, int *regB, int *Sc, int *seg)
{
  int64_t val;

  // chech params
  if (disp == (int64_t *)NULL)
      return;
  if (regA == (int *)NULL)
      return;
	 if (regB == (int *)NULL)
		 return;
	 if (Sc == (int *)NULL)
		 return;
	 if (seg == (int *)NULL)
		 return;

     *disp = 0;
     *regA = -1;
	 *regB = -1;
	 *Sc = 0;
	 *seg = -1;
j1:
     if (token!='[') {
			 if (inptr[2] == ':') {
				 if (inptr[1] == 's' || inptr[1] == 'S') {
					 switch (inptr[0]) {
					 case 'C':
					 case 'c':
						 *seg = 0; inptr += 3; any1_NextToken(); goto j1;
					 case 'D':
					 case 'd':
						 *seg = 1;
						 inptr += 3;
						 any1_NextToken();
						 goto j1;
					 case 'E':
					 case 'e':
						 *seg = 2;
						 inptr += 3;
						 any1_NextToken();
						 goto j1;
					 case 'S':
					 case 's':
						 *seg = 3;
						 inptr += 3;
						 any1_NextToken();
						 goto j1;
					 case 'F':
					 case 'f':
						 *seg = 4;
						 inptr += 3;
						 any1_NextToken();
						 goto j1;
					 case 'G':
					 case 'g':
						 *seg = 5;
						 inptr += 3;
						 any1_NextToken();
						 goto j1;
					 }
				 }
			 }
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
// If the displacement is too large the displacment is loaded into r2.
//
// So
//    sw    t2,$12345678[t2]
// Becomes:
//		lmi		r2,#$12345
//    add   x1,t2,r2
//    sw    $678[x1]
//
// sw disp[r1],r2
// sw [r1+r2],r3
// ----------------------------------------------------------------------------

static void process_store()
{
	int Ra, Rb, Rc;
	int Rs;
	int Sc;
	int seg;
	int64_t disp, val;
	int64_t aq = 0, rl = 0;
	int64_t rglist;
	int lsm;
	int ar;
	int64_t opcode6 = parm1[token];
	int64_t funct6 = parm2[token];
	int64_t sz = parm3[token];
	bool li = false;

	lsm = opcode6 == I_STM;
	GetFPSize();
	GetArBits(&aq, &rl);
	ar = (int)((aq << 1LL) | rl);
	Rs = 0;
	if (!lsm) {
		Rs = getRegisterX();
		if (Rs < 0) {
			printf("Expecting a source register (%d).\r\n", lineno);
			printf("Line:%.60s\r\n", inptr);
			ScanToEOL();
			return;
		}
		expect(',');
	}
	else
		any1_NextToken();
	mem_operand(&disp, &Ra, &Rc, &Sc, &seg);
	if (Ra >= 0 && Rc >= 0) {
		emit_insn(RA(Rc) | I_IMOD);
		emit_insn(
			FUNC4(opcode6) |
			((Sc & 7LL) << 29LL) |
			RT(0) |
			RA(Ra) |
			RB(Rs) |
			I_STxX);
		ScanToEOL();
		return;
	}
	if (lsm) {
		opcode6 = 13;
		any1_NextToken();
		expect(',');
//		any1_NextToken();
		rglist = expr();
	}

	if (Ra <= 0)
		Ra = 0x40;
	val = disp;
	if (Ra == 55)
		val -= program_address;
	if (Ra == regGP) {
		if (segment == rodataseg)
			val -= rodata_base_address;
		else if (segment == bssseg)
			val -= bss_base_address;
		else
			val -= data_base_address;
	}
	if (lsm) {
		emit_insn(((rglist >> 2LL) << 8LL) | (rglist & 3LL) | 0x5C);
	}
	if (IsNBit(val, 10) && (val & 7LL) == 0 && Ra == regSP) {
		emit_insn(((val >> 3LL) << 13LL) | (Ra << 8) | I_STOSP20,5);
		goto xit;
	}
	if (IsNBit(val, 11))
		emit_insn(FUNC4(opcode6) | (((val >> 6LL) & 31LL) << 27LL) | RB(Rs) | RA(Ra) | RT(val) | I_STx);
	else if (IsNBit(val, 39)) {
		emit_insn((((val) >> 11LL) << 8LL) | I_EXI0);
		emit_insn(FUNC4(opcode6) | (((val >> 6LL) & 31LL) << 27LL) | RB(Rs) | RA(Ra) | RT(val) | I_STx);
	}
	else if (IsNBit(val, 67)) {
		emit_insn((((val) >> 11LL) << 8LL) | I_EXI0);
		emit_insn((((val) >> 39LL) << 8LL) | I_EXI1);
		emit_insn(FUNC4(opcode6) | (((val >> 6LL) & 31LL) << 27LL) | RB(Rs) | RA(Ra) | RT(val) | I_STx);
	}
xit:
	ScanToEOL();
}
/*
static void process_storepair(int64_t opcode6)
{
	int Ra, Rb;
	int Rs, Rs2;
	int Sc;
	int64_t disp, val;
	int64_t aq = 0, rl = 0;
	int ar;

	GetArBits(&aq, &rl);
	ar = (int)((aq << 1LL) | rl);
	Rs = getRegisterX();
	if (Rs < 0) {
		printf("Expecting a source register (%d).\r\n", lineno);
		printf("Line:%.60s\r\n", inptr);
		ScanToEOL();
		return;
	}
	expect(',');
	Rs2 = getRegisterX();
	expect(',');
	mem_operand(&disp, &Ra, &Rb, &Sc);
	if (Ra > 0 && Rb > 0) {
		emit_insn(
			(opcode6 << 34LL) |
			(ar << 26) |
			(Sc << 24) |
			(Rs << 18) |
			(Rb << 12) |
			(Ra << 6) |
			0x02, !expand_flag, 5);
		return;
	}
	if (Ra < 0) Ra = 0;
	val = disp;
	if (Ra == 55)
		val -= program_address;
	if (!IsNBit(val, 14)) {
		LoadConstant(val, 52);
		// Change to indexed addressing
		emit_insn(
			(opcode6 << 34LL) |
			(ar << 26) |
			(0 << 24) |		// Sc
			(Rs << 18) |
			(52 << 12) |
			(Ra << 6) |
			0x02, !expand_flag, 5);
		ScanToEOL();
		return;
	}
	emit_insn(
		(val << 26LL) |
		(ar << 24) |
		(Rs2 << 18) |
		(Rs << 12) |
		(Ra << 6) |
		opcode6, !expand_flag, 5, true);
	ScanToEOL();
}
*/
static void process_sv(int64_t opcode6)
{
    int Ra,Vb;
    int Vs;
    int64_t disp,val;
	int64_t aq = 0, rl = 0;
	int ar = 0;

	GetArBits(&aq, &rl);
	ar = (int)((aq << 1LL) | rl);
	Vs = getVecRegister();
    if (Vs < 0 || Vs > 63) {
        printf("Expecting a vector source register (%d).\r\n", lineno);
        printf("Line:%.60s\r\n",inptr);
        ScanToEOL();
        return;
    }
    expect(',');
    mem_voperand(&disp, &Ra, &Vb);
	if (Ra > 0 && Vb > 0) {
		emit_insn(
			(opcode6 << 34LL) |
			(ar << 26) |
			(Vs << 18) |
			(Vb << 12) |
			(Ra << 6) |
			0x02);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	//if (val < -32768 || val > 32767)
	//	printf("SV displacement too large: %d\r\n", lineno);
	if (!IsNBit(val, 20)) {
		LoadConstant(val, 52);
		// ToDo: store with indexed addressing
		return;
	}
	emit_insn(
		(val << 20) |
		(ar << 18) |
		(Vs << 12) |
		(Ra << 6) |
		opcode6);
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_ldi()
{
  int Ra = 0;
  int Rt;
  int64_t val;
	char *p;
	int sz = 3;
	bool li = false;

  p = inptr;
	if (*p=='.')
		getSz(&sz);
	sz &= 3;
  Rt = getRegisterX();
  expect(',');
	any1_NextToken();
  val = expr();
	LoadConstant(val, Rt);
	return;
}

// ----------------------------------------------------------------------------
// link #-40
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// lw r1,disp[r2]
// lw r1,[r2+r3]
// ----------------------------------------------------------------------------

static void process_load()
{
  int Ra,Rb,Rc;
  int Rt;
	int Sc;
	int seg;
  char *p;
	int64_t rglist;
	int lsm;
  int64_t disp;
  int64_t val;
	int64_t aq = 0, rl = 0;
	int ar;
  int fixup = 5;
	int64_t opcode6 = parm1[token];
	int64_t funct6 = parm2[token];
	int64_t sz = parm3[token];
	bool li = false;

	Rt = 0;
	lsm = opcode6 == I_LDM;
	GetFPSize();
	GetArBits(&aq, &rl);
	ar = (int)((aq << 1LL) | rl);
	p = inptr;
	if (!lsm) {
		Rt = getRegisterX();
		if (Rt < 0) {
			printf("Expecting a target register (%d).\r\n", lineno);
			printf("Line:%.60s\r\n", p);
			ScanToEOL();
			inptr -= 2;
			return;
		}
		expect(',');
	}
	else
		any1_NextToken();
  mem_operand(&disp, &Ra, &Rb, &Sc, &seg);
	if (lsm) {
		opcode6 = 13;
		any1_NextToken();
		expect(',');
//		any1_NextToken();
		rglist = expr();
	}
	if (Ra <= 0) Ra = 0x40;
    val = disp;

	if (Ra == regGP) {
		if (segment == rodataseg)
			val -= rodata_base_address;
		else if (segment == bssseg)
			val -= bss_base_address;
		else
			val -= data_base_address;
	}

	if (lsm) {
		emit_insn(((rglist >> 2LL) << 8LL) | (rglist & 3LL) | 0x5C);
	}

	// Check for indexed mode
	if (Ra >= 0 && Rb >= 0) {
		emit_insn(FUNC4(opcode6) | ((Sc & 7LL) << 29LL) | RB(Rb)|RA(Ra)|RT(Rt)|(opcode6&0x80?I_LDxXZ:I_LDxX));
		ScanToEOL();
		return;
	}

	if (IsNBit(val, 10) && (val & 7LL) == 0 && Ra == regSP) {
		emit_insn(((val >> 3LL) << 13LL) | (Ra << 8) | I_LDOSP20,5);
		return;
	}
	if (IsNBit(val, 12)) {
		emit_insn(FUNC4(opcode6) | ((val & 0xfffLL) << 20LL) | RA(Ra) | RT(Rt) | (opcode6 & 0x80 ? I_LDxZ : I_LDx));
	}
	else if (IsNBit(val, 39)) {
		emit_insn((((val) >> 11LL) << 8LL) | I_EXI0);
		emit_insn(FUNC4(opcode6) | ((val & 0xfffLL) << 20LL) | RA(Ra) | RT(Rt) | (opcode6 & 0x80 ? I_LDxZ : I_LDx));
	}
	else if (IsNBit(val, 67)) {
		emit_insn((((val) >> 11LL) << 8LL) | I_EXI0);
		emit_insn((((val) >> 39LL) << 8LL) | I_EXI1);
		emit_insn(FUNC4(opcode6) | ((val & 0xfffLL) << 20LL) | RA(Ra) | RT(Rt) | (opcode6 & 0x80 ? I_LDxZ : I_LDx));
	}
xit:
	ScanToEOL();
}

static void process_reglist()
{
	int64_t val;

	any1_NextToken();
	val = expr();
	emit_insn(((val >> 2LL) << 8LL) | (val & 3LL) | 0x5C);
}

static void process_cache(int opcode6)
{
  int Ra,Rb;
	int Sc;
	int seg;
  char *p;
  int64_t disp;
  int64_t val;
  int fixup = 5;
	int cmd;

  p = inptr;
	any1_NextToken();
	cmd = (int)expr() & 0x1f;
  expect(',');
  mem_operand(&disp, &Ra, &Rb, &Sc, &seg);

	// Check for indexed mode
	if (Ra >= 0 && Rb >= 0) {
		error("Indexed mode not supported for CACHE");
		emit_insn(FUNC4(opcode6) | ((Sc & 7LL) << 29LL) | RB(Rb) | RA(Ra) | RT(cmd) | ((opcode6 & 0x80) ? I_LDxXZ : I_LDxX));
		ScanToEOL();
		return;
	}

	if (Ra <= 0) Ra = 0x40;
	if (IsNBit(val, 12)) {
		emit_insn(FUNC4(opcode6) | ((val & 0xfffLL) << 20LL) | RA(Ra) | RT(cmd) | opcode6);
	}
	else if (IsNBit(val, 39)) {
		emit_insn((((val) >> 11LL) << 8LL) | I_EXI0);
		emit_insn(FUNC4(opcode6) | ((val & 0xfffLL) << 20LL) | RA(Ra) | RT(cmd) | opcode6);
	}
	else if (IsNBit(val, 67)) {
		emit_insn((((val) >> 11LL) << 8LL) | I_EXI0);
		emit_insn((((val) >> 39LL) << 8LL) | I_EXI1);
		emit_insn(FUNC4(opcode6) | ((val & 0xfffLL) << 20LL) | RA(Ra) | RT(cmd) | opcode6);
	}
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
		if (opcode6 == 0x36)	// LV
			opcode6 = 0x19;		// LVX
		emit_insn(
			(opcode6 << 26) |
			(Vt << 16) |
			(Vb << 11) |
			(Ra << 6) |
			0x02);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	//if (val < -32768 || val > 32767)
	//	printf("LV displacement too large: %d\r\n", lineno);
	if (val >= -32768 && val < 32768) {
		emit_insn(
			(val << 16) |
			(Vt << 11) |
			(Ra << 6) |
			opcode6);
		ScanToEOL();
		return;
	}
	LoadConstant(val,23);
	// add r23,r23,ra
	if (Ra != 0)
		emit_insn(
			(0x04 << 26) |
			(3 << 21) |
			(23 << 16) |
			(23 << 11) |
			(Ra << 6) |
			0x02
		);
	emit_insn(
		(Vt << 11) |
		(23 << 6) |
		opcode6);
	ScanToEOL();
}

static void process_lsfloat(int64_t opcode6, int64_t opcode3)
{
  int Ra,Rb;
  int Rt;
	int Sc;
	int seg;
	char *p;
	int64_t disp;
	int64_t val;
	int fixup = 5;

  int  sz;
  int rm;
	//printf("Fix segment prefix\r\n");
  rm = 0;
  sz = GetFPSize();
  p = inptr;
  Rt = getFPRegister();
  if (Rt < 0) {
      printf("Expecting a float target register (1:%d).\r\n", lineno);
      printf("Line:%.60s\r\n",p);
      ScanToEOL();
      inptr-=2;
      return;
  }
  expect(',');
  mem_operand(&disp, &Ra, &Rb, &Sc, &seg);
	if (Ra > 0 && Rb > 0) {
		emit_insn(
			((opcode6+sz) << 26) |
			(Sc << 23) |
			(Rt << 18) |
			RB(Rb) |
			RA(Ra) |
			0x16);
		return;
	}
    if (Ra < 0) Ra = 0;
    val = disp;
	if (!IsNBit(val, 29)) {
		LoadConstant(val, 23);
		// Change to indexed addressing
		emit_insn(
			((opcode6+sz) << 26LL) |
			(0 << 23) |		// Sc = 0
			(Rt << 18) |
			(23 << 13) |
			RA(Ra) |
			0x02);
		ScanToEOL();
		return;
	}
	switch (sz) {
	case 0:	val &= 0xfffffffffffffffeLL; val |= 1; break;
	case 1: val &= 0xfffffffffffffffcLL; val |= 2; break;
	case 2: val &= 0xfffffffffffffff8LL; val |= 4; break;
	case 4: val &= 0xfffffffffffffff0LL; val |= 8; break;
	}
	if (!IsNBit(val, 13)) {
		emit_insn(
			(val << 18LL) |
			RT(Rt) |
			RA(Ra) |
			(1 << 6) |
			opcode6);
		ScanToEOL();
		return;
	}
	emit_insn(
		(val << 18LL) |
		RT(Rt) |
		RA(Ra) |
		opcode6);
	ScanToEOL();

}

static void process_stfloat(int64_t opcode6, int64_t opcode3)
{
	int Ra, Rb;
	int Rt;
	int Sc;
	int seg;
	char *p;
	int64_t disp;
	int64_t val;
	int fixup = 5;

	int  sz;
	int rm;
	//printf("Fix segment prefix\r\n");
	rm = 0;
	sz = GetFPSize();
	p = inptr;
	Rt = getFPRegister();
	if (Rt < 0) {
		printf("Expecting a float target register (1:%d).\r\n", lineno);
		printf("Line:%.60s\r\n", p);
		ScanToEOL();
		inptr -= 2;
		return;
	}
	expect(',');
	mem_operand(&disp, &Ra, &Rb, &Sc, &seg);
	if (Ra > 0 && Rb > 0) {
		emit_insn(
			((opcode6 + sz) << 26) |
			(Sc << 23) |
			(Rt << 18) |
			RB(Rb) |
			RA(Ra) |
			0x16);
		return;
	}
	if (Ra < 0) Ra = 0;
	val = disp;
	if (!IsNBit(val, 29)) {
		LoadConstant(val, 23);
		// Change to indexed addressing
		emit_insn(
			((opcode6 + sz) << 26LL) |
			(0 << 23) |		// Sc = 0
			(Rt << 18) |
			(23 << 13) |
			RA(Ra) |
			0x02);
		ScanToEOL();
		return;
	}
	switch (sz) {
	case 0:	val &= 0xfffffffffffffffeLL; val |= 1; break;
	case 1: val &= 0xfffffffffffffffcLL; val |= 2; break;
	case 2: val &= 0xfffffffffffffff8LL; val |= 4; break;
	case 4: val &= 0xfffffffffffffff0LL; val |= 8; break;
	}
	if (!IsNBit(val, 13)) {
		emit_insn(
			(val << 18LL) |
			RT(Rt) |
			RA(Ra) |
			(1 << 6) |
			opcode6);
		ScanToEOL();
		return;
	}
	emit_insn(
		(val << 18LL) |
		RT(Rt) |
		RA(Ra) |
		opcode6);
	ScanToEOL();

}

static void process_ld()
{
	int Rt;
	char *p;

	p = inptr;
	Rt = getRegisterX();
	expect(',');
//	any1_NextToken();
	if (token == '#') {
		inptr = p;
		process_ldi();
		return;
	}
	// Else: do a word load
	inptr = p;
	(*jumptbl[tk_lw])();
	//process_load(0x20,0x12,4);
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
		0x19
		);
	prevToken();
}

// ----------------------------------------------------------------------------
// mov r1,r2 -> translated to or Rt,Ra,#0
// ----------------------------------------------------------------------------

static void process_mov(int64_t oc, int64_t fn)
{
  int Ra;
  int Rt;
  char *p;
	int vec = 0;
	int fp = 0;
	int d3;
	int rgs = 8;
	int sz = 3;
	bool intreg = true;

	p = inptr;
	if (*p == '.')
		getSz(&sz);

	d3 = 7;	// current to current
	p = inptr;
  Rt = getRegisterX();
	if (Rt==-1) {
		intreg = false;
		inptr = p;
		Rt = getFPRegister();
		if (Rt == -1) {
			d3 = 4;
			inptr = p;
			vec = 1;
			Rt = getVecRegister();
		}
		else {
			d3 = 4;
			fp = 1;
		}
	}
  need(',');
	p = inptr;
  Ra = getRegisterX();
	if (Ra==-1) {
		intreg = false;
		inptr = p;
		Ra = getFPRegister();
		if (Ra == -1) {
			inptr = p;
			Ra = getVecRegister();
			vec |= 2;
		}
		else {
			if (fp == 1)
				d3 = 6;
			else
				d3 = 5;
			fp |= 2;
		}
	}
	if (intreg) {
		emit_insn((Ra << 13) | (Rt << 8) | I_MOV20, 5);
		goto xit;
		emit_insn(
			FUNC6(I_OR2) |
			RT(Rt) |
			RB(0) |
			RA(Ra) |
			I_R2
		);
	}
	else
		emit_insn(
			 FUNC6(oc) |
			 RT(Rt) |
			 RA(Ra) |
			 I_R2
			 );
xit:
	prevToken();
}

static int64_t process_op2()
{
	int64_t op2 = 0;

	inptr++;
	any1_NextToken();
	switch (token) {
	case tk_add:	op2 = 0x04LL;	break;
	case tk_sub:	op2 = 0x05LL;	break;
	case tk_and:	op2 = 0x08LL; break;
	case tk_or:		op2 = 0x09LL; break;
	case tk_xor:	op2 = 0x0ALL; break;
	case tk_nop:	op2 = 0x3FLL; break;
	default:	op2 = 0x3FLL; break;
	}
	return (op2);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_pushq(int oc)
{
	int Rs2;
	int Rs1;

	if (*inptr == '.') {
		inptr++;
		recflag = true;
	}
	Rs1 = getRegisterX();
	need(',');
	Rs2 = getRegisterX();
	emit_insn(
		FUNC6(oc) |
		RB(Rs2) |
		RA(Rs1) |
		RT(0) |
		I_OSR2
	);
	prevToken();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void process_setto(int oc, int func7)
{
	int Rs2;
	int Rs1;

	Rs1 = getRegisterX();
	need(',');
	Rs2 = getRegisterX();
	emit_insn(
		FUNC6(func7) |
		RB(Rs2) |
		RA(Rs1) |
		RT(0) |
		oc
	);
	prevToken();
}

// ----------------------------------------------------------------------------
// shr r1,r2,#5
// shr:sub r1,r2,#5,r3
// ----------------------------------------------------------------------------

static void process_shifti(int64_t op4)
{
	int Ra, Rc = 0;
	int Rt;
	int sz = 0;
	int64_t func6 = 0x0F;
	int64_t val;
	int64_t op2 = 0;
	char *p, *q;
	bool vm_shift = false;

	q = p = inptr;
	SkipSpaces();
	if (p[0] == ':') {
		inptr++;
		op2 = process_op2();
		q = inptr;
	}
	if (q[0]=='.')
		getSz(&sz);
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	if ((Rt >= 104 && Rt <= 111) || (Ra >= 104 && Ra <= 111)) {
		vm_shift = true;
		Rt &= 7;
		Ra &= 7;
	}
	val = expr();
	val &= 63;
	if (val < 32 && op4 == I_SLL && Ra==Rt)
		emit_insn((val << 13) |(Rt << 8LL) | I_SLLI20, 5);
	else if (val < 32 && op4 == I_SRL && Ra == Rt)
		emit_insn((val << 13) | (Rt << 8LL) | I_SRLI20, 5);
	else
		emit_insn(
			FUNC6(vm_shift ? (op4 == I_SRL ? 0x0F : 0x0E) : op4 + 1) |
			(vm_shift ? I_VM : I_R2) |
			RT(Rt) |
			RA(Ra) |
			RB(val)
		);
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
	any1_NextToken();
	if (token=='#')
		val = expr();
	else {
		inptr = p;
	    Ra = getRegisterX();
	}
	if (Ra==-1) {
		emit_insn(
			0xC0000002LL |
			RB(val & 7) |
			RA(0)
			);
	}
	else {
		emit_insn(
			0xC0000002LL |
			RB(0) |
			RA(Ra)
			);
	}
}

// ----------------------------------------------------------------------------
// REX r0,6,6,1
// ----------------------------------------------------------------------------

static void process_rex()
{
	int64_t val = 7;
	int Ra = -1;
	int64_t tgtol;
	int pl;
	int im;
    char *p;

	p = inptr;
	any1_NextToken();
	tgtol = expr() & 3LL;
	if (tgtol==0)
		error("REX: Illegal redirect to user level %d");
	need(',');
	Ra = getRegisterX();
	any1_NextToken();
	//ToDO: Fix
	emit_insn(
		FUNC6(I_REX) |
		(tgtol << 27LL) |
		RA(Ra) |
		I_OSR2
	);
}

// ----------------------------------------------------------------------------
// shl r1,r2,r3
// shl:add r1,r2,r3,r4
// ----------------------------------------------------------------------------

static void process_shift(int64_t op4)
{
	int64_t Ra, Rb = 0, Rc = 0;
	int Rt;
	char *p, *q;
	int sz = 0;
	int func6 = 0x2f;
	int64_t op2 = 0x00LL;	// NOP
	int b23 = 0;
	bool vm_shift = false;

	q = p = inptr;
	SkipSpaces();
	if (p[0] == ':') {
		inptr++;
		op2 = process_op2();
		q = inptr;
	}
	if (q[0]=='.')
		getSz(&sz);
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	need(',');
	any1_NextToken();
	if (token=='#') {
		inptr = p;
		process_shifti(op4);
		return;
	}
	else {
		prevToken();
		Rb = getRegisterX();
	}
	if ((Ra >= 104 && Ra <= 111) || (Rb >= 104 && Rb <= 111) || (Rt >= 104 && Rt <= 111)) {
		vm_shift = true;
	}
	if (vm_shift) {
		error("Vector mask shift only supports immediate mode.");
		return;
	}
	emit_insn(FUNC6(op4) | RT(Rt)| RB(Rb) | RA(Ra) | I_R2);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static int getTlbReg()
{
	int Tn;

	Tn = -1;
	SkipSpaces();
	if ((inptr[0] == 'a' || inptr[0] == 'A') &&
		(inptr[1] == 's' || inptr[1] == 'S') &&
		(inptr[2] == 'i' || inptr[2] == 'I') &&
		(inptr[3] == 'd' || inptr[3] == 'D') &&
		!isIdentChar(inptr[4])) {
		inptr += 4;
		any1_NextToken();
		return (7);
	}
	if ((inptr[0] == 'm' || inptr[0] == 'M') &&
		(inptr[1] == 'a' || inptr[1] == 'A') &&
		!isIdentChar(inptr[2])) {
		inptr += 2;
		any1_NextToken();
		return (8);
	}
	if ((inptr[0] == 'i' || inptr[0] == 'I') &&
		(inptr[1] == 'n' || inptr[1] == 'N') &&
		(inptr[2] == 'd' || inptr[2] == 'D') &&
		(inptr[3] == 'e' || inptr[3] == 'E') &&
		(inptr[4] == 'x' || inptr[4] == 'X') &&
		!isIdentChar(inptr[5])) {
		inptr += 5;
		any1_NextToken();
		return (1);
	}
	if ((inptr[0] == 'p' || inptr[0] == 'P') &&
		(inptr[1] == 'a' || inptr[1] == 'A') &&
		(inptr[2] == 'g' || inptr[2] == 'G') &&
		(inptr[3] == 'e' || inptr[3] == 'E') &&
		(inptr[4] == 's' || inptr[4] == 'S') &&
		(inptr[5] == 'i' || inptr[5] == 'I') &&
		(inptr[6] == 'z' || inptr[6] == 'Z') &&
		(inptr[7] == 'e' || inptr[7] == 'E') &&
		!isIdentChar(inptr[8])) {
		inptr += 8;
		any1_NextToken();
		return (3);
	}
	if ((inptr[0] == 'p' || inptr[0] == 'P') &&
		(inptr[1] == 'h' || inptr[1] == 'H') &&
		(inptr[2] == 'y' || inptr[2] == 'Y') &&
		(inptr[3] == 's' || inptr[3] == 'S') &&
		(inptr[4] == 'p' || inptr[4] == 'P') &&
		(inptr[5] == 'a' || inptr[5] == 'A') &&
		(inptr[6] == 'g' || inptr[6] == 'G') &&
		(inptr[7] == 'e' || inptr[7] == 'E') &&
		!isIdentChar(inptr[8])) {
		inptr += 8;
		any1_NextToken();
		return (5);
	}
	if ((inptr[0] == 'p' || inptr[0] == 'P') &&
		(inptr[1] == 't' || inptr[1] == 'T') &&
		(inptr[2] == 'a' || inptr[2] == 'A') &&
		!isIdentChar(inptr[3])) {
		inptr += 3;
		any1_NextToken();
		return (10);
	}
	if ((inptr[0] == 'p' || inptr[0] == 'P') &&
		(inptr[1] == 't' || inptr[1] == 'T') &&
		(inptr[2] == 'c' || inptr[2] == 'C') &&
		!isIdentChar(inptr[3])) {
		inptr += 3;
		any1_NextToken();
		return (11);
	}
	if ((inptr[0] == 'r' || inptr[0] == 'R') &&
		(inptr[1] == 'a' || inptr[1] == 'A') &&
		(inptr[2] == 'n' || inptr[2] == 'N') &&
		(inptr[3] == 'd' || inptr[3] == 'D') &&
		(inptr[4] == 'o' || inptr[4] == 'O') &&
		(inptr[5] == 'm' || inptr[5] == 'M') &&
		!isIdentChar(inptr[6])) {
		inptr += 6;
		any1_NextToken();
		return (2);
	}
	if ((inptr[0] == 'v' || inptr[0] == 'V') &&
		(inptr[1] == 'i' || inptr[1] == 'I') &&
		(inptr[2] == 'r' || inptr[2] == 'R') &&
		(inptr[3] == 't' || inptr[3] == 'T') &&
		(inptr[4] == 'p' || inptr[4] == 'P') &&
		(inptr[5] == 'a' || inptr[5] == 'A') &&
		(inptr[6] == 'g' || inptr[6] == 'G') &&
		(inptr[7] == 'e' || inptr[7] == 'E') &&
		!isIdentChar(inptr[8])) {
		inptr += 8;
		any1_NextToken();
		return (4);
	}
	if ((inptr[0] == 'w' || inptr[0] == 'W') &&
		(inptr[1] == 'i' || inptr[1] == 'I') &&
		(inptr[2] == 'r' || inptr[2] == 'R') &&
		(inptr[3] == 'e' || inptr[3] == 'E') &&
		(inptr[4] == 'd' || inptr[4] == 'D') &&
		!isIdentChar(inptr[5])) {
		inptr += 5;
		any1_NextToken();
		return (0);
	}
	return (Tn);
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

static void process_csrrw(int64_t op)
{
	int Rd;
	int Rs = 0;
	int Rc;
	int64_t val,val2;
	char *p;
	int sz = 3;

	p = inptr;
	if (p[0] == '.')
		getSz(&sz);
	Rd = getRegisterX();
	need(',');
	p = inptr;
	any1_NextToken();
	if (token=='#') {
		val = expr();
		if (op != I_CSRRD) {
			need(',');
			any1_NextToken();
			if (token == '#') {
				val2 = expr();
				if (val2 < -15LL || val2 > 15LL) {
					LoadConstant(val2, 2);
					emit_insn(((val & 0xcfff) << 18) | (op << 37LL) | RA(2) | RD(Rd) | I_CSR);
					return;
				}
				emit_insn(((val & 0xcfff) << 18) | (op << 37LL) | RA(val2) | RD(Rd) | I_CSR);
				return;
			}
			prevToken();
			Rs = getRegisterX();
		}
		emit_insn(((val & 0xFFFFLL) << 20LL) | RA(Rs) | RD(Rd) | op);
		prevToken();
		return;
		}
	printf("Illegal CSR instruction.\r\n");
	return;
}

// ---------------------------------------------------------------------------
// com r3,r3
// - alternate mnemonic for xor Rn,Rn,#-1
// ---------------------------------------------------------------------------

static void process_com(int oc)
{
	int Ra;
	int Rt;
	char *p;
	int sz = 3;

	p = inptr;
	if (p[0] == '.')
		getSz(&sz);
	if (*inptr == '.')
		recflag = true;
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	//TODo: Fix
	emit_insn(
		FUNC6(oc) |
		RT(Rt) |
		RA(Ra) |
		I_R1
		);
	prevToken();
}

static void process_sxx(int oc)
{
	int Ra, Rt;

	if (*inptr == '.') {
		inptr++;
		recflag = true;
	}
	Rt = getRegisterX();
	need(',');
	Ra = getRegisterX();
	emit_insn(
		(((oc >> 7) & 1) << 30) |
		BW(oc) |
		BO(0) |
		RD(Rt) |
		RA(Ra) |
		I_EXT
	);
	prevToken();
	ScanToEOL();
}

static void process_sync(int oc)
{
//    emit_insn(oc,!expand_flag);
}

static void process_tlb(int cmd)
{
	int Ra,Rt;
	int Tn;

	Ra = 0;
	Rt = 0;
	Tn = 0;
	switch (cmd) {
	case 1:     Rt = getRegisterX(); prevToken(); break;  // TLBPB
	case 2:     Rt = getRegisterX(); prevToken(); break;  // TLBRD
	case 3:     break;       // TLBWR
	case 4:     break;       // TLBWI
	case 5:     break;       // TLBEN
	case 6:     break;       // TLBDIS
	case 7: {            // TLBRDREG
		Rt = getRegisterX();
		need(',');
		Tn = getTlbReg();
	}
					break;
	case 8: {            // TLBWRREG
		Tn = getTlbReg();
		need(',');
		Ra = getRegisterX();
		prevToken();
	}
					break;
	case 9:     break;

	}
	emit_insn(
		(0x3f << 26) |	// TLB
		(cmd << 22) | 
		RB(Tn) |
		RT(Rt) |
		RA(Ra) |
		0x02
	);
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
	Vm &= 0x7;
    //prevToken();
    emit_insn((funct6<<26)|(Vm<<23)|(sz << 21)|(Vt<<16)|(Vb<<11)|(Va<<6)|0x01);
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
    emit_insn((funct6<<26)|(Vm<<23)|(sz << 21)|(Vt<<16)|(Rb<<11)|(Va<<6)|0x01);
}
       
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

static void ProcessEOL(int opt)
{
	int64_t nn, mm, cai, caia, wd, nk;
	int first;
	int jj;
	double cc;
	static char* wtcrsr = "|/-\\|/-\\";
	static int wtndx = 0;
	static int bt_index = 0;
	int evn;
	float nf;

	if ((lineno % 100) == 0) {
		printf("%c\r", wtcrsr[wtndx]);
		wtndx++;
		wtndx &= 7;
	}

	//printf("Line: %d: %.80s\r", lineno, inptr);
	expand_flag = 0;
	compress_flag = 0;
	segprefix = -1;
	first = true;
	if (bGen && (segment == codeseg || segment == dataseg || segment == rodataseg)) {
		nn = binstart;
		nk = (nn << 1) + (bt_index ? 1 : 0);
		cc = 4;
		if (segment == codeseg) {
			cc = 9;
		while (nn < sections[segment].index) {
			fprintf(ofp, "%08I64X.%01X ", ca >> 1, bt_index * 2);
			for (mm = nk; nk < mm + cc && nn < sections[segment].index; nk += cc) {
				nn = nk >> 1;
				switch (nk & 1) {
				case 0:
				case 4:
				case 8:
				case 12:
					if (((int64_t)sections[segment].bytes[nn] >> 4LL) == 0x7) {
						cc = 5;
						wd = ((int64_t)sections[segment].bytes[nn]) |
							((int64_t)sections[segment].bytes[nn + 1] << 8) |
							((int64_t)(sections[segment].bytes[nn + 2] & 15LL) << 16);
						fprintf(ofp, "    %05I64X ", wd);
					}
					else {
						cc = 9;
						wd = ((int64_t)sections[segment].bytes[nn]) |
							((int64_t)sections[segment].bytes[nn + 1] << 8) |
							((int64_t)sections[segment].bytes[nn + 2] << 16) |
							((int64_t)sections[segment].bytes[nn + 3] << 24) |
							(((int64_t)sections[segment].bytes[nn + 4] & 15) << 32);
						fprintf(ofp, "%09I64X ", wd);
					}
					break;
				case 1:
				case 5:
				case 9:
				case 13:
					if (((int64_t)sections[segment].bytes[nn+1] & 15LL) == 0x7) {
						cc = 5;
						wd = ((int64_t)sections[segment].bytes[nn] >> 4) |
							((int64_t)sections[segment].bytes[nn + 1] << 4) |
							((int64_t)sections[segment].bytes[nn + 2] << 12);
						fprintf(ofp, "    %05I64X ", wd);
					}
					else {
						cc = 9;
						wd = ((int64_t)sections[segment].bytes[nn] >> 4) |
							((int64_t)sections[segment].bytes[nn + 1] << 4) |
							((int64_t)sections[segment].bytes[nn + 2] << 12) |
							((int64_t)sections[segment].bytes[nn + 3] << 20) |
							(((int64_t)sections[segment].bytes[nn + 4]) << 28);
						fprintf(ofp, "%09I64X ", wd);
					}
					break;
					/*
					wd = ((int64_t)sections[segment].bytes[nn] >> 2) |
						((int64_t)sections[segment].bytes[nn + 1] << 6) |
						((int64_t)sections[segment].bytes[nn + 2] << 14) |
						((int64_t)sections[segment].bytes[nn + 3] << 22) |
						(((int64_t)sections[segment].bytes[nn + 4] & 15) << 30);
					fprintf(ofp, "%09I64X ", wd);
					break;
					*/
				case 2:
				case 6:
				case 10:
				case 14:
					if (((int64_t)sections[segment].bytes[nn] >> 4LL) == 0x7)
						cc = 5;
					wd = ((int64_t)sections[segment].bytes[nn] >> 4) |
						((int64_t)sections[segment].bytes[nn + 1] << 4) |
						((int64_t)sections[segment].bytes[nn + 2] << 12) |
						((int64_t)sections[segment].bytes[nn + 3] << 20) |
						(((int64_t)sections[segment].bytes[nn + 4] & 63) << 28);
					fprintf(ofp, "%09I64X ", wd);
					break;
				case 3:
				case 7:
				case 11:
				case 15:
					wd = ((int64_t)sections[segment].bytes[nn] >> 6) |
						((int64_t)sections[segment].bytes[nn + 1] << 2) |
						((int64_t)sections[segment].bytes[nn + 2] << 10) |
						((int64_t)sections[segment].bytes[nn + 3] << 18) |
						((int64_t)sections[segment].bytes[nn + 4] << 26);
					fprintf(ofp, "%09I64X ", wd);
					break;
				}
			}
			nn = nk >> 1;
			for (; nk < mm + cc; nk++)
				fprintf(ofp, "   ");
			if (first & opt) {
				fprintf(ofp, "\t%.*s\n", inptr - stptr - 1, stptr);
				first = 0;
			}
			else
				fprintf(ofp, opt ? "\n" : "; NOP Ramp\n");
			bt_index += 36;
			//ca += bt_index / 8;
			ca = ca + 9;
			bt_index &= 7;
//			nn = (int)nf;
		}	// while
		}
		else {
			caia = 0;
			while (nn < sections[segment].index) {
				fprintf(ofp, "%08I64X.%01X ", ca >> 1, bt_index * 2);
				for (mm = nk; nk < mm + cc && nn < sections[segment].index;) {
					nn = nk >> 1;
					cai = sections[segment].index - nn;
					if (cai > 10) cai = 10;
					for (jj = 0; jj < (int)cai; jj++, nk += 2) {
						fprintf(ofp, "%02X ", sections[segment].bytes[nn + jj]);
						ca += 2;
					}
					fprintf(ofp, " ");
					nn += cai;
					caia += cai;
				}
				for (jj = 10 - (int)caia; jj >= 0; jj--)
					fprintf(ofp, "   ");
				if (first & opt) {
					fprintf(ofp, "\t%.*s\n", inptr - stptr - 1, stptr);
					first = 0;
				}
				else
					fprintf(ofp, "\n");
			}
		}
		first = 1;
		caia = 0;
		/*
				for (mm = nn; nn < mm + cc && nn < sections[segment].index; ) {
					cai = sections[segment].index - nn;
					// Output for instructions with multiple words
					if ((cai % 5) == 0 && cai < 20 && segment==codeseg)
						cai = 5;
					// Otherwise a big stream of information was output, likely data
					if (cai > 10) cai = 10;
		//			for (jj = (int)cai-1; jj >= 0; jj--)
		//				fprintf(ofp, "%02X", sections[segment].bytes[nn+jj]);
					for (jj = 0; jj < (int) cai; jj++)
						fprintf(ofp, "%02X ", sections[segment].bytes[nn + jj]);
					fprintf(ofp, " ");
					nn += cai;
					caia += cai;
						}
				for (jj = 10 - (int)caia; jj >= 0; jj--)
					fprintf(ofp, "   ");
		//        for (; nn < mm + caia; nn++)
		//            fprintf(ofp, "  ");
		*/
//		else
//			fprintf(ofp, opt ? "\n" : "; NOP Ramp\n");
		//ca += caia;
		//    }
				// empty (codeless) line
		if (binstart == sections[segment].index) {
			fprintf(ofp, "%24s\t%.*s", "", inptr - stptr, stptr);
		}

		//    } // bGen
		if (opt) {
			stptr = inptr;
			lineno++;
		}
		binstart = sections[segment].index;
		bt_index = sections[segment].bt_ndx;
		ca = sections[segment].address;
	}
}

static void process_default()
{
	while (token == ' ' || token == '\t' || token == '\r')
		any1_NextToken();
	switch (token) {
	case tk_eol: ProcessEOL(1); break;
		//        case tk_add:  process_add(); break;
		//		case tk_abs:  process_rop(0x04); break;
	case tk_abs: process_rop(0x01); break;
	case tk_addi: process_riop(0x04, 0x04, 0); break;
	case tk_align: process_align(); break;
	case tk_andi:  process_riop(I_ANDI, I_AND2, 0); break;
	case tk_asl: process_shift(I_ASL); break;
	case tk_aslx: process_shift(I_ASLX); break;
	case tk_asr: process_shift(I_ASR); break;
	case tk_bal: process_call(I_BAL, 1); break;
	case tk_bbc: process_bbc(I_BBS, -1); break;
	case tk_bbs: process_bbc(I_BBS, 0); break;
	case tk_begin_expand: expandedBlock = 1; break;
	case tk_bfchg: process_bitfield(I_FLIP, 7); break;
	case tk_bfclr: process_bitfield(I_DEP, 3); break;
	case tk_bfext: process_bitfield(I_EXT, 0); break;
	case tk_bfextu: process_bitfield(I_EXT, 1); break;
	case tk_bfins: process_bitfield(I_DEP, 0); break;
	case tk_bfinsi: process_bitfield(I_DEPI, 0); break;
		//case tk_bnei: process_beqi(0x12, 1); break;
	case tk_bra: process_bra(0xD4, 0x0C); break;
	case tk_brk: process_brk(); break;
		//case tk_bsr: process_bra(0x56); break;
	case tk_bss:
		if (first_bss) {
			while (sections[segment].address & (pagesize-1)*2)
				emitNybble(0x00);
			sections[3].address = sections[segment].address;
			bss_base_address = bss_address = sections[3].address;
			first_bss = 0;
			binstart = sections[3].index;
			ca = sections[3].address;
		}
		segment = bssseg;
		break;
	case tk_bytndx: process_rrop();
	case tk_cache: process_cache(0x1E); break;
	case tk_call: process_call(I_CALL, 1); break;
	case tk_cli: emit_insn(0xC0000002); break;
	case tk_chk:  process_chk(0x34); break;
	case tk_cmovenz: process_cmove(6); break;
	case tk_cmovfnz: process_cmovf(0x27); break;
		//case tk_cmp:  process_rrop(0x06); break;
	//case tk_cmpi:  process_riop(0x06); break;
	//case tk_cmpu:  process_rrop(0x07); break;
	//case tk_cmpui:  process_riop(0x07); break;
	case tk_code: process_code(); break;
	case tk_com: process_com(3); break;
	case tk_csrrc: process_csrrw(I_CSRRC); break;
	case tk_csrrs: process_csrrw(I_CSRRS); break;
	case tk_csrrw: process_csrrw(I_CSRRW); break;
	case tk_csrrd: process_csrrw(I_CSRRD); break;
	case tk_data:
		if (first_data) {
			while (sections[segment].address & (pagesize-1)*2)
				emitNybble(0x00);
			if (rom_code)
				sections[2].address = 0;
			else
				sections[2].address = sections[segment].address;   // set starting address
			data_base_address = data_address = sections[2].address;
			first_data = 0;
			binstart = sections[2].index;
			ca = sections[2].address;
		}
		process_data(dataseg);
		break;
	case tk_db:  process_db(); break;
		//case tk_dbnz: process_dbnz(0x26,3); break;
	case tk_dc:  process_dc(); break;
	case tk_dcb: process_db(); break;
	case tk_dct: process_dct(); break;
	case tk_dcw: process_dcw(); break;
	case tk_dco: process_dco(); break;
	case tk_dep: process_bitfield(I_DEP, 0x00);
	case tk_dh:  process_dh(); break;
	case tk_dh_htbl:  process_dh_htbl(); break;
		//case tk_divsu:	process_rrop(0x3D, -1); break;
	case tk_divwait: process_rop(0x13); break;
	case tk_dw:  process_dw(); break;
		//	case tk_end: goto j1;
	case tk_else: doelse(); break;
	case tk_end_expand: expandedBlock = 0; break;
	case tk_endif: doendif(); break;
	case tk_endpublic: break;
	case tk_eori: process_riop(I_EORI, I_EOR2, 0); break;
	case tk_ext: process_bitfield(I_EXT, 0x00); break;
	case tk_extu: process_bitfield(I_EXT, 0x01); break;
	case tk_extern: process_extern(); break;
	case tk_file:
		any1_NextToken();
		if (token == tk_strconst)
			mname = std::string(laststr);
		//any1_NextToken();
		//if (token == ',') {
		//	any1_NextToken();
		//	lineno = expr();
		//}
		break;
	case tk_ftoi:	process_ftoi(0x12); break;
	case tk_fadd:	process_fprrop(0x04); break;
	case tk_fcmp:	process_fsetop(I_FCMP); break;
	case tk_fdiv:	process_fprrop(0x09); break;
	case tk_fill: process_fill(); break;
	case tk_fmov:	process_fprop(0x10); break;
	case tk_fmul:	process_fprrop(0x08); break;
	case tk_fneg:	process_fprop(0x14); break;
	case tk_fsub:	process_fprrop(0x05); break;
	case tk_fseq:	process_fsetop(I_FSEQ); break;
	case tk_fsle:	process_fsetop(I_FSLE); break;
	case tk_fslt:	process_fsetop(I_FSLT); break;
//	case tk_fsne:	process_fsetop(I_FSNE); break;
	case tk_gcsub: process_riop(I_GCSUBI, I_GCSUB, 0x00); break;
	case tk_getto: process_rop(I_GETTO); break;
	case tk_getzl: process_getzl(I_GETZL); break;
	case tk_hint:	process_hint(); break;
		//case tk_ibne: process_ibne(0x26,2); break;
	case tk_if:		pif1 = inptr - 2; doif(); break;
	case tk_ifdef:		pif1 = inptr - 5; doifdef(); break;
	case tk_ifndef:		pif1 = inptr - 6; doifndef(); break;
	case tk_isnull: process_ptrop(0x06,0); break;
	case tk_itof: process_itof(0x15); break;
	case tk_iret:	process_iret(0xC8000002); break;
	case tk_isptr:  process_ptrop(0x06,1); break;
	//case tk_jal: process_jal(0x18); break;
	case tk_jal: process_jal(I_JAL, 1); break;
	case tk_jalr: process_riop(I_JALR, I_JALR, 0); break;
	case tk_jmp: process_jal(I_JAL, 0); break;
	case tk_jsr: process_call(I_JAL,1); break;
	case tk_ld:	process_ld(); break;
	case tk_link: process_link(I_LINK); break;
		//case tk_lui: process_lui(0x27); break;
	case tk_lsr: process_shift(I_LSR); break;
	case tk_lv:  process_lv(0x36); break;
	case tk_macro:	process_macro(); break;
	case tk_memdb: emit_insn(0x04400002); break;
	case tk_memsb: emit_insn(0x04440002); break;
	case tk_message: process_message(); break;
	case tk_mov: process_mov(I_MOV, 0x00); break;
	case tk_mvseg: process_rrop(); break;
		//case tk_mulh: process_rrop(0x26, 0x3A); break;
		//case tk_muluh: process_rrop(0x24, 0x38); break;
	case tk_neg: process_com(5); break;
	case tk_nop: emit_insn(I_NOP, false); break;
	case tk_not: process_com(4); break;
		//        case tk_not: process_rop(0x07); break;
	case tk_ori: process_riop(0x09,0x09,0); break;
	case tk_org: process_org(); break;
	case tk_peekq: process_popq(I_PEEKQ); break;
	case tk_plus: compress_flag = 0;  expand_flag = 1; break;
	case tk_popq: process_popq(I_POPQ); break;
	case tk_push: process_push(); break;
	case tk_ptrdif: process_rrop(); break;
	case tk_public:
		process_public();
		break;
	case tk_pushq: process_pushq(I_PUSHQ); break;
	case tk_rodata:
		if (first_rodata) {
			while (sections[segment].address & (pagesize-1)*2)
				emitNybble(0x00);
			sections[1].address = sections[segment].address;
			rodata_base_address = rodata_address = sections[1].address;
			first_rodata = 0;
			binstart = sections[1].index;
			ca = sections[1].address;
		}
		segment = rodataseg;
		break;
	//case tk_redor: process_rop(0x06); break;
	case tk_ret: process_ret(I_RET); break;
	case tk_rex: process_rex(); break;
	case tk_rol: process_shift(I_ROL); break;
	case tk_roli: process_shifti(I_ROLI); break;
	case tk_ror: process_shift(I_ROR); break;
	case tk_rori: process_shifti(I_RORI); break;
	case tk_rte: process_iret(I_RTE); break;
	//case tk_rtl: process_ret(I_RTL); break;
	case tk_rts: process_ret(I_RET); break;
	case tk_sei: process_sei(); break;
	case tk_seq:	process_setop(I_SEQ, I_SEQ, 0x00); break;
	
	case tk_setto: process_setto(I_OSR2, I_SETTO); break;
	case tk_setwb: emit_insn(0x04580002); break;
		//case tk_seq:	process_riop(0x1B,2); break;
	case tk_sge:	process_setop(I_SGE, I_SGEI, 0x00); break;
	case tk_sgeu:	process_setop(I_SGEU, I_SGEUI, 0x00); break;
	case tk_sgt:	process_setop(-I_SLT, I_SGTI, 0x00); break;
	case tk_sgtu:	process_setop(-I_SLTU, I_SGTUI, 0x00); break;

	case tk_shl: process_shift(I_ASL); break;
	case tk_shli: process_shifti(I_ASLI); break;
	case tk_shr: process_shift(I_ASR); break;
	case tk_shri: process_shifti(I_ASRI); break;
	case tk_shru: process_shift(I_LSR); break;
	case tk_shrui: process_shifti(I_LSRI); break;

	case tk_sle:	process_setop(-I_SGE, I_SLEI, 0x00); break;
	case tk_sleu:	process_setop(-I_SGEU, I_SLEUI, 0x00); break;
	case tk_slt:	process_setop(I_SLT, I_SLTI, 0x00); break;
	case tk_sltu:	process_setop(I_SLTU, I_SLTUI, 0x00); break;
	case tk_sne:	process_setop(I_SNE, I_SNEI, 0x00); break;

	case tk_sll:	process_shift(I_SLL); break;
	case tk_slli: process_shifti(I_ASLI); break;
	case tk_srai: process_shifti(I_ASRI); break;
	case tk_srl:	process_shift(I_SRL); break;
	case tk_srli: process_shifti(I_SRLI); break;
	case tk_statq: process_pushq(11); break;
	case tk_subf: process_riop(I_SUBFI, 0x00, 0x00); break;
	case tk_subi:  process_riop(-I_ADDI,I_SUB2,0x00); break;
	case tk_sv:  process_sv(0x37); break;
	case tk_swap: process_rop(0x03); break;
		//case tk_swp:  process_storepair(0x27); break;
	case tk_sxb: process_sxx(0x07); break;
	case tk_sxw: process_sxx(0x0F); break;
	case tk_sxt: process_sxx(0x1F); break;
	case tk_sync: emit_insn(0x04480002); break;
	case tk_tlbdis:  process_tlb(6); break;
	case tk_tlben:   process_tlb(5); break;
	case tk_tlbpb:   process_tlb(1); break;
	case tk_tlbrd:   process_tlb(2); break;
	case tk_tlbrdreg:   process_tlb(7); break;
	case tk_tlbwi:   process_tlb(4); break;
	case tk_tlbwr:   process_tlb(3); break;
	case tk_tlbwrreg:   process_tlb(8); break;
	case tk_tst:	process_rop(I_TST);
	case tk_unlink: emit_insn(I_UNLINK, false); break;
	/*
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
	*/
	case tk_wai: emit_insn(FUNC6(I_WAI)|I_OSR2,true); break;
	case tk_wfi: emit_insn(FUNC6(I_WAI) | I_OSR2,true); break;
	case tk_wydndx: process_rrop();
	case tk_xori: process_riop(0x0A,0x0A,0x00); break;
	case tk_zxb: process_sxx(0x87); break;
	case tk_zxw: process_sxx(0x8F); break;
	case tk_zxt: process_sxx(0x9F); break;
	case tk_id:  process_label(); break;
	case '-': compress_flag = 1; expand_flag = 0; break;
	default:	
//		printf("%.60s\r\n", stptr);
//		printf("%*s", inptr - stptr, "^");
		break;
	}
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void any1v3_processMaster()
{
    int nn;
    int64_t bs1, bs2;
		SYM* sym;

		pagesize = 16384;
    lineno = 1;
    binndx = 0;
		bt_ndx = 0;
    binstart = 0;
		num_lbranch = 0;
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
	expandedBlock = 0;
	//if (pass == 1) 
	{
		for (nn = 0; nn < tk_last_token; nn++) {
			jumptbl[nn] = &process_default;
			parm1[nn] = 0;
			parm2[nn] = 0;
			parm3[nn] = 0;
		}
		jumptbl[tk_add] = &process_rrop;
		parm1[tk_add] = I_ADD2;
		parm2[tk_add] = I_ADDI;
		parm3[tk_add] = I_R2;
		jumptbl[tk_sub] = &process_rrop;
		parm1[tk_sub] = I_SUB2;
		parm2[tk_sub] = -I_ADDI;
		parm3[tk_sub] = I_R2;
		jumptbl[tk_cmp] = &process_cmp;
		parm1[tk_cmp] = I_CMP;
		parm2[tk_cmp] = I_CMP;
		parm3[tk_cmp] = I_R2;
		jumptbl[tk_and] = &process_rrop;
		parm1[tk_and] = I_AND2;
		parm2[tk_and] = I_ANDI;
		parm3[tk_and] = I_R2;
		jumptbl[tk_or] = &process_rrop;
		parm1[tk_or] = I_OR2;
		parm2[tk_or] = I_ORI;
		parm3[tk_or] = I_R2;
		jumptbl[tk_xor] = &process_rrop;
		parm1[tk_xor] = I_EOR2;
		parm2[tk_xor] = I_EORI;
		parm3[tk_xor] = I_R2;
		jumptbl[tk_eor] = &process_rrop;
		parm1[tk_eor] = I_EOR2;
		parm2[tk_eor] = I_EORI;
		parm3[tk_eor] = I_R2;

		jumptbl[tk_div] = &process_rrop;
		parm1[tk_div] = I_DIV;
		parm2[tk_div] = I_DIVI;
		parm3[tk_div] = I_R2;
		jumptbl[tk_divu] = &process_rrop;
		parm1[tk_divu] = I_DIVU;
		parm2[tk_divu] = I_DIVUI;
		parm3[tk_divu] = I_R2;
		jumptbl[tk_max] = &process_rrop;
		parm1[tk_max] = 0x2DLL;
		parm2[tk_max] = -1LL;
		parm3[tk_max] = I_R2;
		jumptbl[tk_min] = &process_rrop;
		parm1[tk_min] = 0x2CLL;
		parm2[tk_min] = -1LL;
		parm3[tk_min] = I_R2;
		jumptbl[tk_mod] = &process_rrop;
		parm1[tk_mod] = 0x16LL;
		parm2[tk_mod] = 0x3ELL;
		parm3[tk_mod] = I_R2;
		jumptbl[tk_modu] = &process_rrop;
		parm1[tk_modu] = 0x14LL;
		parm2[tk_modu] = 0x3CLL;
		parm3[tk_modu] = I_R2;
		jumptbl[tk_mul] = &process_rrop;
		parm1[tk_mul] = I_MUL;
		parm2[tk_mul] = I_MULI;
		parm3[tk_mul] = I_R2;
		jumptbl[tk_mulf] = &process_rrop;
		parm1[tk_mulf] = I_MULF;
		parm2[tk_mulf] = I_MULFI;
		parm3[tk_mulf] = I_R2;
		jumptbl[tk_mulu] = &process_rrop;
		parm1[tk_mulu] = I_MULU;
		parm2[tk_mulu] = I_MULUI;
		parm3[tk_mulu] = I_R2;
		jumptbl[tk_sub] = &process_rrop;
		parm1[tk_sub] = I_SUB2;
		parm2[tk_sub] = -I_ADDI;
		parm3[tk_sub] = I_R2;
		jumptbl[tk_ptrdif] = &process_ptrdif;
		parm1[tk_ptrdif] = I_PTRDIF;
		parm2[tk_ptrdif] = -1LL;
		jumptbl[tk_transform] = &process_rrop;
		parm1[tk_transform] = 0x11LL;
		parm2[tk_transform] = -1LL;
		jumptbl[tk_xnor] = &process_rrop;
		parm1[tk_xnor] = I_XNOR;
		parm2[tk_xnor] = -1LL;
		jumptbl[tk_fbeq] = &process_fbcc;
		parm1[tk_fbeq] = I_BEQ;
		parm2[tk_fbeq] = 0x04;
		parm3[tk_fbeq] = 0;
		jumptbl[tk_fbeq] = &process_fbcc;
		parm1[tk_fbne] = I_BNE;
		parm2[tk_fbne] = 0x00;
		parm3[tk_fbne] = 0;
		jumptbl[tk_fbge] = &process_fbcc;
		parm1[tk_fbge] = I_BGE;
		parm2[tk_fbge] = 0x00;
		parm3[tk_fbge] = 0;
		jumptbl[tk_fblt] = &process_fbcc;
		parm1[tk_fblt] = I_BLT;
		parm2[tk_fblt] = 0x00;
		parm3[tk_fblt] = 0;
		jumptbl[tk_beq] = &process_bcc;
		parm1[tk_beq] = I_BEQ;
		parm2[tk_beq] = 0x04;
		parm3[tk_beq] = 0;
		jumptbl[tk_bge] = &process_bcc;
		parm1[tk_bge] = I_BGE;
		parm2[tk_bge] = 1;
		parm3[tk_bge] = 1;
		jumptbl[tk_bgt] = &process_bcc;
		parm1[tk_bgt] = -I_BLT;
		parm2[tk_bgt] = 3;
		parm3[tk_bgt] = 0;
		jumptbl[tk_ble] = &process_bcc;
		parm1[tk_ble] = -I_BGE;
		parm2[tk_ble] = 2;
		parm3[tk_ble] = 0;
		jumptbl[tk_bltu] = &process_bcc;
		parm1[tk_bltu] = I_BLTU;
		parm2[tk_bltu] = 0;
		parm3[tk_bltu] = 0;
		jumptbl[tk_bgeu] = &process_bcc;
		parm1[tk_bgeu] = I_BGEU;
		parm2[tk_bgeu] = 1;
		parm3[tk_bgeu] = 1;
		jumptbl[tk_bgtu] = &process_bcc;
		parm1[tk_bgtu] = -I_BLTU;
		parm2[tk_bgtu] = 3;
		parm3[tk_bgtu] = 0;
		jumptbl[tk_bleu] = &process_bcc;
		parm1[tk_bleu] = -I_BGEU;
		parm2[tk_bleu] = 2;
		parm3[tk_bleu] = 0;
		jumptbl[tk_blt] = &process_bcc;
		parm1[tk_blt] = I_BLT;
		parm2[tk_blt] = 0;
		parm3[tk_blt] = 0;
		jumptbl[tk_bne] = &process_bcc;
		parm1[tk_bne] = I_BNE;
		parm2[tk_bne] = 0x05;
		parm3[tk_bne] = 0x00;
		jumptbl[tk_bmi] = &process_bcc;
		parm1[tk_bmi] = I_BLT;
		parm2[tk_bmi] = 0x05;
		parm3[tk_bmi] = 0x00;
		jumptbl[tk_bpl] = &process_bcc;
		parm1[tk_bpl] = I_BGE;
		parm2[tk_bpl] = 0x05;
		parm3[tk_bpl] = 0x00;
		jumptbl[tk_ldi] = &process_ldi;
		parm1[tk_ldi] = 0;
		parm2[tk_ldi] = 0;
		// stores
		jumptbl[tk_stb] = &process_store;
		parm1[tk_stb] = S_BYTE;
		parm2[tk_stb] = S_BYTE;
		parm3[tk_stb] = 0x00;
		jumptbl[tk_stw] = &process_store;
		parm1[tk_stw] = S_WYDE;
		parm2[tk_stw] = S_WYDE;
		parm3[tk_stw] = 0x01;
		jumptbl[tk_stt] = &process_store;
		parm1[tk_stt] = S_TETRA;
		parm2[tk_stt] = S_TETRA;
		parm3[tk_stt] = 0x02;
		jumptbl[tk_sto] = &process_store;
		parm1[tk_sto] = S_OCTA;
		parm2[tk_sto] = S_OCTA;
		parm3[tk_sto] = 0x03;
		jumptbl[tk_fsto] = &process_store;
		parm1[tk_fsto] = I_FSTO;
		parm2[tk_fsto] = I_FSTO;
		parm3[tk_fsto] = 0x00;
		jumptbl[tk_sth] = &process_store;
		parm1[tk_sth] = S_HEXI;
		parm2[tk_sth] = S_HEXI;
		parm3[tk_sth] = 0x04;
		jumptbl[tk_swc] = &process_store;
		parm1[tk_swc] = 0x17;
		parm2[tk_swc] = 0x23;
		parm3[tk_swc] = 0x00;
		jumptbl[tk_stm] = &process_store;
		parm1[tk_stm] = I_STM;
		parm2[tk_stm] = I_STM;
		parm3[tk_stm] = 0x00;
		// loads
		jumptbl[tk_ldb] = &process_load;
		parm1[tk_ldb] = S_BYTE;
		parm2[tk_ldb] = S_BYTE;
		parm3[tk_ldb] = 0x00;
		jumptbl[tk_ldbu] = &process_load;
		parm1[tk_ldbu] = S_BYTE|0x80;
		parm2[tk_ldbu] = S_BYTE|0x80;
		parm3[tk_ldbu] = 0x00;
		jumptbl[tk_ldw] = &process_load;
		parm1[tk_ldw] = S_WYDE;
		parm2[tk_ldw] = S_WYDE;
		parm3[tk_ldw] = 0x01;
		jumptbl[tk_ldwu] = &process_load;
		parm1[tk_ldwu] = S_WYDE|0x80;
		parm2[tk_ldwu] = S_WYDE|0x80;
		parm3[tk_ldwu] = 0x01;
		jumptbl[tk_lea] = &process_load;
		parm1[tk_lea] = 0x0F;
		parm2[tk_lea] = 0x0F;
		parm3[tk_lea] = 0x00;
		jumptbl[tk_ldt] = &process_load;
		parm1[tk_ldt] = S_TETRA;
		parm2[tk_ldt] = S_TETRA;
		parm3[tk_ldt] = 0x02;
		jumptbl[tk_ldtu] = &process_load;
		parm1[tk_ldtu] = S_TETRA|0x80;
		parm2[tk_ldtu] = S_TETRA|0x80;
		parm3[tk_ldtu] = 0x02;
		jumptbl[tk_ldo] = &process_load;
		parm1[tk_ldo] = S_OCTA;
		parm2[tk_ldo] = S_OCTA;
		parm3[tk_ldo] = 0x03;
		jumptbl[tk_ldor] = &process_load;
		parm1[tk_ldor] = I_LDOR;
		parm2[tk_ldor] = I_LDOR;
		parm3[tk_ldor] = 0x03;
		jumptbl[tk_ldh] = &process_load;
		parm1[tk_ldh] = S_HEXI;
		parm2[tk_ldh] = S_HEXI;
		parm3[tk_ldh] = 0x04;
		jumptbl[tk_fldo] = &process_load;
		parm1[tk_fldo] = I_FLDO;
		parm2[tk_fldo] = I_FLDO;
		parm3[tk_fldo] = 0x03;
		jumptbl[tk_fsto] = &process_store;
		parm1[tk_fsto] = I_FSTO;
		parm2[tk_fsto] = I_FSTO;
		parm3[tk_fsto] = 0x03;
		jumptbl[tk_ldm] = &process_load;
		parm1[tk_ldm] = I_LDM;
		parm2[tk_ldm] = I_LDM;
		parm3[tk_ldm] = 0x00;
		jumptbl[tk_bytndx] = &process_rrop;
		parm1[tk_bytndx] = I_BYTNDX;
		parm2[tk_bytndx] = I_BYTNDX;
		parm3[tk_bytndx] = I_R2;
		jumptbl[tk_wydndx] = &process_rrop;
		parm1[tk_wydndx] = I_WYDNDX;
		parm2[tk_wydndx] = I_WYDNDX;
		parm3[tk_wydndx] = I_R2;
		jumptbl[tk_sf] = &process_store;
		parm1[tk_sf] = 0x2B;
		parm2[tk_sf] = 0x2D;
		parm3[tk_sf] = 0x01;
		jumptbl[tk_lf] = &process_load;
		parm1[tk_lf] = 0x1B;
		parm2[tk_lf] = 0x1D;
		parm3[tk_lf] = 0x01;
		jumptbl[tk_mvseg] = &process_rrop;
		parm1[tk_mvseg] = I_MVSEG;
		parm2[tk_mvseg] = I_MVSEG;
		parm3[tk_mvseg] = I_OSR2;
		jumptbl[tk_mvmap] = &process_rrop;
		parm1[tk_mvmap] = I_MVMAP;
		parm2[tk_mvmap] = I_MVMAP;
		parm3[tk_mvmap] = I_OSR2;
		jumptbl[tk_mvci] = &process_rrop;
		parm1[tk_mvci] = I_MVCI;
		parm2[tk_mvci] = I_MVCI;
		parm3[tk_mvci] = I_OSR2;
		jumptbl[tk_rem] = &process_rrop;
		parm1[tk_rem] = I_REM;
		parm2[tk_rem] = I_REMI;
		parm3[tk_rem] = I_R2;
		jumptbl[tk_perm] = &process_rrop;
		parm1[tk_perm] = I_PERM;
		parm2[tk_perm] = I_PERMI;
		parm3[tk_perm] = I_R2;
		jumptbl[tk_ptrdif] = &process_rrop;
		parm1[tk_ptrdif] = I_PTRDIF;
		parm2[tk_ptrdif] = I_PTRDIF;
		parm3[tk_ptrdif] = I_R3;
	}
	tbndx = 0;

	if (pass==3) {
    htblmax = 0;
		sym = new_symbol("__data_start");
		sym->value.low = 0;
		sym->value.high = 0;
    for (nn = 0; nn < 100000; nn++) {
      hTable[nn].count = 0;
      hTable[nn].opcode = 0;
    }
  }
  for (nn = 0; nn < 12; nn++) {
    sections[nn].index = 0;
		sections[nn].bt_ndx = 0;
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
	current_symbol = nullptr;
	ZeroMemory(&insnStats, sizeof(insnStats));
	SymbolInitForPass();
	num_lbranch = 0;
	num_insns = 0;
	num_cinsns = 0;
	num_bytes = 0;
	ZeroMemory(binfile, sizeof(binfile));
	any1_NextToken();
  while (token != tk_eof && token != tk_end) {
		recflag = FALSE;
//        printf("\t%.*s\n", inptr-stptr-1, stptr);
//        printf("token=%d\r", token);
    if (expandedBlock)
      expand_flag = 1;
		(*jumptbl[token])();
    any1_NextToken();
  }
j1:
	fprintf(ofp, "\r\n");
	fprintf(ofp, "rodata start: %16I64X\r\n", rodata_base_address);
	fprintf(ofp, "data start: %16I64X\r\n", data_base_address);
	fprintf(ofp, "bss start: %16I64X\r\n", bss_base_address);
	fprintf(ofp, "\r\n");
}

