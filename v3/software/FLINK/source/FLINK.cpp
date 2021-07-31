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

enum {
  codeseg = 0,
  rodataseg = 1,
  dataseg = 2,
  bssseg = 3,
  tlsseg = 4,
  stackseg = 5,
  constseg = 6,
};

#define I_EXI0	0x50
#define I_EXI1	0x51
#define I_EXI2	0x52

#define ZeroMemory(a,b) memset((a),0,(b))

uint64_t baseaddr;
uint64_t entry_pt;
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

uint64_t Round512(uint64_t n)
{
  n += 511;
  n &= 0xfffffffffffffe00LL;
  return (n);
}

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
  if (strncmp(option, "BASE:", 5) == 0) {
    baseaddr = strtoull(&option[5], nullptr, 16);
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
  et = elf_fileo.sections[codeseg]->hdr.sh_size;
  sec = elf_files[efes.fileno]->sections[textsec];
  memcpy(
    &elf_fileo.sections[codeseg]->bytes[et],
    &sec->bytes[0],
    elf_files[efes.fileno]->sections[textsec]->hdr.sh_size
  );
  et += elf_files[efes.fileno]->sections[textsec]->hdr.sh_size;
  elf_fileo.sections[textsec]->hdr.sh_size = et;
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

void CopyToCodeSection(clsElf64Section* dst, clsElf64Section* src, uint64_t offset, uint64_t size)
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

int symvalcmp(const void* a, const void* b)
{
  Elf64Symbol* aa = (Elf64Symbol*)a;
  Elf64Symbol* bb = (Elf64Symbol*)b;
  uint64_t va = aa->st_value;
  uint64_t vb = bb->st_value;

  if (va < vb)
    return (-1);
  if (va == vb)
    return (0);
  return (1);
}

// All the symbol names were copied to a global table by AccumulateSymbols()
// and the name indexes reset to point into that table.

char* GetName(Elf64Symbol* a, int opt)
{
  int secs;
  char* p;
  static int last_file = -1;
  static clsElf64Section* last_sec;

  if (opt) {
    p = &nametext[a->st_name];
    return (p);
  }

  // Do fast lookup if within same file
  if (last_file == a->st_other) {
    p = (char*)&last_sec->bytes[a->st_name];
    return (p);
  }
  // Do slow lookup
  if ((unsigned)a->st_other >= file_count)
    return ((char *)"<bad fileno>");
  last_file = a->st_other;
  for (secs = 0; secs < elf_files[a->st_other]->hdr.e_shnum; secs++) {
    if (elf_files[a->st_other]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_STRTAB) {
      last_sec = elf_files[a->st_other]->sections[secs];
      p = (char *)&last_sec->bytes[a->st_name];
      return (p);
    }
  }
  last_file = -1;
}

int symcmp(const void* a, const void* b)
{
  Elf64Symbol* aa = (Elf64Symbol*)a;
  Elf64Symbol* bb = (Elf64Symbol*)b;
  if (aa->st_info < bb->st_info)
    return (-1);
  if (aa->st_info > bb->st_info)
    return (1);
  return (strcmp(GetName(aa,1), GetName(bb,1)));
}

int symnamecmp(const void* a, const void* b)
{
  Elf64Symbol* aa = (Elf64Symbol*)a;
  Elf64Symbol* bb = (Elf64Symbol*)b;
  return (strcmp(GetName(aa,1), GetName(bb,1)));
}

void DumpSymbols(clsElf64Section* sec, int opt)
{
  int nn;
  Elf64Symbol* sym;

  printf("\r\n\r\n");
  printf("Name             Info File Section   Value   Size\r\n");
  for (nn = 0; nn < sec->hdr.sh_size; nn += sec->hdr.sh_entsize) {
    sym = (Elf64Symbol*)&sec->bytes[nn];
    if (opt)
      printf("%8d  %02x  %2d   %2d    %08llx %lld\r\n",
        sym->st_name, sym->st_info, sym->st_other, sym->st_shndx,
        sym->st_value, sym->st_size
      );
    else
      printf("%-32.32s  %02x  %2d   %2d    %08llx %lld\r\n",
        GetName(sym,1), sym->st_info, sym->st_other, sym->st_shndx,
        sym->st_value, sym->st_size
      );
  }
  printf("%d symbols\r\n", sec->hdr.sh_size / sec->hdr.sh_entsize);
}

bool IsGlobalFunc(Elf64Symbol* s)
{
  return ((s->st_info >> 4) == STB_GLOBAL && (s->st_info & 15) == STT_FUNC);
}

bool IsFunc(Elf64Symbol* s)
{
  return ((s->st_info & 15) == STT_FUNC);
}

// Get all the symbols, remove duplicate references.

void AccumulateSymbols()
{
  int secs;
  int symtabsec = -1;
  clsElf64Section* sec, * newsec;
  Elf64Symbol* sym, * a, * b;
  int nn, kk, fc;

  // Allocate section to hold symbols
  newsec = new clsElf64Section;
  newsec->Clear();
  ZeroMemory(newsec->bytes, sizeof(newsec->bytes));

  // Iterate across all files
  for (fc = 0; fc < file_count; fc++) {
    for (secs = 0; secs < elf_files[fc]->hdr.e_shnum; secs++) {
      if (elf_files[fc]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_SYMTAB) {
        sec = elf_files[fc]->sections[secs];
        for (nn = 0; nn < sec->hdr.sh_size; nn += sec->hdr.sh_entsize) {
          sym = (Elf64Symbol*)&sec->bytes[nn];
          if (sym->st_name) {
            sym->st_other = fc;
            sym->st_name = nmTable.AddName(GetName(sym,0));
            newsec->Add(sym);
          }
        }
      }
    }
  }
  ZeroMemory(&newsec->hdr, sizeof(newsec->hdr));
  newsec->hdr.sh_name = nmTable.AddName((char*)".symtab");
  newsec->hdr.sh_addr = 0;
  newsec->hdr.sh_type = clsElf64Shdr::SHT_SYMTAB;
  newsec->hdr.sh_entsize = sizeof(Elf64Symbol);
  newsec->hdr.sh_size = newsec->index;
  newsec->hdr.sh_offset = Round512(512 + elf_fileo.sections[0]->index + elf_fileo.sections[1]->index + elf_fileo.sections[2]->index) + nmTable.length; // offset in file
  newsec->hdr.sh_link = 5;
  newsec->hdr.sh_addralign = 1;
  DumpSymbols(newsec, 1);

  // Remove duplicate symbols which may be caused by extern declarations.
  qsort(&newsec->bytes[0], newsec->hdr.sh_size / newsec->hdr.sh_entsize, newsec->hdr.sh_entsize, symcmp);
  for (nn = 0; nn < newsec->hdr.sh_size; nn += newsec->hdr.sh_entsize) {
    a = (Elf64Symbol*)&newsec->bytes[nn];
    for (kk = newsec->hdr.sh_entsize; 1; kk += newsec->hdr.sh_entsize) {
      b = (Elf64Symbol*)&newsec->bytes[nn + kk];
      if (strcmp(GetName(a,1), GetName(b,1)) == 0) {
        if (IsGlobalFunc(a) && IsGlobalFunc(b)) {
          if (b->st_size <= 0) {
            b->st_info = 255; // mark for deletion
          }
        }
      }
      else
        break;
    }
  }
  for (kk = nn = 0; nn < newsec->hdr.sh_size; nn += newsec->hdr.sh_entsize) {
    a = (Elf64Symbol*)&newsec->bytes[nn];
    b = (Elf64Symbol*)&newsec->bytes[kk];
    memcpy(b, a, newsec->hdr.sh_entsize);
    if (a->st_info != 255)
      kk += newsec->hdr.sh_entsize;
  }
  newsec->hdr.sh_size = kk;
  elf_fileo.AddSection(newsec);
  DumpSymbols(newsec, 0);
}

// Copy a function from one of the input files to the output file.
// The function address may change.

void CopyFuncToOutput(Elf64Symbol* sym)
{
  int secs;
  int textsec = -1;
  clsElf64Section* sec;
  int byt;
  uint64_t offs, nn;
  uint64_t newval;
  char* nm;

  // Find the text section
  for (secs = 0; secs < elf_fileo.hdr.e_shnum; secs++) {
    if (elf_fileo.sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_PROGBITS) {
      textsec = secs;
      break;
    }
  }
  if (textsec < 0)
    return;
  sec = elf_fileo.sections[textsec];
  sec->index = sec->hdr.sh_size;
  // 16 byte align
  while ((sec->index & 31LL) != 0)
    sec->AddNybble(0LL);
  newval = sec->hdr.sh_addr + (sec->index << 1LL);
  // Should be in text section
  if (sym->st_shndx != 0)
    return;
  nm = GetName(sym, 0);
  if ((uint64_t)sym->st_value < (uint64_t)elf_files[sym->st_other]->sections[sym->st_shndx]->hdr.sh_addr)
    return;
  offs = (sym->st_value - elf_files[sym->st_other]->sections[sym->st_shndx]->hdr.sh_addr) >> 1LL;
  for (nn = 0; nn < (sym->st_size + 1) >> 1LL; nn++) {
    byt = elf_files[sym->st_other]->sections[sym->st_shndx]->bytes[offs+nn];
    sec->AddByte(byt);
  }
  sym->st_value = newval;
  sym->st_info &= 0x0f; // mark as local so it does not get copied again
  sec->hdr.sh_size = sec->index;
}

Elf64Symbol* FindSymbol(Elf64Symbol* s)
{
  clsElf64Section* sec;
  Elf64Symbol* sym, *a;
  int nn;

  sec = elf_fileo.sections[6];
  for (nn = 0; nn < sec->hdr.sh_size; nn += sec->hdr.sh_entsize) {
    sym = (Elf64Symbol*)&sec->bytes[nn];
    if (symcmp(s, sym) == 0)
      return (sym);
  }
  //sym = (Elf64Symbol*)bsearch(s, &sec->bytes[0], sec->hdr.sh_size / sec->hdr.sh_entsize, sec->hdr.sh_entsize, symcmp);
  //return (sym);
}

void CopySymsToOutput(FS fs)
{
  int symtabsec = -1;
  int secs;
  clsElf64Section* sec;
  Elf64Symbol* symtab, * sym, *s;
  int nn;
  FS fss;

  // Find the symbol table
  for (secs = 0; secs < elf_files[fs.fileno]->hdr.e_shnum; secs++) {
    if (elf_files[fs.fileno]->sections[secs]->hdr.sh_type == clsElf64Shdr::SHT_SYMTAB) {
      symtabsec = secs;
      break;
    }
  }
  if (symtabsec < 0)
    return;
  sec = elf_files[fs.fileno]->sections[symtabsec];
  symtab = (Elf64Symbol*)&sec->bytes[0];
  DumpSymbols(sec, 0);

  // Sort the symbols by value so they end up in the same order in the output
  // file as was specified in the input files.
  qsort(
    symtab,
    sec->hdr.sh_size / sec->hdr.sh_entsize,
    sec->hdr.sh_entsize,
    symvalcmp
  );
  DumpSymbols(sec, 0);

  // Grab each symbol in the input file and find the corresponding symbol in
  // the output file. Copy functions from input to output.
  for (nn = 0; nn < sec->hdr.sh_size; nn += sec->hdr.sh_entsize) {
    s = (Elf64Symbol*)&sec->bytes[nn];
    // Find symbol in output file symbol table.
    sym = FindSymbol(s);
    if (sym != nullptr) {
      if (IsFunc(sym)) {
        CopyFuncToOutput(s);
        sym->st_value = s->st_value;
        sym->st_info = s->st_info;
      }
    }
  }
  // Now copy all the symbols symbols to output
  /*
  for (nn = 0; nn < sec->hdr.sh_size; nn += sec->hdr.sh_entsize) {
    s = (Elf64Symbol*)&sec->bytes[nn];
    // Find symbol in output file symbols table.
    sym = FindSymbol(s);
    if (sym != nullptr) {
      fss.fileno = sym->st_other;
      fss.name = GetName(sym);
      fss.sym = sym;
      fss.symnum = 0;
      CopySymsToOutput(fss);
    }
  }
  */
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
    symvalcmp
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
  textsec->Clear();
  textsec->hdr.sh_name = nmTable.AddName((char *)".text");
  textsec->hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
  textsec->hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_EXECINSTR;
  textsec->hdr.sh_addr = rel_out ? 0 : baseaddr;// textsec->start;
  textsec->hdr.sh_offset = 512;  // offset in file
  textsec->hdr.sh_size = textsec->index;
  textsec->hdr.sh_link = 0;
  textsec->hdr.sh_info = 0;
  textsec->hdr.sh_addralign = 16;
  textsec->hdr.sh_entsize = 0;
  elf_fileo.AddSection(textsec);
}

void AddRodatasec()
{
  clsElf64Section* rodatasec;

  rodatasec = new clsAny1elfSection();
  rodatasec->hdr.sh_name = nmTable.AddName((char *)".rodata");
  rodatasec->hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
  rodatasec->hdr.sh_flags = clsElf64Shdr::SHF_ALLOC;
  rodatasec->hdr.sh_addr = elf_fileo.sections[0]->hdr.sh_addr + elf_fileo.sections[0]->index;
  rodatasec->hdr.sh_offset = elf_fileo.sections[0]->hdr.sh_offset + elf_fileo.sections[0]->index; // offset in file
  rodatasec->hdr.sh_size = rodatasec->index;
  rodatasec->hdr.sh_link = 0;
  rodatasec->hdr.sh_info = 0;
  rodatasec->hdr.sh_addralign = 8;
  rodatasec->hdr.sh_entsize = 0;
  elf_fileo.AddSection(rodatasec);
}

void AddDatasec()
{
  clsElf64Section* datasec;

  datasec = new clsAny1elfSection();
  datasec->hdr.sh_name = nmTable.AddName((char*)".data");
  datasec->hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
  datasec->hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_WRITE;
  datasec->hdr.sh_addr = elf_fileo.sections[1]->hdr.sh_addr + elf_fileo.sections[1]->index;
  datasec->hdr.sh_offset = elf_fileo.sections[1]->hdr.sh_offset + elf_fileo.sections[1]->index; // offset in file
  datasec->hdr.sh_size = datasec->index;
  datasec->hdr.sh_link = 0;
  datasec->hdr.sh_info = 0;
  datasec->hdr.sh_addralign = 8;
  datasec->hdr.sh_entsize = 0;
  elf_fileo.AddSection(datasec);
}

void AddBsssec()
{
  clsElf64Section* bsssec;

  bsssec = new clsAny1elfSection();
  bsssec->hdr.sh_name = nmTable.AddName((char *)".bss");
  bsssec->hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
  bsssec->hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_WRITE;
  bsssec->hdr.sh_addr = elf_fileo.sections[2]->hdr.sh_addr + elf_fileo.sections[2]->index;
  bsssec->hdr.sh_offset = elf_fileo.sections[2]->hdr.sh_offset + elf_fileo.sections[2]->index; // offset in file
  bsssec->hdr.sh_size = 0;
  bsssec->hdr.sh_link = 0;
  bsssec->hdr.sh_info = 0;
  bsssec->hdr.sh_addralign = 8;
  bsssec->hdr.sh_entsize = 0;
  elf_fileo.AddSection(bsssec);
}

void AddTlssec()
{
  clsElf64Section* tlssec;

  tlssec = new clsAny1elfSection();
  tlssec->hdr.sh_name = nmTable.AddName((char *)".tls");
  tlssec->hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
  tlssec->hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_WRITE;
  tlssec->hdr.sh_addr = elf_fileo.sections[3]->hdr.sh_addr + elf_fileo.sections[3]->index;;
  tlssec->hdr.sh_offset = elf_fileo.sections[2]->hdr.sh_offset + elf_fileo.sections[2]->index; // offset in file
  tlssec->hdr.sh_size = 0;
  tlssec->hdr.sh_link = 0;
  tlssec->hdr.sh_info = 0;
  tlssec->hdr.sh_addralign = 8;
  tlssec->hdr.sh_entsize = 0;
  elf_fileo.AddSection(tlssec);
}

void AddStrtabsec()
{
  clsElf64Section* strsec, *sec;

  strsec = new clsAny1elfSection();
  elf_fileo.AddSection(strsec);
  AccumulateSymbols();
  sec = new clsAny1elfSection();
  sec->hdr.sh_name = nmTable.AddName((char *)".reltext"); // section 7
  elf_fileo.AddSection(sec);
  sec = new clsAny1elfSection();
  sec->hdr.sh_name = nmTable.AddName((char*)".relrodata");
  elf_fileo.AddSection(sec);
  sec = new clsAny1elfSection();
  sec->hdr.sh_name = nmTable.AddName((char*)".reldata");
  elf_fileo.AddSection(sec);
  sec = new clsAny1elfSection();
  sec->hdr.sh_name = nmTable.AddName((char*)".relbss");
  elf_fileo.AddSection(sec);
  sec = new clsAny1elfSection();
  sec->hdr.sh_name = nmTable.AddName((char*)".reltls");
  elf_fileo.AddSection(sec);
  strsec->hdr.sh_name = nmTable.AddName((char*)".strtab");
  strsec->hdr.sh_type = clsElf64Shdr::SHT_STRTAB;
  strsec->hdr.sh_flags = 0;
  strsec->hdr.sh_addr = 0;
  strsec->hdr.sh_offset = 512 + elf_fileo.sections[0]->index + elf_fileo.sections[1]->index + elf_fileo.sections[2]->index; // offset in file
  strsec->hdr.sh_size = nmTable.length;
  strsec->hdr.sh_link = 0;
  strsec->hdr.sh_info = 0;
  strsec->hdr.sh_addralign = 1;
  strsec->hdr.sh_entsize = 0;
  memcpy(elf_fileo.sections[5]->bytes, nametext, nmTable.length);
}

void InitRelsec()
{
  int nn;

  for (nn = 7; nn < 12; nn++) {
    elf_fileo.sections[nn]->hdr.sh_type = clsElf64Shdr::SHT_REL;
    elf_fileo.sections[nn]->hdr.sh_flags = 0;
    elf_fileo.sections[nn]->hdr.sh_addr = 0;
    elf_fileo.sections[nn]->hdr.sh_offset = elf_fileo.sections[nn - 1]->hdr.sh_offset + elf_fileo.sections[nn - 1]->hdr.sh_size; // offset in file
    elf_fileo.sections[nn]->hdr.sh_size = elf_fileo.sections[nn]->index;
    elf_fileo.sections[nn]->hdr.sh_link = 6;
    elf_fileo.sections[nn]->hdr.sh_info = 0;
    elf_fileo.sections[nn]->hdr.sh_addralign = 1;
    elf_fileo.sections[nn]->hdr.sh_entsize = 16;
  }
}


void SetHdr()
{
  uint64_t start;

  elf_fileo.hdr.e_ident[0] = 127;
  elf_fileo.hdr.e_ident[1] = 'E';
  elf_fileo.hdr.e_ident[2] = 'L';
  elf_fileo.hdr.e_ident[3] = 'F';
  elf_fileo.hdr.e_ident[4] = clsElf64Header::ELFCLASS64;   // 64 bit file format
  elf_fileo.hdr.e_ident[5] = clsElf64Header::ELFDATA2LSB;  // little endian
  elf_fileo.hdr.e_ident[6] = 1;        // header version always 1
  elf_fileo.hdr.e_ident[7] = 255;      // OS/ABI indentification, 255 = standalone
  elf_fileo.hdr.e_ident[8] = 255;      // ABI version
  elf_fileo.hdr.e_ident[9] = 0;
  elf_fileo.hdr.e_ident[10] = 0;
  elf_fileo.hdr.e_ident[11] = 0;
  elf_fileo.hdr.e_ident[12] = 0;
  elf_fileo.hdr.e_ident[13] = 0;
  elf_fileo.hdr.e_ident[14] = 0;
  elf_fileo.hdr.e_ident[15] = 0;
  elf_fileo.hdr.e_type = rel_out ? 1 : 2;
  elf_fileo.hdr.e_machine = 888;         // machine architecture
  elf_fileo.hdr.e_version = 1;
  elf_fileo.hdr.e_entry = entry_pt;
  elf_fileo.hdr.e_phoff = 0;
  elf_fileo.hdr.e_shoff = elf_fileo.sections[11]->hdr.sh_offset + elf_fileo.sections[11]->index;
  elf_fileo.hdr.e_flags = 0;
  elf_fileo.hdr.e_ehsize = Elf64HdrSz;
  elf_fileo.hdr.e_phentsize = 0;
  elf_fileo.hdr.e_phnum = 0;
  elf_fileo.hdr.e_shentsize = Elf64ShdrSz;
  elf_fileo.hdr.e_shstrndx = 5;           // index into section table of string table header
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
  FS fes;

  if (argc < 2) {
    exit(0);
  }
  baseaddr = 0;
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
  fes = FindEntrySymbol();
  entry_pt = fes.sym->st_value;
  elf_fileo.hdr.e_shnum = 0;  // This will be incremented by AddSection()
  AddTextsec();
  AddRodatasec();
  AddDatasec();
  AddBsssec();
  AddTlssec();
  AddStrtabsec();
  InitRelsec();
  SetHdr();
  // The file containing the entry symbol is the root file.
  if (fes.fileno >= 0 && fes.symnum >= 0) {
    CopySymsToOutput(fes);
    //CopyToOutput(fes);
    // Lookup all symbols in root file and copy to output.
    // Set offset of string table.
    elf_fileo.sections[5]->hdr.sh_offset = 512 + elf_fileo.sections[0]->index + elf_fileo.sections[1]->index + elf_fileo.sections[2]->index; // offset in file

    SaveOutput((char*)"flink_out.elf");
  }
//  compress_exi(argv[1], true);
}
