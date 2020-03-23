SYS_WRITE equ 1
SYS_EXIT equ 60
STDOUT equ 1

global _start

section .rodata
hello:
    db 'hello world', `\n`

section .text

_start:
    mov eax, SYS_WRITE
    mov edi, STDOUT
    mov rsi, hello
    mov edx, 13
    syscall

    ; exit
    mov eax, SYS_EXIT
    xor edi, edi
    syscall
