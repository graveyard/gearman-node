_ = require 'underscore'
async = require 'async'
{EventEmitter}  = require 'events'

class MockJob extends EventEmitter
  constructor: ->
    super
    @handle = 'job_handle'
    @events = []
  delayEmit: (event, timeout, args...) =>
    @events.push {event, timeout, args}
  intervalEmit: (event, timeout, data) ->
    interval = Math.floor timeout / (data.length + 1)
    @delayEmit event, (i + 1) * interval, el for el, i in data
  # Takes a list of events and returns a new list of events sorted in increasing order, with each
  # timeout being the offset from the previous event, such that the total offset for the event is
  # the same.
  @orderEvents: (events) ->
    return events unless events.length > 1
    events = _(events).sortBy 'timeout'
    # Pair each event with the previous event, except for the first which gets paired with 0
    pairs = _.zip events, [timeout: 0].concat _.first(events, events.length - 1)
    _.map pairs, ([curr, prev]) ->
      _.extend {}, curr, timeout: curr.timeout - prev.timeout
  start: =>
    # We can't just set timeouts for all of the events because it may not result in a predictable
    # order. For instance, consider:
    # a 'complete' event is registered after 100ms
    # a 'created' event is registered after 10ms
    # If something then blocks the event loop for 110ms, both will fire on the next tick, in the
    # order that they were registered, so we'd see the 'complete' event before seeing the 'create'
    # event.
    events = @constructor.orderEvents @events
    async.forEachSeries events, ({event, timeout, args}, cb_fe) =>
      setTimeout =>
        @emit event, @handle, args...
        cb_fe()
      , timeout
    , -> # No errors to handle
    @

class CompleteJob extends MockJob
  constructor: (timeout = 0) ->
    super
    @delayEmit 'complete', timeout

class DataJob extends CompleteJob
  constructor: (data, timeout = 0) ->
    # Add 1 so 'complete' event fires last
    super timeout + 1
    @intervalEmit 'data', timeout, data

class FailJob extends MockJob
  constructor: (timeout = 0) ->
    super
    @delayEmit 'fail', timeout

class ErrorJob extends FailJob
  constructor: (messages, timeout = 0) ->
    # Add 1 so 'fail' event fires last
    super timeout + 1
    @intervalEmit 'warning', timeout, messages

module.exports = {MockJob, CompleteJob, DataJob, FailJob, ErrorJob}
