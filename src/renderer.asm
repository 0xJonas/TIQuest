;--------------------------------------------------------
;                        Renderer
;--------------------------------------------------------
; 
; The renderer displays stuff on the screen.
;
; Sprite data uses the following format:
;   Sprites are saved in rows. Each row consists of two bitplanes. The bits of each bitplane
;   determine the color of the pixel:
;   
;   plane 1| plane 0 | color
;         0| 0       | transparent
;         0| 1       | white (off)
;         1| 0       | gray (flickering)
;         1| 1       | black (on)
;
;   When drawn using blit_graphic, sprites have a maximum width of 12 bytes (96 pixels).
;
; The gray color is created using dithering: For this, each draw call (e.g. blit_graphic)
; renderes into two buffers (_dither_buffer_1 and _dither_buffer_2). These buffers take turns in
; being drawn to the screen. The buffers are drawn at a rate of ~100Hz (~120Hz for TI-83+).
; When drawing a byte containing gray, the corresponding bits are ANDed
; with a dither mask. This mask is updated using the following sequence:
;
;   _dither_buffer_1 | _dither_buffer_2
;            00100100 | 01001001
;            10010010 | 00100100
;            01001001 | 10010010
;            00100100 | 01001001
;            10010010 | 00100100
;                    ...
;
; It would probably be more intuitive to use a checkerboard pattern for dithering. However, due
; to some quirks with timers/lcd, this does not create an even gray color, but instead a flickering
; checkerboard pattern with some bits of gray in it.
;
; Provided labels:
;   clear_display
;   advance_dither_mask
;   blit_graphic


display_buffer_1 .equ plotSScreen
display_buffer_2 .equ appBackUpScreen
_ti_lcd_busy_quick .equ $000b


; Delays execution until the display driver is ready to accept data
; Must be called before writing anything to the display driver
_lcd_busy_quick:
    push af
    call _ti_lcd_busy_quick
    pop af
    ret


; Clears the display buffers by filling them with 0s.
clear_display:
    ld hl, display_buffer_1
    ld bc, 64 * 12 + 256 + 1            ; The screen is 64 * 12 bytes. However, because we branch when the registers are !0, we need to add 1 to b and c
_:  ld (hl), 0
    inc hl
    dec c
    jp NZ, -_
    dec b
    jp NZ, -_

    ld hl, display_buffer_2
    ld bc, 64 * 12 + 256 + 1
_:  ld (hl), 0
    inc hl
    dec c
    jp NZ, -_
    dec b
    jp NZ, -_

    ret


; Advances the dithering masks used by dither_and_copy_to_screen.
advance_dither_mask:
    ld a, (_local_dither_mask_0)
    ld b, a
    and %00000011
    jr NZ, +_
    scf
_:  rr b
    ld a, b
    ld (_local_dither_mask_0), a
    ld (_local_dither_mask_3), a

    ld a, (_local_dither_mask_1)
    ld b, a
    and %00000011
    jr NZ, +_
    scf
_:  rr b
    ld a, b
    ld (_local_dither_mask_1), a

    ld a, (_local_dither_mask_2)
    ld b, a
    and %00000011
    jr NZ, +_
    scf
_:  rr b
    ld a, b
    ld (_local_dither_mask_2), a
    ret


; Dithers the current contents of the display buffers and sends them to
; the LCD.
dither_and_copy_to_screen:
    di                                  ; disable interrupts

    ld a, $80                           ; Reset vertical address
    call _lcd_busy_quick
    out (lcdinstport), a

    ld a, $20
    ld (_lcd_column_selector), a        ; Setup command to set the lcd driver's column

    ld c, 11                            ; C: column index
    di                                  ; Disable interrupts

    ld a, $05                           ; Set the display driver to automatically increment the x (which is actually the row index) address after each write
    call _lcd_busy_quick                ; Delay before writing to the lcd driver (required by the hardware)
    out (lcdinstport), a

    ld hl, display_buffer_1
    exx
    ld hl, display_buffer_2
    exx

_loop_row:
_lcd_column_selector .equ $ + 1
    ld a, 0                             ; Set the target address of the lcd driver
    call _lcd_busy_quick
    out (lcdinstport), a

    ld b, 64 / 3                        ; Unroll by a factor of 3

