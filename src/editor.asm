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

; This module implements the main editor. It depends on the following
; components to already be resident in RAM:
;
; 1. Alternate kernal at $E000-$EFFF (file "001").
; 2. Character set at $D000-$D3FF (file "002").
; 3. Reversed character set at $D400-$D7FF (generated at runtime by the kernal).
; 3. Sprites at $D800-$D8FF (file "003").
; 4. SID player or MIDI player at $6000-$6FFF (file "006" or "013").
; 5. Preferences/key assignments at $5A00 (file "007").

   .org $0400
   .obj "004"

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
read_err      = $e096
read_error    = $e099
reset_keys    = $e09c
change_keys   = $e09f

;
;Major storage areas
;

cred_block = $5800       ;5 lines of credits, terminated by a zero, in ASCII
config     = $5a00       ;Configuration file ("007") data.
edit_key   = $5a00       ;Table of edit keys
var        = $5c00       ;Start of editor module variables
player     = $6000       ;SID player module
start_heap = $7000       ;Start of music data
dir_info   = $7100       ;Directory storage
top_heap   = $bf00       ;Top of heap address for SID data.
applic     = $c000       ;Where transient applications are loaded in.
buffer_loc = $da00       ;Cut and paste buffer
buffer_size = 1530       ;Maximum cut/paste buffer size

;
;Zero-page start of storage equate
;

zp = 2                   ;Start of zero page storage for this module

;
;Zero-page pointers
;

voice_start = zp         ;6 two-byte pointers to start of each voice
voice_end   = zp+14      ;6 two-byte pointers to end of each voice
voice_pos   = zp+28      ;6 two-byte pointers to position in each voice
disp_start  = zp+42      ;Pointer to start of current voice for disp update
disp_end    = zp+44      ;Pointer to end of current voice for disp update
row1_ptr    = zp+46      ;Screen address of row 1 text slot
row2_ptr    = zp+48      ;Screen address of row 2 text slot
ptr         = zp+50      ;A local, temporary pointer
file_ptr    = zp+52      ;Pointer to current filename
voice       = zp+54      ;Current voice number (0-5)
move_mode   = zp+55      ;Movement mode - single voice/all voices
number      = zp+56      ;A number
low_range   = zp+60      ;Low range for command value
high_range  = zp+62      ;High range for command value
measure     = zp+64      ;Current measure number in current voice
current_note = zp+66     ;Current note bytes
beat_count  = zp+68      ;Number of semi-beats in current measure
mark_ptr    = zp+70      ;Start of marked region
cut_ptr     = zp+72      ;End of marked region
reg_start   = zp+74      ;Lowest note address in region
reg_end     = zp+76      ;Highest note address in region
buf_ptr     = zp+78      ;Pointer into cut/paste buffer
wds_ptr     = zp+80      ;Points to next line in WDS file being displayed
old_wds_ptr = zp+82      ;One line behind WDS_PTR
xadd        = zp+84      ;Value to add to number storage location
ptr2        = zp+85      ;General use pointer
temp        = zp+87      ;A temporary value
temp2       = zp+88      ;Another temporary value

;
;Global zero page locations (used by new Kernal, too).
;

txtptr      = $e0        ;Points to start of a text item to be printed
start_m     = $e2        ;Start of block of memory to be moved
end_m       = $e4        ;End of block
dest_m      = $e6        ;Where to move that block

;
;Current note variables used by display routines.
;

d$duration       = var+2            ;Current note duration value (for display).
d$tie            = var+3            ;Current note tie value
d$dot            = var+4            ;Current note dot/triplet status
d$octave         = var+5            ;Current note's octave (0-7)
d$note_letter    = var+6            ;Current note letter
d$accidental     = var+7            ;Current accidental value
d$command        = var+8            ;Command index/token number
d$cmd_value      = var+9            ;Two-byte value of command
d$cmd_sign       = var+11

row1_text        = var+12           ;Top row of current note display
row2_text        = var+17           ;Bottom row of current note display

menusize         = var+22           ;Size of current menu
topline          = var+23           ;First screen line with a file
topfile          = var+24           ;Index of first displayed file
botfile          = var+25           ;Index (+1) of last displayed file
num_files        = var+26           ;Number of files in directory
mus_flag         = var+27           ;1=MUS file included
str_flag         = var+28           ;1=STR file included

max_len          = var+29           ;Maximum length byte
key_temp         = var+30           ;A temporary value
pr_device        = var+61           ;Program file device

e$duration       = var+62           ;Editing note duration value
e$tie            = var+63           ;Editing note tie value
e$dot            = var+64           ;Editing note dot/triplet status
e$octave         = var+65           ;Editing note's octave (0-7)
e$note_letter    = var+66           ;Editing note letter
e$accidental     = var+67           ;Editing accidental value
e$command        = var+68           ;Editing index/token number
e$cmd_value      = var+69           ;Two-byte value of command
e$cmd_sign       = var+71

text             = var+72           ;16 byte temporary text area
key              = var+88           ;Current key we're in
time_top         = var+89           ;Beats per measure
time_bot         = var+90           ;Beats per whole note
cmd_len          = var+91           ;Length of current command string
cmd_string       = var+92           ;Current hot key command string (3 char).

midi_mode        = var+100          ;MIDI enabled/disabled
midi_phase       = var+101          ;0=waiting, 1=read note, 2=read velocity
midi_wait        = var+102          ;Note value read during last IRQ
midi_note        = var+103          ;0=no MIDI note waiting, >127=MIDI note

u_flag           = var+104          ;Were any u or uV durations found?
voice_staff      = var+105          ;Type of staff (0-5) for each voice
staff_type       = var+111          ;Type of current staff displayed

play_flag        = var+112          ;Is play routine installed in interrupt?
stereo_mode      = var+113          ;0=no chip, 1=$DE00, 2=$DF00

route            = var+114          ;0=stereo, 1=mono-left, 2=mono-right
start_enable     = var+120          ;Bit map: 0=don't start voice, 1=start it

bong_flag        = var+121          ;1=Wait for "bong" release
bong_count       = var+122          ;Jiffy countdown to bong release

current_file     = var+123          ;Filename of last loaded SID
current_flen     = var+139          ;Length of filename of last loaded SID
mod_flag         = var+140          ;1=SID in memory was modified
cut_flag         = var+141          ;1=Mark has been set

j$speed_count    = var+149          ;Countdown to next joystick repeat
j$waiting        = var+150          ;Joystick value waiting (0-31).
j$last           = var+151          ;Last joystick value

r$note_letter    = var+152          ;Last note before rest (C-B)
r$accidental     = var+153          ;Last accidental before rest

wds_flag         = var+154          ;1=There is a WDS file, 0=none
play_screen      = var+155          ;Display screen during play (0-2)

vlen             = var+156          ;Length of voices to be inserted (12 bytes)
pause_mode       = var+170          ;1=play pause, 0=normal play

name_len         = var+171          ;Length of current filename
filename         = var+172          ;Current filename (Maximum 40 bytes)

clock_save       = var+224          ;TOD clock save values (4 bytes).
play_speed       = var+228          ;Speed of player
play_count       = var+229          ;Countdown to next call to player interrupt

bar_color        = var+230          ;6 bar color values for use during play

;
;Temporary values
;

table            = var+256          ;Temporary general-use table
line_construct   = var+256          ;One use of temporary table
staff_pos        = var+384          ;Sprite positions for notes on staff
nodot_table      = var+512          ;Duration factor for undotted notes
dot_table        = var+512+16       ;Duration factor for dotted notes
dd_table         = var+512+32       ;Duration factor for double-dotted notes
partial_trip     = var+512+48       ;Counter of partial triplets - each dur
full_trip        = var+512+64       ;Counter of full triplets - each dur

tv               = var+768          ;Start of temporary value storage
row_pos          = tv               ;Position in row (number conv routines)
num_flag         = tv+2             ;Numeric position in row (skipping sign)
slot_count       = tv+3             ;Counts slots updated in a voice
voice_count      = tv+4             ;Counts voices during screen update
index            = tv+5             ;File index value
char             = tv+6             ;Current character value
pos              = tv+7             ;Position in input buffer
move_flag        = tv+8             ;1=memory moved, 0=not moved
dvoice           = tv+10            ;Current voice display in construction

;
;Miscellaneous constants
;

screen           = $f400
col_factor       = $e4
sprite_block     = 96
vic              = $d000
sid              = $d400

mctrl            = $de08
mdata            = $de09


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
;Constants used by note display routines.
;

abs_pitch        = 0                ;Absolute duration
utility_dur      = 1                ;Global utility duration
whole_note       = 2                ;Whole note
half_note        = 3                ;Half note
quarter_note     = 4                ;Quarter note
eighth_note      = 5                ;Eighth note
sixteenth_note   = 6                ;Sixteenth note
duration_32      = 7                ;Thirty-second note
duration_64      = 8                ;Sixty-fourth note
utility_voice    = 9                ;Local (voice) utility duration

no_dot           = 0                ;Not a dot or triplet value
dot              = 1                ;Note is dotted
double_dot       = 2                ;Note is double dotted
triplet          = 3                ;Note is part of a triplet

double_flat      = 0                ;Double flat note
flat             = 1                ;Flat note
natural          = 2                ;Natural note
sharp            = 3                ;Sharp note
double_sharp     = 4                ;Double-sharp note

rest_note        = 0                ;Value of a rest
c_note           = 1                ;Pitch C
d_note           = 2                ;Pitch D
e_note           = 3                ;Pitch E
f_note           = 4                ;Pitch F
g_note           = 5                ;Pitch G
a_note           = 6                ;Pitch A
b_note           = 7                ;Pitch B

full_char        = 28               ;Full bar for timing screen
half_char        = 31               ;Half bar for timing screen
box_char         = 91               ;Start character code for box drawing
dur_char         = 97               ;Character code for whole note
acc_char         = 104              ;Character code for double-flat
dot_char         = 109              ;Character code for dotted note
tie_char         = 112              ;Character code for 1st tie character
line_char        = 114              ;Staff line characters
piano_char       = 124              ;Char code for 1st piano character

;
;Constants for command indices.
;

bmp_cmd          = 0
flt_cmd          = 1
rng_cmd          = 2
snc_cmd          = 3
fx_cmd           = 4                ;F-X command
o3_cmd           = 5                ;3-O command
lfo_cmd          = 6
pv_cmd           = 7                ;P&V command
wav_cmd          = 8
fm_cmd           = 9                ;F-M command
tal_cmd          = 10
end_cmd          = 11
hlt_cmd          = 12
atk_cmd          = 13
dcy_cmd          = 14
sus_cmd          = 15
rls_cmd          = 16
res_cmd          = 17
vol_cmd          = 18
def_cmd          = 19
cal_cmd          = 20
rup_cmd          = 21
rdn_cmd          = 22
src_cmd          = 23
dst_cmd          = 24
utl_cmd          = 25
pnt_cmd          = 26
hed_cmd          = 27
flg_cmd          = 28
vdp_cmd          = 29
vrt_cmd          = 30
aux_cmd          = 31
pvd_cmd          = 32
pvr_cmd          = 33
max_cmd          = 34
utv_cmd          = 35
fc_cmd           = 36               ;F-C command
hld_cmd          = 37               ;HLD command
ps_cmd           = 38               ;P-S command
fs_cmd           = 39               ;F-S command
sca_cmd          = 40
aut_cmd          = 41
tem_cmd          = 42
tps_cmd          = 43
rtp_cmd          = 44
pw_cmd           = 45               ;P-W command
jif_cmd          = 46
dtn_cmd          = 47
por_cmd          = 48
ms_cmd           = 49               ;MS# command

;
;Player interface equates
;

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
p$flag           = player+36
p$byte_2         = player+38
p$byte_1         = player+44
p$measure_l      = player+50
p$measure_h      = player+56
p$freq_l         = player+62
p$freq_h         = player+68
p$pulse_l        = player+74
p$pulse_h        = player+80
p$v_gate         = player+86
p$atk_dcy        = player+92
p$sus_rel        = player+98
p$pnt_val        = player+104
p$hld_val        = player+110
p$utv_val        = player+116
p$por_val_l      = player+122
p$por_val_h      = player+128
p$vdp_val        = player+134
p$vrt_val        = player+140
p$pvd_val        = player+146
p$pvr_val        = player+152
p$p_v_val        = player+158
p$dtn_l          = player+164
p$dtn_h          = player+170
p$rtp_val        = player+176
p$tps_val        = player+182
p$aps_l          = player+188
p$aps_h          = player+194
p$reson          = player+200
p$cut_val        = player+202
p$volume         = player+208
p$tempo          = player+210
p$utl_val        = player+212
p$cur_rate       = player+214
p$norm_rate      = player+216
p$aut_val        = player+218
p$f_s_val        = player+224
p$lfo_val        = player+230
p$rup_val        = player+232
p$rdn_val        = player+234
p$max_val        = player+236
p$route          = player+238
p$mod_tempo      = player+239
p$dur_count      = player+241

play_channel     = player+$ff0
interface_type   = player+$ff8
p$aux_val        = player+$ff9

;
;Key table interface equates
;

ek0              = edit_key+6
ek_note          = ek0+3
ek_octave        = ek_note+8
ek_acc           = ek_octave+8
ek_dur           = ek_acc+9
ek1              = ek_dur+25
eke              = ek1+9
cc_key           = eke

;
;Configuration variables (part of "007" file).
;

cvar             = config+128
bong_mode        = cvar             ;1=audio feedback of notes, 0=none
acc_mode         = cvar+1           ;1=search measure for identical accidental
update_mode      = cvar+2           ;1=update top of screen during scroll
pitch_mode       = cvar+3           ;1=go to nearest pitch, 0=stay in octave
insert_mode      = cvar+4           ;1=insert any notes/commands entered
tie_mode         = cvar+5           ;1=don't clear tie after entering note
j$speed          = cvar+6           ;Joystick speed in jiffies
mus_device       = cvar+7           ;Music file device
expand_value     = cvar+8           ;Reverb effect between channels
word_mode        = cvar+9           ;1=load and use .WDS files, 0=don't
cmd_update       = cvar+10          ;1=update command during scroll
midi_entry       = cvar+11          ;1=MIDI note entered, 0=no it's not
midi_channel     = cvar+12          ;6 MIDI channel defaults
aux_mode         = cvar+18          ;1=use AUX colors, 0=don't

num_menu         = config+160
menu_file        = num_menu+1
menu_name        = menu_file+8

;
;Initialization code
;

   sta interface_type
   lda #11
   sta 53265
   lda #128
   sta 650
   sta j$last

   lda 186
   sta pr_device

   lda #0
   sta applic          ;No transient applications in memory to start with
   lda #0
   sta midi_mode
   sta midi_note
   sta midi_phase
   sta 198

   lda #<buffer_loc    ;Nothing in the cut/paste buffer
   sta buf_ptr
   lda #>buffer_loc
   sta buf_ptr+1

   jsr get_str_mode

   jsr clear_all
   jsr accept_midi

;
;Initialize sprites
;

   lda #0
   sta bong_flag
   sta cut_flag
   ldx #<inter
   ldy #>inter
   jsr setirq

   lda #174
   sta vic
   lda #68
   sta vic+4
   sta vic+6
   sta vic+8
   lda #32
   sta vic+10
   sta vic+12

   ldy #sprite_block
   sty screen+1016
   iny
   sty screen+1017
   iny
   sty screen+1018
   iny
   sty screen+1019
   sty screen+1020
   iny
   sty screen+1021
   lda #0
   sta vic+16
   sta vic+$1c
   sta vic+$1b
   lda #1
   sta vic+$1d
   lda #32
   sta vic+$17
   lda #1
   sta vic+41
   lda #12
   sta vic+42
   sta vic+43
   lda #15
   sta vic+44
   sta vic+45

;-- Draw editing screen, display credits at top until a key is pressed --

   jsr draw_edit_screen
   jsr init_para
   jsr note_top
   jsr update_top
   jsr change_stat
   jsr place_sprite

   jsr print
   .byte defl,18,0,0,128+7
   .asc "Stereo Editor 1.0"
   .byte eof,defr,22,18,0,128+7
   .asc "By Robert A. Stoerrle"
   .byte eof,eot

   lda #27
   sta 53265

-  lda j$waiting
   bne +
   lda midi_note
   bne +
   lda 198
   beq -

+  jsr draw_top_line
   jsr update_top
   jmp edit

new_file = *

   jsr init_para
   jsr note_top
   jsr update_top
   jmp edit

;
;Interrupt routine to cycle through colors of edit sprite
;

inter = *

   bit midi_mode       ;If MIDI is disabled, bypass next check
   beq not_midi
   lda interface_type
   bpl +
   bit mctrl
   bpl not_midi
   jmp midi_irq_passport
+  bit $de02
   bpl not_midi
   jmp midi_irq_seq

not_midi = *

   lda vic+39          ;Voice cursor sprite flasher
   clc
   adc #1
   and #15
   bne +
   lda #1
+  sta vic+39

   lda 56320
   and #31
   eor #31
   cmp j$last
   beq +
   sta j$last
-  sta j$waiting
   lda j$speed
   sta j$speed_count
   bne ++
+  cmp #16
   bcs +
   dec j$speed_count
   beq -

+  lda bong_flag       ;Handle releasing "bong" notes in editor mode
   beq +
   dec bong_count
   bne +
   lda #0
   sta bong_flag
   lda #32
   sta sid+4

+  rts

;
;Translate MIDI note to note, octave, and accidental value for editor.
;

midi_translate = *

   lda midi_note       ;Get last MIDI note, AND for true value
   and #127
   ldy #8              ;Assume octave -1
-  cmp #12
   bcc +               ;Branch when 12 cannot be subtracted
   sbc #12
   dey                 ;Subtract and increment octave
   bpl -
+  sty e$octave
   tay
   lda step_note,y     ;Convert step index (0-11) to a pitch
   sta e$note_letter
   lda step_acc,y      ;Convert step index to accidental
   sta e$accidental
   rts

;
;Tables of step values (0-11).
;

step_note     .byte 1,1,2,2,3,4,4,5,5,6,6,7

step_acc      .byte natural,sharp,natural,sharp,natural,natural,sharp
              .byte natural,sharp,natural,sharp,natural

;
;Check for a stereo chip at address. Return with carry set if one is found,
;otherwise return with carry clear.
;

check_for_chip = *

   lda #0
   sta ptr
   sta ptr+1

   lda #255
cfca sta $de0f
   lda #8
cfcb sta $de11
   lda #$41
cfcc sta $de12
   ldx #1
   ldy #127

cfc0 lda $de1b
   bne cfc1
   stx ptr
   beq cfc2
cfc1 cmp #255
   bne no_cart
   stx ptr+1
cfc2 dey
   bpl cfc0

   lda ptr
   and ptr+1
   beq no_cart
   sec
   rts

no_cart clc
   rts

;
;Set STEREO_MODE based on chip configuration (checks both $DE00 and $DF00).
;

get_str_mode = *

   lda #0
   sta stereo_mode

   lda #$de
   sta cfca+2
   sta cfcb+2
   sta cfcc+2
   sta cfc0+2
   jsr check_for_chip
   bcc +
   inc stereo_mode
   rts

+  inc cfca+2
   inc cfcb+2
   inc cfcc+2
   inc cfc0+2
   jsr check_for_chip
   bcc +
   lda #2
   sta stereo_mode

+  rts

;
;Frequency tables for bong routines
;

freq_dbl     .word 38539,43258,38539,51443,57743,51443,57743,0

freq_flat    .word 32407,36376,40830,43258,48556,54502,61176,0

freq_natural .word 34334,38539,43258,45830,51443,57743,64814,0

freq_sharp   .word 36376,40830,45830,48556,54502,61176

;
;Sound a "bong" in current pitch on voice 1 of internal SID chip.
;

bong = *

   lda bong_mode
   beq no_bong

   ldx e$note_letter
   beq no_bong

   lda #$10            ;ATK 1, DCY 0
   sta sid+5
   lda #$f9            ;SUS 15, RLS 9
   sta sid+6
   lda #$0a            ;VOL 10
   sta sid+24

   lda e$octave
   sta temp

   dex
   ldy e$accidental
   cpy #sharp
   bne +
   cpx #b_note-1
   bne +
   ldx #c_note-1
   ldy #natural
   dec temp
   bmi no_bong
   
+  stx ptr
   tya
   and #3
   asl
   asl
   asl
   adc ptr
   asl
   tay
   lda freq_dbl,y
   sta ptr
   lda freq_dbl+1,y
   sta ptr+1

   ldy temp
   beq +
-  lsr ptr+1
   ror ptr
   dey
   bne -

+  lda ptr
   sta sid
   lda ptr+1
   sta sid+1
   lda #32+1
   sta sid+4
   lda #4
   sta bong_count
   lda #1
   sta bong_flag

no_bong rts


;
;Read joystick value (0-31).
;

read_joy = *

   sei
   ldy #0
   lda j$waiting
   sty j$waiting
   cli
   rts

;
;Search for a given measure marker in one or all voices.
;

search_meas = *

   jsr save_n_remove
   jsr print
   .byte box,12,10,28,14,7,xx+13,yy+11,col+1
   .asc "Search for MS#:"
   .byte xx+13,yy+13,tab,28,xx+13,eot

   lda #0
   sta low_range
   sta low_range+1
   lda #<999
   sta high_range
   lda #>999
   sta high_range+1

   jsr get_gen_num
   bcc +
   jsr recall_screen
   jmp da

+  jsr recall_screen
   ldy number
   lda number+1
   asl
   asl
   asl
   asl
   asl
   asl
   ora #%00011110
   sta number
   sty number+1

   lda move_mode
   bne +
   lda voice
   asl
   tax
   jsr msearch
   jmp ++
+  ldx #10
-  jsr msearch
   dex
   dex
   bpl -
+  jmp da

;
;Search voice for given MS# command (always from beginning of voice).
;

msearch = *

   lda voice_start,x
   sta ptr
   lda voice_start+1,x
   sta ptr+1

-  lda ptr
   cmp voice_end,x
   bne +
   lda ptr+1
   cmp voice_end+1,x
   beq msea2
+  ldy #0
   lda (ptr),y
   cmp number
   bne +
   iny
   lda (ptr),y
   cmp number+1
   beq msea1
+  lda ptr
   clc
   adc #2
   sta ptr
   bcc +
   inc ptr+1
+  jmp -

msea1 = *

   lda ptr
   sta voice_pos,x
   lda ptr+1
   sta voice_pos+1,x

msea2 = *

   rts

;
;Renumber measures in current voice.
;

renum_meas = *

   lda measure
   sta number
   lda measure+1
   sta number+1

   lda voice
   asl
   tax
   lda voice_pos,x
   sta ptr
   lda voice_pos+1,x
   sta ptr+1

-  lda ptr
   cmp voice_end,x
   bne +
   lda ptr+1
   cmp voice_end+1,x
   bne +
   jsr modify
   jmp rec_n_ret
+  lda ptr
   clc
   adc #2
   sta ptr
   bcc +
   inc ptr+1
+  ldy #0
   lda (ptr),y
   and #%00111111
   cmp #%00011110
   bne rmm
   inc number
   bne +
   inc number+1
+  lda number+1
   asl
   asl
   asl
   asl
   asl
   asl
   ora #%00011110
   sta (ptr),y
   iny
   lda number
   sta (ptr),y
rmm jmp -

;
;Remove measure markers in one or all voices
;

kill_meas = *

   jsr one_or_all
   bne +
   jsr one_moment_please
   lda voice
   asl
   tax
   jsr remove_ms
   jmp ++
+  jsr one_moment_please
   ldx #10
-  jsr remove_ms
   dex
   dex
   bpl -
+  jsr modify
   jmp rec_n_ret

;
;Subroutine to remove measure markers in voice in .X
;(Works backwards for efficiency).
;

remove_ms = *

   lda voice_end,x
   sta ptr
   lda voice_end+1,x
   sta ptr+1

-  ldy #0
   lda (ptr),y
   and #%00111111
   cmp #%00011110
   bne dnrm

   stx temp
   lda ptr
   sta dest_m
   clc
   adc #2
   sta start_m
   lda ptr+1
   sta dest_m+1
   adc #0
   sta start_m+1
   jsr usual_end
   jsr move_down
   ldx temp
   jsr adjust_two
   ldx temp
   jsr home_key

dnrm lda ptr
   sec
   sbc #2
   sta ptr
   bcs +
   dec ptr+1
+  lda ptr+1
   cmp voice_start+1,x
   bne +
   lda ptr
   cmp voice_start,x
+  bcs -

   rts

;
;Make clicking sound for when a measure is automatically entered.
;

click = *

   lda #15             ;Make this loud and distinguishable
   sta sid+24
   lda #$00            ;ATK 0, DCY 0
   sta sid+5+7
   lda #$f5            ;SUS 15, RLS 5
   sta sid+6+7
   lda #128            ;Frequency 128x256+128
   sta sid+0+7
   sta sid+1+7

   ldy #129
   sty sid+4+7
   dey
   sty sid+4+7
   rts

;
;Pause mode interrupt routine.
;

qinter = *

   lda $dc0d
   jmp exit_mirq

;
;Handle MIDI note input (Passport)
;

midi_irq_passport = *

   lda midi_phase      ;Branch if $9x already read
   bne +
   lda mdata           ;Get byte from interface
   and #$f0
   cmp #$90            ;If not $9x, exit
   bne exit_mirq
   inc midi_phase      ;Signify that $9x was found
   bne exit_mirq

+  cmp #1              ;Branch if note already read
   bne +
   lda mdata           ;Read note from interface
   ora #128
   sta midi_wait       ;Store value +128 until next IRQ
   inc midi_phase
   bne exit_mirq

+  lda mdata           ;Read velocity from interface
   beq +
   lda midi_wait       ;If not zero, store note where main program sees it
   sta midi_note
   lda #0              ;Reset to waiting_for_next_note phase
+  sta midi_phase

exit_mirq = *

   pla                 ;Call to this routine is a JSR. Must remove to bypass
   pla
   pla                 ;My IRQ pushes bank configuration on stack
   sta 1
   pla                 ;Restore registers, return to main program
   tay
   pla
   tax
   pla
   rti

;
;Handle MIDI note input (Sequential)
;

midi_irq_seq = *

   lda midi_phase      ;Branch if $9x already read
   bne +
   lda $de03           ;Get byte from interface
   and #$f0
   cmp #$90            ;If not $9x, exit
   bne exit_mirq
   inc midi_phase      ;Signify that $9x was found
   bne exit_mirq

+  cmp #1              ;Branch if note already read
   bne +
   lda $de03           ;Read note from interface
   ora #128
   sta midi_wait       ;Store value +128 until next IRQ
   inc midi_phase
   bne exit_mirq

+  lda $de03           ;Read velocity from interface
   beq +
   lda midi_wait       ;If not zero, store note where main program sees it
   sta midi_note
   lda #0              ;Reset to waiting_for_next_note phase
+  sta midi_phase

   jmp exit_mirq

