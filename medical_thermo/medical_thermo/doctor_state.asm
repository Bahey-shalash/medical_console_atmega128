;======================================================================
;  DOCTOR MODE - Medical Diagnostic State (ST_DOCTOR)
;======================================================================
;  Purpose:
;  - Implements a diagnostic mode with temperature display
;  - Shows a red Swiss cross on the 8×8 RGB LED matrix
;  - Provides continuous temperature monitoring at 4Hz update rate
;
;  Functions:
;  - doctorInit: Initialize doctor mode (LCD and LED matrix)
;  - doctor_loop: Main refresh loop for temperature monitoring
;  - matrix_doctor: Draw Swiss cross pattern on LED matrix
;
;  Register Usage:
;  - r18: Saves caller's a0, temporary for flags and temperature
;  - a0, a1: Used for temperature values (LSB/MSB)
;  - a0-a2, r0-r1, r22-r25, Z: Used for LED matrix operations
;
;  Dependencies:
;  - Requires LCD driver for text display
;  - Requires WS2812 drivers for LED matrix control
;  - Uses temperature sensor DS18B20 via temp_task function
;  - Uses PRINTF macro for formatted temperature output
;======================================================================

doctorInit:
        push    r18                    ; save caller's a0 slot

        ;---------------------------------------------------------------------
        ;  INITIALIZATION - Clear LCD and show doctor mode header
        ;---------------------------------------------------------------------
        rcall   lcd_clear
        PRINTF  LCD
        .db     "Doctor",0,0

        ;---------------------------------------------------------------------
        ;  VISUAL INDICATOR - Display red Swiss cross on LED matrix
        ;---------------------------------------------------------------------
        rcall   matrix_doctor         ; fills buffer & transmits

;======================================================================
;  MAIN LOOP - Temperature monitoring with 4Hz refresh rate
;======================================================================
doctor_loop:
        ;---------------------------------------------------------------------
        ;  TEMPERATURE PROCESSING - Handle sensor conversion and reading
        ;---------------------------------------------------------------------
        lds     r18, flags
        sbrc    r18, FLG_TEMP
        rcall   temp_task

        ;---------------------------------------------------------------------
        ;  DISPLAY UPDATE - Show current temperature reading on LCD
        ;---------------------------------------------------------------------
        lds     a0, temp_lsb
        lds     a1, temp_msb
        rcall   lcd_clear
        PRINTF  LCD
        .db     "Doctor ", FFRAC2+FSIGN, a, 4, $42, "C", 0,0

        ;---------------------------------------------------------------------
        ;  TIMING CONTROL - Maintain 4Hz update rate (250ms per cycle)
        ;---------------------------------------------------------------------
        WAIT_MS 250                    ; ≈4 Hz update

        ;---------------------------------------------------------------------
        ;  STATE CHECKING - Exit when no longer in Doctor mode
        ;---------------------------------------------------------------------
        mov     r18, sel
        cpi     r18, ST_DOCTOR
        breq    doctor_loop

        ;---------------------------------------------------------------------
        ;  CLEANUP - Restore saved register and return to caller
        ;---------------------------------------------------------------------
        pop     r18
        ret


;======================================================================
;  MATRIX_DOCTOR - Create Swiss cross pattern on LED matrix
;======================================================================
;  Description:
;  - Fills the entire 8×8 matrix with red color
;  - Blanks out specific pixels to form a Swiss cross pattern
;  - Transmits the resulting pattern to the LED matrix
;
;  Register Usage:
;  - a0-a2: RGB color components (G,R,B in WS2812B order)
;  - r1: Zero value for blanking pixels
;  - r22: Counter for filling the buffer
;  - r24, r25: X,Y coordinates for pixel addressing
;  - Z: Memory pointer for frame buffer access
;======================================================================
matrix_doctor:
        push    r22
        push    ZL
        push    ZH

        ;---------------------------------------------------------------------
        ;  COLOR SETUP - Set fill color to red (GRB format)
        ;---------------------------------------------------------------------
        ldi     a0, 0x00            ; G
        ldi     a1, 0x0F            ; R
        ldi     a2, 0x00            ; B

        ;---------------------------------------------------------------------
        ;  BUFFER FILLING - Fill entire matrix with red color
        ;---------------------------------------------------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        ldi     r22, 64
md_fill:
        st      Z+, a0
        st      Z+, a1
        st      Z+, a2
        dec     r22
        brne    md_fill

        ;---------------------------------------------------------------------
        ;  CROSS PATTERN - Blank out pixels to form Swiss cross shape
        ;---------------------------------------------------------------------
        ; list of pixels to turn off:
        ; (3,1),(4,1),(3,2),(4,2),(3,3),(4,3),(3,4),(4,4),
        ; (3,5),(4,5),(3,6),(4,6),
        ; (1,3),(1,4),(2,3),(2,4),(5,3),(5,4),(6,3),(6,4)

        ; helper: a zero color in r1
        clr     r1

        ; (3,1)
        ldi     r24,3
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,1)
        ldi     r24,4
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,2)
        ldi     r24,3
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,2)
        ldi     r24,4
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,3)
        ldi     r24,3
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,3)
        ldi     r24,4
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,4)
        ldi     r24,3
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,4)
        ldi     r24,4
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,5)
        ldi     r24,3
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,5)
        ldi     r24,4
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (3,6)
        ldi     r24,3
        ldi     r25,6
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (4,6)
        ldi     r24,4
        ldi     r25,6
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (1,3)
        ldi     r24,1
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (1,4)
        ldi     r24,1
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (2,3)
        ldi     r24,2
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (2,4)
        ldi     r24,2
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (5,3)
        ldi     r24,5
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (5,4)
        ldi     r24,5
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (6,3)
        ldi     r24,6
        ldi     r25,3
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ; (6,4)
        ldi     r24,6
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,   r1

        ;---------------------------------------------------------------------
        ;  DATA TRANSMISSION - Send pattern data to LED matrix
        ;---------------------------------------------------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        _LDI    r0, 64
md_send:
        ld      a0, Z+
        ld      a1, Z+
        ld      a2, Z+
        cli
        rcall   ws_byte3wr
        sei
        dec     r0
        brne    md_send
        rcall   ws_reset

        ;---------------------------------------------------------------------
        ;  CLEANUP - Restore saved registers and return
        ;---------------------------------------------------------------------
        pop     ZH
        pop     ZL
        pop     r22
        ret