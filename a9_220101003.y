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
#include <utility> /* For std::swap */

/* External declarations */
extern int yylex();
extern FILE* yyin;
extern int line_no;
extern char* yytext;
extern FILE* lex_output; /* Keep for logging */

/* Function Prototypes */
void yyerror(const char* s);

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

    /* Structure for expression attributes (Phase 4 Update) */
    struct ExprAttributes {
        Symbol* place = nullptr;
        TypeInfo* type = nullptr;
        BackpatchList* truelist = nullptr; // --- Phase 4 ---
        BackpatchList* falselist = nullptr;// --- Phase 4 ---
        std::vector<std::string>* param_names = nullptr; 
        bool is_deref_lvalue = false;    // Still useful to know if it *originated* from a deref
        Symbol* pointer_sym_for_lvalue = nullptr; // <<< ADD: Stores the original pointer symbol (e.g., 'p' in *p)

        ExprAttributes() {}
        ~ExprAttributes() {
            // Cleanup handled explicitly in parser rules where ownership ends
            // delete truelist; // NO!
            // delete falselist; // NO!
         }
    };

    /* Structure for Statement Attributes (Phase 4) */
    struct StmtAttributes {
        BackpatchList* nextlist = nullptr;
        StmtAttributes() {}
        ~StmtAttributes() {
             // Cleanup handled explicitly in parser rules
             // delete nextlist; // NO!
        }
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
    StmtAttributes* stmt_attr_ptr;       /* Phase 4 */
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

/* --- Phase 4: %type for markers and statements --- */
%type <list_ptr> M N // Markers return BackpatchList*
%type <stmt_attr_ptr> statement compound_statement selection_statement iteration_statement
%type <stmt_attr_ptr> expression_statement jump_statement block_item block_item_list
%type <stmt_attr_ptr> block_item_list_opt function_definition
/* --- End Phase 4 --- */

%type <type_ptr> pointer /* <<< Add type for pointer chain */

/* Operator Precedence and Associativity */
%right '='
%left OR
%left AND
%nonassoc '<' '>' LE GE EQ NE /* Boolean comparison */
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

/* Grammar Rules (Phase 4 - Complete) */

/* --- Phase 4: Marker Non-terminals --- */
M   : /* empty */
        { $$ = new BackpatchList(makelist(get_next_quad_index()));
          std::cout << "Debug: Marker M created list pointing to next quad " << get_next_quad_index() << std::endl; }
    ;
N   : /* empty */
        {
            $$ = new BackpatchList(makelist(get_next_quad_index()));
            emit(OP_GOTO, ""); // Emit GOTO with empty target
            std::cout << "Debug: Marker N created list pointing to GOTO at quad " << get_next_quad_index()-1 << std::endl;
        }
    ;
/* --- End Phase 4 --- */

/* --- Add pointer rule --- */
pointer /* Builds a chain of TypeInfo for pointers, returns the head */
    : '*'
        {
            $$ = new TypeInfo(TYPE_POINTER, 8); // Assuming 8-byte pointers
            $$->ptr_type = nullptr; // Base type (pointed-to type) filled in later
            std::cout << "Debug: Pointer level 1" << std::endl;
        }
    | '*' pointer
        {
            $$ = new TypeInfo(TYPE_POINTER, 8);
            $$->ptr_type = $2; // Link to the next pointer level or base type placeholder
            std::cout << "Debug: Pointer level > 1" << std::endl;
        }
    ;

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

/* --- Function Call Processing --- */
postfix_expression
    : primary_expression { $$ = $1; }
    | postfix_expression '[' expression ']' { /* Phase 7 */ $$ = nullptr; delete $1; delete $3; }
    | postfix_expression '(' ')'
        {
            // Function call with no arguments
            if (!$1) {
                yyerror("Invalid function call");
                $$ = nullptr;
            } else if (!$1->place) {
                yyerror("Function identifier expected");
                delete $1;
                $$ = nullptr;
            } else {
                Symbol* func_sym = $1->place;
                
                // Check if it's a function
                if (!func_sym->type || func_sym->type->base != TYPE_FUNCTION) {
                    yyerror(("Called object '" + func_sym->name + "' is not a function").c_str());
                    delete $1;
                    $$ = nullptr;
                } else {
                    // Create result for the function call
                    $$ = new ExprAttributes();
                    
                    // Get return type
                    TypeInfo* return_type = func_sym->type->return_type;
                    
                    if (return_type && return_type->base != TYPE_VOID) {
                        // Non-void function: create temporary for return value
                        $$->place = new_temp(return_type);
                        $$->type = return_type;
                        emit(OP_CALL, $$->place->name, func_sym->name, "0"); // 0 parameters
                    } else {
                        // Void function: no return value
                        $$->place = nullptr;
                        $$->type = new TypeInfo(TYPE_VOID, 0);
                        emit(OP_CALL, "", func_sym->name, "0"); // 0 parameters
                    }
                    
                    std::cout << "Debug: Generated call to function '" << func_sym->name 
                             << "' with 0 parameters" << std::endl;
                    
                    delete $1;
                }
            }
        }
    | postfix_expression '(' argument_expression_list ')'
        {
            // Function call with arguments
            if (!$1 || !$3) {
                yyerror("Invalid function call");
                delete $1;
                delete $3;
                $$ = nullptr;
            } else {
                Symbol* func_sym = $1->place;
                
                // Check if it's a function (existing validation code)
                if (!func_sym->type || func_sym->type->base != TYPE_FUNCTION) {
                    yyerror(("Called object '" + func_sym->name + "' is not a function").c_str());
                    delete $1;
                    delete $3;
                    $$ = nullptr;
                } else {
                    // Create result for the function call
                    $$ = new ExprAttributes();
                    TypeInfo* return_type = func_sym->type->return_type;
                    
                    // Get parameter count
                    int param_count = std::stoi($3->place->name);
                    
                    // Emit parameters in reverse order (C calling convention)
                    if ($3->param_names) {
                        for (auto it = $3->param_names->begin(); it != $3->param_names->end(); ++it) {
                            emit(OP_PARAM, *it);
                        }
                    }
                    
                    // Emit function call (existing code)
                    if (return_type && return_type->base != TYPE_VOID) {
                        $$->place = new_temp(return_type);
                        $$->type = return_type;
                        emit(OP_CALL, $$->place->name, func_sym->name, std::to_string(param_count));
                    } else {
                        $$->place = nullptr;
                        $$->type = new TypeInfo(TYPE_VOID, 0);
                        emit(OP_CALL, "", func_sym->name, std::to_string(param_count));
                    }
                    
                    std::cout << "Debug: Generated call to function '" << func_sym->name 
                            << "' with " << param_count << " parameters in reverse order" << std::endl;
                    
                    delete $1;
                    delete $3;
                }
            }
        }
    | postfix_expression ARROW IDENTIFIER { /* Phase ? */ delete[] $3; $$ = nullptr; delete $1; }
    ;

/* Revised for parameter passing */
argument_expression_list
    : assignment_expression
        {
            // First argument
            if (!$1) {
                yyerror("Invalid function argument");
                $$ = nullptr;
            } else {
                // Create expressions attribute and vector for parameter names
                $$ = new ExprAttributes();
                $$->param_names = new std::vector<std::string>();
                
                // Add first parameter to the vector
                $$->param_names->push_back($1->place->name);

                // Emit parameter quad
                // emit(OP_PARAM, $1->place->name);
                
                // Count parameters (1 so far)
                // $$ = new ExprAttributes();
                // We'll use the place field to store parameter count (as string)
                Symbol* count_sym = new Symbol("1");
                count_sym->initial_value = $1->place->name; // Store first param name
                $$->place = count_sym;
                $$->type = $1->type; // Keep track of last arg type (might be useful)
                
                std::cout << "Debug: Added first parameter to call" << std::endl;
                
                delete $1; // Clean up original expression
            }
        }
    | argument_expression_list ',' assignment_expression
        {
            // Additional argument
            if (!$1 || !$3) {
                yyerror("Invalid function argument");
                delete $1;
                delete $3;
                $$ = nullptr;
            } else {
                // Emit parameter quad for the new argument
                // emit(OP_PARAM, $3->place->name);

                $1->param_names->push_back($3->place->name);

                // Increment parameter count
                int current_count = std::stoi($1->place->name);
                current_count++;
                $1->place->name = std::to_string(current_count);

                // Update return value
                $$ = $1; // Reuse attributes from argument_expression_list
                // $$->place->name = std::to_string(current_count); // Update count
                
                std::cout << "Debug: Added parameter #" << current_count << " to call" << std::endl;
                
                delete $3; // Clean up the new expression
            }
        }
    ;

unary_expression
    : postfix_expression { $$ = $1; } /* Propagation */
    | '&' unary_expression %prec '&' /* Address-of */
      {
        ExprAttributes* operand_attr = $2;
        if (!operand_attr) { yyerror("Invalid operand for address-of operator '&'"); $$ = nullptr; }
        else if (!operand_attr->place || operand_attr->place->is_temp) { // Basic L-value check
            yyerror("L-value required for address-of operator '&'");
            delete operand_attr; $$ = nullptr;
        } else {
            // Create pointer type: pointer to operand's type
            TypeInfo* ptr_type = new TypeInfo(TYPE_POINTER, 8);
            ptr_type->ptr_type = new TypeInfo(*(operand_attr->type)); // Copy operand's type
            Symbol* result_temp = new_temp(ptr_type); // Temp to hold the address
            emit(OP_ADDR, result_temp->name, operand_attr->place->name); // result = &operand
            $$ = new ExprAttributes();
            $$->place = result_temp; // Place holds the address temp
            $$->type = ptr_type;     // Type is pointer
            $$->is_deref_lvalue = false;
            $$->pointer_sym_for_lvalue = nullptr; // Not applicable
            std::cout << "Debug: Unary Op & -> " << result_temp->name << std::endl;
            delete operand_attr;
        }
      }
    | '*' unary_expression %prec '*' /* Dereference */
      {
         ExprAttributes* operand_attr = $2; // Attributes of the pointer expression (e.g., 'p')
         if (!operand_attr || !operand_attr->type || operand_attr->type->base != TYPE_POINTER || !operand_attr->type->ptr_type || !operand_attr->place) {
             yyerror("Cannot dereference non-pointer or invalid type");
             delete operand_attr; $$ = nullptr;
         } else {
             // Type of the result is the type being pointed to
             TypeInfo* pointed_to_type = new TypeInfo(*(operand_attr->type->ptr_type)); // Create a copy
             // Create a temporary to hold the result of the dereference
             Symbol* result_temp = new_temp(pointed_to_type);

             // Emit the dereference TAC immediately: temp = *pointer
             emit(OP_ASSIGN_DEREF, result_temp->name, operand_attr->place->name);

             $$ = new ExprAttributes();
             $$->place = result_temp; // Place now holds the temporary containing the value
             $$->type = pointed_to_type; // Type is the pointed-to type
             $$->is_deref_lvalue = true; // Mark that this originated from a dereference
             $$->pointer_sym_for_lvalue = operand_attr->place; // Store the original pointer symbol ('p')

             std::cout << "Debug: Unary Op * emitted: " << result_temp->name << " = *"
                       << operand_attr->place->name << ". Storing pointer '"
                       << $$->pointer_sym_for_lvalue->name << "' for potential L-value use." << std::endl;

             // Don't delete operand_attr->place as it's stored in pointer_sym_for_lvalue
             // Delete the rest of the operand attributes
             delete operand_attr->type; // Delete the pointer TypeInfo
             // delete operand_attr->truelist; // Handle lists if applicable
             // delete operand_attr->falselist;
             delete operand_attr; // Delete the container struct
         }
      }
    | unary_operator unary_expression %prec UMINUS
      {
        op_code op = (op_code)$1;
        ExprAttributes* operand_attr = $2;
        if (!operand_attr) { yyerror("Invalid operand for unary operator"); $$ = nullptr; }
        else {
            // --- Phase 4: Handle '!' ---
            if (op == OP_NOT) {
                if (!operand_attr->type || operand_attr->type->base != TYPE_BOOL) {
                    yyerror("Operand for '!' must be boolean"); delete operand_attr; $$ = nullptr;
                } else {
                    // Swap true and false lists
                    $$ = operand_attr; // Take ownership
                    std::swap($$->truelist, $$->falselist);
                    std::cout << "Debug: Logical NOT applied by swapping lists" << std::endl;
                }
            } else { // Handle arithmetic unary ops (+, -) as in Phase 3
                TypeInfo* temp_result_base_type = typecheck(operand_attr->type, nullptr, op);
                if (!temp_result_base_type) { yyerror("Invalid type for unary operator"); delete operand_attr; $$ = nullptr; }
                else {
                     Symbol* operand_place = operand_attr->place;
                     Symbol* result_temp = new_temp(temp_result_base_type);
                     emit(op, result_temp->name, operand_place->name);
                     $$ = new ExprAttributes(); $$->place = result_temp; $$->type = result_temp->type; /* No lists */
                     std::cout << "Debug: Unary Op " << opcode_to_string(op) << " -> " << result_temp->name << std::endl;
                     delete operand_attr;
                }
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
    : additive_expression { $$ = $1; } /* Only propagate if non-boolean */
    | relational_expression '<' additive_expression { /* Phase 4: Action for < */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) { yyerror("Invalid op for '<'"); delete left_attr; delete right_attr; $$ = nullptr; }
        else { TypeInfo* bool_type = typecheck(left_attr->type, right_attr->type, OP_IF_LT); /* Check compatibility */
            if (!bool_type) { yyerror("Type mismatch for '<'"); delete left_attr; delete right_attr; $$ = nullptr; }
            else { delete bool_type; /* Only needed for check */
                TypeInfo* cmp_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ? new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* lop = convert_type(left_attr->place, cmp_type); Symbol* rop = convert_type(right_attr->place, cmp_type); delete cmp_type;
                $$ = new ExprAttributes(); $$->type = new TypeInfo(TYPE_BOOL, 1);
                $$->truelist = new BackpatchList(makelist(get_next_quad_index()));
                $$->falselist = new BackpatchList(makelist(get_next_quad_index() + 1));
                emit(OP_IF_LT, "", lop->name, rop->name);
                emit(OP_GOTO, "");
                std::cout << "Debug: Relational Op < generated jumps" << std::endl;
                delete left_attr; delete right_attr; } }
      }
    | relational_expression '>' additive_expression { /* Phase 4: Action for > */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) { yyerror("Invalid op for '>'"); delete left_attr; delete right_attr; $$ = nullptr; }
        else { TypeInfo* bool_type = typecheck(left_attr->type, right_attr->type, OP_IF_GT);
            if (!bool_type) { yyerror("Type mismatch for '>'"); delete left_attr; delete right_attr; $$ = nullptr; }
            else { delete bool_type;
                TypeInfo* cmp_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ? new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* lop = convert_type(left_attr->place, cmp_type); Symbol* rop = convert_type(right_attr->place, cmp_type); delete cmp_type;
                $$ = new ExprAttributes(); $$->type = new TypeInfo(TYPE_BOOL, 1);
                $$->truelist = new BackpatchList(makelist(get_next_quad_index())); $$->falselist = new BackpatchList(makelist(get_next_quad_index() + 1));
                emit(OP_IF_GT, "", lop->name, rop->name); emit(OP_GOTO, "");
                std::cout << "Debug: Relational Op > generated jumps" << std::endl;
                delete left_attr; delete right_attr; } }
      }
    | relational_expression LE additive_expression { /* Phase 4: Action for <= */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) { yyerror("Invalid op for '<='"); delete left_attr; delete right_attr; $$ = nullptr; }
        else { TypeInfo* bool_type = typecheck(left_attr->type, right_attr->type, OP_IF_LE);
            if (!bool_type) { yyerror("Type mismatch for '<='"); delete left_attr; delete right_attr; $$ = nullptr; }
            else { delete bool_type;
                TypeInfo* cmp_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ? new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* lop = convert_type(left_attr->place, cmp_type); Symbol* rop = convert_type(right_attr->place, cmp_type); delete cmp_type;
                $$ = new ExprAttributes(); $$->type = new TypeInfo(TYPE_BOOL, 1);
                $$->truelist = new BackpatchList(makelist(get_next_quad_index())); $$->falselist = new BackpatchList(makelist(get_next_quad_index() + 1));
                emit(OP_IF_LE, "", lop->name, rop->name); emit(OP_GOTO, "");
                std::cout << "Debug: Relational Op <= generated jumps" << std::endl;
                delete left_attr; delete right_attr; } }
      }
    | relational_expression GE additive_expression { /* Phase 4: Action for >= */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) { 
            yyerror("Invalid op for '>='"); 
            delete left_attr; delete right_attr; 
            $$ = nullptr; 
        }else { 
            TypeInfo* bool_type = typecheck(left_attr->type, right_attr->type, OP_IF_GE);
            if (!bool_type) { 
                yyerror("Type mismatch for '>='"); 
                delete left_attr; delete right_attr; 
                $$ = nullptr; 
            }else { 
                delete bool_type;
                TypeInfo* cmp_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ? new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* lop = convert_type(left_attr->place, cmp_type); Symbol* rop = convert_type(right_attr->place, cmp_type); delete cmp_type;
                $$ = new ExprAttributes(); $$->type = new TypeInfo(TYPE_BOOL, 1);
                $$->truelist = new BackpatchList(makelist(get_next_quad_index())); $$->falselist = new BackpatchList(makelist(get_next_quad_index() + 1));
                emit(OP_IF_GE, "", lop->name, rop->name); emit(OP_GOTO, "");
                std::cout << "Debug: Relational Op >= generated jumps" << std::endl;
                delete left_attr; delete right_attr; 
            } 
        }
      }
    ;

