%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h" // The new header for all AST definitions

/* --- Symbol Table for Variables --- */
#define MAX_VARS 100
struct var {
    char name[32];
    double value;
};
struct var vars[MAX_VARS];
int var_count = 0;

/* --- Global Canvas Dimensions --- */
double canvas_width = 21.0;  // Default A4 width in cm
double canvas_height = 29.7; // Default A4 height in cm

// Forward declarations for functions defined in this file
int yylex(void);
int yyerror(const char *s);
double get_var_value(const char* name);
int add_or_update_var(const char *name, double value);

%}

/* =======================================================
 *  BISON DECLARATIONS
 * =======================================================*/

%union {
    int ival;
    double dval;
    char *sval;
    ASTNode *node;      /* Pointer to any AST node */
    ExprNode *expr;     /* Pointer to an expression node */
    CmpOp op;           /* A comparison operator */
}

/* --- Token Definitions --- */
%token <sval> ID
%token <dval> NUM
%token <sval> COLOR
%token INT RECT FILL NUMDECL LINE CANVAS WHILE
%token LT GT EQ NE LE GE

/* --- Grammar Rule Type Definitions --- */
%type <node> program stmts stmt rect_cmd line_cmd decl while_loop condition assignment
%type <expr> arg color_arg fill_opt line_opt
%type <op> cmp_op

%%

/* =======================================================
 *  GRAMMAR RULES
 * =======================================================*/

program: optional_canvas_decl stmts {
        printf("<svg width=\"%gcm\" height=\"%gcm\" xmlns=\"http://www.w3.org/2000/svg\">\n", canvas_width, canvas_height);
        if ($2) {
            eval_ast($2); // Evaluate the entire AST
            free_ast($2); // Free the memory
        }
        printf("</svg>\n");
    }
    ;

optional_canvas_decl: /* empty */
                    | CANVAS arg arg {
                        // NOTE: This currently only supports literal numbers for canvas size, not variables.
                        if ($2->type == NODE_TYPE_EXPR_NUM && $3->type == NODE_TYPE_EXPR_NUM) {
                           canvas_width = $2->val.dval;
                           canvas_height = $3->val.dval;
                        }
                        // We consume the expression nodes here, so we free them
                        free($2);
                        free($3);
                    }
                    ;

stmts: /* empty */  { $$ = NULL; }
     | stmts stmt { $$ = new_stmt_list($2, $1); }
     ;

stmt: decl          { $$ = $1; }
    | assignment    { $$ = $1; }
    | rect_cmd      { $$ = $1; }
    | line_cmd      { $$ = $1; }
    | while_loop    { $$ = $1; }
    ;

while_loop: WHILE '(' condition ')' '{' stmts '}' {
        $$ = new_while($3, $6);
    }
    ;

condition: arg cmp_op arg { $$ = new_condition($2, $1, $3); }
    ;

cmp_op: LT { $$ = OP_LT; } | GT { $$ = OP_GT; } | EQ { $$ = OP_EQ; }
      | NE { $$ = OP_NE; } | LE { $$ = OP_LE; } | GE { $$ = OP_GE; }
      ;

decl: NUMDECL ID '=' arg { $$ = new_decl($2, $4); } ;

assignment: ID '=' arg { $$ = new_decl($1, $3); } ;

rect_cmd: RECT arg arg arg arg fill_opt {
        $$ = new_rect_cmd($2, $3, $4, $5, $6);
    }
    ;

line_cmd: LINE arg arg arg arg line_opt {
        $$ = new_line_cmd($2, $3, $4, $5, $6);
    }
    ;

arg: NUM { $$ = new_expr_num($1); }
   | ID  { $$ = new_expr_id($1); }
   ;

fill_opt: /* empty */ { $$ = NULL; }
        | FILL '=' color_arg { $$ = $3; }
        ;

line_opt: /* empty */ { $$ = NULL; }
        | FILL '=' color_arg { $$ = $3; }
        ;

color_arg: ID { $$ = new_expr_id($1); }
         | COLOR { $$ = new_expr_color($1); }
         ;

%%
/* =======================================================
 *  C CODE SECTION
 * =======================================================*/

int main(void) {
    return yyparse();
}

int yyerror(const char *s) {
    fprintf(stderr, "Parse Error: %s\n", s);
    return 1;
}

/* --- SYMBOL TABLE FUNCTIONS --- */

// Adds a new variable or updates an existing one.
int add_or_update_var(const char *name, double value) {
    // First, check if var exists to update it
    for (int i = 0; i < var_count; ++i) {
        if (strcmp(vars[i].name, name) == 0) {
            vars[i].value = value;
            return 0;
        }
    }
    // If not, add a new one, checking for overflow
    if (var_count >= MAX_VARS) {
        fprintf(stderr, "Runtime Error: Maximum number of variables (%d) reached.\n", MAX_VARS);
        return -1;
    }
    strncpy(vars[var_count].name, name, 31);
    vars[var_count].name[31] = '\0'; // Ensure null termination
    vars[var_count].value = value;
    var_count++;
    return 0;
}

// Retrieves a variable's value from the symbol table.
double get_var_value(const char* name) {
    for (int i = 0; i < var_count; ++i) {
        if (strcmp(vars[i].name, name) == 0) {
            return vars[i].value;
        }
    }
    fprintf(stderr, "Runtime Error: undefined variable '%s'\n", name);
    return 0.0; // Return 0 if not found
}

/* --- AST NODE CREATION FUNCTIONS --- */

ASTNode* new_stmt_list(ASTNode* stmt, ASTNode* next) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    if (!n) { yyerror("out of memory"); exit(1); }
    n->type = NODE_TYPE_STMTS;
    n->node.stmts.stmt = stmt;
    n->node.stmts.next = next;
    return n;
}

ASTNode* new_rect_cmd(ExprNode *x, ExprNode *y, ExprNode *w, ExprNode *h, ExprNode *fill) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    if (!n) { yyerror("out of memory"); exit(1); }
    n->type = NODE_TYPE_RECT;
    n->node.rect.x = x; n->node.rect.y = y; n->node.rect.w = w; n->node.rect.h = h;
    n->node.rect.fill = fill;
    return n;
}

ASTNode* new_line_cmd(ExprNode *x1, ExprNode *y1, ExprNode *x2, ExprNode *y2, ExprNode *stroke) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    if (!n) { yyerror("out of memory"); exit(1); }
    n->type = NODE_TYPE_LINE;
    n->node.line.x1 = x1; n->node.line.y1 = y1; n->node.line.x2 = x2; n->node.line.y2 = y2;
    n->node.line.stroke = stroke;
    return n;
}

ASTNode* new_decl(char* name, ExprNode* val) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    if (!n) { yyerror("out of memory"); exit(1); }
    // NOTE: This one node type is used for both declaration and assignment
    n->type = NODE_TYPE_DECL;
    n->node.decl.name = name;
    n->node.decl.value = val;
    return n;
}

ASTNode* new_while(ASTNode* cond, ASTNode* body) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    if (!n) { yyerror("out of memory"); exit(1); }
    n->type = NODE_TYPE_WHILE;
    n->node.while_loop.condition = cond;
    n->node.while_loop.body = body;
    return n;
}

ASTNode* new_condition(CmpOp op, ExprNode* left, ExprNode* right) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    if (!n) { yyerror("out of memory"); exit(1); }
    n->type = NODE_TYPE_CONDITION;
    n->node.condition.op = op;
    n->node.condition.left = left;
    n->node.condition.right = right;
    return n;
}

ExprNode* new_expr_num(double d) {
    ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode));
    if (!e) { yyerror("out of memory"); exit(1); }
    e->type = NODE_TYPE_EXPR_NUM;
    e->val.dval = d;
    return e;
}

ExprNode* new_expr_id(char* s) {
    ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode));
    if (!e) { yyerror("out of memory"); exit(1); }
    e->type = NODE_TYPE_EXPR_ID;
    e->val.sval = s;
    return e;
}

ExprNode* new_expr_color(char* s) {
    ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode));
    if (!e) { yyerror("out of memory"); exit(1); }
    e->type = NODE_TYPE_EXPR_COLOR;
    e->val.sval = s;
    return e;
}

/* --- AST EVALUATION FUNCTIONS --- */

// Evaluates an expression node to a double
double eval_expr_numeric(ExprNode *expr) {
    if (!expr) return 0.0;
    if (expr->type == NODE_TYPE_EXPR_NUM) {
        return expr->val.dval;
    }
    if (expr->type == NODE_TYPE_EXPR_ID) {
        return get_var_value(expr->val.sval);
    }
    fprintf(stderr, "Runtime Error: Expected numeric value but got something else.\n");
    return 0.0;
}

