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


module matrix_multiplier(
    input wire aclk,
    input wire aresetn,
    
    output reg msi_interrupt_req,
    input wire msi_interrupt_ack,
    
    output wire start,
    output wire write,
    output wire [31:0] addr,
    output wire [31:0] write_data,
    input wire [31:0] read_data,
    input wire done
    );
    
    
    
    localparam S_IDLE      = 4'd0,
           S_CHECK_STATUS    = 4'd1,
           S_DECIDE        = 4'd2,
           S_READ_A      = 4'd3,
           S_READ_B     = 4'd8,
           S_COMPUTE       = 4'd4,
           S_WRITE_RESULTS = 4'd5,
           S_WRITE_STATUS    = 4'd6,
           S_INTERRUPT     = 4'd7;

reg [2:0] handle_command;
wire [8:0][31:0] read_matrix;
wire [8:0][31:0] write_matrix;
wire [31:0] read_status;
wire handle_done;


matrix_memory_handle #(
    .DIM(3)) matrix_handle (
    .axi_start(start),
    .axi_write(write),
    .axi_addr(addr),
    .axi_write_data(write_data),
    .axi_read_data(read_data),
    .axi_done(done),
    .clk(aclk),
    .matrix_done(handle_done),
    .command(handle_command),
    .status_read_data(read_status),
    .matrix_write_data(write_matrix),
    .matrix_read_data(read_matrix),
    .rstn(aresetn));
    
reg [3:0] current_state;

reg [8:0][31:0] mat_a;
reg [8:0][31:0] mat_b;

reg start_mul;
wire mul_done;

reg accumulate;

systolic_array #(
    .DIM(3)) multiplier (
    .clk(aclk),
    .rst(aresetn),
    .mat_a(mat_a),
    .mat_b(mat_b),
    .out(write_matrix),
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

        msi_interrupt_req <= 1'b0;
        start_mul <= 1'b0;
        accumulate <= 0;
        
        handle_command <= MHS_IDLE;
        
        for (int init = 0; init < 9; init = init + 1) begin
            mat_a[init] <= 32'h0;
            mat_b[init] <= 32'h0;
        end
    end else begin
        // Defaults for each cycle
        case (current_state)
            S_IDLE: begin
                current_state <= S_CHECK_STATUS;
            end

            // Initiate read of 0x10
            S_CHECK_STATUS: begin
                if(handle_done) begin
                    handle_command <= MHS_IDLE;
                    current_state <= S_DECIDE;
                 end else begin
                    handle_command <= MHS_READ_STATUS;
                 end
            end

            // Evaluate data from 0x10
            S_DECIDE: begin
                current_state <= (read_status == 32'd1) ? S_READ_A : S_CHECK_STATUS;
            end

            // Read from 0x0 -> reg_A
            S_READ_A: begin
                if (handle_done) begin
                    mat_a <= read_matrix;
                    handle_command <= MHS_IDLE;
                    current_state <= S_READ_B;
                end else begin
                    handle_command <= MHS_READ_MATRIX_A;
                end
            end
            
            S_READ_B: begin
                if (handle_done) begin
                    mat_b <= read_matrix;
                    handle_command <= MHS_IDLE;
                    current_state <= S_COMPUTE;
                end else begin
                    handle_command <= MHS_READ_MATRIX_B;
                end
            end
            
            S_COMPUTE: begin
                if(mul_done) begin
                    start_mul <= 0;
                    current_state <= S_WRITE_RESULTS;
                end else begin
                    start_mul <= 1;
                    accumulate <= 1;
                end
            end

            S_WRITE_RESULTS: begin
                if(handle_done) begin
                    handle_command <= MHS_IDLE;
                    current_state <= S_WRITE_STATUS;
                    accumulate <= 0;
                end else begin
                    handle_command <= MHS_WRITE_RESULT;
                end
            end
            

            // Write 0 to 0x20
            S_WRITE_STATUS: begin
                if(handle_done) begin
                    handle_command <= MHS_IDLE;
                    current_state <= S_INTERRUPT;
                end else begin
                    handle_command <= MHS_RESET_STATUS;
                end
            end
            S_INTERRUPT: begin
                if(msi_interrupt_req && msi_interrupt_ack) begin
                    msi_interrupt_req <= 1'b0;
                    current_state <= S_IDLE;
                end else begin
                    msi_interrupt_req <= 1'b1;
                end
            end
            default: current_state <= S_IDLE;
        endcase
    end
end 
endmodule
