// BROKEN ON PURPOSE: no synchronizers.
// Same as async_fifo.sv (Gray pointers), except the Gray pointer from the other
// clock domain is used DIRECTLY in the full/empty compare, with no 2-flop
// synchronizer. A flop that samples it can go metastable.
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

  //the two registered Gray pointers (declared here, used by both sides)
  logic [PTR_W:0] r_Wr_Gray = '0;         // write domain: goes to the read side
  logic [PTR_W:0] r_Rd_Gray = '0;         // read domain:  goes to the write side

  // =====================================================================
  // WRITE DOMAIN (i_Wr_Clk)
  // =====================================================================
  logic [PTR_W:0] r_Wr_Ptr  = '0;         // write pointer, binary
  logic [PTR_W:0] w_Wr_Gray;              // its Gray version

  logic w_Wr;
  assign w_Wr      = i_Wr_En && !o_Full;
  assign w_Wr_Gray = r_Wr_Ptr ^ (r_Wr_Ptr >> 1);

  always_ff @(posedge i_Wr_Clk) begin
    if (w_Wr) begin
      r_Mem[r_Wr_Ptr[PTR_W-1:0]] <= i_Wr_Data;
      r_Wr_Ptr <= r_Wr_Ptr + 1'b1;
    end
    r_Wr_Gray <= w_Wr_Gray;
  end

  // BUG: r_Rd_Gray comes from the READ clock domain, used here with no synchronizer
  logic [PTR_W:0] w_Full_Gray;            // read pointer with the top 2 bits inverted
  assign w_Full_Gray = {~r_Rd_Gray[PTR_W:PTR_W-1], r_Rd_Gray[PTR_W-2:0]};
  assign o_Full      = (w_Wr_Gray == w_Full_Gray);

  // =====================================================================
  // READ DOMAIN (i_Rd_Clk)
  // =====================================================================
  logic [PTR_W:0] r_Rd_Ptr  = '0;         // read pointer, binary
  logic [PTR_W:0] w_Rd_Gray;              // its Gray version

  logic w_Rd;
  assign w_Rd      = i_Rd_En && !o_Empty;
  assign w_Rd_Gray = r_Rd_Ptr ^ (r_Rd_Ptr >> 1);

  always_ff @(posedge i_Rd_Clk) begin
    if (w_Rd)
      r_Rd_Ptr <= r_Rd_Ptr + 1'b1;
    r_Rd_Gray <= w_Rd_Gray;
  end

  // BUG: r_Wr_Gray comes from the WRITE clock domain, used here with no synchronizer
  assign o_Empty   = (w_Rd_Gray == r_Wr_Gray);
  assign o_Rd_Data = r_Mem[r_Rd_Ptr[PTR_W-1:0]];

endmodule