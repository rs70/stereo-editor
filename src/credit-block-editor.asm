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

;This source file contains code for the SID Editor's "Credit Block Editor"
;transient application. Transient applications load at $C000. If SID data
;reside that high, they are moved down, overwriting the player module.
;Transient applictions may use only the memory between $C000 and $CFFF, and
;zero page locations 100-131. Return with carry set ONLY if sid file needs
;to be saved after this application.

   .org $c000
   .obj "008"

;
;Interface storage
;

cred_block  = $5800    ;Editor storage of credit block
voice_start = $02
var         = $5c00
stereo_mode = var+113
route       = var+114
midi_channel = $5a00+98
expand_value = $5a88

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

linebuf  =  $c780
clinebuf =  $c7c0

;
;Zero-page pointers
;

ptr              = zp            ;General-use pointer
aptr             = zp+2          ;Current position in ASCII credit block
line             = zp+4          ;Screen pointer
cline            = zp+6          ;Color pointer
rvs_flag         = zp+8          ;128=reverse, 0=normal
color            = zp+9          ;Current color (0-15)
xpos             = zp+10         ;Cursor X position (0-32)
ypos             = zp+11         ;Cursor row (0-4)
under_char       = zp+12         ;Character under cursor
under_color      = zp+13         ;Color under cursor
flash            = zp+14         ;1=flash cursor, 0=don't
count            = zp+15         ;Countdown to next cursor flash
cmode            = zp+16         ;128=flash on, 0=flash off
ps1              = zp+17         ;Scrolling pointer
ps2              = zp+19         ;Scrolling pointer
pc1              = zp+21         ;Scrolling pointer
pc2              = zp+23         ;Scrolling pointer
mod_flag         = zp+25         ;1=modified, 0=not
play_flag        = zp+26         ;1=include player in interrupt, 0=don't!

txtptr           = $e0           ;Kernal interface variable
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
;Player interface equates
;

player           = $6000
init_play        = player
drop_play        = player+3
play_inter       = player+6
sim_start        = player+9
p$status         = player+12
p$error          = player+13
p$error_voice    = player+14
p$address        = player+15
p$expand         = player+16
p$mode           = player+17
p$musicl         = player+18
p$musich         = player+24
p$enable         = player+30

;
;Transient application ID text
;

   .asc "sid/app"
   .byte 008 ;File number
   .word init ;Starting address
return_vec .word $ffff ;Filled in by main program - Return location

;
;Special interrupt routine for cursor flashing
;

inter = *

   lda play_flag
   beq +
   jsr play_inter

+  lda flash
   beq end_int
   dec count
   bne end_int
   lda #20
   sta count

   ldy xpos
   lda cmode
   eor #128
   sta cmode
   bmi +
   lda under_char
   sta (line),y
   lda under_color
   sta (cline),y
   rts

+  lda under_char
   eor #128
   sta (line),y
   lda color
   sta (cline),y

end_int rts

;
;Reset pointer to ASCII credit block
;

reset = *

   lda #<cred_block
   sta aptr
   lda #>cred_block
   sta aptr+1
   rts

;
;Get next byte from ASCII credit block
;

get_byte = *

   sty gbr+1
   ldy #0
   lda (aptr),y
   inc aptr
   bne gbr
   inc aptr+1
gbr ldy #0
   ora #0
   rts

;
;Send byte to ASCII credit block
;

send_byte = *

   sty sbr+1
   ldy #0
   sta (aptr),y
   inc aptr
   bne sbr
   inc aptr+1
sbr ldy #0
   rts

;
;Convert any ASCII code to its corresponding ROM code.
;Return with carry set only if it's non-printable

ascii_to_rom = *

   cmp #160
   beq sub128
   cmp #32
   bcc non_printable
   cmp #64
   bcc sub0
   cmp #96
   bcc sub64
   cmp #128
   bcc sub32
   cmp #160
   bcc non_printable
   cmp #192
   bcc sub64
   cmp #255
   bcc sub128
   lda #94
   clc
   rts
sub128 sec
   sbc #32
sub96 sec
   sbc #32
sub64 sec
   sbc #32
sub32 sec
   sbc #32
sub0 clc
   rts

non_printable = *

   sec
   rts

;
;Convert ROM to ASCII.
;

rom_to_ascii = *

   cmp #32
   bcc add64
   cmp #64
   bcc add0
   cmp #96
   bcc add128
   bcs add64
add128 clc
   adc #64
add64 clc
   adc #64
add0 rts

;
;Establish cursor at current position.
;

put_cursor = *

   jsr calc_line
   ldy xpos
   lda (cline),y
   sta under_color
   lda (line),y
   sta under_char
   eor #128
   sta (line),y
   lda color
   sta (cline),y
   lda #20
   sta count
   sta flash
   lda #128
   sta cmode
   rts

;
;Remove cursor from current position.
;

remove_cursor = *

   lda #0
   sta flash
   ldy xpos
   lda under_color
   sta (cline),y
   lda under_char
   sta (line),y
   rts

;
;Calculate screen/color addressed based on cursor position
;

calc_line = *

   ldx #4
   ldy ypos
   iny
   iny
   iny
   jsr get_adr
   lda colptr
   sta cline
   lda colptr+1
   sta cline+1
   lda txtptr
   sta line
   lda txtptr+1
   sta line+1
   rts

;
;Table of screen color changing ASCII codes.
;

color_table    .byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154
               .byte 155

;
;----- Main Program -----
;Set up normal character set at $C800
;

init = *

   jsr clear_screen
   lda #0
   sta play_flag
   sei
   lda 1
   and #%11111011
   sta 1
   lda #0
   sta start_m
   sta end_m
   sta dest_m
   lda #$d8
   sta end_m+1
   lda #$d0
   sta start_m+1
   lda #$c8
   sta dest_m+1
   jsr move_down
   lda #kernal_out
   sta 1
   cli

   lda #$d2     ;Switch to normal, upper-case character set we just copied
   sta 53272

;
;Draw credit block editing screen
;

   lda #0
   sta mod_flag

   lda #6
   ldy #0
-  sta $d800,y
   sta $d900,y
   iny
   bne -

   jsr print
   .byte xx+9,yy+0,col+1
   .asc "sid credit block editor"
   .byte xx+10,yy+11,col+7
   .asc "[f1] "
   .byte col+11
   .asc "- "
   .byte col+15
   .asc "delete line"
   .byte xx+10,yy+12,col+7
   .asc "[f2] "
   .byte col+11
   .asc "- "
   .byte col+15
   .asc "insert line"
   .byte xx+10,yy+13,col+7
   .asc "[f3] "
   .byte col+11
   .asc "- "
   .byte col+15
   .asc "center line"
   .byte xx+10,yy+14,col+7
   .asc "[f4] "
   .byte col+11
   .asc "- "
   .byte col+15
   .asc "invert line"
   .byte xx+10,yy+15,col+7
   .asc "[f5] "
   .byte col+11
   .asc "- "
   .byte col+15
   .asc "exit"
   .byte xx+10,yy+16,col+7
   .asc "[f7] "
   .byte col+11
   .asc "- "
   .byte col+15
   .asc "paint line"
   .byte xx+10,yy+17,col+7
   .asc "[f8] "
   .byte col+11
   .asc "- "
   .byte col+15
   .asc "invert/paint"
   .byte eot

   ldy #31
   lda #64
-  sta screen+84,y
   sta screen+324,y
   dey
   bpl -
   lda #93
   sta screen+123
   sta screen+163
   sta screen+203
   sta screen+243
   sta screen+283
   sta screen+156
   sta screen+196
   sta screen+236
   sta screen+276
   sta screen+316
   lda #112
   sta screen+83
   lda #109
   sta screen+323
   lda #110
   sta screen+116
   lda #125
   sta screen+356

;
;Convert ASCII credit block to screen codes.
;

   jsr init_for_convert
   lda #1
   sta color

conv_in = *

   jsr next_line
   ldy #0
   sty rvs_flag

cin1 = *

   jsr get_byte
   beq cin3
   jsr ascii_to_rom
   bcs cin2
   ora rvs_flag
   sta (line),y
   lda color
   sta (cline),y
   iny
   bne cin1

cin2 = *

   cmp #13
   beq conv_in

   cmp #18
   bne +
   lda #128
   sta rvs_flag
   bne cin1

+  cmp #18+128
   bne +
   lda #0
   sta rvs_flag
   beq cin1

+  ldx #15
-  cmp color_table,x
   beq +
   dex
   bpl -
   bmi cin1

+  txa
   sta color
   bpl cin1

cin3 = *

   lda #0
   sta flash
   ldx #<inter
   ldy #>inter
   jsr setirq

;
;Home cursor
;

home = *

   lda #0
   sta xpos
   sta ypos

loop = *

   jsr put_cursor

wait = *

   lda play_flag
   beq +
   lda p$status
   bne +
   lda p$error
   bne +
   jsr remove_cursor
   jmp restart_sid
+  jsr getin
   beq wait
   pha
   jsr remove_cursor
   pla
   jsr ascii_to_rom
   bcs special_key
   ldy xpos
   ora rvs_flag
   sta (line),y
   lda color
   sta (cline),y
   jsr modify

cright inc xpos
   lda xpos
   cmp #32
   bcc loop
   lda #0
   sta xpos
   inc ypos
   lda ypos
   cmp #5
   bcc loop
   lda #0
   sta ypos
   bne loop

special_key = *

   ldx #15
-  cmp color_table,x
   bne +
   txa
   sta color
   bpl loop
+  dex
   bpl -

   ldx #cmd_key1-cmd_key-1
-  cmp cmd_key,x
   beq +
   dex
   bpl -
   jmp loop

+  txa
   asl
   tax
   lda cmd_vec+1,x
   pha
   lda cmd_vec,x
   pha
   rts

;
;Command keys and dispatch vectors
;

cmd_key     .byte 29,29+128,17+128,17,13,18,18+128,3,135,19,147,136,138
            .byte 140,134,20,148,137,133,16
cmd_key1    = *

cmd_vec     .word cright-1,cleft-1,cup-1,cdown-1,cret-1,rvs_on-1,rvs_off-1
            .word cancel-1,cancel-1,home-1,cclr-1,paint-1,invert-1
            .word invert_c-1,center_line-1,edel-1,eins-1
            .word insline-1,delline-1,play_toggle-1

;
;Handle cursor movements
;

cleft dec xpos
   bpl +
   lda #31
   sta xpos
   dec ypos
   bpl +
   lda #4
   sta ypos
+  jmp loop

cup dec ypos
   bpl +
   lda #4
   sta ypos
+  jmp loop

cdown ldy ypos
   iny
   cpy #5
   bcc +
   ldy #0
+  sty ypos
   jmp loop

;
;Carriage return
;

cret lda #0
   sta xpos
   sta rvs_flag
   jmp cdown

;
;Reverse on/off
;

rvs_on lda #128
   .byte $2c
rvs_off lda #0
   sta rvs_flag
   jmp loop

;
;Return to main program
;

cancel = *

   lda play_flag
   beq +
   lda #0
   sta play_flag
   jsr drop_play
+  jsr convert_back
   lsr mod_flag
   jmp (return_vec)

;
;Clear edit area.
;

cclr = *

   ldx #yy+3
-  txa
   jsr printchar
   jsr print
   .byte xx+4,tab,36,eot
   inx
   cpx #yy+8
   bcc -
   jsr modify
   jmp home

;
;"Paint" entire line in current color
;

paint_proc = *

   ldy #31
   lda color
-  sta (cline),y
   dey
   bpl -
   rts

paint jsr paint_proc
   jsr modify
   jmp loop

;
;Reverse entire line, affecting color.
;

invert_c jsr paint_proc

;
;Reverse entire line, not affecting color.
;

invert = *

   ldy #31
-  lda (line),y
   eor #128
   sta (line),y
   dey
   bpl -
   jsr modify
   jmp loop

;
;Center current line
;

center_line = *

   ldy #0
-  lda (line),y
   cmp #32
   bne +
   iny
   cpy #32
   bcc -
   jmp loop

+  ldx #0
-  lda (line),y
   sta linebuf,x
   lda (cline),y
   sta clinebuf,x
   inx
   iny
   cpy #32
   bcc -

   lda #32
-  dex
   bmi +
   cmp linebuf,x
   beq -
+  inx
   stx ptr

+  lda #33
   sec
   sbc ptr
   lsr
   sta ptr+1

   ldy #0
   lda #32
-  cpy ptr+1
   bcs +
   sta (line),y
   iny
   bne -

+  ldx #0
-  cpx ptr
   bcs +
   lda linebuf,x
   sta (line),y
   lda clinebuf,x
   sta (cline),y
   iny
   inx
   bne -

+  lda #32
-  cpy #32
   bcs +
   sta (line),y
   iny
   bne -

+  jsr modify
   jmp loop

;
;Delete a character
;

edel jsr modify
   ldy xpos
   beq cdel2
edel0 cpy #32
   bcs +
   lda (line),y
   dey
   sta (line),y
   iny
   lda (cline),y
   dey
   sta (cline),y
   iny
   iny
   bne edel0
/  lda #32
   dey
   sta (line),y
   dec xpos
cdel1 jmp loop
cdel2 dec ypos
   bpl +
   lda #4
   sta ypos
+  jsr calc_line
   ldy #32
   sty xpos
   bne -

;
;Insert a character
;

eins ldy #31
   lda (line),y
   cmp #32
   bne cdel1
   ldy xpos
   dey
   sty ptr
   ldy #30
-  cpy ptr
   beq +
   lda (line),y
   iny
   sta (line),y
   dey
   lda (cline),y
   iny
   sta (cline),y
   dey
   dey
   bpl -
