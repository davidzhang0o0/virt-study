;*************************************************
;* smp64.asm                                     *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************




        


;-----------------------------------------------------
; dispatch_to_processor_sets64()
; input:
;       esi - sets of index
;       rdi - routine ���
;       rax - delivery ����
; ������
;       1) ���� IPI ��һ��CPU
;-----------------------------------------------------
dispatch_to_processor_sets64:
        push rbx         
        push rcx
        push rdx
        push r15
        mov ecx, esi
        mov edx, esi
        mov r15d, eax
        
        
        ;;
        ;; �õ�Ŀ�괦������ PCB ��
        ;;
dispatch_to_processor_sets64.@0:
        bsf esi, ecx
        jz dispatch_to_processor_sets64.@1
        
        ;;
        ;; �ô�����Ϊ busy ״̬��ȥ�� usable processor �б�
        ;;
        lock btr DWORD [fs: SDA.UsableProcessorMask], esi               ; ������Ϊ unusable ״̬
        btr ecx, esi
        
        call get_processor_pcb
        mov rbx, rax
        mov eax, STATUS_PROCESSOR_INDEX_EXCEED
        test rbx, rbx
        jz dispatch_to_processor_sets64.@1
        
        ;;
        ;; д�� Routine ��ڵ�ַ�� PCB ��
        ;;
        mov [rbx + PCB.IpiRoutinePointer], rdi       
        jmp dispatch_to_processor_sets64.@0

dispatch_to_processor_sets64.@1:                
        ;;
        ;; ���� IPI ��Ŀ�괦����
        ;;
        mov eax, [rbx + PCB.ApicId]
        shl edx, 24
        mov rsi, [gs: PCB.LapicBase]
        mov [rsi + ICR1], edx
        or r15d, IPI_VECTOR | LOGICAL
        mov DWORD [rsi + ICR0], r15d
                
dispatch_to_processor_sets64.done:        
        pop r15
        pop rdx
        pop rcx
        pop rbx        
        ret
        




        
        
;-----------------------------------------------------
; dispatch_routine64()
; input:
;       none
; output:
;       none
; ������
;       1) �������� IPI ��������
;-----------------------------------------------------        
dispatch_routine64:
        ;;
        ;; ��ȡ���ز���
        ;;
        pop QWORD [gs: PCB.RetRip]
        pop QWORD [gs: PCB.RetCs]
        pop QWORD [gs: PCB.Rflags]
        pop QWORD [gs: PCB.RetRsp]
        pop QWORD [gs: PCB.RetSs]
        
        ;;
        ;; ���� context
        ;;
        pusha64
        
        mov rbp, rsp
                
        ;;
        ;; ���� BottomHalf ���� 0 ���ж�ջ
        ;;
        push KernelSsSelector64                 ; ss
        push rbp                                ; rsp
        push 02 | FLAGS_IF                      ; rflags�����ж�
        push KernelCsSelector64                 ; cs
        push dispatch_routine64.BottomHalf      ; rip
                
        ;;
        ;; �� routine ��ڵ�ַ
        ;;
        mov rbx, [gs: PCB.IpiRoutinePointer]

        ;;
        ;; IPI routine ���أ�Ŀ�������� BottomHalf ����
        ;;
        LAPIC_EOI_COMMAND
        iret64        
        
        
        
                

  
;-----------------------------------------------------
; dispatch_routine64.BottomHalf
; ������
;       dispatch_routine ���°벿�ִ���
;-----------------------------------------------------
dispatch_routine64.BottomHalf:               
        ;;
        ;; ִ��Ŀ������
        ;;
        test rbx, rbx
        jz dispatch_routine64.BottomHalf.@1
        call rbx
        
        ;;
        ;; д�� routine ����״̬
        ;;
        mov [fs: SDA.LastStatusCode], eax
        
        ;;
        ;; ����ṩ�� Ipi routine �°벿�ִ�����ִ��
        ;;
        mov rax, [gs: PCB.IpiRoutineBottomHalf]
        test rax, rax
        jz dispatch_routine64.BottomHalf.@1
        call rax
        
dispatch_routine64.BottomHalf.@1:
        ;;
        ;; Ŀ�괦��������ɹ�������Ϊ usable ״̬
        ;;
        mov ecx, [gs: PCB.ProcessorIndex]
        lock bts DWORD [fs: SDA.UsableProcessorMask], ecx        

        ;;
        ;; ���ڲ��ź���Ч
        ;;
        SET_INTERNAL_SIGNAL
        
        ;;
        ;; �ָ� context ���ر��ж���
        ;;
        popa64                                                  ; ���ж��� context

        cli
        mov rsp, [gs: PCB.ReturnStackPointer]
        popf
        
        ;;
        ;; ����Ƿ񷵻� 0 ��
        ;;
        test DWORD [gs: PCB.RetCs], 03
        jz dispatch_routine64.BottomHalf.R0
        sti
        retf64
        
dispatch_routine64.BottomHalf.R0:
        mov rsp, [gs: PCB.RetRsp]
        sti
        jmp QWORD FAR [gs: PCB.RetRip]
        
        


;-----------------------------------------------------
; goto_entry64()
; input:
;       rsi - Ŀ���ַ
; output:
;       none
; ������
;       1) �ô�����ת��ִ����ڵ����
;-----------------------------------------------------
goto_entry64:
        push rax
        push rbp
        mov rbp, rsp
        
        add rsp, 24                                     ; ָ�� CS
        
        ;;
        ;; ��鱻�ж���Ȩ��
        ;;
        test DWORD [rsp], 03                            ; ��� CS 
        jz goto_entry64.@0
        
        ;;
        ;; ���ڷ�0������дΪ 0 ���ж�ջ
        ;;
        add rsp, 32                                     ; ָ��δѹ�뷵�ز���ǰ
        mov rax, rsp
        push KernelSsSelector64
        push rax
        push 02 | FLAGS_IF                              ; ѹ�� rflags
        push KernelCsSelector64                         ; ѹ�� cs       
        
goto_entry64.@0:        
        push QWORD [gs: PCB.IpiRoutinePointer]          ; ԭ���ص�ַ <--- Ŀ���ַ
        
        mov rax, [gs: PCB.LapicBase]
        mov DWORD [rax + EOI], 0
        mov rax, [rbp + 8]
        mov rbp, [rbp]
        iret64                                          ; ת��Ŀ���ַ


        