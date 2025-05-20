;======================================================================
;  doctor_state.asm  – “Doctor” screen (temperature read-out)
;======================================================================

; (ST_DOCTOR is defined in main.asm via definitions.asm)

doctor_loop:
    push    r18
    rcall   lcd_clear

doc_body:
	rcall lcd_clear 
    lds     r18, flags
    sbrc    r18, FLG_TEMP
    rcall   temp_task

    lds     a0, temp_lsb
    lds     a1, temp_msb
    PRINTF  LCD
    .db    "Doctor ", FFRAC2+FSIGN, a, 4, $42, "C", 0

    WAIT_US 250000             ; ~4 Hz refresh

    mov     r18, sel           ; copy the state register
    cpi     r18, ST_DOCTOR     ; still Doctor?
    breq    doc_body

    pop     r18
    ret