;*************************************************
;* system_data_manage.asm                        *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************

%include "..\inc\system_manage_region.inc"


;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
; �����ַ�ռ�˵��:
;; 1) 8000h - FFFFh��setup ģ��ʹ��
;; 2) 1_0000h - 1_FFFFh������δ��
;; 3) 2_0000h - 2_FFFFh��preccted/long ģ��ʹ��
;; 4) 10_0000h - 11_FFFFh��PCB ���򣨹�128K��
;; 5) 12_0000h - 14_FFFFh��SDA ���򣨹�192K��
;; 6) 20_0000h - 9F_FFFFh��Legacy ģʽ�µ� PT ���򣨹�8M��
;; 7) 200_0000h - 21F_FFFFh��Longmode �µ� PPT ���򣨹�2M��
;; 8) 220_0000h - 2FF_FFFFh��PT pool ���򣨹�14M��
;; 9) 101_0000h ~ ��User Stack Base ����
;; 10) 104_0000h ~��Kernel Stack Base ����
;; 11) 300_1000h ~��User Pool Base ����
;; 12) 320_0000h ~��Kernel Pool Base ����
;; 13) A0_0000h ~ BF_FFFFh : EPT PPT ����
;; 14) C0_0000h ~ FF_FFFFh ������δ��
;;
;;
;; ���������ڴ�Ϊ256M����ַ�� 0000_0000h - 0FFF_FFFFh
;;
;; VM �ڴ� domain ����˵����
;; 1) VM 0: 0000_0000h - 087F_FFFFh
;; 2) VM 1: 0880_0000 - 08FF_FFFFh (8M)
;; 3) VM 2: 0900_0000 - 097F_FFFFh (8M��
;; 4) VM 3: 0980_0000 - 09FF_FFFFh (8M)
;; 5) VM 4: 0A00_0000 - 0A7F_FFFFh (8M)
;; 6) VM 5: 0A80_0000 - 0AFF_FFFFh (8M)
;; 7) VM 6: 0B00_0000 - 0B7F_FFFFh
;; 8) VM 7: 0B80_0000 - 0BFF_FFFFh
;; 9) VM 8: 0C00_0000 - 0C7F_FFFFh
;; 10) ... ...
;;

;; �����ַ�ռ�˵����
;; һ. legacy ģʽ�£�
;; 1) 8000h - FFFFh��setup ģ��ʹ��
;; 2) 1_0000h - 1_FFFFh������δ��
;; 3) 2_0000h - 2_FFFFh��protected/long ģ��ʹ��
;; 4) 8000_0000h - 8001_FFFFh��PCB ����ӳ�䵽 10_0000h - 11_FFFFh��
;; 5) 8002_0000h - 8003_FFFFh��SDA ����ӳ�䵽 12_0000h - 13_FFFFh��
;; 6) 7FE0_0000h ~��User Stack Base ����
;; 7) FFE0_0000h ~��Kernel Stack Base ����
;; 8) 8320_0000h ~��Kernel Pool Base ����
;; 9) 7300_1000h ~��User Pool Base  ����
;; 10) C000_0000h - C07F_FFFFh��PT ������8M��
;; 11) C0A0_0000h - C0BF_FFFFh��EPT PPT ����2M)
;; 12) 8800_0000h ~ 8xxxx_xxxx��VM domain ����
;;
;; ��. longmode �£�
;; 1) 8000h - FFFFh��setup ģ��ʹ��
;; 2) 1_0000h - 1_FFFFh������δ��
;; 3) 2_0000h - 2_FFFFh��long ģ��ʹ��
;; 4) FFFF_F800_8000_0000h ~��PCB ����
;; 5) FFFF_F800_8002_0000h ~��SDA ����
;; 6) 7FE0_0000h ~��User Stack Base ����
;; 7) FFFF_FF80_FFE0_0000h ~��Kernel Stack Base ����
;; 8) FFFF_F800_8320_0000h ~��Kernel Pool Base ����
;; 9) 7300_1000h ~��User Pool Base  ����
;; 10) FFFF_F6FB_7DA0_0000h ~��PPT ������8M��
;; 11) FFFF_F800_8220_0000h ~��PT Pool ����
;; 12) FFFF_F800_8020_0000h ~������ PT Pool ����
;; 13) FFFF_F800_C0A0_0000h ~ FFFF_F800_C0BF_FFFFh��EPT PXT ����2M��
;; 14) FFFF_F800_8800_0000h ~ FFFF_F800_8xxx_xxxx��VM domain ����
;;
;;
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$



;;
;; ֧�ִ���������
;;
PROCESSOR_MAX           EQU     16


;;
;; PCB(Processor Control Block)�ɷ���ʹ�õ� pool ����
;;
PCB_SIZE                EQU     PROCESSOR_CONTROL_BLOCK_SIZE
PCB_POOL_SIZE           EQU     (PCB_SIZE * PROCESSOR_MAX)

;;
;; PCB pool �����ַ��ÿ���������� PCB ����������
;;
PCB_PHYSICAL_POOL       EQU     100000h


;;
;; PCB �� SDA �����ַ
;; �� 32 λ�£�
;; 1) PCB_BASE  =  8000_0000h
;; 2) SDA_BASE  =  8002_0000h (PCB_BASE + PCB_POOL_SIZE)
;;
;; �� 64 λ�£�
;; 1) PCB_BASE64  = ffff_f800_8000_0000h
;; 2) SDA_BASE64  = ffff_f800_8002_0000h (PCB_BASE64 + PCB_POOL_SIZE)
;;
PCB_BASE                EQU     80000000h
SDA_BASE                EQU     (PCB_BASE + PCB_POOL_SIZE)
PCB_BASE64              EQU     0FFFFF80080000000h
SDA_BASE64              EQU     (PCB_BASE64 + PCB_POOL_SIZE)


;;
;; PCB �� SDA �����ַ:
;; 1) PCB_PHYSICAL_BASE  =  100000h (PCB_PHYSICAL_POOL)
;; 2) SDA_PHYSICAL_BASE  =  120000h (PCB_PHYSICAL_POOL + PCB_POOL_SIZE)
;;
PCB_PHYSICAL_BASE       EQU     PCB_PHYSICAL_POOL
SDA_PHYSICAL_BASE       EQU     (PCB_PHYSICAL_POOL + PCB_POOL_SIZE)







;------------------------------------------------------
; pass_the_check_longmode()
; input:
;       none
; output:
;       none
; ������
;       ͨ�� longmode ֧�ּ�飬�����֧�ִ��������� HLT 
;------------------------------------------------------
pass_the_check_longmode:
        mov eax, 80000000h
        cpuid
        cmp eax, 80000001h
        jb pass_the_check_longmode.error
        mov eax, 80000001h
        cpuid 
        bt edx, 29
        jc pass_the_check_longmode.done
        
pass_the_check_longmode.error:
        mov si, SDA.ErrMsg2
        call puts
        hlt
        RESET_CPU
               
pass_the_check_longmode.done:
        ret    
        
        
