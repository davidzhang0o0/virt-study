;*************************************************
;* VmxInit.asm                                   *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************
        






;----------------------------------------------------------
; vmx_operation_enter()
; input:
;       esi - VMXON region pointer
; output:
;       0 - successful
;       otherwise - ������
; ������
;       1) ʹ���������� VMX root operation ����
;----------------------------------------------------------
vmx_operation_enter:
        push ecx
        push edx
        push ebp
        
                
        
%ifdef __X64        
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        mov eax, STATUS_SUCCESS
        
        ;;
        ;; ����Ƿ��Ѿ������� VMX root operation ģʽ
        ;;
        test DWORD [ebp + PCB.ProcessorStatus], CPU_STATUS_VMXON
        jnz vmx_operation_enter.done

        ;;
        ;; ����Ƿ�֧�� VMX 
        ;;
        bt DWORD [ebp + PCB.FeatureEcx], 5
        mov eax, STATUS_UNSUCCESS
        jnc vmx_operation_enter.done        
        
        ;;
        ;; ���� VMX operation ����
        ;;
        REX.Wrxb
        mov eax, cr4
        REX.Wrxb
        bts eax, 13                                     ; CR4.VMEX = 1
        REX.Wrxb
        mov cr4, eax
        
        ;;
        ;; ����ָ��״̬������ִ�� VMX ָ��
        ;;
        or DWORD [ebp + PCB.InstructionStatus], INST_STATUS_VMX
        
        ;;
        ;; ��ʼ�� VMXON ����
        ;;
        call initialize_vmxon_region
        cmp eax, STATUS_SUCCESS
        jne vmx_operation_enter.done

        ;;
        ;; ���� VMX root operation ģʽ
        ;; 1) operand �������ַ pointer
        ;;
        vmxon [ebp + PCB.VmxonPhysicalPointer]

        ;;
        ;; ��� VMXON ָ���Ƿ�ִ�гɹ�
        ;; 1) �� CF = 0 ʱ��WMXON ִ�гɹ�
        ;; 1) �� CF = 1 ʱ������ʧ��
        ;;
        mov eax, STATUS_UNSUCCESS
        jc vmx_operation_enter.done
        jz vmx_operation_enter.done

        ;;
        ;; ʹ�� "all-context invalidation" ����ˢ�� cache
        ;;
        mov eax, ALL_CONTEXT_INVALIDATION
        invvpid eax, [ebp + PCB.InvDesc]
        invept eax, [ebp + PCB.InvDesc]
        
        
        ;;
        ;; ���ݴ����� index ֵ������ VPID ͷ
        ;;
        mov ecx, [ebp + PCB.ProcessorIndex]
        shl ecx, 8
        
        ;;
        ;; ���� VMM stack
        ;;
        call get_kernel_stack_pointer
        REX.Wrxb
        mov [ebp + PCB.VmmStack], eax
        
        ;;
        ;; ���� VMM Msr-load ����
        ;;
        call get_vmcs_access_pointer
        REX.Wrxb
        mov [ebp + PCB.VmmMsrLoadAddress], eax
        REX.Wrxb
        mov [ebp + PCB.VmmMsrLoadPhyAddress], edx
        
        
        ;;
        ;; ���� VMCS A ���򣬲���Ϊȱʡ�� VMCS ����
        ;;
        call get_vmcs_pointer
        REX.Wrxb
        mov [ebp + PCB.GuestA + 8], eax                                 ; VMCS A �����ַ
        REX.Wrxb
        mov [ebp + PCB.GuestA], edx                                     ; VMCS A �����ַ
        mov ax, cx
        or ax, 1
        mov [ebp + PCB.GuestA + VMB.Vpid], ax                           ; VMCS A �� VPID
        
        ;;
        ;; ���� VMCS B ����
        ;;        
        call get_vmcs_pointer
        REX.Wrxb
        mov [ebp + PCB.GuestB + 8], eax                                 ; VMCS B �����ַ
        REX.Wrxb
        mov [ebp + PCB.GuestB], edx                                     ; VMCS B �����ַ        
        mov ax, cx
        or ax, 2
        mov [ebp + PCB.GuestB + VMB.Vpid], ax                           ; VMCS B �� VPID
        
        ;;
        ;; ���� VMCS C ����
        ;;        
        call get_vmcs_pointer
        REX.Wrxb
        mov [ebp + PCB.GuestC + 8], eax                                 ; VMCS C �����ַ
        REX.Wrxb
        mov [ebp + PCB.GuestC], edx                                     ; VMCS C �����ַ
        mov ax, cx
        or ax, 3
        mov [ebp + PCB.GuestC + VMB.Vpid], ax
        
        ;;
        ;; ���� VMCS D ����
        ;;          
        call get_vmcs_pointer
        REX.Wrxb
        mov [ebp + PCB.GuestD + 8], eax                                 ; VMCS D �����ַ
        REX.Wrxb
        mov [ebp + PCB.GuestD], edx                                     ; VMCS D �����ַ
        mov ax, cx
        or ax, 4
        mov [ebp + PCB.GuestC + VMB.Vpid], ax
                
        
%if 0        
                
        ;;
        ;; ��ʼ�� EPT �ṹ
        ;;
        cmp BYTE [ebp + PCB.IsBsp], 1
        jne vmx_operation_enter.@0
     
        call init_ept_pxt_ppt
%endif        

vmx_operation_enter.@0:        
                
        ;;
        ;; ���´�����״̬
        ;;
        or DWORD [ebp + PCB.ProcessorStatus], CPU_STATUS_VMXON
        
        mov eax, STATUS_SUCCESS
        
vmx_operation_enter.done:
        pop ebp
        pop edx
        pop ecx
        ret




;----------------------------------------------
; initialize_vmxon_region()
; input:
;       none
; output:
;       0 - successful
;       otherwise - ������
; ������
;       1) ��ʼ�� VMM��host���� vmxon region
;----------------------------------------------
initialize_vmxon_region:
        push ebx
        push ecx
        push ebp

%ifdef __X64
        LoadGsBaseToRbp      
%else
        mov ebp, [gs: PCB.Base]
%endif        

        ;;
        ;; �� CR0 ��ǰֵ
        ;;
        REX.Wrxb
        mov ecx, cr0
        mov ebx, ecx
        
        ;;
        ;; ��� CR0.PE �� CR0.PG �Ƿ���� fixed λ������ֻ���� 32 λֵ
        ;; 1) �Ա� Cr0FixedMask ֵ���̶�Ϊ1ֵ��������ͬ�򷵻ش�����
        ;;
        mov eax, STATUS_VMX_UNEXPECT                    ; �����루��������ֵ��
        xor ecx, [ebp + PCB.Cr0FixedMask]               ; �� Cr0FixedMask ֵ��򣬼���Ƿ���ͬ
        js initialize_vmxon_region.done                 ; ��� CR0.PG λ�Ƿ����
        test ecx, 1
        jnz initialize_vmxon_region.done                ; ��� CR0.PE λ�Ƿ����
        
        ;;
        ;; ��� CR0.PE �� CR0.PG λ��������� CR0 ����λ
        ;;
        or ebx, [ebp + PCB.Cr0Fixed0]                   ; ���� Fixed 1 λ
        and ebx, [ebp + PCB.Cr0Fixed1]                  ; ���� Fixed 0 λ
        REX.Wrxb
        mov cr0, ebx                                    ; д�� CR0
        
        ;;
        ;; ֱ������ CR4 fixed 1 λ
        ;;
        REX.W
        mov ecx, cr4
        or ecx, [ebp + PCB.Cr4FixedMask]                ; ���� Fixed 1 λ
        and ecx, [ebp + PCB.Cr4Fixed1]                  ; ���� Fixed 0 λ
        REX.W
        mov cr4, ecx
        
        ;;
        ;; ���� VMXON region
        ;;
        call get_vmcs_access_pointer                    ; edx:eax = pa:va
        REX.Wrxb
        mov [ebp + PCB.VmxonPointer], eax
        REX.Wrxb
        mov [ebp + PCB.VmxonPhysicalPointer], edx
        
        ;;
        ;; ���� VMCS region ��Ϣ
        ;;
        REX.Wrxb      
        mov ebx, [ebp + PCB.VmxonPointer]
        mov eax, [ebp + PCB.VmxBasic]                   ; ��ȡ VMCS revision identifier ֵ 
        mov [ebx], eax                                  ; д�� VMCS ID

        mov eax, STATUS_SUCCESS
                
initialize_vmxon_region.done:        
        pop ebp
        pop ecx
        pop ebx
        ret        
        



        
;----------------------------------------------------------
; vmx_operation_exit()
; input:
;       none
; output:
;       0 - successful
;       otherwise - ������
; ����: 
;       1) ʹ�������˳� VMX root operation ����
;----------------------------------------------------------
vmx_operation_exit:
        push ebp
        
%ifdef __X64        
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        ;;
        ;; ����Ƿ��� VMX ģʽ
        ;;
        test DWORD [ebp + PCB.ProcessorStatus], CPU_STATUS_VMXON
        jz vmx_operation_exit.done
        
        ;;
        ;; ʹ�� "all-context invalidation" ����ˢ�� cache
        ;;
        mov eax, ALL_CONTEXT_INVALIDATION
        invvpid eax, [ebp + PCB.InvDesc]
        invept eax, [ebp + PCB.InvDesc]
        
        vmxoff
        ;;
        ;; ����Ƿ�ɹ�
        ;; 1) �� CF = 0 �� ZF = 0 ʱ��VMXOFF ִ�гɹ�
        ;;
        mov eax, STATUS_VMXOFF_UNSUCCESS
        jc vmx_operation_exit.done
        jz vmx_operation_exit.done

                
        ;;
        ;; ����ر� CR4.VMXE ��־λ
        ;;
        REX.Wrxb
        mov eax, cr4
        btr eax, 13
        REX.Wrxb
        mov cr4, eax
                
        ;;
        ;; ����ָ��״̬
        ;;
        and DWORD [ebp + PCB.InstructionStatus], ~INST_STATUS_VMX
        ;;
        ;; ���´�����״̬
        ;;
        and DWORD [ebp + PCB.ProcessorStatus], ~CPU_STATUS_VMXON
        
        mov eax, STATUS_SUCCESS
        
vmx_operation_exit.done:
        pop ebp
        ret
        

      


