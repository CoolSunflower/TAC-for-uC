// Test case for Phase 1: Basic structure and declarations
integer global_var;
float pi; // Another global

integer main() 
begin
    integer local_x;
    char c;
    
    local_x = 10; // Requires expression parsing (Phase 3) - Okay if it parses now
    
    if (local_x > 5) // Requires expression/selection parsing (Phase 3/4)
    begin
        // empty block
    end

    return 0; // Requires expression/return parsing (Phase 3/6)
end

void utility_func(integer param1, float param2)
begin
    // Function body - empty for now
end

// End of test file
