all: dist/build/llvm-test/llvm-test

dist/build/llvm-test/llvm-test:
	cabal configure
	cabal build

clean:
	rm -rf dist

test: dist/build/llvm-test/llvm-test
	echo "def foo(x y) x+foo(y, 4.0);" | dist/build/llvm-test/llvm-test
