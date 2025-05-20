;======================================================================
;  Home state  (sel == 0)
;======================================================================

home_loop:
            push  r18
            push  r19
            rcall lcd_clear

home_body:
			rcall lcd_clear 
            PRINTF LCD
            .db "Home",0
			
			WAIT_US 250000             ; ~4 Hz refresh

            lds   r18,flags
            sbrc  r18,FLG_TEMP
            rcall temp_task

            WAIT_US 50000                 ; ?50 ms

            mov   r19,sel
            cpi   r19,0                   ; still Home?
            breq  home_body

            pop   r19
            pop   r18
            ret