// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// CC64 - 'C' derived language compiler
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

extern TYP              stdfunc;

extern void DumpCSETable();
extern void scan(Statement *);
extern void GenerateComment(char *);
int TempFPInvalidate();
int TempInvalidate();
void TempRevalidate(int,int);
void TempFPRevalidate(int);
void ReleaseTempRegister(Operand *ap);
Operand *GetTempRegister();
extern void GenLoad(Operand *ap1, Operand *ap3, int ssize, int size);

void ANY1CodeGenerator::SignExtendBitfield(Operand* ap3, uint64_t mask)
{
	Operand* ap2;
	uint64_t umask;

	umask = 0x8000000000000000LL | ~(mask >> 1);
	ap2 = GetTempRegister();
	GenerateDiadic(op_ldi, 0, ap2, cg.MakeImmediate((int64_t)umask));
	GenerateTriadic(op_add, 0, ap3, ap3, ap2);
	GenerateTriadic(op_xor, 0, ap3, ap3, ap2);
	ReleaseTempRegister(ap2);
}

// Convert a value to a Boolean.
Operand* ANY1CodeGenerator::MakeBoolean(Operand* ap)
{
	Operand* ap1;
	OCODE* ip;

	ap1 = GetTempRegister();
	ip = currentFn->pl.tail;
	if (ip->opcode & 0x8000)
		return (ap1);
	GenerateTriadic(op_sne, 0, ap1, ap, makereg(regZero));
	ap1->isBool = true;
	return (ap1);
}

void ANY1CodeGenerator::GenerateLea(Operand* ap1, Operand* ap2)
{
	switch (ap2->mode) {
	case am_reg:
		GenerateDiadic(op_mov, 0, ap1, ap2);
		break;
	default:
		GenerateDiadic(op_lea, 0, ap1, ap2);
	}
}

Operand* ANY1CodeGenerator::GenerateSafeLand(ENODE *node, int flags, int op)
{
	Operand* ap1, * ap2, * ap4, * ap5;
	int lab0;
	OCODE* ip;

	lab0 = nextlabel++;

	ap1 = GenerateExpression(node->p[0], am_reg|am_creg, node->p[0]->GetNaturalSize());
	ap2 = GenerateExpression(node->p[1], am_reg|am_creg, node->p[1]->GetNaturalSize());

	if (!ap1->isBool)
		ap4 = MakeBoolean(ap1);
	else
		ap4 = ap1;

	if (!ap2->isBool)
		ap5 = MakeBoolean(ap2);
	else
		ap5 = ap2;

	GenerateTriadic(op_and, 0, ap4, ap4, ap5);
	ReleaseTempReg(ap2);
	//ap2->MakeLegal(flags, sizeOfWord);
	ap1->isBool = true;
	return (ap1);
}


void ANY1CodeGenerator::GenerateBitfieldInsert(Operand* ap1, Operand* ap2, int offset, int width)
{
	int nn;
	uint64_t mask;

	if (cpu.SupportsBitfield) {
		ap1->MakeLegal(am_reg, sizeOfWord);
		ap2->MakeLegal(am_reg, sizeOfWord);
		Generate4adic(op_dep, 0, ap1, ap2, MakeImmediate(offset), MakeImmediate((int64_t)width - 1));
		return;
	}
	for (mask = nn = 0; nn < width; nn++)
		mask = (mask << 1) | 1;
	mask = ~mask;
	GenerateTriadic(op_and, 0, ap2, ap2, MakeImmediate((int64_t)~mask));		// clear unwanted bits in source
	if (offset > 0)
		GenerateTriadic(op_ror, 0, ap1, ap1, MakeImmediate((int64_t)offset));
	GenerateTriadic(op_and, 0, ap1, ap1, MakeImmediate(mask));		// clear bits in target field
	GenerateTriadic(op_or, 0, ap1, ap1, ap2);
	if (offset > 0)
		GenerateTriadic(op_rol, 0, ap1, ap1, MakeImmediate((int64_t)offset));
}


void ANY1CodeGenerator::GenerateBitfieldInsert(Operand* ap1, Operand* ap2, Operand* offset, Operand* width)
{
	int nn;
	uint64_t mask;

	if (cpu.SupportsBitfield) {
		ap1->MakeLegal(am_reg, sizeOfWord);
		ap2->MakeLegal(am_reg, sizeOfWord);
		Generate4adic(op_dep, 0, ap1, ap2, offset, width);
		return;
	}
	for (mask = nn = 0; nn < width->offset->i; nn++)
		mask = (mask << 1) | 1;
	mask = ~mask;
	GenerateTriadic(op_and, 0, ap2, ap2, MakeImmediate((int64_t)~mask));		// clear unwanted bits in source
	GenerateTriadic(op_ror, 0, ap1, ap1, offset);
	GenerateTriadic(op_and, 0, ap1, ap1, MakeImmediate(mask));		// clear bits in target field
	GenerateTriadic(op_or, 0, ap1, ap1, ap2);
	GenerateTriadic(op_rol, 0, ap1, ap1, offset);
}


void ANY1CodeGenerator::GenerateBitfieldInsert(Operand* ap1, Operand* ap2, ENODE* offset, ENODE* width)
{
	int nn;
	uint64_t mask;
	Operand* ap3, * ap4;
	OCODE* ip;

	if (cpu.SupportsBitfield) {
		ap1->MakeLegal(am_reg, sizeOfWord);
		ap2->MakeLegal(am_reg, sizeOfWord);
		ip = currentFn->pl.tail;
		// Try and get immediate operands for both offset and width
		ap3 = GenerateExpression(offset, am_reg | am_imm | am_imm0, sizeOfWord);
		ap4 = GenerateExpression(width, am_reg | am_imm | am_imm0, sizeOfWord);
		if (ap3->mode != ap4->mode) {
			ReleaseTempReg(ap4);
			ReleaseTempReg(ap3);
			currentFn->pl.tail = ip;
			ap3 = GenerateExpression(offset, am_reg, sizeOfWord);
			ap4 = GenerateExpression(width, am_reg, sizeOfWord);
		}
		Generate4adic(op_dep, 0, ap1, ap2, ap3, ap4);
		ReleaseTempReg(ap4);
		ReleaseTempReg(ap3);
		return;
	}
	
	ap3 = GenerateExpression(offset, am_reg | am_imm | am_imm0, sizeOfWord);
	ap4 = GenerateExpression(width, am_reg | am_imm | am_imm0, sizeOfWord);
	for (mask = nn = 0; nn < ap4->offset->i; nn++)
		mask = (mask << 1) | 1;
	mask = ~mask;
	GenerateTriadic(op_and, 0, ap2, ap2, MakeImmediate((int64_t)~mask));		// clear unwanted bits in source
	GenerateTriadic(op_ror, 0, ap1, ap1, ap3);
	GenerateTriadic(op_and, 0, ap1, ap1, MakeImmediate(mask));		// clear bits in target field
	GenerateTriadic(op_or, 0, ap1, ap1, ap2);
	GenerateTriadic(op_rol, 0, ap1, ap1, ap3);
	ReleaseTempReg(ap4);
	ReleaseTempReg(ap3);
}


