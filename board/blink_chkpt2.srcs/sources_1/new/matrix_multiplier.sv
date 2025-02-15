`timescale 1ns / 1ps
`include "memory_states.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2025 02:08:21 PM
// Design Name: 
// Module Name: matrix_multiplier
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


module matrix_multiplier    #(
    parameter SYS_DIM,
    parameter INPUT_DIM
    ) (
    input wire aclk,
    input wire aresetn,
    
    output reg [2:0] matrix_command,
    output reg [SYS_DIM*SYS_DIM-1:0] matrix_num,
    input wire [31:0] status_read_data,
    input wire [SYS_DIM*SYS_DIM-1:0][31:0] matrix_read_data,
    output reg [SYS_DIM*SYS_DIM-1:0][31:0] matrix_write_data,
    input wire matrix_done
    );
    
    
    
    localparam S_IDLE      = 4'd0,
           S_CHECK_STATUS    = 4'd1,
           S_DECIDE        = 4'd2,
           S_START_TILE    = 4'd3,
           S_READ_A      = 4'd4,
           S_READ_B     = 4'd5,
           S_COMPUTE       = 4'd6,
           S_COMPLETE_TILE  = 4'd7,
           S_WRITE_RESULTS = 4'd8,
           S_WRITE_STATUS    = 4'd9,
           S_INTERRUPT     = 4'd10;
    
reg [3:0] current_state;

reg [SYS_DIM*SYS_DIM-1:0][31:0] mat_a;
reg [SYS_DIM*SYS_DIM-1:0][31:0] mat_b;

reg start_mul;
wire mul_done;

localparam int TILE_SPAN = INPUT_DIM/SYS_DIM;

reg [TILE_SPAN:0] output_tile_num;
reg [TILE_SPAN-1:0] sub_tile_num;

reg accumulate;

systolic_array #(
    .DIM(SYS_DIM)) multiplier (
    .clk(aclk),
    .rst(aresetn),
    .mat_a(mat_a),
    .mat_b(mat_b),
    .out(matrix_write_data),
    .accumulate(accumulate),
    .start(start_mul),
    .done(mul_done)
    );

////////////////////////////////////////////////////////////////////////////////
// Output and Data Handling
////////////////////////////////////////////////////////////////////////////////
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        current_state <= S_IDLE;
        start_mul <= 1'b0;
        accumulate <= 0;
        matrix_num <= 0;
        matrix_command <= MHS_IDLE;
        output_tile_num <= 0;
        sub_tile_num <= 0;
        
        for (int init = 0; init < SYS_DIM*SYS_DIM; init = init + 1) begin
            mat_a[init] <= 32'h0;
            mat_b[init] <= 32'h0;
        end
    end else begin
        matrix_command <= MHS_IDLE;
        case (current_state)
            S_IDLE: begin
                current_state <= S_CHECK_STATUS;
            end

            S_CHECK_STATUS: begin
                if(matrix_done) begin
                    current_state <= S_DECIDE;
                 end else begin
                    matrix_command <= MHS_READ_STATUS;
                 end
            end

            S_DECIDE: begin
                current_state <= (status_read_data == 32'd1) ? S_START_TILE : S_CHECK_STATUS;
            end
            
            S_START_TILE: begin
                if(output_tile_num==TILE_SPAN*TILE_SPAN) begin
                    output_tile_num <= 0;
                    current_state <= S_WRITE_STATUS;
                end else begin
                    accumulate <= 1;
                    current_state <= S_READ_A;
                end
            end

            // Read from 0x0 -> reg_A
            S_READ_A: begin
                if (matrix_done) begin
                    mat_a <= matrix_read_data;
                    current_state <= S_READ_B;
                end else begin
                    matrix_num <= TILE_SPAN*(output_tile_num/TILE_SPAN)+sub_tile_num;
                    matrix_command <= MHS_READ_MATRIX_A;
                end
            end
            
            S_READ_B: begin
                if (matrix_done) begin
                    mat_b <= matrix_read_data;
                    current_state <= S_COMPUTE;
                end else begin
                    matrix_num <= TILE_SPAN*sub_tile_num + (output_tile_num % TILE_SPAN) + INPUT_DIM;
                    matrix_command <= MHS_READ_MATRIX_B;
                end
            end
            
            S_COMPUTE: begin
                if(mul_done) begin
                    start_mul <= 0;
                    current_state <= S_COMPLETE_TILE;
                end else begin
                    start_mul <= 1;
                end
            end
            
            S_COMPLETE_TILE: begin
                if(sub_tile_num==TILE_SPAN-1) begin
                    sub_tile_num <= 0;
                    output_tile_num <= output_tile_num + 1;
                    current_state <= S_WRITE_RESULTS;
                end else begin
                    sub_tile_num <= sub_tile_num + 1;
                    current_state <= S_READ_A;
                end
            end

            S_WRITE_RESULTS: begin
                if(matrix_done) begin
                    current_state <= S_START_TILE;
                    accumulate <= 0; // we've written results, can reset now
                end else begin
                    matrix_num <= (output_tile_num-1) + (INPUT_DIM*2); // offset with others
                    matrix_command <= MHS_WRITE_RESULT;
                end
            end
            
            S_WRITE_STATUS: begin
                if(matrix_done) begin
                    current_state <= S_INTERRUPT;
                end else begin
                    matrix_command <= MHS_RESET_STATUS;
                end
            end
            
            S_INTERRUPT: begin
                if(matrix_done) begin
                    current_state <= S_IDLE;
                end else begin
                    matrix_command <= MHS_INTERRUPT;
                end
            end
            default: current_state <= S_IDLE;
        endcase
    end
end 
endmodule
