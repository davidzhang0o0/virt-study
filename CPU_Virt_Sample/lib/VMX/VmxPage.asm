;*************************************************
;* VmxPage.asm                                   *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************






;----------------------------------------------------------
; get_ept_pointer()
; input:
;       none
; output:
;       eax - vmcs pointer�������ַ��
;       edx - vmcs pointer�������ַ��
; ������ 
;       1) ��������� kernel pool ����� 4K ����Ϊ EPT �е� PT ��
;       2) eax ���������ַ��edx ���������ַ
;       3) 64-bit �£�rax - 64 λ���������ַ�� rdx - 64 λ���������ַ
;       4) �˺���ʵ���� VmxVmcs.asm ��
;----------------------------------------------------------
get_ept_pointer:
get_ept_page:
        ;;
        ;; EPT �� page ʹ�� WB ����
        ;;
        mov esi, 0
        jmp get_vmcs_region_pointer




;----------------------------------------------------------
; get_ept_page_attribute():
; input:
;       none
; output:
;       eax - page memory attribute
; ������
;       1) �õ� EPT �ṹ�е� page memory attribute
;       2) ֧������ attribute: WB �� UC
;----------------------------------------------------------
get_ept_page_attribute:
        push ebp
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif           
        pop ebp
        ret



;----------------------------------------------------------
; init_ept_pxt():
; input:
;       none
; output:
;       none
; ������
;       1) ��ʼ�� EPT �� PXT ��
;----------------------------------------------------------
init_ept_pxt_ppt:
        push ebp
        push ecx
        push edx

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif
            
        ;;
        ;; ӳ�� PPT ����
        ;;
        REX.Wrxb
        mov esi, [ebp + SDA.EptPptBase64]
        REX.Wrxb
        mov edx, esi
        REX.Wrxb
        mov edi, [ebp + SDA.EptPptPhysicalBase64]
        
        mov eax, XD | RW | P                
        REX.Wrxb
        mov ecx, [ebp + SDA.EptPptTop64]
        REX.Wrxb
        sub ecx, esi
        REX.Wrxb
        add ecx, 0FFFh
        REX.Wrxb
        shr ecx, 12 
        
%ifdef __X64
        DB 41h, 89h, 0C0h                       ; mov r8d, eax
        DB 41h, 89h, 0C9h                       ; mov r9d, ecx
%endif        
        call do_virtual_address_mapping_n       
      
        ;;
        ;; �� PPT ����
        ;;
        REX.Wrxb
        mov esi, edx
        mov edi, ecx
        call clear_4k_buffer_n
        
        
        ;;
        ;; д�� PXT ��ֵ��ÿ�� PML4E �� PPT �������ַ
        ;;
        REX.Wrxb
        mov edi, [ebp + SDA.EptPxtBase64]                       ; Pxt �����ַ
        mov esi, [ebp + SDA.EptPptPhysicalBase64]               ; Ppt �������ַ
        and esi, 0FFFFF000h
        
        xor ecx, ecx        
        mov edx, 00100000h                                      ; bits 54:53 = 1 ʱ����ʾΪ PML4E 
        
init_ept_pxt.loop:        
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE | EPT_VALID_FLAG
        or eax, esi
        mov [edi + ecx * 8], eax
        mov [edi + ecx * 8 + 4], edx
        add esi, 1000h
        INCv ecx
        cmp ecx, 512
        jb init_ept_pxt.loop                
        pop ecx
        pop edx
        pop ebp
        ret
        
        
        
;----------------------------------------------------------
; get_ept_ppt_virtual_address()��
; input:
;       esi - pa
; output:
;       eax - va
; ������
;       1) ��������������ַת��Ϊ�����ַ
;----------------------------------------------------------
get_ept_ppt_virtual_address:
        push ebp
        
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif        
        sub esi, [ebp + SDA.EptPptPhysicalBase64]
        REX.Wrxb
        mov eax, [ebp + SDA.EptPptBase64]
        REX.Wrxb
        add eax, esi
        pop ebp
        ret
        

;----------------------------------------------------------
; get_ept_pdt_virtual_address()��
; input:
;       esi - pa
; output:
;       eax - va
; ������
;       1) ��������������ַת��Ϊ�����ַ
;----------------------------------------------------------
get_ept_pdt_virtual_address:
get_ept_pt_virtual_address:
        push ebp
        
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif
        ;;
        ;; ˵����
        ;; 1) EPT �� PDT �� PT �������ַ�� kernel pool ����䡣
        ;; 2) ��Ҫ��ȥ KernelPoolPhysicalBase ֵ�������ַ��
        ;; 2) ���� KernelPoolBase ֵ�������ַ��
        ;;
        REX.Wrxb
        sub esi, [ebp + SDA.KernelPoolPhysicalBase]
        REX.Wrxb
        mov eax, [ebp + SDA.KernelPoolBase]
        REX.Wrxb
        add eax, esi
        pop ebp
        ret
                


