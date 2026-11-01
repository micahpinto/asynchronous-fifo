// BROKEN ON PURPOSE: binary pointers cross the clock domains.
// Same as async_fifo.sv, except the pointers are sent across in BINARY, not Gray.
// Each bit still has a 2-flop ASYNC_REG synchronizer.
// When several bits change at once (e.g. 0111 -> 1000), the bits can arrive on
// different clocks and the other side can see a pointer value that never existed.
// DEPTH must be a power of 2 (4, 8, 16, ...).
module async_fifo #(
  parameter int WIDTH = 8,     // bits per slot
  parameter int DEPTH = 16     // number of slots
)(
  // write side: runs on i_Wr_Clk 
  input  logic             i_Wr_Clk,
  input  logic             i_Wr_En,
  input  logic [WIDTH-1:0] i_Wr_Data,
  output logic             o_Full,

  //read side: runs on i_Rd_Clk
  input  logic             i_Rd_Clk,
  input  logic             i_Rd_En,
  output logic [WIDTH-1:0] o_Rd_Data,
  output logic             o_Empty
);

  localparam int PTR_W = $clog2(DEPTH);

  // shared memory
  logic [WIDTH-1:0] r_Mem [DEPTH];

  // =====================================================================
  // WRITE DOMAIN (i_Wr_Clk)
  // =====================================================================
  logic [PTR_W:0] r_Wr_Ptr = '0;          // write pointer, binary

  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Rd_Ptr_Sync1 = '0;    // read pointer arriving
  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Rd_Ptr_Sync2 = '0;    // IN BINARY (the bug)

  logic w_Wr;
  assign w_Wr = i_Wr_En && !o_Full;

  always_ff @(posedge i_Wr_Clk) begin
    if (w_Wr) begin
      r_Mem[r_Wr_Ptr[PTR_W-1:0]] <= i_Wr_Data;
      r_Wr_Ptr <= r_Wr_Ptr + 1'b1;
    end
    r_Rd_Ptr_Sync1 <= r_Rd_Ptr;                           // BUG: binary pointer crosses
    r_Rd_Ptr_Sync2 <= r_Rd_Ptr_Sync1;
  end

  // full in binary: same slot bits, different lap bit
  assign o_Full = (r_Wr_Ptr[PTR_W] != r_Rd_Ptr_Sync2[PTR_W]) &&
                  (r_Wr_Ptr[PTR_W-1:0] == r_Rd_Ptr_Sync2[PTR_W-1:0]);

  // =====================================================================
  // READ DOMAIN (i_Rd_Clk)
  // =====================================================================
  logic [PTR_W:0] r_Rd_Ptr = '0;          // read pointer, binary

  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Wr_Ptr_Sync1 = '0;    // write pointer arriving
  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Wr_Ptr_Sync2 = '0;    // IN BINARY (the bug)

  logic w_Rd;
  assign w_Rd = i_Rd_En && !o_Empty;

  always_ff @(posedge i_Rd_Clk) begin
    if (w_Rd)
      r_Rd_Ptr <= r_Rd_Ptr + 1'b1;
    r_Wr_Ptr_Sync1 <= r_Wr_Ptr;                           // BUG: binary pointer crosses
    r_Wr_Ptr_Sync2 <= r_Wr_Ptr_Sync1;
  end

  // empty in binary: pointers equal
  assign o_Empty   = (r_Rd_Ptr == r_Wr_Ptr_Sync2);
  assign o_Rd_Data = r_Mem[r_Rd_Ptr[PTR_W-1:0]];

endmodule