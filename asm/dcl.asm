global _start

; TODO
; dont do inverse of T?

SYS_READ   equ 0
SYS_WRITE  equ 1
SYS_EXIT   equ 60
STDIN      equ 0
STDOUT     equ 1
BUFSIZE    equ 1024 * 64
CHARNUM    equ 42
SQUEEZED_L equ 'L'-'1'
SQUEEZED_R equ 'R'-'1'
SQUEEZED_T equ 'T'-'1'

; name of register in which address of io buffer is stored
%define BUFADDR r12

; checks if char is in range ['1'; 'Z'] and subtracts '1'
; argument is modified to be in range [0; CHARNUM)
%macro  squeeze 1
    sub %1, '1'
    cmp %1, CHARNUM
    jae exit_failure
%endmacro

; expects argument to be in range [0; CHARNUM)
; modifies it to be in range ['1'; 'Z']
%macro  unsqueeze 1
    add %1, '1'
%endmacro

; adds two values modulo CHARNUM
; stores result in first argument
; sum of arguments should be less than 2 * CHARNUM
%macro  addmod 2
    add %1, %2
    fastmod %1
%endmacro

; computes argument % CHARNUM
; stores result in argument
; argument should be less than 2 * CHARNUM
%macro fastmod 1
    lea r13d, [%1 - CHARNUM]
    cmp %1, CHARNUM
    cmovae %1, r13d
%endmacro

section .bss
; arrays holding informations about rotors
L:   resd 3*CHARNUM
R:   resd 2*CHARNUM
T:   resd 2*CHARNUM
Li:  resd 2*CHARNUM
Ri:  resd 3*CHARNUM

; array holding info about key
key: resd 2

section .text

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

    ; calculate inverse of rotor T to validate using Ri helper buffer
    ;mov rsi, T
    ;mov rdi, Ri
    ;call inverse_buf

    ; calculate inverse of rotor R and save it into Ri
    mov rsi, R
    mov rdi, Ri
    call inverse_buf

    ; validate cycles of rotor T
    mov rsi, T
    call validate_cycles

    ; extend buffers Li, R, T, Ti using repeat_buf, in a way
    ; that buf[i] == buf[i + CHARNUM], i ∈  [0, CHARNUM)
    mov rsi, Li
    mov rdx, CHARNUM
    call repeat_buf
    mov rsi, R ; previous repeat_buf did not modify rdx
    call repeat_buf
    mov rsi, T ; previous repeat_buf did not modify rdx
    call repeat_buf

    ; extend buffers Li, R, T, Ti using repeat_buf, in a way
    ; that buf[i] == buf[i + CHARNUM] and buf[i] == buf[i + 2 * CHARNUM]
    mov rsi, L
    mov rdx, CHARNUM * 2
    call repeat_buf
    mov rsi, Ri ; previous repeat_buf did not modify rdx
    call repeat_buf

    ; by extending rotor buffers in such way number of modulo operations
    ; in later permutation processing can be reduced

    ; load key into persistent registers
    mov r14d, dword [key] ; l
    mov r15d, dword [key + 4] ; r

    ; reserve space for io buffer
    sub rsp, BUFSIZE
    mov BUFADDR, rsp

main_loop:
    ; read string from stdin to buf
    mov eax, SYS_READ
    mov edi, STDIN
    mov rsi, BUFADDR
    mov rdx, BUFSIZE
    syscall

    ; check rax for return status
    cmp rax, 0
    je exit_success ; if status == 0 exit normally
    jl exit_failure ; if status < 0, then exit with non zero code
    ; if status > 0, then rax contains info about count of read bytes

    ; process rax bytes from buff
    mov rdx, rax
    call process

    ; display rax bytes from buf
    ; no need to fill rax, as process does not modify arguments
    mov rsi, BUFADDR
    call show

    jmp main_loop

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
    mov dword [rdi + rax * 4], ecx ; save it in destination array

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
    ; fill destination buffer with 0xff value
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

; extend contents of dword array of size CHARNUM to size CHARNUM + rdx
; by prefix duplication
; rsi - source dword array address
; rdx - size extention
; does not modify arguments
; modifies value of rax, rcx, rdi
repeat_buf:
    lea rdi, [rsi + CHARNUM * 4]
    xor eax, eax ; use eax as loop counter
