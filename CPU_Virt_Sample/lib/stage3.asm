;*************************************************
; stage3.asm                                     *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************



;;
;; stage3 ˵����
;; 1) ǰ�벿���� legacy 32 λ����ִ��
;; 2) ��벿���� 64-bit ������ִ��
;;

        bits 32

;-----------------------------------------------------------------------
; alloc_stage3_kernel_stack_4k_base()
; input:
;       none
; output:
;       edx:eax - 64 λ�� 4K stack base�������ַ�� 
; ������
;       1)����һ��4Kҳ���С�� kernel stack base�Ŀ���ֵ         
;       2)�����µ�ǰ kernel stack base ��¼
;-----------------------------------------------------------------------
alloc_stage3_kernel_stack_4k_base:
        mov eax, 4096
        xor edx, edx                                            ; ���� 4K ��С
        mov esi, SDA_PHYSICAL_BASE + SDA.KernelStackBase        ; �� KernelStackBase �������
        call locked_xadd64                                      ; edx:eax ���� kernel base
        ret
        
        
        

        
;---------------------------------------------------------------
; init_longmode_basic_page32()
; input:
;       none
; output:
;       none
; ������
;       1) �ڽ��� long-mode ǰ����������ĳ�ʼ��
;       2) �� legacy ��ʹ��
;---------------------------------------------------------------
init_longmode_basic_page32:
        ;;
        ;; ����ӳ�� PPT ������2M�������� PXT ������4K��
        ;;
        call map_longmode_page_transition_table32
        
        ;;
        ;; ӳ�������������
        ;; 1) compatibility ģʽ�µ� LONG_SEGMENT ����
        ;; 2) setup ģ������
        ;; 3) 64-bit ģʽ�µ� LONG_SEGMENT ����
        ;;
        
        ;;
        ;; 1) ӳ�� compatibility ģʽ�£���ʼ��ʱ���� LONG_SEGMENT ����, ʹ�� 4K ҳ��
        ;;
        mov eax, LONG_LENGTH + 0FFFh                            ; ���ϱ����� 4K �ռ�
        shr eax, 12
        push eax
        xor edi, edi
        xor edx, edx
        mov esi, LONG_SEGMENT
        mov eax, esi
        mov ecx, US | RW | P 
        call do_prev_stage3_virtual_address_mapping32_n     
        
        ;;
        ;; 2��ӳ�� SETUP_SEGMENT ����
        ;;
        mov ecx, [SETUP_SEGMENT]
        add ecx, 0FFFh
        shr ecx, 12
        push ecx
        xor edi, edi
        xor edx, edx       
        mov esi, SETUP_SEGMENT
        mov eax, esi
        mov ecx, US | RW | P
        call do_prev_stage3_virtual_address_mapping32_n
      
        
%ifdef GUEST_ENABLE
        ;;
        ;; ӳ�� guest ģ��
        ;;
        mov ecx, [GUEST_BOOT_SEGMENT]
        add ecx, 0FFFh
        shr ecx, 12
        push ecx
        xor edi, edi
        xor edx, edx        
        mov esi, GUEST_BOOT_SEGMENT
        mov eax, esi
        mov ecx, US | RW | P
        call do_prev_stage3_virtual_address_mapping32_n

        mov ecx, [GUEST_KERNEL_SEGMENT]
        add ecx, 0FFFh
        shr ecx, 12
        push ecx
        xor edi, edi
        xor edx, edx        
        mov esi, GUEST_KERNEL_SEGMENT
        mov eax, esi
        mov ecx, US | RW | P
        call do_prev_stage3_virtual_address_mapping32_n        
