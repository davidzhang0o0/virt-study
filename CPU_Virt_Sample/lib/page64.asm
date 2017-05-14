;*************************************************
; page64.asm                                     *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************



%include "..\inc\page.inc"



;;
;; page64 ģ��˵����
;; 1) page64 ģ�����ǰ�벿��Ϊ legacy �µ� 32 λ��д����δ���� long mode ֮ǰʹ��
;; 2) ��벿��Ϊ 64-bit �����д���ڽ��� 64-bit ������ʹ��
;; 3) legacy �����׺ʹ�� "32"��64-bit �����׺ʹ�� "64"
;;





;;
;; ���� page table entry ��־λ����Ӧ entry[11:9]
;;

PTE_INVALID                     EQU             0
PTE_VALID                       EQU             800h

;;
;; pte �����Ч�Ա�־��PTE_VALID | P)
;;
VALID_FLAGS                     EQU             801h



        bits 32

        

;---------------------------------------------------------------
; clear_2m_for_longmode_ppt()
; input:
;       none
; output:
;       none
; ע�⣺
;       1) �ڳ�ʼ��ҳת����ṹǰ����
;       2) �� legacy ģʽ��ִ��
;       3) �� init_longmode_basic_page() �ڲ�ʹ��
;---------------------------------------------------------------
clear_2m_for_longmode_ppt:
        push ecx
        ;;
        ;; �� PPT �����򣬹� 2M �ռ�
        ;;
        mov esi, [fs: SDA.PptPhysicalBase64]
        mov edi, 200000h / 1000h
        call clear_4k_page_n32
        pop ecx
        ret




;---------------------------------------------------------------
; get_pt_physical_base()
; intput:
;       none
; output:
;       edx:eax - physical address of PT 
; ������
;       1) �� PT Pool �����һ�� 4K ������飬��Ϊ PT �� PDT��
;       2) �˺����� legacy ģʽ��ʹ��
;---------------------------------------------------------------
get_pt_physical_base32:
        push ebx  
        ;;
        ;; �� PtPoolPhysicalBase ������� PT �����ַ
        ;; 1) ���ڴ��� stage1 �׶Σ�ʹ��PtPool�����ַ
        ;;    
        mov esi, SDA_PHYSICAL_BASE + SDA.PtPoolPhysicalBase
        xor edx, edx                                            ; ��������Ϊ 4K
        mov eax, 4096
        call locked_xadd64                                      ; edx:eax = Pt pool address
        mov ebx, eax
        mov esi, eax
        call clear_4k_page32                                    ; �������
        mov eax, ebx
        pop ebx
        ret



        
        
;---------------------------------------------------------------
; get_pte_virtual_address():
; input:
;       edx:eax - virtual address
; output:
;       edx:eax - PTE address
; ������
;       �� legacy ģʽ��ʹ��
;---------------------------------------------------------------
get_pte_virutal_address32:
        push ecx
        push ebx
        
        and edx, 0FFFFh                                         ; ���ַ�� 16 λ
        and eax, 0FFFFF000h                                     ; ���ַ�� 12 λ

        ;;
        ;; offset = va >> 12 * 8
        ;;
        mov ecx, (12 - 3)
        call shr64
        
        ;;
        ;; offset + PtBase64
        ;;
        mov ecx, [fs: SDA.PtBase64 + 4]
        mov ebx, [fs: SDA.PtBase64]
        call addition64
        
        pop ebx
        pop ecx
        ret
        


;---------------------------------------------------------------
; get_pxe_offset32():
; input:
;       edx:eax - va
; output:
;       edx:eax - offset
; ������
;       �õ� PXT entry �� offset ֵ
; ע�⣺
;       �� legacy ģʽ��ʹ��
;---------------------------------------------------------------
get_pxe_offset32:
        push ecx
        and edx, 0FFFFh                                         ; �� va �� 16 λ
        mov ecx, (12 + 9 + 9 + 9)                               ; index = va >> 39
        call shr64
        mov ecx, 3
        call shl64                                              ; offset = index << 3
        pop ecx
        ret

;---------------------------------------------------------------
; get_ppe_offset32():
; input:
;       edx:eax - va
; output:
;       edx:eax - offset
; ������
;       �õ� PPT entry �� offset ֵ
;       �� legacy ��ʹ��
;---------------------------------------------------------------
get_ppe_offset32:
        push ecx
        and edx, 0FFFFh                                         ; �� va �� 16 λ
        mov ecx, (12 + 9 + 9)                                   ; index = va >> 30
        call shr64
        mov ecx, 3
        call shl64                                              ; offset = index << 3
        pop ecx
        ret

        


;---------------------------------------------------------------
; get_pde_offset32():
; input:
;       edx:eax - va
; output:
;       edx:eax - offset
; ������
;       �õ� PDT entry �� offset ֵ
;       �� legacy ��ʹ��
;---------------------------------------------------------------
get_pde_offset32:
        push ecx
        and edx, 0FFFFh                                         ; �� va �� 16 λ
        mov ecx, (12 + 9)                                       ; index = va >> 21
        call shr64
        mov ecx, 3
        call shl64                                              ; offset = index << 3
        pop ecx
        ret

;---------------------------------------------------------------
; get_pde_index()
; input:
;       edx:eax - va
; output:
;       eax - index
; ������
;       1) �� legacy ��ʹ��
;---------------------------------------------------------------
get_pde_index32:
        shr eax, (12 + 9)
        and eax, 1FFh
        shl eax, 3                                              ; (va & PDE_MASK) >> 21 << 3
        ret




