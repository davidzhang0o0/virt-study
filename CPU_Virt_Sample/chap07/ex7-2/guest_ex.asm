;*************************************************
; guest_ex.asm                                   *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************

        
        ;;
        ;; ���� ex7-2��ģ�� guest �����л�
        ;; ע�⣺�������Ϊ guest ʹ�� legacy ����ģʽ
        ;; �����������Ϊ��
        ;;      1) build -DDEBUG_RECORD_ENABLE -DGUEST_ENABLE -D__X64
        ;;      2) build -DDEBUG_RECORD_ENABLE -DGUEST_ENABLE
        ;;


%ifndef GUEST_X64
        ;;
        ;; ��������ʹ�õ� TSS selector
        ;;
        NewTssSelector          EQU     GuestReservedSel0    
        TargetTaskSelector      EQU     GuestReservedSel0    


        ;;
        ;; ����һ�� TSS ������
        ;;
        sgdt [GuestEx.GdtPointer]
        mov ebx, [GuestEx.GdtBase]
        mov DWORD [ebx + NewTssSelector + 4], GuestEx.Tss
        mov DWORD [ebx + NewTssSelector + 2], GuestEx.Tss
        mov WORD [ebx + NewTssSelector], 67h        
        mov WORD [ebx + NewTssSelector + 5], 89h

        ;;
        ;; ����һ�� task-gate ������
        ;;
        sidt [GuestEx.IdtPointer]
        mov ebx, [GuestEx.IdtBase]
        mov WORD [ebx + 60h * 8 + 2], NewTssSelector
        mov BYTE [ebx + 60h * 8 + 5], 85h
        

        ;;
        ;; ����������� TSS ������
        ;;
        mov ebx, GuestEx.Tss
        mov DWORD [ebx + TSS32.Esp], 7F00h
        mov WORD [ebx + TSS32.Ss], GuestKernelSs32
        mov eax, cr3
        mov [ebx + TSS32.Cr3], eax
        mov DWORD [ebx + TSS32.Eip], GuestEx.NewTask
        mov DWORD [ebx + TSS32.Eflags], FLAGS_IF | 02h
        mov WORD [ebx + TSS32.Cs], GuestKernelCs32
        mov WORD [ebx + TSS32.Ds], GuestKernelSs32
        
       
        ;;
        ;; ### ������������л�������###
        ;; ע�⣺��Ҫʹ�� INT ָ�
        ;;       ��Ϊ�������� ex7-4 ��������ִ�� INT ָ���û�ж��жϵ������л����д��� ����
        ;;       ���ԣ�����ʹ�� CALL ָ����������л� ����
        ;;     
        call    TargetTaskSelector : 0
        
        ;;
        ;; ��ӡ�л���������Ϣ
        ;;
        mov esi, GuestEx.Msg2
        call PutStr


        jmp $
   
        
;; 
;; #### Ŀ������ ####
;;     
GuestEx.NewTask:
        mov esi, GuestEx.Msg1
        call PutStr
        clts
        iret


%endif


;;
;; GDT ��ָ��
;;
GuestEx.GdtPointer:
        GuestEx.GdtLimit        dw      0
        GuestEx.GdtBase         dd      0


GuestEx.IdtPointer:
        GuestEx.IdtLimit        dw      0
        GuestEx.IdtBase         dd      0
        
        
;;
;; TSS ����
;;
ALIGNB 4
GuestEx.Tss:    times 104       db      0



GuestEx.Msg1    db      'now, switch to new task', 10, 0
GuestEx.Msg2    db      'now, switch back old task', 10, 0
                