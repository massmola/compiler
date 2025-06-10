%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

// --- Data Structures for Scoped Variables ---
#define MAX_VARS_PER_SCOPE 50
#define MAX_SCOPE_DEPTH 20

// --- Moved these variables back to the top ---
double canvas_width = 21.0;
double canvas_height = 29.7;

struct var {
    char name[32];
    double value;
};

struct scope {
    struct var vars[MAX_VARS_PER_SCOPE];
    int var_count;
};

// The stack of scopes
struct scope scope_stack[MAX_SCOPE_DEPTH];
int scope_level = -1;

int yylex(void);
int yyerror(const char *s);

// Function prototypes for functions defined below
void enter_scope();
void exit_scope();
void declare_var(const char *name, double value);
int update_var_value(const char *name, double value);
double get_var_value(const char *name);
double eval_expr_numeric(ExprNode *expr);
void free_expr(ExprNode *e);
%}

%union {
    int ival; double dval; char *sval;
    ASTNode *node; ExprNode *expr; CmpOp op;
}

%token <sval> ID
%token <dval> NUM
%token <sval> COLOR
%token INT RECT FILL NUMDECL LINE CANVAS WHILE IF ELSE
%token LT GT EQ NE LE GE

%left '+' '-'
%left '*' '/'

%type <node> program stmts stmt rect_cmd line_cmd decl while_loop if_stmt condition assignment
%type <expr> expr color_arg fill_opt line_opt
%type <op> cmp_op

%%

program: optional_canvas_decl stmts {
        printf("<svg width=\"%gcm\" height=\"%gcm\" xmlns=\"http://www.w3.org/2000/svg\">\n", canvas_width, canvas_height);
        enter_scope(); // Establish the global scope
        if ($2) { eval_ast($2); free_ast($2); }
        exit_scope(); // Clean up the global scope
        printf("</svg>\n");
    }
    ;

optional_canvas_decl: /* empty */
    | CANVAS expr expr {
        canvas_width = eval_expr_numeric($2);
        canvas_height = eval_expr_numeric($3);
        free_expr($2); free_expr($3);
    }
    ;

stmts: /* empty */  { $$ = NULL; } | stmts stmt { $$ = new_stmt_list($2, $1); } ;
stmt: decl | assignment | rect_cmd | line_cmd | while_loop | if_stmt ;

if_stmt: IF '(' condition ')' '{' stmts '}' { $$ = new_if($3, $6, NULL); }
    | IF '(' condition ')' '{' stmts '}' ELSE '{' stmts '}' { $$ = new_if($3, $6, $10); }
    ;

while_loop: WHILE '(' condition ')' '{' stmts '}' { $$ = new_while($3, $6); } ;
condition: expr cmp_op expr { $$ = new_condition($2, $1, $3); } ;
cmp_op: LT { $$ = OP_LT; } | GT { $$ = OP_GT; } | EQ { $$ = OP_EQ; } | NE { $$ = OP_NE; } | LE { $$ = OP_LE; } | GE { $$ = OP_GE; } ;
decl: NUMDECL ID '=' expr { $$ = new_decl($2, $4); } ;
assignment: ID '=' expr { $$ = new_assignment($1, $3); } ;
rect_cmd: RECT expr expr expr expr fill_opt { $$ = new_rect_cmd($2, $3, $4, $5, $6); } ;
line_cmd: LINE expr expr expr expr line_opt { $$ = new_line_cmd($2, $3, $4, $5, $6); } ;

expr: NUM                 { $$ = new_expr_num($1); }
    | ID                  { $$ = new_expr_id($1); }
    | expr '+' expr       { $$ = new_expr_op('+', $1, $3); }
    | expr '-' expr       { $$ = new_expr_op('-', $1, $3); }
    | expr '*' expr       { $$ = new_expr_op('*', $1, $3); }
    | expr '/' expr       { $$ = new_expr_op('/', $1, $3); }
    | '(' expr ')'        { $$ = $2; }
    ;

fill_opt: /* empty */ { $$ = NULL; } | FILL '=' color_arg { $$ = $3; } ;
line_opt: /* empty */ { $$ = NULL; } | FILL '=' color_arg { $$ = $3; } ;
color_arg: ID { $$ = new_expr_id($1); } | COLOR { $$ = new_expr_color($1); } ;

%%

int main(void) { return yyparse(); }
int yyerror(const char *s) { fprintf(stderr, "Parse Error: %s\n", s); return 1; }

/* --- C CODE SECTION (WITH SCOPE MANAGEMENT) --- */

// --- Scope Management Functions ---
void enter_scope() {
    if (scope_level >= MAX_SCOPE_DEPTH - 1) {
        fprintf(stderr, "Runtime Error: Maximum scope depth exceeded.\n");
        exit(1);
    }
    scope_level++;
    scope_stack[scope_level].var_count = 0; // Initialize new scope
}

void exit_scope() {
    if (scope_level < 0) {
        fprintf(stderr, "Runtime Error: No scope to exit.\n");
        return;
    }
    scope_level--;
}

// --- Variable Management Functions (Scope-Aware) ---

