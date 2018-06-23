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

;This source file contains code for Stereo Editor's "MSW Archive Maker"
;transient application. Transient applications load at $C000. If SID data
;reside that high, they are moved down, overwriting the player module.
;Transient applictions may use only the memory between $C000 and $CFFF, and
;zero page locations 100-131. Return with carry set ONLY if the sid file needs
;to be saved after this application.
;

   .org $c000
   .obj "012"

;
;Interface storage
;

credits     = $5800
mus_device  = $5a87
start_heap  = $7000
end_heap    = $bffc
voice_start = 2
voice_end   = 16
voice_pos   = 30

;
;NEW Kernal routine equates:
;

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

;
;Zero-page start of storage equate
;

zp = 100                 ;Start of zero page storage for this module

;
;Major storage
;

filename = $cf00

;
;Zero-page pointers
;

ptr              = zp            ;General-use pointer
mus_len          = zp+2          ;Length of .MUS file
str_len          = zp+4          ;Length of .STR file
type             = zp+6          ;Type byte
filename_len     = zp+7          ;Length of filename stem
tempy            = zp+8          ;A temporary value
scr_len          = zp+9

k_txtptr         = $e0           ;Kernal interface variable
colptr           = $e2           ;Kernal interface variable
start_m          = $e2           ;Start of block to be moved
end_m            = $e4           ;End of block
dest_m           = $e6           ;Destination address for block

;
;Constants used by Kernal routines
;

screen           = $f400
vic              = $d000

kernal_in        = %00000110
kernal_out       = %00000101

eof              = 1
def              = 2
tab              = 3
rvs              = 4
rvsoff           = 5
defl             = 6
defr             = 7
clr              = 8
fkey             = 10
box              = 12
xx               = 96
col              = 176
yy               = 224
eot              = 255

dispatch         = 1
service          = 2
numeric          = 3
string           = 4
null'item        = 5
eom              = 0

;
;Transient application ID text
;

    .asc "sid/app"
    .byte 012 ;File number
    .word init ;Starting address
return_vec .word $ffff ;Filled in by main program - Return location

;
;----- Main Program -----
;

init = *

    ldy #0

    lda voice_start
    cmp #<start_heap
    bne +
    lda voice_start+1
    cmp #>start_heap
    beq ++
+   ldy #2

+   lda voice_start+6
    sec
    sbc voice_start
    sta mus_len
    lda voice_start+7
    sbc voice_start+1
    sta mus_len+1
    bne +
    lda mus_len
    cmp #6
    beq ++
+   iny

+   lda voice_start+12
    sec
    sbc voice_start+6
    sta str_len
    lda voice_start+13
    sbc voice_start+7
    sta str_len+1
    bne +
    lda str_len
    cmp #6
    beq ++
+   iny
    iny
    iny
    iny

+   sty type

    lda type_table,y
    bpl +
    jmp bad_combo
+   asl
    adc type_table,y
    tay
    sty tempy

    jsr print
    .byte clr,box,8,5,32,7,4,xx+9,yy+6,col+1
    .asc "Stereo Editor MSW Maker"
    .byte xx+13,yy+10,col+7
    .asc "Ready to write a"
    .byte xx+21,yy+11
    .asc "file!"
    .byte xx+10,yy+13
    .asc "Enter a Filename Stem:"
    .byte xx+15,yy+15,col+13,tab,39
    .byte xx+5,yy+17,col+7
    .asc "(Or just press RETURN to abort)"
    .byte xx+17,yy+11,col+10,eot

    ldy tempy
    ldx #0
-   lda arc_ext,y
    ora #128
    jsr printchar
    iny
    inx
    cpx #3
    bne -

    jsr print
    .byte col+13,xx+15,yy+15,eot
    jsr get_filename
    cpy #0
    bne +
    jmp exit

+   jsr blurb
    jsr print
    .asc "Writing Header Information..."
    .byte eof,eot

    lda mus_device
    sta $ba
    jsr init_drive
    lda #15
    ldx $ba
    ldy #15
    jsr setlfs
    lda #0
    jsr setnam
    jsr open

;-- Determine length of credit block. Add it to mus_len --

    ldy #0
-   lda credits,y
    beq yplus0
    iny
    bne -
-   lda credits+256,y
    beq yplus256
    iny
    bne -
yplus256 inc mus_len+1
yplus0 tya
    sec
    adc mus_len
    sta mus_len
    bcc +
    inc mus_len+1

;-- Open actual file --

+   ldx filename_len
    ldy tempy
    lda #"."
    sta filename,x
    inx
    lda arc_ext,y
    sta filename,x
    inx
    lda arc_ext+1,y
    sta filename,x
    inx
    lda arc_ext+2,y
    sta filename,x
    inx
    stx scr_len
    txa
    ldx #<filename
    ldy #>filename
    jsr setnam
    lda #1
    ldx $ba
    ldy #1
    jsr setlfs
    jsr open
    jsr read_error
    cmp #20
    bcc +
    jmp report_error
+   ldx #1
    jsr chkout

;-- Send ML header to file --

    lda #<start_off
    sta ptr
    lda #>start_off
    sta ptr+1
    ldy #0
-   lda (ptr),y
    jsr chrout
    inc ptr
    bne +
    inc ptr+1
+   lda ptr
    cmp #<end_off
    bne -
    lda ptr+1
    cmp #>end_off
    bne -

;-- Send type byte to file --

    lda type
    jsr chrout

;-- Send SAL mimic code to file --

    ldy #0
-   lda mimic_code,y
    jsr chrout
    iny
    cpy #5
    bcc -

;-- Send filename length and filename to file --

    lda filename_len
    jsr chrout
    ldy #0
-   cpy filename_len
    bcs +
    lda filename,y
    jsr chrout
    iny
    bne -

;-- Send MUS file --

+   jsr blurb
    jsr print
    .asc "Sending Music to File..."
    .byte eof,eot
    lda mus_len
    clc
    adc #8
    php
    jsr chrout
    lda mus_len+1
    plp
    adc #0
    jsr chrout
    lda voice_start
    sta ptr
    lda voice_start+1
    sta ptr+1
    lda #0
    jsr chrout
    jsr chrout

    ldy #0
-   lda voice_start+2,y
    sec
    sbc voice_start,y
    php
    jsr chrout
    lda voice_start+3,y
    plp
    sbc voice_start+1,y
    jsr chrout
    iny
    iny
    cpy #6
    bcc -

    ldy #0
-   lda (ptr),y
    jsr chrout
    inc ptr
    bne +
    inc ptr+1
+   lda ptr
    cmp voice_start+6
    bne -
    lda ptr+1
    cmp voice_start+7
    bne -
    jsr send_credits

;-- Send .WDS file if we're supposed to --

    lda type
    and #2
    beq skip_wds
    jsr blurb
    jsr print
    .asc "Sending Words to File..."
    .byte eof,eot
    lda voice_start
    sec
    sbc #<start_heap
    php
    jsr chrout
    plp
    lda voice_start+1
    sbc #>start_heap
    jsr chrout
    lda #<start_heap
    sta ptr
    lda #>start_heap
    sta ptr+1
    ldy #0
-   lda (ptr),y
    jsr chrout
    inc ptr
    bne +
    inc ptr+1
+   lda ptr
    cmp voice_start
    bne -
    lda ptr+1
    cmp voice_start+1
    bne -

;-- Send .STR file if necessary

skip_wds = *

    lda type
    and #4
    beq skip_str
    jsr blurb
    jsr print
    .asc "Sending Stereo to File..."
    .byte eof,eot
    lda str_len
    clc
    adc #9
    php
    jsr chrout
    plp
    lda str_len+1
    adc #0
    jsr chrout
    lda #0
    jsr chrout
    jsr chrout

    ldy #6
-   lda voice_start+2,y
    sec
    sbc voice_start,y
    php
    jsr chrout
    lda voice_start+3,y
    plp
    sbc voice_start+1,y
    jsr chrout
    iny
    iny
    cpy #12
    bcc -

    lda voice_start+6
    sta ptr
    lda voice_start+7
    sta ptr+1
    ldy #0
-   lda (ptr),y
    jsr chrout
    inc ptr
    bne +
    inc ptr+1
+   lda ptr
    cmp voice_start+12
    bne -
    lda ptr+1
    cmp voice_start+13
    bne -
    lda #0
    jsr chrout

;-- Send scratch text and close files now that we're done --

skip_str = *

    lda #"s"
    jsr chrout
    lda #"0"
    jsr chrout
    lda #":"
    jsr chrout
    ldy #0
-   lda filename,y
    jsr chrout
    iny
    cpy scr_len
    bcc -
    lda #0
    jsr chrout

;-- Exit application --

exit = *

    jsr clrchn
    lda #1
    jsr close
    lda #15
    jsr close
    clc
    jmp (return_vec)

