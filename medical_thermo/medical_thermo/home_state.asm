;======================================================================
;  home_state.asm   – Home screen  (sel == ST_HOME)
;======================================================================


;----------------------------------------------------------------------
;  INIT  – called from main_loop
;----------------------------------------------------------------------
home_init:
        push  r18
        push  r19
        rcall lcd_clear
        ; --- one-shot initialisation goes here if ever needed ---
        rcall home_loop
        pop   r19
        pop   r18
        ret

;----------------------------------------------------------------------
;  LOOP  – while sel == ST_HOME
;----------------------------------------------------------------------
home_loop:
loop_home:
        ;----- LCD ----------------------------------------------------
        rcall lcd_clear
        PRINTF LCD
        .db "Home",0

        ;----- Matrix: solid dim-white -------------------------------
        ldi  a0, 0x03             ; G
        ldi  a1, 0x03             ; R
        ldi  a2, 0x03             ; B
        rcall ws_fill_color
        rcall ws_show_frame

        ;----- housekeeping ------------------------------------------
        WAIT_US 250000            ; ~4 Hz
        lds  r18, flags
        sbrc r18, FLG_TEMP
        rcall temp_task
        WAIT_US 50000             ; ~50 ms

        ;----- stay in this state? -----------------------------------
        mov  r19, sel
        cpi  r19, ST_HOME
        breq loop_home
        ret