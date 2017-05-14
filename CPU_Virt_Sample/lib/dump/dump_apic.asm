;*************************************************
; dump_apic.asm                                  *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************



		

;------------------------------
; dump_tmr()
; input:
;       esi - APIC page
; output:
;       none
; ������
;       1) ��ӡ TMR
;------------------------------
dump_tmr:
        push ebx        
        REX.Wrxb
        mov ebx, esi        
        mov esi, tmr
        call puts        
        mov esi, [ebx + TMR7]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + TMR6]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + TMR5]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + TMR4]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + TMR3]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + TMR2]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + TMR1]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + TMR0]
        call print_dword_value
        call println
        pop ebx
        ret
	
	
;--------------------------------
; dump_lvt()
; input:
;       esi - APIC page
; output:
;       none
; ������
;       ��ӡ LVT ��Ĵ���
;--------------------------------
dump_lvt:
        push ebx
        REX.Wrxb
        mov ebx, esi                
	mov esi, lvt_msg
	call puts
	mov esi, lvt_cmci
	call puts
	mov esi, [ebx + LVT_CMCI]
	call print_dword_value
	mov esi, lvt_timer
	call puts
	mov esi, [ebx + LVT_TIMER]
	call print_dword_value	
	mov esi, lvt_thermal
	call puts
	mov esi, [ebx + LVT_THERMAL]
	call print_dword_value	
	call println
	mov esi, lvt_perfmon
	call puts
	mov esi, [ebx + LVT_PERFMON]
	call print_dword_value	
	mov esi, lvt_lint0
	call puts
	mov esi, [ebx + LVT_LINT0]
	call print_dword_value	
	mov esi, lvt_lint1
	call puts
	mov esi, [ebx + LVT_LINT1]
	call print_dword_value	
	call println
	mov esi, lvt_error
	call puts
	mov esi, [ebx + LVT_ERROR]
	call print_dword_value	
	call println        
        pop ebx        
	ret



;------------------------------
; dump_irr()
; input:
;       esi - APIC page
; output:
;       none
; ������
;       1) ��ӡ IRR
;------------------------------
dump_irr:
        push ebx        
        REX.Wrxb
        mov ebx, esi        
        mov esi, irr
        call puts        
        mov esi, [ebx + IRR7]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + IRR6]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + IRR5]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + IRR4]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + IRR3]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + IRR2]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + IRR1]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + IRR0]
        call print_dword_value
        call println
        pop ebx
        ret


;------------------------------
; dump_isr()
; input:
;       esi - APIC page
; output:
;       none
; ������
;       1) ��ӡ ISR
;------------------------------
dump_isr:
        push ebx
        REX.Wrxb
        mov ebx, esi
        mov esi, isr
        call puts        
        mov esi, [ebx + ISR7]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + ISR6]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + ISR5]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + ISR4]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + ISR3]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + ISR2]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + ISR1]
        call print_dword_value
        mov esi, '_'
        call putc
        mov esi, [ebx + ISR0]
        call print_dword_value
        call println
        pop ebx
        ret
        
        
        
        

;------------------------------
; dump_apic()
; input:
;       esi - APIC page
; output:
;       none
; ������
;       1) ��ӡ apic�Ĵ�����Ϣ
;--------------------------------
dump_apic:
        push ebx
        
        REX.Wrxb
        mov ebx, esi
	mov esi, apicid
	call puts
	mov esi, [ebx + APIC_ID]		
	call print_dword_value
	mov esi, apicver
	call puts
	mov esi, [ebx + APIC_VER]
	call print_dword_value
	call println
	mov esi, tpr
	call puts
	mov esi, [ebx + TPR]
	call print_dword_value
	mov esi, apr
	call puts
	mov esi, [ebx + APR]
	call print_dword_value
	mov esi, ppr
	call puts
	mov esi, [ebx + PPR]
	call print_dword_value
	call println	
	mov esi, eoi
	call puts
	mov esi, [ebx + EOI]
	call print_dword_value
	mov esi, rrd
	call puts
	mov esi, [ebx + RRD]
	call print_dword_value
	mov esi, ldr
	call puts
	mov esi, [ebx + LDR]
	call print_dword_value	
	call println
	mov esi, dfr
	call puts
	mov esi, [ebx + DFR]
	call print_dword_value	
	mov esi, svr
	call puts
	mov esi, [ebx + SVR]
	call print_dword_value	
	call println

