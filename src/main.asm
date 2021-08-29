.nolist
    #include ti83plus.inc
    #include mirage.inc
.list

_display_mirror_1 .equ appBackUpScreen
_display_mirror_2 .equ saveSScreen
_ti_lcd_busy_quick .equ $000b

appHeader:
    .org userMem - 2                    ; Everything after the Compiled AsmPrgm (2 bytes) token is loaded at the beginning of user memory.
    .db t2ByteTok, tasmCmp              ; Compiled AsmPrgm token, which defines the binary as an assembly program
    ret                                 ; Prevent the calculator's OS from running the program.
                                        ; The program is actually run by MirageOS which uses a longer header.
    .db 1                               ; Indentifier for a MirageOS program
    .db	%00000000, %00000000            ; 15x15 bitmap which shows up in the directory view
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	%00000000, %00000000
    .db	"TIQuest", 0                    ; Zero terminated description
    jp setup

setup:
    res indicRun, (IY + indicFlags)     ; Disable the run indicator (random scrolling pixels in the top-right)
    set fullScrnDraw, (IY + apiFlg4)    ; Enable full screen

    call clear_display
main_loop:
    ld hl, test_graphic
    ld (graphic_addr), hl
    ld a, 6
    ld (graphic_x), a
    ld a, 10
    ld (graphic_y), a
    ld a, 1
    ld (graphic_w), a
    ld a, 8
    ld (graphic_h), a
    call blit_graphic

    call wait_for_next_frame
    ld hl, _display_mirror_1
    call copy_buffer_to_screen

    call wait_for_next_frame
    ld hl, _display_mirror_2
    call copy_buffer_to_screen

    bcall(_GetCSC)
    cp skEnter
    jr Z, exit
    jr main_loop
exit:
    ret


; Halts execution (enters low-power state) until the next frame should be drawn.
wait_for_next_frame:
    res indicOnly, (IY + indicFlags)    ; Make sure interrupts are enabled and key presses are recorded
    ei                                  ; The OS has some timer running which periodically generates an interrupt.
    halt                                ; Enter low-power state
    ret


#include renderer.asm

; -------------------------------------------------
;                    Variables
; -------------------------------------------------

temp_b1:
    .db 0
temp_b2:
    .db 0
temp_b3:
    .db 0
temp_b4:
    .db 0
temp_w1:
    .dw 0
temp_w2:
    .dw 0
temp_w3:
    .dw 0
temp_w4:
    .dw 0

; -------------------------------------------------
;                     Graphics
; -------------------------------------------------

test_graphic:
    .db %01100000 ;0
    .db %01100110 ;1
    .db %01100000 ;0
    .db %01100110 ;1
    .db %11110000 ;0
    .db %11111111 ;1
    .db %11110110 ;0
    .db %10011001 ;1
    .db %11110110 ;0
    .db %10011001 ;1
    .db %11110000 ;0
    .db %11111111 ;1
    .db %01100000 ;0
    .db %01100110 ;1
    .db %01100000 ;0
    .db %01100110 ;1

#include res/player.inc
