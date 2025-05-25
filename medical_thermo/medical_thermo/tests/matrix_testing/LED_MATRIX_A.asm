; file   ws2812b_4MHz_demo01_PA_PD_PC.asm   target ATmega128L?4?MHz?STK300
; purpose  Drive a WS2812B LED matrix (PA1) while blinking LEDs (PC0/PC1)
;          and reading a push?button with **internal pull?up** (PD0).
;
; wiring ----------------------------------------------------------------------
;   • WS2812B DIN   ?  PORTA.1  (PA1)
;   • Button 0      ?  PORTD.0  (PD0, active?low, internal pull?up enabled)
;   • LED0 / LED1   ?  PORTC.0 / PORTC.1  (logic?high = LED on)
;
; Only port assignments/comments were changed; all timing?critical code and
; logic remain identical to the original working version.

.include "macros.asm"
.include "definitions.asm"

; -----------------------------------------------------------------------------
;  WS2812b4_WR0  — logic?0 bit on PA1
; -----------------------------------------------------------------------------
.macro WS2812b4_WR0
    clr u            ; preload 0x00
    sbi PORTA, 1     ; ? start T0H
    out PORTA, u     ; ? end T0H
    nop
    nop
.endm

; -----------------------------------------------------------------------------
;  WS2812b4_WR1  — logic?1 bit on PA1
; -----------------------------------------------------------------------------
.macro WS2812b4_WR1
    sbi PORTA, 1     ; ? start T1H
    nop
    nop
    cbi PORTA, 1     ; ? end T1H
.endm

.org 0
    jmp reset

; -----------------------------------------------------------------------------
;  Reset & initialisation
; -----------------------------------------------------------------------------
reset:
    LDSP  RAMEND                 ; set up stack
    rcall ws2812b4_init          ; configure PA1
    OUTI  DDRC, 0xff             ; PORTC outputs (LEDs)
    OUTI  DDRD, 0x00             ; PD0 input
    OUTI  PORTD, 0x01            ; enable pull?up on PD0

; -----------------------------------------------------------------------------
;  1. store demo image in SRAM (unchanged)
; -----------------------------------------------------------------------------
main:
    ldi  b0, 17
    clr  b1
    ldi  zl, low(0x0400)
    ldi  zh, high(0x0400)

imgld_loop:
    ldi a0, 0x0f  ; pixel 1 – green
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0

    ldi a0, 0x00  ; pixel 2 – red
    st  z+, a0
    ldi a0, 0x0f
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0

    ldi a0, 0x00  ; pixel 3 – blue
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x0f
    st  z+, a0

    ldi a0, 0x00  ; pixel 4 – off
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0

    dec b0
    brne imgld_loop

; -----------------------------------------------------------------------------
;  2. display + button loop (unchanged)
; -----------------------------------------------------------------------------
restart:
    ldi zl, low(0x0400)
    ldi zh, high(0x0400)
    add zl, b1

    _LDI r0, 64
loop:
    ld  a0, z+
    ld  a1, z+
    ld  a2, z+

    cli
    rcall ws2812b4_byte3wr
    sei

    dec r0
    brne loop

    rcall ws2812b4_reset

switch:
    sbic PIND, 0                 ; wait for press (goes low)
    rjmp cproc01
    sbis PIND, 0                 ; wait for release (returns high)
    rjmp PC-1

    inc  b1                      ; scroll pattern
    INVP PORTC, 1                ; toggle LED1
    jmp  restart

cproc01:
    INVP PORTC, 0                ; blink LED0
    WAIT_MS 20
    rjmp switch

; -----------------------------------------------------------------------------
;  Sub?routines (unchanged apart from port lett.)
; -----------------------------------------------------------------------------
ws2812b4_init:
    OUTI DDRA, 0x02              ; PA1 output
ret

ws2812b4_byte3wr:
    ldi w, 8
ws2b3_starta0:
    sbrc a0, 7
    rjmp ws2b3w1
    WS2812b4_WR0
    rjmp ws2b3_nexta0
ws2b3w1:
    WS2812b4_WR1
ws2b3_nexta0:
    lsl a0
    dec w
    brne ws2b3_starta0

    ldi w, 8
ws2b3_starta1:
    sbrc a1, 7
    rjmp ws2b3w1a1
    WS2812b4_WR0
    rjmp ws2b3_nexta1
ws2b3w1a1:
    WS2812b4_WR1
ws2b3_nexta1:
    lsl a1
    dec w
    brne ws2b3_starta1

    ldi w, 8
ws2b3_starta2:
    sbrc a2, 7
    rjmp ws2b3w1a2
    WS2812b4_WR0
    rjmp ws2b3_nexta2
ws2b3w1a2:
    WS2812b4_WR1
ws2b3_nexta2:
    lsl a2
    dec w
    brne ws2b3_starta2
ret

ws2812b4_reset:
    cbi PORTA, 1
    WAIT_US 50
ret
