;======================================================================
;  SNAKE  state � ST_GAME1
;  � 8�8 WS2812 matrix
;  � 3-segment snake, blue head / green body
;  � Rotary-encoder steering (every edge ? queued & drained @1 kHz)
;======================================================================
;TODO: 0. play and pause game with the{ in encoder encoder_button:
;	sbrc	_w,ENCOD_I
;	rjmp	i_rise
;i_fall:
;	set						; set T=1 to indicate button press
;	ret
;i_rise:
;	ret}
;TODO: 1. add apple
;TODO: 2. make the apple spawn at a random location (using a timer that) do not spawn on the snake
;TODO: 3. add collision detection (snake vs apple)
;TODO: 4. make the apple disappear when eaten
;TODO: 5. make the snake grow when it eats the apple
;TODO: 6. apple respauns when eaten
;TODO: 7. make the snake grow when it eats the apple
;TODO: 8. make the snake die when it runs into the wall
;TODO: 9. make the snake die when it runs into itself

;---------------------------------------------------------------------
; ? Data section � circular buffer & control FIFO
;---------------------------------------------------------------------
.dseg
snake_body:   .byte 64      ; packed x + 8*y
head_idx:     .byte 1
 tail_idx:    .byte 1
snake_len:    .byte 1

direction:    .byte 1       ; 0=Up 1=Right 2=Down 3=Left

; ?? 8-slot FIFO of pending turns (0�3 headings) ????????????????????
turn_queue:   .byte 8
tq_head:      .byte 1       ; write idx (0..7)
tq_tail:      .byte 1       ; read  idx (0..7)
;---------------------------------------------------------------------
.cseg

;======================================================================
;  snake_init � entry from main dispatcher
;======================================================================
snake_init: ; game_snake_init now
    rcall lcd_clear
    PRINTF LCD
    .db "SNAKE",0

    rcall encoder_init             ; configure PE4�6
    rcall snake_init_data
    rcall snake_draw
    rjmp snake_wait                ; ? main loop

;======================================================================
;  snake_wait � 1 ms poll loop, 500 ms frame timer
;======================================================================
snake_wait:
    ldi r24, low(500)
    ldi r25, high(500)

poll_loop:
    rcall update_game              ; enqueue & dequeue @1 kHz
    WAIT_MS 1
    sbiw r24, 1                    ; decrement 16-bit counter
    brne poll_loop

    rcall move_snake               ; single step @500 ms
    rcall snake_draw

    mov s, sel
    _CPI s, ST_GAME1
    breq snake_wait
    ret

;======================================================================
;  snake_init_data � build 3-segment snake, clear FIFO & seed encoder
;======================================================================
snake_init_data:
    ; clear body buffer ? 0xFF
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi r22, 64
clr_buf:
    ldi w, 0xFF
    st Z+, w
    dec r22
    brne clr_buf

    ; seed segments at (2,3),(3,3),(4,3)
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi w, 26
    st Z+, w
    ldi w, 27
    st Z+, w
    ldi w, 28
    st Z, w

    ; init indices & length
    ldi w, 2
    sts head_idx, w
    clr w
    sts tail_idx, w
    ldi w, 3
    sts snake_len, w

    ; start heading RIGHT
    ldi w, 1
    sts direction, w

    ; clear the 8-slot FIFO
    clr w
    sts tq_head, w
    sts tq_tail, w

    ; zero encoder counters (a0/b0) to suppress boot-spike
    clr a0
    clr b0

    ; seed old-port so first encoder_update yields ?=0
    in w, ENCOD
    sts enc_old, w

    ret

;======================================================================
;  update_game � encoder_update ? enqueue & immediately dequeue one
;======================================================================
update_game:
    ; preserve frame-counter registers r24:r25
    push r25
    push r24
    ; preserve working registers
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23

    ; r15 ? �1 per detent or 0
    rcall encoder_update
    mov r19, r15
    tst r19
    brne continue_update
    rjmp exit_update

continue_update:
    ; compute candidate heading in r20
    lds r21, direction
    tst r19
    brmi make_left

make_right:
    ; turn right (CW)
    mov r20, r21
    inc r20
    cpi r20, 4
    brlo check_reverse
    clr r20
    rjmp check_reverse

make_left:
    ; turn left (CCW)
    mov r20, r21
    tst r20
    brne dec_ok
    ldi r20, 3
    rjmp check_reverse

dec_ok:
    dec r20

