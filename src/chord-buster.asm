;-----------------------------------------------------------------------------
;FILENAME: CHORD.SOURCE                               Chord buster Translation
;-----------------------------------------------------------------------------

;This source file contains code for the Stereo Editor translation of Jerry
;Roth's "Super Chord Buster". It is coded as a transient application.
;Transient applications load at $C000. Transient applications may use only the
;memory between $C000 and $CFFF, and zero page locations 100-131. Return with
;carry set ONLY if sid file needs to be saved after this application.

   .org $c000
   .obj "016"

;-- Main Editor Interface storage --

start_heap    = $7000
end_heap      = $bf00

voice_start   = 2
voice_end     = 16
voice_pos     = 30

nq_count      = $bf10
nq_hot        = $bf11
nq_app        = $bf12
nq_name       = $bf13
note_queue    = $bf33

;-- NEW Kernal routine equates --

setirq        = $e000
print         = $e003
lprint        = $e006
printchar     = $e009
printbyte     = $e00c
printword     = $e00f
select_string = $e012
save_screen   = $e015
recall_screen = $e018
getrom        = $e01b
clear_screen  = $e01e
menudef       = $e021
menuset       = $e024
select        = $e027
select_0      = $e02a
headerdef     = $e02d
sizedef       = $e030
s_itemx       = $e033
s_itemy       = $e036
s_itemlen     = $e039
s_itemvecl    = $e03c
s_itemvech    = $e03f
s_itemvarl    = $e042
s_itemvarh    = $e045
s_itemmin     = $e048
s_itemmax     = $e04b
s_itemtype    = $e04e
read_item     = $e051
cursor_on     = $e054
cursor_off    = $e057
move_up       = $e05a
move_down     = $e05d
read_prdir    = $e060
init_drive    = $e063
load_prfile   = $e066
preparef      = $e069
releasef      = $e06c
setlfs        = $e06f
setnam        = $e072
open          = $e075
close         = $e078
chkin         = $e07b
chkout        = $e07e
clrchn        = $e081
chrin         = $e084
chrout        = $e087
getin         = $e08a
set_item      = $e08d
get_adr       = $e090
backspace     = $e093
read_err      = $e096
read_error    = $e099

;-- Zero-page start of storage equate --

zp            = 100            ;Start of zero page storage for this module

;-- Constants used by Kernal routines --

screen        = $f400
s_base        = screen
s             = s_base
vic           = $d000
c_base        = $d800
c             = c_base
col_f1        = s_base-c_base
col_factor    = 65535-col_f1+1/256

kernal_in     = %00000110
kernal_out    = %00000101

eof           = 1
def           = 2
tab           = 3
rvs           = 4
rvsoff        = 5
defl          = 6
defr          = 7
clr           = 8
fkey          = 10
box           = 12
xx            = 96
col           = 176
yy            = 224
eot           = 255

dispatch      = 1
service       = 2
numeric       = 3
string        = 4
null'item     = 5
eom           = 0

;-- Major storage --

base_note     = $cf00
chord_type    = $cf01
cur_item      = $cf02          ;4 bytes

;-- Zero-page usage --

ptr           = zp             ;General-use pointer
mod_flag      = zp+4           ;1=SID in memory modified, 0=not
r0            = zp+6
r1            = zp+8
r2            = zp+10
r3            = zp+12
heap_ptr      = zp+14
item_ptr      = zp+16

txtptr        = $e0            ;Kernal interface variable
colptr        = $e2            ;Kernal interface variable
start_m       = $e2            ;Start of block to be moved
end_m         = $e4            ;End of block
dest_m        = $e6            ;Destination address for block

;-- Transient application ID text --

    .asc "sid/app"
    .byte 016 ;File number
    .word init ;Starting address
return_vec .word $ffff ;Filled in by main program - Return location
stack_save .byte $fa

;-- Exit application --

exit = *

    ldx stack_save
    txs
    lsr mod_flag
    jmp (return_vec)

;-- Set flag indicating file modified --

modify = *

    lda #1
    sta mod_flag
    rts

;-- Clear bottom of screen only (leave top logo alone). --

clear_bot = *

    ldy #0
    lda #32
-   sta s_base+200,y
    sta s_base+200+256,y
    sta s_base+200+512,y
    sta s_base+768-24,y
    iny
    bne -
    rts

;-----------------------------------------------------------------------------
; MAIN PROGRAM
;-----------------------------------------------------------------------------

init = *

    tsx
    stx stack_save
    lda #0
    sta mod_flag

    jsr print
    .byte clr,box,9,0,31,4,7,col+1,xx+11,yy+1
    .asc "Super Chord Buster"
    .byte col+15,xx+10,yy+2
    .asc "By Jerry Roth (Dr. J)"
    .byte xx+13,yy+3
    .asc "Copyright 1988"
    .byte eot

