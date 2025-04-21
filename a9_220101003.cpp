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
// --- Modify apply_pending_types ---
void apply_pending_types(TypeInfo* base_type) {
    if (!base_type) {
         std::cerr << "Error: apply_pending_types called with null base_type." << std::endl;
         // Clean up pending symbols to avoid memory leaks?
         for (Symbol* sym : pending_type_symbols) {
             delete sym->type; // Delete any partially built pointer chain
         }
         pending_type_symbols.clear();
         return;
    }

    std::cout << "Debug: Applying base type '" << base_type->toString() << "' to " << pending_type_symbols.size() << " pending symbols." << std::endl;

    for (Symbol* sym : pending_type_symbols) {
        if (!sym) continue;

        TypeInfo* final_type = nullptr;
        TypeInfo* base_type_copy = new TypeInfo(*base_type); // Use a copy for each symbol

        if (sym->type) { // Pointer chain exists (sym->type holds the head from init_declarator)
            TypeInfo* current = sym->type; // Head of pointer chain
            while (current->ptr_type) { // Find the end of the chain
                current = current->ptr_type;
            }
            current->ptr_type = base_type_copy; // Link the base type copy at the end
            final_type = sym->type; // Final type is the head of the chain
            sym->type = nullptr; // Ownership transferred from symbol to final_type temporarily
        } else {
            final_type = base_type_copy; // Just the base type copy, no pointers
        }

        // Handle arrays (applied *after* pointer chain is built)
        if (!sym->pending_dims.empty()) {
            // ... (existing array handling logic - should work correctly with final_type) ...
            // Example:
            int dim = sym->pending_dims[0]; // Assuming 1D for now
            TypeInfo* array_type = new TypeInfo(TYPE_ARRAY, 0);
            array_type->ptr_type = final_type; // Element type is the pointer/base type
            array_type->dims.push_back(dim);
            // Calculate width...
            final_type = array_type; // Symbol's type is now array
        }

        // Assign the final constructed type back to the symbol
        sym->type = final_type;
        sym->size = final_type ? final_type->width : 0; // Update size

        // ... (Optional: Revisit initializer assignment with type checking here) ...

        if (sym->type) {
            std::cout << "Debug: Applied final type '" << sym->type->toString()
                      << "' to pending symbol '" << sym->name << "'" << std::endl;
        } else {
             std::cout << "Warning: Failed to determine final type for symbol '" << sym->name << "'" << std::endl;
        }
    }
    pending_type_symbols.clear(); // Reset for next declaration
    // delete base_type; // NO! Caller (declaration rule) deletes the original base_type.
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
            std::string elem_type = ptr_type ? ptr_type->toString() : "unknown";
            std::string dims_str = "";
            if (!dims.empty()) {
                dims_str = "[";
                for (size_t i = 0; i < dims.size(); ++i) {
                    dims_str += (i > 0 ? "," : "") + std::to_string(dims[i]);
                }
                dims_str += "]";
            }
            return "array<" + elem_type + ">" + dims_str;
        }
        case TYPE_FUNCTION: { 
            std::string ret = return_type ? return_type->toString() : "unknown_ret";
            std::string params = "(";
            for(size_t i = 0; i < param_types.size(); ++i) {
                params += (i > 0 ? ", " : "");
                params += param_types[i] ? param_types[i]->toString() : "unknown_param";
            }
            params += ")";
            return ret + params; // Example: "integer(integer, float)"
        }
        default: return "unknown";
    }
}


// --- Quad Implementation (Modified) ---
std::string opcode_to_string(op_code op) {
    switch(op) {
        // Keep existing cases from paste-5.txt
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
        case OP_INT2FLOAT: return "int2float"; case OP_FLOAT2INT: return "float2int";
        case OP_FUNC_BEGIN: return "func_begin"; case OP_FUNC_END: return "func_end";
        // --- Phase 4: Add strings for new opcodes ---
        case OP_IF_LT: return "if<"; case OP_IF_GT: return "if>";
        case OP_IF_LE: return "if<="; case OP_IF_GE: return "if>=";
        case OP_IF_EQ: return "if=="; case OP_IF_NE: return "if!=";
        // --- End Phase 4 ---
        default: return "op_unknown";
    }
}


