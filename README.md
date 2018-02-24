# SpyLog

## Execute actions based on log records

[![SpyLog-x86-0.0.2.exe](https://img.shields.io/badge/0.0.2-x86-blue.svg)](https://github.com/moteus/lua-spylog/releases/download/v0.0.2/SpyLog-x86-0.0.2.exe)
[![SpyLog-x64-0.0.2.exe](https://img.shields.io/badge/0.0.2-x64-blue.svg)](https://github.com/moteus/lua-spylog/releases/download/v0.0.2/SpyLog-x64-0.0.2.exe)

-----------------------------------------------------------

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

For Windows there exists installer which allows install SpyLog and all dependencies. You can download
it form [Releases](https://github.com/moteus/lua-spylog/releases) page.

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

### Supported sources
 * Text log file
 * UDP raw server
 * SysLog UDP server (rfc3164 and rfc5424)
 * SNMP trap UDP server (allows handle Windows event logs)
 * EventLog (based on event trap) allows additional filters based on source names.
 * FreeSWITCH ESL TCP connection
 * TCP raw connection
 * Process stdout and/or stderr

### Filters

#### Named captures
By default filter names first capure as `date` and second one as `host`.
If there only one capture then `date` set as current timestamp and capture names as `host`.
It is possible to assign names to captures using `capture` array.
```Lua
FILTER{'nginx-404',
  capture = {'host', 'date'}; -- we have to swap `date` and `host`
  failregex = '^([0-9.]+) %- %- %[(.-)%].-GET.-HTTP.- 404';
}
```
Also it possible add any other captures. They will be send to jails as whell.

#### Ignore regex
Filters support `ignoreregex` field to exclude records which already matched by `failregex`

#### Exclude IP
Filters support `exclude` array which allows exclude some IP and networks.

### Jails
Each jail is just array of counters with some expire time.

#### Counter types
Currently supports this counter types

 * `incremental` increment to one for each filter message
 * `accumulate` get increment value from filter message.
   Can be used e.g. to calculate total calls duration in some VOIP system.
 * `fixed` just return value from filter message.
   Can be used e.g. to monitor max call duration for calls in some VOIP system.

By default `increment` type uses.

#### Counter control values
Each counter do count for some value (like `counter[id] = counter[id] + value`).
To specify `id` field you can use `capture` field. By default it is `host`.
To specify `value` you can use `value` field. There no default value for this.
E.g. in voip system it may be need monitor each account and block them .

```Lua
JAIL{
  ...
  counter  = {
    type    = 'accumulate';
    capture = 'account'; -- count total duration for each account
    value   = 'duration'; -- what value use to increment.
  };
}
```

#### Capture filters
It is also possible add some additional filter to `filters` and `jails`.

Example 1. Add `black` list for user names for RDP service.
```Lua
JAIL{"rdp-bad-user-access"; -- e.g. can ban after first attempt
  -- apply this jail only for specific user list
  cfilter  = {"list",
    type    = "allow",
    capture = "user",
    nocase  = true,
    filter  = { "admin", "guest", "user", "root"};
  };
}
```

Example 2. Counts attempts to call only to some specific area codes.
```Lua
JAIL{
  -- count only calls to Cuba and Albania and exclude '192.168.123.22' host
  cfilter = {
    {'prefix',            -- filter type
      type    = 'allow',  -- count if match
      capture = 'number', -- capture name to filter
      filter = {          -- filter rules
        '53',  -- Cuba 
        '355', -- Albania
      }
    };

    {'acl',              -- filter type
      type    = 'deny',  -- count if not match
      capture = 'host',  -- capture name to filter
      filter  = {        -- filter rules
        '192.168.123.22',
      }
    };
  }
}
```

Example 3. Apply jail to some countries only.
```Lua
JAIL{"rdp-bad-country-access"; -- e.g. can ban after first attempt
  -- apply this jail for all counties except Russia and North America
  cfilter  = {"geoip",
    type    = "deny",
    filter  = { 'ru', continent = {'na'} };
  };
}
```

Each capture filter should have name as first element, `capture` and `filter` fields.
Currently support `prefix`, `acl`, `regex`, `list` and `geoip` filters.
`capture` field specify what value from capture should be used in this fileter.
`filter` is set of rules had specific format for each type of filter.
`prefix` filter should have `filter` field as array of prefixes of file name.
`acl` filter should have `filter` field as array of IP and/or CIDR.
`regex` filter should have `filter` field as string/array of strings.
`list` filter should have `list` field as string/array of strings.


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
 - [LuaService](https://luarocks.org/modules/moteus/luaservice)
 - [environ](https://luarocks.org/modules/moteus/environ)

### To support `mail` action
 - [lluv-ssl](https://luarocks.org/modules/moteus/lluv-ssl)
 - [sendmail](https://luarocks.org/modules/moteus/sendmail)
 - [try](https://luarocks.org/modules/moteus/try)

### To support `growl` action
 - [gntp](https://luarocks.org/modules/moteus/gntp)
 - [openssl](https://luarocks.org/modules/zhaozg/openssl)

### To support `esl` source type
 - [lluv-esl](https://luarocks.org/modules/moteus/lluv-esl)

### To support `prefix` capture filter
 - [prefix_tree](https://luarocks.org/modules/moteus/prefix_tree)

### To support `geoip` capture filter
 - [mmdblua](https://luarocks.org/modules/daurnimator/mmdblua)
 - [compat53](https://luarocks.org/modules/siffiejoe/compat53)
 - [lua-lru](https://luarocks.org/modules/starius/lua-lru) (optional)