;---------------------------------------------------------------
; get_pte_offset32():
; input:
;       edx:eax - va
; output:
;       edx:eax - offset
; ������
;       �õ� PT entry �� offset ֵ
;       �� legacy ��ʹ��
;---------------------------------------------------------------
get_pte_offset32:
        push ecx
        and edx, 0FFFFh                                         ; �� va �� 16 λ
        and eax, 0FFFFF000h                                     ; �� va �� 12 λ
        mov ecx, 12 - 3                                         ; va >> 12 << 3
        call shr64
        pop ecx
        ret

;---------------------------------------------------------------
; get_pte_index32()
; input:
;       edx:eax - va
; output:
;       eax - index
; ������
;       1) �� legacy ��ʹ��
;---------------------------------------------------------------
get_pte_index32:
        shr eax, 12
        and eax, 1FFh
        shl eax, 3                                              ; (va & PTE_MASK) >> 12 << 3
        ret




        
        
        
;---------------------------------------------------------------
; map_longmode_page_transition_table32()
; input:
;       none
; output:
;       none
; ������
;       1) �˺�������ӳ�� PXT, PPT, PDT ����
;       2) init_longmode_page() ִ������ӳ��ǰ����
;       3) �˺���ʹ���� legacy ģʽ��
;---------------------------------------------------------------
map_longmode_page_transition_table32:
        push ecx
        push ebx
        push edx
        
        ;;
        ;; �� 2M �� PPT ����������
        ;;
        call clear_2m_for_longmode_ppt

        ;;
        ;; ��Ҫд���PPT �����ֵַ��200_0000h��
        ;;
        mov eax, [fs: SDA.PptPhysicalBase64]
        mov edx, [fs: SDA.PptPhysicalBase64 + 4]
        and eax, ~0FFFh
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
                
        ;;
        ;; 4K �� PXT ����������21ed000h - 21edfffh)
        ;;
        mov ebx, [fs: SDA.PxtPhysicalBase64]

        ;;
        ;; �Ӹ�����д�� 21ff000h - 2000000h
        ;;
        add eax, (200000h - 1000h)                      ; ��ʼд�� 21ff000h ֵ
        mov ecx, (1000h - 8)                            ; �� 21edff8h ��ʼд
        or eax, VALID_FLAGS | RW                        ; Supervisor, Read/Write, Present, PTE valid
        mov esi, VALID_FLAGS | US | RW                  ; User, Read/Write, Prsent, PTE valid
        
map_longmode_page_transition_table32.loop:
        cmp ecx, 800h
        jae map_longmode_page_transition_table32.@1
        ;;
        ;; 21ed000h - 21ed7f8 ֮��д�� User Ȩ��
        ;;
        or eax, esi

        ;;
        ;; 21ed800h - 21edff8 ֮��д�� Supervisor Ȩ��
        ;;        
map_longmode_page_transition_table32.@1:        
        mov [ebx + ecx], eax
        mov [ebx + ecx + 4], edx
        sub eax, 1000h        
        sub ecx, 8
        jns map_longmode_page_transition_table32.loop
        
        ;;
        ;; ���� PPT ����������־Ϊ��Ч
        ;;
        mov BYTE [fs: SDA.PptValid], 1
        
        pop edx
        pop ebx
        pop ecx
        ret






;---------------------------------------------------------------
; do_prev_stage3_virtual_address_mapping32():
; input:
;       edi:esi - virtual address
;       edx:eax - physical address
;       ecx - page attribute
; output:
;       0 - succssful, otherwise - error code
; ����:
;       1) ִ�� 64 λ�������ַӳ�����
;       2) �ɹ����� 0�������ش�����
;       3) �� legacy ģʽ��ʹ��
;
; attribute ������
;       ecx ���ݹ����� attribute �������־λ��ɣ�
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
;---------------------------------------------------------------
do_prev_stage3_virtual_address_mapping32:
        push eax
        push ecx
        push edx
        push ebx
        push ebp
        push esi
        push edi
        
        ;;
        ;; ���ӳ��������ַ�Ƿ��� PPT �������ڣ�
        ;; ffff_f6fb_7da0_0000h - ffff_f6fb_7dbf_ffffh��2M �ռ䣩
        ;; 1) �ǵĻ������Աj��
        ;;
        mov eax, esi
        mov edx, edi
        mov ebx, 7DA00000h
        mov ecx, 0FFFFF6FBh
        call cmp64
        mov ebx, 7DBFFFFFh
        jb do_prev_stage3_virtual_address_mapping32.next
        call cmp64
        jbe do_prev_stage3_virtual_address_mapping32.done
        
do_prev_stage3_virtual_address_mapping32.next:        
        
        ;;
        ;; �� PPE ֵ
        ;;        
        mov eax, esi
        mov edx, edi
        call get_ppe_offset32
        add eax, [fs: SDA.PptPhysicalBase64]
        mov ebp, eax                                            ; PPE ��ַ
        mov eax, [eax]                                          ; eax = PPE �� 32 λ��
        
        ;;
        ;; ��� PPE �Ƿ���Ч
        ;;
        and eax, VALID_FLAGS
        cmp eax, VALID_FLAGS
        jne do_prev_stage3_virtual_address_mapping32.write_ppe
        
        ;;
        ;; PPE ��Чʱ���� PDT ���ַ����һ��������� PDE
        ;;
        mov eax, [ebp]
        and eax, 0FFFFF000h
        mov ebp, eax                                            ; PDT ���ַ
        
        jmp do_prev_stage3_virtual_address_mapping32.check_pde
        
        
