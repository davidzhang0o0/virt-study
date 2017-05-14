;*************************************************
; GuestLib.asm                                   *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


        bits 32


        
;-----------------------------------------
; ZeroMemory()
; input:
;       esi - size
;       edi - buffer address
; ������
;       ���ڴ���� 0
;-----------------------------------------
ZeroMemory:
        push ecx
        
        test edi, edi
        jz ZeroMemory.done
        
        xor eax, eax
        
        ;;
        ;; ��� count > 4 ?
        ;;
        cmp esi, 4
        jb ZeroMemory.@1
        
        ;;
        ;; ��д���� 4 �ֽ�
        ;;
        mov [edi], eax
        
        ;;
        ;; ��������� DWORD �߽��ϵĲ�ԭ����� 4 - dest & 03
        ;; 1) ���磺[2:0] = 011B��3��
        ;; 2) ȡ���� = 100B��4��
        ;; 3) ��1�� = 101B��5��        
        ;; 4) ��32λ����03�� = 001B��1���������Ϊ 1
        ;;
        mov ecx, esi                                    ; ԭ count        
        mov esi, edi                                    ; ԭ dest
        not esi
        inc esi
        and esi, 03                                     ; �� 32 λ���� 03h
        sub ecx, esi                                    ; count = ԭ count - ���

        ;;
        ;; dest ���ϵ����� DWORD �߽�
        ;;
        add edi, esi                                    ; dest = dest + ���
        mov esi, ecx
           
        ;;
        ;; �� 32 λ�£��� DWORD Ϊ��λ
        ;; 
        shr ecx, 2
        rep stosd

ZeroMemory.@1:                     
        ;;
        ;; һ�� 1 �ֽڣ�д��ʣ���ֽ���
        ;;
        mov ecx, esi
        and ecx, 03h
        rep stosb
        
ZeroMemory.done:        
        pop ecx
        ret   
        ret
        
        
;-----------------------------------------------------
; AllocPhysicalPage()
; input:
;       esi - count of page
; output:
;       eax - physical address of page
;-----------------------------------------------------        
AllocPhysicalPage:
        push ebx
        
        ;;
        ;; �����ַ
        ;;
        imul eax, esi, 4096
        xadd [Guest.PoolPhysicalBase], eax
        mov ebx, eax

        ;;
        ;; ��ҳ��
        ;;
        mov esi, 4096
        mov edi, eax       
        call ZeroMemory
        mov eax, ebx
        
        pop ebx
        ret






%ifdef GUEST_X64



