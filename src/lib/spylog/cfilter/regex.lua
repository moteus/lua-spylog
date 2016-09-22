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
  assert(filter.regex, 'capture filter with type `regex` has no regex list')
  if type(filter.regex) == 'string' then
    filter.regex = {filter.regex}
  end

  assert(filter.value, 'capture filter with type `regex` has no value')

  self.__base.__init(self, filter)

  local engine = filter.engine or 'default'

  engine = assert(ENGINES[engine], string.format('capture filter with type `regex` has unknown engine %s', tostring(engine)))

  self._find = engine(filter.regex)

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