do_prev_stage3_virtual_address_mapping32.write_ppe:
        ;;
        ;; PPE ��Чʱ:
        ;; 1) ��Ҫ����4K�ռ���Ϊ��һ���� PDT ������
        ;; 2) д�� PPE ��
        ;;
        call get_pt_physical_base32                             ; edx:eax - 4K�ռ������ַ
        mov ecx, [esp + 20]                                     ; page attribute
        and ecx, 07h                                            ; ���� U/S, R/W �� P ���ԣ�PCD/PWT ���Բ�����
        or ecx, VALID_FLAGS                                     ; ���� VALAGS_FLAGS ��־��
        or ecx, eax
        ;;
        ;; д�� PPE
        ;;
        mov [ebp], ecx
        mov [ebp + 4], edx
        mov ebp, eax                                            ; PDT ���ַ
        
do_prev_stage3_virtual_address_mapping32.check_pde:        
        ;;
        ;; ��� PDE ��
        ;;
        mov eax, [esp + 4]
        mov edx, [esp]
        call get_pde_index32
        add ebp, eax                                            ; PDE ��ַ
        mov eax, [ebp]                                          ; PDE ֵ
        ;;
        ;; ��� PDE �Ƿ���Ч
        ;; 
        and eax, VALID_FLAGS
        cmp eax, VALID_FLAGS
        jne do_prev_stage3_virtual_address_mapping32.write_pde
        ;;
        ;; PDE ��Чʱ����ȡ PT ���ַ����һ��������� PTE ��
        ;;
        mov eax, [ebp]
        and eax, 0FFFFF000h
        mov ebp, eax                                            ; PT ���ַ
        
        jmp do_prev_stage3_virtual_address_mapping32.check_pte
        
do_prev_stage3_virtual_address_mapping32.write_pde:
        ;;
        ;; PDE ��Чʱ����Ҫд�� PDE��
        ;; ע�⣺
        ;; 1) ���ȣ�����Ƿ�ʹ�� 2M ҳӳ��
        ;; 2) ���� 2M ҳӳ�䣬����Ҫ���� PT ��
        ;; 3) ���� 4K ҳӳ�䣬����Ҫ���� PT ��
        ;; 
        
        ;;
        ;; ��� page ����
        ;;
        mov ecx, [esp + 20]                                     ; ����
        test ecx, PS                                            ; PS λ
        jnz do_prev_stage3_virtual_address_mapping32.write_pde.@1
        ;;
        ;; ���� 4K ҳӳ��
        ;; 1) ���� 4K �ռ䣬��Ϊ PT ���ַ
        ;; 2) д�� PDE ��
        ;;
        call get_pt_physical_base32
        and ecx, 07                                             ; ���� U/S, R/W �� P λ
        or ecx, eax                                             ; �ϳ� page attribute
        or ecx, VALID_FLAGS                                     ; ��Ч��־λ
        
        ;;
        ;; д�� PDE
        ;; 
        mov [ebp], ecx
        mov [ebp + 4], edx
        mov ebp, eax                                            ; PT ���ַ
        
        jmp do_prev_stage3_virtual_address_mapping32.check_pte
        
        
do_prev_stage3_virtual_address_mapping32.write_pde.@1:        
        ;;
        ;; ���� 2M ҳӳ�䣬д�� page frame ��ֵַ
        ;;
        mov eax, [esp + 24]
        mov edx, [esp + 16]                                     ; edx:eax = page frame ��ַ
        and eax, 0FFE00000h                                     ; 2M �߽�
        ;;
        ;; ��֤�ڴ�����֧�ֵ���������ַ��
        ;;
        and eax, [gs: PCB.MaxPhyAddrSelectMask]
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
        
        ;;
        ;; ���� page attribute �� [12:0] λ
        ;;
        mov ecx, [esp + 20]                                     ; �� page attribute
        mov esi, ecx
        
        ;;
        ;; ���� XD ��־λ, attribute & XdValue
        ;;
        and esi, [fs: SDA.XdValue]                              ; �Ƿ��� XD ����
        or edx, esi                                             ; �ϳ� XD ��־
        and ecx, 1FFFh                                          ; ���� 12:0
        or ecx, VALID_FLAGS                                     ; ���� VALAGS_FLAGS ��־��
        or ecx, eax
        
        ;;
        ;; д�� PDE�����ӳ��
        ;;
        mov [ebp], ecx
        mov [ebp + 4], edx
        
        mov eax, MAPPING_SUCCESS
        jmp do_prev_stage3_virtual_address_mapping32.done


do_prev_stage3_virtual_address_mapping32.check_pte:
        mov edx, [esp]
        mov eax, [esp + 4]                                      ; edx:eax = va
        call get_pte_index32
        add ebp, eax                                            ; PTE ��ַ
        mov eax, [ebp]
        
        ;;
        ;; ��� PTE �Ƿ���Ч
        ;;
        and eax, VALID_FLAGS
        cmp eax, VALID_FLAGS
        je do_prev_stage3_virtual_address_mapping32.check_mapping

