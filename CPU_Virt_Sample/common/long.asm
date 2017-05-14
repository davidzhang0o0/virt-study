;*************************************************
; long.asm                                       *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


;;
;; ��δ��뽫�л��� long mode ����
;;

%include "..\inc\support.inc"
%include "..\inc\protected.inc"
%include "..\inc\services.inc"
%include "..\inc\system_manage_region.inc"


        
        org LONG_SEGMENT
        
        DD      LONG_LENGTH                             ; long ģ�鳤��
        DD      BspLongEntry                            ; BSP ��ڵ�ַ
        DD      ApStage3Routine                         ; AP ��ڵ�ַ


        ;;
        ;; ˵����
        ;; 1) ��ʱ������������ stage1 �׶Σ�����δ��ҳ����ģʽ��
        ;; 2) stage3 �׶ν��л��� longmode         
        ;;
        bits 32        
        
BspLongEntry:               
        ;;
        ;; ���� longmode ǰ׼������, ��ʼ�� stage3 �׶εĻ���ҳ��ṹ
        ;; ������
        ;;      1) compatibility ģʽ������������: LONG_SEGMENT
        ;;      2) setup ģ����������SETUP_SEGMENT
        ;;      3) 64-bit ������������: ffff_ff80_4000_0000h
        ;;      4) video ����b_8000h                
        ;;      5) SDA ����ӳ�䵽��ffff_f800_8002_0000h
        ;;      6) ӳ��ҳ��� PT Pool �ͱ��� PT Pool ����
        ;;      7) LAPIC �� IAPIC ��ַ������logical processor ��ַһ�£�
        ;;
        call init_longmode_basic_page32
        
        ;;
        ;; ���� stage3 �׶ε� GDT/IDT pointer 
        ;;
        call update_stage3_gdt_idt_pointer
        
ApLongEntry:                     
        ;;
        ;; ӳ�� stage3 �׶ε� PCB ����
        ;;
        call map_stage3_pcb

        ;;
        ;; ���� stage3 �� kernel stack
        ;; 1) ��Ҫ������ҳǰ������ FS ��ǰִ��
        ;; 2) ��������� kernel stack ������ PCB.KernelStack ��
        ;;        
        call update_stage3_kernel_stack        

        ;;
        ;; �� GS base ֵ���Ա���һ������
        ;;
        mov esi, [gs: PCB.Base]
        mov edi, [gs: PCB.Base + 4]

        ;;
        ;; ���� longmode �µ� PXT ��
        ;;
        mov eax, [fs: SDA.PxtPhysicalBase64]
        mov cr3, eax

        ;;
        ;; ���� long-mode ǰ�ȸ��� GS.selector
        ;;
        mov ax, [gs: PCB.GsSelector]
        mov gs, ax

        ;;
        ;; ���潫�л��� longmode !
        ;; ˵����
        ;; 1) longmode_enter() �������л��� 64-bit ģʽ
        ;; 2) longmode_enter() ���غ��� 64-bit ��ִ�л���
        ;; 3) ���� GS base 
        ;; 4) ��Ҫ��һ�����к����� longmode ������ʼ��
        ;;

        ;;
        ;; ���� EFER �Ĵ��������� long mode
        ;;
        mov ecx, IA32_EFER
        rdmsr 
        bts eax, 8                                      ; EFER.LME = 1
        wrmsr

        ;;
        ;; ���� long mode������ compatibility ģʽ
        ;;
        mov eax, cr0
        bts eax, 31
        mov cr0, eax                                    ; EFER.LMA = 1   
                                

        ;;
        ;; ת�� 64-bit ģʽ
        ;;
        jmp KernelCsSelector64 : ($ + 7)
        


        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;  ������ 64-bit ����  ;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        bits 64
    
        ;;
        ;; ���� FS/GS ��
        ;;  
        mov eax, SDA_BASE
        mov edx, 0FFFFF800h
        mov ecx, IA32_FS_BASE
        wrmsr
        mov eax, esi
        mov edx, edi
        mov ecx, IA32_GS_BASE
        wrmsr
        
        ;;
        ;; ˢ�� segment selector �� cache ����
        ;;
        mov ax, KernelSsSelector64
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov rsp, [gs: PCB.KernelStack] 
        
        ;;
        ;; ���´�����״̬
        ;;
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_PG | CPU_STATUS_LONG | CPU_STATUS_64
        

                
        ;;
        ;; ˢ�� GDTR/IDTR
        ;;
        lgdt [fs: SDA.GdtPointer]
        lidt [fs: SDA.IdtPointer]

        ;;
        ;; ���� TSS ����
        ;;
        call update_stage3_tss
        
        ;;
        ;; ��װȱʡ�жϴ������
        ;;
        call install_default_interrupt_handler
        
        ;;
        ;; ���� GS ����Ϣ
        ;;
        call update_stage3_gs_segment

        ;;
        ;; ���� SYSENTER/SYSEXIT ʹ�û���
        ;;
        call setup_sysenter
                       
        
%ifndef DBG               
        ;;
        ;; stage3 �׶������������Ƿ�Ϊ BSP        
        ;; 1) �ǣ���ȴ� AP ��� stage3 �׶ι����������ȴ����� AP ����л��� long mode��
        ;; 2) ����ת�� ApStage3End
        ;;
        cmp BYTE [gs: PCB.IsBsp], 1
        jne ApStage3End
        
        call init_sys_service_call

        ;;
        ;; �ȴ����� AP ��� stage3 �׶ι���
        ;;
        call wait_for_ap_stage3_done

        ;;
        ;; �����������뵽 VMX root ģʽ
        ;;        
        call vmx_operation_enter

