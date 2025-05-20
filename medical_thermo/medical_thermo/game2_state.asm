;======================================================================
;  Game-2 state  (sel == 2)
;======================================================================

game2_loop:
            push  r18
            push  r19
            rcall lcd_clear

g2_body:
			rcall lcd_clear 
            PRINTF LCD
            .db "Game2",0

            lds   r18,flags
            sbrc  r18,FLG_TEMP
            rcall temp_task

            WAIT_US 50000

            mov   r19,sel
            cpi   r19,2                   ; still Game-2?
            breq  g2_body

            pop   r19
            pop   r18
            ret