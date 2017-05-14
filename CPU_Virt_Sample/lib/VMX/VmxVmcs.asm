;*************************************************
;* VmxVmcs.asm                                   *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************





;----------------------------------------------------------
; alloc_vmcs_region_4k_physical_base()
; input:
;       none
; output;
;       eax - ���� vmcs base �����ֵַ
; ������
;       1) �� kernel pool ����� 4k ����Ϊ vmcs region 
;----------------------------------------------------------
alloc_vmcs_region_4k_physical_base:      
        jmp alloc_kernel_pool_4k_physical_base
        
        
        
        
;----------------------------------------------------------
; alloc_vmcs_region_4k_base()
; input:
;       none
; output;
;       eax - ���� vmcs region �����ֵַ
; ������
;       1) �� kernel pool ����� 4k ����Ϊ vmcs region 
;----------------------------------------------------------
alloc_vmcs_region_4k_base:
        jmp alloc_kernel_pool_4k_base

        



;----------------------------------------------------------
; get_vmcs_page_memory_type()
; input:
;       none
; output:
;       eax - page attribute��PCD �� PWT ��־λ��
; ������
;       1) ���� VMCS �Լ� access page �еĹ��� PCD �� PWT ��־λ
;----------------------------------------------------------
get_vmcs_page_memory_type:
        ;;
        ;; ��� VMX access ֧�ֵ��ڴ�����
        ;;
        mov eax, PCB.VmcsMemoryType
        mov eax, [gs: eax]
        
        ;;
        ;; �Ƿ�֧�� WirteBack(06h)
        ;; 1) �ǣ����� PCD = 0, PWT = 0
        ;; 2) �񣬷��� PCD = 1, PWT = 1
        ;;
        mov esi, PCD | PWT                              ; ��Ӧ UC ����
        cmp eax, MEM_TYPE_WB
        mov eax, 0                                      ; ��Ӧ WB ����
        cmovne eax, esi
        ret  
        



;----------------------------------------------------------
; get_vmcs_pointer()
; input:
;       none
; output:
;       eax - vmcs pointer�������ַ��
;       edx - vmcs pointer�������ַ��
; ������ 
;       1) ��� vmcs pointer/vmcs access page pointer
;       2) eax ���������ַ��edx ���������ַ
;       3) 64-bit �£�rax 64 λ���������ַ�� rdx 64 λ���������ַ
;----------------------------------------------------------
get_vmcs_access_pointer:
get_vmcs_pointer:
        call get_vmcs_page_memory_type
        mov esi, eax
              
        
;----------------------------------------------------------
; get_vmcs_region_pointer()
; input:
;       esi - memory type
; output:
;       eax - vmcs pointer�������ַ��
;       edx - vmcs pointer�������ַ��
; ������ 
;       1) ��� vmcs pointer
;       2) eax ���������ַ��edx ���������ַ
;       3) 64-bit �£�rax 64 λ���������ַ�� rdx 64 λ���������ַ
;----------------------------------------------------------
get_vmcs_region_pointer:
        push ebx
        push ecx

        mov ecx, esi                                    ; memory type
        
        ;;
        ;; ���������ַ
        ;;
        call alloc_vmcs_region_4k_base
        REX.Wrxb
        mov ebx, eax                                    ; ebx - virtual address

        ;;
        ;; ���������ַ
        ;;
        call alloc_vmcs_region_4k_physical_base
        REX.Wrxb
        mov edx, eax                                    ; edx - physical address
        
        ;;
        ;; ��ַӳ��
        ;;
        REX.Wrxb
        mov esi, ebx                                    ; esi - virtual address
        REX.Wrxb
        mov edi, eax                                    ; edi - physical address



        mov eax, ecx                                    ; eax - page attribute
        or eax, XD | RW | P
        
%ifdef __X64
        DB 41h, 89h, 0C0h                               ; mov r8d, eax
%endif

        call do_virtual_address_mapping

        

        ;;
        ;; �� vmcs region 
        ;;
        REX.Wrxb
        mov esi, ebx
        call clear_4k_page

        REX.Wrxb
        mov eax, ebx        
        pop ecx
        pop ebx
        ret
        
        
        
        





;----------------------------------------------------------
; flush_guest_state()
; input:
;       none
; output:
;       none
; ������
;       1) �� VMCS buffer �е� Guest State ��Ϣˢ�µ���ǰ Vmcs ��
;----------------------------------------------------------        
flush_guest_state:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
        mov ebx, ebp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
        mov ebx, ebp
%endif
        add ebp, PCB.GuestStateBuf
                
        ;;
        ;; control register, rsp/rip/rflags
        ;;
        DoVmWrite GUEST_CR0, [ebp + GUEST_STATE.Cr0]   
        DoVmWrite GUEST_CR3, [ebp + GUEST_STATE.Cr3]
        DoVmWrite GUEST_CR4, [ebp + GUEST_STATE.Cr4]
        DoVmWrite GUEST_DR7, [ebp + GUEST_STATE.Dr7]
        DoVmWrite GUEST_RSP, [ebp + GUEST_STATE.Rsp]
        DoVmWrite GUEST_RIP, [ebp + GUEST_STATE.Rip]
        DoVmWrite GUEST_RFLAGS, [ebp + GUEST_STATE.Rflags]
        
        ;;
        ;; segment register
        ;;
        DoVmWrite GUEST_CS_SELECTOR, [ebp + GUEST_STATE.CsSelector]
        DoVmWrite GUEST_SS_SELECTOR, [ebp + GUEST_STATE.SsSelector]
        DoVmWrite GUEST_DS_SELECTOR, [ebp + GUEST_STATE.DsSelector]
        DoVmWrite GUEST_ES_SELECTOR, [ebp + GUEST_STATE.EsSelector]
        DoVmWrite GUEST_FS_SELECTOR, [ebp + GUEST_STATE.FsSelector]
        DoVmWrite GUEST_GS_SELECTOR, [ebp + GUEST_STATE.GsSelector]
        DoVmWrite GUEST_LDTR_SELECTOR, [ebp + GUEST_STATE.LdtrSelector]
        DoVmWrite GUEST_TR_SELECTOR, [ebp + GUEST_STATE.TrSelector]

        DoVmWrite GUEST_CS_BASE, [ebp + GUEST_STATE.CsBase]
        DoVmWrite GUEST_SS_BASE, [ebp + GUEST_STATE.SsBase]
        DoVmWrite GUEST_DS_BASE, [ebp + GUEST_STATE.DsBase]
        DoVmWrite GUEST_ES_BASE, [ebp + GUEST_STATE.EsBase]
        DoVmWrite GUEST_FS_BASE, [ebp + GUEST_STATE.FsBase]
        DoVmWrite GUEST_GS_BASE, [ebp + GUEST_STATE.GsBase]
        DoVmWrite GUEST_LDTR_BASE, [ebp + GUEST_STATE.LdtrBase]
        DoVmWrite GUEST_TR_BASE, [ebp + GUEST_STATE.TrBase]        
                
        DoVmWrite GUEST_CS_LIMIT, [ebp + GUEST_STATE.CsLimit]    
        DoVmWrite GUEST_SS_LIMIT, [ebp + GUEST_STATE.SsLimit]
        DoVmWrite GUEST_DS_LIMIT, [ebp + GUEST_STATE.DsLimit]
        DoVmWrite GUEST_ES_LIMIT, [ebp + GUEST_STATE.EsLimit]
        DoVmWrite GUEST_FS_LIMIT, [ebp + GUEST_STATE.FsLimit]
        DoVmWrite GUEST_GS_LIMIT, [ebp + GUEST_STATE.GsLimit]
        DoVmWrite GUEST_LDTR_LIMIT, [ebp + GUEST_STATE.LdtrLimit]
        DoVmWrite GUEST_TR_LIMIT, [ebp + GUEST_STATE.TrLimit]

        DoVmWrite GUEST_CS_ACCESS_RIGHTS, [ebp + GUEST_STATE.CsAccessRight]
        DoVmWrite GUEST_SS_ACCESS_RIGHTS, [ebp + GUEST_STATE.SsAccessRight]
        DoVmWrite GUEST_DS_ACCESS_RIGHTS, [ebp + GUEST_STATE.DsAccessRight]
        DoVmWrite GUEST_ES_ACCESS_RIGHTS, [ebp + GUEST_STATE.EsAccessRight]
        DoVmWrite GUEST_FS_ACCESS_RIGHTS, [ebp + GUEST_STATE.FsAccessRight]
        DoVmWrite GUEST_GS_ACCESS_RIGHTS, [ebp + GUEST_STATE.GsAccessRight]
        DoVmWrite GUEST_LDTR_ACCESS_RIGHTS, [ebp + GUEST_STATE.LdtrAccessRight]
        DoVmWrite GUEST_TR_ACCESS_RIGHTS, [ebp + GUEST_STATE.TrAccessRight]        
        
        ;;
        ;; GDTR/IDTR base & limit
        ;;
        DoVmWrite GUEST_GDTR_BASE, [ebp + GUEST_STATE.GdtrBase]
        DoVmWrite GUEST_IDTR_BASE, [ebp + GUEST_STATE.IdtrBase]
        DoVmWrite GUEST_GDTR_LIMIT, [ebp + GUEST_STATE.GdtrLimit]
        DoVmWrite GUEST_IDTR_LIMIT, [ebp + GUEST_STATE.IdtrLimit]
        
        ;;
        ;; MSR
        ;;               
        DoVmWrite GUEST_IA32_SYSENTER_CS, [ebp + GUEST_STATE.SysenterCsMsr]
        DoVmWrite GUEST_IA32_SYSENTER_ESP, [ebp + GUEST_STATE.SysenterEspMsr]
        DoVmWrite GUEST_IA32_SYSENTER_EIP, [ebp + GUEST_STATE.SysenterEipMsr]
              
        DoVmWrite GUEST_IA32_DEBUGCTL_FULL, [ebp + GUEST_STATE.DebugCtlMsr]           
        DoVmWrite GUEST_IA32_PERF_GLOBAL_CTRL_FULL, [ebp + GUEST_STATE.PerfGlobalCtlMsr]        
        DoVmWrite GUEST_IA32_PAT_FULL, [ebp + GUEST_STATE.PatMsr] 
        DoVmWrite GUEST_IA32_EFER_FULL, [ebp + GUEST_STATE.EferMsr]
        
%ifndef __X64        
        DoVmWrite GUEST_IA32_DEBUGCTL_HIGH, [ebp + GUEST_STATE.DebugCtlMsr + 4]
        DoVmWrite GUEST_IA32_PERF_GLOBAL_CTRL_HIGH, [ebp + GUEST_STATE.PerfGlobalCtlMsr + 4]
        DoVmWrite GUEST_IA32_PAT_HIGH, [ebp + GUEST_STATE.PatMsr + 4]
        DoVmWrite GUEST_IA32_EFER_HIGH, [ebp + GUEST_STATE.EferMsr + 4]
%endif         
       

        ;;
        ;; SMBASE
        ;;
        DoVmWrite GUEST_SMBASE, [ebp + GUEST_STATE.SmBase]
        
        
        ;;
        ;; ### guest non-register state ###
        ;; 1) activity state
        ;; 2) interruptibility state
        ;; 3) pending debug exception
        ;; 4) vmcs link pointer
        ;; 5) VMX preemption timer value
        ;; 6) PDPTEs
        ;; 7) guest interrupt status��RVI/SVI��
        ;;
        DoVmWrite GUEST_ACTIVITY_STATE, [ebp + GUEST_STATE.ActivityState]
        DoVmWrite GUEST_INTERRUPTIBILITY_STATE, [ebp + GUEST_STATE.InterruptibilityState]
        DoVmWrite GUEST_PENDING_DEBUG_EXCEPTION, [ebp + GUEST_STATE.PendingDebugException]
        DoVmWrite GUEST_VMCS_LINK_POINTER_FULL, [ebp + GUEST_STATE.VmcsLinkPointer]
%ifndef __X64
        DoVmWrite GUEST_VMCS_LINK_POINTER_HIGH, [ebp + GUEST_STATE.VmcsLinkPointer + 4]
%endif  
        ;;
        ;; ����Ƿ�֧�� VM-execution control �� "activate VMX-preemption timer" ����Ϊ 1 
        ;;  
        test DWORD [ebx + PCB.PinBasedCtls + 4], ACTIVATE_VMX_PREEMPTION_TIMER
        jz flush_guest_state.@1
        ;;
        ;; д�� preemption timer value
        ;;
        DoVmWrite GUEST_VMX_PREEMPTION_TIMER_VALUE, [ebp + GUEST_STATE.VmxPreemptionTimerValue]

flush_guest_state.@1:      
        ;;
        ;; ����Ƿ�֧�� EPT
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], ENABLE_EPT
        jz flush_guest_state.@2
        
        ;;
        ;; ֧��ʱд�� PDPTEs
        ;;
        DoVmWrite GUEST_PDPTE0_FULL, [ebp + GUEST_STATE.Pdpte0]
        DoVmWrite GUEST_PDPTE1_FULL, [ebp + GUEST_STATE.Pdpte1]
        DoVmWrite GUEST_PDPTE2_FULL, [ebp + GUEST_STATE.Pdpte2]
        DoVmWrite GUEST_PDPTE3_FULL, [ebp + GUEST_STATE.Pdpte3]

%ifndef __X64
        DoVmWrite GUEST_PDPTE0_HIGH, [ebp + GUEST_STATE.Pdpte0 + 4]
        DoVmWrite GUEST_PDPTE1_HIGH, [ebp + GUEST_STATE.Pdpte1 + 4]
        DoVmWrite GUEST_PDPTE2_HIGH, [ebp + GUEST_STATE.Pdpte2 + 4]
        DoVmWrite GUEST_PDPTE3_HIGH, [ebp + GUEST_STATE.Pdpte3 + 4]
%endif        
        
flush_guest_state.@2:                
        ;;
        ;; ����Ƿ�֧�� virtual-interrupt delivery
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], VIRTUAL_INTERRUPT_DELIVERY
        jz flush_guest_state.done
        ;;
        ;; ֧��ʱд�� guest interrupt status
        ;;
        DoVmWrite GUEST_INTERRUPT_STATUS, [ebp + GUEST_STATE.GuestInterruptStatus]
        
flush_guest_state.done:        
        pop ebx
        pop ebp        
        ret        
        

;----------------------------------------------------------
; store_guest_state()
; input:
;       none
; output:
;       none
; ������
;       1) ����ǰ VMCS �е� Guest State ��Ϣ������ guest state buffer ��
;----------------------------------------------------------        
store_guest_state:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
        mov ebx, ebp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
        mov ebx, ebp
%endif
        add ebp, PCB.GuestStateBuf
                
        ;;
        ;; control register, rsp/rip/rflags
        ;;
        DoVmRead GUEST_CR0, [ebp + GUEST_STATE.Cr0]   
        DoVmRead GUEST_CR3, [ebp + GUEST_STATE.Cr3]
        DoVmRead GUEST_CR4, [ebp + GUEST_STATE.Cr4]
        DoVmRead GUEST_DR7, [ebp + GUEST_STATE.Dr7]
        DoVmRead GUEST_RSP, [ebp + GUEST_STATE.Rsp]
        DoVmRead GUEST_RIP, [ebp + GUEST_STATE.Rip]
        DoVmRead GUEST_RFLAGS, [ebp + GUEST_STATE.Rflags]
        
        ;;
        ;; segment register
        ;;
        DoVmRead GUEST_CS_SELECTOR, [ebp + GUEST_STATE.CsSelector]
        DoVmRead GUEST_SS_SELECTOR, [ebp + GUEST_STATE.SsSelector]
        DoVmRead GUEST_DS_SELECTOR, [ebp + GUEST_STATE.DsSelector]
        DoVmRead GUEST_ES_SELECTOR, [ebp + GUEST_STATE.EsSelector]
        DoVmRead GUEST_FS_SELECTOR, [ebp + GUEST_STATE.FsSelector]
        DoVmRead GUEST_GS_SELECTOR, [ebp + GUEST_STATE.GsSelector]
        DoVmRead GUEST_LDTR_SELECTOR, [ebp + GUEST_STATE.LdtrSelector]
        DoVmRead GUEST_TR_SELECTOR, [ebp + GUEST_STATE.TrSelector]

        DoVmRead GUEST_CS_BASE, [ebp + GUEST_STATE.CsBase]
        DoVmRead GUEST_SS_BASE, [ebp + GUEST_STATE.SsBase]
        DoVmRead GUEST_DS_BASE, [ebp + GUEST_STATE.DsBase]
        DoVmRead GUEST_ES_BASE, [ebp + GUEST_STATE.EsBase]
        DoVmRead GUEST_FS_BASE, [ebp + GUEST_STATE.FsBase]
        DoVmRead GUEST_GS_BASE, [ebp + GUEST_STATE.GsBase]
        DoVmRead GUEST_LDTR_BASE, [ebp + GUEST_STATE.LdtrBase]
        DoVmRead GUEST_TR_BASE, [ebp + GUEST_STATE.TrBase]
                
        DoVmRead GUEST_CS_LIMIT, [ebp + GUEST_STATE.CsLimit]     
        DoVmRead GUEST_SS_LIMIT, [ebp + GUEST_STATE.SsLimit]
        DoVmRead GUEST_DS_LIMIT, [ebp + GUEST_STATE.DsLimit]
        DoVmRead GUEST_ES_LIMIT, [ebp + GUEST_STATE.EsLimit]
        DoVmRead GUEST_FS_LIMIT, [ebp + GUEST_STATE.FsLimit]
        DoVmRead GUEST_GS_LIMIT, [ebp + GUEST_STATE.GsLimit]
        DoVmRead GUEST_LDTR_LIMIT, [ebp + GUEST_STATE.LdtrLimit]
        DoVmRead GUEST_TR_LIMIT, [ebp + GUEST_STATE.TrLimit]

        DoVmRead GUEST_CS_ACCESS_RIGHTS, [ebp + GUEST_STATE.CsAccessRight]
        DoVmRead GUEST_SS_ACCESS_RIGHTS, [ebp + GUEST_STATE.SsAccessRight]
        DoVmRead GUEST_DS_ACCESS_RIGHTS, [ebp + GUEST_STATE.DsAccessRight]
        DoVmRead GUEST_ES_ACCESS_RIGHTS, [ebp + GUEST_STATE.EsAccessRight]
        DoVmRead GUEST_FS_ACCESS_RIGHTS, [ebp + GUEST_STATE.FsAccessRight]
        DoVmRead GUEST_GS_ACCESS_RIGHTS, [ebp + GUEST_STATE.GsAccessRight]
        DoVmRead GUEST_LDTR_ACCESS_RIGHTS, [ebp + GUEST_STATE.LdtrAccessRight]
        DoVmRead GUEST_TR_ACCESS_RIGHTS, [ebp + GUEST_STATE.TrAccessRight]        
        
        ;;
        ;; GDTR/IDTR base & limit
        ;;
        DoVmRead GUEST_GDTR_BASE, [ebp + GUEST_STATE.GdtrBase]
        DoVmRead GUEST_IDTR_BASE, [ebp + GUEST_STATE.IdtrBase]
        DoVmRead GUEST_GDTR_LIMIT, [ebp + GUEST_STATE.GdtrLimit]
        DoVmRead GUEST_IDTR_LIMIT, [ebp + GUEST_STATE.IdtrLimit]
        
        ;;
        ;; MSR
        ;;
        DoVmRead GUEST_IA32_DEBUGCTL_FULL, [ebp + GUEST_STATE.DebugCtlMsr]                
        DoVmRead GUEST_IA32_SYSENTER_CS, [ebp + GUEST_STATE.SysenterCsMsr]
        DoVmRead GUEST_IA32_SYSENTER_ESP, [ebp + GUEST_STATE.SysenterEspMsr]
        DoVmRead GUEST_IA32_SYSENTER_EIP, [ebp + GUEST_STATE.SysenterEipMsr]        
        DoVmRead GUEST_IA32_PERF_GLOBAL_CTRL_FULL, [ebp + GUEST_STATE.PerfGlobalCtlMsr]        
        DoVmRead GUEST_IA32_PAT_FULL, [ebp + GUEST_STATE.PatMsr] 
        DoVmRead GUEST_IA32_EFER_FULL, [ebp + GUEST_STATE.EferMsr]
        
%ifndef __X64        
        DoVmRead GUEST_IA32_DEBUGCTL_HIGH, [ebp + GUEST_STATE.DebugCtlMsr + 4]
        DoVmRead GUEST_IA32_PERF_GLOBAL_CTRL_HIGH, [ebp + GUEST_STATE.PerfGlobalCtlMsr + 4]
        DoVmRead GUEST_IA32_PAT_HIGH, [ebp + GUEST_STATE.PatMsr + 4]
        DoVmRead GUEST_IA32_EFER_HIGH, [ebp + GUEST_STATE.EferMsr + 4]
%endif         
       

        ;;
        ;; SMBASE
        ;;
        DoVmRead GUEST_SMBASE, [ebp + GUEST_STATE.SmBase]
        
        
        ;;
        ;; ### guest non-register state ###
        ;; 1) activity state
        ;; 2) interruptibility state
        ;; 3) pending debug exception
        ;; 4) vmcs link pointer
        ;; 5) VMX preemption timer value
        ;; 6) PDPTEs
        ;; 7) guest interrupt status��RVI/SVI��
        ;;
        DoVmRead GUEST_ACTIVITY_STATE, [ebp + GUEST_STATE.ActivityState]
        DoVmRead GUEST_INTERRUPTIBILITY_STATE, [ebp + GUEST_STATE.InterruptibilityState]
        DoVmRead GUEST_PENDING_DEBUG_EXCEPTION, [ebp + GUEST_STATE.PendingDebugException]
        DoVmRead GUEST_VMCS_LINK_POINTER_FULL, [ebp + GUEST_STATE.VmcsLinkPointer]
%ifndef __X64
        DoVmRead GUEST_VMCS_LINK_POINTER_HIGH, [ebp + GUEST_STATE.VmcsLinkPointer + 4]
%endif  
        ;;
        ;; ����Ƿ�֧�� VM-execution control �� "activate VMX-preemption timer" ����Ϊ 1 
        ;;  
        test DWORD [ebx + PCB.PinBasedCtls + 4], ACTIVATE_VMX_PREEMPTION_TIMER
        jz store_guest_state.@1        
        ;;
        ;; ��ȡ preemption timer value
        ;;
        DoVmRead GUEST_VMX_PREEMPTION_TIMER_VALUE, [ebp + GUEST_STATE.VmxPreemptionTimerValue]

store_guest_state.@1:      
        ;;
        ;; ����Ƿ�֧�� EPT
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], ENABLE_EPT
        jz store_guest_state.@2
        
        ;;
        ;; ֧��ʱ��ȡ PDPTEs
        ;;
        DoVmRead GUEST_PDPTE0_FULL, [ebp + GUEST_STATE.Pdpte0]
        DoVmRead GUEST_PDPTE1_FULL, [ebp + GUEST_STATE.Pdpte1]
        DoVmRead GUEST_PDPTE2_FULL, [ebp + GUEST_STATE.Pdpte2]
        DoVmRead GUEST_PDPTE3_FULL, [ebp + GUEST_STATE.Pdpte3]

%ifndef __X64
        DoVmRead GUEST_PDPTE0_HIGH, [ebp + GUEST_STATE.Pdpte0 + 4]
        DoVmRead GUEST_PDPTE1_HIGH, [ebp + GUEST_STATE.Pdpte1 + 4]
        DoVmRead GUEST_PDPTE2_HIGH, [ebp + GUEST_STATE.Pdpte2 + 4]
        DoVmRead GUEST_PDPTE3_HIGH, [ebp + GUEST_STATE.Pdpte3 + 4]
%endif        
        
store_guest_state.@2:                
        ;;
        ;; ����Ƿ�֧�� virtual-interrupt delivery
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], VIRTUAL_INTERRUPT_DELIVERY
        jz store_guest_state.done
        ;;
        ;; ֧��ʱ��ȡ guest interrupt status
        ;;
        DoVmRead GUEST_INTERRUPT_STATUS, [ebp + GUEST_STATE.GuestInterruptStatus]
        
store_guest_state.done:  
        pop ebx      
        pop ebp        
        ret            
        

;----------------------------------------------------------
; flush_host_state()
; input:
;       none
; output:
;       none
; ������
;       1) �� VMCS buffer �е� Host State ��Ϣˢ�µ���ǰ Vmcs ��
;----------------------------------------------------------  
flush_host_state:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif
        add ebp, PCB.HostStateBuf
        
        ;;
        ;; control register, rsp/rip
        ;;
        DoVmWrite HOST_CR0, [ebp + HOST_STATE.Cr0]   
        DoVmWrite HOST_CR3, [ebp + HOST_STATE.Cr3]
        DoVmWrite HOST_CR4, [ebp + HOST_STATE.Cr4]
        DoVmWrite HOST_RSP, [ebp + HOST_STATE.Rsp]
        DoVmWrite HOST_RIP, [ebp + HOST_STATE.Rip]

        ;;
        ;; segment register
        ;;
        DoVmWrite HOST_CS_SELECTOR, [ebp + HOST_STATE.CsSelector]
        DoVmWrite HOST_SS_SELECTOR, [ebp + HOST_STATE.SsSelector]
        DoVmWrite HOST_DS_SELECTOR, [ebp + HOST_STATE.DsSelector]
        DoVmWrite HOST_ES_SELECTOR, [ebp + HOST_STATE.EsSelector]
        DoVmWrite HOST_FS_SELECTOR, [ebp + HOST_STATE.FsSelector]
        DoVmWrite HOST_GS_SELECTOR, [ebp + HOST_STATE.GsSelector]
        DoVmWrite HOST_TR_SELECTOR, [ebp + HOST_STATE.TrSelector]

        DoVmWrite HOST_FS_BASE, [ebp + HOST_STATE.FsBase]
        DoVmWrite HOST_GS_BASE, [ebp + HOST_STATE.GsBase]
        DoVmWrite HOST_TR_BASE, [ebp + HOST_STATE.TrBase]
        DoVmWrite HOST_GDTR_BASE, [ebp + HOST_STATE.GdtrBase]
        DoVmWrite HOST_IDTR_BASE, [ebp + HOST_STATE.IdtrBase]          
        
        ;;
        ;; MSR
        ;;            
        DoVmWrite HOST_IA32_SYSENTER_CS, [ebp + HOST_STATE.SysenterCsMsr]
        DoVmWrite HOST_IA32_SYSENTER_ESP, [ebp + HOST_STATE.SysenterEspMsr]
        DoVmWrite HOST_IA32_SYSENTER_EIP, [ebp + HOST_STATE.SysenterEipMsr]        
        DoVmWrite HOST_IA32_PERF_GLOBAL_CTRL_FULL, [ebp + HOST_STATE.PerfGlobalCtlMsr]        
        DoVmWrite HOST_IA32_PAT_FULL, [ebp + HOST_STATE.PatMsr] 
        DoVmWrite HOST_IA32_EFER_FULL, [ebp + HOST_STATE.EferMsr]
        
%ifndef __X64        
        DoVmWrite HOST_IA32_PERF_GLOBAL_CTRL_HIGH, [ebp + HOST_STATE.PerfGlobalCtlMsr + 4]
        DoVmWrite HOST_IA32_PAT_HIGH, [ebp + HOST_STATE.PatMsr + 4]
        DoVmWrite HOST_IA32_EFER_HIGH, [ebp + HOST_STATE.EferMsr + 4]
%endif            
                
        pop ebp
        ret 
        
        
        
;----------------------------------------------------------
; store_host_state()
; input:
;       none
; output:
;       none
; ������
;       1) �� VMCS �е� Host State ��Ϣ���浽 host state buffer ��
;----------------------------------------------------------  
store_host_state:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif
        add ebp, PCB.HostStateBuf
        
        ;;
        ;; control register, rsp/rip
        ;;
        DoVmRead HOST_CR0, [ebp + HOST_STATE.Cr0]   
        DoVmRead HOST_CR3, [ebp + HOST_STATE.Cr3]
        DoVmRead HOST_CR4, [ebp + HOST_STATE.Cr4]
        DoVmRead HOST_RSP, [ebp + HOST_STATE.Rsp]
        DoVmRead HOST_RIP, [ebp + HOST_STATE.Rip]

        ;;
        ;; segment register
        ;;
        DoVmRead HOST_CS_SELECTOR, [ebp + HOST_STATE.CsSelector]
        DoVmRead HOST_SS_SELECTOR, [ebp + HOST_STATE.SsSelector]
        DoVmRead HOST_DS_SELECTOR, [ebp + HOST_STATE.DsSelector]
        DoVmRead HOST_ES_SELECTOR, [ebp + HOST_STATE.EsSelector]
        DoVmRead HOST_FS_SELECTOR, [ebp + HOST_STATE.FsSelector]
        DoVmRead HOST_GS_SELECTOR, [ebp + HOST_STATE.GsSelector]
        DoVmRead HOST_TR_SELECTOR, [ebp + HOST_STATE.TrSelector]

        DoVmRead HOST_FS_BASE, [ebp + HOST_STATE.FsBase]
        DoVmRead HOST_GS_BASE, [ebp + HOST_STATE.GsBase]
        DoVmRead HOST_TR_BASE, [ebp + HOST_STATE.TrBase]
        DoVmRead HOST_GDTR_BASE, [ebp + HOST_STATE.GdtrBase]
        DoVmRead HOST_IDTR_BASE, [ebp + HOST_STATE.IdtrBase]          
        
        ;;
        ;; MSR
        ;;            
        DoVmRead HOST_IA32_SYSENTER_CS, [ebp + HOST_STATE.SysenterCsMsr]
        DoVmRead HOST_IA32_SYSENTER_ESP, [ebp + HOST_STATE.SysenterEspMsr]
        DoVmRead HOST_IA32_SYSENTER_EIP, [ebp + HOST_STATE.SysenterEipMsr]        
        DoVmRead HOST_IA32_PERF_GLOBAL_CTRL_FULL, [ebp + HOST_STATE.PerfGlobalCtlMsr]        
        DoVmRead HOST_IA32_PAT_FULL, [ebp + HOST_STATE.PatMsr] 
        DoVmRead HOST_IA32_EFER_FULL, [ebp + HOST_STATE.EferMsr]
        
%ifndef __X64        
        DoVmRead HOST_IA32_PERF_GLOBAL_CTRL_HIGH, [ebp + HOST_STATE.PerfGlobalCtlMsr + 4]
        DoVmRead HOST_IA32_PAT_HIGH, [ebp + HOST_STATE.PatMsr + 4]
        DoVmRead HOST_IA32_EFER_HIGH, [ebp + HOST_STATE.EferMsr + 4]
%endif            
                
        pop ebp
        ret 
            
            

;----------------------------------------------------------
; flush_execution_control()
; input:
;       none
; output:
;       none
; ������
;       1) �� execution control buffer ˢ�µ� VMCS ��
;----------------------------------------------------------              
flush_execution_control:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif  
        add ebp, PCB.ExecutionControlBuf
        
        
        ;;
        ;; д������� execution control ��ÿ����̶�Ϊ 32 λ��
        ;;
        DoVmWrite CONTROL_PINBASED, [ebp + EXECUTION_CONTROL.PinControl]
        DoVmWrite CONTROL_PROCBASED_PRIMARY, [ebp + EXECUTION_CONTROL.ProcessorControl1]
        DoVmWrite CONTROL_PROCBASED_SECONDARY, [ebp + EXECUTION_CONTROL.ProcessorControl2]
        
        
        ;;
        ;; д�� exception bitmap �� #PF �쳣�� mask/match ֵ���̶�Ϊ 32 λ��
        ;;
        DoVmWrite CONTROL_EXCEPTION_BITMAP, [ebp + EXECUTION_CONTROL.ExceptionBitmap]
        DoVmWrite CONTROL_PAGE_FAULT_ERROR_CODE_MASK, [ebp + EXECUTION_CONTROL.PfErrorCodeMask]
        DoVmWrite CONTROL_PAGE_FAULT_ERROR_CODE_MATCH, [ebp + EXECUTION_CONTROL.PfErrorCodeMatch]
        
        
        ;;
        ;; д�� IoBitmap A & B ��ֵַ�������ַ��
        ;; 1) �ڿ��� "Use I/O bitmap" ʱд�룬������ԣ�
        ;; 
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl1], USE_IO_BITMAP
        jz flush_execution_control.@1
        
        ;;
        ;; ��ֵַ�̶�Ϊ 64 λ���� x86 �·�����д��
        ;;
        DoVmWrite CONTROL_IOBITMAPA_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.IoBitmapAddressA]
        DoVmWrite CONTROL_IOBITMAPB_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.IoBitmapAddressB]
        
%ifndef __X64
        DoVmWrite CONTROL_IOBITMAPA_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.IoBitmapAddressA + 4]
        DoVmWrite CONTROL_IOBITMAPB_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.IoBitmapAddressB + 4]        
%endif        



flush_execution_control.@1:        
        ;;
        ;; д�� time-stamp counter offset ֵ
        ;; 1) �� "Use TSC offsetting" = 1 ʱд�룬�������
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl1], USE_TSC_OFFSETTING
        jz flush_execution_control.@2
        
        ;;
        ;; TSC offset ֵΪ 64 λ���� x86 �·�����д��
        ;;
        DoVmWrite CONTROL_TSC_OFFSET_FULL, [ebp + EXECUTION_CONTROL.TscOffset]        
%ifndef __X64
        DoVmWrite CONTROL_TSC_OFFSET_HIGH, [ebp + EXECUTION_CONTROL.TscOffset + 4]
%endif        


flush_execution_control.@2:
        ;;
        ;; д�� CR0/CR4 guest/host mask �� shadow ֵ
        ;;
        DoVmWrite CONTROL_CR0_GUEST_HOST_MASK, [ebp + EXECUTION_CONTROL.Cr0GuestHostMask]
        DoVmWrite CONTROL_CR0_READ_SHADOW, [ebp + EXECUTION_CONTROL.Cr0ReadShadow]
        DoVmWrite CONTROL_CR4_GUEST_HOST_MASK, [ebp + EXECUTION_CONTROL.Cr4GuestHostMask]
        DoVmWrite CONTROL_CR4_READ_SHADOW, [ebp + EXECUTION_CONTROL.Cr4ReadShadow]
        
        ;;
        ;; д�� CR3 target count/value
        ;;                
        DoVmWrite CONTROL_CR3_TARGET_COUNT, [ebp + EXECUTION_CONTROL.Cr3TargetCount]
        DoVmWrite CONTROL_CR3_TARGET_VALUE0, [ebp + EXECUTION_CONTROL.Cr3Target0]
        DoVmWrite CONTROL_CR3_TARGET_VALUE1, [ebp + EXECUTION_CONTROL.Cr3Target1]
        DoVmWrite CONTROL_CR3_TARGET_VALUE2, [ebp + EXECUTION_CONTROL.Cr3Target2]
        DoVmWrite CONTROL_CR3_TARGET_VALUE3, [ebp + EXECUTION_CONTROL.Cr3Target3]
           
        ;;
        ;; ���� APIC virutalization ���ֵ
        ;; 1) APIC-access address �ڿ��� "virtualize APIC access" ʱд��
        ;; 2) virutal-APIC address �ڿ��� "use TPR shadow" 1-setting ʱд��
        ;; 3) TPR threshold �ڿ��� "use TPR shadow" ʱд��
        ;; 4) EOI-exit bitmap �ڿ��� "virutal-interrupt delivery" ʱд��
        ;; 5) posted-interrupt notification vector �ڿ��� "process posted interrupt" ʱд��
        ;; 6) posted-interrupt descriptor address �ڿ��� "process posted interrupt" ʱд��
        ;;           
        
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl2], VIRTUALIZE_APIC_ACCESS
        jz flush_execution_control.@3
        
        ;;
        ;; APIC-access address ֵΪ 64 λ���� x86 �·�����д��
        ;;
        DoVmWrite CONTROL_APIC_ACCESS_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.ApicAccessAddress]
%ifndef __X64
        DoVmWrite CONTROL_APIC_ACCESS_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.ApicAccessAddress + 4]
%endif
        
        
flush_execution_control.@3:
        ;;
        ;; ����Ƿ��� "Use TPR shadow"
        ;; 
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl1], USE_TPR_SHADOW
        jz flush_execution_control.@4
        
        ;;
        ;; Virtual-APIC address Ϊ 64 λ���� x86 �·�����д��
        ;;
        DoVmWrite CONTROL_VIRTUAL_APIC_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.VirtualApicAddress]
%ifndef __X64
        DoVmWrite CONTROL_VIRTUAL_APIC_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.VirtualApicAddress + 4]
%endif
        
        DoVmWrite CONTROL_TPR_THRESHOLD, [ebp + EXECUTION_CONTROL.TprThreshold]
                
                
flush_execution_control.@4:        
        ;;
        ;; ����Ƿ��� "virtual-interrupt delivery" ����
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl2], VIRTUAL_INTERRUPT_DELIVERY
        jz flush_execution_control@5

        ;;
        ;; EOI bitmap Ϊ 64 λ���� x86 �·�����д��
        ;; 1) EOI bitmap 0 ��Ӧ 0 - 63 �� vector
        ;; 2) EOI bitmap 1 ��Ӧ 64 - 127 �� vector
        ;; 3) EOI bitmap 2 ��Ӧ 128 - 191 �� vector
        ;; 4) EOI bitmap 3 ��Ӧ 192 - 255 �� vector
        ;;
        DoVmWrite CONTROL_EOIEXIT_BITMAP0_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap0]
        DoVmWrite CONTROL_EOIEXIT_BITMAP1_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap1]
        DoVmWrite CONTROL_EOIEXIT_BITMAP2_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap2]
        DoVmWrite CONTROL_EOIEXIT_BITMAP3_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap3]
        
%ifndef __X64
        DoVmWrite CONTROL_EOIEXIT_BITMAP0_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap0 + 4]
        DoVmWrite CONTROL_EOIEXIT_BITMAP1_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap1 + 4]
        DoVmWrite CONTROL_EOIEXIT_BITMAP2_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap2 + 4]
        DoVmWrite CONTROL_EOIEXIT_BITMAP3_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap3 + 4]        
%endif


flush_execution_control@5:
        ;;
        ;; ����Ƿ��� "process posted interrupt" ����
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.PinControl], PROCESS_POSTED_INTERRUPT
        jz flush_execution_control.@6
        
        ;;
        ;; vector ֵΪ 16 λ��descriptor address ֵΪ 64 λ
        ;;
        DoVmWrite CONTROL_POSTED_INTERRUPT_NOTIFICATION_VECTOR, [ebp + EXECUTION_CONTROL.PostedInterruptVector]
        DoVmWrite CONTROL_POSTED_INTERRUPT_DESCRIPTOR_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.PostedInterruptDescriptorAddr]
%ifndef __X64
        DoVmWrite CONTROL_POSTED_INTERRUPT_DESCRIPTOR_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.PostedInterruptDescriptorAddr + 4]
%endif
        
