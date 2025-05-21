;======================================================================
;  snake_test_xy.asm   · ATmega128L @ 4?MHz · STK-300
;  -------------------------------------------------------------------
;  Stand-alone: light (3,3), (4,3), (5,3) in green on an 8×8 WS2812 matrix
;======================================================================

        .cseg
        .org    0
        rjmp    reset
        .org    0x56          ; skip vector table

.include "macros.asm"
.include "definitions.asm"
.include "ws2812_driver.asm"      ; ws_init, ws_byte3wr, ws_reset,
                                  ; ws_idx_xy, ws_offset_idx

reset:
    LDSP    RAMEND
    rcall   ws_init               ; configure PD7, timing

; clear 8×8×3 = 192-byte frame buffer
    ldi     ZL, low(WS_BUF_BASE)
    ldi     ZH, high(WS_BUF_BASE)
    ldi     r18, 192
clr_loop:
    clr     u
    st      Z+, u
    dec     r18
    brne    clr_loop

; set snake pixel at (3,3) = green
    ldi     r24, 3       ; x = 3
    ldi     r25, 3       ; y = 3
    rcall   ws_idx_xy
    rcall   ws_offset_idx
    ldi     a0, 0x10     ; G = 0x10
    clr     a1          ; R = 0
    clr     a2          ; B = 0
    st      Z+, a0
    st      Z+, a1
    st      Z,  a2

; set snake pixel at (4,3)
    ldi     r24, 4
    ldi     r25, 3
    rcall   ws_idx_xy
    rcall   ws_offset_idx
    ldi     a0, 0x10
    clr     a1
    clr     a2
    st      Z+, a0
    st      Z+, a1
    st      Z,  a2

; set snake pixel at (5,3)
    ldi     r24, 5
    ldi     r25, 3
    rcall   ws_idx_xy
    rcall   ws_offset_idx
    ldi     a0, 0x10
    clr     a1
    clr     a2
    st      Z+, a0
    st      Z+, a1
    st      Z,  a2

; stream the 64 pixels forever
main:
    ldi     ZL, low(WS_BUF_BASE)
    ldi     ZH, high(WS_BUF_BASE)
    _LDI   r0, 64
send:
    ld      a0, Z+
    ld      a1, Z+
    ld      a2, Z+
    cli
    rcall   ws_byte3wr
    sei
    dec     r0
    brne    send
    rcall   ws_reset             ; latch (?50 µs LOW)
    rjmp    main