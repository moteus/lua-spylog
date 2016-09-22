local log        = require "spylog.log"
local ut         = require "lluv.utils"
local BaseFilter = require "spylog.filter.base"
local config     = require "spylog.config"
local ptree      = require "prefix_tree"
local path       = require "path"

local PrefixFilter = ut.class(BaseFilter) do

function PrefixFilter:__init(filter)
  local prefixes = assert(filter.prefix, 'capture filter with type `prefix` has no prefix list')

  filter.value = filter.value or 'number'
  self.__base.__init(self, filter)

  local tree

  -- load prefixes
  if type(prefixes) == 'table' then
    tree = ptree.new()
    if prefixes[1] then -- load from array
      for _, prefix in ipairs(prefixes) do
        tree:add(prefix, '')
      end
    else -- load from map
      for prefix, value in pairs(prefixes) do
        tree:add(prefix, value)
      end
    end
  else -- load from file
    local base_prefix_dir = path.join(config.CONFIG_DIR, 'config', 'jails')
    local full_path = path.fullpath(path.isfullpath(prefixes) or path.join(base_prefix_dir, prefixes))
    log.debug('full path for prefix: %s', full_path)
    if not path.isfile(full_path) then
      return nil, string.format('can not find prefix file %s', full_path)
    end
    tree = ptree.LoadPrefixFromFile(full_path)
  end

  self._tree = tree

  return self
end

function PrefixFilter:apply(capture)
  local value = self:value(capture)

  if value and self._tree:find(value) then
    return self._allow
  end

  return not self._allow
end

end

return PrefixFilter