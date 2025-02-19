`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/06/2025 06:08:19 PM
// Design Name: 
// Module Name: systolic_PE
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


module systolic_PE(
    input clk,
    input rst,
    input [31:0] a_in,
    input [31:0] b_in,
    input valid,
    output reg [31:0] a_out,
    output reg [31:0] b_out,
    output reg [31:0] result
    );
    
    reg [31:0] inter;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            a_out <= 32'b0;
            b_out <= 32'b0;
            result <= 32'b0;
            inter <= 32'b0;
        end else if(!valid) begin
            a_out <= 32'b0;
            b_out <= 32'b0;
            result <= 32'b0;
            inter <= 32'b0;
        end else begin
            inter <= (a_in*b_in);
            result <= result + inter;
            a_out <= a_in;
            b_out <= b_in; 
        end
    end
endmodule
