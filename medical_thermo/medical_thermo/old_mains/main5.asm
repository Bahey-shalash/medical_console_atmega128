;======================================================================
;  main.asm · ATmega128L @ 4 MHz · STK-300
;
;  Screens : Home, Game1, Game2, Game3, Doctor
;  Buttons : PD0-PD3 ? INT0-INT3  (falling-edge)
;  LED     : PC7 (active-low) — PB7 tri-stated
;  Timer-1 : 1-s overflow
;              • toggles LED
;              • drives DS18B20 temperature task
;  DS18B20 : bus on PORTB.DQ  (DQ = 5 in definitions.asm)
;              – Convert-T and Read-Scratchpad alternate each second
;              – Only Doctor screen shows the value
;======================================================================

            .org 0
            jmp  reset
            .org INT0addr                 ; NEXT
            jmp  int0_isr
            .org INT1addr                 ; PREV
            jmp  int1_isr
            .org INT2addr                 ; RESET ? Home
            jmp  int2_isr
            .org INT3addr                 ; DOCTOR
            jmp  int3_isr
            .org OVF1addr                 ; 1-s heartbeat
            jmp  t1_isr

;----------------------------------------------------------------------
;  Includes  (after vectors – avoids any .cseg overlap)
;----------------------------------------------------------------------
            .include "definitions.asm"
            .include "macros.asm"
            .include "lcd.asm"
            .include "printf.asm"
            .include "wire1.asm"          ; 1-Wire low-level helpers

;----------------------------------------------------------------------
;  Registers, flags, constants
;----------------------------------------------------------------------
            .def  sel        = r6         ; FSM state
            .equ  FLG_UPDATE = 0          ; redraw request
            .equ  FLG_TEMP   = 1          ; run temp task

            .equ  REG_STATES = 4          ; 0..3 (Home-Game3)
            .equ  DOCTOR_VAL = 4
            .equ  LAST_IDX   = REG_STATES-1
            .equ  DB_US      = 10000      ; 10-ms debounce

            ; LED line is PC7 (active-low)
            .equ  LED_BIT    = 7

            ; Timer-1 one-second preload (4 MHz /1024 = 3906 ? 0xF0BE)
            .equ  T1_PREH    = 0xF0
            .equ  T1_PREL    = 0xBE

;----------------------------------------------------------------------
.dseg
flags:      .byte 1                ; flag bits

temp_lsb:   .byte 1                ; DS18B20 LSB
temp_msb:   .byte 1                ; DS18B20 MSB
phase:      .byte 1                ; 0 = Convert-T, 1 = Read
;----------------------------------------------------------------------
.cseg
;======================================================================
;  RESET
;======================================================================
reset:
            LDSP  RAMEND
            rcall LCD_init
            rcall wire1_init                 ; 1-Wire bus idle
			OUTI DDRA,0xff

;-- Buttons PD0-PD3 as inputs with pull-ups ---------------------------
            cbi   DDRD,0
            cbi   DDRD,1
            cbi   DDRD,2
            cbi   DDRD,3
            sbi   PORTD,0
            sbi   PORTD,1
            sbi   PORTD,2
            sbi   PORTD,3

;-- LED: old PB7 high-Z, new PC7 output -------------------------------
            cbi   DDRB,LED_BIT
            cbi   PORTB,LED_BIT
            sbi   DDRC,LED_BIT
            sbi   PORTC,LED_BIT          ; LED off (high)

;-- Timer-1 one-second tick -------------------------------------------
            ldi   w,T1_PREH
            out   TCNT1H,w
            ldi   w,T1_PREL
            out   TCNT1L,w
            ldi   w,(1<<CS12)|(1<<CS10)  ; prescale ÷1024
            out   TCCR1B,w
            OUTI  TIMSK,(1<<TOIE1)       ; enable OVF1

;-- INT0-INT3 falling-edge --------------------------------------------
            OUTEI EICRA,0b10101010
            OUTI  EIMSK,0b00001111

            sei

;-- Kick first temperature conversion (phase = 0) ---------------------
            clr   w
            sts   phase,w
            rcall temp_convert

            clr   sel
            ldi   w,(1<<FLG_UPDATE)
            sts   flags,w

;======================================================================
;  MAIN LOOP
;======================================================================
main_loop:
            ; redraw if requested
            lds   w,flags
            sbrc  w,FLG_UPDATE
            rcall redraw

            ; run temperature task if flagged
            lds   w,flags
            sbrc  w,FLG_TEMP
            rcall temp_task

            rjmp  main_loop

;----------------------------------------------------------------------
;  Temperature background task
;----------------------------------------------------------------------
temp_task:
            ; clear FLG_TEMP
            lds   w,flags
            andi  w,~(1<<FLG_TEMP)
            sts   flags,w

            lds   w,phase
            tst   w
            breq  do_convert             ; 0 ? Convert-T

;--- phase 1 : read ----------------------------------------------------
            rcall temp_fetch             ; puts bytes in SRAM
            clr   w
            sts   phase,w                ; next time: convert

            ; if on Doctor screen, force redraw
            mov   w,sel
            cpi   w,DOCTOR_VAL
            brne  temp_done
            lds   w,flags
            ori   w,(1<<FLG_UPDATE)
            sts   flags,w
            rjmp  temp_done

