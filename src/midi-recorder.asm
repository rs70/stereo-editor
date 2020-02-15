; -----------------------------------------------------------------------------
; Copyright (c) 1988-2018 Robert A. Stoerrle
;
; Permission to use, copy, modify, and/or distribute this software for any
; purpose with or without fee is hereby granted, provided that the above
; copyright notice and this permission notice appear in all copies.
;
; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
; REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
; AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
; INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
; LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
; OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
; PERFORMANCE OF THIS SOFTWARE.
; -----------------------------------------------------------------------------

;This source file contains code for Stereo Editor's "MIDI Recording Studio"
;transient application. Transient applications load at $C000. Transient
;applications may use only the memory between $C000 and $CFFF, and zero page
;locations 100-131. Return with carry set ONLY if sid file needs to be saved
;after this application.

   .org $c000
   .obj "015"

;-- Main Editor Interface storage --

start_heap    = $7000
end_heap      = $bffc

voice_start   = 2
voice_end     = 16
voice_pos     = 30

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

note_table    = $cef0          ;Keeps track of notes that are on
note_string   = $cee0          ;Current note string
receive_buf   = $cf00          ;Keeps track of MIDI bytes received

;-- Zero-page usage --

ptr           = zp             ;General-use pointer
i_index       = zp+2           ;Interface input index
r_index       = zp+3           ;Read index
mod_flag      = zp+4           ;1=SID in memory modified, 0=not
num_notes     = zp+5           ;How many notes are on?
r0            = zp+6
r1            = zp+8
r2            = zp+10
r3            = zp+12
last_stat     = zp+14          ;Last MIDI status byte read
cur_note      = zp+15          ;Current note (temporary value)

k_txtptr      = $e0            ;Kernal interface variable
colptr        = $e2            ;Kernal interface variable
start_m       = $e2            ;Start of block to be moved
end_m         = $e4            ;End of block
dest_m        = $e6            ;Destination address for block

;-- Transient application ID text --

    .asc "sid/app"
    .byte 015 ;File number
    .word init ;Starting address
return_vec .word $ffff ;Filled in by main program - Return location
stack_save .byte $fa

;-- Exit application --

exit = *

    ldx stack_save
    txs
    lda #19
    sta $de08
    lda #17
    sta $de08

    lsr mod_flag
    jmp (return_vec)

;-- Set flag indicating file modified --

modify = *

    lda #1
    sta mod_flag
    rts

;-- MIDI IRQ handler --

inter = *

    bit $de08
    bpl norm_inter
    lda $de09
    ldx i_index
    sta receive_buf,x
    inc i_index
    pla
    pla

;-- End Stereo Editor IRQ routine --

irq_end = *

    pla
    sta $01
    pla
    tay
    pla
    tax
    pla
    rti

;-- Do normal interrupt processing --

norm_inter = *

    rts

;-- Get byte from MIDI port. Wait until data in buffer, or a key
;   pressed. Return byte in .A, or carry set if key is hit --

get_midi = *

    ldx r_index
    cpx i_index
    bne +
    lda 198
    beq get_midi
    jsr getin
    jmp exit
;    sec
;    rts

+   lda receive_buf,x
    inc r_index
    clc
    ora #0
    rts

;-- Transmit byte in MIDI port. .A = byte to send --

put_midi = *

    tax
    lda #2
-   bit $de08
    beq -
    stx $de09
    rts

;-- Turn on note in .A (12-107) --

note_on = *

    ldy num_notes
    cpy #6
    bcs +
    sta note_table,y
    inc num_notes
+   rts

;-- Turn off note in .A (12-107). --

note_off = *

    ldy #0
-   cpy num_notes
    beq +
    cmp note_table,y
    beq no1
    iny
    bne -
+   rts

no1 cpy num_notes
    beq +
    lda note_table+1,y
    sta note_table,y
    iny
    bne no1
+   dec num_notes
    rts

;-- Display currently active notes. --

show_on = *

    ldy #0
so1 cpy num_notes
    bcs so9
    sty r2
    lda note_table,y
    jsr get_note_str
    lda r2
    jsr get_scr_pos
    ldy #2
-   lda note_string,y
    sta (r0),y
    lda #13
    sta (r1),y
    dey
    bpl -
    ldy r2
    iny
    bne so1

so9 cpy #6
    bcs +
    sty r2
    tya
    jsr get_scr_pos
    ldy #2
    lda #32
-   sta (r0),y
    dey
    bpl -
    ldy r2
    iny
    bne so9
+   rts

;-- Given a note number in .A (12-107), convert that to a 3-byte string
;   of the form: "A#4". --

get_note_str = *

    sec
    sbc #12
    ldy #0
-   cmp #12
    bcc +
    sbc #12
    iny
    bne -
+   pha
    tya
    ora #$30
    sta note_string+2
    pla
    asl
    tay
    lda note_names,y
    sta note_string
    lda note_names+1,y
    sta note_string+1
    rts

;-- Given note index in .A, return screen pointers to where on screen to put
;   that note string. --

get_scr_pos = *

    asl
    tay
    lda note_loc,y
    sta r0
    sta r1
    lda note_loc+1,y
    sta r0+1
    clc
    adc #col_factor
    sta r1+1
    rts

;-- Screen locations of notes that are on. --

note_loc       .word 10*40+10+s_base
               .word 11*40+10+s_base
               .word 12*40+10+s_base
               .word 13*40+10+s_base
               .word 14*40+10+s_base
               .word 15*40+10+s_base

;-- Note names for each step. --

note_names     .scr "C "
               .scr "C#"
               .scr "D "
               .scr "D#"
               .scr "E "
               .scr "F "
               .scr "F#"
               .scr "G "
               .scr "G#"
               .scr "A "
               .scr "A#"
               .scr "B "

;-----------------------------------------------------------------------------
; MAIN PROGRAM
;-----------------------------------------------------------------------------

init = *

    tsx
    stx stack_save
    lda #0
    sta last_stat
    sta mod_flag
    sta i_index
    sta r_index
    sta num_notes

    ldx #<inter               ;Set up our MIDI receive interrupt
    ldy #>inter
    jsr setirq

    lda #19                   ;Tell interface we want interrupt on receive
    sta $de08
    lda #145
    sta $de08

    jsr print
    .byte clr
    .byte eot

;-- Recording main loop. --

rec_loop = *

    jsr get_midi
    sta cur_note
    bpl +
    sta last_stat
    jmp rec_loop

+   lda last_stat
    beq rec_loop
    and #$f0
    cmp #$90
    bne rl2

    jsr get_midi               ; Velocity (just discard unless 0)
    beq +
    lda cur_note
    jsr note_on
    jsr show_on
    jmp rec_loop
+   lda cur_note
    jsr note_off
    jsr show_on
    jmp rec_loop

rl2 jmp rec_loop