flush_execution_control.@6:               
        ;;
        ;; MSR bitmap address �ڿ��� "use MSR bitmap" ʱд��
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl1], USE_MSR_BITMAP
        jz flush_execution_control.@7
        
        ;;
        ;; MSR bitmap Ϊ 64 λֵ
        ;;
        DoVmWrite CONTROL_MSR_BITMAP_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.MsrBitmapAddress]        
%ifndef __X64
        DoVmWrite CONTROL_MSR_BITMAP_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.MsrBitmapAddress + 4]
%endif        
                
                
flush_execution_control.@7:
        ;;
        ;; д�� executive-VMCS pointer ֵ (64 λ��
        ;;
        DoVmWrite CONTROL_EXECUTIVE_VMCS_POINTER_FULL, [ebp + EXECUTION_CONTROL.ExecutiveVmcsPointer]
%ifndef __X64
        DoVmWrite CONTROL_EXECUTIVE_VMCS_POINTER_HIGH, [ebp + EXECUTION_CONTROL.ExecutiveVmcsPointer + 4]
%endif         

        ;;
        ;; д�� extended-page table pointer ֵ
        ;; 1) �ڿ��� "enable EPT" ʱд��
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl2], ENABLE_EPT
        jz flush_execution_control.@8
        
        ;;
        ;; EPTP ֵΪ 64 λ
        ;;
        DoVmWrite CONTROL_EPT_POINTER_FULL, [ebp + EXECUTION_CONTROL.EptPointer]
%ifndef __X64
        DoVmWrite CONTROL_EPT_POINTER_HIGH, [ebp + EXECUTION_CONTROL.EptPointer + 4]
%endif         


flush_execution_control.@8:
        ;;
        ;; д�� virtual-processor indentifiler ֵ
        ;; 1) ���� "enable VPID" ʱд��
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl2], ENABLE_VPID
        jz flush_execution_control.@9
        
        DoVmWrite CONTROL_VPID, [ebp + EXECUTION_CONTROL.Vpid]
        
        
flush_execution_control.@9:        
        ;;
        ;; PLE_CAP �� PLE_WINDOW �ڿ��� "PAUSE-loop exitting" ʱд��
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl2], PAUSE_LOOP_EXITING
        jz flush_execution_control.@10
        
        DoVmWrite CONTROL_PLE_GAP, [ebp + EXECUTION_CONTROL.PleGap]
        DoVmWrite CONTROL_PLE_WINDOW, [ebp + EXECUTION_CONTROL.PleWindow]
                
                
flush_execution_control.@10:
        ;;
        ;; VM-function �ڿ��� "enable VM functions" ʱд��
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.ProcessorControl2], ENABLE_VM_FUNCTION
        jz flush_execution_control.done
        
        ;;
        ;; д�� 64 λ�� VM-function ������
        ;;
        DoVmWrite CONTROL_VM_FUNCTION_FULL, [ebp + EXECUTION_CONTROL.VmFunctionControl]
%ifndef __X64
        DoVmWrite CONTROL_VM_FUNCTION_HIGH, [ebp + EXECUTION_CONTROL.VmFunctionControl + 4]
%endif        
        
        ;;
        ;; EPTP list �ڿ��� "EPTP switching" ʱд��
        ;;
        test DWORD [ebp + EXECUTION_CONTROL.VmFunctionControl], EPTP_SWITCHING
        jz flush_execution_control.done
        
        ;;
        ;; 64 λ�� EPT list ��ֵַ
        ;;
        DoVmWrite CONTROL_EPTP_LIST_FULL, [ebp + EXECUTION_CONTROL.EptpListAddress]
%ifndef __X64
        DoVmWrite CONTROL_EPTP_LIST_HIGH, [ebp + EXECUTION_CONTROL.EptpListAddress + 4]
%endif
        
flush_execution_control.done:                
        pop ebp
        ret
        
        
        
;---------------------------------------------------------------------------
; store_execution_control()
; input:
;       none
; output:
;       none
; ������
;       1) �� VMCS �е� VM-execution control ������ execution control buffer ��
;---------------------------------------------------------------------------              
store_execution_control:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
        mov ebx, ebp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
        mov ebx, ebp
%endif  
        add ebp, PCB.ExecutionControlBuf
        
        
        ;;
        ;; ��������Ŀ�����
        ;;
        DoVmRead CONTROL_PINBASED, [ebp + EXECUTION_CONTROL.PinControl]
        DoVmRead CONTROL_PROCBASED_PRIMARY, [ebp + EXECUTION_CONTROL.ProcessorControl1]
        DoVmRead CONTROL_PROCBASED_SECONDARY, [ebp + EXECUTION_CONTROL.ProcessorControl2]
        
        ;;
        ;; exception bitmap & page-fault error-code mask/match
        ;;
        DoVmRead CONTROL_EXCEPTION_BITMAP, [ebp + EXECUTION_CONTROL.ExceptionBitmap]
        DoVmRead CONTROL_PAGE_FAULT_ERROR_CODE_MASK, [ebp + EXECUTION_CONTROL.PfErrorCodeMask]
        DoVmRead CONTROL_PAGE_FAULT_ERROR_CODE_MATCH, [ebp + EXECUTION_CONTROL.PfErrorCodeMatch]
        
        ;;
        ;; IoBitmap address A & B
        ;; 1) ��֧�� "Use I/O bitmap" 1-setting ʱ��ȡ
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls + 4], USE_IO_BITMAP
        jz store_execution_control.@1
        
        DoVmRead CONTROL_IOBITMAPA_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.IoBitmapAddressA]
        DoVmRead CONTROL_IOBITMAPB_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.IoBitmapAddressB]
%ifndef __X64
        DoVmRead CONTROL_IOBITMAPA_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.IoBitmapAddressA + 4]
        DoVmRead CONTROL_IOBITMAPB_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.IoBitmapAddressB + 4]        
%endif        



store_execution_control.@1:
        ;;
        ;; time-stamp counter offset
        ;; 1) ��֧�� "Use TSC offsetting" 1-setting ʱ��ȡ
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls + 4], USE_TSC_OFFSETTING
        jz store_execution_control.@2
        
        DoVmRead CONTROL_TSC_OFFSET_FULL, [ebp + EXECUTION_CONTROL.TscOffset]        
%ifndef __X64
        DoVmRead CONTROL_TSC_OFFSET_HIGH, [ebp + EXECUTION_CONTROL.TscOffset + 4]
%endif        


store_execution_control.@2:        
        ;;
        ;; CR0 & CR4 guest/host mask & shadow
        ;;
        DoVmRead CONTROL_CR0_GUEST_HOST_MASK, [ebp + EXECUTION_CONTROL.Cr0GuestHostMask]
        DoVmRead CONTROL_CR0_READ_SHADOW, [ebp + EXECUTION_CONTROL.Cr0ReadShadow]
        DoVmRead CONTROL_CR4_GUEST_HOST_MASK, [ebp + EXECUTION_CONTROL.Cr4GuestHostMask]
        DoVmRead CONTROL_CR4_READ_SHADOW, [ebp + EXECUTION_CONTROL.Cr4ReadShadow]
        
        ;;
        ;; CR3 target count/value
        ;;                
        DoVmRead CONTROL_CR3_TARGET_COUNT, [ebp + EXECUTION_CONTROL.Cr3TargetCount]
        DoVmRead CONTROL_CR3_TARGET_VALUE0, [ebp + EXECUTION_CONTROL.Cr3Target0]
        DoVmRead CONTROL_CR3_TARGET_VALUE1, [ebp + EXECUTION_CONTROL.Cr3Target1]
        DoVmRead CONTROL_CR3_TARGET_VALUE2, [ebp + EXECUTION_CONTROL.Cr3Target2]
        DoVmRead CONTROL_CR3_TARGET_VALUE3, [ebp + EXECUTION_CONTROL.Cr3Target3]
           
        ;;
        ;; APIC virutalization
        ;; 1) APIC-access address ����֧�� "virtualize APIC access" 1-setting ʱ��Ч
        ;; 2) virutal-APIC address ����֧�� "use TPR shadow" 1-setting ʱ��Ч
        ;; 3) TPR threshold ����֧�� "use TPR shadow" 1-setting ʱ��Ч
        ;; 4) EOI-exit bitmap ����֧�� "virutal-interrupt delivery" 1-setting ʱ��Ч
        ;; 5) posted-interrupt notification vector ����֧�� "process posted interrupt" 1-setting ʱ��Ч
        ;; 6) posted-interrupt descriptor address ����֧�� "process posted interrupt" 1-setting ʱ��Ч
        ;;           
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], VIRTUALIZE_APIC_ACCESS
        jz store_execution_control.@3
        
        DoVmRead CONTROL_APIC_ACCESS_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.ApicAccessAddress]
