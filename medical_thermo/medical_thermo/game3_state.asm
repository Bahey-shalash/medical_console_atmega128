;----------------------------------------------------------------------
;  GAME 3  state
;----------------------------------------------------------------------

gameThreeInit:
        rcall   lcd_clear
        PRINTF  LCD
        .db     "GAME 3",0

        ; yellow matrix  (R+G)
        ldi     a0, 0x08
        ldi     a1, 0x08
        ldi     a2, 0x00
        rcall   matrix_solid

game3_wait:
        mov     s, sel
        _CPI     s, ST_GAME3
        brne    game3_done
        WAIT_MS 50
        rjmp    game3_wait

game3_done:
        ret