;-----------------------------------------------------------
; initialize_vmcs_buffer()
; input:
;       esi - VM_MANAGE_BLOCK pointer
; output:
;       0 - successful
;       otherwise - ������
; ������
;       1) ��ʼ���ṩ�� vmcs buffer���� VM �����ָ���ṩ��
;-----------------------------------------------------------
initialize_vmcs_buffer:
        push ebp
        push ecx
        push ebx
        push edx        
        
        ;;
        ;; PCB ��ַ
        ;;
%ifdef __X64
        LoadGsBaseToRbp              
%else
        mov ebp, [gs: PCB.Base]
%endif      

        push esi                                                ; ���� VMCS �����ָ��
        
        REX.Wrxb
        mov ebx, esi

        ;;
        ;; д�� VMCS region �� Identifier ֵ
        ;;
        mov eax, [ebp + PCB.VmxBasic]
        REX.Wrxb
        mov edi, [ebx + VMB.Base]                               ; VMCS region �����ַ
        mov [edi], eax
        
        ;;
        ;; д�� VMM �����¼
        ;;
        REX.Wrxb
        mov eax, [ebp + PCB.VmmStack]
        REX.Wrxb
        mov [ebx + VMB.HostStack], eax
        REX.Wrxb
        mov eax, [ebp + PCB.VmmMsrLoadAddress]
        REX.Wrxb
        mov [ebx + VMB.VmExitMsrLoadAddress], eax
        REX.Wrxb
        mov eax, [ebp + PCB.VmmMsrLoadPhyAddress]
        REX.Wrxb
        mov [ebx + VMB.VmExitMsrLoadPhyAddress], eax
        
        
        ;;
        ;; ��ʼ�� VM �� VSB ����
        ;;
        REX.Wrxb
        mov esi, ebx
        call init_vm_storage_block
        
        ;;
        ;; ��ʼ�� VM domain
        ;;
        call vm_alloc_domain
        REX.Wrxb
        mov [ebx + VMB.DomainBase], eax
        REX.Wrxb
        mov [ebx + VMB.DomainPhysicalBase], edx
        REX.Wrxb
        add edx, (DOMAIN_SIZE - 1)
        mov [ebx + VMB.DomainPhysicalTop], edx

        ;;
        ;; ��ʼ�� EP4TA
        ;;
        call get_vmcs_access_pointer
        REX.Wrxb
        mov [ebx + VMB.Ep4taBase], eax
        REX.Wrxb
        mov [ebx + VMB.Ep4taPhysicalBase], edx
        
        ;;
        ;; ����Ϊ VMCS region ������ص� access page��������
        ;; 1) IoBitmap A page
        ;; 2) IoBitmap B page
        ;; 3) Virtual-access page
        ;; 4) MSR-Bitmap page
        ;; 5) VM-entry/VM-exit MSR store page
        ;; 6) VM-exit MSR load page
        ;; 7) IoVteBuffer page
        ;; 8) MsrVteBuffer page
        ;; 9) GpaHteBuffer page
        ;;

        mov ecx, 9                                              ; �� 9 �� access page
        REX.Wrxb
        lea ebx, [ebx + VMB.IoBitmapAddressA]                   ; VMB.IoBitmapAddressA ��ַ

        
        ;;
        ;; ʹ�� get_vmcs_access_pointer() ����һ�� access page
        ;; 1) edx:eax ���ض�Ӧ�� physical address �� virtual address
        ;; 2) �� X64 �·��ض�Ӧ�� 64 λ��ַ
        ;; 3) ע�⣺���ﲻ��� get_vmcs_access_pointer() �ķ���ֵ��
        ;;          ��Ϊ��ʾ����û��Ƶ������ڴ���Դ�����Σ�
        ;;
        
initialize_vmcs_buffer.loop:
        call get_vmcs_access_pointer
        REX.Wrxb
        mov [ebx], eax                                          ; д�� access page �����ַ
        REX.Wrxb
        mov [ebx + 8], edx                                      ; д�� access page �����ַ
        REX.Wrxb
        add ebx, 16                                             ; ָ����һ����¼        
        DECv ecx
        jnz initialize_vmcs_buffer.loop
        

        pop ebx                                                ; ebx - VMCS �����ָ��        
        xor eax, eax
        
        ;;
        ;; ��ʼ�� IO & MSR table entry ����ֵ
        ;;
        mov [ebx + VMB.IoVteCount], eax
        mov [ebx + VMB.MsrVteCount], eax
        mov [ebx + VMB.GpaHteCount], eax


        ;;
        ;; ��ʼ�� MSR-store/MSR-load �б����ֵ
        ;;
        mov [ebx + VMB.VmExitMsrStoreCount], eax
        mov [ebx + VMB.VmExitMsrLoadCount], eax
        
        ;;
        ;; ��ʼ�� IO VTE, MSR VTE, GPA HTE, EXTINT ITE ָ��
        ;;
        REX.Wrxb
        mov eax, [ebx + VMB.IoVteBuffer]
        REX.Wrxb
        mov [ebx + VMB.IoVteIndex], eax
        REX.Wrxb
        mov eax, [ebx + VMB.MsrVteBuffer]
        REX.Wrxb
        mov [ebx + VMB.MsrVteIndex], eax
        REX.Wrxb
        mov eax, [ebx + VMB.GpaHteBuffer]
        REX.Wrxb
        mov [ebx + VMB.GpaHteIndex], eax

        ;;
        ;; IO ������־λ
        ;;
        mov DWORD [ebx + VMB.IoOperationFlags], 0
        
        ;;
        ;; ��ʼ�� guest-status
        ;;
        mov DWORD [ebx + VMB.GuestSmb + GSMB.ProcessorStatus], 0
        mov DWORD [ebx + VMB.GuestSmb + GSMB.InstructionStatus], 0

                
        
        ;;
        ;; ��� VMCS buffer
        ;;
        mov esi, EXECUTION_CONTROL_SIZE
        REX.Wrxb
        lea edi, [ebp + PCB.ExecutionControlBuf]
        call zero_memory
        mov esi, ENTRY_CONTROL_SIZE
        REX.Wrxb
        lea edi, [ebp + PCB.EntryControlBuf]
        call zero_memory        
        mov esi, EXIT_CONTROL_SIZE
        REX.Wrxb
        lea edi, [ebp + PCB.ExitControlBuf]
        call zero_memory
        mov esi, HOST_STATE_SIZE
        REX.Wrxb
        lea edi, [ebp + PCB.HostStateBuf]
        call zero_memory        
        mov esi, GUEST_STATE_SIZE
        REX.Wrxb
        lea edi, [ebp + PCB.GuestStateBuf]
        call zero_memory        

        
        ;;
        ;; ����ֱ��ʼ������ VMCS �򣬰�����
        ;; 1) VM execution control fields
        ;; 2) VM-exit control fields
        ;; 3) VM-entry control fields
        ;; 4) VM host state fields
        ;; 5) VM guest state fields
        ;;       
        REX.Wrxb
        mov esi, ebx
        call init_vm_execution_control_fields
        REX.Wrxb
        mov esi, ebx
        call init_vm_exit_control_fields
        REX.Wrxb
        mov esi, ebx
        call init_vm_entry_control_fields
        REX.Wrxb
        mov esi, ebx
        call init_host_state_area

        REX.Wrxb
        mov esi, ebx

        ;;
        ;; ���guestΪʵģʽ������� init_realmode_guest_sate
        ;;
        mov eax, init_guest_state_area
        mov ebx, init_realmode_guest_state
        test DWORD [esi + VMB.GuestFlags], GUEST_FLAG_PE
        cmovz eax, ebx
        call eax

        pop edx
        pop ebx
        pop ecx
        pop ebp        
        ret



;-----------------------------------------------------------
; init_vm_storage_block()
; input:
;       esi - VMB pointer
; output:
;       none
; ������
;       1) ��ʼ�� VM ˽�Ĵ洢����
;-----------------------------------------------------------
init_vm_storage_block:
        push ebx
        push edx
        
        
        REX.Wrxb
        mov ebx, esi
        
        ;;
        ;; ���� VSB��VM storage block������
        ;;
        mov esi, ((VSB_SIZE + 0FFFh) / 1000h)
        call alloc_kernel_pool_n
        REX.Wrxb
        mov [ebx + VMB.VsbBase], eax                            ; edx:eax = PA:VA
        REX.Wrxb
        mov [ebx + VMB.VsbPhysicalBase], edx  

        ;;
        ;; ��ʼ�� VSB �����¼
        ;;
        REX.Wrxb
        mov [eax + VSB.Base], eax
        REX.Wrxb
        mov [eax + VSB.PhysicalBase], edx
        
        ;;
        ;; ��ʼ�� VM video buffer �����¼
        ;;        
        REX.Wrxb
        lea esi, [eax + VSB.VmVideoBuffer]
        REX.Wrxb
        mov [eax + VSB.VmVideoBufferHead], esi
        REX.Wrxb
        mov [eax + VSB.VmVideoBufferPtr], esi

        ;;
        ;; ��ʼ�� VM keryboard buffer �����¼
        ;;
        REX.Wrxb
        lea esi, [eax + VSB.VmKeyBuffer]
        REX.Wrxb
        mov [eax + VSB.VmKeyBufferHead], esi
        REX.Wrxb
        mov [eax + VSB.VmKeyBufferPtr], esi
        mov DWORD [eax + VSB.VmKeyBufferSize], 256
        
        ;;
        ;; ���´�����״̬���������� guest ����
        ;;
        mov eax, PCB.ProcessorStatus
        or DWORD [gs: eax], CPU_STATUS_GUEST_EXIST
        
        pop edx
        pop ebx      
        ret




;-----------------------------------------------------------
; setup_vmcs_region():
; input:
;       none
; output:
;       none
;-----------------------------------------------------------
setup_vmcs_region:
        ;;
        ;; ���潫 VMCS buffer ����ˢ�µ� VMCS ��
        ;;
        call flush_execution_control
        call flush_exit_control
        call flush_entry_control
        call flush_host_state
        call flush_guest_state        
        ret

        
        
      



;----------------------------------------------------------
; init_guest_state_area()
; input:
;       esi - VMB pointer
; output:
;       none
; ������
;       1) ���� VMCS �� HOST STAGE ����
;       2) ���Ǳ���ģʽ����IA-32eģʽ�� guest��������
;----------------------------------------------------------   
init_guest_state_area:
        push ebp
        push edx
        push ecx
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp                                         ; ebp = PCB.Base
        LoadFsBaseToRbx                                         ; ebx = SDA.Base
