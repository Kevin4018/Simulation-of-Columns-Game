# This file contains our implementation of Columns.
#
# Kaiwen Yang & Yifei Yang
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.data
##############################################################################
# Immutable Data
##############################################################################
ADDR_DSPL: #base address of the bitmap display
    .word 0x10008000

ADDR_KBRD: #base address of the keyboard input device
    .word 0xffff0000

colour0: .word 0x00ff0000    # red
colour1: .word 0x0000ff00    # green
colour2: .word 0x000000ff    # blue
colour3: .word 0x00ffff00    # yellow
colour4: .word 0x00ff00ff    # magenta
colour5: .word 0x0000ffff    # cyan
board: .space 640   # 16 rows × 10 cols × 4 bytes
mark: .space 640

fall_counter: .word 0
fall_limit: .word 5
difficulty:         .word 0
ghost_colour:       .word 0x00666666      # grey outline / shadow
special_colour:     .word 0x00ff8800    # white special block

special_col_flag:   .word -1              # column to clear, -1 means none
##############################################################################
# Mutable Data
##############################################################################
col_x:          .word 4    #the starting position of the gem
col_y:          .word 0

gem0:           .word 0x00ff0000    #color of gems
gem1:           .word 0x0000ff00
gem2:           .word 0x000000ff

next_gem0:       .word 0x00ff0000
next_gem1:       .word 0x0000ff00
next_gem2:       .word 0x000000ff

bg_colour:      .word 0x00000000    
grid_colour:    .word 0x00333333
score_colour:   .word 0x00ffffff
score:          .word 0

# 3x5 bitmap font for digits 0-9, stored row by row
# each byte uses the low 3 bits
digit_bits:
    .byte 7,5,5,5,7      # 0
    .byte 2,6,2,2,7      # 1
    .byte 7,1,7,4,7      # 2
    .byte 7,1,7,1,7      # 3
    .byte 5,5,7,1,1      # 4
    .byte 7,4,7,1,7      # 5
    .byte 7,4,7,5,7      # 6
    .byte 7,1,1,1,1      # 7
    .byte 7,5,7,5,7      # 8
    .byte 7,5,7,1,7      # 9

##############################################################################
# Code
##############################################################################
.text
.globl main

main:
    jal select_difficulty
    jal clear_board
    jal clear_marks
    sw   $zero, score
    jal initial_gems
    jal clear_screen

game_loop:
    jal handle_input
    jal auto_fall
    jal clear_screen
    jal draw_grid
    jal draw_board
    jal draw_drop_preview
    jal draw_screen
    jal draw_next_preview
    jal draw_score
    jal sleep
    j game_loop
select_difficulty:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

select_loop:
    jal  clear_screen
    jal  draw_difficulty_screen

    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, $zero, select_loop

    lw   $t2, 4($t0)

    li   $t3, 49              # '1'
    beq  $t2, $t3, select_easy

    li   $t3, 50              # '2'
    beq  $t2, $t3, select_medium

    li   $t3, 51              # '3'
    beq  $t2, $t3, select_hard

    j    select_loop

select_easy:
    li   $t4, 1
    sw   $t4, difficulty
    li   $t4, 8
    sw   $t4, fall_limit
    j    select_done

select_medium:
    li   $t4, 2
    sw   $t4, difficulty
    li   $t4, 5
    sw   $t4, fall_limit
    j    select_done


select_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Draw where the current falling column would land
##############################################################################
draw_drop_preview:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    lw   $t0, col_x
    lw   $t1, col_y          # temp_y

preview_fall_loop:
    li   $t2, 13
    beq  $t1, $t2, preview_found

    addi $t3, $t1, 3         # row below bottom gem
    li   $t4, 10
    mult $t3, $t4
    mflo $t5
    add  $t5, $t5, $t0
    sll  $t5, $t5, 2

    la   $t6, board
    add  $t6, $t6, $t5
    lw   $t7, 0($t6)

    bne  $t7, $zero, preview_found

    addi $t1, $t1, 1
    j    preview_fall_loop

