; GluOS x86 kernel loader
;   
; @file kernel_loader.asm
;   
; @author Jacob Smith

[BITS 16]
[ORG 0x1000]

; Entry point
entry:
    
    ; Disable interrupts
    cli
    
    ; ax = 0=
    xor ax, ax

    ; ds = es = fs = gs = ss = 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set the stack pointer
    mov sp, 0x9C00

    ; Enable interrupts
    sti

    ; Gather memory information
    call memory_info_get

    mov ax, 0x4f02
    mov bx, 011Bh
    int 0x10

    mov ax, 0x4f01
    mov cx, 011Bh
    mov di, 0x2000
    int 0x10

    ; Set up protected mode
    jmp protected_mode_set

protected_mode_set:

    ; Enable A20 line
    call a20_line_set

    ; Disable interrupts
    cli

    ; Load the Global Descriptor Table
    call global_descriptor_table_load

    ; Switch to protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp 0x08:prot_md

a20_line_set:

    ; Enable the A20 line
    mov ah, 0x24
    mov al, 0x01
    int 0x15

    ; Done
    ret

global_descriptor_table_load:

    ; Load the global descriptor table
    lgdt [gdtinfo]

    ; Done
    ret

; Query system address map
memory_info_get:

    ; Query low memory
    ;call low_memory_info_get

    ; Query high memory
    ;mov di, address_range_descriptors
    ;call high_memory_info_get
    ret

; di = pointer to memory for address range descriptors
high_memory_info_get:

    ; bx = 0
    xor bx, bx

    .query:

        ; Query memory
        mov ax, 0xE820
        mov cx, 24
        mov edx, 0x534D4150
        int 0x15
        
        ; Error?
        jc .err

        ; Continue?
        or bx, bx
        jz .done

        ; Increment di
        add di, cx

        ; Loop
        jmp .query

    ; Done
    .done:
        
        ; Done
        ret

    ; Error
    .err:

        ; Disable interrupts
        cli

        ; Hang
        jmp $


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
    jb .error_disk_read

    ; Done
    ret

    .error_disk_read-=:
            
        ; Print an error message
        mov si, disk_read_error_msg
        call print

        ; Disable interrupts
        cli

        ; Hang
        hlt

[BITS 32]
prot_md:
    
    ; Disable interrupts (redundant)
    cli

    ; Update protected mode data segment
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Update stack pointer
    mov esp, 0x3000

    .end:

        ; Initialize the renderer
        call renderer_init
        
        ; Draw
        call draw_line

        ; Halt
        cli
        hlt

    .err: 

    ; Disable interrupts
    cli

    ; Hang
    jmp $

; Allocator module
%include "allocator.inc"

; Renderer module
%include "renderer.inc"

; Data 
gdtinfo:
   dw gdt_end - gdt - 1
   dd gdt
gdt:
descriptor_null: 
    dq 0
descriptor_code:
    db 0xff, 0xff, 0, 0, 0, 0x9A, 0xCF, 0
descriptor_data:
    db 0xff, 0xff, 0, 0, 0, 0x92, 0xCF, 0
gdt_end:
address_range_descriptors:
    ard0:
        dq 0x0, 0x00
        dd 0x0
    ard1:
        dq 0x0, 0x00
        dd 0x0
    ard2:
        dq 0x0, 0x00
        dd 0x0
    ard3:
        dq 0x0, 0x00
        dd 0x0
    ard4:
        dq 0x0, 0x00
        dd 0x0
    ard5:
        dq 0x0, 0x00
        dd 0x0
    ard6:
        dq 0x0, 0x00
        dd 0x0
    ard7:
        dq 0x0, 0x00
        dd 0x0
disk_read_error_msg: db "Disk read error!", 0x0A, 0x0D, 0x00
no_root_error_msg:   db "Root node not found!", 0x0A, 0x0D, 0x00

even_block: dw 0x1000
odd_block: dw 0x1100

; Disk metadata
%include "index_metadata.inc"

; Theme data
%include "theme.inc"

dap:
    db 0x10
    db 0x00
sector_quantity:
    dw 0x0001
    dd 0x00001000
sector: 
    dq 0xFFFFFFFFFFFFFFFF