equality_expression
    : relational_expression { $$ = $1; } /* Propagation */
    | equality_expression EQ relational_expression { /* Phase 4: Action for == */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) { yyerror("Invalid op for '=='"); delete left_attr; delete right_attr; $$ = nullptr; }
        else { TypeInfo* bool_type = typecheck(left_attr->type, right_attr->type, OP_IF_EQ);
            if (!bool_type) { yyerror("Type mismatch for '=='"); delete left_attr; delete right_attr; $$ = nullptr; }
            else { delete bool_type;
                TypeInfo* cmp_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ? new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* lop = convert_type(left_attr->place, cmp_type); Symbol* rop = convert_type(right_attr->place, cmp_type); delete cmp_type;
                $$ = new ExprAttributes(); $$->type = new TypeInfo(TYPE_BOOL, 1);
                $$->truelist = new BackpatchList(makelist(get_next_quad_index())); $$->falselist = new BackpatchList(makelist(get_next_quad_index() + 1));
                emit(OP_IF_EQ, "", lop->name, rop->name); emit(OP_GOTO, "");
                std::cout << "Debug: Equality Op == generated jumps" << std::endl;
                delete left_attr; delete right_attr; } }
      }
    | equality_expression NE relational_expression { /* Phase 4: Action for != */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $3;
        if (!left_attr || !right_attr) { yyerror("Invalid op for '!='"); delete left_attr; delete right_attr; $$ = nullptr; }
        else { TypeInfo* bool_type = typecheck(left_attr->type, right_attr->type, OP_IF_NE);
            if (!bool_type) { yyerror("Type mismatch for '!='"); delete left_attr; delete right_attr; $$ = nullptr; }
            else { delete bool_type;
                TypeInfo* cmp_type = (left_attr->type->base == TYPE_FLOAT || right_attr->type->base == TYPE_FLOAT) ? new TypeInfo(TYPE_FLOAT, 8) : new TypeInfo(TYPE_INTEGER, 4);
                Symbol* lop = convert_type(left_attr->place, cmp_type); Symbol* rop = convert_type(right_attr->place, cmp_type); delete cmp_type;
                $$ = new ExprAttributes(); $$->type = new TypeInfo(TYPE_BOOL, 1);
                $$->truelist = new BackpatchList(makelist(get_next_quad_index())); $$->falselist = new BackpatchList(makelist(get_next_quad_index() + 1));
                emit(OP_IF_NE, "", lop->name, rop->name); emit(OP_GOTO, "");
                std::cout << "Debug: Equality Op != generated jumps" << std::endl;
                delete left_attr; delete right_attr; } }
      }
    ;

