;*************************************************
;* crt64.asm                                     *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


       
        
        bits 64
         
        
;-----------------------------------------
; clear_4k_page64()
; input:  
;       rsi - address
; output;
;       none
; ������
;       1) һ���� 4K ҳ��
;       2) ��ַ�� 4K �߽���
;       3) �迪�� SSE ָ��֧��    
;       4) �� 64-bit ��ʹ��
;------------------------------------------        
clear_4k_page64:
        pxor xmm0, xmm0
        test rsi, rsi
        mov eax, 4096
        jz clear_4k_page64.done
        
        and rsi, ~0FFFh
        
clear_4k_page64.loop:        
        movdqa [rsi + rax - 16], xmm0
        movdqa [rsi + rax - 32], xmm0
        movdqa [rsi + rax - 48], xmm0
        movdqa [rsi + rax - 64], xmm0
        movdqa [rsi + rax - 80], xmm0
        movdqa [rsi + rax - 96], xmm0
        movdqa [rsi + rax - 112], xmm0
        movdqa [rsi + rax - 128], xmm0
        sub eax, 128
        jnz clear_4k_page64.loop
        
clear_4k_page64.done:
        ret 


;-----------------------------------------
; clear_4k_buffer64()���� 4K �ڴ�
; input:  
;       rsi: address
; output;
;       none
; ������
;       1) һ���� 4K ҳ��
;       2) ��ַ�� 4K �߽���
;       3) ʹ�� GPI ָ���
;-----------------------------------------
clear_4k_buffer64:
        push rsi
        push rdi
        mov rdi, rsi
        mov esi, 1000h
        call zero_memory64
        pop rdi
        pop rsi
        ret



;-----------------------------------------
; clear_4k_page_n64()���� n�� 4Kҳ��
; input:  
;       rsi - address
;       rdi - count
; output;
;       none
;------------------------------------------   
clear_4k_page_n64:
        call clear_4k_page64
        add rsi, 4096
        dec edi
        jnz clear_4k_page_n64
        ret        


;-----------------------------------------
; clear_4k_buffer_n64()���� n�� 4K �ڴ��
; input:  
;       rsi - address
;       rdi - count
; output;
;       none
;------------------------------------------ 
clear_4k_buffer_n64:
        call clear_4k_buffer64
        add rsi, 4096
        dec edi
        jnz clear_4k_buffer_n64
        ret        
        
        
;-------------------------------------------------------------------
; zero_memory64()
; input:
;       rsi - size
;       rdi - buffer
; output:
;       none
; ������
;       1) ���ڴ��
;-------------------------------------------------------------------
zero_memory64:
        push rcx
        test rdi, rdi
        jz zero_memory64.done

        xor eax, eax
        
        ;;
        ;; ��� count > 8 ?
        ;;
        cmp esi, 8
        jb zero_memory64.@1
        
        ;;
        ;; ��д���� 8 �ֽ�
        ;;
        mov [rdi], rax
        
        ;;
        ;; ��������� 8 �ֽڱ߽��ϵĲ�����ԭ����� 8 - (dest & 07)
        ;; 1) ���磺[2:0] = 011B��3��
        ;; 2) ȡ���� = 100B��4��
        ;; 3) ��1�� = 101B��5��
        ;;
        mov ecx, esi                                    ; count 
        mov esi, edi
        not esi                                         ; ԭ dest ȡ��
        inc esi                                         ; 
        and esi, 07h                                    ; �õ� QWORD �߽��ϵĲ��
        sub ecx, esi                                    ; c = count - ���
        
        ;;
        ;; dest ���ϵ����� QWORD �߽�
        ;;
        add rdi, rsi                                    ; dest = ԭ dest + ���
        
        ;;
        ;; �� QWORD Ϊ��λд��
        ;;
        mov esi, ecx
        shr ecx, 3                                      ; n = c / 8
                
        ;;
        ;; һ�� 8 �ֽ� QWORD �߽���д��
        ;;        
        rep stosq


zero_memory64.@1:            
        ;;
        ;; һ�� 1 �ֽڣ�д��ʣ���ֽ���
        ;;
        mov ecx, esi
        and ecx, 07h
        rep stosb
        
zero_memory64.done:        
        pop rcx
        ret   
        
        


;-------------------------------------------------
; strlen64(): ��ȡ�ַ�������
; input:
;       rsi - string
; output:
;       eax - length of string
;-------------------------------------------------
strlen64:
        push rcx
        xor eax, eax
        ;;
        ;; ����� string = NULL ʱ������ 0 ֵ
        ;;
        test rsi, rsi
        jz strlen64.done
        
        ;;
        ;; �����Ƿ�֧�� SSE4.2 ָ��Լ��Ƿ��� SSE ָ��ִ��
        ;; ѡ��ʹ�� SSE4.2 �汾�� strlen ָ��
        ;;
        cmp DWORD [gs: PCB.SSELevel], SSE4_2
        jb strlen64.legacy
        test DWORD [gs: PCB.InstructionStatus], INST_STATUS_SSE
        jnz sse4_strlen + 1                           ; ת��ִ�� sse4_strlen() 


strlen64.legacy:

        ;;
        ;; ʹ�� legacy ��ʽ
        ;;
        xor ecx, ecx
        mov rdi, rsi
        dec rcx                                         ; rcx = -1
        repne scasb                                     ; ѭ������ 0 ֵ
        sub rax, rcx                                    ; 0 - rcx
        dec rax
strlen64.done:
        pop rcx
        ret 
        
        
;-------------------------------------------------
; memcpy64(): �����ڴ��
; input:
;       rsi - source
;       rdi - dest 
;       r8 - count
; output:
;       none
;-------------------------------------------------
memcpy64:
        push rcx
        mov rcx, r8
        shr rcx, 3
        rep movsq
        mov rcx, r8
        and ecx, 07h
        rep movsb
        pop rcx
        ret  
        
        
        
        
        
;-------------------------------------------------------------------
; get_tss_base64()
; input:
;       none
; output:
;       rax - tss ���ַ
; ������
;       1) �� TSS POOL �����һ�� TSS ��
;       2) ʧ��ʱ���� 0 ֵ
;-------------------------------------------------------------------
get_tss_base64:
        push rbx
        xor esi, esi
        mov eax, [fs: SDA.TssPoolGranularity]
        lock xadd [fs: SDA.TssPoolBase], rax
        cmp rax, [fs: SDA.TssPoolTop]
        cmovae rax, rsi
        mov rbx, rax
        mov esi, [fs: SDA.TssPoolGranularity]
        mov rdi, rbx
        call zero_memory64
        mov rax, rbx
        pop rbx
        ret
        


;-------------------------------------------------------------------
; append_gdt_descriptor64(): �� GDT �����һ��������
; input:
;       rsi - 64 λ������
; output:
;       rax - ���� selector ֵ
; ������
;       1) �� GDT �����һ��������
;       2) �� 64-bit ��ʹ��
;-------------------------------------------------------------------
append_gdt_descriptor64:
        ;;
        ;; ��� Top �ϵ��������Ƿ�Ϊ 128 λϵͳ������
        ;; 1) �ǣ���һ�� entry = top + 16
        ;; 2) ����һ�� entry = top + 8
        ;;
        mov r9, [fs: SDA.GdtTop]                        ; ��ȡ GDT ����ԭֵ
        mov rax, [r9]
        bt rax, 44                                      ; ��� S ��־λ
        mov r8, 8
        mov rax, 16
        cmovc rax, r8
        add r9, rax                                     ; ָ����һ�� entry
        mov [r9], rsi                                   ; д�� GDT 
        mov [fs: SDA.GdtTop], r9                        ; ���� gdt_top ��¼
        add DWORD [fs: SDA.GdtLimit], 8                 ; ���� gdt_limit ��¼
        sub r9, [fs: SDA.GdtBase]                       ; �õ� selector ֵ
        mov rax, r9
        
        ;;
        ;; ����ˢ�� gdtr �Ĵ���
        ;;
        lgdt [fs: SDA.GdtPointer]
        ret
           
           
