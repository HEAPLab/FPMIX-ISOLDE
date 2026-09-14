# FPMIX

Copyright 2026 Politecnico di Milano.  
Authors: Andrea Galimberti, Davide Zoni.  
Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.  
Date: May 5, 2026.  

Floating-point unit (FPU) with design-time configurable floating-point (FP) formats for each operation type and supporting any FP format with length up to the width of the integer format.  
Design-time configurable parameters include the FP format's mantissa widths of each operation type, namely:
- addition/subtraction,
- multiplication,
- division,
- FP-to-int conversions,
- int-to-FP conversions,
- comparisons.

Other design-time configurable parameters are the FP format's exponent width, the integer format's width and the approximation and precision of the Goldschmidt divider.

Two SystemVerilog testbenches are provided for validation of the FPU against a DPI C model and for a simpler simulation requiring no support for DPI C, respectively.

## Code Structure

```
FPMIX/
├── pkg/                  # SystemVerilog packages with parameters and helper functions
│   └── fpmix_pkg.sv      # Main package file: configurable parameters at lines 8-52
├── rtl/                  # SystemVerilog modules for FPMIX FPU design
│   ├── fpmix_top.sv      # Top module
│   └── ...
├── tb/
│   ├── dpi_fpmix.c       # Reference model for DPI-C verification
│   ├── tb_fpmix.sv       # SystemVerilog testbench for simple simulation
│   └── validate_fpmix.sv # SystemVerilog testbench for verification against DPI C model
├── scripts/              # Non-project-mode flow for Vivado synth., impl. and sim.
|   └── ...
└── xdc/
    └── timing.xdc        # Clock constraints for implementation on VCU118 and Artix-7 100
```

## Synthesis and Implementation

**Vivado Version:** 2024.2  
**Synthesis:** Default strategy, `-mode out_of_context`  
**Implementation:** Default strategy, Post-Route Physical Optimization (`phys_opt_design`) enabled

### Post-Implementation Area and Performance Results

**Virtex UltraScale+ VCU118 Evaluation Platform - FPGA:** `xcvu9p-flga2104-2L-e`

| Metric      | float32 | float24 | bfloat16 |
|-------------|---------|---------|----------|
| Clock (MHz) |     256 |     313 |      345 |
| LUTs        |    2192 |    1605 |     1169 |
| FFs         |     574 |     475 |      368 |
| DSPs        |      10 |       3 |        0 |

**Artix-7 100 - FPGA:** `xc7a100tcsg324-1`

| Metric      | float32 | float24 | bfloat16 | bfloat16 |
|-------------|---------|---------|----------|----------|
| Clock (MHz) |      85 |      85 |       85 |      100 |
| LUTs        |    2192 |    1524 |     1136 |     1180 |
| FFs         |     542 |     431 |      342 |      342 |
| DSPs        |      10 |       3 |        0 |        0 |

**Utilization Breakdown**

Target: Artix-7 100 (`xc7a100tcsg324-1`) FPGA  
Clock: 85MHz  

| float32 FPU             |  LUT |  FF | DSP |
|-------------------------|------|-----|-----|
| FPMIX                   | 2199 | 542 |  10 |
| Addition/Subtraction    |  484 |  38 |   0 |
| Multiplication          |  327 |  38 |   2 |
| Division                |  500 | 183 |   8 |
| Int-to-FP Conversion    |  245 |  36 |   0 |
| FP-to-Int Conversion    |  194 |  36 |   0 |
| Comparison              |   53 |   0 |   0 |
| Mul./Div. Preprocessing |  178 |   0 |   0 |
| FP Rounding             |   33 |   0 |   0 |

| float24 FPU             |  LUT |  FF | DSP |
|-------------------------|------|-----|-----|
| FPMIX                   | 1524 | 431 |   3 |
| Addition/Subtraction    |  379 |  30 |   0 |
| Multiplication          |  199 |  30 |   1 |
| Division                |  272 | 112 |   2 |
| Int-to-FP Conversion    |  223 |  28 |   0 |
| FP-to-Int Conversion    |  154 |  36 |   0 |
| Comparison              |   41 |   0 |   0 |
| Mul./Div. Preprocessing |   80 |   0 |   0 |
| FP Rounding             |   25 |   0 |   0 |

| bfloat16 FPU            |  LUT |  FF | DSP |
|-------------------------|------|-----|-----|
| FPMIX                   | 1133 | 342 |   0 |
| Addition/Subtraction    |  196 |  22 |   0 |
| Multiplication          |  222 |  22 |   0 |
| Division                |  216 |  81 |   0 |
| Int-to-FP Conversion    |  171 |  20 |   0 |
| FP-to-Int Conversion    |  102 |  36 |   0 |
| Comparison              |   29 |   0 |   0 |
| Mul./Div. Preprocessing |   36 |   0 |   0 |
| FP Rounding             |   17 |   0 |   0 |