+  lda #32
   iny
   sta (line),y
   jsr modify
jloop jmp loop

;
;Insert a line
;

insline ldy #31
-  lda screen+284,y
   cmp #32
   bne jloop
   dey
   bpl -

   lda #<screen+284
   sta ps1
   sta pc1
   lda #>screen+284
   sta ps1+1
   lda #>$d800+284
   sta pc1+1
   lda #<screen+244
   sta ps2
   sta pc2
   lda #>screen+244
   sta ps2+1
   lda #>$d800+244
   sta pc2+1

   ldx #4
il1 cpx ypos
   beq il2
   ldy #31
-  lda (ps2),y
   sta (ps1),y
   lda (pc2),y
   sta (pc1),y
   dey
   bpl -
   lda ps1
   sec
   sbc #40
   sta ps1
   sta pc1
   bcs +
   dec ps1+1
   dec pc1+1
+  lda ps2
   sec
   sbc #40
   sta ps2
   sta pc2
   bcs +
   dec ps2+1
   dec pc2+1
+  dex
   bpl il1

il2 ldy #31
   lda #32
-  sta (ps1),y
   dey
   bpl -
   jsr modify
   jmp loop

;
;Delete a line
;

delline lda line
   sta ps1
   sta pc1
   clc
   adc #40
   sta ps2
   sta pc2
   lda line+1
   sta ps1+1
   adc #0
   sta ps2+1
   sec
   sbc #$1c
   sta pc2+1
   lda cline+1
   sta pc1+1
dl1 lda ps1
   cmp #<screen+284
   bne +
   lda ps1+1
   cmp #>screen+284
   bcs dl9
+  ldy #31
-  lda (ps2),y
   sta (ps1),y
   lda (pc2),y
   sta (pc1),y
   dey
   bpl -
   lda ps1
   clc
   adc #40
   sta ps1
   sta pc1
   bcc +
   inc ps1+1
   inc pc1+1
+  lda ps2
   clc
   adc #40
   sta ps2
   sta pc2
   bcc +
   inc ps2+1
   inc pc2+1
+  jmp dl1
dl9 ldy #31
   lda #32
-  sta (ps1),y
   dey
   bpl -
   jsr modify
   jmp loop

;
;Set modify flag
;

modify lda #1
   sta mod_flag
   rts

;
;Initialize pointers for conversion.
;

init_for_convert = *

   jsr reset
   lda #<screen+124-40
   sta line
   sta cline
   lda #>screen+124-40
   sta line+1
   lda #$d8
   sta cline+1
   rts

;
;Go to next line
;

next_line = *

   lda line
   clc
   adc #40
   sta line
   sta cline
   bcc +
   inc line+1
   inc cline+1
+  rts

;
;--- Convert back to ASCII codes ---
;

convert_back = *

   jsr init_for_convert
   lda #255
   sta color

   lda #5
   sta ps1

cb1 = *

   jsr next_line

   ldy #32
   lda #32
-  dey
   bmi +
   cmp (line),y
   beq -
+  iny
   beq justret
   sty pc1

   lda #255
   sta rvs_flag

   ldy #0
-  lda (line),y
   cmp #32
   beq skipsp

   lda (cline),y
   and #15
   cmp color
   beq +
   sta color
   tax
   lda color_table,x
   jsr send_byte

skipsp = *

+  lda (line),y
   and #128
   cmp rvs_flag
   beq ++
   sta rvs_flag
   cmp #128
   bne +
   lda #18
   .byte $2c
+  lda #18+128
   jsr send_byte

+  lda (line),y
   and #127
   jsr rom_to_ascii
   jsr send_byte

   iny
   cpy pc1
   bcc -

justret lda #13
   jsr send_byte

   dec ps1
   bne cb1
   lda #0
   jmp send_byte

;
;Toggle play mode
;

play_toggle = *

   lda play_flag
   beq restart_sid
   lda #0
   sta play_flag
   jsr drop_play
   jmp loop

restart_sid = *

+  ldy #10
   ldx #5
-  lda voice_start,y
   sta p$musicl,x
   lda voice_start+1,y
   sta p$musich,x
   lda #1
   sta p$enable,x
   dey
   dey
   dex
   bpl -

   lda stereo_mode
   beq +
   clc
   adc #$dd
   sta p$address
   lda expand_value
   sta p$expand

   ldx #<midi_channel
   ldy #>midi_channel
   jsr init_play

   lda #63
   ldx stereo_mode
   bne ++
   ldx route
   bne +
   lda #7
   bne ++
+  lda #%00111000
+  sta p$status
   lda #0
   sta p$mode
   lda #1
   sta play_flag
   jmp loop
