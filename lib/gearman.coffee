# Convenience wrapper around the gearman protocol. Instead of sending/listening
# for binary packets from the gearman server you can do things like
#
#   gearman = new Gearman
#   gearman.connect()
#   gearman.sendCommand 'SUBMIT_JOB', 'reverse', job_id, 'kitteh'
#   gearman.on 'JOB_CREATED', (job_handle) -> ...
#
# Other than emitting events corresponding to gearman server responses like "JOB_CREATED",
# this class emits two other events
#   'connect': called upon a successful call to connect()
#   'error'  : something bad happened
#
# It also queues commands so that you don't have to wait for a connection. For
# even more sugar around the protocol check out ./client and ./worker.

EventEmitter = require("events").EventEmitter
_ = require 'underscore'
assert = require 'assert'
reconnect = require 'reconnect'

uid = 0

class Gearman extends EventEmitter
  constructor: (@host='localhost', @port=4730, @debug=false) ->
    @uid = (uid += 1)
    @packetTypes =
      CAN_DO             : 1
      CANT_DO            : 2
      RESET_ABILITIES    : 3
      PRE_SLEEP          : 4
      NOOP               : 6
      SUBMIT_JOB         : 7
      JOB_CREATED        : 8
      GRAB_JOB           : 9
      NO_JOB             : 10
      JOB_ASSIGN         : 11
      WORK_STATUS        : 12
      WORK_COMPLETE      : 13
      WORK_FAIL          : 14
      GET_STATUS         : 15
      ECHO_REQ           : 16
      ECHO_RES           : 17
      SUBMIT_JOB_BG      : 18
      ERROR              : 19
      STATUS_RES         : 20
      SUBMIT_JOB_HIGH    : 21
      SET_CLIENT_ID      : 22
      CAN_DO_TIMEOUT     : 23
      ALL_YOURS          : 24
      WORK_EXCEPTION     : 25
      OPTION_REQ         : 26
      OPTION_RES         : 27
      WORK_DATA          : 28
      WORK_WARNING       : 29
      GRAB_JOB_UNIQ      : 30
      JOB_ASSIGN_UNIQ    : 31
      SUBMIT_JOB_HIGH_BG : 32
      SUBMIT_JOB_LOW     : 33
      SUBMIT_JOB_LOW_BG  : 34
      SUBMIT_JOB_SCHED   : 35
      SUBMIT_JOB_EPOCH   : 36
    @packetTypesReversed = {}
    @packetTypesReversed[val] = key for key, val of @packetTypes
    @connected = @connecting = @remainder = false
    @commandQueue = []
    @handleCallbackQueue = []
    @currentJobs = {}
    @currentWorkers = {}
    @workers = {}

    @paramCount =
      ERROR           : [ "string", "string" ]
      JOB_ASSIGN      : [ "string", "string", "buffer" ]
      JOB_ASSIGN_UNIQ : [ "string", "string", "string", "buffer" ]
      JOB_CREATED     : [ "string" ]
      WORK_COMPLETE   : [ "string", "buffer" ]
      WORK_EXCEPTION  : [ "string", "buffer" ]
      WORK_WARNING    : [ "string", "string" ]
      WORK_DATA       : [ "string", "buffer" ]
      WORK_FAIL       : [ "string" ]
      WORK_STATUS     : [ "string", "number", "number" ]

  connect: ->
    return if @connected or @connecting
    @connecting = true
    console.log "GEARMAN #{@uid}: connecting..." if @debug
    @reconnecter = reconnect (socket) =>
      console.log 'socket', socket
      @socket = socket
      @socket.on "error", @errorHandler.bind @
      @socket.on "data", @receive.bind @
      @socket.setKeepAlive true
      @connecting = false
      @connected = true
      console.log "GEARMAN #{@uid}: connected!" if @debug
      @emit "connect"
      @processCommandQueue()
    @reconnecter.on 'reconnect', ->
      console.log "GEARMAN #{@uid}: attempting reconnect!" if @debug
      @connected = false
      @connecting = true
    @reconnecter.connect {host: @host, port: @port}

  disconnect: ->
    return if not @connected
    @reconnecter.reconnect = false # user has explicitly requested a disconnect, so stop reconnecting
    @connected = false
    @connecting = false
    if @socket
      try
        @socket.end()
    console.log "GEARMAN #{@uid}: disconnected" if @debug
    @emit 'disconnect'

  errorHandler: (err) ->
    @emit "error", err
    @disconnect()

  sendCommand: ->
    # { '0' : arg0, '1': arg1, ... } -> [ arg0, arg1, ... ]
    @commandQueue.push _.toArray(arguments)
    @processCommandQueue()

  processCommandQueue: () ->
    return if @commandQueue.length is 0 or not @connected
    @sendCommandToServer.apply @, @commandQueue.shift()

  sendCommandToServer: ->
    assert @connected
    args = _.toArray(arguments)
    console.log "GEARMAN #{@uid}: sendCommandToServer", args if @debug

    # if args.length and typeof(_.last(args)) is "function"
    #   commandCallback = args.pop()
    #   @handleCallbackQueue.push commandCallback

    commandName = (args.shift() or "").trim().toUpperCase()
    commandId = @packetTypes[commandName]
    assert commandId?, "unhandled command #{commandName}"

    bodyLength = 0
    for i in _.range args.length
      args[i] = new Buffer "#{args[i] or ''}", "utf-8" if args[i] not instanceof Buffer
      bodyLength += args[i].length

    # null byte between arguments adds to body length
    bodyLength += if args.length > 1 then args.length - 1 else 0

    # gearman header consists of 12 bytes:
    # 4 byte magic code: either \0REQ or \0RES
    # 4 byte packet type
    # 4 byte size: the size of the data being sent after the header
    body = new Buffer bodyLength + 12 # packet size + 12 byte header
    body.writeUInt32BE 0x00524551, 0  # \0REQ
    body.writeUInt32BE commandId, 4   # packet type
    body.writeUInt32BE bodyLength, 8  # packet length

    curpos = 12
    for i in _.range args.length
      args[i].copy body, curpos
      curpos += args[i].length
      body[curpos++] = 0x00 if i < args.length - 1 # null byte between args

    if @debug
      console.log "GEARMAN #{@uid}: sending #{commandName} with #{args.length} arguments:"
      # console.log "\tbody: #{body}"
      console.log "\targ[#{i}]: ", "#{arg}", arg for arg, i in args

    @socket.write body, @processCommandQueue.bind @

  receive: (chunk) ->
    # allocate buffer for this chunk plus its predecessor (in the case of continuation)
    data = new Buffer( (chunk?.length or 0) + (@remainder?.length or 0) )
    return if not data.length

    # copy remainder into the start of the buffer
    if @remainder
      @remainder.copy data, 0, 0
      chunk.copy data, @remainder.length, 0 if chunk
    else
      data = chunk

    # gearman responses are always >= 12 bytes (see comment in send...)
    if data.length < 12
      @remainder = data
      return

    # packet must start with \0RES
    if (data.readUInt32BE 0) isnt 0x00524553
      return @errorHandler new Error "Out of sync with server"

    # check if the response is complete
    bodyLength = data.readUInt32BE 8
    if data.length < 12 + bodyLength
      @remainder = data
      return

    # check if we got a little bit of the next packet
    @remainder = null
    if data.length > 12 + bodyLength
      @remainder = data.slice 12 + bodyLength
      data = data.slice 0, 12 + bodyLength

    commandId = data.readUInt32BE 4
    commandName = @packetTypesReversed[commandId]
    assert commandName?, "unhandled command #{commandName}"

    args = []
    if bodyLength and argTypes = @paramCount[commandName]
      curpos = 12
      argpos = 12

      for argType, i in argTypes

        # read the argument from the buffer. arguments are separated by null
        curarg = data.slice argpos # last argument
        if i < argTypes.length - 1
          # find where the argument ends
          curpos++ while data[curpos] isnt 0x00 and curpos < data.length
          curarg = data.slice argpos, curpos

        switch argTypes[i]
          when "string"
            curarg = curarg.toString "utf-8"
          when "number"
            curarg = Number(curarg.toString()) or 0

        args.push curarg
        curpos++ # for null
        argpos = curpos
        break if curpos >= data.length

    if @debug
      console.log "GEARMAN #{@uid}: received #{commandName} with #{args.length} arguments:"
      #console.log "\tdata: #{data}"
      console.log "\targ[#{i}]: ", "#{arg}", arg for arg, i in args

    @emit.apply @, [commandName].concat(args)
    #@emit commandName, args
    #if typeof @["receive_#{commandName}"] is "function"
    #  #args = args.concat @handleCallbackQueue.shift() if commandName is "JOB_CREATED" and @handleCallbackQueue.length
    #  @["receive_#{commandName}"].apply @, args

    # potentially saw the end of a packet plus a complete new packet
    process.nextTick @receive.bind @ if @remainder and @remainder.length >= 12

module.exports = Gearman
