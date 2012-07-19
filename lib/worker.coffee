Stream = require("stream").Stream

class Worker extends Stream
  constructor: (@gearman, @handle, @name, @payload) ->
    @writable = true
    @finished = false

  write: (data) ->
    return if @finished
    @gearman.sendCommand "WORK_DATA", @handle, data

  success: (data) ->
    return if @finished
    @finished = true
    @gearman.sendCommand "WORK_COMPLETE", @handle, data
    delete @gearman.currentWorkers[@handle]
    @gearman.sendCommand "GRAB_JOB"

  error: () ->
    return if @finished
    @finished = true
    @gearman.sendCommand "WORK_FAIL", @handle
    delete @gearman.currentWorkers[@handle]
    @gearman.sendCommand "GRAB_JOB"

  warn: (warning) ->
    return if @finished
    @gearman.sendCommand "WORK_WARNING", @handle, warning

  done: (err) ->
    return @success() if not err?
    @warn err
    @error()

module.exports = Worker
