;======================================================================
;  SNAKE state – ST_GAME1               (constant-time apple handling)
;----------------------------------------------------------------------
;  • 8×8 WS2812 matrix
;  • 3-segment snake  – blue head / green body
;  • Apple: red, re-spawns instantly at a random free cell when eaten
;  • Walls: collision → “GAME OVER” (freeze until `sel` ≠ ST_GAME1)
;  • Control: rotary encoder (turns queued @1 kHz)
;  • Pseudo-random: read Timer-0 counter (prescaler untouched)
;----------------------------------------------------------------------
;  Snake length is fixed at three – no growth or self-collision yet
;======================================================================

;---------------------------------------------------------------------
;  SRAM layout
;---------------------------------------------------------------------
.dseg
snake_body:   .byte 64      ; packed x + 8*y (0xFF = empty)
head_idx:     .byte 1
tail_idx:     .byte 1
snake_len:    .byte 1

direction:    .byte 1       ; 0 Up  1 Right  2 Down  3 Left
apple_pos:    .byte 1       ; packed apple pixel (0xFF = none)

turn_queue:   .byte 8
tq_head:      .byte 1
tq_tail:      .byte 1
.cseg

;=====================================================================
;  INITIALISATION
;=====================================================================
snake_game_init:
    rcall lcd_clear
    PRINTF LCD
    .db "SNAKE",0

    rcall encoder_init
    rcall snake_init_data
    rcall snake_draw
    rjmp snake_wait

snake_init_data:
    ; clear body buffer → 0xFF
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi r22, 64
clear_body:
    ldi w, 0xFF
    st  Z+, w
    dec r22
    brne clear_body

    ; seed snake at (2,3)(3,3)(4,3)
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi w, 26
    st  Z+, w
    ldi w, 27
    st  Z+, w
    ldi w, 28
    st  Z , w

    ; indices & length
    ldi w, 2
    sts head_idx, w
    clr w
    sts tail_idx, w
    ldi w, 3
    sts snake_len, w

    ldi w, 1                  ; heading RIGHT
    sts direction, w

    ldi w, 45                 ; apple at (5,5)
    sts apple_pos, w

    clr w
    sts tq_head, w
    sts tq_tail, w
    clr a0
    clr b0
    in  w, ENCOD
    sts enc_old, w
    ret                       ; Timer-0 untouched – PRNG read only

;=====================================================================
;  MAIN LOOP  (fixed 500-ms frames)
;=====================================================================
snake_wait:
    ;------------- start of frame -----------------------------------
    ldi r24, low(500)
    ldi r25, high(500)
frame_delay:
    rcall update_game
    WAIT_MS 1
    sbiw r24, 1
    brne frame_delay

    rcall move_snake
    rcall snake_draw

    ;------------- prepare next frame --------------------------------
    ldi r24, low(500)          ; reload 500-ms counter
    ldi r25, high(500)

    mov  s, sel
    _CPI s, ST_GAME1
    breq frame_delay            ; loop inside ST_GAME1
    ret

;=====================================================================
;  update_game – rotary encoder → heading        (unchanged)
;=====================================================================
update_game:
    push r25
    push r24
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23

    rcall encoder_update        ; r15 = ±1 or 0
    mov  r19, r15
    tst  r19
    brne enc_move
    rjmp enc_exit

enc_move:
    lds  r21, direction
    tst  r19
    brmi enc_left

enc_right:
    mov  r20, r21
    inc  r20
    cpi  r20, 4
    brlo enc_chk
    clr  r20
    rjmp enc_chk

enc_left:
    mov  r20, r21
    tst  r20
    brne enc_left_ok
    ldi  r20, 3
    rjmp enc_chk
enc_left_ok:
    dec  r20

enc_chk:                        ; reject 180°
    mov  r22, r21
    subi r22, -2
    andi r22, 0x03
    cp   r20, r22
    breq enc_exit

    ; enqueue
    lds  r23, tq_head
    mov  r24, r23
    inc  r24
    andi r24, 0x07
    lds  r22, tq_tail
    cp   r24, r22
    breq enc_exit

    ldi  ZL, low(turn_queue)
    ldi  ZH, high(turn_queue)
    add  ZL, r23
    brcc enc_store
    inc  ZH