;-----------------------------------------------------
; init_longmode_page()
; intput:
;       none
; output:
;       none
; ������
;       1) ��δ��ҳ�µ���
;-----------------------------------------------------
init_longmode_page:
        push ebx
        push edx
        push ecx
        push ebp

        ;;
        ;;    --------------- �����ַ --------------              ------ �����ַ ------
        ;; 1) FFFF8000_C0200000h - FFFF8000_C05FFFFFh     ==>     00200000h - 005FFFFFh ��2Mҳ�棩
        ;; 2) FFFF8000_80020000h - FFFF8000_8002FFFFh     ==>     00020000h - 0002FFFFh ��4Kҳ�棩
        ;; 3) 00020000h - 0002FFFFh                       ==>     00020000h - 0002FFFFh ��4Kҳ�棩
        ;; 4) FFFF8000_FFF00000h - FFFF8000_FFF00FFFh     ==>     AllocPhysicalPage()   ��4Kҳ�棩
        ;; 5) 000B8000h - 000B8FFFh                       ==>     000B8000h - 000B8FFFh ��4Kҳ�棩
        ;; 6) 00007000h - 00008FFFh                       ==>     00007000h - 00008FFFh ��4Kҳ�棩
        ;; 7) FFFF8000_81000000h - FFFF8000_81000FFFh     ==>     01000000h - 01000FFFh ��4Kҳ�棩
        ;;
        
        
                
        ;;
        ;; #### step 1: ���� PML4E ####
        ;;
        
        ;;
        ;; ���� FFFF8000_xxxxxxxx �� PML4E
        ;;
        mov esi, 1
        call AllocPhysicalPage
        mov ebx, eax                                                    ;; ebx = PML4T[100h]
        or eax, RW | P
        mov [GUEST_PML4T_BASE + 100h * 8], eax                          ;; PML4T[100h]
        mov DWORD [GUEST_PML4T_BASE + 100h * 8 + 4], 0
        
        ;;
        ;; ���� 00000000_xxxxxxxx �� PML4E
        ;;��
        mov esi, 1
        call AllocPhysicalPage
        mov edx, eax                                                    ;; edx = PML4T[0]
        or eax, RW | US | P
        mov [GUEST_PML4T_BASE + 0 * 8], eax                             ;; PML4T[0]
        mov DWORD [GUEST_PML4T_BASE + 0 * 8 + 4], 0
        
        
        ;;
        ;; #### step 2: ���� PDPTE ####
        ;;
        
        ;;
        ;; ���� FFFF8000_Cxxxxxxx �� PDPTE
        ;; ���� FFFF8000_8xxxxxxx �� PDPTE  
        ;; ���� FFFF8000_Fxxxxxxx �� PDPTE
        ;;
        mov esi, 1
        call AllocPhysicalPage
        mov ebp, eax                                                    ;; ebp
        or eax, RW | P
        mov [ebx + 2 * 8], eax
        mov DWORD [ebx + 2 * 8 + 4], 0
        
        mov esi, 1
        call AllocPhysicalPage
        mov ecx, eax
        or eax, RW | P
        mov [ebx + 3 * 8], eax
        mov DWORD [ebx + 3 * 8 + 4], 0              
                
        ;;
        ;; ���� 00000000_0xxxxxxx �� PDPTE
        ;;
        mov esi, 1
        call AllocPhysicalPage
        mov ebx, eax                                                    ;; ebx
        or eax, RW | US | P
        mov [edx + 0 * 8], eax
        mov DWORD [edx + 0 * 8 + 4], 0        

        
        
        ;;
        ;; #### step 3: ���� PDE ####
        ;;
          
        ;;
        ;; ���� FFFF8000_C02xxxxx �� PDE
        ;;
        mov DWORD [ecx + 1 * 8], 200000h | PS | RW | P
        mov DWORD [ecx + 1 * 8 + 4], 0
        mov DWORD [ecx + 2 * 8], 400000h | PS | RW | P
        mov DWORD [ecx + 2 * 8 + 4], 0

        ;;
        ;; ���� FFFF8000_FFFxxxxx �� PDE
        ;;
        mov esi, 1
        call AllocPhysicalPage
        mov edi, eax
        or eax, RW | P
        mov [ecx + 1FFh * 8], eax
        mov DWORD [ecx + 1FFh * 8 + 4], 0
        mov ecx, edi
        
                
        ;;
        ;; ���� FFFF8000_8002xxxx �� PDE
        ;;
        mov esi, 1
        call AllocPhysicalPage
        mov edx, eax                                                    ;; edx
        or eax, RW | P
        mov [ebp + 0 * 8], eax
        mov DWORD [ebp + 0 * 8 + 4], 0
        
        ;;
        ;; ���� FFFF8000_810xxxxx �� PDE
        ;;
        mov esi, 1
        call AllocPhysicalPage
        or eax, RW | P
        mov [ebp + 8 * 8], eax
        mov DWORD [ebp + 8 * 8 + 4], 0 
               
        ;;
        ;; ���� FFFF8000_81000000h ӳ��� PTE
        ;;
        and eax, ~0FFFh
        mov DWORD [eax + 0 * 8], 01000000h | RW | P
        mov DWORD [eax + 0 * 8 + 4], 0
       
        ;;
        ;; ���� 00000000_00020xxx �� PDE
        ;;
        mov esi, 1
        call AllocPhysicalPage
        mov ebp, eax
        or eax, RW | US | P
        mov [ebx + 0 * 8], eax
        mov DWORD [ebx + 0 * 8 + 4], 0
        
       
        
     
        ;;
        ;; #### step 4: ���� PTE ####
        ;;
        
        ;;
        ;; ���� FFFF8000_FFF00000 �� PTE
        ;;
        mov esi, 1
        call AllocPhysicalPage
        or eax, RW | P
        mov [ecx + 100h * 8], eax
        mov DWORD [ecx + 100h * 8 + 4], 0
        
        ;;
        ;; ���� FFFF8000_80020000h��00020000h �� PTE
        ;;
        mov ecx, 20h
        mov esi, 20000h | RW | P
