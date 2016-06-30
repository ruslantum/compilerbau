
void doNothing() {
	return;
}

int returnSomething() {
	int something = 1;
	return something;
}

double returnSomeDouble() {
	double someDouble = 3.1415;
	return someDouble;
}

void doSomething() {
	int something = returnSomething();
	double someDouble = returnSomeDouble();
	doNothing();
	return;
}


