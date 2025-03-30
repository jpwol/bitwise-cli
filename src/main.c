#include "Parse.h"

int main() {
  printf("\033[35m>>>\033[0m ");
  char input[MAX_EXPR_LEN];

  while ((fgets(input, MAX_EXPR_LEN, stdin) != NULL)) {
    Token tokens[MAX_TOKENS];
    Token rpn[MAX_TOKENS];

    // printf("\033[35m>>>\033[0m ");
    // newlines in my buffer? more likely than you think
    input[strcspn(input, "\n")] = '\0';

    int token_count = tokenize(input, tokens);
    int rpn_count = shunting_yard(tokens, token_count, rpn);

    printf("%d\n", evaluate(rpn, rpn_count));
    printf("\033[35m>>>\033[0m ");
  }

  return 0;
}
