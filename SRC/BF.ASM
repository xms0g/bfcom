.model tiny
.data
BUFFER_SIZE equ 10000
TAPE_SIZE   equ 30000

filename db 13 dup(?)
buffer   db BUFFER_SIZE dup(?)
tape     db TAPE_SIZE dup(?)
msg_open_fail db 'Open failed$'
msg_read_fail db 'Read failed$'

.code
org 100h         

extrn _interpret:near

start:
    lea di, tape
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
    jc open_fail
    ; Save returned file handle in BX    
    mov bx, ax                  
    
    ; Read up to XXX bytes from file into buffer
    mov ah, 3Fh
    mov cx, BUFFER_SIZE - 1
    lea dx, buffer
    int 21h
    jc read_fail
    ; AX = number of bytes actually read
    mov si, ax
    ; Null-terminate buffer at end of data read               
    mov byte ptr buffer[si], 0  
    
    push ds
    push offset tape
    push offset buffer
    call _interpret
    pop ax
    pop ax
    pop ds
    jmp close_file
open_fail:
    ; handle open error
    mov dx, offset msg_open_fail
    call print
    jmp done
read_fail:
    ; handle read error
    mov dx, offset msg_read_fail
    call print
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

end start
