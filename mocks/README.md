# Mocks

When testing software that depends on Gearman, it's useful to have objects that resemble the various
`gearman-coffee` classes.
Usually, if you're testing a Gearman worker, you'd like to avoid running a Gearman server and
instead give it a mock to communicate with.
If you're testing something that is a Gearman client, you'll want to mock out the response of
`client.submitJob` and the the side effects of that job.

## Usage

### MockWorkers

```coffee
{MockWorker} = require('gearman-coffee/mocks').Workers
worker = new MockWorker()
worker.on 'data', console.log
worker.on 'done', (err) -> console.log "GOT DONE WITH ERR", err
worker_function = (payload, worker) ->
  worker.data el for el in payload
  worker.done()
worker_function [0..1], worker
```

### MockClient/MockJobs

```coffee
assert        = require 'assert'
GearmanCoffee = require 'gearman-coffee'
GearmanMocks  = require 'gearman-coffee/mocks'
sinon         = require 'sinon'

{DataJob} = GearmanMocks.jobs
MockClient = GearmanMocks.client

client = new MockClient()
client_stub = sinon.stub GearmanCoffee, 'Client'
client_stub.returns client
client.intercept 'worker_name', new DataJob(['1', '2']), (payload) ->
  assert.deepEqual payload, expected_payload
```

Now you can run some function that internally creates a GearmanClient and submits a job to
'worker_name'.
When that happens, it's going to get back a job that emits two data events for '1' and '2' before
emitting a complete event.

## MockJobs
Mock jobs that you can pass to the `intercept` method of a `MockClient`.

### MockJob
Base class for mock jobs.

#### job.delayEmit(event, timeout, args...)
```coffee
job.delayEmit 'complete', 2000
job.delayEmit 'data', 2000, '1'
```

#### job.start()
Starts any timers registered via `job.delayEmit`

### CompleteJob extends MockJob
Mock job that emits a complete event after `timeout` time (default 500 ms).
```coffee
j = new CompleteJob()
j = new CompleteJob 1000
```

### DataJob extends CompleteJob
Mock job that emits `data` in evenly-spaced intervals over `timeout` time (default 500 ms), and then
completes.
```coffee
j = new DataJob ['1', '2']
j = new DataJob ['1', '2'], 1000
```

## MockClient

### client.intercept(worker_name, job, [assertions])
* `worker_name`: name of the worker to register this intercept for.
* `job`: MockJob to return for that intercept.
* `assertions`: optional function that is passed the payload when the job is submitted by the client
so that you can inspect it and make any assertions you would like about it
```coffee
client.intercept 'worker_name', new DataJob(['3', '4'])
client.intercept 'worker_name', new DataJob(['1', '2']), (payload) ->
  assert.deepEqual payload, expected_payload
```

### client.submitJob(worker_name, payload)
If there is an intercept registerd for `worker_name`, returns the first one.
Otherwise, throws an exception.

## MockWorkers

### MockWorker
Base class for mock workers. Emits any methods called on it as events.

#### worker.received
A map from method name (`warning`, `status`, `data`, `error`, `complete`, `done`) to an array of the
arguments that that method was called with, one for each time that method was called on the worker.

### DoneWorker extends MockWorker
A mock worker that expects only the `done` method to be called.
The constructor takes a function that is passed the arguments to done.

### SuccessWorker extends DoneWorker
A mock worker that expects only the `done` method to be called, without an error.
The constructor takes a function that is passed the arguments to done.

### ErrorWorker extends DoneWorker
A mock worker that expects only the `done` method to be called, with an error.
The constructor takes a function that is passed the error argument.

### DataWorker extends MockWorker
A mock worker that expects only the `data` and the `done` methods to be called, without an error.
The constructor takes in a function that is passed `null` and an array of all of the arguments to
the `data` function.
