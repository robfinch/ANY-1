// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_tlb.sv
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//                                                                          
// ============================================================================

import any1_pkg::*;

module any1_TLB(rst_i, clk_i, asid_i, umode_i,xlaten_i,we_i,ladr_i,iacc_i,iadr_i,padr_o,acr_o,tlben_i,wrtlb_i,tlbadr_i,tlbdat_i,tlbdat_o,tlbmiss_o);
parameter AWID=32;
parameter RSTIP = 64'hFFFFFFFFFFFD0000;
input rst_i;
input clk_i;
input [7:0] asid_i;
input umode_i;
input xlaten_i;
input we_i;
input [AWID-1:0] ladr_i;
input iacc_i;
input [AWID-1:0] iadr_i;
output reg [AWID-1:0] padr_o;
output reg [3:0] acr_o;
input tlben_i;
input wrtlb_i;
input [11:0] tlbadr_i;
input [63:0] tlbdat_i;
output reg [63:0] tlbdat_o;
output reg tlbmiss_o;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

wire [AWID-1:0] rstip = RSTIP;
reg [63:0] tadri0, tadri1, tadri2, tadri3;
reg wr0,wr1,wr2,wr3, wed;
reg hit0,hit1,hit2,hit3;
wire wrtlb1 = tlbadr_i[11:10]==2'd0 && wrtlb_i;
wire wrtlb2 = tlbadr_i[11:10]==2'd1 && wrtlb_i;
wire wrtlb3 = tlbadr_i[11:10]==2'd2 && wrtlb_i;
wire wrtlb4 = tlbadr_i[11:10]==2'd3 && wrtlb_i;
wire [63:0] tlbdato1,tlbdato2,tlbdato3,tlbdato4;
wire [63:0] tadr0, tadr1, tadr2, tadr3;
wire clk_g = clk_i;
always @*
case(tlbadr_i[11:10])
2'd0: tlbdat_o <= tlbdato1;
2'd1: tlbdat_o <= tlbdato2;
2'd2: tlbdat_o <= tlbdato3;
2'd3: tlbdat_o <= tlbdato4;
endcase

wire pe_xlat, ne_xlat;
edge_det u5 (
  .rst(rst_i),
  .clk(clk_g),
  .ce(1'b1),
  .i(xlaten_i),
  .pe(pe_xlat),
  .ne(ne_xlat),
  .ee()
);

// Dirty / Accessed bit write logic
always @(posedge clk_g)
  wed <= we_i;
always @(posedge clk_g)
begin
  wr0 <= 1'b0;
  wr1 <= 1'b0;
  wr2 <= 1'b0;
  wr3 <= 1'b0;
  if (ne_xlat) begin
    if (hit0) begin
      tadri0 <= {tadr0[63:55],wed,1'b1,tadr0[52:0]};
      wr0 <= 1'b1;
    end
    if (hit1) begin
      tadri1 <= {tadr1[63:55],wed,1'b1,tadr1[52:0]};
      wr1 <= 1'b1;
    end
    if (hit2) begin
      tadri2 <= {tadr2[63:55],wed,1'b1,tadr2[52:0]};
      wr2 <= 1'b1;
    end
    if (hit3) begin
      tadri3 <= {tadr3[63:55],wed,1'b1,tadr3[52:0]};
      wr3 <= 1'b1;
    end
  end
end

TLBRam u1 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i),      // input wire ena
  .wea(tlbwr1),      // input wire [0 : 0] wea
  .addra(tlbadr_i[9:0]),  // input wire [9 : 0] addra
  .dina(tlbdat_i),    // input wire [63 : 0] dina
  .douta(tlbdato1),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr0),      // input wire [0 : 0] web
  .addrb(ladr_i[23:14]),  // input wire [9 : 0] addrb
  .dinb(tadr0i),    // input wire [63 : 0] dinb
  .doutb(tadr0)  // output wire [63 : 0] doutb
);

TLBRam u2 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i),      // input wire ena
  .wea(tlbwr2),      // input wire [0 : 0] wea
  .addra(tlbadr_i[9:0]),  // input wire [9 : 0] addra
  .dina(tlbdat_i),    // input wire [63 : 0] dina
  .douta(tlbdato2),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr1),      // input wire [0 : 0] web
  .addrb(ladr_i[23:14]),  // input wire [9 : 0] addrb
  .dinb(tadr1i),    // input wire [63 : 0] dinb
  .doutb(tadr1)  // output wire [63 : 0] doutb
);

