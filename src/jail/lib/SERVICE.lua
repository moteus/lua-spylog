-------------------------------------------------------------------------------
local SERVICE do -- SERVICE module

local service = service

local function remove_dir_end(str)
  while(str ~= '')do
    local ch = str:sub(-1)
    if ch == '\\' or ch == '/' then 
      str = str:sub(1,-2)
    else break end
  end
  return str
end

local lsrv = {
  RUN_AS_SERVICE = (service ~= nil);
  print = service and service.print or print;
  name  = service and service.name or "LuaService console"
}

function lsrv.exit(code)
  -- To enforce stop service 
  if service and (not service.stopping()) then
    os.exit(code)
  end
end

-- call %LUA_INIT%
if lsrv.RUN_AS_SERVICE then
  -------------------------------------------------------------------------------
  local LUA_INIT = "LUA_INIT" do

  local lua_version_t
  local function lua_version()
    if not lua_version_t then 
      local version = assert(_VERSION)
      local maj,min = version:match("^Lua (%d+)%.(%d+)$")
      if maj then                         lua_version_t = {tonumber(maj),tonumber(min)}
      elseif not math.mod then            lua_version_t = {5,2}
      elseif table.pack and not pack then lua_version_t = {5,2}
      else                                lua_version_t = {5,2} end
    end
    return lua_version_t[1], lua_version_t[2]
  end

  local LUA_MAJOR, LUA_MINOR = lua_version()
  local IS_LUA_51 = (LUA_MAJOR == 5) and (LUA_MINOR == 1)

  local LUA_INIT_VER
  if not IS_LUA_51 then
    LUA_INIT_VER = LUA_INIT .. "_" .. LUA_MAJOR .. "_" .. LUA_MINOR
  end

  LUA_INIT = LUA_INIT_VER and os.getenv( LUA_INIT_VER ) or os.getenv( LUA_INIT ) or ""

  end
  -------------------------------------------------------------------------------

  -------------------------------------------------------------------------------
  local load_src do

  local loadstring = loadstring or load
  local unpack     = table.unpack or unpack

  function load_src(str)
    local f, n
    if str:sub(1,1) == '@' then
      n = str:sub(2)
      f = assert(loadfile(n))
    else
      n = '=(loadstring)'
      f = assert(loadstring(str))
    end
    return f, n
  end

  end
  -------------------------------------------------------------------------------

  local ok, err = pcall(function()
    if LUA_INIT and #LUA_INIT > 0 then
      local init = load_src(LUA_INIT)
      init()
    end
  end)

  if not ok then
    lsrv.print("Can not init Lua " .. err);
    return lsrv.exit(-1)
  end
end

-------------------------------------------------------------------------------
-- Set current work dir
local ok, err = pcall(function() 
  if lsrv.RUN_AS_SERVICE then
    lsrv.PATH  = remove_dir_end(service.path)
    if service.SetCurrentDirectory then
      service.SetCurrentDirectory(lsrv.PATH)
    end
  else
    local lfs  = require "lfs"
    lsrv.PATH  = remove_dir_end(lfs.currentdir())
    lfs.chdir(lsrv.PATH)
  end
end)

if not ok then
  lsrv.print("Can not set current work directory " .. err);
  return lsrv.exit(-1)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Set sleep function
local ok, err = pcall(function() 
  if lsrv.RUN_AS_SERVICE then
    lsrv.sleep = service.sleep
  else
    local function prequire(mod)
      local ok, err = pcall(require, mod)
      if not ok then return nil, err end
      return err, mod
    end

    repeat
      local m
      m = prequire "socket"
      if m then lsrv.sleep = function(s) m.sleep(s/1000) end; break; end
      m = prequire "lzmq.timer"
      if m then lsrv.sleep = m.sleep; break; end
    until true

    assert(lsrv.sleep)
  end
end)

if not ok then
  lsrv.print("Can not set sleep function " .. err);
  return lsrv.exit(-1)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Implement basic main loop
do

lsrv.STOP_FLAG = false

function lsrv.check_stop(stime, scount)
  if stime == 0 then
    scount = 1
  end

  stime  = stime  or lsrv.stime  or 1000
  scount = scount or lsrv.scount or 1

  for i = 1, scount do
    if lsrv.STOP_FLAG or (service and service.stopping()) then 
      lsrv.STOP_FLAG = true
      return lsrv.STOP_FLAG
    end
    if stime > 0 then
      lsrv.sleep(stime)
    end
  end

  return false
end

function lsrv.stop()
  lsrv.STOP_FLAG = true
end

function lsrv.run(main, stime, scount)
  stime  = lsrv.stime  or stime  or 5000
  scount = lsrv.scount or scount or 10*2
  while true do
    if lsrv.check_stop(stime, scount) then
      break
    end
    main()
  end
end

end
-------------------------------------------------------------------------------

SERVICE = lsrv

end
-------------------------------------------------------------------------------
local BASE_DIR = string.match(SERVICE.PATH, "^(.-)[\\/][^\\/]+$")
SERVICE.CONFIG_DIR = BASE_DIR
package.path   = BASE_DIR     .. '\\lib\\?.lua;'       ..  package.path
package.cpath  = SERVICE.PATH .. '\\lib\\?.dll;'       ..  package.cpath
package.path   = SERVICE.PATH .. '\\lib\\?\\init.lua;' ..  package.path
package.path   = SERVICE.PATH .. '\\lib\\?.lua;'       ..  package.path
-------------------------------------------------------------------------------

return SERVICE