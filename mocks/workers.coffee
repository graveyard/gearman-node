_               = require 'underscore'
assert          = require 'assert'
{EventEmitter}  = require 'events'
util            = require 'util'

METHODS = ['warning', 'status', 'data', 'error', 'complete', 'done']
error_on_methods = (methods) -> _(methods).each error_on_method.bind @
error_on_method = (method) ->
  @on method, (args...) =>
    throw new Error "Called unexpected '#{method}' with #{args}"

# Mock gearman worker object
class MockWorker extends EventEmitter
  constructor: ->
    super
    @received = {}
    _(METHODS).each (method) =>
      @[method] = (args...) =>
        @emit.apply @, [method].concat args
        @received[method] ?= []
        @received[method].push args
    @handle = "some_thing:#{Math.floor (Math.random() * 99999) + 1}"
# A mock worker that expects to only have the 'done' method called
class DoneWorker extends MockWorker
  constructor: (done_fn) ->
    super
    error_on_methods _(METHODS).without 'done'
    @on 'done', done_fn
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
    super
    data = []
    error_on_methods _(METHODS).without 'done', 'data'
    @on 'data', (datum) -> data.push datum
    @on 'done', (err) =>
      assert.ifError err
      done_fn null, data
module.exports = _([DoneWorker, SuccessWorker, ErrorWorker, MockWorker, DataWorker]).chain()
  .map((klass) -> [klass.name, klass]).object().value()
