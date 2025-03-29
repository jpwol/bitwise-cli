#include "Parser.h"

// calculate operator precedence
int precedence(char op) {
  switch (op) {
    case '~':
      return 5;
    case '<':
    case '>':
      return 4;
    case '&':
      return 3;
    case '^':
      return 2;
    case '|':
      return 1;
    default:
      return 0;
  }
}

int tokenize(const char* input, Token tokens[]) {
  int i = 0;
  int token_count = 0;

  while (input[i]) {
    if (isspace(input[i])) {
      i++;
      continue;
    }
    if (isdigit(input[i])) {
      int j = 0;
      while (isdigit(input[i]) || input[i] == 'b' || input[i] == 'x') {
        tokens[token_count].value[j++] = input[i++];
      }
      tokens[token_count].value[j] = '\0';
      tokens[token_count].type = TOKEN_NUMBER;
    } else if (isalpha(input[i])) {
      tokens[token_count].value[0] = input[i++];
      tokens[token_count].value[1] = '\0';
      tokens[token_count].type = TOKEN_VARIABLE;
    } else {
      tokens[token_count].value[0] = input[i++];
      tokens[token_count].value[1] = '\0';
      if (input[i] == '<' || input[i] == '>') i++;

      if (tokens[token_count].value[0] == '(')
        tokens[token_count].type = TOKEN_LPAREN;
      else if (tokens[token_count].value[0] == ')')
        tokens[token_count].type = TOKEN_RPAREN;
      else
        tokens[token_count].type = TOKEN_OPERATOR;
    }
    token_count++;
  }
  return token_count;
}

int infix_to_postfix(Token tokens[], int count, Token output[]) {
  Token stack[MAX_TOKENS];
  int stack_top = -1;
  int output_pos = 0;

  for (int i = 0; i < count; i++) {
    if (tokens[i].type == TOKEN_NUMBER || tokens[i].type == TOKEN_VARIABLE) {
      output[output_pos++] = tokens[i];
    } else if (tokens[i].type == TOKEN_OPERATOR) {
      while (stack_top >= 0 && precedence(stack[stack_top].value[0]) >=
                                   precedence(tokens[i].value[0])) {
        output[output_pos++] = stack[stack_top--];
      }
      stack[++stack_top] = tokens[i];
    } else if (tokens[i].type == TOKEN_LPAREN) {
      stack[++stack_top] = tokens[i];
    } else if (tokens[i].type == TOKEN_RPAREN) {
      while (stack_top >= 0 && stack[stack_top].type != TOKEN_LPAREN) {
        output[output_pos++] = stack[stack_top--];
      }
      stack_top--;
    }
  }

  while (stack_top >= 0) {
    output[output_pos++] = stack[stack_top--];
  }

  return output_pos;
}

int evaluate_rpn(Token rpn[], int count, int x) {
  int stack[MAX_TOKENS];
  int top = -1;

  for (int i = 0; i < count; i++) {
    if (rpn[i].type == TOKEN_NUMBER) {
      stack[++top] = strtol(rpn[i].value, NULL, 0);
    } else if (rpn[i].type == TOKEN_VARIABLE) {
      stack[++top] = x;
    } else {
      int b = stack[top--];
      int a = (rpn[i].value[0] == '~')
                  ? 0
                  : stack[top--];  // ~ is unary, don't need to pop the next
                                   // value yahurrr
      switch (rpn[i].value[0]) {
        case '&':
          stack[++top] = a & b;
          break;
        case '|':
          stack[++top] = a | b;
          break;
        case '^':
          stack[++top] = a ^ b;
          break;
        case '~':
          stack[++top] = ~b;
          break;
        case '<':
          stack[++top] = a << b;
          break;
        case '>':
          stack[++top] = a >> b;
          break;
      }
    }
  }

  return stack[top];
}