;---------------------------------------------------------------
; get_ept_pxe_offset32():
; input:
;       edx:eax - guest physical address
; output:
;       eax - offset
; ������
;       �õ� PXT entry �� offset ֵ
; ע�⣺
;       �� legacy ģʽ��ʹ��
;---------------------------------------------------------------
get_ept_pxe_offset32:
        push ecx
        and edx, 0FFFFh                                         ; �� ga �� 16 λ
        mov ecx, (12 + 9 + 9 + 9)                               ; index = ga >> 39
        call shr64
        mov ecx, 3
        call shl64                                              ; offset = index << 3
        pop ecx
        ret
        
                
;---------------------------------------------------------------
; get_ept_ppe_offset32():
; input:
;       edx:eax - ga
; output:
;       eax - offset
; ������
;       1) �õ� PPT entry �� offset ֵ
;       2) �� legacy ��ʹ��
;---------------------------------------------------------------
get_ept_ppe_offset32:
        push ecx
        and edx, 0FFFFh                                         ; �� ga �� 16 λ
        mov ecx, (12 + 9 + 9)                                   ; index = ga >> 30
        call shr64
        mov ecx, 3
        call shl64                                              ; offset = index << 3
        pop ecx
        ret
        
        

;---------------------------------------------------------------
; get_ept_pde_offset32():
; input:
;       edx:eax - ga
; output:
;       eax - offset
; ������
;       1) �õ� PDT entry �� offset ֵ
;       2) �� legacy ��ʹ��
;---------------------------------------------------------------
get_ept_pde_offset32:
        and eax, 3FE00000h                                      ; PDE index
        shr eax, (12 + 9 - 3)                                   ; index = ga >> 21 << 3
        ret
        


;---------------------------------------------------------------
; get_ept_pte_offset32():
; input:
;       edx:eax - ga
; output:
;       eax - offset
; ������
;       1) �õ� PT entry �� offset ֵ
;       2) �� legacy ��ʹ��
;---------------------------------------------------------------
get_ept_pte_offset32:
        and eax, 01FF000h                                       ; PTE index
        shr eax, (12 - 3)                                       ; offset = ga >> 12 << 3
        ret
                        
                        
                        
;----------------------------------------------------------
; get_ept_entry_level_attribute32()
; input:
;       ecx - shld count
; output:
;       edx:eax - level attribute
;----------------------------------------------------------
get_ept_entry_level_attribute32:

        xor edx, edx
        xor eax, eax      
          
        cmp ecx, (47 - 11)
        je get_ept_entry_level_attribute32.@1
        
        cmp ecx, (47 - 11 - 9)
        je get_ept_entry_level_attribute32.@2
        
        cmp ecx, (47 - 11 - 9 - 9)
        je get_ept_entry_level_attribute32.@3
        
        cmp ecx, (47 - 11 - 9 - 9 -9)
        jne get_ept_entry_level_attribute32.Done
        
        mov edx, EPT_PTE32
        mov eax, EPT_MEM_WB                             ;; PTE ʹ�� WB �ڴ�����
        jmp get_ept_entry_level_attribute32.Done
        
get_ept_entry_level_attribute32.@1:
        mov edx, EPT_PML4E32
        jmp get_ept_entry_level_attribute32.Done

get_ept_entry_level_attribute32.@2:
        mov edx, EPT_PDPTE32
        jmp get_ept_entry_level_attribute32.Done
        
get_ept_entry_level_attribute32.@3:
        mov edx, EPT_PDE32
        
get_ept_entry_level_attribute32.Done:                
        ret



;----------------------------------------------------------
; do_guest_physical_address_mapping32()
; input:
;       edi:esi - guest physical address (64 λ��
;       edx:eax - physical address(64λ��
;       ecx - page attribute
; output:
;       0 - successful, otherwise - error code
; ������
;       1) �������ӳ�乤������ӳ�� guest physical address �� physical address
;       2) ��������޸����������޸� EPT violation �� EPT misconfiguration
;       3) legacyģʽ��ʹ��
;
; page attribute ˵����
;       ecx ���ݹ����� attribute �������־λ��ɣ�
;       [0]    - Read
;       [1]    - Write
;       [2]    - Execute
;       [5:3]  - EPT memory type
;       [27:6] - ����
;       [26]   - FIX_ACCESS, ��λʱ������ access right �޸�����
;       [27]   - FIX_MISCONF����λʱ������ misconfiguration �޸�����
;       [28]   - EPT_FIXING����λʱ����Ҫ�����޸�������������ӳ�乤��
;              - EPT_FIXING ��λʱ������ӳ�乤��
;       [29] - FORCE����λʱ��ǿ�ƽ���ӳ��
;       [31:30] - ����
;----------------------------------------------------------        
do_guest_physical_address_mapping32:
        push eax
        push ecx
        push edx
        push ebx
        push ebp
        push esi
        push edi

%define STACK_EAX_OFFSET                24
%define STACK_ECX_OFFSET                20
%define STACK_EDX_OFFSET                16
%define STACK_EBX_OFFSET                12    
%define STACK_EBP_OFFSET                 8
%define STACK_ESI_OFFSET                 4
%define STACK_EDI_OFFSET                 0

        ;;
        ;; EPT ӳ��˵����
        ;; 1) ����ӳ���ʹ�� 4K-page ����
        ;; 2) �� PML4T(PXT)��PDPT(PPT) �Լ� PDT ���ϣ�����Ȩ�޶����� Read/Write/Execute
        ;; 3) �����һ�� PT ���ϣ�����Ȩ��������� ecx ����(page attribute)
        ;; 4) ����ҳ����Ҫʹ�� get_ept_page ��̬���䣨�� Kernel pool �ڷ��䣩
        ;;
        ;;
        ;; page attribute ʹ��˵����
        ;; 1) FIX_MISCONF=1 ʱ�������޸� EPT misconfiguration ����.
        ;; 2) FIX_ACCESS=1 ʱ�������޸� EPT violation ����
        ;; 3) GET_PTE=1ʱ��������Ҫ���� PTE ֵ
        ;; 4) GET_PAGE_FRAME=1ʱ��������Ҫ���� page frame
        ;; 5) EPT_FORCE=1ʱ������ǿ��ӳ��
        ;;

        mov ecx, (47 - 11)                                      ; ��ʼ shr count

        ;;
        ;; ��ȡ��ǰ VMB �� EP4TA ֵ
        ;;
        mov ebp, [gs: PCB.CurrentVmbPointer]
        mov ebp, [ebp + VMB.Ep4taBase]                          ; ebp = EPT PML4T �����ַ

        
        ;;
        ;; ������� EPT paging structure walk ����
        ;;
do_guest_physical_address_mapping32.Walk:

        mov ebx, [esp + STACK_ECX_OFFSET]                       ; ebx = page attribute
        
        ;;
        ;; ��ȡ EPT ����
        ;;
        mov esi, ecx        
        mov edx, [esp + STACK_EDI_OFFSET]
        mov eax, [esp + STACK_ESI_OFFSET]                       ; edx:eax = GPA, ecx = shr count
        call shr64
        and eax, 0FF8h                                          ; eax = EPT entry index
        add ebp, eax                                            ; ebp ָ�� EPT ����
        mov ecx, esi
        mov esi, [ebp]
        mov edi, [ebp + 4]                                      ; edi:esi = EPT ����ֵ
        
        
        ;;
        ;; ��� EPT �����Ƿ�Ϊ not present��������
        ;; 1) access right ��Ϊ 0
        ;; 2) EPT_VALID_FLAG
        ;;
        test esi, 7                                             ; access right = 0 ?
        jz do_guest_physical_address_mapping32.NotPrsent
        test esi, EPT_VALID_FLAG                                ; ��Ч��־λ = 0 ?
        jz do_guest_physical_address_mapping32.NotPrsent

        ;;
        ;; �� EPT ����Ϊ Present ʱ
        ;;
        test ebx, FIX_MISCONF
        jz do_guest_physical_address_mapping32.CheckFix
        
        ;;
        ;; �����޸� EPT misconfiguration ����
        ;;        
        and edi, ~EPT_LEVEL_MASK32                              ; ������� level ����
        call get_ept_entry_level_attribute32
        or edi, edx                                             ; ���� level ����
        or esi, eax
        call do_ept_entry_misconf_fixing32                      ; edi:esi = EPT ����
        cmp eax, MAPPING_SUCCESS
        jne do_guest_physical_address_mapping32.Done
        mov [ebp], esi
        mov [ebp + 4], edi        
                
do_guest_physical_address_mapping32.CheckFix:        
        test ebx, FIX_ACCESS
        jz do_guest_physical_address_mapping32.CheckGetPageFrame
        
        ;;
        ;; �����޸� EPT violation ����
        ;; 
        call do_ept_entry_violation_fixing32                    ; edi:esi = ���ebx = attribute
        cmp eax, MAPPING_SUCCESS
        jne do_guest_physical_address_mapping32.Done
        mov [ebp], esi
        mov [ebp + 4], edi
        
