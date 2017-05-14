;*************************************************
; crt16.asm                                      *
; Copyright (c) 2009-2013 邓志                   *
; All rights reserved.                           *
;*************************************************


%include "..\inc\support.inc"

;;
;; 这是 16位实模式下使用的 runtime 库
;;


	bits 16
	

;------------------------------------------------------
; putc16()
; input: 
;       si - 字符
; output:
;       none
; 描述：
;       打印一个字符
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
; 描述：
;       打印换行
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
;       si - 字符串
; output:
;       none
; 描述：
;       打印字符串信息
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
;       ax - 字符
; 描述:
;       将 Hex 数字转换为对应的字符
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
;       si - 需转换的数（word size)
;       di - 目标串 buffer（最短需要 5 bytes，包括 0)
; 描述：
;       将一个WORD转换为字符串，放入提供的 buffer 内
;------------------------------------------------------
convert_word_into_buffer:
	push cx
	push si
	mov cx, 4                                       ; 4 个 half-byte
convert_word_into_buffer.loop:
	rol si, 4                                       ; 高4位 --> 低 4位
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
;       esi - 需转换的数（dword size)
;       di - 目标串 buffer（最短需要 9 bytes，包括 0)
; 描述：
;       将一个WORD转换为字符串，放入提供的 buffer 内
;------------------------------------------------------
convert_dword_into_buffer:
	push cx
	push esi
	mov cx, 8					; 8 个 half-byte
convert_dword_into_buffer.loop:
	rol esi, 4					; 高4位 --> 低 4位
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
; 描述:
;       检查是否支持 CPUID 指令
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
; 描述：
;       1) 得到内存 size，保存在 MMap.Size 里
;------------------------------------------------------
get_system_memory:
        push ebx
        push ecx
        push edx
        
;;
;; 常量定义
;;
SMAP_SIGN       EQU     534D4150h
MMAP_AVAILABLE  EQU     01h
MMAP_RESERVED   EQU     02h
MMAP_ACPI       EQU     03h
MMAP_NVS        EQU     04h




        xor ebx, ebx                            ; 第 1 次迭代
        mov edi, MMap.Base        
        
        ;;
        ;; 查询 memory map
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
; 描述：
;       1) 在 16 位 real mode 环境下使用
;       2) 函数返回后，进入 32位 unreal mode，使用 4G 段限
;------------------------------------------------------
unreal_mode_enter:
        push ebp
        push edx
        push ecx
        push ebx
               
        mov cx, ds
        
        ;;
        ;; 计算进入保护模式和返回实模式入口点地址
        ;;        
        call _TARGET
_TARGET  EQU     $
        pop ax
        mov bx, ax
        add ax, (_RETURN_TARGET - _TARGET)                      ; 返回实模式入口偏移量
        add bx, (_ENTER_TARGET - _TARGET)                       ; 进入保护模式入口偏移量
          
        ;;
        ;; 保存原 GDT pointer
        ;;
        sub esp, 6
        sgdt [esp]
        
        ;;
        ;; 压入返回实模式的 far pointer(16:16)
        ;;
        push cs
        push ax
      
        
        ;;
        ;; 记录返回到实模式前的 stack pointer 值
        ;;        
        mov ebp, esp
        
        ;;
        ;; 压入 code descriptor
        ;;
        mov ax, cs
        xor edx, edx
        shld edx, eax, 20
        shl eax, 20
        or eax, 0000FFFFh                                       ; limit = 4G, base = cs << 4
        or edx, 00CF9A00h                                       ; DPL = 0, P = 1,　32-bit code segment
        ;or edx, 008F9A00h
        push edx
        push eax
        
        ;;
        ;; 压入 data descriptor
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
        ;; 压入 NULL descriptor
        ;;
        xor eax, eax
        push eax
        push eax    

        
        ;;
        ;; 必须保证 ds = ss
        ;;
        mov ax, ss
        mov ds, ax
        
        ;;
        ;; 压入　GDT pointer(16:32)
        ;;
        push esp
        push WORD (3 * 8 - 1)
        
        ;;
        ;; 加载 GDT
        ;;
        lgdt [esp]
        
        ;;
        ;; 切换到 32 位保护模式
        ;;
        mov eax, cr0
        bts eax, 0
        mov cr0, eax
        
        ;;
        ;; 转入保护模式（此处 operand size = 16)
        ;;
        push 10h
        push bx
        retf
       


;;
;; 32 位保护模式入口
;;

_ENTER_TARGET   EQU     $

        bits 32
        ;bits 16
        
        ;;
        ;; 更新 segment
        ;;
        mov ax, 08
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ss, ax
        mov esp, ebp
        
        ;;
        ;; 关闭保护模式
        ;;
        mov eax, cr0
        btr eax, 0
        mov cr0, eax
        
        ;;
        ;; 返回到实模式（此处 operand size = 32)
        ;; 因此：使用 66h 来调整到 16 位 operand
        ;;
        DB 66h
        retf
        ;retf

        
_RETURN_TARGET  EQU     $

        ;;
        ;; 恢复原 data segment 值
        ;;
        mov ds, cx
        mov es, cx
        mov fs, cx
        mov gs, cx
        mov ss, cx
        
        ;;
        ;; 恢复原 GDT pointer 值
        ;;
        lgdt [esp]
        add esp, 6
        
        pop ebx
        pop ecx
        pop edx
        pop ebp
        
        ;;
        ;; 此处是 32-bit operand size
        ;; 因此：需使用 16 位的返回地址
        ;;
        DB 66h
        ret
        





;------------------------------------------------------
; protected_mode_enter()
; input:
;       none
; output:
;       none
; 描述：
;       1) 函数将切换到保护模式
;       2) 加载为 FS 设置的描述符
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
        ;; 计算进入保护模式和返回实模式入口点地址
        ;;        
        call _TARGET1
_TARGET1  EQU     $
        pop bx
        
        ;;
        ;; 调整为以 0 为 base 的 EIP 值
        ;;
        mov di, cs
        shl edi, 4
        add ebx, edi
        add ebx, (_ENTER_TARGET1 - _TARGET1)                    ; 进入保护模式入口偏移量
          

        
        ;;
        ;; 记录返回到实模式前的 stack pointer 值
        ;;        
        mov ebp, esp

                
        ;;
        ;; 压入 FS 段描述符
        ;; 1) FS 段管理 SDA 区域
        ;; 2) FS base 使用物理地址默认为 12_0000h
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
        ;; 压入 code descriptor
        ;;
        mov eax, 0000FFFFh                                      ; limit = 4G, base = 0
        mov edx, 00CF9A00h                                      ; DPL = 0, P = 1, 32-bit code segment
        push edx
        push eax
        
        ;;
        ;; 压入 data descriptor
        ;;
        mov eax, 0000FFFFh                                       ; limit = 4G, base = 0
        mov edx, 00CF9200h                                       ; DPL = 0, P = 1, 32-bit data segment
        push edx
        push eax
        
        ;;
        ;; 压入 NULL descriptor
        ;;
        xor eax, eax
        push eax
        push eax    
        
        
        ;;
        ;; 注意：
        ;; 1) 必须保证 ds = ss
        ;;
        mov ax, ss
        mov ds, ax
        
        ;;
        ;; 压入　GDT pointer(16:32)
        ;;
        push esp
        push WORD (4 * 8 - 1)
        
        ;;
        ;; 加载 GDT
        ;;
        lgdt [esp]

        ;;
        ;; 切换到 32 位保护模式
        ;;
        mov eax, cr0
        bts eax, 0
        mov cr0, eax
        
        ;;
        ;; 转入保护模式（此处 operand size = 16)
        ;;
        push DWORD 10h
        push ebx
        retf32
       


;;
;; 32 位保护模式入口
;;

_ENTER_TARGET1  EQU     $

        bits 32
        
        ;;
        ;; 更新 segment
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
        ;; 将返回地址调整到以 0 为 base 的 EIP 值
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
; 描述:
;       1) 此函数用来获得自旋锁
;       2) 输入参数为 spin lock 地址
;------------------------------------------------------
get_spin_lock16:
        ;;
        ;; 自旋锁操作方法说明:
        ;; 1) 使用 bts 指令，如下面指令序列
        ;;    lock bts DWORD [esi], 0
        ;;    jnc AcquireLockOk
        ;;
        ;; 2) 本例中使用 cmpxchg 指令
        ;;    lock cmpxchg [esi], edi
        ;;    jnc AcquireLockOk
        ;;    
        
        xor eax, eax
        mov edi, 1        
        
        ;;
        ;; 尝试获取 lock
        ;;
get_spink_lock16.acquire:
        lock cmpxchg [esi], edi
        je get_spink_lock16.done

        ;;
        ;; 获取失败后，检查 lock 是否开放（未上锁）
        ;; 1) 是，则再次执行获取锁，并上锁
        ;; 2) 否，继续不断地检查 lock，直到 lock 开放
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
MMap.Base:      DQ      0                       ; 内存区域的地起地址
MMap.Length:    DQ      0                       ; 内存区域的长度
MMap.Type:      DD      0                       ; 内存区域的类型:

