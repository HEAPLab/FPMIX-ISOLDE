// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

package fpmix_pkg;

	//////////////////////////////////////
	//      FPMIX FPU configuration     //
	//////////////////////////////////////
	//	Integer format
	localparam FPMIX_INTEGER_DW		=	32;
	//	Baseline floating-point format
	/*****************************************
	** Supported values: ANY combination of **
	** FPMIX_FLOAT_E_DW, FPMIX_FLOAT_F_DW   **
	** such that their sum is less than     **
	** FPMIX_INTEGER_DW                     **
	*****************************************/
	localparam FPMIX_FLOAT_E_DW		=	8;
	localparam FPMIX_FLOAT_F_DW		=	23;
	//	Per-operation mantissa width
	/*****************************************
	** Supported values: ANY integer value  **
	** between 1 and FPMIX_FLOAT_F_DW       **
	**                                      **
	**  Tested configurations               **
	**  Standard IEEE 754    float32:   23  **
	**  Custom 24-bit        float24:   15  **
	**  DL-tailored 16-bit  bfloat16:    7  **
	**                                      **
	** These 3 FP formats share an exponent **
	** width FPMIX_FLOAT_E_DW of 8          **
	*****************************************/
	localparam ADD_FLOAT_F_DW		=	23;
	localparam MUL_FLOAT_F_DW		=	23;
	localparam DIV_FLOAT_F_DW		=	23;
	localparam F2I_FLOAT_F_DW		=	23;
	localparam I2F_FLOAT_F_DW		=	23;
	localparam CMP_FLOAT_F_DW		=	23;
	//	Goldschmidt divider
	/*****************************************
	** Supported DIV_APPROX_DW values: 6, 4 **
	**                                      **
	**  Tested configurations               **
	**  DIVISION FORMAT    APPROX    PREC   **
	**          float32       6        8    **
	**          float24       4        0    **
	**         bfloat16       4        0    **
	*****************************************/
	localparam DIV_APPROX_DW		=	6;
	localparam DIV_PREC_DW			=	8;

	//////////////////////////////////////
	//  Fixed parameters - DO NOT EDIT  //
	//////////////////////////////////////
	localparam FPMIX_FLOAT_S_DW		=	1;
	localparam FPMIX_FLOAT_DW		=	FPMIX_FLOAT_S_DW + FPMIX_FLOAT_E_DW + FPMIX_FLOAT_F_DW;
	localparam FPMIX_INTEGER_S_DW	=	1;
	localparam FPMIX_INTEGER_F_DW	=	FPMIX_INTEGER_DW - FPMIX_INTEGER_S_DW;

	////////////////////////////////////////////
	// Testbench-only constants - DO NOT EDIT //
	////////////////////////////////////////////
	localparam PLUS_INF				=	{1'b0,{FPMIX_FLOAT_E_DW{1'b1}},{FPMIX_FLOAT_F_DW{1'b0}}};
	localparam MINUS_INF			=	{1'b1,{FPMIX_FLOAT_E_DW{1'b1}},{FPMIX_FLOAT_F_DW{1'b0}}};
	localparam PLUS_ZERO			=	{1'b0,{FPMIX_FLOAT_E_DW{1'b0}},{FPMIX_FLOAT_F_DW{1'b0}}};
	localparam MINUS_ZERO			=	{1'b0,{FPMIX_FLOAT_E_DW{1'b0}},{FPMIX_FLOAT_F_DW{1'b0}}};
	localparam FPMIX_FLOAT_E_BIAS	=	(2 ** (FPMIX_FLOAT_E_DW - 1)) - 1;
	localparam FPMIX_FLOAT_E_MAX	=	(2 ** FPMIX_FLOAT_E_DW) - 1;

//////////////////////////////////////////////////////////////////
//                       FSM state enums                        //
//////////////////////////////////////////////////////////////////

	typedef enum logic [1:0]
	{
		SSDIV_IDLE	= 'd0,
		SSDIV_MUL	= 'd1,
		SSDIV_COMPL	= 'd2
	}	ssFractDiv_t;

//////////////////////////////////////////////////////////////////
//                      Rounding mode enum                      //
//////////////////////////////////////////////////////////////////

	typedef enum logic
	{
		FPU_RNDMODE_NEAREST		=	'd0,
		FPU_RNDMODE_TRUNCATE	=	'd1
	} rndModeFPU_t;

//////////////////////////////////////////////////////////////////
//                         Opcode enum                          //
//////////////////////////////////////////////////////////////////

	typedef enum logic[4:0]
	{
		FPU_IDLE	= 5'd0,

		FPU_I2F		= 5'd1,
		FPU_F2I		= 5'd2,

		FPU_ADD		= 5'd3,
		FPU_SUB		= 5'd4,
		FPU_MUL		= 5'd5,
		FPU_DIV		= 5'd6,

		FPU_SQRT	= 5'd7,	// reserved for future use
		FPU_INVERSE	= 5'd8,	// reserved for future use

		FPU_EQ		= 5'd9,
		FPU_LT		= 5'd10,
		FPU_LE		= 5'd11,
		
		FPU_BYPASS	= 5'd12,
		
		FPU_FSGNJS	= 5'd13,
		FPU_FSGNJNS	= 5'd14,
		FPU_FSGNJXS	= 5'd15,

		FPU_U2F		= 5'd16,
		FPU_F2U		= 5'd17
	} opcodeFPU_t;

//////////////////////////////////////////////////////////////////
//                       Helper functions                       //
//////////////////////////////////////////////////////////////////

	/*
	* Nan +/- X	  -> Nan
	* X   +/- Nan -> Nan
	* +inf + +inf -> +inf
	* +inf - -inf -> +inf
	* -inf - +inf -> -inf
	* -inf + -inf -> -inf
	* +inf - inf -> NAN
	* -inf + inf -> NAN
	*/
	function automatic logic[3:0] FUNC_calcInfNanResAddSub (
				input isOpSub_i,
				input isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
				input isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
			);

		logic realOp2_sign;
		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

		logic isValidRes, isInfRes, isNanRes, signRes;
		realOp2_sign 	= sign_op2_i ^ isOpSub_i;

		isValidRes 		= (isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
		if (isNan_op1)
		begin
			isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
		end
		else if (isNan_op2)
		begin
			isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
		end
		else // both are not NaN
		begin
			case({sign_op1_i, isInf_op1_i, realOp2_sign, isInf_op2_i})
				4'b00_00: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b00_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b00_10: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b00_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b01_00: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b01_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b01_10: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b01_11: begin isNanRes = 1; isInfRes = 0; signRes = 1; end //Nan - NOTE sign goes neg if one of the operands is neg
				4'b10_00: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b10_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b10_10: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b10_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b11_00: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b11_01: begin isNanRes = 1; isInfRes = 0; signRes = 1; end //Nan - NOTE sign goes neg if one of the operands is neg
				4'b11_10: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b11_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
			endcase
		end
		return {isValidRes, isInfRes, isNanRes, signRes};
	endfunction

	/*
	* 		Nan 	x 			X		-> 		 Nan
	* 		X 		x 			Nan 	-> 		 Nan
	* (+/-) inf 	x 	(+/-) 	inf 	-> (+/-) inf
	* (+/-) inf 	x 			0		-> 		 Nan
	* (+/-) inf		x 	(+/-)	X		-> (+/-) inf
	*/
	function automatic logic[4:0] FUNC_calcInfNanZeroResMul (
				input isZero_op1_i, isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
				input isZero_op2_i, isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
			);

		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

		logic isValidRes, isZeroRes, isInfRes, isNanRes, signRes;

		isValidRes	= (isZero_op1_i || isZero_op2_i || isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
		if (isNan_op1)
		begin
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
		end
		else if (isNan_op2)
		begin
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
		end
		else // both are not NaN
		begin
			case({isZero_op1_i, isZero_op2_i, isInf_op1_i,isInf_op2_i})
				4'b00_00: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end
				4'b00_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b00_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b00_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b01_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end	//TODO check sign of zero res
				4'b01_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end	//Impossible
				4'b01_10: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1; 						end	//TODO check sign of zero res
				4'b01_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b10_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b10_01: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1;						 	end
				4'b10_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b10_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b11_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
			endcase
		end
		return {isValidRes, isZeroRes, isInfRes, isNanRes, signRes};
	endfunction

	/*
	* 		Nan 	/ 			X		-> 		 Nan
	* 		X 		/ 			Nan 	-> (+/-) inf
	* (+/-)	inf		/ 			X 		-> (+/-) inf
	* 		X 		/ 	(+/-) 	inf 	-> (+/-) 0
	* (+/-) !0 		/ 	(+/-) 	0 		-> 		 inf
	* (+/-) 0 		/ 	(+/-) 	0 		-> 		 Nan
	* (+/-) inf 	/ 	(+/-) 	inf 	-> 		 Nan
	*/
	function automatic logic[4:0] FUNC_calcInfNanZeroResDiv (
				input isZero_op1_i, isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
				input isZero_op2_i, isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
			);

		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

		logic isValidRes, isZeroRes, isInfRes, isNanRes, signRes;

		isValidRes	= (isZero_op1_i || isZero_op2_i || isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
		if (isNan_op1)
		begin
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
		end
		else if (isNan_op2)
		begin
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
		end
		else // both are not NaN
		begin
			case({isZero_op1_i, isZero_op2_i, isInf_op1_i,isInf_op2_i})
				4'b00_00: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end
				4'b00_01: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i;	end //	x   / inf
				4'b00_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end //	inf	/ x
				4'b00_11: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end //	inf	/ inf
				4'b01_00: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end //	x   / 0
				4'b01_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //	Impossible
				4'b01_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end //	inf / 0
				4'b01_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //	Impossible
				4'b10_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end //	0   / x
				4'b10_01: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end //	0   / inf
				4'b10_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //	Impossible
				4'b10_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //	Impossible
				4'b11_00: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end //	0   / 0
				4'b11_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //	Impossible
				4'b11_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //	Impossible
				4'b11_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //	Impossible
			endcase
		end
		return {isValidRes, isZeroRes, isInfRes, isNanRes, signRes};
	endfunction

	localparam int MIN_F_DW = 1;
	localparam int MAX_F_DW = FPMIX_FLOAT_DW;

	function automatic logic [MAX_F_DW:MIN_F_DW] FUNC_widthUsedMask();
		logic [MAX_F_DW:MIN_F_DW] tmp;
		int w;
		begin
			tmp = '0;
			for (w = MIN_F_DW; w <= MAX_F_DW; w++)
			begin
				if (ADD_FLOAT_F_DW == w ||
				    MUL_FLOAT_F_DW == w ||
				    DIV_FLOAT_F_DW == w ||
				    F2I_FLOAT_F_DW == w ||
				    I2F_FLOAT_F_DW == w)
				begin
					tmp[w] = 1'b1;
				end
			end
			return tmp;
		end
	endfunction

	localparam logic [MAX_F_DW:MIN_F_DW] WIDTH_USED_MASK = FUNC_widthUsedMask();

endpackage
