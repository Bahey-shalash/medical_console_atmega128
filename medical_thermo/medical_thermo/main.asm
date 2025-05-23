;======================================================================
;  main.asm  � ATmega128L @ 4 MHz � STK-300
;  Modular finite-state machine
;   � WS2812 matrix on PD7  (driver)
;   � LED-strip heartbeat on PF7 (active-low)
;   � Buttons on PD0�PD3 (INT0�INT3)
;======================================================================
;
;  Register policy ----------------------------------------------------
;  r16 = w   : volatile scratch, clobbered by nearly every macro �
;              do **not** rely on its value except right after you
;              loaded it yourself and before the next macro call.
;  r17 = _w  : scratch inside interrupt prologues only.
;  r14 = s   : long-lived scratch for general calculations � never
;              touched by macros.  Preserve if you call sub-routines
;              that may use it.
;---------------------------------------------------------------------

            .include "m128def.inc"
            .include "definitions.asm"
            .include "macros.asm"

;---------------------------------------------------------------------
;  Global registers / constants
;---------------------------------------------------------------------
            .def  sel = r6           ; current FSM state
            .def  s   = r14          ; stable scratch register

            .equ  FLG_TEMP   = 0     ; bit0 of `flags`  � temperature-ready
            .equ  REG_STATES = 4     ; valid game states 0�3
            .equ  ST_HOME    = 0
            .equ  ST_GAME1   = 1
            .equ  ST_GAME2   = 2
            .equ  ST_GAME3   = 3
            .equ  ST_DOCTOR  = 4

            .equ  T1_PREH    = 0xF0  ; Timer-1 preload (high)
            .equ  T1_PREL    = 0xBE  ; Timer-1 preload (low)
            .equ  LED_BIT    = 7     ; PF7 heartbeat (active-low)

;---------------------------------------------------------------------
;  SRAM allocation
;---------------------------------------------------------------------
.dseg
flags:      .byte 1            ; bit-flags (0 = FLG_TEMP)
temp_lsb:   .byte 1            ; DS18B20 LSB
temp_msb:   .byte 1            ; DS18B20 MSB
phase:      .byte 1            ; 0 = convert, 1 = read

;---------------------------------------------------------------------
.cseg
;======================================================================
;  Interrupt vectors
;======================================================================
            .org 0
            jmp  reset

            .org INT0addr      ; next state
            jmp  int0_isr
            .org INT1addr      ; previous state
            jmp  int1_isr
            .org INT2addr      ; go home
            jmp  int2_isr
            .org INT3addr      ; doctor mode
            jmp  int3_isr
            .org OVF1addr      ; Timer-1 overflow
            jmp  t1_isr

;---------------------------------------------------------------------
;  Library / driver includes (after vectors)
;---------------------------------------------------------------------
            .include "lcd.asm"
            .include "printf.asm"
            .include "wire1.asm"
            .include "ws2812_driver.asm"
            .include "encoder.asm"
            .include "ws2812_helpers.asm"

;---------------------------------------------------------------------
;  State modules
;---------------------------------------------------------------------
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
			rcall encoder_init

; � Buttons PD0�PD3: inputs with pull-ups ----------------------------
            cbi   DDRD,0
            cbi   DDRD,1
            cbi   DDRD,2
            cbi   DDRD,3
            sbi   PORTD,0
            sbi   PORTD,1
            sbi   PORTD,2
            sbi   PORTD,3

; � WS2812 driver init (sets PD7 output) -----------------------------
            rcall ws_init

; � Heartbeat LED on PF7 (active-low) --------------------------------
            OUTEI DDRF,(1<<LED_BIT)    ; PF7 ? output (clobbers w)
            OUTEI PORTF,(1<<LED_BIT)   ; drive high = LED off

; === DEBUG LEDs on PF6 (CW) and PF5 (CCW) ============================
;        OUTEI DDRF,((1<<6)|(1<<5))       ; PF6 | PF5 ? outputs
 ;       OUTEI PORTF,((1<<6)|(1<<5))      ; start high  (LEDs off)


; � Ensure WS2812 line idle low until driver starts ------------------
            cbi   PORTD,7

; � Timer-1 one-second tick ------------------------------------------
            ldi   w,T1_PREH
            out   TCNT1H,w
            ldi   w,T1_PREL
            out   TCNT1L,w
            ldi   w,(1<<CS12)|(1<<CS10)
            out   TCCR1B,w
            OUTI  TIMSK,(1<<TOIE1)

