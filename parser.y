%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_VARS 100

// Global variables for canvas size, with default values (A4 paper)
double canvas_width = 21.0;
double canvas_height = 29.7;

struct var {
    char name[32];
    double value;
};

struct var vars[MAX_VARS];
int var_count = 0;

int yylex(void);
int yyerror(const char *s);

int add_var(const char *name, double value) {
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
%token NUMDECL
%token LINE
%token CANVAS

%type <sval> fill_opt line_opt
%type <dval> rect_arg
%type <dval> line_arg

%%

start: optional_canvas_decl svg_body;

optional_canvas_decl: /* empty */
                    | canvas_cmd '\n'
                    ;

svg_body: svg_open stmts svg_close;


svg_open: {
    printf("<svg width=\"%gcm\" height=\"%gcm\" xmlns=\"http://www.w3.org/2000/svg\">\n", canvas_width, canvas_height);
};
svg_close: { printf("</svg>\n"); };

stmts: /* empty */
     | stmts stmt
     ;

/* --- THE FIX IS HERE --- */
stmt: decl '\n'
    | rect_cmd '\n'
    | line_cmd '\n'
    | '\n'  /* This new rule allows for empty lines between statements */
    ;
/* --- END OF FIX --- */

canvas_cmd: CANVAS rect_arg rect_arg {
    canvas_width = $2;
    canvas_height = $3;
}
;

rect_cmd: RECT rect_arg rect_arg rect_arg rect_arg fill_opt {
    if ($6) {
        printf("<rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\" fill=\"%s\"/>\n", $2, $3, $4, $5, $6);
        free($6);
    } else {
        printf("<rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\"/>\n", $2, $3, $4, $5);
    }
}
    ;

decl: NUMDECL ID '=' NUM { add_var($2, $4); free($2); }
    ;

fill_opt: /* empty */ { $$ = NULL; }
        | FILL '=' ID { $$ = $3; }
        | FILL '=' COLOR { $$ = $3; }
        ;

line_cmd: LINE line_arg line_arg line_arg line_arg line_opt {
    double x1 = $2, y1 = $3, x2 = $4, y2 = $5;
    char *stroke = $6 ? $6 : "black";
    printf("<line x1=\"%gcm\" y1=\"%gcm\" x2=\"%gcm\" y2=\"%gcm\" stroke=\"%s\" stroke-width=\"10\" stroke-linecap=\"round\"/>\n", x1, y1, x2, y2, stroke);
    if ($6) free($6);
}
    ;

line_opt: /* empty */ { $$ = NULL; }
        | FILL '=' ID { $$ = $3; }
        | FILL '=' COLOR { $$ = $3; }
        ;

rect_arg: NUM { $$ = $1; }
        | ID  { /* lookup variable value */
            int found = 0;
            for (int i = 0; i < var_count; ++i) {
                if (strcmp(vars[i].name, $1) == 0) {
                    $$ = vars[i].value;
                    found = 1;
                    break;
                }
            }
            if (!found) {
                fprintf(stderr, "Error: undefined variable '%s'\n", $1);
                $$ = 0;
            }
            free($1);
        }
        ;

line_arg: NUM { $$ = $1; }
        | ID  { int found = 0; for (int i = 0; i < var_count; ++i) { if (strcmp(vars[i].name, $1) == 0) { $$ = vars[i].value; found = 1; break; } } if (!found) { fprintf(stderr, "Error: undefined variable '%s'\n", $1); $$ = 0; } free($1); }
        ;
%%


int main(void) {
    return yyparse();
}

int yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
    return 1;
}