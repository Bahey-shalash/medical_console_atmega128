;======================================================================
;  SNAKE GAME IMPLEMENTATION - Classic Snake Game for LED Matrix
;======================================================================
;  Target: ATmega128L @ 4MHz
;
;  Game Description:
;  This file implements a classic Snake game that runs on an 8×8 RGB LED
;  matrix. The player controls a snake that grows in length each time it
;  eats an apple. The game ends if the snake collides with the walls.
;
;  Features:
;  - Blue snake head with green body segments
;  - Red apple that randomly respawns when eaten
;  - Rotary encoder control with direction queue
;  - Growing snake length when eating apples
;  - Wall collision detection (game over condition)
;
;  Technical Implementation:
;  - Uses WS2812B RGB LED matrix for display
;  - Snake stored as positions in SRAM buffer
;  - Circular queue for processing direction changes
;  - Pseudo-random number generation for apple placement
;  - Fixed frame rate gameplay (configurable delay)
;
;  Register Usage:
;  - r18-r26: Used for game state calculations
;  - ZL,ZH: Memory pointers for accessing snake data
;  - a0-a2: RGB color components for LED matrix
;
;  Last Modified: May 25, 2025
;======================================================================

;---------------------------------------------------------------------
;  SYMBOLIC CONSTANTS - Game parameters and configuration
;---------------------------------------------------------------------
.equ DIR_UPP              = 0
.equ DIR_RIGHTT           = 1
.equ DIR_DOWNN            = 2
.equ DIR_LEFTT            = 3
.equ DIR_INITT            = DIR_RIGHTT

.equ Apple_INIT_POS       = 45 ; (5,5) in 8x8 matrix

.equ SNAKE_INIT_POS1      = 26
.equ SNAKE_INIT_POS2      = 27
.equ SNAKE_INIT_POS3      = 28
.equ SNAKE_INIT_HEAD_IDX  = 2
.equ SNAKE_INIT_LEN       = 3

.equ FRAME_DELAY_MS       = 500

.equ MATRIX_SIZE          = 8
.equ GRID_CELLS           = MATRIX_SIZE * MATRIX_SIZE
.equ COORD_MASK           = 0x07

.equ QUEUE_SIZE           = 8
.equ QUEUE_MASK           = QUEUE_SIZE - 1

.equ APPLE_PLACEMENT_TRIES = 8

.equ EMPTY_CELL           = 0xFF
.equ BODY_GREEN           = 0x0F
.equ HEAD_BLUE            = 0x0F
.equ APPLE_RED            = 0x0F

;---------------------------------------------------------------------
;  SRAM LAYOUT - Game state variables
;---------------------------------------------------------------------
.dseg
snake_body:   .byte GRID_CELLS      ; packed x + MATRIX_SIZE*y
head_idx:     .byte 1
tail_idx:     .byte 1
snake_len:    .byte 1

direction:    .byte 1               ; DIR_UPP..DIR_LEFTT
apple_pos:    .byte 1               ; EMPTY_CELL = no apple

turn_queue:   .byte QUEUE_SIZE
tq_head:      .byte 1
tq_tail:      .byte 1
.cseg

;=====================================================================
;  INITIALIZATION - Game setup and data initialization
;=====================================================================
; This section initializes the game by:
; - Clearing the LCD and displaying "SNAKE"
; - Initializing the rotary encoder
; - Setting up the initial snake data
; - Drawing the initial game state
;---------------------------------------------------------------------
snake_game_init:
    rcall lcd_clear
    PRINTF LCD
    .db "SNAKE",0

    rcall encoder_init
    rcall snake_init_data
    rcall snake_draw
    rjmp snake_wait

;---------------------------------------------------------------------
;  DATA INITIALIZATION - Setup initial game state
;---------------------------------------------------------------------
; Sets up the initial snake position, direction, apple placement,
; and other game parameters. Clears the entire play field and places
; the snake in its starting position.
;---------------------------------------------------------------------
snake_init_data:
    ; clear body buffer → EMPTY_CELL
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi r22, GRID_CELLS
clear_body:
    ldi w, EMPTY_CELL
    st  Z+, w
    dec r22
    brne clear_body

    ; seed snake at three positions
    ldi ZL, low(snake_body)
    ldi ZH, high(snake_body)
    ldi w, SNAKE_INIT_POS1
    st  Z+, w
    ldi w, SNAKE_INIT_POS2
    st  Z+, w
    ldi w, SNAKE_INIT_POS3
    st  Z , w

    ; indices & length
    ldi w, SNAKE_INIT_HEAD_IDX
    sts head_idx, w
    clr w
    sts tail_idx, w
    ldi w, SNAKE_INIT_LEN
    sts snake_len, w

    ; initial direction & apple
    ldi w, DIR_INITT
    sts direction, w
    ldi w, Apple_INIT_POS
    sts apple_pos, w

    ; queue pointers
    clr w
    sts tq_head, w
    sts tq_tail, w

    ; encoder state
    clr a0
    clr b0
    in  w, ENCOD
    sts enc_old, w
    ret  ; Timer-0 prescaler untouched – PRNG read only

;=====================================================================
;  MAIN LOOP - Game cycle with fixed frame rate
;=====================================================================
; Controls the main game timing loop. Each frame consists of:
; - A fixed delay period (FRAME_DELAY_MS)
; - Processing user input during the delay
; - Moving the snake
; - Drawing the updated game state
; - Checking if player has exited the game
;---------------------------------------------------------------------
snake_wait:
    ; start-of-frame delay
    ldi r24, low(FRAME_DELAY_MS)
    ldi r25, high(FRAME_DELAY_MS)
frame_delay:
    rcall update_game
    WAIT_MS 1
    sbiw r24, 1
    brne frame_delay

    rcall move_snake
    rcall snake_draw

    ; prepare next frame
    ldi r24, low(FRAME_DELAY_MS)
    ldi r25, high(FRAME_DELAY_MS)
    mov s, sel
    _CPI s, ST_GAME1
    breq frame_delay
    ret

;=====================================================================
;  USER INPUT HANDLING - Process rotary encoder movements
;=====================================================================
; Reads the rotary encoder and updates the snake's direction based
; on encoder rotation. Implements a queue system to store direction
; changes that haven't been processed yet. Prevents 180° turns.
;---------------------------------------------------------------------
update_game:
    push r25
    push r24
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23

    rcall encoder_update        ; r15 = ±1 or 0
    mov  r19, r15
    tst  r19
    brne enc_move
    rjmp enc_exit

enc_move:
    lds  r21, direction
    tst  r19
    brmi enc_left

enc_right:
    mov  r20, r21
    inc  r20
    cpi  r20, DIR_LEFTT+1
    brlo enc_chk
    clr  r20
    rjmp enc_chk

enc_left:
    mov  r20, r21
    tst  r20
    brne enc_left_ok
    ldi  r20, DIR_LEFTT
    rjmp enc_chk
enc_left_ok:
    dec  r20

enc_chk:                      ; reject 180°
    mov  r22, r21  ; r22 = old_direction
    subi r22, -2     ; r22 = old_direction + 2
    andi r22, 0x03  ; r22 = (old_direction + 2) & 0b11 = (old_direction + 2) mod 4
    cp   r20, r22    ; compare new_direction to the 180°-opposite
    breq enc_exit   ; if equal, reject the 180° turn

    ; enqueue
    lds  r23, tq_head
    mov  r24, r23
    inc  r24
    andi r24, QUEUE_MASK
    lds  r22, tq_tail
    cp   r24, r22
    breq enc_exit

    ldi  ZL, low(turn_queue)
    ldi  ZH, high(turn_queue)
    add  ZL, r23
    brcc enc_store
    inc  ZH
enc_store:
    st   Z, r20
    sts  tq_head, r24

    ; dequeue immediately
    lds  r22, tq_tail
    lds  r23, tq_head
    cp   r22, r23
    breq enc_exit

    ldi  ZL, low(turn_queue)
    ldi  ZH, high(turn_queue)
    add  ZL, r22
    brcc enc_read
    inc  ZH
