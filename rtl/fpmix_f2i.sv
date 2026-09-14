// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_f2i #(
	FLOAT_S_DW		=	1,
	FLOAT_E_DW		=	8,
	FLOAT_F_DW		=	23,
	INTEGER_DW		=	32
)(
	clk, rst,
	//	Inputs
	doF2i_i, isIntSigned_i,
	s_op1_i, extF_op1_i, extE_op1_i,
	isSNAN_op1_i, isQNAN_op1_i,
	//	Outputs
	s_res_o, f_res_o, valid_o,
	isOverflow_o, isUnderflow_o, isSNaN_o
);

localparam INTEGER_S_DW	=	1;
localparam INTEGER_F_DW	=	INTEGER_DW -1;
localparam FLOAT_E_BIAS	=	(2 ** (FLOAT_E_DW - 1)) - 1;

input									clk;
input									rst;
//	Inputs
input									doF2i_i;
input									isIntSigned_i;
input			[FLOAT_S_DW-1:0]		s_op1_i;
input			[(FLOAT_F_DW+1)-1:0]	extF_op1_i;
input			[(FLOAT_E_DW+1)-1:0]	extE_op1_i;
input									isSNAN_op1_i;
input									isQNAN_op1_i;
//	Outputs
output	logic							s_res_o;
output	logic	[(INTEGER_DW+3)-1:0]	f_res_o;
output	logic							valid_o;
output	logic							isOverflow_o;
output	logic							isUnderflow_o;
output	logic							isSNaN_o;

//////////////////////////////////////////////////////////////////
//                        Internal wires                        //
//////////////////////////////////////////////////////////////////

	logic	[$clog2(INTEGER_F_DW)-1:0]	shiftLeft;
	logic	[$clog2(INTEGER_F_DW)-1:0]	shiftRight;
	logic								isShiftRight;
	logic								isOverflow_temp;
	logic	[INTEGER_S_DW-1:0]			intResSign;
	logic	[(INTEGER_DW+3)-1:0] 		floatFractExt;
	logic	[(INTEGER_DW+3)-1:0] 		floatFractExtSh;

	// Post-normalization wires/regs
	logic	[FLOAT_S_DW-1:0]			s_res_postNorm;
	logic	[(INTEGER_DW+3)-1:0]		f_res_postNorm;
	logic								isOverflow_postNorm;
	logic								isUnderflow_postNorm;

	//	Output next values
	logic								s_res;
	logic	[(INTEGER_DW+3)-1:0] 		f_res;
	logic								valid;
	logic								isOverflow;
	logic								isUnderflow;
	logic								isSNaN;

//////////////////////////////////////////////////////////////////
//                       Sequential logic                       //
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			//	Output registers
			s_res_o			<=	'0;
			f_res_o			<=	'0;
			valid_o			<=	'0;
			isOverflow_o	<=	'0;
			isUnderflow_o	<=	'0;
			isSNaN_o		<=	'0;	
		end
		else
		begin
			//	Output registers
			s_res_o			<=	s_res;
			f_res_o			<=	f_res;
			valid_o			<=	valid;
			isOverflow_o	<=	isOverflow;
			isUnderflow_o	<=	isUnderflow;
			isSNaN_o		<=	isSNaN;	
		end
	end

//////////////////////////////////////////////////////////////////
//                     Combinational logic                      //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		shiftLeft				=	'0;
		shiftRight				=	'0;
		isShiftRight			=	1'b0;
		isOverflow_temp			=	1'b0;
		if (extE_op1_i < (FLOAT_E_BIAS + FLOAT_F_DW - INTEGER_F_DW))
		begin
			shiftRight			=	INTEGER_F_DW;
			isShiftRight		=	1'b1;
		end
		else if (extE_op1_i < (FLOAT_E_BIAS + FLOAT_F_DW))
		begin
			shiftRight			=	FLOAT_E_BIAS + FLOAT_F_DW - extE_op1_i;
			isShiftRight		=	1'b1;
		end
		else if ((isIntSigned_i &&
						(extE_op1_i < (FLOAT_E_BIAS + INTEGER_F_DW) ||							
							(s_op1_i == '1 && extE_op1_i == (FLOAT_E_BIAS + INTEGER_F_DW) &&
							extF_op1_i[(FLOAT_F_DW+1)-1] == '1 && extF_op1_i[(FLOAT_F_DW+1)-2:0] == '0))) ||
				(~isIntSigned_i &&
						(extE_op1_i <= (FLOAT_E_BIAS + INTEGER_F_DW))))
		begin
			shiftLeft			=	extE_op1_i - FLOAT_E_BIAS - FLOAT_F_DW;
		end
		else
		begin
			isOverflow_temp		=	1'b1;
		end

		intResSign				=	s_op1_i && (~(isQNAN_op1_i | isSNAN_op1_i));
		floatFractExt			=	extF_op1_i << 3;

		if (isShiftRight)
			floatFractExtSh		=	floatFractExt >> shiftRight;
		else
			floatFractExtSh		=	floatFractExt << shiftLeft;
		
		// Sticky bit computation
		floatFractExtSh[1] = 1'b0;
		for (int i = 0; i < INTEGER_DW; i++) begin
			if (shiftRight >= i + 3)
				floatFractExtSh[1] |= floatFractExt[3 + i];
		end

		s_res_postNorm			=	intResSign;
		f_res_postNorm			=	floatFractExtSh;
		isOverflow_postNorm		=	isOverflow_temp;
		isUnderflow_postNorm	=	1'b0;

		s_res					=	s_res_postNorm;
		if (isOverflow_postNorm)
			f_res				=	{1'b1,{(INTEGER_F_DW+3){1'b0}}};
		else
			f_res				=	f_res_postNorm;
		valid					=	doF2i_i;
		isOverflow				=	isOverflow_postNorm;
		isUnderflow				=	isUnderflow_postNorm;
		isSNaN					=	isSNAN_op1_i;
	end

endmodule
