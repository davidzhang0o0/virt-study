;*************************************************
;* debug.asm                                     *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************

;*
;* ����Ϊ֧�� debug ���ܶ���ĺ�����
;*

LBR_FORMAT32                    EQU             0
LBR_FORMAT64_LIP                EQU             1
LBR_FORMAT64_EIP                EQU             2
LBR_FORMAT64_MISPRED            EQU             3
PEBS_FORMAT_ENH                 EQU             1

;;
;; ���� debug ��Ԫ״̬��
;;
STATUS_BTS_SUCCESS                      EQU     0
STATUS_BTS_ERROR                        EQU     1
STATUS_BTS_UNAVAILABLE                  EQU     2
STATUS_BTS_NOT_READY                    EQU     4
STATUS_BTINT_NOT_READY                  EQU     8
STATUS_DS_NOT_READY                     EQU     10h



;-------------------------------------------------
; init_debug_store_unit()
; input:
;       none
; output:
;       none
; ������
;       ��ʼ���������� debug store ���ܵ�Ԫ
;-------------------------------------------------
init_debug_store_unit:
        push ebx
        push ecx
        push edx
        
        mov ebx, [gs: PCB.Base]       
        
        ;;
        ;; ������� AMD ƽ̨���˳�
        ;;
        mov eax, [gs: PCB.Vendor]
        cmp eax, VENDOR_AMD
        je init_debug_unit.done
                

        ;;
        ;; ����Ƿ�֧�� 64 λ DS 
        ;;
        mov eax, [gs: PCB.DebugCapabilities]
        test eax, DEBUG_DS64_AVAILABLE
        jnz init_debug_unit.ds64
        
        ;;
        ;; ���� DS �����¼ָ��
        ;;
        xor ecx, ecx
        lea eax, [ebx + PCB.DSManageRecord]                     ; DS �����¼��ַ
init_debug_unit.loop1:        
        mov [ebx + PCB.BtsBasePointer + ecx * 8], eax
        mov DWORD [ebx + PCB.BtsBasePointer + ecx * 8 + 4], 0
        add eax, 4
        inc ecx
        cmp ecx, 12
        jb init_debug_unit.loop1
        
        ;;
        ;; 32 λ��ʽ�� DS Size ֵ
        ;; 1) ÿ�� BTS ��¼Ϊ 12 �ֽ�
        ;; 2) ÿ�� PEBS ��¼Ϊ 40 �ֽ�
        ;;
        mov DWORD [gs: PCB.BtsRecordSize], 12
        mov DWORD [gs: PCB.PebsRecordSize], 40
                
        jmp init_debug_unit.next

        
init_debug_unit.ds64:
        ;;
        ;; 64 λ��ʽ�� DS size ֵ
        ;; 1) ÿ�� BTS ��¼Ϊ 24 �ֽ�
        ;; 2) ��ǿ�� PEBS ��¼Ϊ 176 �ֽ�
        ;; 3) ��ͨ�� PEBS ��¼Ϊ 144 �ֽ�
        ;;
        mov DWORD [gs: PCB.BtsRecordSize], 24
        
        ;;
        ;; ����Ƿ�֧����ǿ�� PEBS ��¼
        ;;
        test eax, DEBUG_PEBS_ENH_AVAILABLE
        mov ecx, 144
        mov edx, 176
        cmovnz ecx, edx
        mov [gs: PCB.PebsRecordSize], ecx
      
        ;;
        ;; ���� DS �����¼ָ��
        ;;         
        xor ecx, ecx
        lea eax, [ebx + PCB.DSManageRecord]                     ; DS �����¼��ַ
init_debug_unit.loop2:        
        mov [ebx + PCB.BtsBasePointer + ecx * 8], eax
        mov DWORD [ebx + PCB.BtsBasePointer + ecx * 8 + 4], 0
        add eax, 8
        inc ecx
        cmp ecx, 12
        jb init_debug_unit.loop2
        
        
