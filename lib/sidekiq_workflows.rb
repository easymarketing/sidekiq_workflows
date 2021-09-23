require 'json'
require 'sidekiq-pro'

module SidekiqWorkflows
  class << self
    attr_accessor :worker_queue
    attr_accessor :callback_queue
  end

  require 'sidekiq_workflows/node'
  require 'sidekiq_workflows/root_node'
  require 'sidekiq_workflows/worker_node'
  require 'sidekiq_workflows/builder'
  require 'sidekiq_workflows/worker'

  def self.deserialize(string)
    from_h(JSON.parse(string, symbolize_names: true))
  end

  def self.from_h(hash, parent = nil)
    parent ||= hash.key?(:workers) ? WorkerNode.new(workflow_uuid: hash[:workflow_uuid], on_partial_complete: hash[:on_partial_complete], workers: hash[:workers]) : RootNode.new(workflow_uuid: hash[:workflow_uuid], on_partial_complete: hash[:on_partial_complete])
    hash[:children].each do |h|
      child = parent.add_group(h[:workers])
      from_h(h, child)
    end
    parent
  end

  def self.build(workflow_uuid: nil, on_partial_complete: nil, except: [], &block)
    root = RootNode.new(workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete)
    Builder.new(root, except).then(&block)
    root
  end
end
