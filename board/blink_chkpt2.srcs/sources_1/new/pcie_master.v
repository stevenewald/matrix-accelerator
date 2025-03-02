`timescale 1ns / 1ps
`include "memory_states.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2025 01:58:57 PM
// Design Name: 
// Module Name: axi_master
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


module pcie_master(
    input wire sys_clk_p,
    input wire sys_clk_n,
    input wire sys_rst_n,
    output wire axi_clk,
    output wire axi_rst_n,
    
    input wire [0:0] pci_exp_rxn,
    input wire [0:0] pci_exp_rxp,
    output wire [0:0] pci_exp_txp,
    output wire [0:0] pci_exp_txn,
    output wire sys_clk,
    
    input wire msi_interrupt_req,
    output wire msi_interrupt_ack,
    output wire msi_enabled,
    
    output wire link_up,
    
    input wire start,
    input wire write,
    input wire [15:0] addr,
    input wire [AXI_MAX_WRITE_BURST_LEN-1:0][63:0] write_data,
    input wire [7:0] num_reads,
    output wire [AXI_MAX_READ_BURST_LEN-1:0][63:0] read_data,
    input wire [7:0] num_writes,
    output wire done 
    );
    
    refclk clk(
    .sys_clk_p(sys_clk_p),
    .sys_clk_n(sys_clk_n),
    .refclk(sys_clk)
    );
    
    wire read_done;
    wire write_done;
    assign done = read_done || write_done;
    
    wire [15:0] axi_araddr;
    wire [2:0] axi_arprot;
    wire axi_arvalid;
    wire axi_arready;
    wire [15:0] axi_awaddr;
    wire [2:0] axi_awprot;
    wire axi_awready;
    wire axi_awvalid;
    wire axi_bready;
    wire [1:0] axi_bresp;
    wire axi_bvalid;
    wire [63:0] axi_rdata;
    wire axi_rready;
    wire [1:0] axi_rresp;
    wire axi_rvalid;
    wire [63:0] axi_wdata;
    wire axi_wready;
    wire [7:0] axi_wstrb;
    wire axi_wvalid;
    
    assign axi_arprot = 3'b0;
    assign axi_awprot = 3'b0;
    
    // AXI4-Full
    wire [7:0] axi_arlen;
    wire [2:0] axi_arsize;
    wire axi_rlast;
    
    wire [7:0] axi_awlen;
    wire [7:0] axi_awsize;
    wire axi_wlast;
    
    design_1_wrapper des(
    .aresetn(axi_rst_n),
    .axi_clk(axi_clk),
    
    // AXI4-Lite
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
    
    // AXI4-Full
    // Unused
    .axi_in_arburst(1),
    .axi_in_awburst(1),
    .axi_in_arcache(0),
    .axi_in_awcache(0),
    .axi_in_arlock(0),
    .axi_in_awlock(0),
    .axi_in_arlen(axi_arlen),
    .axi_in_awlen(axi_awlen),
    .axi_in_arsize(axi_arsize),
    .axi_in_awsize(axi_awsize),
    .axi_in_arqos(0),
    .axi_in_awqos(0),
    .axi_in_rlast(axi_rlast),
    .axi_in_wlast(axi_wlast),
    
    
    .refclk(sys_clk),
    .sys_reset(sys_rst_n),
    .pcie_7x_mgt_0_rxn(pci_exp_rxn),
    .pcie_7x_mgt_0_rxp(pci_exp_rxp),
    .pcie_7x_mgt_0_txn(pci_exp_txn),
    .pcie_7x_mgt_0_txp(pci_exp_txp),
    .link_up(link_up),
    .msi_interrupt_req(msi_interrupt_req),
    .msi_interrupt_ack(msi_interrupt_ack),
    .msi_enabled(msi_enabled)
    );
    
    axi_read_fse read_fse (
        .clk(axi_clk),
        .resetn(axi_rst_n),
        
        .start(start && !write),
        .addr(addr),
        .read_data(read_data),
        .num_reads(num_reads),
        .read_done(read_done),
    
        // Read Address Channel
        .m_axi_araddr(axi_araddr),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),
        .m_axi_arlen(axi_arlen),
        .m_axi_arsize(axi_arsize),
    
        // Read Data Channel
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready),
        .m_axi_rlast(axi_rlast)
        
    );
    
     axi_write_fse write_fse (
        .clk(axi_clk),
        .resetn(axi_rst_n),
        
        .start(start && write),
        .addr(addr),
        .write_data(write_data),
        .num_writes(num_writes),
        .write_done(write_done),
    
        // Write Address Channel
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awready(axi_awready),
        .m_axi_awlen(axi_awlen),
        .m_axi_awsize(axi_awsize),
    
        // Write Data Channel
        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wready(axi_wready),
        .m_axi_wlast(axi_wlast),
    
        // Write Response Channel
        .m_axi_bresp(axi_bresp),
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bready(axi_bready)        
    );
endmodule
