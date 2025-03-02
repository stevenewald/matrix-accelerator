`timescale 1ns / 1ps
`include "memory_states.vh"
module test();
    wire refclk;
    wire refrst;
    
    wire axi_rst;
    wire axi_clk;
    wire [15:0] axi_araddr;
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
    wire [255:0] axi_rdata;
    wire axi_rready;
    wire [1:0] axi_rresp;
    wire axi_rvalid;
    wire [255:0] axi_wdata;
    wire axi_wready;
    wire [31:0] axi_wstrb;
    wire axi_wvalid;
    
    wire [1:0] group_led;
    
    wire [7:0] axi_arlen;
    wire [2:0] axi_arsize;
    wire [7:0] axi_awlen;
    wire [2:0] axi_awsize;
    wire axi_rlast;
    wire axi_wlast;
    
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
        .axi_in_arsize(axi_arsize),
        .axi_in_awsize(axi_awsize),
        .axi_in_rvalid(axi_rvalid),
        .axi_in_rready(axi_rready),
        .axi_in_arlen(axi_arlen),
        .axi_in_awlen(axi_awlen),
        .axi_in_wlast(axi_wlast),
        .axi_in_rlast(axi_rlast),
        .axi_in_arburst(1),
        .axi_in_awburst(1)
    );
    
    wire msi_req;
    
    wire start;
    wire write;
    wire [15:0] addr;
    wire [AXI_MAX_WRITE_BURST_LEN-1:0][255:0] write_data;
    wire [AXI_MAX_READ_BURST_LEN-1:0][255:0] read_data;
    wire [7:0] num_reads;
    wire [7:0] num_writes;
    
    wire read_done;
    wire write_done;
    wire done = read_done || write_done;
    
    axi_write_fse write_fse(
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
       

        .m_axi_awsize(axi_awsize),
        .m_axi_awlen(axi_awlen),
        .m_axi_wlast(axi_wlast),
        
        .start(start && write),
        .addr(addr),
        .write_data(write_data),
        .num_writes(num_writes),
        .write_done(write_done)
    );
    
    axi_read_fse read_fse(
        .clk(axi_clk),
        .resetn(axi_rst),
        .m_axi_araddr(axi_araddr),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready),
        
        .m_axi_arsize(axi_arsize),
        .m_axi_arlen(axi_arlen),
        .m_axi_rlast(axi_rlast),
        
        .start(start && !write),
        .addr(addr),
        .read_data(read_data),
        .num_reads(num_reads),
        .read_done(read_done)
    );
    
    matrix_master matrix_mst(
        .axi_clk(axi_clk),
        .axi_rst_n(axi_rst),
        
        .msi_interrupt_req(msi_req),
        .msi_interrupt_ack(msi_req),
        
        .axi_start(start),
        .axi_write(write),
        .axi_addr(addr),
        .axi_read_data(read_data),
        .axi_num_reads(num_reads),
        .axi_num_writes(num_writes),
        .axi_write_data(write_data),
        .axi_done(done)
        );
  
  axi_stim stim();
  initial begin
  end

endmodule
