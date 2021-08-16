#pragma once
#include "clsDevice.h"
#include "clsKeyboard.h"
extern char refscreen;
extern uint64_t dataBreakpoints[30];
extern int numDataBreakpoints;
extern int runstop;
extern clsKeyboard keybd;
extern volatile unsigned __int8 keybd_status;
extern volatile unsigned __int8 keybd_scancode;

class clsSystem
{
public:
	unsigned int memory[33554432];
	unsigned int scratchpad[8192];
	unsigned int rom[65536];
	unsigned long VideoMem[16384];
	bool VideoMemDirty[4096];
	unsigned int leds;
	int m_z;
	int m_w;
	char write_error;
	unsigned int radr1;
	unsigned int radr2;

	clsSystem();
	void Reset();
	unsigned int Read(uint64_t ad, int sr=0);
	int Write(uint64_t ad, unsigned int dat, unsigned int mask, int cr=0);
	int WriteByte(uint64_t ad, unsigned int dat, int cr = 0);
	int WriteWyde(uint64_t ad, unsigned int dat, int cr = 0);
	int WriteTetra(uint64_t ad, unsigned int dat, int cr = 0);
	int WriteOcta(uint64_t ad, uint64_t dat, int cr = 0);
	uint64_t IFetch(uint64_t ad);
 	int random();
};