enc_read:
    ld   r20, Z
    inc  r22
    andi r22, QUEUE_MASK
    sts  tq_tail, r22
    sts  direction, r20

enc_exit:
    pop  r23
    pop  r22
    pop  r21
    pop  r20
    pop  r19
    pop  r18
    pop  r24
    pop  r25
    ret

;=====================================================================
;  SNAKE MOVEMENT - Update snake position and handle collisions
;=====================================================================
; Calculates the snake's new head position based on current direction
; Checks for collisions with walls and handles apple eating
; Updates the snake's length and position data
;---------------------------------------------------------------------
move_snake:
    lds  r18, direction

    ; fetch current head
    lds  r19, head_idx
    ldi  ZL, low(snake_body)
    ldi  ZH, high(snake_body)
    add  ZL, r19
    brcc head_ptr
    inc  ZH
head_ptr:
    ld   r20, Z

    ; unpack x,y
    mov  r21, r20
    andi r21, COORD_MASK
    mov  r22, r20
    lsr  r22
    lsr  r22
    lsr  r22
    andi r22, COORD_MASK

    ; border check & compute next cell
    cpi  r18, DIR_RIGHTT
    breq dir_right
    cpi  r18, DIR_LEFTT
    breq dir_left
    cpi  r18, DIR_UPP
    breq dir_up
    inc  r22
    cpi  r22, MATRIX_SIZE
    brne pack_cell
    rjmp hit_wall

dir_right:
    inc  r21
    cpi  r21, MATRIX_SIZE
    brne pack_cell
    rjmp hit_wall

dir_left:
    tst  r21
    breq hit_wall
    dec  r21
    rjmp pack_cell

dir_up:
    tst  r22
    breq hit_wall
    dec  r22

pack_cell:
    ; pack new head
    mov  r20, r22
    lsl  r20
    lsl  r20
    lsl  r20
    add  r20, r21

    ; apple collision?
    lds  r23, apple_pos
    cpi  r23, EMPTY_CELL
    breq write_head
    cp   r20, r23
    brne write_head

    ; eat apple → reposition & grow
    ldi  r23, EMPTY_CELL
    sts  apple_pos, r23
    rcall place_new_apple
    lds  r24, snake_len
    cpi  r24, GRID_CELLS
    breq write_head
    inc  r24
    sts  snake_len, r24
    rjmp write_head_no_tail

write_head:
    ; advance tail normally
    lds  r21, tail_idx
    inc  r21
    cpi  r21, GRID_CELLS
    brlo tail_ok
    clr  r21
tail_ok:
    sts  tail_idx, r21

write_head_no_tail:
    ; advance head index & write new head
    lds  r19, head_idx
    inc  r19
    cpi  r19, GRID_CELLS
    brlo idx_ok_write
    clr  r19
idx_ok_write:
    sts  head_idx, r19
    ldi  ZL, low(snake_body)
    ldi  ZH, high(snake_body)
    add  ZL, r19
    brcc write_ptr
    inc  ZH
write_ptr:
    st   Z, r20
    ret

hit_wall:
    rcall lcd_clear
    PRINTF LCD
    .db "GAME OVER",0
freeze_game:
    mov  r18, sel
    _CPI r18, ST_GAME1
    breq freeze_game
    ret

;=====================================================================
;  APPLE PLACEMENT - Generate random position for new apple
;=====================================================================
; Places a new apple at a random position that doesn't overlap with 
; the snake. Uses a pseudo-random number generator with a fixed 
; number of placement attempts for consistent timing.
;---------------------------------------------------------------------
place_new_apple:
    push r26
    push r25
    push r24
    push r23
    push r22
    push r21
    push r20
    push r19
    push r18

    clr   r18                ; first free candidate marker
    ldi   r23, APPLE_PLACEMENT_TRIES

