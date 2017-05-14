;*************************************************
; sse.asm                                        *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


;
; SSE ϵ��ָ�����

init_sse:
        
        ret


;--------------------------------
; store_xmm(image): ���� xmm �Ĵ���
; input:
;       esi: address of image
;-------------------------------
store_xmm:
        movdqu [esi], xmm0
        movdqu [esi + 16], xmm1
        movdqu [esi + 32], xmm2
        movdqu [esi + 48], xmm3
        movdqu [esi + 64], xmm4
        movdqu [esi + 80], xmm5
        movdqu [esi + 96], xmm6
        movdqu [esi + 112], xmm7
        ret

;-----------------------------------
; restore_xmm(image): �ָ� xmm �Ĵ���
; input:
;       esi: address of image
;----------------------------------
restore_xmm:
        movdqu xmm0, [esi]
        movdqu xmm1, [esi + 16]
        movdqu xmm2, [esi + 32] 
        movdqu xmm3, [esi + 48] 
        movdqu xmm4, [esi + 64] 
        movdqu xmm5, [esi + 80] 
        movdqu xmm6, [esi + 96] 
        movdqu xmm7, [esi + 112] 
        ret

;---------------------------------------
; store_sse(image)�� ���� SSEx ���� state
; input:
;       esi: image
;---------------------------------------
store_sse:
        call store_xmm
        stmxcsr [esi + 128]
        ret

;----------------------------------------
; restore_sse(image): �ָ� SSEx ���� state
; input:
;       esi: image
;----------------------------------------
restore_sse:
        call restore_xmm
        ldmxcsr [esi + 128]
        ret

;-----------------------------
; sse4_strlen(): �õ��ַ�������
; input:
;       esi: string
; output:
;       eax: length of string
;-----------------------------
sse4_strlen:
        push ecx
        pxor xmm0, xmm0                 ; �� XMM0 �Ĵ���
        mov eax, esi
        sub eax, 16
sse4_strlen_loop:        
        add eax, 16
        pcmpistri xmm0, [eax], 8        ; unsigned byte, equal each, IntRes2=IntRes1, lsb index
        jnz sse4_strlen_loop
        add eax, ecx
        sub eax, esi
        pop ecx
        ret


;----------------------------------------------------------
; substr_search(str1, str2): ���Ҵ�str2 �� str1�����ֵ�λ��
; input:
;       esi: str1, edi: str2
; outpu:
;       -1: �Ҳ��������� eax = ���� str2 �� str1 ��λ��
;----------------------------------------------------------
substr_search:
        push ecx
        push ebx
        lea eax, [esi - 16]
        movdqu xmm0, [edi]              ; str2 ��
	mov ecx, 16
        mov ebx, -1
substr_search_loop:
	add eax, ecx                     ; str1 ��
        test ecx, ecx
        jz found
	pcmpistri xmm0, [eax], 0x0c     ; unsigned byte, substring search, LSB index
	jnz substr_search_loop   
found:        
        add eax, ecx
	sub eax, esi                    ; eax = λ��
        cmp ecx, 16
        cmovz eax, ebx
        pop ebx
        pop ecx
	ret
        
