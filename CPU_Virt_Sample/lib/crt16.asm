;*************************************************
; crt16.asm                                      *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


%include "..\inc\support.inc"

;;
;; ���� 16λʵģʽ��ʹ�õ� runtime ��
;;


	bits 16
	

;------------------------------------------------------
; putc16()
; input: 
;       si - �ַ�
; output:
;       none
; ������
;       ��ӡһ���ַ�
;------------------------------------------------------
putc16:
	push bx
	xor bh, bh
	mov ax, si
	mov ah, 0Eh	
	int 10h
	pop bx
	ret

;------------------------------------------------------
; println16()
; input:
;       none
; output:
;       none
; ������
;       ��ӡ����
;------------------------------------------------------
println16:
	mov si, 13
	call putc16
	mov si, 10
	call putc16
	ret

;------------------------------------------------------
; puts16()
; input: 
;       si - �ַ���
; output:
;       none
; ������
;       ��ӡ�ַ�����Ϣ
;------------------------------------------------------
puts16:
	pusha
	mov ah, 0Eh
	xor bh, bh	

do_puts16.loop:	
	lodsb
	test al,al
	jz do_puts16.done
	int 10h
	jmp do_puts16.loop

do_puts16.done:	
	popa
	ret	
	
	
;------------------------------------------------------
; hex_to_char()
; input:
;       si - Hex number
; ouput:
;       ax - �ַ�
; ����:
;       �� Hex ����ת��Ϊ��Ӧ���ַ�
;------------------------------------------------------
hex_to_char16:
	push si
	and si, 0Fh
	movzx ax, BYTE [Crt16.Chars + si]
	pop si
	ret
	
	
;------------------------------------------------------
; convert_word_into_buffer()
; input:
;       si - ��ת��������word size)
;       di - Ŀ�괮 buffer�������Ҫ 5 bytes������ 0)
; ������
;       ��һ��WORDת��Ϊ�ַ����������ṩ�� buffer ��
;------------------------------------------------------
convert_word_into_buffer:
	push cx
	push si
	mov cx, 4                                       ; 4 �� half-byte
convert_word_into_buffer.loop:
	rol si, 4                                       ; ��4λ --> �� 4λ
	call hex_to_char16
	mov BYTE [di], al
	inc di
	dec cx
	jnz convert_word_into_buffer.loop
	mov BYTE [di], 0
	pop si
	pop cx
	ret

;------------------------------------------------------
; convert_dword_into_buffer()
; input:
;       esi - ��ת��������dword size)
;       di - Ŀ�괮 buffer�������Ҫ 9 bytes������ 0)
; ������
;       ��һ��WORDת��Ϊ�ַ����������ṩ�� buffer ��
;------------------------------------------------------
convert_dword_into_buffer:
	push cx
	push esi
	mov cx, 8					; 8 �� half-byte
convert_dword_into_buffer.loop:
	rol esi, 4					; ��4λ --> �� 4λ
	call hex_to_char16
	mov BYTE [di], al
	inc di
	dec cx
	jnz convert_dword_into_buffer.loop
	mov BYTE [di], 0
	pop esi
	pop cx
	ret

;------------------------------------------------------
; check_cpuid()
; output:
;       1 - support,  0 - no support
; ����:
;       ����Ƿ�֧�� CPUID ָ��
;------------------------------------------------------
check_cpuid:
	pushfd                                          ; save eflags DWORD size
	mov eax, DWORD [esp]                            ; get old eflags
	xor DWORD [esp], 0x200000                       ; xor the eflags.ID bit
	popfd                                           ; set eflags register
	pushfd                                          ; save eflags again
	pop ebx                                         ; get new eflags
	cmp eax, ebx                                    ; test eflags.ID has been modify
	setnz al                                        ; OK! support CPUID instruction
	movzx eax, al
	ret



;------------------------------------------------------
; get_system_memory()
; input:
;       none
; output:
;       none
; ������
;       1) �õ��ڴ� size�������� MMap.Size ��
;------------------------------------------------------
get_system_memory:
        push ebx
        push ecx
        push edx
        
;;
;; ��������
;;
SMAP_SIGN       EQU     534D4150h
MMAP_AVAILABLE  EQU     01h
MMAP_RESERVED   EQU     02h
MMAP_ACPI       EQU     03h
MMAP_NVS        EQU     04h




        xor ebx, ebx                            ; �� 1 �ε���
        mov edi, MMap.Base        
        
        ;;
        ;; ��ѯ memory map
        ;;
get_system_memory.loop:      
        mov eax, 0E820h
        mov edx, SMAP_SIGN
        mov ecx, 20
        int 15h
        jc get_system_memory.done
        
        cmp eax, SMAP_SIGN
        jne get_system_memory.done
        
        mov eax, [MMap.Type]
        cmp eax, MMAP_AVAILABLE
        jne get_system_memory.next
        
        mov eax, [MMap.Length]
        mov edx, [MMap.Length + 4]
        add [MMap.Size], eax
        adc [MMap.Size + 4], edx
        
get_system_memory.next:
        test ebx, ebx
        jnz get_system_memory.loop
        
get_system_memory.done:
        pop edx
        pop ecx
        pop ebx        
        ret
        


;------------------------------------------------------
; unreal_mode_enter()
; input:
;       none
; output:
;       none
; ������
;       1) �� 16 λ real mode ������ʹ��
;       2) �������غ󣬽��� 32λ unreal mode��ʹ�� 4G ����
;------------------------------------------------------
unreal_mode_enter:
        push ebp
        push edx
        push ecx
        push ebx
               
        mov cx, ds
        
        ;;
        ;; ������뱣��ģʽ�ͷ���ʵģʽ��ڵ��ַ
        ;;        
        call _TARGET
_TARGET  EQU     $
        pop ax
        mov bx, ax
        add ax, (_RETURN_TARGET - _TARGET)                      ; ����ʵģʽ���ƫ����
        add bx, (_ENTER_TARGET - _TARGET)                       ; ���뱣��ģʽ���ƫ����
          
        ;;
        ;; ����ԭ GDT pointer
        ;;
        sub esp, 6
        sgdt [esp]
        
        ;;
        ;; ѹ�뷵��ʵģʽ�� far pointer(16:16)
        ;;
        push cs
        push ax
      
        
        ;;
        ;; ��¼���ص�ʵģʽǰ�� stack pointer ֵ
        ;;        
        mov ebp, esp
        
        ;;
        ;; ѹ�� code descriptor
        ;;
        mov ax, cs
        xor edx, edx
        shld edx, eax, 20
        shl eax, 20
        or eax, 0000FFFFh                                       ; limit = 4G, base = cs << 4
        or edx, 00CF9A00h                                       ; DPL = 0, P = 1,��32-bit code segment
        ;or edx, 008F9A00h
        push edx
        push eax
        
        ;;
        ;; ѹ�� data descriptor
        ;;
        mov ax, ds
        xor edx, edx       
        shld edx, eax, 20
        shl eax, 20
        or eax, 0000FFFFh                                       ; limit = 4G, base = ds << 4
        or edx, 00CF9200h                                       ; DPL = 0, P = 1, 32-bit data segment
        push edx
        push eax
        
        ;;
        ;; ѹ�� NULL descriptor
        ;;
        xor eax, eax
        push eax
        push eax    

        
        ;;
        ;; ���뱣֤ ds = ss
        ;;
        mov ax, ss
        mov ds, ax
        
        ;;
        ;; ѹ�롡GDT pointer(16:32)
        ;;
        push esp
        push WORD (3 * 8 - 1)
        
        ;;
        ;; ���� GDT
        ;;
        lgdt [esp]
        
        ;;
        ;; �л��� 32 λ����ģʽ
        ;;
        mov eax, cr0
        bts eax, 0
        mov cr0, eax
        
        ;;
        ;; ת�뱣��ģʽ���˴� operand size = 16)
        ;;
        push 10h
        push bx
        retf
       


;;
;; 32 λ����ģʽ���
;;

_ENTER_TARGET   EQU     $

        bits 32
        ;bits 16
        
        ;;
        ;; ���� segment
        ;;
        mov ax, 08
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ss, ax
        mov esp, ebp
        
        ;;
        ;; �رձ���ģʽ
        ;;
        mov eax, cr0
        btr eax, 0
        mov cr0, eax
        
        ;;
        ;; ���ص�ʵģʽ���˴� operand size = 32)
        ;; ��ˣ�ʹ�� 66h �������� 16 λ operand
        ;;
        DB 66h
        retf
        ;retf

        
_RETURN_TARGET  EQU     $

        ;;
        ;; �ָ�ԭ data segment ֵ
        ;;
        mov ds, cx
        mov es, cx
        mov fs, cx
        mov gs, cx
        mov ss, cx
        
        ;;
        ;; �ָ�ԭ GDT pointer ֵ
        ;;
        lgdt [esp]
        add esp, 6
        
        pop ebx
        pop ecx
        pop edx
        pop ebp
        
        ;;
        ;; �˴��� 32-bit operand size
        ;; ��ˣ���ʹ�� 16 λ�ķ��ص�ַ
        ;;
        DB 66h
        ret
        





;------------------------------------------------------
; protected_mode_enter()
; input:
;       none
; output:
;       none
; ������
;       1) �������л�������ģʽ
;       2) ����Ϊ FS ���õ�������
;------------------------------------------------------
        bits 16
        
