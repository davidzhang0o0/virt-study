;*************************************************
;* exception.asm                                 *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


;;
;; �������� Exception �������� VM exit
;;




%if 0

;----------------------------------------------------------
; reflect_exception_to_guest()
; input:
;       none
; output:
;       none
; ������
;       �����������£�VMM ��Ҫ reflect exception �� guest ִ��:
;       1) VM exit ������ exception ����
;       2) exception �������� guest OS ������������
;----------------------------------------------------------
reflect_exception_to_guest:
        push ebx
        push ecx
        push edx
        push ebp
        mov ebp, esp
        sub esp, 8
        
        ;;
        ;; �� VM-exit IDT-vectoring information �� bit31 Ϊ 1 ʱ��˵�� VM-exit ������ event delivery ������
        ;; ��ô reflect exception ����������ֱ�Դ�:
        ;; 1) ֱ�� reflect �� guest
        ;; 2) reflect #DF exception �� guest
        ;;
        
        ;;
        ;; �� VM-exit interrupt information �� VM-exit interrupt error code ֵ
        ;;
        ReadVmcsRegion VMEXIT_INTERRUPTION_INFORMATION
        mov ebx, eax
        ReadVmcsRegion VMEXIT_INTERRUPTION_ERROR_CODE
        mov ecx, eax        
        
        ;;
        ;; ��� bit12 λ��NMI unblocking due to IRET��
        ;; 1) bit12 Ϊ 0 ʱ�����޸� blocking by NMI λ
        ;; 2) bit12 Ϊ 1 ʱ����� VM-exit event �Ƿ�Ϊ #DF
        ;; 
        xor esi, esi
        btr ebx, 12
        jnc reflect_exception_to_guest.@0
        cmp bl, 8
        je reflect_exception_to_guest.@0
        
        ;;
        ;; ��Ҫ���� blocking by NMI λ
        ;;
        mov esi, GUEST_BLOCKING_BY_NMI        
 
reflect_exception_to_guest.@0:

        
        ;;
        ;; ���ж� VM exit �Ƿ��� event delivery �����в���
        ;; 1) �� VM eixt IDT-vectoring informationg
        ;; 2) ��� bit31 �Ƿ�Ϊ 1
        ;; 3) ����Ƿ����� hardware exception
        ;;
        ReadVmcsRegion IDT_VECTORING_INFORMATION
        mov edx, eax
        test eax, FIELD_VALID_FLAG
        jz reflect_exception_to_guest.inject
        
        ;;
        ;; �� IDT-vectoring information ��Чʱ��NMI unblocking due to IRET λ���� undefined ֵ
        ;;
        xor esi, esi                                                    ; �� blocking by NMI λ
        
        ;;
        ;; ����Ƿ����� hardware exception��3��
        ;;
        and eax, 700h
        cmp eax, INTERRUPT_TYPE_HARDWARE_EXCEPTION
        jne reflect_exception_to_guest.inject
        
        ;;
        ;; ��ԭʼ event �� #DF ʱ������ guest ���� triple fault
        ;;
        cmp dl, 8
        jne reflect_exception_to_guest.@1

        ;;
        ;; VMM �� guest ���� shutdown ״̬
        ;;        
        WriteVmcsRegion GUEST_ACTIVITY_STATE, GUEST_STATE_SHUTDOWN
        
        jmp reflect_exception_to_guest.inject
        
        
        ;;
        ;; ���������֮һ����Ҫ reflect #DF exception �� guest
        ;; 1) ���ԭʼ event����¼�� IDT-vectoring ������� VM-exit �� event �������� #DE��#TS��#NP��#SS �� #GP
        ;;   ����Ӧ�� vector Ϊ 0, 10, 11, 12��13��
        ;; 2) ���ԭʼ event Ϊ #PF���������� VM-exit �� event Ϊ #PF �� #DE��#TS��#NP��#SS, #GP
        ;;   ����Ӧ�� vector Ϊ 14, 0, 10, 11, 12, 13��
        ;; ��������֮һ������event delivery �ڼ䷢���� #DF �쳣
        ;;

reflect_exception_to_guest.@1:
       
        ;;
        ;; ԭʼ event �Ƿ�Ϊ contributory exception��0, 10, 11, 12, 13��
        ;;
        cmp dl, 0                                                       ; ��� #DE
        je reflect_exception_to_guest.@2
        cmp dl, 10                                                      ; ��� 10-13
        jb reflect_exception_to_guest.inject
        cmp dl, 13                         
        jbe reflect_exception_to_guest.@2
        
        ;;
        ;; ԭʼ event �Ƿ�Ϊ #PF
        ;;
        cmp dl, 14                                                      ; ��� #PF
        jne reflect_exception_to_guest.inject   
                
        
        ;;
        ;; ��� VM-exit event �Ƿ�Ϊ #PF
        ;;       
        cmp bl, 14
        je reflect_exception_to_guest.df
        
reflect_exception_to_guest.@2:
        cmp bl, 0                                                       ; ��� #DE
        je reflect_exception_to_guest.df
        
        ;;
        ;; �Ƿ� contributory exception��10, 11, 12, 13��
        ;;
        cmp bl, 10                                                      ; ��� 10 - 13
        jb reflect_exception_to_guest.inject
        cmp bl, 13
        ja reflect_exception_to_guest.inject           


reflect_exception_to_guest.df:
        ;;
        ;; ����һ�� #DF �쳣�� event injection ��Ϣ
        ;; 1) vector = 08h
        ;; 2) interrupt type = hardware exception
        ;; 3) deliver error code = 1
        ;; 4) valid flags = 1
        ;; 5) error code = 0
        ;;
        mov ebx, INTERRUPT_TYPE_HARDWARE_EXCEPTION | 08h | 800h | FIELD_VALID_FLAG
        mov ecx, 0
        
reflect_exception_to_guest.inject:        
        ;;
        ;; ���� injection ��Ϣ��
        ;; 1) ���� VM exit interrupt-information 
        ;; 2) ���� VM exit interrupt error code
        ;;
        WriteVmcsRegion VMENTRY_INTERRUPTION_INFORMATION, ebx
        WriteVmcsRegion VMENTRY_EXCEPTION_ERROR_CODE, ecx

        ;;
        ;; ���� guest interruptibility state
        ;;                
        ReadVmcsRegion GUEST_INTERRUPTIBILITY_STATE
        or esi, eax
        WriteVmcsRegion GUEST_INTERRUPTIBILITY_STATE, esi
        
reflect_exception_to_guest.done:        
        mov esp, ebp
        pop ebp
        pop edx
        pop ecx
        pop ebx
        ret

%endif


;-----------------------------------------------------------------------
; do_DE()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #DE ������ VM-exit
;-----------------------------------------------------------------------
do_DE:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret


;-----------------------------------------------------------------------
; do_DB()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #DB ������ VM-exit
;-----------------------------------------------------------------------
do_DB:
        push ebp
%ifdef __X64 
        LoadGsBaseToRbp
%else
        mov ebp, [gs: SDA.Base]
