;----------------------------------------------------------------------
;  ws_show_frame   – streams the 192-byte frame-buffer (?1.9 ms)
;----------------------------------------------------------------------
ws_show_frame:
        push  r16
        push  ZL
        push  ZH

        ldi   ZL, low(WS_BUF_BASE)
        ldi   ZH, high(WS_BUF_BASE)
        ldi   r16, 64               ; 64 pixels

send_loop:
        ld    a0, Z+
        ld    a1, Z+
        ld    a2, Z+
        cli                         ; keep timing precise
        rcall ws_byte3wr
        sei
        dec   r16
        brne  send_loop
        rcall ws_reset

        pop   ZH
        pop   ZL
        pop   r16
        ret