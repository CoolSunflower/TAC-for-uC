#include "a9_220101003.h"
#include <iostream>
#include <iomanip> // For std::setw

// --- Define Global Variables ---
std::vector<Quad> quad_list;
SymbolTable* global_symbol_table = nullptr;
SymbolTable* current_symbol_table = nullptr;
int next_quad_index = 0;
int temp_counter = 0;
Symbol* current_function = nullptr;
std::vector<Symbol*> pending_type_symbols;

// Add this helper function
void apply_pending_types(TypeInfo* type) {
    for (Symbol* sym : pending_type_symbols) {
        if (sym) {
            // Create appropriate type
            TypeInfo* final_type;
            
            if (!sym->pending_dims.empty()) {
                // Create array type
                final_type = new TypeInfo(TYPE_ARRAY, 0);
                final_type->dims = sym->pending_dims;
                
                // Create and link element type
                final_type->ptr_type = new TypeInfo(type->base, type->width);
                
                // Calculate total size
                int total_size = type->width;
                for (int dim : sym->pending_dims) {
                    total_size *= dim;
                }
                final_type->width = total_size;
            } else {
                // Create regular type
                final_type = new TypeInfo(type->base, type->width);
            }

            sym->type = final_type;
            sym->size = final_type->width;
            
            std::cout << "Debug: Applied type '" << final_type->toString() 
                    << "' to pending symbol '" << sym->name << "'" << std::endl;
        }
    }
    pending_type_symbols.clear(); // Reset for next declaration
}

// --- SymbolTable Class Definition (Basic for Phase 1) ---
SymbolTable::~SymbolTable() {
    // Basic cleanup - delete symbols owned by this table
    // Careful: Nested tables might be managed elsewhere or need specific deletion logic
    for (auto const& [key, val] : symbols) {
        if (val) {
                delete val->type; // Assuming type is owned by symbol
                // Don't delete nested_table here unless ownership is clear
                delete val;
        }
    }
    symbols.clear();
    // Note: Deleting nested tables needs careful handling to avoid double deletes
    // Might be better managed explicitly in end_scope or main cleanup
}   

Symbol* SymbolTable::lookup(const std::string& name) {
    auto it = symbols.find(name);
    if (it != symbols.end()) {
        return it->second; // Found in current scope
    }
    return nullptr; // Not found in this scope
}

bool SymbolTable::insert(const std::string& name, Symbol* symbol) {
    if (lookup(name)) {
        return false; // Already exists in this scope
    }
    symbols[name] = symbol;
    return true;
}
    
std::string TypeInfo::toString() const {
    switch(base) {
        case TYPE_VOID: return "void";
        case TYPE_BOOL: return "bool";
        case TYPE_CHAR: return "char";
        case TYPE_INTEGER: return "integer";
        case TYPE_FLOAT: return "float";
        case TYPE_POINTER: return (ptr_type ? ptr_type->toString() + "*" : "pointer(unknown)");
        case TYPE_ARRAY: {
            // CRITICAL FIX: Show element type and dimensions
            std::string elem_type = "unknown";
            if (ptr_type) {
                elem_type = ptr_type->toString();
            }
            
            std::string dims_str = "";
            if (!dims.empty()) {
                dims_str = "[";
                for (size_t i = 0; i < dims.size(); ++i) {
                    if (i > 0) dims_str += ",";
                    dims_str += std::to_string(dims[i]);
                }
                dims_str += "]";
            }
            
            return "array<" + elem_type + ">" + dims_str;
        }
        case TYPE_FUNCTION: return "function";
        default: return "unknown";
    }
}

// --- Quad Implementation ---
std::string opcode_to_string(op_code op) {
    switch(op) {
        case OP_PLUS: return "+"; case OP_MINUS: return "-"; case OP_MULT: return "*"; 
        case OP_DIV: return "/"; case OP_MOD: return "%"; case OP_UMINUS: return "uminus";
        case OP_UPLUS: return "uplus"; case OP_LT: return "<"; case OP_GT: return ">";
        case OP_LE: return "<="; case OP_GE: return ">="; case OP_EQ: return "==";
        case OP_NE: return "!="; case OP_AND: return "&&"; case OP_OR: return "||";
        case OP_NOT: return "!"; case OP_ASSIGN: return "="; case OP_GOTO: return "goto";
        case OP_IF_FALSE: return "if_false"; case OP_IF_TRUE: return "if_true";
        case OP_PARAM: return "param"; case OP_CALL: return "call"; case OP_RETURN: return "return";
        case OP_ADDR: return "&"; case OP_DEREF_ASSIGN: return "*="; case OP_ASSIGN_DEREF: return "=*";
        case OP_ARRAY_ACCESS: return "[]"; case OP_ARRAY_ASSIGN: return "[]=";
        case OP_FUNC_BEGIN: return "func_begin"; case OP_FUNC_END: return "func_end";
        default: return "op_unknown";
    }
}

std::string Quad::toString() const {
    std::string op_str = opcode_to_string(op);
    std::string res_str = result;
    std::string a1_str = arg1;
    std::string a2_str = arg2;

    // Basic formatting - adjust as needed
    if (op >= OP_PLUS && op <= OP_MOD || op >= OP_LT && op <= OP_NE || op == OP_AND || op == OP_OR) {
        return res_str + " = " + a1_str + " " + op_str + " " + a2_str;
    } else if (op == OP_UMINUS || op == OP_UPLUS || op == OP_NOT || op == OP_ASSIGN || op == OP_ADDR || op == OP_ASSIGN_DEREF) {
        return res_str + " = " + op_str + " " + a1_str;
    } else if (op == OP_GOTO) {
        return op_str + " " + res_str; // Result holds the label/target quad index
    } else if (op == OP_IF_FALSE || op == OP_IF_TRUE) {
        return op_str + " " + a1_str + " goto " + res_str; // Arg1 is condition, Result is target
    } else if (op == OP_PARAM) {
         return op_str + " " + res_str; // Result is the parameter name/temp
    } else if (op == OP_CALL) {
        return (res_str.empty() ? "" : res_str + " = ") + op_str + " " + a1_str + ", " + a2_str; // a1=func, a2=nparams
    } else if (op == OP_RETURN) {
        return op_str + (res_str.empty() ? "" : " " + res_str);
    } else if (op == OP_FUNC_BEGIN || op == OP_FUNC_END) {
        return op_str + " " + res_str; // Result might hold function name
    } else if (op == OP_DEREF_ASSIGN) {
        return "*" + res_str + " = " + a1_str;
    }
     else if (op == OP_ARRAY_ACCESS) {
        return res_str + " = " + a1_str + "[" + a2_str + "]";
    } else if (op == OP_ARRAY_ASSIGN) {
        return a1_str + "[" + a2_str + "] = " + res_str;
    }
    
    // Default fallback
    return op_str + ", " + res_str + ", " + a1_str + ", " + a2_str; 
}


// --- Translator Function Implementations ---

void emit(op_code op, std::string result, std::string arg1, std::string arg2) {
    quad_list.emplace_back(op, result, arg1, arg2);
    next_quad_index++;
}

void print_quads() {
    std::cout << "\n--- Generated Quads ---" << std::endl;
    if (quad_list.empty()) {
        std::cout << "(No quads generated)" << std::endl;
        return;
    }
    std::cout << std::left; // Left-align output
    for (size_t i = 0; i < quad_list.size(); ++i) {
        std::cout << std::setw(4) << i << ": " << quad_list[i].toString() << std::endl;
    }
    std::cout << "-----------------------" << std::endl;
}

int get_next_quad_index() {
    return next_quad_index;
}

void initialize_symbol_tables() {
    if (global_symbol_table) delete global_symbol_table; // Basic cleanup if re-initializing
    global_symbol_table = new SymbolTable(nullptr, 0); // Global scope has no parent, level 0
    current_symbol_table = global_symbol_table;
}

// Basic recursive lookup for Phase 1 (no complex scope rules yet)
Symbol* lookup_symbol(const std::string& name, bool recursive) {
    SymbolTable* table = current_symbol_table;
    while (table != nullptr) {
        Symbol* sym = table->lookup(name);
        if (sym) {
            return sym; // Found
        }
        if (!recursive) {
             break; // Don't check parent scopes if recursive is false
        }
        table = table->parent; // Move to parent scope
    }
    return nullptr; // Not found
}

// Basic insert for Phase 1
Symbol* insert_symbol(const std::string& name, TypeInfo* type) {
    if (!current_symbol_table) return NULL; // Should not happen if initialized

    // Check if already exists in the *current* scope only
    if (lookup_symbol(name, false)) { 
        std::cerr << "Error: Redeclaration of symbol '" << name << "' in current scope." << std::endl;
        // In a real compiler, yyerror might be called or an error flag set
        return NULL; 
    }

    Symbol* sym = new Symbol(name, type); 
    // Assign basic size for known types (can refine later)
    if (type) {
        switch(type->base) {
            case TYPE_CHAR: sym->size = 1; break;
            case TYPE_BOOL: sym->size = 1; break;
            case TYPE_INTEGER: sym->size = 4; break; // Assuming 4-byte int
            case TYPE_FLOAT: sym->size = 4; break;   // Assuming 4-byte float
            default: sym->size = 0; // Pointers, arrays, void, functions need calculation
        }
    }
    // Offset calculation would happen here in a real implementation
    
    current_symbol_table->insert(name, sym);
    // std::cout << "Debug: Inserted symbol '" << name << "' into scope " << current_symbol_table->scope_level << std::endl; // Optional debug
    return sym;
}

void print_debug_scope() {
    if (current_symbol_table) {
        std::cout << "Debug: Current scope level is " << current_symbol_table->scope_level << std::endl;
    } else {
        std::cout << "Debug: No current symbol table" << std::endl;
    }
}

// Creates a new scope nested within the current one
SymbolTable* begin_scope() {
    if (!current_symbol_table) initialize_symbol_tables();

    int next_level = current_symbol_table->scope_level + 1;
    SymbolTable* new_table = new SymbolTable(current_symbol_table, next_level);
    current_symbol_table->child_scopes.push_back(new_table); // Add child to parent's list
    current_symbol_table = new_table;
    print_debug_scope(); // Optional debug
    return new_table;
}

// Exits the current scope and returns to the parent scope
void end_scope() {
    if (current_symbol_table && current_symbol_table->parent) {
        SymbolTable* parent_table = current_symbol_table->parent;
        // Optional: Store the finished scope's table in the parent symbol that created it (e.g., function symbol)
        
        // Clean up the current scope's table IF it's not stored elsewhere
        // delete current_symbol_table; // Be careful with ownership if tables are stored!
        print_debug_scope(); // Optional debug        
        current_symbol_table = parent_table;
        // std::cout << "Debug: Exited to scope level " << current_symbol_table->scope_level << std::endl; // Optional debug
    } else {
        print_debug_scope(); // Optional debug
        std::cerr << "Warning: Attempted to end global scope or symbol table not initialized." << std::endl;
    }
}

// Basic placeholder for temporary generation
Symbol* new_temp(TypeInfo* type) {
    std::string temp_name = "t" + std::to_string(temp_counter++);
    Symbol* temp_sym = new Symbol(temp_name, type);
    temp_sym->is_temp = true; 
    // Insert the temporary into the *current* symbol table so it can be looked up if needed
    // Temporaries usually don't clash with user variables, but tracking them is good
    if (!current_symbol_table) initialize_symbol_tables(); 
    current_symbol_table->insert(temp_name, temp_sym); 
    
    // Important: The Symbol* returned usually holds the *name* which is used in Quads.
    // We return the Symbol* itself as it contains name, type, etc.
    return temp_sym; 
}

// --- Placeholder Implementations ---