;---------------------------------------------------
; pass_the_enable_apic()
; input:
;       none
; output:
;       none
; ������
;       ͨ�� apic �Ŀ����������������� HLT ״̬
;---------------------------------------------------
pass_the_enable_apic:
        push ecx
        push edx
	mov eax, 1
	cpuid
	bt edx, 9                               ; ����Ƿ�֧�� APIC on Chip
	jnc pass_the_enable_apic.error
        
        ;;
        ;; ���� global enable λ
        ;;
        mov ecx, IA32_APIC_BASE
        rdmsr
        bts eax, 11                             ; enable
        wrmsr
        
        ;;
        ;; ���� software enable λ
        ;;
        and eax, 0FFFFF000h                     ; local APIC base
        mov ebx, [eax + LAPIC_SVR]
        bts ebx, 8                              ; SVR.Enable = 1
        mov [eax + LAPIC_SVR], ebx
        
pass_the_enable_apic.done:
        pop edx
        pop ecx
        ret
        
pass_the_enable_apic.error:
        mov esi, SDA.ErrMsg1
        call puts
        hlt
        RESET_CPU
        
        

;-------------------------------------------------------------------
; append_gdt_descriptor(): �� GDT �����һ��������
; input:
;       edx:eax - 64 λ������
; output:
;       eax - ���� selector ֵ
; ������
;       1) ���һ���������������� GDTR 
;-------------------------------------------------------------------
append_gdt_descriptor:
        mov esi, [fs: SDA.GdtTop]                       ; ��ȡ GDT ����ԭֵ
        add esi, 8                                      ; ָ����һ�� entry
        mov [esi], eax
        mov [esi + 4], edx
        mov [fs: SDA.GdtTop], esi                       ; ���� gdt_top ��¼
        add DWORD [fs: SDA.GdtLimit], 8                 ; ���� gdt_limit ��¼
        sub esi, [fs: SDA.GdtBase]                      ; �õ� selector ֵ
        ;;
        ;; ����ˢ�� gdtr �Ĵ���
        ;;
        lgdt [fs: SDA.GdtPointer]
        mov eax, esi                                    ; ������ӵ� selector
        ret



;-------------------------------------------------------------------
; remove_gdt_descriptor(): �Ƴ� GDT ���һ��������
; input:
;       none
; output:
;       edx:eax - �����Ƴ���������
;-------------------------------------------------------------------
remove_gdt_descriptor:
        push ebx
        xor edx, edx
        xor eax, eax
        mov ebx, [fs: SDA.GdtTop]
        cmp ebx, [fs: SDA.GdtBase]
        jbe remove_gdt_descriptor.done
        mov edx, [ebx + 4]
        mov eax, [ebx]                                  ; ��ԭ������ֵ
        mov DWORD [ebx], 0
        mov DWORD [ebx + 4], 0                          ; ��������ֵ
        sub ebx, 8
        mov [fs: SDA.GdtTop], ebx
        sub DWORD [fs: SDA.GdtLimit], 8
remove_gdt_descriptor.done:        
        pop ebx
        ret




;-------------------------------------------------------------------
; set_gdt_descriptor(): �����ṩ�� selector ֵ�� GDT ��д��һ��������
; input:
;       esi - selector 
;       edx:eax - 64 λ������ֵ
; output:
;       eax - ������������ַ
;-------------------------------------------------------------------        
set_gdt_descriptor:
        push ebx
        and esi, 0FFF8h
        mov ebx, esi
        add ebx, [fs: SDA.GdtBase]
        mov [ebx], eax
        mov [ebx + 4], edx
        
        ;;
        ;; ��⼰���� GDT �� limit �� top
        ;;
        add esi, 7
        cmp ebx, [fs: SDA.GdtTop]
        jbe set_gdt_descriptor.next
        mov [fs: SDA.GdtTop], ebx  
             
set_gdt_descriptor.next:
        ;;
        ;; ������õ� GDT entry λ�ó����� GDT limit
        ;; �͸��� limit����ˢ�� gdtr �Ĵ���
        ;;
        cmp esi, [fs: SDA.GdtLimit]
        jbe set_gdt_descriptor.done
        mov [fs: SDA.GdtLimit], esi
        lgdt [fs: SDA.GdtPointer]               ; ˢ�� gdtr �Ĵ���
set_gdt_descriptor.done:        
        mov eax, ebx
        pop ebx
        ret


;-------------------------------------------------------------------
; get_gdt_descriptor(): ��ȡ GDT ������
; input:
;       esi - selector 
; output:
;       edx:eax - �ɹ�ʱ������ 64 λ��������ʧ��ʱ������ -1 ֵ
;------------------------------------------------------------------- 
get_gdt_descriptor:
        push ebx
        xor eax, eax
        inc eax
        mov edx, eax
        and esi, 0FFF8h
        mov ebx, esi
        add esi, 7
        
        ;; 
        ;; ����Ƿ� limit
        cmp esi, [fs: SDA.GdtLimit]
        ja get_gdt_descriptor.done
        
        add ebx, [fs: SDA.GdtBase]
        mov eax, [ebx]
        mov edx, [ebx + 4]
        
get_gdt_descriptor.done:        
        pop ebx
        ret        


;-------------------------------------------------------------------
; get_idt_descriptor(): ��ȡ IDT ������
; input:
;       esi - vector  
; output:
;       edx:eax - �ɹ�ʱ������ 64 λ��������ʧ��ʱ������ -1 ֵ
;------------------------------------------------------------------- 
get_idt_descrptor:
        push ebx
        xor eax, eax
        inc eax
        mov edx, eax                            ; edx:eax = -1
        and esi, 0FFh
        shl esi, 3                              ; vector * 8
        mov ebx, esi
        add esi, 7
        
        ;;
        ;; ����Ƿ� limit
        cmp esi, [fs: SDA.IdtLimit]
        ja get_idt_descriptor.done
        
        ;;
        ;; �� IDT entry
        add ebx, [fs: SDA.IdtBase]
        mov eax, [ebx]
        mov edx, [ebx + 4]
        
get_idt_descriptor.done:        
        pop ebx
        ret


;-------------------------------------------------------------------
; set_idt_descriptor(): �����ṩ�� vector ֵ�� IDT ��д��һ��������
; input:
;       esi - vector
;       edx:eax - 64 λ������ֵ
; output:
;       eax - ������������ַ
;-------------------------------------------------------------------  
set_idt_descriptor:
        push ebx
        and esi, 0FFh
        shl esi, 3                              ; vector * 8
        mov ebx, [fs: SDA.IdtBase]
        add ebx, esi
        mov [ebx], eax
        mov [ebx + 4], edx
        mov eax, ebx
        pop ebx
        ret





;-------------------------------------------------------------------
; mask_io_port_access(): ���ζ�ĳ���˿ڵķ���
; input:
;       esi - �˿�ֵ
; output:
;       none
;-------------------------------------------------------------------
mask_io_port_access:
set_iomap_bit:
        push ebp
        push ebx
        
%ifdef __X64        
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        REX.Wrxb
        mov ebx, [ebp + PCB.IomapBase]                          ; ����ǰ Iomap ��ַ
        test DWORD [ebp + PCB.ProcessorStatus], CPU_STATUS_PG
        REX.Wrxb
        cmovz ebx, [ebp + PCB.IomapPhysicalBase]
        mov eax, esi
        shr eax, 3                                              ; port / 8
        and esi, 7                                              ; ȡ byte ��λ��
        bts DWORD [ebx + eax], esi                              ; ��λ
        pop ebx
        pop ebp
        ret


;-------------------------------------------------------------------
; unmask_io_port_access(): ���ζ�ĳ���˿ڵķ���
; input:
;       esi - �˿�ֵ
; output:
;       none
;-------------------------------------------------------------------
unmask_io_port_access:
clear_iomap_bit:
        push ebp
        push ebx

