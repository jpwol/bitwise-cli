#include "Parse.h"

int main() {
  while (1) {
    char input[MAX_EXPR_LEN];

    Token tokens[MAX_TOKENS];
    Token rpn[MAX_TOKENS];

    printf("\033[35m>>>\033[0m ");
    fgets(input, MAX_EXPR_LEN, stdin);
    // newlines in my buffer? more likely than you think
    input[strcspn(input, "\n")] = '\0';

    int token_count = tokenize(input, tokens);
    int rpn_count = shunting_yard(tokens, token_count, rpn);

    printf("%d\n", evaluate(rpn, rpn_count));
  }

  return 0;
}
