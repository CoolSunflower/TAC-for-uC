
--- Generated Three Address Code ---
0   : func_begin printHello
1   : func_end printHello
2   : func_begin getZero
3   : t0 = 0
4   : return t0
5   : func_end getZero
6   : func_begin add
7   : t1 = a + b
8   : result = t1
9   : return result
10  : func_end add
11  : func_begin average
12  : t2 = x + y
13  : sum = t2
14  : t3 = 2.000000
15  : t4 = sum / t3
16  : return t4
17  : func_end average
18  : func_begin intToFloat
19  : t5 = int2float value
20  : return t5
21  : func_end intToFloat
22  : func_begin calculate
23  : t6 = a + c
24  : return t6
25  : func_end calculate
26  : func_begin max
27  : if x > y goto 29
28  : goto 31
29  : return x
30  : goto 31
31  : return y
32  : func_end max
33  : func_begin factorial
34  : t7 = 1
35  : if n <= t7 goto 37
36  : goto 40
37  : t8 = 1
38  : return t8
39  : goto 40
40  : t9 = 1
41  : t10 = n - t9
42  : param t10
43  : t11 = call factorial, 1
44  : t12 = n * t11
45  : return t12
46  : func_end factorial
47  : func_begin main
48  : call printHello, 0
49  : t13 = call getZero, 0
50  : a = t13
51  : t14 = 10
52  : t15 = 20
53  : param t14
54  : param t15
55  : t16 = call add, 2
56  : b = t16
57  : t17 = 1.500000
58  : t18 = 2.500000
59  : param t17
60  : param t18
61  : t19 = call average, 2
62  : f = t19
63  : t20 = 5
64  : t21 = 3
65  : param t20
66  : param t21
67  : t22 = call max, 2
68  : t23 = 4
69  : param t23
70  : t24 = call factorial, 1
71  : param t22
72  : param t24
73  : t25 = call add, 2
74  : a = t25
75  : t26 = 42
76  : param t26
77  : t27 = call intToFloat, 1
78  : f = t27
79  : t28 = 10
80  : t29 = 3.140000
81  : t30 = 65
82  : param t28
83  : param t29
84  : param t30
85  : t31 = call calculate, 3
86  : b = t31
87  : t32 = 0
88  : return t32
89  : func_end main
------------------------------------