/* Skip bitwise &, | */

logical_AND_expression
    : equality_expression { $$ = $1; } /* Propagation */
    | logical_AND_expression M AND equality_expression { /* Phase 4: Action for && */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $4; BackpatchList* marker_list = $2;
        if (!left_attr || !right_attr) { yyerror("Invalid op for '&&'"); delete left_attr; delete right_attr; delete marker_list; $$ = nullptr; }
        else if (!left_attr->type || left_attr->type->base != TYPE_BOOL || !right_attr->type || right_attr->type->base != TYPE_BOOL) {
             yyerror("Operands for '&&' must be boolean"); delete left_attr; delete right_attr; delete marker_list; $$ = nullptr; }
        else {
             backpatch(*left_attr->truelist, marker_list->front()); // Backpatch left's TRUE to start of right expr
             $$ = new ExprAttributes(); $$->type = left_attr->type; // Result is boolean
             $$->truelist = right_attr->truelist; right_attr->truelist = nullptr; // Transfer ownership of right's truelist
             $$->falselist = new BackpatchList(mergelist(*left_attr->falselist, *right_attr->falselist)); // Merge falselists
             std::cout << "Debug: Logical AND processed" << std::endl;
             // Cleanup owned resources
             delete left_attr->truelist; delete left_attr->falselist; delete left_attr;
             delete right_attr->falselist; delete right_attr; // right's truelist was transferred
             delete marker_list;
        }
      }
    ;

