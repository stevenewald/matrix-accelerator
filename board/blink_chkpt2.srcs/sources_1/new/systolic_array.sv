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
    
    reg [2:0] cycle_count;
    reg [31:0] a_in [2:0];
    reg [31:0] b_in [2:0];
    
    reg [2:0] state;
    
    localparam S_IDLE       = 3'd0,
               S_RUNNING    = 3'd1,
               S_COMPLETE   = 3'd2;
    
    always @(posedge clk) begin
        if(!rst) begin
            cycle_count <= 0;
            done <= 0;
            state <= S_IDLE;
            for(int i = 0; i < 4; i++) begin
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
                    cycle_count <= cycle_count + 1;
                    if(cycle_count < 7) begin
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
                    end
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
    
    /*// 100
    // 000
    // 000
    systolic_PE pe11(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[0]),
        .a_out(a_out[0]),
        .b_in(b_in[0]),
        .b_out(b_out[0]),
        .valid(running),
        .result(out[0]));
        
    // 010
    // 000
    // 000
    systolic_PE pe12(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[0]),
        .a_out(a_out[1]),
        .b_in(b_in[1]),
        .b_out(b_out[1]),
        .valid(running),
        .result(out[1]));
    
    // 001
    // 000
    // 000
    systolic_PE pe13(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[1]),
        .a_out(a_out[2]),
        .b_in(b_in[2]),
        .b_out(b_out[2]),
        .valid(running),
        .result(out[2]));
        
        
    // 000
    // 100
    // 000
    systolic_PE pe21(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[1]),
        .a_out(a_out[3]),
        .b_in(b_out[0]),
        .b_out(b_out[3]),
        .valid(running),
        .result(out[3]));
        
    // 000
    // 010
    // 000
    systolic_PE pe22(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[3]),
        .a_out(a_out[4]),
        .b_in(b_out[1]),
        .b_out(b_out[4]),
        .valid(running),
        .result(out[4]));
        
    // 000
    // 001
    // 000
    systolic_PE pe23(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[4]),
        .a_out(a_out[5]),
        .b_in(b_out[2]),
        .b_out(b_out[5]),
        .valid(running),
        .result(out[5]));
        
    // 000
    // 000
    // 100
    systolic_PE pe31(
        .clk(clk),
        .rst(rst),
        .a_in(a_in[2]),
        .a_out(a_out[6]),
        .b_in(b_out[3]),
        .b_out(b_out[6]),
        .valid(running),
        .result(out[6]));
        
    // 000
    // 000
    // 010
    systolic_PE pe32(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[6]),
        .a_out(a_out[7]),
        .b_in(b_out[4]),
        .b_out(b_out[7]),
        .valid(running),
        .result(out[7]));
        
    // 000
    // 000
    // 001
    systolic_PE pe33(
        .clk(clk),
        .rst(rst),
        .a_in(a_out[7]),
        .a_out(a_out[8]),
        .b_in(b_out[5]),
        .b_out(b_out[8]),
        .valid(running),
        .result(out[8]));*/
        
endmodule
