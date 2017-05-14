;*************************************************
; page32.asm                                     *
; Copyright (c) 2009-2013 邓志                   *
; All rights reserved.                           *
;*************************************************


%include "..\inc\page.inc"





        bits 32




;-------------------------------------------------------------
; clear_8m_for_pae(): 清 8M 区域（PAE 模式使用的页转换表）
; input:
;       esi - address
;-------------------------------------------------------------
clear_8m_for_pae:
        push ecx
        mov ecx, (8 * 1024 * 1024) / 4096
clear_8m_for_pae.loop:        
        call clear_4k_buffer
        add esi, 4096
        dec ecx
        jnz clear_8m_for_pae.loop
        pop ecx
        ret
        
        
;--------------------------------------------------
; get_pte_offset()
; input:
;       esi - virutal address or physical address
; output:
;       eax - pte address offset
;-------------------------------------------------- 
get_pte_offset:
        mov eax, esi
        shr eax, 12                             ; get pte index
        shl eax, 3                              ; pte index * 8
        ret
        
;--------------------------------------------------
; get_pte_virtual_address()
; input:
;       esi - virutal address
; output:
;       eax - virtual address of pte address
;--------------------------------------------------        
get_pte_virtual_address:
        call get_pte_offset
        add eax, [fs: SDA.PtBase]
        ret

;--------------------------------------------------
; get_pte_physical_address()
; input:
;       esi - physical address
; output:
;       eax - physical address of pte address
;--------------------------------------------------        
get_pte_physical_address:
        call get_pte_offset
        add eax, [fs: SDA.PtPhysicalBase]
        ret


;--------------------------------------------------
; get_pde_offset()
; input:
;       esi - virutal address or physical address
; output:
;       eax - pde address offset
;-------------------------------------------------- 
get_pde_offset:
        mov eax, esi
        shr eax, 21                             ; get pde index
        shl eax, 3                              ; pde index * 8
        ret

;--------------------------------------------------
; get_pde_virtual_address()
; input:
;       esi - virutal address or physical address
; output:
;       eax - virutal address of pde address
;--------------------------------------------------
get_pde_virtual_address:
        call get_pde_offset
        add eax, [fs: SDA.PdtBase]
        ret

;--------------------------------------------------
; get_pde_physical_address()
; input:
;       esi - physical address
; output:
;       eax - physical address of pde address
;--------------------------------------------------        
get_pde_physical_address:
        call get_pde_offset
        add eax, [fs: SDA.PdtPhysicalBase]
        ret
        

;-------------------------------------------------------------------
; load_pdpt()
; input:
;       esi - physical address of PDPT(page directory pointer table)
; output:
;       eax - pde address
;------------------------------------------------------------------
load_pdpt:
        push ecx
        push ebx
        mov ebx, esi
        xor ecx, ecx

        ;;
        ;; 将 PDPT 地址调整到 32 bytes 对齐
        ;;
        add ebx, 31
        and ebx, 0FFFFFFE0h

        ;;
        ;; 保存在 PDPT 表里
        ;;
        mov eax, [fs: SDA.PdtPhysicalBase]                      ; PDT 表物理地址
        and eax, 0FFFFF000h
        or eax, P                                               ; PDPTE0
        mov [ebx], eax
        add eax, 1000h                                          ; PDPTE1
        mov [ebx + 4], ecx
        mov [ebx + 8], eax
        add eax, 1000h                                          ; PDPTE2
        mov [ebx + 8 + 4], ecx
        mov [ebx + 16], eax
        add eax, 1000h                                          ; PDPTE3       
        mov [ebx + 16 + 4], ecx
        mov [ebx + 24], eax
        mov [ebx + 24 + 4], ecx
        mov cr3, ebx
        pop ebx
        pop ecx
        ret


;-----------------------------------------------------------------
; init_ppt_area()
; input:
;       none
; output:
;       none
;  描述:
;       1) 设置 stage2 阶段 PAE-paging 模式下的 PPT 表区域 
;-----------------------------------------------------------------
init_ppt_area:
        push ebx
        push edx
        push ecx
        
        xor edx, edx
        xor ecx, ecx        
        
        ;;
        ;; 在 PPT 表里写入 PDT 表基址
        ;;
        mov ebx, [fs: SDA.PptPhysicalBase]
        mov eax, [fs: SDA.PdtPhysicalBase]
        or eax, P

