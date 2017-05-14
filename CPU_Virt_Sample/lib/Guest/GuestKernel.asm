;*************************************************
; GuestKernel.asm                                *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


%include "..\..\inc\support.inc"
%include "..\..\lib\Guest\Guest.inc"



        
        [SECTION .text]
        org GUEST_KERNEL_ENTRY
        dd GUEST_KERNEL_LENGTH
        
;;
;; ��ǰ guest �Ѿ�λ��δ��ҳ�� protected ģʽ��
;; 
        bits 32

GuestKernel.Start:        
        
        mov esi, Guest.StartMsg
        call PutStr

        mov eax, cr4
        or eax, CR4_PAE
        mov cr4, eax                            ; ���� CR4.PAE
        
        
        ;;
        ;; ���� GUEST_X64 ���������� guest ���� IA-32e ���� protected ģʽ
        ;;
        
%ifdef GUEST_X64
        ;;
        ;; ��ʼ�� long mode ģʽҳ��
        ;;
        call init_longmode_page
        
        mov eax, GUEST_PML4T_BASE
        mov cr3, eax
        
        ;;
        ;; ���� long mode
        ;;
        mov ecx, IA32_EFER
        rdmsr
        or eax, EFER_LME
        wrmsr
        
        ;;
        ;; ������ҳ
        ;;
        mov eax, cr0
        or eax, CR0_PG
        mov cr0, eax
        
        jmp GuestKernelCs64 : GuestKernel.@0

GuestKernel.@0:
        
        bits 64
        
        mov ax, GuestKernelSs64
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov rsp, 0FFFF8000FFF00FF0h
        
        
        mov rax, (0FFFF800080000000h + GuestKernel.Next)
        jmp rax
        
        
%else   

        ;;-------------------------
        ;; 32 λ����ģʽ
        ;;-------------------------
   
        call init_pae_page
        
        mov eax, Guest.Pdpt
        mov cr3, eax
        
        ;;
        ;; ������ҳ
        ;;
        mov eax, cr0
        or eax, CR0_PG
        mov cr0, eax
        
        mov esp, 0FFF00FF0h
        mov eax, (80000000h + GuestKernel.Next)
        jmp eax
        
%endif        
        
        



;;###########################
;;      guest kernel 
;;###########################

 GuestKernel.Next:  
        ;;
        ;; ���´�������־
        ;;
        or DWORD [Guest.ProcessorFlag], GUEST_PROCESSOR_PAGING 
        
        ;;
        ;; �����Ϣ
        ;;     
        mov esi, Guest.DoneMsg
        call PutStr
        mov esi, Guest.RunMsg
        call PutStr
        mov esi, Guest.TscMsg
        call PutStr
        rdtsc
        mov esi, eax
        mov edi, edx
        call PrintQword
        call PrintLn
       

       
        ;;
        ;; geust_ex.asm �� guest ��ʾ���ļ�
        ;;
        %include "guest_ex.asm"
        
       
        jmp $
        
        
        
%include "..\..\lib\Guest\GuestLib.asm"
%include "..\..\lib\Guest\GuestCrt.asm"
%include "..\..\lib\Guest\Guest8259.asm"




;;#####################################
;;
;;         Guest ����������
;;
;;#####################################
        
        [SECTION .data]

Guest.PoolPhysicalBase          DD      GUEST_POOL_PHYSICAL_BASE

;;
;; ������״̬��־λ
;;
Guest.ProcessorFlag             DD      0


Guest.VideoBufferPtr            DQ      0B8000h
Guest.IdtPointer:               DW      0
                                DQ      0
Guest.TssBase                   DQ      0


KeyBufferLength                 DD      256
KeyBufferHead                   DQ      KeyBuffer
KeyBufferPtr                    DQ      (KeyBuffer - 1)
KeyBuffer            times 256  DB      0




%ifndef GUEST_X64

;;
;; ������ PAE paging �µ� PDPT ��
;; 1) ÿ�� PDPTE Ϊ 8 �ֽ�
;;
        ALIGNB 32
Guest.Pdpt                      DQ      GUEST_PDT0_BASE | P
                                DQ      GUEST_PDT1_BASE | P
                                DQ      GUEST_PDT2_BASE | P
                                DQ      GUEST_PDT3_BASE | P
                
%endif        


;;
;; ��Ϣ
;;
Guest.StartMsg                  db      '[OS]: start ...', 10, 0
Guest.DoneMsg                   db      '[OS]: initialize done ...', 10, 0
Guest.RunMsg                    db      '[OS]: running ...', 10, 0
Guest.TscMsg                    db      '[OS]: TSC = ', 0


GUEST_KERNEL_LENGTH             EQU     $ - GUEST_KERNEL_ENTRY
