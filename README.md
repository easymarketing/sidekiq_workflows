# sidekiq_workflows [ ![Codeship Status for easymarketing/sidekiq_workflows](https://app.codeship.com/projects/e91d8f00-8cc8-0136-51c6-2a99a1cc69dd/status?branch=master)](https://app.codeship.com/projects/303519)

Sidekiq extension providing a workflow API on top of Sidekiq Pro's batches. To use this gem, you need a [Sidekiq Pro](https://sidekiq.org/products/pro.html) license, and provide the credentials to the `gems.contribsys.com` repository via bundler:

`bundle config gems.contribsys.com username:password`

or alternatively `export BUNDLE_GEMS__CONTRIBSYS__COM=username:password`

# Rationale

While Sidekiq Pro's batches are powerful, only a rather low level API is provided to work with them. Take this example:

https://github.com/mperham/sidekiq/wiki/Really-Complex-Workflows-with-Batches

This is a lot of complex code scattered in various callbacks to enable a straightforward workflow. It is easy making mistakes when writing such code, and it's also hard to debug. This gem provides an API to define a workflow in a single place, abstracting the Batch API away.

# Usage
```
require 'sidekiq_workflows'
```
## Defining a workflow

A workflow consists of Sidekiq workers which can execute in parallel. On successful completion (*all workers within a group have completed without raising an exception*), a follow-up group of workers can be launched. If a worker within a group raises an exception, the follow-up group will not be started. Retries are currently not supported, please make sure that the Sidekiq workers being used have **retries disabled** (`sidekiq_options retry: false`).

```
class A; include Sidekiq::Worker; def perform(x); end; end
class B; include Sidekiq::Worker; def perform(x, y); end; end
class C; include Sidekiq::Worker; def perform(x, y, z); end; end
class D; include Sidekiq::Worker; def perform; end; end

workflow = SidekiqWorkflows.build do
  perform(A, 'first param to perform')
  perform(B, 'first', 'second').then do
    perform(C, 'first', 'second', 'third')
    perform(D)
  end
end
```

`A` and `B` run in parallel. As soon as `B` completes successfully, `C` and `D` will be launched, running in parallel as well.

### Additional parameters

`SidekiqWorkflows.build` can take some additional parameters:

* `workflow_uuid`: To identify this workflow instance, you may want to provide an ID.
* `except`: An array of worker classes to be entirely skipped in this workflow instance.
* `on_partial_complete`: A callback that is being called whenever a group of workers within the workflow has completed (successfully or not). Modifying the example above: 

```
class WorkflowCallbacks; def on_partial_complete(status, options); end; end

workflow = SidekiqWorkflows.build(on_partial_complete: 'WorkflowCallbacks#on_partial_complete') do
  ...
end
```

This is especially useful if you want to report progress of the workflow to a client (for example, send a notification). The callback can also be used to verify sucess or failure. When using the example above, the callback will be called 4 times in total (for `A`, `B`, `C`, `D`). The `status` hash contains the `workflow_uuid` if present. For more details on `status` and `options`, see: https://github.com/mperham/sidekiq/wiki/Batches#callbacks

## Launching a workflow

Once defined, you can launch a workflow like this:

`batch_id = SidekiqWorkflows::Worker.perform_workflow(workflow)`

This method returns a Sidekiq Pro batch ID. This batch represents the workflow, and its status changes to `complete` when the workflow has completed.

### Additional parameters

`SidekiqWorkflows::Worker.perform_workflow` can take some additional parameters:

* `on_complete`: A callback that is being called once, when the workflow has completed.
* `on_complete_options`: A hash of key/value options which will be part of the `options` hash of the callback.

```
class WorkflowCallbacks; def on_complete(status, options); end; end

SidekiqWorkflows::Worker.perform_workflow(workflow, on_complete: 'WorkflowCallbacks#on_complete', on_complete_options: {stuff: 1})
```

If `workflow_uuid` has been passed into `SidekiqWorkflows.build`, it will also be present inside the `options` hash.

# Configuration

There is some additional configuration options.

```
SidekiqWorkflows.worker_queue = 'some_queue'
SidekiqWorkflows.callback_queue = 'another_queue'
```

`worker_queue` is the name of the Sidekiq queue which will be used for the gem's own meta worker. This worker usually has a execution time of only a few milliseconds, so you may want to use an appropriate queue for that.

`callback_queue` is the name of the Sidekiq queue which will be used for the `on_partial_complete` and `on_complete` callback workers.

If not specified, the `default` Sidekiq queue will be used.