init_debug_unit.next:
        ;;
        ;; ���� DS ����
        ;;
        call set_debug_store_area
        
init_debug_unit.done:        
        pop ecx
        pop edx
        pop ebx
        ret


;-------------------------------------------------
; get_bts_buffer_base()
; input:
;       none
; output:
;       �ɹ�ʱ���� Bts buffer����ʧ��ʱ���� 0
; ������
;       �õ� BTS buffer ��ַ���ڿ��� paging ��ʹ�ã�
;-------------------------------------------------
get_bts_buffer_base:
        push ecx
        xor ecx, ecx
        mov eax, [fs: SDA.BtsBufferSize]                ; bts buffer ����
        lock xadd [fs: SDA.BtsPoolBase], eax            ; �õ� bts buffer ��ַ
        cmp eax, [fs: SDA.BtsPoolTop]
        cmovae eax, ecx
        pop ecx
        ret


;-------------------------------------------------
; get_pebs_buffer_base()
; input:
;       none
; output:
;       �ɹ�ʱ���� PEBS buffer����ʧ��ʱ���� 0
; ������
;       �õ� PEBS buffer ��ַ���ڿ��� paging ��ʹ�ã�
;-------------------------------------------------
get_pebs_buffer_base:
        push ecx
        xor ecx, ecx
        mov eax, [fs: SDA.PebsBufferSize]               ; pebs buffer ����
        lock xadd [fs: SDA.PebsPoolBase], eax           ; �õ� pebs buffer ��ַ
        cmp eax, [fs: SDA.PebsPoolTop]
        cmovae eax, ecx
        pop ecx
        ret





;------------------------------------------------------
; enable_bts()
; input:
;       none
; output:
;       0 - succssful, error code - failure
; ����:
;       ���� bts ���ƣ��ɹ��󷵻� 0��ʧ�ܷ��ش�����
;-----------------------------------------------------
enable_bts:
enable_branch_trace_store:
        push ecx
        push edx
        push ebx
        
        mov eax, STATUS_BTS_SUCCESS
        
        ;;
        ;; ����Ƿ��Ѿ�����
        ;; 
        mov ebx, [gs: PCB.DebugStatus]
        test ebx, DEBUG_STATUS_BTS_ENABLE
        jnz enable_branch_trace_store.done
        
        ;;
        ;; ��� BTS �Ƿ����
        ;;
        mov eax, [gs: PCB.DebugCapabilities]
	test eax, DEBUG_BTS_AVAILABLE
        mov eax, STATUS_BTS_UNAVAILABLE
	jz enable_branch_trace_store.done
        
        ;;
        ;; ��� BTS �����Ƿ����ú�
        ;;
        test ebx, DEBUG_STATUS_BTS_READY
        mov eax, STATUS_BTS_NOT_READY
        jz enable_branch_trace_store.done
        
        ;;
        ;; ���� IA32_DEBUGCTL[6].TR �� IA32_DEBUGCTL[7].BTS λ
        ;;
	mov ecx, IA32_DEBUGCTL
	rdmsr
	or eax, 0C0h					; TR=1, BTS=1
	wrmsr
        ;;
        ;; ���� debug ״̬
        ;;
        or ebx, DEBUG_STATUS_BTS_ENABLE
        mov [gs: PCB.DebugStatus], ebx
        mov eax, STATUS_BTS_SUCCESS
        
enable_branch_trace_store.done:	
        pop ebx
        pop edx
        pop ecx
	ret
	

