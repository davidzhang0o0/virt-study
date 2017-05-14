;*************************************************
; protected.asm                                  *
; Copyright (c) 2009-2013 邓志                   *
; All rights reserved.                           *
;*************************************************


%include "..\inc\support.inc"
%include "..\inc\protected.inc"


        org PROTECTED_SEGMENT

        DD      PROTECTED_LENGTH                        ; 保存模块长度
        DD      BspProtectedEntry                       ; BSP 的 protected 模块入口
        DD      ApStage2Routine                         ; AP 的 protected 模块入口
        
        
        bits 32        
        
BspProtectedEntry:
        ;;
        ;; 初始化 stage2 阶段的 paging 环境
        ;; 1) 使用 PAE 分页结构
        ;;
        call init_ppt_area
        call init_pae_page
        
        ;;
        ;; 更新 stage2 的 GDT/IDT pointer 值
        ;;
        call update_stage2_gdt_idt_pointer
        
ApProtectedEntry:  
        ;;
        ;; 映射 stage2 阶段的 PCB 区域
        ;;
        call map_stage2_pcb

        ;;
        ;; 更新 stage2 的 kernel stack
        ;; 1) 需要开启分页前及更新 FS 段前执行
        ;; 2) 将调整后的 kernel stack 保存在 PCB.KernelStack 内        
        ;;
        call update_stage2_kernel_stack
        
        ;;
        ;; 读 FS/GS base 值
        ;;
        mov esi, [fs: SDA.Base]
        mov edi, [gs: PCB.Base]

        ;;
        ;; 加载 PPT 表
        ;;
        mov eax, [fs: SDA.PptPhysicalBase]
        mov cr3, eax

        ;;
        ;; 开启 paging 管理
        ;;
        mov eax, cr0
        bts eax, 31
        mov cr0, eax 
        
        ;;
        ;; 更新 fs 与 gs 段为开启 paging 后的 base 值
        ;;
        xor edx, edx
        mov eax, esi
        mov ecx, IA32_FS_BASE     
        wrmsr
        mov eax, edi
        mov ecx, IA32_GS_BASE
        wrmsr

        ;;
        ;; 更新处理器状态
        ;;
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_PG | CPU_STATUS_PE
        
        ;;
        ;; 更新 kernel stack
        ;;
        mov esp, [gs: PCB.KernelStack]
        
        ;;
        ;; 重新加载 GDTR/IDTR 以及 TR
        ;;
        lgdt [fs: SDA.GdtPointer]
        lidt [fs: SDA.IdtPointer]
        ;;
        ;; 更新 TSS 环境，这是 legacy 模式下是最终 TSS 环境
        ;;
        call update_stage2_tss        
        
        ;;
        ;; 设置 user stack pointer
        ;;
        call get_user_stack_4k_pointer
        mov [gs: PCB.UserStack], eax
        
        
        ;;
        ;; 配置 SYSENTER/SYSEXIT 使用环境
        ;;
        call setup_sysenter
               
        ;;
        ;; 初始化处理器 debug store 单元
        ;;
        call init_debug_store_unit
        


%ifndef DBG
        ;;
        ;; Stage2 阶段最后工作，检查是否为 BSP
        ;; 1) 是，等待所有 AP 完成 stage2 工作
        ;; 2) 否，转入ApStage3End
        ;;
        cmp BYTE [gs: PCB.IsBsp], 1
        jne ApStage2End

        call init_sys_service_call


        ;;
        ;; 等待所有 AP 第2阶段工作完成
        ;;
        call wait_for_ap_stage2_done
        

        ;;
        ;; 将处理器切入到 VMX root 模式
        ;;        
        call vmx_operation_enter
        
%endif

        ;;
        ;; 当前处理器拥有焦点
        ;;         
        mov eax, [gs: PCB.ProcessorIndex] 
        mov [fs: SDA.InFocus], eax

        ;;
        ;; 更新 SDA.KeyBuffer 记录
        ;;        
        mov ebx, [gs: PCB.LsbBase]
        mov eax, [ebx + LSB.LocalKeyBufferHead]
        mov [fs: SDA.KeyBufferHead], eax
        lea eax, [ebx + LSB.LocalKeyBufferPtr]
        mov [fs: SDA.KeyBufferPtrPointer], eax
        mov eax, [ebx + LSB.LocalKeyBufferSize]
        mov [fs: SDA.KeyBufferLength], eax
        
        
        ;;
        ;; 打开键盘
        ;;
        call enable_8259_keyboard
        
        sti
        NMI_ENABLE

        ;;
        ;; 更新系统状态
        ;;
        call update_system_status   
        
        
        
;;============================================================================;;
;;                      所有处理器初始化完成                                   ;;
;;============================================================================;;
        
        bits 32
        
        ;;
        ;; 嵌入实验例子代码，在 ex.asm 文件里实现
        ;;
        %include "ex.asm"





                                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;              User 代码               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                                
; 进入 ring 3 代码
        movzx eax, WORD [fs: SDA.UserSsSelector]
        or eax, 3
        push eax
        push DWORD [gs: PCB.UserStack]
        movzx eax, WORD [fs: SDA.UserCsSelector]
        or eax, 3
        push eax
        push DWORD user_entry
        retf

        
;; 用户代码
user_entry:
        mov ax, UserSsSelector32
        mov ds, ax
        mov es, ax
user_start:
        hlt
        jmp $ - 1





;********************************************************
;*      !!!  AP 处理器 protected 模块代码 !!!           *
;********************************************************

ApStage2Routine:
        jmp ApProtectedEntry
        
       
ApStage2End:

%ifdef TRACE
        mov esi, Stage2.Msg
        call puts
%endif


        
        ;;
        ;; 增加 ApInitDoneCount 计数
        ;;
        lock inc DWORD [fs: SDA.ApInitDoneCount]
        
        ;;
        ;; 开放第2阶段 AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage2LockPointer]
        xchg [ebx], eax
 
        ;;
        ;; 设置 UsableProcessMask 值，指示 logical processor 处于可用状态
        ;;
        mov eax, [gs: PCB.ProcessorIndex]                       ; 处理器 index 
        lock bts DWORD [fs: SDA.UsableProcessorMask], eax       ; 设 Mask 位

        ;;
        ;; 将处理器切入到 VMX root 模式
        ;;        
        call vmx_operation_enter
        
        ;;
        ;; 更新系统状态
        ;;
        call update_system_status        
        
        ;;
        ;; 记录处理器的 HLT 状态
        ;;
        mov DWORD [gs: PCB.ActivityState], CPU_STATE_HLT
                         
        ;;
        ;; AP 第2阶段的最终工作是：进入 HLT 状态
        ;;
        sti
        hlt
        jmp $ - 1







        bits 32


;********* include 模块 ********************
%include "..\lib\crt.asm"
%include "..\lib\LocalVideo.asm"
%include "..\lib\system_data_manage.asm"
%include "..\lib\services.asm"
%include "..\lib\pci.asm"
%include "..\lib\apic.asm"
%include "..\lib\ioapic.asm"
%include "..\lib\debug.asm"
%include "..\lib\perfmon.asm"
%include "..\lib\mem.asm"
%include "..\lib\page32.asm"
%include "..\lib\pic8259A.asm"
%include "..\lib\Vmx\VmxInit.asm"
%include "..\lib\Vmx\Vmx.asm"
%include "..\lib\Vmx\VmxException.asm"
%include "..\lib\Vmx\VmxVmcs.asm"
%include "..\lib\Vmx\VmxDump.asm"
%include "..\lib\Vmx\VmxLib.asm"
%include "..\lib\Vmx\VmxPage.asm"
%include "..\lib\Vmx\VmxVMM.asm"
%include "..\lib\Vmx\VmxExit.asm"
%include "..\lib\Vmx\VmxMsr.asm"
%include "..\lib\Vmx\VmxIo.asm"
%include "..\lib\Vmx\VmxApic.asm"
%include "..\lib\smp.asm"
%include "..\lib\DebugRecord.asm"
%include "..\lib\stage2.asm"
%include "..\lib\dump\dump_apic.asm"
%include "..\lib\data.asm"
%include "..\lib\Decode\Decode.asm"


;;
;; 模块长度
;;
PROTECTED_LENGTH        EQU     $ - $$


;; end of protected.asm