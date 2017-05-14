;*************************************************
;* VmxPage64.asm                                 *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************




;---------------------------------------------------------------
; get_ept_pxe_offset64():
; input:
;       rsi - guest physical address
; output:
;       eax - offset
; ������
;       �õ� PXT entry �� offset ֵ
; ע�⣺
;       �� legacy ģʽ��ʹ��
;---------------------------------------------------------------
get_ept_pxe_offset64:
        shld rax, rsi, (32-4)                   
        and eax, 0FF8h                          ; bits 47:39 << 3
        ret
        

;---------------------------------------------------------------
; get_ept_ppe_offset64():
; input:
;       rsi - GPA
; output:
;       eax - offset
; ������
;       1) �õ� PPT entry �� offset ֵ
;---------------------------------------------------------------        
get_ept_ppe_offset64:
        shld rax, rsi, (32-4+9)                 
        and eax, 0FF8h                          ; bits 38:30 << 3
        ret
        


;---------------------------------------------------------------
; get_ept_pde_offset64():
; input:
;       rsi - GPA
; output:
;       eax - offset
; ������
;       1) �õ� PDT entry �� offset ֵ
;---------------------------------------------------------------
get_ept_pde_offset64:
        shld rax, rsi, (32-4+9+9)
        and eax, 0FF8h                          ; bits 29:21
        ret
        

;---------------------------------------------------------------
; get_ept_pte_offset64():
; input:
;       rsi - GPA
; output:
;       eax - offset
; ������
;       1) �õ� PT entry �� offset ֵ
;---------------------------------------------------------------  
get_ept_pte_offset64:
        shld rax, rsi, (32-4+9+9+9)
        and eax, 0FF8h                          ; bits 20:12
        ret
        
        
;----------------------------------------------------------
; get_ept_entry_level_attribute()
; input:
;       esi - shld count
; output:
;       esi - level number
;----------------------------------------------------------
get_ept_entry_level_attribute:
        cmp esi, (32 - 4)
        je get_ept_entry_level_attribute.@1
        
        cmp esi, (32 - 4 + 9)
        je get_ept_entry_level_attribute.@2
        
        cmp esi, (32 - 4 + 9 + 9)
        je get_ept_entry_level_attribute.@3
        
        cmp esi, (32 - 4 + 9 + 9 + 9)
        je get_ept_entry_level_attribute.@4
        
        xor esi, esi
        jmp get_ept_entry_level_attribute.Done
        
get_ept_entry_level_attribute.@1:
        mov rsi, EPT_PML4E
        jmp get_ept_entry_level_attribute.Done

get_ept_entry_level_attribute.@2:
        mov rsi, EPT_PDPTE
        jmp get_ept_entry_level_attribute.Done
        
get_ept_entry_level_attribute.@3:
        mov rsi, EPT_PDE
        jmp get_ept_entry_level_attribute.Done
        
get_ept_entry_level_attribute.@4:
        mov rsi, (EPT_PTE | EPT_MEM_WB)                         ;; PTE ʹ�� WB �ڴ�����
                                        
get_ept_entry_level_attribute.Done:                
        ret


;----------------------------------------------------------
; do_guest_physical_address_mapping64()
; input:
;       rsi - guest physical address
;       rdi - physical address
;       eax - page attribute
; output:
;       0 - successful, otherwise - error code
; ������
;       1) �������ӳ�乤������ӳ�� guest-physical address �� physical addrss
;       2) ��������޸����������޸� EPT violation �� EPT misconfiguration
;
; page attribute ˵����
;       eax ���ݹ����� attribute �������־λ��ɣ�
;       [0]    - Read
;       [1]    - Write
;       [2]    - Execute
;       [23:3] - ����
;       [24]   - GET_PTE
;       [25]   - GET_PAGE_FRAME
;       [26]   - FIX_ACCESS, ��λʱ������ access right �޸�����
;       [27]   - FIX_MISCONF����λʱ������ misconfiguration �޸�����
;       [28]   - EPT_FIXING����λʱ����Ҫ�����޸�������������ӳ�乤��
;              - EPT_FIXING ��λʱ������ӳ�乤��
;       [29]   - EPT_FORCE����λʱ��ǿ�ƽ���ӳ��
;       [31:30] - ����
;----------------------------------------------------------
do_guest_physical_address_mapping64:
        push rbp
        push rdx
        push rbx
        push rcx
        push r10
        push r11

        
        
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
        
        
        mov r10, rsi                                    ; r10 = GPA
        mov r11, rdi                                    ; r11 = HPA
        mov ebx, eax                                    ; ebx = page attribute
        mov ecx, (32 - 4)                               ; ecx = EPT ���� index ����λ����shld��
        
        ;;
        ;; ��ȡ��ǰ VMB �� EP4TA ֵ
        ;;
        mov rbp, [gs: PCB.CurrentVmbPointer]
        mov rbp, [rbp + VMB.Ep4taBase]                  ; rbp = EPT PML4T �����ַ


