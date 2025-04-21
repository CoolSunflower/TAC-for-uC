
--- Generated Three Address Code ---
0   : func_begin main
1   : t0 = 0
2   : sum = t0
3   : t1 = 0
4   : i = t1
5   : t2 = 0
6   : i = t2
7   : t3 = 10
8   : if i < t3 goto 14
9   : goto 17
10  : t4 = 1
11  : t5 = i + t4
12  : i = t5
13  : goto 7
14  : t6 = sum + i
15  : sum = t6
16  : goto 10
17  : t7 = 10
18  : a = t7
19  : t8 = 5
20  : b = t8
21  : if a > b goto 23
22  : goto 26
23  : t9 = 1
24  : result_simple_if = t9
25  : goto 26
26  : t10 = 10
27  : if a == t10 goto 29
28  : goto 32
29  : t11 = 100
30  : result_ifelse1 = t11
31  : goto 34
32  : t12 = 199
33  : result_ifelse1 = t12
34  : t13 = 2
35  : t14 = 2
36  : t15 = t13 + t14
37  : x = t15
38  : func_end main
------------------------------------
