@echo off
REM Pendrive: abre o kit da CAAAL usando os instaladores da pasta ao lado (sem baixar nada)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1"