%else
        mov ebp, [gs: PCB.Base]
        mov ebx, [fs: SDA.Base]
%endif

%define GuestStateBufBase                       (ebp + PCB.GuestStateBuf)
%define ExecutionControlBufBase                 (ebp + PCB.ExecutionControlBuf)
%define EntryControlBufBase                     (ebp + PCB.EntryControlBuf)
        
        REX.Wrxb
        mov edx, esi
        
        
        ;;
        ;; �ڱ���ģʽ�� IA-32e ģʽ��, guest ������
        ;; 1) CR0 = Cr0FixedMask
        ;; 2) CR4 = Cr4FixedMask | PAE | OSFXSR
        ;; 3) CR3 = ��ǰֵ
        ;;
        mov eax, [ebp + PCB.Cr0FixedMask]               ; CR0 �̶�ֵ
        REX.Wrxb
        mov esi, [ebp + PCB.Cr4FixedMask]
        or esi, CR4_PAE | CR4_OSFXSR                    ; ʹ�� PAE ��ҳģʽ
        
        REX.Wrxb
        mov edi, cr3                                    ; CR3 ��ǰֵ
        
        ;;
        ;; ��� GUEST_PG Ϊ 0������ CR0.PG λ
        ;;
        test DWORD [edx + VMB.GuestFlags], GUEST_FLAG_PG
        jnz init_guest_state_area.@0
        and eax, 7FFFFFFFh
        
init_guest_state_area.@0:        
        ;;
        ;; д�� CR0, CR4 �Լ� CR3
        ;;
        REX.Wrxb
        mov [GuestStateBufBase  + GUEST_STATE.Cr0], eax
        REX.Wrxb
        mov [GuestStateBufBase  + GUEST_STATE.Cr4], esi
        REX.Wrxb
        mov [GuestStateBufBase  + GUEST_STATE.Cr3], edi
        
     
        ;;
        ;; DR7 = 400h
        ;;        
        mov eax, 400h
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Dr7], eax
        
        ;;
        ;; RIP = guest_entry, Rflags = 202h(IF=1)
        ;;
        REX.Wrxb
        mov eax, [edx + VMB.GuestEntry]
        mov ecx, 02h | FLAGS_IF
        
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Rip], eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Rflags], ecx


        REX.Wrxb
        mov eax, [edx + VMB.GuestStack]                
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Rsp], eax



                
        ;;
        ;; �������� segment register ���ֵ
        ;; 1) 16 λ selector
        ;; 2) 32 λ base
        ;; 3) 32 λ limit
        ;; 4) 32 λ access right
        ;;  
        
        ;;
        ;; ��� guest �Ƿ�Ϊ IA-32e ģʽ
        ;;
        test DWORD [edx + VMB.GuestFlags], GUEST_FLAG_IA32E
        jz init_guest_state_area.@1
        
        ;;
        ;; �� IA-32e ģʽ�µ� selector:
        ;; 1) CS = KerelCsSelector64
        ;; 2) ES/SS/DS = KernelSsSelector64
        ;; 3) FS = FsSelector, GS = ��ǰֵ
        ;; 4) LDTR = 0
        ;; 5) TR = ��ǰֵ
        ;;
        mov WORD [GuestStateBufBase + GUEST_STATE.FsSelector], FsSelector
        mov ax, [ebp + PCB.GsSelector]        
        mov WORD [GuestStateBufBase + GUEST_STATE.GsSelector], ax        
        mov WORD [GuestStateBufBase + GUEST_STATE.LdtrSelector], 0        
        mov ax, [ebp + PCB.TssSelector]
        mov [GuestStateBufBase + GUEST_STATE.TrSelector], ax

        ;;
        ;; ��� guest ʹ�� 3 ����USER��Ȩ��
        ;;
        test DWORD [edx + VMB.GuestFlags], GUEST_FLAG_USER
        jz init_guest_state_area.@01
        
        mov WORD [GuestStateBufBase + GUEST_STATE.CsSelector], KernelCsSelector64 | 3
        mov WORD [GuestStateBufBase + GUEST_STATE.SsSelector], KernelSsSelector64 | 3
        mov WORD [GuestStateBufBase + GUEST_STATE.DsSelector], KernelSsSelector64 | 3
        mov WORD [GuestStateBufBase + GUEST_STATE.EsSelector], KernelSsSelector64 | 3
        
        jmp init_guest_state_area.@02
        
init_guest_state_area.@01:        
        
        mov WORD [GuestStateBufBase + GUEST_STATE.CsSelector], KernelCsSelector64
        mov WORD [GuestStateBufBase + GUEST_STATE.SsSelector], KernelSsSelector64
        mov WORD [GuestStateBufBase + GUEST_STATE.DsSelector], KernelSsSelector64
        mov WORD [GuestStateBufBase + GUEST_STATE.EsSelector], KernelSsSelector64

        
init_guest_state_area.@02:
                        
        ;;
        ;; �� IA-32e ģʽ�µ� limit��Ϊ���� host ���һ�£����� limit ����Ϊ
        ;; 1) ES/CS/SS/DS = 0FFFFFFFFh
        ;; 2) FS/GS = 0FFFFFh
        ;; 3) LDTR = 0
        ;; 4) TR = 2FFFh
        ;;
        mov eax, 0FFFFFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsLimit], eax
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsLimit], eax
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsLimit], eax
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsLimit], eax
        mov DWORD [GuestStateBufBase + GUEST_STATE.FsLimit], 0000FFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.GsLimit], 0000FFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.LdtrLimit], 0
        mov DWORD [GuestStateBufBase + GUEST_STATE.TrLimit], 2FFFh

        ;;
        ;; �� IA-32e ģʽ�µ� base
        ;; 1) ES/CS/SS/DS = 0
        ;; 2) FS/GS = ��ǰֵ
        ;; 3) LDTR = 0
        ;; 4) TR = ��ǰֵ
        ;;
        xor eax, eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.CsBase], eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.SsBase], eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.DsBase], eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.EsBase], eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.LdtrBase], eax
        REX.Wrxb            
        mov [GuestStateBufBase + GUEST_STATE.FsBase], ebx
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.GsBase], ebp
        REX.Wrxb
        mov eax, [ebp + PCB.TssBase]
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.TrBase], eax
        
        ;;
        ;; 64-bit Kernel CS/SS ����������˵����
        ;; 1���� x64 ��ϵ����������������Ϊ��
        ;;      * CS = 00209800_00000000h (L=P=1, G=D=0, C=R=A=0)
        ;;      * SS = 00009200_00000000h (L=1, G=B=0, W=1, E=A=0)
        ;; 2) �� VMX �ܹ���, ��VM-exit ���� host ��Ὣ����������Ϊ��
        ;;      * CS = 00AF9B00_0000FFFFh (G=L=P=1, D=0, C=0, R=A=1)
        ;;      * SS = 00CF9300_0000FFFFh (G=P=1, B=1, E=0, W=A=1)
        ;;
        ;; 3) ��ˣ�Ϊ���� host �����������һ�£����ｫ��������Ϊ��
        ;;      * CS = 00AF9A00_0000FFFFh (G=L=P=1, D=0, C=A=0, R=1)
        ;;      * SS = 00CF9200_0000FFFFh (G=P=1, B=1, E=A=0, W=1)  
        ;;        
        mov DWORD [GuestStateBufBase + GUEST_STATE.FsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.GsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0        
        mov DWORD [GuestStateBufBase + GUEST_STATE.LdtrAccessRight], TYPE_SYS | TYPE_LDT | SEG_Ugdlp | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.TrAccessRight], TYPE_SYS | TYPE_BUSY_TSS64 | SEG_ugdlP | DPL_0
        
        ;;
        ;; ��� guest ʹ�� 3 ����USER��Ȩ��
        ;;
        test DWORD [edx + VMB.GuestFlags], GUEST_FLAG_USER
        jz init_guest_state_area.@03
        
        ;;
        ;; CS, SS, ES, DS ��Ϊ 3 ��
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsAccessRight], TYPE_NON_SYS | TYPE_CcRA | SEG_uGdLP | DPL_3
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_3
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_3
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_3
        
        jmp init_guest_state_area.@2

        
init_guest_state_area.@03:
        ;;
        ;; CS, SS, ES, DS ��Ϊ 0 ��
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsAccessRight], TYPE_NON_SYS | TYPE_CcRA | SEG_uGdLP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0
        
        jmp init_guest_state_area.@2

        
init_guest_state_area.@1:
        ;;
        ;; ����ģʽ�� selector
        ;; 1) CS = KernelCsSelector32
        ;; 2) ES/SS/DS = KernelSsSelector32
        ;; 3) FS/GS/TR = ��ǰֵ
        ;; 
        test DWORD [edx + VMB.GuestFlags], GUEST_FLAG_USER
        jz init_guest_state_area.@11
        ;;
        ;; ��Ϊ 3 ��
        ;;           
        mov WORD [GuestStateBufBase + GUEST_STATE.CsSelector], KernelCsSelector32 | 3
        mov WORD [GuestStateBufBase + GUEST_STATE.SsSelector], KernelSsSelector32 | 3
        mov WORD [GuestStateBufBase + GUEST_STATE.DsSelector], KernelSsSelector32 | 3
        mov WORD [GuestStateBufBase + GUEST_STATE.EsSelector], KernelSsSelector32 | 3
                
        jmp init_guest_state_area.@12
        
init_guest_state_area.@11:
        ;;
        ;; ��Ϊ 0 ��
        ;;
        mov WORD [GuestStateBufBase + GUEST_STATE.CsSelector], KernelCsSelector32
        mov WORD [GuestStateBufBase + GUEST_STATE.SsSelector], KernelSsSelector32
        mov WORD [GuestStateBufBase + GUEST_STATE.DsSelector], KernelSsSelector32
        mov WORD [GuestStateBufBase + GUEST_STATE.EsSelector], KernelSsSelector32
                