;This routine converts a two-byte note or command into its onscreen
;representation (icon). Note data should be stored in CURRENT_NOTE.
;Based on that note, the D$ variables are set for easy access to note
;parameters. The screen text (two rows) is stored in ROW1_TEXT and
;ROW2_TEXT.

get_icon = *

   lda #3                ;Bits 0 and 1 of first byte will
   bit current_note      ;   be clear if it's a note.
   beq +
   jmp get_cmd_icon

+  lda current_note      ;Bits 2-3 give the duration.
   lsr
   lsr
   and #7
   sta d$duration

   lda current_note      ;Is the note tied to the next?
   and #64
   sta d$tie

   lda current_note      ;If bit 7 is set, it can be one
   bpl gi2               ;   of three things.
   and #32
   beq +
   lda d$duration
   bne op
   lda #duration_64
   sta d$duration
   bne +
op lda #double_dot       ;If dot bit is set, it's a double-dotted note.
   sta d$dot             
   bne note_byte2
+  lda #triplet          ;Otherwise, it's a triplet.
   sta d$dot
   bne note_byte2

gi2 lda #no_dot          ;Assume note is not dotted.
   sta d$dot
   lda current_note
   and #32
   beq note_byte2
   lda d$duration
   cmp #abs_pitch        ;Dotted absolute pitch is decoded as a 64th note.
   bne +
   lda #duration_64
   sta d$duration
   bne note_byte2
+  cmp #utility_dur      ;Dotted utility duration is decoded as utility voice.
   bne +
   lda #utility_voice
   sta d$duration
   bne note_byte2
+  lda #dot              ;Otherwise, it's just a normal dotted note.
   sta d$dot

note_byte2 = *           ;Process second byte of the note

   lda current_note+1
   lsr
   lsr
   lsr
   and #7
   sta d$octave          ;Octave number contained in bits 3-5

   lda current_note+1
   and #7
   sta d$note_letter     ;Note letter contained in bits 0-2

   lda current_note+1
   lsr
   lsr
   lsr
   lsr
   lsr
   lsr
   and #3
   beq +
   tay
   lda acc_table-1,y
   sta d$accidental      ;It's a normal accidental: natural, flat, or sharp
   bne done_note
+  ldy d$note_letter
   lda double_acc_table-1,y
   sta d$accidental      ;It's a double flat or double sharp

done_note = *            ;Now just call routines to get screen codes

   jsr get_pitch_text
   jmp get_dur_text      ;And exit

;
;This routine constructs in ROW1_TEXT the onscreen representation
;(3 characters) of the pitch in D$NOTE_LETTER, accidental in D$ACCIDENTAL
;and octave in D$OCTAVE.
;

get_pitch_text = *

   ldy #4                ;First, clear first row text
   lda #" "
-  sta row1_text,y
   dey
   bpl -

   ldy d$note_letter
   cpy #rest_note
   bne +
   lda #"("              ;Rests are handled differently
   sta row1_text
   lda #18+64            ;Screen code for "R"
   sta row1_text+1
   lda #")"
   sta row1_text+2
   rts

+  lda letter_table-1,y  ;Get screen code for note letter
   sta row1_text
   clc
   lda d$octave          ;Translate octave number to screen digit
   eor #7
   adc #48
   sta row1_text+2

   lda d$accidental      ;Get the redefined character for current accidental.
   clc
   adc #acc_char
   sta row1_text+1

   rts

;
;This routine returns in ROW2_TEXT the onscreen representation of
;the current duration value (based on D$DURATION and D$DOT).
;

get_dur_text = *

   lda #" "              ;Clear out second row text
   ldy #4
-  sta row2_text,y
   dey
   bpl -

   lda d$duration
   bne +                 ;If absolute duration, display that symbol
   lda #65               ;Screen code for "A"
   sta row2_text+1
   rts

+  cmp #utility_dur
   bne +                 ;If utility duration, display that symbol
   lda #21               ;Screen code for "u"
   sta row2_text+1
   bne cht

+  cmp #utility_voice
   bne +                 ;If utility voice, display that symbol
   lda #21               ;Screen code for "u"
   sta row2_text+1
   lda #64+22            ;Screen code for "V"
   sta row2_text+2
   bne cht

+  clc
   adc #dur_char-2       ;Convert to redefined character for duration
   sta row2_text+1

   lda d$dot
   beq cht               ;If no dot, leave the space there
   clc
   adc #dot_char-1       ;Otherwise, replace with appropriate redefined char.
   sta row2_text+2

cht lda d$tie            ;If note is tied to next note, install that symbol.
   beq +
   lda #tie_char
   sta row2_text+3
   lda #tie_char+1
   sta row2_text+4

+  rts

acc_table        .byte sharp,natural,flat
 
double_acc_table .byte double_sharp,double_sharp,double_flat,double_sharp
                 .byte double_sharp,double_flat,double_flat
 
letter_table     .byte 67,68,69,70,71,65,66      ;Screen codes for A-G

command_text     .scr "BMPFLTRNGSNCF-X3-OLFOP&V"
                 .scr "WAVF-M"
                 .scr "TALEND   "
                 .scr "ATKDCYSUSRLSRESVOL"
                 .scr "DEFCAL"
                 .scr "RUPRDN"
                 .scr "SRCDST"
                 .scr "UTLPNTHEDFLGVDPVRTAUXPVDPVRMAXUTVF-CHLD"
                 .scr "P-SF-SSCAAUT"
                 .scr "TEMTPSRTP"
                 .scr "P-WJIFDTNPORMS#"

bmp_text         .scr "UPDN"
noyes_text       .scr "NO YES"
wav_text         .scr "PST"
fm_text          .scr "HBL"

bin3_table       .byte 4,2,1

dec3_table       .byte 10,100

dec5_table       .word 10,100,1000,10000


simple_commands  .byte $16,$26,$36,$46,$76,$86,$b6,$c6,$d6
                 .byte $e6,$f6,$0e,$4e  ;$01 commands with 0-255 ranges

signed_commands  .byte $56,$66,$6e,$96  ;$01 commands with -127 to 127 range

table_commands   .byte $06,$a6,$2e      ;$01 commands requiring look-up tables

end_cmd_list = *

;
;Subroutine to convert a value less than 256 to ASCII digits and
;place them into ROW2_TEXT, removing leading zeros. Number given in .A
;

convert_neg_byte = *

   ldy #"-"
   sty row2_text
   ldy #1
   .byte $2c

convert_byte = *

   ldy #0
   sty row_pos           ;Current position in row is 0
   ldy #0
   sty num_flag

   ldx #1                ;Start with 100
-  ldy #0                ;We've subtracted 0 times
-  cmp dec3_table,x
   bcc +                 ;Branch if we can't subtract
   iny                   ;Increment digit and subtract
   sbc dec3_table,x
   bcs -
+  sta temp
   tya
   ora num_flag
   beq +                 ;If digit is zero and no digits printed, skip
   tya
   ora #48               ;Convert digit to ASCII
   ldy row_pos
   sta row2_text,y       ;Store digit
   inc row_pos
   inc num_flag
+  lda temp
   dex
   bpl --

   ldy row_pos           ;Store last digit regardless of value
   ora #48
   sta row2_text,y
   rts

;
;Current note is actually a command (Bits 0 and 1 of byte 1 are not
;zero). Convert it to a command index (d$command) and value (d$cmd_value).
;

get_cmd_index = *

   lda #0                ;Clear out command index and values
   sta d$cmd_value
   sta d$cmd_value+1
   sta d$cmd_sign
   sta d$command

   lda current_note
   cmp #1
   beq +
   jmp other_commands    ;If first byte is not 1, branch

+  lda current_note+1
   pha
   lsr
   lsr
   lsr
   lsr
   sta d$cmd_value       ;Get value of upper nybble
   pla
   and #15               ;Lower four bits = 3/11 denotes a series of commands
   cmp #11
   beq +
   cmp #3
   bne cmd_dec3

+  lda current_note+1
   bmi cmd_dec2          ;Bit 7 set means it's a DEF or CAL
   lsr                   ;Upper four bits will give exact command
   lsr
   lsr
   lsr                   ;Last LSR puts yes/no bit into carry flag
   sta d$command
   lda #0
   bcc +
   lda #1
+  sta d$cmd_value
   rts

cmd_dec2 = *

   lsr                   ;It's a DEF or CAL
   lsr
   lsr
   lsr                   ;Last LSR puts def/cal bit in carry flag
   ldy #def_cmd          ;Command index that corresponds to DEF
   bcc +
   iny                   ;Change to CAL token if bit 3 is set
+  sty d$command
   clc
   adc #8                ;Add 8 to get true DEF/CAL phrase number
   sta d$cmd_value
   rts

cmd_dec3 = *

   cmp #0                ;Lower nybble = 0 denotes DCY command
   bne cmd_dec4
   lda #dcy_cmd
   sta d$command
   rts

cmd_dec4 = *

   cmp #2                ;Lower nybble = 2 denotes CAL command
   bne cmd_dec5
   lda #cal_cmd
   sta d$command
   rts

cmd_dec5 = *

   cmp #6                ;Lower nybble = 6 denotes DEF command
   bne cmd_dec6
   lda #def_cmd
   sta d$command
   rts

cmd_dec6 = *

   cmp #7                ;Lower nybble = 7 could be WAV or F-M
   bne cmd_dec7
   lda current_note+1
   and #16
   bne +
   lda #wav_cmd          ;Bit 4 clear denotes WAV command
   sta d$command
   lsr d$cmd_value
   rts
+  lda #fm_cmd           ;Bit 4 set denotes F-M command
   sta d$command
   lsr d$cmd_value
   rts

cmd_dec7 = *

   cmp #8                ;Lower nybble 8 denotes RLS
   bne cmd_dec8
   lda #rls_cmd
   sta d$command
   rts

cmd_dec8 = *

   cmp #10               ;Lower nybble 10 signifies RES
   bne cmd_dec9
   lda #res_cmd
   sta d$command
   rts

cmd_dec9 = *

   cmp #14               ;Lower nybble 14 denotes VOL
   bne cmd_dec10
   lda #vol_cmd
   sta d$command
   rts

cmd_dec10 = *

   cmp #15               ;Lower nybble 15 denotes 5 commands
   bne cmd_dec11
   lda d$cmd_value
   bne +
   lda #tal_cmd          ;0 in upper nybble signifies TAL
   sta d$command
   rts
+  cmp #2
   bne +
   lda #end_cmd          ;2 in upper nybble represents END
   sta d$command
   rts
+  cmp #4
   bne +
   lda #hlt_cmd          ;4 in upper nybble denotes HLT
   sta d$command
   rts
+  and #8
   bne +
   lda #src_cmd          ;Bit 3 of upper nybble clear denotes SRC
   sta d$command
   lsr d$cmd_value
   rts
+  lda #dst_cmd          ;It's a DST command
   sta d$command
   lda d$cmd_value
   and #7
   lsr
   sta d$cmd_value
   rts

cmd_dec11 = *

   and #7
   cmp #1
   bne cmd_dec12
   lda #rup_cmd          ;Lower 3 bits = 1 denotes RUP
   sta d$command
-  lda current_note+1    ;Value is made up of bits 3-7
   lsr
   lsr
   lsr
   sta d$cmd_value
   rts

cmd_dec12 = *

   cmp #5
   bne cmd_dec13
   lda #rdn_cmd          ;Lower 3 bits = 5 denotes RDN
   sta d$command
   bne -                 ;Use RUP routine to get a value from 0-31

cmd_dec13 = *

   lda current_note+1    ;All that's left is ATK and SUS
   pha
   lsr
   lsr
   lsr
   and #15
   sta d$cmd_value       ;Value is bits 3-6
   pla
   bmi +                 ;Bit 7 set denotes SUS, clear signifies ATK
   lda #atk_cmd
   .byte $2c
+  lda #sus_cmd
   sta d$command
   rts

;
;Process commands whose first byte is NOT equal to 1.
;(Assumes first command byte is in .A)

other_commands = *

   ldy #end_cmd_list-simple_commands-1
-  cmp simple_commands,y
   beq +                 ;Look for commands whose second byte gives value
   dey
   bpl -
   jmp large_commands

+  tya                   ;Current command fits that category
   clc
   adc #utl_cmd          ;Determine its index
   sta d$command
   cpy #signed_commands-simple_commands
   bcs +
   lda current_note+1    ;Second byte always positive - store value
   sta d$cmd_value
   rts

+  cpy #table_commands-simple_commands
   bcs oc2
   lda current_note+1
-  sta temp              ;Convert signed binary to unsigned binary and sign
   bpl +
   inc d$cmd_sign
   lda #0
   sec
   sbc temp
+  sta d$cmd_value
   rts

oc2 lda d$command
   cmp #tps_cmd
   bne +
   ldy current_note+1    ;Look up correct TPS value (-95 to 95)
   lda tps_table,y
   jmp -

+  cmp #rtp_cmd
   bne +
   ldy current_note+1    ;Look up correct RTP value (-47 to 47)
   lda rtp_table,y
   jmp -

+  lda current_note+1    ;It's TEM

tem_trans = *

   lsr
   lsr                   ;Divide by 4 to get offset into 64 byte table
   tay
   lda tem_table,y
   sta d$cmd_value
   lda tem_table+1,y
   sta d$cmd_value+1
   rts

;
;Handle commands with values encoded in both first and second bytes.
;(Assumes first command byte is in .A)
;

large_commands = *

   and #15               ;Check lower nybble of first byte
   cmp #2
   bne +
   lda #pw_cmd           ;If 2, it's P-W
   sta d$command
   lda current_note      ;Upper 4 bits of byte 1 are bits 8-11 of value
-  lsr
   lsr
   lsr
   lsr
   sta d$cmd_value+1
   lda current_note+1    ;Second byte makes up bits 0-7 of value
   sta d$cmd_value
   rts

+  cmp #14
   bne lc2
   lda current_note      ;14 in lower nybble indicates MS# or JIF
   and #32
   bne +
   lda #ms_cmd           ;Bit 5 clear indicates MS$
   sta d$command
   lda current_note
   lsr
   lsr
   bpl -                 ;Bits 6-7 plus second byte make up value

+  lda #jif_cmd          ;Bit 5 set indicates JIF
   sta d$command
   lda current_note+1
   asl
   rol d$cmd_value+1
   asl
   rol d$cmd_value+1
   sta d$cmd_value
   lda current_note      ;Bits 6-7 contribute to 10 bit value
   lsr
   lsr
   lsr
   lsr
   lsr
   lsr
   ora d$cmd_value
   sta d$cmd_value
   lda d$cmd_value+1     ;JIF should be negated if positive value > 767
   cmp #3
   bne +
   inc d$cmd_sign
   lda #0
   sta d$cmd_value+1
   sbc d$cmd_value
   sta d$cmd_value
+  rts

lc2 cmp #10
   bne lc3
   lda #dtn_cmd          ;Lower nybble 10 indicates DTN
   sta d$command
   lda current_note+1
   sta d$cmd_value
   lda current_note      ;Bits 4-7 contribute to value
   lsr
   lsr
   lsr
   lsr
   lsr
   sta d$cmd_value+1
   bcc +
   lda #0
   sec
   sbc d$cmd_value
   sta d$cmd_value
   lda #8
   sbc d$cmd_value+1
   sta d$cmd_value+1
   inc d$cmd_sign
+  rts

lc3 lda #por_cmd         ;All that's left is POR
   sta d$command
   lda current_note+1
   sta d$cmd_value
   lda current_note      ;Bits 2-7 contribute to value
   lsr
   lsr
   sta d$cmd_value+1
   rts

;
;Convert a 2-byte signed binary number in d$cmd_value to an unsigned
;number with a separate sign byte.
;

adjust_signed = *

   lda d$cmd_value+1
   bpl +
   lda #0
   sec
   sbc d$cmd_value
   sta d$cmd_value
   lda #0
   sbc d$cmd_value+1
   sta d$cmd_value+1
   inc d$cmd_sign
+  rts

;
;Decode a command and set up its icon
;

get_cmd_icon = *

   jsr get_cmd_index

;
;Convert a command index and value into a command icon.
;

cmd_to_icon = *

   lda d$command         ;Get command index
   asl
   adc d$command         ;Multiply by 3
   tay
   ldx #0
-  lda command_text,y    ;Copy appropriate command text to row 1
   sta row1_text,x
   iny
   inx
   cpx #3
   bcc -

   lda #" "              ;Clear out extra two spaces on row 1
   sta row1_text+3
   sta row1_text+4
   ldy #4
-  sta row2_text,y       ;And all of second row
   dey
   bpl -

   lda d$command
   bne +                 ;Branch forward if not BMP command

   lda d$cmd_value       ;Convert 0 or 1 to "UP" or "DN"
   asl
   tay
   lda bmp_text,y
   sta row2_text
   lda bmp_text+1,y
   sta row2_text+1
   rts

+  cmp #wav_cmd
   bcs +                 ;Branch forward if not a yes/no command

   cmp #lfo_cmd          ;Exception is LFO, which has a 0 or 1 value
   bne ci1
   lda d$cmd_value
   jmp convert_byte

ci1 lda d$cmd_value      ;Convert 0 or 1 to "NO " or "YES"
   asl
   adc d$cmd_value
   tay
   lda noyes_text,y
   sta row2_text
   lda noyes_text+1,y
   sta row2_text+1
   lda noyes_text+2,y
   sta row2_text+2
   rts

+  cmp #wav_cmd          ;Branch forward if not WAV command
   bne ci2

   lda d$cmd_value       ;Check command value
   bne +
show_n lda #"n"          ;If it's zero, it's noise ("N") waveform.
   sta row2_text
   rts
+  ldx #0                ;Not zero, so .X is position in row 2 text
   ldy #2                ;.Y is index into binary table.
-  lda d$cmd_value
   and bin3_table,y      ;Is current bit set?
   beq +
   lda wav_text,y        ;Yes - add waveform designation to row 2
   sta row2_text,x
   inx
+  dey
   bpl -
   rts

ci2 cmp #fm_cmd          ;Branch forward if not F-M command
   bne ci3

   lda d$cmd_value       ;Check command value
   beq show_n            ;If it's zero, it's "N".
   ldx #0                ;Not zero, so .X is position in row 2
   ldy #2                ;.Y is index into binary table
-  lda d$cmd_value
   and bin3_table,y      ;Is current bit set
   beq +
   lda fm_text,y         ;Yes - add filter mode designation to row
   sta row2_text,x
   inx
+  dey
   bpl -
-  rts

ci3 cmp #atk_cmd         ;TAL, END, and HLT commands have no value
   bcc -

   cmp #ps_cmd
   bcs +

   lda d$cmd_value       ;For commands with values 0-255
   jmp convert_byte

+  lda d$cmd_value+1
   bne ci4
   lda d$cmd_value       ;For commands with values -255 to 255
   ldy d$cmd_sign
   bne +
   jmp convert_byte
+  jmp convert_neg_byte

ci4 lda d$cmd_sign       ;Handle numbers greater than 255 or less than -255
   beq +
   ldy #"-"
   sty row2_text
   ldy #1
   .byte $2c
+  ldy #0
   sty row_pos           ;Current position in row is 0
   ldy #0
   sty num_flag          ;No zeros printed yet

   ldx #6                ;Start with 10000
-  ldy #0                ;We've subtracted 0 times
-  lda d$cmd_value+1
   cmp dec5_table+1,x
   bne +
   lda d$cmd_value
   cmp dec5_table,x
+  bcc +                 ;Branch if we can't subtract
   iny                   ;Increment digit and subtract
   lda d$cmd_value
   sec
   sbc dec5_table,x
   sta d$cmd_value
   lda d$cmd_value+1
   sbc dec5_table+1,x
   sta d$cmd_value+1
   bcs -
+  tya
   ora num_flag
   beq +                 ;If digit is zero and no digits printed, skip
   tya
   ora #48               ;Convert digit to ASCII
   ldy row_pos
   sta row2_text,y       ;Store digit
   inc row_pos
   inc num_flag
+  lda temp
   dex
   dex
   bpl --

   ldy row_pos           ;Store last digit regardless of value
   lda d$cmd_value
   ora #48
   sta row2_text,y
   rts

;
;Quick look-up table for TPS (192 bytes).
;

tps_table = *

   .byte $54,$f5,$48,$e9,$3c,$dd,$30,$d1,$24,$c5,$18,$b9,$0c,$ad,$00,$a1
   .byte $55,$f6,$49,$ea,$3d,$de,$31,$d2,$25,$c6,$19,$ba,$0d,$ae,$01,$a2
   .byte $56,$f7,$4a,$eb,$3e,$df,$32,$d3,$26,$c7,$1a,$bb,$0e,$af,$02,$a3
   .byte $57,$f8,$4b,$ec,$3f,$e0,$33,$d4,$27,$c8,$1b,$bc,$0f,$b0,$03,$a4
   .byte $58,$f9,$4c,$ed,$40,$e1,$34,$d5,$28,$c9,$1c,$bd,$10,$b1,$04,$a5
   .byte $59,$fa,$4d,$ee,$41,$e2,$35,$d6,$29,$ca,$1d,$be,$11,$b2,$05,$a6
   .byte $5a,$fb,$4e,$ef,$42,$e3,$36,$d7,$2a,$cb,$1e,$bf,$12,$b3,$06,$a7
   .byte $5b,$fc,$4f,$f0,$43,$e4,$37,$d8,$2b,$cc,$1f,$c0,$13,$b4,$07,$a8
   .byte $5c,$fd,$50,$f1,$44,$e5,$38,$d9,$2c,$cd,$20,$c1,$14,$b5,$08,$a9
   .byte $5d,$fe,$51,$f2,$45,$e6,$39,$da,$2d,$ce,$21,$c2,$15,$b6,$09,$aa
   .byte $5e,$ff,$52,$f3,$46,$e7,$3a,$db,$2e,$cf,$22,$c3,$16,$b7,$0a,$ab
   .byte $5f,$00,$53,$f4,$47,$e8,$3b,$dc,$2f,$d0,$23,$c4,$17,$b8,$0b,$ac

;
;Quick look-up table for RTP (180 bytes).
;

rtp_table = *

   .byte $00,$00,$00,$f5,$e9,$dd,$d1,$00,$00,$00,$00,$f6,$ea,$de,$d2,$00
   .byte $00,$00,$00,$f7,$eb,$df,$d3,$00,$00,$00,$00,$f8,$ec,$e0,$d4,$00
   .byte $00,$00,$00,$f9,$ed,$e1,$d5,$00,$00,$00,$00,$fa,$ee,$e2,$d6,$00
   .byte $00,$00,$00,$fb,$ef,$e3,$d7,$00,$00,$00,$00,$fc,$f0,$e4,$d8,$00
   .byte $00,$00,$00,$fd,$f1,$e5,$d9,$00,$00,$00,$00,$fe,$f2,$e6,$da,$00
   .byte $00,$00,$00,$ff,$f3,$e7,$db,$00,$24,$18,$0c,$00,$f4,$e8,$dc,$00
   .byte $25,$19,$0d,$01,$00,$00,$00,$00,$26,$1a,$0e,$02,$00,$00,$00,$00
   .byte $27,$1b,$0f,$03,$00,$00,$00,$00,$28,$1c,$10,$04,$00,$00,$00,$00
   .byte $29,$1d,$11,$05,$00,$00,$00,$00,$2a,$1e,$12,$06,$00,$00,$00,$00
   .byte $2b,$1f,$13,$07,$00,$00,$00,$00,$2c,$20,$14,$08,$00,$00,$00,$00
   .byte $2d,$21,$15,$09,$00,$00,$00,$00,$2e,$22,$16,$0a,$00,$00,$00,$00
   .byte $2f,$23,$17,$0b

;
;Quick look-up table for TEM (32 words).
;

tem_table = *

   .word 56,1800,900,600,450,360,300,257
   .word 225,200,180,163,150,138,128,120
   .word 112,105,100,94,90,85,80,78
   .word 75,72,69,66,64,62,60,58

draw_note_top = *

   jsr note_top
   jsr update_top

edit jsr change_stat

da jsr place_sprite
   jsr disp_all

dc lda update_mode
   beq +
   jsr show_current
+  jsr eval_measure

db lda midi_note
   beq +
   jsr midi_translate
   lda #0
   sta midi_note
   jsr change_stat
   lda midi_entry
   beq +
   jmp enter_note

+  jsr read_joy
   beq +
   jmp joy_translate

+  jsr getin
   beq db

   ldy #ek1-edit_key-1
-  cmp edit_key,y
   beq +
   dey
   bpl -
   bmi db

+  cpy #ek0-edit_key
   bcs dd
   tya
   asl
   tay
   lda key_vec,y
   sta proc+1
   lda key_vec+1,y
   sta proc+2
   lda move_mode
   beq +

   ldx #10
-  jsr proc
   dex
   dex
   bpl -
   jmp da

+  lda voice
   asl
   tax
   jsr proc
update_one lda voice
   jsr disp_voice
   jmp dc

dd tya
   tax
   asl
   tay
   lda key_vec+1,y
   pha
   lda key_vec,y
   pha
   rts

proc jmp $ffff

;
;Handle cursor right
;

cur_right = *

   lda voice_pos+1,x
   cmp voice_end+1,x
   bne +
   lda voice_pos,x
   cmp voice_end,x
+  bcs +
   lda voice_pos,x
   clc
   adc #2
   sta voice_pos,x
   bcc +
   inc voice_pos+1,x
+  rts

;
;Handle cursor left
;

cur_left = *

   lda voice_pos+1,x
   cmp voice_start+1,x
   bne +
   lda voice_pos,x
   cmp voice_start,x
   beq ++
+  lda voice_pos,x
   sec
   sbc #2
   sta voice_pos,x
   bcs +
   dec voice_pos+1,x
+  rts

;
;Handle cursor down
;

cur_down = *

   jsr reject_cut
   ldy voice
   iny
   cpy #6
   bcc +
   ldy #0
+  sty voice
   jsr show_voice_staff
   jsr place_sprite
   jmp dc

;
;Handle cursor up
;

cur_up = *

   jsr reject_cut
   ldy voice
   dey
   bpl +
   ldy #5
+  sty voice
   jsr show_voice_staff
   jsr place_sprite
   jmp dc

;
;Handle HOME keypress (go to beginning of voice)
;

home_key = *

   lda voice_start,x
   sta voice_pos,x
   lda voice_start+1,x
   sta voice_pos+1,x
   rts

;
;Handle CLR keypress (go to end of voice)
;

clr_key = *

   lda voice_end,x
   sta voice_pos,x
   lda voice_end+1,x
   sta voice_pos+1,x
   rts

;
;Go to next measure
;

next_meas = *

   ldy #0
-  lda voice_pos,x
   cmp voice_end,x
   bne +
   lda voice_pos+1,x
   cmp voice_end+1,x
   beq nm1
+  lda voice_pos,x
   clc
   adc #2
   sta voice_pos,x
   sta ptr
   lda voice_pos+1,x
   adc #0
   sta voice_pos+1,x
   sta ptr+1
   lda (ptr),y
   and #%00111111
   cmp #$1e
   bne -
