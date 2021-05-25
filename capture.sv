module capture(clk,rst_n,wrt_smpl,run,capture_done,triggered,trig_pos,
               we,waddr,set_capture_done,armed);

    parameter ENTRIES = 384,		// defaults to 384 for simulation, use 12288 for DE-0
                LOG2 = 9;			// Log base 2 of number of entries
    
    input clk;					// system clock.
    input rst_n;					// active low asynch reset
    input wrt_smpl;				// from clk_rst_smpl.  Lets us know valid sample ready
    input run;					// signal from cmd_cfg that indicates we are in run mode
    input capture_done;			// signal from cmd_cfg register.
    input triggered;				// from trigger unit...we are triggered
    input [LOG2-1:0] trig_pos;	// How many samples after trigger do we capture
    
    output logic we;					// write enable to RAMs
    output reg [LOG2-1:0] waddr;	// write addr to RAMs
    output logic set_capture_done;		// asserted to set bit in cmd_cfg
    output reg armed;				// we have enough samples to accept a trigger

    typedef enum reg[1:0] {IDLE,CAPTURE,WAIT_RD} state_t;
    state_t state,nxt_state;
    
    reg [LOG2-1:0] trig_cnt;						// how many samples post trigger?
    logic set, clr, start;
    //// you fill in the rest ////
    always_ff @(posedge clk, negedge rst_n) // state flip flop
    begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    always_ff @(posedge clk)
    begin
        if (start)
            trig_cnt <= 0;
        else if (triggered && we)
            trig_cnt <= trig_cnt + 1;
    end

    always_ff @(posedge clk)
    begin
        if (start)
            waddr <= 0;
        else if (we)
        begin
            if (waddr == ENTRIES - 1'b1)
                waddr <= 0;
            else
                waddr <= waddr + 1;
        end
    end

    assign set = (waddr + trig_pos) == (ENTRIES - 1'b1);
    assign we = run & !capture_done & wrt_smpl;

    always_ff @(posedge clk, negedge rst_n)
    begin
        if (!rst_n)
            armed <= 0;
        else if (clr)
            armed <= 0;
        else if (set)
            armed <= 1;
    end


    always_comb
    begin
        nxt_state = state;
        start = 0;
        set_capture_done = 0;
        clr = 0;
        case(state)
            IDLE:
            begin
                if (run)
                begin
                    nxt_state = CAPTURE;
                    start = 1;
                end
            end
            CAPTURE:
            begin
                if ((trig_cnt == trig_pos) && triggered)
                begin
                    nxt_state = WAIT_RD;
                    clr = 1;
                    set_capture_done = 1;
                end
                // else
                //     we = wrt_smpl;
            end
            WAIT_RD:
            begin
                if (!capture_done)
                    nxt_state = IDLE;
            end
            default: nxt_state = IDLE;
        endcase
    end
endmodule
