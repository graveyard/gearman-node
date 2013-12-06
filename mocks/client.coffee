module.exports = class MockClient
  constructor: ->
    @registered_tasks = {}
  registerTask: (job_name, job, assertions=(->)) ->
    @registered_tasks[job_name] ?= []
    @registered_tasks[job_name].push {job, assertions}
  submitJob: (job_name, payload) ->
    task = @registered_tasks[job_name]?.shift()
    throw new Error "No job registered for #{job_name}" unless task
    task.assertions payload
    task.job.start()
