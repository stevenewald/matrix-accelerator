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
    output reg [31:0] axi_write_data,
    input wire [31:0] axi_read_data,
    input wire axi_done,
    
    output reg msi_interrupt_req,
    input wire msi_interrupt_ack,
    
    input wire clk,
    input wire rstn,
    
    input wire [$clog2((MAX_INPUT_SIZE*MAX_INPUT_SIZE)/(DIM*DIM)+1)-1:0] matrix_num,
    input wire [DIM*DIM-1:0][31:0] matrix_write_data,
    output reg [DIM*DIM-1:0][31:0] matrix_read_data,
    output reg [31:0] status_read_data,
    input wire [2:0] command,
    output reg matrix_done
    );
    
    reg [2:0] state;
    reg [$clog2(DIM*DIM+1)-1:0] arg_num;
    
    wire [31:0] matrix_offset = DIM*DIM*matrix_num + 1; //+1 for status_addr
    
    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            msi_interrupt_req <= 0;
            axi_start <= 0;
            axi_write <= 0;
            axi_addr <= 0;
            axi_write_data <= 0;
            matrix_read_data <= 0;
            matrix_done <= 0;
            state <= MHS_IDLE;
            arg_num <= 0;
            status_read_data <= 0;
        end else begin
            case (state)
                MHS_IDLE: begin
                    if(matrix_done) begin
                        // Give time for higher level module to process done signal
                        matrix_done <= 0;
                    end else begin
                        state <= command;
                    end
                end
                MHS_READ_STATUS: begin
                    if(axi_done) begin
                        status_read_data <= axi_read_data;
                        matrix_done <= 1;
                        axi_start <= 0;
                        state <= MHS_IDLE;
                    end else begin
                        axi_addr <= STATUS_ADDR;
                        axi_write <= 0;
                        axi_start <= 1;
                    end
                end
                MHS_READ_MATRIX_A: begin
                    if(axi_done) begin
                        axi_start <= 0;
                        matrix_read_data[arg_num] <= axi_read_data;
                        if(arg_num==(DIM*DIM-1)) begin
                            state <= MHS_IDLE;
                            arg_num <= 0;
                            matrix_done <= 1;
                        end else begin
                            arg_num <= arg_num + 1;
                        end
                    end else begin
                        axi_start <= 1;
                        axi_addr <= 4*(matrix_offset + arg_num);
                        axi_write <= 0;
                    end                            
                end
                MHS_READ_MATRIX_B: begin
                    if(axi_done) begin
                        axi_start <= 0;
                        matrix_read_data[arg_num] <= axi_read_data;
                        if(arg_num==(DIM*DIM-1)) begin
                            state <= MHS_IDLE;
                            arg_num <= 0;
                            matrix_done <= 1;
                        end else begin
                            arg_num <= arg_num + 1;
                        end
                    end else begin
                        axi_start <= 1;
                        axi_addr <= 4*(matrix_offset+arg_num);
                        axi_write <= 0;
                    end                            
                end
                MHS_WRITE_RESULT: begin
                    if(axi_done) begin
                        axi_start <= 0;

                        if(arg_num==(DIM*DIM-1)) begin
                            state <= MHS_IDLE;
                            arg_num <= 0;
                            matrix_done <= 1;
                            axi_write <= 0;
                        end else begin
                            arg_num <= arg_num+1;
                        end
                    end else begin
                        axi_start <= 1;
                        axi_write <= 1;
                        axi_write_data <= matrix_write_data[arg_num];
                        axi_addr <= 4*(matrix_offset + arg_num);
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
                        axi_write_data <= 0;
                        axi_write <= 1;
                        axi_start <= 1;
                    end
                end
            endcase
        end
    end
endmodule
