local ztimer = require "lzmq.timer"
local date   = require "date"

-------------------------------------------------------------------------------
-- Timers implementations
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local TimeCounter = {} do
TimeCounter.__index = TimeCounter

function TimeCounter:new(interval)
  local o = setmetatable({}, self)
  o._timer = ztimer.monotonic():start(interval * 1000)
  o._value = 0
  return o
end

function TimeCounter:inc(v)
  if self._timer:rest() == 0 then
    self:reset()
  end
  self._value = self._value + (v or 1)
  return self._value
end

function TimeCounter:get()
  if self._timer:rest() == 0 then
    self._value = 0
  end
  return self._value
end

function TimeCounter:raw()
  return self._value
end

function TimeCounter:reset(now)
  self._timer:start()
  self._value = 0
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local ExternalTimeCounter = {} do
ExternalTimeCounter.__index = ExternalTimeCounter

function ExternalTimeCounter:new(interval)
  local o = setmetatable({}, self)
  o._start = 0
  o._interval = interval
  o._value = 0
  return o
end

function ExternalTimeCounter:diff_(now)
  local diff
  if self._start > now then -- overflow
    diff = self._start - now
  else
    diff = now - self._start
  end
  return diff
end

function ExternalTimeCounter:inc(v, now)
  local diff = self:diff_(now)
  if diff > self._interval then
    self:reset(now)
  end
  self._value = self._value + (v or 1)
  return self._value
end

function ExternalTimeCounter:get(now)
  local diff = self:diff_(now)
  if diff > self._interval then
    self._value = 0
  end
  return self._value
end

function ExternalTimeCounter:reset(now)
  self._start = now
  self._value = 0
end

function ExternalTimeCounter:raw()
  return self._value
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local RpnBaseCounter = {} do
RpnBaseCounter.__index = RpnBaseCounter

local div = function(a, b) 
  return math.floor(a/b)
end

local timer

local function get_now(resolution)
  return div(timer:elapsed(), (resolution * 1000))
end

function RpnBaseCounter:__init(interval, resolution)
  self._last_time = 0
  self._total = 0
  self._values = {}

  resolution = resolution or 1
  interval   = interval or 60
  if interval < 60 then interval = 60 end -- at least one minute

  self._N = div(interval, resolution)
  if self._N > 60 then 
    self._N  = 60
    resolution = div(interval, self._N)
  end -- too many subcounters

  self._2N = 2 * self._N

  if resolution == 1 then
    if self._internal then
      self._now = function(self)
        return div(timer:elapsed(), 1000)
      end
    else
      self._now = function(self, now)
        return now
      end
    end
  else
    if self._internal then
      local sec = resolution * 1000
      self._now = function(self)
        return div(timer:elapsed(), sec)
      end
    else
      self._now = function(self, now)
        return div(now, resolution)
      end
    end
  end

  if self._internal then
    timer = timer or ztimer.monotonic():start()
  end

  for i = 0, self._N - 1 do self._values[i] = 0 end

  return self
end

function RpnBaseCounter:_refresh(now)
  local N = self._N

  now = self:_now(now)

  local elapsed = now - self._last_time

  if elapsed > self._2N then
    for i = 0, N - 1 do self._values[i] = 0 end
    self._last_time = now
    self._total = 0
  elseif elapsed >= self._N then
    local last_valid_time = now - N + 1
    local last_count_time = self._last_time

    local i = (last_valid_time - 1) % N
    local j = (last_count_time - 1) % N

    while i ~= j do
      self._total = self._total - self._values[i]
      self._values[i] = 0
      i = (i - 1 + N) % N
    end

    self._last_time = last_valid_time
  end

  return now
end

function RpnBaseCounter:inc(v, now)
  now = self:_refresh(now)

  local e = now % self._N
  self._values[e] = self._values[e] + (v or 1);
  self._total = self._total + (v or 1)

  return self._total
end

function RpnBaseCounter:get(now)
  self:_refresh(now)
  return self._total
end

function RpnBaseCounter:reset(now)
  self._last_time = 0
  self._total = 0
  for i = 0, self._N - 1 do self._values[i] = 0 end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local RpnInternalCounter = setmetatable({}, RpnBaseCounter) do
RpnInternalCounter.__index = RpnInternalCounter

