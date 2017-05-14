;*************************************************
;* VmxExit.asm                                   *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************




;-----------------------------------------------------------------------
; GetExceptionInfo()
; input:
;       none
; output:
;       none
; ������
;       1) �ռ��� exception ���� NMI ������ vector ��Ϣ
;-----------------------------------------------------------------------
GetExceptionInfo:

        ret



;-----------------------------------------------------------------------
; GetMovCrInfo()
; input:
;       none
; output:
;       none
; ������
;       1) �ռ����� MOV-CR ���� VM-exit ����Ϣ
;-----------------------------------------------------------------------
GetMovCrInfo:
        push ebp
        push ebx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        lea ebx, [ebp + PCB.GuestExitInfo]

        ;;
        ;; ��Ĵ���ֵ
        ;;
        xor eax, eax
        REX.Wrxb
        mov [ebx + MOV_CR_INFO.Register], eax
        REX.Wrxb
        mov [ebx + MOV_CR_INFO.ControlRegister], eax
        
        ;;
        ;; ��ȡ VM-exit ��ϸ��Ϣ
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        
        ;;
        ;; ��������
        ;;
        mov ecx, eax
        shr ecx, 4
        and ecx, 3
        mov [ebx + MOV_CR_INFO.Type], ecx

        ;;
        ;; �жϷ�������
        ;;
        cmp ecx, CAT_LMSW
        je GetMovCrInfo.Lmsw                            ;; ���� LMSW
        cmp ecx, CAT_MOV_TO_CR
        je GetMovCrInfo.MovToCr                         ;; ���� MOV-to-CR
        cmp ecx, CAT_MOV_FROM_CR
        jne GetMovCrInfo.Done                           ;; ���� MOV-from-CR

GetMovCrInfo.MovFromCr:        
        ;;
        ;; ��ȡĿ��Ĵ��� ID
        ;;
        mov esi, eax
        shr esi, 8
        and esi, 0Fh
        mov [ebx + MOV_CR_INFO.RegisterID], esi
        
        ;;
        ;; ��ȡԴ���ƼĴ���ֵ
        ;;        
        mov esi, eax
        and esi, 0Fh        
        cmp esi, 0
        mov eax, GUEST_CR0
        je GetMovCrInfo.MovFromCr.GetCr
        cmp esi, 3
        mov eax, GUEST_CR3
        je GetMovCrInfo.MovFromCr.GetCr

        mov eax, GUEST_CR4
        
GetMovCrInfo.MovFromCr.GetCr:        
        DoVmRead        eax, [ebx + MOV_CR_INFO.ControlRegister]

        jmp GetMovCrInfo.Done
        

GetMovCrInfo.MovToCr:
        ;;
        ;; ��ȡĿ����ƼĴ���ID
        ;;
        mov esi, eax
        and esi, 0Fh
        mov [ebx + MOV_CR_INFO.ControlRegisterID], esi

        ;;
        ;; ��ȡԴ�Ĵ���ֵ 
        ;;
        mov esi, eax
        shr esi, 8
        and esi, 0Fh
        call get_guest_register_value
        REX.Wrxb
        mov [ebx + MOV_CR_INFO.Register], eax


        jmp GetMovCrInfo.Done
        
GetMovCrInfo.Lmsw:        
        ;;
        ;; ��ȡ LMSW Դ������ֵ
        ;;
        mov esi, eax
        shr esi, 16
        and esi, 0FFFFh
        mov [ebx + MOV_CR_INFO.LmswSource], esi
        
        ;;
        ;; ��� LMSW ָ�����������
        ;;
        test eax, (1 << 6)
        jz GetMovCrInfo.Done
        
        ;;
        ;; �����ڴ������ʱ����ȡ���Ե�ֵַ
        ;;
        REX.Wrxb
        mov esi, [ebp + PCB.ExitInfoBuf + EXIT_INFO.GuestLinearAddress]
        REX.Wrxb
        mov [ebx + MOV_CR_INFO.LinearAddress], esi

