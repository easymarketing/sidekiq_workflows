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

    def perform_group(workers)
      filtered_workers = workers.reject { |w| skip_workers.include?(w[:worker]) }
      return self if filtered_workers.empty?
      child = @node.add_group(filtered_workers)
      Builder.new(child, skip_workers)
    end

    def then(&block)
      instance_eval(&block)
    end
  end

end
