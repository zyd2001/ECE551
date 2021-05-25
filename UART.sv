module UART(clk,rst_n,RX,TX,rx_rdy,clr_rx_rdy,rx_data,trmt,tx_data,tx_done);

input clk,rst_n;		// clock and active low reset
input RX,trmt;		// trmt tells TX section to transmit tx_data
input clr_rx_rdy;		// rx_rdy can be cleared by this or new start bit
input [7:0] tx_data;		// byte to transmit
output TX,rx_rdy,tx_done;	// rx_rdy asserted when byte received,
				// tx_done asserted when tranmission complete
output [7:0] rx_data;		// byte received

    UART_rx iRX(.clk(clk), .rst_n(rst_n), .rx_data(rx_data), 
        .RX(RX), .clr_rdy(clr_rx_rdy), .rdy(rx_rdy));

    UART_tx iTX(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(tx_data), 
        .TX(TX), .tx_done(tx_done));

endmodule
