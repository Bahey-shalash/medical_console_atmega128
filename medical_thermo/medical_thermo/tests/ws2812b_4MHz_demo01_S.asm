; file	ws2812b_4MHz_demo01_S.asm   target ATmega128L-4MHz-STK300
; purpose send data to ws2812b using 4 MHz MCU and standard I/O port
;         display and paralllel process (blinking LED0)
; usage: buttons on PORTC, ws2812 on PORTD (bit 1)
;        press button 0
;       a pattern is stored into memory and displayed on the array
;       LED0 blinks fast; when button0 is pressed and released, LED1
;       akcnowledges and the pattern displayed on the array moves by
;       one memory location
; warnings: 1/2 timings of pulses in the macros are sensitive
;			2/2 intensity of LEDs is high, thus keep intensities
;				within the range 0x00-0x0f, and do not look into
;				LEDs
; 20220315 AxS

.include "macros.asm"		; include macro definitions
.include "definitions.asm"	; include register/constant definitions

; WS2812b4_WR0	; macro ; arg: void; used: void
; purpose: write an active-high zero-pulse to PD1
.macro	WS2812b4_WR0
	clr u
	sbi PORTD, 1
	out PORTD, u
	nop
	nop
	;nop	;deactivated on purpose of respecting timings
	;nop
.endm

; WS2812b4_WR1	; macro ; arg: void; used: void
; purpose: write an active-high one-pulse to PD1
.macro	WS2812b4_WR1
	sbi PORTD, 1
	nop
	nop
	cbi PORTD, 1
	;nop	;deactivated on purpose of respecting timings
	;nop

.endm

.org 0
	jmp	reset


reset:
	LDSP	RAMEND			; Load Stack Pointer (SP)
	rcall	ws2812b4_init	; initialize 
	OUTI	DDRB, 0xff		; connect LEDs to PORTB, output mode
	OUTI	DDRC, 0x00		; connectbuttons to PORTC, input mode

main:
	; ------ part 1: store image that will be displayed into SRAM
	ldi	b0,17	; 64 pls = 16 * 4 pls, 17 due to loop condition
	clr b1
	ldi zl,low(0x0400)
	ldi zh,high(0x0400)

imgld_loop:
	ldi	a0, 0x0f	; pixel 1, light green
	st	z+,a0
	ldi a0,0x00
	st	z+,a0
	ldi	a0, 0x00
	st z+,a0

	ldi	a0, 0x00	; pixel 2, light red
	st	z+,a0
	ldi a0,0x0f
	st	z+,a0
	ldi	a0, 0x00
	st z+,a0

	ldi	a0, 0x00	; pixel 3, light blue
	st	z+,a0
	ldi a0,0x00
	st	z+,a0
	ldi	a0, 0x0f
	st z+,a0

	ldi	a0, 0x00	; pixel 4, off
	st	z+,a0
	ldi a0,0x00
	st	z+,a0
	ldi	a0, 0x00
	st z+,a0

	dec b0
	brne imgld_loop

	; ------ part 2, display: read image from SRAM and send to display
restart:

	ldi zl,low(0x0400)
	ldi zh,high(0x0400)
	add	zl,b1

	_LDI	r0,64
loop:

	ld a0, z+
	;add a1,b1		; increase intensity (and color) until all white
	ld a1, z+		;>and high intensity, uncomment to use
	;add a1,b1
	ld a2,z+
	;add a2,b1

	cli
	rcall ws2812b4_byte3wr
	sei

	dec r0
	brne loop
	rcall ws2812b4_reset

switch:
	sbic PINC,0
	rjmp cproc01
	sbis PINC,0
	rjmp PC-1

	inc b1
	INVP PORTB, 1
	jmp restart

cproc01:
	INVP PORTB,0		; blink LED to assume a parallel process
	WAIT_MS 20
	rjmp switch


; ws2812b4_init		; arg: void; used: r16 (w)
; purpose: initialize AVR to support ws2812
ws2812b4_init:
	OUTI	DDRD,0x02
ret

; ws2812b4_byte3wr	; arg: a0,a1,a2 ; used: r16 (w)
; purpose: write contents of a0,a1,a2 (24 bit) into ws2812, 1 LED configuring
;     GBR color coding, LSB first
ws2812b4_byte3wr:

	ldi w,8
ws2b3_starta0:
	sbrc a0,7
	rjmp	ws2b3w1
	WS2812b4_WR0			; write a zero
	rjmp	ws2b3_nexta0
ws2b3w1:
	WS2812b4_WR1
ws2b3_nexta0:
	lsl a0
	dec	w
	brne ws2b3_starta0

	ldi w,8
ws2b3_starta1:
	sbrc a1,7
	rjmp	ws2b3w1a1
	WS2812b4_WR0			; write a zero
	rjmp	ws2b3_nexta1
ws2b3w1a1:
	WS2812b4_WR1
ws2b3_nexta1:
	lsl a1
	dec	w
	brne ws2b3_starta1

	ldi w,8
ws2b3_starta2:
	sbrc a2,7
	rjmp	ws2b3w1a2
	WS2812b4_WR0			; write a zero
	rjmp	ws2b3_nexta2
ws2b3w1a2:
	WS2812b4_WR1
ws2b3_nexta2:
	lsl a2
	dec	w
	brne ws2b3_starta2
	
ret

; ws2812b4_reset	; arg: void; used: r16 (w)
; purpose: reset pulse, configuration becomes effective
ws2812b4_reset:
	cbi PORTD, 1
	WAIT_US	50 	; 50 us are required, NO smaller works
ret