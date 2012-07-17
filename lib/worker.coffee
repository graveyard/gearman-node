Stream = require("stream").Stream

class Worker extends Stream
  constructor: (@gearman, @handle, @name, @payload) ->
    @writable = true
    @finished = false

  write: (data) ->
    return if @finished
    @gearman.sendCommand "WORK_DATA", @handle, data

  end: (data) ->
    return if @finished
    @finished = true
    @gearman.sendCommand "WORK_COMPLETE", @handle, data
    delete @gearman.currentWorkers[@handle]
    @gearman.sendCommand "GRAB_JOB"

  error: (error) ->
    return if @finished
    @finished = true
    @gearman.sendCommand "WORK_FAIL", @handle
    delete @gearman.currentWorkers[@handle]
    @gearman.sendCommand "GRAB_JOB"

module.exports = Worker
