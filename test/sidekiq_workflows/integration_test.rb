require_relative '../test_helper'
require_relative './worker'
require 'set'

describe SidekiqWorkflows::Worker do
  describe 'build' do

    it 'should run a workflow tree and write some results to redis' do
      Sidekiq::Testing.disable! do
        workflow_uuid = SecureRandom.uuid
        workflow = SidekiqWorkflows.build(workflow_uuid: workflow_uuid) do
          perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerOne - level 1').then do
            perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerThree - level 2')
          end

          perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerTwo - level 1').then do
            perform([
              {worker: SidekiqWorkflows::TestWorker, payload: [workflow_uuid, 'WorkerFour - level 2'], delay: 30},
              {worker: SidekiqWorkflows::TestWorker, payload: [workflow_uuid, 'WorkerFive - level 2']}
            ]).then do
              perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerSix - level 3')
            end
          end
        end

        batch_id = SidekiqWorkflows::Worker.perform_workflow(workflow)
        sleep 10
        expect(Redis.new(url: 'redis://redis:6379').smembers(workflow_uuid).to_set).must_equal(["WorkerFive - level 2", "WorkerThree - level 2", "WorkerOne - level 1", "WorkerTwo - level 1"].to_set)

        Sidekiq::Batch::Status.new(batch_id).join

        expect(Redis.new(url: 'redis://redis:6379').smembers(workflow_uuid).size).must_equal(6)
      end
    end
  end
end
