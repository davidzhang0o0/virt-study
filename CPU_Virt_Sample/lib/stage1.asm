;*************************************************
; stage1.asm                                     *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************



;-------------------------------------------------------------------
; init_system_data_area()
; input:
;       none
; output:
;       none
; ������
;       1) ��ʼ��ϵ�y��������SDA��
;       2) �˺���ִ���� 32-bit ����ģʽ��
;-------------------------------------------------------------------
init_system_data_area:
        push ecx
        push edx
        ;;
        ;; ��ַ˵����
        ;; 1) ���еĵ�ֵַʹ�� 64 λ
        ;; 2) �� 32 λʹ���� legacy ģʽ�£�ӳ�� 32 λֵ
        ;; 3) �� 32 λʹ���� 64-bit ģʽ�£�ӳ�� 64 λֵ
        ;;
        
        
        ;;
        ;; SDA ������Ϣ˵����
        ;; 1) SDA.Base ֵ��
        ;;      1.1) legacy �� SDA_BASE = 8002_0000h
        ;;      1.2) 64-bit �� SDA_BASE = ffff_f800_8000_0000h
        ;; 2) SDA.PhysicalBase ֵ��
        ;;      2.1) legacy �� 64-bit �±��ֲ��䣬Ϊ 12_0000h
        ;; 3) SDA.PcbBase ֵ��
        ;;      3.1) ָ�� BSP �� PCB ���򣬼���8000_0000h
        ;; 4) SDA.PcbPhysicalBase ֵ��
        ;;      4.1) ָ�� BSP �� PCB �����ַ������10_0000h
        ;;
        mov edx, 0FFFFF800h                                             ; 64 λ��ַ�еĸ� 32 λ
        xor ecx, ecx
        
        mov DWORD [fs: SDA.Base], SDA_BASE                              ; SDA �����ַ
        mov [fs: SDA.Base + 4], edx
        mov DWORD [fs: SDA.PhysicalBase], SDA_PHYSICAL_BASE             ; SDA �����ַ
        mov [fs: SDA.PhysicalBase + 4], ecx
        mov DWORD [fs: SDA.PcbBase], PCB_BASE                           ; ָ�� BSP �� PCB ����
        mov [fs: SDA.PcbBase + 4], edx
        mov DWORD [fs: SDA.PcbPhysicalBase], PCB_PHYSICAL_BASE          ; ָ�� BSP �� PCB ����
        mov [fs: SDA.PcbPhysicalBase + 4], ecx
        mov [fs: SDA.ProcessorCount], ecx                               ; �� processor count
        mov DWORD [fs: SDA.Size], SDA_SIZE                              ; SDA size
        mov DWORD [fs: SDA.ApInitDoneCount], 1
        mov DWORD [fs: SDA.VideoBufferHead], 0B8000h
        mov DWORD [fs: SDA.VideoBufferHead + 4], ecx
        mov DWORD [fs: SDA.VideoBufferPtr], 0B8000h
        mov DWORD [fs: SDA.VideoBufferPtr + 4], ecx
        mov DWORD [fs: SDA.TimerCount], ecx
        mov DWORD [fs: SDA.LastStatusCode], ecx
        mov DWORD [fs: SDA.UsableProcessorMask], ecx                    ; UsableProcessorMask ָʾ������
        mov DWORD [fs: SDA.ProcessMask], ecx                            ; process queue = 0��������
        mov DWORD [fs: SDA.ProcessMask + 4], ecx
        mov DWORD [fs: SDA.NmiIpiRequestMask], ecx
        
        ;;
        ;; ���������ڴ� size
        ;;
        mov eax, [MMap.Size]
        mov ecx, [MMap.Size + 4]
        shrd eax, ecx, 10                                               ; ת��Ϊ KB ��λ
        mov [fs: SDA.MemorySize], eax
               
        ;;
        ;; ����boot������
        ;;
        mov al, [7C03h]
        mov [fs: SDA.BootDriver], al
        
        ;;
        ;; �����Ҫ���� longmode ���� __X64 ����
        ;; 1��SDA.ApLongmode = 1 ʱ���������д��������� longmode ģʽ
        ;; 2) SDA.ApLongmode = 0 ʱ��ʹ�� legacy ����
        ;;
%ifdef  __X64
        mov DWORD [fs: SDA.ApLongmode], 1
%else
        mov DWORD [fs: SDA.ApLongmode], 0
