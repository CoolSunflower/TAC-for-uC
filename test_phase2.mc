/* test_phase2.mc - Test for declaration processing and symbol table management */

/* Global declarations of various types */
integer globalInt;
float globalFloat;
char globalChar;
bool globalBool;
integer globalArray[10];

/* Multiple declarations in one statement */
integer var1 = 3, var2, var3 = 4;

/* Function with parameters and local variables */
integer testFunction(integer param1, float param2)
begin
    /* Local variables at function scope */
    integer localInt;
    float localFloat;
    char localChar;
    
    /* Arrays with different sizes */
    integer intArray[5];
    char charArray[20];
    
    /* Nested block with shadowing */
    begin
        /* Redeclaring variables in nested scope (valid) */
        integer localInt;    /* Valid - different scope from function's localInt */
        float localFloat;    /* Valid - different scope */
        
        /* More nested blocks to test deeper scoping */
        begin
            integer deepInt;
            char deepChar;
        end
    end
    
    /* Another block with its own variables */
    begin
        integer blockVar;
        float blockArray[3];
    end
end

/* Another function to test function scope isolation */
void anotherFunction()
begin
    /* These should be independent from testFunction's variables */
    integer localInt;
    integer intArray[10];  /* Different size from testFunction's intArray */
end

/* Test for const variables (if supported) */
/* const integer constInt; */

/* Main function for overall structure */
integer main()
begin
    integer x;
    
    /* This next line should generate a redeclaration error */
    /* integer x; */
    
    /* This is okay - different scope */
    begin
        integer x;
        float y;
    end
    
    /* Valid - x is in a different block above */
    integer y;
    
    /* Test array declarations */
    integer smallArray[1];
    integer mediumArray[50];
    char stringBuffer[100];
    
    /* Test zero/negative array size (should generate errors) */
    /* integer badArray1[0]; */
    /* integer badArray2[-5]; */
end
