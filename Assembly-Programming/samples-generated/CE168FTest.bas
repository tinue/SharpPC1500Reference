10 REMTest all 8 banks of the CE-163F module. Firmware 1.5!
11 REMNot generated, this was hand written
15 WAIT:PRINT "BREAK, or banks get zeroed!"
20 FOR I = 0 TO 7
30 WAIT 20: PRINT "Testing Page "; PEEK &E2
40 X=1: CALL &7C01,X
50 IF X <> 0 GOTO "ERROR"
60 X=I+1 : IF X < 8 CALL &C6,X : REMCopy to next bank, but not to flash
70 X=I+1 : CALL &E3,X: REMBank switch
70 NEXT I
80 X=0 : CALL &E3,X: REMGo back to bank 0
90 END
100 "ERROR": PRINT "Bank ";I;" is faulty"