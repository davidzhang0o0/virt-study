;*************************************************
;* service.asm                                   *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************



;-----------------------------------------------------
; DO_EXCEPTION_REPORT
; input:
;       none
; output:
;       none
; ������
;       1) ʵ�ִ�ӡ�쳣��Ϣ
;-----------------------------------------------------
%macro DO_EXCEPTION_REPORT 0
        mov esi, Services.ProcessorIdMsg
        call puts
        mov esi, [gs: PCB.ProcessorIndex]
        call print_dword_decimal
        mov esi, ':'
        call putc
        bsf ecx, [gs: PCB.ExceptionBitMask]
        btr [gs: PCB.ExceptionBitMask], ecx
        lea esi, [Services.ExcetpionMsgTable + ecx * 4]
        call puts        
        mov esi, Services.ExceptionReportMsg
        call puts
        mov esi, Services.CsIpMsg
        call puts
        mov esi, [ebp + 8 * 4 + 4]                      ; CS ֵ
        call print_word_value
        mov esi, ':'
        call putc
        mov esi, [ebp + 8 * 4]                          ; EIP 
        call print_dword_value
        mov esi, ','
        call putc
        mov esi, Services.ErrorCodeMsg
        call puts
        mov esi, [gs: PCB.ErrorCode]                    ; error code
        call print_word_value
        call println
        mov esi, Services.RegisterContextMsg 
        call puts
        
        ;;
        ;; ��ӡ�Ĵ���ֵ
        ;;
        mov esi, Services.EflagsMsg
        call puts
        mov esi, [ebp + 8 * 4 + 8]                      ; eflags
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
        mov esi, cr2 
        call print_dword_value
%%0:              
        call println
        
        
        
        
        mov ecx, 7
        mov ebx, Services.RegisterMsg
%%1:        
        mov esi, ebx
        call puts
        mov esi, [ebp + ecx * 4]
        call print_dword_value
        call println
        add ebx, REG_MSG_LENGTH
        dec ecx
        jns %%1
        
        call println       
        
%endmacro






;-----------------------------------------------------
; MASK_EXCEPTION_BITMAP
; input:
;       none
; output:
;       none
; ������
;       1) ʵ�� 64/32 �µ����� exception bitmap
;       2) ������� bits 32 �±���
;-----------------------------------------------------
%macro MASK_EXCEPTION_BITMAP    1
        ;;
        ;; ʵ��ָ�� or DWORD [gs: PCB.ExceptionBitMask], X
        ;;
        ;;
%if %1 > 0FFh
        %ifdef __STAGE1
                DB 65h, 81h, 0Dh
                DD PCB.ExceptionBitMask
                DD %1
                
        %elifdef __X64
                DB 65h, 81h, 0Ch, 25h
                DD PCB.ExceptionBitMask
                DD %1
        %else
                DB 65h, 81h, 0Dh
                DD PCB.ExceptionBitMask
                DD %1
        %endif
        
%else

        %ifdef __STAGE1
                DB 65h, 83h, 0Dh
                DD PCB.ExceptionBitMask
                DB %1         
        %elifdef __X64
                DB 65h, 83h, 0Ch, 25h
                DD PCB.ExceptionBitMask
                DB %1
        %else
                DB 65h, 83h, 0Dh
                DD PCB.ExceptionBitMask
                DB %1                
        %endif     
        
%endif
%endmacro




;;
;; ���� 64/32 λ�µ��쳣��������
;;

ExceptionHandlerTable:
        DQ     exception00
        DQ     exception01
        DQ     nmi_handler
        DQ     exception03
        DQ     exception04
        DQ     exception05
        DQ     exception06
        DQ     exception07
        DQ     exception08
        DQ     exception09
        DQ     exception10
        DQ     exception11
        DQ     exception12
        DQ     exception13
        DQ     exception14
        DQ     exception15
        DQ     exception16
        DQ     exception17
        DQ     exception18
        DQ     exception19
        
        
        
        
        
