;======================================================================
;  HOME STATE - Main Menu Interface
;======================================================================
;  Target: ATmega128L @ 4MHz
;
;  Description:
;  This file implements the HOME state, which serves as the main menu
;  for the medical console. It displays "HOME" on the LCD screen and
;  creates a green pattern with strategic "holes" (blank pixels) on the
;  8×8 RGB LED matrix to create a recognizable visual pattern.
;
;  Functions:
;  - home_init: Initialize the HOME state (LCD and LED matrix)
;  - home_wait: Main polling loop that monitors the current state
;  - matrix_holes: Helper function to create the patterned LED display
;
;  Register Usage:
;  - s: Used to check current system state
;  - a0-a2: RGB color components for LED matrix (GRB order)
;  - r22: Counter for filling the buffer
;  - r24, r25: X,Y coordinates for pixel addressing
;  - Z: Memory pointer for frame buffer access
;
;  Dependencies:
;  - Requires LCD driver for text display
;  - Uses WS2812 driver for LED matrix control
;  - Relies on ST_HOME constant from main.asm
;
;  Last Modified: May 25, 2025
;======================================================================

;----------------------------------------------------------------------
;  HOME state  — draw green background with "holes" off(smiley face)
;----------------------------------------------------------------------

home_init:
        rcall   lcd_clear
        PRINTF  LCD
        .db     "HOME",0,0

        ; prepare green for fill (GRB = 0x0F,0x00,0x00)
        ldi     a0, 0x0F     ; G
        ldi     a1, 0x00     ; R
        ldi     a2, 0x00     ; B
        rcall   matrix_holes

;---------------------------------------------------------------------
;  MAIN LOOP - Wait until user changes state
;---------------------------------------------------------------------
home_wait:
        mov     s, sel
        _CPI    s, ST_HOME
        brne    home_done
        WAIT_MS 50
        rjmp    home_wait

;---------------------------------------------------------------------
;  CLEANUP - Return to main state handler
;---------------------------------------------------------------------
home_done:
        ret


;======================================================================
;  matrix_holes  — fill 8×8 buffer green, then blank specified pixels
;  clobbers: a0–a2, r0, r22, r24–r25, Z, w=r16  (all scratch)
;======================================================================
matrix_holes:
        push    r22
        push    ZL
        push    ZH

        ;---------------------------------------------------------------------
        ;  BUFFER PREPARATION - Fill entire matrix with green color
        ;---------------------------------------------------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        ldi     r22, 64
mh_fill:
        st      Z+, a0
        st      Z+, a1
        st      Z+, a2
        dec     r22
        brne    mh_fill

        ;---------------------------------------------------------------------
        ;  PATTERN CREATION - Turn off specific pixels to create pattern
        ;---------------------------------------------------------------------
        ; (1,1)
        ldi     r24,1
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (2,1)
        ldi     r24,2
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (5,1)
        ldi     r24,5
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (6,1)
        ldi     r24,6
        ldi     r25,1
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (1,2)
        ldi     r24,1
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (2,2)
        ldi     r24,2
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (5,2)
        ldi     r24,5
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (6,2)
        ldi     r24,6
        ldi     r25,2
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (1,4)
        ldi     r24,1
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (6,4)
        ldi     r24,6
        ldi     r25,4
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (2,5)
        ldi     r24,2
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (3,5)
        ldi     r24,3
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (4,5)
        ldi     r24,4
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ; (5,5)
        ldi     r24,5
        ldi     r25,5
        rcall   ws_idx_xy
        rcall   ws_offset_idx
        st      Z+, r1
        st      Z+, r1
        st      Z,  r1

        ;---------------------------------------------------------------------
        ;  DATA TRANSMISSION - Send pattern to LED matrix
        ;---------------------------------------------------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        _LDI    r0, 64
mh_send:
        ld      a0, Z+
        ld      a1, Z+
        ld      a2, Z+
        cli
        rcall   ws_byte3wr
        sei
        dec     r0
        brne    mh_send
        rcall   ws_reset

        ;---------------------------------------------------------------------
        ;  CLEANUP - Restore saved registers and return
        ;---------------------------------------------------------------------
        pop     ZH
        pop     ZL
        pop     r22
        ret