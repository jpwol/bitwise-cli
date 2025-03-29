#include "Parser.h"

int main() {
  char expr[MAX_LEN];
  int x;

  printf("Enter value of x: ");
  scanf("%d", &x);

  getchar();  // newlines in my buffer? more likely than you think

  printf("Enter bitwise expression (using x): ");
  fgets(expr, MAX_LEN, stdin);
  expr[strcspn(expr, "\n")] = '\0';

  Token tokens[MAX_TOKENS], rpn[MAX_TOKENS];
  int token_count = tokenize(expr, tokens);
  int rpn_count = infix_to_postfix(tokens, token_count, rpn);

  int result = evaluate_rpn(rpn, rpn_count, x);
  printf("Result: %d\n", result);

  return 0;
}
