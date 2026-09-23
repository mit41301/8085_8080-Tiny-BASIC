;**************************************
;*
;* T B I
;* TINY BASIC INTERPRETER
;* VERSION 3.0
;* FOR 8080 SYSTEM
;* LI-CHEN WANG
;* 26 APRIL, 1977
;*
;* Paper copy of source code converted to this file
;* for Oshonsoft Assembler
;* and verified against paper copy of object file
;* by Lyndon Schultz 13 August 2024
;*
;**************************************
;*
;* *** MEMORY USAGE ***
;*
;* 0080-01FF ARE FOR FOR VARIABLES, INPUT LINE, AND STACK
;* 2000-3FFF ARE FOR TINY BASIC TEXT & ARRAY
;* F000-F7FF ARE FOR TBI CODE
;*
BOTSCR EQU 0080H     ; BOTTOM OF SCATCHPAD
TOPSCR EQU 0200H     ; TOP OF SCATCHPAD
BOTRAM EQU 2000H     ; BOTTOM OF RAM
DFTLMT EQU 4000H
BOTROM EQU F000H     ; BOTTOM OF ROM
CR     EQU 0DH
LF     EQU 0AH
;*
;* DEFINE VARIABLES. BUFFER, AND STACK IN RAM
;*
       ORG BOTSCR
KEYWRD DS 1       ; WAS INIT DONE?
TXTLMT DS 2       ; ->LIMIT OF TEXT AREA
VARBGN DS 2*26    ; TB VARIABLES A-Z
CURRNT DS 2       ; POINTS TO CURRENT LINE
STKGOS DS 2       ; SAVES SP IN 'G0SUB'
VARNXT DS 0       ; TEMP STORAGE
STKINP DS 2       ; SAVES SP IN 'INPUT'
LOPVAR DS 2       ; 'FOR* LOOP SAVE AREA
LOPINC DS 2       ; INCREMENT
LOPLMT DS 2       ; LIMIT
LOPLN  DS 2       ; LINE NUMBER
LOPPT  DS 2       ; TEXT POINTER
RANPNT DS 2       ; RANDOM NUMBER POINTER
       DS 1       ; EXTRA BYTE FOR BUFFER
BUFFER DS 132     ; INPUT BUFFER
BUFEND DS 0       ; BUFFER ENDS
       DS 4       ; EXTRA BYTES FOR STACK
STKLMT DS 0       ; SOFT LIMIT FOR STACK
       ORG TOPSCR
STACK  DS 0       ; STACK STARTS HERE
       ORG BOTRAM
TXTUNF DS 2
TEXT   DS 2
;*
;**************************************
;*
;* *** INITIALIZE ***
;*
      ORG BOTROM
INIT  LXI  SP,STACK
      CALL CRLF
      LXI  H,KEYWRD     ; AT POWER ON KEYWRD IS
      MVI  A,C3H        ; PROBABLY NOT C3
      CMP  M
      JZ   TELL         ; IT IS C3, CONTINUE
      MOV  M,A          ; NO, SET IT TO C3
      LXI  H,DFTLMT     ; AND SET DEFAULT VALUE
      SHLD TXTLMT       ; IN 'TXTLMT'
      MVI  A,HIGH BOTROM ; INITIALIZE RANPNT
      STA  RANPNT +1
PURGE LXI  H,TEXT+4     ; PURGE TEXT AREA
      SHLD TXTUNF
      MVI  H,FFH
      SHLD TEXT
TELL  LXI  D,MSG        ; TELL USER
      CALL PRTSTG       ; ***********************
      JMP  RSTART       ; **** JMP USER-INIT ****
MSG   DB  "TINY "       ; ***********************
      DB  "BASIC V3.0"
      DB  CR
OK    DB  "OK"
      DB  CR
WHAT  DB  "WHAT?"
      DB  CR
HOW   DB  "HOW?"
      DB  CR
SORRY DB  "SORRY"
      DB  CR
;*
;**************************************
;*
;* *** DIRECT COMMAND / TEXT COLLECTER ***
;*
;* TBI PRINTS OUT "OK(CR)", AND THEN IT PROMPTS ">" AND READS A LINE.
;* IF THE LINE STARTS WITH A NON-ZERO NUMBER. THIS NUMBER IS THE LINE
;* NUMBER. THE LINE NUMBER (IN 16 BIT BINARY) AND THE REST OF THE LINE
;* (INCLUDING CR) IS STORED IN THE MEMORY. IF A LINE WITH THE SAME
;* LINE NUMBER IS ALREADY THERE, IT IS REPLACED BY THE NEW ONE. IF THE
;* REST OF THE LINE CONSISTS OF A CR ONLY, IT IS NOT STORED AND ANY
;* EXISTING LINE WITH THE SAME LINE NUMBER IS DELETED.
;* AFTER A LINE INSERTED, REPLACED, OR DELETED, THE PROGRAM LOOPS
;* BACK AND ASKS FOR ANOTHER LINE. THIS LOOP WILL BE TERMINATED WHEN IT
;* READS A LINE WITH ZERO OR NO LINE NUM8ER; AND CONTROL IS TRANSFERED
;* TO "DIRECT".
;* TINY BASIC PROGRAM SAVE AREA STARTS AT THE MEMORY LOCATION LABELED
;* "TEXT". THE END OF TEXT IS MARKED BY 2 BYTES XX FF. FOLLOWING
;* THESE ARE 2 BYTES RESERVED FOR THE ARRAY ELEMENT @(0). THE CONTENT
;* OF LOCATION LABELED "TXTUNF" POINTS TO ONE AFTER @(0).
;* THE MEMORY LOCATION "CURRNT" POINTS TO THE LINE NUMBER THAT IS
;* CURRENTLY BEING INTERPRETED. WHILE WE ARE IN THIS LOOP OR WHILE WE
;* ARE INTERPRETING A DIRECT COMMAND (SEE NEXT SECTION). "CURRNT"
;* SHOULD POINT TO A0.
;*
RSTART LXI  SP,STACK    ; RE-INITIALIZE STACK
       LXI  H,ST1 + 1   ; LITERAL 0
       SHLD CURRNT      ; CURRNT->LINE NUMBER = 0
ST1    LXI  H,0
       SHLD LOPVAR
       SHLD STKGOS
       LXI  D,OK        ; DE—> STRING
       CALL PRTSTG      ; PRINT STRING UNTIL CR
ST2    MVI  A,">"       ; PROMPT '>' AND
       CALL GETLN       ; READ A LINE
       PUSH D           ; DE—>END OF LINE
       LXI  D,BUFFER    ; DE->BEGINNING OF LINE
       CALL TSTNUM      ; TEST IF IT IS A NUMBER
       CALL IGNBLK
       MOV  A,H         ; HL = VALUE OF THE LINE NUMBER OR
       ORA  L           ; 0 IF NO LINE NUMBER WAS FOUND
       POP  B           ; BC—>END OF LINE
       JZ   DIRECT
       DCX  D           ; BACKUP DE AND SAVE
       MOV  A,H         ; VALUE OF LINE NUMBER THERE
       STAX D
       DCX  D
       MOV  A,L
       STAX D
       PUSH B           ; BC.DE—>BEGIN. END
       PUSH D
       MOV  A,C
       SUB  E
       PUSH PSW         ; A = NUMBER OF BYTES IN LINE
       CALL FNDLN       ; FIND THIS LINE IN SAVE
       PUSH D           ; AREA. DE->SAVE AREA
       JNZ  ST3         ; NZ:NOT FOUND. INSERT
       PUSH D           ; Z:FOUND. DELETE IT
       CALL FNDNXT      ; SET DE->NEXT LINE
ST3    POP  B           ; BC—>LINE TO BE DELETED
       LHLD TXTUNF      ; HL->UNFILLED SAVE AREA
       CALL MVUP        ; MOVE UP TO DELETE
       MOV  H,B         ; TXTUNF->UNFILLED AREA
       MOV  L,C
       SHLD TXTUNF      ; UPDATE
       POP  B           ; GET READY TO INSERT
       LHLD TXTUNF      ; BUT FIRST CHECK IF
       POP  PSW         ; THE LENGTH OF NEW LINE
       PUSH H           ; IS 3 (LINE NUMBER AND CR)
       CPI  3           ; THEN DO NOT INSERT
       JZ   RSTART      ; MUST CLEAR THE STACK
       ADD  L           ; COMPUTE NEW TXTUNF
       MOV  E,A
       MVI  A, 0
       ADC  H
       MOV  D,A         ; DE—> NEW UNFILLED AREA
       LHLD TXTLMT      ; CHECK TO SEE IF THERE
       XCHG
       CALL COMP        ; IS ENOUGH SPACE
       JNC  QSORRY      ; SORRY. NO ROOM FOR IT
       SHLD TXTUNF      ; OK, UPDATE TXTUNF
       POP  D           ; DE—>OLD UNFILLED AREA
       CALL MVDOWN
       POP  D           ; DE—>BEGIN. HL—>END
       POP  H
       CALL MVUP        ; MOVE NEW LINE TO SAVE
       JMP  ST2         ; AREA
;*
;**************************************
;*
;* *** DIRECT *** & EXEC ***
;*
;* THIS SECTION OF THE CODE TESTS A STRING AGAINST A TABLE. WHEN A
;* MATCH IS FOUND, CONTROL IS TRANSFERED TO THE SECTION OF CODE
;* ACCORDING TO THE TABLE.
;*
;* AT 'EXEC', DE SHOULD POINT TO THE STRING AND HL SHOULD POINT TO THE
;* TABLE—1. AT 'DIRECT', DE SHOULD POINT TO THE STRING. HL WILL BE SET
;* UP TO POINT TO TAB1-1, WHICH IS THE TABLE OF ALL DIRECT AND
;* STATEMENT COMMANDS.
;*
;* A '.' IN THE STRING WILL TERMINATE THE TEST AND THE PARTIAL MATCH
;* WILL BE CONSIDERED AS A MATCH. E.G.. 'P.', 'PR.', 'PRI.', 'PRIN.',
;* OR 'PRINT' WILL ALL MATCH 'PRINT'.
;*
;* THE TABLE CONSISTS OF ANY NUMBER OF ITEMS. EACH ITEM IS A STRING OF
;* CHARACTERS WITH BIT 7 SET TO 0 AND A JUMP ADDRESS STORED HI-LOW WITH
;* BIT 7 OF THE HIGH BYTE SET TO 1.
;*
;* END OF TABLE IS AN ITEM WITH A JUMP ADDRESS ONLY. IF THE STRING
;* DOES NOT MATCH ANY OF THE OTHER ITEMS, IT WILL MATCH THIS NULL ITEM
;* AS DEFAULT.
;*
DIRECT LXI H,TAB1-1     ; *** DIRECT ***
;*
EXEC   CALL IGNBLK      ; *** EXEC ***
       PUSH D           ; SAVE POINTER
EX1    LDAX D           ; IF FOUND '.' IN STRING
       INX  D           ; BEFORE ANY MISMATCH
       CPI  "."         ; WE DECLARE A MATCH
       JZ   EX3
       INX  H           ; HL—>TABLE
       CMP  M           ; IF MATCH, TEST NEXT
       JZ   EX1
       MVI  A,7FH       ; ELSE, SEE IF BIT 7
       DCX  D           ; OF TABLE IS SET. WHICH
       CMP  M           ; IS THE JUMP ADDR. (HI)
       JC   EX5         ; C:YES. MATCHED
EX2    INX  H           ; NC:NO. FIND JUMP ADDR.
       CMP  M
       JNC  EX2
       INX  H           ; BUMP TO NEXT TAB. ITEM
       POP  D           ; RESTORE STRING POINTER
       JMP  EXEC        ; TEST AGAINST NEXT ITEM
EX3    MVI  A,7FH       ; PARTIAL MATCH. FIND
EX4    INX  H           ; JUMP ADDR.. WHICH IS
       CMP  M           ; FLAGGED BY BIT 7
       JNC  EX4
EX5    MOV  A,M         ; LOAD HL WITH THE JUMP
       INX  H           ; ADDRESS FROM THE TABLE
       MOV  L,M         ;  ******************
       ANI  FFH         ; ***** ANI 7FH ******
       MOV  H,A         ;  ******************
       POP  PSW         ; CLEAN UP THE GARBAGE
       PCHL             ; AND WE GO DO IT
;*
;**************************************
;*
;* WHAT FOLLOWS IS THE C0DE T0 EXECUTE DIRECT AND STATEMENT COMMANDS.
;* CONTROL IS TRANSFERED TO THESE POINTS VIA THE COMMAND TABLE LOOKUP
;* CODE OF 'DIRECT' ANC 'EXEC' IN LAST SECTION. AFTER THE COMMANO IS
;* EXECUTED, CONTROL IS TRANSFERED TO OTHER SECTIONS AS FOLLOWS:
;*
;* FOR 'LIST', 'NEW', AND 'STOP': GO BACK TO 'RSTART'
;* FOR 'RUN' GO EXECUTE THE FIRST STORED LINE IF ANY: ELSE GO BACK TO
;* 'RSTATT'.
;* FOR 'GOTO' AND 'GOSUB': GO EXECUTE THE TARGET LINE.
;* FOR 'RETURN' AND 'NEXT': GO BACK TO SAVED RETURN LINE.
;* FOR ALL OTHERS: IF 'CURRNT' -> 0, GO TO 'RSTART', ELSE GO EXECUTE
;* NEXT COMMAND. (THIS IS DONE IN 'FINISH'.)
;*
;**************************************
;*
;* *** NEW *** STOP *** RUN (& FRIENDS) *** & GOTO ***
;* 'NEW(CR)' RESETS 'TXTUNF'
;*
;* 'STOP(CR)' GOES BACK TO 'RSTART'
;*
;* 'RUN(CR)' FINDS THE FIRST STORED LINE, STORE ITS ADDRESS (IN
;* 'CURRNT'), AND START EXECUTE IT. NOTE THAT ONLY THOSE
;* COMMANDS IN TAB2 ARE LEGAL FOR STORED PROGRAM.
;*
;* THERE ARE 3 MORE ENTRIES IN 'RUN':
;* 'RUNNXL' FINDS N£XT LINE. STORES ITS ADDR. AND EXECUTES IT.
;* 'RUNTSL' STORES THE ADDRESS OF THIS LINE AND EXECUTES IT.
;* 'RUNSML' CONTINUES THE EXECUTION ON SAME LINE.
;*
;* 'GOTO EXPR(CR)' EVALUATES THE EXPRESSION, FIND THE TARGET
;* LINE, AND JUMP TO 'RUNTSL' TO DO IT.
;*
NEW    CALL ENDCHK      ; *** NEW(CR) ***
       JMP  PURGE
STOP   CALL ENDCHK      ; *** STOP(CR) ***
       JMP  RSTART
;*
RUN    CALL ENDCHK      ; *** RUN(CR) ***
       LXI  D,TEXT      ; FIRST SAVED LINE
;*
RUNNXL LXI  H,0         ; *** RUNNXL ***
       CALL FNDLP       ; FIND WHATEVER LINE NUMBER
       JC   RSTART      ; C:PASSED TXTUNF, QUIT
;*
RUNTSL XCHG             ; *** RLNTSL ***
       SHLD CURRNT      ; SET 'CURRNT'->LINE NUMBER
       XCHG
       INX  D           ; BUMP PASS LINE NUMBER
       INX  D
;*
RUNSML CALL CHKIO       ; *** RUNSML ***
       LXI  H,TAB2-1    ; FIND COMMAND IN TAB2
       JMP  EXEC        ; AND EXECUTE IT
;*
GOTO   CALL EXPR        ; *** GOTO EXPR ***
       PUSH D           ; SAVE FOR ERROR ROUTINE
       CALL ENDCHK      ; MUST FIND A CR
       CALL FNDLN       ; FIND THE TARGET LINE
       JNZ  AHOW        ; NO SUCH LINE NUMBER
       POP  PSW         ; CLEAR THE "PUSH DE"
       JMP  RUNTSL      ; GO DO IT
;*
;**************************************
;*
;* *** LIST *** & PRINT ***
;*
;* LIST HAS THREE FORMS:
;* 'LIST(CR)' LISTS ALL SAVED LINES
;* 'LIST N(CR)' START LIST AT LINE N
;* 'LIST N1, N2(CR)' START LIST AT LINE N1 FOR N2 LINES.
;*  YOU CAN STOPTHE LISTING BY CONTROL C KEY
;*
;* PRINT COMMAND IS 'PRINT ....,' OR 'PRINT ....(CR)'
;* WHERE '....' IS A LIST OF EXPRESIONS, FORMATS, AND/OR STRINGS.
;* THESE ITEMS ARE SEPERATED BY COMMAS.
;*
;* A FORMAT IS A POUND SIGN FOLLOWED BY A NUMBER. IT CONTROLS THE
;* NUMBER OF SPACES THE VALUE OF A EXPRESION IS GOING TO BE PRINTED.
;* IT STAYS EFFECTIVE FOR THE REST OF THE PRINT COMMAND UNLESS CHANGED
;* BY ANOTHER FORMAT. IF NO FORMAT IS SPECIFIED, 8 POSITIONS WILL BE
;* USED.
;*
;* A STRING IS QUOTED IN A PAIR OF SINGLE QUOTES OR A PAIR OF DOUBLE
;* QUOTES.
;*
;* CONTROL CHARACTERS AND LOWER CASE LETTERS CAN BE INCLUDED INSIDE THE
;* QUOTES. ANOTHER (BETTER) WAY OF GENERATING CONTROL CHARACTERS ON
;* THE OUTPUT IS USE THE UP-ARROW CHARACTER FOLLOWED BY A LETTER. |L
;*  |L MEANS FF, |I MEANS HT, |G MEANS BELL ETC.
;*
;* A (CRLF) IS GENERATED AFTER THE ENTIRE LIST HAS BEEN PRINTED OR IF
;* THE LIST IS A NULL LIST. HOWEVER IF THE LIST ENDED WITH A COMMA, NO
;* (CRLF) IS GENERATED.
;*
LIST   CALL TSTNUM      ; TEST IF THERE IS A NUMBER
       PUSH H
       LXI  H,FFFFH
       CALL TSTCH       ; TSTCH ROUTINE LOOKS AT
       DB   ","         ; NEXT BYTE AFTER CALL
       DB   LS1-$-1     ; AND LOCATION OFFSET FOR RELATIVE JUMP
       CALL TSTNUM
LS1    XTHL
       CALL ENDCHK      ; IF NO NUMBER WE GET A 0
       CALL FNDLN       ; FIND THIS OR NEXT LINE
LS2    JC   RSTART      ; C:PASSED TXTUNF
       XTHL
       MOV  A,H
       ORA  L
       JZ   RSTART
       DCX  H
       XTHL
       CALL PRTLN       ; PRINT THE LINE
       CALL PRTSTG
       CALL CHKIO
       CALL FNDLP       ; FIND NEXT LINE
       JMP  LS2         ; AND LOOP BACK
;*
PRINT  MVI  C,8         ; C= NUMBER OF SPACES
       CALL TSTCH       ; IF NULL LIST & ";"
       DB   ";"
       DB   PR1-$-1
       CALL CRLF        ; GIVE CR-LF AND
       JMP  RUNSML      ; CONTINUE SAME LINE
PR1    CALL TSTCH       ; IF NULL LIST (CR)
       DB   CR
       DB   PR6-$-1
       CALL CRLF        ; ALSO GIVE CR-LF AND
       JMP RUNNXL       ; GO TO NEXT LINE