Operand* ANY1CodeGenerator::GenerateBitfieldExtract(Operand* ap, Operand* offset, Operand* width)
{
	Operand* ap1;

	ap1 = GetTempRegister();
	if (cpu.SupportsBitfield) {
		if (isSigned)
			Generate4adic(op_ext, 0, ap1, ap, offset, width);
		else
			Generate4adic(op_extu, 0, ap1, ap, offset, width);
	}
	else {
		uint64_t mask;
		int bit_offset = offset->offset->i;

		mask = 0;
		while (width-- >= 0)	mask = mask + mask + 1;
		if (bit_offset > 0)
			GenerateTriadic(op_srl, 0, ap1, ap, offset);
		GenerateTriadic(op_and, 0, ap1, ap1, MakeImmediate((int64_t)mask));
		if (isSigned)
			SignExtendBitfield(ap1, mask);
	}
	return (ap1);
}

Operand* ANY1CodeGenerator::GenerateBitfieldExtract(Operand* ap, ENODE* offset, ENODE* width)
{
	Operand* ap1;
	Operand* ap2;
	Operand* ap3;
	OCODE* ip;
	int wd;

	ap1 = GetTempRegister();
	ip = currentFn->pl.tail;
	ap2 = GenerateExpression(offset, am_reg | am_imm | am_imm0, sizeOfWord);
	ap3 = GenerateExpression(width, am_reg | am_imm | am_imm0, sizeOfWord);
	if (ap2->mode != ap3->mode) {
		currentFn->pl.tail = ip;
		ReleaseTempReg(ap3);
		ReleaseTempReg(ap2);
		ap2 = GenerateExpression(offset, am_reg, sizeOfWord);
		ap3 = GenerateExpression(width, am_reg, sizeOfWord);
	}
	if (cpu.SupportsBitfield) {
		if (isSigned)
			Generate4adic(op_ext, 0, ap1, ap, ap2, ap3);
		else
			Generate4adic(op_extu, 0, ap1, ap, ap2, ap3);
	}
	else {
		
		uint64_t mask;

		mask = 0;
		wd = ap3->offset->i;
		while (wd-- >= 0)	mask = mask + mask + 1;
		if (ap2->offset->i > 0)
			GenerateTriadic(op_srl, 0, ap1, ap, ap2);
		GenerateTriadic(op_and, 0, ap1, ap1, MakeImmediate((int64_t)mask));
		if (isSigned)
			SignExtendBitfield(ap1, mask);
		
	}
	ReleaseTempReg(ap3);
	ReleaseTempReg(ap2);
	return (ap1);
}

