;======================================================================
;  WS2812B RGB LED MATRIX DRIVER
;======================================================================
;  Target: ATmega128L @ 4MHz
;
;  Description:
;  This driver provides bit-banging control for WS2812B addressable RGB 
;  LEDs arranged in an 8×8 matrix configuration. It handles precise timing
;  requirements and provides helper functions for matrix addressing.
;
;  WS2812B Protocol Specifications:
;  - Single-wire interface using non-return-to-zero (NRZ) coding
;  - Strict timing: "0" bit = 0.4μs high + 0.85μs low
;                   "1" bit = 0.8μs high + 0.45μs low
;  - Reset condition: >50μs low
;  - Data sent in GRB order (not RGB)
;  - 24 bits per LED (8 bits per color channel)
;
;  Functions:
;  - ws_init: Initialize WS2812 pin as output
;  - ws_byte3wr: Transmit one RGB pixel (3 bytes)
;  - ws_reset: Latch data to LEDs
;  - ws_idx_xy: Convert X,Y coordinates to linear index
;  - ws_offset_idx: Calculate buffer address from linear index
;
;  Last Modified: May 25, 2025
;======================================================================

; file   ws2812_driver.asm          target ATmega128L-4 MHz
; purpose: reusable bit-bang driver + 8×8 XY helpers for WS2812B
;
.equ WS_PORT_REG = PORTD
.equ WS_DDR_REG  = DDRD
.equ WS_PIN_IDX  = 7
.equ WS_PIN_MASK = (1 << WS_PIN_IDX)

.equ WS_BUF_BASE = 0x0400          ; 8×8×3-byte frame buffer

;---------------------------------------------------------------------
;  REGISTER PRESERVATION - Save/restore registers during function calls
;---------------------------------------------------------------------
        .macro WS_PUSH_ALL
            push    a0
            push    a1
            push    a2
            push    u
            push    w
            push    r24
            push    r25
            push    ZH
            push    ZL
        .endm

        .macro WS_POP_ALL
            pop     ZL
            pop     ZH
            pop     r25
            pop     r24
            pop     w
            pop     u
            pop     a2
            pop     a1
            pop     a0
        .endm

;---------------------------------------------------------------------
;  BIT TRANSMISSION MACROS - Precisely timed bit patterns for WS2812B
;---------------------------------------------------------------------
; "0" bit total ≈ 5 cycles (T0H ≈ 0.40 μs, T0L ≈ 0.85 μs)
.macro WS_WR0
    clr  u                          ; u = 0  (destroys u **inside** routine)
    sbi  WS_PORT_REG, WS_PIN_IDX    ; high     (2 cy)
    out  WS_PORT_REG, u             ; low      (1 cy) full-port write
    nop                              ; 1 cy
    nop                              ; 1 cy
.endm
; "1" bit total ≈ 8 cycles (T1H ≈ 0.80 μs, T1L ≈ 0.45 μs)
.macro WS_WR1
    sbi  WS_PORT_REG, WS_PIN_IDX    ; high   (2 cy)
    nop                              ; 1 cy
    nop                              ; 1 cy
    cbi  WS_PORT_REG, WS_PIN_IDX    ; low    (2 cy)
.endm

;=====================================================================
;  PUBLIC INTERFACE FUNCTIONS
;=====================================================================

;---------------------------------------------------------------------
;  INITIALIZATION - Configure data pin for WS2812 control
;---------------------------------------------------------------------
; set the data pin as output
ws_init:
    OUTI WS_DDR_REG, WS_PIN_MASK
    ret

;---------------------------------------------------------------------
;  DATA TRANSMISSION - Send color data to WS2812 LEDs
;---------------------------------------------------------------------
; bit-bang three bytes  (G=a0, R=a1, B=a2)
; u & w pushed so the caller never sees them modified
ws_byte3wr:
    push  u
    push  w

    ; — byte G (a0) —
    ldi   w, 8
_b0:
    sbrc  a0, 7
        rjmp _b0_1
    WS_WR0
    rjmp  _b0_next
_b0_1:
    WS_WR1
_b0_next:
    lsl   a0
    dec   w
    brne  _b0

    ; — byte R (a1) —
    ldi   w, 8
_b1:
    sbrc  a1, 7
        rjmp _b1_1
    WS_WR0
    rjmp  _b1_next
_b1_1:
    WS_WR1
_b1_next:
    lsl   a1
    dec   w
    brne  _b1

    ; — byte B (a2) —
    ldi   w, 8
_b2:
    sbrc  a2, 7
        rjmp _b2_1
    WS_WR0
    rjmp  _b2_next
_b2_1:
    WS_WR1
_b2_next:
    lsl   a2
    dec   w
    brne  _b2

    pop   w
    pop   u
    ret

;---------------------------------------------------------------------
;  FRAME LATCHING - Signal end of frame to update LED display
;---------------------------------------------------------------------
; hold the data line low ≥50 μs to latch the frame
ws_reset:
    cbi  WS_PORT_REG, WS_PIN_IDX
    WAIT_US 50
    ret

;---------------------------------------------------------------------
;  COORDINATE CONVERSION - Matrix addressing utilities
;---------------------------------------------------------------------
; r24=x, r25=y → r24 = x + 8×y   (clobbers u, r24)
ws_idx_xy:
    mov  u, r25
    lsl  u
    lsl  u
    lsl  u
    add  r24, u
    ret

; r24=index → Z = WS_BUF_BASE + 3×index  (clobbers u, w, ZL, ZH)
ws_offset_idx:
    mov  w, r24                  ; w = idx
    lsl  w                       ; w = 2×idx
    mov  u, r24
    add  w, u                    ; w = 3×idx
    ldi  ZL, low (WS_BUF_BASE)
    ldi  ZH, high(WS_BUF_BASE)
    add  ZL, w
    clr  u
    adc  ZH, u                   ; add carry
    ret