module pwm8(clk, rst_n, duty, PWM_sig);
	input clk, rst_n;
	input [7:0] duty;
	output logic PWM_sig;
	
	logic cnt_le_duty;
	logic [7:0] cnt;
	
	assign cnt_le_duty = (cnt <= duty);
	
	always_ff @(posedge clk, negedge rst_n) begin // counter logic
		if (!rst_n)
			cnt <= 0;
		else
			cnt <= cnt + 1;
	end

	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			PWM_sig <= 0;
		else
			PWM_sig <= cnt_le_duty;
	end
endmodule