module SidekiqWorkflows
  module Node
    def add_group(workers)
      @children << (child = WorkerNode.new(workers: workers, workflow_uuid: workflow_uuid, on_partial_success: on_partial_success, parent: self))
      child
    end

    def serialize
      to_h.to_json
    end

    def all_nodes
      [self] + children.flat_map(&:all_nodes)
    end
  end
end