function RpnInternalCounter:new(interval, resolution)
  local o = setmetatable({}, RpnInternalCounter)
  o._internal = true
  RpnBaseCounter.__init(o, interval, resolution)
  return o
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local RpnExternalCounter = setmetatable({}, RpnBaseCounter) do
RpnExternalCounter.__index = RpnExternalCounter

function RpnExternalCounter:new(interval, resolution)
  local o = setmetatable({}, RpnExternalCounter)
  o._internal = false
  RpnBaseCounter.__init(o, interval, resolution)
  return o
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local TimeCounters = {} do
TimeCounters.__index = TimeCounters

function TimeCounters:new(Counter, interval, resolution)
  local o = setmetatable({}, self)
  o._Counter    = Counter
  o._counters   = {}
  o._interval   = interval
  o._resolution = resolution

  return o
end

function TimeCounters:inc(value, delta, now)
  local counter = self._counters[value]
  if not counter then
    counter = self._Counter:new(self._interval, self._resolution)
    self._counters[value] = counter
  end

  return counter:inc(delta, now)
end

function TimeCounters:get(value, now)
  local counter = self._counters[value]
  if not counter then return 0 end

  return counter:get(now)
end

function TimeCounters:reset(value, now)
  local counter = self._counters[value]
  if not counter then return 0 end

  return counter:reset(now)
end

function TimeCounters:purge(now)
  for key, counter in pairs(self._counters) do
    if counter:get(now) == 0 then
      self._counters[key] = nil
    end
  end
end

function TimeCounters:count()
  local c = 0
  for _ in pairs(self._counters) do
    c = c + 1
  end
  return c
end

function TimeCounters:raw(value)
  local counter = self._counters[value]
  if not counter then
    counter = self._Counter:new(self._interval, now)
    self._counters[value] = counter
  end

  return counter:raw()
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Jail API
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local JailCounter = {} do
JailCounter.__index = JailCounter

local date_to_ts do

local begin_time = date(2000, 1, 1)

date_to_ts = function (d)
  return math.floor(date.diff(d, begin_time):spanseconds())
end

end

function JailCounter:new(jail)
  local o = setmetatable({}, self)

  o._external   = jail.counter and jail.counter.time == 'filter'
  o._accumulate = jail.counter and jail.counter.type == 'accumulate'
  o._fixed      = jail.counter and jail.counter.type == 'fixed'
  o._value      = jail.counter and jail.counter.value or 'value'
  o._banwhat    = jail.counter and jail.counter.banwhat or 'host'

  if not o._fixed then
    local resolution = jail.counter and jail.counter.resolution
    local counter
    if resolution then
      counter = o._external and RpnExternalCounter or RpnInternalCounter
    else
      counter = o._external and ExternalTimeCounter or TimeCounter
    end

    o._counter = TimeCounters:new(counter, jail.findtime, resolution)
  end

  return o
end

function JailCounter:inc(filter)
  if self._fixed then
    return tonumber(filter[self._value]) or 1
  end

  local now
  if self._external then
    now = date_to_ts(filter.date)
  end

  local inc
  if self._accumulate then
    inc = tonumber(filter[self._value])
  end

  return self._counter:inc(filter[self._banwhat], inc, now)
end

function JailCounter:reset(filter)
  if self._fixed then return end

  local now
  if self._external then
    now = date_to_ts(filter.date)
  end

  self._counter:reset(filter[self._banwhat], now)
end

function JailCounter:purge(now)
  if self._fixed then return end

  local now
  if self._external then
    now = date_to_ts(now)
  end

  self._counter:purge(now)
end

function JailCounter:count()
  if self._fixed then return 0 end

  return self._counter:count()
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local JailPrefixCounter = {} do
JailPrefixCounter.__index = JailPrefixCounter

function JailPrefixCounter:new(jail)
  local o    = setmetatable({}, self)
  o._tree    = jail.counter.prefix
  o._counter = JailCounter:new(jail)

  return o
end

function JailPrefixCounter:inc(filter)
  if filter.number and self._tree:find(filter.number) then
    return self._counter:inc(filter)
  end
end

function JailPrefixCounter:reset(filter)
  if filter.number and self._tree:find(filter.number) then
    return self._counter:reset(filter)
  end
end

function JailPrefixCounter:purge(now)
  return self._counter:purge(now)
end

function JailPrefixCounter:count()
  return self._counter:count()
end

end
-------------------------------------------------------------------------------

return {
  jail   = JailCounter;
  prefix = JailPrefixCounter;
}