init_ppt_area.loop:        
        mov [ebx + ecx * 8], eax
        mov [ebx + ecx * 8 + 4], edx
        inc ecx
        add eax, 1000h
        cmp ecx, 4
        jb init_ppt_area.loop
        
        pop ecx
        pop edx
        pop ebx
        ret


;-----------------------------------------------------------------
; map_pae_page_transition_table()
; input:
;       esi - 页转换表虚拟地址
; output:
;       none
; 描述:
;       1) 映射页转换表结构区域
;       2) 使用 4K 页面
;-----------------------------------------------------------------
map_pae_page_transition_table:
        push ecx
        push ebx
        push edx
        
        ;;
        ;; 向 PDT_BASE - PDT_TOP 区域写入
        ;; 1) 写入物理地址区域 800000h - 803fffh
        ;; 2) 写入值：200000h - A00000h
        ;;
        mov ebx, [fs: SDA.PdtPhysicalBase]
        mov eax, [fs: SDA.PtPhysicalBase]
        xor ecx, ecx
        mov esi, RW | P
        mov edx, US | RW | P
map_pae_page_transition_table.loop:
        and eax, 0FFFFF000h
        or eax, edx
        mov [ebx + ecx * 8], eax
        mov DWORD [ebx + ecx * 8 + 4], 0
        inc ecx
        
        ;;
        ;; 在 8000_0000h - ffff_ffffh 区域具有 supervisor 权限
        ;;
        cmp ecx, 2000h / 8
        cmovae edx, esi
        add eax, 1000h
        cmp ecx, 4000h / 8
        jb map_pae_page_transition_table.loop
        
        
        ;;
        ;; 修改 c000_0000 - c07f_ffffh 区域具有 XD 权限
        ;;
        mov esi, [fs: SDA.PtBase]
        call get_pde_physical_address
        mov ebx, eax
        mov ecx, 3
        mov edx, [fs: SDA.XdValue]
        
map_pae_page_transition_table.loop2:        
        mov [ebx + ecx * 8 + 4], edx
        dec ecx
        jge map_pae_page_transition_table.loop2
        
        pop edx
        pop ebx
        pop ecx
        ret
        
        

;----------------------------------------------------------------------------------------------
; init_pae_page(): 初始化设置 PAE-paging 模式的页转换表结构
; input:
;       none
; output:
;       none
; 
; 系统页表结构:
;       * 0xc0000000-0xc07fffff（共8M）映射到物理页面 0x200000-0x9fffff 上，使用 4K 页面
;
; 初始化区域描述:
;       1) 0x7000-0x1ffff 分别映射到 0x8000-0x1ffff 物理页面，用于一般的运作
;       2) 0xb8000 - 0xb9fff 分映射到　0xb8000-0xb9fff 物理地址，使用 4K 页面，用于 VGA 显示区域
;       3) 0x80000000-0x8000ffff（共64K）映射到物理地址 0x100000-0x10ffff 上，用于系统数据结构        
;       4) 0x400000-0x400fff 映射到 1000000h page frame 使用 4K 页面，用于 DS store 区域
;       5) 0x600000-0x7fffff 映射到 0FEC00000h 物理页面上，使用 2M 页面，用于 LPC 控制器区域（I/O APIC）
;       6) 0x800000-0x9fffff 映射到 0FEE00000h 物理地址上，使用 2M 页面，用于 local APIC 区域
;       7) 0xb0000000 开始映射到物理地址 0x1100000 开始，使用 4K 页面，用于 VMX 数据空间

;
; 注，下面是动态映射区域：
;       1) 0x7fe00000 开始映射到物理地址 0x1010000 开始，使用 4K 页面，用于 user 的 stack 空间
;       2) 0xffe00000 开始映射到物理地址 0x1020000 开始，使用 4K 页面，用于 kernel 的 stack 空间
;---------------------------------------------------------------------------------------------

init_pae_page:
        push ecx
          
      
        ;;
        ;; 清页转换表区域(8M)
        ;;
        mov esi, [fs: SDA.PtPhysicalBase]
        call clear_8m_for_pae
        
        ;;
        ;; 映射8M页转换表区域（使用 4K page）
        ;;
        call map_pae_page_transition_table
          
        ;;
        ;; 0x7000-0x9000 分别映射到 0x7000-0x90000 物理页面, 使用 4K 页面               
        ;;
        mov esi, 7000h
        mov edi, 7000h
        mov ecx, (10000h - 7000h) / 1000h        
do_virtual_address_mapping.loop1:        
        mov eax, PHY_ADDR | US | RW | P
        call do_virtual_address_mapping
        add esi, 1000h
        add edi, 1000h
        dec ecx
        jnz do_virtual_address_mapping.loop1

%ifdef GUEST_ENABLE        
        mov esi, GUEST_BOOT_SEGMENT
        mov edi, GUEST_BOOT_SEGMENT
        mov eax, PHY_ADDR | US | RW | P
        call do_virtual_address_mapping
        
        mov esi, GUEST_KERNEL_SEGMENT
        mov edi, GUEST_KERNEL_SEGMENT
        mov eax, PHY_ADDR | US | RW | P
        mov ecx, [GUEST_KERNEL_SEGMENT]        
        add ecx, 0FFFh
        shr ecx, 12
        call do_virtual_address_mapping_n
%endif        
        
        ;;
        ;; 映射 protected 模块区域，使用 4K 页
        ;;
        mov esi, PROTECTED_SEGMENT
        mov edi, PROTECTED_SEGMENT
        mov eax, PHY_ADDR | US | RW | P
        
%ifdef __STAGE2
        mov ecx, (PROTECTED_LENGTH + 0FFFh) / 1000h
%endif        
        call do_virtual_address_mapping_n
        
        ;;
        ;; 0xb8000 - 0xb9fff 分映射到　0xb8000-0xb9fff 物理地址，使用 4K 页面
        ;;
        mov esi, 0B8000h
        mov edi, 0B8000h
        mov eax, XD | PHY_ADDR | US | RW | P
        call do_virtual_address_mapping
        mov esi, 0B9000h
        mov edi, 0B9000h
        mov eax, XD | PHY_ADDR | US | RW | P
        call do_virtual_address_mapping

        ;;
        ;; 映射 System Data Area 区域
        ;;
        mov esi, [fs: SDA.Base]                                 ; SDA virtual address
        mov edi, [fs: SDA.PhysicalBase]                         ; SDA physical address
        mov ecx, [fs: SDA.Size]                                 ; SDA size
        add ecx, [fs: SRT.Size]                                 ; 映射区域大小 = SDA size + SRT size
        add ecx, 0FFFh
        shr ecx, 12                                             
do_virtual_address_mapping.loop2:        
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        add esi, 1000h
        add edi, 1000h
        dec ecx
        jnz do_virtual_address_mapping.loop2
       
        
        ;;
        ;; 映射 System service routine table 区域（4K）
        ;;
        mov esi, [fs: SRT.Base]
        mov edi, [fs: SRT.PhysicalBase]
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        
       
        ;;
        ;; 0x400000-0x400fff 映射到 1000000h page frame 使用 4K 页面
        ;;
        mov esi, 400000h
        mov edi, 1000000h
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        
        ;;              
        ;; 0x600000-0x600fff 映射到 0FEC00000h 物理地址上，使用 4K 页面
        ;;
        mov esi, IOAPIC_BASE
        mov edi, 0FEC00000h
        mov eax, XD | PHY_ADDR | PCD | PWT | RW | P
        call do_virtual_address_mapping
        
        ;;
        ;; 0x800000-0x800fff 映射到 0FEE00000h 物理地址上，使用 4k 页面
        ;;
        mov esi, LAPIC_BASE
        mov edi, 0FEE00000h
        mov eax, XD | PHY_ADDR | PCD | PWT | RW | P
        call do_virtual_address_mapping
           
        
        ;;
        ;; 0xb0000000 开始映射到物理地址 0x1100000 开始，使用 4K 页面
        ;;
        mov esi, VMX_REGION_VIRTUAL_BASE                        ; VMXON region virtual address
        mov edi, VMX_REGION_PHYSICAL_BASE                       ; VMXON region physical address
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        
        pop ecx
        ret
        
        
        
        


        
