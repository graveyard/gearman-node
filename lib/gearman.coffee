Gearman = (host, port, debug) ->
  Stream.call this
  @debug = !!debug
  @port = port or 4730
  @host = host or "localhost"
  @init()
netlib = require("net")
Stream = require("stream").Stream
utillib = require("util")
module.exports = Gearman
utillib.inherits Gearman, Stream
Gearman::init = ->
  @connected = @connecting = @processing = false
  @processing = false
  @commandQueue = []
  @handleCallbackQueue = []
  @remainder = false
  @currentJobs = {}
  @currentWorkers = {}
  @workers = {}

Gearman.packetTypes =
  CAN_DO: 1
  CANT_DO: 2
  RESET_ABILITIES: 3
  PRE_SLEEP: 4
  NOOP: 6
  SUBMIT_JOB: 7
  JOB_CREATED: 8
  GRAB_JOB: 9
  NO_JOB: 10
  JOB_ASSIGN: 11
  WORK_STATUS: 12
  WORK_COMPLETE: 13
  WORK_FAIL: 14
  GET_STATUS: 15
  ECHO_REQ: 16
  ECHO_RES: 17
  SUBMIT_JOB_BG: 18
  ERROR: 19
  STATUS_RES: 20
  SUBMIT_JOB_HIGH: 21
  SET_CLIENT_ID: 22
  CAN_DO_TIMEOUT: 23
  ALL_YOURS: 24
  WORK_EXCEPTION: 25
  OPTION_REQ: 26
  OPTION_RES: 27
  WORK_DATA: 28
  WORK_WARNING: 29
  GRAB_JOB_UNIQ: 30
  JOB_ASSIGN_UNIQ: 31
  SUBMIT_JOB_HIGH_BG: 32
  SUBMIT_JOB_LOW: 33
  SUBMIT_JOB_LOW_BG: 34
  SUBMIT_JOB_SCHED: 35
  SUBMIT_JOB_EPOCH: 36

Gearman.packetTypesReversed =
  1: "CAN_DO"
  2: "CANT_DO"
  3: "RESET_ABILITIES"
  4: "PRE_SLEEP"
  6: "NOOP"
  7: "SUBMIT_JOB"
  8: "JOB_CREATED"
  9: "GRAB_JOB"
  10: "NO_JOB"
  11: "JOB_ASSIGN"
  12: "WORK_STATUS"
  13: "WORK_COMPLETE"
  14: "WORK_FAIL"
  15: "GET_STATUS"
  16: "ECHO_REQ"
  17: "ECHO_RES"
  18: "SUBMIT_JOB_BG"
  19: "ERROR"
  20: "STATUS_RES"
  21: "SUBMIT_JOB_HIGH"
  22: "SET_CLIENT_ID"
  23: "CAN_DO_TIMEOUT"
  24: "ALL_YOURS"
  25: "WORK_EXCEPTION"
  26: "OPTION_REQ"
  27: "OPTION_RES"
  28: "WORK_DATA"
  29: "WORK_WARNING"
  30: "GRAB_JOB_UNIQ"
  31: "JOB_ASSIGN_UNIQ"
  32: "SUBMIT_JOB_HIGH_BG"
  33: "SUBMIT_JOB_LOW"
  34: "SUBMIT_JOB_LOW_BG"
  35: "SUBMIT_JOB_SCHED"
  36: "SUBMIT_JOB_EPOCH"

Gearman.paramCount =
  ERROR: [ "string", "string" ]
  JOB_ASSIGN: [ "string", "string", "buffer" ]
  JOB_ASSIGN_UNIQ: [ "string", "string", "string", "buffer" ]
  JOB_CREATED: [ "string" ]
  WORK_COMPLETE: [ "string", "buffer" ]
  WORK_EXCEPTION: [ "string", "string" ]
  WORK_WARNING: [ "string", "string" ]
  WORK_DATA: [ "string", "buffer" ]
  WORK_FAIL: [ "string" ]
  WORK_STATUS: [ "string", "number", "number" ]

