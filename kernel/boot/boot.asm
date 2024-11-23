; GluOS x86 bootloader
;   
; @file boot.asm
;   
; @author Jacob Smith

; TODO: Produce an error when kernel loader is not found

[BITS 16]
[ORG 0x7C00]

; Disable interrupts
cli

; Canonicalize code segment
jmp entry
    
; Entry point
entry:

    ; ax = 0
    xor ax, ax

    ; ds, es, fs, gs, ss = 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Enable interrupts
    sti
    
    ; Initialize the 8 bytes of memory after the bootloader to zero
    ; NOTE: These are used later
    mov si, index_node_block
    mov cx, 8
    rep stosb

    ; Set the stack pointer
    mov sp, 0x9C00

    ; Compute if there are an even or odd number of nodes
    mov al, byte [node_quantity]
    and al, 1

    ; NOTE: See commentary under .flip_flop label
    jnz .flip_flop

    .done:

    ; Find kernel loader
    call stage_2_load

    ; Execute kernel loader
    jmp 0x0:0x1000

    .flip_flop:

        ; COMMENTARY: A glufs image has one node foreach file in the image.
        ;             This means that there may be an even or odd number of 
        ;             nodes on the image. The index block is aligned to the
        ;             end of the disk. Therefore, it is ambiguous if an even
        ;             node starts at 0x1000 or 0x1100. To compute this, the 
        ;             bootloader tests the parity of the node quantity. If 
        ;             the parity is odd, the offset for even and odd labels 
        ;             inverted

        ; Store the odd offset
        mov cx, 0x1100

        ; Store the even offset
        mov dx, 0x1000

        ; Overwrite the even offset with the odd offset
        mov bx, even_block
        mov word [bx], cx

        ; Overwrite the odd offset with the even offset
        mov bx, odd_block
        mov word [bx], dx
        
        ; Continue
        jmp .done

stage_2_load:

    ; Load the node
    mov si, index_node_block

    ; Read the sector
    call node_load

    ; Search
    .lp:

        ; Point to the name of the file
        add si, 8

        ; Preserve si
        push si
        
        ; Print the name of the file ...
        call print
        
        ; ... and a newline
        call new_line

        ; Restore si
        pop si
       
        ; Check for the right file
        mov di, file_path
        mov cx, word [file_path_len]
        call strcmp

        ; Found the file
        jz .found

        ; CF = 1 == B > A == right
        jc  .right

        ; CF = 0 == B < A == right
        jnc .left
        
        .done:

        ; Load the node
        call node_load

        ; Align to 256 bytes
        and si, 0xff00

        ; Continue
        jmp .lp

    .left:

        ; Align to 256 bytes 
        and si, 0xff00

        ; Align to left pointer
        add si, 240

        ; Continue
        jmp .done

    .right:

        ; Align to 256 bytes
        and si, 0xff00

        ; Align to right pointer
        add si, 248
        
        ; Continue
        jmp .done

    .found:
        ; COMMENTARY: Offsets in glufs are byte-aligned, however the BIOS
        ;             reads 512-byte sectors. Thus, the bootloader must 
        ;             convert the byte offset to a sector offset. To compute
        ;             the correct offset, the bootloader divides the byte 
        ;             offset by 512. This is the same as a right shift by 9. 
        ;             
        ;             A right shift by 9 effectively discards the 9 least 
        ;             significant digits. Instead of performing 9 right shift
        ;             operations on a 64-bit number, the bootloader copies the 
        ;             most significant 7 bytes. This is the same as a right 
        ;             shift by 8. A concomitant right shift by 1 bit yields
        ;             the correct sector offset.

        ; Preserve si
        push si
        
        ; Print the name of the file
        mov si, success_msg
        call print

        ; Restore si
        pop si

        ; Clear the first byte of the file path
        xor al, al
        mov byte [si], al

        ; si points to disk offset
        mov cx, 7
        sub si, cx

        ; di points to dap sector offset
        mov di, sector
        
        ; Preserve
        push di

        ; Copy the 7 most significant bytes from the node offset to the dap
        rep stosb

        ; Restore
        pop di
        
        ; One more right shift
        call rsh_64_bit_number

        ; Read 56 sectors
        ; NOTE: This is arbitrary, but I think it's safe to assume that 
        ;       the kernel loader will never exceed 28 KB

        ; Read the sector
        call sector_read
        
        ; Done
        ret

