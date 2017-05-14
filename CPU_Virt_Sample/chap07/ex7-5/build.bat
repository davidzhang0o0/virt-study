@echo off

set Params=
set ConfigString1=
set ConfigString2=
set Target=x86
set GuestEnable=No
set GuestTarget=x86


:Loop
set s=%1
set s=%s:~2%
if "%s%"=="__X64" (set Target=x64)
if "%s%"=="GUEST_ENABLE" (set GuestEnable=Yes)
if "%s%"=="GUEST_X64" (
        set GuestTarget=x64
        goto :CommandLineNext
        )        
set Params=%Params% %1
:CommandLineNext       
shift
if "%1"=="" (goto :Next) else goto :Loop

:Next

if %GuestTarget%==x64 (
        if %Target%==x64 (
                set Params=%Params% -DGUEST_X64
                )
        )


::
:: ע��:
::      1) setup.asm ģ�����ʱ���� -D__STAGE1 ����
::      2) proected.asm ģ�����ʱ���� -D__STAGE2 ����
::      3) long.asm ģ�����ʱ���� -D__STAGE3 ����
::

nasm -I..\  ..\..\common\boot.asm %Params%
if %errorlevel%==0 (nasm -I..\  ..\..\common\setup.asm %Params% -D__STAGE1) else goto :END
if %errorlevel%==0 (
        if "%Target%"=="x64" (
                    set ConfigString1=..\..\common\long,0,c.img,256,200
                    set ConfigString2=..\..\common\long,0,demo.img,256,200
                    nasm -I..\  ..\..\common\long.asm %Params% -D__STAGE3
                ) else (
                    set ConfigString1=..\..\common\protected,0,c.img,64,200
                    set ConfigString2=..\..\common\protected,0,demo.img,64,200
                    nasm -I..\  ..\..\common\protected.asm %Params% -D__STAGE2
                )
        ) else goto :END
if %errorlevel%==0 (
        if "%GuestEnable%"=="Yes" (
                        nasm -I..\ ..\..\lib\Guest\GuestBoot.asm %Params% -D__STAGE4 && nasm -I..\ ..\..\lib\Guest\GuestKernel.asm %Params% -D__STAGE4
                )
        ) else goto :END
if %errorlevel%==0 (goto DoMerge) else goto :END


:DoMerge

:: $$$ ���� config.txt �ļ�����ʹ�� merge ����д��ӳ���ļ� $$$

::
:: #### Ϊ fat32 �ļ���ʽ�� U������ ####
::
echo #### ������ build.bat �Զ����ɵ�������Ϣ! #### > config.txt
echo. >> config.txt
echo. >> config.txt
echo #### Ϊ fat32 �ļ���ʽ�� U������ #### >> config.txt
echo ..\..\common\boot,0,c.img,63,1 >> config.txt
echo ..\..\common\setup,0,c.img,1,60 >> config.txt
echo %ConfigString1% >> config.txt
if "%GuestEnable%"=="Yes" (
        echo ..\..\lib\Guest\GuestBoot,0,c.img,512,6 >> config.txt
        echo ..\..\lib\Guest\GuestKernel,0,c.img,520,20 >> config.txt
        )
echo. >> config.txt

::
:: #### д�� floppy ��ӳ�� ####
::
echo #### д�� floppy ��ӳ�� #### >> config.txt
echo ..\..\common\boot,0,demo.img,0,1 >> config.txt
echo ..\..\common\setup,0,demo.img,1,60 >> config.txt
echo %ConfigString2% >> config.txt
if "%GuestEnable%"=="Yes" (
        echo ..\..\lib\Guest\GuestBoot,0,demo.img,512,6 >> config.txt
        echo ..\..\lib\Guest\GuestKernel,0,demo.img,520,20 >> config.txt
        )
echo. >> config.txt

::
:: #### д�� u �� ####
::
echo #### д�� u �� #### >> config.txt
echo c.img,0,\\.\g:,0,600 >> config.txt

::
:: ִ�� merge ����
::
call merge


:END        



