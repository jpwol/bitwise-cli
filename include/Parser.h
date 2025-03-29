#ifndef PARSER_H
#define PARSER_H

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_TOKENS 100
#define MAX_LEN 256

typedef enum {
  TOKEN_NUMBER,
  TOKEN_VARIABLE,
  TOKEN_OPERATOR,
  TOKEN_LPAREN,
  TOKEN_RPAREN
} TokenType;

typedef struct {
  TokenType type;
  char value[16];
} Token;

int precedence(char op);
int tokenize(const char* input, Token tokens[]);
int infix_to_postfix(Token tokens[], int count, Token output[]);
int evaluate_rpn(Token rpn[], int count, int x);

#endif
