;*************************************************
;* VmxVMM.asm                                    *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************



        
        


;-----------------------------------------------------------------------
; VmmEntry()
; input:
;       none
; output:
;       none
; ������
;       1) ���� VMM �������
;-----------------------------------------------------------------------  
VmmEntry:
        ;;
        ;; �ص� host �������� CPU_STATUS_GUEST λ
        ;;
%ifdef __X64
        DB 65h                          ; GS
        DB 81h, 24h, 25h                ; AND mem, imme32
        DD PCB.ProcessorStatus
        DD ~CPU_STATUS_GUEST
%else
        and DWORD [gs: PCB.ProcessorStatus], ~CPU_STATUS_GUEST
%endif

        ;;
        ;; VM-exit �󣬱��뱣�� guest context ��Ϣ
        ;;
        call store_guest_context

        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        
        DEBUG_RECORD         "[VM-exit]: return back to VMM !"          ; ���� debug ��¼��
        
        call update_guest_context                                       ; ���� debug ��¼�е� guest context

        
        
        ;;
        ;; ��ȡ VM-exit information �ֶ�
        ;;
        call store_exit_info
        
        ;;
        ;; ���� DoProcess �����Ĳ���
        ;;
        REX.Wrxb
        mov eax, [ebp + PCB.CurrentVmbPointer]
        mov esi, [eax + VMB.DoProcessParam]

        ;;
        ;; ��ȡ VM-exit ԭ���룬ת��ִ����Ӧ�Ĵ�������
        ;;
        movzx eax, WORD [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitReason]
        mov eax, [DoVmExitRoutineTable + eax * 4]
        call eax
        
        ;;
        ;; �Ƿ����
        ;;
        cmp eax, VMM_PROCESS_IGNORE
        je VmmEntry.done
        
        ;;
        ;; �Ƿ� RESUME���ص� guest ִ��
        ;;
        cmp eax, VMM_PROCESS_RESUME
        je VmmEntry.resume
        
        ;;
        ;; �Ƿ��״� launch ����
        ;;
        cmp eax, VMM_PROCESS_LAUNCH
        jne VmmEntry.Failure
        
        
        ;;
        ;; ���� launch ����
        ;;
        DEBUG_RECORD    "[VMM]: launch to guest !"
        
        call reset_guest_context                        ; �� guest context ����
        
%ifdef __X64
        DB 65h                                          ; GS
        DB 81h, 0Ch, 25h                                ; OR mem, imme32
        DD PCB.ProcessorStatus
        DD CPU_STATUS_GUEST
%else        
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_GUEST
%endif
        vmlaunch
        jmp VmmEntry.Failure
        
        
VmmEntry.resume:
        
        DEBUG_RECORD    "[VMM]: resume to guest !"

        ;;
        ;; resume ǰ������ָ� guest context ��Ϣ
        ;;
        call restore_guest_context                      ; �ָ� guest context
        
%ifdef __X64
        DB 65h                                          ; GS
        DB 81h, 0Ch, 25h                                ; OR mem, imme32
        DD PCB.ProcessorStatus
        DD CPU_STATUS_GUEST
%else        
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_GUEST
%endif
        vmresume


                        
VmmEntry.Failure:

%ifdef __X64
        DB 65h                          ; GS
        DB 81h, 24h, 25h                ; AND mem, imme32
        DD PCB.ProcessorStatus
        DD ~CPU_STATUS_GUEST
%else
        and DWORD [gs: PCB.ProcessorStatus], ~CPU_STATUS_GUEST
%endif

        DEBUG_RECORD    "[VMM]: dump VMCS !"
        
        sti
        call dump_vmcs

VmmEntry.done:        
        pop ebp
        ret



;-----------------------------------------------------------------------
; DoExceptionNMI()
; input:
;       none
; output:
;       eax - process code
; ������
;       1) ������ exception ���� NMI ������ VM-exit
;-----------------------------------------------------------------------
DoExceptionNMI: 
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        ;;
        ;; ���������ŵ���Ŀ�괦������
        ;;
        movzx eax, BYTE [ebp + PCB.ExitInfoBuf + EXIT_INFO.InterruptionInfo]
        mov eax, [DoExceptionTable + eax * 4]
        call eax

DoExceptionNMI.Done:        
        pop ebp
        ret
        
        



;-----------------------------------------------------------------------
; DoExternalInterrupt()
; input:
;       none
; output:
;       none
; ������
;       1) �������ⲿ�ж������� VM-exit
;-----------------------------------------------------------------------        
DoExternalInterrupt: 
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        DEBUG_RECORD    "[DoExternalInterrupt]: inject an external-interrupt !"
        
        ;;
        ;; ֱ�ӷ����ⲿ�жϸ� guest ����
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InterruptionInfo]
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, eax
        
        mov eax, VMM_PROCESS_RESUME        
        pop ebx
        pop ebx
        ret



;-----------------------------------------------------------------------
; DoTripleFault()
; input:
;       none
; output:
;       none
; ������
;       1) ������ triple fault ������ VM-exit
;----------------------------------------------------------------------- 
DoTripleFault: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        

;-----------------------------------------------------------------------
; DoINIT()
; input:
;       none
; output:
;       none
; ������
;       1) ������ INIT �ź������� VM-exit
;----------------------------------------------------------------------- 
DoINIT:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        GetVmcsField    GUEST_RIP
        cmp eax, 20556h
        mov eax, VMM_PROCESS_RESUME                
        jne DoINIT.done

        call stop_lapic_timer
        mov eax, VMM_PROCESS_DUMP_VMCS         
        
DoINIT.done:
        pop ebp
        ret
        

;-----------------------------------------------------------------------
; DoSIPI()
; input:
;       none
; output:
;       none
; ������
;       1) ������ SIPI �ź������� VM-exit
;----------------------------------------------------------------------- 
DoSIPI: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret



;-----------------------------------------------------------------------
; DoIoSMI()
; input:
;       none
; output:
;       none
; ������
;       1) ������ I/O SMI ������ VM-exit
;----------------------------------------------------------------------- 
DoIoSMI: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret




;-----------------------------------------------------------------------
; DoOtherSMI()
; input:
;       none
; output:
;       none
; ������
;       1) ������ Other SMI ������ VM-exit
;----------------------------------------------------------------------- 
DoOtherSMI:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret




;-----------------------------------------------------------------------
; DoInterruptWindow()
; input:
;       none
; output:
;       none
; ������
;       1) ������ interrupt-window ������ VM-exit
;----------------------------------------------------------------------- 
DoInterruptWindow: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret





;-----------------------------------------------------------------------
; DoNMIWindow()
; input:
;       none
; output:
;       none
; ������
;       1) ������ NMI window ������ VM-exit
;----------------------------------------------------------------------- 
DoNMIWindow: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoTaskSwitch()
; input:
;       none
; output:
;       none
; ������
;       1) ������ task switch ������ VM-exit
;----------------------------------------------------------------------- 
DoTaskSwitch: 
        push ebp
        push ecx
        push edx
        push ebx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

        DEBUG_RECORD    "[DoTaskSwitch]: the VMM to complete the task switching"
        
        ;;
        ;; �ռ������л� VM-exit �������Ϣ
        ;;
        call GetTaskSwitchInfo        
        
        ;;
        ;; ### VMM ��Ҫģ�⴦�����������л����� ###
        ;; ע�⣺
        ;;  1) ����ʹ���¼�ע�����������л���        
        ;;  2) ����ġ���ǰ��ָ��������
        ;;

        mov ecx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.Source]            ;; ������Դ

        ;;
        ;; step 1: ����ǰ�� TSS ������
        ;; a) JMP�� IRET ָ������� busy λ��
        ;; b) CALL, �жϻ��쳣������ busy λ���ֲ��䣨ԭ busy Ϊ 1��
        ;;        
DoTaskSwitch.Step1:
        cmp ecx, TASK_SWITCH_JMP
        je DoTaskSwitch.Step1.ClearBusy
        cmp ecx, TASK_SWITCH_IRET
        jne DoTaskSwitch.Step2              
          
DoTaskSwitch.Step1.ClearBusy:
        ;;
        ;; �嵱ǰ TSS ������ busy λ
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.CurrentTssDesc]
        btr DWORD [ebx + 4], 9
        
        
        ;;
        ;; step 2: �ڵ�ǰ TSS �ﱣ�� context ��Ϣ
        ;;
DoTaskSwitch.Step2:        
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.CurrentTss]  ;; ��ǰ TSS ��
        REX.Wrxb
        mov edx, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov edx, [edx + VMB.VsbBase]                                      ;; ��ǰ VM store block
        
        ;;
        ;; �� VSB ����� guest context ���Ƶ���ǰ TSS ��
        ;;
        mov eax, [edx + VSB.Rax]
        mov [ebx + TSS32.Eax], eax                                       ;; ���� eax
        mov eax, [edx + VSB.Rcx]
        mov [ebx + TSS32.Ecx], eax                                       ;; ���� ecx
        mov eax, [edx + VSB.Rdx]
        mov [ebx + TSS32.Edx], eax                                       ;; ���� edx
        mov eax, [edx + VSB.Rbx]
        mov [ebx + TSS32.Ebx], eax                                       ;; ���� ebx
        mov eax, [edx + VSB.Rsp]
        mov [ebx + TSS32.Esp], eax                                       ;; ���� esp
        mov eax, [edx + VSB.Rbp]
        mov [ebx + TSS32.Ebp], eax                                       ;; ���� ebp
        mov eax, [edx + VSB.Rsi]
        mov [ebx + TSS32.Esi], eax                                       ;; ���� esi
        mov eax, [edx + VSB.Rdi]
        mov [ebx + TSS32.Edi], eax                                       ;; ���� edi
        mov eax, [edx + VSB.Rflags]
        mov [ebx + TSS32.Eflags], eax                                    ;; ���� eflags
        
        ;;
        ;; ע�⣺���� EIP ʱ��Ҫ����ָ���
        ;;
        mov eax, [edx + VSB.Rip]
        add eax, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.InstructionLength]
        mov [ebx + TSS32.Eip], eax                                       ;; ���� eip
                
        ;;
        ;; ��ȡ guest selector �� CR3 �����ڵ�ǰ TSS ��
        ;;
        GetVmcsField    GUEST_CS_SELECTOR
        mov [ebx + TSS32.Cs], ax                                         ;; ���� cs selector
        GetVmcsField    GUEST_ES_SELECTOR
        mov [ebx + TSS32.Es], ax                                         ;; ���� es selector
        GetVmcsField    GUEST_DS_SELECTOR
        mov [ebx + TSS32.Ds], ax                                         ;; ���� ds selector
        GetVmcsField    GUEST_SS_SELECTOR
        mov [ebx + TSS32.Ss], ax                                         ;; ���� ss selector
        GetVmcsField    GUEST_FS_SELECTOR
        mov [ebx + TSS32.Fs], ax                                         ;; ���� fs selector
        GetVmcsField    GUEST_GS_SELECTOR
        mov [ebx + TSS32.Gs], ax                                         ;; ���� gs selector
        GetVmcsField    GUEST_LDTR_SELECTOR
        mov [ebx + TSS32.LdtrSelector], ax                               ;; ���� ldt selector
        GetVmcsField    GUEST_CR3
        mov [ebx + TSS32.Cr3], eax                                       ;; ���� cr3

        
        ;;
        ;; step 3: ����ǰ TSS �ڵ� eflags.NT ��־λ
        ;; a) IRET ָ������� TSS �� eflags.NT λ
        ;; b) CALL, JMP, �жϻ��쳣����TSS �� eflags.NT λ���ֲ���
        ;;        
DoTaskSwitch.Step3:
        cmp ecx, TASK_SWITCH_IRET
        jne DoTaskSwitch.Step4
        ;;
        ;; �嵱ǰ TSS �ڵ� eflags.NT λ
        ;;
        btr DWORD [ebx + TSS32.Eflags], 14
        
        
        ;;
        ;; step 4: ����Ŀ�� TSS �� eflags.NT λ
        ;; a) CALL, �жϻ��쳣������ TSS �ڵ� eflags.NT λ
        ;; b) IRET��JMP ���𣺱��� TSS �ڵ� eflags.NT λ����
        ;;
DoTaskSwitch.Step4:
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]          ;; Ŀ�� TSS ��
        
        cmp ecx, TASK_SWITCH_CALL
        je DoTaskSwitch.Step4.SetNT
        cmp ecx, TASK_SWITCH_GATE
        jne DoTaskSwitch.Step5

DoTaskSwitch.Step4.SetNT:
        ;;
        ;; ��Ŀ�� TSS �� eflags.NT λ
        ;;
        bts DWORD [ebx + TSS32.Eflags], 14

        ;;
        ;; step 5: ����Ŀ�� TSS ������
        ;; a) CALL, JMP, �жϻ��쳣������ busy λ
        ;; b) IRET ����: busy λ���ֲ���
        ;;
DoTaskSwitch.Step5:        
        cmp ecx, TASK_SWITCH_IRET
        je DoTaskSwitch.Step6
        ;;
        ;; ��Ŀ�� TSS ������ busy λ
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTssDesc]
        bts DWORD [ebx + 4], 9
        
        ;;
        ;; step 6: ����Ŀ�� TR �Ĵ���
        ;;
DoTaskSwitch.Step6:        
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTssDesc]    ;; Ŀ�� TSS ������
        mov eax, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTrSelector]     ;; Ŀ�� TSS selector
        
        SetVmcsField    GUEST_TR_SELECTOR, eax
        movzx eax, WORD [edx]                                   ;; ��ȡ limit
        SetVmcsField    GUEST_TR_LIMIT, eax                     ;; ���� TR.limit
        movzx eax, WORD [edx + 5]                               ;; ��ȡ access rights
        and eax, 0F0FFh
        SetVmcsField    GUEST_TR_ACCESS_RIGHTS, eax             ;; ���� TR access rights
        mov eax, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTssBase]
        SetVmcsField    GUEST_TR_BASE, eax                      ;; ���� TR base
        
        
        ;;
        ;; step 7: ����Ŀ������ context
        ;;
DoTaskSwitch.Step7:
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]        ;; Ŀ�� TSS ��
        REX.Wrxb
        mov edx, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov edx, [edx + VMB.VsbBase]                    ;; ��ǰ VM store block        
        
        ;;
        ;; ��Ŀ�� TSS �ڵ�ֵ���Ƶ���ǰ VSB ��
        ;;
        mov eax, [ebx + TSS32.Eax]
        mov [edx + VSB.Rax], eax                        ;; ���� eax     
        mov eax, [ebx + TSS32.Ecx]
        mov [edx + VSB.Rcx], eax                        ;; ���� ecx
        mov eax, [ebx + TSS32.Edx]
        mov [edx + VSB.Rdx], eax                        ;; ���� edx
        mov eax, [ebx + TSS32.Ebx]
        mov [edx + VSB.Rbx], eax                        ;; ���� ebx
        mov eax, [ebx + TSS32.Ebp]
        mov [edx + VSB.Rbp], eax                        ;; ���� ebp
        mov eax, [ebx + TSS32.Esi]
        mov [edx + VSB.Rsi], eax                        ;; ���� esi
        mov eax, [ebx + TSS32.Edi]
        mov [edx + VSB.Rdi], eax                        ;; ���� edi 
        
        ;;
        ;; ���� guest ESP, EIP, EFLAGS, CR3
        ;;
        mov eax, [ebx + TSS32.Esp]
        SetVmcsField    GUEST_RSP, eax                  ;; ���� esp 
        mov eax, [ebx + TSS32.Cr3]
        SetVmcsField    GUEST_CR3, eax                  ;; ���� cr3
        mov eax, [ebx + TSS32.Eip]
        SetVmcsField    GUEST_RIP, eax                  ;; ���� eip
        mov eax, [ebx + TSS32.Eflags] 
        SetVmcsField    GUEST_RFLAGS, eax               ;; ���� eflags
        
        ;;
        ;; ���� SS
        ;;
        mov esi, [ebx + TSS32.Ss]
        call load_guest_ss_register
        cmp eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jne DoTaskSwitch.Done
        
        ;;
        ;; ���� CS
        ;;
        mov esi, [ebx + TSS32.Cs]
        call load_guest_cs_register
        cmp eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jne DoTaskSwitch.Done
        
        ;;
        ;; ���� ES
        ;;
        mov esi, [ebx + TSS32.Es]
        call load_guest_es_register
        cmp eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jne DoTaskSwitch.Done
        
        ;;
        ;; ���� DS
        ;;
        mov esi, [ebx + TSS32.Ds]
        call load_guest_ds_register
        cmp eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jne DoTaskSwitch.Done
        
        ;;
        ;; ���� FS
        ;;        
        mov esi, [ebx + TSS32.Fs]
        call load_guest_fs_register
        cmp eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jne DoTaskSwitch.Done
                
        ;;
        ;; ���� GS
        ;;
        mov esi, [ebx + TSS32.Gs]
        call load_guest_gs_register        
        cmp eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jne DoTaskSwitch.Done
        
        ;;
        ;; ���� LDTR
        ;;        
        mov esi, [ebx + TSS32.LdtrSelector]
        call load_guest_ldtr_register
        cmp eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jne DoTaskSwitch.Done
                                
        ;;
        ;; step 8: ��Ŀ�� TSS �ڱ��浱ǰ TR selector
        ;;
