all: clean compile_rules compile_parser test_rules

compile_rules:
	bnfc -m -o dist CPP.cf

compile_parser:
	cd dist; make

test_rules:
	dist/TestCPP test/01_hello.cc
	dist/TestCPP test/02_greet.cc
	dist/TestCPP test/03_med.cc
	dist/TestCPP test/04_grade.cc
	dist/TestCPP test/05_palin.cc
	dist/TestCPP test/06_grammar.cc
	cd lab1-testsuite-larger; ./progs-test-lab1 ../CPP.cf

clean:
	rm -rf dist
