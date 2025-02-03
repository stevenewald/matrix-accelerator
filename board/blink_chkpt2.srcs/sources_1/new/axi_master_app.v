module axi_master_app (
    input                         clk,
    input                         resetn,      // Active low reset
    input                         start,       // Transaction start trigger
    input                         write_en,    // 1: write, 0: read
    input                [31:0]   addr,        // Transaction address
    input      [31:0]   write_data,  // Data for write transaction
    output reg [31:0]   read_data,   // Data received from read transaction
    output reg                  done,         // Transaction completion flag

    // AXI-Lite Write Address Channel
    output reg [31:0]   m_axi_awaddr,
    output reg                  m_axi_awvalid,
    input                       m_axi_awready,

    // AXI-Lite Write Data Channel
    output reg [31:0]   m_axi_wdata,
    output reg [3:0] m_axi_wstrb,
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

reg [3:0] state, next_state;

//---------------------------------------------------------------------
// State Register Update
//---------------------------------------------------------------------
/*always @(posedge clk or negedge resetn) begin
    if (!resetn)
        state <= STATE_IDLE;
    else
        state <= next_state;
end*/

//---------------------------------------------------------------------
// Next State Logic
//---------------------------------------------------------------------
always @(*) begin
    next_state = state;
    case (state)
        STATE_IDLE: begin
            if (start) begin
                if (write_en)
                    next_state = STATE_WRITE_ADDR;
                else
                    next_state = STATE_READ_ADDR;
            end
        end
        STATE_WRITE_ADDR: begin
            if (m_axi_awready && m_axi_awvalid)
                next_state = STATE_WRITE_DATA;
        end
        STATE_WRITE_DATA: begin
            if (m_axi_wready && m_axi_wvalid)
                next_state = STATE_WRITE_RESP;
        end
        STATE_WRITE_RESP: begin
            if (m_axi_bvalid && m_axi_bready)
                next_state = STATE_DONE;
        end
        STATE_READ_ADDR: begin
            if (m_axi_arready && m_axi_arvalid)
                next_state = STATE_READ_DATA;
        end
        STATE_READ_DATA: begin
            if (m_axi_rvalid && m_axi_rready)
                next_state = STATE_DONE;
        end
        STATE_DONE: begin
            // Wait for 'start' to be deasserted before returning to idle.
            if (!start)
                next_state = STATE_IDLE;
        end
        default: next_state = STATE_IDLE;
    endcase
end

//---------------------------------------------------------------------
// Output Logic
//---------------------------------------------------------------------
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        m_axi_awaddr  <= {ADDR_WIDTH{1'b0}};
        m_axi_awvalid <= 1'b0;
        m_axi_wdata   <= {DATA_WIDTH{1'b0}};
        m_axi_wstrb   <= {(DATA_WIDTH/8){1'b0}};
        m_axi_wvalid  <= 1'b0;
        m_axi_bready  <= 1'b0;
        m_axi_araddr  <= {ADDR_WIDTH{1'b0}};
        m_axi_arvalid <= 1'b0;
        m_axi_rready  <= 1'b0;
        read_data     <= {DATA_WIDTH{1'b0}};
        done          <= 1'b0;
        state         <= STATE_IDLE;
    end else begin
        state = next_state;
        // Default: deassert signals that are only active in specific states.
        m_axi_awvalid <= 1'b0;
        m_axi_wvalid  <= 1'b0;
        m_axi_bready  <= 1'b0;
        m_axi_arvalid <= 1'b0;
        m_axi_rready  <= 1'b0;
        done          <= 1'b0;
        
        case (state)
            STATE_IDLE: begin
                // All AXI signals remain deasserted.
            end
            
            // Write Transaction Sequence
            STATE_WRITE_ADDR: begin
                m_axi_awaddr  <= addr;
                m_axi_awvalid <= 1'b1;
            end
            
            STATE_WRITE_DATA: begin
                m_axi_wdata  <= write_data;
                m_axi_wstrb  <= {(DATA_WIDTH/8){1'b1}};  // Full word write
                m_axi_wvalid <= 1'b1;
            end
            
            STATE_WRITE_RESP: begin
                m_axi_bready <= 1'b1;
            end
            
            // Read Transaction Sequence
            STATE_READ_ADDR: begin
                m_axi_araddr  <= addr;
                m_axi_arvalid <= 1'b1;
            end
            
            STATE_READ_DATA: begin
                m_axi_rready <= 1'b1;
                if (m_axi_rvalid)
                    read_data <= m_axi_rdata;
            end
            
            STATE_DONE: begin
                done <= 1'b1;
            end
            
            default: ; // No action needed
        endcase
    end
end

endmodule
