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

; Stereo Editor MIDI Player Program
; (February 9, 1990)
;
; This module can be loaded in place of the normal editor program (file "004").
; It supports unattended playback of a disk full of stereo or mono SIDs via a
; Passport or Sequential MIDI interface.

    .org $0400
    .obj "014"

;-- Old Kernal routine equates. --

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
reset_keys    = $e09c
change_keys   = $e09f

;-- Major storage areas --

dir_info   = $4000       ;Directory information
play_pos   = $5500
play_list  = $5501
logo_s     = $5600
logo_c     = $5700
cred_block = $5800       ;5 lines of credits, terminated by a zero, in ASCII
config     = $5a00       ;Configuration file ("007") data.
edit_key   = $5a00       ;Table of edit keys
var        = $5c00       ;Start of player module variables
player     = $6000       ;MIDI player module
start_heap = $7000       ;Start of music data
top_heap   = $cf00       ;Top of heap address for SID data.

;-- Zero-page start of storage equate --

zp = 2                   ;Start of zero page storage for this module

;-- Zero-page pointers --

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
last_status = zp+89      ;Last MIDI status byte (negative)
r0          = zp+90
r1          = zp+92
r3          = zp+94
r4          = zp+96
line        = zp+98
cline       = zp+100
aptr        = zp+102

;-- Global zero page locations (used by new Kernal, too). --

txtptr      = $e0        ;Points to start of a text item to be printed
start_m     = $e2        ;Start of block of memory to be moved
end_m       = $e4        ;End of block
dest_m      = $e6        ;Where to move that block

;-- Current note variables used by display routines. --

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
current_index    = var+236          ;Current index into sid list.
cont_mode        = var+237          ;0=can't continue, 1=continue list, 2=all
repeat_mode      = var+238          ;0=don't repeat play list, 1=DO repeat
repeat_flag      = var+239          ;1=repeat current song

;-- Temporary values --

table            = var+256          ;Temporary general-use table
line_construct   = var+256          ;One use of temporary table
staff_pos        = var+384          ;Sprite positions for notes on staff
selected         = var+512          ;1=file selected, 0=not selected

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
rvs_flag         = tv+11
color            = tv+12

;-- Miscellaneous constants --

screen           = $f400
s_base           = screen
c_base           = $d800
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

;-- Constants used by note display routines. --

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

;-- Constants for command indices. --

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

;-- Player interface equates --

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

p$midinote       = player+$ff0
interface_type   = player+$ff8
p$aux_val        = player+$ff9

;-- Key table interface equates --

ek0              = edit_key+6
ek_note          = ek0+3
ek_octave        = ek_note+8
ek_acc           = ek_octave+8
ek_dur           = ek_acc+9
ek1              = ek_dur+25
eke              = ek1+9
cc_key           = eke

;-- Configuration variables (part of "007" file). --

midi_channel     = config+98        ;6 MIDI channel defaults
midi_vel         = config+104       ;6 MIDI velocity defaults
midi_prg         = config+110       ;6 MIDI program defaults
midi_tps_sign    = config+116       ;6 MIDI TPS sign defaults
midi_tps         = config+122       ;6 MIDI TPS absolute value defaults

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
aux_mode         = cvar+12          ;1=use AUX colors, 0=don't

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

    lda 186
    sta pr_device
    lda #0
    sta 198
    sta num_files
    sta repeat_mode
    jsr clear_sel

    ldy #0
-   lda sprite_info,y
    sta $cf00,y
    iny
    bne -

    sei
    lda #0
    sta $01
    ldy #char_tab1-char_tab-1  ;Add special graphics to character set
-   lda char_tab,y
    sta 96*8+$d000,y
    dey
    bpl -

    lda #0
    sta r0
    sta r1
    lda #$d0
    sta r0+1
    lda #$d8
    sta r1+1
    ldx #8
    ldy #0
-   lda #$33
    sta 1
    lda (r0),y
    pha
    lda #0
    sta 1
    pla
    sta (r1),y
    iny
    bne -
    inc r0+1
    inc r1+1
    dex
    bne -

    lda #kernal_out
    sta $01
    cli

    jsr clear_all

    ldx #<inter
    ldy #>inter
    jsr setirq

;-- Draw and save the top logo --

    ldy #0
-   lda #96
    sta s_base,y
    lda #12
    sta c_base,y
    iny
    bne -

    jsr print
    .byte box,13,0,27,3,7,xx+14,yy+1,col+13,rvs
    .asc "Stereo Editor"
    .byte xx+14,yy+2,col+14
    .asc " MIDI Player "
    .byte rvsoff,xx+12,yy+4,tab,27,xx+12,yy+1,32,xx+12,yy+2,32,xx+12,yy+3,32
    .byte eot

    ldy #0
-   lda s_base,y
    sta logo_s,y
    lda c_base,y
    sta logo_c,y
    iny
    bne -

;-- Some test stuff. --

    lda #27
    sta 53265
    jsr fill
    jmp main_menu

;-- "Log in" a new SID disk. --

new_disk = *

    jsr save_screen
    jsr print
    .byte box,11,12,30,16,10
    .byte rvs,xx+10,yy+17,col+9,tab,30
    .byte xx+10,yy+16,32
    .byte xx+10,yy+15,32
    .byte xx+10,yy+14,32
    .byte xx+10,yy+13,32
    .byte rvsoff,col+1,xx+12,yy+13
    .asc "Insert a Disk that"
    .byte xx+12,yy+14
    .asc "Contains SID Files"
    .byte xx+12,yy+15
    .asc "and Press RETURN."
    .byte eot
    jsr abort_cont
    bcc +
    jsr recall_screen
    jmp select

+   jsr recall_screen
    jsr one_moment_please
    jsr read_dir
    jsr recall_screen
    lda num_files
    bne edit_play_list

    jsr alert
    jsr print
    .asc "There are no SID"
    .byte xx+11,yy+14
    .asc "Files on this Disk."
    .byte xx+11,yy+15
    .asc "Press RETURN."
    .byte eot
    jsr abort_cont
    jsr recall_screen
    jmp select

;-- Allow selection from files, if there are any in memory. --

edit_play_list = *

    lda num_files
    beq +
    jmp dir_select

+   jsr save_screen
    jsr no_sids_alert
    jsr abort_cont
    jsr recall_screen
    jmp select

;-- "No SIDs in Memory" alert box. --

no_sids_alert = *

    jsr alert
    jsr print
    .asc "There are Currently"
    .byte xx+11,yy+14
    .asc "no SIDs in Memory."
    .byte xx+11,yy+15
    .asc "Press RETURN."
    .byte eot
    rts

;-- Pause mode interrupt routine. --

qinter = *

    lda $dc0d

;-- Exit properly from an IRQ. --

exit_mirq = *

    pla
    pla
    pla
    sta $01
    pla
    tay
    pla
    tax
    pla
    rti

;-- Fill bottom screen area with the "+" pattern and place logo at top. --

fill = *

    ldy #0
-   lda #12
    sta c_base+256,y
    sta c_base+512,y
    sta c_base+768-24,y
    lda #96
    sta s_base+256,y
    sta s_base+512,y
    sta s_base+768-24,y
    lda logo_c,y
    sta c_base,y
    lda logo_s,y
    sta s_base,y
    iny
    bne -
    rts

;-- Character definition. --

char_tab       .byte $e7,$e7,$e7,$00,$00,$e7,$e7,$e7
               .byte $cc,$cc,$33,$33,$cc,$cc,$33,$33
               .byte $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
               .byte $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f
               .byte $03,$03,$03,$03,$03,$03,$03,$03
               .byte $e7,$e7,$e7,$e7,$e7,$e7,$e7,$e7
               .byte $e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0
char_tab1      = *

;-- Display the main menu. --

main_menu = *

    jsr clear_window

mm_return = *

    jsr print
    .byte def,32,4,8,128+4
    .asc "Main Menu"
    .byte eof,eot

    jsr menudef
    .byte 4,128+15,1
    .word 0,0,0,0
    .byte dispatch,5,10,30
    .word new_disk
    .asc "Read a New Disk"
    .byte dispatch,5,11,30
    .word edit_play_list
    .asc "Select/Unselect Files to Play"
    .byte dispatch,5,12,30
    .word play_selected
    .asc "Play Selected Files"
    .byte dispatch,5,13,30
    .word play_all_files
    .asc "Listen to All Files on Disk"
    .byte dispatch,5,14,30
    .word disk_directory
    .asc "Display Disk Directory"
    .byte dispatch,5,15,30
    .word send_command
    .asc "Issue Disk Commands"
    .byte dispatch,5,16,30
    .word continue_play
    .asc "Continue Playing Song List"
    .byte dispatch,5,17,30
    .word option_menu
    .asc "Options and General Settings"
    .byte dispatch,5,18,30
    .word midi_menu
    .asc "MIDI Default Menu"
    .byte dispatch,5,19,30
    .word clear_songs
    .asc "No Songs Selected"
    .byte eom
    jmp select

;-- Handle no function. --

no_function = *

    jmp select

;-- Return with carry set if member cancels, clear if RETURN is pressed. --

abort_cont = *

    jsr getin
    cmp #3
    beq +
    cmp #135
    beq +
    cmp #13
    bne abort_cont
    clc
+   rts

;-- Play selected files (if some are selected) --

play_selected = *

    lda play_pos
    beq +
    jmp play_sel

+   jsr save_screen
    jsr alert
    jsr print
    .asc "There are Currently"
    .byte xx+11,yy+14
    .asc "no SIDs on the Play"
    .byte xx+11,yy+15
    .asc "List. Press RETURN."
    .byte eot
    jsr abort_cont
    jsr recall_screen
    jmp select

;-- Prepare window for a 3-line alert message. --

alert = *

    jsr print
    .byte box,10,12,30,16,13
    .byte rvs,xx+9,yy+17,col+5,tab,30
    .byte xx+9,yy+16,32
    .byte xx+9,yy+15,32
    .byte xx+9,yy+14,32
    .byte xx+9,yy+13,32
    .byte rvsoff,xx+11,yy+13,col+1,eot
    rts

;-- MIDI menu --

midi_menu = *

    jsr save_screen
    jsr print
    .byte box,5,8,35,16,13
    .byte xx+4,yy+8,32
    .byte rvs,col+5,xx+4,yy+9,32
    .byte xx+4,yy+10,32
    .byte xx+4,yy+11,32
    .byte xx+4,yy+12,32
    .byte xx+4,yy+13,32
    .byte xx+4,yy+14,32
    .byte xx+4,yy+15,32
    .byte xx+4,yy+16,32
    .byte xx+4,yy+17,tab,35
    .byte rvsoff,col+12,xx+6,yy+9,rvs,tab,16
    .asc "CHAN  VEL  PRG  TPS"
    .byte col+15,rvsoff,yy+10,eot

    ldx #1
-   jsr print
    .byte xx+6
    .asc "Voice "
    .byte eot
    txa
    ora #48
    jsr printchar
    jsr print
    .asc " :"
    .byte 13,eot
    inx
    cpx #7
    bcc -

    jsr menudef
    .byte 5,15,1
    .word return_f7,0,0,0

    .byte numeric,17,10,2,1,16
    .word midi_channel
    .byte numeric,17,11,2,1,16
    .word midi_channel+1
    .byte numeric,17,12,2,1,16
    .word midi_channel+2
    .byte numeric,17,13,2,1,16
    .word midi_channel+3
    .byte numeric,17,14,2,1,16
    .word midi_channel+4
    .byte numeric,17,15,2,1,16
    .word midi_channel+5

    .byte numeric,22,10,3,1,127
    .word midi_vel
    .byte numeric,22,11,3,1,127
    .word midi_vel+1
    .byte numeric,22,12,3,1,127
    .word midi_vel+2
    .byte numeric,22,13,3,1,127
    .word midi_vel+3
    .byte numeric,22,14,3,1,127
    .word midi_vel+4
    .byte numeric,22,15,3,1,127
    .word midi_vel+5

    .byte numeric,27,10,3,0,127
    .word midi_prg
    .byte numeric,27,11,3,0,127
    .word midi_prg+1
    .byte numeric,27,12,3,0,127
    .word midi_prg+2
    .byte numeric,27,13,3,0,127
    .word midi_prg+3
    .byte numeric,27,14,3,0,127
    .word midi_prg+4
    .byte numeric,27,15,3,0,127
    .word midi_prg+5

    .byte string,32,10,1,2
    .word midi_tps_sign,plus_minus
    .byte string,32,11,1,2
    .word midi_tps_sign+1,plus_minus
    .byte string,32,12,1,2
    .word midi_tps_sign+2,plus_minus
    .byte string,32,13,1,2
    .word midi_tps_sign+3,plus_minus
    .byte string,32,14,1,2
    .word midi_tps_sign+4,plus_minus
    .byte string,32,15,1,2
    .word midi_tps_sign+5,plus_minus

    .byte numeric,33,10,2,0,24
    .word midi_tps
    .byte numeric,33,11,2,0,24
    .word midi_tps+1
    .byte numeric,33,12,2,0,24
    .word midi_tps+2
    .byte numeric,33,13,2,0,24
    .word midi_tps+3
    .byte numeric,33,14,2,0,24
    .word midi_tps+4
    .byte numeric,33,15,2,0,24
    .word midi_tps+5

    .byte eom

    jsr menuset
    jmp select_0

return_f7 = *

    jsr recall_screen
    jmp mm_return

;-- Plus/Minus text --

plus_minus = *

    .asc "+"
    .byte eot
    .asc "-"
    .byte eot

;-- Interrupt routine. --

inter = *

    inc $a2
    rts

;-- Print "One Moment Please" message. --

one_moment_please = *

    jsr print
    .byte box,10,13,31,15,3
    .byte rvs,xx+9,yy+16,col+6,tab,31,xx+9,yy+15,32,xx+9,yy+14,32
    .byte rvsoff,col+1,xx+11,yy+14
    .asc "One Moment Please..."
    .byte eot
    rts

;-- Load and play selected sids. --

play_sel = *

    lda #0
    sta current_index
    lda #1
    sta cont_mode

cont_sel = *

    jsr one_moment_please

sp1 ldy current_index
    cpy play_pos
    bcs +
    lda play_list,y
    tay
    jsr get_file_info
    jsr save_screen
    jsr load_mus
    jsr play_sid
    pha
    jsr recall_screen
    pla
    bne sp8
    inc current_index
    bne sp1
+   lda repeat_mode
    beq sp8
    lda #0
    sta current_index
    beq sp1
sp8 jmp main_menu

;-- Play all files on disk. --

play_all_files = *

    lda num_files
    bne +
    jsr save_screen
    jsr no_sids_alert
    jsr abort_cont
    jsr recall_screen
    jmp select

+   lda #0
    sta current_index
    lda #2
    sta cont_mode

cont_all = *

    jsr one_moment_please

sp2 ldy current_index
    cpy num_files
    bcs +
    jsr get_file_info
    jsr save_screen
    jsr load_mus
    jsr play_sid
    pha
    jsr recall_screen
    pla
    bne sp9
    inc current_index
    bne sp2
+   lda repeat_mode
    beq sp9
    lda #0
    sta current_index
    beq sp2
sp9 jmp main_menu

;-- Continue playing where we left off (if possible). --

continue_play = *

    lda num_files
    beq noc
    lda cont_mode
    bne cc2

noc jsr save_screen
    jsr alert
    jsr print
    .asc "You cannot continue"
    .byte xx+11,yy+14
    .asc "playing at this"
    .byte xx+11,yy+15
    .asc "time. Press RETURN."
    .byte eot
    jsr abort_cont
    jsr recall_screen
    jmp select

cc2 cmp #1                     ;Play selected mode
    bne cc3
    lda current_index
    cmp play_pos
    bcs noc
    jmp cont_sel

cc3 lda current_index          ;Play all mode
    cmp num_files
    bcs noc
    jmp cont_all

;-- Options menu. --

option_menu = *

    jsr save_screen
    jsr print
    .byte box,12,12,28,15,13
    .byte rvs,col+5,xx+11,yy+16,tab,28
    .byte xx+11,yy+13,32
    .byte xx+11,yy+14,32
    .byte xx+11,yy+15,32
    .byte rvsoff,col+1,xx+13,yy+13
    .asc "Repeat:"
    .byte xx+13,yy+14
    .asc "Drive:"
    .byte eot

    jsr menudef
    .byte 5,15,1
    .word return_f7,0,0,0
    .byte string,24,13,3,2
    .word repeat_mode,yes_no
    .byte numeric,24,14,2,8,11
    .word mus_device
    .byte eom
    jsr menuset
    jmp select_0

;-- Clear all selected songs. --

clear_songs = *

    jsr clear_sel
    jsr save_screen
    jsr alert
    jsr print
    .asc "The Play List has"
    .byte xx+11,yy+14
    .asc "been Cleared. Press"
    .byte xx+11,yy+15
    .asc "RETURN to Continue."
    .byte eot
    jsr abort_cont
    jsr recall_screen
    jmp select

;-- Yes/No strings. --

yes_no         .asc "No"
               .byte eot
               .asc "Yes"
               .byte eot

;-- Accept a disk command from user. --

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
-   dey
    bmi +
    cmp filename,y
    beq -
+   iny
    sty name_len
    rts

;-- Issue Disk Command option. --

send_command = *

    jsr save_screen
    jsr print
    .byte box,0,11,39,17,7,xx+2,yy+13,col+1
    .asc "Enter Disk Command:"
    .byte col+15,yy+15,xx+2,tab,39,xx+2,eot
    jsr get_diskcomm
    bne +
    jsr recall_screen
    jmp select

+   jsr recall_screen
    jsr one_moment_please
    jsr open_error_ch
    ldx #15
    jsr chkout
    ldy #0
-   cpy name_len
    bcs +
    lda filename,y
    jsr chrout
    iny
    bne -
+   jsr clrchn
    jsr read_error
    pha
    jsr close_all
    pla
    cmp #20
    bcs handle_disk_err
    jsr recall_screen
    jmp select

;-- Handle disk errors. --

handle_disk_err = *

    jsr clrchn
    jsr close_all
    ldx #$fa
    txs
    jsr alert
    jsr print
    .asc "A Disk Error has"
    .byte xx+11,yy+14
    .asc "Occurred. Press"
    .byte xx+11,yy+15
    .asc "RETURN to Continue."
    .byte eot
    jsr abort_cont
    jmp main_menu

;-- Read SID directory from disk. --

read_dir = *
 
   jsr clear_sel
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

dir_error jmp handle_disk_err

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
   jsr calc_empty
   jmp exl

+  jsr set_str_ext       ;If so, read from disk
   jsr open_read
   jsr chrin
   jsr chrin
   ldx #6
   jsr calc_all
   jsr close_all

exl lda str_flag
   bne +
   lda #120
   jsr delay
+  jsr clear_screen
   lda #$d4
   sta 53272
   rts

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
+  jmp handle_disk_err

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

+  jmp show_title

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

;-- Draw/Clear middle window and position cursor to home position in it. --

clear_window = *

    jsr print
    .byte box,3,7,36,21,11,xx+2,yy+22,tab,36
    .byte xx+2,yy+21,32
    .byte xx+2,yy+20,32
    .byte xx+2,yy+19,32
    .byte xx+2,yy+18,32
    .byte xx+2,yy+17,32
    .byte xx+2,yy+16,32
    .byte xx+2,yy+15,32
    .byte xx+2,yy+14,32
    .byte xx+2,yy+13,32
    .byte xx+2,yy+12,32
    .byte xx+2,yy+11,32
    .byte xx+2,yy+10,32
    .byte xx+2,yy+9,32
    .byte xx+2,yy+8,32
    .byte xx+4,yy+8,eot
    rts

;-- Clear any selected files. --

clear_sel = *

    ldy #0
    sty play_pos
    sty cont_mode
    tya
-   sta selected,y
    iny
    bne -
    rts

;-- Add a file to the play list (file index in .Y) --

add_play = *

    tya
    ldy play_pos
    sta play_list,y
    inc play_pos
    rts

;-- Remove a file from the play list (file index in .Y). --

del_play = *

    tya
    ldy #0
-   cpy play_pos
    bcs dp9
    cmp play_list,y
    beq dp1
    iny
    bne -

dp1 lda play_list+1,y
    sta play_list,y
    iny
    cpy play_pos
    bcc dp1
    dec play_pos

dp9 rts

;*****************************************************************************
;*                   High level use of disk access routines                  *
;*****************************************************************************

;-- Allow file selection from a scrolling menu of files. --

dir_select = *
 
   jsr clear_window
   jsr print
   .byte col+10,rvs
   .asc " Select Files to Play:"
   .byte tab,36,xx+4,yy+20
   .asc " RETURN to select, F5 to exit"
   .byte tab,36,rvsoff,eot

   jsr headerdef
   .byte 7,15,1
   .word dir_cancel,0,dir_other,dir_bound

   lda num_files
   cmp #11
   bcc +
   lda #11
+  sta menusize
   jsr sizedef
   lda #9
   sta topline

   ldy #10
-  lda #dispatch
   jsr s_itemtype
   lda #5
   jsr s_itemx
   tya
   clc
   adc topline
   jsr s_itemy
   lda #30
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

   lda #col+15
   jsr printchar
   lda #0
   sta index
   lda topfile
   sta botfile
df lda #xx+5
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
   .byte tab,21,eot
   ldy botfile
   lda selected,y
   beq +
   jsr print
   .asc "(Play)"
   .byte eot

+  jsr print
   .byte tab,32,eot
   ldy #0
-  lda name_len+13,y
   beq +
   lda msw_desig,y
   jsr printchar
+  iny
   cpy #3
   bcc -
   jsr print
   .byte tab,36,eot

   inc botfile
   inc index
   lda index
   cmp menusize
   bcc df
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
   lda selected,y
   eor #1
   sta selected,y
   jsr add_or_del
   jmp disp_files

add_or_del = *

   beq +
   jmp add_play
+  jmp del_play

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

   jmp main_menu

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

;-- Sprite definitions. --

sprite_info    .byte $e0,$00,$00,$e0,$00,$00,$e0,$00
               .byte $00,$e0,$00,$00,$e0,$00,$00,$e0
               .byte $00,$00,$e0,$00,$00,$e0,$00,$00
               .byte $fc,$00,$00,$fc,$00,$00,$fc,$00
               .byte $00,$fc,$00,$00,$fc,$00,$00,$fc
               .byte $00,$00,$fc,$00,$00,$fc,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$11

               .byte $fc,$00,$00,$fc,$00,$00,$fc,$00
               .byte $00,$fc,$00,$00,$fc,$00,$00,$fc
               .byte $00,$00,$fc,$00,$00,$fc,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$11

               .byte $60,$00,$00,$60,$00,$00,$60,$00
               .byte $00,$60,$00,$00,$60,$00,$00,$60
               .byte $00,$00,$60,$00,$00,$60,$00,$00
               .byte $fc,$00,$00,$fc,$00,$00,$fc,$00
               .byte $00,$fc,$00,$00,$fc,$00,$00,$fc
               .byte $00,$00,$fc,$00,$00,$fc,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$11

               .byte $7c,$00,$00,$7c,$00,$00,$7c,$00
               .byte $00,$7c,$00,$00,$7c,$00,$00,$7c
               .byte $00,$00,$7c,$00,$00,$7c,$00,$00
               .byte $fc,$00,$00,$fc,$00,$00,$fc,$00
               .byte $00,$fc,$00,$00,$fc,$00,$00,$fc
               .byte $00,$00,$fc,$00,$00,$fc,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$00
               .byte $00,$00,$00,$00,$00,$00,$00,$11

;-- Display disk directory --

disk_directory = *

    jsr clear_window

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
+   ldx #1
    jsr chkin
    jsr chrin  ;Skip load address
    jsr chrin
    jsr clrchn

qdl jsr clear_window
    jsr print
    .byte col+15,yy+8,eot
    lda #0
    sta topfile

qdl1 jsr print
    .byte rvsoff,xx+4,eot

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
-   jsr chrin
    cmp #34
    bne +
    sta botfile
+   cmp #0
    beq qdl2
    cmp #18
    bne +
    lda #rvs
+   cmp #146
    beq +
    sta line_construct,y
    iny
+   jmp -

qdl2 lda #32
-   dey
    bmi +
    cmp line_construct,y
    beq -
+   iny
    sty temp
    ldy #0
-   lda line_construct,y
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
    cmp #12
    bcc qdl1

qdl3 jsr clrchn
    jsr print
    .byte col+12,xx+4,yy+20,rvs
    .asc "Press RETURN to continue."
    .byte tab,36,rvsoff,eot
    jsr abort_cont
    bcs qdl9
    lda botfile
    beq qdl9
    jmp qdl

qdl9 jsr close_all
    jmp main_menu

;-- Directory filename. --

dirchar2       .asc "$"
dirchar3       = *

;-- Play current sid. --

play_sid = *

   lda #0
   sta repeat_flag

   ldy #5
-  lda orig_color,y
   sta bar_color,y
   sta p$aux_val,y
   dey
   bpl -

   jsr all_voices_on

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
   sta wds_flag

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

   jsr set_up_play_screen
   jsr init_play_spr

   jsr store_route
   lda expand_value
   sta p$expand
   lda #0
   sta p$route

   ldx #<midi_channel
   ldy #>midi_channel
   jsr init_play

   lda #%00111111
   sta p$status

   lda #0
   sta p$mode

   jsr show_wds
   jsr next_wds
   
   ldx #<pinter
   ldy #>pinter
   jsr setirq

play_loop = *

   jsr monitor_bars
   jsr update_time

   lda p$flag
   beq plb
   lda #0
   sta p$flag
   jsr show_wds
   jsr next_wds

plb lda #0                     ;Check keyboard matrix for activity
   sta $dc00
   lda $dc01
   eor #255
   bne pk_handle
   lda #0
   sta 197

plc lda p$status
   bne play_loop
   lda repeat_flag
   bne +
   jmp p_bypass
+  ldx #<inter
   ldy #>inter
   jsr setirq
   jsr drop_play
   jmp play_sid

;
;Handle player keypresses.
;

pk_handle = *

   jsr scnkey
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

play_key      .byte 32,136,135,"r",134
play_key1     = *

pk_vec        .word p_bypass-1,p_bypass-1,p_abort-1,set_repeat-1,p_pause-1

;-- Pause playing until a key is pressed. --

p_pause = *

    sei
-   inc $d020
    jsr scnkey
    jsr getin
    beq -
    lda #0
    sta $d020
    cli
    jmp play_loop

;-- Designate this song to repeat when it finishes. --

set_repeat = *

    lda #1
    sta repeat_flag
    jmp plc

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

p_bypass = *

   lda #0
   .byte $2c

p_abort = *

   lda #1

   pha
   lda #0
   sta $d015
   ldx #<inter
   ldy #>inter
   jsr setirq
   jsr drop_play
   cli
   lda #128
   sta 650
   pla
   rts

;
;Update elapsed play time at top of screen (unless in pause mode)
;

update_time = *

    lda pause_mode
    bne ut9
    lda 56331                  ;Necessary to latch clock
    lda 56330
    pha
    lsr
    lsr
    lsr
    lsr
    ora #48
    cmp #48
    bne +
    lda #32
+   sta screen+32+80
    pla
    and #15
    ora #48
    sta screen+33+80

    lda 56329
    pha
    lsr
    lsr
    lsr
    lsr
    ora #48
    sta screen+35+80
    pla
    and #15
    ora #48
    sta screen+36+80
    lda 56328                  ;Necessary to unlatch clock

ut9 rts

;
;Call play interrupt. Skip keyscan, etc.
;

pinter = *

   jsr play_inter
   jmp exit_mirq

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
   .byte xx+1,yy+20,col+14,eot
   jsr disp_line

   jsr print
   .byte xx+1,yy+21,col+6,eot
   jmp disp_line
per rts

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
   .byte tab,39,rvsoff,eot
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

;-- Set up the play screen! --

set_up_play_screen = *

    jsr fill
    jsr draw_piano
    jsr print
    .byte xx+1,yy+1,tab,9,xx+1,yy+2,tab,9,xx+1,yy+3,tab,9,xx+1,yy+4,tab,9
    .byte xx+31,yy+2,col+1
    .asc "   :   "
    .byte col+2,xx+0,yy+24,rvs,32
    .asc "Playing: "
    .byte eot
    jsr print_filename
    jsr print
    .byte tab,30,rvsoff,defr,10,30,24,128+2,eot
    jsr calc_songs_left
    jsr printbyte
    jsr print
    .asc " More "
    .byte eof,eot

    lda wds_flag
    beq +
    jsr print
    .byte box,0,19,39,22,10,eot

+   jsr disp_aux
    rts

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
-   lda p$v_gate,x
    and #1
    beq +
    lda p$byte_1,x
    and #3
    bne sso
    lda p$byte_2,x
+   stx temp
    jsr quick_note_disp
    ldx temp
sso jsr light_key
    dex
    bpl -
    rts

;-- Display current note letter for each voice --

quick_note_disp = *

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
    tay
    lda acc_table-1,y
    sta d$accidental
    bne ++
+   ldy d$note_letter
    lda double_acc-1,y
    sta d$accidental
+   ldy d$note_letter
    cpy #rest_note
    bne +
    lda #32
    sta s_base+42,x
    sta s_base+82,x
    sta s_base+122,x
    sta s_base+162,x
    rts

+   lda letter_table-1,y
    sta s_base+162,x
    lda d$accidental

    cmp #flat
    bne +
    lda #32
    sta s_base+42,x
    lda #98
    sta s_base+82,x
    sta s_base+122,x
    rts

+   cmp #natural
    bne +
    lda #98
    sta s_base+42,x
    sta s_base+82,x
    sta s_base+122,x
    rts

+   cmp #sharp
    bne +
    lda #98
    sta s_base+42,x
    sta s_base+82,x
    lda #32
    sta s_base+122,x
    rts

+   cmp #double_flat
    bne +
    lda #32
    sta s_base+42,x
    sta s_base+82,x
    lda #98
    sta s_base+122,x
    rts

+   lda #98
    sta s_base+42,x
    lda #32
    sta s_base+82,x
    sta s_base+122,x
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
-   lda bar_color,x
    sta $d027,x
    sta c_base+42,x
    sta c_base+82,x
    sta c_base+122,x
    lda #1
    sta c_base+162,x
    dex
    bpl -
    rts

;-- Initial bar colors --

orig_color    .byte 6,14,3,13,7,5

;-- Note letters. --

letter_table  .scr "CDEFGAB"

;-- Accidental tables. --

acc_table      .byte sharp,natural,flat
 
double_acc     .byte double_sharp,double_sharp,double_flat,double_sharp
               .byte double_sharp,double_flat,double_flat
 
;-- Draw the big piano display. --

draw_piano = *

    lda #<6*40+5+s_base
    sta r0
    sta r1
    lda #>6*40+5+s_base
    sta r0+1
    lda #>6*40+5+c_base
    sta r1+1

    ldx #11                    ;Draw main area
pd1 ldy #30
pd2 lda #11
    sta (r1),y
    lda #97
    sta (r0),y
    dey
    bpl pd2
    lda r0
    clc
    adc #40
    sta r0
    sta r1
    bcc +
    inc r0+1
    inc r1+1
+   dex
    bne pd1

    jsr print                  ;Draw piano shadow
    .byte xx+4,yy+7,32
    .byte xx+4,yy+8,32
    .byte xx+4,yy+9,32
    .byte xx+4,yy+10,32
    .byte xx+4,yy+11,32
    .byte xx+4,yy+12,32
    .byte xx+4,yy+13,32
    .byte xx+4,yy+14,32
    .byte xx+4,yy+15,32
    .byte xx+4,yy+16,32
    .byte xx+4,yy+17,tab,35,eot

    ldy #28                    ;Draw actual white piano keys
-   lda #1
    sta 7*40+6+c_base,y
    sta 8*40+6+c_base,y
    sta 9*40+6+c_base,y
    sta 10*40+6+c_base,y
    sta 12*40+6+c_base,y
    sta 13*40+6+c_base,y
    sta 14*40+6+c_base,y
    sta 15*40+6+c_base,y
    lda sequence_1,y
    sta 7*40+6+s_base,y
    sta 8*40+6+s_base,y
    sta 12*40+6+s_base,y
    sta 13*40+6+s_base,y
    lda sequence_2,y
    sta 9*40+6+s_base,y
    sta 10*40+6+s_base,y
    sta 14*40+6+s_base,y
    sta 15*40+6+s_base,y
    dey
    bpl -

    rts

;-- Piano tables. --

sequence_1     .byte 99,100,100,101,100,100,100,101
               .byte 100,100,101,100,100,100,101,100
               .byte 100,101,100,100,100,101,100,100
               .byte 101,100,100,100,102

sequence_2     .byte 99,101,101,101,101,101,101,101
               .byte 101,101,101,101,101,101,101,101
               .byte 101,101,101,101,101,101,101,101
               .byte 101,101,101,101,102

;-- Set up play screen piano sprites. --

init_play_spr = *

    lda #%00111111
    sta $d015                  ;Enable all 6 sprites
    sta $d017                  ;Expand vertically
    lda #0
    sta $d01b                  ;Sprite priority
    sta $d01c                  ;Multicolor
    sta $d01d                  ;Don't expand horizontally
    rts

;-- Tables --

sprite_x       .byte <77,80,85,88,93,101,104,109,112,117,120,125
               .byte <133,136,141,144,149,157,160,165,168,173,176,181
               .byte <189,192,197,200,205,213,216,221,224,229,232,237
               .byte <245,248,253,256,261,269,272,277,280,285,288,293

sprite_p       .byte 60,61,62,61,63,60,61,62,61,62,61,63
               .byte 60,61,62,61,63,60,61,62,61,62,61,63
               .byte 60,61,62,61,63,60,61,62,61,62,61,63
               .byte 60,61,62,61,63,60,61,62,61,62,61,63

or_table       .byte 1,2,4,8,16,32

and_table      .byte 254,253,251,247,239,223

;-- Light appropriate piano key for voice # in .X --

light_key = *

    ldy #146
    sty r1
    lda p$midinote,x
    beq zz
    sec
    sbc #12
    cmp #48
    bcc +
    ldy #106
    sty r1
    sbc #48
+   tay
    lda sprite_p,y
    sta s_base+1016,x
    lda sprite_x,y
    sta r0
    lda $d010
    cpy #39
    bcc +
    ora or_table,x
    bne ++
+   and and_table,x
+   sta $d010

    txa
    asl
    tay
    lda r0
    sta $d000,y
    lda r1
    sta $d001,y
    rts

zz  txa
    asl
    tay
    lda #0
    sta $d001,y
    rts

;-- Scan keyboard. --

scnkey = *

    lda #kernal_in
    sta 1
    jsr $ff9f
    lda #kernal_out
    sta 1
    rts

;-- Return songs left to play in .A. --

calc_songs_left = *

    lda cont_mode
    cmp #1
    bne +
    lda play_pos
    sec
    sbc current_index
    sbc #1
    rts
+   lda num_files
    sec
    sbc current_index
    sbc #1
    rts

;-- Draw SID title screen. --

show_title = *

    jsr clear_screen
    lda #$d6
    sta 53272

    ldy #0                     ;Fill whole screen with pattern
-   lda #12
    sta c_base,y
    sta c_base+256,y
    sta c_base+512,y
    sta c_base+768,y
    lda #219
    sta s_base,y
    sta s_base+256,y
    sta s_base+512,y
    sta s_base+768,y
    iny
    bne -

    lda #236                   ;Draw box corners
    sta 6*40+3+s_base
    sta 17*40+13+s_base
    lda #251
    sta 6*40+36+s_base
    sta 17*40+28+s_base
    lda #252
    sta 12*40+3+s_base
    sta 19*40+13+s_base
    lda #254
    sta 12*40+36+s_base
    sta 19*40+28+s_base

    lda #97                    ;Draw left and right sides of boxes
    sta 7*40+3+s_base
    sta 8*40+3+s_base
    sta 9*40+3+s_base
    sta 10*40+3+s_base
    sta 11*40+3+s_base
    sta 18*40+13+s_base
    lda #225
    sta 7*40+36+s_base
    sta 8*40+36+s_base
    sta 9*40+36+s_base
    sta 10*40+36+s_base
    sta 11*40+36+s_base
    sta 18*40+28+s_base

    lda #6                     ;Color box corners and sides of boxes
    sta 6*40+3+c_base
    sta 6*40+36+c_base
    sta 7*40+3+c_base
    sta 7*40+36+c_base
    sta 8*40+3+c_base
    sta 8*40+36+c_base
    sta 9*40+3+c_base
    sta 9*40+36+c_base
    sta 10*40+3+c_base
    sta 10*40+36+c_base
    sta 11*40+3+c_base
    sta 11*40+36+c_base
    sta 12*40+3+c_base
    sta 12*40+36+c_base
    lda #11
    sta 17*40+13+c_base
    sta 17*40+28+c_base
    sta 18*40+13+c_base
    sta 18*40+28+c_base
    sta 19*40+13+c_base
    sta 19*40+28+c_base

    ldy #31                    ;Draw middle stuff in top box
-   lda #226
    sta 6*40+4+s_base,y
    lda #98
    sta 12*40+4+s_base,y
    lda #6
    sta 6*40+4+c_base,y
    sta 12*40+4+c_base,y
    lda #32
    sta 7*40+4+s_base,y
    sta 8*40+4+s_base,y
    sta 9*40+4+s_base,y
    sta 10*40+4+s_base,y
    sta 11*40+4+s_base,y
    sta 13*40+2+s_base,y
    dey
    bpl -

    ldy #13                    ;Draw middle stuff in bottom box
-   lda #226
    sta 17*40+14+s_base,y
    lda #98
    sta 19*40+14+s_base,y
    lda #11
    sta 17*40+14+c_base,y
    sta 19*40+14+c_base,y
    lda now_loading,y
    sta 18*40+14+s_base,y
    lda #1
    sta 18*40+14+c_base,y
    lda #32
    sta 20*40+12+s_base,y
    dey
    bpl -

    lda #32                    ;Draw shadow sides
    sta 13*40+34+s_base
    sta 13*40+35+s_base
    sta 20*40+26+s_base
    sta 20*40+27+s_base
    sta 7*40+2+s_base
    sta 8*40+2+s_base
    sta 9*40+2+s_base
    sta 10*40+2+s_base
    sta 11*40+2+s_base
    sta 12*40+2+s_base
    sta 18*40+12+s_base
    sta 19*40+12+s_base

    jmp do_show

;-- "Now Loading..." text. --

now_loading    .scr "now loading..."

;-- Reset pointer to ASCII credit block. --

reset = *

   lda #<cred_block
   sta aptr
   lda #>cred_block
   sta aptr+1
   rts

;-- Get next byte from ASCII credit block. --

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

;-- Convert any ASCII code to its corresponding ROM code. Return with
;   carry set only if it's non-printable. --

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

;-- Table of screen color changing ASCII codes. --

color_table    .byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154
               .byte 155

;-- Convert ASCII credit block to screen codes. --

do_show = *

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

   rts

;-- Initialize pointers for conversion. --

init_for_convert = *

   jsr reset
   lda #<6*40+4+s_base
   sta line
   sta cline
   lda #>6*40+4+s_base
   sta line+1
   lda #>6*40+4+c_base
   sta cline+1
   rts

;-- Go to next line --

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

;-- Delay for number of jiffies in .A --

delay = *

    ldy #0
    sty $a2
-   cmp $a2
    bcs -
    rts
