#include <stdio.h>
int main() {
    extern int yyparse();
    return yyparse();
}
