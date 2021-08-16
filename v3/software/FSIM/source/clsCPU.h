#include "Instructions.h"

#pragma once

#define FLT_SGB		0x34

class clsSystem;

class clsSegDesc
{
public:
	uint64_t base;
	uint64_t limit;
};

class clsTLBEntry
{
public:
	unsigned int ppn;
	unsigned int vpn;
	unsigned int X;
	unsigned int W;
	unsigned int R;
	unsigned int C;
	unsigned int U;
	unsigned int A;
	unsigned int D;
	unsigned int G;
	unsigned int ASID;
	uint64_t pack() {
		uint64_t rv;

		rv = (ASID << 56LL) |
				(G << 55LL) |
				(D << 54LL) |
				(A << 53LL) |
				(U << 52LL) |
				(C << 51LL) |
				(R << 50LL) |
				(W << 49LL) |
				(X << 48LL) |
				(vpn << 28LL) |
				(ppn)
				;
		return (rv);
	};
};

class clsTLB
{
public:
	clsTLBEntry entries[4][1024];
public:
	void Reset()
	{
		int count;

		for (count = 4080; count < 4096; count++)
			switch ((count >> 10LL) & 3LL) {
			case 0:
			case 1:
			case 2:
//				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].e = 0x00EF000000000000LL | (((count >> 10LL) & 3LL) << 44LL) | ((count & 0xfffLL) << 32LL) | (count & 0xfffLL);
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].ASID = 0;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].G = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].D = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].A = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].U = 0;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].C = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].R = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].W = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].X = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].vpn = (count >> 10LL) & 0xFFLL;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].ppn = (count & 0xfffLL);
				break;
			case 3:
//				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].e = 0x00EF000000000000LL | (15LL << 44LL) | ((count & 0xfffLL) << 32LL) | (count & 0xfffLL);
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].ASID = 0;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].G = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].D = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].A = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].U = 0;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].C = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].R = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].W = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].X = 1;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].vpn = 0xffLL;
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].ppn = (255LL << 10LL) | (count & 0x3ffLL);
				break;
			}
	};
	uint64_t ReadWrite(uint64_t a0, uint64_t a1) {
		uint64_t olde;
		uint64_t way = (a0 >> 10LL) & 3LL;
		uint64_t entryno = a0 & 0x3ffLL;
		static int randway = 0;

		olde = entries[way][entryno].pack();
		if (a0 >> 63LL) {
			if ((a0 >> 15LL) & 1LL) {
				entries[randway][entryno].ASID = a1 >> 56LL;
				entries[randway][entryno].G = (a1 >> 55LL) & 1LL;
				entries[randway][entryno].D = (a1 >> 54LL) & 1LL;
				entries[randway][entryno].A = (a1 >> 53LL) & 1LL;
				entries[randway][entryno].U = (a1 >> 52LL) & 1LL;
				entries[randway][entryno].C = (a1 >> 51LL) & 1LL;
				entries[randway][entryno].R = (a1 >> 50LL) & 1LL;
				entries[randway][entryno].W = (a1 >> 49LL) & 1LL;
				entries[randway][entryno].X = (a1 >> 48LL) & 1LL;
				entries[randway][entryno].vpn = (a1 >> 28LL) & 0xfffffLL;
				entries[randway][entryno].ppn = (a1 >> 0LL) & 0xfffffLL;
			}
			else {
				entries[way][entryno].ASID = a1 >> 56LL;
				entries[way][entryno].G = (a1 >> 55LL) & 1LL;
				entries[way][entryno].D = (a1 >> 54LL) & 1LL;
				entries[way][entryno].A = (a1 >> 53LL) & 1LL;
				entries[way][entryno].U = (a1 >> 52LL) & 1LL;
				entries[way][entryno].C = (a1 >> 51LL) & 1LL;
				entries[way][entryno].R = (a1 >> 50LL) & 1LL;
				entries[way][entryno].W = (a1 >> 49LL) & 1LL;
				entries[way][entryno].X = (a1 >> 48LL) & 1LL;
				entries[way][entryno].vpn = (a1 >> 28LL) & 0xfffffLL;
				entries[way][entryno].ppn = (a1 >> 0LL) & 0xfffffLL;
			}
			randway++;
			if (randway > 2)
				randway = 0;
		}
		return (olde);
	}
	uint64_t Map(uint8_t ASID, uint64_t virt) {
		clsTLBEntry e0, e1, e2, e3;
		e0 = entries[0][(virt >> 14LL) & 0x3ffLL];
		if (e0.vpn == (virt >> 24LL) & 0xffffLL && (e0.ASID == ASID || e0.G))
			return ((e0.ppn << 14LL) | (virt & 0x3fffLL));
		//if (e0.es.vpn == (virt >> 24LL) & 0xffffLL && (e0.es.ASID == ASID || e0.es.G))
		//	return ((e0.es.ppn << 14LL) | (virt & 0x3fffLL));
		e1 = entries[1][(virt >> 14LL) & 0x3ffLL];
		if (e1.vpn == (virt >> 24LL) & 0xffffLL && (e1.ASID == ASID || e1.G))
			return ((e1.ppn << 14LL) | (virt & 0x3fffLL));
		//if (e1.es.vpn == (virt >> 24LL) & 0xffffLL && (e1.es.ASID == ASID || e1.es.G))
		//	return ((e1.es.ppn << 14LL) | (virt & 0x3fffLL));
		e2 = entries[2][(virt >> 14LL) & 0x3ffLL];
		if (e2.vpn == (virt >> 24LL) & 0xffffLL && (e2.ASID == ASID || e2.G))
			return ((e2.ppn << 14LL) | (virt & 0x3fffLL));
		//if (e2.es.vpn == (virt >> 24LL) & 0xffffLL && (e2.es.ASID == ASID || e2.es.G))
		//	return ((e2.es.ppn << 14LL) | (virt & 0x3fffLL));
		e3 = entries[3][(virt >> 14LL) & 0x3ffLL];
		if (e3.vpn == (virt >> 24LL) & 0xffffLL && (e3.ASID == ASID || e3.G))
			return ((e3.ppn << 14LL) | (virt & 0x3fffLL));
		return (0xffffffffffffffffLL);
	};
};


