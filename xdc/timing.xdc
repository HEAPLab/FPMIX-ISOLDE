# Copyright 2026 Politecnico di Milano.
# Authors: Andrea Galimberti, Davide Zoni.
# Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.
# Date: January 29, 2026.

# VCU 118 target - float32 FPU
# 256 MHz clock constraint (3.9 ns period)
create_clock -name clk -period  3.900 [get_ports clk]

# VCU 118 target - float24 FPU
# 313 MHz clock constraint (3.2 ns period)
#create_clock -name clk -period  3.200 [get_ports clk]

# VCU 118 target - bfloat16 FPU
# 345 MHz clock constraint (2.9 ns period)
#create_clock -name clk -period  2.900 [get_ports clk]

# Artix-7 100 target - float32, float24, bfloat16 FPUs
# 85 MHz clock constraint (11.8 ns period)
#create_clock -name clk -period 11.800 [get_ports clk]

# Artix-7 100 target - bfloat16 FPU
# 100 MHz clock constraint (10.0 ns period)
#create_clock -name clk -period 10.000 [get_ports clk]
