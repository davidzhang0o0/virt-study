;*************************************************
;* crt.asm                                       *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************



;-----------------------------------------
; clear_4k_page32()����4Kҳ��
; input:  
;       esi: address
; output;
;       none
; ������
;       1) һ���� 4K ҳ��
;       2) ��ַ�� 4K �߽���
;       3) �迪�� SSE ָ��֧��    
;------------------------------------------        
clear_4k_page32:
        push esi
        
        test esi, esi
        mov eax, 4096
        jz clear_4k_page32.done
        
        and esi, 0FFFFF000h
        pxor xmm0, xmm0       
clear_4k_page32.loop:        
        movdqa [esi + eax - 16], xmm0
        movdqa [esi + eax - 32], xmm0
        movdqa [esi + eax - 48], xmm0
        movdqa [esi + eax - 64], xmm0
        movdqa [esi + eax - 80], xmm0
        movdqa [esi + eax - 96], xmm0
        movdqa [esi + eax - 112], xmm0
        movdqa [esi + eax - 128], xmm0
        sub eax, 128
        jnz clear_4k_page32.loop
        
clear_4k_page32.done:
        pop esi
        ret



;-----------------------------------------
; clear_4k_buffer32()���� 4K �ڴ�
; input:  
;       esi: address
; output;
;       none
; ������
;       1) һ���� 4K ҳ��
;       2) ��ַ�� 4K �߽���
;       3) ʹ�� GPI ָ���
;-----------------------------------------
clear_4k_buffer32:
        push esi
        push edi
        mov edi, esi
        mov esi, 1000h
        call zero_memory32
        pop edi
        pop esi
        ret



;-----------------------------------------
; clear_4k_page_n32()���� n�� 4Kҳ��
; input:  
;       esi - address
;       edi - count
; output;
;       none
;------------------------------------------   
clear_4k_page_n32:
        call clear_4k_page32
        add esi, 4096
        dec edi
        jnz clear_4k_page_n32
        ret        


;-----------------------------------------
; clear_4k_buffer_n32()���� n�� 4K �ڴ��
; input:  
;       esi - address
;       edi - count
; output;
;       none
;------------------------------------------ 
clear_4k_buffer_n32:
        call clear_4k_buffer32
        add esi, 4096
        dec edi
        jnz clear_4k_buffer_n32
        ret        
        
        
;-----------------------------------------
; zero_memory32()
; input:
;       esi - size
;       edi - buffer address
; ������
;       ���ڴ���� 0
;-----------------------------------------
zero_memory32:
        push ecx
        
        test edi, edi
        jz zero_memory32.done
        
        xor eax, eax
        
        ;;
        ;; ��� count > 4 ?
        ;;
        cmp esi, 4
        jb zero_memory32.@1
        
        ;;
        ;; ��д���� 4 �ֽ�
        ;;
        mov [edi], eax
        
        ;;
        ;; ��������� DWORD �߽��ϵĲ�ԭ����� 4 - dest & 03
        ;; 1) ���磺[2:0] = 011B��3��
        ;; 2) ȡ���� = 100B��4��
        ;; 3) ��1�� = 101B��5��        
        ;; 4) ��32λ����03�� = 001B��1���������Ϊ 1
        ;;
        mov ecx, esi                                    ; ԭ count
        mov esi, edi                                    ; ԭ dest
        not esi
        inc esi
        and esi, 03                                     ; �� 32 λ���� 03h
        sub ecx, esi                                    ; count = ԭ count - ���

        ;;
        ;; dest ���ϵ����� DWORD �߽�
        ;;
        add edi, esi                                    ; dest = dest + ���
        mov esi, ecx
           
        ;;
        ;; �� 32 λ�£��� DWORD Ϊ��λ
        ;; 
        shr ecx, 2
        rep stosd

zero_memory32.@1:                     
        ;;
        ;; һ�� 1 �ֽڣ�д��ʣ���ֽ���
        ;;
        mov ecx, esi
        and ecx, 03h
        rep stosb
        
zero_memory32.done:        
        pop ecx
        ret   
        


;-------------------------------------------------
; strlen32(): ��ȡ�ַ�������
; input:
;       esi - string
; output:
;       eax - length of string
;-------------------------------------------------
strlen32:
        push ecx
        xor eax, eax
        ;;
        ;; ����� string = NULL ʱ������ 0 ֵ
        ;;
        test esi, esi
        jz strlen32.done
        
        ;;
        ;; �����Ƿ�֧�� SSE4.2 ָ��Լ��Ƿ��� SSE ָ��ִ��
        ;; ѡ��ʹ�� SSE4.2 �汾�� strlen ָ��
        ;;
        cmp DWORD [gs: PCB.SSELevel], SSE4_2
        jb strlen32.legacy
        test DWORD [gs: PCB.InstructionStatus], INST_STATUS_SSE
        jnz sse4_strlen + 1                             ; ת��ִ�� sse4_strlen() 


strlen32.legacy:

        ;;
        ;; ʹ�� legacy ��ʽ
        ;;
        xor ecx, ecx
        mov edi, esi
        dec ecx                                         ; ecx = 0FFFFFFFFh
        repne scasb                                     ; ѭ������ 0 ֵ
        sub eax, ecx                                    ; 0 - ecx
        dec eax
strlen32.done:
        pop ecx
        ret        
        
        


;-------------------------------------------------
; memcpy32(): �����ڴ��
; input:
;       esi - source
;       edi - dest 
;       ecx - count
; output:
;       none
;-------------------------------------------------
memcpy32:
        push ecx
        mov eax, ecx
        shr ecx, 2
        rep movsd
        mov ecx, eax
        and ecx, 3
        rep movsb
        pop ecx
        ret        
        
;-------------------------------------------------
; strcopy()
; input:
;       esi - sourece
;       edi - dest
; output:
;       none
;-------------------------------------------------
strcpy:
        REX.Wrxb
        test esi, esi
        jz strcpy.done
        REX.Wrxb
        test edi, edi
        jz strcpy.done        
strcpy.loop:        
        mov al, [esi]
        test al, al
        jz strcpy.done
        mov [edi], al
        REX.Wrxb
        INCv esi
        REX.Wrxb
        INCv edi
        jmp strcpy.loop
strcpy.done:        
        ret




;-------------------------------------------------
; bit_swap32(): ���� dword �ڵ�λ
; input:
;       esi - source
; output:
;       eax - dest
; ����:
;       dest[31] <= source[0]
;       ... ...
;       dest[0]  <= source[31]
;-------------------------------------------------        
bit_swap32:
        push ecx
        mov ecx, 32
        xor eax, eax
        
        ;;
        ;; ѭ���ƶ� 1 λֵ
        ;;
bit_swap32.loop:        
        shl esi, 1                              ; esi ��λ�Ƴ��� CF
        rcr eax, 1                              ; CF ���� eax ��λ
        ;;
        ;; ע�⣺
        ;;      1) ʹ�� FF /1 �� dec ָ������� 64-bit ģʽ�±�Ϊ REX prefix
        ;;
        DECv ecx
        jnz bit_swap32.loop
        pop ecx
        ret


;-------------------------------------------------
; clear_screen()
; input:
;       esi - row
;       edi - column
; output:
;       none
; ������
;       1) �� (row, column) λ�ÿ�ʼ�����Ļ
;-------------------------------------------------
clear_screen:
        push ebp
        push ecx
        push edx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif   

        mov eax, 80 * 2
        mul esi
        lea ecx, [eax + edi * 2]                        ; ecx = (row * 80 + column) * 2
        mov esi, 80 * 2 * 25                            ; ������Ļ size
        sub esi, ecx                                    ; ʣ�� size        
        REX.Wrxb
        mov edi, [ebp + PCB.LsbBase]
        REX.Wrxb
        mov edi, [edi + LSB.LocalVideoBufferHead]       
        REX.Wrxb
        add edi, ecx
        call zero_memory
        
        ;;
        ;; ���ӵ�н��㣬���� target video buffer
        ;;
        mov eax, [ebp + PCB.ProcessorIndex]             ; eax = index
        REX.Wrxb
        mov ebp, [ebp + PCB.SdaBase]                    ; ebp = SDA
        cmp [ebp + SDA.InFocus], eax
        jne clear_screen.done
        mov esi, 80 * 2 * 25
        sub esi, ecx
        REX.Wrxb
        mov edi, [ebp + SDA.VideoBufferHead]
        REX.Wrxb
        add edi, ecx
        call zero_memory
        
clear_screen.done:        
        pop edx
        pop ecx
        pop ebp
        ret



;-------------------------------------------------
; video_buffer_row():
; input:
;       none
; output:
;       eax - row
; ����:
;       1) �õ� video buffer ��ǰλ�õ��к�
;       2) ���޸� esi ֵ���Ա����ʹ��
;-------------------------------------------------
video_buffer_row:
        push ebx
        push edx
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif   
        
        REX.Wrxb
        mov ebx, [ebp + PCB.LsbBase]                    ; ebx = LSB
        REX.Wrxb
        mov eax, [ebx + LSB.LocalVideoBufferPtr]        ; eax = LocalVideoBufferPtr
        REX.Wrxb
        sub eax, [ebx + LSB.LocalVideoBufferHead]       ; VideoBufferPtr - VideoBufferHead
        mov ebx, 80 * 2
        xor edx, edx
        div ebx                                          ; (VideoBufferPtr - VideoBufferHead) / (80 * 2)
        pop ebp
        pop edx
        pop ebx
        ret
        


        
        
