%{
/* Parser for micro C language (Phase 1 - C++ Integration) */
#include <cstdio>       // Use C++ headers
#include <cstdlib>
#include <cstring>
#include <iostream>     // For std::cerr, std::cout
#include <string>       // For std::string (used in translator)
#include <vector>       // For std::vector (used in translator)
#include <list>         // For std::list (used in translator)

// External declarations
extern int yylex();       // The lexer function
extern FILE* yyin;      // Input file stream (remains FILE*)
extern int line_no;     // Current line number from lexer
extern char* yytext;    // Current lexeme text (provided by lexer)

// Function Prototypes
void yyerror(const char* s); // Error reporting function

// --- REMOVED OLD C Symbol Table Structures and Functions ---
// NO struct symbol definition here
// NO global Symbol* symbol_table here
// NO int current_scope here
// NO insert_symbol, lookup_symbol, print_symbol_table, free_symbol_table function definitions here

%}

%code requires {
    #include "a9_220101003.h" 
}

/* Bison Declarations */

// Define the union for semantic values
%union {
    int ival;
    float fval;
    char cval;
    char* sval; // For IDENTIFIER, STRING_LITERAL (lexer provides char*)
                // ** CRITICAL: Parser actions MUST delete[] sval memory **

    // Pointers to structures needed for semantic analysis (from a9_translator.h)
    Symbol* sym_ptr;         // Pointer to a symbol table entry
    TypeInfo* type_ptr;      // Pointer to type information
    BackpatchList* list_ptr; // Pointer to a backpatch list (used later)
    
    // Placeholder for expression attributes (used later)
    // struct { Symbol* place; TypeInfo* type; } expr_attr; 
    
    // Placeholder for statement attributes (used later)
    // struct { BackpatchList* next; BackpatchList* breaklist; BackpatchList* continuelist; } stmt_attr;

};

// Define types for tokens that carry values from the lexer (using the new union fields)
%token <ival> INT_CONSTANT
%token <fval> FLOAT_CONSTANT
%token <cval> CHAR_CONSTANT
%token <sval> IDENTIFIER STRING_LITERAL // Uses char* from lexer

// Define keywords and operators (no associated value needed in union)
%token RETURN VOID FLOAT INTEGER CHAR FOR CONST WHILE BOOL IF DO ELSE BEGIN_TOKEN END_TOKEN
%token ARROW INC DEC SHL SHR LE GE EQ NE AND OR 

%type <sval> direct_declarator 

// Define types for non-terminals that will carry semantic values (Phase 1: mostly placeholders)
// Examples (Uncomment and adapt in later phases):
// %type <type_ptr> type_specifier 
// %type <sym_ptr> primary_expression assignment_expression unary_expression
// %type <expr_attr> expression conditional_expression logical_OR_expression ... etc.
// %type <list_ptr> M N             
// %type <stmt_attr> statement 

/* Operator Precedence and Associativity (Copied from original, check Micro C spec if different) */
%right '='
// %right '?' ':' // Micro C spec doesn't explicitly list ternary, remove if unsupported
%left OR
%left AND
// %left '|' // Assume bitwise ops are not in Micro C unless spec says otherwise
// %left '&' // Assume bitwise ops are not in Micro C unless spec says otherwise
%left EQ NE
%left '<' '>' LE GE
// %left SHL SHR // Assume bitwise shift ops are not in Micro C
%left '+' '-'
%left '*' '/' '%'
%right '!' // Logical NOT
// %right '~' // Assume bitwise NOT is not in Micro C
// %right '&' '*' // Unary Address-of/Dereference (Add later if supported)
// %left '.' ARROW // Member access (Add later if supported)
// %left '[' ']' '(' ')' // Array/Function call (Highest precedence, handled by rules)


// Handling the "dangling else" ambiguity
%nonassoc IFX  /* Prec for IF without ELSE */
%nonassoc ELSE /* Prec for IF with ELSE */

/* Start symbol */
%start translation_unit

%%

