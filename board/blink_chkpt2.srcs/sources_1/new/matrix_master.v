`timescale 1ns / 1ps
`include "memory_states.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/13/2025 01:02:50 PM
// Design Name: 
// Module Name: matrix_master
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


module matrix_master(
    input wire axi_clk,
    input wire axi_rst_n,
    
    output wire msi_interrupt_req,
    input wire msi_interrupt_ack,

    output wire axi_start,
    output wire axi_write,
    output wire [31:0] axi_addr,
    input wire [AXI_MAX_READ_BURST_LEN-1:0][31:0] axi_read_data,
    output wire [7:0] axi_num_reads,
    output wire [AXI_MAX_WRITE_BURST_LEN-1:0][31:0] axi_write_data,
    output wire [7:0] axi_num_writes,
    input wire axi_done
    );
    
    wire matrix_done;
    wire [2:0] matrix_command;
    wire [TILE_NUM_ELEMENTS-1:0][31:0] matrix_write_data;
    wire [TILE_NUM_ELEMENTS-1:0][15:0] matrix_read_data;
    wire [31:0] status_read_data;
    
    wire [MATRIX_NUM_NBITS-1:0] matrix_num;
    
    matrix_memory_handle matrix_handle (
    .axi_start(axi_start),
    .axi_write(axi_write),
    .axi_addr(axi_addr),
    .axi_write_data(axi_write_data),
    .axi_num_writes(axi_num_writes),
    .axi_read_data(axi_read_data),
    .axi_num_reads(axi_num_reads),
    .axi_done(axi_done),
    .msi_interrupt_req(msi_interrupt_req),
    .msi_interrupt_ack(msi_interrupt_ack),
    .matrix_num(matrix_num),
    .clk(axi_clk),
    .rstn(axi_rst_n),
    .matrix_done(matrix_done),
    .command(matrix_command),
    .status_read_data(status_read_data),
    .matrix_write_data(matrix_write_data),
    .matrix_read_data(matrix_read_data));
    
    matrix_multiplier #(
        .SYS_DIM(SYS_DIM)) multiplier (
        .aclk(axi_clk),
        .aresetn(axi_rst_n),
        .matrix_command(matrix_command),
        .matrix_num(matrix_num),
        .status_read_data(status_read_data),
        .matrix_read_data(matrix_read_data),
        .matrix_write_data(matrix_write_data),
        .matrix_done(matrix_done)
        );
endmodule
