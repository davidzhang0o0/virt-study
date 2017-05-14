;*************************************************
;* debug.asm                                     *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************



;
; ���ܼ�ؿ�
;

;--------------------------------------------
; init_perfmon_unit()
; input:
;       none
; output:
;       none
; ������
;       1) ����Ƿ����� Intel ƽ̨
;       2) ������ counter
;--------------------------------------------
init_perfmon_unit:
        push ecx
        push edx
        
        mov eax, [gs: PCB.Vendor]
        cmp eax, VENDOR_AMD
        je init_perfmon_unit.done
        
        ;;
        ;; perfmon ��ʼ����
        ;; �ر����� counter �� PEBS 
        ;; �� overflow ��־λ
        ;;
        
        DISABLE_GLOBAL_COUNTER
        DISABLE_PEBS
        RESET_COUNTER_OVERFLOW       
        RESET_PMC
        RESET_FIXED_PMC        
        
init_perfmon_unit.done:        
        pop edx
        pop ecx
        ret


;--------------------------------------------
; get_unhalted_cpi(): ���� non-halted CPI ֵ
; input:
;       esi - ���ĺ�������
; outpu:
;       eax - CPI ֵ
; ����:
;       ʹ�� CPU_CLK_UNHALTED.CORE �¼�
;-------------------------------------------
get_unhalted_cpi:
        push ecx
        push edx
        ;*
        ;* �ȹر�Fixed������������Ϊ0ֵ
        ;*
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR1_EN)
        RESET_FIXED_PMC

        ;*
        ;* ����Fixed����������ʼ����
        ;*
        mov ecx, IA32_FIXED_CTR_CTRL
        mov eax, 0BBh
        mov edx, 0
        wrmsr
        ENABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR1_EN)

        call esi                ; ���ñ���������
        
        ;*
        ;* �ر�Fxied��������ֹͣ����
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR1_EN)
        
        mov ecx, IA32_FIXED_CTR0
        rdmsr
        push eax
        push edx
        mov ecx, IA32_FIXED_CTR1
        rdmsr
        push eax
        push edx
        RESET_FIXED_PMC
        pop edx
        pop eax
        pop edi
        pop esi 
        div esi
        pop edx
        pop ecx
        ret


;--------------------------------------------
; get_nominal_cpi(): ���� non-nominal CPI ֵ
; input:
;       esi - ���ĺ�������
; outpu:
;       eax - CPI ֵ
; ������
;       ʹ�� CPU_CLK_UNHALTED.REF �¼�
;-------------------------------------------
get_nominal_cpi:
        push ecx
        push edx
        ;*
        ;* �ȹر�Fixed������������Ϊ0ֵ
        ;*
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)
        RESET_FIXED_PMC

        ;*
        ;* ����Fixed����������ʼ����
        mov ecx, IA32_FIXED_CTR_CTRL
        mov eax, 0B0Bh
        mov edx, 0
        wrmsr
        ENABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)
        call esi                ; ���ò��Ժ���
        
        ;*
        ;* �ر�Fxied��������ֹͣ����
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)
        
        mov ecx, IA32_FIXED_CTR0
        rdmsr
        push eax
        push edx
        mov ecx, IA32_FIXED_CTR2
        rdmsr
        push eax
        push edx
        RESET_FIXED_PMC
        pop edx
        pop eax
        pop edi
        pop esi
        div esi                 
        pop edx
        pop ecx
        ret







;-----------------------------------------------
; support_full_write(): �����Ƿ�֧�� full-write
; output:
;        1-support, 0-no support
;-----------------------------------------------
support_full_write:
        ;;
        ;; ��� PerfCapabilities[13] λ
        ;;       
        mov eax, [gs: PCB.PerfCapabilities]
        test eax, PERF_FW_WRITE_AVAILABLE
        setnz al
        movzx eax, al
        ret


