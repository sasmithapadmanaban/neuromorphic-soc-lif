# Configurable Multi-Core Neuromorphic SoC with LIF Neurons

## Overview

This project implements a configurable, multi-core neuromorphic System-on-Chip (SoC) using synthesizable Verilog RTL.

The architecture integrates sensor delta encoding, spiking-neuron processing based on leaky integrate-and-fire (LIF) dynamics, configurable neural parameters, temporal traces, and learning-controlled synaptic weight updates.

The design is intended for exploration of neuromorphic hardware architecture, RTL design, functional verification, and digital VLSI implementation.

## Key Features

- Parameterized multi-core neural-processing architecture.
- Leaky integrate-and-fire (LIF) neuron processing.
- Configurable membrane threshold and decay.
- Sensor delta encoding for change-sensitive spike generation.
- Signed synaptic weight storage.
- Pre-synaptic and post-synaptic temporal traces.
- Learning enable control and conditional weight updates.
- AXI-style memory-mapped configuration interface.
- Dedicated inference interrupt output.
- Verilog testbench for system-level simulation.

## Architecture

The design consists of two primary RTL modules.

### 1. Neuromorphic SoC Top

The top-level module integrates the sensor input interface, delta encoder, configuration registers, multi-core interconnect, and inference interrupt logic.

### 2. Neuromorphic Core Backend

Each backend instance contains a parameterized array of LIF neurons, a synaptic weight matrix, membrane potential state, temporal traces, and learning-controlled weight updates.

## Default Configuration

| Parameter | Default value |
|---|---:|
| Number of cores | 2 |
| Inputs per core | 8 |
| Neurons per core | 8 |
| Synaptic weight width | 8 bits |
| Membrane potential width | 16 bits |
| AXI data width | 32 bits |
| AXI address width | 12 bits |

These values are the RTL defaults and may be changed through the module parameters where supported.

## Configuration Registers

| Address | Register | Reset value |
|---|---|---|
| `0x000` | Membrane threshold | `0x0250` |
| `0x004` | Membrane decay | `0x0003` |
| `0x008` | Learning enable | `1` |
| `0x00C` | Sensor encoder threshold | `0x1F` |

## Repository Structure

- `rtl/` — Synthesizable Verilog modules.
- `testbench/` — Simulation testbench and verification code.
- `constraints/` — Timing constraints.
- `synthesis/` — Synthesis scripts and instructions.
- `physical_design/` — Physical-design scripts and documentation.
- `reports/` — Generated synthesis, timing, area, and power reports.
- `docs/` — Architecture, register map, and verification documentation.

## Tools

The RTL can be evaluated using a compatible Verilog simulator and synthesis tool.

Cadence Genus and Innovus can be used for synthesis and physical-design exploration when the required tools, technology libraries, and design constraints are available.

## Verification Status

The repository includes a Verilog testbench intended to exercise reset, configuration writes, and sensor-input activity.

Functional verification, protocol compliance, synthesis, timing closure, and physical-design results should be documented after the corresponding checks have been performed.

## Future Improvements

- Strengthen AXI4-Lite transaction handling and protocol verification.
- Add self-checking testbenches for sensor encoding and LIF behaviour.
- Define and validate the intended synaptic learning rule.
- Evaluate memory inference and implementation cost.
- Add synthesis area, timing, and power measurements.
- Explore architectural and low-power optimizations.


