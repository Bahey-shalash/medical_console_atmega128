;======================================================================
;  WS2812B RGB LED MATRIX HELPER FUNCTIONS
;======================================================================
;  Target: ATmega128L @ 4MHz
;
;  Description:
;  This file provides higher-level helper functions for working with
;  the WS2812B 8×8 RGB LED matrix. It implements common operations like
;  filling the entire matrix with a single color, leveraging the lower-level
;  driver functions from ws2812_driver.asm.
;
;  Dependencies:
;  - ws2812_driver.asm must be included before this file
;  - Requires the WS_BUF_BASE memory area defined in ws2812_driver.asm
;  - Uses WAIT_US macro from macros.asm
;
;  Functions:
;  - matrix_solid: Fill entire 8×8 matrix with a single RGB color
;
;  Register Usage:
;  - Input: a0=Green, a1=Red, a2=Blue (GRB order to match WS2812B protocol)
;  - Preserves: r22, ZL, ZH
;  - Clobbers: Z, r0, w=r16 (all scratch registers per calling convention)
;
;  Last Modified: May 25, 2025
;======================================================================
matrix_solid:
        push    r22
        push    ZL
        push    ZH

        ;---------------------------------------------------------------------
        ;  BUFFER PREPARATION - Fill frame buffer with specified color
        ;---------------------------------------------------------------------
        ldi     ZL, low(WS_BUF_BASE)
        ldi     ZH, high(WS_BUF_BASE)
        ldi     r22, 64                    ; 64 pixels (8×8 matrix)
m_fill_loop:
        st      Z+, a0                     ; Store Green component
        st      Z+, a1                     ; Store Red component
        st      Z+, a2                     ; Store Blue component
        dec     r22                        ; Decrement pixel counter
        brne    m_fill_loop                ; Continue until all pixels filled

        ;---------------------------------------------------------------------
        ;  DATA TRANSMISSION - Send buffer contents to LED matrix
        ;---------------------------------------------------------------------
        ldi     ZL, low(WS_BUF_BASE)       ; Reset Z pointer to buffer start
        ldi     ZH, high(WS_BUF_BASE)
        _LDI    r0, 64                     ; 64 pixels to transmit
m_send_loop:
        ld      a0, Z+                     ; Load Green component
        ld      a1, Z+                     ; Load Red component
        ld      a2, Z+                     ; Load Blue component
        cli                                ; Disable interrupts for precise timing
        rcall   ws_byte3wr                 ; Transmit one RGB pixel
        sei                                ; Re-enable interrupts
        dec     r0                         ; Decrement pixel counter
        brne    m_send_loop                ; Continue until all pixels sent
        rcall   ws_reset                   ; Send reset pulse to latch data

        ;---------------------------------------------------------------------
        ;  CLEANUP - Restore preserved registers and return
        ;---------------------------------------------------------------------
        pop     ZH                         ; Restore Z pointer
        pop     ZL
        pop     r22                        ; Restore counter register
        ret                                ; Return to caller