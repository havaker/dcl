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
	ja exit_failure
%endmacro

%macro  unsqueeze 1
	add %1, 0x31
%endmacro

%macro  incmod 2
	add %1, %2
	fastmod %1
%endmacro

%macro fastmod 1
	cmp %1, CHARNUM
	jb %%end
	sub %1, CHARNUM
	%%end:
%endmacro

section .bss
buf: resb BUFSIZE
L:   resd TABSIZE + CHARNUM
R:   resd TABSIZE
T:   resd TABSIZE
Li:  resd TABSIZE
Ri:  resd TABSIZE + CHARNUM
Ti:  resd TABSIZE
key: resd 2


section .text

; parses given string as rotor data and saves it in dword array
; rsi - source string address
; rdi - destination dword array address
; rdx - expected string length
; does not modify arguments
; modifies value of rax, rcx
parse_buf:
	xor eax, eax ; use eax as loop counter
parse_buf_loop:
	cmp edx, eax ; end loop if esi >= eax
	jle parse_buf_end

	movzx ecx, byte [rsi + rax] ; copy byte from source string
	squeeze ecx ; verify and transform
	mov dword [rdi + rax * 4], ecx ; save it in destination string

	inc eax
	jmp parse_buf_loop
parse_buf_end:
	; check if source string is null-terminated
	cmp byte [rsi + rdx], 0
	jne exit_failure
	ret

; fills dword array of length CHARNUM with sepcified value
; rdi - destination dword array adress
; rdx - value
; does not modify arguments
; modifies value of rax
fill_buf:
	xor eax, eax ; use eax as loop counter
fill_buf_loop:
	mov [rdi + rax * 4], edx
	inc eax
	cmp eax, CHARNUM
	jne fill_buf_loop
	ret

; calculates inverse of given permutation of length CHARNUM
; rsi - source dword array address
; rdi - destination dword array adress
; does not modify arguments
; modifies value of rax, rcx, rdx
inverse_buf:
	; fill buffer with 0xff value
	mov edx, 0xff
	call fill_buf

	xor eax, eax ; use eax as loop counter
inverse_buf_loop:

	mov ecx, [rsi + rax * 4] ; ecx is currently processed value
	; if destination[ecx] != 0xff source must invalid, exit failure
	cmp dword [rdi + rcx * 4], 0xff
	jne exit_failure
	mov [rdi + rcx * 4], eax

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
	jne exit_failure
	cmp eax, ecx
	je exit_failure

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
	mov r8d, dword [key] ; l
	mov r9d, dword [key + 4] ; r
process_loop:

	movzx ecx, byte [buf + rax] ; get byte from buffer
	squeeze ecx

	incmod r8d, 1

	; if (r9d == 27 || r9d == 33 || r9d == 35) ebx := 1 else ebx := 0
	xor r10d, r10d
	cmp r8d, 27
	sete r10b

	xor r11d, r11d
	cmp r8b, 33
	sete r11b
	or r10d, r11d

	xor r11d, r11d
	cmp r8b, 35
	sete r11b
	or r10d, r11d

	incmod r9d, r10d

	add ecx, r8d
	mov ecx, [R + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r8d

	add ecx, r9d
	mov ecx, [L + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r9d

	mov ecx, [T + ecx * 4]

	add ecx, r9d
	mov ecx, [Li + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r9d

	add ecx, r8d
	mov ecx, [Ri + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r8d
	fastmod ecx

	unsqueeze ecx
	mov byte [buf + rax], cl

	inc eax
	cmp eax, edi
	jne process_loop

	mov dword [key], r8d; l
	mov dword [key + 4], r9d ; r

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
	jl exit_failure

	sub rdi, rax
	add rsi, rax

	jmp show
show_end:
	ret

_start:
	; check argument count
	cmp dword [rsp], 5
	jne exit_failure

	mov rsi, [rsp + 8 * 2] ; load argv[1] to rdi
	mov rdi, L
	mov rdx, 42
	call parse_buf

	mov rsi, [rsp + 8 * 3]
	mov rdi, R
	call parse_buf

	mov rsi, [rsp + 8 * 4]
	mov rdi, T
	call parse_buf

	mov rsi, [rsp + 8 * 5]
	mov rdi, key
	mov rdx, 2
	call parse_buf

	mov rsi, L
	mov rdi, Li
	call inverse_buf

	mov rsi, R
	mov rdi, Ri
	call inverse_buf

	mov rsi, T
	mov rdi, Ti
	call inverse_buf
	call validate_cycles

	mov rdi, L
	call repeat_buf
	mov rdi, L + CHARNUM * 4
	call repeat_buf
	mov rdi, Li
	call repeat_buf
	mov rdi, R
	call repeat_buf
	mov rdi, Ri
	call repeat_buf
	mov rdi, Ri + CHARNUM * 4
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
	je exit_success ; if status == 0 exit normally
	jl exit_failure ; if status < 0, then exit with non zero code

	mov rdi, rax ; ustaw argument funkcji process
	call process
	mov rdi, rax ; ustaw argument funkcji show
	mov rsi, buf ; ustaw argument funkcji show
	call show

	jmp main_loop

exit_success:
    mov eax, SYS_EXIT
    xor edi, edi
    syscall

exit_failure:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall
