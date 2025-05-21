;======================================================================
;  Doctor mode  – ST_DOCTOR
;======================================================================

doctorInit:
        push  r18
        rcall lcd_clear
        rcall doctorLoop
        pop   r18
        ret

;----------------------------------------------------------------------
doctorLoop:
loopDoctor:
        ;---- background temperature ---------------------------------
        lds  r18,flags
        sbrc r18,FLG_TEMP
        rcall temp_task

        ;---- LCD -----------------------------------------------------
        rcall lcd_clear
        lds  a0,temp_lsb
        lds  a1,temp_msb
        PRINTF LCD
        .db "Doctor ",FFRAC2+FSIGN,a,4,$42,"C",0

        ;---- Matrix --------------------------------------------------
        WS_PUSH_ALL
            ldi  a0,0
            ldi  a1,0
            ldi  a2,0
            rcall ws_fill_color

            lds  r22,temp_lsb
            lsr  r22
            cpi  r22,64
            brlo bucketOk
            ldi  r22,63
bucketOk:
            ldi  r24,7
            ldi  r25,7
thermLoop:
            cpi  r25,4
            brlo greenPart
redPart:
            ldi  a0,0
            ldi  a1,0x10
            rjmp colourDone
greenPart:
            ldi  a0,0x10
            ldi  a1,0
colourDone:
            ldi  a2,0
            rcall ws_plot_xy
            dec  r25
            dec  r22
            brpl thermLoop

            rcall ws_show_frame
        WS_POP_ALL

        ;---- housekeeping -------------------------------------------
        WAIT_US 100000
        WAIT_US 20000

        mov   r18,sel
        cpi   r18,ST_DOCTOR
        brne  exitDoctor           ; *** long-range fix
        rjmp  loopDoctor
exitDoctor:                         ; ***
        ret