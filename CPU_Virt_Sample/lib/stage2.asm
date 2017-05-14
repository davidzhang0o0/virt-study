;*************************************************
; stage2.asm                                     *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************
   
   
   

;-----------------------------------------------------
; update_stage2_gdt_idt_pointer()
; input:
;       none
; output:
;       none
; ������
;       1) �� GDT/IDT pointer ����Ϊ paging �����µ�ֵ
;       2) Ϊ�½׶��л��� paging��׼��
;-----------------------------------------------------
update_stage2_gdt_idt_pointer:
        ;;
        ;; ���� GDT/IDT pointer��ʹ�������ַ
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
; map_stage2_pcb()
; input:
;       none
; output:
;       none
; ������
;       1) ӳ�� stage2 �׶ε� PCB ���� 
;-----------------------------------------------------------------------
map_stage2_pcb:
        push ecx
        ;;
        ;; ӳ�䴦������ Processor Control Block ����
        ;;
        mov esi, [gs: PCB.Base]                                 ; PCB virutal address
        mov edi, [gs: PCB.PhysicalBase]                         ; PCB physical address
        mov ecx, [gs: PCB.Size]                                 ; PCB size
        add ecx, 0FFFh
        shr ecx, 12        
map_stage1_pcb.@0:        
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        add esi, 1000h
        add edi, 1000h
        dec ecx
        jnz map_stage1_pcb.@0
        
        ;;
        ;; ӳ�� Local Storage Block ����
        ;;
        mov esi, [gs: PCB.LsbBase]
        mov edi, [gs: PCB.LsbPhysicalBase]
        mov ecx, LOCAL_STORAGE_BLOCK_SIZE + 0FFFh
        shr ecx, 12
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping_n
        
        pop ecx
        ret
        
        
;-----------------------------------------------------------------------
; update_stage2_tss()
; input:
;       none
; output:
;       none
; ������
;       1) �� TSS ����Ϊ stage2��paging �£����� 
;       2) �ڽ��� stage2 ��ʹ��
;-----------------------------------------------------------------------
update_stage2_tss:
        push ebx
        push edx
        push ecx
           
        ;;
        ;; Tss �����ַ
        ;;
        mov eax, [gs: PCB.TssBase]
        
        ;;
        ;; �������� TSS ������
        ;; 1) �������������ַ��Ϊ�����ַ
        ;;
        mov ecx, eax
        xor edx, edx
        and eax, 00FFFFFFh
        shld edx, eax, 16
        shl eax, 16
        or eax, (1000h + 2000h - 1)                             ; TSS limit = 2FFFh������ IO bitmap��
        and ecx, 0FF000000h
        or ecx, 00008900h                                       ; 32-bit TSS, available
        or edx, ecx                                             ; edx:eax - TSS ������
        
        ;;
        ;; д�� GDT ��
        ;;
        movzx esi, WORD [gs: PCB.TssSelector]
        add esi, [fs: SDA.GdtBase]
        mov [esi], eax
        mov [esi + 4], edx
        
        
        ;;
        ;; �޸� TSS ������
        ;;
        mov ebx, [gs: PCB.TssBase]
        mov ax, [fs: SDA.KernelCsSelector]
        mov [ebx + tss32.ss0], ax
        
        ;;
        ;; ����һ�� kernel ʹ�õ� stack �����ַ��ӳ��ԭ�����ַ
        ;;
        call alloc_kernel_stack_4k_base
        mov esi, eax                                            ; �����ַ
        mov edi, [ebx + tss32.esp0]                             ; �����ַ
        add eax, 0FF0h                                          ; ����������
        mov [ebx + tss32.esp0], eax                             ; ���� ESP0 ֵ
        mov eax, XD | RW | P
        call do_virtual_address_mapping
        
        ;;
        ;; ���¼��� TR
        movzx eax, WORD [gs: PCB.TssSelector]
        ltr ax
                
update_stage2_tss.done:
        pop ecx
        pop edx
        pop ebx
        ret
        
        
;-----------------------------------------------------------------------
; update_stage2_kernel_stack()
; input:
;       none
; output:
;       none
; ������
;       1) Ϊ paging ��ʹ��ԭ kernel stack�������һ�� VA ӳ��ԭ stack
;-----------------------------------------------------------------------
update_stage2_kernel_stack:
        ;;
        ;; ���� stack ֵ��
        ;; 1) ����һ�� kernel stack �����ַӳ�䵽 kernel stack �����ַ
        ;;
        call alloc_kernel_stack_4k_base
        mov esi, eax
        
        ;;
        ;; ���� KernelStack ֵ
        ;; 1) ��ǰΪ�����ַ
        ;; 2) ��ַ�еĸ� 32 λ�� 64-bit ģʽ��ʹ��
        ;;
        mov eax, esp
        and eax, 0FFFh
        add eax, esi
        add eax, 4
        mov [gs: PCB.KernelStack], eax
        mov DWORD [gs: PCB.KernelStack + 4], 0FFFFFF80h
        
        
        ;;
        ;; ӳ�� KernelStack ��ַ
        ;;
        mov edi, esp
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        ret

        


;-----------------------------------------------------
; wait_for_stage2_done()
; input:
;       none
; output:
;       none
; ������
;       1) ���� INIT-SIPI-SIPI ��Ϣ��� AP
;       2) �ȴ� AP ��ɵ�2�׶ι���
;-----------------------------------------------------
wait_for_ap_stage2_done:             
        ;;
        ;; ���ŵ�2�׶� AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage2LockPointer]
        xchg [ebx], eax
        
        ;;
        ;; �ȴ� AP ��� stage2 ����:
        ;; ��鴦�������� ApInitDoneCount �Ƿ���� LocalProcessorCount ֵ
        ;; 1)�ǣ����� AP ��� stage2 ����
        ;; 2)�񣬼����ȴ�
        ;;
wait_for_ap_stage2_done.@0:        
        mov eax, [fs: SDA.ApInitDoneCount]
        cmp eax, [gs: PCB.LogicalProcessorCount]
        jb wait_for_ap_stage2_done.@0
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
        push ecx

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
        pop ecx
        ret