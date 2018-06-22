all: obj/001 obj/002 obj/003 obj/004 obj/005 obj/006 obj/007 obj/008 obj/009 obj/010 obj/011 obj/012 obj/013 obj/014 \
	obj/stereo-editor obj/slow-editor obj/midi-player obj/slow-player

clean:
	rm obj/*

package:
	c1541 -format "stereo editor,1" d64 obj/stereo-editor.d64 \
		-write obj/stereo-editor "stereo editor" \
		-write obj/slow-editor "slow editor" \
		-write obj/midi-player "midi player" \
		-write obj/slow-player "slow player" \
		-write obj/001 \
		-write obj/002 \
		-write obj/003 \
		-write obj/004 \
		-write obj/005 \
		-write obj/006 \
		-write obj/007 \
		-write obj/008 \
		-write obj/009 \
		-write obj/010 \
		-write obj/011 \
		-write obj/012 \
		-write obj/013 \
		-write obj/014 \
		-write orig/001 001.orig

obj/001: src/kernal.asm
	as64 -O obj src/kernal.asm

obj/002: src/charset.asm
	as64 -O obj src/charset.asm

obj/003: src/sprites.asm
	as64 -O obj src/sprites.asm

obj/004: src/editor.asm
	as64 -O obj src/editor.asm

obj/005: src/key-customizer.asm
	as64 -O obj src/key-customizer.asm

obj/006: third-party/sidplayer
	cp third-party/sidplayer obj/006

obj/007: src/settings.asm
	as64 -O obj src/settings.asm

obj/008: src/credit-block-editor.asm
	as64 -O obj src/credit-block-editor.asm

obj/009: src/words-editor.asm
	as64 -O obj src/words-editor.asm

obj/010: assets/reg
	cp assets/reg obj/010

obj/011: src/registration.asm
	as64 -O obj src/registration.asm

obj/012: src/archive-builder.asm
	as64 -O obj src/archive-builder.asm

obj/013: third-party/sidplayer-midi
	cp third-party/sidplayer-midi obj/013

obj/014: src/midi-player.asm
	as64 -O obj src/midi-player.asm

obj/stereo-editor: src/boot.asm
	as64 -O obj -o stereo-editor src/boot.asm

obj/slow-editor: src/boot.asm
	as64 -DSLOW -O obj -o slow-editor src/boot.asm

obj/midi-player: src/boot.asm
	as64 -DPLAYER -O obj -o midi-player src/boot.asm

obj/slow-player: src/boot.asm
	as64 -DSLOW -DPLAYER -O obj -o slow-player src/boot.asm
