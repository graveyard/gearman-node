module.exports = class MockClient
  constructor: ->
    @to_intercept = {}
  intercept: (job_name, job, assertions=(->)) ->
    @to_intercept[job_name] ?= []
    @to_intercept[job_name].push {job, assertions}
  submitJob: (job_name, payload) ->
    task = @to_intercept[job_name]?.shift()
    throw new Error "No job registered for #{job_name}" unless task
    task.assertions payload
    task.job.start()
