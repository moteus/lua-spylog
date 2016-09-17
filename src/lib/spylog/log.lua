local config  = require "spylog.config"

local function build_writer()
  local SERVICE = require "LuaService"
  local config  = require "spylog.config"
  local stdout_writer

  if not SERVICE.RUN_AS_SERVICE then
    stdout_writer = require 'log.writer.stdout'.new()
  end

  local writer = require "log.writer.list".new(
    require 'log.writer.file'.new(config.LOG.file),
    require 'log.writer.net.zmq'.new(config.LOG.zmq),
    stdout_writer
  )
  return writer
end

if config.LOG.multithread then
  writer = require "log.writer.async.zmq".new('inproc://async.logger',
    config.main_thread and string.dump(build_writer)
  )
else
  writer = build_writer()
end

local log = require "log".new(
  config.LOG.level or "info",
  require "log.writer.prefix".new(config.LOG.prefix or "", writer),
  require "log.formatter.mix".new(
    require "log.formatter.pformat".new()
  )
)

return log