preview_found:
    # If landing position is same as current position, still draw it.
    move $a0, $t0
    move $a1, $t1
    jal  draw_preview_column

    lw   $ra, 4($sp)
    lw   $s0, 0($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
# Draw 3 ghost cells at board position (a0 = col_x, a1 = top row)
##############################################################################
draw_preview_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # draw top
    move $t0, $a0
    move $t1, $a1
    jal  draw_preview_one

    # middle
    move $t0, $a0
    addi $t1, $a1, 1
    jal  draw_preview_one

    # bottom
    move $t0, $a0
    addi $t1, $a1, 2
    jal  draw_preview_one

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Draw one preview cell
# t0 = board x, t1 = board y
##############################################################################
draw_preview_one:
    lw   $t2, ADDR_DSPL
    lw   $t3, ghost_colour

    addi $t4, $t0, 7         # screen x
    addi $t5, $t1, 4         # screen y

    li   $t6, 32
    mult $t5, $t6
    mflo $t7
    add  $t7, $t7, $t4
    sll  $t7, $t7, 2
    add  $t7, $t7, $t2

    sw   $t3, 0($t7)
    jr   $ra
    
    ##############################################################################
# Clear an entire column if special_col_flag != -1
##############################################################################
clear_special_column:
    lw   $t0, special_col_flag
    li   $t1, -1
    beq  $t0, $t1, clear_special_done

    li   $t2, 0              # row = 0

clear_special_loop:
    li   $t3, 10
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t0
    sll  $t4, $t4, 2

    la   $t5, board
    add  $t5, $t5, $t4
    sw   $zero, 0($t5)

    addi $t2, $t2, 1
    li   $t6, 16
    bne  $t2, $t6, clear_special_loop

    li   $t7, -1
    sw   $t7, special_col_flag

clear_special_done:
    jr   $ra
    
select_hard:
    li   $t4, 3
    sw   $t4, difficulty
    li   $t4, 3
    sw   $t4, fall_limit
    jr   $ra

##############################################################################
# Minimal difficulty screen: show 1 2 3
##############################################################################
draw_difficulty_screen:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $a0, 1
    li   $a1, 7
    li   $a2, 10
    li   $a3, 2
    jal  draw_digit_scaled

    li   $a0, 2
    li   $a1, 14
    li   $a2, 10
    li   $a3, 2
    jal  draw_digit_scaled

    li   $a0, 3
    li   $a1, 21
    li   $a2, 10
    li   $a3, 2
    jal  draw_digit_scaled

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Columns fall with gravity
##############################################################################
auto_fall:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, fall_counter
    addi $t0, $t0, 1
    sw   $t0, fall_counter

    lw   $t1, fall_limit
    bne  $t0, $t1, auto_fall_done

    sw   $zero, fall_counter
    jal  step_down

auto_fall_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
##############################################################################
# Initialize first 3 gems with random colours
##############################################################################
initial_gems:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # current falling block
    jal  random_colour
    sw   $v0, gem0

    jal  random_colour
    sw   $v0, gem1

    jal  random_colour
    sw   $v0, gem2

    # next preview block
    jal  random_colour
    sw   $v0, next_gem0

    jal  random_colour
    sw   $v0, next_gem1

    jal  random_colour
    sw   $v0, next_gem2

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Return one random colour in
##############################################################################
##############################################################################
# Return one random colour, with a small chance of being a special block
##############################################################################
random_colour:
    # First roll to decide whether this is a special block
    li  $v0, 42
    li  $a0, 0
    li  $a1, 5              # random number in [0, 10)
    syscall

    move $t0, $a0
    beq  $t0, $zero, rc_special   # 1/10 chance

    # Otherwise choose one of the normal 6 colours
    li  $v0, 42
    li  $a0, 0
    li  $a1, 6
    syscall

    move $t0, $a0

    li  $t1, 0
    beq $t0, $t1, rc0
    li  $t1, 1
    beq $t0, $t1, rc1
    li  $t1, 2
    beq $t0, $t1, rc2
    li  $t1, 3
    beq $t0, $t1, rc3
    li  $t1, 4
    beq $t0, $t1, rc4
    j   rc5

rc_special:
    lw  $v0, special_colour
    jr  $ra

rc0:
    lw  $v0, colour0
    jr  $ra
rc1:
    lw  $v0, colour1
    jr  $ra
rc2:
    lw  $v0, colour2
    jr  $ra
rc3:
    lw  $v0, colour3
    jr  $ra
rc4:
    lw  $v0, colour4
    jr  $ra
rc5:
    lw  $v0, colour5
    jr  $ra
    
##############################################################################
# Draw the whole screen
##############################################################################
draw_screen:
    lw $t0, ADDR_DSPL      # display base
    lw $t1, col_x          # board x
    lw $t2, col_y          # board y

    # convert board x to screen x
    addi $t1, $t1, 7      # screen_x = 13 + col_x

    # gem 0: screen_y = 4 + col_y
    addi $t7, $t2, 4
    li   $t3, 32
    mult $t7, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4
    lw   $t6, gem0
    sw   $t6, 0($t5)

    # gem 1: screen_y = 4 + col_y + 1
    addi $t7, $t7, 1
    li   $t3, 32
    mult $t7, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4
    lw   $t6, gem1
    sw   $t6, 0($t5)

    # gem 2: screen_y = 4 + col_y + 2
    addi $t7, $t7, 1
    li   $t3, 32
    mult $t7, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4
    lw   $t6, gem2
    sw   $t6, 0($t5)

    jr $ra

##############################################################################
# Handle keyboard input
##############################################################################
handle_input:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, $zero, handle_done

    lw   $t2, 4($t0)

    li   $t3, 97          # 'a'
    beq  $t2, $t3, move_left

    li   $t3, 100         # 'd'
    beq  $t2, $t3, move_right

    li   $t3, 115           #'s'
    beq  $t2, $t3, step_down

    li   $t3, 119         # 'w'
    beq  $t2, $t3, rotate_gems

    li   $t3, 112         # 'p'
    beq  $t2, $t3, pause_game

    li   $t3, 113         # 'q'
    beq  $t2, $t3, quit_game

handle_done:
    jr   $ra

move_left:
    lw   $t0, col_x
    lw   $t1, col_y

    beq  $t0, $zero, handle_done     # wall

    addi $t3, $t0, -1                # new x
    li   $t4, 0

check_loop_l:
    add  $t5, $t1, $t4               # row

    li   $t6, 10
    mult $t5, $t6
    mflo $t7
    add  $t7, $t7, $t3
    sll  $t7, $t7, 2

    la   $t8, board
    add  $t8, $t8, $t7
    lw   $t9, 0($t8)

    bne  $t9, $zero, handle_done

    addi $t4, $t4, 1
    li   $t6, 3
    bne  $t4, $t6, check_loop_l

    sw   $t3, col_x
    jr   $ra

move_right:
    lw $t0, col_x
    lw $t1, col_y

    li $t2, 9
    beq $t0, $t2, handle_done   # wall

    addi $t3, $t0, 1            # new x

    li $t4, 0

check_loop_r:
    add $t5, $t1, $t4          # row

    li $t6, 10
    mult $t5, $t6
    mflo $t7
    add  $t7, $t7, $t3
    sll  $t7, $t7, 2

    la   $t8, board
    add  $t8, $t8, $t7
    lw   $t9, 0($t8)

    bne  $t9, $zero, handle_done

    addi $t4, $t4, 1
    li   $t6, 3
    bne  $t4, $t6, check_loop_r

    sw $t3, col_x
    jr $ra

step_down:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw $t0, col_x
    lw $t1, col_y

    li $t2, 13
    beq $t1, $t2, landed

    addi $t3, $t1, 3
    li  $t4, 10
    mult $t3, $t4
    mflo $t5
    add  $t5, $t5, $t0
    sll  $t5, $t5, 2

    la   $t6, board
    add  $t6, $t6, $t5
    lw   $t7, 0($t6)

    bne  $t7, $zero, landed

    addi $t1, $t1, 1
    sw   $t1, col_y
    j    step_down_done

landed:
    jal lock_column
    jal resolve_board
    jal check_game_over
    jal spawn_column

step_down_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
rotate_gems:
    lw   $t4, gem0
    lw   $t5, gem1
    lw   $t6, gem2
    sw   $t6, gem0
    sw   $t4, gem1
    sw   $t5, gem2
    jr   $ra

pause_game:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

pause_release_wait:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    bne  $t1, $zero, pause_release_wait

pause_loop:
    jal  clear_screen
    jal  draw_paused_message
    jal  sleep

    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, $zero, pause_loop

    lw   $t2, 4($t0)
    li   $t3, 112         # 'p'
    bne  $t2, $t3, pause_loop

pause_unrelease_wait:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    bne  $t1, $zero, pause_unrelease_wait

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

quit_game:
    jal  show_end_screen
    li   $v0, 10
    syscall

##############################################################################
# End screen: clear display, show GG and final score, then pause briefly
##############################################################################
show_end_screen:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  clear_screen
    jal  draw_gg
    jal  draw_end_score

    li   $v0, 32
    li   $a0, 1500
    syscall

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Draw PAUSED message centered on pause screen
##############################################################################
draw_paused_message:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $a0, 4
    li   $a1, 12
    jal  draw_letter_p

    li   $a0, 8
    li   $a1, 12
    jal  draw_letter_a

    li   $a0, 12
    li   $a1, 12
    jal  draw_letter_u

    li   $a0, 16
    li   $a1, 12
    jal  draw_letter_s

    li   $a0, 20
    li   $a1, 12
    jal  draw_letter_e

    li   $a0, 24
    li   $a1, 12
    jal  draw_letter_d

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# a0 = left x, a1 = top y, letters fit in 3x5 box
draw_letter_p:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)
    move $s0, $a0
    move $s1, $a1

    move $a0, $s0
    move $a1, $s1
    li   $a2, 5
    jal  draw_vline

    move $a0, $s0
    move $a1, $s1
    li   $a2, 3
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 2
    li   $a2, 3
    jal  draw_hline

    addi $a0, $s0, 2
    addi $a1, $s1, 1
    li   $a2, 1
    jal  draw_vline

    lw   $ra, 8($sp)
    lw   $s0, 4($sp)
    lw   $s1, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_a:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)
    move $s0, $a0
    move $s1, $a1

    move $a0, $s0
    move $a1, $s1
    li   $a2, 5
    jal  draw_vline

    addi $a0, $s0, 2
    move $a1, $s1
    li   $a2, 5
    jal  draw_vline

    move $a0, $s0
    move $a1, $s1
    li   $a2, 3
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 2
    li   $a2, 3
    jal  draw_hline

    lw   $ra, 8($sp)
    lw   $s0, 4($sp)
    lw   $s1, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_u:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)
    move $s0, $a0
    move $s1, $a1

    move $a0, $s0
    move $a1, $s1
    li   $a2, 4
    jal  draw_vline

    addi $a0, $s0, 2
    move $a1, $s1
    li   $a2, 4
    jal  draw_vline

    move $a0, $s0
    addi $a1, $s1, 4
    li   $a2, 3
    jal  draw_hline

    lw   $ra, 8($sp)
    lw   $s0, 4($sp)
    lw   $s1, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_s:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)
    move $s0, $a0
    move $s1, $a1

    move $a0, $s0
    move $a1, $s1
    li   $a2, 3
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 2
    li   $a2, 3
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 4
    li   $a2, 3
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 1
    li   $a2, 1
    jal  draw_vline

    addi $a0, $s0, 2
    addi $a1, $s1, 3
    li   $a2, 1
    jal  draw_vline

    lw   $ra, 8($sp)
    lw   $s0, 4($sp)
    lw   $s1, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_e:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)
    move $s0, $a0
    move $s1, $a1

    move $a0, $s0
    move $a1, $s1
    li   $a2, 5
    jal  draw_vline

    move $a0, $s0
    move $a1, $s1
    li   $a2, 3
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 2
    li   $a2, 3
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 4
    li   $a2, 3
    jal  draw_hline

    lw   $ra, 8($sp)
    lw   $s0, 4($sp)
    lw   $s1, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_d:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)
    move $s0, $a0
    move $s1, $a1

    move $a0, $s0
    move $a1, $s1
    li   $a2, 5
    jal  draw_vline

    move $a0, $s0
    move $a1, $s1
    li   $a2, 2
    jal  draw_hline

    move $a0, $s0
    addi $a1, $s1, 4
    li   $a2, 2
    jal  draw_hline

    addi $a0, $s0, 2
    addi $a1, $s1, 1
    li   $a2, 3
    jal  draw_vline

    lw   $ra, 8($sp)
    lw   $s0, 4($sp)
    lw   $s1, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# Draw two large G letters in white
