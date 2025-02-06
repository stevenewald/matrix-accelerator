`timescale 1ns / 1ps
module test();
    wire refclk;
    wire refrst;
    
    wire axi_rst;
    wire axi_clk;
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
    
    wire [1:0] group_led;

    design_2_wrapper dut(
        .axi_clk_out(axi_clk),
        .axi_rst_out(axi_rst),
        .axi_in_awaddr(axi_awaddr),
        .axi_in_awprot(axi_awprot),
        .axi_in_awvalid(axi_awvalid),
        .axi_in_awready(axi_awready),
        .axi_in_wdata(axi_wdata),
        .axi_in_wstrb(axi_wstrb),
        .axi_in_wvalid(axi_wvalid),
        .axi_in_wready(axi_wready),
        .axi_in_bresp(axi_bresp),
        .axi_in_bvalid(axi_bvalid),
        .axi_in_bready(axi_bready),
        .axi_in_araddr(axi_araddr),
        .axi_in_arprot(axi_arprot),
        .axi_in_arvalid(axi_arvalid),
        .axi_in_arready(axi_arready),
        .axi_in_rdata(axi_rdata),
        .axi_in_rresp(axi_rresp),
        .axi_in_rvalid(axi_rvalid),
        .axi_in_rready(axi_rready)
    );
    
    wire msi_req;
    
    axi_master master_2(
        .aclk(axi_clk),
        .aresetn(axi_rst),
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
        .msi_interrupt_req(msi_req),
        .msi_interrupt_ack(msi_req)
    );
  
  axi_stim stim();
  initial begin
  end

endmodule
