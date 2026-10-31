// Asynchronous (dual-clock) FIFO.
// The write side and the read side run on two unrelated clocks.
// The data stays in the memory; only the pointers cross between the clock domains,
// in Gray code, each through a two-flop synchronizer.
// DEPTH must be a power of 2 (4, 8, 16, ...).
module async_fifo #(
  parameter int WIDTH = 8,     // bits per slot
  parameter int DEPTH = 16     // number of slots
)(
  //write side: runs on i_Wr_Clk
  input  logic             i_Wr_Clk,
  input  logic             i_Wr_En,
  input  logic [WIDTH-1:0] i_Wr_Data,
  output logic             o_Full,      // computed in the write domain

  //read side: runs on i_Rd_Clk
  input  logic             i_Rd_Clk,
  input  logic             i_Rd_En,
  output logic [WIDTH-1:0] o_Rd_Data,
  output logic             o_Empty      // computed in the read domain
);

  localparam int PTR_W = $clog2(DEPTH);   // 16 slots -> 4 slot bits; pointers have PTR_W+1 bits (lap bit)

  //shared memory
  logic [WIDTH-1:0] r_Mem [DEPTH];        // written on the write clock, read by the read side

  // =====================================================================
  // WRITE DOMAIN (i_Wr_Clk)
  // =====================================================================
  logic [PTR_W:0] r_Wr_Ptr  = '0;         // write pointer, binary (lap bit + slot bits)
  logic [PTR_W:0] w_Wr_Gray;              // its Gray version (combinational)
  logic [PTR_W:0] r_Wr_Gray = '0;         // registered Gray copy: this one crosses to the read side

  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Rd_Gray_Sync1 = '0;   // read pointer arriving
  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Rd_Gray_Sync2 = '0;   // from the read side

  logic w_Wr;
  assign w_Wr      = i_Wr_En && !o_Full;                  // never write when full
  assign w_Wr_Gray = r_Wr_Ptr ^ (r_Wr_Ptr >> 1);          // binary -> Gray

  always_ff @(posedge i_Wr_Clk) begin
    if (w_Wr) begin
      r_Mem[r_Wr_Ptr[PTR_W-1:0]] <= i_Wr_Data;            // store the byte
      r_Wr_Ptr <= r_Wr_Ptr + 1'b1;                        // move to the next slot
    end
    r_Wr_Gray       <= w_Wr_Gray;                         // clean copy, before crossing
    r_Rd_Gray_Sync1 <= r_Rd_Gray;                         // synchronizer flop 1
    r_Rd_Gray_Sync2 <= r_Rd_Gray_Sync1;                   // synchronizer flop 2
  end

  // full: in Gray, top 2 bits inverted and the rest equal
  assign o_Full = (w_Wr_Gray == {~r_Rd_Gray_Sync2[PTR_W:PTR_W-1], r_Rd_Gray_Sync2[PTR_W-2:0]});

  // =====================================================================
  // READ DOMAIN (i_Rd_Clk)
  // =====================================================================
  logic [PTR_W:0] r_Rd_Ptr  = '0;         // read pointer, binary
  logic [PTR_W:0] w_Rd_Gray;              // its Gray version (combinational)
  logic [PTR_W:0] r_Rd_Gray = '0;         // registered Gray copy: this one crosses to the write side

  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Wr_Gray_Sync1 = '0;   // write pointer arriving
  (* ASYNC_REG = "TRUE" *) logic [PTR_W:0] r_Wr_Gray_Sync2 = '0;   // from the write side

  logic w_Rd;
  assign w_Rd      = i_Rd_En && !o_Empty;                 // never read when empty
  assign w_Rd_Gray = r_Rd_Ptr ^ (r_Rd_Ptr >> 1);          // binary -> Gray

  always_ff @(posedge i_Rd_Clk) begin
    if (w_Rd)
      r_Rd_Ptr <= r_Rd_Ptr + 1'b1;                        // read = move the pointer
    r_Rd_Gray       <= w_Rd_Gray;                         // clean copy, before crossing
    r_Wr_Gray_Sync1 <= r_Wr_Gray;                         // synchronizer flop 1
    r_Wr_Gray_Sync2 <= r_Wr_Gray_Sync1;                   // synchronizer flop 2
  end

  // empty: the read pointer has caught up with the (synchronized) write pointer
  assign o_Empty   = (w_Rd_Gray == r_Wr_Gray_Sync2);
  assign o_Rd_Data = r_Mem[r_Rd_Ptr[PTR_W-1:0]];          // front byte, always visible

endmodule