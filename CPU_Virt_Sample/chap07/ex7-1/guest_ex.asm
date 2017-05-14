;*************************************************
; guest_ex.asm                                   *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


;;
;; guest ��ʾ���ļ�
;;

        ;;
        ;; ���� SYSENTER ʹ�û���
        ;;
        xor edx, edx
        xor eax, eax
        mov ax, cs
        mov ecx, IA32_SYSENTER_CS
        wrmsr

       
%if __BITS__ == 64
        mov rax, rsp
        shld rdx, rax, 32        
%else
        mov eax, esp
        xor edx, edx
%endif
        mov ecx, IA32_SYSENTER_ESP
        wrmsr
        

%if __BITS__ == 64
        mov rax, 0FFFF800080000000h + SysRoutine
        shld rdx, rax, 32
%else
        mov eax, 80000000h + SysRoutine
        xor edx, edx
%endif
        mov ecx, IA32_SYSENTER_EIP
        wrmsr
        
        
        ;;
        ;; ������� user Ȩ��
        ;;
%if __BITS__ == 64
        push GuestUserSs64 | 3
        push 7FF0h
        push GuestUserCs64 | 3
        push GuestEx.UserEntry
        retf64
%else
        push GuestUserSs32 | 3
        push 7FF0h
        push GuestUserCs32 | 3
        push GuestEx.UserEntry
        retf
%endif




;;#################################
;; ������ guest �� User �����
;;#################################

GuestEx.UserEntry:        
%if __BITS__ == 64
        mov ax, GuestUserSs64
%else
        mov ax, GuestUserSs32
%endif        
        mov ds, ax
        mov es, ax

        ;;
        ;; ����ϵͳ��������
        ;;       
        call FastSysCallEntry
        
        mov esi, GuestEx.Msg2
        call PutStr
        
        jmp $
        
        

        
;-------------------------------------
; FastSysCallEntry()
;-------------------------------------        
FastSysCallEntry:
%if __BITS__ == 64
        mov rcx, rsp
        mov rdx, [rsp]
%else
        mov ecx, esp
        mov edx, [esp]
%endif
        sysenter
        ret


        
;-------------------------------------
; SYSENTER ָ��ķ�������
;-------------------------------------
SysRoutine:
        mov esi, GuestEx.Msg1
        call PutStr
        REX.Wrxb
        sysexit
        


GuestEx.Msg1            db      10, 'now, enter sysenter service routine...', 10, 0        
GuestEx.Msg2            db      'system service done ...', 0