Operand* ANY1CodeGenerator::GenerateEq(ENODE *node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_seq, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateNe(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_sne, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateLt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_slt, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateLe(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, node->p[1]->GetNaturalSize());
	if (ap2->mode == am_reg)
		GenerateTriadic(op_sgt, 0, ap3, ap2, ap1);
	else
		GenerateTriadic(op_sle, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateGt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, size);
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, size);
	if (ap2->mode == am_reg)
		GenerateTriadic(op_slt, 0, ap3, ap2, ap1);
	else
		GenerateTriadic(op_sgt, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	//		GenerateDiadic(op_sgt,0,ap3,ap3);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateGe(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_sge, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateLtu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_sltu, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateLeu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, node->p[1]->GetNaturalSize());
	if (ap2->mode == am_reg)
		GenerateTriadic(op_sgtu, 0, ap3, ap2, ap1);
	else
		GenerateTriadic(op_sleu, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateGtu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, size);
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, size);
	if (ap2->mode == am_reg)
		GenerateTriadic(op_sltu, 0, ap3, ap2, ap1);
	else
		GenerateTriadic(op_sgtu, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	//		GenerateDiadic(op_sgt,0,ap3,ap3);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateGeu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, size);
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, size);
	GenerateTriadic(op_sgeu, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateFeq(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_fseq, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateFne(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_fsne, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateFlt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_fslt, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateFle(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_fsle, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateFgt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_fslt, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* ANY1CodeGenerator::GenerateFge(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->GetNaturalSize());
	ap2 = cg.GenerateExpression(node->p[1], am_reg, node->p[1]->GetNaturalSize());
	GenerateTriadic(op_fsle, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand *ANY1CodeGenerator::GenExpr(ENODE *node)
{
	Operand *ap1,*ap2,*ap3,*ap4;
	int lab0, lab1;
	int64_t size = sizeOfWord;
	int op;
	OCODE* ip;

    lab0 = nextlabel++;
    lab1 = nextlabel++;

	switch(node->nodetype) {
	case en_eq:		op = op_seq;	break;
	case en_ne:		op = op_sne;	break;
	case en_lt:		op = op_slt;	break;
	case en_ult:	op = op_sltu;	break;
	case en_le:		op = op_sle;	break;
	case en_ule:	op = op_sleu;	break;
	case en_gt:		op = op_sgt;	break;
	case en_ugt:	op = op_sgtu;	break;
	case en_ge:		op = op_sge;	break;
	case en_uge:	op = op_sgeu;	break;
	case en_flt:	op = op_fslt;	break;
	case en_fle:	op = op_fsle;	break;
	case en_fgt:	op = op_fsgt;	break;
	case en_fge:	op = op_fsge;	break;
	case en_feq:	op = op_fseq;	break;
	case en_fne:	op = op_fsne;	break;
	case en_veq:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();         
		ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
		ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
		GenerateTriadic(op_vseq,0,ap3,ap1,ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vne:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();         
		ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
		ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
		GenerateTriadic(op_vsne,0,ap3,ap1,ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vlt:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();         
		ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
		ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
		GenerateTriadic(op_vslt,0,ap3,ap1,ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vle:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();         
		ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
		ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
		GenerateTriadic(op_vsle,0,ap3,ap1,ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vgt:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();         
		ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
		ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
		GenerateTriadic(op_vsgt,0,ap3,ap1,ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vge:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();         
		ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
		ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
		GenerateTriadic(op_vsge,0,ap3,ap1,ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_land_safe:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size);
		ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, size);
		GenerateTriadic(op_and, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return(ap3);
	case en_lor_safe:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size);
		GenerateTriadic(op_or, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return(ap3);
	default:	// en_land, en_lor
		//ap1 = GetTempRegister();
		//ap2 = cg.GenerateExpression(node,am_reg,8);
		//GenerateDiadic(op_redor,0,ap1,ap2);
		//ReleaseTempReg(ap2);
		GenerateFalseJump(node,lab0,0);
		ap1 = GetTempRegister();
		GenerateDiadic(op_ldi|op_dot,0,ap1,MakeImmediate(1));
		GenerateMonadic(op_bra,0,MakeDataLabel(lab1,regZero));
		GenerateLabel(lab0);
		GenerateDiadic(op_ldi|op_dot,0,ap1,MakeImmediate(0));
		GenerateLabel(lab1);
		ap1->isBool = true;
		return (ap1);
	}

	switch (node->nodetype) {
	case en_eq:	return (GenerateEq(node));
	case en_ne:	return (GenerateNe(node));
	case en_lt:	return (GenerateLt(node));
	case en_le:	return (GenerateLe(node));
	case en_gt: return (GenerateGt(node));
	case en_ge:	return (GenerateGe(node));
	case en_ult:	return (GenerateLtu(node));
	case en_ule:	return (GenerateLeu(node));
	case en_ugt:	return (GenerateGtu(node));
	case en_uge:	return (GenerateGeu(node));
	case en_flt:	return (GenerateFlt(node));
	case en_fle:	return (GenerateFle(node));
	case en_fgt:	return (GenerateFgt(node));
	case en_fge:	return (GenerateFge(node));
	case en_feq:	return (GenerateFeq(node));
	case en_fne:	return (GenerateFne(node));
	case en_chk:
		size = node->GetNaturalSize();
        ap4 = GetTempRegister();         
		ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
		ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
		ap3 = cg.GenerateExpression(node->p[2],am_reg|am_imm0,size);
		if (ap3->mode == am_imm) {  // must be a zero
		   ap3->mode = am_reg;
		   ap3->preg = 0;
        }
   		Generate4adic(op_chk,0,ap4,ap1,ap2,ap3);
        ReleaseTempRegister(ap3);
        ReleaseTempRegister(ap2);
        ReleaseTempRegister(ap1);
        return ap4;
	}
	size = node->GetNaturalSize();
  ap3 = GetTempRegister();         
	ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
	ap2 = cg.GenerateExpression(node->p[1],am_reg|am_imm,size);
	GenerateTriadic(op,0,ap3,ap1,ap2);
  ReleaseTempRegister(ap2);
  ReleaseTempRegister(ap1);
	ap3->isBool = true;
	return (ap3);
	/*
    GenerateFalseJump(node,lab0,0);
    ap1 = GetTempRegister();
    GenerateDiadic(op_ld,0,ap1,MakeImmediate(1));
    GenerateMonadic(op_bra,0,MakeDataLabel(lab1));
    GenerateLabel(lab0);
    GenerateDiadic(op_ld,0,ap1,MakeImmediate(0));
    GenerateLabel(lab1);
    return ap1;
	*/
}

void ANY1CodeGenerator::GenerateBranchTrue(Operand* ap, int label)
{
	GenerateTriadic(op_bne, 0, ap, makereg(regZero), MakeDataLabel(label,regZero));
}

void ANY1CodeGenerator::GenerateBranchFalse(Operand* ap, int label)
{
	GenerateTriadic(op_beq, 0, ap, makereg(regZero), MakeDataLabel(label,regZero));
}

void ANY1CodeGenerator::GenerateBeq(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm && ap2->offset->i >= -128 && ap2->offset->i < 128)
		GenerateTriadic(op_beqi, 0, ap1, ap2, MakeCodeLabel(label));
	else if (((ap2->mode == am_imm && ap2->offset->i == 0) || (ap2->mode == am_reg && ap2->preg == regZero)) && ap1->preg >= regFirstArg && ap1->preg < regFirstArg + 4)
		GenerateDiadic(op_beqz, 0, ap1, MakeCodeLabel(label));
	else {
		if (ap2->mode == am_reg && ap1->mode == am_reg)
			GenerateTriadic(op_beq, 0, ap1, ap2, MakeCodeLabel(label));
		else {
			if (ap2->mode == am_imm && ap2->offset->i < 32 && ap2->offset->i >= -32)
				GenerateTriadic(op_beq, 0, ap1, ap2, MakeCodeLabel(label));
			else {
				ap3 = GetTempRegister();
				GenerateTriadic(op_seq, 0, ap3, ap1, ap2);
				GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
				ReleaseTempReg(ap3);
			}
		}
	}
}

void ANY1CodeGenerator::GenerateBne(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (((ap2->mode == am_imm && ap2->offset->i == 0) || (ap2->mode == am_reg && ap2->preg == regZero)) && ap1->preg >= regFirstArg && ap1->preg < regFirstArg + 4) {
		GenerateDiadic(op_bnez, 0, ap1, MakeCodeLabel(label));
	}
	else {
		if (ap2->mode == am_reg && ap1->mode == am_reg)
			GenerateTriadic(op_bne, 0, ap1, ap2, MakeCodeLabel(label));
		else {
			if (ap2->mode == am_imm && ap2->offset->i < 32 && ap2->offset->i >= -32)
				GenerateTriadic(op_bne, 0, ap1, ap2, MakeCodeLabel(label));
			else {
				ap3 = GetTempRegister();
				GenerateTriadic(op_sne, 0, ap3, ap1, ap2);
				GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
				ReleaseTempReg(ap3);
			}
		}
	}
}

void ANY1CodeGenerator::GenerateBlt(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		ap3 = GetTempRegister();
		if (ap2->offset->i >= -32 && ap2->offset->i < 32)
			GenerateTriadic(op_blt, 0, ap1, ap2, MakeCodeLabel(label));
		else {
			GenerateTriadic(op_slt, 0, ap3, ap1, ap2);
			GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		}
		ReleaseTempReg(ap3);
	}
	else
		GenerateTriadic(op_blt, 0, ap1, ap2, MakeCodeLabel(label));
}

void ANY1CodeGenerator::GenerateBge(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		ap3 = GetTempRegister();
		if (ap2->offset->i >= -32 && ap2->offset->i < 32)
			GenerateTriadic(op_bge, 0, ap1, ap2, MakeCodeLabel(label));
		else {
			GenerateTriadic(op_sge, 0, ap3, ap1, ap2);
			GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		}
		ReleaseTempReg(ap3);
	}
	else
		GenerateTriadic(op_bge, 0, ap1, ap2, MakeCodeLabel(label));
}

void ANY1CodeGenerator::GenerateBle(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		ap3 = GetTempRegister();
		GenerateTriadic(op_sge, 0, ap3, ap2, ap1);
		GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
	}
	else
		GenerateTriadic(op_bge, 0, ap2, ap1, MakeCodeLabel(label));
}

void ANY1CodeGenerator::GenerateBgt(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		ap3 = GetTempRegister();
		GenerateTriadic(op_slt, 0, ap3, ap2, ap1);
		GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
	}
	else
		GenerateTriadic(op_blt, 0, ap2, ap1, MakeCodeLabel(label));
}

void ANY1CodeGenerator::GenerateBltu(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		// Don't generate any code if testing against unsigned zero.
		// An unsigned number can't be less than zero so the branch will
		// always be false. Spit out a warning, its probably coded wrong.
		if (ap2->offset->i == 0)
			error(ERR_UBLTZ);	//GenerateDiadic(op_bltu,0,ap1,makereg(0),MakeCodeLabel(label));
		if (ap2->offset->i >= 0 && ap2->offset->i < 64) {
			GenerateTriadic(op_bltu, 0, ap1, ap2, MakeCodeLabel(label));
		}
		else {
			ap3 = GetTempRegister();
			GenerateTriadic(op_sltu, 0, ap3, ap1, ap2);
			GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
			ReleaseTempReg(ap3);
		}
	}
	else {
		GenerateTriadic(op_bltu, 0, ap1, ap2, MakeCodeLabel(label));
	}
}

void ANY1CodeGenerator::GenerateBgeu(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		if (ap2->offset->i == 0) {
			// This branch is always true
			error(ERR_UBGEQ);
			GenerateMonadic(op_bra, 0, MakeCodeLabel(label));
		}
		else {
			if (ap2->offset->i >= 0 && ap2->offset->i < 64)
				GenerateTriadic(op_bgeu, 0, ap1, ap2, MakeCodeLabel(label));
			else {
				ap3 = GetTempRegister();
				GenerateTriadic(op_sgeu, 0, ap3, ap1, ap2);
				GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
				ReleaseTempReg(ap3);
			}
		}
	}
	else {
		GenerateTriadic(op_bgeu, 0, ap1, ap2, MakeCodeLabel(label));
	}
}

void ANY1CodeGenerator::GenerateBleu(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		if (ap2->offset->i >= 0 && ap2->offset->i < 64)
			GenerateTriadic(op_bleu, 0, ap1, ap2, MakeCodeLabel(label));
		else {
			ap3 = GetTempRegister();
			GenerateTriadic(op_sleu, 0, ap3, ap1, ap2);
			GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
			ReleaseTempReg(ap3);
		}
	}
	else {
		GenerateTriadic(op_bleu, 0, ap1, ap2, MakeCodeLabel(label));
	}
}

void ANY1CodeGenerator::GenerateBgtu(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	if (ap2->mode == am_imm) {
		ap3 = GetTempRegister();
		GenerateLoadConst(ap3, ap2);
		GenerateTriadic(op_sltu, 0, ap3, ap3, ap1);
		GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
	}
	else
		GenerateTriadic(op_bltu, 0, ap2, ap1, MakeCodeLabel(label));
}

void ANY1CodeGenerator::GenerateBand(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	GenerateTriadic(op_and, 0, ap3, ap1, ap2);
	GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
	ReleaseTempReg(ap3);
}

void ANY1CodeGenerator::GenerateBor(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	GenerateTriadic(op_or, 0, ap3, ap1, ap2);
	GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
	ReleaseTempReg(ap3);
}

void ANY1CodeGenerator::GenerateBnand(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	GenerateTriadic(op_and, 0, ap3, ap1, ap2);
	GenerateDiadic(op_beqz, 0, ap3, MakeCodeLabel(label));
	ReleaseTempReg(ap3);
}

void ANY1CodeGenerator::GenerateBnor(Operand* ap1, Operand* ap2, int label)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	GenerateTriadic(op_or, 0, ap3, ap1, ap2);
	GenerateDiadic(op_beqz, 0, ap3, MakeCodeLabel(label));
	ReleaseTempReg(ap3);
}

bool ANY1CodeGenerator::GenerateBranch(ENODE *node, int op, int label, int predreg, unsigned int prediction, bool limit)
{
	int size, sz;
	Operand *ap1, *ap2, *ap3;
	OCODE *ip;

	if ((op == op_nand || op == op_nor || op == op_and || op == op_or) && (node->p[0]->HasCall() || node->p[1]->HasCall()))
		return (false);
	size = node->GetNaturalSize();
	ip = currentFn->pl.tail;
  if (op==op_flt || op==op_fle || op==op_fgt || op==op_fge || op==op_feq || op==op_fne) {
    ap1 = cg.GenerateExpression(node->p[0],am_reg,size);
	  ap2 = cg.GenerateExpression(node->p[1],am_reg,size);
  }
  else {
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size);
		ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, size);
  }
	if (limit && currentFn->pl.Count(ip) > 10) {
		currentFn->pl.tail = ip;
		currentFn->pl.tail->fwd = nullptr;
		return (false);
	}

	/*
	// Optimize CMP to zero and branch into plain branch, this works only for
	// signed relational compares.
	if (ap2->mode == am_imm && ap2->offset->i==0 && (op==op_eq || op==op_ne || op==op_lt || op==op_le || op==op_gt || op==op_ge)) {
    	switch(op)
    	{
    	case op_eq:	op = op_beq; break;
    	case op_ne:	op = op_bne; break;
    	case op_lt: op = op_blt; break;
    	case op_le: op = op_ble; break;
    	case op_gt: op = op_bgt; break;
    	case op_ge: op = op_bge; break;
    	}
    	ReleaseTempReg(ap3);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		GenerateDiadic(op,0,ap1,MakeCodeLabel(label));
		return;
	}
	*/
	/*
	if (op==op_ltu || op==op_leu || op==op_gtu || op==op_geu)
 	    GenerateTriadic(op_cmpu,0,ap3,ap1,ap2);
    else if (op==op_flt || op==op_fle || op==op_fgt || op==op_fge || op==op_feq || op==op_fne)
        GenerateTriadic(op_fdcmp,0,ap3,ap1,ap2);
	else 
 	    GenerateTriadic(op_cmp,0,ap3,ap1,ap2);
	*/
	sz = 0;
	switch(op)
	{
	case op_bchk:	break;
	case op_nand:	op = op_bnand; break;
	case op_nor:	op = op_bnor; break;
	case op_and:	op = op_band; break;
	case op_or:	op = op_bor; break;
	case op_eq:	op = op_beq; break;
	case op_ne:	op = op_bne; break;
	case op_lt: op = op_blt; break;
	case op_le: op = op_ble; break;
	case op_gt: op = op_bgt; break;
	case op_ge: op = op_bge; break;
	case op_ltu: op = op_bltu; break;
	case op_leu: op = op_bleu; break;
	case op_gtu: op = op_bgtu; break;
	case op_geu: op = op_bgeu; break;
	case op_feq:	op = op_fbeq; sz = 'd'; break;
	case op_fne:	op = op_fbne; sz = 'd'; break;
	case op_flt:	op = op_fblt; sz = 'd'; break;
	case op_fle:	op = op_fble; sz = 'd'; break;
	case op_fgt:	op = op_fbgt; sz = 'd'; break;
	case op_fge:	op = op_fbge; sz = 'd'; break;
	}

	switch(op) {

	case op_fbne:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fcmp, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bbs, 0, ap3, MakeImmediate(8), MakeCodeLabel(label));
		//GenerateTriadic(op_fsne, 0, ap3, ap1, ap2);
		//GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fbeq:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fcmp, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bbs, 0, ap3, MakeImmediate(0), MakeCodeLabel(label));
		//GenerateTriadic(op_fseq, 0, ap3, ap1, ap2);
		//GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fblt:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fcmp, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bbs, 0, ap3, MakeImmediate(1), MakeCodeLabel(label));
		//GenerateTriadic(op_fslt, 0, ap3, ap1, ap2);
		//GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fble:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fcmp, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bbs, 0, ap3, MakeImmediate(2), MakeCodeLabel(label));
		//GenerateTriadic(op_fsle, 0, ap3, ap1, ap2);
		//GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fbgt:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fcmp, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bbs, 0, ap3, MakeImmediate(10), MakeCodeLabel(label));
		//GenerateTriadic(op_fslt, 0, ap3, ap2, ap1);
		//GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fbge:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fcmp, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bbs, 0, ap3, MakeImmediate(11), MakeCodeLabel(label));
		//GenerateTriadic(op_fsle, 0, ap3, ap2, ap1);
		//GenerateDiadic(op_bnez, 0, ap3, MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_band:	GenerateBand(ap1, ap2, label); break;
	case op_bor:	GenerateBor(ap1, ap2, label);	break;
	case op_bnand:	GenerateBnand(ap1, ap2, label);	break;
	case op_bnor:	GenerateBnor(ap1, ap2, label);	break;
	case op_beq:	GenerateBeq(ap1, ap2, label); break;
	case op_bne:	GenerateBne(ap1, ap2, label); break;
	case op_blt:	GenerateBlt(ap1, ap2, label); break;
	case op_ble:	GenerateBle(ap1, ap2, label); break;
	case op_bgt:	GenerateBgt(ap1, ap2, label); break;
	case op_bge:	GenerateBge(ap1, ap2, label);	break;
	case op_bltu:	GenerateBltu(ap1, ap2, label);	break;
	case op_bleu:	GenerateBleu(ap1, ap2, label);  break;
	case op_bgtu:	GenerateBgtu(ap1, ap2, label);	break;
	case op_bgeu:	GenerateBgeu(ap1, ap2, label);	break;
	}
  ReleaseTempReg(ap2);
  ReleaseTempReg(ap1);
	return (true);
}


