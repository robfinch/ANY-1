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
#include "stdafx.h"

extern FILE *ofp;
extern int pass;
extern bool keepUnreferenced;
int numsym = 0;
SYM* current_symbol;
NameTable gfnTable(100000);

void ShellSort(void *, int, int, int (*)());   // Does a shellsort - like bsort()
SHashVal HashFnc(void *def);
int icmp (const void *n1, const void *n2);
int ncmp (char *n1, const void *n2);
SHashTbl HashInfo = { HashFnc, icmp, ncmp, 0, sizeof(SYM), NULL };

char *GetName(int ndx)
{
	return (nmTable.GetName(ndx));
}

char* GetShName(int ndx)
{
  return (shnmTable.GetName(ndx));
}

SHashVal HashFnc(void *d)
{
   SYM *def = (SYM *)d;
   return htSymHash(&HashInfo, &nmTable.nametext[def->name]);
}

int icmp (const void *m1, const void *m2)
{
  SYM *n1; SYM *n2;
  n1 = (SYM *)m1;
  n2 = (SYM *)m2;
	if (n1->name==0) return 1;
	if (n2->name==0) return -1;
  return (strcmp(&nmTable.nametext[n1->name], &nmTable.nametext[n2->name]));
}

int ncmp (char *m1, const void *m2)
{
  SYM *n2;
  n2 = (SYM *)m2;
	//if (m1==NULL) return 1;
	//if (n2->name==NULL) return -1;
  return (strcmp(m1, &nmTable.nametext[n2->name]));
}

int libcmp(const void* m1, const void* m2)
{
  SYM* n1; SYM* n2;
  n1 = (SYM*)m1;
  n2 = (SYM*)m2;
  if (n1->libcallno < n2->libcallno) return -1;
  if (n1->libcallno > n2->libcallno) return 1;
  return (0);
}

void SymbolInit()
{
   HashInfo.size = 100000;
   HashInfo.width = sizeof(SYM);
   if ((HashInfo.table = calloc(HashInfo.size, sizeof(SYM))) == NULL) {
      exit (1);
   }
}

// Pack any 'holes' in the table

int PackSymbols(int end)
{
  int ii, blnk, count;
  SYM* dp, * pt;

  pt = (SYM*)HashInfo.table;

  for (blnk = ii = count = 0; count < end; count++, ii++) {
    dp = &pt[ii];
    if (dp->name) {
      if (blnk > 0) {
        memmove(&pt[ii - blnk], &pt[ii], (HashInfo.size - count) * sizeof(SYM));
      }
      ii -= blnk;
      blnk = 0;
    }
    else
      blnk++;
  }
  memset(&pt[ii], 0, (HashInfo.size - ii) *sizeof(SYM));
  return (ii);
}

void SymbolInitForPass()
{
  int ii;
  SYM* dp, * pt;

  pt = (SYM*)HashInfo.table;
  for (ii = 0; ii < HashInfo.size; ii++) {
    dp = &pt[ii];
    dp->referenceCount = 0;
  }
}

