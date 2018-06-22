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

; This module is loaded in when the booter program is unable to verify the
; presence of the Enhanced Sidplayer module. It gives ordering information
; and copies the "SID.OBJ.64" from the Enhanced Sidplayer disk to the Stereo
; Editor disk, under filename "010".

   .org $6000
   .obj "011"

;-- Kernal interface --

txtptr           = $02
start_m          = $04
end_m            = $06
dest_m           = $08

;-- Bank switching --

bank_0         = $ff01
bank_1         = $ff02
bank_k         = $ff03

;-- New Kernal routines --

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
reset_keys    = $e09c
change_keys   = $e09f
print_error   = $e0a2
exit_irq      = $e0a5
init_kernal   = $e0a8

;-- Constants for screen print routine --

eof           = 1              ;End of field
def           = 2              ;Define a field
tab           = 3              ;Destructive
rvs           = 4              ;Reverse mode on
rvsoff        = 5              ;Reverse mode off
defl          = 6              ;Non-justified field
defr          = 7              ;Right-justified field
clr           = 8              ;Clear entire screen
fkey          = 10             ;Print function key names
box           = 12             ;Define a screen window
xx            = 96             ;80 values to set X-coordinate
col           = 176            ;16 values to set color
yy            = 224            ;25 values to set Y-coordinate
eot           = 255            ;End of text for print

;-- Constants for menu creation --

dispatch      = 1              ;Dispatch to this item with no RTS on stack
service       = 2              ;Call service routine with RTS on stack
numeric       = 3              ;Auto-service numeric value
string        = 4              ;Auto-service strings
null_item     = 5              ;Not a serviceable item
eom           = 0              ;End of menu definition

;-- Display initial screen --

restart = *

   jsr print
   .byte box,3,4,37,20,14,col+1,xx+5,yy+6
   .asc "In order to use the Stereo"
   .byte xx+5,yy+7
   .asc "Editor, you must possess a copy"
   .byte xx+5,yy+8
   .asc "of the book/disk combination"
   .byte xx+5,yy+9,34
   .asc "Compute!'s Music System for"
   .byte xx+5,yy+10
   .asc "the Commodore 128 and 64: The"
   .byte xx+5,yy+11
   .asc "Enhanced Sidplayer"
   .byte 34,".",xx+5,yy+13
   .asc "Please insert the C-64 side of"
   .byte xx+5,yy+14
   .asc "your Enhanced Sidplayer disk"
   .byte xx+5,yy+15
   .asc "to verify that you possess it."
   .byte eot

   jsr menudef
   .byte 0,128+15,2
   .word 0,0,0,0
   .byte dispatch,12,17,16
   .word continue
   .asc "Continue"
   .byte dispatch,12,18,16
   .word more_info
   .asc "More Information"
   .byte eom
   jmp select_0

;
;Perform the copy operation
;

continue = *

   jsr clear_screen
   jsr init_drive

   lda #15
   ldx $ba
   ldy #15
   jsr setlfs
   lda #0
   jsr setnam
   jsr open

   lda #1
   ldx $ba
   ldy #0
   jsr setlfs
   lda #orig_file1-orig_file
   ldx #<orig_file
   ldy #>orig_file
   jsr setnam
   jsr open
   jsr read_error
   cmp #20
   bcc +
   jmp wrong_disk
+  ldx #1
   jsr chkin
   ldy #0
-  jsr chrin
   sta $c000,y
   iny
   bne -
-  jsr chrin
   sta $c100,y
   iny
   bne -

;-- Read some extra bytes until end of file, but do nothing with them. ;D --

-  jsr chrin
   lda $90
   beq -

;-- Close files --

   jsr clrchn
   lda #1
   jsr close

;-- Is it really the correct file? --

   ldy #5
-  lda $c162,y
   cmp sequence,y
   beq +
   jmp wrong_disk
+  dey
   bpl -

;-- Yes, so Prompt for insertion of Stereo Editor disk --

   jsr print
   .byte box,8,9,31,16,14,col+1,xx+10,yy+11
   .asc "Please reinsert your"
   .byte xx+10,yy+12
   .asc "Stereo Editor disk."
   .byte xx+10,yy+14
   .asc "Press RETURN."
   .byte eot

-  jsr getin
   cmp #13
   bne -

;
;Scratch any existence of 010 file.
;

   jsr clear_screen

   ldx #15
   jsr chkout
   ldy #0
-  lda scratch_new,y
   jsr chrout
   iny
   cpy #new_file1-scratch_new
   bcc -
   jsr clrchn

;
;Rewrite 500 bytes of SID.OBJ.64 file as 010
;

   lda #1
   ldx $ba
   ldy #1
   jsr setlfs
   lda #new_file1-new_file
   ldx #<new_file
   ldy #>new_file
   jsr setnam
   jsr open

   ldx #1
   jsr chkout
   ldy #0
-  lda $c000,y
   jsr chrout
   iny
   bne -
-  lda $c100,y
   jsr chrout
   iny
   cpy #256-12
   bne -

   jsr clrchn
   lda #1
   jsr close
   lda #15
   jsr close

;
;Return to main booter program
;

   rts

;
;Filenames used
;

orig_file     .asc "sid.obj.64"
orig_file1    = *

scratch_new   .asc "s0:"
new_file      .asc "010"
new_file1     = *

;
;Not a Sidplayer disk
;

wrong_disk = *

   jsr clrchn
   lda #1
   jsr close
   lda #15
   jsr close
   jsr print
   .byte box,7,8,33,17,14,xx+9,yy+10,col+1
   .asc "This is not an Enhanced"
   .byte xx+9,yy+11
   .asc "Sidplayer disk. Please"
   .byte xx+9,yy+12
   .asc "check disk."
   .byte eot

   jsr menudef
   .byte 0,15+128,2
   .word 0,0,0,0
   .byte dispatch,13,14,16
   .word continue
   .asc "Try Again"
   .byte dispatch,13,15,16
   .word more_info
   .asc "More Information"
   .byte eom
   jmp select_0

;
;Give user more information.
;

more_info = *

   jsr print
   .byte box,0,0,39,24,14,xx+2,yy+2,col+1
   .asc "The original Enhanced Sidplayer"
   .byte xx+2,yy+3
   .asc "program, developed by Craig"
   .byte xx+2,yy+4
   .asc "Chamberlain, is the most powerful"
   .byte xx+2,yy+5
   .asc "and user-friendly music composition"
   .byte xx+2,yy+6
   .asc "tool for the Commodore 128 and 64."
   .byte xx+2,yy+7
   .asc "Not only is the program excellent,"
   .byte xx+2,yy+8
   .asc "the book makes complex topics in"
   .byte xx+2,yy+9
   .asc "music theory easy for the beginner,"
   .byte xx+2,yy+10
   .asc "so that even those without a musical"
   .byte xx+2,yy+11
   .asc "background can make effective and"
   .byte xx+2,yy+12
   .asc "creative use of the system."
   .byte xx+2,yy+14
   .asc "It is the desire of all involved"
   .byte xx+2,yy+15
   .asc "with the Stereo Editor project that"
   .byte xx+2,yy+16
   .asc "Chamberlain continue to be rewarded"
   .byte xx+2,yy+17
   .asc "for his work. For this reason, the"
   .byte xx+2,yy+18
   .asc "Stereo Editor's player was designed"
   .byte xx+2,yy+19
   .asc "as an extension of the stand-alone"
   .byte xx+2,yy+20
   .asc "player provided with the book/disk."
   .byte def,38,1,22,1
   .asc "<PRESS RETURN TO CONTINUE>
   .byte eof,eot

-  jsr getin
   cmp #13
   bne -

   jsr print
   .byte box,0,0,39,24,14,xx+2,yy+2,col+1
   .asc "The stand-alone player module will"
   .byte xx+2,yy+3
   .asc "be loaded automatically with Stereo"
   .byte xx+2,yy+4
   .asc "Editor, but it is NOT provided with
   .byte xx+2,yy+5
   .asc "this utility; you MUST have the"
   .byte xx+2,yy+6
   .asc "Enhanced Sidplayer system. This"
   .byte xx+2,yy+7
   .asc "program simply copies that file to"
   .byte xx+2,yy+8
   .asc "your Stereo Editor disk."
   .byte xx+2,yy+10
   .asc "If you distribute SE, copy it "
   .byte col+7,"B","E","F","O","R","E",col+1,xx+2,yy+11
   .asc "the verification process; once"
   .byte xx+2,yy+12
   .asc "that has taken place, your Stereo"
   .byte xx+2,yy+13
   .asc "Editor disk is "
   .byte col+10
   .asc "NO LONGER PUBLIC"
   .byte xx+2,yy+14
   .asc "DOMAIN "
   .byte col+1
   .asc "and may not be distributed"
   .byte xx+2,yy+15
   .asc "to anyone who does not own a copy"
   .byte xx+2,yy+16
   .asc "of the Compute! book/disk product."
   .byte xx+2,yy+18
   .asc "The 'unvalidate' program on this"
   .byte xx+2,yy+19
   .asc "disk may be used to restore a copy"
   .byte xx+2,yy+20
   .asc "of the verified disk to PD status."
   .byte def,38,1,22,1
   .asc "<PRESS RETURN TO CONTINUE>
   .byte eof,eot

-  jsr getin
   cmp #13
   bne -

   jsr print
   .byte box,0,0,39,24,14,xx+2,yy+2,col+1
   .asc "If you do not possess Compute!'s"
   .byte xx+2,yy+3
   .asc "Music System, you might be able to"
   .byte xx+2,yy+4
   .asc "find a copy at your local bookstore."
   .byte xx+2,yy+5
   .asc "The book/disk combination, which"
   .byte xx+2,yy+6
   .asc "retails for $24.95, can be purchased"
   .byte xx+2,yy+7
   .asc "from Dr. Evil Laboratories for the"
   .byte xx+2,yy+8
   .asc "discounted price of $22.95 (plus"
   .byte xx+2,yy+9
   .asc "$2.40 for first class mail or $1.25"
   .byte xx+2,yy+10
   .asc "for book rate mail)."
   .byte xx+2,yy+12
   .asc "Send your check or money order,"
   .byte xx+2,yy+13
   .asc "payable to Dr. Evil Labs, to:"
   .byte xx+5,yy+15,col+15
   .asc "Dr. Evil Laboratories"
   .byte xx+5,yy+16
   .asc "P.O. Box 3432"
   .byte xx+5,yy+17
   .asc "Redmond, WA 98073-3432"
   .byte xx+2,yy+19,col+1
   .asc "Washington State residents MUST add"
   .byte xx+2,yy+20
   .asc "8.1% sales tax ($1.86 per book)."
   .byte def,38,1,22,1
   .asc "<PRESS F5 FOR MENU>
   .byte eof,eot

-  jsr getin
   cmp #135
   bne -

   jmp restart

;-- Sequence of bytes checked for at $0160 offset in Enhanced Sidplayer module.

sequence = *

   .byte $c1,$60,$01,$02,$04,$00