do_prev_stage3_virtual_address_mapping32.write_pte:
        
        ;;
        ;; ��Чʱ��д�� page frame ��ֵַ
        ;;
        
        mov eax, [esp + 24]
        mov edx, [esp + 16]                                     ; edx:eax = page frame ��ַ
        and eax, 0FFFFF000h                                     ; 4K �߽�
        ;;
        ;; ��֤�ڴ�����֧�ֵ���������ַ��
        ;;
        and eax, [gs: PCB.MaxPhyAddrSelectMask]
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
        
        ;;
        ;; �ϳ� page attribute
        ;;
        mov ecx, [esp + 20]
        btr ecx, 12                                             ; ȡ PAT λ
        setc bl
        shl bl, 7                                               ; PTE.PAT λ
        or cl, bl
        mov esi, ecx
        and esi, [fs: SDA.XdValue]
        or edx, esi                                             ; �ϳ� XD ��־λ
        and ecx, 0FFh                                           ; ���� 8:0 λ
        or eax, ecx
        or eax, VALID_FLAGS                                     ; �����Ч��־
        
        ;;
        ;; д�� PTE ��
        ;;
        mov [ebp], eax
        mov [ebp + 4], edx
        
        mov eax, MAPPING_SUCCESS
        jmp do_prev_stage3_virtual_address_mapping32.done

do_prev_stage3_virtual_address_mapping32.check_mapping:
        ;;
        ;; ���� PTE ����Ч�ģ����� va �Ѿ���ӳ��
        ;; 1) ����Ƿ�ǿ��ӳ��
        ;; 2) ���ǵĻ�������ӳ��
        ;;
        mov ecx, [esp + 20]
        test ecx, FORCE
        jnz do_prev_stage3_virtual_address_mapping32.write_pte
        
        mov eax, MAPPING_USED
        
do_prev_stage3_virtual_address_mapping32.done:        
        mov [esp + 24], eax
        pop edi
        pop esi
        pop ebp
        pop ebx
        pop edx
        pop ecx        
        pop eax
        ret


;---------------------------------------------------------------
; do_prev_stage3_virtual_address_mapping32_n()
; input:
;       edi:esi - virtual address
;       edx:eax - physical address
;       ecx - page attribute
;       count - [ebp + 8]
;       
; output:
;       0 - succssful, otherwise - error code
;
;---------------------------------------------------------------
do_prev_stage3_virtual_address_mapping32_n:
        push ebp
        mov ebp, esp
        sub esp, 16
        
        mov [ebp - 8], eax
        mov [ebp - 4], edx                      ; edx:eax
        mov eax, [ebp + 8]
        mov [ebp - 12], eax                     ; count
        test eax, eax
        jz do_prev_stage3_virtual_address_mapping32_n.done
        
do_prev_stage3_virtual_address_mapping32_n.loop:        
        mov eax, [ebp - 8]
        mov edx, [ebp - 4]
        call do_prev_stage3_virtual_address_mapping32
        add esi, 1000h
        add DWORD [ebp - 8], 1000h
        dec DWORD [ebp - 12]
        jnz do_prev_stage3_virtual_address_mapping32_n.loop

do_prev_stage3_virtual_address_mapping32_n.done:        
        mov esp, ebp
        pop ebp
        ret 4










;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
;$                                              $
;$              64-bit page64 ��                $
;$                                              $
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$


        bits 64
        
        
;---------------------------------------------------------------
; get_pt_virtual_base64()
; intput:
;       rsi - physical address of PT
; output:
;       rax - virtual address of PT��ʧ��ʱ���� 0 ֵ
; ������
;       1) ���� PT pool �������ַ��Ӧ�������ַ
;---------------------------------------------------------------
get_pt_virtual_base64:
        push rsi
        xor eax, eax
        
        ;;
        ;; ��Ҫ��������ַ������ PT pool �ڣ����Ǳ��� PT pool ��
        ;;
        cmp rsi, PT_POOL_PHYSICAL_BASE64
        jb get_pt_virtual_base64.check_backup
        cmp rsi, PT_POOL_PHYSICAL_TOP64
        ja get_pt_virtual_base64.done
        
        sub rsi, PT_POOL_PHYSICAL_BASE64
        mov rax, PT_POOL_BASE64
        add rax, rsi
        jmp get_pt_virtual_base64.done

get_pt_virtual_base64.check_backup:        
        cmp rsi, PT_POOL2_PHYSICAL_BASE64
        jb get_pt_virtual_base64.done
        cmp rsi, PT_POOL2_PHYSICAL_TOP64
        ja get_pt_virtual_base64.done
        
        sub rsi, PT_POOL2_PHYSICAL_BASE64
        mov rax, PT_POOL2_BASE64
        add rax, rsi
        
get_pt_virtual_base64.done:        
        pop rsi
        ret
        
        
        
        
;---------------------------------------------------------------
; get_pt_physical_base64()
; intput:
;       none
; output:
;       rax - physical address of PT 
; ������
;       1) �� PT Pool �����һ�� 4K ������飬��Ϊ PT �� PDT��
;       2) �������� PT Pool ����䣬���� PT pool ������ڱ��� PT pool ����
;       3) ������ PT Pool Ҳ�����꣬���� 0 ֵ
;---------------------------------------------------------------
get_pt_physical_base64:
        push rbx
        xor esi, esi
        mov eax, 4096                                   ; ��������Ϊ 4K
        
        ;;
        ;; ����� PT Pool �Ƿ���п���
        ;;
        cmp BYTE [fs: SDA.PtPoolFree], 1
        jne get_pt_physical_base64.check_backup
        
        ;;
        ;; ����ʱ���� Pt pool �����һ�� 4K �����
        ;;
        lock xadd [fs: SDA.PtPoolPhysicalBase], rax
        
        ;;
        ;; ����� Pt pool �Ƿ���
        ;;
        cmp rax, [fs: SDA.PtPoolPhysicalTop]
        jb get_pt_physical_base64.ok
        
        ;;
        ;; ����ʱ��
        ;; 1) �� PtPoolFree ��־λ
        ;; 2) ����ʹ�ñ��� Pt pool ��������
        ;;
        mov BYTE [fs: SDA.PtPoolFree], 0
        mov eax, 4096
                