;-----------------------------------------------------------
; do_virtual_address_mapping32(): 执行虚拟地址映射
; input:
;       esi - virtual address
;       edi - physical address
;       eax - attribute
; output:
;       0 - succssful, 否则返回错误码
;
; desciption:
;       eax 传递过来的 attribute 由下面标志位组成：
;       [0] - P
;       [1] - R/W
;       [2] - U/S
;       [3] - PWT
;       [4] - PCD
;       [5] - A
;       [6] - D
;       [7] - PS
;       [8] - G
;       [12] - PAT
;       [28] - INGORE
;       [29] - FORCE，置位时，强制进行映射
;       [30] - PHYSICAL，置位时，表示基于物理地址进行映射（用于初始化时）
;       [31] - XD
;----------------------------------------------------------
do_virtual_address_mapping32:
        push ecx
        push ebx
        push edx
        push ebp
        
        ;;
        ;; 保证地址对齐在 4K 边界 
        ;;
        and esi, 0FFFFF000h
        and edi, 0FFFFF000h
        
        push esi
        push edi
        

        
                
        ;;
        ;; PT_BASE - PT_TOP 区域已经初始化映射，不能再进行映射
        ;; 假如映射到 PT_BASE - PT_TOP 区域内就失败返回
        ;;
        cmp esi, [fs: SDA.PtBase]
        jb do_virtual_address_mapping32.next
        cmp esi, [fs: SDA.PtTop]
        ja do_virtual_address_mapping32.next

        mov eax, MAPPING_ADDRESS_INVALID
        jmp do_virtual_address_mapping32.done
        
do_virtual_address_mapping32.next:
        ;;
        ;; 检查是否基于物理地址
        ;; ebx 存放 get_pde_XXX 函数
        ;; ebp 存入 get_pte_XXX 函数
        ;;
        test eax, PHY_ADDR                              ; physical address 标志位
        mov ebx, get_pde_virtual_address
        mov ecx, get_pde_physical_address
        cmovnz ebx, ecx
        mov ebp, get_pte_virtual_address
        mov ecx, get_pte_physical_address
        cmovnz ebp, ecx
        
        ;;
        ;; 获得输入的 XD 标志位
        ;; 最后，合成 XD 标志，取决于是否开启 XD 功能
        ;;
        mov edx, eax
        and edx, [fs: SDA.XdValue]                      ; 是否开启 XD 功能
        mov ecx, eax
        
        ;;
        ;; 读取 PDE 项地址
        ;;
        call ebx 
        mov ebx, eax
        
        test ecx, PS                                    ; PS == 1 ? 使用 2M 页映射
        jz do_virtual_address_mapping32.4k
        
        ;;
        ;; 下面使用 2M 页进行映射
        ;;        
        and edi, 0FFE00000h                             ; 调整到 2M 页物理地址
        or di, cx                                       ; page frame 属性
        and edi, 0FFE011FFh                             ; 清 PDE 的 [11:9] 和 [20:13] 位

        mov eax, [ebx]
        test eax, P                                     ; 检查是否已经在使用中
        jz do_virtual_address_mapping32.2m.next           ; 没有使用的话，直接设置
        test ecx, FORCE                                 ; 检查 FORCE_PDE 位
        jnz do_virtual_address_mapping32.2m.next
              
        ;;
        ;; 如果已经在使用，检测内容是否一致，不一致则返回错误码：MAPPING_USED
        ;;
        xor eax, edi
        test eax, ~(60h)                                ; 忽略 D 和 A 标志位
        mov eax, MAPPING_USED
        jnz do_virtual_address_mapping32.done  
        mov eax, [ebx + 4]                              ; PDE 高半部分
        xor eax, edx                                    ; 检查 XD 标志位
        mov eax, MAPPING_USED
        js do_virtual_address_mapping32.done              ; XD 标志位不符
               
do_virtual_address_mapping32.2m.next:        
        mov [ebx + 4], edx                              ; PDE 高 32 位        
        mov [ebx], edi                                  ; PDE 低 32 位
        mov eax, MAPPING_SUCCESS
        jmp do_virtual_address_mapping32.done
        
        
        ;;
        ;; 下面使用 4K 页映射
        ;;
