;======================================================================
;  ws2812b_4MHz_demo01_PD7_PD0_PC01.asm · ATmega128L @ 4 MHz · STK-300
;
;  Drive a WS2812B LED strip on PD7 while blinking LEDs on PC0/PC1
;  and reading a push-button on PD0 (internal pull-up).
;
;  Wiring:
;    • WS2812B DIN    ? PORTD.7 (PD7)
;    • Button “0”     ? PORTD.0 (PD0, active-low, pull-up)
;    • LED0 / LED1    ? PORTC.0 / PORTC.1 (high = on)
;======================================================================

            .include "macros.asm"
            .include "definitions.asm"

;----------------------------------------------------------------------
;  Configuration constants for WS2812 on PD7
;----------------------------------------------------------------------
            .equ  WS_PORT = PORTD
            .equ  WS_DDR  = DDRD
            .equ  WS_BIT  = 7

;----------------------------------------------------------------------
;  WS2812b4_WR0  — send a “0” bit on PD7
;----------------------------------------------------------------------
.macro WS2812b4_WR0
    clr    u                 ; u ? 0x00
    sbi    WS_PORT, WS_BIT   ; start T0H (drive high)
    out    WS_PORT, u        ; end T0H (drive low)
    nop
    nop
.endm

;----------------------------------------------------------------------
;  WS2812b4_WR1  — send a “1” bit on PD7
;----------------------------------------------------------------------
.macro WS2812b4_WR1
    sbi    WS_PORT, WS_BIT   ; start T1H (drive high)
    nop
    nop
    cbi    WS_PORT, WS_BIT   ; end T1H (drive low)
.endm

;======================================================================
;  Reset & Initialization
;======================================================================
            .org 0
            jmp   reset

reset:
    LDSP   RAMEND
    rcall  ws2812b4_init      ; configure PD7 as output

    ; LEDs on PC0/PC1 as outputs (active-high)
    OUTI   DDRC, (1<<0)|(1<<1)

    ; Button on PD0 input, enable pull-up
    OUTI   DDRD, 0x80
    OUTI   PORTD, (1<<0)

;----------------------------------------------------------------------
;  1. Store demo image in SRAM (unchanged)
;----------------------------------------------------------------------
main:
    ldi    b0, 20
    clr    b1
    ldi    zl, low(0x0400)
    ldi    zh, high(0x0400)

imgld_loop:
    ; pixel 1 – green
    ldi    a0, 0x0f  
    st     z+, a0
    ldi    a0, 0x00
    st     z+, a0
    ldi    a0, 0x00
    st     z+, a0

    ; pixel 2 – red
    ldi    a0, 0x00
    st     z+, a0
    ldi    a0, 0x0f
    st     z+, a0
    ldi    a0, 0x00
    st     z+, a0

    ; pixel 3 – blue
    ldi    a0, 0x00
    st     z+, a0
    ldi    a0, 0x00
    st     z+, a0
    ldi    a0, 0x0f
    st     z+, a0

    ; pixel 4 – off
    ldi    a0, 0x00
    st     z+, a0
    ldi    a0, 0x00
    st     z+, a0
    ldi    a0, 0x00
    st     z+, a0

    dec    b0
    brne  imgld_loop

;----------------------------------------------------------------------
;  2. Display + button loop (unchanged)
;----------------------------------------------------------------------
restart:
    ldi    zl, low(0x0400)
    ldi    zh, high(0x0400)
    add    zl, b1

    _LDI   r0, 64
loop:
    ld     a0, z+
    ld     a1, z+
    ld     a2, z+

    cli
    rcall  ws2812b4_byte3wr
    sei

    dec    r0
    brne  loop

    rcall  ws2812b4_reset

switch:
    sbic   PIND, 0            ; wait for button press (PD0 low)
    rjmp   cproc01
    sbis   PIND, 0            ; wait for release (PD0 high)
    rjmp   switch

    inc    b1                 ; scroll pattern
    INVP   PORTC, 1           ; toggle LED1
    jmp    restart

cproc01:
    INVP   PORTC, 0           ; blink LED0
    WAIT_MS 20
    rjmp   switch

;======================================================================
;  Subroutines
;======================================================================
ws2812b4_init:
    ; configure PD7 (WS_BIT) as output
    ldi    w, (1<<WS_BIT)
    out    WS_DDR, w
    ret

ws2812b4_byte3wr:
    ldi    w, 8
ws2b3_starta0:
    sbrc   a0, 7
    rjmp   ws2b3w1
    WS2812b4_WR0
    rjmp   ws2b3_nexta0
ws2b3w1:
    WS2812b4_WR1
ws2b3_nexta0:
    lsl    a0
    dec    w
    brne   ws2b3_starta0

    ldi    w, 8
ws2b3_starta1:
    sbrc   a1, 7
    rjmp   ws2b3w1a1
    WS2812b4_WR0
    rjmp   ws2b3_nexta1
ws2b3w1a1:
    WS2812b4_WR1
ws2b3_nexta1:
    lsl    a1
    dec    w
    brne   ws2b3_starta1

    ldi    w, 8
ws2b3_starta2:
    sbrc   a2, 7
    rjmp   ws2b3w1a2
    WS2812b4_WR0
    rjmp   ws2b3_nexta2
ws2b3w1a2:
    WS2812b4_WR1
ws2b3_nexta2:
    lsl    a2
    dec    w
    brne   ws2b3_starta2
    ret

ws2812b4_reset:
    cbi    WS_PORT, WS_BIT
    WAIT_US 50
    ret