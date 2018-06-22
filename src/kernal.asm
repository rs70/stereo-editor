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

; This module resides at $8000 and is responsible for basic initialization and
; booting the rest of the application's components:
; 
; 1. Most of this module is the alternate kernal, which is copied to $E000
;    where the application expects to find it. This kernal provides screen I/O
;    (simple windowing and menus) and fast disk I/O.
; 2. Banks out all ROMs (character, BASIC, kernal), leaving a RAM-only
;    memory map.
; 3. VIC is reconfigured to address the last 16K block of memory (character
;    generator at $D000 and screen at $F400).
; 4. Installs thunks for a few needed ROM kernal routines, as well as the main
;    IRQ handler, at $0334. Each thunk banks the kernal ROM in, executes the
;    appropriate ROM routine, and then banks the kernal ROM back out.
; 5. Loads the character set at $D000 and generates the reverse character
;    set based on the normal character set.
; 6. Loads sprites at $D800.
; 7. Looks for a Sequential or Passport MIDI interface. If found, the user is
;    prompted to choose normal SID playback or MIDI playback.
; 8. Loads the SID player or MIDI player at $6000.
; 9. Loads the main application at $0400 and jumps to it.

   .org $8000
   .obj "001"

;Operating system routine equates

cint = $ff81
ioinit = $ff84
restor = $ff8a
scnkey = $ff9f

kernal_in  = %00000110
kernal_out = %00000101
col_const = $e4
border_char = 116

;Global variables

save_area = $f800
screen = $f400    ;Location of screen memory
txtptr = $e0
start_m = $e2
end_m = $e4
dest_m = $e6

;Zero-page variables for the screen print routine

line = $d9
cline = $db
fline = $dd
diff = $dd
kernal_temp = $df
fcline = $e8
newtop = $e8
number = $ea
ps1 = $ec
aptr = ps1
ps2 = $ee
bptr = ps2
pc1 = $f0
ftrack = pc1
fsector = pc1+1
pc2 = $f2
blockcnt = pc2
bvalue = pc2+1

xpos = $c8
ypos = $c9
color = $ca
rvsflag = $cc
pta = $cd
ptx = $ce
pty = $cf
fieldx = $d0
fieldy = $d1
fieldlen = $d2
fieldcol = $d3
fieldpos = $d4
fieldmode = $d5
fieldtemp = $d6
numflag = $d7
temptab = $d8

;Storage for menu routines.

menudata = $f000         ;Start of menu management area
mnum = menudata          ;Current menu number
hicol = menudata+1       ;Highlighting color
menufl = menudata+2      ;Menu flash mode
menucvec = menudata+3    ;Cancel vector
menuhvec = menudata+5    ;Help vector
menuovec = menudata+7    ;Other keypress vector
menubvec = menudata+9    ;Boundary vector
menusize = menudata+11   ;Number of menu items
fieldbuf = menudata+20   ;* Print routine storage *
itemx = menudata+64      ;Menu item column table
itemy = menudata+114     ;Menu item row table
itemlen = menudata+164   ;Menu item length table
itemvecl = menudata+214  ;Low byte of service vector table
itemvech = menudata+264  ;High byte of service vector table
itemvarl = menudata+314  ;Low byte of variable table
itemvarh = menudata+364  ;High byte of variable table
itemtabl = menudata+214  ;Low bytes of string table
itemtabh = menudata+264  ;High bytes of string table
itemmin = menudata+414   ;Table of minimum numeric values
itemmax = menudata+464   ;Table of maximum numeric values
itemtype = menudata+514  ;Table of menu item types
menupos = menudata+564   ;Position in each menu number (menus 0-31).

program = $f299
sprite_save = $f29a
track = $f29b
sector = $f29c
hotkey = $f29d
key = $f29e
fastmode = $f29f
ts_table = $f2a0
minibuf = $f2e0
fastbuf = $f300

;Zero-page storage for menu routines.

slow_name = $100
mline = $f7
mcline = $f9
hline = $b0
hcline = $b2
ix = $b4
iy = $b5
item = $b6
cflash = $a6
ccount = $a7
ilen = $a8
lastmenu = $a9
mcount = $aa
mflash = $ab

;Constants for screen print routine

eof = 1         ;End of field
def = 2         ;Define a field
tab = 3         ;Destructive
rvs = 4         ;Reverse mode on
rvsoff = 5      ;Reverse mode off
defl = 6        ;Non-justified field
defr = 7        ;Right-justified field
clr = 8         ;Clear entire screen
fkey = 10       ;Print function key names
box = 12        ;Define a screen window
xx = 96         ;80 values to set X-coordinate
col = 176       ;16 values to set color
yy = 224        ;25 values to set Y-coordinate
eot = 255       ;End of text for print

;Constants for menu creation

dispatch = 1    ;Dispatch to this item with no RTS on stack
service = 2     ;Call service routine with RTS on stack
numeric = 3     ;Auto-service numeric value
string = 4      ;Auto-service strings
null'item = 5   ;Not a serviceable item
eom = 0         ;End of menu definition

;Jump to initialization routines for fast/slow modes, editor/player flags.

   lda #1
   .byte $2c
   lda #0
   .byte $2c
   lda #129
   .byte $2c
   lda #128
   pha
   and #1
   sta fastmode
   pla
   and #128
   sta program
   jmp init

;System vector values when Kernal ROM switched out.

system_vector .word nmi,reset,irq

;----- Interface code that resides at $0334 ----

interface_code .off $0334

;IRQ handler

irq = *

   pha
   txa
   pha
   tya
   pha

;Main interrupt routine

irq_main = *

   lda 1
   pha
   lda #kernal_out
   sta 1
   jsr just_rts
irq_vec = *-2
   jsr inter
   lda #kernal_in
   sta 1
   jsr scnkey
   lda $dc0d
   pla
   sta 1
   pla
   tay
   pla
   tax
   pla
   rti

;Kernal routine calls

setlfs sta $b8
   stx $ba
   sty $b9
   rts

setnam sta $b7
   stx $bb
   sty $bc
   rts

open lda $d015
   sta sprite_save
   lda #0
   sta $d015
   lda #kernal_in
   sta 1
   jsr $ffc0
   lda #kernal_out
   sta 1
   rts

close ldy #kernal_in
   sty 1
   jsr $ffc3
   ldy #kernal_out
   sty 1
   ldy sprite_save
   sty $d015
   rts

chkin lda #kernal_in
   sta 1
   jsr $ffc6
   lda #kernal_out
   sta 1
   rts

chkout lda #kernal_in
   sta 1
   jsr $ffc9
   lda #kernal_out
   sta 1
   rts

