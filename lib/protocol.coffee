# Takes care of all protocol-related things:
# - can decode data coming from a socket connection to gearmand. outputs friendly (cmd + args events
# - given a command and arguments, packs and returns a proper gearman packet

EventEmitter = require("events").EventEmitter
assert = require 'assert'
_ = require 'underscore'

class Protocol extends EventEmitter
  @packetTypes:
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
  @packetTypesReversed: {}
  @paramCount:
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

  constructor: (options) ->
    {@debug} = _(options).defaults { debug: true }
    @remainder = null

  decode: (chunk) =>
    # allocate buffer for this chunk plus its predecessor (in the case of continuation)
    data = new Buffer( (chunk?.length or 0) + (@remainder?.length or 0) )
    return if not data.length

    # copy remainder into the start of the buffer
    if @remainder
      @remainder.copy data, 0, 0
      chunk.copy data, @remainder.length, 0 if chunk
    else
      data = chunk

    # gearman packets are always >= 12 bytes (see comment in send...)
    # 4 byte magic code: either \0REQ or \0RES
    # 4 byte packet type
    # 4 byte size: the size of the data being sent after the header
    if data.length < 12
      @remainder = data
      return

    # packet must start with \0RES or \0REQ
    start = data.readUInt32BE 0
    if start isnt 0x00524553 and start isnt 0x00524551
      throw new Error('Gearman decoder out of sync with server')

    # check if the packet is complete
    body_length = data.readUInt32BE 8
    if data.length < 12 + body_length
      @remainder = data
      return

    # check if we got a little bit of the next packet
    @remainder = null
    if data.length > 12 + body_length
      @remainder = data.slice 12 + body_length
      data = data.slice 0, 12 + body_length

    commandId = data.readUInt32BE 4
    cmd = Protocol.packetTypesReversed[commandId]
    assert cmd?, "unhandled command #{cmd}"

    args = []
    if body_length and argTypes = Protocol.paramCount[cmd]
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
      console.log "GEARMAN #{@uid}: received #{cmd} with #{args.length} arguments:"
      #console.log "\tdata: #{data}"
      console.log "\targ[#{i}]: ", "#{arg}", arg for arg, i in args

    @emit.apply @, [cmd].concat(args)
    #@emit cmd, args
    #if typeof @["receive_#{cmd}"] is "function"
    #  #args = args.concat @handleCallbackQueue.shift() if cmd is "JOB_CREATED" and @handleCallbackQueue.length
    #  @["receive_#{cmd}"].apply @, args

    # potentially saw the end of a packet plus a complete new packet
    process.nextTick @decode if @remainder and @remainder.length >= 12

  encode: =>
    args = _(arguments).toArray()
    cmd = args.shift()
    cmd_id = Protocol.packetTypes[cmd]
    assert cmd_id?, "unhandled command #{cmd}"

    body_length = 0
    for i in _.range args.length
      args[i] = new Buffer "#{args[i] or ''}", "utf-8" if args[i] not instanceof Buffer
      body_length += args[i].length

    # null byte between arguments adds to body length
    body_length += if args.length > 1 then args.length - 1 else 0

    # gearman header consists of 12 bytes:
    # 4 byte magic code: either \0REQ or \0RES
    # 4 byte packet type
    # 4 byte size: the size of the data being sent after the header
    body = new Buffer body_length + 12 # packet size + 12 byte header
    body.writeUInt32BE 0x00524551, 0  # \0REQ
    body.writeUInt32BE cmd_id, 4   # packet type
    body.writeUInt32BE body_length, 8  # packet length

    curpos = 12
    for i in _.range args.length
      args[i].copy body, curpos
      curpos += args[i].length
      body[curpos++] = 0x00 if i < args.length - 1 # null byte between args

    body

Protocol.packetTypesReversed[val] = key for key, val of Protocol.packetTypes

module.exports = Protocol