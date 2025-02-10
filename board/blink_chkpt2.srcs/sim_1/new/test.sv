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
    
    assign axi_arprot = 3'b0;
    assign axi_awprot = 3'b0;

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
    
    wire start;
    wire write;
    wire [31:0] addr;
    wire [31:0] write_data;
    wire [31:0] read_data;
    wire done;
    
    axi_master_fse master_2(
        .clk(axi_clk),
        .resetn(axi_rst),
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awready(axi_awready),
        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wready(axi_wready),
        .m_axi_bresp(axi_bresp),
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bready(axi_bready),
        .m_axi_araddr(axi_araddr),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready),
        
        .start(start),
        .write_en(write),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .done(done)
    );
    
    
    
    matrix_multiplier multiplier(
        .aclk(axi_clk),
        .aresetn(axi_rst),
        .msi_interrupt_req(msi_req),
        .msi_interrupt_ack(msi_req),
        .start(start),
        .write(write),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .done(done)
        );
  
  axi_stim stim();
  initial begin
  end

endmodule
