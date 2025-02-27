`timescale 1ns / 1ps
`include "memory_states.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2025 01:44:42 PM
// Design Name: 
// Module Name: matrix_write_buffer
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
// assumes contiguous writes (true for result)
module matrix_write_buffer(
    input wire aresetn,
    input wire aclk,
    input wire [TILE_NUM_ELEMENTS-1:0][31:0] matrix_data,
    input wire [31:0] addr,
    output reg [$clog2(WB_STORAGE_CAPACITY+1)-1:0] size,
    input wire clear_buffer,
    input wire matrix_valid,
    output reg [WB_STORAGE_CAPACITY-1:0][TILE_NUM_ELEMENTS-1:0][31:0] buffer,
    output reg [31:0] addr_begin,
    output wire buffer_full
    );
    
    assign buffer_full = size==WB_STORAGE_CAPACITY;
    
    always @(posedge aclk) begin
        if(!aresetn) begin
            buffer <= 0;
            size <= 0;
            addr_begin <= 0;
        end else if(clear_buffer) begin
            buffer <= 0;
            size <= 0;
            addr_begin <= 0;
        end else if(matrix_valid) begin
            if(size==WB_STORAGE_CAPACITY) begin
                addr_begin <= addr;
                buffer[0] <= matrix_data;
                size <= 1;
            end else begin
                if(size==0) addr_begin <= addr;
                buffer[size] <= matrix_data;
                size <= size+1;
            end
        end
    end
endmodule
