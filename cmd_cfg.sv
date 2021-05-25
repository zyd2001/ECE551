module cmd_cfg(clk,rst_n,resp,send_resp,resp_sent,cmd,cmd_rdy,clr_cmd_rdy,
               set_capture_done,raddr,rdataCH1,rdataCH2,rdataCH3,rdataCH4,
                rdataCH5,waddr,trig_pos,decimator,maskL,maskH,matchL,matchH,
                baud_cntL,baud_cntH,TrigCfg,CH1TrigCfg,CH2TrigCfg,CH3TrigCfg,
                CH4TrigCfg,CH5TrigCfg,VIH,VIL);
                
    parameter ENTRIES = 384,	// defaults to 384 for simulation, use 12288 for DE-0
                LOG2 = 9;		// Log base 2 of number of entries
                
    input clk,rst_n;
    input [15:0] cmd;			// 16-bit command from UART (host) to be executed
    input cmd_rdy;			// indicates command is valid
    input resp_sent;			// indicates transmission of resp[7:0] to host is complete
    input set_capture_done;	// from the capture module (sets capture done bit in TrigCfg)
    input [LOG2-1:0] waddr;		// on a dump raddr is initialized to waddr
    input [7:0] rdataCH1;		// read data from RAMqueues
    input [7:0] rdataCH2,rdataCH3;
    input [7:0] rdataCH4,rdataCH5;
    output logic [7:0] resp;		// data to send to host as response (formed in SM)
    output logic send_resp;				// used to initiate transmission to host (via UART)
    output logic clr_cmd_rdy;			// when finished processing command use this to knock down cmd_rdy
    output logic [LOG2-1:0] raddr;		// read address to RAMqueues (same address to all queues)
    output logic [LOG2-1:0] trig_pos;	// how many sample after trigger to capture
    output reg [3:0] decimator;	// goes to clk_rst_smpl block
    output reg [7:0] maskL,maskH;				// to trigger logic for protocol triggering
    output reg [7:0] matchL,matchH;			// to trigger logic for protocol triggering
    output reg [7:0] baud_cntL,baud_cntH;		// to trigger logic for UART triggering
    output reg [5:0] TrigCfg;					// some bits to trigger logic, others to capture unit
    output reg [4:0] CH1TrigCfg,CH2TrigCfg;	// to channel trigger logic
    output reg [4:0] CH3TrigCfg,CH4TrigCfg;	// to channel trigger logic
    output reg [4:0] CH5TrigCfg;				// to channel trigger logic
    output reg [7:0] VIH,VIL;					// to dual_PWM to set thresholds
    
    typedef enum logic [1:0] { IDLE, DUMP, LOAD, DUMP_WAIT } state_t;
    
    state_t state,nstate;

    logic write, clear, inc;
    logic [LOG2-1:0] count;

    always_ff @(posedge clk)
    begin
        if (clear)
        begin
            raddr <= waddr;
            count <= 0;
        end
        else if (inc)
        begin
            count <= count + 1;
            if (raddr == ENTRIES - 1'b1)
                raddr <= 0;
            else
                raddr <= raddr + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= IDLE;
        else
            state <= nstate;

    always_ff @(posedge clk, negedge rst_n)
    begin
        if (!rst_n)
        begin
            TrigCfg <= 6'h03;
            CH1TrigCfg <= 5'h01;
            CH2TrigCfg <= 5'h01;
            CH3TrigCfg <= 5'h01;
            CH4TrigCfg <= 5'h01;
            CH5TrigCfg <= 5'h01;
            decimator <= 4'h0;
            VIH <= 8'hAA;
            VIL <= 8'h55;
            matchH <= 8'h00;
            matchL <= 8'h00;
            maskH <= 8'h00;
            maskL <= 8'h00;
            baud_cntH <= 8'h06;
            baud_cntL <= 8'hc8;
            trig_pos <= {{LOG2-1{1'b0}}, 1'b1};
        end
        else if (write)
        begin
            case(cmd[13:8])
                6'h00: TrigCfg <= cmd[5:0];
                6'h01: CH1TrigCfg <= cmd[4:0];
                6'h02: CH2TrigCfg <= cmd[4:0];
                6'h03: CH3TrigCfg <= cmd[4:0];
                6'h04: CH4TrigCfg <= cmd[4:0];
                6'h05: CH5TrigCfg <= cmd[4:0];
                6'h06: decimator <= cmd[3:0];
                6'h07: VIH <= cmd[7:0];
                6'h08: VIL <= cmd[7:0];
                6'h09: matchH <= cmd[7:0];
                6'h0a: matchL <= cmd[7:0];
                6'h0b: maskH <= cmd[7:0];
                6'h0c: maskL <= cmd[7:0];
                6'h0d: baud_cntH <= cmd[7:0];
                6'h0e: baud_cntL <= cmd[7:0];
                6'h0f: trig_pos[LOG2-1:8] <= cmd[LOG2-9:0];
                6'h10: trig_pos[7:0] <= cmd[7:0];
            endcase
        end
        else if (set_capture_done)
            TrigCfg[5] <= 1;
    end

    always_comb 
    begin
        nstate = state;
        resp = 0;
        send_resp = 0;
        write = 0;
        clear = 0;
        inc = 0;
        clr_cmd_rdy = 0;
        case(state)
            IDLE: 
            begin
                if (cmd_rdy)
                begin
                    case(cmd[15:14])
                        2'b00:
                        begin
                            nstate = IDLE;
                            clr_cmd_rdy = 1;
                            send_resp = 1;
                            case(cmd[13:8])
                                6'h00: resp = {2'b0, TrigCfg};
                                6'h01: resp = {3'b0, CH1TrigCfg};
                                6'h02: resp = {3'b0, CH2TrigCfg};
                                6'h03: resp = {3'b0, CH3TrigCfg};
                                6'h04: resp = {3'b0, CH4TrigCfg};
                                6'h05: resp = {3'b0, CH5TrigCfg};
                                6'h06: resp = {4'b0, decimator};
                                6'h07: resp = VIH;
                                6'h08: resp = VIL;
                                6'h09: resp = matchH;
                                6'h0a: resp = matchL;
                                6'h0b: resp = maskH;
                                6'h0c: resp = maskL;
                                6'h0d: resp = baud_cntH;
                                6'h0e: resp = baud_cntL;
                                6'h0f: resp = trig_pos[LOG2-1:8];
                                6'h10: resp = trig_pos[7:0];
                            endcase
                        end
                        2'b01: 
                        begin
                            nstate = IDLE;
                            clr_cmd_rdy = 1;
                            write = 1;
                            resp = 8'ha5;
                            send_resp = 1;
                        end
                        2'b10: 
                        begin
                            nstate = LOAD;
                            clear = 1;
                        end
                        default: 
                        begin
                            nstate = IDLE;
                            clr_cmd_rdy = 1;
                            resp = 8'hee;
                            send_resp = 1;
                        end
                    endcase
                end
            end
            DUMP:
            begin
                case(cmd[10:8])
                    3'h1: resp = rdataCH1;
                    3'h2: resp = rdataCH2;
                    3'h3: resp = rdataCH3;
                    3'h4: resp = rdataCH4;
                    3'h5: resp = rdataCH5;
                endcase
                if (count < ENTRIES)
                begin
                    nstate = DUMP_WAIT;
                    send_resp = 1;
                    inc = 1;
                end
                else
                begin
                    nstate = IDLE;
                    clr_cmd_rdy = 1;
                end
            end
            DUMP_WAIT:
            begin
                if (resp_sent)
                begin
                    nstate = DUMP;
                end
            end
            LOAD: 
            begin
                nstate = DUMP;
            end
        endcase
    end


endmodule
  