;----------------------------------------------
; write_counter_maximum(): д�� counter �����ֵ
; input:
;       esi-counter
;-----------------------------------------------
write_counter_maximum:
        push ecx
        push edx
        call support_full_write                 ; �Ƿ�֧��д�����ֵ
        mov edi, 0FFFFh
        xor edx, edx
        test eax, eax
        mov eax, 0FFFFFFFFh
        lea ecx, [esi + 400h]                   ; IA32_A_PCMx
        cmovnz edx, edi
        cmovz ecx, esi
        wrmsr
        pop edx
        pop ebx
        ret

;---------------------------------------------------
; check_counter_overflow(): ����Ƿ� counter �������
; output:
;        1-yes, 0-no
;---------------------------------------------------
test_counter_overflow:
check_counter_overflow:
        push ecx
        push edx
        mov ecx, IA32_PERF_GLOBAL_STATUS
        rdmsr
        test edx, 7                             ; ���� IA32_FIXED_CTRx �Ĵ���
        setnz dl
        jnz test_counter_overflow.done
        test eax, 0Fh                           ; ���� IA32_PMCx �Ĵ���
        setnz dl
test_counter_overflow.done:
        movzx eax, dl
        pop edx
        pop ecx
        ret

;-------------------------------------------------------
; test_pebs_buffer_overflow(): ��� PEBS buffer �Ƿ����
; output:
;        1-yes, 0-no
;-------------------------------------------------------
test_pebs_buffer_overflow:
check_pebs_buffer_overflow:
        mov ecx, IA32_PERF_GLOBAL_STATUS
        rdmsr
        bt edx, 30                              ; ���� OvfBuffer λ
        setc al
        movzx eax, al
        ret

;-----------------------------------------------
; test_pebs_interrupt(): ����Ƿ���� PEBS �ж�
; output:
;       1-yes, 0-no
;----------------------------------------------
test_pebs_interrupt:
check_pebs_interrupt:
        mov eax, [gs: PCB.PebsBufferIndex]      ; ԭ PEBS index ֵ
        mov esi, [gs: PCB.PebsIndexPointer]
        mov esi, [esi]                          ; ����ǰ PEBS index ֵ
        cmp esi, eax
        seta al                                 ; ��ǰ PEBS index ����ԭֵ������ 1
        movzx eax, al
        ret


;--------------------------------------------------------------------
; reset_pmi_counter_overflow(): ���� PMI �жϲ����� counter overflow 
;---------------------------------------------------------------------
reset_pmi_counter_overflow:
        push ecx
        push edx
        mov ecx, IA32_PERF_GLOBAL_STATUS
        rdmsr
        mov esi, eax                            ; ���� overflow status
        mov ecx, IA32_PEBS_ENABLE
        rdmsr
        and eax, esi                            ; ȡ PEBS overflow status
        not eax
        and eax, esi                            ; ȡ PMI overflow status
        mov ecx, IA32_PERF_GLOBAL_OVF_CTRL
        mov edx, 0
        wrmsr
        pop edx
        pop ecx
        ret


;------------------------------
; ��ӡ IA32_PERFEVTSELx �Ĵ���
;-----------------------------
dump_perfevtsel:
        jmp do_dump_perfevtsel
dp_msg1 db '<', 0
dp_msg2 db '>', 0        
dp_msg3 db ' ', 0
do_dump_perfevtsel:        
        push ecx
        push ebx
        xor ebx, ebx
        mov ecx, IA32_PERFEVTSEL0
        mov esi, perfevtsel
        call puts
        
do_dump_perfevtsel_loop:        
        mov esi, dp_msg1
        call puts
        mov esi, ebx
        call print_dword_decimal
        mov esi, dp_msg2
        call puts
        rdmsr
        mov esi, eax
        call print_dword_value
        mov esi, dp_msg3
        call puts
        inc ebx
        inc ecx
        cmp ecx, IA32_PERFEVTSEL3
        jbe do_dump_perfevtsel_loop
        call println
        pop ebx
        pop ecx
        ret

;----------------------------------
; ��ӡ PMC �Ĵ���
;----------------------------------
dump_pmc:
        push ecx
        push ebx
        xor ebx, ebx
        mov ecx, IA32_PMC0
        mov esi, pmc
        call puts
        