/* Grammar Rules (Phase 1 - Structure + Cleanup, NO TAC actions yet) */

/* 1. Expressions */
primary_expression
    : IDENTIFIER         { /* Phase 3: lookup symbol */ delete[] $1; } // Cleanup sval
    | INT_CONSTANT       { /* Phase 3: handle constant */ }
    | FLOAT_CONSTANT     { /* Phase 3: handle constant */ }
    | CHAR_CONSTANT      { /* Phase 3: handle constant */ }
    | STRING_LITERAL     { /* Phase 3: handle literal */ delete[] $1; } // Cleanup sval
    | '(' expression ')' { /* Phase 3: $$ = $2 */ }
    ;

postfix_expression
    : primary_expression             { /* Phase 3: $$ = $1 */ }
    | postfix_expression '[' expression ']' { /* Phase 7: array access */ }
    | postfix_expression '(' ')'     { /* Phase 6: function call (no args) */ }
    | postfix_expression '(' argument_expression_list ')' { /* Phase 6: function call (w/ args) */ }
    | postfix_expression ARROW IDENTIFIER { /* Phase ?: struct/ptr access */ delete[] $3; } // Cleanup IDENTIFIER sval
    ;

argument_expression_list
    : assignment_expression                { /* Phase 6: process arg */ }
    | argument_expression_list ',' assignment_expression { /* Phase 6: process args */ }
    ;

unary_expression
    : postfix_expression         { /* Phase 3: $$ = $1 */ }
    | unary_operator unary_expression { /* Phase 3: apply operator */ }
    // Add INC/DEC later if needed by Micro C spec
    ;

unary_operator // Adapt based on actual Micro C spec
    : '&' { /* Phase 7: Address-of */ }
    | '*' { /* Phase 7: Dereference */ }
    | '+' { /* Phase 3: Unary plus */ }
    | '-' { /* Phase 3: Unary minus */ }
    | '!' { /* Phase 3: Logical NOT */ }
    // Remove '~' if not supported
    ;

multiplicative_expression
    : unary_expression             { /* Phase 3: $$ = $1 */ }
    | multiplicative_expression '*' unary_expression { /* Phase 3: emit MUL */ }
    | multiplicative_expression '/' unary_expression { /* Phase 3: emit DIV */ }
    | multiplicative_expression '%' unary_expression { /* Phase 3: emit MOD */ }
    ;

additive_expression
    : multiplicative_expression    { /* Phase 3: $$ = $1 */ }
    | additive_expression '+' multiplicative_expression { /* Phase 3: emit ADD */ }
    | additive_expression '-' multiplicative_expression { /* Phase 3: emit SUB */ }
    ;

// Remove SHL/SHR rules if bitwise shift not supported

relational_expression
    : additive_expression          { /* Phase 3: $$ = $1 */ }
    | relational_expression '<' additive_expression { /* Phase 3: emit LT */ }
    | relational_expression '>' additive_expression { /* Phase 3: emit GT */ }
    | relational_expression LE additive_expression  { /* Phase 3: emit LE */ }
    | relational_expression GE additive_expression  { /* Phase 3: emit GE */ }
    ;

equality_expression
    : relational_expression        { /* Phase 3: $$ = $1 */ }
    | equality_expression EQ relational_expression { /* Phase 3: emit EQ */ }
    | equality_expression NE relational_expression { /* Phase 3: emit NE */ }
    ;

// Remove bitwise AND/OR rules ('&', '|') if not supported

logical_AND_expression
    : equality_expression          { /* Phase 3: $$ = $1 */ }
    | logical_AND_expression AND equality_expression { /* Phase 3: emit AND */ }
    ;

logical_OR_expression
    : logical_AND_expression       { /* Phase 3: $$ = $1 */ }
    | logical_OR_expression OR logical_AND_expression { /* Phase 3: emit OR */ }
    ;

conditional_expression // Remove if ternary '?:' not supported
    : logical_OR_expression        { /* Phase 3: $$ = $1 */ }
    // | logical_OR_expression '?' expression ':' conditional_expression { /* Phase ?: ternary op */ }
    ;

