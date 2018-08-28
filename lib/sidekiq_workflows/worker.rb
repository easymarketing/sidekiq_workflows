require 'sidekiq_workflows/node'

module SidekiqWorkflows
  class Worker
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: SidekiqWorkflows.worker_queue || 'default'

    def perform(workflow)
      workflow = ensure_deserialized(workflow)

      case workflow.class
      when RootNode
        perform_children(batch, workflow)
      when GroupNode
        batch.jobs do
          child_batch = Sidekiq::Batch.new
          child_batch.callback_queue = SidekiqWorkflows.callback_queue unless SidekiqWorkflows.callback_queue.nil?
          child_batch.description = "Workflow #{workflow.workflow_uuid || '-'} with #{workflow.worker}"
          child_batch.on(:complete, 'SidekiqWorkflows::Worker#on_complete', workflow: workflow.serialize, workflow_uuid: workflow.workflow_uuid)
          child_batch.jobs do
            workflow.workers.each do |entry|
              if delay
                entry[:worker].perform_in(entry[:delay], *entry[:payload])
              else
                entry[:worker].perform_async(*entry[:payload])
              end
            end
          end
        end
      when WorkerNode
        batch.jobs do
          child_batch = Sidekiq::Batch.new
          child_batch.callback_queue = SidekiqWorkflows.callback_queue unless SidekiqWorkflows.callback_queue.nil?
          child_batch.description = "Workflow #{workflow.workflow_uuid || '-'} with #{workflow.worker}"
          child_batch.on(:complete, 'SidekiqWorkflows::Worker#on_complete', workflow: workflow.serialize, workflow_uuid: workflow.workflow_uuid)
          child_batch.jobs do
            if workflow.delay
              workflow.worker.perform_in(workflow.delay, *workflow.payload)
            else
              workflow.worker.perform_async(*workflow.payload)
            end
          end
        end
      end
    end

    def on_complete(status, options)
      workflow = ensure_deserialized(options['workflow'])

      if workflow.on_partial_complete
        klass, method = workflow.on_partial_complete.split('#')
        ActiveSupport::Inflector.constantize(klass).new.send(method, status, options)
      end

      perform_children(status.parent_batch, workflow) unless status.failures > 0
    end

    def self.perform_async(workflow, *args)
      super(workflow.serialize, *args)
    end

    def self.perform_workflow(workflow, on_complete: nil, on_complete_options: {})
      batch = Sidekiq::Batch.new
      batch.callback_queue = SidekiqWorkflows.callback_queue unless SidekiqWorkflows.callback_queue.nil?
      batch.description = "Workflow #{workflow.workflow_uuid || '-'} root batch"
      batch.on(:complete, on_complete, on_complete_options.merge(workflow_uuid: workflow.workflow_uuid)) if on_complete
      batch.jobs do
        perform_async(workflow)
      end
      batch.bid
    end

    private

    def perform_children(batch, workflow)
      batch.jobs do
        workflow.children.each do |child|
          self.class.perform_async(child)
        end
      end
    end

    def ensure_deserialized(workflow)
      workflow.is_a?(String) ? SidekiqWorkflows.deserialize(workflow) : workflow
    end
  end
end
