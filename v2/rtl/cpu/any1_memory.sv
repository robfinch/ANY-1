import any1_pkg:::*;

module any1_memory(rst, clk, vpa_o, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o, dat_i, dat_o,
	ihit, ic_line, x2m_empty, x2m_rd, membufo, iav, ibc, icv, idv, funcUnit,
	);
input rst;
input clk;
output reg vpa_o;
output reg cyc_o;
output reg stb_o;
input ack_i;
output reg we_o;
output reg [15:0] sel_o;
output Address adr_o;
input [127:0] dat_i;
output reg [127:0] dat_o;
output ihit;
output reg [511:0] ic_line;
input x2m_empty;
output reg x2m_rd;
input sMemoryIO membufo;
input iav;
input ibv;
input icv;
input idv;
output sFuncUnit funcUnit;

integer n;

reg [5:0] mstate;
reg [5:0] mstk_state;
reg zero_data;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Data Cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg [1:0] waycnt;
reg daccess;
reg [2:0] dwait;		// wait state counter for dcache
reg [3:0] dcnt;
Address dadr;
reg [pL1LineSize-1:0] dci;
wire [pL1LineSize-1:0] dc_line;
reg [pL1LineSize-1:0] datil;
reg dcachable;
reg [1:0] dc_rway,dc_wway;
reg dcache_wr;

dcache_blkmem your_instance_name (
  .clka(clk_g),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(dcache_wr),      // input wire [0 : 0] wea
  .addra({dc_wway,dadr[11:6]}),  // input wire [8 : 0] addra
  .dina(dci),    // input wire [511 : 0] dina
  .clkb(clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({dc_rway,adr_o[11:6]}),  // input wire [8 : 0] addrb
  .doutb(dc_line)  // output wire [511 : 0] doutb
);
/*
dcache_mem udcm1 (
  .a({dc_wway,dadr[pL1msb:6]}),        // input wire [5 : 0] a
  .d(dci),        // input wire [511 : 0] d
  .dpra({dc_rway,adr_o[pL1msb:6]}),  // input wire [5 : 0] dpra
  .clk(clk),    // input wire clk
  .we(dcache_wr),      // input wire we
  .dpo(dc_line)    // output wire [511 : 0] dpo
);
*/
reg [AWID-7:0] dctag0 [0:63];
reg [AWID-7:0] dctag1 [0:63];
reg [AWID-7:0] dctag2 [0:63];
reg [AWID-7:0] dctag3 [0:63];
reg [pL1CacheLines-1:0] dcvalid0;
reg [pL1CacheLines-1:0] dcvalid1;
reg [pL1CacheLines-1:0] dcvalid2;
reg [pL1CacheLines-1:0] dcvalid3;
reg dc_invline;
reg dhit1a;
reg dhit1b;
reg dhit1c;
reg dhit1d;
always @*	//(posedge clk_g)
  dhit1a <= dctag0[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid0[adr_o[pL1msb:6]];
always @*	//(posedge clk_g)
  dhit1b <= dctag1[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid1[adr_o[pL1msb:6]];
always @*	//(posedge clk_g)
  dhit1c <= dctag2[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid2[adr_o[pL1msb:6]];
always @*	//(posedge clk_g)
  dhit1d <= dctag3[ip[pL1msb:6]]==adr_o[AWID-1:6] && dcvalid3[adr_o[pL1msb:6]];
wire dhit = dhit1a|dhit1b|dhit1c|dhit1d;
initial begin
  dcvalid0 = {pL1CacheLines{1'd0}};
  dcvalid1 = {pL1CacheLines{1'd0}};
  dcvalid2 = {pL1CacheLines{1'd0}};
  dcvalid3 = {pL1CacheLines{1'd0}};
  for (n = 0; n < pL1CacheLines; n = n + 1) begin
    dctag0[n] = 32'd1;
    dctag1[n] = 32'd1;
    dctag2[n] = 32'd1;
    dctag3[n] = 32'd1;
  end
end

always @*
begin
  case(1'b1)
  dhit1a: dc_rway <= 2'b00;
  dhit1b: dc_rway <= 2'b01;
  dhit1c: dc_rway <= 2'b10;
  dhit1d: dc_rway <= 2'b11;
  default:  dc_rway <= 2'b00;
  endcase
end


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg ic_update;
wire [16:0] lfsr_o;
reg [1:0] ic_rway,ic_wway;
wire icache_wr;

lfsr ulfsr1
(
	.rst(rst_i),
	.clk(clk_g),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

reg iaccess;
reg [3:0] icnt;
reg [pL1LineSize-1:0] ici;
reg [pL1LineSize-1:0] iri;
wire [pL1LineSize-1:0] ic_line;
reg [AWID-7:0] ic_tag;
//reg [pL1LineSize-1:0] icache [0:3] [0:pL1CacheLines-1];
icache_mem uicm1 (
  .a({waycnt,iadr[pL1msb:6]}),        // input wire [5 : 0] a
  .d(ici),        // input wire [511 : 0] d
  .dpra({ic_rway,ip[pL1msb:6]}),  // input wire [5 : 0] dpra
  .clk(clk_g),    // input wire clk
  .we(icache_wr),      // input wire we
  .dpo(ic_line)    // output wire [511 : 0] dpo
);
reg [AWID-7:0] ictag [0:3] [0:pL1CacheLines-1];
reg [pL1CacheLines-1:0] icvalid [0:3];
reg ic_invline;
reg ihit;
reg ihit1a;
reg ihit1b;
reg ihit1c;
reg ihit1d;
always @*	//(posedge clk_g)
  ihit1a = ictag[0][ip[pL1msb:6]]==ip[AWID-1:6] && icvalid[0][ip[pL1msb:6]];
always @*	//(posedge clk_g)
  ihit1b = ictag[1][ip[pL1msb:6]]==ip[AWID-1:6] && icvalid[1][ip[pL1msb:6]];
always @*	//(posedge clk_g)
  ihit1c = ictag[2][ip[pL1msb:6]]==ip[AWID-1:6] && icvalid[2][ip[pL1msb:6]];
always @*	//(posedge clk_g)
  ihit1d = ictag[3][ip[pL1msb:6]]==ip[AWID-1:6] && icvalid[3][ip[pL1msb:6]];
always @*
	ihit = ihit1a|ihit1b|ihit1c|ihit1d;
initial begin
  icvalid[0] = {pL1CacheLines{1'd0}};
  icvalid[1] = {pL1CacheLines{1'd0}};
  icvalid[2] = {pL1CacheLines{1'd0}};
  icvalid[3] = {pL1CacheLines{1'd0}};
  for (n = 0; n < pL1CacheLines; n = n + 1) begin
    ictag[0][n] = 32'd1;
    ictag[1][n] = 32'd1;
    ictag[2][n] = 32'd1;
    ictag[3][n] = 32'd1;
  end
end

always @*
begin
  case(1'b1)
  ihit1a: ic_rway <= 2'b00;
  ihit1b: ic_rway <= 2'b01;
  ihit1c: ic_rway <= 2'b10;
  ihit1d: ic_rway <= 2'b11;
  default:  ic_rway <= 2'b00;
  endcase
end

// For victim cache update
always @*
begin
  case(1'b1)
  ihit1a: ic_tag <= ictag[0][ip[pL1msb:6]];
  ihit1b: ic_tag <= ictag[1][ip[pL1msb:6]];
  ihit1c: ic_tag <= ictag[2][ip[pL1msb:6]];
  ihit1d: ic_tag <= ictag[3][ip[pL1msb:6]];
  default:  ic_tag <= 32'd1;
  endcase
end

//always @(posedge clk_g)
//	if (ic_update)
		//tLICache(lfsr_o[1:0],iadr[AWID-1:6],ici,1'b1);


reg [2:0] ivcnt;
reg [511:0] ivcache [0:4];
reg [AWID-1:6] ivtag [0:4];
reg [4:0] ivvalid;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Key Cache
// - the key cache is direct mapped, 64 lines of 512 bits.
// - keys are stored in the low order 20 bits of a 32-bit memory cell
// - 16 keys per 512 bit cache line
// - one cache line is enough to cover 256kB of memory
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

`ifdef SUPPORT_KEYCHK
reg [511:0] kyline [0:63];
reg [AWID-19:0] kytag;
reg [63:0] kyv;
reg kyhit;
always @*
	kyhit <= kytag[adr_o[23:18]]==adr_o[AWID-1:18] && kyv[adr_o[23:18]];
initial begin
	kyv = 64'd0;
	for (n = 0; n < 64; n = n + 1) begin
		kyline[n] <= 512'd0;
		kytag[n] <= 32'd1;
	end
end
wire [19:0] kyut = kyline[adr_o[23:18]] >> {adr_o[17:14],5'd0};
`endif


always @(posedge clk)
if (rst) begin
	mstate <= MEMORY1;
	mstk_state <= MEMORY1;
end
else
	case(mstate)
MEMORY1:
	begin
	iaccess <= FALSE;
	daccess <= FALSE;
  icnt <= 4'd0;
  dcnt <= 4'd0;
	if (ihit) begin
		if (!x2m_empty) begin
			x2m_rd <= TRUE;
			zero_data <= FALSE;
			mgoto (MEMORY1c);
		end
		else
			mgoto (MEMORY1);	// Stay in state
	end
	else begin
`ifdef ANY1_TLB
    mgoto (IFETCH2a);
`else
    mgoto (IFETCH3);
`endif
`ifdef SUPPORT_VICTIM_CACHE
		for (n = 0; n < 5; n = n + 1) begin
			if (ivtag[n]==iadr[AWID-1:6] && ivvalid[n]) begin
				ici <= ivcache[n];
				icnt <= 4'd15;	// trigger update
				ivcache[n] <= ic_line;
				ivtag[n] <= ic_tag;
	    	mgoto (IFETCH5);
    	end
		end
`endif
  end
	end
	//tMemory1();
IFETCH2a:
  begin
    mgoto(IFETCH3);
  end
IFETCH3:
  begin
`ifdef SUPPORT_VICTIM_CACHE
  	// Cache miss, select an entry in the victim cache to
  	// update.
		ivcnt <= ivcnt + 2'd1;
		if (ivcnt>=3'd4)
			ivcnt <= 3'd0;
		ivcache[ivcnt] <= ic_line;
		ivtag[ivcnt] <= ic_tag;
		ivvalid[ivcnt] <= TRUE;
`endif
		xlaten <= FALSE;
	  begin
  		mgoto (IFETCH3a);
`ifdef ANY1_TLB  		
  		if (tlbmiss) begin
  			funcUnit.cmt <= TRUE;
		    funcUnit.cause <= 16'h8004;
			  funcUnit.badAddr <= ip;
			  vpa_o <= FALSE;
			end
			else
`endif			
			begin
			  // First time in, set to miss address, after that increment
			  iaccess <= TRUE;
`ifdef CPU_B128
        if (!iaccess)
          iadr <= {ip[AWID-1:5],5'h0};
        else
          iadr <= {iadr[AWID-1:4],4'h0} + 5'h10;
`endif
`ifdef CPU_B64
        if (!iaccess)
          iadr <= {ip[AWID-1:5],5'h0}
        else
          iadr <= {iadr[AWID-1:3],3'h0} + 4'h8;
`endif
`ifdef CPU_B32
        if (!iaccess)
          iadr <= {ip[AWID-1:5],5'h0};
        else
          iadr <= {iadr[AWID-1:2],2'h0} + 3'h4;
`endif			
      end
	  end
  end
IFETCH3a:
  begin
  	vpa_o <= HIGH;
    cyc_o <= HIGH;
		stb_o <= HIGH;
`ifdef CPU_B128
    sel_o <= 16'hFFFF;
`endif
`ifdef CPU_B64
    sel_o <= 8'hFF;
`endif
`ifdef CPU_B32
		sel_o <= 4'hF;
`endif
//		adr_o <= iadr;
    mgoto (IFETCH4);
  end
IFETCH4:
  begin
    if (ack_i) begin
      cyc_o <= LOW;
      stb_o <= LOW;
      vpa_o <= LOW;
      sel_o <= 1'h0;
`ifdef CPU_B128
      case(icnt[3:2])
      2'd0: ici[127:0] <= dat_i;
      2'd1: ici[255:128] <= dat_i;
      2'd2: ici[383:256] <= dat_i;
      2'd3: ici[511:384] <= dat_i;
      endcase
      mgoto (IFETCH5);
`endif
`ifdef CPU_B64
      case(icnt[3:1])
      3'd0: ici[63:0] <= dat_i;
      3'd1: ici[127:64] <= dat_i;
      3'd2: ici[191:128] <= dat_i;
      3'd3; ici[255:192] <= dat_i;
      3'd4:	ici[319:256] <= dat_i;
      3'd5:	ici[383:320] <= dat_i;
      3'd6:	ici[447:384] <= dat_i;
      3'd7:	ici[511:448] <= dat_i;
      endcase
      mgoto (IFETCH5);
`endif
`ifdef CPU_B32
			// ToDo: fill remaining cases
      case(icnt[3:0])
      4'd0: ici[31:0] <= dat_i;
      4'd1: ici[63:32] <= dat_i;
      4'd2: ici[95:64] <= dat_i;
      4'd3: ici[127:96] <= dat_i;
      4'd4: ici[159:128] <= dat_i;
      4'd5: ici[191:160] <= dat_i;
      4'd6; ici[223:192] <= dat_i;
      4'd7: ici[255:224] <= dat_i;
      endcase
      mgoto (IFETCH5);
`endif
    end
		tPMAIP(); // must have adr_o valid for PMA
  end
IFETCH5:
  begin
  	// Having the ack_i in the wrong spot caused sim to lockup
    if (~ack_i) begin
`ifdef CPU_B128
      icnt <= icnt + 4'd4;
`endif
`ifdef CPU_B64
      icnt <= icnt + 4'd2;
`endif
`ifdef CPU_B32
      icnt <= icnt + 2'd1;
`endif
`ifdef CPU_B128
    if (icnt[3:2]==2'd3) begin
    	ic_wway <= waycnt;
			ictag[waycnt][iadr[pL1msb:6]] <= iadr[AWID-1:6];
			//icache[waycnt][iadr[pL1msb:6]] <= ici;
			icvalid[waycnt][iadr[pL1msb:6]] <= 1'b1;
//			tLICache(lfsr_o[1:0],iadr[AWID-1:6],ici,1'b1);
//    	tMemory1();
			mgoto(MEMORY1);
    end
		else
      mgoto (IFETCH3);
`endif
`ifdef CPU_B64
    if (icnt[3:1]==3'd7) begin
			tLICache(lfsr_o[1:0],iadr[AWID-1:6],ici,1'b1);
    	tMemory1();
    end
		else
      mgoto (IFETCH3);
`endif
`ifdef CPU_B32
    if (icnt[3:0]==4'd15) begin
			tLICache(lfsr_o[1:0],iadr[AWID-1:6],ici,1'b1);
    	tMemory1();
    end
		else
      mgoto (IFETCH3);
`endif
    end

  end

`ifdef ANY1_TLB
TLB1:
	mgoto (TLB2);
TLB2:
	mgoto (TLB3);
TLB3:
	begin
    funcUnit.res <= tlbdato;
		funcUnit.rid <= membufo.rid;
    funcUnit.cmt <= TRUE;
   	tMemory1();
	end
`endif


MEMORY1c:
  if (rob[membufo.rid].iav && rob[membufo.rid].ibv && rob[membufo.rid].icv && rob[membufo.rid].idv)
  	mgoto (MEMORY1d);
  // Need a cycle for AGEN
MEMORY1d:
	mgoto(MEMORY1e);
MEMORY1e:
	begin
  	/*
    if (membufo.ir[7:0]==LINK) begin
    	rob[membufo.rid].Rt <= 6'd62;
    	rob[membufo.rid].res <= membufo.ia + membufo.imm;
    end
   */
`ifdef ANY1_TLB
    mgoto (MEMORY1a);
`else
    mgoto (MEMORY2);
`endif
    if (membufo.ir.r2.opcode==SYS) begin
    	tlb_ia <= rob[membufo.rid].ia;
    	tlb_ib <= rob[membufo.rid].ib;
    	tlbwr <= TRUE;
`ifdef ANY1_TLB
   		mgoto (TLB1);
`else
			rob[membufo.rid].ui <= TRUE;
      rob[membufo.rid].cmt <= TRUE;
      rob[membufo.rid].cmt2 <= TRUE;
			tMemory1();
`endif   		
    end
    else if (membufo.ir.r2.opcode==LEA) begin
      rob[membufo.rid].res.val <= ea;
      rob[membufo.rid].cmt <= TRUE;
      rob[membufo.rid].cmt2 <= TRUE;
    	tMemory1();
    end
    else begin
    	// If speculated loads are not enabled then they must occur at the
    	// head of the list.
    	if (membufo.ir.r2.opcode==LDx && membufo.rid != rob_deq && !sple)
    		mgoto (MEMORY1e);
    	// Holding pattern until store is at head of list
    	// Prevents the scenario of having an instruction before the store
    	// causing an exception.
    	else if (membufo.ir.r2.opcode==STx && membufo.rid != rob_deq)
    		mgoto (MEMORY1e);
    	else begin
      tEA(ea);
      xlaten <= TRUE;
`ifdef CPU_B128
      sel <= selx << ea[3:0];
      dat <= zero_data ? 1'd0 : membufo.dato << {ea[3:0],3'b0};
`endif
`ifdef CPU_B64
      sel <= selx << ea[2:0];
      dat <= zero_data ? 1'd0 : membufo.dato << {ea[2:0],3'b0};
`endif
`ifdef CPU_B32
      sel <= selx << ea[1:0];
      dat <= zero_data ? 1'd0 : membufo.dato << {ea[1:0],3'b0};
`endif
      ealow <= ea[7:0];
      end
    end
  end
MEMORY1a:
  mgoto (MEMORY2);
// This cycle for pageram access
MEMORY2:
  begin
    mgoto (MEMORY_KEYCHK1);
  end
MEMORY_KEYCHK1:
  begin
 `ifdef SUPPORT_KEYCHK
  	if (!kyhit)
  		mgosub(KYLD);
  	else begin
  		mgoto (MEMORY2b);
  		for (n = 0; n < 8; n = n + 1)
  			if (kyut == keys[n] || kyut==20'd0)
  				mgoto(MEMORY3);
  	end
`else
		mgoto (MEMORY3);
`endif  	
    if (d_cache)
      tPMAEA();
  end
MEMORY2b:
	begin
    rob[membufo.rid].cause <= 16'h8031;	// KEY fault
    rob[membufo.rid].cmt <= TRUE;
    rob[membufo.rid].cmt2 <= TRUE;
	  badaddr[3'd5] <= ea;
	  tMemory1();
	end
MEMORY3:
  begin
    xlaten <= FALSE;
    dwait <= 3'd0;
    mgoto (MEMORY4);
`ifdef ANY1_TLB
		if (tlbmiss) begin
	    rob[membufo.rid].cause <= 16'h8004;
  	  badaddr[3'd5] <= ea;
	    rob[membufo.rid].cmt <= TRUE;
  	  rob[membufo.rid].cmt2 <= TRUE;
  	  tMemory1();
  	end
    else
`endif    
    if (~d_cache) begin
      cyc_o <= HIGH;
      stb_o <= HIGH;
`ifdef CPU_B128
      sel_o <= sel[15:0];
      dat_o <= dat[127:0];
`endif
`ifdef CPU_B64
      sel_o <= sel[7:0];
      dat_o <= dat[63:0];
`endif
`ifdef CPU_B32
      sel_o <= sel[3:0];
      dat_o <= dat[31:0];
`endif
      case(membufo.ir[7:0])
      LDx:
      	begin
      		if (dhit) begin
      			cyc_o <= 1'b0;
      			stb_o <= 1'b0;
      			sel_o <= 1'h0;
      		end
      	end
      STx:	we_o <= HIGH;
      default:  ;
      endcase
//      dadr <= adr_o;
    end
  end
MEMORY4:
  begin
    if (d_cache) begin
    	/*
      icvalid[0][adr_o[pL1msb:6]] <= 1'b0;
      icvalid[1][adr_o[pL1msb:6]] <= 1'b0;
      icvalid[2][adr_o[pL1msb:6]] <= 1'b0;
      icvalid[3][adr_o[pL1msb:6]] <= 1'b0;
      */
    	tMemory1();
    end
    else if (dce & dhit) begin
    	datil <= dc_line;
  		if (d_st) begin
  			if (acki) begin
`ifdef CPU_B128
	  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
`endif
`ifdef CPU_B64
  				dci <= (dc_line & stmask) | ((dat << {adr_o[5:3],6'b0}) & ~stmask);
`endif
`ifdef CPU_B32
  				dci <= (dc_line & stmask) | ((dat << {adr_o[5:2],5'b0}) & ~stmask);
`endif
	  			dc_wway <= dc_rway;
  				dcache_wr <= TRUE;
		      mgoto (MEMORY5);
		      stb_o <= LOW;
		      if (sel[`SELH]==1'h0) begin
		        cyc_o <= LOW;
		        we_o <= LOW;
		        sel_o <= 1'h0;
		      end
		    end
  		end
    	else begin
    		dwait <= dwait + 2'd1;
    		if (dwait==3'd2)
	      	mgoto (MEMORY5);
	    end
  	end
    else if (acki) begin
      mgoto (MEMORY5);
      stb_o <= LOW;
      dati <= dat_i;
      if (sel[`SELH]==1'h0) begin
        cyc_o <= LOW;
        we_o <= LOW;
        sel_o <= 1'h0;
      end
    end
  end
MEMORY5:
  if (~acki) begin
    if (|sel[`SELH])
      mgoto (MEMORY6);
    else begin
      case(membufo.ir.r2.opcode)
      LDx:
      	begin
      		if (dce & dhit)
      			dati <= datil >> {adr_o[5:3],6'b0};
	        mgoto (DATA_ALIGN);
      	end
	    STx://,`FSTO,`PSTO,
	    	begin
	    		if (membufo.ir.st.func==4'd7) begin	// STPTR
			    	if (ea==32'd0) begin
			    	 	rob[membufo.rid].cmt <= TRUE;
			    	 	rob[membufo.rid].cmt2 <= TRUE;
				    	tMemory1();
			    	end
			    	else begin
			    		shr_ma <= TRUE;
			    		zero_data <= TRUE;
			    		mgoto (MEMORY1c);
			    	end
	    		end
	    		else begin
			    	rob[membufo.rid].cmt <= TRUE;
		    	 	rob[membufo.rid].cmt2 <= TRUE;
			    	tMemory1();
		      end
	    	end
      default:
        mgoto (DATA_ALIGN);
      endcase
    end
  end
MEMORY6:
  begin
`ifdef ANY1_TLB
    mgoto (MEMORY6a);
`else
    mgoto (MEMORY7);
`endif
    xlaten <= TRUE;
    tEA(ea);
  end
MEMORY6a:
  mgoto (MEMORY7);
MEMORY7:
  mgoto (MEMORY_KEYCHK2);
MEMORY_KEYCHK2:
  begin
 `ifdef SUPPORT_KEYCHK
  	if (!kyhit)
  		mgosub(KYLD);
  	else begin
  		mgoto (MEMORY2b);
  		for (n = 0; n < 8; n = n + 1)
  			if (kyut == keys[n] || kyut==20'd0)
  				mgoto(MEMORY8);
  	end
`else
		mgoto (MEMORY8);
`endif  	
    tPMAEA();
  end
MEMORY8:
  begin
    xlaten <= FALSE;
    dwait <= 3'd0;
//    dadr <= adr_o;
    mgoto (MEMORY9);
`ifdef ANY1_TLB    
		if (tlbmiss) begin
	    rob[membufo.rid].cause <= 16'h8004;
  	  badaddr[3'd4] <= ea;
		  cyc_o <= LOW;
		  stb_o <= LOW;
		  we_o <= 1'b0;
		  sel_o <= 1'd0;
	  end
		else
`endif
		begin
			if (dhit & d_ld & dce) begin
				cyc_o <= LOW;
				stb_o <= LOW;
				sel_o <= 1'b0;
			end
			else begin
      	stb_o <= HIGH;
      	sel_o <= sel[`SELH];
      	dat_o <= dat[`DATH];
    	end
    end
  end
MEMORY9:
  if (dhit & dce) begin
  	datil <= dc_line;
		if (d_st) begin
			if (acki) begin
`ifdef CPU_B128
  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
`endif
`ifdef CPU_B64
 				dci <= (dc_line & stmask) | ((dat << {adr_o[5:3],6'b0}) & ~stmask);
`endif
`ifdef CPU_B32
				dci <= (dc_line & stmask) | ((dat << {adr_o[5:2],5'b0}) & ~stmask);
`endif
  			dc_wway <= dc_rway;
  			dcache_wr <= TRUE;
	      mgoto (MEMORY10);
	      stb_o <= LOW;
	      if (sel[`SELH]==1'h0) begin
	        cyc_o <= LOW;
	        we_o <= LOW;
	        sel_o <= 1'h0;
	      end
	    end
		end
  	else begin
    	dwait <= dwait + 2'd1;
    	if (dwait==3'd2)
      	mgoto (MEMORY10);
    end
	end
  else if (acki) begin
    mgoto (MEMORY10);
    stb_o <= LOW;
    dati[`DATH] <= dat_i;
`ifdef CPU_B128
    cyc_o <= LOW;
    we_o <= LOW;
    sel_o <= 1'h0;
`endif
`ifdef CPU_B64
    cyc_o <= LOW;
    we_o <= LOW;
    sel_o <= 1'h0;
`endif
`ifdef CPU_B32
    if (sel[11:8]==4'h0) begin
      cyc_o <= LOW;
      we_o <= LOW;
      sel_o <= 4'h0;
    end
`endif
  end
MEMORY10:
  if (~acki) begin
`ifdef CPU_B32
    ea <= {ea[31:2]+2'd1,2'b00};
    if (sel[11:8])
      mgoto (MEMORY11);
    else
`endif
    begin
      case(membufo.ir[7:0])
      LDx:
      	begin
      		if (dhit & dce)
      			dati <= datil >> {adr_o[5:3],6'b0};
	        mgoto (DATA_ALIGN);
      	end
	    STx://,`FSTO,`PSTO,
	    	begin
	    		if (membufo.ir.st.func==4'd7) begin	// STPTR
			    	if (ea==32'd0) begin
			    	 	rob[membufo.rid].cmt <= TRUE;
			    	 	rob[membufo.rid].cmt2 <= TRUE;
				    	tMemory1();
			    	end
			    	else begin
			    		shr_ma <= TRUE;
			    		zero_data <= TRUE;
			    		mgoto (MEMORY1c);
			    	end
	    		end
	    		else begin
			    	rob[membufo.rid].cmt <= TRUE;
			    	rob[membufo.rid].cmt2 <= TRUE;
				   	tMemory1();
		      end
	    	end
      default:
        mgoto (DATA_ALIGN);
      endcase
    end
  end
MEMORY11:
  begin
`ifdef ANY1_TLB
    mgoto (MEMORY11a);
`else
    mgoto (MEMORY12);
`endif
    xlaten <= TRUE;
    tEA(ea);
  end
MEMORY11a:
  mgoto (MEMORY12);
MEMORY12:
  mgoto (MEMORY_KEYCHK3);
MEMORY_KEYCHK3:
  begin
`ifdef SUPPORT_KEYCHK
  	if (!kyhit)
  		mgosub(KYLD);
  	else begin
  		mgoto (MEMORY2b);
  		for (n = 0; n < 8; n = n + 1)
  			if (kyut == keys[n] || kyut==20'd0)
  				mgoto(MEMORY13);
  	end
`else
		mgoto(MEMORY13);  	
`endif
    tPMAEA();
  end
MEMORY13:
  begin
    xlaten <= FALSE;
    dwait <= 3'd0;
//    dadr <= adr_o;
    mgoto (MEMORY14);
`ifdef ANY1_TLB    
		if (tlbmiss) begin
	    rob[membufo.rid].cause <= 16'h8004;
  	  badaddr[3'd4] <= ea;
		  cyc_o <= LOW;
		  stb_o <= LOW;
		  we_o <= 1'b0;
		  sel_o <= 1'd0;
	  end
		else
`endif		
		begin
			if (dhit & d_ld) begin
				cyc_o <= LOW;
				stb_o <= LOW;
				sel_o <= 1'b0;
			end
			else begin
      	stb_o <= HIGH;
      	sel_o <= sel[11:8];
      	dat_o <= dat[95:64];
    	end
    end
  end
MEMORY14:
  if (dhit & dce) begin
  	datil <= dc_line;
		if (d_st) begin
			if (acki) begin
`ifdef CPU_B128
  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
`endif
`ifdef CPU_B64
 				dci <= (dc_line & stmask) | ((dat << {adr_o[5:3],6'b0}) & ~stmask);
`endif
`ifdef CPU_B32
				dci <= (dc_line & stmask) | ((dat << {adr_o[5:2],5'b0}) & ~stmask);
`endif
  			dc_wway <= dc_rway;
  			dcache_wr <= TRUE;
	      mgoto (MEMORY15);
	      stb_o <= LOW;
        cyc_o <= LOW;
        we_o <= LOW;
        sel_o <= 1'h0;
	    end
		end
  	else begin
    	dwait <= dwait + 2'd1;
    	if (dwait==3'd2)
      	mgoto (MEMORY15);
    end
	end
  else if (acki) begin
    mgoto (MEMORY15);
    cyc_o <= LOW;
    stb_o <= LOW;
    we_o <= LOW;
    sel_o <= 4'h0;
    dati[95:64] <= dat_i;
  end
MEMORY15:
  if (~acki) begin
    case(membufo.ir[7:0])
    LDx:
    	begin
    		if (dhit & dce)
    			dati <= datil >> {adr_o[5:3],6'b0};
        mgoto (DATA_ALIGN);
    	end
    STx://,`FSTO,`PSTO,
    	begin
    		if (membufo.ir.st.func==4'd7) begin	// STPTR
		    	if (ea==32'd0) begin
		    	 	rob[membufo.rid].cmt <= TRUE;
		    	 	rob[membufo.rid].cmt2 <= TRUE;
			    	tMemory1();
		    	end
		    	else begin
		    		shr_ma <= TRUE;
		    		zero_data <= TRUE;
		    		mgoto (MEMORY1c);
		    	end
    		end
    		else begin
		    	rob[membufo.rid].cmt <= TRUE;
	    	 	rob[membufo.rid].cmt2 <= TRUE;
		    	tMemory1();
	      end
    	end
    default:
      mgoto (DATA_ALIGN);
    endcase
  end
DATA_ALIGN:
  begin
  	if (d_ld & ~dhit & dcachable & dce)
  		mgoto (DFETCH2);
  	else
    	tMemory1();
 	 	funcUnit.cmt <= TRUE;
    case(membufo.ir.r2.opcode)
    LDx:
    	begin
	    	case(membufo.ir.ld.func)
	    	4'd0:	begin funcUnit.res <= {{56{datis[7]}},datis[7:0]}; funcUnit.rid <= membufo.rid; end
	    	4'd1:	begin funcUnit.res <= {{48{datis[15]}},datis[15:0]}; funcUnit.rid <= membufo.rid; end
	    	4'd2:	begin funcUnit.res <= {{32{datis[31]}},datis[31:0]}; funcUnit.rid <= membufo.rid; end
	    	4'd3:	begin funcUnit.res <= datis[63:0]; funcUnit.rid <= membufo.rid; end
	    	4'd7:	begin funcUnit.res <= datis[63:0]; funcUnit.rid <= membufo.rid; end
	    	4'd8:	begin funcUnit.res <= {56'd0,datis[7:0]}; funcUnit.rid <= membufo.rid; end
	    	4'd9:	begin funcUnit.res <= {48'd0,datis[15:0]}; funcUnit.rid <= membufo.rid; end
	    	4'd10:	begin funcUnit.res <= {32'd0,datis[31:0]}; funcUnit.rid <= membufo.rid; end
	    	4'd11:	begin funcUnit.res <= datis[63:0]; funcUnit.rid <= membufo.rid; end
	    	4'd15:	begin funcUnit.res <= datis[63:0]; funcUnit.rid <= membufo.rid; end
	    	default:	;
	    	endcase
    	end
	  //LDOR: res <= datis[63:0];
    //`FLDO,`PLDO:  res <= datis[63:0];
    //`RTS:    pc <= datis[63:0] + {ir[12:9],2'b00};
    //`RTX:    pc <= datis[63:0];
    //`UNLINK:  begin res <= datis[63:0]; Rd <= 5'd30; end
    //`POP:   begin crres <= datis[31:0]; rares <= datis[AWID-1:0]; res <= datis[63:0]; end
    default:  ;
    endcase
  end


DFETCH2:
  begin
    mgoto(DFETCH3);
  end
DFETCH3:
  begin
 		xlaten <= FALSE;
	  begin
  		mgoto (DFETCH3a);
`ifdef ANY1_TLB  		
  		if (tlbmiss) begin
		    funcUnit.cause <= 16'h8004;
			  funcUnit.badAddr <= adr_o;
			end
			else
`endif			
			begin
			  // First time in, set to miss address, after that increment
			  daccess <= TRUE;
`ifdef CPU_B128
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:4],4'h0} + 5'h10;
        end
`endif
`ifdef CPU_B64
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0}
        else begin
          dadr <= {dadr[AWID-1:3],3'h0} + 4'h8;
        end
`endif
`ifdef CPU_B32
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:2],2'h0} + 3'h4;
        end
`endif			
      end
	  end
  end
DFETCH3a:
  begin
    cyc_o <= HIGH;
		stb_o <= HIGH;
`ifdef CPU_B128
    sel_o <= 16'hFFFF;
`endif
`ifdef CPU_B64
    sel_o <= 8'hFF;
`endif
`ifdef CPU_B32
		sel_o <= 4'hF;
`endif
//		adr_o <= dadr;
    mgoto (DFETCH4);
  end
DFETCH4:
  begin
    if (ack_i) begin
      cyc_o <= LOW;
      stb_o <= LOW;
      vpa_o <= LOW;
      sel_o <= 1'h0;
`ifdef CPU_B128
      case(dcnt[3:2])
      2'd0: dci[127:0] <= dat_i;
      2'd1: dci[255:128] <= dat_i;
      2'd2: dci[383:256] <= dat_i;
      2'd3: dci[511:384] <= dat_i;
      endcase
      mgoto (DFETCH5);
`endif
`ifdef CPU_B64
      case(dcnt[3:1])
      3'd0: dci[63:0] <= dat_i;
      3'd1: dci[127:64] <= dat_i;
      3'd2: dci[191:128] <= dat_i;
      3'd3; dci[255:192] <= dat_i;
      3'd4:	dci[319:256] <= dat_i;
      3'd5:	dci[383:320] <= dat_i;
      3'd6:	dci[447:384] <= dat_i;
      3'd7:	dci[511:448] <= dat_i;
      endcase
      mgoto (DFETCH5);
`endif
`ifdef CPU_B32
      case(dcnt[3:0])
      4'd0: dci[31:0] <= dat_i;
      4'd1: dci[63:32] <= dat_i;
      4'd2: dci[95:64] <= dat_i;
      4'd3: dci[127:96] <= dat_i;
      4'd4: dci[159:128] <= dat_i;
      4'd5: dci[191:160] <= dat_i;
      4'd6; dci[223:192] <= dat_i;
      4'd7: dci[255:224] <= dat_i;
      endcase
      mgoto (DFETCH5);
`endif
    end
  end
DFETCH5:
  begin
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3) begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[pL1msb:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[pL1msb:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[pL1msb:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[pL1msb:6]] <= 1'b1;
    	endcase
		end
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7) begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[pL1msb:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[pL1msb:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[pL1msb:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[pL1msb:6]] <= 1'b1;
    	endcase
		end
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15) begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[pL1msb:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[pL1msb:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[pL1msb:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[pL1msb:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[pL1msb:6]] <= 1'b1;
    	endcase
		end
`endif
    if (~ack_i) begin
`ifdef CPU_B128
      dcnt <= dcnt + 4'd4;
`endif
`ifdef CPU_B64
      dcnt <= dcnt + 4'd2;
`endif
`ifdef CPU_B32
      dcnt <= dcnt + 2'd1;
`endif
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3)
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7)
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15)
`endif
    	tMemory1();
		else
      mgoto (DFETCH3);
    end
  end

`ifdef SUPPORT_KEYCHK
KYLD:
  begin
    tEA(keytbl);
`ifdef ANY1_TLB
			mgoto (KYLD2);
`else
    	mgoto(KYLD3);
`endif
  end
KYLD2:
	mgoto (KYLD3);
KYLD3:
  begin
 		xlaten <= FALSE;
	  begin
  		mgoto (KYLD3a);
`ifdef ANY1_TLB  		
  		if (tlbmiss) begin
		    rob[membufo.rid].cause <= 16'h8004;
			  badaddr[3'd4] <= adr_o;
			end
			else
`endif			
			begin
			  // First time in, set to miss address, after that increment
			  daccess <= TRUE;
`ifdef CPU_B128
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:4],4'h0} + 5'h10;
        end
`endif
`ifdef CPU_B64
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0}
        else begin
          dadr <= {dadr[AWID-1:3],3'h0} + 4'h8;
        end
`endif
`ifdef CPU_B32
        if (!daccess)
          dadr <= {adr_o[AWID-1:5],5'h0};
        else begin
          dadr <= {dadr[AWID-1:2],2'h0} + 3'h4;
        end
`endif			
      end
	  end
  end
KYLD3a:
  begin
    cyc_o <= HIGH;
		stb_o <= HIGH;
`ifdef CPU_B128
    sel_o <= 16'hFFFF;
`endif
`ifdef CPU_B64
    sel_o <= 8'hFF;
`endif
`ifdef CPU_B32
		sel_o <= 4'hF;
`endif
//		adr_o <= dadr;
    mgoto (KYLD4);
  end
KYLD4:
  begin
    if (ack_i) begin
      cyc_o <= LOW;
      stb_o <= LOW;
      vpa_o <= LOW;
      sel_o <= 1'h0;
`ifdef CPU_B128
      case(dcnt[3:2])
      2'd0: dci[127:0] <= dat_i;
      2'd1: dci[255:128] <= dat_i;
      2'd2: dci[383:256] <= dat_i;
      2'd3: dci[511:384] <= dat_i;
      endcase
      mgoto (KYLD5);
`endif
`ifdef CPU_B64
      case(dcnt[3:1])
      3'd0: dci[63:0] <= dat_i;
      3'd1: dci[127:64] <= dat_i;
      3'd2: dci[191:128] <= dat_i;
      3'd3; dci[255:192] <= dat_i;
      3'd4:	dci[319:256] <= dat_i;
      3'd5:	dci[383:320] <= dat_i;
      3'd6:	dci[447:384] <= dat_i;
      3'd7:	dci[511:448] <= dat_i;
      endcase
      mgoto (KYLD5);
`endif
`ifdef CPU_B32
      case(dcnt[3:0])
      4'd0: dci[31:0] <= dat_i;
      4'd1: dci[63:32] <= dat_i;
      4'd2: dci[95:64] <= dat_i;
      4'd3: dci[127:96] <= dat_i;
      4'd4: dci[159:128] <= dat_i;
      4'd5: dci[191:160] <= dat_i;
      4'd6; dci[223:192] <= dat_i;
      4'd7: dci[255:224] <= dat_i;
      endcase
      mgoto (KYLD5);
`endif
    end
  end
KYLD5:
  begin
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3) begin
    	kytag[dadr[11:6]] <= dadr[AWID-1:6];
    	kyline[dadr[11:6]] <= dci;
    	kyv[dadr[11:6]] <= 1'b1;
		end
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7) begin
    	kytag[dadr[11:6]] <= dadr[AWID-1:6];
    	kyline[dadr[11:6]] <= dci;
    	kyv[dadr[11:6]] <= 1'b1;
		end
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15) begin
    	kytag[dadr[11:6]] <= dadr[AWID-1:6];
    	kyline[dadr[11:6]] <= dci;
    	kyv[dadr[11:6]] <= 1'b1;
		end
`endif
    if (~ack_i) begin
`ifdef CPU_B128
      dcnt <= dcnt + 4'd4;
`endif
`ifdef CPU_B64
      dcnt <= dcnt + 4'd2;
`endif
`ifdef CPU_B32
      dcnt <= dcnt + 2'd1;
`endif
`ifdef CPU_B128
    if (dcnt[3:2]==2'd3)
`endif
`ifdef CPU_B64
    if (dcnt[3:1]==3'd7)
`endif
`ifdef CPU_B32
    if (dcnt[3:0]==4'd15)
`endif
    	mret();
		else
      mgoto (KYLD3);
    end
  end
`endif
default:	;
	endcase

task tEA;
input Address iea;
begin
  if (MUserMode && d_st && !ea_acr[1])
    rob[membufo.rid].cause <= 16'h8032;
  else if (MUserMode && d_ld && !ea_acr[2])
    rob[membufo.rid].cause <= 16'h8033;
	if (!MUserMode || iea[AWID-1:24]=={AWID-24{1'b1}})
		dadr <= iea;
	else
		dadr <= iea[AWID-4:0] + {sregfile[segsel][AWID-1:4],`SEG_SHIFT};
end
endtask

/*
task tPC;
begin
  if (UserMode & !pc_acr[0])
    tException(32'h80000002,ip);
	if (!UserMode || ip[AWID-1:24]=={AWID-24{1'b1}})
		ladr <= ip;
	else
		ladr <= ip[AWID-2:0] + {sregfile[ip[AWID-1:AWID-4]][AWID-1:4],`SEG_SHIFT};
end
endtask
*/
task tPMAEA;
begin
  if (keyViolation && omode == 3'd0)
    rob[membufo.rid].cause <= 16'h8031;
  // PMA Check
  for (n = 0; n < 8; n = n + 1)
    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
      if ((d_st && !PMA_AT[n][1]) || (d_ld && !PMA_AT[n][2]))
		    rob[membufo.rid].cause <= 16'h803D;
		  dcachable <= PMA_AT[n][3];
    end
end
endtask

task tPMAIP;
begin
  // PMA Check
  // Abort cycle that has already started.
  for (n = 0; n < 8; n = n + 1)
    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
      if (!PMA_AT[n][0]) begin
        rob[rob_que].cause <= 16'h803D;
        cyc_o <= LOW;
    		stb_o <= LOW;
    		vpa_o <= LOW;
    		sel_o <= 4'h0;
    	end
    end
end
endtask

task mgoto;
input [5:0] nst;
begin
	mstate <= nst;
end
endtask

task mgosub;
input [5:0] nst;
begin
	mstk_state <= mstate;
	mstate <= nst;
end
endtask

task mret();
begin
	mstate <= mstk_state;
end
endtask

endmodule