;---------------------------------------------------
; enable_btint()
; input:
;       none
; output:
;       eax - status
; ������
;       ���� BTINT ���ƣ�Ӧ�� enable_bts() ֮�����
; ʾ����
;       call enable_bts                 ; ���� BTS ����
;       ...
;       call enable_btint               ; ���� BTINT
;----------------------------------------------------
enable_btint:
        push ecx
        push edx
        push ebx
        
        mov eax, STATUS_BTS_SUCCESS
        
        ;;
        ;; ��� BTINT �Ƿ��Ѿ�����
        ;; 
        mov ebx, [gs: PCB.DebugStatus]
        test ebx, DEBUG_STATUS_BTINT_ENABLE
        jnz enable_bts_with_int.done
        
        ;;
        ;; ��� BTS �Ƿ�׼����
        ;;
        test ebx, DEBUG_STATUS_BTS_READY
        mov eax, STATUS_BTS_NOT_READY
        jz enable_bts_with_int.done
        
        ;;
        ;; ��� BTINT �����Ƿ�׼����
        ;;
        test ebx, DEBUG_STATUS_BTINT_READY
        jnz enable_bts_with_int.next
        
        ;;
        ;; ���� DS �����¼������: BTS threadold <= BTS maximum
        ;;
        mov eax, [gs: PCB.BtsMaximumPointer]
        mov eax, [eax]
        mov ebx, [gs: PCB.BtsThresholdPointer]
        cmp [ebx], eax                                  ; bts thresold >  bts maximum
        cmovb eax, [ebx]
        mov [ebx], eax        
        
        or DWORD [gs: PCB.DebugStatus], DEBUG_STATUS_BTINT_READY
        
enable_bts_with_int.next:        
        ;;
        ;; ���� IA32_DEBUGCTL[8].BTINT λ
        ;;
	mov ecx, IA32_DEBUGCTL
	rdmsr
	or eax, 0100h                                   ; BTINT = 1
	wrmsr

        ;;
        ;; ���� Debug ״̬
        ;; 
        or DWORD [gs: PCB.DebugStatus], DEBUG_STATUS_BTINT_ENABLE
        
enable_bts_with_int.done:        
        pop ebx
        pop edx
        pop ecx
        ret
	
	
	
;--------------------------------
; disable_bts(): �ر� BTS ����
;--------------------------------
disable_bts:
        push ecx
        push edx
        push ebx
        ;;
        ;; ����Ƿ��ѿ���
        ;;
        mov ebx, [gs: PCB.DebugStatus]
        test ebx, DEBUG_STATUS_BTS_ENABLE
        jz disable_bts.done
        
	mov ecx, IA32_DEBUGCTL
	rdmsr
	and eax, 0FF3Fh                                 ; TR=0, BTS=0
	wrmsr
       
        ;;
        ;; ���� debug ״̬
        ;;
        and ebx, ~DEBUG_STATUS_BTS_ENABLE
        mov [gs: PCB.DebugStatus], ebx
disable_bts.done:        
        pop ebx
        pop edx
        pop ecx
	ret



;--------------------------------
; disable_btint()���ر� BTINT ����
;--------------------------------
disable_btint:
        push ecx
        push edx
        push ebx
        mov ebx, [gs: PCB.DebugStatus]
        test ebx, DEBUG_STATUS_BTINT_ENABLE
        jz disable_btint.done
        
        mov ecx, IA32_DEBUGCTL
        rdmsr
        btr eax, 8                                      ; BTINT = 0
        wrmsr
        
        ;;
        ;; ���� DS �����¼����
        ;;
        mov ebx, [gs: PCB.BtsThresholdPointer]
        mov eax, [gs: PCB.BtsMaximumPointer]
        mov eax, [eax]
        add eax, [gs: PCB.BtsRecordSize]
        cmp [ebx], eax                                  ; bts thresold >  bts maximum
        cmovae eax, [ebx]
        mov [ebx], eax
        
        ;;
        ;; ���� debug ״̬
        ;;
        and DWORD [gs: PCB.DebugStatus], ~DEBUG_STATUS_BTINT_ENABLE
        and DWORD [gs: PCB.DebugStatus], ~DEBUG_STATUS_BTINT_READY
disable_btint.done:
        pop ebx
        pop edx
        pop ecx
        ret



;------------------------
; support_debug_store(): ��ѯ�Ƿ�֧�� DS ����
; output:
;       1-support, 0-no support
;------------------------
support_ds:
support_debug_store:
        push edx
        ;;
        ;; ��� CPUID.01H:EDX[21].Branch_Trace_Store λ
        ;;
        mov edx, [gs: PCB.FeatureEdx]
	bt edx, 21
	setc al
	movzx eax, al
        pop edx
	ret

;---------------------------------------------
; support_ds64: ��ѯ�Ƿ�֧�� DS save 64 λ��ʽ
; output:
;       1-support, 0-no support
;---------------------------------------------
support_ds64:
        push ecx
        ;;
        ;; ��� CPUID.01H.ECX[2].DS64 λ
        ;;
        mov ecx, [gs: PCB.FeatureEcx]
	bt ecx, 2                               ; 64-bit DS AREA
	setc al
	movzx eax, al
        pop ecx
	ret


;-------------------------------------------------
; available_branch_trace_store()
; input:
;       none
; output:
;       1 - available, 0 - unavailable
;-------------------------------------------------
available_bts:
available_branch_trace_store:
        push edx
        push ecx
        ;;
        ;; ��� CPUID.01H:EDX[21].Branch_Trace_Store λ
        ;;
        mov edx, [gs: PCB.FeatureEdx]
        bt edx, 21
	setc al
	jnc available_branch_trace_store.done
        
        ;;
        ;; ��� IA32_MISC_ENABLE[11].BTS_Unavailable λ
        ;;
	mov ecx, IA32_MISC_ENABLE
	rdmsr
	bt eax, 11
	setnc al
available_branch_trace_store.done:	
	movzx eax, al
        pop ecx
        pop edx
	ret


;--------------------------------------
; avaiable_pebs(): �Ƿ�֧�� PEBS ����
; output:
;       1-available, 0-unavailable
;--------------------------------------
available_pebs:
        push edx
        push ecx

        ;;
        ;; ��� CPUID.01H:EDX[21].Branch_Trace_Store λ
        ;;
        mov edx, [gs: PCB.FeatureEdx]
        bt edx, 21
	setc al
	jnc available_pebs.done
        
        ;;
        ;; ��� IA32_MISC_ENABLE[12].PEBS_Unavailable λ
        ;;
	mov ecx, IA32_MISC_ENABLE
	rdmsr
	bt eax, 12
	setnc al
available_pebs.done:
	movzx eax, al
        pop ecx
        pop edx
	ret


;------------------------------------------------------------
; support_enhancement_pebs(): ����Ƿ�֧����ǿ�� PEBS ��¼
; output:
;       1-support, 0-no support
;-----------------------------------------------------------
support_enhancement_pebs:
        ;;
        ;; ��� PerfCapabilities[8] λ
        ;;        
        mov eax, [gs: PCB.PerfCapabilities]
	test eax, PERF_PEBS_ENH_AVAILABLE
	sete al
	movzx eax, al
	ret
        

;----------------------------------------------
; update_debug_capabilities_info()
; input:
;       none
; output:
;       none
; ������
;       ���´����� debug ��صĹ��ܼ�¼
;----------------------------------------------
update_debug_capabilities_info:
        push ebx
        mov ebx, [gs: PCB.DebugCapabilities]
        call available_bts
        test eax, eax
        jz update_debug_capabilities_info.@1
        or ebx, DEBUG_BTS_AVAILABLE
        
update_debug_capabilities_info.@1:        
        call support_ds64
        test eax, eax
        jz update_debug_capabilities_info.@2
        or ebx, DEBUG_DS64_AVAILABLE
        
update_debug_capabilities_info.@2:                
        call available_pebs
        test eax, eax
        jz update_debug_capabilities_info.@3
        or ebx, DEBUG_PEBS_AVAILABLE
        
update_debug_capabilities_info.@3:        
        call support_enhancement_pebs
        test eax, eax
        jz update_debug_capabilities_info.@4
        or ebx, DEBUG_PEBS_ENH_AVAILABLE

