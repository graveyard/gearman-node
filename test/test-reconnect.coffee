assert  = require 'assert'
Gearman = require('../index').Gearman
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
