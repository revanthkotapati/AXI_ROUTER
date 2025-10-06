`timescale 1ns/1ps

module tb_axi_stream_router;

 

  // 1. Port List
  logic clk;
  logic reset;

  logic s_tvalid;
  logic [9:0] s_tdata;
  logic s_tready;

  logic config_tvalid;
  logic [23:0] config_tdata;  // {port0_count, port1_count, port2_count}
  logic config_tready;

  logic m0_tvalid, m1_tvalid, m2_tvalid;
  logic [9:0] m0_tdata, m1_tdata, m2_tdata;
  logic m0_tready, m1_tready, m2_tready;

  // 2. Internal Variables
  int cfg_fd, input_fd, expected0_fd, expected1_fd, expected2_fd;
  logic [7:0] port0_count, port1_count, port2_count;
  logic [9:0] s_val, exp0, exp1, exp2;
  int wait_n;

  // 3. File Paths
  localparam string CONFIG_FILE   = "router_config.csv";
  localparam string INPUT_FILE    = "router_input.csv";
  localparam string EXP_M0_FILE   = "expected_m0.csv";
  localparam string EXP_M1_FILE   = "expected_m1.csv";
  localparam string EXP_M2_FILE   = "expected_m2.csv";

  // 4. DUT Instantiation
  axi_stream_router DUT (
    .clk(clk), .rst(reset),
    .s_tvalid(s_tvalid), .s_tdata(s_tdata), .s_tready(s_tready),
    .config_tvalid(config_tvalid), .config_tdata(config_tdata), .config_tready(config_tready),
    .m0_tvalid(m0_tvalid), .m0_tdata(m0_tdata), .m0_tready(m0_tready),
    .m1_tvalid(m1_tvalid), .m1_tdata(m1_tdata), .m1_tready(m1_tready),
    .m2_tvalid(m2_tvalid), .m2_tdata(m2_tdata), .m2_tready(m2_tready)
  );

  // 5. Clock Generation
  always #5 clk = ~clk;

  // 6. Reset Task
  task automatic reset_task;
  begin
    reset <= 1;
    repeat(5) @(posedge clk);
    reset <= 0;
    $display("INFO: Reset done.");
  end
  endtask

  // 7. Main Initial Block
  initial begin
    clk = 0;
    reset = 0;
    s_tvalid = 0;
    s_tdata = 0;
    config_tvalid = 0;
    config_tdata = 0;
    m0_tready = 1;
    m1_tready = 1;
    m2_tready = 1;

    repeat(3) @(posedge clk);
    reset_task();

    fork
      send_config(CONFIG_FILE);
      send_input(INPUT_FILE, 2);
      begin
      repeat(100) @(posedge clk);
      check_output(EXP_M0_FILE, EXP_M1_FILE, EXP_M2_FILE, 3);
      end
    join

    $display("TESTBENCH: Completed.");
    #100;
    $finish;
  end

  // 8. Send Configuration (no struct)
  task automatic send_config(input string file);
    int val0, val1, val2;
  begin
    cfg_fd = $fopen(file, "r");
    if (cfg_fd == 0) $fatal("ERROR: Cannot open config file.");

    $fscanf(cfg_fd, "%d\n", val0);
    $fscanf(cfg_fd, "%d\n", val1);
    $fscanf(cfg_fd, "%d\n", val2);

    port0_count = val0[7:0];
    port1_count = val1[7:0];
    port2_count = val2[7:0];

    config_tdata = {port0_count, port1_count, port2_count};
    config_tvalid = 1;

    @(posedge clk);
    while (!config_tready) @(posedge clk);
    config_tvalid = 0;
    $fclose(cfg_fd);

    $display("CONFIG SENT: p0=%0d, p1=%0d, p2=%0d", port0_count, port1_count, port2_count);
  end
  endtask

  // 9. Send AXI-Stream Input Data
  task automatic send_input(input string file, input int throttle);
  begin
    input_fd = $fopen(file, "r");
    if (input_fd == 0) $fatal("ERROR: Cannot open input file.");

    while ($fscanf(input_fd, "%h\n", s_val) == 1) begin
      s_tvalid <= 1;
      s_tdata <= s_val;
      @(posedge clk);
      while (!s_tready) @(posedge clk);
      s_tvalid <= 0;
     // s_tdata <= 0;

      wait_n = $urandom % throttle;
      repeat (wait_n) @(posedge clk);
    end

    $fclose(input_fd);
    $display("INFO: Input data sent.");
  end
  endtask

  // 10. Output Checker
  task automatic check_output(input string f0, input string f1, input string f2, input int throttle);
  begin
    expected0_fd = $fopen(f0, "r");
    expected1_fd = $fopen(f1, "r");
    expected2_fd = $fopen(f2, "r");
    if (!expected0_fd || !expected1_fd || !expected2_fd)
      $fatal("ERROR: Could not open one or more expected output files.");

    forever begin
      @(posedge clk);

      if (m0_tvalid && m0_tready) begin
        $fscanf(expected0_fd, "%h\n", exp0);
        if (m0_tdata !== exp0)
          $fatal("FAIL @M0: Got %h, Expected %h", m0_tdata, exp0);
        else
          $display("PASS @M0: %h", m0_tdata);
      end

      if (m1_tvalid && m1_tready) begin
        $fscanf(expected1_fd, "%h\n", exp1);
        if (m1_tdata !== exp1)
          $fatal("FAIL @M1: Got %h, Expected %h", m1_tdata, exp1);
        else
          $display("PASS @M1: %h", m1_tdata);
      end

      if (m2_tvalid && m2_tready) begin
        $fscanf(expected2_fd, "%h\n", exp2);
        if (m2_tdata !== exp2)
          $fatal("FAIL @M2: Got %h, Expected %h", m2_tdata, exp2);
        else
          $display("PASS @M2: %h", m2_tdata);
      end

      wait_n = $urandom % throttle;
      repeat(wait_n) @(posedge clk);
    end
  end
  endtask

endmodule