DoTaskSwitch.Step8:
        mov eax, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.CurrentTrSelector]
        mov [ebx + TSS32.TaskLink], ax                                  ;; ���� task link

        ;;
        ;; step 9: ���� CR0.TS λ
        ;;
DoTaskSwitch.Step9:
        GetVmcsField    GUEST_CR0
        or eax, CR0_TS
        SetVmcsField    GUEST_CR0, eax

DoTaskSwitch.Done:
        mov eax, VMM_PROCESS_RESUME
        pop ebx
        pop edx
        pop ecx
        pop ebp
        ret
        




;-----------------------------------------------------------------------
; DoCPUID()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� CPUID ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoCPUID: 
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        DEBUG_RECORD    '[DoCPUID]: virtualize CPUID!'
        
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebp, [ebp + VMB.VsbBase]
        
        ;;
        ;; �� VMM ����һ�� CPUID ���⻯����� guest
        ;;
        mov eax, [ebp + VSB.Rax]                                        ; ��ȡ CPUID ���ܺ�
        cpuid                                                           ; ִ�� CPUID ָ��
        mov eax, 633h                                                   ; �޸� guest CPU ���ͺ�

        ;;
        ;; �� CPUID �������� guest
        ;;        
        REX.Wrxb
        mov [ebp + VSB.Rax], eax
        REX.Wrxb
        mov [ebp + VSB.Rbx], ebx
        REX.Wrxb
        mov [ebp + VSB.Rcx], ecx
        REX.Wrxb
        mov [ebp + VSB.Rdx], edx                        
        
        ;;
        ;; ���� guest-RIP
        ;;
        call update_guest_rip
        
        mov eax, VMM_PROCESS_RESUME                                     ; ֪ͨ VMM ���� RESUME ����
    
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------------------------
; DoGETSEC()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� GETSEC ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoGETSEC: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret


;-----------------------------------------------------------------------
; DoHLT()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� HLT ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoHLT:
        DEBUG_RECORD    "[DoHLT]: enter HLT state"
        
        ;;
        ;; �� guest ����Ϊ HLT ״̬
        ;;
        SetVmcsField    GUEST_ACTIVITY_STATE, GUEST_STATE_HLT
        
        mov eax, VMM_PROCESS_RESUME
        ret
        
        
        

;-----------------------------------------------------------------------
; DoINVD()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� INVD ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoINVD:
        ;;
        ;; VMM ֱ��ִ�� INVD ָ��
        ;;
        invd
        call update_guest_rip
        
        DEBUG_RECORD    "[DoINVD]: execute INVD !"
        
        mov eax, VMM_PROCESS_RESUME
        ret
        
        
        

;-----------------------------------------------------------------------
; DoINVLPG()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� INVLPG ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoINVLPG: 
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        


        
        DEBUG_RECORD    "[DoINVLPG]: invalidate the cache !"
        
        ;;
        ;; ��ȡ��ǰ VPID ֵ
        ;;
        GetVmcsField    CONTROL_VPID
        
        ;;
        ;; INVVPID ������
        ;;
        mov [ebp + PCB.InvDesc + INV_DESC.Vpid], eax
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword1], 0
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword3], 0        
        REX.Wrxb
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        REX.Wrxb
        mov [ebp + PCB.InvDesc + INV_DESC.LinearAddress], eax
        
        ;;
        ;; ʹ��ˢ������ individual-address invalidation
        ;;
        mov eax, INDIVIDUAL_ADDRESS_INVALIDATION
        invvpid eax, [ebp + PCB.InvDesc]
        
        call update_guest_rip
        mov eax, VMM_PROCESS_RESUME
        
        pop ebp
        ret



;-----------------------------------------------------------------------
; DoRDPMC()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� RDPMC ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoRDPMC: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoRDTSC()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� RDTSC ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoRDTSC: 
        DEBUG_RECORD    "[DoRDTSC]: processing RDTSC"
        
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoRSM()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� RSM ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoRSM: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoVMCALL()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMCALL ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMCALL:
        push ebp
        push ebx
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif    
        
        ;LOADv   esi, 0FFFF800081000000h
        ;mov edi, 0
        ;call dump_guest_longmode_paging_structure64
        ;jmp $
        ;REX.Wrxb
        ;mov ebx, [ebp + PCB.CurrentVmbPointer]
        ;REX.Wrxb
        ;mov ebx, [ebx + VMB.VsbBase]
        ;REX.Wrxb
        ;mov esi, [ebx + VSB.Rbx]
        ;call get_system_va_of_guest_os
        ;REX.Wrxb
        ;mov esi, eax
        ;call dump_memory
        
        mov eax, VMM_PROCESS_DUMP_VMCS
        pop ebx
        pop ebp
        ret


;-----------------------------------------------------------------------
; DoVMCLEAR()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMCLEAR ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMCLEAR: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret



;-----------------------------------------------------------------------
; DoVMLAUNCH()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMLAUNCH ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMLAUNCH: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoVMPTRLD()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMPTRLD ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMPTRLD: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret



;-----------------------------------------------------------------------
; DoVMPTRST()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMPTRST ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMPTRST: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        

;-----------------------------------------------------------------------
; DoVMREAD()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMREAD ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMREAD: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoVMRESUME()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMRESUME ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMRESUME:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        
        
;-----------------------------------------------------------------------
; DoVMWRITE()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMWRITE ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMWRITE: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoVMXOFF()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMXOFF ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMXOFF:
        call update_guest_rip
        mov eax, VMM_PROCESS_RESUME
        ret
        
        


;-----------------------------------------------------------------------
; DoVMXON()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� VMXON ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMXON: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        
        

;-----------------------------------------------------------------------
; DoControlRegisterAccess()
; input:
;       none
; output:
;       none
; ������
;       1) �����Է��� control �Ĵ��������� VM-exit
;----------------------------------------------------------------------- 
DoControlRegisterAccess: 
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
               
        ;;
        ;; �ռ��� MOV-CR VM-exit �������Ϣ
        ;;
        call GetMovCrInfo
        
        
        
        ;;
        ;; ### ���� MOV-CR ָ����Ϣ���� 4 ��ָ�� ###
        ;; 1) MOV to CRn ָ��
        ;; 2) MOV from CRn ָ��
        ;; 3) CLTS ָ��
        ;; 4) LMSW ָ��
        ;;          
        mov ecx, [ebp + PCB.GuestExitInfo + MOV_CR_INFO.Type]        

        cmp ecx, CAT_MOV_FROM_CR
        je DoControlRegisterAccess.MovFromCr            ; ���� MOV from CR ָ��
        cmp ecx, CAT_CLTS
        je DoControlRegisterAccess.Clts                 ; ���� CLTS ָ��        
        cmp ecx, CAT_LMSW
        je DoControlRegisterAccess.Lmsw                 ; ���� LMSW ָ��
        
        ;;
        ;; ���� MOV-to-CR ָ��
        ;;        