;-----------------------------------------------------
; exception00()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 0 ��������
;-----------------------------------------------------
exception00:
        MASK_EXCEPTION_BITMAP   (1 << 0)
        jmp exception_default_handler




;-----------------------------------------------------
; exception01()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 1 ��������
;-----------------------------------------------------        
exception01:
        MASK_EXCEPTION_BITMAP   (1 << 1)
        jmp exception_default_handler


;-----------------------------------------------------
; exception02()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 2 ��������
;-----------------------------------------------------        
exception02:
        MASK_EXCEPTION_BITMAP   (1 << 2)
        jmp exception_default_handler.@0



;-----------------------------------------------------
; nmi_handler32()
; input:
;       none
; output:
;       none
; ������
;       1) ��Ӳ����IPI����
;-----------------------------------------------------
nmi_handler32:
        pusha        
        
        ;;
        ;; ��ȡ������index���ж�NMI handler����ʽ
        ;; 1) ��������index ��Ӧ�� RequestMask λΪ 1ʱ��ִ�� IPI routine
        ;; 2) RequestMask Ϊ 0ʱ��ִ��ȱʡ���쳣��������
        ;;        
        mov ecx, [gs: PCB.ProcessorIndex]
        lock btr DWORD [fs: SDA.NmiIpiRequestMask], ecx
        jnc exception02                                 ; ת��ȱʡ�쳣��������

        ;;
        ;; ������� IPI routine
        ;;
        mov eax, [fs: SDA.NmiIpiRoutine]
        call eax

        ;;
        ;; ���ڲ��ź���Ч
        ;;        
        SET_INTERNAL_SIGNAL        
        
        popa
        iret
        
        
        
                
        
;-----------------------------------------------------
; exception03()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 3 ��������
;-----------------------------------------------------         
exception03:
        MASK_EXCEPTION_BITMAP   (1 << 3)
        jmp exception_default_handler



;-----------------------------------------------------
; exception04()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 4 ��������
;-----------------------------------------------------         
exception04:
        MASK_EXCEPTION_BITMAP   (1 << 4)
        jmp exception_default_handler



;-----------------------------------------------------
; exception05()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 5 ��������
;----------------------------------------------------- 
exception05:
        MASK_EXCEPTION_BITMAP   (1 << 5)
        jmp exception_default_handler



;-----------------------------------------------------
; exception06()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 6 ��������
;----------------------------------------------------- 
exception06:
        DEBUG_RECORD         "[exception]: enter #UD handler !"
        
        MASK_EXCEPTION_BITMAP   (1 << 6)
        jmp exception_default_handler



;-----------------------------------------------------
; exception07()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 7 ��������
;----------------------------------------------------- 
exception07:
        MASK_EXCEPTION_BITMAP   (1 << 7)
        jmp exception_default_handler




;-----------------------------------------------------
; exception08()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 8 ��������
;----------------------------------------------------- 
exception08:
        MASK_EXCEPTION_BITMAP   (1 << 8)
        jmp error_code_default_handler




;-----------------------------------------------------
; exception09()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 9 ��������
;----------------------------------------------------- 
exception09:
        MASK_EXCEPTION_BITMAP   (1 << 9)
        jmp exception_default_handler



;-----------------------------------------------------
; exception10()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 10 ��������
;----------------------------------------------------- 
exception10:
        MASK_EXCEPTION_BITMAP   (1 << 10)
        jmp error_code_default_handler


;-----------------------------------------------------
; exception11()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 11 ��������
;----------------------------------------------------- 
exception11:
        MASK_EXCEPTION_BITMAP   (1 << 11)
        jmp error_code_default_handler



;-----------------------------------------------------
; exception12()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 12 ��������
;----------------------------------------------------- 
exception12:
        MASK_EXCEPTION_BITMAP   (1 << 12)
        jmp error_code_default_handler



