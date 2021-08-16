#include "stdafx.h"
#include <string>
#include "Instructions.h"
#include "Disassem.h"


uint64_t insn;
uint64_t imm1,imm2;
int immcnt;
int opcode;
int func;

std::string Ra()
{
	char buf[40];
	std::string str;
	str = "$x" + std::string(_itoa((insn >> 14LL) & 0x1fLL,buf,10));
	return str;
}

std::string Rb()
{
	char buf[40];
	std::string str;
	int Rb;

	Rb = (insn >> 20LL) & 0x7fLL;
	if (Rb & 0x40)
		str = "#" + std::string(_itoa(Rb & 0x3f, buf, 16));
	else
		str = "$x" + std::string(_itoa(Rb & 0x1f,buf,10));
	return str;
}

std::string Rbi()
{
	char buf[40];
	std::string str;
	int Rb;

	Rb = (insn >> 20LL) & 0x7fLL;
	if (Rb & 0x40)
		str = "$x" + std::string(_itoa(Rb & 0x3f, buf, 16));
	else
		str = "[$x" + std::string(_itoa(Rb & 0x1f, buf, 10)) + "]";
	return str;
}

std::string Bb()
{
	char buf[40];
	std::string str;
	int Rb;

	Rb = (insn >> 20LL) & 0x7fLL;
	if (Rb & 0x40)
		str = "#" + std::string(_itoa(Rb & 0x3f, buf, 16));
	else
		str = "$b" + std::string(_itoa(Rb & 0x1f, buf, 10));
	return str;
}

std::string Rc()
{
	char buf[40];
	std::string str;
	if ((insn >> 27LL) & 1LL)
		str = "#$" + std::string(_itoa(((insn >> 19LL) << 5LL) | ((insn >> 14LL) & 0x1fLL), buf, 16));
	else
		str = "$x" + std::string(_itoa((insn >> 14LL) & 0x1f,buf,10));
	return (str);
}

std::string Rt()
{
	char buf[40];
	std::string str;
	if ((insn & 0x7fLL)==IJAL || (insn & 0x7fLL)==IBAL)
		str = "$x" + std::string(_itoa((insn >> 8LL) & 0x3LL, buf, 10));
	else
		str = "$x" + std::string(_itoa((insn >> 8LL) & 0x1fLL,buf,10));
	return str;
}

std::string Rt4()
{
	char buf[40];
	std::string str;
	str = "$x" + std::string(_itoa(((insn >> 12) & 0xf)|((insn & 1) << 4),buf,10));
	return str;
}

std::string FPa()
{
	char buf[40];
	std::string str;
	str = "$FP" + std::string(_itoa((insn >> 14LL) & 0x1fLL,buf,10));
	return str;
}

std::string FPb()
{
	char buf[40];
	std::string str;
	str = "$FP" + std::string(_itoa((insn >> 20LL) & 0x1fLL,buf,10));
	return str;
}

std::string FPt()
{
	char buf[40];
	std::string str;
	str = "$FP" + std::string(_itoa((insn >> 8LL) & 0x1fLL,buf,10));
	return str;
}

std::string Bn()
{
	char buf[40];
	std::string str;
	str = "$B" + std::string(_itoa((insn >> 11) & 0x3f,buf,10));
	return str;
}

std::string Sa()
{
	char buf[40];
	std::string str;
	str = std::string(_itoa((insn >> 20LL) & 0x3f,buf,16));
	return str;
}

std::string IncAmt()
{
	char buf[40];
	std::string str;
	str = std::string(_itoa((insn >> 12) & 0x1f,buf,16));
	return str;
}

