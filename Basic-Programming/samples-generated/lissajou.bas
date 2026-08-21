// ============================================================
// LISSAJOU — plot a Lissajous figure with progress report
//
// Variables:
//   A  = X amplitude (coordinate units, up to 108)
//   B  = Y amplitude (coordinate units)
//   F  = X frequency (FA)
//   G  = Y frequency (FB)
//   D  = Phase shift (radians)
//   I  = Integer loop counter (0-100)
//   T  = Derived time/angle (I * PI / 50)
//   P  = Current progress percentage (0-100)
//   L  = Last printed progress to avoid repeats
//   X  = Computed X coordinate
//   Y  = Computed Y coordinate
// ============================================================
10 REM LISSAJOU (C) Martin Erzberger, 2026
// entry point: DEF L starts the program
20 "L" CLEAR : WAIT 0
// 1. Printer Title (Black)
// Mixed-case titles for better aesthetics
30 LCURSOR 0 : COLOR 0 : CSIZE 2
40 LPRINT "Lissajous Figure"
// 2. Setup Plotter (Red)
50 COLOR 3 : GRAPH : GLCURSOR (108, -120) : SORGN
// Initialise parameters (A=100 utilizes full paper width)
60 A = 100 : B = 100 : F = 3 : G = 2 : D = PI / 2 : L = -5
// 3. Plotting Loop
70 FOR I = 0 TO 100
80 T = I * PI / 50
90 X = A * SIN (F * T + D)
100 Y = B * SIN (G * T)
// Draw or move pen
110 IF I = 0 THEN GLCURSOR (X, Y) : GOTO "SKIP"
120 LINE -(X, Y)
130 "SKIP" P = I
// 4. Progress Report (LCD)
// Mixed-case status for better readability
140 IF P >= L + 5 THEN PRINT "Progress: "; P; "%" : L = P
150 NEXT I
// 5. Cleanup
160 GLCURSOR (0, -120)
170 TEXT : PRINT "Complete"
180 WAIT : END
