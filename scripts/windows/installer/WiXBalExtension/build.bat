@echo off

rem Configuring environment
rem set MSBUILD="%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\msbuild.exe"
call "%VS140COMNTOOLS%\..\..\vc\vcvarsall.bat"

set outdir=%~dp0build

rem Removing release folder
Call :DeleteDir "%outdir%"
Call :DeleteDir "ipch"

msbuild.exe inc\Version.proj /nologo /verbosity:quiet
msbuild.exe BalExtensionExt.sln /nologo /verbosity:quiet /t:Rebuild /p:Configuration=Release /p:Platform="Mixed Platforms" /p:RunCodeAnalysis=false /p:DefineConstants="TRACE" /p:OutDir="%outdir%\\" /l:FileLogger,Microsoft.Build.Engine;logfile=build.log
if %errorlevel% neq 0 (
	echo Build failed
	rem pause
	goto :EOF
)


set outdir=

goto :EOF

REM *****************************************************************
REM End of Main
REM *****************************************************************


REM *****************************************************************
REM Delete/create directory
REM *****************************************************************
:DeleteDir
rd %1% /q/s 2>nul 1>nul
goto :EOF
