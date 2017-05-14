;*************************************************
;* smp.asm                                       *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************
     


;;
;; ����IPIִ�з�ʽ
;;      1) GOTO_ENTRY:                  �ô�������ת����ڵ�
;;      2) DISPATCH_TO_ROUTINE:         �ô�����ִ��һ�� routine
;;      3) FORCE_DISPATCH_TO_ROUTINE:   �ô�����ִ�� NMI handler
;;
%define GOTO_ENTRY                      FIXED_DELIVERY | IPI_ENTRY_VECTOR
%define DISPATCH_TO_ROUTINE             FIXED_DELIVERY | IPI_VECTOR
%define FORCE_DISPATCH_TO_ROUTINE       NMI_DELIVERY | 02h





;-----------------------------------------------------
; force_dispatch_to_processor()
; input:
;       esi - ������ index
;       edi - routine ���
; output:
;       eax - status code
; ������
;       1) ʹ�� NMI delivery ��ʽ���� IPI
;       2) ������Ŀ�괦������ eflags.IF ��־λ
;-----------------------------------------------------
force_dispatch_to_processor:
        mov eax, FORCE_DISPATCH_TO_ROUTINE
        jmp dispatch_to_processor.Entry



;-----------------------------------------------------
; goto_processor()
; input:
;       esi - ������ Index ��
;       edi - entry
; output:
;       eax - status code 
; ������
;       1) ת��Ŀ�괦��������ڵ�ִ��
;       2) ������� esi �ṩĿ�괦������ index ֵ����0��ʼ��
;       3) ������� edi �ṩĿ�������ڵ�ַ
;       4) �����������ȴ�ֱ�ӷ���       
;       5) ���Ը��Լ�����ִ�У�
;-----------------------------------------------------
goto_processor:
        mov eax, GOTO_ENTRY
        jmp dispatch_to_processor.Entry



;-----------------------------------------------------
; dispatch_to_processor()
; input:
;       esi - ������ Index ��
;       edi - routine ���
; output:
;       eax - status code
; ������
;       1) ��һ�� routine ���ȵ�ĳ��������ִ��
;       2) ������� esi �ṩĿ�괦������ index ֵ����0��ʼ��
;       3) ������� edi �ṩĿ�������ڵ�ַ
;       4) �����������ȴ�ֱ�ӷ���       
;       5) �����Լ����Լ���������ִ�У�
;-----------------------------------------------------
dispatch_to_processor:
        mov eax, DISPATCH_TO_ROUTINE


dispatch_to_processor.Entry:
        push ebp
        push ebx         
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif               

        mov ecx, esi                                                    ; ������ index ֵ
        mov edx, eax
        
        ;;
        ;; �õ�Ŀ�괦������ PCB ��
        ;;
        call get_processor_pcb
        REX.Wrxb
        mov ebx, eax
        
        ;;
        ;; ����Ƿ����
        ;;
        mov eax, STATUS_PROCESSOR_INDEX_EXCEED
        REX.Wrxb
        test ebx, ebx
        jz dispatch_to_processor.done
        

        ;;
        ;; �ô�����Ϊ busy ״̬��ȥ�� usable processor �б�
        ;;
        mov eax, SDA.UsableProcessorMask
        lock btr DWORD [fs: eax], ecx                                   ; ������Ϊ unusable ״̬
        
        cmp edx, FORCE_DISPATCH_TO_ROUTINE
        jne dispatch_to_processor.@0
        ;;
        ;; �����ʹ�� NMI delivery ��ʽ
        ;;
        REX.Wrxb
        mov ebp, [ebp + PCB.SdaBase]                                    ; sda base
        REX.Wrxb
        mov [ebp + SDA.NmiIpiRoutine], edi                              ; д�� SDA.NmiIpiRoutine
        lock bts DWORD [ebp + SDA.NmiIpiRequestMask], ecx               ; ���� Nmi IPI routine Maskλ
        jmp dispatch_to_processor.@1
        
dispatch_to_processor.@0:        
        ;;
        ;; д�� Routine ��ڵ�ַ�� PCB ��
        ;;
        REX.Wrxb
        mov [ebx + PCB.IpiRoutinePointer], edi


dispatch_to_processor.@1:
        
        ;;
        ;; ʹ������ID��ʽ������ IPI ��Ŀ�괦����
        ;;
        mov esi, [ebx + PCB.ApicId]                     ; ������ ID ֵ        
        SEND_IPI_TO_PROCESSOR   esi, edx
  
        mov eax, STATUS_SUCCESS
        
dispatch_to_processor.done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret




;-----------------------------------------------------
; dipatch_to_processor_with_waitting()
; input:
;       esi - ������ Index ��
;       edi - routine ���
; output:
;       eax - status code
; ������
;       1) ��һ�� routine ���ȵ�ĳ��������ִ��
;       2) ������� esi �ṩĿ�괦������ index ֵ����0��ʼ��
;       3) ������� edi �ṩĿ�������ڵ�ַ
;       4) ��������� dispatch routine ��ɺ󷵻�
;-----------------------------------------------------
dispatch_to_processor_with_waitting:
        ;;
        ;; �ڲ��ź���Ч
        ;;
        RELEASE_INTERNAL_SIGNAL
        
        ;;
        ;; ���ȵ�������
        ;;     
        call dispatch_to_processor
        
        ;;
        ;; �ȴ��ź���Ч���ȴ�Ŀ�괦����ִ�����
        ;;
        WAIT_FOR_INTERNAL_SIGNAL        
        ret



;-----------------------------------------------------
; broadcast_message_exclude_self()
; input:
;       esi - routine ���
; output:
;       none
; ������
;       1) �� NMI delivery ��ʽ�㲥 IPI
;       2) �������Լ�
;-----------------------------------------------------
broadcast_message_exclude_self:
        push ebp
        push ecx
        
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  

        xor eax, eax
        xor edi, edi
        DECv eax                                        ; eax = 0FFFFFFFFh        
        mov ecx, [ebp + SDA.ProcessorCount]             ; ����������
        shld edi, eax, cl                               ; edi = ProcessorCount Mask
        mov eax, PCB.ProcessorIndex
        mov eax, [gs: eax]                              ; ������ index
        btr edi, eax                                    ; �� self Mask λ                
        mov [ebp + SDA.NmiIpiRequestMask], edi          ; д�� NMI request Mask ֵ
        REX.Wrxb
        mov [ebp + SDA.NmiIpiRoutine], esi              ; д�� NMI IPI routine
        
        ;;
        ;; �㲥 NMI IPI message
        ;;
        BROADCASE_MESSAGE       ALL_EX_SELF | NMI_DELIVERY | 02h

        pop ecx        
        pop ebp
        ret






;-----------------------------------------------------
; get_for_signal()
; input:
;       esi - signal
; output:
;       none
; ������
;       1) ��ȡ�ź���
;       2) ������� esi �ṩ�źŵ�ַ       
;-----------------------------------------------------
get_for_signal:
        mov [fs: SDA.SignalPointer], esi
        call wait_for_signal
        ret

   
        
;-----------------------------------------------------
; wait_for_signal()
; input:
;       esi - Signal
; output:
;       none
; ������
;       1) �ȴ� signal
;-----------------------------------------------------
wait_for_signal:
        mov eax, 1
        xor edi, edi       
        ;;
        ;; ���Ի�ȡ lock
        ;;
wait_for_signal.acquire:
        lock cmpxchg [esi], edi
        je wait_for_signal.done

        ;;
        ;; ��ȡʧ�ܺ󣬼�� lock �Ƿ񿪷ţ�δ������
        ;; 1) �ǣ����ٴ�ִ�л�ȡ����������
        ;; 2) �񣬼������ϵؼ�� lock��ֱ�� lock ����
        ;;
wait_for_signal.check:        
        mov eax, [esi]
        cmp eax, 1
        je wait_for_signal.acquire
        pause
        jmp wait_for_signal.check
wait_for_signal.done:        
        ret



;-----------------------------------------------------
; get_processor_pcb()
; input:
;       esi - ������ Index ֵ
; output:
;       eax - �ô������� PCB ��ַ
; ������
;       1) �����ṩ�Ĵ�����Indexֵ����0��ʼ�����õ��ô�������Ӧ�� PCB ��
;       2) ����ʱ���� 0 ֵ
;-----------------------------------------------------
get_processor_pcb:
        push ebp
        push edx

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif        
        ;;
        ;; ����ṩ�Ĵ����� Index ֵ�Ƿ���
        ;;
        mov eax, [ebp + SDA.ProcessorCount]
        cmp esi, eax
        setb al
        movzx eax, al
        jae get_processor_pcb.done
        ;;
        ;; Ŀ�괦���� PCB base = PCB_BASE + (Index * PCB_SIZE)
        ;;
        mov eax, PCB_SIZE
        mul esi
        REX.Wrxb
        add eax, [ebp + SDA.PcbBase]
        
get_processor_pcb.done:        
        pop edx
        pop ebp
        ret
        

;-----------------------------------------------------
; get_processor_id()
; input:
;       esi - ������ Index ֵ
; output:
;       eax - local APIC ID
; ������
;       1) �����ṩ�Ĵ�����Indexֵ����0��ʼ�����õ��ô����� LAPIC ID
;       2) ����ʱ���� -1 ֵ
;-----------------------------------------------------
get_processor_id:
        call get_processor_pcb
        REX.Wrxb
        test eax, eax
        jz get_processor_id.FoundNot        
        mov eax, [eax + PCB.ApicId]
        ret
get_processor_id.FoundNot:
        mov eax, -1        
        ret
        
        
        
;-----------------------------------------------------
; dispatch_routine()
; input:
;       none
; output:
;       none
; ������
;       1) �������� IPI ��������
;-----------------------------------------------------        
dispatch_routine:
        ;;
        ;; ���汻�ж��� context
        ;;
        pusha
        
        ;;
        ;; ���� BottomHalf ���� 0 ���ж�ջ
        ;;
        push 02 | FLAGS_IF                      ; eflags�����ж�
        push KernelCsSelector32                 ; cs
        push dispatch_routine.BottomHalf        ; eip       
       
        ;;
        ;; �� routine ��ڵ�ַ
        ;;
        mov ebx, [gs: PCB.IpiRoutinePointer]
        
        ;;
        ;; IPI routine ���أ�Ŀ�������� BottomHalf ����
        ;;
        LAPIC_EOI_COMMAND                       ; ���� EOI ����
        iret                                    ; ת��ִ�� BottomHalf ����
                



;-----------------------------------------------------
; dispatch_routine.BottomHalf
; ������
;       dispatch_routine ���°벿�ִ���
;-----------------------------------------------------
dispatch_routine.BottomHalf:
        ;;
        ;; ��ǰջ�����ݣ�
        ;; 1) 8 �� GPRs
        ;; 2) ���ж��ߵķ��ز���
        ;;

%define RETURN_EIP_OFFSET               (8 * 4)

        mov ebp, esp
                
        ;;
        ;; ���ж�ջ�ṹ����Ϊ far pointer
        ;;
        mov eax, [ebp + RETURN_EIP_OFFSET]                      ; �� eip
        mov esi, [ebp + RETURN_EIP_OFFSET + 4]                  ; �� cs
        mov ecx, [ebp + RETURN_EIP_OFFSET + 8]                  ; �� eflags
        mov [ebp + RETURN_EIP_OFFSET + 8], esi                  ; cs д��ԭ eflags λ��
        mov [ebp + RETURN_EIP_OFFSET + 4], eax                  ; eip д��ԭ cs λ��
        mov [ebp + RETURN_EIP_OFFSET], ecx                      ; eflags д��ԭ eip λ��
        
        ;;
        ;; ִ��Ŀ������
        ;;
        test ebx, ebx
        jz dispatch_routine.BottomHalf.@1
        call ebx
        
        ;;
        ;; д��״ֵ̬
        ;;
        mov [fs: SDA.LastStatusCode], eax
         
        ;;
        ;; ����ṩ�� IPI routine �°벿�ִ�����ִ��
        ;;
        mov eax, [gs: PCB.IpiRoutineBottomHalf]
        test eax, eax
        jz dispatch_routine.BottomHalf.@1
        call eax
        
dispatch_routine.BottomHalf.@1:
        ;;
        ;; Ŀ�괦��������ɹ�������Ϊ usable ״̬
        ;;
        mov eax, [gs: PCB.ProcessorIndex]
        lock bts DWORD [fs: SDA.UsableProcessorMask], eax

        ;;
        ;; ���ڲ��ź���Ч
        ;;        
        SET_INTERNAL_SIGNAL
     
        
%undef RETURN_EIP_OFFSET        

        ;;
        ;; �ָ� context ���ر��ж���
        ;;
        popa                                                    ; ���ж��� context
        popf                                                    ; eflags
        retf                                                    ; ���ر��ж���
        
                


;-----------------------------------------------------
; goto_entry()
; input:
;       none
; output:
;       none
; ������
;       1) ǿ���ô�����������ڵ����
;       2) ע�⣬���ַ�ʽ���ܷ��أ�
;-----------------------------------------------------
goto_entry:
        push eax
        push ebp
        mov ebp, esp
        
        add esp, 12                                             ; ָ�� CS
        
        ;;
        ;; ��鱻�ж���Ȩ��
        ;;
        test DWORD [esp], 03                                    ; ��� cs
        jz goto_entry.@0
        
        ;;
        ;; ���ڷ�0������дΪ 0 ���ж�ջ
        ;;
        add esp, 16                                             ; ָ��δѹ�뷵�ز���ǰ
        push 02 | FLAGS_IF                                      ; ѹ�� EFLAGS
        push KernelCsSelector32                                 ; ѹ�� CS
        
goto_entry.@0:        
        ;;
        ;; д��Ŀ���ַ
        ;;
        push DWORD [gs: PCB.IpiRoutinePointer]                  ; ԭ���ص�ַ <--- Ŀ���ַ

        ;;
        ;; д lapic EOI ����
        ;;        
        mov eax, [gs: PCB.LapicBase]
        mov DWORD [eax + EOI], 0
        mov eax, [ebp + 4]
        mov ebp, [ebp]
        iret                                                    ; ת��Ŀ���ַ




;-----------------------------------------------------
; do_schedule()
; input:
;       esi -������ index
; output:
;       none
; ������
;       1) ���¹��ܼ������е�ǰ�������л�
;-----------------------------------------------------
do_schedule:
        push esi
        push edi
        push ecx

        ;;
        ;; �л���ǰ������
        ;;
        mov edi, switch_to_processor
        call force_dispatch_to_processor
        
        pop ecx
        pop edi
        pop esi
        ret
        


;-----------------------------------------------------
; switch_to_processor()
; input:
;       none
; output:
;       none
; ������
;       1) �л���ǰ������
;-----------------------------------------------------
switch_to_processor:
        push ebp
        push ecx
        push ebx

        
%ifdef  __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        ;;
        ;; �л����㴦����
        ;;
        mov ecx, [ebp + PCB.ProcessorIndex]
        mov eax, SDA.InFocus
        xchg [fs: eax], ecx        

        ;;
        ;; ����Ƿ��� guese ����������Ҫ�л�
        ;;
        mov esi, [ebp + PCB.ProcessorStatus]
        test esi, CPU_STATUS_GUEST_EXIST
        jz switch_to_processor.host
        
        
        ;;
        ;; ��鵱ǰ�������Ƿ��Ѿ�ӵ�н��� ?
        ;; 1) �ǣ��� XOR CPU_STATUS_GUEST ��־λ
        ;; 2) ������ CPU_STATUS_GUEST ��־λ
        ;;
        mov edi, esi
        and esi, ~CPU_STATUS_GUEST_FOCUS
        xor edi, CPU_STATUS_GUEST_FOCUS
        cmp ecx, [ebp + PCB.ProcessorIndex]
        cmove esi, edi
        mov [ebp + PCB.ProcessorStatus], esi
        
        ;;
        ;; ��� host/guest ����
        ;;
        test esi, CPU_STATUS_GUEST_FOCUS
        jnz switch_to_processor.Guest


switch_to_processor.host:
        ;;
        ;; �л� lcoal keyboard buffer
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.LsbBase]                    ; ebx = LSB
        REX.Wrxb
        mov ebp, [ebp + PCB.SdaBase]                    ; ebp = SDA        
        REX.Wrxb
        mov eax, [ebx + LSB.LocalKeyBufferHead]
        REX.Wrxb
        mov [ebp + SDA.KeyBufferHead], eax              ; SDA.KeyBufferHead = LSB.LocalKeyBufferHead
        REX.Wrxb
        lea eax, [ebx + LSB.LocalKeyBufferPtr]
        REX.Wrxb
        mov [ebp + SDA.KeyBufferPtrPointer], eax        ; KeyBufferPtrPointer = &LocalKeyBufferPtr
        mov eax, [ebx + LSB.LocalKeyBufferSize]
        mov [ebp + SDA.KeyBufferLength], eax            ; KeyBufferLength = LocalKeyBufferSize
        
        ;;
        ;; �л���Ļ
        ;;        
        call flush_local_video_buffer                   ; ˢ��Ϊ��ǰ������ local video buffer                

        jmp switch_to_processor.Done


switch_to_processor.Guest:
        ;;
        ;; �л� VM keyboard buffer
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebx + VMB.VsbBase]
        REX.Wrxb
        mov ebp, [ebp + PCB.SdaBase]                    ; ebp = SDA       
        REX.Wrxb
        mov eax, [ebx + VSB.VmKeyBufferHead]
        REX.Wrxb
        mov [ebp + SDA.KeyBufferHead], eax              ; SDA.KeyBufferHead = VSB.VmKeyBufferHead
        REX.Wrxb
        lea eax, [ebx + VSB.VmKeyBufferPtr]
        REX.Wrxb
        mov [ebp + SDA.KeyBufferPtrPointer], eax        ; SDA.KeyBufferPtrPointer = &VmKeyBufferPtr
        mov eax, [ebx + VSB.VmKeyBufferSize]
        mov [ebp + SDA.KeyBufferLength], eax            ; SDA.KeyBufferLength = VmKeyBufferSize
        
        ;;
        ;; �л���Ļ
        ;;        
        call flush_vm_video_buffer                      ; ˢ��Ϊ��ǰ������ vm video buffer  

switch_to_processor.Done:        
        pop ebx
        pop ecx
        pop ebp
        ret
