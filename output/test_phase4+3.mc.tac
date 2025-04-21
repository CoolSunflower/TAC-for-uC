
--- Generated Three Address Code ---
0   : func_begin main
1   : t0 = 10
2   : a = t0
3   : t1 = 5
4   : b = t1
5   : t2 = 1
6   : x = t2
7   : t3 = 0
8   : y = t3
9   : t4 = 3.140000
10  : f1 = t4
11  : t5 = 2.000000
12  : f2 = t5
13  : t6 = 0
14  : result_simple_if = t6
15  : t7 = 0
16  : result_ifelse1 = t7
17  : t8 = 0
18  : result_ifelse2 = t8
19  : t9 = 0
20  : result_and_shortcircuit = t9
21  : t10 = 0
22  : result_and_noskip = t10
23  : t11 = 0
24  : result_or_shortcircuit = t11
25  : t12 = 0
26  : result_or_noskip = t12
27  : t13 = 0
28  : result_not = t13
29  : t14 = 0
30  : result_nested = t14
31  : t15 = 0
32  : result_dangling = t15
33  : t16 = 0
34  : result_complex = t16
35  : t17 = 0
36  : result_seq1 = t17
37  : t18 = 0
38  : result_seq2 = t18
39  : t19 = 0
40  : side_effect_and = t19
41  : t20 = 0
42  : side_effect_or = t20
43  : if a > b goto 45
44  : goto 48
45  : t21 = 1
46  : result_simple_if = t21
47  : goto 48
48  : if f1 < f2 goto 50
49  : goto 53
50  : t22 = 99
51  : result_simple_if = t22
52  : goto 53
53  : t23 = 10
54  : if a == t23 goto 56
55  : goto 59
56  : t24 = 100
57  : result_ifelse1 = t24
58  : goto 61
59  : t25 = 199
60  : result_ifelse1 = t25
61  : if b >= a goto 63
62  : goto 66
63  : t26 = 299
64  : result_ifelse2 = t26
65  : goto 68
66  : t27 = 200
67  : result_ifelse2 = t27
68  : t28 = 0
69  : side_effect_and = t28
70  : if a < b goto 72
71  : goto 80
72  : t29 = 1
73  : side_effect_and = t29
74  : t30 = 1
75  : if t29 == t30 goto 77
76  : goto 80
77  : t31 = 51
78  : result_and_shortcircuit = t31
79  : goto 80
80  : t32 = 0
81  : side_effect_and = t32
82  : if a > b goto 84
83  : goto 92
84  : t33 = 1
85  : side_effect_and = t33
86  : t34 = 0
87  : if t33 == t34 goto 89
88  : goto 92
89  : t35 = 61
90  : result_and_noskip = t35
91  : goto 92
92  : t36 = 0
93  : side_effect_or = t36
94  : t37 = 10
95  : if a == t37 goto 102
96  : goto 97
97  : t38 = 1
98  : side_effect_or = t38
99  : t39 = 1
100 : if t38 == t39 goto 102
101 : goto 105
102 : t40 = 71
103 : result_or_shortcircuit = t40
104 : goto 105
105 : t41 = 0
106 : side_effect_or = t41
107 : t42 = 10
108 : if a != t42 goto 115
109 : goto 110
110 : t43 = 1
111 : side_effect_or = t43
112 : t44 = 1
113 : if t43 == t44 goto 115
114 : goto 118
115 : t45 = 81
116 : result_or_noskip = t45
117 : goto 118
118 : if a < b goto 123
119 : goto 120
120 : t46 = 91
121 : result_not = t46
122 : goto 123
123 : t47 = 10
124 : if a == t47 goto 126
125 : goto 138
126 : t48 = 5
127 : if b == t48 goto 129
128 : goto 132
129 : t49 = 101
130 : result_nested = t49
131 : goto 134
132 : t50 = 102
133 : result_nested = t50
134 : t51 = 1000
135 : t52 = result_nested + t51
136 : result_nested = t52
137 : goto 138
138 : t53 = 1
139 : if x == t53 goto 141
140 : goto 150
141 : t54 = 1
142 : if y == t54 goto 144
143 : goto 147
144 : t55 = 111
145 : result_dangling = t55
146 : goto 150
147 : t56 = 112
148 : result_dangling = t56
149 : goto 150
150 : if a > b goto 152
151 : goto 155
152 : t57 = 0
153 : if b != t57 goto 157
154 : goto 155
155 : if f1 <= f2 goto 160
156 : goto 157
157 : t58 = 121
158 : result_complex = t58
159 : goto 162
160 : t59 = 122
161 : result_complex = t59
162 : t60 = 1
163 : result_seq1 = t60
164 : t61 = 0
165 : if a < t61 goto 167
166 : goto 170
167 : t62 = 999
168 : result_seq1 = t62
169 : goto 170
170 : t63 = 10
171 : t64 = result_seq1 + t63
172 : result_seq1 = t64
173 : t65 = 100
174 : result_seq2 = t65
175 : t66 = 0
176 : if b > t66 goto 178
177 : goto 182
178 : t67 = 5
179 : t68 = result_seq2 + t67
180 : result_seq2 = t68
181 : goto 184
182 : t69 = 0
183 : result_seq2 = t69
184 : t70 = 1000
185 : t71 = result_seq2 + t70
186 : result_seq2 = t71
187 : func_end main
------------------------------------
