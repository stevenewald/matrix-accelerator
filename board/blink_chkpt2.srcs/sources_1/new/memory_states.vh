`ifndef STATE_DEFS_V
`define STATE_DEFS_V

parameter SYS_DIM        = 8;
parameter MAX_INPUT_SIZE = 104;

parameter MATRIX_NUM_NBITS = $clog2(3*(MAX_INPUT_SIZE*MAX_INPUT_SIZE)/(SYS_DIM*SYS_DIM)+1);

// Must be <= AXI_MAX_BURST_LEN
parameter TILE_NUM_ELEMENTS = SYS_DIM*SYS_DIM;

// Max burst size - corresponds to read/write buffer for axi master
parameter AXI_MAX_BURST_LEN = TILE_NUM_ELEMENTS/2;

parameter INPUT_NUM_BITS = 16;

parameter MAX_TILE_SPAN = MAX_INPUT_SIZE/SYS_DIM;
parameter MAX_TILE_NUM = MAX_TILE_SPAN*MAX_TILE_SPAN;
parameter BITS_PER_OUTPUT_TILE_NUM = $clog2(MAX_TILE_NUM+1);
parameter BITS_PER_TILE_CNT = $clog2(MAX_TILE_SPAN+1);

parameter BITS_PER_MATRIX_NUM = $clog2(3*(MAX_INPUT_SIZE*MAX_INPUT_SIZE)/(SYS_DIM*SYS_DIM)+1);

// matrix handle state
parameter MHS_IDLE          = 4'd0;
parameter MHS_READ_STATUS   = 4'd1;
parameter MHS_READ_MATRIX = 4'd2;
parameter MHS_WRITE_RESULT  = 3'd4;
parameter MHS_RESET_STATUS  = 3'd5;
parameter MHS_INTERRUPT     = 3'd6;
`endif