enc_store:
    st   Z, r20
    sts  tq_head, r24

    ; dequeue immediately
    lds  r22, tq_tail
    lds  r23, tq_head
    cp   r22, r23
    breq enc_exit

    ldi  ZL, low(turn_queue)
    ldi  ZH, high(turn_queue)
    add  ZL, r22
    brcc enc_read
    inc  ZH
enc_read:
    ld   r20, Z
    inc  r22
    andi r22, 0x07
    sts  tq_tail, r22
    sts  direction, r20

enc_exit:
    pop  r23
    pop  r22
    pop  r21
    pop  r20
    pop  r19
    pop  r18
    pop  r24
    pop  r25
    ret

;=====================================================================
;  move_snake – borders & apple collision
;=====================================================================
move_snake:
    lds  r18, direction

    ; current head byte → r20
    lds  r19, head_idx
    ldi  ZL, low(snake_body)
    ldi  ZH, high(snake_body)
    add  ZL, r19
    brcc head_ptr
    inc  ZH
head_ptr:
    ld   r20, Z

    ; unpack x,y
    mov  r21, r20
    andi r21, 0x07            ; x
    mov  r22, r20
    lsr  r22
    lsr  r22
    lsr  r22
    andi r22, 0x07            ; y

    ; border check & next cell
    cpi  r18, 1
    breq dir_right
    cpi  r18, 3
    breq dir_left
    cpi  r18, 0
    breq dir_up
    inc  r22
    cpi  r22, 8
    breq hit_wall
    rjmp pack_cell

dir_right:
    inc  r21
    cpi  r21, 8
    breq hit_wall
    rjmp pack_cell

dir_left:
    tst  r21
    breq hit_wall
    dec  r21
    rjmp pack_cell

dir_up:
    tst  r22
    breq hit_wall
    dec  r22

pack_cell:
    mov  r20, r22
    lsl  r20
    lsl  r20
    lsl  r20                 ; y*8
    add  r20, r21            ; + x → packed candidate

    ; apple collision?
    lds  r23, apple_pos
    cpi  r23, 0xFF
    breq write_head
    cp   r20, r23
    brne write_head
    ldi  r23, 0xFF
    sts  apple_pos, r23
    rcall place_new_apple     ; constant-time routine (below)

write_head:
    lds  r19, head_idx
    inc  r19
    cpi  r19, 64
    brlo idx_ok_write
    clr  r19
idx_ok_write:
    sts  head_idx, r19
    ldi  ZL, low(snake_body)
    ldi  ZH, high(snake_body)
    add  ZL, r19
    brcc write_ptr
    inc  ZH
write_ptr:
    st   Z, r20

    ; keep length 3
    lds  r21, tail_idx
    inc  r21
    cpi  r21, 64
    brlo tail_ok
    clr  r21
tail_ok:
    sts  tail_idx, r21
    ret

hit_wall:
    rcall lcd_clear
    PRINTF LCD
    .db "GAME OVER",0
freeze_game:
    mov  r18, sel
    _CPI r18, ST_GAME1
    breq freeze_game
    ret

;=====================================================================
;  place_new_apple – constant-time (8 passes) – NO dot-labels
;=====================================================================
;  * executes 8 identical iterations every call  (~108 µs @ 4 MHz)
;  * first free coordinate found is committed after loop
;---------------------------------------------------------------------
place_new_apple:
    push r26
    push r25
    push r24
    push r23
    push r22
    push r21
    push r20
    push r19
    push r18

    clr   r18                 ; r18 = 0 → not yet chosen
    ldi   r23, 8              ; exactly 8 iterations

loop_iter:
    ; ----- PRNG candidate ------------------------------------------
    in    r24, TCNT0
    in    r26, ADCL           ; ADC LSB
    eor   r24, r26
    lds   r19, head_idx
    add   r24, r19            ; decorrelate

    mov   r25, r24
    andi  r24, 0x07           ; x 0-7
    lsr   r25
    lsr   r25
    lsr   r25
    andi  r25, 0x07           ; y 0-7

    mov   r20, r25
    lsl   r20
    lsl   r20
    lsl   r20                 ; y*8
    add   r20, r24            ; packed candidate

    ; ----- compare to 3-segment snake ------------------------------
    lds   r22, tail_idx

seg0_ptr:
    ldi   ZL, low(snake_body)
    ldi   ZH, high(snake_body)
    add   ZL, r22
    brcc  seg0_buf
    inc   ZH
seg0_buf:
    ld    r24, Z
    cp    r24, r20
    breq  clash_found

    inc   r22                 ; segment 1
    cpi   r22, 64
    brlo  seg1_idx
    clr   r22
seg1_idx:
    ldi   ZL, low(snake_body)
    ldi   ZH, high(snake_body)
    add   ZL, r22
    brcc  seg1_buf
    inc   ZH
seg1_buf:
    ld    r24, Z
    cp    r24, r20
    breq  clash_found

    inc   r22                 ; segment 2
    cpi   r22, 64
    brlo  seg2_idx
    clr   r22
seg2_idx:
    ldi   ZL, low(snake_body)
    ldi   ZH, high(snake_body)
    add   ZL, r22
    brcc  seg2_buf
    inc   ZH
seg2_buf:
    ld    r24, Z
    cp    r24, r20
    breq  clash_found

    tst   r18                 ; first free candidate ?
    brne  skip_store
    mov   r18, r20
skip_store:
clash_found:
    dec   r23
    brne  loop_iter

    tst   r18                 ; commit result
    brne  store_ok
    mov   r18, r20            ; (never all clash, but be safe)
store_ok:
    sts   apple_pos, r18

    pop   r18
    pop   r19
    pop   r20
    pop   r21
    pop   r22
    pop   r23
    pop   r24
    pop   r25
    pop   r26
    ret

;=====================================================================
;  snake_draw – render snake & apple
;=====================================================================
snake_draw:
    clr a0
    clr a1
    clr a2
    rcall matrix_solid

    lds  r23, tail_idx
    lds  s, snake_len
    ldi  r22, 0
draw_loop:
    cp   r22, s
    breq draw_done
    mov  r24, r23
    add  r24, r22
    cpi  r24, 64
    brlo idx_ok3
    subi r24, 64
idx_ok3:
    ldi  ZL, low(snake_body)
    ldi  ZH, high(snake_body)
    add  ZL, r24
    brcc buf_ok3
    inc  ZH
buf_ok3:
    ld   w, Z                 ; packed = x + 8*y
    mov  r24, w
    andi r24, 0x07            ; x
    mov  r25, w
    lsr  r25
    lsr  r25
    lsr  r25
    andi r25, 0x07            ; y
    rcall ws_idx_xy
    rcall ws_offset_idx
    mov  _w, s
    dec  _w
    cp   r22, _w
    breq head_pix
body_pix:
    ldi  a0, 0x0F             ; green body
    clr  a1
    clr  a2
    rjmp store_px
head_pix:
    clr  a0
    clr  a1
    ldi  a2, 0x0F             ; blue head
store_px:
    st   Z+, a0
    st   Z+, a1
    st   Z , a2
    inc  r22
    rjmp draw_loop

draw_done:
    ; apple (if present)
    lds  w, apple_pos
    cpi  w, 0xFF
    breq flush_frame
    mov  r24, w
    andi r24, 0x07
    mov  r25, w
    lsr  r25
    lsr  r25
    lsr  r25
    andi r25, 0x07
    rcall ws_idx_xy
    rcall ws_offset_idx
    clr  a0
    ldi  a1, 0x0F             ; red apple
    clr  a2
    st   Z+, a0
    st   Z+, a1
    st   Z , a2

flush_frame:
    ldi  ZL, low(WS_BUF_BASE)
    ldi  ZH, high(WS_BUF_BASE)
    _LDI r0, 64
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