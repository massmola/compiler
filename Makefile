all: compiler

compiler: parser.tab.c lex.yy.c
	gcc -o compiler parser.tab.c lex.yy.c -ll

parser.tab.c: parser.y
	bison -d parser.y

lex.yy.c: lexer.l parser.tab.h
	flex lexer.l

clean:
	rm -f compiler parser.tab.c parser.tab.h lex.yy.c
