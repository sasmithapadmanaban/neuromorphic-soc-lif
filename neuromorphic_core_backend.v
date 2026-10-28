
// =========================================================================================
// Module: neuromorphic_core_backend
// Description: Complete LIF Array with local Named Verification Blocks.
// =========================================================================================

module neuromorphic_core_backend #(
    parameter NUM_INPUTS     = 8,
    parameter NUM_NEURONS    = 8,
    parameter WEIGHT_W       = 8,
    parameter MEMBRANE_W     = 16
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire [NUM_INPUTS-1:0]   pre_spikes,
    output reg  [NUM_NEURONS-1:0]  post_spikes,
    input  wire [MEMBRANE_W-1:0]   cfg_threshold,
    input  wire [MEMBRANE_W-1:0]   cfg_decay,
    input  wire                    cfg_learning_en
);

    reg signed [WEIGHT_W-1:0]     synaptic_matrix_sram [0:NUM_INPUTS-1][0:NUM_NEURONS-1];
    reg signed [MEMBRANE_W-1:0]   membrane_potentials  [0:NUM_NEURONS-1];
    reg [7:0]                     pre_time_traces      [0:NUM_INPUTS-1];
    reg [7:0]                     post_time_traces     [0:NUM_NEURONS-1];

    wire inhibition_active;
    assign inhibition_active = |post_spikes;

    integer n, s, i_init, j_init;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            post_spikes <= {NUM_NEURONS{1'b0}};
            for (i_init = 0; i_init < NUM_NEURONS; i_init = i_init + 1) begin
                membrane_potentials[i_init] <= {MEMBRANE_W{1'b0}};
            end
        end else begin
            for (n = 0; n < NUM_NEURONS; n = n + 1) begin : lif_execution_block
                reg signed [MEMBRANE_W-1:0] integration_accumulator;
                integration_accumulator = membrane_potentials[n];

                for (s = 0; s < NUM_INPUTS; s = s + 1) begin
                    if (pre_spikes[s]) begin
                        integration_accumulator = integration_accumulator + 
                            $signed({{(MEMBRANE_W-WEIGHT_W){synaptic_matrix_sram[s][n][WEIGHT_W-1]}}, synaptic_matrix_sram[s][n]});
                    end
                end

                if (integration_accumulator > 0) begin
                    integration_accumulator = integration_accumulator - $signed({1'b0, cfg_decay});
                    if (integration_accumulator < 0) begin
                        integration_accumulator = {MEMBRANE_W{1'b0}};
                    end
                end

                if (inhibition_active && !post_spikes[n]) begin
                    integration_accumulator = integration_accumulator >>> 2; 
                end

                if (integration_accumulator >= $signed({1'b0, cfg_threshold})) begin
                    post_spikes[n]         <= 1'b1;
                    membrane_potentials[n] <= {MEMBRANE_W{1'b0}};
                end else begin
                    post_spikes[n]         <= 1'b0;
                    membrane_potentials[n] <= integration_accumulator;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i_init = 0; i_init < NUM_INPUTS; i_init = i_init + 1) begin
                pre_time_traces[i_init] <= 8'h00;
                for (j_init = 0; j_init < NUM_NEURONS; j_init = j_init + 1) begin
                    synaptic_matrix_sram[i_init][j_init] <= 8'sd24; 
                end
            end
            for (j_init = 0; j_init < NUM_NEURONS; j_init = j_init + 1) begin
                post_time_traces[j_init] <= 8'h00;
            end
        end else begin
            for (s = 0; s < NUM_INPUTS; s = s + 1) begin
                if (pre_spikes[s]) begin
                    pre_time_traces[s] <= 8'hFF;
                end else if (pre_time_traces[s] > 0) begin
                    pre_time_traces[s] <= pre_time_traces[s] - 1'b1;
                end
            end

            for (n = 0; n < NUM_NEURONS; n = n + 1) begin
                if (post_spikes[n]) begin
                    post_time_traces[n] <= 8'hFF;
                end else if (post_time_traces[n] > 0) begin
                    post_time_traces[n] <= post_time_traces[n] - 1'b1;
                end
            end

            if (cfg_learning_en) begin
                for (s = 0; s < NUM_INPUTS; s = s + 1) begin
                    for (n = 0; n < NUM_NEURONS; n = n + 1) begin
                        if (post_spikes[n] && (pre_time_traces[s] > 8'h00)) begin
                            if (synaptic_matrix_sram[s][n] < 8'sd127) begin
                                synaptic_matrix_sram[s][n] <= synaptic_matrix_sram[s][n] + 8'sd2;
                            end
                        end
                        if (pre_spikes[s] && (post_time_traces[n] > 8'h00)) begin
                            if (synaptic_matrix_sram[s][n] > -8'sd128) begin
                                synaptic_matrix_sram[s][n] <= synaptic_matrix_sram[s][n] - 8'sd1;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule
