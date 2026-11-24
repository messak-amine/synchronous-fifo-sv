@echo off
setlocal
cd /d "%~dp0" || exit /b 1
if not exist build mkdir build
if not exist build exit /b 1
iverilog -g2012 -Wall -s tb_sync_fifo -o build\tb_sync_fifo.vvp rtl\sync_fifo.v tb\tb_sync_fifo.sv
if errorlevel 1 exit /b 1
vvp build\tb_sync_fifo.vvp
exit /b %errorlevel%