;��ӡ Interrupt Request Register
        REX.Wrxb
        mov esi, ebx
	call dump_irr
		
;; ��ӡ In-service register	
        REX.Wrxb
        mov esi, ebx
	call dump_isr

; ��ӡ tigger mode rigister
        REX.Wrxb
        mov esi, ebx
	call dump_tmr

	mov esi, esr
	call puts
	;call read_esr		; �� ESR �Ĵ���
	;mov esi, eax
        mov esi, [ebx + ESR]
	call print_dword_value
	mov esi, icr
	call puts
	mov esi, [ebx + ICR0]	
	mov edi, [ebx + ICR1]	
	call print_qword_value
	call println
	
; ��ӡ LVT ��Ĵ���
        REX.Wrxb
        mov esi, ebx
	call dump_lvt

; ��ӡ APIC timer �Ĵ���
	mov esi, init_count
	call puts
	mov esi, [ebx + TIMER_ICR]
	call print_dword_value
	mov esi, current_count
	call puts
	mov esi, [ebx + TIMER_CCR]
	call print_dword_value
	mov esi, dcr
	call puts
	mov esi, [ebx + TIMER_DCR]
	call print_dword_value
	call println
        
        pop ebx        
	ret
	


; ���� x2APIC ID ��ر���
x2apic_smt_mask_width		dd	0, 0, 0, 0, 0, 0, 0, 0
x2apic_smt_select_mask		dd	0, 0, 0, 0, 0, 0, 0, 0
x2apic_core_mask_width		dd	0, 0, 0, 0, 0, 0, 0, 0
x2apic_core_select_mask		dd	0, 0, 0, 0, 0, 0, 0, 0
x2apic_package_mask_width	dd	0, 0, 0, 0, 0, 0, 0, 0
x2apic_package_select_mask	dd	0, 0, 0, 0, 0, 0, 0, 0

x2apic_id			dd	0, 0, 0, 0, 0, 0, 0, 0
x2apic_package_id		dd	0, 0, 0, 0, 0, 0, 0, 0
x2apic_core_id			dd 	0, 0, 0, 0, 0, 0, 0, 0
x2apic_smt_id			dd	0, 0, 0, 0, 0, 0, 0, 0


;;; ���� xAPIC ID ��ر���
xapic_smt_mask_width		dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_smt_select_mask		dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_core_mask_width		dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_core_select_mask		dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_package_mask_width	dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_package_select_mask	dd	0, 0, 0, 0, 0, 0, 0, 0

xapic_id			dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_package_id		dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_core_id			dd	0, 0, 0, 0, 0, 0, 0, 0
xapic_smt_id			dd 	0, 0, 0, 0, 0, 0, 0, 0



;**** ���� *****
apicid				db	'apic ID: 0x', 0
apicver				db	'    apic version: 0x', 0
tpr					db	'TPR: 0x', 0
apr					db	'  APR: 0x', 0
ppr					db	'  PPR: 0x', 0
eoi					db	'EOI: 0x', 0	
rrd					db	'  RRD: 0x', 0
ldr					db	'  LDR: 0x', 0
dfr					db	'DFR: 0x', 0
svr					db	'  SVR: 0x', 0
isr					db	'ISR: 0x', 0
tmr					db	'TMR: 0x', 0	
irr					db	'IRR: 0x', 0
esr					db	'ESR: 0x', 0
icr					db	'  ICR: 0x', 0
lvt_msg				db	'---------------------- Local Vector Table -----------------', 10, 0
lvt_cmci			db	'CMCI: 0x', 0
lvt_timer			db	'  TIMER: 0x', 0
lvt_thermal			db	'  THERMAL: 0x', 0
lvt_perfmon			db	'PERFMON: 0x', 0
lvt_lint0			db	'  LINT0: 0x', 0
lvt_lint1			db	'  LINT1: 0x', 0
lvt_error			db	'ERROR: 0x', 0
init_count			db	'timer_ICR: 0x', 0
current_count		db	'  timer_CCR: 0x', 0
dcr					db	'  timer_DCR: 0x', 0
