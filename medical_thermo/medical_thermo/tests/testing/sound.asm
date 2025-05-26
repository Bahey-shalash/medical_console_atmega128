;==============================================================================
; file: sound.asm           target ATmega128L-4MHz-STK300
; purpose: library, sound generation without .-2/.+1 tricks
;==============================================================================

; entry: a0 = period (in 10 µs units), b0 = duration (in 2.5 ms units)
sound:
    mov   b1, b0          ; duration.high = b0
    clr   b0              ; duration.low  = 0
    clr   a1              ; period.high   = 0
    tst   a0
    breq  sound_off       ; if period=0 ? silent busy-wait

;—— main toggle loop ————————————————————————————————————————————————
sound_play:
    mov   w, a0
    rcall wait9us         ; ?9 µs
sound_delay:
    nop                   ; ?0.25 µs
    dec   w               ; ?0.25 µs
    brne  sound_delay     ; ?0.5 µs more ? total ?10 µs
    INVP  PORTE, SPEAKER  ; toggle piezo pin
    sub   b0, a0          ; decrement duration
    sbc   b1, a1
    brcc  sound_play      ; keep going while > 0
    ret

;—— “silence” busy-wait when a0=0 ——————————————————————————————————————
sound_off:
    ldi   a0, 1
    rcall wait9us
sound_off_delay:
    sub   b0, a0
    sbc   b1, a1
    brcc  sound_off_delay
    ret

;=== delay subroutines ===

wait2us:    nop          ; 1 cycle
            ret          ; 4 cycles ? ?2 µs

wait4us:    rcall wait2us ; 3+2 µs
            rcall wait2us
            ret

wait8us:    rcall wait4us
            rcall wait4us
            ret

wait9us:    rcall wait8us
            nop           ; +1 cycle
            ret

;=== musical scale definitions (period = 100 000/freq in 10 µs units) ===
.equ do    = 50000/517
.equ dom   = do*944/1000
.equ re    = do*891/1000
.equ rem   = do*841/1000
.equ mi    = do*794/1000
.equ fa    = do*749/1000
.equ fam   = do*707/1000
.equ so    = do*667/1000
.equ som   = do*630/1000
.equ la    = do*595/1000
.equ lam   = do*561/1000
.equ si    = do*530/1000

.equ do2   = do/2
.equ dom2  = dom/2
.equ re2   = re/2
.equ rem2  = rem/2
.equ mi2   = mi/2
.equ fa2   = fa/2
.equ fam2  = fam/2
.equ so2   = so/2
.equ som2  = som/2
.equ la2   = la/2
.equ lam2  = lam/2
.equ si2   = si/2

.equ do3   = do/4
.equ dom3  = dom/4
.equ re3   = re/4
.equ rem3  = rem/4
.equ mi3   = mi/4
.equ fa3   = fa/4
.equ fam3  = fam/4
.equ so3   = so/4
.equ som3  = som/4
.equ la3   = la/4
.equ lam3 = lam/4
.equ si3   = si/4
;==============================================================================