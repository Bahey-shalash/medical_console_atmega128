; file   ws2812_demo_scroll.asm    target ATmega128L-4 MHz-STK300
; purpose  Scroll a 4-pixel pattern, blink LEDs on PC0/PC1 and poll a
;          push-button on PD0 while driving WS2812B chain on PA1.
;
; wiring ----------------------------------------------------------------------
;   • WS2812B DIN   ?  PORTA.1  (PA1)
;   • Button 0      ?  PORTD.0  (PD0, active-low, internal pull-up enabled)
;   • LED0 / LED1   ?  PORTC.0 / PORTC.1  (logic-high = LED on)
;
; includes --------------------------------------------------------------------
.include "macros.asm"
.include "definitions.asm"


; -----------------------------------------------------------------------------
.org 0x40  
    jmp reset

; base address of demo image in SRAM
.equ IMG_BASE = 0x0400
.include "ws2812_driver.asm"        ; generic driver (see above)
; -----------------------------------------------------------------------------
;  Reset & initialisation
; -----------------------------------------------------------------------------
reset:
    LDSP RAMEND
    rcall ws_init                      ; configure PA1
          OUTI DDRC, 0x03                    ; PC0|PC1 outputs
        ; PD7 = output (WS data), PD0 = input (button) + pull-up
        OUTI DDRD, (1<<7)                  ; DDRD7=1 ? PD7 output; DDRD0=0 ? PD0 input
        OUTI PORTD, (1<<0)                 ; PORTD0=1 ? pull-up on PD0

; -----------------------------------------------------------------------------
;  1. load demo pattern into SRAM (identical pixel data as original)
; -----------------------------------------------------------------------------
    ldi  b0, 17                        ; 17 × (4 pixels) so we can scroll
    clr  b1
    ldi  zl, low(IMG_BASE)
    ldi  zh, high(IMG_BASE)

img_load_loop:
    ; pixel 1 – green
    ldi a0, 0x0f  ; G
    st  z+, a0
    ldi a0, 0x00  ; R
    st  z+, a0
    ldi a0, 0x00  ; B
    st  z+, a0

    ; pixel 2 – red
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x0f
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0

    ; pixel 3 – blue
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x0f
    st  z+, a0

    ; pixel 4 – off
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0
    ldi a0, 0x00
    st  z+, a0

    dec b0
    brne img_load_loop

; -----------------------------------------------------------------------------
;  2. display / button / LED loop
; -----------------------------------------------------------------------------
    clr  b1                            ; scroll offset (0…95)

main_loop:
    ldi  zl, low(IMG_BASE)
    ldi  zh, high(IMG_BASE)
    add  zl, b1                        ; apply scroll offset

    _LDI r0, 64                        ; 64 × 24-bit words
pixel_loop:
    ld   a0, z+
    ld   a1, z+
    ld   a2, z+

    cli
    rcall ws_byte3wr                   ; send pixel
    sei

    dec  r0
    brne pixel_loop

    rcall ws_reset                     ; latch frame

; ----- button test -----------------------------------------------------------
button_wait:
    sbic PIND, 0                       ; wait for press (low)
    rjmp led1_toggle
    sbis PIND, 0                       ; wait for release (high)
    rjmp PC-1

    inc  b1                            ; next scroll position
    cpi  b1, 96
     brlo keep_scroll
    clr  b1
keep_scroll:
    INVP PORTC, 1                      ; toggle LED1
    rjmp main_loop

led1_toggle:
    INVP PORTC, 0                      ; blink LED0
    WAIT_MS 20
    rjmp button_wait