; � INT0�INT3 falling-edge config -----------------------------------
            OUTEI EICRA,0b10101010
            OUTI  EIMSK,0b00001111

            sei                         ; global IRQ enable

; � Kick off first DS18B20 conversion --------------------------------
            clr   w                     ; w is volatile � fine here
            sts   phase,w
            rcall temp_convert

            clr   sel                   ; start in Home state

;======================================================================
;  MAIN LOOP � state dispatch
;======================================================================
main_loop:
switch:
            mov   s,sel                ; copy once, keep stable
            _CPI   s,ST_HOME
            brne  swSnake
            rcall home_init
            rjmp  switch

swSnake:
            _CPI   s,ST_GAME1
            brne  swGameTwo
            rcall snake_game_init; changed nameeeee
            rjmp  switch

swGameTwo:
            _CPI   s,ST_GAME2
            brne  swGameThree
            rcall gameTwoInit
            rjmp  switch

swGameThree:
            _CPI   s,ST_GAME3
            brne  swDoctor
            rcall gameThreeInit
            rjmp  switch

swDoctor:
            rcall doctorInit
            rjmp  switch

;======================================================================
;  1-Wire helpers
;======================================================================
; Use s (r14) instead of w so we don�t depend on the volatile macro reg.

temp_convert:
            push  s
            rcall wire1_reset
            ldi   a0,skipROM
            rcall wire1_write
            ldi   a0,convertT
            rcall wire1_write
            pop   s
            ret

temp_fetch:
            push  s
            rcall wire1_reset
            ldi   a0,skipROM
            rcall wire1_write
            ldi   a0,readScratchpad
            rcall wire1_write
            rcall wire1_read
            sts   temp_lsb,a0
            rcall wire1_read
            sts   temp_msb,a0
            pop   s
            ret

;---------------------------------------------------------------------
;  Background temperature task
;---------------------------------------------------------------------
; Only s is used; w may change at macro calls we don�t care about here.

temp_task:
            lds   s,flags
            _ANDI  s,~(1<<FLG_TEMP)
            sts   flags,s

            lds   s,phase
            tst   s
            breq  temp_do_convert

            rcall temp_fetch
            clr   s
            sts   phase,s
            ret

temp_do_convert:
            rcall temp_convert
            _LDI   s,1
            sts   phase,s
            ret

;======================================================================
;  Interrupt service routines
;======================================================================
;----------------------  INT0 � next state  ---------------------------
int0_isr:
            push  w                    ; save volatile macro reg
            inc   sel
            ldi   w,REG_STATES
            cp    sel,w
            brlo  int0_done
            clr   sel                  ; wrap ? 0
int0_done:
            pop   w
            reti

;----------------------  INT1 � previous state ------------------------
int1_isr:
            push  w
            tst   sel
            brne  int1_dec
            ldi   w,REG_STATES-1       ; wrap ? 3
            mov   sel,w
            pop   w
            reti
int1_dec:
            dec   sel
            pop   w
            reti

;----------------------  INT2 � goto Home ----------------------------
int2_isr:
            clr   sel
            reti

;----------------------  INT3 � Doctor mode --------------------------
int3_isr:
            push  w
            ldi   w,ST_DOCTOR
            mov   sel,w
            pop   w
            reti

;----------------------  Timer-1 overflow ----------------------------
t1_isr:
            push  w                     ; save macro scratch
            push  _w                    ; save ISR scratch

            ; reload counter
            ldi   w,T1_PREH
            out   TCNT1H,w
            ldi   w,T1_PREL
            out   TCNT1L,w

            ; heartbeat LED on PF7 (toggle)
            lds   s,PORTF
            ldi   _w,(1<<LED_BIT)
            eor   s,_w
            sts   PORTF,s

            ; set temperature task flag
            lds   s,flags
            _ORI   s,(1<<FLG_TEMP)
            sts   flags,s

            pop   _w
            pop   w
            reti
;======================================================================
;TODO: increse the debounce time for the buttons 
;TODO: Wrap cli/sei around wire1_reset, wire1_read*, and wire1_write* (or at least around WIRE1 calls) before adding faster or more frequent interrupts.