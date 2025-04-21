%{
/* Lexical analyzer for micro C language */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#include "a9_220101003.tab.hpp"

extern int line_no;
int line_no = 1;

extern FILE* lex_output;

// Helper using new[] for C++ compatibility
char* make_string_copy(const char* source) {
    if (!source) return nullptr;
    char* new_str = new char[strlen(source) + 1];
    strcpy(new_str, source);
    return new_str;
}

/* Helper function to log token information */
void log_token(const char* token_type, const char* lexeme) {
    if (lex_output != NULL) {
        fprintf(lex_output, "%d: %-15s", line_no, token_type);
        if (lexeme != NULL) {
            fprintf(lex_output, " [%s]", lexeme);
        }
        fprintf(lex_output, "\n");
    }
}
%}

%option nounput

NUMERIC     [0-9]
POSITIVE    [1-9]
LETTER      [a-zA-Z]
NONDIGIT    [a-zA-Z_]
BLANK       [ \t\r]
EOL         \n

%%

"return"    { log_token("RETURN", yytext); return RETURN; }
"void"      { log_token("VOID", yytext); return VOID; }
"float"     { log_token("FLOAT", yytext); return FLOAT; }
"integer"   { log_token("INTEGER", yytext); return INTEGER; }
"char"      { log_token("CHAR", yytext); return CHAR; }
"for"       { log_token("FOR", yytext); return FOR; }
"const"     { log_token("CONST", yytext); return CONST; }
"while"     { log_token("WHILE", yytext); return WHILE; }
"bool"      { log_token("BOOL", yytext); return BOOL; }
"if"        { log_token("IF", yytext); return IF; }
"do"        { log_token("DO", yytext); return DO; }
"else"      { log_token("ELSE", yytext); return ELSE; }
"begin"     { log_token("BEGIN", yytext); return BEGIN_TOKEN; }
"end"       { log_token("END", yytext); return END_TOKEN; }

{LETTER}({NONDIGIT}|{NUMERIC})* {
    yylval.sval = make_string_copy(yytext);
    log_token("IDENTIFIER", yytext);
    return IDENTIFIER;
}

"0" {
    yylval.ival = 0;
    log_token("INT_CONSTANT", "0");
    return INT_CONSTANT;
}

{POSITIVE}{NUMERIC}* {
    int val = 0;
    int i = 0;
    while (yytext[i] != '\0') {
        val = val * 10 + (yytext[i] - '0');
        i++;
    }
    yylval.ival = val;
    log_token("INT_CONSTANT", yytext);
    return INT_CONSTANT;
}

{NUMERIC}*"."{NUMERIC}*([eE][+-]?{NUMERIC}+)? {
    double val = 0.0;
    sscanf(yytext, "%lf", &val);
    yylval.fval = (float)val;
    log_token("FLOAT_CONSTANT", yytext);
    return FLOAT_CONSTANT;
}

{NUMERIC}+[eE][+-]?{NUMERIC}+ {
    double val = 0.0;
    sscanf(yytext, "%lf", &val);
    yylval.fval = (float)val;
    log_token("FLOAT_CONSTANT", yytext);
    return FLOAT_CONSTANT;
}

\'([^\'\\\n]|\\[\'\"?\\abfnrtv])\' {
    char actual_char;
    
    if (yytext[1] != '\\') {
        actual_char = yytext[1];
    } else {
        /* Handle escape sequences with strcoll-like mapping */
        const char escape = yytext[2];
        switch (escape) {
            case '\'': actual_char = '\''; break;
            case '\"': actual_char = '\"'; break;
            case '?':  actual_char = '\?'; break;
            case '\\': actual_char = '\\'; break;
            case 'a':  actual_char = '\a'; break;
            case 'b':  actual_char = '\b'; break;
            case 'f':  actual_char = '\f'; break;
            case 'n':  actual_char = '\n'; break;
            case 'r':  actual_char = '\r'; break;
            case 't':  actual_char = '\t'; break;
            case 'v':  actual_char = '\v'; break;
            default:   actual_char = escape;
        }
    }
    
    yylval.cval = actual_char;
    log_token("CHAR_CONSTANT", yytext);
    return CHAR_CONSTANT;
}

