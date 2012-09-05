assert  = require 'assert'
Gearman = require('../index').Gearman
Client = require('../index').Client
Worker = require('../index').Worker
_ = require 'underscore'
async = require 'async'

options =
  host: 'localhost'
  port: 4730
  debug: false

describe 'retry', ->
  it 'worker can auto-retry failed jobs', (done) ->
    @timeout 100000

    payload =
      data: 'the data'
      warning: "job warning"

    tries = 0
    worker = new Worker 'retry', (the_payload, worker) ->
      tries += 1
      the_payload = JSON.parse(the_payload)
      assert.equal the_payload.data, payload.data, "#{the_payload.data} received, expected #{payload.data}"
      worker.data "#{the_payload.data}"
      setTimeout () ->
        worker.done(if tries is 1 then the_payload.warning else null)
      , 1000
    , _(max_retries: 1).extend options

    client = new Client options
    client.submitJob('retry', JSON.stringify(payload)).on 'data', (handle, data) ->
      console.log 'received data', data
      assert.equal data, payload.data, "expected job to produce #{payload.data}, got #{data}"
    .on 'warning', (handle, warning) ->
      assert.equal warning, payload.warning, "expected job to produce warning #{payload.warning}, got #{warning}"
    .on 'fail', (handle) ->
      assert false, "job should not fail"
    .on 'complete', (handle, data) ->
      worker.disconnect() for worker in workers
      client.disconnect()
      done()