##############################################################################
draw_gg:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # left G at (9, 7)
    li   $a0, 9
    li   $a1, 7
    jal  draw_big_g

    # right G at (18, 7)
    li   $a0, 18
    li   $a1, 7
    jal  draw_big_g

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Draw one block-style G inside a 6x7 box
# a0 = left x, a1 = top y
##############################################################################
draw_big_g:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    move $s0, $a0
    move $s1, $a1

    # top bar
    move $a0, $s0
    move $a1, $s1
    li   $a2, 5
    jal  draw_hline

    # left bar
    move $a0, $s0
    move $a1, $s1
    li   $a2, 6
    jal  draw_vline

    # bottom bar
    move $a0, $s0
    addi $a1, $s1, 6
    li   $a2, 5
    jal  draw_hline

    # right lower bar
    addi $a0, $s0, 4
    addi $a1, $s1, 3
    li   $a2, 3
    jal  draw_vline

    # middle bar of G
    addi $a0, $s0, 2
    addi $a1, $s1, 3
    li   $a2, 3
    jal  draw_hline

    lw   $ra, 8($sp)
    lw   $s0, 4($sp)
    lw   $s1, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# Draw final score centered under GG
##############################################################################
draw_end_score:
    addi $sp, $sp, -28
    sw   $ra, 24($sp)
    sw   $s0, 20($sp)
    sw   $s1, 16($sp)
    sw   $s2, 12($sp)
    sw   $s3, 8($sp)
    sw   $s4, 4($sp)
    sw   $s5, 0($sp)

    lw   $t0, score
    li   $t1, 100
    divu $t0, $t1
    mflo $s0
    mfhi $t2

    li   $t1, 10
    divu $t2, $t1
    mflo $s1
    mfhi $s2

    li   $s3, 10            # hundreds x; centered under GG
    li   $s4, 18            # score y just below GG
    li   $s5, 1             # compact final-score size

    move $a0, $s0
    move $a1, $s3
    move $a2, $s4
    move $a3, $s5
    jal  draw_digit_scaled

    move $a0, $s1
    addi $a1, $s3, 4
    move $a2, $s4
    move $a3, $s5
    jal  draw_digit_scaled

    move $a0, $s2
    addi $a1, $s3, 8
    move $a2, $s4
    move $a3, $s5
    jal  draw_digit_scaled

    lw   $ra, 24($sp)
    lw   $s0, 20($sp)
    lw   $s1, 16($sp)
    lw   $s2, 12($sp)
    lw   $s3, 8($sp)
    lw   $s4, 4($sp)
    lw   $s5, 0($sp)
    addi $sp, $sp, 28
    jr   $ra

