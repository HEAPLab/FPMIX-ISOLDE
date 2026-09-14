// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_floatRnd #(
	FLOAT_E_DW	=	8,
	FLOAT_F_DW	=	23
)(
	//	Inputs
	rndMode_i,
	e_res_postNorm_i,
	f_res_postNorm_i,
	//	Outputs
	e_res_postRnd_o,
	f_res_postRnd_o
);

import fpmix_pkg::*;

//	Inputs
input	rndModeFPU_t												rndMode_i;
input			[FLOAT_E_DW-1:0]									e_res_postNorm_i;
input			[(1/*ovf*/+1/*hidden*/+FLOAT_F_DW+3/*G,R,S*/)-1:0]	f_res_postNorm_i;
//	Outputs
output	logic	[FLOAT_E_DW-1:0]									e_res_postRnd_o;
output	logic	[FLOAT_F_DW-1:0]									f_res_postRnd_o;

//////////////////////////////////////////////////////////////////
//						Internal wires							//
//////////////////////////////////////////////////////////////////

	logic 							isAddOne;
	logic [(1+1+FLOAT_F_DW+3)-1:0]	tempF_1;
	logic [FLOAT_E_DW-1:0]			tempE;
	logic [(1+1+FLOAT_F_DW+3)-1:0]	tempF;

//////////////////////////////////////////////////////////////////
//						Combinational logic						//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		//////////////////////////////////////////
		//	Round to nearest even				//
		//	X0.00 -> X0		|	X1.00 -> X1		//
		//	X0.01 -> X0		|	X1.01 -> X1		//
		//	X0.10 -> X0		|	X1.10 -> X1. +1	//
		//	X0.11 -> X1		|	X1.11 -> X1. +1	//
		//////////////////////////////////////////
		tempF_1 = f_res_postNorm_i;
		case(f_res_postNorm_i[3:1] /*3 bits X.G(S|R)*/ )
			3'b0_00:	begin tempF_1[3] = 0;	isAddOne = 0; end
			3'b0_01:	begin tempF_1[3] = 0;	isAddOne = 0; end
			3'b0_10:	begin tempF_1[3] = 0;	isAddOne = 0; end
			3'b0_11:	begin tempF_1[3] = 1;	isAddOne = 0; end
			3'b1_00:	begin tempF_1[3] = 1;	isAddOne = 0; end
			3'b1_01:	begin tempF_1[3] = 1;	isAddOne = 0; end
			3'b1_10:	begin tempF_1[3] = 1;	isAddOne = 1; end
			3'b1_11:	begin tempF_1[3] = 1;	isAddOne = 1; end
		endcase

		tempF =	tempF_1 + (isAddOne<<3);

		//	Normalize after rounding
		if (tempF[(1+1+FLOAT_F_DW+3)-1] == 1'b1)
		begin
			tempE = e_res_postNorm_i + 1;
			tempF = tempF >> 1;
		end
		else
		begin
			tempE = e_res_postNorm_i;
		end
	end

	always_comb
	begin
		if (rndMode_i == FPU_RNDMODE_NEAREST)
			{e_res_postRnd_o, f_res_postRnd_o}	=	{tempE, tempF[3+:FLOAT_F_DW]};
		else
			{e_res_postRnd_o, f_res_postRnd_o}	=	{e_res_postNorm_i, f_res_postNorm_i[3+:FLOAT_F_DW]};
	end

endmodule
