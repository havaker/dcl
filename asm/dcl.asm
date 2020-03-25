SYS_READ  equ 0
SYS_WRITE equ 1
SYS_EXIT  equ 60
STDIN     equ 0
STDOUT    equ 1
BUFSIZE   equ 4096

global _start

%macro  squeeze 1
	sub %1, 0x31
	cmp %1, 0x29
	ja abort
%endmacro

%macro  unsqueeze 1
	add %1, 0x31
%endmacro

; przerobic na bufory
section .bss
buf: resb BUFSIZE
L: resq 42
R: resq 42
T: resq 42
key: resb 2

section .data
Li: times 42 db 0xff
Ri: times 42 db 0xff
Ti: times 42 db 0xff

section .text

; rdi - adres src
; rsi - spodziewana długość bufora bez znaku \0
; rdx - adres dst
; nie modyfikuje argumentów
squeeze_buf:
	xor eax, eax ; użyj eax jako licznika pętli
squeeze_buf_loop:
	cmp esi, eax ; jeśli esi >= eax to skończ pętlę
	jle squeeze_buf_end

	movzx ecx, byte [rdi + rax]
	squeeze ecx
	mov byte [rdx + rax], cl

	inc eax
	jmp squeeze_buf_loop
squeeze_buf_end:
	cmp byte [rdi + rsi], 0
	jne abort
	ret


; rdi - adres src
; rsi - adres dst
; nie modyfikuje argumentów
inverse_buf:
	xor eax, eax
inverse_buf_loop:

	movzx ecx, byte [rdi + rax]
	cmp byte [rsi + rcx], 0xff
	jne abort
	mov byte [rsi + rcx], al

	inc eax
	cmp eax, 42
	jne inverse_buf_loop
	ret

; rdi - adres src
; nie modyfikuje argumentów
validate_cycles:
	xor eax, eax
validate_cycles_loop:

	movzx ecx, byte [rdi + rax]
	movzx edx, byte [rdi + rcx]

	cmp eax, edx
	jne abort
	cmp eax, ecx
	je abort

	inc eax
	cmp eax, 42
	jne validate_cycles_loop
	ret

; rdi - count
process:
	xor eax, eax
process_loop:

	movzx ecx, byte [buf + rax] ; get byte from buffer
	squeeze ecx

	unsqueeze ecx
	mov byte [buf + rax], cl

	inc eax
	cmp eax, edi
	jne process_loop
	ret

; rdi - count
; rsi - buffer
show:
	test rdi, rdi
	je show_end

	mov rdx, rdi ; set count parameter

	push rdi
	push rsi

	mov eax, SYS_WRITE
	mov edi, STDOUT
	syscall

	pop rsi
	pop rdi

	cmp rax, 0
	jl abort

	sub rdi, rax
	add rsi, rax

	jmp show
show_end:
	ret

_start:
	; check argument count
	cmp dword [rsp], 5
	jne abort

	lea rbp, [rsp + 8 * 2] ; address of argv[1]

	mov rdi, [rbp] ; load argv[1] to rdi
	mov rsi, 42
	mov rdx, L
	call squeeze_buf

	add rbp, 8
	mov rdi, [rbp]
	mov rdx, R
	call squeeze_buf

	add rbp, 8
	mov rdi, [rbp]
	mov rdx, T
	call squeeze_buf

	add rbp, 8
	mov rdi, [rbp]
	mov rsi, 2
	mov rdx, key
	call squeeze_buf

	; load l r
;	mov al, [rdi]
;	mov cl, [rdi + 1]
;	mov [l], al
;	mov [r], cl

	mov rdi, L
	mov rsi, Li
	call inverse_buf

	mov rdi, R
	mov rsi, Ri
	call inverse_buf

	mov rdi, T
	mov rsi, Ti
	call inverse_buf
	call validate_cycles

main_loop:
	; read string from stdin to buf
	mov eax, SYS_READ
	mov edi, STDIN
	mov rsi, buf
	mov rdx, BUFSIZE
	syscall

	; check rax for return status
	cmp rax, 0
	je exit ; if status == 0 exit normally
	jl abort ; if status < 0, then abort

	mov rdi, rax ; ustaw argument funkcji process
	call process
	mov rdi, rax ; ustaw argument funkcji show
	mov rsi, buf ; ustaw argument funkcji show
	call show

	jmp main_loop

exit:
    mov eax, SYS_EXIT
    xor edi, edi
    syscall

abort:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall
