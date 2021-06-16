// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2020  Robert Finch, Waterloo
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
#ifndef A64_H
#define A64_H

#include <Windows.h>
#include "token.h"
#include "elf.hpp"
#include "NameTable.hpp"
#include "symbol.h"
#include "ht.h"

enum {
    codeseg = 0,
    rodataseg = 1,
    dataseg = 2,
    bssseg = 3,
    tlsseg = 4,
    stackseg = 5,
    constseg = 6,
};

extern int rel_out;
extern int code_bits;
extern int data_bits;
extern FILE *ofp, *vfp;
extern int64_t program_address;
extern int64_t start_address;
extern char first_org;
extern int bGen;
extern char fSeg;
extern int segment;
extern int segmodel;
extern SHashTbl HashInfo;

extern FilenameStack fns;
extern std::string mname;
extern int gCpu;
extern bool gpu;
extern char lastid[500];
extern char laststr[500];
extern char current_label[500];
extern Int128 last_icon;
extern Int128 ival;
extern char *inptr;
extern char *stptr;
extern int lineno;
extern int64_t code_address;
extern int8_t code_bit_ndx;
extern int64_t bss_address;
extern int64_t data_address;
extern int segprefix;
extern int masterFileLength;
extern char masterFile[10000000];
extern uint8_t binfile[10000000];
extern int binndx;
extern int64_t binstart;
extern int8_t bitstart;
extern NameTable nmTable;
extern float num_bytes;
extern int num_insns;
extern int num_cinsns;
extern int num_lbranch;
extern int tbndx;
extern int pass;

extern void doif();
extern int64_t expr();
extern Int128 expr128();
void Table888_processMaster();
extern void emitCode(int cd);
extern void emitByte(int64_t cd);
extern void emitChar(int64_t cd);
extern void emitHalf(int64_t cd);
extern void emitWord(int64_t cd);
extern void process_align();
extern void process_db();
extern void process_dc();
extern void process_dd();
extern void process_dh();
extern void process_dh_htbl();
extern void process_dw();
extern void process_fill();
extern void process_extern();
extern void process_org();
extern void process_code();
extern void process_data(int);
extern void process_public();
extern void process_label();
extern void process_hint();
extern void bump_address();
extern int getIdentifier();
extern bool IsNBit(int64_t val, int64_t n);
extern int GetSymNdx(SYM *sp);
extern SYM *GetSymByIndex(int n);
extern void getbase(int base);
extern int NumSections;
extern clsElf64Section sections[12];
extern SYM *lastsym;

extern char currentFilename[300];
extern HTBLE hTable[10000];
extern char nametext[1000000];
extern int processOpt;
extern int expandedBlock;
extern int gCanCompress;
extern int expand_flag;
extern int compress_flag;
extern int16_t token2;
extern int32_t reg;

#endif
