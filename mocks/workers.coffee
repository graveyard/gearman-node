_               = require 'underscore'
assert          = require 'assert'
{EventEmitter2} = require 'eventemitter2'
util            = require 'util'

# Mock gearman worker object
class MockWorker extends EventEmitter2
  constructor: ->
    super { wildcard: true }
    _(['warning', 'status', 'data', 'error', 'complete', 'done']).each (method) =>
      @[method] = => @emit.apply @, [method].concat(_(arguments).toArray())
    @handle = "some_thing:#{Math.floor (Math.random() * 99999) + 1}"
# A mock worker that expects to only have the 'done' method called once
class DoneWorker extends MockWorker
  constructor: (done_fn) ->
    super()
    @on '*', (args...) ->
      assert.equal @event, 'done', "Worker sent unexpected event #{@event}: #{util.inspect args}"
      done_fn args...
# A mock worker that expects to only have the 'done' method called without an error
class SuccessWorker extends DoneWorker
  constructor: (success_fn) ->
    super (err, rest...) ->
      assert.ifError err
      success_fn null, rest...
# A mock worker that expects to only have the 'done' method called with an error
class ErrorWorker extends DoneWorker
  constructor: (err_fn) ->
    super (err) ->
      assert err
      err_fn err
# A mock worker that expects to only have the 'done' and 'data' methods called, without an error.
# Sends the data to the done_fn
class DataWorker extends MockWorker
  constructor: (done_fn) ->
    super()
    data = []
    @on '*', (args...) ->
      switch @event
        when 'data'
          data.push args[0]
        when 'done'
          assert.ifError args[0]
          done_fn null, data
        else
          throw new Error "Worker sent unexpected event #{@event}: #{util.inspect args}"
module.exports = _([DoneWorker, SuccessWorker, ErrorWorker, MockWorker, DataWorker]).chain()
  .map((klass) -> [klass.name, klass]).object().value()