do_guest_physical_address_mapping64.Walk:
        ;;
        ;; EPT paging structure walk ����
        ;;
        shld rax, r10, cl
        and eax, 0FF8h
        
        ;;
        ;; ��ȡ EPT ����
        ;;
        add rbp, rax                                    ; rbp ָ�� EPT ����
        mov rsi, [rbp]                                  ; rsi = EPT ����ֵ
        
        
        ;;
        ;; ��� EPT �����Ƿ�Ϊ not present��������
        ;; 1) access right ��Ϊ 0
        ;; 2) EPT_VALID_FLAG
        ;;
        test esi, 7                                             ; access right = 0 ?
        jz do_guest_physical_address_mapping64.NotPrsent
        test esi, EPT_VALID_FLAG                                ; ��Ч��־λ = 0 ?
        jz do_guest_physical_address_mapping64.NotPrsent

        ;;
        ;; �� EPT ����Ϊ Present ʱ
        ;;
        test ebx, FIX_MISCONF
        jz do_guest_physical_address_mapping64.CheckFix
        
        ;;
        ;; �����޸� EPT misconfiguration ����
        ;;        
        mov rax, ~EPT_LEVEL_MASK
        and rax, rsi                                            ; ������� level ����
        mov esi, ecx
        call get_ept_entry_level_attribute
        or rsi, rax                                             ; ���� level ����
        call do_ept_entry_misconf_fixing64
        cmp eax, MAPPING_SUCCESS
        jne do_guest_physical_address_mapping64.Done
        mov [rbp], rsi                                          ; д�ر���ֵ��
                
do_guest_physical_address_mapping64.CheckFix:        
        test ebx, FIX_ACCESS
        jz do_guest_physical_address_mapping64.CheckGetPageFrame
        
        ;;
        ;; �����޸� EPT violation ����
        ;; 
        mov edi, ebx                                            ; rsi = ����, ebx = page attribute
        call do_ept_entry_violation_fixing64
        cmp eax, MAPPING_SUCCESS
        jne do_guest_physical_address_mapping64.Done
        mov [rbp], rsi                                          ; д�ر���ֵ
        
do_guest_physical_address_mapping64.CheckGetPageFrame:              
        ;;
        ;; ��ȡ��������
        ;;
        and rsi, ~0FFFh                                         ; �� bits 11:0
        and rsi, [gs: PCB.MaxPhyAddrSelectMask]                 ; ȡ��ֵַ
        
        ;;
        ;; ����Ƿ����� PTE
        ;;
        cmp ecx, (32 - 4 + 9 + 9 + 9)
        jne do_guest_physical_address_mapping64.Next
        
        ;;
        ;; �����Ҫ���� PTE ��������
        ;;
        test ebx, GET_PTE
        mov rax, [rbp]        
        jnz do_guest_physical_address_mapping64.Done
        
        ;;
        ;; �����Ҫ���� page frame ֵ 
        ;;
        test ebx, GET_PAGE_FRAME
        mov rax, rsi
        jnz do_guest_physical_address_mapping64.Done
        
        ;;
        ;; �������ǿ��ӳ��
        ;;
        test ebx, EPT_FORCE
        jnz do_guest_physical_address_mapping64.BuildPte
        
        mov eax, MAPPING_USED
        jmp do_guest_physical_address_mapping64.Done
        
        
do_guest_physical_address_mapping64.Next:
        ;;
        ;; �������� walk 
        ;;
        call get_ept_pt_virtual_address
        mov rbp, rax                                            ; rbp = EPT ҳ���ַ
        jmp do_guest_physical_address_mapping64.NextWalk
        
        
        
do_guest_physical_address_mapping64.NotPrsent:     
        ;;
        ;; �� EPT ����Ϊ not present ʱ
        ;; 1) ��� FIX_MISCONF ��־λ����������޸� EPT misconfiguration ʱ�����󷵻�
        ;; 2) ������Զ�ȡ page frame ֵ�����󷵻�
        ;;
        test ebx, (FIX_MISCONF | GET_PAGE_FRAME)
        mov eax, MAPPING_UNSUCCESS
        jnz do_guest_physical_address_mapping64.Done


do_guest_physical_address_mapping64.BuildPte:
        ;;
        ;; ���� PTE ����ֵ
        ;;
        mov edx, ebx
        and edx, 07                                             ; �ṩ�� page frame ����Ȩ��
        or edx, EPT_VALID_FLAG                                  ; ��Ч��־λ
        or rdx, r11                                             ; �ṩ�� HPA 
        
        ;;
        ;; ����Ƿ����� PTE �㼶
        ;; 1���ǣ�д�����ɵ� PTE ֵ
        ;; 2���񣺷��� EPT ҳ��
        ;;
        cmp ecx, (32 - 4 + 9 + 9 + 9)
        je do_guest_physical_address_mapping64.WriteEptEntry

        ;;
        ;; ������� EPT ҳ�棬��Ϊ��һ��ҳ��
        ;;        
        call get_ept_page                                       ; rdx:rax = pa:va                
        or rdx, EPT_VALID_FLAG | EPT_READ | EPT_WRITE | EPT_EXECUTE
        
do_guest_physical_address_mapping64.WriteEptEntry:
        ;;
        ;; ���ɱ���ֵ��д��ҳ��
        ;;
        mov esi, ecx
        call get_ept_entry_level_attribute                      ; �õ� EPT ����㼶����
        or rdx, rsi
                                
        ;;
        ;; д�� EPT ��������
        ;;
        mov [rbp], rdx
        mov rbp, rax                                            ; rbp = EPT ���ַ      

do_guest_physical_address_mapping64.NextWalk:
        ;;
        ;; ִ�м��� walk ����
        ;;
        cmp ecx, (32 - 4 + 9 + 9 + 9)
        lea rcx, [rcx + 9]                                      ; ��һ��ҳ��� shld count
        jne do_guest_physical_address_mapping64.Walk
        
        mov eax, MAPPING_SUCCESS
        
do_guest_physical_address_mapping64.Done:
        pop r11                
        pop r10
        pop rcx
        pop rbx
        pop rdx
        pop rbp
        ret

        
        

;---------------------------------------------------------------
; do_guest_physical_address_mapping64_n()
; input:
;       rsi - guest physical address
;       rdi - physical address
;       eax - page attribute
;       ecx - count
; output:
;       0 - succssful, otherwise - error code
; ����:
;       1) ���� n ҳ�� guest physical address ӳ��
;---------------------------------------------------------------
do_guest_physical_address_mapping64_n:
        push rbx
        push rcx
        push r10
        push r11
        
        mov r10, rsi
        mov r11, rdi
        mov ebx, eax

do_guest_physical_address_mapping64_n.Loop:
        mov rsi, r10
        mov rdi, r11
        mov eax, ebx
        call do_guest_physical_address_mapping64
        cmp eax, MAPPING_SUCCESS
        jne do_guest_physical_address_mapping64_n.done
        
        add r10, 1000h
        add r11, 1000h
        dec ecx
        jnz do_guest_physical_address_mapping64_n.Loop
        
        mov eax, MAPPING_SUCCESS

do_guest_physical_address_mapping64_n.done:        
        pop r11
        pop r10
        pop rcx
        pop rbx
        ret
        
        