nm1 rts

;
;Go to previous measure
;

last_meas = *

   ldy #0
-  lda voice_pos,x
   cmp voice_start,x
   bne +
   lda voice_pos+1,x
   cmp voice_start+1,x
   beq nm2
+  lda voice_pos,x
   sec
   sbc #2
   sta voice_pos,x
   sta ptr
   lda voice_pos+1,x
   sbc #0
   sta voice_pos+1,x
   sta ptr+1
   lda (ptr),y
   and #%00111111
   cmp #$1e
   bne -
nm2 rts

;
;Toggle movement mode between single voice and all voices
;

switch_move = *

   lda move_mode
   eor #1
   sta move_mode
   jsr place_sprite
   jmp dc

;
;Set octave (keys 0-7)
;

eo = *

   txa
   sec
   sbc #ek_octave-edit_key
   eor #7
   sta e$octave
   jsr restore_e$
   jsr bong
   jsr change_stat
   jmp db

;
;Toggle rest
;

erest = *

   lda e$note_letter
   bne +
   jsr restore_e$
   jmp ++

+  lda e$note_letter
   sta r$note_letter
   lda e$accidental
   sta r$accidental
   lda #0
   sta e$note_letter
   lda #natural
   sta e$accidental

+  jsr bong
   jsr change_stat
   jmp db

;
;Set pitch (C-B)
;

en = *

   ldy #natural
   txa
   sec
   sbc #ek_note-edit_key
   sta temp
   ldx pitch_mode
   beq en2
   cmp r$note_letter
   bcc +
   sbc r$note_letter
   cmp #4
   bcc en2
   lda e$octave
   cmp #7
   beq en2
   inc e$octave
   bne en2

+  lda r$note_letter
   sec
   sbc temp
   cmp #4
   bcc en2
   lda e$octave
   beq en2
   dec e$octave

en2 lda temp
   sta e$note_letter
   sta r$note_letter

   jsr measure_acc
   bcs en3

   ldy #natural
   ldx e$note_letter
   lda bin_up-1,x
   ldx key
   and key_table,x
   beq +

   ldy #sharp
   lda key_table,x
   bpl +
   ldy #flat

+  sty e$accidental
   sty r$accidental
   
en3 jsr bong
   jsr change_stat
   jmp db

;
;Set accidental
;

ea = *

   txa
   pha
   jsr restore_e$
   pla

   sec
   sbc #ek_acc-edit_key
   cmp #double_sharp
   beq +
   cmp #double_flat
   bne ++
+  ldy e$note_letter
   beq nch
   cmp double_acc_table-1,y
   bne nch
+  sta e$accidental
   sta r$accidental
   jsr bong
   jsr change_stat
nch jmp db

;
;Toggle tie
;

e_tie = *

   lda e$duration
   cmp #abs_pitch
   beq +
   lda e$tie
   eor #64
   sta e$tie
   jsr change_stat
+  jmp db

;
;Set duration
;

ed = *

   txa
   sec
   sbc #ek_dur-edit_key
ed2 sta e$duration
   ldy #0
   sty e$dot
   cmp #abs_pitch
   bne +
   sty e$tie
+  jsr change_stat
   jmp db

;
;Set triplet if possible
;

e_trip = *

   lda e$dot
   cmp #triplet
   bne +
   lda #0
   beq rt
+  lda e$duration
   cmp #half_note
   bcc +
   cmp #utility_voice
   beq +
   lda #triplet
rt sta e$dot
   jsr change_stat
+  jmp db

;
;Set dot if possible
;

e_dot = *

   lda e$dot
   cmp #dot
   bne +
   lda #0
   beq rd
+  lda e$duration
   cmp #whole_note
   bcc +
   cmp #duration_64
   bcs +
   lda #dot
rd sta e$dot
   jsr change_stat
+  jmp db

;
;Set double dot if possible
;

e_dd = *

   lda e$dot
   cmp #double_dot
   bne +
   lda #0
   beq qr
+  lda e$duration
   cmp #whole_note
   bcc +
   cmp #duration_32
   bcs +
   lda #double_dot
qr sta e$dot
   jsr change_stat
+  jmp db

;
;Delete note at cursor unless at end of voice.
;

del_note = *

   jsr reject_cut
   jsr at_end
   bcs +
   jsr close1
   jsr modify
+  jmp da

;
;Insert HLT command at current position in current voice
;

ins_note = *

   jsr reject_cut
   jsr at_end
   bcs +
   jsr open1
   ldy #0
   lda #$01       ;HLT command
   sta (ptr),y
   iny
   lda #$4f
   sta (ptr),y
   jsr modify
+  jmp da

;
;Move one or all voices forward one position
;

move_forward = *

   lda move_mode
   bne +

   lda voice
   asl
   tax
   jmp cur_right

+  ldx #10
-  jsr cur_right
   dex
   dex
   bpl -
   rts

;
;Return with carry set if at end of voice, clear otherwise.
;Also puts address of current note in PTR.
;

at_end = *

   lda voice
   asl
   tax
   lda voice_pos+1,x
   sta ptr+1
   lda voice_pos,x
   sta ptr
   cmp voice_end,x
   bne +
   lda voice_pos+1,x
   cmp voice_end+1,x
   bne +
   sec
   rts
+  clc
   rts

;
;Encode note with current parameters
;

encode_note = *

   ldy e$accidental
   lda e$octave
   asl
   asl
   asl
   ora e$note_letter
   ora encode_acc,y
   sta current_note+1

   lda e$duration
   cmp #abs_pitch
   bne +
   lda #0
   sta current_note
   rts

+  lda e$tie
   sta current_note

   lda e$duration
   cmp #duration_64
   bne +
   lda e$dot
   cmp #triplet
   bne +
   lda current_note
   ora #%10100000
   sta current_note
   rts

+  lda e$duration
   cmp #utility_voice
   bne +
   lda current_note
   ora #%00100100
   sta current_note
   rts

+  lda e$dot
   cmp #triplet
   bne +
   lda current_note
   ora #%10000000
   sta current_note

+  lda e$duration
   cmp #utility_dur
   bne +
   lda current_note
   ora #%00000100
   sta current_note
   rts

+  cmp #duration_64
   bne +
   lda current_note
   ora #%00100000
   sta current_note
   rts

+  lda e$dot
   cmp #dot
   bne +
   lda current_note
   ora #%00100000
   sta current_note

+  lda e$dot
   cmp #double_dot
   bne +
   lda current_note
   ora #%10100000
   sta current_note

+  lda e$duration
   asl
   asl
   ora current_note
   sta current_note
   rts

;
;Insert note/command at current position in current voice
;

open1 = *

   lda voice_start+13
   cmp #$cf
   bcc +
   lda #3
   sta ptr+1
   jmp check_memory

+  lda voice
   asl
   tax
   lda voice_pos,x
   sta start_m
   clc
   adc #2
   sta dest_m
   lda voice_pos+1,x
   sta start_m+1
   adc #0
   sta dest_m+1
   lda voice_pos+12
   sta end_m
   lda voice_pos+13
   sta end_m+1
   jsr move_up

   lda voice
   asl
   tax
   lda voice_end,x
   clc
   adc #2
   sta voice_end,x
   bcc +
   inc voice_end+1,x
+  inx
   inx
-  lda voice_start,x
   clc
   adc #2
   sta voice_start,x
   bcc +
   inc voice_start+1,x
+  lda voice_end,x
   clc
   adc #2
   sta voice_end,x
   bcc +
   inc voice_end+1,x
+  lda voice_pos,x
   clc
   adc #2
   sta voice_pos,x
   bcc +
   inc voice_pos+1,x
+  inx
   inx
   cpx #14
   bcc -

   rts

;
;Close up space at current position
;

close1 = *

   lda voice
   asl
   tax
   lda voice_pos,x
   sta dest_m
   clc
   adc #2
   sta start_m
   lda voice_pos+1,x
   sta dest_m+1
   adc #0
   sta start_m+1
   lda voice_pos+12
   sta end_m
   lda voice_pos+13
   sta end_m+1
   jsr move_down

   lda voice
   asl
   tax
   jsr adjust_two

   rts

;
;Update note display for voice whose number (0-5) is in .A
;

disp_voice = *

   sta dvoice
   asl
   tax
   lda voice_start,x     ;Localize all pointers for this voice
   sta disp_start
   lda voice_start+1,x
   sta disp_start+1
   lda voice_end,x
   sta disp_end
   lda voice_end+1,x
   sta disp_end+1
   lda voice_pos,x       ;Start 3 commands/notes to the left
   sta cut_ptr
   sec
   sbc #6
   sta ptr
   lda voice_pos+1,x
   sta cut_ptr+1
   sbc #0
   sta ptr+1

   lda voice_row,x       ;Get address of screen lines for rows 1 and 2
   sta row1_ptr
   clc
   adc #40
   sta row2_ptr
   lda voice_row+1,x
   sta row1_ptr+1
   adc #0
   sta row2_ptr+1

   lda #128
   sta temp2
   lda #7                ;7 slots per row
   sta slot_count

dr lda ptr+1             ;If pointer is under start of voice, blank slot
   cmp disp_start+1
   bne +
   lda ptr
   cmp disp_start
+  bcc s_blank
   
   lda ptr+1             ;If pointer is above end of voice, blank slot
   cmp disp_end+1
   bne +
   lda ptr
   cmp disp_end
+  bcs s_blank

   lda cut_flag
   beq +
   lda voice
   cmp dvoice
   bne +

   jsr check_region
   sta temp2

+  ldy #0                ;Pointer in range. Decode icon and display it.
   lda (ptr),y
   sta current_note
   iny
   lda (ptr),y
   sta current_note+1
   jsr get_icon
   ldy #4
-  lda row1_text,y
   ora temp2
   sta (row1_ptr),y
   lda row2_text,y
   ora temp2
   sta (row2_ptr),y
   dey
   bpl -
   bmi +

s_blank ldy #4           ;Pointer out of range - slot is blank
   lda #160
-  sta (row1_ptr),y
   sta (row2_ptr),y
   dey
   bpl -

+  lda row1_ptr          ;Move one slot to right
   clc
   adc #5
   sta row1_ptr
   bcc +
   inc row1_ptr+1

+  lda row2_ptr
   clc
   adc #5
   sta row2_ptr
   bcc +
   inc row2_ptr+1

+  lda ptr               ;Get next note/command address
   clc
   adc #2
   sta ptr
   bcc +
   inc ptr+1

+  dec slot_count
   bne dr
   rts
   
;
;Update display of all 6 voices
;

disp_all = *

   lda #5
-  sta voice_count
   jsr disp_voice
   lda voice_count
   sec
   sbc #1
   bcs -
   rts

;
;Display reverse color boxes for voice data
;

draw_edit_screen = *

   lda #yy+13
   jsr printchar
   ldx #2
-  jsr print
   .byte xx+0,col+7
   .asc "VOC"
   .byte col+15,xx+4,rvs,tab,39,13,xx+4,tab,39,rvsoff,13,col+7
   .asc "VOC"
   .byte col+12,xx+4,rvs,tab,39,13,xx+4,tab,39,rvsoff,13,eot
   dex
   bpl -

   jsr print
   .byte col+13,xx+1,yy+14,"1",xx+1,yy+16,"2",xx+1,yy+18,"3"
   .byte xx+1,yy+20,"4",xx+1,yy+22,"5",xx+1,yy+24,"6",eot

draw_top_line = *

   jsr print
   .byte xx+0,yy+0,col+7,rvs
   .asc "MS#"
   .byte tab,9
   .asc "Key:"
   .byte tab,22
   .asc "Time:"
   .byte tab,40,rvsoff,eot

   rts

;
;Draw top of screen for note editing
;

note_top = *

   jsr clear_top

   jsr print
   .byte col+11,xx+15,yy+6
   .asc "TIE"
   .byte eot

   ldy #39
-  lda #11
   sta 12*40+55296,y
   lda #128+64
   sta 12*40+screen,y
   dey
   bpl -

   ldy #0
   lda #6
-  sta 55296+80,y
   iny
   bne -

   ldy #box_char
   sty screen+94
   sty screen+99
   sty screen+214
   iny
   sty screen+98
   sty screen+102
   sty screen+218
   iny
   sty screen+174
   sty screen+179
   sty screen+294
   iny
   sty screen+178
   sty screen+182
   sty screen+298
   iny
   sty screen+134
   sty screen+138
   sty screen+139
   sty screen+142
   sty screen+254
   sty screen+258
   iny
   tya
   ldy #2
-  sta screen+95,y
   sta screen+175,y
   sta screen+215,y
   sta screen+295,y
   dey
   bpl -
   sta screen+100
   sta screen+101
   sta screen+180
   sta screen+181

   lda #1
   sta 55296+135
   sta 55296+136
   sta 55296+137
   sta 55296+140
   sta 55296+141

   ldx #26
   ldy #2
   jsr get_adr

   ldx #4
-  ldy #13
-  lda #1
   sta (start_m),y
   lda piano_top,y
   sta (txtptr),y
   dey
   bpl -
   jsr add40p
   dex
   bne --

   ldx #3
-  ldy #13
-  lda #1
   sta (start_m),y
   lda piano_bot,y
   sta (txtptr),y
   dey
   bpl -
   jsr add40p
   dex
   bne --

;
;Create staff lines/sprites based on staff number
;(0=grand staff, 1=treble staff).
;

draw_staff = *

   lda staff_type
   bne +
   ldy #3
   jsr draw_lines
   ldy #6
   jsr draw_lines
   jmp ++
+  ldy #5
   jsr draw_lines

+  ldy staff_type
   lda staff_y5,y
   sta vic+11
   lda staff_y6,y
   sta vic+13
   lda staff_sprite,y
   sta screen+1016+6
   
   ldx #63
   lda #0
-  sta staff_pos,x
   dex
   bpl -

   ldx staff_start,y
   lda staff_end,y
   sta temp
   ldy #137
-  tya
   sta staff_pos,x
   dey
   dey
   inx
   txa
   and #%00000111
   bne +
   inx
+  cpx temp
   bcc -

   rts

;
;Sprite positioning tables for various staves
;

staff_y5    .byte 69,85,0,0,0,0
staff_y6    .byte 101,0,93,89,93,101

staff_start .byte 9,18,4,9,11,15
staff_end   .byte 55,63,49,54,56,60

staff_sprite  .byte 101,101,101,102,102,102

;
;Add 40 to TXTPTR and START_M
;

add40p = *

   lda txtptr
   clc
   adc #40
   sta txtptr
   sta start_m
   bcc +
   inc txtptr+1
   inc start_m+1
+  rts

;
;Draw lines at screen row in .Y
;

draw_lines = *

   ldx #1
   jsr get_adr
   ldx #0
-  ldy #9
-  lda #12
   sta (start_m),y
   lda line_table,x
   sta (txtptr),y
   dey
   bpl -
   jsr add40p
   inx
   cpx #3
   bne --

   rts

;
;Data used in creating staff display
;

line_table    .byte line_char,line_char,line_char+1

;
;Data used in creating piano display
;

piano_top     .byte 160,piano_char,piano_char+1,piano_char
              .byte piano_char+1,160,piano_char+130,piano_char
              .byte piano_char+1,piano_char,piano_char+1,piano_char
              .byte piano_char+1,160

piano_bot     .byte 160,160,piano_char+130,160
              .byte piano_char+130,160,piano_char+130,160
              .byte piano_char+130,160,piano_char+130,160
              .byte piano_char+130,160

;
;Update key value at top of screen, as well as time signature display.
;

update_top = *

   lda key
   jsr key_to_text
   ldy #6
-  lda text,y
   ora #128
   sta screen+14,y
   dey
   bpl -

   jsr print
   .byte yy+0,xx+28,col+7,rvs,eot
   lda time_top
   jsr printbyte
   lda #"/"
   jsr printchar
   lda time_bot
   jsr printbyte
   jsr print
   .byte tab,34,rvsoff,eot

   rts

;
;Display editor sprite in proper position for current voice
;Also enables clef sprites.
;

place_sprite = *

   lda vic+21
   ora #1+32+64
   sta vic+21

place_sprite1 = *

   ldy voice
   lda sprite_y,y
   sta vic+1

   ldx #5
-  txa
   asl
   tay
   lda voc_adr,y
   sta ptr
   lda voc_adr+1,y
   sta ptr+1
   lda move_mode
   bne co7
   cpx voice
   beq co7
   lda #0
   .byte $2c
co7 lda #128
   sta temp
   ldy #0
   lda (ptr),y
   and #127
   ora temp
   sta (ptr),y
   dex
   bpl -
   rts

;
;Show stats for current note at top of screen
;

show_current = *

   lda voice
   asl
   tax
   lda voice_pos,x
   sta ptr
   lda voice_pos+1,x
   sta ptr+1
   ldy #1
   lda (ptr),y
   sta current_note+1
   dey
   lda (ptr),y
   sta current_note
   and #3
   bne cs3

   jsr get_icon
   jsr bong_sub

play_show = *

cs2 = *

   ldy #2
-  lda row1_text,y
   sta screen+135,y
   dey
   bpl -
   lda row2_text+1
   sta screen+140
   lda row2_text+2
   sta screen+141

   lda #1
   ldy d$tie
   bne +
cs3 lda #0
   sta e$tie
   lda #11
+  sta 55296+255
   sta 55296+256
   sta 55296+257

   lda e$note_letter
   bne +
   jmp rem_s1
+  lda vic+21
   ora #2+4+8+16
   sta vic+21
   lda e$accidental
   and #3
   asl
   asl
   asl
   adc e$note_letter
   tay
   ldx piano_key,y
   lda #108
   ldy #2
   cpx #7
   bcc +
   lda #78
   ldy #13
+  sta vic+3
   sty vic+40
   lda piano_x,x
   sta vic+2
   lda piano_x9,x
   sta vic+16

   lda e$octave
   eor #7
   asl
   asl
   asl
   adc e$note_letter
   tay
   lda staff_pos,y
   sta vic+5
   ldx staff_type
   bne +
   lda grand_table,y
   sta vic+7
   lda #0
   sta vic+9
   rts

+  ora #0
   beq outs
   sec
   sbc #59
   lsr
   tay
   lda other_stab,y
   bne +
   sta vic+7
   sta vic+9
   rts
+  pha
   and #63
   clc
   adc #59
   sta vic+7
   pla
   bpl vsf
   and #64
   bne +
   lda vic+7
   clc
   adc #20
-  sta vic+9
   rts
+  lda vic+7
   beq vsf
   sec
   sbc #20
   bcs -
vsf lda #0
   beq -

outs lda e$octave
   cmp #4
   bcs +
   lda #59
   sta vic+7
   lda #79
   sta vic+9
   rts
+  lda #119
   sta vic+7
   lda #99
   sta vic+9
   rts

;
;Remove piano and staff sprites
;

rem_s1 = *

   lda vic+21
   and #%11100001
   sta vic+21
   rts

;
;Piano key numbers used for various natural, sharp, etc. notes
;

piano_key       .byte 0,1,2,1,4,5,4,5
                .byte 0,6,7,8,2,9,10,11
                .byte 0,0,1,2,3,4,5,6
                .byte 0,7,8,3,9,10,11,0

piano_x         .byte 236,253,13,29,45,61,77,244,4,36,52,68

piano_x9        .byte 0,0,2,2,2,2,2,0,2,2,2,2

;
;Update boxes at top of screen from e$ variables.
;

change_stat = *

   ldy #e$accidental-e$duration
-  lda e$duration,y
   sta d$duration,y
   dey
   bpl -

   jsr get_pitch_text
   jsr get_dur_text
   jmp cs2

;
;Address of first slot on screen for each voice (0-5).
;

voice_row                .word 62988,63068,63148,63228,63308,63388

;
;Sprite Y coordinates for voices 0-5
;

sprite_y                 .byte 153,169,185,201,217,233

;
;Voice number addresses for VOC 0-6 display at left of screen
;

voc_adr                  .word screen+561,screen+641,screen+721
                         .word screen+801,screen+881,screen+961

;
;Edit key function vectors
;

key_vec                  .word cur_right,cur_left,home_key,clr_key
                         .word next_meas,last_meas
                         .word cur_down-1,cur_up-1,switch_move-1
                         .word erest-1,en-1,en-1,en-1,en-1,en-1,en-1,en-1
                         .word eo-1,eo-1,eo-1,eo-1,eo-1,eo-1,eo-1,eo-1
                         .word ea-1,ea-1,ea-1,ea-1,ea-1
                         .word e_tie-1,enter_note-1,del_note-1,ins_note-1
                         .word ed-1,ed-1,ed-1,ed-1,ed-1
                         .word ed-1,ed-1,ed-1,ed-1,ed-1
                         .word e_trip-1,e_dot-1,e_dd-1
                         .word f7_menu-1,select_command-1,enter_meas-1
                         .word play_sid-1,chg_staff-1,chg_key-1,search_meas-1
                         .word play_all-1,joy_up-1,joy_down-1,joy_left-1
                         .word joy_right-1

;
;Sharps and flats in octave in various keys.
;Bit 7 : 0=Sharp, 1=Flat     3 : 0=F nat, 1=F S/F
;    6 : 0=B nat, 1=B S/F    2 : 0=E nat, 1=E S/F
;    5 : 0=A nat, 1=A S/F    1 : 0=D nat, 1=D S/F
;    4 : 0=G nat, 1=G S/F    0 : 0=C nat, 1=C S/F
;

key_table                .byte %00000000,%00001000,%00001001,%00011001
                         .byte %00011011,%00111011,%00111111,%01111111
                         .byte %11111111,%11110111,%11110110,%11100110
                         .byte %11100100,%11000100,%11000000

;
;Encode current accidental into note bytes
;

encode_acc               .byte %00000000,%11000000,%10000000
                         .byte %01000000,%00000000

;
;Descending binary sequence
;

bin_up         .byte 1,2,4,8,16,32,64,128

;
;Key designations
;

key_desig      .byte c_note,g_note,d_note,a_note,e_note,b_note
               .byte f_note+128,c_note+128
               .byte c_note+64,g_note+64,d_note+64,a_note+64
               .byte e_note+64,b_note+64,f_note

;
;Convert key index (0-14) to its onscreen representation.
;(Returns 7 characters in TEXT, which must be at least 8 characters long).
;

key_to_text = *

   sta temp
   cmp #8
   bcs +
   ora #48
   sta text
   lda #acc_char+sharp
   sta text+1
   bne ++

+  and #7
   eor #7
   ora #48
   sta text
   lda #acc_char+flat
   sta text+1

+  lda #" "
   sta text+2
   lda #"("
   sta text+3

   ldx #0
   ldy temp
   lda key_desig,y
   pha
   and #7
   tay
   lda letter_table-1,y
   sta text+4

   pla
   asl
   bcc +
   lda #acc_char+sharp
   sta text+5
   inx
   bne ++

+  asl
   bcc +
   lda #acc_char+flat
   sta text+5
   inx

+  lda #")"
   sta text+5,x
   lda #" "
   sta text+6,x
   rts

;
;Save screen and remove sprites
;

save_n_remove = *

   jsr save_screen

;
;Remove sprites from screen (except clef sprites).
;

remove_sprites = *

   lda #%01100000
   sta vic+21
   rts

;
;Create duration tables for current time signature
;

calc_time = *

   lda time_bot
   sta nodot_table+12
   lda #0
   sta nodot_table+13

   ldx #10
-  lda nodot_table+3,x
   sta number+1
   lda nodot_table+2,x
   asl
   rol number+1
   sta nodot_table,x
   clc
   adc nodot_table+2,x
   sta dot_table,x
   lda number+1
   sta nodot_table+1,x
   adc nodot_table+3,x
   sta dot_table+1,x
   lda dot_table,x
   clc
   adc nodot_table+4,x
   sta dd_table,x
   lda dot_table+1,x
   adc nodot_table+5,x
   sta dd_table+1,x
   dex
   dex
   bpl -

   rts

;
;Evaluate current measure in current voice for number of beats
;

eval_measure = *

   lda #0              ;Clear counters
   sta beat_count
   sta beat_count+1
   sta u_flag
   ldy #13
-  sta partial_trip,y
   sta full_trip,y
   dey
   bpl -

   lda voice
   asl
   tax
   lda voice_pos,x
   sta ptr
   lda voice_pos+1,x
   sta ptr+1
   ldy #0
-  lda (ptr),y
   and #%00111111
   cmp #$1e
   beq found_meas
   lda ptr
   cmp voice_start,x
   bne +
   lda ptr+1
   cmp voice_start+1,x
   bne +
   lda #0
   sta measure
   sta measure+1
   jsr show_mn
   lda time_bot        ;If bottom number of time signature is 0, don't count
   bne tbn
nobeatcount jsr print
   .byte yy+0,xx+34,rvs,tab,40,rvsoff,eot
   rts
tbn jmp startnc
+  lda ptr
   sec
   sbc #2
   sta ptr
   bcs -
   dec ptr+1
   bne -
   
found_meas = *

   lda (ptr),y
   lsr
   lsr
   lsr
   lsr
   lsr
   lsr
   sta measure+1
   iny
   lda (ptr),y
   sta measure
   jsr show_mn
   lda time_bot        ;If bottom number of signature is 0, don't count beats
   beq nobeatcount
+  jmp dnc             ;Skip over MS# command marking start of measure

startnc ldy #0         ;Start counting durations within measure
   lda (ptr),y
   sta temp
   and #%00000011
   bne nwn

   lda temp
   beq dnc             ;Don't count if ABS pitch
   and #%10111111      ;Eliminate tie bit
   sta temp
   cmp #%10100000
   bne nott64
   lda #triplet
   sta d$dot
   lda #6
   bne t64

nwn lda temp
   cmp #1
   bne +
   iny
   lda (ptr),y
   cmp #$4f
   beq jat             ;Stop if HLT command (ALWAYS at end of voice) is found
   lda temp
+  and #%00111111
   cmp #$1e
   bne dnc
jat jmp add_trips      ;Stop if MS# command is encountered
   
setuflag lda #1
   sta u_flag

dnc lda ptr
   clc 
   adc #2
   sta ptr
   bcc startnc
   inc ptr+1
   bne startnc

nott64 and #%00111111
   cmp #%00100100
   beq setuflag        ;Don't count if uV duration
   cmp #%00000100
   beq setuflag        ;Don't count u duration
   lda #0
   sta d$dot
   lda temp
   and #%10100011
   cmp #%10000000
   bne +
   lda #triplet        ;If a triplet, set that flag
   sta d$dot
+  cmp #%10100000
   bne +
   lda #double_dot     ;If double dot, set that flag
   sta d$dot
+  cmp #%00100000
   bne +
   lda #dot
   sta d$dot           ;If single dot, set THAT flag
+  lda temp            ;Get pitch index
   and #%00011111
   lsr
   lsr
   bne +
   lda #0
   sta d$dot
   lda #8
+  sec
   sbc #2
t64 asl
   tax

   lda d$dot
   cmp #no_dot
   bne +
   lda beat_count
   clc
   adc nodot_table,x
   sta beat_count
   lda beat_count+1
   adc nodot_table+1,x
   sta beat_count+1
   bcc endnc

+  cmp #dot
   bne +
   lda beat_count
   clc
   adc dot_table,x
   sta beat_count
   lda beat_count+1
   adc dot_table+1,x
   sta beat_count+1
   bcc endnc

+  cmp #double_dot
   bne +
   lda beat_count
   clc
   adc dd_table,x
   sta beat_count
   lda beat_count+1
   adc dd_table+1,x
   sta beat_count+1
   bcc endnc

+  cmp #triplet
   bne +
   ldy partial_trip,x
   iny
   cpy #3
   bcc +
   ldy #0
   inc full_trip,x
+  tya
   sta partial_trip,x
endnc jmp dnc

add_trips = *

   ldx #12
-  lda full_trip,x
   beq +
   asl
   tay
-  cpy #0
   beq +
   lda beat_count
   clc
   adc nodot_table,x
   sta beat_count
   lda beat_count+1
   adc nodot_table+1,x
   sta beat_count+1
   dey
   bne -
+  dex
   dex
   bpl --


   lda #0
   sta temp
   ldy #5              ;Divide to get true number of beats
-  lsr beat_count+1
   ror beat_count
   ror temp            ;Temp is the remainder
   dey
   bpl -

   lda beat_count+1
   bne +
   lda beat_count
   cmp #100
   bcc ++
+  lda #0
   sta beat_count+1
   lda #99
   sta beat_count

+  jsr print
   .byte xx+34,yy+0,col+7,rvs,"M",":",eot
   lda temp
   sta beat_count+1
   lda beat_count
   jsr printbyte
   lda u_flag
   beq +
   lda "u"
   bne pct

+  lda #0
   ldx #12
-  ora partial_trip,x
   dex
   dex
   bpl -
   cmp #0
   beq +
   sta u_flag
   lda #"T"
   bne pct

+  lda beat_count+1
   beq +
   lda #"+"
pct jsr printchar
   
+  jsr print
   .byte tab,40,rvsoff,eot
   rts

;
;Display measure number
;

show_mn = *

   jsr print
   .byte xx+4,yy+0,col+7,rvs,eot
   ldx measure
   ldy measure+1
   jsr printword
   jsr print
   .byte tab,9,rvsoff,eot
   rts

;
;Enter next measure number
;

enter_meas = *

   jsr reject_cut
   jsr should_we_open
   ldy #1
   inc measure
   bne +
   inc measure+1
+  lda measure
   sta (ptr),y
   dey
   lda measure+1
   asl
   asl
   asl
   asl
   asl
   asl
   ora #%00011110
   sta (ptr),y
   jsr move_forward
   jsr modify
   jmp da

;
;Sprite positioning table for extra line sprites for Grand Staff.
;

grand_table  .byte 0,119,119,119,119,119,119,119
             .byte 0,119,119,115,115,111,111,107
             .byte 0,107,103,103,000,000,000,000
             .byte 0,000,000,000,000,000,000,000
             .byte 0,095,000,000,000,000,000,000
             .byte 0,000,000,000,000,000,071,071
             .byte 0,067,067,063,063,059,059,059
             .byte 0,059,059,059,059,059,059,059

;
;Positioning tables for other staves
;(bits 0-5 : Sprite Y position minus 59, bit 7 : 1=two sprites, 0=one
; bit 6 : 1=second sprite 20 lines below, 0=second sprite 20 lines above)

other_stab   .byte 128,132,132,136,136,12,12,16,16,20,20,24,24
             .byte 28,28
             .byte 0,0,0,0,0,0,0,0,0,0,0
             .byte 36,36,40,40,44,44,48,48,244,244,248,248,252,252

;
;Hot key for changing voice's staff
;

chg_staff = *

   ldx voice
   lda voice_staff,x
   clc
   adc #1
   cmp #6
   bcc +
   lda #0
+  sta voice_staff,x
   jsr show_voice_staff
   jmp da

;
;Hot key for changing current key
;

chg_key = *

   ldy key
   iny
   cpy #15
   bcc +
   ldy #0
+  sty key
   jsr update_top
   jmp db

;
;Search backwards for pitch and octave that matches e$note_letter and
;e$octave. Ignore double sharps and double flats.
;

measure_acc = *

   jsr at_end
   bcc qm2
   lda acc_mode
   beq qm2

   lda voice_pos,x
   sta ptr
   lda voice_pos+1,x
   sta ptr+1

qm1 lda ptr
   cmp voice_start,x
   bne +
   lda ptr+1
   cmp voice_start+1,x
   beq qm2
+  lda ptr
   sec
   sbc #2
   sta ptr
   bcs +
   dec ptr+1
+  ldy #0
   lda (ptr),y
   and #%00000011
   bne +
   iny
   lda (ptr),y
   and #7
   cmp e$note_letter
   bne qm1
   lda (ptr),y
   lsr
   lsr
   lsr
   lsr
   lsr
   lsr
   beq qm2
   eor #3
   clc
   adc #1
   sta e$accidental
   sec
   rts
+  lda (ptr),y
   and #%00111111
   cmp #$1e
   bne qm1
qm2 clc
   rts

;
;Reject command and return to main loop if it cannot be used in cut/paste
;mode.
;

reject_cut = *

   lda cut_flag
   beq +
   ldx #$fa
   txs
   jmp db
+  rts

;
;Adjust pointers for deleted note
;

adjust_two = *

   lda voice_end,x
   sec
   sbc #2
   sta voice_end,x
   bcs +
   dec voice_end+1,x
+  inx
   inx
-  lda voice_start,x
   sec
   sbc #2
   sta voice_start,x
   bcs +
   dec voice_start+1,x
+  lda voice_end,x
   sec
   sbc #2
   sta voice_end,x
   bcs +
   dec voice_end+1,x
+  lda voice_pos,x
   sec
   sbc #2
   sta voice_pos,x
   bcs +
   dec voice_pos+1,x
+  inx
   inx
   cpx #14
   bcc -
   rts

;
;Restore e$ from r$ if current note is a rest.
;

restore_e$ = *

   lda e$note_letter
   bne +
   lda r$note_letter
   sta e$note_letter
   lda r$accidental
   sta e$accidental
+  rts

;
;Sound the bong based on current note
;

bong_sub = *

   ldy #d$accidental-d$duration
-  lda d$duration,y
   sta e$duration,y
   dey
   bpl -
   lda e$accidental
   sta r$accidental
   lda e$note_letter
   beq +
   sta r$note_letter
+  jmp bong

;-- Enter note with current parameters --

enter_note = *

   jsr reject_cut
   jsr encode_note
   jsr should_we_open
   ldy #0
   lda current_note
   sta (ptr),y
   iny
   lda current_note+1
   sta (ptr),y

   lda tie_mode
   bne +
   lda #0
   sta e$tie
   lda #11
   sta 55296+255
   sta 55296+256
   sta 55296+257

+  jsr modify
   jsr bong
   jsr move_forward
   jsr disp_all       ;*** To avoid e$ update based on note under cursor
   jsr eval_measure
   lda time_bot
   beq +
   lda beat_count+1
   ora u_flag
   bne +
   lda time_top
   cmp beat_count
   bne +
   jsr at_end
   bcc +
   jsr click
   jmp enter_meas    ;Note: should not enter measure if not in space-over mode
+  jmp db

;-- Insert a space if we should prior to entering note/command --

should_we_open = *

    jsr at_end
    lda insert_mode
    bne +
    bcc swo
+   jsr open1
swo rts

;
;Translate joystick values to editor functions
;

joy_translate = *

   cmp #16
   bne +
   jmp enter_note

+  cmp #%0010
   bne jt2

joy_down = *

   ldy r$note_letter
   dey
   bne +
   inc e$octave
   lda e$octave
   and #7
   sta e$octave
   ldy #7
+  sty temp
   ldy #natural
   jmp en2

jt2 cmp #%0001
   bne jt3

joy_up = *

   ldy r$note_letter
   iny
   cpy #8
   bcc +
   dec e$octave
   lda e$octave
   and #7
   sta e$octave
   ldy #1
+  sty temp
   ldy #natural
   jmp en2

jt3 cmp #%1000
   bne jt4

joy_right = *

   lda e$dot
   cmp #dot
   bne jry
jrx lda e$duration
   sec
   sbc #1
   bcs +
   lda #9
+  sta e$duration
   lda #no_dot
-  sta e$dot
   lda #0
   sta e$tie
   jsr change_stat
   jmp db
jry lda e$duration
   cmp #2
   bcc jrx
   cmp #8
   bcs jrx
   lda #dot
   jmp -

jt4 cmp #%0100
   bne jt9

joy_left = *

   lda e$dot
   cmp #dot
   beq jrz
   lda e$duration
   clc
   adc #1
   cmp #10
   bcc +
   lda #0
+  sta e$duration
   cmp #2
   bcc jrz
   cmp #8
   bcs jrz
   lda #dot
-  sta e$dot
   lda #0
   sta e$tie
   jsr change_stat
   jmp db
jrz lda #no_dot
   jmp -

jt9 jmp db

;
;Menu displayed when F7 is pressed.
;

f7_menu = *

   jsr refuse_midi
   jsr save_n_remove
   lda cut_flag
   beq +
   jmp region_menu
+  jsr define_f7
   jmp select_0

return_f7 ldx #$fa
   txs
   jsr recall_screen
   jsr define_f7
   jmp select

define_f7 = *

   jsr print
   .byte box,11,7,29,19,7,eot
   jsr menudef
   .byte 2,15+128,1
   .word rec_n_ret,0,0,0
   .byte dispatch,12,8,17
   .word edit_feat
   .asc "Editing Features"
   .byte dispatch,12,9,17
   .word song_para
   .asc "Song Parameters"
   .byte dispatch,12,10,17
   .word play_menu
   .asc "Player Options"
   .byte dispatch,12,11,17
   .word general_modes
   .asc "General Modes"
   .byte dispatch,12,12,17
   .word customizing
   .asc "Customizing Menus"
   .byte dispatch,12,13,17
   .word edit_title
   .asc "Title Block Edit"
   .byte dispatch,12,14,17
   .word save_load_new
   .asc "Load/Save/New"
   .byte dispatch,12,15,17
   .word disk_commands
   .asc "Disk Commands"
   .byte dispatch,12,16,17
   .word edit_words
   .asc "Words File Editor"
   .byte dispatch,12,17,17
   .word midi_menu
   .asc "MIDI Channel Menu"
   .byte dispatch,12,18,17
   .word spec_options
   .asc "Other Features"
   .byte eom
   rts

;
;Song parameter menu
;

song_para = *

   jsr recall_screen
   jsr print
   .byte box,11,10,29,14,7,eot

   jsr menudef
   .byte 3,15+128,1
   .word return_f7,0,0,0
   .byte dispatch,12,11,17
   .word select_key
   .asc "Key Signature"
   .byte dispatch,12,12,17
   .word time_sig
   .asc "Time Signature"
   .byte dispatch,12,13,17
   .word select_staff
   .asc "Staff Type"
   .byte eom
   jmp select

;
;Call up window to allow for key selection.
;

select_key = *

   jsr recall_screen
   jsr print
   .byte box,11,8,28,17,7,eot

   ldy #14
-  sty slot_count
   tya
   jsr key_to_text
   lda slot_count
   and #7
   clc
   adc #9
   pha
   tay
   ldx #12
   lda slot_count
   cmp #8
   bcc +
   ldx #21
+  jsr get_adr
   ldy #6
-  lda #15
   sta (start_m),y
   lda text,y
   sta (txtptr),y
   dey
   bpl -
   ldy slot_count
   lda #dispatch
   jsr s_itemtype
   lda #7
   jsr s_itemlen
   txa
   jsr s_itemx
   pla
   jsr s_itemy
   lda #<keysold
   jsr s_itemvecl
   lda #>keysold
   jsr s_itemvech
   dey
   bpl --

   lda #15
   jsr sizedef
   jsr headerdef
   .byte 8,15,1
   .word song_para,0,0,0
   jmp select_0
   
keysold jsr read_item
   sta key
   
rec_n_ret ldx #$fa
   txs
   jsr recall_screen
   jsr show_voice_staff
   jsr update_top
   jsr accept_midi
   jmp da

;
;Time signature menu
;

time_sig = *

   jsr recall_screen
   jsr print
   .byte box,9,11,31,14,7,col+15,xx+10,yy+12
   .asc "Beats/Measure:"
   .byte xx+10,yy+13
   .asc "Beats/Whole Note:"
   .byte eot

   jsr menudef
   .byte 8,15,1
   .word jct,0,0,0
   .byte numeric,28,12,3,0,16
   .word time_top
   .byte numeric,28,13,3,0,16
   .word time_bot
   .byte eom
   jsr menuset
   jmp select_0

jct jsr calc_time
   jmp song_para

;
;Staff selection menu
;

select_staff = *

   jsr recall_screen
   jsr print
   .byte box,11,9,29,16,7,col+15,yy+10,eot

   ldx #1
-  jsr print
   .byte xx+12
   .asc "Voice "
   .byte eot
   txa
   ora #48
   jsr printchar
   jsr print
   .byte ":",13,eot
   inx
   cpx #7
   bcc -

   jsr menudef
   .byte 8,15,1
   .word song_para,0,0,0
   .byte string,22,10,7,6
   .word voice_staff,staff_name
   .byte string,22,11,7,6
   .word voice_staff+1,staff_name
   .byte string,22,12,7,6
   .word voice_staff+2,staff_name
   .byte string,22,13,7,6
   .word voice_staff+3,staff_name
   .byte string,22,14,7,6
   .word voice_staff+4,staff_name
   .byte string,22,15,7,6
   .word voice_staff+5,staff_name
   .byte eom
   jsr menuset
   jmp select_0

;
;Show staff for current voice if it doesn't match the one currently being
;displayed.
;

show_voice_staff = *

   ldy voice
   lda voice_staff,y
   cmp staff_type
   beq +

   sta staff_type
   ldx #yy+3
-  txa
   jsr printchar
   jsr print
   .byte xx+0,tab,13,eot
   inx
   cpx #yy+9
   bcc -

   jmp draw_staff

+  rts

;
;Staff names
;

staff_name      .asc "Grand"
                .byte eot
                .asc "Treble"
                .byte eot
                .asc "Bass"
                .byte eot
                .asc "Tenor"
                .byte eot
                .asc "Alto"
                .byte eot
                .asc "Soprano"
                .byte eot

;
;Editing Features Menu
;

edit_feat = *

   ldx #$fa
   txs
   jsr recall_screen
   jsr print
   .byte box,11,8,29,17,7,eot

   jsr menudef
   .byte 3,15+128,1
   .word return_f7,0,0,0
   .byte dispatch,12,9,17
   .word set_mark
   .asc "Set Mark"
   .byte dispatch,12,10,17
   .word insert_buffer
   .asc "Insert Buffer"
   .byte dispatch,12,11,17
   .word clear_to_end
   .asc "Clear to End"
   .byte dispatch,12,12,17
   .word clear_to_start
   .asc "Erase to Start"
   .byte dispatch,12,13,17
   .word renum_meas
   .asc "Renumber Measures"
   .byte dispatch,12,14,17
   .word kill_meas
   .asc "Kill MS# Commands"
   .byte dispatch,12,15,17
   .word purge_buffer
   .asc "Purge Buffer"
   .byte dispatch,12,16,17
   .word copy_voice
   .asc "Voice-Voice Copy"
   .byte eom
   jmp select

;
;One voice or all voice selection
;

one_or_all = *

   jsr recall_screen
   jsr print
   .byte box,11,11,29,14,7,eot

   jsr menudef
   .byte 4,15+128,1
   .word edit_feat,0,0,0
   .byte dispatch,12,12,17
   .word ooa
   .asc "Voice   Only"
   .byte dispatch,12,13,17
   .word ooa
   .asc "All Voices"
   .byte eom
   lda voice
   clc
   adc #49
   sta screen+498
   jmp select_0

ooa jsr read_item
   rts

;
;Save/Load/New menu
;

save_load_new = *

   ldx #$fa
   txs
   jsr recall_screen
   jsr print
   .byte box,11,9,29,15,7,eot

   jsr menudef
   .byte 3,15+128,1
   .word return_f7,0,0,0
   .byte dispatch,12,10,17
   .word save_this_sid
   .asc "Save Current SID"
   .byte dispatch,12,11,17
   .word load_new_file
   .asc "Load New File"
   .byte dispatch,12,12,17
   .word clear_this_sid
   .asc "Erase Current SID"
   .byte dispatch,12,13,17
   .word insert_load
   .asc "Insertion Load"
   .byte dispatch,12,14,17
   .word disp_memory
   .asc "Bytes Free Check"
   .byte eom
   jmp select

;
;Load in a new SID file, selected from directory of files on disk.
;

load_new_file = *

   jsr prompt_for_save

   jsr recall_screen
   jsr print
   .byte box,7,9,32,15,7,xx+9,yy+11,col+15
   .asc "Insert a disk with SID"
   .byte xx+9,yy+12
   .asc "music files and press"
   .byte xx+9,yy+13
   .asc "RETURN to continue."
   .byte eot

   jsr abort_cont
   bcc +
   jmp save_load_new

+  jsr one_moment_please
   jsr clear_all
   jsr init_para
   jsr read_dir
   bcc +
   jmp handle_disk_err
+  jsr recall_screen
   lda num_files
   bne +
   jmp empty_disk
+  ldx #<save_load_new
   ldy #>save_load_new
   jsr dir_select
 
   jsr one_moment_please
   jsr load_mus

   jsr recall_screen

   ldy #0
-  cpy name_len
   bcs +
   lda filename,y
   sta current_file,y
   iny
   bne -
+  sty current_flen

   lda #0
   sta mod_flag
   jmp new_file

;
;Put up "One Moment Please..." menu
;

one_moment_please = *

   jsr recall_screen
   jsr print
   .byte box,8,10,31,14,7,xx+10,yy+12,col+15
   .asc "One Moment Please..."
   .byte eot
   rts

;
;Wait for carriage return or cancel. Return with carry clear if return,
;set if cancel
;

abort_cont = *

-  jsr getin
   cmp #3
   beq +
   cmp #135
   beq +
   cmp #13
   bne -
   clc
+  rts

;
;Header that identifies a transient application module
;

trans_id .asc "sid/app"
tid1 = *

;
;Load/re-enter key customizer module
;

key_custom = *

   lda #5
   jsr enter_trans
   jmp customizing

;
;Load/re_enter a transient module (file number in .A).
;

enter_trans = *

   sta temp
   pla
   sta ptr
   pla
   sta ptr+1

   lda #0
   sta move_flag
   ldy #tid1-trans_id-1
-  lda applic,y
   cmp trans_id,y
   bne +
   dey
   bpl -
   lda applic+7
   cmp temp
   beq etr2

+  jsr one_moment_please
   lda voice_start+13    ;Move SID data down if necessary
   cmp #$bf
   bcc etr1
   sta end_m+1
   lda voice_start+12
   sta end_m
   lda voice_start
   sta start_m
   lda voice_start+1
   sta start_m+1
   lda #<player
   sta dest_m
   lda #>player
   sta dest_m+1
   jsr move_down
   lda #1
   sta move_flag

etr1 lda pr_device
   sta 186
   jsr read_prdir
   bcs trans_error
   lda temp
   ldx #<applic
   ldy #>applic
   jsr load_prfile
   bcs trans_error
   jsr releasef
   lda #27
   sta 53265

etr2 lda vic+21
   sta temp2
   lda #0
   sta vic+21

   lda #<return_from_app
   sta applic+10
   lda #>return_from_app
   sta applic+11
   jmp (applic+8)

trans_error jsr releasef
   jsr prompt_insert
   lda #27
   sta 53265
   jsr abort_cont
   bcs +
   jmp etr1
+  jsr move_song_back
   jmp rec_n_ret

;
;Code for returning from application
;

return_from_app = *

   bcc +
   jsr modify

+  lda #$d4
   sta 53272
   ldx #<inter
   ldy #>inter
   jsr setirq

   jsr move_song_back

   lda temp2
   sta vic+21

   ldx #$fa
   txs
   lda ptr+1
   pha
   lda ptr
   pha
-  rts

;
;If song was moved, move it back.
;

move_song_back = *

   lda move_flag
   beq -
   lda voice_start+13
   sec
   sbc #16
   sta end_m+1
   lda voice_start+12
   sta end_m
   lda voice_start
   sta dest_m
   lda voice_start+1
   sta dest_m+1
   lda #<player
   sta start_m
   lda #>player
   sta start_m+1
   jsr move_up

rel9 lda pr_device
   sta 186
   jsr read_prdir
   bcc +
-  jsr releasef
   jsr prompt_insert
   lda #27
   sta 53265
   jsr abort_cont
   jmp rel9
+  lda #6  ;Player module filename "006"
   ldx #<player
   ldy #>player
   jsr load_prfile
   bcs -
   jsr releasef
   lda #27
   sta 53265
   rts

;
;Customizing Menus
;

customizing = *

   jsr recall_screen
   jsr print
   .byte box,10,10,29,14,7,eot
   jsr menudef
   .byte 3,15+128,1
   .word return_f7,0,0,0
   .byte dispatch,11,11,18
   .word hardware
   .asc "Hardware Set-Up"
   .byte dispatch,11,12,18
   .word key_custom
   .asc "Key Customizer"
   .byte dispatch,11,13,18
   .word save_config
   .asc "Save Configuration"
   .byte eom
   jmp select

;
;Hardware configuration menu
;

hardware = *

   jsr recall_screen
   jsr print
   .byte box,10,11,30,15,7,col+15,xx+11,yy+12
   .asc "Music Drive:"
   .byte xx+11,yy+13
   .asc "Stereo Chip:"
   .byte xx+11,yy+14
   .asc "Joy Speed:"
   .byte eot

   jsr menudef
   .byte 4,15,1
   .word customizing,0,0,0
   .byte numeric,25,12,5,8,11
   .word mus_device
   .byte string,25,13,5,3
   .word stereo_mode,str_str
   .byte numeric,25,14,5,5,60
   .word j$speed
   .byte eom

   jsr menuset
   jmp select

;
;Strings for chip addresses
;

str_str       .asc "None"
              .byte eot
              .asc "$DE00"
              .byte eot
              .asc "$DF00"
              .byte eot

;
;If current voice's position is beyond the end of the voice, fix it.
;

check_pos = *

   lda voice
   asl
   tax
   lda voice_pos+1,x
   cmp voice_end+1,x
   bne +
   lda voice_pos,x
   cmp voice_end,x
+  bcc +
   lda voice_end,x
   sta voice_pos,x
   lda voice_end+1,x
   sta voice_pos+1,x
+  rts

;
;"Are You Sure" prompt. Returns only if affirmative.
;

are_you_sure = *

   stx rayj+1
   sty rayj+2

   jsr recall_screen
   jsr print
   .byte box,11,10,29,14,7,col+1,xx+12,yy+11
   .asc "Are You Sure?"
   .byte eot
   jsr menudef
   .byte 11,15+128,1
   .word rays,0,0,0
   .byte dispatch,19,12,3
   .word rays
   .asc "No"
   .byte dispatch,19,13,3
   .word aysok
   .asc "Yes"
   .byte eom
   jmp select_0

aysok rts

rays ldx #$fa
   txs
rayj jmp $ffff

;
;Move memory down and keep track of how far.
;

cmove_down = *

   jsr usual_end
   lda start_m
   sec
   sbc dest_m
   sta ptr
   lda start_m+1
   sbc dest_m+1
   sta ptr+1
   jmp move_down

;
;Subtract PTR from .X indexed VOICE_END
;

sub_end = *

   lda voice_end,x
   sec
   sbc ptr
   sta voice_end,x
   lda voice_end+1,x
   sbc ptr+1
   sta voice_end+1,x
   rts

;
;Subtract voice_start (as above)
;

sub_start = *

   lda voice_start,x
   sec
   sbc ptr
   sta voice_start,x
   lda voice_start+1,x
   sbc ptr+1
   sta voice_start+1,x
   rts

;
;Subtract position (as above)
;

sub_pos = *

   lda voice_pos,x
   sec
   sbc ptr
   sta voice_pos,x
   lda voice_pos+1,x
   sbc ptr+1
   sta voice_pos+1,x
   rts

;
;Add PTR to VOICE_END,X
;

add_end = *

   lda voice_end,x
   clc
   adc ptr
   sta voice_end,x
   lda voice_end+1,x
   adc ptr+1
   sta voice_end+1,x
   rts

;
;Return with carry set only if at start of current voice
;

at_start = *

   lda voice
   asl
   tax
   lda voice_pos,x
   cmp voice_start,x
   bne +
   lda voice_pos+1,x
   cmp voice_start+1,x
   bne +
   rts
+  clc
   rts

;
;Return with carry set only if current voice is empty
;

is_clear = *

   lda voice
   asl
   tax

is_clear_x = *

   lda voice_start,x
   cmp voice_end,x
   bne +
   lda voice_start+1,x
   cmp voice_end+1,x
   bne +
   rts
+  clc
   rts

;
;Clear to end of current voice
;

clear_to_end = *

   jsr at_end
   bcc +
   jmp rec_n_ret
+  jsr ef_ays

   lda voice
   asl
   tax
   lda voice_end,x
   sta start_m
   lda voice_end+1,x
   sta start_m+1
   lda voice_pos,x
   sta dest_m
   lda voice_pos+1,x
   sta dest_m+1
   jsr cmove_down

common_clear = *

   lda voice
   asl
   tax
   jsr sub_end
   jsr check_pos
   jsr adjust_voices
   jsr modify

jrnr jmp rec_n_ret

;
;Clear to start of current voice
;

clear_to_start = *

   jsr at_start
   bcs jrnr
   jsr ef_ays

   lda voice
   asl
   tax
   lda voice_pos,x
   sta start_m
   lda voice_pos+1,x
   sta start_m+1
   lda voice_start,x
   sta voice_pos,x
   sta dest_m
   lda voice_start+1,x
   sta voice_pos+1,x
   sta dest_m+1
   jsr cmove_down
   jmp common_clear

;
;Prompt for voice number: Returns voice number (0-5) in .A
;

prompt_voice = *

   jsr menudef
   .byte 11,15,1
   .word edit_feat,0,ef_oth,0
   .byte dispatch,15,13,1
   .word pvs
   .asc "1"
   .byte dispatch,17,13,1
   .word pvs
   .asc "2"
   .byte dispatch,19,13,1
   .word pvs
   .asc "3"
   .byte dispatch,21,13,1
   .word pvs
   .asc "4"
   .byte dispatch,23,13,1
   .word pvs
   .asc "5"
   .byte dispatch,25,13,1
   .word pvs
   .asc "6"
   .byte eom
   jmp select_0

pvs jsr read_item
   rts

ef_oth cmp #"0"
   bcc +
   cmp #"7"
   bcs +
   and #15
   sbc #0
   rts