// Evaluates an expression node to a string (for colors)
const char* eval_expr_string(ExprNode *expr) {
    if (!expr) return "black"; // Default color
    if (expr->type == NODE_TYPE_EXPR_COLOR) {
        return expr->val.sval;
    }
    if (expr->type == NODE_TYPE_EXPR_ID) {
        // Here you could lookup color variable names.
        // For now we just assume the ID itself is a valid color name like "blue".
        return expr->val.sval;
    }
    return "black"; // Fallback
}


// Evaluates a condition, returning 1 for true, 0 for false
int eval_condition(ConditionNode *cond) {
    double left = eval_expr_numeric(cond->left);
    double right = eval_expr_numeric(cond->right);
    switch(cond->op) {
        case OP_LT: return left < right;
        case OP_GT: return left > right;
        case OP_EQ: return left == right;
        case OP_NE: return left != right;
        case OP_LE: return left <= right;
        case OP_GE: return left >= right;
        default: return 0; // Should not happen
    }
}

// The core recursive function to walk the AST and execute it
void eval_ast(ASTNode *n) {
    if (!n) return;

    switch(n->type) {
        case NODE_TYPE_STMTS:
            // The statement list is built backwards, so we must evaluate next first to run in correct order.
            if (n->node.stmts.next) {
                eval_ast(n->node.stmts.next);
            }
            eval_ast(n->node.stmts.stmt);
            break;

        case NODE_TYPE_DECL:
            {
                double val = eval_expr_numeric(n->node.decl.value);
                add_or_update_var(n->node.decl.name, val);
            }
            break;

        case NODE_TYPE_RECT:
            {
                double x = eval_expr_numeric(n->node.rect.x);
                double y = eval_expr_numeric(n->node.rect.y);
                double w = eval_expr_numeric(n->node.rect.w);
                double h = eval_expr_numeric(n->node.rect.h);
                const char* fill = "black"; // Default fill
                if (n->node.rect.fill) {
                    fill = eval_expr_string(n->node.rect.fill);
                }
                printf("  <rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\" fill=\"%s\"/>\n", x, y, w, h, fill);
            }
            break;

        case NODE_TYPE_LINE:
            {
                double x1 = eval_expr_numeric(n->node.line.x1);
                double y1 = eval_expr_numeric(n->node.line.y1);
                double x2 = eval_expr_numeric(n->node.line.x2);
                double y2 = eval_expr_numeric(n->node.line.y2);
                const char* stroke = "black";
                if(n->node.line.stroke) {
                   stroke = eval_expr_string(n->node.line.stroke);
                }
                printf("  <line x1=\"%gcm\" y1=\"%gcm\" x2=\"%gcm\" y2=\"%gcm\" stroke=\"%s\" stroke-width=\"0.1cm\"/>\n", x1, y1, x2, y2, stroke);
            }
            break;

        case NODE_TYPE_WHILE:
            while(eval_condition((ConditionNode*)n->node.while_loop.condition)) {
                eval_ast(n->node.while_loop.body);
            }
            break;

        default:
            fprintf(stderr, "Runtime Error: Unknown AST node type %d\n", n->type);
            break;
    }
}

// Memory Cleanup: Frees all nodes in the AST.
// This is important to prevent memory leaks.
void free_ast(ASTNode *n) {
    if (!n) return;

    switch(n->type) {
        case NODE_TYPE_STMTS:
            free_ast(n->node.stmts.stmt);
            free_ast(n->node.stmts.next);
            break;
        case NODE_TYPE_DECL:
            free(n->node.decl.name);
            free(n->node.decl.value);
            break;
        case NODE_TYPE_RECT:
            free(n->node.rect.x); free(n->node.rect.y); free(n->node.rect.w); free(n->node.rect.h);
            if (n->node.rect.fill) free(n->node.rect.fill);
            break;
        case NODE_TYPE_LINE:
            free(n->node.line.x1); free(n->node.line.y1); free(n->node.line.x2); free(n->node.line.y2);
            if (n->node.line.stroke) free(n->node.line.stroke);
            break;
        case NODE_TYPE_WHILE:
            free_ast(n->node.while_loop.condition);
            free_ast(n->node.while_loop.body);
            break;
        case NODE_TYPE_CONDITION:
            free(n->node.condition.left);
            free(n->node.condition.right);
            break;
        default:
            // No sub-nodes to free for expression nodes, they are freed by their parents
            break;
    }
    // Finally, free the node itself
    free(n);
}