init_guest_state_area.@12:

        mov WORD [GuestStateBufBase + GUEST_STATE.FsSelector], FsSelector
        mov ax, [ebp + PCB.GsSelector]
        mov WORD [GuestStateBufBase + GUEST_STATE.GsSelector], ax
        mov WORD [GuestStateBufBase + GUEST_STATE.LdtrSelector], 0        
        mov ax, [ebp + PCB.TssSelector]
        mov [GuestStateBufBase + GUEST_STATE.TrSelector], ax

        ;;
        ;; ����ģʽ�� limit
        ;; 1) ES/CS/SS/DS = 0FFFFFFFFh
        ;; 2) FS/GS = 0FFFFFh
        ;; 3) LDTR = 0
        ;; 4) TR = 2FFFh
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsLimit], 0FFFFFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsLimit], 0FFFFFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsLimit], 0FFFFFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsLimit], 0FFFFFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.FsLimit], 0000FFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.GsLimit], 0000FFFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.LdtrLimit], 0
        mov DWORD [GuestStateBufBase + GUEST_STATE.TrLimit], 2FFFh
        
        ;;
        ;; ����ģʽ�� base
        ;; 1) ES/CS/SS/DS = 0
        ;; 2) FS/GS/TR = ��ǰֵ
        ;; 3) LDTR = 0
        ;;
        xor eax, eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.CsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.SsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.DsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.EsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.FsBase], ebx
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.GsBase], ebp
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.LdtrBase], eax        
        mov eax, [ebp + PCB.TssBase]
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.TrBase], eax
        
                
        ;;
        ;; ����ģʽ�� access rights
        ;; 1) CS = 0000C09Bh
        ;; 2) ES/SS/DS = 0000C093h
        ;; 3) FS/GS = 00004093h
        ;; 4) LDTR = 00010002h
        ;; 5) TR = 0000000Bh
        ;; 
        mov DWORD [GuestStateBufBase + GUEST_STATE.FsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_ugDlP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.GsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_ugDlP | DPL_0        
        mov DWORD [GuestStateBufBase + GUEST_STATE.LdtrAccessRight], TYPE_SYS | TYPE_LDT | SEG_Ugdlp | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.TrAccessRight], TYPE_SYS | TYPE_BUSY_TSS32 | SEG_ugdlP | DPL_0       
                
        test DWORD [edx + VMB.GuestFlags], GUEST_FLAG_USER
        jz init_guest_state_area.@13
        ;;
        ;; ��Ϊ 3 ��
        ;;    
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsAccessRight], TYPE_NON_SYS | TYPE_CcRA | SEG_uGDlP | DPL_3
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_3
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_3
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_3
                
        jmp init_guest_state_area.@2
        
init_guest_state_area.@13:
        ;;
        ;; ��Ϊ 0 ��
        ;;        
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsAccessRight], TYPE_NON_SYS | TYPE_CcRA | SEG_uGDlP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_uGDlP | DPL_0

        
        
        
init_guest_state_area.@2:
        ;;
        ;; д�� GDTR �� IDTR ֵ
        ;; 1) 32 λ base(x64�� 64 λ��
        ;; 2) 32 λ limit
        ;;
        REX.Wrxb
        mov eax, [ebx + SDA.GdtBase]
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.GdtrBase], eax
        REX.Wrxb
        mov eax, [ebx + SDA.IdtBase]
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.IdtrBase], eax
        movzx eax, WORD [ebx + SDA.GdtLimit]
        mov [GuestStateBufBase + GUEST_STATE.GdtrLimit], eax
        movzx eax, WORD [ebx + SDA.IdtLimit]
        mov [GuestStateBufBase + GUEST_STATE.IdtrLimit], eax

        REX.Wrxb
        mov esi, edx
     
        ;;
        ;; �Ե�ǰֵд�� MSRs
        ;; 1) IA32_DEBUGCTL
        ;; 2) IA32_SYSENTER_CS��32λ��
        ;; 3) IA32_SYSENTER_ESP
        ;; 4) IA32_SYSENTER_EIP
        ;; 5) IA32_PERF_GLOBAL_CTRL
        ;; 6) IA32_PAT
        ;; 7) IA32_EFER
        ;;            
        mov ecx, IA32_SYSENTER_CS
        rdmsr
        mov [GuestStateBufBase + GUEST_STATE.SysenterCsMsr], eax
        mov ecx, IA32_SYSENTER_ESP
        rdmsr
        mov [GuestStateBufBase + GUEST_STATE.SysenterEspMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.SysenterEspMsr + 4], edx
        mov ecx, IA32_SYSENTER_EIP
        rdmsr
        mov [GuestStateBufBase + GUEST_STATE.SysenterEipMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.SysenterEipMsr + 4], edx        
        mov ecx, IA32_PERF_GLOBAL_CTRL
        rdmsr
        mov [GuestStateBufBase + GUEST_STATE.PerfGlobalCtlMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.PerfGlobalCtlMsr + 4], edx   
        mov ecx, IA32_PAT
        rdmsr
        mov [GuestStateBufBase + GUEST_STATE.PatMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.PatMsr + 4], edx
        
        

        mov ecx, IA32_EFER
        rdmsr
        
        test DWORD [EntryControlBufBase + ENTRY_CONTROL.VmEntryControl], IA32E_MODE_GUEST
        jnz init_guest_state_area.@3
        
        ;;
        ;; �� ��IA-32e mode guest��Ϊ 0 ʱ����� LME��LMA �Լ� SCE λ
        ;;        
        and eax, ~(EFER_LME | EFER_LMA | EFER_SCE)

init_guest_state_area.@3:        

        mov [GuestStateBufBase + GUEST_STATE.EferMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.EferMsr + 4], edx        

        
        ;;
        ;; SMBASE  = 0
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.SmBase], 0
        
        
        ;;
        ;;==== ���� guest non-register state ��Ϣ ====
        ;;
        ;;
        ;; 1. Activity state = Active
        ;;
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.ActivityState], GUEST_STATE_ACTIVE
        
        ;; 2. Interruptibility state:
        ;; ˵����
        ;;    1) ȫ������Ϊ 0
        ;;    2) ���˵� guest processor ���� SMM ģʽʱ��Block by SMI ������Ϊ 1 ֵ
        ;; ��ˣ�
        ;;    [0]: Blocking by STI: No
        ;;    [1]: Blocking by MOV SS: No
        ;;    [2]: Blocking by SMI: No
        ;;    [3]: Blocking by NMI: No
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.InterruptibilityState], 0
        
        ;;
        ;; 3. Pending debug exceptions = 0
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.PendingDebugException], 0
        mov DWORD [GuestStateBufBase + GUEST_STATE.PendingDebugException + 4], 0
        
        ;;
        ;; 4. VMCS link pointer = FFFFFFFF_FFFFFFFFh
        ;;
        mov eax, 0FFFFFFFFh
        mov [GuestStateBufBase + GUEST_STATE.VmcsLinkPointer], eax
        mov [GuestStateBufBase + GUEST_STATE.VmcsLinkPointer + 4], eax
        
        ;;
        ;; 5. VMX-preemption timer value
        ;; ˵����
        ;;    1) guest ÿ 500ms ִ�� VM-exit
        ;;    2) PCB.ProcessorFrequency * us ��
        ;;
%if 0        
        mov esi, [ebp + PCB.ProcessorFrequency]
        mov eax, 500000                                                 ; 500ms
        mul esi
%endif
        mov eax, [esi + VMB.VmxTimerValue]                                      ; �� VMB ���ȡ timer value        
        mov [GuestStateBufBase + GUEST_STATE.VmxPreemptionTimerValue], eax
        
        ;;
        ;; 6. PDPTEs(Page-Directory-Pointer Table Enties)
        ;; ˵����
        ;;      1) �� SDA.Ppt �����ȡ 4 �� PDPTEs ֵ
        ;;
        mov eax, [ebx + SDA.Ppt]
        mov edx, [ebx + SDA.Ppt + 4]
        mov [GuestStateBufBase + GUEST_STATE.Pdpte0], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte0 + 4], edx        
        mov eax, [ebx + SDA.Ppt + 8 * 1]
        mov edx, [ebx + SDA.Ppt + 8 * 1 + 4]
        mov [GuestStateBufBase + GUEST_STATE.Pdpte1], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte1 + 4], edx
        mov eax, [ebx + SDA.Ppt + 8 * 2]
        mov edx, [ebx + SDA.Ppt + 8 * 2 + 4]
        mov [GuestStateBufBase + GUEST_STATE.Pdpte2], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte2 + 4], edx
        mov eax, [ebx + SDA.Ppt + 8 * 3]
        mov edx, [ebx + SDA.Ppt + 8 * 3 + 4]     
        mov [GuestStateBufBase + GUEST_STATE.Pdpte3], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte3 + 4], edx
               
        ;;
        ;; guest interrupt status
        ;;                
        mov WORD [GuestStateBufBase + GUEST_STATE.GuestInterruptStatus], 0
        
        
%undef GuestStateBufBase        
%undef ExecutionControlBufBase
%undef EntryControlBufBase

        pop ebx
        pop ecx
        pop edx
        pop ebp
        ret
        


;----------------------------------------------------------
; init_realmode_guest_state()
; input:
;       esi - VMB pointer
; output:
;       none
; ������
;       1) ����ʵģʽ�� VMCS �� GUEST STAGE ����
;----------------------------------------------------------     
init_realmode_guest_state:
        push ebp
        push edx
        push ecx
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp                                         ; ebp = PCB.Base
        LoadFsBaseToRbx                                         ; ebx = SDA.Base
%else
        mov ebp, [gs: PCB.Base]
        mov ebx, [fs: SDA.Base]
%endif

