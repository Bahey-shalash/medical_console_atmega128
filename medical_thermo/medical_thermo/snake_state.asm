;======================================================================
;  snake_state.asm   – Stub version (sel == ST_GAME1)
;======================================================================

;  no scratch RAM needed
.dseg
.cseg

;----------------------------------------------------------------------
;  INIT  – called from main_loop
;----------------------------------------------------------------------
snake_init:
        push  r18
        push  r19
        rcall lcd_clear
        rcall snake_loop
        pop   r19
        pop   r18
        ret

;----------------------------------------------------------------------
;  LOOP  – while sel == ST_GAME1
;----------------------------------------------------------------------
snake_loop:
loop_snk:
        ;----- LCD ----------------------------------------------------
        rcall lcd_clear
        PRINTF LCD
        .db "Snake - WIP",0

        ;----- Matrix: just clear (all LEDs off) ----------------------
        ldi  a0, 0x00
        ldi  a1, 0x00
        ldi  a2, 0x00
        rcall ws_fill_color
        rcall ws_show_frame

        ;----- housekeeping ------------------------------------------
        WAIT_US 250000            ; ~4 Hz
        lds   r18, flags
        sbrc  r18, FLG_TEMP
        rcall temp_task
        WAIT_US 50000

        ;----- stay in this state? -----------------------------------
        mov   r19, sel
        cpi   r19, ST_GAME1
        breq  loop_snk
        ret