%endif

        
        ;;
        ;; 3) ӳ�� 64-bit ģʽ�µ� LONG_SEGMENT ����
        ;;      3.1) �����ַ ffff_ff80_4000_0000 - ffff_ff80_4000_3fffh 
        ;;      3.2) ӳ�䵽 2_0000h - 2_3000h ����ҳ�棬ʹ�� 4K ҳ
        ;; 
        mov eax, LONG_LENGTH + 0FFFh
        shr eax, 12
        push eax        
        mov edi, 0FFFFFF80h
        mov esi, 40000000h
        mov eax, LONG_SEGMENT
        xor edx, edx
        mov ecx, RW | P
        call do_prev_stage3_virtual_address_mapping32_n

        ;;
        ;; ӳ�� video ����
        ;;
        mov esi, [fs: SDA.VideoBufferPtr]
        xor edi, edi
        mov eax, 0B8000h
        xor edx, edx
        mov ecx, XD | RW | US | P
        push DWORD (((24 * 80 * 2) * 2 + 0FFFh) / 1000h)
        call do_prev_stage3_virtual_address_mapping32_n
        

        ;;
        ;; ӳ�� SDA ����:
        ;; 1) SDA ����� legacy stage1 �׶��µ������ַ��һ��һӳ�䣩
        ;; 2) SDA ����λ��: ffff_f800_8002_0000h
        ;;
        mov esi, [fs: SDA.PhysicalBase]
        xor edi, edi
        mov eax, esi
        mov edx, edi
        mov ecx, [fs: SDA.Size]
        add ecx, [fs: SRT.Size]
        add ecx, 0FFFh
        shr ecx, 12
        push ecx
        mov ecx, XD | RW | P
        call do_prev_stage3_virtual_address_mapping32_n
                
        mov esi, SDA_BASE
        mov edi, 0FFFFF800h
        mov eax, [fs: SDA.PhysicalBase]
        mov edx, [fs: SDA.PhysicalBase + 4]
        mov ecx, [fs: SDA.Size]
        add ecx, [fs: SRT.Size]
        add ecx, 0FFFh
        shr ecx, 12
        push ecx
        mov ecx, XD | RW | P
        call do_prev_stage3_virtual_address_mapping32_n
        
        
        ;;
        ;; ӳ��ҳ��� PT Pool����:
        ;; 1) �� PT Pool ����  ffff_f800_8220_0000h ӳ�䵽 220_0000h
        ;; 2) ���� PT Pool ����: ffff_f800_8020_0000h ӳ�䵽 020_0000h
        ;;
        
        ;;
        ;; 1) PT Pool ����
        ;;
        mov esi, [fs: SDA.PtPoolBase]
        mov edi, [fs: SDA.PtPoolBase + 4]
        mov eax, PT_POOL_PHYSICAL_BASE64
        xor edx, edx
        mov ecx, [fs: SDA.PtPoolSize]
        add ecx, 0FFFh
        shr ecx, 12
        push ecx
        mov ecx, XD | RW | P
        call do_prev_stage3_virtual_address_mapping32_n
        
        ;;
        ;; 2) ���� PT Pool ����
        ;;
        mov esi, [fs: SDA.PtPool2Base]
        mov edi, [fs: SDA.PtPool2Base + 4]
        mov eax, PT_POOL2_PHYSICAL_BASE64
        xor edx, edx
        mov ecx, [fs: SDA.PtPool2Size]
        add ecx, 0FFFh
        shr ecx, 12
        push ecx
        mov ecx, XD | RW | P
        call do_prev_stage3_virtual_address_mapping32_n       

        ;;
        ;; ӳ�� LAPIC �� IAPIC
        ;; 1) LAPIC_BASE64 = ffff_f800_fee0_0000h ӳ�䵽 fee0_0000h
        ;; 2) IAPIC_BASE64 = ffff_f800_fec0_0000h ӳ�䵽 fec0_0000h
        ;;
        mov edi, 0FFFFF800h
        mov esi, 0FEE00000h
        xor edx, edx
        mov eax, esi
        mov ecx, XD | PCD | PWT | RW | P
        call do_prev_stage3_virtual_address_mapping32
        
        mov edi, 0FFFFF800h
        mov esi, 0FEC00000h
        xor edx, edx
        mov eax, esi
        call do_prev_stage3_virtual_address_mapping32
        ret



