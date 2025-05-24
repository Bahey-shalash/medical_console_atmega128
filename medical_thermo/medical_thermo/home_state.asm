;----------------------------------------------------------------------
;  HOME state  — draw green background with “holes” off
;----------------------------------------------------------------------

home_init:
        rcall   lcd_clear
        PRINTF  LCD
        .db     "HOME",0,0

        ; prepare green for fill (GRB = 0x0F,0x00,0x00)
        ldi     a0, 0x0F     ; G
        ldi     a1, 0x00     ; R
        ldi     a2, 0x00     ; B
        rcall   matrix_holes

home_wait:
        mov     s, sel
        _CPI    s, ST_HOME
        brne    home_done
        WAIT_MS 50
        rjmp    home_wait

home_done:
        ret


;======================================================================
;  matrix_holes  — fill 8×8 buffer green, then blank specified pixels
;  clobbers: a0–a2, r0, r22, r24–r25, Z, w=r16  (all scratch)
;======================================================================
matrix_holes:
        push    r22
        push    ZL
        push    ZH

        ;--- 1) fill frame buffer 64×3=192 B with (a0,a1,a2) -----------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        ldi     r22, 64
mh_fill:
        st      Z+, a0
        st      Z+, a1
        st      Z+, a2
        dec     r22
        brne    mh_fill

        ;--- 2) blank out “holes” by writing 0,0,0 at each coord --------
        ; (1,1)
        ldi     r24,1
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (2,1)
        ldi     r24,2
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (5,1)
        ldi     r24,5
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (6,1)
        ldi     r24,6
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (1,2)
        ldi     r24,1
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (2,2)
        ldi     r24,2
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (5,2)
        ldi     r24,5
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (6,2)
        ldi     r24,6
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (1,4)
        ldi     r24,1
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (6,4)
        ldi     r24,6
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (2,5)
        ldi     r24,2
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (3,5)
        ldi     r24,3
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (4,5)
        ldi     r24,4
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (5,5)
        ldi     r24,5
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ;--- 3) transmit the frame to the LEDs ------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        _LDI    r0, 64
mh_send:
        ld      a0, Z+
        ld      a1, Z+
        ld      a2, Z+
        cli
        rcall   ws_byte3wr
        sei
        dec     r0
        brne    mh_send
        rcall   ws_reset

        pop     ZH
        pop     ZL
        pop     r22
        ret