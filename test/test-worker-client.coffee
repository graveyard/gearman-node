assert  = require 'assert'
Gearman = require('../index').Gearman
Client = require('../index').Client
Worker = require('../index').Worker
_ = require 'underscore'
async = require 'async'

options =
  host: 'localhost'
  port: 4730
  debug: true

describe 'connection', ->
  gearman = null
  before () ->
    gearman = new Gearman(options.host, options.port, options.debug)
    gearman.on 'error', (e) -> throw e

  it 'instantiates Gearman class', ->
    assert gearman instanceof Gearman, 'instance not created'

  it 'can connect to server', (done) ->
    gearman.on 'connect', -> done()
    gearman.connect()

  it 'closes connection', (done) ->
    gearman.on 'disconnect', -> done()
    gearman.disconnect()

describe 'worker and client', ->
  it 'sends/receives binary data', (done) ->
    @timeout 10000
    data1 = new Buffer([ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])
    data2 = new Buffer([ 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255 ])
    worker = new Worker 'test', (payload, worker) ->
      assert.equal payload.toString('base64'), data1.toString('base64')
      worker.complete data2
    , options

    client = new Client options
    job = client.submitJob 'test', data1
    job.on 'complete', (handle, data) ->
      assert.equal data.toString('base64'), data2.toString('base64')
      worker.disconnect()
      client.disconnect()
      done()

  it 'sends/receives strings and json', (done) ->
    @timeout 10000
    payload_data = { 'test payload': 'test' }
    worker_data = { 'test worker': 'test' }
    worker = new Worker 'test_json', (payload, worker) ->
      assert.deepEqual JSON.parse(payload), payload_data
      worker.complete JSON.stringify(worker_data)
    , options

    client = new Client options
    job = client.submitJob 'test_json', JSON.stringify(payload_data)
    job.on 'complete', (handle, data) ->
      assert.deepEqual JSON.parse(data), worker_data
      worker.disconnect()
      client.disconnect()
      done()

  it 'allows for worker failure without message', (done) ->
    @timeout 10000
    worker = new Worker 'test_fail', (payload, worker) ->
      worker.error()
    , options

    client = new Client options
    job = client.submitJob 'test_fail'
    job.on 'fail', (handle) ->
      worker.disconnect()
      client.disconnect()
      done()

  it 'allows for worker failure with warning message', (done) ->
    @timeout 10000
    worker = new Worker 'test_fail_message', (payload, worker) ->
      worker.warning('heyo')
      worker.error()
    , options

    client = new Client options
    job = client.submitJob 'test_fail_message'
    job.on 'warning', (handle, warning) ->
      assert.equal warning, 'heyo'
    job.on 'fail', (handle) ->
      worker.disconnect()
      client.disconnect()
      done()

  it 'allows for worker failure with warning message 2', (done) ->
    @timeout 10000
    worker = new Worker 'test_fail_message2', (payload, worker) ->
      worker.error('heyo')
    , options

    client = new Client options
    job = client.submitJob 'test_fail_message2'
    job.on 'warning', (handle, warning) ->
      assert.equal warning, 'heyo'
    job.on 'fail', (handle) ->
      worker.disconnect()
      client.disconnect()
      done()

  it 'allows for worker success with warning message', (done) ->
    @timeout 10000
    worker = new Worker 'test_complete_warning', (payload, worker) ->
      worker.warning 'WARN!!'
      worker.complete 'completion data'
    , options

    client = new Client options
    job = client.submitJob 'test_complete_warning'
    job.on 'warning', (handle, warning) ->
      assert.equal warning, 'WARN!!', "bad warning message"
    job.on 'complete', (handle, data) ->
      assert.equal data, 'completion data', "bad job data on completion"
      done()

  it 'allows for worker pre-completion messages: data and status', (done) ->
    @timeout 10000
    data_msgs = ['started','halfway','done']
    status_msgs = [[0,100],[50,100],[100,100]]
    worker = new Worker 'test_data_status', (payload, worker) ->
      async.forEachSeries [0,1,2], (i, cb_fe) ->
        worker.data data_msgs[i]
        worker.status status_msgs[i][0], status_msgs[i][1]
        setTimeout cb_fe, 1000
      , () ->
        worker.complete 'completion data'
    , options

    client = new Client options
    job = client.submitJob 'test_data_status'
    data_i = 0
    status_i = 0
    job.on 'data', (handle, data) ->
      assert.equal data, data_msgs[data_i], "data message didn't match"
      data_i += 1
    job.on 'status', (handle, num, den) ->
      assert.deepEqual [num,den], status_msgs[status_i], "status message didn't match"
      status_i += 1
    job.on 'complete', (handle, data) ->
      assert.equal data, 'completion data', "bad job data on completion"
      done()

  it 'worker.done is worker.error if sent an argument', (done) ->
    @timeout 10000
    worker = new Worker 'test_done_error', (payload, worker) ->
      worker.done 'error'
    , options

    client = new Client options
    job = client.submitJob 'test_done_error'
    warning = null
    job.on 'warning', (handle, _warning) ->
      warning = _warning
    job.on 'fail', (handle, data) ->
      assert.equal warning, 'error', "bad warning message"
      done()

  it 'worker.done is worker.complete if no argument sent', (done) ->
    @timeout 10000
    worker = new Worker 'test_done_complete', (payload, worker) ->
      worker.done()
    , options

    client = new Client options
    job = client.submitJob 'test_done_complete'
    warning = null
    job.on 'warning', (handle, _warning) ->
      warning = _warning
    job.on 'complete', (handle, data) ->
      assert.equal warning, null, "should not have gotten a  warning"
      done()

  it 'completes the task it was working on when sent a shutdown', (done) ->
    @timeout 10000
    client = new Client options
    job1 = client.submitJob 'test_shutdown_completion', 1
    job2 = client.submitJob 'test_shutdown_completion', 2
    job1.on 'warning', (handle, warning) -> assert false, 'should not warn'
    job2.on 'warning', (handle, warning) -> assert false, 'should not warn'
    async.series [
      (cb) ->
        job1.on 'complete', (handle, data) -> cb()
        new Worker 'test_shutdown_completion', (payload, worker) ->
          # shutdown should only be called after done() once
          worker.parent.shutdown( ->
            console.warn "shutting down"
            cb new Error("called shutdown method before done called") if worker.parent.work_in_progress
          )
          assert.equal payload, 1, 'first worker should only have the chance to work on first job'
          setTimeout (-> worker.done()), 2000 # more than the timeout for re-checking done-ness
        , options
      (cb) ->
        console.warn 'starting second worker'
        new Worker 'test_shutdown_completion', (payload, worker) ->
          assert.equal payload, 2, 'second job should have second payload'
          cb()
        , options
    ], (err) ->
      assert.equal err, null, "should not have given error: #{err}"
      done()

  it 'completes err when sent a shutdown', (done) ->
    @timeout 10000
    client = new Client options
    job1 = client.submitJob 'test_err_shutdown_completion', 1
    job2 = client.submitJob 'test_err_shutdown_completion', 2
    job1.on 'complete', (handle, warning) -> assert false, 'should not complete'
    job2.on 'warning', (handle, warning) -> assert false, 'should not warn'
    async.series [
      (cb) ->
        job1.on 'warning', (handle, data) -> cb()
        new Worker 'test_err_shutdown_completion', (payload, worker) ->
          worker.parent.shutdown( ->
            console.warn 'err shutting down'
            cb new Error("called shutdown method before done called") if worker.parent.work_in_progress
          )
          assert.equal payload, 1, 'first worker should only have the chance to work on first job'
          setTimeout (-> worker.done("Worker Error")), 2000 # more than the timeout for re-checking done-ness
        , options
      (cb) ->
        console.warn 'starting second worker'
        job2.on 'complete', (handle, data) -> cb()
        new Worker 'test_err_shutdown_completion', (payload, worker) ->
          assert.equal payload, 2, 'second job should have second payload'
          worker.done()
        , options
    ], (err) ->
      assert.equal err, null, "should not have given error: #{err}"
      done()

  it 'still exits if not working on a job when sent a shutdown', (done) ->
    @timeout 10000
    async.series [ (cb) ->
      w = new Worker 'test_shutdown_no_job', (payload, worker) ->
        worker.parent
        assert.fail 'job should not have run!'
      , options
      # must wait for worker to connect first
      setTimeout (-> w.shutdown -> cb()), 500
    ], (err) ->
      assert.equal err, null, "should not have given error: #{err}"
      done()

# describe 'worker timeout', ->
#   it 'timeout happens before job complete', (done)->
#     @timeout 10000
#     worker = new Worker 'test_1s_timeout', (payload, worker) ->
#       setTimeout () ->
#         worker.complete()
#       , 3000
#     , _.extend options, timeout: 1000

#     client = new Client options
#     job = client.submitJob 'test_1s_timeout'
#     job.on 'complete', (handle, data) ->
#       assert false, 'job should timeout'
#     job.on 'fail', (handle) ->
#       worker.disconnect()
#       client.disconnect()
#       done()
