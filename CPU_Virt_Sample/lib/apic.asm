;*************************************************
;* apic.asm                                      *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


%include "..\inc\apic.inc"


LAPIC_BASE64                    EQU     0FFFFF800FEE00000h      
IAPIC_BASE64                    EQU     0FFFFF800FEC00000h





;-----------------------------------------------------
; support_apic()������Ƿ�֧�� APIC on Chip�� local APIC
;----------------------------------------------------
support_apic:
        push edx
        mov edx, [gs: PCB.FeatureEdx]
	bt edx, 9				; ��� CPUID.01H:EDX[9] λ 
	setc al
	movzx eax, al
        pop edx
	ret


;--------------------------------------------
; support_x2apic(): �����Ƿ�֧�� x2apic
;--------------------------------------------
support_x2apic:
        push ecx
        mov ecx, [gs: PCB.FeatureEcx]
	bt ecx, 21
	setc al					; ��� CPUID.01H:ECX[21] λ
	movzx eax, al
        pop ecx
	ret	


;-------------------------------------
; enable_apic(): ���� apic
; input:
;       none
;------------------------------------
enable_apic:
        ;;
        ;; ����Ƿ��Ѿ������� local apic
        ;;
        movzx eax, BYTE [gs: PCB.IsLapicEnable]
        test eax, eax
        jnz enable_apic.done
        
        ;;
        ;; ����Ƿ��� paging��û������ apic ʹ�������ַ
        ;; 
        mov eax, [gs: PCB.ProcessorStatus]
        test eax, CPU_STATUS_PG
        mov esi, [gs: PCB.LapicBase]
        cmovz esi, [gs: PCB.LapicPhysicalBase]
        
        ;;
        ;; ���� local apic
        ;;
        mov eax, [esi + SVR]
        bt eax, 8
        mov [esi + SVR], eax
        mov eax, 1
        ;;
        ;; ���� PCB.IsLapicEnable ֵ
        ;;
        mov [gs: PCB.IsLapicEnable], al
enable_apic.done:        
        ret


;-------------------------------------
; disable_apic(): �ر� apic
; input:
;       none
;------------------------------------
disable_apic:
        movzx eax, BYTE [gs: PCB.IsLapicEnable]
        test eax, eax
        jz disable_apic.done
        
        ;;
        ;; ����Ƿ��� paging��û������ apic ʹ�������ַ
        ;; 
        mov eax, [gs: PCB.ProcessorStatus]
        test eax, CPU_STATUS_PG
        mov esi, [gs: PCB.LapicBase]
        cmovz esi, [gs: PCB.LapicPhysicalBase]
                
        ;;
        ;; �ر� apic
        ;;
        mov eax, [esi + SVR]
	btr eax, 8		                ; SVR.enable = 0
        mov [esi + SVR], eax
        ;;
        ;; ���� apic
        ;;
        mov BYTE [gs: PCB.IsLapicEnable], 0
disable_apic.done:        
        ret





;-------------------------------
; enable_x2apic():
;------------------------------
enable_x2apic:
	mov ecx, IA32_APIC_BASE
	rdmsr
	or eax, 0xc00						; bit 10, bit 11 ��λ
	wrmsr
	ret
	
;-------------------------------
; disable_x2apic():
;-------------------------------
disable_x2apic:
	mov ecx, IA32_APIC_BASE
	rdmsr
	and eax, 0xfffff3ff					; bit 10, bit 11 ��λ
	wrmsr
	ret	


;------------------------------
; reset_apic(): ��� local apic
;------------------------------
reset_apic:
	mov ecx, IA32_APIC_BASE
	rdmsr
	btr eax, 11							; clear xAPIC enable flag
	wrmsr
	ret

;---------------------------------
; set_apic(): ���� apic
;---------------------------------
set_apic:
	mov ecx, IA32_APIC_BASE
	rdmsr
	bts eax, 11							; enable = 1
	wrmsr
	ret
	
	
