%{
/* Parser for micro C language (Phase 3 - Expression TAC Generation - CORRECTED v4 - NO MACRO) */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
#include <list>
#include <sstream> /* For converting constants to string */

/* External declarations */
extern int yylex();
extern FILE* yyin;
extern int line_no;
extern char* yytext;
extern FILE* lex_output; /* Keep for logging */

/* Function Prototypes */
void yyerror(const char* s);

/* --- NO BINARY_OP_ACTION Macro Here --- */

%}

%code requires {
    #include "a9_220101003.h"

    /* Structure for declarator attributes (from Phase 2) */
    struct DeclaratorAttributes {
        std::string name;
        TypeInfo* type;
        int array_dim;
        DeclaratorAttributes() : type(nullptr), array_dim(0) {}
        ~DeclaratorAttributes() {}
    };

    /* Structure for expression attributes (Phase 3) */
    struct ExprAttributes {
        Symbol* place = nullptr;
        TypeInfo* type = nullptr;
        ExprAttributes() {}
         ~ExprAttributes() { /* Assume type owned elsewhere */ }
    };
}

/* Bison Declarations */

%union {
    int ival;
    float fval;
    char cval;
    char* sval; /* From lexer, MUST delete[] */

    Symbol* sym_ptr;
    TypeInfo* type_ptr;
    BackpatchList* list_ptr;

    DeclaratorAttributes* decl_attr_ptr; /* Phase 2 */
    ExprAttributes* expr_attr_ptr;       /* Phase 3 */
};

/* Token Types */
%token <ival> INT_CONSTANT
%token <fval> FLOAT_CONSTANT
%token <cval> CHAR_CONSTANT
%token <sval> IDENTIFIER STRING_LITERAL

/* Keywords & Operators */
%token RETURN VOID FLOAT INTEGER CHAR FOR CONST WHILE BOOL IF DO ELSE BEGIN_TOKEN END_TOKEN
%token ARROW INC DEC SHL SHR LE GE EQ NE AND OR

/* Non-terminal Types */
%type <decl_attr_ptr> direct_declarator declarator init_declarator init_declarator_list init_declarator_list_opt
%type <type_ptr> type_specifier

/* --- Phase 3: %type for expressions --- */
%type <expr_attr_ptr> primary_expression postfix_expression unary_expression
%type <expr_attr_ptr> multiplicative_expression additive_expression relational_expression
%type <expr_attr_ptr> equality_expression logical_AND_expression logical_OR_expression
%type <expr_attr_ptr> conditional_expression assignment_expression expression
%type <expr_attr_ptr> initializer argument_expression_list
%type <ival> unary_operator
%type <expr_attr_ptr> expression_opt
/* --- End Phase 3 --- */


/* Operator Precedence and Associativity */
%right '='
%left OR
%left AND
%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/' '%'
%right '!' /* Logical NOT (unary) */
%precedence UMINUS /* Placeholder for unary minus precedence */

/* Dangling else */
%nonassoc IFX
%nonassoc ELSE

/* Start symbol */
%start translation_unit

%%

/* Grammar Rules (Phase 3 - Expression TAC - CORRECTED v4 - NO MACRO) */

