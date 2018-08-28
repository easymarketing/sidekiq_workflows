require 'active_support/inflector'
require 'sidekiq_workflows/node'

module SidekiqWorkflows
  class WorkerNode
    include Node

    attr_accessor :worker, :workflow_uuid, :on_partial_complete, :delay, :payload
    attr_reader :children
    attr_reader :parent

    def initialize(worker:, workflow_uuid: nil, on_partial_complete: nil, delay: nil, payload: [], parent:)
      @worker = worker.is_a?(String) ? ActiveSupport::Inflector.constantize(worker) : worker
      @workflow_uuid = workflow_uuid
      @on_partial_complete = on_partial_complete
      @delay = delay.to_i unless delay.nil?
      @payload = payload
      @parent = parent
      @children = []
    end

    def to_h
      {
        node_type: 'worker',
        worker: @worker.name,
        workflow_uuid: workflow_uuid,
        on_partial_complete: on_partial_complete,
        delay: delay,
        payload: @payload,
        children: @children.map(&:to_h)
      }
    end
  end
end
