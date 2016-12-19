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

if not "%1"=="install" if not "%1"=="uninstall" (
if not "%1"=="add-filter" if not "%1"=="remove-filter" if not "%1"=="list-filter" if not "%1"=="clean-filter" (
if not "%1"=="add-host" if not "%1"=="remove-host" (
goto :usage
)))

:: what need to do (install, uninstall, add-filter, remove-filter)
SET action=%1
SET policy=
SET filter=
SET host=
SET skip_policy=false
SET skip_filter=false
SHIFT

if "%action%" == "add-filter"    goto :filter_args
if "%action%" == "remove-filter" goto :filter_args
if "%action%" == "list-filter"   goto :filter_args
if "%action%" == "clean-filter"  goto :filter_args

if "%action%" == "add-host"      goto :filter_ip_args
if "%action%" == "remove-host"   goto :filter_ip_args

::---------------------------------------------------------
:: decode args for install
::---------------------------------------------------------
:install_args
IF NOT "%1"=="" (
  IF "%1"=="-policy" (
    SET policy=%2
    SHIFT
  )
  IF "%1"=="-filter" (
    SET filter=%2
    SHIFT
  )
  IF "%1"=="-skip-policy" (
    SET skip_policy=true
  )
  IF "%1"=="-skip-filter" (
    SET skip_filter=true
  )
  SHIFT
  GOTO :install_args
)

if "%action%" == "install"       goto :install
if "%action%" == "uninstall"     goto :uninstall

::---------------------------------------------------------
:: decode args for add/remove filter
::---------------------------------------------------------
:filter_args
SET filter=%1
if "%filter:~0,1%"=="-" (
  SET filter=
)

:filter_args_loop
IF NOT "%1"=="" (
  IF "%1"=="-policy" (
    SET policy=%2
    SHIFT
  )
  IF "%1"=="-filter" (
    SET filter=%2
    SHIFT
  )
  SHIFT
  GOTO :filter_args_loop
)

if "%action%" == "add-filter"    goto :add_filter
if "%action%" == "remove-filter" goto :remove_filter
if "%action%" == "list-filter"   goto :list_filter
if "%action%" == "clean-filter"  goto :clean_filter

::---------------------------------------------------------
:: decode args for add/remove ip to filter
::---------------------------------------------------------
:filter_ip_args
SET host=%1
if "%filter:~0,1%"=="-" (
  SET host=
)

:filter_ip_args_loop
IF NOT "%1"=="" (
  IF "%1"=="-host" (
    SET host=%2
    SHIFT
  )
  IF "%1"=="-filter" (
    SET filter=%2
    SHIFT
  )
  SHIFT
  GOTO :filter_ip_args_loop
)

if "%action%" == "add-host"      goto :add_filter_ip
if "%action%" == "remove-host"   goto :remove_filter_ip

:usage
echo ipsecspylog install^|uninstall [-skip-policy] [-skip-filter]
echo ipsecspylog add-filter^|remove-filter [[-filter] ^<filter^>] [-policy ^<policy^>]
echo ipsecspylog list-filter^|clean-filter [[-filter] ^<filter^>]
echo ipsecspylog add-host^|remove-host [[-host] ^<host^>] [-filter ^<filter^>]

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
call:AddFilterIP %host% %filter%

goto :eof

:remove_filter_ip
call:RemoveFilterIP %host% %filter%

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
  set filter=%~2
  if "%filter%" == "" set filter=%SpyLogFilterName%

  netsh ipsec static add filter filterlist=%filter% srcaddr=%host% srcmask=32 dstaddr=me
endlocal
goto :eof


:RemoveFilterIP
setlocal
  set host=%~1
  set filter=%~2
  if "%filter%" == "" set filter=%SpyLogFilterName%

  netsh ipsec static delete filter filterlist=%filter% srcaddr=%host% srcmask=32 dstaddr=me
endlocal
goto :eof