/* 1. Expressions */
primary_expression
    : IDENTIFIER {
        /* Phase 3: Lookup identifier */
        Symbol* sym = lookup_symbol($1, true);
        if (!sym) {
            yyerror(("Undeclared identifier '" + std::string($1) + "'").c_str());
            $$ = nullptr;
        } else if (!sym->type) {
             yyerror(("Identifier '" + std::string($1) + "' used before type assignment").c_str());
             $$ = nullptr;
        } else {
            $$ = new ExprAttributes();
            $$->place = sym;
            $$->type = sym->type;
            std::cout << "Debug: Primary IDENTIFIER '" << sym->name << "' type: " << sym->type->toString() << std::endl;
        }
        delete[] $1;
      }
    | INT_CONSTANT {
        /* Phase 3: Handle integer constant */
        TypeInfo* const_type = new TypeInfo(TYPE_INTEGER, 4);
        Symbol* temp = new_temp(const_type);
        std::string const_str = std::to_string($1);
        emit(OP_ASSIGN, temp->name, const_str);
        $$ = new ExprAttributes();
        $$->place = temp;
        $$->type = const_type;
        std::cout << "Debug: Primary INT_CONSTANT " << const_str << std::endl;
      }
    | FLOAT_CONSTANT {
        /* Phase 3: Handle float constant */
        TypeInfo* const_type = new TypeInfo(TYPE_FLOAT, 8); /* A9 spec */
        Symbol* temp = new_temp(const_type);
        std::ostringstream oss;
        oss << std::fixed << $1;
        std::string const_str = oss.str();
        emit(OP_ASSIGN, temp->name, const_str);
        $$ = new ExprAttributes();
        $$->place = temp;
        $$->type = const_type;
         std::cout << "Debug: Primary FLOAT_CONSTANT " << const_str << std::endl;
      }
    | CHAR_CONSTANT {
         /* Phase 3: Handle char constant */
         TypeInfo* const_type = new TypeInfo(TYPE_CHAR, 1);
         Symbol* temp = new_temp(const_type);
         std::string const_str = std::to_string(static_cast<int>($1));
         emit(OP_ASSIGN, temp->name, const_str);
         $$ = new ExprAttributes();
         $$->place = temp;
         $$->type = const_type;
         std::cout << "Debug: Primary CHAR_CONSTANT " << const_str << std::endl;
      }
    | STRING_LITERAL {
         std::cout << "Debug: Primary STRING_LITERAL (ignored for TAC)" << std::endl;
         delete[] $1;
         $$ = nullptr;
      }
    | '(' expression ')' {
         $$ = $2; /* Propagate, transfer ownership */
         std::cout << "Debug: Primary ( expression )" << std::endl;
      }
    ;

postfix_expression
    : primary_expression { $$ = $1; } /* Propagation */
    | postfix_expression '[' expression ']' { /* Phase 7 */ $$ = nullptr; delete $1; delete $3; }
    | postfix_expression '(' ')'     { /* Phase 6 */ $$ = nullptr; delete $1; }
    | postfix_expression '(' argument_expression_list ')' { /* Phase 6 */ $$ = nullptr; delete $1; delete $3; }
    | postfix_expression ARROW IDENTIFIER { /* Phase ? */ delete[] $3; $$ = nullptr; delete $1; }
    ;

argument_expression_list /* Placeholder */
    : assignment_expression { $$ = $1; }
    | argument_expression_list ',' assignment_expression { delete $1; $$ = $3; }
    ;

unary_expression
    : postfix_expression { $$ = $1; } /* Propagation */
    | unary_operator unary_expression %prec UMINUS
      {
        /* Phase 3: Handle unary operators */
        op_code op = (op_code)$1;
        ExprAttributes* operand_attr = $2;

        if (!operand_attr) {
            yyerror("Invalid operand for unary operator");
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(operand_attr->type, nullptr, op);
            if (!temp_result_base_type) {
                 yyerror("Invalid type for unary operator");
                 delete operand_attr;
                 $$ = nullptr;
            } else {
                 Symbol* operand_place = operand_attr->place;
                 Symbol* result_temp = new_temp(temp_result_base_type);

                 emit(op, result_temp->name, operand_place->name);

                 $$ = new ExprAttributes();
                 $$->place = result_temp;
                 $$->type = result_temp->type;

                 std::cout << "Debug: Unary Op " << opcode_to_string(op) << " -> " << result_temp->name << std::endl;
                 delete operand_attr;
            }
        }
      }
    ;

unary_operator /* Return opcode as int/ival */
    : '+' { $$ = (int)OP_UPLUS; }
    | '-' { $$ = (int)OP_UMINUS; }
    | '!' { $$ = (int)OP_NOT; }
    ;