GetMovCrInfo.Done:        
        pop ecx
        pop ebx
        pop ebp
        ret
        




;-----------------------------------------------------------------------
; GetTaskSwitchInfo()
; input:
;       none
; output:
;       none
; ������
;       1) �ռ��� exception ���� NMI ������ vector ��Ϣ
;-----------------------------------------------------------------------
GetTaskSwitchInfo:
        push ebp
        push ebx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        lea ebx, [ebp + PCB.GuestExitInfo]
        
        ;;
        ;; ��ȡ VM-exit ��Ϣ 
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        movzx esi, ax
        mov [ebx + TASK_SWITCH_INFO.NewTrSelector], esi                 ; ��¼Ŀ�� TSS selector
        shr eax, 30
        and eax, 3
        mov [ebx + TASK_SWITCH_INFO.Source], eax                        ; �����л�Դ
        GetVmcsField    GUEST_TR_SELECTOR
        mov [ebx + TASK_SWITCH_INFO.CurrentTrSelector], eax             ; ��¼��ǰ TSS selector
        
        ;;
        ;; ��ȡָ���
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InstructionLength]
        mov [ebx + TASK_SWITCH_INFO.InstructionLength], eax
        
        ;;
        ;; ��ȡ GDT/IDT base
        ;;
        GetVmcsField    GUEST_GDTR_BASE
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_va
        REX.Wrxb
        mov [ebx + TASK_SWITCH_INFO.GuestGdtBase], eax
        REX.Wrxb
        mov edx, eax                                                    ; edx = GuestGdtBase
        GetVmcsField    GUEST_IDTR_BASE
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_va
        REX.Wrxb
        mov [ebx + TASK_SWITCH_INFO.GuestIdtBase], eax

        ;;
        ;; ��ȡ GDT/IDT limit
        ;;
        GetVmcsField    GUEST_GDTR_LIMIT
        mov [ebx + TASK_SWITCH_INFO.GuestGdtLimit], eax
        GetVmcsField    GUEST_IDTR_LIMIT
        mov [ebx + TASK_SWITCH_INFO.GuestIdtLimit], eax
        

        ;;
        ;; ��ȡ current/new-task TSS ��������ַ
        ;;
        mov eax, [ebx + TASK_SWITCH_INFO.CurrentTrSelector]       
        REX.Wrxb
        lea eax, [edx + eax]                                            ; Gdt.Base + selector
        REX.Wrxb
        mov [ebx + TASK_SWITCH_INFO.CurrentTssDesc], eax                ; ��¼��ǰ TSS ��������ַ
        mov eax, [ebx + TASK_SWITCH_INFO.NewTrSelector]                 ; Ŀ�� TSS selector
        REX.Wrxb
        lea eax, [edx + eax]                                            ; Ŀ�� TSS ��������ַ = Gdt.Base + selector
        REX.Wrxb
        mov [ebx + TASK_SWITCH_INFO.NewTaskTssDesc], eax

        ;;
        ;; ��ȡ current TSS ��ַ
        ;;
        GetVmcsField    GUEST_TR_BASE
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_va
        REX.Wrxb
        mov [ebx + TASK_SWITCH_INFO.CurrentTss], eax                    ; ��ǰ TSS ��ַ

        ;;
        ;; ��ȡ new-task TSS ��ַ
        ;; *** ע�⣬����Ҫ��ȡ 64 λ TSS ��ַ���� longmode �²�֧�������л���***        
        ;;
        REX.Wrxb
        mov eax, [ebx + TASK_SWITCH_INFO.NewTaskTssDesc]
        mov esi, [eax]                                                  ; ������ low 32
        mov edi, [eax + 4]                                              ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                                 ; TSS ��ַ bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                             ; TSS ��ַ bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                              ; TSS ��ַ bits 23:16
        or edi, eax
        or esi, edi                                                     ; TSS ��ַ bits 31:0
        mov [ebx + TASK_SWITCH_INFO.NewTaskTssBase], esi                ; TR.base �� guest-linear address ֵ      
        call get_system_va_of_guest_va
        REX.Wrxb
        mov [ebx + TASK_SWITCH_INFO.NewTaskTss], eax                    ; Ŀ�� TSS ��ַ

        pop edx
        pop ebx
        pop ebp
        ret



