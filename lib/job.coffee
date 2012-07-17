Stream = require("stream").Stream

class Job extends Stream
  constructor: (@gearman, @name, @payload) ->
    @timeoutTimer = null
    @gearman.sendCommand "SUBMIT_JOB", @name, false, @payload, @receiveHandle.bind @

  setTimeout: (timeout, timeoutCallback) ->
    @timeoutValue = timeout
    @timeoutCallback = timeoutCallback
    @updateTimeout()

  updateTimeout: () ->
    return if not @timeoutValue
    clearTimeout @timeoutTimer
    @timeoutTimer = setTimeout (@onTimeout.bind @), @timeoutValue

  onTimeout: () ->
    delete @gearman.currentJobs[@handle] if @handle
    return if @aborted
    @abort()
    error = new Error("Timeout exceeded for the job")
    if typeof @timeoutCallback is "function"
      @timeoutCallback error
    else
      @emit "timeout", error

  abort: () ->
    clearTimeout @timeoutTimer
    @aborted = true

  receiveHandle: (handle) ->
    if not handle
      @emit "error", new Error("Invalid response from server")
      return
    @handle = handle
    @gearman.currentJobs[handle] = @
    @emit "created"

module.exports = Job
