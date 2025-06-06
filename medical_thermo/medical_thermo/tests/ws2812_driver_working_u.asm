; file   ws2812_driver.asm          target ATmega128L-4 MHz
; purpose: reusable bit-bang driver + 8�8 XY helpers for WS2812B
;
; ????? ROUTINE REGISTER-USAGE SUMMARY (after this patch) ?????????????
;  routine         reads            clobbers (caller must save)       
; ?????????????????????????????????????????????????????????????????????
;  ws_init         �                �                                 
;  ws_byte3wr      a0 a1 a2         a0 a1 a2          (u,w are saved) 
;  ws_reset        �                �                                 
;  ws_idx_xy       r24 r25          r24 u                            
;  ws_offset_idx   r24              u w ZL ZH                        
;  (SREG always changes as any normal arithmetic will.)               
; ?????????????????????????????????????????????????????????????????????
;
; If your code needs a0�a2 kept, push them before calling ws_byte3wr.
;
; ????? pin configuration (override before .include if you wish) ?????
.equ WS_PORT_REG = PORTD
.equ WS_DDR_REG  = DDRD
.equ WS_PIN_IDX  = 7
.equ WS_PIN_MASK = (1 << WS_PIN_IDX)

.equ WS_BUF_BASE = 0x0400          ; 8�8�3-byte frame buffer

; ????? timing-critical bit macros (4 MHz) ????????????????????????????
; �0� bit total ? 5 cycles (T0H ? 0.40 �s, T0L ? 0.85 �s)
.macro WS_WR0
    clr  u                          ; u = 0  (destroys u **inside** routine)
    sbi  WS_PORT_REG, WS_PIN_IDX    ; high     (2 cy)
    out  WS_PORT_REG, u             ; low      (1 cy) full-port write
    nop                              ; 1 cy
    nop                              ; 1 cy
.endm
; �1� bit total ? 8 cycles (T1H ? 0.80 �s, T1L ? 0.45 �s)
.macro WS_WR1
    sbi  WS_PORT_REG, WS_PIN_IDX    ; high   (2 cy)
    nop                              ; 1 cy
    nop                              ; 1 cy
    cbi  WS_PORT_REG, WS_PIN_IDX    ; low    (2 cy)
.endm

; ????????????????? PUBLIC ROUTINES ???????????????????????????????????

; set the data pin as output
ws_init:
    OUTI WS_DDR_REG, WS_PIN_MASK
    ret

; bit-bang three bytes  (G=a0, R=a1, B=a2)
; u & w pushed so the caller never sees them modified
ws_byte3wr:
    push  u
    push  w

    ; ? byte G (a0) ?
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

    ; ? byte R (a1) ?
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

    ; ? byte B (a2) ?
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

; hold the data line low ?50 �s to latch the frame
ws_reset:
    cbi  WS_PORT_REG, WS_PIN_IDX
    WAIT_US 50
    ret

; r24=x, r25=y  ? r24 = x + 8�y   (clobbers u, r24)
ws_idx_xy:
    mov  u, r25
    lsl  u
    lsl  u
    lsl  u
    add  r24, u
    ret

; r24=index ? Z = WS_BUF_BASE + 3�index  (clobbers u, w, ZL, ZH)
ws_offset_idx:
    mov  w, r24                  ; w = idx
    lsl  w                       ; w = 2�idx
    mov  u, r24
    add  w, u                    ; w = 3�idx
    ldi  ZL, low (WS_BUF_BASE)
    ldi  ZH, high(WS_BUF_BASE)
    add  ZL, w
    clr  u
    adc  ZH, u                   ; add carry
    ret