%ifdef __X64        
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        REX.Wrxb
        mov ebx, [ebp + PCB.IomapBase]                          ; ����ǰ Iomap ��ַ
        test DWORD [ebp + PCB.ProcessorStatus], CPU_STATUS_PG
        REX.Wrxb
        cmovz ebx, [ebp + PCB.IomapPhysicalBase]        
        mov eax, esi
        shr eax, 3                                              ; port / 8
        and esi, 7                                              ; ȡ byte ��λ��
        btr DWORD [ebx + eax], esi                              ; ��λ
        pop ebx
        pop ebp
        ret
        
        
        
;-------------------------------------------------------------------
; update_processor_basic_info(): ���»����Ĵ�������Ϣ
; input:
;       none
; output:
;       none
;
; ע�⣺
;       �˺����ڿ��� paging ǰ����
;-------------------------------------------------------------------
update_processor_basic_info:
        push ebx
        push ecx
        push edx

        ;;
        ;; ���ô����� count �� index ֵ
        ;; 1) index Ϊ count ԭֵ
        ;; 2) ���� count ����
        ;;
        mov eax, 1
        lock xadd [fs: SDA.ProcessorCount], eax         ; processor count
        mov [gs: PCB.ProcessorIndex], eax               ; index = count(��ʼֵΪ0)
        
        
        ;;
        ;; ��ȡ basic �� extended ����� CPUID leaf
        ;;
        xor eax, eax
        cpuid
        mov [gs: PCB.MaxBasicLeaf], eax
        mov eax, 80000000h
        cpuid
        mov [gs: PCB.MaxExtendedLeaf], eax
                                                  
        ;;
        ;; �õ�  vendor ID ֵ
        ;;
        call get_vendor_id
        mov [gs: PCB.Vendor], eax        
        
        ;;
        ;; �õ����� CPUID ��Ϣ
        ;;
        call update_cpuid_info
        
        mov ebx, [gs: PCB.CpuidLeaf01Ebx]
        mov ecx, ebx
        and ecx, 0FF00h
        shr ecx, 5                                      ; cache line = EBX[15:08] * 8��bytes)
        mov [gs: PCB.CacheLineSize], ecx       
        mov ecx, ebx
        shr ecx, 16
        and ecx, 0FFh
        mov [gs: PCB.MaxLogicalProcessor], ecx          ; ����߼���������        
        shr ebx, 24
        mov [gs: PCB.InitialApicId], ebx                ; ��ʼ APIC ID       
        mov esi, [gs: PCB.CpuidLeaf01Eax]
        call get_display_family_model
        mov [gs: PCB.DisplayModel], ax                  ; DisplayFamily_DiplayModel
        
        ;;
        ;; ����Ƿ�֧�� SMT
        ;;
        call check_multi_threading_support
        mov [gs: PCB.IsMultiThreading], al
                
        ;;
        ;; ��� SSE ָ��֧�ֶ�
        ;;
        call get_sse_level
        mov [gs: PCB.SSELevel], eax
       
        ;;
        ;; ���� cache ��Ϣ
        ;;
        call update_cache_info

        
        ;;
        ;; ���»�������չ��Ϣ
        ;; 
        mov eax, 80000001h
        cpuid
        mov [gs: PCB.ExtendedFeatureEcx], ecx           ; ���� CPUID.80000001H Ҷ��Ϣ
        mov [gs: PCB.ExtendedFeatureEdx], edx
        mov eax, 80000008h
        cmp [gs: PCB.MaxExtendedLeaf], eax              ; �Ƿ�֧�� 8000000h leaf
        mov ecx, 2020h                                  ; 32 λ
        jb update_processor_basic_info.@1
        cpuid
        mov ecx, eax
        
update_processor_basic_info.@1:        
        ;;
        ;; ���� MAXPHYADDR ֵ
        ;;
        mov [gs: PCB.MaxPhysicalAddr], cl
        mov [gs: PCB.MaxVirtualAddr], ch
        
        ;;
        ;; ���� MAXPHYADDR MASK ֵ
        ;;
        call get_maxphyaddr_select_mask
        mov [gs: PCB.MaxPhyAddrSelectMask], eax
        mov [gs: PCB.MaxPhyAddrSelectMask + 4], edx
        
     
        ;;
        ;; IA32_PERF_CAPABILITIES �Ĵ����Ƿ����
        ;; ��� CPUID.01H:ECX[15].PDCM (Perfmon and Debug Capability)
        ;;
        xor edx, edx
        mov eax, [gs: PCB.FeatureEcx]
        bt eax, 15
        mov eax, edx
        jnc update_processor_basic_info.@2
        mov ecx, IA32_PERF_CAPABILITIES
        rdmsr
update_processor_basic_info.@2:        
        mov [gs: PCB.PerfCapabilities], eax
        mov [gs: PCB.PerfCapabilities + 4], edx

      
        ;;
        ;; APIC ������Ϣ
        ;;
        mov ecx, IA32_APIC_BASE
        rdmsr
        mov ebx, eax
        bt eax, 8                                       ; ����Ƿ�Ϊ BSP
        setc BYTE [gs: PCB.IsBsp]
        and eax, 0FFFFF000h
        mov [gs: PCB.LapicPhysicalBase], eax            ; local APIC �����ַ
        mov DWORD [gs: PCB.LapicBase], LAPIC_BASE       ; local APIC ��ַ��virutal address��
        mov ecx, [gs: PCB.ProcessorIndex]
        mov edx, 01000000h
        shl edx, cl                                     ; ���ɴ������߼� ID
        mov [gs: PCB.LogicalId], edx
        mov [eax + LAPIC_LDR], edx                      ; ���� local APIC ���߼� ID
         
        ;; 
        ;; ���� loacal APIC ��Ϣ
        ;;
        mov BYTE [gs: PCB.IsLapicEnable], 1
        mov BYTE [gs: PCB.IsLx2ApicEnable], 0
        mov ebx, [eax + LAPIC_ID]
        mov [gs: PCB.ApicId], ebx                       ; ���� Lapic ID
        mov ebx, [eax + LAPIC_VERSION]
        mov [gs: PCB.LapicVersion], ebx                 ; ���� Lapic version        
        
        ;;
        ;; ���ô������ĳ�ʼ TPR ֵ 
        ;;
        movzx ebx, BYTE [gs: PCB.CurrentTpl]
        shl ebx, 4
        mov [eax + LAPIC_TPR], ebx
        
        ;;
        ;; ��ʼ�� local LVT �Ĵ���
        ;;
        mov DWORD [eax + LVT_PERFMON], FIXED_DELIVERY | LAPIC_PERFMON_VECTOR
        mov DWORD [eax + LVT_TIMER], TIMER_ONE_SHOT | LAPIC_TIMER_VECTOR | LVT_MASKED
        mov DWORD [eax + TIMER_ICR], 0    
        mov DWORD [eax + LVT_ERROR], LAPIC_ERROR_VECTOR
        mov DWORD [eax + LVT_THERMAL], SMI_DELIVERY 
        mov DWORD [eax + LVT_CMCI], LVT_MASKED        
        mov DWORD [eax + LVT_LINT0], EXTINT_DELIVERY
        mov DWORD [eax + LVT_LINT1], NMI_DELIVERY        


