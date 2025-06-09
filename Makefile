all: test

compiler: parser.tab.c lex.yy.c
	gcc -o compiler parser.tab.c lex.yy.c -lfl

parser.tab.c: parser.y
	bison -d parser.y

lex.yy.c: lexer.l parser.tab.h
	flex lexer.l

.PHONY: clean test

clean:
	rm -rf compiler parser.tab.c parser.tab.h lex.yy.c output/*.svg output/*.txt output/*.err

output/%.svg: input/%.svgl compiler
	@mkdir -p output
	./compiler < $< > $@ 2> $@.err
	@if [ $$? -ne 0 ]; then \
		echo "Error: Compilation failed for $<. Check $@.err for details."; \
		exit 1; \
	fi
	@cp $@ $@.txt

test: clean all
	@mkdir -p output
	$(MAKE) $(patsubst input/%.svgl,output/%.svg,$(wildcard input/*.svgl))
	@echo "Tests completed. Check output/*.svg and output/*.txt for results."