##############################################################################
# Draw horizontal line of length a2 at (a0, a1)
##############################################################################
draw_hline:
    addi $sp, $sp, -20
    sw   $ra, 16($sp)
    sw   $s0, 12($sp)
    sw   $s1, 8($sp)
    sw   $s2, 4($sp)
    sw   $s3, 0($sp)

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    li   $s3, 0
hline_loop:
    add  $a0, $s0, $s3
    move $a1, $s1
    jal  draw_pixel_cell
    addi $s3, $s3, 1
    bne  $s3, $s2, hline_loop

    lw   $ra, 16($sp)
    lw   $s0, 12($sp)
    lw   $s1, 8($sp)
    lw   $s2, 4($sp)
    lw   $s3, 0($sp)
    addi $sp, $sp, 20
    jr   $ra

##############################################################################
# Draw vertical line of length a2 at (a0, a1)
##############################################################################
draw_vline:
    addi $sp, $sp, -20
    sw   $ra, 16($sp)
    sw   $s0, 12($sp)
    sw   $s1, 8($sp)
    sw   $s2, 4($sp)
    sw   $s3, 0($sp)

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    li   $s3, 0
vline_loop:
    move $a0, $s0
    add  $a1, $s1, $s3
    jal  draw_pixel_cell
    addi $s3, $s3, 1
    bne  $s3, $s2, vline_loop

    lw   $ra, 16($sp)
    lw   $s0, 12($sp)
    lw   $s1, 8($sp)
    lw   $s2, 4($sp)
    lw   $s3, 0($sp)
    addi $sp, $sp, 20
    jr   $ra

