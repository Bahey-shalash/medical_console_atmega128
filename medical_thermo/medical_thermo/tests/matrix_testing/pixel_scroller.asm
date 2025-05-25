;========================================================================
; pixel_scroller.asm
;
; Lights a single white pixel at (3,7) on an 8×8 WS2812 matrix (PD7)
; and moves it left/right with a quadrature encoder on PORTE (PE4).
;
; Uses:
;   m128def.inc         ; defines INTxaddr, I/O regs, RAMEND, etc.
;   definitions.asm    ; clock=4 MHz, register aliases
;   macros.asm         ; INC_CYC, pointer helpers, etc.
;   ws2812_driver.asm  ; WS_PORT_REG=PORTD, WS_PIN_IDX=7, ws_init…ws_idx_xy
;   encoder.asm        ; encoder_init, encoder_update (Δ in r3)
;========================================================================

    .include "m128def.inc"
    .include "definitions.asm"
    .include "macros.asm"
   
;—— RAM ——
.dseg
x_pos:  .byte 1      ; current X coordinate (0..7)

;—— VECTORS & RESET ——
.cseg
    .org 0
      rjmp reset

    .org INT4addr
      rjmp encoder_isr
 .include "ws2812_driver.asm"
    .include "encoder.asm"

;========================================================================
reset:
    ; Initialize stack pointer
    ldi  r16, high(RAMEND)
    out  SPH, r16
    ldi  r16, low(RAMEND)
    out  SPL, r16

    ;—— WS2812 init & clear all 64 pixels ——
    rcall ws_init
    ldi  r16, 64
clear_loop:
    clr  a0           ; G=0
    clr  a1           ; R=0
    clr  a2           ; B=0
    rcall ws_byte3wr
    dec  r16
    brne clear_loop
    rcall ws_reset    ; latch

    ;—— Initial pixel at (3,7) ——
    ldi  r16, 3
    sts  x_pos, r16
    rcall update_pixel

    ;—— Encoder setup: any‐change on INT4 (PE4) ——
    rcall encoder_init
    ldi  r16, (1<<ISC40)    ; ISC41=0, ISC40=1 → any edge
    out  EICRB, r16
    ldi  r16, (1<<INT4)     ; enable INT4
    out  EIMSK, r16
    sei                     ; global interrupts

main:
    rjmp main               ; idle; all work in ISR

;========================================================================
; encoder_isr — handle PE4 change, update x_pos, redraw pixel
;========================================================================
encoder_isr:
    push  r24
    push  r25
    push  r1
    in    r1, SREG
    push  r1
    push  r3                ; save u

    rcall encoder_update    ; Δ = ±1 → r3

    lds   r24, x_pos
    add   r24, r3
    cpi   r24, 8
    brlo  no_high_clip
    ldi   r24, 7
    rjmp  store_x
no_high_clip:
    tst   r24
    brpl  store_x
    ldi   r24, 0
store_x:
    sts   x_pos, r24

    rcall update_pixel

    pop   r3
    pop   r1
    out   SREG, r1
    pop   r1
    pop   r25
    pop   r24
    reti

;========================================================================
; update_pixel — bit-bang all 64 LEDs, white at (x_pos,7), then latch
;========================================================================
update_pixel:
    push  r20
    push  r21

    lds   r24, x_pos      ; r24 = X
    ldi   r25, 7          ; r25 = Y
    rcall ws_idx_xy       ; r24 = idx = X + 8·Y
    mov   r21, r24        ; save idx

    clr   r20             ; r20 = count

zero_loop:
    cp    r20, r21
    breq  led_pixel
    clr   a0
    clr   a1
    clr   a2
    rcall ws_byte3wr
    inc   r20
    rjmp  zero_loop

led_pixel:
    ldi   a0, 0xFF        ; G
    ldi   a1, 0xFF        ; R
    ldi   a2, 0xFF        ; B
    rcall ws_byte3wr
    inc   r20

trail_loop:
    cpi   r20, 64
    brge  done
    clr   a0
    clr   a1
    clr   a2
    rcall ws_byte3wr
    inc   r20
    rjmp  trail_loop

done:
    rcall ws_reset        ; latch

    pop   r21
    pop   r20
    ret