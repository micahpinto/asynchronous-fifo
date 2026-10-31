`timescale 1ns/1ps

// Testbench for async_fifo: two unrelated clocks.
// A writer process and a reader process run at the same time, each on its own clock.
// A reference model (a queue) holds what the FIFO SHOULD contain; every byte the
// reader takes is compared with the model. The test runs at three clock ratios.
module async_fifo_tb;

  localparam int WIDTH   = 8;
  localparam int DEPTH   = 8;        // small, so full happens often
  localparam int N_BYTES = 2000;     // bytes per phase

  //two clocks, with periods we can change during the test
  real wr_half = 5.0;                // write clock: half period in ns
  real rd_half = 5.0;                // read clock:  half period in ns
  logic wr_clk = 0, rd_clk = 0;
  always #(wr_half) wr_clk = ~wr_clk;
  always #(rd_half) rd_clk = ~rd_clk;

  // FIFO signals
  logic             wr_en = 0, rd_en = 0;
  logic [WIDTH-1:0] wr_data = '0;
  logic [WIDTH-1:0] rd_data;
  logic             full, empty;

  async_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) DUT (
    .i_Wr_Clk  (wr_clk),
    .i_Wr_En   (wr_en),
    .i_Wr_Data (wr_data),
    .o_Full    (full),
    .i_Rd_Clk  (rd_clk),
    .i_Rd_En   (rd_en),
    .o_Rd_Data (rd_data),
    .o_Empty   (empty)
  );

  // reference model and counters 
  logic [WIDTH-1:0] model [$];       // what the FIFO should contain, oldest first
  int errors = 0;
  int n_full = 0, n_empty = 0;       // clocks where the flag was 1 (coverage), to count number of fulls and emptys

  // writer: runs on the write clock 
  task automatic writer(int n, int p_wr);
    int written = 0;
    while (written < n) begin
      @(negedge wr_clk);
      if (full) n_full++;
      // safety check: if the FIFO says "not full", there must really be room
      if (!full && model.size() >= DEPTH) begin
        $display("%0t: full = 0 but the FIFO already holds %0d bytes", $time, model.size());
        errors++;
      end
      wr_en   = ($urandom_range(0, 99) < p_wr);   // write with probability p_wr %
      wr_data = $urandom_range(0, 255);
      if (wr_en && !full) begin                   // this write will be accepted
        model.push_back(wr_data);
        written++;
      end
    end
    @(negedge wr_clk);
    wr_en = 0;
  endtask

  //reader: runs on the read clock
  task automatic reader(int n, int p_rd);
    int got = 0;
    while (got < n) begin
      @(negedge rd_clk);
      if (empty) n_empty++;
      // safety check: if the FIFO says "not empty", there must really be data
      if (!empty && model.size() == 0) begin
        $display("%0t: empty = 0 but the FIFO holds no data", $time);
        errors++;
      end
      rd_en = ($urandom_range(0, 99) < p_rd);     // read with probability p_rd %
      if (rd_en && !empty) begin                  // this read will be accepted
        if (rd_data !== model[0]) begin
          $display("%0t: read %h, expected %h", $time, rd_data, model[0]);
          errors++;
        end
        void'(model.pop_front());
        got++;
      end
    end
    @(negedge rd_clk);
    rd_en = 0;
  endtask

  //one phase: set the clocks, then write and read at the same time
  task automatic run_phase(string name, real wr_period, real rd_period);
    int err_before = errors;
    wr_half = wr_period / 2.0;
    rd_half = rd_period / 2.0;
    fork                                          // both run at the same time
      writer(N_BYTES, 70);
      reader(N_BYTES, 70);
    join                                          // wait until both are finished
    if (model.size() != 0) begin
      $display("%s: %0d bytes left in the model", name, model.size());
      errors++;
    end
    $display("%-34s write %5.1f ns, read %5.1f ns: %0d bytes, %0d errors",
             name, wr_period, rd_period, N_BYTES, errors - err_before);
  endtask

  initial begin
    run_phase("Phase 1: writer faster (fills up)", 10.0, 37.0);
    run_phase("Phase 2: reader faster (drains)",   37.0, 10.0);
    run_phase("Phase 3: almost the same speed",    10.0, 10.7);

    $display("----------------------------------");
    $display("Clocks with full = 1: %0d, clocks with empty = 1: %0d", n_full, n_empty);
    if (errors == 0) $display("TEST PASSED: 0 errors");
    else             $display("TEST FAILED: %0d errors", errors);
    $display("----------------------------------");
    $finish;
  end

  //watchdog: if bytes get lost, the reader would wait forever
  initial begin
    #10ms;
    $display("TIMEOUT: the test did not finish (bytes lost?)");
    $finish;
  end

endmodule