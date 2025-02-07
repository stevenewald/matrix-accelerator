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
    input wire [3:0][31:0] mat_a,
    input wire [3:0][31:0] mat_b,
    output wire [3:0][31:0] out,
    input wire start,
    output reg done
    );
    
    reg running;
    
    reg [2:0] cycle_count;
    reg [31:0] a_in [1:0];
    reg [31:0] b_in [1:0];
    
    wire [31:0] a_out [1:0];
    wire [31:0] b_out [1:0];
    
    always @(posedge clk) begin
        if(!rst) begin
            cycle_count <= 0;
            running <= 0;
            a_in[0] <= 32'b0;
            a_in[1] <= 32'b0;
            b_in[0] <= 32'b0;
            b_in[1] <= 32'b0;
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
            
            cycle_count <= 1;
        end else if(cycle_count == 1) begin
            a_in[0] <= mat_a[1];
            b_in[0] <= mat_b[2];
            
            a_in[1] <= mat_a[2];
            b_in[1] <= mat_b[1];
            
            cycle_count <= 2;
        end else if(cycle_count == 2) begin
            a_in[0] <= 0;
            b_in[0] <= 0;
            
            a_in[1] <= mat_a[3];
            b_in[1] <= mat_b[3];
            
            cycle_count <= 3;
        end else if (cycle_count == 3) begin
            
            a_in[1] <= 32'b0;
            b_in[1] <= 32'b0;
            cycle_count <= 4;
        end else begin
            done <= 1;
            running <= 0;
        end
    end
    
    // 10
    // 00
    systolic_PE pe1(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[0]),
        .b_in(b_in[0]),
        .a_out(a_out[0]),
        .b_out(b_out[0]),
        .valid(running),
        .result(out[0]));
        
    // 01
    // 00
    systolic_PE pe2(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[0]),
        .b_in(b_in[1]),
        .b_out(b_out[1]),
        .valid(running),
        .result(out[1]));
        
    // 00
    // 10
    systolic_PE pe3(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[1]),
        .b_in(b_out[0]),
        .a_out(a_out[1]),
        .valid(running),
        .result(out[2]));
        
    // 00
    // 01
    systolic_PE pe4(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[1]),
        .b_in(b_out[1]),
        .valid(running),
        .result(out[3]));
        
endmodule