do_convert:
            rcall temp_convert           ; send Convert-T
            ldi   w,1
            sts   phase,w

temp_done:  ret

;----------------------------------------------------------------------
;  Low-level helpers (preserve w)
;----------------------------------------------------------------------
temp_convert:
            push  w
            rcall wire1_reset
            ldi   a0,skipROM
            rcall wire1_write
            ldi   a0,convertT
            rcall wire1_write
            pop   w
            ret

temp_fetch:
            push  w
            rcall wire1_reset
            ldi   a0,skipROM
            rcall wire1_write
            ldi   a0,readScratchpad
            rcall wire1_write
            rcall wire1_read            ; LSB
            sts   temp_lsb,a0
            rcall wire1_read            ; MSB
            sts   temp_msb,a0
            pop   w
            ret

;----------------------------------------------------------------------
;  redraw – debounces keys and re-arms INT0-INT3
;----------------------------------------------------------------------
redraw:
            lds   w,flags
            andi  w,~(1<<FLG_UPDATE)
            sts   flags,w

            rcall show_state
            WAIT_US DB_US

            ldi   w,(1<<INT0)|(1<<INT1)|(1<<INT2)|(1<<INT3)
            out   EIMSK,w
            ret

;----------------------------------------------------------------------
;  show_state – preserves w exactly like original version
;----------------------------------------------------------------------
show_state:
            rcall lcd_clear

            tst   sel
            breq  st_home

            ;-------- compare using original push/ldi/cp pattern ------
            push  w
            ldi   w,1
            cp    sel,w
            pop   w
            breq  st_game1

            push  w
            ldi   w,2
            cp    sel,w
            pop   w
            breq  st_game2

            push  w
            ldi   w,3
            cp    sel,w
            pop   w
            breq  st_game3

; Doctor screen – print temperature
st_doctor:
            lds   a0,temp_lsb
            lds   a1,temp_msb
            PRINTF LCD
            .db "Doctor ",FFRAC2+FSIGN,a,4,$42,"C",0
            ret

st_game3:   PRINTF LCD
            .db "Game3",0
            ret
st_game2:   PRINTF LCD
            .db "Game2",0
            ret
st_game1:   PRINTF LCD
            .db "Game1",0
            ret
st_home:    PRINTF LCD
            .db "Home",0
            ret

;======================================================================
;  External interrupt ISRs (original register usage)
;======================================================================
; [The INT0-INT3 handlers are unchanged from your working version]

; INT0 – NEXT ----------------------------------------------------------
int0_isr:
            push  r17
            push  w
            in    w,SREG
            push  w
            in    w,EIMSK
            andi  w,~(1<<INT0)
            out   EIMSK,w
            ldi   w,DOCTOR_VAL
            cp    sel,w
            breq  i0_flag
            inc   sel
            ldi   w,REG_STATES
            cp    sel,w
            brlo  i0_flag
            clr   sel
i0_flag:    lds   r17,flags
            ori   r17,(1<<FLG_UPDATE)
            sts   flags,r17
            pop   w
            out   SREG,w
            pop   w
            pop   r17
            reti

; INT1 – PREV ----------------------------------------------------------
int1_isr:
            push  r17
            push  w
            in    w,SREG
            push  w
            in    w,EIMSK
            andi  w,~(1<<INT1)
            out   EIMSK,w
            ldi   w,DOCTOR_VAL
            cp    sel,w
            breq  i1_flag
            tst   sel
            brne  dec_ok
            ldi   w,LAST_IDX
            mov   sel,w
            rjmp  i1_flag
dec_ok:     dec   sel
i1_flag:    lds   r17,flags
            ori   r17,(1<<FLG_UPDATE)
            sts   flags,r17
            pop   w
            out   SREG,w
            pop   w
            pop   r17
            reti

; INT2 – RESET ---------------------------------------------------------
int2_isr:
            push  r17
            push  w
            in    w,SREG
            push  w
            in    w,EIMSK
            andi  w,~(1<<INT2)
            out   EIMSK,w
            clr   sel
            lds   r17,flags
            ori   r17,(1<<FLG_UPDATE)
            sts   flags,r17
            pop   w
            out   SREG,w
            pop   w
            pop   r17
            reti

; INT3 – DOCTOR --------------------------------------------------------
int3_isr:
            push  r17
            push  w
            in    w,SREG
            push  w
            in    w,EIMSK
            andi  w,~(1<<INT3)
            out   EIMSK,w
            ldi   w,DOCTOR_VAL
            mov   sel,w
            lds   r17,flags
            ori   r17,(1<<FLG_UPDATE)
            sts   flags,r17
            pop   w
            out   SREG,w
            pop   w
            pop   r17
            reti

;======================================================================
;  Timer-1 Overflow ISR – LED blink + flag temp task
;======================================================================
t1_isr:
            push  w
            in    w,SREG
            push  w

            ; reload preload
            ldi   w,T1_PREH
            out   TCNT1H,w
            ldi   w,T1_PREL
            out   TCNT1L,w

            INVP  PORTC,LED_BIT          ; blink LED

            lds   w,flags
            ori   w,(1<<FLG_TEMP)
            sts   flags,w

            pop   w
            out   SREG,w
            pop   w
            reti