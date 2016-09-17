-- Configuration file for LuaService

return {
  tracelevel = 7,
  name = "spylog_filter",
  display_name = "SpyLog - Filter",
  script = "main.lua",
  lua_cpath = '!\\lib\\?.dll;!\\..\\lib\\?.dll;',
  lua_path = '!\\lib\\?.lua;!\\lib\\?\\init.lua;!\\..\\lib\\?.lua;!\\..\\lib\\?\\init.lua';
}
