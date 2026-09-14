// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_preMulDiv #(
	FRACT_DW	=	23
)(
	//	Inputs
	extFract1_i,
	extFract2_i,
	//	Outputs
	numLeadingZeros1_o,
	extShFract1_o,
	numLeadingZeros2_o,
	extShFract2_o
);

//	Inputs
input			[(1+FRACT_DW)-1:0]			extFract1_i;
input			[(1+FRACT_DW)-1:0]			extFract2_i;
//	Outputs
output	logic	[$clog2(1+FRACT_DW)-1:0]	numLeadingZeros1_o;
output	logic	[(1+FRACT_DW)-1:0]			extShFract1_o;
output	logic	[$clog2(1+FRACT_DW)-1:0]	numLeadingZeros2_o;
output	logic	[(1+FRACT_DW)-1:0]			extShFract2_o;

//////////////////////////////////////////////////////////////////
//				Combinational logic - Operand 1					//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		// Default: no left shift, if mantissa is zero
		numLeadingZeros1_o			=	'0;
		// Priority search from LSB to MSB
		for (int i = 0; i < 1+FRACT_DW; i++)
			if (extFract1_i[i])
				numLeadingZeros1_o	=	(1+FRACT_DW)-1 - i;
		// Left shift
		extShFract1_o	=	extFract1_i << numLeadingZeros1_o;
	end

//////////////////////////////////////////////////////////////////
//				Combinational logic - Operand 2					//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		// Default: no left shift, if mantissa is zero
		numLeadingZeros2_o			=	'0;
		// Priority search from MSB to LSB
		for (int i = 0; i < 1+FRACT_DW; i++)
			if (extFract2_i[i])
				numLeadingZeros2_o	=	(1+FRACT_DW)-1 - i;
		// Left shift
		extShFract2_o	=	extFract2_i << numLeadingZeros2_o;
	end

endmodule
