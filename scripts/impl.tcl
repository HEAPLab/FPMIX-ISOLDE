# Copyright 2026 Politecnico di Milano.
# Authors: Andrea Galimberti, Davide Zoni.
# Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.
# Date: January 9, 2026.

set PART [lindex $argv 0]
if {$PART == ""} { set PART xcvu9p-flga2104-2L-e }
set DCP "./runs/synth_${PART}/fpmix_top.dcp"
set OUTDIR [file normalize "./runs/impl_${PART}"]
file mkdir $OUTDIR
open_checkpoint $DCP
opt_design
place_design
route_design -directive Explore
phys_opt_design
report_timing_summary -file $OUTDIR/timing.rpt
report_utilization -file $OUTDIR/util.rpt
write_checkpoint -force $OUTDIR/fpmix_top_routed.dcp
quit

