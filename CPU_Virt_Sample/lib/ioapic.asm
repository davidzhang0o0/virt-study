;*************************************************
;* ioapic.asm                                    *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


init_ioapic_unit:
        call enable_ioapic
        call init_ioapic_keyboard
        ret
        
        
;------------------------------------
; enable_ioapic()
; input:
;       none
; output:
;       none
; ����:
;       1) ���� ioapic
;       2) �� stage1 ��ʹ��
;------------------------------------
enable_ioapic:
        ;;
        ;; ���� ioapic
        ;;
        call get_root_complex_base_address
        mov esi, [eax + 31FEh]
        bts esi, 8                                      ; IOAPIC enable λ
        and esi, 0FFFFFF00h                             ; IOAPIC range select
        mov [eax + 31FEh], esi                          ; enable ioapic
       
        ;;
        ;; ���� IOAPIC ID
        ;;
        mov DWORD [0FEC00000h], IOAPIC_ID_INDEX
        mov DWORD [0FEC00010h], 0F000000h              ; IOAPIC ID = 0Fh
        ret



;-----------------------------------
; ioapic_keyboard_handler()
;-----------------------------------
ioapic_keyboard_handler:
        push ebp
        push ecx
        push ebx
        push esi
        push edi
        push eax

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  
     
        
        in al, I8408_DATA_PORT                          ; ������ɨ����
        test al, al
        js ioapic_keyboard_handler.done                 ; Ϊ break code
        
        ;;
        ;; �Ƿ�Ϊ���ܼ�
        ;;
        cmp al, SC_F1
        jb ioapic_keyboard_handler.next
        cmp al, SC_F10
        ja ioapic_keyboard_handler.next

        ;;
        ;; �л���ǰ������
        ;;
        sub al, SC_F1
        movzx esi, al
        mov edi, switch_to_processor
        call force_dispatch_to_processor
        
        
        jmp ioapic_keyboard_handler.done
        
ioapic_keyboard_handler.next:
        
        ;;
        ;; ��ɨ���뱣���ڴ������Լ��� local keyboard buffer ��
        ;; local keyboard buffer �� SDA.KeyBufferHeadPointer �� SDA.KeyBufferPtrPointer ָ��ָ��
        ;;
        REX.Wrxb
        mov ebx, [ebp + SDA.KeyBufferPtrPointer]                ; ebx = LSB.LocalKeyBufferPtr ָ��ֵ
        REX.Wrxb
        mov esi, [ebx]                                          ; esi = LSB.LocalKeyBufferPtr ֵ
        REX.Wrxb
        INCv esi
        
        ;;
        ;; ����Ƿ񳬹�����������
        ;;
        REX.Wrxb
        mov ecx, [ebp + SDA.KeyBufferHead]                      ; ecx = LSB.KeyBufferHead
        REX.Wrxb
        mov edi, ecx
        REX.Wrxb
        add ecx, [ebp + SDA.KeyBufferLength]
        REX.Wrxb
        cmp esi, ecx
        REX.Wrxb
        cmovae esi, edi                                         ; ������ﻺ����β������ָ��ͷ��
        mov [esi], al                                           ; д��ɨ����
        REX.Wrxb
        xchg [ebx], esi                                         ; ���»�����ָ�� 
                
ioapic_keyboard_handler.done:       
        call send_eoi_command
        pop eax
        pop edi
        pop esi
        pop ebx
        pop ecx
        pop ebp
        REX.Wrxb
        iret


;----------------------------------------------------
; init_ioapic_keyboard(): ��ʼ�� ioapic keyboard ����
;----------------------------------------------------
init_ioapic_keyboard:
        push ebx
        ;;
        ;; ���� IOAPIC �� redirectior table 1 �Ĵ���        
        ;;
        mov ebx, [gs: PCB.IapicPhysicalBase]
        mov DWORD [ebx + IOAPIC_INDEX], IRQ1_INDEX
        mov DWORD [ebx + IOAPIC_DATA], LOGICAL | IOAPIC_IRQ1_VECTOR | IOAPIC_RTE_MASKED
        mov DWORD [ebx + IOAPIC_INDEX], IRQ1_INDEX + 1
        mov DWORD [ebx + IOAPIC_DATA], 01000000h                ; ʹ�� processor #0
        pop ebx
        ret
        
        
%if 0        
;----------------------------------------------
; wait_esc_for_reset_ex(): �ȴ����� <ESC> ������
;---------------------------------------------
wait_esc_for_reset_ex:
        mov esi, Ioapic.WaitResetMsg
        call puts
wait_esc_for_reset_ex.loop:
        xor esi, esi
        lock xadd [fs: SDA.KeyBufferPtr], esi
        mov al, [esi]
        cmp al, 01                              ; ��鰴���Ƿ�Ϊ <ESC> ��
        je wait_esc_for_reset_ex.next
        pause
        jmp wait_esc_for_reset_ex.loop        
        
wait_esc_for_reset_ex.next:        
        ;;
        ;; Now: broadcast INIT message
        ;;
        mov DWORD [APIC_BASE + ICR1], 0FF000000h
        mov DWORD [APIC_BASE + ICR0], 00004500h        
        ret
        
%endif        
        
        
