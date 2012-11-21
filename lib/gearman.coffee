# Convenience wrapper around the gearman protocol. Instead of sending/listening
# for binary packets from the gearman server you can do things like
#
#   gearman = new Gearman
#   gearman.connect()
#   gearman.send 'SUBMIT_JOB', 'reverse', job_id, 'kitteh'
#   gearman.on 'JOB_CREATED', (job_handle) -> ...
#
# Other than emitting events corresponding to gearman server responses like "JOB_CREATED",
# this class emits two other events
#   'connect': called upon a successful call to connect()
#   'error'  : something bad happened
#
# It also queues commands so that you don't have to wait for a connection. For
# even more sugar around the protocol check out ./client and ./worker.

netlib = require "net"
EventEmitter = require("events").EventEmitter
_ = require 'underscore'
assert = require 'assert'
Protocol = require "#{__dirname}/protocol"

uid = 0

class Gearman extends Protocol

  constructor: (@host='localhost', @port=4730, @debug=false) ->
    super @debug
    @uid = (uid += 1)
    @connected = @connecting = false
    @cmd_queue = []
    @handleCallbackQueue = []
    @currentJobs = {}
    @currentWorkers = {}
    @workers = {}

  connect: =>
    return if @connected or @connecting

    @connecting = true
    console.log "GEARMAN #{@uid}: connecting..." if @debug
    @socket = (netlib.connect or netlib.createConnection) @port, @host

    @socket.on "connect", =>
      @socket.setKeepAlive true
      @connecting = false
      @connected = true
      console.log "GEARMAN #{@uid}: connected!" if @debug
      @emit "connect"
      @process_queue()
    @socket.on "end", @disconnect
    @socket.on "close", @disconnect
    @socket.on "error", @error_handler
    @socket.on 'data', @decode

  disconnect: =>
    return if not @connected
    @connected = false
    @connecting = false
    if @socket
      try
        @socket.end()
    console.log "GEARMAN #{@uid}: disconnected" if @debug
    @emit 'disconnect'

  error_handler: (err) =>
    @emit "error", err
    @disconnect()

  send: =>
    @cmd_queue.push _(arguments).toArray()
    @process_queue()

  process_queue: () =>
    return if @cmd_queue.length is 0 or not @connected
    @_send.apply @, @cmd_queue.shift()

  _send: =>
    assert @connected
    buf = @encode.apply @, arguments
    args = _(arguments).toArray()
    cmd = args.shift()
    if @debug
      console.log "GEARMAN #{@uid}: sending #{cmd} with #{args.length} arguments:"
      # console.log "\tbody: #{body}"
      console.log "\targ[#{i}]: ", "#{arg}", arg for arg, i in args
    @socket.write buf, @process_queue

module.exports = Gearman
