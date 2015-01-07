_         = require 'underscore'
assert    = require 'assert'
{MockJob} = require('../lib/mocks').Jobs

describe 'mocks', ->
  describe 'jobs', ->
    describe 'event ordering', ->
      make_events = (arr) -> _(arr).map (el) -> timeout: el
      _.each [
        in: [1, 1500, 0]
        out: [0, 1, 1499]
        name: 'with three events'
      ,
        in: [1]
        out: [1]
        name: 'with one event'
      ,
        in: []
        out: []
        name: 'with no events'
      ,
        in: [0, 2, 10, 50]
        out: [0, 2, 8, 40]
        name: 'with four events'
      ], (spec) ->
        it spec.name, ->
          assert.deepEqual MockJob.orderEvents(make_events spec.in), make_events spec.out
