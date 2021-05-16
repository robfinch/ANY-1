// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.1 (win64) Build 2902540 Wed May 27 19:54:49 MDT 2020
// Date        : Sat May 15 18:19:45 2021
// Host        : Ateana5 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/cores2021/ANY1/v1/ANY1/ANY1.srcs/sources_1/ip/x2m_fifo/x2m_fifo_stub.v
// Design      : x2m_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tsbg484-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_5,Vivado 2020.1" *)
module x2m_fifo(clk, srst, din, wr_en, rd_en, dout, full, empty, valid)
/* synthesis syn_black_box black_box_pad_pin="clk,srst,din[208:0],wr_en,rd_en,dout[208:0],full,empty,valid" */;
  input clk;
  input srst;
  input [208:0]din;
  input wr_en;
  input rd_en;
  output [208:0]dout;
  output full;
  output empty;
  output valid;
endmodule
