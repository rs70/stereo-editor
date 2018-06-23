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

;This source file contains code for the SID Editor's "Words File Editor"
;transient application. Transient applications load at $C000. If SID data
;reside that high, they are moved down, overwriting the player module.
;Transient applictions may use only the memory between $C000 and $CFFF, and
;zero page locations 100-131. Return with carry set ONLY if sid file needs
;to be saved after this application.
;

   .org $c000
   .obj "009"

;
;Interface storage
;

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

ascii_buf = $cf00
linebuf  =  $cf80
line_buf =  linebuf
clinebuf =  $cfc0
cline_buf = clinebuf

;
;Zero-page pointers
;

ptr              = zp            ;General-use pointer
topptr           = zp+2          ;Address of line displayed at top of window
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
txtptr           = zp+21         ;Pointer to current line
endptr           = zp+23         ;Pointer to end of words data
mod_flag         = zp+25         ;1=modified, 0=not
line_count       = zp+26         ;Number of lines left to display
tx               = zp+27         ;Temporary storage
color_t          = zp+28         ;Temporary color storage
rvs_t            = zp+29         ;Temporary reverse mode storage
line_len         = zp+30         ;Length of current line (ASCII)
new_len          = zp+31         ;Length of replacement line (ASCII)
maxptr           = zp+32         ;Points to start of SID data.

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
   .byte 009 ;File number
   .word init ;Starting address
return_vec .word $ffff ;Filled in by main program - Return location

;
;Special interrupt routine for cursor flashing
;

inter = *

   lda flash
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
;Convert any ASCII code to its corresponding ROM code.
;Return with carry set only if it's non-printable
;

ascii_to_rom = *

   cmp #160
   beq sub128
   cmp #32
   bcc non_printable
   cmp #96
   bcc sub0
   cmp #128
   bcc sub32
   cmp #160
   bcc non_printable
   cmp #192
   bcc sub64
   cmp #255
   bcc sub192
   lda #94
   clc
   rts
sub192 sbc #191
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
   bcc add192
   cmp #64
   bcc add0
   cmp #96
   bcc add0
   bcs add64
add128 clc
   adc #64
add64 clc
   adc #64
add0 rts
add192 adc #192
   rts
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

   ldx #1
   ldy ypos
   iny
   iny
   iny
   jsr get_adr
   lda colptr
   sta cline
   lda colptr+1
   sta cline+1
   lda k_txtptr
   sta line
   lda k_txtptr+1
   sta line+1
   rts

;
;Table of screen color changing ASCII codes.
;

color_table    .byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154
               .byte 155

;
;Grab and convert line at TXTPTR.
;

grab_line = *

   jsr txt_2_ptr
   jsr convert_line
   sty line_len
   rts

;
;Convert ASCII line pointed to by PTR to character and color codes in
;LINE_BUF and CLINE_BUF.
;

convert_line = *

   lda #7
   sta ps1
   lda #0
   sta ps2
   tax
   ldy #255

cin1 = *

   iny
   lda (ptr),y
   beq cin3
   jsr ascii_to_rom
   bcs cin2
   ora ps2
   sta line_buf,x
   lda ps1
   sta cline_buf,x
   inx
   bne cin1

cin2 = *

   cmp #13
   beq eoln

   cmp #18
   bne +
   lda #128
   sta ps2
   bne cin1

+  cmp #18+128
   bne +
   lda #0
   sta ps2
   beq cin1

+  stx tx
   ldx #15
-  cmp color_table,x
   beq +
   dex
   bpl -
   ldx tx
   bpl cin1

+  stx ps1
   ldx tx
   bpl cin1

eoln = *

   iny

cin3 = *

-  cpx #38
   bcs +
   lda #32
   sta line_buf,x
   lda ps1
   sta cline_buf,x
   inx
   bne -

+  rts

;
;Display current 12 lines of text.
;

disp_lines = *

   lda #<40*3+screen+1
   sta line
   sta cline
   lda #>40*3+screen+1
   sta line+1
   lda #>40*3+55297
   sta cline+1

   lda topptr
   sta ptr
   lda topptr+1
   sta ptr+1
   lda #12
   sta line_count
-  jsr convert_line
   tya
   clc
   adc ptr
   sta ptr
   bcc +
   inc ptr+1
+  ldy #37
-  lda line_buf,y
   sta (line),y
   lda cline_buf,y
   sta (cline),y
   dey
   bpl -
   lda line
   clc
   adc #40
   sta line
   sta cline
   bcc +
   inc line+1
   inc cline+1
+  dec line_count
   bne --
   rts

;
;----- Main Program -----
;

