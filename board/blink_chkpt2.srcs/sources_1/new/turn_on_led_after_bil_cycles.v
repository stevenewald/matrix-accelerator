`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2025 03:28:50 PM
// Design Name: 
// Module Name: turn_on_led_after_bil_cycles
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


module turn_on_led_after_bil_cycles(
    input wire refclk,
    output reg led
    );
    
    reg [28:0] counter;

    // Parameter for the cycle threshold (300 million)
    parameter THRESHOLD = 29'd100_000_000;
    
    always @(posedge refclk) begin
        if (counter == THRESHOLD - 1) begin
            // Toggle LED when the counter reaches the threshold
            led <= ~led;
            counter <= 29'd0; // Reset the counter
        end else begin
            // Increment the counter
            counter <= counter + 1;
        end
    end
endmodule
