::=========================================================
:: Basic way to manage IPSec SpyLog filters
:: Install/Uninstall default policy and filters
:: Create/Assign filters to policy
:: Clean all host in filter
:: Add/Remove host to specific filter
:: List of IP for specific filter
::=========================================================

@echo off && setlocal

set DummyIP=192.168.251.136
set SpyLogActionName=SpyLogBlock
set SpyLogPolicyName=SpyLogBlock
set SpyLogFilterName=SpyLogBlock

if "%1"=="" goto :usage
if "%1"=="-help" goto :usage

if not "%1"=="install" if not "%1"=="uninstall" if not "%1"=="filter" if not "%1"=="host" (
  echo ERROR: Unknown action/object: %1
  goto :usage
)

:: what need to do (install, uninstall, filter, host)
SET object=%1
SET policy=
SET filter=
SET host=
SET port=
SET protocol=
SET mask=
SET skip_policy=false
SET skip_filter=false
SHIFT

if "%object%" == "filter"    goto :filter_args
if "%object%" == "host"      goto :filter_ip_args

::---------------------------------------------------------
:: decode args for install/uninstall
::---------------------------------------------------------
:install_args
IF NOT "%1"=="" (
  IF "%1"=="-policy" (
    SET policy=%2
    SHIFT && SHIFT
    GOTO :install_args
  )
  IF "%1"=="-filter" (
    SET filter=%2
    SHIFT && SHIFT
    GOTO :install_args
  )
  IF "%1"=="-skip-policy" (
    SET skip_policy=true
    SHIFT
    GOTO :install_args
  )
  IF "%1"=="-skip-filter" (
    SET skip_filter=true
    SHIFT
    GOTO :install_args
  )
  echo ERROR: Unknown key for %object% command: %1
  goto :usage
)

if "%object%" == "install"       goto :install
if "%object%" == "uninstall"     goto :uninstall

::---------------------------------------------------------
:: decode args for manage filter
::---------------------------------------------------------
:filter_args
if not "%1"=="add" if not "%1"=="remove" if not "%1"=="list" if not "%1"=="clean" (
  echo ERROR: Unknown action for filter object: %1
  goto :usage
)
SET action=%1
SHIFT

SET filter=%1
if "%filter:~0,1%"=="-" (
  SET filter=
)
if not "%filter%"=="" (
  SHIFT
)

:filter_args_loop
IF NOT "%1"=="" (
  IF "%1"=="-policy" (
    SET policy=%2
    SHIFT && SHIFT
    GOTO :filter_args_loop
  )
  IF "%1"=="-filter" (
    SET filter=%2
    SHIFT && SHIFT
    GOTO :filter_args_loop
  )
  echo ERROR: Unknown key for filter command: %1
  goto :usage
)

if "%action%" == "add"    goto :add_filter
if "%action%" == "remove" goto :remove_filter
if "%action%" == "list"   goto :list_filter
if "%action%" == "clean"  goto :clean_filter

::---------------------------------------------------------
:: decode args for add/remove ip to filter
::---------------------------------------------------------
:filter_ip_args
if not "%1"=="add" if not "%1"=="remove" (
  echo ERROR: Unknown action for host object: %1
  goto :usage
)
SET action=%1
SHIFT

SET host=%1
if "%host:~0,1%"=="-" (
  SET host=
)
if not "%host%"=="" (
  SHIFT
)


:filter_ip_args_loop
IF NOT "%1"=="" (
  IF "%1"=="-host" (
    SET host=%2
    SHIFT && SHIFT
    GOTO :filter_ip_args_loop
  )
  IF "%1"=="-filter" (
    SET filter=%2
    SHIFT && SHIFT
    GOTO :filter_ip_args_loop
  )
  IF "%1"=="-protocol" (
    SET protocol=%2
    SHIFT && SHIFT
    GOTO :filter_ip_args_loop
  )
  IF "%1"=="-port" (
    SET port=%2
    SHIFT && SHIFT
    GOTO :filter_ip_args_loop
  )
  IF "%1"=="-mask" (
    SET mask=%2
    SHIFT && SHIFT
    GOTO :filter_ip_args_loop
  )
  echo ERROR: Unknown key for host command: %1
  goto :usage
)

:: if you whant use port then you have to define protocol
if not "%port%"=="" if "%protocol%"=="" (
  echo ERROR: no protocol, but port defined
  goto :usage
)

:: if you define protocol you can set port to `0` that means any
if "%port%"=="" if not "%protocol%"=="" (
  SET port=0
)

:: only this host
if "%mask%"=="" (
  SET mask=32
)

if "%action%" == "add"      goto :add_filter_ip
if "%action%" == "remove"   goto :remove_filter_ip

:usage
echo ipsecspylog install^|uninstall [-skip-policy] [-skip-filter]
echo ipsecspylog filter add^|remove [[-filter] ^<filter^>] [-policy ^<policy^>]
echo ipsecspylog filter list^|clean [[-filter] ^<filter^>]
echo ipsecspylog host add^|remove [[-host] ^<host^>] [-mask ^<net^|mask^>] [-protocol ^<protocol^> [-port ^<port^>]] [-filter ^<filter^>]

