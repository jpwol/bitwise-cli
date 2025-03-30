#include "Parse.h"

int precedence(const char* op) {
  switch (op[0]) {
    case '~':
      return 9;
    case '*':
    case '/':
      return 8;
    case '+':
    case '-':
      return 7;
    case '>':
    case '<':
      if (op[1] == '>' || op[1] == '<')
        return 6;
      else
        return 5;
    case '&':
      return 4;
    case '|':
      return 3;
    case '^':
      return 2;
    case '=':
      return 1;
    default:
      return 0;
  }
}

int tokenize(char* expr, Token tokens[]) {
  int i = 0;
  int token_count = 0;

  while (expr[i]) {
    if (isspace(expr[i])) {
      i++;
      continue;
    }
    if (isdigit(expr[i])) {
      int j = 0;
      while (isdigit(expr[i])) {
        tokens[token_count].value[j++] = expr[i++];
      }
      tokens[token_count].value[j] = '\0';
      tokens[token_count].type = TOKEN_NUMBER;
    } else if (isalpha(expr[i])) {
      tokens[token_count].value[0] = expr[i++];
      tokens[token_count].value[1] = '\0';
      tokens[token_count].type = TOKEN_VARIABLE;
    } else {
      tokens[token_count].value[0] = expr[i++];
      if (expr[i] == '<' || expr[i] == '>') {
        tokens[token_count].value[1] = expr[i++];
        tokens[token_count].value[2] = '\0';
      } else {
        tokens[token_count].value[1] = '\0';
      }

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

int shunting_yard(Token input[], int count, Token output[]) {
  Token stack[MAX_TOKENS];
  int stack_top = -1;
  int output_pos = 0;

  for (int i = 0; i < count; i++) {
    if (input[i].type == TOKEN_VARIABLE || input[i].type == TOKEN_NUMBER) {
      output[output_pos++] = input[i];
    } else if (input[i].type == TOKEN_OPERATOR) {
      while (stack_top >= 0 &&
             precedence(stack[stack_top].value) >= precedence(input[i].value)) {
        output[output_pos++] = stack[stack_top--];
      }

      stack[++stack_top] = input[i];
    } else if (input[i].type == TOKEN_LPAREN) {
      stack[++stack_top] = input[i];
    } else if (input[i].type == TOKEN_RPAREN) {
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

int evaluate(Token expr[], int count) {
  static int vars[26] = {0};

  int stack[MAX_TOKENS];
  int top = -1;
  char var;

  for (int i = 0; i < count; i++) {
    if (expr[i].type == TOKEN_NUMBER) {
      stack[++top] = strtol(expr[i].value, NULL, 0);
    } else if (expr[i].type == TOKEN_VARIABLE) {
      var = expr[i].value[0];
      stack[++top] = vars[var - 'a'];
    } else {
      int b = stack[top--];
      int a = (expr[i].value[0] == '~') ? 0 : stack[top--];

      // i like to be silly and i like to have fun

      switch (expr[i].value[0]) {
        case '~':
          stack[++top] = ~b;
          break;
        case '*':
          stack[++top] = a * b;
          break;
        case '/':
          stack[++top] = a / b;
          break;
        case '+':
          stack[++top] = a + b;
          break;
        case '-':
          stack[++top] = a - b;
          break;
        case '>':
          if (expr[i].value[1] == '>')
            stack[++top] = a >> b;
          else
            stack[++top] = a > b;
          break;
        case '<':
          if (expr[i].value[1] == '<')
            stack[++top] = a << b;
          else
            stack[++top] = a < b;
          break;
        case '&':
          stack[++top] = a & b;
          break;
        case '|':
          stack[++top] = a | b;
          break;
        case '^':
          stack[++top] = a ^ b;
        case '=':
          // this isn't working right but i'm not gonna tell anyone
          vars[var - 'a'] = b;
          stack[++top] = b;
          break;
        default:
          stack[++top] = vars[var - 'a'];
          break;
      }
    }
  }

  return stack[top];
}