; IN: si = node number
; OUT: si = pointer to node in memory
node_load:
    
    ; Compute if the node is even or odd
    mov al, byte [si]
    and al, 1
    
    ; Node is odd
    jnz .odd_node
    
    ; Node is even. Use the even block offset
    mov ax, word [even_block]

    .done:
    
    ; Preserve offset for return
    push ax
    
    ; Compute a sector offset from a node number
    mov di, si
    call rsh_64_bit_number

    ; Add the node number to the starting index sector
    mov bx, index_block
    mov di, sector
    call add_64_bit_number
    
    ; Read the sector
    call sector_read

    ; Restore offset
    pop si

    ; Done
    ret
        
    .err_no_root:

        ; Print an error message
        mov si, no_root_error_msg
        call print

        ; Hang
        cli
        hlt
    
    .odd_node:
        
        ; Node is odd. Use odd block offset
        mov ax, word [odd_block]

        ; Continue
        jmp .done

; IN: bx = pointer to lhs
;     si = pointer to rhs
;     di = pointer to result
add_64_bit_number:

    ; Add bits 0-15
    mov ax, [si + 0]
    adc ax, [bx + 0]
    mov word [di + 0], ax

    ; Add bits 16-31
    mov ax, [si + 2]
    adc ax, [bx + 2]
    mov word [di + 2], ax

    ; Add bits 32-47
    mov ax, [si + 4]
    adc ax, [bx + 4]
    mov word [di + 4], ax

    ; Add bits 48-63
    mov ax, [si + 6]
    add ax, [bx + 6]
    mov word [di + 6], ax

    ; Done
    ret

; IN: si = pointer to source
;     di = pointer to result
rsh_64_bit_number:

    ; Clear the carry flag for the first rcr
    clc

    ; Right shift bits 48-63
    mov ax, [si + 6]
    sar ax, 1
    mov word [di + 6], ax

    ; Right shift bits 32-47
    mov ax, [si + 4]
    rcr ax, 1
    mov word [di + 4], ax

    ; Right shift bits 16-31
    mov ax, [si + 2]
    rcr ax, 1
    mov word [di + 2], ax
 
    ; Right shift bits 0-15
    mov ax, [si + 0]
    rcr ax, 1
    mov word [di + 0], ax

    ; Done
    ret

; Read a sector using the bootloader's DAP
sector_read:

    ; Clear the carry flag
    clc

    ; Extended disk read
    mov ah, 0x42
    mov dl, 0x80
    mov si, dap
    int 0x13

    ; Error
    jb .err

    ; Done
    ret

    .err:
            
        ; Print an error message
        mov si, disk_read_error_msg
        call print

        ; Disable interrupts
        cli

        ; Hang
        hlt

; String compare
; IN:  si = pointer to A
;      di = pointer to B
; OUT: ZF = 0 if A == B 
;      CF = 1 if B > A else 0
strcmp:

    ; Preserve
    push si
    push di

    .lp:

        ; Load A
        mov al, byte [si]

        ; Load B
        mov bl, byte [di]

        ; B - A
        cmp al, bl

        ; Strings are not equal
        jnz .exit

        ; Next character
        inc si
        inc di

        ; Increment
        dec cx
        
        ; Done?
        jcxz .exit

        ; Continue
        jmp .lp

    .exit:

        ; Restore
        pop di
        pop si

        ; Done
        ret

; Print a null terminated string
; IN: si = pointer to string
print:

    ; bx = 0
    xor bx, bx

    .lp: 

        ; Load next byte of string
        lodsb

        ; Continuation condition
        or al, al
        jz .exit

        ; TTY print
        mov ah, 0x0E
        int 0x10      

        ; Continue
        jmp .lp

    .exit:

        ; Done
        ret

; Print a new line
new_line:
    
    ; Preserve
    push bx
    push ax

    ; TTY print
    mov ah, 0x0E

    ; Line feed
    mov al, 0x0A
    int 0x10

    ; Carriage return
    mov al, 0x0D
    int 0x10

    ; Restore
    pop ax
    pop bx

    ; Done
    ret

; Data 
success_msg:              db "File found!", 0x0A, 0x0D, 0x00
disk_read_error_msg:      db "Disk read error!", 0x0A, 0x0D, 0x00
file_not_found_error_msg: db "File not found!", 0x0A, 0x0D, 0x00
no_root_error_msg:        db "Root node not found!", 0x0A, 0x0D, 0x00
file_path:                db "/boot/kernel_loader", 0x00
file_path_len:            dw $ - file_path
even_block: dw 0x1000
odd_block: dw 0x1100

; Metadata
%include "index_metadata.inc"

; Disk Address Packet
times 478-($-$$) db 0
dap:
    db 0x10
    db 0x00
sector_quantity:
        dw 0x0001
    dd 0x00001000
    sector: 
        dq 0xFFFFFFFFFFFFFFFF

; Index metadata
; NOTE: The values at these labels are set at build time. 
times 494-($-$$) db 0
node_quantity: dq 0
node_size: dq 0

; Padding
times 510-($-$$) db 0

; Boot sig
db 0x55
db 0xAA
index_node_block: