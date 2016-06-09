.PHONY: all bnfc tccpp

all: bnfc icpp

icpp:
	ghc --make icpp.hs -o icpp

bnfc:
	bnfc ../CPP.cf
	happy -gca ParCPP.y
	alex -g LexCPP.x

clean:
	-rm -f tccpp
	-rm -f *.log *.aux *.hi *.o *.dvi
	-rm -f DocCPP.ps

distclean: clean
	-rm -f DocCPP.* LexCPP.* ParCPP.* LayoutCPP.* SkelCPP.* PrintCPP.* TestCPP.* AbsCPP.* TestCPP ErrM.* SharedString.* CPP.dtd XMLCPP.*
