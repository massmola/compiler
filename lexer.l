%{
#include "parser.tab.h"
#include <stdlib.h>
%}

%%
"int"     { return INT; }
"RECT"    { return RECT; }
"fill"    { return FILL; }
"="       { return '='; }
"num"     { return NUMDECL; }
"LINE"    { return LINE; }
"#"[a-fA-F0-9]{6} { yylval.sval = strdup(yytext); return COLOR; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.sval = strdup(yytext); return ID; }
[0-9]+(\.[0-9]+)? { yylval.dval = atof(yytext); return NUM; }
\n        { return '\n'; }
[ \t]+    { /* skip whitespace */ }
.         { /* skip unknown characters */ }
%%
