
// =========================================================================================
// Module: neuromorphic_soc_top
// Description: Synthesizable Multi-core Neuromorphic SoC with explicit block names
//              and proper timescale headers for clean Cadence elaboration.
// =========================================================================================

module neuromorphic_soc_top #(
    parameter AXI_DATA_W      = 32,
    parameter AXI_ADDR_W      = 12,
    parameter NUM_CORES       = 2,
    parameter INPUTS_PER_CORE = 8,
    parameter NEURONS_PER_CORE= 8,
    parameter WEIGHT_W        = 8,
    parameter MEMBRANE_W      = 16
)(
    input  wire                              clk,
    input  wire                              rst_n,

    // AXI4-Lite Interface
    input  wire [AXI_ADDR_W-1:0]             s_axi_awaddr,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,
    input  wire [AXI_DATA_W-1:0]             s_axi_wdata,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,
    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,
    input  wire [AXI_ADDR_W-1:0]             s_axi_araddr,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,
    output reg  [AXI_DATA_W-1:0]             s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    // Raw Edge Interface
    input  wire [(INPUTS_PER_CORE*8)-1:0]    edge_sensor_data_flat,
    input  wire                              sensor_data_valid,

    output reg                               inference_interrupt
);

    // Configuration Registers
    reg [MEMBRANE_W-1:0] cfg_threshold;
    reg [MEMBRANE_W-1:0] cfg_decay;
    reg                  cfg_learning_en;
    reg [7:0]            cfg_encoder_threshold;

    // Internal Nets
    reg  [INPUTS_PER_CORE-1:0] encoded_spikes;
    wire [NEURONS_PER_CORE-1:0] core_out_spikes [0:NUM_CORES-1];
    wire [INPUTS_PER_CORE-1:0]  core_pre_spikes [0:NUM_CORES-1];

    // Write FSM States
    localparam AXI_WR_IDLE       = 2'b00;
    localparam AXI_WR_DATA_PHASE = 2'b01;
    localparam AXI_WR_RESP_PHASE = 2'b10;
    reg [1:0] wr_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready         <= 1'b0;
            s_axi_wready          <= 1'b0;
            s_axi_bvalid          <= 1'b0;
            s_axi_bresp           <= 2'b00;
            cfg_threshold         <= 16'h0250;
            cfg_decay             <= 16'h0003;
            cfg_learning_en       <= 1'b1;
            cfg_encoder_threshold <= 8'h1F;
            wr_state              <= AXI_WR_IDLE;
        end else begin
            case (wr_state)
                AXI_WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        wr_state      <= AXI_WR_DATA_PHASE;
                    end
                end
                AXI_WR_DATA_PHASE: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b0;
                    case (s_axi_awaddr)
                        12'h000: cfg_threshold         <= s_axi_wdata[MEMBRANE_W-1:0];
                        12'h004: cfg_decay             <= s_axi_wdata[MEMBRANE_W-1:0];
                        12'h008: cfg_learning_en       <= s_axi_wdata[0];
                        12'h00C: cfg_encoder_threshold <= s_axi_wdata[7:0];
                    endcase
                    s_axi_bvalid <= 1'b1;
                    wr_state     <= AXI_WR_RESP_PHASE;
                end
                AXI_WR_RESP_PHASE: begin
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= AXI_WR_IDLE;
                    end
                end
                default: wr_state <= AXI_WR_IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= {AXI_DATA_W{1'b0}};
            s_axi_rresp   <= 2'b00;
        end else begin
            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                case (s_axi_araddr)
                    12'h000: s_axi_rdata <= {{(AXI_DATA_W-MEMBRANE_W){1'b0}}, cfg_threshold};
                    12'h004: s_axi_rdata <= {{(AXI_DATA_W-MEMBRANE_W){1'b0}}, cfg_decay};
                    12'h008: s_axi_rdata <= {{(AXI_DATA_W-1){1'b0}}, cfg_learning_en};
                    12'h00C: s_axi_rdata <= {{(AXI_DATA_W-8){1'b0}}, cfg_encoder_threshold};
                    default: s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rready && s_axi_rvalid) begin
                    s_axi_rvalid <= 1'b0;
                end
            end
        end
    end

    // Sensory Encoder Matrix
    generate
        genvar s;
        for (s = 0; s < INPUTS_PER_CORE; s = s + 1) begin : gen_delta_encoders
            reg [7:0] prev_sensor_val;
            wire [7:0] current_sensor_val;
            
            assign current_sensor_val = edge_sensor_data_flat[(s*8)+:8];

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    prev_sensor_val   <= 8'h00;
                    encoded_spikes[s] <= 1'b0;
                end else if (sensor_data_valid) begin : delta_proc_block
                    // Named block fixes the Verilog block scope issue completely
                    integer diff;
                    diff = current_sensor_val - prev_sensor_val;
                    if (diff >= cfg_encoder_threshold || diff <= -cfg_encoder_threshold) begin
                        encoded_spikes[s] <= 1'b1;
                        prev_sensor_val   <= current_sensor_val;
                    end else begin
                        encoded_spikes[s] <= 1'b0;
                    end
                end else begin
                    encoded_spikes[s] <= 1'b0;
                end
            end
        end
    endgenerate

    // Interconnect Mesh
    generate
        genvar route_idx;
        for (route_idx = 0; route_idx < NUM_CORES; route_idx = route_idx + 1) begin : gen_routing
            assign core_pre_spikes[route_idx] = encoded_spikes;
        end
    endgenerate

    always @* begin
        inference_interrupt = core_out_spikes[NUM_CORES-1][0];
    end

    // Compute Elements
    generate
        genvar k;
        for (k = 0; k < NUM_CORES; k = k + 1) begin : gen_cores
            neuromorphic_core_backend #(
                .NUM_INPUTS(INPUTS_PER_CORE),
                .NUM_NEURONS(NEURONS_PER_CORE),
                .WEIGHT_W(WEIGHT_W),
                .MEMBRANE_W(MEMBRANE_W)
            ) core_inst (
                .clk(clk),
                .rst_n(rst_n),
                .pre_spikes(core_pre_spikes[k]),
                .post_spikes(core_out_spikes[k]),
                .cfg_threshold(cfg_threshold),
                .cfg_decay(cfg_decay),
                .cfg_learning_en(cfg_learning_en)
            );
        end
    endgenerate

endmodule