;-----------------------------------------------------
; update_stage3_gdt_idt_pointer()
; input:
;       none
; output:
;       none
; ������
;       1) �� GDT/IDT pointer ����Ϊ paging �����µ�ֵ
;       2) Ϊ�½׶��л��� paging��׼��
;-----------------------------------------------------
update_stage3_gdt_idt_pointer:
        ;;
        ;; ���� GDT/IDT pointer��ʹ�� 64-bit �����ַ
        ;; 1) ��ַ�еĸ� 32 λֵΪ ffff_ff800h���Ѿ��� stage1 ����
        ;;
        mov DWORD [fs: SDA.IdtBase], SDA_BASE + SDA.Idt
        mov DWORD [fs: SDA.IdtTop], SDA_BASE + SDA.Idt
        mov DWORD [fs: SDA.GdtBase], SDA_BASE + SDA.Gdt
        mov eax, [fs: SDA.GdtTop]
        sub eax, SDA_PHYSICAL_BASE
        add eax, SDA_BASE
        mov [fs: SDA.GdtTop], eax
        ret    
        


;-----------------------------------------------------------------------
; map_stage3_pcb()
; input:
;       none
; output:
;       none
; ������
;       1) ӳ�� stage3 �׶ε� PCB ���� 
;-----------------------------------------------------------------------
map_stage3_pcb:
        push ecx
        push edx
        
        ;;
        ;; ӳ�䴦������ Processor Control Block ����64-bit��
        ;;
        mov ecx, [gs: PCB.Size]                                 ; PCB size
        add ecx, 0FFFh
        shr ecx, 12   
        push ecx                                                ; ҳ������        
        mov esi, [gs: PCB.Base]
        mov edi, [gs: PCB.Base + 4]                             ; edi:esi - 64 λ PCB �����ַ
        mov eax, [gs: PCB.PhysicalBase]
        mov edx, [gs: PCB.PhysicalBase + 4]                     ; edx:eax - PCB �����ַ
        mov ecx, XD | RW | P                                    ; ecx - ҳ����
        call do_prev_stage3_virtual_address_mapping32_n
        
        ;;
        ;; ӳ�䴦������ LSB ����
        ;;
        mov ecx, LOCAL_STORAGE_BLOCK_SIZE + 0FFFh
        shr ecx, 12
        push ecx
        mov esi, [gs: PCB.LsbBase]
        mov edi, [gs: PCB.LsbBase + 4]                          ; edi:esi - 64 λ LSB �����ַ
        mov eax, [gs: PCB.LsbPhysicalBase]
        mov edx, [gs: PCB.LsbPhysicalBase + 4]                  ; edx:eax - 64 λ�����ַ
        mov ecx, XD | RW | P
        call do_prev_stage3_virtual_address_mapping32_n
        
        pop edx
        pop ecx
        ret
                



;-----------------------------------------------------------------------
; update_stage3_kernel_stack()
; input:
;       none
; output:
;       none
; ������
;       1) Ϊ paging ��ʹ��ԭ kernel stack�������һ�� VA ӳ��ԭ stack
;-----------------------------------------------------------------------
update_stage3_kernel_stack:
        ;;
        ;; ���� stack ֵ��
        ;; 1) ����һ�� kernel stack �����ַӳ�䵽 kernel stack �����ַ
        ;;
        call alloc_stage3_kernel_stack_4k_base
        mov esi, eax
        mov edi, edx                                    ; edi:esi - �����ַ
        ;;
        ;; ���� KernelStack ֵ
        ;; 1) ��ǰΪ�����ַ
        ;; 2) ��ַ�еĸ� 32 λ�� 64-bit ģʽ��ʹ��
        ;;
        mov eax, esp
        and eax, 0FFFh
        add esi, eax
        add esi, 4
        mov [gs: PCB.KernelStack], esi
        mov DWORD [gs: PCB.KernelStack + 4], edi
        
        
        ;;
        ;; ӳ�� KernelStack ��ַ
        ;;
        mov eax, esp
        xor edx, edx                                    ; edx:eax - �����ַ
        mov ecx, XD | RW | P
        call do_prev_stage3_virtual_address_mapping32
        ret
        






        bits 64
        
               
