; module.inc
; Copyright (c) 2009-2013 mik 
; All rights reserved.


%ifndef __MODULE_INC__
%define __MODULE_INC__


;---------------------------------------------------------------------------
; 宏 MODULE_HEADER: 定义模块头结构
; input:
;       $1 - 模块 size
; example:
;       MODULE_HEADER   1, (PROECTED_END - PROTECTED_BEGIN)
; explain:
;       定义 protected 模块头结构，大小为 从 PROTECTED_END - PROTECTED_BEGIN
;       位于 disk 的扇区 1 上
;----------------------------------------------------------------------------
%macro MODULE_HEADER    1
header_size:            DW      8h              ; MODULE_HEADER 结构 6 bytes
sector_position:        DW      $1              ; 模块在 disk 的扇区位置
module_size:            DD      $2              ; 模块大小
%endmacro



%endif