;-------------------------------------------------------------------
; append_gdt_system_descriptor64()
; input:
;       rdi:rsi - 128 λϵͳ������
; output:
;       rax - ���� selector ֵ
; ����:
;       1) �� GDT ���ϵͳ��������������TSS��LDT �Լ� Call-gate ������
;-------------------------------------------------------------------
append_gdt_system_descriptor64:
        ;;
        ;; ��� Top �ϵ��������Ƿ�Ϊ 128 λϵͳ������
        ;; 1) �ǣ���һ�� entry = top + 16
        ;; 2) ����һ�� entry = top + 8
        ;;
        mov r9, [fs: SDA.GdtTop]                        ; ��ȡ GDT ����ԭֵ
        mov rax, [r9]
        bt rax, 44                                      ; ��� S ��־λ
        mov r8, 8
        mov rax, 16
        cmovc rax, r8
        add r9, rax                                     ; ָ����һ�� entry
        mov [r9], rsi                                   ; д�� GDT 
        mov [r9 + 8], rdi
        mov [fs: SDA.GdtTop], r9                        ; ���� gdt_top ��¼
        add DWORD [fs: SDA.GdtLimit], 16                ; ���� gdt_limit ��¼
        sub r9, [fs: SDA.GdtBase]                       ; �õ� selector ֵ
        mov rax, r9
        
        ;;
        ;; ����ˢ�� gdtr �Ĵ���
        ;;
        lgdt [fs: SDA.GdtPointer]
        ret
            



;-------------------------------------------------------------------
; remove_gdt_descriptor64()
; input:
;       none
; output:
;       rax - �����Ƴ���������
;       rdx:rax - 128 λϵͳ������
; ������
;       1) �Ƴ� GDT ���ϵ�һ��������
;       2) ���ر��Ƴ������������������ system ������������ 128 λ������
;-------------------------------------------------------------------
remove_gdt_descriptor64:
        xor r9, r9
        xor rax, rax
        ;;
        ;; ��� GDT ���Ƿ�Ϊ��
        ;;
        mov r8, [fs: SDA.GdtTop]                        ; GDT top ָ��
        cmp r8, [fs: SDA.GdtBase]
        jbe remove_gdt_descriptor64.done
        
        mov rax, [r8]                                   ; ������ԭ������ֵ
        ;;
        ;; ����Ƿ����� system ������
        ;; 
        bt rax, 44
        jnc remove_gdt_descriptor64.system
        mov [r8], r9                                    ; ��ԭ GDT ����
        mov esi, 8
        jmp remove_gdt_descriptor64.next
        
remove_gdt_descriptor64.system:        
        mov rdx, [r8 + 8]
        mov [r8], r9
        mov [r8 + 8], r9
        mov esi, 16
        
remove_gdt_descriptor64.next:
        sub DWORD [fs: SDA.GdtLimit], esi               ; ���� GDT limit
        ;;
        ;; ���ǰһ�� entry �Ƿ�Ϊ system ������
        ;; 1) �ǣ�ǰһ�� entry = top - 16
        ;; 2) ��ǰһ�� entry = top - 8
        ;;
        mov rsi, [r8 - 8]
        ;;
        ;; ��������������Ƿ�Ϊ 0 
        ;;        
        shr rsi, 40
        and esi, 0Fh
        mov r9d, 8
        mov esi, 16
        cmovnz esi, r9d
              
        ;;
        ;; ���� TOP ֵ
        ;;
        sub r8, rsi        
        mov [fs: SDA.GdtTop], r8
        
        ;;
        ;; ���� GDTR
        ;;
        lgdt [fs: SDA.GdtPointer]
        
remove_gdt_descriptor64.done:        
        ret
        
        
        
        
;-------------------------------------------------------------------
; write_gdt_descriptor64()
; input:
;       esi - selector
;       rdi - 64 λ������ֵ
; output:
;       rax - ������������ַ
; ������
;       �����ṩ�� selector ֵ�� GDT ��д��һ��������
;-------------------------------------------------------------------   
write_gdt_descriptor64:
        and esi, 0FFF8h
        mov r8, [fs: SDA.GdtBase]
        add r8, rsi
        mov [r8], rdi                                   ; д��������
        
        ;;
        ;; ��⼰���� GDT �� top
        ;;
        add esi, 7
        cmp r8, [fs: SDA.GdtTop]                        ; �Ƿ� GDT TOP
        jbe write_gdt_descriptor64.next
        
        ;;
        ;; ���� Top������� Top 
        ;;
        mov [fs: SDA.GdtTop], r8

write_gdt_descriptor64.next:
        ;;
        ;; ����Ƿ� GDT limit
        ;;
        cmp esi, [fs: SDA.GdtLimit]
        jbe write_gdt_descriptor64.done
        
        ;;
        ;; �� limit������� GDT limit
        ;;
        mov [fs: SDA.GdtLimit], esi
        
        ;;
        ;; ˢ�� GDTR
        ;;
        lgdt [fs: SDA.GdtPointer]
        
write_gdt_descriptor64.done:        
        mov rax, r8
        ret
        
        
        
        
;-------------------------------------------------------------------
; read_gdt_descriptor64()
; input:
;       esi - selector
; output:
;       rdx:rax - 128 λϵͳ������
; ������
;       1) ��ȡ GDT ��������
;       2) ����ϵͳ���������� rdx:rax ���� 128 λ������
;       3) ʧ�ܷ��� -1
;-------------------------------------------------------------------        
read_gdt_descriptor64:
        and esi, 0FFF8h
        mov r8, rsi
        add esi, 7
        xor eax, eax
        dec rax
        mov rdx, rax
        
        ;;
        ;; ����Ƿ� limit
        ;;
        cmp esi, [fs: SDA.GdtLimit]
        ja read_gdt_descriptor64.done
        ;;
        ;; �� GDT ����
        ;;
        add r8, [fs: SDA.GdtBase]
        mov rax, [r8]
        
        ;;
        ;; ����Ƿ�Ϊ system ������
        ;;
        xor edx, edx
        bt rax, 44                                      ; S ��־λ
        jc read_gdt_descriptor64.done
        
        ;;
        ;; S = 0������ system ������
        ;;
        mov rdx, [r8 + 8]
                
read_gdt_descriptor64.done:        
        ret
        



;-------------------------------------------------------------------
; read_idt_descriptor64(): ��ȡ IDT ������
; input:
;       esi - vector  
; output:
;       rdx:rax - �ɹ�ʱ������ 128 λ��������ʧ��ʱ������ -1 ֵ
;------------------------------------------------------------------- 
read_idt_descrptor64:
        and esi, 0FFh
        shl esi, 4                                      ; vector * 16
        mov r8, rsi
        add esi, 15
        xor eax, eax
        dec rax
        mov rdx, rax
        
        ;;
        ;; ����Ƿ� limit
        ;;
        cmp esi, [fs: SDA.IdtLimit]
        ja read_idt_descriptor64.done
        ;;
        ;; ��ȡ IDT ����
        ;;
        add r8, [fs: SDA.IdtBase]
        mov rax, [r8]
        mov rdx, [r8 + 8]
read_idt_descriptor64.done:        
        ret




;-------------------------------------------------------------------
; write_idt_descriptor64(): �����ṩ�� vector ֵ�� IDT ��д��һ��������
; input:
;       esi - vector
;       rdx:rax - 128 λ������ֵ
; output:
;       rax - ������������ַ
;-------------------------------------------------------------------
write_idt_descriptor64:
        and esi, 0FFh
        shl esi, 4                                      ; vector * 16
        mov r8, [fs: SDA.IdtBase]
        add r8, rsi
        mov [r8], rax
        mov [r8 + 8], rdx
        ret
        

        
;-------------------------------------------------------------------
; mask_io_port_access64(): ���ζ�ĳ���˿ڵķ���
; input:
;       esi - �˿�ֵ
; output:
;       none
;-------------------------------------------------------------------
mask_io_port_access64:
        mov r8, [gs: PCB.IomapBase]                     ; ����ǰ Iomap ��ַ
        mov eax, esi
        shr eax, 3                                      ; port / 8
        and esi, 7                                      ; ȡ byte ��λ��
        bts [r8 + rax], esi                             ; ��λ
        ret
        
        
;-------------------------------------------------------------------
; unmask_io_port_access(): ���ζ�ĳ���˿ڵķ���
; input:
;       esi - �˿�ֵ
; output:
;       none
;-------------------------------------------------------------------
unmask_io_port_access64:
        mov r8, [gs: PCB.IomapBase]                     ; ����ǰ Iomap ��ַ
        mov eax, esi
        shr eax, 3                                      ; port / 8
        and esi, 7                                      ; ȡ byte ��λ��
        btr [r8 + rax], esi                             ; ��λ
        ret
        
        



        

        
;-------------------------------------------------------------------
; read_fs_base()
; input:
;       none
; output:
;       rax - fs base
; ������
;       1) ��ȡ FS base ֵ
;       2) basic �汾ʹ�� RDMSR ָ��� FS base
;       3) extended �汾ʹ�� RDFSBASE ָ��� FS base
;-------------------------------------------------------------------
read_fs_base:
        push rcx
        push rdx
        mov ecx, IA32_FS_BASE
        jmp read_fs_gs_base.legacy
        
read_fs_base_ex:
        push rcx
        push rdx
        mov ecx, IA32_FS_BASE
        mov rax, read_fs_base.rdfsbase
        mov r8, read_fs_gs_base.legacy
        jmp rw_fs_gs_base
        
;-------------------------------------------------------------------
; read_gs_base()
; input:
;       none
; output:
;       rax - gs base
; ������
;       1) ��ȡ GS base ֵ
;       2) basic �汾ʹ�� RDMSR ָ��� GS base
;       3) extended �汾ʹ�� RDFSBASE ָ��� GS base
;-------------------------------------------------------------------
read_gs_base:
        push rcx
        push rdx
        mov ecx, IA32_GS_BASE
        jmp read_fs_gs_base.legacy
        
read_gs_base_ex:
        push rcx
        push rdx
        mov ecx, IA32_GS_BASE        
        mov rax, read_gs_base.rdgsbase
        mov r8, read_fs_gs_base.legacy        
        jmp rw_fs_gs_base        
        

;-------------------------------------------------------------------
; write_fs_base()
; input:
;       rsi - fs base
; output:
;       none
; ������
;       1) д FS base ֵ
;       2) basic �汾ʹ�� WRMSR ָ��д FS base
;       3) extended �汾ʹ�� WRFSBASE ָ��д FS base
;-------------------------------------------------------------------
write_fs_base:
        push rcx
        push rdx
        mov ecx, IA32_FS_BASE
        jmp write_fs_gs_base.legacy        
        
write_fs_base_ex:
        push rcx
        push rdx
        mov ecx, IA32_FS_BASE        
        mov rax, write_fs_base.wrfsbase
        mov r8, write_fs_gs_base.legacy        
        jmp rw_fs_gs_base
        
        
;-------------------------------------------------------------------
; write_gs_base()
; input:
;       rsi - gs base
; output:
;       none
; ������
;       1) д GS base ֵ
;       2) basic �汾ʹ�� WRMSR ָ��д GS base
;       3) extended �汾ʹ�� WRGSBASE ָ��д GS base
;-------------------------------------------------------------------
write_gs_base:
        push rcx
        push rdx
        mov ecx, IA32_GS_BASE
        jmp write_fs_gs_base.legacy  

write_gs_base_ex: 
        push rcx
        push rdx
        mov ecx, IA32_GS_BASE       
        mov rax, write_gs_base.wrgsbase
        mov r8, write_fs_gs_base.legacy  

                

