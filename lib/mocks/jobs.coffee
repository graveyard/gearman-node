{EventEmitter}  = require 'events'

module.exports =
  MockJob: class MockJob extends EventEmitter
    constructor: ->
      super
      @handle = 'job_handle'
      @events = []
    delayEmit: (event, timeout, args...) =>
      @events.push {event, timeout, args}
    start: =>
      for {event, timeout, args} in @events
        setTimeout @emit.bind(@), timeout, event, @handle, args...
      @
  CompleteJob: class CompleteJob extends MockJob
    constructor: (timeout=500) ->
      super
      @delayEmit 'complete', timeout
  DataJob: class DataJob extends CompleteJob
    constructor: (data, timeout=500) ->
      super timeout
      data_interval = timeout / (data.length + 1)
      @delayEmit 'data', (i + 1) * data_interval, el for el, i in data
