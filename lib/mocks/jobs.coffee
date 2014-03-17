{EventEmitter}  = require 'events'

class MockJob extends EventEmitter
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

class FinishJob extends MockJob
  constructor: (event, timeout = 500) ->
    super
    @delayEmit event, timeout

class IntervalJob extends FinishJob
  constructor: (finish_event, event, data, timeout = 500) ->
    # Short timeouts can cause the finish event to fire before all the data
    # events fire
    timeout = if timeout <= data.length then (data.length + 1) * 2 else timeout
    super finish_event, timeout
    interval = timeout / (data.length + 1)
    @delayEmit event, (i + 1) * interval, el for el, i in data

class CompleteJob extends FinishJob
  constructor: (timeout = 500) ->
    super 'complete', timeout

class DataJob extends IntervalJob
  constructor: (data, timeout = 500) ->
    super 'complete', 'data', data, timeout

class FailJob extends FinishJob
  constructor: (timeout = 500) ->
    super 'fail', timeout

class ErrorJob extends IntervalJob
  constructor: (messages, timeout = 500) ->
    super 'fail', 'warning', messages, timeout

module.exports = {MockJob, CompleteJob, DataJob, FailJob, ErrorJob}