%endif
        
        ;;
        ;; ���� #DB �쳣
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_DB
        DoVmWrite       VMENTRY_INSTRUCTION_LENGTH, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InstructionLength]
        
        mov eax, VMM_PROCESS_RESUME
        pop ebp
        ret
        



;-----------------------------------------------------------------------
; do_NMI()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ NMI ������ VM-exit
;-----------------------------------------------------------------------
do_NMI:
        push ebp
%ifdef __X64 
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif

        DEBUG_RECORD    "[do_NMI]: call NMI handler !"

        ;;
        ;; ������ã��������� NMI handler ��ʽ��VMM����� NMI
        ;;
        int NMI_VECTOR
        
                        
        ;;
        ;; ����ע�� NMI �� guest ���
        ;; 1) �����ַ�ʽ����Ϊ VMM ���
        ;;
%if 0
        DEBUG_RECORD    "[do_NMI]: inject a NMI event !"
        
        ;;
        ;; ע�� NMI �¼�
        ;;       
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_NMI
        SetVmcsField    VMENTRY_INSTRUCTION_LENGTH, 0
%endif

        mov eax, VMM_PROCESS_RESUME
        pop ebp
        ret



;-----------------------------------------------------------------------
; do_BP()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #BP ������ VM-exit
;-----------------------------------------------------------------------
do_BP:
        push ebp
%ifdef __X64 
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        DEBUG_RECORD    "[do_BP]: inject a #BP event !"        
        
        ;;
        ;; ���� #BP �쳣
        ;;
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_BP
        DoVmWrite       VMENTRY_INSTRUCTION_LENGTH, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InstructionLength]
        
        mov eax, VMM_PROCESS_RESUME
        ;mov eax, VMM_PROCESS_DUMP_VMCS
        pop ebp
        ret
        
        

;-----------------------------------------------------------------------
; do_OF()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #OF ������ VM-exit
;-----------------------------------------------------------------------
do_OF:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret



;-----------------------------------------------------------------------
; do_BR()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #BR ������ VM-exit
;-----------------------------------------------------------------------
do_BR:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
;-----------------------------------------------------------------------
; do_UD()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #UD ������ VM-exit
;-----------------------------------------------------------------------
do_UD:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        


;-----------------------------------------------------------------------
; do_NM()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #NM ������ VM-exit
;-----------------------------------------------------------------------
do_NM:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; do_DF()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #DF ������ VM-exit
;-----------------------------------------------------------------------
do_DF:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret        
        
        


;-----------------------------------------------------------------------
; do_TS()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #TS ������ VM-exit
;-----------------------------------------------------------------------
do_TS:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        

;-----------------------------------------------------------------------
; do_NP()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #NP ������ VM-exit
;-----------------------------------------------------------------------
do_NP:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
                


;-----------------------------------------------------------------------
; do_SS()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #SS ������ VM-exit
;-----------------------------------------------------------------------
do_SS:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
                
;-----------------------------------------------------------------------
; do_GP()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #GP ������ VM-exit
;-----------------------------------------------------------------------
do_GP:
        push ebp
        push ebx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

        DEBUG_RECORD    "[do_GP]..."

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        
        call get_interrupt_info                 ; �ռ��ж������Ϣ
        
        ;;
        ;; ���� software interrupt, external-interrupt �Լ� privileged interrupt ʱ��ִ���жϴ���
        ;;
        movzx eax, BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.InterruptType]
        cmp al, INTERRUPT_TYPE_SOFTWARE
        je do_GP.DoInterrupt
        cmp al, INTERRUPT_TYPE_EXTERNAL
        je do_GP.DoInterrupt
        cmp al, INTERRUPT_TYPE_PRIVILEGE
        je do_GP.DoInterrupt

        ;;
        ;; ���䴦��
        ;; 1) �� IDT-vectoring information ��¼�쳣Ϊ #DE��#TS��#NP, #SS ���� #GP ʱ����Ҫ���� #DF �쳣
        ;; 2) �� IDT-vectoring information ��¼�쳣Ϊ #DF �쳣����Ҫ���� triple fault
        ;;
        cmp eax, INTERRUPT_TYPE_HARD_EXCEPTION
        jne do_GP.ReflectGp
        mov al, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Vector]
        cmp al, DF_VECTOR
        je do_GP.TripleFalut
        cmp al, DE_VECTOR
        je do_GP.ReflectDf
        cmp al, TS_VECTOR
        je do_GP.ReflectDf
        cmp al, NP_VECTOR
        je do_GP.ReflectDf
        cmp al, SS_VECTOR
        je do_GP.ReflectDf
        cmp al, PF_VECTOR
        je do_GP.ReflectDf
        cmp al, GP_VECTOR
        jne do_GP.ReflectGp

do_GP.ReflectDf:
        mov eax, 0
        mov ecx, INJECT_EXCEPTION_DF
        jmp do_GP.ReflectException
        
do_GP.ReflectGp:
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InterruptionErrorCode]
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_GP.ReflectException

do_GP.TripleFalut:
        DEBUG_RECORD    "triple fault ..."
        mov eax, VMM_PROCESS_DUMP_VMCS
        jmp do_GP.Done1
        
        ;;
        ;; ���� triple fault 
        ;;        
        SetVmcsField    GUEST_ACTIVITY_STATE, GUEST_STATE_SHUTDOWN
        jmp do_GP.Done

        ;;
        ;; #### ���� VMM �����жϵ� delivery ���� ####
        ;;
do_GP.DoInterrupt:        
        DEBUG_RECORD    "process INT instruction"
        
        movzx esi, BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Vector]
        call do_int_process
        jmp do_GP.Done
        
        
do_GP.ReflectException:        
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, ecx        
        
do_GP.Done:        
        mov eax, VMM_PROCESS_RESUME        
do_GP.Done1:        
        pop edx
        pop ebx
        pop ebp
        ret
        


;-----------------------------------------------------------------------
; do_PF()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #PF ������ VM-exit
;-----------------------------------------------------------------------
do_PF:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        mov eax, VMM_PROCESS_DUMP_VMCS

        REX.Wrxb
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        cmp eax, 410000h
        mov eax, VMM_PROCESS_DUMP_VMCS
        jne do_PF.Done
        
        DEBUG_RECORD    "[do_PF]: restart..."
        
        SetVmcsField    GUEST_RIP, 200BBh
        
        mov eax, VMM_PROCESS_RESUME
do_PF.Done:   
        pop ebx
        pop ebp        
        ret
        


;-----------------------------------------------------------------------
; do_MF()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #MF ������ VM-exit
;-----------------------------------------------------------------------
do_MF:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
                
                                

;-----------------------------------------------------------------------
; do_AC()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #AC ������ VM-exit
;-----------------------------------------------------------------------
do_AC:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret



;-----------------------------------------------------------------------
; do_MC()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #MC ������ VM-exit
;-----------------------------------------------------------------------
do_MC:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
        
                

;-----------------------------------------------------------------------
; do_XM()
; input:
;       none
; output:
;       eax - VMM ������
; ������
;       1) ������ #XM ������ VM-exit
;-----------------------------------------------------------------------
do_XM:
        mov eax, VMM_PROCESS_DUMP_VMCS
        ret
        
                
        