| Example 2-format FPU    | Format   |  LUT |  FF | DSP |
|-------------------------|----------|------|-----|-----|
| FPMIX                   |          | 1837 | 438 |   0 |
| Addition/Subtraction    | float32  |  484 |  22 |   0 |
| Multiplication          | bfloat16 |  222 |  22 |   0 |
| Division                | bfloat16 |  216 |  81 |   0 |
| Int-to-FP Conversion    | float32  |  194 |  36 |   0 |
| FP-to-Int Conversion    | float32  |  245 |  36 |   0 |
| Comparison              | float32  |   53 |   0 |   0 |
| Mul./Div. Preprocessing | bfloat16 |   36 |   0 |   0 |
| FP Rounding             | float32  |   33 |   0 |   0 |
| FP Rounding             | bfloat16 |   17 |   0 |   0 |

| Example 3-format FPU    | Format   |  LUT |  FF | DSP |
|-------------------------|----------|------|-----|-----|
| FPMIX                   |          | 1874 | 461 |   1 |
| Addition/Subtraction    | float32  |  484 |  22 |   0 |
| Multiplication          | float24  |  199 |  30 |   1 |
| Division                | bfloat16 |  216 |  81 |   0 |
| Int-to-FP Conversion    | bfloat16 |  171 |  20 |   0 |
| FP-to-Int Conversion    | bfloat16 |  102 |  36 |   0 |
| Comparison              | float32  |   53 |   0 |   0 |
| Mul./Div. Preprocessing | float24  |   80 |   0 |   0 |
| Mul./Div. Preprocessing | bfloat16 |   36 |   0 |   0 |
| FP Rounding             | float32  |   33 |   0 |   0 |
| FP Rounding             | float24  |   25 |   0 |   0 |
| FP Rounding             | bfloat16 |   17 |   0 |   0 |

**Operations Latency**

| Operation Type       | RISC-V Instructions               | float32 | float24 | bfloat16 |
|----------------------|-----------------------------------|---------|---------|----------|
| Addition/Subtraction | `fadd.s`, `fsub.s`                | 2       | 2       | 2        |
| Multiplication       | `fmul.s`                          | 2       | 2       | 2        |
| Division             | `fdiv.s`                          | 8       | 6       | 4        |
| Int-to-FP Conversion | `fcvt.s.w`, `fcvt.s.wu`           | 2       | 2       | 2        |
| FP-to-Int Conversion | `fcvt.w.s`, `fcvt.wu.s`           | 2       | 2       | 2        |
| Comparison           | `feq.s`, `fle.s`, `flt.s`         | 1       | 1       | 1        |
| Sign-Inject          | `fsgnj.s`, `fsgnjn.s`, `fsgnjx.s` | 1       | 1       | 1        |
| Move                 | `fmv.w.x`, `fmv.x.w`              | 1       | 1       | 1        |

## Simulation

The design includes a simple `tb_fpmix` testbench contained in the `tb/tb_fpmix.sv` file.  
Simulations were run in **Vivado 2024.2 (GUI project mode, tested on Ubuntu 22.04.5 and Windows 11 25H2)**.

## Validation

The design includes a SystemVerilog DPI-C model (`tb/dpi_fpmix.c`), used by the `validate_fpmix` testbench contained in the `tb/validate_fpmix.sv` file.
To run simulations with DPI enabled, follow these steps:

1. **Compile the DPI library using XSim C compiler (`xsc`)**  
   From the Vivado **Tcl Console**, run:
   
   ```tcl
   exec xsc <pathToDPIFile>/dpi_fpmix.c -o <pathToDPIFile>/dpi_fpmix.so
   ```

2. **Tell XSim to load the DPI shared library during elaboration**  
   Go to:
   **Flow Navigator → Project Settings → Simulation → Elaboration options**
   and add the following flag in **`xsim.elaborate.xelab.more_options`**:

   ```
   --sv_lib dpi_fpmix
   ```

3. **Place the shared object in the XSim working directory**  
   Copy the compiled `.so` file into:

   ```
   <VivadoProject>/<projectName>.sim/sim_1/behav/xsim/
   ```

   For post-synthesis and post-implementation simulations, copy the `.so` into the corresponding simulation subdirectories as well.

4. **Run simulation as usual**  
   Use:
   **Flow Navigator → Run Simulation → Run Behavioral Simulation**

   For post-synthesis and post-implementation simulations, accordingly use the corresponding actions from the dropdown menu.

## Non-Project Mode (Recommended)

**Vivado 2024.2, Ubuntu 22.04** shell/Makefile flows (no project).

### Quick Start

```
source <pathToVivadoInstallation>/Xilinx/Vivado/2024.2/settings64.sh # Adjust path
make clean all # Synth/impl/RTL sim/post-synth (VCU118)
```

### Makefile Targets

