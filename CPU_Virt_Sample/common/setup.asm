;*************************************************
; setup.asm                                      *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


;;
;; ��� setup ģʽ�ǹ��õģ����� ..\common\ Ŀ¼��
;; ����д����̵ĵ� 1 ������ ��
;;

%include "..\inc\support.inc"
%include "..\inc\protected.inc"
%include "..\inc\system_manage_region.inc"
%include "..\inc\apic.inc"


;;
;; ˵����
;; 1) ģ�鿪ʼ���� SETUP_SEGMENT
;; 2) ģ��ͷ�Ĵ���ǡ�ģ�� size��
;; 3) load_module() ������ģ����ص� SETUP_SEGMENT λ����
;; 4) SETUP ģ��ġ���ڵ㡱�ǣ�SETUP_SEGMENT + 4
        
        [SECTION .text]
        org SETUP_SEGMENT


       
;
;; ��ģ��Ŀ�ͷ dword ��С����������ģ��Ĵ�С��
;; load_module �������� size ����ģ�鵽�ڴ�
;;

        DD SETUP_LENGTH                                 ; ���ģ��� size

    
;;
;; ģ�鵱ǰ������ 16 λʵģʽ��
;;
        bits 16
        
SetupEntry:                                             ; ����ģ��������ڵ㡣

        cli
        NMI_DISABLE
        

        ;;
        ;; ��ʵģʽ�¶�ȡϵͳ���������ڴ�
        ;;
        call get_system_memory
 
        ;;
        ;; �л��� big-real ģʽ������ 32 λʵģʽ״̬������ 4G ����
        ;; 1) ���� unreal_mode_enter() ���� big-real ״̬
        ;;
        ;call unreal_mode_enter

        ;;
        ;; ���ģ�
        ;; 1) ��Ϊ���� protected_mode_enter() ֱ�ӽ��뱣��ģʽ
        ;;       
        call protected_mode_enter
                
     
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;; ������ 32 λ���� ;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
                bits 32

        ;;
        ;; ͨ���������� long-mode ֧�ּ��
        ;; ������ʾ������Ϣ������ HLT ״̬
        ;;                 
        call pass_the_check_longmode
        
    
        ;;
        ;; ����������ݵĳ�ʼ������:
        ;; 1) ���ȣ���ʼ�� SDA��System Data Area����������
        ;; 2) Ȼ�󣬳�ʼ�� PCB��Processor Control Block����������
        ;;
        ;; ˵��:
        ;; 1) SDA ���������д������������Ա����ȳ�ʼ��
        ;; 2) PCB ������ logical processor ���ݣ���֧�� 16 �� PCB ��
        ;; 3) PCB �����Ƕ�̬���䣬ÿ�� PCB ���ַ��ͬ
        ;; 
        ;;
        ;; fs ��˵����
        ;;      1) fs ָ�� SDA��System Data Area������������ logical processor �������������
        ;; ע�⣺
        ;;      1) ��Ҫ��֧�� 64 λ�Ĵ������ϲ���ֱ��д IA_FS_BASE �Ĵ�����
        ;;      2) ������Ҫ��������ģʽ������ FS �λ�ַ
        ;;      3) GS �λ�ַ�ں��������и���
        ;;        
        
        call init_system_data_area

PcbInitEntry:
        ;;
        ;; ���� PCB��Processor Control Block������
        ;; ˵����
        ;; 1) �˴�Ϊ logical processor �� PCB ��ʼ����ڣ����� BSP �� AP��
        ;; 2) ÿ�� logical processor ����Ҫ��������� PCB ���ݳ�ʼ��
        ;; 
        
        ;;
        ;; ���� update_stage1_gs_segment() ���� GS ����Ϣ
        ;; ע�⣺
        ;; 1) �Ȼ�� PCB �����ַд�� GS ��
        ;; 2) �ٷ��� PCB �����ַ
        ;; 3) ���ӳ�� stage1 �׶� PCB
        ;;
        call update_stage1_gs_segment

        ;;
        ;; ����һ�� stage1 �׶�ʹ�õ� kernel stack����ʱʹ�������ַ
        ;; 1) �轫 stack pointer ���� 4k base ֵ�Ķ���
        ;;
        call alloc_stage1_kernel_stack_4k_physical_base
        add eax, 0FF0h
        mov esp, eax
        

        ;;
        ;; ���� GDTR �� IDTR
        ;;
        lgdt [fs: SDA.GdtPointer]
        lidt [fs: SDA.IdtPointer]
          

        ;;
        ;; ���� selector
        ;;
        call update_stage1_selector
        
        ;;
        ;; ���� TSS ����
        ;; 1) ��ʱ TSS ����ʹ�������ַ
        ;;
        call build_stage1_tss
       

        ;;
        ;; ���� local APIC
        ;;
        call pass_the_enable_apic

        ;;
        ;; ���´�������Ϣ
        ;;
        call update_processor_basic_info
        call update_processor_topology_info
        call update_debug_capabilities_info
        call init_memory_type_manage
        call init_perfmon_unit

%ifndef DBG
        ;;
        ;; Stage1 �׶������������Ƿ�Ϊ BSP
        ;; 1) �ǣ����� INIT-SIPI-SIPI ����
        ;; 2) ����ȴ����� SIPI 
        ;;
        cmp BYTE [gs: PCB.IsBsp], 1
        jne ApStage1End
          
        ;;
        ;; ���� BSP ��1�׶ε��������
        ;; 1) ���� INIT-SIPI-SIPI ���и� AP 
        ;; 2) �ȴ����� AP ��1�׶����
        ;; 3) ת���½׶ι���
        ;;
        call wait_for_ap_stage1_done

        ;;
        ;; �� ApInitDoneCount = 1��Ϊ��һ�׶μ�����׼��
        ;;
        mov DWORD [fs: SDA.ApInitDoneCount], 1
        
%endif         
        ;;
        ;; ����Ƿ���Ҫ���� longmode
        ;; 1) �ǣ����� stage2, ���� stage3 �׶Σ�longmode ģʽ��
        ;; 2) �񣬽��� stage2 �׶�
        ;;
        cmp DWORD [fs: SDA.ApLongmode], 1
        mov eax, [PROTECTED_SEGMENT + 4]
        cmove eax, [LONG_SEGMENT + 4]

        ;;
        ;; ת���½׶����
        ;; 
        jmp eax


%ifndef DBG      
              
        ;;
        ;; AP��1�׶������˵����
        ;; 1) ���� ApInitDoneCount ����ֵ
        ;; 1) AP �ȴ���2�׶������ȴ� BSP ���� stage2 ����
        ;;
        
ApStage1End:  

%ifdef TRACE
        mov esi, Stage1.Msg
        call puts       
%endif        
  
        ;;
        ;; ������ɼ���
        ;;
        lock inc DWORD [fs: SDA.ApInitDoneCount]
        ;;
        ;; ���ŵ�1�׶� AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage1LockPointer]
        xchg [ebx], eax

        ;;
        ;; ����Ƿ���Ҫ���� longmode
        ;; 1) �ǣ����� stage2, �ȴ� stage3 �������� stage3 �׶Σ�longmode ģʽ��
        ;; 2) �񣬵ȴ� stage2 �������� stage2 �׶�
        ;;
        cmp DWORD [fs: SDA.ApLongmode], 1
        je ApStage1End.WaitStage3
        ;;
        ;; ���ڵȴ� stage2 ��������
        ;;
        mov esi, [fs: SDA.Stage2LockPointer]
        call get_spin_lock
        ;;
        ;; ���� stage2
        ;;
        jmp [PROTECTED_SEGMENT + 8]
        
ApStage1End.WaitStage3:
        ;;
        ;; ���ڵȴ� stage3 ������
        ;;
        mov esi, [fs: SDA.Stage3LockPointer]
        call get_spin_lock                
        ;;
        ;; ���� stage3
        ;; 
        jmp [LONG_SEGMENT + 8]


%endif

    

;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
;$      AP Stage1 Startup Routine       $
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$


        bits 16

times 4096 - ($ - $$)   DB      0


ApStage1Entry:

        cli
        
        ;;
        ;; real mode ��ʼ����
        ;;
        xor ax, ax
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, 7FF0h

       
        ;;
        ;; ��� ApLock���Ƿ����� AP ���� startup routine ִ��
        ;;
        xor eax, eax
        mov esi, 1
        
        ;;
        ;; ���������
        ;;
AcquireApStage1Lock:
        ;;
        ;; 1) ʹ�� cmpxchg ָ��
        ;;
        lock cmpxchg [ApStage1Lock], esi
        jz AcquireApStage1LockOk
        
        ;;
        ;; 2) ʹ�� bts ָ��
        ;; lock bts DWORD [ApStage1Lock], 0
        ;; jnc AcquireApStage1LockOk
        ;;
        
CheckApStage1Lock:
        mov eax, [ApStage1Lock]
        test eax, eax 
        jz AcquireApStage1Lock
        pause
        jmp CheckApStage1Lock
        

        
AcquireApStage1LockOk:

        ;;
        ;; ���뱣��ģʽ
        ;;
        call protected_mode_enter
        
        bits 32
        
        ;;
        ;; ת��ִ�� PCB ��ʼ��
        ;; ע�⣺
        ;;      1) �˴�ʹ�þ��Ե�ַ��ת����Ϊ cs.base = 0
        ;;
        mov eax, PcbInitEntry
        jmp eax
        

   




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ������ include �����ĺ���ģ��        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        bits 16
                
%include "..\lib\crt16.asm"                 
 
  
        bits 32
;;
;; �������ʹ���� stage1 �׶�
;;        
%include "..\lib\crt.asm"        
%include "..\lib\LocalVideo.asm"
%include "..\lib\system_data_manage.asm" 
%include "..\lib\mem.asm"
%include "..\lib\page32.asm"
%include "..\lib\apic.asm"
%include "..\lib\ioapic.asm"
%include "..\lib\pci.asm"
%include "..\lib\mtrr.asm"
%include "..\lib\debug.asm"
%include "..\lib\perfmon.asm"
%include "..\lib\pic8259a.asm"
%include "..\lib\smp.asm"
%include "..\lib\stage1.asm"
%include "..\lib\services.asm"
%include "..\lib\data.asm"





        [SECTION .data]
    
;;
;; ���� Ap ����ִ��������ʼ״̬Ϊ 1����������
;;
ApStage1Lock    DD      1                       ;; stage1��setup���׶ε���
ApStage2Lock    DD      1                       ;; stage2��protected���׶ε���
ApStage3Lock    DD      1                       ;; stage3��long���׶ε���

        
;;
;; ģ�鳤��
;;
SETUP_LENGTH    EQU     $ - SETUP_SEGMENT



; end of setup        