;-------------------------------------------------
; video_buffer_column():
; input:
;       none
; output:
;       eax - column
; ����:
;       1) �õ� video buffer ��ǰλ�õ��к�
;       2) ���޸� esi ֵ���Ա����ʹ��
;-------------------------------------------------      
video_buffer_column:
        push ebx
        push edx
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif   

        REX.Wrxb
        mov ebx, [ebp + PCB.LsbBase]                    ; ebx = LSB        
        REX.Wrxb
        mov eax, [ebx + LSB.LocalVideoBufferPtr]        ; eax = LocalVideoBufferPtr
        REX.Wrxb
        sub eax, [ebx + LSB.LocalVideoBufferHead]       ; VideoBufferPtr - VideoBufferHead
        mov ebx, 80 * 2
        xor edx, edx
        div ebx                                         ; (VideoBufferPtr - VideoBufferHead) / (80 * 2)        
        mov eax, edx                                    ; edx = column
        pop ebp 
        pop edx
        pop ebx        
        ret  






;-------------------------------------------------
; set_video_buffer()
; input:
;       esi - row
;       edi - column
; output:
;       none
; ������
;       1) ���� video buffer λ��
;-------------------------------------------------
set_video_buffer:
        push ebp
        push ebx
        push ecx
        push edx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 
        
        ;;
        ;; ����Ƿ񳬳���Χ
        ;;
        cmp esi, 25
        jae set_video_buffer.done
        cmp edi, 80
        jae set_video_buffer.done
        
        ;;
        ;; eax = (row * 80 + column) * 2
        ;;
        mov eax, 80 * 2
        mul esi
        REX.Wrxb
        lea eax, [eax + edi * 2]
        
        ;;
        ;; TargetBufferPtr = (row * 80 + column) * 2 + B8000h
        ;;
        REX.Wrxb
        lea ecx, [eax + 0B8000h]
        
        ;;
        ;; VideoBufferPtr = (row * 80 + column) * 2 + VideoBufferHead
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.LsbBase]                    ; ebx = LSB
        REX.Wrxb
        add eax, [ebx + LSB.LocalVideoBufferHead]
        
        ;;
        ;; ���� VideoBufferPtr
        ;;
        REX.Wrxb
        mov [ebx + LSB.LocalVideoBufferPtr], eax
        
        ;;
        ;; �����ǰ������ӵ�н��㣬����� target video buffer
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.SdaBase]                    ; ebx = SDA
        mov esi, [ebp + PCB.ProcessorIndex]
        cmp [ebx + SDA.InFocus], esi
        jne set_video_buffer.done

        ;;
        ;; ���� target video buffer ptr
        ;;
        REX.Wrxb
        mov [ebx + SDA.VideoBufferPtr], ecx
        
set_video_buffer.done:        
        pop edx
        pop ecx
        pop ebx
        pop ebp
        ret        
        


                
        
;-------------------------------------------------
; check_new_line()
; input:
;       esi - string
; output:
;       0 - no, otherwise yes.
; ����:
;       �����ṩ���ַ���������Ƿ���Ҫת��
;-------------------------------------------------          
check_new_line:
        push ebp
        push ecx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        call strlen
        mov ecx, eax                            ; �ַ�������
        shl ecx, 1                              ; length * 2
        call video_buffer_column
        neg eax
        add eax, 80 * 2
        cmp eax, ecx
        jae check_new_line.done
        ;;
        ;; ����
        ;;
        REX.Wrxb
        mov ecx, [ebp + PCB.LsbBase]
        REX.Wrxb
        add [ecx + LSB.LocalVideoBufferPtr], eax
        
        ;;
        ;; �����ǰӵ�н��㣬����� target video buffer
        ;;
        mov ecx, [ebp + PCB.ProcessorIndex]
        REX.Wrxb
        mov ebp, [ebp + PCB.SdaBase]
        cmp [ebp + SDA.InFocus], ecx
        jne check_new_line.done
        
        add [ebp + SDA.VideoBufferPtr], eax
  
check_new_line.done:        
        pop ecx
        pop ebp
        ret        



        


;-------------------------------------------------
; write_char()
; input:
;       esi - �ַ�
; output:
;       none
; ����:
;       1) �� video buffer д���ṩ��һ���ַ�
;       2) �� 64-bit ģʽ�¸���
;-------------------------------------------------          
write_char:
        push ebx
        push ecx
        push edx
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif
        
        or si, 0F00h                                            ; si = �ַ�
        
        ;;
        ;; ����ǰ LocalVideoBufferPtr
        ;;
        REX.Wrxb
        mov ebx, [ebp + PCB.LsbBase]                            ; ebx = LSB        
        REX.Wrxb
        mov ecx, [ebx + LSB.LocalVideoBufferPtr]                ; LocalVideoBufferPtr
        REX.Wrxb
        mov edi, [ebx + LSB.LocalVideoBufferHead]               ; edi = BufferHead
        REX.Wrxb
        sub ecx, edi                                            ; ecx = index
        
        ;;
        ;; ����Ƿ�ӵ�н���
        ;;
        mov eax, SDA.InFocus
        mov eax, [fs: eax]
        cmp eax, [ebp + PCB.ProcessorIndex]
        sete dl                                                 ; dl = 1 ʱ��ӵ�н���
        
        REX.Wrxb
        mov ebp, [ebp + PCB.SdaBase]                            ; ebp = SDA
        
        
        ;;
        ;; ����Ƿ�Ϊ���з�
        ;;
        cmp si, 0F0Ah
        jne write_char.@1

        ;;
        ;; �����У�
        ;; 1) ����������д��λ�ã����� video buffer ָ��Ϊ��һ���ַ���дλ��
        ;;
        call video_buffer_column                                ; �õ���ǰ column ֵ
        neg eax
        add eax, 80 * 2                                         ; ���в�� = (80 * 2) - column
        add ecx, eax                                            ; index + ���в��
        jmp write_char.update

write_char.@1:
        
        ;;
        ;; ����Ƿ�Ϊ HT ����ˮƽTAB����
        ;;
        cmp si, 0F09h
        jne write_char.next
        ;;
        ;; ����TAB����
        ;; �����һ���ַ��Ƿ�Ϊ TAB ��
        ;; 1) �ǣ�buffer pointer ���� 10h
        ;; 2) ��buffer pointer ���� 0Fh
        ;;
        add ecx, 0Fh
        cmp BYTE [ebx + LSB.LocalVideoBufferLastChar], 09
        jne write_char.@2
        INCv ecx
        
write_char.@2:        
        ;;
        ;; ������ 8 * 2 ���ַ��߽�
        ;;
        and ecx, 0FFFFFFF0h
        jmp write_char.update
        
        
write_char.next:        
        ;;
        ;; ����Ƿ񳬹�һ����25 * 80)
        ;;
        cmp ecx, (25 * 80 * 2)
        jae write_char.update
        
        ;;
        ;; д video buffer
        ;;
        mov [edi + ecx], si                                     ; �� BufferHead[Index] д���ַ�
        
        ;;
        ;; �����ǰӵ�н��㣬д�� target video buffer
        ;;
        test dl, dl
        jz write_char.next.@0
        REX.Wrxb
        mov eax, [ebp + SDA.VideoBufferHead]
        mov [eax + ecx], si
        
write_char.next.@0:        
        add ecx, 2                                              ; ָ����һ���ַ�λ��
        
        
write_char.update:        
        ;;
        ;; ���� video buffer ָ�룬ָ��ָһ���ַ�λ��
        ;;
        REX.Wrxb
        add edi, ecx
        REX.Wrxb
        mov [ebx + LSB.LocalVideoBufferPtr], edi                ; ���� Buffer Ptr
        mov [ebx + LSB.LocalVideoBufferLastChar], si            ; ������һ���ַ�
        
        ;;
        ;; �����ǰӵ�н��㣬����� target video buffer
        ;;
        test dl, dl
        jz write_char.done
               
        ;; 
        ;; ���� target video buffer ��¼
        ;;
        REX.Wrxb
        add ecx, [ebp + SDA.VideoBufferHead]
        mov [ebp + SDA.VideoBufferLastChar], si
        REX.Wrxb
        mov [ebp + SDA.VideoBufferPtr], ecx
        
write_char.done:
        pop ebp
        pop edx
        pop ecx
        pop ebx
        ret
        



        
        
;-------------------------------------------------
; putc()
; input:
;       esi - �ַ�
; output:
;       none
; ����:
;       1) �� video buffer ��ӡһ���ַ�
;-------------------------------------------------        
putc:
        and esi, 0FFh
        jmp write_char




;-------------------------------------------------
; println()
; input:
;       none
; output:
;       none
; ����:
;       ��ӡ����
;------------------------------------------------
println:
        mov si, 10
        jmp putc
        
        
;-------------------------------------------------
; print_tab()
; input:
;       none
; output:
;       none
; ����:
;       ��ӡ TAB ��
;------------------------------------------------
print_tab:
        mov si, 09
        jmp putc


;-------------------------------------------------
; printblank()
; input:
;       none
; output:
;       none
; ����:
;       ��ӡһ���ո�
;-------------------------------------------------   
printblank:
        mov si, ' '
        jmp putc
        
        
           
