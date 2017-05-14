;*************************************************
; page32.asm                                     *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


%include "..\inc\page.inc"





        bits 32




;-------------------------------------------------------------
; clear_8m_for_pae(): �� 8M ����PAE ģʽʹ�õ�ҳת����
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
        ;; �� PDPT ��ַ������ 32 bytes ����
        ;;
        add ebx, 31
        and ebx, 0FFFFFFE0h

        ;;
        ;; ������ PDPT ����
        ;;
        mov eax, [fs: SDA.PdtPhysicalBase]                      ; PDT �������ַ
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
;  ����:
;       1) ���� stage2 �׶� PAE-paging ģʽ�µ� PPT ������ 
;-----------------------------------------------------------------
init_ppt_area:
        push ebx
        push edx
        push ecx
        
        xor edx, edx
        xor ecx, ecx        
        
        ;;
        ;; �� PPT ����д�� PDT ���ַ
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
;       esi - ҳת���������ַ
; output:
;       none
; ����:
;       1) ӳ��ҳת����ṹ����
;       2) ʹ�� 4K ҳ��
;-----------------------------------------------------------------
map_pae_page_transition_table:
        push ecx
        push ebx
        push edx
        
        ;;
        ;; �� PDT_BASE - PDT_TOP ����д��
        ;; 1) д�������ַ���� 800000h - 803fffh
        ;; 2) д��ֵ��200000h - A00000h
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
        ;; �� 8000_0000h - ffff_ffffh ������� supervisor Ȩ��
        ;;
        cmp ecx, 2000h / 8
        cmovae edx, esi
        add eax, 1000h
        cmp ecx, 4000h / 8
        jb map_pae_page_transition_table.loop
        
        
        ;;
        ;; �޸� c000_0000 - c07f_ffffh ������� XD Ȩ��
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
; init_pae_page(): ��ʼ������ PAE-paging ģʽ��ҳת����ṹ
; input:
;       none
; output:
;       none
; 
; ϵͳҳ��ṹ:
;       * 0xc0000000-0xc07fffff����8M��ӳ�䵽����ҳ�� 0x200000-0x9fffff �ϣ�ʹ�� 4K ҳ��
;
; ��ʼ����������:
;       1) 0x7000-0x1ffff �ֱ�ӳ�䵽 0x8000-0x1ffff ����ҳ�棬����һ�������
;       2) 0xb8000 - 0xb9fff ��ӳ�䵽��0xb8000-0xb9fff �����ַ��ʹ�� 4K ҳ�棬���� VGA ��ʾ����
;       3) 0x80000000-0x8000ffff����64K��ӳ�䵽�����ַ 0x100000-0x10ffff �ϣ�����ϵͳ���ݽṹ        
;       4) 0x400000-0x400fff ӳ�䵽 1000000h page frame ʹ�� 4K ҳ�棬���� DS store ����
;       5) 0x600000-0x7fffff ӳ�䵽 0FEC00000h ����ҳ���ϣ�ʹ�� 2M ҳ�棬���� LPC ����������I/O APIC��
;       6) 0x800000-0x9fffff ӳ�䵽 0FEE00000h �����ַ�ϣ�ʹ�� 2M ҳ�棬���� local APIC ����
;       7) 0xb0000000 ��ʼӳ�䵽�����ַ 0x1100000 ��ʼ��ʹ�� 4K ҳ�棬���� VMX ���ݿռ�

;
; ע�������Ƕ�̬ӳ������
;       1) 0x7fe00000 ��ʼӳ�䵽�����ַ 0x1010000 ��ʼ��ʹ�� 4K ҳ�棬���� user �� stack �ռ�
;       2) 0xffe00000 ��ʼӳ�䵽�����ַ 0x1020000 ��ʼ��ʹ�� 4K ҳ�棬���� kernel �� stack �ռ�
;---------------------------------------------------------------------------------------------

init_pae_page:
        push ecx
          
      
        ;;
        ;; ��ҳת��������(8M)
        ;;
        mov esi, [fs: SDA.PtPhysicalBase]
        call clear_8m_for_pae
        
        ;;
        ;; ӳ��8Mҳת��������ʹ�� 4K page��
        ;;
        call map_pae_page_transition_table
          
        ;;
        ;; 0x7000-0x9000 �ֱ�ӳ�䵽 0x7000-0x90000 ����ҳ��, ʹ�� 4K ҳ��               
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
        ;; ӳ�� protected ģ������ʹ�� 4K ҳ
        ;;
        mov esi, PROTECTED_SEGMENT
        mov edi, PROTECTED_SEGMENT
        mov eax, PHY_ADDR | US | RW | P
        
