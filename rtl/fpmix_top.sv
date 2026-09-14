// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_top (
	clk, rst,
	//	Inputs
	flush_i, padv_i,
	opcode_i, rndMode_i, op1_i, op2_i,
	//	Outputs
	result_o, isResultValid_o, isReady_o
);

import fpmix_pkg::*;

input									clk;
input									rst;
//	Inputs
input									flush_i;	// Flush the FPU invalidating the current operation
input									padv_i;		// Pipeline advance signal: accept new operation
input	opcodeFPU_t						opcode_i;
input	rndModeFPU_t					rndMode_i;
input			[FPMIX_INTEGER_DW-1:0]	op1_i;
input			[FPMIX_INTEGER_DW-1:0]	op2_i;
//	Outputs
output	logic	[FPMIX_INTEGER_DW-1:0]	result_o;
output	logic							isResultValid_o;
output	logic							isReady_o;

	// Input wires: drive registered inputs
	logic 									flush_r, flush_r_next;
	opcodeFPU_t								opcode_r, opcode_r_next;
	rndModeFPU_t							rndMode_r, rndMode_r_next;
	logic	[FPMIX_INTEGER_DW-1:0]			op1_r, op1_r_next;

	// Output wires: drive registered outputs
	logic	[FPMIX_INTEGER_DW-1:0]			result_o_next;
	logic									isResultValid_o_next;

	//	Add/sub outputs
	logic									addsub_s_res;
	logic	[FPMIX_FLOAT_E_DW-1:0]			addsub_e_res;
	logic	[ADD_FLOAT_F_DW+5-1:0]			addsub_f_res;
	logic									addsub_valid;
	logic									addsub_isOverflow;
	logic									addsub_isUnderflow;
	logic									addsub_isToRound;

	//	Mul outputs
	logic									mul_s_res;
	logic	[FPMIX_FLOAT_E_DW-1:0]			mul_e_res;
	logic	[MUL_FLOAT_F_DW+5-1:0]			mul_f_res;
	logic									mul_valid;
	logic									mul_isOverflow;
	logic									mul_isUnderflow;
	logic									mul_isToRound;

	//	Div outputs
	logic									div_s_res;
	logic	[FPMIX_FLOAT_E_DW-1:0]			div_e_res;
	logic	[DIV_FLOAT_F_DW+5-1:0]			div_f_res;
	logic									div_valid;
	logic									div_isOverflow;
	logic									div_isUnderflow;
	logic									div_isToRound;

	//	F2i outputs
	logic									f2i_s_res;
	logic	[(FPMIX_INTEGER_DW+3)-1:0]		f2i_f_res;
	logic									f2i_valid;
	logic									f2i_isOverflow;
	logic									f2i_isUnderflow;
	logic									f2i_isSNaN;

	//	I2f outputs
	logic									i2f_s_res;
	logic	[FPMIX_FLOAT_E_DW-1:0]			i2f_e_res;
	logic	[I2F_FLOAT_F_DW+5-1:0]			i2f_f_res;
	logic									i2f_valid;
	logic									i2f_isOverflow;
	logic									i2f_isUnderflow;
	logic									i2f_isToRound;

	//	Cmp outputs
	logic									cmp_res;
	logic									cmp_isResValid;
	logic									cmp_isCmpInvalid;

	//	Mul-div preprocessing outputs
	logic	[$clog2(1+FPMIX_FLOAT_F_DW)-1:0]	preMulDiv_numLeadingZeros1_by_w	[MIN_F_DW:MAX_F_DW];
	logic	[1+FPMIX_FLOAT_F_DW-1:0]			preMulDiv_extShFract1_by_w		[MIN_F_DW:MAX_F_DW];
	logic	[$clog2(1+FPMIX_FLOAT_F_DW)-1:0]	preMulDiv_numLeadingZeros2_by_w	[MIN_F_DW:MAX_F_DW];
	logic	[1+FPMIX_FLOAT_F_DW-1:0]			preMulDiv_extShFract2_by_w		[MIN_F_DW:MAX_F_DW];

	//	FloatRnd outputs
	logic	[FPMIX_FLOAT_E_DW-1:0]			floatRnd_e_res_postRnd;
	logic	[FPMIX_FLOAT_F_DW-1:0]			floatRnd_f_res_postRnd;

	//	IntRnd outputs
	logic	[FPMIX_INTEGER_DW-1:0]			intRnd_int_res_postRnd;

	//	Registered operation commands
	logic									doAddSub_r, doAddSub_r_next;
	logic									isOpSub_r, isOpSub_r_next;
	logic									doMul_r, doMul_next;
	logic									doDiv_r, doDiv_next;
	logic									doF2i_r, doF2i_next;
	logic									doI2f_r, doI2f_next;
	logic									isIntSigned_r, isIntSigned_next;
	logic									doCmpEq_r, doCmpEq_next;
	logic									doCmpLt_r, doCmpLt_next;
	logic									doCmpLe_r, doCmpLe_next;

	//	FUs results and valid bits
	logic	[FPMIX_INTEGER_DW-1:0]			res;
	logic									isResValid;

	//	Pre-processing output registers
	logic	[FPMIX_FLOAT_S_DW-1:0]			s_op1_r;
	logic	[FPMIX_FLOAT_E_DW-1:0]			e_op1_r;
	logic	[FPMIX_FLOAT_F_DW-1:0]			f_op1_r;
	logic	[(FPMIX_FLOAT_F_DW+1)-1:0]		extF_op1_r;
	logic	[(FPMIX_FLOAT_E_DW+1)-1:0]		extE_op1_r;
	logic									isInf_op1_r;
	logic									isZ_op1_r;
	logic									isSNAN_op1_r;
	logic									isQNAN_op1_r;
	logic	[FPMIX_FLOAT_S_DW-1:0]			s_op2_r;
	logic	[FPMIX_FLOAT_E_DW-1:0]			e_op2_r;
	logic	[FPMIX_FLOAT_F_DW-1:0]			f_op2_r;
	logic	[(FPMIX_FLOAT_F_DW+1)-1:0]		extF_op2_r;
	logic	[(FPMIX_FLOAT_E_DW+1)-1:0]		extE_op2_r;
	logic									isInf_op2_r;
	logic									isZ_op2_r;
	logic									isSNAN_op2_r;
	logic									isQNAN_op2_r;
	//	Add/sub-only
	logic										op1_GT_op2_r;
	logic	[FPMIX_FLOAT_E_DW+1-1:0]			e_diff_r;
	//	Mul-div-only
	logic	[(1+FPMIX_FLOAT_F_DW)-1:0]			extShF_op1_r;
	logic	[$clog2(1+FPMIX_FLOAT_F_DW)-1:0]	nlz_op1_r;
	logic	[(1+FPMIX_FLOAT_F_DW)-1:0]			extShF_op2_r;
	logic	[$clog2(1+FPMIX_FLOAT_F_DW)-1:0]	nlz_op2_r;

	//	Pre-operation wires/regs
	logic	[FPMIX_FLOAT_S_DW-1:0]			s_op1_wire;
	logic	[FPMIX_FLOAT_E_DW-1:0]			e_op1_wire;
	logic	[FPMIX_FLOAT_F_DW-1:0]			f_op1_wire;
	logic	[(FPMIX_FLOAT_F_DW+1)-1:0]		extF_op1_wire;
	logic	[(FPMIX_FLOAT_E_DW+1)-1:0]		extE_op1_wire;
	logic									isDN_op1_wire;
	logic									isZ_op1_wire;
	logic									isInf_op1_wire;
	logic									isSNAN_op1_wire;
	logic									isQNAN_op1_wire;
	logic	[FPMIX_FLOAT_S_DW-1:0]			s_op2_wire;
	logic	[FPMIX_FLOAT_E_DW-1:0]			e_op2_wire;
	logic	[FPMIX_FLOAT_F_DW-1:0]			f_op2_wire;
	logic	[(FPMIX_FLOAT_F_DW+1)-1:0]		extF_op2_wire;
	logic	[(FPMIX_FLOAT_E_DW+1)-1:0]		extE_op2_wire;
	logic									isDN_op2_wire;
	logic									isZ_op2_wire;
	logic									isInf_op2_wire;
	logic									isSNAN_op2_wire;
	logic									isQNAN_op2_wire;
	//	Add/sub-only
	logic									op1_GT_op2_wire;
	logic	[FPMIX_FLOAT_E_DW+1-1:0]		e_diff_wire;
	// Per-width DN/Z/ext (Inf/SNaN/QNaN stay shared, computed at max width)
	logic	[1+FPMIX_FLOAT_E_DW-1:0]		extE_op1_by_w	[MIN_F_DW:MAX_F_DW];
	logic	[1+FPMIX_FLOAT_F_DW-1:0]		extF_op1_by_w	[MIN_F_DW:MAX_F_DW];
	logic									isDN_op1_by_w	[MIN_F_DW:MAX_F_DW];
	logic									isZ_op1_by_w	[MIN_F_DW:MAX_F_DW];
	logic	[1+FPMIX_FLOAT_E_DW-1:0]		extE_op2_by_w	[MIN_F_DW:MAX_F_DW];
	logic	[1+FPMIX_FLOAT_F_DW-1:0]		extF_op2_by_w	[MIN_F_DW:MAX_F_DW];
	logic									isDN_op2_by_w	[MIN_F_DW:MAX_F_DW];
	logic									isZ_op2_by_w	[MIN_F_DW:MAX_F_DW];

	//	Pre-rounding wires/regs
	logic									s_res;
	logic	[FPMIX_FLOAT_E_DW-1:0]			e_res;
	logic	[FPMIX_FLOAT_F_DW+5-1:0]		f_res;
	logic									isOverflow;
	logic									isUnderflow;
	logic									isToRound;

	//	Post-rounding wires/regs
	logic	[$clog2(FPMIX_FLOAT_F_DW)-1:0]	widthSel_r, widthSel_next;
	logic	[FPMIX_FLOAT_E_DW-1:0]			rnd_e_res_by_w	[MIN_F_DW:MAX_F_DW];
	logic	[FPMIX_FLOAT_F_DW-1:0]			rnd_f_res_by_w	[MIN_F_DW:MAX_F_DW];
	logic	[FPMIX_FLOAT_DW-1:0]			res_postRnd;
	logic									isOverflow_postRnd;
	logic									isUnderflow_postRnd;

	//	Integer post-rounding wires/regs
	logic									f2i_s_res_postRnd;
	logic	[FPMIX_INTEGER_DW-1:0]			f2i_f_res_postRnd;
	logic	[FPMIX_INTEGER_DW-1:0]			f2i_res_postRnd;
	logic									f2i_isOverflow_postRnd;
	logic									f2i_isUnderflow_postRnd;
	logic									f2i_isInvalid_postRnd;

	//	Busy flag
	logic									busy_r, busy_next;

//////////////////////////////////////////////////////////////////
//                       Sequential logic                       //
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			//	Input registers
			doAddSub_r			<=	1'b0;
			isOpSub_r			<=	1'b0;
			doMul_r				<=	1'b0;
			doDiv_r				<=	1'b0;
			doF2i_r				<=	1'b0;
			doI2f_r				<=	1'b0;
			isIntSigned_r		<=	1'b0;
			doCmpEq_r			<=	1'b0;
			doCmpLt_r			<=	1'b0;
			doCmpLe_r			<=	1'b0;
			flush_r				<=	1'b0;
			opcode_r			<=	FPU_IDLE;
			rndMode_r			<=	FPU_RNDMODE_NEAREST;
			op1_r				<=	'0;
			//	Output registers
			result_o			<=	'0;
			isResultValid_o		<=	1'b0;
			//	Width selection
			widthSel_r			<=	ADD_FLOAT_F_DW;
			//	Busy flag
			busy_r				<=	1'b0;
		end
		else
		begin
			//	Input registers
			doAddSub_r			<=	doAddSub_r_next;
			isOpSub_r			<=	isOpSub_r_next;
			doMul_r				<=	doMul_next;
			doDiv_r				<=	doDiv_next;
			doF2i_r				<=	doF2i_next;
			doI2f_r				<=	doI2f_next;
			isIntSigned_r		<=	isIntSigned_next;
			doCmpEq_r			<=	doCmpEq_next;
			doCmpLt_r			<=	doCmpLt_next;
			doCmpLe_r			<=	doCmpLe_next;
			flush_r				<=	flush_r_next;
			opcode_r			<=	opcode_r_next;
			rndMode_r			<=	rndMode_r_next;
			op1_r				<=	op1_r_next;
			//	Output registers
			result_o			<=	result_o_next;
			isResultValid_o		<=	isResultValid_o_next;
			//	Width selection
			widthSel_r			<=	widthSel_next;
			//	Busy flag
			busy_r				<=	busy_next;
		end
	end

//////////////////////////////////////////////////////////////////
//                     Combinational logic                      //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		doAddSub_r_next			=	1'b0;
		isOpSub_r_next			=	1'b0;
		doMul_next				=	1'b0;
		doDiv_next				=	1'b0;
		doF2i_next				=	1'b0;
		doI2f_next				=	1'b0;
		isIntSigned_next		=	isIntSigned_r;
		doCmpEq_next			=	1'b0;
		doCmpLt_next			=	1'b0;
		doCmpLe_next			=	1'b0;

		flush_r_next			=	flush_r;
		opcode_r_next			=	opcode_r;
		rndMode_r_next			=	rndMode_r;
		op1_r_next				=	op1_r;
		result_o_next			=	result_o;
		isResultValid_o_next	=	isResultValid_o;

		s_res					=	1'b0;
		e_res					=	'0;
		f_res					=	'0;
		isOverflow				=	1'b0;
		isUnderflow				=	1'b0;
		isToRound				=	1'b0;

		res						=	'0;
		isResValid				=	1'b0;

		widthSel_next			=	widthSel_r;

		busy_next				=	busy_r;

		if (opcode_i != FPU_IDLE && !flush_i && !busy_r)
		begin
			case (opcode_i)
				FPU_ADD	:
				begin
							doAddSub_r_next		=	1'b1;
							isOpSub_r_next		=	1'b0;
							widthSel_next		=	ADD_FLOAT_F_DW;
				end
				FPU_SUB	:
				begin
							doAddSub_r_next		=	1'b1;
							isOpSub_r_next		=	1'b1;
							widthSel_next		=	ADD_FLOAT_F_DW;
				end
				FPU_MUL	:
				begin
							doMul_next			=	1'b1;
							widthSel_next		=	MUL_FLOAT_F_DW;
				end
				FPU_DIV	:
				begin
							doDiv_next			=	1'b1;
							widthSel_next		=	DIV_FLOAT_F_DW;
				end
				FPU_F2I	:
				begin
							doF2i_next			=	1'b1;
							isIntSigned_next	=	1'b1;
							widthSel_next		=	F2I_FLOAT_F_DW;
				end
				FPU_F2U	:
				begin
							doF2i_next			=	1'b1;
							isIntSigned_next	=	1'b0;
							widthSel_next		=	F2I_FLOAT_F_DW;
				end
				FPU_I2F	:
				begin
							doI2f_next			=	1'b1;
							isIntSigned_next	=	1'b1;
							widthSel_next		=	I2F_FLOAT_F_DW;
				end
				FPU_U2F	:
				begin
							doI2f_next			=	1'b1;
							isIntSigned_next	=	1'b0;
							widthSel_next		=	I2F_FLOAT_F_DW;
				end
				FPU_EQ	:	doCmpEq_next		=	1'b1;
				FPU_LT	:	doCmpLt_next		=	1'b1;
				FPU_LE	:	doCmpLe_next		=	1'b1;
			endcase
			flush_r_next					=	'0;
			opcode_r_next					=	opcode_i;
			rndMode_r_next					=	rndMode_i;
			op1_r_next						=	op1_i;
			busy_next						=	1'b1;
		end

		case (opcode_r)
			FPU_ADD, FPU_SUB:
			begin
				s_res						=	addsub_s_res;
				e_res						=	addsub_e_res;
				f_res						=	{addsub_f_res, {(FPMIX_FLOAT_F_DW-ADD_FLOAT_F_DW){1'b0}}};
				isOverflow					=	addsub_isOverflow;
				isUnderflow					=	addsub_isUnderflow;
				isToRound					=	addsub_isToRound;
				res							=	{res_postRnd, {(FPMIX_INTEGER_DW-FPMIX_FLOAT_DW){1'b0}}};
				isResValid					=	addsub_valid;
			end
			FPU_MUL:
			begin
				s_res						=	mul_s_res;
				e_res						=	mul_e_res;
				f_res						=	{mul_f_res, {(FPMIX_FLOAT_F_DW-MUL_FLOAT_F_DW){1'b0}}};
				isOverflow					=	mul_isOverflow;
				isUnderflow					=	mul_isUnderflow;
				isToRound					=	mul_isToRound;
				res							=	{res_postRnd, {(FPMIX_INTEGER_DW-FPMIX_FLOAT_DW){1'b0}}};
				isResValid					=	mul_valid;
			end
			FPU_DIV:
			begin
				s_res						=	div_s_res;
				e_res						=	div_e_res;
				f_res						=	{div_f_res, {(FPMIX_FLOAT_F_DW-DIV_FLOAT_F_DW){1'b0}}};
				isOverflow					=	div_isOverflow;
				isUnderflow					=	div_isUnderflow;
				isToRound					=	div_isToRound;
				res							=	{res_postRnd, {(FPMIX_INTEGER_DW-FPMIX_FLOAT_DW){1'b0}}};
				isResValid					=	div_valid;
			end
			FPU_F2I, FPU_F2U:
			begin
				res							=	f2i_res_postRnd;
				isResValid					=	f2i_valid;
			end
			FPU_I2F, FPU_U2F:
			begin
				s_res						=	i2f_s_res;
				e_res						=	i2f_e_res;
				f_res						=	{i2f_f_res, {(FPMIX_FLOAT_F_DW-I2F_FLOAT_F_DW){1'b0}}};
				isOverflow					=	i2f_isOverflow;
				isUnderflow					=	i2f_isUnderflow;
				isToRound					=	i2f_isToRound;
				res							=	{res_postRnd, {(FPMIX_INTEGER_DW-FPMIX_FLOAT_DW){1'b0}}};
				isResValid					=	i2f_valid;
			end
			FPU_EQ, FPU_LT, FPU_LE:
			begin
				res							=	{{(FPMIX_INTEGER_DW-1){1'b0}}, cmp_res};
				isResValid					=	cmp_isResValid;
			end
			FPU_BYPASS:
			begin
				res							=	op1_r;
				isResValid					=	1'b1;
			end
			FPU_FSGNJS, FPU_FSGNJNS, FPU_FSGNJXS:
			begin
				case(opcode_r)
					FPU_FSGNJS:		res		=	{s_op2_r			, op1_r[FPMIX_INTEGER_DW-2:0]};
					FPU_FSGNJNS:	res		=	{~s_op2_r			, op1_r[FPMIX_INTEGER_DW-2:0]};
					FPU_FSGNJXS:	res		=	{s_op1_r ^ s_op2_r	, op1_r[FPMIX_INTEGER_DW-2:0]};
				endcase
				isResValid					=	1'b1;
			end
		endcase

		if (isResValid)
		begin
			result_o_next					=	res;
			isResultValid_o_next			=	1'b1;
		end

		if (isResultValid_o & padv_i)
		begin
			busy_next						=	1'b0;
			isResultValid_o_next			=	1'b0;
		end
	end

//////////////////////////////////////////////////////////////////
//          Operands pre-processing - Sequential logic          //
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			s_op1_r			<=	'0;
			e_op1_r			<=	'0;
			f_op1_r			<=	'0;
			extF_op1_r		<=	'0;
			extE_op1_r		<=	'0;
			isInf_op1_r		<=	'0;
			isZ_op1_r		<=	'0;
			isSNAN_op1_r	<=	'0;
			isQNAN_op1_r	<=	'0;
			s_op2_r			<=	'0;
			e_op2_r			<=	'0;
			f_op2_r			<=	'0;
			extF_op2_r		<=	'0;
			extE_op2_r		<=	'0;
			isInf_op2_r		<=	'0;
			isZ_op2_r		<=	'0;
			isSNAN_op2_r	<=	'0;
			isQNAN_op2_r	<=	'0;
			//	Add/sub-only
			op1_GT_op2_r	<=	'0;
			e_diff_r		<=	'0;
			//	Mul-div-only
			extShF_op1_r	<=	'0;
			nlz_op1_r		<=	'0;
			extShF_op2_r	<=	'0;
			nlz_op2_r		<=	'0;
		end
		else
		begin
			s_op1_r			<=	s_op1_wire;
			e_op1_r			<=	e_op1_wire;
			f_op1_r			<=	f_op1_wire;
			extF_op1_r		<=	extF_op1_wire;
			extE_op1_r		<=	extE_op1_wire;
			isInf_op1_r		<=	isInf_op1_wire;
			isZ_op1_r		<=	isZ_op1_wire;
			isSNAN_op1_r	<=	isSNAN_op1_wire;
			isQNAN_op1_r	<=	isQNAN_op1_wire;
			s_op2_r			<=	s_op2_wire;
			e_op2_r			<=	e_op2_wire;
			f_op2_r			<=	f_op2_wire;
			extF_op2_r		<=	extF_op2_wire;
			extE_op2_r		<=	extE_op2_wire;
			isInf_op2_r		<=	isInf_op2_wire;
			isZ_op2_r		<=	isZ_op2_wire;
			isSNAN_op2_r	<=	isSNAN_op2_wire;
			isQNAN_op2_r	<=	isQNAN_op2_wire;
			//	Add/sub-only
			op1_GT_op2_r	<=	op1_GT_op2_wire;
			e_diff_r		<=	e_diff_wire;
			//	Mul-div-only
			extShF_op1_r	<=	preMulDiv_extShFract1_by_w[widthSel_r];
			nlz_op1_r		<=	preMulDiv_numLeadingZeros1_by_w[widthSel_r];
			extShF_op2_r	<=	preMulDiv_extShFract2_by_w[widthSel_r];
			nlz_op2_r		<=	preMulDiv_numLeadingZeros2_by_w[widthSel_r];
		end
	end

//////////////////////////////////////////////////////////////////
//          Operands pre-processing - Wire assignments          //
//////////////////////////////////////////////////////////////////

	genvar w;
	for (w = MIN_F_DW; w <= MAX_F_DW; w++)
	begin : GENOP1DECODE_W
		if (WIDTH_USED_MASK[w])
		begin : USED
			logic	[FPMIX_FLOAT_E_DW-1:0]		e_w;
			logic	[w-1:0]						f_w;

			logic								isDN_w;
			logic								isZ_w;
			logic	[1+FPMIX_FLOAT_E_DW-1:0]	extE_w;
			logic	[1+FPMIX_FLOAT_F_DW-1:0]	extF_w;

			assign	e_w					=	e_op1_wire;
			assign	f_w					=	f_op1_wire[FPMIX_FLOAT_F_DW-1 -: w];
			assign	isDN_w				=	~(|e_w) & (|f_w);
			assign	isZ_w				=	~(|e_w) & ~(|f_w);
			assign	extE_w				=	{1'b0, e_w[FPMIX_FLOAT_E_DW-1:1], (e_w[0] | isDN_w)};
			assign	extF_w				=	{(~isDN_w & ~isZ_w), f_w, {(FPMIX_FLOAT_F_DW - w){1'b0}}};
			assign	extE_op1_by_w[w]	=	extE_w;
			assign	extF_op1_by_w[w]	=	extF_w;
			assign	isDN_op1_by_w[w]	=	isDN_w;
			assign	isZ_op1_by_w[w]		=	isZ_w;
		end
		else
		begin : UNUSED
			// Tie off to avoid X if indexed accidentally
			assign	extE_op1_by_w[w]	=	'0;
			assign	extF_op1_by_w[w]	=	'0;
			assign	isDN_op1_by_w[w]	=	1'b0;
			assign	isZ_op1_by_w[w]		=	1'b0;
		end
	end

	for (w = MIN_F_DW; w <= MAX_F_DW; w++)
	begin : GENOP2DECODE_W
		if (WIDTH_USED_MASK[w])
		begin : USED
			logic	[FPMIX_FLOAT_E_DW-1:0]		e_w;
			logic	[w-1:0]						f_w;
			logic								isDN_w;
			logic								isZ_w;
			logic	[1+FPMIX_FLOAT_E_DW-1:0]	extE_w;
			logic	[1+FPMIX_FLOAT_F_DW-1:0]	extF_w;

			assign	e_w					=	e_op2_wire;
			assign	f_w					=	f_op2_wire[FPMIX_FLOAT_F_DW-1 -: w];
			assign	isDN_w				=	~(|e_w) & (|f_w);
			assign	isZ_w				=	~(|e_w) & ~(|f_w);
			assign	extE_w				=	{1'b0, e_w[FPMIX_FLOAT_E_DW-1:1], (e_w[0] | isDN_w)};
			assign	extF_w				=	{(~isDN_w & ~isZ_w), f_w, {(FPMIX_FLOAT_F_DW - w){1'b0}}};
			assign	extE_op2_by_w[w]	=	extE_w;
			assign	extF_op2_by_w[w]	=	extF_w;
			assign	isDN_op2_by_w[w]	=	isDN_w;
			assign	isZ_op2_by_w[w]		=	isZ_w;
		end
		else
		begin : UNUSED
			// Tie off to avoid X if indexed accidentally
			assign	extE_op2_by_w[w]	=	'0;
			assign	extF_op2_by_w[w]	=	'0;
			assign	isDN_op2_by_w[w]	=	1'b0;
			assign	isZ_op2_by_w[w]		=	1'b0;
		end
	end

//////////////////////////////////////////////////////////////////
//        Operands pre-processing - Combinational logic         //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		// Split operand #1
		{s_op1_wire, e_op1_wire, f_op1_wire}	=	op1_i[(FPMIX_INTEGER_DW-1)-:FPMIX_FLOAT_DW];
		// Check operand #1: deNorm (isDN), +/-inf (isInf), +/-zero (isZ), not a number (isSNaN, isQNaN)
		isInf_op1_wire							=	(&e_op1_wire) &  ~(|f_op1_wire);
		isDN_op1_wire							=	isDN_op1_by_w[widthSel_r];
		isZ_op1_wire							=	isZ_op1_by_w[widthSel_r];
		isSNAN_op1_wire							=	(&e_op1_wire) & ~f_op1_wire[FPMIX_FLOAT_F_DW-1] & (|f_op1_wire[FPMIX_FLOAT_F_DW-2:0]);
		isQNAN_op1_wire							=	(&e_op1_wire) & f_op1_wire[FPMIX_FLOAT_F_DW-1];
		// Extend operand #1
		extE_op1_wire							=	extE_op1_by_w[widthSel_r];
		extF_op1_wire							=	extF_op1_by_w[widthSel_r];

		// Split, check and extend operand #2
		{s_op2_wire, e_op2_wire, f_op2_wire}	=	op2_i[(FPMIX_INTEGER_DW-1)-:FPMIX_FLOAT_DW];
		isInf_op2_wire							=	(&e_op2_wire) &  ~(|f_op2_wire);
		isDN_op2_wire							=	isDN_op2_by_w[widthSel_r];
		isZ_op2_wire							=	isZ_op2_by_w[widthSel_r];
		isSNAN_op2_wire							=	(&e_op2_wire) & ~f_op2_wire[FPMIX_FLOAT_F_DW-1] & (|f_op2_wire[FPMIX_FLOAT_F_DW-2:0]);
		isQNAN_op2_wire							=	(&e_op2_wire) & f_op2_wire[FPMIX_FLOAT_F_DW-1];
		extE_op2_wire							=	extE_op2_by_w[widthSel_r];
		extF_op2_wire							=	extF_op2_by_w[widthSel_r];

		//	Add/sub-only
		op1_GT_op2_wire							=	{extE_op1_wire, extF_op1_wire[1+FPMIX_FLOAT_F_DW-1 -: (1+ADD_FLOAT_F_DW)]} > {extE_op2_wire, extF_op2_wire[1+FPMIX_FLOAT_F_DW-1 -: (1+ADD_FLOAT_F_DW)]};
		e_diff_wire								=	op1_GT_op2_wire ? (extE_op1_wire - extE_op2_wire) : (extE_op2_wire - extE_op1_wire);
	end

	assign	isReady_o	=	(opcode_i == FPU_IDLE) | isResultValid_o;

//////////////////////////////////////////////////////////////////
//        Floating-point rounding - Combinational logic         //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		if (isToRound)
			res_postRnd	=	{s_res, rnd_e_res_by_w[widthSel_r], rnd_f_res_by_w[widthSel_r]};
		else
			res_postRnd	=	{s_res, e_res, f_res[5+:FPMIX_FLOAT_F_DW]};
	end

//////////////////////////////////////////////////////////////////
//            Integer rounding - Combinational logic            //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		f2i_res_postRnd			=	(intRnd_int_res_postRnd ^ {FPMIX_INTEGER_DW{f2i_s_res}}) + f2i_s_res;
		f2i_isInvalid_postRnd	=	((~f2i_s_res) & intRnd_int_res_postRnd[FPMIX_INTEGER_DW-1]) | f2i_isOverflow | f2i_isSNaN;
	end

//////////////////////////////////////////////////////////////////
//                     Internal submodules                      //
//////////////////////////////////////////////////////////////////

	fpmix_addsub #(
		.FLOAT_S_DW			(FPMIX_FLOAT_S_DW),
		.FLOAT_E_DW			(FPMIX_FLOAT_E_DW),
		.FLOAT_F_DW			(ADD_FLOAT_F_DW)
	) fpmix_addsub0 (
		.clk				(clk),
		.rst				(rst),
		.doAddSub_i			(doAddSub_r),
		.isOpSub_i			(isOpSub_r),
		.s_op1_i			(s_op1_r),
		.extF_op1_i			(extF_op1_r[((1+FPMIX_FLOAT_F_DW)-1)-:(1+ADD_FLOAT_F_DW)]),
		.extE_op1_i			(extE_op1_r),
		.isInf_op1_i		(isInf_op1_r),
		.isSNAN_op1_i		(isSNAN_op1_r),
		.isQNAN_op1_i		(isQNAN_op1_r),
		.s_op2_i			(s_op2_r),
		.extF_op2_i			(extF_op2_r[((1+FPMIX_FLOAT_F_DW)-1)-:(1+ADD_FLOAT_F_DW)]),
		.extE_op2_i			(extE_op2_r),
		.isInf_op2_i		(isInf_op2_r),
		.isSNAN_op2_i		(isSNAN_op2_r),
		.isQNAN_op2_i		(isQNAN_op2_r),
		.op1_GT_op2_i		(op1_GT_op2_r),
		.e_diff_i			(e_diff_r),
		.s_res_o			(addsub_s_res),
		.e_res_o			(addsub_e_res),
		.f_res_o			(addsub_f_res),
		.valid_o			(addsub_valid),
		.isOverflow_o		(addsub_isOverflow),
		.isUnderflow_o		(addsub_isUnderflow),
		.isToRound_o		(addsub_isToRound)
	);

	fpmix_mul #(
		.FLOAT_S_DW			(FPMIX_FLOAT_S_DW),
		.FLOAT_E_DW			(FPMIX_FLOAT_E_DW),
		.FLOAT_F_DW			(MUL_FLOAT_F_DW)
	) fpmix_mul0 (
		.clk				(clk),
		.rst				(rst),
		.doMul_i			(doMul_r),
		.s_op1_i			(s_op1_r),
		.extShF_op1_i		(extShF_op1_r[((1+FPMIX_FLOAT_F_DW)-1)-:(1+MUL_FLOAT_F_DW)]),
		.extE_op1_i			(extE_op1_r),
		.nlz_op1_i			(nlz_op1_r[$clog2(MUL_FLOAT_F_DW)-1:0]),
		.isZ_op1_i			(isZ_op1_r),
		.isInf_op1_i		(isInf_op1_r),
		.isSNAN_op1_i		(isSNAN_op1_r),
		.isQNAN_op1_i		(isQNAN_op1_r),
		.s_op2_i			(s_op2_r),
		.extShF_op2_i		(extShF_op2_r[((1+FPMIX_FLOAT_F_DW)-1)-:(1+MUL_FLOAT_F_DW)]),
		.extE_op2_i			(extE_op2_r),
		.nlz_op2_i			(nlz_op2_r[$clog2(MUL_FLOAT_F_DW)-1:0]),
		.isZ_op2_i			(isZ_op2_r),
		.isInf_op2_i		(isInf_op2_r),
		.isSNAN_op2_i		(isSNAN_op2_r),
		.isQNAN_op2_i		(isQNAN_op2_r),
		.s_res_o			(mul_s_res),
		.e_res_o			(mul_e_res),
		.f_res_o			(mul_f_res),
		.valid_o			(mul_valid),
		.isOverflow_o		(mul_isOverflow),
		.isUnderflow_o		(mul_isUnderflow),
		.isToRound_o		(mul_isToRound)
	);

	fpmix_div #(
		.FLOAT_S_DW			(FPMIX_FLOAT_S_DW),
		.FLOAT_E_DW			(FPMIX_FLOAT_E_DW),
		.FLOAT_F_DW			(DIV_FLOAT_F_DW),
		.APPROX_DW			(DIV_APPROX_DW),
		.PREC_DW			(DIV_PREC_DW)
	) fpmix_div0 (
		.clk				(clk),
		.rst				(rst),
		.doDiv_i			(doDiv_r),
		.s_op1_i			(s_op1_r),
		.extShF_op1_i		(extShF_op1_r[((1+FPMIX_FLOAT_F_DW)-1)-:(1+DIV_FLOAT_F_DW)]),
		.extE_op1_i			(extE_op1_r),
		.nlz_op1_i			(nlz_op1_r[$clog2(DIV_FLOAT_F_DW)-1:0]),
		.isZ_op1_i			(isZ_op1_r),
		.isInf_op1_i		(isInf_op1_r),
		.isSNAN_op1_i		(isSNAN_op1_r),
		.isQNAN_op1_i		(isQNAN_op1_r),
		.s_op2_i			(s_op2_r),
		.extShF_op2_i		(extShF_op2_r[((1+FPMIX_FLOAT_F_DW)-1)-:(1+DIV_FLOAT_F_DW)]),
		.extE_op2_i			(extE_op2_r),
		.nlz_op2_i			(nlz_op2_r[$clog2(DIV_FLOAT_F_DW)-1:0]),
		.isZ_op2_i			(isZ_op2_r),
		.isInf_op2_i		(isInf_op2_r),
		.isSNAN_op2_i		(isSNAN_op2_r),
		.isQNAN_op2_i		(isQNAN_op2_r),
		.s_res_o			(div_s_res),
		.e_res_o			(div_e_res),
		.f_res_o			(div_f_res),
		.valid_o			(div_valid),
		.isOverflow_o		(div_isOverflow),
		.isUnderflow_o		(div_isUnderflow),
		.isToRound_o		(div_isToRound)
	);

	fpmix_f2i #(
		.FLOAT_S_DW			(FPMIX_FLOAT_S_DW),
		.FLOAT_E_DW			(FPMIX_FLOAT_E_DW),
		.FLOAT_F_DW			(F2I_FLOAT_F_DW),
		.INTEGER_DW			(FPMIX_INTEGER_DW)
	) fpmix_f2i0 (
		.clk				(clk),
		.rst				(rst),
		.doF2i_i			(doF2i_r),
		.isIntSigned_i		(isIntSigned_r),
		.s_op1_i			(s_op1_r),
		.extF_op1_i			(extF_op1_r[((1+FPMIX_FLOAT_F_DW)-1)-:(1+F2I_FLOAT_F_DW)]),
		.extE_op1_i			(extE_op1_r),
		.isSNAN_op1_i		(isSNAN_op1_r),
		.isQNAN_op1_i		(isQNAN_op1_r),
		.s_res_o			(f2i_s_res),
		.f_res_o			(f2i_f_res),
		.valid_o			(f2i_valid),
		.isOverflow_o		(f2i_isOverflow),
		.isUnderflow_o		(f2i_isUnderflow),
		.isSNaN_o			(f2i_isSNaN)
	);

	fpmix_i2f #(
		.FLOAT_S_DW			(FPMIX_FLOAT_S_DW),
		.FLOAT_E_DW			(FPMIX_FLOAT_E_DW),
		.FLOAT_F_DW			(I2F_FLOAT_F_DW),
		.INTEGER_DW			(FPMIX_INTEGER_DW)
	) fpmix_i2f0 (
		.clk				(clk),
		.rst				(rst),
		.doI2f_i			(doI2f_r),
		.isIntSigned_i		(isIntSigned_r),
		.op1_i				(op1_r),
		.s_res_o			(i2f_s_res),
		.e_res_o			(i2f_e_res),
		.f_res_o			(i2f_f_res),
		.valid_o			(i2f_valid),
		.isOverflow_o		(i2f_isOverflow),
		.isUnderflow_o		(i2f_isUnderflow),
		.isToRound_o		(i2f_isToRound)
	);

	fpmix_cmp #(
		.FLOAT_S_DW			(FPMIX_FLOAT_S_DW),
		.FLOAT_E_DW			(FPMIX_FLOAT_E_DW),
		.FLOAT_F_DW			(CMP_FLOAT_F_DW)
	) fpmix_cmp0 (
		.clk				(clk),
		.doEq_i				(doCmpEq_r),
		.doLt_i				(doCmpLt_r),
		.doLe_i				(doCmpLe_r),
		.opASign_i			(s_op1_r),
		.opAExp_i			(e_op1_r),
		.opAFract_i			(f_op1_r[(FPMIX_FLOAT_F_DW-1)-:CMP_FLOAT_F_DW]),
		.opBSign_i			(s_op2_r),
		.opBExp_i			(e_op2_r),
		.opBFract_i			(f_op2_r[(FPMIX_FLOAT_F_DW-1)-:CMP_FLOAT_F_DW]),
		.isAZer_i			(isZ_op1_r),
		.isASNaN_i			(isSNAN_op1_r),
		.isAQNaN_i			(isQNAN_op1_r),
		.isBZer_i			(isZ_op2_r),
		.isBSNaN_i			(isSNAN_op2_r),
		.isBQNaN_i			(isQNAN_op2_r),
		.cmp_o				(cmp_res),
		.isCmpValid_o		(cmp_isResValid),
		.isCmpInvalid_o		(cmp_isCmpInvalid)
	);

	for (w = MIN_F_DW; w <= MAX_F_DW; w++)
	begin : GEN_PRE_MULDIV_W
		if (WIDTH_USED_MASK[w])
		begin : USED
			// Narrowed ext fract inputs for this width
			logic	[1+w-1:0]	extFract1_w;
			logic	[1+w-1:0]	extFract2_w;

			// Outputs of this preMulDiv instance
			logic	[$clog2(1+w)-1:0]	numLeadingZeros1_w;
			logic	[1+w-1:0]			extShFract1_w;
			logic	[$clog2(1+w)-1:0]	numLeadingZeros2_w;
			logic	[1+w-1:0]			extShFract2_w;

			// Narrow the generic extended fraction coming from operand preprocessing
			assign	extFract1_w	=	extF_op1_wire[1+FPMIX_FLOAT_F_DW-1 -: (1+w)];
			assign	extFract2_w	=	extF_op2_wire[1+FPMIX_FLOAT_F_DW-1 -: (1+w)];

			fpmix_preMulDiv #(
				.FRACT_DW			(w)
			) u_preMulDiv_w (
				.extFract1_i		(extFract1_w),
				.extFract2_i		(extFract2_w),
				.numLeadingZeros1_o	(numLeadingZeros1_w),
				.extShFract1_o		(extShFract1_w),
				.numLeadingZeros2_o	(numLeadingZeros2_w),
				.extShFract2_o		(extShFract2_w)
			);

			assign	preMulDiv_numLeadingZeros1_by_w[w]	=	{{($clog2(1+FPMIX_FLOAT_F_DW) - $clog2(1+w)){1'b0}},numLeadingZeros1_w};
			assign	preMulDiv_extShFract1_by_w[w]		=	{extShFract1_w,{(FPMIX_FLOAT_F_DW - w){1'b0}}};
			assign	preMulDiv_numLeadingZeros2_by_w[w]	=	{{($clog2(1+FPMIX_FLOAT_F_DW) - $clog2(1+w)){1'b0}},numLeadingZeros2_w};
			assign	preMulDiv_extShFract2_by_w[w]		=	{extShFract2_w,{(FPMIX_FLOAT_F_DW - w){1'b0}}};
		end
		else
		begin : UNUSED
			// Tie off to avoid X if indexed accidentally
			assign	preMulDiv_numLeadingZeros1_by_w[w]	=	'0;
			assign	preMulDiv_extShFract1_by_w[w]		=	'0;
			assign	preMulDiv_numLeadingZeros2_by_w[w]	=	'0;
			assign	preMulDiv_extShFract2_by_w[w]		=	'0;
		end
	end

	for (w = MIN_F_DW; w <= MAX_F_DW; w++)
	begin : GEN_RND_W
		if (WIDTH_USED_MASK[w])
		begin : USED
			logic	[(w+5)-1:0]	f_res_in_narrow;
			logic	[w-1:0]		f_res_out_narrow;

			assign	f_res_in_narrow		=	f_res[((FPMIX_FLOAT_F_DW+5)-1) -: (w+5)];

			fpmix_floatRnd #(
				.FLOAT_E_DW			(FPMIX_FLOAT_E_DW),
				.FLOAT_F_DW			(w)
			) u_rnd_w (
				.rndMode_i			(rndMode_r),
				.e_res_postNorm_i	(e_res),
				.f_res_postNorm_i	(f_res_in_narrow),
				.e_res_postRnd_o	(rnd_e_res_by_w[w]),
				.f_res_postRnd_o	(f_res_out_narrow)
			);

			assign rnd_f_res_by_w[w]	=	{f_res_out_narrow, {(FPMIX_FLOAT_F_DW-w){1'b0}}};
		end
		else
		begin : UNUSED
			// Tie off to avoid X if indexed accidentally
			assign	rnd_e_res_by_w[w]	=	'0;
			assign	rnd_f_res_by_w[w]	=	'0;
		end
	end

	fpmix_intRnd #(
		.INT_DW				(FPMIX_INTEGER_DW)
	) fpmix_intRnd0 (
		.rndMode_i			(rndMode_r),
		.int_res_preRnd_i	(f2i_f_res),
		.int_res_postRnd_o	(intRnd_int_res_postRnd)
	);

endmodule