;-----------------------------------------------------
; exception13()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 13 ��������
;-----------------------------------------------------         
exception13:
        DEBUG_RECORD         "[exception]: enter #GP handler !"
        
        MASK_EXCEPTION_BITMAP   (1 << 13)
        jmp error_code_default_handler



;-----------------------------------------------------
; exception14()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 14 ��������
;-----------------------------------------------------         
exception14:
        DEBUG_RECORD         "[exception]: enter #PF handler !"

        MASK_EXCEPTION_BITMAP   (1 << 14)
        jmp error_code_default_handler



;-----------------------------------------------------
; exception15()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 15 ��������
;----------------------------------------------------- 
exception15:
        MASK_EXCEPTION_BITMAP   (1 << 15)
        jmp exception_default_handler
                                                                           


;-----------------------------------------------------
; exception16()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 16 ��������
;----------------------------------------------------- 
exception16:
        MASK_EXCEPTION_BITMAP   (1 << 16)
        jmp exception_default_handler



;-----------------------------------------------------
; exception17()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 17 ��������
;----------------------------------------------------- 
exception17:
        MASK_EXCEPTION_BITMAP   (1 << 17)
        jmp error_code_default_handler
             



;-----------------------------------------------------
; exception18()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 18 ��������
;-----------------------------------------------------                         
exception18:
        MASK_EXCEPTION_BITMAP   (1 << 18)
        jmp exception_default_handler

        
        
;-----------------------------------------------------
; exception19()
; input: 
;       none
; output:
;       none
; ������
;       1) vector 19 ��������
;----------------------------------------------------- 
exception19:
        MASK_EXCEPTION_BITMAP   (1 << 19)
        jmp exception_default_handler







;-----------------------------------------------------
; error_code_default_handler()
; ������
;       1) ��Ҫѹ��������ȱʡ handler
;-----------------------------------------------------
error_code_default_handler32:
        ;;
        ;; pop ��������
        ;;
        pop DWORD [gs: PCB.ErrorCode]


;-----------------------------------------------------
; exception_default_handler()
; input:
;       none
; output:
;       none
; ������
;       1)ȱʡ���쳣��������
;       2)����ȱʡ���쳣��������°벿��
;       3)���°벿���У������ж�
;-----------------------------------------------------
exception_default_handler32:
        pusha
        mov ebp, esp
exception_default_handler32.@0:
        ;;
        ;; ��ӡ�쳣 context ��Ϣ��ebp ָ��ǰջ��
        ;;
        DO_EXCEPTION_REPORT
        
        ;;
        ;; �ȴ� <ESC> ������
        ;;
        call wait_esc_for_reset
        
        popa
        iret




        


;-----------------------------------------------------------------------
; install_kernel_interrupt_handler()
; input:
;       esi - vector
;       edi - handler
; ����:
;       �� IDT ���������������Թ� kernel Ȩ��ʹ��
;-----------------------------------------------------------------------
install_kernel_interrupt_handler32:
        push ebx
        push edx
        mov edx, edi
        movzx eax, WORD [fs: SDA.KernelCsSelector]      ; CS selector
        shl eax, 16
        and edi, 0FFFFh
        or eax, edi
        and edx, 0FFFF0000h
        or edx, 8E00h                                   ; 32-bit Interrupt-gate
        call set_idt_descriptor                         ; д�� IDT ��
        pop edx
        pop ebx
        ret




;-----------------------------------------------------------------------
; install_user_interrupt_handler32()
; input:
;       esi - vector
;       edi - handler
; ����:
;       �� IDT ���������������Թ� user �������
;-----------------------------------------------------------------------
install_user_interrupt_handler32:     
        push ebx
        push edx
        mov edx, edi
        movzx eax, WORD [fs: SDA.KernelCsSelector]      ; CS selector
        shl eax, 16
        and edi, 0FFFFh
        or eax, edi
        and edx, 0FFFF0000h
        or edx, 0EE00h                                  ; 32-bit Interrupt-gate, DPL=3
        call set_idt_descriptor                         ; д�� IDT ��
        pop edx
        pop ebx   
        ret
        