;-----------------------------------------------------------------------
; DoReserved()
; input:
;       none
; output:
;       none
; ������
;       1) �������쳣
;-----------------------------------------------------------------------
DoReserved:
        ret


;-----------------------------------------------------------------------
; do_int_process()
; input:
;       esi - vector
; output:
;       none
; ������
;       1) �����ж� delivery ����
;-----------------------------------------------------------------------
do_int_process:
        push ebp
        push ebx
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        DEBUG_RECORD    "[do_int_process]..."
        
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        
        mov ecx, esi                                    ; ecx = vector
                        
        ;;
        ;; ����Ƿ��� IA-32e ģʽ
        ;; 1) �ǣ����� IA-32e ģʽ�µ� INT ָ��
        ;; 2) �񣬴��� protected ģʽ�µ� INT ָ��
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.GuestStatus], GUEST_STATUS_LONGMODE
        jnz do_int_process.Longmode

do_int_process.Protected:
        DEBUG_RECORD    "[do_int_process.Protected]..."
        
        ;;
        ;; #### ���� protected ģʽ�µ� INT ָ��ִ�� ####
        ;;
        shl ecx, 3

        ;;
        ;; step 1: ��� vector �Ƿ񳬳� IDT limit
        ;; 1) (vector * 8 + 7) > limit ?
        ;;
        mov edx, ecx
        lea esi, [edx + 7]
        cmp si, [ebx + VMB.GuestImb + GIMB.IdtLimit]        
        jbe do_int_process.Protected.ReadDesc

do_int_process.Gp_vector_11B:
        ;;
        ;; error code = vector | IDT | EXT
        ;;
        mov eax, ecx
        or eax, 3
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_int_process.ReflectException

do_int_process.Gp_vector_10B:
        ;;
        ;; error code = vector | IDT | 0
        ;;
        mov eax, ecx
        or eax, 2
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_int_process.ReflectException

do_int_process.Gp_CsSelector_01B:
do_int_process.Gp_vector_01B:
        ;;
        ;; error code = vector | 0 | EXT
        ;;
        mov eax, ecx
        or eax, 1
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_int_process.ReflectException

do_int_process.Gp_01B:
        mov eax, 1
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_int_process.ReflectException

do_int_process.Np_vector_11B:
        ;;
        ;; error code = vector | 1 | EXT
        ;;
        mov eax, ecx
        or eax, 3
        mov ecx, INJECT_EXCEPTION_NP
        jmp do_int_process.ReflectException
                
do_int_process.Np_CsSelector_01B:
        ;;
        ;; error code = selector | 0 | EXT
        ;;
        mov eax, ecx
        or eax, 1
        mov ecx, INJECT_EXCEPTION_NP
        jmp do_int_process.ReflectException


do_int_process.Protected.ReadDesc:
        ;;
        ;; step 2: �� IDT ������
        ;;
        REX.Wrxb
        add edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtBase]
        mov esi, [edx]
        mov edi, [edx + 4]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc], esi
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], edi
                
do_int_process.Protected.CheckType:
        ;;
        ;; step 3: ��� IDT �������Ƿ����� gate
        ;;
        shr edi, 8
        and edi, 0Fh
        cmp edi, 0101B                                  ; task-gate
        je do_int_process.Protected.CheckPrivilege
        cmp edi, 1110B                                  ; interrupt-gate
        je do_int_process.Protected.CheckPrivilege
        cmp edi, 1111B                                  ; trap-gate
        jne do_int_process.Gp_vector_11B
        
do_int_process.Protected.CheckPrivilege:
        ;;
        ;; step 4: ������software-interrupt ʱ�����Ȩ�ޣ�CPL <= IDT-gate.DPL
        ;;
        movzx eax, BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.InterruptType]
        cmp eax, INTERRUPT_TYPE_SOFTWARE
        jne do_int_process.Protected.CheckPresent
        
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Cpl] 
        mov esi, [edx + 4]
        shr esi, 13
        and esi, 3
        cmp esi, eax
        jb do_int_process.Gp_vector_10B

do_int_process.Protected.CheckPresent:        
        ;;
        ;; step 5: ��� gate �Ƿ�Ϊ present
        ;;
        test DWORD [edx + 4], (1 << 15)
        jz do_int_process.Np_vector_11B


do_int_process.Protected.GateType:
        ;;
        ;; step 6: ��� gate ����
        ;;
        test DWORD [edx + 4], (1 << 9)
        jnz do_int_process.InterruptTrap
        
        ;;
        ;; ### �������� task-gate ###
        ;;
        jmp do_int_process.Done
        

do_int_process.InterruptTrap:
        ;;
        ;; step 7: ��� code-segment selector �Ƿ�Ϊ NULL
        ;;
        movzx ecx, WORD [edx + 2]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCs], cx
        and ecx, 0FFF8h
        jz do_int_process.Gp_01B
        
        ;;
        ;; step 8: ��� code-segment selector �Ƿ񳬳� GDT limit
        ;;
        mov esi, ecx
        add esi, 7
        cmp si, [ebx + VMB.GuestGmb + GGMB.GdtLimit]
        ja do_int_process.Gp_CsSelector_01B
        
        ;;
        ;; step 9: ��ȡ code-segment ������
        ;;
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.GdtBase]
        mov esi, [edx + ecx]
        mov edi, [edx + ecx + 4]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc], esi
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4], edi

     
        ;;
        ;; step 10: ��������� C/D λ���Ƿ�Ϊ code-segment
        ;;
        test edi, (1 << 11)
        jz do_int_process.Gp_CsSelector_01B

        ;;
        ;; step 11: ���Ȩ�ޣ�DPL <= CPL
        ;;
        mov esi, edi
        shr esi, 13
        and esi, 3
        cmp si, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Cpl]
        ja do_int_process.Gp_CsSelector_01B

        ;;
        ;; step 12: ��� code-segment �������Ƿ�Ϊ present
        ;;
        test edi, (1 << 15)
        jz do_int_process.Np_CsSelector_01B


do_int_process.InterruptTrap.Next:
        ;;
        ;; step 13: ����Ȩ�޽�����Ӧ����
        ;;
        ;; ע�⣺ ### ��Ϊ���ӣ�����ʵ�ֶ� conforming ���ͶεĴ��� ###
        ;;        ### ��Ϊ���ӣ�����ʵ�ֶ� virutal-8086 ģʽ�µ��жϴ��� ###
        ;;
        mov eax, do_interrupt_for_inter_privilege
        mov edi, do_interrupt_for_intra_privilege        
        cmp si, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Cpl]
        cmove eax, edi
        mov ecx, do_interrupt_for_inter_privilege_longmode
        mov edi, do_interrupt_for_intra_privilege_longmode
        cmove ecx, edi
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.GuestStatus], GUEST_STATUS_LONGMODE
        cmovnz eax, ecx
        call eax
        jmp do_int_process.Done        
 
        
