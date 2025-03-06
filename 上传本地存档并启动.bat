@echo off
setlocal enabledelayedexpansion
set version=v0.3.1

:begin
::--------读取配置文件--------
set url=https://dav.jianguoyun.com/dav
set backup_interval=30
if not exist "AutoBackup.Config" (
    (
    echo #配置文件版本
    echo config_version=!version!
    echo #webdav网址（默认坚果云，按需修改）
    echo url=!url!
    echo #webdav账号
    echo id=!id!
    echo #webdav密码
    echo psw=!psw!
    echo #备份后多长时间之内不在备份（每天重置，单位：分钟）
    echo backup_interval=!backup_interval!
    ) > AutoBackup.Config
    start notepad AutoBackup.Config
    exit
) else (
    echo 正在读取配置文件...
    for /f "tokens=1,2 delims==" %%A in ('findstr /v "^#" "AutoBackup.Config"') do (
        set "%%A=%%B"
        @REM echo %%A,%%B
    )

    ::判断配置文件版本
    if not "%version%"=="!config_version!" (
        echo 当前版本 %version%，配置文件版本 !config_version!，将为您更新配置文件。
        pause
        move /y "AutoBackup.Config" "AutoBackup.Config.old"
        goto :begin
    )

    ::初次使用自动弹出配置界面
    if "!id!" == ""  (
        echo 请先配置webdav信息再使用
        pause
        start notepad AutoBackup.Config
        exit
    )
)

::--------读取缓存文件--------
if not exist "AutoBackup.temp" (
    echo 第一次启动需要创建缓存文件，请再次启动
    pause
    set last_datestamp=0
    set last_minstamp=0
    goto :save_temp_and_exit
) 
::读取缓存文件
for /f "tokens=1,2 delims==" %%A in ('findstr /v "^#" "AutoBackup.temp"') do (
    set "%%A=%%B"
    @REM echo %%A,%%B
)

::--------备份前准备--------
echo 正在拷贝存档...
del /Q "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata_backup\*.dat"
xcopy /Y "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata\" "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata_backup\" >nul

:: 获取当前日期和时间
for /f "tokens=1-5 delims=/ " %%a in ('date /t') do (set datestamp=%%a%%b%%c)
set "datestamp=%datestamp:~2%"
for /f "tokens=1-5 delims=: " %%a in ('time /t') do (set timestamp=%%a%%b)
::获取分钟时间戳
for /f "tokens=1-4 delims=:. " %%a in ("%time%") do (set /a hour=%%a & set /a minute=1%%b-100) & set /a minstamp=hour*60 + minute & 
@REM echo %minstamp%
PowerShell -NoProfile -Command "& {if (Get-Alias curl -ErrorAction SilentlyContinue) {Remove-Item Alias:curl}}"

::--------启动游戏--------
echo 即将启动游戏，备份将在后台进行...
start ./pvzHE-Launcher.exe

::--------判断是否备份--------
::判断是否跨天
@REM echo !datestamp!，!last_datestamp!
if !datestamp!==!last_datestamp! ( 
    set /a "t1=!last_minstamp! + 0"
    set /a "t2=!minstamp! + 0"
    set /a diff="!t2! - !t1!"
    @REM echo !t1!
    @REM echo !t2!
    @REM echo !diff!
    ::判断是否达到时间间隔
    if !diff! leq !backup_interval! (
            @REM pause
        goto :save_temp_and_exit
    )
)

::--------开始同步--------
echo 正在同步...
set last_datestamp=!datestamp!
set last_minstamp=!minstamp!
@REM pause
@REM goto :save_temp_and_exit
curl -s -X DELETE --header "Destination: %url%sync" --user "%id%:%psw%" >nul
curl --user "%id%:%psw%" -X MKCOL "%url%/pvzHE" >nul
curl --user "%id%:%psw%" -X MKCOL "%url%/pvzHE/sync" >nul
curl --user "%id%:%psw%" -X MKCOL "%url%/pvzHE/.history" >nul
curl --user "%id%:%psw%" -X MKCOL "%url%/pvzHE/.history/%datestamp%" >nul
curl --user "%id%:%psw%" -X MKCOL "%url%/pvzHE/.history/%datestamp%/%timestamp%" >nul

::同步
for /R "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata_backup\" %%f in (*) do (
    echo 正在上传 %%f，请耐心等待直到当前窗口自动关闭
    set file=%%f
    curl --user "%id%:%psw%" -T "!file!" "%url%/pvzHE/sync/"  >nul
    curl --user "%id%:%psw%" -T "!file!" "%url%/pvzHE/.history/%datestamp%/%timestamp%/"  >nul
)

::--------保存缓存文件--------
:save_temp_and_exit
(
    echo last_datestamp=!last_datestamp!
    echo last_minstamp=!last_minstamp! 
) > AutoBackup.temp

endlocal
exit
::--------更新日志--------
0.3.1
    优化了云端的路径，修复云端路径异常的bug。
    修复了更新时无法自动继承旧配置的bug（尽管在更新前这个bug并没有触发的机会）
0.3.0
    由于杂交2.3版本的部分小游戏占用存储较多，且频繁闪退，可能会消耗大量上传流量，对白嫖坚果云的用户非常不友好，该版本设置了最小备份间隔
    使用config和temp文件设置脚本的部分参数
0.2.0
    修复部分bug，脚本基本可用
0.1.0
    初次尝试撰写该脚本(用了一个通宵，写出了基本可用的脚本)


