int main() {

int i = 0;
int a = 2;

if(++i > 0 && a < 1) {
return i;
} else {
return 0;
}

if(++i > 0 || a < 1) {
return i;
} else {
return 0;
}

return 100;
}
