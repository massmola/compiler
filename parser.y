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
    double dval;
    char *sval;
}

%token INT
%token <sval> ID
%token <dval> NUM
%token RECT
%token FILL
%token <sval> COLOR

%type <sval> fill_opt // <--- ADD THIS LINE

%%
start: svg_file;

svg_file: svg_open stmts svg_close;

svg_open: { printf("<svg xmlns=\"http://www.w3.org/2000/svg\">\n"); };
svg_close: { printf("</svg>\n"); };

stmts: /* empty */
     | stmts stmt
     ;

stmt: decl '\n'
    | rect_cmd '\n'
    ;

rect_cmd: RECT NUM NUM NUM NUM fill_opt {
    if ($6) {
        printf("<rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\" fill=\"%s\"/>\n", $2, $3, $4, $5, $6);
        free($6); // Free the allocated string for fill color
    } else {
        printf("<rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\"/>\n", $2, $3, $4, $5);
    }
}
    ;

decl: INT ID '=' NUM {
    if ((double)(int)$4 == $4) { // Check if NUM is an integer
        if (add_var($2, (int)$4) == 0) {
            printf("Declared int %s = %d\n", $2, (int)$4);
        } else {
            printf("Variable table full!\n");
        }
    } else {
        printf("Error: NUM must be an integer for variable declarations.\n");
    }
    free($2);
}
    ;

fill_opt: /* empty */ { $$ = NULL; }
        | FILL '=' ID { $$ = $3; }
        | FILL '=' COLOR { $$ = $3; }
        ;
%%


int main(void) {
    return yyparse();
}

int yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
    return 1;
}