clrchn lda #kernal_in
   sta 1
   jsr $ffcc
   lda #kernal_out
   sta 1
   rts

chrin lda #kernal_in
   sta 1
   jsr $ffcf
   pha
   lda #kernal_out
   sta 1
   pla
   rts

chrout sty kernal_temp
   ldy #kernal_in
   sty 1
   jsr $ffd2
   ldy #kernal_out
   sty 1
   ldy kernal_temp
   rts

getin ldy #kernal_in
   sty 1
   jsr $ffe4
   ldy #kernal_out
   sty 1
   ora #0
   rts

load pha
   lda #kernal_in
   sta 1
   pla
   jsr $ffd5
   ldy #kernal_out
   sty 1
   rts

reset lda #kernal_in
   sta 1
   jmp 64738

nmi rti

   .ofe

i_end = *

;---- Custom Kernal Module ----
;Offset coding to $E000

kernal .off $e000

;Custom kernal jump table ($E000).

   jmp setirq
   jmp print
   jmp lprint
   jmp printchar
   jmp printbyte
   jmp printword
   jmp select_string
   jmp save_screen
   jmp recall_screen
   jmp getrom
   jmp clear_screen
   jmp menudef
   jmp menuset
   jmp select
   jmp select_0
   jmp headerdef
   jmp sizedef
   jmp s_itemx
   jmp s_itemy
   jmp s_itemlen
   jmp s_itemvecl
   jmp s_itemvech
   jmp s_itemvarl
   jmp s_itemvarh
   jmp s_itemmin
   jmp s_itemmax
   jmp s_itemtype
   jmp read_item
   jmp cursor_on
   jmp cursor_off
   jmp move_up
   jmp move_down
   jmp read_prdir
   jmp init_drive
   jmp load_prfile
   jmp preparef
   jmp releasef
   jmp setlfs
   jmp setnam
   jmp open
   jmp close
   jmp chkin
   jmp chkout
   jmp clrchn
   jmp chrin
   jmp chrout
   jmp getin
   jmp set_item
   jmp get_adr
   jmp backspace
   jmp read_err
   jmp read_error
   jmp reset_keys
   jmp change_keys

;---- Print routines ----

;Convert a printable ASCII code into a ROM code.

getrom cmp #64
   bcc +++
   cmp #96
   bcc ++
   cmp #192
   bcs +
   sbc #31
   bcs +++
+  sec
   sbc #64
+  sec
   sbc #64
+  rts

;Print a character. Includes all special codes/fields/etc.

printchar stx ptx
   sty pty
   sta pta
printvec jmp $ffff

normalprint cmp #32
   bcc pspec
   cmp #96
   bcc printable
   cmp #176
   bcc xset
   cmp #192
   bcc colset
   cmp #224
   bcc printable

;Set Y position

yset sbc #yy
   sta ypos
   jsr calcline

;General exit from printchar routine

prexit ldx ptx
   ldy pty
   lda pta
   rts

;Set X position

xset sec
   sbc #xx
   sta xpos
   bcs prexit

;Set color

colset sec
   sbc #col
   sta color
   jmp prexit

;Handle printable codes

printable ldy xpos
   jsr getrom
   ora rvsflag
   sta (line),y
   lda color
   sta (cline),y
   inc xpos
   bne prexit

jpdef jmp pdef

;Handle special control codes

pspec cmp #def
   beq jpdef
   cmp #defr
   beq jpdef
   cmp #defl
   beq jpdef
   cmp #tab
   bne pspec1
   lda #<ptab1
   sta printvec+1
   lda #>ptab1
   sta printvec+2
   jmp prexit

ptab1 sta fieldx
   ldy xpos
   lda #32
   ora rvsflag
   sta temptab
-  cpy fieldx
   bcs +
   lda temptab
   sta (line),y
   lda color
   sta (cline),y
   iny
   bne -
+  sty xpos
   jsr setnormal
   jmp prexit

pspec1 cmp #rvs
   bne pspec2
   lda #128
   sta rvsflag
   jmp prexit

pspec2 cmp #rvsoff
   bne pspec3
   lda #0
   sta rvsflag
   jmp prexit

pspec3 cmp #13
   bne pspec4
   lda #0
   sta xpos
   inc ypos
   jsr calcline
   jmp prexit

pspec4 = *

pspec5 cmp #clr
   bne pspec6
   jsr clear_screen
   jmp prexit

pspec6 cmp #fkey
   bne pspec7
   lda #<fkeys
   sta printvec+1
   lda #>fkeys
   sta printvec+2
   jmp prexit
fkeys sta temptab
   jsr setnormal
   ldy xpos
   ldx #7
   lda #160
   sta (line),y
   txa
   sta (cline),y
   iny
   lda #"f"+128
   sta (line),y
   txa
   sta (cline),y
   iny
   lda temptab
   ora #$30+128
   sta (line),y
   txa
   sta (cline),y
   iny
   lda #160
   sta (line),y
   txa
   sta (cline),y
   iny
   sty xpos
   jmp prexit

pspec7 cmp #box
   bne pspec9
   jmp prbox

pspec9 jmp prexit

;Define a field

pdef sta fieldmode
   lda #<pdef1
   sta printvec+1
   lda #>pdef1
   sta printvec+2
   jmp prexit

pdef1 sta fieldlen
   lda #<pdef2
   sta printvec+1
   lda #>pdef2
   sta printvec+2
   jmp prexit

pdef2 sta fieldx
   lda #<pdef3
   sta printvec+1
   lda #>pdef3
   sta printvec+2
   jmp prexit

pdef3 sta fieldy
   lda #<pdef4
   sta printvec+1
   lda #>pdef4
   sta printvec+2
   jmp prexit

pdef4 sta fieldcol
   lda #<pdef5
   sta printvec+1
   lda #>pdef5
   sta printvec+2
   lda #0
   sta fieldpos
   jmp prexit

pdef5 cmp #eof
   beq pdef6
   ldy fieldpos
   sta fieldbuf,y
   inc fieldpos
   jmp prexit

pdef6 jsr setnormal
   lda fieldcol
   and #128
   sta temptab
   ldy fieldy
   lda lobyte,y
   sta fline
   sta fcline
   lda hibyte,y
   sta fline+1
   clc
   adc #col_const
   sta fcline+1
   ldy fieldx
   lda fieldlen
   sec
   sbc fieldpos
   ldx fieldmode
   cpx #defr
   beq ++
   cpx #defl
   bne +
   lda #0
+  lsr
+  sta fieldtemp
   lda fieldmode
   cmp #def
   bne +
   lda fieldpos
   and #1
   beq +
   inc fieldtemp
