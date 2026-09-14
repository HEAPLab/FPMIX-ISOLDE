#!/bin/bash
# Copyright 2026 Politecnico di Milano.
# Authors: Andrea Galimberti, Davide Zoni.
# Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.
# Date: January 9, 2026.

rm -rf xsim.dir *.wdb vivado*.log
xvlog -sv pkg/fpmix_pkg.sv rtl/*.sv tb/tb_fpmix.sv
xelab tb_fpmix -debug typical --snapshot tb_fpmix
xsim tb_fpmix -R

