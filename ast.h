#ifndef AST_H
#define AST_H

// Enum for all possible node types in our AST
typedef enum {
    NODE_TYPE_STMTS,
    NODE_TYPE_RECT,
    NODE_TYPE_LINE,
    NODE_TYPE_DECL,
    NODE_TYPE_ASSIGNMENT, // Separate type for clarity
    NODE_TYPE_WHILE,
    NODE_TYPE_CONDITION,
    NODE_TYPE_EXPR_NUM,
    NODE_TYPE_EXPR_ID,
    NODE_TYPE_EXPR_COLOR,
    NODE_TYPE_EXPR_OP // For binary operations +, -, *, /
} NodeType;

// Enum for comparison operators
typedef enum {
    OP_LT = 1, OP_GT, OP_EQ, OP_NE, OP_LE, OP_GE
} CmpOp;

// Forward-declare the main struct so pointers can be used inside
struct ASTNode;

// Forward-declare ExprNode for use in OpNode
struct ExprNode;

// Node for a binary operation in an expression
typedef struct {
    int op; // The operator: '+', '-', '*', '/'
    struct ExprNode *left;
    struct ExprNode *right;
} OpNode;

// The basic building block for an expression. Can be a value or an operation.
typedef struct ExprNode {
    NodeType type;
    union {
        double dval;
        char *sval;
        OpNode op;
    } data;
} ExprNode;

// Node for a list of statements
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

// Node for a variable declaration or assignment
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
    struct ASTNode *body;
} WhileNode;

// The generic AST node that holds all other node types
typedef struct ASTNode {
    NodeType type;
    union {
        StmtListNode stmts;
        RectNode rect;
        LineNode line;
        DeclNode decl; // Used for both decl and assignment
        WhileNode while_loop;
        ConditionNode condition;
        ExprNode expr;
    } node;
} ASTNode;

/* --- Function Prototypes for AST Helper/Evaluator Functions --- */
// These are defined in parser.y, but declared here for all files to see.

ASTNode* new_stmt_list(ASTNode* stmt, ASTNode* next);
ASTNode* new_rect_cmd(ExprNode *x, ExprNode *y, ExprNode *w, ExprNode *h, ExprNode *fill);
ASTNode* new_line_cmd(ExprNode *x1, ExprNode *y1, ExprNode *x2, ExprNode *y2, ExprNode *stroke);
ASTNode* new_decl(char* name, ExprNode* val);
ASTNode* new_assignment(char* name, ExprNode* val);
ASTNode* new_while(ASTNode* cond, ASTNode* body);
ASTNode* new_condition(CmpOp op, ExprNode* left, ExprNode* right);
ExprNode* new_expr_num(double d);
ExprNode* new_expr_id(char* s);
ExprNode* new_expr_op(int op, ExprNode *left, ExprNode *right); // For operations
ExprNode* new_expr_color(char* s);

void eval_ast(struct ASTNode *node);
void free_ast(struct ASTNode *node);
void free_expr(ExprNode *e);

#endif // AST_H