do_guest_physical_address_mapping32.CheckGetPageFrame:              
        ;;
        ;; ��ȡ��������
        ;;
        and esi, ~0FFFh                                         ; �� bits 11:0
        and edi, [gs: PCB.MaxPhyAddrSelectMask + 4]             ; ȡ��ֵַ
        
        ;;
        ;; ����Ƿ����� PTE
        ;;
        cmp ecx, (47 - 11 - 9 - 9 - 9)
        jne do_guest_physical_address_mapping32.Next
        
        ;;
        ;; �����Ҫ���� PTE ��������
        ;;
        test ebx, GET_PTE
        mov edx, [ebp + 4]
        mov eax, [ebp]
        jnz do_guest_physical_address_mapping32.Done
        
        ;;
        ;; �����Ҫ���� page frame ֵ 
        ;;
        test ebx, GET_PAGE_FRAME
        mov edx, edi
        mov eax, esi
        jnz do_guest_physical_address_mapping32.Done
        
        ;;
        ;; �������ǿ��ӳ��
        ;;
        test ebx, EPT_FORCE
        jnz do_guest_physical_address_mapping32.BuildPte
        
        mov eax, MAPPING_USED
        jmp do_guest_physical_address_mapping32.Done
        
        
do_guest_physical_address_mapping32.Next:
        ;;
        ;; �������� walk 
        ;;
        call get_ept_pt_virtual_address
        mov ebp, eax                                            ; ebp = EPT ҳ���ַ
        jmp do_guest_physical_address_mapping32.NextWalk
        
        
        
do_guest_physical_address_mapping32.NotPrsent:  
        ;;
        ;; �� EPT ����Ϊ not present ʱ
        ;; 1) ��� FIX_MISCONF ��־λ����������޸� EPT misconfiguration ʱ�����󷵻�
        ;; 2) ������Զ�ȡ page frame ֵ�����󷵻�
        ;;
        test ebx, (FIX_MISCONF | GET_PAGE_FRAME)
        mov eax, MAPPING_UNSUCCESS
        jnz do_guest_physical_address_mapping32.Done


do_guest_physical_address_mapping32.BuildPte:
        ;;
        ;; ���� PTE ����ֵ
        ;;
        mov esi, ebx
        and esi, 07                                             ; �ṩ�� page frame ����Ȩ��
        or esi, EPT_VALID_FLAG                                  ; ��Ч��־λ
        or esi, [esp + STACK_EAX_OFFSET]
        mov edi, [esp + STACK_EDX_OFFSET]                       ; edi:esi = Ҫд��� PTE
        
        ;;
        ;; ����Ƿ����� PTE
        ;; 1���ǣ�д���ṩ�� HPA ֵ
        ;; 2���񣺷��� EPT ҳ��
        ;;
        cmp ecx, (47 - 11 - 9 - 9 - 9)
        je do_guest_physical_address_mapping32.WriteEptEntry
        
        ;;
        ;; ������� EPT ҳ�棬��Ϊ��һ��ҳ��
        ;;        
        call get_ept_page                                       ; edx:eax = pa:va                
        or edx, EPT_VALID_FLAG | EPT_READ | EPT_WRITE | EPT_EXECUTE
        mov esi, edx
        xor edi, edi
        mov ebx, eax
        
do_guest_physical_address_mapping32.WriteEptEntry:
        ;;
        ;; ���ɱ���ֵ��д��ҳ��
        ;;
        call get_ept_entry_level_attribute32                    ; �õ� EPT ����㼶����
        or edi, edx
        or esi, eax
                                
        ;;
        ;; д�� EPT ��������
        ;;
        mov [ebp], esi
        mov [ebp + 4], edi
        mov ebp, ebx                                            ; ebp = EPT ���ַ      


do_guest_physical_address_mapping32.NextWalk:
        ;;
        ;; ִ�м��� walk ����
        ;;
        cmp ecx, (47 - 11 - 9 - 9 - 9)
        lea ecx, [ecx - 9]                                      ; ��һ��ҳ��� shr count
        jne do_guest_physical_address_mapping32.Walk

        mov eax, MAPPING_SUCCESS
        
do_guest_physical_address_mapping32.Done:
              
        mov [esp + STACK_EAX_OFFSET], eax

;;################################################
;; ע�⣺������ PTE ����ʱ��������Ҫд�� EDX ����ֵ #
;;       ���ﱣ���⹦�ܡ�!                        #
;;################################################
        ;;; mov [esp + STACK_EDX_OFFSET], edx                       
        
