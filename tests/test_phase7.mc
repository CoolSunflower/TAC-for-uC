integer main()
begin
    integer x;
    integer y;
    integer *p;
    integer a[10]; // Declare an integer array
    integer i;     // Index variable

    x = 5;
    p = &x;
    *p = 10; // x = 10
    y = *p;  // y = 10

    // --- Array Tests ---
    i = 2;
    a[i] = 20;      // Assign value to a[2]
    y = a[i];       // Read value from a[2] into y (y should become 20)

    a[0] = x + 5;   // Assign result of expression to a[0] (a[0] = 10 + 5 = 15)
    x = a[0] + a[i]; // Read from array elements (x = 15 + 20 = 35)

    // Test with constant index
    a[5] = 50;
    y = a[5];       // y = 50

    // Return a value to check in TAC
    return x; // Expected TAC: return 35
end