;-----------------------------------------------------------------------
; GetDescTableRegisterInfo()
; input:
;       none
; output:
;       none
; ������
;       1) �ռ��ɷ�����������Ĵ��������� vector ��Ϣ
;-----------------------------------------------------------------------
GetDescTableRegisterInfo:
        push ebp
        push ebx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        REX.Wrxb
        lea ebx, [ebp + PCB.GuestExitInfo]

        ;;
        ;; �ռ�������Ϣ
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        mov [ebx + INSTRUCTION_INFO.Displacement], eax
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InstructionLength]
        mov [ebx + INSTRUCTION_INFO.InstructionLength], eax
        mov edx, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InstructionInfo]
        mov [ebx + INSTRUCTION_INFO.Flags], edx

        ;;
        ;; ������ȡ��Ϣ
        ;;
        mov eax, edx
        and eax, 03h
        mov [ebx + INSTRUCTION_INFO.Scale], eax                 ; scale ֵ
        mov eax, edx
        shr eax, 7
        and eax, 07h
        mov [ebx + INSTRUCTION_INFO.AddressSize], eax           ; address size
        mov eax, edx
        shr eax, 15
        and eax, 07h
        mov [ebx + INSTRUCTION_INFO.Segment], eax               ; segment
        mov eax, edx
        shr eax, 18
        and eax, 0Fh
        mov [ebx + INSTRUCTION_INFO.Index], eax                 ; index
        mov eax, edx
        shr eax, 23
        and eax, 0Fh
        mov [ebx + INSTRUCTION_INFO.Base], eax                  ; base
        mov eax, edx
        shr eax, 28
        and eax, 03h
        mov [ebx + INSTRUCTION_INFO.Type], eax                  ; instruction type

        ;;
        ;; LLDT, SLDT, LTR, STR ָ��ļĴ���������
        ;;
        mov eax, edx
        shr eax, 3
        and eax, 0Fh
        mov [ebx + INSTRUCTION_INFO.Register], eax
        
        
        ;;
        ;; ���� operand size
        ;; 1) SGDT/SIDT���ڷ� 64-bit ���� 32λ���� 64-bit ���� 64λ
        ;; 2) LGDT/LIDT��16λ��32λ��64λ
        ;;             
        GetVmcsField    GUEST_CS_ACCESS_RIGHTS
        mov esi, INSTRUCTION_OPS_DWORD
        
        cmp edx, INSTRUCTION_TYPE_SGDT
        je GetDescTableRegisterInfo.Ops.@1
        cmp edx, INSTRUCTION_TYPE_SIDT
        je GetDescTableRegisterInfo.Ops.@1
        
        bt edx, 11                                              ; operand size λ
        mov esi, 0
        
