all: dcl-c dcl generate

dcl-c: .build/dcl-c.o
	cc -g -o dcl-c .build/dcl-c.o

.build/dcl-c.o: c/dcl.c
	cc -Wall -g -c c/dcl.c -o .build/dcl-c.o

dcl: .build/dcl.o
	ld -o dcl .build/dcl.o

.build/dcl.o: asm/dcl.asm
	nasm -g -F dwarf -f elf64 -o .build/dcl.o asm/dcl.asm

generate: .build/generate.o
	cc -o generate .build/generate.o

.build/generate.o: c/generate.c
	cc -Wall -c c/generate.c -o .build/generate.o

clean:
	rm -f .build/*.o dcl dcl-c generate