;-------------------------------------------------------------------
; update_stage3_tss()
; input:
;       none
; output:
;       none
; ����:
;       1) ���� longmode �µ� TSS ��
;-------------------------------------------------------------------
update_stage3_tss:
        push rbx
        push rdx
        push rcx
           
        ;;
        ;; Tss �����ַ
        ;;
        mov rax, [gs: PCB.TssBase]

        ;;
        ;; �������� TSS ������
        ;; 1) �������������ַ��Ϊ�����ַ
        ;;
        mov rsi, rax
        mov rdx, rax
        mov rdi, 0000890000002FFFh                      ; 64-bit TSS, DPL=0, limit = 2FFFh
        shl rsi, (63 - 23)
        shr rsi, (63 - 39)                              ; base[23:0]
        or rdi, rsi 
        shr rdx, 32                                     ; base[63:32]
        and eax, 0FF000000h                             ; base[31:24]
        shl rax, 32
        or rax, rdi

        ;;
        ;; д�� GDT ��
        ;;
        movzx esi, WORD [gs: PCB.TssSelector]
        add rsi, [fs: SDA.GdtBase]
        mov [rsi], rax
        mov [rsi + 8], rdx
        
        
        ;;
        ;; �޸� TSS ������
        ;;
        mov rbx, [gs: PCB.TssBase]
        
        ;;
        ;; ����һ�� kernel ʹ�õ� stack �����ַ��ӳ��ԭ�����ַ
        ;;
        call alloc_kernel_stack_4k_base
        mov rsi, rax                                            ; �����ַ
        mov edi, [rbx + tss32.esp0]                             ; ԭ�����ַ
        add rax, 0FF0h                                          ; ����������
        mov [rbx + tss64.rsp0], rax                             ; ���� TSS64 �� RSP0 ֵ
        mov r8d, XD | RW | P
        call do_virtual_address_mapping
        
        ;;
        ;; ���¼��� TR
        movzx eax, WORD [gs: PCB.TssSelector]
        ltr ax
                        
update_stage3_tss.done:
        pop rcx
        pop rdx
        pop rbx
        ret



    
;-----------------------------------------------------------------------
; update_stage3_gs_segment()
; input:
;       none
; output:
;       none
; ����:
;       1) ���� GS ��׼��
;-----------------------------------------------------------------------
update_stage3_gs_segment:
        push rcx
        push rdx
        push rbx
        
        ;;
        ;; ���� context ����ָ��
        ;;
        mov rbx, [gs: PCB.Base]
        lea rax, [rbx + PCB.Context]
        mov [gs: PCB.ContextBase], rax
        lea rax, [rbx + PCB.XMMStateImage]
        mov [gs: PCB.XMMStateImageBase], rax

        ;;
        ;; ���� LAPIC �� IAPIC ��ַ
        ;; 1) LAPIC_BASE64 = ffff_f800_fee0_0000h
        ;; 2) IAPIC_BASE64 = ffff_f800_fec0_0000h
        ;;
        mov rax, 0FFFFF800FEE00000h
        mov [gs: PCB.LapicBase], rax
        mov rax, 0FFFFF800FEC00000h
        mov [gs: PCB.IapicBase], rax

      
        pop rbx
        pop rdx
        pop rcx
        ret
        
        
        
  

        
;-----------------------------------------------------
; install_default_interrupt_handler()
; input:
;       none
; output:
;       none
; ����:
;       1) ��װĬ�ϵ��жϷ�������
;-----------------------------------------------------
install_default_interrupt_handler:
        push rcx
        xor ecx, ecx
        
        cmp BYTE [gs: PCB.IsBsp], 1
        jne install_default_interrupt_handler.done
        
        ;;
        ;; ��װ�쳣��������
        ;;