init_longmode_page.loop:
        mov [ebp + ecx * 8], esi
        mov DWORD [ebp + ecx * 8 + 4], 0
        or DWORD [ebp + ecx * 8], PAGE_USER                     ; 20000h ���� USER Ȩ��
        mov [edx + ecx * 8], esi
        mov DWORD [edx + ecx * 8 + 4], 0
        add esi, 1000h
        inc ecx
        cmp ecx, 2Fh
        jbe init_longmode_page.loop
        
        ;;
        ;; ���� 0B8000h �� PTE
        ;;
        mov DWORD [ebp + 0B8h * 8], 0B8000h | RW | US | P
        mov DWORD [ebp + 0B8h * 8 + 4], 0      

        ;;
        ;; ���� 7000h - 8FFFh �� PTE
        ;;
        mov DWORD [ebp + 7 * 8], 7000h | RW | US | P
        mov DWORD [ebp + 7 * 8 + 4], 0     
        mov DWORD [ebp + 8 * 8], 8000h | RW | US | P
        mov DWORD [ebp + 8 * 8 + 4], 0     
        
        pop ebp
        pop ecx
        pop edx
        pop ebx
        ret


        bits 64
        
;----------------------------------------------------------
; update_tss_longmode()
; input:
;       none
; output:
;       none
; ������
;       1) ���� TSS Ϊ 64-bit �µ� TSS
;----------------------------------------------------------
update_tss_longmode:       
        ret
        
        
        
;----------------------------------------------------------
; do_virtual_address_mapping()
; input:
;       rsi - guest physical address
;       rdi - physical address
;       eax - page attribute
; output:
;       0 - successful, otherwise - error code
; ������
;       1) �������ַӳ�䵽�����ַ
;----------------------------------------------------------
do_virtual_address_mapping:
        push rbp
        push rbx
        push rcx
        push r10
        push r11

        
               
        
        mov r10, rsi                                    ; r10 = VA
        mov r11, rdi                                    ; r11 = PA
        mov ebx, eax                                    ; ebx = page attribute
        mov ecx, (32 - 4)                               ; ecx = ���� index ����λ����shld��
        mov rbp, PML4T_BASE                             ; rbp = PML4T �����ַ


do_virtual_address_mapping.Walk:
        ;;
        ;; paging structure walk ����
        ;;
        shld rax, r10, cl
        and eax, 0FF8h
        
        ;;
        ;; ��ȡ����
        ;;
        add rbp, rax                                    ; rbp ָ�����
        mov rsi, [rbp]                                  ; rsi = ����ֵ
        
        
        ;;
        ;; �������Ƿ�Ϊ not present
        ;;
        test esi, PAGE_P
        jnz do_virtual_address_mapping.NextWalk
        

do_virtual_address_mapping.NotPrsent:     
        ;;
        ;; ����Ƿ�Ϊ PDE
        ;;
        cmp ecx, (32 - 4 + 9 + 9)
        jne do_virtual_address_mapping.CheckPte

        test ebx, PAGE_2M
        jz do_virtual_address_mapping.CheckPte

        ;;
        ;; ʹ�� 2M ҳ��
        ;;
        mov eax, ebx
        and eax, 0FFh
        and r11, ~1FFFFFh
        or rax, r11
        mov [rbp], rax

        jmp do_virtual_address_mapping.Done

do_virtual_address_mapping.CheckPte:
        ;;
        ;; ����Ƿ�Ϊ PTE
        ;;
        cmp ecx, (32 - 4 + 9 + 9 + 9)
        jne do_virtual_address_mapping.WriteEntry

        ;;
        ;; ʹ�� 4K ҳ��
        ;;
        mov eax, ebx
        and eax, 07Fh
        and r11, ~0FFFh
        or rax, r11
        mov [rbp], rax

        jmp do_virtual_address_mapping.Done

        
