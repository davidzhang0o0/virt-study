;*************************************************
;* DoOpcode.asm                                  *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************



;-------------------------------------------------
; DoOpcode48()
; input:
;       esi - buffer of encodes
;       edi - buffer of out
; output:
;       eax - bits 7:0 ���س���ֵ
;             bits 31:8 ������
;-------------------------------------------------
DoOpcode48:
        push ebp
        push ebx
        
%ifdef __X64
        LoadFsBaseToRbp
%else
        mov ebp, [fs: SDA.Base]
%endif

        REX.Wrxb
        mov ebx, [ebp + SDA.DmbBase]
        test DWORD [ebx + DMB.TargetCpuMode], TARGET_CODE64
        jz DoOpcode48.@1
        or DWORD [ebx + DMB.DecodePrefixFlag], DECODE_PREFIX_REX
        mov al, [esi]                                   ; �� encode
        mov [ebx + DMB.PrefixRex], al                   ; ���� REX prefix
        mov eax, DECODE_STATUS_CONTINUE | 1
        jmp DoOpcode48.done
        
DoOpcode48.@1:
        mov esi, InstructionMsg48
        call strcpy
        mov BYTE [edi], ' '
        REX.Wrxb
        INCv edi
        mov esi, Register40
        call strcpy
        mov BYTE [edi], 0
        REX.Wrxb
        INCv edi
        mov eax, 1
        
DoOpcode48.done:
        pop ebx
        pop ebp
        ret



DoOpcodeB0:
        mov eax, DECODE_STATUS_FAILURE
        ret
        
DoOpcodeB1:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeB2:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeB3:
        mov eax, DECODE_STATUS_FAILURE
        ret
        
DoOpcodeB4:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeB5:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeB6:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeB7:
        mov eax, DECODE_STATUS_FAILURE
        ret


;-------------------------------------------------
; DoOpcodeB8()
; input:
;       esi - buffer of encodes
;       edi - buffer of out
; output:
;       eax - bits 7:0 ���س���ֵ
;             bits 31:8 ������
;-------------------------------------------------
DoOpcodeB8:
        push ebx
        
        REX.Wrxb
        mov ebx, esi
        mov eax, DECODE_STATUS_OUTBUFFER
        
        REX.Wrxb
        test edi, edi
        jz DoOpcodeB8.done                              ; Ŀ�� buffer Ϊ��
        
        mov esi, InstructionMsgB8
        call strcpy                                     ; д��ָ����
        mov BYTE [edi], ' '
        REX.Wrxb
        INCv edi
        mov esi, Register40                             ; д��Ĵ�����
        call strcpy
        mov BYTE [edi], ','
        REX.Wrxb
        INCv edi
        mov esi, [ebx + 1]
        call dword_to_string                            ; �����������ַ���
        mov BYTE [edi], 0
        REX.Wrxb
        INCv edi        
        
        mov eax, 5                                      ; ���� encode ����
        
DoOpcodeB8.done:
        pop ebx        
        ret




DoOpcodeB9:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeBA:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeBB:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeBC:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeBD:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeBE:
        mov eax, DECODE_STATUS_FAILURE
        ret

DoOpcodeBF:
        mov eax, DECODE_STATUS_FAILURE
        ret


;-------------------------------------------------
; DoOpcodeCD()
; input:
;       esi - buffer of encodes
;       edi - buffer of out
; output:
;       eax - bits 7:0 ���س���ֵ
;             bits 31:8 ������
;-------------------------------------------------
DoOpcodeCD:
        push ebx        
        REX.Wrxb
        mov ebx, esi
        mov esi, InstructionMsgCD
        call strcpy                                     ; д��ָ����
        mov BYTE [edi], ' '
        REX.Wrxb
        INCv edi        
        REX.Wrxb
        movzx esi, BYTE [ebx + 1]
        call byte_to_string                            ; �����������ַ���
        mov BYTE [edi], 0
        REX.Wrxb
        INCv edi                
        mov eax, 2                                      ; ���� encode ����
        pop ebx
        ret

;-------------------------------------------------
; DoOpcodeC3()
; input:
;       esi - buffer of encodes
;       edi - buffer of out
; output:
;       eax - bits 7:0 ���س���ֵ
;             bits 31:8 ������
;-------------------------------------------------
DoOpcodeC3:
        push ebx        
        REX.Wrxb
        mov ebx, esi
        mov esi, InstructionMsgC3
        call strcpy                                     ; д��ָ����
        mov BYTE [edi], 0
        REX.Wrxb
        INCv edi                
        mov eax, 1                                      ; ���� encode ����
        pop ebx
        ret


;-------------------------------------------------
; DoOpcodeCF()
; input:
;       esi - buffer of encodes
;       edi - buffer of out
; output:
;       eax - bits 7:0 ���س���ֵ
;             bits 31:8 ������
;-------------------------------------------------
DoOpcodeCF:
        mov esi, InstructionMsgCF
        call strcpy                                     ; д��ָ����
        mov BYTE [edi], 0
        REX.Wrxb
        INCv edi                
        mov eax, 1                                      ; ���� encode ����
        ret


        
        
;-------------------------------------------------
; DoOpcodeE8()
; input:
;       esi - buffer of encodes
;       edi - buffer of out
; output:
;       eax - bits 7:0 ���س���ֵ
;             bits 31:8 ������
;-------------------------------------------------
DoOpcodeE8:
        ret        