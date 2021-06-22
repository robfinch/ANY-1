// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	any1_BMM.v
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
// 10x10 = 700 LUTs
// 16x16 = 3072 LUTs
// ============================================================================
//
import any1_pkg::*;

module BMM(op,a,b,o);
parameter DBW=64;
parameter N=7;
input [1:0] op;	// 0 = MOR, 1 = MXOR, 2= MOR transpose, 3 = MXOR transpose
input Value a;
input Value b;
output Value o;

integer n,i,j,k;
reg omor[0:N][0:N];
reg omxor[0:N][0:N];
reg am[0:N][0:N];
reg bm[0:N][0:N];

always @*
for (i = 0; i <= N; i = i + 1) begin
	for (j = 0; j <= N; j = j + 1) begin
		am[i][j] = a[(N-i)*(N+1)+(N-j)];
		bm[i][j] = b[(N-i)*(N+1)+(N-j)];
	end
end

always @*
for (i = 0; i <= N; i = i + 1) begin
	for (j = 0; j <= N; j = j + 1) begin
		omor[i][j] = 0;
		omxor[i][j] = 0;
		for (k = 0; k < N; k = k + 1) begin
			omor[i][j] = omor[i][j]|(am[i][k]&bm[k][j]);
			omxor[i][j] = omxor[i][j]^(am[i][k]&bm[k][j]);
		end
	end
end

always @*
case (op[0])
1'b0:	begin
		for (i = 0; i <= N; i = i + 1)
    		for (j = 0; j <= N; j = j + 1)
    			o[(N-i)*(N+1)+(N-j)] = omor[i][j];
    	end
1'b1:	begin
		for (i = 0; i <= N; i = i + 1)
    		for (j = 0; j <= N; j = j + 1)
    			o[(N-i)*(N+1)+(N-j)] = omxor[i][j];
    	end
endcase

endmodule
