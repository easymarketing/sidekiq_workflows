module SidekiqWorkflows
  class TestWorker
    include Sidekiq::Worker

    sidekiq_options retry: 1

    def perform(test_uuid, worker_name)
      raise StandardError if worker_name == 'ErrorWorker'

      Redis.new(url: 'redis://redis:6379').sadd(test_uuid, worker_name)
    end

    def on_success(status, options)
      Redis.new(url: 'redis://redis:6379').sadd(options['workflow_uuid'], 'success')
    end

    def on_death(status, options)
      Redis.new(url: 'redis://redis:6379').sadd(options['workflow_uuid'], 'death')
    end
  end
end
