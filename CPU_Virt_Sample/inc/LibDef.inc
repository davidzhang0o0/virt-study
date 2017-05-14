;*************************************************
; LibDef.inc                                     *
; Copyright (c) 2009-2013 邓志                   *
; All rights reserved.                           *
;*************************************************

%ifndef __LIBDEF_INC
%define __LIBDEF_INC


;---------------------------------------
; DBG_MSG
; input:
;       %1 - message string
; output:
;       none
; 描述：
;       1) 打印字符串
;---------------------------------------
%macro DBG_MSG 1
        jmp %%1
%%0:    db %1, 10, 0
%%1:
        mov esi, %%0
        call puts
%endmacro
        

;---------------------------------------
; UserReadSdaData
; input:
;       %1 - offset
;       %2 - length
; output:
;       eax - data
; 描述：
;       1) USER权限下读 SDA 数据
;---------------------------------------
%macro UserReadSdaData  2
        mov eax, READ_SDA_DATA
        mov esi, %1 | (%2 << 28)
        call sys_service_enter
%endmacro


;---------------------------------------
; UserReadPcbData
; input:
;       %1 - offset
;       %2 - length
; output:
;       eax - data
; 描述：
;       1) USER权限下读 PCB 数据
;---------------------------------------
%macro UserReadPcbData  2
        mov eax, READ_PCB_DATA
        mov esi, %1 | (%2 << 28)
        call sys_service_enter
%endmacro



;---------------------------------------
; UserWriteSdaData
; input:
;       %1 - offset
;       %2 - length
;       %3 - data
; output:
;       none
; 描述：
;       1) USER权限下写 SDA 数据
;---------------------------------------
%macro UserWriteSdaData  3
%if __BITS__ == 64
        mov rdi, %3
        mov eax, WRITE_SDA_DATA
        mov esi, %1 | (%2 << 28)
        call sys_service_enter
%else
        REX.Wrxb
        mov edi, %3
        mov eax, WRITE_SDA_DATA
        mov esi, %1 | (%2 << 28)
        call sys_service_enter
%endif
%endmacro


;---------------------------------------
; UserWritePcbData
; input:
;       %1 - offset
;       %2 - length
;       %3 - data
; output:
;       none
; 描述：
;       1) USER权限下写 SDA 数据
;---------------------------------------
%macro UserWritePcbData  3
%if __BITS__ == 64
        mov rdi, %3
        mov eax, WRITE_PCB_DATA
        mov esi, %1 | (%2 << 28)
        call sys_service_enter
%else
        REX.Wrxb
        mov edi, %3
        mov eax, WRITE_PCB_DATA
        mov esi, %1 | (%2 << 28)
        call sys_service_enter
%endif
%endmacro



;---------------------------------------
; UserReadSysData
; input:
;       %1 - address
; output:
;       eax - data
; 描述：
;       1) USER权限下读 Sys 数据
;---------------------------------------
%macro UserReadSysData  1
        mov eax, READ_SYS_DATA
%if __BITS__ == 64
        mov rsi, %1
%else
        mov esi, %1
%endif
        call sys_service_enter
%endmacro


;---------------------------------------
; UserWriteSysData
; input:
;       %1 - address
;       %2 - data
; output:
;       none
; 描述：
;       1) USER权限下写 Sys 数据
;---------------------------------------
%macro UserWriteSysData  2
%if __BITS__ == 64
        mov rsi, %1
        mov rdi, %2
        mov eax, WRITE_SYS_DATA
        call sys_service_enter
%else
        REX.Wrxb
        mov esi, %1
        REX.Wrxb
        mov edi, %2
        mov eax, WRITE_SYS_DATA
        call sys_service_enter
%endif
%endmacro





;---------------------------------------
; SET_INTERNAL_SIGNAL
; input:
;       none
; output:
;       none
; 描述:
;       1) 置内部使用的信号有效（置位）
;---------------------------------------
%macro SET_INTERNAL_SIGNAL       0
        mov eax, SDA.Signal
        lock bts DWORD [fs: eax], 0
%endmacro



;---------------------------------------
; RELEASE_INTERNAL_SIGNAL
; input:
;       none
; output:
;       none
; 描述:
;       1) 置内部使用的信号无效（清位）
;---------------------------------------
%macro RELEASE_INTERNAL_SIGNAL     0
        mov eax, SDA.Signal
        lock btr DWORD [fs: eax], 0
%endmacro



;---------------------------------------
; WAIT_FOR_INTERNAL_SIGNAL
; input:
;       none
; output:
;       none
; 描述:
;       1) 等待内部信号有效
;---------------------------------------
%macro WAIT_FOR_INTERNAL_SIGNAL     0
%%0:
        mov eax, SDA.Signal
        lock btr DWORD [fs: eax], 0
        jc %%2
        
        ;;
        ;; 等待信号
        ;;
%%1:
        bt DWORD [fs: eax], 0
        jc %%0
        pause
        jmp %%1
%%2:        
%endmacro




;---------------------------------------
; ACQUIRE_SPIN_LOCK
; input:
;       %1 - 锁指针
; output:
;       none
; 描述:
;       1) 获得自旋锁
;---------------------------------------
%macro ACQUIRE_SPIN_LOCK        1
%%0:
        lock bts DWORD [%1], 0
        jnc %%2
        
        ;;
        ;; 检查锁是否开放
        ;;
%%1:
        bt DWORD [%1], 0
        jnc %%0
        pause
        jmp %%1
%%2:        
%endmacro



;---------------------------------------
; RELEASE_SPIN_LOCK
; input:
;       %1 - 锁指针
; output:
;       none
; 描述:
;       1) 获得自旋锁
;---------------------------------------
%macro RELEASE_SPIN_LOCK        1
        lock btr DWORD [%1], 0
%endmacro





;;
;;
;; 重定义函数名，目的是保持一致
;;

%ifdef __STAGE1
;;
;; 定义在 stage1 阶段使用
;;
%define clear_4k_page                                   clear_4k_page32
%define clear_4k_buffer                                 clear_4k_buffer32
%define clear_4k_page_n                                 clear_4k_page_n32
%define clear_4k_buffer_n                               clear_4k_buffer_n32
%define strlen                                          strlen32
%define zero_memory                                     zero_memory32
%define memcpy                                          memcpy32
%define delay_with_us                                   delay_with_us32
%define error_code_default_handler                      error_code_default_handler32
%define exception_default_handler                       exception_default_handler32
%define do_virtual_address_mapping                      do_virtual_address_mapping32
%define do_virtual_address_mapping_n                    do_virtual_address_mapping32_n
%define nmi_handler                                     nmi_handler32
%define exception_default_handler.@0                    exception_default_handler32.@0

%elifdef __X64

;;
;; 定义在 X64 下
;;
%define clear_4k_page                                   clear_4k_page64
%define clear_4k_buffer                                 clear_4k_buffer64
%define clear_4k_page_n                                 clear_4k_page_n64
%define clear_4k_buffer_n                               clear_4k_buffer_n64                             
%define strlen                                          strlen64
%define zero_memory                                     zero_memory64
%define memcpy                                          memcpy64
%define delay_with_us                                   delay_with_us64
%define error_code_default_handler                      error_code_default_handler64
%define exception_default_handler                       exception_default_handler64
%define install_kernel_interrupt_handler                install_kernel_interrupt_handler64
%define install_user_interrupt_handler                  install_user_interrupt_handler64
%define read_idt_descriptor                             read_idt_descriptor64
%define write_idt_descriptor                            write_idt_descriptor64
%define read_gdt_descriptor                             read_gdt_descriptor64
%define write_gdt_descriptor                            write_idt_descriptor64
%define setup_sysenter                                  setup_sysenter64
%define do_virtual_address_mapping                      do_virtual_address_mapping64
%define do_virtual_address_mapping_n                    do_virtual_address_mapping64_n
%define do_guest_physical_address_mapping               do_guest_physical_address_mapping64
%define do_guest_physical_address_mapping_n             do_guest_physical_address_mapping64_n
%define dump_ept_paging_structure                       dump_ept_paging_structure64
%define nmi_handler                                     nmi_handler64
%define exception_default_handler.@0                    exception_default_handler64.@0


%else

;;
;; 定义在 X86 下
;;
%define clear_4k_page                                   clear_4k_page32
%define clear_4k_buffer                                 clear_4k_buffer32
%define clear_4k_page_n                                 clear_4k_page_n32
%define clear_4k_buffer_n                               clear_4k_buffer_n32
%define strlen                                          strlen32
%define zero_memory                                     zero_memory32
%define memcpy                                          memcpy32
%define error_code_default_handler                      error_code_default_handler32
%define exception_default_handler                       exception_default_handler32
%define install_kernel_interrupt_handler                install_kernel_interrupt_handler32
%define install_user_interrupt_handler                  install_user_interrupt_handler32
%define read_idt_descriptor                             get_idt_descriptor
%define write_idt_descriptor                            set_idt_descriptor
%define read_gdt_descriptor                             get_gdt_descriptor
%define write_gdt_descriptor                            set_gdt_descriptor
%define setup_sysenter                                  setup_sysenter32
%define do_virtual_address_mapping                      do_virtual_address_mapping32
%define do_virtual_address_mapping_n                    do_virtual_address_mapping32_n
%define do_guest_physical_address_mapping               do_guest_physical_address_mapping32
%define do_guest_physical_address_mapping_n             do_guest_physical_address_mapping32_n
%define nmi_handler                                     nmi_handler32
%define exception_default_handler.@0                    exception_default_handler32.@0



%endif          ;; __STAGE1







%endif          ;; __LIBDEF_INC

