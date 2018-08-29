require 'sidekiq_workflows/node'

module SidekiqWorkflows
  class Builder
    attr_reader :node, :skip_workers

    def initialize(node, skip_workers = [])
      @node = node
      @skip_workers = skip_workers
    end

    def perform(workers, *args, delay: nil)
      workers = [worker: workers, payload: args, delay: delay] unless workers.is_a?(Array)
      workers.reject! { |w| skip_workers.include?(w[:worker]) }
      return self if workers.empty?

      child = @node.add_group(workers)
      Builder.new(child, skip_workers)
    end

    def then(&block)
      instance_eval(&block)
    end
  end

end
