;======================================================================
;  Snake  – ST_GAME1
;======================================================================

snake_init:
        push  r18
        push  r19
        rcall lcd_clear
        rcall snake_loop
        pop   r19
        pop   r18
        ret

;----------------------------------------------------------------------
snake_loop:
loopSnake:
        ;---- LCD -----------------------------------------------------
        rcall lcd_clear
        PRINTF LCD
        .db "Snake",0,0

        ;---- Matrix --------------------------------------------------
        WS_PUSH_ALL
            ; black background
            ldi  a0,0
            ldi  a1,0
            ldi  a2,0
            rcall ws_fill_color

            ; horizontal green bar (row 3)
            ldi  a0,0x10
            ldi  a1,0x00
            ldi  a2,0x00
            ldi  r25,3
            ldi  r24,0
drawBar:
            rcall ws_plot_xy
            inc   r24
            cpi   r24,8
            brlo  drawBar

            rcall ws_show_frame
        WS_POP_ALL

        ;---- housekeeping -------------------------------------------
        WAIT_US 100000
        lds   r18,flags
        sbrc  r18,FLG_TEMP
        rcall temp_task
        WAIT_US 20000

        ;---- stay in this state? ------------------------------------
        mov   r19,sel
        cpi   r19,ST_GAME1
        brne  exitSnake            ; *** long-range fix
        rjmp  loopSnake
exitSnake:                          ; ***
        ret