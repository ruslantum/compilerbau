double foo() {
  double a = 7.098e-7;
  return a;
}

int main() {
double i = 2.098e-7;
int counter = 0;

while (counter < 10) {
  double bla = i + foo();
  counter++;
}

return 0;
}
