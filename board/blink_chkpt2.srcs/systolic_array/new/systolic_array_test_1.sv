`timescale 1ns / 1ps

module systolic_array_test_1;

    // Testbench signals
    reg clk;
    reg rst;
    reg [3:0][31:0] mat_a;
    reg [3:0][31:0] mat_b;
    wire [3:0][31:0] out;
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
        mat_a[0] <= 31'b0;
        mat_a[1] <= 31'b0;
        mat_a[2] <= 31'b0;
        mat_a[3] <= 31'b0;
        mat_b[0] <= 31'b0;
        mat_b[1] <= 31'b0;
        mat_b[2] <= 31'b0;
        mat_b[3] <= 31'b0;
    end

    // Clock generation
    always #5 clk = ~clk;  // 10 ns clock period

    // Test sequence
    initial begin

        // Reset pulse
        #10 rst = 0;
        #10 rst = 1;

        // Set input matrices
        mat_a[0] = 32'ha1;
        mat_a[1] = 32'ha2;
        mat_a[2] = 32'ha3;
        mat_a[3] = 32'ha4;

        mat_b[0] = 32'hb1;
        mat_b[1] = 32'hb2;
        mat_b[2] = 32'hb3;
        mat_b[3] = 32'hb4;

        // Assert start signal
        #10 start = 1;
        #10 start = 0;  // De-assert start after one cycle

        // Wait for the done signal
        wait (done);

        // Display results
        $display("Output: %d, %d, %d, %d", out[0], out[1], out[2], out[3]);

        // Finish simulation
        #20 $finish;
    end

endmodule
