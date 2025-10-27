@cls
@setlocal EnableExtensions
@echo Off
title Clean up temporary folders
set "_drv=%~d0"
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
pushd "%ROOT%"
Set "DISM=%ROOT%\DISM0\Dism.exe /English"
reg.exe query HKLM\mtSOFT 1>Nul 2>Nul && reg.exe unload HKLM\mtSOFT 1>Nul 2>Nul
reg.exe query HKLM\mtCOMP 1>Nul 2>Nul && reg.exe unload HKLM\mtCOMP 1>Nul 2>Nul
reg.exe query HKLM\mtSYS 1>Nul 2>Nul && reg.exe unload HKLM\mtSYS 1>Nul 2>Nul
for /d %%# in (log*) do (set "_log=%%#")
for /d %%# in (mnt*) do (set "MT=%%#")
for /d %%# in (sdir*) do (set "_scDir=%%#")
if not defined _log (mkdir log && set "_log=log")
if not defined _scDir (mkdir sdir && set "_scDir=sdir")
if defined MT (
%DISM% /LogPath:%_log%\clsa.log /LogLevel:2 /scratchdir:%_scDir% /Cleanup-Mountpoints
%DISM% /LogPath:%_log%\disc.log /LogLevel:2 /scratchdir:%_scDir% /unmount-wim /mountdir:%MT% /discard
%DISM% /LogPath:%_log%\clsb.log /LogLevel:2 /scratchdir:%_scDir% /Cleanup-Mountpoints
)
for /d %%# in (fsu* kb* lcu* log* lp* mnt* sdir* sxs* tmp*) do (rmdir /s /q "%%#\" 1>Nul 2>Nul)
del /f /q *.xml *.mun 1>Nul 2>Nul
echo:
echo:
echo  NOTE: If mnt* folder still exist, check registry hives. Unload all unusual hives.
echo:
Pause
(Goto) 2>Nul & Call "Bedi.cmd"
Exit
