-- configure service
local SERVICE = require "LuaService"

-- BASE_DIR = SERVICE_PATH\..
local BASE_DIR = string.match(SERVICE.PATH, "^(.-)[\\/][^\\/]+$")

package.cpath  = BASE_DIR     .. '\\lib\\?.dll;'       ..  package.cpath
package.path   = BASE_DIR     .. '\\lib\\?.lua;'       ..  package.path

package.cpath  = SERVICE.PATH .. '\\lib\\?.dll;'       ..  package.cpath
package.path   = SERVICE.PATH .. '\\lib\\?\\init.lua;' ..  package.path
package.path   = SERVICE.PATH .. '\\lib\\?.lua;'       ..  package.path

return {CONFIG_DIR = BASE_DIR}
