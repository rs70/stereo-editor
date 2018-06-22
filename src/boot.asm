; Stereo Editor Loader
; By Robert A. Stoerrle
;
; Loads the bootstrap/kernal module ("001"), passing
; parameters that control which application is ultimately
; loaded, as well as whether the fast loader is used.
;
; The load address of this program is carefully chosen so that
; BASIC's IMAIN vector is overwritten. Instead of displaying
; the "READY" prompt after loading, the vector redirects to
; this start of this program.
;
; I could not locate the original source code for this module,
; so I recreated it from a disassembly (6/21/2018).

    .org $02a7

;-- Kernal equates --
;
FA          = $ba                       ; Current device number
SETMSG      = $ff90
SETLFS      = $ffba
SETNAM      = $ffbd
LOAD        = $ffd5

;-- BASIC equates --
;
IERROR      = $0300
IMAIN       = $0302
ERROR       = $e38b

;-- The bootstrap/kernal module's jump table --
;
BOOT        = $8000
FAST_EDIT   = BOOT                      ; Fast load the editor
SLOW_EDIT   = BOOT+3                    ; Slow load the editor
FAST_PLAY   = BOOT+6                    ; Fast load the MIDI player
SLOW_PLAY   = BOOT+9                    ; Slow load the MIDI player

;-- Entry point --
;
start = *

    lda #11                             ; Initialize the screen
    sta $d011

    lda #0                              ; Turn off all Kernal messages
    jsr SETMSG

    lda #1
    ldx FA                              ; Load from the same drive
    ldy #0
    jsr SETLFS

    lda #end_filename - filename
    ldx #<filename
    ldy #>filename
    jsr SETNAM

    lda #0
    ldx #<BOOT
    ldy #>BOOT
    jsr LOAD

; Choose a final destination based on the existence of symbols
; SLOW and PLAYER (defaulting to fast loading the editor if neither
; symbol is defined).
;
.ifdef SLOW
.ifdef PLAYER
    jmp SLOW_PLAY
.else
    jmp SLOW_EDIT
.ife
.else
.ifdef PLAYER
    jmp FAST_PLAY
.else
    jmp FAST_EDIT
.ife
.ife

filename = *
    .asc "001"
end_filename = *

* = IERROR

    .word ERROR                         ; IERROR vector (unchanged)
    .word start                         ; IMAIN vector (redirected)