get_pt_physical_base64.check_backup:       
        ;;
        ;; ��鱸�� Pt Pool �Ƿ���п���
        ;; ���� Pt Pool �ǿ���ʱ������ 0 ֵ
        ;;
        cmp BYTE [fs: SDA.PtPool2Free], 1
        cmovne eax, esi
        jne get_pt_physical_base64.done
        
        ;;
        ;; �ӱ��� Pt pool ����� 4K �����
        ;;        
        lock xadd [fs: SDA.PtPool2PhysicalBase], rax
        
        ;;
        ;; ��鱸�� Pt pool �Ƿ���
        ;;
        cmp rax, [fs: SDA.PtPool2PhysicalTop]
        jb get_pt_physical_base64.ok
        
        ;;
        ;; ����ʱ���� Free ��־
        ;;
        mov BYTE [fs: SDA.PtPool2Free], 0
        mov eax, esi
        ret
        
get_pt_physical_base64.ok:
        mov rbx, rax
        ;;
        ;; �� PT Pool �� 
        ;;
        mov rsi, rax
        call get_pt_virtual_base64
        mov rsi, rax
        call clear_4k_page64
        mov rax, rbx
        
get_pt_physical_base64.done:        
        pop rbx
        ret






;---------------------------------------------------------------
; do_virtual_address_mapping64():
; input:
;       rsi - virtual address
;       rdi - physical address
;       r8 - page attribute
; output:
;       0 - succssful, otherwise - error code
; ����:
;       1) ִ�� 64 λ�������ַӳ�����
;       2) �ɹ����� 0�������ش�����
;
; attribute ������
;       r8 ���ݹ����� attribute �������־λ��ɣ�
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
;       [26:13] - ����
;       [27] - GET_PHY_PAGE_FRAME
;       [28] - INGORE
;       [29] - FORCE����λʱ��ǿ�ƽ���ӳ��
;       [30] - PHYSICAL����λʱ����ʾ���������ַ����ӳ�䣨���ڳ�ʼ��ʱ��
;       [31] - XD
;---------------------------------------------------------------
do_virtual_address_mapping64:
        push rbx
        push rbp
        push r12
        push r15
        mov rbx, rsi
        mov r12, r8
        mov r15, rdi
        
        ;;
        ;; ���ӳ��������ַ�Ƿ��� PPT �������ڣ�PPT_BASE - PPT_TOP64)��
        ;; 1) �ǵĻ��������Ѿ�ӳ�䣬��Ҫ���Աj��
        ;;
        mov rax, PPT_BASE64
        cmp rsi, rax
        jb do_virtual_address_mapping64.next
        mov rax, PPT_TOP64
        cmp rsi, rax
        jbe do_virtual_address_mapping64.done
        
do_virtual_address_mapping64.next:        
        ;;
        ;; �� PPE ֵ
        ;;
        call get_ppe_offset64
        add rax, [fs: SDA.PptBase64]
        mov rbp, rax                                            ; PPE ��ַ
        mov rax, [rax]                                          ; PPE ֵ
        
        ;;
        ;; ��� PPE �Ƿ���Ч
        ;;
        and eax, VALID_FLAGS
        cmp eax, VALID_FLAGS
        jne do_virtual_address_mapping64.write_ppe

        ;;
        ;; �� PDT ���ַ����һ��������� PDE
        ;;
        mov rax, [rbp]
        and rax, ~0FFFh                                         ; �� bits 11:0
        and rax, [gs: PCB.MaxPhyAddrSelectMask]                 ; 
        
        ;;
        ;; PDT �������ַת��Ϊ��Ӧ�������ַ
        ;;
        mov rsi, rax
        call get_pt_virtual_base64
        mov rbp, rax                                            ; PDT ���ַ
        
        jmp do_virtual_address_mapping64.check_pde
        
        
do_virtual_address_mapping64.write_ppe:
        ;;
        ;; PPE ��Чʱ:
        ;; 1) ��Ҫ����4K�ռ���Ϊ��һ���� PDT ������
        ;; 2) д�� PPE ��
        ;;
        ;; page ��������˵����
        ;; 1) �Ӳ�ʹ�� 1G ҳ��ӳ�䣬�����ȥ�� PS ��־λ
        ;; 2) XD ��־������ PPE ��
        ;; 3) ���ݹ����� User �� Writable ���ԣ�����Ҫ����!
        ;; 4) PAT,PCD,PWT �Լ� G ���Ժ���!(��Щ����ֻ���� page frame �ϣ�
        ;;
        call get_pt_physical_base64                             ; rax - 4K�ռ������ַ
        
        ;;
        ;; ����Ƿ��� 4K �����ַ�Ƿ�ɹ�:
        ;; 1) ���ɹ�ʱ������״̬��Ϊ��MAPPING_NO_RESOURCE
        ;;
        test rax, rax
        mov esi, MAPPING_NO_RESOURCE
        cmovz eax, esi
        jz do_virtual_address_mapping64.done
        
        mov rsi, rax
        or rax, VALID_FLAGS | PAGE_P | PAGE_WRITE | PAGE_USER
        
        ;;
        ;; д�� PPE ��
        ;;
        mov [rbp], rax
        call get_pt_virtual_base64                              ; ȡ PDT ��Ӧ�������ַ
        mov rbp, rax                                            ; PDT ���ַ
        
do_virtual_address_mapping64.check_pde:        
        ;;
        ;; ��ȡ PDE ��
        ;;
        mov rsi, rbx
        call get_pde_index64
        add rbp, rax                                            ; PDE ��ַ
        mov rax, [rbp]                                          ; PDE ֵ
        ;;
        ;; ��� PDE �Ƿ���Ч
        ;; 
        and eax, VALID_FLAGS
        cmp eax, VALID_FLAGS
        jne do_virtual_address_mapping64.write_pde
        
        ;;
        ;; PDE ��Чʱ�����ӳ���Ƿ���Ч
        ;;
        mov rsi, [rbp]
        mov rdi, r12
        call check_valid_for_mapping
        cmp eax, MAPPING_VALID
        jne do_virtual_address_mapping64.done
                
        ;;
        ;; ӳ����Ч���ͨ������ȡ PT ���ַ����һ��������� PTE ��
        ;;
        mov rax, [rbp]
        and rax, ~0FFFh
        and rax, [gs: PCB.MaxPhyAddrSelectMask]
        mov rsi, rax
        call get_pt_virtual_base64
        mov rbp, rax                                            ; PT ���ַ
        
        jmp do_virtual_address_mapping64.check_pte
        
do_virtual_address_mapping64.write_pde:
        ;;
        ;; PDE ��Чʱ����Ҫд�� PDE��
        ;; ע�⣺
        ;; 1) ���ȣ�����Ƿ�ʹ�� 2M ҳӳ��
        ;; 2) ���� 2M ҳӳ�䣬����Ҫ���� PT ��
        ;; 3) ���� 4K ҳӳ�䣬����Ҫ���� PT ��
        ;; 
        ;; page ��������˵����
        ;; 1) ���� 2M page frame ʱ�������е����� page ���Զ�Ҫ����
        ;; 2) ���� 4K ҳ��ӳ��ʱ��ֻȡ page �����е� U/S, R/W �� P
        ;;
        
        ;;
        ;; ����Ƿ�Ϊ 2M ҳ��ӳ��
        ;;
        mov r8, r12
        test r8d, PAGE_2M                                       ; PS λ
        jnz do_virtual_address_mapping64.write_pde.@1
        ;;
        ;; ���� 4K ҳӳ��
        ;; 1) ���� 4K �ռ䣬��Ϊ PT ���ַ
        ;; 2) д�� PDE ��
        ;;
        call get_pt_physical_base64
        ;;
        ;; ����Ƿ��� 4K �����ַ�Ƿ�ɹ�:
        ;; 1) ���ɹ�ʱ������״̬��Ϊ��MAPPING_NO_RESOURCE
        ;;
        test rax, rax
        mov esi, MAPPING_NO_RESOURCE
        cmovz eax, esi
        jz do_virtual_address_mapping64.done

        mov rsi, rax                
        or rax, VALID_FLAGS | PAGE_P | PAGE_WRITE | PAGE_USER
        
        ;;
        ;; д�� PDE
        ;; 
        mov [rbp], rax
        call get_pt_virtual_base64
        mov rbp, rax                                            ; PT ���ַ
        
        jmp do_virtual_address_mapping64.check_pte
        
        
do_virtual_address_mapping64.write_pde.@1:        
        ;;
        ;; ���� 2M ҳӳ�䣬д�� page frame ��ֵַ
        ;;
        mov rax, r15
        and rax, ~1FFFFFh                                       ; ��֤ 2M page frame �߽�
        and rax, [gs: PCB.MaxPhyAddrSelectMask]                 ; ��֤�ڴ���������������ַ��Χ��
        
        ;;
        ;; ���� page attribute �����е� [12] λ���Լ� [8:0]
        ;; �������� page frame ������
        ;;
        mov r8, r12
        and r8, 11FFh
        or rax, r8
        
        ;;
        ;; ���� XD ��־λ�������Բ��� AND [fs: SDA.XdValue]
        ;;
        and r12d, [fs: SDA.XdValue]                             ; ȡ�����Ƿ��� XD ����
        shl r12, 32                                             ; ���� XD ��־
        or rax, r12                                             ; ���� XD ��־ֵ
        or rax, VALID_FLAGS                                     ; ���� VALAGS_FLAGS ��־��
        
        ;;
        ;; д�� PDE�����ӳ��
        ;;
        mov [rbp], rax

        ;;
        ;; ���سɹ�״̬��
        ;;
        mov eax, MAPPING_SUCCESS
        
        jmp do_virtual_address_mapping64.done


do_virtual_address_mapping64.check_pte:
        ;;
        ;; ��ȡ PTE ��
        ;;
        mov rsi, rbx
        call get_pte_index64
        add rbp, rax                                            ; PTE ��ַ
        mov rax, [rbp]
        
        ;;
        ;; ��� PTE �Ƿ���Ч
        ;; 1) ���ԭ���� PTE ����Ч�ģ���ô��Ҫ���ӳ���Ƿ�Ϸ�
        ;; 2) ��� PTE ��Ч����д�� PTE ֵ
        ;;
        and eax, VALID_FLAGS
        cmp eax, VALID_FLAGS
        je do_virtual_address_mapping64.check_mapping

