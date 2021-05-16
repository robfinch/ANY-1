// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.1 (win64) Build 2902540 Wed May 27 19:54:49 MDT 2020
// Date        : Sat May 15 17:48:46 2021
// Host        : Ateana5 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/cores2021/ANY1/v1/ANY1/ANY1.srcs/sources_1/ip/d2r_fifo/d2r_fifo_stub.v
// Design      : d2r_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tsbg484-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_5,Vivado 2020.1" *)
module d2r_fifo(clk, srst, din, wr_en, rd_en, dout, full, empty, valid)
/* synthesis syn_black_box black_box_pad_pin="clk,srst,din[168:0],wr_en,rd_en,dout[168:0],full,empty,valid" */;
  input clk;
  input srst;
  input [168:0]din;
  input wr_en;
  input rd_en;
  output [168:0]dout;
  output full;
  output empty;
  output valid;
endmodule