;-------------------------------------------------
; print_chars()
; input:
;       esi - char
;       edi - count
; output:
;       none
; ������
;       1) ��ӡ���ɸ��ַ�
;-------------------------------------------------
print_chars:
        push ebx
        push ecx
        mov ebx, esi
        mov ecx, edi
print_chars.@0:   
        mov esi, ebx     
        call putc
        ;;
        ;; ע�⣺
        ;;      1) ʹ�� FF /1 �� dec ָ������� 64-bit ģʽ�±�Ϊ REX prefix
        ;;
        DECv ecx    
        jnz print_chars.@0
        pop ecx
        pop ebx
        ret


;-------------------------------------------------
; print_space()
; input:
;       esi - ����
; output:
;       none
; ����:
;       ��ӡ�����ո�
;-------------------------------------------------
print_space:       
        mov edi, esi
        mov esi, ' '
        jmp print_chars
        


;-------------------------------------------------
; puts()
; input:
;       esi - string
; output:
;       none
; ����:
;       ��ӡ�ַ���
;-------------------------------------------------
puts:
        push ebx
        push ecx
        
        ;;
        ;; �ַ� flag
        ;;
        xor ecx, ecx
        
        REX.Wrxb
        mov ebx, esi
        REX.Wrxb
        test esi, esi
        jz puts.done
        
puts.loop:
        mov al, [ebx]
        test al, al
        jz puts.done
        
        ;;
        ;; �����һ���ַ��Ƿ�Ϊ '\'
        ;;
        test ecx, CHAR_FLAG_BACKSLASH
        jz puts.@0
       
        ;;
        ;; ����Ƿ�Ϊ n
        ;;
        cmp al, 'n'
        je puts.@01
        
        mov esi, '\'
        call putc
        mov al, [ebx]
        and ecx, ~CHAR_FLAG_BACKSLASH
        jmp puts.@1        
        
puts.@01:
        mov esi, 10
        call putc
        and ecx, ~CHAR_FLAG_BACKSLASH
        jmp puts.next        


puts.@0:        
        ;;
        ;; ����Ƿ�Ϊ '\' �ַ�
        ;;
        cmp al, '\'
        jne puts.@1
        
        or ecx, CHAR_FLAG_BACKSLASH                             ; ��¼��б��
        jmp puts.next


puts.@1:
        ;;
        ;; ��ӡ�ַ�
        ;;        
        mov esi, eax
        call putc 

puts.next:        
        ;;
        ;; ע�⣺
        ;;      1) ʹ�� FF /0 �� inc ָ������� 64-bit ģʽ�±�Ϊ REX prefix
        ;;        
        REX.Wrxb
        INCv ebx
        jmp puts.loop
        
puts.done:     
        pop ecx   
        pop ebx
        ret
        
        


;-------------------------------------------------
; hex_to_char()
; input:
;       esi - hex number
; output:
;       eax - char
; ����:
;       ��ʮ����������תΪ�ַ�
;-------------------------------------------------        
hex_to_char:
        mov eax, esi
        and eax, 0Fh
        movzx eax, BYTE [crt.chars + eax]        
        ret
        

;-------------------------------------------------
; byte_to_string():
; intput:
;       esi - byte
;       edi - buffer
; output:
;       none
;-------------------------------------------------
byte_to_string:
        REX.Wrxb
        test edi, edi
        jz byte_to_string.done        
        mov eax, esi
        shr eax, 4
        and eax, 0Fh
        movzx eax, BYTE [crt.chars + eax]  
        mov [edi], al
        REX.Wrxb
        INCv edi      
        and esi, 0Fh
        movzx eax, BYTE [crt.chars + esi]
        mov [edi], al
        REX.Wrxb
        INCv edi      
        mov BYTE [edi], 'H'
        REX.Wrxb
        INCv edi        
byte_to_string.done:        
        ret
        
                
;-------------------------------------------------
; dword _to_string():
; intput:
;       esi - DWORD
;       edi - buffer
; output:
;       none
;-------------------------------------------------
dword_to_string:
        push ecx
        REX.Wrxb
        test edi, edi
        jz dword_to_string.done
        mov ecx, 8
dword_to_string.loop:
        shld eax, esi, 4
        shl esi, 4
        and eax, 0Fh
        movzx eax, BYTE [crt.chars + eax]  
        mov [edi], al
        REX.Wrxb
        INCv edi      
        DECv ecx
        jnz dword_to_string.loop
        mov BYTE [edi], 'H'
        REX.Wrxb
        INCv edi
dword_to_string.done:        
        pop ecx
        ret



;-------------------------------------------------
; print_hex_value()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡʮ��������
;-------------------------------------------------
print_hex_value:
        push ecx
        push ebx
        push esi
        mov ecx, 8
print_hex_value.loop:        
        rol esi, 4
        mov ebx, esi
        call hex_to_char
        mov esi, eax
        call putc
        mov esi, ebx
        ;;
        ;; ע�⣺
        ;;      1) ʹ�� FF /1 �� dec ָ������� 64-bit ģʽ�±�Ϊ REX prefix
        ;;
        DECv ecx        
        jnz print_hex_value.loop
        pop esi
        pop ebx
        pop ecx
        ret



;-------------------------------------------------
; print_half_byte()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡ����ֽڣ�4λֵ��
;-------------------------------------------------
print_half_byte:
        call hex_to_char
        mov esi, eax
        call putc
        ret
        

;-------------------------------------------------
; print_decimal()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡʮ������
;-------------------------------------------------
print_decimal32:
print_dword_decimal:
        push ebp
        push edx
        push ecx
        push ebx
        
        REX.Wrxb
        mov ebp, esp
        REX.Wrxb
        sub esp, 64
        
        ;;
        ;; ������������:
        ;; 1) quotient: ��������ÿ�γ�10�����
        ;; 2) digit_array: ��������ÿ�γ�10��������ַ���
        ;;
%define QUOTIENT_OFFSET                 8
%define DIGIT_ARRAY_OFFSET              9

        mov eax, esi
        REX.Wrxb
        lea ebx, [ebp - QUOTIENT_OFFSET]
        mov [ebx], eax                                  ; ��ʼ��ֵ
        mov BYTE [ebp - DIGIT_ARRAY_OFFSET], 0          ; 0
        mov ecx, 10                                     ; ����
        
        ;;
        ;; ָ������β���������������ǰд
        ;;
        REX.Wrxb
        lea esi, [ebp - DIGIT_ARRAY_OFFSET]

print_decimal.loop:
        REX.Wrxb
        DECv esi                                ; ָ����һ��λ�ã���ǰд
        xor edx, edx
        div ecx                                 ; value / 10
        
        ;;
        ;; ������Ƿ�Ϊ 0��Ϊ 0 ʱ���� 10 ����
        ;;
        test eax, eax
        cmovz edx, [ebx]
        mov [ebx], eax
        lea edx, [edx + '0']                    ; ����ת��Ϊ�ַ���ʹ�� lea ָ�����ʹ�� add ָ����ı�eflags)
        mov [esi], dl                           ; д�������ַ�
        jnz print_decimal.loop
        
        ;;
        ;; �����ӡ�����ִ�
        ;;
        call puts
        
        
%undef QUOTIENT_OFFSET
%undef DIGIT_ARRAY_OFFSET

        REX.Wrxb
        mov esp, ebp        
        pop ebx
        pop ecx
        pop edx
        pop ebp
        ret




;---------------------------------------------------------------
; print_dword_float()
; input:
;       esi - ��������ֵַ��������ֵ��
; output:
;       none
; ����:
;       esi �ṩ��Ҫ��ӡ�������ĵ�ַ�����������ص� FPU stack ��
;--------------------------------------------------------------
print_dword_float:
        fnsave [gs: PCB.FpuStateImage]
        finit
        fld DWORD [esi]
        call print_float
        frstor [gs: PCB.FpuStateImage]
        ret



;---------------------------------------------------------------
; print_qword_float()
; input:
;       esi - ��������ֵַ��˫����ֵ��
; output:
;       none
; ����:
;       esi �ṩ��Ҫ��ӡ�������ĵ�ַ�����������ص� FPU stack ��
;--------------------------------------------------------------
print_qword_float:
        fnsave [gs: PCB.FpuStateImage]
        finit
        fld QWORD [esi]
        call print_float
        frstor [gs: PCB.FpuStateImage]
        ret


;---------------------------------------------------------------
; print_tword_float()
; input:
;       esi - ��������ֵַ����չ˫����ֵ��
; output:
;       none
; ����:
;       esi �ṩ��Ҫ��ӡ�������ĵ�ַ�����������ص� FPU stack ��
;--------------------------------------------------------------
print_tword_float:
        fnsave [gs: PCB.FpuStateImage]
        finit
        fld TWORD [esi]
        call print_float
        frstor [gs: PCB.FpuStateImage]
        ret
        
        
        


;-------------------------------------------------
; print_float()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡ��������С����ǰ��ֵ
;-------------------------------------------------
print_float:
        ;;
        ;; ׼�����������س���ֵ
        ;;
        fld TWORD [crt.float_const10]                   ; ���ظ����� 10.0 ֵ��
        fld1                                            ; ���ظ����� 1
        fld st2                                         ; ���� value �� st0
        
        ;;
        ;; ��ǰ FPU stack ״̬��
        ;; ** 1) st0    - float value
        ;; ** 2) st1    - 1.0
        ;; ** 3) st2    - 10.0
        ;;                
        fprem                                           ; st0/st1��ȡ����ֵ
        fld st3                                         ; ���� float value
        fsub st0, st1                                   ; st0 �Ľ��ΪС����ǰ���ֵ
        
        ;;
        ;; �����ȴ�ӡС����ǰ���ֵ
        ;; 
        call print_point
        
        mov DWORD [crt.point], 0
        
        ;;
        ;; ��ǰ FPU stack ״̬��
        ;; st(2) = 10.0
        ;; st(1) = 1.0
        ;; st(0) = ����ֵ 
        ;;