%ifndef __X64
        DoVmRead CONTROL_APIC_ACCESS_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.ApicAccessAddress + 4]
%endif
        
store_execution_control.@3:
        ;;
        ;; ����Ƿ�֧�� "use TPR shadow" 1-setting
        ;; 
        test DWORD [ebx + PCB.ProcessorBasedCtls + 4], USE_TPR_SHADOW
        jz store_execution_control.@4
        
        ;;
        ;; ��ȡ virtual-APIC address �� TPR threshold ֵ
        ;;
        DoVmRead CONTROL_VIRTUAL_APIC_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.VirtualApicAddress]
%ifndef __X64
        DoVmRead CONTROL_VIRTUAL_APIC_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.VirtualApicAddress + 4]
%endif
        DoVmRead CONTROL_TPR_THRESHOLD, [ebp + EXECUTION_CONTROL.TprThreshold]
                
                
store_execution_control.@4:        
        ;;
        ;; ����Ƿ�֧�� "virtual-interrupt delivery" 1-setting
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], VIRTUAL_INTERRUPT_DELIVERY
        jz store_execution_control@5

        DoVmRead CONTROL_EOIEXIT_BITMAP0_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap0]
        DoVmRead CONTROL_EOIEXIT_BITMAP1_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap1]
        DoVmRead CONTROL_EOIEXIT_BITMAP2_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap2]
        DoVmRead CONTROL_EOIEXIT_BITMAP3_FULL, [ebp + EXECUTION_CONTROL.EoiBitmap3]
        
%ifndef __X64
        DoVmRead CONTROL_EOIEXIT_BITMAP0_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap0 + 4]
        DoVmRead CONTROL_EOIEXIT_BITMAP1_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap1 + 4]
        DoVmRead CONTROL_EOIEXIT_BITMAP2_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap2 + 4]
        DoVmRead CONTROL_EOIEXIT_BITMAP3_HIGH, [ebp + EXECUTION_CONTROL.EoiBitmap3 + 4]        
%endif

store_execution_control@5:
        ;;
        ;; ����Ƿ�֧�� "process posted interrupt" 1-setting
        ;;
        test DWORD [ebx + PCB.PinBasedCtls + 4], PROCESS_POSTED_INTERRUPT
        jz store_execution_control.@6
        
        ;;
        ;; ��ȡ vector �� descriptor address
        ;;
        DoVmRead CONTROL_POSTED_INTERRUPT_NOTIFICATION_VECTOR, [ebp + EXECUTION_CONTROL.PostedInterruptVector]
        DoVmRead CONTROL_POSTED_INTERRUPT_DESCRIPTOR_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.PostedInterruptDescriptorAddr]
%ifndef __X64
        DoVmRead CONTROL_POSTED_INTERRUPT_DESCRIPTOR_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.PostedInterruptDescriptorAddr + 4]
%endif
        
        
store_execution_control.@6:   
        ;;
        ;; MSR bitmap address ����֧�� "use MSR bitmap" 1-setting ʱ��Ч
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls + 4], USE_MSR_BITMAP
        jz store_execution_control.@7
        
        DoVmRead CONTROL_MSR_BITMAP_ADDRESS_FULL, [ebp + EXECUTION_CONTROL.MsrBitmapAddress]
%ifndef __X64
        DoVmRead CONTROL_MSR_BITMAP_ADDRESS_HIGH, [ebp + EXECUTION_CONTROL.MsrBitmapAddress + 4]
%endif        
                
store_execution_control.@7:
        ;;
        ;; executive-VMCS pointer
        ;;
        DoVmRead CONTROL_EXECUTIVE_VMCS_POINTER_FULL, [ebp + EXECUTION_CONTROL.ExecutiveVmcsPointer]
%ifndef __X64
        DoVmRead CONTROL_EXECUTIVE_VMCS_POINTER_HIGH, [ebp + EXECUTION_CONTROL.ExecutiveVmcsPointer + 4]
%endif         

        ;;
        ;; extended-page table pointer ����֧�� "enable EPT" 1-setting ʱ��Ч
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], ENABLE_EPT
        jz store_execution_control.@8
        
        DoVmRead CONTROL_EPT_POINTER_FULL, [ebp + EXECUTION_CONTROL.EptPointer]
%ifndef __X64
        DoVmRead CONTROL_EPT_POINTER_HIGH, [ebp + EXECUTION_CONTROL.EptPointer + 4]
%endif         


store_execution_control.@8:        
        ;;
        ;; virtual-processor indentifiler ����֧�� "enable VPID" 1-setting ʱ��Ч
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], ENABLE_VPID
        jz store_execution_control.@9
        
        DoVmRead CONTROL_VPID, [ebp + EXECUTION_CONTROL.Vpid]
        
store_execution_control.@9:        
        ;;
        ;; PLE_CAP �� PLE_WINDOW ����֧�� "PAUSE-loop exitting" 1-setting ʱ��Ч
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], PAUSE_LOOP_EXITING
        jz store_execution_control.@10
        
        DoVmRead CONTROL_PLE_GAP, [ebp + EXECUTION_CONTROL.PleGap]
        DoVmRead CONTROL_PLE_WINDOW, [ebp + EXECUTION_CONTROL.PleWindow]
                
store_execution_control.@10:
        ;;
        ;; VM-function ����֧�� "enable VM functions" 1-setting ʱ��Ч
        ;;
        test DWORD [ebx + PCB.ProcessorBasedCtls2 + 4], ENABLE_VM_FUNCTION
        jz store_execution_control.done
        
        DoVmRead CONTROL_VM_FUNCTION_FULL, [ebp + EXECUTION_CONTROL.VmFunctionControl]
%ifndef __X64
        DoVmRead CONTROL_VM_FUNCTION_HIGH, [ebp + EXECUTION_CONTROL.VmFunctionControl + 4]
%endif        
        
        ;;
        ;; EPTP list ����֧�� "EPTP switching" 1-setting ʱ��Ч
        ;;
        test DWORD [ebx + PCB.VmFunction], EPTP_SWITCHING
        jz store_execution_control.done
        
        DoVmRead CONTROL_EPTP_LIST_FULL, [ebp + EXECUTION_CONTROL.EptpListAddress]
%ifndef __X64
        DoVmRead CONTROL_EPTP_LIST_HIGH, [ebp + EXECUTION_CONTROL.EptpListAddress + 4]
%endif
        
store_execution_control.done:                
        pop ebx
        pop ebp
        ret        
        
        
        
;----------------------------------------------------------
; flush_exit_control()
; input:
;       none
; output:
;       none
; ������
;       1) �� exit control buffer ˢ�µ� VMCS ��
;----------------------------------------------------------        
flush_exit_control:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif        
        add ebp, PCB.ExitControlBuf

        ;;
        ;; д�� VM exit control ��
        ;;
        DoVmWrite VMEXIT_CONTROL, [ebp + EXIT_CONTROL.VmExitControl]
        
        ;;
        ;; MSR store fields
        ;;
        DoVmWrite VMEXIT_MSR_STORE_COUNT, [ebp + EXIT_CONTROL.MsrStoreCount]
        DoVmWrite VMEXIT_MSR_STORE_ADDRESS_FULL, [ebp + EXIT_CONTROL.MsrStoreAddress]
%ifndef __X64
        DoVmWrite VMEXIT_MSR_STORE_ADDRESS_HIGH, [ebp + EXIT_CONTROL.MsrStoreAddress + 4]
%endif        

        ;;
        ;; MSR load fields
        ;;
        DoVmWrite VMEXIT_MSR_LOAD_COUNT, [ebp + EXIT_CONTROL.MsrLoadCount]
        DoVmWrite VMEXIT_MSR_LOAD_ADDRESS_FULL, [ebp + EXIT_CONTROL.MsrLoadAddress]
%ifndef __X64
        DoVmWrite VMEXIT_MSR_LOAD_ADDRESS_HIGH, [ebp + EXIT_CONTROL.MsrLoadAddress + 4]
%endif         

        pop ebp
        ret




;----------------------------------------------------------
; store_exit_control()
; input:
;       none
; output:
;       none
; ������
;       1) �� VMCS �е� VM-exit control ������ buffer ��
;----------------------------------------------------------        
store_exit_control:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif        
        add ebp, PCB.ExitControlBuf

        ;;
        ;; ��ȡ VM exit control field
        ;;
        DoVmRead VMEXIT_CONTROL, [ebp + EXIT_CONTROL.VmExitControl]
        
        ;;
        ;; MSR store fields
        ;;
        DoVmRead VMEXIT_MSR_STORE_COUNT, [ebp + EXIT_CONTROL.MsrStoreCount]
        DoVmRead VMEXIT_MSR_STORE_ADDRESS_FULL, [ebp + EXIT_CONTROL.MsrStoreAddress]
%ifndef __X64
        DoVmRead VMEXIT_MSR_STORE_ADDRESS_HIGH, [ebp + EXIT_CONTROL.MsrStoreAddress + 4]
%endif        

        ;;
        ;; MSR load fields
        ;;
        DoVmRead VMEXIT_MSR_LOAD_COUNT, [ebp + EXIT_CONTROL.MsrLoadCount]
        DoVmRead VMEXIT_MSR_LOAD_ADDRESS_FULL, [ebp + EXIT_CONTROL.MsrLoadAddress]
%ifndef __X64
        DoVmRead VMEXIT_MSR_LOAD_ADDRESS_HIGH, [ebp + EXIT_CONTROL.MsrLoadAddress + 4]
%endif         

        pop ebp
        ret



;----------------------------------------------------------
; flush_entry_control()
; input:
;       none
; output:
;       none
; ������
;       1) �� buffer �е� VM-entry control ˢ�µ� VMCS ��
;----------------------------------------------------------
flush_entry_control:
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif        
        add ebp, PCB.EntryControlBuf
        
        ;;
        ;; д�� VM-entry control field
        ;;
        DoVmWrite VMENTRY_CONTROL, [ebp + ENTRY_CONTROL.VmEntryControl]
        
        ;;
        ;; MSR load fields
        ;;
        DoVmWrite VMENTRY_MSR_LOAD_COUNT, [ebp + ENTRY_CONTROL.MsrLoadCount]
        DoVmWrite VMENTRY_MSR_LOAD_ADDRESS_FULL, [ebp + ENTRY_CONTROL.MsrLoadAddress]
%ifndef __X64
        DoVmWrite VMENTRY_MSR_LOAD_ADDRESS_HIGH, [ebp + ENTRY_CONTROL.MsrLoadAddress + 4]
%endif           

        ;;
        ;; VM-entry interrupt information
        ;;        
        DoVmWrite VMENTRY_INTERRUPTION_INFORMATION, [ebp + ENTRY_CONTROL.InterruptionInfo]
        DoVmWrite VMENTRY_EXCEPTION_ERROR_CODE, [ebp + ENTRY_CONTROL.ExceptionErrorCode]
        DoVmWrite VMENTRY_INSTRUCTION_LENGTH, [ebp + ENTRY_CONTROL.InstructionLength]

        pop ebp
        ret




;----------------------------------------------------------
; store_entry_control()
; input:
;       none
; output:
;       none
; ������
;       1) �� VMCS �е� VM-entry control ������ buffer ��
;----------------------------------------------------------
store_entry_control:
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif        
        add ebp, PCB.EntryControlBuf
        
        ;;
        ;; VM-entry control field
        ;;
        DoVmRead VMENTRY_CONTROL, [ebp + ENTRY_CONTROL.VmEntryControl]
        
        
        ;;
        ;; MSR load fields
        ;;
        DoVmRead VMENTRY_MSR_LOAD_COUNT, [ebp + ENTRY_CONTROL.MsrLoadCount]
        DoVmRead VMENTRY_MSR_LOAD_ADDRESS_FULL, [ebp + ENTRY_CONTROL.MsrLoadAddress]
%ifndef __X64
        DoVmRead VMENTRY_MSR_LOAD_ADDRESS_HIGH, [ebp + ENTRY_CONTROL.MsrLoadAddress + 4]
%endif           

        ;;
        ;; VM-entry interrupt information
        ;;        
        DoVmRead VMENTRY_INTERRUPTION_INFORMATION, [ebp + ENTRY_CONTROL.InterruptionInfo]
        DoVmRead VMENTRY_EXCEPTION_ERROR_CODE, [ebp + ENTRY_CONTROL.ExceptionErrorCode]     
        DoVmRead VMENTRY_INSTRUCTION_LENGTH, [ebp + ENTRY_CONTROL.InstructionLength]
  
        pop ebp
        ret
        
        
        
        

;----------------------------------------------------------
; store_exit_info()
; input:
;       none
; output:
;       none
; ����:
;       1) �� VMCS �е� VM-exit information ������ buffer
;----------------------------------------------------------        
store_exit_info:
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [gs: PCB.Base]
%endif 
        add ebp, PCB.ExitInfoBuf

        ;;
        ;; exit reason & qualification
        ;;
        DoVmRead EXIT_REASON, [ebp + EXIT_INFO.ExitReason]
        DoVmRead EXIT_QUALIFICATION, [ebp + EXIT_INFO.ExitQualification]
        
        ;;
        ;; guest linear/physcial address
        ;;
        DoVmRead GUEST_LINEAR_ADDRESS, [ebp + EXIT_INFO.GuestLinearAddress]
        DoVmRead GUEST_PHYSICAL_ADDRESS_FULL, [ebp + EXIT_INFO.GuestPhysicalAddress]
%ifndef __X64
        DoVmRead GUEST_PHYSICAL_ADDRESS_HIGH, [ebp + EXIT_INFO.GuestPhysicalAddress + 4]
%endif

        ;;
        ;; Vm-exit interruption information
        ;;
        DoVmRead VMEXIT_INTERRUPTION_INFORMATION, [ebp + EXIT_INFO.InterruptionInfo]
        DoVmRead VMEXIT_INTERRUPTION_ERROR_CODE, [ebp + EXIT_INFO.InterruptionErrorCode]

        ;;
        ;; IDT-vectoring information
        ;;
        DoVmRead IDT_VECTORING_INFORMATION, [ebp + EXIT_INFO.IdtVectoringInfo]
        DoVmRead IDT_VECTORING_ERROR_CODE, [ebp + EXIT_INFO.IdtVectoringErrorCode]
                
        ;;
        ;; instruction length & information
        ;;
        DoVmRead VMEXIT_INSTRUCTION_LENGTH, [ebp + EXIT_INFO.InstructionLength]
        DoVmRead VMEXIT_INSTRUCTION_INFORMATION, [ebp + EXIT_INFO.InstructionInfo]        
        
        ;;
        ;; I/O rcx/rsi/rdi/rip
        ;;
        DoVmRead IO_RCX, [ebp + EXIT_INFO.IoRcx]
        DoVmRead IO_RSI, [ebp + EXIT_INFO.IoRsi]
        DoVmRead IO_RDI, [ebp + EXIT_INFO.IoRdi]
        DoVmRead IO_RIP, [ebp + EXIT_INFO.IoRip]
        
  
        ;;
        ;; VM-instruction error field
        ;;
        DoVmRead VM_INSTRUCTION_ERROR, [ebp + EXIT_INFO.InstructionError]
               
        pop ebp
        ret
        
        
        

        