all: clean compile_rules compile_parser test_rules

compile_rules:
	bnfc -m -o dist CPP.cf

compile_parser:
	cd dist; make

test_rules:
	dist/TestCPP test/hello.cc

clean:
	rm -rf dist
