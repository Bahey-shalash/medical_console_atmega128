; file   ws2812_driver.asm          target ATmega128L-4 MHz
; purpose Reusable bit-bang driver + 8×8 XY helpers for WS2812B
;
; usage: in your app…
;   .include "macros.asm"
;   .include "definitions.asm"
;   .include "ws2812_driver.asm"
;   …
;   rcall ws_init        ; PA1 output
;   ; load a0=G, a1=R, a2=B
;   rcall ws_byte3wr
;   …
;   rcall ws_reset       ; latch (?50 µs low)
;
; expects: a0/a1/a2/u/w as per definitions.asm
; -----------------------------------------------------------------------------

; user?override before include if you wire WS DIN elsewhere:
.equ WS_PORT_REG = PORTA
.equ WS_DDR_REG  = DDRA
.equ WS_PIN_IDX  = 1
.equ WS_PIN_MASK = (1 << WS_PIN_IDX)

.equ WS_BUF_BASE = 0x0400    ; SRAM frame buffer start (8×8×3 bytes)

; -----------------------------------------------------------------------------
; timing?critical bit macros (4 MHz)
; -----------------------------------------------------------------------------
.macro WS_WR0
    clr  u
    sbi  WS_PORT_REG, WS_PIN_IDX
    out  WS_PORT_REG, u
    nop
    nop
.endm

.macro WS_WR1
    sbi  WS_PORT_REG, WS_PIN_IDX
    nop
    nop
    cbi  WS_PORT_REG, WS_PIN_IDX
.endm

; -----------------------------------------------------------------------------
; PUBLIC: ws_init, ws_byte3wr, ws_reset
; -----------------------------------------------------------------------------
ws_init:
    OUTI WS_DDR_REG, WS_PIN_MASK
    ret

ws_byte3wr:
    ldi   w, 8
_b0:
    sbrc  a0, 7
    rjmp  _b0_1
    WS_WR0
    rjmp  _b0_next
_b0_1:
    WS_WR1
_b0_next:
    lsl   a0
    dec   w
    brne  _b0

    ldi   w, 8
_b1:
    sbrc  a1, 7
    rjmp  _b1_1
    WS_WR0
    rjmp  _b1_next
_b1_1:
    WS_WR1
_b1_next:
    lsl   a1
    dec   w
    brne  _b1

    ldi   w, 8
_b2:
    sbrc  a2, 7
    rjmp  _b2_1
    WS_WR0
    rjmp  _b2_next
_b2_1:
    WS_WR1
_b2_next:
    lsl   a2
    dec   w
    brne  _b2
    ret

ws_reset:
    cbi   WS_PORT_REG, WS_PIN_IDX
    WAIT_US 50
    ret

; -----------------------------------------------------------------------------
; PUBLIC: ws_idx_xy, ws_offset_idx
; -----------------------------------------------------------------------------
; r24?x, r25?y ? r24 = x + 8·y
ws_idx_xy:
    mov   u, r25
    lsl   u
    lsl   u
    lsl   u
    add   r24, u
    ret

; r24=index ? Z = WS_BUF_BASE + 3·index
ws_offset_idx:
    mov   w, r24       ; w = idx
    lsl   w            ; w = 2·idx
    mov   u, r24       ; u = idx
    add   w, u         ; w = 3·idx
    ldi   ZL, low(WS_BUF_BASE)
    ldi   ZH, high(WS_BUF_BASE)
    add   ZL, w
    clr   u
    adc   ZH, u        ; add carry only
    ret