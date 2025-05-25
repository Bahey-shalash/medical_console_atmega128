;======================================================================
;  MEDICAL CONSOLE - Main Control Program
;======================================================================
;  Target Hardware: ATmega128L @ 4 MHz on STK-300 Development Board
;
;  Program Description:
;  - Multi-state medical console with temperature monitoring
;  - Implements a finite state machine with multiple operating modes
;  - Includes games, diagnostic tools, and temperature monitoring
;  - Uses DS18B20 digital temperature sensor via 1-Wire protocol
;  - Features WS2812 RGB LED matrix for visual feedback
;  - User input via rotary encoder and push buttons
;
;  Last Modified: May 25, 2025
;======================================================================

;---------------------------------------------------------------------
;  INCLUDES - Core system definitions and macros
;---------------------------------------------------------------------
            .include "m128def.inc"      ; ATmega128 register definitions
            .include "definitions.asm"  ; Global constants and registers
            .include "macros.asm"       ; Utility macros for code simplification

;---------------------------------------------------------------------
;  GLOBAL REGISTERS AND CONSTANTS
;---------------------------------------------------------------------
            .def  sel = r6           ; Current FSM state register
            .def  s   = r14          ; Stable scratch register for operations

            ; System State Constants
            .equ  FLG_TEMP   = 0     ; Bit0 of 'flags' - temperature-ready flag
            .equ  REG_STATES = 4     ; Number of valid game states (0-3)
            .equ  ST_HOME    = 0     ; Home/idle state
            .equ  ST_GAME1   = 1     ; Snake game state
            .equ  ST_GAME2   = 2     ; Game 2 state
            .equ  ST_GAME3   = 3     ; Game 3 state
            .equ  ST_DOCTOR  = 4     ; Diagnostic/doctor mode

            ; Timer and Hardware Constants
            .equ  T1_PREH    = 0xF0  ; Timer-1 preload high byte
            .equ  T1_PREL    = 0xBE  ; Timer-1 preload low byte (approx 1s)
            .equ  LED_BIT    = 7     ; PF7 heartbeat indicator (active-low)
            .equ  BTN_DEBOUNCE = 50  ; Button debounce time in milliseconds

;---------------------------------------------------------------------
;  SRAM ALLOCATION - System variables
;---------------------------------------------------------------------
.dseg
flags:      .byte 1            ; System flags (bit 0 = temperature ready)
temp_lsb:   .byte 1            ; DS18B20 temperature LSB
temp_msb:   .byte 1            ; DS18B20 temperature MSB
phase:      .byte 1            ; Temperature sensor phase (0=convert, 1=read)

;---------------------------------------------------------------------
;  CODE SEGMENT START
;---------------------------------------------------------------------
.cseg

;======================================================================
;  INTERRUPT VECTORS - Defines system interrupt handlers
;======================================================================
            .org 0
            jmp  reset         ; Reset vector - system startup

            .org INT0addr      ; Next state button (increment state)
            jmp  int0_isr
            .org INT1addr      ; Previous state button (decrement state)
            jmp  int1_isr
            .org INT2addr      ; Home button (return to home state)
            jmp  int2_isr
            .org INT3addr      ; Doctor mode button (diagnostic mode)
            jmp  int3_isr
            .org OVF1addr      ; Timer-1 overflow (1 second tick)
            jmp  t1_isr

;---------------------------------------------------------------------
;  LIBRARY INCLUDES - External code modules
;---------------------------------------------------------------------
            ; User interface and IO modules
            .include "lcd.asm"          ; LCD display driver
            .include "printf.asm"       ; Formatted text output
            
            ; Sensor and hardware interface modules
            .include "wire1.asm"        ; 1-Wire protocol for DS18B20
            .include "ws2812_driver.asm"  ; WS2812 RGB LED driver
            .include "encoder.asm"      ; Rotary encoder input handler
            .include "ws2812_helpers.asm" ; WS2812 utility functions

;---------------------------------------------------------------------
;  STATE MODULES - Application state implementations
;---------------------------------------------------------------------
            ; Each state module implements a different console mode
            .include "home_state.asm"    ; Home screen and temperature display
            .include "snake_state.asm"   ; Snake game implementation
            .include "game2_state.asm"   ; Second game implementation
            .include "game3_state.asm"   ; Third game implementation 
            .include "doctor_state.asm"  ; Diagnostic/doctor mode

