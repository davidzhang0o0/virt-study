;*************************************************
; boot.asm                                       *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************

%include "..\inc\support.inc"
%include "..\inc\ports.inc"







;----------------------------------------------------
; MAKE_LOAD_MODULE_ENTRY
; input:
;       %1 - ģ����ص��ڴ�ε�ַ
;       %2 - ģ���ڴ��̵������ţ�LBA��
; output:
;       none
; ������
;       1) ����������Ҫ���ص�ģ���
;----------------------------------------------------
%macro MAKE_LOAD_MODULE_ENTRY   2
        %%segment       DW      %1
        %%sector        DW      %2
%endmacro

LOAD_MODULE_ENTRY_SIZE          EQU     4






        bits 16

    
;;
;; ע�⣺
;; 1) ���ڴ��������� real mode ��       
;; 2) int 19h ���� boot ģ����� BOOT_SEGMENT ��, BOOT_SEGMENT ����Ϊ 7C00h
;;
         
        org BOOT_SEGMENT
        jmp WORD Boot.Start
        
;;
;; ���ڱ��� int 13h/ax=08h ��õ� driver ����
;;
driver_parameters_table:        
        driver_number           DB      0               ; driver number
        driver_type             DB      0               ; driver type       
        cylinder_maximum        DW      0               ; ���� cylinder ��
        header_maximum          DW      0               ; ���� header ��
        sector_maximum          DW      0               ; ���� sector ��
        parameter_table         DW      0               ; address of parameter table 
                
;;
;; ���� int 13h ʹ�õ� disk address packet������ int 13h ��/д
;;        
disk_address_packet:
        size                    DW      10h             ; size of packet
        read_sectors            DW      0               ; number of sectors
        buffer_offset           DW      0               ; buffer far pointer(16:16)
        buffer_selector         DW      0               ; Ĭ�� buffer Ϊ 0
        start_sector            DQ      0               ; start sector



;;
;;
;; ����ģ�����Ҫ���������ģ�飨���Ŷ����� ..\inc\support.inc �ļ��
;; 1) setup ģ��
;; 2) ���� X64 ʱ long ģ�飬�� 32 λ�¼��� protected ģ��
;; 3) guest �� boot ģ��
;; 4) guest �� kernel ģ��
;;
load_module_table:
        MAKE_LOAD_MODULE_ENTRY          (SETUP_SEGMENT >> 4), SETUP_SECTOR

;;
;; �� 64 λ���л����£���Ҫ���� long ģ�飬������� proteccted ģ��
;;        
%ifdef __X64
        MAKE_LOAD_MODULE_ENTRY          (LONG_SEGMENT >> 4), LONG_SECTOR
%else
        MAKE_LOAD_MODULE_ENTRY          (PROTECTED_SEGMENT >> 4), PROTECTED_SECTOR
%endif

;;
;; ���綨���� GUEST_ENABLE ���ţ�����Ҫ���� GuestBoot �� GuestKernel ģ��
;;        
%ifdef GUEST_ENABLE
        MAKE_LOAD_MODULE_ENTRY          (GUEST_BOOT_SEGMENT >> 4), GUEST_BOOT_SECTOR
        MAKE_LOAD_MODULE_ENTRY          (GUEST_KERNEL_SEGMENT >> 4), GUEST_KERNEL_SECTOR
%endif
        
load_module_table.end:




;;########################## boot ģ����� ############################

Boot.Start:
        cli
        NMI_DISABLE                                             ; �ر� NMI
        FAST_A20_ENABLE                                         ; ���� A20 λ        
        
        ;; 
        ;; set BOOT_SEG environment
        ;;
        mov ax, cs
        mov ds, ax
        mov ss, ax
        mov es, ax
        mov sp, BOOT_SEGMENT                                    ; �� stack ��Ϊ BOOT_SEGMENT
        
        mov [driver_number], dl                                 ; ���� boot driver
        mov WORD [buffer_selector], es                          ; �����̵� buffer segment ����Ϊ es
        call get_driver_parameters                              ; �����̲���
        call clear_screen
        
        
        ;;
        ;; ������м���ģ�鹤��
        ;;

        mov bx, load_module_table                               ; ģ����ر�
load_module.loop:        
        mov ax, [bx]                                            
        mov [buffer_selector], ax                               ; segment ��ģ����ر��ж�ȡ
        mov WORD [buffer_offset], 0                             ; selector = 0
        mov ax, [bx + 2]
        mov [start_sector], ax                                  ; sector ��ģ����ر��ж�ȡ
        call load_module
        add bx, LOAD_MODULE_ENTRY_SIZE
        cmp bx, load_module_table.end
        jb load_module.loop



        ;;
        ;; ����ģ�鵽�ڴ��ת�� setup ģ����ڵ�ִ�У�SETUP_SEGMENT + 4��
        ;;
                
        jmp SETUP_SEGMENT + 4
       

        

