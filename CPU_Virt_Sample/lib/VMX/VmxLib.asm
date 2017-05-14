;*************************************************
;* VmxLib.asm                                    *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************






;-------------------------------------------------------------------
; vm_alloc_domain()
; input;
;       none
; output:
;       eax - �����ַ
;       edx - �����ַ
; ������
;       1) �� domain pool ����� VM domain ����
;-------------------------------------------------------------------
vm_alloc_domain:
        push ebp
        push ebx
        push ecx
        
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  

        mov ebx, DOMAIN_SIZE
        mov edx, ebx
        REX.Wrxb
        xadd [ebp + SDA.DomainBase], ebx
        REX.Wrxb
        xadd [ebp + SDA.DomainPhysicalBase], edx

        ;;
        ;; �� x64 ��ʹ�� 2M ҳ�棬�� x86 ��ʹ�� 4K ҳ��
        ;;
%ifdef __X64
        REX.Wrxb
        mov esi, ebx
        REX.Wrxb
        mov edi, edx
        REX.wrxB
        mov eax, PAGE_2M | PAGE_WRITE | PAGE_P
        REX.wrxB
        mov ecx, (DOMAIN_SIZE / 200000h)
        call do_virtual_address_mapping_n           
%else        
        REX.Wrxb
        mov esi, ebx
        REX.Wrxb
        mov edi, edx
        REX.wrxB
        mov eax, PAGE_WRITE | PAGE_P
        REX.wrxB
        mov ecx, (DOMAIN_SIZE + 0FFFh) / 1000h
        call do_virtual_address_mapping_n
%endif

        REX.Wrxb
        mov eax, ebx
        pop ecx
        pop ebx
        pop ebp
        ret
        



;-------------------------------------------------------------------
; vm_alloc_pool_physical_page()
; input
;       esi - n ҳ
; output:
;       eax - physical address
; ������
;       1) �� VM domain ����������ڴ�
;       2) �ɹ�ʱ�����������ַ��ʧ�ܷ��� 0 ֵ
;-------------------------------------------------------------------
vm_alloc_pool_physical_page:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        
        mov eax, esi
        shl eax, 12
        REX.Wrxb
        xadd [ebx + VMB.DomainPhysicalBase], eax
        
        ;;
        ;; �Ƿ񳬳� domain ����
        ;;
        REX.Wrxb
        cmp eax, [ebx + VMB.DomainPhysicalTop]
        jb  vm_alloc_pool_physical_page.done
        
        ;;
        ;; ���� 0 ֵ������״̬��
        ;;
        REX.Wrxb
        mov [ebx + VMB.DomainPhysicalBase], eax
        mov DWORD [ebp + PCB.LastStatusCode], STATUS_NO_RESOURCE
        xor eax, eax
        
vm_alloc_pool_physical_page.done:        
        pop ebx
        pop ebp
        ret


;---------------------------------------------------------------
; get_guest_paging_mode()
; input:
;       none
; output:
;       eax - guest paging mode
; ����:
;       1) ���� guest OS �ķ�ҳģʽ
;---------------------------------------------------------------
get_guest_paging_mode:
        ;;
        ;; ��� IA32_EFER.LMA λ
        ;;
        GetVmcsField    GUEST_IA32_EFER_FULL
        test eax, EFER_LMA
        mov eax, GUEST_PAGING_LONGMODE
        jnz get_guest_paging_mode.done
        
        ;;
        ;; ��� CR4.PAE λ
        ;;
        GetVmcsField    GUEST_CR4
        test eax, CR4_PAE
        mov eax, GUEST_PAGING_PAE
        mov esi, GUEST_PAGING_32bit
        cmovz eax, esi
        
get_guest_paging_mode.done:        
        ret




;---------------------------------------------------------------
; get_guest_pa_of_guest_va()
; input:
;       esi - guest-linear address
; output:
;       eax - guest-physical address
; ��������
;       1) �õ� guest-linear address ��Ӧ�� guest-physical address
;---------------------------------------------------------------
get_guest_pa_of_guest_va:
        push ebp
        push ebx
        push ecx
        push edx
        
        
        REX.Wrxb
        mov edx, esi                                    ; edx = guest-linear address

        ;;
        ;; ��ȡ��ǰ guest �� CR3 ֵ
        ;;
        GetVmcsField    GUEST_CR3        
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_pa   
        test eax, eax
        jz get_guest_pa_of_guest_va.Done
        
        REX.Wrxb
        mov ebp, eax                                    ; ebp = guest-paging structure
        
        
        ;;
        ;; ��� guest �ķ�ҳģʽ
        ;; 1) IA-32e ģʽ
        ;; 2) PAE ģʽ
        ;; 3) 32-bit ģʽ
        ;;        
        call get_guest_paging_mode        
        cmp eax, GUEST_PAGING_LONGMODE
        je get_guest_pa_of_guest_va.Longmode                
        cmp eax, GUEST_PAGING_PAE
        je get_guest_pa_of_guest_va.Pae
        
        ;;
        ;; ���� 32-bit ��ҳģʽ
        ;;
        mov ecx, 12
        xor eax, eax

get_guest_pa_of_guest_va.32bit.Walk:        
        shld eax, edx, cl
        and eax, 0FFCh
        
        REX.Wrxb
        add ebp, eax
        mov ebx, [ebp]
        
        test ebx, PAGE_P
        mov eax, -1
        jz get_guest_pa_of_guest_va.Done
        
        mov eax, ebx
        and eax, ~0FFFh
        
        ;;
        ;; ����Ƿ�Ϊ PTE
        ;;
        cmp ecx, (12 + 10)
        je get_guest_pa_of_guest_va.Result

        mov esi, eax
        call get_system_va_of_guest_pa        
        REX.Wrxb
        mov ebp, eax
        add ecx, 10
        jmp get_guest_pa_of_guest_va.32bit.Walk
        
        
        
get_guest_pa_of_guest_va.Pae: 
        ;;
        ;; ���� PAE ��ҳģʽ
        ;;
        mov ecx, 5
        xor eax, eax

get_guest_pa_of_guest_va.Pae.Walk:
        shld eax, edx, cl
        and eax, 0FF8h
        
        ;;
        ;; ��ȡ����
        ;;
        REX.Wrxb
        add ebp, eax
        REX.Wrxb        
        mov ebx, [ebp]

        ;;
        ;; ����Ƿ�Ϊ present������� not-present ���� -1
        ;;
        test ebx, PAGE_P
        mov eax, -1
        jz get_guest_pa_of_guest_va.Done        
        
        REX.Wrxb
        mov eax, ebx       
        
        and eax, ~0FFFh
        mov esi, PCB.MaxPhyAddrSelectMask
        REX.Wrxb
        and eax, [gs: esi]
        
        ;;
        ;; ����Ƿ�Ϊ PDE
        ;;
        cmp ecx, (5 + 9)
        jne get_guest_pa_of_guest_va.Pae.Walk.@1
        
        ;;
        ;; ����Ƿ�Ϊ 2M ҳ��
        ;;
        test ebx, PAGE_2M
        jnz get_guest_pa_of_guest_va.Result       
        
get_guest_pa_of_guest_va.Pae.Walk.@1:
        ;;
        ;; ����Ƿ�Ϊ PTE
        ;;
        cmp ecx, (5 + 9 + 9)
        je get_guest_pa_of_guest_va.Result
        
        ;;
        ;; ���� walk        
        ;;
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_pa
        REX.Wrxb
        mov ebp, eax        
        add ecx, 9
        jmp get_guest_pa_of_guest_va.Pae.Walk
        
                
        
get_guest_pa_of_guest_va.Longmode:
        ;;
        ;; ���� IA-32e ��ҳģʽ
        ;;
        mov ecx, 32 - 4
        xor eax, eax
        
get_guest_pa_of_guest_va.Longmode.Walk:
        ;;
        ;; guest-paging structure walk ����
        ;;
        REX.Wrxb
        shld eax, edx, cl
        and eax, 0FF8h
           
        ;;
        ;; ��ȡ guest ����
        ;;
        REX.Wrxb
        add ebp, eax                                    ; ebp ָ�� guest ����
        REX.Wrxb
        mov ebx, [ebp]                                  ; ebx = guest ����ֵ

        ;;
        ;; �������Ƿ�Ϊ not present
        ;; 1) �� not present ʱ������ -1 ֵ
        ;;
        test ebx, PAGE_P
        mov eax, -1
        jz get_guest_pa_of_guest_va.Done

        REX.Wrxb
        mov eax, ebx

        ;;
        ;; ��ȡ���� guest-physical address
        ;;
        REX.Wrxb
        and eax, ~0FFFh                                         ; �� bits 11:0        
        mov esi, PCB.MaxPhyAddrSelectMask
        REX.Wrxb
        and eax, [gs: esi]                                      ; ȡ��ֵַ

        ;;
        ;; ����Ƿ�Ϊ PTE
        ;;
        cmp ecx, (32 - 4 + 9 + 9 + 9)
        je get_guest_pa_of_guest_va.Result
        
        ;;
        ;; ����Ƿ�Ϊ PDE
        ;;
        cmp ecx, (32 - 4 + 9 + 9)
        jne get_guest_pa_of_guest_va.Longmode.Walk.@1

        test ebx, PAGE_2M
        jnz get_guest_pa_of_guest_va.Result

get_guest_pa_of_guest_va.Longmode.Walk.@1:
        ;;
        ;; �������� walk 
        ;;
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_pa       
        REX.Wrxb
        mov ebp, eax                                            ; ebp = guest ҳ���ַ
        add ecx, 9
        jmp get_guest_pa_of_guest_va.Longmode.Walk

get_guest_pa_of_guest_va.Result:
        and edx, 0FFFh
        REX.Wrxb
        add eax, edx

get_guest_pa_of_guest_va.Done:     
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        
        
        
        
;-------------------------------------------------------------------
; get_system_va_of_guest_pa()
; input:
;       esi - guest_physical_address
; output:
;       eax - virtual address
; ������
;       1) ���ص�ǰ guest �� guest-physical address ��Ӧ�� system �������ַ
;       2) ʧ��ʱ���� 0 ֵ
;-------------------------------------------------------------------
get_system_va_of_guest_pa:
        push ebx
        push ecx
        push edx        


        REX.Wrxb
        mov ebx, esi
        
        ;;
        ;; ��ȡ guest-physical address �� VM domain ��ַ
        ;;
%ifdef __X64        
        mov eax, GET_PAGE_FRAME
%else
        xor edi, edi
        mov ecx, GET_PAGE_FRAME
%endif
        call do_guest_physical_address_mapping
        cmp eax, MAPPING_UNSUCCESS
        mov esi, 0
        je get_system_va_of_guest_pa.done
        
        ;;
        ;; �õ� system ��ַ
        ;;
%ifdef __X64
        LOADv rsi, SYSTEM_DATA_SPACE_BASE
        REX.Wrxb
        or esi, eax
        and ebx, 0FFFh
        REX.Wrxb
        add esi, ebx
