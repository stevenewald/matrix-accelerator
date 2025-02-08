`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/06/2025 06:11:28 PM
// Design Name: 
// Module Name: systolic_array
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module systolic_array(
    input wire clk,
    input wire rst,
    input wire [8:0][31:0] mat_a,
    input wire [8:0][31:0] mat_b,
    output wire [8:0][31:0] out,
    input wire start,
    output reg done
    );
    
    reg running;
    
    reg [2:0] cycle_count;
    reg [31:0] a_in [2:0];
    reg [31:0] b_in [2:0];
    
    wire [31:0] a_out [8:0];
    wire [31:0] b_out [8:0];
    
    always @(posedge clk) begin
        if(!rst) begin
            cycle_count <= 0;
            running <= 0;
            a_in[0] <= 32'b0;
            a_in[1] <= 32'b0;
            a_in[2] <= 32'b0;
            b_in[0] <= 32'b0;
            b_in[1] <= 32'b0;
            b_in[2] <= 32'b0;
            done <= 0;
        end else if(done) begin
            done <= 0;
        end else if(!running && !start) begin
        end else if(!running && start) begin
            running <= 1;
            cycle_count <= 0;
            a_in[0] <= mat_a[0];
            b_in[0] <= mat_b[0];
            
            a_in[1] <= 0;
            b_in[1] <= 0;
            
            a_in[2] <= 0;
            a_in[2] <= 0;
            
            cycle_count <= 1;
        end else if(cycle_count == 1) begin
            a_in[0] <= mat_a[1];
            b_in[0] <= mat_b[3];
            
            a_in[1] <= mat_a[3];
            b_in[1] <= mat_b[1];
            
            a_in[2] <= 0;
            b_in[2] <= 0;
            
            cycle_count <= 2;
        end else if(cycle_count == 2) begin
            a_in[0] <= mat_a[2];
            b_in[0] <= mat_b[6];
            
            a_in[1] <= mat_a[4];
            b_in[1] <= mat_b[4];
            
            a_in[2] <= mat_a[6];
            b_in[2] <= mat_b[2];
            
            cycle_count <= 3;
        end else if (cycle_count == 3) begin
            a_in[0] <= 32'b0;
            b_in[0] <= 32'b0;
            
            a_in[1] <= mat_a[5];
            b_in[1] <= mat_b[7];
            
            a_in[2] <= mat_a[7];
            b_in[2] <= mat_b[5];
            
            cycle_count <= 4;
        end else if(cycle_count == 4) begin
            a_in[1] <= 32'b0;
            b_in[1] <= 32'b0;
            
            a_in[2] <= mat_a[8];
            b_in[2] <= mat_b[8];
            
            cycle_count <= 5;
        end else if(cycle_count == 5) begin
            a_in[2] <= 32'b0;
            b_in[2] <= 32'b0;
            cycle_count <= 6;
        end else if(cycle_count==6) begin
            cycle_count <= 7;
        end else begin
            done <= 1;
            running <= 0;
        end
    end
    
    // 100
    // 000
    // 000
    systolic_PE pe11(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[0]),
        .a_out(a_out[0]),
        .b_in(b_in[0]),
        .b_out(b_out[0]),
        .valid(running),
        .result(out[0]));
        
    // 010
    // 000
    // 000
    systolic_PE pe12(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[0]),
        .a_out(a_out[1]),
        .b_in(b_in[1]),
        .b_out(b_out[1]),
        .valid(running),
        .result(out[1]));
    
    // 001
    // 000
    // 000
    systolic_PE pe13(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[1]),
        .a_out(a_out[2]),
        .b_in(b_in[2]),
        .b_out(b_out[2]),
        .valid(running),
        .result(out[2]));
        
        
    // 000
    // 100
    // 000
    systolic_PE pe21(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[1]),
        .a_out(a_out[3]),
        .b_in(b_out[0]),
        .b_out(b_out[3]),
        .valid(running),
        .result(out[3]));
        
    // 000
    // 010
    // 000
    systolic_PE pe22(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[3]),
        .a_out(a_out[4]),
        .b_in(b_out[1]),
        .b_out(b_out[4]),
        .valid(running),
        .result(out[4]));
        
    // 000
    // 001
    // 000
    systolic_PE pe23(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[4]),
        .a_out(a_out[5]),
        .b_in(b_out[2]),
        .b_out(b_out[5]),
        .valid(running),
        .result(out[5]));
        
    // 000
    // 000
    // 100
    systolic_PE pe31(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[2]),
        .a_out(a_out[6]),
        .b_in(b_out[3]),
        .b_out(b_out[6]),
        .valid(running),
        .result(out[6]));
        
    // 000
    // 000
    // 010
    systolic_PE pe32(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[6]),
        .a_out(a_out[7]),
        .b_in(b_out[4]),
        .b_out(b_out[7]),
        .valid(running),
        .result(out[7]));
        
    // 000
    // 000
    // 001
    systolic_PE pe33(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[7]),
        .a_out(a_out[8]),
        .b_in(b_out[5]),
        .b_out(b_out[8]),
        .valid(running),
        .result(out[8]));
        
endmodule
