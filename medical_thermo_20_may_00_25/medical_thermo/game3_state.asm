;======================================================================
;  Game-3 state  (sel == 3)
;======================================================================

game3_loop:
            push  r18
            push  r19
            rcall lcd_clear

g3_body:
			rcall lcd_clear 
            PRINTF LCD
            .db "Game3",0

            lds   r18,flags
            sbrc  r18,FLG_TEMP
            rcall temp_task

            WAIT_US 50000

            mov   r19,sel
            cpi   r19,3                   ; still Game-3?
            breq  g3_body

            pop   r19
            pop   r18
            ret