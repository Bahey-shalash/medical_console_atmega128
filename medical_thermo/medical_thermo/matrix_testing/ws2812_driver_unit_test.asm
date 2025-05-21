; file: ws2812_driver_unit_test.asm
; target ATmega128L-4MHz
; tests: ws_init, ws_idx_xy, ws_offset_idx
; -----------------------------------------------------------------------------
; WHAT IT SHOULD DO:
; 1) ws_init: set WS_PIN_IDX bit in WS_DDR_REG (DDRD) to “1” (output).
; 2) ws_idx_xy: for each (x,y), return in r24 the value x + 8*y.
;    - Test vectors: (0,0)->0, (7,7)->63, (2,4)->34, (5,3)->29
; 3) ws_offset_idx: for each idx, set Z = WS_BUF_BASE + 3·idx.
;    - Test vectors: idx=0 ? Z = WS_BUF_BASE+0; idx=20 ? Z = WS_BUF_BASE+60
;  
; After running, inspect SRAM at WS_BUF_BASE:
;  • [0]   = DDRD value (bit 7 should be 1)
;  • [1..4]= ws_idx_xy results
;  • [5..6]= low,high bytes of WS_BUF_BASE+0
;  • [7..8]= low,high bytes of WS_BUF_BASE+60
; -----------------------------------------------------------------------------

.include "macros.asm"
.include "definitions.asm"

.org 0x0000
    rjmp start

.org 0x0040
 
start:
    ; now pull in the driver so its code lives after our vectors
	.include "ws2812_driver.asm"

    ; initialize stack
    LDSP    RAMEND

    ; --- 1) Test ws_init ---
    ldi     r16, 0x00
    out     WS_DDR_REG, r16     ; DDRD ? 0
    rcall   ws_init             ; should set bit WS_PIN_IDX=7
    in      r17, WS_DDR_REG     ; read DDRD
    ldi     ZL, low(WS_BUF_BASE)
    ldi     ZH, high(WS_BUF_BASE)
    st      Z+, r17             ; SRAM[0]=DDRD

    ; --- 2) Test ws_idx_xy ---
    ldi     r24, 0
    ldi     r25, 0
    rcall   ws_idx_xy
    st      Z+, r24             ; SRAM[1]=0

    ldi     r24, 7
    ldi     r25, 7
    rcall   ws_idx_xy
    st      Z+, r24             ; SRAM[2]=63

    ldi     r24, 2
    ldi     r25, 4
    rcall   ws_idx_xy
    st      Z+, r24             ; SRAM[3]=34

    ldi     r24, 5
    ldi     r25, 3
    rcall   ws_idx_xy
    st      Z+, r24             ; SRAM[4]=29

    ; --- 3) Test ws_offset_idx ---
    ldi     r24, 0
    rcall   ws_offset_idx
    mov     r18, ZL
    mov     r19, ZH
    st      Z+, r18             ; SRAM[5]=low(WS_BUF_BASE)
    st      Z+, r19             ; SRAM[6]=high(WS_BUF_BASE)

    ldi     r24, 20
    rcall   ws_offset_idx
    mov     r18, ZL
    mov     r19, ZH
    st      Z+, r18             ; SRAM[7]=low(WS_BUF_BASE+60)
    st      Z+, r19             ; SRAM[8]=high(WS_BUF_BASE+60)

hang:
    rjmp    hang                ; infinite loop—test done