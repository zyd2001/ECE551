module RAMqueue(clk, we, waddr, wdata, raddr, rdata);
	parameter ENTRIES = 384;
	parameter LOG2 = 9;
	
	input clk, we;
	input [LOG2-1:0] waddr, raddr;
	input [7:0] wdata;
	output reg [7:0] rdata;
	
    // synopsys translate_off
	reg [7:0] mem[0:ENTRIES-1];
	
	always @(posedge clk) begin
		rdata <= mem[raddr];
		if (we == 1) begin
			mem[waddr] <= wdata;
		end
	end
    // synopsys translate_on
endmodule