+  jmp select

;
;Code to adjust voices above current voice
;

adjust_voices = *

-  inx
   inx
   cpx #14
   bcs +
   jsr sub_end
   jsr sub_start
   jsr sub_pos
   jmp -

+  rts

;
;Adjust forward instead of backward
;

adjust_forward = *

-  inx                 ;Adjust pointers forward
   inx
   cpx #14
   bcs +
   jsr add_end
   lda voice_start,x
   clc
   adc ptr
   sta voice_start,x
   lda voice_start+1,x
   adc ptr+1
   sta voice_start+1,x
   lda voice_pos,x
   clc
   adc ptr
   sta voice_pos,x
   lda voice_pos+1,x
   adc ptr+1
   sta voice_pos+1,x
   jmp -
+  rts

;
;Insert PTR bytes at current position in current voice.
;

insert_area = *

   jsr check_memory
   lda voice_pos,x
   sta start_m
   clc
   adc ptr
   sta dest_m
   lda voice_pos+1,x
   sta start_m+1
   adc ptr+1
   sta dest_m+1
   jsr usual_end
   jmp move_up

;
;Set end_m to very end of all voice data.
;

usual_end = *

   lda voice_start+12
   sta end_m
   lda voice_start+13
   sta end_m+1
   rts

;
;Copy voice to voice
;

copy_voice = *

   jsr is_clear
   bcc +
   jmp rec_n_ret

+  jsr recall_screen
   jsr print
   .byte box,11,10,29,14,7,xx+12,yy+11,col+1
   .asc "Copy Voice "
   .byte eot
   lda voice
   clc
   adc #49
   jsr printchar
   jsr print
   .asc " to:"
   .byte eot

   jsr prompt_voice
   asl
   sta temp
   tax
   jsr is_clear_x
   bcs +

   jsr ef_ays          ;Destination voice is not clear, so clear it
   ldx temp
   lda voice_end,x
   sta start_m
   lda voice_end+1,x
   sta start_m+1
   lda voice_start,x
   sta dest_m
   lda voice_start+1,x
   sta dest_m+1
   jsr cmove_down
   ldx temp
   jsr sub_end
   jsr adjust_voices

+  lda voice           ;Now calculate length of source voice
   asl
   tax
   lda voice_end,x
   sec
   sbc voice_start,x
   sta ptr
   lda voice_end+1,x
   sbc voice_start+1,x
   sta ptr+1
   
   ldx temp
   lda voice_start,x
   sta voice_pos,x
   lda voice_start+1,x
   sta voice_pos+1,x

   jsr insert_area

   ldx temp
   jsr add_end

   jsr adjust_forward

+  lda voice           ;Now copy the actual data from voice to voice
   asl
   tax
   lda voice_start,x
   sta start_m
   lda voice_start+1,x
   sta start_m+1
   lda voice_end,x
   sta end_m
   lda voice_end+1,x
   sta end_m+1
   ldx temp
   lda voice_start,x
   sta dest_m
   lda voice_start+1,x
   sta dest_m+1
   jsr move_down       ;**** Should work either direction when no overlap ***

   jsr modify

   jmp rec_n_ret

;
;Save current file (subroutine).
;

save_current_file = *

   jsr set_cur_file
   lda name_len
   bne +
   jmp new_name
+  jsr recall_screen
   jsr print
   .byte box,10,9,29,15,7,xx+11,yy+10,col+1
   .asc "File was loaded as"
   .byte xx+11,yy+11,34,eot
   jsr print_filename
   jsr print
   .byte 34,".",eot

   jsr menudef
   .byte 11,15+128,1
   .word save_load_new,0,0,0
   .byte dispatch,14,13,12
   .word same_name
   .asc "Replace File"
   .byte dispatch,14,14,12
   .word new_name
   .asc "New Filename"
   .byte eom
   jmp select_0

new_name = *

   jsr prompt_filename
   jsr get_filename
   cpy #0
   bne +
   jmp save_load_new
+  jsr one_moment_please
   jmp common_save

same_name = *

   jsr one_moment_please
   jsr init_mus
   jsr scratch_files
   jmp +

common_save = *

   jsr init_mus
+  jsr save_sid
   bcc +
   cmp #63
   bne save_error

   jsr recall_screen
   jsr print
   .byte box,9,10,31,15,7,xx+10,yy+11,col+1
   .asc "That filename already"
   .byte xx+10,yy+12
   .asc "exists. Replace file?"
   .byte eot
   jsr menudef
   .byte 11,15+128,1
   .word save_load_new,0,0,0
   .byte dispatch,19,13,3
   .word save_load_new
   .asc "No"
   .byte dispatch,19,14,4
   .word same_name
   .asc "Yes"
   .byte eom
   jmp select_0

+  lda #0
   sta mod_flag
   rts

save_error jmp handle_disk_err

;
;Set modify flag
;

modify = *

   lda #1
   sta mod_flag
   rts

;
;Accept a filename from user.
;

get_filename = *

   lda #12
   .byte $2c

;
;Accept a disk command from user.
;

get_diskcomm = *

   lda #36
   sta max_len
   lda #0
   sta name_len

gfn0  jsr cursor_on

gfn1 jsr getin
   beq gfn1
   pha
   jsr cursor_off
   pla
   ldy name_len
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
   cpy max_len
   bcs gfn0
   sta filename,y
   jsr printchar
   inc name_len
   bne gfn0

gfdel cpy #0
   beq gfn0
   dec name_len
   jsr backspace
   jmp gfn0

gfabort ldy #0

gfret lda #32
-  dey
   bmi +
   cmp filename,y
   beq -
+  iny
   sty name_len
   rts

;
;Save SID menu option.
;

save_this_sid = *

   jsr save_current_file
   jmp rec_n_ret

;
;Clear SID menu option.
;

clear_this_sid = *


   lda mod_flag
   beq +
   jsr prompt_for_save
-  jsr clear_all
   jsr recall_screen
   jmp new_file

+  ldx #<save_load_new
   ldy #>save_load_new
   jsr are_you_sure
   jmp -

;
;Prompt user to save SID in memory if it has been modified.
;

prompt_for_save = *

   lda mod_flag
   beq skip_save

   jsr recall_screen
   jsr print
   .byte box,9,9,30,15,7,xx+10,yy+10,col+1
   .asc "Changes were made to"
   .byte xx+10,yy+11
   .asc "the SID in memory."
   .byte xx+10,yy+12
   .asc "Save it?"
   .byte eot
   jsr menudef
   .byte 11,15+128,1
   .word save_load_new,0,0,0
   .byte dispatch,18,13,3
   .word do_save
   .asc "Yes"
   .byte dispatch,18,14,3
   .word skip_save
   .asc "No"
   .byte eom
   jmp select_0

do_save jmp save_current_file

skip_save rts

;
;----- CUT AND PASTE ROUTINES -----
;Mark has been set.
;

set_mark = *

   jsr recall_screen
   jsr at_end
   bcc +
   jmp da              ;Cannot start cut at end of voice (or empty voice).

+  lda voice_pos,x
   sta mark_ptr
   lda voice_pos+1,x
   sta mark_ptr+1
   lda #1
   sta cut_flag
   jmp da

;
;Compare PTR to MARK_PTR
;

cmp_mark = *

   lda ptr+1
   cmp mark_ptr+1
   bne +
   lda ptr
   cmp mark_ptr
+  rts

;
;Compare PTR to CUT_PTR
;

cmp_cut = *

   lda ptr+1
   cmp cut_ptr+1
   bne +
   lda ptr
   cmp cut_ptr
+  rts

;
;Decide if we're currently within the marked region.
;(Return 0 in .A if within, 128 otherwise).
;

check_region = *

   jsr cmp_mark
   bcc cdi
   beq cdy
   jsr cmp_cut
   bcc cdy
   beq cdy
cdn lda #128
   rts
cdy lda #0
   rts
cdi jsr cmp_cut
   bcs cdy
   bcc cdn

;
;Cut/Paste menu
;

region_menu = *

   jsr print
   .byte box,11,10,29,15,7,eot
   jsr menudef
   .byte 2,15+128,1
   .word rec_n_ret,0,0,0
   .byte dispatch,12,11,17
   .word cut_region
   .asc "Cut Marked Region"
   .byte dispatch,12,12,17
   .word save_region
   .asc "Save Region"
   .byte dispatch,12,13,17
   .word delete_region
   .asc "Delete Region"
   .byte dispatch,12,14,17
   .word remove_mark
   .asc "Remove Mark"
   .byte eom
   jmp select_0

;
;Save marked text in buffer, but do not delete it.
;

save_region = *

   jsr copy_to_buffer
   lda #0
   sta cut_flag
   jmp rec_n_ret

;
;Return to region menu.
;

return_cut = *

   ldx #$fa
   txs
   jsr recall_screen
   jmp region_menu

;
;Cut marked text, saving it in the buffer.
;

cut_region = *

   jsr copy_to_buffer
   jmp +

;
;Delete marked text without saving it.
;

delete_region = *

   ldx #<return_cut
   ldy #>return_cut
   jsr are_you_sure
+  lda #0
   sta cut_flag
   jsr get_region_ptr
   lda reg_start
   sta dest_m
   lda reg_start+1
   sta dest_m+1
   lda reg_end
   sta start_m
   lda reg_end+1
   sta start_m+1
   jsr cmove_down
   lda voice
   asl
   tax
   jsr sub_end
   lda reg_start
   sta voice_pos,x
   lda reg_start+1
   sta voice_pos+1,x
   jsr adjust_voices
   jsr modify
   jmp rec_n_ret

;
;Remove mark.
;

remove_mark = *

   lda #0
   sta cut_flag
   jmp rec_n_ret

;
;Get region start and end pointers.
;

get_region_ptr = *

   jsr at_end
   bcc +
   lda voice_pos,x
   sec
   sbc #2
   sta voice_pos,x
   bcs +
   dec voice_pos+1,x

+  lda voice_pos,x
   sta reg_start
   lda voice_pos+1,x
   sta reg_start+1
   lda mark_ptr
   sta reg_end
   lda mark_ptr+1
   sta reg_end+1

   lda reg_start+1
   cmp reg_end+1
   bne +
   lda reg_start
   cmp reg_end
+  bcc +

   lda reg_start
   sta reg_end
   lda reg_start+1
   sta reg_end+1
   lda mark_ptr
   sta reg_start
   lda mark_ptr+1
   sta reg_start+1

+  lda reg_end
   clc
   adc #2
   sta reg_end
   bcc +
   inc reg_end+1

+  rts

;
;Call routine to set pointers, then copy region to buffer if there is
;room.
;

copy_to_buffer = *

   jsr get_region_ptr
   lda reg_end
   sec
   sbc reg_start
   sta ptr
   lda reg_end+1
   sbc reg_start+1
   sta ptr+1
   
   cmp #>buffer_size
   bne +
   lda ptr
   cmp #<buffer_size
+  bcc +

   jsr recall_screen
   jsr print
   .byte box,8,9,32,15,7,xx+10,yy+11,col+15
   .asc "That region is too"
   .byte xx+10,yy+12
   .asc "large for the buffer."
   .byte xx+10,yy+13
   .asc "Press RETURN."
   .byte eot
   jsr abort_cont
   jmp rec_n_ret

+  sei
   lda #0
   sta 1
   lda reg_start
   sta start_m
   lda reg_start+1
   sta start_m+1
   lda reg_end
   sta end_m
   lda reg_end+1
   sta end_m+1
   lda #<buffer_loc
   sta dest_m
   clc
   adc ptr
   sta buf_ptr
   lda #>buffer_loc
   sta dest_m+1
   adc ptr+1
   sta buf_ptr+1
   jsr move_up
   lda #kernal_out
   sta 1
   cli

   rts

;
;Insert buffer into current voice at current position
;

insert_buffer = *

   lda buf_ptr
   cmp #<buffer_loc
   bne +
   lda buf_ptr+1
   cmp #>buffer_loc
   bne +
   jmp rec_n_ret

+  lda buf_ptr
   sec
   sbc #<buffer_loc
   sta ptr
   lda buf_ptr+1
   sbc #>buffer_loc
   sta ptr+1

   lda voice
   asl
   tax
   jsr insert_area

   lda voice
   asl
   tax
   jsr add_end
   jsr adjust_forward

   lda voice           ;Now copy the actual data
   asl
   tax
   lda voice_pos,x
   sta dest_m
   lda voice_pos+1,x
   sta dest_m+1
   lda #<buffer_loc
   sta start_m
   lda #>buffer_loc
   sta start_m+1
   lda buf_ptr
   sta end_m
   lda buf_ptr+1
   sta end_m+1
   sei
   lda #0
   sta 1
   jsr move_up
   lda #kernal_out
   sta 1
   cli
   jsr modify
   jmp rec_n_ret

;
;Edit credit block (transient application)
;

edit_title = *

   lda #8
   jsr enter_trans
   jmp return_f7

;
;General mode menu
;

general_modes = *

   jsr recall_screen
   jsr print
   .byte box,9,7,31,18,7,col+15,xx+10,yy+8
   .asc "Note Feedback:"
   .byte xx+10,yy+9
   .asc "Accidental Mode:"
   .byte xx+10,yy+10
   .asc "Scroll Updating:"
   .byte xx+10,yy+11
   .asc "Nearest Pitch:"
   .byte xx+10,yy+12
   .asc "Insert Mode:"
   .byte xx+10,yy+13
   .asc "Tie Mode:"
   .byte xx+10,yy+14
   .asc "Words Enable:"
   .byte xx+10,yy+15
   .asc "Command Update:"
   .byte xx+10,yy+16
   .asc "Auto MIDI Entry:"
   .byte xx+10,yy+17
   .asc "Use AUX Colors:"
   .byte eot

   jsr menudef
   .byte 4,15,1
   .word return_f7,0,0,0
   .byte string,28,8,3,2
   .word bong_mode,yesno
   .byte string,28,9,3,2
   .word acc_mode,yesno
   .byte string,28,10,3,2
   .word update_mode,yesno
   .byte string,28,11,3,2
   .word pitch_mode,yesno
   .byte string,28,12,3,2
   .word insert_mode,yesno
   .byte string,28,13,3,2
   .word tie_mode,yesno
   .byte string,28,14,3,2
   .word word_mode,yesno
   .byte string,28,15,3,2
   .word cmd_update,yesno
   .byte string,28,16,3,2
   .word midi_entry,yesno
   .byte string,28,17,3,2
   .word aux_mode,yesno
   .byte eom
   jsr menuset
   jmp select_0

;
;Yes/No string table
;

yesno     .asc "No"
          .byte eot
          .asc "Yes"
          .byte eot

;
;Purge buffer. Ask for confirmation if not empty.
;

purge_buffer = *

   lda buf_ptr
   cmp #<buffer_loc
   bne +
   lda buf_ptr+1
   cmp #>buffer_loc
   beq ++
+  jsr ef_ays
+  lda #<buffer_loc
   sta buf_ptr
   lda #>buffer_loc
   sta buf_ptr+1
   jmp rec_n_ret

;
;Are You Sure prompt for Edit Features menu functions.
;

ef_ays = *

   ldx #<edit_feat
   ldy #>edit_feat
   jmp are_you_sure

;
;Prompt for insertion of program disk.
;

prompt_insert = *

   jsr recall_screen
   jsr print
   .byte box,9,10,31,15,7,col+15,xx+11,yy+12
   .asc "Insert Program Disk"
   .byte xx+12,yy+13
   .asc "and press RETURN."
   .byte eot
   rts

;
;No SID files on disk message.
;

empty_disk = *

   jsr print
   .byte box,8,9,31,16,7,xx+10,yy+11,col+15
   .asc "There are no SIDs on"
   .byte xx+10,yy+12
   .asc "this disk."
   .byte xx+10,yy+14
   .asc "Press RETURN."
   .byte eot
   jsr abort_cont
   jmp save_load_new

;
;Call up .WDS file editor transient utility.
;

edit_words = *

   lda #9
   jsr enter_trans
   jmp return_f7

;
;Special options menu.
;

spec_options = *

   lda num_menu
   bne +
   jmp select
+  lda #0
   jsr set_item

spec_op1 = *

   jsr recall_screen
   jsr print
   .byte box,11,eot
   lda #25
   sec
   sbc num_menu
   lsr
   sta temp
   jsr printchar
   lda #29
   jsr printchar
   lda temp
   sec
   adc num_menu
   jsr printchar
   jsr print
   .byte 7,col+15,eot

   jsr headerdef
   .byte 3,15+128,1
   .word return_f7,0,0,0
   lda num_menu
   jsr sizedef
   
   ldx #0              ;Index into menu names
   ldy #0              ;Current menu #
-  tya
   sec
   adc temp
   jsr s_itemy
   adc #yy
   jsr printchar
   lda #12
   jsr s_itemx
   lda #17
   jsr s_itemlen
   lda #<spec_sel
   jsr s_itemvecl
   lda #>spec_sel
   jsr s_itemvech
   lda #dispatch
   jsr s_itemtype
   lda #xx+12
   jsr printchar
-  lda menu_name,x
   cmp #"$"
   beq +
   jsr printchar
   inx
   bne -
+  inx
   iny
   cpy num_menu
   bcc --

   jmp select

spec_sel = *

   jsr read_item
   sta key_temp
   tay
   lda menu_file,y
   jsr enter_trans
   lda key_temp
   jsr set_item
   jmp spec_op1

;
;Filename prompt
;

prompt_filename = *

   jsr recall_screen
   jsr print
   .byte box,11,10,29,14,7,xx+12,yy+11,col+1
   .asc "Enter SID Name:"
   .byte xx+12,yy+13,col+15,tab,29,xx+12,eot
   rts

;
;Insertion load
;

insert_load = *

   jsr prompt_filename
   jsr get_filename
   cpy #0
   bne +
   jmp save_load_new
+  jsr one_moment_please
   jsr do_insert_file
   jsr modify
   jmp rec_n_ret

;
;Disk commands menu
;

disk_commands = *

   jsr recall_screen
   jsr print
   .byte box,11,11,29,14,7,eot
   jsr menudef
   .byte 3,15+128,1
   .word return_f7,0,0,0
   .byte dispatch,12,12,17
   .word send_command
   .asc "Send Disk Command"
   .byte dispatch,12,13,17
   .word disk_directory
   .asc "Disk Directory"
   .byte eom
   jmp select

;
;Display disk directory
;

disk_directory = *

   jsr recall_screen
   jsr print
   .byte box,6,4,34,20,7,eot

   jsr init_mus
   jsr open_error_ch
   lda #1
   ldx mus_device
   ldy #0
   jsr setlfs
   lda #dirchar3-dirchar2
   ldx #<dirchar2
   ldy #>dirchar2
   jsr setnam
   jsr open
   jsr read_error
   cmp #20
   bcc +
   jmp handle_disk_err
+  ldx #1
   jsr chkin
   jsr chrin  ;Skip load address
   jsr chrin
   jsr clrchn

qdl jsr print
   .byte box,6,4,34,20,7,col+15,yy+5,eot
   lda #0
   sta topfile

qdl1 jsr print
   .byte rvsoff,xx+7,eot

   ldx #1
   jsr chkin
   jsr chrin  ;Skip line link address
   jsr chrin
   jsr chrin  ;Get number of blocks
   tax
   jsr chrin
   tay
   jsr printword
   lda #32
   jsr printchar

   ldy #0
   sty botfile
-  jsr chrin
   cmp #34
   bne +
   sta botfile
+  cmp #0
   beq qdl2
   cmp #18
   bne +
   lda #rvs
+  cmp #146
   beq +
   sta line_construct,y
   iny
+  jmp -

qdl2 lda #32
-  dey
   bmi +
   cmp line_construct,y
   beq -
+  iny
   sty temp
   ldy #0
-  lda line_construct,y
   jsr printchar
   iny
   cpy temp
   bcc -

   jsr clrchn
   lda #13
   jsr printchar
   lda botfile
   beq qdl3
   inc topfile
   lda topfile
   cmp #13
   bcc qdl1

qdl3 jsr clrchn
   jsr print
   .byte col+12,xx+7,yy+19,rvs
   .asc "Press RETURN to continue."
   .byte tab,34,rvsoff,eot
   jsr abort_cont
   bcs qdl10
   lda botfile
   beq qdl9
   jmp qdl

qdl9 jsr close_all
   jmp rec_n_ret
qdl10 jsr close_all
   jmp disk_commands

dirchar2     .asc "$"
dirchar3     = *

;
;Handle disk errors (error in .A)
;

handle_disk_err = *

   pha
   jsr close_all
   jsr recall_screen
   jsr print
   .byte box,11,9,28,15,7,col+15,xx+13,yy+11
   .asc "Disk Error #"
   .byte eot
   pla
   jsr printbyte
   jsr print
   .byte xx+13,yy+13
   .asc "Press RETURN."
   .byte eot
   jsr abort_cont
   jmp rec_n_ret

;
;Play menu
;

play_menu = *

   jsr recall_screen
   jsr print
   .byte box,9,11,31,14,7,xx+10,yy+12,col+15
   .asc "Play Mode:"
   .byte xx+10,yy+13
   .asc "Channel Delay:"
   .byte eot

   jsr menudef
   .byte 4,15,1
   .word return_f7,0,pv_oth,0
   .byte string,25,12,6,2
   .word route,route_strings
   .byte numeric,25,13,6,0,9
   .word expand_value
   .byte eom

   jsr menuset
   jmp select_0

pv_oth = *

   pha
   jsr read_item
   tay
   pla
   cpy #1
   bne pv_jsel

   cmp #"0"
   bcc pv_jsel
   cmp #":"
   bcs pv_jsel
   and #15
   sta expand_value
pv_jmes jsr menuset
pv_jsel jmp select

;
;Route Strings
;

route_strings = *

   .asc "Stereo"
   .byte eot
   .asc "Invert"
   .byte eot

;
;Send disk command option
;

send_command = *

   jsr recall_screen
   jsr print
   .byte box,0,9,39,15,7,xx+2,yy+11,col+1
   .asc "Enter Disk Command:"
   .byte col+15,yy+13,xx+2,tab,39,xx+2,eot
   jsr get_diskcomm
   bne +
   jmp disk_commands

+  jsr one_moment_please
   jsr open_error_ch
   ldx #15
   jsr chkout
   ldy #0
-  cpy name_len
   bcs +
   lda filename,y
   jsr chrout
   iny
   bne -
+  jsr clrchn
   jsr read_error
   pha
   jsr close_all
   pla
   cmp #20
   bcc +
   jmp handle_disk_err
+  jmp disk_commands

;
;Display free memory left.
;

disp_memory = *

   jsr recall_screen
   jsr print
   .byte box,8,9,31,16,7,xx+10,yy+11,col+15
   .asc "You have "
   .byte eot
   lda #<top_heap
   sec
   sbc voice_start+12
   tax
   lda #>top_heap
   sbc voice_start+13
   tay
   jsr printword
   jsr print
   .asc " bytes"
   .byte xx+10,yy+12
   .asc "of memory left."
   .byte xx+10,yy+14
   .asc "Press RETURN."
   .byte eot
   jsr abort_cont
   jmp save_load_new

;-- MIDI menu --

midi_menu = *

   jsr recall_screen
   jsr print
   .byte box,9,9,30,16,7,col+15,yy+10,eot

   ldx #1
-  jsr print
   .byte xx+10
   .asc "Voice "
   .byte eot
   txa
   ora #48
   jsr printchar
   jsr print
   .asc " : Channel"
   .byte 13,eot
   inx
   cpx #7
   bcc -

   jsr menudef
   .byte 4,15,1
   .word return_f7,0,0,0
   .byte numeric,28,10,2,1,16
   .word midi_channel
   .byte numeric,28,11,2,1,16
   .word midi_channel+1
   .byte numeric,28,12,2,1,16
   .word midi_channel+2
   .byte numeric,28,13,2,1,16
   .word midi_channel+3
   .byte numeric,28,14,2,1,16
   .word midi_channel+4
   .byte numeric,28,15,2,1,16
   .word midi_channel+5
   .byte eom
   jsr menuset
   jmp select_0

;
;Set up screen and menus for command selection
;

select_command = *

   jsr reject_cut
   lda vic+21 ;Remove all sprites except current position marker
   and #1
   sta vic+21

   ldx #<cc_key
   ldy #>cc_key
   jsr change_keys

   jsr clear_top

resel_c = *

   ldy #49
-  lda cmd_x,y
   jsr s_itemx
   tax
   lda #3
   jsr s_itemlen
   lda #dispatch
   jsr s_itemtype
   lda #<cmd_sel
   jsr s_itemvecl
   lda #>cmd_sel
   jsr s_itemvech
   lda cmd_y,y
   jsr s_itemy
   cpy #49
   beq +
   sty temp
   tay
   jsr get_adr
   ldy temp
   lda cmd_index_tab,y
   asl
   adc cmd_index_tab,y
   tax
   ldy #0
-  lda command_text,x
   sta (txtptr),y
   inx
   iny
   cpy #3
   bcc -
   ldy temp
+  dey
   bpl --

   jsr print
   .byte col+13,xx+24,yy+11,"H","L","T",eot

   jsr headerdef
   .byte 3,13,1
   .word exit_cmd,0,cmd_other,0
   lda #50
   jsr sizedef

   jsr update_cmd

place_from_ec = *

   lda e$command
   jsr set_item
   lda #0
   sta cmd_len
   jmp select

;
;Return to regular (note) edit screen
;

exit_cmd = *

   jsr read_item
   sta e$command
   jsr reset_keys
   jmp draw_note_top

;
;Dispatch to appropriate command handler routines
;

cmd_sel = *

   jsr read_item
   sta e$command
   asl
   tay
   lda cmd_dispatch+1,y
   beq +
   pha
   lda cmd_dispatch,y
   pha
   ldx #$01
   stx current_note
   ldx #0
   stx low_range
   stx high_range
   stx low_range+1
   stx high_range+1

   rts

+  jmp resel_c

;
;Handle other keypresses
;

cmd_other = *

   cmp #"a"
   bcc cot1
   cmp #"z"+1
   bcs cot1

   ldy cmd_len
   beq +
   sta char
   jsr read_item
   tax
   lda char
   cpx e$command
   beq +
lookc ldy #0
   sty cmd_len

+  cpy #3
   bcs lookc
   jsr getrom
   ora #64
   sta cmd_string,y
   inc cmd_len

   ldy #0            ;Look for a match for string
-  sty temp
   ldx cmd_x,y
   lda cmd_y,y
   tay
   jsr get_adr
   ldy #255
   ldx #0
-  iny
   lda (txtptr),y
   cmp #"-"
   beq -
   cmp cmd_string,x
   bne +
   inx
   cpx cmd_len
   bcc -
   bcs cmd_match
+  ldy temp
   iny
   cpy #50
   bcc --

   ldy cmd_len
   cpy #1
   beq +
   lda char          ;No match - try again with zeroed string
   jmp lookc
+  jmp select