main_menu = *

    jsr clear_bot
    jsr print
    .byte box,6,9,33,16,6
    .byte col+13,xx+10,yy+7
    .asc "Choose base of chord:"
    .byte xx+4,yy+18,col+5
    .asc "Commonly used chords in key of C:"
    .byte xx+7,yy+20,col+13
    .asc "C  F  G  C7  G7  A7  E7  D7"
    .byte xx+16,yy+21
    .asc "Am  Dm  Em"
    .byte xx+9,yy+23,col+11
    .asc "Press F5 to return to"
    .byte xx+13,yy+24
    .asc "Stereo Editor"
    .byte eot

    ldx #yy+10
-   txa
    jsr printchar
    jsr print
    .byte xx+12
    .asc "................"
    .byte eot
    inx
    cpx #yy+16
    bcc -

    jsr menudef
    .byte 4,3,1
    .word exit,0,0,0
    .byte dispatch,7,10,5
    .word csel
    .asc "C"
    .byte dispatch,7,11,5
    .word csel
    .asc "C#/Db"
    .byte dispatch,7,12,5
    .word csel
    .asc "D"
    .byte dispatch,7,13,5
    .word csel
    .asc "D#/Eb"
    .byte dispatch,7,14,5
    .word csel
    .asc "E"
    .byte dispatch,7,15,5
    .word csel
    .asc "F"

    .byte dispatch,28,10,5
    .word csel
    .asc "F#/Gb"
    .byte dispatch,28,11,5
    .word csel
    .asc "G"
    .byte dispatch,28,12,5
    .word csel
    .asc "G#/Ab"
    .byte dispatch,28,13,5
    .word csel
    .asc "A"
    .byte dispatch,28,14,5
    .word csel
    .asc "A#/Bb"
    .byte dispatch,28,15,5
    .word csel
    .asc "B"
    .byte eom
    jmp select

;-- Chord table. --

chord_tab = *

    .byte 1,5,8,0,0,0,0 
    .byte 1,4,8,0,0,0,0 
    .byte 1,5,9,0,0,0,0 
    .byte 1,4,7,0,0,0,0 
    .byte 1,5,8,10,0,0,0 
    .byte 1,4,8,10,0,0,0 
    .byte 1,5,8,10,3,0,0 
    .byte 1,5,8,11,0,0,0 
    .byte 1,5,9,11,0,0,0 
    .byte 1,5,7,11,0,0,0 
    .byte 1,5,8,12,0,0,0 
    .byte 1,4,8,11,0,0,0 
    .byte 1,4,9,11,0,0,0 
    .byte 1,4,7,11,0,0,0 
    .byte 1,4,7,10,0,0,0 
    .byte 1,5,8,11,3,0,0 
    .byte 1,5,9,11,3,0,0 
    .byte 1,5,7,11,3,0,0 
    .byte 1,5,8,12,3,0,0 
    .byte 1,4,8,11,3,0,0 
    .byte 1,4,9,11,3,0,0 
    .byte 1,4,7,11,3,0,0 
    .byte 1,5,8,11,3,6,0 
    .byte 1,5,8,11,3,6,10 

;-- Names of notes. --

note_tab = *

    .asc "C"
    .byte eot
    .asc "C#/Db"
    .byte eot
    .asc "D"
    .byte eot
    .asc "D#/Eb"
    .byte eot
    .asc "E"
    .byte eot
    .asc "F"
    .byte eot
    .asc "F#/Gb"
    .byte eot
    .asc "G"
    .byte eot
    .asc "G#/Ab"
    .byte eot
    .asc "A"
    .byte eot
    .asc "A#/Bb"
    .byte eot
    .asc "B"
    .byte eot

;-- Ordinal numbers. --

ordinal = *

    .asc "1st "
    .byte eot
    .asc "3rd "
    .byte eot
    .asc "5th "
    .byte eot
    .asc "7th "
    .byte eot
    .asc "9th "
    .byte eot
    .asc "11th"
    .byte eot
    .asc "13th"
    .byte eot

;-- The base chord has been selected. --

csel = *

    jsr read_item
    sta base_note

c_reenter = *

    jsr clear_bot
    jsr print
    .byte box,3,9,37,22,6,def,40,0,7,13
    .asc "Choose type of chord ("
    .byte eot
    lda #<note_tab
    sta txtptr
    lda #>note_tab
    sta txtptr+1
    lda base_note
    jsr select_string
    jsr lprint
    jsr print
    .asc "):"
    .byte eof,col+11,eot

    ldx #yy+10
-   txa
    jsr printchar
    jsr print
    .byte xx+18
    .asc "....."
    .byte eot
    inx
    cpx #yy+22
    bcc -

    jsr menudef
    .byte 5,3,1
    .word main_menu,0,0,0
    .byte dispatch,4,10,14
    .word tsel
    .asc "Major"
    .byte dispatch,4,11,14
    .word tsel
    .asc "Minor"
    .byte dispatch,4,12,14
    .word tsel
    .asc "Augmented (+5)"
    .byte dispatch,4,13,14
    .word tsel
    .asc "Diminished"
    .byte dispatch,4,14,14
    .word tsel
    .asc "6th"
    .byte dispatch,4,15,14
    .word tsel
    .asc "Minor 6th"
    .byte dispatch,4,16,14
    .word tsel
    .asc "6th,9"
    .byte dispatch,4,17,14
    .word tsel
    .asc "7th"
    .byte dispatch,4,18,14
    .word tsel
    .asc "7th+5"
    .byte dispatch,4,19,14
    .word tsel
    .asc "7th-5"
    .byte dispatch,4,20,14
    .word tsel
    .asc "Major 7th"
    .byte dispatch,4,21,14
    .word tsel
    .asc "Minor 7th"

    .byte dispatch,23,10,14
    .word tsel
    .asc "Minor 7th+5"
    .byte dispatch,23,11,14
    .word tsel
    .asc "Minor 7th-5"
    .byte dispatch,23,12,14
    .word tsel
    .asc "Diminished 7th"
    .byte dispatch,23,13,14
    .word tsel
    .asc "9th"
    .byte dispatch,23,14,14
    .word tsel
    .asc "9th+5"
    .byte dispatch,23,15,14
    .word tsel
    .asc "9th-5"
    .byte dispatch,23,16,14
    .word tsel
    .asc "Major 9th"
    .byte dispatch,23,17,14
    .word tsel
    .asc "Minor 9th"
    .byte dispatch,23,18,14
    .word tsel
    .asc "Minor 9th+5"
    .byte dispatch,23,19,14
    .word tsel
    .asc "Minor 9th-5"
    .byte dispatch,23,20,14
    .word tsel
    .asc "11th"
    .byte dispatch,23,21,14
    .word tsel
    .asc "13th"
    .byte eom
    jmp select

;-- Type of chord has been selected. --

tsel = *

    jsr read_item
    sta chord_type
    asl                            ; Multiply by 7
    asl
    adc chord_type
    adc chord_type
    adc chord_type
    adc #<chord_tab
    sta r0
    lda #>chord_tab
    adc #0
    sta r0+1

    jsr print
    .byte box,14,13,26,21,2,col+15,yy+14,eot

    jsr init_queue
    ldy #0
ts1 sty r2
    lda #xx+15
    jsr printchar

    lda (r0),y
    bne +
    jmp ts9
+   clc
    adc base_note
    cmp #13
    bcc ts2
    sbc #12
ts2 sec
    sbc #1
    sta r1

    cpy #3
    bne ts4
    lda chord_type
    cmp #4
    beq ts3
    cmp #5
    beq ts3
    cmp #6
    bne ts4
ts3 jsr print
    .asc "6th "
    .byte eot
    lda #"6"
    jsr add_heap
    lda #"t"
    jsr add_heap
    lda #"h"
    jsr add_heap
    lda #32
    jsr add_heap
    ldy r2
    jmp ts5

ts4 lda #<ordinal
    sta txtptr
    lda #>ordinal
    sta txtptr+1
    tya
    jsr select_string
    jsr ladd_heap
    jsr lprint

ts5 jsr print
    .byte "-"," ",eot
    lda #"-"
    jsr add_heap
    lda #" "
    jsr add_heap
    lda #<note_tab
    sta txtptr
    lda #>note_tab
    sta txtptr+1
    lda r1
    jsr select_string
    jsr ladd_heap
    jsr lprint
    lda #13
    jsr printchar
    lda #"$"
    jsr add_heap
    lda #5
    sta cur_item
    lda r1
    sta cur_item+1
    jsr add_note

ts9 ldy r2
    iny
    cpy #7
    bcs tsa
    jmp ts1

tsa lda #<remove_opt
    sta txtptr
    lda #>remove_opt
    sta txtptr+1
    jsr ladd_heap
    lda #4
    sta cur_item
    jsr add_note

-   jsr getin
    beq -
    jmp c_reenter

;-- Initialize (clear) note queue. --

init_queue = *

    ldx #<our_name
    ldy #>our_name
    jsr set_util
    lda #0
    sta nq_count
    sta nq_hot
    lda #16
    sta nq_app
    lda #<note_queue+32
    sta heap_ptr
    lda #>note_queue
    sta heap_ptr+1
    sta item_ptr+1
    lda #<note_queue
    sta item_ptr
    rts

;-- Add byte in .A to note_queue text heap. --

add_heap = *

    sty aqy+1
    ldy #0
    sta (heap_ptr),y
    inc heap_ptr
aqy ldy #0
    rts

;-- Add EOT-terminated text at txtptr to note_queue text heap. --

ladd_heap = *

    ldy #0
-   lda (txtptr),y
    cmp #eot
    beq +
    jsr add_heap
    iny
    bne -
+   rts

;-- Add 4 bytes to note info table. --

add_note = *

    ldy #3
-   lda cur_item,y
    sta (item_ptr),y
    dey
    bpl -
    lda item_ptr
    clc
    adc #4
    sta item_ptr
    inc nq_count
    rts

;-- Set the utility menu name to the EOT-terminated string at .X and .Y --

set_util = *

    stx txtptr
    sty txtptr+1
    ldy #0
-   lda (txtptr),y
    sta nq_name,y
    cmp #eot
    beq +
    iny
    bne -
+   rts

;-- Util name. --

our_name       .asc "ADD CHORD NOTES"
               .byte eot

remove_opt     .asc "Remove Menu$"
               .byte eot