DoControlRegisterAccess.MovToCr:        
        ;;
        ;; ��ȡĿ����ƼĴ���ID ��Դ�Ĵ���ֵ
        ;;
        mov ebx, [ebp + PCB.GuestExitInfo + MOV_CR_INFO.ControlRegisterID]      ; ebx = CRn
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + MOV_CR_INFO.Register]               ; edx = register

        ;;
        ;; ����Ŀ����ƼĴ���������ȡԴ�Ĵ���ֵ
        ;;                
        cmp ebx, 0
        je DoControlRegisterAccess.MovToCr.@0
        cmp ebx, 4
        je DoControlRegisterAccess.MovToCr.@4

        ;;
        ;; ### ���� MOV-to-CR3 ָ�� ###
        ;;
        DEBUG_RECORD    "[DoControlRegisterAccess]: processing MOV to CR3"
        
        mov eax, GUEST_CR3
        
        ;;
        ;; ʹ�� single-context invalidateion, retaining-global ��ʽˢ�� cache
        ;;
        mov ebx, SINGLE_CONTEXT_EXCLUDE_GLOBAL_INVALIDATION
        
DoControlRegisterAccess.MovToCr.SetCr:
        ;;
        ;; д��Ŀ����ƼĴ���ֵ
        ;;
        DoVmWrite       eax, [ebp + PCB.GuestExitInfo + MOV_CR_INFO.Register]
        jmp DoControlRegisterAccess.Next


DoControlRegisterAccess.MovToCr.@0:
        ;;
        ;; ���� MOV-to-CR0 ָ��
        ;;
        DEBUG_RECORD    "[DoControlRegisterAccess]: processing MOV to CR0"        
        
        ;;
        ;; ��ȡ CR0 guest/host mask �� read shadow
        ;;
        DoVmRead        CONTROL_CR0_GUEST_HOST_MASK, [ebp + PCB.ExecutionControlBuf + EXECUTION_CONTROL.Cr0GuestHostMask]
        DoVmRead        CONTROL_CR0_READ_SHADOW, [ebp + PCB.ExecutionControlBuf + EXECUTION_CONTROL.Cr0ReadShadow]
        
        ;;
        ;; ������ĸ�λ���� VM-exit
        ;; 1) X = source ^ ReadShadow
        ;; 2) Y = X & GuestHostMask
        ;; 3) ��� Y ֵ
        ;;
        mov eax, edx
        mov esi, [ebp + PCB.ExecutionControlBuf + EXECUTION_CONTROL.Cr0ReadShadow]
        xor eax, esi
        and eax, [ebp + PCB.ExecutionControlBuf + EXECUTION_CONTROL.Cr0GuestHostMask]       
        

        test eax, (CR0_PE | CR0_PG)
        jnz DoControlRegisterAccess.MovToCr.@0.PG_PE
        test eax, CR0_NE
        jnz DoControlRegisterAccess.MovToCr.@0.NE
        test eax, (CR0_CD | CR0_NW)
        jnz DoControlRegisterAccess.MovToCr.@0.CD_NW

DoControlRegisterAccess.MovToCr.@0.PG_PE:
        mov ebx, SINGLE_CONTEXT_INVALIDATION
        jmp DoControlRegisterAccess.Next
        
DoControlRegisterAccess.MovToCr.@0.NE:        
        mov ebx, SINGLE_CONTEXT_INVALIDATION
        jmp DoControlRegisterAccess.Next
                
DoControlRegisterAccess.MovToCr.@0.CD_NW:
        ;;
        ;; ��� CR0.CD �� CR0.NW ������
        ;; 1) ������� CR0.CD = 0��CR0.NW = 1 ʱ��ֱ��ע�� #GP(0) �쳣�� guest OS
        ;;
        mov eax, edx
        and eax, (CR0_CD | CR0_NW)
        cmp eax, CR0_NW
        jne DoControlRegisterAccess.MovToCr.@0.CD_NW.@1
        
        ;;
        ;; ע�� #GP(0) �쳣
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_GP
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0
        
        mov eax, VMM_PROCESS_RESUME
        jmp DoControlRegisterAccess.Done
        
DoControlRegisterAccess.MovToCr.@0.CD_NW.@1:
        ;;
        ;; ���� CR0 �Ĵ���ֵ
        ;;
        and edx, (CR0_CD | CR0_NW)
        mov eax, cr0
        or eax, edx
        mov cr0, eax
                
        ;;
        ;; �����µ� CR0.CD/CR0.NW λ read shadow ֵ
        ;;
        and esi, ~(CR0_CD | CR0_NW)
        or edx, esi
        SetVmcsField    CONTROL_CR0_READ_SHADOW, edx
        
        
        mov ebx, SINGLE_CONTEXT_INVALIDATION
        
        jmp DoControlRegisterAccess.Next


DoControlRegisterAccess.MovToCr.@4:
        ;;
        ;; ʹ�� single-context invalidateion ��ʽˢ�� cache
        ;;
        mov ebx, SINGLE_CONTEXT_INVALIDATION
        
        DEBUG_RECORD    '[DoControlRegisterAccess]: processing MOV to CR4'   
        jmp DoControlRegisterAccess.Next
        
        
        
        
DoControlRegisterAccess.MovFromCr:
        ;;
        ;; ���� MOV from CR ָ��
        ;;
        ;; ע�⣺
        ;; 1) ������� MOV-from-CR8 ָ�� !
        ;; 2) ֻ�� MOV-from-CR3 ָ����Ҫ���� !
        ;;        
        
        ;;
        ;; ��Դ���ƼĴ���ֵд��Ŀ��Ĵ�����
        ;;
        REX.Wrxb
        mov esi, [ebp + PCB.GuestExitInfo + MOV_CR_INFO.ControlRegister]
        REX.Wrxb
        mov edi, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov edi, [edi + VMB.VsbBase]
        mov eax, [ebp + PCB.GuestExitInfo + MOV_CR_INFO.RegisterID]
        REX.Wrxb
        mov [edi + VSB.Context + eax * 8], esi
                
        jmp DoControlRegisterAccess.Resume


DoControlRegisterAccess.Clts:
        ;;
        ;; ������ CLTS ָ�������� VM-exit
        ;;
        jmp DoControlRegisterAccess.Next

DoControlRegisterAccess.Lmsw:  
        ;;
        ;; ���� LMSW ָ��
        ;;
        jmp DoControlRegisterAccess.Next




DoControlRegisterAccess.Next:        
        ;;
        ;; ˢ�� cache
        ;;
        GetVmcsField    CONTROL_VPID
        mov [ebp + PCB.InvDesc + INV_DESC.Vpid], eax
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword1], 0
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword2], 0
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword3], 0

        invvpid ebx, [ebp + PCB.InvDesc]
        
        DEBUG_RECORD    "[DoControlRegisterAccess]: invalidate cache !"

DoControlRegisterAccess.Resume:        
        ;;
        ;; ���� MOV-CR ָ��
        ;;
        call update_guest_rip
        
        mov eax, VMM_PROCESS_RESUME

DoControlRegisterAccess.Done:        
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        



;-----------------------------------------------------------------------
; DoMovDr()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� MOV-DR ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoMovDr: 
        call update_guest_rip
        mov eax, VMM_PROCESS_RESUME
        ret
        
        
        

