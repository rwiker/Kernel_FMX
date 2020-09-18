#! /bin/sh

64tass --m65816 src/kernel.asm -D TARGET=2 --long-address --flat  --intel-hex -o kernel.hex --list kernel_hex.lst --labels=kernel_hex.lbl