check_reverse:
    ; reject 180� turn
    mov r22, r21
    subi r22, -2
    andi r22, 0x03
    cp r20, r22
    breq exit_update

    ; enqueue into turn_queue[tq_head]
    lds r23, tq_head
    mov r24, r23
    inc r24
    andi r24, 0x07
    lds r22, tq_tail
    cp r24, r22
    breq exit_update          ; full? drop

    ; store heading
    ldi ZL, low(turn_queue)
    ldi ZH, high(turn_queue)
    add ZL, r23
    brcc qok
    inc ZH
qok:
    st Z, r20
    sts tq_head, r24

    ; immediately dequeue one to keep FIFO shallow
    lds r22, tq_tail
    lds r23, tq_head
    cp r22, r23
    breq exit_update          ; empty?

    ldi ZL, low(turn_queue)
    ldi ZH, high(turn_queue)
    add ZL, r22
    brcc dqok
    inc ZH
dqok:
    ld r20, Z                 ; oldest
    inc r22
    andi r22, 0x07
    sts tq_tail, r22
    sts direction, r20        ; apply it

exit_update:
    ; restore working registers
    pop r23
    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    ; restore frame-counter registers
    pop r24
    pop r25
    ret

;======================================================================
;  move_snake � advance one cell (toroidal), keep length = 3
;======================================================================
move_snake:
    lds   r18, direction

    ; fetch current head
    lds   r19, head_idx
    ldi   ZL, low(snake_body)
    ldi   ZH, high(snake_body)
    add   ZL, r19
    brcc head_ptr_ok
    inc   ZH
head_ptr_ok:
    ld    r20, Z

    ; unpack x,y
    mov   r21, r20
    andi  r21,0x07
    mov   r22, r20
    swap  r22
    andi  r22,0x07

    ; apply move + wrap
    cpi   r18,1
    breq mv_right
    cpi   r18,3
    breq mv_left
    cpi   r18,0
    breq mv_up
mv_down:
    inc   r22
    cpi   r22,8
    brlo  mv_done
    clr   r22
    rjmp  mv_done
mv_up:
    tst   r22
    brne mv_up_ok
    ldi   r22,7
    rjmp mv_done
mv_up_ok:
    dec   r22
    rjmp mv_done
mv_right:
    inc   r21
    cpi   r21,8
    brlo mv_done
    clr   r21
    rjmp mv_done
mv_left:
    tst   r21
    brne mv_left_ok
    ldi   r21,7
    rjmp mv_done
mv_left_ok:
    dec   r21
mv_done:

    ; repack and write head
    mov r20, r21
    mov _w, r22
    swap _w
    andi _w,0x70
    or r20, _w
    lds r19, head_idx
    inc r19
    cpi r19,64
    brlo head_ok
    clr r19
head_ok:
    sts head_idx, r19
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    add ZL, r19
    brcc write_ok
    inc ZH
write_ok:
    st Z, r20

    ; bump tail
    lds r21, tail_idx
    inc r21
    cpi r21,64
    brlo tail_ok
    clr r21
tail_ok:
    sts tail_idx, r21
    ret

;======================================================================
;  snake_draw � paint body & head, then WS2812 stream
;======================================================================
snake_draw:
    clr a0
    clr a1
    clr a2
    rcall matrix_solid

    lds r23, tail_idx
    lds s, snake_len
    ldi r22,0

draw_loop:
    cp r22, s
    breq draw_done
    ; compute buffer idx
    mov r24, r23
    add r24, r22
    cpi r24,64
    brlo idx_ok
    subi r24,64
idx_ok:
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    add ZL, r24
    brcc buf_ok
    inc ZH
buf_ok:
    ld w, Z

    ; unpack and pixel
    mov r24, w
    andi r24,0x07
    mov r25, w
    swap r25
    andi r25,0x07
    rcall ws_idx_xy
    rcall ws_offset_idx

    mov _w, s
    dec _w
    cp r22, _w
    breq head_col
body_col:
    ldi a0,0x0F
    clr a1
    clr a2
    rjmp store_px
head_col:
    clr a0
    clr a1
    ldi a2,0x0F
store_px:
    st Z+, a0
    st Z+, a1
    st Z, a2

    inc r22
    rjmp draw_loop

draw_done:
    ldi ZL, low(WS_BUF_BASE)
    ldi ZH, high(WS_BUF_BASE)
    _LDI r0,64
send_lp:
    ld a0, Z+
    ld a1, Z+
    ld a2, Z+
    cli
    rcall ws_byte3wr
    sei
    dec r0
    brne send_lp
    rcall ws_reset
    ret