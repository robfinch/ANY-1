
package any1_pkg;

// Define only one of the following to control the external bus size
`define CPU_B128		1'b1
//`define CPU_B64			1'b1
//`define CPU_B32			1'b1

`define AMSB		31
`define ABITS		31:0

`ifdef CPU_B128
`define SELH    31:16
`define DATH    255:128
`endif
`ifdef CPU_B64
`define SELH    15:8
`define DATH    127:64
`endif
`ifdef CPU_B32
`define SELH    7:4
`define DATH    63:32
`endif

`define SEG_SHIFT	14'd0
//`define VICTIM_CACHE	1'b1
`define ANY1_TLB	1'b1

parameter ROB_ENTRIES = 64;

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
parameter TAG_U20		= 4'h8;
parameter TAG_U10		= 4'h9;

parameter OM_USER		= 3'd0;
parameter OM_SUPER	= 3'd1;
parameter OM_HYPER	= 3'd2;
parameter OM_MACHINE	= 3'd3;
parameter OM_DEBUG	= 3'd4;

parameter BRK		= 8'h00;
parameter R3		= 8'h03;
parameter ADD		= 8'h04;
parameter SUB		= 8'h05;
parameter MUL		= 8'h06;
parameter AND		= 8'h08;
parameter OR		= 8'h09;
parameter XOR		= 8'h0A;
parameter PTRDIF	= 8'h18;
parameter R2		= 8'h0C;
parameter MULU	= 8'h0E;
parameter MULH	= 8'h0F;
parameter DIV		= 8'h10;
parameter DIVU	= 8'h11;
parameter DIVSU	= 8'h12;
parameter MULSU =	8'h16;
parameter DIF		= 8'h18;
parameter MULF	= 8'h1C;
parameter MULSUH= 8'h1D;
parameter MULUH = 8'h1E;
parameter SEQ		= 8'h26;
parameter SNE		= 8'h27;
parameter SLT		= 8'h2C;
parameter SGE		= 8'h2D;
parameter SLTU	= 8'h2E;
parameter SGEU	= 8'h2F;

parameter SLL		= 8'h10;

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
parameter WYDNDX= 8'h1B;
parameter BTFLD	=	8'h1C;

parameter U20NDX= 8'h23;
parameter EXTU	= 8'h24;
parameter SEQI	= 8'h26;
parameter SNEI	= 8'h27;
parameter SLTI	= 8'h28;
parameter SGTI	= 8'h29;
parameter SLTUI	= 8'h2A;
parameter SGTUI = 8'h2B;
parameter EXT		= 8'h2C;

parameter NOP  	= 8'h3F;
parameter JAL		= 8'h40;

parameter SYS		= 8'h44;
parameter CSR		= 8'h0F;
parameter CSRR	= 3'd0;
parameter CSRW	= 3'd1;
parameter CSRS	= 3'd2;
parameter CSRC	= 3'd3;
parameter CSRRW	= 3'd4;
parameter REX		= 8'h10;
parameter PFI		= 8'h11;
parameter WFI		= 8'h12;
parameter RTE		= 8'h13;
parameter MVSEG	= 8'h1D;
parameter TLBRW	= 8'h1E;
parameter SYNC	= 8'h1F;

parameter BLT		= 8'h48;
parameter BGE		= 8'h49;
parameter BLTU	= 8'h4A;
parameter BGEU	= 8'h4B;
parameter BEQ		= 8'h4E;
parameter BNE		= 8'h4F;

parameter LDx		= 8'h60;
parameter LEA		= 8'h6D;
parameter CACHE	= 8'h6E;
parameter STx		= 8'h70;

parameter NOP_INSN = {56'd0,NOP};

parameter CSR_CAUSE	= 16'h?006;
parameter CSR_SEMA	= 16'h?00C;
parameter CSR_ASID	= 16'h101F;
parameter CSR_MCR0	= 16'h3000;
parameter CSR_TICK	= 16'h3002;
parameter CSR_MBADADDR	= 16'h3007;
parameter CSR_MTVEC = 16'h303?;
parameter CSR_MPMSTACK	= 16'h3040;
parameter CSR_MSTATUS	= 16'h3044;
parameter CSR_MEIP	=	16'h3048;
parameter CSR_DCR0	= 16'h4000;
parameter CSR_DTVEC = 16'h403?;
parameter CSR_DPMSTACK	= 16'h4040;
parameter CSR_DSTATUS	= 16'h4044;
parameter CSR_DEIP	=	16'h4048;
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
parameter FLT_IADR	= 8'h36;
parameter FLT_UNIMP	= 8'h37;
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

parameter pL1CacheLines = 64;
parameter pL1LineSize = 512;
localparam pL1msb = $clog2(pL1CacheLines-1)-1+6;
parameter RSTIP = 32'hFFFD0000;
parameter RIBO = 1;

typedef logic [`ABITS] Address;
typedef logic [AWID-13:0] BTBTag;
typedef logic [7:0] ASID;
typedef logic [63:0] Data;
typedef logic [3:0] DataTag;

