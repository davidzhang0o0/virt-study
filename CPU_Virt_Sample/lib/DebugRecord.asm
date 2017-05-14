;*************************************************
;* DeubgRecord.asm                               *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************




;-------------------------------------------------
; update_guest_context()
; input:
;       none
; output:
;       none
; ������
;       1) ���µ�ǰ debug reocrd ����β���� context ��Ϣ
;-------------------------------------------------
update_guest_context:

%ifdef DEBUG_RECORD_ENABLE
        push ebp
        push ebx
        push edx
        
%ifdef __X64        
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        REX.Wrxb
        mov eax, [ebp + PCB.SdaBase]        
        REX.Wrxb
        mov ebx, [eax + SDA.DrsTailPtr]                 ; �� Tail pointer
        REX.Wrxb
        mov edx, [ebp + PCB.CurrentVmbPointer]
        REX.Wrxb
        mov edx, [edx + VMB.VsbBase]
        
        ;;
        ;; ���� debug record �еļĴ���ֵ
        ;;
        REX.Wrxb
        mov eax, [edx + VSB.Rax]
        REX.Wrxb
        mov [ebx + DRS.Rax], eax                        ; rax
        REX.Wrxb
        mov eax, [edx + VSB.Rcx]
        REX.Wrxb
        mov [ebx + DRS.Rcx], eax                        ; rcx
        REX.Wrxb
        mov eax, [edx + VSB.Rdx]
        REX.Wrxb
        mov [ebx + DRS.Rdx], eax                        ; rdx
        REX.Wrxb
        mov eax, [edx + VSB.Rbx]
        REX.Wrxb
        mov [ebx + DRS.Rbx], eax                        ; rbx        
        REX.Wrxb
        mov eax, [edx + VSB.Rsp]
        REX.Wrxb
        mov [ebx + DRS.Rsp], eax                        ; rsp
        REX.Wrxb
        mov eax, [edx + VSB.Rbp]
        REX.Wrxb
        mov [ebx + DRS.Rbp], eax                        ; rbp
        REX.Wrxb
        mov eax, [edx + VSB.Rsi]
        REX.Wrxb
        mov [ebx + DRS.Rsi], eax                        ; rsi
        REX.Wrxb
        mov eax, [edx + VSB.Rdi]
        REX.Wrxb
        mov [ebx + DRS.Rdi], eax                        ; rdi
        
%ifdef __X64        
        REX.Wrxb
        mov eax, [edx + VSB.R8]
        REX.Wrxb
        mov [ebx + DRS.R8], eax                         ; r8        
        REX.Wrxb
        mov eax, [edx + VSB.R9]
        REX.Wrxb
        mov [ebx + DRS.R9], eax                         ; r9
        REX.Wrxb
        mov eax, [edx + VSB.R10]
        REX.Wrxb
        mov [ebx + DRS.R10], eax                        ; r10
        REX.Wrxb
        mov eax, [edx + VSB.R11]
        REX.Wrxb
        mov [ebx + DRS.R11], eax                        ; r11
        REX.Wrxb
        mov eax, [edx + VSB.R12]
        REX.Wrxb
        mov [ebx + DRS.R12], eax                        ; r12
        REX.Wrxb
        mov eax, [edx + VSB.R13]
        REX.Wrxb
        mov [ebx + DRS.R13], eax                        ; r13
        REX.Wrxb
        mov eax, [edx + VSB.R14]
        REX.Wrxb
        mov [ebx + DRS.R14], eax                        ; r14
        REX.Wrxb
        mov eax, [edx + VSB.R15]
        REX.Wrxb
        mov [ebx + DRS.R15], eax                        ; r15
%endif             
                        
        ;;
        ;; ���� guest CS:RIP �� RFLAGS
        ;;
        mov eax, GUEST_CS_SELECTOR
        vmread [ebx + DRS.Cs], eax        
        REX.Wrxb
        mov eax, [edx + VSB.Rip]
        REX.Wrxb
        mov [ebx + DRS.Rip], eax                
        REX.Wrxb
        mov eax, [edx + VSB.Rflags]
        REX.Wrxb
        mov [ebx + DRS.Rflags], eax  
        
        ;;
        ;; ���� append msg
        ;;
        GetVmcsField    EXIT_REASON
        movzx esi, ax
        mov esi, [Vmx.ExitResonInfoTable + esi * 4]             
        mov edi, Drs.ExitReasonMsg        
        REX.Wrxb
        mov [ebx + DRS.AppendMsg], esi
        REX.Wrxb
        mov [ebx + DRS.PrefixMsg], edi

update_guest_context.done:        
        pop edx
        pop ebx
        pop ebp
