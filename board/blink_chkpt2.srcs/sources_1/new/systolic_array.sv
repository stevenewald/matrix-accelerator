`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/06/2025 06:11:28 PM
// Design Name: 
// Module Name: systolic_array
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


module systolic_array(
    input wire clk,
    input wire rst,
    input wire [8:0][31:0] mat_a,
    input wire [8:0][31:0] mat_b,
    output wire [8:0][31:0] out,
    input wire start,
    output reg done
    );
    
    localparam DIM = 2'd3;
    
    reg [2:0] cycle_count;
    reg [31:0] a_in [DIM-1:0];
    reg [31:0] b_in [DIM-1:0];
    
    reg [2:0] state;
    
    localparam S_IDLE       = 3'd0,
               S_RUNNING    = 3'd1,
               S_COMPLETE   = 3'd2;
    
    always @(posedge clk) begin
        if(!rst) begin
            cycle_count <= 0;
            done <= 0;
            state <= S_IDLE;
            for(int i = 0; i < DIM; i++) begin
                a_in[i] <= 32'b0;
                b_in[i] <= 32'b0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if(start) begin
                        cycle_count <= 0;
                        state <= S_RUNNING;
                    end
                end
                S_RUNNING: begin

                    if(cycle_count <= 2) begin
                        a_in[0] <= mat_a[cycle_count];
                        b_in[0] <= mat_b[cycle_count*3];
                    end else begin
                        a_in[0] <= 0;
                        b_in[0] <= 0;
                    end
                    
                    if(1 <= cycle_count && cycle_count <= 3) begin
                        a_in[1] <= mat_a[3+(cycle_count-1)];
                        b_in[1] <= mat_b[1+(cycle_count-1)*3];
                    end else begin
                        a_in[1] <= 0;
                        b_in[1] <= 0;
                    end
                    
                    if(2 <= cycle_count && cycle_count <= 4) begin
                        a_in[2] <= mat_a[6+(cycle_count-2)];
                        b_in[2] <= mat_b[2+(cycle_count-2)*3];
                    end else begin
                        a_in[2] <= 0;
                        b_in[2] <= 0;
                    end
                    
                    if(cycle_count == 6) begin
                        state <= S_COMPLETE;
                    end
                    cycle_count <= cycle_count + 1;
                end
                S_COMPLETE: begin
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
    
    wire running = state != S_IDLE;
    
    pe_grid_generator #(.DIM(3)
        ) pe_grid (
            .clk(clk),
            .rst(rst),
            .valid(running),
            .a_in(a_in),
            .b_in(b_in),
            .result(out)
            );
    
        
endmodule
