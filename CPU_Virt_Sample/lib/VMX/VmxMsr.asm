;*************************************************
;* VmxMsr.asm                                    *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


;;
;; ������� MSR ����
;;

  
        
;-----------------------------------------------------------------------
; GetMsrVte()
; input:
;       esi - MSR index
; output:
;       eax - MSR VTE��value table entry����ַ
; ������
;       1) ���� MSR ��Ӧ�� VTE �����ַ
;       2) ������ MSR ʱ������ 0 ֵ��
;-----------------------------------------------------------------------
GetMsrVte:
        push ebp
        push ebx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        cmp DWORD [ebx + VMB.MsrVteCount], 0
        je GetMsrVte.NotFound
        
        REX.Wrxb
        mov eax, [ebx + VMB.MsrVteBuffer]               
        
GetMsrVte.@1:                
        cmp esi, [eax]                                  ; ��� MSR index ֵ
        je GetMsrVte.Done
        REX.Wrxb
        add eax, MSR_VTE_SIZE                           ; ָ����һ�� entry
        REX.Wrxb
        cmp eax, [ebx + VMB.MsrVteIndex]
        jb GetMsrVte.@1
GetMsrVte.NotFound:
        xor eax, eax
GetMsrVte.Done:        
        pop ebx
        pop ebp
        ret



;-----------------------------------------------------------------------
; AppendMsrVte()
; input:
;       esi - MSR index
;       eax - MSR low32
;       edx - MSR hi32
; output:
;       eax - VTE ��ַ
; ������
;       1) �� MSR VTE buffer ��д�� MSR VTE ��Ϣ
;-----------------------------------------------------------------------
AppendMsrVte:
        push ebp
        push ebx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]     
        mov ebx, eax
        call GetMsrVte
        REX.Wrxb
        test eax, eax
        jnz AppendMsrVte.WriteVte
        
        mov eax, MSR_VTE_SIZE
        REX.Wrxb
        xadd [ebp + VMB.MsrVteIndex], eax
        inc DWORD [ebp + VMB.MsrVteCount]
                
AppendMsrVte.WriteVte:
        ;;
        ;; д�� MSR VTE ����
        ;;
        mov [eax + MSR_VTE.MsrIndex], esi
        mov [eax + MSR_VTE.Value], ebx
        mov [eax + MSR_VTE.Value + 4], edx
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------------------------
; DoWriteMsrForApicBase()
; input:
;       none
; output:
;       none
; ������
;       1) ���� guest ���� IA32_APIC_BASE �Ĵ���
;-----------------------------------------------------------------------
DoWriteMsrForApicBase:
        push ebp
        push ebx
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebx + VMB.VsbBase]
               
        ;;
        ;; ��ȡ guest д��� MSR ֵ
        ;;
        mov eax, [ebx + VSB.Rax]
        mov edx, [ebx + VSB.Rdx]

        DEBUG_RECORD    "[DoWriteMsrForApicBase]: write to IA32_APIC_BASE"
                
        ;;
        ;; ### ���д��ֵ�Ƿ�Ϸ� ###
        ;; 1) ����λ��bits 7:0, bit 9��bits 63:N����Ϊ 0
        ;; 2) ��� bit 11 �� bit 10 ������
        ;;      a) �� bit 11 = 1, bit 10 = 0 ʱ������ bit 11 = 1�� bit 10 = 1 ���� x2APIC ģʽ
        ;;      b) �� bit 11 = 0, bit 10 = 1 ʱ����Ч
        ;;      c) �� bit 11 = 0, bit 10 = 0 ʱ���ر� local APIC
        ;;      d) �� bit 11 = 1, bit 10 = 1 ʱ������ bit 11 = 1, bit 10 = 0 ʱ������ #GP �쳣 
        ;;
        
        ;;
        ;; ��鱣��λ����Ϊ 0 ʱע�� #GP �쳣
        ;;
        test eax, 2FFh
        jnz DoWriteMsrForApicBase.Error
        mov esi, [ebp + PCB.MaxPhyAddrSelectMask + 4]
        not esi
        test edx, esi
        jnz DoWriteMsrForApicBase.Error
        
        ;;
        ;; ��� xAPIC enable��bit 11���� x2APIC enable��bit 10��
        ;;
        test eax, APIC_BASE_X2APIC
        jz DoWriteMsrForApicBase.Check.@1

        ;;
        ;; �� bit 10 = 1 ʱ����� CPUID.01H:ECX[21].x2APIC λ
        ;; 1) Ϊ 0 ʱ������֧�� x2APIC ģʽ��ע�� #GP(0) �쳣
        ;; 
        test DWORD [ebp + PCB.CpuidLeaf01Ecx], (1 << 21)
        jz DoWriteMsrForApicBase.Error

        ;;
        ;; �� bit 10 = 1 ʱ��bit 11 = 0����Ч������ע�� #GP(0) �쳣
        ;;
        test eax, APIC_BASE_ENABLE
        jz DoWriteMsrForApicBase.Error
        

DoWriteMsrForApicBase.x2APIC:
        ;;
        ;; ���� bit 10 = 1, bit 11 = 1
        ;; 1) ʹ�� x2APIC ģʽ�����⻯����
        ;;       
        mov esi, IA32_APIC_BASE
        call AppendMsrVte                                ;; ���� guest д��ԭֵ
        

        ;;
        ;; ��� secondary prcessor-based VM-execution control �ֶΡ�virtualize x2APIC mode��λ
        ;; 1) Ϊ 1 ʱ��ʹ�� VMX ԭ���� x2APIC ���⻯��ֱ�ӷ���
        ;; 2) Ϊ 0 ʱ����� 800H - 8FFH MSR �Ķ�д
        ;;
        GetVmcsField    CONTROL_PROCBASED_SECONDARY
        test eax, VIRTUALIZE_X2APIC_MODE
        jnz DoWriteMsrForApicBase.Done
        
        ;;
        ;; ���ڼ�� x2APIC MSR �Ķ�д����Χ�� 800H �� 8FFH
        ;;
        call set_msr_read_bitmap_for_x2apic
        call set_msr_write_bitmap_for_x2apic
        jmp DoWriteMsrForApicBase.Done
                
DoWriteMsrForApicBase.Check.@1:
        ;;
        ;; bit 10 = 0, bit 11 = 0���ر� local APIC�����������⻯����
        ;; 1��д�� IA32_APIC_BASE �Ĵ���
        ;; 2���ָ�ӳ��
        ;;
        test eax, APIC_BASE_ENABLE
        jnz DoWriteMsrForApicBase.Check.@2
        
        ;;
        ;; guest ���Թر� local APIC
        ;; 1) �ָ� guest �� IA32_APIC_BASE �Ĵ�����д��
        ;; 2) �ָ� EPT ӳ��
        ;;
        mov esi, IA32_APIC_BASE
        mov eax, [ebx + VSB.Rax]
        mov edx, [ebx + VSB.Rdx]
        call append_vmentry_msr_load_entry

%ifdef __X64        
        REX.Wrxb
        mov esi, [ebx + VSB.Rax]
        mov edi, 0FEE00000h
        mov eax, EPT_WRITE | EPT_READ
        call do_guest_physical_address_mapping
%else
        mov esi, [ebx + VSB.Rax]
        mov edi, [ebx + VSB.Rdx]
        mov eax, 0FEE00000h
        mov edx, 0
        mov ecx, EPT_WRITE | EPT_READ
        call do_guest_physical_address_mapping
%endif

        jmp DoWriteMsrForApicBase.Done
        
DoWriteMsrForApicBase.Check.@2:
        ;;
        ;; ��ȡԭ guest ���õ� APIC_APIC_BASE ֵ
        ;; 1) ���緵�� 0 ֵ������� guest �� 1 ��д IA32_APIC_BASE
        ;;
        mov esi, IA32_APIC_BASE
        call GetMsrVte
        test eax, eax
        jz DoWriteMsrForApicBase.xAPIC
                
        ;;
        ;; ���ԭֵ bit 11 = 1, bit 10 = 1 ʱ�������� bit 11 = 1, bit 10 = 0 ʱ�������� #GP �쳣
        ;;
        test DWORD [eax + MSR_VTE.Value], APIC_BASE_X2APIC
        jnz DoWriteMsrForApicBase.Error
        
        
