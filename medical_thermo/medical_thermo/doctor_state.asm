
;----------------------------------------------------------------------
;  INIT
;----------------------------------------------------------------------
doctor_init:
        push  r18
        rcall lcd_clear
        rcall doctor_loop
        pop   r18
        ret

;----------------------------------------------------------------------
;  LOOP
;----------------------------------------------------------------------
doctor_loop:
loop_doc:
        ;----- temperature background task ---------------------------
        lds  r18, flags
        sbrc r18, FLG_TEMP
        rcall temp_task

        ;----- LCD: show °C ------------------------------------------
        rcall lcd_clear
        lds  a0, temp_lsb
        lds  a1, temp_msb
        PRINTF LCD
        .db "Doctor ", FFRAC2+FSIGN, a, 4, $42, "C",0

        ;----- Matrix: colour bar in column 7 ------------------------
        ; clear background
        ldi  a0, 0x00
        ldi  a1, 0x00
        ldi  a2, 0x00
        rcall ws_fill_color

        ; convert temp to 0–63 buckets (˜2 °C each)
        lds  r22, temp_lsb
        lsr  r22
        cpi  r22, 64
        brlo temp_ok
        ldi  r22, 63
temp_ok:
        ldi  r24, 7              ; x = right-most column
        ldi  r25, 7              ; start at top

while_temp_bar:
        cpi  r25, 4
        brlo green_part
red_part:
        ldi  a0, 0x00
        ldi  a1, 0x10            ; red
        rjmp plot_colour
green_part:
        ldi  a0, 0x10            ; green
        ldi  a1, 0x00
plot_colour:
        ldi  a2, 0x00
        rcall ws_plot_xy
        dec  r25
        dec  r22
        brge while_temp_bar

        rcall ws_show_frame

        ;----- refresh / exit test -----------------------------------
        WAIT_US 250000
        mov  r18, sel
        cpi  r18, ST_DOCTOR
        breq loop_doc
        ret