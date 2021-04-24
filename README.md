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
The instructions are of a fixed format. In order to get all desired features
into an instruction a 64-bit instruction size has been choosen. The least
significant eight bits of the instruction are the major opcode of the
instruction. Up to four register reads ports may be present in an instruction.
The register spec field allows the selection of either a scalar or a vector
register rather than using opcodes to select scalar or vector operations. As
such there are relatively few instructions.

# Register File
There are two primary register files for the cpu. A scalar register file and a
vector register file. Both register files have 64-registers.
The vector register file has 64 elements per vector register. The register files
are unified and may contain integer, floating-point, decimal floating-point or
posit values.

The instruction pointer is referencable as x63 for use in generating ip relative
addressing modes.
