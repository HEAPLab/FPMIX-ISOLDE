#!/bin/bash
PART=${1:-xcvu9p-flga2104-2L-e}
NETLIST=./runs/synth_${PART}/fpmix_top.v
rm -rf xsim.dir *.wdb vivado*.log dpi_fpmix.so
xsc tb/dpi_fpmix.c -o dpi_fpmix.so
xvlog -sv pkg/fpmix_pkg.sv $NETLIST tb/validate_fpmix.sv
xelab validate_fpmix -debug typical --snapshot validate_post_synth --sv_lib dpi_fpmix
xsim validate_post_synth -R

