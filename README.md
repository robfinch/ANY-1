# ANY-1

Welcome to the ANY-1 repository.
This repository is for project files related to the ANY-1 cpu core.
The ANY-1 cpu core aims to be a vector processing core implemented in an FPGA.

# History
Project was started January 20th, 2021, spurred on by discussions of the CRAY-1
computer at ANYCPU.org.

# Status
The project is in initial stages. Specs are being developed. The general
characteristics of the programming model are being determined.
The current working version is version #3.

# Operating Modes
The core will have five operating modes. User, supervisor, hyper-visor, machine
and debug. Virtual memory is available only in user mode.
Some earlier machines (68k, 6809) are bi-modal which works very well. Some
machines (RISC-V, x286+) have four operating modes or levels.


# Instruction Set

## Version 1.
The instructions are of a fixed format. In order to get all desired features
into an instruction a 64-bit instruction size has been choosen. The least
significant eight bits of the instruction are the major opcode of the
instruction. Up to four register reads ports may be present in an instruction.
The register spec field allows the selection of either a scalar or a vector
register rather than using opcodes to select scalar or vector operations. As
such there are relatively few instructions.

## Version 2.
For version2 of the ISA a 32 bit instruction size was chosen. This is much
more code dense than version 1. However there are only two source registers
allowed per instruction. To implement some of the instructions requiring more
source registers, there are instruction modifiers that prefix instructions to
add additional features.

## Version 3.
For version 3 of the ISA a 36-bit instruction size was chosen. This is
practically almost as dense as the 32-bit version since 36-bits is capable
of capturing some instructions that just won't fit into 32-bits. Version 3
has type codes associated with register specs similar to the original 
version. Version 3 is a 32 register machine.

# Register File
There are two primary register files for the cpu. A scalar register file and a
vector register file. Both register files have 32-registers.
The vector register file has 64 elements per vector register. The register files
are unified and may contain integer, floating-point, decimal floating-point or
posit values.

# Addressing
The instruction pointer is referencable as x31 for use in generating ip relative
addressing modes.

Addresses in the machine are byte addresses with one binary point to indicate
which nybble an instruction is located on. Data addresses always refer to
whole byte locations (the LSB of a data pointer is always zero). Instructions
may be aligned on any half-byte address. Addresses are manipulated in registers
as half-byte addresses so that data pointers and code pointers refer to the 
same address.

Here is a sample code listing that shows that addresses are represented as byte
addresses with one binary/hex decimal point.
```
                        	_Delay2s:
FFFFFFFFFFFC0640.0 00005B850 		ldi			$a1,#3000000
FFFFFFFFFFFC0644.8 C6C001504 
                        	.0001:
FFFFFFFFFFFC0649.0 441055602 		srl			$a2,$a1,#16
FFFFFFFFFFFC064D.8 FFFF22050 		stb			$a2,LEDS
FFFFFFFFFFFC0652.0 001600070 
FFFFFFFFFFFC0656.8 FFFF55504 		sub 		$a1,$a1,#1
FFFFFFFFFFFC065B.0 FF9503C48 		bgt		  $a1,#0,.0001
FFFFFFFFFFFC065F.8 000004042 		ret
```


# Status
A version of version 3 of the ISA has been coded. Only the scalar integer
instruction set is supported. It is being simulated.

# Active Implementation
The currently active implementation for an FPGA is a scalar out-of-order
machine. There are 32 architectural registers with an additional
rename registers. A programmer may only use
32 of them. Registers are 64-bit and may contain integer, float, or
posit values.
## Pipeline
The pipeline is partially elastic, some of the stages contain fifo's to buffer
outstanding instructions. <- no longer the case. The front end is in-elastic
and feeds the re-order buffer. Elasiticity comes from the use of a re-order
buffer. 
The reorder buffer is a configurable size
up to 63 entries with a default of eight entries. Reorder entries take
considerable resources, configuring a large reorder buffer may use most of
the FPGA. The reorder buffer allows instructions to be committed to the machine
state in program order, even though they may execute out-of-order.
## ISA support
Only the scalar integer part of the ISA is supported. Adding vector capability
is a work-in-progress. To get some semblance of the capabilies of 64-bit
instructions, instruction modifiers may precede the instruction to add
features for the instruction. Most instructions do not require modifiers
however, some instructions require modifiers to be useful. For instance
bit-field ops require four register read ports, without a modifier they
are not much use.
There is a fast, single cycle multiply operation.
## Caches
Instruction cache is 32kB with a 64B line size and four way set
associative. There is a five entry fully associative victim cache for the
instruction cache.
The data cache is 16kB with a 64B line size. Data cache is write-through
no write allocate. Also four way set associative.
Caches are implemented with block rams. Access to the instruction cache is
pipelined and feeds the pipeline every clock cycle. The data cache takes
several clock cycles for a data access. But it is far better than the 
main memory access time.
## Queues
There are queues for multiply, divide and memory operations. These operations
may take multiple clock cycles to complete, and as they are running other
instruction are allowed to execute past them. Simpler instructions execute
directly in a single clock cycle and update the reorder buffer instead of 
being queued.
The memory queue does not allow loads to bypass stores. Load and stores are
performed in program order relative to each other. Other instructions are
allowed to complete (but not commit) while loads and stores are taking place.

## Scheduler
There is a simple instruction scheduler that selects one of the instructions
in the queue that is ready to execute. Stores will only be chosen to execute
if all instructions before the store have committed.
Preference is given to executing branch instructions. Preferense is also
given to instructions that have been in the queue the longest.
The scheduler will not choose the same queue slot for execution twice in a
row, to give time for the execute status to be updated to 'out'.