%ifdef __STAGE2
        mov ecx, (PROTECTED_LENGTH + 0FFFh) / 1000h
%endif        
        call do_virtual_address_mapping_n
        
        ;;
        ;; 0xb8000 - 0xb9fff ��ӳ�䵽��0xb8000-0xb9fff �����ַ��ʹ�� 4K ҳ��
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
        ;; ӳ�� System Data Area ����
        ;;
        mov esi, [fs: SDA.Base]                                 ; SDA virtual address
        mov edi, [fs: SDA.PhysicalBase]                         ; SDA physical address
        mov ecx, [fs: SDA.Size]                                 ; SDA size
        add ecx, [fs: SRT.Size]                                 ; ӳ�������С = SDA size + SRT size
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
        ;; ӳ�� System service routine table ����4K��
        ;;
        mov esi, [fs: SRT.Base]
        mov edi, [fs: SRT.PhysicalBase]
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        
       
        ;;
        ;; 0x400000-0x400fff ӳ�䵽 1000000h page frame ʹ�� 4K ҳ��
        ;;
        mov esi, 400000h
        mov edi, 1000000h
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        
        ;;              
        ;; 0x600000-0x600fff ӳ�䵽 0FEC00000h �����ַ�ϣ�ʹ�� 4K ҳ��
        ;;
        mov esi, IOAPIC_BASE
        mov edi, 0FEC00000h
        mov eax, XD | PHY_ADDR | PCD | PWT | RW | P
        call do_virtual_address_mapping
        
        ;;
        ;; 0x800000-0x800fff ӳ�䵽 0FEE00000h �����ַ�ϣ�ʹ�� 4k ҳ��
        ;;
        mov esi, LAPIC_BASE
        mov edi, 0FEE00000h
        mov eax, XD | PHY_ADDR | PCD | PWT | RW | P
        call do_virtual_address_mapping
           
        
        ;;
        ;; 0xb0000000 ��ʼӳ�䵽�����ַ 0x1100000 ��ʼ��ʹ�� 4K ҳ��
        ;;
        mov esi, VMX_REGION_VIRTUAL_BASE                        ; VMXON region virtual address
        mov edi, VMX_REGION_PHYSICAL_BASE                       ; VMXON region physical address
        mov eax, XD | PHY_ADDR | RW | P
        call do_virtual_address_mapping
        
        pop ecx
        ret
        
        
        
        


        
;-----------------------------------------------------------
; do_virtual_address_mapping32(): ִ�������ַӳ��
; input:
;       esi - virtual address
;       edi - physical address
;       eax - attribute
; output:
;       0 - succssful, ���򷵻ش�����
;
; desciption:
;       eax ���ݹ����� attribute �������־λ��ɣ�
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
;       [29] - FORCE����λʱ��ǿ�ƽ���ӳ��
;       [30] - PHYSICAL����λʱ����ʾ���������ַ����ӳ�䣨���ڳ�ʼ��ʱ��
;       [31] - XD
;----------------------------------------------------------
do_virtual_address_mapping32:
        push ecx
        push ebx
        push edx
        push ebp
        
        ;;
        ;; ��֤��ַ������ 4K �߽� 
        ;;
        and esi, 0FFFFF000h
        and edi, 0FFFFF000h
        
        push esi
        push edi
        

        
                
        ;;
        ;; PT_BASE - PT_TOP �����Ѿ���ʼ��ӳ�䣬�����ٽ���ӳ��
        ;; ����ӳ�䵽 PT_BASE - PT_TOP �����ھ�ʧ�ܷ���
        ;;
        cmp esi, [fs: SDA.PtBase]
        jb do_virtual_address_mapping32.next
        cmp esi, [fs: SDA.PtTop]
        ja do_virtual_address_mapping32.next

        mov eax, MAPPING_ADDRESS_INVALID
        jmp do_virtual_address_mapping32.done
        
