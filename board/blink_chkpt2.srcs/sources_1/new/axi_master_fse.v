module axi_master_fse
(
    input                         clk,
    input                         resetn,      // Active low reset
    input                         start,       // Transaction start trigger
    input                         write_en,    // 1: write, 0: read
    input      [31:0]   addr,        // Transaction address
    input      [31:0]   write_data,  // Data for write transaction
    output reg [31:0]   read_data,   // Data received from read transaction
    output reg                  done,         // Transaction completion flag

    // AXI-Lite Write Address Channel
    output reg [31:0]   m_axi_awaddr,
    output reg                  m_axi_awvalid,
    input                       m_axi_awready,

    // AXI-Lite Write Data Channel
    output reg [31:0]   m_axi_wdata,
    output reg [4:0] m_axi_wstrb,
    output reg                  m_axi_wvalid,
    input                       m_axi_wready,

    // AXI-Lite Write Response Channel
    input       [1:0]           m_axi_bresp,
    input                       m_axi_bvalid,
    output reg                  m_axi_bready,

    // AXI-Lite Read Address Channel
    output reg [31:0]   m_axi_araddr,
    output reg                  m_axi_arvalid,
    input                       m_axi_arready,

    // AXI-Lite Read Data Channel
    input      [31:0]   m_axi_rdata,
    input       [1:0]           m_axi_rresp,
    input                       m_axi_rvalid,
    output reg                  m_axi_rready
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
        read_data     <= {32{1'b0}};
        done          <= 1'b0;
        state         <= STATE_IDLE;
    end else begin


        case (state)
            STATE_IDLE: begin
                // !done to ensure buffer
                if (!done && start) begin
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
                    m_axi_awaddr  <= addr;
                    m_axi_awvalid <= 1'b1;
                end
            end
            
            STATE_WRITE_DATA: begin
                if(m_axi_wvalid && m_axi_wready) begin
                    m_axi_wvalid <= 0;
                    state <= STATE_WRITE_RESP;
                end else begin
                    m_axi_wdata  <= write_data;
                    m_axi_wstrb  <= {4'hF};  // Full word write
                    m_axi_wvalid <= 1'b1; 
                end
            end
            
            STATE_WRITE_RESP: begin
                if(m_axi_bready && m_axi_bvalid) begin
                    m_axi_bready <= 0;
                    state <= STATE_DONE;
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
                    m_axi_araddr  <= addr;
                    m_axi_arvalid <= 1'b1;
                end
            end
            
            STATE_READ_DATA: begin
                if(m_axi_rvalid && m_axi_rready) begin
                    read_data <= m_axi_rdata;
                    m_axi_rready <= 0;
                    state <= STATE_DONE;
                end else begin
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