;-- Report disk error --

report_error = *

    pha
    jsr print
    .byte clr,xx+0,yy+3,col+1
    .asc "Disk Error #"
    .byte eot
    pla
    jsr printbyte
    jsr print
    .asc " has occurred."
    .byte 13
    .asc "Press RETURN."
    .byte eot
-   jsr getin
    cmp #13
    bne -
    jmp exit

;-- Report bad combination of files to archive --

bad_combo = *

    jsr print
    .byte clr,xx+0,yy+3,col+1
    .asc "This combination of files cannot"
    .byte 13
    .asc "be archived."
    .byte 13,13
    .asc "Press RETURN."
    .byte eot
    jmp -

;-- Send credit block to output file --

send_credits = *

    ldy #0
-   lda credits,y
    beq +
    jsr chrout
    iny
    bne -
-   lda credits+256,y
    beq +
    jsr chrout
    iny
    bne -
+   jmp chrout

;-- Type table --

type_table   .byte 128,128,128,1,128,0,128,2

;-- SID Archive extensions --

arc_ext      .asc "slrsalmsw"

;-- Accept a filename from user --

get_filename = *

   lda #0
   sta filename_len

gfn0  jsr cursor_on

gfn1 jsr getin
   beq gfn1
   pha
   jsr cursor_off
   pla
   ldy filename_len
   cmp #13
   beq gfret
   cmp #20
   beq gfdel
   cmp #135
   beq gfabort
   cmp #3
   beq gfabort
   cmp #32
   bcc gfn0
   cmp #96
   bcs gfn0
   cpy #12
   bcs gfn0
   sta filename,y
   jsr printchar
   inc filename_len
   bne gfn0

gfdel cpy #0
   beq gfn0
   dec filename_len
   jsr backspace
   jmp gfn0

gfabort ldy #0

gfret lda #32
-  dey
   bmi +
   cmp filename,y
   beq -
+  iny
   sty filename_len
   rts

;-- Print blurb in middle of screen --

blurb = *

    jsr print
    .byte clr,def,40,0,12,1,eot
    rts

;-- Make us mimic a real SAL file as far as Omega-Q and Music Connection are
;-- concerned.

mimic_code = *

    .byte $20,$cc,$ff,$28,$60

;-----------------------------------------------------------------------------
; UNCRUNCHER MODULE
;-----------------------------------------------------------------------------

;-- Uncruncher equates --

heap_ptr = 251
utemp = 253
uptr = 254
uname_len = $2a8
uname = $2a9
raster_num = $2c0
enable = $2c1
error = $2c2

;-- BASIC header --

start_off = *

    .word $0801  ;Load address
    .off $0801   ;Offset coded to $0801

len_ref = *

    .word 2059
    .word utype_byte-len_ref
    .byte 158
    .asc "2061"
    .byte 0
    .word 0

;-- Set up screen display. Blank screen at first.

    lda #11
    sta 53265
    lda #8
    jsr $ffd2
    lda #0
    sta 53280
    sta 53281
    ldy #0
-   lda #219
    sta $400,y
    sta $500,y
    sta $600,y
    sta $700,y
    lda #15
    sta $d800,y
    sta $d900,y
    sta $da00,y
    sta $db00,y
    iny
    bne -

    ldy #33
-   lda #98+128
    sta 5*40+1027,y
    lda #98
    sta 11*40+1027,y
    lda #6
    sta 5*40+55299,y
    sta 11*40+55299,y
    dey
    bpl -

    ldy #23
-   lda #160
    sta 14*40+1024+8,y
    sta 18*40+1024+8,y
    lda #11
    sta 14*40+55296+8,y
    sta 18*40+55296+8,y
    dey
    bpl -

    lda #108+128
    sta 5*40+1024+3
    lda #123+128
    sta 5*40+1024+36
    lda #124+128
    sta 11*40+1024+3
    lda #126+128
    sta 11*40+1024+36

    lda #97
    sta 6*40+3+1024
    sta 7*40+3+1024
    sta 8*40+3+1024
    sta 9*40+3+1024
    sta 10*40+3+1024

    lda #97+128
    sta 6*40+36+1024
    sta 7*40+36+1024
    sta 8*40+36+1024
    sta 9*40+36+1024
    sta 10*40+36+1024

    lda #160
    sta 15*40+8+1024
    sta 16*40+8+1024
    sta 17*40+8+1024
    sta 15*40+31+1024
    sta 16*40+31+1024
    sta 17*40+31+1024

    lda #6
    sta 6*40+3+55296
    sta 7*40+3+55296
    sta 8*40+3+55296
    sta 9*40+3+55296
    sta 10*40+3+55296
    sta 6*40+36+55296
    sta 7*40+36+55296
    sta 8*40+36+55296
    sta 9*40+36+55296
    sta 10*40+36+55296

    lda #11
    sta 15*40+8+55296
    sta 16*40+8+55296
    sta 17*40+8+55296
    sta 15*40+31+55296
    sta 16*40+31+55296
    sta 17*40+31+55296

    ldy #31
    lda #32