%undef STACK_EAX_OFFSET
%undef STACK_ECX_OFFSET
%undef STACK_EDX_OFFSET
%undef STACK_EBX_OFFSET
%undef STACK_EBP_OFFSET
%undef STACK_ESI_OFFSET
%undef STACK_EDI_OFFSET
        
        pop edi
        pop esi
        pop ebp
        pop ebx
        pop edx
        pop ecx        
        pop eax        
        ret
        
        
        
        
        
;---------------------------------------------------------------
; do_guest_physical_address_mapping32_n()
; input:
;       edi:esi - guest physical address
;       edx:eax - physical address
;       ecx - page attribute
;       [ebp + 28] - count
; output:
;       0 - succssful, otherwise - error code
; ����:
;       1) ���� n ҳ�� guest physical address ӳ��
;---------------------------------------------------------------
do_guest_physical_address_mapping32_n:
        push ebp
        push edi
        push esi
        push edx
        push eax
        push ecx
        
        mov ebp, esp

%define STACK_EBP_OFFSET                20
%define STACK_EDI_OFFSET                16
%define STACK_ESI_OFFSET                12
%define STACK_EDX_OFFSET                 8
%define STACK_EAX_OFFSET                 4
%define STACK_ECX_OFFSET                 0
%define VAR_COUNT_OFFSET                28
        
        
do_guest_physical_address_mapping32_n.Loop:
        mov esi, [ebp + STACK_ESI_OFFSET]
        mov edi, [ebp + STACK_EDI_OFFSET]
        mov eax, [ebp + STACK_EAX_OFFSET]
        mov edx, [ebp + STACK_EDX_OFFSET]
        call do_guest_physical_address_mapping32
        cmp eax, MAPPING_SUCCESS
        jne do_guest_physical_address_mapping32_n.done
        
        add DWORD [ebp + STACK_ESI_OFFSET], 1000h
        add DWORD [ebp + STACK_EAX_OFFSET], 1000h
        dec DWORD [ebp + VAR_COUNT_OFFSET]
        jnz do_guest_physical_address_mapping32_n.Loop
        
        mov eax, MAPPING_SUCCESS
        
do_guest_physical_address_mapping32_n.done:
        
        pop ecx
        pop eax
        pop edx
        pop esi
        pop edi
        pop ebp
        ret 4




;---------------------------------------------------------------
; do_ept_entry_misconf_fixing32()
; input:
;       edi:esi - table entry of EPT_MISCONFIGURATION
; output:
;       eax - 0 = successful�� otherwise = error code
; ������
;       1) �޸��ṩ�� EPT table entry ֵ
; ������
;       edi:esi - �ṩ���� EPT misconfiguration �� EPT ����޸��󷵻� EPT ����
;       eax - Ϊ 0 ʱ��ʾ�ɹ�������Ϊ������
;---------------------------------------------------------------
do_ept_entry_misconf_fixing32:
        push ecx
        
        ;;
        ;; EPT misconfigruation �Ĳ�����
        ;; 1) ����� access right Ϊ 010B��write-only������ 110B��write/execute��
        ;; 2) ����� access right Ϊ 100B��execute-only������ VMX ����֧�� execute-only ����
        ;; 3) �������� present �ģ�access right ��Ϊ 000B����
        ;;      3.1) ����λ��Ϊ 0������bits 51:M Ϊ����λ����� M ֵ���� MAXPHYADDR ֵ
        ;;      3.2) page frame �� memory type ��֧�֣�Ϊ 2, 3 ���� 7
        ;;
        
        mov eax, MAPPING_UNSUCCESS
        
        ;;
        ;; ���Ϊ not present��ֱ�ӷ���
        ;;        
        test esi, 7
        jz do_ept_entry_misconf_fixing32.done
        
        
        mov eax, esi
        and eax, 7

        ;;
        ;; ### ���1��access right �Ƿ�Ϊ 100B��execute-only��
        ;;
        cmp eax, EPT_EXECUTE
        jne do_ept_entry_misconf_fixing32.@1
        
        ;;
        ;; ��� VMX �Ƿ�֧�� execute-only
        ;;
        test DWORD [gs: PCB.EptVpidCap], 1
        jnz do_ept_entry_misconf_fixing32.@2
        
do_ept_entry_misconf_fixing32.@1:
        ;;
        ;; ���ﲻ��� access right �Ƿ�Ϊ 010B��write-only�� ���� 110B��write/execute��
        ;; ����ֱ����� read Ȩ��
        ;;
        or esi, EPT_READ
        
                
