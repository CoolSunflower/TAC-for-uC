/* 
 * a9_test_phase3.mc
 * Test file for Phase 3: Expression TAC Generation
 */

integer g_int1, g_int2, g_int_res;
float g_float1, g_float2, g_float_res; /* A9 Spec: float is 8 bytes */
char g_char1, g_char_res;
bool g_bool1, g_bool2, g_bool_res;

void main()
begin
    integer l_int1, l_int2, l_int_res;
    float l_float1, l_float2, l_float_res;
    char l_char1;
    bool l_bool1, l_bool2, l_bool_res;

    /* 1. Constants and Basic Assignment */
    l_int1 = 10;          /* TAC: tX = 10; l_int1 = tX */
    g_int1 = -5;          /* TAC: tX = 5; tY = uminus tX; g_int1 = tY */
    l_float1 = 123.45;    /* TAC: tX = 123.45; l_float1 = tX */
    g_float1 = -0.5;      /* TAC: tX = 0.5; tY = uminus tX; g_float1 = tY */
    l_char1 = 'A';        /* TAC: tX = 65; l_char1 = tX (assuming ASCII) */
    g_bool1 = (10 < 20);  // Assign the result of a comparison (which is internally 1)
    l_bool1 = (5 == 9);   // Assign the result of a comparison (which is internally 0)
    
    /* 2. Arithmetic Operations */
    l_int2 = l_int1 + 20;             /* TAC: tX = l_int1 + 20; l_int2 = tX */
    g_int2 = g_int1 * l_int2;         /* TAC: tX = g_int1 * l_int2; g_int2 = tX */
    l_int_res = (l_int1 + l_int2) / 3;/* TAC: tA=l_int1+l_int2; tB=tA/3; l_int_res=tB */
    g_int_res = l_int2 % 7;           /* TAC: tX = l_int2 % 7; g_int_res = tX */

    l_float2 = l_float1 * 2.0;            /* TAC: tX=l_float1 * 2.0; l_float2=tX */
    g_float2 = g_float1 + l_float2;       /* TAC: tX = g_float1 + l_float2; g_float2 = tX */
    l_float_res = (g_float2 - l_float1) / g_float1; /* TAC: tA=g_float2-l_float1; tB=tA/g_float1; l_float_res=tB */

    /* 3. Mixed Type Arithmetic & Conversions */
    l_float_res = l_int1 + l_float1;   /* TAC: tA=int2float l_int1; tB=tA+l_float1; l_float_res=tB */
    g_float_res = l_float2 * g_int1;   /* TAC: tA=int2float g_int1; tB=l_float2*tA; g_float_res=tB */
    l_int_res = l_int2 + l_char1;      /* TAC: tA=char2int l_char1(opt); tB=l_int2+tA; l_int_res=tB */

    /* Implicit conversion on assignment (if implemented) */
    g_float_res = l_int1;              /* TAC: tX=int2float l_int1; g_float_res=tX */
    /* g_int_res = l_float1; */        /* TAC: tX=float2int l_float1; g_int_res=tX (if supported) - Comment out if not */

    /* 4. Unary Operations */
    l_int_res = -l_int2;               /* TAC: tX = uminus l_int2; l_int_res = tX */
    l_float_res = +l_float1;           /* TAC: tX = uplus l_float1; l_float_res = tX (or just copy) */
    l_bool_res = !g_bool1;             /* TAC: tX = ! g_bool1; l_bool_res = tX */
    l_bool_res = !(l_int1 == 10);      /* TAC: tA = l_int1 == 10; tB = ! tA; l_bool_res = tB */

    /* 5. Relational Operators */
    l_bool1 = l_int1 < l_int2;         /* TAC: tX = l_int1 < l_int2; l_bool1 = tX */
    l_bool2 = g_float1 >= l_float2;    /* TAC: tX = g_float1 >= l_float2; l_bool2 = tX */
    g_bool_res = (l_int1 * 2) == (l_int2 - 0); /* TAC: tA=l_int1*2; tB=l_int2-0; tC=tA==tB; g_bool_res=tC */
    l_bool_res = l_float1 != g_float2; /* TAC: tX = l_float1 != g_float2; l_bool_res = tX */
    l_bool_res = l_int1 <= g_float1;   /* TAC: tA=int2float l_int1; tB=tA<=g_float1; l_bool_res=tB */

    /* 6. Logical Operators (Phase 3: Non-short-circuit) */
    l_bool_res = l_bool1 && l_bool2;   /* TAC: tX = l_bool1 && l_bool2; l_bool_res = tX */
    g_bool_res = g_bool1 || l_bool_res;/* TAC: tX = g_bool1 || l_bool_res; g_bool_res = tX */
    g_bool_res = (l_int1 > 0) && (l_float1 < 100.0); /* TAC: tA=l_int1>0; tB=l_float1<100.0; tC=tA&&tB; g_bool_res=tC */

    /* 7. Precedence Test */
    /* Expected order: unary -, *, +, <, && */
    l_bool_res = -l_int1 + l_int2 * 3 < 100 && l_bool1;
    /* TAC:
       tA = uminus l_int1
       tB = l_int2 * 3
       tC = tA + tB
       tD = tC < 100
       tE = tD && l_bool1
       l_bool_res = tE
    */

    /* 8. Assignment Chain / Use of Assignment Result */
    l_int1 = l_int2 = 50;               /* TAC: tX=50; l_int2=tX; l_int1=l_int2 (or l_int1=tX) */
    l_int_res = (g_int1 = g_int2 + 1);  /* TAC: tA=g_int2+1; g_int1=tA; l_int_res=g_int1 (or l_int_res=tA) */

end