multiplicative_expression
    : unary_expression { $$ = $1; }
    | multiplicative_expression '*' unary_expression
      { /* Phase 3: Action for * operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '*'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_MULT);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '*'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                TypeInfo* required_type = (temp_result_base_type->base == TYPE_FLOAT) ? temp_result_base_type : left_attr->type;
                Symbol* left_operand = convert_type(left_attr->place, required_type);
                Symbol* right_operand = convert_type(right_attr->place, required_type);
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_MULT) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type);
                emit(OP_MULT, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op *: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    | multiplicative_expression '/' unary_expression
      { /* Phase 3: Action for / operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '/'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_DIV);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '/'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                TypeInfo* required_type = (temp_result_base_type->base == TYPE_FLOAT) ? temp_result_base_type : left_attr->type;
                Symbol* left_operand = convert_type(left_attr->place, required_type);
                Symbol* right_operand = convert_type(right_attr->place, required_type);
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_DIV) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type);
                emit(OP_DIV, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op /: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    | multiplicative_expression '%' unary_expression
      { /* Phase 3: Action for % operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '%'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_MOD);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '%'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                TypeInfo* required_type = (temp_result_base_type->base == TYPE_FLOAT) ? temp_result_base_type : left_attr->type; /* Should be int only for MOD */
                Symbol* left_operand = convert_type(left_attr->place, required_type);
                Symbol* right_operand = convert_type(right_attr->place, required_type);
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_MOD) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type);
                emit(OP_MOD, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op %: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    ;

additive_expression
    : multiplicative_expression { $$ = $1; }
    | additive_expression '+' multiplicative_expression
      { /* Phase 3: Action for + operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '+'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_PLUS);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '+'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                TypeInfo* required_type = (temp_result_base_type->base == TYPE_FLOAT) ? temp_result_base_type : left_attr->type;
                Symbol* left_operand = convert_type(left_attr->place, required_type);
                Symbol* right_operand = convert_type(right_attr->place, required_type);
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_PLUS) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type);
                emit(OP_PLUS, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op +: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    | additive_expression '-' multiplicative_expression
      { /* Phase 3: Action for - operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '-'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_MINUS);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '-'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                TypeInfo* required_type = (temp_result_base_type->base == TYPE_FLOAT) ? temp_result_base_type : left_attr->type;
                Symbol* left_operand = convert_type(left_attr->place, required_type);
                Symbol* right_operand = convert_type(right_attr->place, required_type);
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_MINUS) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type);
                emit(OP_MINUS, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op -: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    ;

/* Skip SHL/SHR */

relational_expression
    : additive_expression { $$ = $1; }
    | relational_expression '<' additive_expression
      { /* Phase 3: Action for < operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '<'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_LT);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '<'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                /* Determine type for comparison (usually highest precision) */
                TypeInfo* compare_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ?
                                          new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4); /* Use A9 float size */
                Symbol* left_operand = convert_type(left_attr->place, compare_type);
                Symbol* right_operand = convert_type(right_attr->place, compare_type);
                delete compare_type; /* Clean up temporary compare_type */
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_LT) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type); /* Result is bool */
                emit(OP_LT, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op <: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    | relational_expression '>' additive_expression
      { /* Phase 3: Action for > operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '>'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_GT);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '>'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                TypeInfo* compare_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ?
                                          new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* left_operand = convert_type(left_attr->place, compare_type);
                Symbol* right_operand = convert_type(right_attr->place, compare_type);
                delete compare_type;
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_GT) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type); /* Bool */
                emit(OP_GT, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op >: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    | relational_expression LE additive_expression
      { /* Phase 3: Action for <= operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '<='");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_LE);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '<='");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                 TypeInfo* compare_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ?
                                          new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* left_operand = convert_type(left_attr->place, compare_type);
                Symbol* right_operand = convert_type(right_attr->place, compare_type);
                delete compare_type;
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_LE) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type); /* Bool */
                emit(OP_LE, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op <=: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    | relational_expression GE additive_expression
      { /* Phase 3: Action for >= operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '>='");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_GE);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '>='");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                 TypeInfo* compare_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ?
                                          new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* left_operand = convert_type(left_attr->place, compare_type);
                Symbol* right_operand = convert_type(right_attr->place, compare_type);
                delete compare_type;
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_GE) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type); /* Bool */
                emit(OP_GE, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op >=: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    ;

equality_expression
    : relational_expression { $$ = $1; }
    | equality_expression EQ relational_expression
      { /* Phase 3: Action for == operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '=='");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_EQ);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '=='");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                 TypeInfo* compare_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ?
                                          new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* left_operand = convert_type(left_attr->place, compare_type);
                Symbol* right_operand = convert_type(right_attr->place, compare_type);
                delete compare_type;
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_EQ) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type); /* Bool */
                emit(OP_EQ, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op ==: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    | equality_expression NE relational_expression
      { /* Phase 3: Action for != operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '!='");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_NE);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '!='");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                 TypeInfo* compare_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ?
                                          new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* left_operand = convert_type(left_attr->place, compare_type);
                Symbol* right_operand = convert_type(right_attr->place, compare_type);
                delete compare_type;
                if (left_operand != left_attr->place || right_operand != right_attr->place) { std::cout << "Debug: Conversion applied for " << opcode_to_string(OP_NE) << std::endl; }
                Symbol* result_temp = new_temp(temp_result_base_type); /* Bool */
                emit(OP_NE, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op !=: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    ;

/* Skip bitwise &, | */

logical_AND_expression /* Phase 3: Simple bool op */
    : equality_expression { $$ = $1; }
    | logical_AND_expression AND equality_expression
      { /* Phase 3: Action for && operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '&&'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
             /* Assuming typecheck handles bool requirement for OP_AND */
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_AND);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '&&'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                /* No conversion needed if typecheck enforces bool */
                Symbol* left_operand = left_attr->place;
                Symbol* right_operand = right_attr->place;
                Symbol* result_temp = new_temp(temp_result_base_type); /* Bool */
                emit(OP_AND, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op &&: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    ;

logical_OR_expression /* Phase 3: Simple bool op */
    : logical_AND_expression { $$ = $1; }
    | logical_OR_expression OR logical_AND_expression
      { /* Phase 3: Action for || operator */
        ExprAttributes* left_attr = $1;
        ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) {
            yyerror("Invalid operand(s) for binary operator '||'");
            delete left_attr; delete right_attr;
            $$ = nullptr;
        } else {
             /* Assuming typecheck handles bool requirement for OP_OR */
            TypeInfo* temp_result_base_type = typecheck(left_attr->type, right_attr->type, OP_OR);
            if (!temp_result_base_type) {
                yyerror("Type mismatch for binary operator '||'");
                delete left_attr; delete right_attr;
                $$ = nullptr;
            } else {
                /* No conversion needed if typecheck enforces bool */
                Symbol* left_operand = left_attr->place;
                Symbol* right_operand = right_attr->place;
                Symbol* result_temp = new_temp(temp_result_base_type); /* Bool */
                emit(OP_OR, result_temp->name, left_operand->name, right_operand->name);
                $$ = new ExprAttributes();
                $$->place = result_temp;
                $$->type = result_temp->type;
                std::cout << "Debug: Binary Op ||: " << left_operand->name << ", " << right_operand->name << " -> " << result_temp->name << std::endl;
                delete left_attr; delete right_attr;
            }
        }
      }
    ;

conditional_expression /* Ternary '?:' - Skip */
    : logical_OR_expression { $$ = $1; }
    ;

assignment_expression
    : conditional_expression { $$ = $1; } /* Propagation */
    | unary_expression '=' assignment_expression
      {
        /* Phase 3: Simple assignment */
        ExprAttributes* lhs_attr = $1;
        ExprAttributes* rhs_attr = $3;

        if (!lhs_attr || !rhs_attr) {
            yyerror("Invalid operand(s) for assignment");
            delete lhs_attr; delete rhs_attr;
            $$ = nullptr;
        } else if (!lhs_attr->place || lhs_attr->place->is_temp) { /* L-value check */
            yyerror("L-value required for assignment target");
            delete lhs_attr; delete rhs_attr;
            $$ = nullptr;
        } else if (!lhs_attr->type) { /* Type check */
             yyerror("Invalid target for assignment (missing type)");
             delete lhs_attr; delete rhs_attr;
             $$ = nullptr;
        } else {
             TypeInfo* assign_check_type = typecheck(lhs_attr->type, rhs_attr->type, OP_ASSIGN);
             if (!assign_check_type) {
                 yyerror("Incompatible types for assignment");
                 delete lhs_attr; delete rhs_attr;
                 $$ = nullptr;
             } else {
                 Symbol* rhs_operand = convert_type(rhs_attr->place, lhs_attr->type);
                 if (rhs_operand != rhs_attr->place) { std::cout << "Debug: Conversion applied for assignment RHS" << std::endl; }
                 emit(OP_ASSIGN, lhs_attr->place->name, rhs_operand->name);

                 $$ = new ExprAttributes();
                 $$->place = lhs_attr->place;
                 $$->type = lhs_attr->type;

                 std::cout << "Debug: Assignment: " << lhs_attr->place->name << " = " << rhs_operand->name << std::endl;
                 delete lhs_attr;
                 delete rhs_attr;
             }
        }
      }
    ;

expression
    : assignment_expression { $$ = $1; } /* Propagation */
    ;

/* 2. Declarations */
declaration
    : type_specifier init_declarator_list_opt ';'
        {
          /* Phase 2: Apply type */
          apply_pending_types($1);
          delete $1; /* Clean base TypeInfo */
          if ($2) { delete $2; } /* Clean last DeclaratorAttributes */
        }
    ;

init_declarator_list_opt
    : /* empty */ { $$ = nullptr; }
    | init_declarator_list { $$ = $1; }
    ;

init_declarator_list
    : init_declarator { $$ = $1; }
    | init_declarator_list ',' init_declarator { delete $1; $$ = $3; }
    ;

init_declarator
    : declarator
        {
          /* Phase 2: Create pending symbol */
          std::string var_name = $1->name;
          Symbol* sym = insert_symbol(var_name, nullptr);
          if (sym == nullptr) { yyerror(("Redeclaration of variable '" + var_name + "'").c_str()); }
          else {
              if ($1->array_dim > 0) { sym->pending_dims.push_back($1->array_dim); }
              pending_type_symbols.push_back(sym);
              std::cout << "Debug: Created pending symbol '" << var_name << "'" << std::endl;
          }
          $$ = $1;
        }
    | declarator '=' initializer
        {
          /* Phase 2/3: Create pending symbol & init TAC */
          std::string var_name = $1->name;
          Symbol* sym = insert_symbol(var_name, nullptr);
          ExprAttributes* init_attr = $3; /* $3 is expr_attr_ptr */

          if (sym == nullptr) {
              yyerror(("Redeclaration of variable '" + var_name + "'").c_str());
              if (init_attr) delete init_attr;
          } else {
              if ($1->array_dim > 0) { sym->pending_dims.push_back($1->array_dim); }
              pending_type_symbols.push_back(sym);
              std::cout << "Debug: Created pending symbol '" << var_name << "' with initializer" << std::endl;

              if (!init_attr) {
                  yyerror(("Invalid initializer expression for '" + var_name + "'").c_str());
              } else {
                  /* Phase 3 Workaround: Emit raw assignment */
                  emit(OP_ASSIGN, sym->name, init_attr->place->name);
                  std::cout << "Debug: Emitted initializer assign (NO TYPE CHECK/CONV): " << sym->name << " = " << init_attr->place->name << std::endl;
                  delete init_attr;
              }
          }
          $$ = $1;
        }
    ;

type_specifier /* Phase 2: Creates TypeInfo */
    : VOID     { $$ = new TypeInfo(TYPE_VOID, 0); }
    | CHAR     { $$ = new TypeInfo(TYPE_CHAR, 1); }
    | INTEGER  { $$ = new TypeInfo(TYPE_INTEGER, 4); }
    | FLOAT    { $$ = new TypeInfo(TYPE_FLOAT, 8); } /* A9 spec */
    | BOOL     { $$ = new TypeInfo(TYPE_BOOL, 1); }
    ;

declarator /* Phase 2: Passes up DeclaratorAttributes */
    : direct_declarator { $$ = $1; }
    ;

direct_declarator /* Phase 2: Creates DeclaratorAttributes */
    : IDENTIFIER { $$ = new DeclaratorAttributes(); $$->name = std::string($1); delete[] $1; }
    | '(' declarator ')' { $$ = $2; }
    | direct_declarator '[' INT_CONSTANT ']'
        {
          $$ = $1;
          if ($$->array_dim > 0) { yyerror("Multidimensional arrays not supported"); }
          if ($3 <= 0) { yyerror("Array dimension must be positive"); $$->array_dim = 0; }
          else { $$->array_dim = $3; }
        }
    | direct_declarator '[' ']' { $$ = $1; yyerror("Array dimension must be specified"); }
    | direct_declarator '(' parameter_list ')'
      {
          /* Phase 6 placeholder, Phase 3 needs name */
          /* $1 contains attributes including the name from the nested direct_declarator */
          /* Parameters $3 not used yet */
          $$ = $1; /* Propagate the attributes containing the name */
          /* Add parameter processing in Phase 6 */
      }
    | direct_declarator '(' identifier_list_opt ')'
      {
          /* Phase 6 placeholder, Phase 3 needs name */
          /* $1 contains attributes including the name */
          /* Parameters $3 not used yet */
          $$ = $1; /* Propagate the attributes containing the name */
          /* Add parameter processing in Phase 6 */
      }
    ;

/* Parameters deferred */
parameter_list : parameter_declaration { /* delete $1; Phase 6 */ } | parameter_list ',' parameter_declaration { /* delete $1; delete $3; Phase 6 */ } ;
parameter_declaration : type_specifier declarator { delete $1; delete $2; /* Phase 6 */ } ;
identifier_list_opt : /* empty */ | identifier_list ;
identifier_list : IDENTIFIER { delete[] $1; } | identifier_list ',' IDENTIFIER { delete[] $3; } ;

initializer /* Phase 3: Handles expression */
    : assignment_expression { $$ = $1; }
    ;

/* 3. Statements */
statement
    : compound_statement
    | expression_statement
    | selection_statement
    | iteration_statement
    | jump_statement
    ;

compound_statement /* Phase 2: Scope handling */
    : BEGIN_TOKEN { begin_scope(); std::cout << "Debug: Entered scope" << std::endl;}
      block_item_list_opt
      END_TOKEN { std::cout << "Debug: Exiting scope" << std::endl; end_scope(); }
    ;

block_item_list_opt : /* empty */ | block_item_list ;
block_item_list : block_item | block_item_list block_item ;
block_item : declaration | statement ;

expression_statement
    : ';' { std::cout << "Debug: Empty statement" << std::endl; }
    | expression ';' { /* Phase 3: Cleanup attributes */ std::cout << "Debug: Expression statement" << std::endl; if ($1) { delete $1; } }
    ;

selection_statement /* Phase 4: Backpatching */
    : IF '(' expression ')' statement %prec IFX { if($3) delete $3; /* Phase 4 */ }
    | IF '(' expression ')' statement ELSE statement { if($3) delete $3; /* Phase 4 */ }
    ;

iteration_statement /* Phase 5: Backpatching */
    : FOR '(' expression_opt ';' expression_opt ';' expression_opt ')' statement
      { /* Clean up expression results */ if($3) delete $3; if($5) delete $5; if($7) delete $7; /* Phase 5 */ }
    ;

expression_opt /* Now has type expr_attr_ptr */
    : /* empty */ { $$ = nullptr; } /* Return null pointer */
    | expression  { $$ = $1; }      /* Propagate */
    ;

jump_statement /* Phase 6: Return TAC */
    : RETURN ';' { /* Phase 6 */ }
    | RETURN expression ';' { if($2) delete $2; /* Phase 6 */ }
    ;

/* 4. External Definitions */
translation_unit : external_declaration | translation_unit external_declaration ;
external_declaration : function_definition | declaration ;

function_definition /* Phase 2: Basic handling */
    : type_specifier declarator
        { /* Action before compound statement */
            std::string func_name = $2->name;
            TypeInfo* func_type = new TypeInfo(TYPE_FUNCTION);
            func_type->return_type = $1; /* $1 is TypeInfo* */
            Symbol* func_sym = insert_symbol(func_name, func_type);
            if (func_sym == nullptr) { yyerror(("Redeclaration of function '" + func_name + "'").c_str()); }
            else { std::cout << "Debug: Inserted function symbol '" << func_name << "'" << std::endl; }
            current_function = func_sym;
            delete $2; /* Cleanup declarator attributes */
        }
      compound_statement /* Enters/exits function body scope */
        { /* Action after compound statement */
            if (current_function && current_function->nested_table == nullptr) { /* Link scope? */ }
            current_function = nullptr;
        }
    ;

%%

/* External variable from lexer */
FILE* lex_output = nullptr;

/* Error Handling */
void yyerror(const char* s) {
    std::cerr << "Syntax Error: " << s << " near '" << (yytext ? yytext : "EOF")
              << "' at line " << line_no << std::endl;
    exit(EXIT_FAILURE);
}

/* Main Function (from Phase 2) */
int main(int argc, char** argv) {
    if (argc < 2) { std::cerr << "Usage: " << argv[0] << " <input_file>" << std::endl; return 1; }
    yyin = fopen(argv[1], "r");
    if (!yyin) { std::cerr << "Error: Cannot open input file: " << argv[1] << std::endl; return 1; }

    /* Lexer Output File Handling */
    char lex_filename[FILENAME_MAX];
    strncpy(lex_filename, argv[1], FILENAME_MAX - 10); lex_filename[FILENAME_MAX - 10] = '\0';
    strcat(lex_filename, ".lex.out");
    lex_output = fopen(lex_filename, "w");
    if (!lex_output) { std::cerr << "Warning: Cannot create lexer output file: " << lex_filename << std::endl; }
    else { std::cout << "Lexical analysis output will be written to " << lex_filename << std::endl; fprintf(lex_output, "LEXICAL ANALYSIS FOR FILE: %s\n---\n", argv[1]); }

    /* Initialization & Parsing */
    initialize_symbol_tables();
    std::cout << "Starting parse for file: " << argv[1] << std::endl;
    int parse_result = yyparse();
    fclose(yyin);

    /* Post-Parsing Output */
    if (parse_result == 0) {
        std::cout << "Parsing completed successfully." << std::endl;
        print_symbol_table(global_symbol_table);
        print_quads(); /* Phase 3: Should now contain expression quads */
    } else { std::cerr << "Parsing failed." << std::endl; }

    /* Cleanup */
    cleanup_translator();
    if (lex_output != nullptr) { fprintf(lex_output, "\n---\nEND OF LEXICAL ANALYSIS\n"); fclose(lex_output); }

    return parse_result;
}