update_debug_capabilities_info.@4:        
        ;;
        ;; ������޵� BTS, CPUID.01H:ECX[4].DS_CPL λ
        ;;
        mov eax, [gs: PCB.FeatureEcx]
        bt eax, 4
        jnc update_debug_capabilities_info.done
        or ebx, DEBUG_DS_CPL_AVAILABLE
        
update_debug_capabilities_info.done:        
        mov [gs: PCB.DebugCapabilities], ebx
        pop ebx
        ret



;----------------------------------------------
; get_lbr_format()
; input:
;       none
; output:
;       eax - lbr format
;----------------------------------------------
get_lbr_format:
        mov eax, [gs: PCB.PerfCapabilities]
        and eax, 3Fh
        ret



;-------------------------------------------
; set_debug_store_area(): ���� DS �������ַ
; input:
;       none
; output:
;       status code
;-------------------------------------------
set_debug_store_area:
        push ecx
        push edx
        
        ;;
        ;; ���� IA32_DS_AERA �Ĵ���
        ;;
	mov ecx, IA32_DS_AREA
        mov eax, [gs: PCB.Base]
        add eax, PCB.DSManageRecord                     ; DS �����¼��ַ
	xor edx, edx
	wrmsr
        
        ;;
        ;; ���� debug ״̬
        ;;
        or DWORD [gs: PCB.DebugStatus], DEBUG_STATUS_DS_READY
        
        ;;
        ;; ���� DS �����¼
        ;;
        call set_ds_management_record
        pop edx
        pop ecx
	ret


;----------------------------------------------------------------
; set_ds_management_record() ���ù�������¼
; input:
;       none
; output:
;       status code
; ����:
;       ȱʡ����£�����Ϊ���λ�· buffer ��ʽ��
;       threshold ֵ���� maximum��������� DS buffer ����ж�
;--------------------------------------------------------------------
set_ds_management_record:
	push ebx
        push ecx
        push edx
             
        ;;
        ;; ��ʼ debug ״̬
        ;;
        mov edx, [gs: PCB.DebugStatus]
        and edx, ~(DEBUG_STATUS_BTS_READY | DEBUG_STATUS_PEBS_READY)
        mov [gs: PCB.DebugStatus], edx
        
        ;;
        ;; ����һ�� BTS buffer������ BTS buffer Base ֵ
        ;;
        call get_bts_buffer_base
        mov esi, eax
        test eax, eax
        mov eax, STATUS_NO_RESOURCE
        jz set_ds_management_record.done                                ; ���� BTS buffer ʧ��

        ;;
        ;; ���� bts �����¼����ʼ״̬�£�
        ;; 1) BTS base = BTS buffer
        ;; 2) BTS index = BTS buffer
        ;; 3) BTS maximum = BTS record size * maximum
        ;; 4) BTS threshold = BTS maximum + BTS record size���� BtsMaximum ��һ����¼��
        ;;
        mov ebx, [gs: PCB.BtsBasePointer]
        mov [ebx], esi
        mov ebx, [gs: PCB.BtsIndexPointer]
        mov [ebx], esi
        mov eax, [gs: PCB.BtsRecordSize]
        imul eax, [fs: SDA.BtsRecordMaximum]
        add eax, [ebx]
        mov ebx, [gs: PCB.BtsMaximumPointer]
        mov [ebx], eax
        add eax, [gs: PCB.BtsRecordSize]                                ; Bts threshold ֵ = Bts maximum + 1
        mov ebx, [gs: PCB.BtsThresholdPointer]
        mov [ebx], eax
      
        ;;
        ;; ���� pebs �����¼����ʼ״̬�£�
        ;; 1) PEBS base = PEBS buffer
        ;; 2) PEBS index = PEBS buffer
        ;; 3) PEBS maximum = PEBS record size * maximum
        ;; 4) PEBS threshold = PEBS maximum
        ;;
        call get_pebs_buffer_base
        mov ebx, [gs: PCB.PebsBasePointer]
        mov [ebx], eax
        mov ebx, [gs: PCB.PebsIndexPointer]
        mov [ebx], eax
        mov eax, [gs: PCB.PebsRecordSize]
        imul eax, [fs: SDA.PebsRecordMaximum]
        add eax, [ebx]
        mov ebx, [gs: PCB.PebsMaximumPointer]
        mov [ebx], eax
        mov ebx, [gs: PCB.PebsThresholdPointer]
        mov [ebx], eax        

        ;;
        ;; ���� debug ״̬
        ;;
        test edx, DEBUG_STATUS_DS_READY
        mov eax, STATUS_DS_NOT_READY
        jz set_ds_management_record.done
        
        or edx, DEBUG_STATUS_BTS_READY | DEBUG_STATUS_PEBS_READY
        and edx, ~DEBUG_STATUS_BTINT_READY
        mov [gs: PCB.DebugStatus], edx
        
