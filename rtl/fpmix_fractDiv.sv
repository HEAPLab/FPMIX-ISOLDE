// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: May 5, 2026.

module fpmix_fractDiv #(
	FLOAT_F_DW	=	23,
	APPROX_DW	=	6,
	PREC_DW		=	8
)(
	clk, rst,
	//	Inputs
	doDiv_i, n_i, d_i,
	//	Outputs
	res_o, valid_o
);

import fpmix_pkg::*;

localparam APPROX_MULS	=	$clog2 (((FLOAT_F_DW+PREC_DW)+1)/APPROX_DW);

input									clk;
input									rst;
//	Inputs
input									doDiv_i;
input			[(1+FLOAT_F_DW)-1:0]	n_i;
input			[(1+FLOAT_F_DW)-1:0]	d_i;
//	Outputs
output	logic	[2*(1+FLOAT_F_DW)-1:0]	res_o;
output	logic							valid_o;

//////////////////////////////////////////////////////////////////
//                        Internal wires                        //
//////////////////////////////////////////////////////////////////

	logic	[2*(1+FLOAT_F_DW+PREC_DW)-1:0]	n_tmp;
	logic	[2*(1+FLOAT_F_DW+PREC_DW)-1:0]	d_tmp;
	logic	[(1+FLOAT_F_DW+PREC_DW)-1:0]	n_r, n_next;
	logic	[(1+FLOAT_F_DW+PREC_DW)-1:0]	d_r, d_next;
	logic	[(1+FLOAT_F_DW+PREC_DW)-1:0]	r_r, r_next;
	logic	[$clog2(APPROX_MULS)-1:0]		i_r, i_next;
	logic	[2*(1+FLOAT_F_DW)-1:0]			res_next;
	logic									valid_next;

	logic	[APPROX_DW-1:0]					approxRecip;

//////////////////////////////////////////////////////////////////
//                          State enum                          //
//////////////////////////////////////////////////////////////////

	ssFractDiv_t	ss, ss_next;

//////////////////////////////////////////////////////////////////
//                       Sequential logic                       //
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			ss		<=	SSDIV_IDLE;
			n_r		<=	'0;
			d_r		<=	'0;
			r_r		<=	'0;
			i_r		<=	'0;
			res_o	<=	'0;
			valid_o	<=	1'b0;
		end
		else
		begin
			ss		<=	ss_next;
			n_r		<=	n_next;
			d_r		<=	d_next;
			r_r		<=	r_next;
			i_r		<=	i_next;
			res_o	<=	res_next;
			valid_o	<=	valid_next;
		end
	end

