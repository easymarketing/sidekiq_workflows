require 'sidekiq_workflows/node'

module SidekiqWorkflows
  class Worker
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(workflow)
      workflow = ensure_deserialized(workflow)

      case workflow.class.name
      when 'SidekiqWorkflows::RootNode'
        perform_children(batch, workflow)
      when 'SidekiqWorkflows::WorkerNode'
        batch.jobs do
          child_batch = Sidekiq::Batch.new
          child_batch.callback_queue = SidekiqWorkflows.callback_queue unless SidekiqWorkflows.callback_queue.nil?
          child_batch.description = "Workflow #{workflow.workflow_uuid || '-'}"
          child_batch.on(:success, 'SidekiqWorkflows::Worker#on_success', workflow: workflow.serialize, workflow_uuid: workflow.workflow_uuid)
          child_batch.jobs do
            workflow.workers.each do |entry|
              if entry[:delay]
                entry[:worker].perform_in(entry[:delay], *entry[:payload])
              else
                entry[:worker].perform_async(*entry[:payload])
              end
            end
          end
        end
      end
    end

    def on_success(status, options)
      workflow = ensure_deserialized(options['workflow'])

      if workflow.on_partial_success
        klass, method = workflow.on_partial_success.split('#')
        ActiveSupport::Inflector.constantize(klass).new.send(method, status, options)
      end

      perform_children(status.parent_batch, workflow)
    end

    def self.perform_async(workflow, *args)
      set(queue: worker_queue).send(:perform_async, workflow.serialize, *args)
    end

    def self.perform_workflow(workflow, on_success: nil, on_success_options: {}, on_death: nil, on_death_options: {})
      batch = Sidekiq::Batch.new
      batch.callback_queue = SidekiqWorkflows.callback_queue unless SidekiqWorkflows.callback_queue.nil?
      batch.description = "Workflow #{workflow.workflow_uuid || '-'} root batch"
      batch.on(:success, on_success, on_success_options.merge(workflow_uuid: workflow.workflow_uuid)) if on_success
      batch.on(:death, on_death, on_death_options.merge(workflow_uuid: workflow.workflow_uuid)) if on_death

      yield batch if block_given?

      batch.jobs do
        perform_async(workflow)
      end

      batch.bid
    end

    private

    def self.worker_queue
      SidekiqWorkflows.worker_queue || Sidekiq.default_worker_options['queue']
    end

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
