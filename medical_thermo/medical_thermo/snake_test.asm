;======================================================================
;  snake_buf_only.asm   · ATmega128L @ 4 MHz · STK-300
;  – Standalones draws a 3-pixel green “snake” at (3,3)…(5,3)
;======================================================================

        .cseg
        .org    0
        rjmp    reset
        .org    0x56               ; skip vector table

;----------------------------------------------------------------------
;  Pull in your WS2812 driver & helpers
;----------------------------------------------------------------------
        .include "macros.asm"
        .include "definitions.asm"
        .include "ws2812_driver.asm"

;----------------------------------------------------------------------
;  SRAM: define SnakeBuf and SnakeLen
;----------------------------------------------------------------------
        .dseg
SnakeBuf:   .byte 64               ; 0–63 indexes
SnakeLen:   .byte 1                ; number of segments
        .cseg

reset:
    LDSP   RAMEND
    rcall  ws_init                   ; PD7 output + timing set up

    ;?? preload buffer & length (in SRAM) ?????????????????????????????
    ; first three bytes = 27,28,29  (coordinates (3,3)…(5,3))
    ldi    ZL, low(SnakeBuf)
    ldi    ZH, high(SnakeBuf)
    ldi    r18, 27
    st     Z+, r18
    ldi    r18, 28
    st     Z+, r18
    ldi    r18, 29
    st     Z,  r18

    ; store length = 3
    ldi    r18, 3
    sts    SnakeLen, r18

;— clear the 192-byte WS frame buffer ---------------------------------
    ldi    ZL, low(WS_BUF_BASE)
    ldi    ZH, high(WS_BUF_BASE)
    ldi    r18, 192
clr_fb:
    clr    r19
    st     Z+, r19
    dec    r18
    brne   clr_fb

main:
    ;?? draw the three snake segments ??????????????????????????????????
    lds    r18, SnakeLen          ; segment counter
    ldi    YL, low(SnakeBuf)
    ldi    YH, high(SnakeBuf)
draw_loop:
    tst    r18
    breq   send_frame
    ld     r24, Y+                ; low = LED index
    clr    r25                    ; high = 0
    rcall  ws_idx_xy
    rcall  ws_offset_idx
    ldi    a0, 0x10               ; G = 0x10
    clr    a1                     ; R = 0
    clr    a2                     ; B = 0
    st     Z+, a0
    adiw   ZL, 1
    st     Z+, a1
    adiw   ZL, 1
    st     Z,  a2
    dec    r18
    rjmp   draw_loop

send_frame:
    ;?? stream 64 pixels forever (per-pixel IRQ mask) ?????????????????
    ldi    ZL, low(WS_BUF_BASE)
    ldi    ZH, high(WS_BUF_BASE)
    _LDI   r0, 64
stream:
    ld     a0, Z+
    ld     a1, Z+
    ld     a2, Z+
    cli
    rcall  ws_byte3wr
    sei
    dec    r0
    brne   stream
    rcall  ws_reset               ; latch (>50 µs)
    rjmp   main
;======================================================================