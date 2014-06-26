assert  = require 'assert'
Gearman = require('../index').Gearman
Worker = require('../index').Worker
net = require 'net'

describe 'gearman connection', ->
  it 'auto-reconnects', (done) ->
    # mock gearman server
    port = Math.round(1025 + Math.random() * 40000)
    times = 0
    server = net.createServer (stream) ->
      times += 1
      console.log 'server connected', times
      if times is 2
        gearman.disconnect()
        server.close()
        setTimeout done, 1000 # make sure a reconnect doesn't happen
      if times > 2
        throw new Error "Reconnected more than expected"
      stream.destroy() # gtfo client
    server.listen port
    gearman = new Gearman 'localhost', port, true
    gearman.connect()

describe 'a reconnecting worker', ->
  it 'registers itself', (done) ->
    @timeout 3000
    reset_abilities = [0,0x52,0x45,0x51,0,0,0,0x3,0,0,0,0]
    can_do = [0,0x52,0x45,0x51,0,0,0,0x1]
    expected_buffer = new Buffer reset_abilities.concat can_do
    port = Math.round(1025 + Math.random() * 40000)
    first_connection = true
    server = net.createServer (stream) ->
      stream.on 'data', (data) ->
        if first_connection
          stream.destroy() # pls go client
          first_connection = false
          return
        if bufferStartsWith data, expected_buffer
          gearman.disconnect()
          server.close()
          done()
    server.listen port
    gearman = new Worker 'nothing', (payload, worker) ->
      console.log payload.toString()
    ,{port: port, debug: true}
    gearman.connect()
    
    bufferStartsWith = (buf1, buf2) ->
      return false for i in [0..buf2.length - 1] when buf1[i] isnt buf2[i]
      true
