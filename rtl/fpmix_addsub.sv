// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_addsub #(
	FLOAT_S_DW	=	1,
	FLOAT_E_DW	=	8,
	FLOAT_F_DW	=	23
)(
	clk, rst,
	//	Inputs
	doAddSub_i, isOpSub_i,
	s_op1_i, extF_op1_i, extE_op1_i,
	isInf_op1_i, isSNAN_op1_i, isQNAN_op1_i,
	s_op2_i, extF_op2_i, extE_op2_i,
	isInf_op2_i, isSNAN_op2_i, isQNAN_op2_i,
	op1_GT_op2_i, e_diff_i,
	//	Outputs
	s_res_o, e_res_o, f_res_o, valid_o,
	isOverflow_o, isUnderflow_o, isToRound_o
);

import fpmix_pkg::*;

localparam FLOAT_E_BIAS	=	(2 ** (FLOAT_E_DW - 1)) - 1;
localparam FLOAT_E_MAX	=	(2 ** FLOAT_E_DW) - 1;
localparam INF_E_F		=	{{FLOAT_E_DW{1'b1}},{FLOAT_F_DW{1'b0}}};
localparam QNAN_E_F		=	{{FLOAT_E_DW{1'b1}},1'b1,{(FLOAT_F_DW-1){1'b0}}};

input									clk;
input									rst;
//	Inputs
input									doAddSub_i;
input									isOpSub_i;
input			[FLOAT_S_DW-1:0]		s_op1_i;
input			[(FLOAT_F_DW+1)-1:0]	extF_op1_i;
input			[(FLOAT_E_DW+1)-1:0]	extE_op1_i;
input									isInf_op1_i;
input									isSNAN_op1_i;
input									isQNAN_op1_i;
input			[FLOAT_S_DW-1:0]		s_op2_i;
input			[(FLOAT_F_DW+1)-1:0]	extF_op2_i;
input			[(FLOAT_E_DW+1)-1:0]	extE_op2_i;
input									isInf_op2_i;
input									isSNAN_op2_i;
input									isQNAN_op2_i;
input									op1_GT_op2_i;
input			[(FLOAT_E_DW+1)-1:0]	e_diff_i;
//	Outputs
output	logic							s_res_o;
output	logic	[FLOAT_E_DW-1:0]		e_res_o;
output	logic	[FLOAT_F_DW+5-1:0]		f_res_o;
output	logic							valid_o;
output	logic							isOverflow_o;
output	logic							isUnderflow_o;
output	logic							isToRound_o;

//////////////////////////////////////////////////////////////////
//                        Internal wires                        //
//////////////////////////////////////////////////////////////////

	// Prepare for add/sub
	logic									doOpSub;	//we perform sub due to combination of operator and/or operand signs

	logic	[(FLOAT_F_DW+1)+3-1:0]			f_op_rhs;					// extended F, three added LSB bits are Guard,Round,Sticky
	logic	[(FLOAT_F_DW+1)+3-1:0]			f_op_rhs_shifted;			// extended F, three added LSB bits are Guard,Round,Sticky
	logic	[1+(FLOAT_F_DW+1)+3-1:0]		f_op_rhs_shifted_2comp;		// 1 bit for 2comp, plus extended F, three LSB bits are Guard,Round,Sticky
	logic	[1+(FLOAT_F_DW+1)+3-1:0]		f_op_noShift;				// extended F, plus three added LSB bits are Guard,Round,Sticky

	// De-normalization
	logic									s_initial_res_addsub;		// the added MSB is because the add result can be 1/B < M < 2
	logic	[1+1+FLOAT_F_DW+3-1:0]			f_initial_res_addsub_temp;	// extended F + 3 LSB bits, plus the added MSB is because the add result can be 1/B < M < 2
	logic	[1+1+FLOAT_F_DW+3-1:0]			f_initial_res_addsub;		// extended F + 3 LSB bits, plus the added MSB is because the add result can be 1/B < M < 2
	logic	[FLOAT_E_DW+1-1:0]				e_initial_res_addsub;		// the added MSB is because the add result can be 1/B < M < 2
	logic	[$clog2(1+FLOAT_F_DW+3)-1:0]	leftShiftAmount;

	// Post-normalization wires/regs
	logic									s_res_postNorm;
	logic	[1+1+FLOAT_F_DW+3-1:0]			f_res_postNorm;				//still keep the hidden bit and the overflow bit (MSB) in the bitvector
	logic	[FLOAT_E_DW+1-1:0]				e_res_postNorm;
	logic									isOverflow_postNorm;
	logic									isUnderflow_postNorm;

	//	Output next values
	logic									s_res;
	logic	[FLOAT_E_DW-1:0]				e_res;
	logic	[FLOAT_F_DW+5-1:0]				f_res;
	logic									valid;
	logic									isOverflow;
	logic									isUnderflow;
	logic									isToRound;

	logic									stickyBit;

	logic									isCheckNanInfValid;
	logic									isCheckInfRes;
	logic									isCheckNanRes;
	logic									isCheckSignRes;

//////////////////////////////////////////////////////////////////
//                       Sequential logic                       //
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			//	output registers
			s_res_o					<=	'0;
			e_res_o					<=	'0;
			f_res_o					<=	'0;
			valid_o					<=	'0;
			isOverflow_o			<=	'0;
			isUnderflow_o			<=	'0;
			isToRound_o				<=	'0;
		end
		else
		begin
			//	output registers
			s_res_o					<=	s_res;
			e_res_o					<=	e_res;
			f_res_o					<=	f_res;
			valid_o					<=	valid;
			isOverflow_o			<=	isOverflow;
			isUnderflow_o			<=	isUnderflow;
			isToRound_o				<=	isToRound;
		end
	end

//////////////////////////////////////////////////////////////////
//                     Combinational logic                      //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		f_op_rhs				= op1_GT_op2_i ? {extF_op2_i,3'b0} : {extF_op1_i,3'b0}; // operand to shift
		f_op_noShift			= op1_GT_op2_i ? {1'b0,extF_op1_i,3'b0} : {1'b0,extF_op2_i,3'b0};	// operand with greter magnitude not to be shifted

		// shift smaller (magnitude) operand and compute sticky
		f_op_rhs_shifted		= f_op_rhs	>>	e_diff_i;
		stickyBit				= 1'b0;
		for (int j = 0; j < FLOAT_F_DW; j++)
		begin
			if (e_diff_i >= j + 3)
				stickyBit		|= f_op_rhs[3 + j];
		end
		f_op_rhs_shifted		= {f_op_rhs_shifted[1+FLOAT_F_DW+3-1: 1], f_op_rhs_shifted[0]|stickyBit}; // sticky applied after right shift

	// perform REGULAR f add/sub. if sub or sign of the two operands differs do perform 2's complement of one operand!
		doOpSub 				= (isOpSub_i && (s_op1_i == s_op2_i)) || (!isOpSub_i && (s_op1_i != s_op2_i));

		f_op_rhs_shifted_2comp	= doOpSub ? ({1'b0,f_op_rhs_shifted} ^ {(1/*for 2comp*/+(1+FLOAT_F_DW/*extended*/)+3){1'b1}}) + 1'b1 : {1'b0,f_op_rhs_shifted};

		f_initial_res_addsub_temp	= {f_op_noShift} + {f_op_rhs_shifted_2comp}; // MSB for 2'compl (if sub), or can be M < 2 (if add)

		e_initial_res_addsub	= op1_GT_op2_i ? extE_op1_i : extE_op2_i;
		s_initial_res_addsub	= op1_GT_op2_i ? s_op1_i : ( ! isOpSub_i ? s_op2_i /*isAdd && op2>op1*/ :  /*isSub && op2>op1*/ ! s_op2_i);

		// put MSB to zero if doOpSub because it was for the 2'compl only. If is 1 after an add it means M > 2
		f_initial_res_addsub	= doOpSub ? {1'b0,f_initial_res_addsub_temp[((1/*hidden*/+FLOAT_F_DW)+3/*LSB*/)-1:0]} : f_initial_res_addsub_temp;

	//
	// post-normalization: 3 scenarios (that must also be combined with the E value!!)
	// a) op1 + 	op2 = f_res = {1, {23{x}}	, xxx} 		-> 1/B < M < 2	shift f by 1 right and increase e by 1. - Sticky is lost ...for good
	// b) op1 +/-	op2 = f_res = {0, 1, {22{x}}, xxx}  	-> 1/B < M < 1 ok. 										- Fix sticky as sticky | round before perform rounding
	// c) op1 - 	op2 = f_res = {0, 0, {22{x}}, xxx}  	-> 1/B < M < 1  shift by N to left and decrease E by N  - no problem since zeros are added and precision is lost by construction
	//

		leftShiftAmount			= '0;
		for (int i = 0; i < 1+1+FLOAT_F_DW+3; i++)
		begin
			if (f_initial_res_addsub[i])
			begin
				leftShiftAmount	= (1+1+FLOAT_F_DW+3-1) - i - 1;
			end
		end

		isOverflow_postNorm		= '0;
		isUnderflow_postNorm	= '0;

		s_res_postNorm			= s_initial_res_addsub; //final sign does not change

		if (f_initial_res_addsub[1/*extra bit*/+(1/*hidden 1*/+FLOAT_F_DW+3/*LSB rnd bits*/)-1] == 1)
			// op1 + op2 = f_res = {-> 1 <-, {x/*hidden*/,23{x}}, xxx}
			if (e_initial_res_addsub + 1 == FLOAT_E_MAX)
			begin // since we need to shift right f exp will increase by 1: if e=0xff then overflow
				isOverflow_postNorm	= 1;
				e_res_postNorm		= FLOAT_E_MAX;
				f_res_postNorm		= '0;
			end
			else
			begin // DO POST-NORM (single right shift) since e+1 < 0xff
				e_res_postNorm	= e_initial_res_addsub + 1;			
				f_res_postNorm	= {
					1'b0,                                              // Bit 27 (MSB)
					f_initial_res_addsub[1+1+FLOAT_F_DW+3-1:3],  // Bits 26 down to 2
					f_initial_res_addsub[2] | f_initial_res_addsub[1] | f_initial_res_addsub[0], // Bit 1
					1'b0                                               // Bit 0
				};
			end
		else if (f_initial_res_addsub[(1+1+FLOAT_F_DW+3/*LSB rnd bits*/)-2] == 1) //no right shift, no left shift -> no postnorm, thus fix the sticky bit for rounding
		begin
			//check if e=0 to signal zero or underflow
			f_res_postNorm		= {f_initial_res_addsub [1+1+FLOAT_F_DW+3-1:2], f_initial_res_addsub[1] | f_initial_res_addsub[0], 1'b0 /*old useless sticky*/ };
			e_res_postNorm		= e_initial_res_addsub;
		end
		else //DO POST-NORM lsh. -- NOTE: G,R,S are eventually lost for good
		begin
			if (f_initial_res_addsub == '0)
			begin
				e_res_postNorm	= '0;
				f_res_postNorm	= '0;
			end
			else if (e_initial_res_addsub > leftShiftAmount)	// do post-norm	(N left shift and exp fix) since after left-shift e > 0
			begin
				e_res_postNorm	= e_initial_res_addsub - leftShiftAmount;
				f_res_postNorm	= f_initial_res_addsub << leftShiftAmount; // shift f left by leftShiftAmount and pad with zeros.
			end
			else
			begin
				e_res_postNorm				= '0;
				f_res_postNorm				= f_initial_res_addsub << (e_initial_res_addsub - 1);	// denorm: we need to account for the hidden bit that is zero
				if (leftShiftAmount > e_initial_res_addsub)
					isUnderflow_postNorm	= '1;
			end
		end

	// compute if nan or infinite res
		{isCheckNanInfValid, isCheckInfRes, isCheckNanRes, isCheckSignRes} = FUNC_calcInfNanResAddSub(
					isOpSub_i, 												/*operator*/
					isInf_op1_i, s_op1_i, isSNAN_op1_i, isQNAN_op1_i,		/*op1 */
					isInf_op2_i, s_op2_i, isSNAN_op2_i, isQNAN_op2_i		/*op2 */
			);

		unique if (isCheckInfRes)
			{s_res, e_res, f_res}	=	{isCheckSignRes, INF_E_F, 5'b0};
		else if (isCheckNanRes)
			{s_res, e_res, f_res}	=	{isCheckSignRes, QNAN_E_F, 5'b0};
		else
			{s_res, e_res, f_res}	=	{s_res_postNorm, e_res_postNorm[FLOAT_E_DW-1:0], f_res_postNorm};
		valid		= doAddSub_i;
		isToRound	= ~isCheckNanInfValid;
		isOverflow	= isOverflow_postNorm;
		isUnderflow	= isUnderflow_postNorm;
	end

endmodule