set_ds_management_record.done:	
        ;;
        ;; �� PEBS buffer ���ָʾλ OvfBuffer
        ;;
        RESET_PEBS_BUFFER_OVERFLOW
        
        pop ebx
        pop edx
        pop ecx
	ret





;--------------------------------------------------------------
; check_bts_buffer_overflow(): ����Ƿ��� BTS buffer ���
; input:
;       none
; output:
;       1 - yes, 0 - no
;--------------------------------------------------------------
test_bts_buffer_overflow:
check_bts_buffer_overflow:
        mov eax, [gs: PCB.BtsIndexPointer]
        mov eax, [eax]                          ; �� BTS index ֵ
        mov esi, [gs: PCB.BtsThresholdPointer]
        cmp eax, [esi]                          ; �Ƚ� index >= threshold ?
        setae al
        movzx eax, al
        ret


;-----------------------------------------
; set_bts_buffer_size(): ���� BTS buffer ��¼��
; input:
;       esi - BTS buffer ���ɵļ�¼��
;-----------------------------------------
set_bts_buffer_size:
        push ecx
        push edx

        mov ecx, [gs: PCB.BtsRecordSize]
        
        ;;
        ;; ���� bts maximum ֵ
        ;;                
        imul esi, ecx                           ; count * sizeof(bts_record)
        mov edx, [gs: PCB.BtsMaximumPointer]
        mov ebx, [gs: PCB.BtsBasePointer]
        mov eax, [ebx]                          ; ��ȡ BTS base ֵ
        add esi, eax                            ; base + buffer size
        mov [edx], esi                          ; ���� bts maximum ֵ

        ;;
        ;; ��� bts index ֵ
        ;;
        mov edi, [gs: PCB.BtsIndexPointer]
        mov eax, [edi]
        cmp eax, esi                          ; ��� index > maximum 
        cmovae eax, [ebx]
        mov [edi], eax
        
        ;;
        ;; ���� bts threshold ֵ
        ;;
        add esi, ecx
        mov eax, [gs: PCB.DebugStatus]
        test eax, DEBUG_STATUS_BTINT_ENABLE
        mov edi, [gs: PCB.BtsThresholdPointer]
        cmovnz esi, [edx]
        mov [edi], esi

        pop edx
        pop ecx
        ret




;--------------------------------------------------
; set_pebs_buffer_size(): ���� PEBS buffer ��������
; input:
;       esi - PEBS buffer ���ɵļ�¼��
;---------------------------------------------------
set_pebs_buffer_size:
        push ecx
        mov ecx, [gs: PCB.PebsRecordSize]
        imul esi, ecx
        mov eax, [gs: PCB.PebsBasePointer]
        add esi, [eax]
        mov ecx, [eax]
        mov eax, [gs: PCB.PebsMaximumPointer]
        mov [eax], esi
        mov eax, [gs: PCB.PebsThresholdPointer]
        mov [eax], esi
        mov eax, [gs: PCB.PebsIndexPointer]
        cmp [eax], esi
        cmovb ecx, [eax]
        mov [eax], ecx
        pop ecx
        ret


