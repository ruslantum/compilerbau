bool test() {
  return true;
}

int main() {
  bool i;

  if (test()){
    int foo = 4;
  } else {
    int foo = 2;
  }
  return foo;
}
