void main() {
	bool b = false;
	int i1 = 1;
	int i2 = 2;
	while(b) {
		i1 = 2;
	}

	while(false) {
		b = false;
	}

	while(i1 || i2) {
		b = true;
	}


}