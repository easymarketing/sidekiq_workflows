module SidekiqWorkflows
  class TestWorker
    include Sidekiq::Worker

    def perform(test_uuid, worker_name)
      Redis.new(url: 'redis://redis:6379').sadd(test_uuid, worker_name)
    end
  end
end
