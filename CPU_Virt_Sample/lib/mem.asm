;*************************************************
;* mem.asm                                       *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


;;
;; ˵����
;;      1) ʵ�� 64/32 λ�µ� kernel/user stack �Լ� kernel/user pool ���亯��
;;      2) ʹ�� 32 λ����
;;


;-----------------------------------------------------------------------
; alloc_user_stack_4k_base()
; input:
;       none
; output:
;       eax - 4K stack base�������ַ��
; ������
;       1)����һ��4Kҳ���С�� user stack base�Ŀ���ֵ         
;       2)�����µ�ǰ user stack base ��¼
;       3) �� x64 �� rax ���� 64 λ user stack base
;-----------------------------------------------------------------------
alloc_user_stack_4k_base:
alloc_user_stack_base:
        mov esi, SDA.UserStackBase                                      ; User stack �����¼
        jmp do_alloc_4k_base



;-----------------------------------------------------------------------
; alloc_user_stack_4k_physical_base()
; input:
;       none
; output:
;       eax - 4K stack base�������ַ��
; ������
;       1)����һ��4Kҳ���С�� user stack base�Ŀ���ֵ         
;       2)�����µ�ǰ user stack base ��¼
;       3) X64 �� rax ���� 64 λ user stack base ֵ
;-----------------------------------------------------------------------
alloc_user_stack_4k_physical_base:
alloc_user_stack_physical_base:
        mov esi, SDA.UserStackPhysicalBase                              ; User stack physical �ռ�����¼
        jmp do_alloc_4k_base



;-----------------------------------------------------------------------
; alloc_kernel_stack_4k_base()
; input:
;       none
; output:
;       eax - 4K stack base�������ַ�� 
; ������
;       1)����һ��4Kҳ���С�� kernel stack base�Ŀ���ֵ         
;       2)�����µ�ǰ kernel stack base ��¼
;       3) X64 �·��� 64 λֵ
;-----------------------------------------------------------------------
alloc_kernel_stack_4k_base:
alloc_kernel_stack_base:
        mov esi, SDA.KernelStackBase                                    ; kernel stack �ռ�����¼
        jmp do_alloc_4k_base




;-----------------------------------------------------------------------
; alloc_kernel_stack_4k_physical_base()
; input:
;       none
; output:
;       eax - 4K stack base�������ַ��   
; ������
;       1)����һ��4Kҳ���С�� kernel stack base�Ŀ���ֵ         
;       2)�����µ�ǰ kernel stack base ��¼
;       3) X64 �·��� 64 λֵ
;-----------------------------------------------------------------------
alloc_kernel_stack_4k_physical_base:
alloc_kernel_stack_physical_base:
        mov esi, SDA.KernelStackPhysicalBase                            ; kernel stack ����ռ�����¼
        jmp do_alloc_4k_base


        

;-----------------------------------------------------------------------
; alloc_user_pool_4k_base()
; input:
;       none
; output:
;       eax - 4K pool base�������ַ��
;-----------------------------------------------------------------------
alloc_user_pool_4k_base:      
alloc_user_pool_base:
        mov esi, SDA.UserPoolBase                                       ; user pool �ռ�����¼
        jmp do_alloc_4k_base
        


;-----------------------------------------------------------------------
; alloc_user_pool_4k_physical_base()
; input:
;       none
; output:
;       eax - 4K pool base�������ַ�� 
;-----------------------------------------------------------------------
alloc_user_pool_4k_physical_base:      
alloc_user_pool_physical_base:
        mov esi, SDA.UserPoolPhysicalBase                               ; user pool ����ռ�����¼
        jmp do_alloc_4k_base
        
                        

;-----------------------------------------------------------------------
; alloc_kernel_pool_4k_base()
; input:
;       none
; output:
;       eax - 4K pool base�������ַ��
;-----------------------------------------------------------------------
alloc_kernel_pool_4k_base:      
alloc_kernel_pool_base:
        mov esi, SDA.KernelPoolBase                                     ; kernel pool �ռ�����¼
        jmp do_alloc_4k_base
        
       
        

