;
;Edit key table
;

   .org $0000
   .obj "007"

;

edit_key                 .byte 29,157,19,147,134,138
ek0                      .byte 17,145," "
ek_note                  .byte "r","c","d","e","f","g","a","b"
ek_octave                .byte "0","1","2","3","4","5","6","7"
ek_acc                   .byte $dd,"-","\","+",$db
                         .byte "/",13,20,148
ek_dur                   .byte "A","u","w","h","q","8","s","t","9","v"
                         .byte "T",".",">"
                         .byte 136,135,133,"p","S","K",137
                         .byte "P","i","m","j","k"

                         .byte "/","@",";",":",148,20," ",136,140
                         .byte 17,17+128,29,29+128
ek1 = *

* = 98

midi_channel             .byte 1,2,3,4,5,6
midi_vel                 .byte 64,64,64,64,64,64
midi_prg                 .byte 0,0,0,0,0,0
midi_tps_sign            .byte 0,0,0,0,0,0
midi_tps                 .byte 0,0,0,0,0,0

bong_mode                .byte 1
acc_mode                 .byte 1
update_mode              .byte 1
pitch_mode               .byte 1
insert_mode              .byte 0
tie_mode                 .byte 0
j$speed                  .byte 6
mus_device               .byte 8
expand_value             .byte 1
word_mode                .byte 1
cmd_update               .byte 1
midi_entry               .byte 0
aux_mode                 .byte 1

* = $00a0

num_menu                 .byte 6
menu_file                .byte 12,5,8,9,15,16,0,0
menu_name                .asc "SID Archive Maker$"
                         .asc "Key Customizer$"
                         .asc "Title Block Edit$"
                         .asc "Words File Editor$"
                         .asc "MIDI Studio$"
                         .asc "Chord Buster$"
                         .byte 0
