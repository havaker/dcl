all: dcl-c dcl

dcl-c: .build/dcl-c.o
	cc -o dcl-c .build/dcl-c.o

.build/dcl-c.o: c/dcl.c
	cc -Wall -c c/dcl.c -o .build/dcl-c.o

dcl: .build/dcl.o
	ld -o dcl .build/dcl.o

.build/dcl.o: asm/dcl.asm
	nasm -g -F dwarf -f elf64 -o .build/dcl.o asm/dcl.asm

clean:
	rm -f .build/dcl-c.o .build/dcl.o dcl dcl-c
