SYS_READ  equ 0
SYS_WRITE equ 1
SYS_EXIT  equ 60
STDIN     equ 0
STDOUT    equ 1
BUFSIZE   equ 4096
CHARNUM   equ 42
TABSIZE   equ CHARNUM*2

; TODO
; describe macros
; rewrite show
; describe process

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

; validates presence of 21 2-cycles for given permutation of length CHARNUM
; rsi - source dword array address
; does not modify arguments
; modifies value of rax, rcx, rdx
validate_cycles:
	xor eax, eax ; use eax as loop counter
validate_cycles_loop:

	mov ecx, [rsi + rax * 4] ; load src[counter]
	mov edx, [rsi + rcx * 4] ; load src[src[counter]]

	cmp eax, edx ; assert that src[src[counter]] == counter
	jne exit_failure
	cmp eax, ecx ; assert that src[counter] != counter
	je exit_failure

	inc eax
	cmp eax, CHARNUM
	jne validate_cycles_loop
	ret

; copy chunk of memory from source to destination address
; source and destination spaces can interlap
; rsi - source dword array address
; rdi - destination dword array address
; rdx - number of dwords to copy
; does not modify arguments
; modifies value of rax, rcx
dwordcpy:
	xor eax, eax ; use eax as loop counter
dwordcpy_loop:

	; copy single dword
	mov ecx, [rsi + rax * 4]
	mov [rdi + rax * 4], ecx

	inc eax
	cmp eax, edx
	jne dwordcpy_loop
	ret

; extend contents of dword array of size CHARNUM to size CHARNUM + rdx
; by prefix duplication
; rsi - source dword array address
; rdx - size extention
; does not modify arguments
; modifies value of rax, rcx, rdi
repeat_buf:
	lea rdi, [rsi + CHARNUM * 4]
	call dwordcpy
	ret

_start:
	; check argument count
	cmp qword [rsp], 5
	jne exit_failure

	; load and parse first argument (argv[1]) as rotor L
	mov rsi, [rsp + 8 * 2]
	mov rdi, L
	mov rdx, CHARNUM ; set expected length
	call parse_buf

	; load and parse second argument (argv[2]) as rotor R
	; previous parse_buf did not modify rdx, no need to mov again
	mov rsi, [rsp + 8 * 3]
	mov rdi, R
	call parse_buf

	; load and parse third argument (argv[3]) as rotor T
	; previous parse_buf did not modify rdx, no need to mov again
	mov rsi, [rsp + 8 * 4]
	mov rdi, T
	call parse_buf

	; load and parse fourth argument (argv[4]) as key (with a of length 2)
	mov rsi, [rsp + 8 * 5]
	mov rdi, key
	mov rdx, 2 ; set expected length
	call parse_buf

	; calculate inverse of rotor L and save it into Li
	mov rsi, L
	mov rdi, Li
	call inverse_buf

	; calculate inverse of rotor R and save it into Ri
	mov rsi, R
	mov rdi, Ri
	call inverse_buf

	; calculate inverse of rotor T and save it into Ti
	mov rsi, T
	mov rdi, Ti
	call inverse_buf
	; validate cycles of rotor T
	; inverse_buf did not modify rsi, so there is no need to do any mov
	call validate_cycles


	; extend buffers Li, R, T, Ti, in a way that buf[i] == buf[i + CHARNUM]
	mov rsi, Li
	mov rdx, CHARNUM
	call repeat_buf

	mov rsi, R
	; repeat_buf did not modify rdx, so there is no need to do any mov
	call repeat_buf

	mov rsi, T
	call repeat_buf

	mov rsi, Ti
	call repeat_buf

	; extend buffers Li, R, T, Ti, in a way that buf[i] == buf[i + CHARNUM]
	; and buf[i] == buf[i + 2 * CHARNUM]
	mov rsi, L
	mov rdx, CHARNUM * 2
	call repeat_buf

	mov rsi, Ri
	call repeat_buf

	; by extending rotor buffers in such way number of modulo operations
	; in later permutation processing can be reduced

	; load keys into persistent registers
	mov r14d, dword [key] ; l
	mov r15d, dword [key + 4] ; r

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
	; if status > 0, then rax contains info about count of read bytes

	; process rax bytes from buff
	mov rdi, rax
	call process

	; display rax bytes from buf
	mov rdi, rax
	mov rsi, buf
	call show

	jmp main_loop

; rdi - count
process:
	xor eax, eax
process_loop:
	movzx ecx, byte [buf + rax] ; get byte from buffer
	squeeze ecx

	incmod r14d, 1

	; if (r15d == 27 || r15d == 33 || r15d == 35) ebx := 1 else ebx := 0
	xor r10d, r10d
	cmp r14d, 27
	sete r10b

	xor r11d, r11d
	cmp r14b, 33
	sete r11b
	or r10d, r11d

	xor r11d, r11d
	cmp r14b, 35
	sete r11b
	or r10d, r11d

	incmod r15d, r10d

	add ecx, r14d
	mov ecx, [R + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r14d

	add ecx, r15d
	mov ecx, [L + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r15d

	mov ecx, [T + ecx * 4]

	add ecx, r15d
	mov ecx, [Li + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r15d

	add ecx, r14d
	mov ecx, [Ri + ecx * 4]
	add ecx, CHARNUM
	sub ecx, r14d
	fastmod ecx

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
	jl exit_failure

	sub rdi, rax
	add rsi, rax

	jmp show
show_end:
	ret

exit_success:
    mov eax, SYS_EXIT
    xor edi, edi
    syscall

exit_failure:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall
