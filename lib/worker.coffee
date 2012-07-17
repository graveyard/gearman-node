Gearman::Worker = (gearman, handle, name, payload) ->
  Stream.call this
  @gearman = gearman
  @handle = handle
  @name = name
  @payload = payload
  @finished = false
  @writable = true

utillib.inherits Gearman::Worker, Stream
Gearman::Worker::write = (data) ->
  return  if @finished
  @gearman.sendCommand "WORK_DATA", @handle, data

Gearman::Worker::end = (data) ->
  return  if @finished
  @finished = true
  @gearman.sendCommand "WORK_COMPLETE", @handle, data
  delete @gearman.currentWorkers[@handle]

  @gearman.sendCommand "GRAB_JOB"

Gearman::Worker::error = (error) ->
  return  if @finished
  @finished = true
  @gearman.sendCommand "WORK_FAIL", @handle
  delete @gearman.currentWorkers[@handle]

  @gearman.sendCommand "GRAB_JOB"