\"([^\"\\\n]|\\[\'\"?\\abfnrtv])*\" {
    yylval.sval = make_string_copy(yytext);
    log_token("STRING_LITERAL", yytext);
    return STRING_LITERAL;
}

"->"        { log_token("ARROW", NULL); return ARROW; }
"++"        { log_token("INC", NULL); return INC; }
"--"        { log_token("DEC", NULL); return DEC; }
"<<"        { log_token("SHL", NULL); return SHL; }
">>"        { log_token("SHR", NULL); return SHR; }
"<="        { log_token("LE", NULL); return LE; }
">="        { log_token("GE", NULL); return GE; }
"=="        { log_token("EQ", NULL); return EQ; }
"!="        { log_token("NE", NULL); return NE; }
"&&"        { log_token("AND", NULL); return AND; }
"||"        { log_token("OR", NULL); return OR; }

"["         { log_token("PUNCTUATOR", "["); return '['; }
"]"         { log_token("PUNCTUATOR", "]"); return ']'; }
"("         { log_token("PUNCTUATOR", "("); return '('; }
")"         { log_token("PUNCTUATOR", ")"); return ')'; }
"&"         { log_token("PUNCTUATOR", "&"); return '&'; }
"*"         { log_token("PUNCTUATOR", "*"); return '*'; }
"+"         { log_token("PUNCTUATOR", "+"); return '+'; }
"-"         { log_token("PUNCTUATOR", "-"); return '-'; }
"!"         { log_token("PUNCTUATOR", "!"); return '!'; }
"/"         { log_token("PUNCTUATOR", "/"); return '/'; }
"%"         { log_token("PUNCTUATOR", "%"); return '%'; }
"<"         { log_token("PUNCTUATOR", "<"); return '<'; }
">"         { log_token("PUNCTUATOR", ">"); return '>'; }
"~"         { log_token("PUNCTUATOR", "~"); return '~'; }
"|"         { log_token("PUNCTUATOR", "|"); return '|'; }
"?"         { log_token("PUNCTUATOR", "?"); return '?'; }
":"         { log_token("PUNCTUATOR", ":"); return ':'; }
";"         { log_token("PUNCTUATOR", ";"); return ';'; }
"="         { log_token("PUNCTUATOR", "="); return '='; }
","         { log_token("PUNCTUATOR", ","); return ','; }

"/*"        {
    log_token("COMMENT_START", "/*");
    int end_found = 0;
    char current, previous = '\0';
    
    while (!end_found) {
        current = yyinput();
        
        if (current == EOF) {
            fprintf(lex_output, "Line %d: WARNING - Unterminated comment\n", line_no);
            fprintf(stderr, "Warning: Unterminated comment at line %d\n", line_no);
            break;
        }
        if (current == '\0') break;        
        if (current == '\n') {
            line_no++;
            fprintf(lex_output, "%d: COMMENT_CONTINUES\n", line_no);
        }
        if (previous == '*' && current == '/') {
            end_found = 1;
            fprintf(lex_output, "%d: COMMENT_END\n", line_no);
        }
        
        previous = current;
    }
}

"//"        {
    log_token("COMMENT", "//");
    
    /* Different approach to single-line comment handling */
    char c;
    do {
        c = yyinput();
        if (c == '\n') {
            line_no++;
            break;
        }
    } while (c != '\0' && c != EOF);
}

{EOL}   { line_no++; }
{BLANK}+ { /* ignore */ }

.           { 
    fprintf(lex_output, "Line %d: ERROR - Unknown token '%s'\n", line_no, yytext);
    fprintf(stderr, "Error: Unrecognized character '%s' at line %d\n", yytext, line_no); 
}

%%

int yywrap() {
    return 1;
}