;------------------------------------------------
; set_apic_physical_base()
; input:
;       esi: �� 32 λ�� edi: �߰벿��
; output:
;       none
; ������
;       ���� apic �������ַ���� MAXPHYADDR ֵ�ڣ�
;------------------------------------------------
set_apic_physical_base:
        push edx
        push ecx
        ;;
        ;; ȷ����ַ�ڴ�����֧�ֵ� MAXPHYADDR ��Χ��
        ;;
        and esi, [gs: PCB.MaxPhyAddrSelectMask]
        and edi, [gs: PCB.MaxPhyAddrSelectMask + 4]
	mov ecx, IA32_APIC_BASE
	rdmsr
        and esi, 0FFFFF000h                                             ; ȥ���� 12 λ
        and eax, 0FFFh                                                  ; ����ԭ���� IA32_APIC_BASE �Ĵ����� 12 λ
        or eax, esi
	mov edx, edi
	wrmsr
        ;;
        ;; ���� apic ��Ϣ
        mov [gs: PCB.LapicPhysicalBase], eax
        mov [gs: PCB.LapicPhysicalBase + 4], edx
        pop ecx
        pop edx
	ret

;-----------------------------------------------------
; get_apic_physical_base()
; input:
;       none
; output:
;       edx:eax - 64 λ��ֵַ
; ����:
;       �õ� apic �������ַ
;----------------------------------------------------
get_apic_physical_base:
        mov eax, [gs: PCB.LapicPhysicalBase]
        mov edx, [gs: PCB.LapicPhysicalBase + 4]
	ret



;----------------------------------------------------
; get_logical_processor_count()
; input:
;       none
; output:
;       eax - ����߼���������
; ������
;       ��� package�����������е��߼� processor ����
;----------------------------------------------------
get_logical_processor_count:
        mov eax, [gs: PCB.MaxLogicalProcessor]
	ret



get_processor_core_count:
	mov eax, 4					; main-leaf
	mov ecx, 0					; sub-leaf
	cpuid
	shr eax, 26
	inc eax						; EAX[31:26] + 1
	ret
		

;---------------------------------------------------
; get_apic_initial_id() 
; input:
;       none
; output:
;       eax - inital apic id
; ������
;       �õ� initial apic id
;---------------------------------------------------
get_apic_id:
        mov eax, [gs: PCB.InitialApicId]
	ret


;---------------------------------------
; get_x2apic_id()
; output:
;       eax - 32 λ�� apic id ֵ
;---------------------------------------
get_x2apic_id:
        push edx
	mov eax, 0Bh                    ; ʹ�� 0B leaf
	cpuid
	mov eax, edx			; ���� x2APIC ID
        pop edx
	ret     
        
        

;-----------------------------------------------------------------
; update_processor_topology_info()
; input:
;       none
; output:
;       none
; ������
;       ö�� CPUID 0B leaf�����õ�������������Ϣ������ PCB �ڵ����˼�¼
;-------------------------------------------------------------------
update_processor_topology_info:
        push ecx
        push edx
        push ebx
        push ebp
        
        ;;
        ;; ����Ƿ�֧�� CUPID OB leaf
        ;;
        mov eax, [gs: PCB.MaxBasicLeaf]
        xor edx, edx
        cmp eax, 0Bh
        jb update_processor_topology_info.done

        ;;
        ;; ����Ƿ��� paging��û������ PCB ʹ�������ַ
        ;;
        mov eax, [gs: PCB.ProcessorStatus]
        test eax, CPU_STATUS_PG
        mov ebp, [gs: PCB.Base] 
        cmovz ebp, [gs: PCB.PhysicalBase]
        add ebp, PCB.ProcessorTopology

        xor edi, edi                                            ; edi = -1
        dec edi
                        
        ;;
        ;; ��ʼö�٣�EAX = 0Bh, ECX = 0
        ;; Ȼ��ÿ�ε��� ECX ֵ����ִ�� CPUID.0BH leaf
        ;;
        xor esi, esi                                            ; ��ʼ�� sub-leaf Ϊ 0
        
