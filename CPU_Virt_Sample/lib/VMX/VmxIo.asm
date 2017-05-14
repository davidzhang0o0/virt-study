;*************************************************
;* VmxIo.asm                                     *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


;;
;; ������� IO �˿ڵ�����
;;



;-----------------------------------------------------------------------
; GetIoVte()
; input:
;       esi - IO port
; output:
;       eax - IO VTE��value table entry����ַ
; ������
;       1) ���� IO �˿ڶ�Ӧ�� VTE �����ַ
;       2) ��������Ӧ�� IO Vte ʱ������ 0 ֵ��
;-----------------------------------------------------------------------
GetIoVte:
        push ebp
        push ebx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        cmp DWORD [ebx + VMB.IoVteCount], 0
        je GetIoVte.NotFound
        
        REX.Wrxb
        mov eax, [ebx + VMB.IoVteBuffer]               
        
GetIoVte.@1:                
        cmp esi, [eax]                                  ; ��� IO �˿�ֵ
        je GetIoVte.Done
        REX.Wrxb
        add eax, IO_VTE_SIZE                            ; ָ����һ�� entry
        REX.Wrxb
        cmp eax, [ebx + VMB.IoVteIndex]
        jb GetIoVte.@1
GetIoVte.NotFound:        
        xor eax, eax
GetIoVte.Done:        
        pop ebx
        pop ebp
        ret



;-----------------------------------------------------------------------
; AppendIoVte()
; input:
;       esi - IO port
;       edi - value
; output:
;       eax - VTE ��ַ
; ������
;       1) ���� IO �˿�ֵ�� IoVteBuffer ��д�� IO VTE
;-----------------------------------------------------------------------
AppendIoVte:
        push ebp
        push ebx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]     
        mov ebx, edi
        call GetIoVte
        REX.Wrxb
        test eax, eax
        jnz AppendIoVte.WriteVte
        
        mov eax, IO_VTE_SIZE
        REX.Wrxb
        xadd [ebp + VMB.IoVteIndex], eax
        inc DWORD [ebp + VMB.IoVteCount]
                
AppendIoVte.WriteVte:
        ;;
        ;; д�� IO VTE ����
        ;;
        mov [eax + IO_VTE.IoPort], esi
        mov [eax + IO_VTE.Value], ebx
        pop ebx
        pop ebp
        ret
        


;-----------------------------------------------------------------------
; GetExtIntRte()
; input:
;       esi - Processor index
; output:
;       eax - ExtInt RTE��route table entry����ַ
; ������
;       1) ���� processor index ��Ӧ�� EXTINT_RTE �����ַ
;       2) ��������Ӧ�� EXTINT_RTE ����ʱ������ 0 ֵ��
;-----------------------------------------------------------------------
GetExtIntRte:
        push ebp
                
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  

        REX.Wrxb
        mov eax, [ebp + SDA.ExtIntRtePtr]
        cmp DWORD [ebp + SDA.ExtIntRteCount], 0
        je GetExtIntRte.NotFound
                   
        
GetExtIntRte.@1:                
        cmp esi, [eax]                                   ; ��� processor index ֵ
        je GetExtIntRte.Done
        REX.Wrxb
        add eax, EXTINT_RTE_SIZE                        ; ָ����һ�� entry
        REX.Wrxb
        cmp eax, [ebp + SDA.ExtIntRteIndex]
        jb GetExtIntRte.@1
GetExtIntRte.NotFound:        
        xor eax, eax
GetExtIntRte.Done:        
        pop ebp
        ret



;-----------------------------------------------------------------------
; GetExtIntRteWithVector()
; input:
;       esi - vector
; output:
;       eax - ExtInt RTE��route table entry����ַ
; ������
;       1) ���� vector ��Ӧ�� EXTINT_RTE �����ַ
;       2) ��������Ӧ�� EXTINT_RTE ����ʱ������ 0 ֵ��
;-----------------------------------------------------------------------
GetExtIntRteWithVector:
        push ebp
                
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  

        REX.Wrxb
        mov eax, [ebp + SDA.ExtIntRtePtr]
        cmp DWORD [ebp + SDA.ExtIntRteCount], 0
        je GetExtIntRteWithVector.NotFound
                           
GetExtIntRteWithVector.@1:                
        cmp esi, [eax + EXTINT_RTE.Vector]              ; ��� vecotr ֵ
        je GetExtIntRteWithVector.Done
        REX.Wrxb
        add eax, EXTINT_RTE_SIZE                        ; ָ����һ�� entry
        REX.Wrxb
        cmp eax, [ebp + SDA.ExtIntRteIndex]
        jb GetExtIntRteWithVector.@1
GetExtIntRteWithVector.NotFound:        
        xor eax, eax
GetExtIntRteWithVector.Done:        
        pop ebp
        ret
        
        
        

;-----------------------------------------------------------------------
; AppendExtIntRte()
; input:
;       esi - vector
; output:
;       eax - EXTINT_RTE ��ַ
; ������
;       1) ���� processor ID �� ExtIntRteBuffer д�� ITE 
;-----------------------------------------------------------------------
AppendExtIntRte:
        push ebp
        push ebx
        push ecx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        
        REX.Wrxb
        mov ebx, [ebp + PCB.SdaBase]
        mov ecx, esi
        mov esi, [ebp + PCB.ApicId]
        call GetExtIntRte
        REX.Wrxb
        test eax, eax
        jnz AppendExtIntRte.WriteRte
        
        mov eax, EXTINT_RTE_SIZE
        REX.Wrxb
        xadd [ebx + SDA.ExtIntRteIndex], eax
        lock inc DWORD [ebx + SDA.ExtIntRteCount]
                
AppendExtIntRte.WriteRte:
        ;;
        ;; д�� IO VTE ����
        ;;
        mov esi, [ebp + PCB.ProcessorIndex]
        mov [eax + EXTINT_RTE.ProcessorIndex], esi
        mov [eax + EXTINT_RTE.Vector], ecx
        lock or DWORD [eax + EXTINT_RTE.Flags], RTE_8259_IRQ0

        pop ecx
        pop ebx
        pop ebp
        ret
        
        


;-----------------------------------------------------------------------
; do_guest_io_process()
; input:
;       none
; output:
;       eax - status code
; ������
;       1) ���� guest IO ָ�����Ӧ����
;-----------------------------------------------------------------------
do_guest_io_process:
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
        
        cmp DWORD [ebp + PCB.LastStatusCode], STATUS_GUEST_PAGING_ERROR
        je do_guest_io_process.Pf
        
        mov edx, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.IoFlags]
        test edx, IO_FLAGS_IN
        jnz do_guest_io_process.In
        
        ;;
        ;; ���� OUT/OUTS
        ;;
do_guest_io_process.Out:
        DEBUG_RECORD    "processing OUT instruciton ..."

        ;;
        ;; #### ��Ϊʾ��������ʵ�ִ�ָ��Ĵ��� ####
        ;;
        test edx, IO_FLAGS_STRING
        jnz do_guest_io_process.Done

        ;;
        ;; �� guest ����д IO �Ĵ�����ֵ������ IO-VTE ��
        ;;        
        mov ecx, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.IoPort]
        mov esi, ecx
        mov edi, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Value]
        call AppendIoVte
 
        ;;
        ;; ��� guest �Ƿ��� 8259 ��ʼ����������!
        ;; 1) ����Ƿ�д MASTER_ICW1_PORT �˿�
        ;;    a) �ǣ�������һ���Ƿ�Ϊ MASTER_ICW2_PORT �˿�
        ;;    b) �������
        ;;

       
        ;;
        ;; ����Ƿ�Ϊ 20h �˿�
        ;;
        cmp ecx, 20h
        jne do_guest_io_process.Out.@1

        movzx eax, BYTE [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Value]       
        ;;
        ;; ���д��ֵ��
        ;; 1) bit 4 = 1 ʱ��д�� ICW ��
        ;; 2) bit 5 = 1 ʱ��д�� EOI ��
        ;;
        test eax, (1 << 4)
        jnz do_guest_io_process.Out.20h.ICW1
        test eax, (1 << 5)
        jz do_guest_io_process.Done
        
        ;;
        ;; ���� EOI ������� VMM �� local APIC д�� EOI
        ;;
        LAPIC_EOI_COMMAND
        jmp do_guest_io_process.Done        

do_guest_io_process.Out.20h.ICW1:        
        ;;
        ;; ���� 8259 MASTER ��ʼ����־λ
        ;;        
        or DWORD [ebx + VMB.IoOperationFlags], IOP_FLAGS_8259_MASTER_INIT
        jmp do_guest_io_process.Done

do_guest_io_process.Out.@1:
        ;;
        ;; ���������Ƿ�д MASTER_ICW2_PORT �˿�
        ;;
        cmp ecx, MASTER_ICW2_PORT
        jne do_guest_io_process.Done
        test DWORD [ebx + VMB.IoOperationFlags], IOP_FLAGS_8259_MASTER_INIT
        jz do_guest_io_process.Done

        ;;
        ;; �� 8259 MASTER ��ʼ����־λ
        ;;
        and DWORD [ebx + VMB.IoOperationFlags], ~IOP_FLAGS_8259_MASTER_INIT
        
        ;;
        ;; �� vector ��ӵ� ExtIntRte ������
        ;;
        mov esi, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Value]
        call AppendExtIntRte
        jmp do_guest_io_process.Done


do_guest_io_process.In:        
        DEBUG_RECORD    "processing IN instruction ..."
        
        ;;
        ;; ���� IN/INS
        ;;
        mov esi, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.IoPort]
        call GetIoVte
        REX.Wrxb
        test eax, eax
        jz do_guest_io_process.Done
        
        mov ecx, [eax + IO_VTE.Value]                           ; IO port ԭֵ        
        REX.Wrxb
        mov ebx, [ebx + VMB.VsbBase]                            ; VSB ����
        
        ;;
        ;; ����Ƿ����ڴ�ָ��
        ;;
        test edx, IO_FLAGS_STRING
        jnz do_guest_io_process.In.String
        
        ;;
        ;; ���� IN al/ax/eax, IoPort 
        ;;
        mov esi, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.OperandSize]
        cmp esi, IO_OPS_BYTE
        je do_guest_io_process.In.Byte
        cmp esi, IO_OPS_WORD
        je do_guest_io_process.In.Word
        
        ;;
        ;; д�� dwrod ֵ
        ;;
        REX.Wrxb
        mov [ebx + VSB.Rax], ecx
        jmp do_guest_io_process.Done
        
do_guest_io_process.In.Byte:
        ;;
        ;; д�� byte ֵ
        ;;
        mov [ebx + VSB.Rax], cl
        jmp do_guest_io_process.Done
        
do_guest_io_process.In.Word:
        ;;
        ;; д�� word ֵ
        ;;
        mov [ebx + VSB.Rax], cx
        jmp do_guest_io_process.Done
        
        
        
do_guest_io_process.In.String:
        ;;
        ;; #### ��Ϊʾ��������ʵ�ֶԴ�ָ��Ĵ��� ####
        ;; 
        jmp do_guest_io_process.Done
        
%if 0
        ;;
        ;; ���� INS ָ��
        ;;
        REX.Wrxb
        mov edi, [[ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.LinearAddress]
        
        test DWORD [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Flags], IO_FLAGS_REP
        jz do_guest_io_process.In.String.@1
        mov ecx, [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.Count]
        
do_guest_io_process.In.String.@1:

%endif


do_guest_io_process.Pf:
        mov ecx, INJECT_EXCEPTION_PF
        mov eax, 2
        test DWORD [ebp + PCB.GuestExitInfo + IO_INSTRUCTION_INFO.IoFlags], IO_FLAGS_IN
        jz do_guest_io_process.ReflectException
        mov eax, 0
        
do_guest_io_process.ReflectException:
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, eax
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, ecx

do_guest_io_process.Done:    
        pop edx    
        pop ecx
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------------------------
; set_io_bitmap_for_8259()
; input:
;       none
; output:
;       none
; ������
;       1) ���� 8259 ��ص� IO bitmap
;-----------------------------------------------------------------------
set_io_bitmap_for_8259:
        mov esi, 20h                    ;; MASTER ICW1, OCW2, OCW3
        call set_io_bitmap
        mov esi, 21h                    ;; MASTER ICW2, ICW3, ICW4, OCW1
        call set_io_bitmap              
        mov esi, 0A0h                   ;; SLAVE ICW1, OCW2, OCW3
        call set_io_bitmap
        mov esi, 0A1h                   ;; SLAVE ICW2, ICW3, ICW4, OCW1
        call set_io_bitmap        
        ret
        