;*************************************************
; pic8259.asm                                    *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


%include "..\inc\ports.inc"



;----------------------------------------------
; init_8253() - init 8253-PIT controller
;----------------------------------------------        
init_8253:
        mov al, 36h                                   ; set to 100Hz
        out PIT_CONTROL_PORT, al
        xor ax, ax
        out PIT_COUNTER0_PORT, al
        out PIT_COUNTER0_PORT, al
        ret
        
        
;-------------------------------------------------
; init_8259()
; input:
;       none
; ouput:
;       none
; ������
;       ��ʼ�� 8259 ����
;       1) master Ƭ�ж������� 20h
;       2) slave Ƭ�ж������� 28h       
;-------------------------------------------------
init_pic8259:
;;; ��ʼ�� master 8259A оƬ
; 1) ��д ICW1
	mov al, 11h  					; ICW = 1, ICW4-write required
	out MASTER_ICW1_PORT, al
	jmp $+2
	nop
; 2) ����д ICW2
	mov al, PIC8259A_IRQ0_VECTOR                    ; interrupt vector
	out MASTER_ICW2_PORT, al
	jmp $+2
	nop
; 3) ����д ICW3				
	mov al, 04h					; bit2 must be 1
	out MASTER_ICW3_PORT, al
	jmp $+2
	nop
; 4) ����д ICW4
	mov al, 01h					; for Intel Architecture
	out MASTER_ICW4_PORT, al
	jmp $+2
        nop
;; ��ʼ�� slave 8259A оƬ
; 1) ��д ICW1
	mov al, 11h					; ICW = 1, ICW4-write required
	out SLAVE_ICW1_PORT, al
	jmp $+2
	nop
; 2) ����д ICW2
	mov al, PIC8259A_IRQ0_VECTOR + 8                ; interrupt vector
	out SLAVE_ICW2_PORT, al
	jmp $+2
	nop
; 3) ����д ICW3				
	mov al, 02h					; bit2 must be 1
	out SLAVE_ICW3_PORT, al
	jmp $+2
	nop
; 4) ����д ICW4
	mov al, 01h					; for Intel Architecture
	out SLAVE_ICW4_PORT, al		
	ret


;-------------------------------------------------
; setup_pic8259()
; input:
;       none
; ������
;       ��ʼ�� 8259 ��������Ӧ���жϷ�������
;-------------------------------------------------
setup_pic8259:
        ;;
        ;; ��ʼ�� 8259 �� 8253
        ;;
        call init_pic8259
        call init_8253                             
        call disable_8259
        ret
	
	
	
;--------------------------
; write_master_EOI:
;--------------------------
write_master_EOI:
	mov al, 00100000B				; OCW2 select, EOI
	out MASTER_OCW2_PORT, al
	ret
        
;-----------------------------
; �� MASTER_EOI()
;-----------------------------
%macro MASTER_EOI 0
	mov al, 00100000B				; OCW2 select, EOI
	out MASTER_OCW2_PORT, al
%endmacro
        
        
        
        
write_slave_EOI:
        mov al,  00100000B
        out SLAVE_OCW2_PORT, al
        ret
	
;-----------------------------
; �� SLAVE_EOI()
;-----------------------------
%macro SLAVE_EOI 0
        mov al,  00100000B
        out SLAVE_OCW2_PORT, al
%endmacro


;----------------------------
; �������� 8259 �ж�
;----------------------------
disable_8259:
        mov al, 0FFh
	out MASTER_MASK_PORT, al        
        ret

;--------------------------
; mask timer
;--------------------------
disable_8259_timer:
	in al, MASTER_MASK_PORT
	or al, 0x01
	out MASTER_MASK_PORT, al
	ret	
	
enable_8259_timer:
	in al, MASTER_MASK_PORT
	and al, 0xfe
	out MASTER_MASK_PORT, al
	ret	
		
;--------------------------
; mask ����
;--------------------------
disable_8259_keyboard:
	in al, MASTER_MASK_PORT
	or al, 0x02
	out MASTER_MASK_PORT, al
	ret
	
enable_8259_keyboard:
	in al, MASTER_MASK_PORT
	and al, 0xfd
	out MASTER_MASK_PORT, al
	ret	
	
;------------------------------
; read_master_isr:
;------------------------------
read_master_isr:
	mov al, 00001011B			; OCW3 select, read ISR
	out MASTER_OCW3_PORT, al
	jmp $+2
	in al, MASTER_OCW3_PORT
	ret