DoWriteMsrForApicBase.xAPIC:
        ;;
        ;; ### �������⻯ local APIC �� xAPIC ģʽ ###
        ;;                
        mov esi, IA32_APIC_BASE
        mov eax, [ebx + VSB.Rax]
        mov edx, [ebx + VSB.Rdx]
        call AppendMsrVte                               ; ���� guest д��ֵ
        
        REX.Wrxb
        mov edx, eax
        
        ;;
        ;; 1������Ƿ����ˡ�virtualize APIC access ��
        ;;     a) �ǣ������� APIC-access page ҳ��
        ;;     b) �����ṩ GPA ���̴��� local APIC ����
        ;; 2������Ƿ����ˡ�enable EPT��
        ;;     a���ǣ���ӳ�� IA32_APIC_BASE[N-1:12]���� APIC-access page ����Ϊ�� HPA ֵ
        ;;     b������ֱ�ӽ� IA32_APIC_BASE[N-1:12] ��Ϊ APIC-access page
        ;;
        
        GetVmcsField    CONTROL_PROCBASED_SECONDARY
        
        test eax, VIRTUALIZE_APIC_ACCESS
        jz DoWriteMsrForApicBase.SetForEptViolation        
        test eax, ENABLE_EPT
        jz DoWriteMsrForApicBase.EptDisable
        
        ;;
        ;; ִ�� EPT ӳ�䵽 0FEE00000H
        ;;
%ifdef __X64        
        REX.Wrxb
        mov esi, [edx + MSR_VTE.Value]
        mov edi, 0FEE00000h
        mov eax, EPT_READ | EPT_WRITE
        call do_guest_physical_address_mapping
%else
        mov esi, [edx + MSR_VTE.Value]
        mov edi, [edx + MSR_VTE.Value + 4]
        mov eax, 0FEE00000H
        mov edx, 0
        mov ecx, EPT_READ | EPT_WRITE
        call do_guest_physical_address_mapping
%endif

        mov eax, 0FEE00000h
        mov edx, 0
        jmp DoWriteMsrForApicBase.SetApicAccessPage


DoWriteMsrForApicBase.EptDisable:
        REX.Wrxb
        mov eax, [edx + MSR_VTE.Value]
        mov edx, [edx + MSR_VTE.Value + 4]
        REX.Wrxb
        and eax, ~0FFFh
        
DoWriteMsrForApicBase.SetApicAccessPage:        
        SetVmcsField    CONTROL_APIC_ACCESS_ADDRESS_FULL, eax
%ifndef __X64
        SetVmcsField    CONTROL_APIC_ACCESS_ADDRESS_HIGH, edx
%endif        
        
        call update_guest_rip
        jmp DoWriteMsrForApicBase.Done
        
        
DoWriteMsrForApicBase.SetForEptViolation:
        ;;
        ;; ���� guest д�� IA32_APIC_BASE �Ĵ�����ֵ��
        ;; 1���� IA32_APIC_BASE[N-1:12] ӳ�䵽 host �� IA32_APIC_BASE ֵ������Ϊ not-present
        ;; 2��GPA �������κ�ӳ��
        ;;        
        
        ;;
        ;; Ϊ GPA �ṩ��������
        ;;
        REX.Wrxb
        mov esi, [edx + MSR_VTE.Value]
        REX.Wrxb
        and esi, ~0FFFh
        mov edi, EptHandlerForGuestApicPage
        call AppendGpaHte

       
        call update_guest_rip
        jmp DoWriteMsrForApicBase.Done
        
DoWriteMsrForApicBase.Error:
        ;;
        ;; ���� #GP(0) �� guest ����
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_GP
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0

DoWriteMsrForApicBase.Done:        
        pop ecx
        pop edx
        pop ebx
        pop ebp
        ret
        
        

;-----------------------------------------------------------------------
; DoReadMsrForApicBase()
; input:
;       none
; output:
;       none
; ������
;       1) ���� guest �� IA32_APIC_BASE �Ĵ���
;-----------------------------------------------------------------------
DoReadMsrForApicBase:
        push ebp
        push ebx
        push edx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebx + VMB.VsbBase]

        mov esi, IA32_APIC_BASE
        call GetMsrVte
        REX.Wrxb
        test eax, eax
        jz DoReadMsrForApicBase.Done
        
        mov edx, [eax + MSR_VTE.Value + 4]
        mov eax, [eax + MSR_VTE.Value]
        mov [ebx + VSB.Rax], eax
        mov [ebx + VSB.Rdx], edx
        
        DEBUG_RECORD    "[DoWriteMsrForApicBase]: read from IA32_APIC_BASE"
        
        call update_guest_rip
DoReadMsrForApicBase.Done:
        pop edx
        pop ebx
        pop ebp
        ret



;-----------------------------------------------------------------------
; set_msr_read_bitmap_for_x2apic()
; input:
;       none
; output:
;       none
;-----------------------------------------------------------------------        
set_msr_read_bitmap_for_x2apic:
        SET_MSR_READ_BITMAP        IA32_X2APIC_APICID
        SET_MSR_READ_BITMAP        IA32_X2APIC_VERSION
        SET_MSR_READ_BITMAP        IA32_X2APIC_TPR
        SET_MSR_READ_BITMAP        IA32_X2APIC_PPR
        SET_MSR_READ_BITMAP        IA32_X2APIC_EOI
        SET_MSR_READ_BITMAP        IA32_X2APIC_LDR
        SET_MSR_READ_BITMAP        IA32_X2APIC_SVR
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR0
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR1
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR2
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR3
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR4
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR5
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR6
        SET_MSR_READ_BITMAP        IA32_X2APIC_ISR7
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR0
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR1
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR2
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR3
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR4
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR5
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR6
        SET_MSR_READ_BITMAP        IA32_X2APIC_TMR7
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR0
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR1
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR2
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR3
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR4
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR5
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR6
        SET_MSR_READ_BITMAP        IA32_X2APIC_IRR7
        SET_MSR_READ_BITMAP        IA32_X2APIC_ESR
        SET_MSR_READ_BITMAP        IA32_X2APIC_LVT_CMCI
        SET_MSR_READ_BITMAP        IA32_X2APIC_ICR
        SET_MSR_READ_BITMAP        IA32_X2APIC_LVT_TIMER
        SET_MSR_READ_BITMAP        IA32_X2APIC_LVT_THERMAL
        SET_MSR_READ_BITMAP        IA32_X2APIC_LVT_PMI 
        SET_MSR_READ_BITMAP        IA32_X2APIC_LVT_LINT0 
        SET_MSR_READ_BITMAP        IA32_X2APIC_LVT_LINT1 
        SET_MSR_READ_BITMAP        IA32_X2APIC_LVT_ERROR
        SET_MSR_READ_BITMAP        IA32_X2APIC_INIT_COUNT
        SET_MSR_READ_BITMAP        IA32_X2APIC_CUR_COUNT
        SET_MSR_READ_BITMAP        IA32_X2APIC_DIV_CONF
        SET_MSR_READ_BITMAP        IA32_X2APIC_SELF_IPI
        ret
        
        
;-----------------------------------------------------------------------
; set_msr_write_bitmap_for_x2apic()
; input:
;       none
; output:
;       none
;-----------------------------------------------------------------------        
set_msr_write_bitmap_for_x2apic:
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_APICID
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_VERSION
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TPR
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_PPR
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_EOI
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LDR
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_SVR
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR0
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR1
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR2
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR3
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR4
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR5
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR6
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ISR7
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR0
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR1
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR2
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR3
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR4
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR5
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR6
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_TMR7
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR0
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR1
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR2
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR3
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR4
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR5
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR6
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_IRR7
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ESR
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_CMCI
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_ICR
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_TIMER
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_THERMAL
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_PMI 
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_LINT0 
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_LINT1 
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_ERROR
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_INIT_COUNT
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_CUR_COUNT
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_DIV_CONF
        SET_MSR_WRITE_BITMAP        IA32_X2APIC_SELF_IPI
        ret


;-----------------------------------------------------------------------
; clear_msr_read_bitmap_for_x2apic()
; input:
;       none
; output:
;       none
;-----------------------------------------------------------------------        
clear_msr_read_bitmap_for_x2apic:
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_APICID
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_VERSION
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TPR
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_PPR
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_EOI
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LDR
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_SVR
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR0
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR1
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR2
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR3
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR4
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR5
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR6
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ISR7
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR0
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR1
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR2
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR3
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR4
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR5
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR6
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_TMR7
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR0
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR1
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR2
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR3
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR4
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR5
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR6
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_IRR7
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ESR
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LVT_CMCI
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_ICR
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LVT_TIMER
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LVT_THERMAL
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LVT_PMI 
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LVT_LINT0 
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LVT_LINT1 
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_LVT_ERROR
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_INIT_COUNT
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_CUR_COUNT
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_DIV_CONF
        CLEAR_MSR_READ_BITMAP        IA32_X2APIC_SELF_IPI
        ret
        
        
;-----------------------------------------------------------------------
; clear_msr_write_bitmap_for_x2apic()
; input:
;       none
; output:
;       none
;-----------------------------------------------------------------------        
clear_msr_write_bitmap_for_x2apic:
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_APICID
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_VERSION
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TPR
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_PPR
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_EOI
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LDR
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_SVR
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR0
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR1
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR2
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR3
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR4
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR5
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR6
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ISR7
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR0
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR1
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR2
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR3
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR4
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR5
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR6
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_TMR7
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR0
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR1
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR2
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR3
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR4
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR5
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR6
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_IRR7
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ESR
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_CMCI
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_ICR
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_TIMER
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_THERMAL
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_PMI 
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_LINT0 
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_LINT1 
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_LVT_ERROR
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_INIT_COUNT
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_CUR_COUNT
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_DIV_CONF
        CLEAR_MSR_WRITE_BITMAP        IA32_X2APIC_SELF_IPI
        ret
        
        
        
;-----------------------------------------------------------------------
; DoWriteMsrForApicBase()
; input:
;       none
; output:
;       none
; ������
;       1) ���� guest ���� IA32_EFER �Ĵ���
;-----------------------------------------------------------------------
DoWriteMsrEfer:
        push ebp
        push ebx
        push edx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebx + VMB.VsbBase]
        
        ;;
        ;; ��鱣��λ
        ;;
        mov eax, [ebx + VSB.Rax]
        mov edx, [ebx + VSB.Rdx]
        test eax, ~(EFER_LME | EFER_LMA | EFER_SCE | EFER_NXE)
        jnz DoWriteMsrEfer.Gp
        test edx, edx
        jnz DoWriteMsrEfer.Gp
        
        ;;
        ;; ����Ƿ��� long-mode ģʽ
        ;;
        test eax, EFER_LME
        jz DoWriteMsrEfer.Write
        
        ;;
        ;; �� long-mode ģʽ�£����� IDT �� limit Ϊ 1FFh
        ;;
        SetVmcsField    GUEST_IDTR_LIMIT, 1FFh
        
        ;;
        ;; ���� VMM ���õ� IDTR.limit 
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        mov WORD [ebx + VMB.GuestImb + GIMB.HookIdtLimit], 1FFh
        
DoWriteMsrEfer.Write:
        ;;
        ;; д�� IA32_EFER �Ĵ���
        ;;
        SetVmcsField    GUEST_IA32_EFER_FULL, eax
        SetVmcsField    GUEST_IA32_EFER_HIGH, edx
        jmp DoWriteMsrEfer.Resume
        
DoWriteMsrEfer.Gp:
        ;;
        ;; ע�� #GP(0) �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_GP
        jmp DoWriteMsrEfer.Done

DoWriteMsrEfer.Resume:
        call update_guest_rip
                
DoWriteMsrEfer.Done:
        mov eax, VMM_PROCESS_RESUME        
        pop edx
        pop ebx
        pop ebp
        ret