TypeInfo* typecheck(TypeInfo* t1, TypeInfo* t2, op_code op) {
    // Phase 1: No actual type checking logic needed yet.
    // In later phases, this would check compatibility based on op.
    // std::cout << "Debug: typecheck called (Phase 1 stub)" << std::endl;
    if (t1) return t1; // Just return one of the types for now
    if (t2) return t2;
    return new TypeInfo(TYPE_UNKNOWN); // Fallback
}

Symbol* convert_type(Symbol* s, TypeInfo* target_type) {
    // Phase 1: No type conversion logic needed yet.
    // std::cout << "Debug: convert_type called (Phase 1 stub)" << std::endl;
    // This would emit conversion quads (e.g., INT2FLOAT) later.
    return s; // Return original symbol for now
}

BackpatchList makelist(int quad_index) {
    // Phase 1: Just return an empty list.
    // std::cout << "Debug: makelist called (Phase 1 stub)" << std::endl;
    return BackpatchList(1, quad_index); // Or return {quad_index};
}

BackpatchList mergelist(const BackpatchList& l1, const BackpatchList& l2) {
    // Phase 1: Just return an empty list.
    // std::cout << "Debug: mergelist called (Phase 1 stub)" << std::endl;
    BackpatchList result = l1;
    result.insert(result.end(), l2.begin(), l2.end());
    return result;
}

void backpatch(BackpatchList& list, int target_quad_index) {
    // Phase 1: Do nothing.
    // std::cout << "Debug: backpatch called (Phase 1 stub)" << std::endl;
    std::string target_str = std::to_string(target_quad_index);
    for (int index : list) {
        if (index >= 0 && index < quad_list.size()) {
            // Assuming the 'result' field holds the jump target for GOTO/IF_FALSE etc.
            quad_list[index].result = target_str; 
        }
    }
    list.clear(); // Clear the list after backpatching
}


void print_symbol_table(SymbolTable* table_to_print, int level) {
    if (!table_to_print) {
        table_to_print = global_symbol_table;
    }
    
    if (!table_to_print) return;

    // Indentation for scope level
    std::string indent(level * 4, ' '); 

    // Print table header with scope level
    if (level == 0) {
        std::cout << "\n--- Symbol Table ---" << std::endl;
    }
    
    std::cout << indent << std::left << std::setw(20) << "Name" 
              << std::setw(30) << "Type" 
              << std::setw(8) << "Size" 
              << std::setw(8) << "Offset" 
              << "Scope Level: " << table_to_print->scope_level << std::endl;
    std::cout << indent << std::string(66, '-') << std::endl;

    // Print all symbols in this table
    for (const auto& [name, symbol] : table_to_print->symbols) {
        if (!symbol) continue;
        std::cout << indent 
                  << std::left << std::setw(20) << symbol->name
                  << std::setw(30) << (symbol->type ? symbol->type->toString() : "N/A")
                  << std::setw(8) << symbol->size
                  << std::setw(8) << symbol->offset
                  << std::endl;

        // CRITICAL FIX: Recursively print nested tables for functions/blocks
        if (symbol->nested_table) {
            std::cout << indent << "Nested scope for " << symbol->name << ":" << std::endl;
            print_symbol_table(symbol->nested_table, level + 1);
        }
    }

    // CRITICAL FIX: After printing all symbols, check for child scopes
    // This handles block scopes not associated with a specific symbol
    if (table_to_print->child_scopes.size() > 0) {
        for (auto* child : table_to_print->child_scopes) {
            std::cout << indent << "Block scope:" << std::endl;
            print_symbol_table(child, level + 1);
        }
    }
    
    if (level == 0) {
        std::cout << "--------------------" << std::endl;
    }
}

// Cleanup function definition
void cleanup_translator() {
    // Perform cleanup related to the translator module
    // Proper cleanup might involve recursively deleting nested tables if they are owned
    delete global_symbol_table; 
    global_symbol_table = nullptr; 
    current_symbol_table = nullptr;
    current_function = nullptr;
    std::cout << "Translator resources cleaned up." << std::endl;
}