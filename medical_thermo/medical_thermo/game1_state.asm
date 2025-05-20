;======================================================================
;  Game-1 state  (sel == 1)
;======================================================================

game1_loop:
            push  r18
            push  r19
            rcall lcd_clear

g1_body:
			rcall lcd_clear 
            PRINTF LCD
            .db "Game1",0

            lds   r18,flags
            sbrc  r18,FLG_TEMP
            rcall temp_task

            WAIT_US 50000

            mov   r19,sel
            cpi   r19,1                   ; still Game-1?
            breq  g1_body

            pop   r19
            pop   r18
            ret