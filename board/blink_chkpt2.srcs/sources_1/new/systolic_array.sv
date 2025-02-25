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


module systolic_array #(
    parameter DIM
    ) (
    input wire clk,
    input wire rst,
    input wire [(DIM*DIM)-1:0][31:0] mat_a,
    input wire [(DIM*DIM)-1:0][31:0] mat_b,
    output wire [(DIM*DIM)-1:0][31:0] out,
    input wire accumulate,
    input wire start,
    output reg done
    );
    
    reg [$clog2(DIM*2+1):0] cycle_count;
    reg [15:0] a_in [DIM-1:0];
    reg [15:0] b_in [DIM-1:0];
    
    // Number of bits needed to represent DIM*2
    reg [2:0] state;
    
    localparam S_IDLE       = 3'd0,
               S_RUNNING    = 3'd1,
               S_COMPLETE   = 3'd2;
    
    wire running = state != S_IDLE;
    
       
    generate
    for(genvar i = 0; i < DIM; i++) begin
        always @(posedge clk) begin
            if(!rst) begin
                a_in[i] <= 0;
                b_in[i] <= 0;
            end else if(running && i <= cycle_count && cycle_count <= DIM+i-1) begin
                a_in[i] <= mat_a[i*DIM+(cycle_count-i)][15:0];
                b_in[i] <= mat_b[i+(cycle_count-i)*DIM][15:0];
            end else begin
                a_in[i] <= 0;
                b_in[i] <= 0;
            end
        end
    end
    endgenerate
    
    always @(posedge clk) begin
        if(!rst) begin
            cycle_count <= 0;
            done <= 0;
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if(start) begin
                        state <= S_RUNNING;
                        cycle_count <= 0;
                    end
                end
                S_RUNNING: begin
                    cycle_count <= cycle_count + 1;
                    if(cycle_count == 3*DIM) begin // this is kinda manual/should be tweaked i think
                        state <= S_COMPLETE;
                        done <= 1;
                    end
                end
                S_COMPLETE: begin
                    done <= 0;
                    state <= S_IDLE;
                end
            endcase
        end
    end
    
    pe_grid_generator #(.DIM(DIM)
        ) pe_grid (
            .clk(clk),
            .rst(rst),
            .valid(accumulate || running),
            .a_in(a_in),
            .b_in(b_in),
            .result(out)
            );
    
        
endmodule