-   sta 40*6+4+1024,y
    sta 40*7+4+1024,y
    sta 40*8+4+1024,y
    sta 40*9+4+1024,y
    sta 40*10+4+1024,y
    dey
    bpl -

    ldy #21
-   lda box_text,y
    sta 40*15+9+1024,y
    lda box_text+22,y
    sta 40*16+9+1024,y
    lda box_text+44,y
    sta 40*17+9+1024,y
    lda #1
    sta 40*15+9+55296,y
    sta 40*16+9+55296,y
    sta 40*17+9+55296,y
    dey
    bpl -

;-- Set up raster interrupt in middle of screen --

   sei
   lda #$7f
   sta $dc0d
   lda #1
   sta $d01a
   lda #1
   sta enable
   sta raster_num
   lda value_d012
   sta $d012
   lda #<inter
   sta $314
   lda #>inter
   sta $315
   cli

;-- Initialize heap pointer --

    lda #<heap
    sta heap_ptr
    lda #>heap
    sta heap_ptr+1

;-- Read some preliminary information from heap --

    jsr get_byte
    sta uname_len
    ldy #0
-   cpy uname_len
    bcs +
    jsr get_byte
    sta uname,y
    iny
    bne -

;-- Locate credit block for display --

+   lda heap_ptr
    sta uptr
    lda heap_ptr+1
    sta uptr+1
    ldy #4
-   lda (heap_ptr),y
    clc
    adc uptr
    sta uptr
    iny
    lda (heap_ptr),y
    adc uptr+1
    sta uptr+1
    iny
    cpy #10
    bcc -
    lda uptr
    clc
    adc #10
    sta uptr
    bcc +
    inc uptr+1

;-- UPTR has now been set to point to credit block. Display it --

+   clc
    ldx #6
    ldy #4
    jsr $fff0   ;Plot cursor to row 6, column 4

    ldy #0
-   lda (uptr),y
    beq found_end
    jsr $ffd2
    cmp #13
    bne +
    lda #29
    jsr $ffd2
    jsr $ffd2
    jsr $ffd2
    jsr $ffd2
+   inc uptr
    bne +
    inc uptr+1
+   bne -

found_end = *

    lda #13
    jsr $ffd2

;-- Redisplay the screen that was blanked --

    lda #27
    sta 53265

;-- Wait for keypress. If STOP, abort. If RETURN, continue.

    lda #0
    sta 198
-   jsr $ffe4
    cmp #13
    beq begin_dissolve
    cmp #3
    bne -
    ldx #<abort_text
    ldy #>abort_text
    jsr blue
    jmp uexit

;-- Decide which files to write, call routine to write them --

begin_dissolve = *

    lda #0
    sta enable
    lda #$16
    sta $d018
    lda #147
    jsr $ffd2

    lda #15
    ldx $ba
    ldy #15
    jsr $ffba
    lda #2
    ldx #<init_cmd
    ldy #>init_cmd
    jsr $ffbd
    jsr $ffc0

    ldx #0
-   lda utype_byte
    and bin,x
    beq +
    txa
    pha
    jsr write_file
    pla
    tax
+   inx
    cpx #3
    bne -

;-- Ask user if he wants to scratch original archive --

    ldy #27
-   lda query_text,y
    sta 40*12+6+1024,y
    lda #1
    sta 40*12+6+55296,y
    dey
    bpl -

-   jsr $ffe4
    cmp #"y"
    beq yes_scratch
    cmp #"n"
    bne -
    jmp done

;-- He said yes, so scratch the file --

yes_scratch = *

    ldy #27
-   lda scr_text,y
    sta 40*12+6+1024,y
    dey
    bpl -

    ldx #15
    jsr $ffc9
-   jsr get_byte
    beq +
    jsr $ffd2
    jmp -

done = *