do_virtual_address_mapping32.next:
        ;;
        ;; ����Ƿ���������ַ
        ;; ebx ��� get_pde_XXX ����
        ;; ebp ���� get_pte_XXX ����
        ;;
        test eax, PHY_ADDR                              ; physical address ��־λ
        mov ebx, get_pde_virtual_address
        mov ecx, get_pde_physical_address
        cmovnz ebx, ecx
        mov ebp, get_pte_virtual_address
        mov ecx, get_pte_physical_address
        cmovnz ebp, ecx
        
        ;;
        ;; �������� XD ��־λ
        ;; ��󣬺ϳ� XD ��־��ȡ�����Ƿ��� XD ����
        ;;
        mov edx, eax
        and edx, [fs: SDA.XdValue]                      ; �Ƿ��� XD ����
        mov ecx, eax
        
        ;;
        ;; ��ȡ PDE ���ַ
        ;;
        call ebx 
        mov ebx, eax
        
        test ecx, PS                                    ; PS == 1 ? ʹ�� 2M ҳӳ��
        jz do_virtual_address_mapping32.4k
        
        ;;
        ;; ����ʹ�� 2M ҳ����ӳ��
        ;;        
        and edi, 0FFE00000h                             ; ������ 2M ҳ�����ַ
        or di, cx                                       ; page frame ����
        and edi, 0FFE011FFh                             ; �� PDE �� [11:9] �� [20:13] λ

        mov eax, [ebx]
        test eax, P                                     ; ����Ƿ��Ѿ���ʹ����
        jz do_virtual_address_mapping32.2m.next           ; û��ʹ�õĻ���ֱ������
        test ecx, FORCE                                 ; ��� FORCE_PDE λ
        jnz do_virtual_address_mapping32.2m.next
              
        ;;
        ;; ����Ѿ���ʹ�ã���������Ƿ�һ�£���һ���򷵻ش����룺MAPPING_USED
        ;;
        xor eax, edi
        test eax, ~(60h)                                ; ���� D �� A ��־λ
        mov eax, MAPPING_USED
        jnz do_virtual_address_mapping32.done  
        mov eax, [ebx + 4]                              ; PDE �߰벿��
        xor eax, edx                                    ; ��� XD ��־λ
        mov eax, MAPPING_USED
        js do_virtual_address_mapping32.done              ; XD ��־λ����
               
do_virtual_address_mapping32.2m.next:        
        mov [ebx + 4], edx                              ; PDE �� 32 λ        
        mov [ebx], edi                                  ; PDE �� 32 λ
        mov eax, MAPPING_SUCCESS
        jmp do_virtual_address_mapping32.done
        
        
        ;;
        ;; ����ʹ�� 4K ҳӳ��
        ;;
do_virtual_address_mapping32.4k:               
        btr ecx, 12                                     ; ȡ PAT ��־λ
        setc dl
        shl dl, 7
        or cl, dl                                       ; �ϳ� PTE �� PAT ��־λ
        xor dl, dl
                       
        ;;
        ;; ��� PDE.P = 0 ʱ������ FORCE = 1ʱ��ֱ�����ã�������Ҫ��� PDE ����
        ;;
        mov eax, [ebx]
        test eax, P
        jz do_virtual_address_mapping32.4k.next
        test ecx, FORCE
        jnz do_virtual_address_mapping32.4k.next
        
        ;;
        ;; ��� PDE ����
        ;; 1) ��� PDE.PS = 1 ʱ�����س����룺MAPPING_PS_MISMATCH
        ;; 2) ��� PDE.R/W = 0��������� R/W = 1 ʱ�����س����룺MAPPING_RW_MISMATCH
        ;; 3) ��� PDE.U/S = 0��������� U/S = 1 ʱ�����س����룺MAPPING_US_MISMATCH
        ;; 4) ��� PDE.XD = 1��������� XD = 0 ʱ�����س����룺MAPPING_XD_MISMATCH
        ;;
        test eax, PS
        jz do_virtual_address_mapping32.4k.l1
        mov eax, MAPPING_PS_MISMATCH
        jmp do_virtual_address_mapping32.done
do_virtual_address_mapping32.4k.l1:         
        test eax, RW
        jnz do_virtual_address_mapping32.4k.l2            ; ��� PDE.R/W = 1 ʱ������
        test ecx, RW
        jz do_virtual_address_mapping32.4k.l2             ; ������� PDE.R/W = 0������
        mov eax, MAPPING_RW_MISMATCH                    ; PDE.R/W = 0���� page frame �� R/W = 1 ������
        jmp do_virtual_address_mapping32.done
do_virtual_address_mapping32.4k.l2:                 
        test eax, US
        jnz do_virtual_address_mapping32.4k.l3            ; ��� PDE.U/S = 1 ʱ������
        test ecx, US
        jz do_virtual_address_mapping32.4k.l3             ; ������� PDE.U/S = 0������
        mov eax, MAPPING_US_MISMATCH                    ; PDE.U/S = 0���� page frmae �� U/S = 1��������
        jmp do_virtual_address_mapping32.done
do_virtual_address_mapping32.4k.l3:        
        mov eax, [ebx + 4]
        test eax, XD
        jz do_virtual_address_mapping32.4k.next           ; ��� PDE.XD = 0������
        test edx, XD
        jnz do_virtual_address_mapping32.4k.pte           ; ������� PDE.XD = 1������ 
        mov eax, MAPPING_XD_MISMATCH
        jmp do_virtual_address_mapping32.done             ; PDE.XD = 1���� page frame �� XD = 0��������
        