dump_pmc_loop:        
        mov esi, dp_msg1
        call puts
        mov esi, ebx
        call print_dword_decimal
        mov esi, dp_msg2
        call puts
        rdmsr
        mov esi, eax
        mov edi, edx
        call print_qword_value
        mov esi, dp_msg3
        call puts
        inc ebx
        inc ecx
        cmp ecx, IA32_PMC3
        jbe dump_pmc_loop
        call println
        pop ebx
        pop ecx
        ret
        
;----------------------------
; ��ӡ Fixed-function counter
;----------------------------
dump_fixed_pmc:
        push ecx
        push ebx
        xor ebx, ebx
        mov ecx, IA32_FIXED_CTR0
        mov esi, fixed_pmc
        call puts
        
dump_fixed_pmc_loop:        
        mov esi, dp_msg1
        call puts
        mov esi, ebx
        call print_dword_decimal
        mov esi, dp_msg2
        call puts
        rdmsr
        mov esi, eax
        mov edi, edx
        call print_qword_value
        mov esi, dp_msg3
        call puts
        inc ebx
        inc ecx
        cmp ecx, IA32_FIXED_CTR2
        jbe dump_fixed_pmc_loop
        call println
        pop ebx
        pop ecx
        ret

;--------------------------
;��ӡ fixed counter control
;---------------------------
dump_fixed_counter_control:
        mov esi, fixed_ctr_ctrl
        call puts
        mov ecx, IA32_FIXED_CTR_CTRL
        rdmsr
        mov esi, eax
        mov edi, edx
        call print_qword_value
        call println
        ret

;----------------------------------
; ��ӡ IA32_PERF_GLOBAL_CTRL �Ĵ���
;----------------------------------
dump_perf_global_ctrl:
dump_perfmon_global_ctrl:
        mov esi, perfmon_global_ctrl
        call puts
        mov ecx, IA32_PERF_GLOBAL_CTRL
        rdmsr
        mov esi, eax
        mov edi, edx
        call print_qword_value
        call println
        ret

;----------------------------------
; ��ӡ IA32_PERF_GLOBAL_STATUS �Ĵ���
;----------------------------------        
dump_perf_global_status:
dump_perfmon_global_status:
        mov esi, perfmon_global_status
        call puts
        mov ecx, IA32_PERF_GLOBAL_STATUS
        rdmsr
        mov esi, eax
        mov edi, edx
        call print_qword_value
        call println
        ret        
;----------------------------------
; ��ӡ IA32_PERF_GLOBAL_OVF �Ĵ���
;----------------------------------
dump_perf_global_ovf_ctrl:
dump_perfmon_global_ovf:
        mov esi, perfmon_global_ovf
        call puts
        mov ecx, IA32_PERF_GLOBAL_OVF_CTRL
        rdmsr
        mov esi, eax
        mov edi, edx
        call print_qword_value
        call println
        ret

;----------------------------------
; ��ӡ���� performace monitor �Ĵ���
;----------------------------------
dump_perfmon:
        call dump_perfevtsel
        call dump_pmc
        call dump_fixed_pmc
        call dump_fixed_counter_control
        call dump_perfmon_global_ctrl
        call dump_perfmon_global_status
        call dump_perfmon_global_ovf
        ret                        


;; **** ������ *******

; ���涨�屣�� performance monitor ��صļĴ���ֵ
perf_global_ctrl_value          dq 0
perf_global_status_value        dq 0




perfevtsel                      db 'PERFEVTSEL: ', 0
pmc                             db 'PMC: ', 0
fixed_pmc                       db 'FIXED_PMC: ', 0
fixed_ctr_ctrl                  db 'FIXED_CTR_CTRL:       ', 0
perfmon_global_ctrl             db 'PERF_GLOBAL_CTRL:     ', 0
perfmon_global_status           db 'PERF_GLOBAL_STATUS:   ', 0
perfmon_global_ovf              db 'PERF_GLOBAL_OVF_CTRL: ', 0