do_int_process.Longmode:
        ;;
        ;; ���� longmode ģʽ�µ� INT ָ��ִ��
        ;;
        DEBUG_RECORD    "[do_int_process.Longmode]..."
        
        ;;
        ;; step 1: ��� vector �Ƿ񳬳� IDT.limit
        ;;
        shl ecx, 4
        lea esi, [ecx + 15]
        cmp si, [ebx + VMB.GuestImb + GIMB.IdtLimit]
        ja do_int_process.Gp_vector_11B

        ;;
        ;; step 2: �� IDT ������
        ;;
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtBase]
        REX.Wrxb
        add edx, ecx
        REX.Wrxb
        mov esi, [edx]
        REX.Wrxb
        mov edi, [edx + 8]
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc], esi
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 8], edi

        ;;
        ;; step 3: ��� IDT �������Ƿ����� interrupt-gate, trap-gate
        ;;
        mov edi, [edx + 4]
        shr edi, 8
        and edi, 0Fh
        cmp edi, 1110B                                  ; interrupt-gate
        je do_int_process.Longmode.CheckPrivilege
        cmp edi, 1111B                                  ; trap-gate
        jne do_int_process.Gp_vector_11B        
        
do_int_process.Longmode.CheckPrivilege:
        ;;
        ;; step 4: ������software-interrupt ʱ�����Ȩ�ޣ�CPL <= IDT-gate.DPL
        ;;
        movzx eax, BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.InterruptType]
        cmp eax, INTERRUPT_TYPE_SOFTWARE
        jne do_int_process.Longmode.CheckPresent
        
        mov eax, [edx + 4]
        shr eax, 13
        and eax, 3
        cmp al, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Cpl]
        jb do_int_process.Gp_vector_10B

do_int_process.Longmode.CheckPresent:
        ;;
        ;; step 5: ��� IDT-gate �Ƿ�Ϊ present
        ;;
        test DWORD [edx + 4], (1 << 15)
        jnz do_int_process.InterruptTrap

        ;;
        ;; #NP (error code = vector | IDT | EXT)
        ;;
        movzx eax, BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Vector]
        shl eax, 3
        or eax, 3
        mov ecx, INJECT_EXCEPTION_NP
        
        
do_int_process.ReflectException:        
        ;;
        ;; ע���쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, ecx
        mov eax, DO_INTERRUPT_ERROR
            
do_int_process.Done:  
        pop ecx
        pop edx
        pop ebx
        pop ebp
        ret
        


;-----------------------------------------------------------------------
; do_interrupt_for_inter_privilege()
; input:
;       esi - privilege level
; output:
;       eax - statusf code
; ������
;       1) ���� legacy ģʽ�µ���Ȩ���ڵ��жϣ������Ȩ�ޣ�
;-----------------------------------------------------------------------
do_interrupt_for_inter_privilege:
        push ebp
        push ebx
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        DEBUG_RECORD    "[do_interrupt_for_inter_privilege]..."

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        mov ecx, esi                                                    ; ecx = privilege level
        
        ;;
        ;; step 1: ��� TSS �Ƿ�Ϊ 32-bit
        ;;
        test DWORD [ebx + VMB.GuestTmb + GTMB.TssAccessRights], (1 << 3)
        jnz do_interrupt_for_inter_privilege.Tss32
        
do_interrupt_for_inter_privilege.Tss16:        
        shl ecx, 2
        add ecx, 2
        
        ;;
        ;; step 1: ��� stack pointer ��ַ�Ƿ񳬳� TSS limit: (DPL << 2) + 2 + 3 > limit ?
        ;; 1) ���� limit������� #TS(TSS_selector, 0, EXT)
        ;;
        lea esi, [ecx + 3]
        cmp esi, [ebx + VMB.GuestTmb + GTMB.TssLimit]
        ja do_interrupt_for_inter_privilege.Ts_TssSelector_01B
        
do_interrupt_for_inter_privilege.ReadStack16:        
        ;;
        ;; step 2: ��ȡ�ж� handler ʹ�õ� stack pointer
        ;;
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TssBase]            
        movzx esi, WORD [eax + ecx]                                             ;; new SP
        movzx ecx, WORD [eax + ecx + 2]                                         ;; new SS��ecx)
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSs], cx             ;; ���� SS
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp], esi           ;; ����Ŀ�� RSP        
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp], eax                 ;; ���� RSP        
        jmp do_interrupt_for_inter_privilege.CheckSsSelector       
        
do_interrupt_for_inter_privilege.Tss32:
        shl ecx, 3
        add ecx, 4

        ;;
        ;; step 1: ��� stack pointer ��ַ�Ƿ񳬳� TSS limit
        ;; 1)  (DPL << 3) + 4 + 5 > limit ����� #TS(TSS_selector, 0, EXT)
        ;;
        lea esi, [ecx + 5]
        cmp esi, [ebx + VMB.GuestTmb + GTMB.TssLimit]
        jbe do_interrupt_for_inter_privilege.ReadStack32
        
        
do_interrupt_for_inter_privilege.Ts_TssSelector_01B:
        ;;
        ;; error code = TssSelector | 0 | EXT
        ;;
        mov eax, [ebx + VMB.GuestTmb + GTMB.TssSelector]
        and eax, 0FFF8h
        or eax, 1
        mov ecx, INJECT_EXCEPTION_TS
        jmp do_interrupt_for_inter_privilege.ReflectException

do_interrupt_for_inter_privilege.Ts_SsSelector_01B:
        ;;
        ;; error code = SsSelector | 0 | EXT
        ;;
        mov eax, ecx
        and eax, 0FFF8h
        or eax, 1
        mov ecx, INJECT_EXCEPTION_TS
        jmp do_interrupt_for_inter_privilege.ReflectException
        
do_interrupt_for_inter_privilege.IdtGate16: 
        ;;
        ;; ��� 16 λ IDT-gate �stack �Ƿ������� 10 bytes��5 *  2)������ stack ���Ƿ����� expand-down ��
        ;; 1) expand-down:  esp - 10 > SS.limit && esp <= SS.Top
        ;; 2) expand-up:    esp <= SS.limit 
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4], (1 << 10)  ; SS.E λ
        jz do_interrupt_for_inter_privilege.IdtGate16.ExpandUp
        
        
do_interrupt_for_inter_privilege.IdtGate16.ExpandDown:
        ;;
        ;; ��� expand-down ���Ͷ�
        ;;
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        sub esi, 10
        cmp esi, eax
        jbe do_interrupt_for_inter_privilege.Ss_SsSelector_01B
        
        ;;
        ;; ���� SS.B λ���
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4], (1 << 22)  ; SS.B λ
        jnz do_interrupt_for_inter_privilege.GetCsLimit
        mov eax, 0FFFFFh                                ;; SS.B = 0 ʱ��expand-down ������Ϊ 0FFFFFh
        
do_interrupt_for_inter_privilege.IdtGate16.ExpandUp:
        ;;
        ;; ��� expand-up ����
        ;;        
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        cmp esi, eax
        jbe do_interrupt_for_inter_privilege.GetCsLimit


        
do_interrupt_for_inter_privilege.Ss_SsSelector_01B:
        ;;
        ;; error code = SsSelector | 0 | EXT
        ;;
        mov eax, ecx
        and eax, 0FFF8h
        or eax, 1
        mov ecx, INJECT_EXCEPTION_SS        
        jmp do_interrupt_for_inter_privilege.ReflectException
        
do_interrupt_for_inter_privilege.Ts_01B:
        ;;
        ;; error code = 0 | 0 | EXT
        ;;
        mov eax, 01
        mov ecx, INJECT_EXCEPTION_TS
        jmp do_interrupt_for_inter_privilege.ReflectException

do_interrupt_for_inter_privilege.Gp_01B:
        ;;
        ;; error code = 0 | 0 | EXT
        ;;
        mov eax, 01
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_interrupt_for_inter_privilege.ReflectException



do_interrupt_for_inter_privilege.ReadStack32:
        ;;
        ;; step 2: ��ȡ�ж� handler ʹ�õ� stack pointer
        ;;
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TssBase]
        mov esi, [eax + ecx]                                                    ;; new ESP
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp], esi           ;; ����Ŀ�� RSP
        movzx ecx, WORD [eax + ecx + 4]                                         ;; new SS
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSs], cx             ;; ����Ŀ�� SS
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp], eax                 ;; ���� RSP

do_interrupt_for_inter_privilege.CheckSsSelector:        
        ;;
        ;; step 3: ��� SS selector �Ƿ�Ϊ NULL������ NULL ����� #TS(EXT)
        ;;
        test ecx, 0FFF8h
        jz do_interrupt_for_inter_privilege.Ts_01B

        ;;
        ;; step 4: ��� SS selector �Ƿ񳬳� limit����������� #TS(SS_selector, 0, EXT)
        ;; 
        ;; ע�⣺#### �˴�������� LDT ####
        ;;
        mov eax, ecx
        and eax, 0FFF8h
        add eax, 7
        cmp eax, [ebx + VMB.GuestGmb + GGMB.GdtLimit]
        ja do_interrupt_for_inter_privilege.Ts_SsSelector_01B

        ;;
        ;; step 5: ��� SS.RPL �Ƿ���� CS.DPL������������� #TS(SS_selector, 0, EXT)
        ;;
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]                ; code segment
        shr eax, 13                                                                     ; CS.DPL
        xor eax, ecx
        test eax, 3
        jnz do_interrupt_for_inter_privilege.Ts_SsSelector_01B

        ;;
        ;; step 6: ��ȡ stack-segment ������
        ;;
        mov esi, ecx
        and esi, 0FFF8h
        REX.Wrxb
        add esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.GdtBase]
        mov edi, [esi + 4]        
        mov esi, [esi]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc], esi
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4], edi

        ;;
        ;; step 7: ��� SS ���������Լ� SS.DPL �� CS.DPL
        ;;
        test edi, (1 << 9)                                                              ; ����Ƿ��д
        jz do_interrupt_for_inter_privilege.Ts_SsSelector_01B                           ;               
        mov esi, edi
        xor edi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]                
        test edi, (3 << 13)                                                             ; ��� SS.DPL == CS.DPL
        jnz do_interrupt_for_inter_privilege.Ts_SsSelector_01B
        test esi, (1 << 15)                                                             ; ����Ƿ�Ϊpresent
        jz do_interrupt_for_inter_privilege.Ss_SsSelector_01B          

        ;;
        ;; step 8: ��ȡ SS.limit
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc]            ; limit[15:0]
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4]
        and esi, 0F0000h
        or eax, esi                                                                     ; limit[19:0]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4], (1 << 23)
        jz do_interrupt_for_inter_privilege.CheckSsLimit
        shl eax, 12
        add eax, 0FFFh

do_interrupt_for_inter_privilege.CheckSsLimit:                         
        ;;
        ;; step 9: ����Ƿ�������ѹ���ֵ
        ;;
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsLimit], eax               ; ���� SS.limit     
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 11)    ; ��� 16-bit gate ���� 32-bit
        jz do_interrupt_for_inter_privilege.IdtGate16

        ;;
        ;; ��� 32 λ stack �Ƿ������� 20 bytes��5 *  4)������ stack ���Ƿ����� expand-down ��
        ;; 1) expand-down:  esp - 20 > SS.limit  && esp <= SS.Top
        ;; 2) expand-up:    esp <= SS.limit
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4], (1 << 10)  ; SS.E λ
        jz do_interrupt_for_inter_privilege.CheckSsLimit.ExpandUp
        
        
do_interrupt_for_inter_privilege.CheckSsLimit.ExpandDown:
        ;;
        ;; ��� expand-down ���Ͷ�
        ;;
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        sub esi, 20
        cmp esi, eax
        jbe do_interrupt_for_inter_privilege.Ss_SsSelector_01B
        
        ;;
        ;; ���� SS.B λ���
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4], (1 << 22)  ; SS.B λ
        jnz do_interrupt_for_inter_privilege.GetCsLimit
        mov eax, 0FFFFFh                                ;; SS.B = 0 ʱ��expand-down ������Ϊ 0FFFFFh
        
do_interrupt_for_inter_privilege.CheckSsLimit.ExpandUp:
        ;;
        ;; ��� expand-up ����
        ;;        
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        cmp esi, eax
        ja do_interrupt_for_inter_privilege.Ss_SsSelector_01B

do_interrupt_for_inter_privilege.GetCsLimit:
        ;;
        ;; step 10: ��ȡ CS.limit
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc]             ; limit[15:0]
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]
        and esi, 0F0000h
        or eax, esi                                                                     ; limit[19:0]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4], (1 << 23)
        jz do_interrupt_for_inter_privilege.CheckCsLimit
        shl eax, 12
        add eax, 0FFFh

do_interrupt_for_inter_privilege.CheckCsLimit:
        ;;
        ;; step 11: ��ȡĿ�� RIP
        ;;
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsLimit], eax               ; ���� CS.limit
        movzx esi, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc]              ; offset[15:0]
        mov edi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4]
        and edi, 0FFFF0000h                                                             ; offset[31:16]
        or esi, edi
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip], esi                   ; ����Ŀ�� RIP

        ;;
        ;; step 12����� Eip �Ƿ񳬳� Cs.limit����������� #GP(EXT)
        ;;
        cmp esi, eax
        ja do_interrupt_for_inter_privilege.Gp_01B
          
        ;;
        ;; step 13: ���� SS �� ESP
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSs]
        SetVmcsField    GUEST_SS_SELECTOR, eax
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_SS_ACCESS_RIGHTS, eax
        DoVmWrite       GUEST_SS_LIMIT, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsLimit]        
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 2]
        and eax, 00FFFFFFh
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsDesc + 4]
        and esi, 0FF000000h
        or eax, esi
        SetVmcsField    GUEST_SS_BASE, eax
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 11)
        mov esi, 20
        mov edi, 10
        cmovz esi, edi
        sub eax, esi
        SetVmcsField    GUEST_RSP, eax
        