/  lda fieldtemp
   beq +
   lda #32
   ora temptab
   sta (fline),y
   lda fieldcol
   sta (fcline),y
   dec fieldtemp
   iny
   bne -
+  ldx #0
-  cpx fieldpos
   beq +
   lda fieldbuf,x
   jsr getrom
   ora temptab
   sta (fline),y
   lda fieldcol
   sta (fcline),y
   inx
   iny
   bne -
+  lda fieldx
   clc
   adc fieldlen
   sta fieldtemp
-  cpy fieldtemp
   beq +
   lda #32
   ora temptab
   sta (fline),y
   lda fieldcol
   sta (fcline),y
   iny
   bne -
+  jmp prexit

;Set normal print vector

setnormal lda #<normalprint
   sta printvec+1
   lda #>normalprint
   sta printvec+2
   rts

;Calculate line and cline based on ypos

calcline ldy ypos
   lda lobyte,y
   sta line
   sta cline
   lda hibyte,y
   sta line+1
   clc
   adc #col_const
   sta cline+1
   rts

;Print text pointed to by txtptr (terminates with a zero)

lprint = *

   ldy #0
-  lda (txtptr),y
   cmp #eot
   beq +
   jsr printchar
   iny
   bne -
   inc txtptr+1
   bne -
+  rts

;Print text that follows in code (terminates with a zero)

print = *

   pla
   clc
   adc #1
   sta txtptr
   pla
   adc #0
   sta txtptr+1
   jsr lprint
   tya
   clc
   adc txtptr
   sta txtptr
   bcc +
   inc txtptr+1
+  inc txtptr
   bne +
   inc txtptr+1
+  jmp (txtptr)

;Screen addresss

lobyte .byte <0,40,80,120,160,200,240
   .byte <280,320,360,400,440,480,520
   .byte <560,600,640,680,720,760,800
   .byte <840,880,920,960

hibyte .byte 244,244,244,244,244,244,244
   .byte 245,245,245,245,245,245
   .byte 246,246,246,246,246,246,246
   .byte 247,247,247,247,247

;Subroutine to clear the screen

clear_screen lda #32
   ldy #0
-  sta screen,y
   sta screen+256,y
   sta screen+512,y
   iny
   bne -
-  sta screen+768,y
   iny
   cpy #232
   bne -
   lda #0
   sta rvsflag
   rts

constl .byte <1,10,100,1000,10000
consth .byte >1,10,100,1000,10000

printbyte sta number
   lda #0
   sta number+1
   beq printnumber

printword stx number
   sty number+1

;Print an integer ranging from 0 to 65535.

printnumber = *

   txa
   pha
   tya
   pha
   ldx #4
   lda #0
   sta numflag
pn1 ldy #0
pn2 lda number+1
   cmp consth,x
   bne +
   lda number
   cmp constl,x
+  bcc pn3
   lda number
   sbc constl,x
   sta number
   lda number+1
   sbc consth,x
   sta number+1
   iny
   bne pn2
pn3 tya
   bne +
   ldy numflag
   beq pn4
+  inc numflag
   ora #$30
   jsr printchar
pn4 dex
   bne pn1
   lda number
   ora #$30
   jsr printchar
   pla
   tay
   pla
   tax
   rts

;Creation of bordered screen windows

prbox lda #<prbox1
   sta printvec+1
   lda #>prbox1
   sta printvec+2
   lda #0
   sta fieldpos
   jmp prexit

prbox1 ldy fieldpos
   sta fieldbuf,y
   inc fieldpos
   cpy #4
   beq prbox2
   jmp prexit

prbox2 jsr setnormal
   ldy fieldbuf+1
   lda lobyte,y
   clc
   adc fieldbuf
   sta ps1
   sta pc1
   lda hibyte,y
   adc #0
   sta ps1+1
   clc
   adc #col_const
   sta pc1+1
   lda fieldbuf+2
   sec
   sbc fieldbuf
   sta fieldlen
   lda fieldbuf+3
   sec
   sbc fieldbuf+1
   tax
   ldy #0
   lda #border_char+4
   sta (ps1),y
   lda fieldbuf+4
   sta (pc1),y
   iny
   lda #border_char
   jsr fillbox
   lda #border_char+5
   sta (ps1),y
   lda fieldbuf+4
   sta (pc1),y
   dex
   jsr bumplinec
-  ldy #0
   lda #border_char+2
   sta (ps1),y
   lda fieldbuf+4
   sta (pc1),y
   iny
   lda #32
   jsr fillbox
   lda #border_char+3
   sta (ps1),y
   lda fieldbuf+4
   sta (pc1),y
   jsr bumplinec
   dex
   bne -
   ldy #0
   lda #border_char+6
   sta (ps1),y
   lda fieldbuf+4
   sta (pc1),y
   iny
   lda #border_char+1
   jsr fillbox
   lda #border_char+7
   sta (ps1),y
   lda fieldbuf+4
   sta (pc1),y
   jmp prexit

fillbox sta ps2
-  cpy fieldlen
   bcs +
   lda ps2
   sta (ps1),y
   lda fieldbuf+4
   sta (pc1),y
   iny
   bne -
+  rts

bumplinec lda ps1
   clc
   adc #40
   sta ps1
   sta pc1
   bcc +
   inc ps1+1
   inc pc1+1
+  rts

;--- Menu Handling Module ---

;Establish a menu

menudef = *

   pla
   clc
   adc #1
   sta txtptr
   pla
   adc #0
   sta txtptr+1

   jsr get_menudata

   lda hicol
   clc
   adc #col
   jsr printchar
   ldy mnum
   bmi +
   lda menupos,y
   cpy lastmenu
   bcc ++
   beq ++
+  lda #0
+  sta item
   sty lastmenu
   ldx #0
md1 ldy #0
   lda (txtptr),y
   cmp #eot
   bne +
   inc txtptr
   bne md1
   inc txtptr+1
   bne md1
+  cmp #eom
   bne +
   jmp endofmenu
+  sta itemtype,x
   iny
   lda (txtptr),y
   sta itemx,x
   clc
   adc #xx
   jsr printchar
   iny
   lda (txtptr),y
   sta itemy,x
   clc
   adc #yy
   jsr printchar
   iny
   lda (txtptr),y
   sta itemlen,x
   iny
   lda itemtype,x
   cmp #numeric
   bcs md2
   lda (txtptr),y
   sta itemvecl,x
   iny
   lda (txtptr),y
   sta itemvech,x
   iny
-  lda (txtptr),y
   cmp #32
   bcc +
   jsr printchar
   iny
   bne -
+  jmp md9
md2 cmp #string
   beq md3
   lda (txtptr),y
   sta itemmin,x
   iny
   lda (txtptr),y
   sta itemmax,x
   iny
   lda (txtptr),y
   sta itemvarl,x
   iny
   lda (txtptr),y
   sta itemvarh,x
   iny
   bne md9
md3 lda (txtptr),y
   sta itemmin,x
   iny
   lda (txtptr),y
   sta itemvarl,x
   iny
   lda (txtptr),y
   sta itemvarh,x
   iny
   lda (txtptr),y
   sta itemtabl,x
   iny
   lda (txtptr),y
   sta itemtabh,x
   iny
md9 tya
   clc
   adc txtptr
   sta txtptr
   bcc +
   inc txtptr+1
+  inx
   jmp md1

endofmenu stx menusize
   inc txtptr
   bne +
   inc txtptr+1
+  jmp (txtptr)

;Define menu header only (service vectors, highlight color, etc.)

headerdef = *

   pla
   clc
   adc #1
   sta txtptr
   pla
   adc #0
   sta txtptr+1

   jsr get_menudata
   jmp (txtptr)

;Get menu data

get_menudata = *

   ldy #10
-  lda (txtptr),y
   sta menudata,y
   dey
   bpl -
   lda hicol
   pha
   and #128
   sta hotkey
   pla
   and #127
   sta hicol
   lda txtptr
   clc
   adc #11
   sta txtptr
   bcc +
   inc txtptr+1
+  rts

;Print .Ath string in a string table

select_string sta temptab
sels1 lda temptab
   beq sels9
   ldy #0
-  lda (txtptr),y
   cmp #eot
   beq +
   iny
   bne -
+  iny
   tya
   clc
   adc txtptr
   sta txtptr
   bcc +
   inc txtptr+1
+  dec temptab
   bne sels1
sels9 rts

selstring jsr select_string
   jmp lprint

;Set up initial values for current menu's
;string and numeric items.

menuset = *

   ldx #0
mse1 cpx menusize
   beq mse9
   lda itemtype,x
   cmp #numeric
   bcc mse8
   bne +
   lda itemvarl,x
   sta number
   lda itemvarh,x
   sta number+1
   ldy #0
   lda (number),y
   sta number
   sty number+1
   lda #defr
   jsr printchar
   jsr prmpar
   jsr printnumber
   lda #eof
   jsr printchar
   jmp mse8
+  lda #defl
   jsr printchar
   jsr prmpar
   lda itemtabl,x
   sta txtptr
   lda itemtabh,x
   sta txtptr+1
   lda itemvarl,x
   sta number
   lda itemvarh,x
   sta number+1
   ldy #0
   lda (number),y
   jsr selstring
   lda #eof
   jsr printchar
mse8 inx
   bne mse1
mse9 rts

;Send some menu params

prmpar lda itemlen,x
   jsr printchar
   lda itemx,x
   jsr printchar
   lda itemy,x
   jsr printchar
   lda hicol
   jmp printchar

;Set up screen addresses according to current item number

itemset ldx item
   lda itemx,x
   sta ix
   lda itemy,x
   sta iy
   lda itemlen,x
   sta ilen
   ldy iy
   lda lobyte,y
   clc
   adc ix
   sta mline
   sta mcline
   lda hibyte,y
   adc #0
   sta mline+1
   clc
   adc #col_const
   sta mcline+1
   lda mline
   sec
   sbc #2
   sta hline
   sta hcline
   lda mline+1
   sbc #0
   sta hline+1
   clc
   adc #col_const
   sta hcline+1
   rts

;Apply proper form of highlighting to current item

applyh jsr itemset
applyh1 lda menufl
   cmp #1
   beq +
   ldy #0
   lda #127
   sta (hline),y
   lda #1
   sta (hcline),y
+  lda menufl
   beq +
   ldy #0
-  cpy ilen
   beq +
   lda (mline),y
   ora #128
   sta (mline),y
   lda hicol
   sta (mcline),y
   iny
   bne -
+  lda #10
   sta mcount
   sta mflash
   rts

;Remove all highlighting from current item

removeh ldy #0
   sty mflash
   lda menufl
   cmp #1
   beq +
   lda #32
   sta (hline),y
+  lda menufl
   beq +
-  cpy ilen
   beq +
   lda (mline),y
   and #127
   sta (mline),y
   iny
   bne -
+  rts

;Allow menu selection

select_0 lda #0
   sta item
select jsr applyh
sloop jsr getin
   beq sloop
   ldx #selkeys1-selkeys-1
-  cmp selkeys,x
   beq sloop1
   dex
   bpl -
jother jmp other'key
sloop1 txa
   asl
   tax
   lda selvec+1,x
   pha
   lda selvec,x
   pha
   rts

def_keys .byte 17,17+128,29,29+128

selkeys .byte 17,17+128,29,29+128,13,133,135,"+","-",3
selkeys1 = *

selvec .word seldown-1,selup-1,selright-1,selleft-1
   .word handlef1-1,handlef1-1,handlef5-1,handleplus-1,handleminus-1
   .word handlef5-1

;Reset normal cursor key definitions


reset_keys = *

   ldy #3
-  lda def_keys,y
   sta selkeys,y
   dey
   bpl -
   rts

;Change cursor key definitions


change_keys = *

   stx txtptr
   sty txtptr+1
   ldy #3
-  lda (txtptr),y
   sta selkeys,y
   dey
   bpl -
   rts