rw_fs_gs_base:
        
        ;;
        ;; ��� RDWRFSBASE ָ���Ƿ����
        ;;
        test DWORD [gs: PCB.InstructionStatus], INST_STATUS_RWFSBASE
        cmovz rax, r8
        jmp rax
        

       
read_fs_base.rdfsbase:
        ;;
        ;; �� FS base
        ;;
        rdfsbase rax
        jmp rw_fs_gs_base.done

read_gs_base.rdgsbase:
        ;;
        ;; �� GS base
        ;;
        rdgsbase rax
        jmp rw_fs_gs_base.done
        
write_fs_base.wrfsbase:        
        ;;
        ;; д FS base
        ;;
        wrfsbase rsi
        jmp rw_fs_gs_base.done
        
write_gs_base.wrgsbase:
        ;;
        ;; д GS base
        ;;
        wrgsbase rsi
        jmp rw_fs_gs_base.done

read_fs_gs_base.legacy:        
        ;;
        ;; ʹ�� legacy ��ʽ�� FS/GS base
        ;;
        rdmsr
        shl rdx, 32
        or rax, rdx   
        jmp rw_fs_gs_base.done
        
write_fs_gs_base.legacy:                
        ;;
        ;; ʹ�� legacy ��ʽд FS/GS base
        ;;
        shld rdx, rsi, 32
        mov eax, esi
        wrmsr       
        
rw_fs_gs_base.done:        
        pop rdx
        pop rcx
        ret        
        








;-------------------------------------------------
; bit_swap64(): ���� qword �ڵ�λ
; input:
;       rsi - source
; output:
;       rax - dest
; ����:
;       dest[63] <= source[0]
;       ... ...
;       dest[0]  <= source[63]
;------------------------------------------------- 
bit_swap64:
        push rcx
        mov ecx, 64
        xor eax, eax
        
        ;;
        ;; ѭ���ƶ� 1 λֵ
        ;;
bit_swap64.loop:        
        shl rsi, 1                              ; rsi ��λ�Ƴ��� CF
        rcr rax, 1                              ; CF ���� rax ��λ
        dec ecx
        jnz bit_swap64.loop
        pop rcx        
        ret
                        


        


%if 0
                                
                        
;-------------------------------------------------
; check_new_line64()
; input:
;       esi - string
; output:
;       0 - no, otherwise yes.
; ����:
;       �����ṩ���ַ���������Ƿ���Ҫת��
;-------------------------------------------------          
check_new_line64:
        push rcx
        call strlen64
        mov ecx, eax                            ; �ַ�������
        shl ecx, 1                              ; length * 2
        call target_video_buffer_column64
        neg eax
        add eax, 80 * 2
        cmp eax, ecx
        jae check_new_line64.done
        ;;
        ;; ����
        ;;
        add [fs: SDA.VideoBufferPtr], eax
check_new_line64.done:        
        pop rcx
        ret  

%endif


                 



;-------------------------------------------------
; print_hex_value64()
; input:
;       rsi - value
; output:
;       none
; ����:
;       1) ��ӡ 64 λʮ��������
;-------------------------------------------------
print_qword_value64:
print_hex_value64:
        push r10
        mov r10, rsi
        ;;
        ;; ��ӡ�� 32 λ
        ;;
        shr rsi, 32
        call print_dword_value
        ;;
        ;; ��ӡ�� 32 λ
        ;;
        mov esi, r10d
        call print_dword_value
        pop r10
        ret


;-------------------------------------------------
; print_decimal64()
; input:
;       rsi - value
; output:
;       none
; ����:
;       ��ӡʮ������
;-------------------------------------------------
print_decimal64:
print_dword_decimal64:
        push rdx
        push rcx
        mov rax, rsi
        mov [crt.quotient], rax
        mov ecx, 10
        
        ;;
        ;; ָ������β���������������ǰд
        ;;
        mov BYTE [crt.digit_array + 60], 0
        lea rsi, [crt.digit_array + 59]

