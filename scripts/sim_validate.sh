#!/bin/bash
# Copyright 2026 Politecnico di Milano.
# Authors: Andrea Galimberti, Davide Zoni.
# Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.
# Date: January 9, 2026.

rm -rf xsim.dir *.wdb *.vcd vivado*.log dpi_fpmix.so
xsc tb/dpi_fpmix.c -o dpi_fpmix.so
xvlog -sv pkg/fpmix_pkg.sv rtl/*.sv tb/validate_fpmix.sv
xelab validate_fpmix -debug typical --snapshot validate_fpmix --sv_lib dpi_fpmix
xsim validate_fpmix -R


