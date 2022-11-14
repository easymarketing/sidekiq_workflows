module SidekiqWorkflows
  module Testing
    class InlineBatches
      class ProcessBatchWorkersInline
        attr_reader :processed, :context, :workflows

        def initialize(workflows)
          @workflows = workflows
          @processed = []
        end

        def call
          workflows[:children].each { |workers| process(workers) }
        end

        def process(workers)
          return if workers[:workers].blank?

          workers[:workers].each do |hash|
            worker_klass = hash[:worker].constantize.new
            worker_klass.perform(*hash[:payload])
            processed << worker_klass
          end
          workers[:children].each { |worker| process(worker) }
        end
      end

      # rubocop:disable Lint/UnusedMethodArgument
      # wee need to have the same kwaargs as original SidekiqWorkflows
      def self.perform_workflow(workflow, on_success: nil, on_success_options: {}, on_death: nil, on_death_options: {})
        processor = ProcessBatchWorkersInline.new(workflow.to_h)
        processor.call

        return unless on_success
        on_success.split("#")[0].constantize.send(
          on_success.split("#")[1], ::OpenStruct.new(bid: "whatever"), on_success_options
        )
        #TODO: add more callbacks support
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end

  def self.with_testing_batches_inline
    Sidekiq::Testing.inline! do
      old_worker_class = SidekiqWorkflows::Worker
      SidekiqWorkflows.send(:remove_const, :Worker)
      SidekiqWorkflows.const_set(:Worker, SidekiqWorkflows::Testing::InlineBatches)
      yield
      SidekiqWorkflows.send(:remove_const, :Worker)
      SidekiqWorkflows.const_set(:Worker, old_worker_class)
    end
  end
end


# For rspec configure below:
#   require 'rspec/core'
#   RSpec.configure do |config|
#     config.around(:each, sidekiq_batches_inline: true) do |example|
#       Sidekiq::Testing.__set_test_mode(:batches_inline) do
#         old_worker_class = SidekiqWorkflows::Worker
#         SidekiqWorkflows.send(:remove_const, :Worker)
#         SidekiqWorkflows.const_set(:Worker, SidekiqWorkflows::Testing::InlineBatches::Worker)
#         example.run
#         SidekiqWorkflows.send(:remove_const, :Worker)
#         SidekiqWorkflows.const_set(:Worker, old_worker_class)
#       end
#     end
#   end
