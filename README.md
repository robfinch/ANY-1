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

# Register File
There are two primary register files for the cpu. A scalar register file and a
vector register file. Both register files have 64-registers.
The vector register file has 64 elements per vector register. The register files
are unified and may contain integer, floating-point, decimal floating-point or
posit values.

The instruction pointer is referencable as x63 for use in generating ip relative
addressing modes.

# Status
A version of version 2 of the ISA has been coded. Only the scalar integer
instruction set is supported. It is being simulated.

# Active Implementation
The currently active implementation for an FPGA is a scalar out-of-order
machine. There are 64 architectural registers with an additional 64
rename registers. So, 128 total registers, but a programmer may only use
64 of them. Registers are 64-bit and may contain integer, float, or
posit values.
## Pipeline
The pipeline is partially elastic, some of the stages contain fifo's to buffer
outstanding instructions. Pipeline fifo's are 64 entries deep. The decode
stage feeds to a reorder buffer. The reorder buffer is a configurable size
up to 64 entries with a default of eight entries. Reorder entries take
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
