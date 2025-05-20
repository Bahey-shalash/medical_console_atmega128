;======================================================================
;  main.asm · modular FSM front-end for ATmega128L @ 4 MHz
;======================================================================

        .include "m128def.inc"      ; defines INT0addr…OVF1addr
        .include "macros.asm"
        .include "definitions.asm"
        .include "lcd.asm"
        .include "printf.asm"
        .include "wire1.asm"
        .include "ws2812_driver.asm"

;----------------------------------------------------------------------
;  1) SRAM variables
;----------------------------------------------------------------------
        .dseg
state_cur:   .byte 1
state_next:  .byte 1
flags:       .byte 1
phase:       .byte 1          ; 0=Convert,1=Read
scr_lsb:     .byte 1
scr_msb:     .byte 1

;----------------------------------------------------------------------
;  2) VECTOR TABLE @ 0x0000 (2-byte slots, no overlap)
;----------------------------------------------------------------------
        .cseg
        .org 0x0000
        rjmp  reset

        .org INT0addr
        rjmp  int0_isr
        .org INT1addr
        rjmp  int1_isr
        .org INT2addr
        rjmp  int2_isr
        .org INT3addr
        rjmp  int3_isr
        .org OVF1addr
        rjmp  t1_isr

;----------------------------------------------------------------------
;  3) APPLICATION CODE @ 0x0200
;----------------------------------------------------------------------
        .org 0x0200

; state IDs
        .equ STATE_HOME   = 0
        .equ STATE_GAME1  = 1
        .equ STATE_GAME2  = 2
        .equ STATE_GAME3  = 3
        .equ STATE_DOCTOR = 4
        .equ STATE_COUNT  = 5

        .equ LED_BIT      = 7
        .equ FLG_TEMP     = 0

        .equ T1_PREH      = 0xF0
        .equ T1_PREL      = 0xBE

;======================================================================
;  RESET – hardware initialization
;======================================================================
reset:
        LDSP  RAMEND
        rcall LCD_init
        rcall wire1_init
        rcall ws_init

; configure PD0–PD3 as inputs w/ pull-ups
        cbi   DDRD,0
        cbi   DDRD,1
        cbi   DDRD,2
        cbi   DDRD,3
        sbi   PORTD,0
        sbi   PORTD,1
        sbi   PORTD,2
        sbi   PORTD,3

; heartbeat LED on PC7
        cbi   DDRB,LED_BIT
        cbi   PORTB,LED_BIT
        sbi   DDRC,LED_BIT
        sbi   PORTC,LED_BIT

; Timer1 ? 1 Hz overflow
        ldi   r16,T1_PREH
        out   TCNT1H,r16
        ldi   r16,T1_PREL
        out   TCNT1L,r16
        ldi   r16,(1<<CS12)|(1<<CS10)
        out   TCCR1B,r16
        OUTI  TIMSK,(1<<TOIE1)

; INT0–3 on falling edge
        OUTEI EICRA,0b10101010
        OUTI  EIMSK,0b00001111

        sei

        clr   r16
        sts   state_cur,r16
        sts   state_next,r16

        rcall ds18b20_convert

;======================================================================
;  MAIN LOOP – FSM core
;======================================================================
main_loop:
        ; 1) request state change?
        lds   r16,state_next
        lds   r17,state_cur
        cp    r16,r17
        breq  no_change

        ; leave old state
        mov   r30,r17
        lsl   r30
        ldi   r31,high(state_leave_tbl<<1)
        add   ZL,r30
        adc   ZH,__zero_reg__
        lpm   r30,Z+
        lpm   r31,Z
        ijmp

ret_from_leave:
        ; enter new state
        sts   state_cur,r16
        mov   r30,r16
        lsl   r30
        ldi   r31,high(state_enter_tbl<<1)
        add   ZL,r30
        adc   ZH,__zero_reg__
        lpm   r30,Z+
        lpm   r31,Z
        ijmp

no_change:
        ; 2) service current state
        lds   r16,state_cur
        mov   r30,r16
        lsl   r30
        ldi   r31,high(state_service_tbl<<1)
        add   ZL,r30
        adc   ZH,__zero_reg__
        lpm   r30,Z+
        lpm   r31,Z
        ijmp

after_service:
        ; 3) DS18B20 background
        lds   r16,flags
        sbrs  r16,FLG_TEMP
        rjmp  main_loop

        andi  r16,~(1<<FLG_TEMP)
        sts   flags,r16

        lds   r16,phase
        tst   r16
        breq  do_convert

        rcall ds18b20_read
        clr   r16
        sts   phase,r16
        rjmp  main_loop

do_convert:
        rcall ds18b20_convert
        ldi   r16,1
        sts   phase,r16
        rjmp  main_loop

;======================================================================
;  DS18B20 helpers
;======================================================================
ds18b20_convert:
        push  r16
        rcall wire1_reset
        ldi   a0,skipROM
        rcall wire1_write
        ldi   a0,convertT
        rcall wire1_write
        pop   r16
        ret

ds18b20_read:
        push  r16
        rcall wire1_reset
        ldi   a0,skipROM
        rcall wire1_write
        ldi   a0,readScratchpad
        rcall wire1_write
        rcall wire1_read
        sts   scr_lsb,a0
        rcall wire1_read
        sts   scr_msb,a0
        pop   r16
        ret

;======================================================================
;  Jump-tables & state includes
;======================================================================
state_enter_tbl:
        .dw home_enter, game1_enter, game2_enter, game3_enter, doctor_enter
state_service_tbl:
        .dw home_service, game1_service, game2_service, game3_service, doctor_service
state_leave_tbl:
        .dw home_leave, game1_leave, game2_leave, game3_leave, doctor_leave

        .include "state_home.asm"
        .include "state_game1.asm"
        .include "state_game2.asm"
        .include "state_game3.asm"
        .include "state_doctor.asm"

;======================================================================
;  Interrupt handlers (update state_next)
;======================================================================
int0_isr:
        push  r18
        in    r18,SREG
        push  r18
        lds   r17,state_cur
        cpi   r17,STATE_DOCTOR
        breq  i0_done
        inc   r17
        cpi   r17,STATE_DOCTOR
        brne  i0_store
        clr   r17
i0_store:
        sts   state_next,r17
i0_done:
        pop   r18
        out   SREG,r18
        pop   r18
        reti

int1_isr:
        push  r18
        in    r18,SREG
        push  r18
        lds   r17,state_cur
        cpi   r17,STATE_DOCTOR
        breq  i1_done
        tst   r17
        brne  i1_dec
        ldi   r17,STATE_GAME3
        rjmp  i1_store
i1_dec:
        dec   r17
i1_store:
        sts   state_next,r17
i1_done:
        pop   r18
        out   SREG,r18
        pop   r18
        reti

int2_isr:
        ldi   r17,STATE_HOME
        sts   state_next,r17
        reti

int3_isr:
        ldi   r17,STATE_DOCTOR
        sts   state_next,r17
        reti

t1_isr:
        push  r18
        in    r18,SREG
        push  r18
        ldi   r18,T1_PREH
        out   TCNT1H,r18
        ldi   r18,T1_PREL
        out   TCNT1L,r18
        INVP  PORTC,LED_BIT
        lds   r18,flags
        ori   r18,(1<<FLG_TEMP)
        sts   flags,r18
        pop   r18
        out   SREG,r18
        pop   r18
        reti