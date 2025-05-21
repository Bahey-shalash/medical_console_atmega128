;======================================================================
;  Home screen  – ST_HOME
;======================================================================

home_init:
        push  r18
        push  r19
        rcall lcd_clear
        rcall home_loop
        pop   r19
        pop   r18
        ret

;----------------------------------------------------------------------
home_loop:
loopHome:
        ;---- LCD -----------------------------------------------------
        rcall lcd_clear
        PRINTF LCD
        .db "Home",0,0

        ;---- Matrix : dim white -------------------------------------
        WS_PUSH_ALL
            ldi  a0,0x03
            ldi  a1,0x03
            ldi  a2,0x03
            rcall ws_fill_color
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
        cpi   r19,ST_HOME
        brne  exitHome              ; *** long-range fix
        rjmp  loopHome
exitHome:                            ; ***
        ret