PR2    CALL TSTCH       ; ELSE IS IT FORMAT?
       DB   "#"
       DB   PR4-$-1
PR3    CALL EXPR        ; YES, EVALUATE EXPR.
       MVI  A,C0H
       ANA  L
       ORA  H
       JNZ  QHOW
       MOV  C,L         ; AND SAVE IT IN C
       JMP  PR5         ; LOOK FOR MORE TO PRINT
PR4    CALL QTSTG       ; OR IS IT A STRING?
       JMP  PR9         ; IF NOT, MUST BE EXPR.
PR5    CALL TSTCH       ; IF "," GO FIND NEXT
       DB   ","
       DB   PR8-$-1
PR6    CALL TSTCH
       DB   ","
       DB   PR7-$-1
       MVI  A," "
       CALL OUTCH
       JMP  PR6
PR7    CALL FIN         ; IN THE LIST.
       JMP  PR2         ; LIST CONTINUES
PR8    CALL CRLF        ; LIST ENDS
       JMP  FINISH
PR9    CALL EXPR        ; EVALUATE THE EXPR
       PUSH B
       CALL PRTNUM      ; PRINT THE VALUE
       POP  B
       JMP PR5          ; MORE TO PRINT?
;*
;**************************************
;*
;* *** GOSUB *** & RETURN ***
;*
;* 'GOSUB EXPR;' OR 'GOSUB EXPR (CR)' IS LIKE THE 'GOTO' COMMAND,
;* EXCEPT THAT THE CURRENT TEXT POINTER, STACK POINTER ETC. ARE SAVE SO
;* THAT EXECUTION CAN BE CONTINUUED AFTER THE SUBROUTINE 'RETURN', IN
;* ORDER THAT 'GOSUB' CAN BE NESTED (AND EVEN RECURSIVE). THE SAVE AREA
;* MUST BE STACKED. THE STACK POINTER IS SAVED IN 'STKGOS'. THE OLD
;* 'STKGOS' IS SAVED IN THE STACK. IF WE ARE IN THE MAIN ROUTINE,
;* 'STKGOS' IS ZERO (THIS WAS DONE BY THE "MAIN" SECTION OF THE CODE).
;* BUT WE STILL SAVE IT AS A FLAG FOR NO FURTHER 'RETURN'S.
;*
;* 'RETURN(CR>' UNDOS EVERYTHING THAT 'GOSUB' DID. AND THUS RETURN THE
;* EXCUTION TO THE COMMAND AFTER THE MOST RECENT 'GOSUB'. IF 'STKGOS'
;* IS ZERO, IT INDICATES THAT WE NEVER HAD A 'GOSUB' AND IS THUS AN ERROR.
;*
GOSUB  CALL PUSHA       ; SAVE THE CURRENT "FOR"
       CALL EXPR        ; PARAMETERS
       PUSH D           ; AND TEXT POINTER
       CALL FNDLN       ; FIND THE TARGET LINE
       JNZ  AHOW        ; NOT THERE. SAY "HOW?"
       LHLD CURRNT      ; SAVE OLD
       PUSH H           ; 'CURRNT' OLD 'STKGOS'
       LHLD STKGOS
       PUSH H
       LXI  H,0         ; AND LOAD NEW ONES
       SHLD LOPVAR
       DAD  SP
       SHLD STKGOS
       JMP  RUNTSL      ; THEN RUN THAT LINE
RETURN CALL ENDCHK      ; THERE MUST BE A CR
       LHLD STKGOS      ; OLD STACK POINTER
       MOV  A,H         ; 0 MEANS NOT EXIST
       ORA  L
       JZ   QWHAT       ; SO, WE SAY: "WHAT?"
       SPHL             ; ELSE, RESTORE IT
RESTOR POP  H
       SHLD STKGOS      ; AND THE OLD 'STKGOS'
       POP  H
       SHLD CURRNT      ; AND THE OLD 'CURRNT'
       POP  D           ; OLD TEXT POINTER
       CALL POPA        ; OLD "FOR" PARAMETERS
       JMP  FINISH
;*
;**************************************
;*
;* *** FOR *** & NEXT ***
;*
;* 'FOR' HAS TWO FORMS:
;* 'FOR VAR=EXP1 TO EXP2 STEP EXP3' AND 'FOR VAR=EXP1 TO EXP2'
;* THE SECOND FORM MEANS THE SAME THING AS THE FIRST
;* FORM WITH EXP3=1. (I.E., WITH A STEP OF +1.) TBI WILL FIND THE
;* VARIABLE VAR. AND SET ITS VALUE TO THE CURRENT VALUE OF EXP1. IT
;* ALSO EVALUATES EXP2 AND EXP3 AND SAVE ALL THESE TOGETHER WITH THE
;* TEXT POINTER ETC. IN THE 'FOR' SAVE AREA, WHICH CONSISTS OF
;* 'LOPVAR', 'LOPINC', 'LOPLMT', 'LOPLN', AND 'LOPPT'. IF THERE IS
;* ALREADY SOMETHING IN THE SAVE AREA (THIS IS INDICATED BY A
;* NON-ZERO 'LOPVAR'), THEN THE OLD SAVE AREA IS SAVED IN THE STACK
;* BEFORE THE NEW ONE OVERWRITES IT. TBI WILL THEN DIG IN THE STACK
;* AND FIND OUT IF THIS SAME VARIABLE WAS USED IN ANOTHER CURRENTLY
;* ACTIVE 'FOR' LOOP. IF THAT IS THE CASE, THEN THE OLD 'FOR' LOOP IS
;* DEACTIVATED. (PURGED FROM THE STACK..)
;*
;* 'NEXT VAR' SERVES AS THE LOGICAL (NOT NECESSARILLY PHYSICAL) END OF
;* THE 'FOR' LOOP. THE CONTROL VARIABLE VAR. IS CHECKED WITH THE
;* 'LOPVAR'. IF THEY ARE NOT THE SAME, TBI DIGS IN THE STACK TO FIND
;* THE RIGHT ONE AND PURGES ALL THOSE THAT DID NOT MATCH. EITHER WAY,
;* TBI THEN ADDS THE 'STEP' TO THAT VARIABLE AND CHECK THE RESULT WITH
;* THE LIMIT. IF IT IS WITHIN THE LIMIT, CONTROL LOOPS BACK TO THE
;* COMMAND FOLLOWING THE 'FOR'. IF OUTSIDE THE LIMIT, THE SAVE AREA IS
;* PURGED AND EXECUTION CONTINUES.
;*
FOR    CALL PUSHA       ; SAVE THE OLD SAVE AREA
       CALL SETVAL      ; SET THE CONTROL VAR.
       DCX  H           ; HL IS ITS ADDRESS
       SHLD LOPVAR      ; SAVE THAT
       LXI  H,TAB4-1    ; USE 'EXEC' TO LOOK
       JMP  EXEC        ; FOR THE WORD 'TO'
FR1    CALL EXPR        ; EVALUATE THE LIMIT
       SHLD LOPLMT      ; SAVE THAT
       LXI  H,TAB5-1    ; USE 'EXEC' TO LOOK
       JMP  EXEC        ; FOR THE WORD 'STEP'
FR2    CALL EXPR        ; FOUND IT, GET STEP
       JMP  FR4
FR3    LXI  H,1         ; NOT FOUND, SET TO 1
FR4    SHLD LOPINC      ; SAVE THAT TOO
       LHLD CURRNT      ; SAVE CURRENT LINE NUMBER
       SHLD LOPLN
       XCHG             ; AND TEXT POINTER
       SHLD LOPPT
       LXI  B,10        ; DIG INTO STACK TO
       LHLD LOPVAR      ; FIND 'LOPVAR'
       XCHG
       MOV  H,B
       MOV  L,B         ; HL=0 NOW
       DAD  SP          ; HERE IS THE STACK
       JMP  FR6
FR5    DAD  B           ; EACH LEVEL IS 10 DEEP
FR6    MOV  A,M         ; GET THAT OLD 'LOPVAR'
       INX  H
       ORA  M
       JZ   FR7         ; 0 SAYS NO MORE IN IT
       MOV  A,M
       DCX  H
       CMP  D           ; SAME AS THIS ONE?
       JNZ  FR5
       MOV  A,M         ; THE OTHER HALF?
       CMP  E
       JNZ  FR5
       XCHG             ; YES, FOUND ONE
       LXI  H,0
       DAD  SP          ; TRY TO MOVE SP
       MOV  B,H
       MOV  C,L
       LXI  H,10
       DAD  D
       CALL MVDOWN      ; AND PURGE 10 WORDS
       SPHL             ; IN THE STACK
FR7    LHLD LOPPT       ; JOB DONE, RESTORE DE
       XCHG
       JMP FINISH       ; AND CONTINUE
;*
NEXT   CALL TSTV        ; GET ADDRESS OF VAR.
       JC   QWHAT       ; NO VARIABLE. "WHAT?"
       SHLD VARNXT      ; YES. SAVE IT
NX1    PUSH D           ; SAVE TEXT POINTER
       XCHG
       LHLD LOPVAR      ; GET VAR. IN 'FOR'
       MOV  A,H
       ORA  L           ; 0 SAYS NEVER HAD ONE
       JZ   AWHAT       ; SO WE ASK: "WHAT?"
       CALL COMP        ; ELSE WE CHECK THEM
       JZ   NX2         ; OK, THEY AGREE
       POP  D           ; NO. LET'S SEE
       CALL POPA        ; PURGE CURRENT LOOP
       LHLD VARNXT      ; AND POP ONE LEVEL
       JMP  NX1         ; GO CHECK AGAIN