init = *

   jsr print
   .byte clr,xx+14,yy+0,col+1
   .asc "Words Editor"
   .byte box,0,2,39,15,11
   .byte eot
   jsr help

   lda #0
   sta mod_flag
   sta flash
   sta rvs_flag
   ldx #<inter
   ldy #>inter
   jsr setirq

   lda #1
   sta color

   jsr move_out

;
;Home cursor
;

home = *

   lda #<start_heap
   sta topptr
   sta txtptr
   lda #>start_heap
   sta topptr+1
   sta txtptr+1
   jsr disp_lines
   jsr grab_line

   lda #0
   sta xpos
   sta ypos

loop = *

   jsr put_cursor

wait = *

   jsr getin
   beq wait
   pha
   jsr remove_cursor
   pla
   jsr key_to_rom
   bcs special_key
   ldy xpos
   ora rvs_flag
   sta (line),y
   lda color
   sta (cline),y
   sta cline_buf,y
   jsr modify

cright inc xpos
   lda xpos
   cmp #38
   bcc loop
   lda #37
   sta xpos
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
            .byte 140,134,20,148,133,137,139,147
cmd_key1    = *

cmd_vec     .word cright-1,cleft-1,cup-1,cdown-1,cret-1,rvs_on-1,rvs_off-1
            .word cancel-1,cancel-1,home-1,cclr-1,paint-1,invert-1
            .word invert_c-1,center_line-1,edel-1,eins-1
            .word del_line-1,ins_line-1,end_of_line-1,clear_all-1

;
;Handle cursor movements
;

cleft lda xpos
   beq +
   dec xpos
+  jmp loop

;
;Cursor up
;

cup dec ypos
   bpl ju
   inc ypos
   jsr top_2_ptr
   jsr find_last
   jsr ptr_2_top
   jsr txt_2_ptr
   jsr find_last
   jsr ptr_2_txt
   jsr disp_lines
   jmp jq
ju jsr txt_2_ptr
   jsr find_last
   jsr ptr_2_txt
jq jsr grab_line
   jmp loop

;
;Cursor down
;

cdown ldy #0
   lda (txtptr),y
   beq jm
   inc ypos
   lda ypos
   cmp #12
   bcc jl
   dec ypos
   jsr txt_2_ptr
   jsr find_next
   jsr ptr_2_txt
   jsr top_2_ptr
   jsr find_next
   jsr ptr_2_top
   jsr disp_lines
   jmp jq
jl jsr txt_2_ptr
   jsr find_next
   jsr ptr_2_txt
jm jmp jq

;
;Carriage return
;

cret ldy #0
   lda (txtptr),y
   bne +
   jsr insert_line
+  lda #0
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

   jsr move_back
   lsr mod_flag
   jmp (return_vec)

;
;Clear all words.
;

cclr = *

   jmp home

;
;"Paint" entire line in current color
;

paint_proc = *

   ldy #37
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

   ldy #37
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
   cpy #38
   bcc -
   jmp loop

+  ldx #0
-  lda (line),y
   sta linebuf,x
   lda (cline),y
   sta clinebuf,x
   inx
   iny
   cpy #38
   bcc -

   lda #32
-  dex
   bmi +
   cmp linebuf,x
   beq -
+  inx
   stx ptr

+  lda #39
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
-  cpy #38
   bcs +
   sta (line),y
   iny
   bne -

+  jsr modify
   jmp loop

;
;Delete a character
;

edel ldy xpos
   beq edel1
edel0 cpy #38
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
+  lda #32
   dey
   sta (line),y
   dec xpos
edel1 jsr modify
   jmp loop

;
;Insert a character
;

eins ldy #37
   lda (line),y
   cmp #32
   bne edel1
   ldy xpos
   dey
   sty ptr
   ldy #36
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
;Given PTR is a pointer to a line, find next line and return it in PTR.
;

find_next = *

   ldy #0
-  lda (ptr),y
   cmp #13
   beq +
   iny
   bne -
+  iny
   tya
   clc
   adc ptr
   sta ptr
   bcc +
   inc ptr+1
+  rts

;
;Given PTR is a pointer to a line, find previous line and return it in PTR.
;

find_last = *

   lda ptr+1
   cmp #>start_heap
   bne +
   lda ptr
   cmp #<start_heap
+  beq fl
   lda ptr
   bne +
   dec ptr+1
+  dec ptr

   ldy #0
-  lda ptr
   cmp #<start_heap
   bne +
   lda ptr+1
   cmp #>start_heap
   beq fl
+  lda ptr
   bne +
   dec ptr+1
+  dec ptr
   lda (ptr),y
   cmp #13
   bne -
   inc ptr
   bne fl
   inc ptr+1
fl rts

;
;Copy TXT_PTR to PTR
;

txt_2_ptr = *

   lda txtptr
   sta ptr
   lda txtptr+1
   sta ptr+1
   rts

;
;Copy PTR to TXT_PTR
;

ptr_2_txt = *

   lda ptr
   sta txtptr
   lda ptr+1
   sta txtptr+1
   rts

;
;Copy TOP_PTR to PTR
;

top_2_ptr = *

   lda topptr
   sta ptr
   lda topptr+1
   sta ptr+1
   rts

;
;Copy PTR to TOP_PTR
;

ptr_2_top = *

   lda ptr
   sta topptr
   lda ptr+1
   sta topptr+1
   rts

;
;Convert current line back to ASCII (in ASCII_BUF).
;

convert_back = *

   lda #255
   sta color_t
   sta rvs_t
   ldx #0

cb1 = *

   ldy #38
   lda #32
-  dey
   bmi +
   cmp (line),y
   beq -
+  iny
   beq justret
   sty ps1+1

   ldy #0
-  lda (line),y
   cmp #32
   beq skipsp

   lda (cline),y
   and #15
   cmp color_t
   beq +
   sta color_t
   stx ps1
   tax
   lda color_table,x
   ldx ps1
   sta ascii_buf,x
   inx

skipsp = *

+  lda (line),y
   and #128
   cmp rvs_t
   beq ++
   sta rvs_t
   cmp #128
   bne +
   lda #18
   .byte $2c
+  lda #18+128
   sta ascii_buf,x
   inx

+  lda (line),y
   and #127
   jsr rom_to_ascii
   sta ascii_buf,x
   inx

   iny
   cpy ps1+1
   bcc -

justret lda #13
   sta ascii_buf,x
   inx

   rts

;
;Set modify flag and replace line in memory.
;

modify lda #1
   sta mod_flag

;
;Replace current line in memory.
;

put_line = *

   jsr convert_back
   stx new_len
   txa
   sec
   sbc line_len
   bne pl2

replace ldy #0
-  cpy new_len
   bcs +
   lda ascii_buf,y
   sta (txtptr),y
   iny
   bne -
+  sty line_len
   rts

pl2 bcs pl3

   lda line_len
   sec
   sbc new_len
   sta ps1

   lda txtptr
   sta dest_m
   clc
   adc ps1
   sta start_m
   lda txtptr+1
   sta dest_m+1
   adc #0
   sta start_m+1
   jsr usual_end
   jsr move_down
   lda endptr
   sec
   sbc ps1
   sta endptr
   bcs +
   dec endptr+1
+  jmp replace

pl3 sta ps1
   lda txtptr
   sta start_m
   clc
   adc ps1
   sta dest_m
   lda txtptr+1
   sta start_m+1
   adc #0
   sta dest_m+1
   jsr usual_end
   ldy endptr+1
   lda endptr
   clc
   adc ps1
   bcc +
   iny
+  cpy maxptr+1
   bcs hit_max
   sta endptr
   sty endptr+1
   jsr move_up
   jmp replace

hit_max = *

   jsr disp_lines
   jmp jq

;
;Translate ASCII keypress to character code. Return with carry set
;only if it's a control code or unimplemented character.
;

key_to_rom = *

   cmp #32
   bcc unimp
   cmp #64
   bcc ksub0
   cmp #96
   bcc ksub64
   cmp #193
   bcc unimp
   cmp #193+26
   bcs unimp
   sbc #63
ksub64 sec
   sbc #64
ksub0 clc
   rts
unimp sec
   rts

;
;Set END_M to ENDPTR.
;

usual_end = *

   lda endptr
   sta end_m
   lda endptr+1
   sta end_m+1
   rts

;
;Move SID data out of way, put a zero at end of word data if necessary.
;

move_out = *

   lda voice_start+12
   sta end_m
   sec
   sbc voice_start
   sta ptr
   lda voice_start+13
   sta end_m+1
   sbc voice_start+1
   sta ptr+1

   lda #<end_heap
   sec
   sbc ptr
   sta dest_m
   sta maxptr
   lda #>end_heap
   sbc ptr+1
   sta dest_m+1
   sta maxptr+1
   lda voice_start
   sta start_m
   sta endptr
   lda voice_start+1
   sta start_m+1
   sta endptr+1
   lda dest_m
   sec
   sbc start_m
   sta ptr
   lda dest_m+1
   sbc start_m+1
   sta ptr+1
   jsr move_up

   ldx #12
