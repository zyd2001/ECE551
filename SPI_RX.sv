module SPI_RX(SS_n, SCLK, MOSI, edg, len8, mask, match, SPItrig, clk, rst_n);
    input clk, rst_n;
    input SS_n, SCLK, MOSI, edg, len8;
    input [15:0] mask, match;
    output SPItrig;

    typedef enum logic { IDLE, RX } state_t;
    state_t state, nxt_state;

    logic SCLK_ff1, SCLK_ff2, SCLK_ff3, SCLK_rise, SCLK_fall, MOSI_ff1, MOSI_ff2, MOSI_ff3, SS_ff1, SS_ff2;
    logic shift, done;
    logic [15:0] shift_reg;

    assign SCLK_rise = ~SCLK_ff3 & SCLK_ff2;
    assign SCLK_fall = SCLK_ff3 & ~SCLK_ff2;

    always_ff @(posedge clk, negedge rst_n) begin // double ff for SS
        if (!rst_n) begin
            SS_ff1 <= 1;
            SS_ff2 <= 1;
        end
        else begin
            SS_ff1 <= SS_n;
            SS_ff2 <= SS_ff1;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin // double ff and edge detector for SCLK
        if (!rst_n) begin
            SCLK_ff1 <= 0;
            SCLK_ff2 <= 0;
            SCLK_ff3 <= 0;
        end
        else begin
            SCLK_ff1 <= SCLK;
            SCLK_ff2 <= SCLK_ff1;
            SCLK_ff3 <= SCLK_ff2;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin // double ff for MOSI
        if (!rst_n) begin
            MOSI_ff1 <= 0;
            MOSI_ff2 <= 0;
            MOSI_ff3 <= 0;
        end
        else begin
            MOSI_ff1 <= MOSI;
            MOSI_ff2 <= MOSI_ff1;
            MOSI_ff3 <= MOSI_ff2;
        end
    end

    always_ff @(posedge clk) begin // datapath
        if (shift)
            shift_reg <= {shift_reg[14:0], MOSI_ff3};
        else
            shift_reg <= shift_reg;
    end

    always_ff @(posedge clk, negedge rst_n) begin // state flop
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    always_comb begin // state transition logic
        nxt_state = state;
        shift = 0;
        done = 0;
        case(state)
            IDLE: begin
                if (!SS_ff2) begin
                    nxt_state = RX;
                end
            end
            RX: begin
                if (SS_ff2) begin
                    nxt_state = IDLE;
                    done = 1;
                end
                else begin
                    if ((edg && SCLK_rise) || (!edg && SCLK_fall)) 
                        shift = 1;
                end
            end
        endcase
    end

    assign SPItrig = done && ((len8) ? ((match[7:0] & ~mask[7:0]) == (shift_reg[7:0] & ~mask[7:0])) : 
        ((match & ~mask) == (shift_reg & ~mask)));
endmodule