NX2    MOV  E,M         ; COME HERE WHEN AGREED
       INX  H
       MOV  D,M         ; DE=VALUE OF VAR.
       LHLD LOPINC
       PUSH H
       MOV  A,H
       XRA  D           ; S=SIGN DIFFER
       MOV  A,D         ; A=SIGN OF DE
       DAD  D           ; ADD ONE STEP
       JM   NX3         ; CANNOT OVERFLOW
       XRA  H           ; MAY OVERFLOW
       JM   NX5         ; AND IT DID
NX3    XCHG
       LHLD LOPVAR      ; PUT IT BACK
       MOV  M,E
       INX  H
       MOV  M,D
       LHLD LOPLMT      ; HL=LIMIT
       POP  PSW         ; OLD HL
       ORA  A
       JP   NX4         ; STEP > 0
       XCHG             ; STEP < 0
NX4    CALL CKHLDE      ; COMPARE WITH LIMIT
       POP  D           ; RESTORE TEXT POINTER
       JC   NX6         ; OUTSIDE LIMIT
       LHLD LOPLN       ; WITHIN LIMIT. GO
       SHLD CURRNT      ; BACK TO THE SAVED
       LHLD LOPPT       ; 'CURRNT' AND TEXT
       XCHG             ; POINTER
       JMP  FINISH
NX5    POP  H           ; OVERFLOW, PURGE
       POP D            ; GARBAGE IN STACK
NX6    CALL POPA        ; PURGE THIS LOOP
       JMP FINISH
;*
;**************************************
;*
;* *** REM *** IF *** INPUT *** & LET (& DEFLT) ***
;*
;* 'REM' CAN BE FOLLOWED BY ANYTHING AND IS IGNORED 8Y TBI. TBI TREATS
;* IT LIKE AN 'IF' WITH A FALSE CONDITION.
;*
;* 'IF' IS FOLLOWED BY AN EXPR. AS A CONDITION AND ONE OR MORE COMMANDS
;* (INCLUDING OTHER 'IF'S) SEPERATED BY SEMI-COLONS. NOTE THAT THE
;* WORD 'THEN' IS NOT USED. TBI EVALUATES THE EXPR. IF IT IS NON-ZERO,
;* EXECUTION CONTINUES. IF THE EXPR. IS ZERO, THE COMMANDS THAT
;* FOLLOWS ARE IGNORED AND EXECUTION CONTINUES AT THE NEXT LINE.
;*
;* 'INPUT' COMMAND IS LIKE THE 'PRINT' COMMAND. AND IS FOLLOWED BY A
;* LIST OF ITEMS. IF THE ITEM IS A STRING IN SINGLE OR DOUBLE QOUTES,
;* OR IS AN UP-ARROW, IT HAS THE SAME EFFECT AS IN 'PRINT'. IF AN ITEM
;* IS A VARIABLE, THIS VARIABLE NAME IS PRINTED OUT FOLLOWED BY A
;* COLON. THEN TBI WAITS FOR AN EXPR. TO BE TYPED IN. THE VARIABLE IS
;* THEN SET TO THE VALUE OF THIS EXPR. IF THE VARIABLE IS PROCEDED BY
;* A STRING (AGAIN IN SINGLE OR DOUBLE QUOTES), THE STRING WILL BE
;* PRINTED FOLLOWED BY A COLON. TBI THEN WAITS FOR INPUT EXPR. AND
;* SET THE VARIABLE TO THE VALUE OF THE EXPR.
;*
;* IF THE INPUT EXPR. IS INVALID, TBI WILL PRINT "WHAT?", "HOW?" OR
;* "SORRY" AND REPRINT THE PROMPT AND REDO THE INPUT. THE EXECUTION
;* WILL NOT TERMINATE UNLESS YOU TYPE CONTROL-C. THIS IS HANDLED IN
;* 'INPERR'.
;*
;* 'LET' IS FOLLOWED BY A LIST OF ITEMS SEPERATED BY COMMAS. EACH ITEM
;* CONSISTS OF A VARIABLE, AN EQUAL SIGN, AND AN EXPR. TBI EVALUATES
;* THE EXPR. AND SET THE VARIBLE TO THAT VALUE. TBI WILL ALSO HANDLE
;* 'LET' COMMAND WITHOUT THE WORD 'LET'. THIS IS DONE BY 'DEFLT'.
;*
REM    LXI  H,0         ; *** REM ***
       JMP  IF1         ; THIS IS LIKE 'IF 0'
;*
IFF    CALL EXPR        ; *** IF ***
IF1    MOV  A,H         ; IS THE EXPR.=0?
       ORA  L
       JNZ  RUNSML      ; NO, CONTINUE
       CALL FNDSKP      ; YES, SKIP REST OF LINE
       JNC  RUNTSL      ; AND RUN THE NEXT LINE
       JMP  RSTART      ; IF NO NEXT, RE-START
;*
INPERR LHLD STKINP      ; *** INPERR ***
       SPHL             ; RESTORE OLD SP
       POP  H           ; AND OLD 'CURRNT'
       SHLD CURRNT
       POP  D           ; AND OLD TEXT POINTER
       POP  D           ; REDO INPUT
;*
INPUT  DS   0
IP1    PUSH D           ; SAVE IN CASE OF ERROR
       CALL QTSTG       ; IS NEXT ITEM A STRING?
       JMP  IP8         ; NO
IP2    CALL TSTV        ; YES, BUT FOLLOWED BY A
       JC   IP5         ; VARIABLE? NO.
IP3    CALL IP12
       LXI  D,BUFFER    ; POINTS TO BUFFER
       CALL EXPR        ; EVALUATE INPUT
       CALL ENDCHK
       POP  D           ; OK, GET OLD HL
       XCHG
       MOV  M,E         ; SAVE VALUE IN VAR.
       INX  H
       MOV  M,D
IP4    POP  H           ; GET OLD 'CURRNT'
       SHLD CURRNT
       POP  D           ; AND OLD TEXT POINTER
IP5    POP  PSW         ; PURGE JUNK IN STACK
IP6    CALL TSTCH       ; IS NEXT CHAR. ","?
       DB   ","
       DB   IP7-$-1
       JMP  INPUT       ; YES, MORE ITEMS.
IP7    JMP  FINISH
IP8    PUSH D           ; SAVE FOR 'PRTSTG'
       CALL TSTV        ; MUST BE VARIABLE NOW
       JNC  IP11
IP10   JMP  QWHAT       ; "WHAT?" IT IS NOT?
IP11   MOV  B,E
       POP  D
       CALL PRTCHS      ; PRINT THOSE AS PROMPT
       JMP  IP3         ; YES, INPUT VARIABLE
IP12   POP  B           ; RETURN ACDRESS
       PUSH D           ; SAVE TEXT POINTER
       XCHG
       LHLD CURRNT      ; ALSO SAVE 'CURRNT'
       PUSH H
       LXI  H,IP1       ; A NEGATIVE NUMBER
       SHLD CURRNT      ; AS A FLAG
       LXI  H,0         ; SAVE SP TOO
       DAD  SP
       SHLD STKINP
       PUSH D           ; OLD HL
       MVI  A," "       ; PRINT A SPACE
       PUSH B
       JMP  GETLN       ; AND GET A LINE
;*
DEFLT  LDAX D           ; *** DEFLT **♦
       CPI  CR          ; EMPTY LINE IS OK
       JZ   LT4         ; ELSE IT IS 'LET'
;*
LET    DS   0           ; *** LET ***
LT2    CALL SETVAL
LT3    CALL TSTCH       ; SET VALUE TO VAR.
       DB   ","
       DB   LT4-$-1
       JMP  LET         ; ITEM BY ITEM
LT4    JMP  FINISH      ; UNTIL FINISH
;*
;**************************************
;*
;* *** EXPR ***
;*
;* 'EXPR' EVALUATES ARITHMETICAL OR LOGICAL EXPRESSIONS.
;* <EXPR>::=<EXPR1>
;*          <EXPR1><REL.OP.><EXPR1>
;* WHERE <REL.OP.> IS ONE OF THE OPERATORS IN TAB6 AND THE RESULT OF
;* THESE OPERATIONS IS 1 IF TRUE AND 0 IF FALSE.
;* <EXPR1>::=(+ OR —)<EXPR2>(+ OR -<EXPR2>)(....)
;* WHERE () ARE OPTIONAL AND (....) ARE OPTIONAL REPEATS.
;* <EXPR2>::=<EXPR3>(<* OR /><EXPR3>)(....)
;* <EXPR3>::=<VARIABLE>
;*           <FUNCTION>
;*           (<EXPH>)
;* <EXPR> IS RECURSIVE SO THAT VARIABLE "@" CAN HAVE AN <EXPR> AS
;* INDEX. FUNCTIONS CAN HAVE AN <EXPR> AS ARGUMENTS, AND
;* <EXPR3> CAN BE AN <EXPR> IN PARANTHESE.
;*
EXPR   CALL EXPR1       ; *** EXPR ***
       PUSH H           ; SAVE <EXPR1> VALUE
       LXI  H,TAB6-1    ; LOOKUP REL.OP.
       JMP  EXEC        ; GO DO IT
XPR1   CALL XPR8        ; REL.OP.">="
       RC               ; NO, RETURN HL=0
       MOV  L,A         ; YES, RETURN HL=1
       RET
XPR2   CALL XPR8        ; REL.OP."#"
       RZ               ; FALSE, RETURN HL=0
       MOV  L,A         ; TRUE, RETURN HL=1
       RET
XPR3   CALL XPR8        ; REL.OP.">"
       RZ               ; FALSE
       RC               ; ALSO FALSE, HL=0
       MOV  L,A         ; TRUE, HL=1
       RET
XPR4   CALL XPR8        ; REL.OP."<="
       MOV  L,A         ; SET HL=1
       RZ               ; REL. TRUE, RETURN
       RC
       MOV  L,H         ; ELSE SET HL=0
       RET
XPR5   CALL XPR8        ; REL.OP."="
       RNZ              ; FALSE, RETRUN HL=0
       MOV  L,A         ; ELSE SET HL=1
       RET
