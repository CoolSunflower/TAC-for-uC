#pragma once

#include <string>
#include <vector>
#include <list>
#include <map>

// 1. FORWARD DECLARATIONS
struct Symbol;
struct TypeInfo;
class SymbolTable;

// 2. BASIC TYPE DEFINITIONS (enums)
typedef enum {
    // Binary Arithmetic
    OP_PLUS, OP_MINUS, OP_MULT, OP_DIV, OP_MOD,
    // Unary Arithmetic
    OP_UMINUS, OP_UPLUS,
    // Relational Operators (Result -> Temp Bool - Phase 3 Style)
    OP_LT, OP_GT, OP_LE, OP_GE, OP_EQ, OP_NE,
    // Logical Operators (Result -> Temp Bool - Phase 3 Style)
    OP_AND, OP_OR, OP_NOT,
    // Assignment
    OP_ASSIGN,
    // Jumps
    OP_GOTO,
    OP_IF_FALSE, // if (arg1 == false) goto result
    OP_IF_TRUE,  // if (arg1 == true) goto result

    // --- Phase 4: Add Specific Conditional Jumps ---
    OP_IF_LT,    // if (arg1 < arg2) goto result
    OP_IF_GT,    // if (arg1 > arg2) goto result
    OP_IF_LE,    // if (arg1 <= arg2) goto result
    OP_IF_GE,    // if (arg1 >= arg2) goto result
    OP_IF_EQ,    // if (arg1 == arg2) goto result
    OP_IF_NE,    // if (arg1 != arg2) goto result
    // --- End Phase 4 ---

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
    // Conversions
    OP_INT2FLOAT,
    OP_FLOAT2INT,
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
struct TypeInfo {
    base_type base = TYPE_UNKNOWN;
    int width = 0;
    std::vector<int> dims;
    TypeInfo* ptr_type = nullptr;
    std::vector<TypeInfo*> param_types;
    TypeInfo* return_type = nullptr;

    TypeInfo(base_type b = TYPE_UNKNOWN, int w = 0) : base(b), width(w), ptr_type(nullptr), return_type(nullptr) {}
    std::string toString() const;

    bool operator==(const TypeInfo& other) const {
        if (base != other.base) return false;
        // Add more checks based on type base if necessary
        // e.g., for pointers, compare ptr_type recursively
        if (base == TYPE_POINTER || base == TYPE_ARRAY) {
            if (!ptr_type && !other.ptr_type) return true;
            if (!ptr_type || !other.ptr_type) return false;
            return (*ptr_type == *other.ptr_type);
        }
        // e.g., for functions, compare return and param types
        if (base == TYPE_FUNCTION) {
             if (!return_type != !other.return_type) return false;
             if (return_type && !(*return_type == *other.return_type)) return false;
             if (param_types.size() != other.param_types.size()) return false;
             for (size_t i = 0; i < param_types.size(); ++i) {
                 if (!param_types[i] || !other.param_types[i] || !(*param_types[i] == *other.param_types[i])) {
                     return false;
                 }
             }
        }
        // Add array dimension checks if needed
        return true; // Bases match and no specific differences found
    }

    bool operator!=(const TypeInfo& other) const {
        return !(*this == other);
    }
};

struct Symbol {
    std::string name;
    TypeInfo* type = nullptr;
    std::string initial_value;
    int size = 0;
    int offset = 0;
    SymbolTable* nested_table = nullptr;
    bool is_temp = false;
    std::vector<int> pending_dims;
    std::vector<Symbol*> parameters; 

    Symbol(std::string n, TypeInfo* t = nullptr, int sz = 0, int off = 0)
        : name(n), type(t), size(sz), offset(off) {}
};

class SymbolTable {
public:
    std::map<std::string, Symbol*> symbols;
    SymbolTable* parent;
    int scope_level;
    std::vector<SymbolTable*> child_scopes; 
    std::string scope_name;

    SymbolTable(SymbolTable* p = nullptr, int level = 0, std::string name = "") : 
        parent(p), scope_level(level), scope_name(name) {}
    ~SymbolTable();
    Symbol* lookup(const std::string& name);
    bool insert(const std::string& name, Symbol* symbol);
};

extern std::vector<Symbol*> pending_type_symbols;
extern Symbol* current_function;
void apply_pending_types(TypeInfo* type);

// 4. QUAD AND BACKPATCH DEFINITIONS
struct Quad {
    op_code op;
    std::string arg1;
    std::string arg2;
    std::string result; // Target label for jumps, result name otherwise

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
void emit(op_code op, std::string result, std::string arg1 = "", std::string arg2 = "");
void print_quads(const std::string& filename);
void print_tac(const std::string& filename);
int get_next_quad_index();

void initialize_symbol_tables();
Symbol* lookup_symbol(const std::string& name, bool recursive = true);
Symbol* insert_symbol(const std::string& name, TypeInfo* type);
SymbolTable* begin_scope(std::string name);
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
