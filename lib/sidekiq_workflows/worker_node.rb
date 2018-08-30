require 'sidekiq_workflows/node'
require 'active_support/inflector'

module SidekiqWorkflows
  class WorkerNode
    include Node

    attr_accessor :workers, :workflow_uuid, :on_partial_complete
    attr_reader :children
    attr_reader :parent

    def initialize(workers:, workflow_uuid: nil, on_partial_complete: nil, parent: nil)
      @workers = workers.each do |entry|
        entry[:worker] = ActiveSupport::Inflector.constantize(entry[:worker]) if entry[:worker].is_a?(String)
        entry[:delay] = entry[:delay].to_i if entry[:delay]
      end
      @workflow_uuid = workflow_uuid
      @on_partial_complete = on_partial_complete
      @parent = parent
      @children = []
    end

    def to_h
      {
        workers: workers.map do |entry|
          {
            worker: entry[:worker].name,
            payload: entry[:payload],
            delay: entry[:delay]
          }
        end,
        workflow_uuid: workflow_uuid,
        on_partial_complete: on_partial_complete,
        children: @children.map(&:to_h)
      }
    end
  end
end
