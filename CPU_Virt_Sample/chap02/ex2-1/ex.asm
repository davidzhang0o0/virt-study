;*************************************************
; ex.asm                                         *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************

;;
;; ex.asm ˵����
;; 1) ex.asm ��ʵ�����ӵ�Դ�����ļ�����Ƕ���� protected.asm �� long.asm �ļ���
;; 2) ex.asm ��ͨ��ģ�飬���� stage2 �� stage3 �׶�����
;;


        ;;
        ;; ���� ex2-1���оٳ�����һ���߼�������VMX�ṩ��������Ϣ
        ;;
                              
        call get_usable_processor_index                         ; ��ȡ���õĴ����� index ֵ
        mov esi, eax                                            ; Ŀ�괦����Ϊ��ȡ�Ĵ�����
        mov edi, TargetCpuVmxCapabilities                       ; Ŀ�����
        mov eax, signal                                         ; signal
        call dispatch_to_processor_with_waitting                ; ���ȵ�Ŀ�괦����ִ��
        
        ;;
        ;; �ȴ� CPU ����
        ;;
        call wait_esc_for_reset




        
;----------------------------------------------
; TargetCpuVmxCapabilities()
; input:
;       none
; output:
;       none
; ������
;       1) ����ִ�е�Ŀ�����
;----------------------------------------------
TargetCpuVmxCapabilities:
        call update_system_status                       ; ����ϵͳ״̬
        call println
                
        ;;
        ;; ��ӡ VMX capabilities ��Ϣ
        ;;
        call dump_vmx_capabilities  
        ret
        

signal  dd 1        