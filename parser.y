%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations
struct ASTNode;
void eval_ast(struct ASTNode *node);
void free_ast(struct ASTNode *node);
double get_var_value(const char* name);

/* --- Symbol Table (no changes) --- */
#define MAX_VARS 100
struct var {
    char name[32];
    double value;
};
struct var vars[MAX_VARS];
int var_count = 0;

// --- Canvas Globals (no changes) ---
double canvas_width = 21.0;
double canvas_height = 29.7;


/*******************************************************
*   1. ABSTRACT SYNTAX TREE (AST) NODE DEFINITIONS     *
********************************************************/

// Enum for all possible node types in our AST
typedef enum {
    NODE_TYPE_STMTS,
    NODE_TYPE_RECT,
    NODE_TYPE_LINE,
    NODE_TYPE_DECL,
    NODE_TYPE_WHILE,
    NODE_TYPE_CONDITION,
    NODE_TYPE_EXPR_NUM,
    NODE_TYPE_EXPR_ID,
    NODE_TYPE_EXPR_COLOR
} NodeType;

// Enum for comparison operators
typedef enum {
    OP_LT = 1, OP_GT, OP_EQ, OP_NE, OP_LE, OP_GE
} CmpOp;

// The basic building block for an expression (a number, variable, or color)
typedef struct {
    NodeType type;
    union {
        double dval;
        char *sval;
    } val;
} ExprNode;

// Node for a list of statements (linked list)
typedef struct {
    NodeType type;
    struct ASTNode *stmt;
    struct ASTNode *next;
} StmtListNode;

// Node for a RECT command
typedef struct {
    NodeType type;
    ExprNode *x, *y, *w, *h;
    ExprNode *fill;
} RectNode;

// Node for a LINE command
typedef struct {
    NodeType type;
    ExprNode *x1, *y1, *x2, *y2;
    ExprNode *stroke;
} LineNode;

// Node for a variable declaration
typedef struct {
    NodeType type;
    char *name;
    ExprNode *value;
} DeclNode;

// Node for a conditional expression (e.g., i < 10)
typedef struct {
    NodeType type;
    CmpOp op;
    ExprNode *left;
    ExprNode *right;
} ConditionNode;

// Node for a WHILE loop
typedef struct {
    NodeType type;
    struct ASTNode *condition;
    struct ASTNode *body; // A list of statements
} WhileNode;

// The generic AST node that holds all other node types
typedef struct ASTNode {
    NodeType type;
    union {
        StmtListNode stmts;
        RectNode rect;
        LineNode line;
        DeclNode decl;
        WhileNode while_loop;
        ConditionNode condition;
        ExprNode expr;
    } node;
} ASTNode;


/*******************************************************
*   2. AST HELPER FUNCTIONS (Node Creation)            *
********************************************************/

// Functions to create nodes on the heap
ASTNode* new_stmt_list(ASTNode* stmt, ASTNode* next) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    n->type = NODE_TYPE_STMTS;
    n->node.stmts.stmt = stmt;
    n->node.stmts.next = next;
    return n;
}

ASTNode* new_rect_cmd(ExprNode *x, ExprNode *y, ExprNode *w, ExprNode *h, ExprNode *fill) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    n->type = NODE_TYPE_RECT;
    n->node.rect.x = x; n->node.rect.y = y; n->node.rect.w = w; n->node.rect.h = h;
    n->node.rect.fill = fill;
    return n;
}

ASTNode* new_line_cmd(ExprNode *x1, ExprNode *y1, ExprNode *x2, ExprNode *y2, ExprNode *stroke) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    n->type = NODE_TYPE_LINE;
    n->node.line.x1 = x1; n->node.line.y1 = y1; n->node.line.x2 = x2; n->node.line.y2 = y2;
    n->node.line.stroke = stroke;
    return n;
}

ASTNode* new_decl(char* name, ExprNode* val) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    n->type = NODE_TYPE_DECL;
    n->node.decl.name = name;
    n->node.decl.value = val;
    return n;
}

ASTNode* new_while(ASTNode* cond, ASTNode* body) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    n->type = NODE_TYPE_WHILE;
    n->node.while_loop.condition = cond;
    n->node.while_loop.body = body;
    return n;
}

ASTNode* new_condition(CmpOp op, ExprNode* left, ExprNode* right) {
    ASTNode *n = (ASTNode*) malloc(sizeof(ASTNode));
    n->type = NODE_TYPE_CONDITION;
    n->node.condition.op = op;
    n->node.condition.left = left;
    n->node.condition.right = right;
    return n;
}

ExprNode* new_expr_num(double d) {
    ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode));
    e->type = NODE_TYPE_EXPR_NUM;
    e->val.dval = d;
    return e;
}

ExprNode* new_expr_id(char* s) {
    ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode));
    e->type = NODE_TYPE_EXPR_ID;
    e->val.sval = s;
    return e;
}

