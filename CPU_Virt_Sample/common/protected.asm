;*************************************************
; protected.asm                                  *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


%include "..\inc\support.inc"
%include "..\inc\protected.inc"


        org PROTECTED_SEGMENT

        DD      PROTECTED_LENGTH                        ; ����ģ�鳤��
        DD      BspProtectedEntry                       ; BSP �� protected ģ�����
        DD      ApStage2Routine                         ; AP �� protected ģ�����
        
        
        bits 32        
        
BspProtectedEntry:
        ;;
        ;; ��ʼ�� stage2 �׶ε� paging ����
        ;; 1) ʹ�� PAE ��ҳ�ṹ
        ;;
        call init_ppt_area
        call init_pae_page
        
        ;;
        ;; ���� stage2 �� GDT/IDT pointer ֵ
        ;;
        call update_stage2_gdt_idt_pointer
        
ApProtectedEntry:  
        ;;
        ;; ӳ�� stage2 �׶ε� PCB ����
        ;;
        call map_stage2_pcb

        ;;
        ;; ���� stage2 �� kernel stack
        ;; 1) ��Ҫ������ҳǰ������ FS ��ǰִ��
        ;; 2) ��������� kernel stack ������ PCB.KernelStack ��        
        ;;
        call update_stage2_kernel_stack
        
        ;;
        ;; �� FS/GS base ֵ
        ;;
        mov esi, [fs: SDA.Base]
        mov edi, [gs: PCB.Base]

        ;;
        ;; ���� PPT ��
        ;;
        mov eax, [fs: SDA.PptPhysicalBase]
        mov cr3, eax

        ;;
        ;; ���� paging ����
        ;;
        mov eax, cr0
        bts eax, 31
        mov cr0, eax 
        
        ;;
        ;; ���� fs �� gs ��Ϊ���� paging ��� base ֵ
        ;;
        xor edx, edx
        mov eax, esi
        mov ecx, IA32_FS_BASE     
        wrmsr
        mov eax, edi
        mov ecx, IA32_GS_BASE
        wrmsr

        ;;
        ;; ���´�����״̬
        ;;
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_PG | CPU_STATUS_PE
        
        ;;
        ;; ���� kernel stack
        ;;
        mov esp, [gs: PCB.KernelStack]
        
        ;;
        ;; ���¼��� GDTR/IDTR �Լ� TR
        ;;
        lgdt [fs: SDA.GdtPointer]
        lidt [fs: SDA.IdtPointer]
        ;;
        ;; ���� TSS ���������� legacy ģʽ�������� TSS ����
        ;;
        call update_stage2_tss        
        
        ;;
        ;; ���� user stack pointer
        ;;
        call get_user_stack_4k_pointer
        mov [gs: PCB.UserStack], eax
        
        
        ;;
        ;; ���� SYSENTER/SYSEXIT ʹ�û���
        ;;
        call setup_sysenter
               
        ;;
        ;; ��ʼ�������� debug store ��Ԫ
        ;;
        call init_debug_store_unit
        


%ifndef DBG
        ;;
        ;; Stage2 �׶������������Ƿ�Ϊ BSP
        ;; 1) �ǣ��ȴ����� AP ��� stage2 ����
        ;; 2) ��ת��ApStage3End
        ;;
        cmp BYTE [gs: PCB.IsBsp], 1
        jne ApStage2End

        call init_sys_service_call


        ;;
        ;; �ȴ����� AP ��2�׶ι������
        ;;
        call wait_for_ap_stage2_done
        

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
        mov ebx, [gs: PCB.LsbBase]
        mov eax, [ebx + LSB.LocalKeyBufferHead]
        mov [fs: SDA.KeyBufferHead], eax
        lea eax, [ebx + LSB.LocalKeyBufferPtr]
        mov [fs: SDA.KeyBufferPtrPointer], eax
        mov eax, [ebx + LSB.LocalKeyBufferSize]
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
        
        bits 32
        
        ;;
        ;; Ƕ��ʵ�����Ӵ��룬�� ex.asm �ļ���ʵ��
        ;;
        %include "ex.asm"





                                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;              User ����               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                                
; ���� ring 3 ����
        movzx eax, WORD [fs: SDA.UserSsSelector]
        or eax, 3
        push eax
        push DWORD [gs: PCB.UserStack]
        movzx eax, WORD [fs: SDA.UserCsSelector]
        or eax, 3
        push eax
        push DWORD user_entry
        retf

        
;; �û�����
user_entry:
        mov ax, UserSsSelector32
        mov ds, ax
        mov es, ax
user_start:
        hlt
        jmp $ - 1





;********************************************************
;*      !!!  AP ������ protected ģ����� !!!           *
;********************************************************

ApStage2Routine:
        jmp ApProtectedEntry
        
       
ApStage2End:

%ifdef TRACE
        mov esi, Stage2.Msg
        call puts
%endif


        
        ;;
        ;; ���� ApInitDoneCount ����
        ;;
        lock inc DWORD [fs: SDA.ApInitDoneCount]
        
        ;;
        ;; ���ŵ�2�׶� AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage2LockPointer]
        xchg [ebx], eax
 
        ;;
        ;; ���� UsableProcessMask ֵ��ָʾ logical processor ���ڿ���״̬
        ;;
        mov eax, [gs: PCB.ProcessorIndex]                       ; ������ index 
        lock bts DWORD [fs: SDA.UsableProcessorMask], eax       ; �� Mask λ

        ;;
        ;; �����������뵽 VMX root ģʽ
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
        ;; AP ��2�׶ε����չ����ǣ����� HLT ״̬
        ;;
        sti
        hlt
        jmp $ - 1







        bits 32


;********* include ģ�� ********************
%include "..\lib\crt.asm"
%include "..\lib\LocalVideo.asm"
%include "..\lib\system_data_manage.asm"
%include "..\lib\services.asm"
%include "..\lib\pci.asm"
%include "..\lib\apic.asm"
%include "..\lib\ioapic.asm"
%include "..\lib\debug.asm"
%include "..\lib\perfmon.asm"
%include "..\lib\mem.asm"
%include "..\lib\page32.asm"
%include "..\lib\pic8259A.asm"
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
%include "..\lib\smp.asm"
%include "..\lib\DebugRecord.asm"
%include "..\lib\stage2.asm"
%include "..\lib\dump\dump_apic.asm"
%include "..\lib\data.asm"
%include "..\lib\Decode\Decode.asm"


;;
;; ģ�鳤��
;;
PROTECTED_LENGTH        EQU     $ - $$


;; end of protected.asm