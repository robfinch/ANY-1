#pragma once

#define IBRK    0x00
#define IRR			0x02
#define IR2			0x02
#define IR1			0x01
#define IMEMDB			0x10
#define IMEMSB			0x11
#define ISYNC			0x12
#define IBTFLD	0x22
#define IBFSET			0x0
#define IBFCLR			0x1
#define IBFCHG			0x2
#define IBFINS			0x3
#define IBFINSI			0x4
#define IBFEXT			0x5
#define IBFEXTU			0x6
#define ICMOVEQ		0x28
#define ICMOVNE		0x29
#define IMUX			0x2A
#define IDEMUX		0x2B
#define IXCHG		0x2E
#define ISEI         0x30
#define IWAIT        0x31
#define IRTI         0x32
#define ICHK		0x3B

// RI
#define IADDI		0x04
#define ISUBFI	0x05
#define IMULI		0x06

#define IANDI   0x08
#define IORI    0x09
#define IXORI   0x0A

#define IDIVI		0x10
#define IDIVUI	0x11
#define IDIVSUI	0x12
#define IREMI		0x18
#define IREMUI	0x19
#define IREMSUI	0x1A
#define IMULUI	0x1E
#define IMULSUI	0x26

// R2
#define IAND		0x00
#define IOR			0x01
#define IXOR		0x02
#define IADD    0x04
#define ISUB    0x05
#define IMUL		0x06
#define INAND		0x08
#define INOR		0x09
#define IXNOR		0x0A
#define IDIV		0x10
#define IDIVU		0x11
#define IDIVSU	0x12
#define IMULU		0x1E
#define ICMP    0x20
#define IMULSU	0x26
#define IMIN		0x38
#define IMAX		0x39
#define ISLL		0x40
#define ISRL		0x41
#define ISRA		0x42
#define IROL		0x43
#define IROR		0x44
#define ISLLI		0x48
#define ISRLI		0x49
#define ISRAI		0x4A
#define IROLI		0x4B
#define IRORI		0x4C

#define IFLOAT	0x0B
#define IFADD		0x04
#define IFSUB		0x05
#define IFCMP		0x06
#define IFMUL		0x08
#define IFDIV		0x09
#define IFLT2FIX	    0x12
#define IFIX2FLT	    0x13
#define IFMOV		0x10
#define IFNEG        0x14
#define IFABS		0x15
#define IFSIGN		0x16
#define IFMAN		0x17
#define IFNABS		0x18
#define IFTX			0x20
#define IFCX			0x21
#define IFEX			0x22
#define IFDX			0x23
#define IFRM			0x24
#define IFSYNC		0x36
#define IREX		0x0D
#define ICSR		0x0E
#define IEXEC	0x0F

#define IENTER	0x3C
#define INOP    0x3F
#define IJAL		0x40
#define IBAL		0x41
#define IJALR		0x42
#define IBLT    0x48
#define IBGE    0x49
#define IBLTU   0x4A
#define IBGEU   0x4B
#define IBBC		0x4C
#define IBBS		0x4D
#define IBEQ    0x4E
#define IBNE    0x4F

#define EXI0		0x50
#define EXI1		0x51
#define EXI2		0x52
#define EXI3		0x53
#define EXI4		0x54

#define ILDx		0x60
#define ILDxX		0x61
#define ILDxZ		0x64
#define ILDxXZ	0x65
#define ISTx		0x70
#define ISTxX		0x71

