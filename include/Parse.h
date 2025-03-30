#ifndef PARSE_H
#define PARSE_H

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_TOKENS 100
#define MAX_EXPR_LEN 256

typedef enum {
  TOKEN_NUMBER,
  TOKEN_VARIABLE,
  TOKEN_OPERATOR,
  TOKEN_LPAREN,
  TOKEN_RPAREN,
} TokenType;

typedef struct {
  TokenType type;
  char value[16];
} Token;

int precedence(const char* expr);
int tokenize(char* expr, Token tokens[]);
int shunting_yard(Token input[], int count, Token output[]);
int evaluate(Token expr[], int count);

#endif
