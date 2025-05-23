;======================================================================
;  SNAKE state – ST_GAME1 (static apple + wall-collision)
;  · 8×8 WS2812 matrix
;  · 3-segment snake — blue head / green body
;  · Static red apple at (5,5)
;  · Rotary-encoder steering (@1 kHz queue)
;  · NEW: border collision → “GAME OVER” freeze until state change
;======================================================================

;---------------------------------------------------------------------
; SRAM layout
;---------------------------------------------------------------------
.dseg
snake_body:   .byte 64      ; packed x + 8*y (0xFF = empty)
head_idx:     .byte 1
tail_idx:     .byte 1
snake_len:    .byte 1

direction:    .byte 1       ; 0=Up 1=Right 2=Down 3=Left
apple_pos:    .byte 1       ; packed apple pixel (5 + 8*5 = 45)

turn_queue:   .byte 8
tq_head:      .byte 1
tq_tail:      .byte 1
.cseg

;======================================================================
; Initialization & Main Loop
;======================================================================

snake_game_init:
    rcall lcd_clear
    PRINTF LCD
    .db "SNAKE",0

    rcall encoder_init
    rcall snake_init_data
    rcall snake_draw
    rjmp snake_wait

snake_wait:
    ldi r24, low(500)
    ldi r25, high(500)
wait_loop:
    rcall update_game
    WAIT_MS 1
    sbiw r24,1
    brne wait_loop

    rcall move_snake
    rcall snake_draw

    mov  s, sel
    _CPI s, ST_GAME1
    breq wait_loop
    ret

;---------------------------------------------------------------------
snake_init_data:
    ; fill body buffer with 0xFF
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi r22, 64
clrbuf:
    ldi w, 0xFF
    st  Z+, w
    dec r22
    brne clrbuf

    ; seed snake at (2,3),(3,3),(4,3)
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi w, 26
    st  Z+, w
    ldi w, 27
    st  Z+, w
    ldi w, 28
    st  Z , w

    ; init indices & length
    ldi w,2
    sts head_idx, w
    clr w
    sts tail_idx, w
    ldi w,3
    sts snake_len, w

    ; initial heading RIGHT
    ldi w,1
    sts direction, w

    ; static apple at (5,5)
    ldi w,45
    sts apple_pos, w

    ; reset FIFO & encoder counters
    clr w
    sts tq_head, w
    sts tq_tail, w
    clr a0
    clr b0
    in  w, ENCOD
    sts enc_old, w
    ret

;======================================================================
; update_game – encoder → turn FIFO (unchanged)
;======================================================================
update_game:
    push r25
    push r24
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23

    rcall encoder_update      ; r15 = ±1 or 0
    mov  r19, r15
    tst  r19
    brne cont_upd
    rjmp exit_upd

cont_upd:
    lds   r21, direction
    tst   r19
    brmi turn_left

turn_right:
    mov   r20, r21
    inc   r20
    cpi   r20,4
    brlo  chk_rev
    clr   r20
    rjmp  chk_rev

turn_left:
    mov   r20, r21
    tst   r20
    brne  tl_ok
    ldi   r20,3
    rjmp  chk_rev
tl_ok:
    dec   r20

chk_rev:
    mov   r22, r21
    subi  r22, -2
    andi  r22,0x03
    cp    r20, r22
    breq  exit_upd

    lds   r23, tq_head
    mov   r24, r23
    inc   r24
    andi  r24,0x07
    lds   r22, tq_tail
    cp    r24, r22
    breq  exit_upd

    ldi   ZL, low(turn_queue)
    ldi   ZH, high(turn_queue)
    add   ZL, r23
    brcc  qok
    inc   ZH
qok:
    st    Z, r20
    sts   tq_head, r24

    lds   r22, tq_tail
    lds   r23, tq_head
    cp    r22, r23
    breq  exit_upd

    ldi   ZL, low(turn_queue)
    ldi   ZH, high(turn_queue)
    add   ZL, r22
    brcc  dqok
    inc   ZH
dqok:
    ld    r20, Z
    inc   r22
    andi  r22,0x07
    sts   tq_tail, r22
    sts   direction, r20

exit_upd:
    pop   r23
    pop   r22
    pop   r21
    pop   r20
    pop   r19
    pop   r18
    pop   r24
    pop   r25
    ret

;======================================================================
; move_snake – abort on border collision → freeze until state change
;======================================================================
move_snake:
    lds   r18, direction

    ; fetch current head → r20
    lds   r19, head_idx
    ldi   ZL, low(snake_body)
    ldi   ZH, high(snake_body)
    add   ZL, r19
    brcc  head_ok
    inc   ZH
head_ok:
    ld    r20, Z

    ; unpack x=r21, y=r22
    mov   r21, r20
    andi  r21,0x07
    mov   r22, r20
    swap  r22
    andi  r22,0x07

    ; WALL CHECK & next step
    cpi   r18,1         ; RIGHT?
    breq  do_right
    cpi   r18,3         ; LEFT?
    breq  do_left
    cpi   r18,0         ; UP?
    breq  do_up
    ; DOWN
    inc   r22
    cpi   r22,8
    breq  hit_wall
    rjmp  pack_move

do_right:
    inc   r21
    cpi   r21,8
    breq  hit_wall
    rjmp  pack_move

do_left:
    tst   r21
    breq  hit_wall
    dec   r21
    rjmp  pack_move

do_up:
    tst   r22
    breq  hit_wall
    dec   r22

pack_move:
    mov   r20, r21
    mov   _w, r22
    swap  _w
    andi  _w,0x70
    or    r20, _w

    lds   r19, head_idx
    inc   r19
    cpi   r19,64
    brlo  idx_ok2
    clr   r19
idx_ok2:
    sts   head_idx, r19
    ldi   ZL, low(snake_body)
    ldi   ZH, high(snake_body)
    add   ZL, r19
    brcc  wr_ok2
    inc   ZH
wr_ok2:
    st    Z, r20

    lds   r21, tail_idx
    inc   r21
    cpi   r21,64
    brlo  tl_ok2
    clr   r21
tl_ok2:
    sts   tail_idx, r21
    ret

hit_wall:
    rcall lcd_clear
    PRINTF LCD
    .db "GAME OVER",0
freeze_loop:
    mov   r18, sel
    _CPI  r18, ST_GAME1
    breq  freeze_loop
    ret

;======================================================================
; snake_draw – unchanged (draw snake then static apple)
;======================================================================
snake_draw:
    clr a0
    clr a1
    clr a2
    rcall matrix_solid

    lds  r23, tail_idx
    lds  s,   snake_len
    ldi  r22,0
draw_snake:
    cp   r22, s
    breq snake_done
    mov  r24, r23
    add  r24, r22
    cpi  r24,64
    brlo idx_ok3
    subi r24,64
idx_ok3:
    ldi  ZL, low(snake_body)
    ldi  ZH, high(snake_body)
    add  ZL, r24
    brcc buf_ok3
    inc  ZH
buf_ok3:
    ld   w, Z
    mov  r24, w
    andi r24,0x07
    mov  r25, w
    swap r25
    andi r25,0x07
    rcall ws_idx_xy
    rcall ws_offset_idx
    mov  _w, s
    dec  _w
    cp   r22, _w
    breq head_pix
body_pix:
    ldi  a0,0x0F
    clr  a1
    clr  a2
    rjmp store_pix
head_pix:
    clr  a0
    clr  a1
    ldi  a2,0x0F
store_pix:
    st   Z+, a0
    st   Z+, a1
    st   Z , a2
    inc  r22
    rjmp draw_snake

snake_done:
    ; draw apple
    lds  w, apple_pos
    mov  r24, w
    andi r24,0x07
    mov  r25, w
    swap r25
    andi r25,0x07
    rcall ws_idx_xy
    rcall ws_offset_idx
    clr  a0
    ldi  a1,0x0F
    clr  a2
    st   Z+, a0
    st   Z+, a1
    st   Z , a2

    ; flush buffer
    ldi  ZL, low(WS_BUF_BASE)
    ldi  ZH, high(WS_BUF_BASE)
    _LDI r0,64
flush_loop:
    ld   a0, Z+
    ld   a1, Z+
    ld   a2, Z+
    cli
    rcall ws_byte3wr
    sei
    dec  r0
    brne flush_loop
    rcall ws_reset
    ret