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

    wire refclk;
    
    refclk clk(
    .sys_clk_p(sys_clk_p),
    .sys_clk_n(sys_clk_n),
    .refclk(refclk)
    );
    
    
    wire reset = 1;
    
    
    wire axi_clk;
    wire [0:0] axi_rst;
    wire [31:0] axi_araddr;
    wire [2:0] axi_arprot;
    wire axi_arvalid;
    wire axi_arready;
    wire [31:0] axi_awaddr;
    wire [2:0] axi_awprot;
    wire axi_awready;
    wire axi_awvalid;
    wire axi_bready;
    wire [1:0] axi_bresp;
    wire axi_bvalid;
    wire [31:0] axi_rdata;
    wire axi_rready;
    wire [1:0] axi_rresp;
    wire axi_rvalid;
    wire [31:0] axi_wdata;
    wire axi_wready;
    wire [3:0] axi_wstrb;
    wire axi_wvalid;
    wire msi_interrupt_req;
    wire msi_interrupt_ack;

    design_1_wrapper des(
    .aresetn(axi_rst),
    .axi_clk(axi_clk),
    .axi_in_araddr(axi_araddr),
    .axi_in_arprot(axi_arprot),
    .axi_in_arready(axi_arready),
    .axi_in_arvalid(axi_arvalid),
    .axi_in_awaddr(axi_awaddr),
    .axi_in_awprot(axi_awprot),
    .axi_in_awready(axi_awready),
    .axi_in_awvalid(axi_awvalid),
    .axi_in_bready(axi_bready),
    .axi_in_bresp(axi_bresp),
    .axi_in_bvalid(axi_bvalid),
    .axi_in_rdata(axi_rdata),
    .axi_in_rready(axi_rready),
    .axi_in_rresp(axi_rresp),
    .axi_in_rvalid(axi_rvalid),
    .axi_in_wdata(axi_wdata),
    .axi_in_wready(axi_wready),
    .axi_in_wstrb(axi_wstrb),
    .axi_in_wvalid(axi_wvalid),
    .refclk(refclk),
    .sys_reset(reset),
    .pcie_7x_mgt_0_rxn(pci_exp_rxn),
    .pcie_7x_mgt_0_rxp(pci_exp_rxp),
    .pcie_7x_mgt_0_txn(pci_exp_txn),
    .pcie_7x_mgt_0_txp(pci_exp_txp),
    .link_up(group_led[1]),
    .msi_interrupt_req(msi_interrupt_req),
    .msi_interrupt_ack(msi_interrupt_ack),
    .msi_enabled(corner_led)
    );
    
    axi_master master_2(
        .aclk(axi_clk),
        .aresetn(axi_rst[0]),
        .awaddr(axi_awaddr),
        .awprot(axi_awprot),
        .awvalid(axi_awvalid),
        .awready(axi_awready),
        .wdata(axi_wdata),
        .wstrb(axi_wstrb),
        .wvalid(axi_wvalid),
        .wready(axi_wready),
        .bresp(axi_bresp),
        .bvalid(axi_bvalid),
        .bready(axi_bready),
        .araddr(axi_araddr),
        .arprot(axi_arprot),
        .arvalid(axi_arvalid),
        .arready(axi_arready),
        .rdata(axi_rdata),
        .rresp(axi_rresp),
        .rvalid(axi_rvalid),
        .rready(axi_rready),
        .msi_interrupt_req(msi_interrupt_req),
        .msi_interrupt_ack(msi_interrupt_ack)
    );
    
    turn_on_led_after_bil_cycles(
    .refclk(refclk),
    .led(group_led[0])
    );
endmodule
