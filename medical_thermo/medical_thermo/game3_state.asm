;======================================================================
;  game3_state.asm   – Game-3  (sel == ST_GAME3)
;======================================================================



;----------------------------------------------------------------------
;  INIT
;----------------------------------------------------------------------
game3_init:
        push  r18
        push  r19
        rcall lcd_clear
        rcall game3_loop
        pop  r19
        pop  r18
        ret

;----------------------------------------------------------------------
;  LOOP
;----------------------------------------------------------------------
game3_loop:
loop_g3:
        ;----- LCD ----------------------------------------------------
        rcall lcd_clear
        PRINTF LCD
        .db "Game3",0

        ;----- Matrix: centred 3×3 green square -----------------------
        ; clear background
        ldi  a0, 0x00
        ldi  a1, 0x00
        ldi  a2, 0x00
        rcall ws_fill_color

        ; square colour
        ldi  a0, 0x10          ; green
        ldi  a1, 0x00
        ldi  a2, 0x00

        ldi  r25, 2            ; y = 2,3,4
for_rows:
        ldi  r24, 2            ; x = 2,3,4
for_cols:
        rcall ws_plot_xy
        inc  r24
        cpi  r24, 5
        brlo for_cols
        inc  r25
        cpi  r25, 5
        brlo for_rows

        rcall ws_show_frame

        ;----- housekeeping ------------------------------------------
        WAIT_US 250000
        lds  r18, flags
        sbrc r18, FLG_TEMP
        rcall temp_task
        WAIT_US 50000

        ;----- stay in this state? -----------------------------------
        mov  r19, sel
        cpi  r19, ST_GAME3
        breq loop_g3
        ret