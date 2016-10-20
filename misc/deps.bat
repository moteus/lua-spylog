::==================================================================
::
:: Install all dependencies on Windows using LuaRocks
:: It requires that you already have all external deps
:: (like libzmq, libuv etc.) installed in your system
:: and LuaRocks can use them to install Lua modules.
::
:: Tested with https://github.com/moteus/lua-windows-environment
::
:: > luaenv x86 5.1 && deps 5.1
:: > luaenv x86 5.2 && deps 5.2
:: > luaenv x86 5.3 && deps 5.3
::
::==================================================================

@echo off && setlocal

set LUA_VER=%1
set TREE=%2
set ROOT=

if exist ..\README.md if exist ..\src set ROOT=..

if exist .\README.md if exist .\src set ROOT=.

if "%ROOT%" == "" (
  echo Please run this file from project root directory
  EXIT /B 1
)

if "%LUA_VER%" == "" (set LUA_VER=5.1)

if "%TREE%" == "" (set TREE=spylog-%LUA_VER%)

set LR=luarocks-%LUA_VER%

if "%LUA_VER%" == "5.1" (set UUID_VER=20120501) else (set UUID_VER=20120509)

::==================================================================
:: Custom rockspecs for build with MSVC
::==================================================================

call %LR% show lua-cjson --tree %TREE% || call %LR% --tree %TREE% install %ROOT%\rockspecs\lua-cjson-2.1.0-1.rockspec
call %LR% show luuid     --tree %TREE% || call %LR% --tree %TREE% install %ROOT%\rockspecs\luuid-%UUID_VER%-2.rockspec

::==================================================================
:: Not released yet
::==================================================================

:: install deps for LuaService by hand from main server
call %LR% show luasocket     --tree %TREE% || call %LR% --tree %TREE% install luasocket
call %LR% show luafilesystem --tree %TREE% || call %LR% --tree %TREE% install luafilesystem
:: install LuaService form dev server
call %LR% show luaservice    --tree %TREE% || call %LR% --tree %TREE% install luaservice --server=http://luarocks.org/dev

:: install deps for lluv-esl by hand from main server
call %LR% show eventemitter --tree %TREE% || call %LR% --tree %TREE% install eventemitter
call %LR% show lluv         --tree %TREE% || call %LR% --tree %TREE% install lluv
call %LR% show luaexpat     --tree %TREE% || call %LR% --tree %TREE% install luaexpat
:: install lluv-esl form dev server
call %LR% show lluv-esl     --tree %TREE% || call %LR% --tree %TREE% install lluv-esl   --server=http://luarocks.org/dev

:: install openssl form dev server
call %LR% show openssl      --tree %TREE% || call %LR% --tree %TREE% install openssl    --server=http://luarocks.org/dev

::==================================================================
:: install rest deps
::==================================================================

call %LR% --tree %TREE% --only-deps install %ROOT%\rockspecs\spylog-scm-0.rockspec