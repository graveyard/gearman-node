assert  = require 'assert'
Gearman = require '../index'

gearman = new Gearman('localhost')

describe 'test connection', ->
  gearman = null
  before () ->
    gearman = new Gearman('localhost')

  it 'instantiates Gearman class', ->
    assert gearman instanceof Gearman, 'instance not created'

  it 'connect to server', (done) ->
    gearman.on 'error', (e) ->
      assert false, 'error connecting'
      done()
    gearman.on 'connect', ->
      done()
    gearman.connect()

  it 'closes connection', (done) ->
    gearman.on 'close', ->
      done()
    gearman.close()

describe 'worker and client', ->
  gearman = null

  beforeEach (done) ->
    gearman = new Gearman('localhost')
    gearman.on 'connect', ->
      done()
    gearman.on 'error', (e) ->
      console.log e.message
    gearman.connect()

  afterEach (done) ->
    gearman.on 'close', ->
      done()
    gearman.close()

  it 'sends/receives binary data', (done) ->
    data1 = new Buffer([ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])
    data2 = new Buffer([ 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255 ])
    gearman.registerWorker 'test', (payload, worker) ->
      assert.equal payload.toString('base64'), data1.toString('base64')
      worker.end data2

    job = gearman.submitJob('test', data1)
    job.on 'data', (payload) ->
      assert.equal payload.toString('base64'), data2.toString('base64')

    job.on 'end', ->
      gearman.on 'idle', -> done()

  it 'allows for worker failure', (done) ->
    gearman.registerWorker 'test_error', (payload, worker) ->
      worker.error()

    job = gearman.submitJob('test_error', 'error')
    job.on 'error', (err) ->
      assert err, 'job should have an error'
      gearman.on 'idle', -> done()

    job.on 'end', (err) ->
      console.log 'DONE', err
      assert false, 'job should not have ended'

describe 'job timeout', ->
  gearman = null
  beforeEach (done) ->
    gearman = new Gearman('localhost')
    gearman.on 'connect', ->
      done()
    gearman.on 'error', (e) ->
      console.log e.message
    gearman.connect()
    gearman.registerWorker 'test', (payload, worker) ->
      setTimeout (->
        worker.end 'OK'
      ), 300

  afterEach (done) ->
    gearman.on 'close', ->
      done()
    gearman.close()

  it 'generates event', (done) ->
    job = gearman.submitJob('test', 'test')
    job.setTimeout 100
    job.on 'timeout', ->
      assert true
      done()
    job.on 'error', (err) ->
      assert false, 'job should not generate error'
    job.on 'end', (err) ->
      assert false, 'job should not complete'

  it 'has timeout callback', (done) ->
    job = gearman.submitJob('test', 'test')
    job.setTimeout 100, ->
      assert true, 'timeout occured'
      done()
    job.on 'error', (err) ->
      assert false, 'job should not generate error'
    job.on 'end', (err) ->
      assert false, 'job should not complete'

  it 'timeout does not occur', (done) ->
    job = gearman.submitJob('test', 'test')
    job.setTimeout 400, ->
      assert false, 'timeout occured'
    job.on 'error', (err) ->
      assert false, 'job should not fail'
    job.on 'end', (err) ->
      assert true, 'job completed before timeout'
      done()
