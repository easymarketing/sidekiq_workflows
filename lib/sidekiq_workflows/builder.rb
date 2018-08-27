require 'sidekiq_workflows/node'

module SidekiqWorkflows
  class Builder
    attr_reader :node, :skip_workers

    def initialize(node, skip_workers = [])
      @node = node
      @skip_workers = skip_workers
    end

    def perform(worker, *payload, with_delay: nil)
      return self if skip_workers.include?(worker)
      child = @node.add_child(worker, *payload, with_delay: with_delay)
      Builder.new(child, skip_workers)
    end

    def then(&block)
      instance_eval(&block)
    end
  end

  def self.build(workflow_uuid: nil, on_partial_complete: nil, except: [], &block)
    root = Node.root(workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete)
    Builder.new(root, except).then(&block)
    root
  end
end