std::string Spr()
{
	char buf[40];
	int spr;

	std::string str;
	spr = (insn >> 17) & 0xFf;
	switch(spr) {
	case 0: str = "CR0"; break;
	case 4: str = "TICK"; break;
	case 7: str = "DPC"; break;
	case 8: str = "IPC"; break;
	case 9: str = "EPC"; break;
	case 10: str = "VBR"; break;
	case 11: str = "BEAR"; break;
	case 12: str = "VECNO"; break;
	case 15: str = "ISP"; break;
	case 16: str = "DSP"; break;
	case 17: str = "ESP"; break;
	case 50: str = "DBAD0"; break;
	case 51: str = "DBAD1"; break;
	case 52: str = "DBAD2"; break;
	case 53: str = "DBAD3"; break;
	case 54: str = "DBCTRL"; break;
	case 55: str = "DBSTAT"; break;
	default:	str = std::string(_itoa(spr,buf,10));
	}
	return str;
}

static std::string CallConstant()
{
  static char buf[50];
  int sir;

  sir = insn;
  sprintf(buf,"$%X", (sir >> 10LL));
  return std::string(buf);
}

static std::string DisassemConstant()
{
  static char buf[50];
  int sir;

  sir = insn;
  if (immcnt == 1) {
    sprintf(buf,"$%X", (imm1 << 16)|(insn>>16));
  }
  else
    sprintf(buf,"$%X", (sir >> 20LL));
  return std::string(buf);
}

static std::string DisassemMemConstant(bool store)
{
	static char buf[50];
	int sir;
	int64_t imm;

	sir = insn;
	if (store) {
		imm = ((sir >> 8LL) & 0x3f) | (((sir >> 27LL) & 0x1fLL) << 6LL);
		if ((sir >> 31LL) & 1LL)
			imm |= 0xfffffffffffff000LL;
		//if (exi) {
		//	imm &= 0x7ffLL | exi_imm;
		//	exi = false;
		//}
	}
	else {
		imm = (sir >> 20LL) & 0xfffLL;
		if ((sir >> 31LL) & 1LL)
			imm |= 0xfffffffffffff000LL;
		//if (exi) {
		//	imm &= 0x7ffLL | exi_imm;
		//	exi = false;
		//}
	}

	//if (immcnt == 1) {
	//	sprintf(buf, "$%X", (imm1 << 16) | (insn >> 16));
	//}
	//else
		sprintf(buf, "$%08I64X", imm);
	return std::string(buf);
}

static std::string DisassemConstant9()
{
  static char buf[50];
  int sir;

  sir = insn;
  sprintf(buf,"$%X", ((sir >> 7) & 0x1ff)<< 3);
  return std::string(buf);
}


static std::string DisassemConstant4()
{
  static char buf[50];
  int sir;

  sir = insn;
	sir >>= 12;
	sir &= 0xF;
	if (sir&8)
		sir |= 0xFFFFFFF0;
    sprintf(buf,"$%X", sir);
    return std::string(buf);
}


static std::string DisassemConstant4x8()
{
  static char buf[50];
  int sir;

  sir = insn;
	sir >>= 12;
	if (sir&0x8)
		sir |= 0xFFFFFFF0;
	sir <<= 3;
  sprintf(buf,"$%X", sir);
  return std::string(buf);
}


static std::string DisassemConstant4u()
{
  static char buf[50];
  int sir;

  sir = insn;
	sir >>= 12;
	sir &= 0xF;
  sprintf(buf,"$%X", sir);
  return std::string(buf);
}


static std::string DisassemBccDisplacement(unsigned int bad)
{
  static char buf[50];
  int sir;
	int brdisp;

  sir = insn;
	brdisp = ((sir >> 8LL) & 0x3fLL) | (((sir >> 19LL) & 1LL) << 6LL) | ((sir >> 27LL) << 7LL);
	if (sir >> 35LL)
		brdisp = brdisp | 0xffffffffffff0000LL;
  sprintf(buf,"$%X", brdisp + bad);
  return (std::string(buf));
}


static std::string DisassemMemAddress()
{
  static char buf[50];
  int sir;
	std::string str;

  sir = insn;
	str = DisassemMemConstant((insn & 0x78LL)==0x68LL);
  if (((insn >> 14LL) & 0x1FLL) != 0)
    sprintf(buf,"[x%d]",((insn >> 14LL) & 0x1FLL));
  else
    sprintf(buf,"");
  return str+std::string(buf);
}

