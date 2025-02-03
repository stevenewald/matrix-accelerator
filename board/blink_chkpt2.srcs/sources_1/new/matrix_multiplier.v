`timescale 1ns / 1ps
module matrix_multiplier #(
    parameter WIDTH = 32
)(
    input clk,
    input reset,
    input start,
    input [WIDTH-1:0] a00, a01, a10, a11,
    input [WIDTH-1:0] b00, b01, b10, b11,
    output reg [WIDTH-1:0] c00, c01, c10, c11,
    output reg done
);

// Pipeline control signals
reg [2:0] valid;

// Stage 0: Input registers
reg [WIDTH-1:0] a00_s0, a01_s0, a10_s0, a11_s0;
reg [WIDTH-1:0] b00_s0, b01_s0, b10_s0, b11_s0;

// Stage 1: Multiplication registers
reg [WIDTH-1:0] a00_s1, a01_s1, a10_s1, a11_s1;
reg [WIDTH-1:0] b00_s1, b01_s1, b10_s1, b11_s1;
reg [2*WIDTH-1:0] m1, m2, m3, m4, m5, m6, m7, m8;

// Stage 2: Addition registers
reg [2*WIDTH-1:0] m1_s2, m2_s2, m3_s2, m4_s2, m5_s2, m6_s2, m7_s2, m8_s2;
reg [2*WIDTH:0] s1, s2, s3, s4;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        // Clear all registers
        {valid, a00_s0, a01_s0, a10_s0, a11_s0, b00_s0, b01_s0, b10_s0, b11_s0} <= 0;
        {a00_s1, a01_s1, a10_s1, a11_s1, b00_s1, b01_s1, b10_s1, b11_s1} <= 0;
        {m1, m2, m3, m4, m5, m6, m7, m8} <= 0;
        {m1_s2, m2_s2, m3_s2, m4_s2, m5_s2, m6_s2, m7_s2, m8_s2} <= 0;
        {s1, s2, s3, s4} <= 0;
        {c00, c01, c10, c11} <= 0;
        done <= 0;
    end else begin
        // Propagate valid signal through pipeline
        valid <= {valid[1:0], start};

        // Stage 0: Capture inputs only when starting
        if (start) begin
            a00_s0 <= a00;
            a01_s0 <= a01;
            a10_s0 <= a10;
            a11_s0 <= a11;
            
            b00_s0 <= b00;
            b01_s0 <= b01;
            b10_s0 <= b10;
            b11_s0 <= b11;
        end

        // Stage 1: Perform multiplications only when valid[0]
        if (valid[0]) begin
            a00_s1 <= a00_s0;
            a01_s1 <= a01_s0;
            a10_s1 <= a10_s0;
            a11_s1 <= a11_s0;
            
            b00_s1 <= b00_s0;
            b01_s1 <= b01_s0;
            b10_s1 <= b10_s0;
            b11_s1 <= b11_s0;

            m1 <= a00_s0 * b00_s0;
            m2 <= a01_s0 * b10_s0;
            m3 <= a00_s0 * b01_s0;
            m4 <= a01_s0 * b11_s0;
            m5 <= a10_s0 * b00_s0;
            m6 <= a11_s0 * b10_s0;
            m7 <= a10_s0 * b01_s0;
            m8 <= a11_s0 * b11_s0;
        end

        // Stage 2: Perform additions only when valid[1]
        if (valid[1]) begin
            m1_s2 <= m1;
            m2_s2 <= m2;
            m3_s2 <= m3;
            m4_s2 <= m4;
            m5_s2 <= m5;
            m6_s2 <= m6;
            m7_s2 <= m7;
            m8_s2 <= m8;

            s1 <= m1 + m2;
            s2 <= m3 + m4;
            s3 <= m5 + m6;
            s4 <= m7 + m8;
        end

        // Stage 3: Assign outputs only when valid[2]
        if (valid[2]) begin
            c00 <= s1[WIDTH-1:0];
            c01 <= s2[WIDTH-1:0];
            c10 <= s3[WIDTH-1:0];
            c11 <= s4[WIDTH-1:0];
        end

        done <= valid[2];
    end
end

endmodule