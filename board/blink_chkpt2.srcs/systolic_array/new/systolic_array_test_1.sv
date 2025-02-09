`timescale 1ns / 1ps

module systolic_array_test_1;

    localparam DIM = 5;

    reg clk;
    reg rst;
    reg [(DIM*DIM)-1:0][31:0] mat_a;
    reg [(DIM*DIM)-1:0][31:0] mat_b;
    wire [(DIM*DIM)-1:0][31:0] out;
    reg start;
    wire done;

    systolic_array #(.DIM(DIM)
    ) uut (
        .clk(clk),
        .rst(rst),
        .mat_a(mat_a),
        .mat_b(mat_b),
        .out(out),
        .start(start),
        .done(done)
    );
    
    initial begin
        clk <= 0;
        rst <= 1;
        start <= 0;
        for(int i = 0; i < DIM*DIM; i++) begin
            mat_a[i] <= 31'b0;
            mat_b[i] <= 31'b0;
        end
    end
    
    reg [31:0] expected [0:(DIM*DIM)-1];
    initial begin
        expected[0] = 152455;
        expected[1] = 153270;
        expected[2] = 154085;
        expected[3] = 154900;
        expected[4] = 155715;
        expected[5] = 157130;
        expected[6] = 157970;
        expected[7] = 158810;
        expected[8] = 159650;
        expected[9] = 160490;
        expected[10] = 161805;
        expected[11] = 162670;
        expected[12] = 163535;
        expected[13] = 164400;
        expected[14] = 165265;
        expected[15] = 166480;
        expected[16] = 167370;
        expected[17] = 168260;
        expected[18] = 169150;
        expected[19] = 170040;
        expected[20] = 171155;
        expected[21] = 172070;
        expected[22] = 172985;
        expected[23] = 173900;
        expected[24] = 174815;
    end

    // Clock generation
    always #5 clk = ~clk;  // 10 ns clock period

    // Test sequence
    initial begin

        // Reset pulse
        #10 rst = 0;
        #10 rst = 1;

        // Set input matrices
        for(int i = 0; i < DIM*DIM; i++) begin
            mat_a[i] = 32'ha1+i;
            mat_b[i] = 32'hb1+i;
        end

        // Assert start signal
        #10 start = 1;
        #10 start = 0;  // De-assert start after one cycle

        // Wait for the done signal
        wait (done);
        
        for(int i = 0; i < DIM*DIM; i++) begin
            $display("Output: %d", out[i]);
        end

        for(int i = 0; i < DIM*DIM; i++) begin
            if(out[i]!=expected[i]) $fatal("UNEXPECTED RESULT");
        end
        $display("PASSED");

        // Finish simulation
        #20 $finish;
    end

endmodule
