// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module validate_fpmix;

	import fpmix_pkg::*;

	import "DPI-C" function int unsigned DPI_fadd ( input int unsigned op1, input int unsigned op2 );
	import "DPI-C" function int unsigned DPI_fsub ( input int unsigned op1, input int unsigned op2 );
	import "DPI-C" function int unsigned DPI_fmul ( input int unsigned op1, input int unsigned op2 );
	import "DPI-C" function int unsigned DPI_fdiv ( input int unsigned op1, input int unsigned op2 );
	import "DPI-C" function int unsigned DPI_feq  ( input int unsigned op1, input int unsigned op2 );
	import "DPI-C" function int unsigned DPI_flt  ( input int unsigned op1, input int unsigned op2 );
	import "DPI-C" function int unsigned DPI_fle  ( input int unsigned op1, input int unsigned op2 );
	import "DPI-C" function int unsigned DPI_i2f  ( input int unsigned op1                         );
	import "DPI-C" function int unsigned DPI_f2i  ( input int unsigned op1                         );
	import "DPI-C" function int unsigned DPI_u2f  ( input int unsigned op1                         );
	import "DPI-C" function int unsigned DPI_f2u  ( input int unsigned op1                         );

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
		$dumpfile("validate_fpmix.vcd");
		$dumpvars(0,validate_fpmix);
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
//			$display("Test-%d",numTest);
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
//			$display("Test-%d",numTest);
			@(posedge clk);
			TASK_doI2f_op ($random);
		end

		//	zero
		numTest++;
//		$display("Test-%d",numTest);
		@(posedge clk);
		TASK_doI2f_op (32'b00000000000000000000000000000000);

		//	max
		numTest++;
//		$display("Test-%d",numTest);
		@(posedge clk);
		TASK_doI2f_op (32'b01111111111111111111111111111111);

		//	min
		numTest++;
//		$display("Test-%d",numTest);
		@(posedge clk);
		TASK_doI2f_op (32'b10000000000000000000000000000000);
	endtask

	task TASK_testU2f ();
		int	numTest;

		numTest	=	0;
		repeat (10)
		begin
			numTest++;
//			$display("Test-%d",numTest);
			@(posedge clk);
			TASK_doU2f_op ($random);
		end

		//	zero
		numTest++;
//		$display("Test-%d",numTest);
		@(posedge clk);
		TASK_doI2f_op (32'b00000000000000000000000000000000);

		//	max
		numTest++;
//		$display("Test-%d",numTest);
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
//			$display("Test-%d",numTest);
			sign		=	$random;
			exponent	=	$urandom_range(0, FPMIX_FLOAT_E_BIAS + FPMIX_INTEGER_F_DW - 1);
			fraction	=	$random;
			TASK_doF2i_op ({sign, exponent, fraction});
		end

		//	- 2^31
		@(posedge clk);
		numTest++;
//		$display("Test-%d",numTest);
		sign		=	'1;
		exponent	=	'd31 + 'd127;
		fraction	=	'0;
		TASK_doF2i_op ({sign, exponent, fraction});

		//	+ (2^31 - 1)
		@(posedge clk);
		numTest++;
//		$display("Test-%d",numTest);
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
//			$display("Test-%d",numTest);
			sign		=	$random;
			exponent	=	$urandom_range(0, FPMIX_FLOAT_E_BIAS + FPMIX_INTEGER_F_DW - 1);
			fraction	=	$random;
			TASK_doF2i_op ({sign, exponent, fraction});
		end

		//	- 2^31
		@(posedge clk);
		numTest++;
//		$display("Test-%d",numTest);
		sign		=	'1;
		exponent	=	'd31 + 'd127;
		fraction	=	'0;
		TASK_doF2i_op ({sign, exponent, fraction});

		//	+ (2^31 - 1)
		@(posedge clk);
		numTest++;
//		$display("Test-%d",numTest);
		sign		=	'0;
		exponent	=	'd30 + 'd127;
		fraction	=	'h7ffffff;
		TASK_doF2i_op ({sign, exponent, fraction});

		// 0
		@(posedge clk);
		numTest++;
//		$display("Test-%d",numTest);
		sign		=	'1;
		exponent	=	'0;
		fraction	=	'0;
		TASK_doF2i_op ({sign, exponent, fraction});

		//	+ (2^32 - 1)
		@(posedge clk);
		numTest++;
//		$display("Test-%d",numTest);
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

		//	TODO: NaNs!!!
	endtask

	task TASK_doArith_op (input opcodeFPU_t opcode, input logic [FPMIX_FLOAT_DW-1:0] op1, input logic [FPMIX_FLOAT_DW-1:0] op2);
		logic	[31:0]	tb_res;

		case (opcode)
			FPU_ADD:	tb_res	=	DPI_fadd (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW), op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));
			FPU_SUB:	tb_res	=	DPI_fsub (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW), op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));
			FPU_MUL:	tb_res	=	DPI_fmul (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW), op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));
			FPU_DIV:	tb_res	=	DPI_fdiv (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW), op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));
		endcase

