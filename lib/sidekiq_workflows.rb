require 'json'
require 'sidekiq-pro'

module SidekiqWorkflows
  class << self
    attr_accessor :worker_queue
    attr_accessor :callback_queue
  end

  require 'sidekiq_workflows/node'
  require 'sidekiq_workflows/builder'
  require 'sidekiq_workflows/worker'
end
