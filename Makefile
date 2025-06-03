CC = gcc
FLEX = flex
BISON = bison

all: graphicslang

graphicslang: graphicslang.tab.c lex.yy.c main.c
	$(CC) -o graphicslang graphicslang.tab.c lex.yy.c main.c -lfl

graphicslang.tab.c graphicslang.tab.h: graphicslang.y
	$(BISON) -d graphicslang.y

lex.yy.c: graphicslang.l graphicslang.tab.h
	$(FLEX) graphicslang.l

clean:
	rm -f graphicslang graphicslang.tab.* lex.yy.c *.o
