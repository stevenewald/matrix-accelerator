`timescale 1ns / 1ps

module systolic_array_test_1;

    // Testbench signals
    reg clk;
    reg rst;
    reg [8:0][31:0] mat_a;
    reg [8:0][31:0] mat_b;
    wire [8:0][31:0] out;
    reg start;
    wire done;

    // Instantiate the systolic_array module
    systolic_array uut (
        .clk(clk),
        .rst(rst),
        .mat_a(mat_a),
        .mat_b(mat_b),
        .out(out),
        .start(start),
        .done(done)
    );
    
    initial begin
            // Initialize signals
        clk <= 0;
        rst <= 1;
        start <= 0;
        for(int i = 0; i < 9; i++) begin
            mat_a[i] <= 31'b0;
            mat_b[i] <= 31'b0;
        end
    end
    
    reg [31:0] expected [0:8];
    initial begin
        expected[0] = 87486;
        expected[1] = 87972;
        expected[2] = 88458;
        expected[3] = 89106;
        expected[4] = 89601;
        expected[5] = 90096;
        expected[6] = 90726;
        expected[7] = 91230;
        expected[8] = 91734;
    end

    // Clock generation
    always #5 clk = ~clk;  // 10 ns clock period

    // Test sequence
    initial begin

        // Reset pulse
        #10 rst = 0;
        #10 rst = 1;

        // Set input matrices
        for(int i = 0; i < 9; i++) begin
            mat_a[i] = 32'ha1+i;
            mat_b[i] = 32'hb1+i;
        end

        // Assert start signal
        #10 start = 1;
        #10 start = 0;  // De-assert start after one cycle

        // Wait for the done signal
        wait (done);

        // Display results
        $display("Output: %d, %d, %d, %d, %d, %d, %d, %d, %d", out[0], out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8]);
        
        
        for(int i = 0; i < 9; i++) begin
            if(out[i]!=expected[i]) $fatal("UNEXPECTED RESULT");
        end
        $display("PASSED");

        // Finish simulation
        #20 $finish;
    end

endmodule