protected_mode_enter:
        push ebp
        push edx
        push ecx
        push ebx

        xor eax, eax
        xor ecx, ecx               
        xor ebx, ebx
                
        ;;
        ;; ������뱣��ģʽ�ͷ���ʵģʽ��ڵ��ַ
        ;;        
        call _TARGET1
_TARGET1  EQU     $
        pop bx
        
        ;;
        ;; ����Ϊ�� 0 Ϊ base �� EIP ֵ
        ;;
        mov di, cs
        shl edi, 4
        add ebx, edi
        add ebx, (_ENTER_TARGET1 - _TARGET1)                    ; ���뱣��ģʽ���ƫ����
          

        
        ;;
        ;; ��¼���ص�ʵģʽǰ�� stack pointer ֵ
        ;;        
        mov ebp, esp

                
        ;;
        ;; ѹ�� FS ��������
        ;; 1) FS �ι��� SDA ����
        ;; 2) FS base ʹ�������ַĬ��Ϊ 12_0000h
        ;;
        xor edx, edx
        mov eax, SDA_PHYSICAL_BASE
        and eax, 00FFFFFFh        
        shld edx, eax, 16
        shl eax, 16
        or eax, 0FFFFh                                          ; limit = 1M for fs
        or edx, 000F9200h                                       ; DPL=0, P=1, base=SDA_PHYSICAL_BASE, data segment/writeable  
        or edx, (SDA_PHYSICAL_BASE & 0FF000000h)     
        push edx
        push eax
        
        ;;
        ;; ѹ�� code descriptor
        ;;
        mov eax, 0000FFFFh                                      ; limit = 4G, base = 0
        mov edx, 00CF9A00h                                      ; DPL = 0, P = 1, 32-bit code segment
        push edx
        push eax
        
        ;;
        ;; ѹ�� data descriptor
        ;;
        mov eax, 0000FFFFh                                       ; limit = 4G, base = 0
        mov edx, 00CF9200h                                       ; DPL = 0, P = 1, 32-bit data segment
        push edx
        push eax
        
        ;;
        ;; ѹ�� NULL descriptor
        ;;
        xor eax, eax
        push eax
        push eax    
        
        
        ;;
        ;; ע�⣺
        ;; 1) ���뱣֤ ds = ss
        ;;
        mov ax, ss
        mov ds, ax
        
        ;;
        ;; ѹ�롡GDT pointer(16:32)
        ;;
        push esp
        push WORD (4 * 8 - 1)
        
        ;;
        ;; ���� GDT
        ;;
        lgdt [esp]

        ;;
        ;; �л��� 32 λ����ģʽ
        ;;
        mov eax, cr0
        bts eax, 0
        mov cr0, eax
        
        ;;
        ;; ת�뱣��ģʽ���˴� operand size = 16)
        ;;
        push DWORD 10h
        push ebx
        retf32
       


;;
;; 32 λ����ģʽ���
;;

_ENTER_TARGET1  EQU     $

        bits 32
        
        ;;
        ;; ���� segment
        ;;
        mov ax, 18h
        mov fs, ax        
        mov ax, 08
        mov ds, ax
        mov es, ax
        mov gs, ax
        mov ss, ax
        mov esp, ebp

        
        pop ebx
        pop ecx
        pop edx
        pop ebp
        
        ;;
        ;; �����ص�ַ�������� 0 Ϊ base �� EIP ֵ
        ;;
        movzx eax, WORD [esp]
        add eax, edi
        sub esp, 2
        mov [esp], eax
        ret


;------------------------------------------------------
; get_spin_lock16()
; input:
;       esi - lock
; output:
;       none
; ����:
;       1) �˺����������������
;       2) �������Ϊ spin lock ��ַ
;------------------------------------------------------
get_spin_lock16:
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
get_spink_lock16.acquire:
        lock cmpxchg [esi], edi
        je get_spink_lock16.done

        ;;
        ;; ��ȡʧ�ܺ󣬼�� lock �Ƿ񿪷ţ�δ������
        ;; 1) �ǣ����ٴ�ִ�л�ȡ����������
        ;; 2) �񣬼������ϵؼ�� lock��ֱ�� lock ����
        ;;
get_spink_lock16.check:        
        mov eax, [esi]
        test eax, eax
        jz get_spink_lock16.acquire
        pause
        jmp get_spink_lock16.check
        
get_spink_lock16.done:                
        ret
        



Crt16.Chars     DB      '0123456789ABCDEF', 0
MMap.Size       DQ      0
MMap.Base:      DQ      0                       ; �ڴ�����ĵ����ַ
MMap.Length:    DQ      0                       ; �ڴ�����ĳ���
MMap.Type:      DD      0                       ; �ڴ����������:

