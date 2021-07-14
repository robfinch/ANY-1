
package any1_pkg;

// Define only one of the following to control the external bus size
`define CPU_B128		1'b1
//`define CPU_B64			1'b1
//`define CPU_B32			1'b1

`define AMSB		31
`define ABITS		31:-1

//`ifdef CPU_B128
`define SELL		15:0
`define SELH    31:16
`define DATL		127:0
`define DATH    255:128
//`endif
`ifdef CPU_B64
`define SELL		7:0
`define SELH    15:8
`define DATL		63:0
`define DATH    127:64
`endif
`ifdef CPU_B32
`define SELL		3:0
`define SELH    7:4
`define DATL		31:0
`define DATH    63:32
`endif

parameter VALUE_SIZE = 64;

`define SEG_SHIFT	14'd0
//`define SUPPORT_EXEC		1'b1
//`define SUPPORT_MYST		1'b1
`define SUPPORT_FLOAT		1'b1
//`define SUPPORT_VECTOR	1'b1
//`define SUPPORT_GRAPHICS	1'b1
`define SUPPORT_VICTIM_CACHE	1'b1
`define ANY1_TLB	1'b1

// Uncomment the following to support key checking on memory access
//`define SUPPORT_KEYCHK		1'b1

parameter ROB_ENTRIES = 8;
// Architectural integer registers
parameter NUM_AIREGS = 32;
parameter NUM_AVREGS = 32;

parameter TRUE  = 1'b1;
parameter FALSE = 1'b0;
parameter HIGH  = 1'b1;
parameter LOW   = 1'b0;
parameter VAL		= 1'b1;
parameter INV		= 1'b0;
parameter AWID  = 32;
parameter WID 	= 64;

parameter TAG_PTR		= 4'h0;
parameter TAG_INT		= 4'h1;
parameter TAG_FLT		= 4'h2;
parameter TAG_PST		= 4'h6;
parameter TAG_BOOL	= 4'h7;
parameter TAG_U8		= 4'h8;
parameter TAG_U21		= 4'h9;

parameter OM_USER		= 3'd0;
parameter OM_SUPER	= 3'd1;
parameter OM_HYPER	= 3'd2;
parameter OM_MACHINE	= 3'd3;
parameter OM_DEBUG	= 3'd4;

parameter BRK		= 8'h00;
parameter R1		= 8'h01;
parameter R2		= 8'h02;
parameter R3		= 8'h03;
parameter VM		= 8'h3E;

// R3 ops
parameter MUX			= 6'h04;
parameter CMOVNZ	= 6'h06;
parameter SLLP		= 6'h10;
parameter SLLPI		= 6'h11;
parameter PTRDIF	= 6'h18;
parameter CHK		= 6'h22;
// R2 ops
parameter AND		= 6'h00;
parameter OR		= 6'h01;
parameter XOR		= 6'h02;
parameter ADD		= 6'h04;
parameter SUB		= 6'h05;
parameter MUL		= 6'h06;
parameter NAND	= 6'h08;
parameter NOR		= 6'h09;
parameter XNOR	= 6'h0A;
parameter MULU	= 6'h0E;
parameter MULH	= 6'h0F;
parameter DIV		= 6'h10;
parameter DIVU	= 6'h11;
parameter DIVSU	= 6'h12;
parameter MULSU =	6'h16;
parameter DIF		= 6'h18;
parameter MULF	= 6'h1C;
parameter MULSUH= 6'h1D;
parameter MULUH = 6'h1E;
parameter MYST	= 6'h1F;
parameter CMP		= 6'h20;
parameter SEQ		= 6'h26;
parameter SNE		= 6'h27;
parameter MIN		= 6'h28;
parameter MAX		= 6'h29;
parameter SLT		= 6'h2C;
parameter SGE		= 6'h2D;
parameter SLTU	= 6'h2E;
parameter SGEU	= 6'h2F;
parameter BMMOR	= 6'h30;
parameter BMMXOR= 6'h31;
parameter BMMTOR =6'h32;
parameter BMMTXOR=6'h33;
parameter SETM	= 6'h36;
parameter VSLLV	= 6'h38;
parameter VSRLV	= 6'h39;
parameter VEX		= 6'h3A;
parameter VEINS	= 6'h3B;
parameter RW_COEFF = 6'h3E;
parameter SLL		= 7'h40;
parameter SRL		= 7'h41;
parameter SRA		= 7'h42;
parameter ROL		= 7'h43;
parameter ROR		= 7'h44;
parameter SLLI	= 7'h48;
parameter SRLI	= 7'h49;
parameter SRAI	= 7'h4A;
parameter ROLI	= 7'h4B;
parameter RORI  = 7'h4C;

// R1 ops
parameter CTLZ	= 6'h00;
parameter CTLO	= 6'h01;
parameter CTPOP	= 6'h02;
parameter NOT		= 6'h04;
parameter NEG		= 6'h05;
parameter ABS		= 6'h06;
parameter NABS	= 6'h07;
parameter TRANSFORM = 6'h11;
parameter V2BITS=	6'h18;
parameter BITS2V=	6'h19;
parameter SQRT	= 6'h1B;
parameter VCMPRSS = 6'h1C;
parameter VCIDX	= 6'h1D;
parameter VSCAN	= 6'h1E;
parameter CLIP	= 6'h20;

// RI ops
parameter ADDI	= 8'h04;
parameter SUBFI	= 8'h05;
parameter MULI	= 8'h06;
parameter ANDI  = 8'h08;
parameter ORI		= 8'h09;
parameter XORI	= 8'h0A;
parameter MULUI	= 8'h0E;
parameter DIVI	= 8'h10;
parameter DIVUI	= 8'h11;
parameter DIVSUI= 8'h12;
parameter MULFI	= 8'h15;
parameter MULSUI= 8'h16;
parameter PERM	= 8'h17;
parameter U10NDX= 8'h1A;
parameter BYTNDX= 8'h1A;
parameter WYDNDX= 8'h1B;
parameter BTFLD	=	8'h1C;
parameter MYSTI	= 8'h1F;

parameter CHKI	= 8'h22;
parameter U21NDX= 8'h23;
parameter SEQI	= 8'h26;
parameter SNEI	= 8'h27;
parameter SLTI	= 8'h28;
parameter SGTI	= 8'h29;
parameter SLTUI	= 8'h2A;
parameter SGTUI = 8'h2B;

parameter MADD	= 8'h30;
parameter MSUB	= 8'h31;
parameter NMADD	= 8'h32;
parameter NMSUB	= 8'h33;
parameter F1		= 8'h34;
parameter F2		= 8'h35;
parameter F3		= 8'h36;
parameter F4		= 8'h37;
parameter LINK	= 8'h3C;
parameter UNLINK= 8'h3D;
parameter NOP  	= 8'h3F;

parameter CSR		= 8'h0F;
parameter CSRR	= 2'd0;
parameter CSRW	= 2'd1;
parameter CSRS	= 2'd2;
parameter CSRC	= 2'd3;
//parameter CSRRW	= 3'd4;

// {OS} ops
parameter SYS		= 8'h07;

parameter EXEC	= 6'h07;
parameter PUSHQ = 6'h08;
parameter POPQ  =	6'h09;
parameter PEEKQ = 6'h0A;
parameter PUSHQI= 6'h0C;
parameter POPQI = 6'h0D;
parameter PEEKQI= 6'h0E;
parameter REX		= 6'h10;
parameter PFI		= 6'h11;
parameter WFI		= 6'h12;
parameter RTE		= 6'h13;
parameter MVSEG	= 6'h1D;
parameter TLBRW	= 6'h1E;
parameter SYNC	= 6'h1F;
parameter CSAVE = 6'h20;
parameter CRESTORE = 6'h21;

parameter BLT		= 8'h48;
parameter BGE		= 8'h49;
parameter BLTU	= 8'h4A;
parameter BGEU	= 8'h4B;
parameter BBC		= 8'h4C;
parameter BBS		= 8'h4D;
parameter BEQ		= 8'h4E;
parameter BNE		= 8'h4F;

parameter EXI0	= 8'h50;
parameter EXI1	= 8'h51;
parameter EXI2	= 8'h52;
parameter EXI3  = 8'h53;
parameter EXI4  = 8'h54;
parameter IMOD	= 8'h58;
parameter BRMOD	= 8'h5A;
parameter STRIDE= 8'h5B;
parameter RGLST0= 8'h5C;
parameter RGLST1= 8'h5D;
parameter RGLST2= 8'h5E;
parameter RGLST3= 8'h5F;
parameter VSYS	= 8'h87;

parameter VIMOD	= 8'hD8;
parameter VBTFLDX=8'hD9;
parameter VSTRIDE=8'hDB;

parameter LDx		= 8'h60;
parameter LDxX	= 8'h61;
parameter LDxZ	= 8'h64;
parameter LDxXZ	= 8'h65;
parameter POP		= 8'h67;
parameter STx		= 8'h68;
parameter STxX	= 8'h69;
parameter PUSH	= 8'h6F;

parameter BEQZ	= 8'h78;
parameter BNEZ	= 8'h79;

parameter JAL		= 8'h40;
parameter BAL		= 8'h41;
parameter JALR	= 8'h42;
parameter RTS		= 8'h7B;
parameter CALL  = 8'h7C;

parameter LDB = 4'd0;
parameter LDW = 4'd1;
parameter LDT = 4'd2;
parameter LDO = 4'd3;
parameter LDH = 4'd4;
parameter LDOR = 4'd6;
parameter LDBU = 4'd8;
parameter LDWU = 4'd9;
parameter LDTU = 4'd10;
parameter LDOU = 4'd11;
parameter LSM  = 4'd13;
parameter LEA	 = 4'd14;
parameter CACHE	= 4'd15;
parameter STCR = 4'd6;
parameter STPTR = 4'd7;

parameter LOAD = 3'd0;
parameter STORE = 3'd1;
parameter TLB = 3'd2;
parameter CACHE2 = 3'd3;
parameter LEA2 = 3'd4;
parameter RTS2 = 3'd5;
parameter M_CALL	= 3'd6;
parameter LOADZ = 3'd7;		// unsigned load

// FLT1
parameter FMOV	= 6'h00;
parameter I2F		= 6'h02;
parameter F2I		= 6'h03;
parameter FSQRT	= 6'h08;
parameter FRM		= 6'h14;
parameter CPYSGN= 6'h18;
parameter SGNINV= 6'h19;
parameter FABS	= 6'h20;
parameter FNABS	= 6'h21;
parameter FNEG	= 6'h22;

// FLT2
parameter FMIN	= 6'h02;
parameter FMAX	= 6'h03;
parameter FADD	= 6'h04;
parameter FSUB	= 6'h05;
parameter FMUL	= 6'h08;
parameter FDIV	= 6'h09;
parameter FCMP	= 6'h10;
parameter FSEQ	= 6'h11;
parameter FSLT	= 6'h12;
parameter FSLE	= 6'h13;
parameter FSNE	= 6'h14;
parameter FCMPB	= 6'h15;
parameter FSETM = 6'h16;

// FLT3
parameter FMA		= 6'h00;
parameter FMS		= 6'h01;
parameter FNMA	= 6'h02;
parameter FNMS	= 6'h03;

parameter VR1		= 8'h81;
parameter VR2		= 8'h82;
parameter VR3		= 8'h83;
parameter VF1		= 8'hB4;
parameter VF2		= 8'hB5;
parameter VF3		= 8'hB6;
parameter VF4		= 8'hB7;

