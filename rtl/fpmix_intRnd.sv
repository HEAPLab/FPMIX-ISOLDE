// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_intRnd #(
	INT_DW	=	32
)(
	//	Inputs
	rndMode_i,
	int_res_preRnd_i,
	//	Outputs
	int_res_postRnd_o
);

import fpmix_pkg::*;

//	Inputs
input	rndModeFPU_t				rndMode_i;
input			[(INT_DW+3)-1:0]	int_res_preRnd_i;
//	Outputs
output	logic	[INT_DW-1:0]		int_res_postRnd_o;

//////////////////////////////////////////////////////////////////
//						Internal wires							//
//////////////////////////////////////////////////////////////////

	logic					isAddOne;
	logic	[INT_DW-1:0]	int_res;

//////////////////////////////////////////////////////////////////
//						Combinational logic						//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		isAddOne	=	(int_res_preRnd_i[3] && int_res_preRnd_i[2]) ||
						(int_res_preRnd_i[2] && int_res_preRnd_i[1]);
		int_res		=	int_res_preRnd_i[3+:INT_DW] + isAddOne;
	end

	always_comb
	begin
		if (rndMode_i == FPU_RNDMODE_NEAREST)
			int_res_postRnd_o	=	int_res;
		else
			int_res_postRnd_o	=	int_res_preRnd_i[3+:INT_DW];
	end

endmodule