typedef struct packed
{
	DataTag tag;
	logic pad;
	logic [2:0] rm;
	logic [7:0] func;
	logic [3:0] sz;
	logic [2:0] m;
	logic z;
	logic [7:0] Rc;
	logic [7:0] Rb;
	logic [7:0] Ra;
	logic [7:0] Rt;
	logic [7:0] opcode;
} Instruction;

typedef struct packed
{
	DataTag tag;
	logic [59:0] val;
} sValue;

typedef struct packed
{
	logic rf;
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
	logic [5:0] Stream;
	logic [5:0] rid;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;
	logic predict_taken;
	logic [511:0] cacheline;
} sInstAlignIn;

typedef struct packed
{
	logic [5:0] Stream;
	logic [5:0] rid;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;
	logic predict_taken;
	Instruction ir;
} sInstAlignOut;

typedef struct packed
{
	logic [5:0] Stream;
	logic Stream_inc;
	logic [5:0] rid;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;	// predicted pc
	logic predict_taken;
	Instruction ir;
	logic ui;							// unimplemented instruction
	logic rfwr;						// register file write is required
	logic [7:0] Ra;
	logic [7:0] Rb;
	logic [7:0] Rc;
	logic [7:0] Rd;
	logic [7:0] Rt;
	sValue imm;
} sDecode;

typedef struct packed
{
	logic [5:0] Stream;
	logic Stream_inc;
	logic [5:0] rid;
	Instruction ir;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;	// predicted pc
	logic predict_taken;
	logic ui;							// unimplemented instruction
	logic rfwr;
	sValue ia;
	sValue ib;
	sValue ic;
	sValue id;
	logic iav;
	logic ibv;
	logic icv;
	logic idv;
	logic itv;
	logic [7:0] Rt;
	sValue imm;
} sExecute;

typedef struct packed
{
	logic [5:0] Stream;
	logic Stream_inc;
	logic [5:0] rid;
	Instruction ir;
	sValue ia;
	logic rfwr;
	logic [7:0] Rt;
	sValue res;
} sExecuteOut;

typedef struct packed
{
	logic [5:0] Stream;
	logic Stream_inc;
	logic [5:0] rid;
	Instruction ir;
	sValue ia;
	sValue ib;
	sValue dato;
	sValue imm;
	logic rfwr;
	logic [7:0] Rt;
} sMemoryIO;

typedef struct packed
{
	logic [5:0] Stream;
	logic Stream_inc;
	logic v;
	logic issued;
	logic cmt;
	logic cmt2;
	logic dec;						// instruction decoded
	Address ip;
	Instruction ir;
	logic ui;							// unimplemented instruction
	logic jump;
	Address jump_tgt;
	logic [3:0] btag;
	logic branch;
	logic takb;
	logic predict_taken;
	logic rfwr;
	logic [7:0] Rt;
	sValue ia;
	sValue ib;
	sValue ic;
	sValue id;
	sValue imm;
	logic iav;
	logic ibv;
	logic icv;
	logic idv;
	logic itv;
	Rid ias;
	Rid ibs;
	Rid ics;
	Rid ids;
	Rid its;
	sValue res;
	logic [15:0] cause;
} sReorderEntry;

typedef struct packed
{
	logic [5:0] rid;
	Instruction ir;
	sValue a;
	sValue b;
	sValue c;
	sValue d;
	sValue imm;
} sALUrec;

typedef struct packed
{
	Address redirect_ip;
	Address current_ip;
} sRedirect;

endpackage

