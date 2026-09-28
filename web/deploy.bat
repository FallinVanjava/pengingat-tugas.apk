@echo off
title Deploy Landing Page ke Vercel
cd /d "%~dp0"
cls
echo =======================================================================
echo          DEPLOY WEBSITE PENGINGAT TUGAS KE VERCEL
echo =======================================================================
echo.
echo Langkah 1: Cek Login Vercel...
echo.
call npx --yes vercel whoami
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo -------------------------------------------------------------------
    echo  Anda belum login ke Vercel di terminal ini.
    echo  Sedang memulai proses login, silakan klik link / authorize di browser.
    echo  PENTING: Jangan tutup jendela ini sampai muncul tulisan "Success!"
    echo -------------------------------------------------------------------
    echo.
    call npx --yes vercel login
)

echo.
echo -------------------------------------------------------------------
echo Langkah 2: Mengunggah dan mem-publish website ke Vercel Production...
echo -------------------------------------------------------------------
echo.
call npx --yes vercel --prod --yes

echo.
echo =======================================================================
echo  DEPLOY SELESAI! Silakan buka URL website yang tertera di atas.
echo =======================================================================
echo.
pause
