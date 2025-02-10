`timescale 1ns / 1ps
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
    
    output reg start,
    output reg write,
    output reg [31:0] addr,
    output reg [31:0] write_data,
    input wire [31:0] read_data,
    input wire done
    );
    
    
    
    localparam S_IDLE      = 3'd0,
           S_CHECK_0x48    = 3'd1,
           S_DECIDE        = 3'd2,
           S_READ_ARGS     = 3'd3,
           S_COMPUTE       = 3'd4,
           S_WRITE_RESULTS = 3'd5,
           S_WRITE_0x48    = 3'd6,
           S_INTERRUPT     = 3'd7;

reg [2:0] current_state;

reg [17:0][31:0] args;
reg [8:0] arg_num;
wire [8:0][31:0] tmp_outputs;
reg [8:0][31:0] outputs;

reg start_mul;
wire mul_done;

systolic_array #(
    .DIM(3)) multiplier (
    .clk(aclk),
    .rst(aresetn),
    .mat_a(args[8:0]),
    .mat_b(args[17:9]),
    .out(tmp_outputs[8:0]),
    .accumulate(0),
    .start(start_mul),
    .done(mul_done)
    );


////////////////////////////////////////////////////////////////////////////////
// Output and Data Handling
////////////////////////////////////////////////////////////////////////////////
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        start      <= 1'b0;
        write   <= 1'b0;
        addr       <= {32{1'b0}};
        write_data <= {32{1'b0}};
        current_state <= S_IDLE;

        msi_interrupt_req <= 1'b0;
        start_mul <= 1'b0;
        
        for (int init = 0; init < 18; init = init + 1) begin
            args[init] <= 32'h0;
        end
    end else begin
        // Defaults for each cycle
        start      <= 1'b0;
        write   <= 1'b0;

        case (current_state)
            S_IDLE: begin
                current_state <= S_CHECK_0x48;
            end

            // Initiate read of 0x10
            S_CHECK_0x48: begin
                if(done) begin
                    start <= 1'b0;
                    current_state <= S_DECIDE;
                end else begin
                    start      <= 1'b1;
                    write   <= 1'b0;      // Read
                    addr       <= 32'h48;
                end
            end

            // Evaluate data from 0x10
            S_DECIDE: begin
                current_state <= (read_data == 32'd1) ? S_READ_ARGS : S_CHECK_0x48;
            end

            // Read from 0x0 -> reg_A
            S_READ_ARGS: begin
                if (done) begin
                    args[arg_num] <= read_data;
                    arg_num<=arg_num+1;
                    start <= 1'b0;
                    if(arg_num==17) begin
                        arg_num <= 0;
                        start_mul <= 1;
                        current_state <= S_COMPUTE;
                    end
                end else begin
                    start <= 1'b1;
                    write <= 1'b0;
                    addr <= 32'h0 + 4*arg_num;
                end
            end
            
            S_COMPUTE: begin
                start_mul <= 0;
                if(mul_done) begin
                    for(int i = 0; i < 9; i++) begin
                        outputs[i] <= tmp_outputs[i];
                    end
                    current_state <= S_WRITE_RESULTS;
                end
            end

            S_WRITE_RESULTS: begin
                if(done) begin
                    arg_num <= arg_num+1;
                    start <= 1'b0;
                    if(arg_num==8) begin
                        arg_num <= 0;
                        current_state <= S_WRITE_0x48;
                    end
                end else begin
                    start      <= 1'b1;
                    write   <= 1'b1;
                    addr       <= 32'h4c + arg_num * 4;
                    write_data <= outputs[arg_num];
                end
            end
            

            // Write 0 to 0x20
            S_WRITE_0x48: begin
                if(done) begin
                    start <= 1'b0;
                    current_state <= S_INTERRUPT;
                end else begin
                    start <= 1'b1;
                    write <= 1'b1;
                    addr <= 32'h48;
                    write_data <= 32'h0;
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
