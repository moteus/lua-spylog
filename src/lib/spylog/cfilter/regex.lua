local ut         = require "lluv.utils"
local BaseFilter = require "spylog.cfilter.base"

local ENGINES = {
  default = function(list)
    local regex = {} for i = 1, #list do
      assert(type(list[i]) == 'string')
      regex[i] = list[i]
    end

    return function(s)
      for i = 1, #regex do
        if string.find(s, regex[i]) then
          return true
        end
      end
    end
  end;

  pcre = function(list)
    local rex = require "rex_pcre"

    local regex = {} for i = 1, #list do
      regex[i] = assert(rex.new(list[i]))
    end

    return function(s)
      for i = 1, #regex do
        if regex[i]:find(s) then
          return true
        end
      end
    end
  end;
}

local RegexFilter = ut.class(BaseFilter) do

function RegexFilter:__init(filter)
  if type(filter.filter) == 'string' then
    filter.filter = {filter.filter}
  end
  local regexes = filter.filter

  assert(type(regexes) == 'table', 'capture filter with type `regex` has no regex list')
  assert(filter.capture, 'capture filter with type `regex` has no capture name')

  self.__base.__init(self, filter)

  local engine = filter.engine or 'default'

  engine = assert(ENGINES[engine], string.format('capture filter with type `regex` has unknown engine %s', tostring(engine)))

  self._find = engine(regexes)

  return self
end

function RegexFilter:apply(capture)
  local value = self:value(capture)

  if value and self._find(value) then
    return self._allow
  end

  return not self._allow
end

end

return RegexFilter