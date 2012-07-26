###

Supported Client Requests
----------------
SUBMIT_JOB
SUBMIT_JOB_LOW
SUBMIT_JOB_HIGH

    A client issues one of these when a job needs to be run. The
    server will then assign a job handle and respond with a JOB_CREATED
    packet.

    If on of the BG versions is used, the client is not updated with
    status or notified when the job has completed (it is detached).

    The Gearman job server queue is implemented with three levels:
    normal, high, and low. Jobs submitted with one of the HIGH versions
    always take precedence, and jobs submitted with the normal versions
    take precedence over the LOW versions.

    Arguments:
    - NULL byte terminated function name.
    - NULL byte terminated unique ID.
    - Opaque data that is given to the function as an argument.

GET_STATUS (TODO)

    A client issues this to get status information for a submitted job.

    Arguments:
    - Job handle that was given in JOB_CREATED packet.


    A client issues this to set an option for the connection in the
    job server. Returns a OPTION_RES packet on success, or an ERROR
    packet on failure.

Unsupported client requests:
SUBMIT_JOB_BG
SUBMIT_JOB_LOW_BG
SUBMIT_JOB_HIGH_BG
SUBMIT_JOB_SCHED ("not used")
SUBMIT_JOB_EPOCH ("not used")
OPTION_REQ

Supported Responses to Client
----------------
JOB_CREATED

    This is sent in response to one of the SUBMIT_JOB* packets. It
    signifies to the client that a the server successfully received
    the job and queued it to be run by a worker.

    Arguments:
    - Job handle assigned by server.

WORK_DATA, WORK_WARNING, WORK_STATUS, WORK_COMPLETE, WORK_FAIL

    For non-background jobs, the server forwards these packets from
    the worker to clients. See "Worker Requests" for more information
    and arguments.

STATUS_RES (TODO)

    This is sent in response to a GET_STATUS request. This is used by
    clients that have submitted a job with SUBMIT_JOB_BG to see if the
    job has been completed, and if not, to get the percentage complete.

    Arguments:
    - NULL byte terminated job handle.
    - NULL byte terminated known status, this is 0 (false) or 1 (true).
    - NULL byte terminated running status, this is 0 (false) or 1
      (true).
    - NULL byte terminated percent complete numerator.
    - Percent complete denominator.

Unsupported responses to client:
WORK_EXCEPTION (deprecated)
OPTION_RES
###

# usage:
#
# client = new Client
# job = client.submitJob 'reverse', 'kitteh'
# job.on 'created', (handle) -> ...
# job.on 'data', (handle, data) -> ...
# job.on 'status', (handle, numerator, denominator) -> ...
# job.on 'complete', (handle, data) -> ...
# job.on 'warning', (handle, warning) -> ...
# job.on 'fail', (handle) ->

Gearman = require './gearman'
_ = require 'underscore'
EventEmitter = require("events").EventEmitter

class Client extends Gearman
  constructor: (@options) ->
    @options = _.defaults (@options or {}),
      host: 'localhost'
      port: 4730
      debug: false
    super @options.host, @options.port, @options.debug
    @jobs = {} # map from job handle to emitter returned to user of this class
    @on 'WORK_DATA',     (handle, data)     => @jobs[handle].emit 'data', handle, "#{data}"
    @on 'WORK_WARNING',  (handle, warning)  => @jobs[handle].emit 'warning', handle, "#{warning}"
    @on 'WORK_STATUS',   (handle, num, den) => @jobs[handle].emit 'status', handle, num, den
    @on 'WORK_COMPLETE', (handle, data) =>
      @jobs[handle].emit 'complete', handle, data
      delete @jobs[handle]
    @on 'WORK_FAIL', (handle) =>
      @jobs[handle].emit 'fail', handle
      delete @jobs[handle]
    @connect()

  submitJob: (name, payload) ->
    job = new EventEmitter
    @on 'JOB_CREATED', (handle) =>
      @jobs[handle] = job
      job.emit 'created', handle
    @sendCommand "SUBMIT_JOB", name, false, payload
    job

module.exports = Client