loop_iter:
    ; PRNG candidate
    in    r24, TCNT0
    in    r26, ADCL
    eor   r24, r26
    lds   r19, head_idx
    add   r24, r19

    mov   r25, r24
    andi  r24, COORD_MASK
    lsr   r25
    lsr   r25
    lsr   r25
    andi  r25, COORD_MASK

    mov   r20, r25
    lsl   r20
    lsl   r20
    lsl   r20
    add   r20, r24

    ; compare against all snake segments
    lds   r22, tail_idx
    lds   r24, snake_len
    clr   r21               ; i = 0
scan_loop:
    cp    r21, r24
    breq  free_found
    mov   _w, r22
    add   _w, r21
    cpi   _w, GRID_CELLS
    brlo  idx_ok
    subi  _w, GRID_CELLS
idx_ok:
    ldi   ZL, low(snake_body)
    ldi   ZH, high(snake_body)
    add   ZL, _w
    brcc  buf_ptr
    inc   ZH
buf_ptr:
    ld    _w, Z
    cp    _w, r20
    breq  clash_found
    inc   r21
    rjmp  scan_loop

clash_found:
    ; segment clash → skip storing
    rjmp  loop_continue

free_found:
    tst   r18
    brne  loop_continue
    mov   r18, r20

loop_continue:
    dec   r23
    brne  loop_iter

    ; commit result
    tst   r18
    brne  store_ok
    mov   r18, r20
store_ok:
    sts   apple_pos, r18

    pop   r18
    pop   r19
    pop   r20
    pop   r21
    pop   r22
    pop   r23
    pop   r24
    pop   r25
    pop   r26
    ret

;=====================================================================
;  RENDERING - Draw the snake and apple on the LED matrix
;=====================================================================
; Renders the current game state to the LED matrix:
; - Draws the snake body in green
; - Draws the snake head in blue
; - Draws the apple in red
; - Transmits the frame buffer to the physical LED matrix
;---------------------------------------------------------------------
snake_draw:
    clr a0
    clr a1
    clr a2
    rcall matrix_solid

    lds  r23, tail_idx
    lds  s, snake_len
    ldi  r22, 0
draw_loop:
    cp   r22, s
    breq draw_done
    mov  r24, r23
    add  r24, r22
    cpi  r24, GRID_CELLS
    brlo idx_ok3
    subi r24, GRID_CELLS
idx_ok3:
    ldi  ZL, low(snake_body)
    ldi  ZH, high(snake_body)
    add  ZL, r24
    brcc buf_ok3
    inc  ZH
buf_ok3:
    ld   w, Z
    mov  r24, w
    andi r24, COORD_MASK
    mov  r25, w
    lsr  r25
    lsr  r25
    lsr  r25
    andi r25, COORD_MASK
    rcall ws_idx_xy
    rcall ws_offset_idx
    mov  _w, s
    dec  _w
    cp   r22, _w
    breq head_pix
body_pix:
    ldi  a0, BODY_GREEN
    clr  a1
    clr  a2
    rjmp store_px
head_pix:
    clr  a0
    clr  a1
    ldi  a2, HEAD_BLUE
store_px:
    st   Z+, a0
    st   Z+, a1
    st   Z , a2
    inc  r22
    rjmp draw_loop

draw_done:
    ; apple
    lds  w, apple_pos
    cpi  w, EMPTY_CELL
    breq flush_frame
    mov  r24, w
    andi r24, COORD_MASK
    mov  r25, w
    lsr  r25
    lsr  r25
    lsr  r25
    andi r25, COORD_MASK
    rcall ws_idx_xy
    rcall ws_offset_idx
    clr  a0
    ldi  a1, APPLE_RED
    clr  a2
    st   Z+, a0
    st   Z+, a1
    st   Z , a2

flush_frame:
    ldi  ZL, low(WS_BUF_BASE)
    ldi  ZH, high(WS_BUF_BASE)
    _LDI r0, GRID_CELLS
flush_loop:
    ld   a0, Z+
    ld   a1, Z+
    ld   a2, Z+
    cli
    rcall ws_byte3wr
    sei
    dec  r0
    brne flush_loop
    rcall ws_reset
    ret