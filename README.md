gearman-coffee
==============

**gearman-coffee** is a rewrite of of **[node-gearman](https://github.com/andris9/node-gearman)** in CoffeeScript that adds additional administrative functions as well as more verbose error handling.

## Connect to a Gearman server

Set up connection data and create a new `Gearman` object

    Gearman = require "gearman-coffee"
    gearman = new Gearman hostname, port

Where `hostname` defaults to `"localhost"` and `port` to `4730`

This doesn't actually create the connection yet. Connection is created when needed but you can force it with `gearman.connect()`

    gearman = new Gearman hostname, port
    gearman.connect()

## Connection events

The following events can be listened for a `Gearman` object:

  * **connect** - when the connection has been successfully established to the server
  * **idle** - when there's no jobs available for workers
  * **close** - connection closed
  * **error** - an error occured. Connection is automatically closed.

Example:

    gearman = new Gearman hostname, port
    gearman.on "connect", () ->
        console.log "Connected to the server!"
    gearman.connect();

## Submit a job

Jobs can be submitted with `gearman.submitJob name, payload` where `name` is the name of the function and `payload` is a string or a Buffer. The returned object (Event Emitter) can be used to detect job status and has the following events:

  * **error** - if the job failed, has parameter error
  * **data** - contains a chunk of data as a Buffer
  * **end** - when the job has been completed, has no parameters
  * **timeout** - when the job has been canceled due to timeout

Example:

    gearman = new Gearman hostname, port
    job = gearman.submitJob "reverse", "test string"

    job.on "data", (data) ->
        console.log data.toString "utf-8" # gnirts tset

    job.on "end", () ->
        console.log "Job completed!"

    job.on "error", (err) ->
        console.log err.message

## Setup a worker

Workers can be set up with `gearman.registerWorker name, callback` where `name` is the name of the function and `callback` is the function to be run when a job is received.

Worker function `callback` gets two parameters - `payload` (received data as a Buffer) and `worker` which is a helper object to communicate with the server. `worker` object has following methods:

  * **write(data)** - for sending data chunks to the client
  * **end([data])** for completing the job
  * **error()** to indicate that the job failed

Example:

    gearman = new Gearman hostname, port

    gearman.registerWorker "reverse", (payload, worker) ->
        if not payload
          worker.error()
          return
        
        reversed = ((payload.toString "utf-8").split "").reverse().join ""
        worker.end reversed

## Job timeout

You can set an optional timeout value (in milliseconds) for a job to abort it automatically when the timeout occurs.

Timeout automatically aborts further processing of the job.

    job.setTimeout timeout[, timeoutCallback]

If `timeoutCallback` is not set, a `'timeout'` event is emitted on timeout.

    job.setTimeout 10*1000 # timeout in 10 secs
    job.on "timeout", () ->
        console.log "Timeout exceeded for the worker. Job aborted."

## Close connection

You can close the Gearman connection with `close()`

    gearman = new Gearman()
    ...
    gearman.close()

The connection is closed when a `'close'` event for the Gearman object is emitted

    gearman.on "close", () ->
        console.log "Connection closed"
    
    gearman.close()

## Streaming

Worker and job objects also act as Stream objects (workers are writable and jobs readable streams), so you can stream data with `pipe` from a worker to a client (but not the other way round). This is useful for zipping/unzipping etc.

**NB!** Streaming support is experimental, do not send very large files as the data tends to clutter up (workers stream interface lacks support for pausing etc.).

**Streaming worker**

    gearman.registerWorker "stream_file", (payload, worker) ->
        input = fs.createReadStream filepath
        # stream file to client
        input.pipe worker

**Streaming client**

    job = gearman.submitJob "stream", null
    output = fs.createWriteStream filepath
    
    # save incoming stream to file
    job.pipe output

## Run tests

Run the tests with

    npm test
    
or alternatively

    node run_tests.js
## License

**MIT**