%endif        
        ret



;-------------------------------------------------
; update_append_msg()
; input:
;       esi - append msg
;       edi - prefix msg
;       eax - address
; output:
;       none
; ������
;       1) ���µ�ǰ debug reocrd ����β���ĸ�����Ϣ
;-------------------------------------------------
update_append_msg:

%ifdef DEBUG_RECORD_ENABLE
        push ebp
        push ebx
        
%ifdef __X64        
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif

        REX.Wrxb
        mov ebx, [ebp + SDA.DrsTailPtr]                 ; �� Tail pointer
        REX.Wrxb
        mov [ebx + DRS.AppendMsg], esi                  ; �����ԭ Append Msg ָ��        
        REX.Wrxb
        mov [ebx + DRS.PrefixMsg], edi                  ; �����ԭ prefix Msg ָ�� 
        mov [ebx + DRS.Address], eax                   
                        
        pop ebx
        pop ebp
%endif        
        ret




;-------------------------------------------------
; print_debug_record()
; input:
;       esi - DRS ָ��
; output:
;       none
; ������
;       1) ��ӡ debug ��¼
;-------------------------------------------------
print_debug_record:

%ifdef DEBUG_RECORD_ENABLE

        push ebp
        push ebx
        push ecx

        REX.Wrxb
        mov ebp, esi                            ; DRS index
        
%ifdef __X64
        mov ebx, Services64.RegisterMsg        
%else
        mov ebx, Services.RegisterMsg
%endif        
        
        mov esi, Drs.CpuIndexMsg
        call puts
        mov esi, [ebp + DRS.ProcessorIndex]
        call print_dword_decimal
        mov esi, Drs.CpuIndexMsg1
        call puts
        mov esi, Drs.RipMsg
        call puts
        
%ifdef __X64
        mov esi, [ebp + DRS.Rip + 4]
        call print_dword_value
%endif        
        mov esi, [ebp + DRS.Rip]
        call print_dword_value
        mov esi, ' '
        call putc
        mov esi, Drs.RflagsMsg
        call puts
        mov esi, [ebp + DRS.Rflags]
        call print_dword_value
        call println

        REX.Wrxb
        add ebp, DRS.Rax 
        
        ;;
        ;; ��ӡ�Ĵ���ֵ
        ;; 
        xor ecx, ecx
print_debug_record.loop:         
        mov esi, ebx
        call puts        
%ifdef __X64        
        mov esi, [ebp + ecx * 8 + 4]
        call print_dword_value
%endif        
        mov esi, [ebp + ecx * 8]
        call print_dword_value  
        mov esi, 8
        call print_space
        add ebx, REG_MSG_LENGTH
        mov esi, ebx
        call puts
%ifdef __X64        
        mov esi, [ebp + ecx * 8 + 8 + 4]
        call print_dword_value
%endif        
        mov esi, [ebp + ecx * 8 + 8]
        call print_dword_value  
        call println
        add ebx, REG_MSG_LENGTH
        add ecx, 2
%ifdef __X64        
        cmp ecx, 16
%else
        cmp ecx, 8
%endif
        jb print_debug_record.loop        
        
        ;;
        ;; ��ӡ�ļ���������
        ;;
        call println
        mov esi, '['
        call putc
        REX.Wrxb
        mov esi, [ebp + DRS.FileName - DRS.Rax]
        call puts
        mov esi, ']'
        call putc
        mov esi, ':'
        call putc
        mov esi, [ebp + DRS.Line - DRS.Rax]
        call print_dword_decimal
        
        
        ;;
        ;; ��ӡ������Ϣ
        ;;
        REX.Wrxb
        mov ebx, [ebp + DRS.AppendMsg - DRS.Rax]
        REX.Wrxb
        test ebx, ebx
        jz print_debug_record.done
        call println
        call println
        mov esi, '>'
        call putc
        mov esi, '>'
        call putc
        mov esi, '>'
        call putc        
        call printblank
        REX.Wrxb
        mov esi, ebx
        call puts


        
print_debug_record.done:        
        pop ecx
        pop ebx
        pop ebp
%endif
        ret




;-------------------------------------------------
; dump_append_msg_list()
; input:
;       none
; output:
;       none
; ������
;       1) ��ӡ��ע��Ϣ�б�
;-------------------------------------------------
dump_append_msg_list:

%ifndef DEBUG_RECORD_ENABLE
        ;;
        ;; ���û�ж��� DEBUG_RECORD_ENABLE ���ţ�����ʾ�� *** NO RECORD ***
        ;;
        mov esi, 2
        mov edi, 0
        call clear_screen
        mov esi, 24
        mov edi, 0
        call set_video_buffer
        mov esi, Drs.StatusMsg
        call puts
        mov esi, 2
        mov edi, 0
        call set_video_buffer
        mov esi, Drs.Msg
        call puts
        mov esi, 0
        call print_dword_decimal
        mov esi, Drs.Msg1
        call puts
        mov esi, Drs.Msg2
        call puts
        
%else

        push ebp
        push ecx
        push ebx
        push edx

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif 
        
        REX.Wrxb
        mov edx, [ebp + SDA.DrsHeadPtr]                         ; edx = ��¼����        

        
dump_append_msg_list.start:
        ;;
        ;; ebx ָ�� DRS ��
        ;;
        REX.Wrxb
        mov ebx, edx
        mov ecx, 20                                             ; ÿ�δ�ӡ 20 ��
        
        ;;
        ;; ��(2:0)�ϴ�ӡ�б�
        ;;        
        mov esi, 2
        mov edi, 0
        call clear_screen
        mov esi, 24
        mov edi, 0
        call set_video_buffer  
        mov esi, Drs.ListMsg1
        call puts
        mov esi, 2
        mov edi, 0
        call set_video_buffer
        mov esi, Drs.ListMsg
        call puts

dump_append_msg_list.loop:        
        mov esi, '<'
        call putc
        mov esi, '#'
        call putc
        mov eax, [ebx + DRS.RecordNumber]
        cmp eax, 10
        mov esi, print_dword_decimal
        mov edi, print_byte_value
        cmovae edi, esi
        mov esi, eax
        call edi
        mov esi, '>'
        call putc
        call printblank

        mov esi, Drs.CpuIndexMsg
        call puts
        mov esi, [ebx + DRS.ProcessorIndex]                     ; CPU index
        call print_dword_decimal
        mov esi, ']'
        call putc
        call printblank

        mov esi, [ebx + DRS.Address]
        test esi, esi
        jz dump_append_msg_list.loop.@0
        call print_dword_value
        mov esi, ':'
        call putc
        call printblank

dump_append_msg_list.loop.@0:
        ;;
        ;; �����ǰ׺��Ϣ�����ӡ
        ;;
        REX.Wrxb
        mov esi, [ebx + DRS.PrefixMsg]
        REX.Wrxb
        test esi, esi
        jz dump_append_msg_list.loop.@1
        call puts
        call printblank
        
dump_append_msg_list.loop.@1:
        ;;
        ;; ��ӡ������Ϣ
        ;;
        REX.Wrxb
        mov esi, [ebx + DRS.AppendMsg]                          ; AppendMsg
        call puts
        
        ;;
        ;; ����к�׺��Ϣ�����ӡ
        ;;
        REX.Wrxb
        mov esi, [ebx + DRS.PostfixMsg]
        REX.Wrxb
        test esi, esi
        jz dump_append_msg_list.loop.@2
        call puts
        
dump_append_msg_list.loop.@2:        
        call println
        
        DECv ecx
        jz dump_append_msg_list.next
        
        REX.Wrxb
        mov ebx, [ebx + DRS.NextDrs]        
        REX.Wrxb
        test ebx, ebx
        jnz dump_append_msg_list.loop
        
        
dump_append_msg_list.next:        
        ;;
        ;; �ȴ�����
        ;;
        call wait_a_key
        
        ;;
        ;; ������
        ;; 1) <Up>�����Ϸ���
        ;; 2) <Down>: ���·���
        ;; 3) <SPACE>��������Ϣ
        ;; 4) <ENTER>���л��� dump_debug_record ģʽ
        ;;
        cmp al, SC_UP
        jne dump_append_msg_list.next.@1
        
        ;;
        ;; ���Ϸ���
        ;;
        REX.Wrxb
        mov edx, [edx + DRS.PrevDrs]
        REX.Wrxb
        test edx, edx
        REX.Wrxb
        cmovz edx, [ebp + SDA.DrsHeadPtr]
        jmp dump_append_msg_list.start
        
dump_append_msg_list.next.@1:        
        cmp al, SC_DOWN
        jne dump_append_msg_list.next.@2
        
        ;;
        ;; ���·���
        ;;
        REX.Wrxb
        mov eax, edx
        REX.Wrxb
        mov edx, [edx + DRS.NextDrs]
        REX.Wrxb
        test edx, edx
        REX.Wrxb
        cmovz edx, eax
        jmp dump_append_msg_list.start

        
dump_append_msg_list.next.@2:        

        cmp al, SC_SPACE                                        ; �Ƿ�Ϊ <SPACE>
        je dump_append_msg_list.start
        
        cmp al, SC_ENTER                                        ; �Ƿ�Ϊ <ENTER>
        jne dump_append_msg_list.next

        
dump_append_msg_list.done:
        pop edx
        pop ebx
        pop ecx
        pop ebp
%endif

        ret



;-------------------------------------------------
; dump_debug_record()
; input:
;       none
; output:
;       none
; ������
;       1) ��ӡ debug ���¼
;-------------------------------------------------
dump_debug_record:

%ifndef DEBUG_RECORD_ENABLE
        ;;
        ;; ���û�ж��� DEBUG_RECORD_ENABLE ���ţ�����ʾ�� *** NO RECORD ***
        ;;
        mov esi, 2
        mov edi, 0
        call clear_screen
        mov esi, 24
        mov edi, 0
        call set_video_buffer
        mov esi, Drs.StatusMsg
        call puts
        mov esi, 2
        mov edi, 0
        call set_video_buffer
        mov esi, Drs.Msg
        call puts
        mov esi, 0
        call print_dword_decimal
        mov esi, Drs.Msg1
        call puts
        mov esi, Drs.Msg2
        call puts
        
%else

        push ebp
        push ecx
        push ebx
        push edx

%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif  


        mov ecx, 1                                      ; �� 1 ����¼
        
        ;;
        ;; ��ȡ DRS ����ͷ
        ;;
        REX.Wrxb
        mov ebx, [ebp + SDA.DrsHeadPtr] 
                
dump_debug_record.loop:
        mov esi, 2
        mov edi, 0
        call clear_screen
        mov esi, 24
        mov edi, 0
        call set_video_buffer
        mov esi, Drs.StatusMsg
        call puts
        mov esi, 2
        mov edi, 0
        call set_video_buffer
        mov esi, Drs.Msg
        call puts
        mov esi, ecx
        call print_dword_decimal
        mov esi, Drs.Msg1
        call puts
        
        cmp DWORD [ebp + SDA.DrsCount], 0
        jne dump_debug_record.next
        mov esi, Drs.Msg2
        call puts
        jmp dump_debug_record.@0
               
               
        ;;
        ;; ���� DRS ����
        ;;               
dump_debug_record.next:        
        ;;
        ;; ��ӡ DRS ��¼��Ϣ
        ;;
        REX.Wrxb
        mov esi, ebx
        call print_debug_record 


        REX.Wrxb
        mov eax, [ebx + DRS.NextDrs]
        REX.Wrxb
        test eax, eax
        jnz dump_debug_record.@0
        
        ;;
        ;; �����¼��
        ;;
        mov esi, Drs.Msg3
        call puts
             
dump_debug_record.@0:        
        ;;
        ;; �ȴ�����
        ;;
        call wait_a_key
        
        ;;
        ;; ������
        ;;
        cmp al, SC_ESC                                          ; �Ƿ�Ϊ <ESC>
        je dump_debug_record.done
        cmp al, SC_ENTER                                        ; �Ƿ�Ϊ <Enter>
        jne dump_debug_record.@01
        ;;
        ;; �л���ʾ AppendMsg �б�
        ;;
        call dump_append_msg_list
        jmp dump_debug_record.loop
        
dump_debug_record.@01:
        cmp al, SC_PGUP                                         ; �Ƿ�Ϊ <PageUp>
        jne dump_debug_record.@1
        
        ;;
        ;; �������Ϸ�ҳ
        ;;
        REX.Wrxb
        cmp DWORD [ebx + DRS.PrevDrs], 0
        je dump_debug_record.@0
        REX.Wrxb
        mov ebx, [ebx + DRS.PrevDrs]                            ; ָ��ǰһ����¼       
        DECv ecx
        REX.Wrxb
        cmp ebx, [ebp + SDA.DrsHeadPtr]                         ; �Ƿ񵽴��¼����
        jne dump_debug_record.loop
        mov ecx, 1
        jmp dump_debug_record.loop
        
dump_debug_record.@1:  
        cmp al, SC_PGDN                                         ; �Ƿ�Ϊ <PageDown>
        jne dump_debug_record.@0
                
        ;;
        ;; �������·�ҳ
        ;;
        REX.Wrxb
        cmp DWORD [ebx + DRS.NextDrs], 0
        je dump_debug_record.@0
        REX.Wrxb
        mov ebx, [ebx + DRS.NextDrs]
        INCv ecx
        REX.Wrxb
        cmp DWORD [ebx + DRS.NextDrs], 0
        jne dump_debug_record.loop
        mov ecx, [ebp + SDA.DrsCount]
        jmp dump_debug_record.loop
        
dump_debug_record.done:        
        pop edx
        pop ebx
        pop ecx
        pop ebp
%endif        
        ret