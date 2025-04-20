// Test file for Phase 4: Selection Statements and Boolean Logic

integer a, b, x, y, z;
float f1, f2;

// Variables to store results of tests
integer result_simple_if;
integer result_ifelse1;
integer result_ifelse2;
integer result_and_shortcircuit;
integer result_and_noskip;
integer result_or_shortcircuit;
integer result_or_noskip;
integer result_not;
integer result_nested;
integer result_dangling;
integer result_complex;
integer result_seq1;
integer result_seq2;

// Markers for side effects in short-circuit tests
integer side_effect_and;
integer side_effect_or;

integer main()
begin // Start main execution block

    // Initialization
    a = 10;
    b = 5;
    x = 1;
    y = 0;
    f1 = 3.14;
    f2 = 2.0;

    result_simple_if = 0;
    result_ifelse1 = 0;
    result_ifelse2 = 0;
    result_and_shortcircuit = 0;
    result_and_noskip = 0;
    result_or_shortcircuit = 0;
    result_or_noskip = 0;
    result_not = 0;
    result_nested = 0;
    result_dangling = 0;
    result_complex = 0;
    result_seq1 = 0;
    result_seq2 = 0;
    side_effect_and = 0;
    side_effect_or = 0;

    // --- Test 1: Simple IF (Condition True) ---
    if (a > b) // 10 > 5 is true
    begin
        result_simple_if = 1;
    end
    // Expected Quad Flow: if a > b goto L_THEN, goto L_AFTER, L_THEN: result=1, L_AFTER: ...
    // Expected result_simple_if = 1

    // --- Test 2: Simple IF (Condition False) ---
    if (f1 < f2) // 3.14 < 2.0 is false
    begin
        result_simple_if = 99; // This block should be skipped
    end
    // Expected Quad Flow: if f1 < f2 goto L_THEN, goto L_AFTER, L_THEN: result=99, L_AFTER: ...
    //                      (Control should take the goto L_AFTER path)
    // Expected result_simple_if = 1 (unmodified from Test 1)

    // --- Test 3: IF-ELSE (True Path) ---
    if (a == 10) // true
    begin
        result_ifelse1 = 100; // Execute this
    end
    else
    begin
        result_ifelse1 = 199; // Skip this
    end
    // Expected Quad Flow: if a == 10 goto L_THEN, goto L_ELSE, L_THEN: result=100, goto L_AFTER, L_ELSE: result=199, L_AFTER: ...
    // Expected result_ifelse1 = 100

    // --- Test 4: IF-ELSE (False Path) ---
    if (b >= a) // 5 >= 10 is false
    begin
        result_ifelse2 = 299; // Skip this
    end
    else
    begin
        result_ifelse2 = 200; // Execute this
    end
    // Expected Quad Flow: if b >= a goto L_THEN, goto L_ELSE, L_THEN: result=299, goto L_AFTER, L_ELSE: result=200, L_AFTER: ...
    // Expected result_ifelse2 = 200

    // --- Test 5: Logical AND Short-circuit (False && ...) ---
    side_effect_and = 0;
    if (a < b && (side_effect_and = 1) == 1) // First part (10 < 5) is false, should short-circuit
    begin
        result_and_shortcircuit = 51;
    end
    // Expected Quad Flow: Evaluate a < b. Generates false list jump. Jumps over evaluation of second part.
    // Expected result_and_shortcircuit = 0 AND side_effect_and = 0

    // --- Test 6: Logical AND No Short-circuit (True && False) ---
    side_effect_and = 0;
    if (a > b && (side_effect_and = 1) == 0) // First part true (10 > 5), Second part false (1 == 0). Evaluate both.
    begin
        result_and_noskip = 61;
    end
    // Expected Quad Flow: Evaluate a > b. True list jumps to second part. Evaluate second part. False list jumps after IF.
    // Expected result_and_noskip = 0 AND side_effect_and = 1

    // --- Test 7: Logical OR Short-circuit (True || ...) ---
    side_effect_or = 0;
    if (a == 10 || (side_effect_or = 1) == 1) // First part true (10 == 10), should short-circuit
    begin
        result_or_shortcircuit = 71;
    end
    // Expected Quad Flow: Evaluate a == 10. Generates true list jump. Jumps directly to THEN block.
    // Expected result_or_shortcircuit = 71 AND side_effect_or = 0

    // --- Test 8: Logical OR No Short-circuit (False || True) ---
    side_effect_or = 0;
    if (a != 10 || (side_effect_or = 1) == 1) // First part false (10 != 10), Second part true (1 == 1). Evaluate both.
    begin
        result_or_noskip = 81;
    end
    // Expected Quad Flow: Evaluate a != 10. False list jumps to second part. Evaluate second part. True list jumps to THEN block.
    // Expected result_or_noskip = 81 AND side_effect_or = 1

    // --- Test 9: Logical NOT ---
    if (!(a < b)) // !(10 < 5) -> !false -> true
    begin
        result_not = 91;
    end
    // Expected Quad Flow: Evaluate a < b. Swap true/false lists. True list (original false) jumps to THEN.
    // Expected result_not = 91

    // --- Test 10: Nested IF Statements ---
    if (a == 10) // True
    begin
        if (b == 5) // True
        begin
            result_nested = 101;
        end
        else
        begin
            result_nested = 102;
        end
        // After inner if-else
        result_nested = result_nested + 1000;
    end
    // Expected result_nested = 101 + 1000 = 1101

    // --- Test 11: Dangling Else ---
    // The 'else' should associate with the inner 'if(y==1)'
    if (x == 1)     // True
      if (y == 1)   // False (y=0)
         result_dangling = 111; // Skip
      else
         result_dangling = 112; // Execute
    // Expected result_dangling = 112

    // --- Test 12: Complex Condition ---
    if ((a > b && b != 0) || !(f1 <= f2)) // (T && T) || !(F) -> T || T -> T
    begin
        result_complex = 121;
    end
    else
    begin
        result_complex = 122;
    end
    // Expected result_complex = 121

    // --- Test 13: Statement Sequencing 1 ---
    result_seq1 = 1;
    if (a < 0) // False
        result_seq1 = 999; // Skipped
    // This statement MUST execute after the IF block structure
    result_seq1 = result_seq1 + 10;
    // Expected result_seq1 = 1 + 10 = 11

    // --- Test 14: Statement Sequencing 2 ---
    result_seq2 = 100;
    if (b > 0) // True
    begin
        result_seq2 = result_seq2 + 5; // result_seq2 = 105
    end
    else
    begin
        result_seq2 = 0; // Skipped
    end
    // This statement MUST execute after the IF-ELSE block structure
    result_seq2 = result_seq2 + 1000;
    // Expected result_seq2 = 105 + 1000 = 1105


    // Final check print (useful if you had print functionality)
    // print a; print b; ... print result_simple_if; ...


end // End main execution block
