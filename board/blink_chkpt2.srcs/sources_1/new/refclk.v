`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2025 01:01:53 PM
// Design Name: 
// Module Name: refclk
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


module refclk(
    input wire sys_clk_p,
    input wire sys_clk_n,
    output wire refclk
    );
    
    wire buf_sys_clk_p;
    wire buf_sys_clk_n;

    // Buffer each input
    IBUF ibuf_p_inst (
        .I(sys_clk_p),       // Input clock (positive)
        .O(buf_sys_clk_p)    // Buffered output
    );

    IBUF ibuf_n_inst (
        .I(sys_clk_n),       // Input clock (negative)
        .O(buf_sys_clk_n)    // Buffered output
    );

    // Combine the two buffered inputs into a single-ended clock
    IBUFDS_GTE2 ibufds_inst (
        .I(buf_sys_clk_p),   // Buffered positive input
        .IB(buf_sys_clk_n),  // Buffered negative input
        .O(refclk)// Single-ended clock output
    );
endmodule