Gearman::connect = ->
  if @connected or @connecting
    @processCommandQueue()  if @connected and not @processing
    return false
  @connecting = true
  console.log "connecting..."  if @debug
  @socket = (netlib.connect or netlib.createConnection)(@port, @host)
  @socket.on "connect", (->
    @socket.setKeepAlive true
    @connecting = false
    @connected = true
    console.log "connected!"  if @debug
    @emit "connect"
    @processCommandQueue()
  ).bind(this)
  @socket.on "end", @close.bind(this)
  @socket.on "close", @close.bind(this)
  @socket.on "error", @errorHandler.bind(this)
  @socket.on "data", @receive.bind(this)

Gearman::close = ->
  if @connected
    @closeConnection()
    @emit "close"

Gearman::closeConnection = ->
  i = undefined
  if @connected
    if @socket
      try
        @socket.end()
    @connected = false
    @connecting = false
    for i of @currentJobs
      if @currentJobs.hasOwnProperty(i)
        if @currentJobs[i]
          @currentJobs[i].abort()
          @currentJobs[i].emit "error", new Error("Job failed")
        delete @currentJobs[i]
    for i of @currentWorkers
      if @currentWorkers.hasOwnProperty(i)
        @currentWorkers[i].finished = true  if @currentWorkers[i]
        delete @currentWorkers[i]
    @init()

Gearman::errorHandler = (err) ->
  @emit "error", err
  @closeConnection()

Gearman::processCommandQueue = (chunk) ->
  command = undefined
  if @commandQueue.length
    @processing = true
    command = @commandQueue.shift()
    @sendCommandToServer.apply this, command
  else
    @processing = false

Gearman::sendCommand = ->
  command = Array::slice.call(arguments)
  @commandQueue.push command
  @processCommandQueue()  unless @processing

Gearman::sendCommandToServer = ->
  body = undefined
  args = Array::slice.call(arguments)
  commandName = undefined
  commandId = undefined
  commandCallback = undefined
  i = undefined
  len = undefined
  bodyLength = 0
  curpos = 12
  unless @connected
    @commandQueue.unshift args
    return @connect()
  commandName = (args.shift() or "").trim().toUpperCase()
  if args.length and typeof args[args.length - 1] is "function"
    commandCallback = args.pop()
    @handleCallbackQueue.push commandCallback
  commandId = Gearman.packetTypes[commandName] or 0
  commandId
  i = 0
  len = args.length

  while i < len
    args[i] = new Buffer((args[i] or "").toString(), "utf-8")  unless args[i] instanceof Buffer
    bodyLength += args[i].length
    i++
  bodyLength += (if args.length > 1 then args.length - 1 else 0)
  body = new Buffer(bodyLength + 12)
  body.writeUInt32BE 0x00524551, 0
  body.writeUInt32BE commandId, 4
  body.writeUInt32BE bodyLength, 8
  i = 0
  len = args.length

  while i < len
    args[i].copy body, curpos
    curpos += args[i].length
    body[curpos++] = 0x00  if i < args.length - 1
    i++
  if @debug
    console.log "Sending: " + commandName + " with " + args.length + " params"
    console.log " - ", body
    args.forEach (arg, i) ->
      console.log "  - ARG:" + i + " ", arg.toString()
  @socket.write body, @processCommandQueue.bind(this)

Gearman::receive = (chunk) ->
  data = new Buffer((chunk and chunk.length or 0) + (@remainder and @remainder.length or 0))
  commandId = undefined
  commandName = undefined
  bodyLength = 0
  args = []
  argTypes = undefined
  curarg = undefined
  i = undefined
  len = undefined
  argpos = undefined
  curpos = undefined
  return  unless data.length
  if @remainder
    @remainder.copy data, 0, 0
    chunk.copy data, @remainder.length, 0  if chunk
  else
    data = chunk
  if data.length < 12
    @remainder = data
    return
  return @errorHandler(new Error("Out of sync with server"))  unless data.readUInt32BE(0) is 0x00524553
  bodyLength = data.readUInt32BE(8)
  if data.length < 12 + bodyLength
    @remainder = data
    return
  if data.length > 12 + bodyLength
    @remainder = data.slice(12 + bodyLength)
    data = data.slice(0, 12 + bodyLength)
  else
    @remainder = false
  commandId = data.readUInt32BE(4)
  commandName = (Gearman.packetTypesReversed[commandId] or "")
  return  unless commandName
  if bodyLength and (argTypes = Gearman.paramCount[commandName])
    curpos = 12
    argpos = 12
    i = 0
    len = argTypes.length

    while i < len
      if i < len - 1
        curpos++  while data[curpos] isnt 0x00 and curpos < data.length
        curarg = data.slice(argpos, curpos)
      else
        curarg = data.slice(argpos)
      switch argTypes[i]
        when "string"
          curarg = curarg.toString("utf-8")
        when "number"
          curarg = Number(curarg.toString()) or 0
      args.push curarg
      curpos++
      argpos = curpos
      break  if curpos >= data.length
      i++
  if @debug
    console.log "Received: " + commandName + " with " + args.length + " params"
    console.log " - ", data
    args.forEach (arg, i) ->
      console.log "  - ARG:" + i + " ", arg.toString()
  if typeof this["receive_" + commandName] is "function"
    args = args.concat(@handleCallbackQueue.shift())  if commandName is "JOB_CREATED" and @handleCallbackQueue.length
    this["receive_" + commandName].apply this, args
  process.nextTick @receive.bind(this)  if @remainder and @remainder.length >= 12

Gearman::receive_NO_JOB = ->
  @sendCommand "PRE_SLEEP"
  @emit "idle"

Gearman::receive_NOOP = ->
  @sendCommand "GRAB_JOB"

Gearman::receive_ECHO_REQ = (payload) ->
  @sendCommand "ECHO_RES", payload

Gearman::receive_ERROR = (code, message) ->
  console.log "Server error: ", code, message  if @debug

Gearman::receive_JOB_CREATED = (handle, callback) ->
  callback handle  if typeof callback is "function"

Gearman::receive_WORK_FAIL = (handle) ->
  job = undefined
  if job = @currentJobs[handle]
    delete @currentJobs[handle]

    unless job.aborted
      job.abort()
      job.emit "error", new Error("Job failed")

Gearman::receive_WORK_DATA = (handle, payload) ->
  if @currentJobs[handle] and not @currentJobs[handle].aborted
    @currentJobs[handle].emit "data", payload
    @currentJobs[handle].updateTimeout()

Gearman::receive_WORK_COMPLETE = (handle, payload) ->
  job = undefined
  if job = @currentJobs[handle]
    delete @currentJobs[handle]

    unless job.aborted
      clearTimeout job.timeoutTimer
      job.emit "data", payload  if payload
      job.emit "end"

Gearman::receive_JOB_ASSIGN = (handle, name, payload) ->
  if typeof @workers[name] is "function"
    worker = new @Worker(this, handle, name, payload)
    @currentWorkers[handle] = worker
    @workers[name] payload, worker

Gearman::registerWorker = (name, func) ->
  unless @workers[name]
    @sendCommand "CAN_DO", name
    @sendCommand "GRAB_JOB"
  @workers[name] = func

Gearman::submitJob = (name, payload) ->
  new @Job(this, name, payload)

Gearman::Worker = (gearman, handle, name, payload) ->
  Stream.call this
  @gearman = gearman
  @handle = handle
  @name = name
  @payload = payload
  @finished = false
  @writable = true

utillib.inherits Gearman::Worker, Stream
Gearman::Worker::write = (data) ->
  return  if @finished
  @gearman.sendCommand "WORK_DATA", @handle, data

Gearman::Worker::end = (data) ->
  return  if @finished
  @finished = true
  @gearman.sendCommand "WORK_COMPLETE", @handle, data
  delete @gearman.currentWorkers[@handle]

  @gearman.sendCommand "GRAB_JOB"

Gearman::Worker::error = (error) ->
  return  if @finished
  @finished = true
  @gearman.sendCommand "WORK_FAIL", @handle
  delete @gearman.currentWorkers[@handle]

  @gearman.sendCommand "GRAB_JOB"

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