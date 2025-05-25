;==============================================================================
; file: music.asm           target ATmega128L-4MHz-STK300
; purpose: Passacaglia Theme Player — repeats forever
;==============================================================================

    .org 0
    rjmp reset             ; one-and-only reset vector

    .include "macros.asm"
    .include "definitions.asm"
    .include "sound.asm"   ; sound driver

;— Duration constants (in 2.5 ms units) —
.equ DUR_E  =  50    ; eighth-note    = 125 ms
.equ DUR_Q  = 100    ; quarter-note   = 250 ms
.equ DUR_H  = 200    ; half-note      = 500 ms
.equ DUR_DQ = 150    ; dotted-qua.    = 375 ms
.equ DUR_DH = 300    ; dotted-half    = 750 ms

reset:
    ; initialize stack
    ldi   r16, high(RAMEND)
    out   SPH, r16
    ldi   r16, low(RAMEND)
    out   SPL, r16

    ; configure speaker pin on PE2
    sbi   DDRE, SPEAKER
    cbi   PORTE, SPEAKER

    ; load Z-pointer to start of table
    ldi   ZL, low(tbl)
    ldi   ZH, high(tbl)

player_loop:
    ld    r16, Z+          ; fetch period LSB
    cpi   r16, 0
    breq  restart_tune

    mov   a0, r16
    ld    r17, Z+          ; fetch duration
    mov   b0, r17
    rcall sound            ; play one note/rest
    rjmp  player_loop

restart_tune:
    ldi   ZL, low(tbl)
    ldi   ZH, high(tbl)
    rjmp  player_loop

tbl:
    .db so,  DUR_DQ    ; Bar 1: G (dotted-quarter), D (eighth), E? (quarter)
    .db re,  DUR_E
    .db rem, DUR_Q

    .db fa,  DUR_Q     ; Bar 2: F, D, B?
    .db re,  DUR_Q
    .db lam, DUR_Q

    .db so,  DUR_Q     ; Bar 3: G, E?, C
    .db rem, DUR_Q
    .db do,  DUR_Q

    .db re,  DUR_H     ; Bar 4: D (half), B? (quarter)
    .db lam, DUR_Q

    .db do,  DUR_Q     ; Bar 5: C, G, E?
    .db so,  DUR_Q
    .db rem, DUR_Q

    .db fa,  DUR_Q     ; Bar 6: F, D, G
    .db re,  DUR_Q
    .db so,  DUR_Q

    .db fa,  DUR_Q     ; Bar 7: F, E?, D
    .db rem, DUR_Q
    .db re,  DUR_Q

    .db do,  DUR_DH    ; Bar 8: C (dotted-half)

    ; terminator
    .db 0, 0