module CommMaster(cmd, send_cmd, cmd_sent, resp_rdy, resp, RX, TX, clr_resp_rdy, clk, rst_n);
    input clk, rst_n;
    input send_cmd, RX, clr_resp_rdy;
    input [15:0] cmd;
    output TX;
    output resp_rdy;
    output [7:0] resp;
    output logic cmd_sent;

    typedef enum logic [1:0] { IDLE, HIGH, LOW, CMPLT } state_t;
    logic sel, trmt;
    logic [7:0] tx_data, low;
    state_t state, nxt_state;

    UART_tx iTX(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(tx_data), 
        .TX(TX), .tx_done(tx_done));

    UART_rx iRX(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_resp_rdy), .rdy(resp_rdy), .rx_data(resp));

    assign tx_data = (sel) ? cmd[15:8] : low;

    always_ff @(posedge clk) begin
        if (send_cmd)
            low <= cmd[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        trmt = 0;
        sel = 0;
        cmd_sent = 0;
        case(state)
            IDLE: begin
                if (send_cmd) begin
                    nxt_state = HIGH;
                    trmt = 1;
                    sel = 1;
                end
            end
            HIGH: begin
                if (tx_done) begin
                    nxt_state = LOW;
                    trmt = 1;
                end
            end
            LOW: begin
                if (tx_done) begin
                    nxt_state = CMPLT;
                    cmd_sent = 1;
                end
            end
            CMPLT: begin
                if (send_cmd) begin
                    nxt_state = HIGH;
                    trmt = 1;
                    sel = 1;
                end
                else
                    cmd_sent = 1;
            end
            default: nxt_state = IDLE;
        endcase
    end

endmodule