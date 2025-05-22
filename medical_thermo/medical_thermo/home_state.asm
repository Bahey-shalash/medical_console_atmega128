;----------------------------------------------------------------------
;  HOME  state
;----------------------------------------------------------------------

home_init:
        rcall   lcd_clear
        PRINTF  LCD
        .db     "HOME",0

        ; green matrix
        ldi     a0, 0x0F     ; G
        ldi     a1, 0x00     ; R
        ldi     a2, 0x00     ; B
        rcall   matrix_solid

home_wait:
        mov     s, sel
        _CPI     s, ST_HOME
        brne    home_done
        WAIT_MS 50
        rjmp    home_wait

home_done:
        ret