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

;This source file contains code for the SID Editor's "Key Customizer"
;transient application. Transient applications load at $C000. If SID data
;reside that high, it is moved down, overwriting the player module.
;Transient applictions may use only the memory between $C000 and $CFFF, and
;zero page locations 100-115.

   .org $c000
   .obj "005"

;
;Number of functions
;

num_fun  = 72

fun_value = $5a00

;
;Old Kernal routine equates:
;

k_setlfs = $ffba         ;Set up file
k_setnam = $ffbd         ;Set filename address and length
k_open   = $ffc0         ;Open file
k_close  = $ffc3         ;Close file
k_chkin  = $ffc6         ;Open channel for reading
k_chkout = $ffc9         ;Open channel for writing
k_clrchn = $ffcc         ;Clear channels
k_chrin  = $ffcf         ;Read character from current channel
k_chrout = $ffd2         ;Send character to current channel
k_getin  = $ffe4         ;Get character from current channel

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

;
;Zero-page start of storage equate
;

zp = 100                 ;Start of zero page storage for this module

;
;Zero-page pointers
;

ptr              = zp            ;General-use pointer
key              = zp+2          ;Key pressed (0-63)
len              = zp+3          ;Length of key text
temp             = zp+4          ;A temporary value
topfun           = zp+6          ;Function index of top screen item
botfun           = zp+7          ;Function index of bottom screen item (+1)
index            = zp+8          ;Current screen display position

txtptr           = $e0           ;Kernal interface variable
colptr           = $e2           ;Kernal interface variable

;
;Start of variables for customizer module
;

var              = $cf00

;
;Customizer module variables
;

text             = var

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
   .byte 005 ;File number
   .word init ;Starting address
return_vec .word $ffff ;Filled in by main program - Return location

;
;---- Tables 'n Stuff
;

short_keys     .scr "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_*+,-./:;=@^\"

k0             .scr "HOME"
               .byte eot
k1             .scr "DEL"
               .byte eot
k2             .scr "STOP"
               .byte eot
k3             .scr "RETURN"
               .byte eot
k4             .scr "CRSR DOWN"
               .byte eot
k5             .scr "CRSR UP"
               .byte eot
k6             .scr "CRSR RIGHT"
               .byte eot
k7             .scr "CRSR LEFT"
               .byte eot
k8             .scr "F1"
               .byte eot
k9             .scr "F3"
               .byte eot
k10            .scr "F5"
               .byte eot
k11            .scr "F7"
               .byte eot
k12            .scr "SPACE"
               .byte eot

;
;Pointers to long key names
;

long_vec       .word k0,k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12
 
;
;SHIFT key list
;

s0             .byte eot
s1             .scr "SHIFT-"
               .byte eot
s2             .scr "C= "
               .byte eot
s3             .scr "CTRL-"
               .byte eot

;
;Pointers to shifted names
;

shift_vec      .word s0,s1,s2,s3

;
;List of functions
;

f0             .scr "Move Forward in Voice"
               .byte eot
f1             .scr "Move Backward in Voice"
               .byte eot
f2             .scr "Move to Start of Voice"
               .byte eot
f3             .scr "Move to End of Voice"
               .byte eot
f4             .scr "Move to Next Measure"
               .byte eot
f5             .scr "Move to Last Measure"
               .byte eot
f6             .scr "Go to Next Voice"
               .byte eot
f7             .scr "Go to Previous Voice"
               .byte eot
f8             .scr "Toggle Single/All Voices"
               .byte eot
f9             .scr "Select Rest"
               .byte eot
f10            .scr "Select C Pitch"
               .byte eot
f11            .scr "Select D Pitch"
               .byte eot
f12            .scr "Select E Pitch"
               .byte eot
f13            .scr "Select F Pitch"
               .byte eot
f14            .scr "Select G Pitch"
               .byte eot
f15            .scr "Select A Pitch"
               .byte eot
