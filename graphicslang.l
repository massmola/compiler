%{
#include "graphicslang.tab.h"
#include <stdio.h>
%}

%%
"int"      { return INT; }
"color"    { return COLOR; }
"point"    { return POINT; }
"line"     { return LINE; }
[0-9]+     { yylval.ival = atoi(yytext); return NUMBER; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.sval = strdup(yytext); return ID; }
"="        { return EQUALS; }
"+"        { return PLUS; }
"-"        { return MINUS; }
"*"        { return TIMES; }
"/"        { return DIVIDE; }
","        { return COMMA; }
"("        { return LPAREN; }
")"        { return RPAREN; }
[ \t\r\n]+  { /* skip whitespace */ }
.          { printf("Unknown character: %s\n", yytext); }
%%