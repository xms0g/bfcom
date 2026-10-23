.model tiny
.data
BUFFER_SIZE equ 10000
TAPE_SIZE   equ 30000
.code
org 100h         

start:
    push bp
    mov bp, sp
    sub sp, 4

    mov di, offset tape
    xor al, al
    mov cx, TAPE_SIZE
    rep stosb
    ; Get the command line from the PSP
    ; SI = offset 0x80 in PSP = length of command line tail
    ; CL = number of characters in command line tail
    ; SI = offset 0x81 in PSP = start of command line tail string
    mov si, 80h                
    mov cl, [si]                
    mov si, 81h                 
    xor ch, ch
    lea di, filename 
cpy_loop:
    ; Load byte from DS:SI into AL and increment SI
    lodsb
    ; Check for carriage return (end of command line)                      
    cmp al, 0Dh
    ; If CR, end copying                 
    je cpy_done                
    cmp al, ' '   
    ; Skip spaces, load next char              
    je cpy_loop
    ; Store AL into ES:DI and increment DI                 
    stosb                      
    loop cpy_loop
cpy_done:
    ; Null-terminate the filename string
    xor al, al                  
    stosb 
    ; Open the file specified by filename (read-only)
    mov ah, 3Dh
    ; Read-only mode (0)
    xor al, al
    ; DS:DX points to filename                  
    lea dx, filename            
    int 21h
    jc fail
    ; Save returned file handle in [bp-4]    
    mov word ptr [bp-4], ax
    ; Read up to XXX bytes from file into buffer
    mov bx, ax 
    mov ah, 3Fh
    mov cx, BUFFER_SIZE - 1
    mov dx, offset buffer
    int 21h
    jc fail
    ; AX = number of bytes actually read
    mov si, ax
    ; Null-terminate buffer at end of data read               
    mov byte ptr buffer[si], 0
    jmp start_intr
fail:
    jmp close_file
start_intr:   
    push ds
    push si
    push di
    
    mov si, offset buffer
    mov di, offset tape
    jmp	check_char
main_loop:
    ; jump = 0
    mov	word ptr [bp-2], 0
    mov	al, byte ptr [si]
    cbw	
	cmp	ax, '>'
    je move_r
    cmp ax, '<'
    je move_l
    cmp ax, '+'
    je inc_curr
    cmp ax, '-'
    je dec_curr
    cmp ax, '.'
    je print_curr
    cmp ax, ','
    je write_curr
    cmp ax, '['
    je loop_start
    cmp ax, ']'
    je loop_end
    jmp check_jump
move_r:
    inc	di
	jmp	check_jump
move_l:
    dec di
    jmp	check_jump
inc_curr:
    inc	byte ptr [di]
	jmp	check_jump
dec_curr:
    dec	byte ptr [di]
	jmp	check_jump
print_curr:
    mov	dl, byte ptr [di]
    mov	ah, 2
    int 21h
    jmp	check_jump
write_curr:
    mov	ah, 1
    int 21h
    mov	byte ptr [di], al
    jmp	check_jump
loop_start:
    mov	al, byte ptr [di]
	mov	ah, 0
	or ax, ax
	jne	check_jump
    mov	cx, 1
	jmp	while1_check
while1_start:
    cmp	byte ptr [si], '['
	jne	else1
	inc	cx
	jmp	while1_check
else1:
    cmp	byte ptr [si], ']'
	jne	while1_check
	dec	cx
while1_check:
    or cx, cx
	jle	set_jump_1
	inc	si
	mov	bx, si
	cmp	byte ptr [bx], 0
	jne	while1_start
loop_end:
    cmp	byte ptr [di], 0
    je check_jump
    mov	bx, 1
	jmp	while2_check
while2_start:
    cmp	byte ptr [si], ']'
	jne	else2
	inc	bx
	jmp	while2_check
else2:
    cmp	byte ptr [si], '['
	jne	while2_check	
	dec	bx
while2_check:
    or	bx, bx
	jle	set_jump_1
	dec	si
	cmp	si, offset buffer
	jae	while2_start
set_jump_1:
    mov	word ptr [bp-2], 1
    jmp check_jump
check_jump:
    cmp	word ptr [bp-2], 0
	jne	check_char	
	inc	si
check_char:
    cmp	byte ptr [si], 0
	je close_file
	jmp	main_loop
close_file:
    ; close file
    mov bx, word ptr [bp-4]
    mov ah, 3Eh
    int 21h
done:
    pop di
    pop si
    pop ds
    mov sp, bp
    pop bp
    mov ax, 4c00h
    int 21h
  
filename db 13 dup(?)
buffer   equ (offset filename + 13)
tape     equ (buffer + BUFFER_SIZE)
end start
