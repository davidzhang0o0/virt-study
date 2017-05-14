;*************************************************
;* services64.asm                                *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************



;-----------------------------------------------------
; EXCEPTION_REPORT64()
; input:
;       none
; output:
;       none
; ������
;       1) ��ӡ context ��Ϣ
;-----------------------------------------------------
%macro DO_EXCEPTION_REPORT64 0
        ;;
        ;; ��ǰջ���� 16 �� GPRs
        ;; rbp ָ��ջ��
        ;;
        mov rsi, Services.ProcessorIdMsg
        call puts
        mov esi, [gs: PCB.ProcessorIndex]
        call print_dword_decimal
        mov esi, ':'
        call putc
        bsf ecx, [gs: PCB.ExceptionBitMask]
        btr [gs: PCB.ExceptionBitMask], ecx
        lea rsi, [Services.ExcetpionMsgTable + ecx * 4]
        call puts
        mov rsi, Services.ExceptionReportMsg
        call puts
        mov rsi, Services.CsIpMsg
        call puts
        mov esi, [rbp + 8 * 16 + 8]                     ; CS
        call print_word_value
        mov esi, ':'
        call putc
        mov rsi, [rbp + 8 * 16]                         ; RIP
        call print_qword_value64
        mov esi, ','
        call putc
        mov rsi, Services.ErrorCodeMsg
        call puts
        mov esi, [gs: PCB.ErrorCode]                    ; Error code
        call print_word_value
        call println
        mov rsi, Services.RegisterContextMsg 
        call puts
        
        ;;
        ;; ��ӡ�Ĵ���ֵ
        ;;
        mov rsi, Services.EflagsMsg
        call puts
        mov esi, [rbp + 8 * 16 + 16]                    ; Rflags
        call print_dword_value
        
        ;;
        ;; �Ƿ����� #PF �쳣
        ;;
        cmp ecx, PF_VECTOR
        jne %%0
        mov esi, 08
        call print_space           
        mov esi, Services.Cr2Msg
        call puts
        mov rsi, cr2 
        call print_qword_value64
%%0:              
        call println

        
        mov ecx, 15
        mov rbx, Services64.RegisterMsg
        
%%1:        
        mov rsi, rbx
        call puts
        mov rsi, [rbp + rcx * 8]
        call print_qword_value64
        call print_tab
        add rbx, REG_MSG_LENGTH
        mov rsi, rbx
        call puts
        mov rsi, [rbp + rcx * 8 - 8]
        call print_qword_value64
        call println
        add rbx, REG_MSG_LENGTH
        sub rcx, 2
        jns %%1
        call println
%endmacro
        
        
                
                
;-----------------------------------------------------
; error_code_default_handler64()
; ������
;       1) ��Ҫѹ��������ȱʡ handler
;-----------------------------------------------------
error_code_default_handler64:
        ;;
        ;; ȡ��������
        ;;
        pop QWORD [gs: PCB.ErrorCode]


;-----------------------------------------------------
; exception_default_handler()
; input:
;       none
; output:
;       none
; ������
;       1) ȱʡ���쳣��������
;       2) ����ȱʡ�쳣�����°벿����
;       3) �°벿�����ж�
;-----------------------------------------------------
exception_default_handler64:
        pusha64
        mov rbp, rsp
exception_default_handler64.@0:                
        ;;
        ;; ��ӡ context ��Ϣ
        ;;
        DO_EXCEPTION_REPORT64                           ; ��ӡ�쳣��Ϣ               
        
        ;;
        ;; �ȴ� <ESC> ������
        ;;
        call wait_esc_for_reset
       
        popa64
        iret64
        
        
        

;-----------------------------------------------------
; nmi_handler64()
; input:
;       none
; output:
;       none
; ������
;       1) ��Ӳ����IPI����
;-----------------------------------------------------
nmi_handler64:
        pusha64        
        mov rbp, rsp
        ;; 
        ;; ��ȡ������index���ж�NMI handler����ʽ
        ;; 1) ��������index ��Ӧ�� RequestMask λΪ 1ʱ��ִ�� IPI routine
        ;; 2) RequestMask Ϊ 0ʱ��ִ��ȱʡ NMI ����
        ;;
        mov ecx, [gs: PCB.ProcessorIndex]
        lock btr DWORD [fs: SDA.NmiIpiRequestMask], ecx
        jnc exception02                                 ; ת��ִ��ȱʡ NMI ����
        

        ;;
        ;; ������� IPI routine
        ;;
        mov rax, [fs: SDA.NmiIpiRoutine]
        call rax

        ;;
        ;; ���ڲ��ź���Ч
        ;;        
        SET_INTERNAL_SIGNAL

        popa64
        iret64
        
        
        
        

;-----------------------------------------------------
; install_kernel_interrupt_handler64()
; input:
;       rsi - vector
;       rdi - interrupt handler
; output:
;       none
; ������
;       1) ��װ kernel ʹ�õ��ж�����
;-----------------------------------------------------
install_kernel_interrupt_handler64:
        push rdx
        push rcx
        mov rcx, rdi
        mov rdx, rdi
        shr rdx, 32                                                     ; offset[63:32]
        mov rax, 00008E0000000000h | (KernelCsSelector64 << 16)         ; Interrupt-gate, DPL=0
        and ecx, 0FFFFh                                                 ; offset[15:0]
        or rax, rcx
        and edi, 0FFFF0000h                                             ; offset[31:16]
        shl rdi, 32
        or rax, rdi
        call write_idt_descriptor64
        pop rcx
        pop rdx
        ret




;-----------------------------------------------------
; install_user_interrupt_handler64()
; input:
;       rsi - vector
;       rdi - interrupt handler
; output:
;       none
; ������
;       1) ��װ user ʹ�õ��ж�����
;-----------------------------------------------------
install_user_interrupt_handler64:
        push rdx
        push rcx
        mov rcx, rdi
        mov rdx, rdi
        shr rdx, 32                                                     ; offset[63:32]
        mov rax, 0000EE0000000000h | (KernelCsSelector64 << 16)         ; Interrupt-gate, DPL=3
        and ecx, 0FFFFh                                                 ; offset[15:0]
        or rax, rcx
        and edi, 0FFFF0000h                                             ; offset[31:16]
        shl rdi, 32
        or rax, rdi
        call write_idt_descriptor64
        pop rcx
        pop rdx
        ret
        



;-----------------------------------------------------
; setup_sysenter64()
; input:
;       none
; output:
;       none
; ������
;       ���� sysenter ָ��ʹ�û���
;-----------------------------------------------------
setup_sysenter64:
        push rdx
        push rcx
        
        xor edx, edx
        mov eax, KernelCsSelector64
        mov [fs: SDA.SysenterCsSelector], ax
        mov ecx, IA32_SYSENTER_CS
        wrmsr
        
        mov rax, [gs: PCB.FastSystemServiceStack]
        test rax, rax
        jnz setup_sysenter64.next
        
        ;;
        ;; ����һ�� kernel stack �Թ� SYSENTER ʹ��
        ;;        
        call get_kernel_stack_pointer               
        mov [gs: PCB.FastSystemServiceStack], rax               ; �������ϵͳ�������� stack        
        
setup_sysenter64.next:        
        shld rdx, rax, 32
        mov ecx, IA32_SYSENTER_ESP
        wrmsr
        
        mov rax, fast_sys_service_routine
        shld rdx, rax, 32
        mov ecx, IA32_SYSENTER_EIP
        wrmsr
        
        pop rcx
        pop rdx
        ret   
        
        

;-----------------------------------------------------
; timer_8259_handler64()
; input:
;       none
; output:
;       none
; ������
;       1) PIC 8259 �� IRQ0 �жϷ�������
;       2) ����ʵ���� 32 λ�� pic8159a.asm ģ����
;-----------------------------------------------------
timer_8259_handler64:
        jmp timer_8259_handler
        




;-----------------------------------------------------
; lapic_timer_handler64:
; input:
;       none
; output:
;       none
; ����:
;       1) Local APIC �� timer ��������
;-----------------------------------------------------
lapic_timer_handler64:       
        pusha64
     
        mov rbx, [gs: PCB.LsbBase]
        cmp DWORD [rbx + LSB.LapicTimerRequestMask], LAPIC_TIMER_PERIODIC
        jne lapic_timer_handler.next
        
        
        mov eax, [rbx + LSB.Second]
        inc eax                                                 ; ��������
        cmp eax, 60
        jb lapic_timer_handler64.@1
        ;;
        ;; ������� 59 �룬�����ӷ�����
        ;;
        mov ecx, [rbx + LSB.Minute]
        inc ecx                                                 ; ���ӷ�����
        cmp ecx, 60
        jb lapic_timer_handler64.@0
        ;;
        ;; ������� 59 �֣�������Сʱ��
        ;;
        xor ecx, ecx
        inc DWORD [rbx + LSB.Hour]
        
lapic_timer_handler64.@0:        
        xor eax, eax
        mov [rbx + LSB.Minute], ecx
        
lapic_timer_handler64.@1:
        mov [rbx + LSB.Second], eax


lapic_timer_handler.next:
        inc DWORD [rbx + LSB.LapicTimerCount]

        ;;
        ;; ����лص���������ִ��
        ;;        
        mov rsi, [rbx + LSB.LapicTimerRoutine]
        test rsi, rsi
        jz lapic_timer_handler64.done
        
        call rsi
        
lapic_timer_handler64.done:  
        ;;
        ;; EOI ����
        ;;
        mov rax, [gs: PCB.LapicBase]
        mov DWORD [rax + EOI], 0
        
        popa64
        iret64
            




                

;-----------------------------------------------------
; local_default_handler64()
;-----------------------------------------------------
local_interrupt_default_handler64:
        push rbx
        mov rbx, [gs: PCB.LapicBase]
        mov DWORD [rbx + EOI], 0
        pop rbx
        iret64