%else        
        mov esi, SYSTEM_DATA_SPACE_BASE
        or esi, eax
        and ebx, 0FFFh
        add esi, ebx
%endif

get_system_va_of_guest_pa.done:
        REX.Wrxb
        mov eax, esi
        pop edx
        pop ecx
        pop ebx
        ret



;----------------------------------------------------------
; get_system_va_of_guest_va()
; input:
;       esi - guest-linear address
; output:
;       eax - host linear address
; ������
;       1) �õ� guest ���Ե�ַ��Ӧ�� host ���Ե�ַ
;----------------------------------------------------------
get_system_va_of_guest_va:
        ;;
        ;; ��ȡ guest-linear address ��Ӧ�� guest-physical address
        ;;
        call get_guest_pa_of_guest_va
        cmp eax, -1
        jne get_system_va_of_guest_va.@1
        mov eax, PCB.LastStatusCode
        mov DWORD [gs: eax], STATUS_GUEST_PAGING_ERROR
        mov eax, 0
        ret
        
get_system_va_of_guest_va.@1:        
        ;;
        ;; ��ȡ guest-physical address ��Ӧ�� host linear address
        ;;
        REX.Wrxb
        mov esi, eax
        call get_system_va_of_guest_pa
        ret


;----------------------------------------------------------
; get_system_va_of_guest_os()
; input:
;       esi - guest-physical address �� guest-linear address
; output:
;       eax - host virtual address
; ������
;       1) ���� guest OS ������paging �򷵻� guest-linear address ��Ӧ�� host virtual address
;       2) ���� guest OS �ر� paging �򷵻� guestt-physical address ��Ӧ�� host virtual address
;----------------------------------------------------------
get_system_va_of_guest_os:
        push ebx
        
        REX.Wrxb
        mov ebx, esi
        
        ;;
        ;; �� guest OS �Ƿ��� paging
        ;; 1) �ǣ����� get_system_va_of_guest_va
        ;; 2) �񣬵��� get_system_va_of_guest_pa
        ;;
        GetVmcsField    GUEST_CR0
        test eax, CR0_PG
        mov esi, get_system_va_of_guest_pa
        mov eax, get_system_va_of_guest_va
        cmovz eax, esi
        REX.Wrxb
        mov esi, ebx
        call eax
        pop ebx
        ret
        



;----------------------------------------------------------
; init_eptp_field()
; input:
;       x86: edi:esi - EP4TA��64 λֵ��
;       x64: rsi - EP4TA
; output:
;       none
; ������
;       1) ���� Extended-page-table pointer��EPTP) ��
;----------------------------------------------------------
init_eptp_field:
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

%define ExecutionControlBufBase                 (ebp + PCB.ExecutionControlBuf)
        
        ;;
        ;; ���� EPTP ˵��:
        ;; [2:0]     - EPT memory type��֧�� UC �� WB ����
        ;; [5:3]     - 3��ָʾ EPT �� page walk legnth Ϊ 4 ����
        ;; [6]       - 1���� IA32_VMX_EPT_VPID_CAP[21]������
        ;; [11:7]    - ����λ��Ϊ 0
        ;; [N-1:12]  - EPT pointer ֵ
        ;; [63:N]    - ����λ��Ϊ 0
        ;;
        REX.Wrxb
        and esi, ~0FFFh                         ; ��֤ 4K �߽�

        ;;
        ;; ��֤ EPT pointer �� MAXPHYADDR ֵ��
        ;;
%ifdef __X64
        REX.Wrxb
        and esi, [ebp + PCB.MaxPhyAddrSelectMask]
%else        
        and edi, [ebp + PCB.MaxPhyAddrSelectMask + 4]
%endif

        ;;
        ;; �� IA32_VMX_EPT_VPID_CAP[21] λ�������Ƿ�֧�� dirty ��־
        ;;
        xor eax, eax
        test DWORD [ebp + PCB.EptVpidCap], (1 << 21)
        setnz al
        shl eax, 6                                      ; EPTP[6]
        
        ;;
        ;; ���� EPT memory type
        ;; 
        or eax, [ebp + PCB.EptMemoryType]               ; EPTP[2:0]
        
        ;;
        ;; ���� page walk length = 3
        ;;
        or eax, 18h                                     ; EPTP[5:3] = 3
        
        ;;
        ;; �ϳ����� EPT pointer ֵ
        ;;
        REX.Wrxb
        or esi, eax        

        
        ;;
        ;; ���� execution control buffer �� Ept pointer
        ;;
        REX.Wrxb
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EptPointer], esi
        
%ifndef __X64
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EptPointer + 4], edi
%endif        
        
        
%undef ExecutionControlBufBase        
        pop ebp
        ret
        
        
        
;----------------------------------------------------------
; set_guest_eptp()
; input:
;       edi:esi - EPT pointer��64 λֵ��
;       rsi - EPT pointer��x64��
; output:
;       none
; ������
;       1) ���� Extended-page-table pointer��EPTP) ��
;----------------------------------------------------------
set_guest_eptp:
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

%define ExecutionControlBufBase                 (ebp + PCB.ExecutionControlBuf)

        ;;
        ;; ���� EPTP buffer
        ;;
        call init_eptp_field
        
        ;;
        ;; д�� VMCS
        ;;
        DoVmWrite CONTROL_EPT_POINTER_FULL, [ExecutionControlBufBase + EXECUTION_CONTROL.EptPointer]
        
%ifndef __X64
        DoVmWrite CONTROL_EPT_POINTER_HIGH, [ExecutionControlBufBase + EXECUTION_CONTROL.EptPointer + 4]
%endif         
        
        
%undef ExecutionControlBufBase        
        pop ebp
        ret
        
        


;----------------------------------------------------------
; set_guest_cpl()
; input:
;       esi - privilege level
; output:
;       none
; ������
;       1) ���� guest ������ CPL ֵ
;----------------------------------------------------------
set_guest_cpl:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

%define GuestStateBufBase       (ebp + PCB.GuestStateBuf)
%define EntryControlBufBase     (ebp + PCB.EntryControlBuf)
      
      
        DoVmRead VMENTRY_CONTROL, [EntryControlBufBase + ENTRY_CONTROL.VmEntryControl]
      
      
        ;;
        ;; eax = 0 �� CS, ebx = 0 �� SS
        ;; ecx = 3 �� CS, edx = 3 �� SS
        ;;
        mov eax, KernelCsSelector32
        mov ebx, KernelSsSelector32
        mov ecx, UserCsSelector32 | 3
        mov edx, UserSsSelector32 | 3
        
        ;;
        ;; �ж��Ƿ�Ϊ IA-32e mode guest
        ;;
        test DWORD [EntryControlBufBase + ENTRY_CONTROL.VmEntryControl], IA32E_MODE_GUEST
        jz set_guest_cpl.@0
        
        ;;
        ;; guest ���� IA-32e mode
        ;;
        mov eax, KernelCsSelector64
        mov ebx, KernelSsSelector64
        mov ecx, UserCsSelector64 | 3
        mov edx, UserSsSelector64 | 3


set_guest_cpl.@0:        
               
        and esi, 03h
        cmovnz eax, ecx
        cmovnz ebx, edx

        ;;
        ;; ���� selector
        ;;                

        SetVmcsField    GUEST_CS_SELECTOR, eax
        SetVmcsField    GUEST_SS_SELECTOR, ebx
        SetVmcsField    GUEST_DS_SELECTOR, eax
        SetVmcsField    GUEST_ES_SELECTOR, ebx
        
%ifdef __X64        
        SetVmcsField    GUEST_FS_SELECTOR, ebx
        SetVmcsField    GUEST_GS_SELECTOR, ebx
%else
        SetVmcsField    GUEST_FS_SELECTOR, FsSelector
        SetVmcsField    GUEST_GS_SELECTOR, GsSelector
%endif        
        
       
                        
       ;;
       ;; ���� access right
       ;;
        mov eax, TYPE_NON_SYS | TYPE_CcRA | SEG_uGDlP
        mov ebx, TYPE_NON_SYS | TYPE_CcRA | SEG_uGDlP | DPL_3
        mov ecx, TYPE_NON_SYS | TYPE_CcRA | SEG_uGdLP
        mov edx, TYPE_NON_SYS | TYPE_CcRA | SEG_uGdLP | DPL_3
        
        test esi, esi  
        cmovnz eax, ebx
        cmovnz ecx, edx
        mov ebx, DPL_3
        cmovnz esi, ebx
        or esi, TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP
        
        test DWORD [ebp + PCB.EntryControlBuf + ENTRY_CONTROL.VmEntryControl], IA32E_MODE_GUEST
        cmovnz eax, ecx
        
        
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsAccessRight], eax
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsAccessRight], esi;TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsAccessRight], esi;TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsAccessRight], esi;TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP
        and esi, ~SEG_G
        mov DWORD [GuestStateBufBase + GUEST_STATE.FsAccessRight], esi;TYPE_NON_SYS | TYPE_ceWA | SEG_ugDlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.GsAccessRight], esi;TYPE_NON_SYS | TYPE_ceWA | SEG_ugDlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.LdtrAccessRight], TYPE_SYS | TYPE_LDT | SEG_Ugdlp
        mov DWORD [GuestStateBufBase + GUEST_STATE.TrAccessRight], TYPE_SYS | TYPE_BUSY_TSS32 | SEG_ugdlP
       

        DoVmWrite GUEST_CS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.CsAccessRight]
        DoVmWrite GUEST_SS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.SsAccessRight]
        DoVmWrite GUEST_DS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.DsAccessRight]
        DoVmWrite GUEST_ES_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.EsAccessRight]
        DoVmWrite GUEST_FS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.FsAccessRight]
        DoVmWrite GUEST_GS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.GsAccessRight]
        DoVmWrite GUEST_LDTR_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.LdtrAccessRight]
        DoVmWrite GUEST_TR_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.TrAccessRight]  


%undef GuestStateBufBase        
%undef EntryControlBufBase
        
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        
        
        
;----------------------------------------------------------
; set_longmode_guest_code()
; input:
;       esi - CSEG_64 or CSEG_32
; output:
;       none
; ������
;       1) ���� longmode �µ� 64-bit �� 32-bit ����
;----------------------------------------------------------
set_longmode_guest_code:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

%define GuestStateBufBase       (ebp + PCB.GuestStateBuf)

        and esi, CSEG_MASK
        DoVmRead GUEST_CS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.CsAccessRight]
        mov eax, [GuestStateBufBase + GUEST_STATE.CsAccessRight]
        and eax, ~CSEG_MASK
        or eax, esi
        mov [GuestStateBufBase + GUEST_STATE.CsAccessRight], eax
        DoVmWrite GUEST_CS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.CsAccessRight]
        
%undef GuestStateBufBase        

        pop ebp
        ret
        
        

;----------------------------------------------------------
; set_guest_interruptitility_state()
; input:
;       esi - interruptibility state
; output:
;       none
; ������
;       1) ����guest�Ŀ��ж�״̬
;----------------------------------------------------------
set_guest_interruptibility_state:
        push ebp       
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        and esi, 0Fh
        mov [ebp + PCB.GuestStateBuf + GUEST_STATE.InterruptibilityState], esi
        DoVmWrite GUEST_INTERRUPTIBILITY_STATE, [ebp + PCB.GuestStateBuf + GUEST_STATE.InterruptibilityState]
        pop ebp
        ret        
        
        

;----------------------------------------------------------
; set_guest_activity_state()
; input:
;       esi - activity state
; output:
;       none
; ������
;       1) ����guest�Ŀ��ж�״̬
;----------------------------------------------------------
set_guest_activity_state:
        push ebp       
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        mov DWORD [ebp + PCB.GuestStateBuf + GUEST_STATE.ActivityState], esi
        DoVmWrite GUEST_ACTIVITY_STATE, [ebp + PCB.GuestStateBuf + GUEST_STATE.ActivityState]        
        pop ebp
        ret



;----------------------------------------------------------
; set_guest_pending_debug_exception()
; input:
;       esi - pending debug exception �ֶ�ֵ
; output:
;       none
; ������
;       1) ���� guest �� pending #DB �쳣
;----------------------------------------------------------
set_guest_pending_debug_exception:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 
        mov [ebp + PCB.GuestStateBuf + GUEST_STATE.PendingDebugException], esi
        DoVmWrite GUEST_PENDING_DEBUG_EXCEPTION, [ebp + PCB.GuestStateBuf + GUEST_STATE.PendingDebugException]
        
        pop ebp
        ret



;----------------------------------------------------------
; update_guest_rip
; input:
;       none
; output:
;       none
; ������
;       1) ���� VM-exit information �����Ϣ������ rip
;----------------------------------------------------------
update_guest_rip:
        push ebp       
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        ;;
        ;; RIP = RIP + instruction length
        ;;
        GetVmcsField    GUEST_RIP
        REX.Wrxb
        mov ecx, eax
        GetVmcsField    VMEXIT_INSTRUCTION_LENGTH
        REX.Wrxb
        add eax, ecx

        ;;
        ;; ���� RIP
        ;;
        SetVmcsField    GUEST_RIP, eax
     
        pop ecx
        pop ebp
        ret


;----------------------------------------------------------
; make_guest_segment_unusable()
; input:
;       esi - ��
; output:
;       none
; ����:
;       1) ���ö�Ϊ unusable
;----------------------------------------------------------
make_guest_segment_unusable:
        vmread eax, esi
        or eax, SEG_U
        vmwrite esi, eax        
        ret
        
        
        
        
;----------------------------------------------------------
; set_realmode_guest_segment()
;----------------------------------------------------------        
set_realmode_guest_segment:
        push ebp       
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 

%define GuestStateBufBase       (ebp + PCB.GuestStateBuf)

        xor eax, eax
        mov [GuestStateBufBase+ GUEST_STATE.CsSelector], ax
        mov [GuestStateBufBase+ GUEST_STATE.SsSelector], ax
        mov [GuestStateBufBase+ GUEST_STATE.DsSelector], ax
        mov [GuestStateBufBase+ GUEST_STATE.EsSelector], ax
        mov [GuestStateBufBase+ GUEST_STATE.FsSelector], ax
        mov [GuestStateBufBase+ GUEST_STATE.GsSelector], ax

        mov [GuestStateBufBase+ GUEST_STATE.CsBase], eax
        mov [GuestStateBufBase+ GUEST_STATE.SsBase], eax
        mov [GuestStateBufBase+ GUEST_STATE.DsBase], eax
        mov [GuestStateBufBase+ GUEST_STATE.EsBase], eax
        mov [GuestStateBufBase+ GUEST_STATE.FsBase], eax
        mov [GuestStateBufBase+ GUEST_STATE.GsBase], eax
        
        mov eax, 0FFFFFh
        mov [GuestStateBufBase+ GUEST_STATE.CsLimit], eax
        mov [GuestStateBufBase+ GUEST_STATE.SsLimit], eax
        mov [GuestStateBufBase+ GUEST_STATE.DsLimit], eax
        mov [GuestStateBufBase+ GUEST_STATE.EsLimit], eax
        mov [GuestStateBufBase+ GUEST_STATE.FsLimit], eax
        mov [GuestStateBufBase+ GUEST_STATE.GsLimit], eax

        mov eax, 93h
        mov [GuestStateBufBase+ GUEST_STATE.CsAccessRight], eax
        mov DWORD [GuestStateBufBase+ GUEST_STATE.SsAccessRight], eax;0F3h
        mov DWORD [GuestStateBufBase+ GUEST_STATE.DsAccessRight], eax
        mov [GuestStateBufBase+ GUEST_STATE.EsAccessRight], eax
        mov [GuestStateBufBase+ GUEST_STATE.FsAccessRight], eax
        mov [GuestStateBufBase+ GUEST_STATE.GsAccessRight], eax


        DoVmWrite GUEST_CS_SELECTOR, [GuestStateBufBase + GUEST_STATE.CsSelector]
        DoVmWrite GUEST_SS_SELECTOR, [GuestStateBufBase + GUEST_STATE.SsSelector]
        DoVmWrite GUEST_DS_SELECTOR, [GuestStateBufBase + GUEST_STATE.DsSelector]
        DoVmWrite GUEST_ES_SELECTOR, [GuestStateBufBase + GUEST_STATE.EsSelector]
        DoVmWrite GUEST_FS_SELECTOR, [GuestStateBufBase + GUEST_STATE.FsSelector]
        DoVmWrite GUEST_GS_SELECTOR, [GuestStateBufBase + GUEST_STATE.GsSelector]
;        DoVmWrite GUEST_LDTR_SELECTOR, [GuestStateBufBase + GUEST_STATE.LdtrSelector]
;        DoVmWrite GUEST_TR_SELECTOR, [GuestStateBufBase + GUEST_STATE.TrSelector]

        DoVmWrite GUEST_CS_BASE, [GuestStateBufBase + GUEST_STATE.CsBase]
        DoVmWrite GUEST_SS_BASE, [GuestStateBufBase + GUEST_STATE.SsBase]
        DoVmWrite GUEST_DS_BASE, [GuestStateBufBase + GUEST_STATE.DsBase]
        DoVmWrite GUEST_ES_BASE, [GuestStateBufBase + GUEST_STATE.EsBase]
        DoVmWrite GUEST_FS_BASE, [GuestStateBufBase + GUEST_STATE.FsBase]
        DoVmWrite GUEST_GS_BASE, [GuestStateBufBase + GUEST_STATE.GsBase]
 ;       DoVmWrite GUEST_LDTR_BASE, [GuestStateBufBase + GUEST_STATE.LdtrBase]
  ;      DoVmWrite GUEST_TR_BASE, [GuestStateBufBase + GUEST_STATE.TrBase]        
                
        DoVmWrite GUEST_CS_LIMIT, [GuestStateBufBase + GUEST_STATE.CsLimit]
        DoVmWrite GUEST_SS_LIMIT, [GuestStateBufBase + GUEST_STATE.SsLimit]
        DoVmWrite GUEST_DS_LIMIT, [GuestStateBufBase + GUEST_STATE.DsLimit]
        DoVmWrite GUEST_ES_LIMIT, [GuestStateBufBase + GUEST_STATE.EsLimit]
        DoVmWrite GUEST_FS_LIMIT, [GuestStateBufBase + GUEST_STATE.FsLimit]
        DoVmWrite GUEST_GS_LIMIT, [GuestStateBufBase + GUEST_STATE.GsLimit]
        ;DoVmWrite GUEST_LDTR_LIMIT, [GuestStateBufBase + GUEST_STATE.LdtrLimit]
        ;DoVmWrite GUEST_TR_LIMIT, [GuestStateBufBase + GUEST_STATE.TrLimit]

        DoVmWrite GUEST_CS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.CsAccessRight]
        DoVmWrite GUEST_SS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.SsAccessRight]
        DoVmWrite GUEST_DS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.DsAccessRight]
        DoVmWrite GUEST_ES_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.EsAccessRight]
        DoVmWrite GUEST_FS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.FsAccessRight]
        DoVmWrite GUEST_GS_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.GsAccessRight]
        ;DoVmWrite GUEST_LDTR_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.LdtrAccessRight]
        ;DoVmWrite GUEST_TR_ACCESS_RIGHTS, [GuestStateBufBase + GUEST_STATE.TrAccessRight]     
        
                                        
        
%undef  GuestStateBufBase
        pop ebp
        ret
        




;-------------------------------------------------------------------
; set_guest_unconditional_ioexit()
; input:
;       none
; output:
;       none
; ������
;       1������ guest ʹ��I/O��������VM����ʱ�رա�I/O bitmap������
;-------------------------------------------------------------------        
set_guest_unconditional_ioexit:
        ;;
        ;; �� primary processor-based VM-execution control �ֶ�
        ;; 1) "unconditional I/O exitting�� = 1
        ;; 2) "use I/O bitmap" = 0
        ;;
        GetVmcsField    CONTROL_PROCBASED_PRIMARY
        or eax, UNCONDITIONAL_IO_EXITING
        and eax, ~USE_IO_BITMAP
        SetVmcsField    CONTROL_PROCBASED_PRIMARY, eax
        ret
        



;-------------------------------------------------------------------
; set_vmcs_iomap_bit(): ���ζ�ĳ���˿ڵķ���
; input:
;       esi - VMB pointer
;       edi - �˿�
; output:
;       none
; ������
;       1) �� IO bitmap ��λ
;-------------------------------------------------------------------
set_vmcs_iomap_bit:
        push ebx        
        REX.Wrxb
        mov ebx, [esi + VMB.IoBitmapAddressA]
        cmp edi, 7FFFh
        REX.Wrxb
        cmova ebx, [esi + VMB.IoBitmapAddressB]        
        mov eax, edi
        shr eax, 3                                              ; port / 8
        and edi, 7                                              ; ȡ byte ��λ��
        bts DWORD [ebx + eax], edi                              ; ��λ
        pop ebx
        ret


;-------------------------------------------------------------------
; set_io_bitmap()
; input:
;       esi - port
; output:
;       none
; ������
;       1) �Ե�ǰ IO bitmap ��λ
;-------------------------------------------------------------------
set_io_bitmap:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebp + VMB.IoBitmapAddressA]
        cmp esi, 7FFFh
        REX.Wrxb
        cmova ebx, [ebp + VMB.IoBitmapAddressB] 
        mov eax, esi
        shr eax, 3                                              ; port / 8
        and esi, 7                                              ; ȡ byte ��λ��
        bts DWORD [ebx + eax], esi                              ; ��λ                
        pop ebx
        pop ebp
        ret
        


;-------------------------------------------------------------------
; set_io_bitmap_with_range()
; input:
;       esi - port start
;       edi - port end
; output:
;       none
; ������
;       1) �Ե�ǰ IO bitmap ��λ
;-------------------------------------------------------------------
set_io_bitmap_with_range:
        push ecx
        push edx
        mov ecx, esi
        mov edx, edi
set_io_bitmap_with_range.Loop:
        mov esi, ecx
        call set_io_bitmap
        INCv ecx
        cmp ecx, edx
        jbe set_io_bitmap_with_range.Loop        
        pop edx
        pop ecx
        ret
        
        