f16            .scr "Select B Pitch"
               .byte eot
f17            .scr "Select Octave 0"
               .byte eot
f18            .scr "Select Octave 1"
               .byte eot
f19            .scr "Select Octave 2"
               .byte eot
f20            .scr "Select Octave 3"
               .byte eot
f21            .scr "Select Octave 4"
               .byte eot
f22            .scr "Select Octave 5"
               .byte eot
f23            .scr "Select Octave 6"
               .byte eot
f24            .scr "Select Octave 7"
               .byte eot
f25            .scr "Change to Double Flat"
               .byte eot
f26            .scr "Change Pitch to Flat"
               .byte eot
f27            .scr "Reset Pitch to Natural"
               .byte eot
f28            .scr "Change Pitch to Sharp"
               .byte eot
f29            .scr "Change to Double Sharp"
               .byte eot
f30            .scr "Toggle Tied/Untied Note"
               .byte eot
f31            .scr "Enter Current Note"
               .byte eot
f32            .scr "Delete Note/Command"
               .byte eot
f33            .scr "Insert a Space"
               .byte eot
f34            .scr "Select Absolute Duration"
               .byte eot
f35            .scr "Select Utility Duration"
               .byte eot
f36            .scr "Select Whole Note"
               .byte eot
f37            .scr "Select Half Note"
               .byte eot
f38            .scr "Select Quarter Note"
               .byte eot
f39            .scr "Select Eighth Note"
               .byte eot
f40            .scr "Select Sixteenth Note"
               .byte eot
f41            .scr "Select Thirty-Second Note"
               .byte eot
f42            .scr "Select Sixty-Fourth Note"
               .byte eot
f43            .scr "Select Utility Voice"
               .byte eot
f44            .scr "Toggle Triplet"
               .byte eot
f45            .scr "Toggle Single-Dotted Note"
               .byte eot
f46            .scr "Toggle Double-Dotted Note"
               .byte eot
f47            .scr "Call Up Main Menu"
               .byte eot
f48            .scr "Call Up Command Menu"
               .byte eot
f49            .scr "Enter Next Measure Marker"
               .byte eot
f50            .scr "Begin Play: Current Voice"
               .byte eot
f51            .scr "Change Clef for Voice
               .byte eot
f52            .scr "Change Key Signature"
               .byte eot
f53            .scr "Search for Measure"
               .byte eot
f54            .scr "Begin Play: All Voices"
               .byte eot
f55            .scr "Mimic Joystick Up"
               .byte eot
f56            .scr "Mimic Joystick Down"
               .byte eot
f57            .scr "Mimic Joystick Left"
               .byte eot
f58            .scr "Mimic Joystick Right"
               .byte eot
f59            .scr "Command Mode: Next Voice"
               .byte eot
f60            .scr "Command Mode: Last Voice"
               .byte eot
f61            .scr "Command Mode: Move Right"
               .byte eot
f62            .scr "Command Mode: Move Left"
               .byte eot
f63            .scr "Command Mode: Insert"
               .byte eot
f64            .scr "Command Mode: Delete"
               .byte eot
f65            .scr "Command Mode: One/All"
               .byte eot
f66            .scr "Command Search - Forward"
               .byte eot
f67            .scr "Command Search - Back"
               .byte eot
f68            .scr "Move to Command Below"
               .byte eot
f69            .scr "Move to Command Above"
               .byte eot
f70            .scr "Move to Command at Right"
               .byte eot
f71            .scr "Move to Command at Left"
               .byte eot
 
;
;Vectors to function text
;

function_vec   .word f0,f1,f2,f3,f4,f5,f6,f7
               .word f8,f9,f10,f11,f12,f13,f14,f15
               .word f16,f17,f18,f19,f20,f21,f22,f23
               .word f24,f25,f26,f27,f28,f29,f30,f31
               .word f32,f33,f34,f35,f36,f37,f38,f39
               .word f40,f41,f42,f43,f44,f45,f46,f47
               .word f48,f49,f50,f51,f52,f53,f54,f55
               .word f56,f57,f58,f59,f60,f61,f62,f63
               .word f64,f65,f66,f67,f68,f69,f70,f71