static void SaveRegisterSet(SYM *sym)
{
	int nn, mm;

	if (!cpu.SupportsPush || true) {
		mm = sym->tp->GetBtp()->type!=bt_void ? 29 : 30;
		GenerateTriadic(op_sub,0,makereg(regSP),makereg(regSP),cg.MakeImmediate(mm*sizeOfWord));
		mm = 0;
		for (nn = 1 + (sym->tp->GetBtp()->type!=bt_void ? 1 : 0); nn < 31; nn++) {
			GenerateDiadic(op_sto,0,makereg(nn),cg.MakeIndexed(mm,regSP));
			mm += sizeOfWord;
		}
	}
	else
		for (nn = 1 + (sym->tp->GetBtp()->type!=bt_void ? 1 : 0); nn < 31; nn++)
			GenerateMonadic(op_push,0,makereg(nn));
}

static void RestoreRegisterSet(SYM * sym)
{
	int nn, mm;

	if (!cpu.SupportsPop || true) {
		mm = 0;
		for (nn = 1 + (sym->tp->GetBtp()->type!=bt_void ? 1 : 0); nn < 31; nn++) {
			GenerateDiadic(op_ldo,0,makereg(nn),cg.MakeIndexed(mm,regSP));
			mm += sizeOfWord;
		}
		mm = sym->tp->GetBtp()->type!=bt_void ? 29 : 30;
		GenerateTriadic(op_add,0,makereg(regSP),makereg(regSP),cg.MakeImmediate(mm*sizeOfWord));
	}
	else // ToDo: check pop is in reverse order to push
		for (nn = 1 + (sym->tp->GetBtp()->type!=bt_void ? 1 : 0); nn < 31; nn++)
			GenerateMonadic(op_pop,0,makereg(nn));
}


