@echo off
setlocal
set "PIPELINE_DIR=%~dp0"
set "RSCRIPT=C:\Program Files\R\R-4.3.3\bin\Rscript.exe"
if not exist "%RSCRIPT%" set "RSCRIPT=Rscript.exe"
"%RSCRIPT%" --vanilla "%PIPELINE_DIR%access_public_data.R" %*
exit /b %ERRORLEVEL%
