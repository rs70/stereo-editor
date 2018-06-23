# stereo-editor
Stereo Editor: A vintage C-64 SID editor

This is the original source code for the C-64 application "Stereo Editor 1.0" (circa 1989),
converted from PETSCII to normal ASCII and lightly edited so that it can be cross-assembled
by modern hardware.

Building
--------

The code was originally edited on a Commodore 128 and built using Chris Miller's
Buddy Assembler. I've written a compatible, portable cross assembler that the included
Makefile uses to build the application on Linux or the Mac (maybe even Windows). You can
find that assembler [here](https://github.com/ras88/as64).

The Makefile can also optionally create a .d64 disk image with all files needed to
run the application on an emulator. This requires the `c1541` command line tool that
is included with the VICE emulator distribution.

Run `make` to build all changed modules. Output will appear in the `obj` subdirectory.

`make package` uses `c1541` to generate `stereo-editor.d64`, also in the `obj`
subdirectory.

`make clean` simply clears the `obj` directory in case you want to do a fresh build
from scratch.

Running
-------

`load "stereo editor",8,1` will load and run Stereo Editor using a fast loader. If the
fast loader proves incompatible with whatever drive or virtual drive you're using,
try `load "slow editor",8,1`.

`load "midi player",8,1` runs a (possibly unreleased?) application that plays selected
SIDs in sequence through a Sequential or Passport MIDI interface. `slow player` is the
non-fastload boot program for that application.

Overview of Source Files
------------------------

`boot.asm` is a short program that does nothing but load the bootstrapper/kernal module.

`kernal.asm` (object file 001) is responsible for loading the rest of the system and
also includes a 4K screen I/O and fast DOS kernal that it copies to $e000.

`charset.asm` (object file 002) and `sprites.asm` (object file 003) are the bitmapped
assets used by the editor.

`editor.asm` (object file 004) contains the bulk of the code.

`archive-builder.asm` (object file 012) is loaded on demand to build MSW, SAL, etc.
bundles.

`words-editor.asm` (object file 009) is loaded on demand to edit .wds files.

`credit-block-editor.asm` (object file 008) is loaded on demand to edit the SID's
credits.

`key-customizer.asm` (object file 005) is loaded on demand to modify command key
shortcuts.

`midi-player.asm` (object file 014) is the alternate MIDI player application discussed
 above.

`settings.asm` (object file 007) contains the initial values for application settings

Memory Map
----------

    0000-00ff:        Zero page storage
    0100-01ff:        CPU stack
    0200-03ff:        System storage, IRQ handler, thunks for required kernal ROM APIs
    0400-57ff:        Main editor application (src/editor.asm)
    5800-59ff:        Credit block for the SID being edited
    5a00-5bff:        Settings (persisted to file "007")
    5c00-5fff:        General editor module data storage
    6000-6fff:        SID or MIDI player code (from file "006" or "013")
    7000-bfff:        Music data heap: 3-6 voices plus optional lyrics (up to 20K)
    c000-cfff:        Transient application code (words editor, key customizer, archiver, etc.)
    d000-d7ff:        Character set (src/charset.asm) or I/O registers (bank switched)
    d800-d9ff:        Sprites (src/sprites.asm) or VIC color SRAM (bank switched)
    da00-dfff:        Cut and paste buffer or VIC color SRAM plus I/O registers (bank switched)
    e000-efff:        Custom kernal (src/kernal.asm)
    f000-f3ff:        Kernal general storage (menu management, fast load buffers, etc.)
    f400-f7ff:        VIC screen memory
    f800-fbff:        Saved screen area
    fc00-ffff:        Saved color area
