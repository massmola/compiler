%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int yylex(void);

// Symbol table entry
struct entry { char* name; char* type; struct entry* next; };
struct entry* symtab = NULL;

void declare(const char* name, const char* type) {
    struct entry* e = malloc(sizeof(struct entry));
    e->name = strdup(name);
    e->type = strdup(type);
    e->next = symtab;
    symtab = e;
}
const char* lookup(const char* name) {
    struct entry* e = symtab;
    while (e) {
        if (strcmp(e->name, name) == 0) return e->type;
        e = e->next;
    }
    return NULL;
}
%}

%union {
    int ival;
    char* sval;
}

%token <ival> NUMBER
%token <sval> ID
%token INT COLOR POINT LINE
%token EQUALS PLUS MINUS TIMES DIVIDE COMMA LPAREN RPAREN

%type <ival> expr
%type <sval> type

%%
program:
    statements
    ;

statements:
    statements statement
    | statement
    ;

statement:
    type ID EQUALS expr '\n' {
        if (strcmp($1, "int") == 0 && $4 != -9999) {
            declare($2, $1);
        } else if (strcmp($1, "color") == 0 && $4 == -9999) {
            declare($2, $1);
        } else {
            printf("Type error in declaration of %s\n", $2);
        }
    }
    | ID EQUALS expr '\n' {
        const char* t = lookup($1);
        if (!t) printf("Undeclared variable %s\n", $1);
    }
    | POINT LPAREN expr COMMA expr RPAREN '\n' {
        printf("Draw point at (%d, %d)\n", $3, $5);
    }
    | LINE LPAREN expr COMMA expr COMMA expr COMMA expr RPAREN '\n' {
        printf("Draw line from (%d, %d) to (%d, %d)\n", $3, $5, $7, $9);
    }
    ;

type:
    INT { $$ = "int"; }
    | COLOR { $$ = "color"; }
    ;

expr:
    NUMBER { $$ = $1; }
    | ID {
        const char* t = lookup($1);
        if (!t) { printf("Undeclared variable %s\n", $1); $$ = -9999; }
        else if (strcmp(t, "int") == 0) $$ = 0; /* dummy value */
        else $$ = -9999;
    }
    | expr PLUS expr { $$ = 0; }
    | expr MINUS expr { $$ = 0; }
    | expr TIMES expr { $$ = 0; }
    | expr DIVIDE expr { $$ = 0; }
    ;

%%
void yyerror(const char *s) { fprintf(stderr, "Error: %s\n", s); }
