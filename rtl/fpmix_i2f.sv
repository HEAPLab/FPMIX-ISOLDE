// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_i2f #(
	FLOAT_S_DW	=	1,
	FLOAT_E_DW	=	8,
	FLOAT_F_DW	=	23,
	INTEGER_DW	=	32
)(
	clk, rst,
	//	Inputs
	doI2f_i, isIntSigned_i,
	op1_i,
	//	Outputs
	s_res_o, e_res_o, f_res_o, valid_o,
	isOverflow_o, isUnderflow_o, isToRound_o
);

import fpmix_pkg::*;

localparam FLOAT_E_BIAS	=	(2 ** (FLOAT_E_DW - 1)) - 1;
localparam ZERO_E_F		=	{{FLOAT_E_DW{1'b0}},{FLOAT_F_DW{1'b0}}};

input								clk;
input								rst;
//	Inputs
input								doI2f_i;
input								isIntSigned_i;
input			[INTEGER_DW-1:0]	op1_i;
//	Outputs
output	logic						s_res_o;
output	logic	[FLOAT_E_DW-1:0]	e_res_o;
output	logic	[FLOAT_F_DW+5-1:0]	f_res_o;
output	logic						valid_o;
output	logic						isOverflow_o;
output	logic						isUnderflow_o;
output	logic						isToRound_o;

//////////////////////////////////////////////////////////////////
//                        Internal wires                        //
//////////////////////////////////////////////////////////////////

	logic								intOpSign;
	logic	[INTEGER_DW-1:0]			intOpMagnitude;
	logic	[FLOAT_E_DW-1:0]			intOpExp;
	logic								isIntOpZero;
	logic	[$clog2(INTEGER_DW)-1:0]	shiftLeft;
	logic	[$clog2(INTEGER_DW)-1:0]	shiftRight;
	logic	[(INTEGER_DW+3)-1:0]		floatFractExt;
	logic	[(1+1+FLOAT_F_DW+3)-1:0]	floatFractExtSh;
	logic								stickyBit;

	// Post-normalization wires/regs
	logic	[FLOAT_S_DW-1:0]			s_res_postNorm;
	logic	[FLOAT_E_DW-1:0]			e_res_postNorm;
	logic	[(1+1+FLOAT_F_DW+3)-1:0]	f_res_postNorm;
	logic								isOverflow_postNorm;
	logic								isUnderflow_postNorm;

	//	Output next values
	logic								s_res;
	logic	[FLOAT_E_DW-1:0]			e_res;
	logic	[(1+1+FLOAT_F_DW+3)-1:0]	f_res;
	logic								valid;
	logic								isOverflow;
	logic								isUnderflow;
	logic								isToRound;

//////////////////////////////////////////////////////////////////
//                       Sequential logic                       //
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			//	Output registers
			s_res_o			<=	'0;
			e_res_o			<=	'0;
			f_res_o			<=	'0;
			valid_o			<=	'0;
			isOverflow_o	<=	'0;
			isUnderflow_o	<=	'0;
			isToRound_o		<=	'0;
		end
		else
		begin
			//	Output registers
			s_res_o			<=	s_res;
			e_res_o			<=	e_res;
			f_res_o			<=	f_res;
			valid_o			<=	valid;
			isOverflow_o	<=	isOverflow;
			isUnderflow_o	<=	isUnderflow;
			isToRound_o		<=	isToRound;
		end
	end

//////////////////////////////////////////////////////////////////
//                     Combinational logic                      //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		if (isIntSigned_i)
		begin
			intOpSign				=	op1_i[INTEGER_DW-1];
			intOpMagnitude			=	(op1_i ^ {INTEGER_DW{intOpSign}}) + intOpSign;
		end
		else
		begin
			intOpSign				=	1'b0;
			intOpMagnitude			=	op1_i;
		end
		intOpExp					=	'0;
		for (int i = 1; i < FPMIX_INTEGER_DW; i++)
		begin
			if (intOpMagnitude[i])
			begin
				intOpExp			=	i;
			end
		end
		isIntOpZero					=	~(|op1_i);

		shiftRight					=	'0;
		shiftLeft					=	'0;
		if (intOpExp > FLOAT_F_DW)
			shiftRight				=	intOpExp - FLOAT_F_DW;
		else
			shiftLeft				=	FLOAT_F_DW - intOpExp;

		floatFractExt				=	intOpMagnitude << 3;

		if (intOpExp > FLOAT_F_DW)
			floatFractExtSh			=	floatFractExt >> shiftRight;
		else
			floatFractExtSh			=	floatFractExt << shiftLeft;

		stickyBit 					=	1'b0;
		for (int j = 0; j < FLOAT_F_DW; j++) begin
			if (shiftRight >= j + 3)
				stickyBit			|=	floatFractExt[3 + j];
		end

		floatFractExtSh[1]			=	floatFractExtSh[1] | floatFractExtSh[0] | stickyBit;
		floatFractExtSh[0]			=	1'b0;

		s_res_postNorm				=	intOpSign;
		e_res_postNorm				=	intOpExp + FLOAT_E_BIAS;
		f_res_postNorm				=	floatFractExtSh;
		isOverflow_postNorm			=	1'b0;
		isUnderflow_postNorm		=	1'b0;

		if (isIntOpZero)
			{s_res, e_res, f_res}	=	{1'b0, ZERO_E_F, 5'b0};
		else
			{s_res, e_res, f_res}	=	{s_res_postNorm, e_res_postNorm, f_res_postNorm};
		valid						=	doI2f_i;
		isToRound					=	~isIntOpZero;
		isOverflow					=	isOverflow_postNorm;
		isUnderflow					=	isUnderflow_postNorm;
	end

endmodule
