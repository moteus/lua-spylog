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

if "%TREE%" == "" (set TREE=%ROOT%\spylog-%LUA_VER%)

set LR=luarocks-%LUA_VER%

if "%LUA_VER%" == "5.1" (set UUID_VER=20120501) else (set UUID_VER=20120509)

::==================================================================
:: Custom rockspecs for build with MSVC
::==================================================================

call %LR% --tree %TREE% install %ROOT%\rockspecs\lua-cjson-2.1.0-1.rockspec
call %LR% --tree %TREE% install %ROOT%\rockspecs\luuid-%UUID_VER%-2.rockspec

::==================================================================
:: Not released yet
::==================================================================

:: install deps for LuaService by hand from main server
call %LR% --tree %TREE% install LuaSocket
call %LR% --tree %TREE% install LuaFileSystem
:: install LuaService form dev server
call %LR% --tree %TREE% install LuaService --server=http://luarocks.org/dev

:: install deps for lluv-esl by hand from main server
call %LR% --tree %TREE% install EventEmitter
call %LR% --tree %TREE% install lluv
call %LR% --tree %TREE% install LuaExpat
:: install lluv-esl form dev server
call %LR% --tree %TREE% install lluv-esl   --server=http://luarocks.org/dev

:: install openssl form dev server
call %LR% --tree %TREE% install openssl    --server=http://luarocks.org/dev

::==================================================================
:: install rest deps
::==================================================================

call %LR% --tree %TREE% --only-deps install %ROOT%\rockspecs\spylog-scm-0.rockspec