// Copyright 2026 Politecnico di Milano.
// Authors: Andrea Galimberti, Davide Zoni.
// Contacts: andrea.galimberti@polimi.it, davide.zoni@polimi.it
// Date: January 7, 2026.

// Floating-point addition
unsigned int
DPI_fadd(unsigned int op1, unsigned int op2)
{
	float f_op1 = *((float*) &op1);
	float f_op2 = *((float*) &op2);
	float f_res = f_op1 + f_op2;
	return *((unsigned int*) &f_res);
}

// Floating-point subtraction
unsigned int
DPI_fsub(unsigned int op1, unsigned int op2)
{
	float f_op1 = *((float*) &op1);
	float f_op2 = *((float*) &op2);
	float f_res = f_op1 - f_op2;
	return *((unsigned int*) &f_res);
}

// Floating-point multiplication
unsigned int
DPI_fmul(unsigned int op1, unsigned int op2)
{
	float f_op1 = *((float*) &op1);
	float f_op2 = *((float*) &op2);
	float f_res = f_op1 * f_op2;
	return *((unsigned int*) &f_res);
}

// Floating-point division
unsigned int
DPI_fdiv(unsigned int op1, unsigned int op2)
{
	float f_op1 = *((float*) &op1);
	float f_op2 = *((float*) &op2);
	float f_res = f_op1 / f_op2;
	return *((unsigned int*) &f_res);
}

// Floating-point comparison: equals
unsigned int
DPI_feq(unsigned int op1, unsigned int op2)
{
	float f_op1 = *((float*) &op1);
	float f_op2 = *((float*) &op2);
	unsigned int res = f_op1 == f_op2;
	return res;
}

// Floating-point comparison: less than
unsigned int
DPI_flt(unsigned int op1, unsigned int op2)
{
	float f_op1 = *((float*) &op1);
	float f_op2 = *((float*) &op2);
	unsigned int res = f_op1 < f_op2;
	return res;
}

// Floating-point comparison: less than or equals
unsigned int
DPI_fle(unsigned int op1, unsigned int op2)
{
	float f_op1 = *((float*) &op1);
	float f_op2 = *((float*) &op2);
	unsigned int res = f_op1 <= f_op2;
	return res;
}

// Conversion from floating-point to signed integer
unsigned int
DPI_f2i(unsigned int uVal)
{
	float fVal = *((float*) &uVal);
	int iVal = (int) fVal;
	return *((unsigned int*) &iVal);
}

// Conversion from signed integer to floating-point
unsigned int
DPI_i2f(int iVal)
{
	float fVal = (float) iVal;
	return *((unsigned int*) &fVal);
}

// Conversion from floating-point to unsigned integer
unsigned int
DPI_f2u(unsigned int uVal)
{
	float fVal = *((float*) &uVal);
	unsigned int iVal = (unsigned int) fVal;
	return *((unsigned int*) &iVal);
}

// Conversion from unsigned integer to floating-point
unsigned int
DPI_u2f(unsigned int iVal)
{
	float fVal = (float) iVal;
	return *((unsigned int*) &fVal);
}