update_processor_basic_info.@3:

        cmp BYTE [gs: PCB.IsBsp], 1
        jne update_processor_basic_info.@4
        
        ;;
        ;; ��ʼ�� IOAPIC
        ;;
        call init_ioapic_unit    

        ;;
        ;; ����������Ƶ��
        ;;
        call update_processor_frequency
        jmp update_processor_basic_info.@5
        
update_processor_basic_info.@4:
        ;;
        ;; ���� APs LINT0 �� LINT1
        ;;
        mov DWORD [eax + LVT_LINT0], LVT_MASKED | EXTINT_DELIVERY
        mov DWORD [eax + LVT_LINT1], LVT_MASKED | NMI_DELIVERY
                
        ;;
        ;; ��ȡ BSP �� PCB ��
        ;;
        mov ebx, [fs: SDA.PcbPhysicalBase]
        
        ;;
        ;; ���� BSP ��Ƶ������
        ;;        
        mov eax, [ebx + PCB.ProcessorFrequency]
        mov [gs: PCB.ProcessorFrequency], eax
        mov eax, [ebx + PCB.TicksFrequency]
        mov [gs: PCB.TicksFrequency], eax
        
        ;;
        ;; ���� BSP �� lapic timer ����Ƶ��
        ;;
        mov eax, [ebx + PCB.LapicTimerFrequency]
        mov [gs: PCB.LapicTimerFrequency], eax
               
update_processor_basic_info.@5:
        ;;
        ;; ���� Ioapic enable ״̬
        ;;
        mov BYTE [gs: PCB.IsIapicEnable], 1
        mov DWORD [gs: PCB.IapicPhysicalBase], 0FEC00000h
        mov DWORD [gs: PCB.IapicBase], IOAPIC_BASE   
        
        
        ;;
        ;; ������ش��������ܺ�ָ��֧��
        ;; 1) ���� PAE 
        ;; 2) ���� XD ֧��
        ;; 3) ���� SMEP ����
        ;;
        call pae_enable
        call xd_page_enable
        call smep_enable
        
        ;;
        ;; ���� CR4.OSFXSR λ������ִ�� SSE ָ��        
        ;;
        mov eax, cr4
        bts eax, 9                                      ; CR4.OSFXSR = 1
        mov cr4, eax 
        or DWORD [gs: PCB.InstructionStatus], INST_STATUS_SSE

        ;;
        ;; ���� Read/Write FS/GS base ���ܣ�����ʹ�� RD/WR FS/GS base ָ��
        ;;
        test DWORD [gs: PCB.FeatureAddition], 1         ; ��� RWFSBASE ����λ
        jz update_processor_basic_info.@6
        mov eax, cr4
        bts eax, 16                                     ; CR4.RWFSBASE = 1
        mov cr4, eax
        or DWORD [gs: PCB.InstructionStatus], INST_STATUS_RWFSBASE
        
update_processor_basic_info.@6:
        ;;
        ;; ֧�� VMX ʱ����ȡ VMX capabilities MSR
        ;;                
        test DWORD [gs: PCB.FeatureEcx], CPU_FLAGS_VMX
        jz update_processor_basic_info.@7
                
        call get_vmx_global_data
        
update_processor_basic_info.@7:
        
update_processor_basic_info.done:
        pop edx
        pop ecx
        pop ebx
        ret
        
        
;-------------------------------------------------------------------
; get_vendor_id(): ���� vendor ID
; input:
;       none
; output:
;       eax - vendor ID
;-------------------------------------------------------------------
get_vendor_id:
        xor eax, eax
        cpuid
        mov eax, VENDOR_UNKNOWN
        
        ;;
        ;; ��飺
        ;; 1) Intel: "GenuineIntel"
        ;; 2) AMD: "AuthenticAMD"
        ;;
check_for_intel:        
        cmp ebx, 756E6547h                      ; "Genu"
        jne check_for_amd
        cmp edx, 49656E69h                      ; "ineI"
        jne check_for_amd
        cmp ecx, 6C65746Eh                      ; "ntel"
        jne check_for_amd
        mov eax, VENDOR_INTEL
        ret
check_for_amd:
        cmp ebx, 68747541h                      ; "htuA"
        jne get_vendor_id.unknown
        cmp edx, 69746E65h                      ; "itne"
        jne get_vendor_id.unknown
        cmp ecx, 444D4163h                      ; "DMAc"
        jne get_vendor_id.unknown
        mov eax, VENDOR_AMD
get_vendor_id.unknown:
        ret



;-------------------------------------------------------------------
; update_cpuid_info()
; input:
;       none
; output:
;       none
; ������
;       1) ��ȡ������ CPUID ��Ϣ
;-------------------------------------------------------------------
update_cpuid_info:
        push ecx
        push edx
        push ebx
              
        ;;
        ;; ����ȡ 0B leaf
        ;;
        mov edi, 0Bh
        mov esi, [gs: PCB.MaxBasicLeaf]
        cmp esi, edi
        cmova esi, edi
        
        mov eax, esi        
        mov edi, [gs: PCB.PhysicalBase]
        shl eax, 4                                      ; MaxBasicLeaf * 16
        lea edi, [edi + PCB.CpuidLeaf01Eax + eax]       ; Cpuid Leaf ����
        
update_cpuid_info.@0:
        sub edi, 16
        mov eax, esi
        xor ecx, ecx
        cpuid
        mov [edi], eax
        mov [edi + 4], ebx
        mov [edi + 8], ecx
        mov [edi + 12], edx
        dec esi
        ja update_cpuid_info.@0
        
        pop ebx
        pop edx
        pop ecx
        ret




;-----------------------------------------------------------------
; get_maxphyaddr_select_mask(): ������ MAXPHYADDR ֵ�� SELECT MASK
; output:
;       edx:eax - maxphyaddr select mask
; ������
;       select mask ֵ����ȡ�� MAXPHYADDR ��Ӧ�������ֵַ
; ���磺
;       MAXPHYADDR = 32 ʱ��select mask = 00000000_FFFFFFFFh
;       MAXPHYADDR = 36 ʱ: select mask = 0000000F_FFFFFFFFh
;       MAXPHYADDR = 40 ʱ: select mask = 000000FF_FFFFFFFFh
;       MAXPHYADDR = 52 ʱ��select mask = 000FFFFF_FFFFFFFFh
;-----------------------------------------------------------------
get_maxphyaddr_select_mask:
        push ecx
        movzx ecx, BYTE [gs: PCB.MaxPhysicalAddr]       ; �õ� MAXPHYADDR ֵ
        xor eax, eax
        xor edx, edx
        and ecx, 1Fh                                    ; ȡ�� 32 ������
        dec eax                                         ; eax = -1��FFFFFFFFh)
        shld edx, eax, cl                               ; edx = n1
        pop ecx
        ret
        
        
;---------------------------------------------------------------------
; get_sse_level(): ��� SSE ָ��֧�ּ���
; input:
;       none
; output:
;       eax - sse level
;---------------------------------------------------------------------
get_sse_level:
        push ecx
        mov eax, 0402h
        mov ecx, [gs: PCB.FeatureEcx]
        bt ecx, 20                              ; SSE4.2
        jc get_sse_level.done
        mov eax, 0401h
        bt ecx, 19                              ; SSE4.1
        jc get_sse_level.done
        mov eax, 0301h
        bt ecx, 9                               ; SSSE3
        jc get_sse_level.done
        mov eax, 0300h               
        bt ecx, 0                               ; SSE3
        jc get_sse_level.done
        mov ecx, [gs: PCB.FeatureEdx]
        mov eax, 0200h
        bt ecx, 26                              ; SSE2
        jc get_sse_level.done
        mov eax, 0100h
        bt ecx, 25                              ; SSE
        jc get_sse_level.done
        xor eax, eax