%endif              
        
        
        ;;
        ;; ��ʼ�� PCB pool ��������¼
        ;; 1) PCB pool ������ÿ�� logical processor ����˽�е� PCB ��
        ;; 2) ��֧�� 16 �� logical processor
        ;; 3) PCB pool ��ַΪ PCB_BASE = 8000_0000h��PCB_POOL_SIZE = 128K
        ;; 4) PCB pool �����ַ PCB_PHYSICAL_BASE = 10_0000h
        ;;
        mov DWORD [fs: SDA.PcbPoolBase], PCB_BASE                       ; PCB pool ��ַ
        mov [fs: SDA.PcbPoolBase + 4], edx
        mov DWORD [fs: SDA.PcbPoolPhysicalBase], PCB_PHYSICAL_POOL      ; PCB pool �����ַ
        mov DWORD [fs: SDA.PcbPoolPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.PcbPoolPhysicalTop], SDA_PHYSICAL_BASE - 1   ; PCB pool ����
        mov DWORD [fs: SDA.PcbPoolPhysicalTop + 4], ecx
        mov DWORD [fs: SDA.PcbPoolTop], PCB_BASE + PCB_POOL_SIZE - 1
        mov DWORD [fs: SDA.PcbPoolTop + 4], edx
        mov DWORD [fs: SDA.PcbPoolSize], PCB_POOL_SIZE
        
        ;;
        ;; ��ʼ�� TSS ���� pool ��¼
        ;; 1) TSS pool ����Ϊÿ�� logical processor ����˽�е� TSS ��
        ;; 2) ÿ�η���Ķ�� TssPoolGranularity = 100h �ֽ�
        ;;
        mov DWORD [fs: SDA.TssPoolBase], SDA_BASE + SDA.Tss             ; TSS pool ��ַ
        mov [fs: SDA.TssPoolBase + 4], edx
        mov DWORD [fs: SDA.TssPoolPhysicalBase], SDA_PHYSICAL_BASE + SDA.Tss
        mov [fs: SDA.TssPoolPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.TssPoolTop], SDA_BASE + SDA.Tss + 0FFFh      ; TSS pool ����
        mov DWORD [fs: SDA.TssPoolTop + 4], edx
        mov DWORD [fs: SDA.TssPoolPhysicalTop], SDA_PHYSICAL_BASE + SDA.Tss + 0FFFh
        mov DWORD [fs: SDA.TssPoolPhysicalTop + 4], ecx
        mov DWORD [fs: SDA.TssPoolGranularity], 100h                    ; TSS ���������Ϊ 100h �ֽ�
        
        ;;
        ;; ���û��� GDT ����
        ;; 1) entry 0:          NULL descriptor
        ;; 2) entry 1,2��       64-bit kernel code/data ������
        ;; 3) entry 3,4:        32-bit user code/data ������
        ;; 4) entry 5,6:        64-bit user code/data ������
        ;; 5) entry 7,8:        32-bit kernel code/data ������                
        ;; 6) entry 9,10:       fs/gs ��ʹ��
        ;; 7) entry 11,12:      TSS ��������̬����
        ;; 
        mov [fs: SDA.Gdt], ecx
        mov [fs: SDA.Gdt + 4], ecx
        
        ;;
        ;; 64-bit Kernel CS/SS ����������˵����
        ;; 1���� x64 ��ϵ����������������Ϊ��
        ;;      * CS = 00209800_00000000h (L=P=1, G=D=0, C=R=A=0)
        ;;      * SS = 00009200_00000000h (L=1, G=B=0, W=1, E=A=0)
        ;; 2) �� VMX �ܹ���, ��VM-exit ���� host ��Ὣ����������Ϊ��
        ;;      * CS = 00AF9B00_0000FFFFh (G=L=P=1, D=0, C=0, R=A=1, limit=4G)
        ;;      * SS = 00CF9300_0000FFFFh (G=P=1, B=1, E=0, W=A=1, limit=4G)
        ;;
        ;; 3) ��ˣ�Ϊ���� host �����������һ�£����ｫ��������Ϊ��
        ;;      * CS = 00AF9A00_0000FFFFh (G=L=P=1, D=0, C=A=0, R=1, limit=4G)
        ;;      * SS = 00CF9200_0000FFFFh (G=P=1, B=1, E=A=0, W=1, limit=4G)  
        ;;
%if 0        
        mov [fs: SDA.Gdt + KernelCsSelector64], ecx
        mov DWORD [fs: SDA.Gdt + KernelCsSelector64 + 4], 00209800h
        mov [fs: SDA.Gdt + KernelSsSelector64], ecx
        mov DWORD [fs: SDA.Gdt + KernelSsSelector64 + 4], 00009200h
