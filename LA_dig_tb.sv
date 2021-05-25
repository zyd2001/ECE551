`timescale 1ns / 100ps
module LA_dig_tb();
			
//// Interconnects to DUT/support defined as type wire /////
wire clk400MHz,locked;			// PLL output signals to DUT
wire clk;						// 100MHz clock generated at this level from clk400MHz
wire VIH_PWM,VIL_PWM;			// connect to PWM outputs to monitor
wire CH1L,CH1H,CH2L,CH2H,CH3L;	// channel data inputs from AFE model
wire CH3H,CH4L,CH4H,CH5L,CH5H;	// channel data inputs from AFE model
wire RX,TX;						// interface to host
wire cmd_sent,resp_rdy;			// from master UART, monitored in test bench
wire [7:0] resp;				// from master UART, reponse received from DUT
wire tx_prot;					// UART signal for protocol triggering
wire SS_n,SCLK,MOSI;			// SPI signals for SPI protocol triggering
wire CH1L_mux,CH1H_mux;         // output of muxing logic for CH1 to enable testing of protocol triggering
wire CH2L_mux,CH2H_mux;			// output of muxing logic for CH2 to enable testing of protocol triggering
wire CH3L_mux,CH3H_mux;			// output of muxing logic for CH3 to enable testing of protocol triggering
logic [15:0] SPI_tx_data;
logic SPI_pos_edge, SPI_width8;

////// Stimulus is declared as type reg ///////
reg REF_CLK, RST_n;
reg [15:0] host_cmd;			// command host is sending to DUT
reg send_cmd;					// asserted to initiate sending of command
reg clr_resp_rdy;				// asserted to knock down resp_rdy
reg [1:0] clk_div;				// counter used to derive 100MHz clk from clk400MHz
reg strt_tx;					// kick off unit used for protocol triggering
reg en_AFE;
reg capture_done_bit;			// flag used in polling for capture_done
reg [7:0] res,exp;				// used to store result and expected read from files

wire AFE_clk;

///////////////////////////////////////////
// Channel Dumps can be written to file //
/////////////////////////////////////////
integer fptr1;		// file pointer for CH1 dumps
integer fptr2;		// file pointer for CH2 dumps
integer fptr3;		// file pointer for CH3 dumps
integer fptr4;		// file pointer for CH4 dumps
integer fptr5;		// file pointer for CH5 dumps
integer fexp;		// file pointer to file with expected results
integer found_res,found_expected,loop_cnt;
integer mismatches;	// number of mismatches when comparing results to expected
integer sample;		// sample counter in dump & compare

///////////////////////////
// Define command bytes //
/////////////////////////
localparam DUMP_CH1  = 8'h81;		// Dump channel 1
localparam DUMP_CH2  = 8'h82;		// Dump channel 2
localparam DUMP_CH3  = 8'h83;		// Dump channel 3
localparam DUMP_CH4  = 8'h84;		// Dump channel 4
localparam DUMP_CH5  = 8'h85;		// Dump channel 5
localparam TRIG_CFG_RD = 8'h00;		// Used to read TRIG_CFG register
localparam SET_DEC     = 8'h46;		// Write to decimator register
localparam SET_VIH_PWM = 8'h47;		// Set VIH trigger level [255:0] are valid values
localparam SET_VIL_PWM = 8'h48;		// Set VIL trigger level [255:0] are valid values
localparam RD_CH1_TRG  = 8'h01;		// read CH1 trigger config register
localparam SET_CH1_TRG = 8'h41;		// Write to CH1 trigger config register
localparam SET_CH2_TRG = 8'h42;		// Write to CH2 trigger config register
localparam SET_CH3_TRG = 8'h43;		// Write to CH3 trigger config register
localparam SET_CH4_TRG = 8'h44;		// Write to CH4 trigger config register
localparam SET_CH5_TRG = 8'h45;		// Write to CH5 trigger config register
localparam SET_TRG_CFG = 8'h40;		// Write to TrigCfg register
localparam RD_TRGPOSL  = 8'h10;		// read trig_posH register
localparam WRT_TRGPOSH = 8'h4F;		// Write to trig_posH register
localparam WRT_TRGPOSL = 8'h50;		// Write to trig_posL register
localparam SET_MATCHH  = 8'h49;		// Write to matchH register
localparam SET_MATCHL  = 8'h4A;		// Write to matchL register
localparam SET_MASKH   = 8'h4B;		// Write to maskH register
localparam SET_MASKL   = 8'h4C;		// Write to maskL register
localparam SET_BAUDH   = 8'h4D;		// Write to baudD register
localparam SET_BAUDL   = 8'h4E;		// Write to baudL register
localparam POS_ACK = 8'hA5;
localparam NEG_ACK = 8'hEE;
/////////////////////////////////
localparam UART_triggering = 1'b0;	// set to true if testing UART based triggering
logic SPI_triggering;	// set to true if testing SPI based triggering

assign AFE_clk = en_AFE & clk400MHz;
///// Instantiate Analog Front End model (provides stimulus to channels) ///////
AFE iAFE(.smpl_clk(AFE_clk),.VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),
         .CH1L(CH1L),.CH1H(CH1H),.CH2L(CH2L),.CH2H(CH2H),.CH3L(CH3L),
         .CH3H(CH3H),.CH4L(CH4L),.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H));
		 
//// Mux for muxing in protocol triggering for CH1 /////
assign {CH1H_mux,CH1L_mux} = (UART_triggering) ? {2{tx_prot}} :		// assign to output of UART_tx used to test UART triggering
                             (SPI_triggering) ? {2{SS_n}}: 			// assign to output of SPI SS_n if SPI triggering
				             {CH1H,CH1L};

//// Mux for muxing in protocol triggering for CH2 /////
assign {CH2H_mux,CH2L_mux} = (SPI_triggering) ? {2{SCLK}}: 			// assign to output of SPI SCLK if SPI triggering
				             {CH2H,CH2L};	

//// Mux for muxing in protocol triggering for CH3 /////
assign {CH3H_mux,CH3L_mux} = (SPI_triggering) ? {2{MOSI}}: 			// assign to output of SPI MOSI if SPI triggering
				             {CH3H,CH3L};					  
	 
////// Instantiate DUT ////////		  
LA_dig iDUT(.clk400MHz(clk400MHz),.RST_n(RST_n),.locked(locked),
            .VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),.CH1L(CH1L_mux),.CH1H(CH1H_mux),
			.CH2L(CH2L_mux),.CH2H(CH2H_mux),.CH3L(CH3L_mux),.CH3H(CH3H_mux),.CH4L(CH4L),
			.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H),.RX(RX),.TX(TX));

///// Instantiate PLL to provide 400MHz clk from 50MHz ///////
pll8x iPLL(.ref_clk(REF_CLK),.RST_n(RST_n),.out_clk(clk400MHz),.locked(locked));

///// It is useful to have a 100MHz clock at this level similar //////
///// to main system clock (clk).  So we will create one        //////
always @(posedge clk400MHz, negedge locked)
  if (~locked)
    clk_div <= 2'b00;
  else
    clk_div <= clk_div+1;
assign clk = clk_div[1];

//// Instantiate Master UART (mimics host commands) //////
CommMaster iMSTR(.clk(clk), .rst_n(RST_n), .RX(TX), .TX(RX),
                     .cmd(host_cmd), .send_cmd(send_cmd),
					 .cmd_sent(cmd_sent), .resp_rdy(resp_rdy),
					 .resp(resp), .clr_resp_rdy(clr_resp_rdy));
					 
////////////////////////////////////////////////////////////////
// Instantiate transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////
UART_tx iTX(.clk(clk), .rst_n(RST_n), .TX(tx_prot), .trmt(strt_tx),
            .tx_data(8'h96), .tx_done());
					 
////////////////////////////////////////////////////////////////////
// Instantiate SPI transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////////
SPI_TX iSPI(.clk(clk),.rst_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.wrt(strt_tx),.done(done),
            .tx_data(SPI_tx_data),.MOSI(MOSI),.pos_edge(SPI_pos_edge),.width8(SPI_width8));

initial begin
    //// Initialization ////
    initialize;

    // I dump the data for all 5 channels in most tests, 
    // so the test bench takes several minutes to run.

    // test0 register read/write
    $display("test0");
    send(SET_CH1_TRG, 8'hff);
    read(RD_CH1_TRG);
    if (resp !== 8'h1f)
    begin
        $display("Expect 1f, %h received", resp);
        $stop;
    end
    send(WRT_TRGPOSL, 8'hab);
    read(RD_TRGPOSL);
    if (resp !== 8'hab)
    begin
        $display("Expect ab, %h received", resp);
        $stop;
    end
    send(WRT_TRGPOSL, 8'h01);
    send(SET_TRG_CFG, 8'hef);
    read(TRIG_CFG_RD);
    if (resp !== 8'h2f)
    begin
        $display("Expect 2f, %h received", resp);
        $stop;
    end
    pass(0);

    // test1
    $display("test1");
    send(SET_CH1_TRG, 8'h10);
    en_AFE = 1;
    send(SET_TRG_CFG, 8'h13);
    wait_capture;
    write_files(1);
    dump_all;
    close_files;
    en_AFE = 0;
    fptr1 = $fopen("test1_CH1dmp.txt", "r");
    fexp = $fopen("test1_CH1_expected.txt", "r");
    compare(fexp, fptr1);
    $fclose(fptr1);
    $fclose(fexp);
    pass(1);

    // test2 different VIH, VIL
    $display("test2");
    send(SET_VIH_PWM, 8'hCC);
    send(SET_VIL_PWM, 8'h22);
    en_AFE = 1;
    send(SET_TRG_CFG, 8'h13);
    wait_capture;
    write_files(2);
    dump_all;
    close_files;
    en_AFE = 0;

    // test3 different Decimator
    $display("test3");
    send(SET_VIH_PWM, 8'hAA);
    send(SET_VIL_PWM, 8'h55);
    send(SET_DEC, 8'h3);
    en_AFE = 1;
    send(SET_TRG_CFG, 8'h13);
    wait_capture;
    write_files(3);
    dump_all;
    close_files;
    en_AFE = 0;

    // test4 different trig_pos
    $display("test4");
    send(SET_DEC, 8'h0);
    send(WRT_TRGPOSL, 8'h12);
    en_AFE = 1;
    send(SET_TRG_CFG, 8'h13);
    wait_capture;
    write_files(4);
    dump_all;
    close_files;
    en_AFE = 0;

    // test5 different Channel trig
    $display("test5");
    send(WRT_TRGPOSL, 8'h01);
    send(SET_CH1_TRG, 8'h01);
    send(SET_CH5_TRG, 8'h10);
    en_AFE = 1;
    send(SET_TRG_CFG, 8'h13);
    wait_capture;
    fptr1 = $fopen("test5_CH5dmp.txt","w");
    dump(DUMP_CH5, fptr1);
    $fclose(fptr1);
    en_AFE = 0;

    // test6 Channel neg edge trig
    $display("test6");
    send(SET_CH5_TRG, 8'h08);
    en_AFE = 1;
    send(SET_TRG_CFG, 8'h13);
    wait_capture;
    fptr1 = $fopen("test6_CH5dmp.txt","w");
    dump(DUMP_CH5, fptr1);
    $fclose(fptr1);
    en_AFE = 0;
    
    // test7 SPI trigger
    $display("test7");
    SPI_triggering = 1;

    // this setting of decimator and trig_pos can
    // put the waveform at the center
    send(SET_DEC, 8'h1); 
    send(WRT_TRGPOSL, 8'h38);

    send(SET_CH5_TRG, 8'h01);
    send(SET_MATCHH, 8'hf0);
    send(SET_MATCHL, 8'hf1);
    send(SET_TRG_CFG, 8'h11);
    SPI_tx_data = 16'hf0f1;
    start_tx;
    wait_capture;
    fptr1 = $fopen("test7_CH3dmp.txt","w");
    dump(DUMP_CH3, fptr1);
    $fclose(fptr1);

    // test8 SPI trigger with mask
    $display("test8");
    send(SET_MATCHH, 8'hee);
    send(SET_MATCHL, 8'hcc);
    send(SET_MASKH, 8'h10);
    send(SET_MASKL, 8'h0f);
    send(SET_TRG_CFG, 8'h11);
    SPI_tx_data = 16'hfec8;
    start_tx;
    wait_capture;
    fptr1 = $fopen("test8_CH3dmp.txt","w");
    dump(DUMP_CH3, fptr1);
    $fclose(fptr1);

    $stop();
end

always
  #10.4 REF_CLK = ~REF_CLK;

`include "tb_tasks.txt"

endmodule	
