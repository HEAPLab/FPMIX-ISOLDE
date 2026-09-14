# Copyright 2026 Politecnico di Milano.
# Authors: Andrea Galimberti, Davide Zoni.
# Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it.
# Date: January 9, 2026.

PART ?= xcvu9p-flga2104-2L-e

.PHONY: all synth impl sim_tb sim_validate post_synth_tb post_synth_validate clean

all: synth impl sim_tb sim_validate post_synth_tb post_synth_validate

synth:
		mkdir -p ./runs/synth_${PART}
			vivado -mode batch -source scripts/synth.tcl ${PART}

impl: synth
		mkdir -p ./runs/impl_${PART}
			vivado -mode batch -source scripts/impl.tcl ${PART}

sim_tb:
		./scripts/sim_tb.sh

sim_validate:
		./scripts/sim_validate.sh

post_synth_tb: synth
		./scripts/sim_post_synth_tb.sh ${PART}

post_synth_validate: synth
		./scripts/sim_post_synth_validate.sh ${PART}

clean:
		rm -rf ./runs/ xsim.dir *.wdb vivado*.log *.vcd *.so dpi_fpmix.so