%endif
        mov DWORD [fs: SDA.Gdt + KernelCsSelector64], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + KernelCsSelector64 + 4], 00AF9A00h
        mov DWORD [fs: SDA.Gdt + KernelSsSelector64], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + KernelSsSelector64 + 4], 00CF9200h      
        
        
        ;;
        ;; 32-bit User CS/SS ������
        ;;
        mov DWORD [fs: SDA.Gdt + UserCsSelector32], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + UserCsSelector32 + 4], 00CFFA00h
        mov DWORD [fs: SDA.Gdt + UserSsSelector32], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + UserSsSelector32 + 4], 00CFF200h
        ;;
        ;; 64-bit User CS/SS ������
        ;;
        mov [fs: SDA.Gdt + UserCsSelector64], ecx
        mov DWORD [fs: SDA.Gdt + UserCsSelector64 + 4], 0020F800h
        mov [fs: SDA.Gdt + UserSsSelector64], ecx
        mov DWORD [fs: SDA.Gdt + UserSsSelector64 + 4], 0000F200h
        ;;
        ;; 32-bit Kernel CS/SS ������
        ;;
        mov DWORD [fs: SDA.Gdt + KernelCsSelector32], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + KernelCsSelector32 + 4], 00CF9A00h
        mov DWORD [fs: SDA.Gdt + KernelSsSelector32], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + KernelSsSelector32 + 4], 00CF9200h  
        ;;
        ;; FS/GS ������
        ;; 1) FS base = 12_0000h, limit = 1M, DPL = 0
        ;; 2) GS base = 10_0000h, limit = 1M, DPL = 0
        ;;
        mov DWORD [fs: SDA.Gdt + FsSelector], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + FsSelector + 4], 000F9212h
        mov DWORD [fs: SDA.Gdt + GsSelector], 0000FFFFh
        mov DWORD [fs: SDA.Gdt + GsSelector + 4], 000F9210h  

        
        ;;
        ;; ���� GDT selector
        ;;
        mov WORD [fs: SDA.KernelCsSelector], KernelCsSelector32
        mov WORD [fs: SDA.KernelSsSelector], KernelSsSelector32
        mov WORD [fs: SDA.UserCsSelector], UserCsSelector32
        mov WORD [fs: SDA.UserSsSelector], UserSsSelector32
        mov WORD [fs: SDA.FsSelector], FsSelector
        mov WORD [fs: SDA.SysenterCsSelector], KernelCsSelector32
        mov WORD [fs: SDA.SyscallCsSelector], KernelCsSelector32
        mov WORD [fs: SDA.SysretCsSelector], UserCsSelector32
                
        ;;
        ;; ���� GDT pointer
        ;; 1) ��ʱ GDT base ʹ�������ַ
        ;;
        mov DWORD [fs: SDA.GdtBase], SDA_PHYSICAL_BASE + SDA.Gdt
        mov [fs: SDA.GdtBase + 4], edx        
        mov WORD [fs: SDA.GdtLimit], 11 * 8 - 1                                  ; �� 11 �� entry        
        mov DWORD [fs: SDA.GdtTop], SDA_PHYSICAL_BASE + SDA.Gdt + 10 * 8         ; top ָ��� 10 �� entry  
        mov [fs: SDA.GdtTop + 4], edx

                
        ;;
        ;; ���� IDT pointer
        ;; 1) ��ʱ IDT base ʹ�������ַ
        ;;
        mov DWORD [fs: SDA.IdtBase], SDA_PHYSICAL_BASE + SDA.Idt
        mov [fs: SDA.IdtBase + 4], edx
        mov WORD [fs: SDA.IdtLimit], 256 * 16 - 1                       ; Ĭ�ϱ��� 255 �� vector��Ϊ longmode �£�
        mov DWORD [fs: SDA.IdtTop], SDA_PHYSICAL_BASE + SDA.Idt         ; top ָ�� base
        mov [fs: SDA.IdtTop + 4], edx
        
        ;;
        ;; ��ʼ SRT��ϵͳ�������̱���Ϣ
        ;;
        mov DWORD [fs: SRT.Base], SDA_BASE + SRT.Base                   ; SRT ��ַ
        mov [fs: SRT.Base + 4], edx
        mov DWORD [fs: SRT.PhysicalBase], SDA_PHYSICAL_BASE + SRT.Base  ; SRT �����ַ
        mov [fs: SRT.PhysicalBase + 4], ecx
        mov DWORD [fs: SRT.Size], SRT_SIZE - SDA_SIZE
        mov DWORD [fs: SRT.Top], SRT_TOP
        mov DWORD [fs: SRT.Top + 4], edx
        mov DWORD [fs: SRT.Index], SDA_BASE + SRT.Entry
        mov DWORD [fs: SRT.Index + 4], edx
        mov DWORD [fs: SRT.ServiceRoutineVector], SYS_SERVICE_CALL      ; ϵͳ��������������
                

        ;;
        ;; ��ʼ�� paging ����ֵ��legacy ģʽ�£�
        ;;
        mov DWORD [fs: SDA.XdValue], 0                                  ; XD λ�� 0
        mov DWORD [fs: SDA.PtBase], PT_BASE                             ; PT ���ַΪ 0C0000000h
        mov DWORD [fs: SDA.PtTop], PT_TOP                               ; PT ����Ϊ 0C07FFFFFh
        mov DWORD [fs: SDA.PtPhysicalBase], PT_PHYSICAL_BASE            ; PT �������ַΪ 200000h
        mov DWORD [fs: SDA.PdtBase], PDT_BASE                           ; PDT ���ַΪ 0C0600000h
        mov DWORD [fs: SDA.PdtTop], PDT_TOP                             ; PDT ����Ϊ 0C0603FFFh        
        mov DWORD [fs: SDA.PdtPhysicalBase], PDT_PHYSICAL_BASE          ; PDT �������ַΪ 800000h
        
        ;;
        ;; ��ʼ legacy ģʽ�µ� PPT ��¼
        ;; 1) PPT �������ַ = SDA_PHYSICAL_BASE + SDA.Ppt
        ;; 2) PPT ���ַ = SDA_BASE + SDA.Ppt
        ;; 3) PPT ���� = SDA_BASE + SDA.Ppt + 31
        ;;
        mov DWORD [fs: SDA.PptPhysicalBase], SDA_PHYSICAL_BASE + SDA.Ppt
        mov DWORD [fs: SDA.PptBase], SDA_BASE + SDA.Ppt                 
        mov DWORD [fs: SDA.PptTop], SDA_BASE + SDA.Ppt + 31
        
      
        ;;
        ;; ��ʼ�� long-mode �µ� page ����ֵ
        ;;
        mov eax, 0FFFFF6FBh
        mov DWORD [fs: SDA.PtBase64], 0
        mov DWORD [fs: SDA.PtBase64 + 4], 0FFFFF680h
        mov DWORD [fs: SDA.PdtBase64], 40000000h
        mov DWORD [fs: SDA.PdtBase64 + 4], eax
        mov DWORD [fs: SDA.PptBase64], 7DA00000h
        mov DWORD [fs: SDA.PptBase64 + 4], eax
        mov DWORD [fs: SDA.PxtBase64], 7DBED000h
        mov DWORD [fs: SDA.PxtBase64 + 4], eax
        mov DWORD [fs: SDA.PtTop64], 0FFFFFFFFh
        mov DWORD [fs: SDA.PtTop64 + 4], 0FFFFF6FFh
        mov DWORD [fs: SDA.PdtTop64], 7FFFFFFFh
        mov DWORD [fs: SDA.PdtTop64 + 4], eax
        mov DWORD [fs: SDA.PptTop64], 7DBFFFFFh
        mov DWORD [fs: SDA.PptTop64 + 4], eax
        mov DWORD [fs: SDA.PxtTop64], 7DBEDFFFh
        mov DWORD [fs: SDA.PxtTop64 + 4], eax
        mov DWORD [fs: SDA.PxtPhysicalBase64], PXT_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PxtPhysicalBase64 + 4], 0
        mov DWORD [fs: SDA.PptPhysicalBase64], PPT_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PptPhysicalBase64 + 4], 0
        mov BYTE [fs: SDA.PptValid], 0
        
        ;;
        ;; PT pool �����¼:
        ;; 1) �� PT pool ����220_0000h - 2ff_ffffh��ffff_f800_8220_000h��
        ;; 2) ���� Pt pool ����20_0000h - 09f_ffffh��ffff_f800_8020_0000h��
        ;;
        mov DWORD [fs: SDA.PtPoolPhysicalBase], PT_POOL_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PtPoolPhysicalBase + 4], 0
        mov DWORD [fs: SDA.PtPoolPhysicalTop], PT_POOL_PHYSICAL_TOP64
        mov DWORD [fs: SDA.PtPoolPhysicalTop + 4], 0
        mov DWORD [fs: SDA.PtPoolSize], PT_POOL_SIZE
        mov DWORD [fs: SDA.PtPoolSize + 4], 0
        mov DWORD [fs: SDA.PtPoolBase], 82200000h
        mov DWORD [fs: SDA.PtPoolBase + 4], 0FFFFF800h
        
        mov DWORD [fs: SDA.PtPool2PhysicalBase], PT_POOL2_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PtPool2PhysicalBase + 4], 0
        mov DWORD [fs: SDA.PtPool2PhysicalTop], PT_POOL2_PHYSICAL_TOP64
        mov DWORD [fs: SDA.PtPool2PhysicalTop + 4], 0
        mov DWORD [fs: SDA.PtPool2Size], PT_POOL2_SIZE
        mov DWORD [fs: SDA.PtPool2Size + 4], 0
        mov DWORD [fs: SDA.PtPool2Base], 80200000h
        mov DWORD [fs: SDA.PtPool2Base + 4], 0FFFFF800h
        
        mov BYTE [fs: SDA.PtPoolFree], 1
        mov BYTE [fs: SDA.PtPool2Free], 1

        ;;
        ;; VMX Ept(extended page table)�����¼
        ;; 1) PXT ������FFFF_F800_C0A0_0000h - FFFF_F800_C0BF_FFFFh(A0_0000h - BF_FFFFh)
        ;; 2) PPT �������� SDA ��
        ;;
        mov eax, [fs: SDA.Base]
        mov edx, [fs: SDA.PhysicalBase]
        add eax, SDA.EptPxt - SDA.Base
        add edx, SDA.EptPxt - SDA.Base        
        mov DWORD [fs: SDA.EptPxtBase64], eax
        mov DWORD [fs: SDA.EptPxtPhysicalBase64], edx
        mov DWORD [fs: SDA.EptPptBase64], 0C0A00000h
        mov DWORD [fs: SDA.EptPptPhysicalBase64], 0A00000h
        add eax, (200000h - 1)
        mov DWORD [fs: SDA.EptPxtTop64], eax
        mov DWORD [fs: SDA.EptPptTop64], 0C0BFFFFFh
                
        mov DWORD [fs: SDA.EptPxtBase64 + 4], 0FFFFF800h
        mov DWORD [fs: SDA.EptPxtPhysicalBase64 + 4], 0
        mov DWORD [fs: SDA.EptPptBase64 + 4], 0FFFFF800h
        mov DWORD [fs: SDA.EptPptPhysicalBase64 + 4], 0
        mov DWORD [fs: SDA.EptPxtTop64 + 4], 0FFFFF800h
        mov DWORD [fs: SDA.EptPptTop64 + 4], 0FFFFF800h
        
        
        
        ;;
        ;; ��ʼ�� stack �� pool ������Ϣ
        ;; 1) legacy �£� KERNEL_STACK_BASE  = ffe0_0000h
        ;;                USER_STACK_BASE    = 7fe0_0000h
        ;;                KERNEL_POOL_BASE   = 8320_0000h
        ;;                USER_POOL_BASE     = 7300_1000h
        ;;
        ;; 2) 64-bit ��:  KERNEL_STACK_BASE64 = ffff_ff80_ffe0_0000h
        ;;                USER_STACK_BASE64   = 0000_0000_7fe0_0000h
        ;;                KERNEL_POOL_BASE64  = ffff_f800_8320_0000h
        ;;                USER_POOL_BASE64    = 0000_0000_7300_1000h
        ;;
        ;; 3) �����ַ:   KERNEL_STACK_PHYSICAL_BASE = 0104_0000h
        ;;               USER_STACK_PHYSICAL_BASE    = 0101_0000h
        ;;               KERNEL_POOL_PHYSICAL_BASE   = 0320_0000h
        ;;               USER_POOL_PHYSICAL_BASE     = 0300_1000h
        ;;
        xor ecx, ecx
        mov DWORD [fs: SDA.UserStackBase], USER_STACK_BASE
        mov [fs: SDA.UserStackBase + 4], ecx
        mov DWORD [fs: SDA.UserStackPhysicalBase], USER_STACK_PHYSICAL_BASE
        mov [fs: SDA.UserStackPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.KernelStackBase], KERNEL_STACK_BASE
        mov DWORD [fs: SDA.KernelStackBase + 4], 0FFFFFF80h
        mov DWORD [fs: SDA.KernelStackPhysicalBase], KERNEL_STACK_PHYSICAL_BASE
        mov [fs: SDA.KernelStackPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.UserPoolBase], USER_POOL_BASE
        mov [fs: SDA.UserPoolBase + 4], ecx
        mov DWORD [fs: SDA.UserPoolPhysicalBase], USER_POOL_PHYSICAL_BASE
        mov [fs: SDA.UserPoolPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.KernelPoolBase], KERNEL_POOL_BASE
        mov DWORD [fs: SDA.KernelPoolBase + 4], 0FFFFF800h
        mov DWORD [fs: SDA.KernelPoolPhysicalBase], KERNEL_POOL_PHYSICAL_BASE
        mov [fs: SDA.KernelPoolPhysicalBase + 4], ecx

        ;;
        ;; ��ʼ�� BTS Pool �� PEBS pool �����¼
        ;;
        mov edx, 0FFFFF800h
        mov ebx, [fs: SDA.Base]
        lea eax, [ebx + SDA.BtsBuffer]
        mov [fs: SDA.BtsPoolBase], eax                          ; BTS Pool ��ַ
        mov [fs: SDA.BtsPoolBase + 4], edx
        add eax, 0FFFh                                          ; 4K size
        mov DWORD [fs: SDA.BtsBufferSize], 100h                 ; ÿ�� BTS buffer Ĭ��Ϊ 100h 
        mov [fs: SDA.BtsPoolTop], eax                           ; BTS pool ����
        mov [fs: SDA.BtsPoolTop + 4], edx
        mov DWORD [fs: SDA.BtsRecordMaximum], 10                ; ÿ�� BTS buffer ������� 10 ����¼
        lea eax, [ebx + SDA.PebsBuffer]
        mov [fs: SDA.PebsPoolBase], eax                         ; PEBS Pool ��ַ
        mov [fs: SDA.PebsPoolBase + 4], edx
        add eax, 3FFFh                                          ; 16K size
        mov DWORD [fs: SDA.PebsBufferSize], 400h                ; ÿ�� PEBS buffer Ĭ��Ϊ 400h
        mov [fs: SDA.PebsPoolTop], eax                          ; PEBS pool ����
        mov [fs: SDA.PebsPoolTop + 4], edx
        mov DWORD [fs: SDA.PebsRecordMaximum], 5                ; ÿ�� Pebs buffer ������� 5 ����¼
        
        
        ;;
        ;; ��ʼ�� VM domain pool �����¼
        ;;
        mov DWORD [fs: SDA.DomainPhysicalBase], DOMAIN_PHYSICAL_BASE
        mov DWORD [fs: SDA.DomainPhysicalBase + 4], 0
        mov DWORD [fs: SDA.DomainBase], DOMAIN_BASE
        mov DWORD [fs: SDA.DomainBase + 4], 0FFFFF800h
        
        ;;
        ;; ��ʼ�� GPA ӳ���б�����¼
        ;;
        mov eax, SDA_BASE + SDA.GpaMappedList
        mov [fs: SDA.GmlBase], eax
        mov DWORD [fs: SDA.GmlBase + 4], 0FFFFF800h

