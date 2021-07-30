// FLINK.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <io.h>
#include <direct.h>
#include <iostream>
#include <fstream>
#include <string>
#include "futs.h"
#include "elf.hpp"
#include "any1elf.hpp"
#include "NameTable.hpp"

#define I_EXI0	0x50
#define I_EXI1	0x51
#define I_EXI2	0x52

#define ZeroMemory(a,b) memset((a),0,(b))

bool opt_nologo = false;
bool rel_out = false;

extern void searchenv(char* filename, char* envname, char** pathname);

char nametext[1000000]; 
NameTable nmTable;
int file_count;
char entry_sym[300];
clsElf64File elf_file;
clsElf64File elf_fileo;
clsElf64File* elf_files[100];

typedef struct
{
  int64_t insn;
  bool rec;
} InsnRec;

void searchenv(char* filename, char* envname, char** pathname)
{
  static char pbuf[5000];
  static char pname[5000];
  char* p;
  //   char *strpbrk(), *strtok(), *getenv();

  if (pathname == (char**)NULL)
    return;
  strncpy(pname, filename, sizeof(pname) / sizeof(char) - 1);
  pname[4999] = '\0';
  if (_access(pname, 0) != -1) {
    *pathname = _strdup(pname);
    return;
  }

  /* ----------------------------------------------------------------------
        The file doesn't exist in the current directory. If a specific
     path was requested (ie. file contains \ or /) or if the environment
     isn't set, return a NULL, else search for the file on the path.
  ---------------------------------------------------------------------- */

  if (!(p = getenv(envname)))
  {
    *pathname = strdup("");
    return;
  }

  strcpy(pbuf, "");
  strcat(pbuf, p);
  if (p = strtok(pbuf, ";"))
  {
    do
    {
      sprintf(pname, "%0.4999s\\%s", p, filename);

      if (access(pname, 0) >= 0) {
        *pathname = strdup(pname);
        return;
      }
    } while (p = strtok(NULL, ";"));
  }
  *pathname = strdup("");
}

int64_t GetInsn()
{
  int nn;
  int64_t ins[9];
  int64_t insn;

  insn = 0LL;
  for (nn = 0; nn < 5; nn++) {
    ins[nn] = elf_file.sections[0]->GetNybble();
  }
  for (; nn < 9; nn++) {
    ins[nn] = ins[1] != 0x7LL ? elf_file.sections[0]->GetNybble() : 0LL;
  }
  for (nn = 8; nn >= 0; nn--)
    insn = insn | (ins[nn] << (nn * 4));
  return (insn);
}

void compress_exi(char *fname, bool searchincl)
{
  FILE* fp;
  char* pathname;
  InsnRec ins[8];
  int64_t insn, op_major;
  int wn, nn;
  bool rec;

  pathname = nullptr;
  for (nn = 0; nn < 8; nn++) {
    ins[nn].insn = 0x3fLL;
    ins[nn].rec = false;
  }
  fp = fopen(fname, "r");
  if (fp == nullptr) {
    if (searchincl) {
      searchenv(fname, (char *)"INCLUDE", &pathname);
      if (strlen(pathname)) {
        fp = fopen(pathname, "r");
        if (fp) goto j1;
      }
    }
    printf("Can't open file <%s>\n", fname);
    goto j2;
  }
j1:
  elf_file.Read(fp);
  wn = 0;
  for (nn = 0; nn < elf_file.hdr.e_shnum; nn++) {
    elf_fileo.sections[nn]->Clear();
    elf_fileo.sections[nn]->start = elf_file.sections[nn]->start;
  }
  while (!elf_file.sections[7]->IsEos()) {

  }
  while (!elf_file.sections[0]->IsEos()) {
    rec = true;
    for (nn = 7; nn >= 1; nn--)
      ins[nn] = ins[nn - 1];
    insn = ins[0].insn = GetInsn();
    ins[0].rec = true;
    op_major = insn & 0x7fLL;
    switch (op_major) {
    case I_EXI2:
      if (ins[1].insn & 0x7fLL == I_EXI1 && ins[2].insn & 0x7fLL == I_EXI0) {
        if (ins[2].insn & 0x800000000LL) {
          if (ins[1].insn == 0xFFFFFFF51LL && ins[0].insn == 0xFFFFFFF52LL) {
            ins[0].rec = false;
            ins[1].rec = false;
          }
        }
        else {
          if (ins[1].insn == 0x000000051LL && ins[0].insn == 0x000000052LL) {
            ins[0].rec = false;
            ins[1].rec = false;
          }
        }
      }
      break;
    case I_EXI1:
      if (ins[1].insn & 0x7fLL == I_EXI0) {
        if (ins[1].insn & 0x800000000LL) {
          if (ins[0].insn == 0xFFFFFFF51LL)
            ins[0].rec = false;
        }
        else {
          if (ins[0].insn == 0x000000051LL)
            ins[0].rec = false;
        }
      }
    }
    if (ins[7].rec)
      elf_fileo.sections[0]->AddAny1Insn(ins[7].insn);
  }
  // Flush output
  for (nn = 6; nn >= 0; nn--)
    if (ins[nn].rec)
      elf_fileo.sections[0]->AddAny1Insn(ins[nn].insn);

  fclose(fp);
j2:
  if (pathname)
    free(pathname);
}

void ReadFile(char* fname, bool searchincl)
{
  FILE* fp;
  char* pathname;
  int nn;

  pathname = nullptr;
  fp = fopen(fname, "r");
  if (fp == nullptr) {
    if (searchincl) {
      searchenv(fname, (char*)"INCLUDE", &pathname);
      if (strlen(pathname)) {
        fp = fopen(pathname, "r");
        if (fp) goto j1;
      }
    }
    printf("Can't open file <%s>\n", fname);
    goto j2;
  }
j1:
  elf_files[file_count] = new clsElf64File();
  if (elf_files[file_count])
    elf_files[file_count]->Read(fp);
  fclose(fp);
  file_count++;
j2:
  if (pathname)
    free(pathname);
}

void ParseOption(char* option)
{
  if (strcmp(option, "NOLOGO") == 0)
    opt_nologo = true;
  if (strncmp(option, "ENTRY:", 6) == 0) {
    strcpy_s(entry_sym, sizeof(entry_sym), &option[6]);
  }
}

// Find Symbol structure.

typedef struct _tagFs {
  int fileno;
  int symnum;
  Elf64Symbol* sym;
  char* name;
} FS;

// Look in all the input files for the entry symbol. Check every file in case
// it is duplicated.

FS FindEntrySymbol()
{
  int fileno;
  int secs;
  Elf64Symbol* sym, * symtab;
  int symcount, symno;
  int symtabndx = -1;
  int strtabndx = -1;
  char* symname;
  FS fes;
  int count;

  count = 0;
  fes.fileno = -1;
  fes.symnum = -1;
  fes.name = nullptr;
  fes.sym = nullptr;
  for (fileno = 0; fileno < file_count; fileno++) {
    printf("File: %d\r\n", fileno);
    for (secs = 0; secs < elf_files[fileno]->hdr.e_shnum; secs++) {
      printf("Section: %d\r\n", secs);
      if (elf_files[fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_SYMTAB) {
        symtabndx = secs;
        printf("Found symtab: %d\r\n", symtabndx);
      }
      if (elf_files[fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_STRTAB) {
        strtabndx = secs;
        printf("Found strtab: %d\r\n", strtabndx);
      }
    }
    printf("\r\n");
    if (symtabndx >= 0 && strtabndx >= 0) {
      symtab = (Elf64Symbol*)&elf_files[fileno]->sections[symtabndx]->bytes[0];
      symcount = elf_files[fileno]->sections[symtabndx]->hdr.sh_size / elf_files[fileno]->sections[symtabndx]->hdr.sh_entsize;
      for (symno = 0; symno < symcount; symno++) {
        sym = &symtab[symno];
        symname = (char *)&elf_files[fileno]->sections[strtabndx]->bytes[sym->st_name];
        printf("sym: %s\r", symname);
        if (strcmp(symname, entry_sym) == 0) {
          if (count == 0) {
            fes.fileno = fileno;
            fes.symnum = symno;
            fes.sym = sym;
            fes.name = symname;
          }
          count++;
        }
      }
    }
  }
  if (count < 1)
    printf("No defined entry point.\r\n");
  else if (count > 1)
    printf("Multiple entry points for entry symbol.\r\n");
  return (fes);
}

FS FindLowsetAddressSymbol()
{
  int fileno;
  int secs;
  Elf64Symbol* sym, * symtab;
  int symcount, symno;
  int symtabndx = -1;
  int strtabndx = -1;
  char* symname;
  FS fes;
  int count;

  count = 0;
  fes.fileno = -1;
  fes.symnum = -1;
  fes.name = nullptr;
  fes.sym = nullptr;
  for (fileno = 0; fileno < file_count; fileno++) {
    printf("File: %d\r\n", fileno);
    for (secs = 0; secs < elf_files[fileno]->hdr.e_shnum; secs++) {
      printf("Section: %d\r\n", secs);
      if (elf_files[fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_SYMTAB) {
        symtabndx = secs;
        printf("Found symtab: %d\r\n", symtabndx);
      }
      if (elf_files[fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_STRTAB) {
        strtabndx = secs;
        printf("Found strtab: %d\r\n", strtabndx);
      }
    }
    printf("\r\n");
    if (symtabndx >= 0 && strtabndx >= 0) {
      symtab = (Elf64Symbol*)&elf_files[fileno]->sections[symtabndx]->bytes[0];
      symcount = elf_files[fileno]->sections[symtabndx]->hdr.sh_size / elf_files[fileno]->sections[symtabndx]->hdr.sh_entsize;
      for (symno = 0; symno < symcount; symno++) {
        sym = &symtab[symno];
        symname = (char*)&elf_files[fileno]->sections[strtabndx]->bytes[sym->st_name];
        printf("sym: %s\r", symname);
        if ((fes.sym == nullptr || ((uint64_t)sym->st_value < (uint64_t)fes.sym->st_value)) && (sym->st_info & 16)) {
          fes.fileno = fileno;
          fes.symnum = symno;
          fes.name = symname;
          fes.sym = sym;
        }
      }
    }
  }
  return (fes);
}

void CopyToOutput(FS efes)
{
  int textsec = -1;
  int secs;
  int et;
  clsElf64Section* sec;
  Elf64Symbol* sym;
  FS fes;

  // Find the program bits
  for (secs = 0; secs < elf_files[efes.fileno]->hdr.e_shnum; secs++) {
    if (elf_files[efes.fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_PROGBITS) {
      textsec = secs;
      break;
    }
  }
  if (textsec < 0)
    return;
  et = elf_fileo.sections[0]->hdr.sh_size;
  sec = elf_files[efes.fileno]->sections[textsec];
  memcpy(
    &elf_fileo.sections[0]->bytes[et],
    &sec->bytes[0],
    elf_files[efes.fileno]->sections[0]->hdr.sh_size
  );
  et += elf_files[efes.fileno]->sections[0]->hdr.sh_size;
  elf_fileo.sections[0]->hdr.sh_size = et;
  /*
  fes = FindLowsetAddressSymbol();
  printf("Lowest address: %s %08I64x\r\n", fes.name, fes.sym->st_value);
  if (fes.fileno == -1)
    return;
  et = elf_fileo.sections[0]->hdr.sh_size;
  sec = elf_files[fes.fileno]->sections[textsec];
  memcpy(
    &elf_fileo.sections[0]->bytes[et],
    &sec->bytes[(fes.sym->st_value-sec->hdr.sh_addr)/2],
    fes.sym->st_size
  );
  et += fes.sym->st_size;
  elf_fileo.sections[0]->hdr.sh_size = et;
  */
}

typedef struct _tagFXI {
  unsigned int type : 7;
  unsigned int isExtern : 1;
  unsigned int bits : 8;
  unsigned int pad : 16;
  unsigned int ord : 32;
} FXI;

uint64_t GetInsn(clsElf64Section* sec, uint64_t offset)
{
  int64_t insn;

  if (offset & 1LL) {
    insn  = (sec->bytes[(uint64_t)(offset) >> 1LL] >> 4LL) & 15; // Get low nybble
    insn |= (*(uint64_t*)&sec->bytes[(uint64_t)(offset + 1LL) >> 1LL] & 0xffffffffLL) << 4LL; // Get remaining nybbles
  }
  else
    insn = *(uint64_t*)&sec->bytes[(uint64_t)offset >> 1LL] & 0xfffffffffLL;
  return (insn);
}

void PutInsn(uint64_t insn, clsElf64Section* sec, uint64_t offset)
{
  uint64_t n;
  int64_t insn;

  if (offset & 1LL) {
    n = (sec->bytes[(uint64_t)(offset) >> 1LL]) & 15; // Get low nybble
    *(uint64_t*)&sec->bytes[(uint64_t)(offset) >> 1LL] = ((insn & 15LL) << 4LL) | n; // Set low nybble
    n = (*(uint64_t*)&sec->bytes[(uint64_t)(offset + 1LL) >> 1LL]) & 0xffffffff00000000LL;
    *(uint64_t*)&sec->bytes[(uint64_t)(offset + 1LL) >> 1LL] = n|(insn >> 4LL); // Set remaining nybbles
  }
  else {
    n = (*(uint64_t*)&sec->bytes[(uint64_t)(offset + 1LL) >> 1LL]) & 0xfffffff000000000LL;
    *(uint64_t*)&sec->bytes[(uint64_t)(offset + 1LL) >> 1LL] = n|insn; // Set nybbles
  }
}

void CopyCodeSection(clsElf64Section* dst, clsElf64Section* src)
{
  memcpy(dst, src, src->hdr.sh_size);
}

void CompactCodeSection(clsElf64Section* sec)
{
}

void CopyToCodeSection(clsElf64Section* dst, clsElf64Section* src, uint64_t offset, uint64_t size);
{
  int nn, kk;
  uint64_t insn;

  kk = dst->hdr.sh_size;
  for (nn = 0; nn < size; nn += 9) {
    insn = GetInsn(src, offset + nn);
    if (insn == 0x03f3f3f3fLL || insn == 0x13f3f3f3fLL || insn == 0x23f3f3f3fLL)
      ;
    else {
      PutInsn(insn, dst, kk);
      kk += 9;
    }
  }
  dst->hdr.sh_size = kk;
  dst->hdr.sh_size += 31LL;
  dst->hdr.sh_size &= 0xffffffffffffffe0LL;
}

int symcmp(void* a, void* b)
{
  Elf64Symbol* aa = (Elf64Symbol*)a;
  Elf64Symbol* bb = (Elf64Symbol*)b;

  if ((uint64_t)aa->st_value < (uint64_t)bb->st_value)
    return (-1);
  if (aa->st_value == bb->st_value)
    return (0);
  return (1);
}

void FixupSymbols(FS fs, uint64_t baseaddr)
{
  int textsec = -1;
  int symtabsec = -1;
  int secs;
  int et;
  int nn;
  clsElf64Section* sec, * newsec;
  Elf64Symbol* sym, * symtab;
  Elf64rel* relrec;
  FXI fxi;
  uint64_t addr;
  uint64_t insn[8];
  uint64_t tgt_offset;
  int64_t dif;
  uint64_t newadr;
  int signbit;

  // Find the program bits
  for (secs = 0; secs < elf_files[fs.fileno]->hdr.e_shnum; secs++) {
    if (elf_files[fs.fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_PROGBITS) {
      textsec = secs;
      break;
    }
  }
  if (textsec < 0)
    return;
  sec = elf_files[fs.fileno]->sections[7];
  newsec = new clsElf64Section;
  ZeroMemory(newsec->bytes, sizeof(newsec->bytes));
  CopyCodeSection(newsec, elf_files[fs.fileno]->sections[textsec]);
  dif = 0;
  for (nn = 0; nn < sec->hdr.sh_size; nn += sec->hdr.sh_entsize) {
    relrec = (Elf64rel* )&sec->bytes[nn];
    fxi.type = relrec->r_info & 0x7fLL;
    fxi.isExtern = (relrec->r_info >> 7LL) & 1LL;
    fxi.bits = (relrec->r_info >> 8LL) & 0xffLL;
    fxi.ord = (relrec->r_info >> 32LL) & 0xffffffffLL;
    switch (fxi.type) {
    case ANY1_FUTC67:
    case ANY1_FUTC67L:
    case ANY1_FUTC67S:
      // Get instruction and prefixes
      insn[0] = GetInsn(sec, relrec->r_offset);       // 50
      insn[1] = GetInsn(sec, relrec->r_offset + 9);   // 51
      insn[2] = GetInsn(sec, relrec->r_offset + 18);  // opcode
      // Compute new prefixes
      switch (fxi.type) {
      case ANY1_FUTC67:
        // Compute fixed-up address
        addr = (insn[2] >> 20LL) & 0x3ffLL;
        addr |= ((insn[0] >> 8LL) << 11LL);
        addr |= ((insn[1] >> 8LL) << 39LL);
        addr += baseaddr - dif;
        insn[2] &= 0xfffffLL;
        insn[2] |= ((addr & 0xffffLL) << 20LL);
        signbit = (insn[2] >> 35LL) & 1LL;
        break;
      case ANY1_FUTC67L:
        // Compute fixed-up address
        addr = (insn[2] >> 20LL) & 0x3ffLL;
        addr |= ((insn[0] >> 8LL) << 11LL);
        addr |= ((insn[1] >> 8LL) << 39LL);
        addr += baseaddr - dif;
        insn[2] &= 0xf000fffffLL;
        insn[2] |= ((addr & 0xfffLL) << 20LL);
        signbit = (insn[2] >> 31LL) & 1LL;
        break;
      case ANY1_FUTC67S:
        // Compute fixed-up address
        addr = ((insn[2] >> 8LL) & 0x3fLL) | ((insn[2] >> 27LL) & 0x1fLL);
        addr |= ((insn[0] >> 8LL) << 11LL);
        addr |= ((insn[1] >> 8LL) << 39LL);
        addr += baseaddr - dif;
        insn[2] &= 0xf07ffc0ffLL;
        insn[2] |= ((addr & 0x3fLL) << 8LL);
        insn[2] |= (((addr >> 6LL) & 0x1fLL) << 27LL);
        signbit = (insn[2] >> 31LL) & 1LL;
        break;
      }
      insn[1] = (((addr >> 11LL) << 8LL) | 0x51) & 0xfffffffffLL;
      insn[0] = (((addr >> 39LL) << 8LL) | 0x50) & 0xfffffffffLL;
      // Remove redundant prefixes (convert to NOPS)
      tgt_offset = relrec->r_offset - dif;
      if (((insn[2] >> 35LL) & 1LL) == 1LL) {
        // All ones?
        if (((insn[0] >> 8LL) == 0xfffffffLL) && ((insn[1] >> 8LL) == 0xfffffffLL)) {
          PutInsn(0x03f3f3f3fLL, newsec, tgt_offset);
          PutInsn(0x13f3f3f3fLL, newsec, tgt_offset + 9);
          PutInsn(insn[2], newsec, tgt_offset + 18);
          dif += 18;
        }
        else if ((insn[1] >> 8LL) == 0xfffffffLL) {
          PutInsn(0x13f3f3f3fLL, newsec, tgt_offset);
          PutInsn(insn[0], newsec, tgt_offset + 9);
          PutInsn(insn[2], newsec, tgt_offset + 18);
          dif += 9;
        }
        else {
          PutInsn(insn[0], newsec, tgt_offset);
          PutInsn(insn[1], newsec, tgt_offset + 9);
          PutInsn(insn[2], newsec, tgt_offset + 18);
        }
      }
      else {
        // All zeros?
        if (((insn[0] >> 8LL) == 0LL) && (insn[1] >> 8LL) == 0LL) {
          PutInsn(0x03f3f3f3fLL, newsec, tgt_offset);
          PutInsn(0x13f3f3f3fLL, newsec, tgt_offset + 9);
          PutInsn(insn[2], newsec, tgt_offset + 18);
          dif += 18;
        }
        else if ((insn[1] >> 8LL) == 0LL) {
          PutInsn(0x13f3f3f3fLL, newsec, tgt_offset);
          PutInsn(insn[0], newsec, tgt_offset + 9);
          PutInsn(insn[2], newsec, tgt_offset + 18);
          dif += 9;
        }
        else {
          PutInsn(insn[0], newsec, tgt_offset);
          PutInsn(insn[1], newsec, tgt_offset + 9);
          PutInsn(insn[2], newsec, tgt_offset + 18);
        }
      }
      break;
    case ANY1_FUTC95:
      insn[0] = GetInsn(sec, relrec->r_offset);       // 50
      insn[1] = GetInsn(sec, relrec->r_offset + 9);   // 51
      insn[2] = GetInsn(sec, relrec->r_offset + 18);  // 52
      insn[3] = GetInsn(sec, relrec->r_offset + 27);  // opcode
      if (((insn[3] >> 35LL) & 1LL) == 1LL) {
        // All ones?
        if (((insn[0] >> 8LL) == 0xfffffffLL) && ((insn[1] >> 8LL) == 0xfffffffLL) && ((insn[2] >> 8LL) == 0xfffffffLL)) {
          insn[0] = 0x03f3f3f3fLL;
          insn[1] = 0x13f3f3f3fLL;
          insn[2] = 0x23f3f3f3fLL;
        }
        else if (((insn[1] >> 8LL) == 0xfffffffLL) && (insn[2] >> 8LL) == 0xfffffffLL) {
          insn[1] = 0x13f3f3f3fLL;
          insn[2] = 0x23f3f3f3fLL;
        }
        else if ((insn[2] >> 8LL) == 0xfffffffLL)
          insn[2] = 0x23f3f3f3fLL;
      }
      else {
        // All zeros?
        if (((insn[0] >> 8LL) == 0LL) && ((insn[1] >> 8LL) == 0LL) && ((insn[2] >> 8LL) == 0LL)) {
          insn[0] = 0x03f3f3f3fLL;
          insn[1] = 0x13f3f3f3fLL;
          insn[2] = 0x23f3f3f3fLL;
        }
        else if (((insn[1] >> 8LL) == 0LL) && (insn[2] >> 8LL) == 0LL) {
          insn[1] = 0x13f3f3f3fLL;
          insn[2] = 0x23f3f3f3fLL;
        }
        else if ((insn[2] >> 8LL) == 0LL)
          insn[2] = 0x23f3f3f3fLL;
      }
      break;
    }
  }
  // Find the symbol table
  for (secs = 0; secs < elf_files[fs.fileno]->hdr.e_shnum; secs++) {
    if (elf_files[fs.fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_SYMTAB) {
      symtabsec = secs;
      break;
    }
  }
  if (symtabsec < 0)
    return;
  symtab = (Elf64Symbol* )&elf_files[fs.fileno]->sections[symtabsec]->bytes[0];
  qsort(
    symtab,
    elf_files[fs.fileno]->sections[symtabsec]->hdr.sh_size / elf_files[fs.fileno]->sections[symtabsec]->hdr.sh_entsize,
    elf_files[fs.fileno]->sections[symtabsec]->hdr.sh_entsize,
    symcmp
  );
  for (nn = 0; nn < elf_files[fs.fileno]->sections[symtabsec]->hdr.sh_size; nn += elf_files[fs.fileno]->sections[symtabsec]->hdr.sh_entsize) {
    sym = (Elf64Symbol *)&elf_files[fs.fileno]->sections[symtabsec]->bytes[nn];
    if (sym->st_shndx == 0) {
      newadr = elf_files[fs.fileno]->sections[textsec]->hdr.sh_addr + elf_files[fs.fileno]->sections[textsec]->hdr.sh_size;
      CopyToCodeSection(newsec, elf_files[fs.fileno]->sections[textsec], sym->st_value, sym->st_size);
      sym->st_value = newadr;
    }
  }
}


void AddTextsec()
{
  clsElf64Section* textsec;

  textsec = new clsAny1elfSection();
  textsec->hdr.sh_name = nmTable.AddName((char *)".text");
  textsec->hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
  textsec->hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_EXECINSTR;
  textsec->hdr.sh_addr = rel_out ? 0 : textsec->start;
  textsec->hdr.sh_offset = 512;  // offset in file
  textsec->hdr.sh_size = textsec->index;
  textsec->hdr.sh_link = 0;
  textsec->hdr.sh_info = 0;
  textsec->hdr.sh_addralign = 16;
  textsec->hdr.sh_entsize = 0;
  elf_fileo.AddSection(textsec);
}

void SaveOutput(char *ofname)
{
  FILE* fp;

  fp = fopen(ofname, "wb");
  elf_fileo.Write(fp);
  fclose(fp);
}

int main(int argc, char *argv[])
{
  int nn;
  FES fes;

  if (argc < 2) {
    exit(0);
  }
  for (nn = 0; nn < 100; nn++)
    elf_files[nn] = nullptr;
  file_count = 0;
  nmTable.Clear();
  ZeroMemory(entry_sym, sizeof(entry_sym));
  for (nn = 1; nn < argc; nn++) {
    if (argv[nn][0] == '/')
      ParseOption(&argv[nn][1]);
    else
      ReadFile(argv[nn], true);
  }
  if (!opt_nologo) {
    printf("\r\nFLINK v0.1 (c) 2021 Robert Finch\r\n");
  }
  if (entry_sym[0] == '\0')
    strcpy(entry_sym, "start");
  AddTextsec();
  fes = FindEntrySymbol();
  // The file containing the entry symbol is the root file.
  if (fes.fileno >= 0 && fes.symnum >= 0) {
    CopyToOutput(fes);
    SaveOutput((char*)"flink_out.elf");
  }
//  compress_exi(argv[1], true);
}

// Run program: Ctrl + F5 or Debug > Start Without Debugging menu
// Debug program: F5 or Debug > Start Debugging menu

// Tips for Getting Started: 
//   1. Use the Solution Explorer window to add/manage files
//   2. Use the Team Explorer window to connect to source control
//   3. Use the Output window to see build output and other messages
//   4. Use the Error List window to view errors
//   5. Go to Project > Add New Item to create new code files, or Project > Add Existing Item to add existing code files to the project
//   6. In the future, to open this project again, go to File > Open > Project and select the .sln file