// Currently unaligned memory access is not supported.
// Made more complicated by the fact it's a 64 bit machine.

typedef	union tag_opval {
	__int64 ai;
	double ad;
} opval;

class clsCPU
{
	opval opera,operb,operc;
	__int64 a, b, c, res, res2, imm, sp_res;
	opval dres;
	unsigned __int64 ua, ub;
	uint64_t reglist;
	__int64 sir,ir2;
	bool StatusHWI;
	int Ra,Rb,Rc;
	int Rt,Rt2;
	int mb,me;
	int spr;
	int Bn;
	unsigned int regLR;
	unsigned int imm1;
	unsigned int imm2;
	int64_t exi_imm;
	char hasPrefix;
	int immcnt;
	unsigned int opcode;
	unsigned int func;
	int i1;
	int nn;
	unsigned int bmask;
	int brdisp;
	int r1,r2,r3;
public:
	uint8_t asid;
	uint64_t ecause;
	clsTLB tlb;
	char isRunning;
	char brk;
	unsigned __int64 ir, xir, wir;
	unsigned int rgs;
	unsigned __int64 regs[32][64];
	unsigned __int64 vregs[32][64];
	uint32_t sregs[1024];		// selectors
	clsSegDesc desc[1024];	// descriptor cache
	double dregs[32];
	uint64_t gdt;
	uint64_t pc;
	uint64_t eip;
	uint64_t ecs;
	uint64_t ecsbnd;
	uint64_t tvec[8];
	uint64_t svec[8];
	uint64_t bvec[8];
	unsigned int pcs[40];
	unsigned int dpc;
	unsigned int epc;
	unsigned int ipc;
	unsigned __int64 dsp;
	unsigned __int64 esp;
	unsigned __int64 isp;
	unsigned int vbr;
	unsigned dbad0;
	unsigned dbad1;
	unsigned dbad2;
	unsigned dbad3;
	unsigned __int64 dbctrl;
	unsigned __int64 dbstat;
	unsigned __int64 tick;
	char km;
	bool irq;
	bool nmi;
	char im;
	int imcd;
	volatile short int vecno;
	short int rvecno;			// registered vector number
	unsigned __int64 cr0;
	bool exi;
	clsSystem *system1;

	void Reset();
	void BuildConstant();
	void Step();
	int fnRp(__int64 ir);
	__int64 DecompressInstruction(__int64 ir);
};