;-------------------------------------------------------------------
; clear_vmcs_iomap_bit(): ���ζ�ĳ���˿ڵķ���
; input:
;       esi - VMB pointer
;       edi - �˿�
; output:
;       none
; ����:
;       1) �� IO bitmap λ
;-------------------------------------------------------------------
clear_vmcs_iomap_bit:
        push ebx
        REX.Wrxb
        mov ebx, [esi + VMB.IoBitmapAddressA]
        cmp edi, 7FFFh
        REX.Wrxb
        cmova ebx, [esi + VMB.IoBitmapAddressB]          
        mov eax, edi
        shr eax, 3                                              ; port / 8
        and edi, 7                                              ; ȡ byte ��λ��
        btr DWORD [ebx + eax], edi                              ; ��λ
        pop ebx
        ret


;-------------------------------------------------------------------
; clear_io_bitmap()
; input:
;       esi - port
; output:
;       none
; ������
;       1) �Ե�ǰ IO bitmap ��λ
;-------------------------------------------------------------------
clear_io_bitmap:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebp + VMB.IoBitmapAddressA]
        cmp esi, 7FFFh
        REX.Wrxb
        cmova ebx, [ebp + VMB.IoBitmapAddressB] 
        mov eax, esi
        shr eax, 3                                              ; port / 8
        and esi, 7                                              ; ȡ byte ��λ��
        btr DWORD [ebx + eax], esi                              ; ��λ                
        pop ebx
        pop ebp
        ret
        


;-------------------------------------------------------------------
; clear_io_bitmap_with_range()
; input:
;       esi - port start
;       edi - port end
; output:
;       none
; ������
;       1) �Ե�ǰ IO bitmap ��λ
;-------------------------------------------------------------------
clear_io_bitmap_with_range:
        push ecx
        push edx
        mov ecx, esi
        mov edx, edi
clear_io_bitmap_with_range.Loop:
        mov esi, ecx
        call clear_io_bitmap
        INCv ecx
        cmp ecx, edx
        jbe clear_io_bitmap_with_range.Loop        
        pop edx
        pop ecx
        ret
        
        

;-------------------------------------------------------------------
; reset_guest_context():
; input:
;       none
; output:
;       none
; ������
;       1) �����мĴ���
;-------------------------------------------------------------------
reset_guest_context:
        xor eax, eax
        xor ecx, ecx
        xor edx, edx
        xor ebx, ebx
        xor ebp, ebp
        xor esi, esi
        xor edi, edi
        
%ifdef __X64
        REX.WRxB
        xor eax, eax                    ; r8
        REX.WRxB
        xor ecx, ecx                    ; r9
        REX.WRxB
        xor edx, edx                    ; r10
        REX.WRxB
        xor ebx, ebx                    ; r11
        REX.WRxB
        xor esp, esp                    ; r12
        REX.WRxB
        xor ebp, ebp                    ; r13
        REX.WRxB
        xor esi, esi                    ; r14
        REX.WRxB
        xor edi, edi                    ; r15
%endif        
        ret


;-----------------------------------------------------------------------
; store_guest_context()
; input:
;       none
; output:
;       none
; ������
;       1) ���浱ǰ guest �Ļ�����Ϣ
;-----------------------------------------------------------------------
store_guest_context:
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbx
%else
        mov ebx, [gs: PCB.Base]
%endif  
        ;;
        ;; ��ǰ VM store block
        ;;
        REX.Wrxb
        mov ebx, [ebx + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebx + VMB.VsbBase]

        ;;
        ;; ���� context
        ;;
        REX.Wrxb
        mov [ebx + VSB.Rax], eax                ; eax
        REX.Wrxb
        mov [ebx + VSB.Rcx], ecx                ; ecx
        REX.Wrxb
        mov [ebx + VSB.Rdx], edx                ; edx
        REX.Wrxb
        mov eax, [esp]
        REX.Wrxb        
        mov [ebx + VSB.Rbx], eax                ; ebx              
        REX.Wrxb
        mov [ebx + VSB.Rbp], ebp                ; ebp
        REX.Wrxb
        mov [ebx + VSB.Rsi], esi                ; esi
        REX.Wrxb
        mov [ebx + VSB.Rdi], edi                ; edi
        
%ifdef __X64
        REX.WRxb
        mov [ebx + VSB.R8], eax                 ; r8
        REX.WRxb
        mov [ebx + VSB.R9], ecx                 ; r9
        REX.WRxb
        mov [ebx + VSB.R10], edx                ; r10
        REX.WRxb
        mov [ebx + VSB.R11], ebx                ; r11
        REX.WRxb
        mov [ebx + VSB.R12], esp                ; r12
        REX.WRxb
        mov [ebx + VSB.R13], ebp                ; r13
        REX.WRxb
        mov [ebx + VSB.R14], esi                ; r14
        REX.WRxb
        mov [ebx + VSB.R15], edi                ; r15
%endif

        ;;
        ;; ���� guest �� RSP, RIP �Լ� rflags
        ;;
        mov eax, GUEST_RSP
        vmread [ebx + VSB.Rsp], eax
        mov eax, GUEST_RIP
        vmread [ebx + VSB.Rip], eax
        mov eax, GUEST_RFLAGS
        vmread [ebx + VSB.Rflags], eax
                
        pop ebx
        ret


;-----------------------------------------------------------------------
; restore_guest_context()
; input:
;       none
; output:
;       none
; ������
;       1) �ָ� guest ������Ϣ
;-----------------------------------------------------------------------
restore_guest_context:
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbx
%else
        mov ebx, [gs: PCB.Base]
%endif  
        ;;
        ;; ��ǰ VM store block
        ;;
        REX.Wrxb
        mov ebx, [ebx + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebx + VMB.VsbBase]

        ;;
        ;; �ָ� context
        ;;        
        REX.Wrxb
        mov ecx, [ebx + VSB.Rcx]                        ; ecx
        REX.Wrxb
        mov edx, [ebx + VSB.Rdx]                        ; edx
        REX.Wrxb
        mov ebp, [ebx + VSB.Rbp]                        ; ebp
        REX.Wrxb
        mov esi, [ebx + VSB.Rsi]                        ; esi
        REX.Wrxb
        mov edi, [ebx + VSB.Rdi]                        ; edi
        
%ifdef __X64        
        REX.WRxb
        mov eax, [ebx + VSB.R8]                         ; r8        
        REX.WRxb
        mov ecx, [ebx + VSB.R9]                         ; r9
        REX.WRxb
        mov edx, [ebx + VSB.R10]                        ; r10
        REX.WRxb
        mov ebx, [ebx + VSB.R11]                        ; r11
        REX.WRxb
        mov esp, [ebx + VSB.R12]                        ; r12
        REX.WRxb
        mov ebp, [ebx + VSB.R13]                        ; r13
        REX.WRxb
        mov esi, [ebx + VSB.R14]                        ; r14
        REX.WRxb
        mov edi, [ebx + VSB.R15]                        ; r15
%endif   

        REX.Wrxb
        mov eax, [ebx + VSB.Rbx]                        ; ebx
        REX.Wrxb
        mov [esp], eax
        REX.Wrxb
        mov eax, [ebx + VSB.Rax]                        ; eax
        
        pop ebx
        ret
        
        
        
        
;-------------------------------------------------------------------
; get_guest_segment_base()
; input:
;       esi - segment ID
; output:
;       eax - base address
; ������
;       1) �����ṩ�� segment �Ĵ��� ID ����ȡ guest segment base ֵ
;-------------------------------------------------------------------
get_guest_segment_base:
        ;;
        ;; ��ȡ segment base �ֶ�
        ;;
        cmp esi, 1
        je get_guest_segment_base.Cs
        cmp esi, 2
        je get_guest_segment_base.Ss
        cmp esi, 3
        je get_guest_segment_base.Ds
        cmp esi, 4
        je get_guest_segment_base.Fs
        cmp esi, 5
        je get_guest_segment_base.Gs
                
get_guest_segment_base.Es:
        mov eax, GUEST_ES_BASE
        jmp get_guest_segment_base.Next
        
get_guest_segment_base.Cs:
        mov eax, GUEST_CS_BASE
        jmp get_guest_segment_base.Next

get_guest_segment_base.Ss:
        mov eax, GUEST_SS_BASE
        jmp get_guest_segment_base.Next
                
get_guest_segment_base.Ds:
        mov eax, GUEST_ES_BASE
        jmp get_guest_segment_base.Next

get_guest_segment_base.Fs:
        mov eax, GUEST_FS_BASE
        jmp get_guest_segment_base.Next

get_guest_segment_base.Gs:
        mov eax, GUEST_GS_BASE

                        
get_guest_segment_base.Next:
        GetVmcsField    eax
        ret
        
        


;-------------------------------------------------------------------
; get_guest_regsiter_value()
; input:
;       esi - register ID
; output:
;       eax - base address
; ������
;       1) �����ṩ�ļĴ��� ID ����ȡ guest �Ĵ���ֵ
;-------------------------------------------------------------------
get_guest_register_value:
        push ebp
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebp, [ebp + VMB.VsbBase]
        and esi, 0Fh
        REX.Wrxb
        mov eax, [ebp + VSB.Context + esi * 8]
        pop ebp
        ret        
        
        

;-------------------------------------------------------------------
; set_guest_register_value()
; input:
;       esi - register ID
;       edi - value
; output:
;       none
; ������
;       1) �����ṩ�ļĴ��� ID ����ȡ guest �Ĵ���ֵ
;-------------------------------------------------------------------
set_guest_register_value:
        push ebp
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebp, [ebp + VMB.VsbBase]
        and esi, 0Fh
        REX.Wrxb
        mov [ebp + VSB.Context + esi * 8], edi        
        pop ebp
        ret


        
;-------------------------------------------------------------------
; append_vmentry_msr_load_entry()
; input:
;       esi - MSR index
;       edx:eax - Msr data
; output:
;       none
; ������
;       1) �� VM-entry MSR-load �б������� MSR entry
;-------------------------------------------------------------------
append_vmentry_msr_load_entry:
        push ebp
        push ebx
        push ecx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        lea edi, [ebp + VMB.VmEntryMsrLoadCount]        
        REX.Wrxb
        mov ebp, [ebp + VMB.VmEntryMsrLoadAddress]
        mov ebx, VMENTRY_MSR_LOAD_COUNT
        
        jmp do_append_msr_list_entry




;-------------------------------------------------------------------
; append_vmexit_msr_store_entry()
; input:
;       esi - MSR index
;       edx:eax - Msr data
; output:
;       none
; ������
;       1) 
;-------------------------------------------------------------------
append_vmexit_msr_store_entry:
        push ebp
        push ebx
        push ecx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        lea edi, [ebp + VMB.VmExitMsrStoreCount]        
        REX.Wrxb
        mov ebp, [ebp + VMB.VmExitMsrStoreAddress]
        mov ebx, VMEXIT_MSR_STORE_COUNT
        
        jmp do_append_msr_list_entry
        
        



