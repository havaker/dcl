SYS_READ  equ 0
SYS_WRITE equ 1
SYS_EXIT  equ 60
STDIN     equ 0
STDOUT    equ 1
BUFSIZE   equ 4096
CHARNUM   equ 42
TABSIZE   equ CHARNUM*2

global _start

%macro  squeeze 1
	sub %1, 0x31
	cmp %1, 0x29
	ja abort
%endmacro

%macro  unsqueeze 1
	add %1, 0x31
%endmacro

;%macro  Q 1 2
;	add %2, %1
;	cmp %2, 42
;	jb %%end
;	sub %2, 42
;%%end:
;%endmacro

section .bss
buf: resb BUFSIZE
L:   resd TABSIZE
R:   resd TABSIZE
T:   resd TABSIZE
key: resd 2

section .data
Li: times TABSIZE dd 0xff
Ri: times TABSIZE dd 0xff
Ti: times TABSIZE dd 0xff

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
	mov dword [rdx + rax * 4], ecx

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

	mov ecx, [rdi + rax * 4]
	cmp dword [rsi + rcx * 4], 0xff
	jne abort
	mov [rsi + rcx * 4], eax

	inc eax
	cmp eax, CHARNUM
	jne inverse_buf_loop
	ret

; rdi - adres src
; nie modyfikuje argumentów
validate_cycles:
	xor eax, eax
validate_cycles_loop:

	mov ecx, [rdi + rax * 4]
	mov edx, [rdi + rcx * 4]

	cmp eax, edx
	jne abort
	cmp eax, ecx
	je abort

	inc eax
	cmp eax, CHARNUM
	jne validate_cycles_loop
	ret

; rdi - adres src
repeat_buf:
	xor eax, eax
repeat_buf_loop:

	mov ecx, [rdi + rax * 4]
	mov [rdi + rax * 4 + CHARNUM*4], ecx

	inc eax
	cmp eax, CHARNUM
	jne repeat_buf_loop
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

	mov rdi, L
	call repeat_buf
	mov rdi, Li
	call repeat_buf
	mov rdi, R
	call repeat_buf
	mov rdi, Ri
	call repeat_buf
	mov rdi, T
	call repeat_buf
	mov rdi, Ti
	call repeat_buf

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