read_slave_isr:
	mov al, 00001011B
        out SLAVE_OCW3_PORT, al
        jmp $+2
        in al, SLAVE_OCW3_PORT
        ret
;-------------------------------
; read_master_irr:
;--------------------------------
read_master_irr:
	mov al, 00001010B			; OCW3 select, read IRR	
	out MASTER_OCW3_PORT, al
	jmp $+2
	in al, MASTER_OCW3_PORT
	ret

read_slave_irr:
        mov al, 00001010B
        out SLAVE_OCW3_PORT, al
        jmp $+2
        in al, SLAVE_OCW3_PORT
        ret

read_master_imr:
	in al, MASTER_IMR_PORT
	ret
        
read_slave_imr:
        in al, SLAVE_IMR_PORT
        ret
;------------------------------
; send_smm_command
;------------------------------
send_smm_command:
	mov al, 01101000B			; SMM=ESMM=1, OCW3 select
	out MASTER_OCW3_PORT, al	
	ret
        

	
	
;--------------------------------------------------
; keyboard_8259_handler:
; ������
;       ʹ���� 8259 IRQ1 handler
;--------------------------------------------------
keyboard_8259_handler:                
        push ebp
        push ecx
        push edx
        push ebx
        push esi
        push edi
        push eax

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  
        
        in al, I8408_DATA_PORT                          ; ������ɨ����
        test al, al
        js keyboard_8259_handler.done                   ; Ϊ break code
  
        ;;
        ;; �Ƿ�Ϊ���ܼ�
        ;;
        cmp al, SC_F1
        jb keyboard_8259_handler.next
        cmp al, SC_F10
        ja keyboard_8259_handler.next

        ;;
        ;; �л���ǰ������
        ;;
        sub al, SC_F1
        movzx esi, al
        mov edi, switch_to_processor
        call force_dispatch_to_processor
        
        
        jmp keyboard_8259_handler.done
        
keyboard_8259_handler.next:
        
        ;;
        ;; ��ɨ���뱣���ڴ������Լ��� local keyboard buffer ��
        ;; local keyboard buffer �� SDA.KeyBufferHeadPointer �� SDA.KeyBufferPtrPointer ָ��ָ��
        ;;
        REX.Wrxb
        mov ebx, [ebp + SDA.KeyBufferPtrPointer]                ; ebx = LSB.LocalKeyBufferPtr ָ��ֵ
        REX.Wrxb
        mov esi, [ebx]                                          ; esi = LSB.LocalKeyBufferPtr ֵ
        REX.Wrxb
        INCv esi
        
     
        ;;
        ;; ����Ƿ񳬹�����������
        ;;
        mov ecx, [ebp + SDA.KeyBufferLength]
        REX.Wrxb
        mov edi, [ebp + SDA.KeyBufferHead]
        REX.Wrxb
        add ecx, edi        
        REX.Wrxb
        cmp esi, ecx
        REX.Wrxb
        cmovae esi, edi                                         ; ������ﻺ����β������ָ��ͷ��
        mov [esi], al                                           ; д��ɨ����
        REX.Wrxb
        xchg [ebx], esi                                         ; ���»�����ָ�� 
        
        ;;
        ;; ����Ƿ���Ҫ�����ⲿ�ж� IPI ��Ŀ�괦����
        ;;
        REX.Wrxb
        mov ebx, [ebp + SDA.ExtIntRtePtr]
        mov ecx, [ebp + SDA.ExtIntRteCount]
        test ecx, ecx
        jz keyboard_8259_handler.done

        mov edx, [ebp + SDA.InFocus]     
keyboard_8259_handler.SendExtIntIpi:
        ;;
        ;; ���Ŀ�괦�����Ƿ�ӵ�н���
        ;;
        cmp edx, [ebx + EXTINT_RTE.ProcessorIndex]
        jne keyboard_8259_handler.SendExtIntIpi.Next

        mov esi, edx
        call get_processor_pcb
        REX.Wrxb
        test eax, eax
        jz keyboard_8259_handler.SendExtIntIpi.Next

        ;;
        ;; ���Ŀ�괦�����Ƿ��� guest������ӵ�н���
        ;;
        mov esi, [eax + PCB.ProcessorStatus]
        xor esi, CPU_STATUS_GUEST | CPU_STATUS_GUEST_FOCUS
        test esi, CPU_STATUS_GUEST | CPU_STATUS_GUEST_FOCUS
        jnz keyboard_8259_handler.SendExtIntIpi.Next

        DEBUG_RECORD    "sending IPI to target processor !"
        
        ;;
        ;; �����ⲿ�жϵ�Ŀ�괦����
        ;;
        mov esi, [eax + PCB.ApicId]
        movzx edi, BYTE [ebx + EXTINT_RTE.Vector]               ; 8259 �� IRQ0 vector
        INCv edi                                                ; �õ������ж� IRQ1 vector
        or edi, FIXED_DELIVERY | PHYSICAL        
        SEND_IPI_TO_PROCESSOR esi, edi
        
keyboard_8259_handler.SendExtIntIpi.Next:
        REX.Wrxb
        add ebx, EXTINT_RTE_SIZE 
        DECv ecx
        jnz keyboard_8259_handler.SendExtIntIpi
        
keyboard_8259_handler.done:
        MASTER_EOI
        pop eax
        pop edi
        pop esi
        pop ebx
        pop edx
        pop ecx
        pop ebp        
        REX.Wrxb
        iret


%if 0           ;; ȡ�� !!

;--------------------------------------------------
; Keyboard_8259_handler.BottomHalf
; input:
;       none
; output:
;       none
; ������
;       1) ���̷������̵��°벿����
;--------------------------------------------------
Keyboard_8259_handler.BottomHalf:
        ;;
        ;; ��ʱ��ջ������Ϊ��
        ;; 1) ����� context
        ;; 2) ���ز���
        ;;

%ifdef __X64
%define RETURN_EIP_OFFSET               (5 * 8)
%define REG_WIDTH                       8
%else
%define RETURN_EIP_OFFSET               (5 * 4)
%define REG_WIDTH                       4
%endif        

        REX.Wrxb
        mov esi, esp
        
        ;;
        ;; ���ж�ջ�ṹ����Ϊ far call ջ�ṹ
        ;;

        REX.Wrxb
        mov eax, [esi + RETURN_EIP_OFFSET]                      ; �� eip
        REX.Wrxb
        mov ebx, [esi + RETURN_EIP_OFFSET + REG_WIDTH]          ; �� cs
        REX.Wrxb
        mov ecx, [esi + RETURN_EIP_OFFSET + REG_WIDTH * 2]      ; �� eflags
        REX.Wrxb
        mov [esi + RETURN_EIP_OFFSET + REG_WIDTH * 2], ebx      ; cs д��ԭ eflags λ��
        REX.Wrxb
        mov [esi + RETURN_EIP_OFFSET + REG_WIDTH], eax          ; eip д��ԭ cs λ��
        REX.Wrxb
        mov [esi + RETURN_EIP_OFFSET], ecx                      ; eflags д��ԭ eip λ��


        ;;
        ;; ��鴦�����Ƿ�ӵ�н���
        ;; 1) �񣬽�ת�� HLT ״̬
        ;; 2) �ǣ����ر��ж���
        ;;        
        mov eax, PCB.ProcessorIndex
        mov ecx, [gs: eax]                                      ; ���������� index ֵ
        
        mov eax, SDA.InFocus
        cmp ecx, [fs: eax]
        je Keyboard_8259_handler.BottomHalf.Done

Keyboard_8259_handler.BottomHalf.@0:        
        ;;
        ;; ���� HLT ״̬
        ;;
        hlt
        
        ;;
        ;; ���������յ��ⲿ�ж����󣬴� HLT �л��ѣ�
        ;; ����ִ���´μ���Ƿ�ӵ�н���
        ;;
        cmp ecx, [fs: eax]
        jne Keyboard_8259_handler.BottomHalf.@0


%undef RETURN_EIP_OFFSET
%undef REG_WIDTH

Keyboard_8259_handler.BottomHalf.Done:
        
        pop eax
        pop edi
        pop esi
        pop ecx
        pop ebp
        popf
        REX.Wrxb        
        retf
        

%endif



;--------------------------------------------------
; timer_8259_handler()
; ������
;       1) ʹ���� 8259 IRQ0 handler
;       2) ÿ���жϽ�����ֵ�� 1
;--------------------------------------------------
timer_8259_handler:
        push eax
        
%ifdef __X64        
        bits 64
        lock inc DWORD [fs: SDA.TimerCount]
        bits 32
%else
        lock inc DWORD [fs: SDA.TimerCount]      
%endif        

        MASTER_EOI
        pop eax
        DW 4840h
        iret
        






                	
       	

	