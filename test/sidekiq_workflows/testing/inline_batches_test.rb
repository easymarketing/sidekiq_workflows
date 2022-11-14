require_relative '../../test_helper'

describe SidekiqWorkflows::Testing::InlineBatches do
  class FooWorker
    include Sidekiq::Worker

    def perform
      $logger << self.class.to_s
    end
  end

  class BazWorker
    include Sidekiq::Worker

    def perform
      $logger << self.class.to_s
    end
  end

  class BadWorker
    include Sidekiq::Worker

    def perform
      $logger << self.class.to_s
    end
  end

  class FakeCallbacks
    def self.on_batch_success(status, options)
      $logger << "success: #{options[:id]}"
    end
  end

  let(:workflow_uuid) { SecureRandom.uuid }

  let(:example_workflow) do
    SidekiqWorkflows.build do
      perform(FooWorker).then do
        [
          perform(BazWorker),
          perform(BazWorker)
        ]
        .then do
          perform(BadWorker)
        end
      end
    end
  end

  it 'Runs all workers in batch and then callbacks' do
    $logger = []
    SidekiqWorkflows.with_testing_batches_inline do
      SidekiqWorkflows::Worker.perform_workflow(
          example_workflow,
          on_success: "FakeCallbacks#on_batch_success",
          on_success_options: { id: 42 },
        )
    end
    expect($logger).must_equal(["FooWorker", "BazWorker", "BazWorker", "BadWorker", "success: 42"])
    $logger = [] # TODO: think of a better testing not with global var
  end
end