XPR6   CALL XPR8        ; REL.OP."<"
       RNC              ; FALSE, RETURN HL=0
       MOV  L,A         ; ELSE SET HL=1
       RET
XPR7   POP  H           ; NOT REL.OP.
       RET              ; RETURN HL=<EXPR1>
XPR8   MOV  A,C         ; SUBROUTINE FOR ALL
       POP  H           ; REL.OP.'S
       POP  B
       PUSH H           ; REVERSE TOP OF STACK
       PUSH B
       MOV  C,A
       CALL EXPR1       ; GET 2ND <EXPR1>
       XCHG             ; VALUE IN DE NOW
       XTHL             ; 1ST <EXPR1> IN HL
       CALL CKHLDE      ; COMPARE 1ST WITH 2ND
       POP  D           ; RESTORE TEXT POINTER
       LXI  H,0         ; SET HL=0, A=1
       MVI A,1
       RET
;*
EXPR1  CALL TSTCH       ; NEGATIVE SIGN?
       DB   "-"
       DB   XP11-$-1
       LXI  H,0         ; YES. FAKE '0-'
       JMP  XP16        ; TREAT LIKE SUBTRACT
XP11   CALL TSTCH       ; POSITIVE SIGN? IGNORE
       DB   "+"
       DB   XP12-$-1
XP12   CALL EXPR2       ; 1ST <EXPR2>
XP13   CALL TSTCH       ; ADD?
       DB   "+"
       DB   XP15-$-1
       PUSH H           ; YES. SAVE VALUE
       CALL EXPR2       ; GET 2ND <EXPR2>
XP14   XCHG             ; 2ND IN DE
       XTHL             ; 1ST IN HL
       MOV  A,H         ; COMPARE SIGN
       XRA  D
       MOV  A,D
       DAD  D
       POP  D           ; RESTORE TEXT POINTER
       JM   XP13        ; 1ST 2ND SIGN DIFFER
       XRA  H           ; 1ST 2ND SIGN EQUAL
       JP   XP13        ; SO IS RESULT
       JMP  QHOW        ; ELSE WE HAVE OVERFLOW
XP15   CALL TSTCH       ; SUBTRACT?
       DB   "-"
       DB   XPR9-$-1
XP16   PUSH H           ; YES, SAVE 1ST <EXPR2>
       CALL EXPR2       ; GET 2ND <EXPR2>
       CALL CHGSGN      ; NEGATE
       JMP  XP14        ; AND ADD THEM
;*
EXPR2  CALL EXPR3       ; GET 1ST <EXPR3>
XP21   CALL TSTCH       ; MULTIPLY?
       DB   "*"
       DB   XP24-$-1
       PUSH H           ; YES, SAVE 1ST
       CALL EXPR3       ; AND GET 2ND <EXPR3>
       MVI  B,0         ; CLEAR B FOR SIGN
       CALL CHKSGN      ; CHECK SIGN
       XTHL             ; 1ST IN HL
       CALL CHKSGN      ; CHECK SIGN OF 1ST
       XCHG
       XTHL
       MOV  A,H         ; IS HL > 255 ?
       ORA  A
       JZ   XP22        ; NO
       MOV  A,D         ; YES, HOW ABOUT DE
       ORA  D
       XCHG             ; PUT SMALLER IN HL
       JNZ  AHOW        ; ALSO >, WILL OVERFLOW
XP22   MOV  A,L         ; THIS IS DUMB
       LXI  H,0         ; CLEAR RESULT
       ORA  A           ; ADD AND COUNT
       JZ   XP25
XP23   DAD  D
       JC   AHOW        ; OVERFLOW
       DCR  A
       JNZ  XP23
       JMP  XP25        ; FINISHED
XP24   CALL TSTCH       ; DIVIDE?
       DB   "/"
       DB   XPR9-$-1
       PUSH H           ; YES, SAVE 1ST <EXPR3>
       CALL EXPR3       ; AND GET 2ND ONE
       MVI  B,0         ; CLEAR B FOR SIGN
       CALL CHKSGN      ; CHECK SIGN OF 2ND
       XTHL             ; GET 1ST IN HL
       CALL CHKSGN      ; CHECK SIGN OF 1ST
       XCHG
       XTHL
       XCHG
       MOV  A,D         ; DIVIDE BY 0?
       ORA  E
       JZ   AHOW        ; SAY "HOW?"
       PUSH B           ; ELSE SAVE SIGN
       CALL DIVIDE      ; USE SUBROUTINE
       MOV  H,B         ; RESULT IN HL NOW
       MOV  L,C
       POP  B           ; GET SIGN BACK
XP25   POP  D           ; AND TEXT POINTER
       MOV  A,H         ; HL MUST BE +
       ORA  A
       JM   QHOW        ; ELSE IT IS OVERFLOW
       MOV  A,B
       ORA  A
       CM   CHGSGN      ; CHANGE SIGN IF NEEDED
       JMP  XP21        ; LOOK FOR MORE TERMS
;*
EXPR3  LXI  H,TAB3-1    ; FIND FUNCTION IN TAB3
       JMP  EXEC        ; AND GO DO IT
NOTF   CALL TSTV        ; NO, NOT A FUNCTION
       JC   XP32        ; NOR A VARIABLE
       MOV  A,M         ; VARIABLE
       INX  H
       MOV  H,M         ; VALUE IN HL
       MOV  L,A
       RET
XP32   CALL TSTNUM      ; OR IS IT A NUMBER
       MOV  A,B         ; NUMBER OF DIGIT
       ORA  A
       RNZ              ; OK
PARN   CALL TSTCH       ; NO DIGIT, MUST BE
       DB   "("
       DB   XPR0-$-1
PARNP  CALL EXPR        ; "(EXPR)"
       CALL TSTCH
       DB   ")"
       DB   XPR0-$-1
XPR9   RET
XPR0   JMP  QWHAT       ; ELSE SAY: "WHAT?"
;*
RND    CALL PARN        ; *** RND(EXPR) ***
       MOV  A,H         ; EXPR MUST BE +
       ORA  A
       JM   QHOW
       ORA  L           ; AND NON-ZERO
       JZ   QHOW
       PUSH D           ; SAVE BOTH
       PUSH H
       LHLD RANPNT      ; GET MEMORY AS RANDOM
       LXI  D,RANEND
       CALL COMP
       JC   RA1         ; WRAP AROUND IF LAST
       LXI  H,BOTROM
RA1    MOV  E,M
       INX  H
       MOV  D,M
       SHLD RANPNT
       POP  H
       XCHG
       PUSH B
       CALL DIVIDE      ; RND(N)=MOD(M,N)+1
       POP  B
       POP  D
       INX  H
       RET
;*
ABS    CALL PARN        ; *** ABS(EXPR) ***
       DCX  D
       CALL CHKSGN      ; CHECK SIGN
       INX  D
       RET
;*
SIZE   LHLD TXTUNF      ; *** SIZE ***
       PUSH D           ; GET THE NUMBER OF FREE
       XCHG             ; BYTES BETWEEN 'TXTUNF'
       LHLD TXTLMT      ; AND 'TXTLMT'
       CALL SUBDE
       POP  D
       RET
;*
;**************************************
;*
;* *** DIVIDE *** SUBDE *** CHKSGN *** CHGSGN *** & CKHLDE ***
;*
;* 'DIVIDE' DIVIDES HL BY DE. RESULT IN BC. REMAINDER IN HL
;*
;* 'SUBDE' SUBTRACTS DE FROM HL
;*
;* 'CHKSGN' CHECKS SIGN OF HL, IF +, NO CHANGE. IF  -, CHANGE SIGN
;* AND FLIP SIGN OF B.
;*
;* 'CHGSGN' CHANGES SIGN OF HL AND B UNCONDITIONALLY.
;*
;* 'CKHLDE' CHECKS SIGN OF HL AND DE. IF DIFFERENT, HL AND DE ARE
;* INTERCHANGED. IF SAME SIGN, NOT INTERCHANGED. EITHER CASE, HL DE
;* ARE THEN COMPARED TO SET THE FLAGS.
;*
DIVIDE PUSH H           ; *** DIVIDE ***
       MOV  L,H         ; DIVIDE H BY DE
       MVI  H,0
       CALL DV1
       MOV  B,C         ; SAVE RESULT IN B
       MOV  A,L         ; (REMAINDER+L)/DE
       POP  H
       MOV  H,A
DV1    MVI  C,FFH       ; (-1) RESULT IN C
DV2    INR  C           ; DUMB ROUTINE
       CALL SUBDE       ; DIVIDE BY SUBTRACT
       JNC  DV2         ; AND COUNT
       DAD  D
       RET
;*
SUBDE  MOV  A,L         ; *** SUBDE ***
       SUB  E           ; SUBTRACT DE FROM
       MOV  L,A         ; HL
       MOV  A,H
       SBB  D
       MOV  H,A
       RET
;*
CHKSGN MOV  A,H         ; *** CHKSGN ***
       ORA  A           ; CHECK SIGN OF HL
       RP               ; IF -, CHANGE SIGN
;*
CHGSGN MOV  A,H         ; *** CHGSGN ***
       ORA  L
       RZ
       MOV  A,H
       PUSH PSW
       CMA              ; CHANGE SIGN OF HL
       MOV  H,A
       MOV  A,L
       CMA
       MOV  L,A
       INX  H
       POP  PSW
       XRA  H
       JP   QHOW
       MOV  A,B         ; AND ALSO FLIP B
       XRI  080H
       MOV  B,A
       RET
;*
CKHLDE MOV  A,H
       XRA  D           ; SAME SIGN?
       JP   CK1         ; YES, COMPARE
       XCHG             ; NO, XCH AND COMP
CK1    CALL COMP
       RET
