// Hardware test for async_fifo on the Arty S7-25.
// Two independent oscillators on the board give two truly unrelated clocks:
//   write side: 100 MHz (pin R2)     read side: 12 MHz (pin F14)
// WRITER sends 0, 1, 2, 3 ... (8-bit, wraps) into the FIFO.
// READER checks every byte is the previous one + 1. Any mismatch -> error LED on, stays on.
// The writer alternates between FAST mode (FIFO mostly full) and SLOW mode (FIFO mostly empty),
// so both flags are exercised. BTN0 skips one number on purpose, to prove the checker works.
module async_top #(
  parameter int MODE_BIT = 26,   // write-mode switch: 2^26 / 100 MHz = 0.67 s per mode
  parameter int BEAT_BIT = 23,   // heartbeat:         2^23 / 12 MHz  = 0.7 s per half blink
  parameter int FLOW_BIT = 21    // data flowing:      toggles every 2^21 bytes read
)(
  input  logic       i_Clk_100,  // write clock
  input  logic       i_Clk_12,   // read clock
  input  logic       i_Btn0,     // press = inject one error
  output logic [3:0] o_Led       // 0 heartbeat, 1 error, 2 data flowing, 3 fast mode
);

  //FIFO connections
  logic       w_Wr_En, w_Full;
  logic [7:0] r_Wr_Data = '0;
  logic       w_Rd_En, w_Empty;
  logic [7:0] w_Rd_Data;

  async_fifo #(.WIDTH(8), .DEPTH(16)) FIFO_INST (
    .i_Wr_Clk  (i_Clk_100),
    .i_Wr_En   (w_Wr_En),
    .i_Wr_Data (r_Wr_Data),
    .o_Full    (w_Full),
    .i_Rd_Clk  (i_Clk_12),
    .i_Rd_En   (w_Rd_En),
    .o_Rd_Data (w_Rd_Data),
    .o_Empty   (w_Empty)
  );

  // =====================================================================
  // WRITE SIDE (100 MHz)
  // =====================================================================
  // button: comes from outside, no clock -> 2-flop synchronizer, then edge detect
  (* ASYNC_REG = "TRUE" *) logic r_Btn_Sync1 = 1'b0;
  (* ASYNC_REG = "TRUE" *) logic r_Btn_Sync2 = 1'b0;
  logic r_Btn_Prev = 1'b0;
  logic r_Inject   = 1'b0;                   // "skip one number at the next write"

  logic [15:0]       r_Lfsr_Wr  = 16'hACE1;  // pseudo-random bits
  logic [MODE_BIT:0] r_Mode_Cnt = '0;        // slow counter for the mode switch
  logic              w_Fast;
  logic              w_Wr;                   // a write is accepted this clock

  assign w_Fast  = r_Mode_Cnt[MODE_BIT];
  assign w_Wr_En = w_Fast ? 1'b1                        // FAST: try every clock (100 M/s)
                          : (r_Lfsr_Wr[4:0] == 5'd0);   // SLOW: 1 in 32 clocks (~3 M/s)
  assign w_Wr    = w_Wr_En && !w_Full;

  always_ff @(posedge i_Clk_100) begin
    r_Btn_Sync1 <= i_Btn0;
    r_Btn_Sync2 <= r_Btn_Sync1;
    r_Btn_Prev  <= r_Btn_Sync2;

    r_Lfsr_Wr  <= {r_Lfsr_Wr[14:0], r_Lfsr_Wr[15] ^ r_Lfsr_Wr[13] ^ r_Lfsr_Wr[12] ^ r_Lfsr_Wr[10]};
    r_Mode_Cnt <= r_Mode_Cnt + 1'b1;

    if (r_Btn_Sync2 && !r_Btn_Prev)          // button just pressed
      r_Inject <= 1'b1;

    if (w_Wr) begin                          // byte accepted -> prepare the next number
      if (r_Inject) begin
        r_Wr_Data <= r_Wr_Data + 8'd2;       // skip one number (deliberate error)
        r_Inject  <= 1'b0;
      end else
        r_Wr_Data <= r_Wr_Data + 8'd1;
    end
  end

  // =====================================================================
  // READ SIDE (12 MHz)
  // =====================================================================
  logic [15:0]       r_Lfsr_Rd   = 16'h1D2B;
  logic [7:0]        r_Expected  = '0;       // the number that should come next
  logic              r_Error     = 1'b0;     // sticky: once 1, stays 1
  logic [FLOW_BIT:0] r_Rd_Count  = '0;       // bytes read (for the "flowing" LED)
  logic [BEAT_BIT:0] r_Beat      = '0;       // free-running counter (heartbeat)
  logic              w_Rd;                   // a read is accepted this clock

  assign w_Rd_En = r_Lfsr_Rd[0];             // try to read on ~50% of clocks (~6 M/s)
  assign w_Rd    = w_Rd_En && !w_Empty;

  always_ff @(posedge i_Clk_12) begin
    r_Lfsr_Rd <= {r_Lfsr_Rd[14:0], r_Lfsr_Rd[15] ^ r_Lfsr_Rd[13] ^ r_Lfsr_Rd[12] ^ r_Lfsr_Rd[10]};
    r_Beat    <= r_Beat + 1'b1;

    if (w_Rd) begin
      if (w_Rd_Data != r_Expected)
        r_Error <= 1'b1;                     // wrong or missing number
      r_Expected <= w_Rd_Data + 8'd1;        // follow the data, so we keep checking after an error
      r_Rd_Count <= r_Rd_Count + 1'b1;
    end
  end

  //LEDs
  assign o_Led[0] = r_Beat[BEAT_BIT];        // blinks: the read side is alive
  assign o_Led[1] = r_Error;                 // must stay OFF
  assign o_Led[2] = r_Rd_Count[FLOW_BIT];    // blinks: bytes are getting through
  assign o_Led[3] = w_Fast;                  // on = fast mode (FIFO full), off = slow mode (FIFO empty)

endmodule