do_ept_entry_misconf_fixing32.@2:
        ;;
        ;; ���ﲻ��鱣��λ
        ;; 1) ����ֱ�ӽ� bits 51:M λ�� 0
        ;; 2) ���� bits 63:52������λ����ֵ
        ;;
        mov eax, 0FFF00000h                                     ; bits 63:52
        or eax, [gs: PCB.MaxPhyAddrSelectMask + 4]              ; bits 63:52, bits M-1:0
        and edi, eax
        
        
        
do_ept_entry_misconf_fixing32.@3:
        ;;
        ;; ������ PML4E ʱ���� bits 7:3�������� bits 6:3
        ;;
        mov eax, ~78h                                           ; ~ bits 6:3
        
        shld ecx, edi, 12
        and ecx, 7                                              ; ȡ bits 54:52��ҳ�� level ֵ
        cmp ecx, 1
        jne do_ept_entry_misconf_fixing32.@31
        
        mov eax, ~0F8h                                          ; ~ bits 7:3
        
        
do_ept_entry_misconf_fixing32.@31:        

        ;;
        ;; ������� PTE ʱ������ bit6��IPATλ�������� memory type ��Ϊ PCB.EptMemoryType ֵ
        ;;
        cmp ecx, 4
        jne do_ept_entry_misconf_fixing32.@32

        or eax, EPT_IPAT
        and esi, eax                                            ; ȥ�� bits 5:3        
        mov eax, [gs: PCB.EptMemoryType]
        shl eax, 3                                              ; ept memory type
        or esi, eax
        mov eax, MAPPING_SUCCESS
        jmp do_ept_entry_misconf_fixing32.done       
                
                
do_ept_entry_misconf_fixing32.@32:
        
        and esi, eax

        mov eax, MAPPING_SUCCESS                            
        
do_ept_entry_misconf_fixing32.done:   
        pop ecx
        ret




;---------------------------------------------------------------
; do_ept_entry_violation_fixing32()
; input:
;       edi:esi - table entry
;       ebx - attribute
; output:
;       eax - 0 = successful�� otherwise = error code
; ������
;       1) �޸������ EPT violation ����
; ����˵����
;       1) rsi �ṩ��Ҫ�޸��ı���
;       2) edi �ṩ������ֵ��
;       [0]    - read access
;       [1]    - write access
;       [2]    - execute access
;       [3]    - readable
;       [4]    - writeable
;       [5]    - excutable
;       [6]    - ����
;       [7]    - valid of guest-linear address
;       [8]    - translation
;       [27:9] - ����
;       [26]   - FIX_ACCESS, ��λʱ������ access right �޸�����
;       [27]   - FIX_MISCONF����λʱ������ misconfiguration �޸�����
;       [28]   - EPT_FIXING����λʱ����Ҫ�����޸�������������ӳ�乤��
;              - EPT_FIXING ��λʱ������ӳ�乤��
;       [29] - FORCE����λʱ��ǿ�ƽ���ӳ��
;       [31:30] - ����
;---------------------------------------------------------------        
do_ept_entry_violation_fixing32:
        push ebx
        

        ;;
        ;; EPT violation �Ĳ���:
        ;; 1) ���� guest-physical address ʱ������ not-present
        ;; 2) �� guest-physical address ���ж����ʣ��� EPT paging-structure ����� bit0 Ϊ 0
        ;; 3) �� guest-physical address ����д���ʣ��� EPT paging-structure ����� bit1 Ϊ 0
        ;; 4) EPTP[6] = 1 ʱ���ڸ��� guest paging-structure ����� accessed �� dirty λʱ����Ϊ��д���ʡ�
        ;;                    ��ʱ EPT paging-structure ����� bit1 Ϊ 0
        ;; 5) �� guest-physical address ���� fetch������execute������ EPT paging-structure ����� bit2 Ϊ 0
        ;;
        
        mov eax, MAPPING_UNSUCCESS
        
        test esi, 7
        jz do_ept_entry_violation_fixing32.done
        
        ;;
        ;; �޸�����:
        ;; 1) ���ﲻ�޸� not-present ����
        ;; 2) �����Ӧ�ķ���Ȩ�ޣ�������ֵ ���� attribute[2:0] ֵ
        ;;
        and ebx, 7
        or esi, ebx

        mov eax, MAPPING_SUCCESS
                
do_ept_entry_violation_fixing32.done:
        pop ebx
        ret
        
        
        
        
        
;---------------------------------------------------------------
; check_fix_misconfiguration()
; input:
;       edi:esi - table entry
;       ebp - address of table entry
; output:
;       0 - Ok, otherwisw - misconfiguration code
; ������
;       1) �������Ƿ��� misconfiguration�����޸�
;---------------------------------------------------------------
check_fix_misconfiguration:
        push ecx
        push ebx
        
        ;;
        ;; misconfiguration ԭ��
        ;; 1) [2:0] = 010B��write-only�� �� 110B��execute/write��ʱ��
        ;; 2) [2:0] = 100B��execute-only������ VMX ����֧�� execute-only ʱ��
        ;; 3) [2:0] = 000B��not present��ʱ������ı���λ��Ϊ 0
        ;;    3.1) �����ڵ������ַ��Ȳ��ܳ��� MAXPHYADDR λ������ MAXPHYADDR ��Χ�ڣ�
        ;;    3.2) EPT memory type Ϊ���������ͣ��� 2,3 �� 7��
        ;;
        
        xor ecx, ecx
        mov eax, esi
        and eax, 07h                                            ; ��ȡ access right

check_fix_misconfiguration.@1:
        ;;
        ;; ��� access right
        ;;        
        cmp eax, EPT_WRITE
        je check_fix_misconfigurate.AccessRight
        cmp eax, EPT_WRITE | EPT_EXECUTE
        je check_fix_misconfigurate.AccessRight
        cmp eax, EPT_EXECUTE
        je check_fix_misconfigurate.ExecuteOnly

check_fix_misconfiguration.@2:
        cmp eax, 0                                              ; not present ?
        je check_fix_misconfiguration.done
        
        ;;
        ;; ȷ�������ַ�� MAXPHYADDR ֵ�� 
        ;;
        and edi, [gs: PCB.MaxPhyAddrSelectMask + 4]             ; ��� MAXPHYADDR ���ֵ
        
        ;;
        ;; ע�⣺����ͳһ����
        ;; 1) ���� memory type ����Ϊ WB��֧��ʱ���� UC����֧�� WB ʱ������
        ;; 2) �������������龰�������Ƿ�Ϊ�������������ڴ����ͣ�
        ;; 3) ��ˣ��������ڴ�����
        ;;
        and esi, 0FFFFFFC7h                                     ; ��ԭ memory type
        mov eax, [gs: PCB.EptMemoryType]
        shl eax, 3
        or esi, eax                                             ; ��� memory type
        
        jmp check_fix_misconfiguration.done
        
check_fix_misconfigurate.ExecuteOnly:
        ;;
        ;; ���� execute-only ����Ȩ��ʱ����Ҫ��� VMX �Ƿ�֧�� execute-only
        ;; 1) ���֧�֣����������
        ;; 2) ��֧��ʱ������� read Ȩ��
        ;;
        test DWORD [gs: PCB.EptVpidCap], 1
        jnz check_fix_misconfiguration.@2
        
check_fix_misconfigurate.AccessRight:
        ;;
        ;; �޸����� write-only��execute-only �� execute/write ����Ȩ��
        ;; 1) ����������£���� read Ȩ��
        ;;
        or esi, EPT_READ
        jmp check_fix_misconfiguration.@2
       

check_fix_misconfiguration.done:                
        ;;
        ;; д�� table entry
        ;;                
        mov [ebp], esi
        mov [ebp + 4], edi
        pop ebx                
        pop ecx
        ret




;---------------------------------------------------------------
; do_ept_page_fault()
; input:
;       none
; output:
;       0 - succssful, otherwise - error code
; ����:
;       1) ���� EPT �� page fualt ��������
;---------------------------------------------------------------
do_ept_page_fault:
        push ebp
        push ebx
        push ecx
        
        ;;
        ;; EPT page fault ����ԭ��Ϊ��
        ;; 1) EPT misconfiguration��EPT �� tage enties ���ò��Ϸ���
        ;; 2) EPT violation��EPT �ķ���Υ����
        ;;
        
        ;;
        ;; �� VM-exit information ��� guest physical address
        ;;
        mov esi, [gs: PCB.ExitInfoBuf + EXIT_INFO.GuestPhysicalAddress]
        mov edi, [gs: PCB.ExitInfoBuf + EXIT_INFO.GuestPhysicalAddress + 4]
        

        ;;
        ;; �� exit reason ֵ�����������ԭ����� VM-exit
        ;;
        mov eax, [gs: PCB.ExitInfoBuf + EXIT_INFO.ExitReason]
        cmp eax, EXIT_NUMBER_EPT_MISCONFIGURATION
        je do_ept_page_fault.EptMisconfiguration
        
        ;;
        ;; ���������� EPT violation ���� VM exit
        ;;
        mov ebx, [gs: PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        
        ;;
        ;; EPT violation �����ദ��˵����
        ;; 1) ���� entry �� not present ������ģ���Ҫ����ӳ��� guest physical address
        ;; 2) ���� access right ����������ģ��������Ӧ��Ȩ��
        ;;

        ;;
        ;; ����Ƿ�Ϊ not present ����
        ;;
        test ebx, 38h                                           ; execute/write/read = 0 ?
        jz do_ept_page_fault.NotPresent

        ;;
        ;; �������� access right Υ��
        ;; 1) ��ȡ Exit Qualification [2:0] ֵ��ȷ���Ǻ��� access ���� VM exit
        ;;
        mov ecx, ebx
        and ecx, 07h                                            ; access ֵ
        or ecx, EPT_FIXING | FIX_ACCESS                         ; �޸�Ȩ������
        
        ;;
        ;; תȥִ���޸�����
        ;; 1) edi:esi - guest physcial address
        ;; 2) ecx - page attribute
        ;;
        jmp do_ept_page_fault.Fixing

 
do_ept_page_fault.NotPresent:        
        ;;
        ;; ���� not present
        ;; 1) ����һ�� 4K �ռ䣨�� kernel pool �
        ;;
        call get_ept_page                                       ; edx:eax ���� pa:va
        mov eax, edx
        xor edx, edx
        mov ecx, EPT_READ | EPT_WRITE | EPT_EXECUTE
        
        ;;
        ;; תȥִ���޸�����
        ;; �� guest physical address ӳ�䵽�·���� page
        ;; 1) edi:esi - guest physical address
        ;; 2) edx:eax - physical address(page frame)
        ;; 3) ecx - R/W/E Ȩ��
        ;;
        jmp do_ept_page_fault.Fixing
        
        
do_ept_page_fault.EptMisconfiguration:
        ;;
        ;; ��������� EPT misconfiguration ���� VM exit��
        ;; ����� guest physical address ���� walk���޸� misconfiguration ����
        ;;        
        mov ecx, EPT_FIXING | FIX_MISCONF                       ; �����޸� misconfiguration ����
        
        ;;
        ;; ������� do_guest_physical_address_mapping() �����޸�����
        ;;
do_ept_page_fault.Fixing:        
        call do_guest_physical_address_mapping32
        
do_ept_page_fault.done:
        pop ecx
        pop ebx
        pop ebp
        ret
        
        


;-----------------------------------------------------------------------
; GetGpaHte()
; input:
;       esi - GPA
; output:
;       eax - GPA HTE��handler table entry����ַ
; ������
;       1) ���� GPA ��Ӧ�� HTE �����ַ
;       2) ��������Ӧ�� GPA Hte ʱ������ 0 ֵ
;-----------------------------------------------------------------------
GetGpaHte:
        push ebp
        push ebx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        cmp DWORD [ebx + VMB.GpaHteCount], 0
        je GetGpaHte.NotFound
        
        REX.Wrxb
        mov eax, [ebx + VMB.GpaHteBuffer]               
        
GetGpaHte.@1:                
        REX.Wrxb
        cmp esi, [eax]                                  ; ��� GPA ��ֵַ
        je GetGpaHte.Done
        REX.Wrxb
        add eax, GPA_HTE_SIZE                           ; ָ����һ�� entry
        REX.Wrxb
        cmp eax, [ebx + VMB.GpaHteIndex]
        jb GetGpaHte.@1
GetGpaHte.NotFound:        
        xor eax, eax
GetGpaHte.Done:        
        pop ebx
        pop ebp
        ret



;-----------------------------------------------------------------------
; AppendGpaHte()
; input:
;       esi - GPA ��ֵַ
;       edi - handler
; output:
;       eax - HTE ��ַ
; ������
;       1) ���� GPA ֵ�� GpaHteBuffer ��д�� HTE
;-----------------------------------------------------------------------
AppendGpaHte:
        push ebp
        push ebx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]     
        mov ebx, edi
        call GetGpaHte
        REX.Wrxb
        test eax, eax
        jnz AppendGpaHte.WriteHte
        
        mov eax, GPA_HTE_SIZE
        REX.Wrxb
        xadd [ebp + VMB.GpaHteIndex], eax
        inc DWORD [ebp + VMB.GpaHteCount]
                
AppendGpaHte.WriteHte:
        ;;
        ;; д�� HTE ����
        ;;
        REX.Wrxb
        mov [eax + GPA_HTE.GuestPhysicalAddress], esi
        REX.Wrxb
        mov [eax + GPA_HTE.Handler], ebx
        pop ebx
        pop ebp
        ret
        