parameter VADDI	= 8'h84;
parameter VSUBFI= 8'h85;
parameter VMULI	= 8'h86;
parameter VANDI = 8'h88;
parameter VORI	= 8'h89;
parameter VXORI	= 8'h8A;
parameter VMULUI= 8'h8E;
parameter VDIVI	= 8'h90;
parameter VDIVUI= 8'h91;
parameter VDIVSUI= 8'h92;
parameter VMULFI	= 8'h95;
parameter VMULSUI= 8'h96;
parameter VPERM	= 8'h97;
parameter VU10NDX= 8'h9A;
parameter VBYTNDX= 8'h9A;
parameter VWYDNDX= 8'h9B;
parameter VBTFLD	=	8'h9C;
parameter VMYSTI	= 8'h9F;

parameter VCHKI	= 8'hA2;
parameter VU21NDX= 8'hA3;
parameter VEXTU	= 8'hA4;
parameter VSEQI	= 8'hA6;
parameter VSNEI	= 8'hA7;
parameter VSLTI	= 8'hA8;
parameter VSGTI	= 8'hA9;
parameter VSLTUI	= 8'hAA;
parameter VSGTUI = 8'hAB;
parameter VEXT		= 8'hAC;

parameter LDSx	= 8'hE2;
parameter LDxVX	= 8'hE3;
parameter CVLDSx= 8'hE6;
parameter STSx	= 8'hF2;
parameter STxVX = 8'hF3;
parameter CVSTSx= 8'hF6;

parameter MAND	= 6'h00;
parameter MOR		= 6'h01;
parameter MXOR	= 6'h02;
parameter VMADD	= 6'h04;
parameter MSLL	= 6'h06;
parameter MSRL	= 6'h07;
parameter MFILL	= 6'h0C;
parameter MPOP	= 6'h0D;
parameter MFIRST= 6'h0E;
parameter MLAST	= 6'h0F;
parameter MTM		= 6'h10;
parameter MFM		= 6'h11;
parameter MTVL	= 6'h12;
parameter MFVL	= 6'h13;


parameter NOP_INSN = {4{NOP}};

parameter CSR_CAUSE	= 16'h?006;
parameter CSR_SEMA	= 16'h?00C;
parameter CSR_FSTAT	= 16'h?014;
parameter CSR_ASID	= 16'h101F;
parameter CSR_KEYS	= 16'b0001_0000_0010_00??;
parameter CSR_KEYTBL= 16'h1024;
parameter CSR_SCRATCH=16'h?041;
parameter CSR_MCR0	= 16'h3000;
parameter CSR_MHARTID = 16'h3001;
parameter CSR_TICK	= 16'h3002;
parameter CSR_MBADADDR	= 16'h3007;
parameter CSR_MTVEC = 16'h303?;
parameter CSR_MPMSTACK	= 16'h3040;
parameter CSR_MSTATUS	= 16'h3044;
parameter CSR_MVSTEP= 16'h3046;
parameter CSR_MVTMP	= 16'h3047;
parameter CSR_MEIP	=	16'h3048;
parameter CSR_DCR0	= 16'h4000;
parameter CSR_DHARTID = 16'h4001;
parameter CSR_DTVEC = 16'h403?;
parameter CSR_DPMSTACK	= 16'h4040;
parameter CSR_DSTUFF0	= 16'h4042;
parameter CSR_DSTUFF1	= 16'h4043;
parameter CSR_DSTATUS	= 16'h4044;
parameter CSR_DVSTEP= 16'h4046;
parameter CSR_DVTMP	= 16'h4047;
parameter CSR_DEIP	=	16'h4048;
parameter CSR_DTCBPTR=16'h4050;
parameter CSR_TIME	= 16'h?FE0;
parameter CSR_MTIME	= 16'h3FE0;
parameter CSR_DTIME	= 16'h4FE0;