_loop_column:
    ; 1st copy
    ld a, (hl)                          ; Load value from display buffer 1
    inc hl                              ; Increment pointer
    ld d, a
    cpl
_local_dither_mask_0 .equ $ + 1
    and %01001001
    or d
    exx
    and (hl)                            ; AND with value from display buffer 2
    inc hl
    exx

    out (lcddataport), a                ; Output byte to the lcd Driver.

    ; 2nd copy
    ld a, (hl)                          ; Load value from display buffer 1
    inc hl                              ; Increment pointer
    ld d, a
    cpl
_local_dither_mask_1 .equ $ + 1
    and %00100100
    or d
    exx
    and (hl)                            ; AND with value from display buffer 2
    inc hl
    exx

    out (lcddataport), a                ; Output byte to the lcd Driver.

    ; 3rd copy
    ld a, (hl)                          ; Load value from display buffer 1
    inc hl                              ; Increment pointer
    ld d, a
    cpl
_local_dither_mask_2 .equ $ + 1
    and %10010010
    or d
    exx
    and (hl)                            ; AND with value from display buffer 2
    inc hl
    exx

    out (lcddataport), a                ; Output byte to the lcd Driver.

    djnz _loop_column                   ; Repeat until one column (64 bytes) has been written

    ; 4th copy (strip)
    ld a, (hl)                          ; Load value from display buffer 1
    inc hl                              ; Increment pointer
    ld d, a
    cpl
_local_dither_mask_3 .equ $ + 1
    and %01001001
    or d
    exx
    and (hl)                            ; AND with value from display buffer 2
    inc hl
    exx

    out (lcddataport), a                ; Output byte to the lcd Driver.

    ld a, (_lcd_column_selector)        ; Select the next column
    inc a
    ld (_lcd_column_selector), a

    dec c 
    jp P, _loop_row                    ; Current column is copied, continue with next column

    ei                                  ; Re-enable interrupts
    ret


; Shifts a block of memory by some number of bits (<8)
;
; Parameters:
;   hl = address
;   b = shift amount
;   c = memory length
bitshift_memory:
    ld a, b                             ; Exit early if shift amount is zero.
    or b
    jp Z, _bitshift_memory_exit

    ld a, c
    ld d, h
    ld e, l
_bitshift_mem_outer
    ld c, a
    ld h, d
    ld l, e
    scf                                 ; Clear carry flag so 0 is shifted in from the left
    ccf
_:  rr (hl)                             ; Rotate memory to the right in place
    inc hl
    dec c
    jr NZ, -_
    djnz _bitshift_mem_outer
_bitshift_memory_exit:
    ret


; Copies a row of bytes from an arbitrary address into the graphics scratch memory
; and shifts the memory by a given amount.
; 
; This is used as a subroutine for blit_graphic.
;
; Parameters:
;   hl = source address
;   b = shift amount
;   c = source length
_copy_to_scratch_mem_and_shift:
    push bc
    push bc
    push bc

    ; Write first bit plane to scratch mem
    ld b, 0
    ld de, _graphics_scratch_mem_b0     ; Set destination to scratch memory b0
    ldir                                ; Copy data
    ld a, 0                             ; Write one more zero to scratch memory, to accomodate for the shift
    ld (de), a

    ; Write second bit plane to scratch mem
    pop bc
    ld b, 0
    ld de, _graphics_scratch_mem_b1     ; Set destination to scratch memory b1
    ldir                                ; Copy data
    ld a, 0                             ; Write one more zero to scratch memory, to accomodate for the shift
    ld (de), a

    ; shift first bitplane
    pop bc                              ; b = shift amount, c = source length
    inc c
    ld hl, _graphics_scratch_mem_b0
    call bitshift_memory

    ; shift second bitplane
    pop bc
    inc c
    ld hl, _graphics_scratch_mem_b1
    call bitshift_memory

    ret


; Draws a sprite to the display buffers using blitting.
; 
; The following addresses must be populated before each call to blit_graphic:
;   (graphic_x) x position of the sprite
;   (graphic_y) y position of the sprite
;   (graphic_w) width of the sprite in bytes
;   (graphic_h) height of the sprite in bytes
;   (graphic_addr) address of the sprite's graphic data
blit_graphic:

#define display_offset_1 temp_w1
#define display_offset_2 temp_w2
#define graphic_h_temp temp_b1
#define next_row_diff temp_w3

; Part 1: Setup target addresses into the display buffer
graphic_x .equ $ + 1                    ; hl = (graphic_x // 8) * 64
    ld a, 0
    and %11111000
    ld l, a
    ld h, 0
    sla l
    rl h
    sla l
    rl h
    sla l
    rl h

    ld a, l
graphic_y .equ $ + 1                    ; hl += graphic_y
    add a, 0
    ld l, a
    ld a, h
    adc a, 0
    ld h, a
    ex de, hl

    ld hl, display_buffer_1             ; Create display offset for buffer 1
    add hl, de
    ld (display_offset_1), hl

    ld hl, display_buffer_2             ; Create display offset for buffer 2
    add hl, de
    ld (display_offset_2), hl

    ld a, (graphic_w)                   ; Calculate value to update the display offsets by when moving to the next row
    neg
    dec a                               ; 1 - 64 * (graphic_w + 1)
    ld h, a
    ld l, 0
    sra h
    rr l
    sra h
    rr l
    inc hl
    ld (next_row_diff), hl

; Part 2: Actual blitting
    ld a, (graphic_h)                   ; Store graphic height into a temporary because we will overwrite it, but also need 
    ld (graphic_h_temp), a              ; the original value later

_blit_row:
    ld hl, (graphic_addr)

    ld a, (graphic_x)                   ; Load shift amount into b (graphic_x & 0b111)
    and %00000111
    ld b, a

    ld a, (graphic_w)                   ; load graphic width into c
    ld c, a
    call _copy_to_scratch_mem_and_shift

    ld a, (graphic_w)                   ; b = length of data in scratch buffers
    ld b, a
    inc b

    ld de, _graphics_scratch_mem_b0
    ld ix, _graphics_scratch_mem_b1
_blit_byte:
    ld c, (ix + 0)                      ; Save content of second bitplane

    ; First display buffer
    ld hl, (display_offset_1)

    ld a, (de)                          ; Create mask by OR-ing the two bitplanes and negating
    or c
    cpl
    and (hl)                            ; Apply mask to current content of the display buffer    
    ld (hl), a

    ld a, (de)                          ; OR masked value with the first bitplane
    or (hl)
    ld (hl), a                          ; Write ORed value back to the display buffer

    ld a, 64                            ; Increment offset
    add a, l
    ld (display_offset_1), a
    ld a, 0
    adc a, h
    ld (display_offset_1 + 1), a

    ; Second display buffer
    ld hl, (display_offset_2)

    ld a, (de)                          ; Create mask by OR-ing the two bitplanes and negating
    or c
    cpl
    and (hl)                            ; Apply mask to current content of the display buffer
    ld (hl), a

    ld a, c                             ; OR masked value with the first bitplane
    or (hl)
    ld (hl), a                          ; Write ORed value back to the display buffer

    ld a, 64                            ; Increment offset
    add a, l
    ld (display_offset_2), a
    ld a, 0
    adc a, h
    ld (display_offset_2 + 1), a

    inc ix
    inc de
    djnz _blit_byte

    ld hl, (graphic_addr)               ; Setup address for the next row (graphic_addr += 2 * graphic_w)
    ld a, (graphic_w)
    sla a
    add a, l
    ld l, a
    JR NC, +_
    inc hl
_:  ld (graphic_addr), hl

    ld hl, (next_row_diff)              ; Load display buffer offset to the start of the next row
    ex de, hl

    ld hl, (display_offset_1)           ; Update display_offset_1 by adding the offset to the next row
    add hl, de
    ld (display_offset_1), hl

    ld hl, (display_offset_2)           ; Update display_offset_2 by adding the offset to the next row
    add hl, de
    ld (display_offset_2), hl

    ld a, (graphic_h_temp)              ; Decrement loop counter
    dec a
    ld (graphic_h_temp), a
    jp NZ, _blit_row

    ret

#undefine display_offset_1
#undefine display_offset_2
#undefine graphic_h_temp


graphic_w:
    .db 0
graphic_h:
    .db 0
graphic_addr:
    .dw 0