// Push temporaries on the stack.

void SaveRegisterVars(CSet *rmask)
{
	int cnt;
	int nn;
	int64_t mask;

	if (pass == 1) {
		max_stack_use += rmask->NumMember() * sizeOfWord;
		currentFn->regvarbot = max_stack_use;
	}
	if( rmask->NumMember() ) {
		if (cpu.SupportsSTM && rmask->NumMember() > 2) {
			mask = 0;
			for (nn = nregs; nn >= 0; nn--)
				if (rmask->isMember(nn))
					mask = mask | (1LL << (nregs-1-nn-1));
			//GenerateMonadic(op_reglist, 0, cg.MakeImmediate(mask, 16));
			GenerateDiadic(op_stm, 0, cg.MakeIndirect(regSP), cg.MakeImmediate(mask, 16));
		}
		else {
			cnt = 0;
			//GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), cg.MakeImmediate(rmask->NumMember() * sizeOfWord));
			rmask->resetPtr();
			for (nn = rmask->lastMember(); nn >= 0; nn = rmask->prevMember()) {
				// nn = nregs - 1 - regno
				// regno = -(nn - nregs + 1);
				// regno = nregs - 1 - nn
				GenerateDiadic(op_sto, 0, makereg(nregs - 1 - nn), cg.MakeIndexed(cnt, regSP));
				cnt += sizeOfWord;
			}
		}
	}
}

void SaveFPRegisterVars(CSet *rmask)
{
	int cnt;
	int nn;

	if( rmask->NumMember() ) {
		cnt = 0;
		GenerateTriadic(op_sub,0,makereg(regSP),makereg(regSP),cg.MakeImmediate(rmask->NumMember()*8));
		for (nn = rmask->lastMember(); nn >= 0; nn = rmask->prevMember()) {
			GenerateDiadic(op_sto, 0, makereg(nregs - 1 - nn), cg.MakeIndexed(cnt, regSP));
			cnt += sizeOfWord;
		}
	}
}

void SavePositRegisterVars(CSet* rmask)
{
	int cnt;
	int nn;

	if (rmask->NumMember()) {
		cnt = 0;
		GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), cg.MakeImmediate(rmask->NumMember() * 8));
		for (nn = rmask->lastMember(); nn >= 0; nn = rmask->prevMember()) {
			GenerateDiadic(op_psto, 0, makefpreg(nregs - 1 - nn), cg.MakeIndexed(cnt, regSP));
			cnt += sizeOfWord;
		}
	}
}

// Restore registers used as register variables.