print_float.loop:
        fldz
        fcomip st0, st1                                 ; ��������Ƿ�Ϊ 0
        jz print_float.next
        fmul st0, st2                                   ; ���� * 10
        fld st1                                         ; 1.0
        fld st1                                         ; ���� * 10
        fprem                                           ; ȡ����
        fld st2
        fsub st0, st1
        fistp DWORD [crt.value]
        mov esi, [crt.value]
        call print_dword_decimal                        ; ��ӡֵ    
        mov DWORD [crt.point], 1
        fxch st2
        fstp DWORD [crt.value]
        fstp DWORD [crt.value]        
        jmp print_float.loop

print_float.next:
        cmp DWORD [crt.point], 1
        je print_float.done
        mov esi, '0'
        call putc

print_float.done:
        ret




;-------------------------------------------------
; print_point()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡ��������С����ǰ��ֵ
;-------------------------------------------------
print_point:
        push ebx
        lea ebx, [crt.digit_array + 98]
        mov BYTE [ebx], '.'

print_point.loop:
        ;;
        ;; ��ǰ״̬��
        ;; st(3) = 10.0
        ;; st(2) = 1.0
        ;; st(1) = ����ֵ
        ;; st(0) = point ֵ
        ;;
        dec ebx
        fdiv st0, st3                           ; value / 10
        fld st2
        fld st1
        fprem                                   ; ������
        fsub st2, st0
        fmul st0, st5
        fistp DWORD [crt.value]
        mov eax, [crt.value]
        add eax, 30h
        mov BYTE [ebx], al  
        fstp DWORD [crt.value]      
        fldz
        fcomip st0, st1                         ; ����С�� 0
        jnz print_point.loop

print_point.done:        
        fstp DWORD [crt.value]
        mov esi, ebx
        call puts
        pop ebx
        ret




;-------------------------------------------------
; print_byte_value()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡһ�� byte ֵ
;-------------------------------------------------
print_byte_value:
        push ebx
        push esi
        mov ebx, esi
        shr esi, 4
        call hex_to_char
        mov esi, eax
        call putc
        mov esi, ebx
        call hex_to_char
        mov esi, eax
        call putc
        pop esi
        pop ebx
        ret        


;-------------------------------------------------
; print_word_value()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡһ�� word ֵ
;-------------------------------------------------
print_word_value:
        push ebx
        push esi
        mov ebx, esi
        shr esi, 8
        call print_byte_value
        mov esi, ebx
        call print_byte_value
        pop esi                
        pop ebx
        ret  


;-------------------------------------------------
; print_dword_value()
; input:
;       esi - value
; output:
;       none
; ����:
;       ��ӡһ�� dword ֵ
;-------------------------------------------------        
print_dword_value:
        push ebx
        push esi
        mov ebx, esi
        shr esi, 16
        call print_word_value
        mov esi, ebx
        call print_word_value
        pop esi
        pop ebx
        ret
        

;-------------------------------------------------
; print_qword_value()
; input:
;       edi:esi - 64 λ value
; output:
;       none
; ����:
;       ��ӡһ�� qword ֵ
;-------------------------------------------------         
print_qword_value:
        push ebx
        push esi
        mov ebx, esi
        mov esi, edi
        call print_dword_value
        mov esi, ebx
        call print_dword_value
        pop esi
        pop ebx
        ret  
        
        
;-------------------------------------------------
; is_letter()
; input:
;       esi - �ַ�
; output:
;       1 - yes, 0 - no
; ����:
;       �ж��ַ��Ƿ�Ϊ��ĸ
;------------------------------------------------- 
is_letter:
        and esi, 0FFh
        cmp esi, DWORD 'z'
        setbe al
        ja is_letter.done
        cmp esi, DWORD 'A'
        setae al
        jb is_letter.done
        cmp esi, DWORD 'Z'
        setbe al
        jbe is_letter.done
        cmp esi, DWORD 'a'
        setae al
is_letter.done:
        movzx eax, al
        ret
        
        
;-------------------------------------------------
; is_lowercase()
; input:
;       esi - �ַ�
; output:
;       1 - yes, 0 - no
; ����:
;       �ж��ַ��Ƿ�ΪСд��ĸ
;------------------------------------------------- 
is_lowercase:
        and esi, 0FFh
        cmp esi, DWORD 'z'
        setbe al        
        ja is_lowercase.done
        cmp esi, DWORD 'a'
        setae al
is_lowercase.done:
        movzx eax, al
        ret


;-------------------------------------------------
; is_uppercase()
; input:
;       esi - �ַ�
; output:
;       1 - yes, 0 - no
; ����:
;       �ж��ַ��Ƿ�Ϊ��д��ĸ
;-------------------------------------------------
is_uppercase:
        and esi, 0FFh
        cmp esi, DWORD 'Z'
        setbe al        
        ja is_uppercase.done
        cmp esi, DWORD 'A'
        setae al
is_uppercase.done:
        movzx eax, al        
        ret
        
        
 
;-------------------------------------------------
; is_digit()
; input:
;       esi - �ַ�
; output:
;       1 - yes, 0 - no
; ����:
;       �ж��ַ��Ƿ�Ϊ����
;-------------------------------------------------
is_digit:
        and esi, 0FFh
        xor eax, eax
        cmp esi, DWORD '0'
        setae al
        jb is_digit.done        
        cmp esi, DWORD '9'
        setbe al
is_digit.done:        
        ret




;-------------------------------------------------
; lower_to_upper()
; input:
;       esi - �ַ�
; output:
;       eax - ���
; ����:
;       Сд��ĸת��Ϊ��д��ĸ
;-------------------------------------------------
lower_to_upper:
        call is_lowercase
        test eax, eax
        jz lower_to_upper.done        
        mov eax, 'a' - 'A'
        neg eax
lower_to_upper.done:        
        add eax, esi
        ret


;-------------------------------------------------
; upper_to_lower()
; input:
;       esi - �ַ�
; output:
;       eax - ���
; ����:
;       ��д��ĸת��ΪСд��ĸ
;-------------------------------------------------
upper_to_lower:
        call is_uppercase
        test eax, eax
        jz upper_to_lower.done
        mov eax, 'a' - 'A'
upper_to_lower.done:
        add eax, esi
        ret


;-------------------------------------------------
; letter_convert()
; input:
;       esi - �ַ�
;       edi - ѡ��1: ת��Ϊ��д��0: ת��ΪСд��
; output:
;       eax - ���
; ����:
;       ����ѡ�����ת��
;-------------------------------------------------
letter_convert:
        test edi, edi
        mov edi, lower_to_upper
        mov eax, upper_to_lower
        cmovz eax, edi
        jmp eax




;-------------------------------------------------
; lowers_to_uppers()
; input:
;       esi - Դ����ַ
;       edi - Ŀ�괮��ַ
; output:
;       none
; ����:
;       Сд��ת��Ϊ��д��
;-------------------------------------------------
lowers_to_uppers:
        mov eax, lower_to_upper                         ; Сдת��д����
        jmp do_string_convert


;-------------------------------------------------
; uppers_to_lowers()
; input:
;       esi - Դ����ַ
;       edi - Ŀ�괮��ַ
; output:
;       none
; ����:
;       ��д��ת��ΪСд��
;-------------------------------------------------
uppers_to_lowers:
        mov eax, lower_to_upper                         ; ��дתСд����


do_string_convert:
        push ecx
        push edx
        ;;
        ;; ���Դ��/Ŀ�괮��ַ
        ;;
        test esi, esi
        jz do_string_convert.done
        test edi, edi
        jz do_string_convert.done
        
        mov ecx, esi
        mov edx, edi
        mov edi, eax
        
        ;;
        ;; ����ַ�����ת��
        ;;
do_string_convert.loop:
        movzx esi, BYTE [ecx]
        test esi, esi
        jz do_string_convert.done
        call edi                                        ; ����ת������
        mov [edx], al
        inc edx
        inc ecx
        jmp do_string_convert.loop
        
do_string_convert.done:        
        pop edx
        pop ecx
        ret



;-------------------------------------------------
; dump_encodes()
; input:
;       esi - ��Ҫ��ӡ�ĵ�ַ
;       edi - �ֽ���
; output:
;       none
; ����:
;       ���ṩ�ĵ�ַ�ڵ��ֽڴ�ӡ����
;-------------------------------------------------
dump_encodes:
        push ecx
        push ebx
        mov ebx, esi
        mov ecx, edi
dump_encodes.loop:        
        movzx esi, BYTE [ebx]
        call print_byte_value
        call printblank
        inc ebx
        dec ecx
        jnz dump_encodes.loop
        pop ebx
        pop ecx
        ret



;-------------------------------------------------
; puts_with_select()
; input:
;       esi - �ַ���
;       edi - select code��select[0] = 1: ��д��0 : Сд��
; output:
;       none
; ������
;       �����ṩ�� select[0] ѡ���ӡ��д��Сд
;       
;-------------------------------------------------
puts_with_select:
        push ebx
        push edx
        mov ebx, esi
        test esi, esi
        jz puts_with_select.done
        
        ;;
        ;; ѡ����Ӧת������
        ;;
        bt edi, 0
        mov edx, lower_to_upper
        mov eax, upper_to_lower
        cmovc edx, eax
        
        ;;
        ;; ��ת�����ӡ
        ;;
puts_with_select.loop:        
        movzx esi, BYTE [ebx]
        test esi, esi
        jz puts_with_select.done
        call edx
        mov esi, eax
        call putc
        inc ebx
        jmp puts_with_select.loop
        
puts_with_select.done:        
        pop edx
        pop ebx
        ret





;-------------------------------------------------
; dump_string_with_mask()
; input:
;       esi - mask flags ֵ�����32λ��
;       edi - �ַ�������
; output:
;       none
; ����:
;       �����ṩ�� mask flags ֵ������ӡ edi �ڵ�ֵ
;       1) mask flags ��λ�����ӡ��д��
;       2) mask flags ��λ�����ӡСд��
; ʾ����
;       CPUID.01H:EDX ���� 01 leaf �Ĺ���֧��λ
;       mov esi, edx
;       mov edi, edx_flags
;       call print_string_with_mask
;-------------------------------------------------
dump_string_with_mask:
        push ebx
        push edx
        push ecx
        mov edx, esi
        mov ebx, edi
dump_string_with.loop:        
        ;;
        ;; ȡ mask flags �� MSB λ�ŵ� edi LSB �У���Ϊ select code
        ;;
        shl edx, 1
        rcr edi, 1
        ;;
        ;; ����ַ��������ڵĽ�����־ -1
        ;;
        mov ecx, [ebx]                          ; ���ַ���ָ��
        cmp ecx, -1
        je dump_string_with_mask.done
        mov esi, ecx
        call check_new_line                     ; ����Ƿ���Ҫ����
        mov esi, ecx
        call puts_with_select                   ; ѡ���ӡ��д/Сд
        call printblank                         ; ��ӡ�ո�
        add ebx, 4
        jmp dump_string_with.loop
dump_string_with_mask.done:
        pop ecx
        pop edx
        pop ebx
        ret        
        
  

;-------------------------------------------------
; subtract64()
; input:
;       edx:eax - ������
;       ecx:ebx - ����
; output:
;       edx:eax - ���
;-------------------------------------------------        
subtract64:
sub64:
        sub eax, ebx
        sbb edx, ecx
        ret

;-------------------------------------------------
; subtract64_with_address()
; input:
;       esi - ��������ַ
;       edi - ������ַ
; output:
;       edx:eax - ���
;-------------------------------------------------        
subtract64_with_address:
        mov eax, [esi]
        sub eax, [edi]
        mov edx, [esi + 4]
        sbb edx, [edi + 4]        
        ret
        
;-------------------------------------------------
; decrement64(): 64 λ�� 1
; input:
;       edx:eax - ������
; output:
;       edx:eax - ���
;-------------------------------------------------
decrement64:
dec64:
        sub eax, 1
        sbb edx, 0
        ret  
        

        
;-------------------------------------------------
; addition64()
; input:
;       edx:eax - ������
;       ecx:ebx - ����
; output:
;       edx:eax - ���
;-------------------------------------------------  
addition64:
add64:
        add eax, ebx
        adc edx, ecx
        ret


;-------------------------------------------------
; addition64_with_address()
; input:
;       esi - ��������ַ
;       edi - ������ַ
; output:
;       edx:eax - ���
;-------------------------------------------------        
addition64_with_address:
        mov eax, [esi]
        sub eax, [edi]
        mov edx, [esi + 4]
        sbb edx, [edi + 4]        
        ret


;------------------------------------------------- 
; increment64(): 64 λ�� 1
; input:
;       edx:eax - ������
; output:
;       edx:eax - ���
;------------------------------------------------- 
increment64:
inc64:
        add eax, 1
        adc edx, 0
        ret
        


;------------------------------------------------- 
; division64(): ���� 64 λ�����
; input:
;       edx:eax - ������
;       ecx:ebx - ����
; output:
;       edx:eax - ��
;------------------------------------------------- 
division64:
        push edi
        sub esp, 16
        mov [esp], eax                                          ; dividend low
        mov [esp + 4], edx                                      ; dividend high
        mov [esp + 8], ebx                                      ; divisor low
        mov [esp + 12], ecx                                     ; divisor high
        mov edi, ecx
        shr edx, 1
        rcr eax, 1                                              ; edx:eax >> 1
        ror edi, 1
        rcr ebx, 1                                              ; edi:ebx >> 1
        bsr ecx, ecx
        shrd ebx, edi, cl
        shrd eax, edx, cl
        shr edx, cl
        rol edi, 1
        div ebx
        mov ebx, [esp]
        mov ecx, eax
        imul edi, eax
        mul DWORD [esp + 8]
        add edx, edi
        sub ebx, eax
        mov eax, ecx
        mov ecx, [esp + 4]
        sbb ecx, edx
        sbb eax, 0
        xor edx, edx
        mov ebx, [esp + 8]
        mov ecx, [esp + 12]        
        add esp, 16
        pop edi
        ret

;------------------------------------------------- 
; division64_32(): 64 λ���� 32 λ��
; input:
;       edx:eax - ������
;       ebx - ����
; output:
;       edx:eax - ��
;------------------------------------------------- 
division64_32:
        cmp edx, ebx
        jae double_divsion
        ;
        ; ֱ�ӽ��� edx:eax / ebx�� edx:eax = ��
        ;
        div ebx
        xor edx, edx
        jmp division64_32.done
        
double_divsion:
        ;
        ; ��Ҫ�������γ�����
        ;
        push ecx
        mov ecx, eax                                            ; ���� dividend low
        mov eax, edx                                            ; dividend high
        xor edx, edx                                            ; 
        div ebx                                                 ; �Ƚ��� dividend ��λ���
        xchg eax, ecx                                           ; ecx = quotient high, eax = dividend low
        div ebx                                                 ; ���� dividend ��λ���
        mov edx, ecx                                            ; edx:eax = quotient    
        pop ecx
division64_32.done:        
        ret


;------------------------------------------------------        
; mul64(): 64λ�˷�
; input:
;       esi: ��������ַ
;       edi: ������ַ
;       ebp: ���ֵ��ַ
;
; ������
; c3:c2:c1:c0 = a1:a0 * b1:b0
;(1) a0*b0 = d1:d0
;(2) a1*b0 = e1:e0
;(3) a0*b1 = f1:f0
;(4) a1*b1 = h1:h0
;
;               a1:a0
; *             b1:b0
;----------------------
;               d1:d0
;            e1:e0
;            f1:f0
; +       h1:h0
;-----------------------
; c0 = b0
; c1 = d1 + e0 + f0
; c2 = e1 + f1 + h0 + carry
; c3 = h1 + carry
;------------------------------------------------------------
__mul64:
        jmp do_mul64
c2_carry        dd 0        
c3_carry        dd 0
temp_value      dd 0
do_mul64:        
        push ecx
        push ebx
        push edx
        mov eax, [esi]                  ; a0
        mov ebx, [esi + 4]              ; a1        
        mov ecx, [edi]                  ; b0
        mul ecx                         ; a0 * b0 = d1:d0, eax = d0, edx = d1
        mov [ebp], eax                  ; ���� c0
        mov ecx, edx                    ; ���� d1
        mov eax, [edi]                  ; b0
        mul ebx                         ; a1 * b0 = e1:e0, eax = e0, edx = e1
        add ecx, eax                    ; ecx = d1 + e0
        mov [temp_value], edx           ; ���� e1
        adc DWORD [c2_carry], 0         ; ���� c2 ��λ
        mov ebx, [esi]                  ; a0
        mov eax, [edi + 4]              ; b1
        mul ebx                         ; a0 * b1 = f1:f0
        add ecx, eax                    ; d1 + e0 + f0
        mov [ebp + 4], ecx              ; ���� c1
        adc DWORD [c2_carry], 0         ; ���� c2 ��λ
        add [temp_value], edx           ; e1 + f1
        adc DWORD [c3_carry], 0         ; ���� c3 ��λ
        mov eax, [esi + 4]              ; a1
        mul ebx                         ; a1 * b1 = h1:h0
        add [temp_value], eax           ; e1 + f1 + h0
        adc DWORD [c3_carry], 0         ; ���� c3 ��λ
        mov eax, [c2_carry]             ; ��ȡ c2 ��λֵ
        add eax, [temp_value]           ; e1 + f1 + h0 + carry
        mov [ebp + 8], eax              ; ���� c2
        add edx, [c3_carry]             ; h1 + carry
        mov [ebp + 12], edx             ; ���� c3
        pop edx
        pop ebx
        pop ecx
        ret
                

;------------------------------------------------------  
; cmp64():
; input:
;       edx:eax
;       ecx:ebx
; output:
;       eflags
; ������
;       ִ��64λ���ıȽϲ���
;------------------------------------------------------  
cmp64:
        ;;
        ;; �ȱȽϸ� 32 λ�������ʱ���ٱȽϵ� 32 λ
        ;;
        cmp edx, ecx
        jne cmp64.done
        cmp eax, ebx
cmp64.done:        
        ret


                
;------------------------------------------------------  
; shl64()
; input:
;       edx:eax - 64 λֵ
;       ecx - count
; output:
;       edx:eax - ���
; ������
;       ִ�� 64 λ������
;------------------------------------------------------ 
shl64:
        and ecx, 63                                     ; ִ����� 63 λ�ƶ�
        
        cmp ecx, 32
        jae shl64_64
        
        ;;
        ;; �����ƶ�С�� 32 λ��
        ;; 
        shld edx, eax, cl                               ; edx:eax << n
        shl eax, cl
        
        jmp shl64.done


shl64_64:
        ;;
        ;; �����ƶ� 32 λ�������߳��� 32 λ
        ;; 1) n = 32 ʱ�� edx:eax << 32, ���Ϊ eax:0
        ;; 2) n > 32 ʱ�� edx:eax << n�� ���Ϊ eax<<(n-32):0
        ;;
        mov edx, eax                                    ; eax ���� edx
        xor eax, eax                                    ; �� 32 λΪ 0
        and ecx, 31                                     ; ȡ 32 ����ֵ�����Ϊ 64 - n 
        shl edx, cl                                     ; �� n = 32 ʱ:  cl = 0
                                                        ; �� n > 32 ʱ�� 32 > cl > 0
shl64.done:
        ret        



;------------------------------------------------------  
; shr64()
; input:
;       edx:eax - 64 λֵ
;       ecx - count
; output:
;       edx:eax - ���
; ������
;       ִ�� 64 λ������
;------------------------------------------------------ 
shr64:
        and ecx, 63                                     ; ִ����� 63 λ�ƶ�
        
        cmp ecx, 32
        jae shr64_64
        
        ;;
        ;; �����ƶ�С�� 32 λ��
        ;; 
        shrd eax, edx, cl                               ; edx:eax >> n
        shr edx, cl
        
        jmp shr64.done


shr64_64:
        ;;
        ;; �����ƶ� 32 λ�������߳��� 32 λ
        ;; 1) n = 32 ʱ�� edx:eax >> 32, ���Ϊ 0:edx
        ;; 2) n > 32 ʱ�� edx:eax >> n�� ���Ϊ 0:edx>>(n-32)
        ;;
        mov eax, edx                                    ; edx ���� eax
        xor edx, edx                                    ; �� 32 λΪ 0
        and ecx, 31                                     ; ȡ 32 ����ֵ�����Ϊ 64 - n 
        shr eax, cl                                     ; �� n = 32 ʱ:  cl = 0
                                                        ; �� n > 32 ʱ�� 32 > cl > 0
shr64.done:
        ret        



;------------------------------------------------------
; locked_xadd64():
; input:
;       esi - ��������ַ��
;       edx:eax - ����
; output:
;       edx:eax - ���ر�����ԭֵ
; ������
;       1) ִ�� lock �� 64 λ����ӣ����������Ŀ���������
;       2) Ŀ����������ڴ�
;       3) ��������Ŀ�������ԭֵ
;------------------------------------------------------
locked_xadd64:
        push ecx
        push ebx
        push ebp


        ;;
        ;; ����Ƿ�֧�� cmpxchg8b ָ��
        ;;
        bt DWORD [gs: PCB.FeatureEdx], 8                ; CPUID.01H:EDX[8].CMPXCHG8B λ
        jc locked_xadd64.ok
        
        ;;
        ;; ��֧�� cmpxchg8b ָ��ʱ��ֱ��ִ������ xadd ָ��
        ;; ���棺
        ;;      1) ����������£�������������ִ�� 64 λ��ԭ�� xadd ����
        ;;
        lock xadd [esi], eax
        lock xadd [esi + 4], edx
        
        jmp locked_xadd64.done
        
        
        ;;
        ;; ����ʹ�� cmpxchg8b ָ�����ʵ���� 32 λ�¶� 64 λ������ԭ�� xadd ����
        ;;
locked_xadd64.ok:

        mov ebp, eax
        mov edi, edx                                    ; edi:ebp �������
        ;;
        ;; ȡԭֵ�������
        ;;
        mov eax, [esi]
        mov edx, [esi + 4]                              ; edx:eax = ԭֵ
                
                
locked_xadd64.loop:
        mov ebx, ebp
        mov ecx, edi                                    ; ecx:ebx = ����
        add ebx, eax
        adc ecx, edx                                    ; ecx:ebx = edx:eax + ecx:ebx
                                                        ; edx:eax = ԭֵ
       
       ;;
       ;; ִ�� edx:eax �� [esi] �Ƚϣ����ҽ���
       ;; 1) edx;eax == [esi] ʱ��[esi] = ecx:ebx
       ;; 2) edx:eax != [esi] ʱ��edx:eax = [esi]
       ;;
        lock cmpxchg8b [esi]                            ; [esi] = ecx:ebx
        
        ;;
        ;; ��� [esi] �ڵ�ԭֵ�Ƿ��Ѿ����޸�
        ;; ע�⣺
        ;; 1) ��ִ�С���д��Ŀ�������֮ǰ�������ܡ��Ѿ������������޸��� [esi] �ڵ�ԭֵ
        ;; 2) ��ˣ�������ԭֵ�Ƿ���ȣ�
        ;; 3) ��ԭֵ�Ѿ����޸�ʱ����Ҫ���¼��� [esi] ԭֵ���ٽ��С���ӡ�������д������
        ;;
        jne locked_xadd64.loop                          ; [esi] ԭֵ�� edx:eax �����ʱ���ظ����� 
locked_xadd64.done:        
        pop ebp
        pop ebx
        pop ecx
        ret





;------------------------------------------------------
; delay_with_us32()
; input:
;       esi - ��ʱ us ��
; output:
;       none
; ����:
;       1) ִ����ʱ����
;       2) ��ʱ�ĵ�λΪus��΢�룩
;------------------------------------------------------
delay_with_us32:
        push edx
        ;;
        ;; ���� ticks �� = us �� * ProcessorFrequency
        ;;
        mov eax, [gs: PCB.ProcessorFrequency]
        mul esi
        mov edi, edx
        mov esi, eax

        ;;
        ;; ����Ŀ�� ticks ֵ
        ;;
        rdtsc
        add esi, eax
        adc edi, edx                            ; edi:esi = Ŀ�� ticks ֵ
        
        ;;
        ;; ѭ���Ƚϵ�ǰ tick �� Ŀ�� tick
        ;;
delay_with_us32.loop:
        rdtsc
        cmp edx, edi
        jne delay_with_us32.@0
        cmp eax, esi
delay_with_us32.@0:
        jb delay_with_us32.loop
        
        pop edx
        ret


;------------------------------------------------------
; start_lapic_timer()
; input:
;       esi - ʱ�䣨��λΪ us��
;       edi - ��ʱģʽ
;       eax - �ص�����
; output:
;       none
; ������
;       1) ���� local apic timer
; ������
;       esi - �ṩ��ʱʱ�䣬��λΪ us
;       edi - LAPIC_TIMER_ONE_SHOT��ʹ��һ���Զ�ʱ
;             LAPIC_TIMER_PERIODIC, ʹ�������Զ�ʱ
;       eax - �ṩһ���ص�����
;------------------------------------------------------
start_lapic_timer:
        push ebp
        push ebx
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        REX.Wrxb
        mov ebx, [ebp + PCB.LsbBase]
        
        
        mov [ebx + LSB.LapicTimerRequestMask], edi
        REX.Wrxb
        mov [ebx + LSB.LapicTimerRoutine], eax
        mov eax, [ebp + PCB.LapicTimerFrequency]
        mul esi
        mov esi, eax   
        REX.Wrxb
        mov eax, [ebp + PCB.LapicBase]
        
        cmp edi, LAPIC_TIMER_PERIODIC        
        mov edi, TIMER_ONE_SHOT | LAPIC_TIMER_VECTOR        
        jne start_lapic_timer.@0        
        mov edi, TIMER_PERIODIC | LAPIC_TIMER_VECTOR
        
start_lapic_timer.@0:        
        mov [eax + LVT_TIMER], edi
        mov [eax + TIMER_ICR], esi
        pop ebx
        pop ebp
        ret


;------------------------------------------------------
; stop_lapic_timer()
; input:
;       none
; output:
;       none
; ������
;       1) ֹͣ local apic timer
;------------------------------------------------------
stop_lapic_timer:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  

        REX.Wrxb
        mov eax, [ebp + PCB.LapicBase]
        mov DWORD [eax + TIMER_ICR], 0
        
        pop ebp        
        ret




;------------------------------------------------------
; clock()
; input:
;       esi - row
;       edi - column
; output:
;       none
; ������
;       1) ��(row,column) λ������ʾʱ��
;------------------------------------------------------
clock:
        push ebp        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        REX.Wrxb
        mov ebp, [ebp + PCB.LsbBase]                    ; LSB
        
        call set_video_buffer
        
        ;;
        ;; ��ʾСʱ��
        ;;
        mov eax, print_byte_value
        mov edi, print_dword_decimal
        mov esi, [ebp + LSB.Hour]
        cmp esi, 9
        cmova eax, edi
        call eax
        mov esi, ':'
        call putc
        ;;
        ;; ��ʾ������
        ;;
        mov eax, print_byte_value
        mov edi, print_dword_decimal
        mov esi, [ebp + LSB.Minute]
        cmp esi, 9
        cmova eax, edi
        call eax
        mov esi, ':'
        call putc
        ;;
        ;; ��ʾ������
        ;;
        mov eax, print_byte_value
        mov edi, print_dword_decimal
        mov esi, [ebp + LSB.Second]
        cmp esi, 9
        cmova eax, edi
        call eax  
        pop ebp
        ret




