%{
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>
%}

%%
"int"       { return INT; }
"RECT"      { return RECT; }
"fill"      { return FILL; }
"num"       { return NUMDECL; }
"LINE"      { return LINE; }
"CANVAS"    { return CANVAS; }
"while"     { return WHILE; }

"<"         { return LT; }
">"         { return GT; }
"=="        { return EQ; }
"!="        { return NE; }
"<="        { return LE; }
">="        { "return GE; }

"="         { return '='; }
"{"         { return '{'; }
"}"         { return '}'; }
"("         { return '('; }
")"         { return ')'; }

"#"[a-fA-F0-9]{6}      { yylval.sval = strdup(yytext); return COLOR; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.sval = strdup(yytext); return ID; }
[0-9]+(\.[0-9]+)?      { yylval.dval = atof(yytext); return NUM; }

\n          { /* Newlines are now just whitespace */ }
[ \t]+      { /* skip whitespace */ }
.           { /* skip unknown characters */ }
%%