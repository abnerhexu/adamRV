# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A microprocessor architecture course project implementing a **5-stage pipelined RV32I processor** in Verilog, with the goal of extending it to a **9-stage scoreboard-based out-of-order execution pipeline** (IF → IS → RO → EX1 → EX2 → EX3 → EX4 → MEM → WB). Simulation uses Verilator.

## Build & Run

All commands run from `RVDesign/`:

```bash
# Full build + simulate + waveform viewer (verilate → compile → run → coverage → gtkwave)
make run

# Clean build artifacts
make clean

# Show Verilator config
make show-config
```

The build produces `obj_dir/Vadam_riscv` which runs simulation for up to 100,000 ns with VCD trace output to `logs/wave.vcd`.

### Converting Test Programs to Hex

Assembly to hex (from `RVDesign/test_program/assembleProgram2hex/`):
```bash
# Edit test.s, then:
bash S2hex.sh
# Output: AdamRiscv/rom/test_program.hex
```

C to hex (from `RVDesign/test_program/CProgram2hex/`):
```bash
bash C2hex.sh
```

Both require the `riscv64-unknown-elf` cross-compilation toolchain.

## Architecture

### Baseline 5-Stage Pipeline (`RVDesign/AdamRiscv/`)

- `adam_riscv.v` — Top-level module wiring all stages together
- `stage_if.v` / `stage_id.v` / `stage_ex.v` / `stage_mem.v` / `stage_wb.v` — Pipeline stages
- `reg_if_id.v` / `reg_id_ex.v` / `reg_ex_mem.v` / `reg_mem_wb.v` — Pipeline registers between stages
- `forwarding.v` — Data forwarding (to be removed in scoreboard design)
- `hazard_detection.v` — Load-use stall and branch flush detection
- `ctrl.v` — Control signal generation from opcode
- `alu.v` / `alu_control.v` — ALU and its control logic
- `regs.v` — 32x32-bit register file
- `inst_memory.v` — Instruction ROM (loads from `rom/test_program.hex`)
- `data_memory.v` — Data RAM
- `define.vh` — Shared macro definitions (opcodes, ALU ops, field widths)

### Scoreboard Extension (Task 2 target)

The ID stage splits into IS (Issue) + RO (Read Operands). EX expands to 4 cycles. Two new data structures:

- **Result Register Status Table** — 32 entries, 3-bit FU field per register indicating which functional unit will produce the result (0=ready, 1=ADD, 2=SUB, 3=AND, 4=OR, 5=XOR, 6=LW)
- **Functional Unit Status Table** — 7 entries tracking ADD, SUB, AND, OR, XOR, LW, SW units (indexed 1–7)

Key design rules:
- No data forwarding — instructions always read from register file after writeback
- ADDI/LUI/AUIPC use the ADD functional unit (index 1)
- No branch instructions in test cases — branch logic modifications optional
- WAR hazards won't occur in test cases — write-back stall check optional
- When multiple instructions have ready operands, any selection policy is acceptable

### Simulation Harness

- `adam_riscv_main.cpp` — C++ testbench: 10ns clock period (posedge at +1ns, negedge at +6ns), reset deasserted after 1000ns (100 cycles)
- `tb.v` — Verilog testbench (alternative)

## Supported Instructions

R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
I-type: ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI, LW, JALR
S-type: SW, SB, SH
B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
U-type: LUI, AUIPC
J-type: JAL