repeat_buf_loop:

    ; copy single dword
    mov ecx, [rsi + rax * 4]
    mov [rdi + rax * 4], ecx

    inc eax
    cmp eax, edx
    jne repeat_buf_loop
    ret

; encrypt string in buffer
; rdx - string length
; expects to have
;   L, Li, T, R, Ri initialized
;   key in registers r14d, r15d
;   buffer address in BUFADDR
; does not modify argument
; modifies value of rax, rcx, r14, r15, r10, r11
process:
    xor eax, eax
process_loop:
    ; get character from string
    movzx ecx, byte [BUFADDR + rax]
    ; change rage of ecx to [0; CHARNUM)
    squeeze ecx

    ; update r from key
    addmod r15d, 1

    xor r10d, r10d
    ; set r10d to 1 if unsqueezed value of r equals to one of 'L', 'R', 'T'
    cmp r15d, SQUEEZED_L
    sete r10b
    xor r11d, r11d
    cmp r15d, SQUEEZED_R
    sete r11b
    or r10d, r11d
    xor r11d, r11d
    cmp r15b, SQUEEZED_T
    sete r11b
    or r10d, r11d

    ; update l from key using value of r10d (which can be 0 or 1)
    addmod r14d, r10d

    ; key (r14d, r15d) is now updated
    ; starting to encrypt byte loaded to ecx

    add ecx, r15d ; shift by r
    ; ecx ∈  [0, CHARNUM * 2), modulo not needed (length of R is CHARNUM*2)
    mov ecx, [R + ecx * 4] ; permutate using rotor R
    add ecx, CHARNUM ; add to prevent going below 0
    sub ecx, r15d ; negative shift by r

    add ecx, r14d ; shift by l
    ; ecx ∈  [0, CHARNUM * 3), modulo not needed (length of L is CHARNUM*3)
    mov ecx, [L + ecx * 4] ; permutate using rotor L
    add ecx, CHARNUM
    sub ecx, r14d ; negative shift by l

    ; ecx ∈  [0, CHARNUM * 2), modulo not needed (length of T is CHARNUM*2)
    mov ecx, [T + ecx * 4] ; permutate using rotor T

    add ecx, r14d ; shift by l
    ; ecx ∈  [0, CHARNUM * 2), modulo not needed (length of Li is CHARNUM*2)
    mov ecx, [Li + ecx * 4] ; inverse permutate using rotor L
    add ecx, CHARNUM
    sub ecx, r14d ; negative shift by l

    add ecx, r15d ; shift by r
    ; ecx ∈  [0, CHARNUM * 3), modulo not needed (length of Ri is CHARNUM*3)
    mov ecx, [Ri + ecx * 4] ; inverse permutate using rotor R
    add ecx, CHARNUM
    sub ecx, r15d ; negative shift by r

    ; finished encryting byte loaded to ecs

    ; ecx ∈  [0, CHARNUM * 2)
    fastmod ecx ; reducing to [0, CHARNUM)
    unsqueeze ecx ; transforminig into letters

    mov byte [BUFADDR + rax], cl ; saving encrypted byte into buffer

    ; looping
    inc eax
    cmp eax, edx
    jne process_loop
    ret

; writes string of given size to stdout
; rsi - source string
; rdx - byte count
; does syscall
; modifies arguments
show:
    test rdx, rdx
    je show_end

    ; save rdx, rsi
    push rdx
    push rsi

    ; make write syscall
    ; rdx already filled with count
    ; rsi already filled with buffer address
    mov eax, SYS_WRITE
    mov edi, STDOUT
    syscall

    ; load rdx, rsi
    pop rsi
    pop rdx

    ; exit failure if syscall returned error
    cmp rax, 0
    jl exit_failure

    sub rdx, rax ; decrease count
    add rsi, rax ; move string ptr

    jmp show ; loop
show_end:
    ret

; exit with 0 return code
exit_success:
    mov eax, SYS_EXIT
    xor edi, edi
    syscall

; exit with non-zero return code
exit_failure:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall
