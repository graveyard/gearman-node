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
    gearman.connect()
    gearman.on 'error', (e) ->
      assert false, 'error connecting'
      done()
    gearman.on 'connect', ->
      done()

  it 'closes connection', (done) ->
    gearman.on 'close', ->
      done()
    gearman.close()


###
exports["Worker and Client"] =
  setUp: (callback) ->
    @gearman = new Gearman("localhost")
    @gearman.on "connect", ->
      callback()

    @gearman.on "error", (e) ->
      console.log e.message

    @gearman.connect()

  tearDown: (callback) ->
    @gearman.on "close", ->
      callback()

    @gearman.close()

  "Send/Receive binary data": (test) ->
    test.expect 2
    data1 = new Buffer([ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])
    data2 = new Buffer([ 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255 ])
    @gearman.registerWorker "test", (payload, worker) ->
      test.equal payload.toString("base64"), data1.toString("base64")
      worker.end data2

    job = @gearman.submitJob("test", data1)
    job.on "data", (payload) ->
      test.equal payload.toString("base64"), data2.toString("base64")

    job.on "end", ->
      @gearman.on "idle", ->
        test.done()

  "Worker fails": (test) ->
    test.expect 1
    @gearman.registerWorker "test", (payload, worker) ->
      worker.error()

    job = @gearman.submitJob("test", "test")
    job.on "error", (err) ->
      test.ok err, "Job failed"
      @gearman.on "idle", ->
        test.done()

    job.on "end", (err) ->
      test.ok false, "Job did not fail"
      test.done()

  "Server fails jobs": (test) ->
    test.expect 1
    job = @gearman.submitJob("test", "test")
    job.on "error", (err) ->
      test.ok err, "Job failed"
      test.done()

    job.on "end", (err) ->
      test.ok false, "Job did not fail"
      test.done()

    setTimeout (->
      @gearman.close()
    ).bind(this), 300

exports["Job timeout"] =
  setUp: (callback) ->
    @gearman = new Gearman("localhost")
    @gearman.on "connect", ->
      callback()

    @gearman.on "error", (e) ->
      console.log e.message

    @gearman.connect()
    @gearman.registerWorker "test", (payload, worker) ->
      setTimeout (->
        worker.end "OK"
      ), 300

  tearDown: (callback) ->
    @gearman.on "close", ->
      callback()

    @gearman.close()

  "Timeout event": (test) ->
    test.expect 1
    job = @gearman.submitJob("test", "test")
    job.setTimeout 100
    job.on "timeout", ->
      test.ok 1, "TImeout occured"
      test.done()

    job.on "error", (err) ->
      test.ok false, "Job failed"
      test.done()

    job.on "end", (err) ->
      test.ok false, "Job should not complete"
      test.done()

  "Timeout callback": (test) ->
    test.expect 1
    job = @gearman.submitJob("test", "test")
    job.setTimeout 100, ->
      test.ok true, "TImeout occured"
      test.done()

    job.on "error", (err) ->
      test.ok false, "Job failed"
      test.done()

    job.on "end", (err) ->
      test.ok false, "Job should not complete"
      test.done()

  "Timeout set but does not occur": (test) ->
    test.expect 1
    job = @gearman.submitJob("test", "test")
    job.setTimeout 400, ->
      test.ok false, "Timeout occured"
      test.done()

    job.on "error", (err) ->
      test.ok false, "Job failed"
      test.done()

    job.on "end", (err) ->
      test.ok true, "Job completed before timeout"
      test.done()