update_processor_topology_info.loop:	
	mov ecx, esi
	mov eax, 0Bh
	cpuid
	inc esi                                                 ; ���� sub-leaf       
                
        ;;
        ;; ִ�� CPUID.0BH/ECX ʱ������ ECX[15:8] Ϊ level type
        ;;
        ;; 1) ���� ECX = 0 ʱ�����أ�ECX[7:0] = 0, ECX[15:8] = 1
        ;; 2) ���� ECX = 1 ʱ�����أ�ECX[7:0] = 1, ECX[15:8] = 2
        ;; 3) ���� ECX = 2 ʱ�����أ�ECX[7:0] = 2��ECX[15:8] = 0
        ;;        
	shr ecx, 8
        and ecx, 0FFh
        jz update_processor_topology_info.next                  ; ��� level = 0��ֹͣö��
        
        ;;
        ;; EAX[4:0] ���� level �� mask width ֵ
        ;;
        and eax, 01Fh                                           ; mask width
        
        ;;
        ;; ���� level type �����д���:
        ;; 1) ECX[15:8] = 1 ʱ������ thread level
        ;; 2) ECX[15:8] = 2 ʱ������ core level
        ;; 
        cmp ecx, LEVEL_THREAD
        je @@1
        cmp ecx, LEVEL_CORE
        jne update_processor_topology_info.loop
        
        ;;
        ;; ���� core level
        ;; ע�⣺
        ;; 1) CoreMaskWidth ֵ������ ThreadMaskWidth ����
        ;; 2) CoreSelectMask ֵ������ ThreadSelectMask ����
        ;; 3) APIC ID ʣ������Ϊ PackageId����ˣ�PackageId = APIC ID >> CoreMaskWidth
        ;;��
        mov [ebp + TopologyInfo.CoreMaskWidth], al
        mov ecx, eax
        mov eax, edx
        shr eax, cl                                             ; PackageId = APIC ID >> CoreMaskWidth
        mov [ebp + TopologyInfo.PackageId], eax                 ; ���� PackageId ֵ
        xor eax, eax
        shld eax, edi, cl                                       ; ��ʼ CoreSelectMask = -1 << CoreMaskWidth
        sub eax, [ebp + TopologyInfo.ThreadSelectMask]          ; CoreSelectMask = ��ʼ CoreSelectMask - ThreadSelectMask
        mov [ebp + TopologyInfo.CoreSelectMask], eax            ; ���� CoreSelectMask ֵ
        and eax, edx                                            ; ��ʼ CoreId = CoreSelectMask & APIC ID
        mov cl, BYTE [ebp + TopologyInfo.ThreadMaskWidth]
        shr eax, cl                                             ; CoreId = ��ʼ CoreId >> ThreadMaskWidth
        mov [ebp + TopologyInfo.CoreId], al                     ; ���� CoreId ֵ
        sub [ebp + TopologyInfo.CoreMaskWidth], cl              ; ���� CoreMaskWidth ֵ
        
        ;;
        ;; ��� logical processor ����:
        ;; 1) ������ Core Level��ECX[15:8] = 2��ʱ��EBX[15:0] ���ش��������� package ���е� logical processor ����
        ;;
        and ebx, 0FFFFh
        mov [ebp + TopologyInfo.LogicalProcessorPerPackage], ebx
        
        jmp update_processor_topology_info.loop
        
@@1:
        ;;
        ;; ���� thread level
        ;;
        mov [ebp + TopologyInfo.ThreadMaskWidth], al            ; ���� TheadMaskWidth ֵ
        mov ecx, eax
        xor eax, eax
        shld eax, edi, cl                                       ; ThreadSelectMask = -1 << ThreadMaskWidth
        mov [ebp + TopologyInfo.ThreadSelectMask], eax          ; ���� ThreadSelectMask ֵ
        and eax, edx                                            ; ThreadId = APIC ID & ThreadSelectMask
        mov [ebp + TopologyInfo.ThreadId], al                   ; ���� TheadId ֵ
        
        ;;
        ;; ��� logical processor ����:
        ;; 1) ������ Thread Level��ECX[15:8] = 1��ʱ��EBX[15:0] ���� core ���е� logical processor ����
        ;;
        and ebx, 0FFFFh
        mov [ebp + TopologyInfo.LogicalProcessorPerCore], ebx   ; ���� logical Processor per core ֵ
        
        jmp update_processor_topology_info.loop
        
        
update_processor_topology_info.next:
        ;;
        ;; ����ʣ����Ϣ��
        ;; 1) 32 λ Processor ID ֵ
        ;; 2) ������ logical processor �� core ����ֵ
        ;;
        mov [ebp + TopologyInfo.ProcessorId], edx               ; ���� ProcessorId��32 λ����չ APIC ID ֵ��
        ;;
        ;; ������ logical processor �� core �����ļ��㷽����
        ;; 1) LogicalProcessorCount = LogicalProcessorPerPackage
        ;; 2) ProcessorCoreCount = LogicalProcessorPerPackage / LogicalProcessorPerCore
        ;;
        mov eax, [ebp + TopologyInfo.LogicalProcessorPerPackage]
        mov [gs: PCB.LogicalProcessorCount], eax
        xor edx, edx
        mov ecx, [ebp + TopologyInfo.LogicalProcessorPerCore]
        ;div ecx
        mov [gs: PCB.ProcessorCoreCount], eax