// Declares a new variable in the CURRENT scope.
void declare_var(const char *name, double value) {
    if (scope_level < 0) enter_scope(); // Ensure global scope exists

    struct scope *current_scope = &scope_stack[scope_level];
    if (current_scope->var_count >= MAX_VARS_PER_SCOPE) {
        fprintf(stderr, "Runtime Error: Maximum variables per scope reached.\n");
        return;
    }
    // Check for re-declaration in the same scope
    for (int i = 0; i < current_scope->var_count; ++i) {
        if (strcmp(current_scope->vars[i].name, name) == 0) {
            fprintf(stderr, "Runtime Error: Variable '%s' already declared in this scope.\n", name);
            return;
        }
    }

    struct var *new_var = &current_scope->vars[current_scope->var_count++];
    strncpy(new_var->name, name, 31);
    new_var->name[31] = '\0';
    new_var->value = value;
}

// Assigns a value to an EXISTING variable, searching from current scope outwards.
int update_var_value(const char* name, double value) {
    for (int i = scope_level; i >= 0; --i) { // Search from current scope down to global
        for (int j = 0; j < scope_stack[i].var_count; ++j) {
            if (strcmp(scope_stack[i].vars[j].name, name) == 0) {
                scope_stack[i].vars[j].value = value;
                return 1; // Success
            }
        }
    }
    fprintf(stderr, "Runtime Error: assignment to undeclared variable '%s'\n", name);
    return 0; // Failure
}

// Gets a variable's value, searching from current scope outwards.
double get_var_value(const char* name) {
    for (int i = scope_level; i >= 0; --i) { // Search from current scope down to global
        for (int j = 0; j < scope_stack[i].var_count; ++j) {
            if (strcmp(scope_stack[i].vars[j].name, name) == 0) {
                return scope_stack[i].vars[j].value;
            }
        }
    }
    fprintf(stderr, "Runtime Error: undefined variable '%s'\n", name);
    return 0.0;
}


// --- AST Helper and Creation Functions (No changes needed here) ---
ASTNode* new_stmt_list(ASTNode* stmt, ASTNode* next) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_STMTS; n->node.stmts.stmt = stmt; n->node.stmts.next = next; return n; }
ASTNode* new_rect_cmd(ExprNode *x, ExprNode *y, ExprNode *w, ExprNode *h, ExprNode *fill) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_RECT; n->node.rect.x = x; n->node.rect.y = y; n->node.rect.w = w; n->node.rect.h = h; n->node.rect.fill = fill; return n; }
ASTNode* new_line_cmd(ExprNode *x1, ExprNode *y1, ExprNode *x2, ExprNode *y2, ExprNode *stroke) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_LINE; n->node.line.x1 = x1; n->node.line.y1 = y1; n->node.line.x2 = x2; n->node.line.y2 = y2; n->node.line.stroke = stroke; return n; }
ASTNode* new_decl(char* name, ExprNode* val) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_DECL; n->node.decl.name = name; n->node.decl.value = val; return n; }
ASTNode* new_assignment(char* name, ExprNode* val) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_ASSIGNMENT; n->node.decl.name = name; n->node.decl.value = val; return n; }
ASTNode* new_while(ASTNode* cond, ASTNode* body) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_WHILE; n->node.while_loop.condition = cond; n->node.while_loop.body = body; return n; }
ASTNode* new_if(ASTNode* cond, ASTNode* if_body, ASTNode* else_body) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_IF; n->node.if_stmt.condition = cond; n->node.if_stmt.if_body = if_body; n->node.if_stmt.else_body = else_body; return n; }
ASTNode* new_condition(CmpOp op, ExprNode* left, ExprNode* right) { ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode)); if (!n) exit(1); n->type = NODE_TYPE_CONDITION; n->node.condition.op = op; n->node.condition.left = left; n->node.condition.right = right; return n; }
ExprNode* new_expr_num(double d) { ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode)); if (!e) exit(1); e->type = NODE_TYPE_EXPR_NUM; e->data.dval = d; return e; }
ExprNode* new_expr_id(char* s) { ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode)); if (!e) exit(1); e->type = NODE_TYPE_EXPR_ID; e->data.sval = s; return e; }
ExprNode* new_expr_color(char* s) { ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode)); if (!e) exit(1); e->type = NODE_TYPE_EXPR_COLOR; e->data.sval = s; return e; }
ExprNode* new_expr_op(int op, ExprNode* left, ExprNode* right) { ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode)); if (!e) exit(1); e->type = NODE_TYPE_EXPR_OP; e->data.op.op = op; e->data.op.left = left; e->data.op.right = right; return e; }


// --- Evaluation Functions ---

