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
        ;; ���� ex.asm ģ��ʹ�õ�ͷ�ļ�
        ;;
        %include "ex.inc"
        
        ;;
        ;; ���� ex3-1: ʹ�� guest �� host ��ͬ���������� guest
        ;;                
        mov esi, [fs: SDA.ProcessorCount]
        dec esi
        mov edi, dump_debug_record
        call dispatch_to_processor

        ;;
        ;; �ȴ��û�ѡ������
        ;;
        call do_command        
        

        ;;
        ;; �ȴ�����
        ;;
        call wait_esc_for_reset

        





;----------------------------------------------
; TargetCpuVmentry()
; input:
;       none
; output:
;       none
; ������
;       1) ����ִ�е�Ŀ�����
;       2) �˺����ô�����ִ�� VM-entry ����
;----------------------------------------------
TargetCpuVmentry:       
        push R5        
        mov R5, [gs: PCB.Base]
                       
        ;;
        ;; CR0.PG = CR.PE = 1
        ;;
        mov eax, GUEST_FLAG_PE | GUEST_FLAG_PG        
%ifdef __X64        
        or eax, GUEST_FLAG_IA32E
%endif  
        mov DWORD [R5 + PCB.GuestA + VMB.GuestFlags], eax

        ;;
        ;; ��ʼ�� VMCS region
        ;;
        mov DWORD [R5 + PCB.GuestA + VMB.GuestEntry], guest_entry
        mov DWORD [R5 + PCB.GuestA + VMB.HostEntry], VmmEntry

        ;;
        ;; ���� guest stack
        ;;
        mov R7, get_user_stack_pointer
        mov R6, get_kernel_stack_pointer
        test eax, GUEST_FLAG_USER
        cmovnz R6, R7
        call R6        
        mov [R5 + PCB.GuestA + VMB.GuestStack], R0
        
        ;;
        ;; ��ʼ�� VMCS buffer
        ;;
        mov R6, [R5 + PCB.VmcsA]
        call initialize_vmcs_buffer
        
                                
        ;;
        ;; ִ�� VMCLEAR ����
        ;;
        vmclear [R5 + PCB.GuestA]
        jc @1
        jz @1         
        
        ;;
        ;; ���� VMCS pointer
        ;;
        vmptrld [R5 + PCB.GuestA]
        jc @1
        jz @1  

        ;;
        ;; ���µ�ǰ VMB ָ��
        ;;
        mov R0, [R5 + PCB.VmcsA]
        mov [R5 + PCB.CurrentVmbPointer], R0
                
        ;;
        ;; ���� VMCS
        ;;
        call setup_vmcs_region
        call update_system_status
        
        ;;
        ;; ���� guest ����
        ;;  
        call reset_guest_context
        or DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_GUEST        
        vmlaunch
        
@1:       
        call dump_vmcs
        call wait_esc_for_reset
        pop R5
        ret
        
        
        
        
;-----------------------------------------------------------------------
; guest_entry():
; input:
;       none
; output:
;       none
; ������
;       1) ���� guest ����ڵ�
;-----------------------------------------------------------------------
guest_entry:
        
        DEBUG_RECORD    "[VM-entry]: switch to guest !"         ; ���� debug ��¼��

        call dump_guest_env                                     ; ��ӡ������Ϣ
        
        hlt
        jmp $ - 1
        ret        





;-------------------------------------------------
; dump_guest_env()
; input:
;       none
; output:
;       none
; ������
;       1) ��� guest ���ֻ�����Ϣ
;-------------------------------------------------
dump_guest_env:
        call println
        mov esi, Guest.Cr0Msg
        call puts
        mov R6, cr0
%if __BITS__ == 64
        call print_qword_value64
%else
        call print_dword_value   
%endif
        call println
        mov esi, Guest.Cr4Msg
        call puts
        mov R6, cr4
%if __BITS__ == 64
        call print_qword_value64
%else
        call print_dword_value   
%endif
        call println
        mov esi, Guest.Cr3Msg
        call puts
        mov R6, cr3
%if __BITS__ == 64
        call print_qword_value64
%else
        call print_dword_value   
%endif
        call println
%if __BITS__ == 64
        mov esi, Guest.CsMsg0
%else
        mov esi, Guest.CsMsg1
%endif 
        call puts
        mov si, cs
        call print_word_value
        mov esi, ':'
        call putc
        mov esi, guest_entry