update_processor_topology_info.done:        
        pop ebp
        pop ebx
        pop edx
        pop ecx
	ret

	
	
;-----------------------------------------------------
; send_eoi_command()
; input:
;       none
; output:
;       none
; ������
;       1) ���� EOI ����� local apic
;-----------------------------------------------------
send_eoi_command:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 

        REX.Wrxb
        mov ebp, [ebp + PCB.LapicBase]
        mov DWORD [ebp + EOI], 0
        pop ebp
        ret

	
	
	
	
%if 0


;-----------------------------------------------------
; get_mask_width(): �õ� mask width��ʹ���� xAPIC ID��
; input:
;       esi - maximum count��SMT �� core ����� count ֵ��
; output:
;       eax - mask width
;-------------------------------------------------------
get_mask_width:
	xor eax, eax			; ��Ŀ��Ĵ���������MSB��Ϊ1ʱ
	bsr eax, esi			; ���� count �е� MSB λ
	ret
	
	
;------------------------------------------------------------------
; extrac_xapic_id(): �� 8 λ�� xAPIC ID ����ȡ package, core, smt ֵ
;-------------------------------------------------------------------	
extrac_xapic_id:
	jmp do_extrac_xapic_id
current_apic_id		dd	0	
do_extrac_xapic_id:	
	push ecx
	push edx
	push ebx

	call get_apic_id						; �õ� xAPIC ID ֵ
	mov [current_apic_id], eax				; ���� xAPIC ID

;; ���� SMT_MASK_WIDTH �� SMT_SELECT_MASK	
	call get_logical_processor_count		; �õ� logical processor ������ֵ
	mov esi, eax
	call get_mask_width						; �õ� SMT_MASK_WIDTH
	mov edx, [current_apic_id]
	mov [xapic_smt_mask_width + edx * 4], eax
	mov ecx, eax
	mov ebx, 0xFFFFFFFF
	shl ebx, cl								; �õ� SMT_SELECT_MASK
	not ebx
	mov [xapic_smt_select_mask + edx * 4], ebx
	
;; ���� CORE_MASK_WIDTH �� CORE_SELECT_MASK 
	call get_processor_core_count
	mov esi, eax
	call get_mask_width						; �õ� CORE_MASK_WIDTH
	mov edx, [current_apic_id]	
	mov [xapic_core_mask_width + edx * 4], eax
	mov ecx, [xapic_smt_mask_width + edx * 4]
	add ecx, eax							; CORE_MASK_WIDTH + SMT_MASK_WIDTH
	mov eax, 32
	sub eax, ecx
	mov [xapic_package_mask_width + edx * 4], eax		; ���� PACKAGE_MASK_WIDTH
	mov ebx, 0xFFFFFFFF
	shl ebx, cl
	mov [xapic_package_select_mask + edx * 4], ebx		; ���� PACKAGE_SELECT_MASK
	not ebx									; ~(-1 << (CORE_MASK_WIDTH + SMT_MASK_WIDTH))
	mov eax, [xapic_smt_select_mask + edx * 4]
	xor ebx, eax							; ~(-1 << (CORE_MASK_WIDTH + SMT_MASK_WIDTH)) ^ SMT_SELECT_MASK
	mov [xapic_core_select_mask + edx * 4], ebx
	
;; ��ȡ SMT_ID, CORE_ID, PACKAGE_ID
	mov ebx, edx							; apic id
	mov eax, [xapic_smt_select_mask]
	and eax, edx							; APIC_ID & SMT_SELECT_MASK
	mov [xapic_smt_id + edx * 4], eax
	mov eax, [xapic_core_select_mask]
	and eax, edx							; APIC_ID & CORE_SELECT_MASK
	mov cl, [xapic_smt_mask_width]
	shr eax, cl								; APIC_ID & CORE_SELECT_MASK >> SMT_MASK_WIDTH
	mov [xapic_core_id + edx * 4], eax
	mov eax, [xapic_package_select_mask]
	and eax, edx							; APIC_ID & PACKAGE_SELECT_MASK
	mov cl, [xapic_package_mask_width]
	shr eax, cl
	mov [xapic_package_id + edx * 4], eax

	pop ebx
	pop edx
	pop ecx
	ret
	
		