##############################################################################
# Draw one bitmap cell in score_colour at (a0, a1)
##############################################################################
draw_pixel_cell:
    lw   $t0, ADDR_DSPL
    lw   $t1, score_colour
    li   $t2, 32
    mult $a1, $t2
    mflo $t3
    add  $t3, $t3, $a0
    sll  $t3, $t3, 2
    add  $t3, $t3, $t0
    sw   $t1, 0($t3)
    jr   $ra

##############################################################################
# Draw border around 10 x 16 board
##############################################################################
draw_grid:
    lw   $t0, ADDR_DSPL
    lw   $t7, grid_colour

    ##########################################################################
    # Top border: y = 3, x = 6..17
    ##########################################################################
    li   $t1, 6                   # x
draw_top_loop:
    li   $t2, 3                   # y

    li   $t3, 32
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4

    sw   $t7, 0($t5)

    addi $t1, $t1, 1
    li   $t6, 18                  # stop after x=17
    bne  $t1, $t6, draw_top_loop

    ##########################################################################
    # Bottom border: y = 20, x = 6..17
    ##########################################################################
    li   $t1, 6
draw_bottom_loop:
    li   $t2, 20

    li   $t3, 32
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4

    sw   $t7, 0($t5)

    addi $t1, $t1, 1
    li   $t6, 18
    bne  $t1, $t6, draw_bottom_loop

    ##########################################################################
    # Left border: x = 6, y = 3..20
    ##########################################################################
    li   $t2, 3
draw_left_loop:
    li   $t1, 6

    li   $t3, 32
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4

    sw   $t7, 0($t5)

    addi $t2, $t2, 1
    li   $t6, 21                  # stop after y=20
    bne  $t2, $t6, draw_left_loop

    ##########################################################################
    # Right border: x = 17, y = 3..20
    ##########################################################################
    li   $t2, 3
draw_right_loop:
    li   $t1, 17

    li   $t3, 32
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4

    sw   $t7, 0($t5)

    addi $t2, $t2, 1
    li   $t6, 21
    bne  $t2, $t6, draw_right_loop

    jr   $ra

##############################################################################
# Draw all fixed gems from board
##############################################################################
draw_board:
    li  $t0, 0              # row

row_loop:
    li  $t1, 0              # col

col_loop:
    # index = row * 10 + col
    li  $t2, 10
    mult $t0, $t2
    mflo $t3
    add  $t3, $t3, $t1
    sll  $t3, $t3, 2

    la   $t4, board
    add  $t4, $t4, $t3
    lw   $t5, 0($t4)

    beq  $t5, $zero, skip_draw

    # convert to screen coords
    addi $t6, $t1, 7   # x
    addi $t7, $t0, 4    # y

    lw   $t8, ADDR_DSPL
    li   $t9, 32
    mult $t7, $t9
    mflo $s0
    add  $s0, $s0, $t6
    sll  $s0, $s0, 2
    add  $s0, $s0, $t8

    sw   $t5, 0($s0)

skip_draw:
    addi $t1, $t1, 1
    li   $t2, 10
    bne  $t1, $t2, col_loop

    addi $t0, $t0, 1
    li   $t2, 16
    bne  $t0, $t2, row_loop

    jr $ra
    
##############################################################################
# Draw the next falling column preview beside the grid
##############################################################################
draw_next_preview:
    lw   $t0, ADDR_DSPL
    li   $t1, 25              # preview x: centered under the middle score digit
    li   $t2, 12              # preview top y: below the score display

    # next gem 0
    li   $t3, 32
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4
    lw   $t6, next_gem0
    sw   $t6, 0($t5)

    # next gem 1
    addi $t2, $t2, 1
    li   $t3, 32
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4
    lw   $t6, next_gem1
    sw   $t6, 0($t5)

    # next gem 2
    addi $t2, $t2, 1
    li   $t3, 32
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t5, $t0, $t4
    lw   $t6, next_gem2
    sw   $t6, 0($t5)

    jr   $ra

##############################################################################
# Draw current score beside the grid
##############################################################################
draw_score:
    addi $sp, $sp, -28
    sw   $ra, 24($sp)
    sw   $s0, 20($sp)
    sw   $s1, 16($sp)
    sw   $s2, 12($sp)
    sw   $s3, 8($sp)
    sw   $s4, 4($sp)
    sw   $s5, 0($sp)

    lw   $t0, score
    li   $t1, 100
    divu $t0, $t1
    mflo $s0                 # hundreds
    mfhi $t2                 # remainder

    li   $t1, 10
    divu $t2, $t1
    mflo $s1                 # tens
    mfhi $s2                 # ones

    # compact placement so score is smaller and closer to the board
    li   $s3, 20             # left x of hundreds digit
    li   $s4, 6              # top y of score display
    li   $s5, 1              # scale = 1 cell per font pixel

    move $a0, $s0
    move $a1, $s3
    move $a2, $s4
    move $a3, $s5
    jal  draw_digit_scaled

    move $a0, $s1
    addi $a1, $s3, 4         # 3 columns + 1 spacing
    move $a2, $s4
    move $a3, $s5
    jal  draw_digit_scaled

    move $a0, $s2
    addi $a1, $s3, 8
    move $a2, $s4
    move $a3, $s5
    jal  draw_digit_scaled

    lw   $ra, 24($sp)
    lw   $s0, 20($sp)
    lw   $s1, 16($sp)
    lw   $s2, 12($sp)
    lw   $s3, 8($sp)
    lw   $s4, 4($sp)
    lw   $s5, 0($sp)
    addi $sp, $sp, 28
    jr   $ra

##############################################################################
# Draw one digit using the 3x5 font
# a0 = digit (0-9), a1 = left x, a2 = top y, a3 = scale
##############################################################################
draw_digit_scaled:
    addi $sp, $sp, -40
    sw   $ra, 36($sp)
    sw   $s0, 32($sp)
    sw   $s1, 28($sp)
    sw   $s2, 24($sp)
    sw   $s3, 20($sp)
    sw   $s4, 16($sp)
    sw   $s5, 12($sp)
    sw   $s6, 8($sp)
    sw   $s7, 4($sp)
    sw   $t0, 0($sp)

    lw   $s0, ADDR_DSPL
    lw   $s1, score_colour
    move $s2, $a1            # base x
    move $s3, $a2            # base y
    move $s4, $a3            # scale

    la   $t0, digit_bits
    li   $t1, 5
    mult $a0, $t1
    mflo $t2
    add  $s5, $t0, $t2       # pointer to 5 rows for this digit

    li   $s6, 0              # row
score_row_loop:
    lbu  $t4, 0($s5)

    li   $s7, 0              # col
score_col_loop:
    li   $t6, 2
    sub  $t6, $t6, $s7       # bit position: 2,1,0
    li   $t7, 1
    sllv $t7, $t7, $t6
    and  $t8, $t4, $t7
    beq  $t8, $zero, score_skip_block

    # draw one font pixel; scale 1 keeps digits compact
    mul  $t9, $s6, $s4
    add  $t9, $t9, $s3       # start y
    li   $t0, 0              # dy
score_dy_loop:
    mul  $t1, $s7, $s4
    add  $t1, $t1, $s2       # start x
    li   $t2, 0              # dx
score_dx_loop:
    add  $t3, $t9, $t0
    li   $t5, 32
    mult $t3, $t5
    mflo $t6
    add  $t6, $t6, $t1
    add  $t6, $t6, $t2
    sll  $t6, $t6, 2
    add  $t6, $t6, $s0
    sw   $s1, 0($t6)

    addi $t2, $t2, 1
    bne  $t2, $s4, score_dx_loop

    addi $t0, $t0, 1
    bne  $t0, $s4, score_dy_loop

score_skip_block:
    addi $s7, $s7, 1
    li   $t6, 3
    bne  $s7, $t6, score_col_loop

    addi $s5, $s5, 1
    addi $s6, $s6, 1
    li   $t6, 5
    bne  $s6, $t6, score_row_loop

    lw   $ra, 36($sp)
    lw   $s0, 32($sp)
    lw   $s1, 28($sp)
    lw   $s2, 24($sp)
    lw   $s3, 20($sp)
    lw   $s4, 16($sp)
    lw   $s5, 12($sp)
    lw   $s6, 8($sp)
    lw   $s7, 4($sp)
    lw   $t0, 0($sp)
    addi $sp, $sp, 40
    jr   $ra

##############################################################################
# Store current falling column into board
##############################################################################
lock_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw $t0, col_x
    lw $t1, col_y

    move $t2, $t1
    jal store_one

    addi $t2, $t1, 1
    lw   $t3, gem1
    jal store_one_direct

    addi $t2, $t1, 2
    lw   $t3, gem2
    jal store_one_direct

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


store_one:
    lw $t3, gem0

store_one_direct:
    # index = row * 10 + col
    li  $t4, 10
    mult $t2, $t4
    mflo $t5
    add  $t5, $t5, $t0
    sll  $t5, $t5, 2

    la   $t6, board
    add  $t6, $t6, $t5

    sw   $t3, 0($t6)
    jr $ra