;------------------------------------------------------
; send_init_command()
; input:
;       none
; output:
;       none
; ������
;       1) �����д��������� INIT ��Ϣ������BSP��
;       2) �˺������������� INIT RESET
; ע�⣺
;       1) INIT RESET �£�MSR ���ı�!
;       2) BSP ִ�� boot������ AP �ȴ� SIPI ��Ϣ!
;------------------------------------------------------
send_init_command:

        test DWORD [gs: PCB.ProcessorStatus], CPU_STATUS_PG
        mov eax, [gs: PCB.LapicBase]
        cmovz eax, [gs: PCB.LapicPhysicalBase]
        ;;
        ;; �����д������㲥 INIT
        ;;
        mov DWORD [ebx + ICR1], 0FF000000h
        mov DWORD [ebx + ICR0], 00004500h           
        hlt
        ret


;----------------------------------------------
; raise_tpl()
; input:
;       none
; output:
;       none
; ������
;       1) ���� TPL��Task Priority Level��һ��
;----------------------------------------------
raise_tpl:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif        
        movzx esi, BYTE [ebp + PCB.CurrentTpl]                  ; ��ȡ��ǰ�� TPL
        mov [ebp + PCB.PrevTpl], esi                            ; ����Ϊ PrevTpl
        INCv esi                                                ; ����һ��
        jmp do_modify_tpl


;----------------------------------------------
; lower_tpl()
; input:
;       none
; output:
;       none
; ������
;       1) ���� TPL��Task Priority Level��һ��
;----------------------------------------------        
lower_tpl:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 
        movzx esi, BYTE [ebp + PCB.CurrentTpl]                  ; ��ȡ��ǰ TPL
        mov [ebp + PCB.PrevTpl], esi                            ; ����Ϊ PrevTpl
        DECv esi                                                ; ����һ��
        jmp do_modify_tpl



;----------------------------------------------
; change_tpl()
; input:
;       esi - TPL
; output:
;       none
; ������
;       1)�޸� TPL��Task Priority Level��
;----------------------------------------------  
change_tpl:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 

        movzx eax, BYTE [ebp + PCB.CurrentTpl]                  ; ��ȡ��ǰ TPL
        mov [ebp + PCB.PrevTpl], eax                            ; ����Ϊ PrevTpl        
        jmp do_modify_tpl
        

;----------------------------------------------
; recover_tpl()
; input:
;       none
; output:
;       none
; ������
;       1)�ָ�ԭ TPL��Task Priority Level��
;----------------------------------------------        
recover_tpl:
        push ebp
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 

        movzx esi, BYTE [ebp + PCB.PrevTpl]                     ; ��ȡԭ TPL
        jmp do_modify_tpl



;-------------------------------------------
; do_modity_tpl()
; input:
;       esi - TPL
; output:
;       none
;-------------------------------------------
do_modify_tpl:        
        and esi, 0FFh
        mov [ebp + PCB.CurrentTpl], esi                         ; �µ� CurrentTpl ֵ
        shl esi, 4
        REX.Wrxb
        mov eax, [ebp + PCB.LapicBase]
        mov [eax + LAPIC_TPR], esi                              ; д�� local APIC TPR
do_modity_tpl.end:        
        pop ebp
        ret




;----------------------------------------------
; read_keyboard()
; input:
;       none
; output:
;       eax - scan code
; ������
;       1) �ȴ�����������һ��ɨ����
;       2) �˺�����󽫹رռ���
;----------------------------------------------
read_keyboard:
        push ebp
        push ebx
        push ecx
        pushf

        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  


        ;;
        ;; �� keyboard
        ;;
%ifdef REAL
        call lower_tpl
%else
        call enable_8259_keyboard
%endif

        ;;        
        ;; ���������� LocalKeyBufferPtr ֵ
        ;;
        REX.Wrxb
        mov ebp, [ebp + PCB.LsbBase]        
        REX.Wrxb
        mov ebx, [ebp + LSB.LocalKeyBufferPtr]

       
        ;;
        ;; ���ж�����
        ;;
        sti        
               
        ;;
        ;; �ȴ�...
        ;; ֱ�� LocalKeyBufferPtr �����ı�ʱ�˳�!
        ;;       
                
        WAIT_UNTIL_NEQ          [ebp + LSB.LocalKeyBufferPtr], ebx
                

        ;;
        ;; ���� keyboard
        ;;
%ifdef REAL
        call raise_tpl
%else        
        call disable_8259_keyboard
%endif


        ;;
        ;; ������ɨ����
        ;;
        REX.Wrxb
        mov ebx, [ebp + LSB.LocalKeyBufferPtr]
        movzx eax, BYTE [ebx]

read_keyboard.done:        
        popf
        pop ecx
        pop ebx
        pop ebp 
        ret
        
        
        
;----------------------------------------------
; wait_a_key()
; input:
;       none
; output:
;       eax - ɨ����
; ������
;       1) �ȴ�����������һ��ɨ����
;       2) wait_a_key()���Ѿ��򿪼���ʱʹ��
;       3��read_keyboard() �ڲ��򿪼��̣������Ѿ���������
;----------------------------------------------
wait_a_key:
        push ebp
        push ecx

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif  
        
        REX.Wrxb
        mov ebp, [ebp + PCB.LsbBase]
               
        ;;
        ;; ��ԭ KeyBufferPtr ֵ
        ;;
        xor eax, eax        
                
        ;;
        ;; �� x64 �£�lock xadd [ebp + LSB.LocalKeyBufferPtr], rax
        ;; �� x86 �£�lock xadd [ebp + LSB.LocalKeybufferPtr], eax
        ;;
        PREFIX_LOCK
        REX.Wrxb
        xadd [ebp + LSB.LocalKeyBufferPtr], eax

        ;;
        ;; �ȴ�...
        ;; ֱ�� KeyBufferPtr �����ı�ʱ�˳�!
        ;;       
                
        WAIT_UNTIL_NEQ          [ebp + LSB.LocalKeyBufferPtr], eax
        

        ;;
        ;; ������ɨ����
        ;;
        REX.Wrxb
        mov eax, [ebp + LSB.LocalKeyBufferPtr]
        movzx eax, BYTE [eax]        

wait_a_key.done:                
        pop ecx
        pop ebp
        ret

        
        
        

;----------------------------------------------
; wait_esc_for_reset()
; input:
;       none
; output:
;       none
; ����:
;       1) �ȴ����� <ESC> ������
;       2) �˺���ʹ�� CPU hard reset ��������
;       3) �� target video buffer ��ӡ
;---------------------------------------------
wait_esc_for_reset:
        push ebp

%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif 

        
        ;;
        ;; ��λ�� (24,0)
        ;;
        ;mov esi, 24
        ;mov edi, 0
        ;call set_video_buffer
        
        mov esi, Ioapic.WaitResetMsg
        call puts
        
        ;;
        ;; �ȴ��� <ESC> ��
        ;;
wait_esc_for_reset.loop:
        call read_keyboard 
        cmp al, SC_ESC                                  ; �Ƿ�Ϊ <ESC> ��
        jne wait_esc_for_reset.loop
        
wait_esc_for_reset.next:

        ;;
        ;; ִ�� CPU RESET ����
        ;; 1) ����ʵ������ʹ�� INIT RESET
        ;; 2) ��vmware ��ʹ�� CPU RESET
        ;;
        
%ifdef REAL
        ;;
        ;; ʹ�� INIT RESET ����
        ;;
        test DWORD [ebp + PCB.ProcessorStatus], CPU_STATUS_PG
        REX.Wrxb
        mov eax, [ebp + PCB.LapicBase]
        REX.Wrxb
        cmovz eax, [ebp + PCB.LapicPhysicalBase]
        ;;
        ;; �����д������㲥 INIT
        ;;
        mov DWORD [eax + ICR1], 0FF000000h
        mov DWORD [eax + ICR0], INIT_DELIVERY  
        
%else        
        
        ;;
        ;; ִ�� CPU hard reset ����
        ;;
        RESET_CPU 

%endif        
        ret
        



        
                
;------------------------------------------------------
; get_spin_lock()
; input:
;       esi - lock
; output:
;       none
; ����:
;       1) �˺����������������
;       2) �������Ϊ spin lock ��ַ
;------------------------------------------------------
get_spin_lock:
        ;;
        ;; ��������������˵��:
        ;; 1) ʹ�� bts ָ�������ָ������
        ;;    lock bts DWORD [esi], 0
        ;;    jnc AcquireLockOk
        ;;
        ;; 2) ������ʹ�� cmpxchg ָ��
        ;;    lock cmpxchg [esi], edi
        ;;    jnc AcquireLockOk
        ;;    
        
        xor eax, eax
        mov edi, 1        
        
        ;;
        ;; ���Ի�ȡ lock
        ;;
get_spin_lock.acquire:
        lock cmpxchg [esi], edi
        je get_spin_lock.done

        ;;
        ;; ��ȡʧ�ܺ󣬼�� lock �Ƿ񿪷ţ�δ������
        ;; 1) �ǣ����ٴ�ִ�л�ȡ����������
        ;; 2) �񣬼������ϵؼ�� lock��ֱ�� lock ����
        ;;
