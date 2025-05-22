;======================================================================
;  doctor_state.asm      – ST_DOCTOR diagnostic screen
;======================================================================


doctorInit:
        push    r18                    ; save caller’s a0 slot

        ;––– 1. clear LCD and show header ––––––––––––––––––––––––––––
        rcall   lcd_clear
        PRINTF  LCD
        .db     "Doctor",0,0;removes annoying warning by alligning 

        ;––– 2. blank the LED matrix (all LEDs off) ––––––––––––––––––
        clr     a0                     ; G
        clr     a1                     ; R
        clr     a2                     ; B
        rcall   matrix_solid           ; fills buffer & transmits

;======================================================================
;  main refresh loop – runs until sel ? ST_DOCTOR
;======================================================================
doctor_loop:
        ;---  temperature housekeeping  -------------------------------
        lds     r18, flags
        sbrc    r18, FLG_TEMP          ; if ready flag set …
        rcall   temp_task              ; … service background task

        ;---  fetch last reading & print ------------------------------
        lds     a0, temp_lsb
        lds     a1, temp_msb
		rcall   lcd_clear
        PRINTF  LCD
        .db     "Doctor ", FFRAC2+FSIGN, a, 4, $42, "C", 0,0

        WAIT_MS 250                    ; ?4 Hz update rate

        ;---  stay only while we are still in Doctor ------------------
        mov     r18, sel
        cpi     r18, ST_DOCTOR
        breq    doctor_loop

        ;––– 3. leave state ––––––––––––––––––––––––––––––––––––––––––
        pop     r18
        ret