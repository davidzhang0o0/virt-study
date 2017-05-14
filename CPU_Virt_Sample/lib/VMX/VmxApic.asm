;*************************************************
;* VmxApic.asm                                   *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************



EPT_VIOLATION_NO_FIXING                 EQU     0
EPT_VIOLATION_FIXING                    EQU     1



;-----------------------------------------------------------------------
; EptHandlerForGuestApicPage()
; input:
;       none
; output:
;       eax - ������
; ������
;       1) �������� guest APIC-page ������� EPT violation
;-----------------------------------------------------------------------
EptHandlerForGuestApicPage:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

       
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        
        ;;
        ;; EPT violation ��ϸ��Ϣ
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        
        ;;
        ;; guest ���� APIC-page ��ƫ����
        ;;
        REX.Wrxb
        mov edx, [ebp + PCB.ExitInfoBuf + EXIT_INFO.GuestPhysicalAddress]    
        and edx, 0FFFh
        
        ;;
        ;; ��� guest ��������
        ;;
        test eax, EPT_READ
        jnz EptHandlerForGuestApicPage.Read
        test eax, EPT_EXECUTE
        jz EptHandlerForGuestApicPage.Write
        
        ;;
        ;; ���� guest ����ִ�� APIC-page ҳ�棬ע��һ�� #PF(0x11) �쳣
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_PF
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0011h
        REX.Wrxb
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.GuestLinearAddress] 
        REX.Wrxb
        mov cr2, eax
        jmp EptHandlerForGuestApicPage.Done
        
EptHandlerForGuestApicPage.Write:
        ;;
        ;; ��ȡԴ������ֵ
        ;;
        GetVmcsField    GUEST_RIP
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_va
        REX.Wrxb
        mov esi, eax
        mov al, [esi]                           ; opcode
        cmp al, 89h
        je EptHandlerForGuestApicPage.Write.Opcode89
        cmp al, 0C7h
        je EptHandlerForGuestApicPage.Write.OpcodeC7
        
        ;;
        ;; ### ע�⣬��Ϊʾ�������ﲻ��������ָ�������������
        ;; 1) ʹ������ opcode ��ָ��
        ;; 1) ���� REX prefix��4xH) ָ��
        ;;
        jmp EptHandlerForGuestApicPage.Done
        
EptHandlerForGuestApicPage.Write.OpcodeC7:
        ;;
        ;; ���� ModRM �ֽ�
        ;;
        mov al, [esi + 1]
        mov cl, al
        and ecx, 7        
        cmp cl, 4
        sete cl                                 ; ��� ModRM.r/m = 4���� cl = 1������ cl = 0
        shr al, 6
        jz EptHandlerForGuestApicPage.Write.@2  ; ModRM.Mod = 0���� ecx += 0
        cmp al, 1                               ; ModRM.Mod = 1���� ecx += 2
        je EptHandlerForGuestApicPage.Write.OpcodeC7.@1
        add ecx, 2        
EptHandlerForGuestApicPage.Write.OpcodeC7.@1:
        add ecx, 2                              ; ModRM.Mod = 2, �� ecx += 4
                                                ; ModRM.Mod = 3�����ڴ��� encode
EptHandlerForGuestApicPage.Write.@2:
        ;;
        ;; ��ȡд��������
        ;;
        mov eax, [esi + ecx + 2]

        jmp EptHandlerForGuestApicPage.Write.Next
        
EptHandlerForGuestApicPage.Write.Opcode89:
        ;;
        ;; ��ȡԴ������
        ;;
        mov esi, [esi + 1]
        shr esi, 3
        and esi, 7
        call get_guest_register_value        

EptHandlerForGuestApicPage.Write.Next:
        ;;
        ;; virtual APIC-page ҳ��
        ;;
        REX.Wrxb
        mov esi, [ebx + VMB.VirtualApicAddress]   
        
        ;;
        ;; APIC-page ��д�� offset Ϊ��д�����������
        ;; 1) 80h:      TPR
        ;; 2) B0h:      EOI
        ;; 3) D0h:      LDR
        ;; 4) E0h:      DFR
        ;; 5) F0h:      SVR
        ;; 6) 2F0h - 370h:      LVT
        ;; 7) 380h:     TIMER-ICR
        ;; 8) 3E0h:     TIMER-DCR
        ;;
        cmp edx, 80h
        jne EptHandlerForGuestApicPage.Write.@1
        
        DEBUG_RECORD    "[EptHandlerForGuestApicPage]: wirte to APIC-page"
        
        ;;
        ;; д�� TPR
        ;;
        mov [esi + 80h], eax
        jmp EptHandlerForGuestApicPage.Done
        
EptHandlerForGuestApicPage.Write.@1:
        
        jmp EptHandlerForGuestApicPage.Done



EptHandlerForGuestApicPage.Read:        
        ;;
        ;; ����ָ��
        ;;
        GetVmcsField    GUEST_RIP
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_va
        REX.Wrxb
        mov esi, eax
        mov al, [esi]                           ; opcode
        cmp al, 8Bh
        je EptHandlerForGuestApicPage.Read.Opcode8B
        
        ;;
        ;; ### ע�⣬��Ϊʾ�������ﲻ��������ָ�������������
        ;; 1) ʹ������ opcode ��ָ��
        ;; 1) ���� REX prefix��4xH) ָ��
        ;;
        jmp EptHandlerForGuestApicPage.Done
        
EptHandlerForGuestApicPage.Read.Opcode8B:
        ;;
        ;; ��ȡĿ������� ID
        ;;
        mov esi, [esi + 1]
        shr esi, 3
        and esi, 7
          
        ;;
        ;; APIC-page ������� offset Ϊ�ɶ�����
        ;; 1) 20h:      APIC ID
        ;; 2) 30h:      VER
        ;; 3) 80h:      TPR
        ;; 4) 90h:      APR
        ;; 5) A0h:      PPR
        ;; 6) B0h:      EOI
        ;; 7) C0h:      RRD
        ;; 8) D0h:      LDR
        ;; 9) E0h:      DFR
        ;; 10) F0h:     SVR
        ;; 11) 100h - 170h:     ISR
        ;; 12) 180h - 1F0h:     TMR
        ;; 13) 200h - 270h:     IRR
        ;; 14) 280h:    ESR
        ;; 15) 2F0h - 370h:     LVT
        ;; 16) 380h:    TIMER-ICR
        ;; 17) 3E0h:    TIMER-DCR
        ;;

        cmp edx, 80h
        jne EptHandlerForGuestApicPage.Read.@1
        
        DEBUG_RECORD    "[EptHandlerForGuestApicPage]: read from APIC-page"  
        
        ;;
        ;; д��Ŀ��Ĵ���
        ;;
        
        REX.Wrxb
        mov eax, [ebx + VMB.VirtualApicAddress]           
        mov edi, [eax + 80h]
        call set_guest_register_value
        jmp EptHandlerForGuestApicPage.Done

EptHandlerForGuestApicPage.Read.@1:        

EptHandlerForGuestApicPage.Done:
        call update_guest_rip
        mov eax, EPT_VIOLATION_NO_FIXING
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        