;-------------------------------------------------------------
; extrac_x2apic_id(): �� x2APIC_ID ����ȡ package, core, smt ֵ
;-------------------------------------------------------------
extrac_x2apic_id:
	push ecx
	push edx
	push ebx

; �����Ƿ�֧�� leaf 11
	mov eax, 0
	cpuid
	cmp eax, 11
	jb extrac_x2apic_id_done
	
	xor esi, esi
	
do_extrac_loop:	
	mov ecx, esi
	mov eax, 11
	cpuid	
	mov [x2apic_id + edx * 4], edx				; ���� x2apic id
	shr ecx, 8
	and ecx, 0xff								; level ����
	jz do_extrac_subid
	
	cmp ecx, 1									; SMT level
	je extrac_smt
	cmp ecx, 2									; core level
	jne do_extrac_loop_next

;; ���� core mask	
	and eax, 0x1f
	mov [x2apic_core_mask_width + edx * 4], eax	; ���� CORE_MASK_WIDTH
	mov ebx, 32
	sub ebx, eax
	mov [x2apic_package_mask_width + edx * 4], ebx	; ���� package_mask_width
	mov cl, al
	mov ebx, 0xFFFFFFFF							;
	shl ebx, cl									; -1 << CORE_MASK_WIDTH
	mov [x2apic_package_select_mask + edx * 4], ebx		; ���� package_select_mask
	not ebx										; ~(-1 << CORE_MASK_WIDTH)
	xor ebx, [x2apic_smt_select_mask + edx * 4]					; ~(-1 << CORE_MASK_WIDTH) ^ SMT_SELECT_MASK
	mov [x2apic_core_select_mask + edx * 4], ebx					; ���� CORE_SELECT_MASK
	jmp do_extrac_loop_next

;; ���� smt mask	
extrac_smt:
	and eax, 0x1f
	mov [x2apic_smt_mask_width + edx * 4], eax					; ���� SMT_MASK_WIDTH
	mov cl, al
	mov ebx, 0xFFFFFFFF
	shl ebx, cl									; (-1) << SMT_MASK_WIDTH
	not ebx										; ~(-1 << SMT_MASK_WIDTH)
	mov [x2apic_smt_select_mask + edx * 4], ebx					; ���� SMT_SELECT_MASK

do_extrac_loop_next:
	inc esi
	jmp do_extrac_loop
	
;; ��ȡ SMT_ID, CORE_ID �Լ� PACKAGE_ID
do_extrac_subid:
	mov eax, [x2apic_id + edx * 4]
	mov ebx, [x2apic_smt_select_mask]
	and ebx, eax								; x2APIC_ID & SMT_SELECT_MASK
	mov [x2apic_smt_id + eax * 4], ebx
	mov ebx, [x2apic_core_select_mask]
	and ebx, eax								; x2APIC_ID & CORE_SELECT_MASK
	mov cl, [x2apic_smt_mask_width]
	shr ebx, cl									; (x2APIC_ID & CORE_SELECT_MASK) >> SMT_MASK_WIDTH
	mov [x2apic_core_id + eax * 4], ebx
	mov ebx, [x2apic_package_select_mask]
	and ebx, eax								; x2APIC_ID & PACKAGE_SELECT_MASK
	mov cl, [x2apic_core_mask_width]
	shr ebx, cl									; (x2APIC_ID & PACKAGE_SELECT_MASK) >> CORE_MASK_WIDTH
	mov [x2apic_package_id + eax * 4], ebx		; 
	
extrac_x2apic_id_done:	
	pop ebx
	pop edx
	pop ecx
	ret
			

%endif	
		
;-----------------------------------
; read_esr(): �� ESR �Ĵ���
;-----------------------------------
read_esr:
        push ebp
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        REX.Wrxb
        mov eax, [ebp + PCB.LapicBase]
	mov DWORD [eax + ESR], 0		        ; д ESR �Ĵ���
	mov eax, [eax + ESR]
        pop ebp
	ret






