;*************************************************
; guest_ex.asm                                   *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************

        ;;
        ;; ���� ex.asm ģ��ʹ�õ�ͷ�ļ�
        ;;
        %include "ex.inc"
        
        
        ;;
        ;; ���� ex7-3��ʵ�� local APIC ���⻯
        ;; �����������Ϊ��
        ;;      1) build -DDEBUG_RECORD_ENABLE -DGUEST_ENABLE -D__X64 -DGUEST_X64
        ;;      2) build -DDEBUG_RECORD_ENABLE -DGUEST_ENABLE -D__X64
        ;;      3) build -DDEBUG_RECORD_ENABLE -DGUEST_ENABLE
        ;;
        

        ;;
        ;; ���� local APIC base ֵΪ 01000000h
        ;;
        mov ecx, IA32_APIC_BASE
        mov eax, 01000000h | APIC_BASE_BSP | APIC_BASE_ENABLE
        xor edx, edx
        wrmsr

        mov esi, GuestEx.Msg0
        call PutStr
        mov ecx, IA32_APIC_BASE
        rdmsr
        mov esi, eax
        and esi, ~0FFFh
        mov edi, edx
        call PrintQword
        call PrintLn
                
        mov R3, GUEST_APIC_BASE 
        
        ;;
        ;; TPR = 50h
        ;;
        mov eax, 50h
        mov [R3 + LAPIC_TPR], eax        
        mov esi, GuestEx.Msg1
        call PutStr        
        mov esi, [R3 + LAPIC_TPR]        
        call PrintValue
        call PrintLn

        ;;
        ;; TPR = 60h
        ;;
        mov DWORD [R3 + LAPIC_TPR], 60h    
        mov esi, GuestEx.Msg1
        call PutStr        
        mov esi, [R3 + LAPIC_TPR]        
        call PrintValue        
        
        jmp $
        
GuestEx.Msg0    db      'APIC base: ', 0
GuestEx.Msg1    db      'TPR:       ', 0


                