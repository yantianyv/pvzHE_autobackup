@echo off
setlocal enabledelayedexpansion
set version=v0.3.0

:begin
::--------读取配置文件--------
set url=https://dav.jianguoyun.com/dav/pvzHE
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
    echo backup_interval=!ackup_interval!
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

@REM ::--------读取缓存文件--------
@REM if not exist "AutoBackup.temp" (
@REM     echo 第一次启动需要创建缓存文件，请再次启动
@REM     pause
@REM     set last_datestamp=0
@REM     set last_minstamp=0
@REM     goto :save_temp_and_exit
@REM ) 
@REM ::读取缓存文件
@REM for /f "tokens=1,2 delims==" %%A in ('findstr /v "^#" "AutoBackup.temp"') do (
@REM     set "%%A=%%B"
@REM     @REM echo %%A,%%B
@REM )

::兼容win11的powershell
PowerShell -NoProfile -Command "& {if (Get-Alias curl -ErrorAction SilentlyContinue) {Remove-Item Alias:curl}}"

:: 获取当前日期和时间
for /f "tokens=1-5 delims=/ " %%a in ('date /t') do (set datestamp=%%a%%b%%c)
set "datestamp=%datestamp:~2%"
for /f "tokens=1-5 delims=: " %%a in ('time /t') do (set timestamp=%%a%%b)

echo 原先的本地存档会在"C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata_old\"目录下备份
echo 该脚本会尝试从云端恢复您的用户数据与无尽模式关卡进度，
echo 该脚本具有一定局限性，如果您曾经创建并删除过大量用户，或者用户数量较多，建议手动恢复存档。
echo 即将开始备份，如需取消请立即关闭窗口。备份开始后请不要中途关闭。
xcopy /Y "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata\" "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata_old\%datestamp%\%timestamp%\" >nul
pause
echo ————————————————————————————————————————
del /Q "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata\*.*"

::同步
set datapath=C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata
curl -s --user %id%:%psw% --head %url%/pvzHE/sync/users.dat 2>nul | findstr "200 OK" >nul
if !errorlevel! geq 1 (
    echo 云端存档异常，正在撤销同步
    xcopy /Y "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata_old\%datestamp%\%timestamp%\" "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata\" >nul
    echo 已撤销同步，请检查云端存档并从历史记录中手动恢复数据
    pause
    exit
)

::用户列表
curl -s --user "%id%:%psw%" -L -o "%datapath%\users.dat" "%url%/pvzHE/sync/users.dat" 
rem >nul

::无尽进度
set i=1
set j=1
set failCount=0
:loop
set /a "failThreshold=3+(i*1/5)"
set filename=user!i!.dat
set filename_bin=user!i!.bin
set downloadpath=%datapath%\!filename!
set downloadpath_bin=%datapath%\!filename_bin!
curl -s --user %id%:%psw% --head %url%/pvzHE/sync/!filename! 2>nul | findstr "200 OK" >nul
if !errorlevel! equ 0 (
    echo 仍在同步，请勿退出...
    curl -s --user %id%:%psw% -L -o "!downloadpath!" "%url%/pvzHE/sync/!filename!"
    curl -s --user %id%:%psw% -L -o "!downloadpath_bin!" "%url%/pvzHE/sync/!filename_bin!"
    for /l %%j in (768, 1, 802) do (
        :: 构建文件名和下载路径
        set filename=game!i!_%%j%.dat
        set downloadpath=%datapath%\!filename!

        :: 使用curl检查文件是否存在
        curl -s --user %id%:%psw% --head %url%/pvzHE/sync/!filename! 2>nul | findstr "200 OK" >nul
        if !errorlevel! equ 0 (
            curl -s --user %id%:%psw% -L -o "!downloadpath!" "%url%/pvzHE/sync/!filename!" >nul
            echo 正在下载%url%/pvzHE/sync/!filename!
        )
    )
    set /a max = %i%
) else (
    set /a failCount+=1
)
if !failCount! geq !failThreshold! (
    goto endloop
)
set /a i+=1
goto loop
:endloop


IF NOT EXIST "%datapath%\users.dat" (
    echo 同步失败，正在撤销同步
    xcopy /Y "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata_old\%datestamp%\%timestamp%\" "C:\ProgramData\PopCap Games\PlantsVsZombies\pvzHE\yourdata\" >nul
    echo 已撤销同步，请检查云端存档并从历史记录中手动恢复数据
    pause
    exit
)

echo 进度已恢复
pause
endlocal

goto :endlog
::------------更新日志------------
0.3.1
    优化了云端的路径，修复云端路径异常的bug。
    修复了更新时无法自动继承旧配置的bug（尽管在更新前这个bug并没有触发的机会）
0.3.0
    改进了读取存档的方法，现在只需要配置一次账号即可使用两个脚本
    恢复范围增加了2.3新增的生存模式以及小游戏
0.2.0
    修复部分bug，脚本基本可用
0.1.0
    初次尝试撰写该脚本(用了一个通宵，写出了基本可用的脚本)
::-------------------------------
:endlog