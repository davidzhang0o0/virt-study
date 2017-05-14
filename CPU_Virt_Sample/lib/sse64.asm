;*************************************************
; sse64.asm                                      *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


;;
;; 64-bit ģʽ�µ� SSE ϵ��ָ�����
;;

;-----------------------------
; sse4_strlen64(): �õ��ַ�������
; input:
;       rsi - string
; output:
;       eax - length of string
;-----------------------------
sse4_strlen64:
        push rcx
        pxor xmm0, xmm0                 ; �� XMM0 �Ĵ���
        mov rax, rsi
        sub rax, 16
sse4_strlen64.loop:        
        add rax, 16
        pcmpistri xmm0, [rax], 8        ; unsigned byte, equal each, IntRes2=IntRes1, lsb index
        jnz sse4_strlen64.loop
        add rax, rcx
        sub rax, rsi
        pop rcx
        ret


;----------------------------------------------------------
; substr_search64(str1, str2): ���Ҵ�str2 �� str1�����ֵ�λ��
; input:
;       rsi - str1 
;       rdi - str2
; outpu:
;       -1: �Ҳ��������� rax = ���� str2 �� str1 ��λ��
;----------------------------------------------------------
substr_search64:
        push rcx
        push rbx
        lea rax, [rsi - 16]
        movdqu xmm0, [rdi]              ; str2 ��
	mov ecx, 16
        xor ebx, ebx
        dec rbx                         ; rbx = -1
substr_search64.loop:
	add rax, rcx                    ; str1 ��
        test ecx, ecx
        jz substr_search64.found
	pcmpistri xmm0, [rax], 0Ch      ; unsigned byte, substring search, LSB index
	jnz substr_search64.loop   
substr_search64.found:
        add rax, rcx
	sub rax, rsi                    ; rax = λ��
        cmp rcx, 16
        cmovz rax, rbx
        pop rbx
        pop rcx
	ret




;-----------------------------------
; store_xmm64(image)
; input:
;       rsi - image
;-----------------------------------
store_xmm64:
        movdqu [rsi], xmm0
        movdqu [rsi + 16], xmm1
        movdqu [rsi + 32], xmm2 
        movdqu [rsi + 48], xmm3 
        movdqu [rsi + 64], xmm4 
        movdqu [rsi + 80], xmm5 
        movdqu [rsi + 96], xmm6 
        movdqu [rsi + 112], xmm7 
        movdqu [rsi + 128], xmm8 
        movdqu [rsi + 144], xmm9 
        movdqu [rsi + 160], xmm10 
        movdqu [rsi + 176], xmm11 
        movdqu [rsi + 192], xmm12
        movdqu [rsi + 208], xmm13 
        movdqu [rsi + 224], xmm14 
        movdqu [rsi + 240], xmm15 
        ret
        
;-----------------------------------
; restore_xmm64(image)
; input:
;       rsi - image
;-----------------------------------    
restore_xmm64:
        movdqu xmm0, [rsi]
        movdqu xmm1, [rsi + 16]
        movdqu xmm2, [rsi + 32] 
        movdqu xmm3, [rsi + 48] 
        movdqu xmm4, [rsi + 64] 
        movdqu xmm5, [rsi + 80] 
        movdqu xmm6, [rsi + 96] 
        movdqu xmm7, [rsi + 112] 
        movdqu xmm8, [rsi + 128] 
        movdqu xmm9, [rsi + 144] 
        movdqu xmm10, [rsi + 160] 
        movdqu xmm11, [rsi + 176] 
        movdqu xmm12, [rsi + 192] 
        movdqu xmm13, [rsi + 208] 
        movdqu xmm14, [rsi + 224] 
        movdqu xmm15, [rsi + 240] 
        ret
        

;--------------------------------
; store_sse64(image)
; input:
;       rsi: iamge
;-------------------------------
store_sse64:
        call store_xmm64
        stmxcsr [rsi + 256]
        ret
                
;-------------------------------
; restore_sse64(image)
; input:
;       rsi: image
;-------------------------------         
restore_sse64:
        call restore_xmm64
        ldmxcsr [rsi + 256]
        ret
        
                        
