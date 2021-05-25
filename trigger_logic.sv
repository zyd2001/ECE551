module trigger_logic(clk, rst_n, armed, set_capture_done, protTrig,
	CH1Trig, CH2Trig, CH3Trig, CH4Trig, CH5Trig, triggered);
	input clk, rst_n, armed, set_capture_done, protTrig, CH1Trig, CH2Trig, CH3Trig, CH4Trig, CH5Trig;
	output logic triggered;
	
	logic out; // output of the combinational logic
	
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			triggered <= 1'b0;
		else
			triggered <= out;
	end
	
	always_comb begin
		if (set_capture_done) // knock down triggered if set_capture_done asserted
			out = 1'b0;
		else if (!triggered)
			out = CH1Trig & CH2Trig & CH3Trig & CH4Trig & CH5Trig & protTrig & armed;
		else
			out = triggered;
	end
endmodule