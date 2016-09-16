-- configure service
local SERVICE = require "LuaService"

-------------------------------------------------------------------------------
package.cpath  = SERVICE.PATH .. '\\lib\\?.dll;'         ..  package.cpath
package.path   = SERVICE.PATH .. '\\lib\\?.lua;'         ..  package.path
package.path   = SERVICE.PATH .. '\\action\\lib\\?.lua;' ..  package.path
package.path   = SERVICE.PATH .. '\\filter\\lib\\?.lua;' ..  package.path
package.path   = SERVICE.PATH .. '\\jail\\lib\\?.lua;'   ..  package.path
-------------------------------------------------------------------------------

return {CONFIG_DIR = SERVICE.PATH}
