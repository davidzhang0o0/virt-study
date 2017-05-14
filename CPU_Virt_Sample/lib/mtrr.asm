;*************************************************
;* mtrr.asm                                      *
;* Copyright (c) 2009-2013 ��־                  *
;* All rights reserved.                          *
;*************************************************


;;
;; ���ģ���� mtrr �Ĵ���������
;;


;-----------------------------------------------------
; update_memory_type_manage_info()
; input:
;       none
; output:
;       none
; ������
;       �����ڴ����͹�����Ϣ
;-----------------------------------------------------
update_memory_type_manage_info:
        push ecx
        push edx
        ;;
        ;; ��� Memory Type Range Register ����
        ;;
        mov ecx, IA32_MTRRCAP
        rdmsr
        and eax, 0FFh
        mov [gs: PCB.MemTypeRecordMaximum], eax
        pop edx
        pop ecx
        ret


;-----------------------------------------------------
; enable_mtrr()
; input:
;       none
; output:
;       none
;-----------------------------------------------------
enable_mtrr:
        push ecx
        push edx
        mov ecx, IA32_MTRR_DEF_TYPE
        rdmsr
        or eax, 0C00h                   ; MTRR enable, Fixed-Range MTRR enable
        wrmsr
        pop edx
        pop ecx
        ret




;-----------------------------------------------------
; init_memory_type_manage_record()
; input:
;       none
; output:
;       none
; ������
;       ��ʼ���ڴ����͹����¼
;-----------------------------------------------------
init_memory_type_manage_record:
        push ebx
        push ecx
        mov eax, [gs: PCB.ProcessorStatus]
        test eax, CPU_STATUS_PG
        mov ebx, [gs: PCB.Base]
        cmovz ebx, [gs: PCB.PhysicalBase]
        mov DWORD [gs: PCB.MemTypeRecordTop], 0
        add ebx, PCB.MemTypeRecord
        
        xor eax, eax
        xor ecx, ecx
        mov [gs: PCB.MemTypeRecordTop], eax
init_memory_type_manage_record.loop:
        mov [ebx + MTMR.InUsed], al
        mov [ebx + MTMR.Type], al
        mov [ebx + MTMR.Start], eax
        mov [ebx + MTMR.Start + 4], eax
        mov [ebx + MTMR.Length], eax
        inc ecx
        cmp ecx, [gs: PCB.MemTypeRecordMaximum]
        jb init_memory_type_manage_record.loop
        pop ecx
        pop ebx
        ret



;-----------------------------------------------------
; init_memory_type_manane()
; input:
;       none
; output:
;       none
; ������
;       ��ʼ���ڴ����͹�����
;-----------------------------------------------------
init_memory_type_manage:
        call update_memory_type_manage_info
        call enable_mtrr
        call init_memory_type_manage_record
        ret



;-----------------------------------------------------------
; set_memory_range_type()
; input:
;       edx:eax - �ڴ���ʼλ��
;       esi - �ڴ淶Χ����
;       edi - �ڴ�����
; output:
;       1 - successful, 0 - failure
; ������
;       ����ĳ���ڴ淶Χ�� cache ����
;-----------------------------------------------------------
set_memory_range_type:
        push ecx
        and eax, 0FFFFF000h                             ; 4K �߽�
        and edx, [gs: PCB.MaxPhyAddrSelectMask + 4]
        and edi, 07h                                    ; ȷ���ڴ�����ֵ <= 7 
        mov ecx, [gs: PCB.MemTypeRecordTop]
        cmp ecx, [gs: PCB.MemTypeRecordMaximum]
        jae set_memory_range_type.done
        shl ecx, 1                                      ; ecx * 2
        or eax, edi
        add ecx, IA32_MTRR_PHYSBASE0
        wrmsr
        
        ;;
        ;; ���ڴ��������ϵ������� 4K Ϊ��λ�ĳ���
        ;;
        add esi, 0FFFh
        and esi, 0FFFFF000h
        
        ;;
        ;; Rang Mask �ļ��㷽������ 8K ��������
        ;;
        ;; 1) ����ֵ(8k) - 1 = 2000h - 1 = 1FFFh
        ;; 2) MaxPhyAddrSelectMask �� 32 λ - 1FFFh = FFFFE000h
        ;; 3) MaxPhyAddrSelectMask[63:32]:FFFFE000h �������յ� Rang Mask ֵ
        ;;
        dec esi                                         ; �󳤶� mask λ
        mov eax, [gs: PCB.MaxPhyAddrSelectMask]         ; select mask �� 32 λ
        mov edx, [gs: PCB.MaxPhyAddrSelectMask + 4]     ; select mask �� 32 λ
        sub eax, esi                                    ; �ó� Rang Mask ֵ
        bts eax, 11                                     ; valid = 1
        mov ecx, [gs: PCB.MemTypeRecordTop]
        shl ecx, 1                                      ; ecx * 2
        add ecx, IA32_MTRR_PHYSMASK0
        wrmsr
        
        ;;
        ;; ���� Top ָ��ֵ
        ;;
        inc DWORD [gs: PCB.MemTypeRecordTop]
        mov al, 1
set_memory_range_type.done:        
        movzx eax, al
        pop ecx
        ret


        