+   ldx #<done_text
    ldy #>done_text
    jsr blue

;-- Exit to BASIC --

uexit = *

    ldx #$fa
    txs
    jmp $a474

;-- Report disk error --

disk_err = *

    ldx #<error_text
    ldy #>error_text
    jsr blue
    ldy #0
-   lda error,y
    jsr $ffd2
    cmp #13
    beq +
    iny
    bne -
+   jmp uexit

;-- Draw blue ready screen and print null-terminated text pointed to by .X, .Y

blue = *

    stx uptr
    sty uptr+1
    jsr $ffcc
    lda #1
    jsr $ffc3
    lda #15
    jsr $ffc3
    jsr $ff84
    sei
    lda #$31
    sta $314
    lda #$ea
    sta $315
    cli
    jsr $ff81
    ldy #0
-   lda (uptr),y
    beq +
    jsr $ffd2
    iny
    bne -
+   rts

;-- Binary values --

bin   .byte 1,2,4

;-- Given extension in .A (0 = MUS, 1= STR, 2 = WDS) --
;-- Add appropriate extension to filename and open that file for writing --
;-- Then send appropriate data from heap --

write_file = *

    sta utemp
    asl
    adc utemp
    tay
    ldx uname_len
    lda "."
    sta uname,x
    inx
    lda ext,y
    sta uname,x
    sta wr_text+9
    inx
    lda ext+1,y
    sta uname,x
    sta wr_text+10
    inx
    lda ext+2,y
    sta uname,x
    sta wr_text+11
    inx
    txa
    ldx #<uname
    ldy #>uname
    jsr $ffbd

    ldy #14
-   lda wr_text,y
    sta 40*12+13+1024,y
    lda #1
    sta 40*12+13+55296,y
    dey
    bpl -

    lda #1
    ldx $ba
    tay
    jsr $ffba
    jsr $ffc0
    jsr check_err
    ldx #1
    jsr $ffc9

    jsr get_byte
    sta uptr
    jsr get_byte
    sta uptr+1
-   jsr get_byte
    jsr $ffd2
    lda uptr
    bne +
    dec uptr+1
+   dec uptr
    lda uptr
    ora uptr+1
    bne -

    jsr $ffcc
    lda #1
    jsr $ffc3
    jmp check_err

;-- Check error chananel --

check_err = *

    ldx #15
    jsr $ffc6
    ldy #0
-   jsr $ffcf
    sta error,y
    cmp #13
    beq +
    iny
    bne -
+   jsr $ffcc
    lda error
    cmp #"2"
    bcc +
    jmp disk_err
+   rts

;-- Read next byte from data from heap --

get_byte = *

    sty gb1+1
    ldy #0
    lda (heap_ptr),y
    inc heap_ptr
    bne gb1
    inc heap_ptr+1
gb1 ldy #0
    ora #0
    rts

;-- Handle raster interrupt --

inter = *

   lda $d019
   sta $d019
   and #1
   beq l1
   lda raster_num
   eor #1
   sta raster_num
   ldx raster_num
   lda enable
   beq +
   lda value_d018,x
   sta $d018
+  lda value_d012,x
   sta $d012
   cpx #0
   bne l1
   jmp $ea31
l1 lda $dc0d
   pla
   tay
   pla
   tax
   pla
   rti

;-- Raster information tables --

value_d012  .byte $ff,$a0
value_d018  .byte $16,$14

;-- Text that goes in lower box --

box_text   .scr "  Insert a disk with  "
           .scr " lots of room and hit "
           .scr "  RETURN to dissolve. "

;-- Text for "Writing .XXX..." message

wr_text    .scr "Writing .xxx..."

;-- Text asking whether original file should be scratched --

query_text .scr "Scratch Original File (Y/N)?"

;-- Text saying that original file is being scratched --

scr_text   .scr " Scratching Original File..."

;-- Done text --

done_text  .byte 13
           .asc "dissolve completed."
           .byte 13,0

;-- Abort text --

abort_text .byte 13
           .asc "aborted."
           .byte 13,0

;-- Disk error text --

error_text .byte 13
           .asc "disk error: "
           .byte 0

;-- Disk initialization command --

init_cmd   .asc "i0"

;-- Possible music file extensions when dissolved --

ext    .asc "muswdsstr"

;-- Beginning of data making up filename and sid --

heap = *+6

;-- Type byte will be placed here --

utype_byte = *

;-- End of offset coding --

   .ofe

end_off = *
