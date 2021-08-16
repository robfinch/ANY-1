#pragma once

class clsTLBEntry
{
public:
	union {
		uint64_t e;
		struct {
			unsigned int ppn : 20;
			unsigned int pad1 : 12;
			uint16_t vpn;
			unsigned int X : 1;
			unsigned int W : 1;
			unsigned int R : 1;
			unsigned int C : 1;
			unsigned int U : 1;
			unsigned int A : 1;
			unsigned int D : 1;
			unsigned int G : 1;
			uint8_t ASID;
		} es;
	};
};

class clsTLB
{
	clsTLBEntry entries[4][1024];
public:
	void Reset()
	{
		int count;

		for (count = 0; count < 4096; count++)
			switch ((count >> 10LL) & 3LL) {
			case 0:
			case 1:
			case 2:
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].e = 0x00EF000000000000LL | (((count >> 10LL) & 3LL) << 44LL) | ((count & 0xfffLL) << 32LL) | (count & 0xfffLL);
				break;
			case 3:
				entries[(count >> 10LL) & 3LL][count & 0x3ffLL].e = 0x00EF000000000000LL | (15LL << 44LL) | ((count & 0xfffLL) << 32LL) | (count & 0xfffLL);
				break;
			}
	};
	uint64_t ReadWrite(uint64_t a0, uint64_t a1) {
		uint64_t olde;
		uint64_t way = (a0 >> 10LL) & 3LL;
		uint64_t entryno = a0 & 0x3ffLL;
		olde = entries[way][entryno].e;
		if (a0 >> 63LL) {
			entries[way][entryno].e = a1;
		}
		return (olde);
	}
	uint64_t Map(uint8_t ASID, uint64_t virt) {
		clsTLBEntry e0, e1, e2, e3;
		e0 = entries[0][(virt >> 14LL) & 0x3ffLL];
		if (e0.es.vpn == (virt >> 24LL) & 0xffffLL && (e0.es.ASID == ASID || e0.es.G))
			return ((e0.es.ppn << 14LL) | (virt & 0x3fffLL));
		e1 = entries[1][(virt >> 14LL) & 0x3ffLL];
		if (e1.es.vpn == (virt >> 24LL) & 0xffffLL && (e1.es.ASID == ASID || e1.es.G))
			return ((e1.es.ppn << 14LL) | (virt & 0x3fffLL));
		e2 = entries[2][(virt >> 14LL) & 0x3ffLL];
		if (e2.es.vpn == (virt >> 24LL) & 0xffffLL && (e2.es.ASID == ASID || e2.es.G))
			return ((e2.es.ppn << 14LL) | (virt & 0x3fffLL));
		e3 = entries[3][(virt >> 14LL) & 0x3ffLL];
		if (e3.es.vpn == (virt >> 24LL) & 0xffffLL && (e3.es.ASID == ASID || e3.es.G))
			return ((e3.es.ppn << 14LL) | (virt & 0x3fffLL));
		return (0xffffffffffffffffLL);
	};
};
