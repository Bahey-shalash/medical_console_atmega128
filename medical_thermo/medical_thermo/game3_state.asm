;======================================================================
;  GAME 3 STATE - Placeholder for Future Game Implementation
;======================================================================
;  Target: ATmega128L @ 4MHz
;
;  Description:
;  This file implements a placeholder state for a future game (Game 3).
;  It currently provides a basic template with a yellow LED matrix display
;  and "GAME 3" text on the LCD. The implementation loops until the user
;  changes to a different state.
;
;  Functions:
;  - gameThreeInit: Initialize Game 3 state (LCD and LED matrix)
;  - game3_wait: Main loop that monitors the current state
;
;  Register Usage:
;  - s: Used to check current system state
;  - a0-a2: RGB color components for LED matrix (GRB order)
;  - sel: System state register (defined in main.asm)
;
;  Dependencies:
;  - Requires LCD driver for text display
;  - Uses WS2812 helper functions for LED matrix control
;  - Relies on ST_GAME3 constant from main.asm
;
;  Last Modified: May 25, 2025
;======================================================================

;----------------------------------------------------------------------
;  GAME 3  state
;----------------------------------------------------------------------

gameThreeInit:
        ;---------------------------------------------------------------------
        ;  INITIALIZATION - Setup LCD display with game title
        ;---------------------------------------------------------------------
        rcall   lcd_clear
        PRINTF  LCD
        .db     "GAME 3",0

        ;---------------------------------------------------------------------
        ;  VISUAL INDICATOR - Set LED matrix to solid yellow (R+G)
        ;---------------------------------------------------------------------
        ; Set color to yellow (GRB order: a0=G, a1=R, a2=B)
        ldi     a0, 0x08
        ldi     a1, 0x08
        ldi     a2, 0x00
        rcall   matrix_solid

;---------------------------------------------------------------------
;  MAIN LOOP - Wait until user changes the state
;---------------------------------------------------------------------
game3_wait:
        ;---------------------------------------------------------------------
        ;  STATE CHECKING - Monitor if current state is still Game 3
        ;---------------------------------------------------------------------
        mov     s, sel
        _CPI     s, ST_GAME3
        brne    game3_done            ; Exit if state has changed
        WAIT_MS 50                    ; Short delay for polling
        rjmp    game3_wait            ; Continue waiting

;---------------------------------------------------------------------
;  CLEANUP - Return to main state handler when done
;---------------------------------------------------------------------
game3_done:
        ret