;---------------------------------------------------------------
; do_ept_page_fault64()
; input:
;       none
; output:
;       0 - succssful, otherwise - error code
; ����:
;       1) ���� EPT �� page fualt ��������
;---------------------------------------------------------------        
do_ept_page_fault64:
        push rbx
        push rcx
        
        ;;
        ;; EPT page fault ����ԭ��Ϊ��
        ;; 1) EPT misconfiguration��EPT �� tage enties ���ò��Ϸ���
        ;; 2) EPT violation��EPT �ķ���Υ����
        ;;
        
        ;;
        ;; �� VM-exit information ��� guest physical address
        ;;
        mov rsi, [gs: PCB.ExitInfoBuf + EXIT_INFO.GuestPhysicalAddress]
        
        
        ;;
        ;; �� exit reason��ȷ������ԭ����� VM-exit
        ;;
        mov eax, [gs: PCB.ExitInfoBuf + EXIT_INFO.ExitReason]
        cmp ax, EXIT_NUMBER_EPT_MISCONFIGURATION
        je do_ept_page_fault64.EptMisconf
        
        ;;
        ;; Exit qualification �ֶα�����ϸ��Ϣ��
        ;; 1) bits 8:7 = 0 ʱ��ִ�� MOV to CR3 ָ������ EPT violation
        ;; 2) bits 8:7 = 1 ʱ���ڷ��� guest paging-structure ʱ���� EPT violation
        ;; 3) bits 8:7 = 3 ʱ, �� guest-physical address ���� EPT violation
        ;;
        ;; �޸� EPT violation ˵����
        ;; 1) �ɡ�MOV to CR3�� �� guest paging-structure ����� EPT violation���޸�ʱ GPA �� HPA һһ��Ӧ
        ;; 2) �� guest-physical address ����� EPT violation���޸�ʱ��̬���� EPT ҳ��
        ;;       
        mov ebx, [gs: PCB.ExitInfoBuf + EXIT_INFO.ExitQualification]
        mov ecx, ebx
        and ecx, 18h                                            ; ȡ bits 8:7
        jz do_ept_page_fault64.EptViolation1
        cmp ecx, 08h
        jz do_ept_page_fault64.EptViolation1
        
        ;;
        ;; ִ��һ���޸�
        ;;
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE | EPT_FIXING | FIX_ACCESS
        
do_ept_page_fault64.EptViolation1:
        ;;
        ;; ʵ��һһ��Ӧ����ӳ��
        ;;
        mov rdi, rsi
        mov eax, EPT_READ | EPT_WRITE | EPT_EXECUTE
        
        
        
do_ept_page_fault64.EptMisconf:


        call do_guest_physical_address_mapping64

do_ept_page_fault64.done:
        pop rcx
        pop rbx
        ret
        
        
        

;---------------------------------------------------------------
; do_ept_entry_misconf_fixing64()
; input:
;       rsi - table entry of EPT_MISCONFIGURATION
; output:
;       eax - 0 = successful�� otherwise = error code
; ������
;       1) �޸��ṩ�� EPT table entry ֵ
; ������
;       rsi - �ṩ���� EPT misconfiguration �� EPT ����޸��󷵻� EPT ����
;       eax - Ϊ 0 ʱ��ʾ�ɹ�������Ϊ������
;---------------------------------------------------------------
do_ept_entry_misconf_fixing64:
        push rcx

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
        ;; ���Ϊ not present����ֱ�ӷ���
        ;;
        test esi, 7
        jz do_ept_entry_misconf_fixing64.done
        
        
        mov rax, rsi
        and eax, 7
        
        ;;
        ;; ### ���1��access right �Ƿ�Ϊ 100B��execute-only��
        ;;
        cmp eax, EPT_EXECUTE
        jne do_ept_entry_misconf_fixing64.@1
        
        ;;
        ;; ��� VMX �Ƿ�֧�� execute-only
        ;;
        test DWORD [gs: PCB.EptVpidCap], 1
        jnz do_ept_entry_misconf_fixing64.@2
        
do_ept_entry_misconf_fixing64.@1:
        ;;
        ;; ���ﲻ��� access right �Ƿ�Ϊ 010B��write-only�� ���� 110B��write/execute��
        ;; ����ֱ����� read Ȩ��
        ;;
        or rsi, EPT_READ                                
        


do_ept_entry_misconf_fixing64.@2:
        ;;
        ;; ���ﲻ��鱣��λ
        ;; 1) ����ֱ�ӽ� bits 51:M λ�� 0
        ;; 2) ���� bits 63:52������λ����ֵ
        ;;
        mov rax, 0FFF0000000000000h                             ; bits 63:52
        or rax, [gs: PCB.MaxPhyAddrSelectMask]                  ; bits 63:52, bits M-1:0
        and rsi, rax

        
