; file   ws2812_driver.asm          target ATmega128L-4 MHz
; purpose  Reusable bit-bang driver for one WS2812B chain.
;          All timing-critical code and helper routines live here.
;
; usage -----------------------------------------------------------------------
;   1) Adjust the three .equ constants below if you move the data line.
;   2) In your application:
;          .include "macros.asm"
;          .include "definitions.asm"
;          .include "ws2812_driver.asm"
;          …
;          rcall ws_init           ; once at start-up
;          ; tmp0 = G, tmp1 = R, tmp2 = B
;          rcall ws_byte3wr
;          …
;          rcall ws_reset          ; ?50 µs low to latch frame
;
; NOTE  expects the aliases a0/a1/a2/u/w/tmp? already defined
;       by   definitions.asm
; -----------------------------------------------------------------------------

; ------ user-adjustable port selection ---------------------------------------
.equ WS_PORT_REG = PORTA            ; data-out port
.equ WS_DDR_REG  = DDRA             ; data-out DDR
.equ WS_PIN_IDX  = 1                ; bit number (0-7)
.equ WS_PIN_MASK = 0x02             ; (1 << WS_PIN_IDX)
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
;  WS_WR0  — transmit logic-0 bit on WS_PORT_REG.WS_PIN_IDX
; -----------------------------------------------------------------------------
.macro WS_WR0
    clr u                       ; preload 0x00
    sbi  WS_PORT_REG, WS_PIN_IDX ; ? start T0H
    out  WS_PORT_REG, u         ; ? end T0H
    nop
    nop
.endm

; -----------------------------------------------------------------------------
;  WS_WR1  — transmit logic-1 bit on WS_PORT_REG.WS_PIN_IDX
; -----------------------------------------------------------------------------
.macro WS_WR1
    sbi  WS_PORT_REG, WS_PIN_IDX ; ? start T1H
    nop
    nop
    cbi  WS_PORT_REG, WS_PIN_IDX ; ? end T1H
.endm

; -----------------------------------------------------------------------------
;  Public sub-routines
; -----------------------------------------------------------------------------
;  ws_init       – make data pin output (call once)
;  ws_byte3wr    – write 24-bit GRB from a0/a1/a2 (destroys w)
;  ws_reset      – hold low ?50 µs (uses WAIT_US)
; -----------------------------------------------------------------------------

; -- configure data pin --------------------------------------------------------
ws_init:
    OUTI WS_DDR_REG, WS_PIN_MASK     ; set pin as output
ret

; -- write three bytes G,R,B ---------------------------------------------------
ws_byte3wr:
    ldi w, 8
wsb3_g_start:
    sbrc a0, 7
    rjmp wsb3_g1
    WS_WR0
    rjmp wsb3_g_next
wsb3_g1:
    WS_WR1
wsb3_g_next:
    lsl a0
    dec w
    brne wsb3_g_start

    ldi w, 8
wsb3_r_start:
    sbrc a1, 7
    rjmp wsb3_r1
    WS_WR0
    rjmp wsb3_r_next
wsb3_r1:
    WS_WR1
wsb3_r_next:
    lsl a1
    dec w
    brne wsb3_r_start

    ldi w, 8
wsb3_b_start:
    sbrc a2, 7
    rjmp wsb3_b1
    WS_WR0
    rjmp wsb3_b_next
wsb3_b1:
    WS_WR1
wsb3_b_next:
    lsl a2
    dec w
    brne wsb3_b_start
ret

; -- latch frame ---------------------------------------------------------------
ws_reset:
    cbi  WS_PORT_REG, WS_PIN_IDX
    WAIT_US 50
ret