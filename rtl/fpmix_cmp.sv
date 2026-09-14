// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: January 29, 2026.

module fpmix_cmp #(
	FLOAT_S_DW	=	1,
	FLOAT_E_DW	=	8,
	FLOAT_F_DW	=	23
)(
	clk,
	//	Inputs
	doEq_i, doLt_i, doLe_i,
	opASign_i, opAExp_i, opAFract_i,
	opBSign_i, opBExp_i, opBFract_i,
	isAZer_i, isASNaN_i, isAQNaN_i,
	isBZer_i, isBSNaN_i, isBQNaN_i,
	//	Outputs
	cmp_o, isCmpValid_o, isCmpInvalid_o
);

input						clk;
//	Inputs
input						doEq_i;
input						doLt_i;
input						doLe_i;
input	[FLOAT_S_DW-1:0]	opASign_i;
input	[FLOAT_E_DW-1:0]	opAExp_i;
input	[FLOAT_F_DW-1:0]	opAFract_i;
input	[FLOAT_S_DW-1:0]	opBSign_i;
input	[FLOAT_E_DW-1:0]	opBExp_i;
input	[FLOAT_F_DW-1:0]	opBFract_i;
input						isAZer_i;
input						isASNaN_i;
input						isAQNaN_i;
input						isBZer_i;
input						isBSNaN_i;
input						isBQNaN_i;
//	Outputs
output	logic				cmp_o;
output	logic				isCmpValid_o;
output	logic				isCmpInvalid_o;		//	invalid operation exception flag

//////////////////////////////////////////////////////////////////
//                        Internal wires                        //
//////////////////////////////////////////////////////////////////

	logic							isABZer;
	logic							isABSNaN, isABQNaN, isABNaN;
	logic							signAEqB, signAEqpB, signAEqmB, signALtB;
	logic							expAGtB, expAEqB, expALtB;
	logic							fractAGtB, fractAEqB, fractALtB;
	logic							cmpAEqB, cmpALtB, cmpALeB;

	//	Output wires
	logic							cmp;
	logic							isCmpValid;
	logic							isCmpInvalid;

//////////////////////////////////////////////////////////////////
//                       Wire assignments                       //
//////////////////////////////////////////////////////////////////

	assign	cmp_o			=	cmp;
	assign	isCmpValid_o	=	isCmpValid;
	assign	isCmpInvalid_o	=	isCmpInvalid;

//////////////////////////////////////////////////////////////////
//                     Combinational logic                      //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		//	Zero/NaN flags
		isABZer			=	isAZer_i && isBZer_i;
		isABSNaN		=	isASNaN_i || isBSNaN_i;
		isABQNaN		=	isAQNaN_i || isBQNaN_i;
		isABNaN			=	isABSNaN || isABQNaN;

		//	Sign/exponent/significand comparisons
		signAEqB		=	opASign_i == opBSign_i;
		signAEqpB		=	~opASign_i && ~opBSign_i;
		signAEqmB		=	opASign_i && opBSign_i;
		signALtB		=	opASign_i > opBSign_i;
		expAGtB			=	opAExp_i > opBExp_i;
		expAEqB			=	opAExp_i == opBExp_i;
		expALtB			=	opAExp_i < opBExp_i;
		fractAGtB		=	opAFract_i > opBFract_i;
		fractAEqB		=	opAFract_i == opBFract_i;
		fractALtB		=	opAFract_i < opBFract_i;

		//	A-B comparisons
		cmpAEqB			=	~isABNaN && (isABZer ||
											(signAEqB && expAEqB && fractAEqB));
		cmpALtB			=	~isABNaN && ~isABZer && (signALtB ||
														(signAEqpB && expALtB) ||
														(signAEqmB && expAGtB) ||
														(signAEqpB && expAEqB && fractALtB) ||
														(signAEqmB && expAEqB && fractAGtB));
		cmpALeB			=	cmpAEqB || cmpALtB;

		//	Output assignments
		if (doEq_i)
			cmp			=	cmpAEqB;
		else if (doLt_i)
			cmp			=	cmpALtB;
		else // if (doLe_i)
			cmp			=	cmpALeB;
		isCmpValid		=	doEq_i || doLt_i || doLe_i;
		isCmpInvalid	=	((doLe_i || doLt_i) && isABNaN) || (doEq_i && isABSNaN);
	end

endmodule
