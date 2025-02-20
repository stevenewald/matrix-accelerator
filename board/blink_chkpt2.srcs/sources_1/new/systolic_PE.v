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
    input [19:0] a_in,
    input [19:0] b_in,
    input valid,
    output reg [19:0] a_out,
    output reg [19:0] b_out,
    output wire [31:0] result
    );
    
    reg [31:0] inter;
    
    xbip_multadd_0 U0 (
    .A        (a_in[19:0]),
    .B        (b_in[19:0]),
    .C        (inter),
    .SUBTRACT (0),
    .P        (result)
  );
    
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            a_out <= 32'b0;
            b_out <= 32'b0;
            inter <= 32'b0;
        end else if(!valid) begin
            a_out <= 32'b0;
            b_out <= 32'b0;
            inter <= 32'b0;
        end else begin
            inter <= result;
            a_out <= a_in;
            b_out <= b_in; 
        end
    end
endmodule
