;======================================================================
;  doctor_state.asm      � ST_DOCTOR diagnostic screen (patched)
;======================================================================

doctorInit:
        push    r18                    ; save caller’s a0 slot

        ;── 1. clear LCD and show header ────────────────────────────────
        rcall   lcd_clear
        PRINTF  LCD
        .db     "Doctor",0,0

        ;── 2. draw red Swiss-cross background on the LED matrix ────────
        rcall   matrix_doctor         ; fills buffer & transmits

;======================================================================
;  main refresh loop � runs until sel ≠ ST_DOCTOR
;======================================================================
doctor_loop:
        ;---  temperature housekeeping  ---------------------------------
        lds     r18, flags
        sbrc    r18, FLG_TEMP
        rcall   temp_task

        ;---  fetch last reading & print -------------------------------
        lds     a0, temp_lsb
        lds     a1, temp_msb
        rcall   lcd_clear
        PRINTF  LCD
        .db     "Doctor ", FFRAC2+FSIGN, a, 4, $42, "C", 0,0

        WAIT_MS 250                    ; ≈4 Hz update

        ;---  stay only while we are still in Doctor -------------------
        mov     r18, sel
        cpi     r18, ST_DOCTOR
        breq    doctor_loop

        ;── 3. leave state ──────────────────────────────────────────────
        pop     r18
        ret


;======================================================================
;  matrix_doctor  — fill 8×8 buffer red, then blank specified pixels
;  clobbers: a0–a2, r0, r18–r22, r24–r25, Z, w=r16 (all scratch)
;======================================================================
matrix_doctor:
        push    r22
        push    ZL
        push    ZH

        ;--- set fill colour to red (GRB = 0x00,0x0F,0x00) -------------
        ldi     a0, 0x00            ; G
        ldi     a1, 0x0F            ; R
        ldi     a2, 0x00            ; B

        ;--- 1) fill frame buffer (64 pixels) --------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        ldi     r22, 64
md_fill:
        st      Z+, a0
        st      Z+, a1
        st      Z+, a2
        dec     r22
        brne    md_fill

        ;--- 2) blank out “holes” by writing 0,0,0 at each coord --------
        ; list of pixels to turn off:
        ; (3,1),(4,1),(3,2),(4,2),(3,3),(4,3),(3,4),(4,4),
        ; (3,5),(4,5),(3,6),(4,6),
        ; (1,3),(1,4),(2,3),(2,4),(5,3),(5,4),(6,3),(6,4)

        ; helper: a zero color in r1
        clr     r1

        ; (3,1)
        ldi     r24,3
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,1)
        ldi     r24,4
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,2)
        ldi     r24,3
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,2)
        ldi     r24,4
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,3)
        ldi     r24,3
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,3)
        ldi     r24,4
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,4)
        ldi     r24,3
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,4)
        ldi     r24,4
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,5)
        ldi     r24,3
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,5)
        ldi     r24,4
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,6)
        ldi     r24,3
        ldi     r25,6
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,6)
        ldi     r24,4
        ldi     r25,6
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (1,3)
        ldi     r24,1
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (1,4)
        ldi     r24,1
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (2,3)
        ldi     r24,2
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (2,4)
        ldi     r24,2
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (5,3)
        ldi     r24,5
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (5,4)
        ldi     r24,5
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (6,3)
        ldi     r24,6
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (6,4)
        ldi     r24,6
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ;--- 3) transmit the frame to the LEDs ------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        _LDI    r0, 64
md_send:
        ld      a0, Z+
        ld      a1, Z+
        ld      a2, Z+
        cli
        rcall   ws_byte3wr
        sei
        dec     r0
        brne    md_send
        rcall   ws_reset

        pop     ZH
        pop     ZL
        pop     r22
        ret