static std::string DisassemMbMe()
{
	static char buf[50];

	sprintf(buf, "#%d,#%d", (insn>>16) & 0x3f,(insn>>22) &0x3f);
	return std::string(buf);
}

static std::string DisassemIndexedAddress(int opt)
{
  static char buf[50];
  int sir;
	std::string str;
	int Ra = (insn >> 14LL) & 0x1fLL;
	int Rb = (insn >> 20LL) & 0x1fLL;
	int sc = (insn >> 27LL) & 7LL;
	int offs = 0;

	sc = 1 << sc;

  sir = insn;
	//if (offs != 0) {
	//	sprintf(buf,"$%X",offs);
	//	str = std::string(buf);
	//}
	//else
		str = std::string("");
		if (opt) {
			sprintf(buf, "[x%d+??", Ra);
			str += std::string(buf);
			goto j1;
		}
		else {
			if (Rb && Ra)
				sprintf(buf, "[R%d+R%d", Ra, Rb);
			else if (Ra) {
				sprintf(buf, "[R%d]", Ra);
				str += std::string(buf);
				return str;
			}
			else if (Rb)
				sprintf(buf, "[R%d", Rb);
		}
	str += std::string(buf);
j1:
	if (sc > 1)
		sprintf(buf, "*%d]", sc);
	else
		sprintf(buf,"]");
	str += std::string(buf);
    return str;
}

static std::string DisassemJali()
{
	char buf[50];
	int Ra = (insn >> 14LL) & 0x1fLL;
	int Rb = (insn >> 20LL) & 0x1fLL;
	int Rt = (insn >> 8LL) & 0x1fLL;

	if (Rt==0) {
		sprintf(buf, "JMP    (%s)", DisassemMemAddress().c_str());
	}
	else if (Rt==31) {
		sprintf(buf, "JSR    (%s)", DisassemMemAddress().c_str());
	}
	else {
		sprintf(buf, "JAL    R%d,(%s)",Rt, DisassemMemAddress().c_str());
	}
	return std::string(buf);
}

static std::string DisassemJal(bool bal)
{
	char buf[50];
	int Ra = (insn >> 14LL) & 0x1fLL;
	int Rb = (insn >> 20LL) & 0x1fLL;
	int Rt = (insn >> 8LL) & 0x3LL;

	if (bal)
		sprintf(buf, "BAL");
	else if (Rt == 0)
		sprintf(buf, "JMP");
	else
		sprintf(buf, "JAL");
	if (Rt==0) {
		sprintf(&buf[3], "    %s", DisassemMemAddress().c_str());
	}
	else {
		sprintf(&buf[3], "    x%d,%s",Rt, DisassemMemAddress().c_str());
	}
	return std::string(buf);
}

static std::string DisassemBrk()
{
	char buf[50];
	sprintf(buf, "BRK    #%d", (insn>>8LL) & 0xffLL);
	return std::string(buf);
}