GetDescTableRegisterInfo.Ops.@1:
        adc esi, 0
        test eax, SEG_L
        mov eax, INSTRUCTION_OPS_QWORD
        cmovz eax, esi
        mov [ebx + INSTRUCTION_INFO.OperandSize], eax           ; operand size
                
        pop edx
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------------------------
; get_interrupt_info()
; input:
;       none
; output:
;       none
; ������
;       1) �ռ��жϴ��������Ϣ
;-----------------------------------------------------------------------
get_interrupt_info:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        
        ;;
        ;; ���� IDT-vectoring information �ֶη����ж�����
        ;; 1) IDT-vectoring information [31] = 0 ʱ������Ҫ����
        ;; 2) �� IDT-vectoring informating ��ȡ�ж������ż����ͣ�������
        ;;
        mov BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.InterruptType], INTERRUPT_TYPE_NONE
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.IdtVectoringInfo]
        test eax, FIELD_VALID_FLAG
        jz get_interrupt_info.Done
        and eax, 7FFh                                                           ; bits[11:0]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Vector], ax               ; ���������ż��ж�����

        ;;
        ;; guest RIP
        ;;
        GetVmcsField    GUEST_RIP
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Rip], eax
                
        
        ;;
        ;; IDT base
        ;;
        REX.Wrxb
        mov esi, [ebx + VMB.GuestImb + GIMB.IdtBase]
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.IdtBase], eax
        
        ;;
        ;; GDT base
        ;;
        REX.Wrxb
        mov esi, [ebx + VMB.GuestGmb + GGMB.GdtBase]
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.GdtBase], eax
        
        ;;
        ;; TSS
        ;;
        REX.Wrxb
        mov esi, [ebx + VMB.GuestTmb + GTMB.TssBase]
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.TssBase], eax


        ;;
        ;; guest CPL, status
        ;;
        GetVmcsField    GUEST_CS_SELECTOR
        and eax, 3
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.Cpl], ax        
        GetVmcsField    GUEST_IA32_EFER_FULL
        test eax, EFER_LMA
        setnz BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.GuestStatus]
                
        ;;
        ;; old SS, RIP, FLAGS, CS, EIP
        ;;
        REX.Wrxb
        mov esi, [ebx + VMB.VsbBase]
        REX.Wrxb
        mov eax, [esi + VSB.Rip]
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip], eax
        REX.Wrxb
        mov eax, [esi + VSB.Rsp]
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRsp], eax
        mov eax, [esi + VSB.Rflags]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldFlags], eax
        GetVmcsField    GUEST_CS_SELECTOR
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldCs], ax
        GetVmcsField    GUEST_SS_SELECTOR
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldSs], ax        

        ;;
        ;; ���� return RIP ֵ
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InstructionLength]
        cmp BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.InterruptType], INTERRUPT_TYPE_SOFTWARE
        je get_interrupt_info.@1
        cmp BYTE [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.InterruptType], INTERRUPT_TYPE_PRIVILEGE
        jne get_interrupt_info.@2
get_interrupt_info.@1:        
        REX.Wrxb
        add [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldRip], eax
get_interrupt_info.@2:        

        ;;
        ;; current SS ������
        ;;
        movzx eax, WORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.OldSs]
        and eax, 0FFF8h
        REX.Wrxb
        add eax, [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.GdtBase]
        mov esi, [eax]
        mov edi, [eax + 4]
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsDesc], esi
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsDesc + 4], edi
        
        ;;
        ;; current SS limit
        ;;
        and esi, 0FFFFh                                                                 ; limit[15:0]
        and edi, 0F0000h
        or esi, edi                                                                     ; limit[19:0]
        test DWORD [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsDesc + 4], (1 << 23)
        jz get_interrupt_info.SsLimit
        shl esi, 12
        add esi, 0FFFh
get_interrupt_info.SsLimit:                
        mov [ebp + PCB.GuestExitInfo + INTERRUPT_INFO.CurrentSsLimit], esi        
 
get_interrupt_info.Done:
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------------------------
; get_io_instruction_info()
; input:
;       none
; output:
;       none
; ������
;       1) �ռ��� IO ָ������ VM-exit �������Ϣ
;-----------------------------------------------------------------------
get_io_instruction_info:
        push ebp
        push ebx
        
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
        ;; IoFlags
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.IoFlags], eax
        
        ;;
        ;; OperandSize
        ;;
        mov esi, eax
        and esi, 7
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.OperandSize], esi
        
        ;;
        ;; IoPort
        ;;
        mov esi, eax
        shr esi, 16
        and esi, 0FFFFh
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.IoPort], esi
        
        
        test eax, IO_FLAGS_STRING
        jnz get_io_info.String
        
        ;;
        ;; �Ǵ�ָ��
        ;;
        test eax, IO_FLAGS_IN
        jnz get_io_info.Done
        ;;
        ;; ��� operand size
        ;;
        mov eax, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.OperandSize]
        cmp eax, IO_OPS_BYTE
        je get_io_info.Byte        
        cmp eax, IO_OPS_WORD
        je get_io_info.Word
        
        ;;
        ;; ���� dword 
        ;;
        mov esi, [ebx + VSB.Rax]
        jmp get_io_info.GetValue
        
get_io_info.Byte:
        ;;
        ;; ���� byte
        ;;
        movzx esi, BYTE [ebx + VSB.Rax]
        jmp get_io_info.GetValue
        
get_io_info.Word:
        ;;
        ;; ���� word
        ;;
        movzx esi, WORD [ebx + VSB.Rax]
        jmp get_io_info.GetValue
        
        
get_io_info.String:
        test eax, IO_FLAGS_REP
        jz get_io_info.String.@1
        ;;
        ;; count
        ;;
        REX.Wrxb
        mov eax, [ebx + VSB.Rcx]
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Count], eax
        
get_io_info.String.@1:        
        ;;        
        ;; Address size
        ;;
        mov eax, [ebp + PCB.ExitInfoBuf + EXIT_INFO.InstructionInfo]
        mov esi, eax
        shr esi, 7
        and esi, 7
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.AddressSize], esi
        
        ;;
        ;; segment
        ;;
        shr eax, 15
        and eax, 7
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Segment], eax
        
        ;;
        ;; linear address
        ;;
        mov eax, esi
        REX.Wrxb
        mov esi, [ebp + PCB.ExitInfoBuf + EXIT_INFO.GuestLinearAddress]
        ;;
        ;; ��� address size
        ;;
        cmp eax, IO_ADRS_WORD
        je get_io_info.String.AddrWord
        cmp eax, IO_ADRS_DWORD
        jne get_io_info.String.GetAddr
        ;;
        ;; 32 λ��ַ
        ;;
        mov esi, esi  
        jmp get_io_info.String.GetAddr              
        
get_io_info.String.AddrWord:
        ;;
        ;; 16 λ��ַ
        ;;
        movzx esi, si
        
get_io_info.String.GetAddr:
        ;;
        ;; ��ȡ system ��ֵַ
        ;;
        call get_system_va_of_guest_os
        REX.Wrxb
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.LinearAddress], eax
        REX.Wrxb
        mov ebx, eax
        REX.Wrxb
        test eax, eax
        jz get_io_info.Done
        
        ;;
        ;; ��ȡ����д�� IO ports ��ֵ
        ;;        
        test DWORD [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.IoFlags], IO_FLAGS_IN
        jnz get_io_info.Done        
        
        ;;
        ;; ��� operand size
        ;;
        mov eax, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.OperandSize]
        cmp eax, IO_OPS_BYTE
        je get_io_info.String.Byte
        cmp eax, IO_OPS_WORD
        je get_io_info.String.Word
        
        ;;
        ;; ���� 32 λ
        ;;
        mov esi, [ebx]
        jmp get_io_info.GetValue
        
get_io_info.String.Byte:
        ;;
        ;; ���� 8 λ
        ;;
        movzx esi, BYTE [ebx]
        jmp get_io_info.GetValue
        
get_io_info.String.Word:
        ;;
        ;; ���� 16 λ
        ;;
        movzx esi, WORD [ebx]
        
get_io_info.GetValue:        
        mov [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Value], esi        
        
get_io_info.Done:
        pop ebx
        pop ebp
        ret



;**********************************
; VM-exit��Ϣ�������̱�           *
;**********************************

GetVmexitInfoRoutineTable:
