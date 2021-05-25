module dual_PWM(clk, rst_n, VIL, VIH, VIL_PWM, VIH_PWM);
	input clk, rst_n;
	input [7:0] VIL, VIH;
	output VIH_PWM, VIL_PWM;
	
	pwm8 PWM_H(.clk(clk), .rst_n(rst_n), .duty(VIH), .PWM_sig(VIH_PWM));
	pwm8 PWM_L(.clk(clk), .rst_n(rst_n), .duty(VIL), .PWM_sig(VIL_PWM));
endmodule