-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.1 (win64) Build 2902540 Wed May 27 19:54:49 MDT 2020
-- Date        : Sat May 15 17:49:07 2021
-- Host        : Ateana5 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               d:/cores2021/ANY1/v1/ANY1/ANY1.srcs/sources_1/ip/r2x_fifo/r2x_fifo_stub.vhdl
-- Design      : r2x_fifo
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a200tsbg484-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity r2x_fifo is
  Port ( 
    clk : in STD_LOGIC;
    srst : in STD_LOGIC;
    din : in STD_LOGIC_VECTOR ( 394 downto 0 );
    wr_en : in STD_LOGIC;
    rd_en : in STD_LOGIC;
    dout : out STD_LOGIC_VECTOR ( 394 downto 0 );
    full : out STD_LOGIC;
    empty : out STD_LOGIC;
    valid : out STD_LOGIC
  );

end r2x_fifo;

architecture stub of r2x_fifo is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,srst,din[394:0],wr_en,rd_en,dout[394:0],full,empty,valid";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "fifo_generator_v13_2_5,Vivado 2020.1";
begin
end;