;Cursor movement routines
; (All allow for null'item type - V1.1 040989)
;
seldown ldy iy
   iny
   sty temptab
   cpy #25
   beq seld21
seld1 ldx #0
-  cpx menusize
   beq seld2
   lda itemtype,x
   cmp #null'item
   beq +
   lda itemy,x
   cmp temptab
   bne +
   lda itemx,x
   cmp ix
   beq seld9
+  inx
   bne -
seld2 inc temptab
   lda temptab
   cmp #25
   bne seld1
seld21 lda menubvec+1
   beq +
   lda #0
   jmp (menubvec)
+  lda #0
   sta temptab
   beq seld1

seld9 jsr removeh
   stx item
   jmp select

selup ldy iy
   dey
   sty temptab
selu1 ldx #0
-  cpx menusize
   beq selu2
   lda itemtype,x
   cmp #null'item
   beq +
   lda itemy,x
   cmp temptab
   bne +
   lda itemx,x
   cmp ix
   beq selu9
+  inx
   bne -
selu2 dec temptab
   bpl selu1
   lda menubvec+1
   beq +
   lda #1
   jmp (menubvec)
+  lda #24
   sta temptab
   bne selu1
selu9 jmp seld9

selright ldy ix
   iny
   sty temptab
selr1 ldx #0
-  cpx menusize
   beq selr2
   lda itemtype,x
   cmp #null'item
   beq +
   lda itemx,x
   cmp temptab
   bne +
   lda itemy,x
   cmp iy
   beq selr9
+  inx
   bne -
selr2 inc temptab
   lda temptab
   cmp #40
   bne selr1
   lda #0
   sta temptab
   beq selr1
selr9 jmp seld9

selleft ldy ix
   dey
   sty temptab
sell1 ldx #0
-  cpx menusize
   beq sell2
   lda itemtype,x
   cmp #null'item
   beq +
   lda itemx,x
   cmp temptab
   bne +
   lda itemy,x
   cmp iy
   beq selr9
+  inx
   bne -
sell2 dec temptab
   bpl sell1
   lda #39
   sta temptab
   bne sell1

handlef1 ldx mnum
   lda item
   sta menupos,x
   tax
   lda itemtype,x
   asl
   tax
   lda f1hv-1,x
   pha
   lda f1hv-2,x
   pha
   rts

f1hv .word hmode1-1,hmode2-1,hmode3-1,hmode4-1

handleplus ldx item
   lda itemtype,x
   cmp #numeric
   bne +
   jmp hmode3
+  lda #"+"
   jmp jother

handleminus ldx item
   lda itemtype,x
   cmp #numeric
   bne +
   jmp hmode3d
+  lda #"-"
   jmp jother

handlef5 lda menucvec+1
   beq +
   jsr removeh
   jmp (menucvec)
+  jmp sloop

;Handle dispatches

hmode1 jsr removeh
hmode11 ldx item
   lda itemvecl,x
   sta number
   lda itemvech,x
   sta number+1
   jmp (number)

;Handle service routines
;(Changed 4/14/89)

hmode2 jsr applyh
   lda #0
   sta mflash
   jmp hmode11

;Handle pressing F1 over a numeric value

hmode3 jsr prephm
   ldy #0
   lda (number),y
   cmp itemmax,x
   bne +
   lda itemmin,x
   jmp ++
+  clc
   adc #1
+  sta (number),y
   sta number
inde lda #0
   sta number+1
   lda #defr
   jsr printchar
   jsr prmpar1
   jsr printnumber
   lda #eof
   jsr printchar
   jmp sloop

prephm ldx item
   lda itemvarl,x
   sta number
   lda itemvarh,x
   sta number+1
   rts

;Handle pressing the minus key over a numeric value

hmode3d jsr prephm
   ldy #0
   lda (number),y
   cmp itemmin,x
   bne +
   lda itemmax,x
   jmp ++
+  sec
   sbc #1
+  sta (number),y
   sta number
   jmp inde

prmpar1 ldx item
   lda hicol
   ora #128
   sta hicol
   jsr prmpar
   lda hicol
   and #127
   sta hicol
   rts

;Handle pressing F1 over a string value

hmode4 lda #defl
   jsr printchar
   jsr prmpar1
   lda itemvarl,x
   sta number
   lda itemvarh,x
   sta number+1
   lda itemtabl,x
   sta txtptr
   lda itemtabh,x
   sta txtptr+1
   ldy #0
   lda (number),y
   clc
   adc #1
   cmp itemmin,x
   bne +
   lda #0
+  sta (number),y
   jsr selstring
   lda #eof
   jsr printchar
   jmp sloop

;Handle other keypresses (allows for hot keys).

other'key = *

   sta key
   ldy hotkey
   beq +
   ldx #0
-  cpx menusize
   bcs +
   ldy itemy,x
   lda lobyte,y
   clc
   adc itemx,x
   sta txtptr
   lda hibyte,y
   adc #0
   sta txtptr+1
   ldy #0
   lda (txtptr),y
   and #127
   ora #64
   cmp key
   beq go'hot'key
   inx
   bne -

+  lda key
   ldx menuovec+1
   beq +
   pha
   jsr removeh
   pla
   jmp (menuovec)
+  jmp sloop

go'hot'key stx item
   jsr removeh
   jsr itemset
   jmp handlef1

;Other menu routines from jump table.

sizedef sta menusize
   rts

s_itemx sta itemx,y
   rts

s_itemy sta itemy,y
   rts

s_itemlen sta itemlen,y
   rts

s_itemtype sta itemtype,y
   rts

s_itemvecl sta itemvecl,y
   rts

s_itemvech sta itemvech,y
   rts

s_itemvarl sta itemvarl,y
   rts

s_itemvarh sta itemvarh,y
   rts

s_itemmin sta itemmin,y
   rts

s_itemmax sta itemmax,y
   rts

read_item lda item
   rts

set_item sta item
   rts

;Turn cursor on/off

cursor_on lda #20
   sta ccount
   sta cflash
   ldy xpos
   lda (line),y
   ora #128
   sta (line),y
   rts

cursor_off lda #0
   sta cflash
   ldy xpos
   lda (line),y
   and #127
   sta (line),y
   rts

backspace dec xpos
   ldy xpos
   lda #32
   sta (line),y
   rts

;Move a block of memory with overlap from a lower location to
;a higher location

move_up lda end_m
   clc
   sbc start_m
   sta diff
   lda end_m+1
   sbc start_m+1
   sta diff+1
   lda dest_m
   sec
   adc diff
   sta newtop
   lda dest_m+1
   adc diff+1
   sta newtop+1
   ldx diff+1
   inx
   ldy #0
   beq +
n1 lda (end_m),y
   sta (newtop),y
+  dec end_m+1
   dec newtop+1
   dex
   beq n3
   dey
n2 lda (end_m),y
   sta (newtop),y
   dey
   bne n2
   beq n1
n3 dey
   ldx diff
   inx
n4 lda (end_m),y
   sta (newtop),y
   dey
   dex
   bne n4
   rts

;Memory move routine. Handles overlap when moving a block from
;a higher location to a lower location.

move_down lda end_m
   sec
   sbc start_m
   sta diff
   lda end_m+1
   sbc start_m+1
   ldy #0
   tax
   beq n12
n11 lda (start_m),y
   sta (dest_m),y
   iny
   bne n11
   inc start_m+1
   inc dest_m+1
   dex
   bne n11
n12 cpy diff
   beq n13
   lda (start_m),y
   sta (dest_m),y
   iny
   bne n12
n13 lda (start_m),y
   sta (dest_m),y
   rts

;Screen save and recall routines

save_screen lda #<save_area
   sta ps2
   lda #>save_area
   sta ps2+1
   lda #0
   sta ps1
   lda #$f4
   sta ps1+1
   jsr quickmove
   lda #$d8
   sta ps1+1
   jmp quickmove

recall_screen lda #<save_area
   sta ps1
   lda #>save_area
   sta ps1+1
   lda #0
   sta ps2
   lda #$f4
   sta ps2+1
   jsr quickmove
   lda #$d8
   sta ps2+1
   jmp quickmove

quickmove ldx #3
   ldy #0
-  lda (ps1),y
   sta (ps2),y
   iny
   bne -
   inc ps1+1
   inc ps2+1
   dex
   bne -
   ldy #0
-  lda (ps1),y
   sta (ps2),y
   iny
   cpy #$e8
   bcc -
   inc ps1+1
   inc ps2+1
   rts

;Calculate screen and color addresses of coordinates in .X and .Y

get_adr = *

   stx ps1
   lda lobyte,y
   clc
   adc ps1
   sta txtptr
   sta start_m
   lda hibyte,y
   adc #0
   sta txtptr+1
   adc #col_const
   sta start_m+1
   rts

;-- INTERRUPT ROUTINE --

inter lda mflash
   beq inter1
   dec mcount
   bne inter1
   lda #10
   sta mcount
   lda menufl
   cmp #1
   beq +
   ldy #0
   lda (hcline),y
   eor #1
   sta (hcline),y
   jmp inter1
+  ldy #0
-  cpy ilen
   beq inter1
   lda (mline),y
   eor #128
   sta (mline),y
   iny
   bne -

inter1 lda cflash
   beq inter9
   dec ccount
   bne inter9
   lda #20
   sta ccount
   ldy xpos
   lda (line),y
   eor #128
   sta (line),y
  
inter9 rts

;---- Other routines ----

setirq sei
   stx irq_vec
   sty irq_vec+1
   cli
just_rts rts

;
;-----------------------------------------------------------------------------
;Fast DOS module
;-----------------------------------------------------------------------------
;
;These routines implement the FAST DOS system used in the 6-voice SID Editor.
;Drive code is sent to the drive via a series of M-W commands, each of
;which transmits 32 bytes.
;
;Initialize program disk, read directory and create a T/S pointer table for
;ordered numeric files on that disk in the range of "000" to "031". Return
;with carry set if there is a disk error, clear otherwise.
;
read_prdir = *
;
   jsr init_drive
   lda fastmode
   bne +
   lda #11
   sta 53265
   clc       ;No need to read directory if in slow mode
   rts
+  jsr activatef
   jsr preparef
;
   ldy #63   ;Zero track/sector table
   lda #0
-  sta ts_table,y
   dey
   bpl -
;
   lda #18
   sta ftrack
   lda #1
   sta fsector
;
se0 jsr readf
   bcs dir_error
   ldy #0
se1 sty bvalue
   ldx #0
-  lda fastbuf+2,y
   sta minibuf,x
   iny
   inx
   cpx #30
   bne -
   ldy bvalue
   lda minibuf
   beq se2
   lda minibuf+3
   cmp #"0"
   bne se2
   lda minibuf+3+3
   cmp #160
   bne se2
   lda minibuf+3+1
   jsr isdigit
   bcc se2
   and #15
   sta bvalue
   asl
   asl
   asl
   adc bvalue
   adc bvalue
   sta bvalue
   lda minibuf+3+2
   jsr isdigit
   bcc se2
   and #15
   clc
   adc bvalue
   cmp #32
   bcs se2
   asl
   tax
   lda minibuf+1
   sta ts_table,x
   lda minibuf+2
   sta ts_table+1,x
se2 tya
   clc
   adc #32
   tay
   bne se1
   lda fastbuf
   cmp #18
   bne endofdir
   sta ftrack
   lda fastbuf+1
   sta fsector
   jmp se0
;  
endofdir clc
dir_error rts

;
;Return with carry set only if ASCII character in .A is a digit (0-9).
;
isdigit cmp #":"
   bcs +
   cmp #"0"
   bcc +
   rts
+  clc
   rts
;
;Initialize drive
;
init_drive =*
;
   lda #"i"
   sta slow_name
   lda #"0"
   sta slow_name+1
   lda #15
   ldx $ba
   ldy #15
   jsr setlfs
   lda #2
   ldx #<slow_name
   ldy #>slow_name
   jsr setnam
   jsr open
   lda #15
   jmp close
;
;Read error number of current drive. Return it in .A, and set carry if there
;is indeed an error
;
read_err = *
;
   lda #15
   ldx $ba
   ldy #15
   jsr setlfs
   lda #0
   jsr setnam
   jsr open
   jsr read_error
   pha
   lda #15
   jsr close
   pla
   cmp #2
   rts
;
read_error = *
;
   ldx #15
   jsr chkin
   jsr read_digits
   pha
   jsr chrin
-  jsr chrin
   cmp #","
   bne -
   jsr read_digits
   sta track
   jsr chrin
   jsr read_digits
   sta sector
   jsr clrchn
   pla
   ldx track
   ldy sector
   cmp #2
   rts
;
;Read two digits
;
read_digits = *
;
   jsr chrin
   and #15
   sta bvalue
   asl
   asl
   asl
   adc bvalue
   adc bvalue
   sta bvalue
   jsr chrin
   and #15
   adc bvalue
   rts
;
;Load numbered file from drive. Assumes read_prdir has been called and
;drive is prepared. Pass file number (0-31) in .A, and load address in
;.X and .Y (low byte, high byte respectively).
;
load_prfile = *
;
   stx aptr
   sty aptr+1
   ldy fastmode
   bne +
   jmp slow_load
+  asl
   tay
   lda ts_table,y
   bne +
load_error sec
   rts
+  sta ftrack
   lda ts_table+1,y
   sta fsector
   jsr readf
   bcs load_error
;
   ldy #0
-  lda fastbuf+4,y
   sta (aptr),y
   iny
   bne -
   lda aptr
   clc
   adc #252
   sta aptr
   bcc +
   inc aptr+1
;
lf1 lda fastbuf
   beq lf9
   sta ftrack
   lda fastbuf+1
   sta fsector
   jsr readf
   bcs load_error
   ldy #0
-  lda fastbuf+2,y
   sta (aptr),y
   iny
   bne -
   lda aptr
   clc
   adc #254
   sta aptr
   bcc +
   inc aptr+1
+  jmp lf1
lf9 clc
   rts
;
;Slow load routine
;
slow_load = *
;
   tay
   lda slow_table,y
   pha
   lsr
   lsr
   lsr
   lsr
   ora #48
   sta slow_name+1
   lda #"0"
   sta slow_name
   pla
   and #15
   ora #48
   sta slow_name+2
;
   lda #7
   ldx $ba
   ldy #0
   jsr setlfs
   lda #3
   ldx #<slow_name
   ldy #>slow_name
   jsr setnam
   lda #0
   ldx aptr
   ldy aptr+1
   jsr load
;
   jmp read_err
;
;Filenames in BCD
;
slow_table = *
;
   .byte $00,$01,$02,$03,$04,$05,$06,$07
   .byte $08,$09,$10,$11,$12,$13,$14,$15
   .byte $16,$17,$18,$19,$20,$21,$22,$23
   .byte $24,$25,$26,$27,$28,$29,$30,$31
;
;The following routine sends the fast code to the drive.
;
activatef lda #7
   ldx $ba
   ldy #15
   jsr setlfs
   lda #0
   jsr setnam
   jsr open
;
   lda #<drivecode
   sta aptr
   lda #>drivecode
   sta aptr+1
   lda #0
   sta bptr
   lda #5
   sta bptr+1
   lda #omega-alpha/32+1
   sta blockcnt
;
snd1 ldx #7
   jsr chkout
   lda #"m"
   jsr chrout
   lda #"-"
   jsr chrout
   lda #"w"
   jsr chrout
   lda bptr
   jsr chrout
   lda bptr+1
   jsr chrout
   lda #32
   jsr chrout
   ldy #0
-  lda (aptr),y
   jsr chrout
   iny
   cpy #32
   bne -
   lda aptr
   clc
   adc #32
   sta aptr
   bcc +
   inc aptr+1
+  lda bptr
   clc
   adc #32
   sta bptr
   bcc +
   inc bptr+1
+  jsr clrchn
;
   dec blockcnt
   bne snd1
   jsr clrchn
   lda #7
   jmp close
;
;These routines activate the fast code in the drive.
;
preparef lda fastmode
   beq +
   ldx $ba
   lda #7
   ldy #15
   jsr setlfs
   lda #11
   sta $d011
   lda #0
   sta $d015
   jsr setnam
   jsr open
   ldx #7
   jsr chkout
   lda #"u"
   jsr chrout
   lda #"c"
   jsr chrout
   lda #13
   jsr chrout
   jsr clrchn
   lda #%00000100
   sta $dd00
   ldy #255
   ldx #127
-  dex
   bne -
   dey
   bne -
+  rts
;
;Read a block from the current fast drive.  Track in FTRACK, and
;sector in FSECTOR.  Data will reside starting at address pointed to by
;FASTPTR.
;
readf sei
   lda #1
   jsr sendf
   lda ftrack
   jsr sendf
   lda fsector
   jsr sendf
   ldy #0
-  jsr getf
   sta fastbuf,y
   iny
   bne -
   jsr getf
   cli
   cmp #2
   rts

;
;Release drive with fastcode currently activated.
;
releasef lda fastmode
   beq +
   sei
   lda #0
   jsr sendf
   cli
;  lda $d011
;  ora #16
;  sta $d011
+  lda #7
   jmp close
;
;Send a byte to the disk drive
;(Byte in .A.  .X destroyed, .Y preserved)
;
sendf ldx #%00010100
   nop
   nop
   nop
   nop
   nop
   stx $dd00
   pha
   and #3
   tax
   lda ftable,x
   sta $dd00
   lda $ff  ;3-cycle delay
   nop
   pla
   lsr
   lsr
   pha
   and #3
   tax
   lda ftable,x
   sta $dd00
   nop
   pla
   lsr
   lsr
   pha
   and #3
   tax
   lda ftable,x
   sta $dd00
   nop
   pla
   lsr
   lsr
   and #3
   tax
   lda ftable,x
   sta $dd00
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   lda #%00000100
   sta $dd00
   rts
;
;Receive a byte from the disk drive.
;
getf lda #64
-  bit $dd00
   bne -
   lda #%00100000
   sta $dd00
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   lda #%00000000
   sta $dd00
   ldx #4
-  lda $dd00
   rol
   ror bvalue
   rol
   ror bvalue
   nop
   lda $ff
   dex
   bne -
   lda bvalue
   rts
;
;Table for fast send routine (computer)
;
ftable .byte %00000100
 .byte %00010100
 .byte %00100100
 .byte %00110100
;
drivecode = *
;
;End of Kernal code
;
   .ofe
;
;
;--------------------------------------
;This code will reside in drive memory
;--------------------------------------
;
   .off $0500
;
byte = 44
fytemp = 45
dtrack = 31
dsector = 116
;
alpha sei
   lda $1c00
   ora #8
   sta $1c00
   ldy #127
   ldx #63
-  dex
   bne -
   dey
   bne -
;
;Main loop - accept the following one-byte command codes from the
;computer:
;
;   0 = Return to normal DOS
;   1 = Read a block
;
loop jsr get
   cmp #1
   bne loop2
;
;Read a block from disk. Accepts T/S from computer. Returns 256 bytes,
;as well as a status byte.
;
ddread jsr get
   sta dtrack
   jsr get
   sta dsector
   lda #7
   sta byte
frl lda dtrack
   sta 6
   lda dsector
   sta 7
   lda #$80
   sta 0
   cli
-  bit 0
   bmi -
   sei
   lda 0
   cmp #2
   bcc +
   dec byte
   bne frl
+  ldy #0
-  lda $300,y
   jsr send
   iny
   bne -
   lda 0
   jsr send
   jmp loop
;
;Return to normal DOS
;
loop2 lda $1c00
   and #$f7
   sta $1c00
   cli
   rts
;
;Receive a byte from the computer using the fast serial protocol.
;
get lda #0
   sta $1800
   lda #4
-  bit $1800
   beq -
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   lda $1800
   and #7
   tax
   lda ftable1,x
   sta byte
   nop
   nop
   nop
   nop
   nop
   lda $1800
   and #7
   tax
   lda ftable2,x
   ora byte
   sta byte
   nop
   lda $ff  ;3-cycle delay
   nop
   lda $1800
   and #7
   tax
   lda ftable3,x
   ora byte
   sta byte
   nop
   lda $ff  ;3-cycle delay
   nop
   lda $1800
   and #7
   tax
   lda ftable4,x
   ora byte
   rts
;
;Send a byte to the computer.
;
send sta byte
   sty fytemp
   lda #%00001000
   sta $1800
   lda #1
-  bit $1800
   beq -
   lda byte
   ldy #4
-  sta byte
   and #3
   tax
   lda ftable5,x
   sta $1800
   lda byte
   lsr
   lsr
   dey
   bne -
   ldy fytemp
   nop
   nop
   nop
   nop
   nop
   nop
   lda #0
   sta $1800
   rts
;
;Tables for use by receiving routines
;
ftable1 .byte %00,%10,%00,%10
 .byte %01,%11,%01,%11
ftable2 .byte %0000,%1000,%0000,%1000
 .byte %0100,%1100,%0100,%1100
ftable3 .byte %000000,%100000
 .byte %000000,%100000
 .byte %010000,%110000
 .byte %010000,%110000
ftable4 .byte %00000000,%10000000
 .byte %00000000,%10000000
 .byte %01000000,%11000000
 .byte %01000000,%11000000
;
;Table used by drive send routine.
;
ftable5 .byte %00001010
   .byte %00001000
   .byte %00000010
   .byte %00000000
;
omega = *
;
;End of drive code
;
   .ofe
;

;---------- SID EDITOR INITIALIZATION -----------
;First, reset system.

init = *

   sei
   cld
   ldx #$ff
   txs
   jsr ioinit
   jsr restor
   jsr cint

   lda #128
   sta 657  ;Disable SHIFT/C= keypress

   lda #0
   sta mflash
   sta cflash
   sta rvsflag
   sta lastmenu
   sta 53280
   sta 53281
   lda #11   ;Blank the screen
   sta 53265

   lda 56578
   ora #3
   sta 56578
   lda 56576 ;VIC will address last 16K block of memory.
   and #252
   sta 56576
   lda #$d4                    ;Character generator at $D000, screen at $F400
   sta 53272
   lda #kernal_out
   sta 1

   ldy #5                      ;Set the system vectors (NMI, IRQ, RESET)
-  lda system_vector,y
   sta $fffa,y
   dey
   bpl -
   lda #<irq_main
   sta $314
   lda #>irq_main
   sta $315
   lda #<nmi
   sta $318
   lda #>nmi
   sta $319

;Move interrupt handler/interface page to $334

   ldy #0
-  lda interface_code,y
   sta $334,y
   iny
   cpy #i_end-interface_code
   bcc -

;Move Kernal routines to their proper locations.

   lda #0
   sta ps2
   lda #$e0
   sta ps2+1
   lda #<kernal
   sta ps1
   lda #>kernal
   sta ps1+1
   ldx #16                     ;**** Number of pages to move.
   ldy #0
-  lda (ps1),y
   sta (ps2),y
   iny
   bne -
   inc ps1+1
   inc ps2+1
   dex
   bne -

;Initialize print routine and clear screen

   jsr setnormal
   jsr clear_screen
   cli

;Load character set in at $4000

   jsr read_prdir
   lda #2
   ldx #0
   ldy #$40
   jsr load_prfile

;Load sprites in at $4800

   lda #3
   ldx #0
   ldy #$48
   jsr load_prfile

;Move character set to proper place and create reverse images of it.
;Also move sprites to correct place.

   sei
   lda #0
   sta 1
   lda #0
   sta ps1
   sta ps2
   sta pc1
   lda #$40
   sta pc1+1
   lda #$d0
   sta ps1+1
   lda #$d4
   sta ps2+1
   ldx #4
   ldy #0
-  lda (pc1),y
   sta (ps1),y
   eor #255
   sta (ps2),y
   iny
   bne -
   inc ps1+1
   inc ps2+1
   inc pc1+1
   dex
   bne -

   ldy #0
-  lda $4800,y
   sta $d800,y
   lda $4900,y
   sta $d900,y
   iny
   bne -

   lda #kernal_out
   sta 1
   cli

;Check for Enhanced Sidplayer module.

   lda #10
   ldx #0
   ldy #$60
   jsr load_prfile

   ldy #sequence1-sequence-1
-  lda $6160,y
   cmp sequence,y
   bne +
   dey
   bpl -
   jmp ok

+  lda #11
   ldx #0
   ldy #$60
   jsr load_prfile
   jsr releasef
   lda #11+16
   sta 53265
   jsr $6000  ;Dispatch to copier
   jsr read_prdir

;Check for MIDI interface and load appropriate module.

ok = *

   jsr check_midi
   lda interface_type
   bne load_midi

;Load stereo SID Player module or MIDI player module depending on entry point

load_sid = *

   lda #6
   .byte $2c

load_midi = *

   lda #13
   ldx #0
   ldy #$60
   jsr load_prfile

;Load key correspondence/customization table

   lda #7
   ldx #0
   ldy #$5a
   jsr load_prfile

;Now load main editor module and transfer control to it. Or load player
;module if that option was selected.

   lda #4
   ldy program
   beq +
   lda #14
+  ldx #0
   ldy #$04
   jsr load_prfile
   jsr releasef

   lda #11+16
   sta 53265
   lda interface_type
   jmp $0400

;-- Sequence of bytes checked for at $0160 offset in Enhanced Sidplayer module.

sequence = *

   .byte $c1,$60,$01,$02,$04,$00

sequence1 = *

;-- Check for Passport or SEQ interface --

check_midi = *

    lda #$13
    sta $de08
    lda #$11
    sta $de08
    lda $de08
    cmp #2
    bne +

    lda #$ff             ;Passport
    sta interface_type
    lda #0
    jmp ask_midi

+   lda #3
    sta $de00
    lda #$15
    sta $de00
    lda $de02
    cmp #2
    bne +
    lda #2               ;Sequential
    sta interface_type
    lda #1
    jmp ask_midi

+   lda #0               ;No interface
    sta interface_type
    lda program
    bne no_midi_error
    rts

;-- If player is being loaded, MIDI interface MUST be present. --

no_midi_error = *

    jsr print
    .byte clr,box,7,10,32,15,14,xx+9,yy+12,col+1
    .asc "You do not have a MIDI"
    .byte xx+9,yy+13
    .asc "interface plugged in."
    .byte eot
    jsr releasef
    lda #27
    sta 53265
-   jmp -

;-- Interface type text --

if_text     .asc "Passport"
            .byte eot
            .asc "Sequential"
            .byte eot

;-- Give option to load normal Sidplayer module or MIDI module --

ask_midi = *

    pha
    jsr releasef
    lda program
    beq +
    pla
    jmp midi_1
+   lda #27
    sta 53265
    jsr print
    .byte clr,box,5,8,35,16,14,xx+7,yy+10,col+1
    .asc "A "
    .byte eot
    pla
    ldx #<if_text
    ldy #>if_text
    stx txtptr
    sty txtptr+1
    jsr select_string
    jsr lprint
    jsr print
    .asc " MIDI interface"
    .byte xx+7,yy+11
    .asc "was found."
    .byte eot

    jsr menudef
    .byte 0,15+128,2
    .word 0,0,0,0
    .byte dispatch,12,13,17
    .word midi_0
    .asc "Normal Sidplayer"
    .byte dispatch,12,14,17
    .word midi_1
    .asc "Play Through MIDI"
    .byte eom
    jmp select_0

midi_0 = *

    lda #0
    sta interface_type

midi_1 = *

    lda #11
    sta 53265
    jmp read_prdir

interface_type = *