assignment_expression
    : conditional_expression       { /* Phase 3: $$ = $1 */ }
    | unary_expression '=' assignment_expression { /* Phase 3: emit ASSIGN */ }
    ;

expression
    : assignment_expression        { /* Phase 3: $$ = $1 */ }
    ;

/* 2. Declarations */
declaration
    : type_specifier init_declarator_list_opt ';' 
        { /* Phase 2: Process completed declarations */ }
    ;

init_declarator_list_opt
    : /* empty */ 
    | init_declarator_list
    ;
    
init_declarator_list
    : init_declarator
    | init_declarator_list ',' init_declarator
    ;

init_declarator
    : declarator                   { /* Phase 2: associate type with declarator */ }
    | declarator '=' initializer   { /* Phase 2: handle initialization */ }
    ;

type_specifier // Add CONST if needed
    : VOID     { /* Phase 2: Set type attribute to VOID */ }
    | CHAR     { /* Phase 2: Set type attribute to CHAR */ }
    | INTEGER  { /* Phase 2: Set type attribute to INTEGER */ }
    | FLOAT    { /* Phase 2: Set type attribute to FLOAT */ }
    | BOOL     { /* Phase 2: Set type attribute to BOOL */ }
    ;

declarator
    // Add pointer rules later if needed: | pointer direct_declarator 
    : direct_declarator          { /* Phase 2: pass declarator info up */ }
    ;

direct_declarator
    : IDENTIFIER                 
        { /* Phase 2: Get identifier name. Store $1 for symbol creation */
          // For Phase 1, just manage memory. We assume $1 will be used by init_declarator
          $$ = $1; // Pass the sval pointer up
        }
    | '(' declarator ')'         
        { /* Phase 2: handle complex declarators */ 
          // If declarator contained sval, it should be managed there or passed up in $$
        }
    | direct_declarator '[' INT_CONSTANT ']' { /* Phase 7: Array declaration */ } 
    | direct_declarator '[' ']'              { /* Phase 7: Array declaration (no size) */ }
    | direct_declarator '(' parameter_list ')' { /* Phase 6: Function declarator */ }
    | direct_declarator '(' identifier_list_opt ')' { /* Phase 6: Function declarator (old style) */ }
    ;

// Add pointer rule later if needed: pointer : '*' | pointer '*' ;

parameter_list
    : parameter_declaration
    | parameter_list ',' parameter_declaration
    ;

parameter_declaration
    : type_specifier declarator // Simplified for now
        { /* Phase 6: Process parameter type and name */ 
          // Declarator action should handle cleanup of its IDENTIFIER sval
        }
    // Add abstract declarator (type only) rule if needed
    ;

identifier_list_opt
    : /* empty */
    | identifier_list
    ;
    
identifier_list
    : IDENTIFIER                { delete[] $1; } // Cleanup sval
    | identifier_list ',' IDENTIFIER { delete[] $3; } // Cleanup sval
    ;

initializer
    : assignment_expression      { /* Phase 2: handle initializer expression */ }
    // Add initializer list '{ ... }' rule later if needed
    ;


/* 3. Statements */
statement
    : compound_statement       { /* Phase 2+: Add nextlist handling */ }
    | expression_statement     { /* Phase 3+: Add nextlist handling */ }
    | selection_statement      { /* Phase 4+: Add nextlist handling */ }
    | iteration_statement      { /* Phase 5+: Add nextlist handling */ }
    | jump_statement           { /* Phase 6: No nextlist needed for return */ }
    ;

compound_statement // Represents BEGIN/END block
    : BEGIN_TOKEN 
        { /* Phase 2: begin_scope(); */ } 
      block_item_list_opt 
      END_TOKEN 
        { /* Phase 2: end_scope(); */ }
    ;

block_item_list_opt
    : /* empty */
    | block_item_list
    ;
    
block_item_list
    : block_item
    | block_item_list block_item
    ;

block_item
    : declaration // Declarations within a block
    | statement   // Statements within a block
    ;

