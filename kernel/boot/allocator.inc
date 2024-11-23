; GluOS kernel loader allocator
;   
; @file allocator.inc
;   
; @author Jacob Smith

;IN: eax: size
;OUT: eax: size, edx: pointer
global allocator_bump
allocator_bump:

    ; Load base
    mov ebx, [allocator.base]

    ; Load size
    mov edx, [allocator.size]

    ; Compute new pointer
    mov ecx, eax
    add ecx, edx
    add ecx, ebx

    ; TORO
    mov ecx, edx

    .end:

        ; Done
        ret

allocator:
    .size: dd 0x0000
    .base: dd 0x5000