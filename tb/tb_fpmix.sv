// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module tb_fpmix;

	import fpmix_pkg::*;

	parameter HALF_CLK_PERIOD_NS = 10;

	logic							clk;
	logic							rst;
	logic							flush;
	logic							padv;
	opcodeFPU_t						opcodeFPU_i_tb;
	rndModeFPU_t					rndMode_i_tb;
	logic	[FPMIX_INTEGER_DW-1:0]	op1_i_tb;
	logic	[FPMIX_INTEGER_DW-1:0]	op2_i_tb;
	logic	[FPMIX_INTEGER_DW-1:0]	result_o_tb;
	logic							isResultValid_o_tb;
	logic							isReady_o_tb;

	int numTest=0;

	always #HALF_CLK_PERIOD_NS clk = ~clk;

	fpmix_top
		fpmix_top0(
				.clk				(clk),
				.rst				(rst),
				.flush_i			(flush),
				.padv_i				(padv),
				.opcode_i			(opcodeFPU_i_tb),
				.rndMode_i			(rndMode_i_tb),
				.op1_i				(op1_i_tb),
				.op2_i				(op2_i_tb),
				.result_o			(result_o_tb),
				.isResultValid_o	(isResultValid_o_tb),
				.isReady_o			(isReady_o_tb)
			);

	initial
	begin
		$dumpfile("tb_fpmix.vcd");
		$dumpvars(0,tb_fpmix);
		clk				<=	1;
		rst				=	1;
		flush			=	0;
		padv			=	1;
		opcodeFPU_i_tb	=	FPU_IDLE;
		rndMode_i_tb	=	FPU_RNDMODE_NEAREST;
		op1_i_tb		=	'0;
		op2_i_tb		=	'0;

		repeat(10) @(posedge clk);
		rst <= 0;
		repeat(10) @(posedge clk);

		rndMode_i_tb	=	FPU_RNDMODE_NEAREST;
		$display("ADD");
		TASK_testArith (FPU_ADD);
		$display("SUB");
		TASK_testArith (FPU_SUB);
		$display("MUL");
		TASK_testArith (FPU_MUL);
		$display("DIV");
		TASK_testArith (FPU_DIV);
		$display("CMP");
		TASK_testCmp ();
		$display("I2F");
		TASK_testI2f ();
		$display("U2F");
		TASK_testU2f ();
		rndMode_i_tb	=	FPU_RNDMODE_TRUNCATE;
		$display("F2I");
		TASK_testF2i ();
		$display("F2U");
		TASK_testF2u ();
		repeat(200) @(posedge clk);
		$finish;
	end

	task TASK_testArith (input opcodeFPU_t opcode);
		logic	[FPMIX_FLOAT_S_DW-1:0]	op1_sign;
		logic	[FPMIX_FLOAT_E_DW-1:0]	op1_exponent;
		logic	[FPMIX_FLOAT_F_DW-1:0]	op1_fraction;

		logic	[FPMIX_FLOAT_S_DW-1:0]	op2_sign;
		logic	[FPMIX_FLOAT_E_DW-1:0]	op2_exponent;
		logic	[FPMIX_FLOAT_F_DW-1:0]	op2_fraction;

		int								numTest;

		numTest				=	0;
		repeat (10)
		begin
			@(posedge clk);
			numTest++;
			op1_sign		=	$urandom_range(0,1);
			op1_exponent	=	$urandom_range(0,255);
			op1_fraction	=	(op1_exponent>=0 && op1_exponent<255) ? $random : $urandom_range(0,1)<<(FPMIX_FLOAT_F_DW-1) /*inf or qnan*/;

			op2_sign		=	$urandom_range(0,1);
			op2_exponent	=	$urandom_range(0,255);
			op2_fraction	=	(op2_exponent>=0 && op2_exponent<255) ? $random : $urandom_range(0,1)<<(FPMIX_FLOAT_F_DW-1) /*inf or qnan*/;

			TASK_doArith_op (opcode, {op1_sign, op1_exponent, op1_fraction}, {op2_sign, op2_exponent, op2_fraction});
		end
	endtask

	task TASK_testI2f ();
		int	numTest;

		numTest	=	0;
		repeat (10)
		begin
			numTest++;
			@(posedge clk);
			TASK_doI2f_op ($random);
		end

		//	zero
		numTest++;
		@(posedge clk);
		TASK_doI2f_op (32'b00000000000000000000000000000000);

		//	max
		numTest++;
		@(posedge clk);
		TASK_doI2f_op (32'b01111111111111111111111111111111);

		//	min
		numTest++;
		@(posedge clk);
		TASK_doI2f_op (32'b10000000000000000000000000000000);
	endtask

	task TASK_testU2f ();
		int	numTest;

		numTest	=	0;
		repeat (10)
		begin
			numTest++;
			@(posedge clk);
			TASK_doU2f_op ($random);
		end

		//	zero
		numTest++;
		@(posedge clk);
		TASK_doI2f_op (32'b00000000000000000000000000000000);

		//	max
		numTest++;
		@(posedge clk);
		TASK_doI2f_op (32'b11111111111111111111111111111111);
	endtask

	task TASK_testF2i ();
		logic	[FPMIX_FLOAT_S_DW-1:0]	sign;
		logic	[FPMIX_FLOAT_E_DW-1:0]	exponent;
		logic	[FPMIX_FLOAT_F_DW-1:0]	fraction;
		int								numTest;

		numTest			=	0;
		repeat (10)
		begin
			@(posedge clk);
			numTest++;
			sign		=	$random;
			exponent	=	$urandom_range(0, FPMIX_FLOAT_E_BIAS + FPMIX_INTEGER_F_DW - 1);
			fraction	=	$random;
			TASK_doF2i_op ({sign, exponent, fraction});
		end

		//	- 2^31
		@(posedge clk);
		numTest++;
		sign		=	'1;
		exponent	=	'd31 + 'd127;
		fraction	=	'0;
		TASK_doF2i_op ({sign, exponent, fraction});

		//	+ (2^31 - 1)
		@(posedge clk);
		numTest++;
		sign		=	'0;
		exponent	=	'd30 + 'd127;
		fraction	=	'h7ffffff;
		TASK_doF2i_op ({sign, exponent, fraction});
	endtask

	task TASK_testF2u ();
		logic	[FPMIX_FLOAT_S_DW-1:0]	sign;
		logic	[FPMIX_FLOAT_E_DW-1:0]	exponent;
		logic	[FPMIX_FLOAT_F_DW-1:0]	fraction;
		int								numTest;

		numTest			=	0;
		repeat (10)
		begin
			@(posedge clk);
			numTest++;
			sign		=	$random;
			exponent	=	$urandom_range(0, FPMIX_FLOAT_E_BIAS + FPMIX_INTEGER_F_DW - 1);
			fraction	=	$random;
			TASK_doF2i_op ({sign, exponent, fraction});
		end

		//	- 2^31
		@(posedge clk);
		numTest++;
		sign		=	'1;
		exponent	=	'd31 + 'd127;
		fraction	=	'0;
		TASK_doF2i_op ({sign, exponent, fraction});

		//	+ (2^31 - 1)
		@(posedge clk);
		numTest++;
		sign		=	'0;
		exponent	=	'd30 + 'd127;
		fraction	=	'h7ffffff;
		TASK_doF2i_op ({sign, exponent, fraction});

		// 0
		@(posedge clk);
		numTest++;
		sign		=	'1;
		exponent	=	'0;
		fraction	=	'0;
		TASK_doF2i_op ({sign, exponent, fraction});

		//	+ (2^32 - 1)
		@(posedge clk);
		numTest++;
		sign		=	'0;
		exponent	=	'd31 + 'd127;
		fraction	=	'hfffffff;
		TASK_doF2i_op ({sign, exponent, fraction});
	endtask

	task TASK_testCmp ();
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_EQ, $random, $random);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LT, $random, $random);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LE, $random, $random);

		TASK_doCmp_op (FPU_EQ, PLUS_INF, PLUS_INF);
		TASK_doCmp_op (FPU_LT, PLUS_INF, PLUS_INF);
		TASK_doCmp_op (FPU_LE, PLUS_INF, PLUS_INF);

		TASK_doCmp_op (FPU_EQ, MINUS_INF, MINUS_INF);
		TASK_doCmp_op (FPU_LT, MINUS_INF, MINUS_INF);
		TASK_doCmp_op (FPU_LE, MINUS_INF, MINUS_INF);

		TASK_doCmp_op (FPU_EQ, PLUS_ZERO, PLUS_ZERO);
		TASK_doCmp_op (FPU_LT, PLUS_ZERO, PLUS_ZERO);
		TASK_doCmp_op (FPU_LE, PLUS_ZERO, PLUS_ZERO);

		TASK_doCmp_op (FPU_EQ, MINUS_ZERO, MINUS_ZERO);
		TASK_doCmp_op (FPU_LT, MINUS_ZERO, MINUS_ZERO);
		TASK_doCmp_op (FPU_LE, MINUS_ZERO, MINUS_ZERO);

		TASK_doCmp_op (FPU_EQ, PLUS_ZERO, MINUS_ZERO);
		TASK_doCmp_op (FPU_LT, PLUS_ZERO, MINUS_ZERO);
		TASK_doCmp_op (FPU_LE, PLUS_ZERO, MINUS_ZERO);

		TASK_doCmp_op (FPU_EQ, MINUS_ZERO, PLUS_ZERO);
		TASK_doCmp_op (FPU_LT, MINUS_ZERO, PLUS_ZERO);
		TASK_doCmp_op (FPU_LE, MINUS_ZERO, PLUS_ZERO);

		TASK_doCmp_op (FPU_EQ, PLUS_INF, MINUS_INF);
		TASK_doCmp_op (FPU_LT, PLUS_INF, MINUS_INF);
		TASK_doCmp_op (FPU_LE, PLUS_INF, MINUS_INF);

		TASK_doCmp_op (FPU_EQ, MINUS_INF, PLUS_INF);
		TASK_doCmp_op (FPU_LT, MINUS_INF, PLUS_INF);
		TASK_doCmp_op (FPU_LE, MINUS_INF, PLUS_INF);

		TASK_doCmp_op (FPU_EQ, PLUS_ZERO, MINUS_INF);
		TASK_doCmp_op (FPU_LT, PLUS_ZERO, MINUS_INF);
		TASK_doCmp_op (FPU_LE, PLUS_ZERO, MINUS_INF);

		TASK_doCmp_op (FPU_EQ, MINUS_ZERO, PLUS_INF);
		TASK_doCmp_op (FPU_LT, MINUS_ZERO, PLUS_INF);
		TASK_doCmp_op (FPU_LE, MINUS_ZERO, PLUS_INF);

		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_EQ, PLUS_INF, $random);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LT, PLUS_INF, $random);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LE, PLUS_INF, $random);

		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_EQ, $random, MINUS_INF);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LT, $random, MINUS_INF);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LE, $random, MINUS_INF);

		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_EQ, MINUS_ZERO, $random);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LT, MINUS_ZERO, $random);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LE, MINUS_ZERO, $random);

		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_EQ, $random, PLUS_ZERO);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LT, $random, PLUS_ZERO);
		repeat(2) @(posedge clk) TASK_doCmp_op (FPU_LE, $random, PLUS_ZERO);
	endtask

	task TASK_doArith_op (input opcodeFPU_t opcode, input logic [FPMIX_FLOAT_DW-1:0] op1, input logic [FPMIX_FLOAT_DW-1:0] op2);
		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		op2_i_tb		<=	op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		$display ("OP1 - S=%b E=0x%02x F=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
		$display ("OP2 - S=%b E=0x%02x F=0x%x", op2[FPMIX_FLOAT_DW-1], op2[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op2[0+:FPMIX_FLOAT_F_DW]);
		$display ("RES - S=%b E=0x%02x F=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
	endtask

	task TASK_doI2f_op (input logic [FPMIX_INTEGER_DW-1:0] op1);
		opcodeFPU_t		opcode;
		logic	[31:0]	tb_res;

		opcode			=	FPU_I2F;
		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1;
		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		$display ("OP1 - I=0x%08x(0b%032b)", op1, op1);
		$display ("RES - S=%b E=0x%02x F=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
	endtask

	task TASK_doU2f_op (input logic [FPMIX_INTEGER_DW-1:0] op1);
		opcodeFPU_t		opcode;
		logic	[31:0]	tb_res;

		opcode			=	FPU_U2F;
		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1;
		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		$display ("OP1 - I=0x%08x(0b%032b)", op1, op1);
		$display ("RES - S=%b E=0x%02x F=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
	endtask

	task TASK_doF2i_op (input logic [FPMIX_FLOAT_DW-1:0] op1);
		opcodeFPU_t		opcode;
		logic	[31:0]	tb_res;

		opcode			=	FPU_F2I;
		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		$display ("OP1 - S=%b E=0x%02x F=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
		$display ("RES - I=0x%08x(0b%032b)", result_o_tb, result_o_tb);
	endtask

	task TASK_doF2u_op (input logic [FPMIX_FLOAT_DW-1:0] op1);
		opcodeFPU_t		opcode;

		opcode			=	FPU_F2U;
		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		$display ("OP1 - S=%b E=0x%02x F=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
		$display ("RES - I=0x%08x(0b%032b)", result_o_tb, result_o_tb);
	endtask

	task TASK_doCmp_op (input opcodeFPU_t opcode, input logic [31:0] op1, input logic [31:0] op2);
		@(posedge clk);
		opcodeFPU_i_tb		<=	opcode;
		op1_i_tb			<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		op2_i_tb			<=	op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		@(posedge clk);
		opcodeFPU_i_tb		<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		$display ("OP1 - S=%b E=0x%02x F=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
		$display ("OP2 - S=%b E=0x%02x F=0x%x", op2[FPMIX_FLOAT_DW-1], op2[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op2[0+:FPMIX_FLOAT_F_DW]);
		$display ("RES - C=%b", result_o_tb[0]);
	endtask

endmodule: tb_fpmix