do_ept_entry_misconf_fixing64.@3:
        ;;
        ;; ������ PML4E ʱ���� bits 7:3�������� bits 6:3
        ;;
        mov rax, ~78h                                           ; ~ bits 6:3
        
        shld rcx, rsi, 12
        and ecx, 7                                              ; ȡ bits 54:52��ҳ����
        cmp ecx, 1
        jne do_ept_entry_misconf_fixing64.@31
        
        mov rax, ~0F8h                                          ; ~ bits 7:3
        
do_ept_entry_misconf_fixing64.@31:        

        ;;
        ;; ������� PTE ʱ������ bit6��IPATλ�������� memory type ��Ϊ PCB.EptMemoryType ֵ
        ;;
        cmp ecx, 4
        jne do_ept_entry_misconf_fixing64.@32

        or rax, EPT_IPAT
        and rsi, rax                                            ; ȥ�� bits 5:3        
        mov eax, [gs: PCB.EptMemoryType]
        shl eax, 3                                              ; ept memory type
        or rsi, rax
        mov eax, MAPPING_SUCCESS
        jmp do_ept_entry_misconf_fixing64.done             
                    
                    
do_ept_entry_misconf_fixing64.@32:
        
        and rsi, rax       

        mov eax, MAPPING_SUCCESS                            
        
do_ept_entry_misconf_fixing64.done:            
        pop rcx
        ret
        





;---------------------------------------------------------------
; do_ept_entry_violation_fixing64()
; input:
;       rsi - table entry
;       edi - attribute
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
do_ept_entry_violation_fixing64:
        push rcx
        
        

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
        jz do_ept_entry_violation_fixing64.done
        
        ;;
        ;; �޸�����:
        ;; 1) ���ﲻ�޸� not-present ����
        ;; 2) �����Ӧ�ķ���Ȩ�ޣ�������ֵ ���� attribute[2:0] ֵ
        ;;
        mov ecx, edi
        and ecx, 7
        or rsi, rcx
       
        mov eax, MAPPING_SUCCESS
                
do_ept_entry_violation_fixing64.done:
        pop rcx
        ret




;---------------------------------------------------------------
; dump_ept_paging_structure64()
; input:
;       rsi - guest-physical address
; output:
;       none
; ��������
;       1) ��ӡ EPT paging structure ����
;---------------------------------------------------------------
dump_ept_paging_structure64:
        push rbp
        push rbx
        push rcx
        push rdx
        push r10

        
        mov r10, rsi                                    ; r10 = GPA
        mov ecx, (32 - 4)                               ; ecx = EPT ���� index ����λ����shld��
        
        ;;
        ;; ��ȡ��ǰ VMB �� EP4TA ֵ
        ;;
        mov rbp, [gs: PCB.CurrentVmbPointer]
        mov rbp, [rbp + VMB.Ep4taBase]                  ; rbp = EPT PML4T �����ַ

        ;;
        ;; ����Ƿ�����Ƕ�״�ӡ
        ;;
        mov edx, Ept.NestEntryMsg
        test DWORD [Ept.DumpPageFlag], DUMP_PAGE_NEST
        jnz dump_ept_paging_structure64.Walk
        
        mov edx, Ept.EntryMsg
        mov esi, Ept.DumpMsg1
        call puts
        mov rsi, r10
        call print_qword_value64
        mov esi, Ept.DumpMsg2
        call puts

dump_ept_paging_structure64.Walk:
        ;;
        ;; EPT paging structure walk ����
        ;;
        shld rax, r10, cl
        and eax, 0FF8h
        
        ;;
        ;; ��ȡ EPT ����
        ;;
        add rbp, rax                                    ; rbp ָ�� EPT ����
        mov rbx, [rbp]                                  ; rbx = EPT ����ֵ

        shld rax, rbx, 12
        and eax, 07h
        mov esi, [rdx + rax * 4]
        call puts
        mov rsi, rbx
        call print_qword_value64
        call println
        
        ;;
        ;; ��� EPT �����Ƿ�Ϊ not present��������
        ;; 1) access right ��Ϊ 0
        ;; 2) EPT_VALID_FLAG
        ;;
        test ebx, 7                                             ; access right = 0 ?
        jz dump_ept_paging_structure64.Done
        test ebx, EPT_VALID_FLAG                                ; ��Ч��־λ = 0 ?
        jz dump_ept_paging_structure64.Done
     
        ;;
        ;; ��ȡ��������
        ;;
        and rbx, ~0FFFh                                         ; �� bits 11:0
        and rbx, [gs: PCB.MaxPhyAddrSelectMask]                 ; ȡ��ֵַ       

        ;;
        ;; �������� walk 
        ;;
        mov rsi, rbx
        call get_ept_pt_virtual_address
        mov rbp, rax                                            ; rbp = EPT ҳ���ַ

        cmp ecx, (32 - 4 + 9 + 9 + 9)
        lea rcx, [rcx + 9]                                      ; ��һ��ҳ��� shld count
        jne dump_ept_paging_structure64.Walk

