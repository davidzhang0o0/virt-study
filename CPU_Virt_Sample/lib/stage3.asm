;*************************************************
; stage3.asm                                     *
; Copyright (c) 2009-2013 邓志                   *
; All rights reserved.                           *
;*************************************************



;;
;; stage3 说明：
;; 1) 前半部分在 legacy 32 位环境执行
;; 2) 后半部分在 64-bit 环境下执行
;;

        bits 32

;-----------------------------------------------------------------------
; alloc_stage3_kernel_stack_4k_base()
; input:
;       none
; output:
;       edx:eax - 64 位的 4K stack base（虚拟地址） 
; 描述：
;       1)分配一个4K页面大小的 kernel stack base的可用值         
;       2)并更新当前 kernel stack base 记录
;-----------------------------------------------------------------------
alloc_stage3_kernel_stack_4k_base:
        mov eax, 4096
        xor edx, edx                                            ; 分配 4K 大小
        mov esi, SDA_PHYSICAL_BASE + SDA.KernelStackBase        ; 在 KernelStackBase 池里分配
        call locked_xadd64                                      ; edx:eax 返回 kernel base
        ret
        
        
        

        
;---------------------------------------------------------------
; init_longmode_basic_page32()
; input:
;       none
; output:
;       none
; 描述：
;       1) 在进入 long-mode 前进行最基本的初始化
;       2) 在 legacy 下使用
;---------------------------------------------------------------
init_longmode_basic_page32:
        ;;
        ;; 下面映射 PPT 表区域（2M），包括 PXT 表区域（4K）
        ;;
        call map_longmode_page_transition_table32
        
        ;;
        ;; 映射基本运行区域：
        ;; 1) compatibility 模式下的 LONG_SEGMENT 区域
        ;; 2) setup 模块区域
        ;; 3) 64-bit 模式下的 LONG_SEGMENT 区域
        ;;
        
        ;;
        ;; 1) 映射 compatibility 模式下（初始化时）的 LONG_SEGMENT 区域, 使用 4K 页面
        ;;
        mov eax, LONG_LENGTH + 0FFFh                            ; 加上保留的 4K 空间
        shr eax, 12
        push eax
        xor edi, edi
        xor edx, edx
        mov esi, LONG_SEGMENT
        mov eax, esi
        mov ecx, US | RW | P 
        call do_prev_stage3_virtual_address_mapping32_n     
        
        ;;
        ;; 2）映射 SETUP_SEGMENT 区域
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
        ;; 映射 guest 模块
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
        ;; 3) 映射 64-bit 模式下的 LONG_SEGMENT 区域：
        ;;      3.1) 虚拟地址 ffff_ff80_4000_0000 - ffff_ff80_4000_3fffh 
        ;;      3.2) 映射到 2_0000h - 2_3000h 物理页面，使用 4K 页
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
        ;; 映射 video 区域
        ;;
        mov esi, [fs: SDA.VideoBufferPtr]
        xor edi, edi
        mov eax, 0B8000h
        xor edx, edx
        mov ecx, XD | RW | US | P
        push DWORD (((24 * 80 * 2) * 2 + 0FFFh) / 1000h)
        call do_prev_stage3_virtual_address_mapping32_n
        

        ;;
        ;; 映射 SDA 区域:
        ;; 1) SDA 区域的 legacy stage1 阶段下的物理地址（一对一映射）
        ;; 2) SDA 区域位于: ffff_f800_8002_0000h
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
        ;; 映射页表池 PT Pool区域:
        ;; 1) 主 PT Pool 区域：  ffff_f800_8220_0000h 映射到 220_0000h
        ;; 2) 备用 PT Pool 区域: ffff_f800_8020_0000h 映射到 020_0000h
        ;;
        
        ;;
        ;; 1) PT Pool 区域
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
        ;; 2) 备用 PT Pool 区域
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
        ;; 映射 LAPIC 与 IAPIC
        ;; 1) LAPIC_BASE64 = ffff_f800_fee0_0000h 映射到 fee0_0000h
        ;; 2) IAPIC_BASE64 = ffff_f800_fec0_0000h 映射到 fec0_0000h
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
; 描述：
;       1) 将 GDT/IDT pointer 更新为 paging 管理下的值
;       2) 为下阶段切换到 paging作准备
;-----------------------------------------------------
update_stage3_gdt_idt_pointer:
        ;;
        ;; 更新 GDT/IDT pointer，使用 64-bit 虚拟地址
        ;; 1) 地址中的高 32 位值为 ffff_ff800h，已经在 stage1 设置
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
; 描述：
;       1) 映射 stage3 阶段的 PCB 区域 
;-----------------------------------------------------------------------
map_stage3_pcb:
        push ecx
        push edx
        
        ;;
        ;; 映射处理器的 Processor Control Block 区域（64-bit）
        ;;
        mov ecx, [gs: PCB.Size]                                 ; PCB size
        add ecx, 0FFFh
        shr ecx, 12   
        push ecx                                                ; 页面数量        
        mov esi, [gs: PCB.Base]
        mov edi, [gs: PCB.Base + 4]                             ; edi:esi - 64 位 PCB 虚拟地址
        mov eax, [gs: PCB.PhysicalBase]
        mov edx, [gs: PCB.PhysicalBase + 4]                     ; edx:eax - PCB 物理地址
        mov ecx, XD | RW | P                                    ; ecx - 页属性
        call do_prev_stage3_virtual_address_mapping32_n
        
        ;;
        ;; 映射处理器的 LSB 区域
        ;;
        mov ecx, LOCAL_STORAGE_BLOCK_SIZE + 0FFFh
        shr ecx, 12
        push ecx
        mov esi, [gs: PCB.LsbBase]
        mov edi, [gs: PCB.LsbBase + 4]                          ; edi:esi - 64 位 LSB 虚拟地址
        mov eax, [gs: PCB.LsbPhysicalBase]
        mov edx, [gs: PCB.LsbPhysicalBase + 4]                  ; edx:eax - 64 位物理地址
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
; 描述：
;       1) 为 paging 在使用原 kernel stack，需分配一个 VA 映射原 stack
;-----------------------------------------------------------------------
update_stage3_kernel_stack:
        ;;
        ;; 调整 stack 值：
        ;; 1) 分配一个 kernel stack 虚拟地址映射到 kernel stack 物理地址
        ;;
        call alloc_stage3_kernel_stack_4k_base
        mov esi, eax
        mov edi, edx                                    ; edi:esi - 虚拟地址
        ;;
        ;; 更新 KernelStack 值
        ;; 1) 此前为物理地址
        ;; 2) 地址中的高 32 位在 64-bit 模式下使用
        ;;
        mov eax, esp
        and eax, 0FFFh
        add esi, eax
        add esi, 4
        mov [gs: PCB.KernelStack], esi
        mov DWORD [gs: PCB.KernelStack + 4], edi
        
        
        ;;
        ;; 映射 KernelStack 地址
        ;;
        mov eax, esp
        xor edx, edx                                    ; edx:eax - 物理地址
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
; 描述:
;       1) 构造 longmode 下的 TSS 块
;-------------------------------------------------------------------
update_stage3_tss:
        push rbx
        push rdx
        push rcx
           
        ;;
        ;; Tss 虚拟地址
        ;;
        mov rax, [gs: PCB.TssBase]

        ;;
        ;; 重新设置 TSS 描述符
        ;; 1) 描述符中物理地址改为虚拟地址
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
        ;; 写入 GDT 中
        ;;
        movzx esi, WORD [gs: PCB.TssSelector]
        add rsi, [fs: SDA.GdtBase]
        mov [rsi], rax
        mov [rsi + 8], rdx
        
        
        ;;
        ;; 修改 TSS 块内容
        ;;
        mov rbx, [gs: PCB.TssBase]
        
        ;;
        ;; 分配一个 kernel 使用的 stack 虚拟地址，映射原物理地址
        ;;
        call alloc_kernel_stack_4k_base
        mov rsi, rax                                            ; 虚拟地址
        mov edi, [rbx + tss32.esp0]                             ; 原物理地址
        add rax, 0FF0h                                          ; 调整到顶部
        mov [rbx + tss64.rsp0], rax                             ; 更新 TSS64 的 RSP0 值
        mov r8d, XD | RW | P
        call do_virtual_address_mapping
        
        ;;
        ;; 重新加载 TR
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
; 描述:
;       1) 更新 GS 段准备
;-----------------------------------------------------------------------
update_stage3_gs_segment:
        push rcx
        push rdx
        push rbx
        
        ;;
        ;; 更新 context 区域指针
        ;;
        mov rbx, [gs: PCB.Base]
        lea rax, [rbx + PCB.Context]
        mov [gs: PCB.ContextBase], rax
        lea rax, [rbx + PCB.XMMStateImage]
        mov [gs: PCB.XMMStateImageBase], rax

        ;;
        ;; 更新 LAPIC 与 IAPIC 基址
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
; 描述:
;       1) 安装默认的中断服务例程
;-----------------------------------------------------
install_default_interrupt_handler:
        push rcx
        xor ecx, ecx
        
        cmp BYTE [gs: PCB.IsBsp], 1
        jne install_default_interrupt_handler.done
        
        ;;
        ;; 安装异常服务例程
        ;;
install_default_interrupt_handler.loop:        
        mov esi, ecx
        mov rdi, [ExceptionHandlerTable + rcx * 8]
        call install_kernel_interrupt_handler64
        inc ecx
        cmp ecx, 32
        jb install_default_interrupt_handler.loop
        
        ;;
        ;; 安装 pic 8259 中断服务例程
        ;;
        mov esi, PIC8259A_IRQ0_VECTOR
        mov rdi, timer_8259_handler64
        call install_kernel_interrupt_handler64

        mov esi, PIC8259A_IRQ1_VECTOR
        mov rdi, keyboard_8259_handler
        call install_kernel_interrupt_handler64
        
        ;;
        ;; 安装系统调用服务例程
        ;;
        mov esi, [fs: SRT.ServiceRoutineVector]
        mov rdi, sys_service_routine
        call install_user_interrupt_handler64
        
        ;;
        ;; 安装 IPI 服务例程
        ;;       
        mov esi, IPI_VECTOR
        mov rdi, dispatch_routine64
        call install_kernel_interrupt_handler64
        
        mov esi, IPI_ENTRY_VECTOR
        mov rdi, goto_entry64
        call install_kernel_interrupt_handler64
        
        ;;
        ;; 安装缺省 local 中断服务例程
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
; 描述：
;       1) 安装 local 缺省中断服务例程
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
; 描述：
;       1) 等待 AP 完成 pre-stage3 阶段工作
;-----------------------------------------------------
wait_for_ap_stage3_done:            
        ;;
        ;; 1) 开放 pre-stage3 锁，允许 AP 进入 pre-stage3
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage3LockPointer]        
        xchg [rbx], eax 


        ;;
        ;; 等待 AP 完成 pre-stage3 工作:
        ;; 检查处理器计数 ApInitDoneCount 是否等于 LocalProcessorCount 值
        ;; 1)是，所有 AP 完成 pre-stage3 工作
        ;; 2)否，继续等待
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
; 描述：
;       1) 将所有处理器放入 VMX root 状态
;-----------------------------------------------------                
put_processor_to_vmx:
        push rcx

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
        pop rcx
        ret
               
               
               

        

        