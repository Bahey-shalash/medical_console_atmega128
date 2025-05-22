;======================================================================
;  SNAKE  state – ST_GAME1 (with head as blue & direction storage)
;======================================================================

;---------------------------------------------------------------------
; ? Data section – circular buffer, counters & directions
;---------------------------------------------------------------------
.dseg
snake_body:   .byte 64     ; circular buffer holds x+8*y for each segment
head_idx:     .byte 1      ; index of newest segment
tail_idx:     .byte 1      ; index of oldest segment
snake_len:    .byte 1      ; current length (<=64)
; new direction vars:
direction:    .byte 1      ; current direction: 0=up,1=right,2=down,3=left
next_dir:     .byte 1      ; queued next direction

;---------------------------------------------------------------------
.cseg

;======================================================================
;  snake_init  – entry from main.asm dispatcher
;======================================================================
snake_init:
        ; 1) LCD header
        rcall   lcd_clear
        PRINTF  LCD
        .db     "SNAKE",0

        ; 2) initialise data structures (snake length = 3)
        rcall   snake_init_data

        ; 3) draw initial frame
        rcall   snake_draw

        ; 4) exit to wait-loop
        ret

;======================================================================
;  Main wait-loop – exits when sel ? ST_GAME1
;======================================================================
snake_wait:
        mov     s, sel
        _CPI    s, ST_GAME1
        brne    snake_done

        ; Game tick
        rcall   update_game    ; handle direction change & movement
        rcall   snake_draw     ; redraw frame
        WAIT_MS 500            ; basic tick interval
        rjmp    snake_wait

snake_done:
        ret

;======================================================================
;  snake_init_data  – build 3-segment snake & init directions
;======================================================================
snake_init_data:
        ; clear buffer to 0xFF
        ldi     ZL, low(snake_body)
        ldi     ZH, high(snake_body)
        ldi     r22, 64
For_clear:
        ldi     w, 0xFF
        st      Z+, w
        dec     r22
        brne    For_clear

        ; write 3 segments at (2,3)=26, (3,3)=27, (4,3)=28
        ldi     ZL, low(snake_body)
        ldi     ZH, high(snake_body)
        ldi     w, 26    ; tail
        st      Z+, w
        ldi     w, 27    ; mid
        st      Z+, w
        ldi     w, 28    ; head
        st      Z,  w

        ; set indices & length
        ldi     w, 2
        sts     head_idx, w
        clr     w
        sts     tail_idx, w
        ldi     w, 3
        sts     snake_len, w

        ; init directions to RIGHT (1)
        ldi     w, 1
        sts     direction, w
        sts     next_dir, w

        ret

;======================================================================
;  snake_draw – redraw whole matrix, head in blue
;======================================================================
snake_draw:
        ; 0) clear to black
        clr     a0
        clr     a1
        clr     a2
        rcall   matrix_solid

        ; 1) prepare loop vars
        lds     s, snake_len     ; s = length
        mov     r21, s
        dec     r21              ; r21 = index of head in loop (len-1)
        ldi     r22, 0           ; iterator i
For_segments:
        cp      r22, s
        breq    out_segments

        ; load buffer[i]
        ldi     ZL, low(snake_body)
        ldi     ZH, high(snake_body)
        add     ZL, r22
        brcc    seg_ptr_ok
        inc     ZH
seg_ptr_ok:
        ld      w, Z

        ; unpack w ? x=r24, y=r25
        mov     r24, w
        andi    r24, 0x07
        mov     r25, w
        swap    r25
        andi    r25, 0x07

        ; compute buffer index
        rcall   ws_idx_xy
        rcall   ws_offset_idx

        ; choose color: head or body
        cp      r22, r21
        breq    draw_head
        rjmp    draw_body

draw_head:
        ; blue head
        clr     a0          ; G = 0
        clr     a1          ; R = 0
        ldi     a2, 0x0F    ; B = bright
        rjmp    write_pixel

draw_body:
        ; regular bright green
        ldi     a0, 0x0F    ; G
        clr     a1          ; R
        clr     a2          ; B

write_pixel:
        st      Z+, a0
        st      Z+, a1
        st      Z,  a2

        inc     r22
        rjmp    For_segments
out_segments:

        ; 2) transmit buffer
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        _LDI    r0, 64
For_send:
        ld      a0, Z+
        ld      a1, Z+
        ld      a2, Z+
        cli
        rcall   ws_byte3wr
        sei
        dec     r0
        brne    For_send
        rcall   ws_reset
        ret

;======================================================================
;  update_game – placeholder for movement & direction logic
;======================================================================
update_game:
        ; TODO: read inputs into next_dir, then mov direction, next_dir on move
        ret