install_default_interrupt_handler.loop:        
        mov esi, ecx
        mov rdi, [ExceptionHandlerTable + rcx * 8]
        call install_kernel_interrupt_handler64
        inc ecx
        cmp ecx, 32
        jb install_default_interrupt_handler.loop
        
        ;;
        ;; ��װ pic 8259 �жϷ�������
        ;;
        mov esi, PIC8259A_IRQ0_VECTOR
        mov rdi, timer_8259_handler64
        call install_kernel_interrupt_handler64

        mov esi, PIC8259A_IRQ1_VECTOR
        mov rdi, keyboard_8259_handler
        call install_kernel_interrupt_handler64
        
        ;;
        ;; ��װϵͳ���÷�������
        ;;
        mov esi, [fs: SRT.ServiceRoutineVector]
        mov rdi, sys_service_routine
        call install_user_interrupt_handler64
        
        ;;
        ;; ��װ IPI ��������
        ;;       
        mov esi, IPI_VECTOR
        mov rdi, dispatch_routine64
        call install_kernel_interrupt_handler64
        
        mov esi, IPI_ENTRY_VECTOR
        mov rdi, goto_entry64
        call install_kernel_interrupt_handler64
        
        ;;
        ;; ��װȱʡ local �жϷ�������
        ;;
        call install_default_local_interrupt_handler
        
install_default_interrupt_handler.done:        
        pop rcx
        ret
                
                
                
;-----------------------------------------------------
; install_default_local_interrupt_handler()
; input:
;       none
; output:
;       none
; ������
;       1) ��װ local ȱʡ�жϷ�������
;-----------------------------------------------------
install_default_local_interrupt_handler:
        mov esi, LAPIC_PERFMON_VECTOR
        mov rdi, local_interrupt_default_handler64
        call install_kernel_interrupt_handler64
        
        mov esi, LAPIC_TIMER_VECTOR
        ;mov rdi, local_interrupt_default_handler64
        mov rdi, lapic_timer_handler64
        call install_kernel_interrupt_handler64
        
        mov esi, LAPIC_ERROR_VECTOR
        mov rdi, local_interrupt_default_handler64
        call install_kernel_interrupt_handler64
        ret


                
;-----------------------------------------------------
; wait_for_ap_stage3_done()
; input:
;       none
; output:
;       none
; ������
;       1) �ȴ� AP ��� pre-stage3 �׶ι���
;-----------------------------------------------------
wait_for_ap_stage3_done:            
        ;;
        ;; 1) ���� pre-stage3 �������� AP ���� pre-stage3
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage3LockPointer]        
        xchg [rbx], eax 


        ;;
        ;; �ȴ� AP ��� pre-stage3 ����:
        ;; ��鴦�������� ApInitDoneCount �Ƿ���� LocalProcessorCount ֵ
        ;; 1)�ǣ����� AP ��� pre-stage3 ����
        ;; 2)�񣬼����ȴ�
        ;;
wait_for_ap_stage3_done.@0:     
        mov eax, [fs: SDA.ApInitDoneCount]
        cmp eax, [gs: PCB.LogicalProcessorCount]
        jb wait_for_ap_stage3_done.@0
        ret

        
        
;-----------------------------------------------------
; put_processor_to_vmx()
; input:
;       none
; output:
;       none
; ������
;       1) �����д��������� VMX root ״̬
;-----------------------------------------------------                
put_processor_to_vmx:
        push rcx

        ;;
        ;; BSP ���� VMX ����
        ;;
        call vmx_operation_enter
                  
        ;;
        ;; ʣ��� APs ���� VMX ����
        ;;
        mov ecx, 1
put_processor_to_vmx.@0:
        mov esi, ecx
        mov edi, vmx_operation_enter
        call dispatch_to_processor_with_waitting
        
        ;;
        ;; �� Status Code ����Ƿ�ɹ�
        ;;
        mov eax, [fs: SDA.LastStatusCode]
        cmp eax, STATUS_SUCCESS
        jne put_processor_to_vmx.done

        inc ecx
        cmp ecx, [fs: SDA.ProcessorCount]
        jb put_processor_to_vmx.@0

put_processor_to_vmx.done:        
        pop rcx
        ret
               
               
               

        

        