std::string Quad::toString() const {
    std::string op_str = opcode_to_string(op);
    std::string res_str = result; // Usually target for jumps
    std::string a1_str = arg1;
    std::string a2_str = arg2;

    // Regular binary/unary assignments (including conversions)
    if (op == OP_ASSIGN){
        return res_str + " = " + a1_str; // Assignment
    }
    // --- Adjusted OP_ASSIGN_DEREF handling ---
    if (op == OP_ASSIGN_DEREF) { // e.g., t = *p
        return res_str + " = * " + a1_str;
    }    
    if ((op >= OP_PLUS && op <= OP_MOD) || (op >= OP_LT && op <= OP_NE) || (op == OP_AND) || (op == OP_OR) ||
        (op == OP_UMINUS) || (op == OP_UPLUS) || (op == OP_NOT) || (op == OP_ADDR) || (op == OP_INT2FLOAT) || (op == OP_FLOAT2INT) )
    {
         // Note: Phase 3 style OP_LT etc. generate assignments, handled here.
         // Phase 4 style OP_IF_LT etc. are handled below.
        if (a2_str.empty()) { // Unary or Assign
            return res_str + " = " + op_str + " " + a1_str;
        } else { // Binary
             return res_str + " = " + a1_str + " " + op_str + " " + a2_str;
        }
    }
    // Gotos
    else if (op == OP_GOTO) {
        return op_str + " " + res_str;
    }
    // Conditional Jumps (Value-based)
    else if (op == OP_IF_FALSE || op == OP_IF_TRUE) {
        return op_str + " " + a1_str + " goto " + res_str;
    }
    // --- Phase 4: Conditional Jumps (Comparison-based) ---
    else if (op >= OP_IF_LT && op <= OP_IF_NE) {
         // Format: if arg1 OP arg2 goto result
         return "if " + a1_str + " " + op_str.substr(2) + " " + a2_str + " goto " + res_str;
    }
    // --- End Phase 4 ---
    // Function related
    else if (op == OP_PARAM) { return op_str + " " + res_str; }
    else if (op == OP_CALL) { return (res_str.empty() ? "" : res_str + " = ") + op_str + " " + a1_str + ", " + a2_str; }
    else if (op == OP_RETURN) { return op_str + (res_str.empty() ? "" : " " + res_str); }
    else if (op == OP_FUNC_BEGIN || op == OP_FUNC_END) { return op_str + " " + res_str; }
    // Pointer/Array
    else if (op == OP_DEREF_ASSIGN) { // e.g., *p = t
        return "* " + res_str + " = " + a1_str;
    }
    else if (op == OP_ARRAY_ACCESS) { return res_str + " = " + a1_str + "[" + a2_str + "]"; }
    else if (op == OP_ARRAY_ASSIGN) { return a1_str + "[" + a2_str + "] = " + res_str; }

    // Fallback (shouldn't normally be reached if all ops handled)
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

Symbol* new_temp(TypeInfo* type) {
    if (!type) { // Cannot create temp without a type
        std::cerr << "Error: Cannot create temporary variable without a type." << std::endl;
        // In a real compiler, might try a default type or throw an exception
        type = new TypeInfo(TYPE_UNKNOWN); // Create a fallback unknown type
    }
    std::string temp_name = "t" + std::to_string(temp_counter++);
    // Important: Create a *copy* of the type for the temporary if the passed type
    // might be deleted later (e.g., if it came from typecheck). If the type
    // is guaranteed to persist (e.g., a global basic type), copying isn't needed.
    // Let's assume for now the caller manages the lifecycle of the passed 'type'.
    Symbol* temp_sym = new Symbol(temp_name, type); // Assign the type directly
    temp_sym->is_temp = true;
    temp_sym->size = type->width; // Set size for the temporary

    if (!current_symbol_table) initialize_symbol_tables();
    current_symbol_table->insert(temp_name, temp_sym); // Add temp to current scope
    return temp_sym;
}

TypeInfo* typecheck(TypeInfo* t1, TypeInfo* t2, op_code op) {
    if (!t1) return nullptr; // First operand must exist for most ops

    // --- Phase 3: Updated numeric checks to include CHAR ---
    bool is_numeric_or_char1 = (t1->base == TYPE_INTEGER || t1->base == TYPE_FLOAT || t1->base == TYPE_CHAR);
    bool is_numeric_or_char2 = t2 && (t2->base == TYPE_INTEGER || t2->base == TYPE_FLOAT || t2->base == TYPE_CHAR);
    // --- End Update ---

    bool is_bool1 = t1->base == TYPE_BOOL;
    // bool is_bool2 = t2 && t2->base == TYPE_BOOL; // For AND/OR

    switch (op) {
        // Binary Arithmetic
        case OP_PLUS: case OP_MINUS: case OP_MULT: case OP_DIV: case OP_MOD:
            // --- Phase 3: Use updated check ---
            if (!is_numeric_or_char1 || (t2 && !is_numeric_or_char2)) { // t2 check needed for binary ops
                std::cerr << "Type Error: Arithmetic operator requires numeric or char operands." << std::endl;
                return nullptr;
            }
            // --- End Update ---

            // Special check for MOD - must be integers (or char treated as int)
            if (op == OP_MOD && (t1->base == TYPE_FLOAT || (t2 && t2->base == TYPE_FLOAT)) ) {
                 std::cerr << "Type Error: '%' operator requires integer/char operands." << std::endl;
                 return nullptr;
            }
            // Promotion rule: If either is float, result is float
            if (t1->base == TYPE_FLOAT || (t2 && t2->base == TYPE_FLOAT))
                return new TypeInfo(TYPE_FLOAT, 8); // Use A9 float size
            else
                return new TypeInfo(TYPE_INTEGER, 4); // Result is int if mixing int/char

        // Relational Operators
        case OP_LT: case OP_GT: case OP_LE: case OP_GE: case OP_EQ: case OP_NE:
        case OP_IF_LT: case OP_IF_GT: case OP_IF_LE: case OP_IF_GE: case OP_IF_EQ: case OP_IF_NE:    
            // --- Phase 3: Use updated check ---
            if (!is_numeric_or_char1 || (t2 && !is_numeric_or_char2)) { // t2 check needed
                std::cerr << "Type Error: Relational operator requires numeric or char operands." << std::endl;
                return nullptr;
            }
             // --- End Update ---
            return new TypeInfo(TYPE_BOOL, 1); // Result is always bool

        // Logical NOT
        case OP_NOT:
            if (!is_bool1 || t2 != nullptr) { // Must be unary, operand must be bool
                 std::cerr << "Type Error: '!' operator requires a boolean operand." << std::endl;
                 return nullptr;
            }
            return new TypeInfo(TYPE_BOOL, 1);

        // Assignment
        case OP_ASSIGN:
            if (!t2) return nullptr;

            if (t2->base == TYPE_BOOL) {
                std::cerr << "Type Error: Cannot assign the result of a boolean expression directly." << std::endl;
                return nullptr;
            }
            // Also ensure LHS isn't bool (though user decl is disallowed, check anyway)
            if (t1->base == TYPE_BOOL) {
                std::cerr << "Type Error: Cannot assign to a variable of explicit boolean type." << std::endl;
                return nullptr;
            }

            // Check compatibility (Allow same type, int/char assigned to float, int to char, char to int?)
            if (t1->base == t2->base) return t1; // Same type
            if (t1->base == TYPE_FLOAT && (t2->base == TYPE_INTEGER || t2->base == TYPE_CHAR)) return t1; // Allow int/char -> float
            // --- Phase 3: Allow char <-> int assignment? Assume yes based on C ---
            if ((t1->base == TYPE_INTEGER && t2->base == TYPE_CHAR) || (t1->base == TYPE_CHAR && t2->base == TYPE_INTEGER)) return t1; // Allow char <-> int
            // --- End Update ---

            std::cerr << "Type Error: Incompatible types for assignment from " << t2->toString() << " to " << t1->toString() << "." << std::endl;
            return nullptr;

        // Unary Minus/Plus
        case OP_UMINUS: case OP_UPLUS:
             // --- Phase 3: Use updated check ---
            if (!is_numeric_or_char1 || t2 != nullptr) { // Must be unary
                std::cerr << "Type Error: Unary +/- requires a numeric or char operand." << std::endl;
                return nullptr;
            }
             // --- End Update ---
            // Result type matches operand (char promotes to int conceptually, but keep original type for now unless needed)
            // If operand is char, treat result as int? Let's return INT if operand is CHAR.
            if(t1->base == TYPE_CHAR) return new TypeInfo(TYPE_INTEGER, 4);
            return t1; // Return original type if int/float

        // Add cases for AND, OR if handling non-short-circuit in Phase 3
        case OP_AND: case OP_OR:
             // Check if operands are bool (or implicitly convertible in C - skip complex C rules for now)
             if(t1->base != TYPE_BOOL || (t2 && t2->base != TYPE_BOOL)) {
                 std::cerr << "Type Error: Logical operator requires boolean operands." << std::endl;
                 return nullptr;
             }
             return new TypeInfo(TYPE_BOOL, 1);


        default:
            std::cerr << "Type Error: Operation " << opcode_to_string(op) << " not type-checked or invalid." << std::endl;
            return nullptr;
    }
}


// --- Phase 3: Implement convert_type ---
Symbol* convert_type(Symbol* s, TypeInfo* target_type) {
    if (!s || !s->type || !target_type) {
        std::cerr << "Error: Cannot perform type conversion with missing type information." << std::endl;
        return s; // Return original if info is missing
    }

    TypeInfo* current_type = s->type;

    // No conversion needed if types are already the same
    if (current_type->base == target_type->base) {
        return s;
    }

    // --- Add explicit check for matching pointer types (redundant if TypeInfo::operator== is correct) ---
    // This helps diagnose if the issue is in the comparison operator vs. convert_type logic
    if (current_type->base == TYPE_POINTER && target_type->base == TYPE_POINTER) {
        // Recursively check pointed-to types if necessary, or assume compatible if base is POINTER
        // For now, let's assume if both are pointers, they are compatible for this phase if typecheck passed.
        // If TypeInfo::operator== is correct, this block might not even be reached.
        std::cout << "Debug: convert_type sees matching pointer base types." << std::endl;
        return s; // Treat as matching
    }
    // --- End explicit pointer check ---

    // Allowed Conversion: Integer -> Float
    if (current_type->base == TYPE_INTEGER && target_type->base == TYPE_FLOAT) {
        std::cout << "Debug: Converting " << s->name << " from integer to float." << std::endl;
        TypeInfo* float_type = new TypeInfo(TYPE_FLOAT, 4); // Create the target type instance
        Symbol* temp = new_temp(float_type); // Create temp with the correct type
        emit(OP_INT2FLOAT, temp->name, s->name);
        return temp;
    }

    // --- ADDED: Allowed Conversion: Float -> Integer ---
    if (current_type->base == TYPE_FLOAT && target_type->base == TYPE_INTEGER) {
        std::cout << "Debug: Converting " << s->name << " from float to integer." << std::endl;
        TypeInfo* int_type = new TypeInfo(TYPE_INTEGER, 4); // Use correct size
        Symbol* temp = new_temp(int_type);
        emit(OP_FLOAT2INT, temp->name, s->name);
        return temp;
    }
    // --- END ADDED ---

    if (current_type->base == TYPE_CHAR && target_type->base == TYPE_INTEGER) {
        // No quad needs to be emitted, char is used as int directly.
        // Return the original symbol.
        std::cout << "Debug: Implicit conversion char->int for " << s->name << std::endl; // Optional Debug
        return s;
    }

    // --- ADDED: Allowed Conversion? Integer -> Char (Truncation/Implicit) ---
    // Often allowed in C, might need OP_INT2CHAR if specific instruction needed
    if (current_type->base == TYPE_INTEGER && target_type->base == TYPE_CHAR) {
        std::cout << "Debug: Implicit conversion int->char for " << s->name << std::endl; // Optional Debug
        // Assuming direct use is okay, like char->int
        return s;
   }
   // --- END ADDED ---

    // --- ADDED: Allowed Conversion? Char -> Float (via Int) ---
    if (current_type->base == TYPE_CHAR && target_type->base == TYPE_FLOAT) {
        std::cout << "Debug: Converting " << s->name << " from char to float (via int)." << std::endl;
        // Treat char as int first, then int to float
        TypeInfo* float_type = new TypeInfo(TYPE_FLOAT, 8);
        Symbol* temp = new_temp(float_type);
        // Assuming OP_INT2FLOAT can handle the char implicitly treated as int
        emit(OP_INT2FLOAT, temp->name, s->name);
        return temp;
    }
    // --- END ADDED ---

    // If no specific conversion rule matches, it's likely a type error
    // The caller (parser action after typecheck) should handle this mismatch.
    // We return the original symbol here, indicating conversion wasn't performed.
    std::cerr << "Warning: No conversion rule found from " << current_type->toString()
              << " to " << target_type->toString() << " for symbol " << s->name << std::endl;
    return s;
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
            quad_list[index].result = target_str;
        } else {
             std::cerr << "Warning: Invalid quad index " << index << " during backpatching." << std::endl;
        }
    }
    list.clear(); // Clear the list after backpatching
}