ExprNode* new_expr_color(char* s) {
    ExprNode *e = (ExprNode*) malloc(sizeof(ExprNode));
    e->type = NODE_TYPE_EXPR_COLOR;
    e->val.sval = s;
    return e;
}

// Function to add a variable to our symbol table
int add_or_update_var(const char *name, double value) {
    // First, check if var exists to update it
    for (int i = 0; i < var_count; ++i) {
        if (strcmp(vars[i].name, name) == 0) {
            vars[i].value = value;
            return 0;
        }
    }
    // If not, add a new one
    if (var_count >= MAX_VARS) return -1;
    strncpy(vars[var_count].name, name, 31);
    vars[var_count].name[31] = '\0';
    vars[var_count].value = value;
    var_count++;
    return 0;
}


int yylex(void);
int yyerror(const char *s);

%}

/* --- 3. BISON DECLARATIONS --- */
%union {
    int ival;
    double dval;
    char *sval;
    ASTNode *node;      /* Pointer to any AST node */
    ExprNode *expr;     /* Pointer to an expression node */
    CmpOp op;           /* A comparison operator */
}

/* Tokens */
%token <sval> ID
%token <dval> NUM
%token <sval> COLOR
%token INT RECT FILL NUMDECL LINE CANVAS WHILE
%token LT GT EQ NE LE GE

/* Non-terminal types */
%type <node> program stmts stmt rect_cmd line_cmd decl while_loop condition
%type <expr> arg color_arg fill_opt line_opt
%type <op> cmp_op

%%

/* --- 4. GRAMMAR RULES TO BUILD THE AST --- */
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
                    | CANVAS arg arg { canvas_width = $2->val.dval; canvas_height = $3->val.dval; free($2); free($3); }
                    ;

stmts: /* empty */  { $$ = NULL; }
     | stmts stmt { $$ = new_stmt_list($2, $1); }
     ;

stmt: decl      { $$ = $1; }
    | rect_cmd  { $$ = $1; }
    | line_cmd  { $$ = $1; }
    | while_loop { $$ = $1; }
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

decl: NUMDECL ID '=' NUM { $$ = new_decl($2, new_expr_num($4)); }
    ;

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
/* --- 5. EVALUATOR AND MAIN FUNCTIONS --- */

int main(void) {
    return yyparse();
}

int yyerror(const char *s) {
    fprintf(stderr, "Parse Error: %s\n", s);
    return 1;
}

// Helper to get a variable's value from the symbol table
double get_var_value(const char* name) {
    for (int i = 0; i < var_count; ++i) {
        if (strcmp(vars[i].name, name) == 0) {
            return vars[i].value;
        }
    }
    fprintf(stderr, "Runtime Error: undefined variable '%s'\n", name);
    return 0.0; // Return 0 if not found
}

// Evaluates an expression node to a double
double eval_expr_numeric(ExprNode *expr) {
    if (!expr) return 0.0;
    if (expr->type == NODE_TYPE_EXPR_NUM) {
        return expr->val.dval;
    }
    if (expr->type == NODE_TYPE_EXPR_ID) {
        return get_var_value(expr->val.sval);
    }
    fprintf(stderr, "Runtime Error: expected numeric value, got something else.\n");
    return 0.0;
}

// Evaluates an expression node to a string (for colors)
const char* eval_expr_string(ExprNode *expr) {
    if (!expr) return "black"; // Default
    if (expr->type == NODE_TYPE_EXPR_COLOR) {
        return expr->val.sval;
    }
    if (expr->type == NODE_TYPE_EXPR_ID) {
        // Here you could lookup color names, but for now we just use the ID as color
        return expr->val.sval;
    }
    return "black";
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
        default: return 0;
    }
}

// The core recursive function to walk the AST and execute it
void eval_ast(ASTNode *n) {
    if (!n) return;

    switch(n->type) {
        case NODE_TYPE_STMTS:
            // The list is built backwards, so we evaluate next first to run in order
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
                if (n->node.rect.fill) {
                    const char* fill = eval_expr_string(n->node.rect.fill);
                    printf("  <rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\" fill=\"%s\"/>\n", x, y, w, h, fill);
                } else {
                    printf("  <rect x=\"%gcm\" y=\"%gcm\" width=\"%gcm\" height=\"%gcm\"/>\n", x, y, w, h);
                }
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
                printf("  <line x1=\"%gcm\" y1=\"%gcm\" x2=\"%gcm\" y2=\"%gcm\" stroke=\"%s\" stroke-width=\"0.1\"/>\n", x1, y1, x2, y2, stroke);
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

// Simple memory cleanup (can be improved)
void free_ast(ASTNode *n) {
    if (!n) return;
    // This is a simplified free function. A real one would need to be more careful.
    // For this example, we accept the memory leak from strings and expressions to keep it simple.
    free(n);
}