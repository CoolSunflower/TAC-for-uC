integer main() 
begin
    integer x;
    integer y;
    integer *p;
    integer *q;

    x = 5;  // Simple assignment
    p = &x; // Address-of operator

    // Test L-value dereference assignment: *p = value
    *p = 10; // x should become 10

    // Test R-value dereference: y = *p
    y = *p; // y should become 10

    q = &y;
    *q = *p + 5; // y should become 10 + 5 = 15

    // You would typically printeger or return values to verify
    // but microC might not have printeger. We rely on TAC inspection.
    // Example: return x + y; // Expected TAC: return 25 (10 + 15)
    return x; // Expected TAC: return 10
end
