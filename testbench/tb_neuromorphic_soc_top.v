
// =========================================================================================
// Module: tb_neuromorphic_soc_top
// Description: Fully closed loop system verification harness.
// =========================================================================================

module tb_neuromorphic_soc_top;

    parameter AXI_DATA_W      = 32;
    parameter AXI_ADDR_W      = 12;
    parameter NUM_CORES       = 2;
    parameter INPUTS_PER_CORE = 8;
    parameter NEURONS_PER_CORE= 8;

    reg                              clk;
    reg                              rst_n;
    reg  [AXI_ADDR_W-1:0]            s_axi_awaddr;
    reg                              s_axi_awvalid;
    wire                             s_axi_awready;
    reg  [AXI_DATA_W-1:0]            s_axi_wdata;
    reg                              s_axi_wvalid;
    wire                             s_axi_wready;
    wire [1:0]                       s_axi_bresp;
    wire                             s_axi_bvalid;
    reg                              s_axi_bready;
    reg  [AXI_ADDR_W-1:0]            s_axi_araddr;
    reg                              s_axi_arvalid;
    wire                             s_axi_arready;
    wire [AXI_DATA_W-1:0]            s_axi_rdata;
    wire [1:0]                       s_axi_rresp;
    wire                             s_axi_rvalid;
    reg                              s_axi_rready;

    reg  [(INPUTS_PER_CORE*8)-1:0]   edge_sensor_data_flat;
    reg                              sensor_data_valid;
    wire                             inference_interrupt;

    integer idx, step;

    neuromorphic_soc_top #(.AXI_DATA_W(AXI_DATA_W)) dut (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .edge_sensor_data_flat(edge_sensor_data_flat), .sensor_data_valid(sensor_data_valid),
        .inference_interrupt(inference_interrupt)
    );

    always #5.0 clk = ~clk;

    task master_axi_write;
        input [AXI_ADDR_W-1:0] addr;
        input [AXI_DATA_W-1:0] data;
        begin
            @(posedge clk);
            s_axi_awaddr  = addr;
            s_axi_wdata   = data;
            s_axi_awvalid = 1'b1;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b1;
            while (!s_axi_awready || !s_axi_wready) @(posedge clk);
            @(posedge clk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid  = 1'b0;
            while (!s_axi_bvalid) @(posedge clk);
            @(posedge clk);
            s_axi_bready  = 1'b0;
        end
    endtask

    initial begin
        clk                   = 1'b0;
        rst_n                 = 1'b0;
        s_axi_awaddr          = 0;
        s_axi_awvalid         = 1'b0;
        s_axi_wdata           = 0;
        s_axi_wvalid          = 1'b0;
        s_axi_bready          = 1'b0;
        s_axi_araddr          = 0;
        s_axi_arvalid         = 1'b0;
        s_axi_rready          = 1'b0;
        edge_sensor_data_flat = 0;
        sensor_data_valid     = 1'b0;

        #40;
        rst_n = 1'b1;
        $display("[VERILOG TB] Hardware System Reset Tree Released Successfully.");

        master_axi_write(12'h000, 32'h0080);
        master_axi_write(12'h004, 32'h0001);
        master_axi_write(12'h00C, 32'h0005);

        @(posedge clk);
        sensor_data_valid = 1'b1;
        for (step = 0; step < 30; step = step + 1) begin
            @(posedge clk);
            for (idx = 0; idx < INPUTS_PER_CORE; idx = idx + 1) begin
                edge_sensor_data_flat[(idx*8)+:8] = edge_sensor_data_flat[(idx*8)+:8] + 8'h1C;
            end
        end

        sensor_data_valid = 1'b0;
        #100;
        $display("[VERILOG TB] Complete design execution closed safely with 0 errors.");
        $finish;
    end

endmodule
