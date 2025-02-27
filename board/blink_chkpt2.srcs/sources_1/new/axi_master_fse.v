`include "memory_states.vh"
module axi_master_fse
(
    input                         clk,
    input                         resetn,      // Active low reset
    input                         start,       // Transaction start trigger
    input                         write_en,    // 1: write, 0: read
    input      [31:0]   addr,        // Transaction address
    input      [AXI_MAX_BURST_LEN-1:0][31:0]   write_data,  
    input wire [7:0]    num_writes,
    output reg [AXI_MAX_BURST_LEN-1:0][31:0]   read_data, 
    input wire [7:0]     num_reads,
    output reg                  done,         // Transaction completion flag

    // AXI-Lite Write Address Channel
    output reg [31:0]   m_axi_awaddr,
    output reg                  m_axi_awvalid,
    input                       m_axi_awready,
    output reg [7:0]            m_axi_awlen,
    output reg [2:0]            m_axi_awsize,

    // AXI-Lite Write Data Channel
    output reg [31:0]   m_axi_wdata,
    output reg [4:0] m_axi_wstrb,
    output reg                  m_axi_wvalid,
    input                   m_axi_wready,
    output reg                  m_axi_wlast,

    // AXI-Lite Write Response Channel
    input       [1:0]           m_axi_bresp,
    input                       m_axi_bvalid,
    output reg                  m_axi_bready,

    // AXI-Lite Read Address Channel
    output reg [31:0]   m_axi_araddr,
    output reg                  m_axi_arvalid,
    input                       m_axi_arready,
    output reg [7:0]            m_axi_arlen,
    output reg [2:0]            m_axi_arsize,

    // AXI-Lite Read Data Channel
    input      [31:0]   m_axi_rdata,
    input       [1:0]           m_axi_rresp,
    input                       m_axi_rvalid,
    output reg                  m_axi_rready,
    input wire                  m_axi_rlast
);

// State encoding
localparam STATE_IDLE       = 4'd0;
localparam STATE_WRITE_ADDR = 4'd1;
localparam STATE_WRITE_DATA = 4'd2;
localparam STATE_WRITE_RESP = 4'd3;
localparam STATE_READ_ADDR  = 4'd4;
localparam STATE_READ_DATA  = 4'd5;
localparam STATE_DONE       = 4'd6;

reg [3:0] state;
reg [$clog2(AXI_MAX_BURST_LEN+1)-1:0] arg_num;
reg truncated_wburst;
reg truncated_rburst;

//---------------------------------------------------------------------
// Output Logic
//---------------------------------------------------------------------
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        m_axi_awaddr  <= {32{1'b0}};
        m_axi_awvalid <= 1'b0;
        m_axi_wdata   <= {32{1'b0}};
        m_axi_wstrb   <= {4{1'b0}};
        m_axi_wvalid  <= 1'b0;
        m_axi_bready  <= 1'b0;
        m_axi_araddr  <= {32{1'b0}};
        m_axi_arvalid <= 1'b0;
        m_axi_rready  <= 1'b0;
        m_axi_arlen <= 8'b0;
        m_axi_arsize <= 3'b0;
        m_axi_awlen <= 8'b0;
        m_axi_awsize <= 3'b0;
        m_axi_wlast <= 0;
        for(int i = 0; i < AXI_MAX_BURST_LEN; ++i) begin
            read_data[i] = 0;
        end
        done          <= 1'b0;
        state         <= STATE_IDLE;
        arg_num <= 0;
        truncated_wburst <= 0;
        truncated_rburst <= 0;
    end else begin
        case (state)
            STATE_IDLE: begin
                // !done to ensure buffer
                if (!done && start) begin
                    truncated_wburst <= (addr&32'h1000) != ((addr+4*num_writes)&32'h1000);
                    truncated_rburst <= (addr&32'h1000) != ((addr+4*num_reads)&32'h1000);
                    arg_num <= 0;
                    if (write_en)
                        state <= STATE_WRITE_ADDR;
                    else
                        state <= STATE_READ_ADDR;
                end else begin
                    done <= 0;
                end
            end
            
            // Write Transaction Sequence
            STATE_WRITE_ADDR: begin
                if(m_axi_awvalid && m_axi_awready) begin
                    m_axi_awvalid <= 0;
                    state <= STATE_WRITE_DATA;
                end else begin
                    m_axi_awaddr  <= addr + 4*arg_num;
                    m_axi_awvalid <= 1'b1;
                    m_axi_awsize <= 2;
                    m_axi_awlen <= truncated_wburst ? 0 : num_writes-1;
                end
            end
            
            STATE_WRITE_DATA: begin
                if(m_axi_wvalid && m_axi_wready) begin
                    arg_num <= arg_num + 1;
                    if(arg_num == num_writes-1 || truncated_wburst) begin
                        m_axi_wvalid <= 0;
                        state <= STATE_WRITE_RESP;
                    end else begin
                        m_axi_wdata <= write_data[arg_num+1];
                        m_axi_wlast <= arg_num==num_writes-2;
                    end
                end else if (!m_axi_wvalid) begin
                    m_axi_wlast <= truncated_wburst || num_writes==1;
                    m_axi_wdata  <= write_data[arg_num];
                    m_axi_wstrb  <= {4'hF};  // Full word write
                    m_axi_wvalid <= 1'b1;
                end
            end
            
            STATE_WRITE_RESP: begin
                if(m_axi_bready && m_axi_bvalid) begin
                    m_axi_bready <= 0;
                    state <= (arg_num == num_writes) ? STATE_DONE : STATE_WRITE_ADDR;
                end else begin
                    m_axi_bready <= 1'b1;
                end
            end
            
            // Read Transaction Sequence
            STATE_READ_ADDR: begin
                if(m_axi_arvalid && m_axi_arready) begin
                    m_axi_arvalid <= 0;
                    state <= STATE_READ_DATA;
                end else begin
                    m_axi_araddr  <= addr + 4*arg_num;
                    m_axi_arvalid <= 1'b1;
                    m_axi_arlen <= truncated_rburst ? 0 : num_reads-1;
                    m_axi_arsize <= 2;
                end
            end
            
            STATE_READ_DATA: begin
                if(m_axi_rvalid && m_axi_rready) begin
                    arg_num <= arg_num + 1;
                    read_data[arg_num] <= m_axi_rdata;
                    if(m_axi_rlast && arg_num==num_reads-1) begin
                        m_axi_rready <= 0;
                        state <= STATE_DONE;
                    end else if(m_axi_rlast && truncated_rburst) begin
                        m_axi_rready <= 0;
                        state <= STATE_READ_ADDR;
                    end
                end else if(!m_axi_rready) begin
                    m_axi_rready <= 1'b1;
                end
            end
            
            STATE_DONE: begin
                done <= 1'b1;
                state <= STATE_IDLE;
            end
            
            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule
