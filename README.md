# Execute actions based on log recods

The main goal of this project is provide [fail2ban](http://www.fail2ban.org) functionality to Windows.

## Install/Start
The `lua-spylog` consist of three services.

 * filter - read logs from sources and extract date(optional) and IP and send them to `jail` service.
 * jail - read messages from `filter` service and support time couter. If some counter is reached to
  `maxretry` then jail send message to `action` service.
 * action - read messages from `jail` service and support queue of actions to be done. When it recv new
  message it push 2 new action to queue (ban and unban). Queue is persistent.

All services can be run as separate process or as thread in one multithreaded process.
To run spylog as Windows service you can use [LuaService](https://github.com/moteus/luaservice).
Also works with [nssm](http://nssm.cc) service helper.

## Configuration

### Detect auth fail on FreeSWITCH system
```Lua
-- config/sources/freeswitch.lua
SOURCE{"freeswitch",
  "esl:ClueCon@127.0.0.1:8021",
  level = 'WARNING';
}
```
```Lua
-- config/filters/freeswitch.lua
FILTER{ "freeswitch-auth-fail";
  enabled = true;
  source  = "freeswitch";
  failregex = {
    "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+) %[WARNING%] sofia_reg.c:%d+ SIP auth failure %([A-Z]+%) on sofia profile %'[^']+%' for %[.-%] from ip ([0-9.]+)%s*$";
    "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+) %[WARNING%] sofia.c:%d+ IP ([0-9.]+) Rejected by acl \"[^\"]*\"%s*$";
  }
};
```
```Lua
-- config/jails/freeswitch.lua
JAIL{"voip-auth-fail";
  enabled  = true;
  filter   = {"freeswitch-auth-fail"};
  findtime = 600;
  maxretry = 3;
  bantime  = 3600 * 24;
  action   = {"mail", "growl", "ipsec"};
}
```

## Dependencies
 - [bit32](https://luarocks.org/modules/siffiejoe/bit32)
 - [date](https://luarocks.org/modules/tieske/date)
 - [lluv](https://luarocks.org/modules/moteus/lluv)
 - [lluv-poll-zmq](https://luarocks.org/modules/moteus/lluv-poll-zmq)
 - [lpeg](https://luarocks.org/modules/gvvaughan/lpeg)
 - [Lrexlib-PCRE](https://luarocks.org/modules/rrt/lrexlib-pcre)
 - [lua-cjson](https://luarocks.org/modules/luarocks/lua-cjson)
 - [lua-llthreads2](https://luarocks.org/modules/moteus/lua-llthreads2)
 - [lua-log](https://luarocks.org/modules/moteus/lua-log)
 - [lua-path](https://luarocks.org/modules/moteus/lua-path)
 - [Lua-Sqlite3](https://luarocks.org/modules/moteus/sqlite3)
 - [LuaFileSystem](https://luarocks.org/modules/hisham/luafilesystem)
 - [luuid](https://luarocks.org/modules/luarocks/luuid)
 - [lzmq](https://luarocks.org/modules/moteus/lzmq)
 - [StackTracePlus](https://luarocks.org/modules/ignacio/stacktraceplus)

### To support `mail` action
 - [lluv-ssl](https://luarocks.org/modules/moteus/lluv-ssl)
 - [sendmail](https://luarocks.org/modules/moteus/sendmail)

### To support `growl` action
 - [gntp](https://luarocks.org/modules/moteus/gntp)
 - [openssl](https://luarocks.org/modules/zhaozg/openssl)

### To support `esl` source type
 - [lluv-esl](https://luarocks.org/modules/moteus/lluv-esl)