;------------------------------------------------------
; clear_screen()
; description:
;       clear the screen & set cursor position at (0,0)
;------------------------------------------------------
clear_screen:
        mov ax, 0x0600
        xor cx, cx
        xor bh, 0x0f            ; white
        mov dh, 24
        mov dl, 79
        int 0x10
        mov ah, 02
        xor bh, bh
        xor dx, dx
        int 0x10        
        ret
        
        
  

;-----------------------------------------------------------------
; read_sector(): ��ȡ����
; input:
;       ʹ�� disk_address_packet �ṹ
; output:
;       0 - successful, otherwise - error code
;----------------------------------------------------------------        
read_sector:
        push es
        push bx
        mov es, WORD [buffer_selector]                  ; es = buffer_selector
               
        ;
        ; ��ʼ�������� 0FFFFFFFFh
        ;
        cmp DWORD [start_sector + 4], 0
        jnz check_lba
        
        ;
        ; ���ģ���ڵ��� 504M ��������ʹ�� CHS ģʽ
        ;
        cmp DWORD [start_sector], 504 * 1024 * 2        ; 504M
        jb chs_mode
        
check_lba:
        ;
        ; ����Ƿ�֧�� 13h ��չ����
        ;
        call check_int13h_extension
        test ax, ax
        jz chs_mode
        
lba_mode:        
        ;
        ; ʹ�� LBA ��ʽ�� sector
        ;
        call read_sector_with_extension
        test ax, ax
        jz read_sector_done


        ;
        ; ʹ�� CHS ��ʽ�� sector
        ;
chs_mode:       

        ;
        ; ���һ�ζ����� 63 �������������ȡ��ÿ������63����
        ;
        movzx cx, BYTE [read_sectors]
        mov bx, cx
        and bx, 3Fh                                     ; bl = 64����������
        shr cx, 6                                       ; read_sectors / 64
        
        mov BYTE [read_sectors], 64                     ; ÿ�ζ�ȡ64������
        
chs_mode.@0:        
        test cx, cx
        jz chs_mode.@1

        call read_sector_with_chs                       ; ������
                
        ;
        ; ������ʼ������buffer
        ;
        add DWORD [start_sector], 64                    ; ��һ����ʼ����
        add WORD [buffer_offset], 64 * 512              ; ָ����һ�� buffer ��
        setc al
        shl ax, 12
        add WORD [buffer_selector], ax                  ; selector ����
        dec cx
        jmp chs_mode.@0


chs_mode.@1:
        ;
        ; ��ȡʣ������
        ;
        mov [read_sectors], bl
        call read_sector_with_chs                
        
read_sector_done:      
        pop bx
        pop es
        ret



;--------------------------------------------------------
; check_int13h_extension(): �����Ƿ�֧�� int13h ��չ����
; input:
;       ʹ�� driver_paramter_table �ṹ
; ouput:
;       1 - support, 0 - not support
;--------------------------------------------------------
check_int13h_extension:
        push bx
        mov bx, 55AAh
        mov dl, [driver_number]                 ; driver number
        mov ah, 41h
        int 13h
        setnc al                                ; c = ʧ��
        jc do_check_int13h_extension_done
        cmp bx, 0AA55h
        setz al                                 ; nz = ��֧��
        jnz do_check_int13h_extension_done
        test cx, 1
        setnz al                                ; z = ��֧����չ���ܺţ�AH=42h-44h,47h,48h
do_check_int13h_extension_done:        
        pop bx
        movzx ax, al
        ret
        
        
        
;--------------------------------------------------------------
; read_sector_with_extension(): ʹ����չ���ܶ�����        
; input:
;       ʹ�� disk_address_packet �ṹ
; output:
;       0 - successful, otherwise - error code
;--------------------------------------------------------------
read_sector_with_extension:
        mov si, disk_address_packet             ; DS:SI = disk address packet        
        mov dl, [driver_number]                 ; driver
        mov ah, 42h                             ; ��չ���ܺ�
        int 13h
        movzx ax, ah                            ; if unsuccessful, ah = error code
        ret
                


