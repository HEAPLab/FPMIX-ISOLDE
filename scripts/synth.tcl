# Copyright 2026 Politecnico di Milano.
# Authors: Andrea Galimberti, Davide Zoni.
# Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.
# Date: January 9, 2026.

set PART [lindex $argv 0]
if {$PART == ""} { set PART xcvu9p-flga2104-2L-e }
set OUTDIR [file normalize "./runs/synth_${PART}"]
file mkdir $OUTDIR
read_verilog -sv ./pkg/fpmix_pkg.sv
read_verilog -sv ./rtl/fpmix_addsub.sv ./rtl/fpmix_cmp.sv ./rtl/fpmix_div.sv ./rtl/fpmix_f2i.sv ./rtl/fpmix_floatRnd.sv ./rtl/fpmix_fractDiv.sv ./rtl/fpmix_i2f.sv ./rtl/fpmix_intRnd.sv ./rtl/fpmix_mul.sv ./rtl/fpmix_preMulDiv.sv ./rtl/fpmix_top.sv
read_xdc ./xdc/timing.xdc
synth_design -top fpmix_top -part $PART -mode out_of_context
report_timing_summary -file $OUTDIR/timing.rpt
report_utilization -file $OUTDIR/util.rpt
write_checkpoint -force $OUTDIR/fpmix_top.dcp
write_verilog -force $OUTDIR/fpmix_top.v
quit