static void RestoreRegisterVars()
{
	int cnt2, cnt;
	int nn;
	int64_t mask;

	if( save_mask->NumMember()) {
		if (cpu.SupportsLDM && save_mask->NumMember() > 2) {
			mask = 0;
			for (nn = 0; nn < 32; nn++)
				if (save_mask->isMember(nn))
					mask = mask | (1LL << nn);
			GenerateMonadic(op_reglist, 0, cg.MakeImmediate(mask, 1));
			GenerateMonadic(op_ldm, 0, cg.MakeIndirect(regSP));
		}
		else {
			cnt2 = cnt = save_mask->NumMember() * sizeOfWord;
			cnt = 0;
			save_mask->resetPtr();
			for (nn = save_mask->nextMember(); nn >= 0; nn = save_mask->nextMember()) {
				GenerateDiadic(op_ldo, 0, makereg(nn), cg.MakeIndexed(cnt, regSP));
				cnt += sizeOfWord;
			}
			GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), cg.MakeImmediate(cnt2));
		}
	}
}

static void RestoreFPRegisterVars()
{
	int cnt2, cnt;
	int nn;

	if( fpsave_mask->NumMember()) {
		cnt2 = cnt = fpsave_mask->NumMember()*sizeOfWord;
		cnt = 0;
		fpsave_mask->resetPtr();
		for (nn = fpsave_mask->nextMember(); nn >= 0; nn = fpsave_mask->nextMember()) {
			GenerateDiadic(op_fldo, 0, makefpreg(nn), cg.MakeIndexed(cnt, regSP));
			cnt += sizeOfWord;
		}
		GenerateTriadic(op_add,0,makereg(regSP),makereg(regSP),cg.MakeImmediate(cnt2));
	}
}

// push the operand expression onto the stack.
// Structure variables are represented as an address in a register and arrive
// here as autocon nodes if on the stack. If the variable size is greater than
// 8 we assume a structure variable and we assume we have the address in a reg.
// Returns: number of stack words pushed.
//
int ANY1CodeGenerator::PushArgument(ENODE *ep, int regno, int stkoffs, bool *isFloat, int* push_count, bool large_argcount)
{    
	Operand *ap, *ap3;
	int nn = 0;
	int sz;

	*isFloat = false;
	*push_count = 0;
	switch(ep->etype) {
	case bt_quad:	sz = sizeOfFPD; break;
	case bt_triple:	sz = sizeOfFPT; break;
	case bt_double:	sz = sizeOfFPD; break;
	case bt_float:	sz = sizeOfFPD; break;
	case bt_posit:	sz = sizeOfPosit; break;
	default:	sz = sizeOfWord; break;
	}
	if (ep->tp) {
		if (ep->tp->IsFloatType())
			ap = cg.GenerateExpression(ep,am_reg,sizeOfFP);
		else if (ep->tp->IsPositType())
			ap = cg.GenerateExpression(ep, am_preg, sizeOfPosit);
		else
			ap = cg.GenerateExpression(ep,am_reg|am_imm,ep->GetNaturalSize());
	}
	else if (ep->etype==bt_quad)
		ap = cg.GenerateExpression(ep,am_reg,sz);
	else if (ep->etype==bt_double)
		ap = cg.GenerateExpression(ep,am_reg,sz);
	else if (ep->etype==bt_triple)
		ap = cg.GenerateExpression(ep,am_reg,sz);
	else if (ep->etype==bt_float)
		ap = cg.GenerateExpression(ep,am_reg,sz);
	else if (ep->etype == bt_posit)
		ap = cg.GenerateExpression(ep, am_reg, sz);
	else
		ap = cg.GenerateExpression(ep,am_reg|am_imm,ep->GetNaturalSize());
	switch(ap->mode) {
	case am_fpreg:
		*isFloat = true;
	case am_preg:
	case am_reg:
  case am_imm:
/*
        nn = round8(ep->esize); 
        if (nn > 8) {// && (ep->tp->type==bt_struct || ep->tp->type==bt_union)) {           // structure or array ?
            ap2 = GetTempRegister();
            GenerateTriadic(op_subui,0,makereg(regSP),makereg(regSP),MakeImmediate(nn));
            GenerateDiadic(op_mov, 0, ap2, makereg(regSP));
            GenerateMonadic(op_push,0,MakeImmediate(ep->esize));
            GenerateMonadic(op_push,0,ap);
            GenerateMonadic(op_push,0,ap2);
            GenerateMonadic(op_bsr,0,MakeStringAsNameConst("memcpy_"));
            GenerateTriadic(op_addui,0,makereg(regSP),makereg(regSP),MakeImmediate(24));
          	GenerateMonadic(op_push,0,ap2);
            ReleaseTempReg(ap2);
            nn = nn >> 3;
        }
        else {
*/
			if (regno) {
				GenerateMonadic(op_hint,0,MakeImmediate(1));
				if (ap->mode==am_imm) {
					GenerateDiadic(op_ldi,0,makereg(regno & 0x7fff), ap);
					if (regno & 0x8000) {
						GenerateTriadic(op_sub,0,makereg(regSP),makereg(regSP),MakeImmediate(sizeOfWord));
						nn = 1;
					}
				}
				else if (ap->mode==am_fpreg) {
					*isFloat = true;
					GenerateDiadic(op_mov,0,makefpreg(regno & 0x7fff), ap);
					if (regno & 0x8000) {
						GenerateTriadic(op_sub,0,makereg(regSP),makereg(regSP),MakeImmediate(sz));
						nn = sz/sizeOfWord;
					}
				}
				else {
					//ap->preg = regno & 0x7fff;
					GenerateDiadic(op_mov,0,makereg(regno & 0x7fff), ap);
					if (regno & 0x8000) {
						GenerateTriadic(op_sub,0,makereg(regSP),makereg(regSP),MakeImmediate(sizeOfWord));
						nn = 1;
					}
				}
			}
			else {
				if (cpu.SupportsPush && !large_argcount) {
					if (ap->mode==am_imm) {	// must have been a zero
						if (ap->offset->i==0)
         					GenerateMonadic(op_push,0,makereg(0));
						else {
							ap3 = GetTempRegister();
							GenerateLoadConst(ap, ap3);
							GenerateMonadic(op_push,0,ap3);
							ReleaseTempReg(ap3);
						}
						nn = 1;
						*push_count = 1;
					}
					else {
						if (ap->type==stddouble.GetIndex()) 
						{
							*isFloat = true;
							GenerateMonadic(op_push,0,ap);
							nn = sz/sizeOfWord;
							nn = 1;
							*push_count = 1;
						}
						else {
							regs[ap->preg].IsArg = true;
							GenerateMonadic(op_push,0,ap);
							nn = 1;
							*push_count = 1;
						}
					}
				}
				else {
					if (ap->mode==am_imm) {	// must have been a zero
						ap3 = nullptr;
						if (ap->offset->i!=0) {
							ap3 = GetTempRegister();
							regs[ap3->preg].IsArg = true;
							GenerateLoadConst(ap, ap3);
	         		GenerateDiadic(op_sto,0,ap3,MakeIndexed(stkoffs,regSP));
							ReleaseTempReg(ap3);
						}
						else {
							GenerateDiadic(op_sto, 0, makereg(0), MakeIndexed(stkoffs, regSP));
						}
						nn = 1;
					}
					else {
						if (ap->type==stddouble.GetIndex() || ap->mode==am_reg) {
							*isFloat = true;
							GenerateDiadic(op_sto,0,ap,MakeIndexed(stkoffs,regSP));
							nn = sz/sizeOfWord;
						}
						else if (ap->type == stdposit.GetIndex() || ap->mode == am_reg) {
							GenerateDiadic(op_sto, 0, ap, MakeIndexed(stkoffs, regSP));
							nn = 1;
						}
						else {
							regs[ap->preg].IsArg = true;
							GenerateDiadic(op_sto,0,ap,MakeIndexed(stkoffs,regSP));
							nn = 1;
						}
					}
				}
			}
//        }
    	break;
    }
	ReleaseTempReg(ap);
	return nn;
}

// Store entire argument list onto stack
//
int ANY1CodeGenerator::PushArguments(Function *sym, ENODE *plist)
{
	TypeArray *ta = nullptr;
	int i,sum;
	OCODE *ip;
	ENODE *p;
	ENODE *pl[100];
	int nn, maxnn, kk, pc;
	int push_count;
	bool isFloat = false;
	bool sumFloat;
	bool o_supportsPush;
	bool large_argcount = false;
	SYM** sy = nullptr;

	sum = 0;
	push_count = 0;
	if (sym)
		ta = sym->GetProtoTypes();

	sumFloat = false;
	ip = currentFn->pl.tail;
	GenerateTriadic(op_sub,0,makereg(regSP),makereg(regSP),MakeImmediate(0));
	// Capture the parameter list. It is needed in the reverse order.
	for (nn = 0, p = plist; p != NULL; p = p->p[1], nn++) {
		pl[nn] = p->p[0];
	}
	if (nn > 2)
		large_argcount = true;
	maxnn = nn;
	for(--nn, i = 0; nn >= 0; --nn,i++ )
  {
		if (pl[nn]->etype == bt_pointer) {
			if (pl[nn]->tp->GetBtp() == nullptr) {
				sum++;
				continue;
			}
			if (pl[nn]->tp->GetBtp()->type == bt_ichar || pl[nn]->tp->GetBtp()->type == bt_iuchar)
				continue;
		}
				//		sum += GeneratePushParameter(pl[nn],ta ? ta->preg[ta->length - i - 1] : 0,sum*8);
		// Variable argument list functions may cause the type array values to be
		// exhausted before all the parameters are pushed. So, we check the parm number.
		if (pl[nn]->etype == bt_none) {	// was there an empty parameter?
			if (sy==nullptr && sym)
				sy = sym->params.GetParameters();
			if (sy) {
				if (sy[nn]) {
					sum += PushArgument(sy[nn]->defval, ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sum * sizeOfWord, &isFloat, &pc, large_argcount);
					push_count += pc;
				}
			}
		}
		else {
			sum += PushArgument(pl[nn], ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sum * sizeOfWord, &isFloat, &pc, large_argcount);
			push_count += pc;
		}
		sumFloat |= isFloat;
//		plist = plist->p[1];
  }
	if (sum == 0 || !large_argcount)
		ip->fwd->MarkRemove();
	else
		ip->fwd->oper3 = MakeImmediate(sum*sizeOfWord);
	/*
	if (!sumFloat) {
		o_supportsPush = cpu.SupportsPush;
		cpu.SupportsPush = false;
		currentFn->pl.tail = ip;
		currentFn->pl.tail->fwd = nullptr;
		i = maxnn-1;
		for (nn = 0; nn < maxnn; nn++, i--) {
			if (pl[nn]->etype == bt_pointer)
				if (pl[nn]->tp->GetBtp()->type == bt_ichar || pl[nn]->tp->GetBtp()->type == bt_iuchar)
					continue;
			if (pl[nn]->etype == bt_none) {	// was there an empty parameter?
				if (sy == nullptr && sym)
					sy = sym->params.GetParameters();
				if (sy)
					PushArgument(sy[nn]->defval, ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sum * sizeOfWord, &isFloat);
			}
			else
				PushArgument(pl[nn], ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sum * 8, &isFloat);
		}
		cpu.SupportsPush = o_supportsPush;
	}
	*/
	if (ta)
		delete ta;
  return (sum);
}

// Pop parameters off the stack

void ANY1CodeGenerator::PopArguments(Function *fnc, int howMany, bool isPascal)
{
	if (howMany != 0) {
		if (fnc) {
			if (!fnc->IsPascal)
				GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(howMany * sizeOfWord));
		}
		else {
			if (!isPascal)
				GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(howMany * sizeOfWord));
		}
	}
}


// Return true if the expression tree has isPascal set anywhere.
// Only needed for indirect function calls.
extern int defaultcc;
bool ANY1CodeGenerator::IsPascal(ENODE *ep)
{
	if (ep == nullptr)
		return (defaultcc==1);
	if (ep->isPascal)
		return (true);
	if (IsPascal(ep->p[0]) || IsPascal(ep->p[1]) || IsPascal(ep->p[2]))
		return (true);
	return (false);
}

void ANY1CodeGenerator::LinkAutonew(ENODE *node)
{
	if (node->isAutonew) {
		currentFn->hasAutonew = true;
	}
}