;-------------------------------------------------------------
; read_sector_with_chs(): ʹ�� CHS ģʽ������
; input:
;       ʹ�� disk_address_packet �� driver_paramter_table
; output:
;       0 - successful
; unsuccessful:
;       ax - error code
;-------------------------------------------------------------
read_sector_with_chs:
        push bx
        push cx
        ;
        ; �� LBA ת��Ϊ CHS��ʹ�� int 13h, ax = 02h ��
        ;
        call do_lba_to_chs
        mov dl, [driver_number]                 ; driver number
        mov es, WORD [buffer_selector]          ; buffer segment
        mov bx, WORD [buffer_offset]            ; buffre offset
        mov al, BYTE [read_sectors]             ; number of sector for read
        test al, al
        jz read_sector_with_chs_done
        mov ah, 02h
        int 13h
        movzx ax, ah                            ; if unsuccessful, ah = error code
read_sector_with_chs_done:
        pop cx
        pop bx
        ret
        
        
        
;-------------------------------------------------------------
; do_lba_to_chs(): LBA ��ת��Ϊ CHS
; input:
;       ʹ�� driver_parameter_table �� disk_address_packet �ṹ
; output:
;       ch - cylinder �� 8 λ
;       cl - [5:0] sector, [7:6] cylinder �� 2 λ
;       dh - header
;
; ������
;       
; 1) 
;       eax = LBA / (head_maximum * sector_maximum),  cylinder = eax
;       edx = LBA % (head_maximum * sector_maximum)
; 2)
;       eax = edx / sector_maximum, head = eax
;       edx = edx % sector_maximum
; 3)
;       sector = edx + 1      
;-------------------------------------------------------------
do_lba_to_chs:
        movzx ecx, BYTE [sector_maximum]        ; sector_maximum
        movzx eax, BYTE [header_maximum]        ; head_maximum
        imul ecx, eax                           ; ecx = head_maximum * sector_maximum
        mov eax, DWORD [start_sector]           ; LBA[31:0]
        mov edx, DWORD [start_sector + 4]       ; LBA[63:32]        
        div ecx                                 ; eax = LBA / (head_maximum * sector_maximum)
        mov ebx, eax                            ; ebx = cylinder
        mov eax, edx
        xor edx, edx        
        movzx ecx, BYTE [sector_maximum]
        div ecx                                 ; LBA % (head_maximum * sector_maximum) / sector_maximum
        inc edx                                 ; edx = sector, eax = head
        mov cl, dl                              ; secotr[5:0]
        mov ch, bl                              ; cylinder[7:0]
        shr bx, 2
        and bx, 0C0h
        or cl, bl                               ; cylinder[9:8]
        mov dh, al                              ; head
        ret
        
        
        
        
;---------------------------------------------------------------------
; get_driver_parameters(): �õ� driver ����
; input:
;       ʹ�� driver_parameters_table �ṹ
; output:
;       0 - successful, 1 - failure
; failure: 
;       ax - error code
;---------------------------------------------------------------------
get_driver_parameters:
        push dx
        push cx
        push bx
        mov ah, 08h                             ; 08h ���ܺţ��� driver parameters
        mov dl, [driver_number]                 ; driver number
        mov di, [parameter_table]               ; es:di = address of parameter table
        int 13h
        jc get_driver_parameters_done
        mov BYTE [driver_type], bl              ; driver type for floppy drivers
        inc dh
        mov BYTE [header_maximum], dh           ; ��� head ��
        mov BYTE [sector_maximum], cl           ; ��� sector ��
        and BYTE [sector_maximum], 3Fh          ; �� 6 λ
        shr cl, 6
        rol cx, 8
        and cx, 03FFh                           ; ��� cylinder ��
        inc cx
        mov [cylinder_maximum], cx              ; cylinder
get_driver_parameters_done:
        movzx ax, ah                            ; if unsuccessful, ax = error code
        pop bx
        pop cx
        pop dx
        ret
 
 
;-------------------------------------------------------------------
; load_module(int module_sector, char *buf)
; input:
;       ʹ�� disk_address_packet �ṹ���ṩ�Ĳ���
; output:
;       none
; ������
;       1) ����ģ�鵽 buf ������
;-------------------------------------------------------------------
load_module:
        push es
        push cx
        
        ;;
        ;; ���� 1 ���������õ�ģ��� size ֵ��Ȼ�������� size ��������ģ���ȡ
        ;;
        mov WORD [read_sectors], 1
	call read_sector
	test ax, ax
	jnz do_load_module_done
        movzx esi, WORD [buffer_offset]
        mov es, WORD [buffer_selector]
	mov ecx, [es: esi]                                              ; ��ȡģ�� siz
	test ecx, ecx
	setz al
	jz do_load_module_done
        
        ;;
        ;; size ���ϵ����� 512 ����
        ;;
	add ecx, 512 - 1
	shr ecx, 9							; ���� block��sectors��
        mov WORD [read_sectors], cx                                     ; 
	call read_sector
do_load_module_done:  
        pop cx
        pop es
	ret
 
 
 
                                                        
times 510-($-$$) db 0
        dw 0AA55h
