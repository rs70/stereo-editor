# stereo-editor
Stereo Editor: A vintage C-64 SID editor

This is the original source code for the C-64 application Stereo Editor (circa 1989),
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