;-----------------------------------------------------------------------
; DoIoInstruction()
; input:
;       none
; output:
;       none
; ������
;       1) ������ I/O ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoIoInstruction:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        ;DEBUG_RECORD    "[DoIoInstruction]: ignore execution of I/O instruction !"
        
        call get_io_instruction_info                    ;; �ռ� IO ָ����Ϣ

        
        ;;
        ;; ִ�� IO ����
        ;;
        call do_guest_io_process
        
        
        ;;
        ;; ���� I/O ָ��
        ;;
        call update_guest_rip
        
        mov eax, VMM_PROCESS_RESUME        
        pop ebx
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; DoRDMSR()
; input:
;       none
; output:
;       none
; ������
;       1) ������ RDMSR ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoRDMSR: 
        push ebp
        push ebx
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
        ;; ��ȡ MSR index
        ;;
        mov ecx, [ebx + VSB.Rcx]
        cmp ecx, IA32_APIC_BASE
        jne DoRDMSR.@1
        
        ;;
        ;; �������� IA32_APIC_BASE
        ;;
        call DoReadMsrForApicBase

DoRDMSR.@1:
        
DoRDMSR.Done:
        mov eax, VMM_PROCESS_RESUME        
        pop ecx
        pop ebx
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; DoWRMSR()
; input:
;       none
; output:
;       none
; ������
;       1) ������ WRMSR ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoWRMSR:
        push ebp
        push ebx
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
        ;; ��ȡ MSR index
        ;;
        mov ecx, [ebx + VSB.Rcx]
        cmp ecx, IA32_APIC_BASE
        jne DoWRMSR.@1
        
        ;;
        ;; ����д IA32_APIC_BASE �Ĵ���
        ;;
        call DoWriteMsrForApicBase

DoWRMSR.@1:        
        
DoWRMSR.Done:
        mov eax, VMM_PROCESS_RESUME                
        pop ecx
        pop ebx
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; DoInvalidGuestState()
; input:
;       none
; output:
;       none
; ������
;       1) ����������Ч guest-state �ֶε��� VM-entry ʧ�������� VM-exit
;----------------------------------------------------------------------- 
DoInvalidGuestState: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        

;-----------------------------------------------------------------------
; DoMSRLoading()
; input:
;       none
; output:
;       none
; ������
;       1) �����ڼ��� guest MSR ������VM-entryʧ�������� VM-exit
;----------------------------------------------------------------------- 
DoMSRLoading: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoMWAIT()
; input:
;       none
; output:
;       none
; ������
;       1) ������ MWAIT ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoMWAIT:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoMTF()
; input:
;       esi - DO process ����
; output:
;       none
; ������
;       1) ������ pending MTF VM-exit ������ VM-exit
;----------------------------------------------------------------------- 
DoMTF:
        push ebp
        push ebx
        push edx
        push ecx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif


        
        ;;
        ;; �������Ҫdecode��������
        ;;
        cmp esi, DO_PROCESS_DECODE
        jne DoMTF.done
        
        
        ;;
        ;; ���� guest ����
        ;;        
        mov eax, [ebp + PCB.EntryControlBuf + ENTRY_CONTROL.VmEntryControl]
        mov edx, [ebp + PCB.GuestStateBuf + GUEST_STATE.CsAccessRight]        
        test eax, IA32E_MODE_GUEST
        jz DoMTF.@1
        test edx, SEG_L
        jz DoMTF.@1                
        mov eax, TARGET_CODE64        
        jmp DoMTF.@2
DoMTF.@1: 
        mov eax, TARGET_CODE32       
        test edx, SEG_D
        jnz DoMTF.@2
        mov eax, TARGET_CODE16
DoMTF.@2:
        

        
        REX.Wrxb
        mov ebp, [ebp + PCB.SdaBase]
        REX.Wrxb
        mov ebx, [ebp + SDA.DmbBase]
        
        mov [ebx + DMB.TargetCpuMode], eax

        ;;
        ;; �� GuestRip ������ decode
        ;;        
        mov esi, [ebx + DMB.DecodeEntry]
        test esi, esi
        jz DoMTF.done
        REX.Wrxb
        mov edi, [ebx + DMB.DecodeBufferPtr]
        call Decode
        test eax, DECODE_STATUS_FAILURE
        jnz DoMTF.done
        
        REX.Wrxb
        mov edx, edi
        
        ;;
        ;; ���� debug record ��Ϣ
        ;;
        mov eax, [ebx + DMB.DecodeEntry]
        xor edi, edi
        REX.Wrxb
        mov esi, [ebx + DMB.DecodeBufferPtr]
        call update_append_msg
        
        REX.Wrxb
        mov [ebx + DMB.DecodeBufferPtr], edx
        
        ;;
        ;; ָ�� guest ��һ��ָ��
        ;;
        GetVmcsField    GUEST_RIP
        mov [ebx + DMB.DecodeEntry], eax
                        
        mov ecx, VMM_PROCESS_RESUME

DoMTF.done:      
        mov eax, ecx
        pop ecx
        pop edx
        pop ebx
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; DoMONITOR()
; input:
;       none
; output:
;       none
; ������
;       1) ������ MONITOR ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoMONITOR: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoPAUSE()
; input:
;       none
; output:
;       none
; ������
;       1) ������ PAUSE ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoPAUSE: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        

;-----------------------------------------------------------------------
; DoMachineCheck()
; input:
;       none
; output:
;       none
; ������
;       1) ������ machine check event ������ VM-exit
;----------------------------------------------------------------------- 
DoMachineCheck:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        

;-----------------------------------------------------------------------
; DoTPRThreshold()
; input:
;       none
; output:
;       none
; ������
;       1) ������ VPTR ���� TPR threshold ������ VM-exit
;----------------------------------------------------------------------- 
DoTPRThreshold: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoAPICAccessPage()
; input:
;       none
; output:
;       none
; ������
;       1) �����ɷ��� APIC-access page ҳ�������� VM-exit
;----------------------------------------------------------------------- 
DoAPICAccessPage: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        


;-----------------------------------------------------------------------
; DoEOIBitmap()
; input:
;       none
; output:
;       none
; ������
;       1) ������ EOI exit bitmap ������ VM-exit
;----------------------------------------------------------------------- 
DoEOIBitmap: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        

;-----------------------------------------------------------------------
; DoGDTR_IDTR()
; input:
;       none
; output:
;       none
; ������
;       1) �����Է��� GDTR/IDTR ������ VM-exit
;----------------------------------------------------------------------- 
DoGDTR_IDTR: 
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
        lea edx, [ebp + PCB.GuestExitInfo]
        
        ;;
        ;; �ռ���Ϣ
        ;;
        call GetDescTableRegisterInfo

        xor ebx, ebx
        
DoGDTR_IDTR.GetLinearAddress:        

        ;;
        ;; �������Ե�ֵַ�������ڴ�������� base, index �� scale
        ;;
        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_BASE
        jnz DoGDTR_IDTR.GetLinearAddress.@1        
        
        ;;
        ;; ��ȡ base �Ĵ���ֵ
        ;;
        mov esi, [edx + INSTRUCTION_INFO.Base]
        call get_guest_register_value
        REX.Wrxb
        mov ebx, eax

DoGDTR_IDTR.GetLinearAddress.@1:
        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_INDEX
        jnz DoGDTR_IDTR.GetLinearAddress.@2
        
        ;;
        ;; ��ȡ index �Ĵ���ֵ
        ;;
        mov esi, [edx + INSTRUCTION_INFO.Index]
        call get_guest_register_value
        
        ;;
        ;; ��� scale ֵ
        ;;
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_0
        jne DoGDTR_IDTR.GetLinearAddress.Check2
        REX.Wrxb
        lea ebx, [ebx + eax]
        jmp DoGDTR_IDTR.GetLinearAddress.@2
        
DoGDTR_IDTR.GetLinearAddress.Check2:
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_2
        jne DoGDTR_IDTR.GetLinearAddress.Check4
        REX.Wrxb
        lea ebx, [ebx + eax * 2]
        jmp DoGDTR_IDTR.GetLinearAddress.@2
        
DoGDTR_IDTR.GetLinearAddress.Check4:
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_4
        jne DoGDTR_IDTR.GetLinearAddress.Check8
        REX.Wrxb
        lea ebx, [ebx + eax * 4]
        jmp DoGDTR_IDTR.GetLinearAddress.@2        

DoGDTR_IDTR.GetLinearAddress.Check8:
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_8
        jne DoGDTR_IDTR.GetLinearAddress.@2
        REX.Wrxb
        lea ebx, [ebx + eax * 8]
                        
DoGDTR_IDTR.GetLinearAddress.@2:
        ;;
        ;; Linear address = base + index * scale + disp
        ;;
        mov eax, [edx + INSTRUCTION_INFO.Displacement]
        REX.Wrxb
        lea ebx, [ebx + eax]

        ;;
        ;; ���� address size���õ����յ����Ե�ֵַ
        ;;
        mov eax, [edx + INSTRUCTION_INFO.AddressSize]
        cmp eax, INSTRUCTION_ADRS_WORD
        jne DoGDTR_IDTR.GetLinearAddress.CheckAddr32
        
        movzx ebx, bx                                   ;; 16 λ��ַ
        jmp DoGDTR_IDTR.GetLinearAddress.GetHostVa

DoGDTR_IDTR.GetLinearAddress.CheckAddr32:
        cmp eax, INSTRUCTION_ADRS_DWORD
        jne DoGDTR_IDTR.GetLinearAddress.GetHostVa
        
        or ebx, ebx                                    ;; 32 λ��ֵַ

DoGDTR_IDTR.GetLinearAddress.GetHostVa:
        ;;
        ;; �õ� host �������ַ
        ;;
        REX.Wrxb
        mov esi, ebx
        call get_system_va_of_guest_os
        REX.Wrxb
        mov ebx, eax
        REX.Wrxb
        test eax, eax
        jnz DoGDTR_IDTR.CheckType
        
        ;;
        ;; ��ַ��Ч��ע�� #PF �쳣
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_PF
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0
        mov eax, VMM_PROCESS_RESUME
        jmp DoGDTR_IDTR.Done
        
        
DoGDTR_IDTR.CheckType:
        REX.Wrxb
        mov ecx, [ebp + PCB.CurrentVmbPointer]
        
        ;;
        ;; ����ָ�
        ;; 1) SGDT������ gdt pointer 
        ;; 2) SIDT������ idt pointer
        ;; 3) LGDT: ���� gdt pointer
        ;; 4) LIDT: ���� idt pointer
        ;;        
        mov eax, [edx + INSTRUCTION_INFO.Type]
        cmp eax, INSTRUCTION_TYPE_SGDT
        REX.Wrxb
        lea esi, [ecx + VMB.GuestGmb + GGMB.GdtPointer]         
        je DoGDTR_IDTR.SgdtSidt
        cmp eax, INSTRUCTION_TYPE_SIDT
        REX.Wrxb
        lea esi, [ecx + VMB.GuestImb + GIMB.IdtPointer]         
        je DoGDTR_IDTR.SgdtSidt       
        cmp eax, INSTRUCTION_TYPE_LGDT
        je DoGDTR_IDTR.Lgdt
        cmp eax, INSTRUCTION_TYPE_LIDT   
        je DoGDTR_IDTR.Lidt


DoGDTR_IDTR.SgdtSidt:
        ;;
        ;; ���� SGDT �� SIDT ָ����� GDT/IDT pointer
        ;;
        mov ax, [esi]
        mov [ebx], ax
        mov eax, [esi + 2]
        mov [ebx + 2], eax

        ;;
        ;; ��� operand size������� 64 λ��д�� 10 bytes
        ;;
        cmp DWORD [edx + INSTRUCTION_INFO.OperandSize], INSTRUCTION_OPS_QWORD
        jne DoGDTR_IDTR.Done
        mov eax, [esi + 6]
        mov [ebx + 6], eax
        jmp DoGDTR_IDTR.Done        

        
DoGDTR_IDTR.Lgdt:
        DEBUG_RECORD    "[DoGDTR_IDTR]: load GDTR"
        
        ;;
        ;; ���� LGDT ָ�д�� GGMB.GdtPointer �Լ����� guest GDTR
        ;;
        REX.Wrxb
        lea ecx, [ecx + VMB.GuestGmb + GGMB.GdtPointer]
        movzx eax, WORD [ebx]        
        mov [ecx], ax                                           ; ���� GDTR.limit
        SetVmcsField    GUEST_GDTR_LIMIT, eax                   ; ���� guest GDTR.limit
        mov eax, [ebx + 2]
        and eax, 00FFFFFFh
        cmp DWORD [edx + INSTRUCTION_INFO.OperandSize], INSTRUCTION_OPS_WORD
        cmovne eax, [ebx + 2]
        cmp DWORD [edx + INSTRUCTION_INFO.OperandSize], INSTRUCTION_OPS_QWORD
        REX.Wrxb
        cmove eax, [ebx + 2]
        REX.Wrxb
        mov [ecx + 2], eax                                      ; ���� GDTR.base
        SetVmcsField    GUEST_GDTR_BASE, eax                    ; ���� guest GDTR.base
        jmp DoGDTR_IDTR.Done

DoGDTR_IDTR.Lidt:        
        DEBUG_RECORD    "[DoGDTR_IDTR]: load IDTR"
        
        ;;
        ;; ���� LIDT ָ�д�� GIMB.IdtPointer �Լ����� guest IDTR
        ;;
        REX.Wrxb
        lea ecx, [ecx + VMB.GuestImb + GIMB.IdtPointer]
        movzx eax, WORD [ebx]        
        mov [ecx + GIMB.IdtLimit], ax                           ; ���� guest ԭ IDTR.limit

        ;;
        ;; �� IA-32e ģʽ���� 1FFh������Ϊ 0FFh
        ;;
        GetVmcsField    GUEST_IA32_EFER_FULL
        mov esi, (31 * 8 + 7)
        test eax, EFER_LMA
        mov eax, (31 * 16 + 15)
        cmovz eax, esi
        
        ;;
        ;; ���� guest IDTR.limit
        ;;        
        SetVmcsField    GUEST_IDTR_LIMIT, eax                  ; ���� guest IDTR.limit
        mov WORD [ecx + GIMB.HookIdtLimit], ax                 ; ���� VMM ���õ� IDTR.limit
        mov eax, [ebx + 2]
        and eax, 00FFFFFFh
        cmp DWORD [edx + INSTRUCTION_INFO.OperandSize], INSTRUCTION_OPS_WORD
        cmovne eax, [ebx + 2]
        cmp DWORD [edx + INSTRUCTION_INFO.OperandSize], INSTRUCTION_OPS_QWORD
        REX.Wrxb
        cmove eax, [ebx + 2]
        REX.Wrxb
        mov [ecx + GIMB.IdtBase], eax                           ; ���� guest ԭ IDTR.base
        SetVmcsField    GUEST_IDTR_BASE, eax                    ; ���� guest IDTR.base
        
DoGDTR_IDTR.Done:
        call update_guest_rip        
        mov eax, VMM_PROCESS_RESUME
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; DoLDTR_TR()
; input:
;       none
; output:
;       none
; ������
;       1) �����Է��� LDTR/TR ������ VM-exit
;----------------------------------------------------------------------- 
DoLDTR_TR: 
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
                
        call GetDescTableRegisterInfo

        REX.Wrxb
        lea edx, [ebp + PCB.GuestExitInfo]
   
        ;;
        ;; �����������ͣ�
        ;; 1) �ڴ��������������Ե�ֵַ
        ;; 2) �Ĵ��������������ȡ�Ĵ���ֵ
        ;;
        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_REG
        jnz DoLDTR_TR.GetRegister

        xor ebx, ebx

        ;;
        ;; �������Ե�ֵַ�������ڴ�������� base, index �� scale
        ;;
        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_BASE
        jnz DoLDTR_TR.GetLinearAddress.@1        
        
        ;;
        ;; ��ȡ base �Ĵ���ֵ
        ;;
        mov esi, [edx + INSTRUCTION_INFO.Base]
        call get_guest_register_value
        REX.Wrxb
        mov ebx, eax

DoLDTR_TR.GetLinearAddress.@1:
        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_INDEX
        jnz DoLDTR_TR.GetLinearAddress.@2
        
        ;;
        ;; ��ȡ index �Ĵ���ֵ
        ;;
        mov esi, [edx + INSTRUCTION_INFO.Index]
        call get_guest_register_value
        
        ;;
        ;; ��� scale ֵ
        ;;
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_0
        jne DoLDTR_TR.GetLinearAddress.Check2
        REX.Wrxb
        lea ebx, [ebx + eax]
        jmp DoLDTR_TR.GetLinearAddress.@2
        
DoLDTR_TR.GetLinearAddress.Check2:
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_2
        jne DoLDTR_TR.GetLinearAddress.Check4
        REX.Wrxb
        lea ebx, [ebx + eax * 2]
        jmp DoLDTR_TR.GetLinearAddress.@2
        
DoLDTR_TR.GetLinearAddress.Check4:
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_4
        jne DoLDTR_TR.GetLinearAddress.Check8
        REX.Wrxb
        lea ebx, [ebx + eax * 4]
        jmp DoLDTR_TR.GetLinearAddress.@2        

DoLDTR_TR.GetLinearAddress.Check8:
        cmp DWORD [edx + INSTRUCTION_INFO.Scale], SCALE_8
        jne DoLDTR_TR.GetLinearAddress.@2
        REX.Wrxb
        lea ebx, [ebx + eax * 8]
                        
DoLDTR_TR.GetLinearAddress.@2:
        ;;
        ;; Linear address = base + index * scale + disp
        ;;
        mov eax, [edx + INSTRUCTION_INFO.Displacement]
        REX.Wrxb
        lea ebx, [ebx + eax]
        ;;
        ;; ���� address size���õ����յ����Ե�ֵַ
        ;;
        mov eax, [edx + INSTRUCTION_INFO.AddressSize]
        cmp eax, INSTRUCTION_ADRS_WORD
        jne DoLDTR_TR.GetLinearAddress.CheckAddr32
        
        movzx ebx, bx                                   ;; 16 λ��ַ
        jmp DoLDTR_TR.GetLinearAddress.GetHostVa

DoLDTR_TR.GetLinearAddress.CheckAddr32:
        cmp eax, INSTRUCTION_ADRS_DWORD
        jne DoLDTR_TR.GetLinearAddress.GetHostVa
        
        or ebx, ebx                                    ;; 32 λ��ֵַ

DoLDTR_TR.GetLinearAddress.GetHostVa:
        ;;
        ;; ��ȡ selector
        ;;
        REX.Wrxb
        mov esi, ebx
        call get_system_va_of_guest_os
        REX.Wrxb
        mov ebx, eax
        REX.Wrxb
        test eax, eax
        jnz DoLDTR_TR.CheckType

        ;;
        ;; ��ַ��Ч��ע�� #PF �쳣
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_PF
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0
        mov eax, VMM_PROCESS_RESUME
        jmp DoLDTR_TR.Done
        
DoLDTR_TR.GetRegister:        
        ;;
        ;; ��ȡ�Ĵ���ֵ
        ;;
        mov esi, [edx + INSTRUCTION_INFO.Register]
        call get_guest_register_value
        movzx esi, ax
        

DoLDTR_TR.CheckType:
        ;;
        ;; ���ָ������
        ;;
        mov eax, [edx + INSTRUCTION_INFO.Type]        
        cmp eax, INSTRUCTION_TYPE_SLDT
        je DoLDTR_TR.Sldt
        cmp eax, INSTRUCTION_TYPE_STR
        je DoLDTR_TR.Str       
        cmp eax, INSTRUCTION_TYPE_LLDT
        mov edi, do_load_ldtr_register
        je DoLDTR_TR.LldtLtr
        cmp eax, INSTRUCTION_TYPE_LTR
        mov edi, do_load_tr_register
        je DoLDTR_TR.LldtLtr


DoLDTR_TR.Sldt:
        ;;
        ;; ���� SLDT ָ��
        ;;
        DEBUG_RECORD    "[DoLDTR_TR]: store LDTR"
        
        GetVmcsField    GUEST_LDTR_SELECTOR
        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_REG
        jnz DoLDTR_TR.Sldt.@1
        mov [ebx], ax
        jmp DoLDTR_TR.Resume
        
DoLDTR_TR.Sldt.@1:        
        mov esi, [edx + INSTRUCTION_INFO.Register]
        mov edi, eax
        call set_guest_register_value
        jmp DoLDTR_TR.Resume
        
DoLDTR_TR.Str:
        ;;
        ;; ���� STR ָ��
        ;;
        DEBUG_RECORD    "[DoLDTR_TR]: store TR"
        
        GetVmcsField    GUEST_TR_SELECTOR
        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_REG
        jnz DoLDTR_TR.Str.@1
        mov [ebx], ax
        jmp DoLDTR_TR.Resume
        
DoLDTR_TR.Str.@1:        
        mov esi, [edx + INSTRUCTION_INFO.Register]
        mov edi, eax
        call set_guest_register_value
        jmp DoLDTR_TR.Resume
        
        
DoLDTR_TR.LldtLtr:        
        ;;
        ;; ���� LLDT �� LTR ָ��
        ;;
        DEBUG_RECORD    "[DoLDTR_TR]: load LDTR or TR"

        test DWORD [edx + INSTRUCTION_INFO.Flags], INSTRUCTION_FLAGS_REG
        jnz DoLDTR_TR.LldtLtr.@1
        movzx esi, WORD [ebx]        
DoLDTR_TR.LldtLtr.@1:
        call edi
        cmp eax, LOAD_LDTR_TR_SUCCESS
        jne DoLDTR_TR.Done

        
DoLDTR_TR.Resume:
        call update_guest_rip        
  
DoLDTR_TR.Done: 
        mov eax, VMM_PROCESS_RESUME      
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; DoEptViolation()
; input:
;       esi - do process code
; output:
;       eax - VMM process code
; ������
;       1) ������ EPT violation ������ VM-exit
;----------------------------------------------------------------------- 
DoEptViolaton:
        push ebp
        push edx
        push ebx
        push ecx
        
%ifdef __X64        
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

        
        ;;
        ;; ��ȡ���� EPT violation �� guest-physical address ֵ
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.ExitInfoBuf + EXIT_INFO.GuestPhysicalAddress]
        
        ;;
        ;; ��� GPA �Ƿ���Ҫ���ж��⴦��
        ;;
        REX.Wrxb
        mov esi, ebx
        REX.Wrxb
        and esi, ~0FFFh
        call GetGpaHte
        REX.Wrxb
        test eax, eax
        jz DoEptViolaton.next        
        REX.Wrxb
        mov eax, [eax + GPA_HTE.Handler]
        call eax
        
        ;;
        ;; ������Ϻ��Ƿ���Ҫ�޸� EPT violation ����
        ;; a����Ҫ��ִ��������޸�����
        ;; b������ֱ�ӷ���
        ;;
        cmp eax, EPT_VIOLATION_FIXING
        jne DoEptViolation.resume
        
DoEptViolaton.next:        
        ;;
        ;; ���ҳ���Ƿ����� not-present
        ;; 1) ������� not-present�����������ҳ�棬��������ӳ��
        ;; 2) ��������޷���Ȩ��ʱ���޸�ӳ��
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        test eax, (EPT_READ | EPT_WRITE | EPT_EXECUTE) << 3                     ; ExitQualification[5:3]
        jz DoEptViolaton.@0

        DEBUG_RECORD            "[DoEptViolation]: fixing access !"  
        
        ;;
        ;; �����޸����ڷ���Ȩ������� EPT violation ����
        ;;
%ifdef __X64        
        REX.Wrxb
        mov esi, ebx                                                            ; guest-physical address
        and eax, 07h                                                            ; ��������
        or eax, FIX_ACCESS                                                      ; ���� FIX_ACCESS ����
%else
        xor edi, edi
        mov esi, ebx
        mov ecx, eax
        and ecx, 07h
        or ecx, FIX_ACCESS
%endif
        jmp DoEptViolation.DoMapping


DoEptViolaton.@0:
        ;;
        ;; �Ӵ����� domain �����һ�� 4K ����ҳ��
        ;;
        mov esi, 1
        call vm_alloc_pool_physical_page
        
        REX.Wrxb
        test eax, eax
        jz DoEptViolation.done
        

DoEptViolaton.remaping:

        DEBUG_RECORD            "[DoEptViolation]: remaping! (eax = HPA, ebx = GPA)"
        
        ;;
        ;; ������� guest-physical address ӳ��
        ;; ע�⣺����������з���Ȩ�ޣ�read/write/execute
        ;; 1) ��Ϊ��guest-physical address ���ʣ����ܻ���ж��ַ��ʣ���Ҫ����Ȩ��
        ;;
%ifdef __X64
        ;;
        ;; rsi - guest-physical address
        ;; rdi - host-physical address
        ;; eax - page attribute
        ;;
        REX.Wrxb
        mov esi, ebx                            ; guest-physical address
        REX.Wrxb
        mov edi, eax                            ; host-physical address
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        or eax, EPT_FIXING | FIX_ACCESS | EPT_READ | EPT_WRITE | EPT_EXECUTE
%else
        ;;
        ;; edi:esi - guest-physical address
        ;; edx:eax - host-physical address
        ;; ecx     - page attribute
        ;;
        xor edi, edi
        xor edx, edx
        mov esi, ebx                            ; guest-physical address
        mov ecx, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        or ecx, EPT_FIXING | FIX_ACCESS | EPT_READ | EPT_WRITE | EPT_EXECUTE
%endif


DoEptViolation.DoMapping:
        ;;
        ;; ִ�� guest-physical address ӳ�乤��
        ;;
        call do_guest_physical_address_mapping
        
        
        ;;
        ;; ### ˢ�� cache ###
        ;;
              
        ;;
        ;; INVEPT ������
        ;;
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword1], 0
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword2], 0
        mov DWORD [ebp + PCB.InvDesc + INV_DESC.Dword3], 0
        
                
%ifdef __X64
       
        GetVmcsField    CONTROL_EPT_POINTER_FULL
        REX.Wrxb
        mov [ebp + PCB.InvDesc + INV_DESC.Eptp], eax
%else
        GetVmcsField    CONTROL_EPT_POINTER_FULL
        mov [ebp + PCB.InvDesc + INV_DESC.Eptp], eax
        GetVmcsField    CONTROL_EPT_POINTER_HIGH
        mov [ebp + PCB.InvDesc + INV_DESC.Eptp + 4], eax       
%endif    
    
        ;;
        ;; ʹ�� single-context invalidation ˢ�·�ʽ
        ;;
        mov eax, SINGLE_CONTEXT_INVALIDATION
        invept eax, [ebp + PCB.InvDesc]
        
        
DoEptViolation.resume:
        mov eax, VMM_PROCESS_RESUME
DoEptViolation.done:        
        pop ecx
        pop ebx
        pop edx
        pop ebp
        ret
        
        
        
        
        

;-----------------------------------------------------------------------
; DoEptMisconfiguration()
; input:
;       none
; output:
;       eax - VMM process code
; ������
;       1) ������ EPT misconfiguration ������ VM-exit
;----------------------------------------------------------------------- 
DoEptMisconfiguration: 
        push ebp
        push ecx
        push edx
        
        ;;
        ;; ���� EPT misconfiguration ʱ�������޸�����
        ;;

        REX.Wrxb
        mov esi, [ebp + PCB.ExitInfoBuf + EXIT_INFO.GuestPhysicalAddress]
        

        DEBUG_RECORD            "[DoEptMisconfiguration]: fixing !"
        
        ;;
        ;; ��������޸�
        ;;
%ifdef __X64
        ;;
        ;; rsi - guest-physical address
        ;; rdi - host-physical address
        ;; eax - page attribute
        ;;
        REX.Wrxb
        mov edi, esi        
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        or eax, FIX_MISCONF
%else
        ;;
        ;; edi:esi - guest-physical address
        ;; edx:eax - host-physical address
        ;; ecx     - page attribute
        ;;
        xor edi, edi
        xor edx, edx
        mov eax, esi        
        mov ecx, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        or ecx, FIX_MISCONF        
%endif
        call do_guest_physical_address_mapping
      
        mov eax, VMM_PROCESS_RESUME

DoEptMisconfiguration.done:        
        pop edx
        pop ecx
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; DoINVEPT()
; input:
;       none
; output:
;       none
; ������
;       1) ������ INVEPT ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoINVEPT: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoRDTSCP()
; input:
;       none
; output:
;       none
; ������
;       1) ������ RDTSCP ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoRDTSCP: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        


;-----------------------------------------------------------------------
; DoVmxPreemptionTimer()
; input:
;       none
; output:
;       none
; ������
;       1) ������VMX-preemption timer ��ʱ������ VM-exit
;----------------------------------------------------------------------- 
DoVmxPreemptionTimer: 
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif   

        mov eax, VMM_PROCESS_DUMP_VMCS
        pop ebp
        ret
        
        
        


;-----------------------------------------------------------------------
; DoINVVPID()
; input:
;       none
; output:
;       none
; ������
;       1) ������ INVVPID ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoINVVPID: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        

;-----------------------------------------------------------------------
; DoWBINVD()
; input:
;       none
; output:
;       none
; ������
;       1) ������ WBINVD ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoWBINVD:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
        

;-----------------------------------------------------------------------
; DoXSETBV()
; input:
;       none
; output:
;       none
; ������
;       1) ������ִ�� XSETBV ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoXSETBV: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoAPICWrite()
; input:
;       none
; output:
;       none
; ������
;       1) ������ APIC-write ������ VM-exit
;----------------------------------------------------------------------- 
DoAPICWrite: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoRDRAND()
; input:
;       none
; output:
;       none
; ������
;       1) ������ RDRAND ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoRDRAND: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoINVPCID()
; input:
;       none
; output:
;       none
; ������
;       1)  ������ INVPCID ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoINVPCID: 
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; DoVMFUNC()
; input:
;       none
; output:
;       none
; ������
;       1) ������ VMFUNC ָ�������� VM-exit
;----------------------------------------------------------------------- 
DoVMFUNC:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret






;**********************************
; �˳��������̱�                   *
;**********************************

DoVmExitRoutineTable:
        DD      DoExceptionNMI, DoExternalInterrupt, DoTripleFault, DoINIT, DoSIPI, DoIoSMI, DoOtherSMI
        DD      DoInterruptWindow, DoNMIWindow, DoTaskSwitch, DoCPUID, DoGETSEC, DoHLT
        DD      DoINVD, DoINVLPG, DoRDPMC, DoRDTSC, DoRSM, DoVMCALL                   
        DD      DoVMCLEAR, DoVMLAUNCH, DoVMPTRLD, DoVMPTRST, DoVMREAD, DoVMRESUME     
        DD      DoVMWRITE, DoVMXOFF, DoVMXON, DoControlRegisterAccess, DoMovDr, DoIoInstruction
        DD      DoRDMSR, DoWRMSR, DoInvalidGuestState, DoMSRLoading, 0, DoMWAIT
        DD      DoMTF, 0, DoMONITOR, DoPAUSE, DoMachineCheck, 0
        DD      DoTPRThreshold, DoAPICAccessPage, DoEOIBitmap, DoGDTR_IDTR, DoLDTR_TR, DoEptViolaton
        DD      DoEptMisconfiguration, DoINVEPT, DoRDTSCP, DoVmxPreemptionTimer, DoINVVPID, DoWBINVD
        DD      DoXSETBV, DoAPICWrite, DoRDRAND, DoINVPCID, DoVMFUNC, 0