get_sse_level.done:        
        pop ecx
        ret        


        
;---------------------------------------------------------------------
; get_display_family_model(): ��� DisplayFamily �� DisplayModel
; input:
;       esi - processor version��from CPUID.01H��
; output:
;       ax - DisplayFamily_DisplayModel
;--------------------------------------------------------------------
get_display_family_model:
	push ebx
	push edx
	push ecx
        mov eax, esi
	mov ebx, eax
	mov edx, eax
	mov ecx, eax
	shr eax, 4
	and eax, 0Fh                                    ; eax = bits 7:4 (�õ� model ֵ)
	shr edx, 8
	and edx, 0Fh                                    ; edx = bits 11:8 (�õ� family ֵ)
	

	cmp edx, 0Fh
	jne test_family_06
	;;
        ;; ����� Pentium 4 ����: DisplayFamily = ExtendedFamily + Family
        ;;
	shr ebx, 20                                     
	add edx, ebx                                    ; edx = ExtendedFamily + Family
	jmp get_displaymodel
        
test_family_06:	
	cmp edx, 06h
	jne get_display_family_model.done
        
get_displaymodel:	
        ;;
        ;; DisplayModel = ExtendedMode << 4 + Model
        ;;
	shr ecx, 12                                     ; ecx = ExtendedMode << 4
	and ecx, 0xf0
	add eax, ecx                                    ; �õ� DisplayModel
        
get_display_family_model.done:	
	mov ah, dl
	pop ecx
	pop edx
	pop ebx
	ret

;-----------------------------------------------------------------------
; check_multi_threading_support():
; input:
;       none
; output:
;       1 - yes, 0 - no
; ������
;       ��鴦�����Ƿ�֧�ֶ��߳�
;-----------------------------------------------------------------------
check_multi_threading_support:
        ;;
        ;; ��Ҫ��� CPUID.01H:EDX[28] �Լ� CPUID.01H:EBX[23:16] ��ֵ
        ;; 
        xor eax, eax
        bt DWORD [gs: PCB.FeatureEdx], 28               ; ��� CPUID.01H:EDX[28] λ
        jnc check_multi_threading_support.done
        ;;
        ;; Ȼ����֧������߼���������
        ;;
        cmp DWORD [gs: PCB.MaxLogicalProcessor], 1
        jb check_multi_threading_support.done
        inc eax
check_multi_threading_support.done:        
        ret



;-----------------------------------------------------------------------
; update_cache_info()
; input:
;       none
; output:
;       none
; ������
;       ��ȡ������ Cache ��Ϣ���ڿ��� paging ǰ���ã�
;-----------------------------------------------------------------------
update_cache_info:
        push ecx
        push ebx
        push edx
        push ebp
        
        ;;
        ;; ͨ��ö�� CPUID.04H leaf ����ȡ cache ��Ϣ
        ;;
        mov esi, 0                                      ; ��ʼ��Ҷ
        mov ebp, [gs: PCB.PhysicalBase]                 ; ʹ�������ַ
        
update_cache_info.loop:
        mov eax, 04h
        mov ecx, esi
        cpuid
        mov edi, eax
        
        ;;
        ;; û�� cache ��Ϣ
        ;;
        and eax, 1Fh
        cmp eax, CACHE_NONE
        je update_cache_info.done
        
        mov eax, edi        
        call get_cache_level_base                       ; ��ȡ cache ��Ϣ�ṹ��ַ
        add ebp, eax                                    ; ebp ��� cache ��Ϣ�ṹ��ַ
        mov eax, edi
        shr eax, 5
        and eax, 3                                      ; EAX[7:5] = cache level
        and edi, 1Fh                                    ; EAX[4:0] = cache type
        mov [ebp + CacheInfo.Type], di
        mov [ebp + CacheInfo.Level], ax
        mov eax, ebx
        shr eax, 22
        inc eax                                         ; ways
        mov [ebp + CacheInfo.Ways], ax
        mov eax, ebx
        shr eax, 12
        and eax, 3FFh                                   ; line partitions
        inc eax
        mov [ebp + CacheInfo.Partitions], ax
        mov eax, ebx
        and eax, 0FFFh                                  ; line size
        inc eax
        mov [ebp + CacheInfo.LineSize], ax
        inc ecx
        mov [ebp + CacheInfo.Sets], ecx                 ; sets
        call get_cache_size
        mov [ebp + CacheInfo.Size], eax                 ; cache size 
        inc esi                                         ; 
        jmp update_cache_info.loop

update_cache_info.done:                
        pop ebp
        pop edx
        pop ebx
        pop ecx
        ret



;-----------------------------------------------------------------------
; get_cache_level_base()
; input:
;       eax - CPUID.01H:EAX ֵ
; output:
;       eax - ��Ӧ�� cache ��Ϣ�ṹ��ַ
; ����:
;       �˺����� update_cache_info() �ڲ�ʹ��
;-----------------------------------------------------------------------
get_cache_level_base:
        push ecx
        push ebx
        mov ecx, eax
        and eax, 01Fh                                   ; EAX[4:0] = cache type ֵ
        shr ecx, 5
        and ecx, 3                                      ; EAX[7:5] = cache level ֵ
        
        ;;
        ;; ������ level ���� cache ����
        ;;
        cmp eax, CACHE_L1D                              ; �Ƿ�Ϊ level-1 data cache
        mov ebx, PCB.L1D
        je get_cache_level_base.done
        cmp eax, CACHE_L1I                              ; �Ƿ�Ϊ level-1 instruction cache
        mov ebx, PCB.L1I
        je get_cache_level_base.done

        ;;
        ;; ����� unified cache �򣬼�� level ��
        ;;
        mov ebx, PCB.L2
        cmp ecx, 2                                      ; �Ƿ�Ϊ level-2
        mov ecx, PCB.L3
        cmovne ebx, ecx                                 ; ����Ϊ level-3
        
get_cache_level_base.done:
        mov eax, ebx                                    ; ������Ӧ�� cache ��Ϣ�ṹ��ַ
        pop ebx                   
        pop ecx
        ret


;-----------------------------------------------------------------------
; get_cache_size()
; input:
;       ebp - cache �ṹ��ַ
; output:
;       eax - cache size
; ����:
;       �˺����� update_cache_info() �ڲ�ʹ��
;-----------------------------------------------------------------------
get_cache_size:
        push edx
        push ecx
        xor edx, edx
        
        ;;
        ;; Cache size(bytes)   
        ;;      = Ways * Partions * LineSize * Sets
        ;;      = (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
        ;;
        
        movzx eax, WORD [ebp + CacheInfo.Ways]
        movzx ecx, WORD [ebp + CacheInfo.Partitions]
        mul ecx
        movzx ecx, WORD [ebp + CacheInfo.LineSize]
        mul ecx
        mov ecx, [ebp + CacheInfo.Sets]
        mul ecx
        pop ecx
        pop edx
        ret




;-----------------------------------------------------------------------
; update_processor_frequency()
; input:
;       none
; output:
;       none
; ����:
;       1) ����������Ƶ��
; Ȩ��˵����
;       1) �ú������� Intel �� CPUFREQ.ASM ����

; Filename: CPUFREQ.ASM
; Copyright(c) 2003 - 2009 by Intel Corporation
;
; This program has been developed by Intel Corporation. Intel
; has various intellectual property rights which it may assert
; under certain circumstances, such as if another
; manufacturer's processor mis-identifies itself as being
; "GenuineIntel" when the CPUID instruction is executed.
;
; Intel specifically disclaims all warranties, express or
; implied, and all liability, including consequential and other
; indirect damages, for the use of this program, including
; liability for infringement of any proprietary rights,
; and including the warranties of merchantability and fitness
; for a particular purpose. Intel does not assume any
; responsibility for any errors which may appear in this program
; nor any responsibility to update it.
;-----------------------------------------------------------------------        
update_processor_frequency:
        push ecx
        push edx
        push ebx
        push ebp
        mov ebp, esp
        sub esp, 14
        
%define UPF.TscHi32             ebp - 4
%define UPF.TscLow32            ebp - 8
%define UPF.Nearest66Mhz        ebp - 10
%define UPF.Nearest50Mhz        ebp - 12
%define UPF.Delta66Mhz          ebp - 14

;;
;; �������Ϊ 5 ��
;; 1) Ĭ��Ϊ 18.2 * 5 = 91
;; 2) �����޸�Ϊ 18 ��
;;
INTERVAL_IN_TICKS               EQU     18
        
        
        ;;
        ;; ���� PIT timer ���ж����
        ;;
        call init_8253
        call enable_8259_timer
        sti

%ifdef REAL
        ;;
        ;; ����Ƿ�֧�� IA32_MPERF
        ;; 1) ֧��ʱ��ʹ�� IA32_MPERF ������
        ;; 2) ����ʹ�� time stamp ������
        ;;
        test DWORD [gs: PCB.CpuidLeaf06Ecx], 1                  ; ��� CPUID.06H:ECX[0]
        jnz update_processor_frequency.enh
%endif
        
        ;;
        ;; ��ǰһ��ʱ���жϼ���ֵ
        ;;
        mov ebx, [fs: SDA.TimerCount]                           

        ;;
        ;; �ȴ���һ�� timer �жϵ���
        ;;
update_processor_frequency.@0:        
        cmp ebx, [fs: SDA.TimerCount]
        je update_processor_frequency.@0
      
        ;;
        ;; �� time stamp ֵ����Ϊ������ʼֵ
        ;;
        rdtsc
        mov [UPF.TscLow32], eax                                 ; BeginTscLow32 ֵ
        mov [UPF.TscHi32], edx                                  ; BeginTscHi32 ֵ
        
        ;;
        ;; ���� lapic timer count ��ʼֵΪ 0FFFFFFFFh
        ;; �������� lapic timer ÿ�����
        ;;
        mov DWORD [0FEE00000h + TIMER_ICR], 0FFFFFFFFh
        
        
        ;;
        ;; ���� timer �ж���ʱ����ֵ
        ;; 1) ���� 5 �����ʱֵ��18.2 * 5 = 91��PIT ÿ���ж�18.2�Σ�5���ڲ���91���жϣ�
        ;; 2) ���� 1 �ε���ʱ
        ;;
        
        ;;
        ;; �޸ģ�
        ;; 1�������޸�Ϊ 1 �����ʱֵ��ԼΪ 19 ��
        ;;
        add ebx, INTERVAL_IN_TICKS + 1
        
        ;;
        ;; ����ȴ�����ʱ�䵽�������ȴ� 1 ����
        ;;
update_processor_frequency.@1:        
        cmp ebx, [fs: SDA.TimerCount]
        ja update_processor_frequency.@1
        
        ;;
        ;; ��ȡ������ TSC ֵ���������� TSC ��ֵ
        ;;
        rdtsc
        sub eax, [UPF.TscLow32]
        sbb edx, [UPF.TscHi32]
        
        ;;
        ;; ��ȡ lapic timer count ����ֵ
        ;;
        mov ecx, [0FEE00000h + TIMER_CCR]                       ; �� lapic timer ��ǰ����ֵ
        mov DWORD [0FEE00000h + TIMER_ICR], 0                   ; �� lapic timer ��ʼ����ֵ
        
        neg ecx
        dec ecx                                                 ; �õ� lapic timer 1��ļ�������
        jmp update_processor_frequency.next
        
        ;;
        ;; ����ʹ����ǿ�ķ�ʽ
        ;;
update_processor_frequency.enh:
        ;;
        ;; �� IA32_MPERF ������
        ;;
        mov ecx, IA32_MPERF
        xor eax, eax
        xor edx, edx

        ;;
        ;; ��ǰһ��ʱ���жϼ���ֵ
        ;;
        mov ebx, [fs: SDA.TimerCount]                           

        ;;
        ;; �ȴ���һ�� timer �жϵ���
        ;;
update_processor_frequency.@2:        
        cmp ebx, [fs: SDA.TimerCount]
        je update_processor_frequency.@2
        
        ;;
        ;; �� C0_MCNT ֵ���� 0 ��ʼ����
        ;;
        wrmsr
        
        ;;
        ;; ���� timer �ж���ʱ����ֵ
        ;; 1) ���� 5 �����ʱֵ��18.2 * 5 = 91��PIT ÿ���ж�18.2�Σ�
        ;; 2) ���� 1 �ε���ʱ
        ;;
        add ebx, INTERVAL_IN_TICKS + 1
        
        ;;
        ;; ����ȴ�����ʱ�䵽�������ȴ� 5 ����
        ;;
update_processor_frequency.@3:        
        cmp ebx, [fs: SDA.TimerCount]
        ja update_processor_frequency.@3
   
        ;;
        ;; �� C0_MCNT ��Ϊ����ֵ
        ;;
        rdmsr

                
update_processor_frequency.next:       
        ;;
        ;; ������� CPU Ƶ��
        ;; 1) MHz ��λֵ��54945 = (1 / 18.2) * 1,000,000������55ms����һ���жϣ�100����ж���Ҫ54945��
        ;; 2) tick_interval = 54945 * INTERVAL_IN_TICKS
        ;; 3) CpuFreq = TSC / tick_interval
        ;;
        mov ebx, 54945 * INTERVAL_IN_TICKS
        div ebx 
        
        ;;
        ;; eax = ������Ƶ��
        ;;
        mov [gs: PCB.TicksFrequency], eax
        
        ;;
        ;; Find nearest full/half multiple of 66/133 MHz
        ;;
        xor dx, dx
        mov ax, [gs: PCB.TicksFrequency]
        mov bx, 3
        mul bx
        add ax, 100
        mov bx, 200
        div bx
        mul bx
        xor dx, dx
        mov bx, 3
        div bx
        
        ;;        
        ;; ax contains nearest full/half multiple of 66/100 MHz
        ;;
        mov [UPF.Nearest66Mhz], ax
        sub ax, [gs: PCB.TicksFrequency]
        jge delta66
        neg ax                                  ; ax = abs(ax)
