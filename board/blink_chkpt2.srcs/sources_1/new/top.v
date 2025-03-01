`timescale 1ns / 1ps
`include "memory_states.vh"
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

    wire reset = 1;
    wire axi_clk;
    wire axi_rst_n;
    wire msi_int_req;
    wire msi_int_ack;
     
     wire axi_start;
     wire axi_write;
     wire [31:0] axi_addr;
     wire [AXI_MAX_READ_BURST_LEN-1:0][63:0] axi_read_data;
     wire [AXI_MAX_WRITE_BURST_LEN-1:0][63:0] axi_write_data;
     wire axi_done;
     wire [7:0] num_reads;
     wire [7:0] num_writes;
    
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
        .num_reads(num_reads),
        .num_writes(num_writes),
        .done(axi_done)
    );
    
    matrix_master matrix_mst(
        .axi_clk(axi_clk),
        .axi_rst_n(axi_rst_n),
        
        .msi_interrupt_req(msi_int_req),
        .msi_interrupt_ack(msi_int_ack),
        
        .axi_start(axi_start),
        .axi_write(axi_write),
        .axi_addr(axi_addr),
        .axi_read_data(axi_read_data),
        .axi_num_reads(num_reads),
        .axi_write_data(axi_write_data),
        .axi_num_writes(num_writes),
        .axi_done(axi_done)
        );
    
    
    turn_on_led_after_bil_cycles(
    .refclk(sys_clk),
    .led(group_led[0])
    );
endmodule
