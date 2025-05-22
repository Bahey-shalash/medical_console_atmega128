;======================================================================
;  main.asm  · ATmega128L @ 4 MHz · STK-300
;  Modular finite-state machine
;   • WS2812 matrix on PD7  (driver)
;   • LED-strip heartbeat on PF7 (active-low)
;   • Buttons on PD0–PD3 (INT0–INT3)
;======================================================================

            .include "m128def.inc"
            .include "definitions.asm"
            .include "macros.asm"

;----------------------------------------------------------------------
;  Global registers / constants
;----------------------------------------------------------------------
            .def  sel        = r6         ; current state
            .equ  FLG_TEMP   = 0
            .equ  REG_STATES = 4          ; 0–3 = Home…Game3
            .equ  ST_HOME    = 0
            .equ  ST_GAME1   = 1
            .equ  ST_GAME2   = 2
            .equ  ST_GAME3   = 3
            .equ  ST_DOCTOR  = 4

            .equ  T1_PREH    = 0xF0       ; Timer-1 preload (high)
            .equ  T1_PREL    = 0xBE       ; Timer-1 preload (low)
            .equ  LED_BIT    = 7          ; PF7 heartbeat

;----------------------------------------------------------------------
.dseg
flags:      .byte 1                     ; bit 0 = FLG_TEMP
temp_lsb:   .byte 1
temp_msb:   .byte 1
phase:      .byte 1                     ; 0=Convert, 1=Read
;----------------------------------------------------------------------
.cseg
;======================================================================
;  Interrupt vectors
;======================================================================
            .org 0
            jmp  reset
            .org INT0addr
            jmp  int0_isr
            .org INT1addr
            jmp  int1_isr
            .org INT2addr
            jmp  int2_isr
            .org INT3addr
            jmp  int3_isr
            .org OVF1addr
            jmp  t1_isr

;----------------------------------------------------------------------
;  Library / driver includes (after vectors)
;----------------------------------------------------------------------
            .include "lcd.asm"
            .include "printf.asm"
            .include "wire1.asm"
            .include "ws2812_driver.asm"
			.include "encoder.asm"
			.include "ws2812_helpers.asm"
;----------------------------------------------------------------------
;  State modules
;----------------------------------------------------------------------
            .include "home_state.asm"
            .include "snake_state.asm"
            .include "game2_state.asm"
            .include "game3_state.asm"
            .include "doctor_state.asm"
;======================================================================
;  RESET sequence
;======================================================================
reset:
            LDSP  RAMEND
            rcall LCD_init
            rcall wire1_init
			;— WS2812 matrix on PD7 -----------------------------------------------
   
;— Buttons PD0–PD3: inputs w/ pull-ups -------------------------------
            cbi   DDRD,0
            cbi   DDRD,1
            cbi   DDRD,2
            cbi   DDRD,3
            sbi   PORTD,0
            sbi   PORTD,1
            sbi   PORTD,2
            sbi   PORTD,3
			rcall ws_init
;— LED-strip on PF7 (active-low) --------------------------------------
            lds   r16,DDRF
            ori   r16,(1<<LED_BIT)
            sts   DDRF,r16           ; PF7 = output
            lds   r16,PORTF
            ori   r16,(1<<LED_BIT)
            sts   PORTF,r16          ; LED off

;— WS2812 matrix on PD7 -----------------------------------------------
            cbi   PORTD,7            ; ensure low until ws_init

;— Timer-1 one-second tick --------------------------------------------
            ldi   r16,T1_PREH
            out   TCNT1H,r16
            ldi   r16,T1_PREL
            out   TCNT1L,r16
            ldi   r16,(1<<CS12)|(1<<CS10)
            out   TCCR1B,r16
            OUTI  TIMSK,(1<<TOIE1)

;— INT0–INT3 falling-edge config -------------------------------------
            OUTEI EICRA,0b10101010
            OUTI  EIMSK,0b00001111

            sei

;— Initialize WS2812 driver ------------------------------------------
            rcall ws_init

;— Kick off first DS18B20 conversion ---------------------------------
            clr   r16
            sts   phase,r16
            rcall temp_convert

            clr   sel              ; start at Home

;======================================================================
;  MAIN LOOP — state dispatch
;======================================================================
; === main.asm (excerpt – only the dispatch section changed) ==========
; --- dispatch table --------------------------------------------------
main_loop:
switch:
        mov   r16,sel

        cpi   r16,ST_HOME
        brne  swSnake
        rcall home_init
        rjmp  switch

swSnake:
        cpi   r16,ST_GAME1
        brne  swGameTwo
        rcall snake_init
        rjmp  switch

swGameTwo:
        cpi   r16,ST_GAME2
        brne  swGameThree
        rcall gameTwoInit            ; *** label changed
        rjmp  switch

swGameThree:
        cpi   r16,ST_GAME3
        brne  swDoctor
        rcall gameThreeInit          ; *** label changed
        rjmp  switch

swDoctor:
        rcall doctorInit             ; *** colon removed
        rjmp  switch
; ====================================================================

;======================================================================
;  1-Wire helpers
;======================================================================
temp_convert:
            push  r16
            rcall wire1_reset
            ldi   a0,skipROM
            rcall wire1_write
            ldi   a0,convertT
            rcall wire1_write
            pop   r16
            ret

temp_fetch:
            push  r16
            rcall wire1_reset
            ldi   a0,skipROM
            rcall wire1_write
            ldi   a0,readScratchpad
            rcall wire1_write
            rcall wire1_read
            sts   temp_lsb,a0
            rcall wire1_read
            sts   temp_msb,a0
            pop   r16
            ret

;----------------------------------------------------------------------
;  Background temperature task
;----------------------------------------------------------------------
temp_task:
            lds   r16,flags
            andi  r16,~(1<<FLG_TEMP)
            sts   flags,r16

            lds   r16,phase
            tst   r16
            breq  do_convert

            rcall temp_fetch
            clr   r16
            sts   phase,r16
            ret

do_convert:
            rcall temp_convert
            ldi   r16,1
            sts   phase,r16
            ret

;======================================================================
;  Interrupt service routines
;======================================================================
;-----------------------  INT0 – next state  --------------------------
int0_isr:
        push  r16
        inc   sel
        ldi   r16,REG_STATES
        cp    sel,r16
        brlo  int0_done
        clr   sel                   ; wrap 3?0
int0_done:
        pop   r16
        reti

;-----------------------  INT1 – previous state -----------------------
int1_isr:
        push  r16
        tst   sel
        brne  int1_dec
        ldi   r16,REG_STATES-1      ; wrap 0?3
        mov   sel,r16
        pop   r16
        reti
int1_dec:
        dec   sel
        pop   r16
        reti

;-----------------------  INT2 – goto Home ----------------------------
int2_isr:
        clr   sel                   ; ST_HOME
        reti

;-----------------------  INT3 – Doctor mode --------------------------
int3_isr:
        push  r16
        ldi   r16,ST_DOCTOR
        mov   sel,r16
        pop   r16
        reti

;-----------------------  Timer-1 overflow  ---------------------------
t1_isr:
        push  r16
        push  r17

        ; reload counter
        ldi   r16,T1_PREH
        out   TCNT1H,r16
        ldi   r16,T1_PREL
        out   TCNT1L,r16

        ; heartbeat LED on PF7
        lds   r16,PORTF
        ldi   r17,(1<<LED_BIT)
        eor   r16,r17
        sts   PORTF,r16

        ; set “temperature task” flag
        lds   r16,flags
        ori   r16,(1<<FLG_TEMP)
        sts   flags,r16

        pop   r17
        pop   r16
        reti