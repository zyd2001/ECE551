module channel_sample(smpl_clk, CH_L, CH_H, clk, smpl, CH_Lff5, CH_Hff5);
    input smpl_clk, clk, CH_L, CH_H;
    output logic [7:0] smpl;
    output logic CH_Lff5, CH_Hff5;

    logic CH_Lff1, CH_Lff2, CH_Lff3, CH_Lff4;
    logic CH_Hff1, CH_Hff2, CH_Hff3, CH_Hff4;

    always_ff @(posedge clk) begin
        smpl[0] <= CH_Lff5;
        smpl[1] <= CH_Hff5;
        smpl[2] <= CH_Lff4;
        smpl[3] <= CH_Hff4;
        smpl[4] <= CH_Lff3;
        smpl[5] <= CH_Hff3;
        smpl[6] <= CH_Lff2;
        smpl[7] <= CH_Hff2;
    end

    always_ff @(negedge smpl_clk) begin
        CH_Hff1 <= CH_H;
        CH_Hff2 <= CH_Hff1;
        CH_Hff3 <= CH_Hff2;
        CH_Hff4 <= CH_Hff3;
        CH_Hff5 <= CH_Hff4;
        CH_Lff1 <= CH_L;
        CH_Lff2 <= CH_Lff1;
        CH_Lff3 <= CH_Lff2;
        CH_Lff4 <= CH_Lff3;
        CH_Lff5 <= CH_Lff4;
    end

endmodule