%ifdef DEBUG_RECORD_ENABLE
        ;;
        ;; ��ʼ�� DRS �����¼
        ;; 1) DrsBase = DrsBuffer
        ;; 2) DrsHeadPtr = DrsTailPtr = DrsBuffer
        ;; 3) DrsIndex = DrsBuffer
        ;; 4) DrsCount = 0
        ;;
        mov eax, [fs: SDA.Base]
        lea eax, [eax + SDA.DrsBuffer]
        mov [fs: SDA.DrsBase], eax
        mov DWORD [fs: SDA.DrsBase + 4], 0FFFFF800h
        mov [fs: SDA.DrsHeadPtr], eax
        mov DWORD [fs: SDA.DrsHeadPtr + 4], 0FFFFF800h
        mov [fs: SDA.DrsTailPtr], eax
        mov DWORD [fs: SDA.DrsTailPtr + 4], 0FFFFF800h        
        mov [fs: SDA.DrsIndex], eax
        mov DWORD [fs: SDA.DrsIndex + 4], 0FFFFF800h
        mov DWORD [fs: SDA.DrsCount], 0
        add eax, MAX_DRS_COUNT * DRS_SIZE
        mov [fs: SDA.DrsTop], eax
        mov DWORD [fs: SDA.DrsTop + 4], 0FFFFF800h        
        mov DWORD [fs: SDA.DrsMaxCount], MAX_DRS_COUNT
        
        ;;
        ;; ��ʼ��ͷ�ڵ� PrevDrs �� NextDrs
        ;;
        mov edx, [fs: SDA.PhysicalBase]
        add edx, SDA.DrsBuffer
        xor eax, eax
        mov [edx + DRS.PrevDrs], eax
        mov [edx + DRS.PrevDrs + 4], eax
        mov [edx + DRS.NextDrs], eax
        mov [edx + DRS.NextDrs + 4], eax      
        mov DWORD [edx + DRS.RecordNumber], 0
%endif        
        

        ;;
        ;; ��ʼ�� DMB ��¼
        ;;
        mov eax, [fs: SDA.Base]
        add eax, SDA.DecodeManageBlock
        mov [fs: SDA.DmbBase], eax
        mov DWORD [fs: SDA.DmbBase + 4], 0FFFFF800h
        add eax, DMB.DecodeBuffer
        mov edx, [fs: SDA.PhysicalBase]
        mov [edx + SDA.DecodeManageBlock + DMB.DecodeBufferHead], eax
        mov [edx + SDA.DecodeManageBlock + DMB.DecodeBufferPtr], eax
        mov DWORD [edx + SDA.DecodeManageBlock + DMB.DecodeBufferHead + 4], 0FFFFF800h
        mov DWORD [edx + SDA.DecodeManageBlock + DMB.DecodeBufferPtr + 4], 0FFFFF800h        
        
        ;;
        ;; ��ʼ�� EXTINT_RTE �����¼
        ;;
        mov eax, [fs: SDA.Base]
        add eax, SDA.ExtIntRteBuffer
        mov [fs: SDA.ExtIntRtePtr], eax
        mov DWORD [fs: SDA.ExtIntRtePtr + 4], 0FFFFF800h
        mov [fs: SDA.ExtIntRteIndex], eax
        mov DWORD [fs: SDA.ExtIntRteIndex + 4], 0FFFFF800h
        mov DWORD [fs: SDA.ExtIntRteCount], 0
        
        ;;
        ;; ���� pic8259 ���쳣�������̣�ȱʡ���жϷ�������
        ;;
        call setup_pic8259
        call install_default_exception_handler
        call install_default_interrupt_handler        
                
        ;;
        ;; ���� AP �� startup routine ��ڵ�ַ
        ;;
        mov eax, ApStage1Entry
        mov [fs: SDA.ApStartupRoutineEntry], eax
        mov DWORD [fs: SDA.Stage1LockPointer], ApStage1Lock
        mov DWORD [fs: SDA.Stage2LockPointer], ApStage2Lock
        mov DWORD [fs: SDA.Stage3LockPointer], ApStage3Lock
        
        pop edx
        pop ecx
        ret
        




;-------------------------------------------------------------------
; alloc_pcb_base()
; input:
;       none
; output:
;       eax - PCB �����ַ
;       edx - PCB �����ַ
; ������
;       1) ÿ���������� PCB ��ַʹ�� alloc_pcb_base() ������
;       2) edx:eax - ���� PCB ��������ַ�Ͷ�Ӧ�������ַ
;       2) �� stage1��legacy ��δ��ҳ��ʹ��
;-------------------------------------------------------------------
alloc_pcb_base:
        push ebx
        mov ebx, PCB_SIZE
        mov edx, ebx
        xor esi, esi
        
        ;;
        ;; ִ��ԭ�� PcbPoolBase �� PCB_SIZE ����
        ;;
        lock xadd [fs: SDA.PcbPoolBase], edx
        lock xadd [fs: SDA.PcbPoolPhysicalBase], ebx

        ;;
        ;; ����Ƿ񳬳� Pool top
        ;; 1) ����ʱ���� 0 ֵ
        ;;
        cmp ebx, [fs: SDA.PcbPoolPhysicalTop]
        cmovge ebx, esi
        cmovge edx, esi
        
        ;;
        ;; ��� PCB ����
        ;;
        mov esi, PCB_SIZE
        mov edi, ebx
        call zero_memory
        mov eax, ebx                        
        pop ebx
        ret



;-------------------------------------------------------------------
; alloc_tss_base()
; input:
;       none
; output:
;       eax - Tss �������ַ
;       edx - Tss �������ַ
; ����:
;       1) �� TSS POOL �����һ�� TSS ��ռ�       
;       2) ��� TSS Pool ���꣬����ʧ�ܣ����� 0 ֵ
;       3) �� stage1 �׶ε���
;-------------------------------------------------------------------
alloc_tss_base:
        push ebx
        
        ;;
        ;; TSS �����˵����
        ;; 1) ͬʱ���� virtual base �� physical base
        ;; 2) ���� virtual address �� physical address ��Ӧ��ϵ
        ;;
        mov ebx, [fs: SDA.TssPoolGranularity]                   ; TSS ��������ȣ�Ĭ��Ϊ 100h �ֽڣ�
        mov edx, ebx       
        xor esi, esi
        
        ;;
        ;; ���� TSS ��
        ;;        
        lock xadd [fs: SDA.TssPoolBase], edx                    ; edx - va
        lock xadd [fs: SDA.TssPoolPhysicalBase], ebx            ; ebx - pa
        
        ;;
        ;; ����ʱ������ 0 ֵ
        ;;
        cmp ebx, [fs: SDA.TssPoolPhysicalTop]
        cmovae ebx, esi
        cmovae edx, esi

        ;;
        ;; �� TSS ��
        ;;
        mov edi, ebx
        mov esi, [fs: SDA.TssPoolGranularity]
        call zero_memory
        mov eax, ebx
        pop ebx
        ret
        


