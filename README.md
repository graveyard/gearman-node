# gearman-coffee

**gearman-coffee** is an implementation of the Gearman protocol in CoffeeScript. It exposes a conventional Node library for creating Gearman workers and clients, and listening for events related to both. It aims to be a very a lightweight wrapper around the protocol itself.

## Workers

Workers are created with the name and function that they perform:

```coffeescript
Worker = require('gearman-coffee').Worker
worker = new Worker 'reverse', (payload, worker) ->
  return worker.error "No payload" if not payload?
  reversed = ((payload.toString "utf-8").split "").reverse().join ""
  worker.complete reversed
```

The worker function itself is passed an object that contains the following convenience methods:

 * `warning(warning)`: sends a 'WORK_WARNING' packet
 * `status(num,den)`: sends a 'WORK_STATUS' packet
 * `data(data)`: sends a 'WORK_DATA' packet
 * `error([warning])`: sends an optional 'WORK_WARNING' before 'WORK_FAIL'
 * `complete([data])`: sends an optional 'WORK_DATA' before 'WORK_COMPLETE'
 * `done([warning])`: calls `error` if warning passed, otherwise `complete`

The exact meaning of these is best documented on the Gearman website itself: [http://gearman.org/index.php?id=protocol](http://gearman.org/index.php?id=protocol).

Workers optionally take in options related to the server to connect to and whether to produce debug output:

```coffeescript
Worker = require('gearman-coffee').Worker
default_options = { host: 'localhost', port: 4730, debug: false }
worker = new Worker 'unstable', (payload, worker) ->
  return worker.done('error') if Math.random() < 0.5
  worker.done()
, default_options
```

## Clients

Clients are used to submit work to Gearman. By default they connect to Gearman at `localhost:4730`:

```coffeescript
Worker = require('gearman-coffee').Client
default_options = { host: 'localhost', port: 4730, debug: false }
client = new Client default_options
```

The `submit` method of the client takes in the name of the worker and the workload you'd like to send. It returns an EventEmitter that relays Gearman server notifications:

```coffeescript
job = client.submit 'reverse', 'kitteh'
job.on 'created', (handle) ->          # JOB_CREATED
job.on 'data', (handle, data) ->       # WORK_DATA
job.on 'warning', (handle, warning) -> # WORK_WARNING
job.on 'status', (handle, num, den) -> # WORK_STATUS
job.on 'complete', (handle, data) ->   # WORK_COMPLETE
job.on 'fail', (handle) ->             # WORK_FAIL
```

## One-level deeper

The Worker and Client objects are built on top of a `Gearman` class that exposes a node-like interface for doing raw sending/receiving of commands to/from gearmand. There is a 'send' method for communicating to gearmand, and events are emitted when gearmand responds.

```coffeescript
Gearman = require('gearman-coffee').Gearman
default_options = { host: 'localhost', port: 4730, debug: false }
gearman = new Gearman default_options
gearman.connect()
gearman.send 'SUBMIT_JOB', 'reverse', job_id, 'kitteh'
gearman.on 'JOB_CREATED', (job_handle) -> ...
```

## Not deep enough?

If you want to do raw packet encoding/decoding in the Gearman protocol format there's also a `Protocol` class. One use case would be proxying gearmand in order to "sniff" packets going to/from gearmand:

```coffeescript
net = require 'net'
Protocol = require('gearman-coffee').Protocol

server = new net.Server()
server.on 'connection', (ib_conn) ->
  # sniff + proxy gearman responses
  ob_decoder = new Protocol().decode
  ob_decoder.on 'WORK_COMPLETE', (handle, data) -> console.log 'done with job!'
  ob_conn = net.connect { host: 'localhost', port: 4730 }
  ob_conn.on 'data', protocol.decode
  ob_conn.on 'data', (data) ->
    ib_conn.write data # relay gearman data back to inbound

  # sniff + proxy gearman requests
  ib_decoder = new Protocol().decode
  ib_decoder.on 'SUBMIT_JOB', (name, id, data) -> console.log 'someone is submitting a job!'
  ib_conn.on 'data', ib_decoder
  ib_conn.on 'data', (data) ->
    ob_conn.write data # relay inbound data to gearman

server.listen proxy_port
```

This could be useful for getting more information than what the Gearman admin protocol provides, or even extending the Gearman protocol itself.

## License

MIT
