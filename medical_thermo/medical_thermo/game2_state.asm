;----------------------------------------------------------------------
;  GAME 2  state
;----------------------------------------------------------------------

gameTwoInit:
        rcall   lcd_clear
        PRINTF  LCD
        .db     "GAME 2",0,0

        ; blue matrix
        ldi     a0, 0x00
        ldi     a1, 0x00
        ldi     a2, 0x0F
        rcall   matrix_solid

game2_wait:
        mov     s, sel
        _CPI     s, ST_GAME2
        brne    game2_done
        WAIT_MS 50
        rjmp    game2_wait

game2_done:
        ret