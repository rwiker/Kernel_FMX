10 REM Turn on graphics with sprites and text overlay
20 POKE $AF0000,PEEK($AF0000) OR $2E
30 REM Make a gradient
40 FOR V=0 TO 31:FOR U=0 TO 31
50 POKE $B10000 + V * 32 + U,V
60 NEXT:NEXT
70 REM Turn on sprite #1
80 POKE $AF0200,1
90 REM Set address of sprite #1
100 POKEW $AF0201,0:POKE $AF0203,1
110 REM Set (X, Y) of sprite #1
120 POKEW $AF0204,100:POKEW $AF0206,100
130 REM Set gradient colors... blue to green
140 FOR C = 1 to 31:BLUE = $AF2400 + C*4
150 POKE BLUE, 255 - C*8:REM Set blue
160 POKE BLUE + 1, C*8:REM Set green
170 POKE BLUE + 2, 0:REM Set red
180 POKE BLUE + 3, $FF:REM Set alpha
190 NEXT


10 POKE $AF0000,PEEK($AF0000) OR $2E
20 FOR V=0 TO 31:FOR U=0 TO 31
30 POKE $B10000 + V * 32 + U,V
40 NEXT:NEXT
50 POKE $AF0200,1
60 POKEW $AF0201,0:POKE $AF0203,1
70 POKEW $AF0204,100:POKEW $AF0206,100
80 FOR C = 1 to 31:BLUE = $AF2400 + C*4
90 POKE BLUE, 255 - C*8
100 POKE BLUE + 1, C*8
110 POKE BLUE + 2, 0
120 POKE BLUE + 3, $FF
130 NEXT