cmd_match = *

   lda temp
   sta e$command
   jsr set_item
-  jmp select

cot1 = *

   cmp #"-"
   beq +

   cmp #"0"
   bcc ++
   cmp #"9"+1
   bcs ++
+  sei
   sta 631
   lda #1
   sta 198
   cli
   jmp cmd_sel

+  jsr handle_ckey

   jmp place_from_ec

;
;Return to command selection screen
;

reselect_cmd = *

   ldx #$fa
   txs
   jsr recall_screen
   jmp resel_c

;
;Vectors to command handler routines
;

cmd_dispatch    .word temh-1,utlh-1
                .word volh-1,bmph-1
                .word hedh-1,talh-1
                .word calh-1,defh-1,endh-1
                .word atkh-1,dcyh-1,sush-1,rlsh-1,pnth-1,hldh-1
                .word wavh-1,pwh-1,psh-1,pvdh-1,pvrh-1,snch-1,rngh-1
                .word vdph-1,vrth-1,porh-1,pvh-1,dtnh-1,tpsh-1,rtph-1
                .word fmh-1,auth-1,resh-1,flth-1,fch-1,fsh-1,fxh-1
                .word lfoh-1,ruph-1,rdnh-1,srch-1,dsth-1,scah-1,maxh-1
                .word msh-1,utvh-1,jifh-1,flgh-1,auxh-1,o3h-1,hlth-1

;
;Screen index to command text index converter
;

cmd_index_tab   .byte tem_cmd,utl_cmd
                .byte vol_cmd,bmp_cmd
                .byte hed_cmd,tal_cmd
                .byte cal_cmd,def_cmd,end_cmd
                .byte atk_cmd,dcy_cmd,sus_cmd,rls_cmd,pnt_cmd,hld_cmd
                .byte wav_cmd,pw_cmd,ps_cmd,pvd_cmd,pvr_cmd,snc_cmd,rng_cmd
                .byte vdp_cmd,vrt_cmd,por_cmd,pv_cmd,dtn_cmd,tps_cmd,rtp_cmd
                .byte fm_cmd,aut_cmd,res_cmd,flt_cmd,fc_cmd,fs_cmd,fx_cmd
                .byte lfo_cmd,rup_cmd,rdn_cmd,src_cmd,dst_cmd,sca_cmd,max_cmd
                .byte ms_cmd,utv_cmd,jif_cmd,flg_cmd,aux_cmd,o3_cmd,hlt_cmd

;
;Screen coordinates for each command in display
;

cmd_x           .byte 0,4
                .byte 0,4
                .byte 0,4
                .byte 0,4,8
                .byte 0,4,8,12,16,20
                .byte 0,4,8,12,16,20,24
                .byte 0,4,8,12,16,20,24
                .byte 0,4,8,12,16,20,24
                .byte 0,4,8,12,16,20,24
                .byte 0,4,8,12,16,20,24

cmd_y           .byte 2,2
                .byte 3,3
                .byte 4,4
                .byte 5,5,5
                .byte 6,6,6,6,6,6
                .byte 7,7,7,7,7,7,7
                .byte 8,8,8,8,8,8,8
                .byte 9,9,9,9,9,9,9
                .byte 10,10,10,10,10,10,10
                .byte 11,11,11,11,11,11,11

;
;Clear lines 1-11 of screen.
;

clear_top = *

   lda #col+13
   .byte $2c

clear_top_cyan = *

   lda #col+3
   jsr printchar

   ldx #11
-  txa
   clc
   adc #yy
   jsr printchar
   jsr print
   .byte xx+0,tab,40,eot
   dex
   bne -
   rts

;
;Print current command's text
;

print_ct = *

   ldy e$command
   lda cmd_index_tab,y
   asl
   adc cmd_index_tab,y

print_cmdtxt = *

   tay
   ldx #2
-  lda command_text,y
   cmp #64
   bcc +
   adc #127
+  jsr printchar
   iny
   dex
   bpl -

   rts

;
;Print "Select xxx Mode" text at top of window
;

print_sm = *

   jsr print
   .byte xx+13,yy+3,col+1
   .asc "Select "
   .byte eot
   jsr print_ct
   jsr print
   .asc " Mode"
   .byte eot
   rts

;
;Create window of standard size at top of screen
;

make_cmd_win = *

   jsr save_screen
   jsr print
   .byte box,12,2,28,6,14,eot
   rts

;
;Query for yes/no prompt
;

query_yn = *

   jsr make_cmd_win
   jsr print_sm
   jsr menudef
   .byte 8,15,1
   .word reselect_cmd,0,0,0
   .byte dispatch,19,4,3
   .word qyn_sel
   .asc "No"
   .byte dispatch,19,5,3
   .word qyn_sel
   .asc "Yes"
   .byte eom
   jmp select_0

qyn_sel = *

   jmp read_item

;
;Handle BMP command
;

bmph = *

   jsr make_cmd_win
   jsr print_sm
   jsr menudef
   .byte 8,15,1
   .word reselect_cmd,0,0,0
   .byte dispatch,18,4,4
   .word bmp_sel
   .asc "Up"
   .byte dispatch,18,5,4
   .word bmp_sel
   .asc "Down"
   .byte eom
   jmp select_0

bmp_sel ldy #$03
   jsr read_item
   beq +
   ldy #$0b
+  sty current_note+1
   jmp enter_cmd

;
;Handle commands with no argument
;

talh lda #$0f

   .byte $2c

endh lda #$2f

   .byte $2c

hlth lda #$4f

   sta current_note+1
   lda #0
   sta 198
   jsr save_screen

;
;Enter a command into current voice
;

enter_cmd = *

   jsr should_we_open
   ldy #0
   lda current_note
   sta (ptr),y
   iny
   lda current_note+1
   sta (ptr),y

   jsr modify
   jsr move_forward
   jsr recall_screen
   jsr disp_all
   jmp resel_c

;
;Handle WAV command
;

wavh = *

   jsr save_screen
   jsr print
   .byte box,12,2,28,8,14,eot
   jsr print_sm
   jsr menudef
   .byte 8,15,1
   .word reselect_cmd,0,0,0
   .byte dispatch,16,7,3
   .word wav_sel
   .asc "N"
   .byte dispatch,16,4,3
   .word wav_sel
   .asc "T"
   .byte dispatch,16,6,3
   .word wav_sel
   .asc "S"
   .byte dispatch,23,6,3
   .word wav_sel
   .asc "TS"
   .byte dispatch,16,5,3
   .word wav_sel
   .asc "P"
   .byte dispatch,23,4,3
   .word wav_sel
   .asc "TP"
   .byte dispatch,23,5,3
   .word wav_sel
   .asc "SP"
   .byte dispatch,23,7,3
   .word wav_sel
   .asc "TSP"
   .byte eom
   lda #1
   jsr set_item
   jmp select

wav_sel jsr read_item
   asl
   asl
   asl
   asl
   asl
   ora #%00000111
   sta current_note+1
   jmp enter_cmd

;
;Handle F-M command
;

fmh = *

   jsr save_screen
   jsr print
   .byte box,12,2,28,8,14,eot
   jsr print_sm
   jsr menudef
   .byte 8,15,1
   .word reselect_cmd,0,0,0
   .byte dispatch,16,7,3
   .word fm_sel
   .asc "N"
   .byte dispatch,16,4,3
   .word fm_sel
   .asc "L"
   .byte dispatch,16,5,3
   .word fm_sel
   .asc "B"
   .byte dispatch,23,4,3
   .word fm_sel
   .asc "LB"
   .byte dispatch,16,6,3
   .word fm_sel
   .asc "H"
   .byte dispatch,23,5,3
   .word fm_sel
   .asc "LH"
   .byte dispatch,23,6,3
   .word fm_sel
   .asc "BH"
   .byte dispatch,23,7,3
   .word fm_sel
   .asc "LBH"
   .byte eom
   lda #1
   jsr set_item
   jmp select

fm_sel jsr read_item
   asl
   asl
   asl
   asl
   asl
   ora #%00010111
   sta current_note+1
   jmp enter_cmd

;
;Handle Yes/No type commands
;

snch lda #$33
   .byte $2c
rngh lda #$23
   .byte $2c
fxh lda #$43
   .byte $2c
o3h lda #$53
   .byte $2c
flth lda #$13
   .byte $2c
pvh lda #$73
   sta current_note+1

   jsr query_yn
   beq +
   lda current_note+1
   ora #%00001000
   sta current_note+1
+  jmp enter_cmd

;
;Invert value in NUMBER (two's complement)
;

invert_number = *

   lda #0
   sec
   sbc number
   sta number
   lda #0
   sbc number+1
   sta number+1
   rts

;
;Print positive or negative value in NUMBER.
;

print_number = *

   lda number+1
   bpl +
   jsr invert_number
   lda #"-"
   jsr printchar
+  ldx number
   ldy number+1
   jmp printword

;
;Prompt for number entry for current command.
;

prompt_number = *

   jsr make_cmd_win
   jsr print
   .byte xx+13,yy+3,col+1
   .asc "Enter "
   .byte eot
   jsr print_ct

   jsr print
   .asc " Value"
   .byte xx+13,yy+4,"(",eot
   lda low_range
   sta number
   lda low_range+1
   sta number+1
   jsr print_number
   jsr print
   .byte " ","-"," ",eot
   lda high_range
   sta number
   lda high_range+1
   sta number+1
   jsr print_number

   jsr print
   .byte ")",xx+13,yy+5,tab,28,xx+13,eot
   jsr get_gen_num
   bcc +
   jmp reselect_cmd
+  rts


;
;Get a numeric value between LOW_RANGE and HIGH_RANGE.
;

get_gen_num = *

   lda #0
   sta pos

gn0 jsr cursor_on
gn1 jsr getin
   beq gn1
   pha
   jsr cursor_off
   pla
   ldy pos
   cmp #13
   beq gn9
   cmp #135
   beq gn8
   cmp #3
   beq gn8
   cmp #20
   beq gn5
   cmp #"-"
   bne +
   cpy #0
   beq ++
+  cmp #"0"
   bcc gn0
   cmp #"9"+1
   bcs gn0
+  cpy #5
   bcs gn0
   sta text,y
   jsr printchar
   inc pos
   bne gn0

gn5 cpy #0
   beq gn0
   dec pos
   jsr backspace
   jmp gn0

gn8 sec
   rts

gn9 cpy #0
   beq gn8

   ldx #0
   stx number
   stx number+1

-  lda text,x
   cmp #"-"
   beq +
   lda number
   sta number+2
   lda number+1
   sta number+3
   ldy #2
-  asl number
   rol number+1
   dey
   bpl -
   asl number+2
   rol number+3
   lda number
   clc
   adc number+2
   sta number
   lda number+1
   adc number+3
   sta number+1
   lda text,x
   and #15
   clc
   adc number
   sta number
   lda number+1
   adc #0
   sta number+1
+  inx
   cpx pos
   bcc --

   lda number+1
   cmp #>16384
   bcc +
   jmp gn0

+  lda text
   cmp #"-"
   bne +
   jsr invert_number

+  lda number+1
   bmi high_ok

   lda high_range+1
   cmp number+1
   bne +
   lda high_range
   cmp number
+  bcs high_ok
not_ok jmp gn0

high_ok lda number+1
   cmp low_range+1
   bne +
   lda number
   cmp low_range
+  php

   lda low_range+1
   bmi hi2
   lda number+1
   bmi +
   plp
   bcc not_ok
   bcs low_ok

+  plp
   jmp not_ok

hi2 lda number+1
   bpl +
   plp
   bcs low_ok
   bcc not_ok

+  plp

low_ok clc
   rts

;
;Handle TEM command.
;

temh = *

   jsr save_screen
   jsr print
   .byte box,12,2,29,8,14,xx+13,yy+3,col+1
   .asc "Select TEM Value"
   .byte col+15,eot

   lda #56
   sta table
   lda #0
   sta table+1
   ldy #0
   ldx #62
-  lda tem_table,x
   sta table+2,y
   lda tem_table+1,x
   sta table+3,y
   iny
   iny
   dex
   dex
   bne -

   jsr headerdef
   .byte 8,15,1
   .word reselect_cmd,0,0,tem_bound
   ldy #3
-  lda #19
   jsr s_itemx
   tya
   clc
   adc #4
   jsr s_itemy
   lda #dispatch
   jsr s_itemtype
   lda #4
   jsr s_itemlen
   lda #<sel_tem
   jsr s_itemvecl
   lda #>sel_tem
   jsr s_itemvech
   dey
   bpl -
   lda #4
   jsr sizedef
   lda #14
   sta topfile
   lda #0
   jsr set_item

show_tem lda #0
   sta index
   lda topfile
   sta botfile
-  lda index
   clc
   adc #yy+4
   jsr printchar
   lda #xx+19
   jsr printchar
   lda botfile
   asl
   tay
   ldx table,y
   lda table+1,y
   tay
   jsr printword
   jsr print
   .byte tab,24,eot
   inc botfile
   inc index
   lda index
   cmp #4
   bcc -
   jmp select

tem_bound bne tem_up
   lda botfile
   cmp #32
   bcs +
   inc topfile
+  jmp show_tem

tem_up lda topfile
   beq +
   dec topfile
+  jmp show_tem

sel_tem lda #$06
   sta current_note
   jsr read_item
   clc
   adc topfile
   beq +
   eor #31
   adc #1
+  asl
   asl
   asl
   jmp stnenter

;
;Handle VOL command.
;

volh = *

   lda #15
   sta high_range
   jsr prompt_number
   lda number
   asl
   asl
   asl
   asl
   ora #$0e
   sta current_note+1
   jmp enter_cmd

;
;Handle DTN command.
;

dtnh = *

   lda #<2047
   sta high_range
   lda #>2047
   sta high_range+1
   lda #$f8
   sta low_range+1
   jsr prompt_number
   lda number
   sta current_note+1
   lda number+1
   and #7
   asl
   asl
   asl
   asl
   asl
   ora #$0a
   bit number+1
   bpl +
   ora #%00010000
+  sta current_note
   jmp enter_cmd

;
;Several 0-255 range commands
;

utlh lda #$16
   .byte $2c
pnth lda #$26
   .byte $2c
hedh lda #$36
   .byte $2c
flgh lda #$46
   .byte $2c
auxh lda #$b6
   .byte $2c
maxh lda #$e6
   .byte $2c
utvh lda #$f6
   .byte $2c
fch lda #$0e
   .byte $2c
hldh lda #$4e
   sta current_note

   lda #255
   sta high_range
second_bstore jsr prompt_number
   lda number
   sta current_note+1
   jmp enter_cmd

;
;Handle POR command
;

porh = *

   lda #<16383
   sta high_range
   lda #>16383
   sta high_range+1
   jsr prompt_number
   lda number
   sta current_note+1
   lda number+1
   asl
   asl
   ora #%00000011
   sta current_note
   jmp enter_cmd

;
;Handle various 0-127 commands
;

vrth lda #$86
   .byte $2c
vdph lda #$76
   .byte $2c
pvrh lda #$d6
   .byte $2c
pvdh lda #$c6
   sta current_note

max_127 lda #127
   sta high_range
   jmp second_bstore

;
;Handle various -128 to 127 commands
;

psh lda #$56
   .byte $2c
fsh lda #$66
   .byte $2c
auth lda #$96
   sta current_note

   lda #$80
   sta low_range
   lda #$ff
   sta low_range+1
   bne max_127

;
;Handle SCA command
;

scah lda #$6e
   sta current_note
   lda #$f9
   sta low_range
   lda #$ff
   sta low_range+1
   lda #7
   sta high_range
   jmp second_bstore

;
;Handle DEF and CAL
;

defh lda #$06
   .byte $2c
calh lda #$02
   sta current_note+1

   lda #23
   sta high_range
   jsr prompt_number
   lda number
   cmp #16
   bcs +
put_47 asl
   asl
   asl
   asl
ornst ora current_note+1
stnenter sta current_note+1
   jmp enter_cmd

+  ldy current_note+1
   cpy #2
   beq +
   ldy #$03
   .byte $2c
+  ldy #$0b
   sty current_note+1
   sec
   sbc #8
   bcs put_47

;
;DCY, RLS, and RES commands
;

dcyh lda #$00
   .byte $2c
rlsh lda #$08
   .byte $2c
resh lda #$0a
   sta current_note+1
   lda #15
   sta high_range
   jsr prompt_number
   lda number
   jmp put_47

;
;ATK and SUS commands
;

atkh lda #%00000100
   .byte $2c
sush lda #%10000100
   sta current_note+1
   lda #15
-  sta high_range
   jsr prompt_number
   lda number
   asl
   asl
   asl
   bcc ornst

;
;Handle RDN and RUP commands
;

rdnh lda #%00000101
   .byte $2c
ruph lda #%00000001
   sta current_note+1
   lda #31
   bne -

;
;Handle LFO command
;

lfoh lda #1
   sta high_range
   jsr prompt_number
   lda number
   asl
   asl
   asl
   ora #%01100011
jstnenter jmp stnenter

;
;Tables for SRC and DST commands
;

src_table    .byte %00011111,%00111111,%01011111

dst_table    .byte %10001111,%10101111,%11011111,%11101111

;
;Handle SCA
;

srch lda #2
   sta high_range
   jsr prompt_number
   ldy number
   lda src_table,y
   bne jstnenter

;
;Handle DST
;

dsth lda #3
   sta high_range
   jsr prompt_number
   ldy number
   lda dst_table,y
   bne jstnenter

;
;Handle TPS
;

tpsh lda #95
   sta high_range
   lda #$ff
   sta low_range+1
   lda #$a1
   sta low_range
   jsr prompt_number
   lda #$a6
   sta current_note
   lda number
   ldy #0
-  cmp tps_table,y
   beq +
   iny
   cpy #192
   bne -
+  tya
   jmp stnenter

;
;Handle RTP
;

rtph lda #47
   sta high_range
   lda #$ff
   sta low_range+1
   lda #$d1
   sta low_range
   jsr prompt_number
   lda #$2e
   sta current_note
   lda number
   ldy #0
-  cmp rtp_table,y
   beq +
   iny
   cpy #180
   bne -
+  tya
   jmp stnenter

;
;Handle MS# command
;

msh lda #<999
   sta high_range
   lda #>999
   sta high_range+1
   jsr prompt_number
   lda number+1
   asl
   asl
   asl
   asl
   asl
   asl
   ora #%00011110
   sta current_note
qqq1 lda number
   sta current_note+1
   jmp enter_cmd

;
;Handle P-W command
;

pwh lda #<4095
   sta high_range
   lda #>4095
   sta high_range+1
   jsr prompt_number
   lda number+1
   asl
   asl
   asl
   asl
   ora #$02
   sta current_note
   bne qqq1

;
;Handle JIF command
;

jifh lda #<757
   sta high_range
   lda #>757
   sta high_range+1
   lda #$38
   sta low_range
   lda #$ff
   sta low_range+1
   jsr prompt_number
   lda number+1
   bmi +
-  lda #0
   lsr number+1
   ror number
   ror
   lsr number+1
   ror number
   ror
   ora #%00111110
   sta current_note
   jmp qqq1

+  lda #3
   sta number+1
   bne -

;
;Search for command (forward)
;

cmd_searchf = *

   jsr search_common
   bne incfirst

-  ldy #1
   lda (ptr),y
   sta current_note+1
   dey
   lda (ptr),y
   sta current_note
   and #%00000011
   beq +
   txa
   pha
   jsr get_icon
   pla
   tax
   lda d$command
   cmp temp2
   bne +
   lda ptr
   sta voice_pos,x
   lda ptr+1
   sta voice_pos+1,x
   jmp disp_all

incfirst = *

+  lda ptr
   clc
   adc #2
   sta ptr
   bcc +
   inc ptr+1
+  lda ptr+1
   cmp voice_end+1,x
   bne +
   lda ptr
   cmp voice_end,x
+  bcc -
   rts

;
;Handle special command mode keys.
;

handle_ckey = *

   ldy #eke-ek1-1
-  cmp ek1,y
   beq +
   dey
   bpl -
   rts
+  tya
   asl
   tay
   lda ck_vec+1,y
   pha
   lda ck_vec,y
   pha
   jsr read_item
   sta e$command
   rts

;
;Command mode function key dispatch vectors.
;

ck_vec         .word cmd_next-1,cmd_last-1,cmd_right-1,cmd_left-1
               .word cmd_ins-1,cmd_del-1,cmd_toggle-1,cmd_searchf-1
               .word cmd_searchb-1

;
;Toggle one/all voice movement mode
;

cmd_toggle = *

   lda move_mode
   eor #1
   sta move_mode
   jmp place_sprite1

;
;Move to previous voice
;

cmd_last = *

   ldy voice
   dey
   bpl +
   ldy #5
+  sty voice
   jsr update_cmd
   jmp place_sprite1

;
;Move to next voice
;

cmd_next = *

   ldy voice
   iny
   cpy #6
   bcc +
   ldy #0
+  sty voice
   jsr update_cmd
   jmp place_sprite1

;
;Insert a HLT command at cursor position
;

cmd_ins = *

   jsr at_end
   bcs +
   jsr open1
   ldy #0
   lda #$01
   sta (ptr),y
   iny
   lda #$4f
   sta (ptr),y
   jsr modify
+  jmp disp_all

;
;Delete current command
;

cmd_del = *

   jsr at_end
   bcs +
   jsr close1
   jsr modify
+  jmp disp_n_up

;
;Move left
;

cmd_left = *

   lda #<cur_left
   sta funjsr+1
   lda #>cur_left
   sta funjsr+2

cmd_fun = *

   lda move_mode
   bne +
   lda voice
   asl
   tax
   jsr funjsr
   jmp disp_n_up
+  ldx #10
-  jsr funjsr
   dex
   dex
   bpl -
disp_n_up jsr update_cmd
   jmp disp_all
funjsr jmp cur_left

;
;Move right
;

cmd_right = *

   lda #<cur_right
   sta funjsr+1
   lda #>cur_right
   sta funjsr+2
   bne cmd_fun

;
;Update command selected at top of screen based on current command.
;

update_cmd = *

   lda cmd_update
   beq duc
   lda voice
   asl
   tay
   lda voice_pos,y
   sta ptr
   lda voice_pos+1,y
   sta ptr+1
   ldy #0
   lda (ptr),y
   sta current_note
   iny
   lda (ptr),y
   sta current_note+1
   jsr get_icon
   lda current_note
   and #3
   beq do_bong

   lda d$command
   ldy #48
-  cmp cmd_index_tab,y
   beq +
   dey
   bpl -
   bmi duc
+  sty e$command

duc rts

do_bong = *

   jmp bong_sub

;
;Search for command - BACKWARDS.
;

cmd_searchb = *

   jsr search_common
   bne decfirst

-  ldy #1
   lda (ptr),y
   sta current_note+1
   dey
   lda (ptr),y
   sta current_note
   and #%00000011
   beq +
   txa
   pha
   jsr get_icon
   pla
   tax
   lda d$command
   cmp temp2
   bne +
   lda ptr
   sta voice_pos,x
   lda ptr+1
   sta voice_pos+1,x
   jmp disp_all

decfirst = *

+  lda ptr
   sec
   sbc #2
   sta ptr
   bcs +
   dec ptr+1
+  lda ptr+1
   cmp voice_start+1,x
   bne +
   lda ptr
   cmp voice_start,x
+  bcs -
   rts

;
;Common code used by forward AND backward command searches.
;

search_common = *

   jsr read_item
   tax
   lda cmd_index_tab,x
   sta temp2

   lda voice
   asl
   tax
   lda voice_pos,x
   sta ptr
   lda voice_pos+1,x
   sta ptr+1

   rts

;
;--- Main disk access module ---
;
;Read SID directory from disk.
;

read_dir = *
 
   jsr init_mus

   jsr open_error_ch
   lda #0
   sta num_files
   lda #1
   ldx mus_device
   ldy #0
   jsr setlfs
   lda #dirchar1-dirchar
   ldx #<dirchar
   ldy #>dirchar
   jsr setnam
   jsr open
   jsr read_error
   cmp #20
   bcs dir_error
   ldx #1
   jsr chkin
   jsr chrin  ;Skip load address
   jsr chrin
   jsr chrin  ;Skip first line's link address
   jsr chrin
   jsr chrin  ;Skip first line's line number
   jsr chrin

-  jsr chrin  ;Skip rest of first line
   cmp #0
   bne -

ndl jsr chrin ;Skip line link address
   jsr chrin
   jsr chrin  ;Skip number of blocks
   jsr chrin

-  jsr chrin  ;Skip to first quote
   cmp #0
   beq ndl9
   cmp #34
   bne -

   ldy #0     ;Read filename
-  jsr chrin
   cmp #34
   beq +
   sta filename,y
   iny
   bne -
+  sty name_len

-  jsr chrin  ;Skip rest of line
   cmp #0
   bne -
   jsr filecheck  ;Analyze file
   jmp ndl

ndl9 jsr close_all ;Close directory file and exit
   clc
   rts

dir_error pha
   jsr close_all
   pla
   sec
   rts

;
;Check current filename to determine if it is a left or right channel
;SID file. If so, add it to directory list (if not already there).
;

filecheck = *
 
   lda #0
   sta mus_flag
   sta str_flag
   sta wds_flag

   ldy name_len
   dey
   dey
   dey
   dey
   bpl +
   rts
+  sty name_len
   ldx #0
-  lda filename,y
   cmp mus_ext,x
   bne +
   iny
   inx
   cpx #4
   bcc -
   inc mus_flag
   bcs vf

+  ldy name_len
   ldx #0
-  lda filename,y
   cmp str_ext,x
   bne +
   iny
   inx
   cpx #4
   bcc -
   inc str_flag
   bcs vf

+  ldy name_len
   ldx #0
-  lda filename,y
   cmp wds_ext,x
   bne +
   iny
   inx
   cpx #4
   bcc -
   inc wds_flag
   bcs vf
+  rts
 
vf lda mus_flag
   sta name_len+13
   lda str_flag
   sta name_len+14
   lda wds_flag
   sta name_len+15

   ldy #0                ;Is file stem in directory already?
vg cpy num_files
   bcs vh
   sty temp
   jsr get_file_adr
   ldy #0
-  lda name_len,y
   cmp (file_ptr),y
   bne +
   iny
   cpy name_len
   beq -
   bcc -
   ldy temp
   bcs vi

+  ldy temp
   iny
   bne vg

vh jsr put_file_info     ;File not in directory so add it.
   inc num_files
   rts

vi jsr get_file_info     ;File already in directory. Add flag.
   lda name_len+13
   ora mus_flag
   sta name_len+13
   lda name_len+14
   ora str_flag
   sta name_len+14
   lda name_len+15
   ora wds_flag
   sta name_len+15

   ldy temp
   jmp put_file_info

;
;Extensions used for L/R channels.
;

mus_ext .asc ".mus"
str_ext .asc ".str"
wds_ext .asc ".wds"

;
;Get address of file whose index is in .Y
;

get_file_adr = *

   sty file_ptr
   lda #0
   sta file_ptr+1
   ldy #4
-  asl file_ptr
   rol file_ptr+1
   dey 
   bne -
   lda file_ptr+1
   clc
   adc #>dir_info
   sta file_ptr+1
   rts

;
;Get file whose index number is in .Y
;

get_file_info = *
 
   jsr get_file_adr
   ldy #15
-  lda (file_ptr),y
   sta name_len,y
   dey
   bpl -
   rts

;
;Put file under index in .Y
;

put_file_info = *

   jsr get_file_adr
   ldy #15
-  lda name_len,y
   sta (file_ptr),y
   dey
   bpl -
   rts

;
;Allow file selection from a scrolling menu of files.
;

dir_select = *
 
   stx dir_cancel+1
   sty dir_cancel+2

   jsr headerdef
   .byte 7,15,1
   .word dir_cancel,0,dir_other,dir_bound

   lda num_files
   cmp #16
   bcc +
   lda #16
+  sta menusize
   jsr sizedef
   lda #25
   sec
   sbc menusize
   lsr
   sta topline

   jsr print
   .byte box,11,eot
   lda topline
   sec
   sbc #1
   jsr printchar
   lda #29
   jsr printchar
   lda topline
   clc
   adc menusize
   jsr printchar
   jsr print
   .byte 7,col+15,eot

   ldy #15
-  lda #dispatch
   jsr s_itemtype
   lda #12
   jsr s_itemx
   tya
   clc
   adc topline
   jsr s_itemy
   lda #17
   jsr s_itemlen
   lda #<sel_file
   jsr s_itemvecl
   lda #>sel_file
   jsr s_itemvech
   dey
   bpl -

home_dir = *

   lda #0
   sta topfile
   jsr set_item

;
;Display a screenful of filenames starting at the one whose index
;is top_item.
;

disp_files = *

   lda #0
   sta index
   lda topfile
   sta botfile
-  lda #xx+12
   jsr printchar
   lda index
   clc
   adc #yy
   adc topline
   jsr printchar
   ldy botfile
   jsr get_file_info
   jsr print_filename
   jsr print
   .byte tab,24,defr,5,24,eot
   lda index
   clc
   adc topline
   jsr printchar
   jsr print
   .byte 15,"(",eot
   ldy #0
-  lda name_len+13,y
   beq +
   lda msw_desig,y
   jsr printchar
+  iny
   cpy #3
   bcc -
   jsr print
   .byte ")",eof,eot
   inc botfile
   inc index
   lda index
   cmp menusize
   bcc --
   jmp select

;
;Music, Stereo, Words designators
;

msw_desig    .asc "MSW"

;
;Current file has been selected
;

sel_file = *
 
   jsr read_item
   clc
   adc topfile
   tay
   jmp get_file_info

;
;Handle other keypresses
;

dir_other = *

   cmp #19  ;HOME
   bne +
   jmp home_dir

+  cmp #147 ;CLR
   bne +
   lda menusize
   sec
   sbc #1
   jsr set_item
   lda num_files
   sbc menusize
   sta topfile
   jmp disp_files

+  jmp select

;
;File selection has been cancelled.
;

dir_cancel = *

   jmp $ffff

;
;Scroll files in either direction
;

dir_bound = *

   bne scroll_down
   lda botfile
   cmp num_files
   bcs +
   inc topfile
+  jmp disp_files

scroll_down = *

   lda topfile
   beq +
   dec topfile
+  jmp disp_files

;
;Print current filename
;

print_filename = *

   ldy #0
-  cpy name_len
   bcs +
   lda filename,y
   jsr printchar
   iny
   bne -
+  rts

;
;Sequence used to read directory of all program files on disk.
;

dirchar .asc "$0:*=p"
dirchar1 = *

;
;Load a .MUS file from disk and initialize all pointers accordingly.
;

load_mus = *

   jsr init_heap

   lda name_len+13
   sta mus_flag
   lda name_len+14
   sta str_flag
   lda name_len+15
   sta wds_flag
   beq +
   lda word_mode
   beq +

   jsr set_wds_ext
   jsr open_read
   jsr read_words
   jsr close_all

+  jsr init_vptrs
   lda #0
   sta cred_block

   lda mus_flag          ;Is there a .MUS file for this SID?
   bne +

   ldx #0
   jsr calc_empty        ;If not, just put in HLT commands for each voice
   jmp rstr

+  jsr set_mus_ext       ;If so, read from disk
   jsr open_read
   jsr chrin             ;Skip load address
   jsr chrin
   ldx #0                ;Calculate pointers for each voice
   jsr calc_all

   jsr read_credits      ;Read credit block

   jsr close_all         ;Close up files

rstr lda str_flag        ;Is there a .STR file?
   bne +

   ldx #6                ;If not, just flesh out with HLT commands
   jmp calc_empty

+  jsr set_str_ext       ;If so, read from disk
   jsr open_read
   jsr chrin
   jsr chrin
   ldx #6
   jsr calc_all
   jmp close_all

;
;Set up for music extension
;

set_mus_ext = *

   ldy name_len
   ldx #0
-  lda mus_ext,x
   sta filename,y
   iny
   inx
   cpx #4
   bcc -
   rts

;
;Set up for stereo extension
;

set_str_ext = *

   ldy name_len
   ldx #0
-  lda str_ext,x
   sta filename,y
   iny
   inx
   cpx #4
   bcc -
   rts

;
;Set up for words extension.
;

set_wds_ext = *

   ldy name_len
   ldx #0
-  lda wds_ext,x
   sta filename,y
   iny
   inx
   cpx #4
   bcc -
   rts

;
;Open .MUS or .STR file for reading.
;

open_read = *

   tya
   jsr open_error_ch
   ldx #<filename
   ldy #>filename
   jsr setnam
   lda #1
   ldx mus_device
   ldy #0
   jsr setlfs
   jsr open
   jsr read_error
   cmp #20
   bcs +
   ldx #1
   jsr chkin
   clc
   rts
+  pha
   jsr close_all
   pla
   sec
   rts

;
;Close files 1 and 15
;

close_all = *

   jsr clrchn
   lda #1
   jsr close
   lda #15
   jmp close

;
;Open error channel
;

open_error_ch = *

   pha
   lda #15
   ldx mus_device
   ldy #15
   jsr setlfs
   lda #0
   jsr setnam
   jsr open
   pla
   rts

;
;Open .MUS or .STR file for writing.
;

open_write = *

   tya
   jsr open_error_ch
   ldx #<filename
   ldy #>filename
   jsr setnam
   lda #1
   ldx mus_device
   ldy #1
   jsr setlfs
   jsr open

   jsr read_error
   bcs +

   ldx #1
   jsr chkout
   clc
   rts

+  pha
   jsr close_all
   pla
   sec
   rts

;
;Read in two-byte length of voice and use it to calculate some pointers.
;

calc_pointers = *

   lda current_note
   clc
   adc voice_start,x
   sta voice_pos+2,x
   sta voice_start+2,x
   lda current_note+1
   adc voice_start+1,x
   sta voice_pos+3,x
   sta voice_start+3,x
   lda voice_start+2,x
   sec
   sbc #2
   sta voice_end,x
   lda voice_start+3,x
   sbc #0
   sta voice_end+1,x
   rts

;
;Calculate all pointers for when there is a file
;

calc_all = *

-  jsr chrin
   sta current_note
   jsr chrin
   sta current_note+1
   jsr calc_pointers
   inx
   inx
   cpx #6
   beq +
   cpx #12
   bne -

;
;Read in actual note data for 3 voices.
;

+  lda #kernal_in
   sta 1
   ldy #0
-  jsr k_chrin
   sta (ptr),y
   inc ptr
   bne +
   inc ptr+1
+  lda ptr+1
   cmp voice_start+1,x
   bne +
   lda ptr
   cmp voice_start,x
+  bcc -
   lda #kernal_out
   sta 1

   rts

;
;Calculate all pointers for when there is no actual file
;

calc_empty = *

-  lda #2
   sta current_note
   lda #0
   sta current_note+1
   jsr calc_pointers
   inx
   inx
   cpx #6
   beq +
   cpx #12
   bne -

+  ldy #5
-  lda #$4f
   sta (ptr),y
   dey
   lda #$01
   sta (ptr),y
   dey
   bpl -
   lda ptr
   clc
   adc #6
   sta ptr
   bcc +
   inc ptr+1
+  rts

;
;Initialize PTR to start of SID heap.
;

init_heap = *

   lda #<start_heap
   sta ptr
   lda #>start_heap
   sta ptr+1

;
;Initialize pointers for voice 1
;

init_vptrs = *

   lda ptr               ;Initialize pointers for voice 1
   sta voice_start
   sta voice_pos
   lda ptr+1
   sta voice_start+1
   sta voice_pos+1
   rts

;
;Clear all voices
;

clear_all = *

   jsr init_heap
   ldx #0
   stx cred_block
   stx current_flen
   stx mod_flag
   stx wds_flag
   jsr calc_empty
   jmp calc_empty

;
;Scratch MUS, WDS, and STR files for current filename stem.
;

scratch_files = *

   lda #15
   ldx mus_device
   ldy #15
   jsr setlfs
   lda #0
   jsr setnam
   jsr open

   jsr scratch1
   ldy #0
-  lda mus_ext,y
   jsr chrout
   iny
   cpy #4
   bcc -
   jsr clrchn

   jsr scratch1
   ldy #0
-  lda str_ext,y
   jsr chrout
   iny
   cpy #4
   bcc -
   jsr clrchn

   lda voice_start
   cmp #<start_heap
   bne +
   lda voice_start+1
   cmp #>start_heap
   beq nsw
+  jsr scratch1
   ldy #0
-  lda wds_ext,y
   jsr chrout
   iny
   cpy #4
   bcc -
   jsr clrchn

nsw lda #15
   jmp close

scratch1 = *

   ldx #15
   jsr chkout
   lda #"s"
   jsr chrout
   lda #"0"
   jsr chrout
   lda #":"
   jsr chrout
   ldy #0
-  lda filename,y
   jsr chrout
   iny
   cpy name_len
   bcc -
   rts

;
;Send length pointers to output file.
;

send_length = *

-  jsr calc_len
   lda ptr
   jsr chrout
   lda ptr+1
   jsr chrout
   inx
   inx
   cpx #6
   beq +
   cpx #12
   bne -
+  rts

;
;Calculate length of voice
;

calc_len = *

   lda voice_start+2,x
   sec
   sbc voice_start,x
   sta ptr
   lda voice_start+3,x
   sbc voice_start+1,x
   sta ptr+1
   rts

;
;Send MUS data to current file.
;

send_mus = *

   lda voice_start
   sta ptr
   lda voice_start+1
   sta ptr+1
   ldy #0
-  lda (ptr),y
   jsr chrout
   inc ptr
   bne +
   inc ptr+1
+  lda ptr+1
   cmp voice_start+7
   bne -
   lda ptr
   cmp voice_start+6
   bne -
   rts

;
;Send STR data to current file.
;

send_str = *

   lda voice_start+6
   sta ptr
   lda voice_start+7
   sta ptr+1
   ldy #0
-  lda (ptr),y
   jsr chrout
   inc ptr
   bne +
   inc ptr+1
+  lda ptr+1
   cmp voice_start+13
   bne -
   lda ptr
   cmp voice_start+12
   bne -
   rts

;
;Save WDS, MUS, and STR files to disk.
;

save_sid = *

   lda voice_start
   cmp #<start_heap
   bne +
   lda voice_start+1
   cmp #>start_heap
   beq nowsave
+  jsr set_wds_ext
   jsr open_write
   bcc +
   jmp sse
+  jsr write_words
   jsr close_all

nowsave = *

   lda voice_start+6
   sec
   sbc voice_start
   tax
   lda voice_start+7
   sbc voice_start+1
   bne +
   cpx #6
   beq snm

+  jsr set_mus_ext
   jsr open_write
   bcs sse
   lda #0
   tax
   jsr chrout
   jsr chrout
   jsr send_length
   jsr send_mus
   jsr write_credits
   jsr close_all

snm = *

   lda voice_start+12
   sec
   sbc voice_start+6
   tax
   lda voice_start+13
   sbc voice_start+7
   bne +
   cpx #6
   beq sns

+  jsr set_str_ext
   jsr open_write
   bcs sse
   lda #0
   jsr chrout
   jsr chrout
   ldx #6
   jsr send_length
   jsr send_str
   lda #0
   jsr chrout
   jsr close_all

sns = *

   clc

sse = *

   rts

;
;Move current_file to filename.
;

set_cur_file = *

   ldy #0
-  cpy current_flen
   bcs +
   lda current_file,y
   sta filename,y
   iny
   bne -
+  sty name_len
   rts

;
;Initialize MUSIC disk drive.
;

init_mus = *

   lda mus_device
   sta 186
   jmp init_drive

;
;Read credit blocks from disk.
;

read_credits = *

   ldy #0
-  jsr chrin
   sta cred_block,y
   cmp #0
   beq +
   iny
   bne -

-  jsr chrin
   sta cred_block+256,y
   cmp #0
   beq +
   iny
   bne -

+  rts

;
;Write credit blocks to disk.
;

write_credits = *

   ldy #0
-  lda cred_block,y
   beq +
   jsr chrout
   iny
   bne -

-  lda cred_block+256,y
   beq +
   jsr chrout
   iny
   bne -

+  lda #0
   jsr chrout

   rts

;
;Save configuration menu option.
;

save_config = *

   jsr one_moment_please

   lda pr_device
   sta 186
   jsr init_drive

   lda #15
   ldx pr_device
   ldy #15
   jsr setlfs
   lda #scr_cmd1-scr_cmd
   ldx #<scr_cmd
   ldy #>scr_cmd
   jsr setnam
   jsr open
   jsr read_error
   cpx #1    ;1 file scratched
   bne +
   cmp #1    ;"Files scratched" error
   beq ++

+  lda #15
   jsr close
   jsr prompt_insert
   jsr abort_cont
   bcc save_config
   jmp rec_n_ret

+  lda #15
   jsr close
   lda #1
   ldx pr_device
   ldy #1
   jsr setlfs
   lda #3
   ldx #<file_007
   ldy #>file_007
   jsr setnam
   jsr open

   ldx #1
   jsr chkout

   lda #0
   jsr chrout
   jsr chrout

   ldy #0
-  lda config,y
   jsr chrout
   iny
   cpy #169
   bcc -

   ldy #0
-  lda config+169,y
   beq +
   jsr chrout
   iny
   bne -

+  lda #0
   jsr chrout
   jsr clrchn
   lda #1
   jsr close
   jmp rec_n_ret

;
;Command to scratch configuration file (007).
;

scr_cmd      .asc "s0:"
file_007     .asc "007"
scr_cmd1     = *

;
;Read in a words file.
;

read_words = *

   ldy #0
   jsr chrin
   cmp #$ff                    ;Is it extended words? :(
   bne +
   rts                         ;YES - Don't read them in

-  jsr chrin
+  ldx $90
   sta (ptr),y
   inc ptr
   bne +
   inc ptr+1
+  cpx #0
   beq -
   lda #0
   sta (ptr),y
   inc ptr
   bne +
   inc ptr+1
+  rts

;
;Write out a words file
;

write_words = *

   lda #<start_heap
   sta ptr
   lda #>start_heap
   sta ptr+1

   ldy #0
-  lda (ptr),y
   beq +
   jsr chrout
   inc ptr
   bne -
   inc ptr+1
   bne -
+  rts

;
;Disk insertion procedure
;

insert_proc = *

   sty topfile
-  sty temp
   tya
   asl
   tax
   jsr chrin
   sec
   sbc #2
   sta vlen,x
   sta ptr
   php
   jsr chrin
   plp
   sbc #0
   sta vlen+1,x
   sta ptr+1
   lda ptr
   ora ptr+1
   beq +
   jsr insert_area
   lda temp
   asl
   tax
   jsr add_end
   jsr adjust_forward
+  ldy temp
   iny
   cpy #3
   beq il4
   cpy #6
   bcc -

il4 lda topfile
   asl
   tax
   lda voice_pos,x
   sta file_ptr
   lda voice_pos+1,x
   sta file_ptr+1
   lda vlen,x
   sta ptr
   lda vlen+1,x
   sta ptr+1

   ldy #0
-  lda ptr
   ora ptr+1
   beq il5
   jsr chrin
   sta (file_ptr),y
   lda ptr
   bne +
   dec ptr+1
+  dec ptr
   inc file_ptr
   bne +
   inc file_ptr+1
+  jmp -

il5 jsr chrin  ;Skip HLT
   jsr chrin

   inc topfile
   lda topfile
   cmp #3
   beq +
   cmp #6
   bcc il4

+  jmp close_all

;
;Main insertion procedure. Opens files, etc.
;

do_insert_file = *

   jsr init_mus

   jsr set_mus_ext
   jsr open_read
   bcs +
   jsr chrin
   jsr chrin
   ldy #0
   jsr insert_proc

+  jsr set_str_ext
   jsr open_read
   bcs +
   jsr chrin
   jsr chrin
   ldy #3
   jsr insert_proc

+  rts

;
;Given a number of bytes to insert in PTR, check if there is enough
;free memory. Return only if OK.
;

check_memory = *

   lda voice_start+12
   clc
   adc ptr
   lda voice_start+13
   adc ptr+1
   cmp #$bf    ;----- Memory ceiling -----
   bcs +
   rts

+  ldx #$fa
   txs
   jsr recall_screen
   jsr close_all
   jsr print
   .byte box,11,9,28,15,7,col+15,xx+13,yy+11
   .asc "Out of Memory!"
   .byte xx+13,yy+13
   .asc "Press RETURN."
   .byte eot
   jsr abort_cont
   jsr recall_screen
   jmp da

;-- Put this here for posterity ;D --

   .asc "Stereo Editor V1.0 - Written by Robert A. Stoerrle (MALAKAI) - "
   .asc "November 24, 1989 - Long live Q-Link!"

play_sid = *

   jsr one_voice_on
   jmp +

play_all = *

   jsr all_voices_on

+  jsr reject_cut
   jsr refuse_midi

   ldy #5
-  lda midi_channel,y
   sta play_channel,y
   lda orig_color,y
   sta bar_color,y
   sta p$aux_val,y
   dey
   bpl -

   lda #64
   sta 650
   lda 56335
   and #127
   sta 56335

   lda #0
   sta 56331
   sta 56330
   sta 56329
   sta 56328

   sta pause_mode
   sta play_screen
   sta wds_flag
   sta play_speed
   sta play_count

   lda word_mode
   beq no_wds
   lda voice_start
   cmp #<start_heap
   bne +
   lda voice_start+1
   cmp #>start_heap
   beq no_wds

+  inc wds_flag
   lda #<start_heap
   sta wds_ptr
   lda #>start_heap
   sta wds_ptr+1

no_wds = *

   jsr update_playtop

   jsr store_route

   lda stereo_mode
   beq +
   clc
   adc #$dd
+  sta p$address
   lda expand_value
   sta p$expand
   lda route
   sta p$route

   jsr init_play

   lda #%00111111
   ldx stereo_mode
   bne ++
   ldx route
   bne +
   lda #%00000111
   bne ++
+  lda #%00111000
+  sta p$status

   lda interface_type
   beq abcd
   lda #%00111111
   sta p$status

abcd = *

;
;Play simulation.
;

   lda voice
   asl
   tay
   lda voice_pos,y
   sta ptr
   lda voice_pos+1,y
   sta ptr+1

   lda vic+21
   and #%11111110
   sta vic+21

   sei
   lda #%01111111
   sta $dc00
   lda #1
   sta p$mode
-  lda $dc01
   eor #255
   bne sim_exit
   jsr sim_start
   ldx voice
   lda p$musich,x
   cmp ptr+1
   bne +
   lda p$musicl,x
   cmp ptr
+  bcs regular_play
   lda p$flag
   beq +
   jsr next_wds
   lda #0
   sta p$flag
+  lda p$status
   bne -

sim_exit = *

-  lda $dc01
   eor #255
   bne -
   cli
   jmp pquit

;
;Play normally
;

regular_play = *

   cli
   lda vic+21
   ora #1
   sta vic+21
   lda #0
   sta p$mode

   jsr show_wds
   jsr next_wds
   
   ldx #<pinter
   ldy #>pinter
   jsr setirq

play_loop = *

   jsr update_time

   lda p$flag
   beq plb
   lda #0
   sta p$flag
   lda play_screen
   bne +
   jsr show_wds
+  jsr next_wds

plb lda play_screen
   beq +
   jsr show_play_cmd
   jmp ck
+  jsr show_play_note

ck inc vic+39
   lda #0               ;Check keyboard matrix for activity
   sta $dc00
   lda $dc01
   eor #255
   bne pk_handle
   lda #0
   sta 197

   lda p$status
   bne play_loop
   jmp pquit

;
;Handle player keypresses.
;

pk_handle = *

   lda #kernal_in
   sta 1
   jsr $ff9f            ;Scan keyboard to get specific keypress
   lda #kernal_out
   sta 1
   jsr getin

   ldy #play_key1-play_key-1
-  cmp play_key,y
   beq +
   dey
   bpl -
   jmp play_loop

+  tax
   tya
   asl
   tay
   lda pk_vec+1,y
   pha
   lda pk_vec,y
   pha
   txa
   rts

;
;Player keys and dispatch vectors.
;

play_key      .byte 17+128,17,"s",32,"_"
              .byte "1","2","3","4","5","6"
              .byte "7",29+128,29,13,133,134,135,"p",136,"+"
              .byte ":",";","="
play_key1     = *

pk_vec        .word pk_up-1,pk_down-1,pk_staff-1,pk_space-1,pk_f7-1
              .word pk_tv-1,pk_tv-1,pk_tv-1,pk_tv-1,pk_tv-1,pk_tv-1
              .word pk_all_on-1,pk_up-1,pk_down-1,pk_update-1
              .word pk_piano-1,pk_voice-1,pk_global-1,pk_pause-1
              .word pk_bars-1,pk_step-1,pk_slow-1,pk_fast-1,pk_norm-1

;-- Set play at normal speed --

pk_norm = *

   lda #0
   sta play_speed
   jmp play_loop

;-- Set play speed one magnitude lower --

pk_slow = *

   inc play_speed
   jmp play_loop

;-- Set play speed one magnitude higher --

pk_fast = *

   lda play_speed
   beq +
   dec play_speed
+  jmp play_loop

;-- Single step during pause mode --

pk_step = *

   lda pause_mode
   beq +
   jsr sim_start
+  jmp play_loop

;
;Begin monitoring previous voice
;

pk_up = *

   and #127
   pha
   ldy voice
   dey
   bpl +
   ldy #5
+  sty voice

pk_moved2 = *

   pla
   cmp #29
   bne pk_moved
   jsr one_voice_on
   jsr update_playtop

pk_moved = *

   lda play_screen
   bne +
   jsr show_voice_staff
+  jsr place_sprite1
   jmp play_loop

;
;Begin monitoring next voice
;

pk_down = *

   and #127
   pha
   ldy voice
   iny
   cpy #6
   bcc +
   ldy #0
+  sty voice
   jmp pk_moved2

;
;Handle changing of staff type.
;

pk_staff = *

   ldx voice
   lda voice_staff,x
   clc
   adc #1
   cmp #6
   bcc +
   lda #0
+  sta voice_staff,x
   inc current_note
   jmp pk_moved

;
;Handle canceling by F7.
;

pk_f7 = *

   jsr get_play_pos

;
;Handle canceling by SPACE bar.
;

pk_space = *

   jmp pquit

;
;Handle turning voices on and off
;

pk_tv = *

   and #7
   tax
   dex
   lda p$enable,x
   eor #1
   sta p$enable,x
-  jsr update_playtop
   jmp play_loop

;
;Turn all voices on
;

pk_all_on = *

   jsr all_voices_on
   jmp -

;
;Show position in each voice currently.
;

pk_update = *

   jsr get_play_pos
   jsr disp_all
   jmp play_loop

;
;Go to piano display screen if not already there.
;

pk_piano = *

   lda play_screen
   beq pkp
   lda #0
   sta play_screen

   lda #%01100001
   sta vic+21
   ldx voice
   lda voice_staff,x
   sta staff_type
   jsr note_top
   jsr play_show
   lda old_wds_ptr
   sta wds_ptr
   lda old_wds_ptr+1
   sta wds_ptr+1
   jsr show_wds
   jsr next_wds
   inc current_note
pkp jmp play_loop

;
;Go to timing display screen
;

pk_bars = *

   lda #3
   cmp play_screen
   beq pkp
   sta play_screen

   jsr draw_bdisp
   jsr show_play_cmd
   jmp play_loop

;
;Go to voice parameter display.
;

pk_voice = *

   lda #1
   cmp play_screen
   beq pkp
   sta play_screen

   jsr draw_vdisp
   jsr show_play_cmd
   jmp play_loop

;
;Go to global parameter display.
;

pk_global = *

   lda #2
   cmp play_screen
   beq pkp
   sta play_screen

   jsr draw_gdisp
   jsr show_play_cmd
   jmp play_loop

;
;Pause/unpause playing.
;

pk_pause = *

   lda pause_mode
   beq +
   lda #0
   sta pause_mode
   sta p$mode
   jsr revive_clock
   lda p$cur_rate
   ldy p$cur_rate+1
   sta $dc04
   sty $dc05
   ldx #<pinter
   ldy #>pinter
   jsr setirq
;   jsr remove_if_3
   jmp play_loop

+  jsr stop_clock
   ldx #<qinter
   ldy #>qinter
   jsr setirq
   lda #1
   sta pause_mode
   sta p$mode
   lda #$d4
   jsr clear_chip
   lda p$address
   beq +
   jsr clear_chip
+  jmp play_loop

;
;Clear one sid chip (address in .A)
;

clear_chip = *

   sta ptr+1
   ldy #24
   lda #0
   sta ptr
-  sta (ptr),y
   dey
   bpl -
   rts

;
;Exit play mode.
;

pquit = *

   lda p$error
   pha
   ldx #<inter
   ldy #>inter
   jsr setirq
   jsr drop_play
   cli
   pla
   jsr play_error
   lda play_screen
   beq +
   jsr note_top
+  jsr draw_top_line
   jsr update_top
   jsr print
   .byte xx+0,yy+10,tab,40,xx+0,yy+11,tab,40,eot
   lda #128
   sta 650
   jsr check_ranges
   jsr accept_midi
   jmp edit

;
;Create/Update top of screen for playing.
;

update_playtop = *

   jsr print
   .byte rvs,col+7,xx+0,yy+0
   .asc "Playing: L"
   .byte eot
   ldy #1
-  tya
   ora #$30
   tax
   lda p$enable-1,y
   bne +
   ldx #32
+  txa
   jsr printchar
   iny
   cpy #4
   bne -

   lda interface_type
   bne +
   lda stereo_mode
   beq upt2

+  jsr print
   .asc " R"
   .byte eot
   ldy #1
-  tya
   ora #$30
   tax
   lda p$enable+2,y
   bne +
   ldx #32
+  txa
   jsr printchar
   iny
   cpy #4
   bne -

upt2 lda interface_type
   beq +

   jsr print
   .byte tab,22
   .asc "MIDI"
   .byte eot

+  jsr print
   .byte tab,29
   .asc "ET: "
   .byte xx+35,":",xx+38,".",rvsoff,eot

;
;Update elapsed play time at top of screen (unless in pause mode)
;

update_time = *

   lda pause_mode
   bne +
   lda 56331
   lda 56330
   pha
   lsr
   lsr
   lsr
   lsr
   ora #48+128
   sta screen+33
   pla
   and #15
   ora #48+128
   sta screen+34

   lda 56329
   pha
   lsr
   lsr
   lsr
   lsr
   ora #48+128
   sta screen+36
   pla
   and #15
   ora #48+128
   sta screen+37

   lda 56328
   and #15
   ora #48+128
   sta screen+39

+  rts

;
;Subroutine to initialize some song parameters.
;

init_para = *

   lda #0
   sta route

   lda #0
   sta voice
   sta move_mode
   sta time_top
   sta time_bot

   jsr calc_time ;Set up for initial time signature

   ldy #e$accidental-e$duration
   lda #0
   sta e$command
   sta key
-  sta e$duration,y
   dey
   bpl -

   ldy #5
-  sta voice_staff,y
   dey
   bpl -
   sta staff_type

   lda #c_note
   sta e$note_letter
   sta r$note_letter
   lda #3
   sta e$octave
   lda #natural
   sta e$accidental
   sta r$accidental
   lda #quarter_note
   sta e$duration

   rts

;
;Call play interrupt. Skip keyscan, etc.
;

pinter = *

   lda play_count
   bne +
   lda play_speed
   sta play_count
   jsr play_inter
   jmp exit_mirq

+  dec play_count
   lda $dc0d
   jmp exit_mirq

;
;Player Error Text
;

error_text     .byte eot
               .asc "Clobber (Ouch!)"
               .byte eot
               .asc "Illegal Duration"
               .byte eot
               .asc "Duration Overflow"
               .byte eot
               .asc "Stack Underflow"
               .byte eot
               .asc "Stack Overflow"
               .byte eot
               .asc "CAL without DEF"
               .byte eot
               .asc "Repeat Head"
               .byte eot

;
;Create player error dialogue (error number 0-7 in .A)
;

play_error = *

   cmp #0
   beq per
   pha
   lda vic+21
   and #%11111110
   sta vic+21

   jsr save_screen
   jsr print
   .byte box,7,9,33,16,7,xx+9,yy+14,col+15
   .asc "Press RETURN."
   .byte xx+9,yy+11,eot
   lda #<error_text
   sta txtptr
   lda #>error_text
   sta txtptr+1
   pla 
   jsr select_string
   jsr lprint

   jsr print
   .asc " Error"
   .byte xx+9,yy+12
   .asc "in Voice "
   .byte eot
   lda p$error_voice
   jsr printchar
   lda #"."
   jsr printchar

   jsr abort_cont
   jsr recall_screen
   jsr get_play_pos

per rts

;
;Display current two lines of words, first defaulting to light blue, second
;to blue color.
;

show_wds = *

   lda wds_flag
   beq per
   lda wds_ptr
   sta ptr
   lda wds_ptr+1
   sta ptr+1
   jsr print
   .byte xx+1,yy+10,col+14,eot
   jsr disp_line

   jsr print
   .byte xx+1,yy+11,col+6,eot
   jmp disp_line

;
;Display a line of words (terminated by carriage return, pointed to by PTR).
;At end, PTR points to start of NEXT line of words.
;

disp_line = *

   ldy #0
   lda (ptr),y
   beq eo_w

-  lda (ptr),y
   cmp #13
   beq +
   jsr conv_wds
   iny
   bne -
+  iny
   tya
   clc
   adc ptr
   sta ptr
   bcc eo_w
   inc ptr+1

eo_w jsr print
   .byte tab,40,rvsoff,eot
   rts

;
;Convert a WDS file character to proper print code and send it to PRINTCHAR.
;

conv_wds = *

   cmp #32
   bcc cwspec
   cmp #64
   bcs +
   jmp printchar
+  cmp #96
   bcs +
   adc #128
   jmp printchar
+  cmp #128
   bcs +
-  rts
+  cmp #160
   bcc cwspec
   cmp #192
   bcc -
   cmp #224
   bcs -
   sbc #127
   jmp printchar

cwspec = *

   ldx #spec_char1-spec_char-1
-  cmp spec_char,x
   bne +
   lda conv_char,x
   jmp printchar
+  dex
   bpl -
   rts

;
;Special WDS file character conversion tables.
;

spec_char     .byte 18,146
              .byte $90,$05,$1c,$9f,$9c,$1e,$1f,$9e
              .byte $81,$95,$96,$97,$98,$99,$9a,$9b,160

spec_char1    = *

conv_char     .byte rvs,rvsoff
              .byte col+0,col+1,col+2,col+3,col+4,col+5,col+6,col+7
              .byte col+8,col+9,col+10,col+11,col+12,col+13,col+14,col+15
              .byte 32

;
;Turn all voices on.
;

all_voices_on = *

   ldy #5
   lda #1
-  sta p$enable,y
   dey
   bpl -
   rts

;
;Go to next line of WDS file.
;

next_wds = *

   lda wds_flag
   beq nwr
   lda wds_ptr
   sta old_wds_ptr
   lda wds_ptr+1
   sta old_wds_ptr+1
   ldy #0
   lda (wds_ptr),y
   beq nwr
-  lda (wds_ptr),y
   cmp #13
   beq +
   iny
   bne -
+  iny
   tya
   clc
   adc wds_ptr
   sta wds_ptr
   bcc nwr
   inc wds_ptr+1
nwr rts

;
;Turn only current voice on for playing.
;

one_voice_on = *

   ldy voice
   ldx #5
   lda #0
-  sta p$enable,x
   dex
   bpl -
   lda #1
   sta p$enable,y
   rts

;
;Draw display top for a single voice.
;

draw_vdisp = *

   lda #1
   sta vic+21
   jsr clear_top_cyan
   jsr print
   .byte box,33,2,39,5,14,xx+36,yy+4,col+3," ",xx+34,yy+3,col+13
   .asc "Voice"
   .byte eot

   ldx #22
-  lda vdisp_y,x
   pha
   lsr
   lsr
   lsr
   lsr
   tay
   lda vdisp_x,y
   clc
   adc #xx
   jsr printchar
   pla
   and #15
   clc
   adc #yy
   jsr printchar
   stx temp
   lda vdisp_index,x
   asl
   adc vdisp_index,x
   jsr print_cmdtxt
   ldx temp
   dex
   bpl -

   rts

;
;Indexes of commands
;

vdisp_index  .byte 13,14,15,16,26,37
             .byte 8,45
             .byte 38,32,33
             .byte 3,2
             .byte 29,30
             .byte 48,7
             .byte 47,43,44
             .byte 1,35
             .byte 49

;
;Coordinates of commands (Bits 0-3 : Y-coordinate, 4-7 : Column 0-3)
;

vdisp_y      .byte $02,$03,$04,$05,$06,$07,$09,$0a
             .byte $12,$13,$14,$16,$17,$19,$1a
             .byte $22,$23,$25,$26,$27,$29,$2a
             .byte $38

;
;X-coordinates of columns 0-3
;

vdisp_x      .byte 0,11,22,35

;
;Indexes of global commands.
;

gdisp_index  .byte 42
             .byte 9,36,41,39,4,17
             .byte 6,21,22,34,5
             .byte 25,18

;
;Coordinates of global commands (Bits 0-3 : Y-coordinate, 4-7: Column)
;

gdisp_y      .byte $03,$05,$06,$07,$08,$09,$0a
             .byte $a2,$a3,$a4,$a5,$a6,$a8,$a9

;
;Update staff and piano displays during playing.
;

show_play_note = *

   ldx voice
   lda p$byte_1,x
   cmp current_note
   bne +
   lda p$byte_2,x
   cmp current_note+1
   beq ck2
+  lda p$byte_2,x
   sta current_note+1
   lda p$byte_1,x
   sta current_note
   and #3
   bne ck2
   jsr get_icon
   ldy #d$accidental-d$duration
-  lda d$duration,y
   sta e$duration,y
   dey
   bpl -
   jmp play_show
ck2 rts

;
;Update command parameters during playing (for either voice or global
;parameter screen).

show_play_cmd = *

   lda play_screen
   cmp #1
   beq +
   cmp #2
   bne nmg
   jmp monitor_global
nmg jmp monitor_bars

+  lda #0
   sta xadd

   lda voice
   tax
   clc
   adc #49
   sta 4*40+36+screen
   
   jsr get_meas
   ldx #<40*9+35+screen
   ldy #>40*9+35+screen
   jsr store_large

+  ldx voice
   lda p$atk_dcy,x
   pha
   lsr
   lsr
   lsr
   lsr
   clc
   ldx #<2*40+4+screen
   ldy #>2*40+4+screen
   clc
   jsr store_small
   pla
   and #15
   ldx #<3*40+4+screen
   ldy #>3*40+4+screen
   clc
   jsr store_small

   ldx voice
   lda p$sus_rel,x
   pha
   lsr
   lsr
   lsr
   lsr
   clc
   ldx #<4*40+4+screen
   ldy #>4*40+4+screen
   clc
   jsr store_small
   pla
   and #15
   ldx #<5*40+4+screen
   ldy #>5*40+4+screen
   clc
   jsr store_small

   ldy #0
   ldx voice
   lda p$v_gate,x
   ldx #"n"
   lsr
   lsr
   bcc +
   ldx #"y"
+  stx 6*40+15+screen
   ldx #"n"
   lsr
   bcc +
   ldx #"y"
+  stx 7*40+15+screen
   lsr
   lsr
   bcc +
   ldx #"t"
   stx 9*40+4+screen
   iny
+  lsr
   bcc +
   pha
   lda #"s"
   sta 9*40+4+screen,y
   pla
   iny
+  lsr
   bcc +
   pha
   lda #"p"
   sta 9*40+4+screen,y
   pla
   iny
+  lsr
   bcc +
   lda #"n"
   sta 9*40+4+screen
   iny
+  lda #32
   sta 9*40+4+screen,y
   sta 9*40+4+screen+1,y

   ldx voice
   lda p$pnt_val,x
   clc
   ldx #<40*6+4+screen
   ldy #>40*6+4+screen
   jsr store_small

   ldx voice
   lda p$hld_val,x
   clc
   ldx #<40*7+4+screen
   ldy #>40*7+4+screen
   jsr store_small

   ldx voice
   lda p$utv_val,x
   clc
   ldx #<40*10+26+screen
   ldy #>40*10+26+screen
   jsr store_small

   ldx voice
   lda p$pvd_val,x
   clc
   ldx #<40*3+15+screen
   ldy #>40*3+15+screen
   jsr store_small

   ldx voice
   lda p$pvr_val,x
   clc
   ldx #<40*4+15+screen
   ldy #>40*4+15+screen
   jsr store_small

   ldx voice
   lda p$vdp_val,x
   clc
   ldx #<40*9+15+screen
   ldy #>40*9+15+screen
   jsr store_small

   ldx voice
   lda p$vrt_val,x
   clc
   ldx #<40*10+15+screen
   ldy #>40*10+15+screen
   jsr store_small

   ldx voice
   lda p$por_val_l,x
   ldy p$por_val_h,x
   sta d$cmd_value
   sty d$cmd_value+1
   ldx #<40*2+26+screen
   ldy #>40*2+35+screen
   clc
   jsr store_large

   ldx voice
   lda p$pulse_l,x
   ldy p$pulse_h,x
   sta d$cmd_value
   sty d$cmd_value+1
   ldx #<40*10+4+screen
   ldy #>40*10+4+screen
   clc
   jsr store_large

   ldx voice
   ldy #"n"
   lda p$p_v_val,x
   beq +
   ldy #"y"
+  sty 3*40+26+screen

   ldy six_to_two,x
   lda p$reson,y
   and flt_table,x
   bne +
   lda #"n"
   .byte $2c
+  lda #"y"
   sta 40*9+26+screen

   ldy p$tps_val,x
   lda tps_table,y
   ldx #<40*6+26+screen
   ldy #>40*6+26+screen
   jsr single_sign

   ldx voice
   ldy p$rtp_val,x
   lda rtp_table,y
   ldx #<40*7+26+screen
   ldy #>40*7+26+screen
   jsr single_sign

   ldx voice
   lda p$dtn_l,x
   ldy p$dtn_h,x
   sta d$cmd_value
   sty d$cmd_value+1
   clc
   bpl +
   jsr adjust_signed
   sec
+  ldx #<40*5+26+screen
   ldy #>40*5+26+screen
   jsr store_large

   ldx voice
   lda p$aps_l,x
   ldy p$aps_h,x
   sta d$cmd_value
   sty d$cmd_value+1
   clc
   bpl +
   jsr adjust_signed
   sec
+  ldx #<40*2+15+screen
   ldy #>40*2+15+screen
   jmp store_large

;
;Handle single byte signed printing.
;

single_sign = *

   clc
   ora #0
   bpl store_small
   sta temp
   lda #0
   sec
   sbc temp
   sec

;
;Store one byte values to screen (value in .A, carry set = negative).
;.X, .Y = screen address.
;

store_small = *

   php
   pha
   txa
   clc
   adc xadd
   sta ptr
   bcc +
   iny
+  sty ptr+1
   jsr clear_row2
   pla
   plp
   bcc +
   jsr convert_neg_byte
   jmp copy_row2
+  jsr convert_byte

;
;Copy ROW2_TEXT to screen
;

copy_row2 = *

   ldy #4
-  lda row2_text,y
   sta (ptr),y
   dey
   bpl -
   rts

;
;Clear ROW2_TEXT
;

clear_row2 = *

   lda #32
   ldy #4
-  sta row2_text,y
   dey
   bpl -
   rts

;
;Store value greater than 255 on screen (carry flag = positive/negative,
;.X, .Y = coordinates, d$cmd_value = value).
;

store_large = *

   lda #0
   ror
   sta d$cmd_sign
   txa
   clc
   adc xadd
   sta ptr
   bcc +
   iny
+  sty ptr+1
   jsr clear_row2
   jsr ci4
   jmp copy_row2

;
;Tables for extracting FLT values.
;

flt_table    .byte 1,2,4,1,2,4

six_to_two   .byte 0,0,0,1,1,1

;
;Draw display top for global parameters.
;

draw_gdisp = *

   lda #1
   sta vic+21
   jsr clear_top_cyan
   lda #col+13
   jsr printchar

   ldx #19
   ldy #1
   jsr get_adr
   ldx #11
   ldy #0
-  lda #95
   sta (txtptr),y
   lda #11
   sta (start_m),y
   lda txtptr
   clc
   adc #40
   sta txtptr
   sta start_m
   bcc +
   inc txtptr+1
   inc start_m+1
+  dex
   bne -

   ldx #13
-  lda gdisp_y,x
   pha
   and #15
   clc
   adc #yy
   jsr printchar
   pla
   lsr
   lsr
   lsr
   lsr
   clc
   adc #xx
   pha
   jsr gdisp1
   pla
   clc
   adc #21
   jsr gdisp1
   dex
   bpl -

   jsr print
   .byte xx+0,yy+2
   .asc "JIF"
   .byte xx+21
   .asc "MS#"
   .byte eot

   rts
   
gdisp1 jsr printchar
   stx temp
   lda gdisp_index,x
   asl
   adc gdisp_index,x
   jsr print_cmdtxt
   ldx temp
   rts

;
;Monitor global parameters.
;

monitor_global = *

   lda #21
   ldx #1
   sta xadd
   stx index
   
mg1 = *

   ldx index
   lda p$tempo,x
   jsr tem_trans
   ldx #<3*40+4+screen
   ldy #>3*40+4+screen
   clc
   jsr store_large

   ldx index
   lda p$utl_val,x
   clc
   ldx #<8*40+14+screen
   ldy #>8*40+14+screen
   jsr store_small

   ldx index
   lda p$volume,x
   pha
   ldx xadd
   asl
   ldy #"n"
   bcc +
   ldy #"y"
+  pha
   tya 
   sta 6*40+14+screen,x
   pla
   asl
   bcc +
   pha
   lda #"h"
   sta 5*40+4+screen,x
   pla
   inx
+  asl
   bcc +
   pha
   lda #"b"
   sta 5*40+4+screen,x
   pla
   inx
+  asl
   bcc +
   pha
   lda #"l"
   sta 5*40+4+screen,x
   pla
   inx
+  cpx xadd
   bne +
   lda #"n"
   sta 5*40+4+screen,x
   inx
+  lda #32
   sta 5*40+4+screen,x
   sta 5*40+4+screen+1,x
   pla
   and #15
   clc
   ldx #<9*40+14+screen
   ldy #>9*40+14+screen
   jsr store_small

   ldx index
   lda p$reson,x
   lsr
   lsr
   lsr
   lsr
   ldy #"n"
   bcc +
   ldy #"y"
+  cpx #0
   bne +
   sty 9*40+4+screen
   beq ++
+  sty 9*40+4+screen+21
+  clc
   ldx #<10*40+4+screen
   ldy #>10*40+4+screen
   jsr store_small

   ldx index
   lda p$lfo_val,x
   clc
   ldx #<40*2+screen+14
   ldy #>40*2+screen+14
   jsr store_small

   ldx index
   lda p$rup_val,x
   clc
   ldx #<40*3+screen+14
   ldy #>40*3+screen+14
   jsr store_small

   ldx index
   lda p$rdn_val,x
   clc
   ldx #<40*4+screen+14
   ldy #>40*4+screen+14
   jsr store_small

   ldx index
   lda p$max_val,x
   clc
   ldx #<40*5+screen+14
   ldy #>40*5+screen+14
   jsr store_small

   ldx #<p$cut_val
   ldy #>p$cut_val
   jsr find_nonzero
   clc
   ldx #<40*6+4+screen
   ldy #>40*6+4+screen
   jsr store_small

   ldx #<p$f_s_val
   ldy #>p$f_s_val
   jsr find_nonzero
   ldx #<40*8+4+screen
   ldy #>40*8+4+screen
   jsr single_sign

   ldx #<p$aut_val
   ldy #>p$aut_val
   jsr find_nonzero
   ldx #<40*7+4+screen
   ldy #>40*7+4+screen
   jsr single_sign

   lda #0
   sta xadd
   dec index
   bmi +
   jmp mg1

+  lda p$cur_rate
   sec
   sbc p$norm_rate
   sta d$cmd_value
   lda p$cur_rate+1
   sbc p$norm_rate+1
   sta d$cmd_value+1
   cmp #192
   bcc +
   jsr adjust_signed
   sec
+  php
   ldy #5
-  lsr d$cmd_value+1
   ror d$cmd_value
   dey
   bpl -
   plp
   ldx #<2*40+4+screen
   ldy #>2*40+4+screen
   jsr store_large

   jsr get_meas
   ldx #<2*40+25+screen
   ldy #>2*40+25+screen
   jmp store_large

;
;Find non-zero value based on INDEX and .X and .Y pointing to a 3-byte
;sequence.
;

find_nonzero = *

   stx ptr
   sty ptr+1
   ldx index
   bne +

   ldy #2
-  lda (ptr),y
   bne seq_found
   dey
   bpl -
   rts

+  ldy #3
-  lda (ptr),y
   bne seq_found
   iny
   cpy #6
   bcc -

seq_found = *

   rts

;
;Get number of current measure in current voice prepared for display.
;

get_meas = *

   ldx voice
   lda p$measure_l,x
   ldy p$measure_h,x
   bpl +
   lda #0
   tay
+  sta d$cmd_value
   sty d$cmd_value+1
   clc
   rts

;
;Retrieve voice positions from player module.
;

get_play_pos = *

   ldx #5
-  txa
   asl
   tay
   lda p$musicl,x
   sta voice_pos,y
   lda p$musich,x
   sta voice_pos+1,y
   dex
   bpl -
   rts

;
;Store voice positions for player module.
;

store_route = *

   ldx #5
-  txa
   asl
   tay
   lda voice_start,y
   sta p$musicl,x
   lda voice_start+1,y
   sta p$musich,x
   dex
   bpl -
   rts

;-- Tell MIDI interface we'll accept notes from it --

accept_midi = *

   lda interface_type
   beq am1
   bpl +
   lda #19
   sta $de08
   lda #145
   sta $de08
   lda #1
   sta midi_mode
   rts
+  lda #19
   sta $de00
   lda #145
   sta $de00
   lda #1
   sta midi_mode
am1 rts

;-- Tell MIDI interface we're refusing notes from it --

refuse_midi = *

   lda interface_type
   beq am1
   bpl +
   lda #19
   sta $de08
   lda #17
   sta $de08
   lda #0
   sta midi_mode
   rts
+  lda #19
   sta $de00
   lda #17
   sta $de00
   lda #0
   sta midi_mode
   rts

;-- Draw timing bar screen --

draw_bdisp = *

   lda #1
   sta vic+21
   jsr clear_top_cyan
   jsr print
   .byte col+1,xx+0,yy+2
   .asc "V1"
   .byte 13
   .asc "V2"
   .byte 13
   .asc "V3"
   .byte 13
   .asc "V4"
   .byte 13
   .asc "V5"
   .byte 13
   .asc "V6"
   .byte col+13,xx+0,yy+9
   .asc "VOC1"
   .byte xx+7
   .asc "VOC2"
   .byte xx+14
   .asc "VOC3"
   .byte xx+21
   .asc "VOC4"
   .byte xx+28
   .asc "VOC5"
   .byte xx+35
   .asc "VOC6"
   .byte col+3,13,tab,40,xx+0,eot

   jmp disp_aux

;-- Locations of start of each timing bar --

bar_loc_l  .byte <2*40+2+screen
           .byte <3*40+2+screen
           .byte <4*40+2+screen
           .byte <5*40+2+screen
           .byte <6*40+2+screen
           .byte <7*40+2+screen

bar_loc_h  .byte >2*40+2+screen
           .byte >3*40+2+screen
           .byte >4*40+2+screen
           .byte >5*40+2+screen
           .byte >6*40+2+screen
           .byte >7*40+2+screen

;-- Draw timing bars of appropriate length for each voice --

monitor_bars = *

    lda aux_mode
    beq mb0
    ldx #5
-   lda p$aux_val,x
    cmp bar_color,x
    bne +
    dex
    bpl -
    bmi mb0
+   jsr adjust_aux

mb0 ldx #5
mb1 lda bar_loc_l,x
    sta ptr
    lda bar_loc_h,x
    sta ptr+1
    ldy #0
    lda p$dur_count,x
    cmp #75
    php
    bcc +
    lda #74
+   lsr
    sta temp
    php
    lda #full_char
-   cpy temp
    bcs +
    sta (ptr),y
    iny
    bne -
+   plp
    bcc +
    lda #half_char
    sta (ptr),y
    iny
+   lda #32
-   cpy #37
    bcs +
    sta (ptr),y
    iny
    bne -
+   plp
    bcc +
    lda #"+"
+   sta (ptr),y
    dex
    bpl mb1

    lda pause_mode
    beq +

    jsr print
    .byte col+3,yy+10,xx+0,eot
    ldx #0
-   lda #tab
    jsr printchar
    lda tab_stops,x
    jsr printchar
    lda p$dur_count,x
    stx temp
    jsr printbyte
    ldx temp
    inx
    cpx #6
    bcc -
    jsr print
    .byte tab,40,eot
    rts

+   ldx #5
-   lda tab_stop_l,x
    sta ptr
    lda tab_stop_h,x
    sta ptr+1
    lda p$v_gate,x
    and #1
    beq +
    lda p$byte_1,x
    and #3
    bne sso
    lda p$byte_2,x
+   stx temp
    jsr quick_note_disp
    ldx temp
sso dex
    bpl -
    rts

;-- Display current note letter for each voice --

quick_note_disp = *

    ldy #0
    pha
    lsr
    lsr
    lsr
    and #7
    sta d$octave
    pla
    pha
    and #7
    sta d$note_letter
    pla
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    and #3
    beq +
    tax
    lda acc_table-1,x
    sta d$accidental
    bne ++
+   ldx d$note_letter
    lda double_acc_table-1,x
    sta d$accidental
+   ldx d$note_letter
    cpx #rest_note
    bne +
    lda #" "
    sta (ptr),y
    iny
    sta (ptr),y
    iny
    sta (ptr),y
    rts
+   lda letter_table-1,x
    sta (ptr),y
    iny
    lda d$accidental
    clc
    adc #acc_char
    sta (ptr),y
    iny
    lda d$octave
    eor #7
    ora #48
    sta (ptr),y
    rts

;-- Screen locations for note jiffy display --

tab_stop_l   .byte <screen+400+0,screen+400+7,screen+400+14
             .byte <screen+400+21,screen+400+28,screen+400+35

tab_stop_h   .byte >screen+400+0,screen+400+7,screen+400+14
             .byte >screen+400+21,screen+400+28,screen+400+35

;-- Tab stops for numeric jiffy display (pause mode). --

tab_stops    .byte 0,7,14,21,28,35

;-- If on play mode 3 (timing display), remove numeric stuff --
;
;remove_if_3 = *
;
;    lda play_screen
;    cmp #3
;    bne +
;
;    ldy #79
;    lda #32
;-   sta 9*40+screen,y
;    dey
;    bpl -
;
;+   rts

;-- Stop the clock for pause mode (saves its value) --

stop_clock = *

    ldy #3
-   lda 56328,y
    sta clock_save,y
    dey
    bpl -
    rts

;-- Recall value of clock prior to pause --

revive_clock = *

    ldy #3
-   lda clock_save,y
    sta 56328,y
    dey
    bpl -
    rts

;-- Make sure each voice position is within its allowable range --

check_ranges = *

    ldx #10
cr6 lda voice_pos+1,x
    cmp voice_start+1,x
    bne +
    lda voice_pos,x
    cmp voice_start,x
+   bcc cr7
    lda voice_pos+1,x
    cmp voice_end+1,x
    bne +
    lda voice_pos,x
    cmp voice_end,x
+   bcc cr8
    beq cr8
cr7 lda voice_start,x
    sta voice_pos,x
    lda voice_start+1,x
    sta voice_pos+1,x
cr8 dex
    dex
    bpl cr6
    rts

;-- Subroutine to update current AUX colors --
 
adjust_aux = *

    ldx #5
-   lda p$aux_val,x
    sta bar_color,x
    dex
    bpl -

;-- Subroutine to display current bar colors --

disp_aux = *

    ldx #5
-   lda bar_loc_l,x
    sta ptr
    lda bar_loc_h,x
    clc
    adc #col_factor
    sta ptr+1
    ldy #37
    lda bar_color,x
-   sta (ptr),y
    dey
    bpl -
    dex
    bpl --
    rts

;-- Initial bar colors --

orig_color    .byte 6,14,3,13,7,5
