`timescale 1ns / 1ps

module sim_1();

    // Clock and Reset
    reg clk;
    reg reset;
    
    // Inputs
    reg start;
    reg [31:0] a00, a01, a10, a11;
    reg [31:0] b00, b01, b10, b11;
    
    // Outputs
    wire [31:0] c00, c01, c10, c11;
    wire done;
    
    // Instantiate DUT
    matrix_multiplier dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .a00(a00),
        .a01(a01),
        .a10(a10),
        .a11(a11),
        .b00(b00),
        .b01(b01),
        .b10(b10),
        .b11(b11),
        .c00(c00),
        .c01(c01),
        .c10(c10),
        .c11(c11),
        .done(done)
    );

    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period
    end

    // Main test sequence
    initial begin
        // Initialize inputs
        reset = 1;
        start = 0;
        {a00, a01, a10, a11} = 0;
        {b00, b01, b10, b11} = 0;
        
        // Reset sequence
        #20;
        reset = 0;
        #10;
        
        // Test Case 1: Identity matrix multiplication
        apply_test(
            32'h01, 32'h00, 32'h00, 32'h01,  // A = I
            32'h01, 32'h00, 32'h00, 32'h01,  // B = I
            32'h01, 32'h00, 32'h00, 32'h01   // Expected C = I
        );
        
        // Test Case 2: Simple multiplication
        apply_test(
            32'h01, 32'h02, 32'h03, 32'h04,  // A
            32'h05, 32'h06, 32'h07, 32'h08,  // B
            32'h13, 32'h16, 32'h2B, 32'h32   // C (19, 22, 43, 50 in decimal)
        );
        
        // Test Case 3: Overflow test
        apply_test(
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,  // A (all 32'hFFFFFFFF)
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,  // B (all 32'hFFFFFFFF)
            32'h00000002, 32'h00000002, 32'h00000002, 32'h00000002   // Expected C (truncated results)
        );
        
        // Test Case 4: Pipelined back-to-back operations
        $display("\nTesting pipeline throughput...");
        fork
            begin
                // First input
                @(negedge clk);
                start = 1;
                {a00, a01, a10, a11} = {32'd1, 32'd0, 32'd0, 32'd1};
                {b00, b01, b10, b11} = {32'd2, 32'd0, 32'd0, 32'd2};
                @(negedge clk);
                start = 0;
            end
            begin
                // Second input 1 cycle later
                @(negedge clk);
                @(negedge clk);
                start = 1;
                {a00, a01, a10, a11} = {32'd3, 32'd0, 32'd0, 32'd3};
                {b00, b01, b10, b11} = {32'd4, 32'd0, 32'd0, 32'd4};
                @(negedge clk);
                start = 0;
            end
        join
        
        // Check results after pipeline flush
        #100;
        $finish;
    end

    // Test application task
    task apply_test(
        input [31:0] a0, a1, a2, a3,
        input [31:0] b0, b1, b2, b3,
        input [31:0] c0, c1, c2, c3
    );
    begin
        $display("\nApplying test:");
        $display("A = [[%h, %h], [%h, %h]]", a0, a1, a2, a3);
        $display("B = [[%h, %h], [%h, %h]]", b0, b1, b2, b3);
        
        // Apply inputs
        @(negedge clk);
        start = 1;
        {a00, a01, a10, a11} = {a0, a1, a2, a3};
        {b00, b01, b10, b11} = {b0, b1, b2, b3};
        @(negedge clk);
        start = 0;
        
        // Wait for completion
        wait(done);
        @(negedge clk);  // Capture stable output
        
        // Verify outputs
        if (c00 !== c0 || c01 !== c1 || c10 !== c2 || c11 !== c3) begin
            $display("ERROR: Result mismatch!");
            $display("Expected: [[%h, %h], [%h, %h]]", c0, c1, c2, c3);
            $display("Received: [[%h, %h], [%h, %h]]", c00, c01, c10, c11);
        end
        else begin
            $display("PASSED: Results match!");
        end
        
        #20;  // Inter-test spacing
    end
    endtask

endmodule