;-----------------------------------------------------------------------
; alloc_kernel_pool_4k_physical_base()
; input:
;       none
; output:
;       eax - 4K pool base�������ַ�� 
;-----------------------------------------------------------------------
alloc_kernel_pool_4k_physical_base:      
alloc_kernel_pool_physical_base:
        mov esi, SDA.KernelPoolPhysicalBase                             ; kernel pool ����ռ�����¼
        jmp do_alloc_4k_base


;-----------------------------------------------------------------------
; alloc_kernel_pool_base_n()
; input:
;       esi - size
; output:
;       eax - vritual address of kernel pool
; ������
;       1) �� kernel pool ����� n ҳ�ռ�
;-----------------------------------------------------------------------
alloc_kernel_pool_base_n:
        mov eax, esi
        shl eax, 12
        mov esi, SDA.KernelPoolBase                                     ; kernel pool �ռ�����¼
        jmp do_alloc_base
        
;-----------------------------------------------------------------------
; alloc_kernel_pool_physical_base_n()
; input:
;       esi - size
; output:
;       eax - physical address of pool
; ������
;       1���� pool ����� n ҳ����ռ�
;-----------------------------------------------------------------------
alloc_kernel_pool_physical_base_n:
        mov eax, esi
        shl eax, 12
        mov esi, SDA.KernelPoolPhysicalBase                             ; kernel pool ����ռ�����¼
        jmp do_alloc_base
        



;-----------------------------------------------------------------------
; do_alloc_4k_base()
; input:
;       esi - �ռ�����¼��
; output:
;       eax - ����һ�� 4k �ռ� base ֵ
; ����:
;       1) �����ڲ�ʹ�õ�ʵ�ֺ����������ڿռ�����¼���з���ռ�
;-----------------------------------------------------------------------
do_alloc_4k_base:

        mov eax, 4096                                                   ; ��������Ϊ 4K 

do_alloc_base:

%ifdef __STAGE1
        lock xadd [fs: esi], eax
%elifdef __X64
        DB 0F0h, 64h, 48h, 0Fh, 0C1h, 06h                               ; lock xadd [fs: rsi], rax
%else
        lock xadd [fs: esi], eax
%endif        
        ret







;-----------------------------------------------------------------------
; get_kernel_stack_4k_pointer()����̬���ȡһ�� kernel stack pointer ֵ
; input:
;       none
; output:
;       eax - stack pointer
; ������
;       1) ����һ�� 4K �� kernel stack �ռ䣬ӳ�䵽�����ַ
;       2) eax ���� stack �ռ�Ķ�����16�ֽڱ߽磩
;-----------------------------------------------------------------------
get_kernel_stack_4k_pointer:
get_kernel_stack_pointer:
        push ebx
        ;;
        ;; ���� stack �ռ�
        ;;
        call alloc_kernel_stack_4k_base                         ; ���������ַ
        REX.Wrxb
        mov ebx, eax
        call alloc_kernel_stack_4k_physical_base                ; ���������ַ


        ;;
        ;; ����ӳ�������ַ
        ;;
        REX.Wrxb
        mov esi, ebx                                            ; �����ַ
        REX.Wrxb
        mov edi, eax                                            ; �����ַ
        REX.wrxB
        mov eax, XD | RW | P                                    ; ҳ����
        call do_virtual_address_mapping

        REX.Wrxb
        add ebx, 0FF0h                                          ; ���� stack ����
        REX.Wrxb
        mov eax, ebx
        pop ebx
        ret
        

        

;-----------------------------------------------------------------------
; get_user_stack_4k_pointer()����̬���ȡһ�� user stack pointer ֵ
; input:
;       none
; output:
;       eax - stack pointer
; ������
;       1) ����һ�� 4K �� user stack �ռ䣬ӳ�䵽�����ַ
;       2) eax ���� stack �ռ�Ķ�����16�ֽڱ߽磩
;-----------------------------------------------------------------------
get_user_stack_4k_pointer:
get_user_stack_pointer:
        push ebx
        
        ;;
        ;; ���� stack �ռ�
        ;;
        call alloc_user_stack_4k_base                                   ; ���������ַ
        REX.Wrxb
        mov ebx, eax
        call alloc_user_stack_4k_physical_base                          ; ���������ַ
        
        ;;
        ;; ӳ�������ַ
        ;;
        REX.Wrxb
        mov esi, ebx                                                    ; �����ַ
        REX.Wrxb
        mov edi, eax                                                    ; �����ַ
        REX.wrxB
        mov eax, XD | US | RW | P   
        call do_virtual_address_mapping

        REX.Wrxb
        add ebx, 0FF0h                                                  ; ���� stack ����
        REX.Wrxb
        mov eax, ebx
        pop ebx
        ret




        
;----------------------------------------------------------------------------
; alloc_kernel_pool_4k()
; input:
;       none
; output:
;       pool if successful, 0 if failure
; ������
;       1) ��̬����һ�� 4K �� pool �ռ�
;----------------------------------------------------------------------------        
alloc_kernel_pool_4k:
alloc_kernel_pool:
        push ebx
        
        call alloc_kernel_pool_4k_physical_base                 ; ���� pool �����ַ�ռ�
        REX.Wrxb
        mov edi, eax
        call alloc_kernel_pool_4k_base                          ; ���� pool virtual address
        REX.Wrxb
        mov ebx, eax

        REX.Wrxb
        mov esi, eax
        REX.wrxB
        mov eax, RW | P                                         ; read/write, present
        call do_virtual_address_mapping
        
        ;;
        ;; �� kernel pool 
        ;;
        REX.Wrxb
        mov esi, ebx
        call clear_4k_buffer
        
        REX.Wrxb       
        mov eax, ebx                                            ; ���� kernel pool �ռ�
        pop ebx
        ret



;----------------------------------------------------------------------------
; alloc_kernel_pool_n()
; input:
;       esi - n
; output:
;       eax - �����ַ
;       edx - �����ַ
; ������
;       1) ��̬���� n ҳ�� pool �ռ�
;----------------------------------------------------------------------------        
alloc_kernel_pool_n:
        push ebx
        push ecx
        mov ecx, esi

        call alloc_kernel_pool_physical_base_n                  ; ���� N ҳ�����ַ�ռ�
        REX.Wrxb
        mov edx, eax                                            ; edi = physical address
        mov esi, ecx                                            ; N ҳ        
        call alloc_kernel_pool_base_n                           ; ���� N ҳ�����ַ�ռ�
        REX.Wrxb
        mov ebx, eax                                            ; ebx = virtual address

        REX.Wrxb
        mov esi, eax                                            ; esi = VA
        REX.Wrxb
        mov edi, edx                                            ; edi = PA
        REX.wrxB
        mov eax, RW | P                                         ; read/write, present        
%ifdef __X64
        DB 41h, 89h, 0C9h                                       ; mov r9d, ecx
%endif        
        call do_virtual_address_mapping_n
        
        ;;
        ;; �� kernel pool 
        ;;
        REX.Wrxb
        mov esi, ebx
        mov edi, ecx
        call clear_4k_buffer_n
        
        REX.Wrxb       
        mov eax, ebx                                            ; ���� kernel pool �ռ�
        pop ecx
        pop ebx
        ret
        
        


;-----------------------------------------------------------------------
; alloc_user_pool_4k()
; input:
;       none
; output:
;       pool if successful, 0 if failure
; ������
;        1) ��̬���ȡһ�� user pool
;-----------------------------------------------------------------------
alloc_user_pool_4k:
alloc_user_pool:
        push ebx
        
        call alloc_user_pool_4k_physical_base                   ; physical address
        REX.Wrxb
        mov edi, eax
        call alloc_user_pool_4k_base                            ; virtual address
        REX.Wrxb
        mov ebx, eax
               
        REX.Wrxb
        mov esi, eax
        REX.wrxB
        mov eax, US | RW | P                            ; read/write, user, present
        call do_virtual_address_mapping

        ;;
        ;; �� pool 
        ;;
        REX.Wrxb
        mov esi, ebx
        call clear_4k_buffer
        
        REX.Wrxb
        mov eax, ebx                                    ; ���� pool
        pop ebx
        ret
        
        

%if 0        
        
        
;--------------------------------------------------------------------------
; free_kernel_pool_4k_map_to_physical_address()��
; input:
;       esi - pool pointer
; output:
;       0 if successful, otherwis failure
; ������
;       1) �ṩ�� pool ��ַ�������� alloc_kernel_pool_4k_map_to_physical_address �ķ���
;       2) �� alloc_kernel_pool_4k_map_to_physical_address ����ʹ��
;--------------------------------------------------------------------------
free_kernel_pool_4k_map_to_physical_address:
        ;;
        ;; ���н�ӳ��
        call do_virtual_address_unmapped
        cmp eax, UNMAPPED_SUCCESS
        je free_kernel_pool_4k.next
        
        ;;
        ;; ��ӳ��ʧ�ܣ�ֱ�ӷ���
        ret


;--------------------------------------------------------------------------
; free_kernel_pool_4k()
; input:
;       esi - pool pointer
; output:
;       0 if successful, otherwis failure
;--------------------------------------------------------------------------
free_kernel_pool_4k:
        ;;
        ;; ���н�ӳ��
        call do_virtual_address_unmapped
        cmp eax, UNMAPPED_SUCCESS
        jne free_kernel_pool_4k.done
        
        ;;
        ;; �ͷ�����ռ�
        mov eax, -4096
        lock xadd [fs: SDA.KernelPoolPhysicalBase], eax         ; �������� pool base


free_kernel_pool_4k.next:
        ;;
        ;; �ͷ� pool �ռ�
        mov eax, -4096
        lock xadd [fs: SDA.KernelPoolBase], eax                 ; ���¿��� pool base
        mov eax, UNMAPPED_SUCCESS
                
free_kernel_pool_4k.done:        
        ret

        

;----------------------------------------------------------------------------
; alloc_user_pool_4k_map_to_physical_address()
; input:
;       esi - physical address
; output:
;       pool if successful, 0 if failure
; ������
;       1) ����һ�� 4k �� user pool �ռ�
;       2) �� pool �ռ�ӳ�䵽�ṩ�������ַ��
;       3) ���� pool �ռ�
;----------------------------------------------------------------------------
alloc_user_pool_4k_map_to_physical_address:
        push ebx
        mov edi, esi                            ; physical address
        and edi, 0FFFFF000h
        jmp alloc_user_pool_4k.next
        


        
        


;--------------------------------------------------------------------------
; free_user_pool_4k_map_to_physical_address()
; input:
;       esi - pool pointer
; output:
;       0 if successful, otherwis failure
; ������
;       1) �ṩ�� pool ��ַ�������� alloc_user_pool_4k_map_to_physical_address �ķ���
;       2) �� alloc_user_pool_4k_map_to_physical_address ����ʹ��
;--------------------------------------------------------------------------
free_user_pool_4k_map_to_physical_address:
        ;;
        ;; ���н�ӳ��
        call do_virtual_address_unmapped
        cmp eax, UNMAPPED_SUCCESS
        je free_user_pool_4k.next
        
        ;;
        ;; ��ӳ��ʧ�ܣ�ֱ�ӷ���
        ret


;--------------------------------------------------------------------------
; free_user_pool_4k()
; input:
;       esi - pool pointer
; output:
;       0 if successful, otherwis failure
;--------------------------------------------------------------------------
free_user_pool_4k:
        ;;
        ;; ���н�ӳ��
        call do_virtual_address_unmapped
        cmp eax, UNMAPPED_SUCCESS
        jne free_user_pool_4k.done
        
        ;;
        ;; �ͷ�����ռ�
        mov eax, -4096
        lock xadd [fs: SDA.UserPoolPhysicalBase], eax         ; �������� pool base


free_user_pool_4k.next:
        ;;
        ;; �ͷ� pool �ռ�
        mov eax, -4096
        lock xadd [fs: SDA.UserPoolBase], eax                 ; ���¿��� pool base
        mov eax, UNMAPPED_SUCCESS
                
free_user_pool_4k.done:        
        ret        
        
%endif        