//////////////////////////////////////////////////////////////////
//                     Combinational logic                      //
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		ss_next		=	ss;
		n_tmp		=	n_r * r_r;
		d_tmp		=	d_r * r_r;
		n_next		=	n_r;
		d_next		=	d_r;
		r_next		=	r_r;
		i_next		=	i_r;
		res_next	=	res_o;
		valid_next	=	1'b0;
		case (ss)
			SSDIV_IDLE:
			begin
				if (doDiv_i)
				begin
					ss_next		=	SSDIV_MUL;
					n_next		=	n_i << PREC_DW;
					d_next		=	d_i << PREC_DW;
					r_next		=	{2'b01, approxRecip} << ((1+FLOAT_F_DW+PREC_DW)-(APPROX_DW+2));
					i_next		=	'0;
				end
			end
			SSDIV_MUL:
			begin
				if (i_r == APPROX_MULS - 1)
				begin
					ss_next		=	SSDIV_IDLE;
					res_next	=	n_tmp[(2*(1+FLOAT_F_DW+PREC_DW)-1)-:(2*(1+FLOAT_F_DW))];
					valid_next	=	1'b1;
				end
				else
					ss_next		=	SSDIV_COMPL;
				n_next			=	n_tmp[(2*(1+FLOAT_F_DW+PREC_DW)-2)-:(1+FLOAT_F_DW+PREC_DW)];
				d_next			=	d_tmp[(2*(1+FLOAT_F_DW+PREC_DW)-2)-:(1+FLOAT_F_DW+PREC_DW)];
			end
			SSDIV_COMPL:
			begin
				ss_next			=	SSDIV_MUL;
				r_next			=	(1'b1 << (FLOAT_F_DW+2+PREC_DW)) - d_r;
				i_next			=	i_r + 1;
			end
		endcase
	end

//////////////////////////////////////////////////////////////////
//             Approximate reciprocal lookup table              //
//////////////////////////////////////////////////////////////////

	generate
		case (APPROX_DW)
		6:
		begin
			always_comb
			begin
				unique case(d_i[(1+FLOAT_F_DW)-2-:APPROX_DW])
					'b000000:	approxRecip	=	'b111111;
					'b000001:	approxRecip	=	'b111101;
					'b000010:	approxRecip	=	'b111011;
					'b000011:	approxRecip	=	'b111001;
					'b000100:	approxRecip	=	'b111000;
					'b000101:	approxRecip	=	'b110110;
					'b000110:	approxRecip	=	'b110100;
					'b000111:	approxRecip	=	'b110011;
					'b001000:	approxRecip	=	'b110001;
					'b001001:	approxRecip	=	'b101111;
					'b001010:	approxRecip	=	'b101110;
					'b001011:	approxRecip	=	'b101101;
					'b001100:	approxRecip	=	'b101011;
					'b001101:	approxRecip	=	'b101010;
					'b001110:	approxRecip	=	'b101000;
					'b001111:	approxRecip	=	'b100111;
					'b010000:	approxRecip	=	'b100110;
					'b010001:	approxRecip	=	'b100101;
					'b010010:	approxRecip	=	'b100011;
					'b010011:	approxRecip	=	'b100010;
					'b010100:	approxRecip	=	'b100001;
					'b010101:	approxRecip	=	'b100000;
					'b010110:	approxRecip	=	'b011111;
					'b010111:	approxRecip	=	'b011110;
					'b011000:	approxRecip	=	'b011101;
					'b011001:	approxRecip	=	'b011100;
					'b011010:	approxRecip	=	'b011011;
					'b011011:	approxRecip	=	'b011010;
					'b011100:	approxRecip	=	'b011001;
					'b011101:	approxRecip	=	'b011000;
					'b011110:	approxRecip	=	'b010111;
					'b011111:	approxRecip	=	'b010110;
					'b100000:	approxRecip	=	'b010101;
					'b100001:	approxRecip	=	'b010100;
					'b100010:	approxRecip	=	'b010011;
					'b100011:	approxRecip	=	'b010010;
					'b100100:	approxRecip	=	'b010010;
					'b100101:	approxRecip	=	'b010001;
					'b100110:	approxRecip	=	'b010000;
					'b100111:	approxRecip	=	'b001111;
					'b101000:	approxRecip	=	'b001110;
					'b101001:	approxRecip	=	'b001110;
					'b101010:	approxRecip	=	'b001101;
					'b101011:	approxRecip	=	'b001100;
					'b101100:	approxRecip	=	'b001100;
					'b101101:	approxRecip	=	'b001011;
					'b101110:	approxRecip	=	'b001010;
					'b101111:	approxRecip	=	'b001001;
					'b110000:	approxRecip	=	'b001001;
					'b110001:	approxRecip	=	'b001000;
					'b110010:	approxRecip	=	'b001000;
					'b110011:	approxRecip	=	'b000111;
					'b110100:	approxRecip	=	'b000110;
					'b110101:	approxRecip	=	'b000110;
					'b110110:	approxRecip	=	'b000101;
					'b110111:	approxRecip	=	'b000101;
					'b111000:	approxRecip	=	'b000100;
					'b111001:	approxRecip	=	'b000011;
					'b111010:	approxRecip	=	'b000011;
					'b111011:	approxRecip	=	'b000010;
					'b111100:	approxRecip	=	'b000010;
					'b111101:	approxRecip	=	'b000001;
					'b111110:	approxRecip	=	'b000001;
					'b111111:	approxRecip	=	'b000000;
				endcase
			end

		end
		4:
		begin
			always_comb
			begin
				unique case(d_i[(1+FLOAT_F_DW)-2-:APPROX_DW])
					'b0000	:	approxRecip	=	'b1111;
					'b0001	:	approxRecip	=	'b1101;
					'b0010	:	approxRecip	=	'b1100;
					'b0011	:	approxRecip	=	'b1010;
					'b0100	:	approxRecip	=	'b1001;
					'b0101	:	approxRecip	=	'b1000;
					'b0110	:	approxRecip	=	'b0111;
					'b0111	:	approxRecip	=	'b0110;
					'b1000	:	approxRecip	=	'b0101;
					'b1001	:	approxRecip	=	'b0100;
					'b1010	:	approxRecip	=	'b0011;
					'b1011	:	approxRecip	=	'b0011;
					'b1100	:	approxRecip	=	'b0010;
					'b1101	:	approxRecip	=	'b0001;
					'b1110	:	approxRecip	=	'b0001;
					'b1111	:	approxRecip	=	'b0000;
				endcase
			end
		end
		default:
		begin
			$error("Unsupported value of APPROX_DW parameter");
		end
		endcase
	endgenerate

endmodule
