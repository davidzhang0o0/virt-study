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
        ;; ���� ex1-2��ʹ�õ��Լ�¼���ܹ۲���Ϣ
        ;;
               
               
               
        ;;
        ;; ����Ŀ�괦����ִ�� dump_debug_record() ���������� CPU ������ȷ��Ŀ�괦������
        ;;
        mov esi, [fs: SDA.ProcessorCount]
        dec esi
        mov edi, dump_debug_record
        call dispatch_to_processor


        ;;
        ;; �����Ϣ
        ;;        
        mov esi, Ex.Msg1
        call puts

        
        ;;
        ;; �����������Լ�¼
        ;;
        mov ecx, 1
        DEBUG_RECORD    "debug record 1"        
        mov ecx, 2
        DEBUG_RECORD    "debug record 2"
        mov ecx, 3
        DEBUG_RECORD    "debug record 3"        
        
        jmp  $

Ex.Msg1         db      'example 1-2: test DEUBG_REOCRD', 0        