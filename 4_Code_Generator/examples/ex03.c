int returnSomething() {
	int something = 1;
	return something;
}

void doSomething() {
	int something = returnSomething();
	return;
}