logical_OR_expression
    : logical_AND_expression { $$ = $1; } /* Propagation */
    | logical_OR_expression M OR logical_AND_expression { /* Phase 4: Action for || */
        ExprAttributes* left_attr = $1; ExprAttributes* right_attr = $4; BackpatchList* marker_list = $2;
        if (!left_attr || !right_attr) { yyerror("Invalid op for '||'"); delete left_attr; delete right_attr; delete marker_list; $$ = nullptr; }
        else if (!left_attr->type || left_attr->type->base != TYPE_BOOL || !right_attr->type || right_attr->type->base != TYPE_BOOL) {
             yyerror("Operands for '||' must be boolean"); delete left_attr; delete right_attr; delete marker_list; $$ = nullptr; }
        else {
             backpatch(*left_attr->falselist, marker_list->front()); // Backpatch left's FALSE to start of right expr
             $$ = new ExprAttributes(); $$->type = left_attr->type; // Result is boolean
             $$->truelist = new BackpatchList(mergelist(*left_attr->truelist, *right_attr->truelist)); // Merge truelists
             $$->falselist = right_attr->falselist; right_attr->falselist = nullptr; // Transfer ownership of right's falselist
             std::cout << "Debug: Logical OR processed" << std::endl;
             // Cleanup owned resources
             delete left_attr->truelist; delete left_attr->falselist; delete left_attr;
             delete right_attr->truelist; delete right_attr; // right's falselist was transferred
             delete marker_list;
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
        } 
        else if (lhs_attr->is_deref_lvalue) {
            // Case: *p = rhs
            if (!lhs_attr->pointer_sym_for_lvalue) { // Sanity check
                yyerror("Internal error: L-value dereference missing pointer symbol");
                delete lhs_attr; delete rhs_attr; $$ = nullptr;
            } else if (!rhs_attr->type || !rhs_attr->place) {
                 yyerror("Invalid RHS for assignment to pointer dereference");
                 delete lhs_attr; delete rhs_attr; $$ = nullptr;
            } else {
                TypeInfo* target_type = lhs_attr->type; // This is the type *p points to (held in the temp's type)
                // Type check: Can RHS be assigned to the type pointed to by LHS?
                TypeInfo* assign_check_type = typecheck(target_type, rhs_attr->type, OP_ASSIGN);
                if (!assign_check_type) {
                    yyerror(("Incompatible types for assignment to pointer dereference: cannot assign " + rhs_attr->type->toString() + " to " + target_type->toString()).c_str());
                    delete lhs_attr; delete rhs_attr; $$ = nullptr;
                } else {
                    delete assign_check_type; // Only needed for check
                    Symbol* rhs_operand = convert_type(rhs_attr->place, target_type); // Convert RHS if necessary
                    // Emit TAC: *ptr = value (using OP_DEREF_ASSIGN: *result = arg1)
                    // Use the original pointer symbol stored earlier
                    emit(OP_DEREF_ASSIGN, lhs_attr->pointer_sym_for_lvalue->name, rhs_operand->name);

                    // Result of assignment expression is the assigned value (RHS)
                    $$ = new ExprAttributes();
                    $$->place = rhs_operand; // Use the (potentially converted) RHS symbol
                    $$->type = new TypeInfo(*rhs_attr->type); // Copy RHS type
                    $$->is_deref_lvalue = false; // Result is not an l-value deref
                    $$->pointer_sym_for_lvalue = nullptr;

                    std::cout << "Debug: Assignment *p = ... : *" << lhs_attr->pointer_sym_for_lvalue->name << " = " << rhs_operand->name << std::endl;
                    delete lhs_attr; // Includes deleting target_type copy
                    delete rhs_attr;
                }
            }
        }
        // --- End L-value Dereference Handling ---
        else { // Normal assignment (variable = ...)
            // Check if LHS is a valid L-value
            if (!lhs_attr->place || lhs_attr->place->is_temp) {
                yyerror("L-value required for assignment target");
                delete lhs_attr; delete rhs_attr;
                $$ = nullptr;
            } else if (!lhs_attr->type || !rhs_attr->type || !rhs_attr->place || !rhs_attr->place) {
                 yyerror("Invalid types or value for assignment");
                 delete lhs_attr; delete rhs_attr;
                 $$ = nullptr;
            } else {
                 // RHS Handling: No special check needed for rhs_attr->is_deref_lvalue.
                 // If RHS was *p, the unary rule already put the value in rhs_attr->place (a temp).
                 Symbol* rhs_place_to_use = rhs_attr->place;

                 TypeInfo* assign_check_type = typecheck(lhs_attr->type, rhs_attr->type, OP_ASSIGN);
                 if (!assign_check_type) {
                     yyerror(("Incompatible types for assignment: cannot assign " + rhs_attr->type->toString() + " to " + lhs_attr->type->toString()).c_str());
                     delete lhs_attr; delete rhs_attr;
                     $$ = nullptr;
                 } else {
                     delete assign_check_type; // Only needed for check
                     Symbol* rhs_operand = convert_type(rhs_place_to_use, lhs_attr->type);
                     if (rhs_operand != rhs_place_to_use) { std::cout << "Debug: Conversion applied for assignment RHS" << std::endl; }
                     emit(OP_ASSIGN, lhs_attr->place->name, rhs_operand->name);

                     // Result of assignment is the assigned value (RHS)
                     $$ = new ExprAttributes();
                     $$->place = rhs_operand; // Use the (potentially converted) RHS symbol
                     $$->type = new TypeInfo(*rhs_attr->type); // Copy RHS type
                     $$->is_deref_lvalue = false;
                     $$->pointer_sym_for_lvalue = nullptr;

                     std::cout << "Debug: Assignment: " << lhs_attr->place->name << " = " << rhs_operand->name << std::endl;
                     delete lhs_attr;
                     delete rhs_attr;
                 }
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
    : declarator // $1 is decl_attr_ptr
        {
          /* Phase 2: Create pending symbol (MODIFIED) */
          std::string var_name = $1->name;
          Symbol* sym = insert_symbol(var_name, nullptr); // Insert symbol first
          if (sym == nullptr) { yyerror(("Redeclaration of variable '" + var_name + "'").c_str()); }
          else {
              // Store declarator attributes (pointer type chain, array dims) with symbol
              // The base type will be applied later by apply_pending_types
              sym->type = $1->type; // <<< Store pointer chain (or null)
              $1->type = nullptr;   // <<< Transfer ownership to symbol
              if ($1->array_dim > 0) { sym->pending_dims.push_back($1->array_dim); }
              pending_type_symbols.push_back(sym);
              std::cout << "Debug: Created pending symbol '" << var_name << "'" << std::endl;
          }
          $$ = $1; // Propagate declarator attributes (contains name, original pointer chain ref is now null)
        }
    | declarator '=' initializer // $1 is decl_attr_ptr, $3 is expr_attr_ptr
        {
          /* Phase 2/3: Create pending symbol & init TAC (MODIFIED) */
          std::string var_name = $1->name;
          Symbol* sym = insert_symbol(var_name, nullptr);
          ExprAttributes* init_attr = $3;

          if (sym == nullptr) {
              yyerror(("Redeclaration of variable '" + var_name + "'").c_str());
              if (init_attr) delete init_attr;
              // delete $1->type; // Clean up pointer chain if declarator owned it - NO, transferred below
          } else {
              // Store declarator attributes with symbol
              sym->type = $1->type; // <<< Store pointer chain (or null)
              $1->type = nullptr;   // <<< Transfer ownership to symbol
              if ($1->array_dim > 0) { sym->pending_dims.push_back($1->array_dim); }
              pending_type_symbols.push_back(sym);
              std::cout << "Debug: Created pending symbol '" << var_name << "' with initializer" << std::endl;

              if (!init_attr) {
                  yyerror(("Invalid initializer expression for '" + var_name + "'").c_str());
              } else {
                  // Emit raw assignment - type check/conversion happens later in apply_pending_types
                  if (init_attr->place) {
                      emit(OP_ASSIGN, sym->name, init_attr->place->name);
                      std::cout << "Debug: Emitted initializer assign (NO TYPE CHECK/CONV): " << sym->name << " = " << init_attr->place->name << std::endl;
                  } else {
                       yyerror(("Invalid initializer value for '" + var_name + "'").c_str());
                  }
                  delete init_attr;
              }
          }
          // Propagate declarator attributes (name). Pointer chain was transferred.
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

declarator /* Phase 2: Passes up DeclaratorAttributes (MODIFIED) */
    : pointer direct_declarator
        {
            $$ = $2; // Get name etc. from direct_declarator
            // Store the pointer type chain built by 'pointer' rule
            // It will be combined with the base type later by apply_pending_types
            $$->type = $1; // $1 is TypeInfo* chain from pointer rule
            std::cout << "Debug: Declarator with pointer chain for '" << $$->name << "'" << std::endl;
        }
    | direct_declarator
        {
            $$ = $1;
            $$->type = nullptr; // Indicate no pointer part
            std::cout << "Debug: Declarator without pointer chain for '" << $$->name << "'" << std::endl;
        }
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
/* --- Parameter List Processing --- */
parameter_list
    : parameter_declaration
        {
            // First parameter - nothing to propagate up
        }
    | parameter_list ',' parameter_declaration
        {
            // Additional parameter - nothing to propagate up
        }
    ;

parameter_declaration
    : type_specifier declarator
        {
            // Process parameter and add to current function's scope
            if (!current_symbol_table) {
                yyerror("No active scope for parameter declaration");
            } else {
                std::string param_name = $2->name;
                Symbol* param_sym = insert_symbol(param_name, $1); // Transfer ownership of type
                
                if (param_sym) {
                    // If we have a function context, add parameter info to function type
                    if (current_function && current_function->type) {
                        TypeInfo* param_type_copy = new TypeInfo($1->base, $1->width);
                        current_function->type->param_types.push_back(param_type_copy);
                        std::cout << "Debug: Added parameter '" << param_name << "' to function '" 
                                << current_function->name << "'" << std::endl;
                    }
                    
                    // Handle array parameters if needed
                    if ($2->array_dim > 0) {
                        // For Phase 6, treat arrays as pointers in parameters
                        if (param_sym->type) {
                            TypeInfo* array_type = new TypeInfo(TYPE_POINTER, 8);
                            array_type->ptr_type = param_sym->type; // Original type becomes pointed-to type
                            param_sym->type = array_type;
                        }
                    }
                } else {
                    delete $1; // Clean up type if insertion failed
                }
            }
            
            delete $2; // Clean up declarator
        }
    ;

identifier_list_opt
    : /* empty */ { /* Nothing to do */ }
    | identifier_list
    ;

identifier_list
    : IDENTIFIER
        {
            delete[] $1; // Clean up
        }
    | identifier_list ',' IDENTIFIER
        {
            delete[] $3; // Clean up
        }
    ;

initializer /* Phase 3: Handles expression */
    : assignment_expression { $$ = $1; }
    ;

/* 3. Statements */
statement /* Type: stmt_attr_ptr */
    : compound_statement    { $$ = $1; }
    | expression_statement  { $$ = $1; }
    | selection_statement   { $$ = $1; }
    | iteration_statement   { $$ = $1; /* Phase 5 */ }
    | jump_statement        { $$ = $1; }
    ;


compound_statement /* Type: stmt_attr_ptr */
    : BEGIN_TOKEN { begin_scope(); std::cout << "Debug: Entered scope" << std::endl;}
      block_item_list_opt /* Type: stmt_attr_ptr */
      END_TOKEN
        {
            std::cout << "Debug: Exiting scope" << std::endl; end_scope();
            $$ = $3 ? $3 : new StmtAttributes(); // If list was null, $$ gets new empty attributes
        }
    ;

block_item_list_opt /* Type: stmt_attr_ptr */
    : /* empty */ { $$ = nullptr; } /* Null means no statements, no nextlist */
    | block_item_list { $$ = $1; } /* Propagate attributes from list */
    ;

block_item_list /* Type: stmt_attr_ptr */
    : block_item { $$ = $1; /* First item's attributes */ }
    | block_item_list M block_item /* --- Phase 4 Step 5: Sequencing --- */
      {
        StmtAttributes* list_attr = $1;
        BackpatchList* marker_list = $2; // Contains index of first quad of block_item ($3)
        StmtAttributes* item_attr = $3;

        if (!list_attr) { // If first item was null (e.g., empty decl)
            $$ = item_attr; // The current item becomes the effective start
            delete marker_list; // M not used for backpatching here
        } else {
            if (list_attr->nextlist) {
                // Backpatch the previous statement list's nextlist to the start of the current item
                backpatch(*list_attr->nextlist, marker_list->front());
                std::cout << "Debug: Backpatched list at " << marker_list->front() << std::endl;
                delete list_attr->nextlist; // Clean up the now-used list
            }
            // The combined nextlist is the nextlist of the *last* statement ($3)
            if (item_attr) {
                 $$ = item_attr; // Transfer ownership of last item's attributes
            } else {
                 $$ = new StmtAttributes(); // If last item was null, create new attributes
            }
            // Cleanup intermediate attributes/lists
            delete list_attr; // list_attr->nextlist already deleted or was null
            delete marker_list;
        }
      }
    ;

block_item /* Type: stmt_attr_ptr */
    : declaration { $$ = new StmtAttributes(); /* Declarations have no nextlist */ }
    | statement   { $$ = $1; /* Propagate attributes from the actual statement */ }
    ;

expression_statement /* Type: stmt_attr_ptr */
    : ';' { $$ = new StmtAttributes(); }
    | expression ';' { if ($1) delete $1; $$ = new StmtAttributes(); } /* Cleanup expr */
    ;

/* --- Phase 4 Step 6: IF / IF-ELSE Logic --- */
selection_statement /* Type: stmt_attr_ptr */
    : IF '(' expression ')' M statement N %prec IFX
        { // Action for IF (...) M S1 N %prec IFX
            ExprAttributes* expr_attr = $3;
            BackpatchList* marker_M_list = $5; // List with quad index for start of 'then' statement
            StmtAttributes* stmt_attr = $6;
            BackpatchList* marker_N_list = $7; // List from the (unneeded) GOTO emitted by N

            if (!expr_attr) { yyerror("Invalid IF cond"); $$ = new StmtAttributes(); delete marker_M_list; delete stmt_attr; delete marker_N_list;} // Cleanup N
            else if (!expr_attr->type || expr_attr->type->base != TYPE_BOOL) { yyerror("IF cond bool"); delete expr_attr; delete marker_M_list; delete stmt_attr; delete marker_N_list; $$ = new StmtAttributes(); } // Cleanup N
            else {
                backpatch(*expr_attr->truelist, marker_M_list->front());
                $$ = new StmtAttributes();
                // The nextlist for the simple IF is the merge of the expression's falselist
                // and the statement's nextlist. The GOTO emitted by N is irrelevant here.
                if (stmt_attr && stmt_attr->nextlist) {
                    $$->nextlist = new BackpatchList(mergelist(*expr_attr->falselist, *stmt_attr->nextlist));
                    delete stmt_attr->nextlist; // stmt_attr's list merged
                } else {
                    $$->nextlist = expr_attr->falselist; // Only falselist if statement has no nextlist
                    expr_attr->falselist = nullptr;      // Avoid double delete
                }
                std::cout << "Debug: Simple IF statement processed. Nextlist created." << std::endl;

                // Cleanup
                delete expr_attr->truelist;
                delete expr_attr->falselist; // Might be null if transferred
                delete expr_attr;
                delete marker_M_list;
                delete marker_N_list; // <<< Delete the list from the unnecessary N marker
                delete stmt_attr; // stmt_attr->nextlist already handled
            }
        }
    | IF '(' expression ')' M statement N ELSE M statement
        { // Action for IF ... M S1 N ELSE M S2
            ExprAttributes* expr_attr = $3;
            BackpatchList* m1_list = $5;    // M before 'then'
            StmtAttributes* s1_attr = $6;   // 'then' statement
            BackpatchList* n_list = $7;     // List from N marker's GOTO
            // $8 is ELSE
            BackpatchList* m2_list = $9;    // M before 'else'
            StmtAttributes* s2_attr = $10;  // 'else' statement

            // --- Keep the error checking and backpatching/merging logic ---
            // --- from the version that correctly used these indices ---
            if (!expr_attr) { yyerror("Invalid IF-ELSE cond"); $$ = new StmtAttributes(); delete m1_list; delete s1_attr; delete n_list; delete m2_list; delete s2_attr;}
            else if (!expr_attr->type || expr_attr->type->base != TYPE_BOOL) { yyerror("IF-ELSE cond bool"); delete expr_attr; delete m1_list; delete s1_attr; delete n_list; delete m2_list; delete s2_attr; $$ = new StmtAttributes(); }
            else {
                backpatch(*expr_attr->truelist, m1_list->front());
                backpatch(*expr_attr->falselist, m2_list->front()); // Backpatch false list to M before else ($9)

                $$ = new StmtAttributes();
                BackpatchList temp_list1, temp_list2;

                // Combine stmt1->nextlist ($6) and the n_list ($7)
                if (s1_attr && s1_attr->nextlist) {
                    temp_list1 = mergelist(*s1_attr->nextlist, *n_list);
                    delete s1_attr->nextlist;
                } else {
                    temp_list1 = *n_list; // Only the jump over else
                }

                // Combine result with stmt2->nextlist ($10)
                if (s2_attr && s2_attr->nextlist) {
                    temp_list2 = mergelist(temp_list1, *s2_attr->nextlist);
                    delete s2_attr->nextlist;
                } else {
                    temp_list2 = temp_list1;
                }
                $$->nextlist = new BackpatchList(temp_list2);

                std::cout << "Debug: IF-ELSE statement processed. Nextlist created." << std::endl;

                // Cleanup
                delete expr_attr->truelist; delete expr_attr->falselist; delete expr_attr;
                delete m1_list; delete s1_attr; // s1_attr->nextlist deleted above
                if (n_list) delete n_list; // Could be null if ownership transferred
                delete m2_list; delete s2_attr; // s2_attr->nextlist deleted above
            }
        }


    ;

iteration_statement
    : FOR '(' expression_opt ';' 
           M                     // M1: Condition location
           expression_opt ';' 
           M                     // M2: Increment location
           expression_opt 
           ')'
           M                     // M3: Body location
           statement
      {
          // Extract attributes
          ExprAttributes* init_expr = $3;
          BackpatchList* cond_marker = $5;    // M1
          ExprAttributes* cond_expr = $6;
          BackpatchList* incr_marker = $8;    // M2
          ExprAttributes* incr_expr = $9;
          BackpatchList* body_marker = $11;   // M3
          StmtAttributes* body_stmt = $12;
          
          std::cout << "Debug: Processing FOR loop" << std::endl;
          
          // Create result attributes
          $$ = new StmtAttributes();
          
          // 1. Process condition
          if (cond_expr && cond_expr->type && cond_expr->type->base == TYPE_BOOL) {
              // Condition's falselist becomes the loop's exit point
              if (cond_expr->falselist) {
                  $$->nextlist = cond_expr->falselist;
                  cond_expr->falselist = nullptr; // Avoid double free
                  std::cout << "Debug: FOR loop exit point from condition falselist" << std::endl;
              } else {
                  $$->nextlist = new BackpatchList();
              }
          } else {
              std::cout << "Debug: FOR loop with no/invalid condition" << std::endl;
              $$->nextlist = new BackpatchList();
          }
          
          // 2. CRITICAL FIX: Insert jump to condition at end of increment section
          // We need to manually insert a quad that jumps to condition between the
          // increment code and the body code
          
          // Calculate position to insert the jump (between increment and body)
          int body_start = body_marker->front();
          
          // Create a new GOTO quad to jump back to condition
          Quad jump_to_cond(OP_GOTO, std::to_string(cond_marker->front()));
          
          // Insert this quad just before the body code starts
          quad_list.insert(quad_list.begin() + body_start, jump_to_cond);
          
          // Adjust next_quad_index to account for the insertion
          next_quad_index++;
          
          // *** CRITICAL FIX: Backpatch condition truelist to body+1 (after the inserted jump) ***
          if (cond_expr && cond_expr->truelist) {
              backpatch(*cond_expr->truelist, body_start + 1);
              std::cout << "Debug: Backpatched condition truelist to body at " 
                        << (body_start + 1) << " (after inserted jump)" << std::endl;
          }
          
          // 3. Link body to increment
          if (body_stmt && body_stmt->nextlist) {
              backpatch(*body_stmt->nextlist, incr_marker->front());
              std::cout << "Debug: Backpatched body nextlist to increment" << std::endl;
          } else {
              emit(OP_GOTO, std::to_string(incr_marker->front()));
              std::cout << "Debug: Emitted explicit jump from body to increment" << std::endl;
          }
          
          // Cleanup
          if (init_expr) delete init_expr;
          if (cond_expr) {
              if (cond_expr->truelist) delete cond_expr->truelist;
              delete cond_expr;
          }
          delete cond_marker;
          if (incr_expr) delete incr_expr;
          delete incr_marker;
          delete body_marker;
          if (body_stmt) delete body_stmt;
      }
    ;

expression_opt /* Type: expr_attr_ptr */
    : /* empty */ { $$ = nullptr; }
    | expression  { $$ = $1; }
    ;

/* --- Return Statement Processing --- */
jump_statement
    : RETURN ';'
        {
            // Return with no value
            $$ = new StmtAttributes();
            
            // Check if current function expects a return value
            if (current_function && current_function->type && 
                current_function->type->return_type && 
                current_function->type->return_type->base != TYPE_VOID) {
                yyerror("Return with no value in function returning non-void");
            }
            
            emit(OP_RETURN, "");
            std::cout << "Debug: Generated void return" << std::endl;
        }
    | RETURN expression ';'
        {
            // Return with value
            $$ = new StmtAttributes();
            
            if (!$2) {
                yyerror("Invalid return expression");
            } else if (!current_function) {
                yyerror("Return statement outside of function");
                delete $2;
            } else {
                TypeInfo* expected_type = nullptr;
                if (current_function->type) {
                    expected_type = current_function->type->return_type;
                }
                
                if (!expected_type) {
                    yyerror("Function return type not specified");
                    delete $2;
                } else if (expected_type->base == TYPE_VOID) {
                    yyerror("Void function cannot return a value");
                    delete $2;
                } else {
                    // Type check and conversion if needed
                    Symbol* return_value = $2->place;
                    
                    // Convert return value to expected type if needed
                    Symbol* converted_value = convert_type(return_value, expected_type);
                    
                    // Emit return quad with (possibly converted) value
                    emit(OP_RETURN, converted_value->name);
                    
                    std::cout << "Debug: Generated return with value " << converted_value->name << std::endl;
                    
                    delete $2;
                }
            }
        }
    ;

/* 4. External Definitions */
translation_unit : external_declaration | translation_unit external_declaration ;
external_declaration : function_definition | declaration ;

function_definition
    : type_specifier declarator 
        { 
            // Create function symbol with proper return type and name from declarator
            std::string func_name = $2->name;
            Symbol* func_sym = lookup_symbol(func_name, false);
            
            if (!func_sym) {
                func_sym = insert_symbol(func_name, new TypeInfo(TYPE_FUNCTION, 0));
                if (func_sym) {
                    // Set function return type based on type_specifier
                    func_sym->type->return_type = $1; // Transfer ownership of $1
                    std::cout << "Debug: Created function symbol '" << func_name << "' with return type " 
                             << func_sym->type->return_type->toString() << std::endl;
                } else {
                    delete $1; // Clean up if we couldn't create the function symbol
                }
            } else {
                // Function already exists - error or allow redefinition?
                yyerror(("Redefinition of function '" + func_name + "'").c_str());
                delete $1;
            }
            
            // Store function being processed as global
            current_function = func_sym;
            
            // Create nested scope for function body
            SymbolTable* func_scope = begin_scope();
            if (func_sym) {
                func_sym->nested_table = func_scope;
            }
            
            // Emit function begin marker
            emit(OP_FUNC_BEGIN, func_name);
            
            delete $2; // Clean up declarator
        }
        compound_statement
        {
            // Handle function end
            if (current_function) {
                // Check if function with non-void return type has a return statement
                if (current_function->type && current_function->type->return_type && 
                    current_function->type->return_type->base != TYPE_VOID) {
                    // We could warn about missing return, but that's a semantic warning not error
                }
                
                // Emit function end marker
                emit(OP_FUNC_END, current_function->name);
                
                // Reset current_function as we're done processing it
                current_function = nullptr;
            }
            
            // End_scope called by compound_statement already
            $$ = $4; // Explicit cast to help Bison understand; // Propagate statement attributes
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