;-------------------------------------------------------------------
; append_vmexit_msr_load_entry()
; input:
;       esi - MSR index
;       edx:eax - Msr data
; output:
;       none
; ������
;       1) 
;-------------------------------------------------------------------
append_vmexit_msr_load_entry:
        push ebp
        push ebx
        push ecx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        lea edi, [ebp + VMB.VmExitMsrLoadCount]        
        REX.Wrxb
        mov ebp, [ebp + VMB.VmExitMsrLoadAddress]
        mov ebx, VMEXIT_MSR_LOAD_COUNT
        
        
        ;;
        ;; д�� entry
        ;;
do_append_msr_list_entry:
        mov ecx, [edi]                                  ; �� entry count
        lea ecx, [ecx * 8]
        mov [ebp + ecx * 2], esi                        ; д�� MSR index
        mov [ebp + ecx * 2 + 8], eax                    ; д�� MSR bits 31:0
        mov [ebp + ecx * 2 + 12], edx                   ; д�� MSR bits 63:32
        inc DWORD [edi]                                 ; ���� entry count
        DoVmWrite       ebx, [edi]                      ; д�� COUNT �ֶ�
        pop ecx
        pop ebx
        pop ebp
        ret
        


;-------------------------------------------------------------------
; get_vmexit_msr_store_entry()
; input:
;       esi - MSR index
; output:
;       edx:eax - Msr data
; ������
;       1) ���� VM-exit MSR-store �б��Ӧ����
;-------------------------------------------------------------------
get_vmexit_msr_store_entry:
        push ebp
        push ebx
        push ecx
                
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebx, [ebp + VMB.VmExitMsrStoreAddress]
        xor ecx, ecx

get_vmexit_msr_store_entry.loop:
        cmp [ebx], esi
        je get_vmexit_msr_store_entry.found
        lea eax, [ecx * 8]
        REX.Wrxb
        lea ebx, [ebx + eax * 2]
        INCv ecx
        cmp ecx, [ebp + VMB.VmExitMsrStoreCount]
        jb get_vmexit_msr_store_entry.loop
        
        ;;
        ;; û�ҵ����� 0
        ;;
        xor eax, eax
        xor edx, edx
        jmp get_vmexit_msr_store_entry.done
        
get_vmexit_msr_store_entry.found:
        mov eax, [ebx + 8]
        mov edx, [ebx + 12]
        
get_vmexit_msr_store_entry.done:
        pop ecx
        pop ebx
        pop ebp
        ret

	
;-------------------------------------------------------------------
; set_msr_read_bitmap()
; input:
;       esi - MSR index
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� read bitmap λ
;-------------------------------------------------------------------
set_msr_read_bitmap:        
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebp, [ebp + VMB.MsrBitmapAddress]        
        mov eax, 0                                      ; low MSR read
        mov edi, 1024                                   ; high MSR read
        cmp esi, 1FFFh
        cmovbe edi, eax
        REX.Wrxb
        add ebp, edi        
        mov eax, esi
        shr eax, 3
        and esi, 7
        bts DWORD [ebp + eax], esi        
        pop ebp
        ret


;-------------------------------------------------------------------
; set_msr_read_bitmap_with_range()
; input:
;       esi - MSR start
;       edi - MSR end
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� read bitmap λ
;-------------------------------------------------------------------
set_msr_read_bitmap_with_range:
        push ecx
        push edx
        mov ecx, esi
        mov edx, edi
set_msr_read_bitmap_with_range.Loop:        
        mov esi, ecx
        call set_msr_read_bitmap
        INCv ecx
        cmp ecx, edx
        jbe set_msr_read_bitmap_with_range.Loop        
        pop edx
        pop ecx
        ret


        

;-------------------------------------------------------------------
; set_msr_write_bitmap()
; input:
;       esi - MSR index
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� write bitmap λ
;-------------------------------------------------------------------
set_msr_write_bitmap:        
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebp, [ebp + VMB.MsrBitmapAddress]        
        mov eax, 1024 * 2                               ; low MSR write
        mov edi, 1024 * 3                               ; high MSR write
        cmp esi, 1FFFh
        cmovbe edi, eax
        REX.Wrxb
        add ebp, edi        
        mov eax, esi
        shr eax, 3
        and esi, 7
        bts DWORD [ebp + eax], esi        
        pop ebp
        ret
        
        
;-------------------------------------------------------------------
; set_msr_write_bitmap_with_range()
; input:
;       esi - MSR start
;       edi - MSR end
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� write bitmap λ
;-------------------------------------------------------------------
set_msr_write_bitmap_with_range:   
        push ecx
        push edx
        mov ecx, esi
        mov edx, edi
set_msr_write_bitmap_with_range.Loop:        
        mov esi, ecx
        call set_msr_write_bitmap
        INCv ecx
        cmp ecx, edx
        jbe set_msr_write_bitmap_with_range.Loop        
        pop edx
        pop ecx
        ret
        
        
        

;-------------------------------------------------------------------
; clear_msr_read_bitmap()
; input:
;       esi - MSR index
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� read bitmap λ
;-------------------------------------------------------------------
clear_msr_read_bitmap:        
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebp, [ebp + VMB.MsrBitmapAddress]        
        mov eax, 0                                      ; low MSR read
        mov edi, 1024                                   ; high MSR read
        cmp esi, 1FFFh
        cmovbe edi, eax
        REX.Wrxb
        add ebp, edi        
        mov eax, esi
        shr eax, 3
        and esi, 7
        btr DWORD [ebp + eax], esi        
        pop ebp
        ret


;-------------------------------------------------------------------
; clear_msr_read_bitmap_with_range()
; input:
;       esi - MSR start
;       edi - MSR end
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� read bitmap λ
;-------------------------------------------------------------------
clear_msr_read_bitmap_with_range: 
        push ecx
        push edx
        mov ecx, esi
        mov edx, edi
clear_msr_read_bitmap_with_range.Loop:        
        mov esi, ecx
        call clear_msr_read_bitmap
        INCv ecx
        cmp ecx, edx
        jbe clear_msr_read_bitmap_with_range.Loop        
        pop edx
        pop ecx
        ret


        
;-------------------------------------------------------------------
; clear_msr_write_bitmap()
; input:
;       esi - MSR index
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� write bitmap λ
;-------------------------------------------------------------------
clear_msr_write_bitmap:        
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        REX.Wrxb
        mov ebp, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov ebp, [ebp + VMB.MsrBitmapAddress]        
        mov eax, 1024 * 2                               ; low MSR write
        mov edi, 1024 * 3                               ; high MSR write
        cmp esi, 1FFFh
        cmovbe edi, eax
        REX.Wrxb
        add ebp, edi        
        mov eax, esi
        shr eax, 3
        and esi, 7
        btr DWORD [ebp + eax], esi        
        pop ebp
        ret        

        
;-------------------------------------------------------------------
; clear_msr_write_bitmap_with_range()
; input:
;       esi - MSR start
;       edi - MSR end
; output:
;       none
; ������
;       1) �� MSR ��Ӧ�� write bitmap λ
;-------------------------------------------------------------------
clear_msr_write_bitmap_with_range: 
        push ecx
        push edx
        mov ecx, esi
        mov edx, edi
clear_msr_write_bitmap_with_range.Loop:        
        mov esi, ecx
        call clear_msr_write_bitmap
        INCv ecx
        cmp ecx, edx
        jbe clear_msr_write_bitmap_with_range.Loop        
        pop edx
        pop ecx
        ret

;-------------------------------------------------------------------
; set_vmx_preemption_timer_value()
; input:
;       esi - us
; output:
;       none
; ������
;       1) ���� VMX-preemption timer ��ʼ����ֵ
;-------------------------------------------------------------------
set_vmx_preemption_timer_value:
        push ebp
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        mov ecx, esi
        GetVmcsField    CONTROL_PINBASED
        test eax, ACTIVATE_VMX_PREEMPTION_TIMER
        jz set_vmx_preemption_timer_value.done
        
        ;;
        ;; ���� vmx preemption timer value
        ;;
        mov eax, [ebp + PCB.ProcessorFrequency]
        mul ecx                                                 ; VmxTimerValue = (ProcessorFrequency * us)
        mov ecx, [ebp + PCB.VmxMisc]
        and ecx, 1Fh                                            ; VMX-preemption timer ����Ƶ��
        shr eax, cl                                             ; VmxTimerValue = (ProcessorFrequency * us) >> Ƶ��
       
        ;;
        ;; д�� VMX-preemption timer value �ֶ�
        ;;        
        SetVmcsField    GUEST_VMX_PREEMPTION_TIMER_VALUE, eax
        
set_vmx_preemption_timer_value.done:
        pop ecx
        pop edx
        pop ebp
        ret


        

;-------------------------------------------------------------------
; in_running_queue()
; input:
;       esi - guest index
; output:
;       none
; ������
;       1) �� guest running ��������� guest ��ţ�0, 1, 2, 3��
;-------------------------------------------------------------------
in_running_queue:
        push ebp
        push ecx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

        ;;
        ;; �� GuestRunningQueue[index] ����� guest ���
        ;;
        mov eax, esi
        cmp DWORD [ebp + PCB.GuestRunningStatus], GUEST_QUEUE_FULL
        je in_running_queue.done
        mov ecx, [ebp + PCB.GuestRunningIndex]
        mov [ebp + PCB.GuestRunningQueue + ecx], al
        INCv ecx       
        cmp ecx, 3
        jbe in_running_queue.@1
        mov DWORD [ebp + PCB.GuestRunningStatus], GUEST_QUEUE_FULL
        jmp in_running_queue.done
in_running_queue.@1:
        mov DWORD [ebp + PCB.GuestRunningStatus], GUEST_QUEUE_NORMAL
        mov [ebp + PCB.GuestRunningIndex], ecx
in_running_queue.done:
        pop ecx
        pop ebp
        ret



;-------------------------------------------------------------------
; in_ready_queue()
; input:
;       esi - guest index
; output:
;       none
; ������
;       1) �� guest ready ��������� guest ��ţ�0, 1, 2, 3��
;-------------------------------------------------------------------
in_ready_queue:
        push ebp
        push ecx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        

        ;;
        ;; �� GuestReadyQueue[index] ����� guest ���
        ;;
        mov eax, esi
        cmp DWORD [ebp + PCB.GuestReadyStatus], GUEST_QUEUE_FULL
        je in_ready_queue.done
        mov ecx, [ebp + PCB.GuestReadyIndex]
        mov [ebp + PCB.GuestReadyQueue + ecx], al
        INCv ecx
        cmp ecx, 3
        jbe in_ready_queue.@1
        mov DWORD [ebp + PCB.GuestReadyStatus], GUEST_QUEUE_FULL
        jmp in_ready_queue.done
in_ready_queue.@1:        
        mov DWORD [ebp + PCB.GuestReadyStatus], GUEST_QUEUE_NORMAL
        mov [ebp + PCB.GuestReadyIndex], ecx
in_ready_queue.done:
        pop ecx
        pop ebp
        ret
        

;-------------------------------------------------------------------
; out_running_queue()
; input:
;       none
; output:
;       eax - guest index
; ������
;       1) �� guest running ������ȡ�� guest ��ţ�0, 1, 2, 3��
;-------------------------------------------------------------------
out_running_queue:
        push ebp
        push ecx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov eax, -1
        cmp DWORD [ebp + PCB.GuestRunningStatus], GUEST_QUEUE_EMPTY
        je out_running_queue.done
        movzx eax, BYTE [ebp + PCB.GuestRunningQueue]        
        mov ecx, [ebp + PCB.GuestRunningIndex]
        DECv ecx
        jl out_running_queue.@1
        shr DWORD [ebp + PCB.GuestRunningQueue], 8
        mov [ebp + PCB.GuestRunningIndex], ecx
        jmp out_running_queue.done
out_running_queue.@1:
        mov DWORD [ebp + PCB.GuestRunningStatus], GUEST_QUEUE_EMPTY        
out_running_queue.done:
        pop ecx
        pop ebp
        ret
        
        

;-------------------------------------------------------------------
; out_ready_queue()
; input:
;       none
; output:
;       eax - guest index
; ������
;       1) �� guest ready ������ȡ�� guest ��ţ�0, 1, 2, 3��
;-------------------------------------------------------------------
out_ready_queue:
        push ebp
        push ecx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov eax, -1
        cmp DWORD [ebp + PCB.GuestReadyStatus], GUEST_QUEUE_EMPTY
        je out_ready_queue.done
        movzx eax, BYTE [ebp + PCB.GuestReadyQueue]        
        mov ecx, [ebp + PCB.GuestReadyIndex]
        DECv ecx
        jl out_ready_queue.@1
        shr DWORD [ebp + PCB.GuestReadyQueue], 8
        mov [ebp + PCB.GuestReadyIndex], ecx
        jmp out_ready_queue.done
out_ready_queue.@1:
        mov DWORD [ebp + PCB.GuestReadyStatus], GUEST_QUEUE_EMPTY        
out_ready_queue.done:
        pop ecx
        pop ebp
        ret        
        
        
        

;-------------------------------------------------------------------
; load_guest_cs_register()
; input:
;       esi - selector
; output:
;       none
; ������
;       1) �� guest GDT ����� CS �Ĵ���
;       2) �� task switch �����ڲ�ʹ�ã�
;-------------------------------------------------------------------
load_guest_cs_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtBase]

        ;;
        ;; ���м�飬������
        ;; 1) CS selector �Ƿ�Ϊ NULL selector
        ;; 2) CS selector �Ƿ񳬳� limit
        ;; 3) CS.RPL == SS.DPL == SS.RPL��CS.DPL ���������
        ;; 4) CS ���Ƿ�Ϊ�����
        ;;
        test cx, 0FFF8h
        jz load_guest_cs_register.Error

        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        and esi, 0FFF8h
        add esi, 7
        cmp esi, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtLimit]
        ja load_guest_cs_register.Error

        ;;
        ;; ��� CS.RPL == SS.RPL 
        ;;
        movzx eax, WORD [ebx + TSS32.Ss]
        xor eax, ecx
        test eax, 03h
        jnz load_guest_cs_register.Error

        ;;
        ;; ��� CS.RPL == SS.DPL
        ;;
        mov esi, ecx
        shl esi, 13
        movzx eax, WORD [ebx + TSS32.Ss]
        and eax, 0FFF8h
        mov eax, [edx + eax + 4]
        xor esi, eax
        test esi, 6000h
        jnz load_guest_cs_register.Error

        ;;
        ;; ��� CS.DPL == SS.DPL
        ;;
        mov esi, ecx
        and esi, 0FFF8h
        mov esi, [edx + esi + 4]
        xor eax, esi
        test eax, 6000h
        jz load_guest_cs_register.@1

        ;;
        ;; CS.DPL <> SS.DPL ʱ������Ƿ�Ϊ conforming ��
        ;;
        test esi, (1 << 10)
        jz load_guest_cs_register.Error

        ;;
        ;; ��� CS.DPL <= SS.DPL
        ;;
        mov edi, esi 
        shr edi, 13
        and edi, 03h                            ; CS.DPL
        xor eax, esi
        shr eax, 13
        and eax, 03h                            ; SS.DPL
        cmp edi, eax
        ja load_guest_cs_register.Error         ; CS.DPL > SS.DPL ʱ����

load_guest_cs_register.@1:

        ;;
        ;; ��� CS �������� P = S = C/D = 1
        ;;
        test esi, 9800h
        jz load_guest_cs_register.Error

        ;;
        ;; ### ������� selector, limit, base, access rights ###
        ;;
        
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_CS_SELECTOR, ecx

        ;;
        ;; �ҵ� CS segment ������
        ;;
        mov esi, ecx
        and esi, 0FFF8h
        REX.Wrxb
        add edx, esi
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; G = 1 ʱ: limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz load_guest_cs_register.@2
        shl eax, 12
        or eax, 0FFFh
load_guest_cs_register.@2:
        SetVmcsField    GUEST_CS_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_CS_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_CS_ACCESS_RIGHTS, eax

        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_cs_register.Done
        
load_guest_cs_register.Error:
        ;;
        ;; ��������ʱ��ע�� #TS �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_TS
        
        mov eax, TASK_SWITCH_LOAD_STATE_ERROR

load_guest_cs_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        


;-------------------------------------------------------------------
; load_guest_es_register()
; input:
;       esi - selector
; output:
;       eax - error code
; ������
;       1) �� guest GDT ����� ES �Ĵ���
;       2) �� task switch �����ڲ�ʹ�ã�
;-------------------------------------------------------------------
load_guest_es_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtBase]
        
        
        ;;
        ;; ��� ES selector �� NULL����ֱ������
        ;; ���򣬼�飺
        ;; 1) selector �Ƿ񳬳� limit
        ;; 2) ����������� P �� S λ
        ;; 3) ������Ϊ code segment��
        ;;      a) �Ƿ�Ϊ�ɶ���
        ;;      b) non-conforming ��: ��Ҫ DPL >= SS.DPL, RPL <= DPL
        ;; 
                
        and esi, 0FFF8h
        jz load_guest_es_register.NullSelector
        
        ;;
        ;; �ҵ�������
        ;;
        REX.Wrxb
        add edx, esi 
               
        ;;
        ;; ����Ƿ񳬳� limit
        ;; ע�⣺
        ;;      ��Ϊʾ������������� LDT 
        ;;
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        add esi, 7
        cmp esi, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtLimit]
        ja load_guest_es_register.Error
        
        ;;
        ;; ��������� P = S = 1
        ;;
        mov eax, [edx + 4]
        test eax, 9000h
        jz load_guest_es_register.Error
        
        ;;
        ;; ������� code segment, ����Ƿ�ɶ�
        ;;
        test eax, (1 << 11)                                     ; ��� C/D λ
        jz load_guest_es_register.Next
        test eax, (1 << 9)                                      ; ��� readable λ
        jz load_guest_es_register.Error
        test eax, (1 << 10)
        jnz load_guest_es_register.Next
        
        ;;
        ;; ���� non-conforming �Σ����Ȩ��
        ;; ��Ҫ���㣺
        ;; 1) DPL >= SS.RPL
        ;; 2) DPL >= RPL
        ;;
        shr eax, 13
        and eax, 03h                                            ; DPL
        movzx esi, WORD [ebx + TSS32.Ss]
        and esi, 03h                                            ; SS.RPL
        cmp eax, esi                                            ; SS.RPL <= DPL ?
        jb load_guest_es_register.Error
        
        mov esi, ecx
        and esi, 03h                                            ; RPL
        cmp eax, esi                                            ; RPL <= DPL ?
        jb load_guest_es_register.Error
        
load_guest_es_register.Next:
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; ��� G λ��G = 1 ʱ limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz load_guest_es_register.@1
        shl eax, 12
        or eax, 0FFFh
load_guest_es_register.@1:
        SetVmcsField    GUEST_ES_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_ES_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_ES_ACCESS_RIGHTS, eax
        
        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_es_register.Done


load_guest_es_register.NullSelector:                
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_ES_SELECTOR, ecx
        
        ;;
        ;; ���� access rights Ϊ unusable
        ;;
        SetVmcsField    GUEST_ES_ACCESS_RIGHTS, SEG_U

        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_es_register.Done

load_guest_es_register.Error:
        ;;
        ;; ��������ʱ��ע�� #TS �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_TS
        
        mov eax, TASK_SWITCH_LOAD_STATE_ERROR
        
load_guest_es_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        
        

;-------------------------------------------------------------------
; load_guest_ds_register()
; input:
;       esi - selector
; output:
;       eax - error code
; ������
;       1) �� guest GDT ����� ES �Ĵ���
;       2) �� task switch �����ڲ�ʹ�ã�
;-------------------------------------------------------------------
load_guest_ds_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtBase]
        
        
        ;;
        ;; ��� DS selector �� NULL����ֱ������
        ;; ���򣬼�飺
        ;; 1) selector �Ƿ񳬳� limit
        ;; 2) ����������� P �� S λ
        ;; 3) ������Ϊ code segment��
        ;;      a) �Ƿ�Ϊ�ɶ���
        ;;      b) non-conforming ��: ��Ҫ DPL >= SS.DPL, RPL <= DPL
        ;; 
                
        and esi, 0FFF8h
        jz load_guest_ds_register.NullSelector
        
        ;;
        ;; �ҵ�������
        ;;
        REX.Wrxb
        add edx, esi 
               
        ;;
        ;; ����Ƿ񳬳� limit
        ;; ע�⣺
        ;;      ��Ϊʾ������������� LDT 
        ;;
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        add esi, 7
        cmp esi, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtLimit]
        ja load_guest_ds_register.Error
        
        ;;
        ;; ��������� P = S = 1
        ;;
        mov eax, [edx + 4]
        test eax, 9000h
        jz load_guest_ds_register.Error
        
        ;;
        ;; ������� code segment, ����Ƿ�ɶ�
        ;;
        test eax, (1 << 11)                                     ; ��� C/D λ
        jz load_guest_ds_register.Next
        test eax, (1 << 9)                                      ; ��� readable λ
        jz load_guest_ds_register.Error
        test eax, (1 << 10)
        jnz load_guest_ds_register.Next
        
        ;;
        ;; ���� non-conforming �Σ����Ȩ��
        ;; ��Ҫ���㣺
        ;; 1) DPL >= SS.RPL
        ;; 2) DPL >= RPL
        ;;
        shr eax, 13
        and eax, 03h                                            ; DPL
        movzx esi, WORD [ebx + TSS32.Ss]
        and esi, 03h                                            ; SS.RPL
        cmp eax, esi                                            ; SS.RPL <= DPL ?
        jb load_guest_ds_register.Error
        
        mov esi, ecx
        and esi, 03h                                            ; RPL
        cmp eax, esi                                            ; RPL <= DPL ?
        jb load_guest_ds_register.Error
        
