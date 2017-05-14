;*************************************************
; GuestCrt.asm                                   *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


        bits 32

;------------------------------------------
; GetCurrentRow()
; input:
;       none
; output:
;       none
;------------------------------------------
GetCurrentRow:
        push ebx
        mov eax, Guest.VideoBufferPtr
        mov eax, [eax]
        sub eax, 0B8000h
        mov bl, (80 * 2)
        div bl
        movzx eax, al
        pop ebx
        ret




;------------------------------------------
; GetCurrentCol()
; input:
;       none
; output:
;       none
;------------------------------------------
GetCurrentCol:
        push ebx
        mov eax, Guest.VideoBufferPtr
        mov eax, [eax]
        sub eax, 0B8000h
        mov bl, (80 * 2)
        div bl
        movzx eax, ah
        pop ebx
        ret


        
;-------------------------------------------
; WriteChar()
; input:
;       esi - �ַ�
; output:
;       none
;-------------------------------------------
WriteChar:
        push ebx
        mov ebx, Guest.VideoBufferPtr
        or si, 0F00h
        cmp si, 0F0Ah                                ; LF
        jne WriteChar.@0
        call GetCurrentCol
        neg eax
        add eax, 80 * 2
        add eax, [ebx]
        jmp WriteChar.Done
        
WriteChar.@0:
        mov eax, [ebx]
        cmp eax, 0B9FF0h
        ja WriteChar.Done
        mov [eax], si
        add eax, 2
        
WriteChar.Done:  
        mov [ebx], eax
        pop ebx
        ret
        

;--------------------------------
; PutChar()
; input: 
;       esi - �ַ�
; output:
;       none
;--------------------------------
PutChar:
        and esi, 0FFh
        call WriteChar
        ret


;--------------------------------
; PrintLn()
; input:
;       none
; output:
;       none
;--------------------------------
PrintLn:
        mov si, 10
        call PutChar
        ret
        
        
        
;------------------------------
; PrintBlank()
;       none
; output:
;       none
;--------------------------------
PrintBlank:
        mov si, ' '
        call PutChar
        ret        


;--------------------------------
; PutStr()
; input: 
;       esi - string
; output:
;       none
;--------------------------------
PutStr:
        push ebx
        REX.Wrxb
        mov ebx, esi
        REX.Wrxb
        test ebx, ebx
        jz PutStr.@0

PutStr.@0:        
        mov al, [ebx]
        test al, al
        jz PutStr.Done
        mov esi, eax
        call PutChar
        REX.Wrxb
        INCv ebx
        jmp PutStr.@0

PutStr.Done:
        pop ebx
        ret        




;-----------------------------------------
; HexConvertChar()
; input:
;       esi - hex
; ouput:
;       eax - char
;----------------------------------------
HexConvertChar:
        jmp HexConvertChar.Start
@Char   db '0123456789ABCDEF', 0

HexConvertChar.Start:
        push esi
        and esi, 0Fh
        movzx eax, BYTE [@Char + esi]
        pop esi
        ret



;--------------------------------------
; DumpHex()
; input:
;       esi - value
; output:
;       none
;--------------------------------------
DumpHex:
        push ecx
        push esi
        mov ecx, 8                                        ; 8 �� half-byte
DumpHex.@0:
        rol esi, 4                                        ; ��4λ --> �� 4λ
        mov edi, esi
        call HexConvertChar
        mov esi, eax
        call PutChar
        mov esi, edi
        DECv ecx
        jnz DumpHex.@0
        pop esi
        pop ecx
        ret



;---------------------------------------
; PrintValue()
; input:
;       esi - value
; output:
;       none
;---------------------------------------
PrintValue:
        call DumpHex
        ret


;---------------------------------------
; PrintQword()
; input:
;       esi - low32
;       edi - hi32
; output:
;       none
;---------------------------------------
PrintQword:
        push ebx
        mov ebx, esi
        mov esi, edi
        call DumpHex
        mov esi, ebx
        call DumpHex
        pop ebx
        ret

;---------------------------------------
; PrintHalfByte()
; input:
;       esi - value
; output:
;       none
;---------------------------------------        
PrintHalfByte:
        call HexConvertChar
        mov esi, eax
        call PutChar
        ret




;------------------------
; PrintDecimal()
; input:
;       esi - dword value
; output:
;       none
;-------------------------
PrintDecimal:
        jmp PrintDecimal.Start
        
Quotient        dd      0
Remainder       dd      0
ValueBuffer  times 20   db 0

PrintDecimal.Start:
        push edx
        push ecx
        push ebx
        mov ebx, Quotient
        mov eax, esi                        ; ��ʼ��ֵ
        mov [ebx], eax        
        mov ecx, 10
        mov esi, ValueBuffer + 19
        mov BYTE [esi], 0
        
PrintDecimal.@0:
        DECv esi                             ; ָ�� ValueBuffer
        xor edx, edx
        div ecx                              ; ��/10
        test eax, eax                        ; �� == 0 ?
        cmovz edx, [ebx]
        mov [ebx], eax
        lea edx, [edx + '0']        
        mov [esi], dl                        ; д������ֵ
        jnz PrintDecimal.@0
        
PrintDecimal.Done:
        call PutStr        
        pop ebx
        pop ecx
        pop edx
        ret        
        
        

;----------------------------------------------
; WaitKey:
; input:
;       none
; output:
;       eax - ɨ����
; ������
;       1) �ȴ�����������һ��ɨ����
;       2) wait_a_key()���Ѿ��򿪼���ʱʹ��
;       3��read_keyboard() �ڲ��򿪼��̣������Ѿ���������
;----------------------------------------------
WaitKey:
        push ebp

        ;;
        ;; ��ԭ KeyBufferPtr ֵ
        ;;
        mov ebp, KeyBufferPtr
        mov eax, [ebp]

        ;;
        ;; �ȴ�...
        ;; ֱ�� KeyBufferPtr �����ı�ʱ�˳�!
        ;;       
                
        WAIT_UNTIL_NEQ32         [ebp], eax
        

        ;;
        ;; ������ɨ����
        ;;
        mov esi, [ebp]
        movzx eax, BYTE [esi]

        pop ebp
        ret