do_interrupt_for_inter_privilege.LoadCsEip:
        ;;
        ;; step 14: ���� CS:EIP
        ;;       
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCs]
        SetVmcsField    GUEST_CS_SELECTOR, eax
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_CS_ACCESS_RIGHTS, eax
        DoVmWrite       GUEST_CS_LIMIT, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsLimit]        
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 2]
        and eax, 00FFFFFFh
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]
        and esi, 0FF000000h
        or eax, esi
        SetVmcsField    GUEST_CS_BASE, eax        
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip]        
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 11)
        cmovnz eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip]
        SetVmcsField    GUEST_RIP, eax

do_interrupt_for_inter_privilege.Push:
        ;;
        ;; step 15: ������Ϣѹ�� stack ��
        ;;
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp]        
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 11)
        jz do_interrupt_for_inter_privilege.Push16
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldSs]
        mov [edx - 4], eax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRsp]
        mov [edx - 8], eax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        mov [edx - 12], eax
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldCs]
        mov [edx - 16], eax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip]
        mov [edx - 20], eax        
        jmp do_interrupt_for_inter_privilege.Flags
        
do_interrupt_for_inter_privilege.Push16:    
        ;;
        ;; ѹ�� 16 λ����
        ;;    
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldSs]
        mov [edx - 2], ax
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRsp]
        mov [edx - 4], ax
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        mov [edx - 6], ax
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldCs]
        mov [edx - 8], ax
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip]
        mov [edx - 10], ax

do_interrupt_for_inter_privilege.Flags:        
        ;;
        ;; step 16: ���� eflags
        ;;        
        mov esi, ~(FLAGS_TF | FLAGS_VM | FLAGS_RF | FLAGS_NT)
        mov edi, ~(FLAGS_TF | FLAGS_VM | FLAGS_RF | FLAGS_NT | FLAGS_IF)
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc], (1 << 8)
        cmovz esi, edi
        and eax, esi
        SetVmcsField    GUEST_RFLAGS, eax
        mov eax, DO_INTERRUPT_SUCCESS
        jmp do_interrupt_for_inter_privilege.Done
               

        
do_interrupt_for_inter_privilege.ReflectException:
        ;;
        ;; ע���쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, ecx
        mov eax, DO_INTERRUPT_ERROR

do_interrupt_for_inter_privilege.Done:        
        pop ecx
        pop edx
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------------------------
; do_interrupt_for_inter_privilege_longmode()
; input:
;       esi - privilege level
; output:
;       eax - status code
; ������
;       1) ���� longmode ģʽ�µ���Ȩ���ڵ��жϣ������Ȩ�ޣ�
;-----------------------------------------------------------------------
do_interrupt_for_inter_privilege_longmode:
        push ebp
        push ebx
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        DEBUG_RECORD    "[do_interrupt_for_inter_privilege_longmode]..."
 
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        mov ecx, esi  
 
        ;;
        ;; step 1: ���� IST ֵ���� stack pointer ƫ����
        ;;
        mov edx, esi       
        shl edx, 3
        add edx, 4
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4]
        and eax, 7
        lea esi, [eax * 8 + 28]
        cmovnz edx, esi

        ;;
        ;; step 2: ��� stack pointer �Ƿ񳬳� TSS limit
        ;;
        mov esi, edx
        add esi, 7
        cmp esi, [ebx + VMB.GuestTmb + GTMB.TssLimit]
        ja do_interrupt_for_inter_privilege_longmode.Ts_TsSelector_01B

        ;;
        ;; step 3: ��ȡ stack pointer
        ;;
        REX.Wrxb
        add edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TssBase]
        REX.Wrxb
        mov esi, [edx]                                                  ;; new RSP
        mov edi, [edx + 4]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSs], cx     ;; ���� SS
                                                                        ;; SS selector ������Ϊ NULL

        ;;
        ;; step 4: ��� RSP �Ƿ�Ϊ canonical ��ַ��ʽ��������� #SS(EXT)
        ;;
        shrd eax, edi, 16
        sar eax, 16
        cmp eax, edi
        jne do_interrupt_for_inter_privilege_longmode.Ss_01B
        
        ;;
        ;; step 5:  RSP ���µ����� 16 �ֽڱ߽����
        ;;
        
        REX.Wrxb
        and esi, ~0Fh                                                   ; new RSP & FFFF_FFFF_FFFF_FFF0h
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp], esi
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp], eax         ;; ���� RSP

        ;;
        ;; step 6: ��� RIP �Ƿ�Ϊ canonical ��ַ��ʽ��������� #GP(EXT)
        ;;
        movzx esi, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc]
        mov edi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4]
        and edi, 0FFFF0000h
        or esi, edi
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 8]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip], esi
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip + 4], eax        
        shrd esi, eax, 16
        sar esi, 16
        cmp esi, eax
        jne do_interrupt_for_inter_privilege_longmode.Gp_01B
        
        ;;
        ;; step 7: ���� RSP��SS = NULL-selector
        ;;
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        REX.Wrxb
        sub eax, (5 * 8)
        SetVmcsField    GUEST_RSP, eax   
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSs]
        SetVmcsField    GUEST_SS_SELECTOR, eax       
        shl eax, 5                      ; SS.DPL
        or eax, 93h                     ; P = S = W = A = 1
        SetVmcsField    GUEST_SS_ACCESS_RIGHTS, eax
        SetVmcsField    GUEST_SS_LIMIT, 0
        SetVmcsField    GUEST_SS_BASE, 0

        ;;
        ;; step 8: ѹ�뷵����Ϣ�� stack ��
        ;;
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp]        
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldSs]
        REX.Wrxb
        mov [edx - 8], eax
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRsp]
        REX.Wrxb
        mov [edx - 16], eax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        REX.Wrxb
        mov [edx - 24], eax        
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldCs]
        REX.Wrxb
        mov [edx - 32], eax
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip]
        REX.Wrxb
        mov [edx - 40], eax
        
        ;;
        ;; step 9: ���� CS:RIP
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCs]
        SetVmcsField    GUEST_CS_SELECTOR, eax
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_CS_ACCESS_RIGHTS, eax
        DoVmWrite       GUEST_CS_LIMIT, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsLimit]        
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 2]
        and eax, 00FFFFFFh
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]
        and esi, 0FF000000h
        or eax, esi
        SetVmcsField    GUEST_CS_BASE, eax
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip]
        SetVmcsField    GUEST_RIP, eax

  
        ;;
        ;; step 10: ���� rflags
        ;;
        mov esi, ~(FLAGS_TF | FLAGS_VM | FLAGS_RF | FLAGS_NT)
        mov edi, ~(FLAGS_TF | FLAGS_VM | FLAGS_RF | FLAGS_NT | FLAGS_IF)
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc], (1 << 8)
        cmovz esi, edi
        and eax, esi
        SetVmcsField    GUEST_RFLAGS, eax
        mov eax, DO_INTERRUPT_SUCCESS
        jmp do_interrupt_for_inter_privilege_longmode.Done
        
        
        
do_interrupt_for_inter_privilege_longmode.Ts_TsSelector_01B:        
        movzx eax, WORD [ebx + VMB.GuestTmb + GTMB.TssSelector]
        and eax, 0FFF8h
        or eax, 1
        mov ecx, INJECT_EXCEPTION_TS
        jmp do_interrupt_for_inter_privilege_longmode.ReflectException