void print_symbol_table(SymbolTable* table_to_print, int level) {
    /* Already defined correctly in paste-3.txt */
    if (!table_to_print) { table_to_print = global_symbol_table; }
    if (!table_to_print) return;

    std::string indent(level * 4, ' ');
    if (level == 0) { std::cout << "\n--- Symbol Table ---" << std::endl; }

    std::cout << indent << std::left << std::setw(20) << "Name"
              << std::setw(30) << "Type"
              << std::setw(8) << "Size"
              << std::setw(8) << "Offset"
              << "Scope Level: " << table_to_print->scope_level << std::endl;
    std::cout << indent << std::string(76, '-') << std::endl; // Adjusted width

    for (const auto& [name, symbol] : table_to_print->symbols) {
        if (!symbol) continue;
        std::cout << indent
                  << std::left << std::setw(20) << symbol->name
                  << std::setw(30) << (symbol->type ? symbol->type->toString() : "N/A")
                  << std::setw(8) << symbol->size
                  << std::setw(8) << symbol->offset
                  << std::endl;

        // Print nested table if associated *directly* with this symbol (e.g., function)
        if (symbol->nested_table) {
            std::cout << indent << "  Nested scope for '" << symbol->name << "':" << std::endl;
            print_symbol_table(symbol->nested_table, level + 1);
        }
    }
     // Separately iterate through child scopes (blocks not tied to a specific function symbol's nested_table field)
     // Avoid double printing if already printed via symbol->nested_table
    for (auto* child : table_to_print->child_scopes) {
        bool already_printed = false;
        for (const auto& [name, symbol] : table_to_print->symbols) {
             if (symbol && symbol->nested_table == child) {
                 already_printed = true;
                 break;
             }
        }
        if (!already_printed) {
             std::cout << indent << "  Block scope:" << std::endl;
             print_symbol_table(child, level + 1);
        }
    }


    if (level == 0) { std::cout << "--------------------" << std::endl; }
}

// Cleanup function definition
void cleanup_translator() {
    // Need a more robust recursive deletion for symbol tables & symbols
    // Simple delete global_symbol_table might leak nested scopes/symbols
    delete global_symbol_table; // Placeholder - leaks memory
    global_symbol_table = nullptr;
    current_symbol_table = nullptr;
    current_function = nullptr;
    quad_list.clear();
    pending_type_symbols.clear();
    next_quad_index = 0;
    temp_counter = 0;
    std::cout << "Translator resources cleaned up (basic)." << std::endl;
}