delta66:
        ;;
        ;; ax contains delta between actual and nearest 66/133 multiple
        ;;
        mov [UPF.Delta66Mhz], ax
        ;;
        ;; Find nearest full/half multiple of 100 MHz
        ;;
        xor dx, dx
        mov ax, [gs: PCB.TicksFrequency]
        add ax, 25
        mov bx, 50
        div bx
        mul bx
        ;;
        ;; ax contains nearest full/half multiple of 100 MHz
        ;;
        mov [UPF.Nearest50Mhz], ax
        sub ax, [gs: PCB.TicksFrequency]
        jge delta50
        neg ax                                  ; ax = abs(ax)
delta50:
        ;;
        ;; ax contains delta between actual and nearest 50/100 MHz
        ;; multiple
        ;;
        mov bx, [UPF.Nearest50Mhz]
        cmp ax, [UPF.Delta66Mhz]
        jb useNearest50Mhz
        mov bx, [UPF.Nearest66Mhz]
        ;;
        ;; Correction for 666 MHz (should be reported as 667 MHZ)
        ;;
        cmp bx, 666
        jne correct666
        inc bx        
        
correct666:
useNearest50Mhz:
        ;;
        ;; ����������������Ƶ��
        ;;
        movzx eax, bx
        mov [gs: PCB.ProcessorFrequency], eax

        ;;
        ;; ���� 1΢�� lapic timer ��������
        ;;
        xor edx, edx
        mov eax, ecx
        mov ecx, 1000000                                ; ��λΪ us
        div ecx
        cmp edx, 500000                                 ; ����������� 1000000/2 �Ļ�
        seta cl
        movzx ecx, cl
        add eax, ecx
        mov [gs: PCB.LapicTimerFrequency], eax
        
        ;;
        ;; �ر� timer ���ж����
        ;;
        cli
        call disable_8259_timer
        
        ;;
        ;; �� timer ����ֵ
        ;;
        mov DWORD [fs: SDA.TimerCount], 0
        
        mov esp, ebp
        pop ebp
        pop ebx
        pop edx
        pop ecx
        ret


        
          

             

;------------------------------------------------------
; get_vmx_global_data()
; input:
;       none
; output:
;       none
; ������
;       1) ��ȡ VMX �����Ϣ
;       2) �� stage1 �׶ε���
;------------------------------------------------------
get_vmx_global_data:
        push ecx
        push edx
        
        ;;
        ;; VmxGlobalData ����
        ;;
        mov edi, [gs: PCB.PhysicalBase]
        add edi, PCB.VmxGlobalData

        ;;
        ;; ### step 1: ��ȡ VMX MSR ֵ ###
        ;; 1) �� CPUID.01H:ECX[5]=1ʱ��IA32_VMX_BASIC �� IA32_VMX_VMCS_ENUM �Ĵ�����Ч
        ;; 2) ���ȶ�ȡ IA32_VMX_BASIC �� IA32_VMX_VMCS_ENUM �Ĵ���ֵ
        ;;
        
        mov esi, IA32_VMX_BASIC
                
get_vmx_global_data.@1:        
        mov ecx, esi
        rdmsr
        mov [edi], eax
        mov [edi + 4], edx
        inc esi
        add edi, 8
        cmp esi, IA32_VMX_VMCS_ENUM
        jbe get_vmx_global_data.@1
        
        ;;
        ;; ### step 2: ���Ŷ�ȡ IA32_VMX_PROCBASED_CTLS2 ###
        ;; 1) �� CPUID.01H:ECX[5]=1������ IA32_VMX_PROCBASED_CTLS[63] = 1ʱ��IA32_VMX_PROCBASED_CTLS2 �Ĵ�����Ч
        ;;
        test DWORD [gs: PCB.ProcessorBasedCtls + 4], ACTIVATE_SECONDARY_CONTROL
        jz get_vmx_global_data.@5
        
        mov ecx, IA32_VMX_PROCBASED_CTLS2
        rdmsr
        mov [gs: PCB.ProcessorBasedCtls2], eax
        mov [gs: PCB.ProcessorBasedCtls2 + 4], edx

        ;;
        ;; ### step 3: ���Ŷ�ȡ IA32_VMX_EPT_VPID_CAP
        ;; 1) �� CPUID.01H:ECX[5]=1��IA32_VMX_PROCBASED_CTLS[63]=1������ IA32_PROCBASED_CTLS2[33]=1 ʱ��IA32_VMX_EPT_VPID_CAP �Ĵ�����Ч
        ;;
        test edx, ENABLE_EPT
        jz get_vmx_global_data.@5        
        
        mov ecx, IA32_VMX_EPT_VPID_CAP
        rdmsr
        mov [gs: PCB.EptVpidCap], eax
        mov [gs: PCB.EptVpidCap + 4], edx
        
        ;;
        ;; ### step 4: ��ȡ IA32_VMX_VMFUNC��###
        ;; 1) IA32_VMX_VMFUNC �Ĵ�������֧�� "enable VM functions" 1-setting ʱ��Ч�������Ҫ����Ƿ�֧��!
        ;; 2) ��� IA32_VMX_PROCBASED_CTLS2[45] �Ƿ�Ϊ 1 ֵ
        ;;
        test DWORD [gs: PCB.ProcessorBasedCtls2 + 4], ENABLE_VM_FUNCTION
        jz get_vmx_global_data.@5
        
        mov ecx, IA32_VMX_VMFUNC
        rdmsr
        mov [gs: PCB.VmFunction], eax
        mov [gs: PCB.VmFunction + 4], edx


get_vmx_global_data.@5:        

        ;;
        ;; ### step 5: ��ȡ 4 �� VMX TRUE capability �Ĵ��� ###
        ;;
        ;; ��� bit55 of IA32_VMX_BASIC Ϊ 1 ʱ, ֧�� 4 �� capability �Ĵ�����
        ;; 1) IA32_VMX_TRUE_PINBASED_CTLS  = 48Dh
        ;; 2) IA32_VMX_TRUE_PROCBASED_CTLS = 48Eh
        ;; 3) IA32_VMX_TRUE_EXIT_CTLS      = 48Fh   
        ;; 4) IA32_VMX_TRUE_ENTRY_CTLS     = 490h
        ;;
        bt DWORD [gs: PCB.VmxBasic + 4], 23
        jnc get_vmx_global_data.@6

        mov BYTE [gs: PCB.TrueFlag], 1                                  ; ���� TrueFlag ��־λ
        ;;
        ;; ���֧�� TRUE MSR �Ļ�����ô�͸������� MSR:
        ;; 1) IA32_VMX_PINBASED_CTLS
        ;; 2) IA32_VMX_PROCBASED_CTLS
        ;; 3) IA32_VMX_EXIT_CTLS
        ;; 4) IA32_VMX_ENTRY_CTLS
        ;; �� TRUE MSR ��ֵ������� MSR!
        ;;
        mov ecx, IA32_VMX_TRUE_PINBASED_CTLS
        rdmsr
        mov [gs: PCB.PinBasedCtls], eax
        mov [gs: PCB.PinBasedCtls + 4], edx
        mov ecx, IA32_VMX_TRUE_PROCBASED_CTLS
        rdmsr
        mov [gs: PCB.ProcessorBasedCtls], eax
        mov [gs: PCB.ProcessorBasedCtls + 4], edx
        mov ecx, IA32_VMX_TRUE_EXIT_CTLS
        rdmsr
        mov [gs: PCB.ExitCtls], eax
        mov [gs: PCB.ExitCtls + 4], edx
        mov ecx, IA32_VMX_TRUE_ENTRY_CTLS
        rdmsr
        mov [gs: PCB.EntryCtls], eax
        mov [gs: PCB.EntryCtls + 4], edx                
                
                
