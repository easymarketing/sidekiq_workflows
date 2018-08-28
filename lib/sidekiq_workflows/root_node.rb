require 'sidekiq_workflows/node'

module SidekiqWorkflows
  class RootNode
    include Node

    attr_accessor :workflow_uuid, :on_partial_complete
    attr_reader :children

    def initialize(workflow_uuid: nil, on_partial_complete: nil)
      @workflow_uuid = workflow_uuid
      @on_partial_complete = on_partial_complete
      @children = []
    end

    def to_h
      {
        workflow_uuid: workflow_uuid,
        on_partial_complete: on_partial_complete,
        children: @children.map(&:to_h)
      }
    end
  end
end
