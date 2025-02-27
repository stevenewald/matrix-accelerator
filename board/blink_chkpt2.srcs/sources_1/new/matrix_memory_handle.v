`timescale 1ns / 1ps
`include "memory_states.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2025 04:25:02 PM
// Design Name: 
// Module Name: matrix_memory_handle
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


module matrix_memory_handle #(
    parameter STATUS_ADDR = 32'h0
    ) (
    output reg axi_start,
    output reg axi_write,
    output reg [31:0] axi_addr,
    output reg [AXI_MAX_BURST_LEN-1:0][31:0] axi_write_data,
    output reg [7:0] axi_num_writes,
    input wire [AXI_MAX_BURST_LEN-1:0][31:0] axi_read_data,
    output reg [7:0] axi_num_reads,
    input wire axi_done,
    
    output reg msi_interrupt_req,
    input wire msi_interrupt_ack,
    
    input wire clk,
    input wire rstn,
    
    input wire [MATRIX_NUM_NBITS-1:0] matrix_num,
    input wire [TILE_NUM_ELEMENTS-1:0][31:0] matrix_write_data,
    output reg [TILE_NUM_ELEMENTS-1:0][15:0] matrix_read_data,
    output reg [31:0] status_read_data,
    input wire [2:0] command,
    output reg matrix_done
    );
    
    reg [2:0] state;
    
    // /2 because packed matrices
    wire [31:0] matrix_offset = 2*TILE_NUM_ELEMENTS*matrix_num + 4; //+1 for status_addr
    
    reg matrix_valid;
    wire [AXI_MAX_BURST_LEN-1:0][31:0] buffer;
    wire [31:0] addr_begin;
    wire buffer_full;
    reg clear_buffer;
    wire [$clog2(WB_STORAGE_CAPACITY+1)-1:0] buffer_size;
    
    matrix_write_buffer write_buf(
        .aresetn(rstn),
        .aclk(clk),
        .matrix_data(matrix_write_data),
        .addr(matrix_offset),
        .clear_buffer(clear_buffer),
        .matrix_valid(matrix_valid),
        .size(buffer_size),
        .buffer(buffer),
        .addr_begin(addr_begin),
        .buffer_full(buffer_full));
    
   
    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            msi_interrupt_req <= 0;
            axi_start <= 0;
            axi_write <= 0;
            axi_addr <= 0;
            matrix_read_data <= 0;
            axi_num_reads <= 0;
            matrix_done <= 0;
            state <= MHS_IDLE;
            status_read_data <= 0;
            axi_num_writes <= 0;
            axi_write_data <= 0;
            matrix_valid <= 0;
            clear_buffer <= 0;
        end else begin
            matrix_valid <= 0;
            clear_buffer <= 0;
            case (state)
                MHS_IDLE: begin
                    if(matrix_done) begin
                        // Give time for higher level module to process done signal
                        // Can maybe remove?
                        matrix_done <= 0;
                    end else begin
                        state <= command;
                    end
                end
                MHS_READ_STATUS: begin
                    if(axi_done) begin
                        status_read_data <= axi_read_data[0];
                        matrix_done <= 1;
                        axi_start <= 0;
                        state <= MHS_IDLE;
                    end else begin
                        axi_addr <= STATUS_ADDR;
                        axi_num_reads <= 1;
                        axi_write <= 0;
                        axi_start <= 1;
                    end
                end
                MHS_READ_MATRIX: begin
                    if(axi_done) begin
                        for(int i = 0; i < TILE_NUM_ELEMENTS/2; ++i) begin
                            matrix_read_data[2*i] <= axi_read_data[i][15:0];
                            matrix_read_data[2*i+1] <= axi_read_data[i][31:16];
                        end
                        state <= MHS_IDLE;
                        matrix_done <= 1;
                        axi_start <= 0;
                    end else begin
                        axi_num_reads <= TILE_NUM_ELEMENTS/2;
                        axi_start <= 1;
                        axi_addr <= matrix_offset;
                        axi_write <= 0;
                    end
                end
                MHS_WRITE_RESULT: begin
                    if(axi_done) begin
                        state <= MHS_IDLE;
                        matrix_done <= 1;
                        axi_write <= 0;
                        axi_start <= 0;
                    end else if(!axi_start) begin
                        matrix_valid <= 1;
                        if(buffer_full) begin
                            axi_write_data <= buffer;
                            axi_num_writes <= AXI_MAX_BURST_LEN;
                            axi_start <= 1;
                            axi_write <= 1;
                            axi_addr <= addr_begin;
                        end else begin
                            state <= MHS_IDLE;
                            matrix_done <= 1;
                        end
                    end
                end
                MHS_FLUSH: begin
                    if(axi_done) begin
                        state <= MHS_IDLE;
                        matrix_done <= 1;
                        axi_write <= 0;
                        axi_start <= 0;
                    end else if(!axi_start) begin
                        axi_write_data <= buffer;
                        axi_num_writes <= buffer_size * TILE_NUM_ELEMENTS;
                        clear_buffer <= 1;
                        axi_start <= 1;
                        axi_write <= 1;
                        axi_addr <= addr_begin;
                    end
                end
                MHS_INTERRUPT: begin
                    if(msi_interrupt_req && msi_interrupt_ack) begin
                        msi_interrupt_req <= 1'b0;
                        matrix_done <= 1;
                        state <= MHS_IDLE;
                    end else begin
                        msi_interrupt_req <= 1'b1;
                    end
                end
                MHS_RESET_STATUS: begin
                    if(axi_done) begin
                        axi_start <= 0;
                        state <= MHS_IDLE;
                        matrix_done <= 1;
                        axi_write <= 0;
                    end else begin
                        axi_addr <= STATUS_ADDR;
                        axi_num_writes <= 1;
                        axi_write_data[0] <= 0;
                        axi_write <= 1;
                        axi_start <= 1;
                    end
                end
            endcase
        end
    end
endmodule
