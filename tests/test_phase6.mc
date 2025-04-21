// TEST FILE: test_phase6.mc
// Purpose: Test function definitions and calls

// 1. Simple function with no parameters and void return
void printHello() 
begin
    // Function with no parameters and no return value
end

// 2. Function with integer return type and no parameters
integer getZero() 
begin
    return 0;
end

// 3. Function with integer parameters and return
integer add(integer a, integer b) 
begin
    integer result;
    result = a + b;
    return result;
end

// 4. Function with floating point parameters and return
float average(float x, float y) 
begin
    float sum;
    sum = x + y;
    return sum / 2.0;
end

// 5. Type conversion in parameters and return values
float intToFloat(integer value) 
begin
    // Should implicitly convert the integer to float on return
    return value;
end

// 6. Multiple parameters of different types
integer calculate(integer a, float b, char c) 
begin
    // Convert char to int implicitly
    return a + c;
end

// 7. Function with early return
integer max(integer x, integer y) 
begin
    if (x > y)
        return x;
    return y;
end

// 8. Recursive function (factorial)
integer factorial(integer n) 
begin
    if (n <= 1)
        return 1;
    return n * factorial(n - 1);
end

// 9. Main function with nested function calls
integer main() 
begin
    integer a;
    integer b;
    float f;
    
    // Simple function call with no return value
    printHello();
    
    // Function calls with return values
    a = getZero();
    b = add(10, 20);
    
    // Function calls with different type parameters
    f = average(1.5, 2.5);
    
    // Nested function calls
    a = add(max(5, 3), factorial(4));
    
    // Type conversion in function calls
    f = intToFloat(42);
    
    // Function call with mixed parameter types
    b = calculate(10, 3.14, 'A');
    
    return 0;
end
