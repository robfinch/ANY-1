
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

parameter TRUE  = 1'b1;
parameter FALSE = 1'b0;
parameter HIGH  = 1'b1;
parameter LOW   = 1'b0;
parameter VAL		= 1'b1;
parameter INV		= 1'b0;
parameter AWID  = 32;
parameter WID 	= 64;

parameter OM_USER		= 3'd0;
parameter OM_SUPER	= 3'd1;
parameter OM_HYPER	= 3'd2;
parameter OM_MACHINE	= 3'd3;
parameter OM_DEBUG	= 3'd4;

parameter R3		= 8'h03;
parameter ADD		= 8'h04;
parameter SUB		= 8'h05;
parameter AND		= 8'h08;
parameter OR		= 8'h09;
parameter XOR		= 8'h0A;
parameter SLL		= 8'h10;
parameter SEQ		= 8'h26;
parameter SNE		= 8'h27;

parameter ADDI	= 8'h04;
parameter SUBFI	= 8'h05;
parameter ANDI  = 8'h08;
parameter ORI		= 8'h09;
parameter XORI	= 8'h0A;

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
parameter BLT		= 8'h48;
parameter BGE		= 8'h49;
parameter BLTU	= 8'h4A;
parameter BGEU	= 8'h4B;
parameter BEQ		= 8'h4E;
parameter BNE		= 8'h4F;

parameter LDx		= 8'h60;
parameter LEA		= 8'h68;
parameter CACHE	= 8'h6E;
parameter STx		= 8'h70;

parameter NOP_INSN = {56'd0,NOP};


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
parameter FLT_UNIMP	= 8'h37;

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
parameter MUL1 = 6'd26;
parameter MUL2 = 6'd27;
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

parameter EDIV1 = 3'd3;
parameter EDIV2 = 3'd4;
parameter EDIV3 = 3'd5;

parameter pL1CacheLines = 256;
localparam pL1msb = $clog2(pL1CacheLines-1)-1+5;
parameter RSTIP = 32'hFFFD0000;
parameter RIBO = 1;

typedef logic [`ABITS] Address;
typedef logic [AWID-14:0] BTBTag;
typedef logic [7:0] ASID;
typedef logic [63:0] Data;

typedef struct packed
{
	logic v;
	Address addr;
	BTBTag	tag;
} BTBEntry;

typedef struct packed
{
	logic [5:0] epoch;
	logic [3:0] rid;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;
	logic predict_taken;
	logic [511:0] cacheline;
} sInstAlignIn;

typedef struct packed
{
	logic [5:0] epoch;
	logic [3:0] rid;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;
	logic predict_taken;
	logic [63:0] ir;
} sInstAlignOut;

typedef struct packed
{
	logic [5:0] epoch;
	logic [3:0] rid;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;	// predicted pc
	logic predict_taken;
	logic [63:0] ir;
	logic ii;							// illegal instruction
	logic rfwr;						// register file write is required
	logic [7:0] Ra;
	logic [7:0] Rb;
	logic [7:0] Rc;
	logic [7:0] Rd;
	logic [7:0] Rt;
	logic [63:0] imm;
} sDecode;

typedef struct packed
{
	logic [5:0] epoch;
	logic [3:0] rid;
	logic [63:0] ir;
	logic [AWID-1:0] ip;
	logic [AWID-1:0] pip;	// predicted pc
	logic predict_taken;
	logic ii;							// illegal instruction
	logic rfwr;
	logic [63:0] ia;
	logic [63:0] ib;
	logic [63:0] ic;
	logic [63:0] id;
	logic [7:0] Rt;
	logic [63:0] imm;
} sExecuteIn;

typedef struct packed
{
	logic [5:0] epoch;
	logic [3:0] rid;
	logic [63:0] ir;
	logic [63:0] ia;
	logic rfwr;
	logic [7:0] Rt;
	logic [63:0] res;
} sExecuteOut;

typedef struct packed
{
	logic [5:0] epoch;
	logic [3:0] rid;
	logic [63:0] ir;
	logic [63:0] ia;
	logic [63:0] ib;
	logic [63:0] dato;
	logic [63:0] imm;
	logic rfwr;
	logic [7:0] Rt;
} sMemoryIO;

typedef struct packed
{
	logic v;
	logic [AWID-1:0] ip;
	logic ii;
	logic cmt;
	logic jump;
	logic [63:0] jump_tgt;
	logic branch;
	logic takb;
	logic rfwr;
	logic [7:0] Rt;
	logic [63:0] res;
	logic [15:0] cause;
} sReorderEntry;

endpackage

