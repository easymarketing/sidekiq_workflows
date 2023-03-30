require_relative '../test_helper'
require_relative './worker'
require 'set'

describe SidekiqWorkflows::Worker do
  describe 'build' do

    it 'should run a workflow tree and write some results to redis - success' do
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

        batch_id = SidekiqWorkflows::Worker.perform_workflow(workflow, on_success: 'SidekiqWorkflows::TestWorker#on_success', on_death: 'SidekiqWorkflows::TestWorker#on_death')
        sleep 10
        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid).to_set).must_equal(["WorkerFive - level 2", "WorkerThree - level 2", "WorkerOne - level 1", "WorkerTwo - level 1"].to_set)

        Sidekiq::Batch::Status.new(batch_id).join

        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid).size).must_equal(7)
        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid)).must_include('success')
        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid)).wont_include('death')
      end
    end

    it 'should run a workflow tree and write some results to redis - death' do
      Sidekiq::Testing.disable! do
        workflow_uuid = SecureRandom.uuid
        workflow = SidekiqWorkflows.build(workflow_uuid: workflow_uuid) do
          perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerOne - level 1').then do
            perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerThree - level 2')
          end

          perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerTwo - level 1').then do
            perform([
              {worker: SidekiqWorkflows::TestWorker, payload: [workflow_uuid, 'ErrorWorker'], delay: 30},
              {worker: SidekiqWorkflows::TestWorker, payload: [workflow_uuid, 'WorkerFive - level 2']}
            ]).then do
              perform(SidekiqWorkflows::TestWorker, workflow_uuid, 'WorkerSix - level 3')
            end
          end
        end

        batch_id = SidekiqWorkflows::Worker.perform_workflow(workflow, on_success: 'SidekiqWorkflows::TestWorker#on_success', on_death: 'SidekiqWorkflows::TestWorker#on_death')
        sleep 10
        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid).to_set).must_equal(["WorkerFive - level 2", "WorkerThree - level 2", "WorkerOne - level 1", "WorkerTwo - level 1"].to_set)

        Sidekiq::Batch::Status.new(batch_id).join

        sleep(3) until Sidekiq::Batch::Status.new(batch_id).dead?

        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid).size).must_equal(5)
        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid)).wont_include('success')
        expect(Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379')).smembers(workflow_uuid)).must_include('death')
      end
    end
  end
end
