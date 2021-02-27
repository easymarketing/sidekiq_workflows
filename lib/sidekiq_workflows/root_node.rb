require 'sidekiq_workflows/node'

module SidekiqWorkflows
  class RootNode
    include Node

    attr_accessor :workflow_uuid, :on_partial_success
    attr_reader :children

    def initialize(workflow_uuid: nil, on_partial_success: nil)
      @workflow_uuid = workflow_uuid
      @on_partial_success = on_partial_success
      @children = []
    end

    def to_h
      {
        workflow_uuid: workflow_uuid,
        on_partial_success: on_partial_success,
        children: @children.map(&:to_h)
      }
    end
  end
end