expression_statement
    : ';'                      { /* Empty statement */ }
    | expression ';'           { /* Evaluated for side effects */ }
    ;

selection_statement // IF / IF-ELSE
    : IF '(' expression ')' statement %prec IFX
        { /* Phase 4: Backpatching for if */ }
    | IF '(' expression ')' statement ELSE statement 
        { /* Phase 4: Backpatching for if-else */ }
    ;

iteration_statement // FOR loop (add WHILE/DO if in Micro C spec)
    : FOR '(' expression_opt ';' expression_opt ';' expression_opt ')' statement 
        { /* Phase 5: Backpatching for for */ }
    ;

expression_opt
    : /* empty */
    | expression 
    ;

jump_statement // RETURN
    : RETURN ';'               { /* Phase 6: emit RETURN */ }
    | RETURN expression ';'    { /* Phase 6: emit RETURN value */ }
    // Add BREAK/CONTINUE later if needed for loops
    ;

/* 4. External Definitions (Top Level) */
translation_unit
    : external_declaration
    | translation_unit external_declaration
    ;

external_declaration
    : function_definition
    | declaration           // Global declarations
    ;

function_definition
    : type_specifier declarator compound_statement 
        { /* Phase 6: Process function definition, symbol table, body */ 
          // Declarator action should handle cleanup of its IDENTIFIER sval
        }
    ;

// Remove function_declarator rules if handled within direct_declarator

%%

/* C++ Code Section */

FILE* lex_output = nullptr; 

// Error Handling Function (using C++ iostream)
void yyerror(const char* s) {
    std::cerr << "Syntax Error: " << s << " near '" << (yytext ? yytext : "EOF") 
              << "' at line " << line_no << std::endl;
    // Exit on first syntax error for simplicity in Phase 1
    exit(EXIT_FAILURE); 
}

// --- REMOVED OLD C function implementations ---

/* Main Function (using C++ translator) */
int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <input_file>" << std::endl;
        return 1;
    }

    // --- Input File Handling ---
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        std::cerr << "Error: Cannot open input file: " << argv[1] << std::endl;
        return 1;
    }

    // --- Lexer Output File Handling (Add this block) ---
    char lex_filename[FILENAME_MAX]; // Use FILENAME_MAX for buffer size
    strncpy(lex_filename, argv[1], FILENAME_MAX - 10); // Copy base name safely
    lex_filename[FILENAME_MAX - 10] = '\0'; // Ensure null termination
    strcat(lex_filename, ".lex.out");       // Append suffix

    lex_output = fopen(lex_filename, "w");
    if (!lex_output) {
        // Non-fatal: Warn but continue if lex output can't be created
        std::cerr << "Warning: Cannot create lexer output file: " << lex_filename << std::endl;
        lex_output = nullptr; // Ensure it's null if open failed
    } else {
        std::cout << "Lexical analysis output will be written to " << lex_filename << std::endl;
        fprintf(lex_output, "LEXICAL ANALYSIS FOR FILE: %s\n---\n", argv[1]); // Add header
    }
    // --- End Lexer Output File Handling ---


    // --- Initialization & Parsing ---
    initialize_symbol_tables(); 
    std::cout << "Starting parse for file: " << argv[1] << std::endl;
    int parse_result = yyparse(); 
    fclose(yyin); // Close input file

    // --- Post-Parsing Output ---
    if (parse_result == 0) {
        std::cout << "Parsing completed successfully." << std::endl;
        print_symbol_table(global_symbol_table); 
        print_quads();           
    } else {
        std::cerr << "Parsing failed." << std::endl;
    }

    // --- Cleanup ---
    cleanup_translator(); // Cleanup translator resources

    // --- Close Lexer Output File (Add this block) ---
    if (lex_output != nullptr) {
        fprintf(lex_output, "\n---\nEND OF LEXICAL ANALYSIS\n");
        fclose(lex_output);
        lex_output = nullptr; // Good practice
    }
    // --- End Close Lexer Output File ---

    return parse_result; 
}
