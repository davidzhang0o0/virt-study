;*************************************************
; stage2.asm                                     *
; Copyright (c) 2009-2013 邓志                   *
; All rights reserved.                           *
;*************************************************
   
   
   

;-----------------------------------------------------
; update_stage2_gdt_idt_pointer()
; input:
;       none
; output:
;       none
; 描述：
;       1) 将 GDT/IDT pointer 更新为 paging 管理下的值
;       2) 为下阶段切换到 paging作准备
;-----------------------------------------------------
update_stage2_gdt_idt_pointer:
        ;;
        ;; 更新 GDT/IDT pointer，使用虚拟地址
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
; 描述：
;       1) 映射 stage2 阶段的 PCB 区域 
;-----------------------------------------------------------------------
map_stage2_pcb:
        push ecx
        ;;
        ;; 映射处理器的 Processor Control Block 区域
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
        ;; 映射 Local Storage Block 区域
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
; 描述：
;       1) 将 TSS 更新为 stage2（paging 下）环境 
;       2) 在进入 stage2 后使用
;-----------------------------------------------------------------------
update_stage2_tss:
        push ebx
        push edx
        push ecx
           
        ;;
        ;; Tss 虚拟地址
        ;;
        mov eax, [gs: PCB.TssBase]
        
        ;;
        ;; 重新设置 TSS 描述符
        ;; 1) 描述符中物理地址改为虚拟地址
        ;;
        mov ecx, eax
        xor edx, edx
        and eax, 00FFFFFFh
        shld edx, eax, 16
        shl eax, 16
        or eax, (1000h + 2000h - 1)                             ; TSS limit = 2FFFh（包括 IO bitmap）
        and ecx, 0FF000000h
        or ecx, 00008900h                                       ; 32-bit TSS, available
        or edx, ecx                                             ; edx:eax - TSS 描述符
        
        ;;
        ;; 写入 GDT 中
        ;;
        movzx esi, WORD [gs: PCB.TssSelector]
        add esi, [fs: SDA.GdtBase]
        mov [esi], eax
        mov [esi + 4], edx
        
        
        ;;
        ;; 修改 TSS 块内容
        ;;
        mov ebx, [gs: PCB.TssBase]
        mov ax, [fs: SDA.KernelCsSelector]
        mov [ebx + tss32.ss0], ax
        
        ;;
        ;; 分配一个 kernel 使用的 stack 虚拟地址，映射原物理地址
        ;;
        call alloc_kernel_stack_4k_base
        mov esi, eax                                            ; 虚拟地址
        mov edi, [ebx + tss32.esp0]                             ; 物理地址
        add eax, 0FF0h                                          ; 调整到顶部
        mov [ebx + tss32.esp0], eax                             ; 更新 ESP0 值
        mov eax, XD | RW | P
        call do_virtual_address_mapping
        
        ;;
        ;; 重新加载 TR
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
; 描述：
;       1) 为 paging 在使用原 kernel stack，需分配一个 VA 映射原 stack
;-----------------------------------------------------------------------
update_stage2_kernel_stack:
        ;;
        ;; 调整 stack 值：
        ;; 1) 分配一个 kernel stack 虚拟地址映射到 kernel stack 物理地址
        ;;
        call alloc_kernel_stack_4k_base
        mov esi, eax
        
        ;;
        ;; 更新 KernelStack 值
        ;; 1) 此前为物理地址
        ;; 2) 地址中的高 32 位在 64-bit 模式下使用
        ;;
        mov eax, esp
        and eax, 0FFFh
        add eax, esi
        add eax, 4
        mov [gs: PCB.KernelStack], eax
        mov DWORD [gs: PCB.KernelStack + 4], 0FFFFFF80h
        
        
        ;;
        ;; 映射 KernelStack 地址
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
; 描述：
;       1) 发送 INIT-SIPI-SIPI 消息序给 AP
;       2) 等待 AP 完成第2阶段工作
;-----------------------------------------------------
wait_for_ap_stage2_done:             
        ;;
        ;; 开放第2阶段 AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage2LockPointer]
        xchg [ebx], eax
        
        ;;
        ;; 等待 AP 完成 stage2 工作:
        ;; 检查处理器计数 ApInitDoneCount 是否等于 LocalProcessorCount 值
        ;; 1)是，所有 AP 完成 stage2 工作
        ;; 2)否，继续等待
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
; 描述：
;       1) 将所有处理器放入 VMX root 状态
;-----------------------------------------------------                
put_processor_to_vmx:
        push ecx

        ;;
        ;; BSP 进入 VMX 环境
        ;;
        call vmx_operation_enter
        
        ;;
        ;; 剩余的 APs 进入 VMX 环境
        ;;
        mov ecx, 1
put_processor_to_vmx.@0:
        mov esi, ecx
        mov edi, vmx_operation_enter
        call dispatch_to_processor_with_waitting
        ;;
        ;; 读 Status Code 检查是否成功
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