;-------------------------------------------------------------------
; alloc_stage1_kernel_stack_4k_physical_base()
; input:
;       none
; output:
;       eax - stack base
; ������
;       1) ���� stage1 �׶�ʹ�õ� kernel stack
;       2) ���������ַ
;-------------------------------------------------------------------
alloc_stage1_kernel_stack_4k_physical_base:
        mov eax, 4096
        lock xadd [fs: SDA.KernelStackPhysicalBase], eax        
        ret




;-------------------------------------------------------------------
; alloc_stage1_kernel_pool_base()
; input:
;       esi - ҳ����
; output:
;       eax - �����ַ
;       edx - �����ַ
; ������
;       1) �ڡ�stage1 �׶η���� kernel pool
;       2) ���������ַ
;-------------------------------------------------------------------
alloc_stage1_kernel_pool_base:
        push ecx
        lea ecx, [esi - 1]
        mov eax, 4096
        shl eax, cl
        mov edx, eax
        lock xadd [fs: SDA.KernelPoolBase], eax 
        lock xadd [fs: SDA.KernelPoolPhysicalBase], edx
        pop ecx
        ret
        
        

;-----------------------------------------------------------------------
; update_stage1_gs_segment()
; input:
;       none
; output:
;       none
; ����:
;       1) ���� stag1 �� GS �Σ���Ӧ�������� PCB ����
;-----------------------------------------------------------------------
update_stage1_gs_segment:
        push edx
        push ecx
        push ebx
        
        ;;
        ;; ���� PCB ��ַ
        ;;
        call alloc_pcb_base                             ; edx:eax = VA:PA
        mov ebx, eax                                    ; ebx = PCB �����ַ
        mov esi, edx                                    ; esi = PCB �����ַ
        xor edx, edx
        
        ;;
        ;; �������ַд�� GS base
        ;;
        mov ecx, IA32_GS_BASE
        wrmsr
        
        ;;
        ;; ���� PCB ������¼
        ;; 1) ��ַ�ĸ� 32 λʹ���� 64-bit ģʽ��
        ;;
        mov edx, 0FFFFF800h
        mov [gs: PCB.PhysicalBase], ebx
        mov [gs: PCB.Base], esi                         
        mov [gs: PCB.Base + 4], edx
        mov DWORD [gs: PCB.Size], PCB_SIZE
        mov eax, [fs: SDA.Base]
        mov [gs: PCB.SdaBase], eax                      ; ָ�� SDA ����
        mov [gs: PCB.SdaBase + 4], edx
        add eax, SRT.Base                               ; SRT �����ַ��λ�� SDA ֮��
        mov [gs: PCB.SrtBase], eax                      ; ָ�� System Service Routine Table ����    
        mov [gs: PCB.SrtBase + 4], edx
        mov eax, [fs: SDA.PhysicalBase]     
        mov [gs: PCB.SdaPhysicalBase], eax
        add eax, SRT.Base
        mov [gs: PCB.SrtPhysicalBase], eax

        ;;
        ;; ���� ReturnStackPointer
        ;;
        lea eax, [esi + PCB.ReturnStack]
        mov [gs: PCB.ReturnStackPointer], eax
        mov [gs: PCB.ReturnStackPointer + 4], edx
        
        ;;
        ;; ȱʡ�� TPR ����Ϊ 3
        ;;
        mov BYTE [gs: PCB.CurrentTpl], INT_LEVEL_THRESHOLD
        mov BYTE [gs: PCB.PrevTpl], 0
        

        ;;
        ;; ���� LDT ������Ϣ
        ;; ע�⣺
        ;; 1) LDT ��ʱΪ�գ�����ʹ�������ַ
        ;; 2) ��ַ�� 32 λʹ���� 64-bit ģʽ��
        ;;
        mov DWORD [gs: PCB.LdtBase], SDA_BASE + SDA.Ldt
        mov DWORD [gs: PCB.LdtBase + 4], 0FFFFF800h
        mov DWORD [gs: PCB.LdtTop], SDA_BASE + SDA.Ldt
        mov DWORD [gs: PCB.LdtTop + 4], 0FFFFF800h
        

        
        ;;
        ;; ���� context ����ָ��
        ;; 1) �� stage1 ʹ�������ַ
        ;;
        lea eax, [ebx + PCB.Context]
        mov [gs: PCB.ContextBase], eax
        lea eax, [ebx + PCB.XMMStateImage]
        mov [gs: PCB.XMMStateImageBase], eax

        ;;
        ;; ���䱾�ش洢��
        ;;
        mov esi, LSB_SIZE + 0FFFh
        shr esi, 12
        call alloc_stage1_kernel_pool_base                              ; edx:eax = PA:VA
        mov [gs: PCB.LsbBase], eax
        mov DWORD [gs: PCB.LsbBase + 4], 0FFFFF800h
        mov [gs: PCB.LsbPhysicalBase], edx
        mov DWORD [gs: PCB.LsbPhysicalBase + 4], 0        
        mov ecx, eax                                                    ; ecx = LSB
        
        ;;
        ;; ��� LSB ��
        ;;
        mov esi, LSB_SIZE
        mov edi, edx
        call zero_memory
                
        ;;
        ;; ���� LSB ������Ϣ
        ;;
        mov [edx + LSB.Base], ecx
        mov DWORD [edx + LSB.Base + 4], 0FFFFF800h                      ; LSB.Base
        mov [edx + LSB.PhysicalBase], edx
        mov DWORD [edx + LSB.PhysicalBase + 4], 0                       ; LSB.PhysicalBase
        
        ;;
        ;; local video buffer ��¼
        ;;
        lea esi, [ecx + LSB.LocalVideoBuffer]
        mov [edx + LSB.LocalVideoBufferHead], esi
        mov DWORD [edx + LSB.LocalVideoBufferHead + 4], 0FFFFF800h      ; LSB.LocalVideoBufferHead
        mov [edx + LSB.LocalVideoBufferPtr], esi
        mov DWORD [edx + LSB.LocalVideoBufferPtr + 4], 0FFFFF800h       ; LSB.LocalVideoBufferPtr
        
        ;;
        ;; local keyboard buffer ��¼
        ;;
        lea esi, [ecx + LSB.LocalKeyBuffer]
        mov [edx + LSB.LocalKeyBufferHead], esi
        mov DWORD [edx + LSB.LocalKeyBufferHead + 4], 0FFFFF800h        ; LSB.LocalKeyBufferHead
        mov [edx + LSB.LocalKeyBufferPtr], esi
        mov DWORD [edx + LSB.LocalKeyBufferPtr + 4], 0FFFFF800h         ; LSB.LocalKeyBufferPtr 
        mov DWORD [edx + LSB.LocalKeyBufferSize], 256                   ; LSB.LocalKeyBufferPtr = 256
               
        
        ;;
        ;; ���� VMCS ����ָ�루����ָ�룩
        ;; 1) VmcsA ָ�� GuestA
        ;; 2) VmcsB ָ�� GuestB
        ;; 3) VmcsC ָ�� GuestC
        ;; 4) VmcsD ָ�� GuestD
        ;;
        mov edx, 0FFFFF800h
        mov ecx, [gs: PCB.Base]
        lea eax, [ecx + PCB.GuestA]
        mov [gs: PCB.VmcsA], eax
        mov [gs: PCB.VmcsA + 4], edx
        lea eax, [ecx + PCB.GuestB]
        mov [gs: PCB.VmcsB], eax
        mov [gs: PCB.VmcsB + 4], edx        
        lea eax, [ecx + PCB.GuestC]
        mov [gs: PCB.VmcsC], eax
        mov [gs: PCB.VmcsC + 4], edx     
        lea eax, [ecx + PCB.GuestD]
        mov [gs: PCB.VmcsD], eax
        mov [gs: PCB.VmcsD + 4], edx                             
        
        ;;
        ;; ���� GS selector
        ;;
        mov WORD [gs: PCB.GsSelector], GsSelector
        
        ;;
        ;; ���´�����״̬��Ϣ
        ;; 
        mov eax, CPU_STATUS_PE
        or DWORD [gs: PCB.ProcessorStatus], eax
                
        pop ebx
        pop ecx
        pop edx
        ret






;-----------------------------------------------------------------------
; update_stage1_selector()
; input:
;       none
; output:
;       none
; ������
;       1) ���� stage1 ��selector����δ��ҳ�µı���ģʽ��
;-----------------------------------------------------------------------
update_stage1_selector:
        mov ax, [fs: SDA.FsSelector]
        mov fs, ax
        mov ax, [fs: SDA.KernelSsSelector]
        mov ds, ax
        mov es, ax
        mov ss, ax
        pop eax
        movzx esi, WORD [fs: SDA.KernelCsSelector]
        push esi
        push eax
        retf



;-----------------------------------------------------------------------
; build_stage1_tss()
; input:
;       none
; output:
;       none
; ������
;       1) ���� TSS ������������ TR
;       2) �� stage1��δ��ҳ�£�ʹ�ã���ʱ TSS ʹ�������ַ
;-----------------------------------------------------------------------
build_stage1_tss:
        push ebx
        push edx
        push ecx
        
        ;;
        ;; ����һ�� TSS ��
        ;;
        call alloc_tss_base                             ; edx:eax ���� VA:PA 
        test eax, eax
        jz build_stage1_tss.done
        
        ;;
        ;; ���� TSS ������Ϣ
        ;; 1) ��ַ�еĸ� 32 λ��ʹ���� 64-bit ģʽ��
        ;; 2) TSS limit = 1000h (TSS���� + IO bitmap ����)
        ;;
        mov [gs: PCB.TssPhysicalBase], eax
        mov DWORD [gs: PCB.TssPhysicalBase + 4], 0
        mov [gs: PCB.TssBase], edx
        mov DWORD [gs: PCB.TssBase + 4], 0FFFFF800h
        mov DWORD [gs: PCB.TssLimit], (1000h + 2000h - 1)
        mov DWORD [gs: PCB.IomapBase], SDA_BASE + SDA.Iomap
        mov DWORD [gs: PCB.IomapBase + 4], 0FFFFF800h
        mov DWORD [gs: PCB.IomapPhysicalBase], SDA_PHYSICAL_BASE + SDA.Iomap        
                       
        ;;
        ;; ��� TSS ������
        ;; 1) ����ʹ�� TSS �����ַ
        ;;
        mov ecx, eax
        and eax, 00FFFFFFh
        xor edx, edx
        shld edx, eax, 16
        shl eax, 16
        or eax, (1000h + 2000h - 1)
        and ecx, 0FF000000h
        or ecx, 00008900h                       ; 32-bit TSS, available
        or edx, ecx
        call append_gdt_descriptor

        ;;
        ;; ���� current Tss ��¼
        ;;
        mov [gs: PCB.TssSelector], ax
        
        ;;
        ;; ע�⣬Ϊ����Ӧ�� 64-bit ������
        ;; 1) ����Ҫ���� longmode ʱ����Ҫ��������һ���յ� GDT ������ ��
        ;;
        cmp DWORD [fs: SDA.ApLongmode], 1
        jne build_stage1_tss.@0
        xor eax, eax
        xor edx, edx
        call append_gdt_descriptor
        
build_stage1_tss.@0:
        
        ;;
        ;; ���� TSS ����
        ;;
        mov ebx, [gs: PCB.TssPhysicalBase]
        mov ax, [fs: SDA.KernelCsSelector]
        mov [ebx + tss32.ss0], ax
        
        ;;
        ;; ����һ�� kernel ʹ�õ� stack����Ϊ�жϷ�������ʹ��
        ;;
        call alloc_stage1_kernel_stack_4k_physical_base
        add eax, 0FF0h                                          ; ������ stack ����
        mov [ebx + tss32.esp0], eax
        
        ;;
        ;; ���� IOmap ��ַ
        ;;
        mov eax, SDA_PHYSICAL_BASE + SDA.Iomap
        sub eax, [gs: PCB.TssPhysicalBase]
        mov [ebx + tss32.IomapBase], ax                         ; Iomap ƫ����

       
        ;;
        ;; ���� TSS ��
        ;;
        mov ax, [gs: PCB.TssSelector]
        ltr ax
        
