-- configure service
local SERVICE = require "LuaService"

-- BASE_DIR = SERVICE_PATH\..
local BASE_DIR = string.match(SERVICE.PATH, "^(.-)[\\/][^\\/]+$")

return {CONFIG_DIR = BASE_DIR}
