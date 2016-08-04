local ztimer = require "lzmq.timer"
local date   = require "date"

-------------------------------------------------------------------------------
local TimeCounter = {} do
TimeCounter.__index = TimeCounter

function TimeCounter:new(interval)
  local o = setmetatable({}, self)
  o._timer = ztimer.monotonic():start(interval)
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

function ExternalTimeCounter:new(interval, now)
  local o = setmetatable({}, self)
  o._start = now
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
local TimeCounters = {} do
TimeCounters.__index = TimeCounters

function TimeCounters:new(Counter, interval)
  local o = setmetatable({}, self)
  o._Counter = Counter
  o._counters = {}
  o._interval = interval
  return o
end

function TimeCounters:inc(value, delta, now)
  local counter = self._counters[value]
  if not counter then
    counter = self._Counter:new(self._interval, now)
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

  if not o._fixed then
    o._counter = TimeCounters:new( 
      o._external and ExternalTimeCounter or TimeCounter,
      jail.findtime
    )
  end

  return o
end

function JailCounter:inc(filter)
  if self._fixed then
    return tonumber(filter.value) or 1
  end

  local now
  if self._external then
    now = date_to_ts(filter.date)
  end

  local inc
  if self._accumulate then
    inc = tonumber(filter.value)
  end

  return self._counter:inc(filter.host, inc, now)
end

function JailCounter:reset(filter)
  if self._fixed then return end

  local now
  if self._external then
    now = date_to_ts(filter.date)
  end

  self._counter:reset(now)
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

return {
  jail = JailCounter;
}