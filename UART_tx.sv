module UART_tx(clk, rst_n, trmt, tx_data, TX, tx_done);
    input clk, rst_n, trmt;
    input [7:0] tx_data;
    output TX;
    output logic tx_done;

    typedef enum logic {IDLE, TRANS} state_t;
    state_t state, nxt_state;

    logic [9:0] tx_shft_reg;
    logic [5:0] baud_cnt;
    logic [3:0] bit_cnt;
    logic load, transmitting, shift, set_done;

    assign TX = tx_shft_reg[0];
    assign shift = (baud_cnt == 6'd33);  // 34 cycles

    always_ff @(posedge clk, negedge rst_n) begin // shift register
        if (!rst_n)
            tx_shft_reg <= 10'hfff;
        else
            casex ({load, shift})
                2'b1x: tx_shft_reg <= {1'b1, tx_data, 1'b0};
                2'b01: tx_shft_reg <= {1'b1, tx_shft_reg[9:1]};
                2'b00: tx_shft_reg <= tx_shft_reg;
            endcase
    end

    always_ff @(posedge clk) begin
        casex ({load|shift, transmitting}) // baud counter
            2'b1x: baud_cnt <= 6'b0;
            2'b01: baud_cnt <= baud_cnt + 1;
            2'b00: baud_cnt <= baud_cnt;
        endcase
        
        casex ({load, shift}) // bit counter
            2'b1x: bit_cnt <= 4'b0;
            2'b01: bit_cnt <= bit_cnt + 1;
            2'b00: bit_cnt <= bit_cnt;
        endcase
    end

    always_ff @(posedge clk, negedge rst_n) begin // state ff
        if (!rst_n) 
            state <= IDLE;
        else 
            state <= nxt_state;
    end

    always_ff @(posedge clk, negedge rst_n) begin // tx_done ff
        if (!rst_n)
            tx_done <= 0;
        else if (set_done)
            tx_done <= 1;
        else if (load)
            tx_done <= 0;
    end

    always_comb begin // state logic
        nxt_state = state;
        load = 0;
        set_done = 0;
        transmitting = 0;
        case (state) 
            IDLE: begin
                if (trmt) begin
                    nxt_state = TRANS;
                    load = 1;
                end
            end
            TRANS: begin
                transmitting = 1;
                if (shift && bit_cnt >= 4'h9) begin // stop at the 10 bits
                    nxt_state = IDLE;
                    set_done = 1;
                end
            end
        endcase
    end
endmodule