//		$strobe ("@%0t - Start FPU operation: opcode:%s",
//								$time, opcode.name);

		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		op2_i_tb		<=	op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);

		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		if (tb_res[31-:FPMIX_FLOAT_DW] !== result_o_tb[31-:FPMIX_FLOAT_DW])
		begin
			$display ("OP1 - S=%b E=0x%02x f=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
			$display ("OP2 - S=%b E=0x%02x f=0x%x", op2[FPMIX_FLOAT_DW-1], op2[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op2[0+:FPMIX_FLOAT_F_DW]);
			$display("ERR DPI-FPU - S=%b E=0x%02x f=0x%x", tb_res[31], tb_res[30-:FPMIX_FLOAT_E_DW], tb_res[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
			$display("ERR RTL-FPU - S=%b E=0x%02x f=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
		end
//		else
//		begin
//			$display("OK DPI-FPU - S=%b E=0x%02x f=0x%x", tb_res[31], tb_res[30-:FPMIX_FLOAT_E_DW], tb_res[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
//			$display("OK RTL-FPU - S=%b E=0x%02x f=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
//		end
//		$strobe ("@%0t - END FPU operation", $time);
	endtask

	task TASK_doI2f_op (input logic [FPMIX_INTEGER_DW-1:0] op1);
		opcodeFPU_t		opcode;
		logic	[31:0]	tb_res;

		opcode			=	FPU_I2F;
		tb_res			=	DPI_i2f (op1);

//		$strobe ("@%0t - Start FPU operation: opcode:%s op1:%0x",
//								$time, opcode.name, op1);

		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1;

		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		if (tb_res[31-:FPMIX_FLOAT_DW] !== result_o_tb)
		begin
			$display ("OP1 - I=0x%08x(0b%032b)", op1, op1);
			$display("ERR DPI-FPU - S=%b E=0x%02x f=0x%x", tb_res[31], tb_res[30-:FPMIX_FLOAT_E_DW], tb_res[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
			$display("ERR RTL-FPU - S=%b E=0x%02x f=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
		end
//		else
//		begin
//			$display("OK DPI-FPU - S=%b E=0x%02x f=0x%x", tb_res[31], tb_res[30-:FPMIX_FLOAT_E_DW], tb_res[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
//			$display("OK RTL-FPU - S=%b E=0x%02x f=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
//		end
//		$strobe ("@%0t - END FPU operation", $time);
	endtask

	task TASK_doU2f_op (input logic [FPMIX_INTEGER_DW-1:0] op1);
		opcodeFPU_t		opcode;
		logic	[31:0]	tb_res;

		opcode			=	FPU_U2F;
		tb_res			=	DPI_u2f (op1);

//		$strobe ("@%0t - Start FPU operation: opcode:%s op1:%0x",
//								$time, opcode.name, op1);

		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1;

		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		if (tb_res[31-:FPMIX_FLOAT_DW] !== result_o_tb)
		begin
			$display ("OP1 - I=0x%08x(0b%032b)", op1, op1);
			$display("ERR DPI-FPU - S=%b E=0x%02x f=0x%x", tb_res[31], tb_res[30-:FPMIX_FLOAT_E_DW], tb_res[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
			$display("ERR RTL-FPU - S=%b E=0x%02x f=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
		end
//		else
//		begin
//			$display("OK DPI-FPU - S=%b E=0x%02x f=0x%x", tb_res[31], tb_res[30-:FPMIX_FLOAT_E_DW], tb_res[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
//			$display("OK RTL-FPU - S=%b E=0x%02x f=0x%x", result_o_tb[31], result_o_tb[30-:FPMIX_FLOAT_E_DW], result_o_tb[30-FPMIX_FLOAT_E_DW-:FPMIX_FLOAT_F_DW]);
//		end
//		$strobe ("@%0t - END FPU operation", $time);
	endtask

	task TASK_doF2i_op (input logic [FPMIX_FLOAT_DW-1:0] op1);
		opcodeFPU_t		opcode;
		logic	[31:0]	tb_res;

		opcode			=	FPU_F2I;
		tb_res			=	DPI_f2i (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));

//		$strobe ("@%0t - Start FPU operation: opcode:%s op1:%0x",
//								$time, opcode.name, op1);

		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb		<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);

		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		if (tb_res !== result_o_tb)
		begin
			$display ("OP1 - S=%b E=0x%02x f=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
			$display("ERR DPI-FPU - I=0x%08x(0b%032b)", tb_res, tb_res);
			$display("ERR RTL-FPU - I=0x%08x(0b%032b)", result_o_tb, result_o_tb);
		end
//		else
//		begin
//			$display("OK DPI-FPU - I=0x%08x(0b%032b)", tb_res, tb_res);
//			$display("OK RTL-FPU - I=0x%08x(0b%032b)", result_o_tb, result_o_tb);
//		end
//		$strobe ("@%0t - END FPU operation", $time);
	endtask

	task TASK_doF2u_op (input logic [FPMIX_FLOAT_DW-1:0] op1);
		opcodeFPU_t		opcode;
		logic	[31:0]	tb_res;

		opcode			=	FPU_F2U;
		tb_res			=	DPI_f2u (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));

//		$strobe ("@%0t - Start FPU operation: opcode:%s op1:%0x",
//								$time, opcode.name, op1);

		@(posedge clk);
		opcodeFPU_i_tb	<=	opcode;
		op1_i_tb 		<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);

		@(posedge clk);
		opcodeFPU_i_tb	<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		if (tb_res !== result_o_tb)
		begin
			$display ("OP1 - S=%b E=0x%02x f=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
			$display("ERR DPI-FPU - I=0x%08x(0b%032b)", tb_res, tb_res);
			$display("ERR RTL-FPU - I=0x%08x(0b%032b)", result_o_tb, result_o_tb);
		end
//		else
//		begin
//			$display("OK DPI-FPU - I=0x%08x(0b%032b)", tb_res, tb_res);
//			$display("OK RTL-FPU - I=0x%08x(0b%032b)", result_o_tb, result_o_tb);
//		end
//		$strobe ("@%0t - END FPU operation", $time);
	endtask

	task TASK_doCmp_op (input opcodeFPU_t opcode, input logic [31:0] op1, input logic [31:0] op2);
		logic	[31:0]	tb_res;

		case (opcode)
			FPU_EQ:	tb_res	=	DPI_feq (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW), op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));
			FPU_LT:	tb_res	=	DPI_flt (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW), op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));
			FPU_LE:	tb_res	=	DPI_fle (op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW), op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW));
		endcase

//		$strobe ("@%0t - Start FPU operation: opcode:%s op1:%0x op2:%0x",
//								$time, opcode.name, op1, op2);

		@(posedge clk);
		opcodeFPU_i_tb		<=	opcode;
		op1_i_tb			<=	op1 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);
		op2_i_tb			<=	op2 << (FPMIX_INTEGER_DW - FPMIX_FLOAT_DW);

		@(posedge clk);
		opcodeFPU_i_tb		<=	FPU_IDLE;
		wait (isResultValid_o_tb);
		@(posedge clk);
		if (tb_res[0] !== result_o_tb[0])
		begin
			$display ("OP1 - S=%b E=0x%02x f=0x%x", op1[FPMIX_FLOAT_DW-1], op1[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op1[0+:FPMIX_FLOAT_F_DW]);
			$display ("OP2 - S=%b E=0x%02x f=0x%x", op2[FPMIX_FLOAT_DW-1], op2[FPMIX_FLOAT_DW-2-:FPMIX_FLOAT_E_DW], op2[0+:FPMIX_FLOAT_F_DW]);
			$display ("ERR DPI-FPU - C=%b", tb_res[0]);
			$display ("ERR RTL-FPU - C=%b", result_o_tb[0]);
		end
//		$strobe ("@%0t - END FPU operation", $time);
	endtask

endmodule: validate_fpmix
