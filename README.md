# gearman-coffee

**gearman-coffee** is an implementation of the Gearman protocol in CoffeeScript. It exposes a conventional Node library for creating Gearman workers and clients, and listening for events related to both. It aims to be a very a lightweight wrapper around the protocol itself.

## Installation

```
npm install gearman-coffee
```

## Workers

Workers are created with the name and function that they perform:

```coffeescript
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

Workers optionally take a hash of options. These options control the Gearman server connection settings as well as debug output and retry behavior:

```coffeescript
default_options =
  host: 'localhost'
  port: 4730
  debug: false
  max_retries: 0
worker = new Worker 'unstable', (payload, worker) ->
  return worker.error() if Math.random() < 0.5
  worker.done 'success'
, default_options
```

## Clients

Clients are used to submit work to Gearman. By default they connect to Gearman at `localhost:4730`:

```coffeescript
default_options =
  host: 'localhost'
  port: 4730
  debug: false
client = new Client default_options
```

The `submitJob` method of the client takes in the name of the worker and the workload you'd like to send. It returns an EventEmitter that relays Gearman server notifications:

```coffeescript
client.submitJob('reverse', 'kitteh')
  .on 'created', (handle) ->          # JOB_CREATED
  .on 'data', (handle, data) ->       # WORK_DATA
  .on 'warning', (handle, warning) -> # WORK_WARNING
  .on 'status', (handle, num, den) -> # WORK_STATUS
  .on 'complete', (handle, data) ->   # WORK_COMPLETE
  .on 'fail', (handle) ->             # WORK_FAIL
```

## License

MIT