print_decimal64.loop:
        dec rsi
        xor edx, edx
        div rcx                                 ; value / 10
        
        ;;
        ;; ������Ƿ�Ϊ 0��Ϊ 0 ʱ���� 10 ����
        ;;
        test rax, rax
        cmovz rdx, [crt.quotient]
        mov [crt.quotient], rax
        lea rdx, [rdx + '0']                    ; ����ת��Ϊ�ַ�
        mov [rsi], dl                           ; д������
        jnz print_decimal64.loop
        
        ;;
        ;; �����ӡ�����ִ�
        ;;
        call puts
        pop rcx
        pop rdx
        ret



;------------------------------------------------------
; get_spin_lock64()
; input:
;       rsi - lock
; output:
;       none
; ����:
;       1) �˺����������������
;       2) �������Ϊ spin lock ��ַ
;------------------------------------------------------
get_spin_lock64:
        push rdx
        ;;
        ;; ��������������˵��:
        ;; 1) ʹ�� bts ָ�������ָ������
        ;;    lock bts DWORD [rsi], 0
        ;;    jnc AcquireLockOk
        ;;
        ;; 2) ������ʹ�� cmpxchg ָ��
        ;;    lock cmpxchg [rsi], edi
        ;;    jnc AcquireLockOk
        ;;    
        
        xor eax, eax
        mov edi, 1        
        
        ;;
        ;; ���Ի�ȡ lock
        ;;
get_spin_lock64.acquire:
        lock cmpxchg [rsi], edi
        je get_spin_lock64.done

        ;;
        ;; ��ȡʧ�ܺ󣬼�� lock �Ƿ񿪷ţ�δ������
        ;; 1) �ǣ����ٴ�ִ�л�ȡ����������
        ;; 2) �񣬼������ϵؼ�� lock��ֱ�� lock ����
        ;;
get_spin_lock64.check:        
        mov eax, [rsi]
        test eax, eax
        jz get_spin_lock64.acquire
        pause
        jmp get_spin_lock64.check
        
get_spin_lock64.done:                
        pop rdx
        ret
        


;------------------------------------------------------
; delay_with_us64()
; input:
;       esi - ��ʱ us ��
; output:
;       none
; ����:
;       1) ִ����ʱ����
;       2) ��ʱ�ĵ�λΪus��΢�룩
;------------------------------------------------------
delay_with_us64:
        push rdx
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
delay_with_us64.loop:
        rdtsc
        cmp edx, edi
        jne delay_with_us64.@0
        cmp eax, esi
delay_with_us64.@0:
        jb delay_with_us64.loop
        
        pop rdx
        ret
        
        
        
        

%if 0
;-----------------------------------------------------
; wait_esc_for_reset64()
; input:
;       none
; output:
;       none
; ����:
;       1) �ȴ����� <ESC> ������
;------------------------------------------------------
wait_esc_for_reset64:
        mov esi, 24
        mov edi, 0
        call set_video_buffer
        mov rsi, Ioapic.WaitResetMsg
        call puts64

        ;;
        ;; �ȴ�����
        ;;        
wait_esc_for_reset64.loop:
        call read_keyboard
        cmp al, SC_ESC
        jne wait_esc_for_reset64.loop
        
wait_esc_for_reset64.next:

        ;;
        ;; ִ�� CPU RESET ����
        ;; 1) ����ʵ������ʹ�� INIT RESET
        ;; 2) ��vmware ��ʹ�� CPU RESET
        ;;
        
%ifdef REAL
        ;;
        ;; ʹ�� INIT RESET ����
        ;;
        mov rax, [gs: PCB.LapicBase]
        ;;
        ;; �����д������㲥 INIT
        ;;
        mov DWORD [rax + ICR1], 0FF000000h
        mov DWORD [rax + ICR0], 00004500h   
        
%else  
        ;;
        ;; ִ�� CPU hard reset ����
        ;;
        RESET_CPU 
%endif        
        ret
        
             
%endif        
        
 

%include "..\lib\sse64.asm"
