// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_scheduler.sv
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

module any1_scheduler(clk, rob, rob_que, robo, wakeup_list, selection);
input clk;
input sReorderEntry [ROB_ENTRIES-1:0] rob;
input [5:0] rob_que;
input sReorderEntry robo;
// Wakeup list, one bit for each instruction.
output reg [ROB_ENTRIES-1:0] wakeup_list;
output reg [6:0] selection;

integer n;

// Prevent the scheduler from choosing the same rob slot twice in a row.
// Works for up to the previous three slots.
reg [5:0] already_chosen [0:3];
initial begin
	for (n = 0; n < 4; n = n + 1)
		already_chosen[n] <= 6'd0;
end

always @(posedge clk)
begin
	for (n = 3; n > 0; n = n - 1)
		already_chosen[n] <= already_chosen[n-1];
	already_chosen[0] <= selection;
end

function fnAlreadyChosen;
input [5:0] nn;
begin
	fnAlreadyChosen = (nn==already_chosen[0]) || (nn==already_chosen[1]) || (nn==already_chosen[2]) || (nn==already_chosen[3]);
end
endfunction

// Detect if there are any load/store instruction in the queue before this
// one. The search takes place backwards through the queue until the queueing
// spot is reached. All older instructions should be between the selected
// instruction and the queueing spot.
function fnPriorLdSt;
input [5:0] ridi;
integer n,m;
reg done;
reg uncommitted_ldst;
begin
	done = FALSE;
	uncommitted_ldst = FALSE;
	m = ridi - 1;
	if (m < 0)
		m = ROB_ENTRIES - 1;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (m==rob_que)
			done = TRUE;
		// IF the prior ld/st is already out, it is still safe to issue the next
		// one.
		if (rob[m].mem_op && !rob[m].cmt && !rob[m].out && rob[m].v && !done)
			uncommitted_ldst = TRUE;
		m = m - 1;
		if (m < 0)
			m = ROB_ENTRIES - 1;
	end
	fnPriorLdSt = uncommitted_ldst;
end
endfunction

function fnPriorFC;
input [5:0] ridi;
integer n,m;
reg done;
reg uncommitted_fc;
begin
	done = FALSE;
	uncommitted_fc = FALSE;
	m = ridi - 1;
	if (m < 0)
		m = ROB_ENTRIES - 1;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (m==rob_que)
			done = TRUE;
		if (rob[m].ir.r2.opcode[6:4]==3'd4 && !rob[m].cmt && rob[m].v && !done)
			uncommitted_fc = TRUE;
		m = m - 1;
		if (m < 0)
			m = ROB_ENTRIES - 1;
	end
	fnPriorFC = uncommitted_fc;
end
endfunction

// Instruction Scheduler
// Choose the next instruction to execute.
// Two pieces to the scheduler 1) wakeup 2) selection
function [6:0] fnNextExec;
input [5:0] que;
integer m,n,j;
reg any_woke;
begin
	// -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -
	// 1) Wakeup
	// -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -
	wakeup_list = {ROB_ENTRIES{1'b0}};
	any_woke = FALSE;
	// Search for and find all instructions that might be executed in this clock
	// cycle.
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		// The "out" flag does not become active until the cycle after the
		// instruction is selected for execution. So, to prevent the same
		// instruction from being selected twice, a check of the exec index is
		// made.
		if (rob[n].dec && rob[n].v && !rob[n].cmt && !rob[n].out) begin
			if (rob[n].iav && rob[n].ibv && rob[n].icv && rob[n].idv) begin		// Args are valid
				if (!fnPriorFC(n) && !fnAlreadyChosen(n)) begin
					if (!(rob[n].mem_op && fnPriorLdSt(n))) begin	// and loads / stores are in order
						wakeup_list[n] = 1'b1;
						any_woke = TRUE;
					end
				end
			end
		end
	end

	// -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -
	// 2) Selection
	// -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -
	fnNextExec = {1'b1,6'd63};	// Default: no selection
	if (any_woke) begin
		// Default to choose the first instruction of the list, as that is most
		// likely the oldest one to be executed and has the greatest chance of
		// dependencies.
		m = que - 2'd1;	// start at que point and work backwards
		if (m < 0)
			m = ROB_ENTRIES - 1;
		for (j = 0; j < ROB_ENTRIES; j = j + 1) begin
			if (wakeup_list[m])
				fnNextExec = m;
			m = m - 2'd1;
			if (m < 0)
				m = ROB_ENTRIES - 1;
		end
		// Now search for branch instructions to be executed. We want to 
		// execute branches as early as possible so that there are not a lot of
		// unexecutable instructions loaded into the buffer.
		m = que - 2'd1;	// start at que point and work backwards
		if (m < 0)
			m = ROB_ENTRIES - 1;
		for (j = 0; j < ROB_ENTRIES; j = j + 1) begin
			if (wakeup_list[m]) begin
				if (rob[m].branch)
					fnNextExec = m;
			end
			m = m - 2'd1;
			if (m < 0)
				m = ROB_ENTRIES - 1;
		end
	end
end
endfunction

always_comb
	selection <= fnNextExec(rob_que);

endmodule
