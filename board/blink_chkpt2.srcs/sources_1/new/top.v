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
    
    
    wire reset = 1;
    wire sys_clk;
    wire axi_clk;
    wire axi_rst_n;
    wire msi_int_req;
    wire msi_int_ack;
     //link up group led 1
     
     wire start;
     wire write;
     wire [31:0] addr;
     wire [31:0] read_data;
     wire [31:0] write_data;
     wire done;
    
    pcie_master pcie(
        .sys_clk_p(sys_clk_p),
        .sys_clk_n(sys_clk_n),
        .sys_rst_n(reset),
        .sys_clk(sys_clk),
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
        
        .start(start),
        .write(write),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .done(done)
    );
    
    matrix_multiplier multiplier(
        .aclk(axi_clk),
        .aresetn(axi_rst_n),
        .msi_interrupt_req(msi_int_req),
        .msi_interrupt_ack(msi_int_ack),
        .start(start),
        .write(write),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .done(done)
        );
        
    
    turn_on_led_after_bil_cycles(
    .refclk(sys_clk),
    .led(group_led[0])
    );
endmodule
