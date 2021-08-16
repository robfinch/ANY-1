#include "stdafx.h"

extern clsPIC pic1;

clsSystem::clsSystem() {
	int nn;
	for (nn = 0; nn < sizeof(memory); nn+=4) {
		memory[nn>>2] = 0;
	}
	Reset();
};
void clsSystem::Reset()
{
	int nn;
	m_z = 88888888;
	m_w = 12345678;
	for (nn = 0; nn < 4096; nn++) {
		VideoMem[nn] = random();
		VideoMemDirty[nn] = true;
	}
	write_error = false;
	runstop = false;
	cpu1.system1 = this;
	refscreen = true;
};
	unsigned int clsSystem::Read(uint64_t adin, int sr) {
		int rr;
		unsigned __int8 sc;
		unsigned __int8 st;
		unsigned int ad = cpu1.tlb.Map(cpu1.asid,adin);
		if (sr) {
			if (radr1 == 0)
				radr1 = ad;
			else if (radr2 == 0)
				radr2 = ad;
			else {
				if (random()&1)
					radr2 = ad;
				else
					radr1 = ad;
			}
		}
		if (ad < 134217728) {
			return memory[ad >> 2];
		}
		else if (((ad & 0xFFF00000) >> 20) == 0xFF4) {
			return (scratchpad[(ad & 32767) >> 2]);
		}
		else if ((ad & 0xfffc0000)==0xfffc0000) {
			return (rom[(ad >> 2) & 0xffff]);
		}
		else if ((ad & 0xFFF00000)==0xFF800000) {
			return VideoMem[(ad>>2)& 0xFFF];
		}
		else if (keybd.IsSelected(ad)) {
			switch(ad & 0x1) {
			case 0:
				sc = keybd.Get();
				rr = ((int)sc<<24)|((int)sc << 16)|((int)sc<<8)|sc;
				break;
			case 1:
				st = keybd.GetStatus();
				rr = ((int)st<<24)|((int)st<<16)|((int)st<<8)|st;
				keybd_status = st;
				break;
			}
			return rr;
		}
		else if (pic1.IsSelected(ad)) {
			return pic1.Read(ad);
		}
		return 0;
	};
	int clsSystem::Write(uint64_t adin, unsigned int dat, unsigned int mask, int cr) {
		int nn;
		int ret;

		unsigned int ad = cpu1.tlb.Map(cpu1.asid,adin);
		if (cr && (ad!=radr1 && ad!=radr2)) {
			ret = false;
			goto j1;
		}
		if (cr) {
			if (ad==radr1)
				radr1 = 0x00000000;
			if (ad==radr2)
				radr2 = 0x00000000;
		}
		if (ad < 134217728) {
			if (ad >= 0x10000 && ad < 0x20000) {
				write_error = true;
				ret = true;
				goto j1;
			}
			if ((ad & 0xfffffff0)==0x00c431a0) {
				ret = true;
			}
			switch(mask) {
			case 0xF:
				memory[ad>>2] = dat;
				break;
			case 0x1:
				memory[ad >> 2] &= 0xFFFFFF00;
				memory[ad >> 2] |= dat & 0xFF;
				break;
			case 0x2:
				memory[ad >> 2] &= 0xFFFF00FF;
				memory[ad >> 2] |= (dat & 0xFF) << 8;
				break;
			case 0x4:
				memory[ad >> 2] &= 0xFF00FFFF;
				memory[ad >> 2] |= (dat & 0xFF) << 16;
				break;
			case 0x8:
				memory[ad >> 2] &= 0x00FFFFFF;
				memory[ad >> 2] |= (dat & 0xFF) << 24;
				break;
			case 0x3:
				memory[ad >> 2] &= 0xFFFF0000;
				memory[ad >> 2] |= dat & 0xFFFF;
				break;
			case 0x6:
				memory[ad >> 2] &= 0xFF0000FF;
				memory[ad >> 2] |= (dat & 0xFFFF) << 8;
				break;
			case 0xC:
				memory[ad >> 2] &= 0x0000FFFF;
				memory[ad >> 2] |= (dat & 0xFFFF) << 16;
				break;
			}
		}
		else if (((ad & 0xFFF00000) >> 20) == 0xFF4) {
			unsigned int ad1 = (ad & 32767) >> 2;
			switch(mask) {
			case 0xF:
				scratchpad[ad1] = dat;
				break;
			case 0x1:
				scratchpad[ad1] &= 0xFFFFFF00;
				scratchpad[ad1] |= dat & 0xFF;
				break;
			case 0x2:
				scratchpad[ad1] &= 0xFFFF00FF;
				scratchpad[ad1] |= (dat & 0xFF) << 8;
				break;
			case 0x4:
				scratchpad[ad1] &= 0xFF00FFFF;
				scratchpad[ad1] |= (dat & 0xFF) << 16;
				break;
			case 0x8:
				scratchpad[ad1] &= 0x00FFFFFF;
				scratchpad[ad1] |= (dat & 0xFF) << 24;
				break;
			case 0x3:
				scratchpad[ad1] &= 0xFFFF0000;
				scratchpad[ad1] |= dat & 0xFFFF;
				break;
			case 0x6:
				scratchpad[ad1] &= 0xFF0000FF;
				scratchpad[ad1] |= (dat & 0xFFFF) << 8;
				break;
			case 0xC:
				scratchpad[ad1] &= 0x0000FFFF;
				scratchpad[ad1] |= (dat & 0xFFFF) << 16;
				break;
			}
		}
		else if ((ad & 0xFFFF0000)==0xFF910000) {
			leds = dat;
		}
		else if ((ad & 0xfffc0000)==0xfffc0000) {
			rom[(ad>>2) & 0xffff] = dat;
		}
		else if ((ad & 0xFFF00000)==0xFF800000) {
			VideoMem[(ad>>2)& 0xFFF] = dat;
			VideoMemDirty[(ad>>2)&0xfff] = true;
			refscreen = true;
		}
		else if (keybd.IsSelected(ad)) {
			switch(ad & 1) {
			case 1:	keybd_status = 0; pic1.irqKeyboard = keybd.GetStatus()==0x80; break;
			}
		}
		else if (pic1.IsSelected(ad)) {
			pic1.Write(ad,dat,0x3);
		}
		ret = true;
j1:
		for (nn = 0; nn < numDataBreakpoints; nn++) {
			if (ad==dataBreakpoints[nn]) {
				runstop = true;
			}
		}
		return ret;
	};
	int clsSystem::WriteByte(uint64_t ad, unsigned int dat, int cr) {
		unsigned int mask;
		unsigned int dt = dat << ((ad & 3) << 3);
		switch (ad & 3) {
		case 0:	mask = 1; break;
		case 1: mask = 2; break;
		case 2: mask = 4; break;
		case 3:	mask = 8; break;
		}
		return (Write(ad & 0xFFFFFFFCL, dt, mask, cr));
	};
	int clsSystem::WriteWyde(uint64_t ad, unsigned int dat, int cr) {
		unsigned int mask;
		unsigned int dt = dat << ((ad & 3) << 3);
		int rv;
		switch (ad & 3) {
		case 0:	mask = 3; break;
		case 1: mask = 6; break;
		case 2: mask = 12; break;
		case 3:	mask = 8; break;
		}
		rv = Write(ad & 0xFFFFFFFCL, dt, mask, cr);
		if ((ad & 3) == 3)
			rv = rv & Write((ad + 4) & 0xFFFFFFFCL, dat >> 8, 1, cr);
		return (rv);
	};
	int clsSystem::WriteTetra(uint64_t ad, unsigned int dat, int cr) {
		unsigned int mask;
		unsigned int dt = dat << ((ad & 3) << 3);
		int rv;
		switch (ad & 3) {
		case 0:	mask = 15; break;
		case 1: mask = 14; break;
		case 2: mask = 12; break;
		case 3:	mask = 8; break;
		}
		rv = Write(ad & 0xFFFFFFFCL, dt, mask, cr);
		if ((ad & 3) != 0) {
			dt = dat >> ((4-(ad & 3)) << 3);
			switch (ad & 3) {
			case 1: mask = 1; break;
			case 2: mask = 3; break;
			case 3:	mask = 7; break;
			}
			rv = rv & Write((ad + 4) & 0xFFFFFFFCL, dt, 1, cr);
		}
		return (rv);
	};
	int clsSystem::WriteOcta(uint64_t ad, uint64_t dat, int cr) {
		unsigned int mask;
		int rv;
		uint64_t dt = dat << (((uint64_t)ad & 3LL) << 3LL);
		switch (ad & 3) {
		case 0:	mask = 15; break;
		case 1: mask = 14; break;
		case 2: mask = 12; break;
		case 3:	mask = 8; break;
		}
		rv = Write(ad & 0xFFFFFFFCL, dt, mask, cr);
		dt = dat >> ((4LL - ((uint64_t)ad & 3LL)) << 3LL);
		rv = rv & Write((ad + 4) & 0xFFFFFFFCL, dt, 15, cr);
		if ((ad & 3) != 0) {
			dt = dat >> ((8LL - ((uint64_t)ad & 3LL)) << 3LL);
			switch (ad & 3) {
			case 1: mask = 1; break;
			case 2: mask = 3; break;
			case 3:	mask = 7; break;
			}
			rv = rv & Write((ad + 8) & 0xFFFFFFFCL, dt, mask, cr);
		}
		return (rv);
	};
	uint64_t clsSystem::IFetch(uint64_t ipin) {
		int rr;
		unsigned __int8 sc;
		unsigned __int8 st;
		uint64_t rv;
		ipin &= 0x1ffffffffLL;
		uint64_t ip = (cpu1.tlb.Map(cpu1.asid,ipin>>1LL) << 1LL) | (ipin & 1LL);
		if (ip < 134217728 * 2) {
			rv = memory[ip >> 3];
			rv = rv | ((uint64_t)(memory[(ip >> 3) + 1]) << 32LL);
		}
		else if ((((ip >> 1) & 0xFFF00000) >> 20) == 0xFF4) {
			rv = scratchpad[(ip >> 3) & 8191];
			rv = rv | ((uint64_t)(scratchpad[((ip >> 3) + 1) & 8191]) << 32LL);
		}
		else if (((ip >> 1) & 0xfffc0000) == 0xfffc0000) {
			rv = rom[(ip >> 3) & 65535];
			rv = rv | ((uint64_t)(rom[((ip >> 3) + 1) & 65535]) << 32LL);
		}
		else if (((ip >> 1) & 0xFF800000) == 0xFF800000) {
			rv = VideoMem[(ip >> 3) & 16383];
			rv = rv | ((uint64_t)(VideoMem[((ip >> 3) + 1) & 16383]) << 32LL);
		}
		else
			rv = 0;
		rv = (rv >> (uint64_t)((ip & 7) << 2)) & 0xfffffffffLL;
		return (rv);
	};
	int clsSystem::random() {
		m_z = 36969 * (m_z & 65535) + (m_z >> 16);
		m_w = 18000 * (m_w & 65535) + (m_w >> 16);
		return (m_z << 16) + m_w;
	};