do_virtual_address_mapping32.4k.next:        
        ;;
        ;; �õ� PT �������ַ
        ;;
        call get_pte_physical_address
        and eax, 0FFFFF000h                             ; ������ 4K ҳ�����ַ
        or al, cl
        and eax, 0FFFFF007h                             ; �� PTE �� [11:3] λ
                                                        ; PCD �� PWT λ������!
        
        ;;
        ;; ���ͨ������ PDE
        mov DWORD [ebx + 4], 0                          ; �� PDE �� 32 λ
        mov [ebx], eax                                  ; PDE �� 32 λ

do_virtual_address_mapping32.4k.pte:
        ;;
        ;; ���� PTE

        call ebp                                        ; �õ� pte ��ַ
        mov [eax + 4], edx
        or di, cx
        and edi, 0FFFFF1FFh                             ; �� PTE �� [11:9] λ       
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
;       ecx - n ��ҳ��
; output:
;       0 - succssful, ���򷵻ش�����
; ������
;       1) ӳ�� n �� ҳ��
;-----------------------------------------------------------
do_virtual_address_mapping32_n:
        push ebp
        push ebx
        push ecx
        push edx
        
        ;;
        ;; ��� page attribute��
        ;; 1) 4K ҳʱ��ʹ�� 4K ����
        ;; 2) 2M ҳʱ��ʹ�� 2M ����
        ;;
        mov edx, 1000h                          ; 4K ҳ
        mov ebp, 200000h                        ; 2M ҳ
        test eax, PAGE_2M                       ; ��� PS λ
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
;       edx:eax - ����ҳ�棬ʧ��ʱ������ -1
; ������
;       1) ��ѯ�����ַӳ�������ҳ��
;       2) �������ַ��ӳ��ҳ��ʱ������ -1 ֵ
;-----------------------------------------------------------
query_physical_page:
        push ebx
        push edx
        
        ;;
        ;; ˵����
        ;; 1) �ȼ�� PDE �����Ƿ�Ϊ valid���Ƿ����� 2M ҳ��
        ;; 2) �� 2M ҳ��ʱ����� PTE ��Ƿ�Ϊ��Ч����Чʱ���� -1 ֵ
        ;; 3) ��Чʱ���� 4K ����ҳ��
        ;;
        
        ;;
        ;; �� PDE ֵ
        ;;
        mov ebx, esi
        call get_pde_virtual_address
        mov edx, [eax + 4]
        mov eax, [eax]
        mov esi, -1
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
        
        ;;
        ;; ��� PDE �Ƿ���Ч
        ;;
        test eax, P                                     ; ��� P λ
        cmovz edx, esi
        cmovz eax, esi
        jz query_physical_page.done
        
        ;;
        ;; ����Ƿ� 2M ҳ��
        ;;
        test eax, PS                                    ; ��� PS λ
        jnz query_physical_page.ok
        
        ;;
        ;; �� PTE ֵ
        ;;
        mov esi, ebx
        call get_pte_virtual_address
        mov edx, [eax + 4]
        mov eax, [eax]
        mov esi, -1
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
        
        ;;
        ;; ��� PTE �Ƿ���Ч
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
; do_virtual_address_unmapped(): ��������ַӳ��
; input:
;       esi - virtual address
; output:
;       0 - successful,  otherwise - error code
;-----------------------------------------------------------
do_virtual_address_unmapped:
        push ecx
        ;;
        ;; PT_BASE - PT_TOP �����ܱ����ӳ��
        ;; ����ӳ�䵽 PT_BASE - PT_TOP �����ھ�ʧ�ܷ���
        ;;
        cmp esi, [fs: SDA.PtBase]
        jb do_virtual_address_unmapped.next
        cmp esi, [fs: SDA.PtTop]
        ja do_virtual_address_unmapped.next 
        mov eax, UNMAPPING_ADDRESS_INVALID
        jmp do_virtual_address_unmapped.done
        
do_virtual_address_unmapped.next:    
        ;;
        ;; ����Ƿ�Ϊ 2M ҳ��
        ;;       
        call get_pde_virtual_address
        mov ecx, [eax]
        test ecx, PS
        jnz do_virtual_address_unmapped.go_ahead

        ;;
        ;; ���� 4K ҳӳ��
        call get_pte_virtual_address
        mov ecx, [eax]
        
do_virtual_address_unmapped.go_ahead:        
        btr ecx, 0                                      ; �� P λ
        xchg [eax], ecx
        invlpg [esi]                                    ; ˢ�� TLB
        mov eax, UNMAPPED_SUCCESS        
        
do_virtual_address_unmapped.done:
        pop ecx
        ret
                



        

