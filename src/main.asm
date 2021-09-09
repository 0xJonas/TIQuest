.nolist
    #include ti83plus.inc
    #include mirage.inc
.list

; Miscelleaneous addresses in the tempSwapArea RAM
arrow_keys    .equ tempSwapArea         ; (1 byte) Currently pressed arrow keys
function_keys .equ tempSwapArea + 1     ; (1 byte) Currently pressed function keys
action_keys   .equ tempSwapArea + 2     ; (1 byte) Currently pressed action keys (2nd, MODE, ALPHA)
_graphics_scratch_mem_b0 .equ tempSwapArea + 3  ; (13 bytes) Scratch memory used by the renderer
_graphics_scratch_mem_b1 .equ tempSwapArea + 16 ; (13 bytes) Scratch memory used by the renderer
temp_b1       .equ tempSwapArea + 26    ; (1 byte) temporary
temp_b2       .equ tempSwapArea + 27    ; (1 byte) temporary
temp_b3       .equ tempSwapArea + 28    ; (1 byte) temporary
temp_b4       .equ tempSwapArea + 29    ; (1 byte) temporary
temp_w1       .equ tempSwapArea + 30    ; (2 bytes) temporary
temp_w2       .equ tempSwapArea + 32    ; (2 bytes) temporary
temp_w3       .equ tempSwapArea + 34    ; (2 bytes) temporary
temp_w4       .equ tempSwapArea + 36    ; (2 bytes) temporary


; Bits to detect the corresponding key presses
key_down .equ 0
key_left .equ 1
key_right .equ 2
key_up .equ 3

key_f1 .equ 4
key_f2 .equ 3
key_f3 .equ 2
key_f4 .equ 1
key_f5 .equ 0

key_2nd .equ 5
key_mode .equ 6
key_alpha .equ 7


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

    call setup_interrupts
    call clear_display
main_loop:
    ; ld hl, player_walk_front_1
    ld hl, test_graphic
    ld (graphic_addr), hl
    ld a, 6
    ld (graphic_x), a
    ld a, 10
    ld (graphic_y), a
    ld a, 1
    ld (graphic_w), a
    ; ld a, 12
    ld a, 8
    ld (graphic_h), a
    call blit_graphic

    call wait_for_next_frame
    call advance_dither_mask
    call dither_and_copy_to_screen

    call wait_for_next_frame
    call advance_dither_mask
    call dither_and_copy_to_screen

    ld a, (action_keys)
    bit key_mode, a
    jr NZ, exit
    jr main_loop
exit:
    ret


; Halts execution (enters low-power state) until the next frame should be drawn.
wait_for_next_frame:
    ei                                  ; The OS has some timer running which periodically generates an interrupt.
_enter_halt:
    halt                                ; Enter low-power state

    bit onInterrupt, (IY + onFlags)     ; Check if we woke up because the ON key was pressed
    jr Z, _start_next_frame
    res onInterrupt, (IY + onFlags)     ; Reset ON key interrupt flag
    jr _enter_halt
_start_next_frame:
    ret


_activate_keygroup_delay:
    push af
    pop af
    ret


scan_keyboard:
    ld a, $ff                           ; Reset keyboard for good luck
    out (1), a

    ld a, %11111110                     ; scan arrow keys.
    out (1), a
    call _activate_keygroup_delay
    in a, (1)
    cpl
    ld (arrow_keys), a

    ld a, %10111111                     ; scan function keys.
    out (1), a
    call _activate_keygroup_delay
    in a, (1)
    cpl
    ld b, a
    and %00011111                       ; Mask out function keys
    ld (function_keys), a
    ld a, b
    and %01100000                       ; Mask out 2nd and MODE
    ld b, a

    ld a, %11011111                     ; scan action keys.
    out (1), a
    call _activate_keygroup_delay
    in a, (1)
    cpl
    and %10000000                       ; Mask out ALPHA key
    or b                                ; OR with action keys from the other keygroup
    ld (action_keys), a

    ret


setup_interrupts:
    ld hl, scan_keyboard                ; Add custom isr
    ld (custintaddr), hl
    ld a, %00101001
    call setupint
    ret


#include renderer.asm

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

#include res/sprites/player.inc