do_virtual_address_mapping64.write_pte:
        
        ;;
        ;; ��Чʱ��д�� page frame ��ֵַ
        ;;
        mov rax, r15
        and rax, ~0FFFh                                         ; ��֤ 4K page frame �߽�
        and rax, [gs: PCB.MaxPhyAddrSelectMask]                 ; ��֤�ڴ���������������ַ��Χ��
        
        ;;
        ;; ���� page attribute �����е� [8:0] λ����ȡ PAT ��־��bit12)
        ;; �������� page frame ������
        ;;
        mov r8, r12
        mov rsi, r12
        and r8, 1FFh
        and r12, PAT                                            ; ȡ PAT ��־ֵ
        shr r12, 5                                              ; ���� PTE �� PAT ��־ֵ
        or r8, r12
        or rax, r8

        ;;
        ;; ���� XD ��־λ�������Բ��� AND [fs: SDA.XdValue]
        ;;
        and esi, [fs: SDA.XdValue]                              ; ȡ�����Ƿ��� XD ����
        shl rsi, 32                                             ; ���� XD ��־
        or rax, rsi                                             ; ���� XD ��־ֵ
        or rax, VALID_FLAGS                                     ; ���� VALAGS_FLAGS ��־��
                       
        ;;
        ;; д�� PTE ��
        ;;
        mov [rbp], rax
        
        mov eax, MAPPING_SUCCESS
        jmp do_virtual_address_mapping64.done

do_virtual_address_mapping64.check_mapping:
        ;;
        ;; ���� PTE ����Ч�ģ����� va �Ѿ���ӳ��
        ;; 1) ����Ƿ�ǿ��ӳ�䣬�����ǿ��ӳ����ֱ��д���µ� PTE ֵ
        ;; 2) ���ǵĻ������ӳ���Ƿ���Ч
        ;;
        mov r8, r12
        test r8d, FORCE
        jnz do_virtual_address_mapping64.write_pte

        ;;
        ;; ���ӳ���Ƿ���Ч��
        ;; 1) �������ܹ����򷵻� MAPPING_USED��ָʾ�Ѿ���ʹ��
        ;; 2) ���򣬷�����Ӧ�Ĵ�����
        ;;
        mov rsi, [rbp]
        mov rdi, r12
        call check_valid_for_mapping
        cmp eax, MAPPING_VALID
        jne do_virtual_address_mapping64.done
        
        ;;
        ;; ���ء��Ѿ���ʹ�á�״̬��
        ;;
        mov eax, MAPPING_USED          
        
        ;;
        ;; ���� page attribute [27] = 1 ʱ����������ҳ frame
        ;;          
        test r12, GET_PHY_PAGE_FRAME
        jz do_virtual_address_mapping64.done
        
        mov rax, [rbp]
        and rax, ~0FFFh
        and rax, [gs: PCB.MaxPhyAddrSelectMask]

do_virtual_address_mapping64.done: 
        pop r15
        pop r12
        pop rbp
        pop rbx
        ret
        


;---------------------------------------------------------------
; do_virtual_address_mapping64_n()
; input:
;       rsi - va
;       rdi - physical address
;       r8 - page attribute
;       r9 - count of pages
; output:
;       rax - status code
; ������
;       1) ���� n ��ҳ���ӳ��
;---------------------------------------------------------------
do_virtual_address_mapping64_n:
        push rcx
        push rbx
        push rdx
        push r12
        push r15
        mov r12, r8
        mov r15, rdi
        mov rdx, rsi
        
        ;;
        ;; ���ӳ��ҳ�� size
        ;;
        mov rcx, 200000h
        mov rbx, 1000h
        test r8d, PAGE_2M
        cmovnz rbx, rcx
        mov rcx, r9
        
do_virtual_address_mapping64_n.loop:
        mov rsi, rdx
        mov rdi, r15
        mov r8, r12        
        call do_virtual_address_mapping64
        cmp eax, MAPPING_SUCCESS
        jne do_virtual_address_mapping64_n.done
        add rdx, rbx
        add r15, rbx
        dec rcx
        jnz do_virtual_address_mapping64_n.loop

do_virtual_address_mapping64_n.done:        
        pop r15
        pop r12
        pop rdx
        pop rbx
        pop rcx
        ret        
        


;---------------------------------------------------------------
; get_physical_address_of_virtual_address()
; input:
;       rsi - virtual address
; output:
;       rax - physical address
; ������
;       1) ���������ַӳ��������ַ
;---------------------------------------------------------------
get_physical_address_of_virtual_address:
        push rbx
        mov rbx, rsi
        mov r8d, GET_PHY_PAGE_FRAME
        call do_virtual_address_mapping64
        and ebx, 0FFFh
        add rax, rbx
        pop rbx
        ret