load_guest_ds_register.Next:
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; ��� G λ��G = 1 ʱ limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz load_guest_ds_register.@1
        shl eax, 12
        or eax, 0FFFh
load_guest_ds_register.@1:
        SetVmcsField    GUEST_DS_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_DS_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_DS_ACCESS_RIGHTS, eax
        
        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_ds_register.Done


load_guest_ds_register.NullSelector:                
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_DS_SELECTOR, ecx
        
        ;;
        ;; ���� access rights Ϊ unusable
        ;;
        SetVmcsField    GUEST_DS_ACCESS_RIGHTS, SEG_U

        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_ds_register.Done

load_guest_ds_register.Error:
        ;;
        ;; ��������ʱ��ע�� #TS �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_TS
        
        mov eax, TASK_SWITCH_LOAD_STATE_ERROR
        
load_guest_ds_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret        
        

;-------------------------------------------------------------------
; load_guest_ss_register()
; input:
;       esi - selector
; output:
;       eax - error code
; ������
;       1) �� guest GDT ����� SS �Ĵ���
;       2) �� task switch �����ڲ�ʹ�ã�
;-------------------------------------------------------------------
load_guest_ss_register:
        push ebp
        push ebx
        push edx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtBase]

        ;;
        ;; ���м�飬������
        ;; 1) SS selector �Ƿ�Ϊ NULL selector
        ;; 2) SS selector �Ƿ񳬳� limit
        ;; 3) SS.RPL == SS.DPL == CS.RPL��CS.DPL ���������
        ;; 4) SS ���Ƿ�Ϊ��д���ݶ�
        ;;
        test cx, 0FFF8h
        jz load_guest_ss_register.Error
        
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        and esi, 0FFF8h
        add esi, 7
        cmp esi, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtLimit]
        ja load_guest_ss_register.Error

        ;;
        ;; ��� SS.RPL == CS.RPL 
        ;;
        movzx eax, WORD [ebx + TSS32.Cs]
        xor eax, ecx
        test eax, 03h
        jnz load_guest_ss_register.Error

        ;;
        ;; ��� SS.RPL == SS.DPL
        ;;
        mov esi, ecx
        shl esi, 13
        movzx eax, WORD [ebx + TSS32.Ss]
        and eax, 0FFF8h
        mov eax, [edx + eax + 4]
        xor esi, eax
        test esi, 6000h
        jnz load_guest_ss_register.Error

        ;;
        ;; ��� SS.DPL == CS.DPL
        ;;
        movzx esi, WORD [ebx + TSS32.Cs]
        and esi, 0FFF8h
        mov esi, [edx + esi + 4]
        xor esi, eax
        test esi, 6000h
        jz load_guest_ss_register.@1
                        
        ;;
        ;; SS.DPL <> CS.DPL ʱ������Ƿ�Ϊ conforming ��
        ;;
        xor esi, eax        
        test esi, (1 << 10)
        jz load_guest_ss_register.Error
        
        ;;
        ;; ��� CS.DPL <= SS.RPL
        ;;
        shr esi, 13
        and esi, 03h                            ;; CS.DPL
        mov edi, ecx
        and edi, 03                             ;; SS.RPL
        cmp esi, edi
        ja load_guest_ss_register.Error         ;; CS.DPL > SS.RPL ʱ����
        

load_guest_ss_register.@1:
        ;;
        ;; ��� SS �������� P = S = W = 1
        ;;
        test eax, 9200h
        jz load_guest_ss_register.Error


        ;;
        ;; ### ������� selector, limit, base, access rights ###
        ;;
        
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_SS_SELECTOR, ecx

        ;;
        ;; �ҵ� SS segment ������
        ;;
        mov esi, ecx
        and esi, 0FFF8h
        REX.Wrxb
        add edx, esi
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; G = 1 ʱ: limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz load_guest_ss_register.@2
        shl eax, 12
        or eax, 0FFFh
load_guest_ss_register.@2:
        SetVmcsField    GUEST_SS_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_SS_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_SS_ACCESS_RIGHTS, eax

        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_ss_register.Done
        
load_guest_ss_register.Error:
        ;;
        ;; ��������ʱ��ע�� #TS �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_TS
        
        mov eax, TASK_SWITCH_LOAD_STATE_ERROR
        
load_guest_ss_register.Done:
        pop ecx
        pop edx
        pop ebx
        pop ebp
        ret        
        
        
        
        
;-------------------------------------------------------------------
; load_guest_fs_register()
; input:
;       esi - selector
; output:
;       eax - error code
; ������
;       1) �� guest GDT ����� FS �Ĵ���
;       2) �� task switch �����ڲ�ʹ�ã�
;-------------------------------------------------------------------
load_guest_fs_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtBase]
        
        
        ;;
        ;; ��� FS selector �� NULL����ֱ������
        ;; ���򣬼�飺
        ;; 1) selector �Ƿ񳬳� limit
        ;; 2) ����������� P �� S λ
        ;; 3) ������Ϊ code segment��
        ;;      a) �Ƿ�Ϊ�ɶ���
        ;;      b) non-conforming ��: ��Ҫ DPL >= SS.DPL, RPL <= DPL
        ;; 
                
        and esi, 0FFF8h
        jz load_guest_fs_register.NullSelector
        
        ;;
        ;; �ҵ�������
        ;;
        REX.Wrxb
        add edx, esi 
               
        ;;
        ;; ����Ƿ񳬳� limit
        ;; ע�⣺
        ;;      ��Ϊʾ������������� LDT 
        ;;
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        add esi, 7
        cmp esi, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtLimit]
        ja load_guest_fs_register.Error
        
        ;;
        ;; ��������� P = S = 1
        ;;
        mov eax, [edx + 4]
        test eax, 9000h
        jz load_guest_fs_register.Error
        
        ;;
        ;; ������� code segment, ����Ƿ�ɶ�
        ;;
        test eax, (1 << 11)                                     ; ��� C/D λ
        jz load_guest_fs_register.Next
        test eax, (1 << 9)                                      ; ��� readable λ
        jz load_guest_fs_register.Error
        test eax, (1 << 10)
        jnz load_guest_fs_register.Next
        
        ;;
        ;; ���� non-conforming �Σ����Ȩ��
        ;; ��Ҫ���㣺
        ;; 1) DPL >= SS.RPL
        ;; 2) DPL >= RPL
        ;;
        shr eax, 13
        and eax, 03h                                            ; DPL
        movzx esi, WORD [ebx + TSS32.Ss]
        and esi, 03h                                            ; SS.RPL
        cmp eax, esi                                            ; SS.RPL <= DPL ?
        jb load_guest_fs_register.Error
        
        mov esi, ecx
        and esi, 03h                                            ; RPL
        cmp eax, esi                                            ; RPL <= DPL ?
        jb load_guest_fs_register.Error
        
load_guest_fs_register.Next:
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; ��� G λ��G = 1 ʱ limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz load_guest_fs_register.@1
        shl eax, 12
        or eax, 0FFFh
load_guest_fs_register.@1:
        SetVmcsField    GUEST_FS_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_FS_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_FS_ACCESS_RIGHTS, eax
        
        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_fs_register.Done


load_guest_fs_register.NullSelector:                
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_FS_SELECTOR, ecx
        
        ;;
        ;; ���� access rights Ϊ unusable
        ;;
        SetVmcsField    GUEST_FS_ACCESS_RIGHTS, SEG_U

        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_fs_register.Done

load_guest_fs_register.Error:
        ;;
        ;; ��������ʱ��ע�� #TS �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_TS
        
        mov eax, TASK_SWITCH_LOAD_STATE_ERROR
        
load_guest_fs_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret        
        
        

;-------------------------------------------------------------------
; load_guest_gs_register()
; input:
;       esi - selector
; output:
;       eax - error code
; ������
;       1) �� guest GDT ����� GS �Ĵ���
;       2) �� task switch �����ڲ�ʹ�ã�
;-------------------------------------------------------------------
load_guest_gs_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtBase]
        
        
        ;;
        ;; ��� GS selector �� NULL����ֱ������
        ;; ���򣬼�飺
        ;; 1) selector �Ƿ񳬳� limit
        ;; 2) ����������� P �� S λ
        ;; 3) ������Ϊ code segment��
        ;;      a) �Ƿ�Ϊ�ɶ���
        ;;      b) non-conforming ��: ��Ҫ DPL >= SS.DPL, RPL <= DPL
        ;; 
                
        and esi, 0FFF8h
        jz load_guest_gs_register.NullSelector
        
        ;;
        ;; �ҵ�������
        ;;
        REX.Wrxb
        add edx, esi 
               
        ;;
        ;; ����Ƿ񳬳� limit
        ;; ע�⣺
        ;;      ��Ϊʾ������������� LDT 
        ;;
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        add esi, 7
        cmp esi, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtLimit]
        ja load_guest_gs_register.Error
        
        ;;
        ;; ��������� P = S = 1
        ;;
        mov eax, [edx + 4]
        test eax, 9000h
        jz load_guest_gs_register.Error
        
        ;;
        ;; ������� code segment, ����Ƿ�ɶ�
        ;;
        test eax, (1 << 11)                                     ; ��� C/D λ
        jz load_guest_gs_register.Next
        test eax, (1 << 9)                                      ; ��� readable λ
        jz load_guest_gs_register.Error
        test eax, (1 << 10)
        jnz load_guest_gs_register.Next
        
        ;;
        ;; ���� non-conforming �Σ����Ȩ��
        ;; ��Ҫ���㣺
        ;; 1) DPL >= SS.RPL
        ;; 2) DPL >= RPL
        ;;
        shr eax, 13
        and eax, 03h                                            ; DPL
        movzx esi, WORD [ebx + TSS32.Ss]
        and esi, 03h                                            ; SS.RPL
        cmp eax, esi                                            ; SS.RPL <= DPL ?
        jb load_guest_gs_register.Error
        
        mov esi, ecx
        and esi, 03h                                            ; RPL
        cmp eax, esi                                            ; RPL <= DPL ?
        jb load_guest_gs_register.Error
        
load_guest_gs_register.Next:
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; ��� G λ��G = 1 ʱ limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz load_guest_gs_register.@1
        shl eax, 12
        or eax, 0FFFh
load_guest_gs_register.@1:
        SetVmcsField    GUEST_GS_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_GS_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_GS_ACCESS_RIGHTS, eax
        
        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_gs_register.Done


load_guest_gs_register.NullSelector:                
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_GS_SELECTOR, ecx
        
        ;;
        ;; ���� access rights Ϊ unusable
        ;;
        SetVmcsField    GUEST_GS_ACCESS_RIGHTS, SEG_U

        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_gs_register.Done

load_guest_gs_register.Error:
        ;;
        ;; ��������ʱ��ע�� #TS �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_TS
        
        mov eax, TASK_SWITCH_LOAD_STATE_ERROR
        
load_guest_gs_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        
            
        
        