dump_ept_paging_structure64.Done:     
        pop r10
        pop rdx
        pop rcx
        pop rbx
        pop rbp
        ret




;---------------------------------------------------------------
; dump_guest_longmode_paging_structure64()
; input:
;       rsi - guest-linear address
;       rdi - dump page flag
; output:
;       none
; ��������
;       1) ��ӡ EPT paging structure ����
;---------------------------------------------------------------
dump_guest_longmode_paging_structure64:
        push rbp
        push rbx
        push rcx
        push r10

        
        mov r10, rsi                                    ; r10 = GPA
        mov ecx, (32 - 4)                               ; ecx = EPT ���� index ����λ����shld��
        
        mov [Ept.DumpPageFlag], edi
        
        ;;
        ;; ��ȡ��ǰ guest �� CR3 ֵ
        ;;
        GetVmcsField    GUEST_CR3
        mov rsi, rax
        call get_system_va_of_guest_pa 
        test rax, rax
        jz dump_guest_longmode_paging_structure64.Done
        mov rbp, rax                                    ; rbp = guest-paging structure
        

        mov esi, Ept.DumpGuestMsg1
        call puts
        mov rsi, r10
        call print_qword_value64
        mov esi, Ept.DumpGuestMsg2
        call puts

dump_guest_longmode_paging_structure64.Walk:
        ;;
        ;; guest-paging structure walk ����
        ;;
        shld rax, r10, cl
        and eax, 0FF8h
        
        ;;
        ;; ��ȡ guest ����
        ;;
        add rbp, rax                                    ; rbp ָ�� guest ����
        mov rbx, [rbp]                                  ; rbx = guest ����ֵ

        mov eax, ecx
        sub eax, (32 - 4)
        and eax, 07h
        mov esi, [Ept.GuestEntryMsg + rax * 4]
        call puts
        mov rsi, rbx
        call print_qword_value64
        call println
        
        ;;
        ;; �Ƿ�Ϊ PDE
        ;;
        cmp ecx, (32 - 4 + 9 + 9)
        jne dump_guest_longmode_paging_structure64.Walk.@0
        test ebx, PAGE_2M
        jnz dump_guest_longmode_paging_structure64.Done


dump_guest_longmode_paging_structure64.Walk.@0:        
        ;;
        ;; �������Ƿ�Ϊ not present
        ;;
        test ebx, PAGE_P                                        ; access right = 0 ?
        jz dump_guest_longmode_paging_structure64.Done

        ;;
        ;; ��ȡ��������
        ;;
        and rbx, ~0FFFh                                         ; �� bits 11:0
        and rbx, [gs: PCB.MaxPhyAddrSelectMask]                 ; ȡ��ֵַ       

        test DWORD [Ept.DumpPageFlag], DUMP_PAGE_NEST
        jz dump_guest_longmode_paging_structure64.Walk.@1
        
        mov rsi, rbx
        call dump_ept_paging_structure64
        
dump_guest_longmode_paging_structure64.Walk.@1:

        ;;
        ;; �������� walk 
        ;;
        mov rsi, rbx
        call get_system_va_of_guest_pa
        mov rbp, rax                                            ; rbp = guest ҳ���ַ

        cmp ecx, (32 - 4 + 9 + 9 + 9)
        lea rcx, [rcx + 9]                                      ; ��һ��ҳ��� shld count
        jne dump_guest_longmode_paging_structure64.Walk

dump_guest_longmode_paging_structure64.Done:     
        pop r10
        pop rcx
        pop rbx
        pop rbp
        ret