%define GuestStateBufBase                       (ebp + PCB.GuestStateBuf)

        
        ;;
        ;; ʵģʽ�� guest ������
        ;; 1) CR0 = �̶�ֵ
        ;; 2) CR4 = �̶�ֵ
        ;; 3) CR3 =  0
        ;;
        mov eax, [ebp + PCB.Cr0FixedMask]               ; CR0 �̶�ֵ
        and eax, ~(CR0_PG | CR0_PE)        
        mov edx, [ebp + PCB.Cr4FixedMask]               ; CR4 �Ĺ̶�ֵ
        xor ecx, ecx                                    ; �� CR3

      
        ;;
        ;; д�� CR0, CR4 �Լ� CR3
        ;;
        REX.Wrxb
        mov [GuestStateBufBase  + GUEST_STATE.Cr0], eax
        REX.Wrxb
        mov [GuestStateBufBase  + GUEST_STATE.Cr4], edx
        REX.Wrxb
        mov [GuestStateBufBase  + GUEST_STATE.Cr3], ecx
        
     
        ;;
        ;; DR7 = 400h
        ;;        
        mov eax, 400h
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Dr7], eax
        
        ;;
        ;; RIP = GuestEntry
        ;; Rflags = 00000002h
        ;;
        mov eax, [esi + VMB.GuestEntry]
        mov ecx, 02h
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Rip], eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Rflags], ecx


        ;;
        ;; RSP = GuestStack
        ;;
        mov eax, [esi + VMB.GuestStack]
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.Rsp], eax
          
                
        ;;
        ;; �������� segment register ���ֵ
        ;; 1) 16 λ selector
        ;; 2) 32 λ base
        ;; 3) 32 λ limit
        ;; 4) 32 λ access right
        ;;  

        ;;
        ;; selector = 0
        ;;
        mov WORD [GuestStateBufBase + GUEST_STATE.CsSelector], 0
        mov WORD [GuestStateBufBase + GUEST_STATE.SsSelector], 0
        mov WORD [GuestStateBufBase + GUEST_STATE.DsSelector], 0
        mov WORD [GuestStateBufBase + GUEST_STATE.EsSelector], 0
        mov WORD [GuestStateBufBase + GUEST_STATE.FsSelector], 0
        mov WORD [GuestStateBufBase + GUEST_STATE.GsSelector], 0
        mov WORD [GuestStateBufBase + GUEST_STATE.LdtrSelector], 0        
        mov WORD [GuestStateBufBase + GUEST_STATE.TrSelector], 0        
        
        ;;
        ;; ���� limit Ϊ 0FFFFh
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsLimit], 0FFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsLimit], 0FFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsLimit], 0FFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsLimit], 0FFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.FsLimit], 0FFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.GsLimit], 0FFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.LdtrLimit], 0FFFFh
        mov DWORD [GuestStateBufBase + GUEST_STATE.TrLimit], 0FFFFh
        
        ;;
        ;; base = 0
        ;;
        xor eax, eax
        REX.Wrxb
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.SsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.DsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.EsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.LdtrBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.FsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.GsBase], eax
        REX.Wrxb        
        mov [GuestStateBufBase + GUEST_STATE.TrBase], eax

        ;;
        ;; access rights:
        ;; 1) CS = 9Bh
        ;; 1) ES/SS/DS/FS/GS = 93h
        ;; 2) LDTR = 00082h
        ;; 3) TR = 00083h
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.CsAccessRight], TYPE_NON_SYS | TYPE_CcRA | SEG_ugdlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.SsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_ugdlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.DsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_ugdlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.EsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_ugdlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.FsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_ugdlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.GsAccessRight], TYPE_NON_SYS | TYPE_ceWA | SEG_ugdlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.LdtrAccessRight], TYPE_SYS | TYPE_LDT | SEG_ugdlP
        mov DWORD [GuestStateBufBase + GUEST_STATE.TrAccessRight], TYPE_SYS | TYPE_BUSY_TSS16 | SEG_ugdlP
                        
        

        ;;
        ;; GDTR �� IDTR
        ;; 1) base = 0
        ;; 2) limit = 0FFFFh
        ;;
        xor eax, eax
        mov edx, 0FFFFh
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.GdtrBase], eax
        REX.Wrxb
        mov [GuestStateBufBase + GUEST_STATE.IdtrBase], eax
        mov [GuestStateBufBase + GUEST_STATE.GdtrLimit], edx
        mov [GuestStateBufBase + GUEST_STATE.IdtrLimit], edx


        ;;
        ;; MSRs ���ã�
        ;; 1) IA32_DEBUGCTL = 0
        ;; 2) IA32_SYSENTER_CS = 0
        ;; 3) IA32_SYSENTER_ESP = 0
        ;; 4) IA32_SYSENTER_EIP = 0
        ;; 5) IA32_PERF_GLOBAL_CTRL = 0
        ;; 6) IA32_PAT = ��ǰֵ
        ;; 7) IA32_EFER = 0
        ;;            
        xor eax, eax
        xor edx, edx
        mov [GuestStateBufBase + GUEST_STATE.SysenterCsMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.SysenterEspMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.SysenterEspMsr + 4], edx
        mov [GuestStateBufBase + GUEST_STATE.SysenterEipMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.SysenterEipMsr + 4], edx        
        mov [GuestStateBufBase + GUEST_STATE.PerfGlobalCtlMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.PerfGlobalCtlMsr + 4], edx   
        mov [GuestStateBufBase + GUEST_STATE.EferMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.EferMsr + 4], edx    
        mov ecx, IA32_PAT
        rdmsr
        mov [GuestStateBufBase + GUEST_STATE.PatMsr], eax
        mov [GuestStateBufBase + GUEST_STATE.PatMsr + 4], edx

       
        ;;
        ;; SMBASE=0
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.SmBase], 0
        
        
        ;;
        ;;==== ���� guest non-register state ��Ϣ ====
        ;;
        ;;
        ;; 1. Activity state = Active
        ;;
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.ActivityState], GUEST_STATE_ACTIVE
        
        ;; 2. Interruptibility state:
        ;; ˵����
        ;;    1) ȫ������Ϊ 0
        ;;    2) ���˵� guest processor ���� SMM ģʽʱ��Block by SMI ������Ϊ 1 ֵ
        ;; ��ˣ�
        ;;    [0]: Blocking by STI: No
        ;;    [1]: Blocking by MOV SS: No
        ;;    [2]: Blocking by SMI: No
        ;;    [3]: Blocking by NMI: No
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.InterruptibilityState], 0
        
        ;;
        ;; 3. Pending debug exceptions = 0
        ;;
        mov DWORD [GuestStateBufBase + GUEST_STATE.PendingDebugException], 0
        mov DWORD [GuestStateBufBase + GUEST_STATE.PendingDebugException + 4], 0
        
        ;;
        ;; 4. VMCS link pointer = FFFFFFFF_FFFFFFFFh
        ;;
        mov eax, 0FFFFFFFFh
        mov [GuestStateBufBase + GUEST_STATE.VmcsLinkPointer], eax
        mov [GuestStateBufBase + GUEST_STATE.VmcsLinkPointer + 4], eax
        
        ;;
        ;; 5. VMX-preemption timer value = 0
        ;;
        mov eax, [esi + VMB.VmxTimerValue]                                      ; �� VMB ���ȡ timer value        
        mov [GuestStateBufBase + GUEST_STATE.VmxPreemptionTimerValue], eax        
        
        ;;
        ;; 6. PDPTEs(Page-Directory-Pointer Table Enties)
        ;; ˵����
        ;;      1) ���� PDPTEs Ϊ 0
        ;;
        xor eax, eax
        xor edx, edx
        mov [GuestStateBufBase + GUEST_STATE.Pdpte0], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte0 + 4], edx        
        mov [GuestStateBufBase + GUEST_STATE.Pdpte1], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte1 + 4], edx
        mov [GuestStateBufBase + GUEST_STATE.Pdpte2], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte2 + 4], edx  
        mov [GuestStateBufBase + GUEST_STATE.Pdpte3], eax
        mov [GuestStateBufBase + GUEST_STATE.Pdpte3 + 4], edx
               
        ;;
        ;; guest interrupt status
        ;;                
        mov WORD [GuestStateBufBase + GUEST_STATE.GuestInterruptStatus], 0
        
        
%undef GuestStateBufBase        

        pop ebx
        pop ecx
        pop edx
        pop ebp
        ret
    
    
        
;----------------------------------------------------------
; init_host_state_area()
; input:
;       esi - VMB pointer
; output:
;       none
; ������
;       1) ���� VMCS �� HOST STAGE ����
;----------------------------------------------------------   
init_host_state_area:
        push ebp
        push edx
        push ebx
        push ecx

%ifdef __X64
        LoadGsBaseToRbp
        LoadFsBaseToRbx
%else
        mov ebp, [gs: PCB.Base]
        mov ebx, [fs: SDA.Base]
%endif        

%define HostStateBufBase                (ebp + PCB.HostStateBuf)


        ;;
        ;; �Ե�ǰֵ�ֱ�д�� CR0, CR3, CR4
        ;;
        REX.Wrxb
        mov eax, cr0
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.Cr0], eax
        REX.Wrxb
        mov eax, cr3
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.Cr3], eax
        REX.Wrxb
        mov eax, cr4
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.Cr4], eax


        ;;
        ;; д�� rsp �� rip
        ;;
        REX.Wrxb
        mov eax, [esi + VMB.HostStack]    
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.Rsp], eax            
        REX.Wrxb
        mov eax, [esi + VMB.HostEntry]
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.Rip], eax        
        

        ;;
        ;; �Ե�ǰֵд�� selector ֵ
        ;;
        mov ax, cs
        mov [HostStateBufBase + HOST_STATE.CsSelector], ax
        mov ax, ss
        mov [HostStateBufBase + HOST_STATE.SsSelector], ax
        mov ax, ds
        mov [HostStateBufBase + HOST_STATE.DsSelector], ax
        mov ax, es
        mov [HostStateBufBase + HOST_STATE.EsSelector], ax
        mov ax, fs
        mov [HostStateBufBase + HOST_STATE.FsSelector], ax
        mov ax, gs
        mov [HostStateBufBase + HOST_STATE.GsSelector], ax
        mov ax, [ebp + PCB.TssSelector]
        mov [HostStateBufBase + HOST_STATE.TrSelector], ax

        ;;
        ;; д�� segment base ֵ
        ;;
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.GsBase], ebp
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.FsBase], ebx
        REX.Wrxb
        mov eax, [ebp + PCB.TssBase]
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.TrBase], eax        
        REX.Wrxb
        mov eax, [ebx + SDA.GdtBase]
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.GdtrBase], eax
        REX.Wrxb
        mov eax, [ebx + SDA.IdtBase]
        REX.Wrxb
        mov [HostStateBufBase + HOST_STATE.IdtrBase], eax

               
        ;;
        ;; �Ե�ǰֵд�� MSR
        ;; 1) IA32_SYSENTER_CS(32λ)
        ;; 2) IA32_SYSENTER_ESP
        ;; 3) IA32_SYSENTER_EIP
        ;; 4) IA32_PERF_GLOBAL_CTRL
        ;; 5) IA32_PAT
        ;; 6) IA32_EFER
        ;; 
        mov ecx, IA32_SYSENTER_CS
        rdmsr
        mov [HostStateBufBase + HOST_STATE.SysenterCsMsr], eax
        mov ecx, IA32_SYSENTER_ESP
        rdmsr
        mov [HostStateBufBase + HOST_STATE.SysenterEspMsr], eax
        mov [HostStateBufBase + HOST_STATE.SysenterEspMsr + 4], edx
        mov ecx, IA32_SYSENTER_EIP
        rdmsr
        mov [HostStateBufBase + HOST_STATE.SysenterEipMsr], eax
        mov [HostStateBufBase + HOST_STATE.SysenterEipMsr + 4], edx        
        mov ecx, IA32_PERF_GLOBAL_CTRL
        rdmsr
        mov [HostStateBufBase + HOST_STATE.PerfGlobalCtlMsr], eax
        mov [HostStateBufBase + HOST_STATE.PerfGlobalCtlMsr + 4], edx        
        mov ecx, IA32_PAT
        rdmsr
        mov [HostStateBufBase + HOST_STATE.PatMsr], eax
        mov [HostStateBufBase + HOST_STATE.PatMsr + 4], edx
        mov ecx, IA32_EFER
        rdmsr
        mov [HostStateBufBase + HOST_STATE.EferMsr], eax
        mov [HostStateBufBase + HOST_STATE.EferMsr + 4], edx        
        