;======================================================================
;  SYSTEM INITIALIZATION - Hardware and peripherals setup
;======================================================================
reset:
            ; Initialize stack and core peripherals
            LDSP  RAMEND               ; Set stack pointer to top of RAM
            rcall LCD_init             ; Initialize LCD display
            rcall wire1_init           ; Initialize 1-Wire interface
            rcall encoder_init         ; Initialize rotary encoder

            ; Configure buttons (PD0-PD3) as inputs with pull-ups
            cbi   DDRD,0               ; Set as input (next state)
            cbi   DDRD,1               ; Set as input (prev state)
            cbi   DDRD,2               ; Set as input (home)
            cbi   DDRD,3               ; Set as input (doctor mode)
            sbi   PORTD,0              ; Enable pull-up
            sbi   PORTD,1              ; Enable pull-up
            sbi   PORTD,2              ; Enable pull-up
            sbi   PORTD,3              ; Enable pull-up

            ; Initialize WS2812 RGB LED matrix
            rcall ws_init              ; Sets PD7 as output for LED data

            ; Configure heartbeat LED on PF7 (active-low)
            OUTEI DDRF,(1<<LED_BIT)    ; Set PF7 as output
            OUTEI PORTF,(1<<LED_BIT)   ; Turn LED off initially

            ; Ensure WS2812 line is idle low until driver activates
            cbi   PORTD,7

            ; Configure Timer-1 for 1-second periodic interrupt
            ldi   w,T1_PREH            ; Load high byte of preload value
            out   TCNT1H,w
            ldi   w,T1_PREL            ; Load low byte of preload value
            out   TCNT1L,w
            ldi   w,(1<<CS12)|(1<<CS10); Set prescaler to clk/1024
            out   TCCR1B,w
            OUTI  TIMSK,(1<<TOIE1)     ; Enable Timer-1 overflow interrupt

            ; Configure external interrupts (INT0-INT3) for falling edge
            OUTEI EICRA,0b10101010     ; Set falling edge for all interrupts
            OUTI  EIMSK,0b00001111     ; Enable INT0-INT3

            sei                        ; Enable global interrupts

            ; Initialize temperature sensing
            clr   w                    ; Set phase to 0 (conversion mode)
            sts   phase,w
            rcall temp_convert         ; Start first temperature conversion

            clr   sel                  ; Start in Home state (ST_HOME)

;======================================================================
;  MAIN PROGRAM LOOP - State machine implementation
;======================================================================
main_loop:
switch:
            ; Copy current state to stable register for comparison
            mov   s,sel                
            
            ; State dispatch - select appropriate handler based on current state
            _CPI  s,ST_HOME
            brne  swSnake              ; If not HOME state, check next state
            rcall home_init            ; Initialize HOME state
            rjmp  switch               ; Return to state check

swSnake:    ; Snake game state handler
            _CPI  s,ST_GAME1
            brne  swGameTwo            ; If not GAME1 state, check next state
            rcall snake_game_init      ; Initialize Snake game
            rjmp  switch               ; Return to state check

swGameTwo:  ; Game 2 state handler
            _CPI  s,ST_GAME2
            brne  swGameThree          ; If not GAME2 state, check next state
            rcall gameTwoInit          ; Initialize Game 2
            rjmp  switch               ; Return to state check

swGameThree: ; Game 3 state handler
            _CPI  s,ST_GAME3
            brne  swDoctor             ; If not GAME3 state, must be DOCTOR state
            rcall gameThreeInit        ; Initialize Game 3
            rjmp  switch               ; Return to state check

swDoctor:   ; Doctor/diagnostic mode handler
            rcall doctorInit           ; Initialize Doctor mode
            rjmp  switch               ; Return to state check

;======================================================================
;  TEMPERATURE SENSING - DS18B20 interface functions
;======================================================================
; These routines handle the temperature sensor communication
; using the 1-Wire protocol with the DS18B20 sensor.
;----------------------------------------------------------------------

; Initiates a temperature conversion on the DS18B20 sensor
temp_convert:
            push  s                   ; Save scratch register
            rcall wire1_reset         ; Reset 1-Wire bus
            ldi   a0,skipROM          ; Skip ROM command (address all devices)
            rcall wire1_write
            ldi   a0,convertT         ; Start temperature conversion
            rcall wire1_write
            pop   s                   ; Restore scratch register
            ret

; Reads temperature data from the DS18B20 sensor
temp_fetch:
            push  s                   ; Save scratch register
            rcall wire1_reset         ; Reset 1-Wire bus
            ldi   a0,skipROM          ; Skip ROM command
            rcall wire1_write
            ldi   a0,readScratchpad   ; Read scratchpad command
            rcall wire1_write
            rcall wire1_read          ; Read LSB of temperature
            sts   temp_lsb,a0
            rcall wire1_read          ; Read MSB of temperature
            sts   temp_msb,a0
            pop   s                   ; Restore scratch register
            ret

;---------------------------------------------------------------------
;  TEMPERATURE BACKGROUND TASK - Periodic temperature monitoring
;---------------------------------------------------------------------
; This routine handles the background temperature monitoring process
; which alternates between conversion and reading phases.
;----------------------------------------------------------------------

temp_task:
            ; Clear temperature ready flag
            lds   s,flags
            _ANDI s,~(1<<FLG_TEMP)    ; Clear temperature ready flag
            sts   flags,s

            ; Check current phase and handle accordingly
            lds   s,phase
            tst   s                   ; Check if phase = 0 (convert) or 1 (read)
            breq  temp_do_convert     ; If phase=0, start conversion

            ; Phase 1: Read temperature data
            rcall temp_fetch          ; Read temperature from sensor
            clr   s                   ; Set phase back to 0 (convert)
            sts   phase,s
            ret

temp_do_convert:
            ; Phase 0: Start temperature conversion
            rcall temp_convert        ; Start temperature conversion
            _LDI  s,1                 ; Set phase to 1 (read)
            sts   phase,s
            ret

;======================================================================
;  INTERRUPT SERVICE ROUTINES - Button and timer handlers
;======================================================================

;----------------------  INT0 - Next state button  --------------------
int0_isr:
            push  w                    ; Save working register
            inc   sel                  ; Increment state
            ldi   w,REG_STATES         ; Load maximum state number
            cp    sel,w                ; Compare current state with max
            brlo  int0_done            ; If less, we're good
            clr   sel                  ; Otherwise wrap around to 0
int0_done:
            ; WAIT_MS BTN_DEBOUNCE     ; Optional: Add debounce delay
            pop   w                    ; Restore working register
            reti                       ; Return from interrupt

;----------------------  INT1 - Previous state button  ----------------
int1_isr:
            push  w                    ; Save working register
            tst   sel                  ; Test if current state is 0
            brne  int1_dec             ; If not 0, simply decrement
            ldi   w,REG_STATES-1       ; Otherwise wrap to highest state
            mov   sel,w
            ; WAIT_MS BTN_DEBOUNCE     ; Optional: Add debounce delay
            pop   w                    ; Restore working register
            reti
int1_dec:
            dec   sel                  ; Decrement state
            pop   w                    ; Restore working register
            ; WAIT_MS BTN_DEBOUNCE     ; Optional: Add debounce delay
            reti

;----------------------  INT2 - Home button  -------------------------
int2_isr:
            clr   sel                  ; Set state to home (0)
            reti                       ; Return from interrupt

;----------------------  INT3 - Doctor mode button  ------------------
int3_isr:
            push  w                    ; Save working register
            ldi   w,ST_DOCTOR          ; Load doctor mode state number
            mov   sel,w                ; Set current state to doctor mode
            pop   w                    ; Restore working register
            reti                       ; Return from interrupt

;----------------------  Timer-1 overflow (1 second tick)  -----------
t1_isr:
            push  w                    ; Save working register
            push  _w                   ; Save ISR scratch register

            ; Reload timer for next 1-second interval
            ldi   w,T1_PREH            ; Load high byte of preload
            out   TCNT1H,w
            ldi   w,T1_PREL            ; Load low byte of preload
            out   TCNT1L,w

            ; Toggle heartbeat LED on PF7
            lds   s,PORTF              ; Get current port state
            ldi   _w,(1<<LED_BIT)      ; Prepare bit mask
            eor   s,_w                 ; Toggle LED bit
            sts   PORTF,s              ; Update port

            ; Set temperature task flag for background processing
            lds   s,flags              ; Get current flags
            _ORI  s,(1<<FLG_TEMP)      ; Set temperature ready flag
            sts   flags,s              ; Update flags

            pop   _w                   ; Restore ISR scratch register
            pop   w                    ; Restore working register
            reti                       ; Return from interrupt
;======================================================================