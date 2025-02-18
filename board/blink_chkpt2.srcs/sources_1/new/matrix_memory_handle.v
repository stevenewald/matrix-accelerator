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
    parameter DIM = 3, // how large is each contiguous matrix
    parameter STATUS_ADDR = 32'h0
    ) (
    output reg axi_start,
    output reg axi_write,
    output reg [31:0] axi_addr,
    output reg [SYS_DIM_ELEMENTS-1:0][31:0] axi_write_data,
    output reg [7:0] axi_num_writes,
    input wire [SYS_DIM_ELEMENTS-1:0][31:0] axi_read_data,
    output reg [7:0] axi_num_reads,
    input wire axi_done,
    
    output reg msi_interrupt_req,
    input wire msi_interrupt_ack,
    
    input wire clk,
    input wire rstn,
    
    input wire [MATRIX_NUM_NBITS-1:0] matrix_num,
    input wire [DIM*DIM-1:0][31:0] matrix_write_data,
    output reg [DIM*DIM-1:0][31:0] matrix_read_data,
    output reg [31:0] status_read_data,
    input wire [2:0] command,
    output reg matrix_done
    );
    
    reg [2:0] state;
    
    reg is_setup;
    
    wire [31:0] matrix_offset = DIM*DIM*matrix_num + 1; //+1 for status_addr
   
    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            msi_interrupt_req <= 0;
            axi_start <= 0;
            axi_write <= 0;
            axi_addr <= 0;
            for(int i = 0; i < SYS_DIM_ELEMENTS; ++i) begin
                axi_write_data[i] <= 0;
            end
            axi_num_reads <= 0;
            matrix_read_data <= 0;
            matrix_done <= 0;
            state <= MHS_IDLE;
            status_read_data <= 0;
            axi_num_writes <= 0;
            is_setup <= 0;
        end else begin
            case (state)
                MHS_IDLE: begin
                    is_setup <= 0;
                    if(matrix_done) begin
                        // Give time for higher level module to process done signal
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
                    if(!is_setup) begin
                        axi_num_reads <= DIM*DIM;
                        is_setup <= 1;
                    end if(axi_done) begin
                        matrix_read_data <= axi_read_data;
                        state <= MHS_IDLE;
                        matrix_done <= 1;
                        axi_start <= 0;
                    end else begin
                        axi_start <= 1;
                        axi_addr <= 4*(matrix_offset);
                        axi_write <= 0;
                    end
                end
                MHS_WRITE_RESULT: begin
                    if(!is_setup) begin
                        axi_num_writes <= DIM*DIM;
                        is_setup <= 1;
                    end else if(axi_done) begin
                        state <= MHS_IDLE;
                        matrix_done <= 1;
                        axi_write <= 0;
                        axi_start <= 0;
                    end else begin
                        axi_start <= 1;
                        axi_write <= 1;
                        axi_write_data <= matrix_write_data;
                        axi_addr <= 4*(matrix_offset);
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
