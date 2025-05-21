;======================================================================
;  ws2812_helpers.asm   – simple drawing helpers for the 8×8 framebuffer
;  · relies on the low-level driver in ws2812_driver.asm
;  · does NO I/O-port touching – only SRAM work + ws_byte3wr / ws_reset
;======================================================================


;----------------------------------------------------------------------
;  ws_fill_color  – paint entire 8×8 buffer with colour (a0,a1,a2)
;    destroys: r18, ZL, ZH        (all others preserved)
;----------------------------------------------------------------------
ws_fill_color:
            push r18
            WS_PUSH_ALL              ; keep caller’s working regs safe

            ldi   ZL, low (WS_BUF_BASE)
            ldi   ZH, high(WS_BUF_BASE)
            ldi   r18, 64            ; 64 pixels
fill_loop:
            st    Z+, a0             ; G
            st    Z+, a1             ; R
            st    Z+, a2             ; B
            dec   r18
            brne  fill_loop

            WS_POP_ALL
            pop  r18
            ret

;----------------------------------------------------------------------
;  ws_plot_xy  – write one pixel
;       in:  r24 = x (0-7),  r25 = y (0-7),  a0/a1/a2 = G/R/B
;----------------------------------------------------------------------
ws_plot_xy:
            WS_PUSH_ALL
            push  ZL
            push  ZH
            push  w
            push  u

            rcall ws_idx_xy          ; r24 ? index 0-63
            rcall ws_offset_idx      ; Z ? address of GRB triplet
            st    Z+, a0
            st    Z+, a1
            st    Z , a2

            pop   u
            pop   w
            pop   ZH
            pop   ZL
            WS_POP_ALL
            ret

;----------------------------------------------------------------------
;  ws_show_frame  – send the whole buffer to the LEDs
;----------------------------------------------------------------------
ws_show_frame:
            WS_PUSH_ALL

            ldi   ZL, low (WS_BUF_BASE)
            ldi   ZH, high(WS_BUF_BASE)
            ldi   r18, 64
show_loop:
            ld    a0, Z+
            ld    a1, Z+
            ld    a2, Z+
            cli
            rcall ws_byte3wr         ; driver saves/restores u & w
            sei
            dec   r18
            brne  show_loop
            rcall ws_reset

            WS_POP_ALL
            ret

delayFrame:
        WAIT_MS 200            ; macro lives here, not in state loops
        WAIT_MS 50             ; small extra so LCD has time to settle
        ret