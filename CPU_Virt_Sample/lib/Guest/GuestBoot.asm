;*************************************************
; GuestBoot.asm                                  *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


%include "..\..\inc\support.inc"
%include "..\..\inc\ports.inc"
%include "..\..\lib\Guest\Guest.inc"

;;
;; Guest ʾ��ģ��˵����
;; 1) ��ʼ�� 7C00h��ʵģʽ��
;; 2) �л�������ģʽ
;;


;;
;; ע�⣺
;; 1) ���ڴ��������� real mode ��       
;; 2) ģ�� GuestBoot �Ѿ������ص� 7C00h λ���ϣ�GUEST_BOOT_ENTRY ����Ϊ 7C00h
;;        

        [SECTION .text]
        org GUEST_BOOT_ENTRY
        dd GUEST_BOOT_LENGTH                                    ;; GuestBoot ģ�鳤��
          
        bits 16
        
GuestBoot.Start:
        cli
        NMI_DISABLE                                             ; �ر� NMI
        FAST_A20_ENABLE                                         ; ���� A20 λ        
        
; set BOOT_SEG environment
        mov ax, cs
        mov ds, ax
        mov ss, ax
        mov es, ax
        mov sp, GUEST_BOOT_ENTRY                                ; �� stack ��Ϊ GUEST_BOOT_ENTRY

               
        
        ;**************************************
        ;*  �����л�������ģʽ                *
        ;**************************************

        lgdt [Guest.GdtPointer]                                 ; ���� GDT
        lidt [Guest.IdtPointer]                                 ; ���� IDT        

        ;;
        ;; ���� TSS 
        ;;
        mov WORD [tss_desc], 67h
        mov WORD [tss_desc + 2], Guest.Tss
        mov BYTE [tss_desc + 5],  89h
        
        mov eax, cr0
        bts eax, 0                                              ; CR0.PE = 1
        mov cr0, eax
             
        jmp GuestKernelCs32 : GuestBoot.Entry32
        
        ;;
        ;; ������ 32 λ protected ģʽ����
        ;;
        
        bits 32

GuestBoot.Entry32:
        mov ax, GuestKernelSs32                                 ; ���� data segment
        mov ds, ax
        mov es, ax
        mov ss, ax

        
        ;; 
        ;; ���� TSS
        ;;
        mov ax, GuestKernelTss
        ltr ax

        ;;
        ;; ����ת�� GuestKernel ģ�飬����� GUEST_KERNEL_ENTRY + 4
        ;;        
        jmp GUEST_KERNEL_ENTRY + 4





        [SECTION .data]
;;        
;; Guest ģ��� GDT
;;
Guest.Gdt:
null_desc               dq 0                    ; NULL descriptor
kernel_code64_desc      dq 0x0020980000000000   ; DPL=0, L=1
kernel_data64_desc      dq 0x0000920000000000   ; DPL=0
user_code32_desc        dq 0x00cff8000000ffff   ; non-conforming, DPL=3, P=1
user_data32_desc        dq 0x00cff2000000ffff   ; DPL=3, P=1, writeable, expand-up
user_code64_desc        dq 0x0020f80000000000   ; DPL = 3
user_data64_desc        dq 0x0000f20000000000   ; DPL = 3
kernel_code32_desc      dq 0x00cf9a000000ffff   ; non-conforming, DPL=0, P=1
kernel_data32_desc      dq 0x00cf92000000ffff   ; DPL=0, P=1, writeable, expand-up
tss_desc                dq 0                    ; TSS
reserved_desc           dq 0
                        dq 0
                        dq 0
                        dq 0 
Guest.Gdt.End:



;;
;; Guest ģ��� IDT
;;
Guest.Idt:
        times 256       dq 0                    ; ���� 256 �� vector
Guest.Idt.End:        


;;
;; Guest ģ��� TSS
;;
Guest.Tss:
                        dd 0                
                        dd 7FF0h                        ; esp0
                        dd GuestKernelSs32              ; ss0
                        dq 0                            ; ss1/esp1
                        dq 0                            ; ss2/esp2
                        dq 0                            ; reserved
                        dq 0FFFF8000FFF008F0h           ; IST1
               times 17 dd 0        
                        dw 0                       
                        dw 0                            ; I/O permission bitmap offset = 0 
Guest.Tss.End:



;;
;; Guest ģ��� Gdt pointer
;;
Guest.GdtPointer:
gdt_limit               dw      (Guest.Gdt.End - Guest.Gdt) - 1
gdt_base                dd      Guest.Gdt


;;
;; Guest ģ��� Idt pointer
;;
Guest.IdtPointer:
idt_limit               dw      (Guest.Idt.End - Guest.Idt) - 1
idt_base                dd      Guest.Idt



    
  

GUEST_BOOT_LENGTH       EQU     $ - GUEST_BOOT_ENTRY