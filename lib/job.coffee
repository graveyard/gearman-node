Gearman::Job = (gearman, name, payload) ->
  Stream.call this
  @gearman = gearman
  @name = name
  @payload = payload
  @timeoutTimer = null
  gearman.sendCommand "SUBMIT_JOB", name, false, payload, @receiveHandle.bind(this)

utillib.inherits Gearman::Job, Stream
Gearman::Job::setTimeout = (timeout, timeoutCallback) ->
  @timeoutValue = timeout
  @timeoutCallback = timeoutCallback
  @updateTimeout()

Gearman::Job::updateTimeout = ->
  if @timeoutValue
    clearTimeout @timeoutTimer
    @timeoutTimer = setTimeout(@onTimeout.bind(this), @timeoutValue)

Gearman::Job::onTimeout = ->
  delete @gearman.currentJobs[@handle]  if @handle
  unless @aborted
    @abort()
    error = new Error("Timeout exceeded for the job")
    if typeof @timeoutCallback is "function"
      @timeoutCallback error
    else
      @emit "timeout", error

Gearman::Job::abort = ->
  clearTimeout @timeoutTimer
  @aborted = true

Gearman::Job::receiveHandle = (handle) ->
  if handle
    @handle = handle
    @gearman.currentJobs[handle] = this
  else
    @emit "error", new Error("Invalid response from server")