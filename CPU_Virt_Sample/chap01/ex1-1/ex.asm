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
        ;; ���� ex1-1������һ���հ���Ŀ��ʾ��
        ;;
        
        
        mov esi, Ex.Msg1
        call puts
        mov esi, [fs: SDA.ApLongmode]
        add esi, 2
        call print_dword_decimal

        jmp  $

Ex.Msg1         db      'example 1-1: run in stage', 0        