// Cause
/*
parameter FLT_RESET		= 8'h01;
parameter FLT_MACHINE_CHECK	= 8'h02;
parameter FLT_DATA_STORAGE	= 8'h03;
parameter FLT_INSTRUCTION_STORAGE = 8'h04;
parameter FLT_EXTERNAL = 8'h05;
parameter FLT_ALIGNMENT = 8'h06;
parameter FLT_PROGRAM = 8'h07;
parameter FLT_FPU_UNAVAILABLE = 8'h08;
parameter FLT_DECREMENTER = 8'h09;
parameter FLT_RESERVED_A = 8'h0A;
parameter FLT_RESERVED_B = 8'h0B;
parameter FLT_SYSTEM_CALL = 8'h0C;
parameter FLT_TRACE = 8'h0D;
parameter FLT_FP_ASSIST = 8'h0E;
parameter FLT_RESERVED = 8'h2F;
*/
parameter FLT_NONE	= 8'h00;
parameter FLT_TLBMISS = 8'h04;
parameter FLT_IADR	= 8'h22;
parameter FLT_CHK		= 8'h27;
parameter FLT_KEY		= 8'h31;
parameter FLT_WRV		= 8'h32;
parameter FLT_RDV		= 8'h33;
parameter FLT_WD		= 8'h36;
parameter FLT_UNIMP	= 8'h37;
parameter FLT_PMA		= 8'h3D;
parameter FLT_NMI		= 8'hFE;

// Instruction fetch
parameter IFETCH1 = 6'd1;
parameter IFETCH2 = 6'd2;
parameter IFETCH3 = 6'd3;
parameter IFETCH4 = 6'd4;
parameter DECODE = 6'd5;
parameter REGFETCH1 = 6'd6;
parameter REGFETCH2 = 6'd7;
parameter EXECUTE = 6'd8;
parameter WRITEBACK = 6'd9;
parameter IFETCH6 = 6'd10;
parameter MEMORY1 = 6'd11;
parameter MEMORY2 = 6'd12;
parameter MEMORY3 = 6'd13;
parameter MEMORY4 = 6'd14;
parameter MEMORY5 = 6'd15;
parameter MEMORY6 = 6'd16;
parameter MEMORY7 = 6'd17;
parameter MEMORY8 = 6'd18;
parameter MEMORY9 = 6'd19;
parameter MEMORY10 = 6'd20;
parameter MEMORY11 = 6'd21;
parameter MEMORY12 = 6'd22;
parameter MEMORY13 = 6'd23;
parameter MEMORY14 = 6'd24;
parameter MEMORY15 = 6'd25;
parameter MEMORY2b = 6'd26;
parameter IFETCH7 = 6'd27;
parameter PAM	 = 6'd28;
parameter TMO = 6'd29;
parameter PAGEMAPA = 6'd30;
parameter CSR1 = 6'd31;
parameter CSR2 = 6'd32;
parameter DATA_ALIGN = 6'd33;
parameter MEMORY_KEYCHK1 = 6'd34;
parameter MEMORY_KEYCHK2 = 6'd35;
parameter MEMORY_KEYCHK3 = 6'd36;
parameter FLOAT = 6'd37;
parameter INSTRUCTION_ALIGN = 6'd38;
parameter IFETCH5 = 6'd39;
parameter MEMORY1a = 6'd40;
parameter MEMORY6a = 6'd41;
parameter MEMORY11a = 6'd42;
parameter IFETCH2a = 6'd43;
parameter REGFETCH3 = 6'd44;
parameter EXPAND_CI = 6'd45;
parameter IFETCH3a = 6'd46;
parameter MEMORY1c = 6'd47;
parameter DFETCH2 = 6'd48;
parameter DFETCH3 = 6'd49;
parameter DFETCH3a = 6'd50;
parameter DFETCH4 = 6'd51;
parameter DFETCH5 = 6'd52;
parameter TLB1 = 6'd53;
parameter TLB2 = 6'd54;
parameter TLB3 = 6'd55;
parameter MEMORY1d = 6'd56;
parameter MEMORY1e = 6'd57;
parameter KYLD = 6'd58;
parameter KYLD2 = 6'd59;
parameter KYLD3 = 6'd60;
parameter KYLD3a = 6'd61;
parameter KYLD4 = 6'd62;
parameter KYLD5 = 6'd63;

parameter MUL1 = 3'd1;
parameter MUL2 = 3'd2;
parameter MUL3 = 3'd3;