do_interrupt_for_inter_privilege_longmode.Gp_01B:        
        mov eax, 01
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_interrupt_for_inter_privilege_longmode.ReflectException
        
do_interrupt_for_inter_privilege_longmode.Ss_01B:        
        mov eax, 1
        mov ecx, INJECT_EXCEPTION_SS       
        
        
do_interrupt_for_inter_privilege_longmode.ReflectException:
        ;;
        ;; ע���쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, ecx        
        mov eax, DO_INTERRUPT_ERROR
        
do_interrupt_for_inter_privilege_longmode.Done:        
        pop ecx
        pop edx
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------------------------
; do_interrupt_for_intra_privilege()
; input:
;       none
; output:
;       eax -status code
; ������
;       1) ���� legacy ģʽ�µ���Ȩ������жϣ�ͬ����
;-----------------------------------------------------------------------
do_interrupt_for_intra_privilege:
        push ebp
        push ebx
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        DEBUG_RECORD    "[do_interrupt_for_intra_privilege]..."

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]

        ;;
        ;; Ŀ�� RSP ����ԭ RSP
        ;;
        REX.Wrxb
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRsp]
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp], esi
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp], eax
        
        ;;
        ;; Ŀ�� SS ����ԭ SS
        ;;
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldSs]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSs], ax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsLimit]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetSsLimit], eax
        
        
do_interrupt_for_intra_privilege.CheckSsLimit:
        ;;
        ;; step 1: ����Ƿ�������ѹ���ֵ
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 11)    ; ��� 16-bit gate ���� 32-bit
        jz do_interrupt_for_intra_privilege.IdtGate16

        ;;
        ;; ��� 32 λ stack �Ƿ������� 12 bytes��3 * 4)������ stack ���Ƿ����� expand-down ��
        ;; 1) expand-down:  esp - 12 > SS.limit && esp <= SS.Top
        ;; 2) expand-up:    esp <= SS.limit 
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsDesc + 4], (1 << 10)  ; SS.E λ
        jz do_interrupt_for_intra_privilege.CheckSsLimit.ExpandUp
        
        
do_interrupt_for_intra_privilege.CheckSsLimit.ExpandDown:
        ;;
        ;; ��� expand-down ���Ͷ�
        ;;
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        sub esi, 12
        cmp esi, eax
        jbe do_interrupt_for_intra_privilege.Ss_01B
        
        ;;
        ;; ���� SS.B λ���
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsDesc + 4], (1 << 22)  ; SS.B λ
        jnz do_interrupt_for_intra_privilege.GetCsLimit
        mov eax, 0FFFFFh                                ;; SS.B = 0 ʱ��expand-down ������Ϊ 0FFFFFh
        
do_interrupt_for_intra_privilege.CheckSsLimit.ExpandUp:
        ;;
        ;; ��� expand-up ����
        ;;        
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        cmp esi, eax
        ja do_interrupt_for_intra_privilege.Ss_01B

do_interrupt_for_intra_privilege.GetCsLimit:
        ;;
        ;; step 2: ��ȡ CS.limit
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc]         ; limit[15:0]
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]
        and esi, 0F0000h
        or eax, esi                                                                     ; limit[19:0]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4], (1 << 23)
        jz do_interrupt_for_intra_privilege.CheckCsLimit
        shl eax, 12
        add eax, 0FFFh
        
do_interrupt_for_intra_privilege.CheckCsLimit:
        ;;
        ;; step 3: EIP �Ƿ񳬳� cs.limit
        ;;
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsLimit], eax
        movzx esi, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc]              ; offset[15:0]
        mov edi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4]
        and edi, 0FFFF0000h                                                             ; offset[31:16]
        or esi, edi
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip], esi                   ; ����Ŀ�� RIP
        cmp esi, eax
        ja do_interrupt_for_intra_privilege.Gp_01B

        ;;
        ;; step 4: ѹ�뷵����Ϣ
        ;;
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 11)
        jz do_interrupt_for_intra_privilege.Push16
        
        ;;
        ;; ѹ�� 32 λ���� 
        ;;
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        mov [edx - 4], eax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldCs]
        mov [edx - 8], eax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip]
        mov [edx - 12], eax

        ;;
        ;; ���� ESP
        ;;
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        sub eax, 12
        SetVmcsField    GUEST_RSP, eax

do_interrupt_for_intra_privilege.LoadCsEip:        
        ;;
        ;; step 5: ���� CS:EIP
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCs]
        SetVmcsField    GUEST_CS_SELECTOR, eax
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_CS_ACCESS_RIGHTS, eax 
        DoVmWrite       GUEST_CS_LIMIT, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsLimit]
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 2]
        and eax, 00FFFFFFh
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]
        and esi, 0FF000000h
        or eax, esi
        SetVmcsField    GUEST_CS_BASE, eax        
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip]        
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 11)
        cmovnz eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip]
        SetVmcsField    GUEST_RIP, eax        

        ;;
        ;; step 6: ���� eflags
        ;;
        mov eax, ~(FLAGS_TF | FLAGS_NT | FLAGS_VM | FLAGS_RF)
        mov esi, ~(FLAGS_TF | FLAGS_NT | FLAGS_VM | FLAGS_RF | FLAGS_IF)
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 8)
        cmovz eax, esi
        and eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        SetVmcsField    GUEST_RFLAGS, eax
        mov eax, DO_INTERRUPT_SUCCESS
        jmp do_interrupt_for_intra_privilege.Done        
                        
do_interrupt_for_intra_privilege.Push16:
        ;;
        ;; ѹ�� 16 λ����
        ;;
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        mov [edx - 2], ax
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldCs]
        mov [edx - 4], ax
        mov ax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip]
        mov [edx - 8], ax
        
        ;;
        ;; ���� RSP
        ;;
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        sub eax, 8
        SetVmcsField    GUEST_RSP, eax
        jmp do_interrupt_for_intra_privilege.LoadCsEip
        
do_interrupt_for_intra_privilege.IdtGate16: 
        ;;
        ;; ��� 16 λ IDT-gate �stack �Ƿ������� 6 bytes��3 * 2)������ stack ���Ƿ����� expand-down ��
        ;; 1) expand-down:  esp - 6 > SS.limit && esp <= SS.Top
        ;; 2) expand-up:    esp <= SS.limit 
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsDesc + 4], (1 << 10)  ; SS.E λ
        jz do_interrupt_for_intra_privilege.IdtGate16.ExpandUp
        
        
do_interrupt_for_intra_privilege.IdtGate16.ExpandDown:
        ;;
        ;; ��� expand-down ���Ͷ�
        ;;
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        sub esi, 6
        cmp esi, eax
        jbe do_interrupt_for_intra_privilege.Ss_01B
        
        ;;
        ;; ���� SS.B λ���
        ;;
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsDesc + 4], (1 << 22)  ; SS.B λ
        jnz do_interrupt_for_intra_privilege.GetCsLimit
        mov eax, 0FFFFFh                                ;; SS.B = 0 ʱ��expand-down ������Ϊ 0FFFFFh
        
do_interrupt_for_intra_privilege.IdtGate16.ExpandUp:
        ;;
        ;; ��� expand-up ����
        ;;        
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        cmp esi, eax
        jbe do_interrupt_for_intra_privilege.GetCsLimit



do_interrupt_for_intra_privilege.Ss_01B:
        mov eax, 01
        mov ecx, INJECT_EXCEPTION_SS
        jmp do_interrupt_for_intra_privilege.ReflectException

do_interrupt_for_intra_privilege.Gp_01B:
        mov eax, 01
        mov ecx, INJECT_EXCEPTION_GP


do_interrupt_for_intra_privilege.ReflectException:        
        ;;
        ;; ע���쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, ecx   
        mov eax, DO_INTERRUPT_ERROR

do_interrupt_for_intra_privilege.Done:
        pop ecx
        pop edx
        pop ebx
        pop ebp
        ret        





;-----------------------------------------------------------------------
; do_interrupt_for_intra_privilege_longmode()
; input:
;       none
; output:
;       eax - status code
; ������
;       1) ���� longmode ģʽ�µ���Ȩ������жϣ�ͬ����
;-----------------------------------------------------------------------
do_interrupt_for_intra_privilege_longmode:
        push ebp
        push ebx
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        DEBUG_RECORD    "[do_interrupt_for_intra_privilege_longmode]..."


        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        
        ;;
        ;; ��ǰ RSP
        ;;
        REX.Wrxb
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRsp]
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp], esi

        ;;
        ;; step 1: ��� IST
        ;;
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4]
        and eax, 7
        jz do_interrupt_for_intra_privilege_longmode.CheckRsp
        lea eax, [eax * 8 + 28]
        lea esi, [eax + 7]
        cmp esi, [ebx + VMB.GuestTmb + GTMB.TssLimit]
        ja do_interrupt_for_intra_privilege_longmode.Ts_TsSelector_01B

        ;;
        ;; ��ȡ IST pointer
        ;;        
        REX.Wrxb
        add eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TssBase]
        REX.Wrxb
        mov esi, [eax]
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp], esi

do_interrupt_for_intra_privilege_longmode.CheckRsp:         
        ;;
        ;; step 2: ��� RSP �Ƿ�Ϊ canonical ��ַ��ʽ
        ;;
        REX.Wrxb
        mov eax, esi
        REX.Wrxb
        shl eax, 16
        REX.Wrxb
        sar eax, 16
        REX.Wrxb
        cmp eax, esi
        jne do_interrupt_for_intra_privilege_longmode.Ss_01B

        REX.Wrxb
        and esi, ~0Fh                                                   ; new RSP & FFFF_FFFF_FFFF_FFF0h
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp], esi
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp], eax         ;; ���� RSP

        ;;
        ;; step 3: ��ȡ RIP������� RIP �Ƿ�Ϊ canonical ��ַ
        ;;
        movzx esi, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc]              ; offset[15:0]
        mov edi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4]
        and edi, 0FFFF0000h                                                             ; offset[31:16]
        or esi, edi
        mov edi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 8]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip], esi                   ; ����Ŀ�� RIP
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip + 4], edi
        shl edi, 16
        sar edi, 16
        cmp edi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip + 4]
        jne do_interrupt_for_intra_privilege_longmode.Gp_01B

        ;;
        ;; step 4: ѹ�뷵����Ϣ
        ;;
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rsp]
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldSs]
        REX.Wrxb
        mov [edx - 8], eax
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRsp]
        REX.Wrxb
        mov [edx - 16], eax
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        REX.Wrxb
        mov [edx - 24], eax
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldCs]
        REX.Wrxb
        mov [edx - 32], eax
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip]
        REX.Wrxb
        mov [edx - 40], eax

        ;;
        ;; step 5: �����µ� RSP ֵ
        ;;
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRsp]
        REX.Wrxb
        sub eax, 40
        SetVmcsField    GUEST_RSP, eax 

        ;;
        ;; step 6: ���� CS:RIP
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCs]
        SetVmcsField    GUEST_CS_SELECTOR, eax
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_CS_ACCESS_RIGHTS, eax 
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 2]
        and eax, 00FFFFFFh
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]
        and esi, 0FF000000h
        or eax, esi
        SetVmcsField    GUEST_CS_BASE, eax        
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc]         ; limit[15:0]
        mov esi, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4]
        and esi, 0F0000h
        or eax, esi                                                                     ; limit[19:0]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsDesc + 4], (1 << 23)
        jz do_interrupt_for_intra_privilege_longmode.SetCsLimit
        shl eax, 12
        add eax, 0FFFh        
do_interrupt_for_intra_privilege_longmode.SetCsLimit:
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetCsLimit], eax
        SetVmcsField    GUEST_CS_LIMIT, eax
        REX.Wrxb
        mov eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TargetRip]
        SetVmcsField    GUEST_RIP, eax

        ;;
        ;; step 7: ���� rflags
        ;;
        mov eax, ~(FLAGS_TF | FLAGS_NT | FLAGS_VM | FLAGS_RF)
        mov esi, ~(FLAGS_TF | FLAGS_NT | FLAGS_VM | FLAGS_RF | FLAGS_IF)
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtDesc + 4], (1 << 8)
        cmovz eax, esi
        and eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags]
        SetVmcsField    GUEST_RFLAGS, eax
        mov eax, DO_INTERRUPT_SUCCESS
        jmp do_interrupt_for_intra_privilege_longmode.Done
        
        
do_interrupt_for_intra_privilege_longmode.Gp_01B:
        mov eax, 01
        mov ecx, INJECT_EXCEPTION_GP
        jmp do_interrupt_for_intra_privilege_longmode.ReflectException
        
        
do_interrupt_for_intra_privilege_longmode.Ts_TsSelector_01B:
        movzx eax, WORD [ebx + VMB.GuestTmb + GTMB.TssSelector]
        or eax, 01
        mov ecx, INJECT_EXCEPTION_TS
        jmp do_interrupt_for_intra_privilege_longmode.ReflectException
        
do_interrupt_for_intra_privilege_longmode.Ss_01B:
        mov eax, 01
        mov ecx, INJECT_EXCEPTION_SS        
        
do_interrupt_for_intra_privilege_longmode.ReflectException:
        ;;
        ;; ע���쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, ecx   
        mov eax, DO_INTERRUPT_ERROR
        
do_interrupt_for_intra_privilege_longmode.Done:
        pop ecx
        pop edx
        pop ebx
        pop ebp        
        ret




;**********************************
; �쳣�������̱�                  *
;**********************************
DoExceptionTable:
        DD      do_DE, do_DB, do_NMI, do_BP, do_DF
        DD      do_BR, do_UD, do_NM, do_DF, DoReserved
        DD      do_TS, do_NP, do_SS, do_GP, do_PF
        DD      DoReserved, do_MF, do_AC, do_MC, do_XM
        DD      DoReserved, DoReserved, DoReserved, DoReserved, DoReserved
        DD      DoReserved, DoReserved, DoReserved, DoReserved, DoReserved
        DD      DoReserved, DoReserved
