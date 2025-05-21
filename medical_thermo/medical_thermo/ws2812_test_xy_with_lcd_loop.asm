; file: ws2812_test_xy_with_lcd_loop.asm          target ATmega128L-4 MHz (STK300)
; purpose: light three test pixels on an 8×8 WS2812 matrix
;          while the LCD repeatedly prints “Test XY”.

        .cseg
        .org  0
        rjmp  reset
        .org  0x56                       ; skip 43×2-byte vector table

; ?? includes ??????????????????????????????????????????????????????????
.include "macros.asm"
.include "definitions.asm"
.include "lcd.asm"            ; lcd_clear, lcd_putc, LCD_init …
.include "printf.asm"         ; PRINTF macro
.include "ws2812_driver.asm"  ; ws_init, ws_byte3wr, … + WS_PUSH_ALL/POP_ALL

; ?? reset & initialisation ???????????????????????????????????????????
reset:
        LDSP   RAMEND
        rcall  ws_init
        rcall  LCD_init                 ; **must** come before first LCD use

        rcall  lcd_clear
        PRINTF LCD
        .db    "Test XY",0
        WAIT_MS 500

; ?? clear 8×8×3-byte frame buffer (192 B) ????????????????????????????
        ldi    ZL, low (WS_BUF_BASE)
        ldi    ZH, high(WS_BUF_BASE)
        ldi    r18, 192
        clr    r0                       ; r0 is now guaranteed 0
clr_fb:
        st     Z+, r0
        dec    r18
        brne   clr_fb

; ?? set three coloured test pixels once ??????????????????????????????
        ; (0,0) ? blue
        ldi    r24,0
        ldi    r25,0
        rcall  ws_idx_xy
        rcall  ws_offset_idx
        ldi    a0,0x00  ; G
        ldi    a1,0x00  ; R
        ldi    a2,0x0F  ; B
        st     Z+, a0
        st     Z+, a1
        st     Z , a2

        ; (4,0) ? red
        ldi    r24,4
        ldi    r25,0
        rcall  ws_idx_xy
        rcall  ws_offset_idx
        ldi    a0,0x00
        ldi    a1,0x0F
        ldi    a2,0x00
        st     Z+, a0
        st     Z+, a1
        st     Z , a2

        ; (5,5) ? green
        ldi    r24,5
        ldi    r25,5
        rcall  ws_idx_xy
        rcall  ws_offset_idx
        ldi    a0,0x0F
        ldi    a1,0x00
        ldi    a2,0x00
        st     Z+, a0
        st     Z+, a1
        st     Z , a2

; ?? main loop ????????????????????????????????????????????????????????
main:
        ; 1) update LCD
        rcall  lcd_clear
        PRINTF LCD
        .db    "Test XY",0
        WAIT_MS 200                    ; ? 5 Hz update rate

        ; 2) stream frame buffer to LEDs (only our 3 non-zero pixels will show)
        WS_PUSH_ALL
            ldi    ZL, low (WS_BUF_BASE)
            ldi    ZH, high(WS_BUF_BASE)
            _LDI   r0, 64              ; 64 pixels
        send_px:
            ld     a0, Z+
            ld     a1, Z+
            ld     a2, Z+
            cli
            rcall  ws_byte3wr          ; ~1.2 µs, u & w auto-saved inside
            sei
            dec    r0
            brne   send_px
            rcall  ws_reset
        WS_POP_ALL

        rjmp   main


;LETS GOOOOOOOOOOOOOOOOOOOOOOO IT WORKEDDDDDDDDD