std::string Disassem(std::string sad, std::string sinsn, uint64_t dad, unsigned int *ad1)
{
	char buf[20];
	std::string str;
	static int first = 1;
	int Rbb = (insn >> 11LL) & 0x1fLL;
	int nn;

	if (first) {
		immcnt = 0;
		first = 0;
	}

	insn = strtoull(sinsn.c_str(),0,16);
	opcode = insn & 0x7fLL;
	func = (insn >> 29LL) & 0x7fLL;
	*ad1 = dad + 4;
	switch (opcode)
	{
	case IR2:
		switch ((insn >> 29LL) & 0x7fLL)
		{
			//case ISEI:	str = "SEI"; break;
			//case IWAIT:	str = "WAI"; break;
			//case IRTI:	str = "RTI"; break;
		case IADD:
			str = "ADD    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case ISUB:
			str = "SUB    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case ICMP:
			str = "CMP    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IMUL:
			str = "MUL    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IMULU:
			str = "MULU   " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IMULSU:
			str = "MULSU  " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IDIV:
			str = "DIV    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IDIVU:
			str = "DIVU   " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IDIVSU:
			str = "DIVSU  " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IREM:
			str = "REM    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IREMU:
			str = "REMU   " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IREMSU:
			str = "REMSU  " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IAND:
			str = "AND    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IOR:
			if (Rbb == 0)
				str = "MOV    " + Rt() + "," + Ra();
			else
				str = "OR     " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IXOR:
			str = "XOR    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case ISLL:
			str = "SLL    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case ISRL:
			str = "SRL    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case ISRA:
			str = "SRA    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IROL:
			str = "ROL    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case IROR:
			str = "ROR    " + Rt() + "," + Ra() + "," + Rb();
			immcnt = 0;
			return str;
		case ISLLI:
			str = "SLL    " + Rt() + "," + Ra() + ",#" + Sa();
			immcnt = 0;
			return str;
		case ISRLI:
			str = "SRL    " + Rt() + "," + Ra() + ",#" + Sa();
			immcnt = 0;
			return str;
		case ISRAI:
			str = "SRA    " + Rt() + "," + Ra() + ",#" + Sa();
			immcnt = 0;
			return str;
		case IROLI:
			str = "ROL    " + Rt() + "," + Ra() + ",#" + Sa();
			immcnt = 0;
			return str;
		case IRORI:
			str = "ROR    " + Rt() + "," + Ra() + ",#" + Sa();
			immcnt = 0;
			return str;
		}
		break;
	case EXI0:
		sprintf(buf, "#$%I64X", (insn >> 8LL));
		str = "EXI0   " + std::string(buf); return (str);
		break;
	case EXI1:
		sprintf(buf, "#$%I64X", (insn >> 8LL));
		str = "EXI1   " + std::string(buf); return (str);
		break;
	case IREGLST0:
	case IREGLST1:
	case IREGLST2:
	case IREGLST3:
		sprintf(buf, "REGLST #$%I64X", (insn & 3LL) | ((insn >> 8LL) << 2LL));
		return (std::string(buf));
	case ILDx:
		switch ((insn >> 32LL) & 15LL) {
		case 0:	str = "LDB    " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 1:	str = "LDW    " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 2:	str = "LDT    " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 3:	str = "LDO    " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 13:	str = "LDM    " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 14:	str = "LEA    " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		}
		break;
	case ILDxZ:
		switch ((insn >> 32LL) & 15LL) {
		case 0:	str = "LDBU   " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 1:	str = "LDWU   " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 2:	str = "LDTU   " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 3:	str = "LDOU   " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 14:	str = "LEA    " + Rt() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		}
		break;
	case ILDxX:
		switch ((insn >> 32LL) & 15LL) {
		case 0:	str = "LDBX   " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 1:	str = "LDWX   " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 2:	str = "LDTX   " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 3:	str = "LDOX   " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 13:	str = "LDMX   " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 14:	str = "LEAX   " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		}
		break;
	case ILDxXZ:
		switch ((insn >> 32LL) & 15LL) {
		case 0:	str = "LDBUX  " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 1:	str = "LDWUX  " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 2:	str = "LDTUX  " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 3:	str = "LDOUX  " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		case 14:	str = "LEAX   " + Rt() + "," + DisassemIndexedAddress(0); immcnt = 0; return (str);
		}
		break;
	case IPOP:
		switch ((insn >> 32LL) & 15LL) {
		case 1:	str = "POP    " + Ra(); immcnt = 0; return (str);
		case 2:	str = "POP    " + Ra() + "," + Rb(); immcnt = 0; return (str);
		case 4:
			sprintf(buf, "#%d", (int)((insn >> 20LL) & 0xfffLL));
			str = "UNLINK " + std::string(buf);
			immcnt = 0;
			return (str);
		case 5:
			sprintf(buf, "#%d", (int)((insn >> 20LL) & 0xfffLL));
			str = "LEAVE  " + std::string(buf);
			immcnt = 0;
			return (str);
		}
		break;
	case ISTx:
		switch ((insn >> 32LL) & 15LL) {
		case 0:	str = "STB    " + Rb() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 1:	str = "STW    " + Rb() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 2:	str = "STT    " + Rb() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 3:	str = "STO    " + Rb() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		case 13:	str = "STM    " + Rb() + ", " + DisassemMemAddress(); immcnt = 0; return (str);
		}
		break;
	case ISTxX:
		switch ((insn >> 32LL) & 15LL) {
		case 0:	str = "STBX   " + Rb() + "," + DisassemIndexedAddress(1); immcnt = 0; return (str);
		case 1:	str = "STWX   " + Rb() + "," + DisassemIndexedAddress(1); immcnt = 0; return (str);
		case 2:	str = "STTX   " + Rb() + "," + DisassemIndexedAddress(1); immcnt = 0; return (str);
		case 3:	str = "STOX   " + Rb() + "," + DisassemIndexedAddress(1); immcnt = 0; return (str);
		}
		break;
	case IPUSH:
		switch ((insn >> 32LL) & 15LL) {
		case 1:	str = "PUSH   " + Ra(); immcnt = 0; return (str);
		case 2:	str = "PUSH   " + Ra() + "," + Rb(); immcnt = 0; return (str);
		}
		break;
	case IBTFLD:
		switch((insn >> 29)&7) {
		case IBFSET:	str = "BFSET   " + Rt() + "," + Ra() + "," + DisassemMbMe(); break;
		case IBFCLR:	str = "BFCLR   " + Rt() + "," + Ra() + "," + DisassemMbMe(); break;
		case IBFCHG:	str = "BFCHG   " + Rt() + "," + Ra() + "," + DisassemMbMe(); break;
		case IBFINS:	str = "BFINS   " + Rt() + "," + Ra() + "," + DisassemMbMe(); break;
//		case BFINSI:	str = "BFINSI " + Rt() + "," + Ra() + "," + DisassemMbMe(); break;
		case IBFEXT:	str = "BFEXT   " + Rt() + "," + Ra() + "," + DisassemMbMe(); break;
		case IBFEXTU:	str = "BFEXTU  " + Rt() + "," + Ra() + "," + DisassemMbMe(); break;
		}
		immcnt = 0;
		return str;
	case ICHK:
		str = "CHK    " + Rt() +"," + Ra() + "," + Bn();
		immcnt = 0;
		return str;
	case IADDI:
		str = "ADD    " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IMULI:
		str = "MUL    " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IMULUI:
		str = "MULU   " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IMULSUI:
		str = "MULSU  " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IDIVI:
		str = "DIV    " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IDIVUI:
		str = "DIVU   " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IDIVSUI:
		str = "DIVSU  " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IREMI:
		str = "REM    " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IREMUI:
		str = "REMU   " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IREMSUI:
		str = "REMSU  " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IANDI:
		str = "AND    " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IORI:
		if (((insn >> 20LL) & 0x1fLL) == 0)
			str = "MOV    " + Rt() + "," + Ra();
		else
			str = "OR     " + Rt() + "," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IXORI:
		str = "EOR    " + Rt() +"," + Ra() + ",#" + DisassemConstant();
		immcnt = 0;
		return str;
	case IFLOAT:
		switch ((insn>>26LL)&0x3fLL) {
		case IFADD:
			str = "FADD   " + FPt() +"," + FPa() + "," + FPb();
			immcnt = 0;
			return str;
		case IFSUB:
			str = "FSUB   " + FPt() +"," + FPa() + "," + FPb();
			immcnt = 0;
			return str;
		case IFCMP:
			str = "FCMP   " + Rt() +"," + FPa() + "," + FPb();
			immcnt = 0;
			return str;
		case IFMUL:
			str = "FMUL   " + FPt() +"," + FPa() + "," + FPb();
			immcnt = 0;
			return str;
		case IFDIV:
			str = "FDIV   " + FPt() +"," + FPa() + "," + FPb();
			immcnt = 0;
			return str;
		case IFMOV:
			str = "FMOV   " + FPt() +"," + FPa();
			immcnt = 0;
			return str;
		case IFNEG:
			str = "FNEG   " + FPt() +"," + FPa();
			immcnt = 0;
			return str;
		case IFABS:
			str = "FABS   " + FPt() +"," + FPa();
			immcnt = 0;
			return str;
		}
		break;
	case IBEQ:
		str = "BEQ    " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IBNE:
		str = "BNE    " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IBLT:
		str = "BLT    " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IBGE:
		str = "BGE    " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IBLTU:
		str = "BLTU   " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IBGEU:
		str = "BGEU   " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IBBC:
		str = "BBC    " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IBBS:
		str = "BBS    " + Ra() + "," + Rb() + "," + DisassemBccDisplacement(dad);
		immcnt = 0;
		return str;
	case IJAL:
		str = DisassemJal(false);
		immcnt = 0;
		return str;
	case IBAL:
		str = DisassemJal(true);
		immcnt = 0;
		return str;
	case IJALR:
		if ((((insn >> 8LL) & 0x1fLL) == 0LL) && ((insn >> 14LL) & 0x1fLL) == 1LL && ((insn >> 20LL) && 0xffffLL)==0LL)
			str = "RET    ";
		else {
			str = "JALR   " + Rt() + "," + Ra() + ",#" + DisassemConstant();
		}
		return (str);
	case IBRK:
		str = DisassemBrk();
		immcnt = 0;
		return str;
	case INOP:
		str = "NOP    ";
		immcnt = 0;
		return str;
	case IOSR2:
		switch (func) {
		case ISYNC:
			str = "SYNC   ";
			return (str);
		case IMTBASE:
			str = "MTBASE [" + Rb() + "]," + Ra();
			return (str);
		case IMFBASE:
			str = "MFBASE " + Rt() + ",[" + Rb() + "]";
			return (str);
		case IMTBND:
			str = "MTBND  [" + Rb() + "]," + Ra();
			return (str);
		case IMFBND:
			str = "MFBND  " + Rt() + ",[" + Rb() + "]";
			return (str);
		case IBASE:
			str = "BASE   " + Rt() + "," + Ra() + "," + Rb();
			return (str);
		case IMTSEL:
			str = "MTSEL  " + Rbi() + "," + Ra();
			return (str);
		case IMFSEL:
			str = "MFSEL  " + Rt() + "," + Rbi();
			return (str);
		case ITLBRW:
			str = "TLBRW  " + Rt() + "," + Ra() + "," + Rb();
			return (str);
		}
		break;
	case ICSR:
		nn = ((insn >> 18LL) & 2LL) | ((insn >> 13LL) & 1LL);
		switch (nn) {
		case 0:
			str = "CSRRD  " + Rt() + "," + Ra() + ",#" + DisassemConstant();
			break;
		case 1:
			str = "CSRRW  " + Rt() + "," + Ra() + ",#" + DisassemConstant();
			break;
		case 2:
			str = "CSRRS  " + Rt() + "," + Ra() + ",#" + DisassemConstant();
			break;
		case 3:
			str = "CSRRC  " + Rt() + "," + Ra() + ",#" + DisassemConstant();
			break;
		}
		return (str);
	case IMOD:
		str = "IMOD   " + Rt() + "," + Rc();
		return (str);
	}
	immcnt = 0;
	return "?????";
}

std::string Disassem(unsigned int ad, uint64_t dat, unsigned int *ad1)
{
	char buf1[20];
	char buf2[20];

	sprintf(buf1,"%06X", ad);
	sprintf(buf2,"%09I64X", dat);
	return (Disassem(std::string(buf1),std::string(buf2),ad,ad1));
}