;----------------------------------------------
; reset_bts_index(): ���� BTS index Ϊ base ֵ
; input:
;       none
; output:
;       none
;----------------------------------------------
reset_bts_index:
        mov edi, [gs: PCB.BtsIndexPointer]
        mov esi, [gs: PCB.BtsBasePointer]
        mov esi, [esi]                                  ; ��ȡ BTS base ֵ
        mov [edi], esi                                  ; BTS index = BTS base
        ret


;----------------------------------------------
; reset_pebs_index()������ PEBS index ֵΪ base
; input:
;       none
; output:
;       none
;----------------------------------------------
reset_pebs_index:
        mov edi, [gs: PCB.PebsIndexPointer]       
        mov esi, [gs: PCB.PebsBasePointer]
        mov esi, [esi]                                  ; ��ȡ PEBS base ֵ
        mov [edi], esi                                  ; PEBS index = PEBS base
        mov [gs: PCB.PebsBufferIndex], esi              ; ���±���� PEBS index ֵ
        ret


;------------------------------------------------------------
; update_pebs_index_track(): ����PEBS index �Ĺ켣
; input:
;       none
; output:
;       none
; ������
;       ���� [gs: PCB.PebsBufferIndex]������ֵ�����ּ�� PEBS �ж�
;       [gs: PCB.PebsBufferIndex] ��¼�š���ǰ���� PEBS index ֵ
;------------------------------------------------------------
update_pebs_index_track:
        mov eax, [gs: PCB.PebsIndexPointer]
        mov eax, [eax]                                  ; ����ǰ pebs index ֵ
        mov [gs: PCB.PebsBufferIndex], eax              ; ���±���� pebs index ֵ        
        ret


;------------------------------------------
; get_bts_base(): ��ȡ BTS buffer base ֵ
; output:
;       eax - BTS base
;-------------------------------------------
get_bts_base:
	mov eax, [gs: PCB.BtsBasePointer]
	mov eax, [eax]
	ret


;------------------------------------------
; get_bts_index(): ��ȡ BTS buffer index ֵ
; output:
;       eax - BTS index
;-------------------------------------------
get_bts_index:
	mov eax, [gs: PCB.BtsIndexPointer]
	mov eax, [eax]
	ret

;------------------------------------------
; get_bts_maximum(): ��ȡ BTS buffer maximum ֵ
; output:
;       eax - BTS maximum
;-------------------------------------------
get_bts_maximum:
	mov eax, [gs: PCB.BtsMaximumPointer]
	mov eax, [eax]
	ret

;----------------------------------------------------
; get_bts_threshold(): ��ȡ BTS buffer thresholdֵ
; output:
;       eax - BTS threshold
;----------------------------------------------------
get_bts_threshold:
	mov eax, [gs: PCB.BtsThresholdPointer]
	mov eax, [eax]
	ret


;-------------------------------------------
; set_bts_index(): ���� BTS index ֵ
; input:
;       esi - BTS index
;-------------------------------------------
set_bts_index:
	mov eax, [gs: PCB.BtsIndexPointer]
	mov [eax], esi
	ret


;---------------------------------------------------------
; get_last_pebs_record_pointer()
; output:
;       eax - PEBS ��¼�ĵ�ֵַ������ 0 ʱ��ʾ�� PEBS ��¼
;----------------------------------------------------------
get_last_pebs_record_pointer:
        mov eax, [gs: PCB.PebsIndexPointer]
        mov esi, [eax]
        mov eax, [gs: PCB.PebsBasePointer]
        cmp esi, [eax]                          ; index > base ?
        seta al
        movzx eax, al
        jbe get_last_pebs_record_pointer.done
        sub esi, [gs: PCB.PebsRecordSize]
        mov eax, esi
get_last_pebs_record_pointer.done:
        ret