parameter DIV1 = 3'd1;
parameter DIV2 = 3'd2;
parameter DIV3 = 3'd3;
parameter DIV4 = 3'd4;

parameter ST_FP1 = 3'd1;
parameter ST_FP2 = 3'd2;
parameter ST_FP3 = 3'd3;

parameter ST_GR1 = 3'd1;
parameter ST_GR2 = 3'd2;
parameter ST_GR3 = 3'd3;

parameter FU_EXEC	= 3'd0;
parameter FU_MUL = 3'd1;
parameter FU_DIV = 3'd2;
parameter FU_MEM = 3'd3;
parameter FU_FP	= 3'd4;
parameter FU_GR = 3'd5;

parameter pL1CacheLines = 64;
parameter pL1LineSize = 512;
parameter pL1ICacheLines = 512;
parameter pL1ICacheLineSize = 548;
localparam pL1Imsb = $clog2(pL1ICacheLines-1)-1+6;
parameter RSTIP = {32'hFFFC0300,1'b0};
parameter BRKIP = {32'hFFFC0000,1'b0};
parameter RIBO = 1;

typedef logic [`ABITS] Address;
typedef logic [AWID-13:0] BTBTag;
typedef logic [7:0] ASID;
typedef logic [63:0] Data;
typedef logic [3:0] DataTag;

typedef logic [NUM_AIREGS-1:1] RegBitList;

typedef struct packed
{
	logic [3:0] func;
	logic [11:0] disp;
	logic Ta;
	logic [4:0] Ra;
	logic Tt;
	logic [4:0] Rt;
	logic [7:0] opcode;
} LoadInst;

typedef struct packed
{
	logic [3:0] func;
	logic [1:0] pad2;
	logic [2:0] Sc;
	logic [1:0] Tb;
	logic [4:0] Rb;
	logic Ta;
	logic [4:0] Ra;
	logic Tt;
	logic [4:0] Rt;
	logic [7:0] opcode;
} NdxLoadInst;

typedef struct packed
{
	logic [3:0] func;
	logic [4:0] disphi;
	logic [1:0] Tb;
	logic [4:0] Rb;
	logic Ta;
	logic [4:0] Ra;
	logic [5:0] displo;
	logic [7:0] opcode;
} StoreInst;

typedef struct packed
{
	logic [3:0] func;
	logic [1:0] pad2;
	logic [2:0] Sc;
	logic [1:0] Tb;
	logic [4:0] Rb;
	logic Ta;
	logic [4:0] Ra;
	logic [5:0] empty;
	logic [7:0] opcode;
} NdxStoreInst;

typedef struct packed
{
	logic [15:0] imm;
	logic Ta;
	logic [4:0] Ra;
	logic Tt;
	logic [4:0] Rt;
	logic [7:0] opcode;
} RIInst;

typedef struct packed
{
	logic [6:0] func;
	logic [1:0] pad2;
	logic [1:0] Tb;
	logic [4:0] Rb;
	logic Ta;
	logic [4:0] Ra;
	logic Tt;
	logic [4:0] Rt;
	logic [7:0] opcode;
} R2Inst;

typedef struct packed
{
	logic [8:0] disphi;
	logic [1:0] Tb;
	logic [4:0] Rb;
	logic Ta;
	logic [4:0] Ra;
	logic [5:0] displo;
	logic [7:0] opcode;
} BrInst;

typedef struct packed
{
	logic [4:0] pad2;
	logic [2:0] Rm3;
	logic Tc2;
	logic [1:0] Td;
	logic [4:0] Rd;
	logic Tc1;
	logic [4:0] Rc;
	logic [1:0] a;
	logic [2:0] m3;
	logic z;
	logic [7:0] opcode;
} InstMod;

typedef union packed
{
	LoadInst ld;
	NdxLoadInst nld;
	StoreInst st;
	NdxStoreInst nst;
	RIInst ri;
	R2Inst r2;
	InstMod im;
	BrInst br;
} Instruction;

typedef struct packed
{
	//DataTag tag;
	logic [VALUE_SIZE-1:0] val;
} Value;

typedef struct packed
{
	logic [31:0] z;
	logic [31:0] y;
	logic [31:0] x;
} Point;

typedef struct packed
{
	Point ul;		// upper left
	Point lr;		// lower right
} Rect;

parameter SRC_REG = 2'b00;
parameter SRC_RES = 2'b01;
parameter SRC_ARG = 2'b10;

typedef struct packed
{
	logic rf;
	logic [1:0] src;
	logic [5:0] rid;
} Rid;

typedef struct packed
{
	logic [5:0] stream;
	logic [2:0] unit;
} sSource;

typedef struct packed
{
	logic v;
	Address addr;
	BTBTag	tag;
} BTBEntry;

typedef struct packed
{
	logic v;
	logic pma_v;
	Address ip;
	Address pip;
	logic predict_taken;
	logic [pL1ICacheLineSize-1:0] cacheline;
} sInstAlignIn;

typedef struct packed
{
	logic v;
	Address ip;
	Address pip;
	logic predict_taken;
	Instruction ir;
} sInstAlignOut;

typedef struct packed
{
	logic v;
	Address ip;
	Address pip;
	logic predict_taken;
	Instruction ir;
	logic ui;							// unimplemented instruction
	logic rfwr;						// register file write is required
	logic vrfwr;					// vector register file write
	logic vmrfwr;
	logic is_vec;					// is a vector instruction
	logic is_mod;					// is an instruction modifier
	logic is_signed;			// is a signed operation
	logic jump;
	logic branch;
	logic call;
	logic exec;
	logic lsm;
	logic needRa;
	logic needRb;					// R2, LDxX
	logic needRc;					// STx/CHK
	logic veins;
	logic vex;
	logic vsrlv;
	logic mem_op;
	logic mc;							// multi-cycle op
	logic [5:0] step;
	logic [5:0] RaStep;
	logic [5:0] RbStep;
	logic [5:0] Ra;
	logic [6:0] Rb;
	logic [6:0] Rc;				// Sometimes Rt is transferred here
	logic [5:0] Rt;
	logic [5:0] Rm;
	logic Ravec;
	logic Rbvec;
	logic Rcvec;
	logic Rtvec;
	logic Rbseg;
	logic Rtseg;
	logic Ramask;
	logic Rbmask;
	logic [2:0] Vm;
	logic z;
	Value imm;
} sDecode;

typedef struct packed
{
	logic v;
	Instruction ir;
	Address ip;
	Address pip;	// predicted pc
	logic predict_taken;
	logic branch;
	logic ui;							// unimplemented instruction
	logic rfwr;
	Value ia;
	Value ib;
	Value ic;
	Value id;
	Value vmask;
	logic z;
	logic iav;
	logic ibv;
	logic icv;
	logic idv;
	logic itv;
	logic vmv;
	logic [5:0] Rt;
	Value imm;
} sExecute;

typedef struct packed
{
	logic [5:0] rid;
	logic [5:0] step;
	Address ip;
	logic out;
	logic out2;
	logic cmt;
	logic cmt2;
	logic vcmt;
	logic update;
	logic wr_fu;
	logic takb;
	logic vrfwr;
	Value res;
	Value ia;
	Value ib;
	logic update_c;
	logic update_d;
	logic [15:0] cause;
} sExecuteOut;

typedef struct packed
{
	logic wr;
	logic [5:0] rid;
	logic [5:0] step;
	Instruction ir;
	Value ia;
	Value ib;
	Value ic;						// index register for store
	Value dato;
	Value imm;
	logic rfwr;
	logic [5:0] Rt;
} sMemoryIO;

typedef struct packed
{
	logic wr;
	logic [5:0] rid;
	Instruction ir;
	Value ia;
	Value ib;
	Value ic;
	logic rfwr;
	logic [5:0] Rt;	
} sGraphicsOp;

typedef struct packed
{
	logic fuf;	// underflow
	logic fof;	// overflow
	logic fdz;	// divide by zero
	logic fnv;	// invalid operation
	logic fnx;	// inexact
	logic lt;
	logic	eq;
	logic gt;
	logic inf;
} sFPFlags;

typedef struct packed
{
	logic [5:0] rid;
	logic v;
	logic cmt;						// commit, clears as soon as committed
	logic cmt2;						// sticky commit, clears when entry reassigned
	logic vcmt;						// entire vector is committed.
	logic dec;						// instruction decoded
	logic out;						// instruction is out being executed
	logic out2;
	Address ip;
	Instruction ir;
	Instruction irmod;
	Instruction lsm_mask;
	logic is_vec;
	logic is_mod;
	logic ui;							// unimplemented instruction
	logic jump;
	Address jump_tgt;
	logic [2:0] mod_cnt;
	logic [3:0] btag;			// Branch tag
	logic veins;
	logic branch;
	logic call;
	logic mem_op;
	logic lsm;
	logic exec;
	logic myst;
	logic [5:0] count;		// LDM / STM count
	logic exi;
	logic imod;
	logic brmod;
	logic stride;
	logic mc;							// multi-cycle op
	logic takb;
	logic predict_taken;
	logic rfwr;
	logic vrfwr;					// write vector register file
	logic vmrfwr;
	logic [5:0] Rt;
	logic [5:0] Ra;
	logic [6:0] Rb;				// for VEX
	logic [6:0] Rc;
	logic [6:0] Rd;
	logic [5:0] Rm;
	logic Ravec;
	logic Rbvec;
	logic Rcvec;
	logic Rdvec;
	logic Rbseg;
	logic Rtseg;
	logic [5:0] pRt;			// physical Rt
	logic [5:0] step;			// vector step
	logic step_v;
	Value ia;
	Value ib;
	Value ic;
	Value id;
	logic [5:0] ia_ele;
	logic [5:0] ib_ele;
	logic [5:0] ic_ele;
	logic [5:0] id_ele;
	logic [5:0] it_ele;
	logic [127:0] imm;
	Value vmask;						// vector mask register value
	logic z;
	logic iav;
	logic ibv;
	logic icv;
	logic idv;
	logic itv;
	logic vmv;
	Rid ias;
	Rid ibs;
	Rid ics;
	Rid ids;
	logic idib;					// id comes from ia
	Rid its;
	Rid vms;
	Value res;
	sFPFlags fp_flags;
	logic [5:0] res_ele;
	logic [15:0] cause;
	Address badAddr;
	logic wr_fu;				// write to functional unit
	logic update_rob;
	logic [47:0] rob_q;
} sReorderEntry;

typedef struct packed
{
	logic wr;						// write to queue signal
	logic [5:0] rid;
	Instruction ir;
	Value a;
	Value b;
	Value c;
	Value d;
	Value imm;
} sALUrec;

typedef struct packed
{
	logic wr;
	logic [5:0] xrid;
	logic [5:0] step;
	Address redirect_ip;
	Address current_ip;
} sRedirect;

typedef struct packed
{
	logic cmt;
	logic [5:0] rid;
	logic [5:0] ele;
	Value res;
	Value res2;
	logic [7:0] cause;	// exception code if any
	Address badAddr;
} sFuncUnit;

typedef struct packed
{
	logic [7:0] tid;		// tran id
	logic [5:0] step;		// vector operation step
	logic fifo_wr;
	logic [2:0] func;		// function to perform
	logic [3:0] func2;	// more resolution to function
	Address adr;
	logic [127:0] dat;
	logic [31:0] sel;		// data byte select, indicates size of data (nybbles)
} MemoryRequest;	// 198

// All the fields in this structure are *output* back to the system.
typedef struct packed
{
	logic [7:0] tid;		// tran id
	logic [5:0] step;
	logic fifo_wr;
	logic [15:0] cause;
	Address badAddr;
	logic [127:0] res;
	logic cmt;
	logic ret;
	logic call;
} MemoryResponse;	// 192

endpackage

