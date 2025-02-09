`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/08/2025 06:16:23 PM
// Design Name: 
// Module Name: pe_grid_generator
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


module pe_grid_generator #(
    parameter DIM = 3
    )(
        input wire clk,
        input wire rst, 
        input wire valid,
        input wire [31:0] a_in [DIM-1:0],
        input wire [31:0] b_in [DIM-1:0],
        output wire [(DIM*DIM)-1:0][31:0] result
    );
    
    wire [31:0] a_out [(DIM*(DIM-1))-1:0];
    wire [31:0] b_out [(DIM*(DIM-1))-1:0];
    
    genvar x,y;
    
    generate
        for(y = 0; y < DIM; y = y + 1) begin : gen1
            for(x = 0; x < DIM; x = x + 1) begin : gen2
                wire [31:0] _a_in = (x==0) ? a_in[y] : a_out[x+(y*(DIM-1))-1];
                wire [31:0] _b_in = (y==0) ? b_in[x] : b_out[x+(y*DIM)-3];
                
                if(x==DIM-1 && y==DIM-1) begin
                    systolic_PE sys_pe(
                        .clk(clk),
                        .rst(rst),
                        .a_in(_a_in),
                        .b_in(_b_in),
                        .valid(valid),
                        .result(result[x+(y*DIM)])
                        );
                end else if(x==DIM-1) begin
                    systolic_PE sys_pe(
                        .clk(clk),
                        .rst(rst),
                        .a_in(_a_in),
                        .b_in(_b_in),
                        .b_out(b_out[x+(y*DIM)]),
                        .valid(valid),
                        .result(result[x+(y*DIM)])
                        );
                end else if(y==DIM-1) begin
                    systolic_PE sys_pe(
                        .clk(clk),
                        .rst(rst),
                        .a_in(_a_in),
                        .a_out(a_out[x+(y*(DIM-1))]),
                        .b_in(_b_in),
                        .valid(valid),
                        .result(result[x+(y*DIM)])
                        );
                end else begin
                    systolic_PE sys_pe(
                        .clk(clk),
                        .rst(rst),
                        .a_in(_a_in),
                        .a_out(a_out[x+(y*(DIM-1))]),
                        .b_in(_b_in),
                        .b_out(b_out[x+(y*DIM)]),
                        .valid(valid),
                        .result(result[x+(y*DIM)])
                        );
                end
            end
        end
    endgenerate
                    
endmodule
