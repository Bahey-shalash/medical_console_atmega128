;======================================================================
;  Game-2  – ST_GAME2   (blue X)
;======================================================================

gameTwoInit:
        push  r18
        push  r19
        rcall lcd_clear
        rcall gameTwoLoop
        pop   r19
        pop   r18
        ret

;----------------------------------------------------------------------
gameTwoLoop:
loopGameTwo:
        ;---- LCD -----------------------------------------------------
        rcall lcd_clear
        PRINTF LCD
        .db "Game2",0,0

        ;---- Matrix --------------------------------------------------
        WS_PUSH_ALL
            ; clear black
            ldi  a0,0
            ldi  a1,0
            ldi  a2,0
            rcall ws_fill_color

            ; blue X
            ldi  a0,0x00
            ldi  a1,0x00
            ldi  a2,0x10
            ldi  r25,0
rowsX:
            mov  r24,r25
            rcall ws_plot_xy
            ldi  r24,7
            sub  r24,r25
            rcall ws_plot_xy
            inc  r25
            cpi  r25,8
            brlo rowsX

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
        cpi   r19,ST_GAME2
        brne  exitGameTwo          ; *** long-range fix
        rjmp  loopGameTwo
exitGameTwo:                        ; ***
        ret