SYS_EXIT equ 60

global _start

%macro  squeeze 1
	sub %1, 0x31
	cmp %1, 0x29
	ja abort
%endmacro

%macro  unsqueeze 1
	add %1, 0x31
%endmacro

section .bss
L: resq 1
R: resq 1
T: resq 1
l: resb 1
r: resb 1

section .data
Li: times 42 db 0xff
Ri: times 42 db 0xff
Ti: times 42 db 0xff

section .text

; rdi - adres bufora
; rsi - spodziewana długość bufora bez znaku \0
; nie modyfikuje argumentów
squeeze_buf:
	xor eax, eax ; użyj eax jako licznika pętli
squeeze_buf_loop:
	cmp esi, eax ; jeśli esi >= eax to skończ pętlę
	jle squeeze_buf_end
	squeeze byte [rdi + rax]
	inc eax
	jmp squeeze_buf_loop
squeeze_buf_end:
	test byte [rdi + rsi], 0
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


_start:
	; check argument count
	cmp dword [rsp], 5
	jne abort

	lea rbp, [rsp + 8 * 2] ; adres argv[1]

	mov rdi, [rbp]
	mov [L], rdi
	mov rsi, 42
	call squeeze_buf

	add rbp, 8
	mov rdi, [rbp]
	mov [R], rdi
	call squeeze_buf

	add rbp, 8
	mov rdi, [rbp]
	mov [T], rdi
	call squeeze_buf

	add rbp, 8
	mov rdi, [rbp]
	mov rsi, 2
	call squeeze_buf

	; load l r
	mov al, [rdi]
	mov cl, [rdi + 1]
	mov [l], al
	mov [r], cl

	mov rdi, [L]
	mov rsi, Li
	call inverse_buf

	mov rdi, [R]
	mov rsi, Ri
	call inverse_buf

	mov rdi, [T]
	mov rsi, Ti
	call inverse_buf

	jmp exit

exit:
    mov eax, SYS_EXIT
    xor edi, edi
    syscall

abort:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall
