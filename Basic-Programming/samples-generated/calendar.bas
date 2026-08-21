// ============================================================
// CALENDAR — Print a monthly calendar on the CE-150 plotter
// (European Style: Monday is the first day of the week)
//
// Variables:
//   D$  = Input date string (yyyy-mm-dd)
//   Y   = Year (numeric)
//   M   = Month (numeric)
//   D   = Target day (numeric)
//   L   = Leap year flag (1=yes)
//   N   = Number of days in month
//   Q   = Calculation day (fixed to 1)
//   M2  = Adjusted month for Zeller calculation
//   Y2  = Adjusted year for Zeller calculation
//   K   = Year of century (0-99)
//   J   = Century (year/100)
//   H   = Zeller result (0=Sat, 1=Sun, ..., 6=Fri)
//   S   = Start column index (0=Mon, ..., 6=Sun)
//   I   = Main loop counter for days (1 to N)
//   C   = Current column counter (0-6)
//   P   = Pen column position for LCURSOR
//   Z   = Currently active pen color (0-3)
//   M$  = Array of month names
// ============================================================
10 REM CALENDAR (C) Martin Erzberger, 2026
// 1. Initialisation
// Dimension string array for month names
20 "C" CLEAR : DIM M$(12) * 9
// Populate month names from DATA
30 RESTORE "MONTHS" : FOR I = 1 TO 12 : READ M$(I) : NEXT I
// 2. User Input
// Prompt for date in ISO format
40 "ASK" INPUT "Date (yyyy-mm-dd)? "; D$
// Basic length check
50 IF LEN (D$) <> 10 THEN GOTO "ASK"
// Parse components
60 Y = VAL (LEFT$ (D$, 4)) : M = VAL (MID$ (D$, 6, 2)) : D = VAL (RIGHT$ (D$, 2))
// Validate month range
70 IF M < 1 OR M > 12 THEN GOTO "ASK"
// 3. Date Calculations
// Leap year logic for Gregorian calendar
80 L = 0 : IF (Y - INT (Y / 4) * 4) = 0 THEN LET L = 1
90 IF (Y - INT (Y / 100) * 100) = 0 THEN LET L = 0
100 IF (Y - INT (Y / 400) * 400) = 0 THEN LET L = 1
// Number of days in chosen month
110 RESTORE "DAYS" : FOR I = 1 TO M : READ N : NEXT I
120 IF M = 2 AND L = 1 THEN LET N = 29
// Validate target day exists in that month
130 IF D < 1 OR D > N THEN GOTO "ASK"
// Zeller's Congruence to find the weekday of the 1st
140 Q = 1 : M2 = M : Y2 = Y
// Adjustments for January and February
150 IF M2 < 3 THEN LET M2 = M2 + 12 : Y2 = Y2 - 1
160 K = Y2 - INT (Y2 / 100) * 100 : J = INT (Y2 / 100)
170 H = (Q + INT (13 * (M2 + 1) / 5) + K + INT (K / 4) + INT (J / 4) - 2 * J)
// Modulo 7 with handling for negative results
180 H = H - INT (H / 7) * 7 : IF H < 0 THEN LET H = H + 7
// Convert Zeller H (0=Sat, 1=Sun, 2=Mon...) to S (0=Mon, ..., 5=Sat, 6=Sun)
190 S = H - 2 : IF S < 0 THEN LET S = S + 7
// 4. Printer Output Setup
// TEXT mode; Black (Z=0), size 2 for header
200 TEXT : COLOR 0 : CSIZE 2 : Z = 0
210 LPRINT M$(M); " "; STR$ (Y)
// Column headers in size 1 (European: Mon-Sun)
220 COLOR 0 : CSIZE 1 : Z = 0
230 LPRINT " Mon Tue Wed Thu Fri Sat Sun"
// 5. Calendar Grid Generation
240 C = S : FOR I = 1 TO N
// Calculate horizontal offset
250 P = C * 4 + 2
// Color logic: Weekends (Sat=5, Sun=6) Red (3); Target Green (2); Black (0)
260 K = 0 : IF C > 4 THEN LET K = 3
270 IF I = D THEN LET K = 2
// Optimize mechanical wear
280 IF K <> Z THEN COLOR K : Z = K
// Position pen and print day right-aligned
290 LCURSOR P : LPRINT RIGHT$ (" " + STR$ (I), 2);
// Advance column counter; wrap after Sun (6)
300 C = C + 1 : IF C < 7 THEN GOTO "NEXTD"
310 LPRINT : C = 0
320 "NEXTD" NEXT I
// 6. Finalisation
330 IF C <> 0 THEN LPRINT
340 IF Z <> 0 THEN COLOR 0 : Z = 0
350 LPRINT : LPRINT : WAIT : END
// 7. Data Storage
360 "MONTHS" DATA "January", "February", "March", "April", "May", "June"
370 DATA "July", "August", "September", "October", "November", "December"
380 "DAYS" DATA 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
9999 END