;*
COMP   MOV  A,H         ; *** COMP ***
       CMP  D           ; COMPARE HL WITH DE
       RNZ              ; RETURN CORRECT C AND
       MOV  A,L         ; Z FLAGS
       CMP E            ; BUT OLD A IS LOST
       RET
;*
;**************************************
;*
;* *** SETVAL *** FIN *** ENDCHK *** & ERROR (& FRIENDS) ***
;* "SETVAL" EXPECTS A VARIABLE, FOLLOWED BY AN EQUAL SIGN AND THEN AN
;* EXPR. IT EVALUATES THE EXPR, AND SET THE VARIABLE TO THAT VALUE.
;* "FIN" CHECKS THE END OF A COMMAND. IF IT ENDED WITH ";", EXECUTION
;* CONTINUES. IF IT ENDED WITH A CR, IT FINDS THE NEXT LINE AND
;* CONTINUE FROM THERE.
;*
;* "ENDCHK" CHECKS IF A COMMAND IS ENDED WITH CR. THIS IS REQUIRED IN
;* CERTAIN COMMANDS. (GOTO, RETURN, AND STOP ETC.)
;*
;* "ERROR" PRINTS THE STRING POINTED BY DE (AND ENDS WITH CR). IT THEN
;* PRINTS THE LINE POINTED BY 'CURRNT' WITH A "?" INSERTED AT WHERE THE
;* OLD TEXT POINTER (SHOULD BE ON TOP OF THE STACK) POINTS TO.
;* EXECUTION OF TBI IS STOPPED AND TBI IS RESTARTED. HOWEVER, IF
;* 'CURRNT' -> ZERO (INDICATING A DIRECT COMMAND), THE DIRECT COMMAND
;* IS NOT PRINTED. AND IF 'CURRNT' -> NEGATIVE NUMBER (INDICATING 'INPUT'
;* COMMAND, THE INPUT LINE IS NOT PRINTED AND EXECUTION IS NOT
;* TERMINATED BUT CONTINUED AT 'INPERR'.
;*
;* RELATED TO 'ERROR' ARE THE FOLLOWING: 'QWHAT' SAVES TEXT POINTER IN
;* STACK AND GET MESSAGE "WHAT?" 'AWHAT' JUST GET MESSAGE "WHAT?" AND
;* JUMP TO 'ERROR'. 'QSORRY' AND 'ASORRY* DO SAME KIND OF THING.
;* 'QHOW' AND 'AHOW' IN THE ZERO PAGE SECTION ALSO DO THIS.
;*
SETVAL CALL TSTV        ; *** SETVAL ***
       JC   QWHAT       ; "WHAT?" NO VARIABLE
       PUSH H           ; SAVE ADORESS OF VAR.
       CALL TSTCH       ; PASS "=" SIGN
       DB   "="
       DB   SV1-$-1
       CALL EXPR        ; EVALUATE EXPR.
       MOV  B,H         ; VALUE IN BC NOW
       MOV  C,L
       POP  H           ; GET ADDRESS
       MOV  M,C         ; SAVE VALUE
       INX  H
       MOV  M,B
       RET
;*
FINISH CALL FIN         ; CHECK END OF COMMAND
SV1    JMP  QWHAT       ; PRINT "WHAT?" IF WRONG
;*
FIN    CALL TSTCH       ; *** FIN ♦**
       DB   ";"
       DB   FI1-$-1
       POP  PSW         ; ";", PURGE RET ADDR.
       JMP  RUNSML      ; CONTINUE SAME LINE
FI1    CALL TSTCH       ; NOT ";", IS IT CR?
       DB   CR
       DB   FI2-$-1
       POP  PSW         ; YES, PURGE RET ADDR.
       JMP  RUNNXL      ; RUN NEXT LINE
FI2    RET              ; ELSE RETURN TO CALLER
;*
IGNBLK LDAX D           ; *** IGNBLK ***
       CPI  " "         ; IGNORE BLANKS
       RNZ              ; IN TEXT (WHERE DE->)
       INX  D           ; AND RETURN THE FIRST
       JMP  IGNBLK      ; NON-BLANK CHAR, IN A
;*
ENDCHK CALL IGNBLK      ; *** ENDCHK ***
       CPI  CR          ; END WITH CR?
       RZ               ; OK, ELSE SAY: "WHAT?"
;*
QWHAT  PUSH D           ; *** QWHAT ***
AWHAT  LXI  D,WHAT      ; *** AWHAT ***
ERROR  CALL CRLF
       CALL PRTSTG      ; PRINT ERROR MESSAGE
       LHLD CURRNT      ; GET CURRENT LINE NUMBER
       PUSH H
       MOV  A,M         ; CHECK THE VALUE
       INX  H
       ORA  M
       POP  D
       JZ   TELL        ; IF ZERO, JUST RESTART
       MOV  A,M         ; IF NEGATIVE,
       ORA  A
       JM   INPERR      ; REDO INPUT
       CALL PRTLN       ; ELSE PRINT THE LINE
       POP  B
       MOV  B,C
       CALL PRTCHS
       MVI  A,"?"       ; PRINT A "?"
       CALL OUTCH
       CALL PRTSTG      ; LINE
       JMP  TELL        ; THEN RESTART
QSORRY PUSH D           ; *** QSORRY ***
ASORRY LXI  D,SORRY     ; *** ASORRY ***
       JMP  ERROR
;*
;**************************************
;*
;* *** FNDLN (& FRlENDS) ***
;*
;* 'FNDLN' FINDS A LINE WITH A GIVEN LINE NUMBER (IN HL) IN THE TEXT SAVE
;* AREA. DE IS USED AS THE TEXT POINTER. IF THE LINE IS FOUND, DE
;* WILL POINT TO THE BEGINNING OF THAT LINE (I.E., THE LOW BYTE OF THE
;* LINE NUMBER). AND FLAGS ARE NC & Z. IF THAT LINE IS NOT THERE AND A LINE
;* WiTH A HIGHER LINE NUMBER IS FOUND, DE POINTS TO THERE ANO FLAGS ARE NC &
;* NZ. IF WE REACHED THE END OF TEXT SAVE AREA AND CANNOT FIND THE
;* LINE, FLAGS ARE C & NZ. 'FNDLN' WILL INITIALIZE DE TO THE BEGINNING
;* OF THE TEXT SAVE AREA TO START THE SEARCH. SOME OTHER ENTRIES OF
;* THIS ROUTINE WILL NOT INITIALIZE DE AND DO THE SEARCH. 'FNDLP'
;* WILL START WITH DE AND SEARCH FOR THE LINE NUMBER. 'FNCNXT' WILL BUMP DE
;* BY 2. FIND A CR AND THEN START SEARCH. 'FNDSKP' USE DE TO FIND A
;* CR, AND THEN START SEARCH.
;*
FNDLN  MOV  A,H         ; *** FNDLN ***
       ORA  A           ; CHECK SIGN OF HL
       JM   QHOW        ; IT CANNOT BE -
       LXI  D,TEXT      ; INIT. TEXT POINTER
;*
FNDLP  INX  D           ; IS IT EOT MARK?
       LDAX D
       DCX  D
       ADD  A
       RC               ; C,NZ PASSED END
       LDAX D           ; WE DID NOT, GET BYTE 1
       SUB  L           ; IS THIS THE LINE?
       MOV  B,A         ; COMPARE LOW ORDER
       INX  D
       LDAX D           ; GET BYTE 2
       SBB  H           ; COMPARE HIGH ORDER
       JC   FL1         ; NO, NOT THERE YET
       DCX  D           ; ELSE WE EITHER FOUND
       ORA  B           ; IT, OR IT IS NOT THERE
       RET              ; NC,Z:FOUND; NC,NZ:NO
;*
FNDNXT INX  D           ; FIND NEXT LINE
FL1    INX  D           ; JUST PASSED BYTE 1 & 2
;*
FNDSKP LDAX D           ; *** FNDSKP ***
       CPI  CR          ; TRY TO FIND CR
       JNZ  FL1         ; KEEP LOOKING
       INX  D           ; FOUND CR, SKIP OVER
       JMP  FNDLP       ; CHECK IF END OF TEXT
;*
TSTV   CALL IGNBLK      ; *** TSTV ***
       SUI  "@"         ; TEST VARIABLES
       RC               ; 0:NOT A VARIABLE
       JNZ  TV1         ; NOT "@" ARRAY
       INX  D           ; IT IS THE "@" ARRAY
       CALL PARN        ; @ SHOULD BE FOLLOWED
       DAD  H           ; BY (EXPR) AS ITS INDEX
       JC   QHOW        ; IS INDEX TOO BIG?
TSTB   PUSH D           ; WILL IT FIT?
       XCHG
       CALL SIZE        ; FIND SIZE OF FREE
       CALL COMP        ; AND CHECK THAT
       JC   ASORRY      ; IF NOT, SAY "SORRY"
       CALL LOCR        ; IF FITS, GET ADDRESS
       DAD  D           ; OF @(EXPR) AND PUT IT
       POP  D           ; IN HL
       RET              ; C FLAG IS CLEARED
TV1    CPI 27           ; (ESC). NOT @. IS IT A TO Z?
       CMC              ; IF NOT RETURN C FLAG
       RC
       INX  D           ; IF A THROUGH Z
       LXI  H,VARBGN-2
       RLC              ; HL—>VARIABLE
       ADD  L           ; RETURN
       MOV  L,A         ; WITH C FLAG CLEARED
       MVI  A,0
       ADC  H
       MOV  H,A
       RET
;*
;**************************************
;*
;* *** TSTCH *** TSTNUM ***
;*
;* TSTCH IS USED TO TEST THE NEXT NON-BLANK CHARACTER IN THE TEXT
;* (POINTED BY DE) AGAINST THE CHARACTER THAT FOLLOWS THE CALL. IF
;* THEY DO NOT MATCH, N BYTES OF CODE WILL BE SKIPPED OVER. WHERE N IS
;* BETWEEN 0 AND 255 AND IS STORED IN THE SECOND BYTE FOLLOWING THE
;* CALL.
;*
;* TSTNUM IS USED TO CHECK WHETHER THE TEXT (POINTED BY DE) IS A
;* NUMBER. IF A NUMBER IS FOUND, B WILL BE NON-ZERO AND HL WILL
;* CONTAIN THE VALUE (IN BINARY) OF THE NUMBER, ELSE B AND HL ARE 0.
;*
TSTCH  XTHL             ; *** TSTCH ***
       CALL IGNBLK      ; IGNORE LEADING BLANKS
       CMP  M           ; AND TEST THE CHARACTER
       INX  H           ; COMPARE THE BYTE THAT
       JZ   TC1         ; FOLLOWS THE CALL INST.
       PUSH B           ; WITH THE TEXT (DE->)
       MOV  C,M         ; IF NOT =, ADD THE 2ND
       MVI  B,0         ; BYTE THAT FOLLOWS THE
       DAD  B           ; CALL TO THE OLD PC
       POP  B           ; I.E., DO A RELATIVE
       DCX  D           ; JUMP IF NOT =
TC1    INX  D           ; IF =, SKIP THOSE BYTES
       INX  H           ; AND CONTINUE
       XTHL
       RET
;*
TSTNUM LXI  H,0         ; *** TSTNUM ***
       MOV  B,H         ; TEST IF THE TEXT IS
       CALL IGNBLK      ; A NUMBER
TN1    CPI "0"          ; IF NOT, RETURN 0 IN
       RC               ; B AND HL
       CPI  ":"         ; IF NUMBERS, CONVERT
       RNC              ; TO BINARY IN HL AND
       MVI  A,F0H       ; SET B TO NUMBER OF DIGITS
       ANA  H           ; IF H>255, THERE IS NO
       JNZ  QHOW        ; ROOM FOR NEXT DIGIT
       INR  B           ; B COUNTS NUMBER OF DIGITS
       PUSH B
       MOV  B,H         ; HL=10*HL*(NEW DIGIT)
       MOV  C,L
       DAD  H           ; WHERE 10* IS DONE BY
       DAD  H           ; SHIFT AND ADD
       DAD  B
       DAD  H
       LDAX D           ; AND (DIGIT) IS FROM
       INX  D           ; STRIPPING THE ASCII
       ANI  0FH         ; CODE
       ADD  L
       MOV  L,A
       MVI  A,0
       ADC  H
       MOV  H,A
       POP  B
       LDAX D           ; DO THIS DIGIT AFTER
       JP   TN1         ; DIGIT. 5 SAYS OVERFLOW
QHOW   PUSH D           ; *** ERROR: "HOW?" ***
AHOW   LXI  D,HOW
       JMP  ERROR
;*
;**************************************
;*
;* *** MVUP *** MVDUWN *** POPA *** & PUSHA ***
;*
;* 'MVUP' MOVES A BLOCK UP FROM WHERE DE-> TO WHERE BC-> UNTIL DE=HL
;*
;* 'MVDOWN' MOVES A BLOCK DOWN FROM WHERE DE-> TO WHERE HL-> UNTIL DE=BC
;*
;* 'POPA' RESTORES THE 'FOR' LOOP VARIABLE SAVE AREA FROM THE STACK
;*
;* 'PUSHA' STACKS THE 'FOR' LOOP VARIABLE SAVE AREA INTO THE STACK
;*
MVUP   CALL COMP        ; *** MVUP ***
       RZ               ; DE = HL, RETURN
       LDAX D           ; GET ONE BYTE
       STAX B           ; MOVE IT
       INX  D           ; INCREASE BOTH POINTERS
       INX  B
       JMP  MVUP        ; UNTIL DONE
;*
MVDOWN MOV A,B          ; *** MVDOWN ***
       SUB  D           ; TEST IF DE = BC
       JNZ  MD1         ; NO, GO MOVE
       MOV  A,C         ; MAYBE, OTHER BYTE?
       SUB  E
       RZ               ; YES, RETURN
MD1    DCX  D           ; ELSE MOVE A BYTE
       DCX  H           ; BUT FIRST DECREASE
       LDAX D           ; BOTH POINTERS AND
       MOV  M,A         ; THEN DO IT
       JMP  MVDOWN      ; LOOP BACK
;*
POPA   POP  B           ; BC = RETURN ADDR
       POP  H           ; RESTORE LOPVAR, BUT
       SHLD LOPVAR      ; =0 MEANS NO MORE
       MOV  A,H
       ORA  L
       JZ   PP1         ; YEP, GO RETURN
       POP  H           ; NOP, RESTORE OTHERS
       SHLD LOPINC
       POP  H
       SHLD LOPLMT
       POP  H
       SHLD LOPLN
       POP  H
       SHLD LOPPT
PP1    PUSH B           ; BC = RETURN ADDR
       RET
;*
PUSHA  LXI  H,STKLMT    ; *** PUSHA ***
       CALL CHGSGN
       POP  B           ; BC=RETURN ADDRESS
       DAD  SP          ; IS STACK NEAR THE TOP?
       JNC  QSORRY      ; YES, SORRY FOR THAT
       LHLD LOPVAR      ; ELSE SAVE LOOP VAR'S
       MOV  A,H         ; BUT IF LOPVAR IS 0
       ORA  L           ; THAT WILL BE ALL
       JZ   PU1
       LHLD LOPPT       ; ELSE, MORE TO SAVE
       PUSH H
       LHLD LOPLN
       PUSH H
       LHLD LOPLMT
       PUSH H
       LHLD LOPINC
       PUSH H
       LHLD LOPVAR
PU1    PUSH H
       PUSH B           ; BC = RETURN ADDR
       RET
LOCR   LHLD TXTUNF
       DCX  H
       DCX  H
       RET
;*
;**************************************
;*
;* *** PRTSTG *** QTSTG *** PRTNUM *** & PRTLN ***
;*
;* 'PRTSTG' PRINTS A STRING POINTED BY DE. IT STOPS PRINTING AND
;* RETURNS TO CALLER WHEN EITHER A CR IS PRINTED OR WHEN THE NEXT BYTE
;* IS ZERO. REG. A AND B ARE CHANGED. REG. DE POINTS TO WHAT FOLLOWS
;* THE CR OR TO THE ZERO.
;*
;* 'QTSTG' LOOKS FOR UP-ARROW, SINGLE QUOTE, OR DOUBLE QUOTE. IF NONE
;* OF THESE, RETURN TO CALLER. IF UP-ARROW, OUTPUT A CONTROL
;* CHARACTER. IF SINGLE OR DOUBLE QUOTE, PRINT THE STRING IN THE QUOTE
;* AND DEMANDS A MATCHING UNQUOTE. AFTER THE PRINTING THE NEXT 3 BYTES
;* OF THE CALLER IS SKIPPED OVER (USUALLY A JUMP INSTRUCTION).
;*
;* 'PRTNUM' PRINTS THE NUMBER IN HL. LEADING BLANKS ARE ADDED IF
;* NEEDED TO PAD THE NUMBER OF SPACES TO THE NUMBER IN C. HOWEVER, IF
;* THE NUMBER OF DIGITS IS LARGER THAN THE NUMBER IN C, ALL DIGITS ARE
;* PRINTED ANYWAY. NEGATIVE SIGN IS ALSO PRINTED ANC COUNTED IN.
;* POSITIVE SIGN IS NOT.
;*
;* 'PRTLN' FINDS A SAVED LINE, PRINTS THE LINE NUMBER AND A SPACE.
;*
PRTSTG SUB  A           ; *** PRTSTG * + *
PS1    MOV  B,A
PS2    LDAX D           ; GET A CHARACTER
       INX  D           ; BUMP POINTER
       CMP  B           ; SAME AS OLD A?
       RZ               ; YES, RETURN
       CALL OUTCH       ; ELSE PRINT IT
       CPI  CR          ; WAS IT A CR?
       JNZ  PS2         ; NO, NEXT
       RET              ; YES, RETURN
;*
QTSTG  CALL TSTCH       ; *** QTSTG ***
       DB   """
       DB   QT3-$-1
       MVI  A,22H       ; IT IS A "
QT1    CALL PS1         ; PRINT UNTIL ANOTHER
QT2    CPI  CR          ; WAS LAST ONE A CR?
       POP  H           ; RETURN ADDRESS
       JZ   RUNNXL      ; WAS CR, RUN NEXT LINE
       INX  H           ; SKIP 3 BYTES ON RETURN
       INX  H
       INX  H
       PCHL             ; RETURN
QT3    CALL TSTCH       ; IS IT A ESC?
       DB   27H
       DB   QT4-$-1
       MVI  A,27H       ; YES, DO SAME
       JMP  QT1         ; AS IN "
QT4    CALL TSTCH       ; IS IT AN UP-ARROW?
       DB   "^"
       DB   QT5-$-1
       LDAX D           ; YES, CONVERT CHARACTER
       XRI  40H         ; TO CONTROL-CH. (@)
       CALL OUTCH
       LDAX D           ; JUST IN CASE IT IS A CR
       INX  D
       JMP  QT2
QT5    RET              ; NONE OF ABOVE
;*
PRTCHS MOV  A,E
       CMP  B
       RZ
       LDAX D
       CALL OUTCH
       INX  D
       JMP PRTCHS
;*
PRTNUM DS   0           ; *** PRTNUM ***
PN3    MVI  B,0         ; B=SIGN
       CALL CHKSGN      ; CHECK SIGN
       JP   PN4         ; NO SIGN
       MVI  B,"-"       ; B=SIGN
       DCR  C           ; TAKES SPACE
PN4    PUSH D
       LXI  D,10        ; DECIMAL
       PUSH D           ; SAVE AS A FLAG
       DCR  C           ; C=SPACES
       PUSH B           ; SAVE SIGN & SPACE
PN5    CALL DIVIDE      ; DIVIDE HL BY 10
       MOV  A,B         ; RESULT 0?
       ORA  C
       JZ   PN6         ; YES, ME GOT ALL
       XTHL             ; NO, SAVE REMAINDER
       DCR  L           ; AND COUNT SPACE
       PUSH H           ; HL IS OLD BC
       MOV  H,B         ; MOVE RESULT TO BC
       MOV  L,C
       JMP  PN5         ; AND DIVIDE BY 10
PN6    POP  B           ; WE GOT ALL DIGITS IN
PN7    DCR  C           ; THE STACK
       MOV  A,C         ; LOOK AT SPACE COUNT
       ORA  A
       JM   PN8         ; NO LEADING BLANKS
       MVI  A," "       ; LEADING BLANKS
       CALL OUTCH
       JMP  PN7         ; MORE?
PN8    MOV  A,B         ; PRINT SIGN
       ORA  A
       CNZ  OUTCH       ; MAYBE - OR NULL
       MOV  E,L         ; LAST REMAINDER IN E
PN9    MOV  A,E         ; CHECK DIGIT IN E
       CPI  10          ; 10 IS FLAG FOR NO MORE
       POP  D
       RZ               ; IF SO, RETURN
       ADI "0"          ; ELSE CONVERT TO ASCII
       CALL OUTCH       ; AND PRINT THE DIGIT
       JMP  PN9         ; GO BACK FOR MORE
;*
PRTLN  LDAX D           ; *** PRTLN ***
       MOV  L,A         ; LOW ORDER LINE NUMBER
       INX  D
       LDAX D           ; HIGH ORDER LINE NUMBER
       MOV  H,A
       INX  D
       MVI  C,4         ; PRINT 4 DIGIT LINE NUMBER
       CALL PRTNUM
       MVI  A," "       ; FOLLOWED BY A BLANK
       CALL OUTCH
       RET
;*
;*
;*
;* TAB1-1 IS THE TABLE OF ALL DIRECT AND STATEMENT COMMANDS.
;* THE TABLE CONSISTS OF ANY NUMBER OF ITEMS. EACH ITEM IS A STRING OF
;* CHARACTERS WITH BIT 7 SET TO 0 AND A JUMP ADDRESS STORED HI-LOW WITH
;* BIT 7 OF THE HIGH BYTE SET TO 1.
;* END OF TABLE IS AN ITEM WITH A JUMP ADDRESS ONLY.
;*
;*
;*
                     ;  *********************
TAB1   DB "LIST"     ; *** DIRECT COMMANDS ***
                     ;  *********************
       DB HIGH LIST,   LOW LIST
       DB "NEW"
       DB HIGH NEW,    LOW NEW
       DB "RUN"
       DB HIGH RUN,    LOW RUN
;*
                     ;  **********************
TAB2   DB "NEXT"     ; *** DIRECT/STATEMENT ***
                     ;  **********************
       DB HIGH NEXT,   LOW NEXT
       DB "LET"
       DB HIGH LET,    LOW LET
       DB "IF"
       DB HIGH IFF,    LOW IFF
       DB "GOTO"
       DB HIGH GOTO,   LOW GOTO
       DB "GOSUB"
       DB HIGH GOSUB,  LOW GOSUB
       DB "RETURN"
       DB HIGH RETURN, LOW RETURN
       DB "REM"
       DB HIGH REM,    LOW REM
       DB "FOR"
       DB HIGH FOR,    LOW FOR
       DB "INPUT"
       DB HIGH INPUT,  LOW INPUT
       DB "PRINT"
       DB HIGH PRINT,  LOW PRINT
       DB "STOP"
       DB HIGH STOP,   LOW STOP
       DB HIGH MOREC,  LOW MOREC
;*
                     ;  **********************
MOREC  JMP  DEFLT    ; *** JMP USER-COMMAND ***
                     ;  **********************
;*
TAB3   DB "RND"      ; *** FUNCTIONS ***
       DB HIGH RND,   LOW RND
       DB "ABS"
       DB HIGH ABS,   LOW ABS
       DB "SIZE"
       DB HIGH SIZE,  LOW SIZE
       DB HIGH MOREF, LOW MOREF
;*
                        ;  ***********************
MOREF  JMP  NOTF        ; *** JMP USER-FUNCTION ***
                        ;  ***********************
;*
TAB4   DB "TO"          ; "FOR" COMMAND
       DB HIGH FR1,   LOW FR1
       DB HIGH QWHAT, LOW QWHAT
;*
TAB5   DB "STEP"         ; "FOR" COMMAND
       DB HIGH FR2,   LOW FR2
       DB HIGH FR3,   LOW FR3
;*
                       ;  ************************
                       ; *** RELATION OPERATORS ***
                       ;  ************************
TAB6   DB ">="
       DB HIGH XPR1, LOW XPR1
       DB "#"
       DB HIGH XPR2, LOW XPR2
       DB ">"
       DB HIGH XPR3, LOW XPR3
       DB "="
       DB HIGH XPR5, LOW XPR5
       DB "<="
       DB HIGH XPR4, LOW XPR4
       DB "<"
       DB HIGH XPR6, LOW XPR6
       DB HIGH XPR7, LOW XPR7
RANEND EQU $
;*
;**************************************
;*
;* *** INPUT OUTPUT ROUTINES ***
;*
;* USER MUST VERIFY AND/OR MODIFY THESE ROUTINES
;*
;**************************************
;*
;* *** CRLF *** OUTCH ***
;*
;* CRLF WILL OUTPUT A CR. ONLY A & FLAGS MAY CHANGE AT RETURN
;*
;* OUTCH WILL OUTPUT THE CHARACTER IN A. IF THE CHARACTER IS CR, IT
;* WILL ALSO OUTPUT A LF AND THREE NULLS. FLAGS MAY CHANGE AT RETURN,
;* OTHER REGISTERS DO NOT.
;*
;* *** CHKIO *** GETLN ***
;*
;* CHKIO CHECKS TO SEE IF THERE IS ANY INPUT. IF NO INPUT, IT RETURNS
;* WITH Z FLAG. IF THERE IS INPUT, IT FURTHER CHECKS WHETHER INPUT IS
;* CONTROL—C. IF NOT CONTROL-C, IT RETURNS THE CHARACTER IN A WITH Z
;* FLAG CLEARED. IF INPUT IS CONTROL-C, CHKIO JUMPS TO 'INIT' AND WILL
;* NOT RETURN. ONLY A & FLAGS MAY CHANGE AT RETURN.
;*
;* 'GETLN' READS A INPUT LINE INTO 'BUFFER'. IT FIRST PROMPT THE
;* CHARACTER IN A (GIVEN BY THE CALLER), THEN IT FILLS THE THE BUFFER
;* AND ECHOS. BACK—SPACE IS USED TO DELETE THE LAST CHARATER (IF THERE
;* IS ONE). CR SIGNALS THE END OF THE LINE, AND CAUSE 'GETLN' TO
;* RETURN. WHEN BUFFER IS FULL, 'GETLN' WILL ACCEPT BACK-SPACE OR CR
;* ONLY AND WILL IGNORE (AND WILL NOT ECHO) OTHER CHARACTERS. AFTER
;* THE INPUT LINE IS STORED IN THE BUFFER, TWO MORE BYTES OF FF ARE
;* ALSO STORED AND DE POINTS TO THE LAST FF. A & FLAGS ARE ALSO
;* CHANGED AT RETURN.
;*
CRLF   MVI  A,CR        ; CR IN A
                        ;  *********************
OUTCH  JMP  XOUTX       ; *** JMP USER-OUTPUT ***
                        ;  *********************
CHKIO  JMP  XINX        ; *** JMP USER-INPUT ****
                        ;  *********************
GETLN  LXI  D,BUFFER    ; ***** MODIFY THIS *****
                        ;  *********************
GL1    CALL OUTCH       ; PROMPT OR ECHO
GL2    CALL CHKIO       ; GET A CHARACTER
       JZ   GL2         ; WAIT FOR INPUT
       CPI  LF
       JZ   GL2
GL3    STAX D           ; SAVE CH.
       CPI  08H         ; IS IT BACK-SPACE?
       JNZ  GL4         ; NO, MORE TESTS
       MOV  A,E         ; YES, DELETE?
       CPI  LOW BUFFER
       JZ   GL2         ; NOTHING TO DELETE
       LDAX D           ; DELETE
       DCX  D
       JMP  GL1
GL4    CPI  CR          ; WAS IT CR?
       JZ   GL5         ; YES, END OF LINE
       MOV  A,E         ; ELSE, MORE FREE ROOM?
       CPI  LOW BUFEND
       JZ   GL2         ; NO, WAIT FOR CR/RUB-OUT
       LDAX D           ; YES, BUMP POINTER
       INX  D
       JMP  GL1
GL5    INX  D           ; END OF LINE
       INX  D           ; BUMP POINTER
       MVI  A,FFH       ; PUT MARKER AFTER IT
       STAX D
       DCX  D
       JMP  CRLF
XOUTX  PUSH PSW         ; OUTPUT ROUTINE
OT1    IN   0           ; PRINT WHAT IS IN A
       ANI  01H         ; TBE BIT
       JZ   OT1         ; WAIT UNTIL READY
       POP  PSW
       OUT  1
       CPI  CR          ; WAS IT CR?
       RNZ              ; NO, RETURN
       MVI  A,LF        ; YES, GIVE LF
       CALL XOUTX
       MVI  A,CR
       RET
XINX   IN   0
       ANI  02H         ; DAV BIT
       RZ               ; NO INPUT, RETURN ZERO
       IN   1           ; CHECK INPUT
       ANI  07FH
       CPI  03H         ; IS IT CONTROL-C?
       RNZ              ; NO, RETURN CH.
       JMP INIT         ; YES, RESTART
       END
