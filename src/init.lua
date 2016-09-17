-- Configuration file for LuaService

return {
  tracelevel = 7,
  name = "spylog",
  display_name = "SpyLog",
  script = "main.lua",
  lua_cpath = '!\\lib\\?.dll',
  lua_path = '!\\lib\\?.lua;!\\lib\\?\\init.lua;!\\action\\lib\\?.lua;!\\filter\\lib\\?.lua;!\\jail\\lib\\?.lua';
}
