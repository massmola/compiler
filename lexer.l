%{
#include "parser.tab.h"
#include <stdlib.h>
%}

%%
"hello"   { return HELLO; }
"int"     { return INT; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.sval = strdup(yytext); return ID; }
[0-9]+    { yylval.ival = atoi(yytext); return NUM; }
"="       { return '='; }
\n        { return '\n'; }
[ \t]+    { /* skip whitespace */ }
.         { return 0; }
%%