%undef HostStateBufBase        
        pop ecx
        pop ebx
        pop edx
        pop ebp
        ret     




;----------------------------------------------------------
; init_vm_execution_control_fields()
; input:
;       esi - VMCS �����ָ�루VMCS_MANAGE_BLOCK��
; output:
;       none
; ������
;       1) ���� VMCS �� VM-execution ������
;----------------------------------------------------------   
init_vm_execution_control_fields:
        push ebx
        push edx
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

%define ExecutionControlBufBase         (ebp + PCB.ExecutionControlBuf)


        
        ;;
        ;; ���� Pin-based ������:
        ;; 1) [0]  - external-interrupt exiting: Yes
        ;; 2) [3]  - NMI exiting: Yes
        ;; 3) [5]  - Virtual NMIs: No
        ;; 4) [6]  - Activate VMX preemption timer: Yes
        ;; 5) [7]  - process posted interrupts: No
        ;;
        ;; ע�⣺
        ;; 1) ��� VMB.VmxTimerValue = 0 ʱ����ʹ�� VMX-preemption timer
        ;;
        
        mov ebx, EXTERNAL_INTERRUPT_EXITING | NMI_EXITING
        mov eax, EXTERNAL_INTERRUPT_EXITING | NMI_EXITING | ACTIVATE_VMX_PREEMPTION_TIMER        
        
        cmp DWORD [esi + VMB.VmxTimerValue], 0
        cmove eax, ebx
        
        ;;
        ;; ע�⣬PCB.PinBasedCtls ��ֵ�� stage1 �׶�ʱ�Ѹ��£�����ֵΪ��
        ;; 1) �� IA32_VMX_BASIC[55] = 1 ʱ������ IA32_VMX_TRUE_PINBASED_CTLS �Ĵ���
        ;; 2) �� IA32_VMX_BASIC[55] = 0 ʱ������ IA32_VMX_PINBASED_CTLS �Ĵ���
        ;; 
        
        ;;######################################################################################
        ;; PCB.PinBasedCtls ֵ˵����
        ;; 1) [31:0]  - allowed 0-setting λ
        ;;              �� bit Ϊ 1 ʱ��Pin-based VM-execution control λΪ 0�������!
        ;;              �� bit Ϊ 0 ʱ��Pin-based VM-execution control λ��Ϊ 0 ֵ��
        ;;     ���:    �� bit Ϊ 1 ʱ��Pin-based VM-execution control ����Ϊ 1 ֵ!!!    
        ;;              
        ;; 2) [63:32] - allowed 1-setting λ
        ;;              �� bit Ϊ 0 ʱ��Pin-based VM-execution control λΪ 1�������
        ;;              �� bit Ϊ 1 ʱ��Pin-based VM-execution control λ��Ϊ 1 ֵ��
        ;;     ���:    �� bit Ϊ 0 ʱ��Pin-based VM-execution control ����Ϊ 0 ֵ!!!
        ;;
        ;; 3) �� [31:0] ��λΪ 0���� [63:32] ����ӦλͬʱΪ 1 ʱ��
        ;;    ˵�� Pin-based VM-execution control λ��������Ϊ 0 �� 1 ֵ
        ;;
        ;; �������յ� Pin-based VM-execution control ֵ˵����
        ;; 1) �� eax �����û����õ�ֵ�������㷨�������յ�ֵ
        ;; �㷨һ��
        ;; 1) mask1 = (allowed 0-setting) AND (allowed 1-setting)���ó�����Ϊ 1 �� mask ֵ
        ;; 2) eax = (eax) OR (mask1)���� 1 ֵ
        ;; 3) mask0 = (allowed 0-setting) OR (allowed 1-setting)���ó�����Ϊ 0 �� mask ֵ
        ;; 4) eax = (eax) AND (mask0)���� 0 ֵ
        ;; 
        ;; �㷨����
        ;; 1) eax = (eax) OR (allowed 0-setting)
        ;; 2) eax = (eax) AND (allowed 1-setting)
        ;;
        ;; �㷨�����㷨һ�ļ��ʵ�֣����ǵĽ����һ���ģ�
        ;; ������Ϊ��ǰ:
        ;;      1) allowed 0-setting = (allowed 0-setting) AND (allowed 1-setting)
        ;;      2) allowed 1-setting = (allowed 0-setting) OR (allowed 1-setting)
        ;;
        ;;######################################################################################
        
                       
        ;;
        ;; ʹ���㷨�����������յ� Pin-based VM-execution control ֵ
        ;;
        or eax, [ebp + PCB.PinBasedCtls]                                ; OR  allowed 0-setting
        and eax, [ebp + PCB.PinBasedCtls + 4]                           ; AND allowed 1-setting

        ;;
        ;; д�� Pin-based VM-execution control ֵ
        ;;        
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.PinControl], eax

        
        ;;
        ;; ���� Processor-based VM-execution control ��
        ;; [2]  - Interrupt-window exiting: No
        ;; [3]  - Use TSC offsetting: No
        ;; [7]  - HLT exiting: Yes
        ;; [9]  - INVLPG exiting: Yes
        ;; [10] - NWAIT exiting: Yes
        ;; [11] - RDPMC exiting: No
        ;; [12] - RDTSC exiting: No
        ;; [15] - CR3-load exiting: Yes
        ;; [16] - CR3-store exiting: Yes
        ;; [19] - CR8-load exiting: No
        ;; [20] - CR8-store exiting: No
        ;; [21] - Use TPR shadow: Yes
        ;; [22] - NMI-window exiting: No
        ;; [23] - MOV-DR exiting: No
        ;; [24] - Unconditional I/O exiting: Yes
        ;; [25] - Use I/O bitmaps: Yes
        ;; [27] - Monitor trap flag: No
        ;; [28] - Use MSR bitmaps: Yes
        ;; [29] - MONITOR exiting: Yes
        ;; [30] - PAUSE exiting: No
        ;; [31] - Active secondary controls: Yes
        ;;
        mov eax, 0B3218680h
        
        ;;
        ;; ���� Primary Processor-based VM-execution control ֵ
        ;; 1) ԭ��͡�Pin-based VM-execution control ֵ��ͬ!
        ;;   
        or eax, [ebp + PCB.ProcessorBasedCtls]                          ; OR  allowed 0-setting
        and eax, [ebp + PCB.ProcessorBasedCtls + 4]                     ; AND allowed 1-setting
        
        ;;
        ;; д�� Primary Processor-based VM-execution control ֵ
        ;;
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.ProcessorControl1], eax
        
        
        ;;
        ;; ���á�Secondary Processor-based VM-execution control ֵ
        ;; 1) [0]  - Virtualize APIC access: Yes
        ;; 2) [1]  - Enable EPT: No
        ;; 3) [2]  - Descriptor-table exiting: Yes
        ;; 4) [3]  - Enable RDTSCP: Yes
        ;; 5) [4]  - Virtualize x2APIC mode: No
        ;; 6) [5]  - Enable VPID: Yes
        ;; 7) [6]  - WBINVD exiting: Yes
        ;; 8) [7]  - unrestricted guest: �� VMB.GuestFlags ����
        ;; 9) [8]  - APIC-register virtualization: Yes
        ;; 10) [9] - virutal-interrupt delivery: Yes
        ;; 11) [10] - PAUSE-loop exiting: No
        ;; 12) [11] - RDRAND exiting: No
        ;; 13) [12] - Enable INVPCID: Yes
        ;; 14) [13] - Enable VM functions: No
        ;;
        mov edx, 136Dh
        
        ;;
        ;; ���������֮һ��ʹ�� unrestricted guest ����
        ;; 1) GUEST_FLAG_PE = 0
        ;; 2) GUEST_FLAG_PG = 0
        ;; 3) GUEST_FLAG_UNRESTRICTED = 1
        ;;
        ;; "unrestricted guest" = 1 ʱ��"Enable EPT"����Ϊ 1
        ;;
        mov edi, [esi + VMB.GuestFlags]
        
        test edi, GUEST_FLAG_PE
        jz init_vm_execution_control_fields.@0
        test edi, GUEST_FLAG_PG
        jz init_vm_execution_control_fields.@0
        test edi, GUEST_FLAG_UNRESTRICTED
        jnz init_vm_execution_control_fields.@0
        test edi, GUEST_FLAG_EPT
        jz init_vm_execution_control_fields.@01
        
        or edx, ENABLE_EPT
        jmp init_vm_execution_control_fields.@01
        
init_vm_execution_control_fields.@0:
        or edx, UNRESTRICTED_GUEST | ENABLE_EPT


init_vm_execution_control_fields.@01:

        ;;
        ;; ��� "Use TPR shadow" Ϊ 0������λ����Ϊ 0
        ;; 1) "virtualize x2APIC mode"
        ;; 2) "APIC-registers virtualization"
        ;; 3) "virutal-interrupt delivery"
        ;;
        test eax, USE_TPR_SHADOW
        jnz init_vm_execution_control_fields.@02
        
        and edx, ~(VIRTUALIZE_X2APIC_MODE | APIC_REGISTER_VIRTUALIZATION | VIRTUAL_INTERRUPT_DELIVERY)
        
