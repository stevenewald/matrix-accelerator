`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/02/2025 11:39:41 AM
// Design Name: 
// Module Name: master
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


module axi_master(
        //output wire  error,
		//output wire  txn_done,
		input wire  aclk,
		input wire  aresetn,
		
		// WRITE ADDR
		output wire [31:0] awaddr,
		output wire [2:0] awprot,
		output wire  awvalid,
		input wire  awready,
		
		// WRITE DATA
		output wire [31:0] wdata,
		output wire [3:0] wstrb,
		output wire  wvalid,
		input wire  wready,
		
		// WRITE RESP
		input wire [1:0] bresp,
		input wire  bvalid,
		output wire  bready,
		
		// READ ADDR
		output wire [31:0] araddr,
		output wire [2:0] arprot,
		output wire  arvalid,
		input wire  arready,
		
		// READ DATA
		input wire [31:0] rdata,
		input wire [1:0] rresp,
		input wire  rvalid,
		output wire  rready
    );
    // Read/Write FSE
    wire start;
	wire write;
	wire [31:0] addr;
	wire [31:0] write_data;
	wire [31:0] read_data;
	wire done;
	
	assign arprot = 3'b0;
	assign awprot = 3'b0;
	
	axi_master_fse fse (
        .clk(aclk),
        .resetn(aresetn),
        
        .start(start),
        .write_en(write),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .done(done),
    
        // Write Address Channel
        .m_axi_awaddr(awaddr),
        .m_axi_awvalid(awvalid),
        .m_axi_awready(awready),
    
        // Write Data Channel
        .m_axi_wdata(wdata),
        .m_axi_wstrb(wstrb),
        .m_axi_wvalid(wvalid),
        .m_axi_wready(wready),
    
        // Write Response Channel
        .m_axi_bresp(bresp),
        .m_axi_bvalid(bvalid),
        .m_axi_bready(bready),
    
        // Read Address Channel
        .m_axi_araddr(araddr),
        .m_axi_arvalid(arvalid),
        .m_axi_arready(arready),
    
        // Read Data Channel
        .m_axi_rdata(rdata),
        .m_axi_rresp(rresp),
        .m_axi_rvalid(rvalid),
        .m_axi_rready(rready)
    );
    
    
    
    
    localparam S_IDLE          = 3'd0,
           S_CHECK_0x10    = 3'd1,
           S_DECIDE        = 3'd2,
           S_READ_0x0      = 3'd3,
           S_READ_0x4      = 3'd4,
           S_WRITE_0xC     = 3'd5,
           S_WRITE_0x10    = 3'd6;

reg [2:0] current_state;

// Registers to store read values and product
reg [31:0] reg_A, reg_B, product;

// Control signals for the AXI-Lite master
reg r_start;
reg r_write_en;
reg [31:0] r_addr;
reg [31:0] r_write_data;

assign start      = r_start;
assign write   = r_write_en;
assign addr       = r_addr;
assign write_data = r_write_data;



////////////////////////////////////////////////////////////////////////////////
// Output and Data Handling
////////////////////////////////////////////////////////////////////////////////
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        r_start      <= 1'b0;
        r_write_en   <= 1'b0;
        r_addr       <= {32{1'b0}};
        r_write_data <= {32{1'b0}};
        reg_A        <= {32{1'b0}};
        reg_B        <= {32{1'b0}};
        product      <= {32{1'b0}};
        current_state <= S_IDLE;
    end else begin
        // Defaults for each cycle
        r_start      <= 1'b0;
        r_write_en   <= 1'b0;

        case (current_state)
            S_IDLE: begin
                current_state <= S_CHECK_0x10;
            end

            // Initiate read of 0x10
            S_CHECK_0x10: begin
                if(done) begin
                    r_start <= 1'b0;
                    current_state <= S_DECIDE;
                end else begin
                    r_start      <= 1'b1;
                    r_write_en   <= 1'b0;      // Read
                    r_addr       <= 32'h10;
                end
            end

            // Evaluate data from 0x10
            S_DECIDE: begin
                current_state <= (read_data == 32'd1) ? S_READ_0x0 : S_CHECK_0x10;
            end

            // Read from 0x0 -> reg_A
            S_READ_0x0: begin
                if (done) begin
                    reg_A <= read_data;
                    r_start <= 1'b0;
                    current_state <= S_READ_0x4;
                end else begin
                    r_start <= 1'b1;
                    r_write_en <= 1'b0;
                    r_addr <= 32'h0;
                end
            end

            // Read from 0x4 -> reg_B
            S_READ_0x4: begin
                if(done) begin
                    reg_B <= read_data;
                    r_start <= 1'b0;
                    current_state <= S_WRITE_0xC;
                end else begin
                    r_start      <= 1'b1;
                    r_write_en   <= 1'b0;
                    r_addr       <= 32'h4;
                end
            end

            // Write A*B to 0xc
            S_WRITE_0xC: begin
                if(done) begin
                    r_start <= 1'b0;
                    current_state <= S_WRITE_0x10;
                end else begin
                    r_start      <= 1'b1;
                    r_write_en   <= 1'b1;
                    r_addr       <= 32'hc;
                    r_write_data <= reg_A * reg_B;
                end
            end

            // Write 0 to 0x10
            S_WRITE_0x10: begin
                if(done) begin
                    r_start <= 1'b0;
                    current_state <= S_IDLE;
                end else begin
                    r_start <= 1'b1;
                    r_write_en <= 1'b1;
                    r_addr <= 32'h10;
                    r_write_data <= 32'h0;
                end
            end
            default: current_state <= S_IDLE;
        endcase
    end
end 
endmodule
