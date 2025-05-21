;======================================================================
;  Game-3  – ST_GAME3   (green square)
;======================================================================

gameThreeInit:
        push  r18
        push  r19
        rcall lcd_clear
        rcall gameThreeLoop
        pop   r19
        pop   r18
        ret

;----------------------------------------------------------------------
gameThreeLoop:
loopGameThree:
        ;---- LCD -----------------------------------------------------
        rcall lcd_clear
        PRINTF LCD
        .db "Game3",0,0

        ;---- Matrix --------------------------------------------------
        WS_PUSH_ALL
            ; clear
            ldi  a0,0
            ldi  a1,0
            ldi  a2,0
            rcall ws_fill_color

            ; 3×3 green block
            ldi  a0,0x10
            ldi  a1,0x00
            ldi  a2,0x00
            ldi  r25,2
rowsSq:
            ldi  r24,2
colsSq:
            rcall ws_plot_xy
            inc   r24
            cpi   r24,5
            brlo  colsSq
            inc   r25
            cpi   r25,5
            brlo  rowsSq

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
        cpi   r19,ST_GAME3
        brne  exitGameThree        ; *** long-range fix
        rjmp  loopGameThree
exitGameThree:                      ; ***
        ret