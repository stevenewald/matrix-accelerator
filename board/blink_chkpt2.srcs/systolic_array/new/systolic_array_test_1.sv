`timescale 1ns / 1ps

module systolic_array_test_1;

    localparam LARGE_DIM = 5;
    localparam SMALL_DIM = 2;

    reg clk;
    reg rst;
    
    reg [(LARGE_DIM*LARGE_DIM)-1:0][31:0] l_mat_a;
    reg [(LARGE_DIM*LARGE_DIM)-1:0][31:0] l_mat_b;
    wire [(LARGE_DIM*LARGE_DIM)-1:0][31:0] l_out;
    
    reg s_accumulate;
    reg [(SMALL_DIM*SMALL_DIM)-1:0][31:0] s_mat_a;
    reg [(SMALL_DIM*SMALL_DIM)-1:0][31:0] s_mat_b;
    wire [(SMALL_DIM*SMALL_DIM)-1:0][31:0] s_out;
    
    reg l_start;
    wire l_done;
    
    reg s_start;
    wire s_done;

    systolic_array #(.DIM(LARGE_DIM)
    ) large_arr (
        .clk(clk),
        .rst(rst),
        .mat_a(l_mat_a),
        .mat_b(l_mat_b),
        .out(l_out),
        .accumulate(0),
        .start(l_start),
        .done(l_done)
    );
    
    systolic_array #(.DIM(SMALL_DIM)
    ) small_arr (
        .clk(clk),
        .rst(rst),
        .mat_a(s_mat_a),
        .mat_b(s_mat_b),
        .out(s_out),
        .accumulate(s_accumulate),
        .start(s_start),
        .done(s_done)
    );
    
    initial begin
        clk <= 0;
        rst <= 1;
        s_start <= 0;
        l_start <= 0;
        s_accumulate <= 0;
        for(int i = 0; i < LARGE_DIM*LARGE_DIM; i++) begin
            l_mat_a[i] <= 31'b0;
            l_mat_b[i] <= 31'b0;
        end
        for(int i = 0; i < SMALL_DIM*SMALL_DIM; i++) begin
            s_mat_a[i] <= 31'b0;
            s_mat_b[i] <= 31'b0;
        end
    end
    
    reg [31:0] l_expected [0:(LARGE_DIM*LARGE_DIM)-1];
    reg [31:0] s_expected [0:(SMALL_DIM*SMALL_DIM)-1];
    
    initial begin
        s_expected[0] = 57495;
        s_expected[1] = 57818;
        s_expected[2] = 58207;
        s_expected[3] = 58534;
    
        l_expected[0] = 152455;
        l_expected[1] = 153270;
        l_expected[2] = 154085;
        l_expected[3] = 154900;
        l_expected[4] = 155715;
        l_expected[5] = 157130;
        l_expected[6] = 157970;
        l_expected[7] = 158810;
        l_expected[8] = 159650;
        l_expected[9] = 160490;
        l_expected[10] = 161805;
        l_expected[11] = 162670;
        l_expected[12] = 163535;
        l_expected[13] = 164400;
        l_expected[14] = 165265;
        l_expected[15] = 166480;
        l_expected[16] = 167370;
        l_expected[17] = 168260;
        l_expected[18] = 169150;
        l_expected[19] = 170040;
        l_expected[20] = 171155;
        l_expected[21] = 172070;
        l_expected[22] = 172985;
        l_expected[23] = 173900;
        l_expected[24] = 174815;
    end

    // Clock generation
    always #5 clk = ~clk;  // 10 ns clock period

    // Test sequence
    initial begin

        // Reset pulse
        #10 rst = 0;
        #10 rst = 1;
        
        for(int i = 0; i < SMALL_DIM*SMALL_DIM; i++) begin
            s_mat_a[i] = 32'ha1+i;
            s_mat_b[i] = 32'hb1+i;
        end
        
        s_accumulate = 1;
        
        #10 s_start = 1;
        #10 s_start = 0;
        
        wait(s_done);
        
        for(int i = 0; i < SMALL_DIM*SMALL_DIM; i++) begin
            if(s_out[i]!=s_expected[i]) $fatal("UNEXPECTED SMALL RESULT. EXECTED %d GOT %d", s_expected[i], s_out[i]);
        end
        $display("SMALL PASSED");
        
        #10 s_start = 1;
        #10 s_start = 0;
        
        wait(s_done);
        
        for(int i = 0; i < SMALL_DIM*SMALL_DIM; i++) begin
            if(s_out[i]!=2*s_expected[i]) $fatal("UNEXPECTED SMALL RESULT ACCUMULATION. EXECTED %d GOT %d", 2*s_expected[i], s_out[i]);
        end
        
        s_accumulate = 0;
        #10 s_start = 1;
        #10 s_start = 0;
        
        wait(s_done);
        
        for(int i = 0; i < SMALL_DIM*SMALL_DIM; i++) begin
            if(s_out[i]!=s_expected[i]) $fatal("UNEXPECTED SMALL RESULT RESET AFTER ACCUMULATION OFF. EXECTED %d GOT %d", 2*s_expected[i], s_out[i]);
        end
        $display("SMALL PASSED ACCUMULATION");

        // Set input matrices
        for(int i = 0; i < LARGE_DIM*LARGE_DIM; i++) begin
            l_mat_a[i] = 32'ha1+i;
            l_mat_b[i] = 32'hb1+i;
        end

        // Assert start signal
        #10 l_start = 1;
        #10 l_start = 0;  // De-assert start after one cycle

        // Wait for the done signal
        wait (l_done);

        for(int i = 0; i < LARGE_DIM*LARGE_DIM; i++) begin
            if(l_out[i]!=l_expected[i]) $fatal("UNEXPECTED LARGE RESULT. EXECTED %d GOT %d", l_expected[i], l_out[i]);
        end
        $display("LARGE PASSED");

        // Finish simulation
        #20 $finish;
    end

endmodule
