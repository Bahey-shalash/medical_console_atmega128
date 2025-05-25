; file   ws2812_test_xy.asm        target ATmega128L-4 MHz-STK300
; purpose Test XY helpers: light (0,0)=blue, (4,0)=red, (5,5)=green
; this works too; but better 
        .cseg
        .org    0
        rjmp    reset
        .org    0x56          ; skip full 43×2-byte vector table

.include "macros.asm"
.include "definitions.asm"
;.include "ws2812_driver_working_u.asm"      ; provides ws_init, ws_byte3wr, ws_reset,
                                  ; ws_idx_xy, ws_offset_idx
.include "ws2812_driver.asm" 
.include "lcd.asm"            ; lcd_clear, lcd_putc, LCD_init …
.include "printf.asm"         ; PRINTF macro 

reset:
    LDSP   RAMEND
    rcall  ws_init
    rcall  LCD_init                 ; **must** come before first LCD use

    rcall  lcd_clear
    PRINTF LCD
    .db    "Test XY",0
    WAIT_MS 500

; clear 8×8×3 = 192 bytes of frame buffer
    ldi    ZL, low(WS_BUF_BASE)
    ldi    ZH, high(WS_BUF_BASE)
    ldi    r18, 192
clr_loop:
    clr    u
    st     Z+, u
    dec    r18
    brne   clr_loop

; set pixel (0,0) ? blue
    ldi    r24, 0
    ldi    r25, 0
    rcall  ws_idx_xy
    rcall  ws_offset_idx
    ldi    a0, 0x00    ; G
    ldi    a1, 0x00    ; R
    ldi    a2, 0x0F    ; B
    st     Z+, a0
    st     Z+, a1
    st     Z,  a2

; set pixel (4,0) ? red
    ldi    r24, 4
    ldi    r25, 0
    rcall  ws_idx_xy
    rcall  ws_offset_idx
    ldi    a0, 0x00
    ldi    a1, 0x0F
    ldi    a2, 0x00
    st     Z+, a0
    st     Z+, a1
    st     Z,  a2

; set pixel (5,5) ? green
    ldi    r24, 5
    ldi    r25, 5
    rcall  ws_idx_xy
    rcall  ws_offset_idx
    ldi    a0, 0x0F
    ldi    a1, 0x00
    ldi    a2, 0x00
    st     Z+, a0
    st     Z+, a1
    st     Z,  a2

; stream the 64 pixels forever
main:
    ldi    ZL, low(WS_BUF_BASE)
    ldi    ZH, high(WS_BUF_BASE)
    _LDI   r0, 64
send:
    ld     a0, Z+
    ld     a1, Z+
    ld     a2, Z+
    cli
    rcall  ws_byte3wr
    sei
    dec    r0
    brne   send
    rcall  ws_reset
    rjmp   main