get_vmx_global_data.@6:
        ;;
        ;; ### step 6: ���� CR0 �� CR4 �� mask ֵ���̶�Ϊ1ֵ��
        ;; 1) Cr0FixedMask = Cr0Fixed0 & Cr0Fixed1
        ;; 2) Cr4FixedMask = Cr4Fixed0 & Cr4Fxied1
        ;;
        mov eax, [gs: PCB.Cr0Fixed0]
        mov edx, [gs: PCB.Cr0Fixed0 + 4]
        and eax, [gs: PCB.Cr0Fixed1]
        and edx, [gs: PCB.Cr0Fixed1 + 4]
        mov [gs: PCB.Cr0FixedMask], eax                                 ; CR0 �̶�Ϊ 1 ֵ
        mov [gs: PCB.Cr0FixedMask + 4], edx
        mov eax, [gs: PCB.Cr4Fixed0]
        mov edx, [gs: PCB.Cr4Fixed0 + 4]
        and eax, [gs: PCB.Cr4Fixed1]
        and edx, [gs: PCB.Cr4Fixed1 + 4]
        mov [gs: PCB.Cr4FixedMask], eax                                 ; CR4 �̶�Ϊ 1 ֵ
        mov [gs: PCB.Cr4FixedMask + 4], edx
        
        ;;
        ;; ���� IA32_FEATURE_CONTROL.lock λ��
        ;; 1) �� lock = 0 ʱ��ִ�� VMXON ���� #GP �쳣
        ;; 2) �� lock = 1 ʱ��д IA32_FEATURE_CONTROL �Ĵ������� #GP �쳣
        ;;
        
        ;;
        ;; ���潫��� IA32_FEATURE_CONTROL �Ĵ���
        ;; 1) �� lock λΪ 0 ʱ����Ҫ����һЩ���ã�Ȼ������ IA32_FEATURE_CONTROL
        ;;        
        mov ecx, IA32_FEATURE_CONTROL
        rdmsr
        bts eax, 0                                                      ; ��� lock λ��������
        jc get_vmx_global_data.@7
        
        ;; lock δ����ʱ��
        ;; 1) �� lock ��λ������ IA32_FEATURE_CONTROL �Ĵ�����
        ;; 2) �� bit 2 ��λ������ enable VMXON outside SMX��
        ;; 3) ���֧�� enable VMXON inside SMX ʱ���� bit 1 ��λ!
        ;; 
        mov esi, 6                                                      ; enable VMX outside SMX = 1, enable VMX inside SMX = 1
        mov edi, 4                                                      ; enable VMX outside SMX = 1, enable VMX inside SMX = 0
        
        ;;
        ;; ����Ƿ�֧�� SMX ģʽ
        ;;
        test DWORD [gs: PCB.FeatureEcx], CPU_FLAGS_SMX
        cmovz esi, edi        
        or eax, esi
        wrmsr
        
                
get_vmx_global_data.@7:        

        ;;
        ;; ����ʹ�� enable VMX inside SMX ���ܣ������ IA32_FEATURE_CONTROL[1] �������Ƿ���뿪�� CR4.SMXE
        ;; 1) ����������û�п��� CR4.SMXE
        ;;
%ifdef ENABLE_VMX_INSIDE_SMX
        ;;
        ;; ### step 7: ���� Cr4FixedMask �� CR4.SMXE λ ###
        ;;
        ;; �ٴζ�ȡ IA32_FEATURE_CONTROL �Ĵ���
        ;; 1) ��� enable VMX inside SMX λ��bit1��
        ;;    1.1) ����� inside SMX���� bit1 = 1���������� CR4FixedMask λ����Ӧλ
        ;; 
        rdmsr
        and eax, 2                                                      ; ȡ enable VMX inside SMX λ��ֵ��bit1��
        shl eax, 13                                                     ; ��Ӧ�� CR4 �Ĵ����� bit 14 λ���� CR4.SMXE λ��
        or DWORD [ebp + PCB.Cr4FixedMask], eax                          ; �� Cr4FixedMask ������ enable VMX inside SMX λ��ֵ��        
        
%endif

get_vmx_global_data.@8:        
        ;;
        ;; ### step 8: ��ѯ Vmcs �Լ� access page ���ڴ� cache ���� ###
        ;; 1) VMCS �����ڴ�����
        ;; 2) VMCS �ڵĸ��� bitmap ����access page �ڴ�����
        ;;
        mov eax, [gs: PCB.VmxBasic + 4]
        shr eax, 50-32                                                  ; ��ȡ IA32_VMX_BASIC[53:50]
        and eax, 0Fh
        mov [gs: PCB.VmcsMemoryType], eax


get_vmx_global_data.@9:        
        ;;
        ;; ### step 9: ��� VMX ��֧�ֵ� EPT page memory attribute ###
        ;; 1) ���֧�� WB ������ʹ�� WB, ����ʹ�� UC
        ;; 2) �� EPT ���� memory type ʱ��ֱ�ӻ��� [gs: PCB.EptMemoryType]
        ;;
        mov esi, MEM_TYPE_WB                                            ; WB 
        mov eax, MEM_TYPE_UC                                            ; UC        
        bt DWORD [gs: PCB.EptVpidCap], 14
        cmovnc esi, eax        
        mov [gs: PCB.EptMemoryType], esi
        
get_vmx_global_data.done:
        pop edx
        pop ecx        
        ret
        


;---------------------------------------------
; pag_enable()
; input:
;       none
; output:
;       none
; ������
;       1) ���� CR4.PAE
;---------------------------------------------
pae_enable:
        ;;
        ;; ��� CPUID.01H.EDX[6] ��־λ
        ;;
        mov eax, [gs: PCB.CpuidLeaf01Edx]        
        bt eax, 6                                       ; PAE support?
        jnc pae_enable_done
        mov eax, cr4
        or eax, CR4_PAE                                 ; CR4.PAE = 1        
        mov cr4, eax
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_PAE
pae_enable_done:        
        ret



;-------------------------------------------------
; xd_page_enable()
; input:
;       none
; output:
;       none
; ������
;       1) ���� XD λ
;-------------------------------------------------
xd_page_enable:
        ;;
        ;; ��� CPUID.80000001H:EDX[20].XD
        ;;
        mov eax, [gs: PCB.ExtendedFeatureEdx]
        bt eax, 20                                      ; XD support ?
        mov eax, 0
        jnc xd_page_enable.done
        mov ecx, IA32_EFER
        rdmsr 
        bts eax, 11                                     ; EFER.NXE = 1
        wrmsr        
        mov eax, XD
xd_page_enable.done:        
        mov DWORD [fs: SDA.XdValue], eax                ; д XD ��־ֵ
        ret




;----------------------------------------------
; semp_enable()
; input:
;       none
; output:
;       none
; ������
;       1) ���� SEMP ����
;----------------------------------------------
smep_enable:
        ;;
        ;; ��� CPUID.07H:EBX[7].SMEP λ
        ;;
        mov eax, [gs: PCB.CpuidLeaf07Ebx]
        bt eax, 7                                       ; SMEP suport ?
        jnc smep_enable_done
        mov eax, cr4
        or eax, CR4_SMEP                                ; enable SMEP
        mov cr4, eax
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_SMEP
smep_enable_done:        
        ret          