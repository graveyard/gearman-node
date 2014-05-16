###

Supported Worker Requests
----------------

CAN_DO: sent to notify the server that the worker is able to
    perform the given function. The worker is then put on a list to be
    woken up whenever the job server receives a job for that function.

    Arguments:
    - Function name.

CAN_DO_TIMEOUT: same as CAN_DO, but with a timeout value on how long the job
     is allowed to run. After the timeout value, the job server will
     mark the job as failed and notify any listening clients.

     Arguments:
     - NULL byte terminated Function name.
     - Timeout value.

PRE_SLEEP: sent to notify the server that the worker is about to
    sleep, and that it should be woken up with a NOOP packet if a
    job comes in for a function the worker is able to perform.

GRAB_JOB: sent to the server to request any available jobs on the
    queue. The server will respond with either NO_JOB or JOB_ASSIGN,
    depending on whether a job is available.

WORK_DATA: sent to update the client with data from a running job. A
    worker should use this when it needs to send updates, send partial
    results, or flush data during long running jobs. It can also be
    used to break up a result so the worker does not need to buffer
    the entire result before sending in a WORK_COMPLETE packet.

    Arguments:
    - NULL byte terminated job handle.
    - Opaque data that is returned to the client.

WORK_WARNING: sent to update the client with a warning. It acts just
    like a WORK_DATA response, but should be treated as a warning
    instead of normal response data.

    Arguments:
    - NULL byte terminated job handle.
    - Opaque data that is returned to the client.

WORK_STATUS: sent to update the server (and any listening clients)
    of the status of a running job. The worker should send these
    periodically for long running jobs to update the percentage
    complete. The job server should store this information so a client
    who issued a background command may retrieve it later with a
    GET_STATUS request.

    Arguments:
    - NULL byte terminated job handle.
    - NULL byte terminated percent complete numerator.
    - Percent complete denominator.

WORK_COMPLETE: notifies the server (and any listening clients) that
    the job completed successfully.

    Arguments:
    - NULL byte terminated job handle.
    - Opaque data that is returned to the client as a response.

WORK_FAIL: notifies the server (and any listening clients) that
    the job failed.

    Arguments:
    - Job handle.

SET_CLIENT_ID: sets the worker ID in a job server so monitoring and reporting
    commands can uniquely identify the various workers, and different
    connections to job servers from the same worker.

    Arguments:
    - Unique string to identify the worker instance.

Unsupported worker requests:
CANT_DO
RESET_ABILITIES
GRAB_JOB_UNIQ
WORK_EXCEPTION (deprecated)
ALL_YOURS

Supported Responses to Worker
----------------
NOOP: used to wake up a sleeping worker so that it may grab a
    pending job.

    Arguments:
    - None.

NO_JOB: sent in response to a GRAB_JOB request to notify the
    worker there are no pending jobs that need to run.

    Arguments:
    - None.

JOB_ASSIGN: given in response to a GRAB_JOB request to give the worker
    information needed to run the job. All communication about the
    job (such as status updates and completion response) should use
    the handle, and the worker should run the given function with
    the argument.

    Arguments:
    - NULL byte terminated job handle.
    - NULL byte terminated function name.
    - Opaque data that is given to the function as an argument.

Unsupported responses:
JOB_ASSIGN_UNIQ

###

Gearman = require './gearman'
_ = require 'underscore'
async = require 'async'
EventEmitter = require("events").EventEmitter

class Worker extends Gearman
  constructor: (@name, @fn, @options) ->
    @work_in_progress = false
    @active = true
    @options = _.defaults (@options or {}),
      host: 'localhost'
      port: 4730
      debug: false
    super @options.host, @options.port, @options.debug
    if @options.timeout?
      @sendCommand 'CAN_DO_TIMEOUT', @name, @options.timeout
    else
      @sendCommand 'CAN_DO', @name
    @get_next_job()
    @on 'NO_JOB', => @sendCommand 'PRE_SLEEP' # will be woken up by noop
    @on 'NOOP', => @get_next_job()            # woken up!
    @on 'JOB_ASSIGN', @receiveJob.bind @
    @connect()

  shutdown: (done) =>
    @active = false
    # poll until the running job is complete and
    # all data is written to the socket
    async.whilst(
      => @socket.bufferSize > 0 and @work_in_progress
      (cb) -> setTimeout cb, 1000
      done
    )

  get_next_job: =>
    @sendCommand 'GRAB_JOB' if @active

  receiveJob: (handle, name, payload) =>
    @fn payload, new WorkerHelper(@,handle)

  # helper fns exposed to worker function
  class WorkerHelper extends EventEmitter
    constructor: (@parent, @handle) ->
      @parent.work_in_progress = true
    warning: (warning) => @parent.sendCommand 'WORK_WARNING', @handle, warning
    status: (num, den) => @parent.sendCommand 'WORK_STATUS', @handle, num, den
    data: (data)       => @parent.sendCommand 'WORK_DATA', @handle, data
    error: (warning) =>
      @warning warning if warning?
      @parent.sendCommand 'WORK_FAIL', @handle
      @parent.work_in_progress = false
      @parent.get_next_job()
    complete: (data) =>
      @parent.sendCommand 'WORK_COMPLETE', @handle, data
      @parent.work_in_progress = false
      @parent.get_next_job()
    done: (err) =>
      if err?
        @error(err)
      else
        @complete()

module.exports = Worker