-  lda voice_start,x
   clc
   adc ptr
   sta voice_start,x
   lda voice_start+1,x
   adc ptr+1
   sta voice_start+1,x
   lda voice_end,x
   clc
   adc ptr
   sta voice_end,x
   lda voice_end+1,x
   adc ptr+1
   sta voice_end+1,x
   lda voice_pos,x
   clc
   adc ptr
   sta voice_pos,x
   lda voice_pos+1,x
   adc ptr+1
   sta voice_pos+1,x
   dex
   dex
   bpl -

   lda endptr+1
   cmp #>start_heap
   bne +
   lda endptr
   cmp #<start_heap
   bne +
   lda #0
   sta start_heap
   inc endptr
   bne +
   inc endptr+1
+  rts

;
;Move SID data back prior to exiting.
;

move_back = *

   lda endptr
   cmp #<start_heap+1
   bne +
   lda endptr+1
   cmp #>start_heap+1
   bne +
   lda #<start_heap
   sta endptr
   lda #>start_heap
   sta endptr+1

+  lda endptr
   sta dest_m
   lda endptr+1
   sta dest_m+1
   lda maxptr
   sta start_m
   lda maxptr+1
   sta start_m+1
   lda #<end_heap
   sta end_m
   lda #>end_heap
   sta end_m+1
   lda start_m
   sec
   sbc dest_m
   sta ptr
   lda start_m+1
   sbc dest_m+1
   sta ptr+1
   jsr move_down

   ldx #12
-  lda voice_start,x
   sec
   sbc ptr
   sta voice_start,x
   lda voice_start+1,x
   sbc ptr+1
   sta voice_start+1,x
   lda voice_end,x
   sec
   sbc ptr
   sta voice_end,x
   lda voice_end+1,x
   sbc ptr+1
   sta voice_end+1,x
   lda voice_pos,x
   sec
   sbc ptr
   sta voice_pos,x
   lda voice_pos+1,x
   sbc ptr+1
   sta voice_pos+1,x
   dex
   dex
   bpl -

   rts

;
;Delete current line.
;

del_line = *

   ldy #0
   lda (txtptr),y
   bne +
   jmp loop
+  lda txtptr
   sta dest_m
   clc
   adc line_len
   sta start_m
   lda txtptr+1
   sta dest_m+1
   adc #0
   sta start_m+1
   jsr usual_end
   jsr move_down

   lda endptr
   sec
   sbc line_len
   sta endptr
   bcs +
   dec endptr+1
+  lda #1
   sta mod_flag
   jsr disp_lines
   jmp jq

;
;Insert current line.
;

ins_line = *

   jsr insert_line
   jsr disp_lines
   jmp jq

;
;Insert current line - subroutine.
;

insert_line = *

   lda txtptr
   sta start_m
   clc
   adc #1
   sta dest_m
   lda txtptr+1
   sta start_m+1
   adc #0
   sta dest_m+1
   jsr usual_end
   jsr move_up
   lda #1
   sta mod_flag

   ldy #0
   lda #13
   sta (txtptr),y

   ldy endptr+1
   ldx endptr
   inx
   bne +
   iny
+  cpy maxptr+1
   bcs +
   sty endptr+1
   stx endptr
   rts

+  jmp hit_max

;
;Display instructions at bottom of screen.
;

help = *

   jsr print
   .byte xx+1,yy+17,col+7,"[",col+15
   .asc "F1"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "Delete Line"

   .byte xx+20,col+7,"[",col+15
   .asc "F2"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "Insert Line"

   .byte 13,xx+1,col+7,"[",col+15
   .asc "F3"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "Center Line"

   .byte xx+20,col+7,"[",col+15
   .asc "F4"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "Invert Line"

   .byte 13,xx+1,col+7,"[",col+15
   .asc "F5"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "Exit"

   .byte xx+20,col+7,"[",col+15
   .asc "F6"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "End of Line"

   .byte 13,xx+1,col+7,"[",col+15
   .asc "F7"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "Paint Line"

   .byte xx+20,col+7,"[",col+15
   .asc "F8"
   .byte col+7,"]",col+11," ","-"," ",col+12
   .asc "Paint/Invert"

   .byte eot
   rts

;
;Go to end of current line.
;

end_of_line = *

   ldy #38
   lda #32
-  dey
   bmi +
   cmp (line),y
   beq -
   cpy #37
   bcs ++
+  iny
+  sty xpos
   jmp loop

;
;Clear entire document
;

clear_all = *

   jsr print
   .byte xx+1,yy+22,col+15
   .asc "Clear all: Are you sure (Y/N)?"
   .byte eot

-  jsr getin
   beq -
   pha
   jsr print
   .byte xx+0,yy+22,tab,40,eot
   pla

   cmp #"y"
   beq +
   jmp loop

+  lda #0
   sta start_heap
   lda #<start_heap+1
   sta endptr
   lda #>start_heap+1
   sta endptr+1
   lda #1
   sta mod_flag
   jmp home
