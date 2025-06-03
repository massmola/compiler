%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_VARS 100

struct var {
    char name[32];
    int value;
};

struct var vars[MAX_VARS];
int var_count = 0;

int yylex(void);
int yyerror(const char *s);

int add_var(const char *name, int value) {
    if (var_count >= MAX_VARS) return -1;
    strncpy(vars[var_count].name, name, 31);
    vars[var_count].name[31] = '\0';
    vars[var_count].value = value;
    var_count++;
    return 0;
}
%}

%union {
    int ival;
    char *sval;
}

%token HELLO
%token INT
%token <sval> ID
%token <ival> NUM

%%
start: stmts;

stmts: /* empty */
     | stmts stmt
     ;

stmt: HELLO '\n' { printf("Hello detected!\n"); }
    | decl '\n'
    ;

decl: INT ID '=' NUM { if (add_var($2, $4) == 0) printf("Declared int %s = %d\n", $2, $4); else printf("Variable table full!\n"); free($2); }
    ;
%%

int main(void) {
    return yyparse();
}

int yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
    return 1;
}
