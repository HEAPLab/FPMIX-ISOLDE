#!/bin/bash
# Copyright 2026 Politecnico di Milano.
# Authors: Andrea Galimberti, Davide Zoni.
# Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.
# Date: January 9, 2026.

PART=${1:-xcvu9p-flga2104-2L-e}
NETLIST=./runs/synth_${PART}/fpmix_top.v
rm -rf xsim.dir *.wdb vivado*.log
xvlog -sv pkg/fpmix_pkg.sv $NETLIST tb/tb_fpmix.sv
xelab tb_fpmix -debug typical --snapshot tb_post_synth
xsim tb_post_synth -R