init_vm_execution_control_fields.@02:        
                       
        ;;
        ;; ���� Secondary Processor-Based VM-excution control ����ֵ
        ;; 1) �㷨�� Pin-Based VM-excution control ֵһ��
        ;;
        or edx, [ebp + PCB.ProcessorBasedCtls2]                         ; OR  allowed 0-setting
        and edx, [ebp + PCB.ProcessorBasedCtls2 + 4]                    ; AND allowed 1-setting
        
        ;;
        ;; д�� Secondary Processor-based VM-execution control ֵ
        ;;
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.ProcessorControl2], edx
        
                
        ;;
        ;; ���� Exception Bitmap
        ;; 1) #BP exiting - Yes
        ;; 2) #DE exiting - Yes
        ;; 3) #UD exiting - Yes
        ;; 4) #PF exiting - Yes
        ;; 5) #GP exiting - Yes
        ;; 6) #SS exiting - Yes
        ;; 7) #DF exiting - Yes
        ;; 8) #DB exiting - Yes
        ;; 9) #TS exiting - Yes
        ;; 10) #NP exiting - Yes
        ;;
        mov eax, 7D4Bh
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.ExceptionBitmap], eax
        
        ;;
        ;; ���� #PF �쳣�� PFEC_MASK �� PFEC_MATCH ֵ
        ;; PFEC �� PFEC_MASK��PFEC_MATCH ˵����
        ;; �� PFEC & PFEC_MASK = PFEC_MATCH ʱ��#PF ���� VM exit ����
        ;;      1) �� PFEC_MASK = PFEC_MATCH = 0 ʱ�����е� #PF ������ VM exit
        ;;      2) �� PFEC_MASK = 0���� PFEC_MATCH = FFFFFFFFh ʱ���κ� #PF �����ᵼ�� VM exit
        ;;
        ;; PFEC ˵��:
        ;; 1) [0] - P λ��  Ϊ 0 ʱ��#PF �� not present ����
        ;;                  Ϊ 1 ʱ��#PF ������ voilation ����
        ;; 2) [1] - R/W λ��Ϊ 0 ʱ��#PF �� read access ����
        ;;                  Ϊ 1 ʱ��#PF �� write access ����
        ;; 3) [2] - U/S λ��Ϊ 0 ʱ������ #PF ʱ���������� supervisor Ȩ����
        ;;                  Ϊ 1 ʱ������ #PF ʱ���������� user Ȩ����
        ;; 4) [3] - RSVD λ��Ϊ 0 ʱ��ָʾ����λΪ 0
        ;;                   Ϊ 1 ʱ��ָʾ����λΪ 1
        ;; 5) [4] - I/D λ�� Ϊ 0 ʱ��ִ��ҳ����
        ;;                   Ϊ 1 ʱ��ִ��ҳ���� #PF
        ;; 6) [31:5] - ����λ
        ;;
        
        
       
        ;;
        ;; �����������е� #PF ������ VM exit
        ;; 1) PFEC_MASK  = 0
        ;; 2) PFEC_MATCH = 0
        ;;        
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.PfErrorCodeMask], 0
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.PfErrorCodeMatch], 0
        
        
        
        ;;
        ;; ���� IO bitmap address�������ַ��
        ;;                
        mov eax, [esi + VMB.IoBitmapPhyAddressA]
        mov edx, [esi + VMB.IoBitmapPhyAddressA + 4]
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.IoBitmapAddressA], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.IoBitmapAddressA + 4], edx
        mov eax, [esi + VMB.IoBitmapPhyAddressB]
        mov edx, [esi + VMB.IoBitmapPhyAddressB + 4]
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.IoBitmapAddressB], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.IoBitmapAddressB + 4], edx
                
        ;;
        ;; ���� TSC-offset
        ;;
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.TscOffset], 0
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.TscOffset + 4], 0
        
        
        ;;
        ;; ���� CR0/CR4 �� guest/host mask �� read shadows ֵ
        ;; ˵����
        ;; 1) �� mask ��ӦλΪ 1 ʱ��������λ���� Host ���ã�guest ��Ȩ����
        ;; 2) �� mask ��ӦλΪ 0 ʱ����ʱ��λ guest ��������
        ;;
        
        ;;
        ;; CR0 guest/host mask ���ã������ṩ�� guest flags ����������
        ;; 1) CR0.NE �� host Ȩ��
        ;; 2) �� GUEST_FLAG_PE = 1��CR0.PE ���� host Ȩ�ޣ�����Ϊ guest Ȩ��
        ;; 3) �� GUEST_FLAG_PG = 1��CR0.PG ���� host Ȩ�ޣ�����Ϊ guest Ȩ��
        ;; 5) CR0.CD ���� host Ȩ��
        ;; 6) CR0.NW ���� host Ȩ��
        ;;
        ;; CR0 read shadow ����:
        ;; 1) CR0.PE ���� CR0 guest/host mask �� CR0.PE
        ;; 2) CR0.PG ���� CR0 guest/host mask �� CR0.PG
        ;; 3) CR0.NE = 1
        ;; 4) CR0.CD = 0
        ;; 5) CR0.NW = 0
        ;;       
        mov eax, [esi + VMB.GuestFlags]
        and eax, (GUEST_FLAG_PG | GUEST_FLAG_PE)
        or eax, CR0_NE | CR0_CD | CR0_NW
        mov edx, eax
        and edx, ~(CR0_CD | CR0_NW)                     
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr0GuestHostMask], eax
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr0GuestHostMask + 4], 0FFFFFFFFh
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr0ReadShadow], edx
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr0ReadShadow + 4], 0
        
        ;;
        ;; CR4 guest/host mask �� read shadow ����
        ;; 1)  CR4.VMXE �� CR4.VME ���� host Ȩ��
        ;; 2) �� GUEST_FLAG_PG = 1 ʱ, CR4.PAE ���� host Ȩ�ޣ����� guest Ȩ��
        ;;
        mov eax, 00002021h
        mov edi, 00002020h        
        test DWORD [esi + VMB.GuestFlags], GUEST_FLAG_PG
        jnz init_vm_execution_control_fields.Cr4
        
        mov eax, 00002001h                              ;; guest/host mask[PAE] = 0
        mov edi, 00002000h                              ;; read shadow[PAE] = 0
        
init_vm_execution_control_fields.Cr4:        
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr4GuestHostMask], eax
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr4GuestHostMask + 4], 0FFFFFFFFh
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr4ReadShadow], edi
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.Cr4ReadShadow + 4], 0
        
        
        ;;
        ;; CR3 target control ����
        ;; 1) CR3-target count = 0
        ;; 2) CR3-target value = 0
        ;;
        xor eax, eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3TargetCount], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target0], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target0 + 4], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target1], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target1 + 4], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target2], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target2 + 4], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target3], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Cr3Target3 + 4], eax
                
        ;;
        ;; APIC virtualization ����
        ;; 1) APIC-access address  = 0FEE00000H��Ĭ�ϣ�
        ;; 2) Virtual-APIC address = �����ã������ַ��
        ;; 3) TPR thresold = 10h
        ;; 4) EOI-exit bitmap = 0
        ;; 5) posted-interrupt notification vector = 0
        ;; 6) posted-interrupt descriptor address = 0
        ;;
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.ApicAccessAddress], 0FEE00000H
        mov DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.ApicAccessAddress + 4], 0
        mov eax, [esi + VMB.VirtualApicPhyAddress]
        mov edx, [esi + VMB.VirtualApicPhyAddress + 4]
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.VirtualApicAddress], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.VirtualApicAddress + 4], edx                


        REX.Wrxb
        mov edx, esi
        
        ;;
        ;; ��ʼ�� virtual-APIC page
        ;;
        REX.Wrxb
        mov esi, [edx + VMB.VirtualApicAddress]
        call init_virtual_local_apic
                             
        ;;
        ;;  ### ���� TPR shadow ###
        ;;
        ;; 1) �� "Use TPR shadow" = 0 ʱ��TPR threshold = 0
        ;; 2) �� "Use TPR shadow" = 1 ���� "Virtual-interrupt delivery" = 0 ʱ, TPR threshold = VPTR[7:4]
        ;; 3) ���� TPR threshold = 20h
        ;;       
        xor eax, eax                
        test DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.ProcessorControl1], USE_TPR_SHADOW
        jz init_vm_execution_control_fields.@1
        ;;
        ;; ��ȡ VPTR
        ;;
        REX.Wrxb
        mov eax, [edx + VMB.VirtualApicAddress]
        mov eax, [eax + TPR]
        shr eax, 4
        and eax, 0Fh                                            ; VPTR[7:4]                       

        test DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.ProcessorControl1], ACTIVATE_SECONDARY_CONTROL
        jz init_vm_execution_control_fields.@1
        test DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.ProcessorControl2], VIRTUAL_INTERRUPT_DELIVERY
        jz init_vm_execution_control_fields.@1
        mov eax, 2

init_vm_execution_control_fields.@1:
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.TprThreshold], eax
        
        
        xor eax, eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap0], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap0 + 4], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap1], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap1 + 4], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap2], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap2 + 4], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap3], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EoiBitmap3 + 4], eax                
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.PostedInterruptVector], ax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.PostedInterruptDescriptorAddr], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.PostedInterruptDescriptorAddr + 4], eax  
        
        ;;
        ;; MSR-bitmap address ���ã������ַ��
        ;;
        mov esi, [edx + VMB.MsrBitmapPhyAddress]
        mov edi, [edx + VMB.MsrBitmapPhyAddress + 4]
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.MsrBitmapAddress], esi
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.MsrBitmapAddress + 4], edi

        ;;
        ;; Executive-VMCS pointer
        ;;
        xor eax, eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.ExecutiveVmcsPointer], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.ExecutiveVmcsPointer + 4], eax          
        
        ;;
        ;; ��� "Enable EPT" = 1, �������� EPT
        ;;
        mov BYTE [ebp + PCB.EptEnableFlag], 0
        test DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.ProcessorControl2], ENABLE_EPT
        jz init_vm_execution_control_fields.@2
                
        mov BYTE [ebp + PCB.EptEnableFlag], 1                           ; ���� EptEnableFlag ֵ
        
        REX.Wrxb
        mov esi, [edx + VMB.Ep4taPhysicalBase]
        