get_spin_lock.check:        
        mov eax, [esi]
        test eax, eax
        jz get_spin_lock.acquire
        pause
        jmp get_spin_lock.check
        
get_spin_lock.done:                
        ret


;------------------------------------------------------
; get_spin_lock_with_count()
; input:
;       esi - lock
;       edi - count
; output:
;       0 - successful, 1 - failure
; ����:
;       1) �˺������������������
;       2) ������� esi Ϊ spin lock ��ַ
;       3) ������� edi Ϊ ����ֵ
;------------------------------------------------------
get_spin_lock_with_count:
        push ecx
        ;;
        ;; ��������������˵��:
        ;; 1) ʹ�� bts ָ�������ָ������
        ;;    lock bts DWORD [esi], 0
        ;;    jnc AcquireLockOk
        ;;
        ;; 2) ������ʹ�� cmpxchg ָ��
        ;;    lock cmpxchg [esi], edi
        ;;    jnc AcquireLockOk
        ;;    
        mov ecx, edi
        xor eax, eax
        mov edi, 1        
        
        ;;
        ;; ���Ի�ȡ lock
        ;;
get_spin_lock_with_count.acquire:
        lock cmpxchg [esi], edi
        je get_spin_lock_with_count.done

        ;;
        ;; ��ȡʧ�ܺ󣬼�� lock �Ƿ񿪷ţ�δ������
        ;; 1) �ǣ����ٴ�ִ�л�ȡ����������
        ;; 2) �񣬼������ϵؼ�� lock��ֱ�� lock ����
        ;;
get_spin_lock_with_count.check:        
        dec ecx
        jz get_spin_lock_with_count.done
        mov eax, [esi]
        test eax, eax
        jz get_spin_lock_with_count.acquire
        pause
        jmp get_spin_lock_with_count.check
        
get_spin_lock_with_count.done:     
        pop ecx
        ret





        
;-----------------------------------------------------
; dump_memory()
; input:
;       esi - buffer
; output:
;       none
; ������
;       1) ��ӡ buffer ����
;       2) <UP>�����Ϸ���<DOWN>���·�, <ESC>�˳�
;-----------------------------------------------------
dump_memory:
        push ebx
        push edx
        
        REX.Wrxb
        mov ebx, esi
        REX.Wrxb
        mov edx, esi

dump_memory.@0:        
        mov esi, 2
        mov edi, 0
        call set_video_buffer
        
        ;;
        ;; ��ӡͷ��
        ;;
        mov esi, 10
        call print_space
        
        xor ecx, ecx
        
dump_memory.Header:        
        mov esi, ecx
        call print_byte_value
        call printblank
        INCv ecx
        cmp ecx, 16
        jb dump_memory.Header
        call println
        mov esi, 10
        call print_space
        mov esi, '-'
        mov edi, 16 * 3 - 1
        call print_chars
        call println

        ;;
        ;; ��ӡ buffer ����
        ;;
        xor ecx, ecx
        
dump_memory.@1:
        lea esi, [ebx + ecx]
        call print_dword_value
        mov esi, ':'
        call putc
        mov esi, ' '
        call putc
        
dump_memory.@2:        
        movzx esi, BYTE [ebx + ecx]
        call print_byte_value
        call printblank
        INCv ecx
        mov eax, ecx
        and eax, 0Fh
        test eax, eax
        jnz dump_memory.@2
        call println
        cmp ecx, 256
        jb dump_memory.@1
        
        ;;
        ;; ���Ƽ���
        ;;
        mov esi, 24
        mov edi, 0
        call set_video_buffer
        mov esi, Status.Msg1
        call puts

dump_memory.@3:        
        call read_keyboard
        cmp al, SC_ESC                          ; �Ƿ�Ϊ <Esc>
        je dump_memory.@4
        cmp al, SC_PGUP                         ; �Ƿ�Ϊ <PageUp>
        jne dump_memory.CheckPageDown
        REX.Wrxb
        sub ebx, 256
        REX.Wrxb
        cmp ebx, edx
        REX.Wrxb
        cmovb ebx, edx
        xor ecx, ecx
        jmp dump_memory.@0

dump_memory.CheckPageDown:
        cmp al, SC_PGDN                         ; �Ƿ�Ϊ <PageDown>
        jne dump_memory.@3
        REX.Wrxb
        add ebx, 256
        xor ecx, ecx
        jmp dump_memory.@0
        
dump_memory.@4:
        ;;
        ;; ִ�� CPU hard reset ����
        ;;
        RESET_CPU        
        pop edx                
        pop ebx
        ret




;-----------------------------------------------------
; get_usable_processor_index()
; input:
;       none
; output:
;       eax - processor index
;-----------------------------------------------------
get_usable_processor_index:
        ;;
        ;; �� UsableProcessorMask ���ҵ�һ�����õ� processor index ֵ
        ;;
        mov eax, SDA.UsableProcessorMask
        mov eax, [fs: eax]
        bsf eax, eax
        ret
        
        

        
;-----------------------------------------------------
; report_system_status()
; input:
;       none
; output:
;       none
;-----------------------------------------------------                        
report_system_status:
        ;;
        ;; ��λ�� 0,0 λ����
        ;;
        mov esi, 0
        mov edi, 0
        call set_video_buffer
        
        ;;
        ;; ��ӡ [Cpus]
        ;;
        mov esi, Status.CpusMsg
        call puts
        mov esi, SDA.ProcessorCount
        mov esi, [fs: esi]
        call print_dword_decimal
        mov esi, ' '
        call putc
        
        ;;
        ;; ��ӡ [Cpu model]
        ;;
        mov esi, Status.CpuModelMsg
        call puts
        mov esi, PCB.DisplayModel
        movzx esi, WORD [gs: esi]
        call print_word_value
        mov esi, ' '
        call putc
        
        ;;
        ;; ��ӡ [Stage]
        ;;
        mov esi, Status.StageMsg
        call puts
        mov esi, SDA.ApLongmode
        mov esi, [fs: esi]
        add esi, 2
        call print_dword_decimal
        mov esi, ' '
        call putc
        
        ;;
        ;; ��ӡ [Cpu id]
        ;;
        mov esi, Status.CpuIdMsg
        call puts
        mov esi, PCB.ProcessorIndex
        mov esi, [gs: esi]
        call print_dword_decimal
        mov esi, ' '
        call putc
        
        
        ;;
        ;; ��ӡ [VMX]
        ;;
        mov esi, Status.VmxMsg
        call puts
        mov esi, PCB.ProcessorStatus
        mov eax, Status.EnableMsg
        test DWORD [gs: esi], CPU_STATUS_VMXON
        mov esi, Status.DisableMsg
        cmovnz esi, eax
        call puts
        mov esi, ' '
        call putc
        
        ;;
        ;; ��ӡ [Host/Guest]
        ;;
        mov esi, Status.EptMsg
        call puts
        ;;
        ;; ��� guest ��־ֵ
        ;;
        mov esi, PCB.EptEnableFlag
        cmp BYTE [gs: esi], 1
        mov esi, Status.EnableMsg
        mov eax, Status.DisableMsg
        cmovne esi, eax
        call puts
        call println        
        ret



;-----------------------------------------------------
; update_system_status()
; input:
;       none
; output:
;       none
; ������
;       1) ����ϵͳ״̬�� local video buffer ��
;-----------------------------------------------------                        
update_system_status:
        ;;
        ;; ��λ�� 0,0 λ����
        ;;
        mov esi, 0
        mov edi, 0
        call set_video_buffer

        ;;
        ;; ��ӡ [Cpu id]
        ;;
        mov esi, Status.CpuIdMsg
        call puts
        mov esi, PCB.ProcessorIndex
        mov esi, [gs: esi]
        call print_dword_decimal
        mov esi, ' '
        call putc
               
        ;;
        ;; ��ӡ [Stage]
        ;;
        mov esi, Status.StageMsg
        call puts
        mov esi, SDA.ApLongmode
        mov esi, [fs: esi]
        add esi, 2
        call print_dword_decimal
        mov esi, ' '
        call putc
        
        ;;
        ;; ��ӡ [Cpus]
        ;;
        mov esi, Status.CpusMsg
        call puts
        mov esi, SDA.ProcessorCount
        mov esi, [fs: esi]
        call print_dword_decimal
        mov esi, ' '
        call putc
        
        ;;
        ;; ��ӡ [Cpu model]
        ;;
        mov esi, Status.CpuModelMsg
        call puts
        mov esi, PCB.DisplayModel
        movzx esi, WORD [gs: esi]
        call print_word_value
        mov esi, ' '
        call putc
                
        ;;
        ;; ��ӡ [VMX]
        ;;
        mov esi, Status.VmxMsg
        call puts
        mov esi, PCB.ProcessorStatus
        mov eax, Status.EnableMsg
        test DWORD [gs: esi], CPU_STATUS_VMXON
        mov esi, Status.DisableMsg
        cmovnz esi, eax
        call puts
        mov esi, ' '
        call putc
        
        ;;
        ;; ��ӡ [Ept]
        ;;
        mov esi, Status.EptMsg
        call puts
        
        ;;
        ;; ��� Ept enable ��־
        ;;
        mov esi, PCB.EptEnableFlag
        cmp BYTE [gs: esi], 1
        mov esi, Status.EnableMsg
        mov eax, Status.DisableMsg
        cmovne esi, eax
        call puts
        call printblank
        call println        
        ret
        



                
        
%include "..\lib\sse.asm"




