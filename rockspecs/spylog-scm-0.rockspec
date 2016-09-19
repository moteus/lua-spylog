package="spylog"
version="scm-0"

-- for now this rockspec installs only dependencies but not spylog itself
source = {
  url = "https://github.com/moteus/lua-spylog/archive/master.zip",
  dir = "lua-spylog-master/src",
}

description = {
  summary = "Execute actions based on log recods",
  detailed = [[
    The main goal of this project is provide fail2ban functionality to Windows.
  ]],
  license = "MIT/X11",
  homepage = "https://github.com/moteus/lua-spylog"
}

dependencies = {
  "lua >= 5.1, <5.4",
  "bit32",
  "date",
  "lluv",
  "lluv-poll-zmq",
  "lpeg",
  "lrexlib-pcre",
  "lua-llthreads2",
  "lua-log > 0.1.5",
  "lua-path",
  "luafilesystem",
  "lzmq",
  "stacktraceplus",
  "lluv-ssl",
  "sendmail",
  "prefix_tree",
  "gntp",
  "sqlite3",

  -- need install before by hand
  "lua-cjson",          -- custom rockspec on windows/msvc
  "luuid",              -- custom rockspec on windows/msvc
  "luaservice",         -- not released yet
  "openssl",            -- not released yet
  "lluv-esl",           -- not released yet
}

build = {
  type = "builtin";
  modules = {};
}


