;*************************************************
; ex.asm                                         *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************

%include "..\..\lib\Guest\Guest.inc"

;;
;; ex.asm ˵����
;; 1) ex.asm ��ʵ�����ӵ�Դ�����ļ�����Ƕ���� protected.asm �� long.asm �ļ���
;; 2) ex.asm ��ͨ��ģ�飬���� stage2 �� stage3 �׶�����
;;
        ;;
        ;; ���� ex.asm ģ��ʹ�õ�ͷ�ļ�
        ;;
        %include "ex.inc"


        ;;
        ;; ʾ�� 7-3: ʹ��EPT����ʵ��local APIC���⻯
        ;;
        
        

;;
;; ����һ�� SYSENTER_EIP hook ǩ��
;;
%define SYSENTER_HOOK_SIGN                      'HOOK'



Ex.Start:
        ;;
        ;; ��� CPU ����
        ;;
        cmp DWORD [fs: SDA.ProcessorCount], 2
        je Ex.Next
        
        ;;
        ;; ���� CPU3 ִ�� dump_debug_record() ����
        ;;                
        mov esi, 3
        mov edi, dump_debug_record
        call dispatch_to_processor

       
        ;;
        ;; �ȴ��û�ѡ������
        ;;
        call do_command        

        
Ex.Next:
        ;;
        ;; ע����һ�� external interrupt ��������
        ;;
        mov esi, Ex.DoExternalInterrupt
        mov [DoVmExitRoutineTable + EXIT_NUMBER_EXTERNAL_INTERRUPT * 4], esi
          
        ;;
        ;; ���� host �� external interrupt ����Ȩ
        ;;          
        mov DWORD [Ex.ExtIntHold], 1
                       
        ;;
        ;; ���ȵ� CPU1 ִ�� dump_debug_record()
        ;;
        mov esi, 1
        mov edi, dump_debug_record
        call dispatch_to_processor
        
        ;;
        ;; ���� VM-entry
        ;;
        call TargetCpuVmentry


        ;;
        ;; �ȴ�����
        ;;
        call wait_esc_for_reset

        






;----------------------------------------------
; TargetCpuVmentry()
; input:
;       none
; output:
;       none
; ������
;       1) ����ִ�е�Ŀ�����
;----------------------------------------------
TargetCpuVmentry: 

        mov R5, [gs: PCB.Base]

        ;;
        ;; ��ʼ�� GUEST A �� B
        ;;
        call init_guest_a
        call init_guest_b
        
        ;;
        ;; �� ready ����ȡ��
        ;;
        call out_ready_queue
        mov ecx, eax
        mov R3, [R5 + PCB.VmcsA + R0 * 8]
  
        ;;
        ;; ���� VMCS pointer
        ;;
        vmptrld [R3 + VMB.PhysicalBase]
        jc TargetCpuVmentry.Failure
        jz TargetCpuVmentry.Failure

        ;;
        ;; ���µ�ǰ VMB ָ��
        ;;
        mov [R5 + PCB.CurrentVmbPointer], R3
        call update_system_status

        mov edi, ecx
        
        ;;
        ;; ���� VMM MSR-load
        ;;                         
        mov ecx, IA32_TIME_STAMP_COUNTER
        rdtsc
        mov ecx, edi
        mov esi, IA32_TIME_STAMP_COUNTER
        call append_vmexit_msr_load_entry      

        ;;
        ;; ע����һ�� VMX preemption timer ��������
        ;;
        mov esi, Ex.DoVmxPreemptionTimer
        mov [DoVmExitRoutineTable + EXIT_NUMBER_VMX_PREEMPTION_TIMER * 4], esi

        ;;
        ;; ע����һ�� WRMSR ָ�������
        ;;
        ;mov esi, Ex.DoWRMSR
        ;mov [DoVmExitRoutineTable + EXIT_NUMBER_WRMSR * 4], esi
        
        ;;
        ;; ע����һ�� VMM �� page fault ��������
        ;;                
        mov esi, Ex.DoPageFault
        mov [DoExceptionTable + 14 * 4], esi

        
        ;;
        ;; ��ӡ��Ϣ
        ;;
        mov esi, Ex.Msg1
        call puts
        mov esi, Ex.Msg2
        call puts         
        mov esi, Ex.Msg3
        call puts
        mov esi, [R5 + PCB.ProcessorIndex] 
        inc esi
        call print_dword_decimal
        mov esi, Ex.Msg4
        call puts   

        ;;
        ;; ���� running ����
        ;;        
        mov esi, ecx
        call in_running_queue
        mov DWORD [R3 + VMB.GuestStatus], GUEST_RUNNING
        
        ;;
        ;; ���� guest ����
        ;;  
        call reset_guest_context
        vmlaunch
        
TargetCpuVmentry.Failure:
     
        call dump_vmcs
        call wait_esc_for_reset
        ret









;----------------------------------------------
; Ex ģ��� WRMSR �������̡�
;----------------------------------------------
Ex.DoWRMSR:
        push R5
        push R3
        push R1
        push R2
        mov R5, [gs: PCB.Base]
        
        ;;
        ;; ��ǰ VM store block
        ;;
        mov R3, [R5 + PCB.CurrentVmbPointer]
        mov R3, [R3 + VMB.VsbBase]
        
        ;;
        ;; ����Ƿ����� IA32_SYSENTER_EIP
        ;;
        mov eax, [R3 + VSB.Rcx]
        cmp eax, IA32_SYSENTER_EIP
        jne Ex.DoWRMSR.@1
        
        ;;
        ;; ���� IA32_SYSENTER_EIP ֵΪ SYSENTER_HOOK_SIGN��������֤
        ;;
        SetVmcsField    GUEST_IA32_SYSENTER_EIP, SYSENTER_HOOK_SIGN
        
        ;;
        ;; ����ԭ IA32_SYSENTER_EIP 
        ;;
        mov eax, [R3 + VSB.Rax]
        mov edx, [R3 + VSB.Rdx]
        mov [Ex.SysenterEip], eax
        mov [Ex.SysenterEip + 4], edx

        DEBUG_RECORD    "[Ex.DoWRMSR]: set SYSENTER_HOOK_SIGN !"
                
        jmp Ex.DoWRMSR.@2
        
Ex.DoWRMSR.@1:       
        ;;
        ;; ���� VM-entry/VM-exit MSR-load/MSR-store
        ;;                         
        mov esi, eax
        mov eax, [R3 + VSB.Rax]
        mov edx, [R3 + VSB.Rdx]
        call append_vmentry_msr_load_entry        
        
Ex.DoWRMSR.@2:
        ;;
        ;; ���� guest-RIP
        ;;
        call update_guest_rip        
        
        mov eax, VMM_PROCESS_RESUME
        pop R2
        pop R1
        pop R5
        pop R3
        ret




;----------------------------------------------
; Ex ģ��� page fault �������̡�
;----------------------------------------------
Ex.DoPageFault:
        push R5
        push R2        
        mov R5, [gs: PCB.Base]

        ;;
        ;; ��ȡ���� #PF �����Ե�ַ
        ;;
        mov R0, [R5 + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
                
        ;;
        ;; ������Ե�ַ�Ƿ��� VMM ���õĵ�ֵַ        
        ;;
        cmp R0, SYSENTER_HOOK_SIGN
        mov eax, VMM_PROCESS_DUMP_VMCS
        jne Ex.DoPageFault.Reflect

        ;;
        ;; ��ȡԭ IA32_SYSENTER_EIP ֵ
        ;;                
        mov R0, [Ex.SysenterEip]
        
        DEBUG_RECORD    "[Ex.DoPageFault]: call SysRoutine !"
        
        ;;
        ;; ���� guest-RIP
        ;;
        SetVmcsField    GUEST_RIP, R0
        
        jmp Ex.DoPageFault.Done

Ex.DoPageFault.Reflect:
        ;;
        ;; ���� #PF �쳣���� guest
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_PF
        mov eax, [R5 + PCB.ExitInfoBuf + EXIT_INFO.InterruptionErrorCode]
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        
Ex.DoPageFault.Done:
        mov eax, VMM_PROCESS_RESUME
        pop R2
        pop R5        
        ret
        




;----------------------------------------------
; Ex ģ��� VMX-preemption timer �������̡�
;----------------------------------------------
Ex.DoVmxPreemptionTimer:
        push R5
        push R1
        push R3


        DEBUG_RECORD    "[Ex.DoPreemptionTimer]: switch guest !"
        
        ;;
        ;; �Ƴ���ǰ���е� guest�����뵽 ready ����
        ;;
        call out_running_queue
        mov R3, [gs: PCB.VmcsA + R0 * 8]        
        mov esi, eax
        call in_ready_queue
        mov DWORD [R3 + VMB.GuestStatus], GUEST_SUSPENDED
     
        ;;
        ;; �� ready ������ȡ����Ҫ���е� guest,���뵽 running ����
        ;;
        call out_ready_queue
        mov R3, [gs: PCB.VmcsA + R0 * 8]
        mov ecx, eax
        
        mov esi, [Ex.SwitchMsg + R0 * 4]
        call puts
        
        ;;
        ;; ���� guest
        ;;
        vmptrld [R3 + VMB.PhysicalBase]
        jc Ex.DoPreemptionTimer.failure
        jz Ex.DoPreemptionTimer.failure
        
        mov [gs: PCB.CurrentVmbPointer], R3

        ;;
        ;; guest ����ʱ��Ϊ 50us
        ;;
        mov esi, 50
        call set_vmx_preemption_timer_value                

        
        cmp DWORD [R3 + VMB.GuestStatus], GUEST_READY
        je Ex.DoPreemptionTimer.ready
        cmp DWORD [R3 + VMB.GuestStatus], GUEST_SUSPENDED
        jne Ex.DoPreemptionTimer.done
        
        ;;
        ;; guest Ŀǰ���� suspended ״̬
        ;;        
        mov DWORD [R3 + VMB.GuestStatus], GUEST_RUNNING
        mov esi, ecx
        call in_running_queue
        
        mov eax, VMM_PROCESS_RESUME        
        jmp Ex.DoPreemptionTimer.done
        
Ex.DoPreemptionTimer.ready:        
        ;;
        ;; guest Ŀǰ���� ready ״̬
        ;;        
        mov DWORD [R3 + VMB.GuestStatus], GUEST_RUNNING
        mov esi, ecx
        call in_running_queue
        
        mov eax, VMM_PROCESS_LAUNCH
        jmp Ex.DoPreemptionTimer.done
        
        
Ex.DoPreemptionTimer.failure:
        call dump_vmcs
        
Ex.DoPreemptionTimer.done:        
        pop R3
        pop R1
        pop R5
        ret
  


;----------------------------------------------
; Ex ģ��� external interrupt �������̡�
;----------------------------------------------
Ex.DoExternalInterrupt:
        ;;
        ;; ���ж� window���� host ִ���жϴ���
        ;;
        sti
        mov eax, VMM_PROCESS_RESUME
        ret






;----------------------------------------------
; init_guest_a()
; input:
;       none
; output:
;       none
; ������
;       1) ��ʼ�� GUEST A
;----------------------------------------------
init_guest_a:
        push R5
        push R2
        push R1
        push R3
        
        mov R5, [gs: PCB.Base]        
        
        ;;
        ;; guest ���� "unrestricted guest" �Լ� "enable EPT"
        ;;          
        mov eax, GUEST_FLAG_UNRESTRICTED | GUEST_FLAG_EPT
        mov [R5 + PCB.GuestA + VMB.GuestFlags], eax


        ;;
        ;; ���� guest RIP �Լ� host-RIP
        ;;
        mov DWORD [R5 + PCB.GuestA + VMB.GuestEntry], GUEST_BOOT_ENTRY + 4
        mov DWORD [R5 + PCB.GuestA + VMB.HostEntry], VmmEntry

        ;;
        ;; ��ʼ�� VMCS buffer
        ;;
        mov R6, [R5 + PCB.VmcsA]
        call initialize_vmcs_buffer
        
        ;;
        ;; ִ�� VMCLEAR ����
        ;;
        vmclear [R5 + PCB.GuestA]
        jc TargetCpuVmentry.Failure
        jz TargetCpuVmentry.Failure  
        
        ;;
        ;; ���� VMCS pointer
        ;;
        vmptrld [R5 + PCB.GuestA]
        jc TargetCpuVmentry.Failure
        jz TargetCpuVmentry.Failure

        ;;
        ;; ���µ�ǰ VMB ָ��
        ;;
        mov R0, [R5 + PCB.VmcsA]
        mov [R5 + PCB.CurrentVmbPointer], R0
                        
        call setup_vmcs_region


        ;;
        ;; ��װ Guest ����
        ;;