%endif
        ;;
        ;; ��ǰ������ӵ�н���
        ;;         
        mov eax, [gs: PCB.ProcessorIndex] 
        mov [fs: SDA.InFocus], eax

        ;;
        ;; ���� SDA.KeyBuffer ��¼
        ;;        
        mov rbx, [gs: PCB.LsbBase]
        mov rax, [rbx + LSB.LocalKeyBufferHead]
        mov [fs: SDA.KeyBufferHead], rax
        lea rax, [rbx + LSB.LocalKeyBufferPtr]
        mov [fs: SDA.KeyBufferPtrPointer], rax
        mov eax, [rbx + LSB.LocalKeyBufferSize]
        mov [fs: SDA.KeyBufferLength], eax
        
                        
        ;;
        ;; �򿪼���
        ;;
        call enable_8259_keyboard

        sti
        NMI_ENABLE
                        
        ;;
        ;; ����ϵͳ״̬
        ;;
        call update_system_status    
        
        
        
;;============================================================================;;
;;                      ���д�������ʼ�����                                   ;;
;;============================================================================;;

        bits 64
        
        ;;
        ;; ������ʵ�����ӵ�Դ����
        ;;        
        %include "ex.asm"
        

       ;;
       ;; �ȴ�����
       ;;
        call wait_esc_for_reset
        





;;
;; ������ APs �� pre-stage3 ���
;; ˵����
;;      1) ÿ�� AP �� stage2 �׶����Ҫ�ȴ� stage3 lock ��Ч����������
;;      2) ApStage3Routine ��ת�� ApLongEntry ִ������ APs ����
;;
        
        
        bits 32

ApStage3Routine:        

%ifdef TRACE
        mov esi, Stage3.Msg
        call puts
%endif        
        jmp ApLongEntry






;;
;; ������ APs �� stage3 �׶ε������
;; ˵����
;       1) ���Ӵ���������
;;      2) ���� stage3 lock������������ APs ����ִ��
;;      3) �� AP ���� HLT ״̬
;;

        bits 64

ApStage3End:        
        
%ifdef TRACE
        mov esi, Stage3.Msg1
        call puts
%endif        


        ;;
        ;; ������ɼ���
        ;;
        lock inc DWORD [fs: SDA.ApInitDoneCount]      
          
        ;;
        ;; 1) ���� stage3 ������������ AP ���� stage3
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage3LockPointer]        
        xchg [rbx], eax

        ;;
        ;; ���� UsableProcessMask ֵ��ָʾ logical processor ���ڿ���״̬
        ;;
        mov eax, [gs: PCB.ProcessorIndex]                       ; ������ index 
        lock bts DWORD [fs: SDA.UsableProcessorMask], eax       ; �� Mask λ
                        
        ;;
        ;; ���� VMX operation ģʽ
        ;;
        call vmx_operation_enter
        
        ;;
        ;; ����ϵͳ״̬
        ;;
        call update_system_status

        ;;
        ;; ��¼�������� HLT ״̬
        ;;
        mov DWORD [gs: PCB.ActivityState], CPU_STATE_HLT
        
       
        ;;
        ;; AP ���� stage3 �׶�����״̬�� HLT ״̬
        ;;
        sti
                
        hlt
        jmp $-1
        



        bits 32
        
%include "..\lib\crt.asm"
%include "..\lib\LocalVideo.asm"
%include "..\lib\mem.asm"
%include "..\lib\page32.asm"
%include "..\lib\system_data_manage.asm"
%include "..\lib\apic.asm"
%include "..\lib\ioapic.asm"
%include "..\lib\pci.asm"
%include "..\lib\pic8259a.asm"
%include "..\lib\services.asm"
%include "..\lib\Decode\Decode.asm"
%include "..\lib\Vmx\VmxInit.asm"
%include "..\lib\Vmx\Vmx.asm"
%include "..\lib\Vmx\VmxException.asm"
%include "..\lib\Vmx\VmxVmcs.asm"
%include "..\lib\Vmx\VmxDump.asm"
%include "..\lib\Vmx\VmxLib.asm"
%include "..\lib\Vmx\VmxPage.asm"
%include "..\lib\Vmx\VmxVMM.asm"
%include "..\lib\Vmx\VmxExit.asm"
%include "..\lib\Vmx\VmxMsr.asm"
%include "..\lib\Vmx\VmxIo.asm"
%include "..\lib\Vmx\VmxApic.asm"
%include "..\lib\DebugRecord.asm"
%include "..\lib\smp.asm"
%include "..\lib\dump\dump_apic.asm"
%include "..\lib\dump\dump_debug.asm"
%include "..\lib\stage3.asm"



        bits 64
;;
;; *** include ���� 64 λ�� *****
;;
%include "..\lib\crt64.asm"
%include "..\lib\page64.asm"
%include "..\lib\services64.asm"
%include "..\lib\smp64.asm"
%include "..\lib\Vmx\VmxPage64.asm"


;;
;; ����
;;
%include "..\lib\data.asm"



LONG_LENGTH     EQU     $ - $$
                