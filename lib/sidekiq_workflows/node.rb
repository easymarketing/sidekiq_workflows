module SidekiqWorkflows
  module Node
    def add_child(worker, *payload, with_delay: nil)
      @children << (child = WorkerNode.new(worker: worker, workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete, delay: with_delay, payload: payload, parent: self))
      child
    end

    def add_group(workers)
      @children << (child = GroupNode.new(workers: workers, workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete, parent: self))
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