##############################################################################
# Generate new falling column at top
##############################################################################
spawn_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $t0, 4
    sw   $t0, col_x

    li   $t0, 0
    sw   $t0, col_y

    # move preview block into the active falling block
    lw   $t1, next_gem0
    sw   $t1, gem0
    lw   $t1, next_gem1
    sw   $t1, gem1
    lw   $t1, next_gem2
    sw   $t1, gem2

    # generate a brand new preview block
    jal  random_colour
    sw   $v0, next_gem0

    jal  random_colour
    sw   $v0, next_gem1

    jal  random_colour
    sw   $v0, next_gem2

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Clear board array to 0
##############################################################################
clear_board:
    la   $t0, board
    li   $t1, 160             # 16*10 cells

clear_board_loop:
    sw   $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bne  $t1, $zero, clear_board_loop
    jr   $ra

##############################################################################
# Clear mark array to 0
##############################################################################
clear_marks:
    la   $t0, mark
    li   $t1, 160             # 16*10 cells

clear_marks_loop:
    sw   $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bne  $t1, $zero, clear_marks_loop
    jr   $ra

##############################################################################
# Find all matches of 3 and mark them in mark[]
##############################################################################
find_matches:
    la   $t8, board
    la   $t9, mark
    
    li   $t0, 0                      # row
fm_h_row:
    li   $t1, 0                      # col
fm_h_col:
    li   $t2, 10
    mult $t0, $t2
    mflo $t3
    add  $t3, $t3, $t1               # index = row*10 + col
    sll  $t4, $t3, 2                 # byte offset

    add  $t5, $t8, $t4               # board addr of (r,c)
    lw   $t6, 0($t5)
    beq  $t6, $zero, fm_h_next

    lw   $t7, 4($t5)                 # (r,c+1)
    bne  $t6, $t7, fm_h_next

    lw   $t2, 8($t5)                 # (r,c+2)
    bne  $t6, $t2, fm_h_next

    add  $t5, $t9, $t4               # mark addr
    li   $t2, 1
    sw   $t2, 0($t5)
    sw   $t2, 4($t5)
    sw   $t2, 8($t5)

fm_h_next:
    addi $t1, $t1, 1
    li   $t2, 8                      # cols 0..7
    bne  $t1, $t2, fm_h_col

    addi $t0, $t0, 1
    li   $t2, 16
    bne  $t0, $t2, fm_h_row

    li   $t0, 0                      # row
fm_v_row:
    li   $t1, 0                      # col
fm_v_col:
    li   $t2, 10
    mult $t0, $t2
    mflo $t3
    add  $t3, $t3, $t1
    sll  $t4, $t3, 2

    add  $t5, $t8, $t4
    lw   $t6, 0($t5)
    beq  $t6, $zero, fm_v_next

    lw   $t7, 40($t5)                # +1 row = +10 cells = +40 bytes
    bne  $t6, $t7, fm_v_next

    lw   $t2, 80($t5)                # +2 rows
    bne  $t6, $t2, fm_v_next

    add  $t5, $t9, $t4
    li   $t2, 1
    sw   $t2, 0($t5)
    sw   $t2, 40($t5)
    sw   $t2, 80($t5)

fm_v_next:
    addi $t1, $t1, 1
    li   $t2, 10                     # cols 0..9
    bne  $t1, $t2, fm_v_col

    addi $t0, $t0, 1
    li   $t2, 14                     # rows 0..13
    bne  $t0, $t2, fm_v_row

    li   $t0, 0
fm_dr_row:
    li   $t1, 0
fm_dr_col:
    li   $t2, 10
    mult $t0, $t2
    mflo $t3
    add  $t3, $t3, $t1
    sll  $t4, $t3, 2

    add  $t5, $t8, $t4
    lw   $t6, 0($t5)
    beq  $t6, $zero, fm_dr_next

    lw   $t7, 44($t5)                # +(10+1) cells = +44 bytes
    bne  $t6, $t7, fm_dr_next

    lw   $t2, 88($t5)                # +(2*10+2) cells
    bne  $t6, $t2, fm_dr_next

    add  $t5, $t9, $t4
    li   $t2, 1
    sw   $t2, 0($t5)
    sw   $t2, 44($t5)
    sw   $t2, 88($t5)

fm_dr_next:
    addi $t1, $t1, 1
    li   $t2, 8                      # col 0-7
    bne  $t1, $t2, fm_dr_col

    addi $t0, $t0, 1
    li   $t2, 14                     # rows 0-13
    bne  $t0, $t2, fm_dr_row

    li   $t0, 0
fm_dl_row:
    li   $t1, 2                      # cols 2-9
fm_dl_col:
    li   $t2, 10
    mult $t0, $t2
    mflo $t3
    add  $t3, $t3, $t1
    sll  $t4, $t3, 2

    add  $t5, $t8, $t4
    lw   $t6, 0($t5)
    beq  $t6, $zero, fm_dl_next

    lw   $t7, 36($t5)                # +(10-1) cells = +36 bytes
    bne  $t6, $t7, fm_dl_next

    lw   $t2, 72($t5)                # +(2*10-2) cells
    bne  $t6, $t2, fm_dl_next

    add  $t5, $t9, $t4
    li   $t2, 1
    sw   $t2, 0($t5)
    sw   $t2, 36($t5)
    sw   $t2, 72($t5)