;-----------------------------------------------------
; setup_sysenter32()
; input:
;       none
; output:
;       none
; ������
;       ���� sysenter ָ��ʹ�û���
;-----------------------------------------------------
setup_sysenter32:
        push edx
        push ecx
        xor edx, edx
        movzx eax, WORD [fs: SDA.SysenterCsSelector]
        mov ecx, IA32_SYSENTER_CS
        wrmsr
        
        mov eax, [gs: PCB.FastSystemServiceStack]
        test eax, eax
        jnz setup_sysenter.next
        
        ;;
        ;; ����һ�� kernel stack �Թ� SYSENTER ʹ��
        ;;        
        call get_kernel_stack_pointer               
        mov [gs: PCB.FastSystemServiceStack], eax               ; �������ϵͳ�������� stack        
        
setup_sysenter.next:        
        mov ecx, IA32_SYSENTER_ESP
        wrmsr
        
        mov eax, fast_sys_service_routine
        xor edx, edx
        mov ecx, IA32_SYSENTER_EIP
        wrmsr
        pop ecx
        pop edx
        ret   



;-----------------------------------------------------
; sys_service_enter()
; input:
;       eax - ϵͳ�������̺�
; ����:
;       ִ�� SYSENTER ָ���������ϵͳ��������
;-----------------------------------------------------
sys_service_enter:
        push ecx
        push edx
        REX.Wrxb
        mov ecx, esp                    ; ecx ���� stack
        mov edx, return_address         ; edx ���淵�ص�ַ
        sysenter
return_address:
        pop edx
        pop ecx        
        ret


;------------------------------------------------------------------
; fast_sys_service_routine()
; input:
;       eax - ϵͳ�������̺�
; ������
;       ʹ���� sysenter/sysexit �汾��ϵͳ��������
;-------------------------------------------------------------------
fast_sys_service_routine:
        push ecx
        push edx
        REX.Wrxb
        mov eax, [fs: SRT.Entry + eax * 8]
        call eax
        pop edx
        pop ecx
        REX.Wrxb
        sysexit


;------------------------------------------------------------------
; sys_service_routine()
; input:
;       eax - ϵͳ�������̺�
; ������
;       ʹ�����жϵ��� ����ϵͳ��������
;-------------------------------------------------------------------
sys_service_routine:
        push ebp

%ifdef __X64
        LoadFsBaseToRbp
        REX.Wrxb
%else
        mov ebp, [fs: SDA.Base]
%endif        
        mov eax, [ebp + SRT.Entry + eax * 8]
        call eax
        
        pop ebp
        REX.Wrxb
        iret



;--------------------------------------------
; append_system_service_routine()
; input:
;       esi - routine
; output:
;       eax - routine number
;--------------------------------------------
append_system_service_routine:
        push ebp

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif 
        REX.Wrxb
        mov eax, [ebp + SRT.Index]
        REX.Wrxb
        mov [eax], esi
        add DWORD [ebp + SRT.Index], 8        
        pop ebp
        ret





;--------------------------------------------
; install_system_service_routine()
; input:
;       esi - sys_service number
;       edi - system service routine
; output:
;       eax - routine number
;--------------------------------------------
install_system_service_routine:
        push ebp

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif 

        and esi, 3Fh
        REX.Wrxb
        mov [ebp + SRT.Entry + esi * 8], edi
        
        pop ebp
        ret


;------------------------------------------------------------------
; init_sys_service_call()
; input:
;       none
; output:
;       none
; ������
;       1) ��ʼ��ϵͳ���ñ�
;------------------------------------------------------------------
init_sys_service_call:
        mov esi, READ_SDA_DATA
        mov edi, read_sda_data
        call install_system_service_routine
        mov esi, READ_PCB_DATA
        mov edi, read_pcb_data
        call install_system_service_routine
        mov esi, WRITE_SDA_DATA
        mov edi, write_sda_data
        call install_system_service_routine        
        mov esi, WRITE_PCB_DATA
        mov edi, write_pcb_data
        call install_system_service_routine    
        mov esi, READ_SYS_DATA
        mov edi, read_sys_data
        call install_system_service_routine       
        mov esi, WRITE_SYS_DATA
        mov edi, write_sys_data
        call install_system_service_routine 
        ret
       



;------------------------------------------------------------------
; read_sda_data()
; input:
;       esi - offset of SDA
; output:
;       eax - data
; ������
;       1) ��ȡ SDA ����
;------------------------------------------------------------------
read_sda_data:
        push ebp
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  
        jmp read_data_start

;------------------------------------------------------------------
; read_pcb_data()
; input:
;       esi - offset of PCB
; output:
;       eax - data
; ������
;       1) ��ȡ PCB ����
;------------------------------------------------------------------
read_pcb_data:
        push ebp       
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        jmp read_data_start


;------------------------------------------------------------------
; write_sda_data()
; input:
;       esi - offset of SDA
;       edi - data
; output:
;       none
; ������
;       1) д SDA ����
;------------------------------------------------------------------
write_sda_data:
        push ebp
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif 
        jmp write_data_start
        

;------------------------------------------------------------------
; write_pcb_data()
; input:
;       esi - offset of PCB
;       edi - data
; output:
;       none
; ������
;       1) д PCB ����
;------------------------------------------------------------------
write_pcb_data:
        push ebp
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 
        jmp write_data_start
        



read_data_start:
        mov eax, esi
        and esi, 0FFFFh
        test eax, 10000000h
        jnz read_data_byte
        test eax, 20000000h
        jnz read_data_word
        test eax, 40000000h
        jnz read_data_dword
        
%ifdef __X64        
        test eax, 80000000h
        jnz read_data_qword
%endif        

        REX.Wrxb
        mov eax, [ebp + esi]
        jmp read_write_data.done


write_data_start:
        REX.Wrxb
        mov eax, edi
        mov edi, esi
        and esi, 0FFFFh
        test edi, 10000000h
        jnz write_data_byte
        test edi, 20000000h
        jnz write_data_word
        test edi, 40000000h
        jnz write_data_dword
        
%ifdef __X64        
        test edi, 80000000h
        jnz write_data_qword
%endif        

        REX.Wrxb
        mov [ebp + esi], eax
        jmp read_write_data.done
        
        


read_data_byte:
        movzx eax, BYTE [ebp + esi]
        jmp read_write_data.done

read_data_word:
        movzx eax, WORD [ebp + esi]
        jmp read_write_data.done 

read_data_qword:
        REX.Wrxb
        
read_data_dword:
        mov eax, [ebp + esi]
        jmp read_write_data.done

write_data_byte:
        mov [ebp + esi], al
        jmp read_write_data.done

write_data_word:
        mov [ebp + esi], ax
        jmp read_write_data.done 

write_data_qword:
        REX.Wrxb
        
write_data_dword:
        mov [ebp + esi], eax
        jmp read_write_data.done

read_write_data.done:
        pop ebp
        ret     
        


;------------------------------------------------------------------
; read_sys_data()
; input:
;       esi - address
; output:
;       eax - data
; ������
;       1) ��ȡϵͳ��������
;------------------------------------------------------------------
read_sys_data:
        REX.Wrxb
        mov eax, [esi]
        ret
        
;------------------------------------------------------------------
; write_sys_data()
; input:
;       esi - address
;       edi - data
; output:
;       none
; ������
;       1) дϵͳ��������
;------------------------------------------------------------------
write_sys_data:
        REX.Wrxb
        mov [esi], edi
        ret
        