do_virtual_address_mapping.WriteEntry:             
        ;;
        ;; ����ҳ��
        ;;
        mov esi, 1
        call AllocPhysicalPage
        
        mov esi, eax
        or rax, PAGE_USER | PAGE_WRITE | PAGE_P          
        
        ;;
        ;; д���������
        ;;
        mov [rbp], rax

do_virtual_address_mapping.NextWalk:
        and esi, ~0FFFh
        mov rbp, POOL_BASE
        sub esi, GUEST_POOL_PHYSICAL_BASE
        add rbp, rsi

        ;;
        ;; ִ�м��� walk ����
        ;;
        add ecx, 9
        jmp do_virtual_address_mapping.Walk
               
do_virtual_address_mapping.Done:
        mov eax, MAPPING_SUCCESS
        pop r11                
        pop r10
        pop rcx
        pop rbx
        pop rbp
        ret

        bits 32
%else


;-----------------------------------------------------
; init_page_page()
; intput:
;       none
; output:
;       none
; ������
;       1) ��δ��ҳ�µ���
;-----------------------------------------------------
init_pae_page:
        push ebx
        push edx
        push ecx
        
        ;;
        ;;    ----- �����ַ ------              ----- �����ַ ------
        ;; 1) C0200000h - C05FFFFFh     ==>     00200000h - 005FFFFFh ��2Mҳ�棩
        ;; 2) 80020000h - 8002FFFFh     ==>     00020000h - 0002FFFFh ��4Kҳ�棩
        ;; 3) 00020000h - 0002FFFFh     ==>     00020000h - 0002FFFFh ��4Kҳ�棩
        ;; 4) FFF00000h - FFF00FFFh     ==>     AllocPhysicalPage()   ��4Kҳ�棩
        ;; 5) 000B8000h - 000B8000h     ==>     000B8000h - 000B8000h ��4Kҳ�棩
        ;; 6) 00007000h - 00008FFFh     ==>     00007000h - 00008FFFh ��4Kҳ�棩
        ;; 7) 81000000h - 81000FFFh     ==>     01000000h - 01000FFFh ��4Kҳ�棩        
        ;;
        
        ;;
        ;; ### step 0: PAE paging ��ҳģʽ�µ� 4 �� PDPTE �Ѿ������� ###
        ;;
        
        
        ;;
        ;; ### step 1: ���� PDE ֵ ###
        ;;
        mov eax, 200000h | PS | RW | P                          ;; ʹ�� 2M ҳ��
        mov [GUEST_PDT3_BASE + 1 * 8], eax                      ;; ӳ�� C0200000h �����ַ�������ַ 200000h
        mov DWORD [GUEST_PDT3_BASE + 1 * 8 + 4], 0
        mov eax, 400000h | PS | RW | P                          ;; ʹ�� 2M ҳ��
        mov [GUEST_PDT3_BASE + 2 * 8], eax                      ;; ӳ�� C0400000h �����ַ�������ַ 400000h
        mov DWORD [GUEST_PDT3_BASE + 2 * 8 + 4], 0
                
        mov esi, 1
        call AllocPhysicalPage                                  ;; ���� 4K ҳ����Ϊ��һ�� PT ��ַ
        or eax, RW | P
        mov [GUEST_PDT2_BASE + 0 * 8], eax                      ;; ӳ�� 80020000h �����ַ
        mov DWORD [GUEST_PDT2_BASE + 0 * 8 + 4], 0              
        
        mov esi, 1
        call AllocPhysicalPage                                  ;; ���� 4K ҳ����Ϊ��һ�� PT ��ַ
        or eax, RW | P
        mov [GUEST_PDT2_BASE + 8 * 8], eax                      ;; ӳ�� 81000000h �����ַ
        mov DWORD [GUEST_PDT2_BASE + 8 * 8 + 4], 0            
        
        mov esi, 1
        call AllocPhysicalPage                                  ;; ���� 4K ҳ����Ϊ��һ�� PT ��ַ
        or eax, RW | P
        mov [GUEST_PDT3_BASE + 01FFh * 8], eax                  ;; ӳ�� FFF00000h �����ַ
        mov DWORD [GUEST_PDT3_BASE + 01FFh * 8 + 4], 0
        
        mov esi, 1
        call AllocPhysicalPage                                  ;; ���� 4K ҳҳ��Ϊ��һ�� PT ��ַ
        or eax, RW | US | P
        mov [GUEST_PDT0_BASE + 0 * 8], eax                      ;; ӳ�� 00020000h �����ַ
        mov DWORD [GUEST_PDT0_BASE + 0 * 8 + 4], 0
        
        ;;
        ;; ### step 2: ���� PTE ֵ ###
        ;;
        mov ebx, [GUEST_PDT2_BASE + 0 * 8]
        mov edx, [GUEST_PDT0_BASE + 0 * 8]
        and ebx, ~0FFFh                                         ; ��ȡ 80020000h �����ַ��Ӧ�� PT ��ַ
        and edx, ~0FFFh                                         ; ��ȡ 00020000h �����ַ��Ӧ�� PT ��ַ
        mov ecx, 20h                                            ; ��ʼ PTE index Ϊ 20h����Ӧ 80020 page frame)
        mov eax, 20000h                                         ; ��ʼ�����ַΪ 20000h
        or eax, RW | P
       
        ;;
        ;; ӳ�������ַ:
        ;; 1) 80020000 - 8002FFFFh �������ַ 00020000 - 0002FFFFh
        ;; 2) 00020000 - 0002FFFFh �������ַ 00020000 - 0002FFFFh
        ;;
init_pae_page.loop1:
        mov [ebx + ecx * 8], eax
        mov DWORD [ebx + ecx * 8 + 4], 0
        mov [edx + ecx * 8], eax
        mov DWORD [edx + ecx * 8 + 4], 0
        or DWORD [edx + ecx * 8], PAGE_USER
        add eax, 1000h                                          ; ָ����һҳ��
        inc ecx
        cmp ecx, 2Fh                                            ; page frmae �� 80020 �� 8002F��00020 �� 0002F��
        jbe init_pae_page.loop1
        
        ;;
        ;; ӳ�������ַ FFF00000 - FFF00FFFh �������ַ�� AllocPhysicalPage() �������
        ;;
        mov ebx, [GUEST_PDT3_BASE + 01FFh * 8]
        and ebx, ~0FFFh                                         ; ��ȡ FFF00000h �����ַ��Ӧ�� PT ��ַ
        mov esi, 1
        call AllocPhysicalPage
        or eax, RW | P
        mov [ebx + 100h * 8], eax
        mov DWORD [ebx + 100h * 8 + 4], 0

        ;;
        ;; ӳ�� 81000000h �����ַ
        ;;
        mov esi, [GUEST_PDT2_BASE + 8 * 8]
        and esi, ~0FFFh
        mov DWORD [esi + 0 * 8], 01000000h | RW | P
        mov DWORD [esi + 0 * 8 + 4], 0
        
                
        ;;
        ;; ӳ�������ַ 000B8000h - 000B8000h �������ַ 000B8000h - 000B8000h
        ;;
        mov ebx, [GUEST_PDT0_BASE + 0 * 8]
        and ebx, ~0FFFh
        mov DWORD [ebx + 0B8h * 8], 0B8000h | RW | US | P
        mov DWORD [ebx + 0B8h * 8 + 4], 0
        
        ;;
        ;; ӳ�������ַ 00007000h - 00008FFFh  �������ַ 00007000h - 00008FFFh 
        ;; 
        mov DWORD [ebx + 7 * 8], 7000h | RW | US | P
        mov DWORD [ebx + 7 * 8 + 4], 0
        mov DWORD [ebx + 8 * 8], 8000h | RW | US | P
        mov DWORD [ebx + 8 * 8 + 4], 0
        
        pop ecx
        pop edx
        pop ebx
        ret


%endif




;-----------------------------------------------------
; do_virtual_address_mapping32()
; input:
;       esi - virtual address
;       edi - physical address
;       eax - page attribute
; output:
;       eax - status code
;-----------------------------------------------------
do_virtual_address_mapping32:
        ret