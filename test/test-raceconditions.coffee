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

describe 'slam it', ->
  it 'can handle a ton of jobs', (done) ->
    @timeout 100000

    payloads = {}
    _.each [1..100], (i) ->
      payloads["#{i}"] =
        key: "#{i}"
        value: i * 100
        data: i % 2
        warning: "job #{i} warning"
        fail: (Math.random() > 0.5)
        duration: (Math.random() * 2000)

    worker_fn = (payload, worker) ->
      payload = JSON.parse(payload)
      assert.equal payload.value, payloads[payload.key].value, "worker #{payload.key} received bad payload.value"
      worker.data "#{payload.data}"
      setTimeout () ->
        worker.done(if payload.fail then payload.warning else null)
      , payload.duration
    workers = []
    workers.push(new Worker 'slammer', worker_fn, options) for i in [1..25]

    client = new Client options
    async.forEach _(payloads).keys(), (key, cb_fe) ->
      payload = payloads[key]
      client.submitJob('slammer', JSON.stringify(payload)).on 'data', (handle, data) ->
        assert.equal data, payload.data, "expected job #{key} to produce #{payload.data}, got #{data}"
      .on 'warning', (handle, warning) ->
        assert.equal warning, payload.warning, "expected job #{key} to produce warning #{payload.warning}, got #{warning}"
      .on 'fail', (handle) ->
        assert payload.fail, 'did not expect job to fail'
        cb_fe()
      .on 'complete', (handle, data) ->
        assert (not payload.fail), 'expected job to fail'
        cb_fe()
    , () ->
      worker.disconnect() for worker in workers
      client.disconnect()
      done()
