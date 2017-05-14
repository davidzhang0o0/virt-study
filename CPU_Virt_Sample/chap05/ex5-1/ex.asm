;*************************************************
; ex.asm                                         *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


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
        ;; ʾ��5-1������������������������VM-exit��CPUID��RDTSCָ��
        ;; 1) guest1 ִ�� CPUID ָ��
        ;; 2) guest2 ִ�� RDTSC ָ��
        ;;
        
        
        
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
        

        ;;
        ;; �ȴ�����
        ;;
        call wait_esc_for_reset

        






;----------------------------------------------
; TargetCpuVmentry1()
; input:
;       none
; output:
;       none
; ������
;       1) ����ִ�е�Ŀ�����
;       2) �˺����ô�����ִ�� VM-entry ����
;----------------------------------------------
TargetCpuVmentry1:       
        push R5
        mov R5, [gs: PCB.Base]

                       
        ;;
        ;; CR0.PG = CR.PE = 1
        ;;
        mov eax, GUEST_FLAG_PE | GUEST_FLAG_PG
        
%ifdef __X64        
        or eax, GUEST_FLAG_IA32E
%endif  
        mov [R5 + PCB.GuestA + VMB.GuestFlags], eax

        ;;
        ;; ��ʼ�� VMCS region
        ;;
        mov DWORD [R5 + PCB.GuestA + VMB.GuestEntry], guest_entry1
        mov DWORD [R5 + PCB.GuestA + VMB.HostEntry], VmmEntry

        ;;
        ;; ���� guest stack
        ;;
        mov edi, get_user_stack_pointer
        mov esi, get_kernel_stack_pointer
        test eax, GUEST_FLAG_USER
        cmovnz esi, edi
        call R6
        mov [R5 + PCB.GuestA + VMB.GuestStack], R0
        
        ;;
        ;; ��ʼ�� VMCS buffer
        ;;
        mov R6, [R5 + PCB.VmcsA]
        call initialize_vmcs_buffer
        
                                
        ;;
        ;; ִ�� VMCLEAR ����
        ;;
        vmclear [R5 + PCB.GuestA]
        jc @1
        jz @1         
        
        ;;
        ;; ���� VMCS pointer
        ;;
        vmptrld [R5 + PCB.GuestA]
        jc @1
        jz @1  

        ;;
        ;; ���µ�ǰ VMB ָ��
        ;;
        mov R0, [R5 + PCB.VmcsA]
        mov [R5 + PCB.CurrentVmbPointer], R0

        ;;
        ;; ���� VMCS
        ;;
        call setup_vmcs_region
        call update_system_status
        

        ;;
        ;; ���� guest ����
        ;;  
        call reset_guest_context
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_GUEST   
        vmlaunch
@1:       
        call dump_vmcs
        call wait_esc_for_reset
        pop R5
        ret
        
        
        




;----------------------------------------------
; TargetCpuVmentry2()
; input:
;       none
; output:
;       none
; ������
;       1) ����ִ�е�Ŀ�����
;----------------------------------------------
TargetCpuVmentry2:       
        push R5
        mov R5, [gs: PCB.Base]

                       
        mov eax, GUEST_FLAG_PE | GUEST_FLAG_PG
        
%ifdef __X64        
        or eax, GUEST_FLAG_IA32E
%endif  
        mov DWORD [R5 + PCB.GuestB + VMB.GuestFlags], eax


        ;;
        ;; ��ʼ�� VMCS region
        ;;
        mov DWORD [R5 + PCB.GuestB + VMB.GuestEntry], guest_entry2
        mov DWORD [R5 + PCB.GuestB + VMB.HostEntry], VmmEntry
        
        ;;
        ;; ���� guest stack
        ;;
        mov edi, get_user_stack_pointer
        mov esi, get_kernel_stack_pointer
        test eax, GUEST_FLAG_USER
        cmovnz R6, R7
        call R6        
        mov [R5 + PCB.GuestB + VMB.GuestStack], R0
       

        ;;
        ;; ��ʼ�� VMCS buffer
        ;;
        mov R6, [R5 + PCB.VmcsB]
        call initialize_vmcs_buffer
        
                                
        ;;
        ;; ִ�� VMCLEAR ����
        ;;
        vmclear [R5 + PCB.GuestB]
        jc @1
        jz @1         
        
        ;;
        ;; ���� VMCS pointer
        ;;
        vmptrld [R5 + PCB.GuestB]
        jc TargetCpuVmentry2.@1
        jz TargetCpuVmentry2.@1  

        ;;
        ;; ���µ�ǰ VMB ָ��
        ;;
        mov R0, [R5 + PCB.VmcsB]
        mov [R5 + PCB.CurrentVmbPointer], R0

        ;;
        ;; ���� VMCS
        ;;
        call setup_vmcs_region
        call update_system_status
        

        ;;
        ;; "rdtsc exitting" = 1
        ;;
        SET_PRIMARY_PROCBASED_CTLS      RDTSC_EXITING
        mov esi, IA32_TIME_STAMP_COUNTER
        xor eax, eax
        xor edx, edx
        call append_vmentry_msr_load_entry
        
       
        ;;
        ;; ���� guest ����
        ;;  
        call reset_guest_context
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_GUEST       
        vmlaunch
        
TargetCpuVmentry2.@1:
        call dump_vmcs
        call wait_esc_for_reset
        ret





;-----------------------------------------------------------------------
; guest_entry1():
; input:
;       none
; output:
;       none
; ������
;       1) ���� guest1 ����ڵ�
;-----------------------------------------------------------------------
guest_entry1:
        DEBUG_RECORD    "[VM-entry]: switch to guest1 !"        ; ���� debug ��¼��
        DEBUG_RECORD    "[guest]: execute CPUID !"
        
        ;;
        ;; guest ����ִ�� CPUID.01H
        ;;
        mov eax, 01h
        cpuid
        
        ;;
        ;; ��� guest CPU ģ��
        ;;
        mov esi, eax
        call get_display_family_model
        mov ebx, eax        
        mov esi, GuestCpuMode
        call puts
        mov esi, ebx
        call print_word_value
        
        hlt
        jmp $ - 1        
        ret        



;-----------------------------------------------------------------------
; guest_entry2():
; input:
;       none
; output:
;       none
; ������
;       1) ���� guest 2 ����ڵ�
;-----------------------------------------------------------------------
guest_entry2:

        DEBUG_RECORD    "[VM-entry]: switch to guest2 !"         ; ���� debug ��¼��
        DEBUG_RECORD    "[guest]: execute RDTSC !"
        
        rdtsc
                
        hlt
        jmp $ - 1
        ret





GuestCpuMode    db 10, 'Guest CPU mode: ', 0
GuestRdtsc      db 10, 'TSC = ', 0





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
        DEBUG_RECORD         "[command]: you press a N key !"
        
        cmp al, SC_N
        jne do_command.@2
        mov DWORD [fs: SDA.NmiIpiRequestMask], 0
        mov edi, NMI_DELIVERY | PHYSICAL | 02h
        jmp do_command.@4
        
do_command.@2:
        ;;
        ;; �Ƿ��� INIT
        ;;
        cmp al, SC_T
        jne do_command.@3
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
        mov DWORD [R0 + PCB.IpiRoutinePointer], 0
        
        
%if __BITS__ == 64        
        mov [rax + PCB.IpiRoutinePointer], rbx        
        mov esi, [rax + PCB.ApicId]
%else        
        mov [eax + PCB.IpiRoutinePointer], ebx
        mov esi, [eax + PCB.ApicId]        
%endif        
        DEBUG_RECORD         "[command]: sending a NMI message !"
        
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





Ex.CmdMsg       db '===================<<< press a key to do command >>>=========================', 10
Ex.SysMsg       db '[system command       ]:   reset - <ESC>, Quit - q,     CPUn - <Fn+1>',  10
Ex.VmxEntryMsg  db '[CPU for VM-entry     ]:   CPU1  - 1,     CPUn - n', 10, 
Ex.IpiMsg       db '[Send Message to CPU  ]:   INT   - i,     NMI  - n,     INIT - t,    SIPI - s', 10, 0


Ex.TargetCpu    dd      1
TargetVmentryRoutine    dd      TargetCpuVmentry1, TargetCpuVmentry2, 0