%if __BITS__ == 64        
        ;;
        ;; step 1���� GuestBoot ģ�鰲װ�� domain
        ;;
        mov ecx, [GUEST_BOOT_SEGMENT]
        add ecx, 0C00h + 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                ;; ���� n �� 4K domain ҳ��� GuestBoot ģ��
        mov rdx, rax

        ;;
        ;; �� GuestBoot ģ�����ӳ�䵽 VM domain
        ;;
        mov esi, GUEST_BOOT_ENTRY                       ;; rsi - guest physical address
        mov rdi, rdx                                    ;; rdi - host phsyical address
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE     ;; eax - page attribute
                                                        ;; ecx - count of page
        call do_guest_physical_address_mapping_n        ;; �� GuestBoot ģ�����ӳ�䵽 domain
        

        ;;
        ;; �� GuestBoot ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_BOOT_SEGMENT                     ;; GuestBoot
        mov rdi, SYSTEM_DATA_SPACE_BASE
        or rdi, rdx                                     ;; VM domain
        add rdi, 0C00h
        mov r8d, [GUEST_BOOT_SEGMENT]
        call memcpy
        

        ;;
        ;; step 2: �� GuestKernel ģ�鰲װ�� domain ��
        ;;
        mov ecx, [GUEST_KERNEL_SEGMENT]
        add ecx, 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                        ; ���� domain �ڴ��������� GuestKernel ģ��
        mov rdx, rax        

        ;;
        ;; �� GuestKernel ģ�����ӳ�䵽 VM domain
        ;;
        mov esi, GUEST_KERNEL_ENTRY
        mov rdi, rdx
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE    
        call do_guest_physical_address_mapping_n                ; �� GuestKernel ģ�����ӳ�䵽 domain �ڴ�
        
        ;;
        ;; �� GuestKernel ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_KERNEL_SEGMENT                           ;; GuestKernel
        mov rdi, SYSTEM_DATA_SPACE_BASE                         ;; VM domain
        or rdi, rdx
        mov r8d, [GUEST_KERNEL_SEGMENT]
        call memcpy
        
        ;;
        ;; step 3: �� B8000h ӳ�䵽 VM video buffer
        ;;
        mov esi, 0B8000h
        mov rdi, [gs: PCB.CurrentVmbPointer]
        mov rdi, [rdi + VMB.VsbPhysicalBase]
        add rdi, VSB.VmVideoBuffer
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE    
        call do_guest_physical_address_mapping
        
        
%else       
        ;;
        ;; step 1���� GuestBoot ģ�鰲װ�� domain
        ;;
        mov ecx, [GUEST_BOOT_SEGMENT]
        add ecx, 0C00h + 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                        ;; ���� domain �ڴ�
        mov ebx, eax
        
        ;;
        ;; �� GuestBoot ģ�����ӳ�䵽 VM domain
        ;;        
        xor edi, edi
        xor edx, edx
        mov esi, GUEST_BOOT_ENTRY                               ; edi:esi = GuestBoot ģ�����
        mov eax, ebx                                            ; edx:eax = domain �ڴ�
        mov ecx, EPT_READ | EPT_WRITE | EPT_EXECUTE
        push ecx                                                ; count of page
        call do_guest_physical_address_mapping_n                ; ӳ�� GuestBoot ģ����ڵ� domain
               
        ;;
        ;; �� GuestBoot ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_BOOT_SEGMENT                             ;; GuestBoot
        mov edi, SYSTEM_DATA_SPACE_BASE
        or edi, ebx                                             ;; VM domain
        add edi, 0C00h
        mov ecx, [GUEST_BOOT_SEGMENT]
        call memcpy
        
        ;;
        ;; step 2���� GuestKernel ģ�鰲װ�� domain
        ;;
        mov ecx, [GUEST_KERNEL_SEGMENT]
        add ecx, 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                        ;; ���� domain �ڴ�
        mov ebx, eax
        
        ;;
        ;; �� GuestKernel ģ�����ӳ�䵽 VM domain
        ;;
        push ecx                                                ; n ҳ
        xor edi, edi
        xor edx, edx
        mov esi, GUEST_KERNEL_ENTRY                             ; edi:esi = GuestKernel ģ�����
        mov eax, ebx                                            ; edx:eax = domain �ڴ�
        mov ecx, EPT_READ | EPT_WRITE | EPT_EXECUTE             ; ecx = paga attribute
        call do_guest_physical_address_mapping_n                ; ӳ�� GuestKernel ģ����ڵ� domain
               
        ;;
        ;; �� GuestKernel ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_KERNEL_SEGMENT                           ;; GuestKernel
        mov edi, SYSTEM_DATA_SPACE_BASE
        or edi, ebx                                             ;; VM domain
        mov ecx, [GUEST_KERNEL_SEGMENT]
        call memcpy 


        ;;
        ;; step 3: �� B8000h ӳ�䵽 VM video buffer
        ;;
        xor edi, edi
        xor edx, edx
        mov esi, 0B8000h                                        ; edi:esi = B8000h
        mov eax, [gs: PCB.CurrentVmbPointer]
        mov eax, [eax + VMB.VsbPhysicalBase]
        add eax, VSB.VmVideoBuffer                              ; edx:eax = VM video buffer
        mov ecx, EPT_READ | EPT_WRITE | EPT_EXECUTE    
        call do_guest_physical_address_mapping
        
%endif

        ;;
        ;; ���� guest �� NMI_EN_PORT��70h���� SYSTEM_CONTROL_PORTA��92h���˿ڵķ���
        ;;
        mov R6, [R5 + PCB.VmcsA]
        mov edi, NMI_EN_PORT
        call set_vmcs_iomap_bit
        
        mov R6, [R5 + PCB.VmcsA]
        mov edi, SYSTEM_CONTROL_PORTA
        call set_vmcs_iomap_bit

        ;;
        ;; ���� VM-entry/VM-exit MSR-load/MSR-store
        ;;                         
        mov esi, IA32_TIME_STAMP_COUNTER
        xor eax, eax
        xor edx, edx
        call append_vmentry_msr_load_entry

        ;;
        ;; ���� guest �ĳ�ʼ IA32_APIC_BASE �Ĵ���ֵ
        ;;
        mov esi, IA32_APIC_BASE
        mov eax, 0FEE00000h | APIC_BASE_BSP | APIC_BASE_ENABLE
        xor edx, edx
        call append_vmentry_msr_load_entry
        
        ;;
        ;; ���浱ǰ�� IA32_APIC_BASE ֵ��Ϊ VM-exit ʱ����
        ;;
        mov ecx, IA32_APIC_BASE
        rdmsr
        mov esi, IA32_APIC_BASE
        call append_vmexit_msr_load_entry

        ;;
        ;; �������ض� IA32_SYSENTER_EIP �Ķ�����
        ;;
        mov esi, IA32_SYSENTER_EIP
        call set_msr_read_bitmap
        
        ;;
        ;; �������ض� IA32_SYSENTER_EIP ��д����
        ;;
        mov esi, IA32_SYSENTER_EIP
        call set_msr_write_bitmap

        ;;
        ;; �������ض� IA32_APIC_BASE �Ķ�����
        ;;
        mov esi, IA32_APIC_BASE
        call set_msr_read_bitmap        
        
        ;;
        ;; �������ض� IA32_APIC_BASE ��д����
        ;;
        mov esi, IA32_APIC_BASE
        call set_msr_write_bitmap

        ;;
        ;; ΪĬ�ϵ� local APIC ��ַ�ṩ��������
        ;;
        mov esi, 0FEE00000h
        mov edi, EptHandlerForGuestApicPage
        call AppendGpaHte
                
        ;;
        ;; ���� VMX-preemption timer��guestA ����ʱ��Ϊ 50us
        ;;
        SET_PINBASED_CTLS       ACTIVATE_VMX_PREEMPTION_TIMER      
        SET_VM_EXIT_CTLS        SAVE_VMX_PREEMPTION_TIMER_VALUE
        mov esi, 50
        call set_vmx_preemption_timer_value
        
        ;;
        ;; ��� host �Ƿ���Ҫ�� external interrupt ���п���
        ;;        
        cmp DWORD [Ex.ExtIntHold], 1
        jne init_guest_a.@1        
        ;;
        ;; �ر� "acknowledge interrupt on exit" λ
        ;;
        CLEAR_VM_EXIT_CTLS      ACKNOWLEDGE_INTERRUPT_ON_EXIT

init_guest_a.@1:        
        
        ;;
        ;; ���� guest ״̬
        ;;                
        mov DWORD [R5 + PCB.GuestA + VMB.GuestStatus], GUEST_READY
                    
        ;;
        ;; �� guestA ���� ready ����
        ;;
        mov esi, 0
        call in_ready_queue
        
        pop R3
        pop R1
        pop R2
        pop R5        
        ret




;----------------------------------------------
; init_guest_b()
; input:
;       none
; output:
;       none
; ������
;       1) ��ʼ�� GUEST B
;----------------------------------------------
init_guest_b:
        push R5
        push R2
        push R1
        push R3
        
        mov R5, [gs: PCB.Base]        
              
        ;;
        ;; guest ���� "unrestricted guest" �Լ� "enable EPT"
        ;;          
        mov eax, GUEST_FLAG_UNRESTRICTED | GUEST_FLAG_EPT
        mov [R5 + PCB.GuestB + VMB.GuestFlags], eax


        ;;
        ;; ���� guest RIP �Լ� host-RIP
        ;;
        mov DWORD [R5 + PCB.GuestB + VMB.GuestEntry], GUEST_BOOT_ENTRY + 4
        mov DWORD [R5 + PCB.GuestB + VMB.HostEntry], VmmEntry

       
        ;;
        ;; ��ʼ�� VMCS buffer
        ;;
        mov R6, [R5 + PCB.VmcsB]
        call initialize_vmcs_buffer
        
        ;;
        ;; ִ�� VMCLEAR ����
        ;;
        vmclear [R5 + PCB.GuestB]
        jc TargetCpuVmentry.Failure
        jz TargetCpuVmentry.Failure  
        
        ;;
        ;; ���� VMCS pointer
        ;;
        vmptrld [R5 + PCB.GuestB]
        jc TargetCpuVmentry.Failure
        jz TargetCpuVmentry.Failure

        ;;
        ;; ���µ�ǰ VMB ָ��
        ;;
        mov R0, [R5 + PCB.VmcsB]
        mov [R5 + PCB.CurrentVmbPointer], R0
                        
        call setup_vmcs_region
        
        ;;
        ;; ��װ Guest ����
        ;;        
%if __BITS__ == 64                

        ;;
        ;; step 1���� GuestBoot ģ�鰲װ�� domain
        ;;
        mov ecx, [GUEST_BOOT_SEGMENT]
        add ecx, 0C00h + 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                ;; ���� n �� 4K domain ҳ��� GuestBoot ģ��
        mov rdx, rax

        ;;
        ;; �� GuestBoot ģ�����ӳ�䵽 VM domain
        ;;
        mov esi, GUEST_BOOT_ENTRY                       ;; rsi - guest physical address
        mov rdi, rdx                                    ;; rdi - host phsyical address
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE     ;; eax - page attribute
                                                        ;; ecx - count of page
        call do_guest_physical_address_mapping_n        ;; �� GuestBoot ģ�����ӳ�䵽 domain
        

        ;;
        ;; �� GuestBoot ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_BOOT_SEGMENT                     ;; GuestBoot
        mov rdi, SYSTEM_DATA_SPACE_BASE
        or rdi, rdx                                     ;; VM domain
        add rdi, 0C00h
        mov r8d, [GUEST_BOOT_SEGMENT]
        call memcpy
        

        ;;
        ;; step 2: �� GuestKernel ģ�鰲װ�� domain ��
        ;;
        mov ecx, [GUEST_KERNEL_SEGMENT]
        add ecx, 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                        ; ���� domain �ڴ��������� GuestKernel ģ��
        mov rdx, rax        

        ;;
        ;; �� GuestKernel ģ�����ӳ�䵽 VM domain
        ;;
        mov esi, GUEST_KERNEL_ENTRY
        mov rdi, rdx
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE    
        call do_guest_physical_address_mapping_n                ; �� GuestKernel ģ�����ӳ�䵽 domain �ڴ�
        
        ;;
        ;; �� GuestKernel ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_KERNEL_SEGMENT                           ;; GuestKernel
        mov rdi, SYSTEM_DATA_SPACE_BASE                         ;; VM domain
        or rdi, rdx
        mov r8d, [GUEST_KERNEL_SEGMENT]
        call memcpy
        
        ;;
        ;; step 3: �� B8000h ӳ�䵽 VM video buffer
        ;;
        mov esi, 0B8000h
        mov rdi, [gs: PCB.CurrentVmbPointer]
        mov rdi, [rdi + VMB.VsbPhysicalBase]
        add rdi, VSB.VmVideoBuffer
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE    
        call do_guest_physical_address_mapping
        
        
%else       
        ;;
        ;; step 1���� GuestBoot ģ�鰲װ�� domain
        ;;
        mov ecx, [GUEST_BOOT_SEGMENT]
        add ecx, 0C00h + 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                        ;; ���� domain �ڴ�
        mov ebx, eax
        
        ;;
        ;; �� GuestBoot ģ�����ӳ�䵽 VM domain
        ;;        
        xor edi, edi
        xor edx, edx
        mov esi, GUEST_BOOT_ENTRY                               ; edi:esi = GuestBoot ģ�����
        mov eax, ebx                                            ; edx:eax = domain �ڴ�
        mov ecx, EPT_READ | EPT_WRITE | EPT_EXECUTE
        push ecx                                                ; count of page
        call do_guest_physical_address_mapping_n                ; ӳ�� GuestBoot ģ����ڵ� domain
               
        ;;
        ;; �� GuestBoot ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_BOOT_SEGMENT                             ;; GuestBoot
        mov edi, SYSTEM_DATA_SPACE_BASE
        or edi, ebx                                             ;; VM domain
        add edi, 0C00h
        mov ecx, [GUEST_BOOT_SEGMENT]
        call memcpy
        
        ;;
        ;; step 2���� GuestKernel ģ�鰲װ�� domain
        ;;
        mov ecx, [GUEST_KERNEL_SEGMENT]
        add ecx, 0FFFh
        shr ecx, 12
        mov esi, ecx
        call vm_alloc_pool_physical_page                        ;; ���� domain �ڴ�
        mov ebx, eax
        
        ;;
        ;; �� GuestKernel ģ�����ӳ�䵽 VM domain
        ;;
        push ecx                                                ; n ҳ
        xor edi, edi
        xor edx, edx
        mov esi, GUEST_KERNEL_ENTRY                             ; edi:esi = GuestKernel ģ�����
        mov eax, ebx                                            ; edx:eax = domain �ڴ�
        mov ecx, EPT_READ | EPT_WRITE | EPT_EXECUTE             ; ecx = paga attribute
        call do_guest_physical_address_mapping_n                ; ӳ�� GuestKernel ģ����ڵ� domain
               
        ;;
        ;; �� GuestKernel ģ�鸴�Ƶ� VM domain
        ;;
        mov esi, GUEST_KERNEL_SEGMENT                           ;; GuestKernel
        mov edi, SYSTEM_DATA_SPACE_BASE
        or edi, ebx                                             ;; VM domain
        mov ecx, [GUEST_KERNEL_SEGMENT]
        call memcpy 


        ;;
        ;; step 3: �� B8000h ӳ�䵽 VM video buffer
        ;;
        xor edi, edi
        xor edx, edx
        mov esi, 0B8000h                                        ; edi:esi = B8000h
        mov eax, [gs: PCB.CurrentVmbPointer]
        mov eax, [eax + VMB.VsbPhysicalBase]
        add eax, VSB.VmVideoBuffer                              ; edx:eax = VM video buffer
        mov ecx, EPT_READ | EPT_WRITE | EPT_EXECUTE    
        call do_guest_physical_address_mapping
        
%endif
        
        ;;
        ;; ���� guest �� NMI_EN_PORT��70h���� SYSTEM_CONTROL_PORTA��92h���˿ڵķ���
        ;;
        mov R6, [R5 + PCB.VmcsB]
        mov edi, NMI_EN_PORT
        call set_vmcs_iomap_bit
        
        mov R6, [R5 + PCB.VmcsB]
        mov edi, SYSTEM_CONTROL_PORTA
        call set_vmcs_iomap_bit
        
        ;;
        ;; ���� VM-entry/VM-exit MSR-load/MSR-store
        ;;                         
        mov esi, IA32_TIME_STAMP_COUNTER
        xor eax, eax
        xor edx, edx
        call append_vmentry_msr_load_entry
                
        ;;
        ;; ���� guest �ĳ�ʼ IA32_APIC_BASE �Ĵ���ֵ
        ;;
        mov esi, IA32_APIC_BASE
        mov eax, 0FEE00000h | APIC_BASE_BSP | APIC_BASE_ENABLE
        xor edx, edx
        call append_vmentry_msr_load_entry
        
        ;;
        ;; ���浱ǰ�� IA32_APIC_BASE ֵ��Ϊ VM-exit ʱ����
        ;;
        mov ecx, IA32_APIC_BASE
        rdmsr
        mov esi, IA32_APIC_BASE
        call append_vmexit_msr_load_entry
        
        
        ;;
        ;; �������ض� IA32_SYSENTER_EIP ��д����
        ;;
        mov esi, IA32_SYSENTER_EIP
        call set_msr_write_bitmap
        
        ;;
        ;; �������ض� IA32_SYSENTER_EIP �Ķ�����
        ;;
        mov esi, IA32_SYSENTER_EIP
        call set_msr_read_bitmap
        
        ;;
        ;; �������ض� IA32_APIC_BASE �Ķ�����
        ;;
        mov esi, IA32_APIC_BASE
        call set_msr_read_bitmap
                
        ;;
        ;; �������ض� IA32_APIC_BASE ��д����
        ;;
        mov esi, IA32_APIC_BASE
        call set_msr_write_bitmap
        
        ;;
        ;; ΪĬ�ϵ� local APIC ��ַ�ṩ��������
        ;;
        mov esi, 0FEE00000h
        mov edi, EptHandlerForGuestApicPage
        call AppendGpaHte
        
        
        ;;
        ;; ���� VMX-preemption timer��guestB ����ʱ��Ϊ 50us
        ;;
        SET_PINBASED_CTLS       ACTIVATE_VMX_PREEMPTION_TIMER        
        SET_VM_EXIT_CTLS        SAVE_VMX_PREEMPTION_TIMER_VALUE
        mov esi, 50
        call set_vmx_preemption_timer_value
        
        ;;
        ;; ��� host �Ƿ���Ҫ�� external interrupt ���п���
        ;;
        cmp DWORD [Ex.ExtIntHold], 1
        jne init_guest_b.@1        
        ;;
        ;; �ر� "acknowledge interrupt on exit" λ
        ;;
        CLEAR_VM_EXIT_CTLS      ACKNOWLEDGE_INTERRUPT_ON_EXIT

init_guest_b.@1:  

        ;;
        ;; ���� guest ״̬
        ;;                
        mov DWORD [R5 + PCB.GuestB + VMB.GuestStatus], GUEST_READY       
        
        ;;
        ;; �� guestB ���� ready ����
        ;;
        mov esi, 1
        call in_ready_queue
        
        
        pop R3
        pop R1
        pop R2
        pop R5     
        ret







;-------------------------------------------------
; 
;-------------------------------------------------
do_command:
%if __BITS__ == 64
        push rbx
%else        
        push ebx
%endif

do_command.loop:        
        mov esi, 2
        mov edi, 0
        call set_video_buffer
        mov esi, Ex.CmdMsg
        call puts
        
        ;;
        ;; �ȴ�����
        ;;
        call wait_a_key
        
        cmp al, SC_ESC                                          ; �Ƿ�Ϊ <ESC>
        je do_esc
        cmp al, SC_Q                                            ; �Ƿ�Ϊ <Q>
        je do_command.done
        
        cmp al, SC_1
        jb do_command.@0
        cmp al, SC_0
        jbe do_command.vmentry

        
do_command.@0:
        ;;
        ;; �Ƿ��� interrupt
        ;;
        cmp al, SC_I
        jne do_command.@1
               
        mov edi, FIXED_DELIVERY | PHYSICAL | IPI_VECTOR
        jmp do_command.@4
        
do_command.@1:
        ;;
        ;; �Ƿ��� NMI
        ;;            
        cmp al, SC_N
        jne do_command.@2
        
        DEBUG_RECORD         "[command]: sending a NMI message !"           
        
        mov DWORD [fs: SDA.NmiIpiRequestMask], 0
        mov edi, NMI_DELIVERY | PHYSICAL | 02h
        
        jmp do_command.@4
        
do_command.@2:
        ;;
        ;; �Ƿ��� INIT
        ;;
        cmp al, SC_T
        jne do_command.@3
        
        ;;
        ;; ��ʱ 500us ����һ�� INIT 
        ;;
        mov esi, 153
        mov edi, LAPIC_TIMER_PERIODIC
        mov eax, InitSignalRoutine
        call start_lapic_timer
        
        mov edi, INIT_DELIVERY | PHYSICAL               
        jmp do_command.@4

do_command.@3:
        ;;
        ;; �Ƿ��� SIPI
        ;;
        cmp al, SC_S
        jne do_command.loop
        mov edi, SIPI_DELIVERY | PHYSICAL
        
do_command.@4:
        mov esi, [Ex.TargetCpu]
        call get_processor_pcb
        mov ebx, foo
               
%if __BITS__ == 64        
        test rax, rax
        jz do_command.loop
        
        mov [rax + PCB.IpiRoutinePointer], rbx        
        mov esi, [rax + PCB.ApicId]
%else        
        test eax, eax
        jz do_command.loop
        
        mov [eax + PCB.IpiRoutinePointer], ebx
        mov esi, [eax + PCB.ApicId]        
%endif        
        
        mov [Ex.TargetCpu], esi
        mov [Ex.TargetIpi], edi
                
        SEND_IPI_TO_PROCESSOR   esi, edi
        jmp do_command.loop
        
        
do_command.vmentry:

        DEBUG_RECORD         "[command]: *** dispatch to CPU for VM-entry *** "
        
        dec al
        movzx eax, al
        mov esi, 1
        cmp eax, [fs: SDA.ProcessorCount]
        cmovb esi, eax
        mov [Ex.TargetCpu], esi
        mov edi, [TargetVmentryRoutine + esi * 4 - 4]
        call goto_processor
        jmp do_command.loop
do_esc:        
        RESET_CPU
        
do_command.done:        
%if __BITS__ == 64
        pop rbx
%else
        pop ebx        
%endif
        ret



foo:
        ret



InitSignalRoutine:
        mov esi, [Ex.TargetCpu]
        mov edi, [Ex.TargetIpi]
        SEND_IPI_TO_PROCESSOR   esi, edi
        ret


dump_lbr:
;        call dump_lbr_stack
        mov ecx, MSR_LASTBRANCH_0_FROM_IP
        rdmsr
        mov [fr0], eax
        mov [fr0+4], edx
        mov ecx, MSR_LASTBRANCH_0_TO_IP
        rdmsr
        mov [to0], eax
        mov [to0+4], edx
        mov ecx, MSR_LASTBRANCH_1_FROM_IP
        rdmsr
        mov [fr1], eax
        mov [fr1+4], edx
        mov ecx, MSR_LASTBRANCH_1_TO_IP
        rdmsr
        mov [to1], eax
        mov [to1+4], edx    
        
        mov esi, [fr0]
        mov edi, [fr0+4]
        call print_qword_value
        mov esi, ','
        call putc
        mov esi, [to0]
        mov edi, [to0+4]
        call print_qword_value
        call println
        mov esi, [fr1]
        mov edi, [fr1+4]
        call print_qword_value
        mov esi, ','
        call putc
        mov esi, [to1]
        mov edi, [to1+4]
        call print_qword_value        
        call wait_esc_for_reset
        ret
        

        
        
        
fr0      DQ      0
fr1      DQ      0
to0      DQ      0
to1      DQ      0


Ex.CmdMsg       db '===================<<< press a key to do command >>>=========================', 10
Ex.SysMsg       db '[system command       ]:   reset - <ESC>, Quit - q,     CPUn - <Fn+1>',  10
Ex.VmxEntryMsg  db '[CPU for VM-entry     ]:   CPU1  - 1,     CPU2 - 2', 10, 
Ex.IpiMsg       db '[Send Message to CPU  ]:   INT   - i,     NMI  - n,     INIT - t,    SIPI - s', 10, 0
Ex.SwtichMsg    db '[switch to guest      ]:   GuestA - a,   GuestB - b,    GuestC - c,  GuestD - d', 10, 0


Ex.TargetCpu    dd      1
Ex.TargetIpi    dd      1

TargetVmentryRoutine    dd      TargetCpuVmentry, TargetCpuVmentry, 0


signal  dd 1        
Ex.ExtIntHold           dd      0
Ex.SysenterEip          dq      0


msg0    db 'press keys: ', 0
msg1    db 'resume failure', 10, 0    

GuestCpuMode    db 10, 'Guest CPU mode: ', 0
Ex.Msg0         db '[Host]: VMCS initializing ...', 10, 0
Ex.Msg1         db '[Host]: launch VM ...', 10, 0
Ex.Msg2         db '[Host]: Guest OS running ...', 10, 0
Ex.Msg3         db '[Host]: press <F', 0
Ex.Msg4         db '> key switch to GUEST screen !', 10, 0
Ex.TscMsg       db '[Host]: TSC = ', 0

Ex.SwitchA      db '[Host]: switch to guestA', 10, 0
Ex.SwitchB      db '[Host]: switch to guestB', 10, 0
Ex.SwitchC      db '[Host]: switch to guestC', 10, 0
Ex.SwitchD      db '[Host]: switch to guestD', 10, 0

Ex.SwitchMsg    dd  Ex.SwitchA, Ex.SwitchB, Ex.SwitchC, Ex.SwitchD, 0