| Target                               | Action                          |
|--------------------------------------|---------------------------------|
| `make all`                           | Full: synth/impl/sim/post-synth |
| `make synth [PART=xc7a100tcsg324-1]` | OOC synth                       |
| `make impl`                          | Place/route/phys_opt            |
| `make sim_tb`                        | RTL simple TB                   |
| `make sim_validate`                  | RTL DPI validation              |
| `make post_synth_tb`                 | Post-synth simple TB            |
| `make post_synth_validate`           | Post-synth DPI                  |
| `make clean`                         | Remove runs/xsim                |

## FPMIX Architecture

### Design-Time Configurable Parameters

| Configurable Parameter                    | SV Package Localparam | Default Value | Constraint                       |
|-------------------------------------------|-----------------------|---------------|----------------------------------|
| Integer Format Bitwidth                   | `FPMIX_INTEGER_DW`    | 32            |                                  |
| FP Format Exponent Bitwidth               | `FPMIX_FLOAT_E_DW`    | 8             |                                  |
| FP Format Mantissa Bitwidth               | `FPMIX_FLOAT_F_DW`    | 23            |                                  |
| FP Addition/Subtraction Mantissa Bitwidth | `ADD_FLOAT_F_DW`      | 23            | Between 1 and `FPMIX_FLOAT_F_DW` |
| FP Multiplication Mantissa Bitwidth       | `MUL_FLOAT_F_DW`      | 23            | Between 1 and `FPMIX_FLOAT_F_DW` |
| FP Division Mantissa Bitwidth             | `DIV_FLOAT_F_DW`      | 23            | Between 1 and `FPMIX_FLOAT_F_DW` |
| Int-to-FP Conversion Mantissa Bitwidth    | `F2I_FLOAT_F_DW`      | 23            | Between 1 and `FPMIX_FLOAT_F_DW` |
| FP-to-Int Conversion Mantissa Bitwidth    | `I2F_FLOAT_F_DW`      | 23            | Between 1 and `FPMIX_FLOAT_F_DW` |
| FP Comparison Mantissa Bitwidth           | `CMP_FLOAT_F_DW`      | 23            | Between 1 and `FPMIX_FLOAT_F_DW` |

### FPMIX Input-Output Interface

**Inputs**

| Signal      | Bitwidth           | Description                                  |
|-------------|--------------------|----------------------------------------------|
| `clk`       | 1                  | Clock                                        |
| `rst`       | 1                  | Reset                                        |
| `flush_i`   | 1                  | Flush, invalidates current operation         |
| `padv_i`    | 1                  | Pipeline advance, accepts new operation      |
| `opcode_i`  | 5                  | Opcode        (see table below for encoding) |
| `rndMode_i` | 1                  | Rounding mode (see table below for encoding) |
| `op1_i`     | `FPMIX_INTEGER_DW` | Operand \#1                                  |
| `op2_i`     | `FPMIX_INTEGER_DW` | Operand \#2                                  |

**Outputs**

| Signal            | Bitwidth           | Description       |
|-------------------|--------------------|-------------------|
| `result_o`        | `FPMIX_INTEGER_DW` | Result            |
| `isResultValid_o` | 1                  | Valid result flag |
| `isReady_o`       | 1                  | Ready result flag |

### Opcodes

| 5-Bit Encoding | Instruction                          | RISC-V F             |
|----------------|--------------------------------------|----------------------|
| `0x00`         | No Operation                         | `-`                  |
| `0x01`         | Signed-to-FP Conversion              | `fcvt.s.w`           |
| `0x02`         | FP-to-Signed Conversion              | `fcvt.w.s`           |
| `0x03`         | FP Addition                          | `fadd.s`             |
| `0x04`         | FP Subtraction                       | `fsub.s`             |
| `0x05`         | FP Multiplication                    | `fmul.s`             |
| `0x06`         | FP Division                          | `fdiv.s`             |
| `0x07`         | Reserved                             | `-`                  |
| `0x08`         | Reserved                             | `-`                  |
| `0x09`         | FP Comparison - Equals               | `feq.s`              |
| `0x0A`         | FP Comparison - Less Than            | `flt.s`              |
| `0x0B`         | FP Comparison - Less Than or Equals  | `fle.s`              |
| `0x0C`         | Move                                 | `fmv.w.x`, `fmv.x.w` |
| `0x0D`         | FP Sign Injection                    | `fsgnj.s`            |
| `0x0E`         | FP Negated Sign Injection            | `fsgnjn.s`           |
| `0x0F`         | FP XORed Sign Injection              | `fsgnjx.s`           |
| `0x10`         | Unsigned-to-FP Conversion            | `fcvt.s.wu`          |
| `0x11`         | FP-to-Unsigned Conversion            | `fcvt.wu.s`          |

### Rounding Modes

| 1-Bit Encoding | Rounding Mode         |
|----------------|-----------------------|
| `0x0`          | Round to Nearest Even |
| `0x1`          | Round Toward Zero     |