goto :eof

:install
call:CreateAction
if "%skip_policy%" == "false" call:CreatePolicy %policy%
if "%skip_policy%" == "false" if "%skip_filter%" == "false" call:CreateFilter %filter% %policy%

goto :eof

:uninstall
if "%skip_policy%" == "false" call:RemovePolicy %policy%
if "%skip_filter%" == "false" call:RemoveFilter %filter% %policy%
call:RemoveAction

goto :eof

:add_filter
call:CreateFilter %filter% %policy%

goto :eof

:remove_filter
call:RemoveFilter %filter% %policy%

goto :eof

:clean_filter
call:RemoveFilter %filter% %policy%
call:CreateFilter %filter% %policy%

goto :eof

:list_filter
call:ListFilter %filter%

goto :eof

:add_filter_ip
if "%port%"=="" (
  call:AddFilterIP %host% %mask% %filter%
)
if not "%port%"=="" (
  call:AddFilterIPPort %host% %mask% %protocol% %port% %filter%
)

goto :eof

:remove_filter_ip
if "%port%"=="" (
  call:RemoveFilterIP %host% %mask% %filter%
)
if not "%port%"=="" (
  call:RemoveFilterIPPort %host% %mask% %protocol% %port% %filter%
)

goto :eof

endlocal


:CreateAction
setlocal
  set name=%~1
  set action=%~2
  if "%name%" == "" set name=%SpyLogActionName%
  if "%action%" == "" set action=block
  netsh ipsec static add filteraction name=%name% action=%action%
endlocal
goto :eof


:RemoveAction
setlocal
  set name=%~1
  if "%name%" == "" set name=%SpyLogActionName%
  netsh ipsec static delete filteraction name=%name%
endlocal
goto :eof


:CreatePolicy
setlocal
  set policy=%~1
  if "%policy%" == "" set policy=%SpyLogPolicyName%
  netsh ipsec static add policy name=%policy% assign=yes activatedefaultrule=no
endlocal
goto :eof


:RemovePolicy
setlocal
  set policy=%~1
  if "%policy%" == "" set policy=%SpyLogPolicyName%
  netsh ipsec static delete policy name=%policy%
endlocal
goto :eof


:CreateFilter
setlocal
  set filter=%~1
  set policy=%~2
  set action=%~3
  if "%filter%" == "" set filter=%SpyLogFilterName%
  if "%policy%" == "" set policy=%SpyLogPolicyName%
  if "%action%" == "" set action=%SpyLogActionName%

  set rule=%policy%-%filter%

  netsh ipsec static add filter filterlist=%filter% srcaddr=%DummyIP% dstaddr=me
  netsh ipsec static add rule name=%rule% policy=%policy% filterlist=%filter% filteraction=%action%
  netsh ipsec static delete filter filterlist=%filter% srcaddr=%DummyIP% dstaddr=Me
endlocal
goto :eof


:RemoveFilter
setlocal
  set filter=%~1
  set policy=%~2
  if "%filter%" == "" set filter=%SpyLogFilterName%
  if "%policy%" == "" set policy=%SpyLogPolicyName%

  set rule=%policy%-%filter%

  netsh ipsec static delete rule name=%rule% policy=%policy%
  netsh ipsec static delete filterlist name=%filter%
endlocal
goto :eof


:ListFilter
setlocal
  set filter=%~1
  if "%filter%" == "" set filter=%SpyLogFilterName%

  netsh ipsec static show filterlist %filter% level=verbose format=table
endlocal
goto :eof


:AddFilterIP
setlocal
  set host=%~1
  set mask=%~2
  set filter=%~3
  if "%filter%" == "" set filter=%SpyLogFilterName%

  netsh ipsec static add filter filterlist=%filter% srcaddr=%host% srcmask=%mask% dstaddr=me
endlocal
goto :eof

:AddFilterIPPort
setlocal
  set host=%~1
  set mask=%~2
  set protocol=%~3
  set port=%~4
  set filter=%~5
  if "%filter%" == "" set filter=%SpyLogFilterName%

  netsh ipsec static add filter filterlist=%filter% srcaddr=%host% srcmask=%mask% protocol=%protocol% dstport=%port% dstaddr=me
endlocal
goto :eof

:RemoveFilterIP
setlocal
  set host=%~1
  set mask=%~2
  set filter=%~3
  if "%filter%" == "" set filter=%SpyLogFilterName%

  netsh ipsec static delete filter filterlist=%filter% srcaddr=%host% srcmask=%mask% dstaddr=me
endlocal
goto :eof

:RemoveFilterIPPort
setlocal
  set host=%~1
  set mask=%~2
  set protocol=%~3
  set port=%~4
  set filter=%~5
  if "%filter%" == "" set filter=%SpyLogFilterName%

  netsh ipsec static add filter filterlist=%filter% srcaddr=%host% srcmask=%mask% protocol=%protocol% dstport=%port% dstaddr=me
endlocal
goto :eof
