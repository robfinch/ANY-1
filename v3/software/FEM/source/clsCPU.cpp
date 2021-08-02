#include "stdafx.h"
#include <stdio.h>

#define BIT(a,b)	(((a) >> (b)) & 1LL)

void clsCPU::Reset()
	{
		int nn;
		km = true;
		brk = 0;
		im = true;
		irq = false;
		nmi = false;
		StatusHWI = false;
		isRunning = false;
		for (nn = 0; nn < 64; nn++)
			regs[0][nn] = 0;
		rgs = 0;
		sregs[15] = 0xFFFFFFFFFFFC0007LL;
		pc = 0x0600LL;
		vbr = 0;
		tick = 0;
		rvecno = 0;
		regLR = 1;
		exi = false;
	};
	void clsCPU::BuildConstant() {
		sir = ir;
		imm1 = (sir >> 16);
		imm2 = (sir&0x80000000) ? 0xFFFFFFFF : 0x00000000;
		imm = ((__int64)imm2 << 32) | imm1;
	};
	void clsCPU::Step()
	{
		unsigned int ad, opc;
		unsigned __int64 irx, iry, irz;
		unsigned int lsfunc;
		int nn;
		int sc;
		int ir21;
		int brdisp;
		int broffs;
		__int64 imm4,imm9,imm9bra;
		uint64_t mask;
		bool isCompressed;
		bool isUnsignedOp;
		uint64_t rv,rv2;
		uint64_t csip = ((sregs[15] & 0xFFFFFFF0LL) << 1LL) + pc;

		if (imcd > 0) {
			imcd--;
			if (imcd==1)
				im = 0;
		}
		tick = tick + 1;
		//---------------------------------------------------------------------------
		// Instruction Fetch stage
		//---------------------------------------------------------------------------
		wir = xir;
		xir = ir;
		if (nmi && !StatusHWI)
			sir = ir = 0x38 + (0x1E << 7) + (510 << 17) + 0x80000000L;
		else if (irq && ~im && !StatusHWI)
			sir = ir = 0x38 + (0x1E << 7) + (vecno << 17) + 0x80000000L;
		else {
			// Read the pc in three characters as the address may be character aligned.
			ir = system1->IFetch(csip);
		}
		ir21 = (ir >> 21) & 0x1F;
		if (ir21 & 0x10)
			ir21 |= 0xFFFFFFE0L;
		if (pc != pcs[0]) {
			for (nn = 39; nn >= 0; nn--)
				pcs[nn] = pcs[nn-1];
			pcs[0] = csip;
		}
		imm4 = (ir >> 12) & 15;
		imm9 = ((ir >> 7) & 0x1ff) << 3;	// For RTS2
		if (imm4 & 0x8)
			imm4 |= 0xFFFFFFFFFFFFFFF0LL;
		imm9bra = ((ir >> 7) & 0x1ff) ;	// For BRAS
		if (imm9bra & 0x100)
			imm9bra |= 0xFFFFFFFFFFFFFF00LL;
		brdisp = ((ir >> 8LL) & 0x3fLL) | (((ir >> 19LL) & 1LL) << 6LL) | ((ir >> 27LL) << 7LL);
		if (ir >> 35LL)
			brdisp = brdisp | 0xffffffffffff0000LL;
		broffs = (((ir >> 23) & 0x1f) << 3) | (((ir >> 16) & 3) << 1);
dc:
		//---------------------------------------------------------------------------
		// Decode stage
		//---------------------------------------------------------------------------
		isUnsignedOp = false;
		if ((ir & 0x70) == 0x70) {
			ir = DecompressInstruction(ir);
			isCompressed = true;
		}
		else
			isCompressed = false;
		opcode = ir & 0x7F;
		func = ir >> 29LL;
		lsfunc = ir >> 32LL;
		switch (opcode) {
		case IJAL:
		case IBAL:
			Rt = (ir >> 8LL) & 0x3LL;
			break;
		default:
			Rt = (ir >> 8LL) & 0x1fLL;
		}
		Ra = (ir >> 14LL) & 0x1fLL;
		Rb = (ir >> 20LL) & 0x1fLL;
		if (opcode==IJAL || opcode==IBAL)
			Rt = (ir >> 8LL) & 3LL;
		Bn = (ir >> 16) & 0x3f;
		sc = (ir >> 21) & 3;
		mb = (ir >> 16) & 0x3f;
		me = (ir >> 22) & 0x3f;
		switch (opcode) {
		case IBLTU:
		case IBGEU:
			isUnsignedOp = true;
			break;
		case IR2:
			switch (func) {
			case ISLTU:
			case ISGEU:
			case IMULF:
				isUnsignedOp = true;
				break;
			}
		}
		switch (opcode) {
		case EXI0:
			exi_imm = ((ir >> 8LL) << 11LL);
			if (ir >> 35LL)
				exi_imm = exi_imm | 0xffffffe000000000LL;
			exi = true;
			break;
		case EXI1:
			exi_imm = exi_imm & 0x7fffffffffLL;
			exi_imm = exi_imm | (((ir >> 8LL) << 39LL));
			exi = true;
			break;
		case ILDx:
		case ILDxZ:
			imm = (ir >> 20LL) & 0xfffLL;
			if ((ir >> 31LL) & 1LL)
				imm |= 0xfffffffffffff000LL;
			if (exi) {
				imm &= 0x7ffLL | exi_imm;
				exi = false;
			}
			break;
		case ISTx:
			Rt = 0;
			imm = ((ir >> 8LL) & 0x3f) | (((ir >> 27LL) & 0x1fLL) << 6LL);
			if ((ir >> 31LL) & 1LL)
				imm |= 0xfffffffffffff000LL;
			if (exi) {
				imm &= 0x7ffLL | exi_imm;
				exi = false;
			}
			break;
		case ISTxX:
			Rt = 0;
			break;
		default:
			imm = (ir >> 20LL) & 0xffffLL;
			if ((ir >> 35LL) & 1LL)
				imm |= 0xffffffffffff0000LL;
			if (exi) {
				imm = (imm & 0x7ffLL) | exi_imm;
				exi = false;
			}
			break;
		}
		a = opera.ai = regs[Ra][rgs];
		b = operb.ai = regs[Rb][rgs];
		if (BIT(ir,26)) {
			b = ((ir >> 20LL) & 0x3fLL);
			if ((ir >> 25LL) && !isUnsignedOp)
				b |= 0xffffffffffffffc0LL;
		}
//		c = operc.ai = regs[Rc][rgs];
		ua = a;
		ub = b;
		res = 0;
		opc = pc;
		pc = pc + (isCompressed ? 5 : 9);

		//---------------------------------------------------------------------------
		// Execute stage
		//---------------------------------------------------------------------------
		switch(opcode) {
		case IR2:
			switch(func) {
//			case ISEI:  im = a|imm; break;
/*
			case IRTI:
				km = ipc & 1;
				pc = ipc & -2;
				regs[30][rgs] = isp;
				StatusHWI = false;
				imcd = 4;
				break;
			case IWAIT:	if (irq || nmi) break;
*/
			case IADD:
				res = a + b;
				break;
			case ISUB:
				res = a - b;
				break;
			case ICMP:
				if (a < b)
					res = -1LL;
				else if (a == b)
					res=0LL;
				else
					res=1LL;
				break;
			// ToDo: return high order 64 bits of product
			case IMUL:
				res = a * b;
				break;
			case IMULSU:
				res = a * ub;
				break;
			case IMULU:
				res = ua * ub;
				break;
			case IDIV:
				res = a / b;
				break;
			case IDIVU:
				res = ua / ub;
				break;
			case IDIVSU:
				res = a / ub;
				break;
			case IAND:
				res = a & b;
				break;
			case IOR:
				res = a | b;
				break;
			case IXOR:
				res = a ^ b;
				break;
			case INAND:
				res = ~(a & b);
				break;
			case INOR:
				res = ~(a | b);
				break;
			case IXNOR:
				res = ~(a ^ b);
				break;
			case ISLL:
				res = ua << (b & 0x3f);
				break;
			case ISRL:
				res = ua >> (b & 0x3f);
				break;
			case ISRA:
				res = a >> (b & 0x3f);
				break;
			case IROL:
				res = (a << (b & 0x3f)) | (a >> ((64 - b) & 0x3f));
				break;
			case IROR:
				res = (a >> (b & 0x3f)) | (a << ((64 - b) & 0x3f));
				break;
			case ISLLI:
				res = ua << (b & 0x3f);
				break;
			case ISRLI:
				res = ua >> (b & 0x3f);
				break;
			case ISRAI:
				res = a >> (b & 0x3f);
				break;
			case IROLI:
				res = (ua << (b & 0x3f)) | (ua >> (64 - (b & 0x3f)));
				break;
			case IRORI:
				res = (ua >> (b & 0x3f)) | (ua << (64 - (b & 0x3f)));
				break;
			}
			break;
		case ICHK:
			Rt = 0;
			r1 = a >= b;
			r2 = a < c;
			res = r1 && r2;
			if (!res) {
				ir = 0x03cc0f38;
				goto dc;
			}
			break;
		case IBTFLD:
			bmask = 0;
			for (nn = 0; nn < me-mb+1; nn ++) {
				bmask = (bmask << 1) | 1;
			}
			switch((ir >> 28) & 15) {
			case IBFSET:
				bmask <<= mb;
				res = a | bmask << mb;
				break;
			case IBFCLR:
				bmask <<= mb;
				res = a & ~(bmask << mb);
				break;
			case IBFCHG:
				bmask <<= mb;
				res = a ^ (bmask << mb);
				break;
			case IBFINS:
				bmask <<= mb;
				c &= ~(bmask << mb);
				res = c | ((a & bmask) << mb);
				break;
			case IBFINSI:
				bmask <<= mb;
				c &= ~(bmask << mb);
				res = c | ((Ra & bmask) << mb);
				break;
			case IBFEXT:
				res = (a >> mb) & bmask;
				if ((res & ((bmask + 1) >> 1)) != 0) res |= ~bmask;
				break;
			case IBFEXTU:
				res = (a >> mb) & bmask;
				break;
			}
			break;
		case IADDI:
			res = a + imm;
			break;
		case ISUBFI:
			res = imm - a;
			break;
		case ICMP:
			if (a < imm)
				res = -1LL;
			else if (a==imm)
				res = 0LL;
			else
				res = 1LL;
			break;
		case IMULI:
			res = a * imm;
			break;
		case IMULUI:
			res = ua * imm;
			break;
		case IMULSUI:
			res = a * imm;
			break;
		case IDIVI:
			res = a / imm;
			break;
		case IDIVUI:
			res = ua / imm;
			break;
		case IDIVSUI:
			res = a / imm;
			break;
		case IREMI:
			res = a % imm;
			break;
		case IREMUI:
			res = ua % imm;
			break;
		case IREMSUI:
			res = a % imm;
			break;
		case IANDI:
			res = a & imm;
			break;
		case IORI:
			res = a | imm;
			break;
		case IXORI:
			res = a ^ imm;
			break;
		case IFLOAT:
			switch(ir >> 26) {
			case IFADD:
				dres.ad = opera.ad + operb.ad;
				break;
			case IFSUB:
				dres.ad = opera.ad - operb.ad;
				break;
			case IFCMP:
				if (opera.ad < operb.ad)
					res = -1;
				else if (opera.ad==operb.ad)
					res = 0;
				else
					res = 1;
				break;
			case IFMUL:
				dres.ad = opera.ad * operb.ad;
				break;
			case IFDIV:
				dres.ad = opera.ad / operb.ad;
				break;
			case IFMOV:
				dres.ad = opera.ad;
				break;
			case IFNEG:
				dres.ad = -opera.ad;
				break;
			case IFABS:
				dres.ai = opera.ai & 0x7FFFFFFFFFFFFFFFLL;
				break;
			}
			break;
		case ILDxX:
			ad = a + (b << sc);
			switch (lsfunc) {
			case 0:	// 8 bit load
				res = (system1->Read(ad) >> ((ad & 3) << 3)) & 0xFF;
				if (res & 0x80) res |= 0xFFFFFFFFFFFFFF00LL;
				break;
			case 1:	// 16 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFLL;
				if (res & 0x8000) res |= 0xFFFFFFFFFFFF0000LL;
				break;
			case 2:	// 32 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFFFFFLL;
				if (res & 0x80000000) res |= 0xFFFFFFFF00000000LL;
				break;
			case 3:	// 64 bit load
				rv = (uint64_t)system1->Read(ad) >> (((uint64_t)ad & 3LL) << 3LL);
				switch (ad & 3) {
				case 0:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 32LL);
					break;
				case 1:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 24LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 56LL);
					break;
				case 2:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 16LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 48LL);
					break;
				case 3:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 8LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 40LL);
					break;
				}
				res = rv;
				break;
			}
			break;
		case ILDxXZ:
			ad = a + (b << sc);
			switch (lsfunc) {
			case 0:	// 8 bit load
				res = (system1->Read(ad) >> ((ad & 3) << 3)) & 0xFF;
				break;
			case 1:	// 16 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFLL;
				break;
			case 2:	// 32 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFFFFFLL;
				break;
			case 3:	// 64 bit load
				rv = (uint64_t)system1->Read(ad) >> (((uint64_t)ad & 3LL) << 3LL);
				switch (ad & 3) {
				case 0:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 32LL);
					break;
				case 1:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 24LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 56LL);
					break;
				case 2:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 16LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 48LL);
					break;
				case 3:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 8LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 40LL);
					break;
				}
				res = rv;
				break;
			}
			break;
		case ILDx:
			ad = a + imm;
			switch (lsfunc) {
			case 0:	// 8 bit load
				res = (system1->Read(ad) >> ((ad & 3) << 3)) & 0xFF;
				if (res & 0x80) res |= 0xFFFFFFFFFFFFFF00LL;
				break;
			case 1:	// 16 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFLL;
				if (res & 0x8000) res |= 0xFFFFFFFFFFFF0000LL;
				break;
			case 2:	// 32 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFFFFFLL;
				if (res & 0x80000000) res |= 0xFFFFFFFF00000000LL;
				break;
			case 3:	// 64 bit load
				rv = (uint64_t)system1->Read(ad) >> (((uint64_t)ad & 3LL) << 3LL);
				switch (ad & 3) {
				case 0:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 32LL);
					break;
				case 1:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 24LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 56LL);
					break;
				case 2:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 16LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 48LL);
					break;
				case 3:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 8LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 40LL);
					break;
				}
				res = rv;
				break;
			}
			break;
		case ILDxZ:
			ad = a + imm;
			switch (lsfunc) {
			case 0:	// 8 bit load
				res = (system1->Read(ad) >> ((ad & 3) << 3)) & 0xFF;
				break;
			case 1:	// 16 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFLL;
				break;
			case 2:	// 32 bit load
				rv = (uint64_t)system1->Read(ad) | ((uint64_t)system1->Read(ad + 4) << 32LL);
				res = (rv >> (((uint64_t)ad & 3LL) << 3LL)) & 0xFFFFFFFFLL;
				break;
			case 3:	// 64 bit load
				rv = (uint64_t)system1->Read(ad) >> (((uint64_t)ad & 3LL) << 3LL);
				switch (ad & 3) {
				case 0:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 32LL);
					break;
				case 1:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 24LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 56LL);
					break;
				case 2:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 16LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 48LL);
					break;
				case 3:
					rv = rv | ((uint64_t)system1->Read(ad + 4) << 8LL);
					rv = rv | ((uint64_t)system1->Read(ad + 8) << 40LL);
					break;
				}
				res = rv;
				break;
			}
			break;
		case ISTx:
			ad = a + imm;
			switch (lsfunc) {
			case 0:
				system1->WriteByte(ad, b, 0);
				break;
			case 1:
				system1->WriteWyde(ad, b, 0);
				break;
			case 2:
				system1->WriteTetra(ad, b, 0);
				break;
			case 3:
				system1->WriteOcta(ad, b, 0);
				break;
			}
			break;
		case ISTxX:
			ad = a + (b << sc);
			switch (lsfunc) {
			case 0:
				system1->WriteByte(ad, b, 0);
				break;
			case 1:
				system1->WriteWyde(ad, b, 0);
				break;
			case 2:
				system1->WriteTetra(ad, b, 0);
				break;
			case 3:
				system1->WriteOcta(ad, b, 0);
				break;
			}
			break;
		case IJAL:
			ad = (ir >> 10LL);
			if (ir >> 35)
				ad |= 0xfffffffffc000000LL;
			res = pc;
			pc = ad;
			break;
		case IBAL:
			ad = (ir >> 10LL);
			if (ir >> 35)
				ad |= 0xfffffffffc000000LL;
			res = pc;
			pc = pc + ad - 9;	// -9 = address of this instruction
			break;
		case IJALR:
			ad = a + imm;
			res = pc;
			pc = ad;
			break;
		case IBRK:
			switch((ir >> 30)&3) {
			case 0:	
				epc = opc|km;
				esp = regs[30][rgs];
				break;
			case 1:
				dpc = opc|km;
				dsp = regs[30][rgs];
				break;
			case 2:
				ipc = (immcnt==10) ? (opc-2)|km : (opc - immcnt * 4)|km;
				isp = regs[30][rgs];
				StatusHWI = true;
				im = true;
				break;
			}
			km = true;
			rvecno = (ir >> 17) & 0x1ff;
			ad = vbr + (((ir >> 17) & 0x1ff) << 3);
			pc = system1->Read(ad);
			break;
		case IBEQ:	if (a == b) pc = pc + brdisp - 9; break;
		case IBNE:	if (a != b) pc = pc + brdisp - 9; break;
		case IBLT:	if (a <  b) pc = pc + brdisp - 9; break;
		case IBGE:	if (a >= b) pc = pc + brdisp - 9; break;
		case IBLTU:	if (ua < ub) pc = pc + brdisp - 9; break;
		case IBGEU:	if (ua >= ub) pc = pc + brdisp - 9; break;
			// Branch on bit set or clear
		case IBBC:	if (BIT(ua,ub) == 0LL) pc = pc + brdisp - 9; break;
		case IBBS:	if (BIT(ua,ub) == 1LL) pc = pc + brdisp - 9; break;
		case INOP:	Rt = 0; immcnt = 0; break;
		case IOSR2:
			switch ((ir >> 29LL) & 0x7fLL) {
			case IMTBASE:
				sregs[BIT(ir,26) ? b & 15 : Rb & 15] = a;
				Rt = 0;
				break;
			case IMFBASE:
				res = sregs[Ra & 15];
				break;
			case IBASE:
				mask = 0xffffffffffffffffLL >> (64LL - 28LL);
				res = (a & mask) | (b << 28LL);
				break;
			}
			break;
		default: break;
		}
		//---------------------------------------------------------------------------
		// Writeback stage
		//---------------------------------------------------------------------------
		if (Rt != 0) {
			if (Rt==31 && res==0xC48EE0) {
				regs[Rt][rgs] <= res;
				printf("hi there");
			}
			regs[Rt][rgs] = res;
		}
		for (nn = 0; nn < 64; nn++)
			regs[0][nn] = 0;
	};