double eval_expr_numeric(ExprNode *expr) {
    if (!expr) return 0.0;
    switch (expr->type) {
        case NODE_TYPE_EXPR_NUM: return expr->data.dval;
        case NODE_TYPE_EXPR_ID: return get_var_value(expr->data.sval);
        case NODE_TYPE_EXPR_OP: {
            double left = eval_expr_numeric(expr->data.op.left);
            double right = eval_expr_numeric(expr->data.op.right);
            switch (expr->data.op.op) {
                case '+': return left + right;
                case '-': return left - right;
                case '*': return left * right;
                case '/':
                    if (right == 0) {
                        fprintf(stderr, "Runtime Error: Division by zero.\n");
                        return 0.0;
                    }
                    return left / right;
                default: fprintf(stderr, "Runtime Error: Unknown operator '%c'\n", expr->data.op.op); return 0.0;
            }
        }
        default: fprintf(stderr, "Runtime Error: Invalid expression type for numeric evaluation.\n"); return 0.0;
    }
}
const char* eval_expr_string(ExprNode *expr) { if (!expr) return "black"; if (expr->type == NODE_TYPE_EXPR_COLOR) return expr->data.sval; if (expr->type == NODE_TYPE_EXPR_ID) return expr->data.sval; return "black"; }
int eval_condition(ConditionNode *cond) { double left = eval_expr_numeric(cond->left); double right = eval_expr_numeric(cond->right); switch(cond->op) { case OP_LT: return left < right; case OP_GT: return left > right; case OP_EQ: return left == right; case OP_NE: return left != right; case OP_LE: return left <= right; case OP_GE: return left >= right; default: return 0; } }

// --- UPDATED eval_ast ---
void eval_ast(ASTNode *n) {
    if (!n) return;
    switch(n->type) {
        case NODE_TYPE_STMTS: if (n->node.stmts.next) eval_ast(n->node.stmts.next); eval_ast(n->node.stmts.stmt); break;
        case NODE_TYPE_DECL:
            declare_var(n->node.decl.name, eval_expr_numeric(n->node.decl.value));
            break;
        case NODE_TYPE_ASSIGNMENT:
            update_var_value(n->node.decl.name, eval_expr_numeric(n->node.decl.value));
            break;
        case NODE_TYPE_RECT: { double x = eval_expr_numeric(n->node.rect.x); double y = eval_expr_numeric(n->node.rect.y); double w = eval_expr_numeric(n->node.rect.w); double h = eval_expr_numeric(n->node.rect.h); printf("  <rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\" fill=\"%s\"/>\n", x, y, w, h, eval_expr_string(n->node.rect.fill)); break; }
        case NODE_TYPE_LINE: { double x1 = eval_expr_numeric(n->node.line.x1); double y1 = eval_expr_numeric(n->node.line.y1); double x2 = eval_expr_numeric(n->node.line.x2); double y2 = eval_expr_numeric(n->node.line.y2); printf("  <line x1=\"%gcm\" y1=\"%gcm\" x2=\"%gcm\" y2=\"%gcm\" stroke=\"%s\" stroke-width=\"0.1cm\"/>\n", x1, y1, x2, y2, eval_expr_string(n->node.line.stroke)); break; }
        case NODE_TYPE_WHILE:
            while(eval_condition(&n->node.while_loop.condition->node.condition)) {
                enter_scope();
                eval_ast(n->node.while_loop.body);
                exit_scope();
            }
            break;
        case NODE_TYPE_IF:
            if (eval_condition(&n->node.if_stmt.condition->node.condition)) {
                enter_scope();
                eval_ast(n->node.if_stmt.if_body);
                exit_scope();
            } else if (n->node.if_stmt.else_body) {
                enter_scope();
                eval_ast(n->node.if_stmt.else_body);
                exit_scope();
            }
            break;
        default: break;
    }
}

// --- Free Functions (No changes needed) ---
void free_expr(ExprNode *e) { if (!e) return; switch(e->type) { case NODE_TYPE_EXPR_ID: case NODE_TYPE_EXPR_COLOR: free(e->data.sval); break; case NODE_TYPE_EXPR_OP: free_expr(e->data.op.left); free_expr(e->data.op.right); break; case NODE_TYPE_EXPR_NUM: break; default: break; } free(e); }
void free_ast(ASTNode *n) { if (!n) return; switch(n->type) { case NODE_TYPE_STMTS: free_ast(n->node.stmts.stmt); free_ast(n->node.stmts.next); break; case NODE_TYPE_ASSIGNMENT: case NODE_TYPE_DECL: free(n->node.decl.name); free_expr(n->node.decl.value); break; case NODE_TYPE_RECT: free_expr(n->node.rect.x); free_expr(n->node.rect.y); free_expr(n->node.rect.w); free_expr(n->node.rect.h); free_expr(n->node.rect.fill); break; case NODE_TYPE_LINE: free_expr(n->node.line.x1); free_expr(n->node.line.y1); free_expr(n->node.line.x2); free_expr(n->node.line.y2); free_expr(n->node.line.stroke); break; case NODE_TYPE_WHILE: free_ast(n->node.while_loop.condition); free_ast(n->node.while_loop.body); break; case NODE_TYPE_IF: free_ast(n->node.if_stmt.condition); free_ast(n->node.if_stmt.if_body); if (n->node.if_stmt.else_body) free_ast(n->node.if_stmt.else_body); break; case NODE_TYPE_CONDITION: free_expr(n->node.condition.left); free_expr(n->node.condition.right); break; default: break; } free(n); }