#pragma once // Use include guards

#include <string>
#include <vector>
#include <list>
#include <map>

// Forward declarations
class SymbolTable; 

// Enum for Three Address Code Opcodes
typedef enum {
    // Binary Arithmetic
    OP_PLUS, OP_MINUS, OP_MULT, OP_DIV, OP_MOD,
    // Unary Arithmetic
    OP_UMINUS, OP_UPLUS, 
    // Relational Operators
    OP_LT, OP_GT, OP_LE, OP_GE, OP_EQ, OP_NE,
    // Logical Operators
    OP_AND, OP_OR, OP_NOT,
    // Assignment
    OP_ASSIGN,
    // Jumps
    OP_GOTO, OP_IF_FALSE, // Conditional jump: if (arg1 == false) goto result
    OP_IF_TRUE,          // Conditional jump: if (arg1 == true) goto result
    // Function Call / Return
    OP_PARAM,       // Define parameter
    OP_CALL,        // Call function (arg1=func_name, arg2=num_params, result=return_temp (optional))
    OP_RETURN,      // Return from function (result=return_value (optional))
    // Pointer/Address Operations (Placeholders for later)
    OP_ADDR,        // Address-of operator (&) -> result = &arg1
    OP_DEREF_ASSIGN, // Assign to dereferenced pointer (*result = arg1)
    OP_ASSIGN_DEREF, // Assign from dereferenced pointer (result = *arg1)
    // Array Access (Placeholders for later)
    OP_ARRAY_ACCESS, // result = arg1[arg2] (arg1=array base, arg2=offset)
    OP_ARRAY_ASSIGN, // arg1[arg2] = result (arg1=array base, arg2=offset)
    // Markers
    OP_FUNC_BEGIN,
    OP_FUNC_END
} op_code;

// Enum for Basic Data Types
typedef enum {
    TYPE_VOID, TYPE_BOOL, TYPE_CHAR, TYPE_INTEGER, TYPE_FLOAT, 
    TYPE_POINTER, TYPE_ARRAY, TYPE_FUNCTION, TYPE_UNKNOWN
} base_type;

// Structure for Type Information
struct TypeInfo {
    base_type base = TYPE_UNKNOWN;
    int width = 0; // Size in bytes
    std::vector<int> dims; // For arrays: dimensions
    TypeInfo* ptr_type = nullptr; // For pointers: type it points to
    std::vector<TypeInfo*> param_types; // For functions: parameter types
    TypeInfo* return_type = nullptr; // For functions: return type

    TypeInfo(base_type b = TYPE_UNKNOWN, int w = 0) : base(b), width(w), ptr_type(nullptr), return_type(nullptr) {}
    // Add constructors/methods for arrays, pointers, functions as needed later
    std::string toString() const; // Declaration: To convert type to string
};

// Structure for Symbol Table Entry
struct Symbol {
    std::string name;
    TypeInfo* type = nullptr;
    std::string initial_value; // Optional initial value as string
    int size = 0;             // Total size (for arrays/structs)
    int offset = 0;           // Offset in activation record
    SymbolTable* nested_table = nullptr; // Pointer to nested scope (for functions/blocks)
    bool is_temp = false;      // Flag if it's a compiler-generated temporary

    Symbol(std::string n = "", TypeInfo* t = nullptr) : name(n), type(t), nested_table(nullptr) {}
    // Add more fields as needed (e.g., is_const, scope)
};

// Structure for Quadruple (Three Address Code)
struct Quad {
    op_code op;
    std::string arg1;
    std::string arg2;
    std::string result; // Result can be a variable name, temp name, constant, or label

    Quad(op_code o, std::string r, std::string a1 = "", std::string a2 = "") : 
        op(o), arg1(a1), arg2(a2), result(r) {}

    std::string toString() const; // Declaration: To format quad for printing
};

// Structure for Backpatch Lists (used in later phases)
// Using a list of integers, where each integer is an index into the quad_list
typedef std::list<int> BackpatchList;

// --- Global Variables (declared extern, defined in .cpp) ---
extern std::vector<Quad> quad_list;           // The list of generated quadruples
extern SymbolTable* global_symbol_table;      // The global symbol table
extern SymbolTable* current_symbol_table;     // The symbol table for the current scope
extern int next_quad_index;                   // Index of the next quad to be generated
extern int temp_counter;                      // Counter for generating temporary variable names

// --- Translator Function Prototypes ---

// Quad Management
void emit(op_code op, std::string result, std::string arg1 = "", std::string arg2 = "");
void print_quads();
int get_next_quad_index();

// Symbol Table Management (Basic stubs for Phase 1)
void initialize_symbol_tables();
Symbol* lookup_symbol(const std::string& name, bool recursive = true); // Look in current and parent scopes
bool insert_symbol(const std::string& name, TypeInfo* type); // Insert into current scope
SymbolTable* begin_scope();
void end_scope();
void print_symbol_table(SymbolTable* table_to_print = global_symbol_table, int level = 0);

// Temporary Variable Generation
Symbol* new_temp(TypeInfo* type);

// Type Checking / Conversion (Placeholders)
TypeInfo* typecheck(TypeInfo* t1, TypeInfo* t2, op_code op); 
Symbol* convert_type(Symbol* s, TypeInfo* target_type);

// Backpatching (Placeholders for Phase 4/5)
BackpatchList makelist(int quad_index);
BackpatchList mergelist(const BackpatchList& l1, const BackpatchList& l2);
void backpatch(BackpatchList& list, int target_quad_index);

// Helper to get string representation of opcode
std::string opcode_to_string(op_code op);

// Cleanup Function
void cleanup_translator();