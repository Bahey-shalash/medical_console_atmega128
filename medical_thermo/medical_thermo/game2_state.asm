;======================================================================
;  GAME 2 STATE - Placeholder for Future Game Implementation
;======================================================================
;  Target: ATmega128L @ 4MHz
;
;  Description:
;  This file implements a placeholder state for a future game (Game 2).
;  It currently provides a basic template with a blue LED matrix display
;  and "GAME 2" text on the LCD. The implementation loops until the user
;  changes to a different state.
;
;  Functions:
;  - gameTwoInit: Initialize Game 2 state (LCD and LED matrix)
;  - game2_wait: Main loop that monitors the current state
;
;  Register Usage:
;  - s: Used to check current system state
;  - a0-a2: RGB color components for LED matrix (GRB order)
;  - sel: System state register (defined in main.asm)
;
;  Dependencies:
;  - Requires LCD driver for text display
;  - Uses WS2812 helper functions for LED matrix control
;  - Relies on ST_GAME2 constant from main.asm
;
;  Last Modified: May 25, 2025
;======================================================================

;----------------------------------------------------------------------
;  GAME 2  state (placeholder for a future game)
;----------------------------------------------------------------------

gameTwoInit:
        ;---------------------------------------------------------------------
        ;  INITIALIZATION - Setup LCD display with game title
        ;---------------------------------------------------------------------
        rcall   lcd_clear
        PRINTF  LCD
        .db     "GAME 2",0,0

        ;---------------------------------------------------------------------
        ;  VISUAL INDICATOR - Set LED matrix to solid blue
        ;---------------------------------------------------------------------
        ; Set color to blue (GRB order: a0=G, a1=R, a2=B)
        ldi     a0, 0x00
        ldi     a1, 0x00
        ldi     a2, 0x0F
        rcall   matrix_solid

;---------------------------------------------------------------------
;  MAIN LOOP - Wait until user changes the state
;---------------------------------------------------------------------
game2_wait:
        ;---------------------------------------------------------------------
        ;  STATE CHECKING - Monitor if current state is still Game 2
        ;---------------------------------------------------------------------
        mov     s, sel
        _CPI     s, ST_GAME2
        brne    game2_done            ; Exit if state has changed
        WAIT_MS 50                    ; Short delay for polling
        rjmp    game2_wait            ; Continue waiting

;---------------------------------------------------------------------
;  CLEANUP - Return to main state handler when done
;---------------------------------------------------------------------
game2_done:
        ret