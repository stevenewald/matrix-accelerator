`include "memory_states.vh"
module axi_read_fse
(
    input                         clk,
    input                         resetn,  
    input                         start,     
    output wire ready,
    input      [31:0]   addr, 
    input wire [BITS_PER_READ_ID-1:0] assigned_read_id,

    output reg [MAX_OUTSTANDING_READS-1:0][AXI_MAX_READ_BURST_LEN-1:0][31:0]   read_data, 
    input wire [7:0]     num_reads,
    output reg [MAX_OUTSTANDING_READS-1:0] read_done,



    // AXI-Lite Read Address Channel
    output reg [31:0]   m_axi_araddr,
    output reg                  m_axi_arvalid,
    input                       m_axi_arready,
    output reg [7:0]            m_axi_arlen,
    output reg [2:0]            m_axi_arsize,
    output reg [BITS_PER_READ_ID-1:0] m_axi_arid,

    // AXI-Lite Read Data Channel
    input      [31:0]   m_axi_rdata,
    input       [1:0]           m_axi_rresp,
    input                       m_axi_rvalid,
    output reg                  m_axi_rready,
    input wire                  m_axi_rlast,
    input wire [BITS_PER_READ_ID-1:0] m_axi_rid
);

assign ready = m_axi_arready;

reg [MAX_OUTSTANDING_READS-1:0][$clog2(AXI_MAX_READ_BURST_LEN+1)-1:0] arg_num;
reg [MAX_OUTSTANDING_READS-1:0] truncated_burst;
reg [MAX_OUTSTANDING_READS-1:0] trunc_ready;
reg [MAX_OUTSTANDING_READS-1:0] addrs;


//---------------------------------------------------------------------
// Output Logic
//---------------------------------------------------------------------

always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
        read_done <= 0;
        read_data <= 0;
        m_axi_rready <= 0;
        arg_num <= 0;
        m_axi_araddr  <= 0;
        m_axi_arvalid <= 0'b0;
        m_axi_arlen <= 8'b0;
        m_axi_arsize <= 3'b0;
        m_axi_arid <= 0;
        truncated_burst <= 0;
        trunc_ready <= 0;
        addrs <= 0;
    end else begin
        read_done <= 0;
        if(m_axi_rvalid && m_axi_rready) begin
            arg_num[m_axi_rid] <= arg_num[m_axi_rid] + 1;
            read_data[m_axi_rid][arg_num[m_axi_rid]] <= m_axi_rdata;
            if(m_axi_rlast && arg_num[m_axi_rid]==num_reads-1) begin
                read_done[m_axi_rid] <= 1;
                arg_num[m_axi_rid] <= 0;
            end else if(m_axi_rlast && truncated_burst[m_axi_rid]) begin
                trunc_ready[m_axi_rid] <= 1;
            end
        end else begin
            m_axi_rready <= 1'b1;
        end
        
        m_axi_arvalid <= 0;
        if(m_axi_arready && start) begin
            read_data[assigned_read_id] <= 0;
            m_axi_araddr <= addr;
            addrs[assigned_read_id] <= addr;
            m_axi_arvalid <= 1;
            m_axi_arlen <= ((addr&32'h1000) != ((addr+4*num_reads)&32'h1000)) ? 0 : num_reads-1;
            m_axi_arsize <= 2;
            m_axi_arid <= assigned_read_id;
            truncated_burst[assigned_read_id] <= (addr&32'h1000) != ((addr+4*num_reads)&32'h1000);
        end else if(m_axi_arready) begin
            for(int i = 0; i < MAX_OUTSTANDING_READS; ++i) begin
                if(trunc_ready[i]) begin
                    m_axi_araddr <= addrs[i] + 4*arg_num[i];
                    m_axi_arvalid <= 1;
                    m_axi_arlen <= 0;
                    m_axi_arsize <= 2;
                    m_axi_arid <= i;
                    trunc_ready[i] <= 0;
                    break;
                end
            end
        end
    end
end

endmodule
