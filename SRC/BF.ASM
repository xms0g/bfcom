.model tiny
.data
BUFFER_SIZE equ 10000
TAPE_SIZE   equ 30000
.code
org 100h         

start:
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
CPY_LOOP:
    ; Load byte from DS:SI into AL and increment SI
    lodsb
    ; Check for carriage return (end of command line)                      
    cmp al, 0Dh
    ; If CR, end copying                 
    je CPY_DONE                
    cmp al, ' '   
    ; Skip spaces, load next char              
    je CPY_LOOP
    ; Store AL into ES:DI and increment DI                 
    stosb                      
    loop CPY_LOOP
CPY_DONE:
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
    jc OPEN_FAIL
    ; Save returned file handle in BX    
    mov bx, ax                  
    
    ; Read up to XXX bytes from file into buffer
    mov ah, 3Fh
    mov cx, BUFFER_SIZE - 1
    mov dx, offset buffer
    int 21h
    jc READ_FAIL
    ; AX = number of bytes actually read
    mov si, ax
    ; Null-terminate buffer at end of data read               
    mov byte ptr buffer[si], 0
    jmp START_INTR
OPEN_FAIL:
    ; handle open error
    mov dx, offset msg_open_fail
    call print
    jmp done
READ_FAIL:
    ; handle read error
    mov dx, offset msg_read_fail
    call print
    jmp done
START_INTR:   
    push ds
    push si
    push di
    push bp
    mov bp, sp
    sub sp, 2

    mov si, offset buffer
    mov di, offset tape
    jmp	CHECK_CHAR
MAIN_LOOP:
    ; jump = 0
    mov	word ptr [bp-2], 0
    mov	al, byte ptr [si]
    cbw	
	cmp	ax, '>'
    je MOVE_R
    cmp ax, '<'
    je MOVE_L
    cmp ax, '+'
    je INC_CURR
    cmp ax, '-'
    je DEC_CURR
    cmp ax, '.'
    je PRINT_CURR
    cmp ax, ','
    je WRITE_CURR
    cmp ax, '['
    je LOOP_START
    cmp ax, ']'
    je LOOP_END
    jmp CHECK_JUMP
MOVE_R:
    inc	di
	jmp	CHECK_JUMP
MOVE_L:
    dec di
    jmp	CHECK_JUMP
INC_CURR:
    inc	byte ptr [di]
	jmp	CHECK_JUMP
DEC_CURR:
    dec	byte ptr [di]
	jmp	CHECK_JUMP
PRINT_CURR:
    mov	dl, byte ptr [di]
    mov	ah, 2
    int 21h
    jmp	CHECK_JUMP
WRITE_CURR:
    mov	ah, 1
    int 21h
    mov	byte ptr [di], al
    jmp	CHECK_JUMP
LOOP_START:
    mov	al, byte ptr [di]
	mov	ah, 0
	or ax, ax
	jne	CHECK_JUMP
    mov	cx, 1
	jmp	WHILE1_CHECK
WHILE1_START:
    cmp	byte ptr [si], '['
	jne	ELSE1
	inc	cx
	jmp	WHILE1_CHECK
ELSE1:
    cmp	byte ptr [si], ']'
	jne	WHILE1_CHECK
	dec	cx
WHILE1_CHECK:
    or cx, cx
	jle	JUMP_1
	inc	si
	mov	bx, si
	cmp	byte ptr [bx], 0
	jne	WHILE1_START
LOOP_END:
    cmp	byte ptr [di], 0
    je CHECK_JUMP
    mov	bx, 1
	jmp	WHILE2_CHECK
WHILE2_START:
    cmp	byte ptr [si], ']'
	jne	ELSE2
	inc	bx
	jmp	WHILE2_CHECK
ELSE2:
    cmp	byte ptr [si], '['
	jne	WHILE2_CHECK	
	dec	bx
WHILE2_CHECK:
    or	bx, bx
	jle	JUMP_1
	dec	si
	cmp	si, offset buffer
	jae	WHILE2_START
JUMP_1:
    mov	word ptr [bp-2], 1
    jmp CHECK_JUMP
CHECK_JUMP:
    cmp	word ptr [bp-2], 0
	jne	CHECK_CHAR	
	inc	si
CHECK_CHAR:
    cmp	byte ptr [si], 0
	je FINAL
	jmp	MAIN_LOOP
FINAL:
    mov sp, bp
    pop bp
    pop di
    pop si
    pop ds
    jmp close_file

close_file:
    mov ah, 3Eh
    int 21h
done: 
    mov ax, 4c00h
    int 21h

print:
    mov ah, 09h
    int 21h
    ret
  
filename db 13 dup(?)
buffer   equ (offset filename + 13)
tape     equ (buffer + BUFFER_SIZE)

msg_open_fail db 'Open failed$'
msg_read_fail db 'Read failed$'
end start
