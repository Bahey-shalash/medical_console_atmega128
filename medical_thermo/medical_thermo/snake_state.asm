;----------------------------------------------------------------------
;  SNAKE  state  (Game 1)
;----------------------------------------------------------------------

snake_init:
        rcall   lcd_clear
        PRINTF  LCD
        .db     "SNAKE",0

        ; red matrix
        ldi     a0, 0x00
        ldi     a1, 0x0F
        ldi     a2, 0x00
        rcall   matrix_solid

snake_wait:
        mov     s, sel
       _CPI     s, ST_GAME1
        brne    snake_done
        WAIT_MS 50
        rjmp    snake_wait

snake_done:
        ret