TLBRam u3 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i),      // input wire ena
  .wea(tlbwr3),      // input wire [0 : 0] wea
  .addra(tlbadr_i[9:0]),  // input wire [9 : 0] addra
  .dina(tlbdat_i),    // input wire [63 : 0] dina
  .douta(tlbdato3),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr2),      // input wire [0 : 0] web
  .addrb(ladr_i[23:14]),  // input wire [9 : 0] addrb
  .dinb(tadr2i),    // input wire [63 : 0] dinb
  .doutb(tadr2)  // output wire [63 : 0] doutb
);

TLBRam u4 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i),      // input wire ena
  .wea(tlbwr4),      // input wire [0 : 0] wea
  .addra(tlbadr_i[9:0]),  // input wire [9 : 0] addra
  .dina(tlbdat_i),    // input wire [63 : 0] dina
  .douta(tlbdato4),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr3),      // input wire [0 : 0] web
  .addrb(ladr_i[23:14]),  // input wire [9 : 0] addrb
  .dinb(tadr3i),    // input wire [63 : 0] dinb
  .doutb(tadr3)  // output wire [63 : 0] doutb
);

always @(posedge clk_g)
if (rst_i)
  padr_o[13:0] <= rstip[13:0];
else
  padr_o[13:0] <= iacc_i ? iadr_i[13:0] : ladr_i[13:0];

always @(posedge clk_g)
if (rst_i) begin
  padr_o[AWID-1:14] <= rstip[AWID-1:14];
end
else begin
  if (pe_xlat) begin
    hit0 <= 1'b0;
    hit1 <= 1'b0;
    hit2 <= 1'b0;
    hit3 <= 1'b0;
  end
  if (iacc_i) begin
    padr_o[AWID-1:14] <= iadr_i[AWID-1:14];
  end
  else if (!umode_i || ladr_i[AWID-1:24]=={AWID-24{1'b1}}) begin
    tlbmiss_o <= FALSE;
    padr_o[AWID-1:14] <= ladr_i[AWID-1:14];
    acr_o <= 4'b1111;
  end
  else if (tadr0[AWID+7:32]==ladr_i[AWID-1:24] && (tadr0[63:56]==asid_i || tadr0[55])) begin
    tlbmiss_o <= FALSE;
    padr_o[AWID-1:14] <= tadr0[AWID-15:0];
    acr_o <= tadr0[51:48];
    hit0 <= 1'b1;
  end
  else if (tadr1[AWID+7:32]==ladr_i[AWID-1:24] && (tadr1[63:56]==asid_i || tadr1[55])) begin
    tlbmiss_o <= FALSE;
    padr_o[AWID-1:14] <= tadr1[AWID-15:0];
    acr_o <= tadr1[51:48];
    hit1 <= 1'b1;
  end
  else if (tadr2[AWID+7:32]==ladr_i[AWID-1:24] && (tadr2[63:56]==asid_i || tadr2[55])) begin
    tlbmiss_o <= FALSE;
    padr_o[AWID-1:14] <= tadr2[AWID-15:0];
    acr_o <= tadr2[51:48];
    hit2 <= 1'b1;
  end
  else if (tadr3[AWID+7:32]==ladr_i[AWID-1:24] && (tadr3[63:56]==asid_i || tadr3[55])) begin
    tlbmiss_o <= FALSE;
    padr_o[AWID-1:14] <= tadr3[AWID-15:0];
    acr_o <= tadr3[51:48];
    hit3 <= 1'b1;
  end
  else
    tlbmiss_o <= TRUE;
end

endmodule
