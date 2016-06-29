#include <stdbool.h>
int main () {
	int ia = 1;
	int ib = 2;

	int iSum = ia + ib;
	int iDif = ia - ib;
	int iMul = ia * ib;
	int iDiv = ia / ib;

	return iSum;
}

double mainDouble () {

	 double da = 1.0;
	 double db = 2.0;

	 double dSum = da + db;
	 double dDif = da - db;
	 double dMul = da * db;
	 double dDiv = da / db;

	 return dSum;
}


bool mainBool() {
	bool ba = true;
	bool bb = false;

	bool bSum = ba + bb;
	bool bDif = ba - bb;
	bool bMul = ba * bb;
	bool bDiv = ba / bb;

	return bSum;
}