;
;ASCII codes to key/shift code table
;(Bits 0-5 : Key number (0-63)
; Bits 6-7 : Shift type (0-3)
;

ascii_list     .byte 0,192+10,192+11,192+12,192+13,192+14,192+15,192+16
               .byte 192+17,192+18,192+19,192+20,192+21,52,192+23,192+24
               .byte 192+25,53,192+27,49,50,192+30,192+31,192+32
               .byte 192+33,192+34,192+35,0,192+3,55,192+6,192+7

               .byte 61,64+1,64+2,64+3,64+4,64+5,64+6,64+7
               .byte 64+8,64+9,37,38,39,40,41,42
               .byte 0,1,2,3,4,5,6,7
               .byte 8,9,43,44,64+39,45,64+41,64+42

               .byte 46,10,11,12,13,14,15,16
               .byte 17,18,19,20,21,22,23,24
               .byte 25,26,27,28,29,30,31,32
               .byte 33,34,35,64+43,48,64+44,47,36

               .byte 64+37,64+10,64+11,64+12,64+13,64+14,64+15,64+16
               .byte 64+17,64+18,64+19,64+20,64+21,64+22,64+23,64+24
               .byte 64+25,64+26,64+27,64+28,64+29,64+30,64+31,64+32
               .byte 64+33,64+34,64+35,64+38,128+40,64+40,64+47,128+37

               .byte 0,128+1,0,0,0,57,58,59
               .byte 60,64+57,64+58,64+59,64+60,64+52,0,0
               .byte 192+1,54,192+0,64+49,64+50,128+2,128+3,128+4
               .byte 128+5,128+6,128+7,128+8,192+5,56,192+8,192+4

               .byte 64+61,128+20,128+18,128+29,128+46,128+16,128+38,128+22
               .byte 128+48,64+48,128+23,128+26,128+13,128+35,128+28,128+25
               .byte 128+10,128+14,128+27,128+32,128+17,128+19,128+21,128+34
               .byte 128+30,128+24,64+46,128+15,128+12,128+33,128+31,128+11

               .byte 64+37,64+10,64+11,64+12,64+13,64+14,64+15,64+16
               .byte 64+17,64+18,64+19,64+20,64+21,64+22,64+23,64+24
               .byte 64+25,64+26,64+27,64+28,64+29,64+30,64+31,64+32
               .byte 64+33,64+34,64+35,64+38,128+40,64+40,64+47,128+37

               .byte 64+61,128+20,128+18,128+29,128+46,128+16,128+38,128+32
               .byte 128+48,64+48,128+23,128+26,128+13,128+35,128+28,128+25
               .byte 128+10,128+14,128+27,128+32,128+17,128+19,128+21,128+34
               .byte 128+30,128+24,64+46,128+15,128+12,128+33,128+31,64+47

;
;Subroutine to create a string for a key given its ASCII value
;

get_string = *

   tay
   lda ascii_list,y
   pha
   and #63
   sta key
   pla
   lsr
   lsr
   lsr
   lsr
   lsr
   lsr
   asl
   tay
   lda shift_vec,y
   sta ptr
   lda shift_vec+1,y
   sta ptr+1

   ldy #0
-  lda (ptr),y
   bmi +
   sta text,y
   iny
   bne -
+  sty len

   ldy key
   cpy #49
   bcs +
   ldx len
   lda #34
   sta text,x
   sta text+2,x
   lda short_keys,y
   sta text+1,x
   inx
   inx
   inx
   bne ++

+  tya
   sbc #49
   asl
   tay
   lda long_vec,y
   sta ptr
   lda long_vec+1,y
   sta ptr+1
   ldx len
   ldy #0
-  lda (ptr),y
   bmi +
   sta text,x
   iny
   inx
   bne -
  
+  stx len
   lda #eot
   sta text,x

   rts

;
;Display current 17 lines of functions and keys
;

disp_fun = *

   lda topfun
   sta botfun
   lda #0
   sta index
df1 ldy index
   iny
   iny
   iny
   ldx #1
   jsr get_adr
   ldy botfun
   lda fun_value,y
   jsr get_string
   lda botfun
   asl
   tay
   lda function_vec,y
   sta ptr
   lda function_vec+1,y
   sta ptr+1
   ldy #0
-  lda (ptr),y
   bmi +
   sta (txtptr),y
   lda #7
   sta (colptr),y
   iny
   bne -
+  tya
   ldy index
   jsr s_itemlen
   tay
   clc
   adc len
   sta temp
   lda #38
   sec
   sbc temp
   sta temp
   ldx #0
-  cpx temp
   bcs +
   lda #"."
   sta (txtptr),y
   lda #11
   sta (colptr),y
   iny
   inx
   bne -
+  ldx #0
-  cpx len
   bcs +
   lda text,x
   sta (txtptr),y
   lda #15
   sta (colptr),y
   iny
   inx
   bne -
+  inc botfun
   inc index
   lda index
   cmp #17
   bcc df1

   rts

;
;Display standard bottom lines
;

disp_bottom = *

   jsr print
   .byte xx+0,yy+22,col+15
   .asc "RETURN - Change Current Key"
   .byte tab,40,13
   .asc "STOP - Return to Editor"
   .byte tab,40,13
   .asc "CRSR Keys - Scroll Through Functions"
   .byte eot
   rts

;
;--- Initialization for this module ---
;

init = *

   lda #0
   sta vic+21

   jsr print           ;Set up screen display
   .byte clr,def,40,0,0,1
   .asc "StereoEditor Key Customizer"
   .byte eof,box,0,2,39,20,11,eot

   jsr disp_bottom

;
;Set up menus
;

   jsr headerdef
   .byte 9,7,1
   .word can_vec,0,other_key,bound
   lda #17
   jsr sizedef

   ldy #16
-  tya
   clc
   adc #3
   jsr s_itemy
   lda #1
   jsr s_itemx
   lda #dispatch
   jsr s_itemtype
   lda #<sel_fun
   jsr s_itemvecl
   lda #>sel_fun
   jsr s_itemvech
   dey
   bpl -

   lda #0
   sta topfun
   jsr set_item

dissel jsr disp_fun
   jmp select

;
;Handle menu scrolling
;

bound = *

   bne scroll_up
   lda botfun
   cmp #num_fun
   bcs +
   inc topfun
+  jmp dissel

scroll_up = *

   lda topfun
   beq +
   dec topfun
+  jmp dissel

;
;Handle function key changing
;

sel_fun = *

   jsr print
   .byte xx+0,yy+22,col+15
   .asc "Press Desired Key:"
   .byte tab,40,13
   .byte tab,40,13
   .byte tab,40,xx+19,yy+22,eot
   jsr cursor_on

-  jsr getin
   beq -

other_key1 pha
   jsr cursor_off
   jsr read_item
   clc
   adc topfun
   tay
   pla
   sta fun_value,y
   jsr disp_bottom
   jmp dissel

;
;Handle other keypresses
;

other_key cmp #19
   bne +
   jmp home_list
+  cmp #147
   bne other_key1
   jmp end_list

;
;Return to main editor program
;

can_vec = *

   clc
   jmp (return_vec)

;
;Go to top of function list
;

home_list = *

   lda #0
   sta topfun
   jsr set_item
   jmp dissel

;
;Go to top of function list
;

end_list = *

   lda #num_fun-17
   sta topfun
   lda #16
   jsr set_item
   jmp dissel
