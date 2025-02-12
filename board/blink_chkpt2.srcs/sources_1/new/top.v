`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2025 01:04:17 PM
// Design Name: 
// Module Name: top
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


module top(
    input sys_clk_p,
    input sys_clk_n,
    output [1:0] group_led,
    output corner_led,
    input [0:0] pci_exp_rxn,
    input [0:0] pci_exp_rxp,
    output [0:0] pci_exp_txp,
    output [0:0] pci_exp_txn
    );
    
    localparam DIM = 3;
      
    wire reset = 1;
    wire axi_clk;
    wire axi_rst_n;
    wire msi_int_req;
    wire msi_int_ack;
     
     wire axi_start;
     wire axi_write;
     wire [31:0] axi_addr;
     wire [31:0] axi_read_data;
     wire [31:0] axi_write_data;
     wire axi_done;
    
    wire sys_clk;
    pcie_master pcie(
        .sys_clk_p(sys_clk_p),
        .sys_clk_n(sys_clk_n),
        .sys_clk(sys_clk),
        .sys_rst_n(reset),
        .axi_clk(axi_clk),
        .axi_rst_n(axi_rst_n),
        .pci_exp_rxn(pci_exp_rxn),
        .pci_exp_rxp(pci_exp_rxp),
        .pci_exp_txp(pci_exp_txp),
        .pci_exp_txn(pci_exp_txn),
        .link_up(group_led[1]),
        
        .msi_interrupt_req(msi_int_req),
        .msi_interrupt_ack(msi_int_ack),
        .msi_enabled(corner_led),
        
        .start(axi_start),
        .write(axi_write),
        .addr(axi_addr),
        .write_data(axi_write_data),
        .read_data(axi_read_data),
        .done(axi_done)
    );
    
    wire matrix_done;
    wire [2:0] matrix_command;
    wire [DIM*DIM-1:0][31:0] matrix_write_data;
    wire [DIM*DIM-1:0][31:0] matrix_read_data;
    wire [31:0] status_read_data;
    
    
    matrix_memory_handle #(
    .DIM(DIM)) matrix_handle (
    .axi_start(axi_start),
    .axi_write(axi_write),
    .axi_addr(axi_addr),
    .axi_write_data(axi_write_data),
    .axi_read_data(axi_read_data),
    .axi_done(axi_done),
    .msi_interrupt_req(msi_int_req),
    .msi_interrupt_ack(msi_int_ack),
    .clk(axi_clk),
    .rstn(axi_rst_n),
    .matrix_done(matrix_done),
    .command(matrix_command),
    .status_read_data(status_read_data),
    .matrix_write_data(matrix_write_data),
    .matrix_read_data(matrix_read_data));
    
    matrix_multiplier #(
        .DIM(DIM)) multiplier (
        .aclk(axi_clk),
        .aresetn(axi_rst_n),
        .matrix_command(matrix_command),
        .status_read_data(status_read_data),
        .matrix_read_data(matrix_read_data),
        .matrix_write_data(matrix_write_data),
        .matrix_done(matrix_done)
        );
        
    
    turn_on_led_after_bil_cycles(
    .refclk(sys_clk),
    .led(group_led[0])
    );
endmodule
