#pragma once

#include <string>
#include <vector>
#include <list>
#include <map>

// 1. FORWARD DECLARATIONS
// Declare all structured types that reference each other first
struct Symbol;
struct TypeInfo;
class SymbolTable;

// 2. BASIC TYPE DEFINITIONS (enums)
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
    OP_GOTO, OP_IF_FALSE,
    OP_IF_TRUE,
    // Function Call / Return
    OP_PARAM,
    OP_CALL,
    OP_RETURN,
    // Pointer/Address Operations
    OP_ADDR,
    OP_DEREF_ASSIGN,
    OP_ASSIGN_DEREF,
    // Array Access
    OP_ARRAY_ACCESS,
    OP_ARRAY_ASSIGN,
    // Markers
    OP_FUNC_BEGIN,
    OP_FUNC_END
} op_code;

// Enum for Basic Data Types
typedef enum {
    TYPE_VOID, TYPE_BOOL, TYPE_CHAR, TYPE_INTEGER, TYPE_FLOAT, 
    TYPE_POINTER, TYPE_ARRAY, TYPE_FUNCTION, TYPE_UNKNOWN
} base_type;

// 3. COMPLETE TYPE DEFINITIONS (in dependency order)
// First define TypeInfo which doesn't depend on Symbol
struct TypeInfo {
    base_type base = TYPE_UNKNOWN;
    int width = 0;
    std::vector<int> dims;
    TypeInfo* ptr_type = nullptr;
    std::vector<TypeInfo*> param_types;
    TypeInfo* return_type = nullptr;

    TypeInfo(base_type b = TYPE_UNKNOWN, int w = 0) : base(b), width(w), ptr_type(nullptr), return_type(nullptr) {}
    std::string toString() const;
};

// Then define Symbol which depends on TypeInfo
struct Symbol {
    std::string name;
    TypeInfo* type = nullptr;
    std::string initial_value;
    int size = 0;
    int offset = 0;
    SymbolTable* nested_table = nullptr;
    bool is_temp = false;
    std::vector<int> pending_dims; // Temporarily store array dimensions

    Symbol(std::string n = "", TypeInfo* t = nullptr) : name(n), type(t), nested_table(nullptr) {}
};

// Now define SymbolTable which depends on Symbol
class SymbolTable {
public:
    std::map<std::string, Symbol*> symbols;
    SymbolTable* parent;
    int scope_level;
    std::vector<SymbolTable*> child_scopes; 

    SymbolTable(SymbolTable* p = nullptr, int level = 0) : parent(p), scope_level(level) {}
    ~SymbolTable();
    Symbol* lookup(const std::string& name);
    bool insert(const std::string& name, Symbol* symbol);
};

extern std::vector<Symbol*> pending_type_symbols; // Symbols waiting for type assignment
extern Symbol* current_function; // Tracks function being processed
void apply_pending_types(TypeInfo* type);

// 4. QUAD AND BACKPATCH DEFINITIONS
struct Quad {
    op_code op;
    std::string arg1;
    std::string arg2;
    std::string result;

    Quad(op_code o, std::string r, std::string a1 = "", std::string a2 = "") : 
        op(o), arg1(a1), arg2(a2), result(r) {}

    std::string toString() const;
};

typedef std::list<int> BackpatchList;

// 5. GLOBAL VARIABLES
extern std::vector<Quad> quad_list;
extern SymbolTable* global_symbol_table;
extern SymbolTable* current_symbol_table;
extern int next_quad_index;
extern int temp_counter;

// 6. FUNCTION PROTOTYPES
// Now all the types they use are properly defined
void emit(op_code op, std::string result, std::string arg1 = "", std::string arg2 = "");
void print_quads();
int get_next_quad_index();

void initialize_symbol_tables();
Symbol* lookup_symbol(const std::string& name, bool recursive = true);
Symbol* insert_symbol(const std::string& name, TypeInfo* type);
SymbolTable* begin_scope();
void end_scope();
void print_symbol_table(SymbolTable* table_to_print = nullptr, int level = 0);

Symbol* new_temp(TypeInfo* type);

TypeInfo* typecheck(TypeInfo* t1, TypeInfo* t2, op_code op); 
Symbol* convert_type(Symbol* s, TypeInfo* target_type);

BackpatchList makelist(int quad_index);
BackpatchList mergelist(const BackpatchList& l1, const BackpatchList& l2);
void backpatch(BackpatchList& list, int target_quad_index);

std::string opcode_to_string(op_code op);

void cleanup_translator();
