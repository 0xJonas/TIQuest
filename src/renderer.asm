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
;   When drawn using blit_graphic, sprites have a maximum width of 7 bytes (56 pixels).
;
; Provided labels:
;   clear_display
;   copy_buffer_to_screen
;   blit_graphic


_display_mirror_1 .equ appBackUpScreen
_display_mirror_2 .equ saveSScreen
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
    ld hl, _display_mirror_1
    ld bc, 64 * 12 + 256 + 1            ; The screen is 64 * 12 bytes. However, because we branch when the registers are !0, we need to add 1 to b and c
_:  ld (hl), 0
    inc hl
    dec c
    jp NZ, -_
    dec b
    jp NZ, -_

    ld hl, _display_mirror_2
    ld bc, 64 * 12 + 256 + 1
_:  ld (hl), 0
    inc hl
    dec c
    jp NZ, -_
    dec b
    jp NZ, -_

    ret


; Copies display buffer contents to the lcd driver.
; 
; This function copies the display buffer contents to the lcd driver in columns. It starts with the
; rightmost column and continues to the left. This is done to minimize calls to _lcd_busy_quick
; because fewer addresses have to be written to the driver.
;
;            <--c
; b +------------+
; | |        <--||
; v |           ||
;   |           v|
;   +------------+
;
; Parameters:
;   hl = address of the screen buffer
copy_buffer_to_screen:
    ld d, $20 + 11                      ; D: lcd driver command to set the column (20h == first 8-pixel column)
    ld c, 12                            ; C: number of columns
    di                                  ; Disable interrupts

    ld a, $05                           ; Set the display driver to automatically increment the x (which is actually the row index) address after each write
    call _lcd_busy_quick                ; Delay before writing to the lcd driver (required by the hardware)
    out (lcdinstport), a

    ld a, 11                            ; set the starting column address (hl += 11)
    add a, l
    ld l, a
    jr NC, +_
    inc h
_:  ld (_current_column_addr), hl
_loop_row:
    ld a, d                             ; Set the target address of the lcd driver
    call _lcd_busy_quick
    out (lcdinstport), a

    ld b, 64
_loop_column:
    ld a, (hl)
    call _lcd_busy_quick
    out (lcddataport), a                ; Output byte to the lcd Driver.
    ld a, l                             ; increment hl by 12
    add a, 12
    ld l, a
    ld a, h
    adc a, 0
    ld h, a
    djnz _loop_column                   ; Repeat until one column (64 bytes) has been written

    dec d                               ; Select the next column

_current_column_addr .equ $ + 1
    ld hl, 0                            ; decrement the column address
    dec hl
    ld (_current_column_addr), hl
    dec c 
    jp NZ, _loop_row                    ; Current column is copied, continue with next column

    ei                                  ; Re-enable interrupts
    ret


; Shifts a block of memory by some number of bits (<8)
;
; Parameters:
;   hl = address
;   b = shift amount
;   c = memory length
bitshift_memory:
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
#define next_row_diff temp_b2

; Part 1: Setup target addresses into the display buffer
graphic_y .equ $ + 1                    ; hl = 12 * graphic_y
    ld l, 0
    ld h, 0
    sla l
    sla l
    ld c, l
    ld b, h
    sla l
    rl h
    add hl, bc

graphic_x .equ $ + 1                    ; hl += graphic_x
    ld a, 0
    sra a
    sra a
    sra a
    add a, l
    ld l, a
    jr NC, +_
    inc h
_:  ex de, hl

    ld hl, _display_mirror_1            ; Create display offset for buffer 1
    add hl, de
    ld (display_offset_1), hl

    ld hl, _display_mirror_2            ; Create display offset for buffer 2
    add hl, de
    ld (display_offset_2), hl

    ld hl, graphic_w                    ; Calculate value to update the display offsets by when moving to the next row
    ld a, 11                            ; 12 - (graphic_w + 1)
    sub (hl)
    ld (next_row_diff), a

; Part 2: Mask display memory using the graphic's stencil
    ld a, (graphic_h)                   ; Store graphic height into a temporary because we will overwrite it, but also need 
    ld (graphic_h_temp), a                     ; the original value later

_blit_row:
    ld hl, (graphic_addr)

    ld a, (graphic_x)                   ; Load shift amount into b (graphic_x & 0b111)
    and %00000111
    ld b, a

    ld a, (graphic_w)                   ; load graphic width into c
    ld c, a
    call _copy_to_scratch_mem_and_shift

; Negate and AND with display buffer contents
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
    or c                                ; OR with second bitplane
    ld (hl), a                          ; Write result back into the display buffer
    inc hl                              ; Increment offset
    ld (display_offset_1), hl

    ; Second display buffer
    ld hl, (display_offset_2)

    ld a, (de)
    or c
    cpl

    and (hl)                            ; Apply mask to current content of the display buffer
    ld (hl), a
    ld a, (de)                          ; OR the display buffer with the AND of the two bitplanes
    and c
    or (hl)
    ld (hl), a

    inc hl
    ld (display_offset_2), hl

    inc ix
    inc de
    djnz _blit_byte

    ld hl, (graphic_addr)               ; Setup address for the next iteration (graphic_addr += 2 * graphic_w)
    ld a, (graphic_w)
    sla a
    add a, l
    ld l, a
    JR NC, +_
    inc hl
_:  ld (graphic_addr), hl

    ld a, (next_row_diff)               ; Load offset to the start of the next row
    ld b, 0
    ld c, a

    ld hl, (display_offset_1)           ; Update display_offset_1 to the next row 
    add hl, bc
    ld (display_offset_1), hl

    ld hl, (display_offset_2)           ; Update display_offset_1 to the next row 
    add hl, bc
    ld (display_offset_2), hl

    ld a, (graphic_h_temp)              ; Decrement loop counter
    dec a
    ld (graphic_h_temp), a
    jr NZ, _blit_row

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

_graphics_scratch_mem_b0:
    .fill 8
_graphics_scratch_mem_b1:
    .fill 8
