;======================================================================
;  matrix_utils.asm  – solid-colour helper for the WS2812 8×8 matrix
;  call:  a0 = G  a1 = R  a2 = B   (GRB order)
;  clobbers:  Z, r0, r22, w=r16  (all scratch according to policy)
;======================================================================
matrix_solid:
        push    r22
        push    ZL
        push    ZH

        ;--- fill frame buffer with the requested colour -------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        ldi     r22, 64                    ; 64 pixels
m_fill_loop:
        st      Z+, a0
        st      Z+, a1
        st      Z+, a2
        dec     r22
        brne    m_fill_loop

        ;--- transmit the frame to the LEDs --------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        _LDI    r0, 64
m_send_loop:
        ld      a0, Z+
        ld      a1, Z+
        ld      a2, Z+
        cli
        rcall   ws_byte3wr
        sei
        dec     r0
        brne    m_send_loop
        rcall   ws_reset

        pop     ZH
        pop     ZL
        pop     r22
        ret