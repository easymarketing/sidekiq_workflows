require 'active_support/inflector'

module SidekiqWorkflows
  class Node
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

    def add_child(worker, *payload, with_delay: nil)
      @children << (child = Node.new(worker: worker, workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete, delay: with_delay, payload: payload, parent: self))
      child
    end

    def to_h
      hash = {
        workflow_uuid: workflow_uuid,
        on_partial_complete: on_partial_complete,
        delay: delay,
        children: @children.map(&:to_h)
      }

      hash.merge!(
        worker: @worker.name,
        payload: @payload
      ) unless @worker.nil?

      hash
    end

    def serialize
      to_h.to_json
    end

    def all_nodes
      [self] + children.flat_map(&:all_nodes)
    end

    def self.root(workflow_uuid: nil, on_partial_complete: nil)
      new(worker: nil, workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete, payload: nil, parent: nil)
    end
  end

  def self.deserialize(string)
    from_h(JSON.parse(string, symbolize_names: true))
  end

  def self.from_h(hash, parent = nil)
    parent ||= Node.new(worker: hash[:worker], workflow_uuid: hash[:workflow_uuid], on_partial_complete: hash[:on_partial_complete], delay: hash[:delay], payload: hash[:payload] || [], parent: nil)
    hash[:children].each do |h|
      child = parent.add_child(h[:worker], *h[:payload], with_delay: h[:delay])
      from_h(h, child)
    end
    parent
  end
end
