; GluOS kernel loader renderer
;   
; @file renderer.inc
;   
; @author Jacob Smith

; IN: void
global renderer_init
renderer_init:

    ; Store a pointer to the framebuffer
    mov esi, 0x2028
    mov edi, dword [esi]
    mov dword [framebuffer.pointer], edi

    ; sizeof(framebuffer)
    mov ecx, 0x240000

    ; Clear the framebuffer
    .lp:

        ; White
        mov dword [edi], 0xffffff

        ; 24-bit
        add edi, 3

        ; downto
        dec ecx

        ; zero
        jecxz .end

        ; Continue
        jmp .lp

    .end:
    
        ; Done
        ret

;IN: eax: x, ebx: y, ecx: color
global renderer_pixel_set
renderer_pixel_set:
    
    ; Preserve
    push eax
    push ebx

    ; x * 3
    mov edx, 3
    mul

    ; w * y * 3
    xchg eax, ebx
    mul
    mov edx, [framebuffer.width] 
    mul

    ; (w * y * 3) + (x * 3)
    add eax, ebx

    ; framebuffer
    mov edx, [framebuffer.pointer]
    add edx

    ; Store color
    mov dword [eax], ecx

    ; Restore
    pop ebx
    pop eax

    ; Done
    ret

; Draw a line
renderer_line_draw:

    ; Start position
    mov eax, 100
    mov ebx, 100

    ; Color
    mov ecx, 0x000000
    
    .lp:

        ; Draw
        inc eax
        inc ebx
        call renderer_pixel_set 

        ; 100 < x < 200
        cmp eax, 200
        je .end
    
    .end:
        
        ; Done
        ret

; Data
framebuffer:
    .pointer: dd 0x00000000
    .width:   dd 0x00000000
    .height:  dd 0x00000000