do_virtual_address_mapping32.4k:               
        btr ecx, 12                                     ; 取 PAT 标志位
        setc dl
        shl dl, 7
        or cl, dl                                       ; 合成 PTE 的 PAT 标志位
        xor dl, dl
                       
        ;;
        ;; 如果 PDE.P = 0 时，或者 FORCE = 1时，直接设置，否则需要检查 PDE 内容
        ;;
        mov eax, [ebx]
        test eax, P
        jz do_virtual_address_mapping32.4k.next
        test ecx, FORCE
        jnz do_virtual_address_mapping32.4k.next
        
        ;;
        ;; 检查 PDE 内容
        ;; 1) 如果 PDE.PS = 1 时，返回出错码：MAPPING_PS_MISMATCH
        ;; 2) 如果 PDE.R/W = 0，而输入的 R/W = 1 时，返回出错码：MAPPING_RW_MISMATCH
        ;; 3) 如果 PDE.U/S = 0，而输入的 U/S = 1 时，返回出错码：MAPPING_US_MISMATCH
        ;; 4) 如果 PDE.XD = 1，而输入的 XD = 0 时，返回出错码：MAPPING_XD_MISMATCH
        ;;
        test eax, PS
        jz do_virtual_address_mapping32.4k.l1
        mov eax, MAPPING_PS_MISMATCH
        jmp do_virtual_address_mapping32.done
do_virtual_address_mapping32.4k.l1:         
        test eax, RW
        jnz do_virtual_address_mapping32.4k.l2            ; 如果 PDE.R/W = 1 时，忽略
        test ecx, RW
        jz do_virtual_address_mapping32.4k.l2             ; 如果输入 PDE.R/W = 0，忽略
        mov eax, MAPPING_RW_MISMATCH                    ; PDE.R/W = 0，但 page frame 的 R/W = 1 出错返回
        jmp do_virtual_address_mapping32.done
do_virtual_address_mapping32.4k.l2:                 
        test eax, US
        jnz do_virtual_address_mapping32.4k.l3            ; 如果 PDE.U/S = 1 时，忽略
        test ecx, US
        jz do_virtual_address_mapping32.4k.l3             ; 如果输入 PDE.U/S = 0，忽略
        mov eax, MAPPING_US_MISMATCH                    ; PDE.U/S = 0，但 page frmae 的 U/S = 1，出错返回
        jmp do_virtual_address_mapping32.done
do_virtual_address_mapping32.4k.l3:        
        mov eax, [ebx + 4]
        test eax, XD
        jz do_virtual_address_mapping32.4k.next           ; 如果 PDE.XD = 0，忽略
        test edx, XD
        jnz do_virtual_address_mapping32.4k.pte           ; 如果输入 PDE.XD = 1，忽略 
        mov eax, MAPPING_XD_MISMATCH
        jmp do_virtual_address_mapping32.done             ; PDE.XD = 1，但 page frame 的 XD = 0，出错返回
        
do_virtual_address_mapping32.4k.next:        
        ;;
        ;; 得到 PT 表物理地址
        ;;
        call get_pte_physical_address
        and eax, 0FFFFF000h                             ; 调整到 4K 页物理地址
        or al, cl
        and eax, 0FFFFF007h                             ; 清 PTE 的 [11:3] 位
                                                        ; PCD 和 PWT 位不设置!
        
        ;;
        ;; 检查通过设置 PDE
        mov DWORD [ebx + 4], 0                          ; 清 PDE 高 32 位
        mov [ebx], eax                                  ; PDE 低 32 位

do_virtual_address_mapping32.4k.pte:
        ;;
        ;; 设置 PTE

        call ebp                                        ; 得到 pte 地址
        mov [eax + 4], edx
        or di, cx
        and edi, 0FFFFF1FFh                             ; 清 PTE 的 [11:9] 位       
        mov [eax], edi
        mov eax, MAPPING_SUCCESS
do_virtual_address_mapping32.done:
        pop edi
        pop esi
        pop ebp
        pop edx
        pop ebx
        pop ecx
        ret



;-----------------------------------------------------------
; do_virtual_address_mapping32_n()
; input:
;       esi - virtual address
;       edi - physical address
;       eax - attribute
;       ecx - n 个页面
; output:
;       0 - succssful, 否则返回错误码
; 描述：
;       1) 映射 n 个 页面
;-----------------------------------------------------------
do_virtual_address_mapping32_n:
        push ebp
        push ebx
        push ecx
        push edx
        
        ;;
        ;; 检查 page attribute：
        ;; 1) 4K 页时，使用 4K 增量
        ;; 2) 2M 页时，使用 2M 增量
        ;;
        mov edx, 1000h                          ; 4K 页
        mov ebp, 200000h                        ; 2M 页
        test eax, PAGE_2M                       ; 检查 PS 位
        cmovz ebp, edx
        
        mov edx, eax
do_virtual_address_mapping32_n.loop:        
        mov eax, edx
        call do_virtual_address_mapping32
        add esi, ebp
        add edi, ebp
        dec ecx
        jnz do_virtual_address_mapping32_n.loop
        
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret



        

;-----------------------------------------------------------
; query_physical_page()
; input:
;       esi - va
; output:
;       edx:eax - 物理页面，失败时，返回 -1
; 描述：
;       1) 查询虚拟地址映射的物理页面
;       2) 当虚拟地址无映射页面时，返回 -1 值
;-----------------------------------------------------------
query_physical_page:
        push ebx
        push edx
        
        ;;
        ;; 说明：
        ;; 1) 先检查 PDE 项，检查是否为 valid，是否属于 2M 页面
        ;; 2) 非 2M 页面时，检查 PTE 项，是否为有效，无效时返回 -1 值
        ;; 3) 有效时返回 4K 物理页面
        ;;
        
        ;;
        ;; 读 PDE 值
        ;;
        mov ebx, esi
        call get_pde_virtual_address
        mov edx, [eax + 4]
        mov eax, [eax]
        mov esi, -1
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
        
        ;;
        ;; 检查 PDE 是否有效
        ;;
        test eax, P                                     ; 检查 P 位
        cmovz edx, esi
        cmovz eax, esi
        jz query_physical_page.done
        
        ;;
        ;; 检查是否 2M 页面
        ;;
        test eax, PS                                    ; 检查 PS 位
        jnz query_physical_page.ok
        
        ;;
        ;; 读 PTE 值
        ;;
        mov esi, ebx
        call get_pte_virtual_address
        mov edx, [eax + 4]
        mov eax, [eax]
        mov esi, -1
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
        
        ;;
        ;; 检查 PTE 是否有效
        ;;
        test eax, P
        cmovz edx, esi
        cmovz eax, esi
        jz query_physical_page.done
        
query_physical_page.ok:
        and eax, 0FFFFF000h
        
query_physical_page.done:        
        pop edx
        pop ebx
        ret        
        
        


;-----------------------------------------------------------
; do_virtual_address_unmapped(): 解除虚拟地址映射
; input:
;       esi - virtual address
; output:
;       0 - successful,  otherwise - error code
;-----------------------------------------------------------
do_virtual_address_unmapped:
        push ecx
        ;;
        ;; PT_BASE - PT_TOP 区域不能被解除映射
        ;; 假如映射到 PT_BASE - PT_TOP 区域内就失败返回
        ;;
        cmp esi, [fs: SDA.PtBase]
        jb do_virtual_address_unmapped.next
        cmp esi, [fs: SDA.PtTop]
        ja do_virtual_address_unmapped.next 
        mov eax, UNMAPPING_ADDRESS_INVALID
        jmp do_virtual_address_unmapped.done
        
do_virtual_address_unmapped.next:    
        ;;
        ;; 检查是否为 2M 页面
        ;;       
        call get_pde_virtual_address
        mov ecx, [eax]
        test ecx, PS
        jnz do_virtual_address_unmapped.go_ahead

        ;;
        ;; 属于 4K 页映射
        call get_pte_virtual_address
        mov ecx, [eax]
        
do_virtual_address_unmapped.go_ahead:        
        btr ecx, 0                                      ; 清 P 位
        xchg [eax], ecx
        invlpg [esi]                                    ; 刷新 TLB
        mov eax, UNMAPPED_SUCCESS        
        
do_virtual_address_unmapped.done:
        pop ecx
        ret
                



        

