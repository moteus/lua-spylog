# Execute actions based on log records

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

### Supported sources
 * Text log file
 * SysLog UDP server (rfc3164 and rfc5424)
 * SNMP trap UDP server (allows handle Windows event logs)
 * EventLog (based on event trap) allows additional filters based on source names.
 * FreeSWITCH ESL TCP connection
 * TCP raw connection

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

#### Jail control value
Each jail support counter for some value. By default it is `host`.
But in some case it may be need support counter for some other value.
E.g. in voip system it may be need monitor each account. To specify
this value uses `banwhat` field. (`banwhat = 'user'`)

#### Counter types
Currently supports this counter types

 * `incremental` increment to one for each filter message
 * `accumulate` get increment value from filter message.
   Can be used e.g. to calculate total calls duration in some VOIP system.
 * `fixed` just return value from filter.

By default `increment` type uses.

```Lua
JAIL{
  ...
  counter  = {
    type  = 'accumulate';
    value = 'duration'; -- what value use to increment.
  };
}
```

#### Jail capture filters
It is also possible add some additional filter to jails.
E.g. we want count only attempt to call to some area codes.
We can not do this on filter side because we can handle same
log line with different jails. Each capture filter should have
name as first element. Currently support `prefix`, `acl`, `regex`
and `list` filters. 
`prefix` filter should hanve `prefix` field with array of prefixes
of file name. 
`acl` filter should have `cidr` field with array of IP and/or CIDR.
`regex` filter should have `regex` string/array of strings.
`list` filter should have `list` array of strings.

```Lua
JAIL{
  -- count only calls to Cuba and Albania and exclude '192.168.123.22' host
  cfilter = {
    {'prefix',          -- filter type
      type  = 'allow',  -- count if match
      value = 'number', -- capture name to filter
      prefix = {
        '53',  -- Cuba 
        '355', -- Albania
      }
    };

    {'acl',            -- filter type
      type  = 'deny',  -- count if not match
      value = 'host',  -- capture name to filter
      cidr = {
        '192.168.123.22',
      }
    };
  }
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

### To support `prefix` filter for jails
 - [prefix_tree](https://luarocks.org/modules/moteus/prefix_tree)