%ifndef __X64        
        mov edi, [edx + VMB.Ep4taPhysicalBase + 4]
%endif
        ;;
        ;; ��ʼ�� EPTP �ֶ�
        ;;
        call init_eptp_field
                
init_vm_execution_control_fields.@2:
        xor eax, eax
        ;;
        ;; ���֧�� "enable VPID"�������������� VPID
        ;;
        test DWORD [ExecutionControlBufBase + EXECUTION_CONTROL.ProcessorControl2], ENABLE_VPID
        jz init_vm_execution_control_fields.@3
        
        mov ax, [edx + VMB.Vpid]                                        ; VMCS ��Ӧ�� VPID ֵ
        
init_vm_execution_control_fields.@3:        

        mov [ExecutionControlBufBase + EXECUTION_CONTROL.Vpid], ax      ; д�� VPID ֵ        

        ;;
        ;; PAUSE-loop exiting ����
        ;;
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.PleGap], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.PleWindow], eax  

        ;;
        ;; VM-funciton control
        ;;                
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.VmFunctionControl], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.VmFunctionControl + 4], eax          
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EptpListAddress], eax
        mov [ExecutionControlBufBase + EXECUTION_CONTROL.EptpListAddress + 4], eax          
        
        ;;
        ;; Ϊ�˷��㣬�ָ� esi ֵ
        ;;
        REX.Wrxb
        mov esi, edx
           
%undef ExecutionControlBufBase        
        pop ebp
        pop edx
        pop ebx
        ret



;----------------------------------------------------------
; init_vm_exit_control_fields()
; input:
;     esi - VMB pointer
; ������
;       1) ���� VM-Entry ������  
;---------------------------------------------------------- 
init_vm_exit_control_fields:
        push ebp
        push edx
        
%ifdef __X64        
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

%define ExitControlBufBase              (ebp + PCB.ExitControlBuf)

        ;;
        ;; VM-exit control ����
        ;; 1) [2]  - Save debug controls: Yes
        ;; 2) [9]  - Host address size: No(x86), Yes(x64)
        ;; 3) [12] - load IA32_PREF_GLOBAL_CTRL: Yes
        ;; 4) [15] - acknowledge interrupt on exit: Yes
        ;; 5) [18] - save IA32_PAT: Yes
        ;; 6) [19] - load IA32_PAT: Yes
        ;; 7) [20] - save IA32_EFER: Yes
        ;; 8) [21] - load IA32_EFER: Yes
        ;; 9) [22] - save VMX-preemption timer value: ȡ���ڡ�activity VMX-preemption timer��λ
        ;;
        
        ;;
        ;; Host address size ֵȡ���� host ��ģʽ
        ;; 1) �� x86 �£�Host address size = 0
        ;; 2) �� 64-bit ģʽ�£�VM-exit ���ص� host ������ 64-bit ģʽ��Host address size = 1
        ;;
%ifdef __X64
        mov eax, 3C9004h | HOST_ADDRESS_SPACE_SIZE
%else
        mov eax, 3C9004h
%endif


        ;;
        ;; �����activity VMX-preemption timer��=1ʱ����save VMX-preemption timer value��=1
        ;;
        test DWORD [ebp + PCB.ExecutionControlBuf + EXECUTION_CONTROL.PinControl], ACTIVATE_VMX_PREEMPTION_TIMER
        jz init_vm_exit_control_fields.@0
        
        or eax, SAVE_VMX_PREEMPTION_TIMER_VALUE        

        
init_vm_exit_control_fields.@0:

        
        ;;
        ;;���������յ� VM-exit control ֵ
        ;;
        or eax, [ebp + PCB.ExitCtls]                                    ; OR allowed 0-setting
        and eax, [ebp + PCB.ExitCtls + 4]                               ; AND allowed 1-setting
        mov [ExitControlBufBase + EXIT_CONTROL.VmExitControl], eax      ; д�� Vm-exit control buffer
        
        
        ;;
        ;; VM-exit MSR-store ���ã�������ʱ������ MSR-store 
        ;; 1) MsrStoreCount = 0
        ;; 2) MsrStoreAddress =  ������
        ;;
        mov DWORD [ExitControlBufBase + EXIT_CONTROL.MsrStoreCount], 0
        mov eax, [esi + VMB.VmExitMsrStorePhyAddress]
        mov edx, [esi + VMB.VmExitMsrStorePhyAddress + 4]
        mov [ExitControlBufBase + EXIT_CONTROL.MsrStoreAddress], eax
        mov [ExitControlBufBase + EXIT_CONTROL.MsrStoreAddress + 4], edx


        ;;
        ;; Vm-exit Msr-load ���ã������ݲ����� Msr-store
        ;; 1) MsrLoadCount = 0
        ;; 2) MsrLoadAddress = ������
        ;;
        mov DWORD [ExitControlBufBase + EXIT_CONTROL.MsrLoadCount], 0
        mov eax, [esi + VMB.VmExitMsrLoadPhyAddress]
        mov edx, [esi + VMB.VmExitMsrLoadPhyAddress + 4]
        mov [ExitControlBufBase + EXIT_CONTROL.MsrLoadAddress], eax
        mov [ExitControlBufBase + EXIT_CONTROL.MsrLoadAddress + 4], edx        


%undef ExitControlBufBase

        pop edx
        pop ebp
        ret




;----------------------------------------------------------
; init_vm_entry_control_fields()
; input:
;       esi - VMB pointer
; ������
;       1) ���� VM-Entry ������  
;---------------------------------------------------------- 
init_vm_entry_control_fields:
        push edx
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

%define EntryControlBufBase             (ebp + PCB.EntryControlBuf)


        ;;
        ;; �� legacy ģʽ������ VM-Entry control
        ;; 1) [2]  - load debug controls : Yes
        ;; 2) [9]  - IA-32e mode guest   : No(x86)��Yes(x64)
        ;; 3) [10] - Entry to SMM        : No
        ;; 4) [11] - deactiveate dual-monitor treatment : No
        ;; 5) [13] - load IA32_PERF_GLOBAL_CTRL : Yes
        ;; 6) [14] - load IA32_PAT : Yes
        ;; 7) [15] - load IA32_EFER : Yes
        ;;
        
        ;;
        ;; ����Ƿ���� IA-32e guest
        ;;
        mov edx, 0E004h
        mov eax, 0E004h | IA32E_MODE_GUEST        
        test DWORD [esi + VMB.GuestFlags], GUEST_FLAG_IA32E
        cmovz eax, edx
                
        ;;
        ;; �������յ� VM-entry control ֵ
        ;;
        or eax, [ebp + PCB.EntryCtls]                                   ; OR allowed 0-setting
        and eax, [ebp + PCB.EntryCtls + 4]                              ; AND allowed 1-setting
        mov [EntryControlBufBase + ENTRY_CONTROL.VmEntryControl], eax   ; д�� Vm-entry control buffer
        

        ;;
        ;; VM-entry MSR-load ���ã�������ʱ������
        ;; 1) MsrLoadCount = 0
        ;; 2) VM-entry MsrLoadAddress =  VM-entry MsrStoreAddress
        ;;
        mov DWORD [EntryControlBufBase + ENTRY_CONTROL.MsrLoadCount], 0
        mov eax, [esi + VMB.VmExitMsrStorePhyAddress]
        mov edx, [esi + VMB.VmExitMsrStorePhyAddress + 4]
        mov [EntryControlBufBase + ENTRY_CONTROL.MsrLoadAddress], eax
        mov [EntryControlBufBase + ENTRY_CONTROL.MsrLoadAddress + 4], edx          
        
        
        ;;
        ;; д�� event injection����ʱû�� event injection
        ;; 1) VM-entry interruption-inoformation = 0
        ;; 2) VM-entry exception error code = 0
        ;; 3) VM-entry instruction length = 0
        ;;
        mov DWORD [EntryControlBufBase + ENTRY_CONTROL.InterruptionInfo], 0
        mov DWORD [EntryControlBufBase + ENTRY_CONTROL.ExceptionErrorCode], 0
        mov DWORD [EntryControlBufBase + ENTRY_CONTROL.InstructionLength], 0

%undef EntryControlBufBase        

        pop ebp
        pop edx
        ret



;----------------------------------------------------------
; init_virutal_local_apic()
; input:
;       esi - virtual apic address
; output:
;       none
; ������
;       1) ��ʼ�� virtual local apic
;----------------------------------------------------------
init_virtual_local_apic:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        REX.Wrxb	        
        mov ebx, [ebp + PCB.LapicBase]
        
        mov eax, [ebx + LAPIC_ID]
        mov [esi + LAPIC_ID], eax
        mov eax, [ebx + LAPIC_VER]
        mov [esi + LAPIC_VER], eax
        
        xor eax, eax
        mov DWORD [esi + LAPIC_TPR], 20h                ; VTPR = 20h
        mov [esi + LAPIC_APR], eax
        mov [esi + LAPIC_PPR], eax
        mov [esi + LAPIC_RRD], eax
        mov [esi + LAPIC_LDR], eax
        mov [esi + LAPIC_DFR], eax
        mov eax, [ebx + LAPIC_SVR]
        mov [esi + LAPIC_SVR], eax
        
        ;;
        ;; ���� LVTE Ϊ masked
        ;;
        mov eax, LVT_MASKED
        mov [esi + LAPIC_LVT_CMCI], eax
        mov [esi + LAPIC_LVT_TIMER], eax
        mov [esi + LAPIC_LVT_THERMAL], eax
        mov [esi + LAPIC_LVT_PERFMON], eax
        mov [esi + LAPIC_LVT_LINT0], eax
        mov [esi + LAPIC_LVT_LINT1], eax
        mov [esi + LAPIC_LVT_ERROR], eax

        xor eax, eax        
        mov [esi + LAPIC_TIMER_ICR], eax
        mov [esi + LAPIC_TIMER_CCR], eax
        mov [esi + LAPIC_TIMER_DCR], eax
        
        pop ebx
        pop ebp
        ret



;----------------------------------------------------------
; init_guest_page_table()
; input:
;       esi - VMB pointer
; output:
;       none
; ������
;       1) ��ʼ�� guest ������ҳ��ṹ
;----------------------------------------------------------
init_guest_page_table:
        ret
        
        