;-------------------------------------------------------------------
; load_guest_ldtr_register()
; input:
;       esi - selector
; output:
;       none
; ������
;       1) �� guest GDT ����� LDTR �Ĵ���
;       2) �� task switch �����ڲ�ʹ�ã�
;-------------------------------------------------------------------
load_guest_ldtr_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi
        REX.Wrxb
        mov ebx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.NewTaskTss]
        REX.Wrxb
        mov edx, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtBase]
        
        
        ;;
        ;; ��� LDTR selector �� NULL����ֱ������
        ;; ���򣬼�飺
        ;; 1) selector �Ƿ񳬳� limit
        ;; 2) ����������� P �� S λ
        ;; 
                
        and esi, 0FFF8h
        jz load_guest_ldtr_register.NullSelector
        
        ;;
        ;; �ҵ�������
        ;;
        REX.Wrxb
        add edx, esi 
               
        ;;
        ;; ����Ƿ񳬳� limit
        ;;
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        add esi, 7
        cmp esi, [ebp + PCB.GuestExitInfo + TASK_SWITCH_INFO.GuestGdtLimit]
        ja load_guest_ldtr_register.Error
        
        ;;
        ;; ��������� P = 1, S = 0
        ;;
        mov eax, [edx + 4]
        test eax, (1 << 15)
        jz load_guest_ldtr_register.Error
        test eax, (1 << 12)
        jnz load_guest_ldtr_register.Error
        
        ;;
        ;; �������������: bits 11:8 = 0010
        ;;
        test eax, 0D00h
        jnz load_guest_ldtr_register.Error

        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; ��� G λ��G = 1 ʱ limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz load_guest_ldtr_register.@1
        shl eax, 12
        or eax, 0FFFh
load_guest_ldtr_register.@1:
        SetVmcsField    GUEST_LDTR_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_LDTR_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_LDTR_ACCESS_RIGHTS, eax
        
        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_ldtr_register.Done


load_guest_ldtr_register.NullSelector:                
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_LDTR_SELECTOR, ecx
        
        ;;
        ;; ���� access rights Ϊ unusable
        ;;
        SetVmcsField    GUEST_LDTR_ACCESS_RIGHTS, SEG_U

        mov eax, TASK_SWITCH_LOAD_STATE_SUCCESS
        jmp load_guest_ldtr_register.Done

load_guest_ldtr_register.Error:
        ;;
        ;; ��������ʱ��ע�� #TS �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_TS
        
        mov eax, TASK_SWITCH_LOAD_STATE_ERROR
        
load_guest_ldtr_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
        

;-------------------------------------------------------------------
; do_load_ldtr_register()
; input:
;       esi - selector
; output:
;       none
; ������
;       1) �� guest GDT ����� LDTR �Ĵ���
;       2) ʹ���� LLDT ָ����
;-------------------------------------------------------------------
do_load_ldtr_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]

        ;;
        ;; �ҵ� GDT.base
        ;;
        REX.Wrxb
        mov esi, [ebx + VMB.GuestGmb + GGMB.GdtBase]
        call get_system_va_of_guest_os
        REX.Wrxb
        mov edx, eax


        ;;
        ;; ��� LDT selector �� NULL������� #GP(0)
        ;; ���򣬼�飺
        ;; 1) selector �Ƿ񳬳� limit
        ;; 2) ����������� P �� S λ
        ;; 
        mov esi, ecx
        and esi, 0FFF8h
        jz do_load_ldtr_register.Gp0
       
        ;;
        ;; �ҵ�������
        ;;
        REX.Wrxb
        add edx, esi 
               
        ;;
        ;; ����Ƿ񳬳� limit, ������� #GP(selector)
        ;;
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        add esi, 7
        cmp si, [ebx + VMB.GuestGmb + GGMB.GdtLimit]
        ja do_load_ldtr_register.GpSelector
        
        ;;
        ;; ��������� P = 1, S = 0
        ;; 1) P = 0������ #NP(selector)
        ;; 2) S = 0, ���� #GP(selector)
        ;;
        mov eax, [edx + 4]
        test eax, (1 << 15)
        jz do_load_ldtr_register.Np
        test eax, (1 << 12)
        jnz do_load_ldtr_register.GpSelector
        
        ;;
        ;; �������������: bits 11:8 = 0010
        ;;
        test eax, 0D00h
        jnz do_load_ldtr_register.GpSelector

        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_LDTR_SELECTOR, ecx
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; ��� G λ��G = 1 ʱ limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz do_load_ldtr_register.@1
        shl eax, 12
        or eax, 0FFFh
do_load_ldtr_register.@1:
        SetVmcsField    GUEST_TR_LIMIT, eax

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_LDTR_BASE, eax
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_LDTR_ACCESS_RIGHTS, eax
        
        mov eax, LOAD_LDTR_SUCCESS
        jmp do_load_ldtr_register.Done


        
do_load_ldtr_register.GpSelector:
        ;;
        ;; ע�� #GP �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_GP
        
        mov eax, LOAD_LDTR_ERROR
        jmp do_load_ldtr_register.Done

do_load_ldtr_register.Gp0:
        ;;
        ;; ע�� #GP �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_GP
        
        mov eax, LOAD_LDTR_ERROR
        jmp do_load_ldtr_register.Done

do_load_ldtr_register.Np:
        ;;
        ;; ע�� #GP �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_NP
        
        mov eax, LOAD_LDTR_ERROR
        jmp do_load_ldtr_register.Done

do_load_ldtr_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret


;-------------------------------------------------------------------
; do_load_tr_register()
; input:
;       esi - selector
; output:
;       eax - ״̬��
; ������
;       1) �� guest GDT ����� TR �Ĵ���
;       2) ʹ���� LTR ָ����
;-------------------------------------------------------------------
do_load_tr_register:
        push ebp
        push ebx
        push ecx
        push edx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov ecx, esi

        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]

        ;;
        ;; �ҵ� GDT.base
        ;;
        REX.Wrxb
        mov esi, [ebx + VMB.GuestGmb + GGMB.GdtBase]
        call get_system_va_of_guest_os
        REX.Wrxb
        mov edx, eax


        ;;
        ;; ��� TR selector �� NULL������� #GP(0)
        ;; ���򣬼�飺
        ;; 1) selector �Ƿ񳬳� limit
        ;; 2) ����������� P �� S λ
        ;; 
        mov esi, ecx
        and esi, 0FFF8h
        jz do_load_tr_register.Gp0
       
        ;;
        ;; �ҵ�������
        ;;
        REX.Wrxb
        add edx, esi 
               
        ;;
        ;; ����Ƿ񳬳� limit, ������� #GP(selector)
        ;;
        ;;
        ;; (selector & 0xFFF8 + 7) > limit ?
        ;;
        add esi, 7
        cmp si, [ebx + VMB.GuestGmb + GGMB.GdtLimit]
        ja do_load_tr_register.GpSelector
        
        ;;
        ;; ��������� P = 1, S = 0
        ;; 1) P = 0������ #NP(selector)
        ;; 2) S = 0, ���� #GP(selector)
        ;;
        mov eax, [edx + 4]
        test eax, (1 << 15)
        jz do_load_tr_register.Np
        test eax, (1 << 12)
        jnz do_load_tr_register.GpSelector
        
        ;;
        ;; �������������: bits 11:8 = 0011(busy TSS) ����� #GP(selector)
        ;;
        test eax, 0600h
        jnz do_load_tr_register.GpSelector
        test eax, 100h
        jz do_load_tr_register.GpSelector
        
        ;;
        ;; �� TSS ������Ϊ busy
        ;;
        bts DWORD [edx + 4], 9                                  ; B = 1
        
        ;;
        ;; ���� selector
        ;;
        SetVmcsField    GUEST_TR_SELECTOR, ecx
        mov [ebx + VMB.GuestTmb + GTMB.TssSelector], cx         ; ���� guest TSS selector
        
        ;;
        ;; ���� limit
        ;;
        movzx eax, WORD [edx]                                   ; limit bits 15:0
        mov esi, [edx + 4]
        and esi, 0F0000h                                        ; limit bits 19:16
        or eax, esi
        ;;
        ;; ��� G λ��G = 1 ʱ limit32 = limit20 * 1000h + 0FFFh
        ;;
        test DWORD [edx + 4], (1 << 23)
        jz do_load_tr_register.@1
        shl eax, 12
        or eax, 0FFFh
do_load_tr_register.@1:
        SetVmcsField    GUEST_TR_LIMIT, eax
        mov [ebx + VMB.GuestTmb + GTMB.TssLimit], eax           ; ���� guest TSS limit

        ;;
        ;; ���� base
        ;;
        mov esi, [edx]                                          ; ������ low 32
        mov edi, [edx + 4]                                      ; ������ high 32
        shr esi, 16
        and esi, 0FFFFh                                         ; base bits 15:0
        mov eax, edi
        and eax, 0FF000000h                                     ; base bits 31:24
        shl edi, (23 - 7)
        and edi, 00FF0000h                                      ; base bits 23:16
        or eax, esi
        or eax, edi                                             ; base bits 31:0
        SetVmcsField    GUEST_TR_BASE, eax
        mov [ebx + VMB.GuestTmb + GTMB.TssBase], eax            ; ���� guest TSS base
        
        ;;
        ;; ���� access rights
        ;;
        movzx eax, WORD [edx + 5]
        and eax, 0F0FFh
        SetVmcsField    GUEST_TR_ACCESS_RIGHTS, eax
        mov [ebx + VMB.GuestTmb + GTMB.TssAccessRights], eax    ; ���� guest TSS AccessRights
        
        mov eax, LOAD_TR_SUCCESS
        jmp do_load_tr_register.Done


        
do_load_tr_register.GpSelector:
        ;;
        ;; ע�� #GP �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx  
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_GP
        
        mov eax, LOAD_TR_ERROR
        jmp do_load_tr_register.Done

do_load_tr_register.Gp0:
        ;;
        ;; ע�� #GP �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, 0
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_GP
        
        mov eax, LOAD_TR_ERROR
        jmp do_load_tr_register.Done

do_load_tr_register.Np:
        ;;
        ;; ע�� #GP �쳣
        ;;
        SetVmcsField    VMENTRY_EXCEPTION_ERROR_CODE, ecx
        SetVmcsField    VMENTRY_INTERRUPTION_INFORMATION, INJECT_EXCEPTION_NP
        
        mov eax, LOAD_TR_ERROR
        jmp do_load_tr_register.Done

do_load_tr_register.Done:
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret
                
                
                
;-------------------------------------------------------------------
; get_address_of_gdt_descriptor()
; input:
;       esi - selector
; output:
;       eax - system va
; ������
;       1) ���� guest GDT ����������ַ��system virtual address)
;-------------------------------------------------------------------
get_address_of_gdt_descriptor:
        push ebp
        push ebx
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        REX.Wrxb
        mov ebx, [ebp + PCB.CurrentVmbPointer]
        mov ecx, esi
        and ecx, 0FFF8h
        REX.Wrxb
        mov esi,  [ebx + VMB.GuestGmb + GGMB.GdtBase]
        call get_system_va_of_guest_os
        REX.Wrxb
        add eax, ecx        
        pop ecx
        pop ebx
        pop ebp
        ret