Operand *ANY1CodeGenerator::GenerateFunctionCall(ENODE *node, int flags)
{ 
	Operand *ap;
	Function *sym;
	Function *o_fn;
	SYM *s;
    int i;
	int sp = 0;
	int fsp = 0;
	int psp = 0;
	int ps;
	TypeArray *ta = nullptr;
	CSet *mask, *fmask, *pmask;

	sym = nullptr;

	// Call the function
	if( node->p[0]->nodetype == en_nacon || node->p[0]->nodetype == en_cnacon ) {
		s = gsearch(*node->p[0]->sp);
 		sym = s->fi;
        i = 0;
  /*
    	if ((sym->tp->GetBtp()->type==bt_struct || sym->tp->GetBtp()->type==bt_union) && sym->tp->GetBtp()->size > 8) {
            nn = tmpAlloc(sym->tp->GetBtp()->size) + lc_auto + round8(sym->tp->GetBtp()->size);
            GenerateMonadic(op_pea,0,MakeIndexed(-nn,regFP));
            i = 1;
        }
*/
//		ReleaseTempRegister(ap);
		sym->SaveTemporaries(&sp, &fsp, &psp);
		if (currentFn->HasRegisterParameters())
			sym->SaveRegisterArguments();
		// If the symbol is unknown, assume a throw is present
		if (sym) {
			if (sym->DoesThrow)
				currentFn->DoesThrow = true;
		}
		else
			currentFn->DoesThrow = true;
		i = i + PushArguments(sym, node->p[1]);
		if (sym && sym->IsInline) {
			o_fn = currentFn;
			mask = save_mask;
			fmask = fpsave_mask;
			pmask = psave_mask;
			currentFn = sym;
			ps = pass;
			// Each function has it's own peeplist. The generated peeplist for an
			// inline function must be appended onto the peeplist of the current
			// function.
			sym->pl.head = sym->pl.tail = nullptr;
			sym->Generate();
			pass = ps;
			currentFn = o_fn;
			currentFn->pl.tail->fwd = sym->pl.head;
			currentFn->pl.tail = sym->pl.tail;
			LinkAutonew(node);
			fpsave_mask = fmask;
			save_mask = mask;
			psave_mask = pmask;
		}
		else {
			if (sym && sym->IsLeaf) {
				GenerateDiadic(op_bal, 0, makereg(regLR), MakeDirect(node->p[0]));
				currentFn->doesJAL = true;
			}
			else
				GenerateDiadic(op_bal, 0, makereg(regLR), MakeDirect(node->p[0]));
			GenerateMonadic(op_bex,0,MakeDataLabel(throwlab,regZero));
			LinkAutonew(node);
		}
		GenerateInlineArgumentList(sym, node->p[1]);
		PopArguments(sym, i);
		if (currentFn->HasRegisterParameters())
			if (sym)
				sym->RestoreRegisterArguments();
		if (sym)
			sym->RestoreTemporaries(sp, fsp, psp);
	}
    else
    {
        i = 0;
    /*
    	if ((node->p[0]->tp->GetBtp()->type==bt_struct || node->p[0]->tp->GetBtp()->type==bt_union) && node->p[0]->tp->GetBtp()->size > 8) {
            nn = tmpAlloc(node->p[0]->tp->GetBtp()->size) + lc_auto + round8(node->p[0]->tp->GetBtp()->size);
            GenerateMonadic(op_pea,0,MakeIndexed(-nn,regFP));
            i = 1;
        }
     */
		ap = cg.GenerateExpression(node->p[0],am_reg,sizeOfWord);
		if (ap->offset) {
			if (ap->offset->sym)
				sym = ap->offset->sym->fi;
		}
		if (sym)
			sym->SaveTemporaries(&sp, &fsp, &psp);
		if (currentFn->HasRegisterParameters())
			if (sym)
				sym->SaveRegisterArguments();
		i = i + PushArguments(sym, node->p[1]);
		// If the symbol is unknown, assume a throw is present
		if (sym) {
			if (sym->DoesThrow)
				currentFn->DoesThrow = true;
		}
		else
			currentFn->DoesThrow = true;
		ap->mode = am_ind;
		ap->offset = 0;
		if (sym && sym->IsInline) {
			o_fn = currentFn;
			mask = save_mask;
			fmask = fpsave_mask;
			pmask = psave_mask;
			currentFn = sym;
			ps = pass;
			sym->pl.head = sym->pl.tail = nullptr;
			sym->Generate();
			pass = ps;
			currentFn = o_fn;
			currentFn->pl.tail->fwd = sym->pl.head;
			currentFn->pl.tail = sym->pl.tail;
			LinkAutonew(node);
			fpsave_mask = fmask;
			save_mask = mask;
			psave_mask = pmask;
		}
		else {
			if (sym && sym->IsLeaf) {
				GenerateDiadic(op_jal, 0, makereg(regLR), ap);
				currentFn->doesJAL = true;
			}
			else
				GenerateDiadic(op_jal, 0, makereg(regLR), ap);
			GenerateMonadic(op_bex,0,MakeDataLabel(throwlab,regZero));
			LinkAutonew(node);
		}
		GenerateInlineArgumentList(sym, node->p[1]);
		PopArguments(sym, i, IsPascal(node));
		if (currentFn->HasRegisterParameters())
			if (sym)
				sym->RestoreRegisterArguments();
		if (sym)
			sym->RestoreTemporaries(sp, fsp, psp);
		ReleaseTempRegister(ap);
	}
	/*
	if (sym) {
	   if (sym->tp->type==bt_double)
           result = GetTempFPRegister();
	   else
           result = GetTempRegister();
    }
    else {
        if (node->etype==bt_double)
            result = GetTempFPRegister();
        else
            result = GetTempRegister();
    }
	*/
	if (sym
		&& sym->sym
		&& sym->sym->tp 
		&& sym->sym->tp->GetBtp()
		&& sym->sym->tp->GetBtp()->IsFloatType()) {
		if (!(flags & am_novalue))
			return (makereg(regFirstArg));
		else
			return (makereg(regZero));
	}
	if (sym
		&& sym->sym
		&& sym->sym->tp
		&& sym->sym->tp->GetBtp()
		&& sym->sym->tp->GetBtp()->IsVectorType()) {
		if (!(flags & am_novalue))
			return (makevreg(1));
		else
			return (makevreg(0));
	}
	if (sym
		&& sym->sym
		&& sym->sym->tp
		&& sym->sym->tp->GetBtp()
		) {
		if (!(flags & am_novalue)) {
			if (sym->sym->tp->GetBtp()->type != bt_void) {
				ap = GetTempRegister();
				GenerateDiadic(op_mov, 0, ap, makereg(regFirstArg));
				regs[1].modified = true;
			}
			else
				ap = makereg(regZero);
			ap->isPtr = sym->sym->tp->GetBtp()->type == bt_pointer;
		}
		else
			return(makereg(regZero));
	}
	else {
		if (!(flags & am_novalue)) {
			ap = GetTempRegister();
			GenerateDiadic(op_mov, 0, ap, makereg(regFirstArg));
			regs[regFirstArg].modified = true;
		}
		else
			return(makereg(regZero));
	}
	return (ap);
	/*
	else {
		if( result->preg != 1 || (flags & am_reg) == 0 ) {
			if (sym) {
				if (sym->tp->GetBtp()->type==bt_void)
					;
				else {
                    if (sym->tp->type==bt_double)
					    GenerateDiadic(op_fdmov,0,result,makefpreg(1));
                    else
					    GenerateDiadic(op_mov,0,result,makereg(1));
                }
			}
			else {
                if (node->etype==bt_double)
      				GenerateDiadic(op_fdmov,0,result,makereg(1));
                else
		     		GenerateDiadic(op_mov,0,result,makereg(1));
            }
		}
	}
    return result;
	*/
}

void ANY1CodeGenerator::GenerateUnlink()
{
	if (cpu.SupportsUnlink)
		GenerateZeradic(op_unlk);
	else
	{
		GenerateDiadic(op_mov, 0, makereg(regSP), makereg(regFP));
		GenerateDiadic(op_ldo, 0, makereg(regFP), MakeIndirect(regSP));
	}
}