void RemoveUnreferenced(int count)
{
  int ii, jj;
  int nn;
  char* p;
  SYM* dp, * pt, *qt;

  pt = (SYM*)HashInfo.table;

  for (ii = 0; ii < count; ii++) {
    dp = &pt[ii];
    if (dp->referenceCount == 0) {
      // Remove any symbols that match the root name.
      for (jj = 0; jj < count; jj++) {
        qt = &pt[jj];
        if (qt->parent == dp->ord) {
          memset(qt, 0, HashInfo.width);
        }
      }
      memset(dp, 0, HashInfo.width);
    }
  }
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

char *segname(int seg)
{
  switch(seg) {
  case codeseg: return "code";
  case dataseg: return "data";
  case bssseg: return "bss";
  case tlsseg: return "tls";
  case rodataseg: return "rodata";
  case constseg: return "const";
  default: return "???";
  }
}

// ----------------------------------------------------------------------------
// Do a binary search to find the symbol.
// ----------------------------------------------------------------------------

SYM *find_symbol(char *name)
{
  SYM *p;
    
  p = (SYM *)htFind2(&HashInfo, name);
  return p;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

SYM *insert_symbol(SYM *sym)
{
  SYM *p;

  if (!(p=(SYM *)htInsert(&HashInfo, sym)))
      printf("failed to insert symbol\r\n");
  if (p)
      p->ord = p-(SYM *)(HashInfo.table);
  return p;
}


// ----------------------------------------------------------------------------
// When the symbol is first setup we force the value to be a large one in
// order to force the assembler to generate a maximum size prefix in case the
// symbol ends up being unresolved.
// ----------------------------------------------------------------------------

SYM *new_symbol(char *name)
{
  SYM *p;
  SYM ts;

  if (p = find_symbol(name)) {
    printf("Symbol already in table.\r\n");
    return p;
  }
  if (numsym > 65525) {
    printf("Too many symbols.\r\n");
    return (SYM *)NULL;
  }
  if (pass > 5) {
    //printf("%s: added\r\n", name);
  }
  ts.name = nmTable.AddName(name);
  ts.gfnName = 0;
//     strncpy(syms[numsym].name, name, sizeof(syms[numsym].name)/sizeof(char)-1);
//     syms[numsym].name[199] = '\0';
//	ts.value.low = 0x8000000000000000LL | numsym;
  ts.value.low = sections[segment].start + numsym;
	ts.value.high = 0; 
  ts.alignment = 1;
  ts.isDefined = 0;
  ts.segment = segment;
  ts.isGlobal = 0;
  ts.isExtern = 0;
	ts.isMacro = false;
	ts.hasPhaseErr = 0;
	ts.addressBits = 32;
  ts.size = 0;
  ts.referenceCount = 0;
  p = insert_symbol(&ts);
  numsym++;
  return p;
}


int GetSymNdx(SYM *sp)
{
	return (sp - (SYM*)HashInfo.table);
}

SYM *GetSymByIndex(int n)
{
	SYM *pt;
	pt = (SYM *)HashInfo.table;
	return (&pt[n]);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void DumpSymbols()
{
    int nn,ii,blnk;
    SYM *dp, *pt;

   pt = (SYM *)HashInfo.table;

   // Pack any 'holes' in the table
   ii = PackSymbols(HashInfo.size);
   if (!keepUnreferenced)
    RemoveUnreferenced(ii);
   ii = PackSymbols(ii);

   // Sort the table
   qsort(pt, ii, sizeof(SYM), icmp);

    
    fprintf(ofp, "%d symbols\n", numsym);
    fprintf(ofp, "  Symbol Name                              seg     address size bits references\n"); 
    for (nn = 0; nn < ii; nn++) {
//        qq = symorder[nn];
        dp = &pt[nn];
        if (dp->name && !dp->isMacro) {
          if (gCpu==ANY1V3)
            fprintf(ofp, "%c %-40s %6s  %06I64x.%1x %4llu %d %d\n", dp->hasPhaseErr ? '*' : ' ', nmTable.GetName(dp->name), segname(dp->segment), dp->value.low >> 1, (int)dp->value.low & 1, dp->size, dp->addressBits, dp->referenceCount);
          else
            fprintf(ofp, "%c %-40s %6s  %06I64x %4llu %d %d\n", dp->hasPhaseErr ? '*' : ' ', nmTable.GetName(dp->name), segname(dp->segment), (int)dp->value.low, dp->size, dp->addressBits, dp->referenceCount);
        }
    }
		fprintf(ofp, "\nUndefined Symbols\n");
		for (nn = 0; nn < ii; nn++) {
			dp = &pt[nn];
			if (dp->name && !dp->isMacro && dp->isDefined == false)
				fprintf(ofp, "%c %-40s %6s  %06I64x %d %d\n", dp->hasPhaseErr ? '*' : ' ', nmTable.GetName(dp->name), segname(dp->segment), dp->value.low, dp->addressBits, dp->referenceCount);
		}
		fprintf(ofp, "\n  Macro Name\n");
		for (nn = 0; nn < ii; nn++) {
			dp = &pt[nn];
			if (dp->name && dp->isMacro) {
				fprintf(ofp, " %-40s  %d\n", nmTable.GetName(dp->name), dp->macro->parms.count);
				fprintf(ofp, "%s", dp->macro->body);
				fprintf(ofp, "\n");
			}
		}
}

void DumpLibcallTable()
{
  int nn, ii, blnk, kk;
  SYM* dp, * pt;

  pt = (SYM*)HashInfo.table;

  // Pack any 'holes' in the table
  ii = PackSymbols(HashInfo.size);
  if (!keepUnreferenced)
    RemoveUnreferenced(ii);
  ii = PackSymbols(ii);

  // Sort the table
  qsort(pt, ii, sizeof(SYM), libcmp);

  for (kk = nn = 0; nn < ii; nn++) {
    dp = &pt[nn];
    if (dp->name && dp->isFunc && dp->isGlobal && dp->isLibcall) {
      for (; kk < dp->libcallno; kk++)
        emitWyde(0);
      emitWyde(dp->value.low >> 5);
    }
  }
}

void DumpSymtab()
{
  int nn, ii, blnk, kk, nm;
  SYM* dp, * pt;

  pt = (SYM*)HashInfo.table;
  ii = HashInfo.size;

  for (kk = nn = 0; nn < ii; nn++) {
    dp = &pt[nn];
    if (dp->name && dp->isGlobal && dp->isFunc) {
      kk++;
    }
  }
  emitWyde(kk);
  for (nn = 0; nn < ii; nn++) {
    dp = &pt[nn];
    if (dp->name && dp->isGlobal && dp->isFunc) {
      if (dp->gfnName == 0) {
        nm = gfnTable.AddName(nmTable.GetName(dp->name));
        dp->gfnName = nm;
      }
      else
        nm = dp->gfnName;
      emitWyde(nm);
      emitWyde(dp->value.low >> 5);
    }
  }
  emitWyde(0);
  emitWyde(0);
  for (nn = 0; nn < gfnTable.length; nn++)
    emitByte(gfnTable.nametext[nn]);
}