;---------------------------------------------------------------
; check_valid_for_mapping()
; input:
;       rsi - pt entry attribute
;       rdi - page attribute
; output:
;       rax - status code
; ����:
;       1) �� PPE��PDE, PTE ��Чʱ��˵���Ѿ���ӳ��
;       2) ��Ҫ����ύ��ӳ���Ƿ���Ч
;       3) ��������״̬�룬Ϊ MAPPING_VALID ʱ������ӳ����Ч
;---------------------------------------------------------------
check_valid_for_mapping:
        push rcx
        ;;
        ;; �������˵����
        ;; 1) ��� entry �� PS = 1 ʱ���������е� PS Ϊ 0 ʱ�����س����룺MAPPING_PS_MISMATCH
        ;; 2) ��� entry �� R/W = 0���������е� R/W = 1 ʱ�����س����룺MAPPING_RW_MISMATCH
        ;; 3) ��� entry �� U/S = 0���������е� U/S = 1 ʱ�����س����룺MAPPING_US_MISMATCH
        ;; 4) ��� entry �� XD = 1���������е� XD = 0 ʱ�����س����룺MAPPING_XD_MISMATCH
        ;; 5) PAT, G��PCD, PWT��A ���Խ����ԣ�
        
        mov eax, esi
        
        ;;
        ;; ��� PS ��־
        ;; 1) ��� PS ��־��ͬ���򷵻� MAPPING_PS_MISMATCH
        ;;
        xor eax, edi
        test eax, PS
        mov ecx, MAPPING_PS_MISMATCH
        cmovnz eax, ecx
        jnz check_valid_for_mapping.done
        
        ;;
        ;; ��� R/W ��־:
        ;; 1) ��� entry �� R/W = 1 ʱ��ͨ�����������¼��
        ;; 2) ��� entry �� R/W = 0 ���Ҳ����� R/W = 1 ʱ������ MAPPING_RW_MISMATCH
        ;;
        mov rax, rsi
        test eax, RW
        jnz check_valid_for_mapping.check_us
        test edi, RW
        mov ecx, MAPPING_RW_MISMATCH
        cmovnz eax, ecx
        jnz check_valid_for_mapping.done

check_valid_for_mapping.check_us:
        ;;
        ;; ��� U/S ��־��
        ;; 1) ��� entry �� U/S = 1 ʱ��ͨ�����������¼��
        ;; 2) ��� entry �� U/S = 0 ���Ҳ����� U/S = 1 ʱ������ MAPPING_US_MISMATCH
        ;;
        test eax, US
        jnz check_valid_for_mapping.check_xd
        test edi, US
        mov ecx, MAPPING_US_MISMATCH
        cmovnz eax, ecx
        jnz check_valid_for_mapping.done

check_valid_for_mapping.check_xd:
        ;;
        ;; ��� XD ��־��
        ;; 1) ��� entry �� XD = 0 ʱ��ͨ�����������¼��
        ;; 2) ��� entry �� XD = 1 ���Ҳ����� U/S = 0 ʱ������ MAPPING_XD_MISMATCH
        ;;
        bt rax, 63
        mov eax, MAPPING_VALID
        jnc check_valid_for_mapping.done
        test edi, XD
        mov ecx, MAPPING_XD_MISMATCH
        cmovz eax, ecx

check_valid_for_mapping.done:        
        pop rcx
        ret



        

;---------------------------------------------------------------
; get_pxe_offset64():
; input:
;       rsi - va
; output:
;       rax - offset
; ������
;       �õ� PXT entry �� offset ֵ
; ע�⣺
;       �� 64-bit ��ʹ��
;---------------------------------------------------------------
get_pxe_offset64:
        mov rax, rsi
        shl rax, 16                                             ; �� va �� 16 λ
        shr rax, (16 + 12 + 9 + 9 + 9)                          ; index = va >> 39
        shl rax, 3                                              ; offset = index << 3
        ret
        
        

;---------------------------------------------------------------
; get_ppe_offset64():
; input:
;       rsi - va
; output:
;       rax - offset
; ������
;       �õ� PPT entry �� offset ֵ
; ע�⣺
;       �� 64-bit ��ʹ��
;---------------------------------------------------------------
get_ppe_offset64:
        mov rax, rsi
        shl rax, 16                                             ; �� va �� 16 λ
        shr rax, (16 + 12 + 9 + 9)                              ; index = va >> 30
        shl rax, 3                                              ; offset = index << 3
        ret
                        




;---------------------------------------------------------------
; get_pde_index64()
; input:
;       rsi - va
; output:
;       rax - index of PDE
; ����:
;       1) �õ� VA �� PDE �� index ֵ
;       2) ��� index ֵ���� PDT ��ַ
;---------------------------------------------------------------
get_pde_index64:
        mov rax, rsi
        shr eax, (12 + 9)
        and eax, 1FFh
        shl eax, 3
        ret
        


;---------------------------------------------------------------
; get_pte_index64():
; input:
;       rsi - va
; output:
;       rax - index of PTE
; ������
;       1) �õ� PTE �� index ֵ
;       2) ��� index ֵ���� PT ��ַ
;---------------------------------------------------------------
get_pte_index64:
        mov rax, rsi
        shr eax, 12
        and eax, 1FFh
        shl eax, 3
        ret                        
        
        
        
        
%if 0

;-----------------------------------------------------------------------
; alloc_kernel_stack_4k_base64()
; input:
;       none
; output:
;       rax - 4K stack base�������ַ�� 
; ������
;       1)����һ��4Kҳ���С�� kernel stack base�Ŀ���ֵ         
;       2)�����µ�ǰ kernel stack base ��¼
;-----------------------------------------------------------------------
alloc_kernel_stack_4k_base64:
        mov eax, 4096
        lock xadd [fs: SDA.KernelStackBase], rax
        ret        
        
%endif