%if __BITS__ == 64
        call print_qword_value64
%else
        call print_dword_value   
%endif
        call println
        
%if __BITS__ == 64
        mov esi, Guest.SsMsg0
%else
        mov esi, Guest.SsMsg1
%endif 
        call puts
        mov si, ss
        call print_word_value
        mov esi, ':'
        call putc
        mov R6, R4
%if __BITS__ == 64
        add R6, 8
        call print_qword_value64
%else
        add R6, 4
        call print_dword_value   
%endif
        
        ret






;-------------------------------------------------
; do_command()
; input:
;       none
; output:
;       none
; ������
;       1) �� BSP ���õ��������
;-------------------------------------------------
do_command:
        push R5

do_command.loop:        
        mov esi, 2
        mov edi, 0
        call set_video_buffer
        mov esi, Ex.CmdMsg
        call puts
        
        ;;
        ;; �ȴ�����
        ;;
        call wait_a_key
        
        cmp al, SC_ESC                                          ; �Ƿ�Ϊ <ESC>
        je do_esc
        cmp al, SC_Q                                            ; �Ƿ�Ϊ <Q>
        je do_command.done
        
        cmp al, SC_1
        jb do_command.@0
        cmp al, SC_0
        jbe do_command.vmentry
        
do_command.@0:
        ;;
        ;; �Ƿ��� interrupt
        ;;
        cmp al, SC_I
        jne do_command.@1
               
        mov edi, FIXED_DELIVERY | PHYSICAL | IPI_VECTOR
        jmp do_command.@4
        
do_command.@1:
        ;;
        ;; �Ƿ��� NMI
        ;;
        DEBUG_RECORD         "[command]: you press a N key !"
        
        cmp al, SC_N
        jne do_command.@2
        mov DWORD [fs: SDA.NmiIpiRequestMask], 0
        mov edi, NMI_DELIVERY | PHYSICAL | 02h
        jmp do_command.@4
        
do_command.@2:
        ;;
        ;; �Ƿ��� INIT
        ;;
        cmp al, SC_T
        jne do_command.@3
        mov edi, INIT_DELIVERY | PHYSICAL
        jmp do_command.@4

do_command.@3:
        ;;
        ;; �Ƿ��� SIPI
        ;;
        cmp al, SC_S
        jne do_command.loop
        mov edi, SIPI_DELIVERY | PHYSICAL
        
do_command.@4:
        mov esi, [Ex.TargetCpu]
        call get_processor_pcb
        mov DWORD [R0 + PCB.IpiRoutinePointer], 0


        ;;
        ;; ���� IPI 
        ;;
        SEND_IPI_TO_PROCESSOR   esi, edi
        jmp do_command.loop
        
        
do_command.vmentry:
        DEBUG_RECORD         "[command]: *** dispatch to CPU for VM-entry *** "
        
        ;;
        ;; ����Ŀ�� CPU ���� guest
        ;;
        dec al
        movzx eax, al
        mov esi, 1
        cmp eax, [fs: SDA.ProcessorCount]
        cmovb esi, eax
        mov [Ex.TargetCpu], esi
        mov edi, [TargetVmentryRoutine + R6 * 4 - 4]
        test edi, edi
        jz do_command.loop
        call goto_processor
        jmp do_command.loop
do_esc:        
        RESET_CPU
        
do_command.done:        
        pop R5
        ret





Ex.CmdMsg       db '===================<<< press a key to do command >>>=========================', 10
Ex.SysMsg       db '[system command       ]:   reset - <ESC>, Quit - q,     CPUn - <Fn+1>',  10
Ex.VmxEntryMsg  db '[CPU for VM-entry     ]:   CPU1  - 1,     CPUn - n', 10, 
Ex.IpiMsg       db '[Send Message to CPU  ]:   INT   - i,     NMI  - n,     INIT - t,    SIPI - s', 10, 0



Guest.Cr0Msg    db 'CR0:', 0
Guest.Cr4Msg    db 'CR4:', 0
Guest.Cr3Msg    db 'CR3:', 0
Guest.CsMsg0    db 'CS:RIP = ', 0
Guest.CsMsg1    db 'CS:EIP = ', 0
Guest.SsMsg0    db 'SS:RSP = ', 0
Guest.SsMsg1    db 'SS:ESP = ', 0

Ex.TargetCpu    dd      1
TargetVmentryRoutine    dd      TargetCpuVmentry, 0