build_stage1_tss.done:    
        pop ecx
        pop edx
        pop ebx
        ret




;-----------------------------------------------------------------------
; install_default_exception_handler()
; input:
;       none
; output:
;       none
; ������
;       1) ��װĬ�ϵ��쳣��������
;-----------------------------------------------------------------------
install_default_exception_handler:
        push ecx
        xor ecx, ecx
install_default_exception_handler.loop:        
        mov esi, ecx
        mov edi, [ExceptionHandlerTable + ecx * 8]
        call install_kernel_interrupt_handler32
        inc ecx
        cmp ecx, 20
        jb install_default_exception_handler.loop
        pop ecx
        ret
        
        
        
;-----------------------------------------------------
; local_interrupt_default_handler()
; ������
;       �������� local �ж�Դȱʡ��������
;-----------------------------------------------------
local_interrupt_default_handler:
        push ebp
        push eax
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        test DWORD [ebp + PCB.ProcessorStatus], CPU_STATUS_PG
        REX.Wrxb
        mov eax, [ebp + PCB.LapicBase]
        REX.Wrxb
        cmovz eax, [ebp + PCB.LapicPhysicalBase]
        mov DWORD [eax + ESR], 0
        mov DWORD [eax + EOI], 0
        pop eax
        pop ebp
        REX.Wrxb
        iret        



;-----------------------------------------------------
; install_default_interrupt_handler()
; ����:
;       ��װĬ�ϵ��жϷ�������
;-----------------------------------------------------
install_default_interrupt_handler:
        push ecx
        xor ecx, ecx
        
        ;;
        ;; ˵��:
        ;; 1) ��װ local vector table ��������
        ;; 2) ��װ IPI ��������
        ;; 3) ��װϵͳ��������(40h �жϵ��ã�
        ;;
     
        ;;
        ;; ��װȱʡ�� local �ж�Դ��������
        ;;
        call install_default_local_interrupt_handler

        ;;
        ;; PIC8259 ��Ӧ���жϷ�������
        ;;
        mov esi, PIC8259A_IRQ0_VECTOR
        mov edi, timer_8259_handler
        call install_kernel_interrupt_handler32

        mov esi, PIC8259A_IRQ1_VECTOR
        mov edi, keyboard_8259_handler
        call install_kernel_interrupt_handler32

%if 0
        call init_ioapic_keyboard
%endif

        ;;
        ;; ���� IRQ1 �жϷ�������
        ;;
        mov esi, IOAPIC_IRQ1_VECTOR
        mov edi, ioapic_keyboard_handler
        call install_kernel_interrupt_handler32

        
        ;;
        ;; ��װ IPI ��������
        ;;       
        mov esi, IPI_VECTOR
        mov edi, dispatch_routine
        call install_kernel_interrupt_handler32
        
        mov esi, IPI_ENTRY_VECTOR
        mov edi, goto_entry
        call install_kernel_interrupt_handler32

        ;;
        ;; ��װϵͳ���÷�������
        ;;
        mov esi, [fs: SRT.ServiceRoutineVector]
        mov edi, sys_service_routine
        call install_user_interrupt_handler32

        pop ecx
        ret
         


;-----------------------------------------------------
; install_default_local_interrupt_handler()
; ������
;       ��װȱʡ local interrupt
;-----------------------------------------------------
install_default_local_interrupt_handler:
        mov esi, LAPIC_PERFMON_VECTOR
        mov edi, local_interrupt_default_handler
        call install_kernel_interrupt_handler32
        
        mov esi, LAPIC_TIMER_VECTOR
        mov edi, local_interrupt_default_handler
        call install_kernel_interrupt_handler32
        
        mov esi, LAPIC_ERROR_VECTOR
        mov edi, local_interrupt_default_handler
        call install_kernel_interrupt_handler32       
        ret




        

;-----------------------------------------------------
; wait_for_ap_stage1_done()
; input:
;       none
; output:
;       none
; ������
;       1) ���� INIT-SIPI-SIPI ��Ϣ��� AP
;       2) �ȴ� AP ��ɵ�1�׶ι���
;-----------------------------------------------------
wait_for_ap_stage1_done:
        push ebx
        push edx
        
        ;;
        ;; local APIC ��1�׶�ʹ�������ַ
        ;;
        mov ebx, [gs: PCB.LapicPhysicalBase]
        
        ;;
        ;; ���� IPIs��ʹ�� INIT-SIPI-SIPI ����
        ;; 1) �� SDA.ApStartupRoutineEntry ��ȡ startup routine ��ַ
        ;;      
        mov DWORD [ebx + ICR0], 000c4500h                       ; ���� INIT IPI, ʹ���� processor ִ�� INIT
        mov esi, 10 * 1000                                      ; ��ʱ 10ms
        call delay_with_us
        
        ;;
        ;; ���淢������ SIPI��ÿ����ʱ 200us
        ;; 1) ��ȡ Ap Startup Routine ��ַ
        ;;
        mov edx, [fs: SDA.ApStartupRoutineEntry]
        shr edx, 12                                             ; 4K �߽�
        and edx, 0FFh
        or edx, 000C4600h                                       ; Start-up IPI
        ;;
        ;; �״η��� SIPI
        ;;
        mov DWORD [ebx + ICR0], edx                             ; ���� Start-up IPI
        mov esi, 200                                            ; ��ʱ 200us
        call delay_with_us
        
        ;;
        ;; �ٴη��� SIPI
        ;;
        mov DWORD [ebx + ICR0], edx                             ; �ٴη��� Start-up IPI
        mov esi, 200
        call delay_with_us

        ;;
        ;; ���ŵ�1�׶� AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage1LockPointer]
        xchg [ebx], eax
                      
        ;;
        ;; �ȴ� AP ��� stage1 ����:
        ;; ��鴦�������� ProcessorCount �Ƿ���� LocalProcessorCount ֵ
        ;; 1)�ǣ����� AP ��� stage1 ����
        ;; 2)���ڵȴ�
        ;;
wait_for_ap_stage1_done.@0:        
        mov eax, [fs: SDA.ApInitDoneCount]
        cmp eax, [gs: PCB.LogicalProcessorCount]
        jb wait_for_ap_stage1_done.@0
         
        pop edx
        pop ebx
        ret
        

        