int clsCPU::fnRp(__int64 ir)
{
	switch (ir & 7) {
	case 0: return (1);
	case 1: return (3);
	case 2: return (4);
	case 3: return (11);
	case 4: return (12);
	case 5: return (18);
	case 6: return (19);
	case 7: return (20);
	}
}

__int64 clsCPU::DecompressInstruction(__int64 ir)
{
	__int64 tir;

	tir = 0;
	if (ir & 0x40) {
		switch ((ir >> 12) & 0xF) {
		case 0:	// MOV
			tir |= 0xC2;
			tir |= (ir & 0x1fLL) << 8LL;
			tir |= (((ir & 0x0f00LL) >> 8LL) << 14LL);
			tir |= (((ir & 0x0020LL) >> 5LL) << 13LL);
			tir |= (7 << 23);
			break;
		case 1:	// ADD
			tir |= 0xC2;
			tir |= (ir & 0x1fLL) << 8LL;
			tir |= (ir & 0x1fLL) << 13LL;
			tir |= (((ir & 0x0f00LL) >> 8LL) << 19LL);
			tir |= (((ir & 0x0020LL) >> 5LL) << 18LL);
			tir |= (3 << 23);
			tir |= (IADD << 26);
			break;
		case 2:	// JALR
			tir |= IJAL;
			tir |= (ir & 0x1fLL) << 8;
			tir |= (((ir & 0x0f00LL) >> 8LL) << 14LL);
			tir |= (((ir & 0x0020LL) >> 5LL) << 13LL);
			break;
		case 3:
			tir |= INOP;	// reserved (NOP)
			break;
		case 4:		// LH Rt,d[SP]
//			tir |= ILx;
			tir |= 0x80LL;
			tir |= (0x31LL << 8LL);
			tir |= (ir & 0x1fLL) << 13LL;
			tir |= (2LL << 18LL);
			tir |= (((ir >> 5LL) & 1LL) << 20LL);
			tir |= (((ir >> 8LL) & 0xFLL) << 21LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 5:		// LW Rt,d[SP]
//			tir |= ILx;
			tir |= 0x80LL;
			tir |= (0x31LL << 8LL);
			tir |= (ir & 0x1fLL) << 13LL;
			tir |= (4LL << 18LL);
			tir |= (((ir >> 5LL) & 1LL) << 21LL);
			tir |= (((ir >> 8LL) & 0xFLL) << 22LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 6:		// LH Rt,d[FP]
//			tir |= ILx;
			tir |= 0x80LL;
			tir |= (0x30LL << 8LL);
			tir |= (ir & 0x1fLL) << 13LL;
			tir |= (2LL << 18LL);
			tir |= (((ir >> 5LL) & 1LL) << 20LL);
			tir |= (((ir >> 8LL) & 0xFLL) << 21LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 7:		// LW Rt,d[FP]
//			tir |= ILx;
			tir |= 0x80LL;
			tir |= (0x30LL << 8LL);
			tir |= (ir & 0x1fLL) << 13LL;
			tir |= (4LL << 18LL);
			tir |= (((ir >> 5LL) & 1LL) << 21LL);
			tir |= (((ir >> 8LL) & 0xFLL) << 22LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 8:		// SH Rb,d[SP]
//			tir |= ISx;
			tir |= 0x80LL;
			tir |= (31LL << 8LL);
			tir |= (2LL << 13LL);
			tir |= (((ir >> 5LL) & 1LL) << 15LL);
			tir |= (((ir >> 8LL) & 3LL) << 16LL);
			tir |= ((ir & 0x1fLL) << 18LL);
			tir |= (((ir >> 10LL) & 3LL) << 23LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 9:		// SW Rb,d[SP]
//			tir |= ISx;
			tir |= 0x80LL;
			tir |= (31LL << 8LL);
			tir |= (4LL << 13LL);
			tir |= (((ir >> 5LL) & 1LL) << 16LL);
			tir |= (((ir >> 8LL) & 1LL) << 17LL);
			tir |= ((ir & 0x1fLL) << 18LL);
			tir |= (((ir >> 9LL) & 7LL) << 23LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 10:		// SH Rb,d[FP]
//			tir |= ISx;
			tir |= 0x80LL;
			tir |= (30LL << 8LL);
			tir |= (2LL << 13LL);
			tir |= (((ir >> 5LL) & 1LL) << 15LL);
			tir |= (((ir >> 8LL) & 3LL) << 16LL);
			tir |= ((ir & 0x1fLL) << 18LL);
			tir |= (((ir >> 10LL) & 3LL) << 23LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 11:		// SW Rb,d[FP]
//			tir |= ISx;
			tir |= 0x80LL;
			tir |= (30LL << 8LL);
			tir |= (4LL << 13LL);
			tir |= (((ir >> 5LL) & 1LL) << 16LL);
			tir |= (((ir >> 8LL) & 1LL) << 17LL);
			tir |= ((ir & 0x1fLL) << 18LL);
			tir |= (((ir >> 9LL) & 7LL) << 23LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 12:	// LH Rt,d[Ra]
//			tir |= ILx;
			tir |= 0x80LL;
			tir |= (fnRp(ir & 7LL) << 8LL);
			tir |= (fnRp((((ir >> 8LL) & 0xfLL) << 1LL) | (ir >> 5LL) & 1LL) << 13LL);
			tir |= (2LL << 18LL);
			tir |= (((ir >> 3LL) & 3LL) << 20LL);
			tir |= (((ir >> 10LL) & 3LL) << 22LL);
			tir |= (((ir >> 11LL) & 1LL) << 24LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 13:	// LW Rt,d[Ra]
//			tir |= ILx;
			tir |= 0x80LL;
			tir |= (fnRp(ir & 7LL) << 8LL);
			tir |= (fnRp((((ir >> 8LL) & 0xfLL) << 1LL) | (ir >> 5LL) & 1LL) << 13LL);
			tir |= (4LL << 18LL);
			tir |= (((ir >> 3LL) & 3LL) << 21LL);
			tir |= (((ir >> 10LL) & 3LL) << 23LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 14:	// SH Rb,d[Ra]
//			tir |= ISx;
			tir |= 0x80LL;
			tir |= (fnRp(ir & 7LL) << 8LL);
			tir |= (2LL << 13LL);
			tir |= (((ir >> 3LL) & 3LL) << 15LL);
			tir |= (((ir >> 10LL) & 1LL) << 17LL);
			tir |= (fnRp((((ir >> 8LL) & 0xfLL) << 1LL) | (ir >> 5LL) & 1LL) << 18LL);
			tir |= (((ir >> 11LL) & 1LL) << 23LL);
			tir |= (((ir >> 11LL) & 1LL) << 24LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		case 15:	// SW Rb,d[Ra]
//			tir |= ISx;
			tir |= 0x80LL;
			tir |= (fnRp(ir & 7LL) << 8LL);
			tir |= (4LL << 13LL);
			tir |= (((ir >> 3LL) & 3LL) << 16LL);
			tir |= (fnRp((((ir >> 8LL) & 0xfLL) << 1LL) | (ir >> 5LL) & 1LL) << 18LL);
			tir |= (((ir >> 10LL) & 1LL) << 23LL);
			tir |= (((ir >> 11LL) & 1LL) << 24LL);
			tir |= (((ir >> 11LL) & 1LL) << 25LL);
			tir |= (((ir >> 11LL) & 1LL) << 26LL);
			tir |= (((ir >> 11LL) & 1LL) << 27LL);
			tir |= (((ir >> 11LL) & 1LL) << 28LL);
			tir |= (((ir >> 11LL) & 1LL) << 29LL);
			tir |= (((ir >> 11LL) & 1LL) << 30LL);
			tir |= (((ir >> 11LL) & 1LL) << 31LL);
			break;
		}
	}
	else {
		switch ((ir >> 12) & 0xF) {
		case 0:	// ADDI
			if ((ir & 0x1fLL) == 0LL)
				tir |= 0x3d;	// NOP
			else if ((ir & 0x1fLL) == 31LL) {	// ADDI SP
				tir |= IADD;
				tir |= 0x80LL;
				tir |= ((ir & 0x1fLL) << 8LL);
				tir |= ((ir & 0x1fLL) << 13LL);
				tir |= (((ir >> 5LL) & 1LL) << 21LL);
				tir |= (((ir >> 8LL) & 0xfLL) << 22LL);
				tir |= (((ir >> 11LL) & 1) << 26LL);
				tir |= (((ir >> 11LL) & 1) << 27LL);
				tir |= (((ir >> 11LL) & 1) << 28LL);
				tir |= (((ir >> 11LL) & 1) << 29LL);
				tir |= (((ir >> 11LL) & 1) << 30LL);
				tir |= (((ir >> 11LL) & 1) << 31LL);
			}
			else {
				tir |= IADD;
				tir |= 0x80LL;
				tir |= ((ir & 0x1fLL) << 8LL);
				tir |= ((ir & 0x1fLL) << 13LL);
				tir |= (((ir >> 5LL) & 1LL) << 18LL);
				tir |= (((ir >> 8LL) & 0xfLL) << 19LL);
				tir |= (((ir >> 11LL) & 1) << 23LL);
				tir |= (((ir >> 11LL) & 1) << 24LL);
				tir |= (((ir >> 11LL) & 1) << 25LL);
				tir |= (((ir >> 11LL) & 1) << 26LL);
				tir |= (((ir >> 11LL) & 1) << 27LL);
				tir |= (((ir >> 11LL) & 1) << 28LL);
				tir |= (((ir >> 11LL) & 1) << 29LL);
				tir |= (((ir >> 11LL) & 1) << 30LL);
				tir |= (((ir >> 11LL) & 1) << 31LL);
			}
			break;
		case 1:
			if ((ir & 0x1fLL) == 0LL) {		// SYS
				tir |= IBRK;
				tir |= 0x80LL;
				tir |= (((ir >> 5LL) & 1LL) << 8LL);
				tir |= (((ir >> 8LL) & 0xFLL) << 9LL);
				tir |= (1LL << 13LL);
				tir |= (1LL << 21LL);
			}
			else {	// LDI
				tir |= IOR;
				tir |= 0x80LL;
				tir |= ((ir & 0x1fLL) << 13LL);
				tir |= (((ir >> 5LL) & 1LL) << 18LL);
				tir |= (((ir >> 8LL) & 0xfLL) << 19LL);
				tir |= (((ir >> 11LL) & 1) << 23LL);
				tir |= (((ir >> 11LL) & 1) << 24LL);
				tir |= (((ir >> 11LL) & 1) << 25LL);
				tir |= (((ir >> 11LL) & 1) << 26LL);
				tir |= (((ir >> 11LL) & 1) << 27LL);
				tir |= (((ir >> 11LL) & 1) << 28LL);
				tir |= (((ir >> 11LL) & 1) << 29LL);
				tir |= (((ir >> 11LL) & 1) << 30LL);
				tir |= (((ir >> 11LL) & 1) << 31LL);
			}
			break;
		case 2:
			if ((ir & 0x1fLL) == 0LL) {		// RET
//				tir |= IRET;
				tir |= 0x80LL;
				tir |= (31LL << 8LL);
				tir |= (31LL << 13LL);
				tir |= (29LL << 18LL);
				tir |= (((ir >> 5LL) & 1LL) << 23LL);
				tir |= (((ir >> 8LL) & 0xFLL) << 24LL);
			}
			else {	// ANDI
				tir |= IAND;
				tir |= 0x80LL;
				tir |= ((ir & 0x1fLL) << 8LL);
				tir |= ((ir & 0x1fLL) << 13LL);
				tir |= (((ir >> 5LL) & 1LL) << 18LL);
				tir |= (((ir >> 8LL) & 0xFLL) << 19LL);
				tir |= (((ir >> 11LL) & 1) << 23LL);
				tir |= (((ir >> 11LL) & 1) << 24LL);
				tir |= (((ir >> 11LL) & 1) << 25LL);
				tir |= (((ir >> 11LL) & 1) << 26LL);
				tir |= (((ir >> 11LL) & 1) << 27LL);
				tir |= (((ir >> 11LL) & 1) << 28LL);
				tir |= (((ir >> 11LL) & 1) << 29LL);
				tir |= (((ir >> 11LL) & 1) << 30LL);
				tir |= (((ir >> 11LL) & 1) << 31LL);
			}
			break;
		case 3:	// SHLI
			tir |= 0x82LL;
			tir |= ((ir & 0x1fLL) << 8LL);
			tir |= ((ir & 0x1fLL) << 13LL);
			tir |= (((ir >> 5LL) & 1LL) << 18LL);
			tir |= (((ir >> 8LL) & 0xFLL) << 19LL);
			tir |= (15LL << 26LL);
			break;
		case 4:
			switch ((ir >> 4) & 3) {
			case 0:	// SHRI
				tir |= 0x82;
				tir |= (fnRp(ir & 7LL) << 8LL);
				tir |= (fnRp(ir & 7LL) << 13LL);
				tir |= (((ir >> 3LL) & 1LL) << 18LL);
				tir |= (((ir >> 8LL) & 0xFLL) << 19LL);
				tir |= (1LL << 23LL);
				tir |= (15LL << 26LL);
				break;
			case 1:	// ASRI
				tir |= 0x82;
				tir |= (fnRp(ir & 7LL) << 8LL);
				tir |= (fnRp(ir & 7LL) << 13LL);
				tir |= (((ir >> 3LL) & 1LL) << 18LL);
				tir |= (((ir >> 8LL) & 0xFLL) << 19LL);
				tir |= (3LL << 23LL);
				tir |= (15LL << 26LL);
				break;
			case 2:
				tir |= IOR;
				tir |= 0x80;
				tir |= (fnRp(ir & 7LL) << 8LL);
				tir |= (fnRp(ir & 7LL) << 13LL);
				tir |= (((ir >> 3LL) & 1LL) << 18LL);
				tir |= (((ir >> 8LL) & 0xFLL) << 19LL);
				tir |= (((ir >> 11LL) & 1) << 23LL);
				tir |= (((ir >> 11LL) & 1) << 24LL);
				tir |= (((ir >> 11LL) & 1) << 25LL);
				tir |= (((ir >> 11LL) & 1) << 26LL);
				tir |= (((ir >> 11LL) & 1) << 27LL);
				tir |= (((ir >> 11LL) & 1) << 28LL);
				tir |= (((ir >> 11LL) & 1) << 29LL);
				tir |= (((ir >> 11LL) & 1) << 30LL);
				tir |= (((ir >> 11LL) & 1) << 31LL);
				break;
			case 3:
				switch ((ir >> 10) & 3) {
				case 0:	// SUB
					tir |= 0x82;
					tir |= (fnRp(ir & 7LL) << 8LL);
					tir |= (fnRp(ir & 7LL) << 13LL);
					tir |= (fnRp((((ir >> 8LL) & 3LL) << 1LL) | ((ir >> 3LL) & 1LL)) << 18LL);
					tir |= (3LL << 23LL);
					tir |= (ISUB << 26LL);
					break;
				case 1:	// AND
					tir |= 0x82;
					tir |= (fnRp(ir & 7LL) << 8LL);
					tir |= (fnRp(ir & 7LL) << 13LL);
					tir |= (fnRp((((ir >> 8LL) & 3LL) << 1LL) | ((ir >> 3LL) & 1LL)) << 18LL);
					tir |= (3LL << 23LL);
					tir |= (IAND << 26LL);
					break;
				case 2:	// OR
					tir |= 0x82;
					tir |= (fnRp(ir & 7LL) << 8LL);
					tir |= (fnRp(ir & 7LL) << 13LL);
					tir |= (fnRp((((ir >> 8LL) & 3LL) << 1LL) | ((ir >> 3LL) & 1LL)) << 18LL);
					tir |= (3LL << 23LL);
					tir |= (IOR << 26LL);
					break;
				case 3:	// XOR
					tir |= 0x82;
					tir |= (fnRp(ir & 7LL) << 8LL);
					tir |= (fnRp(ir & 7LL) << 13LL);
					tir |= (fnRp((((ir >> 8LL) & 3LL) << 1LL) | ((ir >> 3LL) & 1LL)) << 18LL);
					tir |= (3LL << 23LL);
					tir |= (IXOR << 26LL);
					break;
				}
				break;
			}
			break;
		case 5:	// CALL
			break;
		case 6:	// reserved
			break;
		// Branches are not compressed! because of DPO addressing
		case 7:
//			tir |= IBcc;
			tir |= 0x80LL;
			tir |= ((ir & 3LL) << 16LL);
			tir |= (((ir >> 2LL) & 0xF) << 23LL);
			tir |= (((ir >> 8LL) & 0xF) << 27LL);
			tir |= (((ir >> 11LL) & 1) << 28LL);
			tir |= (((ir >> 11LL) & 1) << 29LL);
			tir |= (((ir >> 11LL) & 1) << 30LL);
			tir |= (((ir >> 11LL) & 1) << 31LL);
			break;
		case 8:
		case 9:
		case 10:
		case 11:
		case 12:
		case 13:
		case 14:
		case 15:
			break;
		}
	}
	return (tir);
}
