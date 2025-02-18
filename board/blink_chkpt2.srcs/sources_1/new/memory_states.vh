`ifndef STATE_DEFS_V
`define STATE_DEFS_V

parameter SYS_DIM        = 4;
parameter MAX_INPUT_SIZE = 70;

parameter MATRIX_NUM_NBITS = $clog2(3*(MAX_INPUT_SIZE*MAX_INPUT_SIZE)/(SYS_DIM*SYS_DIM)+1);

// matrix handle state
parameter MHS_IDLE          = 3'd0;
parameter MHS_READ_STATUS   = 3'd1;
parameter MHS_READ_MATRIX_A = 3'd2;
parameter MHS_READ_MATRIX_B = 3'd3;
parameter MHS_WRITE_RESULT  = 3'd4;
parameter MHS_RESET_STATUS  = 3'd5;
parameter MHS_INTERRUPT     = 3'd6;
`endif