@echo off
setlocal
cd /d "%~dp0" || exit /b 1

if "%~1"=="" goto sim
if /i "%~1"=="sim" goto sim
if /i "%~1"=="synth" goto synth
if /i "%~1"=="lint" goto lint
if /i "%~1"=="clean" goto clean
echo Usage: %~nx0 [sim^|synth^|lint^|clean] >&2
exit /b 1

:sim
if not exist build\ mkdir build
if not exist build\ exit /b 1
call iverilog -g2012 -Wall -s tb_sync_fifo -o build\tb_sync_fifo.vvp rtl\sync_fifo.v tb\tb_sync_fifo.sv
if errorlevel 1 exit /b %errorlevel%
call vvp build\tb_sync_fifo.vvp
exit /b %errorlevel%

:synth
call yosys -p "read_verilog rtl/sync_fifo.v; synth -top sync_fifo -noabc; select -assert-none t:$_DLATCH_*; check -assert"
exit /b %errorlevel%

:lint
rem The native executable needs the suite's Verilator support files.
if not defined VERILATOR_ROOT if defined YOSYSHQ_ROOT set "VERILATOR_ROOT=%YOSYSHQ_ROOT%\share\verilator"
verilator_bin.exe --lint-only -Wall --top-module sync_fifo rtl\sync_fifo.v
exit /b %errorlevel%

:clean
if not exist build\ exit /b 0
rmdir /s /q build
exit /b %errorlevel%