fm_dl_next:
    addi $t1, $t1, 1
    li   $t2, 10                     # cols 2-9
    bne  $t1, $t2, fm_dl_col

    addi $t0, $t0, 1
    li   $t2, 14
    bne  $t0, $t2, fm_dl_row

    jr   $ra

##############################################################################
# Clear all marked cells in board[]
# If a special block is cleared, clear its whole column too.
##############################################################################
##############################################################################
# Clear all marked cells in board[]
# If a special block is cleared, clear its whole column too.
##############################################################################
clear_marked:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    la   $t0, board
    la   $t1, mark
    li   $t2, 160
    move $v0, $zero

    li   $t9, -1
    sw   $t9, special_col_flag

    li   $t8, 0              # cell index 0..159

clear_marked_loop:
    lw   $t3, 0($t1)
    beq  $t3, $zero, clear_marked_skip

    lw   $t4, 0($t0)         # current board colour

    # check if this is a special block
    lw   $t5, special_colour
    bne  $t4, $t5, not_special_block

    # col = index % 10
    li   $t6, 10
    divu $t8, $t6
    mfhi $t7
    sw   $t7, special_col_flag

not_special_block:
    sw   $zero, 0($t0)
    li   $v0, 1

    lw   $t4, score
    addi $t4, $t4, 1
    li   $t5, 1000
    blt  $t4, $t5, score_store_new
    move $t4, $zero
score_store_new:
    sw   $t4, score

clear_marked_skip:
    addi $t0, $t0, 4
    addi $t1, $t1, 4
    addi $t2, $t2, -1
    addi $t8, $t8, 1
    bne  $t2, $zero, clear_marked_loop

    # after normal clearing, apply special effect if needed
    jal  clear_special_column

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Apply gravity to board
##############################################################################
apply_gravity:
    la  $t8, board
    li  $t0, 0          # col

gravity_col_loop:
    li  $t1, 15     # write_row
    li  $t2, 15     # scan_row

gravity_scan_loop:
    # addr of board[scan_row][col]
    li   $t3, 10
    mult $t2, $t3
    mflo $t4
    add  $t4, $t4, $t0
    sll  $t4, $t4, 2
    add  $t5, $t8, $t4
    lw   $t6, 0($t5)

    beq  $t6, $zero, gravity_scan_next

    # addr of board[write_row][col]
    li   $t3, 10
    mult $t1, $t3
    mflo $t4
    add  $t4, $t4, $t0
    sll  $t4, $t4, 2
    add  $t7, $t8, $t4

    sw   $t6, 0($t7)

    beq  $t1, $t2, gravity_same_cell
    sw   $zero, 0($t5)

gravity_same_cell:
    addi $t1, $t1, -1    # next write position

gravity_scan_next:
    addi $t2, $t2, -1
    slti $t3, $t2, 0
    beq  $t3, $zero, gravity_scan_loop

    # fill remaining cells above write_row with 0
gravity_fill_loop:
    slti $t3, $t1, 0
    bne  $t3, $zero, gravity_next_col

    li   $t3, 10
    mult $t1, $t3
    mflo $t4
    add  $t4, $t4, $t0
    sll  $t4, $t4, 2
    add  $t5, $t8, $t4
    sw   $zero, 0($t5)

    addi $t1, $t1, -1
    j    gravity_fill_loop

gravity_next_col:
    addi $t0, $t0, 1
    li   $t3, 10
    bne  $t0, $t3, gravity_col_loop

    jr   $ra

##############################################################################
# Repeatedly clear matches and apply gravity until stable
##############################################################################
resolve_board:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

resolve_loop:
    jal  clear_marks
    jal  find_matches
    jal  clear_marked
    beq  $v0, $zero, resolve_done

    jal  apply_gravity
    j    resolve_loop

resolve_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Game over if any gem touches the top row (row 0)
##############################################################################
check_game_over:
    la   $t0, board      # board base
    li   $t1, 0          # col = 0

check_top_loop:
    sll  $t2, $t1, 2     # offset = col * 4   (row 0 => no extra row offset)
    add  $t3, $t0, $t2
    lw   $t4, 0($t3)

    bne  $t4, $zero, top_game_over

    addi $t1, $t1, 1
    li   $t5, 10
    bne  $t1, $t5, check_top_loop

    jr   $ra

top_game_over:
    j   quit_game
    
##############################################################################
# Clear screen to black
##############################################################################
clear_screen:
    lw $t0, ADDR_DSPL
    lw $t1, bg_colour
    li $t2, 1024

clear_loop:
    sw $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, -1
    bne $t2, $zero, clear_loop
    jr $ra

##############################################################################
# Sleep
##############################################################################
sleep:
    li   $v0, 32
    li   $a0, 80
    syscall
    jr   $ra
