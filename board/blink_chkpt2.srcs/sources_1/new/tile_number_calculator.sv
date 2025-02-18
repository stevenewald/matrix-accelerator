`timescale 1ns / 1ps
`include "memory_states.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/16/2025 01:52:32 PM
// Design Name: 
// Module Name: tile_number_calculator
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


module tile_number_calculator #(
    parameter SYS_DIM
    ) (
    input wire aclk,
    input wire arstn,
    
    input wire [BITS_PER_INPUT_DIM-1:0] input_dim,
    output reg [BITS_PER_TILE_SPAN-1:0] tile_span,
    
    input wire [BITS_PER_OUTPUT_TILE-1:0] output_tile_num,
    input wire [BITS_PER_SUB_TILE-1:0] sub_tile_num,
    
    output reg [BITS_PER_MATRIX_NUM-1:0] matrix_a_num,
    //output reg [31:0] matrix_b_num,
    
    output wire valid
    );
    
    localparam S_IDLE = 3'd0,
               S_CALC_TILE_SPAN = 3'd1,
               S_CALC_A  = 3'd2,
               S_FINISH_A1 = 3'd3,
               S_FINISH_A2 = 3'd4,
               S_DONE       = 3'd5;
               
    reg [2:0] state;
    
    // calc tile span
    reg [BITS_PER_TILE_SPAN:0] tmp_dim;
    
    // calc A
    reg [BITS_PER_TILE_SPAN:0] tmp_tile_span;
    reg [BITS_PER_SUB_TILE-1:0] old_sub_tile_num;
    
    reg [BITS_PER_MATRIX_NUM-1:0] tmp_mat_a_num;
        
    assign valid = state == S_IDLE;
    
    always @(posedge aclk) begin
        if(!arstn) begin
            state <= S_IDLE;
            tmp_dim <= 0;
            tile_span <= 0;
            matrix_a_num <= 0;
            
            tmp_tile_span <= 0;
            old_sub_tile_num <= 0;
            tmp_mat_a_num <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if(tmp_dim!=input_dim) begin
                        tmp_dim <= 0;
                        tile_span <= 0;
                        matrix_a_num <= 0;
                        tmp_tile_span <= 0;
                        tmp_mat_a_num <= 0;
                        state <= S_CALC_TILE_SPAN;
                    end
                    
                    if(old_sub_tile_num!=sub_tile_num) begin
                        old_sub_tile_num <= sub_tile_num;
                        tmp_tile_span <= 0;
                        tmp_mat_a_num <= 0;
                        state <= S_CALC_A;
                    end
                        
                end
                
                S_CALC_TILE_SPAN: begin
                    if(tmp_dim>=input_dim) begin
                        tile_span <= tmp_tile_span;
                        state <= S_IDLE;
                    end else begin 
                        tmp_dim <= tmp_dim + SYS_DIM;
                        tmp_tile_span <= tmp_tile_span + 1;
                    end
                end
                
                // mat_a = tile_span*(output_tile_num/tile_span)+sub_tile_num;
                // mat_b = tile_span*sub_tile_num + (output_tile_num % tile_span) + tile_span*tile_span;
                S_CALC_A: begin
                    if(tmp_tile_span > output_tile_num) begin
                        tmp_mat_a_num <= tmp_mat_a_num*tile_span;
                        state <= S_FINISH_A1;
                    end else begin
                        tmp_tile_span <= tmp_tile_span + tile_span;
                        tmp_mat_a_num <= tmp_mat_a_num + 1;
                    end
                end
                
                S_FINISH_A1: begin
                    tmp_mat_a_num <= tmp_mat_a_num + sub_tile_num - tile_span;
                    state <= S_FINISH_A2;
                end
                
                S_FINISH_A2: begin
                    matrix_a_num <= tmp_mat_a_num;
                    state <= S_DONE;
                end
                
                S_DONE: begin
                    state <= S_IDLE;
                end
            endcase 
        end
    end
endmodule
