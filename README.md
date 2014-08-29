# gearman-node

**gearman-node** is an implementation of the Gearman protocol in CoffeeScript. It exposes a conventional Node library for creating Gearman workers and clients, and listening for events related to both. It aims to be a very a lightweight wrapper around the protocol itself.

## Installation

```
npm install gearman-node
```

## Workers

Workers are created with the name and function that they perform:

```javascript
var gearman = require('gearman-node');

var worker = new gearman.Worker('reverse', function(payload, worker) {
  var reversed;
  if (payload == null) {
    return worker.error('No payload');
  }
  reversed = payload.toString("utf-8").split('').reverse().join('');
  return worker.complete(reversed);
});
```

The worker function itself is passed an object that contains the following convenience methods:

 * `warning(warning)`: sends a 'WORK_WARNING' packet
 * `status(num,den)`: sends a 'WORK_STATUS' packet
 * `data(data)`: sends a 'WORK_DATA' packet
 * `error([warning])`: sends an optional 'WORK_WARNING' before 'WORK_FAIL'
 * `complete([data])`: sends an optional 'WORK_DATA' before 'WORK_COMPLETE'
 * `done([warning])`: calls `error` if warning passed, otherwise `complete`

The exact meaning of these is best documented on the Gearman website itself: [http://gearman.org/protocol/](http://gearman.org/protocol/).

Workers optionally take a hash of options. These options control the Gearman server connection settings as well as debug output and retry behavior:

```javascript
var gearman = require('gearman-node');
var default_options, worker;

default_options = {
  host: 'localhost',
  port: 4730,
  debug: false,
  max_retries: 0
};

worker = new gearman.Worker('unstable', function(payload, worker) {
  if (Math.random() < 0.5) {
    return worker.error();
  }
  return worker.done();
}, default_options);
```

## Clients

Clients are used to submit work to Gearman. By default they connect to Gearman at `localhost:4730`:

```javascript
var gearman = require('gearman-node');
var client, default_options;

default_options = {
  host: 'localhost',
  port: 4730,
  debug: false
};

client = new gearman.Client(default_options);
```

The `submitJob` method of the client takes in the name of the worker and the workload you'd like to send. It returns an EventEmitter that relays Gearman server notifications:

```javascript
client.submitJob('reverse', 'kitteh')
  .on('created', function(handle) { ... });           // JOB_CREATED
  .on('data', function(handle, data) { ... });        // WORK_DATA
  .on('warning', function(handle, warning) { ... });  // WORK_WARNING
  .on('status', function(handle, num, den) { ... });  // WORK_STATUS
  .on('complete', function(handle, data) { ... });    // WORK_COMPLETE
  .on('fail', function(handle) { ... });              // WORK_FAIL
```

## License

MIT
